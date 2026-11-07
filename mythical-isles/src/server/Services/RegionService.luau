-- Regiões dos mundos (Crystal Hollow): portais entre regiões, baús-santuário e NPCs.
-- Tudo validado no servidor: o jogador precisa ter o mundo desbloqueado e estar nele, perto do
-- objeto; os baús têm recarga POR JOGADOR salva no perfil (data.shrines), sem duplicar recompensa.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Regions = require(Shared.Config.Regions)
local Drops = require(Shared.Config.Drops)
local Exploration = require(Shared.Config.Exploration)
local Worlds = require(Shared.Config.Worlds)
local RateLimiter = require(Shared.Util.RateLimiter)

local RegionService = {}

local S
local travelLimiter = RateLimiter.new(1, 1.5)
local useLimiter = RateLimiter.new(3, 1)
local talkIndex: { [Player]: { [string]: number } } = {}

function RegionService.init(registry)
	S = registry
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function regionsOf(worldId: string)
	return S.WorldService.Regions and S.WorldService.Regions[worldId]
end

-- Próximo destino do circuito a partir de uma região.
function RegionService.nextRegion(regionId: string): string
	local c = Regions.circuitOf(regionId) or Regions.Circuit
	local i = table.find(c, regionId) or 0
	return c[i % #c + 1]
end

-- Viagem por portal de região. `toRegion` = destino; valida mundo desbloqueado e presença no mundo.
function RegionService.travel(player: Player, toRegion: string)
	local info = Regions.Info[toRegion]
	if not info then
		return { ok = false, msg = "Região inválida" }
	end
	if not travelLimiter:allow(player) then
		return { ok = false, msg = "Aguarde um instante" }
	end
	local data = S.DataService.get(player)
	if not data or not data.worlds[info.world] then
		return { ok = false, msg = "Mundo bloqueado" }
	end
	if S.WorldService.playerWorld(player) ~= info.world then
		return { ok = false, msg = "Você não está em " .. Worlds.Info[info.world].name }
	end
	local reg = regionsOf(info.world)
	local gate = reg and reg.gates[toRegion]
	local root = rootOf(player)
	if not gate or not root then
		return { ok = false, msg = "Portal indisponível" }
	end
	local char = player.Character :: Model
	char:PivotTo(gate.arrival)
	root.AssemblyLinearVelocity = Vector3.zero
	S.PetService.teleportPets(player, gate.arrival.Position)
	S.ExplorationService.clearSelection(player)
	S.Push:FireClient(player, "Toast", { text = "✦ " .. info.name .. " — " .. info.subtitle, kind = "region" })
	return { ok = true }
end

-- Abre um baú-santuário (recompensa da tabela Drops.Shrine, recarga por jogador).
function RegionService.claim(player: Player, worldId: string, chestId: string)
	if not useLimiter:allow(player) then
		return { ok = false, msg = "Aguarde" }
	end
	local reg = regionsOf(worldId)
	local chest = reg and reg.chests[chestId]
	local data = S.DataService.get(player)
	local root = rootOf(player)
	if not chest or not data or not root then
		return { ok = false, msg = "Indisponível" }
	end
	if (root.Position - chest.pos).Magnitude > Exploration.Shrine.range then
		return { ok = false, msg = "Chegue mais perto do baú" }
	end
	local now = os.time()
	local last = data.shrines[chestId]
	if last and now - last < Exploration.Shrine.cooldown then
		local left = Exploration.Shrine.cooldown - (now - last)
		local msg = string.format("%s: volte em %d min", chest.title, math.ceil(left / 60))
		S.Push:FireClient(player, "Toast", { text = msg, kind = "error" })
		return { ok = false, msg = msg }
	end
	local first = last == nil
	data.shrines[chestId] = now
	local granted = S.RewardService.rollDrops(player, Drops.Shrine, chest.title, { worldIndex = Worlds.Info[worldId].index })
	data.stats.treasures += 1
	S.QuestService.event(player, { type = "open_treasure" })
	S.CombatService.fx("burst", { at = chest.pos + Vector3.new(0, 3, 0), radius = 6, color = Color3.fromRGB(170, 140, 255) })
	if first then
		S.Push:FireClient(player, "Toast", { text = "✦ Local secreto descoberto: " .. chest.title, kind = "secret" })
	end
	S.DataService.markDirty(player)
	return { ok = true, items = granted, first = first }
end

-- Conversa com NPC: cada interação mostra a próxima fala.
function RegionService.talk(player: Player, npc)
	if not useLimiter:allow(player) then
		return
	end
	local root = rootOf(player)
	if not root or not npc.model.PrimaryPart or (root.Position - npc.model.PrimaryPart.Position).Magnitude > 16 then
		return
	end
	local per = talkIndex[player] or {}
	talkIndex[player] = per
	local i = (per[npc.id] or 0) % #npc.lines + 1
	per[npc.id] = i
	S.Push:FireClient(player, "Toast", { text = npc.name .. ": " .. npc.lines[i], kind = "npc" })
	return npc.lines[i]
end

function RegionService.start()
	for worldId, reg in pairs(S.WorldService.Regions or {}) do
		for regionId, gate in pairs(reg.gates) do
			local dest = RegionService.nextRegion(regionId)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Viajar"
			prompt.ObjectText = Regions.Info[dest].name
			prompt.HoldDuration = 0.4
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.Parent = gate.part
			prompt.Triggered:Connect(function(player)
				RegionService.travel(player, dest)
			end)
			gate.prompt = prompt
			local hub = Regions.hub(worldId)
			if hub and dest ~= hub and regionId ~= hub then
				local back = Instance.new("ProximityPrompt")
				back.ActionText = "Voltar ao início"
				back.ObjectText = Regions.Info[hub].name
				back.KeyboardKeyCode = Enum.KeyCode.R
				back.GamepadKeyCode = Enum.KeyCode.ButtonY
				back.UIOffset = Vector2.new(0, 70)
				back.MaxActivationDistance = 14
				back.RequiresLineOfSight = false
				back.Parent = gate.part
				back.Triggered:Connect(function(player)
					RegionService.travel(player, hub)
				end)
				gate.backPrompt = back
			end
		end
		for chestId, chest in pairs(reg.chests) do
			chest.prompt.Triggered:Connect(function(player)
				RegionService.claim(player, worldId, chestId)
			end)
		end
		for _, npc in ipairs(reg.npcs) do
			npc.prompt.Triggered:Connect(function(player)
				RegionService.talk(player, npc)
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(p)
		talkIndex[p] = nil
	end)
end

return RegionService

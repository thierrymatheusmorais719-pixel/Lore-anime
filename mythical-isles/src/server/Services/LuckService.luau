-- Sorte no servidor: reúne fontes válidas do perfil, da equipe e dos eventos, calcula os
-- multiplicadores e os envia para a interface. O cliente NUNCA informa sorte.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local LuckLogic = require(Shared.Logic.LuckLogic)
local LuckConfig = require(Shared.Config.Luck)
local InventoryLogic = require(Shared.Logic.InventoryLogic)
local Net = require(Shared.Net)

local LuckService = {}

local S
local Push
local manualEvents = {} -- eventos extras (ex.: comando de teste no Studio): { id, label, bonus, category, ends }
local lastSent: { [Player]: string } = {}

function LuckService.init(registry)
	S = registry
	Push = Net.get("Push")
end

local function events(now: number)
	local list = LuckLogic.activeEvents(now)
	for i = #manualEvents, 1, -1 do
		local ev = manualEvents[i]
		if ev.ends <= now then
			table.remove(manualEvents, i)
		else
			table.insert(list, ev)
		end
	end
	return list
end

function LuckService.activeEvents()
	return events(os.time())
end

function LuckService.addManualEvent(id: string, label: string, bonus: number, category: string, duration: number)
	table.insert(manualEvents, { id = id, label = label, bonus = bonus, category = category, ends = os.time() + duration })
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		LuckService.push(p, true)
	end
end

function LuckService.sources(player: Player)
	local data = S.DataService.get(player)
	if not data then
		return {}
	end
	local now = os.time()
	local perks, synergyLuck = S.PetService.luckContributions(player)
	return LuckLogic.collectSources({ now = now, profile = data, teamPerks = perks, synergy = synergyLuck, events = events(now) })
end

function LuckService.mult(player: Player, category: string): number
	return (LuckLogic.multiplier(LuckService.sources(player), category))
end

function LuckService.mults(player: Player)
	local sources = LuckService.sources(player)
	local out = {}
	for _, c in ipairs(LuckConfig.Categories) do
		out[c] = (LuckLogic.multiplier(sources, c))
	end
	return out, sources
end

-- Estado para a interface: multiplicadores por categoria, detalhamento por tipo e fontes.
function LuckService.view(player: Player)
	local sources = LuckService.sources(player)
	local cats = {}
	for _, c in ipairs(LuckConfig.Categories) do
		local mult, byType = LuckLogic.multiplier(sources, c)
		cats[c] = { mult = mult, byType = byType, max = LuckConfig.MaxMultiplier[c] }
	end
	return { categories = cats, sources = sources, now = os.time() }
end

function LuckService.push(player: Player, force: boolean?)
	local view = LuckService.view(player)
	-- só reenvia quando algo mudou (fontes/multiplicadores), ou a cada 10s para os timers
	local sig = {}
	for _, s in ipairs(view.sources) do
		table.insert(sig, s.id .. ":" .. string.format("%.3f", s.bonus))
	end
	local key = table.concat(sig, "|")
	if force or lastSent[player] ~= key then
		lastSent[player] = key
		Push:FireClient(player, "Luck", view)
	end
end

-- Beber uma poção (item do inventário).
function LuckService.usePotion(player: Player, itemId: string)
	local data = S.DataService.get(player)
	local potion = LuckConfig.Potions[itemId]
	if not data or not potion then
		return { ok = false, msg = "Poção inválida" }
	end
	if InventoryLogic.count(data, itemId) < 1 then
		return { ok = false, msg = "Você não tem essa poção" }
	end
	InventoryLogic.spend(data, { items = { [itemId] = 1 } })
	LuckLogic.addBuff(data.buffs, os.time(), {
		id = itemId, source = "potion", label = potion.label, category = potion.category, bonus = potion.bonus, duration = potion.duration,
	})
	S.DataService.markDirty(player)
	LuckService.push(player, true)
	return { ok = true, msg = potion.label .. " ativa!" }
end

-- Buff de recompensa de missão.
function LuckService.addQuestBuff(player: Player, id: string, label: string, luck)
	local data = S.DataService.get(player)
	if not data then
		return
	end
	LuckLogic.addBuff(data.buffs, os.time(), {
		id = "quest:" .. id, source = "quest", label = label, category = luck.category or "All", bonus = luck.bonus, duration = luck.duration,
	})
	S.DataService.markDirty(player)
	LuckService.push(player, true)
end

function LuckService.start()
	local Players = game:GetService("Players")
	Players.PlayerRemoving:Connect(function(p)
		lastSent[p] = nil
	end)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			for _, p in ipairs(Players:GetPlayers()) do
				if S.DataService.get(p) then
					LuckService.push(p, tick % 10 == 0)
				end
			end
		end
	end)
end

return LuckService

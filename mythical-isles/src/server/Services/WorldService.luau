-- Mundos: constrói as ilhas, controla portais, desbloqueio e viagem.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local Regions = require(Shared.Config.Regions)
local Bosses = require(Shared.Config.Bosses)
local Make = require(Shared.Util.Make)
local InventoryLogic = require(Shared.Logic.InventoryLogic)
local Net = require(Shared.Net)
local WorldBuilder = require(script.Parent.WorldBuilder)
local CrystalHollow = require(script.Parent.CrystalHollow)
local SkyKingdom = require(script.Parent.SkyKingdom)
local SanctuaryTree = require(script.Parent.SanctuaryTree)
local VerdantLowlands = require(script.Parent.VerdantLowlands)

local WorldService = {}

local S
local Push
WorldService.Layout = {} -- [worldId] = { center, radius, spawnCF, arena, enemyZones, resourceFields, eggStations }
WorldService.Sanctuary = nil -- Árvore-Santuário do Verdant Haven (SanctuaryTree.build)
WorldService.Regions = {} -- [worldId] = { gates, chests, npcs } (regiões construídas à mão; ver RegionService)

function WorldService.init(registry)
	S = registry
	Push = Net.get("Push")
	for _, name in ipairs({ "World", "Enemies", "Bosses", "Pets", "Resources", "Telegraphs", "Fx", "Treasures" }) do
		if not workspace:FindFirstChild(name) then
			Make("Folder", { Name = name, Parent = workspace })
		end
	end
	-- FallenPartsDestroyHeight só pode ser alterado no arquivo do lugar (default.project.json),
	-- não por script de jogo. A proteção contra queda é feita em WorldService.start.
end

local function nextWorld(id: string): string?
	local i = Worlds.indexOf(id)
	return Worlds.Order[i + 1]
end

local function prevWorld(id: string): string?
	local i = Worlds.indexOf(id)
	return Worlds.Order[i - 1]
end

-- Mar de nuvens abaixo das ilhas: as ilhas flutuam, mas há um "chão" visual no horizonte.
local function cloudSea(parent: Instance)
	local folder = Make("Folder", { Name = "CloudSea", Parent = parent })
	for i = 0, 3 do
		Make("Part", {
			Name = "CloudSea", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			Size = Vector3.new(2048, 2, 2048), CFrame = CFrame.new(-700 + i * 2000, -150, 0),
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(236, 242, 255), Transparency = 0.15, Parent = folder,
		})
	end
end

function WorldService.build()
	local root = workspace:FindFirstChild("World")
	cloudSea(root)
	local L = WorldBuilder.Layout
	local function buildWorld(id: string)
		local w = Worlds.Info[id]
		local folder = Make("Folder", { Name = id, Parent = root })
		local terrainOk = WorldBuilder.terrain(id, folder)
		if id == "verdant" then
			-- Terras Baixas em volta do planalto: rampas, rio, ruínas, torre, runas, pântano e cavernas
			if w.lowlands then
				local okLow, low = pcall(VerdantLowlands.build, folder, terrainOk, WorldBuilder)
				if okLow then
					WorldService.Lowlands = low
					local reg = WorldService.Regions[id] or { gates = {}, chests = {}, npcs = {}, walkPoints = {} }
					reg.walkPoints = reg.walkPoints or {}
					for cid, ch in pairs(low.chests) do
						reg.chests[cid] = ch
					end
					for label, q in pairs(low.walkPoints) do
						reg.walkPoints[label] = q
					end
					WorldService.Regions[id] = reg
				else
					local rs = game:GetService("ReplicatedStorage")
					rs:SetAttribute("ServerErrors", ((rs:GetAttribute("ServerErrors") or "") .. "\n\nTerras Baixas: " .. tostring(low)))
				end
			end
			WorldBuilder.verdantLandmark(folder, terrainOk)
			WorldBuilder.blockGrove(folder)
			-- Árvore-Santuário gigante no lugar da Árvore Ancestral (sobre o lago turquesa)
			local lake = WorldBuilder.Layout.verdantLake
			local treeCenter = WorldBuilder.polar(w.center, lake.theta, lake.dist)
			local okTree, tree = pcall(SanctuaryTree.build, folder, treeCenter, function(parent, cf, title)
				return WorldBuilder.shrineChest(parent, cf, title, { accent = Color3.fromRGB(150, 255, 140) })
			end)
			if okTree then
				WorldService.Sanctuary = tree
				-- a decoração e a mata (construídas depois) não nascem nos pés das raízes nem na escadaria
				local reserved = Regions.Reserved.verdant
				for _, f in ipairs(tree.footprint) do
					local d = (f.pos - w.center) * Vector3.new(1, 0, 1)
					table.insert(reserved, { theta = math.deg(math.atan2(d.Z, d.X)), dist = d.Magnitude, r = f.r })
				end
			else
				local rs = game:GetService("ReplicatedStorage")
				rs:SetAttribute("ServerErrors", ((rs:GetAttribute("ServerErrors") or "") .. "\n\nÁrvore-Santuário: " .. tostring(tree)))
			end
		elseif id == "crystal" or id == "sky" then
			local reg = (id == "crystal" and CrystalHollow or SkyKingdom).build(folder, terrainOk)
			WorldService.Regions[id] = reg
			if reg.errors then
				local rs = game:GetService("ReplicatedStorage")
				rs:SetAttribute("ServerErrors", ((rs:GetAttribute("ServerErrors") or "") .. "\n\n" .. Worlds.Info[id].name .. ": " .. reg.errors))
			end
		end
		WorldBuilder.boundary(id, folder)
		local spawnCF = WorldBuilder.plaza(id, folder)
		WorldBuilder.decor(id, folder)
		-- anel de mata para exploração (ilhas ampliadas): floresta densa, trilha e baús-santuário
		local ring = WorldBuilder.wildRing(id, folder, terrainOk)
		if next(ring.chests) then
			local reg = WorldService.Regions[id] or { gates = {}, chests = {}, npcs = {}, walkPoints = {} }
			reg.walkPoints = reg.walkPoints or {}
			for cid, ch in pairs(ring.chests) do
				reg.chests[cid] = ch
			end
			for label, q in pairs(ring.walkPoints) do
				reg.walkPoints[label] = q
			end
			reg.ring = ring
			WorldService.Regions[id] = reg
		end
		-- baús da Árvore-Santuário (ninhos, copa, coroa) usam o mesmo sistema dos baús-santuário
		if id == "verdant" and WorldService.Sanctuary then
			local reg = WorldService.Regions[id] or { gates = {}, chests = {}, npcs = {}, walkPoints = {} }
			for cid, ch in pairs(WorldService.Sanctuary.chests) do
				reg.chests[cid] = ch
			end
			WorldService.Regions[id] = reg
		end

		local layout = { id = id, center = w.center, radius = w.radius, spawnCF = spawnCF, enemyZones = {}, resourceFields = {}, eggStations = {} }

		for i, eggId in ipairs(w.eggs) do
			local spot = L.eggs[i]
			local pos = WorldBuilder.polar(w.center, spot.theta, spot.dist)
			local model, prompt = WorldBuilder.eggStation(eggId, pos, folder)
			layout.eggStations[eggId] = model
			prompt.Triggered:Connect(function(player)
				Push:FireClient(player, "OpenEgg", { egg = eggId })
			end)
		end

		local nxt = nextWorld(id)
		if nxt then
			local pos = WorldBuilder.polar(w.center, L.portalNext.theta, L.portalNext.dist)
			local _, prompt, text = WorldBuilder.portal(pos, (w.center - pos) * Vector3.new(1, 0, 1), Worlds.Info[nxt].palette.accent, "→ " .. Worlds.Info[nxt].name, folder)
			text.Text = string.format("→ %s (%d moedas)", Worlds.Info[nxt].name, Worlds.Info[nxt].unlockCost)
			prompt.Triggered:Connect(function(player)
				WorldService.portal(player, nxt)
			end)
		end
		local prv = prevWorld(id)
		if prv then
			local pos = WorldBuilder.polar(w.center, L.portalPrev.theta, L.portalPrev.dist)
			local _, prompt = WorldBuilder.portal(pos, (w.center - pos) * Vector3.new(1, 0, 1), Worlds.Info[prv].palette.accent, "← " .. Worlds.Info[prv].name, folder)
			prompt.Triggered:Connect(function(player)
				WorldService.teleport(player, prv)
			end)
		end

		for i, enemyId in ipairs(w.enemies) do
			local z = L.enemyZones[i]
			layout.enemyZones[enemyId] = { center = WorldBuilder.polar(w.center, z.theta, z.dist), radius = z.r }
		end
		-- inimigos das Terras Baixas: pântano e pátio das ruínas (no chão de baixo)
		if id == "verdant" and w.lowlands and WorldService.Lowlands then
			local y = w.center.Y - w.lowlands.drop
			local function at(theta: number, dist: number): Vector3
				local q = WorldBuilder.polar(w.center, theta, dist)
				return Vector3.new(q.X, y, q.Z)
			end
			layout.enemyZones.bog_lurker = { center = at(322, 478), radius = 40 }
			layout.enemyZones.ruin_sentinel = { center = at(215, 430), radius = 22 } -- campo na frente do portão das ruínas
		end
		for _, f in ipairs(L.resources) do
			table.insert(layout.resourceFields, { center = WorldBuilder.polar(w.center, f.theta, f.dist), radius = f.r })
		end
		local boss = Bosses.Info[w.bossId]
		local arenaCenter = WorldBuilder.polar(w.center, L.arena.theta, L.arena.dist)
		local _, banner = WorldBuilder.arena(id, arenaCenter, boss.arenaRadius, folder)
		layout.arena = { center = arenaCenter, radius = boss.arenaRadius, banner = banner }
		WorldService.Layout[id] = layout
	end
	for _, id in ipairs(Worlds.Order) do
		-- cada ilha é construída separadamente: se uma falhar, as outras continuam
		local ok, err = pcall(buildWorld, id)
		if not ok then
			warn("[WorldService] falha ao construir " .. id .. ": " .. tostring(err))
			local rs = game:GetService("ReplicatedStorage")
			rs:SetAttribute("ServerErrors", ((rs:GetAttribute("ServerErrors") or "") .. "\n\nconstrução de " .. id .. ": " .. tostring(err)))
		end
	end
end

-- Mundo em que uma posição está (ou nil se fora das ilhas).
function WorldService.worldAt(pos: Vector3): string?
	for _, id in ipairs(Worlds.Order) do
		local w = Worlds.Info[id]
		local d = (pos - w.center) * Vector3.new(1, 0, 1)
		local dy = pos.Y - w.center.Y
		if d.Magnitude <= (w.extent or w.radius + 40) and dy > -120 and dy < (w.ceiling or 120) then
			return id
		end
	end
	return nil
end

function WorldService.inSafeZone(pos: Vector3): boolean
	local id = WorldService.worldAt(pos)
	if not id then
		return false
	end
	local d = (pos - Worlds.Info[id].center) * Vector3.new(1, 0, 1)
	return d.Magnitude <= Worlds.SafeRadius
end

function WorldService.playerWorld(player: Player): string?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	return WorldService.worldAt((root :: BasePart).Position)
end

function WorldService.teleport(player: Player, worldId: string)
	local data = S.DataService.get(player)
	if not data or not Worlds.Info[worldId] then
		return { ok = false, msg = "Mundo inválido" }
	end
	if not data.worlds[worldId] then
		return { ok = false, msg = "Mundo bloqueado" }
	end
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return { ok = false, msg = "Personagem indisponível" }
	end
	local layout = WorldService.Layout[worldId]
	char:PivotTo(layout.spawnCF)
	player:SetAttribute("World", worldId)
	S.PetService.teleportPets(player, layout.spawnCF.Position)
	S.ExplorationService.clearSelection(player)
	return { ok = true }
end

function WorldService.unlock(player: Player, worldId: string)
	local data = S.DataService.get(player)
	local w = Worlds.Info[worldId]
	if not data or not w then
		return { ok = false, msg = "Mundo inválido" }
	end
	if data.worlds[worldId] then
		return { ok = true, msg = "Já desbloqueado" }
	end
	local prev = prevWorld(worldId)
	if prev and not data.worlds[prev] then
		return { ok = false, msg = "Desbloqueie " .. Worlds.Info[prev].name .. " primeiro" }
	end
	if not InventoryLogic.spend(data, { coins = w.unlockCost }) then
		return { ok = false, msg = string.format("Precisa de %d moedas", w.unlockCost) }
	end
	data.worlds[worldId] = true
	S.QuestService.event(player, { type = "unlock_world", target = worldId })
	S.DataService.markDirty(player)
	S.CombatService.refreshPlayerHealth(player)
	return { ok = true, msg = w.name .. " desbloqueado!" }
end

function WorldService.portal(player: Player, worldId: string)
	local data = S.DataService.get(player)
	if not data then
		return
	end
	if not data.worlds[worldId] then
		Push:FireClient(player, "OpenUnlock", { world = worldId })
		return
	end
	WorldService.teleport(player, worldId)
end

-- Spawn controlado pelo servidor: o personagem só nasce DEPOIS do mapa pronto e sempre
-- em cima da praça do Verdant Haven (evita nascer no ar/cair antes do terreno existir).
local RESPAWN_TIME = 4

function WorldService.spawnCharacter(player: Player)
	if player.Parent then
		player:LoadCharacter()
	end
end

local function placeAtSpawn(player: Player, char: Model, worldId: string)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if not hrp then
		return
	end
	local layout = WorldService.Layout[worldId] or WorldService.Layout[Worlds.Order[1]]
	char:PivotTo(layout.spawnCF)
	player:SetAttribute("World", layout.id)
end

function WorldService.start()
	local function track(player: Player)
		player.CharacterAdded:Connect(function(char)
			placeAtSpawn(player, char, Worlds.Order[1])
			local hum = char:WaitForChild("Humanoid", 10)
			if hum then
				hum.Died:Connect(function()
					task.delay(RESPAWN_TIME, function()
						if player.Parent and player.Character == char then
							WorldService.spawnCharacter(player)
						end
					end)
				end)
			end
		end)
		WorldService.spawnCharacter(player)
	end
	Players.PlayerAdded:Connect(track)
	for _, p in ipairs(Players:GetPlayers()) do
		track(p)
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, p in ipairs(Players:GetPlayers()) do
				local char = p.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					local w = WorldService.worldAt(hrp.Position)
					if w and p:GetAttribute("World") ~= w then
						p:SetAttribute("World", w)
					end
					-- proteção contra queda: abaixo da ilha atual, volta para a praça dela
					local wid = p:GetAttribute("World") or Worlds.Order[1]
					local cur = Worlds.Info[wid] or Worlds.Info[Worlds.Order[1]]
					if hrp.Position.Y < cur.center.Y - (cur.fallDepth or 45) then
						char:PivotTo((WorldService.Layout[wid] or WorldService.Layout[Worlds.Order[1]]).spawnCF)
						hrp.AssemblyLinearVelocity = Vector3.zero
					end
				end
			end
		end
	end)
end

return WorldService

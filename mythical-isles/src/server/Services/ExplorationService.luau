-- Exploração: recursos quebráveis (loop base de moedas), tesouros ocultos, ovos especiais
-- encontrados explorando e o evento secreto "Estrela Errante". Toda chance usa a sorte do servidor.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local Exploration = require(Shared.Config.Exploration)
local Drops = require(Shared.Config.Drops)
local LuckLogic = require(Shared.Logic.LuckLogic)
local InventoryLogic = require(Shared.Logic.InventoryLogic)
local Items = require(Shared.Config.Items)
local Make = require(Shared.Util.Make)
local RateLimiter = require(Shared.Util.RateLimiter)

local ExplorationService = {}

local S
local rng = Random.new()
local nodes: { any } = {}
local nodeByModel: { [Instance]: any } = {}
local selection: { [Player]: any } = {}
local treasures: { [Player]: { any } } = {}
local mineLimiter = RateLimiter.new(10, 2, 0.1)
local openLimiter = RateLimiter.new(5, 2, 0.3)
local PLAYER_MINE = 6

local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

function ExplorationService.init(registry)
	S = registry
end

-------------------------------------------------------------------------------
-- Modelos de recurso
-------------------------------------------------------------------------------

local function p(model, props)
	props.Anchored = true
	props.CanCollide = props.CanCollide == true
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	props.Parent = model
	return Make("Part", props)
end

local function buildResource(kind: string, pos: Vector3)
	local m = Make("Model", { Name = kind })
	local base = p(m, { Name = "Base", Size = V(5, 1, 5), CFrame = CF(pos + V(0, 0.5, 0)), Transparency = 1, CanCollide = false })
	m.PrimaryPart = base
	local yaw = CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	if kind == "bloom_bush" then
		for i, o in ipairs({ { 0, 1.6, 0, 3.4 }, { 1.4, 1.2, 0.6, 2.4 }, { -1.3, 1.1, -0.5, 2.6 } }) do
			p(m, { Name = "Leaf", Shape = Enum.PartType.Ball, Size = Vector3.one * o[4], CFrame = CF(pos + V(o[1], o[2], o[3])), Color = rgb(80, 150 + i * 10, 70), Material = Enum.Material.Grass })
		end
		for k = 1, 4 do
			local a = k * 1.6
			p(m, { Name = "Blossom", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7, CFrame = CF(pos + V(math.cos(a) * 1.5, 2.6, math.sin(a) * 1.5)), Color = rgb(255, 150, 190), Material = Enum.Material.Neon })
		end
	elseif kind == "crystal_cluster" then
		for i = 1, 4 do
			p(m, { Name = "Crystal", Size = V(1.3, 5 - i * 0.7, 1.3), CFrame = CF(pos + V(0, 2.2 - i * 0.2, 0)) * yaw * CFrame.Angles(math.rad((i - 2) * 22), math.rad(i * 70), math.rad((i % 2) * 20 - 10)) * CF(0, 0, (i - 1) * 0.5),
				Color = i % 2 == 0 and rgb(180, 140, 255) or rgb(120, 220, 255), Material = Enum.Material.Glass, Transparency = 0.1 })
		end
		p(m, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = CF(pos + V(0, 0.8, 0)), Color = rgb(150, 230, 255), Material = Enum.Material.Neon })
	elseif kind == "cloud_puff" then
		for i, o in ipairs({ { 0, 1.8, 0, 3.6 }, { 1.6, 1.4, 0.4, 2.6 }, { -1.5, 1.5, -0.4, 2.8 }, { 0.3, 3, 0.2, 2.2 } }) do
			p(m, { Name = "Puff", Shape = Enum.PartType.Ball, Size = Vector3.one * o[4], CFrame = CF(pos + V(o[1], o[2], o[3])), Color = rgb(245, 248, 255), Transparency = 0.05 * i })
		end
		p(m, { Name = "Spark", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = CF(pos + V(0, 2, -1.6)), Color = rgb(255, 240, 120), Material = Enum.Material.Neon })
	elseif kind == "glow_mushroom" then
		p(m, { Name = "Stem", Shape = Enum.PartType.Cylinder, Size = V(3, 1, 1), CFrame = CF(pos + V(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(230, 220, 205) })
		local cap = p(m, { Name = "Cap", Size = V(4, 1.4, 4), CFrame = CF(pos + V(0, 3.4, 0)), Color = rgb(150, 120, 255), Material = Enum.Material.Neon })
		Make("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = cap })
		p(m, { Name = "SmallCap", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = CF(pos + V(1.6, 0.8, 0.5)), Color = rgb(120, 255, 210), Material = Enum.Material.Neon })
	elseif kind == "star_shard" then
		p(m, { Name = "Shard", Size = V(1.8, 5, 1.8), CFrame = CF(pos + V(0, 3.2, 0)) * yaw * CFrame.Angles(0, 0, math.rad(12)), Color = rgb(255, 225, 150), Material = Enum.Material.Neon })
		p(m, { Name = "Shard", Size = V(1.2, 3, 1.2), CFrame = CF(pos + V(1.2, 1.6, 0.3)) * yaw * CFrame.Angles(0, 0, math.rad(-25)), Color = rgb(170, 140, 255), Material = Enum.Material.Neon })
		p(m, { Name = "Rock", Size = V(3.4, 1.2, 3), CFrame = CF(pos + V(0, 0.6, 0)) * yaw, Color = rgb(60, 54, 90), Material = Enum.Material.Basalt })
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = true
		end
	end
	return m
end

local function spawnNode(node)
	local model = buildResource(node.kind, node.pos)
	model:SetAttribute("ResourceId", node.kind)
	model:SetAttribute("Health", node.cfg.hp)
	model:SetAttribute("MaxHealth", node.cfg.hp)
	model:SetAttribute("Label", node.cfg.label)
	model.Parent = workspace:FindFirstChild("Resources")
	node.model = model
	node.hp = node.cfg.hp
	node.alive = true
	node.contrib = {}
	nodeByModel[model] = node
end

-------------------------------------------------------------------------------
-- Mineração
-------------------------------------------------------------------------------

local function nodeFrom(inst: Instance?)
	while inst do
		local n = nodeByModel[inst]
		if n then
			return n
		end
		inst = inst.Parent
	end
	return nil
end

function ExplorationService.select(player: Player, model: Instance?)
	if not mineLimiter:allow(player) then
		return
	end
	if typeof(model) ~= "Instance" then
		return
	end
	local node = nodeFrom(model)
	local root = S.CombatService.charRoot(player)
	if not node or not node.alive or not root then
		return
	end
	if (root.Position - node.pos).Magnitude > Exploration.MineRange + 25 then
		return
	end
	selection[player] = node
	player:SetAttribute("Mining", node.kind)
	for _, st in ipairs(S.PetService.team(player)) do
		st.mineTarget = node.model
	end
	S.CombatService.setFocus(player, nil)
end

function ExplorationService.clearSelection(player: Player)
	selection[player] = nil
	player:SetAttribute("Mining", nil)
	for _, st in ipairs(S.PetService.team(player)) do
		st.mineTarget = nil
	end
end

local function rollSpecials(player: Player, node, mults)
	local worldId = node.world
	local w = Worlds.Info[worldId]
	-- ovo especial do mundo
	local se = Drops.ResourceSpecialEgg[worldId]
	if se then
		local chance = LuckLogic.applyChance(se.chance, mults.SpecialEgg, 1, se.maxChance)
		if S.RewardService.random() < chance then
			local data = S.DataService.get(player)
			InventoryLogic.add(data, se.item, 1)
			S.RewardService.discovery(player, {
				id = S.AnnounceService.newId(), kind = "egg", item = se.item, rarity = "Legendary", chance = chance,
				text = Items.label(se.item) .. " encontrado explorando " .. w.name,
			})
			S.Push:FireClient(player, "Drop", { source = "Exploração", items = { { item = se.item, amount = 1, notable = true } } })
		end
	end
	-- tesouro oculto
	local tchance = LuckLogic.applyChance(Drops.TreasureSpawnChance, mults.Treasure, 1, Drops.TreasureSpawnMaxChance)
	if S.RewardService.random() < tchance then
		ExplorationService.spawnTreasure(player)
	end
end

local function breakNode(node)
	node.alive = false
	local total = 0
	for _, dmg in pairs(node.contrib) do
		total += dmg
	end
	local w = Worlds.Info[node.world]
	for player, dmg in pairs(node.contrib) do
		if player.Parent and S.DataService.get(player) then
			local share = dmg / math.max(1, total)
			local coins = math.max(1, math.floor(node.cfg.coins * share + 0.5))
			local got = S.RewardService.addCoins(player, coins)
			local data = S.DataService.get(player)
			data.stats.resources += 1
			S.QuestService.event(player, { type = "break_resource", world = node.world })
			S.CombatService.queueNumber(node.pos + V(0, 5, 0), got, "coins")
			if share >= 0.25 then
				rollSpecials(player, node, (S.LuckService.mults(player)))
			end
		end
	end
	S.CombatService.fx("burst", { at = node.pos + V(0, 2, 0), radius = 5, color = w.palette.accent })
	for player, sel in pairs(selection) do
		if sel == node then
			ExplorationService.clearSelection(player)
		end
	end
	nodeByModel[node.model] = nil
	node.model:Destroy()
	node.model = nil
	task.delay(node.cfg.respawn, function()
		spawnNode(node)
	end)
end

local function mineTick()
	for player, node in pairs(selection) do
		local root = S.CombatService.charRoot(player)
		if not node.alive or not root or (root.Position - node.pos).Magnitude > Exploration.MineRange * 1.6 then
			ExplorationService.clearSelection(player)
		else
			local power = PLAYER_MINE
			for _, st in ipairs(S.PetService.team(player)) do
				if os.clock() >= st.knockedUntil and st.target == nil and (st.root.Position - node.pos).Magnitude < 14 then
					power += st.stats.atk * Exploration.MineFactor
					S.CombatService.setAction(st.model, "Attack")
				end
			end
			local dmg = math.min(node.hp, power)
			node.hp -= dmg
			node.contrib[player] = (node.contrib[player] or 0) + dmg
			node.model:SetAttribute("Health", math.floor(node.hp))
			if node.hp <= 0 then
				breakNode(node)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Tesouros
-------------------------------------------------------------------------------

function ExplorationService.spawnTreasure(player: Player)
	local root = S.CombatService.charRoot(player)
	local worldId = root and S.WorldService.worldAt(root.Position)
	if not root or not worldId then
		return
	end
	local list = treasures[player] or {}
	treasures[player] = list
	if #list >= Exploration.Treasure.maxPerPlayer then
		return
	end
	local layout = S.WorldService.Layout[worldId]
	local pos
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(Exploration.Treasure.spawnMin, Exploration.Treasure.spawnMax)
		local cand = root.Position + V(math.cos(a) * d, 0, math.sin(a) * d)
		local flatC = (cand - layout.center) * V(1, 0, 1)
		local inArena = ((cand - layout.arena.center) * V(1, 0, 1)).Magnitude < layout.arena.radius + 6
		if flatC.Magnitude < layout.radius - 8 and not inArena then
			pos = cand
			break
		end
	end
	if not pos then
		return
	end
	local hit = workspace:Raycast(pos + V(0, 40, 0), V(0, -100, 0))
	local y = hit and hit.Position.Y or layout.center.Y
	local m = Make("Model", { Name = "Treasure" })
	local chest = p(m, { Name = "Chest", Size = V(3, 2, 2.2), CFrame = CF(pos.X, y + 0.7, pos.Z), Color = rgb(150, 100, 50), Material = Enum.Material.Wood, CanCollide = true })
	p(m, { Name = "Lid", Size = V(3.1, 0.8, 2.3), CFrame = CF(pos.X, y + 2.0, pos.Z), Color = rgb(120, 80, 40), Material = Enum.Material.Wood })
	p(m, { Name = "Trim", Size = V(3.2, 0.3, 2.4), CFrame = CF(pos.X, y + 1.6, pos.Z), Color = rgb(255, 210, 80), Material = Enum.Material.Metal })
	local glint = p(m, { Name = "Glint", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = CF(pos.X, y + 3.2, pos.Z), Color = rgb(255, 240, 160), Material = Enum.Material.Neon })
	Make("PointLight", { Color = rgb(255, 220, 120), Range = 10, Brightness = 1, Parent = glint })
	m.PrimaryPart = chest
	m:SetAttribute("OwnerId", player.UserId)
	m:SetAttribute("Revealed", false)
	m:SetAttribute("Expires", workspace:GetServerTimeNow() + Exploration.Treasure.lifetime)
	m.Parent = workspace:FindFirstChild("Treasures")
	local t = { model = m, pos = chest.Position, world = worldId, expires = os.clock() + Exploration.Treasure.lifetime }
	table.insert(list, t)
	S.Push:FireClient(player, "Treasure", { pos = chest.Position })
	task.delay(Exploration.Treasure.lifetime, function()
		local i = table.find(list, t)
		if i then
			table.remove(list, i)
			m:Destroy()
		end
	end)
end

-- Explorador revela tesouros (do próprio jogador) num raio.
function ExplorationService.reveal(player: Player, radius: number, _duration: number)
	local root = S.CombatService.charRoot(player)
	if not root then
		return
	end
	local found = 0
	for _, t in ipairs(treasures[player] or {}) do
		if (t.pos - root.Position).Magnitude <= radius then
			t.model:SetAttribute("Revealed", true)
			found += 1
		end
	end
	-- o faro também tem chance de desenterrar um tesouro novo
	local mults = S.LuckService.mults(player)
	if found == 0 and S.RewardService.random() < LuckLogic.applyChance(0.25, mults.Treasure, 1, 0.6) then
		ExplorationService.spawnTreasure(player)
		for _, t in ipairs(treasures[player] or {}) do
			t.model:SetAttribute("Revealed", true)
		end
	end
end

function ExplorationService.open(player: Player, model: Instance?)
	if not openLimiter:allow(player) or typeof(model) ~= "Instance" then
		return
	end
	local list = treasures[player] or {}
	local root = S.CombatService.charRoot(player)
	if not root then
		return
	end
	for i, t in ipairs(list) do
		if t.model == model or (model :: Instance):IsDescendantOf(t.model) then
			if (t.pos - root.Position).Magnitude > Exploration.Treasure.openRange then
				S.Push:FireClient(player, "Toast", { text = "Chegue mais perto do tesouro", kind = "error" })
				return
			end
			table.remove(list, i)
			t.model:Destroy()
			local w = Worlds.Info[t.world]
			S.RewardService.rollDrops(player, Drops.Treasure, "Tesouro", { worldIndex = w.index })
			local data = S.DataService.get(player)
			data.stats.treasures += 1
			S.QuestService.event(player, { type = "open_treasure" })
			S.CombatService.fx("burst", { at = t.pos + V(0, 2, 0), radius = 6, color = rgb(255, 220, 120) })
			-- evento secreto
			local mults = S.LuckService.mults(player)
			local chance = LuckLogic.applyChance(Drops.SecretEventChance, mults.SecretEvent, 1, Drops.SecretEventMaxChance)
			if S.RewardService.random() < chance then
				S.EnemyService.spawnWanderingStar(player, t.pos + V(6, 0, 6), t.world)
				S.Push:FireClient(player, "Toast", { text = "✦ Evento secreto: uma Estrela Errante apareceu! Derrote-a antes que fuja.", kind = "secret" })
				S.RewardService.discovery(player, { id = S.AnnounceService.newId(), kind = "event", rarity = "Mythic", chance = chance, text = "Encontrou uma Estrela Errante em " .. w.name })
			end
			return
		end
	end
end

-- Exploradores na equipe encontram tesouros periodicamente.
local function explorerTick()
	for _, player in ipairs(Players:GetPlayers()) do
		local hasExplorer = false
		for _, st in ipairs(S.PetService.team(player)) do
			if st.stats.role == "Explorer" then
				hasExplorer = true
			end
		end
		if hasExplorer and S.CombatService.charRoot(player) then
			local mults = S.LuckService.mults(player)
			if S.RewardService.random() < LuckLogic.applyChance(0.2, mults.Treasure, 1, 0.5) then
				ExplorationService.spawnTreasure(player)
			end
		end
	end
end

function ExplorationService.start()
	for _, worldId in ipairs(Worlds.Order) do
		local w = Worlds.Info[worldId]
		local layout = S.WorldService.Layout[worldId] or { resourceFields = {} }
		local cfg = Exploration.Resources[w.resource]
		local per = math.ceil(cfg.count / math.max(1, #layout.resourceFields))
		for _, field in ipairs(layout.resourceFields) do
			for _ = 1, per do
				local a = rng:NextNumber(0, math.pi * 2)
				local d = math.sqrt(rng:NextNumber()) * field.radius
				local pos = field.center + V(math.cos(a) * d, 0, math.sin(a) * d)
				local hit = workspace:Raycast(pos + V(0, 40, 0), V(0, -100, 0))
				pos = V(pos.X, hit and hit.Position.Y or w.center.Y, pos.Z)
				local node = { kind = w.resource, cfg = cfg, pos = pos, world = worldId }
				table.insert(nodes, node)
				spawnNode(node)
			end
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		selection[player] = nil
		for _, t in ipairs(treasures[player] or {}) do
			t.model:Destroy()
		end
		treasures[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Exploration.MineInterval)
			local ok, err = pcall(mineTick)
			if not ok then
				warn("[ExplorationService]", err)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(45)
			pcall(explorerTick)
		end
	end)
end

return ExplorationService

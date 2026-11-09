-- MINERAÇÃO DE CRISTAIS (servidor). Veios de cristal nas Cavernas Esmeralda (Mundo 1) e em volta dos
-- campos de recursos dos outros mundos. O JOGADOR minera segurando o botão do ProximityPrompt
-- ("Minerar"); cada golpe é validado aqui (distância, intervalo mínimo pela picareta) e os pets da
-- equipe por perto aumentam a força. Quebrar um veio dá cristais (itens) a quem bateu nele, conta
-- para as missões (mine_crystal) e pode dar um Coração Prismático (sorte de Drop).
-- Contratos de mineração (entregas diárias) e a melhoria da picareta também passam por aqui.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Mining = require(Shared.Config.Mining)
local Worlds = require(Shared.Config.Worlds)
local Items = require(Shared.Config.Items)
local MiningLogic = require(Shared.Logic.MiningLogic)
local InventoryLogic = require(Shared.Logic.InventoryLogic)
local LuckLogic = require(Shared.Logic.LuckLogic)
local Make = require(Shared.Util.Make)
local VerdantLowlands = require(script.Parent.VerdantLowlands)

local MiningService = {}

local S
local rng = Random.new()
local veins: { any } = {}
local lastStrike: { [Player]: number } = {}
local folder: Folder?

local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

MiningService.veins = veins -- (testes)

function MiningService.init(registry)
	S = registry
end

local function today(): number
	return math.floor(os.time() / 86400)
end

-------------------------------------------------------------------------------
-- Modelo do veio: rocha com cristais saindo, brilho e o prompt "Minerar"
-------------------------------------------------------------------------------
local function buildVein(vein)
	local cfg = vein.cfg
	local color = Mining.Crystals[cfg.crystal].color
	local m = Make("Model", { Name = "CrystalVein" })
	local base = Make("Part", { Name = "VeinRock", Shape = Enum.PartType.Ball, Size = V(5, 3.2, 5), CFrame = CF(vein.pos + V(0, 0.9, 0)), Color = rgb(78, 74, 84),
		Material = Enum.Material.Slate, Anchored = true, CanCollide = true, Parent = m })
	m.PrimaryPart = base
	local yaw = rng:NextNumber(0, math.pi * 2)
	for k = 1, 5 do
		local a = yaw + k * 1.26
		local h = 2.2 + (k % 3) * 0.9
		local p = vein.pos + V(math.cos(a) * 1.1, 1.6 + h / 2, math.sin(a) * 1.1)
		local cry = Make("Part", { Name = "VeinCrystal", Size = V(0.9, h, 0.9), CFrame = CF(p) * CFrame.Angles(math.cos(a) * 0.45, a, math.sin(a) * 0.45),
			Color = color, Material = k == 1 and Enum.Material.Neon or Enum.Material.Glass, Transparency = k == 1 and 0 or 0.15, Anchored = true, CanCollide = false, Parent = m })
		-- ponta lisa (elipsoide) no alto de cada cristal
		local tip = Make("Part", { Name = "VeinTip", Size = V(0.9, 1.2, 0.9), CFrame = cry.CFrame * CF(0, h / 2, 0), Color = color, Material = Enum.Material.Glass,
			Transparency = 0.15, Anchored = true, CanCollide = false, Parent = m })
		Make("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = tip })
	end
	local core = Make("Part", { Name = "VeinCore", Size = V(1, 1, 1), CFrame = CF(vein.pos + V(0, 2.4, 0)), Transparency = 1, Anchored = true, CanCollide = false, Parent = m })
	Make("PointLight", { Color = color, Range = 12, Brightness = 1.2, Parent = core })
	local prompt = Make("ProximityPrompt", { Name = "MinePrompt", ActionText = "Minerar", ObjectText = cfg.label, HoldDuration = Mining.Pickaxes[1].hold,
		MaxActivationDistance = Mining.Range, RequiresLineOfSight = false, Parent = core })
	m:SetAttribute("VeinKind", vein.kind)
	m:SetAttribute("Crystal", cfg.crystal)
	m:SetAttribute("Label", cfg.label)
	m:SetAttribute("Health", cfg.hp)
	m:SetAttribute("MaxHealth", cfg.hp)
	m:SetAttribute("World", vein.world)
	prompt.Triggered:Connect(function(player)
		MiningService.strike(player, vein)
	end)
	vein.prompt = prompt
	return m
end

local function spawnVein(vein)
	vein.hp = vein.cfg.hp
	vein.contrib = {}
	vein.alive = true
	vein.model = buildVein(vein)
	vein.model.Parent = folder
end

-------------------------------------------------------------------------------
-- Golpes e quebra
-------------------------------------------------------------------------------
local function breakVein(vein)
	vein.alive = false
	local color = Mining.Crystals[vein.cfg.crystal].color
	for player in pairs(vein.contrib) do
		local data = player.Parent and S.DataService.get(player)
		if data then
			local _, lvl = MiningLogic.pickaxe(data)
			local mults = S.LuckService.mults(player)
			local rare = LuckLogic.applyChance(Mining.RareChance, mults.Drop or 1, 1, Mining.RareMaxChance)
			local got = MiningLogic.yield(vein.kind, lvl, function(a, b)
				return rng:NextInteger(a, b)
			end, function()
				return S.RewardService.random()
			end, rare)
			local granted, total = {}, 0
			for id, n in pairs(got) do
				if n > 0 and InventoryLogic.add(data, id, n) then
					total += n
					table.insert(granted, { item = id, amount = n, notable = Mining.Crystals[id].rare == true })
					S.QuestService.event(player, { type = "mine_crystal", target = id, world = vein.world, amount = n })
				end
			end
			data.mining.mined += total
			data.mining.veins += 1
			if got.prism_heart then
				S.Push:FireClient(player, "Toast", { text = "✦ Coração Prismático encontrado no " .. vein.cfg.label .. "!", kind = "luck" })
			end
			S.Push:FireClient(player, "Drop", { source = vein.cfg.label, items = granted })
			S.DataService.markDirty(player)
		end
	end
	S.CombatService.fx("burst", { at = vein.pos + V(0, 2.5, 0), radius = 6, color = color })
	if vein.model then
		vein.model:Destroy()
		vein.model = nil
	end
	task.delay(vein.cfg.respawn, function()
		if folder and folder.Parent then
			spawnVein(vein)
		end
	end)
end

-- Um golpe de picareta (do ProximityPrompt). Devolve { ok, msg?, power?, hp? }.
function MiningService.strike(player: Player, vein)
	local data = S.DataService.get(player)
	if not data or not vein or not vein.alive then
		return { ok = false }
	end
	local root = S.CombatService.charRoot(player)
	if not root or (root.Position - vein.pos).Magnitude > Mining.Range + 4 then
		return { ok = false, msg = "Longe demais do veio" }
	end
	local _, lvl = MiningLogic.pickaxe(data)
	local now = os.clock()
	if lastStrike[player] and now - lastStrike[player] < MiningLogic.minInterval(lvl) then
		return { ok = false, msg = "Rápido demais" } -- (o tempo de segurar o botão é conferido aqui)
	end
	lastStrike[player] = now
	local helpers = 0
	for _, st in ipairs(S.PetService.team(player)) do
		if st.model and st.model.Parent and st.root and os.clock() >= (st.knockedUntil or 0) and (st.root.Position - vein.pos).Magnitude <= Mining.PetHelpRange then
			helpers += 1
			S.CombatService.setAction(st.model, "Attack")
		end
	end
	local power = MiningLogic.strikePower(lvl, helpers)
	vein.hp = math.max(0, vein.hp - power)
	vein.contrib[player] = true
	if vein.model then
		vein.model:SetAttribute("Health", vein.hp)
	end
	S.CombatService.fx("burst", { at = vein.pos + V(0, 2.2, 0), radius = 2, color = Mining.Crystals[vein.cfg.crystal].color })
	if vein.hp <= 0 then
		breakVein(vein)
	end
	return { ok = true, power = power, hp = vein.hp }
end

-------------------------------------------------------------------------------
-- Contratos e picareta (pedidos do painel de Missões)
-------------------------------------------------------------------------------
function MiningService.view(player: Player)
	local data = S.DataService.get(player)
	if not data then
		return { ok = false }
	end
	MiningLogic.ensureContracts(data, today())
	return { ok = true }
end

function MiningService.deliver(player: Player, id: string)
	local data = S.DataService.get(player)
	if not data or type(id) ~= "string" then
		return { ok = false }
	end
	MiningLogic.ensureContracts(data, today())
	local reward, ct = MiningLogic.deliver(data, id)
	if not reward then
		return { ok = false, msg = ct }
	end
	S.RewardService.grantBundle(player, reward, "Contrato: " .. ct.label, "contract:" .. id .. ":" .. today())
	S.QuestService.event(player, { type = "mining_contract", target = id })
	S.DataService.markDirty(player)
	return { ok = true, msg = "Contrato entregue: " .. ct.label }
end

function MiningService.upgrade(player: Player)
	local data = S.DataService.get(player)
	if not data then
		return { ok = false }
	end
	local lvl, why = MiningLogic.upgrade(data)
	if not lvl then
		return { ok = false, msg = why }
	end
	S.DataService.markDirty(player)
	player:SetAttribute("Pickaxe", lvl)
	return { ok = true, msg = "Nova picareta: " .. Mining.Pickaxes[lvl].label }
end

-------------------------------------------------------------------------------
-- Posições dos veios
-------------------------------------------------------------------------------
local function ground(pos: Vector3, exclude: { Instance }): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(pos + V(0, 60, 0), V(0, -160, 0), params)
	return hit and V(pos.X, hit.Position.Y, pos.Z) or nil
end

function MiningService.start()
	folder = Make("Folder", { Name = "CrystalVeins", Parent = workspace })
	local function add(kind: string, worldId: string, pos: Vector3)
		local vein = { kind = kind, cfg = Mining.Veins[kind], world = worldId, pos = pos }
		table.insert(veins, vein)
		spawnVein(vein)
	end
	-- Mundo 1: dois veios em cada salão das Cavernas Esmeralda (no chão escavado)
	local low = S.WorldService.Lowlands
	if low and low.cave and low.cave.halls then
		for i, hp in ipairs(low.cave.halls) do
			local h = VerdantLowlands.Cave.halls[i]
			if h then
				local floorY = hp.Y - h.r * 0.78 + 1
				for k = 0, 1 do
					local a = i * 1.3 + k * math.pi
					local d = h.r * 0.42
					add("emerald", "verdant", V(hp.X + math.cos(a) * d, floorY, hp.Z + math.sin(a) * d))
				end
			end
		end
	end
	-- outros mundos: veios em volta dos campos de recursos
	local exclude = { folder }
	for _, name in ipairs({ "Resources", "Enemies", "Pets", "Characters" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, worldId in ipairs(Worlds.Order) do
		local kinds = Mining.WorldVeins[worldId]
		local layout = S.WorldService.Layout[worldId]
		if kinds and worldId ~= "verdant" and layout then
			local n = 0
			for fi, field in ipairs(layout.resourceFields or {}) do
				if fi > 3 then
					break
				end
				for k = 1, Mining.VeinsPerField do
					n += 1
					local a = fi * 0.9 + k * (math.pi * 2 / Mining.VeinsPerField)
					local d = field.radius + 7
					local pos = ground(field.center + V(math.cos(a) * d, 0, math.sin(a) * d), exclude)
					if pos then
						add(kinds[(n - 1) % #kinds + 1], worldId, pos)
					end
				end
			end
		end
	end
	Players.PlayerRemoving:Connect(function(p)
		lastStrike[p] = nil
	end)
	S.DataService.onLoaded(function(player, data)
		MiningLogic.ensureContracts(data, today())
		local _, lvl = MiningLogic.pickaxe(data)
		player:SetAttribute("Pickaxe", lvl)
	end)
	local _ = Items
end

return MiningService

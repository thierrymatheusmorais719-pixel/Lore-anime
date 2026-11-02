-- Construção procedural das ilhas: terreno, decoração temática, estações de ovos, portais
-- e arenas de boss. Usado pelo WorldService (não é um serviço por si só).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local Eggs = require(Shared.Config.Eggs)
local Make = require(Shared.Util.Make)

local WorldBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB
local Terrain = workspace.Terrain

local CLIFF_COLORS = {
	Rock = rgb(110, 100, 90),
	Basalt = rgb(46, 44, 60),
	Limestone = rgb(205, 205, 215),
	Mud = rgb(70, 60, 56),
	Concrete = rgb(52, 44, 82),
}

local function part(props)
	props.Anchored = true
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	if props.CanCollide == nil then
		props.CanCollide = true
	end
	return Make("Part", props)
end

local function ellipsoid(props)
	local p = part(props)
	Make("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
	return p
end

-- Posição no anel da ilha (θ em graus, 0 = +X, 90 = +Z)
function WorldBuilder.polar(center: Vector3, theta: number, dist: number, y: number?): Vector3
	return center + V(math.cos(rad(theta)) * dist, y or 0, math.sin(rad(theta)) * dist)
end

-- Layout fixo (mesmo para todas as ilhas) — evita sobreposição entre zonas.
WorldBuilder.Layout = {
	arena = { theta = 90, dist = 140 },
	portalNext = { theta = 262, dist = 42 },
	portalPrev = { theta = 278, dist = 42 },
	eggs = { { theta = 200, dist = 32 }, { theta = 340, dist = 32 } },
	resources = { { theta = 0, dist = 108, r = 42 }, { theta = 180, dist = 108, r = 42 } },
	enemyZones = { { theta = 222, dist = 150, r = 30 }, { theta = 270, dist = 160, r = 30 }, { theta = 318, dist = 150, r = 30 } },
}

-------------------------------------------------------------------------------
-- Terreno
-------------------------------------------------------------------------------

function WorldBuilder.terrain(worldId: string)
	local w = Worlds.Info[worldId]
	local c, r = w.center, w.radius
	local ground = Enum.Material[w.ground]
	local cliff = Enum.Material[w.cliff]
	Terrain:SetMaterialColor(ground, w.palette.ground)
	Terrain:SetMaterialColor(cliff, CLIFF_COLORS[w.cliff] or rgb(100, 100, 100))
	Terrain:FillCylinder(CF(c - V(0, 6, 0)), 12, r, ground)
	Terrain:FillCylinder(CF(c - V(0, 26, 0)), 28, r * 0.93, cliff)
	Terrain:FillBall(c - V(0, 52, 0), r * 0.72, cliff)
	Terrain:FillBall(c - V(0, 105, 0), r * 0.38, cliff)
	-- algumas colinas suaves na borda (sem bloquear caminhos)
	local rng = Random.new(w.index * 97)
	for i = 1, 10 do
		local theta = i * 36 + rng:NextNumber(-8, 8)
		local pos = WorldBuilder.polar(c, theta, r - rng:NextNumber(10, 22), -8)
		Terrain:FillBall(pos, rng:NextNumber(12, 18), i % 3 == 0 and cliff or ground)
	end
end

-- Muro invisível na borda para ninguém cair da ilha.
function WorldBuilder.boundary(worldId: string, parent: Instance)
	local w = Worlds.Info[worldId]
	local n = 40
	for i = 1, n do
		local a = (i - 0.5) / n * math.pi * 2
		local pos = w.center + V(math.cos(a) * (w.radius + 1), 15, math.sin(a) * (w.radius + 1))
		part({
			Name = "Boundary", Size = V(2, 40, 2 * math.pi * (w.radius + 1) / n + 1), CFrame = CF(pos) * ANG(0, -a, 0),
			Transparency = 1, CanQuery = false, Parent = parent,
		})
	end
end

-------------------------------------------------------------------------------
-- Decoração
-------------------------------------------------------------------------------

local function tree(parent, pos: Vector3, scale: number, trunkColor: Color3, leafColor: Color3, glow: Color3?)
	local h = 10 * scale
	part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = V(h, 2 * scale, 2 * scale), CFrame = CF(pos + V(0, h / 2, 0)) * ANG(0, 0, rad(90)),
		Color = trunkColor, Material = Enum.Material.Wood, Parent = parent })
	for i, o in ipairs({ { 0, h + 1.5 * scale, 0, 7 }, { 2.4, h - 0.5 * scale, 1, 5 }, { -2.2, h, -1.4, 5.4 } }) do
		part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * o[4] * scale, CFrame = CF(pos + V(o[1] * scale, o[2], o[3] * scale)),
			Color = leafColor:Lerp(rgb(255, 255, 255), i * 0.03), Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
	end
	if glow then
		for k = 1, 3 do
			local a = k * 2.1
			part({ Name = "GlowFruit", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7 * scale, CFrame = CF(pos + V(math.cos(a) * 3 * scale, h - 1, math.sin(a) * 3 * scale)),
				Color = glow, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
		end
	end
end

local function rock(parent, pos: Vector3, scale: number, color: Color3, material: Enum.Material?)
	local p = part({ Name = "Rock", Size = V(4, 3, 3.5) * scale, CFrame = CF(pos + V(0, 1 * scale, 0)) * ANG(rad(10), math.random() * 6, rad(-8)),
		Color = color, Material = material or Enum.Material.Slate, Parent = parent })
	return p
end

local function crystal(parent, pos: Vector3, scale: number, color: Color3)
	for i = 1, 3 do
		part({ Name = "Crystal", Size = V(1.6, 7 - i * 1.4, 1.6) * scale, CFrame = CF(pos + V((i - 2) * 1.2 * scale, (3 - i * 0.6) * scale, 0)) * ANG(rad((i - 2) * 18), rad(i * 40), rad((i - 2) * 12)),
			Color = color, Material = Enum.Material.Glass, Transparency = 0.15, Parent = parent })
	end
	part({ Name = "CrystalGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2 * scale, CFrame = CF(pos + V(0, 0.6 * scale, 0)), Color = color, Material = Enum.Material.Neon,
		CanCollide = false, Parent = parent })
end

local function cloud(parent, pos: Vector3, scale: number)
	for i, o in ipairs({ { 0, 0, 0, 8 }, { 5, -1, 1, 6 }, { -5, -1, -1, 6 }, { 2, 2, -2, 5 } }) do
		part({ Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.one * o[4] * scale, CFrame = CF(pos + V(o[1], o[2], o[3]) * scale),
			Color = rgb(250, 252, 255), Material = Enum.Material.SmoothPlastic, Transparency = 0.1 + i * 0.03, CanCollide = false, CastShadow = false, Parent = parent })
	end
end

local function pillar(parent, pos: Vector3, height: number, color: Color3, trim: Color3, material: Enum.Material?)
	part({ Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = V(height, 3, 3), CFrame = CF(pos + V(0, height / 2, 0)) * ANG(0, 0, rad(90)),
		Color = color, Material = material or Enum.Material.Marble, Parent = parent })
	part({ Name = "PillarCap", Size = V(4, 1, 4), CFrame = CF(pos + V(0, height + 0.5, 0)), Color = trim, Material = Enum.Material.Marble, Parent = parent })
	part({ Name = "PillarBase", Size = V(4, 1, 4), CFrame = CF(pos + V(0, 0.5, 0)), Color = trim, Material = Enum.Material.Marble, Parent = parent })
end

local function mushroom(parent, pos: Vector3, scale: number, capColor: Color3)
	part({ Name = "Stem", Shape = Enum.PartType.Cylinder, Size = V(3 * scale, 0.8 * scale, 0.8 * scale), CFrame = CF(pos + V(0, 1.5 * scale, 0)) * ANG(0, 0, rad(90)),
		Color = rgb(230, 220, 200), Parent = parent })
	local cap = ellipsoid({ Name = "Cap", Size = V(3.4, 1.4, 3.4) * scale, CFrame = CF(pos + V(0, 3.1 * scale, 0)), Color = capColor, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	Make("PointLight", { Color = capColor, Range = 10 * scale, Brightness = 0.8, Shadows = false, Parent = cap })
end

local function lantern(parent, pos: Vector3, color: Color3)
	part({ Name = "Post", Size = V(0.5, 6, 0.5), CFrame = CF(pos + V(0, 3, 0)), Color = rgb(60, 50, 40), Material = Enum.Material.Wood, Parent = parent })
	local lamp = part({ Name = "Lamp", Size = V(1.2, 1.4, 1.2), CFrame = CF(pos + V(0, 6.5, 0)), Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	Make("PointLight", { Color = color, Range = 16, Brightness = 1.2, Shadows = false, Parent = lamp })
end

local function floatingShard(parent, pos: Vector3, scale: number, color: Color3)
	part({ Name = "FloatingShard", Size = V(2, 5, 2) * scale, CFrame = CF(pos) * ANG(rad(20), math.random() * 6, rad(15)), Color = color, Material = Enum.Material.Neon,
		Transparency = 0.1, CanCollide = false, CastShadow = false, Parent = parent })
end

-- Lista de pontos livres para decoração (evita praça, arena, campos de recurso e zonas de inimigos).
local function freeSpot(center: Vector3, radius: number, rng: Random)
	local L = WorldBuilder.Layout
	for _ = 1, 30 do
		local theta = rng:NextNumber(0, 360)
		local dist = rng:NextNumber(55, radius - 14)
		local pos = WorldBuilder.polar(center, theta, dist)
		local ok = true
		local arena = WorldBuilder.polar(center, L.arena.theta, L.arena.dist)
		if (pos - arena).Magnitude < 90 then
			ok = false
		end
		for _, f in ipairs(L.resources) do
			if (pos - WorldBuilder.polar(center, f.theta, f.dist)).Magnitude < f.r + 6 then
				ok = false
			end
		end
		for _, z in ipairs(L.enemyZones) do
			if (pos - WorldBuilder.polar(center, z.theta, z.dist)).Magnitude < z.r + 4 then
				ok = false
			end
		end
		if ok then
			return pos
		end
	end
	return nil
end

function WorldBuilder.decor(worldId: string, parent: Instance)
	local w = Worlds.Info[worldId]
	local c = w.center
	local rng = Random.new(w.index * 1337)
	local folder = Make("Folder", { Name = "Decor", Parent = parent })
	local count = 46
	for i = 1, count do
		local pos = freeSpot(c, w.radius, rng)
		if pos then
			local s = rng:NextNumber(0.8, 1.4)
			if worldId == "verdant" then
				if i % 3 == 0 then
					rock(folder, pos, s, rgb(120, 116, 104))
				else
					tree(folder, pos, s, rgb(110, 78, 50), rgb(90, 160, 70))
				end
			elseif worldId == "crystal" then
				if i % 2 == 0 then
					crystal(folder, pos, s, i % 4 == 0 and rgb(200, 140, 255) or rgb(120, 220, 255))
				else
					rock(folder, pos, s * 1.6, rgb(50, 48, 66), Enum.Material.Basalt)
				end
			elseif worldId == "sky" then
				if i % 3 == 0 then
					pillar(folder, pos, rng:NextNumber(10, 18), rgb(240, 240, 248), rgb(230, 200, 120))
				else
					cloud(folder, pos + V(0, rng:NextNumber(3, 10), 0), s)
				end
			elseif worldId == "wilds" then
				if i % 3 == 0 then
					mushroom(folder, pos, s, i % 2 == 0 and rgb(170, 140, 255) or rgb(120, 255, 210))
				elseif i % 3 == 1 then
					tree(folder, pos, s * 1.3, rgb(60, 48, 44), rgb(46, 84, 60), rgb(190, 255, 220))
				else
					lantern(folder, pos, rgb(255, 210, 140))
				end
			elseif worldId == "astral" then
				if i % 2 == 0 then
					pillar(folder, pos, rng:NextNumber(12, 22), rgb(80, 72, 130), rgb(240, 200, 120), Enum.Material.Marble)
				else
					floatingShard(folder, pos + V(0, rng:NextNumber(8, 16), 0), s, i % 4 == 1 and rgb(255, 220, 150) or rgb(170, 140, 255))
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Praça central (área segura)
-------------------------------------------------------------------------------

function WorldBuilder.plaza(worldId: string, parent: Instance)
	local w = Worlds.Info[worldId]
	local c = w.center
	local folder = Make("Folder", { Name = "Plaza", Parent = parent })
	part({ Name = "PlazaFloor", Shape = Enum.PartType.Cylinder, Size = V(1, 52, 52), CFrame = CF(c + V(0, 0.4, 0)) * ANG(0, 0, rad(90)),
		Color = rgb(214, 206, 190), Material = Enum.Material.Cobblestone, Parent = folder })
	part({ Name = "PlazaRing", Shape = Enum.PartType.Cylinder, Size = V(1.1, 30, 30), CFrame = CF(c + V(0, 0.45, 0)) * ANG(0, 0, rad(90)),
		Color = w.palette.accent, Material = Enum.Material.Marble, Parent = folder })
	-- Monumento central: cristal-farol do mundo
	part({ Name = "Monument", Size = V(3, 10, 3), CFrame = CF(c + V(0, 5.9, 0)) * ANG(0, rad(45), 0), Color = rgb(235, 232, 220), Material = Enum.Material.Marble, Parent = folder })
	local beacon = part({ Name = "Beacon", Size = V(2.4, 4, 2.4), CFrame = CF(c + V(0, 13, 0)) * ANG(rad(45), rad(45), 0), Color = w.palette.accent, Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
	Make("PointLight", { Color = w.palette.accent, Range = 30, Brightness = 1.5, Parent = beacon })
	local spawn
	if worldId == Worlds.Order[1] then
		spawn = Make("SpawnLocation", { Name = "Spawn", Size = V(10, 1, 10), CFrame = CF(c + V(0, 0.5, 14)), Anchored = true, Transparency = 1, CanCollide = false,
			Duration = 0, Neutral = true, Parent = folder })
	end
	return CF(c + V(0, 4, 14)), spawn
end

-------------------------------------------------------------------------------
-- Estação de ovos
-------------------------------------------------------------------------------

function WorldBuilder.eggStation(eggId: string, pos: Vector3, parent: Instance)
	local egg = Eggs.Info[eggId]
	local folder = Make("Model", { Name = "EggStation_" .. eggId, Parent = parent })
	local base = part({ Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = V(2, 9, 9), CFrame = CF(pos + V(0, 1, 0)) * ANG(0, 0, rad(90)),
		Color = rgb(235, 230, 220), Material = Enum.Material.Marble, Parent = folder })
	folder.PrimaryPart = base -- GetPivot() da estação = pedestal (usado na checagem de distância)
	part({ Name = "PedestalTrim", Shape = Enum.PartType.Cylinder, Size = V(0.4, 9.6, 9.6), CFrame = CF(pos + V(0, 2.1, 0)) * ANG(0, 0, rad(90)),
		Color = egg.spot, Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
	local shell = ellipsoid({ Name = "Egg", Size = V(4.2, 5.4, 4.2), CFrame = CF(pos + V(0, 5.8, 0)), Color = egg.color, Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = folder })
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local y = (i % 2 == 0) and 0.8 or -0.6
		local spotPos = shell.Position + V(math.cos(a) * 1.95, y, math.sin(a) * 1.95)
		ellipsoid({ Name = "Spot", Size = V(0.9, 0.9, 0.3), CFrame = CF(spotPos, shell.Position) , Color = egg.spot, Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
	end
	Make("PointLight", { Color = egg.spot, Range = 12, Brightness = 1, Parent = shell })
	local sign = Make("BillboardGui", { Name = "Label", Size = UDim2.fromOffset(220, 60), StudsOffset = V(0, 5, 0), AlwaysOnTop = false, MaxDistance = 80, Parent = shell })
	Make("TextLabel", { Size = UDim2.fromScale(1, 0.55), BackgroundTransparency = 1, Text = egg.name, TextScaled = true, Font = Enum.Font.FredokaOne,
		TextColor3 = rgb(255, 255, 255), TextStrokeTransparency = 0.4, Parent = sign })
	local cost = egg.currency == "coins" and (tostring(egg.cost) .. " Moedas") or (tostring(egg.cost) .. " Essência")
	Make("TextLabel", { Position = UDim2.fromScale(0, 0.55), Size = UDim2.fromScale(1, 0.45), BackgroundTransparency = 1, Text = cost, TextScaled = true,
		Font = Enum.Font.GothamBold, TextColor3 = egg.currency == "coins" and rgb(255, 214, 80) or rgb(120, 240, 210), TextStrokeTransparency = 0.5, Parent = sign })
	local prompt = Make("ProximityPrompt", { Name = "HatchPrompt", ActionText = "Ver ovo", ObjectText = egg.name, HoldDuration = 0, MaxActivationDistance = 14,
		RequiresLineOfSight = false, KeyboardKeyCode = Enum.KeyCode.E, Parent = base })
	folder:SetAttribute("EggId", eggId)
	prompt:SetAttribute("EggId", eggId)
	return folder, prompt, shell
end

-------------------------------------------------------------------------------
-- Portal
-------------------------------------------------------------------------------

function WorldBuilder.portal(pos: Vector3, facing: Vector3, color: Color3, label: string, parent: Instance)
	local model = Make("Model", { Name = "Portal", Parent = parent })
	local cf = CF(pos, pos + facing)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "PortalPillar", Size = V(2, 14, 2), CFrame = cf * CF(side * 6, 7, 0), Color = rgb(230, 228, 220), Material = Enum.Material.Marble, Parent = model })
	end
	part({ Name = "PortalLintel", Size = V(15, 2, 2.4), CFrame = cf * CF(0, 14.5, 0), Color = rgb(230, 228, 220), Material = Enum.Material.Marble, Parent = model })
	local field = part({ Name = "PortalField", Size = V(10, 12.5, 0.4), CFrame = cf * CF(0, 7, 0), Color = color, Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, Parent = model })
	Make("PointLight", { Color = color, Range = 18, Brightness = 2, Parent = field })
	local gui = Make("BillboardGui", { Size = UDim2.fromOffset(260, 50), StudsOffset = V(0, 10, 0), MaxDistance = 90, Parent = field })
	local text = Make("TextLabel", { Name = "Text", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = label, TextScaled = true, Font = Enum.Font.FredokaOne,
		TextColor3 = rgb(255, 255, 255), TextStrokeTransparency = 0.3, Parent = gui })
	local prompt = Make("ProximityPrompt", { Name = "PortalPrompt", ActionText = "Viajar", ObjectText = label, HoldDuration = 0.3, MaxActivationDistance = 12,
		RequiresLineOfSight = false, Parent = field })
	return model, prompt, text
end

-------------------------------------------------------------------------------
-- Arena de boss
-------------------------------------------------------------------------------

local ARENA_THEME = {
	verdant = { floor = rgb(110, 92, 70), floorMat = Enum.Material.Wood, pillar = rgb(96, 70, 48), trim = rgb(150, 230, 110), deco = "roots" },
	crystal = { floor = rgb(40, 40, 58), floorMat = Enum.Material.Basalt, pillar = rgb(60, 60, 84), trim = rgb(140, 220, 255), deco = "crystals" },
	sky = { floor = rgb(235, 236, 244), floorMat = Enum.Material.Marble, pillar = rgb(245, 245, 250), trim = rgb(120, 190, 255), deco = "clouds" },
	wilds = { floor = rgb(52, 66, 54), floorMat = Enum.Material.Slate, pillar = rgb(60, 48, 44), trim = rgb(200, 140, 255), deco = "blooms" },
	astral = { floor = rgb(36, 30, 64), floorMat = Enum.Material.Marble, pillar = rgb(70, 62, 120), trim = rgb(255, 210, 130), deco = "stars" },
}

function WorldBuilder.arena(worldId: string, center: Vector3, radius: number, parent: Instance)
	local theme = ARENA_THEME[worldId]
	local folder = Make("Folder", { Name = "Arena", Parent = parent })
	part({ Name = "ArenaFloor", Shape = Enum.PartType.Cylinder, Size = V(1.2, radius * 2, radius * 2), CFrame = CF(center + V(0, 0.4, 0)) * ANG(0, 0, rad(90)),
		Color = theme.floor, Material = theme.floorMat, Parent = folder })
	part({ Name = "ArenaInner", Shape = Enum.PartType.Cylinder, Size = V(1.25, radius * 0.6, radius * 0.6), CFrame = CF(center + V(0, 0.42, 0)) * ANG(0, 0, rad(90)),
		Color = theme.floor:Lerp(theme.trim, 0.15), Material = theme.floorMat, Parent = folder })
	-- borda luminosa (limite do combate)
	local n = 36
	for i = 1, n do
		local a = (i - 0.5) / n * math.pi * 2
		part({ Name = "ArenaEdge", Size = V(1, 0.3, 2 * math.pi * radius / n), CFrame = CF(center + V(math.cos(a) * radius, 1.05, math.sin(a) * radius)) * ANG(0, -a, 0),
			Color = theme.trim, Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
	end
	-- pilares com luz
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local pos = center + V(math.cos(a) * (radius + 4), 0, math.sin(a) * (radius + 4))
		pillar(folder, pos, 16, theme.pillar, theme.pillar:Lerp(theme.trim, 0.3), theme.floorMat)
		local flame = part({ Name = "Brazier", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, CFrame = CF(pos + V(0, 18, 0)), Color = theme.trim,
			Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
		Make("PointLight", { Color = theme.trim, Range = 26, Brightness = 1.4, Shadows = false, Parent = flame })
		if theme.deco == "crystals" then
			crystal(folder, pos + V(math.cos(a) * 6, 0, math.sin(a) * 6), 2.2, theme.trim)
		elseif theme.deco == "roots" then
			tree(folder, pos + V(math.cos(a) * 9, 0, math.sin(a) * 9), 1.6, rgb(90, 66, 46), rgb(70, 130, 60), theme.trim)
		elseif theme.deco == "clouds" then
			cloud(folder, pos + V(math.cos(a) * 10, 6, math.sin(a) * 10), 1.4)
		elseif theme.deco == "blooms" then
			mushroom(folder, pos + V(math.cos(a) * 7, 0, math.sin(a) * 7), 2, theme.trim)
		elseif theme.deco == "stars" then
			floatingShard(folder, pos + V(math.cos(a) * 6, 14, math.sin(a) * 6), 1.6, theme.trim)
		end
	end
	-- arco de entrada voltado para o centro da ilha
	local island = Worlds.Info[worldId].center
	local dir = (island - center) * V(1, 0, 1)
	dir = dir.Magnitude > 0 and dir.Unit or V(0, 0, -1)
	local gatePos = center + dir * (radius + 2)
	local gateCf = CF(gatePos, gatePos + dir)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "GatePillar", Size = V(3, 18, 3), CFrame = gateCf * CF(side * 9, 9, 0), Color = theme.pillar, Material = theme.floorMat, Parent = folder })
	end
	part({ Name = "GateLintel", Size = V(22, 3, 3.4), CFrame = gateCf * CF(0, 19, 0), Color = theme.pillar, Material = theme.floorMat, Parent = folder })
	local banner = part({ Name = "GateBanner", Size = V(14, 2.4, 0.3), CFrame = gateCf * CF(0, 16, -1.8), Color = theme.trim, Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
	return folder, banner
end

return WorldBuilder

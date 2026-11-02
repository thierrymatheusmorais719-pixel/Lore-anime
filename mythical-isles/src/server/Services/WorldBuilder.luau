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
	verdantLake = { theta = 140, dist = 160, r = 38 }, -- lago da Árvore Ancestral (Mundo 1)
}

-------------------------------------------------------------------------------
-- Terreno
-------------------------------------------------------------------------------

local function terrainFill(w)
	local Terrain = workspace:FindFirstChildOfClass("Terrain")
	if not Terrain then
		error("Workspace sem Terrain")
	end
	local c, r = w.center, w.radius
	local ground = Enum.Material[w.ground]
	local cliff = Enum.Material[w.cliff]
	Terrain:SetMaterialColor(ground, w.palette.ground)
	Terrain:SetMaterialColor(cliff, CLIFF_COLORS[w.cliff] or rgb(100, 100, 100))
	Terrain:FillCylinder(CF(c - V(0, 6, 0)), 12, r, ground)
	-- parte de baixo da ilha flutuante: camadas que afinam para baixo, TODAS abaixo do chão
	-- (antes era uma esfera grande cujo topo saía acima da grama e cobria a ilha)
	Terrain:FillCylinder(CF(c - V(0, 26, 0)), 28, r * 0.93, cliff)
	Terrain:FillCylinder(CF(c - V(0, 50, 0)), 20, r * 0.76, cliff)
	Terrain:FillCylinder(CF(c - V(0, 68, 0)), 16, r * 0.56, cliff)
	Terrain:FillCylinder(CF(c - V(0, 82, 0)), 12, r * 0.38, cliff)
	Terrain:FillBall(c - V(0, 96, 0), r * 0.2, cliff)
	-- algumas colinas suaves na borda (sem bloquear caminhos)
	local rng = Random.new(w.index * 97)
	for i = 1, 10 do
		local theta = i * 36 + rng:NextNumber(-8, 8)
		local pos = WorldBuilder.polar(c, theta, r - rng:NextNumber(10, 22), -8)
		Terrain:FillBall(pos, rng:NextNumber(12, 18), i % 3 == 0 and cliff or ground)
	end
end

-- Alternativa sem Terrain: a ilha é feita de peças (mesmo formato e cores).
local function partIsland(w, parent: Instance)
	local folder = Make("Folder", { Name = "IslandParts", Parent = parent })
	local c, r = w.center, w.radius
	local function mat(name, fallback)
		local ok, m = pcall(function()
			return Enum.Material[name]
		end)
		return ok and m or fallback
	end
	local top = part({ Name = "IslandTop", Shape = Enum.PartType.Cylinder, Size = V(12, r * 2, r * 2), CFrame = CF(c - V(0, 6, 0)) * ANG(0, 0, rad(90)),
		Color = w.palette.ground, Parent = folder })
	pcall(function()
		top.Material = mat(w.ground, Enum.Material.Grass)
	end)
	local cliffColor = CLIFF_COLORS[w.cliff] or rgb(100, 100, 100)
	local mid = part({ Name = "IslandCliff", Shape = Enum.PartType.Cylinder, Size = V(28, r * 1.86, r * 1.86), CFrame = CF(c - V(0, 26, 0)) * ANG(0, 0, rad(90)),
		Color = cliffColor, Parent = folder })
	local low = part({ Name = "IslandRoot", Shape = Enum.PartType.Cylinder, Size = V(20, r * 1.5, r * 1.5), CFrame = CF(c - V(0, 50, 0)) * ANG(0, 0, rad(90)), Color = cliffColor, Parent = folder })
	local tip = part({ Name = "IslandTip", Shape = Enum.PartType.Cylinder, Size = V(16, r * 0.9, r * 0.9), CFrame = CF(c - V(0, 68, 0)) * ANG(0, 0, rad(90)), Color = cliffColor, Parent = folder })
	for _, p in ipairs({ mid, low, tip }) do
		pcall(function()
			p.Material = mat(w.cliff, Enum.Material.Rock)
		end)
	end
end

function WorldBuilder.terrain(worldId: string, parent: Instance)
	local w = Worlds.Info[worldId]
	local ok, err = pcall(terrainFill, w)
	if not ok then
		warn("[WorldBuilder] Terrain indisponível (" .. tostring(err) .. "): ilha " .. worldId .. " feita com peças")
		partIsland(w, parent)
	end
	return ok
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
local function freeSpot(center: Vector3, radius: number, rng: Random, worldId: string?)
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
		if worldId == "verdant" then
			local lake = L.verdantLake
			if (pos - WorldBuilder.polar(center, lake.theta, lake.dist)).Magnitude < lake.r + 34 then
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
		local pos = freeSpot(c, w.radius, rng, worldId)
		if pos then
			local s = rng:NextNumber(0.8, 1.4)
			if worldId == "verdant" then
				local k = i % 6
				if k == 0 then
					WorldBuilder.mossRock(folder, pos, s * 1.2)
				elseif k == 1 or k == 4 then
					WorldBuilder.bonsai(folder, pos, s * 1.1, rng, i % 4 == 1 and rgb(170, 120, 220) or rgb(110, 185, 70))
				elseif k == 2 then
					WorldBuilder.flowerBush(folder, pos, s, rng, rgb(160, 110, 230))
				elseif k == 3 then
					tree(folder, pos, s, rgb(100, 72, 48), rgb(80, 160, 70))
				else
					WorldBuilder.flowerBush(folder, pos, s * 0.9, rng, rgb(255, 150, 200))
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
-- Mundo 1 — cenário inspirado nas referências do autor (docs/concept/world1_ref_*.jpg):
-- árvore ancestral gigante sobre um platô de musgo, lago turquesa, cachoeiras caindo de
-- penhascos cobertos de musgo, cachoeiras na borda da ilha, árvores-bonsai e flores roxas.
-------------------------------------------------------------------------------

local MOSS, MOSS2, BARK, BARK2 = rgb(96, 160, 64), rgb(70, 130, 52), rgb(92, 70, 52), rgb(70, 54, 40)
local WATERFALL = rgb(200, 240, 255)

function WorldBuilder.mossRock(parent, pos: Vector3, s: number)
	local r = part({ Name = "MossRock", Size = V(5, 3.4, 4.2) * s, CFrame = CF(pos + V(0, 1.2 * s, 0)) * ANG(rad(8), math.random() * 6, rad(-6)),
		Color = rgb(110, 116, 108), Material = Enum.Material.Slate, Parent = parent })
	ellipsoid({ Name = "Moss", Size = V(4.6, 1.2, 3.8) * s, CFrame = r.CFrame * CF(0, 1.6 * s, 0), Color = MOSS, Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
	return r
end

-- Árvore de copa achatada e tronco torto (estilo bonsai/acácia das referências).
function WorldBuilder.bonsai(parent, pos: Vector3, s: number, rng: Random, leaf: Color3)
	local lean = rng:NextNumber(-0.35, 0.35)
	local a = CF(pos) * ANG(0, rng:NextNumber(0, 6.28), 0)
	local p1 = a * ANG(0, 0, lean) * CF(0, 4 * s, 0)
	part({ Name = "Trunk", Size = V(1.6, 8, 1.6) * s, CFrame = p1, Color = BARK, Material = Enum.Material.Wood, Parent = parent })
	local p2 = p1 * CF(0, 4 * s, 0) * ANG(0, 0, -lean * 2.2) * CF(0, 3 * s, 0)
	part({ Name = "Trunk", Size = V(1.2, 6, 1.2) * s, CFrame = p2, Color = BARK, Material = Enum.Material.Wood, Parent = parent })
	local top = p2 * CF(0, 3 * s, 0)
	for k, o in ipairs({ { 0, 0.6, 0, 11, 2.6 }, { 4, -0.4, 1.5, 7, 2 }, { -3.8, 0, -1.6, 7.5, 2.1 } }) do
		ellipsoid({ Name = "Canopy", Size = V(o[4], o[5], o[4] * 0.85) * s, CFrame = CF((top * CF(o[1] * s, o[2] * s, o[3] * s)).Position),
			Color = leaf:Lerp(rgb(255, 255, 255), k * 0.04), Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
	end
	part({ Name = "Branch", Size = V(0.7, 0.7, 6) * s, CFrame = top * CF(2 * s, -0.8, 0.8 * s) * ANG(0, rad(70), rad(-10)), Color = BARK, Material = Enum.Material.Wood, CanCollide = false, Parent = parent })
end

function WorldBuilder.flowerBush(parent, pos: Vector3, s: number, rng: Random, color: Color3)
	ellipsoid({ Name = "Bush", Size = V(5, 2.6, 4.6) * s, CFrame = CF(pos + V(0, 1 * s, 0)), Color = MOSS2, Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
	for k = 1, 7 do
		local ang = k / 7 * math.pi * 2 + rng:NextNumber(0, 0.5)
		part({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(0.7, 1.1) * s,
			CFrame = CF(pos + V(math.cos(ang) * 1.8 * s, (2 + rng:NextNumber(0, 0.6)) * s, math.sin(ang) * 1.6 * s)),
			Color = color:Lerp(rgb(255, 255, 255), rng:NextNumber(0, 0.25)), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = parent })
	end
end

local function waterfall(parent, top: Vector3, height: number, width: number, facing: Vector3)
	local cf = CF(top - V(0, height / 2, 0), top - V(0, height / 2, 0) + facing)
	part({ Name = "Waterfall", Size = V(width, height, 1.2), CFrame = cf, Color = WATERFALL, Material = Enum.Material.SmoothPlastic, Transparency = 0.25,
		CanCollide = false, CastShadow = false, Parent = parent })
	part({ Name = "WaterfallGlow", Size = V(width * 0.55, height, 0.4), CFrame = cf * CF(0, 0, -0.5), Color = rgb(235, 250, 255), Material = Enum.Material.Neon,
		Transparency = 0.55, CanCollide = false, CastShadow = false, Parent = parent })
	local foam = part({ Name = "Foam", Shape = Enum.PartType.Cylinder, Size = V(0.8, width * 1.6, width * 1.6), CFrame = CF(top - V(0, height - 0.2, 0)) * ANG(0, 0, rad(90)),
		Color = rgb(245, 252, 255), Transparency = 0.2, CanCollide = false, CastShadow = false, Parent = parent })
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(rgb(235, 248, 255))
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new(width * 0.6, width * 1.4)
	mist.Lifetime = NumberRange.new(1.5, 2.5)
	mist.Rate = 6
	mist.Speed = NumberRange.new(2, 4)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.Parent = foam
end

function WorldBuilder.verdantLandmark(parent: Instance, terrainOk: boolean)
	local w = Worlds.Info.verdant
	local L = WorldBuilder.Layout.verdantLake
	local folder = Make("Folder", { Name = "AncientGrove", Parent = parent })
	local lc = WorldBuilder.polar(w.center, L.theta, L.dist)
	local outward = (lc - w.center) * V(1, 0, 1)
	outward = outward.Unit
	local R = L.r
	-- lago turquesa
	local waterOk = false
	if terrainOk then
		waterOk = pcall(function()
			local T = workspace:FindFirstChildOfClass("Terrain") :: Terrain
			T.WaterColor = rgb(40, 200, 205)
			T.WaterTransparency = 0.55
			T.WaterReflectance = 0.6
			T.WaterWaveSize = 0.08
			T:FillCylinder(CF(lc - V(0, 4, 0)), 8, R, Enum.Material.Air)
			T:FillCylinder(CF(lc - V(0, 6, 0)), 8, R, Enum.Material.Water)
			T:FillCylinder(CF(lc - V(0, 11, 0)), 2, R, Enum.Material.Sand)
		end)
	end
	if not waterOk then
		part({ Name = "LakeWater", Shape = Enum.PartType.Cylinder, Size = V(0.6, R * 2, R * 2), CFrame = CF(lc + V(0, 0.15, 0)) * ANG(0, 0, rad(90)),
			Color = rgb(40, 200, 205), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false, Parent = folder })
	end
	-- margens com pedras de musgo e vitórias-régias
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		WorldBuilder.mossRock(folder, lc + V(math.cos(a) * (R + 2), -1.2, math.sin(a) * (R + 2)), 0.9 + (i % 3) * 0.3)
	end
	for i = 1, 9 do
		local a = i * 2.39
		local d = R * (0.45 + (i % 3) * 0.15)
		part({ Name = "LilyPad", Shape = Enum.PartType.Cylinder, Size = V(0.3, 3.2, 3.2), CFrame = CF(lc + V(math.cos(a) * d, waterOk and -1.9 or 0.5, math.sin(a) * d)) * ANG(0, 0, rad(90)),
			Color = rgb(80, 170, 70), CanCollide = false, Parent = folder })
		if i % 2 == 0 then
			part({ Name = "LilyFlower", Shape = Enum.PartType.Ball, Size = Vector3.one * 1, CFrame = CF(lc + V(math.cos(a) * d, waterOk and -1.4 or 1, math.sin(a) * d)),
				Color = rgb(255, 170, 220), Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
		end
	end
	-- platô de musgo no meio do lago
	local plateauTop = 10
	part({ Name = "Plateau", Shape = Enum.PartType.Cylinder, Size = V(plateauTop + 10, 30, 30), CFrame = CF(lc + V(0, (plateauTop - 10) / 2, 0)) * ANG(0, 0, rad(90)),
		Color = rgb(96, 100, 92), Material = Enum.Material.Slate, Parent = folder })
	part({ Name = "PlateauMoss", Shape = Enum.PartType.Cylinder, Size = V(1.6, 31, 31), CFrame = CF(lc + V(0, plateauTop, 0)) * ANG(0, 0, rad(90)),
		Color = MOSS, Material = Enum.Material.Grass, Parent = folder })
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.3
		part({ Name = "PlateauRock", Size = V(6, plateauTop + 6, 5), CFrame = CF(lc + V(math.cos(a) * 14, (plateauTop - 6) / 2, math.sin(a) * 14)) * ANG(0, -a, rad(4)),
			Color = rgb(88, 94, 86), Material = Enum.Material.Slate, Parent = folder })
	end
	-- cachoeiras descendo do platô para o lago
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + 0.9
		local dir = V(math.cos(a), 0, math.sin(a))
		waterfall(folder, lc + dir * 15.6 + V(0, plateauTop + 0.5, 0), plateauTop + 2, 4.5, dir)
	end
	-- ÁRVORE ANCESTRAL (tronco retorcido, raízes, galhos, copas verdes e roxas, cipós)
	local base = lc + V(0, plateauTop + 0.8, 0)
	local seg = { { 0, 9, 0, 13 }, { 0.12, 8, 0.05, 12 }, { -0.1, 7, -0.06, 12 }, { 0.08, 5.5, 0.04, 11 } }
	local cfT = CF(base)
	for _, sgm in ipairs(seg) do
		local piece = cfT * ANG(sgm[1], 0, sgm[3]) * CF(0, sgm[4] / 2, 0)
		part({ Name = "AncientTrunk", Shape = Enum.PartType.Cylinder, Size = V(sgm[4] + 1, sgm[2] * 2, sgm[2] * 2), CFrame = piece * ANG(0, 0, rad(90)),
			Color = BARK, Material = Enum.Material.Wood, Parent = folder })
		ellipsoid({ Name = "TrunkMoss", Size = V(sgm[2] * 1.4, sgm[4] * 0.6, sgm[2] * 0.6), CFrame = piece * CF(sgm[2] * 0.75, 0, 0), Color = MOSS2, Material = Enum.Material.Grass,
			CanCollide = false, Parent = folder })
		cfT = piece * CF(0, sgm[4] / 2, 0)
	end
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local rootCf = CF(base + V(math.cos(a) * 9, 1.5, math.sin(a) * 9)) * ANG(0, -a, 0) * ANG(0, 0, rad(-28))
		part({ Name = "Root", Size = V(14, 3.2, 3.6), CFrame = rootCf, Color = BARK2, Material = Enum.Material.Wood, Parent = folder })
	end
	local crown = cfT.Position
	local canopyCenters = {}
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.4
		local len = 20 + (i % 3) * 4
		local dir = V(math.cos(a), 0.45 + (i % 2) * 0.2, math.sin(a)).Unit
		local from = crown - V(0, 6 + (i % 3) * 4, 0)
		local to = from + dir * len
		part({ Name = "Branch", Size = V(3.2, 3.2, len), CFrame = CF((from + to) / 2, to), Color = BARK, Material = Enum.Material.Wood, Parent = folder })
		table.insert(canopyCenters, to + V(0, 2, 0))
	end
	table.insert(canopyCenters, crown + V(0, 6, 0))
	for i, cpos in ipairs(canopyCenters) do
		local purple = i % 3 == 0
		local col = purple and rgb(165, 115, 215) or (i % 2 == 0 and rgb(90, 175, 70) or rgb(110, 190, 80))
		local big = i == #canopyCenters and 1.5 or 1
		ellipsoid({ Name = "AncientCanopy", Size = V(24, 9, 22) * big, CFrame = CF(cpos), Color = col, Material = Enum.Material.Grass, CanCollide = false, Parent = folder })
		ellipsoid({ Name = "AncientCanopy", Size = V(15, 6, 14) * big, CFrame = CF(cpos + V(3, 4, -2)), Color = col:Lerp(rgb(255, 255, 255), 0.1), Material = Enum.Material.Grass,
			CanCollide = false, Parent = folder })
		for k = 1, 3 do
			local off = V(math.cos(k * 2.1) * 8, -4.5, math.sin(k * 2.1) * 7)
			local len = 6 + (k % 3) * 3
			part({ Name = "HangingMoss", Size = V(0.5, len, 0.5), CFrame = CF(cpos + off - V(0, len / 2, 0)), Color = rgb(70, 140, 90), Material = Enum.Material.Grass,
				CanCollide = false, CastShadow = false, Parent = folder })
		end
		local glow = part({ Name = "Firefly", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = CF(cpos + V(0, -5.5, 0)), Color = rgb(220, 255, 170),
			Material = Enum.Material.Neon, CanCollide = false, CastShadow = false, Parent = folder })
		if i % 2 == 0 then
			Make("PointLight", { Color = rgb(200, 255, 170), Range = 18, Brightness = 1, Shadows = false, Parent = glow })
		end
	end
	-- penhascos de musgo atrás do lago com cachoeiras altas
	local side = V(-outward.Z, 0, outward.X)
	for i = -3, 3 do
		local p = lc + outward * (R + 18) + side * (i * 12)
		local h = 26 + (3 - math.abs(i)) * 4
		part({ Name = "Cliff", Size = V(13, h, 10), CFrame = CF(p + V(0, h / 2 - 2, 0), p + V(0, h / 2 - 2, 0) + outward) * ANG(0, 0, rad(i * 2)),
			Color = rgb(92, 98, 92), Material = Enum.Material.Slate, Parent = folder })
		ellipsoid({ Name = "CliffMoss", Size = V(14, 4, 11), CFrame = CF(p + V(0, h - 1.5, 0)), Color = MOSS, Material = Enum.Material.Grass, CanCollide = false, Parent = folder })
		if i == -2 or i == 0 or i == 2 then
			waterfall(folder, p - outward * 5.6 + V(0, h - 2, 0), h - 1, 5, -outward)
		end
	end
	-- cachoeiras caindo da borda da ilha para o mar de nuvens
	for _, dTheta in ipairs({ -18, 20 }) do
		local edge = WorldBuilder.polar(w.center, L.theta + dTheta, w.radius - 2)
		local dir = ((edge - w.center) * V(1, 0, 1)).Unit
		part({ Name = "Stream", Size = V(6, 0.4, 22), CFrame = CF(edge - dir * 10 + V(0, 0.15, 0), edge + V(0, 0.15, 0)), Color = rgb(60, 205, 210),
			Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false, Parent = folder })
		waterfall(folder, edge + dir * 1.5 + V(0, 0.2, 0), 140, 6, dir)
	end
	-- flores roxas e árvores-bonsai ao redor do lago
	local rng = Random.new(4242)
	for i = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = R + rng:NextNumber(6, 24)
		local pos = lc + V(math.cos(a) * d, 0, math.sin(a) * d)
		if (pos - w.center).Magnitude < w.radius - 10 then
			if i % 3 == 0 then
				WorldBuilder.bonsai(folder, pos, 1.2, rng, i % 2 == 0 and rgb(170, 120, 220) or rgb(110, 185, 70))
			else
				WorldBuilder.flowerBush(folder, pos, 1.1, rng, i % 2 == 0 and rgb(160, 110, 230) or rgb(200, 150, 255))
			end
		end
	end
	return folder
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
		Color = rgb(214, 206, 190):Lerp(w.palette.accent, 0.25), Material = Enum.Material.Marble, Parent = folder })
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

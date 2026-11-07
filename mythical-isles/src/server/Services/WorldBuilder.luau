-- Construção procedural das ilhas: terreno, decoração temática, estações de ovos, portais
-- e arenas de boss. Usado pelo WorldService (não é um serviço por si só).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local Eggs = require(Shared.Config.Eggs)
local Make = require(Shared.Util.Make)
local Regions = require(Shared.Config.Regions)
local CrystalKit = require(script.Parent.CrystalKit)
local BlockTree = require(script.Parent.BlockTree)

local WorldBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB

local CLIFF_COLORS = {
	Rock = rgb(110, 100, 90),
	Basalt = rgb(84, 80, 104), -- cinza-violeta (rochas de Crystal Hollow, como na arte de referência)
	Limestone = rgb(205, 205, 215),
	Mud = rgb(70, 60, 56),
	Concrete = rgb(52, 44, 82),
}

local MOSS, MOSS2, BARK = rgb(96, 160, 64), rgb(70, 130, 52), rgb(92, 70, 52)

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

local function terrainFill(w, worldId: string)
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
	-- protuberâncias de rocha sob a borda: quebram o contorno "em degraus" dos cilindros
	-- (o topo de cada bola fica sempre abaixo do chão, para não criar domos)
	local lump = Random.new(w.index * 311)
	for i = 1, 30 do
		local theta = i * 12 + lump:NextNumber(-5, 5)
		local depth = lump:NextNumber(6, 70)
		local shrink = 1 - depth / 95
		local rad_ = lump:NextNumber(9, 17)
		local y = math.min(-depth, -3 - rad_)
		Terrain:FillBall(WorldBuilder.polar(c, theta, r * shrink * lump:NextNumber(0.86, 0.97), y), rad_, cliff)
	end
	-- algumas colinas suaves na borda (sem bloquear caminhos nem os lugares do anel de mata)
	local plan = WorldBuilder.ringPlan and WorldBuilder.ringPlan(worldId)
	local function onPoi(pos: Vector3, hr: number): boolean
		for _, p in ipairs(plan and plan.pois or {}) do
			if ((pos - p.pos) * V(1, 0, 1)).Magnitude < p.r + hr + 6 then
				return true
			end
		end
		return false
	end
	local rng = Random.new(w.index * 97)
	for i = 1, 10 do
		local theta = i * 36 + rng:NextNumber(-8, 8)
		local pos = WorldBuilder.polar(c, theta, r - rng:NextNumber(10, 22), -8)
		local hr = rng:NextNumber(12, 18)
		-- não sobe colina em cima de regiões construídas à mão (templo, baús, lago...)
		if not Regions.isReserved(worldId, pos, hr) and not onPoi(pos, hr) then
			Terrain:FillBall(pos, hr, i % 3 == 0 and cliff or ground)
		end
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
	local ok, err = pcall(terrainFill, w, worldId)
	if ok then
		local okD, errD = pcall(WorldBuilder.terrainDetail, worldId)
		if not okD then
			warn("[WorldBuilder] detalhes do terreno falharam em " .. worldId .. ": " .. tostring(errD))
		end
	end
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
	local openings = Regions.Openings[worldId] or {}
	for i = 1, n do
		local a = (i - 0.5) / n * math.pi * 2
		local deg = math.deg(a)
		local open = false
		for _, o in ipairs(openings) do
			local diff = math.abs((deg - o.theta + 180) % 360 - 180)
			if diff < o.w then
				open = true -- abertura para ponte/cais
			end
		end
		if open then
			continue
		end
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
		-- regiões construídas à mão (lago, montanhas, caverna, rio) ficam livres de decoração aleatória
		if worldId and Regions.isReserved(worldId, pos, 4) then
			ok = false
		end
		if ok then
			return pos
		end
	end
	return nil
end

-- Ponto livre de gameplay (praça, ovos, portais, arena, campos, zonas e áreas reservadas).
function WorldBuilder.isFree(worldId: string, pos: Vector3, margin: number?, ignoreReserved: boolean?): boolean
	local w = Worlds.Info[worldId]
	local L = WorldBuilder.Layout
	local m = margin or 0
	local function near(theta, dist, r)
		return ((pos - WorldBuilder.polar(w.center, theta, dist)) * V(1, 0, 1)).Magnitude < r + m
	end
	if ((pos - w.center) * V(1, 0, 1)).Magnitude < 30 + m then
		return false
	end
	if near(L.arena.theta, L.arena.dist, 74) or near(L.portalNext.theta, L.portalNext.dist, 8) or near(L.portalPrev.theta, L.portalPrev.dist, 8) then
		return false
	end
	for _, e in ipairs(L.eggs) do
		if near(e.theta, e.dist, 9) then
			return false
		end
	end
	for _, f in ipairs(L.resources) do
		if near(f.theta, f.dist, f.r + 2) then
			return false
		end
	end
	for _, z in ipairs(L.enemyZones) do
		if near(z.theta, z.dist, z.r + 2) then
			return false
		end
	end
	return ignoreReserved == true or not Regions.isReserved(worldId, pos, m)
end
WorldBuilder.freeSpot = freeSpot

-------------------------------------------------------------------------------
-- Detalhes do terreno: caminhos de terra, manchas de solo, montinhos e pedras de Terrain
-------------------------------------------------------------------------------

-- Materiais extras por ilha (cores de material do Terrain são globais: cada material novo
-- é usado com UMA cor só em todas as ilhas).
local TERRAIN_STYLE = {
	verdant = { path = "Ground", patch = "Ground", boulder = "Rock" },
	crystal = { path = "Cobblestone", patch = "Slate", boulder = "Basalt" },
	sky = { path = "Sandstone", patch = "Ice", boulder = "Limestone" },
	wilds = { path = "Ground", patch = "Mud", boulder = "Rock" },
	astral = { path = "Salt", patch = "CrackedLava", boulder = "Concrete" },
}
local EXTRA_COLORS = {
	Ground = rgb(122, 98, 70), Cobblestone = rgb(128, 126, 146), Slate = rgb(86, 92, 116), Glacier = rgb(176, 158, 236), Sandstone = rgb(226, 212, 184),
	Ice = rgb(212, 234, 250), Salt = rgb(122, 114, 170), CrackedLava = rgb(96, 70, 160),
}

local function groundRay(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local T = workspace:FindFirstChildOfClass("Terrain")
	if not T then
		return pos
	end
	params.FilterDescendantsInstances = { T }
	local hit = workspace:Raycast(pos + V(0, 40, 0), V(0, -80, 0), params)
	return hit and hit.Position or pos
end
WorldBuilder.groundAt = groundRay

function WorldBuilder.terrainDetail(worldId: string)
	local w = Worlds.Info[worldId]
	local T = workspace:FindFirstChildOfClass("Terrain") :: Terrain
	local st = TERRAIN_STYLE[worldId] or TERRAIN_STYLE.verdant
	local c = w.center
	local L = WorldBuilder.Layout
	for _, name in ipairs({ st.path, st.patch }) do
		if EXTRA_COLORS[name] then
			T:SetMaterialColor(Enum.Material[name], EXTRA_COLORS[name])
		end
	end
	local pathMat = Enum.Material[st.path]
	-- caminhos levemente sinuosos da praça até cada área (blocos finos rente ao chão)
	local rng = Random.new(w.index * 733)
	local function path(theta: number, fromDist: number, toDist: number)
		local wob = rng:NextNumber(0, 6.28)
		local prev = WorldBuilder.polar(c, theta, fromDist)
		local steps = math.max(2, math.floor((toDist - fromDist) / 9))
		for k = 1, steps do
			local t = k / steps
			local d = fromDist + (toDist - fromDist) * t
			local cur = WorldBuilder.polar(c, theta + math.sin(t * 5 + wob) * 7 * (1 - math.abs(t - 0.5)), d)
			local mid = (prev + cur) / 2
			local len = (cur - prev).Magnitude + 3
			T:FillBlock(CF(mid - V(0, 1, 0), mid - V(0, 1, 0) + (cur - prev)), V(6.5, 2, len), pathMat)
			prev = cur
		end
	end
	path(L.arena.theta, 27, L.arena.dist - 30)
	for _, f in ipairs(L.resources) do
		path(f.theta, 27, f.dist - f.r + 4)
	end
	for _, z in ipairs(L.enemyZones) do
		path(z.theta, 50, z.dist - z.r + 6)
	end
	path(L.portalNext.theta, 27, L.portalNext.dist - 3)
	path(L.portalPrev.theta, 27, L.portalPrev.dist - 3)
	-- manchas de solo exposto / gelo / lava rachada (rente ao chão)
	for _ = 1, 12 do
		local pos = freeSpot(c, w.core or w.radius, rng, worldId)
		if pos then
			T:FillCylinder(CF(pos - V(0, 1, 0)), 2, rng:NextNumber(4, 9), Enum.Material[st.patch])
		end
	end
	-- montinhos suaves (o topo sobe só 2-3,5 studs) longe da praça e das estações
	for _ = 1, 7 do
		local pos = freeSpot(c, w.core or w.radius, rng, worldId)
		if pos and (pos - c).Magnitude > 75 then
			local rr = rng:NextNumber(12, 16)
			T:FillBall(pos - V(0, rr - rng:NextNumber(2, 3.5), 0), rr, Enum.Material[w.ground])
		end
	end
	-- pedras naturais semienterradas
	for _ = 1, 10 do
		local pos = freeSpot(c, w.core or w.radius, rng, worldId)
		if pos then
			local rr = rng:NextNumber(2.2, 4.2)
			T:FillBall(pos + V(0, rr * 0.15, 0), rr, Enum.Material[st.boulder])
			if rng:NextNumber() < 0.6 then
				T:FillBall(pos + V(rr * 0.9, -rr * 0.2, rr * 0.4), rr * 0.6, Enum.Material[st.boulder])
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Vegetação e rochas "naturais"
-------------------------------------------------------------------------------

local function cyl(props, a: Vector3, b: Vector3, radius: number)
	-- cilindro de a até b (o eixo do cilindro do Roblox é X)
	props.Shape = Enum.PartType.Cylinder
	props.Size = V((b - a).Magnitude, radius * 2, radius * 2)
	props.CFrame = CF((a + b) / 2, b) * ANG(0, rad(90), 0)
	return part(props)
end

-- FOLHAGEM: em vez de bolas, cada copa é um tufo de FOLHAS individuais (triângulos e lâminas finas com
-- material LeafyGrass) que apontam para fora em leque, sobre um miolo escuro facetado que fecha os buracos.
-- Folhas de cima recebem tom mais claro (luz do sol); as de baixo, mais escuro (sombra interna).
local LEAF_LIGHT = rgb(226, 236, 140)
local LEAF_DARK = rgb(18, 34, 16)

local function wedge(props)
	props.Anchored = true
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	if props.CanCollide == nil then
		props.CanCollide = false
	end
	return Make("WedgePart", props)
end

-- Folha triangular deitada no plano XZ do referencial `cf`: base na origem, ponta em -Z.
local function leafTri(parent, cf: CFrame, w: number, len: number, t: number, color: Color3, material: Enum.Material?)
	local flat = cf * ANG(rad(-90), 0, 0) -- triângulo "em pé" (ápice +Y) deitado com a ponta para -Z
	for _, side in ipairs({ -1, 1 }) do
		wedge({ Name = "Leaf", Size = V(t, len, w / 2), CFrame = flat * CF(side * w / 4, len / 2, 0) * ANG(0, side * rad(-90), 0),
			Color = color, Material = material or Enum.Material.LeafyGrass, Parent = parent })
	end
end

-- Tufo de folhas. radii = semi-eixos do tufo; n = nº de folhas; flat < 1 achata (copas em "prato").
local function foliage(parent, center: Vector3, radii: Vector3, leaf: Color3, rng: Random, n: number?, flat: number?, leafScale: number?)
	n = n or 16
	flat = flat or 1
	local ls = leafScale or 1
	-- miolo facetado (dois blocos girados), escuro: dá volume e esconde o céu entre as folhas
	for k = 1, 2 do
		part({ Name = "LeafCore", Size = V(radii.X * 1.35, radii.Y * 1.15, radii.Z * 1.35) * (k == 1 and 1 or 0.8),
			CFrame = CF(center + V(0, k == 2 and radii.Y * 0.25 or 0, 0)) * ANG(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
			Color = leaf:Lerp(LEAF_DARK, 0.3), Material = Enum.Material.LeafyGrass, CanCollide = false, Parent = parent })
	end
	local golden = 2.39996
	for i = 1, n do
		-- direções bem distribuídas (espiral de Fibonacci), com mais folhas em cima
		local y = 1 - (i - 0.5) / n * 1.55
		local r = math.sqrt(math.max(0, 1 - y * y))
		local th = i * golden + rng:NextNumber(-0.3, 0.3)
		local dir = V(math.cos(th) * r, y * flat, math.sin(th) * r)
		if dir.Magnitude < 0.05 then
			dir = V(1, 0, 0)
		end
		dir = dir.Unit
		local pos = center + V(dir.X * radii.X, dir.Y * radii.Y, dir.Z * radii.Z) * rng:NextNumber(0.55, 0.85)
		local light = math.clamp(0.5 + dir.Y * 0.5, 0, 1)
		local color = leaf:Lerp(LEAF_DARK, (1 - light) * 0.2):Lerp(LEAF_LIGHT, light * light * 0.3 + rng:NextNumber(0, 0.08))
		-- folha aponta para fora, com rolagem aleatória e a ponta caindo um pouco
		local cf = CF(pos, pos + V(dir.X, dir.Y * 0.6 - 0.15, dir.Z)) * ANG(0, 0, rng:NextNumber(-0.7, 0.7)) * ANG(-rng:NextNumber(0.05, 0.45), 0, 0)
		local size = math.min(radii.X, radii.Z) * ls
		if i % 2 == 0 then
			leafTri(parent, cf, size * rng:NextNumber(0.7, 0.95), size * rng:NextNumber(1.0, 1.35), 0.18, color)
		else
			local w, l = size * rng:NextNumber(0.55, 0.8), size * rng:NextNumber(0.9, 1.2)
			part({ Name = "Leaf", Size = V(w, 0.18, l), CFrame = cf * CF(0, 0, -l * 0.42) * ANG(0, rad(45) * (rng:NextNumber() < 0.5 and 1 or 0), 0),
				Color = color, Material = Enum.Material.LeafyGrass, CanCollide = false, Parent = parent })
		end
	end
end
WorldBuilder.foliage = foliage

-- ÁRVORE DE GALHOS E CUBOS (referência do autor) — o modelo de árvore de TODOS os mundos, exceto o
-- bosque de blocos do Verdant Haven (BlockTree), que continua com o seu próprio modelo.
--   * tronco fino marrom-avermelhado que se divide em vários galhos, e cada galho em dois ramos;
--   * em cada ponta, um cacho de cubos girados ao acaso com textura de grama, em verdes escuros
--     (cubos de cima um pouco mais claros, os de baixo na sombra);
--   * cachos pendentes nas laterais, presos por ramos finos que descem.
-- Só o tronco colide (dá para andar por baixo da copa). ~80 peças por árvore.
local TREE_BARK = rgb(96, 54, 50)
local TREE_SHADOW = rgb(8, 20, 8)

-- Cacho: n cubos girados ao acaso em volta de `center`; squash > 1 alonga na vertical (cacho pendente).
local function cubeCluster(parent, center: Vector3, size: number, leaf: Color3, rng: Random, n: number, squash: number?)
	local sq = squash or 0.65
	for k = 1, n do
		local off = k == 1 and Vector3.zero or V(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1) * sq, rng:NextNumber(-1, 1)) * size * 0.5
		local c = rng:NextNumber(0.72, 1.1) * size
		local shade = math.clamp(rng:NextNumber(0.1, 0.4) - off.Y / size * 0.4, 0.02, 0.6)
		part({ Name = "LeafCube", Size = V(c, c * rng:NextNumber(0.85, 1), c * rng:NextNumber(0.9, 1.05)),
			CFrame = CF(center + off) * ANG(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28)),
			Color = leaf:Lerp(TREE_SHADOW, shade), Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
	end
end
WorldBuilder.cubeCluster = cubeCluster

-- opts: name, trunk (altura até a forquilha, ×s), branches (nº de galhos), rise (quanto sobem),
-- spread (alcance), leader (galho central), cluster (tamanho dos cachos), hang (nº de cachos pendentes),
-- lite (versão leve para florestas densas: um ramo por galho e cachos menores, ~20 peças)
local function branchTree(parent, pos: Vector3, s: number, rng: Random, bark: Color3, leaf: Color3, glow: Color3?, opts)
	opts = opts or {}
	local model = Make("Model", { Name = opts.name or "Tree", Parent = parent })
	local barkCol = bark:Lerp(TREE_BARK, 0.75)
	local spread = opts.spread or 1
	local rise = opts.rise or 0.85
	local fork = pos + V(rng:NextNumber(-0.5, 0.5) * s, (opts.trunk or 6.2) * s * rng:NextNumber(0.9, 1.12), rng:NextNumber(-0.5, 0.5) * s)
	cyl({ Name = "Trunk", Color = barkCol, Material = Enum.Material.Wood, Parent = model }, pos - V(0, 0.8, 0), fork, 0.6 * s)
	if not opts.lite then
		cyl({ Name = "TrunkBase", Color = barkCol:Lerp(rgb(0, 0, 0), 0.12), Material = Enum.Material.Wood, CanCollide = false, Parent = model },
			pos - V(0, 0.8, 0), pos + V(0, 1.3 * s, 0), 0.8 * s)
		part({ Name = "Knot", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3 * s, CFrame = CF(fork), Color = barkCol, Material = Enum.Material.Wood,
			CanCollide = false, Parent = model })
	end
	local tips, mids = {}, {}
	local nb = opts.branches or 4
	local yaw0 = rng:NextNumber(0, math.pi * 2)
	for b = 1, nb do
		local a = yaw0 + (b - 1) / nb * math.pi * 2 + rng:NextNumber(-0.35, 0.35)
		local dir = V(math.cos(a), rise * rng:NextNumber(0.8, 1.2), math.sin(a)).Unit
		local mid = fork + dir * rng:NextNumber(4.2, 5.8) * s * spread
		cyl({ Name = "Branch", Color = barkCol, Material = Enum.Material.Wood, CanCollide = false, Parent = model }, fork - V(0, 0.5 * s, 0), mid, 0.38 * s)
		table.insert(mids, { at = mid, a = a })
		for k = -1, 1, opts.lite and 3 or 2 do
			local a2 = a + k * rng:NextNumber(0.4, 0.75) * (opts.lite and 0.5 or 1)
			local d2 = V(math.cos(a2), rise * rng:NextNumber(0.5, 1.1) + 0.15, math.sin(a2)).Unit
			local tip = mid + d2 * rng:NextNumber(3, 4.4) * s * spread
			cyl({ Name = "Twig", Color = barkCol, Material = Enum.Material.Wood, CanCollide = false, Parent = model }, mid, tip, 0.22 * s)
			table.insert(tips, tip)
		end
	end
	local top = fork + V(rng:NextNumber(-1, 1) * s, (opts.leader or 5.5) * s, rng:NextNumber(-1, 1) * s)
	cyl({ Name = "Branch", Color = barkCol, Material = Enum.Material.Wood, CanCollide = false, Parent = model }, fork, top, 0.34 * s)
	table.insert(tips, top)
	local cs = (opts.cluster or 3.1) * s
	for i, t in ipairs(tips) do
		local main = i == #tips
		cubeCluster(model, t + V(0, cs * 0.25, 0), cs * (main and 1.25 or rng:NextNumber(0.9, 1.1)), leaf, rng, opts.lite and (main and 5 or 4) or (main and 7 or 5))
	end
	-- miolo da copa: fecha o vão entre o galho central e os laterais
	for k = 1, opts.lite and 0 or 2 do
		local a = yaw0 + k * math.pi + 0.8
		cubeCluster(model, fork + V(math.cos(a) * 2 * s * spread, (opts.leader or 5.5) * 0.6 * s, math.sin(a) * 2 * s * spread), cs * 1.05, leaf, rng, 4)
	end
	-- cachos pendentes nas laterais
	local hang = opts.hang or (opts.lite and 0 or 2)
	for i = 1, math.min(hang, #mids) do
		local m = mids[(i - 1) * math.max(1, math.floor(#mids / hang)) % #mids + 1]
		local out = V(math.cos(m.a), 0, math.sin(m.a))
		local p0 = m.at + out * 1.2 * s
		local p1 = p0 + out * 1.4 * s - V(0, rng:NextNumber(1.8, 2.6) * s, 0)
		cyl({ Name = "Twig", Color = barkCol, Material = Enum.Material.Wood, CanCollide = false, Parent = model }, p0, p1, 0.16 * s)
		cubeCluster(model, p1, cs * 0.72, leaf, rng, 3, 1.7)
	end
	if glow then
		for k = 1, 4 do
			local t = tips[(k - 1) * 2 % #tips + 1]
			part({ Name = "GlowFruit", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7 * s, CFrame = CF(t - V(rng:NextNumber(-1, 1), 1.6 * s, rng:NextNumber(-1, 1))),
				Color = glow, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false, Parent = model })
		end
	end
	return model
end
WorldBuilder.branchTree = branchTree

-- Nomes antigos (todas as chamadas dos mundos passam por aqui): mesma árvore, proporções diferentes.
local function oakTree(parent, pos: Vector3, s: number, rng: Random, bark: Color3, leaf: Color3, glow: Color3?)
	return branchTree(parent, pos, s, rng, bark, leaf, glow, { name = "Tree" })
end
WorldBuilder.oakTree = oakTree

-- Versão alta e estreita (no lugar do antigo pinheiro).
local function pineTree(parent, pos: Vector3, s: number, rng: Random, bark: Color3, leaf: Color3)
	return branchTree(parent, pos, s, rng, bark, leaf, nil, { name = "Pine", trunk = 8.5, branches = 3, rise = 1.9, spread = 0.65, leader = 7.5, cluster = 2.7, hang = 1 })
end

-- Grupo de rochas: blocos inclinados de tamanhos diferentes, meio enterrados, com musgo opcional.
local function rockCluster(parent, pos: Vector3, s: number, rng: Random, color: Color3, material: Enum.Material, moss: Color3?)
	local model = Make("Model", { Name = "Rocks", Parent = parent })
	for k = 1, 3 do
		local sz = V(rng:NextNumber(3.2, 5), rng:NextNumber(2.4, 4), rng:NextNumber(3, 4.6)) * s * (k == 1 and 1 or 0.65)
		local off = k == 1 and V(0, 0, 0) or V(rng:NextNumber(-2.6, 2.6), 0, rng:NextNumber(-2.6, 2.6)) * s
		local r = part({ Name = "Rock", Size = sz, CFrame = CF(pos + off + V(0, sz.Y * 0.28, 0)) * ANG(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 6.28), rng:NextNumber(-0.35, 0.35)),
			Color = color:Lerp(rgb(255, 255, 255), rng:NextNumber(0, 0.1)), Material = material, Parent = model })
		if moss and k == 1 then
			-- musgo: placa fina e irregular por cima da pedra (não uma bola)
			part({ Name = "Moss", Size = V(sz.X * 0.92, 0.35, sz.Z * 0.85), CFrame = r.CFrame * CF(0, sz.Y * 0.5, 0) * ANG(0, rad(20), 0), Color = moss, Material = Enum.Material.LeafyGrass,
				CanCollide = false, Parent = model })
		end
	end
	return model
end
WorldBuilder.rockCluster = rockCluster

-- Fogo de partículas (textura de fogo embutida no cliente): chama, brasas subindo e fumaça.
function WorldBuilder.fire(holder: BasePart, color: Color3, scale: number)
	local function e(props)
		local pe = Instance.new("ParticleEmitter")
		for k, v in pairs(props) do
			(pe :: any)[k] = v
		end
		pe.Parent = holder
		return pe
	end
	local s = scale or 1
	e({ Name = "Flame", Texture = "rbxasset://textures/particles/fire_main.dds", Color = ColorSequence.new(rgb(255, 240, 200), color), LightEmission = 1, LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * s), NumberSequenceKeypoint.new(0.5, 1.6 * s), NumberSequenceKeypoint.new(1, 0.2 * s) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.7, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 0.9), Rate = 26, Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(12, 12), Acceleration = V(0, 4, 0),
		RotSpeed = NumberRange.new(-40, 40), Rotation = NumberRange.new(0, 360) })
	e({ Name = "Embers", Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(rgb(255, 200, 120)), LightEmission = 1, LightInfluence = 0,
		Size = NumberSequence.new(0.18 * s, 0), Lifetime = NumberRange.new(1, 2), Rate = 6, Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(25, 25),
		Acceleration = V(0, 2, 0), Drag = 0.6 })
	e({ Name = "Smoke", Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(rgb(70, 66, 64)), LightEmission = 0, LightInfluence = 1,
		Size = NumberSequence.new(1 * s, 4 * s), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(2, 3.5), Rate = 4, Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(10, 10), Acceleration = V(0.6, 1.5, 0),
		RotSpeed = NumberRange.new(-15, 15), Rotation = NumberRange.new(0, 360) })
end

-- Partículas ambientes (texturas embutidas no cliente Roblox): pólen e vaga-lumes, esporos, cintilação.
local AMBIENT = {
	pollen = { tex = "rbxasset://textures/particles/sparkles_main.dds", color = rgb(255, 246, 190), size = 0.18, rate = 3, life = 7, speed = 0.4, emission = 0.6 },
	fireflies = { tex = "rbxasset://textures/particles/sparkles_main.dds", color = rgb(210, 255, 150), size = 0.35, rate = 2, life = 5, speed = 0.6, emission = 1, light = true },
	spores = { tex = "rbxasset://textures/particles/sparkles_main.dds", color = rgb(150, 255, 220), size = 0.25, rate = 4, life = 8, speed = 0.3, emission = 1 },
	glints = { tex = "rbxasset://textures/particles/sparkles_main.dds", color = rgb(200, 220, 255), size = 0.3, rate = 3, life = 2.5, speed = 0.1, emission = 1 },
	mist = { tex = "rbxasset://textures/particles/smoke_main.dds", color = rgb(240, 246, 255), size = 6, rate = 0.6, life = 9, speed = 0.5, emission = 0, transparency = 0.82 },
}
function WorldBuilder.ambient(parent: Instance, pos: Vector3, kind: string, spread: number?)
	local cfg = AMBIENT[kind]
	if not cfg then
		return nil
	end
	local sp = spread or 12
	local anchor = part({ Name = "Ambient_" .. kind, Size = V(sp, 3, sp), CFrame = CF(pos), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
		CastShadow = false, Parent = parent })
	local e = Instance.new("ParticleEmitter")
	e.Name = "Ambient"
	e.Texture = cfg.tex
	e.Color = ColorSequence.new(cfg.color)
	e.LightEmission = cfg.emission
	e.LightInfluence = cfg.emission > 0.5 and 0 or 1
	e.Rate = cfg.rate
	e.Lifetime = NumberRange.new(cfg.life * 0.7, cfg.life)
	e.Speed = NumberRange.new(cfg.speed * 0.5, cfg.speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = V(0, cfg.speed * 0.15, 0)
	e.Drag = 0.4
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, cfg.size), NumberSequenceKeypoint.new(0.8, cfg.size), NumberSequenceKeypoint.new(1, 0) })
	local t0 = cfg.transparency or 0.15
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, t0), NumberSequenceKeypoint.new(0.75, t0), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = anchor
	if cfg.light then
		Make("PointLight", { Color = cfg.color, Range = 14, Brightness = 0.7, Shadows = false, Parent = anchor })
	end
	return anchor
end

-- Moita: dois tufos baixos de folhas.
local function bush(parent, pos: Vector3, s: number, rng: Random, leaf: Color3)
	for k = 1, 2 do
		local a = rng:NextNumber(0, 6.28)
		local off = k == 1 and V(0, 0, 0) or V(math.cos(a), 0, math.sin(a)) * 1.6 * s
		local r = rng:NextNumber(1.4, 1.9) * s * (k == 1 and 1 or 0.75)
		foliage(parent, pos + off + V(0, r * 0.55, 0), V(r, r * 0.7, r), leaf, rng, k == 1 and 14 or 9, 1, 0.9)
	end
end

-- Samambaia: frondes triangulares compridas em roseta, arqueadas para fora.
local function fern(parent, pos: Vector3, s: number, rng: Random, leaf: Color3)
	local spin = rng:NextNumber(0, 6.28)
	for k = 1, 7 do
		local a = spin + k / 7 * math.pi * 2
		local out = V(math.cos(a), 0, math.sin(a))
		local base = pos + V(0, 0.25 * s, 0) + out * 0.3 * s
		local cf = CF(base, base + out + V(0, rng:NextNumber(0.35, 0.7), 0))
		leafTri(parent, cf * ANG(rad(-12), 0, 0), 0.7 * s, rng:NextNumber(3.0, 3.8) * s, 0.12, leaf:Lerp(LEAF_LIGHT, (k % 3) * 0.07), Enum.Material.Grass)
	end
end

function WorldBuilder.decor(worldId: string, parent: Instance)
	local w = Worlds.Info[worldId]
	local c = w.center
	local rng = Random.new(w.index * 1337)
	local folder = Make("Folder", { Name = "Decor", Parent = parent })
	-- Crystal Hollow já tem muito conteúdo feito à mão nas regiões: menos decoração aleatória
	local count = (worldId == "crystal" or worldId == "sky") and 40 or 64
	for i = 1, count do
		local spot = freeSpot(c, w.core or w.radius, rng, worldId)
		if spot then
			local pos = groundRay(spot) -- apoia no chão real (montinhos/pedras do Terrain)
			local s = rng:NextNumber(0.8, 1.35)
			local k = i % 10
			if worldId == "verdant" then
				if k == 0 or k == 5 then
					oakTree(folder, pos, s, rng, BARK, i % 4 == 0 and rgb(76, 136, 54) or rgb(62, 118, 46))
				elseif k == 1 then
					WorldBuilder.bonsai(folder, pos, s * 1.1, rng, i % 3 == 0 and rgb(84, 140, 56) or rgb(66, 124, 48))
				elseif k == 2 then
					rockCluster(folder, pos, s, rng, rgb(112, 116, 108), Enum.Material.Slate, MOSS)
				elseif k == 3 or k == 8 then
					bush(folder, pos, s, rng, rgb(70, 132, 54))
				elseif k == 4 or k == 9 then
					fern(folder, pos, s, rng, rgb(84, 150, 62))
				elseif k == 6 then
					WorldBuilder.flowerBush(folder, pos, s, rng, rgb(160, 110, 230))
				else
					WorldBuilder.flowerBush(folder, pos, s * 0.9, rng, rgb(255, 150, 200))
				end
			elseif worldId == "crystal" then
				-- Crystal Valley: árvores de folhas azuis/violeta, aglomerados de várias espécies,
				-- cristais miúdos no chão, rochas com musgo e moitas com flores violeta
				if k == 0 or k == 6 then
					oakTree(folder, pos, s, rng, rgb(84, 66, 74), i % 4 == 0 and rgb(120, 90, 220) or rgb(60, 110, 210))
				elseif k == 1 then
					WorldBuilder.bonsai(folder, pos, s, rng, rgb(150, 100, 230))
				elseif k == 2 or k == 7 then
					CrystalKit.cluster(folder, CF(pos) * ANG(0, rng:NextNumber(0, 6.28), 0), rng, { count = rng:NextInteger(4, 6), h = rng:NextNumber(5, 9) * s, w = rng:NextNumber(1.1, 1.6) * s,
						styles = ({ { "blue", "ice" }, { "violet", "amethyst" }, { "sapphire", "blue" } })[i % 3 + 1] })
				elseif k == 3 or k == 8 then
					CrystalKit.scatter(folder, pos, rng, i % 2 == 0 and { "blue", "ice" } or { "violet", "blue" })
				elseif k == 4 then
					rockCluster(folder, pos, s, rng, rgb(70, 72, 92), Enum.Material.Slate, rgb(70, 130, 92))
				elseif k == 5 then
					WorldBuilder.flowerBush(folder, pos, s, rng, rgb(170, 110, 255))
				else
					bush(folder, pos, s, rng, rgb(54, 110, 120))
				end
			elseif worldId == "sky" then
				-- Skybound Kingdom: árvores verdes e douradas, bonsais floridos, cristais brancos/azuis,
				-- canteiros de flores e pedras claras com musgo (como na arte de referência)
				if k == 0 or k == 5 then
					oakTree(folder, pos, s, rng, rgb(108, 80, 58), i % 4 == 0 and rgb(158, 180, 74) or rgb(84, 160, 70))
				elseif k == 1 then
					WorldBuilder.bonsai(folder, pos, s, rng, i % 3 == 0 and rgb(250, 190, 210) or rgb(110, 180, 80))
				elseif k == 2 or k == 7 then
					WorldBuilder.flowerBush(folder, pos, s, rng, ({ rgb(255, 170, 200), rgb(255, 220, 120), rgb(170, 150, 255) })[i % 3 + 1])
				elseif k == 3 then
					CrystalKit.cluster(folder, CF(pos) * ANG(0, rng:NextNumber(0, 6.28), 0), rng, { count = 4, h = rng:NextNumber(4, 7) * s, w = 1.2 * s, styles = { "pearl", "blue" } })
				elseif k == 4 then
					rockCluster(folder, pos, s, rng, rgb(214, 212, 206), Enum.Material.Limestone, rgb(96, 150, 70))
				elseif k == 6 then
					bush(folder, pos, s, rng, rgb(76, 146, 64))
				else
					fern(folder, pos, s, rng, rgb(96, 166, 70))
				end
			elseif worldId == "wilds" then
				if k == 0 or k == 4 then
					mushroom(folder, pos, s, i % 2 == 0 and rgb(170, 140, 255) or rgb(120, 255, 210))
				elseif k == 1 or k == 6 then
					oakTree(folder, pos, s * 1.25, rng, rgb(60, 48, 44), rgb(46, 84, 60), rgb(190, 255, 220))
				elseif k == 2 then
					pineTree(folder, pos, s * 1.1, rng, rgb(56, 44, 40), rgb(36, 66, 50))
				elseif k == 3 or k == 8 then
					fern(folder, pos, s * 1.2, rng, rgb(52, 100, 66))
				elseif k == 5 then
					rockCluster(folder, pos, s, rng, rgb(84, 86, 80), Enum.Material.Rock, rgb(56, 96, 60))
				else
					lantern(folder, pos, rgb(255, 210, 140))
				end
			elseif worldId == "astral" then
				if k % 3 == 0 then
					pillar(folder, pos, rng:NextNumber(12, 22), rgb(80, 72, 130), rgb(240, 200, 120), Enum.Material.Marble)
				elseif k % 3 == 1 then
					floatingShard(folder, pos + V(0, rng:NextNumber(8, 16), 0), s, i % 4 == 1 and rgb(255, 220, 150) or rgb(170, 140, 255))
				else
					rockCluster(folder, pos, s, rng, rgb(70, 62, 110), Enum.Material.Basalt)
				end
			end
		end
	end
	-- partículas ambientes espalhadas pela ilha
	local ambientKind = ({ verdant = "pollen", crystal = "glints", sky = "mist", wilds = "spores", astral = "glints" })[worldId]
	for i = 1, 10 do
		local spot = freeSpot(c, w.radius, rng, worldId)
		if spot and ambientKind then
			local kind = (worldId == "verdant" or worldId == "wilds") and i % 3 == 0 and "fireflies" or ambientKind
			WorldBuilder.ambient(folder, spot + V(0, kind == "mist" and 3 or 4, 0), kind, kind == "mist" and 30 or 18)
		end
	end
end

-------------------------------------------------------------------------------
-- Mundo 1 — cenário inspirado nas referências do autor (docs/concept/world1_ref_*.jpg):
-- árvore ancestral gigante sobre um platô de musgo, lago turquesa, cachoeiras caindo de
-- penhascos cobertos de musgo, cachoeiras na borda da ilha, árvores-bonsai e flores roxas.
-------------------------------------------------------------------------------

local WATERFALL = rgb(200, 240, 255)

function WorldBuilder.mossRock(parent, pos: Vector3, s: number)
	return rockCluster(parent, pos, s, Random.new(math.floor(pos.X * 7 + pos.Z * 13)), rgb(110, 116, 108), Enum.Material.Slate, MOSS)
end

-- Versão baixa e de copa larga e achatada (no lugar do antigo bonsai/acácia).
function WorldBuilder.bonsai(parent, pos: Vector3, s: number, rng: Random, leaf: Color3)
	return branchTree(parent, pos, s, rng, BARK, leaf, nil, { name = "Bonsai", trunk = 4.8, branches = 5, rise = 0.38, spread = 1.15, leader = 3.2, cluster = 3.3, hang = 3 })
end

function WorldBuilder.flowerBush(parent, pos: Vector3, s: number, rng: Random, color: Color3)
	foliage(parent, pos + V(0, 1.1 * s, 0), V(2.3, 1.3, 2.1) * s, MOSS2, rng, 14, 1, 0.85)
	for k = 1, 6 do
		-- flor: duas pétalas cruzadas (estrela de 4 pontas) + miolo
		local ang = k / 6 * math.pi * 2 + rng:NextNumber(0, 0.5)
		local fp = pos + V(math.cos(ang) * 1.7 * s, (2.1 + rng:NextNumber(0, 0.6)) * s, math.sin(ang) * 1.5 * s)
		local col = color:Lerp(rgb(255, 255, 255), rng:NextNumber(0, 0.25))
		local tilt = CF(fp) * ANG(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4))
		for q = 0, 1 do
			part({ Name = "Petals", Size = V(1.05, 0.08, 0.38) * s, CFrame = tilt * ANG(0, q * rad(90), 0), Color = col, Material = Enum.Material.SmoothPlastic, CanCollide = false,
				CastShadow = false, Parent = parent })
		end
		part({ Name = "FlowerCore", Size = V(0.3, 0.14, 0.3) * s, CFrame = tilt * CF(0, 0.06 * s, 0) * ANG(0, rad(45), 0), Color = rgb(255, 222, 110), CanCollide = false, CastShadow = false, Parent = parent })
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
	-- respingos: gotas que saltam da base da queda d'água
	local splash = Instance.new("ParticleEmitter")
	splash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	splash.Color = ColorSequence.new(rgb(235, 250, 255))
	splash.LightEmission = 0.3
	splash.Size = NumberSequence.new(0.35, 0.05)
	splash.Lifetime = NumberRange.new(0.5, 0.9)
	splash.Rate = 18
	splash.Speed = NumberRange.new(6, 12)
	splash.SpreadAngle = Vector2.new(35, 35)
	splash.Acceleration = V(0, -35, 0)
	splash.Parent = foam
end

WorldBuilder.waterfall = function(...)
	return waterfall(...)
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
	-- ÁRVORE ANCESTRAL (tronco retorcido, raízes, galhos e copa de cubos no estilo da árvore de galhos)
	local base = lc + V(0, plateauTop + 0.8, 0)
	local seg = { { 0, 9, 0, 13 }, { 0.12, 8, 0.05, 12 }, { -0.1, 7, -0.06, 12 }, { 0.08, 5.5, 0.04, 11 } }
	local cfT = CF(base)
	for _, sgm in ipairs(seg) do
		local piece = cfT * ANG(sgm[1], 0, sgm[3]) * CF(0, sgm[4] / 2, 0)
		part({ Name = "AncientTrunk", Shape = Enum.PartType.Cylinder, Size = V(sgm[4] + 1, sgm[2] * 2, sgm[2] * 2), CFrame = piece * ANG(0, 0, rad(90)),
			Color = TREE_BARK, Material = Enum.Material.Wood, Parent = folder })
		part({ Name = "TrunkMoss", Size = V(0.8, sgm[4] * 0.55, sgm[2] * 1.1), CFrame = piece * CF(sgm[2] * 0.95, 0, 0) * ANG(rad(8), 0, rad(-4)), Color = MOSS2, Material = Enum.Material.LeafyGrass,
			CanCollide = false, Parent = folder })
		cfT = piece * CF(0, sgm[4] / 2, 0)
	end
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local rootCf = CF(base + V(math.cos(a) * 9, 1.5, math.sin(a) * 9)) * ANG(0, -a, 0) * ANG(0, 0, rad(-28))
		part({ Name = "Root", Size = V(14, 3.2, 3.6), CFrame = rootCf, Color = TREE_BARK:Lerp(rgb(0, 0, 0), 0.2), Material = Enum.Material.Wood, Parent = folder })
	end
	local crown = cfT.Position
	local canopyCenters = {}
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.4
		local len = 20 + (i % 3) * 4
		local dir = V(math.cos(a), 0.45 + (i % 2) * 0.2, math.sin(a)).Unit
		local from = crown - V(0, 6 + (i % 3) * 4, 0)
		local to = from + dir * len
		part({ Name = "Branch", Size = V(3.2, 3.2, len), CFrame = CF((from + to) / 2, to), Color = TREE_BARK, Material = Enum.Material.Wood, Parent = folder })
		table.insert(canopyCenters, to + V(0, 2, 0))
	end
	table.insert(canopyCenters, crown + V(0, 6, 0))
	-- copa no estilo da árvore de galhos e cubos: cachos de cubos de grama em verdes escuros,
	-- com cachos pendentes presos por ramos finos
	for i, cpos in ipairs(canopyCenters) do
		local crng = Random.new(500 + i)
		local col = i % 2 == 0 and rgb(70, 128, 52) or rgb(58, 112, 46)
		local big = i == #canopyCenters and 1.35 or 1
		for k = 1, 4 do
			local a = k / 4 * math.pi * 2 + crng:NextNumber(-0.4, 0.4)
			cubeCluster(folder, cpos + V(math.cos(a) * 6 * big, 1.5 + crng:NextNumber(-1, 2), math.sin(a) * 6 * big), 7 * big, col, crng, 5)
		end
		cubeCluster(folder, cpos + V(0, 4.5 * big, 0), 8.5 * big, col, crng, 6)
		for k = 1, 2 do
			local a = k * 2.6 + i
			local p0 = cpos + V(math.cos(a) * 8, -1, math.sin(a) * 8)
			local p1 = p0 + V(math.cos(a) * 2, -(6 + (k % 2) * 3), math.sin(a) * 2)
			cyl({ Name = "Twig", Color = TREE_BARK, Material = Enum.Material.Wood, CanCollide = false, Parent = folder }, p0, p1, 0.35)
			cubeCluster(folder, p1, 4.2, col, crng, 3, 1.7)
		end
		WorldBuilder.ambient(folder, cpos + V(0, -6, 0), "fireflies", 10)
	end
	-- penhascos de musgo atrás do lago com cachoeiras altas
	local side = V(-outward.Z, 0, outward.X)
	for i = -3, 3 do
		local p = lc + outward * (R + 18) + side * (i * 12)
		local h = 26 + (3 - math.abs(i)) * 4
		-- penhasco natural: colunas de rocha de alturas e inclinações diferentes, com musgo no topo e escorrendo
		local crng = Random.new(900 + i)
		for k = 1, 3 do
			local hh = h * (k == 1 and 1 or crng:NextNumber(0.55, 0.85))
			local off = side * crng:NextNumber(-4.5, 4.5) + outward * crng:NextNumber(-1.5, 2.5)
			local cp = p + off + V(0, hh / 2 - 2, 0)
			part({ Name = "Cliff", Size = V(crng:NextNumber(6, 9), hh, crng:NextNumber(7, 10)), CFrame = CF(cp, cp + outward) * ANG(crng:NextNumber(-0.06, 0.06), crng:NextNumber(-0.3, 0.3), crng:NextNumber(-0.07, 0.07)),
				Color = rgb(92, 98, 92):Lerp(rgb(130, 128, 116), crng:NextNumber(0, 0.35)), Material = Enum.Material.Slate, Parent = folder })
			ellipsoid({ Name = "CliffMoss", Size = V(8.5, 3, 9), CFrame = CF(p + off + V(0, hh - 1.8, 0)), Color = k == 2 and MOSS2 or MOSS, Material = Enum.Material.Grass, CanCollide = false, Parent = folder })
			if k == 1 then
				part({ Name = "MossDrip", Size = V(3, hh * 0.45, 0.6), CFrame = CF(p + off - outward * 4.6 + V(0, hh * 0.72, 0), p + off - outward * 10 + V(0, hh * 0.72, 0)),
					Color = MOSS2, Material = Enum.Material.Grass, CanCollide = false, CastShadow = false, Parent = folder })
			end
		end
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
				WorldBuilder.bonsai(folder, pos, 1.2, rng, i % 2 == 0 and rgb(84, 140, 56) or rgb(66, 124, 48))
			else
				WorldBuilder.flowerBush(folder, pos, 1.1, rng, i % 2 == 0 and rgb(160, 110, 230) or rgb(200, 150, 255))
			end
		end
	end
	return folder
end

-------------------------------------------------------------------------------
-- ANEL DE MATA (exploração): entre o raio `core` (parte central original, com praça, ovos, arena,
-- zonas e regiões feitas à mão) e o raio da ilha. Floresta densa em bosques e clareiras, uma trilha
-- em volta da ilha com ligações ao centro e seis lugares para descobrir, cada um com um baú-santuário
-- de verdade (RegionService.claim: recompensa da tabela Drops.Shrine e recarga por jogador).
-------------------------------------------------------------------------------

local RING = {
	verdant = { name = "Mata Profunda", bark = rgb(96, 58, 50), leaves = { rgb(62, 118, 46), rgb(76, 136, 54), rgb(54, 104, 42), rgb(84, 140, 58) },
		shrub = rgb(58, 112, 44), rock = rgb(112, 116, 108), rockMat = Enum.Material.Slate, moss = MOSS, stone = rgb(150, 146, 136), accent = rgb(150, 255, 140),
		cell = 16.5, density = 0.68, cap = rgb(220, 70, 60) },
	crystal = { name = "Bosque de Safira", bark = rgb(84, 66, 74), leaves = { rgb(70, 120, 214), rgb(110, 84, 210), rgb(58, 112, 214), rgb(124, 92, 226) },
		shrub = rgb(54, 110, 120), rock = rgb(70, 72, 92), rockMat = Enum.Material.Slate, moss = rgb(70, 130, 92), stone = rgb(150, 148, 162), accent = rgb(140, 210, 255),
		cell = 19.5, density = 0.55, crystals = true, cap = rgb(150, 110, 255) },
	wilds = { name = "Mata Sussurrante", bark = rgb(60, 48, 44), leaves = { rgb(46, 84, 60), rgb(40, 74, 56), rgb(56, 96, 66) }, glow = rgb(190, 255, 220),
		shrub = rgb(48, 92, 62), rock = rgb(84, 86, 80), rockMat = Enum.Material.Rock, moss = rgb(56, 96, 60), stone = rgb(110, 112, 104), accent = rgb(180, 140, 255),
		cell = 16.5, density = 0.68, cap = rgb(170, 140, 255) },
	astral = { name = "Bosque Estelar", bark = rgb(70, 60, 100), leaves = { rgb(150, 120, 230), rgb(120, 100, 210), rgb(176, 150, 250) }, glow = rgb(255, 220, 150),
		shrub = rgb(104, 86, 170), rock = rgb(70, 62, 110), rockMat = Enum.Material.Basalt, stone = rgb(96, 88, 140), accent = rgb(255, 220, 150),
		cell = 18, density = 0.55, shards = true, cap = rgb(255, 210, 140) },
}
WorldBuilder.Ring = RING

-- Faixas (θ em graus) onde a mata não entra: riachos e cachoeiras que descem até a borda.
local function ringKeepOut(worldId: string)
	local out = {}
	if worldId == "verdant" then
		local t = WorldBuilder.Layout.verdantLake.theta
		table.insert(out, { theta = t - 18, w = 6 })
		table.insert(out, { theta = t + 20, w = 6 })
	elseif worldId == "crystal" then
		table.insert(out, { theta = Regions.Info.prism_lake.theta, w = 7 }) -- riacho de saída do lago até a borda
	end
	return out
end

local function angDiff(a: number, b: number): number
	return math.abs((a - b + 180) % 360 - 180)
end

-- Baú-santuário da mata (mesmo funcionamento dos baús das regiões).
local function ringChest(parent: Instance, at: CFrame, title: string, st)
	local model = Make("Model", { Name = "ShrineChest", Parent = parent })
	local box = part({ Name = "ChestBox", Size = V(4, 2.4, 2.8), CFrame = at * CF(0, 1.2, 0), Color = rgb(122, 82, 50), Material = Enum.Material.WoodPlanks, Parent = model })
	part({ Name = "ChestLid", Size = V(4.1, 1, 2.9), CFrame = at * CF(0, 2.9, 0), Color = rgb(138, 94, 58), Material = Enum.Material.WoodPlanks, Parent = model })
	for _, x in ipairs({ -1.5, 1.5 }) do
		part({ Name = "ChestBand", Size = V(0.4, 3.5, 3), CFrame = at * CF(x, 1.75, 0), Color = rgb(226, 186, 90), Material = Enum.Material.Metal, Parent = model })
	end
	part({ Name = "ChestLock", Size = V(0.8, 0.9, 0.3), CFrame = at * CF(0, 2.3, -1.5), Color = rgb(226, 186, 90), Material = Enum.Material.Metal, Parent = model })
	part({ Name = "ChestGem", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = at * CF(0, 3.9, 0), Color = st.accent, Material = Enum.Material.Neon, CanCollide = false,
		CastShadow = false, Parent = model })
	local prompt = Make("ProximityPrompt", { ActionText = "Abrir", ObjectText = title, HoldDuration = 0.6, MaxActivationDistance = 12, RequiresLineOfSight = false, Parent = box })
	model.PrimaryPart = box
	return model, prompt
end

-- Arbusto leve de cubos (sub-bosque): 3 peças.
local function cubeShrub(parent, pos: Vector3, s: number, leaf: Color3, rng: Random)
	cubeCluster(parent, pos + V(0, 1.1 * s, 0), 2.3 * s, leaf, rng, 3, 0.5)
end

-- Os seis lugares da mata. Cada um recebe o chão (pos), a direção para o centro (inward) e devolve
-- o ponto do baú.
local POI = {}

POI.ruins = function(f, pos, inward, st, rng)
	local side = V(-inward.Z, 0, inward.X)
	for k = 1, 5 do
		local o = (k - 3) * 4.2
		part({ Name = "RuinSlab", Size = V(4, 0.6, rng:NextNumber(6, 9)), CFrame = CF(pos + side * o + inward * rng:NextNumber(-1.5, 1.5) + V(0, 0.05, 0)) * ANG(0, rng:NextNumber(-0.15, 0.15), 0),
			Color = st.stone:Lerp(rgb(0, 0, 0), rng:NextNumber(0, 0.15)), Material = Enum.Material.Slate, Parent = f })
	end
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2
		local q = pos + V(math.cos(a), 0, math.sin(a)) * 12
		local h = k % 3 == 0 and rng:NextNumber(3, 5) or rng:NextNumber(8, 12)
		part({ Name = "RuinColumn", Shape = Enum.PartType.Cylinder, Size = V(h, 2.4, 2.4), CFrame = CF(q + V(0, h / 2 - 0.3, 0)) * ANG(0, 0, rad(90)) * ANG(rng:NextNumber(-0.06, 0.06), 0, 0),
			Color = st.stone, Material = Enum.Material.Slate, Parent = f })
		if k % 3 ~= 0 then
			part({ Name = "RuinCapital", Size = V(3.2, 0.9, 3.2), CFrame = CF(q + V(0, h + 0.15, 0)) * ANG(0, a, 0), Color = st.stone:Lerp(rgb(255, 255, 255), 0.12), Material = Enum.Material.Slate, Parent = f })
		end
	end
	local a0 = rng:NextNumber(0, math.pi * 2)
	local fallen = pos + V(math.cos(a0), 0, math.sin(a0)) * 6
	part({ Name = "FallenColumn", Shape = Enum.PartType.Cylinder, Size = V(9, 2.4, 2.4), CFrame = CF(fallen + V(0, 1, 0)) * ANG(0, a0 + 1.2, 0), Color = st.stone, Material = Enum.Material.Slate, Parent = f })
	if st.moss then
		part({ Name = "RuinMoss", Size = V(6, 0.3, 3.5), CFrame = CF(fallen + V(0, 2.25, 0)) * ANG(0, a0 + 1.2, 0), Color = st.moss, Material = Enum.Material.LeafyGrass, CanCollide = false, Parent = f })
	end
	return pos + inward * 2, "Ruínas da " .. st.name
end

POI.pond = function(f, pos, inward, st, rng, terrainOk)
	local R = 12
	local ok = false
	if terrainOk then
		ok = pcall(function()
			local T = workspace:FindFirstChildOfClass("Terrain") :: Terrain
			T:FillCylinder(CF(pos - V(0, 2.5, 0)), 5, R, Enum.Material.Air)
			T:FillCylinder(CF(pos - V(0, 4, 0)), 4, R - 1, Enum.Material.Water)
		end)
	end
	if not ok then
		part({ Name = "PondWater", Shape = Enum.PartType.Cylinder, Size = V(0.6, R * 2, R * 2), CFrame = CF(pos + V(0, 0.15, 0)) * ANG(0, 0, rad(90)),
			Color = rgb(60, 180, 200), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false, Parent = f })
	end
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2 + 0.4
		rockCluster(f, pos + V(math.cos(a), 0, math.sin(a)) * (R + 2.5) - V(0, 0.6, 0), rng:NextNumber(0.6, 1), rng, st.rock, st.rockMat, st.moss)
	end
	for k = 1, 5 do
		local a = k * 2.2
		part({ Name = "LilyPad", Shape = Enum.PartType.Cylinder, Size = V(0.3, 2.8, 2.8), CFrame = CF(pos + V(math.cos(a) * (3 + k * 1.3), ok and -1.9 or 0.5, math.sin(a) * (3 + k * 1.3))) * ANG(0, 0, rad(90)),
			Color = rgb(80, 170, 70), CanCollide = false, Parent = f })
	end
	return pos + inward * (R + 6), "Lago Escondido da " .. st.name
end

POI.lookout = function(f, pos, inward, st, rng, terrainOk)
	local top = pos + V(0, 12, 0)
	local ok = false
	if terrainOk then
		ok = pcall(function()
			local T = workspace:FindFirstChildOfClass("Terrain") :: Terrain
			local g = Enum.Material[st.ground]
			T:FillBall(pos - V(0, 22, 0), 34, g)
			T:FillBall(pos + inward * 22 - V(0, 14, 0), 18, g) -- rampa do lado da trilha
		end)
	end
	if not ok then
		top = pos + V(0, 1, 0)
	end
	-- mirante de madeira no alto do morro
	local wood, roof = rgb(120, 84, 56), rgb(150, 70, 56)
	part({ Name = "LookoutFloor", Size = V(13, 0.8, 13), CFrame = CF(top + V(0, 0.6, 0)), Color = wood, Material = Enum.Material.WoodPlanks, Parent = f })
	for _, o in ipairs({ V(-5.6, 0, -5.6), V(5.6, 0, -5.6), V(-5.6, 0, 5.6), V(5.6, 0, 5.6) }) do
		part({ Name = "LookoutPost", Size = V(1, 16, 1), CFrame = CF(top + o + V(0, 2, 0)), Color = wood:Lerp(rgb(0, 0, 0), 0.15), Material = Enum.Material.Wood, Parent = f })
	end
	local rcf = CF(top + V(0, 11.2, 0)) * ANG(0, math.atan2(inward.X, inward.Z), 0)
	for _, side in ipairs({ -1, 1 }) do
		Make("WedgePart", { Name = "LookoutRoof", Anchored = true, Size = V(15, 3.2, 7.5), CFrame = rcf * CF(0, 0, side * 3.75) * ANG(0, side > 0 and math.pi or 0, 0),
			Color = roof, Material = Enum.Material.WoodPlanks, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth, Parent = f })
	end
	local sides = { V(0, 0, -6.2), V(0, 0, 6.2), V(-6.2, 0, 0), V(6.2, 0, 0) }
	local openIdx, best = 1, -2
	for i, o in ipairs(sides) do
		if o.Unit:Dot(inward) > best then
			openIdx, best = i, o.Unit:Dot(inward)
		end
	end
	for i, o in ipairs(sides) do
		local along = math.abs(o.X) > 0 and V(0.4, 1.2, 12) or V(12, 1.2, 0.4)
		if i ~= openIdx then -- o lado da subida fica aberto
			part({ Name = "LookoutRail", Size = along, CFrame = CF(top + o + V(0, 1.8, 0)), Color = wood, Material = Enum.Material.Wood, Parent = f })
		end
	end
	return top + V(0, 1, 0) - inward * 2, "Mirante da " .. st.name
end

POI.camp = function(f, pos, inward, st, rng)
	local side = V(-inward.Z, 0, inward.X)
	local cloth = { rgb(196, 120, 70), rgb(110, 140, 170) }
	for k, o in ipairs({ -7, 7 }) do
		local tp = pos + side * o - inward * 6
		local cf = CF(tp, tp + inward) * ANG(0, 0, 0)
		for _, sgn in ipairs({ -1, 1 }) do
			Make("WedgePart", { Name = "Tent", Anchored = true, Size = V(5, 4.6, 3), CFrame = cf * CF(sgn * 1.5, 2.3, 0) * ANG(0, -sgn * math.pi / 2, 0), Color = cloth[k],
				Material = Enum.Material.Fabric, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth, Parent = f })
		end
	end
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		part({ Name = "FireStone", Size = V(1.2, 0.9, 1.2), CFrame = CF(pos + V(math.cos(a) * 1.9, 0.35, math.sin(a) * 1.9)) * ANG(0, a, 0), Color = st.rock, Material = st.rockMat, Parent = f })
	end
	local holder = part({ Name = "Campfire", Size = V(2, 0.6, 2), CFrame = CF(pos + V(0, 0.3, 0)), Color = rgb(70, 46, 30), Material = Enum.Material.Wood, CanCollide = false, Parent = f })
	WorldBuilder.fire(holder, rgb(255, 140, 50), 0.8)
	Make("PointLight", { Color = rgb(255, 170, 90), Range = 16, Brightness = 1.4, Shadows = false, Parent = holder })
	for _, sgn in ipairs({ -1, 1 }) do
		cyl({ Name = "LogSeat", Color = rgb(110, 76, 50), Material = Enum.Material.Wood, Parent = f }, pos + side * sgn * 5 + inward * 2 + V(0, 0.8, 0), pos + side * sgn * 5 - inward * 3 + V(0, 0.8, 0), 0.8)
	end
	part({ Name = "Crate", Size = V(2.4, 2.4, 2.4), CFrame = CF(pos + side * 11 + V(0, 1.2, 0)) * ANG(0, 0.4, 0), Color = rgb(150, 110, 66), Material = Enum.Material.WoodPlanks, Parent = f })
	part({ Name = "Crate", Size = V(1.8, 1.8, 1.8), CFrame = CF(pos + side * 11 + V(0, 3.3, 0)) * ANG(0, 1.1, 0), Color = rgb(150, 110, 66), Material = Enum.Material.WoodPlanks, Parent = f })
	return pos - side * 10 - inward * 4, "Acampamento Abandonado"
end

POI.log = function(f, pos, inward, st, rng)
	local side = V(-inward.Z, 0, inward.X)
	local axis = side
	local R, len = 5.6, 26
	local bark = st.bark:Lerp(rgb(70, 50, 36), 0.4)
	-- tronco oco caído: anel de tábuas grossas, dá para atravessar por dentro
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		if k ~= 1 then -- uma fresta no alto deixa a luz entrar
			local off = V(0, math.cos(a), 0) * R + inward * math.sin(a) * R
			part({ Name = "LogShell", Size = V(3.7, 1.4, len), CFrame = CF(pos + off + V(0, R - 0.6, 0), pos + off + V(0, R - 0.6, 0) + axis) * ANG(0, 0, a), Color = bark,
				Material = Enum.Material.Wood, Parent = f })
		end
	end
	for _, sgn in ipairs({ -1, 1 }) do
		part({ Name = "LogMoss", Size = V(4.5, 0.5, 8), CFrame = CF(pos + axis * sgn * 6 + V(0, 2 * R - 0.4, 0), pos + axis * sgn * 6 + V(0, 2 * R - 0.4, 0) + axis), Color = st.moss or st.shrub,
			Material = Enum.Material.LeafyGrass, CanCollide = false, Parent = f })
	end
	for k = 1, 5 do
		local q = pos + axis * rng:NextNumber(-len / 2, len / 2) + inward * (R + 0.6) * (k % 2 == 0 and 1 or -1)
		ellipsoid({ Name = "LogShroom", Size = V(1.8, 0.7, 1.8), CFrame = CF(q + V(0, 1 + k % 3, 0)), Color = st.cap, CanCollide = false, Parent = f })
	end
	return pos + V(0, 0.2, 0), "Tronco Oco da " .. st.name
end

POI.stones = function(f, pos, inward, st, rng)
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		local q = pos + V(math.cos(a), 0, math.sin(a)) * 11
		local h = rng:NextNumber(7, 11)
		local stone = part({ Name = "StandingStone", Size = V(2.6, h, 1.6), CFrame = CF(q + V(0, h / 2 - 0.8, 0)) * ANG(0, -a + math.pi / 2, rng:NextNumber(-0.08, 0.08)),
			Color = st.stone:Lerp(rgb(0, 0, 0), rng:NextNumber(0, 0.2)), Material = Enum.Material.Slate, Parent = f })
		part({ Name = "StoneRune", Size = V(0.8, 1.6, 0.1), CFrame = stone.CFrame * CF(0, h * 0.15, -0.82), Color = st.accent, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false, Parent = f })
	end
	part({ Name = "Altar", Size = V(5, 1.4, 3.4), CFrame = CF(pos + V(0, 0.7, 0)) * ANG(0, math.atan2(inward.X, inward.Z), 0), Color = st.stone, Material = Enum.Material.Slate, Parent = f })
	return pos + inward * 4, "Círculo de Pedras da " .. st.name
end

local POI_ORDER = { "ruins", "pond", "lookout", "camp", "log", "stones" }

-- Plano do anel (determinístico): trilha, faixas proibidas e os seis lugares. Usado também pelo
-- terreno (as colinas da borda não sobem em cima dos lugares).
function WorldBuilder.ringPlan(worldId: string)
	local w = Worlds.Info[worldId]
	if not RING[worldId] or not w.core or w.radius <= w.core + 30 then
		return nil
	end
	local rng = Random.new(w.index * 4099)
	local R0, R1 = w.core + 8, w.radius - 10
	local Rm = (R0 + R1) / 2
	local keep = ringKeepOut(worldId)
	local function blocked(theta: number, margin: number)
		for _, k in ipairs(keep) do
			if angDiff(theta, k.theta) < k.w + margin then
				return true
			end
		end
		return false
	end
	local function trailR(theta: number): number
		return Rm + math.sin(rad(theta) * 5 + w.index) * 7
	end
	local pois = {}
	for i, kind in ipairs(POI_ORDER) do
		local theta = (i - 1) * 60 + 25 + rng:NextNumber(-8, 8)
		while blocked(theta, 12) do
			theta += 7
		end
		local outer = i % 2 == 0
		local pos = WorldBuilder.polar(w.center, theta, trailR(theta) + (outer and 20 or -18))
		local inwardC = ((w.center - pos) * V(1, 0, 1)).Unit
		table.insert(pois, { kind = kind, pos = pos, theta = theta, r = kind == "lookout" and 30 or 20, inward = outer and inwardC or -inwardC, i = i })
	end
	return { R0 = R0, R1 = R1, Rm = Rm, keep = keep, blocked = blocked, trailR = trailR, pois = pois }
end

function WorldBuilder.wildRing(worldId: string, parent: Instance, terrainOk: boolean)
	local w = Worlds.Info[worldId]
	local out = { gates = {}, chests = {}, npcs = {}, pois = {}, walkPoints = {} }
	local plan = WorldBuilder.ringPlan(worldId)
	if not plan then
		return out
	end
	local st = table.clone(RING[worldId])
	st.ground = w.ground
	local c = w.center
	local f = Make("Folder", { Name = "WildRing", Parent = parent })
	local rng = Random.new(w.index * 7919)
	local R0, R1, blocked, trailR = plan.R0, plan.R1, plan.blocked, plan.trailR
	local T = terrainOk and workspace:FindFirstChildOfClass("Terrain") :: Terrain
	local pathMat = Enum.Material[(TERRAIN_STYLE[worldId] or TERRAIN_STYLE.verdant).path]
	-- trilha em volta da ilha (sinuosa) e quatro ligações com a parte central
	local trail = {}
	local function paveSegment(a: Vector3, b: Vector3)
		if T then
			T:FillBlock(CF((a + b) / 2 - V(0, 1, 0), (a + b) / 2 - V(0, 1, 0) + (b - a)), V(7, 2, (b - a).Magnitude + 3), pathMat)
		end
		table.insert(trail, { a = a, b = b })
	end
	local prev = WorldBuilder.polar(c, 0, trailR(0))
	for deg = 6, 360, 6 do
		local cur = WorldBuilder.polar(c, deg, trailR(deg))
		paveSegment(prev, cur)
		prev = cur
	end
	for _, th in ipairs({ 30, 150, 210, 330 }) do
		local t2 = th
		for _ = 1, 20 do
			if not blocked(t2, 4) and not Regions.isReserved(worldId, WorldBuilder.polar(c, t2, w.core - 6), 4) then
				break
			end
			t2 += 6
		end
		paveSegment(WorldBuilder.polar(c, t2, w.core - 6), WorldBuilder.polar(c, t2, trailR(t2)))
	end
	local function nearTrail(p: Vector3, d: number): boolean
		for _, sg in ipairs(trail) do
			local ab = (sg.b - sg.a) * V(1, 0, 1)
			local t = math.clamp(((p - sg.a) * V(1, 0, 1)):Dot(ab) / math.max(ab:Dot(ab), 1e-3), 0, 1)
			if (((sg.a + ab * t) - p) * V(1, 0, 1)).Magnitude < d then
				return true
			end
		end
		return false
	end
	-- seis lugares para descobrir (alternando por dentro e por fora da trilha), cada um com baú
	local pois = plan.pois
	for _, p in ipairs(pois) do
		local reach = p.kind == "pond" and 13 or (p.kind == "lookout" and 26 or 4)
		paveSegment(WorldBuilder.polar(c, p.theta, trailR(p.theta)), p.pos + p.inward * reach)
	end
	for i, p in ipairs(pois) do
		local pf = Make("Folder", { Name = "POI_" .. p.kind, Parent = f })
		local base = p.kind == "lookout" and p.pos or groundRay(p.pos)
		local chestPos, title = POI[p.kind](pf, base, p.inward, st, rng, terrainOk)
		local id = worldId .. "_wild_" .. p.kind
		local model, prompt = ringChest(pf, CF(chestPos, chestPos + p.inward), title, st)
		out.chests[id] = { model = model, prompt = prompt, pos = chestPos, title = title, region = nil }
		out.walkPoints[title] = chestPos + p.inward * 4 + V(0, 2.5, 0)
		table.insert(out.pois, { kind = p.kind, pos = base, title = title, chest = id, index = i })
	end
	local function nearPoi(q: Vector3, m: number): boolean
		for _, p in ipairs(pois) do
			if ((q - p.pos) * V(1, 0, 1)).Magnitude < p.r + m then
				return true
			end
		end
		return false
	end
	-- FLORESTA: grade com sorteio modulado por um "ruído" de senos (bosques fechados e clareiras)
	local trees = Make("Folder", { Name = "Forest", Parent = f })
	local cell = st.cell
	local phase = rng:NextNumber(0, 6.28)
	local count = 0
	for gx = -R1, R1, cell do
		for gz = -R1, R1, cell do
			local q = c + V(gx + rng:NextNumber(-cell * 0.4, cell * 0.4), 0, gz + rng:NextNumber(-cell * 0.4, cell * 0.4))
			local flat = (q - c) * V(1, 0, 1)
			local d = flat.Magnitude
			if d > R0 and d < R1 then
				local theta = math.deg(math.atan2(flat.Z, flat.X)) % 360
				local dens = 0.55 + 0.28 * math.sin(rad(theta) * 3 + phase) * math.cos(d / 23) + 0.17 * math.sin(rad(theta) * 7 + d / 17)
				if not blocked(theta, 2) and not nearTrail(q, 6) and not nearPoi(q, 6) and not Regions.isReserved(worldId, q, 6) then
					local roll = rng:NextNumber()
					local g = groundRay(q)
					if roll < dens * st.density * 1.45 then
						local s = rng:NextNumber(1.15, 1.85)
						local m = branchTree(trees, g, s, rng, st.bark, st.leaves[rng:NextInteger(1, #st.leaves)], (st.glow and rng:NextNumber() < 0.25) and st.glow or nil,
							{ name = "ForestTree", lite = true, branches = 3, trunk = rng:NextNumber(4.2, 5.8), rise = 0.7, spread = rng:NextNumber(1.0, 1.2), cluster = 4.1, leader = 4.5 })
						m:SetAttribute("Ring", true)
						count += 1
						if rng:NextNumber() < 0.6 then
							local a = rng:NextNumber(0, 6.28)
							cubeShrub(trees, groundRay(q + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(4, 7)), rng:NextNumber(0.8, 1.2), st.shrub, rng)
						end
					elseif roll < 0.9 then
						-- clareira: arbustos, pedras e (por mundo) cristais ou estilhaços flutuantes
						local k = rng:NextInteger(1, 4)
						if k == 1 and st.crystals then
							CrystalKit.cluster(trees, CF(g) * ANG(0, rng:NextNumber(0, 6.28), 0), rng, { count = 3, h = rng:NextNumber(4, 7), w = 1.1, styles = { "blue", "violet" }, rock = false })
						elseif k == 1 and st.shards then
							floatingShard(trees, g + V(0, rng:NextNumber(7, 13), 0), rng:NextNumber(0.8, 1.2), st.accent)
						elseif k == 2 then
							rockCluster(trees, g, rng:NextNumber(0.6, 1.1), rng, st.rock, st.rockMat, st.moss)
						else
							cubeShrub(trees, g, rng:NextNumber(0.8, 1.3), st.shrub, rng)
						end
					end
				end
			end
		end
	end
	out.treeCount = count
	-- partículas ambientes na mata (vaga-lumes/pólen/cintilação)
	local amb = ({ verdant = "fireflies", crystal = "glints", wilds = "spores", astral = "glints" })[worldId]
	for i = 1, 6 do
		WorldBuilder.ambient(f, WorldBuilder.polar(c, i * 60 + 55, plan.Rm) + V(0, 5, 0), amb, 30)
	end
	return out
end

-------------------------------------------------------------------------------
-- Bosque da árvore de blocos (Verdant Haven): a árvore de destaque da referência do autor e
-- seis árvores menores da mesma família (formas diferentes), entre a praça e a borda nordeste.
-------------------------------------------------------------------------------

WorldBuilder.BlockGrove = {
	{ theta = 38, dist = 120, variant = "hero" },
	{ theta = 24, dist = 152, variant = "wide" }, { theta = 52, dist = 185, variant = "tall" }, { theta = 34, dist = 196, variant = "round" },
	{ theta = 20, dist = 132, variant = "young" }, { theta = 40, dist = 80, variant = "young" }, { theta = 66, dist = 216, variant = "round" },
}

function WorldBuilder.blockGrove(parent: Instance)
	local w = Worlds.Info.verdant
	local folder = Make("Folder", { Name = "BlockTreeGrove", Parent = parent })
	local trees = {}
	for i, spot in ipairs(WorldBuilder.BlockGrove) do
		local pos = groundRay(WorldBuilder.polar(w.center, spot.theta, spot.dist))
		local rng = Random.new(7100 + i * 13)
		-- cada árvore varia escala, copa e quantidade de blocos/rosetas (nenhuma cópia idêntica)
		local opts = table.clone(BlockTree.Variants[spot.variant])
		if not opts.hero then
			opts.scale *= rng:NextNumber(0.88, 1.14)
			opts.crownW *= rng:NextNumber(0.85, 1.15)
			opts.crownD *= rng:NextNumber(0.85, 1.15)
			opts.crownH *= rng:NextNumber(0.9, 1.15)
			opts.blocks += rng:NextInteger(-2, 3)
			opts.rosettes = math.max(1, opts.rosettes + rng:NextInteger(-1, 1))
		end
		local m = BlockTree.build(folder, pos, rng, opts)
		m:SetAttribute("Variant", spot.variant)
		table.insert(trees, m)
	end
	return trees
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
		-- braseiro: bacia de metal com fogo de partículas (chama, brasas e fumaça) e luz
		part({ Name = "BrazierBowl", Shape = Enum.PartType.Cylinder, Size = V(1.2, 3.2, 3.2), CFrame = CF(pos + V(0, 17.6, 0)) * ANG(0, 0, rad(90)), Color = rgb(60, 54, 50),
			Material = Enum.Material.Metal, Parent = folder })
		local flame = part({ Name = "Brazier", Size = V(2.2, 0.5, 2.2), CFrame = CF(pos + V(0, 18.3, 0)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = folder })
		WorldBuilder.fire(flame, theme.trim, 1.6)
		Make("PointLight", { Color = theme.trim:Lerp(rgb(255, 190, 120), 0.4), Range = 26, Brightness = 1.6, Shadows = false, Parent = flame })
		if theme.deco == "crystals" then
			crystal(folder, pos + V(math.cos(a) * 6, 0, math.sin(a) * 6), 2.2, theme.trim)
		elseif theme.deco == "roots" then
			oakTree(folder, pos + V(math.cos(a) * 9, 0, math.sin(a) * 9), 1.25, Random.new(i * 17), rgb(90, 66, 46), rgb(70, 130, 60), theme.trim)
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

-- Peças do Mundo 3 (Skybound Kingdom): ilhas flutuantes de Terrain com silhueta própria,
-- pontes celestes de mármore e ouro, torres, palácio com anéis dourados, pavilhões, estátuas,
-- cais com navio voador, fontes, lanternas, nuvens de tempestade e bancos de nuvem.
-- Decoração não colide nem dispara Touched (exceto o que se pisa: pontes, escadas, pisos, cais).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Make = require(Shared.Util.Make)
local CrystalKit = require(script.Parent.CrystalKit)

local SkyKit = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB
local M = Enum.Material

local MARBLE, MARBLE2, GOLD, BLUE, WOOD = rgb(238, 234, 224), rgb(214, 210, 200), rgb(226, 184, 86), rgb(44, 62, 152), rgb(124, 90, 60)
SkyKit.MARBLE, SkyKit.GOLD = MARBLE, GOLD

local part, wedge = CrystalKit.part, CrystalKit.wedge

local function cyl(props, a: Vector3, b: Vector3, radius: number)
	props.Shape = Enum.PartType.Cylinder
	props.Size = V((b - a).Magnitude, radius * 2, radius * 2)
	props.CFrame = CF((a + b) / 2, b) * ANG(0, rad(90), 0)
	return part(props)
end
SkyKit.cyl = cyl

-------------------------------------------------------------------------------
-- Ilha flutuante
-------------------------------------------------------------------------------

-- Ilha de Terrain: topo de grama com contorno lobado, camada de rocha clara, base que afina em
-- degraus irregulares, saliências e "pingentes" de rocha embaixo; raízes e cipós pendurados,
-- cristais nas laterais e muro invisível na borda (com aberturas nas pontes).
-- opts = { gaps = { graus... } (direções das pontes, no referencial do mundo), roots, crystals, styles }
function SkyKit.island(T: Terrain?, parent: Instance, top: Vector3, r: number, depth: number, rng: Random, opts)
	opts = opts or {}
	local model = Make("Model", { Name = opts.name or "FloatingIsland", Parent = parent })
	local lobes = { { V(0, 0, 0), r } }
	for k = 1, opts.lobes or 4 do
		local a = k / (opts.lobes or 4) * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
		local d = r * rng:NextNumber(0.35, 0.55)
		table.insert(lobes, { V(math.cos(a) * d, 0, math.sin(a) * d), r * rng:NextNumber(0.42, 0.62) })
	end
	if T then
		for _, l in ipairs(lobes) do
			T:FillCylinder(CF(top + l[1] - V(0, 9, 0)), 14, l[2] * 0.97, M.Limestone)
		end
		for _, l in ipairs(lobes) do
			T:FillCylinder(CF(top + l[1] - V(0, 2, 0)), 4, l[2], M.Grass)
		end
		-- base: degraus que afinam para baixo, com deslocamentos (silhueta irregular)
		local n = 6
		for k = 0, n do
			local f = k / n
			local rr = r * 0.92 * (1 - f) ^ 1.15 + 3
			local off = V(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * r * 0.1
			T:FillCylinder(CF(top + off - V(0, 16 + f * depth, 0)) * ANG(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08)), depth / n + 4, rr, k % 3 == 2 and M.Slate or M.Limestone)
			-- saliências na borda de cada degrau
			for _ = 1, 3 do
				local a = rng:NextNumber(0, math.pi * 2)
				local br = math.max(3, rr * rng:NextNumber(0.25, 0.4))
				local y = math.min(top.Y - 16 - f * depth, top.Y - 4 - br)
				T:FillBall(V(top.X + math.cos(a) * rr * 0.85, y, top.Z + math.sin(a) * rr * 0.85) + off, br, M.Limestone)
			end
		end
		-- pingentes de rocha
		for _ = 1, opts.pendants or 5 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = r * rng:NextNumber(0.15, 0.6)
			local f0 = d / r
			local p = top + V(math.cos(a) * d, -16 - depth * (1 - f0) * 0.6, math.sin(a) * d)
			local br = math.max(3, r * 0.14)
			for k = 0, 2 do
				T:FillBall(p - V(0, k * br * 1.3, 0), br * (1 - k * 0.28), k == 1 and M.Slate or M.Limestone)
			end
		end
		T:FillBlock(CF(top - V(0, 16 + depth + 6, 0)) * ANG(rad(40), rad(45), rad(40)), Vector3.one * math.max(5, r * 0.18), M.Limestone)
	end
	-- raízes e cipós pendurados na borda
	for i = 1, opts.roots or math.floor(r / 4) do
		local a = i / (opts.roots or math.floor(r / 4)) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local dir = V(math.cos(a), 0, math.sin(a))
		local p0 = top + dir * r * rng:NextNumber(0.86, 0.98) - V(0, rng:NextNumber(5, 10), 0)
		local p = p0
		local thick = rng:NextNumber(0.35, 0.65)
		for s = 1, rng:NextInteger(2, 3) do
			local nxt = p + dir * rng:NextNumber(-0.5, 1.5) + V(0, -rng:NextNumber(4, 8), 0) + V(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
			cyl({ Name = "HangingRoot", Color = WOOD:Lerp(rgb(70, 50, 36), rng:NextNumber(0, 0.5)), Material = M.Wood, CastShadow = false, Parent = model }, p, nxt, thick * (1 - s * 0.2))
			p = nxt
		end
		if i % 2 == 0 then
			local len = rng:NextNumber(8, 18)
			part({ Name = "HangingVine", Size = V(0.5, len, 0.5), CFrame = CF(p0 + dir * 1.2 - V(0, len / 2, 0)), Color = rgb(78, 140, 70), Material = M.LeafyGrass, CastShadow = false, Parent = model })
		end
	end
	-- cristais nas laterais, apontando para fora e para baixo
	for i = 1, opts.crystals or 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local dir = V(math.cos(a), 0, math.sin(a))
		local q = top + dir * r * 0.72 - V(0, 18 + rng:NextNumber(0, depth * 0.3), 0)
		local normal = (dir * 0.9 + V(0, -0.45, 0)).Unit
		CrystalKit.cluster(model, CF(q, q + normal) * ANG(rad(-90), 0, 0), rng, { count = 4, h = rng:NextNumber(6, 11), w = 1.5,
			styles = (opts.styles or { "blue", "ice" }), rock = false, name = "SideCrystal" })
	end
	-- muro invisível na borda, com aberturas nas pontes
	local segs = math.max(12, math.floor(2 * math.pi * r / 10))
	for i = 1, segs do
		local a = (i - 0.5) / segs * math.pi * 2
		local deg = math.deg(a)
		local open = false
		for _, g in ipairs(opts.gaps or {}) do
			if math.abs((deg - g + 180) % 360 - 180) < (opts.gapWidth or 14) then
				open = true
			end
		end
		if not open then
			part({ Name = "IslandEdge", Size = V(2, 14, 2 * math.pi * r / segs + 1), CFrame = CF(top + V(math.cos(a) * (r + 0.5), 6, math.sin(a) * (r + 0.5))) * ANG(0, -a, 0),
				Transparency = 1, CanCollide = true, CanQuery = false, Parent = model })
		end
	end
	return { model = model, top = top, r = r, lobes = lobes }
end

-- Detalhes sob a ilha principal (que vem do terrainFill): pingentes, raízes e cristais.
function SkyKit.undersideDetail(T: Terrain?, parent: Instance, center: Vector3, r: number, rng: Random)
	local model = Make("Model", { Name = "MainUnderside", Parent = parent })
	if T then
		for i = 1, 14 do
			local a = i / 14 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local d = r * rng:NextNumber(0.35, 0.8)
			local p = center + V(math.cos(a) * d, -50 - (1 - d / r) * 40, math.sin(a) * d)
			for k = 0, 3 do
				T:FillBall(p - V(0, k * 7, 0), 9 - k * 2, k % 2 == 0 and M.Limestone or M.Slate)
			end
		end
	end
	for i = 1, 26 do
		local a = i / 26 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local dir = V(math.cos(a), 0, math.sin(a))
		local p = center + dir * (r - rng:NextNumber(1, 4)) - V(0, rng:NextNumber(6, 12), 0)
		local len = rng:NextNumber(8, 20)
		if i % 2 == 0 then
			cyl({ Name = "HangingRoot", Color = WOOD, Material = M.Wood, CastShadow = false, Parent = model }, p, p + dir * 1.5 - V(0, len, 0), rng:NextNumber(0.4, 0.8))
		else
			part({ Name = "HangingVine", Size = V(0.6, len, 0.6), CFrame = CF(p + dir * 1.5 - V(0, len / 2, 0)), Color = rgb(78, 140, 70), Material = M.LeafyGrass, CastShadow = false, Parent = model })
		end
	end
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.3
		local dir = V(math.cos(a), 0, math.sin(a))
		local q = center + dir * r * 0.86 - V(0, 30, 0)
		local normal = (dir + V(0, -0.5, 0)).Unit
		CrystalKit.cluster(model, CF(q, q + normal) * ANG(rad(-90), 0, 0), rng, { count = 5, h = rng:NextNumber(9, 15), w = 2, styles = { "blue", "pearl", "ice" }, rock = false })
	end
	return model
end

-------------------------------------------------------------------------------
-- Pontes e caminhos
-------------------------------------------------------------------------------

-- Ponte celeste de mármore com balaústres, frisos dourados, arcos por baixo e lanternas nas pontas.
function SkyKit.bridge(parent: Instance, a: Vector3, b: Vector3, width: number, rng: Random)
	local model = Make("Model", { Name = "SkyBridge", Parent = parent })
	local len = (b - a).Magnitude
	local flat = ((b - a) * V(1, 0, 1)).Unit
	local right = flat:Cross(V(0, 1, 0)).Unit
	local segs = math.max(4, math.floor(len / 6))
	local function at(t)
		return a:Lerp(b, t) + V(0, math.sin(t * math.pi) * math.min(6, len * 0.05), 0)
	end
	for i = 0, segs - 1 do
		local p0, p1 = at(i / segs), at((i + 1) / segs)
		local mid = (p0 + p1) / 2
		local look = CF(mid, mid + (p1 - p0))
		part({ Name = "Deck", Size = V(width, 1.4, (p1 - p0).Magnitude + 0.3), CFrame = look, Color = i % 2 == 0 and MARBLE or MARBLE2, Material = M.Limestone, CanCollide = true, Parent = model })
		for _, side in ipairs({ -1, 1 }) do
			local rail = look * CF(side * (width / 2 - 0.4), 1.9, 0)
			part({ Name = "Rail", Size = V(0.7, 0.5, (p1 - p0).Magnitude + 0.3), CFrame = rail, Color = MARBLE2, Material = M.Limestone, CanCollide = true, Parent = model })
			part({ Name = "Baluster", Size = V(0.5, 1.6, 0.5), CFrame = look * CF(side * (width / 2 - 0.4), 0.9, 0), Color = MARBLE, Material = M.Limestone, Parent = model })
			part({ Name = "GoldTrim", Size = V(0.2, 0.25, (p1 - p0).Magnitude + 0.3), CFrame = look * CF(side * (width / 2 + 0.05), -0.4, 0), Color = GOLD, Material = M.Metal, CastShadow = false, Parent = model })
		end
	end
	-- arcos decorativos por baixo (a ponte parece apoiada em abóbadas)
	for t = 0.25, 0.76, 0.5 do
		local p = at(t)
		for k = 0, 6 do
			local ang = math.pi * k / 6
			local q = p + flat * math.cos(ang) * 6 - V(0, 1.5 + math.sin(ang) * 5, 0)
			part({ Name = "Arch", Size = V(width * 0.8, 1.6, 3), CFrame = CF(q, q + flat) * ANG(-(ang - math.pi / 2), 0, 0), Color = MARBLE2, Material = M.Limestone, Parent = model })
		end
	end
	for _, p in ipairs({ a, b }) do
		for _, side in ipairs({ -1, 1 }) do
			SkyKit.lanternPost(model, p + right * side * (width / 2 + 1.2) - V(0, 0.6, 0), false)
		end
	end
	return model
end

-- Pilar de lanterna dourada (como na arte): base de mármore, painéis azuis, lanterna com luz.
function SkyKit.lanternPost(parent: Instance, pos: Vector3, light: boolean?)
	part({ Name = "LanternBase", Size = V(2.2, 1, 2.2), CFrame = CF(pos + V(0, 0.5, 0)), Color = MARBLE2, Material = M.Limestone, CanCollide = true, Parent = parent })
	part({ Name = "LanternShaft", Size = V(1.5, 3.2, 1.5), CFrame = CF(pos + V(0, 2.6, 0)), Color = MARBLE, Material = M.Limestone, CanCollide = true, Parent = parent })
	part({ Name = "LanternPanel", Size = V(1.56, 2, 1.0), CFrame = CF(pos + V(0, 2.6, 0)), Color = BLUE, Material = M.SmoothPlastic, CastShadow = false, Parent = parent })
	part({ Name = "LanternCap", Size = V(2, 0.4, 2), CFrame = CF(pos + V(0, 4.4, 0)), Color = GOLD, Material = M.Metal, Parent = parent })
	local lamp = part({ Name = "LanternLight", Size = V(1.1, 1.3, 1.1), CFrame = CF(pos + V(0, 5.3, 0)), Color = rgb(255, 214, 140), Material = M.Neon, CastShadow = false, Parent = parent })
	wedge({ Name = "LanternRoof", Size = V(1.8, 0.8, 0.9), CFrame = CF(pos + V(0, 6.3, -0.45)), Color = GOLD, Material = M.Metal, Parent = parent })
	wedge({ Name = "LanternRoof", Size = V(1.8, 0.8, 0.9), CFrame = CF(pos + V(0, 6.3, 0.45)) * ANG(0, math.pi, 0), Color = GOLD, Material = M.Metal, Parent = parent })
	if light then
		Make("PointLight", { Color = rgb(255, 210, 140), Range = 16, Brightness = 1.1, Shadows = false, Parent = lamp })
	end
end

-------------------------------------------------------------------------------
-- Arquitetura branca e dourada
-------------------------------------------------------------------------------

-- Torre: fuste de mármore com anéis dourados, janelas, varanda e telhado em degraus com pináculo.
-- broken = torre destruída (topo irregular, blocos caídos, cristal elétrico crescendo da ruína).
function SkyKit.tower(parent: Instance, pos: Vector3, h: number, r: number, rng: Random, broken: boolean?)
	local model = Make("Model", { Name = broken and "BrokenTower" or "Tower", Parent = parent })
	part({ Name = "TowerBase", Size = V(r * 2.6, 2, r * 2.6), CFrame = CF(pos + V(0, 1, 0)) * ANG(0, rad(45), 0), Color = MARBLE2, Material = M.Limestone, CanCollide = true, Parent = model })
	local shaftH = broken and h * rng:NextNumber(0.35, 0.6) or h
	cyl({ Name = "TowerShaft", Color = MARBLE, Material = M.Limestone, CanCollide = true, Parent = model }, pos + V(0, 2, 0), pos + V(0, 2 + shaftH, 0), r)
	for k = 1, math.floor(shaftH / 10) do
		cyl({ Name = "GoldRing", Color = GOLD, Material = M.Metal, CastShadow = false, Parent = model }, pos + V(0, 2 + k * 10 - 0.3, 0), pos + V(0, 2 + k * 10 + 0.3, 0), r + 0.25)
		for w = 0, 3 do
			local a = w * math.pi / 2 + k * 0.4
			part({ Name = "Window", Size = V(1.2, 2.6, 0.3), CFrame = CF(pos + V(math.cos(a) * r, 2 + k * 10 - 4, math.sin(a) * r), pos + V(math.cos(a) * r * 2, 2 + k * 10 - 4, math.sin(a) * r * 2)),
				Color = rgb(40, 56, 120), Material = M.SmoothPlastic, CastShadow = false, Parent = model })
		end
	end
	local topY = 2 + shaftH
	if broken then
		for k = 1, 5 do
			local a = k / 5 * math.pi * 2
			part({ Name = "JaggedTop", Size = V(r * 0.9, rng:NextNumber(2, 6), r * 0.7), CFrame = CF(pos + V(math.cos(a) * r * 0.7, topY + 1, math.sin(a) * r * 0.7)) * ANG(rng:NextNumber(-0.3, 0.3), -a, rng:NextNumber(-0.3, 0.3)),
				Color = MARBLE2, Material = M.Limestone, Parent = model })
		end
		for _ = 1, 4 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = r + rng:NextNumber(2, 7)
			part({ Name = "Rubble", Size = V(rng:NextNumber(2, 4), rng:NextNumber(1.5, 3), rng:NextNumber(2, 4)), CFrame = CF(pos + V(math.cos(a) * d, 1, math.sin(a) * d)) * ANG(rng:NextNumber(-0.4, 0.4), a, rng:NextNumber(-0.4, 0.4)),
				Color = MARBLE2, Material = M.Limestone, CanCollide = true, Parent = model })
		end
		CrystalKit.cluster(model, CF(pos + V(0, topY - 1, 0)), rng, { count = 4, h = r * 2.2, w = r * 0.45, styles = { "storm", "ice" }, rock = false, name = "StormCrystal" })
	else
		cyl({ Name = "Balcony", Color = MARBLE2, Material = M.Limestone, Parent = model }, pos + V(0, topY - 0.6, 0), pos + V(0, topY + 0.6, 0), r + 1.4)
		local roofR = r + 0.6
		for k = 0, 4 do
			local rr = roofR * (1 - k / 5)
			cyl({ Name = "Roof", Color = k % 2 == 0 and GOLD or rgb(54, 78, 170), Material = k % 2 == 0 and M.Metal or M.SmoothPlastic, Parent = model },
				pos + V(0, topY + 0.6 + k * 1.6, 0), pos + V(0, topY + 0.6 + (k + 1) * 1.6, 0), math.max(0.4, rr))
		end
		part({ Name = "Spire", Size = V(0.5, r * 2.2, 0.5), CFrame = CF(pos + V(0, topY + 8.6 + r * 1.1, 0)), Color = GOLD, Material = M.Metal, Parent = model })
		CrystalKit.shard(model, CF(pos + V(0, topY + 8.6 + r * 2.1, 0)), 2.6, 0.8, "pearl", true)
	end
	return model
end

-- Pavilhão octogonal com cúpula dourada (templo pequeno do porto/jardins).
function SkyKit.pavilion(parent: Instance, pos: Vector3, r: number, rng: Random)
	local model = Make("Model", { Name = "Pavilion", Parent = parent })
	cyl({ Name = "PavilionFloor", Color = MARBLE2, Material = M.Limestone, CanCollide = true, Parent = model }, pos, pos + V(0, 1.2, 0), r + 2)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local q = pos + V(math.cos(a) * r, 1.2, math.sin(a) * r)
		cyl({ Name = "PavilionColumn", Color = MARBLE, Material = M.Limestone, CanCollide = true, Parent = model }, q, q + V(0, 9, 0), 0.7)
		part({ Name = "Architrave", Size = V(1.4, 1.2, 2 * r * math.sin(math.pi / 8) + 1.2), CFrame = CF(pos + V(math.cos(a + math.pi / 8) * r * 0.93, 10.8, math.sin(a + math.pi / 8) * r * 0.93)) * ANG(0, -(a + math.pi / 8), 0),
			Color = MARBLE2, Material = M.Limestone, Parent = model })
	end
	cyl({ Name = "DomeRing", Color = GOLD, Material = M.Metal, Parent = model }, pos + V(0, 11.3, 0), pos + V(0, 11.9, 0), r + 0.8)
	local dome = part({ Name = "Dome", Size = V(r * 2.1, r * 1.4, r * 2.1), CFrame = CF(pos + V(0, 11.8, 0)), Color = GOLD, Material = M.Metal, Parent = model })
	Make("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = dome })
	part({ Name = "Finial", Size = V(0.4, 3.4, 0.4), CFrame = CF(pos + V(0, 12 + r * 0.7 + 1.5, 0)), Color = GOLD, Material = M.Metal, Parent = model })
	CrystalKit.shard(model, CF(pos + V(0, 1.2, 0)), 3.6, 1.2, "blue", true)
	return model
end

-- Anéis dourados flutuando em torno do pináculo do palácio + feixe de luz para o céu (como na arte).
function SkyKit.haloRings(parent: Instance, center: Vector3, radius: number)
	local model = Make("Model", { Name = "HaloRings", Parent = parent })
	for ringIdx, tilt in ipairs({ { rad(12), 0 }, { rad(-8), rad(25) } }) do
		local rr = radius * (ringIdx == 1 and 1 or 0.82)
		local n = 22
		local rot = CF(center + V(0, ringIdx * 4, 0)) * ANG(tilt[1], tilt[2], 0)
		for k = 0, n - 1 do
			local a = k / n * math.pi * 2
			part({ Name = "HaloSegment", Size = V(1.6, 1.0, 2 * math.pi * rr / n + 0.4), CFrame = rot * CF(math.cos(a) * rr, 0, math.sin(a) * rr) * ANG(0, -a, 0),
				Color = GOLD, Material = M.Metal, Reflectance = 0.1, CastShadow = false, Parent = model })
		end
	end
	local beam = part({ Name = "LightBeam", Shape = Enum.PartType.Cylinder, Size = V(160, 2.4, 2.4), CFrame = CF(center + V(0, 80, 0)) * ANG(0, 0, rad(90)),
		Color = rgb(200, 230, 255), Material = M.Neon, Transparency = 0.55, CastShadow = false, Parent = model })
	beam:SetAttribute("Decorative", true)
	return model
end

-- Palácio celestial: terraços com escadarias, colunata, torreões, torre central com anéis e feixe.
function SkyKit.palace(parent: Instance, at: CFrame, rng: Random)
	local model = Make("Model", { Name = "CelestialPalace", Parent = parent })
	local function block(name, cf, size, color, mat, collide)
		return part({ Name = name, Size = size, CFrame = at * cf, Color = color, Material = mat or M.Limestone, CanCollide = collide ~= false, Parent = model })
	end
	-- terraço 1 (amplo) e terraço 2
	block("Terrace1", CF(0, 1.5, 0), V(46, 3, 40), MARBLE2)
	block("Terrace1Trim", CF(0, 3.1, 0), V(46.6, 0.4, 40.6), GOLD, M.Metal, false)
	CrystalKit.stairs(model, at * CF(0, 0, -20 - 3 * 1.6) * ANG(0, math.pi, 0), 3, 16, 1, 1.6)
	block("Terrace2", CF(0, 4.5, 4), V(32, 3, 26), MARBLE)
	CrystalKit.stairs(model, at * CF(0, 3, -9 - 3 * 1.6) * ANG(0, math.pi, 0), 3, 12, 1, 1.6)
	-- colunata frontal com frontão
	for k = -3, 3 do
		local q = (at * CF(k * 4.2, 6, -8.5)).Position
		cyl({ Name = "Colonnade", Color = MARBLE, Material = M.Limestone, CanCollide = true, Parent = model }, q, q + V(0, 11, 0), 0.8)
	end
	block("Entablature", CF(0, 17.8, -8.5), V(30, 1.8, 3), MARBLE2, nil, false)
	block("GoldFrieze", CF(0, 17.2, -10.05), V(30, 0.5, 0.2), GOLD, M.Metal, false)
	wedge({ Name = "Pediment", Size = V(3, 5, 15), CFrame = at * CF(-7.5, 21.2, -8.5) * ANG(0, rad(90), 0), Color = MARBLE, Material = M.Limestone, Parent = model })
	wedge({ Name = "Pediment", Size = V(3, 5, 15), CFrame = at * CF(7.5, 21.2, -8.5) * ANG(0, rad(-90), 0), Color = MARBLE, Material = M.Limestone, Parent = model })
	-- salão (keep) e torreões
	block("Keep", CF(0, 14, 6), V(22, 16, 16), MARBLE)
	block("KeepCornice", CF(0, 22.3, 6), V(23, 0.8, 17), GOLD, M.Metal, false)
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			SkyKit.tower(model, (at * CF(x * 13, 6, 6 + z * 9)).Position, 22, 2.6, rng, false)
		end
	end
	-- torre central altíssima com anéis e feixe de luz
	local spireBase = (at * CF(0, 22.6, 6)).Position
	SkyKit.tower(model, spireBase, 40, 4, rng, false)
	SkyKit.haloRings(model, spireBase + V(0, 46, 0), 16)
	-- estandartes azuis com emblema dourado
	for _, x in ipairs({ -9.5, 9.5 }) do
		CrystalKit.banner(model, at * CF(x, 4, -2.1), 12)
	end
	return model
end

-- Estátua de guardião alado sobre pedestal.
function SkyKit.statue(parent: Instance, at: CFrame)
	local model = Make("Model", { Name = "WingedStatue", Parent = parent })
	local function b(name, cf, size, color, mat)
		return part({ Name = name, Size = size, CFrame = at * cf, Color = color, Material = mat or M.Limestone, CanCollide = name == "Pedestal", Parent = model })
	end
	b("Pedestal", CF(0, 2, 0), V(5, 4, 5), MARBLE2)
	b("PedestalTrim", CF(0, 4.1, 0), V(5.4, 0.4, 5.4), GOLD, M.Metal)
	b("Robe", CF(0, 7.4, 0), V(2.6, 6, 2), MARBLE)
	b("Chest", CF(0, 11.2, 0), V(2.8, 2, 1.8), MARBLE)
	b("Head", CF(0, 13, -0.1), V(1.4, 1.6, 1.4), MARBLE)
	b("Crown", CF(0, 14, -0.1), V(1.6, 0.4, 1.6), GOLD, M.Metal)
	b("Sword", CF(0, 9, -1.4), V(0.4, 7, 0.2), GOLD, M.Metal)
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			wedge({ Name = "StatueWing", Size = V(0.4, 5 - k, 3.4 - k * 0.6), CFrame = at * CF(side * (2 + k * 1.6), 12 - k * 0.6, 1.2) * ANG(0, side * rad(70), side * rad(-25 + k * 10)),
				Color = MARBLE, Material = M.Limestone, Parent = model })
		end
	end
	return model
end

-- Cais de madeira saindo da borda + navio voador ancorado (casco, convés, mastro, vela, balão).
function SkyKit.harbor(parent: Instance, start: Vector3, dir: Vector3, rng: Random)
	local model = Make("Model", { Name = "CloudHarborDock", Parent = parent })
	local right = dir:Cross(V(0, 1, 0)).Unit
	local len = 34
	for i = 0, math.floor(len / 2) do
		local p = start + dir * i * 2 + V(0, 0.4, 0)
		part({ Name = "Plank", Size = V(8, 0.5, 1.8), CFrame = CF(p, p + right), Color = WOOD:Lerp(rgb(90, 64, 42), (i % 3) / 3), Material = M.WoodPlanks, CanCollide = true, Parent = model })
		if i % 4 == 0 then
			for _, side in ipairs({ -1, 1 }) do
				part({ Name = "DockPost", Size = V(0.9, 9, 0.9), CFrame = CF(p + right * side * 4.2 - V(0, 3, 0)), Color = rgb(96, 70, 48), Material = M.Wood, CanCollide = true, Parent = model })
			end
		end
	end
	-- corrimão de corda
	for _, side in ipairs({ -1, 1 }) do
		cyl({ Name = "DockRope", Color = rgb(190, 160, 110), Material = M.Fabric, CastShadow = false, CanCollide = true, Parent = model },
			start + right * side * 4.2 + V(0, 2.4, 0), start + dir * len + right * side * 4.2 + V(0, 2.4, 0), 0.15)
	end
	-- navio voador ancorado ao lado do cais
	local shipC = start + dir * (len * 0.6) + right * 13 + V(0, 2, 0)
	local sf = CF(shipC, shipC + dir)
	local function sp(name, cf, size, color, mat, shape)
		local props = { Name = name, Size = size, CFrame = sf * cf, Color = color, Material = mat or M.WoodPlanks, Parent = model }
		if shape == "wedge" then
			return wedge(props)
		end
		return part(props)
	end
	sp("Hull", CF(0, -1.5, 0), V(7, 4, 20), rgb(110, 76, 50))
	sp("HullBow", CF(0, -1.5, -12.5) * ANG(0, math.pi, 0), V(7, 4, 5), rgb(110, 76, 50), nil, "wedge")
	sp("Keel", CF(0, -4, 1), V(2, 2, 18), rgb(80, 56, 38))
	sp("Deck", CF(0, 0.6, 0), V(6.4, 0.4, 19), rgb(170, 130, 90))
	sp("GoldStripe", CF(0, -0.2, 0), V(7.1, 0.4, 20.1), GOLD, M.Metal)
	sp("Mast", CF(0, 8, -1), V(0.8, 15, 0.8), rgb(96, 70, 48), M.Wood)
	sp("Sail", CF(0, 9, -0.6), V(9, 9, 0.2), rgb(250, 246, 236), M.Fabric)
	sp("SailEmblem", CF(0, 9, -0.75), V(2.4, 2.4, 0.1), BLUE, M.Fabric)
	local balloon = sp("Balloon", CF(0, 20, 1), V(10, 8, 18), rgb(240, 236, 226), M.Fabric)
	Make("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = balloon })
	for _, x in ipairs({ -3, 3 }) do
		for _, z in ipairs({ -6, 7 }) do
			cyl({ Name = "BalloonRope", Color = rgb(190, 160, 110), Material = M.Fabric, CastShadow = false, Parent = model }, (sf * CF(x, 0.8, z)).Position, (sf * CF(x * 0.8, 16.5, z * 0.8)).Position, 0.12)
		end
	end
	sp("Rudder", CF(0, -0.5, 10.6), V(0.4, 4, 2.4), rgb(110, 76, 50))
	for _, side in ipairs({ -1, 1 }) do
		sp("Fin", CF(side * 4.2, 0, 4) * ANG(0, 0, side * rad(-20)), V(3, 0.3, 5), GOLD, M.Metal)
	end
	return model
end

-- Fonte de mármore com água em queda (partículas).
function SkyKit.fountain(parent: Instance, pos: Vector3)
	local model = Make("Model", { Name = "Fountain", Parent = parent })
	cyl({ Name = "Basin", Color = MARBLE2, Material = M.Limestone, CanCollide = true, Parent = model }, pos, pos + V(0, 1.6, 0), 6)
	cyl({ Name = "FountainWater", Color = rgb(110, 200, 235), Material = M.Glass, Transparency = 0.35, Parent = model }, pos + V(0, 1.2, 0), pos + V(0, 1.5, 0), 5.4)
	cyl({ Name = "FountainColumn", Color = MARBLE, Material = M.Limestone, Parent = model }, pos + V(0, 1.6, 0), pos + V(0, 5.4, 0), 0.9)
	cyl({ Name = "UpperBowl", Color = GOLD, Material = M.Metal, Parent = model }, pos + V(0, 5.2, 0), pos + V(0, 5.8, 0), 2.6)
	local jet = part({ Name = "FountainJet", Size = V(1, 1, 1), CFrame = CF(pos + V(0, 6, 0)), Transparency = 1, Parent = model })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(rgb(220, 245, 255))
	e.LightEmission = 0.3
	e.Size = NumberSequence.new(0.35, 0.1)
	e.Lifetime = NumberRange.new(0.7, 1)
	e.Rate = 30
	e.Speed = NumberRange.new(6, 9)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = V(0, -24, 0)
	e.Parent = jet
	return model
end

-- Nuvem 2D anime fixa no mundo (BillboardGui sem iluminação). kind = "storm" (escura, origem de
-- raios) ou "soft" (branca com sombra lavanda — bancos de nuvem abaixo das ilhas).
local CLOUD_COLORS = {
	storm = { rgb(62, 66, 96), rgb(104, 110, 146), rgb(150, 158, 196) },
	soft = { rgb(196, 198, 242), rgb(255, 255, 255), rgb(255, 250, 228) },
}
function SkyKit.cloud(parent: Instance, pos: Vector3, w: number, rng: Random, kind: string)
	local cols = CLOUD_COLORS[kind] or CLOUD_COLORS.soft
	local anchor = part({ Name = kind == "storm" and "StormCloud" or "SoftCloud", Size = V(2, 2, 2), CFrame = CF(pos), Transparency = 1, Parent = parent })
	anchor:SetAttribute("CloudKind", kind)
	anchor:SetAttribute("CloudWidth", w)
	if kind == "storm" then
		anchor:SetAttribute("LightningSource", true)
	end
	local b = Instance.new("BillboardGui")
	b.Size = UDim2.new(w, 0, w * 0.45, 0)
	b.LightInfluence = 0
	b.AlwaysOnTop = false
	b.MaxDistance = 5000
	b.Parent = anchor
	local function circle(x, y, r, color, z)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(r * 2, r * 2)
		f.SizeConstraint = Enum.SizeConstraint.RelativeYY
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.ZIndex = z
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
		f.Parent = b
	end
	local n = rng:NextInteger(5, 7)
	for k = 1, n do
		local x = 0.12 + (k - 1) / (n - 1) * 0.76
		local r = rng:NextNumber(0.24, 0.36)
		x = math.clamp(x, r * 0.45 + 0.02, 1 - r * 0.45 - 0.02)
		circle(x, 0.62 - r * 0.5 + 0.08, r, cols[1], 1)
		circle(x, 0.62 - r * 0.5, r * 0.96, cols[2], 2)
		if k % 2 == 0 then
			circle(x - 0.02, 0.62 - r * 0.95, r * 0.4, cols[3], 3)
		end
	end
	return anchor
end

function SkyKit.stormCloud(parent: Instance, pos: Vector3, w: number, rng: Random)
	return SkyKit.cloud(parent, pos, w, rng, "storm")
end

-- Banco de nuvens abaixo das ilhas: nuvens 2D brancas em alturas diferentes (profundidade).
function SkyKit.cloudBank(parent: Instance, pos: Vector3, size: number, rng: Random)
	for k = 1, 2 do
		SkyKit.cloud(parent, pos + V(rng:NextNumber(-0.5, 0.5) * size, (k - 1) * -size * 0.25, rng:NextNumber(-0.5, 0.5) * size), size * rng:NextNumber(1.6, 2.4), rng, "soft")
	end
end

return SkyKit

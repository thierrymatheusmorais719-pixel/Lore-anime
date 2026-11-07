-- Peças de construção do Mundo 2 (Crystal Hollow): espécies de cristal, arquitetura antiga,
-- pontes, portais de região, baús-santuário e NPCs. Tudo procedural, sem assets externos.
--
-- Desempenho: decoração não colide, não é consultada por raycast nem dispara Touched; peças
-- pequenas não projetam sombra. Luzes só nos cristais gigantes, portais e tochas.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Make = require(Shared.Util.Make)

local CrystalKit = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB

local function base(props)
	props.Anchored = true
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	if props.CanCollide == nil then
		props.CanCollide = false
	end
	if props.CanQuery == nil then
		props.CanQuery = props.CanCollide
	end
	props.CanTouch = false
	return props
end

local function part(props)
	return Make("Part", base(props))
end
CrystalKit.part = part

local function wedge(props)
	return Make("WedgePart", base(props))
end
CrystalKit.wedge = wedge

-------------------------------------------------------------------------------
-- Cristais
-------------------------------------------------------------------------------

-- Espécies: casca (vidro) + núcleo luminoso opcional. Cores e transparências diferentes.
CrystalKit.Styles = {
	blue = { shell = rgb(120, 196, 255), shellT = 0.32, refl = 0.18, core = rgb(70, 160, 255), coreW = 0.42 },
	violet = { shell = rgb(196, 150, 255), shellT = 0.32, refl = 0.15, core = rgb(160, 90, 255), coreW = 0.42 },
	sapphire = { shell = rgb(46, 86, 210), shellT = 0.15, refl = 0.3, core = rgb(90, 140, 255), coreW = 0.3 },
	ice = { shell = rgb(210, 238, 255), shellT = 0.22, refl = 0.25 },
	amethyst = { shell = rgb(120, 60, 190), shellT = 0.18, refl = 0.25, core = rgb(220, 140, 255), coreW = 0.3 },
	rare = { shell = rgb(255, 226, 250), shellT = 0.25, refl = 0.3, core = rgb(255, 160, 230), coreW = 0.45, core2 = rgb(255, 230, 140) },
}

-- Um cristal (prisma octogonal = dois blocos girados 45° + pontas em cumeeira).
-- `at` = base do cristal; o eixo do cristal é o +Y de `at`. detail=false → versão leve (3 peças).
function CrystalKit.shard(parent: Instance, at: CFrame, h: number, w: number, styleName: string, detail: boolean?)
	local st = CrystalKit.Styles[styleName] or CrystalKit.Styles.blue
	local bodyH, tipH = h * 0.74, h * 0.26
	local shadow = w > 1.6
	local function shell(cf: CFrame, size: Vector3, shape: string)
		local props = { Name = "Crystal", Size = size, CFrame = cf, Color = st.shell, Material = Enum.Material.Glass, Transparency = st.shellT, Reflectance = st.refl, CastShadow = shadow, Parent = parent }
		if shape == "wedge" then
			return wedge(props)
		end
		return part(props)
	end
	local turns = (detail == false) and { 0 } or { 0, 45 }
	for _, deg in ipairs(turns) do
		local r = at * ANG(0, rad(deg), 0)
		shell(r * CF(0, bodyH / 2, 0), V(w, bodyH, w), "block")
		-- ponta: duas cunhas formando uma cumeeira
		shell(r * CF(0, bodyH + tipH / 2, -w / 4), V(w, tipH, w / 2), "wedge")
		shell(r * CF(0, bodyH + tipH / 2, w / 4) * ANG(0, math.pi, 0), V(w, tipH, w / 2), "wedge")
	end
	if st.core and detail ~= false then
		-- núcleo luminoso visto através do vidro
		part({ Name = "CrystalCore", Size = V(w * st.coreW, bodyH * 0.92, w * st.coreW), CFrame = at * CF(0, bodyH * 0.5, 0) * ANG(0, rad(22), 0), Color = st.core,
			Material = Enum.Material.Neon, Transparency = 0.15, CastShadow = false, Parent = parent })
		if st.core2 then
			part({ Name = "CrystalCore", Size = V(w * 0.2, bodyH * 0.6, w * 0.2), CFrame = at * CF(w * 0.15, bodyH * 0.45, 0), Color = st.core2, Material = Enum.Material.Neon,
				CastShadow = false, Parent = parent })
		end
	end
end

-- Base de rocha quebrada (cunhas e blocos de basalto) onde os cristais nascem.
local function rockBase(parent: Instance, at: CFrame, size: number, rng: Random)
	for k = 1, 3 do
		local a = k / 3 * math.pi * 2 + rng:NextNumber(0, 1)
		local s = size * rng:NextNumber(0.6, 1)
		part({ Name = "CrystalRock", Size = V(s * 1.3, s * 0.7, s), CFrame = at * CF(math.cos(a) * size * 0.35, s * 0.15, math.sin(a) * size * 0.35) * ANG(rng:NextNumber(-0.3, 0.3), a, rng:NextNumber(-0.3, 0.3)),
			Color = rgb(52, 50, 70):Lerp(rgb(90, 86, 110), rng:NextNumber(0, 0.4)), Material = Enum.Material.Basalt, CanCollide = true, Parent = parent })
	end
end

-- Aglomerado: vários cristais saindo de uma base, com inclinações e alturas diferentes.
-- opts = { count, h, w, styles = {..}, spread (graus), rock = bool, detail = bool }
function CrystalKit.cluster(parent: Instance, at: CFrame, rng: Random, opts)
	local model = Make("Model", { Name = opts.name or "CrystalCluster", Parent = parent })
	local n = opts.count or 5
	local styles = opts.styles or { "blue" }
	if opts.rock ~= false then
		rockBase(model, at, opts.w * 2.2, rng)
	end
	for i = 1, n do
		local main = i == 1
		local h = opts.h * (main and 1 or rng:NextNumber(0.35, 0.75))
		local w = opts.w * (main and 1 or rng:NextNumber(0.45, 0.8))
		local tilt = main and rng:NextNumber(0, 6) or rng:NextNumber(14, opts.spread or 42)
		local yaw = (i / n) * 360 + rng:NextNumber(-25, 25)
		local off = main and V() or V(math.cos(rad(yaw)), 0, math.sin(rad(yaw))) * opts.w * rng:NextNumber(0.4, 0.9)
		local cf = at * CF(off) * ANG(0, rad(yaw), 0) * ANG(rad(tilt), 0, 0) * CF(0, -h * 0.08, 0)
		CrystalKit.shard(model, cf, h, w, styles[(i - 1) % #styles + 1], opts.detail ~= false and (main or h > 4))
	end
	return model
end

-- Cristal gigante: aglomerado enorme com luz própria e cintilação (marco visual das regiões).
-- noRock = true: nasce direto da rocha do Terrain (cumes, encostas) — sem base de pedras soltas.
function CrystalKit.giant(parent: Instance, pos: Vector3, scale: number, rng: Random, styles, lightColor: Color3?, noRock: boolean?)
	local at = CF(pos) * ANG(0, rng:NextNumber(0, 6.28), 0)
	local model = CrystalKit.cluster(parent, at, rng, { name = "GiantCrystal", count = 7, h = 22 * scale, w = 3.6 * scale, styles = styles, spread = 34, rock = not noRock })
	local glow = part({ Name = "GiantGlow", Size = V(2, 2, 2), CFrame = CF(pos + V(0, 8 * scale, 0)), Transparency = 1, Parent = model })
	Make("PointLight", { Color = lightColor or rgb(110, 180, 255), Range = math.min(60, 26 * scale), Brightness = 1.1, Shadows = false, Parent = glow })
	local e = Instance.new("ParticleEmitter")
	e.Name = "Glints"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(rgb(255, 255, 255), lightColor or rgb(140, 200, 255))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45 * scale), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(1.2, 2.4)
	e.Rate = 5
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = glow
	glow.Size = V(10 * scale, 14 * scale, 10 * scale)
	return model
end

-- Cristais pequenos espalhados no chão (versão leve).
function CrystalKit.scatter(parent: Instance, pos: Vector3, rng: Random, styles)
	local model = Make("Model", { Name = "CrystalShards", Parent = parent })
	for i = 1, rng:NextInteger(2, 4) do
		local a = rng:NextNumber(0, 6.28)
		local cf = CF(pos + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(0, 1.6)) * ANG(0, a, 0) * ANG(rad(rng:NextNumber(10, 35)), 0, 0)
		CrystalKit.shard(model, cf * CF(0, -0.3, 0), rng:NextNumber(1.2, 2.8), rng:NextNumber(0.35, 0.7), styles[(i - 1) % #styles + 1], false)
	end
	return model
end

-- Cristal raro: o "Coração Prismático" num pedestal, com dois tons e brilho especial.
function CrystalKit.rare(parent: Instance, pos: Vector3, rng: Random)
	local model = Make("Model", { Name = "RareCrystal", Parent = parent })
	part({ Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = V(1.6, 5, 5), CFrame = CF(pos + V(0, 0.8, 0)) * ANG(0, 0, rad(90)), Color = rgb(200, 196, 214),
		Material = Enum.Material.Marble, CanCollide = true, Parent = model })
	part({ Name = "PedestalTrim", Shape = Enum.PartType.Cylinder, Size = V(0.4, 5.4, 5.4), CFrame = CF(pos + V(0, 1.7, 0)) * ANG(0, 0, rad(90)), Color = rgb(230, 200, 120),
		Material = Enum.Material.Metal, Parent = model })
	CrystalKit.cluster(model, CF(pos + V(0, 1.8, 0)), rng, { count = 4, h = 6, w = 1.3, styles = { "rare", "ice", "rare", "violet" }, spread = 28, rock = false })
	local glow = part({ Name = "RareGlow", Size = V(3, 5, 3), CFrame = CF(pos + V(0, 4.5, 0)), Transparency = 1, Parent = model })
	Make("PointLight", { Color = rgb(255, 180, 235), Range = 18, Brightness = 1.4, Shadows = false, Parent = glow })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(rgb(255, 230, 250), rgb(255, 200, 120))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.4), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(1, 2)
	e.Rate = 8
	e.Speed = NumberRange.new(0.3, 1.2)
	e.Acceleration = V(0, 1.5, 0)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = glow
	return model
end

-------------------------------------------------------------------------------
-- Arquitetura antiga
-------------------------------------------------------------------------------

local STONE, STONE2, STONE_DARK, GOLD = rgb(150, 148, 160), rgb(122, 120, 136), rgb(84, 82, 98), rgb(214, 180, 96)
CrystalKit.STONE = STONE

-- Coluna de pedra com base e capitel; broken = quebrada (topo inclinado + pedaço caído).
function CrystalKit.column(parent: Instance, pos: Vector3, h: number, r: number, rng: Random, broken: boolean?)
	local model = Make("Model", { Name = "Column", Parent = parent })
	part({ Name = "Plinth", Size = V(r * 2.6, 1, r * 2.6), CFrame = CF(pos + V(0, 0.5, 0)), Color = STONE2, Material = Enum.Material.Slate, CanCollide = true, Parent = model })
	local shaftH = broken and h * rng:NextNumber(0.35, 0.7) or h
	part({ Name = "Shaft", Shape = Enum.PartType.Cylinder, Size = V(shaftH, r * 2, r * 2), CFrame = CF(pos + V(0, 1 + shaftH / 2, 0)) * ANG(0, 0, rad(90)),
		Color = STONE, Material = Enum.Material.Limestone, CanCollide = true, Parent = model })
	-- caneluras (faixas verticais) dão relevo ao fuste
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2
		part({ Name = "Flute", Size = V(0.35, shaftH * 0.94, 0.35), CFrame = CF(pos + V(math.cos(a) * r * 0.98, 1 + shaftH / 2, math.sin(a) * r * 0.98)), Color = STONE2,
			Material = Enum.Material.Limestone, CastShadow = false, Parent = model })
	end
	if broken then
		part({ Name = "BrokenTop", Size = V(r * 2, 1.2, r * 2), CFrame = CF(pos + V(0, 1 + shaftH + 0.2, 0)) * ANG(rad(rng:NextNumber(10, 25)), rng:NextNumber(0, 6), 0),
			Color = STONE, Material = Enum.Material.Limestone, Parent = model })
		local a = rng:NextNumber(0, 6.28)
		local fallLen = h - shaftH
		part({ Name = "FallenDrum", Shape = Enum.PartType.Cylinder, Size = V(fallLen * 0.6, r * 2, r * 2), CFrame = CF(pos + V(math.cos(a) * (r * 2 + fallLen * 0.35), r, math.sin(a) * (r * 2 + fallLen * 0.35))) * ANG(0, a, 0),
			Color = STONE2, Material = Enum.Material.Limestone, CanCollide = true, Parent = model })
	else
		part({ Name = "Capital", Size = V(r * 2.5, 1.2, r * 2.5), CFrame = CF(pos + V(0, 1.6 + shaftH, 0)), Color = STONE2, Material = Enum.Material.Slate, CanCollide = true, Parent = model })
	end
	return model
end

-- Arco de pedra (dois pilares + aduelas formando a curva). `at`: centro da base, olhando pelo vão.
function CrystalKit.arch(parent: Instance, at: CFrame, width: number, height: number, depth: number, rng: Random, ruined: boolean?)
	local model = Make("Model", { Name = "Arch", Parent = parent })
	local pw = math.max(2.4, width * 0.16)
	local legH = height - width / 2
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Pier", Size = V(pw, legH, depth), CFrame = at * CF(side * (width / 2 + pw / 2), legH / 2, 0), Color = STONE, Material = Enum.Material.Limestone, CanCollide = true, Parent = model })
		part({ Name = "PierBase", Size = V(pw + 1, 1.2, depth + 1), CFrame = at * CF(side * (width / 2 + pw / 2), 0.6, 0), Color = STONE2, Material = Enum.Material.Slate, CanCollide = true, Parent = model })
	end
	-- aduelas: blocos ao longo de um semicírculo
	local n = 9
	local rr = width / 2 + pw / 2
	for i = 0, n - 1 do
		if not (ruined and (i == 5 or i == 6) ) then
			local a = math.pi * (i + 0.5) / n
			local blockLen = math.pi * rr / n + 0.3
			part({ Name = "Voussoir", Size = V(blockLen, pw, depth), CFrame = at * CF(math.cos(a) * rr, legH + math.sin(a) * rr, 0) * ANG(0, 0, a - math.pi / 2),
				Color = i % 2 == 0 and STONE or STONE2, Material = Enum.Material.Limestone, CanCollide = true, Parent = model })
		end
	end
	if ruined then
		for k = 1, 3 do
			part({ Name = "Rubble", Size = V(pw, pw * 0.8, depth * 0.7) * rng:NextNumber(0.5, 0.9), CFrame = at * CF(rng:NextNumber(-width, width), 0.8, rng:NextNumber(-depth * 2, depth * 2)) * ANG(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5)),
				Color = STONE2, Material = Enum.Material.Limestone, CanCollide = true, Parent = model })
		end
	end
	return model
end

-- Escada reta de pedra: degraus a partir de `at` subindo na direção -Z (LookVector).
function CrystalKit.stairs(parent: Instance, at: CFrame, steps: number, width: number, rise: number, run: number)
	local model = Make("Model", { Name = "Stairs", Parent = parent })
	for i = 1, steps do
		local h = rise * i
		part({ Name = "Step", Size = V(width, h, run), CFrame = at * CF(0, h / 2, -run * (i - 0.5)), Color = i % 2 == 0 and STONE or STONE2, Material = Enum.Material.Slate,
			CanCollide = true, Parent = model })
	end
	return model
end

-- Ponte de pedra em arco, caminhável, com parapeitos. De `a` até `b` (pontos do tabuleiro).
function CrystalKit.stoneBridge(parent: Instance, a: Vector3, b: Vector3, width: number, rng: Random)
	local model = Make("Model", { Name = "StoneBridge", Parent = parent })
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local right = dir:Cross(V(0, 1, 0)).Unit
	local segs = math.max(4, math.floor(len / 5))
	for i = 0, segs - 1 do
		local t0, t1 = i / segs, (i + 1) / segs
		local function at(t)
			return a:Lerp(b, t) + V(0, math.sin(t * math.pi) * len * 0.08, 0)
		end
		local p0, p1 = at(t0), at(t1)
		local mid = (p0 + p1) / 2
		part({ Name = "Deck", Size = V(width, 1.2, (p1 - p0).Magnitude + 0.2), CFrame = CF(mid, mid + (p1 - p0)), Color = i % 2 == 0 and STONE or STONE2,
			Material = Enum.Material.Cobblestone, CanCollide = true, Parent = model })
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "Parapet", Size = V(0.9, 1.6, (p1 - p0).Magnitude + 0.2), CFrame = CF(mid + right * side * (width / 2 - 0.45) + V(0, 1.4, 0), mid + right * side * (width / 2 - 0.45) + V(0, 1.4, 0) + (p1 - p0)),
				Color = STONE2, Material = Enum.Material.Limestone, CanCollide = true, Parent = model })
		end
	end
	-- pilares de sustentação nos terços (descem até a água/fundo)
	for _, t in ipairs({ 0.33, 0.67 }) do
		local p = a:Lerp(b, t) + V(0, math.sin(t * math.pi) * len * 0.08, 0)
		part({ Name = "BridgePier", Size = V(width * 0.8, 14, 3), CFrame = CF(p - V(0, 7.6, 0), p - V(0, 7.6, 0) + dir), Color = STONE_DARK, Material = Enum.Material.Slate, CanCollide = true, Parent = model })
	end
	-- cristais nas cabeceiras
	for _, p in ipairs({ a, b }) do
		for _, side in ipairs({ -1, 1 }) do
			CrystalKit.shard(model, CF(p + right * side * (width / 2 + 0.6)) * ANG(0, rng:NextNumber(0, 6), rad(side * 8)), 4.5, 1.1, side < 0 and "blue" or "violet", true)
		end
	end
	return model
end

-- Ponte suspensa de tábuas e cordas entre duas plataformas (a e b no nível do tabuleiro).
function CrystalKit.ropeBridge(parent: Instance, a: Vector3, b: Vector3, width: number)
	local model = Make("Model", { Name = "RopeBridge", Parent = parent })
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local right = dir:Cross(V(0, 1, 0)).Unit
	local planks = math.floor(len / 1.6)
	local sag = len * 0.06
	local function deck(t)
		return a:Lerp(b, t) - V(0, math.sin(t * math.pi) * sag, 0)
	end
	for i = 0, planks - 1 do
		local t = (i + 0.5) / planks
		local p = deck(t)
		part({ Name = "Plank", Size = V(width, 0.35, 1.35), CFrame = CF(p, p + dir) * ANG(0, 0, rad((i % 3 - 1) * 2)), Color = rgb(122, 88, 58):Lerp(rgb(90, 64, 42), (i % 4) / 4),
			Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = model })
	end
	-- cordas (segmentos) e postes
	for _, side in ipairs({ -1, 1 }) do
		local prev = deck(0) + right * side * width / 2 + V(0, 2.6, 0)
		for k = 1, 10 do
			local t = k / 10
			local cur = deck(t) + right * side * width / 2 + V(0, 2.6 + math.sin(t * math.pi) * sag * 0.4, 0)
			part({ Name = "Rope", Size = V(0.18, 0.18, (cur - prev).Magnitude + 0.1), CFrame = CF((prev + cur) / 2, cur), Color = rgb(170, 140, 96), Material = Enum.Material.Fabric,
				CastShadow = false, CanCollide = true, Parent = model })
			prev = cur
		end
		for _, p in ipairs({ a, b }) do
			part({ Name = "Post", Size = V(0.8, 4.4, 0.8), CFrame = CF(p + right * side * (width / 2 + 0.2) + V(0, 1.6, 0)), Color = rgb(96, 70, 48), Material = Enum.Material.Wood, CanCollide = true, Parent = model })
		end
	end
	return model
end

-- Estandarte de tecido roxo com emblema de cristal pendurado numa haste.
function CrystalKit.banner(parent: Instance, at: CFrame, h: number)
	part({ Name = "BannerRod", Size = V(4.2, 0.3, 0.3), CFrame = at * CF(0, h, 0), Color = GOLD, Material = Enum.Material.Metal, Parent = parent })
	part({ Name = "Banner", Size = V(3.4, h * 0.9, 0.12), CFrame = at * CF(0, h * 0.55, 0), Color = rgb(70, 40, 150), Material = Enum.Material.Fabric, CastShadow = false, Parent = parent })
	wedge({ Name = "BannerTail", Size = V(0.12, 1.4, 1.7), CFrame = at * CF(0, h * 0.1 - 0.6, 0) * ANG(0, rad(90), rad(180)), Color = rgb(70, 40, 150), Material = Enum.Material.Fabric, Parent = parent })
	part({ Name = "BannerEmblem", Size = V(1.1, 1.1, 0.14), CFrame = at * CF(0, h * 0.62, -0.02) * ANG(0, 0, rad(45)), Color = rgb(170, 220, 255), Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
end

-- Lanterna de ferro num poste de madeira, com chama de partículas e luz quente.
function CrystalKit.lantern(parent: Instance, pos: Vector3, fire)
	local model = Make("Model", { Name = "Lantern", Parent = parent })
	part({ Name = "Post", Size = V(0.7, 7, 0.7), CFrame = CF(pos + V(0, 3.5, 0)), Color = rgb(90, 64, 44), Material = Enum.Material.Wood, CanCollide = true, Parent = model })
	part({ Name = "Arm", Size = V(2.4, 0.4, 0.4), CFrame = CF(pos + V(1, 6.8, 0)), Color = rgb(90, 64, 44), Material = Enum.Material.Wood, Parent = model })
	part({ Name = "LampCage", Size = V(1.2, 1.5, 1.2), CFrame = CF(pos + V(1.9, 5.9, 0)), Color = rgb(40, 38, 44), Material = Enum.Material.Metal, Transparency = 0.55, Parent = model })
	local lamp = part({ Name = "LampFlame", Size = V(0.6, 0.8, 0.6), CFrame = CF(pos + V(1.9, 5.8, 0)), Color = rgb(255, 196, 110), Material = Enum.Material.Neon, CastShadow = false, Parent = model })
	if fire then
		fire(lamp, rgb(255, 170, 80), 0.25)
	end
	Make("PointLight", { Color = rgb(255, 190, 120), Range = 16, Brightness = 1.2, Shadows = false, Parent = lamp })
	return model
end

-- Portal de região: anel de pedra com runas e vórtice de energia (ProximityPrompt para viajar).
function CrystalKit.gate(parent: Instance, at: CFrame, color: Color3, label: string)
	local model = Make("Model", { Name = "RegionGate", Parent = parent })
	part({ Name = "GateBase", Size = V(16, 1.2, 7), CFrame = at * CF(0, 0.6, 0), Color = STONE2, Material = Enum.Material.Slate, CanCollide = true, Parent = model })
	CrystalKit.stairs(model, at * CF(0, 0, -3.5) * ANG(0, math.pi, 0), 1, 10, 0.6, 2)
	local n = 14
	local R = 6
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		part({ Name = "RingStone", Size = V(2.9, 1.8, 2.2), CFrame = at * CF(math.cos(a) * R, 7.4 + math.sin(a) * R, 0) * ANG(0, 0, a + math.pi / 2),
			Color = i % 2 == 0 and STONE or STONE2, Material = Enum.Material.Limestone, CanCollide = true, Parent = model })
		if i % 2 == 0 then
			part({ Name = "Rune", Size = V(0.8, 0.8, 0.12), CFrame = at * CF(math.cos(a) * R, 7.4 + math.sin(a) * R, -1.15) * ANG(0, 0, a), Color = color, Material = Enum.Material.Neon,
				CastShadow = false, Parent = model })
		end
	end
	-- vórtice: disco translúcido + partículas girando para dentro
	local vortex = part({ Name = "Vortex", Shape = Enum.PartType.Cylinder, Size = V(0.3, R * 1.75, R * 1.75), CFrame = at * CF(0, 7.4, 0) * ANG(0, rad(90), 0),
		Color = color, Material = Enum.Material.ForceField, Transparency = 0.2, CastShadow = false, Parent = model })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(rgb(255, 255, 255), color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Rate = 14
	e.Speed = NumberRange.new(-3, -1)
	e.SpreadAngle = Vector2.new(180, 180)
	e.RotSpeed = NumberRange.new(120, 200)
	e.Parent = vortex
	Make("PointLight", { Color = color, Range = 18, Brightness = 1.2, Shadows = false, Parent = vortex })
	-- placa com o nome
	local sign = part({ Name = "GateSign", Size = V(9, 1.4, 0.4), CFrame = at * CF(0, 14.6, 0), Color = STONE_DARK, Material = Enum.Material.Slate, Parent = model })
	local gui = Make("SurfaceGui", { Face = Enum.NormalId.Front, CanvasSize = Vector2.new(400, 60), LightInfluence = 0, Parent = sign })
	Make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = label, TextScaled = true, Font = Enum.Font.FredokaOne, TextColor3 = rgb(220, 236, 255),
		TextStrokeTransparency = 0.4, Parent = gui })
	local gui2 = Make("SurfaceGui", { Face = Enum.NormalId.Back, CanvasSize = Vector2.new(400, 60), LightInfluence = 0, Parent = sign })
	Make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = label, TextScaled = true, Font = Enum.Font.FredokaOne, TextColor3 = rgb(220, 236, 255),
		TextStrokeTransparency = 0.4, Parent = gui2 })
	model.PrimaryPart = vortex
	return model, vortex
end

-- Baú-santuário (recompensa fixa com recarga por jogador; o servidor valida tudo).
function CrystalKit.chest(parent: Instance, at: CFrame, title: string)
	local model = Make("Model", { Name = "ShrineChest", Parent = parent })
	local box = part({ Name = "ChestBox", Size = V(4, 2.4, 2.8), CFrame = at * CF(0, 1.2, 0), Color = rgb(70, 52, 110), Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = model })
	part({ Name = "ChestLid", Size = V(4.1, 1, 2.9), CFrame = at * CF(0, 2.9, 0), Color = rgb(84, 62, 130), Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = model })
	for _, x in ipairs({ -1.5, 1.5 }) do
		part({ Name = "ChestBand", Size = V(0.4, 3.5, 3), CFrame = at * CF(x, 1.75, 0), Color = GOLD, Material = Enum.Material.Metal, Parent = model })
	end
	part({ Name = "ChestLock", Size = V(0.8, 0.9, 0.3), CFrame = at * CF(0, 2.3, -1.5), Color = GOLD, Material = Enum.Material.Metal, Parent = model })
	CrystalKit.shard(model, at * CF(0, 3.4, 0) * ANG(0, rad(30), 0), 2.2, 0.6, "blue", true)
	part({ Name = "ChestDais", Size = V(6.5, 0.6, 5), CFrame = at * CF(0, 0.3 - 0.6, 0), Color = STONE, Material = Enum.Material.Slate, CanCollide = true, Parent = model })
	local prompt = Make("ProximityPrompt", { ActionText = "Abrir", ObjectText = title, HoldDuration = 0.6, MaxActivationDistance = 12, RequiresLineOfSight = false, Parent = box })
	model.PrimaryPart = box
	return model, prompt
end

-- NPC: figura encapuzada feita de peças (manto, capuz, rosto, cajado com cristal) + nome.
function CrystalKit.npc(parent: Instance, at: CFrame, name: string, robe: Color3, crystalStyle: string)
	local model = Make("Model", { Name = "NPC_" .. name, Parent = parent })
	local robeDark = robe:Lerp(rgb(0, 0, 0), 0.35)
	local body = part({ Name = "Robe", Size = V(3, 4.6, 2.2), CFrame = at * CF(0, 2.3, 0), Color = robe, Material = Enum.Material.Fabric, CanCollide = true, Parent = model })
	wedge({ Name = "RobeHem", Size = V(3.4, 1.4, 1.4), CFrame = at * CF(0, 0.7, -1.2) * ANG(0, math.pi, 0), Color = robeDark, Material = Enum.Material.Fabric, Parent = model })
	wedge({ Name = "RobeHem", Size = V(3.4, 1.4, 1.4), CFrame = at * CF(0, 0.7, 1.2), Color = robeDark, Material = Enum.Material.Fabric, Parent = model })
	part({ Name = "Sash", Size = V(3.1, 0.5, 2.3), CFrame = at * CF(0, 3, 0), Color = GOLD, Material = Enum.Material.Fabric, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Sleeve", Size = V(0.9, 2.6, 1), CFrame = at * CF(side * 1.9, 3.3, -0.2) * ANG(rad(-20), 0, rad(side * 8)), Color = robe, Material = Enum.Material.Fabric, Parent = model })
	end
	local head = part({ Name = "Head", Size = V(1.5, 1.5, 1.4), CFrame = at * CF(0, 5.4, -0.1), Color = rgb(222, 186, 160), Material = Enum.Material.SmoothPlastic, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Eye", Size = V(0.18, 0.26, 0.05), CFrame = at * CF(side * 0.3, 5.5, -0.82), Color = rgb(40, 60, 110), CastShadow = false, Parent = model })
	end
	part({ Name = "Beard", Size = V(1.1, 0.9, 0.3), CFrame = at * CF(0, 4.9, -0.75), Color = rgb(230, 230, 236), Material = Enum.Material.Fabric, Parent = model })
	wedge({ Name = "Hood", Size = V(2, 1.6, 2), CFrame = at * CF(0, 6.3, 0.1), Color = robeDark, Material = Enum.Material.Fabric, Parent = model })
	part({ Name = "HoodBack", Size = V(2, 1.8, 0.6), CFrame = at * CF(0, 5.6, 0.75), Color = robeDark, Material = Enum.Material.Fabric, Parent = model })
	part({ Name = "Staff", Size = V(0.35, 7, 0.35), CFrame = at * CF(2.3, 3.4, -0.4), Color = rgb(96, 70, 48), Material = Enum.Material.Wood, CanCollide = true, Parent = model })
	CrystalKit.shard(model, at * CF(2.3, 6.8, -0.4), 1.8, 0.6, crystalStyle, true)
	local gui = Make("BillboardGui", { Size = UDim2.fromOffset(200, 40), StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0), MaxDistance = 70, AlwaysOnTop = false, Adornee = head, Parent = model })
	Make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = name, TextScaled = true, Font = Enum.Font.FredokaOne, TextColor3 = rgb(255, 230, 150),
		TextStrokeTransparency = 0.3, Parent = gui })
	local prompt = Make("ProximityPrompt", { ActionText = "Conversar", ObjectText = name, MaxActivationDistance = 12, RequiresLineOfSight = false, Parent = body })
	model.PrimaryPart = body
	return model, prompt
end

return CrystalKit

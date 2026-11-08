-- GREAT SANCTUARY TREE — a Árvore-Santuário no centro do Verdant Haven (Mundo 1).
--
-- Escala: ~300 studs de altura, copa de ~240 studs de diâmetro: visível de qualquer ponto da ilha.
-- O tronco fica SUSPENSO sobre 6 raízes em arco (tipo figueira), então a praça, as estações de ovo e os
-- portais continuam embaixo dela, num "santuário" coberto pelas raízes.
--
-- Andares (alturas acima do chão):
--   0      Praça das Raízes, poças de seiva, coluna do Elevador de Seiva
--   ~49    Coração da Raiz: deck em volta do tronco (chega-se pela Escadaria da Raiz ou pelo elevador)
--   49-206 rampa em espiral pela casca; 4 GALHOS SUSPENSOS saem dela como estradas até ninhos com baús
--   ~207   Copas Celestiais: deck dentro da copa + terraços de folhas para subir pulando
--   ~302   Coroa Estelar: mirante no topo (elevador liberado depois de vencer o Elderroot)
--
-- Superfícies orgânicas (tronco, raízes, galhos) são malhas do MeshKit convertidas em cunhas ancoradas
-- (Builders/Facets): funciona sem EditableMesh. Copa no estilo "galhos e cubos" do Mundo 1 (BlockTree).
-- Runas (atributo RuneRing) pulsam no cliente (SanctuaryClient).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Make = require(Shared.Util.Make)
local MeshKit = require(Shared.Builders.MeshKit)
local Facets = require(Shared.Builders.Facets)

local SanctuaryTree = {}

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad
local rgb = Color3.fromRGB
local M = Enum.Material
local FWD = V(0, 0, -1)

local BARK, BARK_DARK, BARK_LIGHT = rgb(88, 54, 34), rgb(54, 32, 22), rgb(112, 74, 46)
local MOSS, MOSS_LIGHT = rgb(64, 128, 50), rgb(96, 160, 64)
local LEAF = { rgb(46, 158, 50), rgb(36, 138, 42), rgb(60, 176, 60), rgb(30, 120, 38), rgb(52, 166, 54) }
local LEAF_DARK = rgb(24, 100, 32)
local PLANK, PLANK_DARK = rgb(150, 106, 66), rgb(112, 78, 48)
local SAP, RUNE, SPORE = rgb(255, 196, 80), rgb(120, 255, 140), rgb(255, 232, 130)

-- Medidas (exportadas para testes e para o serviço do elevador)
SanctuaryTree.HUB_Y = 49 -- deck do Coração da Raiz
SanctuaryTree.RAMP_TOP = 206
SanctuaryTree.CANOPY_Y = 207 -- deck das Copas Celestiais
SanctuaryTree.CROWN_Y = 302 -- Coroa Estelar
SanctuaryTree.RAMP_RISE, SanctuaryTree.RAMP_STEP = 1.4, 12 -- subida (studs) e giro (graus) por tábua
SanctuaryTree.BRANCH_Y = { 86, 114, 142, 170 } -- galhos-estrada (altura da junção com a rampa)
SanctuaryTree.BRANCH_LEN = { 104, 92, 112, 96 }
-- raízes em arco (θ em graus): evitam portais (262°/278°), ovos (200°/340°), campos de recurso e a arena
SanctuaryTree.ROOTS = { 25, 75, 120, 165, 225, 310 }
SanctuaryTree.STAIR_ROOT = 225 -- a raiz com a escadaria (pousa mais longe: subida suave)
SanctuaryTree.LIFT_THETA = 142

local function solid(c: Color3)
	return function()
		return c
	end
end

local function polar(c: Vector3, thetaDeg: number, r: number, y: number): Vector3
	local a = rad(thetaDeg)
	return c + V(math.cos(a) * r, y, math.sin(a) * r)
end

-- raio do tronco em cada altura (o mesmo perfil do loft)
local TRUNK = { { 34, 16 }, { 46, 28 }, { 62, 25.5 }, { 100, 22.5 }, { 140, 20 }, { 180, 17.5 }, { 210, 15 }, { 245, 10.5 }, { 285, 4.5 } }
function SanctuaryTree.trunkRadius(y: number): number
	if y <= TRUNK[1][1] then
		return TRUNK[1][2]
	end
	for i = 1, #TRUNK - 1 do
		local a, b = TRUNK[i], TRUNK[i + 1]
		if y <= b[1] then
			local f = (y - a[1]) / (b[1] - a[1])
			f = f * f * (3 - 2 * f)
			return a[2] + (b[2] - a[2]) * f
		end
	end
	return TRUNK[#TRUNK][2]
end
local trunkR = SanctuaryTree.trunkRadius

-- relevo da casca: sulcos verticais (ruído esticado no eixo Y) + caroços grandes
local BARK_AMP = 1.6
local function barkNoise(p: Vector3): number
	return math.abs(math.noise(p.X * 0.16 + 2.1, p.Y * 0.035, p.Z * 0.16 + 4.7)) * 1.3 - 0.35 + math.noise(p.X * 0.05 + 0.3, p.Y * 0.05, p.Z * 0.05) * 0.5
end

local function displaceBark(g, amp: number)
	local nrm = MeshKit.normals(g)
	local out = table.create(#g.verts)
	for i, v in ipairs(g.verts) do
		out[i] = v + nrm[i] * (barkNoise(v) * amp)
	end
	return { verts = out, colors = g.colors, tris = g.tris, flat = g.flat }, nrm
end

local function barkShade(g)
	local nrm = MeshKit.normals(g)
	local cols = table.create(#g.verts)
	for i, p in ipairs(g.verts) do
		local n = nrm[i]
		local gv = math.noise(p.X * 0.2 + 0.31, p.Y * 0.05, p.Z * 0.2 + 0.17)
		local c = BARK:Lerp(BARK_DARK, math.clamp((gv - 0.02) * 3, 0, 0.8))
		c = c:Lerp(BARK_LIGHT, math.clamp(-gv * 2 - 0.3, 0, 0.6))
		local m = math.noise(p.X * 0.06 + 7.3, p.Y * 0.06, p.Z * 0.06 + 1.1)
		if n.Y > 0.25 and m > -0.25 then
			c = c:Lerp(m > 0.15 and MOSS_LIGHT or MOSS, math.clamp((n.Y - 0.25) * 2.4, 0, 1))
		end
		cols[i] = c
	end
	return { verts = g.verts, colors = cols, tris = g.tris, flat = g.flat }
end

local function tube(pts, r0: number, r1: number, seg: number, up: Vector3?)
	local keys = {}
	for i, p in ipairs(pts) do
		local f = (i - 1) / math.max(1, #pts - 1)
		keys[i] = { p = p, w = r0 + (r1 - r0) * f }
	end
	return MeshKit.loft(keys, { seg = seg, steps = 1, up = up, capStart = 0, capEnd = r1 * 0.9, capRings = 0, color = solid(BARK) })
end

local function part(parent: Instance, props)
	props.Anchored = true
	props.TopSurface = props.TopSurface or Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	if props.CanCollide == nil then
		props.CanCollide = false
	end
	props.CanQuery = props.CanCollide
	props.CanTouch = false
	props.Parent = parent
	return Make("Part", props)
end

local function ball(parent: Instance, props)
	props.Shape = Enum.PartType.Ball
	return part(parent, props)
end

-- Tábua entre dois pontos (eixo Z ao longo da tábua; a tábua inclina com a subida).
local function plank(parent: Instance, a: Vector3, b: Vector3, width: number, color: Color3, name: string?)
	local mid = (a + b) / 2
	return part(parent, { Name = name or "Plank", Size = V(width, 0.9, (b - a).Magnitude + 0.9), CFrame = CF(mid, b) * CF(0, -0.45, 0), Color = color,
		Material = M.WoodPlanks, CanCollide = true })
end

local function emitter(parent: Instance, pos: Vector3, size: Vector3, cfg)
	local anchor = part(parent, { Name = cfg.name or "Particles", Size = size, CFrame = CF(pos), Transparency = 1, CastShadow = false })
	local e = Instance.new("ParticleEmitter")
	e.Name = cfg.name or "Particles"
	e.Texture = cfg.tex or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(cfg.color)
	e.LightEmission = cfg.emission or 0.8
	e.LightInfluence = 0
	e.Rate = cfg.rate
	e.Lifetime = NumberRange.new(cfg.life * 0.7, cfg.life)
	e.Speed = NumberRange.new(cfg.speed * 0.4, cfg.speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = cfg.accel or Vector3.zero
	e.Drag = cfg.drag or 0.6
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.15, cfg.size), NumberSequenceKeypoint.new(0.85, cfg.size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = anchor
	return anchor
end

-- Ângulo (graus) da rampa em espiral numa altura.
function SanctuaryTree.rampTheta(y: number): number
	return SanctuaryTree.LIFT_THETA + 26 + (y - SanctuaryTree.HUB_Y) / SanctuaryTree.RAMP_RISE * SanctuaryTree.RAMP_STEP
end

--[[ Constrói a árvore. Devolve:
	{ model, facets, parts, stops = { [id] = { id, label, part, arrival: CFrame, order, requiresBoss? } },
	  chests = { [id] = { model, prompt, pos, title } }, ramp = { pontos }, stairs = { pontos }, runes = n } ]]
function SanctuaryTree.build(parent: Instance, center: Vector3, makeChest)
	local c = center
	local model = Make("Model", { Name = "SanctuaryTree", Parent = parent })
	local bark = Make("Folder", { Name = "Bark", Parent = model })
	local deco = Make("Folder", { Name = "Detail", Parent = model })
	local walk = Make("Folder", { Name = "Walkways", Parent = model })
	local canopy = Make("Folder", { Name = "Canopy", Parent = model })
	local runes = Make("Folder", { Name = "Runes", Parent = model })
	local out = { model = model, facets = 0, stops = {}, chests = {}, ramp = {}, stairs = {}, runes = 0, branchEnds = {} }
	local rng = Random.new(31337)
	local function facets(g, collide: boolean, material, name: string?)
		out.facets += Facets.build(g, 0.8, { material = material or M.Wood, anchored = true, collide = collide, shadow = true, name = name or "Bark" }, bark)
	end

	-- TRONCO (suspenso sobre as raízes, com leve curva)
	local keys = {}
	for i, k in ipairs(TRUNK) do
		keys[i] = { p = c + V(0, k[1], 0), w = k[2], h = k[2] }
	end
	local trunk = MeshKit.loft(keys, { seg = 16, steps = 2, up = FWD, capStart = 7, capEnd = 3, capRings = 1, color = solid(BARK) })
	trunk = barkShade((displaceBark(trunk, BARK_AMP)))
	facets(trunk, true, M.Wood, "Trunk")

	-- RAÍZES EM ARCO: saem do tronco e pousam no chão em volta da praça
	for _, th in ipairs(SanctuaryTree.ROOTS) do
		local pts
		if th == SanctuaryTree.STAIR_ROOT then
			-- raiz longa e mais deitada: a escadaria sobe por cima dela
			-- o eixo fica abaixo dos degraus o suficiente para o topo da raiz não cobrir a escada
			local path = { { 94, -3 }, { 88, 0 }, { 76, 9 }, { 61, 22 }, { 46, 35.5 }, { 34, 44.5 }, { 20, 47 } }
			pts = {}
			for i, q in ipairs(path) do
				local r = 3.8 + (7.5 - 3.8) * (i - 1) / (#path - 1)
				pts[i] = polar(c, th, q[1], i == 1 and q[2] or q[2] - r - 1.3)
			end
		else
			pts = { polar(c, th, 72, -3), polar(c, th, 66, -0.5), polar(c, th, 60, 10), polar(c, th, 50, 27), polar(c, th, 34, 43), polar(c, th, 17, 47) }
		end
		-- a curva vai do chão para o tronco: o raio cresce para dentro
		local rev = {}
		for i = #pts, 1, -1 do
			table.insert(rev, pts[i])
		end
		local g = tube(rev, 7.5, 3.8, 9)
		facets(barkShade((displaceBark(g, 0.9))), true, M.Wood, "Root")
		-- poça de seiva brilhante onde a raiz encontra o chão
		local pool = polar(c, th, (pts[2] - c).Magnitude + 4, 0.25)
		part(deco, { Name = "SapPool", Shape = Enum.PartType.Cylinder, Size = V(0.4, 7, 7), CFrame = CF(pool) * CFrame.Angles(0, 0, rad(90)), Color = SAP, Material = M.Neon,
			Transparency = 0.15, CastShadow = false })
	end

	-- ESCADARIA DA RAIZ (do chão até o Coração da Raiz)
	do
		local path = { { 88, 0 }, { 76, 9 }, { 61, 22 }, { 46, 35.5 }, { 35, 44.5 }, { 33, SanctuaryTree.HUB_Y } }
		local function at(h: number): Vector3
			for i = 1, #path - 1 do
				local a, b = path[i], path[i + 1]
				if h <= b[2] then
					local f = (h - a[2]) / (b[2] - a[2])
					return polar(c, SanctuaryTree.STAIR_ROOT, a[1] + (b[1] - a[1]) * f, h)
				end
			end
			return polar(c, SanctuaryTree.STAIR_ROOT, path[#path][1], path[#path][2])
		end
		local n = math.ceil(SanctuaryTree.HUB_Y / 1.25)
		local prev = at(0)
		for i = 1, n do
			local h = SanctuaryTree.HUB_Y * i / n
			local q = at(h)
			local run = (q - prev) * V(1, 0, 1)
			local dir = run.Magnitude > 1e-3 and run.Unit or (c - q) * V(1, 0, 1)
			local mid = q
			part(walk, { Name = "StairStep", Size = V(6, 0.8, run.Magnitude + 1.4), CFrame = CF(mid - V(0, 0.4, 0), mid - V(0, 0.4, 0) + dir) * CF(0, 0, run.Magnitude / 2),
				Color = i % 2 == 0 and PLANK or PLANK_DARK, Material = M.WoodPlanks, CanCollide = true })
			table.insert(out.stairs, q)
			if i % 5 == 0 then
				local side = dir:Cross(V(0, 1, 0)).Unit
				local lp = q + side * 3.4 + V(0, 2.5, 0)
				part(walk, { Name = "StairPost", Size = V(0.5, 5, 0.5), CFrame = CF(lp - V(0, 0.2, 0)), Color = PLANK_DARK, Material = M.Wood })
				local l = ball(walk, { Name = "SporeLamp", Size = Vector3.one * 1.1, CFrame = CF(lp + V(0, 2.6, 0)), Color = SPORE, Material = M.Neon, CastShadow = false })
				if i % 20 == 0 then
					Make("PointLight", { Color = SPORE, Range = 12, Brightness = 0.8, Shadows = false, Parent = l })
				end
			end
			prev = q
		end
	end

	-- CORAÇÃO DA RAIZ: deck em anel em volta do tronco
	local hubY = SanctuaryTree.HUB_Y
	do
		local r0 = trunkR(hubY) - 1.5
		local r1 = r0 + 11
		local n = 18
		for i = 0, n - 1 do
			local a0, a1 = i / n * 360, (i + 1) / n * 360
			local am = (a0 + a1) / 2
			local inner, outer = polar(c, am, r0, hubY), polar(c, am, r1, hubY)
			local width = 2 * math.pi * r1 / n + 1.2
			part(walk, { Name = "HubDeck", Size = V(width, 1, r1 - r0), CFrame = CF((inner + outer) / 2 - V(0, 0.5, 0), outer - V(0, 0.5, 0)), Color = i % 2 == 0 and PLANK or PLANK_DARK,
				Material = M.WoodPlanks, CanCollide = true })
			-- grade baixa na borda (com abertura na chegada da escadaria)
			if math.abs(((am - SanctuaryTree.STAIR_ROOT + 180) % 360) - 180) > 14 then
				part(walk, { Name = "HubRail", Size = V(width, 2.4, 0.5), CFrame = CF(polar(c, am, r1 - 0.3, hubY + 1.2), polar(c, am, r1 + 5, hubY + 1.2)), Color = PLANK_DARK, Material = M.Wood,
					CanCollide = true })
			end
		end
	end

	-- RAMPA EM ESPIRAL pela casca (do deck do coração até a copa)
	local function rampPoint(y: number): Vector3
		return polar(c, SanctuaryTree.rampTheta(y), trunkR(y) + 5.6, y)
	end
	do
		local y = hubY
		local prev = rampPoint(y)
		table.insert(out.ramp, prev)
		local i = 0
		while y < SanctuaryTree.RAMP_TOP do
			y = math.min(SanctuaryTree.RAMP_TOP, y + SanctuaryTree.RAMP_RISE)
			local q = rampPoint(y)
			i += 1
			plank(walk, prev, q, 8, i % 2 == 0 and PLANK or PLANK_DARK, "RampPlank")
			-- corrimão do lado de fora (aberto nas junções com os galhos-estrada)
			local outDir = ((prev + q) / 2 - c) * V(1, 0, 1)
			outDir = outDir.Unit
			local junction = false
			for _, by in ipairs(SanctuaryTree.BRANCH_Y) do
				if math.abs(y - by) < 4 then
					junction = true
				end
			end
			if not junction then
				local ra, rb = prev + outDir * 4.1 + V(0, 1.1, 0), q + outDir * 4.1 + V(0, 1.1, 0)
				part(walk, { Name = "RampRail", Size = V(0.45, 2.2, (rb - ra).Magnitude + 0.5), CFrame = CF((ra + rb) / 2, rb), Color = PLANK_DARK, Material = M.Wood, CanCollide = true })
			end
			if i % 9 == 0 then
				local lp = q + outDir * 4.1 + V(0, 3.4, 0)
				local l = ball(walk, { Name = "SporeLamp", Size = Vector3.one * 1.2, CFrame = CF(lp), Color = SPORE, Material = M.Neon, CastShadow = false })
				if i % 36 == 0 then
					Make("PointLight", { Color = SPORE, Range = 16, Brightness = 0.9, Shadows = false, Parent = l })
				end
			end
			table.insert(out.ramp, q)
			prev = q
		end
		-- patamar no topo: liga o fim da rampa ao deck da copa (passando por cima da abertura)
		local landing = polar(c, SanctuaryTree.rampTheta(SanctuaryTree.RAMP_TOP) + 16, trunkR(SanctuaryTree.CANOPY_Y) + 5.6, SanctuaryTree.CANOPY_Y)
		plank(walk, prev, landing, 8, PLANK, "RampLanding")
		table.insert(out.ramp, landing)
	end

	-- GALHOS SUSPENSOS: saem da rampa (junção na mesma altura) até ninhos com baús
	for bi, by in ipairs(SanctuaryTree.BRANCH_Y) do
		local th = SanctuaryTree.rampTheta(by)
		local len = SanctuaryTree.BRANCH_LEN[bi]
		local rs = trunkR(by)
		local radiusAt = function(f)
			return 5.2 + (2.6 - 5.2) * f
		end
		local rise = 9
		local function topAt(f: number): Vector3
			local r = (rs - 4) + (len - (rs - 4)) * f
			return polar(c, th + math.sin(f * 3) * 4, r, by + rise * f * f)
		end
		local axis = {}
		for k = 0, 4 do
			local f = k / 4
			axis[k + 1] = topAt(f) - V(0, radiusAt(f) + 0.5, 0)
		end
		local g = tube(axis, 5.2, 2.6, 8)
		facets(barkShade((displaceBark(g, 0.6))), false, M.Wood, "Branch")
		-- estrada de tábuas por cima do galho, com corda dos dois lados
		local f0 = (rs + 9 - (rs - 4)) / (len - (rs - 4))
		local nSeg = 16
		local prevT = topAt(f0)
		for k = 1, nSeg do
			local f = f0 + (0.94 - f0) * k / nSeg
			local q = topAt(f)
			plank(walk, prevT, q, 5.5, k % 2 == 0 and PLANK or PLANK_DARK, "BranchPlank")
			local dir = (q - prevT).Unit
			local side = dir:Cross(V(0, 1, 0)).Unit
			for _, s in ipairs({ -1, 1 }) do
				local ra, rb = prevT + side * s * 2.9 + V(0, 1.2, 0), q + side * s * 2.9 + V(0, 1.2, 0)
				part(walk, { Name = "BranchRope", Size = V(0.3, 2.2, (rb - ra).Magnitude + 0.3), CFrame = CF((ra + rb) / 2, rb), Color = rgb(170, 140, 90), Material = M.Fabric,
					CanCollide = true, CastShadow = false })
			end
			prevT = q
		end
		-- ninho na ponta: deck redondo, borda de gravetos, lanterna e baú
		local nest = topAt(0.97)
		for k = 0, 7 do
			local a = k / 8 * 360
			local p1 = nest + V(math.cos(rad(a)) * 5, 0, math.sin(rad(a)) * 5)
			part(walk, { Name = "NestDeck", Size = V(7.5, 1, 6.5), CFrame = CF(p1 - V(0, 0.5, 0), nest - V(0, 0.5, 0)), Color = PLANK, Material = M.WoodPlanks, CanCollide = true })
		end
		part(walk, { Name = "NestDeck", Size = V(7, 1, 7), CFrame = CF(nest - V(0, 0.5, 0)), Color = PLANK_DARK, Material = M.WoodPlanks, CanCollide = true })
		local inward = ((c - nest) * V(1, 0, 1)).Unit
		for k = 0, 13 do
			local a = rad(k / 14 * 360)
			local q = nest + V(math.cos(a) * 9.6, 0.7, math.sin(a) * 9.6)
			if V(math.cos(a), 0, math.sin(a)):Dot(inward) > 0.82 then
				continue -- entrada do ninho (vindo da estrada)
			end
			part(deco, { Name = "NestTwig", Size = V(0.9, 1.4, 5), CFrame = CF(q, q + V(-math.sin(a), 0.1, math.cos(a))), Color = k % 2 == 0 and BARK or BARK_LIGHT, Material = M.Wood,
				CanCollide = true })
		end
		local lamp = ball(deco, { Name = "NestLamp", Size = Vector3.one * 1.6, CFrame = CF(nest + V(4, 5, 4)), Color = SPORE, Material = M.Neon, CastShadow = false })
		Make("PointLight", { Color = SPORE, Range = 20, Brightness = 1, Shadows = false, Parent = lamp })
		part(deco, { Name = "LampVine", Size = V(0.25, 4, 0.25), CFrame = CF(nest + V(4, 7.6, 4)), Color = rgb(70, 110, 50), Material = M.Grass })
		-- cacho de folhas por cima do ninho (sombra e cor)
		local crng = Random.new(900 + bi)
		for k = 1, 5 do
			local a = k / 5 * math.pi * 2
			local sz = V(crng:NextNumber(9, 14), crng:NextNumber(4, 6), crng:NextNumber(9, 14))
			part(canopy, { Name = "NestLeaves", Size = sz, CFrame = CF(nest + V(math.cos(a) * 7, 14 + crng:NextNumber(-1, 2), math.sin(a) * 7)) * CFrame.Angles(0, crng:NextNumber(0, 1.5), 0),
				Color = LEAF[crng:NextInteger(1, #LEAF)], Material = M.SmoothPlastic, CastShadow = k % 2 == 0 })
		end
		if makeChest then
			local outward = ((nest - c) * V(1, 0, 1)).Unit
			local chestCf = CF(nest - outward * 2.5, nest - outward * 2.5 - outward)
			local title = ({ "Ninho do Galho Dourado", "Ninho dos Esporos", "Ninho do Vento Alto", "Ninho da Seiva Antiga" })[bi]
			local m, prompt = makeChest(deco, chestCf, title)
			out.chests["sanct_nest" .. bi] = { model = m, prompt = prompt, pos = chestCf.Position, title = title }
		end
		table.insert(out.branchEnds, nest)
	end

	-- GALHOS ALTOS (sustentam a copa; sem estrada)
	local upperEnds = {}
	for k = 1, 7 do
		local th = k / 7 * 360 + 20
		local y0 = 196 + (k % 3) * 8
		local len = 70 + (k % 4) * 12
		local p0 = polar(c, th, trunkR(y0) - 4, y0)
		local p1 = polar(c, th + 6, len * 0.55, y0 + 18)
		local p2 = polar(c, th + 10, len, y0 + 26)
		facets(barkShade(tube({ p0, p1, p2 }, 4.4, 1.6, 7)), false, M.Wood, "UpperBranch")
		table.insert(upperEnds, p2)
	end

	-- RUNAS ANTIGAS esculpidas no tronco (6 anéis; pulsam de baixo para cima no cliente)
	local GLYPHS = {
		{ { 0, 0, 0, 3.2 }, { 0.9, 0.6, 45, 1.6 }, { -0.9, -0.6, 45, 1.6 } },
		{ { -0.7, 0, 0, 3 }, { 0.7, 0, 0, 3 }, { 0, 0.9, 90, 1.6 } },
		{ { 0, 0, 30, 3 }, { 0, 0, -30, 3 }, { 0, -1.2, 90, 1.4 } },
		{ { 0, 0.5, 0, 2 }, { -0.8, -0.6, 60, 1.8 }, { 0.8, -0.6, -60, 1.8 } },
	}
	local ringYs = { 58, 82, 108, 134, 160, 186 }
	for ri, ry in ipairs(ringYs) do
		local n = 10
		for k = 0, n - 1 do
			local th = k / n * 360 + ri * 17
			local dir = V(math.cos(rad(th)), 0, math.sin(rad(th)))
			local base = c + V(0, ry, 0) + dir * trunkR(ry)
			local push = barkNoise(base) * BARK_AMP + 0.45
			local origin = CF(base + dir * push, base + dir * (push + 1))
			for _, bar in ipairs(GLYPHS[(k + ri) % #GLYPHS + 1]) do
				local cf = origin * CF(bar[1], bar[2], 0) * CFrame.Angles(0, 0, rad(bar[3]))
				local p = part(runes, { Name = "Rune", Size = V(0.45, bar[4], 0.3), CFrame = cf, Color = RUNE, Material = M.Neon, CastShadow = false })
				p:SetAttribute("RuneRing", ri)
				out.runes += 1
			end
		end
	end

	-- SEIVA BRILHANTE escorrendo pelos sulcos do tronco
	for s = 1, 5 do
		local th = s / 5 * 360 + 40
		local y = 200
		local prev
		while y > 52 do
			local wob = math.sin(y * 0.11 + s) * 6
			local dir = V(math.cos(rad(th + wob)), 0, math.sin(rad(th + wob)))
			local base = c + V(0, y, 0) + dir * trunkR(y)
			local q = base + dir * (barkNoise(base) * BARK_AMP + 0.3)
			if prev then
				part(deco, { Name = "SapStream", Size = V(0.7, 0.35, (q - prev).Magnitude + 0.3), CFrame = CF((prev + q) / 2, q), Color = SAP, Material = M.Neon, CastShadow = false,
					Transparency = 0.1 })
			end
			prev = q
			y -= 9
		end
	end

	-- COPAS CELESTIAIS: deck dentro da copa (fim da rampa)
	local cy = SanctuaryTree.CANOPY_Y
	do
		local r0 = trunkR(cy) - 1.5
		local r1 = 44
		local n = 22
		-- abertura por onde a rampa sobe (sem ela, o fim da rampa passaria sob o deck sem altura para o jogador)
		local rampEnd = SanctuaryTree.rampTheta(SanctuaryTree.RAMP_TOP)
		for i = 0, n - 1 do
			local am = (i + 0.5) / n * 360
			local inner, outer = polar(c, am, r0, cy), polar(c, am, r1, cy)
			local behind = (rampEnd - am) % 360
			if behind < 68 and behind > -1 then
				continue
			end
			part(walk, { Name = "CanopyDeck", Size = V(2 * math.pi * r1 / n + 1.5, 1, r1 - r0), CFrame = CF((inner + outer) / 2 - V(0, 0.5, 0), outer - V(0, 0.5, 0)),
				Color = i % 2 == 0 and rgb(70, 150, 60) or rgb(60, 138, 54), Material = M.Grass, CanCollide = true })
		end
		for i = 0, n - 1 do
			local am = (i + 0.5) / n * 360
			part(walk, { Name = "CanopyRail", Size = V(2 * math.pi * r1 / n + 1.5, 2.4, 0.6), CFrame = CF(polar(c, am, r1, cy + 1.2), polar(c, am, r1 + 5, cy + 1.2)), Color = PLANK_DARK,
				Material = M.Wood, CanCollide = true })
		end
		-- flores de luz e cogumelos no deck
		for k = 1, 12 do
			local a = k / 12 * 360 + 7
			local p = polar(c, a, 30 + (k % 3) * 4, cy)
			part(deco, { Name = "LightStem", Size = V(0.4, 2.4, 0.4), CFrame = CF(p + V(0, 1.2, 0)), Color = rgb(60, 140, 60), Material = M.Grass })
			ball(deco, { Name = "LightFlower", Size = Vector3.one * 1.4, CFrame = CF(p + V(0, 2.8, 0)), Color = k % 2 == 0 and SPORE or rgb(180, 255, 200), Material = M.Neon, CastShadow = false })
		end
		if makeChest then
			local cp = polar(c, SanctuaryTree.LIFT_THETA + 180, 38, cy)
			local chestCf = CF(cp, c + V(0, cy, 0))
			local m, prompt = makeChest(deco, chestCf, "Baú das Copas Celestiais")
			out.chests.sanct_canopy = { model = m, prompt = prompt, pos = cp, title = "Baú das Copas Celestiais" }
		end
	end
	-- terraços de folhas em espiral: dá para subir pulando do deck até perto do topo
	for k = 1, 14 do
		local a = SanctuaryTree.LIFT_THETA + 200 + k * 31
		local y = cy + k * 4.6
		local r = trunkR(y) + 10 + (k % 2) * 3
		part(canopy, { Name = "LeafTerrace", Size = V(10, 2.4, 10), CFrame = CF(polar(c, a, r, y - 1.2)) * CFrame.Angles(0, rad(a), 0), Color = LEAF[(k % #LEAF) + 1],
			Material = M.Plastic, TopSurface = Enum.SurfaceType.Studs, CanCollide = true, CastShadow = false })
	end

	-- COPA: domo largo e irregular de blocos (estilo "galhos e cubos" do Mundo 1)
	local domeC = c + V(0, 248, 0)
	local RX, RY = 132, 48
	local nBlocks = 165
	for i = 1, nBlocks do
		-- espiral de Fibonacci sobre o domo (metade de cima e um pouco abaixo do equador)
		local f = (i - 0.5) / nBlocks
		local yN = 1 - f * 1.35
		local rN = math.sqrt(math.max(0, 1 - yN * yN))
		local a = i * 2.39996
		local jitter = 0.86 + rng:NextNumber(0, 0.22)
		local p = domeC + V(math.cos(a) * rN * RX * jitter, yN * RY * jitter, math.sin(a) * rN * RX * jitter)
		local big = 1 - math.abs(yN) * 0.35
		local sz = V(rng:NextNumber(18, 32) * big, rng:NextNumber(7, 13), rng:NextNumber(18, 30) * big)
		local studs = i % 9 == 0
		part(canopy, { Name = "LeafBlock", Size = sz, CFrame = CF(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = LEAF[rng:NextInteger(1, #LEAF)],
			Material = studs and M.Plastic or M.SmoothPlastic, TopSurface = studs and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth, CastShadow = i % 4 == 0 })
	end
	-- base escura da copa (sombra suave sobre o deck) e cachos pendentes presos por ramos
	for i = 1, 18 do
		local a = i / 18 * math.pi * 2
		local r = 58 + (i % 3) * 18
		local p = c + V(math.cos(a) * r, cy + 2 + (i % 2) * 3, math.sin(a) * r)
		part(canopy, { Name = "LeafUnder", Size = V(rng:NextNumber(22, 30), 6, rng:NextNumber(20, 28)), CFrame = CF(p) * CFrame.Angles(0, a, 0), Color = LEAF_DARK, Material = M.SmoothPlastic,
			CastShadow = false })
	end
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2 + 0.3
		local p0 = c + V(math.cos(a) * 92, cy + 4, math.sin(a) * 92)
		local p1 = p0 - V(0, 14 + (i % 3) * 5, 0)
		part(deco, { Name = "HangingVine", Size = V(0.5, (p0 - p1).Magnitude, 0.5), CFrame = CF((p0 + p1) / 2), Color = rgb(70, 120, 50), Material = M.Grass })
		for k = 1, 3 do
			part(canopy, { Name = "HangingLeaves", Size = V(5, 4, 5) * (1.2 - k * 0.15), CFrame = CF(p1 + V((k - 2) * 2.2, -k * 0.8, (k % 2) * 2)) * CFrame.Angles(0, k, 0),
				Color = LEAF[(i + k) % #LEAF + 1], Material = M.SmoothPlastic, CastShadow = false })
		end
		if i % 2 == 0 then
			local l = ball(deco, { Name = "SporeLantern", Size = Vector3.one * 2, CFrame = CF(p1 - V(0, 4, 0)), Color = SPORE, Material = M.Neon, CastShadow = false })
			Make("PointLight", { Color = SPORE, Range = 22, Brightness = 1, Shadows = false, Parent = l })
		end
	end
	-- rosetas de folhas brilhantes e flores-estrela na superfície da copa
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local yN = 0.15 + (i % 3) * 0.25
		local p = domeC + V(math.cos(a) * RX * math.sqrt(1 - yN * yN) * 1.02, yN * RY + 4, math.sin(a) * RX * math.sqrt(1 - yN * yN) * 1.02)
		local dir = (p - domeC).Unit
		local cf = CF(p, p + dir)
		for k = 1, 5 do
			local ang = k / 5 * math.pi * 2
			local leaf = part(canopy, { Name = "RosetteLeaf", Size = V(7, 7, 2.6), CFrame = cf * CF(math.cos(ang) * 4.5, math.sin(ang) * 4.5, 0) * CFrame.Angles(math.sin(ang) * rad(-25), math.cos(ang) * rad(25), 0),
				Color = rgb(70, 190, 72), Material = M.SmoothPlastic, Reflectance = 0.06, CastShadow = false })
			Make("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = leaf })
		end
		ball(canopy, { Name = "StarFlower", Size = Vector3.one * 3.2, CFrame = cf * CF(0, 0, -1), Color = i % 2 == 0 and SPORE or rgb(190, 255, 210), Material = M.Neon, CastShadow = false })
	end

	-- COROA ESTELAR: mirante no topo (com baú e altar)
	local crownY = SanctuaryTree.CROWN_Y
	do
		local top = c + V(0, crownY, 0)
		part(walk, { Name = "CrownFloor", Shape = Enum.PartType.Cylinder, Size = V(2, 36, 36), CFrame = CF(top - V(0, 1, 0)) * CFrame.Angles(0, 0, rad(90)), Color = rgb(64, 150, 58),
			Material = M.Grass, CanCollide = true })
		part(walk, { Name = "CrownRim", Shape = Enum.PartType.Cylinder, Size = V(2.4, 38, 38), CFrame = CF(top - V(0, 1.3, 0)) * CFrame.Angles(0, 0, rad(90)), Color = PLANK_DARK,
			Material = M.Wood, CanCollide = true })
		for k = 0, 7 do
			local a = rad(k / 8 * 360)
			local dir = V(math.cos(a), 0, math.sin(a))
			local petal = part(deco, { Name = "StarPetal", Size = V(5, 0.6, 12), CFrame = CF(top + dir * 22 + V(0, 0.5, 0), top + dir * 40 + V(0, 4, 0)), Color = k % 2 == 0 and SPORE or rgb(200, 255, 210),
				Material = M.Neon, Transparency = 0.15, CastShadow = false })
			Make("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = petal })
		end
		part(deco, { Name = "Altar", Size = V(5, 3, 5), CFrame = CF(top + V(0, 1.5, 0)), Color = rgb(230, 224, 206), Material = M.Marble, CanCollide = true })
		local gem = part(deco, { Name = "CrownStar", Size = V(3, 3, 3), CFrame = CF(top + V(0, 6, 0)) * CFrame.Angles(rad(45), rad(45), 0), Color = RUNE, Material = M.Neon, CastShadow = false })
		gem:SetAttribute("Spin", true)
		Make("PointLight", { Color = RUNE, Range = 40, Brightness = 2, Shadows = false, Parent = gem })
		emitter(deco, top + V(0, 8, 0), V(30, 4, 30), { name = "CrownSparkles", color = SPORE, rate = 10, life = 4, speed = 2, size = 0.7, accel = V(0, 1.5, 0) })
		if makeChest then
			local cp = top + V(10, 0, 0)
			local chestCf = CF(cp, top)
			local m, prompt = makeChest(deco, chestCf, "Relicário da Coroa Estelar")
			out.chests.sanct_crown = { model = m, prompt = prompt, pos = cp, title = "Relicário da Coroa Estelar" }
		end
	end

	-- PARTÍCULAS: esporos dourados e folhas brilhantes caindo da copa; vagalumes nos andares
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		emitter(deco, c + V(math.cos(a) * 60, cy - 4, math.sin(a) * 60), V(50, 2, 50), { name = "FallingSpores", color = k % 2 == 0 and SPORE or rgb(150, 255, 150), rate = 5, life = 14,
			speed = 1.2, size = 0.55, accel = V(0, -1.4, 0), drag = 0.2 })
	end
	emitter(deco, c + V(0, hubY + 8, 0), V(60, 14, 60), { name = "HubFireflies", color = rgb(200, 255, 140), rate = 6, life = 6, speed = 1.5, size = 0.35 })

	-- ELEVADOR DE SEIVA: coluna de seiva da praça até o Coração da Raiz + estações nos andares
	local liftFoot = polar(c, SanctuaryTree.LIFT_THETA, 32, 0)
	part(deco, { Name = "SapColumn", Shape = Enum.PartType.Cylinder, Size = V(hubY - 1, 4.5, 4.5), CFrame = CF(liftFoot + V(0, hubY / 2 - 0.5, 0)) * CFrame.Angles(0, 0, rad(90)),
		Color = SAP, Material = M.Neon, Transparency = 0.45, CastShadow = false })
	emitter(deco, liftFoot + V(0, hubY / 2, 0), V(3, hubY - 4, 3), { name = "SapBubbles", color = rgb(255, 230, 150), rate = 8, life = 3, speed = 5, size = 0.4, accel = V(0, 8, 0) })
	local function station(id: string, label: string, pos: Vector3, order: number, facing: Vector3, requiresBoss: string?)
		local pod = part(deco, { Name = "SapLift_" .. id, Size = V(4, 1, 4), CFrame = CF(pos + V(0, 0.5, 0)), Color = SAP, Material = M.Neon, CanCollide = true, CastShadow = false })
		local orb = ball(deco, { Name = "SapLiftOrb", Size = Vector3.one * 2.2, CFrame = CF(pos + V(0, 4.2, 0)), Color = SAP, Material = M.Neon, Transparency = 0.2, CastShadow = false })
		Make("PointLight", { Color = SAP, Range = 14, Brightness = 1.2, Shadows = false, Parent = orb })
		local arrival = CF(pos + V(0, 3.5, 0) + facing.Unit * 4, pos + V(0, 3.5, 0) + facing.Unit * 9)
		out.stops[id] = { id = id, label = label, part = pod, arrival = arrival, order = order, requiresBoss = requiresBoss, pos = pos }
	end
	local function outwardAt(th: number)
		return V(math.cos(rad(th)), 0, math.sin(rad(th)))
	end
	station("ground", "Praça das Raízes", liftFoot + V(0, 0.4, 0) + outwardAt(SanctuaryTree.LIFT_THETA) * 4, 1, outwardAt(SanctuaryTree.LIFT_THETA))
	station("hub", "Coração da Raiz", polar(c, SanctuaryTree.LIFT_THETA, trunkR(hubY) + 6, hubY), 2, outwardAt(SanctuaryTree.LIFT_THETA))
	local nest2 = out.branchEnds[2]
	station("boughs", "Galhos Suspensos", nest2 + ((c - nest2) * V(1, 0, 1)).Unit * 6, 3, ((c - nest2) * V(1, 0, 1)))
	station("canopy", "Copas Celestiais", polar(c, SanctuaryTree.LIFT_THETA, 34, cy), 4, outwardAt(SanctuaryTree.LIFT_THETA))
	station("crown", "Coroa Estelar", c + V(-10, crownY, 0), 5, V(-1, 0, 0), "elderroot")

	out.parts = #model:GetDescendants()
	return out
end

return SanctuaryTree

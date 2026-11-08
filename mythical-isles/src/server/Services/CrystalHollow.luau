-- MUNDO 2 — CRYSTAL HOLLOW (inspirado na arte de referência do autor: montanhas com cristais
-- gigantes azuis e violeta, cachoeiras, rio e lago turquesa, ruínas, pontes, portais e vale gramado).
--
-- Cinco regiões ligadas por caminhos e por um circuito de portais de região:
--   1. Crystal Valley   (centro)      praça, ovos, lagoas, árvores de cristal, NPC, portal
--   2. Shattered Peaks  (θ 45°)       três picos de rocha (Terrain), cristais gigantes, paredão com a
--                                      grande cachoeira, rio até o vale, rampa, ponte suspensa e baú
--   3. Azure Caverns    (θ 195°)      maciço com túnel, salão escavado (Terrain), lago subterrâneo,
--                                      cristais nas paredes, estalactites, passagem secreta e baú
--   4. Prism Lake       (θ 140°)      lago de margens irregulares, ilhas, ruínas, ponte de pedra,
--                                      penhasco com cachoeiras, saída que cai da ilha
--   5. Titan's Domain   (θ 90°)       arena do Prism Titan cercada de obeliscos, estátua quebrada,
--                                      fachada de templo e espigões de cristal
--
-- Montanhas, lago, rio e caverna são Terrain (com fallback em peças para o essencial se o Terrain
-- falhar). As posições usam o mesmo sistema polar do WorldBuilder.Layout.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local Make = require(Shared.Util.Make)
local WorldBuilder = require(script.Parent.WorldBuilder)
local CrystalKit = require(script.Parent.CrystalKit)
local BeaconTower = require(script.Parent.BeaconTower)

local CrystalHollow = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB

local W = Worlds.Info.crystal
local C = W.center
local M = Enum.Material

local function P(theta: number, dist: number, y: number?): Vector3
	return WorldBuilder.polar(C, theta, dist) + V(0, y or 0, 0)
end
local function out(theta: number): Vector3
	return V(math.cos(rad(theta)), 0, math.sin(rad(theta)))
end
local function tan(theta: number): Vector3
	return V(-math.sin(rad(theta)), 0, math.cos(rad(theta)))
end
-- referencial no chão em `pos`, olhando para `toward` (horizontal)
local function facing(pos: Vector3, toward: Vector3): CFrame
	local d = (toward - pos) * V(1, 0, 1)
	if d.Magnitude < 0.01 then
		d = V(0, 0, -1)
	end
	return CF(pos, pos + d)
end

-- distância horizontal de q ao segmento a-b
local function segDist(q: Vector3, a: Vector3, b: Vector3): number
	local ab = (b - a) * V(1, 0, 1)
	local aq = (q - a) * V(1, 0, 1)
	local t = math.clamp(aq:Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (aq - ab * t).Magnitude
end
local function clearOf(q: Vector3, discs): boolean
	for _, d in ipairs(discs) do
		if ((q - d[1]) * V(1, 0, 1)).Magnitude < d[2] then
			return false
		end
	end
	return true
end

local T: Terrain? = nil
local function terrain(): Terrain?
	return T
end

-------------------------------------------------------------------------------
-- Terrain: montanhas, água, túneis
-------------------------------------------------------------------------------

-- Montanha / maciço rochoso: núcleo maciço + dezenas de blocos de rocha espalhados num cone
-- irregular + faces de penhasco inclinadas + musgo nas partes altas + cume em lâminas.
-- (Uma pilha simples de esferas parecia um "boneco de neve"; assim a silhueta fica recortada.)
local function crag(pos: Vector3, height: number, baseR: number, rng: Random, lean: Vector3, opts)
	local t = terrain()
	if not t then
		return
	end
	opts = opts or {}
	local function R(f)
		return baseR * (1 - f) ^ 0.9
	end
	local function axis(f)
		return pos + lean * f * height * 0.18
	end
	-- núcleo (garante massa sólida no eixo)
	for k = 0, 5 do
		local f = k / 6
		t:FillBall(axis(f) + V(0, height * f, 0), math.max(4, R(f) * 0.62), M.Basalt)
	end
	-- massa irregular
	for _ = 1, opts.chunks or 34 do
		local f = rng:NextNumber() ^ 0.85
		local Rf = R(f) + 3
		local a = rng:NextNumber(0, math.pi * 2)
		local d = Rf * rng:NextNumber(0.25, 0.8)
		local r = math.max(3.5, Rf * rng:NextNumber(0.3, 0.55))
		local mat = rng:NextNumber() < 0.28 and M.Slate or M.Basalt
		t:FillBall(axis(f) + V(math.cos(a) * d, height * f - r * 0.2, math.sin(a) * d), r, mat)
	end
	-- faces de penhasco: lajes inclinadas encostadas nos flancos
	for i = 1, opts.faces or 6 do
		local a = i / (opts.faces or 6) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local f = rng:NextNumber(0.1, 0.55)
		local Rf = R(f)
		local dir = V(math.cos(a), 0, math.sin(a))
		local c = axis(f) + dir * Rf * 0.7 + V(0, height * f, 0)
		local slab = CF(c, c + dir) * ANG(rad(-rng:NextNumber(8, 20)), 0, rad(rng:NextNumber(-12, 12)))
		t:FillBlock(slab, V(Rf * rng:NextNumber(0.7, 1.1), height * rng:NextNumber(0.25, 0.4), 5), M.Basalt)
	end
	-- musgo nas saliências altas (como na arte de referência)
	for _ = 1, opts.moss or 5 do
		local f = rng:NextNumber(0.35, 0.8)
		local a = rng:NextNumber(0, math.pi * 2)
		local Rf = R(f)
		t:FillBall(axis(f) + V(math.cos(a) * Rf * 0.75, height * f + 1, math.sin(a) * Rf * 0.75), math.max(3, Rf * 0.28), M.LeafyGrass)
	end
	-- cume: lâminas de rocha giradas
	local top = axis(1) + V(0, height - 2, 0)
	for k = 1, 2 do
		t:FillBlock(CF(top + V(rng:NextNumber(-2, 2), -k * 3, rng:NextNumber(-2, 2))) * ANG(rad(rng:NextNumber(20, 40)), rad(k * 50), rad(rng:NextNumber(20, 40))),
			Vector3.one * math.max(5, baseR * (0.16 + k * 0.05)), M.Basalt)
	end
end

local function mountain(pos: Vector3, height: number, baseR: number, rng: Random, lean: Vector3)
	crag(pos, height, baseR, rng, lean)
end

-- Água "encaixada" no terreno: escava, enche de água até 2 studs abaixo do chão e forra o fundo.
local function pond(pos: Vector3, r: number, depth: number?)
	local t = terrain()
	if not t then
		return
	end
	local d = depth or 7
	t:FillCylinder(CF(pos - V(0, d / 2, 0)), d, r, M.Air)
	t:FillCylinder(CF(pos - V(0, 2 + (d - 2) / 2, 0)), d - 2, r, M.Water)
	t:FillCylinder(CF(pos - V(0, d + 0.5, 0)), 1.5, r, M.Sand)
end

-- Rio: segmentos escavados e cheios de água entre pontos (largura w).
local function river(points: { Vector3 }, w: number)
	local t = terrain()
	if not t then
		return
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + w * 0.8
		local look = CF(mid, mid + (b - a) * V(1, 0, 1))
		t:FillBlock(look - V(0, 2.5, 0), V(w + 2, 5, len), M.Air)
		t:FillBlock(look - V(0, 4, 0), V(w, 4, len), M.Water)
		t:FillBlock(look - V(0, 6.5, 0), V(w + 2, 1, len), M.Sand)
	end
	for _, p in ipairs(points) do
		t:FillCylinder(CF(p - V(0, 2.5, 0)), 5, w / 2 + 1, M.Air)
		t:FillCylinder(CF(p - V(0, 4, 0)), 4, w / 2, M.Water)
	end
end

-- Caminho de pedra (calçamento de Terrain rente ao chão).
local function path(points: { Vector3 }, w: number?)
	local t = terrain()
	if not t then
		return
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local mid = (a + b) / 2
		t:FillBlock(CF(mid - V(0, 1, 0), mid - V(0, 1, 0) + (b - a) * V(1, 0, 1)), V(w or 7, 2, (b - a).Magnitude + 3), M.Cobblestone)
	end
end

-------------------------------------------------------------------------------
-- Região 1 — Crystal Valley
-------------------------------------------------------------------------------

local function buildValley(folder: Instance, rng: Random, out_)
	local f = Make("Folder", { Name = "CrystalValley", Parent = folder })
	-- lagoa do vale com pedras, cristais e flores luminosas na margem
	local pb = P(125, 66)
	pond(pb, 9, 6)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local q = pb + V(math.cos(a), 0, math.sin(a)) * 10.5
		if i % 3 == 0 then
			CrystalKit.scatter(f, q, rng, { "blue", "ice" })
		else
			WorldBuilder.rockCluster(f, q - V(0, 0.4, 0), 0.55, rng, rgb(84, 86, 104), M.Slate, rgb(70, 130, 92))
		end
	end
	for i = 1, 5 do
		local a = i * 1.3
		local q = pb + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(2, 6)
		CrystalKit.part({ Name = "GlowLily", Shape = Enum.PartType.Cylinder, Size = V(0.2, 2.4, 2.4), CFrame = CF(q - V(0, 1.85, 0)) * ANG(0, 0, rad(90)), Color = rgb(70, 140, 110), Parent = f })
		CrystalKit.part({ Name = "GlowLilyBloom", Size = V(0.6, 0.4, 0.6), CFrame = CF(q - V(0, 1.5, 0)) * ANG(0, rad(45), 0), Color = rgb(190, 140, 255), Material = M.Neon, CastShadow = false, Parent = f })
	end
	-- lagoa onde o rio dos picos termina
	pond(P(52, 80), 11, 7)
	-- lanternas ao longo dos caminhos principais
	for _, th in ipairs({ 0, 90, 180, 300 }) do
		for _, d in ipairs({ 38, 62 }) do
			local q = P(th, d) + tan(th) * 5
			if WorldBuilder.isFree("crystal", q, 2) then
				CrystalKit.lantern(f, WorldBuilder.groundAt(q), WorldBuilder.fire)
			end
		end
	end
	-- árvores de cristal (copas de folhas azuis e violeta) e aglomerados num anel ao redor da praça
	local placed = 0
	for i = 1, 40 do
		if placed >= 12 then
			break
		end
		local q = P(rng:NextNumber(0, 360), rng:NextNumber(34, 88))
		if WorldBuilder.isFree("crystal", q, 6) then
			placed += 1
			local g = WorldBuilder.groundAt(q)
			if placed % 3 == 0 then
				CrystalKit.cluster(f, CF(g) * ANG(0, rng:NextNumber(0, 6.28), 0), rng, { count = 5, h = rng:NextNumber(6, 10), w = 1.5, styles = placed % 2 == 0 and { "violet", "blue" } or { "blue", "ice" } })
			else
				WorldBuilder.oakTree(f, g, rng:NextNumber(0.85, 1.15), rng, rgb(84, 66, 74), placed % 2 == 0 and rgb(124, 92, 226) or rgb(58, 112, 214))
			end
		end
	end
	-- (o arco antigo do caminho oeste virou o portal de pedra das ruínas do Farol Ancestral: buildBeacon)
	-- NPC e portal de região
	local npcModel, npcPrompt = CrystalKit.npc(f, facing(P(120, 34), C), "Lyra, a Sábia", rgb(70, 60, 150), "blue")
	table.insert(out_.npcs, { id = "lyra", model = npcModel, prompt = npcPrompt, name = "Lyra", lines = {
		"Bem-vindo a Crystal Hollow! Os portais de pedra ligam as cinco regiões — atravesse um para ir à próxima.",
		"Nos Picos Estilhaçados há uma ponte suspensa. Do outro lado, um baú espera quem tiver coragem.",
		"Dizem que existe uma passagem escondida atrás dos cristais pendurados nas Cavernas Azuis...",
		"No Lago Prisma, siga a ponte de pedra até a ilha das ruínas.",
		"O Prism Titan dorme no Domínio do Titã. Leve uma equipe forte e observe os avisos no chão!",
	} })
	local gp = P(160, 58)
	local gate, vortex = CrystalKit.gate(f, facing(gp, C), rgb(120, 200, 255), "Shattered Peaks →")
	out_.gates.crystal_valley = { model = gate, part = vortex, arrival = facing(gp, C) * CF(0, 3.5, -8), from = "crystal_valley" }
	-- baú do vale, junto à lagoa
	local cp = P(138, 58)
	local chest, prompt = CrystalKit.chest(f, facing(cp, C), "Baú do Vale")
	out_.chests.valley_chest = { model = chest, prompt = prompt, pos = cp, title = "Baú do Vale", region = "crystal_valley" }
end

-------------------------------------------------------------------------------
-- Farol Ancestral — torre-farol em treliça com cristal gigante e ruínas (imagem do autor), no fim do
-- caminho oeste do vale, entre as zonas de inimigos
-------------------------------------------------------------------------------

CrystalHollow.BEACON = { theta = 294, dist = 100 }

local function buildBeacon(folder: Instance, rng: Random, out_)
	local f = Make("Folder", { Name = "AncientBeaconSite", Parent = folder })
	local pos = WorldBuilder.groundAt(P(CrystalHollow.BEACON.theta, CrystalHollow.BEACON.dist))
	local toCenter = (C - pos) * V(1, 0, 1)
	local t = BeaconTower.build(f, pos, toCenter, rng)
	-- as ruínas só nascem em lugar livre (fora das zonas de inimigos e dos campos) e fora da torre
	local function free(q: Vector3, m: number): boolean
		return ((q - pos) * V(1, 0, 1)).Magnitude > 40 + m and WorldBuilder.isFree("crystal", q, m, true)
	end
	local ruins, isles = BeaconTower.ruins(f, pos, toCenter.Unit, rng, free)
	local chest, prompt = CrystalKit.chest(f, t.chestCF, "Relicário do Farol")
	out_.chests.beacon_chest = { model = chest, prompt = prompt, pos = t.chestCF.Position, title = "Relicário do Farol", region = "ancient_beacon" }
	t.ruins, t.isles = ruins, isles
	out_.beacon = t
end

-------------------------------------------------------------------------------
-- Região 2 — Shattered Peaks
-------------------------------------------------------------------------------

local function buildPeaks(folder: Instance, rng: Random, out_)
	local f = Make("Folder", { Name = "ShatteredPeaks", Parent = folder })
	local th = 45
	local o, t = out(th), tan(th)
	local Pc = P(th, 185)
	local A = Pc - t * 35 + o * 10
	local B = Pc + o * 30 + t * 5
	local Cc = Pc + t * 40 + o * 8
	mountain(A, 74, 34, rng, o * 0.4)
	mountain(B, 100, 40, rng, o * 0.3)
	mountain(Cc, 66, 32, rng, o * 0.4)
	local tr = terrain()
	-- paredão de onde cai a grande cachoeira (face voltada para o vale)
	local wallPos = B - o * 16
	if tr then
		tr:FillBlock(CF(wallPos + V(0, 37, 0), wallPos + V(0, 37, 0) + o), V(30, 80, 12), M.Basalt)
		tr:FillBlock(CF(wallPos - o * 5 + V(0, 76, 0), wallPos - o * 5 + V(0, 76, 0) + o), V(18, 3, 6), M.Slate) -- borda de onde a água sai
		-- quebra a silhueta "de caixa" do paredão: rochas nas laterais e no topo
		for k = 0, 6 do
			for _, side in ipairs({ -1, 1 }) do
				tr:FillBall(wallPos + t * side * rng:NextNumber(15, 19) + o * rng:NextNumber(-2, 4) + V(0, 6 + k * 11, 0), rng:NextNumber(6, 9), k % 3 == 0 and M.Slate or M.Basalt)
			end
		end
		tr:FillBall(wallPos + o * 4 + V(0, 80, 0), 10, M.Basalt)
	end
	local pool = B - o * 34
	pond(pool, 13, 8)
	WorldBuilder.waterfall(f, wallPos - o * 8 + V(0, 76, 0), 76, 12, -o)
	-- cachoeira menor descendo do pico A para a mesma bacia
	WorldBuilder.waterfall(f, A + t * 14 - o * 8 + V(0, 30, 0), 30, 5, (pool - (A + t * 14)).Unit)
	-- rio da bacia até a lagoa do vale
	river({ pool, P(48, 160), P(51, 140), P(54, 118), P(53, 98), P(52, 82) }, 8) -- mesmo traçado de riverPts (abaixo)
	-- ponte de pedra cruzando o rio (trilha entre os picos e o domínio do titã)
	local mid = (P(54, 118) + P(53, 98)) / 2
	local across = tan(53)
	CrystalKit.stoneBridge(f, mid - across * 9 + V(0, 0.6, 0), mid + across * 9 + V(0, 0.6, 0), 6, rng)
	-- rampa de pedra (Terrain) do chão até a plataforma do pico A, e plataformas com ponte suspensa até o pico C
	local platY = 32
	-- plataformas na face dos picos A e C voltada para o vale; a ponte passa na frente da grande
	-- cachoeira (fora do pico B). Um nicho é escavado acima de cada plataforma.
	local pa = Pc - t * 19 + V(0, platY, 0)
	local pc = Pc + t * 25 - o * 2 + V(0, platY, 0)
	if tr then
		local foot = pa - o * 70 - V(0, platY, 0)
		local midR = (foot + pa) / 2 - V(0, 1.5, 0)
		tr:FillBlock(CF(midR, midR + (pa - foot)), V(9, 4, (pa - foot).Magnitude + 6), M.Slate)
		for _, q in ipairs({ pa, pc }) do
			tr:FillBlock(CF(q + V(0, 7, 0)), V(16, 14, 16), M.Air)
			tr:FillCylinder(CF(q - V(0, 3, 0)), 6, 9, M.Slate)
		end
	end
	for _, q in ipairs({ pa, pc }) do
		CrystalKit.part({ Name = "Platform", Size = V(14, 1.2, 14), CFrame = CF(q - V(0, 0.5, 0)), Color = CrystalKit.STONE, Material = M.Slate, CanCollide = true, Parent = f })
	end
	out_.walkPoints["plataforma do pico A"] = pa + V(0, 2.5, 0)
	out_.walkPoints["plataforma do pico C"] = pc + V(0, 2.5, 0)
	out_.walkPoints["pé da rampa"] = pa - o * 66 - V(0, platY - 3, 0)
	local dirAC = ((pc - pa) * V(1, 0, 1)).Unit
	CrystalKit.ropeBridge(f, pa + dirAC * 7, pc - dirAC * 7, 5)
	CrystalKit.lantern(f, pa - o * 5 - dirAC * 3, WorldBuilder.fire)
	CrystalKit.lantern(f, pc - o * 5 + dirAC * 3, WorldBuilder.fire)
	local chest, prompt = CrystalKit.chest(f, facing(pc, pa) * CF(0, 0, 3), "Baú do Pico")
	out_.chests.peak_chest = { model = chest, prompt = prompt, pos = pc, title = "Baú do Pico", region = "shattered_peaks" }
	-- cristais gigantes: coroa do pico B (como na arte), flancos e base da cachoeira
	-- (afundados alguns studs no cume: o cristal "nasce" da rocha)
	CrystalKit.giant(f, B + o * 0.3 * 100 * 0.18 + V(0, 84, 0), 1.25, rng, { "blue", "ice", "sapphire" }, rgb(120, 190, 255), true)
	CrystalKit.giant(f, A + o * 0.4 * 74 * 0.18 + V(0, 60, 0), 0.8, rng, { "violet", "amethyst" }, rgb(190, 130, 255), true)
	CrystalKit.giant(f, Cc + o * 0.4 * 66 * 0.18 + V(0, 53, 0), 0.75, rng, { "blue", "violet" }, rgb(150, 160, 255), true)
	CrystalKit.giant(f, pool + t * 16 + o * 2, 0.6, rng, { "blue", "ice" }, rgb(110, 200, 255))
	-- aglomerados nas encostas, inclinados para fora
	for i = 1, 10 do
		local m = ({ A, B, Cc })[i % 3 + 1]
		local a = rng:NextNumber(0, math.pi * 2)
		local h = rng:NextNumber(6, 26)
		local q = m + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(18, 24) * (1 - h / 80) + V(0, h, 0)
		local normal = (V(math.cos(a), 0.9, math.sin(a))).Unit
		local at = CF(q, q + normal) * ANG(rad(-90), 0, 0)
		CrystalKit.cluster(f, at, rng, { count = 5, h = rng:NextNumber(5, 10), w = 1.6, styles = i % 2 == 0 and { "violet", "blue" } or { "blue", "sapphire" }, rock = false })
	end
	-- árvores na base dos picos
	local riverPts = { pool, P(48, 160), P(51, 140), P(54, 118), P(53, 98), P(52, 82) }
	local planted = 0
	for _ = 1, 30 do
		if planted >= 6 then
			break
		end
		local q = Pc - o * rng:NextNumber(36, 58) + t * rng:NextNumber(-48, 48)
		local nearRiver = false
		for k = 1, #riverPts - 1 do
			if segDist(q, riverPts[k], riverPts[k + 1]) < 10 then
				nearRiver = true
			end
		end
		if segDist(q, Pc - t * 19 - o * 70, Pc - t * 19) < 9 then
			nearRiver = true -- (a rampa também fica livre)
		end
		if not nearRiver and clearOf(q, { { A, 31 }, { B, 36 }, { Cc, 29 }, { pool, 16 }, { Pc - o * 48 - t * 2, 12 }, { Pc - t * 19 - o * 35, 8 } }) and WorldBuilder.isFree("crystal", q, 2, true) then
			planted += 1
			WorldBuilder.oakTree(f, WorldBuilder.groundAt(q), rng:NextNumber(0.9, 1.2), rng, rgb(84, 66, 74), planted % 2 == 0 and rgb(70, 120, 210) or rgb(110, 84, 210))
		end
	end
	WorldBuilder.ambient(f, pool + V(0, 3, 0), "mist", 30)
	-- portal da região
	local gp = Pc - o * 48 - t * 2
	local gate, vortex = CrystalKit.gate(f, facing(gp, C), rgb(170, 140, 255), "Azure Caverns →")
	out_.gates.shattered_peaks = { model = gate, part = vortex, arrival = facing(gp, C) * CF(0, 3.5, -8), from = "shattered_peaks" }
end

-------------------------------------------------------------------------------
-- Região 3 — Azure Caverns
-------------------------------------------------------------------------------

local function buildCaverns(folder: Instance, rng: Random, out_)
	local f = Make("Folder", { Name = "AzureCaverns", Parent = folder })
	local th = 195
	local o, t = out(th), tan(th)
	local Cm = P(th, 192)
	local tr = terrain()
	if tr then
		-- maciço (rocha) com lóbulos; depois escavamos túnel, salão, passagem e câmara secreta
		-- maciço recortado (mesmo gerador das montanhas) com núcleo que cobre o salão
		tr:FillBall(Cm + V(0, 6, 0), 30, M.Basalt)
		crag(Cm + o * 4, 46, 40, rng, o * 0.3, { chunks = 30, faces = 7, moss = 6 })
		tr:FillBall(Cm + t * 22 + V(0, 4, 0), 18, M.Basalt)
		tr:FillBall(Cm - t * 22 + V(0, 2, 0), 18, M.Slate)
		tr:FillBall(Cm + t * 35 + V(0, 6, 0), 15, M.Basalt)
		-- túnel de entrada (piso no nível do chão)
		local mouth, inner = Cm - o * 48, Cm - o * 12
		local mid = (mouth + inner) / 2
		tr:FillBlock(CF(mid + V(0, 6, 0), mid + V(0, 6, 0) + o), V(11, 12, (inner - mouth).Magnitude), M.Air)
		-- salão principal (cúpula) com piso refeito no nível 0
		tr:FillBall(Cm + V(0, 13, 0), 17, M.Air)
		tr:FillCylinder(CF(Cm - V(0, 3, 0)), 6, 17, M.Slate)
		-- passagem secreta estreita e câmara escondida
		local pass0, pass1 = Cm + t * 14, Cm + t * 30
		local pm = (pass0 + pass1) / 2
		tr:FillBlock(CF(pm + V(0, 3.5, 0), pm + V(0, 3.5, 0) + t), V(5, 7, (pass1 - pass0).Magnitude + 2), M.Air)
		tr:FillBall(Cm + t * 35 + V(0, 6, 0), 7, M.Air)
		tr:FillCylinder(CF(Cm + t * 35 - V(0, 2, 0)), 4, 7, M.Slate)
	end
	-- lago subterrâneo no salão
	local poolC = Cm + t * 6 + o * 4
	pond(poolC, 6, 5)
	-- arco de pedra na boca do túnel e lanternas
	local mouth = Cm - o * 44
	CrystalKit.arch(f, facing(mouth, Cm) * CF(0, 0, 0), 11, 15, 4, rng, false)
	for _, side in ipairs({ -1, 1 }) do
		CrystalKit.lantern(f, mouth - o * 3 + t * side * 9, WorldBuilder.fire)
	end
	-- cristais nas paredes do salão (apontando para dentro), estalactites e estalagmites
	local hallC = Cm + V(0, 13, 0)
	for i = 1, 14 do
		local az = i / 14 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local el = rad(rng:NextNumber(-25, 35))
		local dir = V(math.cos(az) * math.cos(el), math.sin(el), math.sin(az) * math.cos(el))
		local toEntrance = (-o):Dot(V(dir.X, 0, dir.Z).Unit)
		local toSecret = t:Dot(V(dir.X, 0, dir.Z).Unit)
		if toEntrance < 0.85 and toSecret < 0.9 then
			local q = hallC + dir * 15.5
			local at = CF(q, q - dir) * ANG(rad(-90), 0, 0)
			CrystalKit.cluster(f, at, rng, { count = 4, h = rng:NextNumber(4, 8), w = 1.2, styles = i % 3 == 0 and { "violet", "amethyst" } or { "blue", "sapphire", "ice" }, rock = false })
		end
	end
	for i = 1, 9 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(3, 12)
		local top = Cm + V(math.cos(a) * d, 13 + math.sqrt(math.max(0, 17 ^ 2 - d * d)) - 1, math.sin(a) * d)
		local h = rng:NextNumber(3, 6.5)
		-- estalactite: duas cunhas de ponta para baixo
		for q = 0, 1 do
			CrystalKit.wedge({ Name = "Stalactite", Size = V(1.4, h, 0.9), CFrame = CF(top - V(0, h / 2, 0)) * ANG(0, a + q * math.pi, 0) * CF(0, 0, 0.45) * ANG(rad(180), 0, 0),
				Color = rgb(70, 76, 100), Material = M.Slate, CastShadow = false, Parent = f })
		end
	end
	for i = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local q = Cm + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(10, 14)
		if (-o):Dot(V(math.cos(a), 0, math.sin(a))) < 0.8 then
			CrystalKit.scatter(f, q, rng, { "blue", "violet" })
		end
	end
	-- luzes do salão (poucas: os cristais dão o resto) e névoa
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		local lp = CrystalKit.part({ Name = "CaveGlow", Size = V(1, 1, 1), CFrame = CF(Cm + V(math.cos(a) * 8, 6, math.sin(a) * 8)), Transparency = 1, Parent = f })
		Make("PointLight", { Color = i == 2 and rgb(170, 120, 255) or rgb(90, 170, 255), Range = 28, Brightness = 1.3, Shadows = false, Parent = lp })
	end
	WorldBuilder.ambient(f, Cm + V(0, 3, 0), "mist", 24)
	WorldBuilder.ambient(f, Cm + V(0, 8, 0), "glints", 26)
	-- cortina de cristais pendurados escondendo a passagem secreta (atravessável)
	local pass0 = Cm + t * 14
	for k = -2, 2 do
		CrystalKit.shard(f, CF(pass0 + t * 0.5 + (o * k * 1.1) + V(0, 7.5, 0)) * ANG(rad(180), rng:NextNumber(0, 6), 0), rng:NextNumber(4, 6.5), 0.8, k % 2 == 0 and "ice" or "blue", false)
	end
	-- câmara secreta: cristal raro + baú
	local sc = Cm + t * 35
	CrystalKit.rare(f, sc + o * 3, rng)
	local chest, prompt = CrystalKit.chest(f, facing(sc - o * 2, Cm), "Baú Secreto das Cavernas")
	out_.chests.cavern_secret = { model = chest, prompt = prompt, pos = sc - o * 2, title = "Baú Secreto das Cavernas", region = "azure_caverns" }
	-- cristais por fora do maciço
	for _, q in ipairs({ Cm - o * 38 + t * 22, Cm - o * 38 - t * 22, Cm - o * 30 + t * 32, Cm - o * 30 - t * 32 }) do
		CrystalKit.cluster(f, CF(WorldBuilder.groundAt(q)) * ANG(0, rng:NextNumber(0, 6), 0), rng, { count = 5, h = rng:NextNumber(6, 11), w = 1.6, styles = { "blue", "violet", "sapphire" } })
	end
	CrystalKit.giant(f, Cm - o * 30 + t * 26, 0.7, rng, { "sapphire", "blue" }, rgb(90, 150, 255))
	-- NPC guardião e portal
	local npcModel, npcPrompt = CrystalKit.npc(f, facing(Cm - o * 52 + t * 9, C), "Orin, o Guardião", rgb(40, 70, 120), "sapphire")
	table.insert(out_.npcs, { id = "orin", model = npcModel, prompt = npcPrompt, name = "Orin", lines = {
		"As Cavernas Azuis são frias, mas os cristais iluminam o caminho.",
		"Ouça... a água do lago subterrâneo sempre corre para onde há segredos.",
		"Nem toda parede de cristal é sólida. Alguns caminhos só aparecem para quem atravessa.",
	} })
	local gp = Cm - o * 52 - t * 12
	local gate, vortex = CrystalKit.gate(f, facing(gp, C), rgb(90, 150, 255), "Prism Lake →")
	out_.gates.azure_caverns = { model = gate, part = vortex, arrival = facing(gp, C) * CF(0, 3.5, -8), from = "azure_caverns" }
	out_.caveHall = Cm
	for label, q in pairs({ ["boca do túnel"] = Cm - o * 46, ["meio do túnel"] = Cm - o * 30, ["salão da caverna"] = Cm - o * 6 - t * 6,
		["passagem secreta"] = Cm + t * 22, ["câmara secreta"] = Cm + t * 35 + o * 1 }) do
		out_.walkPoints[label] = q + V(0, 2.5, 0)
	end
end

-------------------------------------------------------------------------------
-- Região 4 — Prism Lake
-------------------------------------------------------------------------------

local function buildLake(folder: Instance, rng: Random, out_)
	local f = Make("Folder", { Name = "PrismLake", Parent = folder })
	local th = 140
	local o, t = out(th), tan(th)
	local Lc = P(th, 165)
	local tr = terrain()
	-- margens irregulares: três círculos sobrepostos
	local lobes = { { Lc, 40 }, { Lc + t * 22 + o * 6, 28 }, { Lc - t * 24 - o * 4, 26 } }
	if tr then
		for _, l in ipairs(lobes) do
			tr:FillCylinder(CF(l[1] - V(0, 5, 0)), 10, l[2], M.Air)
		end
		for _, l in ipairs(lobes) do
			tr:FillCylinder(CF(l[1] - V(0, 7, 0)), 8, l[2], M.Water)
			tr:FillCylinder(CF(l[1] - V(0, 12, 0)), 2, l[2], M.Sand)
		end
		-- ilhas
		tr:FillCylinder(CF(Lc + o * 8 - t * 6 - V(0, 5.5, 0)), 13, 11, M.Slate)
		tr:FillCylinder(CF(Lc + o * 8 - t * 6 + V(0, 0.5, 0)), 1, 10, M.Grass)
		tr:FillBall(Lc + t * 26 - V(0, 3, 0), 6, M.Basalt)
		tr:FillBall(Lc - t * 22 - o * 14 - V(0, 3, 0), 5, M.Basalt)
		-- penhasco no lado tangente, de onde caem duas cachoeiras
		local cl = Lc + t * 50
		tr:FillBlock(CF(cl + V(0, 12, 0), cl + V(0, 12, 0) - t), V(40, 34, 12), M.Basalt)
		crag(cl + t * 14, 44, 24, rng, t * 0.3, { chunks = 18, faces = 4, moss = 4 })
		for k = -2, 2 do
			tr:FillBall(cl + o * k * 9 + t * 5 + V(0, 28 + (k % 2) * 4, 0), 7, k % 2 == 0 and M.Basalt or M.Slate)
		end
		tr:FillBall(cl + o * 22 + V(0, 10, 0), 10, M.Slate)
		tr:FillBall(cl - o * 22 + V(0, 8, 0), 9, M.Basalt)
	end
	local cl = Lc + t * 50
	for _, k in ipairs({ -9, 8 }) do
		WorldBuilder.waterfall(f, cl - t * 6.5 + o * k + V(0, 28.5, 0), 31, k < 0 and 6 or 4.5, -t)
	end
	-- saída do lago: riacho até a borda e cachoeira caindo da ilha
	local exitA = Lc + o * 38
	local edge = P(th, W.radius - 2)
	river({ exitA, (exitA + edge) / 2, edge }, 6)
	WorldBuilder.waterfall(f, edge + o * 1.5 + V(0, -1.5, 0), 140, 6, o)
	-- ilha das ruínas: plataforma, colunas (algumas quebradas), arco, cristal raro e baú
	local isl = Lc + o * 8 - t * 6 + V(0, 1, 0)
	CrystalKit.part({ Name = "RuinFloor", Size = V(15, 0.8, 15), CFrame = CF(isl + V(0, 0.2, 0)) * ANG(0, rad(th), 0), Color = CrystalKit.STONE, Material = M.Cobblestone, CanCollide = true, Parent = f })
	for k = 1, 6 do
		local a = rad(th) + k / 6 * math.pi * 2
		CrystalKit.column(f, isl + V(math.cos(a), 0, math.sin(a)) * 7.5, 11, 0.9, rng, k % 3 ~= 0)
	end
	CrystalKit.arch(f, facing(isl - o * 7, Lc - o * 40), 6, 9, 2, rng, true)
	CrystalKit.rare(f, isl + o * 2, rng)
	out_.walkPoints["ilha das ruínas"] = isl - o * 5 + V(0, 2.5, 0)
	local chest, prompt = CrystalKit.chest(f, facing(isl - o * 3 + t * 3, Lc - o * 40), "Baú das Ruínas")
	out_.chests.lake_ruins = { model = chest, prompt = prompt, pos = isl - o * 3 + t * 3, title = "Baú das Ruínas", region = "prism_lake" }
	-- ponte de pedra da margem até a ilha
	CrystalKit.stoneBridge(f, Lc - o * 42 + V(0, 0.6, 0), isl - o * 7.5 + V(0, 0.2, 0), 6, rng)
	-- cristais subindo da água, nas ilhotas e na margem
	for i = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local q = Lc + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(14, 34)
		if (q - isl).Magnitude > 13 then
			CrystalKit.cluster(f, CF(q - V(0, 4, 0)) * ANG(0, a, 0), rng, { count = 4, h = rng:NextNumber(7, 13), w = 1.5, styles = i % 2 == 0 and { "violet", "blue" } or { "ice", "blue" }, rock = false })
		end
	end
	CrystalKit.giant(f, Lc + t * 26 + V(0, 1, 0), 0.75, rng, { "violet", "amethyst", "blue" }, rgb(180, 130, 255))
	CrystalKit.giant(f, cl + t * 12 + V(0, 34, 0), 0.9, rng, { "blue", "ice" }, rgb(120, 200, 255), true)
	for i = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local q = Lc + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(47, 58)
		if clearOf(q, { { lobes[1][1], lobes[1][2] + 4 }, { lobes[2][1], lobes[2][2] + 4 }, { lobes[3][1], lobes[3][2] + 4 }, { cl, 24 }, { Lc - o * 62, 12 } })
			and WorldBuilder.isFree("crystal", q, 2, true) then
			local g = WorldBuilder.groundAt(q)
			if i % 3 == 0 then
				CrystalKit.scatter(f, g, rng, { "violet", "blue" })
			else
				WorldBuilder.oakTree(f, g, rng:NextNumber(0.8, 1.1), rng, rgb(84, 66, 74), i % 2 == 0 and rgb(70, 120, 214) or rgb(120, 92, 220))
			end
		end
	end
	WorldBuilder.ambient(f, cl - t * 12 + V(0, 2, 0), "mist", 30)
	WorldBuilder.ambient(f, Lc + V(0, 2, 0), "glints", 40)
	-- portal da região
	local gp = Lc - o * 62
	local gate, vortex = CrystalKit.gate(f, facing(gp, C), rgb(200, 150, 255), "Titan's Domain →")
	out_.gates.prism_lake = { model = gate, part = vortex, arrival = facing(gp, C) * CF(0, 3.5, -8), from = "prism_lake" }
end

-------------------------------------------------------------------------------
-- Região 5 — Titan's Domain
-------------------------------------------------------------------------------

local function buildTitan(folder: Instance, rng: Random, out_)
	local f = Make("Folder", { Name = "TitansDomain", Parent = folder })
	local L = WorldBuilder.Layout
	local A = P(L.arena.theta, L.arena.dist)
	-- via processional: obeliscos com cristal e estandartes dos dois lados do caminho
	for _, d in ipairs({ 50, 64 }) do
		for _, side in ipairs({ -1, 1 }) do
			local q = P(90 + side * 6, d)
			CrystalKit.part({ Name = "ObeliskBase", Size = V(4, 1.2, 4), CFrame = CF(q + V(0, 0.6, 0)), Color = rgb(70, 66, 92), Material = M.Slate, CanCollide = true, Parent = f })
			CrystalKit.part({ Name = "Obelisk", Size = V(2.6, 14, 2.6), CFrame = CF(q + V(0, 8, 0)), Color = rgb(58, 56, 80), Material = M.Basalt, CanCollide = true, Parent = f })
			CrystalKit.shard(f, CF(q + V(0, 15, 0)) * ANG(0, rad(45), 0), 4.5, 1.6, side < 0 and "blue" or "violet", true)
			CrystalKit.banner(f, facing(q, P(90, d)) * CF(0, 0, -1.5), 11)
		end
	end
	-- estátua colossal quebrada de um titã antigo (tronco, cabeça caída, mão)
	local sp = P(70, 70)
	local scf = facing(sp, A)
	CrystalKit.part({ Name = "StatuePlinth", Size = V(12, 2.4, 10), CFrame = scf * CF(0, 1.2, 0), Color = rgb(96, 94, 112), Material = M.Slate, CanCollide = true, Parent = f })
	CrystalKit.part({ Name = "StatueLegs", Size = V(8, 7, 5), CFrame = scf * CF(0, 5.9, 0), Color = rgb(70, 70, 92), Material = M.Basalt, CanCollide = true, Parent = f })
	CrystalKit.part({ Name = "StatueTorso", Size = V(9, 6, 5.5), CFrame = scf * CF(0.6, 11.6, 0) * ANG(0, 0, rad(-6)), Color = rgb(64, 62, 86), Material = M.Basalt, CanCollide = true, Parent = f })
	CrystalKit.part({ Name = "StatueCore", Size = V(2, 2, 0.6), CFrame = scf * CF(0.6, 11.8, -2.9) * ANG(0, 0, rad(45)), Color = rgb(80, 150, 255), Material = M.Neon, Parent = f })
	CrystalKit.part({ Name = "StatueHead", Size = V(4.4, 4, 4), CFrame = scf * CF(-9, 2, -5) * ANG(rad(20), rad(30), rad(70)), Color = rgb(70, 70, 92), Material = M.Basalt, CanCollide = true, Parent = f })
	CrystalKit.part({ Name = "StatueFist", Size = V(5, 4, 5), CFrame = scf * CF(8, 2, -6) * ANG(rad(-10), rad(40), rad(15)), Color = rgb(64, 62, 86), Material = M.Basalt, CanCollide = true, Parent = f })
	CrystalKit.cluster(f, scf * CF(0.6, 14.6, 1), rng, { count = 4, h = 6, w = 1.3, styles = { "blue", "ice" }, rock = false })
	-- espigões de cristal gigantes nos dois lados da arena, junto à borda da ilha
	CrystalKit.giant(f, P(75, 214), 1.3, rng, { "blue", "sapphire", "ice" }, rgb(100, 170, 255))
	CrystalKit.giant(f, P(105, 214), 1.15, rng, { "violet", "amethyst", "blue" }, rgb(170, 120, 255))
	-- fachada de templo em ruínas atrás da arena (escadaria, colunata e frontão quebrado)
	local tp = P(90, 222)
	local tcf = facing(tp, A)
	CrystalKit.part({ Name = "TempleBase", Size = V(46, 3, 12), CFrame = tcf * CF(0, 1.5, 0), Color = rgb(120, 118, 136), Material = M.Slate, CanCollide = true, Parent = f })
	CrystalKit.stairs(f, tcf * CF(0, 0, -6 - 4.8) * ANG(0, math.pi, 0), 3, 30, 1, 1.6)
	for k = -3, 3 do
		if k ~= 0 then
			CrystalKit.column(f, (tcf * CF(k * 6.2, 3, -2)).Position, 20, 1.3, rng, math.abs(k) == 2)
		end
	end
	CrystalKit.part({ Name = "Architrave", Size = V(28, 2.4, 5), CFrame = tcf * CF(-7, 26.6, -2) * ANG(0, 0, rad(4)), Color = rgb(140, 138, 154), Material = M.Limestone, CanCollide = true, Parent = f })
	CrystalKit.wedge({ Name = "Pediment", Size = V(5, 7, 14), CFrame = tcf * CF(-12, 31.3, -2) * ANG(0, rad(90), 0), Color = rgb(150, 148, 162), Material = M.Limestone, Parent = f })
	CrystalKit.wedge({ Name = "Pediment", Size = V(5, 7, 14), CFrame = tcf * CF(2, 31.3, -2) * ANG(0, rad(-90), 0), Color = rgb(150, 148, 162), Material = M.Limestone, Parent = f })
	CrystalKit.part({ Name = "FallenArchitrave", Size = V(16, 2.4, 5), CFrame = tcf * CF(14, 4.2, -9) * ANG(rad(8), rad(20), rad(-14)), Color = rgb(130, 128, 146), Material = M.Limestone, CanCollide = true, Parent = f })
	CrystalKit.banner(f, tcf * CF(0, 3, -3), 18)
	local chest, prompt = CrystalKit.chest(f, facing(P(80, 214), A), "Relicário do Titã")
	out_.chests.titan_reliquary = { model = chest, prompt = prompt, pos = P(80, 214), title = "Relicário do Titã", region = "titans_domain" }
	-- NPC e portal (o portal fecha o circuito e volta ao vale)
	local npcModel, npcPrompt = CrystalKit.npc(f, facing(P(78, 60), C), "Mestre Vael", rgb(110, 40, 80), "violet")
	table.insert(out_.npcs, { id = "vael", model = npcModel, prompt = npcPrompt, name = "Vael", lines = {
		"O Prism Titan desperta quando alguém pisa na arena. Ele tem três fases: Ressonância, Refração e Sobrecarga.",
		"Quando o núcleo no peito dele brilhar forte, saia da área marcada no chão!",
		"A Onda de Energia é um anel: fique perto dele ou bem longe.",
	} })
	local gp = P(112, 52)
	local gate, vortex = CrystalKit.gate(f, facing(gp, C), rgb(255, 200, 120), "Crystal Valley →")
	out_.gates.titans_domain = { model = gate, part = vortex, arrival = facing(gp, C) * CF(0, 3.5, -8), from = "titans_domain" }
end

-------------------------------------------------------------------------------

function CrystalHollow.build(folder: Instance, terrainOk: boolean)
	T = terrainOk and workspace:FindFirstChildOfClass("Terrain") or nil
	if T then
		T:SetMaterialColor(M.Slate, rgb(86, 92, 116))
		T:SetMaterialColor(M.Cobblestone, rgb(128, 126, 146))
	end
	local root = Make("Folder", { Name = "CrystalHollow", Parent = folder })
	local result = { gates = {}, chests = {}, npcs = {}, walkPoints = {} }
	-- caminhos de pedra até cada região (antes da água: rio/lago cortam o que cruzarem)
	path({ P(150, 28), P(155, 45), P(160, 52) })
	path({ P(30, 28), P(36, 80), P(40, 120), P(45 - 8, 140) })
	path({ P(195, 28), P(200, 70), P(198, 120), P(195, 140) })
	path({ P(130, 28), P(135, 70), P(140, 100) })
	path({ P(105, 28), P(112, 46) })
	local builders = {
		{ "Crystal Valley", buildValley }, { "Shattered Peaks", buildPeaks }, { "Azure Caverns", buildCaverns },
		{ "Prism Lake", buildLake }, { "Titan's Domain", buildTitan }, { "Ancient Beacon", buildBeacon },
	}
	for i, b in ipairs(builders) do
		-- cada região é independente: se uma falhar, as outras continuam (e o erro é reportado)
		local ok, err = pcall(b[2], root, Random.new(2000 + i * 31), result)
		if not ok then
			warn("[CrystalHollow] falha ao construir " .. b[1] .. ": " .. tostring(err))
			result.errors = (result.errors or "") .. b[1] .. ": " .. tostring(err) .. "\n"
		end
	end
	return result
end

return CrystalHollow

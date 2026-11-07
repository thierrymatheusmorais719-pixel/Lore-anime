-- MUNDO 3 — SKYBOUND KINGDOM (inspirado na arte de referência do autor: ilhas flutuantes enormes
-- sobre um mar de nuvens, cachoeiras caindo das bordas, templos brancos e dourados, cristais azuis,
-- pontes de pedra ligando as ilhas, palácio com anéis dourados e feixe de luz).
--
-- A ilha principal (terrainFill) abriga o Cloud Harbor, a área de combate e a Tempest Arena. Em volta
-- flutuam ilhas satélites de Terrain, cada uma com silhueta própria, ligadas por pontes:
--   Cloud Harbor      ilha principal (centro)  praça, ovos, cais com navio voador, pavilhão, cachoeiras
--   Golden Heights    θ 34° (+26 studs)        palácio celestial, torres, jardins, ponte suspensa
--   Storm Islands     θ 266° (3 ilhas)         nuvens de tempestade, raios, cristais elétricos, ruínas
--   Celestial Gardens θ 160° (3 ilhas)         árvore gigante, lagos, flores, fontes, pavilhão
--   Tempest Arena     θ 90° (arena do boss)    torres destruídas, cristais elétricos, tempestade
--
-- Devolve portais, baús, NPCs, pontos de passagem e as LIGAÇÕES entre ilhas (pontes) para os testes.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local Make = require(Shared.Util.Make)
local WorldBuilder = require(script.Parent.WorldBuilder)
local CrystalKit = require(script.Parent.CrystalKit)
local SkyKit = require(script.Parent.SkyKit)

local SkyKingdom = {}

local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB
local M = Enum.Material

local W = Worlds.Info.sky
local C = W.center

local function P(theta: number, dist: number, y: number?): Vector3
	return WorldBuilder.polar(C, theta, dist) + V(0, y or 0, 0)
end
local function facing(pos: Vector3, toward: Vector3): CFrame
	local d = (toward - pos) * V(1, 0, 1)
	if d.Magnitude < 0.01 then
		d = V(0, 0, -1)
	end
	return CF(pos, pos + d)
end
local function flatDir(a: Vector3, b: Vector3): Vector3
	return ((b - a) * V(1, 0, 1)).Unit
end
local function degOf(v: Vector3): number
	return math.deg(math.atan2(v.Z, v.X))
end

local T: Terrain? = nil

-- Água encaixada no terreno de uma ilha (topo em `pos.Y`).
local function pond(pos: Vector3, r: number, depth: number?)
	if not T then
		return
	end
	local d = depth or 6
	T:FillCylinder(CF(pos - V(0, d / 2, 0)), d, r, M.Air)
	T:FillCylinder(CF(pos - V(0, 2 + (d - 2) / 2, 0)), d - 2, r, M.Water)
	T:FillCylinder(CF(pos - V(0, d + 0.5, 0)), 1.5, r, M.Sand)
end

-- Riacho até a borda + cachoeira caindo da ilha no vazio (mar de nuvens).
local function edgeFall(parent: Instance, from: Vector3, edge: Vector3, width: number, height: number)
	if T then
		local mid = (from + edge) / 2
		local look = CF(mid, mid + (edge - from) * V(1, 0, 1))
		T:FillBlock(look - V(0, 2, 0), V(width + 2, 4, (edge - from).Magnitude + 2), M.Air)
		T:FillBlock(look - V(0, 3.5, 0), V(width, 3, (edge - from).Magnitude + 2), M.Water)
		T:FillCylinder(CF(from - V(0, 2.5, 0)), 5, width * 0.9, M.Air)
		T:FillCylinder(CF(from - V(0, 3.5, 0)), 3, width * 0.8, M.Water)
	end
	local dir = flatDir(from, edge)
	WorldBuilder.waterfall(parent, edge + dir * 1.5 - V(0, 1.6, 0), height, width * 0.9, dir)
end

-- Rajadas de vento discretas (riscos brancos que atravessam a ilha).
local function wind(parent: Instance, pos: Vector3, dir: Vector3, size: number)
	local a = CrystalKit.part({ Name = "Wind", Size = V(size, size * 0.3, size), CFrame = CF(pos, pos + dir), Transparency = 1, Parent = parent })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(rgb(255, 255, 255))
	e.LightEmission = 0.2
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new(1.2, 0.4)
	e.Squash = NumberSequence.new(-2.5)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.EmissionDirection = Enum.NormalId.Front
	e.Speed = NumberRange.new(26, 38)
	e.SpreadAngle = Vector2.new(4, 8)
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Rate = 3
	e.Parent = a
end

local function sparks(parent: Instance, pos: Vector3)
	local a = CrystalKit.part({ Name = "StormSparks", Size = V(6, 8, 6), CFrame = CF(pos), Transparency = 1, Parent = parent })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(rgb(255, 255, 255), rgb(120, 220, 255))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new(0.5, 0)
	e.Lifetime = NumberRange.new(0.15, 0.35)
	e.Rate = 5
	e.Speed = NumberRange.new(4, 9)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = a
end

-- Árvores, flores e moitas variadas em cima de uma ilha (evita o centro e os pontos ocupados).
local function greenery(parent: Instance, top: Vector3, r: number, rng: Random, n: number, palette, avoid)
	local placed = 0
	for _ = 1, n * 4 do
		if placed >= n then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local d = r * rng:NextNumber(0.25, 0.8)
		local q = top + V(math.cos(a) * d, 0, math.sin(a) * d)
		local ok = true
		for _, av in ipairs(avoid or {}) do
			if ((q - av[1]) * V(1, 0, 1)).Magnitude < av[2] then
				ok = false
			end
		end
		if ok then
			placed += 1
			local k = placed % 5
			if k == 0 then
				WorldBuilder.oakTree(parent, q, rng:NextNumber(0.9, 1.3), rng, rgb(108, 80, 58), palette.leaf)
			elseif k == 1 then
				WorldBuilder.flowerBush(parent, q, rng:NextNumber(0.8, 1.1), rng, palette.flowers[rng:NextInteger(1, #palette.flowers)])
			elseif k == 2 then
				WorldBuilder.bonsai(parent, q, rng:NextNumber(0.7, 0.95), rng, palette.leaf2)
			elseif k == 3 then
				CrystalKit.scatter(parent, q, rng, palette.crystals)
			else
				WorldBuilder.rockCluster(parent, q, rng:NextNumber(0.6, 0.9), rng, rgb(214, 212, 206), M.Limestone, rgb(96, 150, 70))
			end
		end
	end
end

local function addLink(out_, a: string, b: string, pa: Vector3, pb: Vector3)
	table.insert(out_.links, { a = a, b = b, pa = pa, pb = pb })
	out_.walkPoints[a .. " ↔ " .. b .. " (início)"] = pa + V(0, 2.5, 0)
	out_.walkPoints[a .. " ↔ " .. b .. " (fim)"] = pb + V(0, 2.5, 0)
	out_.supportPoints[a .. " ↔ " .. b .. " (início)"] = pa + V(0, 2.5, 0)
	out_.supportPoints[a .. " ↔ " .. b .. " (fim)"] = pb + V(0, 2.5, 0)
end

-- Ponte entre a ilha `ia` e a ilha `ib` (pontos na borda de cada uma, voltados uma para a outra).
local function connect(parent: Instance, out_, nameA: string, ia, nameB: string, ib, rng: Random, rope: boolean?)
	local d = flatDir(ia.top, ib.top)
	local pa = ia.top + d * (ia.edge or ia.r - 4)
	local pb = ib.top - d * (ib.edge or ib.r - 4)
	if rope then
		CrystalKit.ropeBridge(parent, pa + V(0, 0.4, 0), pb + V(0, 0.4, 0), 5)
	else
		SkyKit.bridge(parent, pa, pb, 7, rng)
	end
	addLink(out_, nameA, nameB, pa, pb)
	return degOf(d), degOf(-d)
end

local function gate(parent: Instance, out_, regionId: string, pos: Vector3, toward: Vector3, color: Color3, label: string)
	local g, vortex = CrystalKit.gate(parent, facing(pos, toward), color, label)
	out_.gates[regionId] = { model = g, part = vortex, arrival = facing(pos, toward) * CF(0, 3.5, -8), from = regionId }
end

local function chest(parent: Instance, out_, id: string, pos: Vector3, toward: Vector3, title: string, region: string)
	local m, prompt = CrystalKit.chest(parent, facing(pos, toward), title)
	out_.chests[id] = { model = m, prompt = prompt, pos = pos, title = title, region = region }
end

local function npc(parent: Instance, out_, id: string, pos: Vector3, toward: Vector3, name: string, robe: Color3, style: string, lines)
	local m, prompt = CrystalKit.npc(parent, facing(pos, toward), name, robe, style)
	table.insert(out_.npcs, { id = id, model = m, prompt = prompt, name = name:match("^[^,]+"), lines = lines })
end

-------------------------------------------------------------------------------

function SkyKingdom.build(folder: Instance, terrainOk: boolean)
	T = terrainOk and workspace:FindFirstChildOfClass("Terrain") or nil
	local root = Make("Folder", { Name = "SkyKingdom", Parent = folder })
	local out_ = { gates = {}, chests = {}, npcs = {}, walkPoints = {}, supportPoints = {}, links = {}, islands = {} }
	local rng = Random.new(3303)
	local main = { top = C, r = 220, edge = 214 }
	out_.islands.main = main

	-- ILHAS SATÉLITES (topo, raio, profundidade) — cada uma com sementes e lóbulos próprios
	local defs = {
		GH = { P(34, 322, 26), 56, 74, 5, { "blue", "pearl" } },
		GH2 = { P(14, 354, 44), 22, 40, 3, { "pearl", "ice" } },
		SI1 = { P(266, 300, -8), 46, 86, 5, { "storm", "blue" } },
		SI2 = { P(292, 352, 16), 30, 66, 4, { "storm", "ice" } },
		SI3 = { P(240, 345, 6), 26, 54, 3, { "storm", "sapphire" } },
		CG1 = { P(160, 300, 8), 48, 70, 5, { "blue", "pearl" } },
		CG2 = { P(136, 336, 16), 24, 44, 3, { "pearl", "violet" } },
		CG3 = { P(184, 334, 2), 22, 40, 3, { "ice", "blue" } },
	}
	-- direções das pontes (para abrir o muro invisível de cada ilha)
	local bridges = {
		{ "main", "GH" }, { "GH", "GH2", rope = true }, { "main", "SI1" }, { "SI1", "SI2" }, { "SI1", "SI3" },
		{ "main", "CG1" }, { "CG1", "CG2" }, { "CG1", "CG3" },
	}
	local gaps = {}
	local function info(name)
		if name == "main" then
			return main
		end
		local d = defs[name]
		return { top = d[1], r = d[2] }
	end
	for _, b in ipairs(bridges) do
		local ia, ib = info(b[1]), info(b[2])
		local d = flatDir(ia.top, ib.top)
		gaps[b[1]] = gaps[b[1]] or {}
		gaps[b[2]] = gaps[b[2]] or {}
		table.insert(gaps[b[1]], degOf(d))
		table.insert(gaps[b[2]], degOf(-d))
	end
	for name, d in pairs(defs) do
		local isl = SkyKit.island(T, root, d[1], d[2], d[3], Random.new(400 + #name * 17 + math.floor(d[2])), { name = "Island_" .. name, lobes = d[4], gaps = gaps[name], styles = d[5],
			crystals = name:sub(1, 2) == "SI" and 5 or 3 })
		isl.edge = d[2] - 4
		out_.islands[name] = isl
	end
	SkyKit.undersideDetail(T, root, C, 220, rng)
	for _, b in ipairs(bridges) do
		connect(root, out_, b[1], out_.islands[b[1]], b[2], out_.islands[b[2]], rng, b.rope)
	end
	-- caminhos de pedra da praça até cada ponte e ao cais
	if T then
		for _, th in ipairs({ 40, 268, 160, 345 }) do
			local a, b = P(th, 30), P(th, 210)
			local mid = (a + b) / 2
			T:FillBlock(CF(mid - V(0, 1, 0), mid - V(0, 1, 0) + (b - a)), V(7, 2, (b - a).Magnitude), M.Cobblestone)
		end
	end
	-- mar de nuvens local: bancos macios logo abaixo das ilhas (profundidade)
	local banks = Make("Folder", { Name = "CloudBanks", Parent = root })
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		SkyKit.cloudBank(banks, C + V(math.cos(a) * rng:NextNumber(150, 380), rng:NextNumber(-130, -95), math.sin(a) * rng:NextNumber(150, 380)), rng:NextNumber(34, 60), rng)
	end

	local function region1()
		-- ===================== 1. CLOUD HARBOR (ilha principal) =====================
		local harbor = Make("Folder", { Name = "CloudHarbor", Parent = root })
		SkyKit.harbor(harbor, P(345, 212, 0), WorldBuilder.polar(V(), 345, 1), rng)
		out_.walkPoints["cais do porto"] = P(345, 230, 2.5)
		out_.supportPoints["cais (início)"] = P(345, 205, 2.5)
		SkyKit.pavilion(harbor, P(60, 72), 6, rng)
		SkyKit.statue(harbor, facing(P(300, 70), C))
		for _, th in ipairs({ 25, 200, 120 }) do
			edgeFall(harbor, P(th, 188), P(th, 219), 6, 150)
		end
		for _, th in ipairs({ 40, 160, 268, 345 }) do
			for _, d in ipairs({ 60, 120, 180 }) do
				for _, side in ipairs({ -1, 1 }) do
					local q = P(th, d) + WorldBuilder.polar(V(), th + 90, 1) * side * 5.5
					if WorldBuilder.isFree("sky", q, 1, true) then
						SkyKit.lanternPost(harbor, WorldBuilder.groundAt(q), d == 60 and side == 1)
					end
				end
			end
		end
		for i = 1, 14 do
			local q = P(rng:NextNumber(0, 360), rng:NextNumber(40, 110))
			if WorldBuilder.isFree("sky", q, 5) then
				local g = WorldBuilder.groundAt(q)
				if i % 3 == 0 then
					CrystalKit.cluster(harbor, CF(g), rng, { count = 4, h = rng:NextNumber(5, 8), w = 1.3, styles = { "blue", "pearl" } })
				else
					WorldBuilder.oakTree(harbor, g, rng:NextNumber(0.9, 1.2), rng, rgb(108, 80, 58), i % 2 == 0 and rgb(86, 160, 70) or rgb(150, 176, 72))
				end
			end
		end
		gate(harbor, out_, "cloud_harbor", P(130, 60), C, rgb(255, 214, 120), "Golden Heights →")
		chest(harbor, out_, "harbor_chest", P(52, 58), C, "Baú do Porto", "cloud_harbor")
		npc(harbor, out_, "aria", P(345, 186), C, "Capitã Aria", rgb(40, 70, 150), "blue", {
			"Bem-vinda ao Cloud Harbor! Daqui saem pontes para as Golden Heights, as Storm Islands e os Celestial Gardens.",
			"As pontes partem das bordas da ilha: siga os caminhos de pedra e as lanternas douradas.",
			"Cuidado nas Storm Islands: os raios caem perto dos cristais elétricos.",
			"O Tempest Wyrm vive na arena ao norte. Quando ele levantar voo, observe as marcas no chão!",
		})
	end
	local function region2()
		-- ===================== 2. GOLDEN HEIGHTS =====================
		local heights = Make("Folder", { Name = "GoldenHeights", Parent = root })
		local GH, GH2 = out_.islands.GH, out_.islands.GH2
		local toMain = flatDir(GH.top, C)
		local palaceAt = facing(GH.top - toMain * 8, C)
		SkyKit.palace(heights, palaceAt, rng)
		for _, side in ipairs({ -1, 1 }) do
			local right = toMain:Cross(V(0, 1, 0)) * side
			SkyKit.tower(heights, GH.top + toMain * 30 + right * 22, 30, 3, rng, false)
			SkyKit.statue(heights, facing(GH.top + toMain * 34 + right * 9, C))
			WorldBuilder.flowerBush(heights, GH.top + toMain * 22 + right * 16, 1, rng, side < 0 and rgb(255, 196, 120) or rgb(160, 190, 255))
		end
		CrystalKit.giant(heights, GH.top - toMain * 18 + toMain:Cross(V(0, 1, 0)) * 34, 0.8, rng, { "blue", "pearl" }, rgb(130, 190, 255))
		SkyKit.tower(heights, GH2.top, 34, 3.2, rng, false)
		CrystalKit.cluster(heights, CF(GH2.top + V(6, 0, 4)), rng, { count = 5, h = 8, w = 1.5, styles = { "pearl", "blue" } })
		chest(heights, out_, "heights_chest", GH2.top + V(-7, 0, 3), GH.top, "Baú das Alturas", "golden_heights")
		edgeFall(heights, GH.top + WorldBuilder.polar(V(), degOf(toMain) + 60, 1) * 36, GH.top + WorldBuilder.polar(V(), degOf(toMain) + 60, 1) * 55, 8, 200)
		gate(heights, out_, "golden_heights", GH.top + toMain * 40 + toMain:Cross(V(0, 1, 0)) * 14, GH.top, rgb(170, 140, 255), "Storm Islands →")
		npc(heights, out_, "seren", GH.top + toMain * 26 - toMain:Cross(V(0, 1, 0)) * 6, C, "Arquiteta Seren", rgb(230, 220, 200), "pearl", {
			"Este é o Palácio Celestial. Os anéis dourados giram em volta da torre há mil anos.",
			"A ponte de cordas leva à torre solitária. Lá em cima há um baú para quem não tem medo de altura.",
			"A grande cachoeira cai das Alturas até o mar de nuvens. Ninguém nunca viu o fundo.",
		})
		out_.walkPoints["escadaria do palácio"] = (palaceAt * CF(0, 0, -26)).Position + V(0, 2.5, 0)
	end
	local function region3()
		-- ===================== 3. STORM ISLANDS =====================
		local storm = Make("Folder", { Name = "StormIslands", Parent = root })
		local SI1, SI2, SI3 = out_.islands.SI1, out_.islands.SI2, out_.islands.SI3
		SkyKit.tower(storm, SI1.top + V(14, 0, -10), 26, 3, rng, true)
		SkyKit.tower(storm, SI2.top + V(-4, 0, 6), 22, 2.6, rng, true)
		CrystalKit.arch(storm, facing(SI3.top + V(4, 0, -4), SI1.top), 9, 13, 3, rng, true)
		for _, k in ipairs({ -1, 1 }) do
			CrystalKit.column(storm, SI3.top + V(k * 8, 0, 6), 12, 1, rng, true)
		end
		for _, isl in ipairs({ SI1, SI2, SI3 }) do
			for _ = 1, 2 do
				local a = rng:NextNumber(0, math.pi * 2)
				local q = isl.top + V(math.cos(a), 0, math.sin(a)) * isl.r * 0.5
				CrystalKit.cluster(storm, CF(q), rng, { count = 5, h = rng:NextNumber(7, 12), w = 1.6, styles = { "storm", "ice" }, name = "StormCrystal" })
				sparks(storm, q + V(0, 5, 0))
			end
			WorldBuilder.rockCluster(storm, isl.top + V(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)), 1.1, rng, rgb(150, 154, 170), M.Slate)
		end
		CrystalKit.giant(storm, SI1.top + V(-12, 0, 12), 0.9, rng, { "storm", "ice", "blue" }, rgb(130, 220, 255))
		-- cachoeira gigante da ilha mais alta
		local away = flatDir(C, SI2.top)
		edgeFall(storm, SI2.top + away * 10, SI2.top + away * 29, 10, 220)
		edgeFall(storm, SI1.top + flatDir(C, SI1.top) * 26, SI1.top + flatDir(C, SI1.top) * 45, 7, 180)
		-- nuvens de tempestade e origens de raios (o cliente faz os raios)
		for i = 1, 6 do
			local base = ({ SI1, SI2, SI3 })[(i - 1) % 3 + 1]
			SkyKit.stormCloud(storm, base.top + V(rng:NextNumber(-35, 35), rng:NextNumber(60, 90), rng:NextNumber(-35, 35)), rng:NextNumber(70, 110), rng)
		end
		wind(storm, SI1.top + V(0, 6, 0), flatDir(SI3.top, SI2.top), 40)
		chest(storm, out_, "storm_chest", SI3.top + V(0, 0, -6), SI1.top, "Baú da Tempestade", "storm_islands")
		local toC1 = flatDir(SI1.top, C)
		local side1 = toC1:Cross(V(0, 1, 0))
		-- portal e NPC ao lado (não em cima) do caminho que vem da ponte principal
		gate(storm, out_, "storm_islands", SI1.top + toC1 * 18 + side1 * 18, SI1.top, rgb(120, 220, 255), "Celestial Gardens →")
		npc(storm, out_, "thal", SI1.top + toC1 * 20 - side1 * 13, C, "Vigia Thal", rgb(70, 76, 110), "storm", {
			"As Storm Islands nunca dormem. Os cristais elétricos atraem os raios.",
			"Lá do alto da ilha mais alta cai a maior cachoeira do reino.",
			"Entre as ruínas da terceira ilha há um baú antigo, ainda trancado com magia de tempestade.",
		})
	end
	local function region4()
		-- ===================== 4. CELESTIAL GARDENS =====================
		local gardens = Make("Folder", { Name = "CelestialGardens", Parent = root })
		local CG1, CG2, CG3 = out_.islands.CG1, out_.islands.CG2, out_.islands.CG3
		local treeAt = CG1.top + flatDir(C, CG1.top) * 14
		WorldBuilder.oakTree(gardens, treeAt, 2.6, rng, rgb(118, 86, 60), rgb(96, 176, 76))
		local lake = CG1.top - flatDir(C, CG1.top) * 6 + flatDir(CG1.top, CG2.top):Cross(V(0, 1, 0)) * 16
		pond(lake, 10, 6)
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			CrystalKit.scatter(gardens, lake + V(math.cos(a), 0, math.sin(a)) * 12, rng, { "blue", "pearl" })
		end
		local flowerPal = { rgb(255, 150, 190), rgb(255, 214, 110), rgb(170, 140, 255), rgb(255, 255, 255), rgb(120, 200, 255) }
		greenery(gardens, CG1.top, CG1.r, rng, 12, { leaf = rgb(86, 168, 72), leaf2 = rgb(190, 140, 230), flowers = flowerPal, crystals = { "pearl", "blue" } },
			{ { treeAt, 14 }, { lake, 14 }, { CG1.top, 8 } })
		SkyKit.fountain(gardens, CG2.top)
		greenery(gardens, CG2.top, CG2.r, rng, 5, { leaf = rgb(120, 180, 80), leaf2 = rgb(255, 170, 200), flowers = flowerPal, crystals = { "pearl" } }, { { CG2.top, 8 } })
		SkyKit.pavilion(gardens, CG3.top + V(0, 0, 0), 5, rng)
		pond(CG3.top + V(10, 0, -6), 5, 5)
		edgeFall(gardens, CG3.top + flatDir(CG1.top, CG3.top) * 6 + V(6, 0, 0), CG3.top + flatDir(CG1.top, CG3.top) * 21, 5, 150)
		chest(gardens, out_, "gardens_chest", treeAt + flatDir(CG1.top, CG3.top) * 9 + flatDir(C, CG1.top) * 4, C, "Baú da Árvore Celeste", "celestial_gardens")
		gate(gardens, out_, "celestial_gardens", CG1.top + flatDir(CG1.top, C) * 24 + flatDir(CG1.top, CG2.top) * 14, CG1.top, rgb(150, 255, 190), "Tempest Arena →")
		npc(gardens, out_, "lumi", CG1.top + flatDir(CG1.top, C) * 30 - flatDir(CG1.top, CG2.top) * 8, C, "Jardineira Lumi", rgb(80, 140, 90), "pearl", {
			"Os Jardins Celestes são cuidados pelos ventos: cada flor nasceu de uma semente trazida pelas nuvens.",
			"A árvore gigante tem raízes que descem até o mar de nuvens. Há um baú escondido sob a copa dela.",
			"Atravesse as pontes para ver a fonte dourada e o pavilhão do lago.",
		})
		out_.walkPoints["sob a árvore gigante"] = treeAt + flatDir(CG1.top, CG3.top) * 9 - flatDir(C, CG1.top) * 4 + V(0, 2.5, 0)
	end
	local function region5()
		-- ===================== 5. TEMPEST ARENA =====================
		local arena = Make("Folder", { Name = "TempestArena", Parent = root })
		local L = WorldBuilder.Layout
		local A = P(L.arena.theta, L.arena.dist)
		for _, off in ipairs({ V(90, 0, 0), V(-90, 0, 0), V(63, 0, 64), V(-63, 0, 64) }) do
			local q = A + off
			SkyKit.tower(arena, q, rng:NextNumber(30, 40), 3.4, rng, true)
			sparks(arena, q + V(0, 10, 0))
		end
		for _, off in ipairs({ V(80, 0, -30), V(-80, 0, -30), V(34, 0, 68), V(-34, 0, 68) }) do
			CrystalKit.cluster(arena, CF(A + off), rng, { count = 5, h = rng:NextNumber(9, 14), w = 1.8, styles = { "storm", "ice" }, name = "StormCrystal" })
		end
		for i = 1, 4 do
			local a = i / 4 * math.pi * 2 + 0.4
			SkyKit.stormCloud(arena, A + V(math.cos(a) * 80, rng:NextNumber(85, 105), math.sin(a) * 80), rng:NextNumber(80, 120), rng)
		end
		wind(arena, A + V(0, 8, 0), V(1, 0, 0.3).Unit, 60)
		gate(arena, out_, "tempest_arena", P(65, 58), A, rgb(255, 200, 120), "Cloud Harbor →")
		chest(arena, out_, "arena_chest", A + V(-70, 0, 50), C, "Relicário da Tempestade", "tempest_arena")
	end
	-- cada região é construída separadamente: se uma falhar, as outras continuam (erro reportado)
	for _, step in ipairs({ { "Cloud Harbor", region1 }, { "Golden Heights", region2 }, { "Storm Islands", region3 }, { "Celestial Gardens", region4 }, { "Tempest Arena", region5 } }) do
		local ok, err = pcall(step[2])
		if not ok then
			warn("[SkyKingdom] falha ao construir " .. step[1] .. ": " .. tostring(err))
			out_.errors = (out_.errors or "") .. step[1] .. ": " .. tostring(err) .. "\n"
		end
	end
	return out_
end

return SkyKingdom

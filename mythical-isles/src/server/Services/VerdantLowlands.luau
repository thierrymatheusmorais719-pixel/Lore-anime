-- TERRAS BAIXAS do Verdant Haven (Mundo 1): a ilha original virou um PLANALTO, cercado por terras
-- 24 studs abaixo que quase dobram o raio do mundo (345 → 640, ~3× a área). Desce-se por rampas de terra.
--
--   * Rio Cristalino: as duas cachoeiras do planalto caem num rio que corre até a borda e despenca da ilha
--   * Ruínas de Eldermoor: muralhas quebradas, colunata, templo em cima de um estrado e uma CRIPTA
--     subterrânea por baixo (escada que desce), com baú no altar e baú na cripta
--   * Torre de Vigia Caída: torre redonda em ruínas com escada em espiral até o topo (baú lá em cima)
--   * Círculo das Runas: monólitos com runas acesas e um altar
--   * Pântano Brumoso: poças, lama, árvores secas, cogumelos que brilham e um baú numa ilhota
--   * Cavernas Esmeralda: túnel que desce do chão para três salões subterrâneos escavados no Terrain,
--     com cristais e cogumelos que brilham, estalactites, um lago subterrâneo e um baú no fundo,
--     e uma segunda saída
--   * bosques espalhados pelas terras baixas
-- Os baús usam o mesmo sistema dos baús-santuário (RegionService.claim, recompensa Drops.Shrine).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local Regions = require(Shared.Config.Regions)
local Make = require(Shared.Util.Make)

local VerdantLowlands = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB

local STONE, STONE_D, STONE_L = rgb(150, 146, 136), rgb(108, 104, 98), rgb(184, 178, 166)
local MOSS, MOSS2, VINE = rgb(96, 160, 64), rgb(70, 130, 52), rgb(62, 118, 46)
local RUNE, CAVE_GLOW, MUSH = rgb(150, 255, 140), rgb(80, 255, 170), rgb(120, 220, 255)
local ACCENT = rgb(150, 255, 140)

-- Lugares (θ em graus, distância do centro). Usados também por Regions (nomes na tela).
VerdantLowlands.Places = {
	eldermoor = { theta = 215, dist = 505 },
	watchtower = { theta = 35, dist = 525 },
	runes = { theta = 270, dist = 548 },
	swamp = { theta = 322, dist = 478 },
	caveIn = { theta = 82, dist = 548 }, -- boca da caverna (entrada)
	caveOut = { theta = 55, dist = 418 }, -- segunda saída
	ramps = { 10, 195, 245, 300 }, -- rampas do planalto para as terras baixas
	river = { 122, 160 }, -- cachoeiras do planalto (Layout.verdantLake ± 18/20)
	riverMouth = 141, -- onde o rio despenca da ilha
}
local PL = VerdantLowlands.Places

-- Salões da caverna (θ, dist, y relativo ao centro da ilha, raio)
VerdantLowlands.Cave = {
	halls = { { theta = 80, dist = 505, y = -47, r = 15 }, { theta = 72, dist = 478, y = -49, r = 17 }, { theta = 63, dist = 452, y = -47, r = 14 } },
}

local function part(props)
	props.Anchored = true
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	if props.Material == nil then
		props.Material = Enum.Material.Slate
	end
	return Make("Part", props)
end

local function polar(theta: number, dist: number, y: number?): Vector3
	local w = Worlds.Info.verdant
	local r = rad(theta)
	return w.center + V(math.cos(r) * dist, y or 0, math.sin(r) * dist)
end
VerdantLowlands.polar = polar

-- Altura do chão das terras baixas (y absoluto)
local function lowY(): number
	local w = Worlds.Info.verdant
	return w.center.Y - (w.lowlands and w.lowlands.drop or 24)
end
VerdantLowlands.groundY = lowY

local function flatDist(a: Vector3, b: Vector3): number
	return ((a - b) * V(1, 0, 1)).Magnitude
end

-------------------------------------------------------------------------------
-- Terreno: chamado por WorldBuilder.terrainFill ANTES do chão do planalto
-------------------------------------------------------------------------------

function VerdantLowlands.terrain(T: Terrain, w, ground: Enum.Material, cliff: Enum.Material)
	local c = w.center
	local R2 = w.lowlands.radius
	local y0 = -w.lowlands.drop
	-- corpo da ilha baixa: chão de grama e camadas de rocha que afinam para baixo
	T:FillCylinder(CF(c + V(0, y0 - 6, 0)), 12, R2, ground)
	T:FillCylinder(CF(c + V(0, y0 - 26, 0)), 28, R2 * 0.93, cliff)
	T:FillCylinder(CF(c + V(0, y0 - 50, 0)), 20, R2 * 0.76, cliff)
	T:FillCylinder(CF(c + V(0, y0 - 68, 0)), 16, R2 * 0.56, cliff)
	T:FillCylinder(CF(c + V(0, y0 - 82, 0)), 12, R2 * 0.38, cliff)
	T:FillBall(c + V(0, y0 - 104, 0), 60, cliff) -- ponta de baixo (o topo fica bem abaixo do chão)
	local lump = Random.new(9311)
	for i = 1, 44 do
		local theta = i * (360 / 44) + lump:NextNumber(-3, 3)
		local depth = lump:NextNumber(6, 70)
		local rr = lump:NextNumber(10, 20)
		T:FillBall(polar(theta, R2 * (1 - depth / 95) * lump:NextNumber(0.88, 0.97), y0 - math.max(depth, 4 + rr)), rr, cliff)
	end
	-- paredão do planalto (a borda da ilha original vira um penhasco de 24 studs)
	T:FillCylinder(CF(c + V(0, (y0 - 1) / 2, 0)), -y0 - 1, w.radius + 1.5, cliff) -- até 1 stud abaixo do topo (a grama do planalto cobre)
	-- morrinhos nas terras baixas, longe dos lugares construídos
	local rng = Random.new(5151)
	for i = 1, 16 do
		local theta = i * 22.5 + rng:NextNumber(-6, 6)
		local d = rng:NextNumber(R2 - 40, R2 - 18)
		local pos = polar(theta, d, y0 - 8)
		local hr = rng:NextNumber(12, 17)
		if not Regions.isReserved("verdant", pos, hr) then
			T:FillBall(pos, hr, i % 4 == 0 and cliff or ground)
		end
	end
end

-- Rampas, rio e escavações (depois do chão do planalto, para cortar o paredão)
local function carve(T: Terrain, w, ground: Enum.Material)
	local y0 = -w.lowlands.drop
	local path = Enum.Material.Ground
	-- RAMPAS de terra do planalto até as terras baixas (inclinação ~17°)
	for _, th in ipairs(PL.ramps) do
		local a = polar(th, w.radius - 6, 0)
		local b = polar(th, w.radius + 74, y0)
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b) * CF(0, -3, 0)
		T:FillBlock(cf, V(14, 6, (b - a).Magnitude + 2), path)
		-- abre o paredão em volta da rampa (sem o "dente" de rocha nas laterais)
		T:FillBlock(CFrame.lookAt(mid, b) * CF(0, 6, 0), V(18, 12, (b - a).Magnitude - 6), Enum.Material.Air)
		T:FillBlock(cf, V(14, 6, (b - a).Magnitude + 2), path)
	end
	-- RIO: as duas cachoeiras caem em poços que se juntam e correm até a borda
	local mouth = polar(PL.riverMouth, w.lowlands.radius - 2, y0)
	local join = polar(PL.riverMouth, w.radius + 70, y0)
	local function channel(p0: Vector3, p1: Vector3, width: number)
		local mid = (p0 + p1) / 2
		local len = (p1 - p0).Magnitude
		T:FillBlock(CFrame.lookAt(mid, p1) * CF(0, -2, 0), V(width + 4, 4, len + 4), ground)
		T:FillBlock(CFrame.lookAt(mid, p1) * CF(0, -1.6, 0), V(width, 3.2, len + 2), Enum.Material.Water)
	end
	for _, th in ipairs(PL.river) do
		local fall = polar(th, w.radius + 6, y0)
		T:FillCylinder(CF(fall + V(0, -1.6, 0)), 3.2, 9, Enum.Material.Water)
		channel(fall, join, 8)
	end
	channel(join, mouth, 10)
	-- TRILHAS de terra: anel pelas terras baixas, descida de cada rampa e ramais até cada lugar
	local Rt = 492
	local function pave(a: Vector3, b: Vector3)
		local mid = (a + b) / 2
		T:FillBlock(CFrame.lookAt(mid - V(0, 1, 0), b - V(0, 1, 0)), V(6, 2, (b - a).Magnitude + 2), path)
	end
	local prev = polar(0, Rt, y0)
	for deg = 5, 360, 5 do
		local q = polar(deg, Rt + math.sin(rad(deg) * 4) * 10, y0)
		local diffMouth = math.abs((deg - PL.riverMouth + 180) % 360 - 180)
		if diffMouth > 4 then -- o rio corta a trilha (atravessa pela ponte)
			pave(prev, q)
		end
		prev = q
	end
	for _, th in ipairs(PL.ramps) do
		pave(polar(th, w.radius + 74, y0), polar(th, Rt + math.sin(rad(th) * 4) * 10, y0))
	end
	for _, key in ipairs({ "eldermoor", "watchtower", "runes", "swamp" }) do
		local P = PL[key]
		pave(polar(P.theta, Rt + math.sin(rad(P.theta) * 4) * 10, y0), polar(P.theta, P.dist + (P.dist > Rt and -30 or 30), y0))
	end
	pave(polar(PL.caveIn.theta, Rt + math.sin(rad(PL.caveIn.theta) * 4) * 10, y0), polar(PL.caveIn.theta, PL.caveIn.dist - 8, y0))
	-- colinas suaves e manchas de capim alto pelo meio das terras baixas
	local hr = Random.new(7123)
	for i = 1, 26 do
		local th = i * (360 / 26) + hr:NextNumber(-6, 6)
		local d = hr:NextNumber(w.radius + 40, w.lowlands.radius - 50)
		local pos = polar(th, d, y0 - hr:NextNumber(9, 12))
		local r = hr:NextNumber(11, 18)
		local near = false
		for _, key in ipairs({ "eldermoor", "watchtower", "runes", "swamp", "caveIn", "caveOut" }) do
			if flatDist(pos, polar(PL[key].theta, PL[key].dist)) < (key == "eldermoor" and 70 or 45) + r then
				near = true
			end
		end
		if math.abs((th - PL.riverMouth + 180) % 360 - 180) < 26 and d < w.radius + 100 or math.abs((th - PL.riverMouth + 180) % 360 - 180) < 6 then
			near = true
		end
		for _, rth in ipairs(PL.ramps) do
			if math.abs((th - rth + 180) % 360 - 180) < 8 then
				near = true
			end
		end
		if math.abs(d - Rt) < r + 6 then
			near = true -- não cobre a trilha
		end
		if not near then
			T:FillBall(pos, r, ground)
		end
		local md = hr:NextNumber(w.radius + 30, w.lowlands.radius - 30)
		local mr = hr:NextNumber(8, 16)
		if math.abs(md - Rt) > mr + 8 then -- capim alto fora da trilha
			T:FillCylinder(CF(polar(th + 7, md, y0 - 0.5)), 1.2, mr, Enum.Material.LeafyGrass)
		end
	end
	-- CAVERNAS: salões e túneis (Air) dentro do corpo de rocha das terras baixas
	local halls = VerdantLowlands.Cave.halls
	local function tunnel(p0: Vector3, p1: Vector3, r: number)
		local n = math.max(2, math.ceil((p1 - p0).Magnitude / (r * 0.6)))
		for k = 0, n do
			T:FillBall(p0:Lerp(p1, k / n), r, Enum.Material.Air)
		end
	end
	local entrance = polar(PL.caveIn.theta, PL.caveIn.dist, y0 + 2)
	local exit = polar(PL.caveOut.theta, PL.caveOut.dist, y0 + 2)
	local hp = {}
	for i, h in ipairs(halls) do
		hp[i] = polar(h.theta, h.dist, h.y)
	end
	tunnel(entrance, hp[1] + V(0, 2, 0), 7)
	for i, h in ipairs(halls) do
		T:FillBall(hp[i], h.r, Enum.Material.Air)
		-- chão do salão plano o bastante para andar (pedra nivelada no fundo)
		T:FillCylinder(CF(hp[i] - V(0, h.r * 0.78, 0)), 2, h.r * 0.7, Enum.Material.Slate)
		if i > 1 then
			tunnel(hp[i - 1], hp[i], 7)
		end
	end
	tunnel(hp[#hp] + V(0, 2, 0), exit, 6.5)
	-- lago subterrâneo no salão do meio
	T:FillCylinder(CF(hp[2] - V(0, halls[2].r * 0.78 - 1.2, 0) + (hp[3] - hp[2]).Unit * 5), 1.6, 6, Enum.Material.Water)
	-- CRIPTA de Eldermoor (sala escavada embaixo do templo, a escada desce até ela)
	local crypt = polar(PL.eldermoor.theta, PL.eldermoor.dist + 14, y0 - 9)
	T:FillBlock(CF(crypt), V(18, 9, 18), Enum.Material.Air)
	return { entrance = entrance, exit = exit, halls = hp, crypt = crypt }
end

-------------------------------------------------------------------------------
-- Peças: ruínas, torre, runas, pântano e caverna
-------------------------------------------------------------------------------

local function mossTop(parent, p: BasePart, rng: Random)
	if rng:NextNumber() < 0.55 then
		part({ Name = "Moss", Size = V(p.Size.X * 0.9, 0.3, p.Size.Z * 0.85), CFrame = p.CFrame * CF(0, p.Size.Y / 2, 0), Color = rng:NextNumber() < 0.5 and MOSS or MOSS2,
			Material = Enum.Material.LeafyGrass, CanCollide = false, Parent = parent })
	end
end

local function vine(parent, top: Vector3, len: number, rng: Random)
	part({ Name = "Vine", Size = V(0.3, len, 0.3), CFrame = CF(top - V(0, len / 2, 0)) * ANG(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.12, 0.12)), Color = VINE,
		Material = Enum.Material.Grass, CanCollide = false, CastShadow = false, Parent = parent })
end

-- muro quebrado entre dois pontos (blocos de altura variável, alguns caídos)
local function brokenWall(parent, a: Vector3, b: Vector3, h: number, rng: Random)
	local dir = (b - a) * V(1, 0, 1)
	local len = dir.Magnitude
	local n = math.max(1, math.floor(len / 6))
	for k = 0, n - 1 do
		if rng:NextNumber() > 0.15 then -- buracos no muro
			local p = a + dir * ((k + 0.5) / n)
			local hh = h * rng:NextNumber(0.35, 1)
			local blk = part({ Name = "RuinWall", Size = V(3, hh, len / n + 0.2), CFrame = CF(p + V(0, hh / 2, 0)) * CFrame.lookAt(Vector3.zero, dir),
				Color = (k % 3 == 0) and STONE_D or STONE, Parent = parent })
			mossTop(parent, blk, rng)
			if rng:NextNumber() < 0.25 then
				vine(parent, p + V(0, hh, 0) + dir.Unit:Cross(V(0, 1, 0)) * 1.6, hh * 0.7, rng)
			end
		elseif rng:NextNumber() < 0.6 then
			-- bloco caído no chão
			local p = a + dir * ((k + 0.5) / n) + dir.Unit:Cross(V(0, 1, 0)) * rng:NextNumber(-5, 5)
			part({ Name = "Rubble", Size = V(3, 2.2, 4), CFrame = CF(p + V(0, 0.9, 0)) * ANG(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
				Color = STONE_D, Parent = parent })
		end
	end
end

local function column(parent, base: Vector3, h: number, rng: Random, fallen: boolean)
	if fallen then
		local a = rng:NextNumber(0, 6.28)
		part({ Name = "FallenColumn", Shape = Enum.PartType.Cylinder, Size = V(h, 2.6, 2.6), CFrame = CF(base + V(0, 1.2, 0)) * ANG(0, a, 0), Color = STONE_L, Parent = parent })
		return
	end
	part({ Name = "ColumnBase", Size = V(3.6, 1, 3.6), CFrame = CF(base + V(0, 0.5, 0)), Color = STONE_D, Parent = parent })
	part({ Name = "Column", Shape = Enum.PartType.Cylinder, Size = V(h, 2.4, 2.4), CFrame = CF(base + V(0, 1 + h / 2, 0)) * ANG(0, 0, rad(90)), Color = STONE_L, Parent = parent })
	local cap = part({ Name = "ColumnCap", Size = V(3.4, 0.9, 3.4), CFrame = CF(base + V(0, 1.45 + h, 0)) * ANG(0, 0, rng:NextNumber(-0.05, 0.05)), Color = STONE, Parent = parent })
	mossTop(parent, cap, rng)
end

local function lantern(parent, pos: Vector3, color: Color3)
	part({ Name = "LanternPost", Size = V(0.5, 4, 0.5), CFrame = CF(pos + V(0, 2, 0)), Color = rgb(70, 52, 40), Material = Enum.Material.Wood, Parent = parent })
	local glow = part({ Name = "LanternGlow", Size = V(1.1, 1.1, 1.1), CFrame = CF(pos + V(0, 4.4, 0)), Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	Make("PointLight", { Color = color, Range = 16, Brightness = 1.4, Parent = glow })
end

-- Ruínas de Eldermoor: pátio murado, colunata, templo num estrado, escada para a cripta
local function eldermoor(parent, chest, rng: Random, out, cave)
	local f = Make("Folder", { Name = "Eldermoor", Parent = parent })
	local c = polar(PL.eldermoor.theta, PL.eldermoor.dist, lowY() - Worlds.Info.verdant.center.Y)
	local inward = ((Worlds.Info.verdant.center - c) * V(1, 0, 1)).Unit
	local side = inward:Cross(V(0, 1, 0))
	local H = 36
	local corners = { c + inward * H + side * H, c - inward * H + side * H, c - inward * H - side * H, c + inward * H - side * H }
	-- portão voltado para o centro da ilha (abertura no meio do muro de frente)
	brokenWall(f, corners[4], c + inward * H - side * 7, 13, rng)
	brokenWall(f, c + inward * H + side * 7, corners[1], 13, rng)
	brokenWall(f, corners[1], corners[2], 13, rng)
	brokenWall(f, corners[2], corners[3], 13, rng)
	brokenWall(f, corners[3], corners[4], 13, rng)
	for _, s in ipairs({ -1, 1 }) do
		local gp = c + inward * H + side * 7 * s
		part({ Name = "GatePillar", Size = V(4, 16, 4), CFrame = CF(gp + V(0, 8, 0)), Color = STONE_D, Parent = f })
	end
	local lintel = part({ Name = "GateLintel", Size = V(18, 2.6, 4.4), CFrame = CFrame.lookAt(c + inward * H + V(0, 17.2, 0), c + inward * H + V(0, 17.2, 0) + side) * ANG(0, rad(90), rad(4)),
		Color = STONE, Parent = f })
	mossTop(f, lintel, rng)
	-- colunata do portão até o templo
	for k = 1, 4 do
		for _, s in ipairs({ -1, 1 }) do
			local base = c + inward * (H - 6 - k * 6.5) + side * 6 * s
			column(f, base, 9 + rng:NextNumber(-3, 1), rng, rng:NextNumber() < 0.25)
		end
	end
	-- templo: estrado com degraus, 8 colunas, laje do teto quebrada, altar e baú
	local plat = c - inward * 6
	part({ Name = "TempleStep", Size = V(26, 1.2, 26), CFrame = CFrame.lookAt(plat + V(0, 0.6, 0), plat + V(0, 0.6, 0) + inward), Color = STONE_D, Parent = f })
	part({ Name = "TempleFloor", Size = V(22, 2.4, 22), CFrame = CFrame.lookAt(plat + V(0, 1.2, 0), plat + V(0, 1.2, 0) + inward), Color = STONE, Parent = f })
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local base = plat + (inward * math.cos(a) + side * math.sin(a)) * 9 + V(0, 2.4, 0)
		column(f, base, k % 3 == 0 and 5 or 11, rng, false)
	end
	local roof = part({ Name = "TempleRoofSlab", Size = V(16, 1.6, 22), CFrame = CFrame.lookAt(plat + V(2, 15.4, 0), plat + V(2, 15.4, 0) + inward) * ANG(0, 0, rad(9)), Color = STONE_L, Parent = f })
	mossTop(f, roof, rng)
	part({ Name = "Altar", Size = V(5, 3, 3), CFrame = CFrame.lookAt(plat + V(0, 3.9, 0), plat + V(0, 3.9, 0) + inward), Color = STONE_D, Parent = f })
	local glow = part({ Name = "AltarRune", Size = V(4, 0.2, 2), CFrame = CFrame.lookAt(plat + V(0, 5.5, 0), plat + V(0, 5.5, 0) + inward), Color = RUNE, Material = Enum.Material.Neon,
		CanCollide = false, Parent = f })
	Make("PointLight", { Color = RUNE, Range = 14, Brightness = 1.2, Parent = glow })
	local altarChest = plat + inward * 3.6 + V(0, 2.4, 0)
	out.chests.verdant_low_eldermoor = chest(f, CF(altarChest, altarChest + inward), "Relicário de Eldermoor")
	-- escada até a cripta (degraus de pedra descendo pelo buraco escavado)
	local crypt = cave.crypt
	local top = c + side * 18 + inward * 10
	local toCrypt = ((crypt - top) * V(1, 0, 1)).Unit
	for k = 0, 9 do
		local p = top + toCrypt * (k * 1.6) + V(0, -k * 0.9 + 0.3, 0)
		part({ Name = "CryptStep", Size = V(5, 0.8, 1.8), CFrame = CFrame.lookAt(p, p + toCrypt), Color = STONE_D, Parent = f })
	end
	part({ Name = "CryptArch", Size = V(7, 1.4, 1.4), CFrame = CFrame.lookAt(top + V(0, 6, 0), top + V(0, 6, 0) + side), Color = STONE, Parent = f })
	for _, s in ipairs({ -1, 1 }) do
		part({ Name = "CryptArchPost", Size = V(1.4, 6, 1.4), CFrame = CF(top + toCrypt:Cross(V(0, 1, 0)) * 3 * s + V(0, 3, 0)), Color = STONE, Parent = f })
	end
	-- dentro da cripta: chão, sarcófago, tochas e o baú
	part({ Name = "CryptFloor", Size = V(16, 1, 16), CFrame = CF(crypt - V(0, 4.5, 0)), Color = STONE_D, Parent = f })
	part({ Name = "Sarcophagus", Size = V(3.4, 2.6, 7), CFrame = CF(crypt - V(0, 2.7, 0) - toCrypt * 3) * CFrame.lookAt(Vector3.zero, toCrypt), Color = STONE_L, Parent = f })
	for _, s in ipairs({ -1, 1 }) do
		local tp = crypt + toCrypt:Cross(V(0, 1, 0)) * 7 * s - V(0, 1, 0)
		local torch = part({ Name = "CryptTorch", Size = V(0.6, 0.6, 0.6), CFrame = CF(tp), Color = rgb(255, 170, 80), Material = Enum.Material.Neon, CanCollide = false, Parent = f })
		Make("PointLight", { Color = rgb(255, 170, 90), Range = 14, Brightness = 1.6, Parent = torch })
	end
	local cc = crypt - V(0, 4, 0) + toCrypt * 4
	out.chests.verdant_low_crypt = chest(f, CF(cc, cc - toCrypt), "Tesouro da Cripta")
	out.walkPoints["Ruínas de Eldermoor"] = c + inward * (H + 6) + V(0, 3, 0)
	return f
end

-- Torre de Vigia Caída: anel de muro em andares (com buracos), escada em espiral até o topo
local function watchtower(parent, chest, rng: Random, out)
	local f = Make("Folder", { Name = "Watchtower", Parent = parent })
	local c = polar(PL.watchtower.theta, PL.watchtower.dist, lowY() - Worlds.Info.verdant.center.Y)
	local R, floors = 7, 5
	for fl = 0, floors - 1 do
		for k = 0, 11 do
			local missing = (fl >= 2 and (k + fl) % 5 == 0) or (fl == floors - 1 and k % 3 == 1)
			if not missing and not (fl == 0 and k == 0) then -- porta no térreo
				local a = (k + 0.5) / 12 * math.pi * 2
				local p = c + V(math.cos(a) * R, fl * 6 + 3, math.sin(a) * R)
				local blk = part({ Name = "TowerWall", Size = V(1.6, 6, 2 * math.pi * R / 12 + 0.5), CFrame = CF(p) * ANG(0, -a, 0), Color = (fl + k) % 2 == 0 and STONE or STONE_D, Parent = f })
				if fl == floors - 1 then
					mossTop(f, blk, rng)
				end
			end
		end
	end
	-- escada em espiral (degraus presos na parede) e plataforma no topo
	local steps = 40
	for k = 0, steps - 1 do
		local a = k / 12 * math.pi * 2 + 0.6
		local y = 0.5 + k * (floors * 6 - 1.5) / steps
		local p = c + V(math.cos(a) * (R - 2.4), y, math.sin(a) * (R - 2.4))
		part({ Name = "TowerStep", Size = V(3.6, 0.6, 2.4), CFrame = CF(p) * ANG(0, -a, 0), Color = rgb(116, 84, 60), Material = Enum.Material.WoodPlanks, Parent = f })
	end
	local topY = floors * 6 - 1
	part({ Name = "TowerTop", Shape = Enum.PartType.Cylinder, Size = V(1, R * 1.4, R * 1.4), CFrame = CF(c + V(0, topY, 0)) * ANG(0, 0, rad(90)), Color = rgb(116, 84, 60),
		Material = Enum.Material.WoodPlanks, Parent = f })
	local tc = c + V(0, topY + 0.5, 0)
	out.chests.verdant_low_tower = chest(f, CF(tc, tc + V(1, 0, 0)), "Baú da Torre de Vigia")
	lantern(f, c + V(R - 2, topY + 0.5, 0), rgb(255, 210, 120))
	-- pedaços de muro caídos em volta
	for k = 1, 6 do
		local a = rng:NextNumber(0, 6.28)
		local p = c + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(R + 3, R + 12)
		part({ Name = "Rubble", Size = V(2.6, 2, 3.4), CFrame = CF(p + V(0, 0.8, 0)) * ANG(rng:NextNumber(-0.4, 0.4), a, rng:NextNumber(-0.4, 0.4)), Color = STONE_D, Parent = f })
	end
	out.walkPoints["Torre de Vigia Caída"] = c + V(R + 6, 3, 0)
	return f
end

-- Círculo das Runas: 12 monólitos (alguns com lintel), runas acesas, altar central
local function runeCircle(parent, chest, rng: Random, out)
	local f = Make("Folder", { Name = "RuneCircle", Parent = parent })
	local c = polar(PL.runes.theta, PL.runes.dist, lowY() - Worlds.Info.verdant.center.Y)
	local R = 17
	local tops = {}
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local p = c + V(math.cos(a) * R, 0, math.sin(a) * R)
		local h = (k % 3 == 1) and 6 or rng:NextNumber(9, 12)
		local m = part({ Name = "Monolith", Size = V(2.6, h, 3.6), CFrame = CF(p + V(0, h / 2 - 0.5, 0)) * ANG(0, -a, rng:NextNumber(-0.06, 0.06)), Color = STONE, Parent = f })
		mossTop(f, m, rng)
		local rune = part({ Name = "Rune", Size = V(0.2, h * 0.45, 1.2), CFrame = m.CFrame * CF(-1.35, 0, 0), Color = RUNE, Material = Enum.Material.Neon, CanCollide = false, Parent = f })
		if k % 4 == 0 then
			Make("PointLight", { Color = RUNE, Range = 12, Brightness = 1, Parent = rune })
		end
		tops[k] = p + V(0, h, 0)
	end
	for k = 0, 11, 3 do
		local a, b = tops[k], tops[(k + 1) % 12]
		if a.Y > c.Y + 8 and b.Y > c.Y + 8 then
			local mid = (a + b) / 2
			part({ Name = "Lintel", Size = V(2.6, 1.6, (b - a).Magnitude + 2), CFrame = CFrame.lookAt(mid + V(0, 0.8, 0), b + V(0, 0.8, 0)), Color = STONE_L, Parent = f })
		end
	end
	part({ Name = "RuneAltar", Shape = Enum.PartType.Cylinder, Size = V(2, 9, 9), CFrame = CF(c + V(0, 1, 0)) * ANG(0, 0, rad(90)), Color = STONE_D, Parent = f })
	local ring = part({ Name = "RuneRing", Shape = Enum.PartType.Cylinder, Size = V(0.2, 8, 8), CFrame = CF(c + V(0, 2.1, 0)) * ANG(0, 0, rad(90)), Color = RUNE, Material = Enum.Material.Neon,
		Transparency = 0.4, CanCollide = false, Parent = f })
	Make("PointLight", { Color = RUNE, Range = 18, Brightness = 1.4, Parent = ring })
	local cc = c + V(0, 2, 0)
	out.chests.verdant_low_runes = chest(f, CF(cc, cc + V(0, 0, 1)), "Oferenda das Runas")
	out.walkPoints["Círculo das Runas"] = c + V(R + 6, 3, 0)
	return f
end

-- Pântano Brumoso: poças, lama, árvores secas, cogumelos que brilham, baú numa ilhota
local function swamp(parent, chest, rng: Random, out, T: Terrain?)
	local f = Make("Folder", { Name = "Swamp", Parent = parent })
	local c = polar(PL.swamp.theta, PL.swamp.dist, lowY() - Worlds.Info.verdant.center.Y)
	if T then
		for k = 1, 7 do
			local a = k / 7 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local p = c + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(10, 34)
			T:FillCylinder(CF(p - V(0, 1, 0)), 2, rng:NextNumber(6, 11), Enum.Material.Mud)
			T:FillCylinder(CF(p - V(0, 0.8, 0)), 1.4, rng:NextNumber(4, 8), Enum.Material.Water)
		end
	end
	for k = 1, 9 do
		local a = rng:NextNumber(0, 6.28)
		local p = c + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(14, 44)
		-- árvore seca: tronco torto e dois galhos nus
		local h = rng:NextNumber(9, 14)
		local trunk = part({ Name = "DeadTrunk", Size = V(1.4, h, 1.4), CFrame = CF(p + V(0, h / 2, 0)) * ANG(rng:NextNumber(-0.15, 0.15), a, rng:NextNumber(-0.15, 0.15)),
			Color = rgb(78, 66, 58), Material = Enum.Material.Wood, Parent = f })
		for _, s in ipairs({ -1, 1 }) do
			part({ Name = "DeadBranch", Size = V(0.6, h * 0.4, 0.6), CFrame = trunk.CFrame * CF(0, h * 0.25, 0) * ANG(0, 0, rad(40 * s)) * CF(0, h * 0.2, 0),
				Color = rgb(78, 66, 58), Material = Enum.Material.Wood, Parent = f })
		end
		vine(f, trunk.Position + V(0, h * 0.4, 0) + V(0.8, 0, 0), h * 0.5, rng)
	end
	for k = 1, 10 do
		local a = rng:NextNumber(0, 6.28)
		local p = c + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(6, 40)
		local s = rng:NextNumber(0.7, 1.3)
		part({ Name = "MushStem", Size = V(0.5 * s, 1.4 * s, 0.5 * s), CFrame = CF(p + V(0, 0.7 * s, 0)), Color = rgb(230, 225, 210), Material = Enum.Material.SmoothPlastic, Parent = f })
		local cap = part({ Name = "MushCap", Shape = Enum.PartType.Ball, Size = V(1.6, 0.9, 1.6) * s, CFrame = CF(p + V(0, 1.5 * s, 0)), Color = MUSH, Material = Enum.Material.Neon,
			CanCollide = false, Parent = f })
		if k % 3 == 0 then
			Make("PointLight", { Color = MUSH, Range = 10, Brightness = 0.8, Parent = cap })
		end
	end
	-- ilhota com o baú e passarela de tábuas
	part({ Name = "Islet", Shape = Enum.PartType.Cylinder, Size = V(1.2, 9, 9), CFrame = CF(c + V(0, 0.2, 0)) * ANG(0, 0, rad(90)), Color = MOSS2, Material = Enum.Material.Grass, Parent = f })
	for k = 1, 6 do
		local p = c + V(4 + k * 2.1, 0.35, 0)
		part({ Name = "Boardwalk", Size = V(2, 0.4, 3.6), CFrame = CF(p) * ANG(0, 0, rng:NextNumber(-0.05, 0.05)), Color = rgb(120, 92, 66), Material = Enum.Material.WoodPlanks, Parent = f })
	end
	local cc = c + V(0, 0.8, 0)
	out.chests.verdant_low_swamp = chest(f, CF(cc, cc + V(1, 0, 0)), "Baú do Pântano")
	out.walkPoints["Pântano Brumoso"] = c + V(18, 3, 0)
	return f
end

-- Cavernas Esmeralda: entrada com moldura de pedra, cristais e cogumelos que brilham, estalactites, baú
local function caves(parent, chest, rng: Random, out, cave)
	local f = Make("Folder", { Name = "EmeraldCaves", Parent = parent })
	local halls = VerdantLowlands.Cave.halls
	-- boca da caverna: moldura de pedras e tochas
	for _, mouth in ipairs({ cave.entrance, cave.exit }) do
		local out_ = ((mouth - Worlds.Info.verdant.center) * V(1, 0, 1)).Unit
		local sd = out_:Cross(V(0, 1, 0))
		for _, s in ipairs({ -1, 1 }) do
			part({ Name = "CaveMouthRock", Size = V(4, 9, 4), CFrame = CF(mouth + sd * 8 * s + V(0, 2, 0)) * ANG(0, rng:NextNumber(0, 6), rng:NextNumber(-0.2, 0.2)), Color = STONE_D, Parent = f })
			local torch = part({ Name = "CaveTorch", Size = V(0.7, 0.7, 0.7), CFrame = CF(mouth + sd * 6 * s + V(0, 4.5, 0)), Color = rgb(255, 170, 80), Material = Enum.Material.Neon,
				CanCollide = false, Parent = f })
			Make("PointLight", { Color = rgb(255, 170, 90), Range = 14, Brightness = 1.4, Parent = torch })
		end
		part({ Name = "CaveMouthTop", Size = V(20, 3, 5), CFrame = CFrame.lookAt(mouth + V(0, 7, 0), mouth + V(0, 7, 0) + sd), Color = STONE, Parent = f })
	end
	-- salões: cristais, cogumelos, estalactites
	for i, hp in ipairs(cave.halls) do
		local h = halls[i]
		local floorY = hp.Y - h.r * 0.78 + 1
		for k = 1, 7 do
			local a = k / 7 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local d = h.r * rng:NextNumber(0.55, 0.85)
			local p = V(hp.X + math.cos(a) * d, floorY, hp.Z + math.sin(a) * d)
			local hgt = rng:NextNumber(2.5, 5.5)
			local cry = part({ Name = "CaveCrystal", Size = V(1.2, hgt, 1.2), CFrame = CF(p + V(0, hgt / 2, 0)) * ANG(rng:NextNumber(-0.4, 0.4), a, rng:NextNumber(-0.4, 0.4)),
				Color = CAVE_GLOW, Material = Enum.Material.Neon, Transparency = 0.1, CanCollide = false, Parent = f })
			if k % 2 == 0 then
				Make("PointLight", { Color = CAVE_GLOW, Range = 16, Brightness = 1.3, Parent = cry })
			end
		end
		for k = 1, 4 do
			local a = rng:NextNumber(0, 6.28)
			local p = V(hp.X + math.cos(a) * h.r * 0.4, floorY, hp.Z + math.sin(a) * h.r * 0.4)
			part({ Name = "CaveMushStem", Size = V(0.4, 1.2, 0.4), CFrame = CF(p + V(0, 0.6, 0)), Color = rgb(230, 230, 220), Material = Enum.Material.SmoothPlastic, Parent = f })
			part({ Name = "CaveMushCap", Shape = Enum.PartType.Ball, Size = V(1.4, 0.8, 1.4), CFrame = CF(p + V(0, 1.3, 0)), Color = MUSH, Material = Enum.Material.Neon, CanCollide = false, Parent = f })
		end
		for k = 1, 6 do
			local a = rng:NextNumber(0, 6.28)
			local d = h.r * rng:NextNumber(0, 0.6)
			local top = V(hp.X + math.cos(a) * d, hp.Y + h.r * 0.75, hp.Z + math.sin(a) * d)
			local len = rng:NextNumber(2, 4.5)
			part({ Name = "Stalactite", Size = V(1, len, 1), CFrame = CF(top - V(0, len / 2, 0)) * ANG(0, a, 0), Color = rgb(96, 104, 96), Material = Enum.Material.Slate, CanCollide = false,
				Parent = f })
		end
		Make("PointLight", { Color = CAVE_GLOW, Range = h.r * 1.4, Brightness = 0.5, Parent = part({ Name = "HallGlow", Size = V(1, 1, 1), CFrame = CF(hp), Transparency = 1,
			CanCollide = false, Parent = f }) })
	end
	-- baú no último salão
	local last = cave.halls[#cave.halls]
	local cc = V(last.X, last.Y - halls[#halls].r * 0.78 + 1, last.Z)
	out.chests.verdant_low_cave = chest(f, CF(cc, cc + (cave.halls[1] - last) * V(1, 0, 1)), "Coração da Caverna Esmeralda")
	out.walkPoints["Cavernas Esmeralda"] = cave.entrance + V(0, 3, 0)
	return f
end

-- Bosques espalhados pelas terras baixas (fora dos lugares, do rio e das rampas)
local function groves(parent, WB, rng: Random)
	local f = Make("Folder", { Name = "LowlandGroves", Parent = parent })
	local w = Worlds.Info.verdant
	local R0, R1 = w.radius + 20, w.lowlands.radius - 14
	local keep = {}
	for _, key in ipairs({ "eldermoor", "watchtower", "runes", "swamp" }) do
		table.insert(keep, { pos = polar(PL[key].theta, PL[key].dist), r = key == "eldermoor" and 56 or 40 })
	end
	table.insert(keep, { pos = polar(215, 430), r = 30 }) -- campo das Sentinelas das Ruínas (zona de inimigos)
	table.insert(keep, { pos = polar(PL.caveIn.theta, PL.caveIn.dist), r = 18 })
	table.insert(keep, { pos = polar(PL.caveOut.theta, PL.caveOut.dist), r = 16 })
	local function blocked(theta: number, d: number): boolean
		local p = polar(theta, d)
		for _, k in ipairs(keep) do
			if flatDist(p, k.pos) < k.r then
				return true
			end
		end
		for _, th in ipairs(PL.ramps) do
			if math.abs((theta - th + 180) % 360 - 180) < 6 and d < w.radius + 90 then
				return true
			end
		end
		-- rio (das cachoeiras até a foz)
		local diffMouth = math.abs((theta - PL.riverMouth + 180) % 360 - 180)
		if diffMouth < 22 and d < w.radius + 90 or diffMouth < 5 then
			return true
		end
		return false
	end
	local leaves = { rgb(62, 118, 46), rgb(76, 136, 54), rgb(54, 104, 42), rgb(84, 140, 58), rgb(92, 150, 60) }
	local bark = rgb(96, 58, 50)
	local trees = 0
	-- árvore leve de blocos (tronco + copa de 5 cubos, ~6 peças): dá densidade sem pesar
	local function blockTree(p: Vector3, sc: number)
		local h = rng:NextNumber(5, 8) * sc
		part({ Name = "Trunk", Size = V(1.3 * sc, h, 1.3 * sc), CFrame = CF(p + V(0, h / 2, 0)) * ANG(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.06, 0.06)), Color = bark,
			Material = Enum.Material.Wood, Parent = f })
		WB.cubeCluster(f, p + V(0, h + 1.6 * sc, 0), 5.2 * sc, leaves[rng:NextInteger(1, #leaves)], rng, 5)
	end
	for g = 1, 46 do
		local theta = g * (360 / 46) + rng:NextNumber(-3, 3)
		local d = rng:NextNumber(R0 + 8, R1 - 8)
		for k = 1, 8 do
			local th = theta + rng:NextNumber(-3.2, 3.2)
			local dd = d + rng:NextNumber(-20, 20)
			if dd > R0 and dd < R1 and not blocked(th, dd) then
				local p = polar(th, dd, lowY() - w.center.Y)
				if k == 1 and g % 2 == 0 then
					WB.oakTree(f, p, rng:NextNumber(0.9, 1.25), rng, bark, leaves[rng:NextInteger(1, #leaves)])
					trees += 1
				elseif k <= 6 then
					blockTree(p, rng:NextNumber(0.8, 1.25))
					trees += 1
				elseif k == 7 then
					WB.bush(f, p, rng:NextNumber(0.9, 1.3), rng, leaves[rng:NextInteger(1, #leaves)])
				else
					WB.rockCluster(f, p, rng:NextNumber(0.7, 1.2), rng, rgb(112, 116, 108), Enum.Material.Slate, MOSS)
				end
			end
		end
	end
	-- canteiros de flores nas clareiras
	local flowerCols = { rgb(255, 150, 200), rgb(255, 230, 120), rgb(180, 140, 255), rgb(255, 255, 255) }
	for k = 1, 14 do
		local th, dd = rng:NextNumber(0, 360), rng:NextNumber(R0 + 20, R1 - 20)
		if not blocked(th, dd) then
			WB.flowerBush(f, polar(th, dd, lowY() - w.center.Y), rng:NextNumber(0.9, 1.2), rng, flowerCols[k % #flowerCols + 1])
		end
	end
	return f, trees
end

-- Constrói tudo das terras baixas. Devolve { chests, walkPoints, trees, cave }.
function VerdantLowlands.build(parent: Instance, terrainOk: boolean, WB)
	local w = Worlds.Info.verdant
	local out = { chests = {}, walkPoints = {}, gates = {}, npcs = {} }
	local f = Make("Folder", { Name = "Lowlands", Parent = parent })
	local T = terrainOk and workspace:FindFirstChildOfClass("Terrain") :: Terrain
	local cave
	if T then
		cave = carve(T, w, Enum.Material[w.ground])
	else
		-- sem Terrain: posições das escavações calculadas do mesmo jeito (as peças continuam no lugar)
		local y0 = -w.lowlands.drop
		local halls = {}
		for i, h in ipairs(VerdantLowlands.Cave.halls) do
			halls[i] = polar(h.theta, h.dist, h.y)
		end
		cave = { entrance = polar(PL.caveIn.theta, PL.caveIn.dist, y0 + 2), exit = polar(PL.caveOut.theta, PL.caveOut.dist, y0 + 2), halls = halls,
			crypt = polar(PL.eldermoor.theta, PL.eldermoor.dist + 14, y0 - 9) }
	end
	local rng = Random.new(20261)
	local function chest(parent_, cf, title)
		local model, prompt = WB.shrineChest(parent_, cf, title, { accent = ACCENT })
		return { model = model, prompt = prompt, pos = cf.Position, title = title }
	end
	eldermoor(f, chest, rng, out, cave)
	watchtower(f, chest, rng, out)
	runeCircle(f, chest, rng, out)
	swamp(f, chest, rng, out, T)
	caves(f, chest, rng, out, cave)
	-- cachoeiras: das duas quedas do planalto (curtas, caem no rio) e a foz que despenca da ilha
	local mouth = polar(PL.riverMouth, w.lowlands.radius - 2, lowY() - w.center.Y)
	local mdir = ((mouth - w.center) * V(1, 0, 1)).Unit
	WB.waterfall(f, mouth + mdir * 1.5 + V(0, 0.2, 0), 140, 9, mdir)
	-- pontes de pedra sobre o rio (o anel de passeio atravessa)
	for _, d in ipairs({ w.radius + 110, w.radius + 210 }) do
		local p = polar(PL.riverMouth, d, lowY() - w.center.Y)
		local along = ((p - w.center) * V(1, 0, 1)).Unit
		local across = along:Cross(V(0, 1, 0))
		part({ Name = "RiverBridge", Size = V(18, 1.2, 7), CFrame = CFrame.lookAt(p + V(0, 1.4, 0), p + V(0, 1.4, 0) + along) * ANG(0, rad(90), 0), Color = STONE, Parent = f })
		for _, s in ipairs({ -1, 1 }) do
			part({ Name = "BridgeRail", Size = V(0.8, 1.6, 18), CFrame = CFrame.lookAt(p + V(0, 2.8, 0) + along * 3.2 * s, p + V(0, 2.8, 0) + along * 3.2 * s + across), Color = STONE_D, Parent = f })
		end
	end
	local _, trees = groves(f, WB, rng)
	out.trees = trees
	out.cave = cave
	out.folder = f
	return out
end

return VerdantLowlands

-- FAROL ANCESTRAL — torre-farol do Mundo 2 (Crystal Hollow), feita a partir da imagem do autor:
-- torre em treliça de pedra que se alarga para cima (cintura fina sobre uma base em degraus), cristal azul
-- gigante preso no alto com um feixe de luz subindo ao céu, brilho violeta dentro da treliça, raízes de
-- pedra com veios roxos espalhando-se pelo chão, e RUÍNAS em volta: portal de pedra (trilito) na frente,
-- colunata, círculo de pedras em pé, colunas quebradas, blocos caídos e ilhotas flutuantes ao fundo.
--
-- Raízes, cristal e ilhotas são malhas do MeshKit convertidas em cunhas ancoradas (Builders/Facets): não
-- precisam de EditableMesh. As ruínas usam as peças do CrystalKit (colunas, arcos) e só nascem em lugar
-- livre (WorldBuilder.isFree: fora das zonas de inimigos, campos de recurso, caminhos reservados).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Make = require(Shared.Util.Make)
local MeshKit = require(Shared.Builders.MeshKit)
local Facets = require(Shared.Builders.Facets)
local CrystalKit = require(script.Parent.CrystalKit)
local WorldBuilder = require(script.Parent.WorldBuilder)

local BeaconTower = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB
local M = Enum.Material

local STONE, STONE_D, STONE_L = rgb(146, 134, 120), rgb(104, 94, 88), rgb(182, 172, 156)
local VIOLET = rgb(150, 70, 255)
local SKY, SKY_L = rgb(110, 200, 255), rgb(210, 245, 255)

BeaconTower.HEIGHT = 110
-- perfil da treliça: { altura, raio } (cintura fina, abre para cima como na imagem)
BeaconTower.PROFILE = { { 19, 8.5 }, { 34, 7.2 }, { 50, 9.6 }, { 66, 12.6 }, { 82, 15.6 }, { 97, 18 }, { 108, 19.5 } }
BeaconTower.SIDES = 8

local function part(parent: Instance, props)
	props.Parent = parent
	return CrystalKit.part(props)
end

-- Viga entre dois pontos.
local function beam(parent: Instance, a: Vector3, b: Vector3, t: number, color: Color3, material, name: string?)
	local len = (b - a).Magnitude
	return part(parent, { Name = name or "Beam", Size = V(t, t, len + t * 0.6), CFrame = CF((a + b) / 2, b), Color = color, Material = material or M.Slate, CanCollide = true })
end

local function facets(parent: Instance, g, props)
	return Facets.build(g, props.th or 0.6, { material = props.material or M.Slate, anchored = true, collide = props.collide == true, shadow = props.shadow ~= false,
		transparency = props.transparency, name = props.name }, parent)
end

local function solid(c: Color3)
	return function()
		return c
	end
end

-- relevo de pedra (ruído na normal)
local function rocky(g, amp: number, freq: number, seed: number)
	local nrm = MeshKit.normals(g)
	local out = table.create(#g.verts)
	for i, v in ipairs(g.verts) do
		out[i] = v + nrm[i] * (math.noise(v.X * freq + seed, v.Y * freq, v.Z * freq - seed) * amp)
	end
	return { verts = out, colors = g.colors, tris = g.tris, flat = g.flat, keep = g.keep }
end

-- Constrói a torre com o pé em `base` (chão). Devolve { model, top, crystal, chestCF, facets }.
function BeaconTower.build(parent: Instance, base: Vector3, facingDir: Vector3, rng: Random)
	local model = Make("Model", { Name = "AncientBeacon", Parent = parent })
	local lattice = Make("Folder", { Name = "Lattice", Parent = model })
	local deco = Make("Folder", { Name = "Detail", Parent = model })
	local out = { model = model, facets = 0 }
	local fwd = Vector3.new(facingDir.X, 0, facingDir.Z).Unit
	local yaw = math.atan2(-fwd.X, -fwd.Z)
	local frame = CF(base) * ANG(0, yaw, 0) -- -Z do frame aponta para `facingDir`

	-- BASE em degraus (octógonos de pedra) com painéis de runas violeta
	local layers = { { 0, 3, 30 }, { 3, 6, 23 }, { 9, 6, 18.5 }, { 15, 4, 16 } }
	for i, L in ipairs(layers) do
		for k = 0, 1 do
			part(model, { Name = "Plinth", Size = V(L[3], L[2], L[3]), CFrame = frame * CF(0, L[1] + L[2] / 2, 0) * ANG(0, rad(45 * k), 0), Color = i % 2 == 0 and STONE or STONE_D,
				Material = M.Slate, CanCollide = true })
		end
		if i == 3 then
			for f = 0, 7 do
				local a = rad(f * 45 + 22.5)
				local face = frame * ANG(0, a, 0) * CF(0, L[1] + L[2] / 2, -L[3] / 2 * 0.924 - 0.05)
				part(deco, { Name = "RunePanel", Size = V(3.4, 3.6, 0.3), CFrame = face, Color = STONE_L, Material = M.Slate })
				part(deco, { Name = "RuneGlow", Size = V(0.35, 2.6, 0.2), CFrame = face * CF(0, 0, -0.2), Color = VIOLET, Material = M.Neon, CastShadow = false })
				part(deco, { Name = "RuneGlow", Size = V(2, 0.35, 0.2), CFrame = face * CF(0, 0.5, -0.2) * ANG(0, 0, rad(f % 2 == 0 and 30 or -30)), Color = VIOLET, Material = M.Neon, CastShadow = false })
			end
		end
	end
	-- contrafortes nas diagonais
	for f = 0, 3 do
		local a = rad(f * 90 + 45)
		part(model, { Name = "Buttress", Size = V(3.2, 12, 6), CFrame = frame * ANG(0, a, 0) * CF(0, 6, -12.5) * ANG(rad(-14), 0, 0), Color = STONE_D, Material = M.Slate, CanCollide = true })
	end

	-- TRELIÇA: anéis octogonais, montantes e travessas em X (o violeta brilha nos andares de baixo)
	local P, N = BeaconTower.PROFILE, BeaconTower.SIDES
	local function corner(level: number, k: number): Vector3
		local h, r = P[level][1], P[level][2]
		local a = rad(k / N * 360 + (level % 2) * (180 / N) * 0.35)
		return (frame * CF(math.cos(a) * r, h, math.sin(a) * r)).Position
	end
	for lv = 1, #P do
		for k = 0, N - 1 do
			local a, b = corner(lv, k), corner(lv, (k + 1) % N)
			beam(lattice, a, b, lv == #P and 1.8 or 1.3, STONE, M.Slate, "Ring")
			if lv < #P then
				local up = corner(lv + 1, k)
				local upNext = corner(lv + 1, (k + 1) % N)
				beam(lattice, a, up, 1.5, STONE_D, M.Slate, "Post")
				beam(lattice, a, upNext, 0.8, STONE, M.Slate, "Brace")
				beam(lattice, b, up, 0.8, STONE, M.Slate, "Brace")
				if lv <= 3 then
					-- veio violeta correndo por dentro do montante
					local inward = (V(base.X, a.Y, base.Z) - a).Unit
					local inward2 = (V(base.X, up.Y, base.Z) - up).Unit
					part(deco, { Name = "VioletVein", Size = V(0.35, 0.35, (up - a).Magnitude), CFrame = CF((a + inward * 0.9 + up + inward2 * 0.9) / 2, up + inward2 * 0.9), Color = VIOLET,
						Material = M.Neon, CastShadow = false })
				end
			end
		end
	end
	-- coroa: pontas no anel do topo e plataforma interna
	for k = 0, N - 1 do
		local c0 = corner(#P, k)
		part(deco, { Name = "CrownSpike", Size = V(1.2, 6, 1.2), CFrame = CF(c0 + V(0, 3, 0)), Color = STONE_L, Material = M.Slate })
		part(deco, { Name = "CrownTip", Size = V(0.7, 2, 0.7), CFrame = CF(c0 + V(0, 7, 0)) * ANG(rad(45), 0, rad(45)), Color = SKY_L, Material = M.Neon, CastShadow = false })
	end
	-- brilho violeta dentro da cintura
	part(deco, { Name = "VioletCore", Shape = Enum.PartType.Cylinder, Size = V(40, 9, 9), CFrame = frame * CF(0, 38, 0) * ANG(0, 0, rad(90)), Color = VIOLET, Material = M.Neon,
		Transparency = 0.72, CastShadow = false })

	-- CRISTAL azul gigante preso no alto (bipirâmide hexagonal de vidro com núcleo de neon)
	local cc = (frame * CF(0, 80, 0)).Position
	local function bipyramid(c: Vector3, r: number, h: number, col: Color3)
		return MeshKit.loft({ { p = c - V(0, h * 0.18, 0), w = r * 0.92 }, { p = c + V(0, h * 0.12, 0), w = r } },
			{ seg = 6, steps = 1, up = V(0, 0, -1), capStart = h * 0.38, capEnd = h * 0.32, capRings = 0, flat = true, color = function(_t, ex)
				return col:Lerp(Color3.new(1, 1, 1), math.max(0, ex) * 0.35)
			end })
	end
	out.facets += facets(deco, bipyramid(cc, 9.5, 36, SKY), { material = M.Glass, transparency = 0.2, name = "BeaconCrystal", shadow = false })
	out.facets += facets(deco, bipyramid(cc, 5.5, 26, rgb(150, 225, 255)), { material = M.Neon, name = "BeaconCore", shadow = false })
	local glow = part(deco, { Name = "BeaconLight", Size = V(1, 1, 1), CFrame = CF(cc), Transparency = 1 })
	Make("PointLight", { Color = SKY, Range = 60, Brightness = 3, Shadows = false, Parent = glow })
	local sp = Instance.new("ParticleEmitter")
	sp.Name = "BeaconSparkles"
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Color = ColorSequence.new(SKY_L, SKY)
	sp.LightEmission = 1
	sp.LightInfluence = 0
	sp.Rate = 12
	sp.Lifetime = NumberRange.new(1.5, 2.5)
	sp.Speed = NumberRange.new(2, 6)
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 0) })
	sp.Parent = glow
	-- anel de luz em volta do cristal
	for k = 0, 15 do
		local a0, a1 = rad(k / 16 * 360), rad((k + 1) / 16 * 360)
		local p0 = cc + V(math.cos(a0) * 11, 2, math.sin(a0) * 11)
		local p1 = cc + V(math.cos(a1) * 11, 2, math.sin(a1) * 11)
		part(deco, { Name = "Halo", Size = V(0.5, 0.5, (p1 - p0).Magnitude + 0.3), CFrame = CF((p0 + p1) / 2, p1), Color = SKY_L, Material = M.Neon, CastShadow = false })
	end
	-- FEIXE DE LUZ subindo ao céu
	local beamTop = cc + V(0, 15, 0)
	part(deco, { Name = "SkyBeam", Shape = Enum.PartType.Cylinder, Size = V(260, 2.4, 2.4), CFrame = CF(beamTop + V(0, 130, 0)) * ANG(0, 0, rad(90)), Color = SKY_L, Material = M.Neon,
		Transparency = 0.3, CastShadow = false })
	part(deco, { Name = "SkyBeamGlow", Shape = Enum.PartType.Cylinder, Size = V(260, 7, 7), CFrame = CF(beamTop + V(0, 130, 0)) * ANG(0, 0, rad(90)), Color = SKY, Material = M.Neon,
		Transparency = 0.82, CastShadow = false })
	out.crystal = cc
	out.top = beamTop

	-- RAÍZES de pedra com veios violeta (saem da base e se espalham pelo chão)
	local rootGeo, veinGeo = {}, {}
	for k = 0, 9 do
		local a = rad(k * 36 + 18 + rng:NextNumber(-8, 8))
		local dir = V(math.cos(a), 0, math.sin(a))
		local reach = 34 + rng:NextNumber(-3, 6)
		local side = V(-dir.Z, 0, dir.X) * rng:NextNumber(-3, 3)
		local pts = {
			(frame * CF(0, 13, 0)).Position + dir * 8.5,
			(frame * CF(0, 8, 0)).Position + dir * 14 + side * 0.4,
			(frame * CF(0, 2.5, 0)).Position + dir * 22 + side,
			(frame * CF(0, -0.6, 0)).Position + dir * reach + side * 1.4,
		}
		local keys = {}
		for i, q in ipairs(pts) do
			keys[i] = { p = q, w = 4.6 - i * 0.75, h = 3.4 - i * 0.55 }
		end
		table.insert(rootGeo, MeshKit.loft(keys, { seg = 6, steps = 1, capStart = 0, capEnd = 1.2, capRings = 0, color = function(_t, _ex, ey)
			return STONE_D:Lerp(STONE, math.clamp(ey * 0.5 + 0.5, 0, 1) * 0.6)
		end }))
		local vk = {}
		for i, q in ipairs(pts) do
			vk[i] = { p = q + V(0, (3.4 - i * 0.55) * 0.9, 0), w = 0.4 }
		end
		table.insert(veinGeo, MeshKit.loft(vk, { seg = 3, steps = 1, capStart = 0, capEnd = 0.3, capRings = 0, color = solid(VIOLET) }))
	end
	out.facets += facets(model, rocky(MeshKit.merge(rootGeo), 0.5, 0.25, 3.1), { material = M.Slate, collide = true, name = "BeaconRoot" })
	out.facets += facets(deco, MeshKit.merge(veinGeo), { material = M.Neon, name = "RootVein", shadow = false, th = 0.3 })
	out.chestCF = frame * CF(0, 3.2, -13.5)
	return out
end

-- Ilhota flutuante: rocha em cone invertido com relevo, tampa de grama e uma árvore de cristal.
local function floatingIsle(parent: Instance, at: Vector3, r: number, rng: Random)
	local g = MeshKit.loft({ { p = at, w = r, h = r }, { p = at - V(0, r * 0.7, 0), w = r * 0.7, h = r * 0.7 }, { p = at - V(0, r * 1.5, 0), w = r * 0.25, h = r * 0.25 } },
		{ seg = 7, steps = 1, up = V(0, 0, -1), capStart = 0, capEnd = r * 0.5, capRings = 0, flat = true, color = function(_t, _ex, _ey, p)
			return STONE_D:Lerp(STONE, math.clamp((p.Y - at.Y + r * 1.5) / (r * 1.5), 0, 1))
		end })
	local n = facets(parent, rocky(g, r * 0.12, 0.2, at.X * 0.01), { material = M.Slate, name = "IsleRock" })
	part(parent, { Name = "IsleGrass", Shape = Enum.PartType.Cylinder, Size = V(1.4, r * 2.1, r * 2.1), CFrame = CF(at + V(0, 0.5, 0)) * ANG(0, 0, rad(90)), Color = rgb(70, 130, 92),
		Material = M.Grass, CanCollide = true })
	WorldBuilder.oakTree(parent, at + V(0, 1.2, 0), r * 0.09, rng, rgb(84, 66, 74), rng:NextNumber() < 0.5 and rgb(124, 92, 226) or rgb(58, 112, 214))
	for k = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		part(parent, { Name = "IsleVine", Size = V(0.3, r * 0.6, 0.3), CFrame = CF(at + V(math.cos(a) * r * 0.85, -r * 0.3, math.sin(a) * r * 0.85)), Color = rgb(70, 130, 92), Material = M.Grass })
	end
	return n
end

--[[ Ruínas em volta da torre. `center` = pé da torre; `front` = direção da entrada (portal de pedra).
	isFree(q, margem) decide onde cada peça pode nascer. Devolve o número de peças de ruína. ]]
function BeaconTower.ruins(parent: Instance, center: Vector3, front: Vector3, rng: Random, isFree)
	local f = Make("Folder", { Name = "BeaconRuins", Parent = parent })
	local fwd = Vector3.new(front.X, 0, front.Z).Unit
	local side = V(-fwd.Z, 0, fwd.X)
	local placed = 0
	local function ground(q: Vector3): Vector3
		return WorldBuilder.groundAt(q)
	end
	-- portal de pedra (trilito) na frente da torre, como na imagem
	local gp = ground(center + fwd * 34)
	local gcf = CF(gp, gp + fwd)
	for _, sx in ipairs({ -1, 1 }) do
		part(f, { Name = "GatePillar", Size = V(3.2, 11, 3.2), CFrame = gcf * CF(sx * 5.2, 5.5, 0) * ANG(0, 0, rad(sx * 1.5)), Color = STONE, Material = M.Slate, CanCollide = true })
		part(f, { Name = "GatePillarCap", Size = V(3.8, 1, 3.8), CFrame = gcf * CF(sx * 5.2, 11.2, 0), Color = STONE_L, Material = M.Slate, CanCollide = true })
	end
	part(f, { Name = "GateLintel", Size = V(14.5, 2.6, 3.8), CFrame = gcf * CF(0, 13, 0) * ANG(0, 0, rad(2)), Color = STONE_D, Material = M.Slate, CanCollide = true })
	part(f, { Name = "GateRune", Size = V(4, 0.4, 0.2), CFrame = gcf * CF(0, 13, -1.95), Color = VIOLET, Material = M.Neon, CastShadow = false })
	placed += 7
	-- colunata (fila de colunas com vigas; uma quebrada), à esquerda da entrada
	local colBase = center + fwd * 18 - side * 52
	if isFree(colBase, 6) then
		for i = 0, 4 do
			local q = ground(colBase + fwd * (i * 7 - 14))
			CrystalKit.column(f, q, 13, 1.5, rng, i == 3)
			placed += 1
		end
		for i = 0, 2 do
			if i ~= 2 then
				local a = ground(colBase + fwd * (i * 7 - 14))
				local b = ground(colBase + fwd * ((i + 1) * 7 - 14))
				part(f, { Name = "ColonnadeBeam", Size = V(3, 1.8, (b - a).Magnitude + 3), CFrame = CF((a + b) / 2 + V(0, 15.6, 0), b + V(0, 15.6, 0)), Color = STONE_D, Material = M.Slate,
					CanCollide = true })
				placed += 1
			end
		end
	end
	-- círculo de pedras em pé (algumas inclinadas ou caídas)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2 + 0.2
		local q = center + V(math.cos(a), 0, math.sin(a)) * 44
		if (q - gp).Magnitude > 10 and isFree(q, 3) then
			local g = ground(q)
			local fallen = k % 5 == 2
			if fallen then
				part(f, { Name = "FallenMonolith", Size = V(2.6, 1.8, 7.5), CFrame = CF(g + V(0, 0.9, 0)) * ANG(0, a + 0.6, rad(rng:NextNumber(-6, 6))), Color = STONE_D, Material = M.Slate, CanCollide = true })
			else
				local h = rng:NextNumber(6, 9)
				part(f, { Name = "Monolith", Size = V(2.8, h, 1.8), CFrame = CF(g + V(0, h / 2 - 0.3, 0), center * V(1, 0, 1) + V(0, g.Y + h / 2, 0)) * ANG(rad(rng:NextNumber(-7, 7)), 0, rad(rng:NextNumber(-6, 6))),
					Color = k % 2 == 0 and STONE or STONE_L, Material = M.Slate, CanCollide = true })
				if k % 3 == 0 then
					part(f, { Name = "MonolithRune", Size = V(0.3, h * 0.5, 0.2), CFrame = CF(g + V(0, h / 2, 0), center * V(1, 0, 1) + V(0, g.Y + h / 2, 0)) * CF(0, 0, -0.95), Color = VIOLET,
						Material = M.Neon, CastShadow = false })
				end
			end
			placed += 1
		end
	end
	-- colunas quebradas, blocos caídos e lajes do antigo piso
	for _ = 1, 30 do
		if placed >= 70 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(26, 72)
		local q = center + V(math.cos(a), 0, math.sin(a)) * d
		if isFree(q, 4) and (q - gp).Magnitude > 9 then
			local g = ground(q)
			local roll = rng:NextNumber()
			if roll < 0.35 then
				CrystalKit.column(f, g, rng:NextNumber(8, 13), 1.3, rng, true)
			elseif roll < 0.7 then
				part(f, { Name = "Block", Size = V(rng:NextNumber(2.5, 4.5), rng:NextNumber(1.6, 2.8), rng:NextNumber(2.5, 4)), CFrame = CF(g + V(0, 0.9, 0)) * ANG(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
					Color = rng:NextNumber() < 0.5 and STONE or STONE_D, Material = M.Slate, CanCollide = true })
			else
				part(f, { Name = "FloorSlab", Size = V(rng:NextNumber(4, 7), 0.6, rng:NextNumber(4, 7)), CFrame = CF(g + V(0, 0.15, 0)) * ANG(rng:NextNumber(-0.05, 0.05), rng:NextNumber(0, 6), 0),
					Color = STONE_L, Material = M.Slate, CanCollide = true })
			end
			placed += 1
		end
	end
	-- ilhotas flutuantes atrás da torre
	local isles = 0
	for k, spec in ipairs({ { -0.9, 0.5, 70, 14 }, { -1.3, -0.4, 100, 8 }, { -0.7, -1.0, 122, 6 } }) do
		local at = center + fwd * (spec[1] * 60) + side * (spec[2] * 60) + V(0, spec[3], 0)
		floatingIsle(f, at, spec[4], Random.new(900 + k))
		isles += 1
	end
	return placed, isles
end

return BeaconTower

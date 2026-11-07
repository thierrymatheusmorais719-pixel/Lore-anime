-- Árvore "de blocos" do Verdant Haven, feita a partir da referência do autor
-- (docs/concept/world1_tree_ref.jpg): tronco grosso marrom-escuro, copa MUITO larga e irregular
-- de blocos verdes em alturas diferentes (com placas de "studs"), rosetas de folhas arredondadas e
-- brilhantes, galhos meio escondidos, raízes e uma base natural com grama, plantas, pedras e folhas.
--
-- Uma família: a árvore de destaque (hero) e variações menores, cada uma com copa, tronco e base
-- diferentes (sementes próprias) — nada de cópias idênticas.
-- Colisão só no que se pisa/esbarra (tronco, raízes grandes e a placa da base, que é baixa).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Make = require(Shared.Util.Make)

local BlockTree = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB
local M = Enum.Material

-- paleta da referência
local LEAF = { rgb(46, 158, 50), rgb(36, 138, 42), rgb(60, 176, 60), rgb(30, 120, 38), rgb(52, 166, 54) }
local LEAF_DARK = rgb(24, 100, 32)
local ROSETTE = rgb(70, 190, 72)
local BARK, BARK_DARK, BARK_LIGHT = rgb(84, 50, 32), rgb(56, 32, 22), rgb(104, 66, 42)
local BASE_GREEN, BASE_GREEN2 = rgb(34, 150, 44), rgb(44, 166, 52)

local function p(parent, props)
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

local function w(parent, props)
	props.Anchored = true
	props.CanCollide = props.CanCollide == true
	props.CanQuery = props.CanCollide
	props.CanTouch = false
	props.Parent = parent
	return Make("WedgePart", props)
end

local function ellipsoid(parent, props)
	local part = p(parent, props)
	Make("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = part })
	return part
end

-- Roseta de folhas arredondadas (como as "flores" verdes da referência), voltada para `dir`.
local function rosette(parent, center: Vector3, dir: Vector3, size: number, rng: Random)
	local cf = CF(center, center + dir)
	local spin = rng:NextNumber(0, math.pi * 2)
	for k = 1, 5 do
		local a = spin + k / 5 * math.pi * 2
		ellipsoid(parent, { Name = "RosetteLeaf", Size = V(size * 0.62, size * 0.62, size * 0.26),
			CFrame = cf * CF(math.cos(a) * size * 0.38, math.sin(a) * size * 0.38, 0) * ANG(math.sin(a) * rad(-25), math.cos(a) * rad(25), 0),
			Color = ROSETTE:Lerp(rgb(80, 196, 80), rng:NextNumber(0, 0.25)), Material = M.SmoothPlastic, Reflectance = 0.06, CastShadow = false })
	end
	ellipsoid(parent, { Name = "RosetteCenter", Size = V(size * 0.4, size * 0.4, size * 0.3), CFrame = cf * CF(0, 0, -size * 0.06), Color = rgb(30, 130, 40), Material = M.SmoothPlastic, CastShadow = false })
end

-- Tufo de grama: lâminas finas e altas (cunhas) inclinadas para fora.
local function grassTuft(parent, pos: Vector3, h: number, rng: Random)
	for k = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local bh = h * rng:NextNumber(0.6, 1)
		w(parent, { Name = "GrassBlade", Size = V(0.12, bh, 0.7), CFrame = CF(pos + V(math.cos(a) * 0.3, bh / 2, math.sin(a) * 0.3)) * ANG(0, a, rad(rng:NextNumber(-14, 14))),
			Color = rgb(28, 120, 36):Lerp(rgb(60, 170, 60), rng:NextNumber(0, 0.5)), Material = M.SmoothPlastic, CastShadow = false })
	end
end

-- Planta de folhas largas (tipo hosta) ao redor do tronco.
local function broadPlant(parent, pos: Vector3, s: number, rng: Random)
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local out = V(math.cos(a), 0, math.sin(a))
		ellipsoid(parent, { Name = "BroadLeaf", Size = V(1.3 * s, 0.2 * s, 2.4 * s), CFrame = CF(pos + out * 1.1 * s + V(0, 0.7 * s, 0), pos + out * 3 * s + V(0, 1.6 * s, 0)),
			Color = rgb(22, 96, 32):Lerp(rgb(46, 140, 50), rng:NextNumber(0, 0.6)), Material = M.SmoothPlastic, CastShadow = false })
	end
end

-- opts = { scale, crownW, crownD, crownH, blocks, rosettes, trunkH, base = bool, hero = bool }
function BlockTree.build(parent: Instance, pos: Vector3, rng: Random, opts)
	local s = opts.scale or 1
	local model = Make("Model", { Name = opts.hero and "VerdantHeroTree" or "VerdantBlockTree", Parent = parent })
	local yaw = CF(pos) * ANG(0, rng:NextNumber(0, math.pi * 2), 0)
	local function at(x, y, z)
		return yaw * CF(x * s, y * s, z * s)
	end
	local baseY = 0
	-- BASE natural: placa verde baixa (pisável), degrau com studs, grama, plantas, pedras e folhas
	if opts.base ~= false then
		local bw, bd = (opts.baseW or 24), (opts.baseD or 20)
		p(model, { Name = "BasePlate", Size = V(bw, 1, bd) * s, CFrame = at(0, 0.5, 0) * ANG(0, rad(rng:NextNumber(-6, 6)), 0), Color = BASE_GREEN, Material = M.SmoothPlastic, CanCollide = true })
		p(model, { Name = "BaseStep", Size = V(bw * 0.55, 0.6, bd * 0.4) * s, CFrame = at(-bw * 0.12, 1.3, bd * 0.18), Color = BASE_GREEN2, Material = M.Plastic, TopSurface = Enum.SurfaceType.Studs })
		p(model, { Name = "StudPatch", Size = V(5, 0.3, 2) * s, CFrame = at(bw * 0.2, 1.15, -bd * 0.3), Color = rgb(52, 176, 60), Material = M.Plastic, TopSurface = Enum.SurfaceType.Studs, CastShadow = false })
		baseY = 1
		for k = 1, (opts.hero and 7 or 3) do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(4, bw * 0.42)
			grassTuft(model, (at(math.cos(a) * d, baseY, math.sin(a) * d)).Position, rng:NextNumber(2.5, 4.5) * s, rng)
		end
		for k = 1, (opts.hero and 3 or 1) do
			local a = rng:NextNumber(0, math.pi * 2)
			broadPlant(model, (at(math.cos(a) * 6.5, baseY, math.sin(a) * 6.5)).Position, s * rng:NextNumber(0.8, 1.1), rng)
		end
		for k = 1, (opts.hero and 5 or 2) do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(5, bw * 0.45)
			p(model, { Name = "Pebble", Size = V(rng:NextNumber(0.8, 1.6), rng:NextNumber(0.5, 0.9), rng:NextNumber(0.8, 1.4)) * s, CFrame = at(math.cos(a) * d, baseY + 0.3, math.sin(a) * d) * ANG(0, a, rng:NextNumber(-0.3, 0.3)),
				Color = rgb(120, 120, 116):Lerp(rgb(160, 158, 150), rng:NextNumber(0, 1)), Material = M.Slate, CastShadow = false })
		end
		for k = 1, (opts.hero and 8 or 3) do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(3, bw * 0.45)
			ellipsoid(model, { Name = "FallenLeaf", Size = V(1.2, 0.1, 0.8) * s, CFrame = at(math.cos(a) * d, baseY + 0.06, math.sin(a) * d) * ANG(0, rng:NextNumber(0, 6), 0),
				Color = LEAF[rng:NextInteger(1, #LEAF)], Material = M.SmoothPlastic, CastShadow = false })
		end
	end
	-- TRONCO grosso de blocos, com lascas de casca e faixas escuras
	local th = opts.trunkH or 14
	local tw = opts.trunkW or 5
	p(model, { Name = "Trunk", Size = V(tw, th, tw * 0.9) * s, CFrame = at(0, baseY + th / 2, 0), Color = BARK, Material = M.SmoothPlastic, CanCollide = true })
	p(model, { Name = "TrunkUpper", Size = V(tw * 0.85, th * 0.4, tw * 0.8) * s, CFrame = at(0.4, baseY + th + th * 0.12, 0) * ANG(0, 0, rad(4)), Color = BARK_DARK, Material = M.SmoothPlastic })
	for k = 1, 4 do
		local side = (k % 2 == 0) and 1 or -1
		local face = k <= 2
		p(model, { Name = "BarkChunk", Size = V(face and tw * 0.5 or 0.8, th * rng:NextNumber(0.25, 0.45), face and 0.8 or tw * 0.5) * s,
			CFrame = at(face and side * tw * 0.15 or side * tw * 0.52, baseY + th * rng:NextNumber(0.25, 0.7), face and -tw * 0.47 or rng:NextNumber(-1, 1)),
			Color = k % 2 == 0 and BARK_DARK or BARK_LIGHT, Material = M.SmoothPlastic })
	end
	-- RAÍZES saindo do tronco (cunhas descendo até a base)
	for k = 1, (opts.hero and 5 or 3) do
		local a = k / (opts.hero and 5 or 3) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local dir = V(math.cos(a), 0, math.sin(a))
		local q = (at(0, baseY, 0)).Position + (yaw - yaw.Position):VectorToWorldSpace(dir) * (tw * 0.5 + 1.2) * s + V(0, 1 * s, 0)
		local out = (yaw - yaw.Position):VectorToWorldSpace(dir)
		w(model, { Name = "Root", Size = V(1.4 * s, 2 * s, 2.8 * s), CFrame = CF(q, q + out), Color = k % 2 == 0 and BARK or BARK_DARK, Material = M.SmoothPlastic, CanCollide = opts.hero == true })
	end
	-- COPA larga e irregular: núcleo + blocos espalhados num elipsoide achatado (alturas diferentes),
	-- base mais escura (sombra), placas com studs e galhos meio escondidos
	local cw, cd, ch = opts.crownW or 34, opts.crownD or 26, opts.crownH or 13
	local cy = baseY + th + ch * 0.45
	p(model, { Name = "CrownCore", Size = V(cw * 0.72, ch * 0.75, cd * 0.72) * s, CFrame = at(0, cy, 0), Color = LEAF[1], Material = M.SmoothPlastic })
	p(model, { Name = "CrownUnder", Size = V(cw * 0.78, ch * 0.25, cd * 0.7) * s, CFrame = at(rng:NextNumber(-1, 1), cy - ch * 0.42, 0), Color = LEAF_DARK, Material = M.SmoothPlastic })
	for i = 1, opts.blocks or 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.35, 1)
		local x = math.cos(a) * r * cw * 0.42
		local z = math.sin(a) * r * cd * 0.42
		local y = cy + rng:NextNumber(-0.42, 0.5) * ch * (1 - r * 0.35)
		local size = V(rng:NextNumber(5, 12), rng:NextNumber(2.5, 6.5), rng:NextNumber(5, 11))
		local studs = i % 7 == 0
		p(model, { Name = "LeafBlock", Size = size * s, CFrame = at(x, y, z) * ANG(0, rad(rng:NextNumber(-8, 8)), 0),
			Color = LEAF[rng:NextInteger(1, #LEAF)], Material = studs and M.Plastic or M.SmoothPlastic, TopSurface = studs and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth,
			CastShadow = size.X * size.Z > 50 })
	end
	-- blocos que saltam para cima, criando a silhueta "em degraus" da referência
	for i = 1, opts.tops or 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, 0.6)
		p(model, { Name = "LeafTop", Size = V(rng:NextNumber(6, 12), rng:NextNumber(2, 4), rng:NextNumber(6, 10)) * s,
			CFrame = at(math.cos(a) * r * cw * 0.35, cy + ch * 0.45 + rng:NextNumber(0, 2), math.sin(a) * r * cd * 0.35), Color = LEAF[(i % #LEAF) + 1], Material = M.SmoothPlastic })
	end
	for _, side in ipairs({ -1, 1 }) do
		p(model, { Name = "Branch", Size = V(cw * 0.22, 1.4, 1.4) * s, CFrame = at(side * cw * 0.14, cy - ch * 0.36, rng:NextNumber(-2, 2)) * ANG(0, 0, side * rad(14)), Color = BARK_DARK, Material = M.SmoothPlastic })
	end
	-- ROSETAS de folhas brilhantes nas faces da copa
	for i = 1, opts.rosettes or 5 do
		local a = (i / (opts.rosettes or 5)) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local up = i % 3 == 0
		local local_ = up and V(math.cos(a) * cw * 0.2, ch * 0.62, math.sin(a) * cd * 0.2) or V(math.cos(a) * cw * 0.47, rng:NextNumber(-0.1, 0.3) * ch, math.sin(a) * cd * 0.47)
		local worldPos = (at(local_.X, cy + local_.Y, local_.Z)).Position
		local dirLocal = up and V(0, 1, 0) or V(math.cos(a), 0.25, math.sin(a))
		rosette(model, worldPos, (yaw - yaw.Position):VectorToWorldSpace(dirLocal).Unit, rng:NextNumber(4.2, 5.6) * s, rng)
	end
	model.PrimaryPart = model:FindFirstChild("Trunk") :: BasePart
	model:SetAttribute("CrownRadius", math.max(cw, cd) * 0.5 * s)
	return model
end

-- Variações da família (forma da copa, tronco e base diferentes).
BlockTree.Variants = {
	hero = { hero = true, scale = 1, crownW = 36, crownD = 28, crownH = 14, blocks = 30, tops = 5, rosettes = 6, trunkH = 14, trunkW = 5.5, baseW = 26, baseD = 22 },
	wide = { scale = 0.62, crownW = 34, crownD = 20, crownH = 11, blocks = 16, tops = 3, rosettes = 3, trunkH = 12, trunkW = 4.6, baseW = 18, baseD = 16 },
	tall = { scale = 0.6, crownW = 24, crownD = 22, crownH = 18, blocks = 16, tops = 4, rosettes = 3, trunkH = 17, trunkW = 4.2, baseW = 16, baseD = 16 },
	round = { scale = 0.55, crownW = 28, crownD = 28, crownH = 13, blocks = 15, tops = 3, rosettes = 4, trunkH = 13, trunkW = 4.8, baseW = 18, baseD = 18 },
	young = { scale = 0.42, crownW = 26, crownD = 22, crownH = 12, blocks = 12, tops = 2, rosettes = 2, trunkH = 12, trunkW = 4.2, base = false },
}

return BlockTree

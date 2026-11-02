-- Modelos procedurais dos bosses (originais). Devolvem: model, centerHeight, radius.

local ModelKit = require(script.Parent.ModelKit)
local CreatureBuilder = require(script.Parent.CreatureBuilder)

local BossModels = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB

local function newRig(id: string, size: Vector3)
	local rig = ModelKit.newRig(id, size, "HumanoidRootPart")
	rig.root.CanCollide = true
	return rig
end

local function helper(rig, name, parent, joint, at)
	return ModelKit.add(rig, { name = name, parent = parent, joint = joint, at = at, shape = "block", size = V(0.2, 0.2, 0.2), transparency = 1, role = "Detail" }).Name
end

local function add(rig, t)
	return ModelKit.add(rig, t).Name
end

-- ELDERROOT: treant ancestral, tronco com rosto, braços de galho, pernas de raiz e copa.
function BossModels.elderroot()
	local rig = newRig("Elderroot", V(10, 4, 8))
	local bark, darkBark, moss, leaf, glow = rgb(96, 70, 48), rgb(70, 50, 34), rgb(80, 130, 60), rgb(70, 140, 60), rgb(170, 255, 120)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 8, 0), shape = "cyl", size = V(14, 9, 9) , color = bark, material = "Wood", role = "Body" })
	-- o cilindro do Roblox é deitado no eixo X; gira para ficar em pé
	local trunkMotor = rig.root:FindFirstChild("Body") :: Motor6D
	trunkMotor.C0 = CF(0, 8, 0) * ANG(0, 0, rad(90))
	rig.parts[body].CFrame = rig.root.CFrame * trunkMotor.C0
	local face = helper(rig, "Head", body, "Neck", CF(4.2, 0, -3.4) * ANG(0, 0, rad(-90)))
	ModelKit.eyes(rig, face, 1.5, 0.6, -0.6, 1.3, glow, true)
	add(rig, { name = "Brow", parent = face, at = CF(0, 1.6, -0.5) * ANG(rad(-10), 0, 0), shape = "block", size = V(5, 0.9, 1.2), color = darkBark, material = "Wood", role = "Detail" })
	add(rig, { name = "Jaw", parent = face, joint = "Jaw", at = CF(0, -1.6, -0.4), shape = "block", size = V(3.4, 0.9, 1.0), color = rgb(30, 20, 14), role = "Detail" })
	add(rig, { name = "Canopy", parent = face, at = CF(0, 7.0, 2.5), shape = "ball", size = Vector3.one * 12, color = leaf, material = "Grass", role = "Accent" })
	add(rig, { name = "Canopy", parent = face, at = CF(-5, 5.5, 3), shape = "ball", size = Vector3.one * 8, color = moss, material = "Grass", role = "Accent" })
	add(rig, { name = "Canopy", parent = face, at = CF(5, 5.8, 2.5), shape = "ball", size = Vector3.one * 8.5, color = moss, material = "Grass", role = "Accent" })
	for i = 1, 5 do
		local a = i * 1.25
		add(rig, { name = "GlowFruit", parent = face, at = CF(math.cos(a) * 5.5, 5 + math.sin(i) * 1.5, 2 + math.sin(a) * 5), shape = "ball", size = Vector3.one * 1.0, color = glow, material = "Neon", role = "Glow" })
	end
	for _, side in ipairs({ -1, 1 }) do
		local arm = helper(rig, side < 0 and "ArmL" or "ArmR", face, side < 0 and "ArmL" or "ArmR", CF(side * 5.2, 1.5, 1))
		add(rig, { name = "Branch", parent = arm, at = CF(side * 2.8, -1.8, 0) * ANG(0, 0, side * rad(-35)), shape = "block", size = V(7, 1.8, 1.8), color = bark, material = "Wood", role = "Body" })
		add(rig, { name = "Forearm", parent = arm, at = CF(side * 5.5, -5, -0.5) * ANG(0, 0, side * rad(70)), shape = "block", size = V(5.5, 1.5, 1.5), color = bark, material = "Wood", role = "Body" })
		for k = -1, 1 do
			add(rig, { name = "Claw", parent = arm, at = CF(side * (6.2 + k * 0.3), -8, -0.5 + k * 0.8) * ANG(rad(k * 15), 0, side * rad(10)), shape = "wedge", size = V(0.6, 2.2, 0.8), color = darkBark, material = "Wood", role = "Detail" })
		end
		add(rig, { name = "ArmMoss", parent = arm, at = CF(side * 1.5, -0.4, 0), shape = "ellipsoid", size = V(3, 1.4, 3), color = moss, material = "Grass", role = "Accent" })
	end
	for i = 1, 4 do
		local a = (i - 0.5) / 4 * math.pi * 2
		local root = helper(rig, "Root" .. i, face, "Root" .. i, CF(math.cos(a) * 3.2, -6.5, 3.4 + math.sin(a) * 3.2))
		add(rig, { name = "RootLimb", parent = root, at = CF(math.cos(a) * 2, -1.5, math.sin(a) * 2) * ANG(0, -a, rad(-35)), shape = "block", size = V(5, 1.6, 1.6), color = darkBark, material = "Wood", role = "Body" })
	end
	ModelKit.hitbox(rig, V(10, 18, 10), CF(0, 6, 0))
	return rig.model, 2.0, 8
end

-- PRISM TITAN: colosso de cristal com núcleo exposto e coroa de prismas.
function BossModels.prism_titan()
	local rig = newRig("PrismTitan", V(10, 4, 8))
	local rock, crystal, core, pale = rgb(70, 74, 100), rgb(140, 210, 255), rgb(230, 190, 255), rgb(220, 240, 255)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 12, 0), shape = "block", size = V(12, 10, 7), color = rock, material = "Slate", role = "Body" })
	add(rig, { name = "Core", parent = body, at = CF(0, 0.5, -3.4), shape = "ball", size = Vector3.one * 3.6, color = core, material = "Neon", role = "Glow" })
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		add(rig, { name = "CoreShard", parent = body, at = CF(math.cos(a) * 2.6, 0.5 + math.sin(a) * 2.6, -3.6) * ANG(0, 0, a), shape = "wedge", size = V(0.6, 2, 1), color = crystal, material = "Glass", role = "Accent" })
	end
	for i, p in ipairs({ { -4, 6, 1, 7 }, { 4, 6.5, 1, 8 }, { 0, 7, 2, 9 }, { -2, 5.5, 3, 6 }, { 2.5, 5.5, 3, 6.5 } }) do
		add(rig, { name = "BackPrism", parent = body, at = CF(p[1], p[2], p[3]) * ANG(rad(-10), rad(i * 20), rad(-p[1] * 4)), shape = "block", size = V(2, p[4], 2), color = i % 2 == 0 and crystal or pale, material = "Glass", role = "Accent" })
	end
	local head = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 6.5, -1), shape = "block", size = V(4.5, 3.5, 4), color = rock, material = "Slate", role = "Body" })
	add(rig, { name = "Visor", parent = head, at = CF(0, 0.2, -2.02), shape = "block", size = V(3.4, 0.7, 0.1), color = core, material = "Neon", role = "Eye" })
	for i = -2, 2 do
		add(rig, { name = "Crown", parent = head, at = CF(i * 0.9, 2.6 - math.abs(i) * 0.5, 0) * ANG(0, 0, rad(-i * 10)), shape = "wedge", size = V(0.6, 3 - math.abs(i) * 0.6, 1.2), color = crystal, material = "Glass", role = "Accent" })
	end
	for _, side in ipairs({ -1, 1 }) do
		local arm = helper(rig, side < 0 and "ArmL" or "ArmR", body, side < 0 and "ArmL" or "ArmR", CF(side * 7.8, 3, 0))
		add(rig, { name = "Shoulder", parent = arm, at = CF(0, 0.5, 0), shape = "block", size = V(5, 4, 5), color = rock, material = "Slate", role = "Body" })
		add(rig, { name = "ShoulderPrism", parent = arm, at = CF(side * 0.5, 3.5, 0) * ANG(0, rad(45), rad(side * -15)), shape = "block", size = V(1.8, 5, 1.8), color = crystal, material = "Glass", role = "Accent" })
		add(rig, { name = "Arm", parent = arm, at = CF(0, -4.5, 0), shape = "block", size = V(3, 6, 3), color = rock, material = "Slate", role = "Body" })
		add(rig, { name = "CrystalFist", parent = arm, at = CF(0, -8.8, 0) * ANG(rad(45), rad(45), 0), shape = "block", size = V(4.4, 4.4, 4.4), color = pale, material = "Glass", role = "Accent" })
		local leg = helper(rig, side < 0 and "LegL" or "LegR", body, side < 0 and "LegL" or "LegR", CF(side * 3.2, -5, 0))
		add(rig, { name = "Leg", parent = leg, at = CF(0, -2.6, 0), shape = "block", size = V(4, 5.4, 4.4), color = rgb(58, 60, 84), material = "Slate", role = "Body" })
		add(rig, { name = "Knee", parent = leg, at = CF(0, -1.8, -2.3), shape = "ball", size = Vector3.one * 1.4, color = crystal, material = "Neon", role = "Glow" })
	end
	ModelKit.hitbox(rig, V(14, 22, 8), CF(0, 10, 0))
	return rig.model, 2.0, 9
end

-- TEMPEST WYRM: serpe alada de tempestade com corpo segmentado e chifres de relâmpago.
function BossModels.tempest_wyrm()
	-- escala colossal: todas as medidas e deslocamentos multiplicados por K
	local K = 1.6
	local function V(x, y, z)
		return Vector3.new(x * K, y * K, z * K)
	end
	local function CF(x, y, z)
		return CFrame.new(x * K, y * K, z * K)
	end
	local rig = newRig("TempestWyrm", V(8, 6, 8))
	local scale, belly, storm, horn = rgb(70, 100, 160), rgb(200, 215, 240), rgb(130, 220, 255), rgb(240, 230, 170)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 0, 0), shape = "ellipsoid", size = V(7, 6, 9), color = scale, role = "Body" })
	add(rig, { name = "Belly", parent = body, at = CF(0, -1.6, -0.5), shape = "ellipsoid", size = V(5.4, 3, 7.4), color = belly, role = "Belly" })
	local neck = helper(rig, "NeckBase", body, nil, CF(0, 2, -4.4))
	local head = add(rig, { name = "Head", parent = neck, joint = "Neck", at = CF(0, 2.5, -3) * ANG(rad(-10), 0, 0), shape = "ellipsoid", size = V(4.4, 3.4, 6), color = scale, role = "Body" })
	add(rig, { name = "NeckSeg", parent = neck, at = CF(0, 1.2, -1.4) * ANG(rad(-35), 0, 0), shape = "ellipsoid", size = V(3.2, 3.2, 4.4), color = scale, role = "Body" })
	add(rig, { name = "Jaw", parent = head, joint = "Jaw", at = CF(0, -1.4, -1.2), shape = "ellipsoid", size = V(3.6, 1.2, 4.4), color = belly, role = "Belly" })
	ModelKit.eyes(rig, head, 1.2 * K, 0.6 * K, -2.3 * K, 0.8 * K, storm, true)
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "Horn", parent = head, at = CF(side * 1.4, 1.8, 1.4) * ANG(rad(-55), 0, side * rad(-15)), shape = "wedge", size = V(0.8, 4, 1.4), color = horn, role = "Accent" })
		add(rig, { name = "Whisker", parent = head, at = CF(side * 2.0, -0.4, -2.2) * ANG(0, side * rad(30), 0), shape = "cyl", size = V(3.5, 0.3, 0.3), color = storm, material = "Neon", role = "Glow" })
	end
	CreatureBuilder.addWings(rig, { body = scale, belly = rgb(150, 180, 230), accent = storm }, 4.2 * K, body, "membrane", CF(0, 2.2, -1.5), 1.3)
	local prev = body
	for i = 1, 6 do
		local s = 1 - i * 0.12
		prev = add(rig, { name = "Seg" .. i, parent = prev, joint = "Seg" .. i, at = CF(0, -0.2, 4.4 * s + 0.4), shape = "ellipsoid", size = V(6 * s, 5 * s, 6.5 * s), color = i % 2 == 0 and rgb(60, 90, 150) or scale, role = "Body" })
		add(rig, { name = "SegFin", parent = prev, at = CF(0, 2.6 * s, 0) * ANG(0, rad(90), 0), shape = "wedge", size = V(0.4, 2.2 * s, 2.6 * s), color = storm, material = "Neon", role = "Glow" })
	end
	add(rig, { name = "TailBlade", parent = prev, at = CF(0, 0, 3), shape = "wedge", size = V(0.6, 3, 3.5), color = horn, role = "Accent" })
	ModelKit.hitbox(rig, V(10, 9, 22), CF(0, 0, 4))
	return rig.model, 7.0 * K, 9 * K
end

-- THE WILDERBLOOM: guardiã floral — caule colossal, flor-cabeça de pétalas, braços de cipó.
function BossModels.wilderbloom()
	local rig = newRig("Wilderbloom", V(10, 4, 10))
	local stem, petal, inner, leaf, glow = rgb(70, 110, 70), rgb(200, 120, 230), rgb(255, 210, 120), rgb(80, 140, 80), rgb(190, 255, 220)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 9, 0), shape = "ellipsoid", size = V(7, 14, 7), color = stem, material = "Grass", role = "Body" })
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		add(rig, { name = "Leaf", parent = body, at = CF(math.cos(a) * 4, -5 + (i % 2), math.sin(a) * 4) * ANG(0, -a, rad(-55)), shape = "ellipsoid", size = V(9, 0.6, 4), color = leaf, material = "Grass", role = "Accent" })
	end
	local head = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 9, -1), shape = "ball", size = Vector3.one * 6, color = inner, material = "Neon", role = "Glow" })
	ModelKit.eyes(rig, head, 1.1, 0.4, -2.7, 0.9, rgb(60, 20, 70), false)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local p = helper(rig, "Petal" .. i, head, "Petal" .. i, CF(math.cos(a) * 3, math.sin(a) * 3, 0.8))
		add(rig, { name = "PetalBlade", parent = p, at = CF(math.cos(a) * 3, math.sin(a) * 3, 0) * ANG(0, 0, a - math.pi / 2), shape = "ellipsoid", size = V(4, 7.5, 0.8), color = i % 2 == 0 and petal or rgb(230, 150, 240), role = "Body" })
	end
	for _, side in ipairs({ -1, 1 }) do
		local arm = helper(rig, side < 0 and "ArmL" or "ArmR", body, side < 0 and "ArmL" or "ArmR", CF(side * 3.6, 3, 0))
		for k = 1, 4 do
			add(rig, { name = "Vine", parent = arm, at = CF(side * (1.4 + k * 1.6), -k * 1.4, -k * 0.4) * ANG(0, 0, side * rad(-30 - k * 8)), shape = "ellipsoid", size = V(2.6, 1.3, 1.3), color = stem, material = "Grass", role = "Body" })
		end
		add(rig, { name = "Thorn", parent = arm, at = CF(side * 8, -6.4, -1.8), shape = "wedge", size = V(1, 2.6, 1.4), color = rgb(230, 220, 160), role = "Detail" })
		add(rig, { name = "VineBud", parent = arm, at = CF(side * 7.4, -5.8, -1.6), shape = "ball", size = Vector3.one * 1.8, color = petal, role = "Accent" })
	end
	for i = 1, 4 do
		local a = (i - 0.5) / 4 * math.pi * 2
		local r = helper(rig, "Root" .. i, body, "Root" .. i, CF(math.cos(a) * 3.2, -7, math.sin(a) * 3.2))
		add(rig, { name = "RootLimb", parent = r, at = CF(math.cos(a) * 2.4, -0.6, math.sin(a) * 2.4) * ANG(0, -a, rad(-20)), shape = "ellipsoid", size = V(6, 1.8, 2), color = rgb(90, 70, 50), material = "Wood", role = "Body" })
	end
	ModelKit.ring(rig, body, "Orbit", CF(0, 2, 0), 6, 10, Vector3.one * 0.7, glow, "Neon", "Glow")
	ModelKit.hitbox(rig, V(10, 24, 10), CF(0, 10, 0))
	return rig.model, 2.0, 7
end

-- VOID SOVEREIGN: entidade astral coroada, com máscara, manto, mãos gigantes flutuantes e anéis.
function BossModels.void_sovereign()
	local rig = newRig("VoidSovereign", V(8, 6, 8))
	local robe, void, gold, glow, star = rgb(30, 22, 60), rgb(10, 6, 24), rgb(240, 200, 120), rgb(170, 110, 255), rgb(255, 245, 220)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 2, 0), shape = "block", size = V(8, 10, 5), color = robe, material = "Fabric", role = "Body" })
	add(rig, { name = "Mantle", parent = body, at = CF(0, -8, 0.5) * ANG(rad(180), 0, 0), shape = "wedge", size = V(10, 8, 8), color = robe, material = "Fabric", role = "Body" })
	add(rig, { name = "Chest", parent = body, at = CF(0, 1, -2.55), shape = "ball", size = Vector3.one * 3, color = void, material = "Neon", role = "Glow" })
	add(rig, { name = "ChestRim", parent = body, at = CF(0, 1, -2.4) * ANG(0, rad(90), 0), shape = "cyl", size = V(0.3, 4, 4), color = gold, material = "Metal", role = "Accent" })
	for i = 1, 9 do
		local a = i * 2.4
		add(rig, { name = "RobeStar", parent = body, at = CF(math.cos(a) * 3.4, math.sin(a * 1.3) * 4, -2.52), shape = "ball", size = Vector3.one * 0.4, color = star, material = "Neon", role = "Glow" })
	end
	local head = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 7.2, 0), shape = "ellipsoid", size = V(4, 5, 4), color = void, role = "Detail" })
	add(rig, { name = "Mask", parent = head, at = CF(0, 0, -1.8), shape = "ellipsoid", size = V(3.0, 3.8, 0.8), color = rgb(235, 230, 245), material = "Marble", role = "Belly" })
	ModelKit.eyes(rig, head, 0.7, 0.4, -2.25, 0.6, glow, true)
	for i = -3, 3 do
		add(rig, { name = "CrownSpike", parent = head, at = CF(i * 0.75, 3.0 - math.abs(i) * 0.3, 0.2) * ANG(0, 0, rad(-i * 9)), shape = "wedge", size = V(0.5, 3.4 - math.abs(i) * 0.4, 1), color = gold, material = "Metal", role = "Accent" })
	end
	add(rig, { name = "CrownGem", parent = head, at = CF(0, 2.6, -0.6), shape = "ball", size = Vector3.one * 0.9, color = glow, material = "Neon", role = "Glow" })
	for _, side in ipairs({ -1, 1 }) do
		local arm = helper(rig, side < 0 and "ArmL" or "ArmR", body, side < 0 and "ArmL" or "ArmR", CF(side * 9, 1, -2))
		add(rig, { name = "Palm", parent = arm, at = CF(0, 0, 0), shape = "block", size = V(3.4, 4.2, 1.4), color = void, material = "Neon", transparency = 0.1, role = "Glow" })
		for k = -1, 2 do
			add(rig, { name = "Finger", parent = arm, at = CF(k * 0.8 - 0.2, 3.2, 0) * ANG(0, 0, rad(-k * 6)), shape = "block", size = V(0.6, 2.4, 0.7), color = void, material = "Neon", transparency = 0.1, role = "Glow" })
		end
		add(rig, { name = "Bracer", parent = arm, at = CF(0, -2.6, 0), shape = "block", size = V(3.6, 1, 1.6), color = gold, material = "Metal", role = "Accent" })
		add(rig, { name = "Shoulder", parent = body, at = CF(side * 4.6, 4.2, 0), shape = "ball", size = Vector3.one * 3, color = gold, material = "Metal", role = "Accent" })
	end
	ModelKit.ring(rig, body, "Orbit", CF(0, 3, 0) * ANG(rad(12), 0, 0), 9, 14, V(1, 1, 1), glow, "Neon", "Glow", "block")
	ModelKit.ring(rig, body, "Orbit2", CF(0, 6, 0) * ANG(rad(-20), 0, rad(10)), 6.5, 10, Vector3.one * 0.6, star, "Neon", "Glow")
	ModelKit.hitbox(rig, V(10, 24, 8), CF(0, 0, 0))
	return rig.model, 9.0, 8
end

function BossModels.build(id: string)
	local builder = BossModels[id]
	assert(builder, "sem modelo de boss: " .. id)
	local model, centerHeight, radius = builder()
	model:SetAttribute("BossId", id)
	return model, centerHeight, radius
end

return BossModels

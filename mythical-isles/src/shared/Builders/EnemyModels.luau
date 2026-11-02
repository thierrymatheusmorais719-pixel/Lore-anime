-- Modelos procedurais dos inimigos (originais). Cada construtor devolve:
--   model, centerHeight (altura do centro do root acima do chão), radius (raio aproximado)
-- Juntas seguem a convenção do Animator: Body, Neck, Jaw, Leg*, Arm*, Wing*, Tail*, Seg*, Orbit*.

local ModelKit = require(script.Parent.ModelKit)
local CreatureBuilder = require(script.Parent.CreatureBuilder)

local EnemyModels = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB

local function newRig(id: string, w: number, h: number, d: number)
	local rig = ModelKit.newRig(id, V(w, h, d), "HumanoidRootPart")
	rig.root.CanCollide = true
	return rig
end

local function helper(rig, name, parent, joint, at)
	return ModelKit.add(rig, { name = name, parent = parent, joint = joint, at = at, shape = "block", size = V(0.1, 0.1, 0.1), transparency = 1, role = "Detail" }).Name
end

local function add(rig, t)
	return ModelKit.add(rig, t).Name
end

-------------------------------------------------------------------------------
-- VERDANT HAVEN
-------------------------------------------------------------------------------

-- Thornling: bulbo vegetal pequeno com coroa de espinhos e braços de cipó.
function EnemyModels.thornling(tint: Color3?)
	local rig = newRig("Thornling", 2.4, 2, 2.4)
	local green, dark, thorn = tint or rgb(96, 150, 64), rgb(58, 92, 42), rgb(200, 190, 120)
	local body = add(rig, { name = "Torso", joint = "Body", shape = "ellipsoid", size = V(2.2, 2.4, 2.0), color = green, material = "Grass", role = "Body" })
	add(rig, { name = "Belly", parent = body, at = CF(0, -0.2, -0.55), shape = "ellipsoid", size = V(1.5, 1.6, 1.0), color = rgb(180, 200, 110), role = "Belly" })
	local head = helper(rig, "Head", body, "Neck", CF(0, 1.1, 0))
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		add(rig, { name = "Thorn", parent = head, at = CF(math.cos(a) * 0.6, 0.35, math.sin(a) * 0.6) * ANG(math.sin(a) * rad(25), 0, -math.cos(a) * rad(25)),
			shape = "wedge", size = V(0.25, 0.9, 0.35), color = thorn, role = "Accent" })
	end
	add(rig, { name = "Bud", parent = head, at = CF(0, 0.5, 0), shape = "ball", size = Vector3.one * 0.7, color = rgb(230, 80, 90), role = "Accent" })
	ModelKit.eyes(rig, body, 0.42, 0.45, -0.92, 0.38, rgb(255, 230, 90), true)
	add(rig, { name = "Mouth", parent = body, at = CF(0, 0, -0.98), shape = "block", size = V(0.7, 0.12, 0.1), color = rgb(40, 20, 20), role = "Detail" })
	for _, side in ipairs({ -1, 1 }) do
		local arm = helper(rig, side < 0 and "ArmL" or "ArmR", body, side < 0 and "ArmL" or "ArmR", CF(side * 1.05, 0.2, 0))
		add(rig, { name = "Vine", parent = arm, at = CF(side * 0.5, -0.4, -0.2) * ANG(0, 0, side * rad(40)), shape = "cyl", size = V(1.3, 0.25, 0.25), color = dark, role = "Body" })
		add(rig, { name = "Claw", parent = arm, at = CF(side * 1.0, -0.85, -0.3), shape = "wedge", size = V(0.2, 0.5, 0.4), color = thorn, role = "Accent" })
		local leg = helper(rig, side < 0 and "LegL" or "LegR", body, side < 0 and "LegL" or "LegR", CF(side * 0.55, -1.0, 0))
		add(rig, { name = "Root", parent = leg, at = CF(0, -0.35, 0), shape = "ellipsoid", size = V(0.6, 0.8, 0.7), color = dark, material = "Wood", role = "Body" })
	end
	return rig.model, 2.0, 1.3
end

-- Wildroot Guardian: gigante de raízes com ombros de musgo e punhos de tronco.
function EnemyModels.wildroot_guardian()
	local rig = newRig("WildrootGuardian", 3.6, 2, 3)
	local bark, moss, glow = rgb(102, 74, 50), rgb(84, 140, 60), rgb(160, 255, 120)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 1.2, 0), shape = "block", size = V(3.4, 3.6, 2.4), color = bark, material = "Wood", role = "Body" })
	add(rig, { name = "Chest", parent = body, at = CF(0, 0.2, -1.0), shape = "ball", size = Vector3.one * 1.0, color = glow, material = "Neon", role = "Glow" })
	for i = -1, 1 do
		add(rig, { name = "RootStrand", parent = body, at = CF(i * 1.0, 0, -1.22) * ANG(0, 0, rad(i * 8)), shape = "cyl", size = V(3.4, 0.35, 0.35), color = rgb(80, 56, 38), material = "Wood", role = "Detail" })
	end
	local head = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 2.4, -0.2), shape = "block", size = V(1.8, 1.4, 1.6), color = bark, material = "Wood", role = "Body" })
	ModelKit.eyes(rig, head, 0.42, 0.1, -0.82, 0.35, glow, true)
	add(rig, { name = "Canopy", parent = head, at = CF(0, 1.0, 0.2), shape = "ellipsoid", size = V(2.6, 1.3, 2.4), color = moss, material = "Grass", role = "Accent" })
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "ShoulderMoss", parent = body, at = CF(side * 1.9, 1.7, 0), shape = "ellipsoid", size = V(1.6, 1.0, 1.8), color = moss, material = "Grass", role = "Accent" })
		local arm = helper(rig, side < 0 and "ArmL" or "ArmR", body, side < 0 and "ArmL" or "ArmR", CF(side * 2.2, 1.2, 0))
		add(rig, { name = "Arm", parent = arm, at = CF(side * 0.2, -1.4, 0), shape = "block", size = V(1.0, 2.8, 1.0), color = bark, material = "Wood", role = "Body" })
		add(rig, { name = "Fist", parent = arm, at = CF(side * 0.2, -3.1, 0), shape = "block", size = V(1.6, 1.3, 1.6), color = rgb(80, 58, 40), material = "Wood", role = "Belly" })
		local leg = helper(rig, side < 0 and "LegL" or "LegR", body, side < 0 and "LegL" or "LegR", CF(side * 1.0, -1.8, 0))
		add(rig, { name = "Leg", parent = leg, at = CF(0, -0.9, 0), shape = "block", size = V(1.2, 1.9, 1.3), color = rgb(90, 64, 44), material = "Wood", role = "Body" })
	end
	return rig.model, 3.0, 2.2
end

-- Briar Beast: fera quadrúpede coberta de espinhos, chifres de sarça.
function EnemyModels.briar_beast()
	local rig = newRig("BriarBeast", 3.6, 2, 6)
	local hide, thorn, eye = rgb(70, 92, 52), rgb(214, 196, 140), rgb(255, 120, 60)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 0.6, 0), shape = "ellipsoid", size = V(3.6, 3.0, 6.0), color = hide, role = "Body" })
	for i = 1, 14 do
		local z = -2.4 + (i % 7) * 0.8
		local x = (i > 7) and 0.9 or -0.9
		add(rig, { name = "Spike", parent = body, at = CF(x * (0.6 + (i % 2) * 0.3), 1.3, z) * ANG(rad(-20), 0, x * rad(-30)), shape = "wedge", size = V(0.35, 1.2 + (i % 3) * 0.3, 0.6), color = thorn, role = "Accent" })
	end
	local head = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 0.5, -3.2), shape = "ellipsoid", size = V(2.2, 1.9, 2.4), color = hide, role = "Body" })
	add(rig, { name = "Jaw", parent = head, joint = "Jaw", at = CF(0, -0.7, -0.6), shape = "ellipsoid", size = V(1.8, 0.6, 1.6), color = rgb(56, 70, 40), role = "Belly" })
	ModelKit.eyes(rig, head, 0.55, 0.2, -1.0, 0.32, eye, true)
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "Horn", parent = head, at = CF(side * 0.8, 0.9, 0.1) * ANG(rad(-30), 0, side * rad(-35)), shape = "wedge", size = V(0.4, 1.6, 0.7), color = thorn, role = "Accent" })
	end
	for _, leg in ipairs({ { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } }) do
		local l = helper(rig, leg[1], body, leg[1], CF(leg[2] * 1.25, -0.9, leg[3] * 1.9))
		add(rig, { name = "Leg", parent = l, at = CF(0, -0.8, 0), shape = "ellipsoid", size = V(1.0, 1.9, 1.1), color = rgb(60, 78, 44), role = "Body" })
	end
	local tail = helper(rig, "Tail", body, "Tail", CF(0, 0.8, 3.0))
	add(rig, { name = "TailVine", parent = tail, at = CF(0, 0.2, 1.0) * ANG(rad(30), 0, 0), shape = "cyl", size = V(0.3, 0.3, 2.2), color = hide, role = "Body" })
	add(rig, { name = "TailThorn", parent = tail, at = CF(0, 0.7, 1.9), shape = "wedge", size = V(0.3, 0.9, 0.5), color = thorn, role = "Accent" })
	return rig.model, 2.6, 3.0
end

-------------------------------------------------------------------------------
-- CRYSTAL HOLLOW
-------------------------------------------------------------------------------

-- Shard Crawler: aracnídeo baixo de seis patas com placas de cristal.
function EnemyModels.shard_crawler()
	local rig = newRig("ShardCrawler", 3, 2, 3.4)
	local shell, crystal, eye = rgb(60, 64, 86), rgb(120, 220, 255), rgb(140, 240, 255)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 0, 0), shape = "ellipsoid", size = V(2.8, 1.3, 3.2), color = shell, material = "Slate", role = "Body" })
	for i = 1, 5 do
		add(rig, { name = "Plate", parent = body, at = CF((i % 2 == 0 and 0.4 or -0.4), 0.6, -1.0 + i * 0.4) * ANG(rad(-15), rad(i * 30), 0), shape = "block", size = V(0.4, 0.9 + i * 0.1, 0.4), color = crystal, material = "Glass", role = "Accent" })
	end
	local head = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 0.1, -1.7), shape = "ellipsoid", size = V(1.4, 0.9, 1.0), color = shell, material = "Slate", role = "Body" })
	for i = -1, 1 do
		add(rig, { name = "Eye", parent = head, at = CF(i * 0.35, 0.2, -0.45), shape = "ball", size = Vector3.one * 0.26, color = eye, material = "Neon", role = "Eye" })
	end
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "Mandible", parent = head, joint = side < 0 and "JawL" or "JawR", at = CF(side * 0.35, -0.3, -0.55) * ANG(0, side * rad(20), 0), shape = "wedge", size = V(0.2, 0.3, 0.7), color = crystal, material = "Glass", role = "Accent" })
		for i, z in ipairs({ -0.9, 0, 0.9 }) do
			local names = { "F", "M", "B" }
			local jn = "Leg" .. names[i] .. (side < 0 and "L" or "R")
			local l = helper(rig, jn, body, jn, CF(side * 1.2, 0, z))
			add(rig, { name = "LegUpper", parent = l, at = CF(side * 0.6, 0.35, 0) * ANG(0, 0, side * rad(-35)), shape = "block", size = V(1.4, 0.25, 0.25), color = shell, role = "Body" })
			add(rig, { name = "LegLower", parent = l, at = CF(side * 1.25, -0.35, 0) * ANG(0, 0, side * rad(60)), shape = "wedge", size = V(0.25, 1.3, 0.3), color = crystal, material = "Glass", role = "Accent" })
		end
	end
	return rig.model, 1.4, 1.8
end

-- Prism Golem: golem de blocos de cristal com núcleo brilhante.
function EnemyModels.prism_golem()
	local rig = newRig("PrismGolem", 4, 2, 3)
	local rock, crystal, core = rgb(80, 84, 110), rgb(170, 140, 255), rgb(220, 180, 255)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 1.4, 0), shape = "block", size = V(4.0, 3.6, 2.6), color = rock, material = "Slate", role = "Body" })
	add(rig, { name = "Core", parent = body, at = CF(0, 0.3, -1.25), shape = "ball", size = Vector3.one * 1.2, color = core, material = "Neon", role = "Glow" })
	for i, p in ipairs({ { -1.4, 2.0, 0.3 }, { 1.2, 2.2, 0 }, { 0, 2.4, 0.6 }, { 0.6, 1.9, -0.6 } }) do
		add(rig, { name = "BackCrystal", parent = body, at = CF(p[1], p[2], p[3]) * ANG(rad(p[1] * 10), rad(i * 25), rad(-p[1] * 12)), shape = "block", size = V(0.8, 2.2 - i * 0.2, 0.8), color = crystal, material = "Glass", role = "Accent" })
	end
	local head = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 2.4, -0.4), shape = "block", size = V(1.6, 1.2, 1.4), color = rock, material = "Slate", role = "Body" })
	add(rig, { name = "Visor", parent = head, at = CF(0, 0, -0.71), shape = "block", size = V(1.2, 0.25, 0.05), color = core, material = "Neon", role = "Eye" })
	for _, side in ipairs({ -1, 1 }) do
		local arm = helper(rig, side < 0 and "ArmL" or "ArmR", body, side < 0 and "ArmL" or "ArmR", CF(side * 2.6, 1.0, 0))
		add(rig, { name = "Shoulder", parent = arm, at = CF(0, 0.3, 0), shape = "block", size = V(1.6, 1.4, 1.6), color = rock, material = "Slate", role = "Body" })
		add(rig, { name = "Arm", parent = arm, at = CF(0, -1.3, 0), shape = "block", size = V(1.0, 2.2, 1.0), color = rock, material = "Slate", role = "Body" })
		add(rig, { name = "CrystalFist", parent = arm, at = CF(0, -2.8, 0) * ANG(0, rad(45), 0), shape = "block", size = V(1.5, 1.5, 1.5), color = crystal, material = "Glass", role = "Accent" })
		local leg = helper(rig, side < 0 and "LegL" or "LegR", body, side < 0 and "LegL" or "LegR", CF(side * 1.1, -1.8, 0))
		add(rig, { name = "Leg", parent = leg, at = CF(0, -0.8, 0), shape = "block", size = V(1.4, 1.7, 1.5), color = rgb(64, 66, 90), material = "Slate", role = "Body" })
	end
	return rig.model, 3.0, 2.4
end

-- Crystal Devourer: verme colossal com mandíbula de cristal, protege veios raros.
function EnemyModels.crystal_devourer()
	local rig = newRig("CrystalDevourer", 4, 2, 4)
	local hide, crystal, maw = rgb(70, 56, 96), rgb(190, 120, 255), rgb(255, 160, 220)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 0.8, 0), shape = "ellipsoid", size = V(4.0, 3.6, 4.2), color = hide, role = "Body" })
	local head = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 1.6, -2.4) * ANG(rad(-15), 0, 0), shape = "ellipsoid", size = V(3.4, 3.0, 3.2), color = hide, role = "Body" })
	add(rig, { name = "Maw", parent = head, at = CF(0, -0.2, -1.4), shape = "ellipsoid", size = V(2.4, 1.8, 0.6), color = maw, material = "Neon", role = "Glow" })
	add(rig, { name = "Jaw", parent = head, joint = "Jaw", at = CF(0, -1.2, -0.9), shape = "ellipsoid", size = V(2.8, 0.9, 2.6), color = rgb(60, 48, 82), role = "Belly" })
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		add(rig, { name = "Fang", parent = head, at = CF(math.cos(a) * 1.0, math.sin(a) * 0.75 - 0.2, -1.55) * ANG(rad(90), 0, 0), shape = "wedge", size = V(0.2, 0.6, 0.3), color = rgb(240, 240, 255), role = "Detail" })
	end
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "Eye", parent = head, at = CF(side * 1.15, 0.9, -0.9), shape = "ball", size = Vector3.one * 0.45, color = maw, material = "Neon", role = "Eye" })
	end
	local prev = body
	for i = 1, 4 do
		local s = 1 - i * 0.15
		prev = add(rig, { name = "Seg" .. i, parent = prev, joint = "Seg" .. i, at = CF(0, -0.3 * s, 2.6 * s), shape = "ellipsoid", size = V(3.6 * s, 3.0 * s, 3.4 * s), color = hide, role = "Body" })
		add(rig, { name = "SegCrystal", parent = prev, at = CF(0, 1.4 * s, 0) * ANG(0, rad(i * 40), rad(10)), shape = "block", size = V(0.8 * s, 2.0 * s, 0.8 * s), color = crystal, material = "Glass", role = "Accent" })
	end
	return rig.model, 2.6, 3.0
end

-------------------------------------------------------------------------------
-- SKYBOUND KINGDOM
-------------------------------------------------------------------------------

-- Storm Sprite: orbe elétrico espinhoso com asinhas.
function EnemyModels.storm_sprite()
	local rig = newRig("StormSprite", 2.4, 2.4, 2.4)
	local cloud, bolt = rgb(120, 130, 170), rgb(255, 240, 110)
	local body = add(rig, { name = "Torso", joint = "Body", shape = "ball", size = Vector3.one * 2.2, color = cloud, role = "Body" })
	add(rig, { name = "Core", parent = body, at = CF(), shape = "ball", size = Vector3.one * 1.5, color = bolt, material = "Neon", transparency = 0.3, role = "Glow", shadow = false })
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		add(rig, { name = "Spike", parent = body, at = CF(math.cos(a) * 1.1, math.sin(a * 2) * 0.3, math.sin(a) * 1.1) * ANG(0, -a, rad(-90)), shape = "wedge", size = V(0.3, 0.9, 0.3), color = bolt, material = "Neon", role = "Accent" })
	end
	ModelKit.eyes(rig, body, 0.4, 0.2, -1.0, 0.36, rgb(255, 255, 255), true)
	CreatureBuilder.addWings(rig, { body = cloud, belly = rgb(200, 210, 240), accent = bolt }, 0.7, body, "feather", CF(0, 0.4, 0.3), 1)
	local orbit = add(rig, { name = "Orbit", parent = body, joint = "Orbit", shape = "block", size = Vector3.one * 0.2, transparency = 1, role = "Detail" })
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		add(rig, { name = "Spark", parent = orbit, at = CF(math.cos(a) * 1.9, 0, math.sin(a) * 1.9), shape = "ball", size = Vector3.one * 0.3, color = bolt, material = "Neon", role = "Glow", shadow = false })
	end
	return rig.model, 1.2, 1.4
end

-- Cloud Stalker: predador esguio de pelagem de nuvem e cauda de relâmpago.
function EnemyModels.cloud_stalker()
	local rig = newRig("CloudStalker", 2.8, 2, 5)
	local fur, dark, bolt = rgb(225, 230, 245), rgb(120, 130, 170), rgb(110, 200, 255)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 0.6, 0), shape = "ellipsoid", size = V(2.4, 2.2, 4.8), color = fur, role = "Body" })
	for i = 1, 5 do
		add(rig, { name = "Puff", parent = body, at = CF((i % 2 == 0 and 0.6 or -0.6), 0.9, -1.8 + i * 0.7), shape = "ball", size = Vector3.one * 1.2, color = rgb(245, 248, 255), role = "Belly" })
	end
	local neck = helper(rig, "Head", body, "Neck", CF(0, 1.0, -2.4))
	add(rig, { name = "NeckFur", parent = neck, at = CF(0, 0.6, -0.4) * ANG(rad(40), 0, 0), shape = "ellipsoid", size = V(1.0, 2.0, 1.0), color = fur, role = "Body" })
	local skull = add(rig, { name = "Skull", parent = neck, at = CF(0, 1.5, -1.2), shape = "ellipsoid", size = V(1.4, 1.2, 2.0), color = dark, role = "Accent" })
	add(rig, { name = "Jaw", parent = skull, joint = "Jaw", at = CF(0, -0.45, -0.5), shape = "ellipsoid", size = V(1.0, 0.4, 1.4), color = rgb(90, 96, 130), role = "Belly" })
	ModelKit.eyes(rig, skull, 0.4, 0.15, -0.75, 0.28, bolt, true)
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "Ear", parent = skull, at = CF(side * 0.45, 0.65, 0.4) * ANG(rad(-35), 0, 0), shape = "wedge", size = V(0.2, 0.8, 0.5), color = dark, role = "Accent" })
	end
	for _, leg in ipairs({ { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } }) do
		local l = helper(rig, leg[1], body, leg[1], CF(leg[2] * 0.8, -0.6, leg[3] * 1.6))
		add(rig, { name = "Leg", parent = l, at = CF(0, -0.8, 0), shape = "ellipsoid", size = V(0.55, 2.0, 0.6), color = dark, role = "Accent" })
	end
	local tail = helper(rig, "Tail", body, "Tail", CF(0, 0.8, 2.4))
	for i = 1, 3 do
		add(rig, { name = "TailBolt", parent = tail, at = CF((i % 2 == 0) and 0.3 or -0.3, 0.4 * i, 0.6 * i) * ANG(rad(40), 0, rad(i % 2 == 0 and 30 or -30)), shape = "block", size = V(0.25, 0.25, 0.9), color = bolt, material = "Neon", role = "Glow" })
	end
	return rig.model, 2.4, 2.6
end

-- Tempest Guardian: cavaleiro de pedra com asas de rocha e núcleo de tempestade.
function EnemyModels.tempest_guardian()
	local rig = newRig("TempestGuardian", 4, 2, 3)
	local stone, trim, storm = rgb(150, 156, 175), rgb(230, 200, 110), rgb(120, 200, 255)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 1.6, 0), shape = "block", size = V(3.4, 3.8, 2.2), color = stone, material = "Limestone", role = "Body" })
	add(rig, { name = "Core", parent = body, at = CF(0, 0.4, -1.1), shape = "ball", size = Vector3.one * 1.1, color = storm, material = "Neon", role = "Glow" })
	add(rig, { name = "Belt", parent = body, at = CF(0, -1.5, 0), shape = "block", size = V(3.6, 0.5, 2.4), color = trim, material = "Metal", role = "Accent" })
	local head = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 2.6, -0.2), shape = "block", size = V(1.5, 1.6, 1.5), color = stone, material = "Limestone", role = "Body" })
	add(rig, { name = "Visor", parent = head, at = CF(0, 0.1, -0.76), shape = "block", size = V(1.1, 0.2, 0.05), color = storm, material = "Neon", role = "Eye" })
	add(rig, { name = "Plume", parent = head, at = CF(0, 1.0, 0.2) * ANG(0, rad(90), 0), shape = "wedge", size = V(0.2, 1.0, 1.4), color = trim, material = "Metal", role = "Accent" })
	for _, side in ipairs({ -1, 1 }) do
		local wing = helper(rig, side < 0 and "WingL" or "WingR", body, side < 0 and "WingL" or "WingR", CF(side * 1.0, 1.4, 1.1))
		for i = 0, 2 do
			add(rig, { name = "StoneFeather", parent = wing, at = CF(side * (1.0 + i * 0.9), 0.6 - i * 0.5, 0.2) * ANG(0, 0, side * rad(-20 - i * 15)), shape = "wedge", size = V(0.3, 2.6 - i * 0.5, 1.0), color = stone, material = "Limestone", role = "Body" })
		end
		local arm = helper(rig, side < 0 and "ArmL" or "ArmR", body, side < 0 and "ArmL" or "ArmR", CF(side * 2.3, 1.2, 0))
		add(rig, { name = "Pauldron", parent = arm, at = CF(0, 0.3, 0), shape = "block", size = V(1.4, 1.0, 1.4), color = trim, material = "Metal", role = "Accent" })
		add(rig, { name = "Arm", parent = arm, at = CF(0, -1.3, 0), shape = "block", size = V(0.9, 2.4, 0.9), color = stone, material = "Limestone", role = "Body" })
		add(rig, { name = "Gauntlet", parent = arm, at = CF(0, -2.8, 0), shape = "block", size = V(1.3, 1.1, 1.3), color = trim, material = "Metal", role = "Accent" })
		local leg = helper(rig, side < 0 and "LegL" or "LegR", body, side < 0 and "LegL" or "LegR", CF(side * 0.9, -1.9, 0))
		add(rig, { name = "Leg", parent = leg, at = CF(0, -0.9, 0), shape = "block", size = V(1.2, 1.9, 1.3), color = stone, material = "Limestone", role = "Body" })
	end
	return rig.model, 3.2, 2.4
end

-------------------------------------------------------------------------------
-- WHISPERING WILDS
-------------------------------------------------------------------------------

-- Mist Prowler: felino furtivo e translúcido com rastro de névoa.
function EnemyModels.mist_prowler()
	local rig = newRig("MistProwler", 2.6, 2, 5)
	local shade, mist, eye = rgb(52, 50, 72), rgb(170, 180, 210), rgb(190, 255, 220)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 0.3, 0), shape = "ellipsoid", size = V(2.2, 1.8, 4.6), color = shade, transparency = 0.15, role = "Body" })
	add(rig, { name = "Stripe", parent = body, at = CF(0, 0.8, 0), shape = "ellipsoid", size = V(0.5, 0.3, 3.6), color = mist, material = "Neon", transparency = 0.4, role = "Glow" })
	local head = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 0.5, -2.4), shape = "ellipsoid", size = V(1.6, 1.3, 1.7), color = shade, transparency = 0.1, role = "Body" })
	add(rig, { name = "Jaw", parent = head, joint = "Jaw", at = CF(0, -0.45, -0.55), shape = "ellipsoid", size = V(1.0, 0.4, 0.9), color = rgb(40, 38, 58), role = "Belly" })
	ModelKit.eyes(rig, head, 0.38, 0.15, -0.72, 0.28, eye, true)
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "Ear", parent = head, at = CF(side * 0.5, 0.7, 0.1) * ANG(0, 0, side * rad(-12)), shape = "wedge", size = V(0.2, 0.8, 0.5), color = shade, role = "Body" })
	end
	for _, leg in ipairs({ { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } }) do
		local l = helper(rig, leg[1], body, leg[1], CF(leg[2] * 0.75, -0.5, leg[3] * 1.5))
		add(rig, { name = "Leg", parent = l, at = CF(0, -0.6, 0), shape = "ellipsoid", size = V(0.55, 1.5, 0.6), color = shade, transparency = 0.15, role = "Body" })
	end
	local tail = helper(rig, "Tail", body, "Tail", CF(0, 0.5, 2.3))
	add(rig, { name = "TailMist", parent = tail, at = CF(0, 0.4, 1.2) * ANG(rad(30), 0, 0), shape = "ellipsoid", size = V(0.5, 0.5, 2.6), color = mist, transparency = 0.35, role = "Accent" })
	return rig.model, 1.8, 2.4
end

-- Hollow Stag: cervo guardião com tronco oco, coração luminoso e galhada enorme.
function EnemyModels.hollow_stag()
	local rig = newRig("HollowStag", 3, 2, 5)
	local wood, glow, moss = rgb(110, 92, 72), rgb(255, 220, 140), rgb(90, 130, 80)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 1.0, 0), shape = "ellipsoid", size = V(2.6, 2.6, 4.6), color = wood, material = "Wood", role = "Body" })
	add(rig, { name = "Hollow", parent = body, at = CF(0, 0, -0.2), shape = "ellipsoid", size = V(2.65, 1.4, 2.2), color = rgb(30, 22, 18), role = "Detail" })
	add(rig, { name = "Heart", parent = body, at = CF(0, 0, -0.2), shape = "ball", size = Vector3.one * 0.9, color = glow, material = "Neon", role = "Glow" })
	add(rig, { name = "Moss", parent = body, at = CF(0, 1.2, 0.4), shape = "ellipsoid", size = V(1.8, 0.5, 2.6), color = moss, material = "Grass", role = "Accent" })
	local neck = helper(rig, "Head", body, "Neck", CF(0, 1.4, -2.0))
	add(rig, { name = "NeckWood", parent = neck, at = CF(0, 0.8, -0.3) * ANG(rad(25), 0, 0), shape = "ellipsoid", size = V(1.0, 2.2, 1.0), color = wood, material = "Wood", role = "Body" })
	local skull = add(rig, { name = "Skull", parent = neck, at = CF(0, 2.0, -0.9), shape = "ellipsoid", size = V(1.2, 1.1, 1.9), color = rgb(225, 215, 190), role = "Belly" })
	ModelKit.eyes(rig, skull, 0.38, 0.15, -0.55, 0.26, glow, true)
	for _, side in ipairs({ -1, 1 }) do
		local base = CF(side * 0.4, 0.5, 0.2)
		add(rig, { name = "Antler", parent = skull, at = base * ANG(0, 0, side * rad(-30)) * CF(0, 1.1, 0), shape = "cyl", size = V(0.25, 2.4, 0.25), color = wood, material = "Wood", role = "Accent" })
		for k = 1, 3 do
			add(rig, { name = "Tine", parent = skull, at = base * CF(side * (0.5 + k * 0.4), 0.8 + k * 0.6, 0) * ANG(0, 0, side * rad(-70 + k * 15)) * ANG(0, 0, rad(90)), shape = "cyl", size = V(1.0, 0.18, 0.18), color = wood, material = "Wood", role = "Accent" })
		end
		add(rig, { name = "AntlerGlow", parent = skull, at = base * CF(side * 1.5, 2.6, 0), shape = "ball", size = Vector3.one * 0.35, color = glow, material = "Neon", role = "Glow" })
	end
	for _, leg in ipairs({ { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } }) do
		local l = helper(rig, leg[1], body, leg[1], CF(leg[2] * 0.85, -1.0, leg[3] * 1.6))
		add(rig, { name = "Leg", parent = l, at = CF(0, -1.0, 0), shape = "cyl", size = V(2.2, 0.45, 0.45), color = wood, material = "Wood", role = "Body" })
		ModelKit.add(rig, { name = "Hoof", parent = l, at = CF(0, -2.1, 0), shape = "block", size = V(0.5, 0.3, 0.6), color = rgb(50, 40, 30), role = "Detail" })
	end
	return rig.model, 3.3, 2.6
end

-- Ancient Bloom Beast: tartaruga colossal com uma árvore florida no casco.
function EnemyModels.ancient_bloom_beast()
	local rig = newRig("AncientBloomBeast", 6, 2, 7)
	local shell, skin, leaf, bloom = rgb(96, 84, 64), rgb(110, 130, 90), rgb(90, 150, 80), rgb(255, 160, 210)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 1.0, 0), shape = "ellipsoid", size = V(6.4, 3.6, 7.4), color = shell, material = "Slate", role = "Body" })
	add(rig, { name = "Rim", parent = body, at = CF(0, -0.9, 0), shape = "ellipsoid", size = V(7.0, 1.2, 8.0), color = rgb(80, 70, 54), material = "Slate", role = "Belly" })
	add(rig, { name = "Trunk", parent = body, at = CF(0, 2.6, 0.4), shape = "cyl", size = V(3.0, 0.9, 0.9), color = rgb(100, 72, 50), material = "Wood", role = "Detail" })
	for i, p in ipairs({ { 0, 4.4, 0.4, 3.6 }, { -1.4, 3.8, 0.8, 2.4 }, { 1.4, 3.9, -0.2, 2.6 } }) do
		add(rig, { name = "Canopy", parent = body, at = CF(p[1], p[2], p[3]), shape = "ball", size = Vector3.one * p[4], color = leaf, material = "Grass", role = "Accent" })
		for k = 1, 3 do
			local a = k * 2.1 + i
			add(rig, { name = "Blossom", parent = body, at = CF(p[1] + math.cos(a) * p[4] * 0.45, p[2] + 0.4, p[3] + math.sin(a) * p[4] * 0.45), shape = "ball", size = Vector3.one * 0.6, color = bloom, material = "Neon", role = "Glow" })
		end
	end
	local head = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 0.2, -4.4), shape = "ellipsoid", size = V(2.4, 2.0, 2.6), color = skin, role = "Body" })
	add(rig, { name = "Jaw", parent = head, joint = "Jaw", at = CF(0, -0.7, -0.6), shape = "ellipsoid", size = V(2.0, 0.6, 1.8), color = rgb(90, 108, 72), role = "Belly" })
	ModelKit.eyes(rig, head, 0.6, 0.35, -0.95, 0.35, rgb(255, 230, 120), true)
	for _, leg in ipairs({ { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } }) do
		local l = helper(rig, leg[1], body, leg[1], CF(leg[2] * 2.6, -1.0, leg[3] * 2.6))
		add(rig, { name = "Leg", parent = l, at = CF(0, -0.9, 0), shape = "cyl", size = V(2.0, 1.6, 1.6), color = skin, role = "Body" })
	end
	return rig.model, 3.0, 4.0
end

-------------------------------------------------------------------------------
-- ASTRAL SANCTUARY
-------------------------------------------------------------------------------

-- Astral Sentinel: construto flutuante com mãos separadas e anel de runas.
function EnemyModels.astral_sentinel()
	local rig = newRig("AstralSentinel", 3, 3, 3)
	local armor, gold, glow = rgb(60, 56, 96), rgb(240, 200, 120), rgb(160, 200, 255)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 0.6, 0), shape = "block", size = V(2.6, 2.8, 1.8), color = armor, material = "Metal", role = "Body" })
	add(rig, { name = "Trim", parent = body, at = CF(0, 0, -0.91), shape = "block", size = V(0.4, 2.6, 0.05), color = gold, material = "Neon", role = "Accent" })
	add(rig, { name = "Skirt", parent = body, at = CF(0, -1.9, 0) * ANG(rad(180), 0, 0), shape = "wedge", size = V(2.2, 1.4, 1.6), color = armor, material = "Metal", role = "Body" })
	local head = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 2.1, 0), shape = "block", size = V(1.3, 1.4, 1.3), color = armor, material = "Metal", role = "Body" })
	add(rig, { name = "Visor", parent = head, at = CF(0, 0.1, -0.66), shape = "block", size = V(0.25, 0.9, 0.05), color = glow, material = "Neon", role = "Eye" })
	add(rig, { name = "Crest", parent = head, at = CF(0, 1.0, 0) * ANG(0, rad(90), 0), shape = "wedge", size = V(0.15, 0.8, 1.2), color = gold, material = "Metal", role = "Accent" })
	for _, side in ipairs({ -1, 1 }) do
		local arm = helper(rig, side < 0 and "ArmL" or "ArmR", body, side < 0 and "ArmL" or "ArmR", CF(side * 2.3, 0.3, -0.3))
		add(rig, { name = "Hand", parent = arm, at = CF(0, 0, 0), shape = "block", size = V(0.9, 1.2, 0.9), color = armor, material = "Metal", role = "Body" })
		add(rig, { name = "HandGlow", parent = arm, at = CF(0, -0.7, 0), shape = "ball", size = Vector3.one * 0.6, color = glow, material = "Neon", role = "Glow" })
		add(rig, { name = "Pauldron", parent = body, at = CF(side * 1.5, 1.2, 0), shape = "ball", size = Vector3.one * 1.2, color = gold, material = "Metal", role = "Accent" })
	end
	ModelKit.ring(rig, body, "Orbit", CF(0, -0.2, 0.2) * ANG(rad(70), 0, 0), 2.0, 8, V(0.35, 0.35, 0.35), glow, "Neon", "Glow", "block")
	return rig.model, 2.2, 2.0
end

-- Rift Keeper: guardião encapuzado com um portal em anel às costas.
function EnemyModels.rift_keeper()
	local rig = newRig("RiftKeeper", 3, 2, 3)
	local robe, void, gold, glow = rgb(40, 30, 70), rgb(20, 10, 40), rgb(230, 190, 110), rgb(190, 120, 255)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 1.4, 0), shape = "block", size = V(2.6, 3.2, 1.8), color = robe, material = "Fabric", role = "Body" })
	add(rig, { name = "Robe", parent = body, at = CF(0, -2.2, 0) * ANG(rad(180), 0, 0), shape = "wedge", size = V(3.0, 2.0, 2.4), color = robe, material = "Fabric", role = "Body" })
	add(rig, { name = "Sash", parent = body, at = CF(0, -0.4, -0.91), shape = "block", size = V(0.5, 2.2, 0.05), color = gold, material = "Metal", role = "Accent" })
	local head = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 2.2, 0), shape = "ellipsoid", size = V(1.6, 1.8, 1.6), color = robe, material = "Fabric", role = "Body" })
	add(rig, { name = "Face", parent = head, at = CF(0, -0.1, -0.55), shape = "ellipsoid", size = V(1.0, 1.1, 0.5), color = void, role = "Detail" })
	ModelKit.eyes(rig, head, 0.25, 0, -0.78, 0.22, glow, true)
	for _, side in ipairs({ -1, 1 }) do
		local arm = helper(rig, side < 0 and "ArmL" or "ArmR", body, side < 0 and "ArmL" or "ArmR", CF(side * 1.6, 1.1, 0))
		add(rig, { name = "Sleeve", parent = arm, at = CF(side * 0.2, -1.1, 0), shape = "ellipsoid", size = V(0.9, 2.4, 0.9), color = robe, material = "Fabric", role = "Body" })
		add(rig, { name = "Hand", parent = arm, at = CF(side * 0.2, -2.4, 0), shape = "ball", size = Vector3.one * 0.6, color = glow, material = "Neon", role = "Glow" })
	end
	local staffArm = rig.parts.ArmR
	add(rig, { name = "Staff", parent = staffArm.Name, at = CF(0.3, -1.6, -0.4), shape = "cyl", size = V(0.25, 5.0, 0.25) * V(1, 1, 1), color = gold, material = "Metal", role = "Accent" })
	local portal = add(rig, { name = "Orbit", parent = body, joint = "Orbit", at = CF(0, 1.2, 1.5), shape = "block", size = Vector3.one * 0.2, transparency = 1, role = "Detail" })
	add(rig, { name = "PortalCore", parent = portal, at = CF() * ANG(0, 0, rad(90)), shape = "cyl", size = V(0.1, 3.0, 3.0), color = void, material = "Neon", transparency = 0.2, role = "Glow" })
	ModelKit.ring(rig, portal, nil, ANG(rad(90), 0, 0), 1.7, 12, V(0.35, 0.35, 0.35), glow, "Neon", "Glow")
	return rig.model, 3.4, 2.0
end

-------------------------------------------------------------------------------
-- EVENTOS
-------------------------------------------------------------------------------

-- Estrela Errante: estrela de cinco pontas que foge (evento secreto).
function EnemyModels.wandering_star()
	local rig = newRig("WanderingStar", 2.5, 2.5, 1)
	local gold, core = rgb(255, 230, 140), rgb(255, 255, 230)
	local body = add(rig, { name = "Torso", joint = "Body", shape = "ball", size = Vector3.one * 1.4, color = core, material = "Neon", role = "Glow" })
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		add(rig, { name = "Point", parent = body, at = CF(math.sin(a) * 1.0, math.cos(a) * 1.0, 0) * ANG(0, 0, -a), shape = "wedge", size = V(0.35, 1.2, 0.6), color = gold, material = "Neon", role = "Glow" })
	end
	ModelKit.eyes(rig, body, 0.25, 0.1, -0.62, 0.22, rgb(60, 40, 20), false)
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 14
	light.Brightness = 2
	light.Parent = rig.parts.Torso
	return rig.model, 1.5, 1.4
end

-- Alias: brotos da Wilderbloom usam o modelo do Thornling com outra cor.
function EnemyModels.wilderbloom_sprout(tint: Color3?)
	return EnemyModels.thornling(tint or rgb(200, 120, 220))
end

function EnemyModels.build(id: string, cfg)
	local builder = EnemyModels[cfg and cfg.model or id] or EnemyModels[id]
	assert(builder, "sem modelo para " .. id)
	local model, centerHeight, radius = builder(cfg and cfg.tint)
	model:SetAttribute("EnemyId", id)
	return model, centerHeight, radius
end

return EnemyModels

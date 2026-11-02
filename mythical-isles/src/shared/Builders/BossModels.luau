-- Modelos procedurais dos bosses, baseados na arte conceitual do autor (docs/concept/bosses.png).
-- Cada construtor devolve: model, centerHeight (altura do centro do root acima do chão), radius.
-- Juntas seguem a convenção do Animator: Body, Neck, Jaw, ArmL/R, LegL/R, LegFL..., WingL/R,
-- Seg1.. (cauda), Petal1.., Root1.. (cipós), Orbit* (anéis/cristais que giram).

local ModelKit = require(script.Parent.ModelKit)

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

-- Cristal pontudo: corpo + ponta em cumeeira (duas cunhas). `at` já inclui a inclinação.
local function crystal(rig, parent: string, at: CFrame, h: number, w: number, color: Color3, material: string?)
	local mat = material or "Neon"
	local bodyH = h * 0.7
	local tipH = h * 0.3
	add(rig, { name = "Crystal", parent = parent, at = at * CF(0, bodyH / 2, 0), shape = "block", size = V(w, bodyH, w), color = color, material = mat, role = "Glow" })
	add(rig, { name = "CrystalTip", parent = parent, at = at * CF(0, bodyH + tipH / 2, -w / 4), shape = "wedge", size = V(w, tipH, w / 2), color = color, material = mat, role = "Glow" })
	add(rig, { name = "CrystalTip", parent = parent, at = at * CF(0, bodyH + tipH / 2, w / 4) * ANG(0, math.pi, 0), shape = "wedge", size = V(w, tipH, w / 2),
		color = color, material = mat, role = "Glow" })
end

-- Leque de cristais (ombros, costas, coroas).
local function cluster(rig, parent: string, at: CFrame, count: number, h: number, w: number, color: Color3, spread: number?)
	spread = spread or 28
	for i = 1, count do
		local t = (count == 1) and 0 or ((i - 1) / (count - 1) - 0.5)
		local scale = 1 - math.abs(t) * 0.55
		crystal(rig, parent, at * CF(t * w * 2.2, 0, (i % 2) * w * 0.4) * ANG(rad((i % 2) * 10 - 5), 0, rad(-t * spread * 2)), h * scale, w * scale, color)
	end
end

-- Triângulo 3D (a, b, c no espaço da peça pai) feito com duas cunhas — membranas de asa.
local function triangle(rig, parent: string, a: Vector3, b: Vector3, c: Vector3, thickness: number, color: Color3, transparency: number?)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local d1, d2 = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
	if height < 0.05 then
		return
	end
	if d1 > 0.05 then
		add(rig, { name = "Membrane", parent = parent, at = CFrame.fromMatrix((a + b) / 2, right, up, back), shape = "wedge", size = V(thickness, height, d1),
			color = color, transparency = transparency, role = "Belly" })
	end
	if d2 > 0.05 then
		add(rig, { name = "Membrane", parent = parent, at = CFrame.fromMatrix((a + c) / 2, -right, up, -back), shape = "wedge", size = V(thickness, height, d2),
			color = color, transparency = transparency, role = "Belly" })
	end
end

-- Osso/bastão entre dois pontos (no espaço da peça pai).
local function bone(rig, parent: string, a: Vector3, b: Vector3, thick: number, color: Color3, material: string?)
	local mid = (a + b) / 2
	add(rig, { name = "Bone", parent = parent, at = CFrame.lookAt(mid, b), shape = "block", size = V(thick, thick, (b - a).Magnitude), color = color, material = material or "Metal", role = "Accent" })
end

-- Rachadura brilhante (linha fina de neon).
local function crack(rig, parent: string, at: CFrame, len: number, color: Color3)
	add(rig, { name = "Crack", parent = parent, at = at, shape = "block", size = V(0.35, len, 0.2), color = color, material = "Neon", role = "Glow", shadow = false })
end

-------------------------------------------------------------------------------
-- ELDERROOT — gigante de casca e madeira com cristais verdes e galhos-chifre.
-------------------------------------------------------------------------------
function BossModels.elderroot()
	local rig = newRig("Elderroot", V(10, 4, 8))
	local bark, dark, moss, glow = rgb(96, 66, 40), rgb(62, 42, 26), rgb(86, 140, 50), rgb(90, 255, 80)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 4, 0), shape = "block", size = V(10, 9, 7), color = bark, material = "Wood", role = "Body" })
	add(rig, { name = "Pelvis", parent = body, at = CF(0, -5.5, 0.3), shape = "block", size = V(8, 3.5, 6), color = dark, material = "Wood", role = "Body" })
	-- placas de casca sobrepostas no peito
	for i, x in ipairs({ -3, 0, 3 }) do
		add(rig, { name = "BarkPlate", parent = body, at = CF(x, 1.5 - (i % 2), -3.6) * ANG(rad(-8), 0, rad(x * 3)), shape = "block", size = V(3.2, 4.2, 0.8), color = dark, material = "Wood", role = "Detail" })
	end
	crystal(rig, body, CF(0, -1.2, -4.0) * ANG(rad(-90), 0, 0), 3.4, 2.2, glow) -- cristal do peito (aponta para frente)
	crack(rig, body, CF(-2, -1.5, -3.9) * ANG(0, 0, rad(20)), 4, glow)
	crack(rig, body, CF(2.4, -2, -3.9) * ANG(0, 0, rad(-25)), 3.5, glow)
	crack(rig, body, CF(0.5, 2.6, -3.95) * ANG(0, 0, rad(70)), 3, glow)
	add(rig, { name = "BackMoss", parent = body, at = CF(0, 3.8, 1.5), shape = "ellipsoid", size = V(9, 2.2, 6), color = moss, material = "Grass", role = "Accent" })
	cluster(rig, body, CF(0, 4, 2.6) * ANG(rad(25), 0, 0), 3, 6, 1.6, glow, 22)
	-- cabeça com galhos-chifre, cristais e mandíbula
	local neck = helper(rig, "NeckBase", body, nil, CF(0, 4.6, -0.8))
	local head = add(rig, { name = "Head", parent = neck, joint = "Neck", at = CF(0, 2.2, -0.6), shape = "block", size = V(4.6, 4, 4.2), color = bark, material = "Wood", role = "Body" })
	add(rig, { name = "Brow", parent = head, at = CF(0, 1, -2.2) * ANG(rad(-20), 0, 0), shape = "wedge", size = V(4.8, 1.2, 1.4), color = dark, material = "Wood", role = "Detail" })
	ModelKit.eyes(rig, head, 1.1, 0.35, -2.15, 0.9, glow, true)
	add(rig, { name = "Jaw", parent = head, joint = "Jaw", at = CF(0, -2.2, -0.5), shape = "block", size = V(3.8, 1.3, 3.4), color = dark, material = "Wood", role = "Belly" })
	for i = -1, 1 do
		add(rig, { name = "Fang", parent = head, at = CF(i * 1.1, -1.5, -2.15) * ANG(rad(180), 0, 0), shape = "wedge", size = V(0.5, 0.9, 0.4), color = rgb(220, 230, 180), role = "Detail" })
	end
	for _, side in ipairs({ -1, 1 }) do
		local base = CF(side * 1.6, 2, 0.4)
		add(rig, { name = "Antler", parent = head, at = base * ANG(0, 0, side * rad(-28)) * CF(0, 2.2, 0), shape = "block", size = V(0.8, 4.6, 0.8), color = dark, material = "Wood", role = "Accent" })
		add(rig, { name = "AntlerTine", parent = head, at = base * CF(side * 2.4, 4.4, 0) * ANG(0, 0, side * rad(-65)) * CF(0, 1.2, 0), shape = "block", size = V(0.55, 2.6, 0.55), color = dark, material = "Wood", role = "Accent" })
		add(rig, { name = "AntlerTine", parent = head, at = base * CF(side * 1.5, 4.2, 0) * ANG(rad(-20), 0, side * rad(5)) * CF(0, 1.3, 0), shape = "block", size = V(0.5, 2.6, 0.5), color = dark, material = "Wood", role = "Accent" })
		crystal(rig, head, CF(side * 1.5, 2, -0.8) * ANG(rad(-10), 0, side * rad(-20)), 3.2, 1.0, glow)
	end
	-- ombros com cristais + braços enormes
	for _, side in ipairs({ -1, 1 }) do
		local jn = side < 0 and "ArmL" or "ArmR"
		local arm = helper(rig, jn, body, jn, CF(side * 6.6, 2.4, 0))
		add(rig, { name = "Shoulder", parent = arm, at = CF(0, 0.6, 0), shape = "block", size = V(4.4, 3.8, 4.4), color = bark, material = "Wood", role = "Body" })
		add(rig, { name = "ShoulderMoss", parent = arm, at = CF(0, 2.5, 0), shape = "ellipsoid", size = V(4.6, 1.4, 4.4), color = moss, material = "Grass", role = "Accent" })
		cluster(rig, arm, CF(side * 0.6, 2.6, 0.3) * ANG(0, 0, side * rad(-15)), 3, 5.5, 1.3, glow, 30)
		add(rig, { name = "UpperArm", parent = arm, at = CF(side * 0.3, -3.5, 0), shape = "block", size = V(3.2, 5.5, 3.2), color = bark, material = "Wood", role = "Body" })
		add(rig, { name = "Forearm", parent = arm, at = CF(side * 0.4, -8.4, -0.4), shape = "block", size = V(3.9, 5, 3.9), color = dark, material = "Wood", role = "Body" })
		crack(rig, arm, CF(side * 0.4, -8.4, -2.4), 3.6, glow)
		add(rig, { name = "Fist", parent = arm, at = CF(side * 0.4, -12, -0.8), shape = "block", size = V(5, 4, 5), color = bark, material = "Wood", role = "Belly" })
		for k = -1, 1 do
			add(rig, { name = "Knuckle", parent = arm, at = CF(side * 0.4 + k * 1.5, -11, -3.4), shape = "block", size = V(1.2, 1.2, 1.2), color = dark, material = "Wood", role = "Detail" })
		end
		crystal(rig, arm, CF(side * 1.8, -10, 0.6) * ANG(0, 0, side * rad(-60)), 2.4, 0.9, glow)
		-- pernas
		local ln = side < 0 and "LegL" or "LegR"
		local leg = helper(rig, ln, body, ln, CF(side * 2.8, -7.5, 0))
		add(rig, { name = "Thigh", parent = leg, at = CF(0, -2, 0), shape = "block", size = V(3.4, 4.5, 3.6), color = bark, material = "Wood", role = "Body" })
		add(rig, { name = "Shin", parent = leg, at = CF(0, -5.6, 0), shape = "block", size = V(3.8, 4.5, 4), color = dark, material = "Wood", role = "Body" })
		add(rig, { name = "Foot", parent = leg, at = CF(0, -8.4, -0.7), shape = "block", size = V(4.4, 1.6, 5.4), color = bark, material = "Wood", role = "Belly" })
		for k = -1, 1 do
			add(rig, { name = "Claw", parent = leg, at = CF(k * 1.4, -8.5, -3.8) * ANG(rad(-90), 0, 0), shape = "wedge", size = V(0.8, 1.2, 1.2), color = rgb(200, 210, 160), role = "Detail" })
		end
	end
	ModelKit.hitbox(rig, V(14, 26, 10), CF(0, 2, 0))
	return rig.model, 13, 8
end

-------------------------------------------------------------------------------
-- PRISM TITAN — colosso de pedra escura coberto de cristais azuis.
-------------------------------------------------------------------------------
function BossModels.prism_titan()
	local rig = newRig("PrismTitan", V(11, 4, 8))
	local rock, dark, blue, pale = rgb(42, 42, 66), rgb(28, 28, 46), rgb(50, 140, 255), rgb(150, 210, 255)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 4.5, 0), shape = "block", size = V(11, 10, 7.5), color = rock, material = "Slate", role = "Body" })
	add(rig, { name = "Pelvis", parent = body, at = CF(0, -6, 0.3), shape = "block", size = V(8.5, 3.5, 6), color = dark, material = "Slate", role = "Body" })
	for i, x in ipairs({ -3.2, 0, 3.2 }) do
		add(rig, { name = "RockPlate", parent = body, at = CF(x, 2.2 - (i % 2) * 0.8, -3.9) * ANG(rad(-6), 0, rad(x * 2)), shape = "block", size = V(3.4, 4, 0.9), color = dark, material = "Slate", role = "Detail" })
	end
	add(rig, { name = "Core", parent = body, at = CF(0, -0.8, -4.0) * ANG(0, 0, rad(45)), shape = "block", size = V(2.8, 2.8, 1.2), color = blue, material = "Neon", role = "Glow" })
	crack(rig, body, CF(-2.6, -2.5, -3.95) * ANG(0, 0, rad(30)), 4.5, blue)
	crack(rig, body, CF(2.6, -2.2, -3.95) * ANG(0, 0, rad(-30)), 4.5, blue)
	crack(rig, body, CF(0, 3.4, -3.95) * ANG(0, 0, rad(90)), 5, blue)
	cluster(rig, body, CF(0, 4.5, 2.4) * ANG(rad(20), 0, 0), 5, 7, 1.6, blue, 26)
	-- cabeça pequena com coroa de cristais
	local neck = helper(rig, "NeckBase", body, nil, CF(0, 5, -1))
	local head = add(rig, { name = "Head", parent = neck, joint = "Neck", at = CF(0, 1.8, -0.4), shape = "block", size = V(4.4, 3.6, 4), color = rock, material = "Slate", role = "Body" })
	add(rig, { name = "Brow", parent = head, at = CF(0, 0.9, -2.05) * ANG(rad(-20), 0, 0), shape = "wedge", size = V(4.6, 1, 1.2), color = dark, material = "Slate", role = "Detail" })
	ModelKit.eyes(rig, head, 1.0, 0.1, -2.05, 0.8, blue, true)
	add(rig, { name = "Jaw", parent = head, joint = "Jaw", at = CF(0, -1.9, -0.4), shape = "block", size = V(3.6, 1.1, 3.2), color = dark, material = "Slate", role = "Belly" })
	cluster(rig, head, CF(0, 1.7, 0.2), 5, 4.2, 1.0, blue, 34)
	-- ombros com cachos de cristal + braços
	for _, side in ipairs({ -1, 1 }) do
		local jn = side < 0 and "ArmL" or "ArmR"
		local arm = helper(rig, jn, body, jn, CF(side * 7.2, 3, 0))
		add(rig, { name = "Shoulder", parent = arm, at = CF(0, 0.5, 0), shape = "block", size = V(5, 4.4, 5), color = rock, material = "Slate", role = "Body" })
		cluster(rig, arm, CF(side * 0.5, 2.6, 0) * ANG(0, 0, side * rad(-12)), 4, 6.5, 1.5, blue, 34)
		add(rig, { name = "UpperArm", parent = arm, at = CF(side * 0.3, -4, 0), shape = "block", size = V(3.6, 6, 3.6), color = dark, material = "Slate", role = "Body" })
		crystal(rig, arm, CF(side * 2, -3.5, 0) * ANG(0, 0, side * rad(-80)), 2.6, 1, blue)
		add(rig, { name = "Forearm", parent = arm, at = CF(side * 0.4, -9, -0.4), shape = "block", size = V(4.4, 5, 4.4), color = rock, material = "Slate", role = "Body" })
		crack(rig, arm, CF(side * 0.4, -9, -2.65), 3.6, blue)
		add(rig, { name = "Fist", parent = arm, at = CF(side * 0.4, -12.8, -0.8), shape = "block", size = V(5.6, 4.6, 5.6), color = dark, material = "Slate", role = "Belly" })
		for k = -1, 1 do
			crystal(rig, arm, CF(side * 0.4 + k * 1.6, -11.5, -3.6) * ANG(rad(-90), 0, 0), 1.6, 0.8, pale)
		end
		local ln = side < 0 and "LegL" or "LegR"
		local leg = helper(rig, ln, body, ln, CF(side * 3, -8, 0))
		add(rig, { name = "Thigh", parent = leg, at = CF(0, -1.8, 0), shape = "block", size = V(3.8, 4, 4), color = rock, material = "Slate", role = "Body" })
		crystal(rig, leg, CF(0, -3.6, -2.2) * ANG(rad(-90), 0, 0), 1.8, 1.2, blue) -- joelho
		add(rig, { name = "Shin", parent = leg, at = CF(0, -5.4, 0), shape = "block", size = V(4.2, 4, 4.4), color = dark, material = "Slate", role = "Body" })
		add(rig, { name = "Foot", parent = leg, at = CF(0, -7.9, -0.6), shape = "block", size = V(4.8, 1.6, 5.8), color = rock, material = "Slate", role = "Belly" })
	end
	ModelKit.hitbox(rig, V(16, 27, 10), CF(0, 2, 0))
	return rig.model, 12.3, 9
end

-------------------------------------------------------------------------------
-- TEMPEST WYRM — dragão de 4 patas, prateado e dourado, com asas douradas e olhos azuis.
-------------------------------------------------------------------------------
function BossModels.tempest_wyrm()
	local K = 1.25
	local function S(x, y, z)
		return Vector3.new(x * K, y * K, z * K)
	end
	local function P(x, y, z)
		return CFrame.new(x * K, y * K, z * K)
	end
	local rig = newRig("TempestWyrm", S(8, 6, 10))
	local silver, scale, gold, blue, mouth = rgb(228, 232, 245), rgb(190, 198, 222), rgb(232, 182, 60), rgb(80, 180, 255), rgb(230, 90, 130)
	local body = add(rig, { name = "Torso", joint = "Body", at = P(0, 0, 0), shape = "ellipsoid", size = S(9, 8, 15), color = silver, material = "SmoothPlastic", role = "Body" })
	add(rig, { name = "Chest", parent = body, at = P(0, 0.6, -5), shape = "ellipsoid", size = S(7.5, 7.5, 7), color = silver, role = "Body" })
	add(rig, { name = "Belly", parent = body, at = P(0, -2, -0.5), shape = "ellipsoid", size = S(6.6, 4.4, 12), color = rgb(240, 214, 150), material = "SmoothPlastic", role = "Belly" })
	add(rig, { name = "ChestGem", parent = body, at = P(0, 0.4, -8.4) * ANG(0, 0, rad(45)), shape = "block", size = S(1.8, 1.8, 0.6), color = blue, material = "Neon", role = "Glow" })
	for i = 1, 6 do
		add(rig, { name = "SpineSpike", parent = body, at = P(0, 4 - math.abs(i - 3) * 0.25, -6 + i * 2) * ANG(0, rad(90), 0), shape = "wedge", size = S(0.5, 2.2, 1.6),
			color = gold, material = "Metal", role = "Accent" })
	end
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "ScaleBand", parent = body, at = P(side * 4.1, 0.3, 0) * ANG(0, 0, side * rad(10)), shape = "ellipsoid", size = S(1.2, 5, 12), color = scale, role = "Detail" })
		crack(rig, body, P(side * 4.45, 0.8, -1) * ANG(rad(90), 0, rad(25)), 5 * K, blue)
	end
	-- pescoço curto e grosso + cabeça grande de dragão
	local neck = helper(rig, "NeckBase", body, nil, P(0, 2.4, -7.5))
	add(rig, { name = "NeckSeg", parent = neck, at = P(0, 1.6, -1.2) * ANG(rad(-40), 0, 0), shape = "ellipsoid", size = S(4.6, 4.6, 6), color = silver, role = "Body" })
	add(rig, { name = "NeckPlate", parent = neck, at = P(0, 1.2, -2.6) * ANG(rad(-40), 0, 0), shape = "ellipsoid", size = S(3, 3.6, 4), color = rgb(240, 214, 150), role = "Belly" })
	local head = add(rig, { name = "Head", parent = neck, joint = "Neck", at = P(0, 4.4, -3.6) * ANG(rad(-6), 0, 0), shape = "ellipsoid", size = S(4.6, 3.8, 6), color = silver, role = "Body" })
	add(rig, { name = "Snout", parent = head, at = P(0, -0.5, -3.6), shape = "ellipsoid", size = S(3, 2, 5), color = silver, role = "Body" })
	add(rig, { name = "BrowRidge", parent = head, at = P(0, 1.3, -1.6) * ANG(rad(-15), 0, 0), shape = "ellipsoid", size = S(4.4, 1, 3), color = scale, role = "Detail" })
	add(rig, { name = "Mouth", parent = head, at = P(0, -1.1, -3.4), shape = "ellipsoid", size = S(2.7, 0.7, 4.6), color = mouth, material = "Neon", role = "Detail" })
	local jaw = add(rig, { name = "Jaw", parent = head, joint = "Jaw", at = P(0, -1.8, -2.6) * ANG(rad(16), 0, 0), shape = "ellipsoid", size = S(2.8, 1.1, 5), color = scale, role = "Belly" })
	for i = -2, 2 do
		if i ~= 0 then
			add(rig, { name = "Tooth", parent = head, at = P(i * 0.55, -1.4, -5) * ANG(rad(180), 0, 0), shape = "wedge", size = S(0.3, 0.8, 0.3), color = rgb(255, 255, 255), role = "Detail" })
			add(rig, { name = "Tooth", parent = jaw, at = P(i * 0.5, 0.65, -2), shape = "wedge", size = S(0.3, 0.7, 0.3), color = rgb(255, 255, 255), role = "Detail" })
		end
	end
	ModelKit.eyes(rig, head, 1.25 * K, 0.6 * K, -2.2 * K, 0.75 * K, blue, true)
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "Horn", parent = head, at = P(side * 1.3, 1.5, 1.2) * ANG(rad(-62), 0, side * rad(-15)) * P(0, 2, 0), shape = "wedge", size = S(0.8, 4.4, 1.3), color = gold, material = "Metal", role = "Accent" })
		add(rig, { name = "HornSmall", parent = head, at = P(side * 2, 0.6, 1.4) * ANG(rad(-75), 0, side * rad(-40)) * P(0, 1.2, 0), shape = "wedge", size = S(0.6, 2.6, 0.9), color = gold, material = "Metal", role = "Accent" })
		add(rig, { name = "Frill", parent = head, at = P(side * 2.2, -0.6, 1.2) * ANG(0, side * rad(30), side * rad(20)), shape = "wedge", size = S(0.3, 2.2, 2.4), color = gold, material = "Metal", role = "Accent" })
	end
	-- asas grandes e erguidas: ossos dourados + membrana (triângulos)
	for _, side in ipairs({ -1, 1 }) do
		local jn = side < 0 and "WingL" or "WingR"
		local wing = helper(rig, jn, body, jn, P(side * 3.4, 3.4, -3))
		local function W(x, y, z)
			return Vector3.new(side * x * K, y * K, z * K)
		end
		local shoulder, elbow, wrist = W(0, 0, 0), W(6, 6.5, 1.5), W(13, 11, 3.5)
		bone(rig, wing, shoulder, elbow, 1.1 * K, gold)
		bone(rig, wing, elbow, wrist, 0.9 * K, gold)
		local tips = { W(21, 9.5, 4.5), W(20, 2.5, 6.5), W(16.5, -3.5, 8), W(10, -6.5, 9) }
		for _, t in ipairs(tips) do
			bone(rig, wing, wrist, t, 0.55 * K, gold)
		end
		local membrane = rgb(242, 196, 96)
		local prevPt = W(23, 13, 4) -- ponta superior (garra)
		bone(rig, wing, wrist, prevPt, 0.7 * K, gold)
		for _, t in ipairs(tips) do
			triangle(rig, wing, wrist, prevPt, t, 0.25 * K, membrane, 0.1)
			prevPt = t
		end
		triangle(rig, wing, wrist, prevPt, W(1, -2, 6), 0.25 * K, membrane, 0.1) -- até o corpo
		triangle(rig, wing, wrist, W(1, -2, 6), elbow, 0.25 * K, membrane, 0.1)
		add(rig, { name = "WingClaw", parent = wing, at = CFrame.new(W(23.6, 13.8, 4)) * ANG(0, 0, side * rad(-30)), shape = "wedge", size = S(0.6, 1.8, 0.6), color = gold, material = "Metal", role = "Accent" })
		crack(rig, wing, CFrame.lookAt((elbow + wrist) / 2, wrist) * ANG(rad(90), 0, 0), 7 * K, blue)
	end
	-- pernas musculosas com garras douradas
	for _, leg in ipairs({ { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } }) do
		local l = helper(rig, leg[1], body, leg[1], P(leg[2] * 3.8, -2, leg[3] * 4.6))
		add(rig, { name = "Thigh", parent = l, at = P(0, -2.2, leg[3] * 0.4), shape = "ellipsoid", size = S(3.4, 5.6, 4.2), color = silver, role = "Body" })
		add(rig, { name = "Shin", parent = l, at = P(0, -6.2, 0.2), shape = "block", size = S(2.2, 4.4, 2.4), color = scale, role = "Body" })
		add(rig, { name = "ShinPlate", parent = l, at = P(0, -6, -1.25), shape = "block", size = S(1.6, 3.6, 0.3), color = gold, material = "Metal", role = "Accent" })
		add(rig, { name = "Foot", parent = l, at = P(0, -8.7, -0.5), shape = "block", size = S(2.8, 1, 3.4), color = silver, role = "Belly" })
		for k = -1, 1 do
			add(rig, { name = "Talon", parent = l, at = P(k * 0.85, -8.8, -2.5) * ANG(rad(-90), 0, 0), shape = "wedge", size = S(0.45, 1.3, 0.9), color = gold, material = "Metal", role = "Accent" })
		end
	end
	-- cauda longa (segmentos animáveis) com lâmina dourada
	local prev = body
	for i = 1, 6 do
		local s = 1 - i * 0.11
		prev = add(rig, { name = "Seg" .. i, parent = prev, joint = "Seg" .. i, at = P(0, -0.2, 3.2 * s + (i == 1 and 6 or 1.4)), shape = "ellipsoid", size = S(4 * s, 3.6 * s, 4.4 * s), color = i % 2 == 0 and scale or silver, role = "Body" })
		add(rig, { name = "TailSpike", parent = prev, at = P(0, 1.8 * s, 0) * ANG(0, rad(90), 0), shape = "wedge", size = S(0.3, 1.2 * s, 1.2 * s), color = gold, material = "Metal", role = "Accent" })
	end
	add(rig, { name = "TailBlade", parent = prev, at = P(0, 0, 2.6) * ANG(rad(-90), 0, 0), shape = "wedge", size = S(0.4, 3, 2.4), color = gold, material = "Metal", role = "Accent" })
	add(rig, { name = "TailGlow", parent = prev, at = P(0, 0, 1.6), shape = "ball", size = S(0.9, 0.9, 0.9), color = blue, material = "Neon", role = "Glow" })
	ModelKit.hitbox(rig, S(10, 12, 24), P(0, 2, 2))
	return rig.model, 9.6 * K, 9 * K
end

-------------------------------------------------------------------------------
-- THE WILDERBLOOM — fera vegetal espinhosa com coroa-flor de cristais rosa e cipós.
-------------------------------------------------------------------------------
function BossModels.wilderbloom()
	local rig = newRig("Wilderbloom", V(10, 4, 9))
	local bark, dark, moss, pink, thorn = rgb(78, 60, 40), rgb(50, 38, 26), rgb(90, 130, 50), rgb(255, 60, 200), rgb(210, 190, 140)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 4, 0) * ANG(rad(12), 0, 0), shape = "ellipsoid", size = V(11, 10, 8.5), color = bark, material = "Wood", role = "Body" })
	add(rig, { name = "Moss", parent = body, at = CF(0, 3.4, 1.5), shape = "ellipsoid", size = V(9, 3, 6), color = moss, material = "Grass", role = "Accent" })
	add(rig, { name = "Heart", parent = body, at = CF(0, -0.5, -4.2) * ANG(0, 0, rad(45)), shape = "block", size = V(2.4, 2.4, 1), color = pink, material = "Neon", role = "Glow" })
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		add(rig, { name = "Thorn", parent = body, at = CF(math.cos(a) * 4.6, math.sin(a) * 3.8, 0.5) * ANG(0, 0, a - math.pi / 2), shape = "wedge", size = V(0.6, 1.8, 1.2), color = thorn, role = "Detail" })
	end
	cluster(rig, body, CF(0, 4.5, 2) * ANG(rad(25), 0, 0), 3, 5, 1.3, pink, 30)
	-- cabeça com olhos rosa e coroa de pétalas de cristal
	local neck = helper(rig, "NeckBase", body, nil, CF(0, 4.2, -2.4))
	local head = add(rig, { name = "Head", parent = neck, joint = "Neck", at = CF(0, 1.6, -1.2), shape = "ellipsoid", size = V(5, 4.4, 5), color = dark, material = "Wood", role = "Body" })
	ModelKit.eyes(rig, head, 1.1, 0.2, -2.3, 0.75, pink, true)
	add(rig, { name = "Jaw", parent = head, joint = "Jaw", at = CF(0, -1.8, -1), shape = "ellipsoid", size = V(3.8, 1.3, 3.4), color = bark, material = "Wood", role = "Belly" })
	for i = -2, 2 do
		add(rig, { name = "Fang", parent = head, at = CF(i * 0.7, -1.1, -2.6) * ANG(rad(180), 0, 0), shape = "wedge", size = V(0.4, 0.8, 0.3), color = rgb(250, 230, 240), role = "Detail" })
	end
	add(rig, { name = "BloomCore", parent = head, at = CF(0, 2.6, 0.2), shape = "ball", size = V(2.6, 2.6, 2.6), color = rgb(255, 150, 230), material = "Neon", role = "Glow" })
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local p = helper(rig, "Petal" .. i, head, "Petal" .. i, CF(math.cos(a) * 1.2, 2.4, math.sin(a) * 1.2 + 0.2))
		crystal(rig, p, ANG(0, -a, 0) * ANG(0, 0, rad(-50)) * ANG(0, math.pi / 2, 0), 6.5 - (i % 2) * 1.6, 1.4, i % 2 == 0 and pink or rgb(255, 120, 220))
	end
	-- braços com garras
	for _, side in ipairs({ -1, 1 }) do
		local jn = side < 0 and "ArmL" or "ArmR"
		local arm = helper(rig, jn, body, jn, CF(side * 5.6, 2, -1))
		add(rig, { name = "Shoulder", parent = arm, at = CF(0, 0.4, 0), shape = "ellipsoid", size = V(4, 3.6, 4), color = bark, material = "Wood", role = "Body" })
		crystal(rig, arm, CF(side * 0.6, 1.6, 0) * ANG(0, 0, side * rad(-30)), 3.6, 1.1, pink)
		add(rig, { name = "UpperArm", parent = arm, at = CF(side * 0.8, -3, -0.4) * ANG(0, 0, side * rad(10)), shape = "block", size = V(2.4, 5.5, 2.4), color = dark, material = "Wood", role = "Body" })
		add(rig, { name = "Forearm", parent = arm, at = CF(side * 1.2, -7.4, -1.2), shape = "block", size = V(2.8, 4.6, 2.8), color = bark, material = "Wood", role = "Body" })
		for k = -1, 1 do
			add(rig, { name = "Claw", parent = arm, at = CF(side * 1.2 + k * 0.8, -10.4, -1.8) * ANG(rad(180), 0, 0), shape = "wedge", size = V(0.5, 2, 0.9), color = thorn, role = "Detail" })
		end
		local ln = side < 0 and "LegL" or "LegR"
		local leg = helper(rig, ln, body, ln, CF(side * 3.4, -4.5, 0.6))
		add(rig, { name = "Thigh", parent = leg, at = CF(0, -2, 0), shape = "ellipsoid", size = V(3.6, 5, 3.8), color = bark, material = "Wood", role = "Body" })
		add(rig, { name = "Foot", parent = leg, at = CF(0, -6.2, -0.8), shape = "block", size = V(3.6, 2, 5), color = dark, material = "Wood", role = "Belly" })
	end
	-- cipós espinhosos enormes (4): saem para os lados, descem e enrolam a ponta para cima
	local vines = { { -1, -0.4, 0 }, { 1, -0.4, 0 }, { -0.7, 1, 2 }, { 0.7, 1, 2 } }
	for i, v in ipairs(vines) do
		local dir = Vector3.new(v[1], 0, v[2]).Unit
		local yaw = math.atan2(-dir.Z, dir.X)
		local root = helper(rig, "Root" .. i, body, "Root" .. i, CF(v[1] * 4.6, 0.5 + v[3], v[2] * 3))
		local cf = ANG(0, yaw, 0) * ANG(0, 0, rad(48))
		local bends = { -10, -22, -26, -26, -22, 18, 38, 46 }
		for sIdx, bend in ipairs(bends) do
			local len = 3.4 - sIdx * 0.16
			local thick = 2.1 - sIdx * 0.18
			cf = cf * ANG(0, 0, rad(bend))
			add(rig, { name = "Vine", parent = root, at = cf * CF(len / 2, 0, 0), shape = "block", size = V(len + 0.4, thick, thick), color = sIdx % 2 == 0 and dark or rgb(66, 84, 36),
				material = "Wood", role = "Body" })
			add(rig, { name = "VineThorn", parent = root, at = cf * CF(len / 2, thick / 2 + 0.35, 0), shape = "wedge", size = V(0.35, 1, 0.7), color = thorn, role = "Detail" })
			if sIdx % 3 == 0 then
				add(rig, { name = "VineGlow", parent = root, at = cf * CF(len / 2, -thick / 2 - 0.05, 0), shape = "block", size = V(len * 0.7, 0.2, 0.35), color = pink, material = "Neon", role = "Glow", shadow = false })
			end
			cf = cf * CF(len, 0, 0)
		end
		crystal(rig, root, cf * ANG(0, 0, rad(-90)), 2.6, 1.0, pink)
	end
	ModelKit.hitbox(rig, V(18, 20, 14), CF(0, 2, 0))
	return rig.model, 7.4, 10
end

-------------------------------------------------------------------------------
-- VOID SOVEREIGN — rei de armadura preta e dourada, coroa de chifres, auréola roxa e capa.
-------------------------------------------------------------------------------
function BossModels.void_sovereign()
	local rig = newRig("VoidSovereign", V(9, 5, 7))
	local armor, robe, gold, purple, glow = rgb(26, 20, 40), rgb(36, 22, 60), rgb(232, 186, 80), rgb(170, 80, 255), rgb(200, 130, 255)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(0, 5, 0), shape = "block", size = V(8.5, 9, 5.2), color = armor, material = "Metal", role = "Body" })
	add(rig, { name = "ChestGem", parent = body, at = CF(0, 0.6, -2.75) * ANG(0, 0, rad(45)), shape = "block", size = V(2.4, 2.4, 0.8), color = purple, material = "Neon", role = "Glow" })
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "GoldTrim", parent = body, at = CF(side * 1.9, -0.6, -2.7) * ANG(0, 0, side * rad(-28)), shape = "block", size = V(0.5, 7.5, 0.3), color = gold, material = "Metal", role = "Accent" })
	end
	add(rig, { name = "Belt", parent = body, at = CF(0, -4.2, 0), shape = "block", size = V(9, 1, 5.6), color = gold, material = "Metal", role = "Accent" })
	-- túnica em camadas até o chão + barra roxa brilhante
	add(rig, { name = "Robe", parent = body, at = CF(0, -11.5, 0.2) * ANG(rad(180), 0, 0), shape = "wedge", size = V(11, 13, 7), color = robe, material = "Fabric", role = "Body" })
	add(rig, { name = "RobeFront", parent = body, at = CF(0, -10.5, -2.6), shape = "block", size = V(3, 12, 0.6), color = armor, material = "Metal", role = "Detail" })
	add(rig, { name = "RobeTrim", parent = body, at = CF(0, -10.5, -2.95), shape = "block", size = V(0.6, 12, 0.2), color = gold, material = "Metal", role = "Accent" })
	add(rig, { name = "Hem", parent = body, at = CF(0, -17.6, 0.2), shape = "block", size = V(11.4, 0.5, 7.4), color = purple, material = "Neon", role = "Glow" })
	-- capa
	add(rig, { name = "Cape", parent = body, at = CF(0, -5, 3.2) * ANG(rad(-8), 0, 0), shape = "block", size = V(10, 20, 0.6), color = rgb(30, 14, 52), material = "Fabric", role = "Body" })
	add(rig, { name = "CapeLining", parent = body, at = CF(0, -5, 2.85) * ANG(rad(-8), 0, 0), shape = "block", size = V(9.4, 19.4, 0.2), color = rgb(90, 30, 150), material = "Fabric", role = "Belly" })
	-- cabeça com elmo, coroa de chifres e auréola
	local neck = helper(rig, "NeckBase", body, nil, CF(0, 4.6, 0))
	local head = add(rig, { name = "Head", parent = neck, joint = "Neck", at = CF(0, 2, -0.2), shape = "block", size = V(3.6, 3.8, 3.6), color = armor, material = "Metal", role = "Body" })
	add(rig, { name = "Faceplate", parent = head, at = CF(0, -0.2, -1.85), shape = "block", size = V(2.8, 3, 0.2), color = rgb(10, 6, 18), role = "Detail" })
	ModelKit.eyes(rig, head, 0.65, 0.3, -1.95, 0.55, glow, true)
	add(rig, { name = "CrownSpike", parent = head, at = CF(0, 3.6, -0.3), shape = "wedge", size = V(0.9, 4.2, 1.2), color = gold, material = "Metal", role = "Accent" })
	add(rig, { name = "CrownGem", parent = head, at = CF(0, 2.1, -1.5) * ANG(0, 0, rad(45)), shape = "block", size = V(0.9, 0.9, 0.4), color = purple, material = "Neon", role = "Glow" })
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "CrownHorn", parent = head, at = CF(side * 1.4, 2.6, -0.2) * ANG(0, 0, side * rad(-28)) * CF(0, 1, 0), shape = "wedge", size = V(0.7, 3, 1), color = gold, material = "Metal", role = "Accent" })
		add(rig, { name = "CrownHornOuter", parent = head, at = CF(side * 2.4, 1.4, 0) * ANG(0, 0, side * rad(-55)) * CF(0, 1.4, 0), shape = "wedge", size = V(0.6, 3.4, 0.9), color = gold, material = "Metal", role = "Accent" })
	end
	-- auréola vertical atrás da cabeça (gira)
	ModelKit.ring(rig, head, "OrbitHalo", CF(0, 1.4, 1.8) * ANG(rad(90), 0, 0), 4.6, 18, V(0.6, 0.6, 0.6), glow, "Neon", "Glow", "block")
	-- ombreiras com espinhos e cristais + braços com garras
	for _, side in ipairs({ -1, 1 }) do
		local jn = side < 0 and "ArmL" or "ArmR"
		local arm = helper(rig, jn, body, jn, CF(side * 5.6, 3.2, 0))
		add(rig, { name = "Pauldron", parent = arm, at = CF(side * 0.4, 0.8, 0), shape = "ellipsoid", size = V(4.6, 3.4, 4.6), color = armor, material = "Metal", role = "Body" })
		add(rig, { name = "PauldronRim", parent = arm, at = CF(side * 0.4, 0.1, 0), shape = "ellipsoid", size = V(4.9, 1, 4.9), color = gold, material = "Metal", role = "Accent" })
		for k = 1, 3 do
			add(rig, { name = "PauldronSpike", parent = arm, at = CF(side * (0.6 + k * 0.6), 2.4, (k - 2) * 1.2) * ANG(0, 0, side * rad(-20 - k * 8)), shape = "wedge", size = V(0.5, 2.4, 1), color = gold, material = "Metal", role = "Accent" })
		end
		crystal(rig, arm, CF(side * 1.2, 2.2, 1.4) * ANG(rad(20), 0, side * rad(-15)), 3.4, 1, purple)
		add(rig, { name = "UpperArm", parent = arm, at = CF(side * 0.4, -3.2, 0), shape = "block", size = V(2.2, 4.6, 2.2), color = armor, material = "Metal", role = "Body" })
		add(rig, { name = "Gauntlet", parent = arm, at = CF(side * 0.5, -7, -0.4), shape = "block", size = V(2.8, 4, 2.8), color = armor, material = "Metal", role = "Body" })
		add(rig, { name = "GauntletTrim", parent = arm, at = CF(side * 0.5, -5.2, -0.4), shape = "block", size = V(3, 0.5, 3), color = gold, material = "Metal", role = "Accent" })
		for k = -1, 1 do
			add(rig, { name = "Talon", parent = arm, at = CF(side * 0.5 + k * 0.8, -9.6, -0.8) * ANG(rad(180), 0, 0), shape = "wedge", size = V(0.4, 1.8, 0.7), color = gold, material = "Metal", role = "Accent" })
		end
	end
	-- cristais roxos flutuando ao redor (giram)
	local orbit = helper(rig, "Orbit", body, "Orbit", CF(0, -1, 0))
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		crystal(rig, orbit, CF(math.cos(a) * 10, math.sin(i * 1.7) * 2.5, math.sin(a) * 10) * ANG(0, 0, rad(i % 2 == 0 and 15 or -15)), 3 + (i % 3), 1.1, i % 2 == 0 and purple or glow)
	end
	ModelKit.hitbox(rig, V(12, 28, 9), CF(0, -1, 0))
	return rig.model, 13.5, 8
end

function BossModels.build(id: string)
	local builder = BossModels[id]
	assert(builder, "sem modelo de boss: " .. id)
	local model, centerHeight, radius = builder()
	model:SetAttribute("BossId", id)
	return model, centerHeight, radius
end

return BossModels

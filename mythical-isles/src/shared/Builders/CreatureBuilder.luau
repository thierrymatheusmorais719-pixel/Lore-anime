-- Construtor procedural dos PETS a partir de Config/Pets.model.
-- Arquétipos: quad (quadrúpede), biped, flyer (alado), serpent, floater (espírito flutuante), golem.
-- Os detalhes (orelhas, chifres, caudas, asas, costas, auréola...) dão a silhueta de cada espécie.
-- Frente da criatura = -Z (LookVector do Roblox).

local ModelKit = require(script.Parent.ModelKit)

local CreatureBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local function darker(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

-------------------------------------------------------------------------------
-- Detalhes reutilizáveis
-------------------------------------------------------------------------------

local function addEars(rig, m, u, head, kind)
	if not kind then
		return
	end
	for _, side in ipairs({ -1, 1 }) do
		local joint = side < 0 and "EarL" or "EarR"
		if kind == "pointy" then
			ModelKit.add(rig, { name = "Ear", parent = head, joint = joint, at = CF(side * 0.5 * u, 0.85 * u, 0.05 * u) * ANG(0, 0, side * rad(-12)),
				shape = "wedge", size = V(0.22 * u, 0.75 * u, 0.55 * u), color = m.body, role = "Body" })
			ModelKit.add(rig, { name = "EarInner", parent = head, at = CF(side * 0.5 * u, 0.8 * u, -0.02 * u) * ANG(0, 0, side * rad(-12)),
				shape = "wedge", size = V(0.12 * u, 0.5 * u, 0.36 * u), color = m.accent, role = "Accent" })
		elseif kind == "round" then
			ModelKit.add(rig, { name = "Ear", parent = head, joint = joint, at = CF(side * 0.62 * u, 0.7 * u, 0.1 * u),
				shape = "ellipsoid", size = V(0.5 * u, 0.5 * u, 0.25 * u), color = m.body, role = "Body" })
		elseif kind == "long" then
			ModelKit.add(rig, { name = "Ear", parent = head, joint = joint, at = CF(side * 0.38 * u, 1.05 * u, 0.2 * u) * ANG(rad(-15), 0, side * rad(-14)),
				shape = "ellipsoid", size = V(0.36 * u, 1.3 * u, 0.24 * u), color = m.body, role = "Body" })
			ModelKit.add(rig, { name = "EarInner", parent = head, at = CF(side * 0.38 * u, 1.05 * u, 0.1 * u) * ANG(rad(-15), 0, side * rad(-14)),
				shape = "ellipsoid", size = V(0.2 * u, 1.0 * u, 0.12 * u), color = m.accent, role = "Accent" })
		elseif kind == "tufted" then
			ModelKit.add(rig, { name = "Ear", parent = head, joint = joint, at = CF(side * 0.5 * u, 0.85 * u, 0.05 * u) * ANG(0, 0, side * rad(-10)),
				shape = "wedge", size = V(0.22 * u, 0.7 * u, 0.5 * u), color = m.body, role = "Body" })
			ModelKit.add(rig, { name = "Tuft", parent = head, at = CF(side * 0.56 * u, 1.3 * u, 0.12 * u),
				shape = "wedge", size = V(0.08 * u, 0.4 * u, 0.15 * u), color = darker(m.body, 0.5), role = "Detail" })
		elseif kind == "mouse" then
			ModelKit.add(rig, { name = "Ear", parent = head, joint = joint, at = CF(side * 0.62 * u, 0.78 * u, 0.15 * u) * ANG(0, 0, side * rad(-15)),
				shape = "cyl", size = V(0.16 * u, 0.85 * u, 0.85 * u), color = m.body, role = "Body" })
			ModelKit.add(rig, { name = "EarInner", parent = head, at = CF(side * 0.6 * u, 0.78 * u, 0.08 * u) * ANG(0, 0, side * rad(-15)),
				shape = "cyl", size = V(0.1 * u, 0.6 * u, 0.6 * u), color = m.accent, role = "Accent" })
		elseif kind == "leafy" then
			ModelKit.add(rig, { name = "Ear", parent = head, joint = joint, at = CF(side * 0.55 * u, 0.85 * u, 0.1 * u) * ANG(rad(-10), 0, side * rad(-35)),
				shape = "ellipsoid", size = V(0.35 * u, 1.1 * u, 0.12 * u), color = m.accent, material = "Grass", role = "Accent" })
		elseif kind == "crystal" then
			ModelKit.add(rig, { name = "Ear", parent = head, joint = joint, at = CF(side * 0.48 * u, 0.9 * u, 0.05 * u) * ANG(0, 0, side * rad(-12)),
				shape = "wedge", size = V(0.2 * u, 0.9 * u, 0.55 * u), color = m.accent, material = "Glass", transparency = 0.1, role = "Accent" })
		elseif kind == "feelers" then
			ModelKit.add(rig, { name = "Feeler", parent = head, joint = joint, at = CF(side * 0.3 * u, 0.9 * u, -0.2 * u) * ANG(rad(-25), 0, side * rad(-20)),
				shape = "cyl", size = V(1.0 * u, 0.08 * u, 0.08 * u), color = darker(m.body, 0.6), role = "Detail" })
			ModelKit.add(rig, { name = "FeelerTip", parent = head, at = CF(side * 0.5 * u, 1.35 * u, -0.4 * u),
				shape = "ball", size = Vector3.one * 0.22 * u, color = m.accent, material = "Neon", role = "Accent" })
		end
	end
end

local function addHorns(rig, m, u, head, kind)
	if not kind then
		return
	end
	for _, side in ipairs({ -1, 1 }) do
		if kind == "antlers" then
			ModelKit.add(rig, { name = "Antler", parent = head, at = CF(side * 0.35 * u, 1.05 * u, 0.1 * u) * ANG(0, 0, side * rad(-25)) * ANG(0, 0, rad(90)),
				shape = "cyl", size = V(0.9 * u, 0.12 * u, 0.12 * u), color = m.accent, material = m.glowHorns and "Neon" or "Wood", role = "Accent" })
			ModelKit.add(rig, { name = "AntlerTine", parent = head, at = CF(side * 0.62 * u, 1.35 * u, 0.05 * u) * ANG(0, 0, side * rad(-60)) * ANG(0, 0, rad(90)),
				shape = "cyl", size = V(0.6 * u, 0.1 * u, 0.1 * u), color = m.accent, material = "Wood", role = "Accent" })
			ModelKit.add(rig, { name = "AntlerTine", parent = head, at = CF(side * 0.48 * u, 1.55 * u, 0.15 * u) * ANG(rad(15), 0, side * rad(-5)) * ANG(0, 0, rad(90)),
				shape = "cyl", size = V(0.5 * u, 0.09 * u, 0.09 * u), color = m.accent, material = "Wood", role = "Accent" })
		elseif kind == "crystal" then
			ModelKit.add(rig, { name = "Horn", parent = head, at = CF(side * 0.35 * u, 0.95 * u, 0.15 * u) * ANG(rad(-20), 0, side * rad(-15)),
				shape = "wedge", size = V(0.2 * u, 0.8 * u, 0.4 * u), color = m.accent, material = "Glass", transparency = 0.15, role = "Accent" })
		elseif kind == "curled" then
			for i = 0, 4 do
				local a = rad(i * 55)
				ModelKit.add(rig, { name = "HornSeg", parent = head, at = CF(side * (0.6 + 0.15 * math.sin(a)) * u, (0.6 + 0.45 * math.cos(a)) * u, (0.2 + 0.35 * math.sin(a)) * u),
					shape = "ball", size = Vector3.one * (0.34 - i * 0.04) * u, color = darker(m.accent, 0.8), material = "Slate", role = "Accent" })
			end
		elseif kind == "grand" or kind == "crystalAntlers" then
			-- galhada enorme e ramificada (Sylvanox: com flores e cipós; cristal: de vidro)
			local crystalA = kind == "crystalAntlers"
			local mat = crystalA and "Glass" or "Wood"
			local col = crystalA and m.accent or (m.antler or darker(m.body, 0.75))
			local base = CF(side * 0.35 * u, 0.9 * u, 0.15 * u)
			local main = base * ANG(rad(-10), 0, side * rad(-22))
			ModelKit.add(rig, { name = "Antler", parent = head, at = main * CF(0, 1.1 * u, 0), shape = "block", size = V(0.16 * u, 2.2 * u, 0.16 * u), color = col, material = mat, role = "Accent" })
			for k = 1, 4 do
				local up = 0.45 * u * k
				local tine = main * CF(0, up, 0) * ANG(rad(k % 2 == 0 and -25 or 15), 0, side * rad(-50 + k * 6)) * CF(0, 0.45 * u, 0)
				ModelKit.add(rig, { name = "Tine", parent = head, at = tine, shape = "block", size = V(0.12 * u, (1.0 - k * 0.1) * u, 0.12 * u), color = col, material = mat, role = "Accent" })
				if kind == "grand" then
					ModelKit.add(rig, { name = "AntlerFlower", parent = head, at = tine * CF(0, 0.5 * u, 0), shape = "ball", size = Vector3.one * 0.22 * u,
						color = ({ Color3.fromRGB(255, 160, 210), Color3.fromRGB(150, 200, 255), Color3.fromRGB(255, 240, 150), Color3.fromRGB(200, 150, 255) })[k], material = "Neon", role = "Glow" })
				end
			end
			if kind == "grand" then
				for k = 1, 2 do
					ModelKit.add(rig, { name = "HangingVine", parent = head, at = main * CF(side * 0.35 * u * k, (1.0 + k * 0.4) * u, 0.1 * u) * CF(0, -0.55 * u, 0),
						shape = "block", size = V(0.06 * u, 1.1 * u, 0.06 * u), color = m.accent, material = "Grass", role = "Accent" })
				end
			end
		elseif kind == "tusks" then
			ModelKit.add(rig, { name = "Tusk", parent = head, at = CF(side * 0.35 * u, -0.45 * u, -0.85 * u) * ANG(rad(-60), 0, 0), shape = "wedge", size = V(0.14 * u, 0.5 * u, 0.2 * u),
				color = Color3.fromRGB(245, 240, 225), role = "Detail" })
		elseif kind == "nubs" then
			ModelKit.add(rig, { name = "Horn", parent = head, at = CF(side * 0.35 * u, 0.85 * u, 0), shape = "ball", size = Vector3.one * 0.25 * u, color = m.accent, role = "Accent" })
		end
	end
end

local function addTail(rig, m, u, parent, at, kind)
	if not kind then
		return
	end
	if kind == "fluffy" then
		local t = ModelKit.add(rig, { name = "Tail", parent = parent, joint = "Tail", at = at * ANG(rad(40), 0, 0),
			shape = "ellipsoid", size = V(0.75 * u, 0.75 * u, 1.7 * u), color = m.body, role = "Body" })
		ModelKit.add(rig, { name = "TailTip", parent = t.Name, at = CF(0, 0, 0.75 * u), shape = "ellipsoid", size = V(0.6 * u, 0.6 * u, 0.6 * u), color = m.belly, role = "Belly" })
	elseif kind == "thin" then
		local t = ModelKit.add(rig, { name = "Tail", parent = parent, joint = "Tail", at = at * ANG(rad(35), 0, 0) * CF(0, 0, 0.6 * u),
			shape = "block", size = V(0.18 * u, 0.18 * u, 1.3 * u), color = m.body, role = "Body" })
		ModelKit.add(rig, { name = "TailTip", parent = t.Name, at = CF(0, 0, 0.7 * u), shape = "ball", size = Vector3.one * 0.32 * u, color = m.accent, role = "Accent" })
	elseif kind == "leaf" then
		ModelKit.add(rig, { name = "Tail", parent = parent, joint = "Tail", at = at * ANG(rad(25), 0, 0) * CF(0, 0, 0.6 * u),
			shape = "ellipsoid", size = V(0.7 * u, 0.12 * u, 1.4 * u), color = m.accent, material = "Grass", role = "Accent" })
	elseif kind == "crystal" then
		local t = ModelKit.add(rig, { name = "Tail", parent = parent, joint = "Tail", at = at * ANG(rad(30), 0, 0) * CF(0, 0, 0.5 * u),
			shape = "block", size = V(0.2 * u, 0.2 * u, 1.0 * u), color = m.body, role = "Body" })
		ModelKit.add(rig, { name = "TailGem", parent = t.Name, at = CF(0, 0, 0.7 * u) * ANG(rad(90), 0, 0), shape = "wedge", size = V(0.4 * u, 0.6 * u, 0.3 * u),
			color = m.accent, material = "Glass", transparency = 0.1, role = "Accent" })
	elseif kind == "flame" then
		local t = ModelKit.add(rig, { name = "Tail", parent = parent, joint = "Tail", at = at * ANG(rad(25), 0, 0) * CF(0, 0, 0.6 * u),
			shape = "ellipsoid", size = V(0.5 * u, 0.5 * u, 1.3 * u), color = m.body, role = "Body" })
		ModelKit.add(rig, { name = "TailFlame", parent = t.Name, at = CF(0, 0.1 * u, 0.8 * u), shape = "ellipsoid", size = V(0.55 * u, 0.7 * u, 0.9 * u),
			color = m.accent, material = "Neon", transparency = 0.15, role = "Glow" })
	elseif kind == "cloud" then
		local t = ModelKit.add(rig, { name = "Tail", parent = parent, joint = "Tail", at = at * ANG(rad(40), 0, 0), shape = "ball", size = Vector3.one * 0.7 * u, color = m.belly, role = "Belly" })
		ModelKit.add(rig, { name = "TailPuff", parent = t.Name, at = CF(0.2 * u, 0.15 * u, 0.4 * u), shape = "ball", size = Vector3.one * 0.55 * u, color = m.belly, role = "Belly" })
		ModelKit.add(rig, { name = "TailPuff", parent = t.Name, at = CF(-0.2 * u, 0.25 * u, 0.6 * u), shape = "ball", size = Vector3.one * 0.45 * u, color = m.accent, role = "Accent" })
	elseif kind == "multi" then
		for i = -2, 2 do
			ModelKit.add(rig, { name = "Tail", parent = parent, joint = "Tail" .. (i + 3), at = at * ANG(rad(45), rad(i * 22), 0) * CF(0, 0, 0.7 * u),
				shape = "ellipsoid", size = V(0.5 * u, 0.5 * u, 1.7 * u), color = i == 0 and m.accent or m.body, material = i == 0 and "Neon" or "SmoothPlastic", role = i == 0 and "Accent" or "Body" })
		end
	elseif kind == "feather" then
		for i = -1, 1 do
			ModelKit.add(rig, { name = "Tail", parent = parent, joint = i == 0 and "Tail" or nil, at = at * ANG(rad(10), rad(i * 18), 0) * CF(0, 0, 0.5 * u),
				shape = "ellipsoid", size = V(0.4 * u, 0.1 * u, 1.2 * u), color = i == 0 and m.accent or m.body, role = i == 0 and "Accent" or "Body" })
		end
	elseif kind == "fan" then
		-- leque de caudas de cristal (raposas de Crystal Hollow; muitas = mítico/secret)
		local n = m.tailCount or 3
		for i = 1, n do
			local t = n == 1 and 0 or ((i - 1) / (n - 1) - 0.5)
			ModelKit.add(rig, { name = "Tail", parent = parent, joint = i == math.ceil(n / 2) and "Tail" or ("Tail" .. i), at = at * ANG(rad(55 - math.abs(t) * 30), rad(t * 110), 0) * CF(0, 0, 0.7 * u),
				shape = "wedge", size = V(0.18 * u, 0.55 * u, 1.6 * u), color = i % 2 == 0 and m.accent or m.belly, material = "Glass", transparency = 0.05, role = "Accent" })
		end
	elseif kind == "leafy" then
		local t = ModelKit.add(rig, { name = "Tail", parent = parent, joint = "Tail", at = at * ANG(rad(45), 0, 0), shape = "ellipsoid", size = V(0.7 * u, 0.7 * u, 1.6 * u), color = m.body, role = "Body" })
		for k = 1, 3 do
			ModelKit.add(rig, { name = "TailLeaf", parent = t.Name, at = CF(0, 0.25 * u, (k - 2) * 0.45 * u) * ANG(0, 0, rad((k - 2) * 40)), shape = "ellipsoid", size = V(0.5 * u, 0.12 * u, 0.7 * u),
				color = m.accent, material = "Grass", role = "Accent" })
		end
	elseif kind == "nub" then
		ModelKit.add(rig, { name = "Tail", parent = parent, joint = "Tail", at = at, shape = "ball", size = Vector3.one * 0.45 * u, color = m.belly, role = "Belly" })
	end
end

local function addBack(rig, m, u, body, kind, len)
	if not kind then
		return
	end
	len = len or 1
	if kind == "moss" then
		for i, p in ipairs({ { 0, 0.85, 0.2 }, { 0.45, 0.7, -0.3 }, { -0.45, 0.72, 0.5 }, { 0.1, 0.8, -0.7 } }) do
			ModelKit.add(rig, { name = "Moss", parent = body, at = CF(p[1] * u, p[2] * u, p[3] * u * len), shape = "ellipsoid",
				size = V((0.8 - i * 0.08) * u, 0.35 * u, (0.8 - i * 0.05) * u), color = m.accent, material = "Grass", role = "Accent" })
		end
	elseif kind == "thorns" then
		for i = -2, 2 do
			ModelKit.add(rig, { name = "Thorn", parent = body, at = CF(0, 0.85 * u, i * 0.45 * u * len) * ANG(0, rad(90), 0),
				shape = "wedge", size = V(0.15 * u, 0.55 * u, 0.4 * u), color = m.accent, role = "Accent" })
		end
	elseif kind == "crystals" then
		for i, p in ipairs({ { 0, 0.9, 0 }, { 0.35, 0.75, 0.5 }, { -0.35, 0.78, -0.4 }, { -0.2, 0.75, 0.7 }, { 0.3, 0.8, -0.6 } }) do
			ModelKit.add(rig, { name = "Crystal", parent = body, at = CF(p[1] * u, p[2] * u, p[3] * u * len) * ANG(rad(i * 13 - 20), rad(i * 40), rad(p[1] * 50)),
				shape = "block", size = V(0.3 * u, (0.9 - i * 0.08) * u, 0.3 * u), color = m.accent, material = "Glass", transparency = 0.1, role = "Accent" })
		end
	elseif kind == "flowers" then
		for i, p in ipairs({ { 0.3, 0.8, 0.1 }, { -0.35, 0.75, 0.5 }, { 0, 0.85, -0.5 } }) do
			local c = ModelKit.add(rig, { name = "Flower", parent = body, at = CF(p[1] * u, p[2] * u, p[3] * u * len), shape = "ball", size = Vector3.one * 0.25 * u, color = Color3.fromRGB(255, 240, 120), role = "Detail" })
			for k = 1, 5 do
				local a = k / 5 * math.pi * 2
				ModelKit.add(rig, { name = "Petal", parent = c.Name, at = CF(math.cos(a) * 0.22 * u, 0, math.sin(a) * 0.22 * u), shape = "ellipsoid",
					size = V(0.28 * u, 0.08 * u, 0.2 * u), color = m.accent, role = "Accent" })
			end
			if i > 3 then
				break
			end
		end
	elseif kind == "wool" then
		for _, p in ipairs({ { 0, 0.75, 0 }, { 0.5, 0.55, 0.4 }, { -0.5, 0.55, 0.4 }, { 0.5, 0.55, -0.4 }, { -0.5, 0.55, -0.4 }, { 0, 0.7, 0.8 }, { 0, 0.7, -0.8 } }) do
			ModelKit.add(rig, { name = "Wool", parent = body, at = CF(p[1] * u, p[2] * u, p[3] * u * len), shape = "ball", size = Vector3.one * 0.9 * u, color = m.body, material = "Fabric", role = "Body" })
		end
		ModelKit.add(rig, { name = "Spark", parent = body, at = CF(0, 1.1 * u, 0), shape = "ball", size = Vector3.one * 0.3 * u, color = m.accent, material = "Neon", role = "Glow" })
	elseif kind == "mane" then
		for i = 1, 9 do
			local a = (i - 1) / 9 * math.pi * 2
			ModelKit.add(rig, { name = "Mane", parent = body, at = CF(math.cos(a) * 0.85 * u, 0.55 * u + math.sin(a) * 0.65 * u, -1.0 * u * len) * ANG(0, 0, a),
				shape = "ellipsoid", size = V(0.5 * u, 0.9 * u, 0.6 * u), color = i % 2 == 0 and m.accent or darker(m.body, 0.85), material = i % 2 == 0 and "Neon" or "SmoothPlastic", role = i % 2 == 0 and "Accent" or "Body" })
		end
	elseif kind == "stars" then
		for i = 1, 6 do
			local a = i * 1.7
			ModelKit.add(rig, { name = "StarSpeck", parent = body, at = CF(math.cos(a) * 0.6 * u, 0.7 * u + (i % 2) * 0.1 * u, math.sin(a) * 0.8 * u * len),
				shape = "ball", size = Vector3.one * 0.16 * u, color = m.accent, material = "Neon", role = "Glow" })
		end
	elseif kind == "shell" or kind == "tree" then
		-- casco de tartaruga (com árvore e musgo nas lendárias)
		local shellCol = m.shell or darker(m.accent, 0.7)
		local sh = ModelKit.add(rig, { name = "Shell", parent = body, at = CF(0, 0.45 * u, 0.1 * u), shape = "ellipsoid", size = V(2.5 * u, 1.6 * u, 3.0 * u), color = shellCol, material = "Slate", role = "Accent" }).Name
		for k = 1, 5 do
			local a = k / 5 * math.pi * 2
			ModelKit.add(rig, { name = "ShellPlate", parent = sh, at = CF(math.cos(a) * 0.7 * u, 0.55 * u, math.sin(a) * 0.85 * u), shape = "ellipsoid", size = V(0.75 * u, 0.3 * u, 0.75 * u),
				color = darker(shellCol, 0.8), material = "Slate", role = "Detail" })
		end
		ModelKit.add(rig, { name = "ShellMoss", parent = sh, at = CF(0, 0.7 * u, 0), shape = "ellipsoid", size = V(2.0 * u, 0.4 * u, 2.4 * u), color = Color3.fromRGB(90, 150, 60), material = "Grass", role = "Detail" })
		if kind == "tree" then
			ModelKit.add(rig, { name = "TreeTrunk", parent = sh, at = CF(0, 1.4 * u, 0), shape = "block", size = V(0.4 * u, 1.6 * u, 0.4 * u), color = Color3.fromRGB(110, 78, 50), material = "Wood", role = "Detail" })
			for k, o in ipairs({ { 0, 2.4, 0, 1.5 }, { 0.6, 2.0, 0.3, 1.0 }, { -0.6, 2.1, -0.2, 1.1 }, { 0.1, 2.0, -0.7, 0.9 } }) do
				ModelKit.add(rig, { name = "TreeLeaves", parent = sh, at = CF(o[1] * u, o[2] * u, o[3] * u), shape = "ball", size = Vector3.one * o[4] * u,
					color = k % 2 == 0 and Color3.fromRGB(80, 160, 60) or Color3.fromRGB(110, 190, 70), material = "Grass", role = "Detail" })
			end
		end
	elseif kind == "leaves" then
		for k = 1, 4 do
			ModelKit.add(rig, { name = "BackLeaf", parent = body, at = CF((k % 2 == 0 and 0.3 or -0.3) * u, 0.8 * u, (k - 2.5) * 0.5 * u * len) * ANG(rad(-30), rad(k * 50), 0), shape = "ellipsoid",
				size = V(0.55 * u, 0.12 * u, 0.85 * u), color = m.accent, material = "Grass", role = "Accent" })
		end
	elseif kind == "fronds" or kind == "fins" then
		ModelKit.add(rig, { name = "Fin", parent = body, at = CF(0, 0.7 * u, 0) * ANG(0, rad(90), 0), shape = "wedge",
			size = V(0.1 * u, 0.6 * u, 0.8 * u), color = m.accent, material = kind == "fins" and "Neon" or "Grass", role = "Accent" })
	end
end

local function addWings(rig, m, u, body, kind, at, span)
	if not kind then
		return
	end
	span = span or 1
	for _, side in ipairs({ -1, 1 }) do
		local joint = side < 0 and "WingL" or "WingR"
		local base = ModelKit.add(rig, { name = joint, parent = body, joint = joint, at = at * CF(side * 0.1 * u, 0, 0),
			shape = "block", size = Vector3.one * 0.2 * u, transparency = 1, role = "Detail" })
		local w = base.Name
		local function seg(name, x, z, sx, sz, color, material, transparency, role, rot)
			ModelKit.add(rig, { name = name, parent = w, at = CF(side * x * u * span, 0, z * u) * ANG(0, side * rad(rot or 0), 0),
				shape = "ellipsoid", size = V(sx * u * span, 0.12 * u, sz * u), color = color, material = material, transparency = transparency, role = role })
		end
		if kind == "feather" or kind == "seraph" then
			seg("WingCover", 0.8, 0, 1.6, 0.9, m.body, "SmoothPlastic", 0, "Body", 0)
			seg("WingFeather", 1.5, 0.35, 1.5, 0.6, m.belly, "SmoothPlastic", 0, "Belly", -15)
			seg("WingTip", 2.1, 0.55, 0.9, 0.45, m.accent, kind == "seraph" and "Neon" or "SmoothPlastic", 0, "Accent", -25)
			if kind == "seraph" then
				seg("WingUpper", 1.2, -0.45, 1.5, 0.45, m.belly, "SmoothPlastic", 0, "Belly", 20)
			end
		elseif kind == "leaf" then
			seg("WingLeaf", 0.9, 0, 1.8, 0.8, m.body, "Grass", 0, "Body", 0)
			seg("WingVein", 0.9, 0, 1.6, 0.12, m.accent, "SmoothPlastic", 0, "Accent", 0)
		elseif kind == "crystal" then
			for i = 0, 2 do
				ModelKit.add(rig, { name = "WingShard", parent = w, at = CF(side * (0.6 + i * 0.55) * u * span, 0.15 * u * i, 0.15 * u * i) * ANG(0, 0, side * rad(-15 - i * 8)),
					shape = "wedge", size = V(0.15 * u, (1.2 - i * 0.25) * u, 0.9 * u), color = m.accent, material = "Glass", transparency = 0.15, role = "Accent" })
			end
		elseif kind == "membrane" then
			seg("WingArm", 0.9, -0.2, 1.8, 0.2, darker(m.body, 0.8), "SmoothPlastic", 0, "Body", 5)
			seg("WingSkin", 1.0, 0.25, 1.9, 0.9, m.belly, "SmoothPlastic", 0.1, "Belly", -5)
			seg("WingClaw", 1.9, -0.25, 0.3, 0.3, m.accent, "SmoothPlastic", 0, "Accent", 0)
		elseif kind == "moth" then
			seg("WingFore", 1.0, -0.2, 2.0, 1.3, m.body, "SmoothPlastic", 0, "Body", 10)
			seg("WingHind", 0.8, 0.6, 1.4, 0.9, m.belly, "SmoothPlastic", 0, "Belly", -15)
			seg("WingEye", 1.1, -0.2, 0.5, 0.5, m.accent, "Neon", 0, "Accent", 0)
		elseif kind == "cloud" then
			seg("WingPuff", 0.8, 0, 1.2, 0.9, m.belly, "SmoothPlastic", 0, "Belly", 0)
		end
	end
end

local function addHalo(rig, m, u, head, y)
	ModelKit.ring(rig, head, "OrbitHalo", CF(0, y * u, 0.1 * u), 0.55 * u, 10, Vector3.one * 0.14 * u, m.accent, "Neon", "Glow")
end

local function addOrbit(rig, m, u, core, kind)
	if not kind then
		return
	end
	local hub = ModelKit.add(rig, { name = "Orbit", parent = core, joint = "Orbit", at = CF(), shape = "block", size = Vector3.one * 0.2, transparency = 1, role = "Detail" })
	local count = (kind == "planets") and 3 or 5
	for i = 1, count do
		local a = i / count * math.pi * 2
		local pos = CF(math.cos(a) * 1.35 * u, math.sin(a * 2) * 0.25 * u, math.sin(a) * 1.35 * u)
		if kind == "leaves" then
			ModelKit.add(rig, { name = "OrbitLeaf", parent = hub.Name, at = pos * ANG(0, -a, rad(30)), shape = "ellipsoid", size = V(0.45 * u, 0.08 * u, 0.25 * u), color = m.accent, material = "Grass", role = "Accent" })
		elseif kind == "shards" then
			ModelKit.add(rig, { name = "OrbitShard", parent = hub.Name, at = pos * ANG(rad(20), a, 0), shape = "wedge", size = V(0.15 * u, 0.45 * u, 0.25 * u), color = m.accent, material = "Glass", role = "Accent" })
		elseif kind == "puffs" then
			ModelKit.add(rig, { name = "OrbitPuff", parent = hub.Name, at = pos, shape = "ball", size = Vector3.one * 0.4 * u, color = m.accent, role = "Accent" })
		elseif kind == "wisps" then
			ModelKit.add(rig, { name = "OrbitWisp", parent = hub.Name, at = pos, shape = "ball", size = Vector3.one * 0.22 * u, color = m.accent, material = "Neon", transparency = 0.2, role = "Glow" })
		elseif kind == "stars" then
			ModelKit.add(rig, { name = "OrbitStar", parent = hub.Name, at = pos * ANG(0, 0, rad(45)), shape = "block", size = Vector3.one * 0.2 * u, color = m.accent, material = "Neon", role = "Glow" })
		elseif kind == "planets" then
			ModelKit.add(rig, { name = "OrbitPlanet", parent = hub.Name, at = pos, shape = "ball", size = Vector3.one * (0.35 + i * 0.08) * u, color = i == 2 and m.accent or darker(m.accent, 0.7), material = i == 2 and "Neon" or "SmoothPlastic", role = "Accent" })
		end
	end
end

-------------------------------------------------------------------------------
-- Arquétipos
-------------------------------------------------------------------------------

local function head(rig, m, u, parent, at, size)
	local h = ModelKit.add(rig, { name = "Head", parent = parent, joint = "Neck", at = at, shape = "ellipsoid", size = size or V(1.8 * u, 1.65 * u, 1.65 * u), color = m.body, role = "Body" })
	return h.Name
end

local function face(rig, m, u, hd, snout)
	if m.beak then
		ModelKit.add(rig, { name = "Beak", parent = hd, at = CF(0, -0.15 * u, -0.95 * u) * ANG(rad(-90), 0, 0), shape = "wedge", size = V(0.5 * u, 0.7 * u, 0.4 * u), color = Color3.fromRGB(240, 190, 60), role = "Detail" })
	elseif snout then
		local k = m.snout or 1
		ModelKit.add(rig, { name = "Snout", parent = hd, at = CF(0, -0.25 * u, -(0.72 + (k - 1) * 0.35) * u), shape = "ellipsoid", size = V(0.85 * u, 0.55 * u, 0.6 * u * k), color = m.belly, role = "Belly" })
		ModelKit.add(rig, { name = "Nose", parent = hd, at = CF(0, -0.12 * u, -(1.0 + (k - 1) * 0.65) * u), shape = "ball", size = Vector3.one * 0.2 * u, color = Color3.fromRGB(40, 30, 35), role = "Detail" })
	end
	ModelKit.eyes(rig, hd, 0.4 * u, 0.15 * u, -0.66 * u, 0.36 * u, m.glowEyes and m.eye or Color3.fromRGB(25, 22, 28), m.glowEyes)
	ModelKit.add(rig, { name = "Cheek", parent = hd, at = CF(0.55 * u, -0.2 * u, -0.5 * u), shape = "ball", size = Vector3.one * 0.22 * u, color = m.accent, transparency = 0.35, role = "Accent", shadow = false })
	ModelKit.add(rig, { name = "Cheek", parent = hd, at = CF(-0.55 * u, -0.2 * u, -0.5 * u), shape = "ball", size = Vector3.one * 0.22 * u, color = m.accent, transparency = 0.35, role = "Accent", shadow = false })
end

local function buildQuad(rig, m, u)
	local stocky = m.stocky and 1.15 or 1
	local L = m.long or 1 -- comprimento do corpo
	local legH = 0.95 * u * (m.legs or 1)
	local neckUp = m.neck or 0
	local body = ModelKit.add(rig, { name = "Torso", joint = "Body", at = CF(0, 0, 0), shape = "ellipsoid", size = V(2.0 * u * stocky, 1.7 * u, 2.7 * u * L), color = m.body, role = "Body" }).Name
	ModelKit.add(rig, { name = "Belly", parent = body, at = CF(0, -0.35 * u, -0.1 * u), shape = "ellipsoid", size = V(1.6 * u * stocky, 1.1 * u, 2.1 * u * L), color = m.belly, role = "Belly" })
	if neckUp > 0 then
		ModelKit.add(rig, { name = "NeckFur", parent = body, at = CF(0, (0.55 + neckUp * 0.5) * u, -1.2 * u * L) * ANG(rad(35), 0, 0), shape = "ellipsoid", size = V(0.9 * u, (1.0 + neckUp) * u, 0.9 * u),
			color = m.body, role = "Body" })
	end
	local hd = head(rig, m, u, body, CF(0, (0.75 + neckUp) * u, -(1.45 * L + neckUp * 0.25) * u))
	face(rig, m, u, hd, true)
	addEars(rig, m, u, hd, m.ears)
	addHorns(rig, m, u, hd, m.horns)
	if m.crest then
		ModelKit.add(rig, { name = "Crest", parent = hd, at = CF(0, 0.95 * u, 0.1 * u) * ANG(rad(-20), 0, 0), shape = "wedge", size = V(0.14 * u, 0.6 * u, 0.6 * u), color = m.accent, role = "Accent" })
	end
	if m.halo then
		addHalo(rig, m, u, hd, m.horns == "grand" and 2.6 or 1.35)
	end
	for _, leg in ipairs({ { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } }) do
		local l = ModelKit.add(rig, { name = leg[1], parent = body, joint = leg[1], at = CF(leg[2] * 0.62 * u * stocky, -0.55 * u, leg[3] * 0.85 * u * L),
			shape = "block", size = V(0.1, 0.1, 0.1), transparency = 1, role = "Detail" }).Name
		local thick = m.legs and m.legs > 1.2 and 0.45 or 0.6
		ModelKit.add(rig, { name = "Leg", parent = l, at = CF(0, -legH * 0.45, 0), shape = "ellipsoid", size = V(thick * u, legH, thick * u), color = m.body, role = "Body" })
		ModelKit.add(rig, { name = "Paw", parent = l, at = CF(0, -legH * 0.9, -0.08 * u), shape = "ellipsoid", size = V((thick + 0.02) * u, 0.32 * u, 0.72 * u), color = m.paw or m.belly, role = "Belly" })
	end
	addTail(rig, m, u, body, CF(0, 0.35 * u, 1.3 * u * L), m.tail)
	addBack(rig, m, u, body, m.back, L)
	if m.wings then
		addWings(rig, m, u, body, m.wings, CF(0, 0.6 * u, -0.2 * u), m.wingSpan or 0.9)
	end
	return 0.55 * u + legH -- altura do centro do root acima do chão
end

local function buildBiped(rig, m, u)
	local body = ModelKit.add(rig, { name = "Torso", joint = "Body", at = CF(0, 0, 0), shape = "ellipsoid", size = V(1.7 * u, 2.0 * u, 1.5 * u), color = m.body, role = "Body" }).Name
	ModelKit.add(rig, { name = "Belly", parent = body, at = CF(0, -0.2 * u, -0.25 * u), shape = "ellipsoid", size = V(1.2 * u, 1.4 * u, 1.1 * u), color = m.belly, role = "Belly" })
	local hd = head(rig, m, u, body, CF(0, 1.55 * u, -0.1 * u))
	face(rig, m, u, hd, false)
	addEars(rig, m, u, hd, m.ears)
	addHorns(rig, m, u, hd, m.horns)
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "ArmL" or "ArmR"
		local a = ModelKit.add(rig, { name = name, parent = body, joint = name, at = CF(side * 0.95 * u, 0.45 * u, 0), shape = "block", size = V(0.1, 0.1, 0.1), transparency = 1, role = "Detail" }).Name
		ModelKit.add(rig, { name = "Arm", parent = a, at = CF(side * 0.15 * u, -0.5 * u, 0), shape = "ellipsoid", size = V(0.5 * u, 1.2 * u, 0.5 * u), color = m.body, role = "Body" })
		ModelKit.add(rig, { name = "Hand", parent = a, at = CF(side * 0.2 * u, -1.1 * u, 0), shape = "ball", size = Vector3.one * 0.5 * u, color = m.accent, role = "Accent" })
		local lname = side < 0 and "LegL" or "LegR"
		local l = ModelKit.add(rig, { name = lname, parent = body, joint = lname, at = CF(side * 0.45 * u, -0.85 * u, 0), shape = "block", size = V(0.1, 0.1, 0.1), transparency = 1, role = "Detail" }).Name
		ModelKit.add(rig, { name = "Leg", parent = l, at = CF(0, -0.45 * u, 0), shape = "ellipsoid", size = V(0.6 * u, 1.0 * u, 0.6 * u), color = m.body, role = "Body" })
		ModelKit.add(rig, { name = "Foot", parent = l, at = CF(0, -0.95 * u, -0.12 * u), shape = "ellipsoid", size = V(0.65 * u, 0.32 * u, 0.85 * u), color = m.belly, role = "Belly" })
	end
	addBack(rig, m, u, body, m.back, 0.6)
	return 0.85 * u + 1.1 * u
end

local function buildFlyer(rig, m, u)
	local body = ModelKit.add(rig, { name = "Torso", joint = "Body", at = CF(0, 0, 0), shape = "ellipsoid", size = V(1.4 * u, 1.35 * u, 2.0 * u), color = m.body, role = "Body" }).Name
	ModelKit.add(rig, { name = "Belly", parent = body, at = CF(0, -0.25 * u, -0.2 * u), shape = "ellipsoid", size = V(1.1 * u, 1.0 * u, 1.5 * u), color = m.belly, role = "Belly" })
	local hd = head(rig, m, u, body, CF(0, 0.75 * u, -1.05 * u), V(1.35 * u, 1.3 * u, 1.3 * u))
	ModelKit.eyes(rig, hd, 0.33 * u, 0.12 * u, -0.5 * u, 0.3 * u, m.glowEyes and m.eye or Color3.fromRGB(25, 22, 28), m.glowEyes)
	if m.drake then
		ModelKit.add(rig, { name = "Snout", parent = hd, at = CF(0, -0.15 * u, -0.75 * u), shape = "ellipsoid", size = V(0.7 * u, 0.5 * u, 0.8 * u), color = m.body, role = "Body" })
		ModelKit.add(rig, { name = "Jaw", parent = hd, joint = "Jaw", at = CF(0, -0.38 * u, -0.7 * u), shape = "ellipsoid", size = V(0.6 * u, 0.25 * u, 0.7 * u), color = m.belly, role = "Belly" })
	else
		ModelKit.add(rig, { name = "Beak", parent = hd, at = CF(0, -0.1 * u, -0.72 * u) * ANG(rad(-90), 0, 0), shape = "wedge", size = V(0.35 * u, 0.5 * u, 0.3 * u), color = m.accent, role = "Accent" })
	end
	addEars(rig, m, u, hd, m.ears)
	addHorns(rig, m, u, hd, m.horns)
	if m.crest then
		ModelKit.add(rig, { name = "Crest", parent = hd, at = CF(0, 0.75 * u, 0.15 * u) * ANG(rad(-25), 0, 0), shape = "wedge", size = V(0.12 * u, 0.55 * u, 0.55 * u), color = m.accent, role = "Accent" })
	end
	if m.halo then
		addHalo(rig, m, u, hd, 1.05)
	end
	addWings(rig, m, u, body, m.wings or "feather", CF(0, 0.35 * u, -0.1 * u), 1)
	addTail(rig, m, u, body, CF(0, 0.15 * u, 0.95 * u), m.tail)
	for _, side in ipairs({ -1, 1 }) do
		ModelKit.add(rig, { name = "Foot", parent = body, at = CF(side * 0.3 * u, -0.75 * u, 0.1 * u), shape = "ellipsoid", size = V(0.28 * u, 0.25 * u, 0.4 * u), color = m.accent, role = "Accent" })
	end
	return 2.2 * u -- voa: altura de flutuação
end

local function buildSerpent(rig, m, u)
	local body = ModelKit.add(rig, { name = "Torso", joint = "Body", at = CF(0, 0, 0), shape = "ellipsoid", size = V(1.1 * u, 1.0 * u, 1.4 * u), color = m.body, role = "Body" }).Name
	local hd = head(rig, m, u, body, CF(0, 0.9 * u, -0.8 * u) * ANG(rad(-10), 0, 0), V(1.25 * u, 1.05 * u, 1.5 * u))
	ModelKit.eyes(rig, hd, 0.38 * u, 0.2 * u, -0.45 * u, 0.3 * u, m.glowEyes and m.eye or Color3.fromRGB(25, 22, 28), m.glowEyes)
	ModelKit.add(rig, { name = "Jaw", parent = hd, joint = "Jaw", at = CF(0, -0.35 * u, -0.25 * u), shape = "ellipsoid", size = V(1.0 * u, 0.35 * u, 1.1 * u), color = m.belly, role = "Belly" })
	if m.halo then
		addHalo(rig, m, u, hd, 1.0)
	end
	local prev = body
	for i = 1, 5 do
		local s = 1 - i * 0.12
		prev = ModelKit.add(rig, { name = "Seg" .. i, parent = prev, joint = "Seg" .. i, at = CF(0, -0.05 * u, 0.95 * u * s), shape = "ellipsoid",
			size = V(1.05 * u * s, 0.95 * u * s, 1.35 * u * s), color = i % 2 == 0 and darker(m.body, 0.9) or m.body, role = "Body" }).Name
		ModelKit.add(rig, { name = "SegBelly", parent = prev, at = CF(0, -0.3 * u * s, 0), shape = "ellipsoid", size = V(0.75 * u * s, 0.4 * u * s, 1.1 * u * s), color = m.belly, role = "Belly" })
		if m.back and i <= 4 then
			ModelKit.add(rig, { name = "SegFin", parent = prev, at = CF(0, 0.45 * u * s, 0) * ANG(0, rad(90), 0), shape = "wedge", size = V(0.08 * u, 0.45 * u * s, 0.6 * u * s),
				color = m.accent, material = m.back == "fins" and "Neon" or "Grass", role = "Accent" })
		end
	end
	if m.tail == "flame" then
		ModelKit.add(rig, { name = "TailFlame", parent = prev, at = CF(0, 0, 0.75 * u), shape = "ellipsoid", size = V(0.5 * u, 0.5 * u, 1.2 * u), color = m.accent, material = "Neon", transparency = 0.1, role = "Glow" })
	end
	return 0.55 * u
end

local function buildFloater(rig, m, u)
	local core = ModelKit.add(rig, { name = "Torso", joint = "Body", at = CF(0, 0, 0), shape = "ball", size = Vector3.one * 1.7 * u, color = m.body, role = "Body", transparency = 0.05 }).Name
	ModelKit.add(rig, { name = "Glow", parent = core, at = CF(0, 0, 0), shape = "ball", size = Vector3.one * 1.1 * u, color = m.belly, material = "Neon", transparency = 0.45, role = "Glow", shadow = false })
	local hd = ModelKit.add(rig, { name = "Head", parent = core, joint = "Neck", at = CF(0, 0, 0), shape = "block", size = Vector3.one * 0.2, transparency = 1, role = "Detail" }).Name
	ModelKit.eyes(rig, hd, 0.32 * u, 0.15 * u, -0.78 * u, 0.32 * u, m.glowEyes and m.eye or Color3.fromRGB(25, 22, 28), m.glowEyes)
	local tail = ModelKit.add(rig, { name = "Tail", parent = core, joint = "Tail", at = CF(0, -0.75 * u, 0.25 * u) * ANG(rad(25), 0, 0), shape = "ellipsoid", size = V(0.9 * u, 1.2 * u, 0.9 * u), color = m.body, transparency = 0.15, role = "Body" }).Name
	ModelKit.add(rig, { name = "TailWisp", parent = tail, at = CF(0, -0.7 * u, 0.15 * u), shape = "ellipsoid", size = V(0.45 * u, 0.8 * u, 0.45 * u), color = m.accent, transparency = 0.25, role = "Accent" })
	addOrbit(rig, m, u, core, m.orbit)
	if m.halo then
		addHalo(rig, m, u, hd, 1.15)
	end
	return 2.0 * u
end

local function buildGolem(rig, m, u)
	local body = ModelKit.add(rig, { name = "Torso", joint = "Body", at = CF(0, 0, 0), shape = "block", size = V(2.0 * u, 1.9 * u, 1.5 * u), color = m.body, material = "Slate", role = "Body" }).Name
	ModelKit.add(rig, { name = "Core", parent = body, at = CF(0, 0.1 * u, -0.72 * u), shape = "ball", size = Vector3.one * 0.6 * u, color = m.accent, material = "Neon", role = "Glow" })
	local hd = ModelKit.add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 1.3 * u, -0.1 * u), shape = "block", size = V(1.2 * u, 0.9 * u, 1.1 * u), color = m.body, material = "Slate", role = "Body" }).Name
	ModelKit.add(rig, { name = "Visor", parent = hd, at = CF(0, 0.05 * u, -0.56 * u), shape = "block", size = V(0.9 * u, 0.22 * u, 0.05 * u), color = m.eye, material = "Neon", role = "Eye" })
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "ArmL" or "ArmR"
		local a = ModelKit.add(rig, { name = name, parent = body, joint = name, at = CF(side * 1.35 * u, 0.5 * u, 0), shape = "block", size = V(0.1, 0.1, 0.1), transparency = 1, role = "Detail" }).Name
		ModelKit.add(rig, { name = "Shoulder", parent = a, at = CF(0, 0.1 * u, 0), shape = "block", size = V(0.9 * u, 0.7 * u, 0.9 * u), color = darker(m.body, 0.85), material = "Slate", role = "Body" })
		ModelKit.add(rig, { name = "Arm", parent = a, at = CF(side * 0.05 * u, -0.7 * u, 0), shape = "block", size = V(0.6 * u, 1.0 * u, 0.6 * u), color = m.body, material = "Slate", role = "Body" })
		ModelKit.add(rig, { name = "Fist", parent = a, at = CF(side * 0.05 * u, -1.35 * u, 0), shape = "block", size = V(0.85 * u, 0.7 * u, 0.85 * u), color = m.belly, material = "Slate", role = "Belly" })
		local lname = side < 0 and "LegL" or "LegR"
		local l = ModelKit.add(rig, { name = lname, parent = body, joint = lname, at = CF(side * 0.55 * u, -0.95 * u, 0), shape = "block", size = V(0.1, 0.1, 0.1), transparency = 1, role = "Detail" }).Name
		ModelKit.add(rig, { name = "Leg", parent = l, at = CF(0, -0.4 * u, 0), shape = "block", size = V(0.75 * u, 0.85 * u, 0.8 * u), color = m.belly, material = "Slate", role = "Belly" })
	end
	addBack(rig, m, u, body, m.back, 0.5)
	addOrbit(rig, m, u, body, m.orbit)
	return 0.95 * u + 0.85 * u
end

-- Slime: gota translúcida com brilho, olhos e um enfeite no topo (broto, cristal, coroa).
local function buildSlime(rig, m, u)
	local body = ModelKit.add(rig, { name = "Torso", joint = "Body", at = CF(0, 0, 0), shape = "ellipsoid", size = V(2.2 * u, 1.7 * u, 2.2 * u), color = m.body, material = m.glassy and "Glass" or "SmoothPlastic",
		transparency = 0.12, role = "Body" }).Name
	ModelKit.add(rig, { name = "Core", parent = body, at = CF(0, -0.15 * u, 0), shape = "ellipsoid", size = V(1.4 * u, 1.0 * u, 1.4 * u), color = m.belly, transparency = 0.25, role = "Belly", shadow = false })
	ModelKit.add(rig, { name = "Shine", parent = body, at = CF(-0.45 * u, 0.55 * u, -0.5 * u), shape = "ellipsoid", size = V(0.5 * u, 0.25 * u, 0.4 * u), color = Color3.new(1, 1, 1), transparency = 0.3, role = "Detail", shadow = false })
	local hd = ModelKit.add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 0, 0), shape = "block", size = V(0.2, 0.2, 0.2), transparency = 1, role = "Detail" }).Name
	ModelKit.eyes(rig, hd, 0.42 * u, 0.15 * u, -0.98 * u, 0.36 * u, m.glowEyes and m.eye or Color3.fromRGB(25, 22, 28), m.glowEyes)
	ModelKit.add(rig, { name = "Smile", parent = hd, at = CF(0, -0.22 * u, -1.05 * u), shape = "block", size = V(0.35 * u, 0.06 * u, 0.06 * u), color = Color3.fromRGB(30, 25, 40), role = "Detail" })
	local top = m.top
	if top == "sprout" then
		for _, side in ipairs({ -1, 1 }) do
			ModelKit.add(rig, { name = "Sprout", parent = body, joint = side < 0 and "EarL" or "EarR", at = CF(side * 0.25 * u, 1.0 * u, 0) * ANG(0, 0, side * rad(-40)),
				shape = "ellipsoid", size = V(0.3 * u, 0.7 * u, 0.12 * u), color = m.accent, material = "Grass", role = "Accent" })
		end
	elseif top == "crystal" then
		for k = -1, 1 do
			ModelKit.add(rig, { name = "TopCrystal", parent = body, at = CF(k * 0.35 * u, 0.95 * u, 0) * ANG(0, 0, rad(-k * 20)), shape = "block", size = V(0.3 * u, (0.8 - math.abs(k) * 0.25) * u, 0.3 * u),
				color = m.accent, material = "Glass", role = "Accent" })
		end
	elseif top == "crown" then
		ModelKit.ring(rig, body, nil, CF(0, 0.9 * u, 0), 0.4 * u, 5, Vector3.one * 0.22 * u, m.accent, "Neon", "Glow", "block")
	end
	return 0.85 * u
end

-- Cogumelo: caule com rostinho e chapéu grande pintado.
local function buildShroom(rig, m, u)
	local body = ModelKit.add(rig, { name = "Torso", joint = "Body", at = CF(0, 0, 0), shape = "ellipsoid", size = V(1.3 * u, 1.6 * u, 1.3 * u), color = m.belly, role = "Belly" }).Name
	local hd = ModelKit.add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 0.95 * u, 0), shape = "ellipsoid", size = V(2.6 * u, 1.3 * u, 2.6 * u), color = m.body, role = "Body" }).Name
	for k = 1, 5 do
		local a = k * 1.3
		ModelKit.add(rig, { name = "CapSpot", parent = hd, at = CF(math.cos(a) * 0.75 * u, 0.4 * u, math.sin(a) * 0.75 * u), shape = "ellipsoid", size = V(0.35 * u, 0.15 * u, 0.35 * u),
			color = m.accent, material = m.glowSpots and "Neon" or "SmoothPlastic", role = "Accent" })
	end
	local faceAnchor = ModelKit.add(rig, { name = "Face", parent = body, at = CF(0, 0, 0), shape = "block", size = V(0.2, 0.2, 0.2), transparency = 1, role = "Detail" }).Name
	ModelKit.eyes(rig, faceAnchor, 0.25 * u, 0.15 * u, -0.6 * u, 0.28 * u, m.glowEyes and m.eye or Color3.fromRGB(25, 22, 28), m.glowEyes)
	for _, side in ipairs({ -1, 1 }) do
		local lname = side < 0 and "LegL" or "LegR"
		local l = ModelKit.add(rig, { name = lname, parent = body, joint = lname, at = CF(side * 0.35 * u, -0.7 * u, 0), shape = "block", size = V(0.1, 0.1, 0.1), transparency = 1, role = "Detail" }).Name
		ModelKit.add(rig, { name = "Foot", parent = l, at = CF(0, -0.25 * u, -0.08 * u), shape = "ellipsoid", size = V(0.45 * u, 0.35 * u, 0.6 * u), color = darker(m.belly, 0.85), role = "Belly" })
		local aname = side < 0 and "ArmL" or "ArmR"
		local a = ModelKit.add(rig, { name = aname, parent = body, joint = aname, at = CF(side * 0.62 * u, 0, 0), shape = "block", size = V(0.1, 0.1, 0.1), transparency = 1, role = "Detail" }).Name
		ModelKit.add(rig, { name = "Arm", parent = a, at = CF(side * 0.12 * u, -0.25 * u, 0), shape = "ellipsoid", size = V(0.3 * u, 0.6 * u, 0.3 * u), color = m.belly, role = "Belly" })
	end
	return 1.2 * u
end

-- Ent/árvore viva: tronco com rosto, braços de galho, raízes e copa (cor da copa varia).
local function buildTreant(rig, m, u)
	local body = ModelKit.add(rig, { name = "Torso", joint = "Body", at = CF(0, 0, 0), shape = "block", size = V(1.5 * u, 2.4 * u, 1.3 * u), color = m.body, material = "Wood", role = "Body" }).Name
	ModelKit.add(rig, { name = "Bark", parent = body, at = CF(0, -0.2 * u, -0.66 * u), shape = "block", size = V(1.1 * u, 1.6 * u, 0.1 * u), color = darker(m.body, 0.75), material = "Wood", role = "Detail" })
	local hd = ModelKit.add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 1.5 * u, 0), shape = "block", size = V(0.2, 0.2, 0.2), transparency = 1, role = "Detail" }).Name
	ModelKit.eyes(rig, hd, 0.32 * u, -0.6 * u, -0.68 * u, 0.3 * u, m.eye, true)
	for k, o in ipairs({ { 0, 0.8, 0, 2.2 }, { 0.9, 0.4, 0.2, 1.5 }, { -0.9, 0.45, -0.1, 1.6 }, { 0.2, 0.5, 0.8, 1.4 }, { -0.2, 1.3, -0.3, 1.3 } }) do
		ModelKit.add(rig, { name = "Canopy", parent = hd, at = CF(o[1] * u, o[2] * u, o[3] * u), shape = "ball", size = Vector3.one * o[4] * u,
			color = k % 2 == 0 and darker(m.accent, 0.85) or m.accent, material = m.glowCanopy and "Neon" or "Grass", transparency = m.glowCanopy and 0.25 or 0, role = "Accent" })
	end
	if m.blossoms then
		for k = 1, 4 do
			local a = k * 1.6
			ModelKit.add(rig, { name = "Blossom", parent = hd, at = CF(math.cos(a) * 1.0 * u, 1.0 * u, math.sin(a) * 1.0 * u), shape = "ball", size = Vector3.one * 0.3 * u, color = m.blossoms, material = "Neon", role = "Glow" })
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		local aname = side < 0 and "ArmL" or "ArmR"
		local a = ModelKit.add(rig, { name = aname, parent = body, joint = aname, at = CF(side * 0.85 * u, 0.7 * u, 0), shape = "block", size = V(0.1, 0.1, 0.1), transparency = 1, role = "Detail" }).Name
		ModelKit.add(rig, { name = "Branch", parent = a, at = CF(side * 0.35 * u, -0.5 * u, 0) * ANG(0, 0, side * rad(25)), shape = "block", size = V(0.35 * u, 1.3 * u, 0.35 * u), color = m.body, material = "Wood", role = "Body" })
		ModelKit.add(rig, { name = "Twig", parent = a, at = CF(side * 0.75 * u, -1.15 * u, 0) * ANG(0, 0, side * rad(-20)), shape = "block", size = V(0.2 * u, 0.6 * u, 0.2 * u), color = m.body, material = "Wood", role = "Body" })
		ModelKit.add(rig, { name = "TwigLeaf", parent = a, at = CF(side * 0.85 * u, -1.5 * u, 0), shape = "ball", size = Vector3.one * 0.45 * u, color = m.accent, material = "Grass", role = "Accent" })
		local lname = side < 0 and "LegL" or "LegR"
		local l = ModelKit.add(rig, { name = lname, parent = body, joint = lname, at = CF(side * 0.45 * u, -1.2 * u, 0), shape = "block", size = V(0.1, 0.1, 0.1), transparency = 1, role = "Detail" }).Name
		ModelKit.add(rig, { name = "Root", parent = l, at = CF(0, -0.4 * u, 0), shape = "block", size = V(0.5 * u, 0.9 * u, 0.6 * u), color = darker(m.body, 0.85), material = "Wood", role = "Body" })
		ModelKit.add(rig, { name = "RootToe", parent = l, at = CF(side * 0.15 * u, -0.8 * u, -0.3 * u) * ANG(rad(-60), 0, 0), shape = "block", size = V(0.3 * u, 0.7 * u, 0.25 * u), color = darker(m.body, 0.85), material = "Wood", role = "Body" })
	end
	if m.glowCore then
		ModelKit.add(rig, { name = "Core", parent = body, at = CF(0, 0.2 * u, -0.68 * u) * ANG(0, 0, rad(45)), shape = "block", size = V(0.4 * u, 0.4 * u, 0.1 * u), color = m.glowCore, material = "Neon", role = "Glow" })
	end
	return 1.2 * u + 0.85 * u
end

local BUILDERS = { quad = buildQuad, biped = buildBiped, flyer = buildFlyer, serpent = buildSerpent, floater = buildFloater, golem = buildGolem,
	slime = buildSlime, shroom = buildShroom, treant = buildTreant }

-- Constrói um pet. Retorna (model, alturaDoRootAcimaDoChao, flutua?)
function CreatureBuilder.build(speciesId: string, species, scaleMul: number?)
	local m = species.model
	local u = (m.size or 1) * (scaleMul or 1) * 1.1
	local rig = ModelKit.newRig(speciesId, Vector3.new(2 * u, 2 * u, 2.4 * u))
	local builder = BUILDERS[m.rig] or buildQuad
	local hoverHeight = builder(rig, m, u)
	rig.model:SetAttribute("Rig", m.rig)
	rig.model:SetAttribute("Species", speciesId)
	local flies = m.rig == "flyer" or m.rig == "floater"
	return rig.model, hoverHeight, flies
end

CreatureBuilder.addWings = addWings
CreatureBuilder.addTail = addTail
CreatureBuilder.addBack = addBack
CreatureBuilder.addHorns = addHorns
CreatureBuilder.addEars = addEars
CreatureBuilder.addOrbit = addOrbit
CreatureBuilder.face = face

return CreatureBuilder

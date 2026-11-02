-- Construtor procedural dos PETS a partir de Config/Pets.model.
-- Arquétipos: quad (quadrúpede), biped, flyer (ave/dragãozinho), serpent, floater (espírito), golem,
-- slime, shroom (cogumelo) e treant (árvore viva).
--
-- Anatomia "estilizada realista": volumes sobrepostos (peito, ombros, ancas, pescoço), contra-sombreamento
-- do pelo (dorso mais escuro, barriga clara), focinho com almofadas e nariz úmido, olhos com íris,
-- pupila, dois brilhos e pálpebra que pisca, orelhas em camadas, patas com dedos e caudas articuladas.
-- Frente da criatura = -Z (LookVector do Roblox).
--
-- Juntas animadas pelo Animator do cliente (pelo NOME do Motor6D): Body, Neck, Jaw, Leg*, Arm*, Wing*,
-- Tail*, TailSeg* (cauda em cadeia), Seg*, Ear*, Lid* (piscar), Orbit*, Petal*.

local ModelKit = require(script.Parent.ModelKit)

local CreatureBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function darker(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function lum(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

-- Paleta derivada das cores da espécie (sombreamento, nariz, interior da orelha, íris naturais).
local function palette(m)
	local body, belly, accent = m.body, m.belly or m.body, m.accent or m.body
	local light = lum(body) > 0.62
	local P = {
		body = body, belly = belly, accent = accent,
		dorsal = darker(body, light and 0.86 or 0.78), -- dorso
		deep = darker(body, 0.58), -- pontas de orelha/patas
		soft = body:Lerp(belly, 0.45), -- transição pelo → barriga (bochechas, peito)
		bib = belly:Lerp(WHITE, 0.12),
		inner = belly:Lerp(Color3.fromRGB(236, 150, 160), 0.45), -- interior da orelha
		nose = light and Color3.fromRGB(190, 112, 124) or Color3.fromRGB(42, 30, 34),
		claw = Color3.fromRGB(62, 52, 50),
		rim = darker(body, 0.25):Lerp(Color3.fromRGB(20, 16, 18), 0.6),
	}
	-- íris: olhos brilhantes usam a cor da espécie; olhos "comuns" (cor escura) recebem uma íris natural
	if m.glowEyes then
		P.iris = m.eye or accent
	elseif m.eye and lum(m.eye) > 0.22 then
		P.iris = m.eye
	else
		P.iris = Color3.fromRGB(122, 76, 34):Lerp(accent, 0.22)
	end
	return P
end

local function add(rig, spec)
	return ModelKit.add(rig, spec).Name
end

local function hub(rig, name, parent, joint, at)
	return add(rig, { name = name, parent = parent, joint = joint, at = at, shape = "block", size = V(0.1, 0.1, 0.1), transparency = 1, role = "Detail" })
end

-- Volume de pelo com contra-sombreamento: peça principal + "sela" dorsal mais escura + barriga clara.
local function furVolume(rig, P, spec)
	local s = spec.size
	local name = add(rig, { name = spec.name, parent = spec.parent, joint = spec.joint, at = spec.at, shape = "ellipsoid", size = s, color = spec.color or P.body, role = "Body",
		material = spec.material })
	if spec.dorsal == true then
		add(rig, { name = "Dorsal", parent = name, at = CF(0, s.Y * 0.09, s.Z * 0.02), shape = "ellipsoid", size = V(s.X * 0.8, s.Y * 0.9, s.Z * 0.93), color = P.dorsal, role = "Body",
			material = spec.material })
	end
	if spec.belly ~= false then
		add(rig, { name = "Underside", parent = name, at = CF(0, -s.Y * 0.19, -s.Z * 0.03), shape = "ellipsoid", size = V(s.X * 0.78, s.Y * 0.7, s.Z * 0.84), color = P.belly, role = "Belly" })
	end
	return name
end

-------------------------------------------------------------------------------
-- Rosto
-------------------------------------------------------------------------------

-- Par de olhos detalhados na superfície da cabeça (hs = tamanho da cabeça).
local function eyes(rig, m, P, hd, hs: Vector3, fx, fy, d, opts)
	opts = opts or {}
	for _, side in ipairs({ -1, 1 }) do
		local at = ModelKit.surface(hs, side * fx, fy, -0.06 * d) * ANG(0, 0, side * rad(opts.tilt or -4))
		ModelKit.detailedEye(rig, hd, at, d, side, {
			glow = m.glowEyes == true or opts.glow == true, iris = opts.iris or P.iris, rim = P.rim, slit = opts.slit,
			lid = opts.noLid ~= true and (opts.lidColor or P.body) or nil, lidTilt = opts.lidTilt or -10,
		})
	end
end

-- Cabeça de mamífero: crânio, testa sombreada, bochechas fofas, focinho com almofadas, queixo, nariz úmido e bigodes.
local function mammalHead(rig, m, P, u, parent, at, hs: Vector3, opts)
	opts = opts or {}
	local hd = add(rig, { name = "Head", parent = parent, joint = "Neck", at = at, shape = "ellipsoid", size = hs, color = P.body, role = "Body" })
	local a, b, c = hs.X / 2, hs.Y / 2, hs.Z / 2
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "Cheek", parent = hd, at = CF(side * a * 0.52, -b * 0.36, -c * 0.3), shape = "ellipsoid", size = V(a * 0.86, b * 0.76, c * 0.9), color = P.body:Lerp(P.belly, 0.25), role = "Body" })
		if opts.ruff then
			add(rig, { name = "CheekTuft", parent = hd, at = CF(side * a * 0.8, -b * 0.46, -c * 0.05) * ANG(0, side * rad(-15), side * rad(-28)), shape = "ellipsoid",
				size = V(a * 0.78, b * 0.36, c * 0.55), color = P.body:Lerp(P.belly, 0.35), role = "Body" })
		end
	end
	local k = m.snout or 1
	if m.beak then
		local bc = m.beakColor or Color3.fromRGB(236, 182, 72)
		add(rig, { name = "Beak", parent = hd, at = CF(0, -b * 0.08, -c * 1.05) * ANG(0, rad(180), 0), shape = "wedge", size = V(a * 0.45, b * 0.32, c * 0.75), color = bc, role = "Detail" })
		add(rig, { name = "BeakLow", parent = hd, at = CF(0, -b * 0.34, -c * 0.98) * ANG(0, 0, rad(180)) * ANG(0, rad(180), 0), shape = "wedge", size = V(a * 0.4, b * 0.2, c * 0.6), color = darker(bc, 0.85), role = "Detail" })
	elseif opts.snout ~= false then
		local reach = c * (0.62 + 0.3 * (k - 1))
		-- ponte do nariz (cor do pelo) e almofadas dos bigodes (claras)
		add(rig, { name = "Muzzle", parent = hd, at = CF(0, -b * 0.12, -reach), shape = "ellipsoid", size = V(a * 0.62, b * 0.58, c * 0.75 * k), color = P.body, role = "Body" })
		for _, side in ipairs({ -1, 1 }) do
			add(rig, { name = "Pad", parent = hd, at = CF(side * a * 0.2, -b * 0.36, -reach - c * 0.14 * k), shape = "ellipsoid", size = V(a * 0.5, b * 0.42, c * 0.56 * k), color = P.bib, role = "Belly" })
		end
		add(rig, { name = "Chin", parent = hd, at = CF(0, -b * 0.6, -reach + c * 0.05), shape = "ellipsoid", size = V(a * 0.52, b * 0.32, c * 0.6 * k), color = P.belly, role = "Belly" })
		local tip = reach + c * 0.42 * k
		add(rig, { name = "Nose", parent = hd, at = CF(0, -b * 0.1, -tip), shape = "ellipsoid", size = V(a * 0.36, b * 0.24, c * 0.26), color = P.nose, role = "Detail", reflectance = 0.18 })
		add(rig, { name = "Mouth", parent = hd, at = CF(0, -b * 0.42, -tip + c * 0.06), shape = "block", size = V(0.03 * u, b * 0.2, 0.03 * u), color = P.rim, role = "Detail", shadow = false })
		if opts.whiskers then
			for _, side in ipairs({ -1, 1 }) do
				for i = 0, 1 do
					add(rig, { name = "Whisker", parent = hd, at = CF(side * a * 0.62, -b * (0.3 + i * 0.1), -reach - c * 0.05) * ANG(0, side * rad(18 - i * 10), side * rad(-6 + i * 12)),
						shape = "block", size = V(a * 0.75, 0.014 * u, 0.014 * u), color = WHITE:Lerp(P.belly, 0.2), transparency = 0.4, role = "Detail", shadow = false })
				end
			end
		end
	else
		add(rig, { name = "Nose", parent = hd, at = ModelKit.surface(hs, 0, -0.22, 0), shape = "ellipsoid", size = V(a * 0.22, b * 0.14, c * 0.16), color = P.nose, role = "Detail" })
	end
	eyes(rig, m, P, hd, hs, opts.eyeX or 0.43, opts.eyeY or 0.14, opts.eyeD or a * 0.5, { slit = opts.slit })
	return hd
end

-------------------------------------------------------------------------------
-- Orelhas, chifres, caudas, costas, asas
-------------------------------------------------------------------------------

local function addEars(rig, m, P, u, hd, hs: Vector3, kind)
	if not kind then
		return
	end
	local a, b = hs.X / 2, hs.Y / 2
	for _, side in ipairs({ -1, 1 }) do
		local joint = side < 0 and "EarL" or "EarR"
		if kind == "pointy" or kind == "tufted" or kind == "crystal" then
			local base = CF(side * a * 0.5, b * 0.72, 0.08 * u) * ANG(rad(-6), side * rad(-12), side * rad(-16))
			local e = hub(rig, "Ear", hd, joint, base)
			local w, h = 0.66 * u, (kind == "tufted" and 0.82 or 0.86) * u
			local crystal = kind == "crystal"
			ModelKit.tri(rig, { name = "EarOuter", parent = e, at = CF(), width = w, height = h, thickness = 0.16 * u,
				color = crystal and P.accent or P.body, material = crystal and "Glass" or nil, transparency = crystal and 0.1 or nil, role = crystal and "Accent" or "Body" })
			if not crystal then
				ModelKit.tri(rig, { name = "EarInner", parent = e, at = CF(0, 0.06 * u, -0.07 * u), width = w * 0.58, height = h * 0.66, thickness = 0.06 * u, color = P.inner, role = "Belly", shadow = false })
				ModelKit.tri(rig, { name = "EarTip", parent = e, at = CF(0, h * 0.64, 0.005 * u), width = w * 0.36, height = h * 0.36, thickness = 0.175 * u, color = P.deep, role = "Body", shadow = false })
				if kind == "tufted" then
					ModelKit.tri(rig, { name = "EarTuft", parent = e, at = CF(0, h * 0.92, 0), width = 0.12 * u, height = 0.38 * u, thickness = 0.06 * u, color = darker(P.body, 0.4), role = "Detail", shadow = false })
				end
			end
		elseif kind == "round" or kind == "mouse" then
			local big = kind == "mouse"
			local e = add(rig, { name = "Ear", parent = hd, joint = joint, at = CF(side * a * (big and 0.66 or 0.62), b * (big and 0.74 or 0.72), 0.1 * u) * ANG(rad(-8), side * rad(-18), side * rad(-20)),
				shape = "ellipsoid", size = (big and V(0.9, 0.86, 0.18) or V(0.62, 0.58, 0.24)) * u, color = P.body, role = "Body" })
			add(rig, { name = "EarInner", parent = e, at = CF(0, -0.02 * u, -0.07 * u), shape = "ellipsoid", size = (big and V(0.64, 0.6, 0.08) or V(0.4, 0.36, 0.1)) * u, color = P.inner, role = "Belly", shadow = false })
		elseif kind == "long" then
			local e = hub(rig, "Ear", hd, joint, CF(side * a * 0.36, b * 0.82, 0.12 * u) * ANG(rad(-14), side * rad(-8), side * rad(-12)))
			add(rig, { name = "EarOuter", parent = e, at = CF(0, 0.62 * u, 0), shape = "ellipsoid", size = V(0.4, 1.38, 0.2) * u, color = P.body, role = "Body" })
			add(rig, { name = "EarInner", parent = e, at = CF(0, 0.58 * u, -0.07 * u), shape = "ellipsoid", size = V(0.24, 1.08, 0.08) * u, color = P.inner, role = "Belly", shadow = false })
			add(rig, { name = "EarTip", parent = e, at = CF(0, 1.18 * u, 0.01 * u), shape = "ellipsoid", size = V(0.3, 0.3, 0.205) * u, color = P.deep, role = "Body", shadow = false })
		elseif kind == "leafy" then
			local e = hub(rig, "Ear", hd, joint, CF(side * a * 0.55, b * 0.7, 0.08 * u) * ANG(rad(-10), 0, side * rad(-38)))
			add(rig, { name = "EarLeaf", parent = e, at = CF(0, 0.5 * u, 0), shape = "ellipsoid", size = V(0.38, 1.1, 0.1) * u, color = P.accent, material = "Grass", role = "Accent" })
			add(rig, { name = "EarVein", parent = e, at = CF(0, 0.5 * u, -0.04 * u), shape = "block", size = V(0.035, 0.9, 0.03) * u, color = P.accent:Lerp(WHITE, 0.35), role = "Accent", shadow = false })
		elseif kind == "feelers" then
			local e = hub(rig, "Feeler", hd, joint, CF(side * a * 0.32, b * 0.82, -0.15 * u) * ANG(rad(-22), 0, side * rad(-22)))
			add(rig, { name = "FeelerStalk", parent = e, at = CF(0, 0.45 * u, 0), shape = "ellipsoid", size = V(0.07, 0.9, 0.07) * u, color = P.deep, role = "Detail" })
			add(rig, { name = "FeelerTip", parent = e, at = CF(0, 0.92 * u, 0), shape = "ball", size = Vector3.one * 0.2 * u, color = P.accent, material = "Neon", role = "Accent", shadow = false })
		end
	end
end

local function addHorns(rig, m, P, u, hd, hs: Vector3, kind)
	if not kind then
		return
	end
	local a, b = hs.X / 2, hs.Y / 2
	local antlerCol = m.antler or Color3.fromRGB(196, 170, 132)
	for _, side in ipairs({ -1, 1 }) do
		if kind == "antlers" then
			local base = CF(side * a * 0.36, b * 0.86, 0.06 * u) * ANG(rad(-12), 0, side * rad(-22))
			local mat = m.glowHorns and "Neon" or "SmoothPlastic"
			local col = m.glowHorns and P.accent or antlerCol
			add(rig, { name = "AntlerBase", parent = hd, at = base * CF(0, 0.02 * u, 0), shape = "ball", size = Vector3.one * 0.2 * u, color = darker(col, 0.8), material = mat, role = "Accent" })
			add(rig, { name = "Antler", parent = hd, at = base * CF(0, 0.42 * u, 0), shape = "ellipsoid", size = V(0.13, 0.85, 0.13) * u, color = col, material = mat, role = "Accent" })
			add(rig, { name = "AntlerTine", parent = hd, at = base * CF(side * 0.16 * u, 0.62 * u, -0.06 * u) * ANG(rad(-10), 0, side * rad(-48)), shape = "ellipsoid", size = V(0.1, 0.55, 0.1) * u, color = col, material = mat, role = "Accent" })
			add(rig, { name = "AntlerTine", parent = hd, at = base * CF(-side * 0.06 * u, 0.9 * u, 0.02 * u) * ANG(rad(12), 0, side * rad(14)), shape = "ellipsoid", size = V(0.09, 0.48, 0.09) * u, color = col, material = mat, role = "Accent" })
		elseif kind == "crystal" then
			local base = CF(side * a * 0.34, b * 0.8, 0.12 * u) * ANG(rad(-18), 0, side * rad(-14))
			ModelKit.tri(rig, { name = "Horn", parent = hd, at = base, width = 0.36 * u, height = 0.9 * u, thickness = 0.2 * u, color = P.accent, material = "Glass", transparency = 0.12, role = "Accent" })
		elseif kind == "curled" then
			for i = 0, 5 do
				local t = rad(i * 50)
				add(rig, { name = "HornSeg", parent = hd, at = CF(side * (a * 0.62 + 0.14 * u * math.sin(t)), b * 0.5 + 0.42 * u * math.cos(t), 0.12 * u + 0.34 * u * math.sin(t)),
					shape = "ball", size = Vector3.one * (0.34 - i * 0.035) * u, color = Color3.fromRGB(150, 130, 108):Lerp(P.accent, 0.15):Lerp(BLACK, i * 0.04), role = "Accent" })
			end
		elseif kind == "grand" or kind == "crystalAntlers" then
			-- galhada enorme e ramificada (Sylvanox: com flores e cipós; cristal: de vidro)
			local crystalA = kind == "crystalAntlers"
			local mat = crystalA and "Glass" or "Wood"
			local col = crystalA and P.accent or (m.antler or darker(P.body, 0.75))
			local main = CF(side * a * 0.38, b * 0.8, 0.15 * u) * ANG(rad(-10), 0, side * rad(-22))
			add(rig, { name = "Antler", parent = hd, at = main * CF(0, 1.1 * u, 0), shape = "ellipsoid", size = V(0.2 * u, 2.3 * u, 0.2 * u), color = col, material = mat, role = "Accent" })
			for k = 1, 4 do
				local tine = main * CF(0, 0.45 * u * k, 0) * ANG(rad(k % 2 == 0 and -25 or 15), 0, side * rad(-50 + k * 6)) * CF(0, 0.45 * u, 0)
				add(rig, { name = "Tine", parent = hd, at = tine, shape = "ellipsoid", size = V(0.14 * u, (1.05 - k * 0.1) * u, 0.14 * u), color = col, material = mat, role = "Accent" })
				if kind == "grand" then
					add(rig, { name = "AntlerFlower", parent = hd, at = tine * CF(0, 0.5 * u, 0), shape = "ball", size = Vector3.one * 0.22 * u,
						color = ({ Color3.fromRGB(255, 160, 210), Color3.fromRGB(150, 200, 255), Color3.fromRGB(255, 240, 150), Color3.fromRGB(200, 150, 255) })[k], material = "Neon", role = "Glow", shadow = false })
				end
			end
			if kind == "grand" then
				for k = 1, 2 do
					add(rig, { name = "HangingVine", parent = hd, at = main * CF(side * 0.35 * u * k, (1.0 + k * 0.4) * u, 0.1 * u) * CF(0, -0.55 * u, 0),
						shape = "ellipsoid", size = V(0.07 * u, 1.1 * u, 0.07 * u), color = P.accent, material = "Grass", role = "Accent", shadow = false })
				end
			end
		elseif kind == "tusks" then
			add(rig, { name = "Tusk", parent = hd, at = CF(side * a * 0.36, -b * 0.55, -hs.Z * 0.48) * ANG(rad(-55), 0, side * rad(-10)), shape = "ellipsoid", size = V(0.13, 0.62, 0.13) * u,
				color = Color3.fromRGB(240, 232, 212), role = "Detail" })
		elseif kind == "nubs" then
			add(rig, { name = "Horn", parent = hd, at = CF(side * a * 0.36, b * 0.86, 0.02 * u) * ANG(0, 0, side * rad(-15)), shape = "ellipsoid", size = V(0.2, 0.3, 0.2) * u, color = antlerCol:Lerp(P.accent, 0.3), role = "Accent" })
		end
	end
end

-- Cauda em cadeia: o 1º segmento usa a junta `joint` ("Tail"...), os seguintes "TailSeg2", "TailSeg3"...
-- (o Animator propaga uma onda amortecida pela cadeia). radii = raio de cada segmento.
local function tailChain(rig, parent, at, joint, segLen, radii, colors, opts)
	opts = opts or {}
	local prev = parent
	local first
	for i, r in ipairs(radii) do
		local seg = add(rig, {
			name = i == 1 and "Tail" or "TailSeg", parent = prev, joint = i == 1 and joint or (opts.chainJoints ~= false and ("TailSeg" .. i) or nil),
			at = (i == 1 and at or CF(0, 0, segLen)) * ANG(rad(opts.curve or -8), rad(opts.sway or 0), 0),
			shape = "ellipsoid", size = V(r * 2, r * 2 * (opts.flat or 1), segLen * 1.55), color = colors[i] or colors[#colors],
			material = opts.material, role = "Body",
		})
		first = first or seg
		prev = seg
	end
	return first, prev
end

local function addTail(rig, m, P, u, parent, at, kind)
	if not kind then
		return
	end
	if kind == "fluffy" then
		-- cauda de raposa: grossa no meio, ponta clara
		local _, last = tailChain(rig, parent, at * ANG(rad(32), 0, 0), "Tail", 0.42 * u, { 0.26 * u, 0.38 * u, 0.42 * u, 0.36 * u },
			{ P.body, P.body, P.dorsal, P.body }, { curve = -10 })
		add(rig, { name = "TailTip", parent = last, at = CF(0, 0, 0.42 * u), shape = "ellipsoid", size = V(0.56, 0.56, 0.8) * u, color = P.bib, role = "Belly" })
	elseif kind == "thin" then
		local _, last = tailChain(rig, parent, at * ANG(rad(30), 0, 0), "Tail", 0.4 * u, { 0.12 * u, 0.1 * u, 0.085 * u, 0.07 * u }, { P.body, P.body, P.dorsal, P.dorsal }, { curve = -12 })
		add(rig, { name = "TailTuft", parent = last, at = CF(0, 0, 0.36 * u), shape = "ellipsoid", size = V(0.3, 0.3, 0.46) * u, color = P.accent, role = "Accent" })
	elseif kind == "leaf" then
		local t = hub(rig, "Tail", parent, "Tail", at * ANG(rad(22), 0, 0))
		for i = -1, 1 do
			add(rig, { name = "TailLeaf", parent = t, at = CF(i * 0.18 * u, 0, 0.6 * u) * ANG(0, rad(i * 22), rad(i * 12)), shape = "ellipsoid", size = V(0.62, 0.08, 1.35) * u,
				color = i == 0 and P.accent or darker(P.accent, 0.82), material = "Grass", role = "Accent" })
		end
		add(rig, { name = "TailVein", parent = t, at = CF(0, 0.045 * u, 0.6 * u), shape = "block", size = V(0.04, 0.02, 1.15) * u, color = P.accent:Lerp(WHITE, 0.4), role = "Accent", shadow = false })
	elseif kind == "crystal" then
		local _, last = tailChain(rig, parent, at * ANG(rad(26), 0, 0), "Tail", 0.38 * u, { 0.16 * u, 0.13 * u, 0.1 * u }, { P.body, P.dorsal, P.dorsal }, { curve = -10 })
		ModelKit.tri(rig, { name = "TailGem", parent = last, at = CF(0, 0, 0.3 * u) * ANG(rad(90), 0, 0), width = 0.46 * u, height = 0.75 * u, thickness = 0.22 * u, color = P.accent, material = "Glass", transparency = 0.08, role = "Accent" })
	elseif kind == "flame" then
		local _, last = tailChain(rig, parent, at * ANG(rad(24), 0, 0), "Tail", 0.4 * u, { 0.2 * u, 0.17 * u, 0.14 * u }, { P.body, P.body, P.dorsal }, { curve = -12 })
		add(rig, { name = "TailFlame", parent = last, at = CF(0, 0.12 * u, 0.42 * u), shape = "ellipsoid", size = V(0.5, 0.72, 0.85) * u, color = P.accent, material = "Neon", transparency = 0.12, role = "Glow", shadow = false })
		add(rig, { name = "TailFlameCore", parent = last, at = CF(0, 0.08 * u, 0.36 * u), shape = "ellipsoid", size = V(0.28, 0.42, 0.5) * u, color = P.accent:Lerp(WHITE, 0.55), material = "Neon", role = "Glow", shadow = false })
	elseif kind == "cloud" then
		local t = add(rig, { name = "Tail", parent = parent, joint = "Tail", at = at * ANG(rad(40), 0, 0), shape = "ball", size = Vector3.one * 0.7 * u, color = P.belly, role = "Belly" })
		add(rig, { name = "TailPuff", parent = t, at = CF(0.2 * u, 0.15 * u, 0.4 * u), shape = "ball", size = Vector3.one * 0.55 * u, color = P.belly:Lerp(WHITE, 0.2), role = "Belly" })
		add(rig, { name = "TailPuff", parent = t, at = CF(-0.2 * u, 0.25 * u, 0.6 * u), shape = "ball", size = Vector3.one * 0.45 * u, color = P.accent, role = "Accent" })
	elseif kind == "multi" then
		-- várias caudas (kitsune): cada uma é uma cadeia curta
		for i = -2, 2 do
			local _, last = tailChain(rig, parent, at * ANG(rad(48 - math.abs(i) * 6), rad(i * 24), 0), "Tail" .. (i + 3), 0.4 * u, { 0.2 * u, 0.28 * u, 0.26 * u },
				{ P.body, P.body, P.body }, { curve = -12, chainJoints = false })
			add(rig, { name = "TailTip", parent = last, at = CF(0, 0, 0.36 * u), shape = "ellipsoid", size = V(0.38, 0.38, 0.56) * u, color = i == 0 and P.accent or P.bib,
				material = i == 0 and "Neon" or nil, role = i == 0 and "Accent" or "Belly" })
		end
	elseif kind == "feather" then
		local t = hub(rig, "Tail", parent, "Tail", at * ANG(rad(8), 0, 0))
		for i = -2, 2 do
			add(rig, { name = "TailFeather", parent = t, at = CF(i * 0.08 * u, -0.01 * math.abs(i) * u, 0.55 * u) * ANG(0, rad(i * 14), 0) * CF(0, 0, 0.05 * u * math.abs(i)),
				shape = "ellipsoid", size = V(0.28, 0.06, 1.25 - math.abs(i) * 0.12) * u, color = i == 0 and P.accent or (math.abs(i) == 1 and P.body or P.dorsal), role = i == 0 and "Accent" or "Body" })
		end
	elseif kind == "fan" then
		-- leque de caudas de cristal (raposas de Crystal Hollow; muitas = mítico/secret)
		local n = m.tailCount or 3
		for i = 1, n do
			local t = n == 1 and 0 or ((i - 1) / (n - 1) - 0.5)
			local j = add(rig, { name = "Tail", parent = parent, joint = i == math.ceil(n / 2) and "Tail" or ("Tail" .. i), at = at * ANG(rad(55 - math.abs(t) * 30), rad(t * 110), 0) * CF(0, 0, 0.55 * u),
				shape = "ellipsoid", size = V(0.36, 0.36, 1.25) * u, color = P.body, role = "Body" })
			ModelKit.tri(rig, { name = "TailShard", parent = j, at = CF(0, 0, 0.45 * u) * ANG(rad(90), 0, 0), width = 0.4 * u, height = 0.9 * u, thickness = 0.16 * u,
				color = i % 2 == 0 and P.accent or P.belly, material = "Glass", transparency = 0.05, role = "Accent" })
		end
	elseif kind == "leafy" then
		-- cauda de esquilo: grande, curvada para cima, com folhas
		local _, last = tailChain(rig, parent, at * ANG(rad(58), 0, 0), "Tail", 0.42 * u, { 0.3 * u, 0.4 * u, 0.42 * u, 0.36 * u }, { P.body, P.body, P.dorsal, P.body }, { curve = -22 })
		for k = 1, 3 do
			add(rig, { name = "TailLeaf", parent = last, at = CF((k - 2) * 0.22 * u, 0.3 * u, (k - 2) * 0.12 * u) * ANG(rad(-20), rad((k - 2) * 30), rad((k - 2) * 40)), shape = "ellipsoid",
				size = V(0.42, 0.08, 0.68) * u, color = k == 2 and P.accent or darker(P.accent, 0.85), material = "Grass", role = "Accent" })
		end
	elseif kind == "nub" then
		local t = add(rig, { name = "Tail", parent = parent, joint = "Tail", at = at, shape = "ball", size = Vector3.one * 0.42 * u, color = P.body, role = "Body" })
		add(rig, { name = "TailFluff", parent = t, at = CF(0, -0.04 * u, 0.08 * u), shape = "ball", size = Vector3.one * 0.32 * u, color = P.bib, role = "Belly" })
	end
end

local function addBack(rig, m, P, u, body, kind, len)
	if not kind then
		return
	end
	len = len or 1
	if kind == "moss" then
		for i, p in ipairs({ { 0, 0.8, 0.15 }, { 0.42, 0.66, -0.3 }, { -0.42, 0.68, 0.45 }, { 0.12, 0.76, -0.68 }, { -0.25, 0.74, -0.15 } }) do
			add(rig, { name = "Moss", parent = body, at = CF(p[1] * u, p[2] * u, p[3] * u * len), shape = "ellipsoid",
				size = V((0.85 - i * 0.07) * u, 0.32 * u, (0.8 - i * 0.05) * u), color = i % 2 == 0 and darker(P.accent, 0.85) or P.accent, material = "Grass", role = "Accent" })
		end
	elseif kind == "thorns" then
		for i = -2, 2 do
			ModelKit.tri(rig, { name = "Thorn", parent = body, at = CF(0, 0.7 * u, i * 0.42 * u * len) * ANG(rad(-14), rad(90), 0), width = 0.42 * u, height = (0.55 - math.abs(i) * 0.06) * u,
				thickness = 0.12 * u, color = P.accent, role = "Accent" })
		end
	elseif kind == "crystals" then
		for i, p in ipairs({ { 0, 0.75, 0 }, { 0.35, 0.62, 0.5 }, { -0.35, 0.65, -0.4 }, { -0.2, 0.62, 0.7 }, { 0.3, 0.66, -0.6 } }) do
			add(rig, { name = "Crystal", parent = body, at = CF(p[1] * u, p[2] * u, p[3] * u * len) * ANG(rad(i * 13 - 20), rad(i * 40), rad(p[1] * 50)),
				shape = "block", size = V(0.3 * u, (0.9 - i * 0.08) * u, 0.3 * u), color = P.accent, material = "Glass", transparency = 0.1, role = "Accent" })
		end
	elseif kind == "flowers" then
		for _, p in ipairs({ { 0.3, 0.72, 0.1 }, { -0.35, 0.68, 0.5 }, { 0, 0.78, -0.5 } }) do
			local c = add(rig, { name = "Flower", parent = body, at = CF(p[1] * u, p[2] * u, p[3] * u * len), shape = "ball", size = Vector3.one * 0.22 * u, color = Color3.fromRGB(255, 226, 110), role = "Detail" })
			for k = 1, 5 do
				local a = k / 5 * math.pi * 2
				add(rig, { name = "Petal", parent = c, at = CF(math.cos(a) * 0.2 * u, -0.02 * u, math.sin(a) * 0.2 * u) * ANG(0, -a, rad(-12)), shape = "ellipsoid",
					size = V(0.3 * u, 0.07 * u, 0.2 * u), color = k % 2 == 0 and P.accent or P.accent:Lerp(WHITE, 0.25), role = "Accent", shadow = false })
			end
		end
	elseif kind == "wool" then
		for _, p in ipairs({ { 0, 0.72, 0 }, { 0.48, 0.5, 0.4 }, { -0.48, 0.5, 0.4 }, { 0.48, 0.5, -0.4 }, { -0.48, 0.5, -0.4 }, { 0, 0.66, 0.8 }, { 0, 0.66, -0.8 } }) do
			add(rig, { name = "Wool", parent = body, at = CF(p[1] * u, p[2] * u, p[3] * u * len), shape = "ball", size = Vector3.one * 0.9 * u, color = P.body, material = "Fabric", role = "Body" })
		end
		add(rig, { name = "Spark", parent = body, at = CF(0, 1.1 * u, 0), shape = "ball", size = Vector3.one * 0.3 * u, color = P.accent, material = "Neon", role = "Glow" })
	elseif kind == "mane" then
		-- juba volumosa em duas camadas ao redor do pescoço
		for i = 1, 10 do
			local a = (i - 1) / 10 * math.pi * 2
			add(rig, { name = "Mane", parent = body, at = CF(math.cos(a) * 0.82 * u, 0.5 * u + math.sin(a) * 0.68 * u, -1.0 * u * len) * ANG(rad(-25), 0, a - math.pi / 2) * CF(0, 0.15 * u, 0),
				shape = "ellipsoid", size = V(0.62 * u, 1.0 * u, 0.7 * u), color = i % 2 == 0 and P.accent or darker(P.accent, 0.78), role = "Accent" })
		end
		for i = 1, 6 do
			local a = (i - 0.5) / 6 * math.pi * 2
			add(rig, { name = "ManeInner", parent = body, at = CF(math.cos(a) * 0.5 * u, 0.55 * u + math.sin(a) * 0.42 * u, -1.25 * u * len) * ANG(rad(-30), 0, a - math.pi / 2),
				shape = "ellipsoid", size = V(0.5 * u, 0.8 * u, 0.55 * u), color = P.accent:Lerp(WHITE, 0.15), role = "Accent" })
		end
	elseif kind == "stars" then
		for i = 1, 6 do
			local a = i * 1.7
			add(rig, { name = "StarSpeck", parent = body, at = CF(math.cos(a) * 0.6 * u, 0.62 * u + (i % 2) * 0.1 * u, math.sin(a) * 0.8 * u * len),
				shape = "ball", size = Vector3.one * 0.15 * u, color = P.accent, material = "Neon", role = "Glow", shadow = false })
		end
	elseif kind == "shell" or kind == "tree" then
		-- casco de tartaruga com placas (com árvore e musgo nas lendárias)
		local shellCol = m.shell or darker(P.accent, 0.7)
		local sh = add(rig, { name = "Shell", parent = body, at = CF(0, 0.42 * u, 0.1 * u), shape = "ellipsoid", size = V(2.5 * u, 1.55 * u, 3.0 * u), color = shellCol, role = "Accent" })
		add(rig, { name = "ShellRim", parent = sh, at = CF(0, -0.38 * u, 0), shape = "ellipsoid", size = V(2.62 * u, 0.5 * u, 3.12 * u), color = darker(shellCol, 0.72), role = "Detail" })
		add(rig, { name = "ShellPlate", parent = sh, at = CF(0, 0.62 * u, 0), shape = "ellipsoid", size = V(0.9 * u, 0.36 * u, 1.0 * u), color = shellCol:Lerp(WHITE, 0.12), role = "Detail" })
		for k = 1, 6 do
			local a = k / 6 * math.pi * 2
			add(rig, { name = "ShellPlate", parent = sh, at = CF(math.cos(a) * 0.72 * u, 0.45 * u, math.sin(a) * 0.9 * u) * ANG(math.sin(a) * rad(-18), 0, math.cos(a) * rad(22)), shape = "ellipsoid",
				size = V(0.78 * u, 0.3 * u, 0.78 * u), color = k % 2 == 0 and shellCol:Lerp(WHITE, 0.08) or darker(shellCol, 0.9), role = "Detail" })
		end
		add(rig, { name = "ShellMoss", parent = sh, at = CF(0.2 * u, 0.7 * u, -0.3 * u), shape = "ellipsoid", size = V(1.3 * u, 0.32 * u, 1.4 * u), color = Color3.fromRGB(86, 140, 58), material = "Grass", role = "Detail" })
		if kind == "tree" then
			add(rig, { name = "TreeTrunk", parent = sh, at = CF(0, 1.4 * u, 0), shape = "ellipsoid", size = V(0.42 * u, 1.7 * u, 0.42 * u), color = Color3.fromRGB(104, 74, 50), material = "Wood", role = "Detail" })
			add(rig, { name = "TreeBranch", parent = sh, at = CF(0.3 * u, 1.85 * u, 0) * ANG(0, 0, rad(-50)), shape = "ellipsoid", size = V(0.2 * u, 0.9 * u, 0.2 * u), color = Color3.fromRGB(104, 74, 50), material = "Wood", role = "Detail" })
			for k, o in ipairs({ { 0, 2.5, 0, 1.5 }, { 0.65, 2.15, 0.3, 1.05 }, { -0.6, 2.2, -0.2, 1.1 }, { 0.1, 2.1, -0.7, 0.95 }, { -0.25, 2.85, 0.3, 0.9 } }) do
				add(rig, { name = "TreeLeaves", parent = sh, at = CF(o[1] * u, o[2] * u, o[3] * u), shape = "ball", size = Vector3.one * o[4] * u,
					color = ({ Color3.fromRGB(78, 150, 58), Color3.fromRGB(104, 178, 66), Color3.fromRGB(64, 128, 52) })[k % 3 + 1], material = "Grass", role = "Detail" })
			end
		end
	elseif kind == "leaves" then
		for k = 1, 4 do
			add(rig, { name = "BackLeaf", parent = body, at = CF((k % 2 == 0 and 0.28 or -0.28) * u, 0.72 * u, (k - 2.5) * 0.48 * u * len) * ANG(rad(-28), rad(k * 50), 0), shape = "ellipsoid",
				size = V(0.5 * u, 0.08 * u, 0.82 * u), color = k % 2 == 0 and P.accent or darker(P.accent, 0.82), material = "Grass", role = "Accent" })
		end
	elseif kind == "fronds" or kind == "fins" then
		for i = -1, 1 do
			ModelKit.tri(rig, { name = "Fin", parent = body, at = CF(0, 0.62 * u, i * 0.45 * u * len) * ANG(rad(-20), rad(90), 0), width = 0.55 * u, height = (0.6 - math.abs(i) * 0.15) * u, thickness = 0.08 * u,
				color = P.accent, material = kind == "fins" and "Neon" or "Grass", role = "Accent" })
		end
	end
end

-- Asas. kind: feather, seraph, leaf, crystal, membrane, moth, cloud.
local function addWings(rig, m, u, body, kind, at, span, pose)
	if not kind then
		return
	end
	local P = palette(m)
	span = span or 1
	-- pose de repouso: asas inclinadas para trás (sweep) e para cima (diedro), como uma ave em voo planado
	local sweep, dihedral = pose and pose.sweep or 0, pose and pose.dihedral or 0
	for _, side in ipairs({ -1, 1 }) do
		local joint = side < 0 and "WingL" or "WingR"
		local w = hub(rig, joint, body, joint, at * CF(side * 0.1 * u, 0, 0) * ANG(0, -side * rad(sweep), 0) * ANG(0, 0, side * rad(dihedral)))
		local function piece(name, x, y, z, sx, sy, sz, color, material, role, yaw, transparency)
			add(rig, { name = name, parent = w, at = CF(side * x * u * span, y * u, z * u) * ANG(0, side * rad(yaw or 0), 0),
				shape = "ellipsoid", size = V(sx * u * span, sy * u, sz * u), color = color, material = material, transparency = transparency, role = role })
		end
		if kind == "feather" or kind == "seraph" then
			-- coberteiras + rêmiges em leque (cada pena é uma peça)
			piece("WingCovert", 0.62, 0.02, -0.05, 1.3, 0.16, 0.85, P.body, nil, "Body", 4)
			piece("WingCovert2", 0.95, 0, 0.12, 1.1, 0.12, 0.62, P.dorsal, nil, "Body", -6)
			local tipCol = kind == "seraph" and P.accent or P.deep:Lerp(P.accent, 0.35)
			for i = 0, 4 do
				piece("WingFeather", 1.25 + i * 0.1, -0.02 - i * 0.01, 0.08 + i * 0.16, 1.5 - i * 0.12, 0.06, 0.3, i % 2 == 0 and P.belly:Lerp(P.body, 0.3) or P.body, nil, "Belly", -8 - i * 9)
			end
			piece("WingTip", 1.95, -0.03, 0.2, 0.75, 0.065, 0.32, tipCol, kind == "seraph" and "Neon" or nil, "Accent", -18)
			if kind == "seraph" then
				piece("WingUpper", 1.15, 0.05, -0.42, 1.5, 0.08, 0.42, P.belly, nil, "Belly", 20)
			end
		elseif kind == "leaf" then
			piece("WingLeaf", 0.95, 0, 0, 1.9, 0.08, 0.85, P.accent, "Grass", "Accent", 0)
			piece("WingLeaf2", 0.8, -0.02, 0.38, 1.4, 0.07, 0.6, darker(P.accent, 0.82), "Grass", "Accent", -22)
			piece("WingVein", 0.95, 0.045, 0, 1.7, 0.02, 0.06, P.accent:Lerp(WHITE, 0.4), nil, "Accent", 0)
		elseif kind == "crystal" then
			for i = 0, 2 do
				ModelKit.tri(rig, { name = "WingShard", parent = w, at = CF(side * (0.55 + i * 0.5) * u * span, 0.1 * u * i, 0.15 * u * i) * ANG(0, 0, side * rad(-75 + i * 10)) * ANG(rad(90), 0, 0),
					width = 0.75 * u, height = (1.35 - i * 0.25) * u * span, thickness = 0.1 * u, color = P.accent, material = "Glass", transparency = 0.12, role = "Accent" })
			end
		elseif kind == "membrane" then
			-- braço da asa + "dedos" + membrana triangular
			piece("WingArm", 0.85, 0, -0.25, 1.75, 0.18, 0.18, P.dorsal, nil, "Body", 6)
			piece("WingFinger", 1.25, 0, 0.25, 1.2, 0.1, 0.1, P.dorsal, nil, "Body", -48)
			piece("WingFinger", 1.6, 0, 0.05, 1.0, 0.1, 0.1, P.dorsal, nil, "Body", -24)
			for i = 0, 1 do
				local x0 = (0.15 + i * 0.8) * u * span
				ModelKit.tri(rig, { name = "WingSkin", parent = w, at = CF(side * (x0 + 0.4 * u * span), 0, -0.2 * u) * ANG(rad(90), 0, 0) * ANG(0, 0, rad(180)),
					width = 0.9 * u * span, height = (0.95 - i * 0.2) * u, thickness = 0.06 * u, color = P.belly, transparency = 0.08, role = "Belly" })
			end
			piece("WingClaw", 1.72, 0.02, -0.28, 0.2, 0.16, 0.2, P.claw, nil, "Detail", 0)
		elseif kind == "moth" then
			piece("WingFore", 1.0, 0, -0.2, 2.0, 0.07, 1.3, P.body, nil, "Body", 10)
			piece("WingHind", 0.8, -0.02, 0.6, 1.4, 0.06, 0.9, P.belly, nil, "Belly", -15)
			piece("WingEye", 1.1, 0.04, -0.2, 0.55, 0.03, 0.55, P.accent, "Neon", "Accent", 0)
			piece("WingEyeRing", 1.1, 0.03, -0.2, 0.78, 0.03, 0.78, P.deep, nil, "Body", 0)
		elseif kind == "cloud" then
			piece("WingPuff", 0.8, 0, 0, 1.2, 0.5, 0.9, P.belly, nil, "Belly", 0)
			piece("WingPuff2", 1.35, 0.05, 0.15, 0.8, 0.4, 0.65, P.belly:Lerp(WHITE, 0.25), nil, "Belly", -10)
		end
	end
end

local function addHalo(rig, P, u, hd, y)
	ModelKit.ring(rig, hd, "OrbitHalo", CF(0, y * u, 0.1 * u), 0.55 * u, 10, Vector3.one * 0.14 * u, P.accent, "Neon", "Glow")
end

local function addOrbit(rig, P, u, core, kind)
	if not kind then
		return
	end
	local h = hub(rig, "Orbit", core, "Orbit", CF())
	local count = (kind == "planets") and 3 or 5
	for i = 1, count do
		local a = i / count * math.pi * 2
		local pos = CF(math.cos(a) * 1.35 * u, math.sin(a * 2) * 0.25 * u, math.sin(a) * 1.35 * u)
		if kind == "leaves" then
			add(rig, { name = "OrbitLeaf", parent = h, at = pos * ANG(0, -a, rad(30)), shape = "ellipsoid", size = V(0.45 * u, 0.08 * u, 0.25 * u), color = P.accent, material = "Grass", role = "Accent" })
		elseif kind == "shards" then
			add(rig, { name = "OrbitShard", parent = h, at = pos * ANG(rad(20), a, 0), shape = "wedge", size = V(0.15 * u, 0.45 * u, 0.25 * u), color = P.accent, material = "Glass", role = "Accent" })
		elseif kind == "puffs" then
			add(rig, { name = "OrbitPuff", parent = h, at = pos, shape = "ball", size = Vector3.one * 0.4 * u, color = P.accent, role = "Accent" })
		elseif kind == "wisps" then
			add(rig, { name = "OrbitWisp", parent = h, at = pos, shape = "ball", size = Vector3.one * 0.22 * u, color = P.accent, material = "Neon", transparency = 0.2, role = "Glow", shadow = false })
		elseif kind == "stars" then
			add(rig, { name = "OrbitStar", parent = h, at = pos * ANG(0, 0, rad(45)), shape = "block", size = Vector3.one * 0.2 * u, color = P.accent, material = "Neon", role = "Glow", shadow = false })
		elseif kind == "planets" then
			add(rig, { name = "OrbitPlanet", parent = h, at = pos, shape = "ball", size = Vector3.one * (0.35 + i * 0.08) * u, color = i == 2 and P.accent or darker(P.accent, 0.7),
				material = i == 2 and "Neon" or "SmoothPlastic", role = "Accent" })
		end
	end
end

-- Perna de quadrúpede: coxa, canela, pata e três dedos. Retorna nada; a junta fica no quadril/ombro.
local function quadLeg(rig, P, u, body, joint, at, legH, thick, pawColor, hind)
	local l = hub(rig, joint, body, joint, at)
	add(rig, { name = "Thigh", parent = l, at = CF(0, -legH * 0.22, hind and 0.05 * u or 0), shape = "ellipsoid", size = V(thick * 1.1, legH * 0.72, thick * (hind and 1.35 or 1.15)), color = P.body, role = "Body" })
	-- canela cilíndrica: as pontas ficam escondidas dentro da coxa e da pata (perna lisa, sem "gomos")
	add(rig, { name = "Shin", parent = l, at = CF(0, -legH * 0.6, hind and 0.05 * u or -0.02 * u) * ANG(0, 0, rad(90)), shape = "cyl", size = V(legH * 0.62, thick * 0.66, thick * 0.66), color = P.body, role = "Body" })
	local pawY = -legH * 0.92
	add(rig, { name = "Paw", parent = l, at = CF(0, pawY, -0.1 * u), shape = "ellipsoid", size = V(thick * 0.95, 0.3 * u, thick * 1.25), color = pawColor, role = "Belly" })
	for i = -1, 1 do
		add(rig, { name = "Toe", parent = l, at = CF(i * thick * 0.27, pawY - 0.03 * u, -0.1 * u - thick * 0.52), shape = "ball", size = Vector3.one * thick * 0.34, color = pawColor:Lerp(WHITE, 0.06),
			role = "Belly", shadow = false })
	end
	return pawY - 0.15 * u
end

-------------------------------------------------------------------------------
-- Arquétipos
-------------------------------------------------------------------------------

local function buildQuad(rig, m, P, u)
	local st = m.stocky and 1.15 or 1
	local L = m.long or 1 -- comprimento do corpo
	local legH = 1.05 * u * (m.legs or 1)
	local neckUp = m.neck or 0
	local body = furVolume(rig, P, { name = "Torso", joint = "Body", at = CF(), size = V(1.62 * u * st, 1.45 * u, 2.55 * u * L) })
	-- ancas discretas e "babador" claro no peito
	add(rig, { name = "Bib", parent = body, at = CF(0, -0.1 * u, -1.16 * u * L), shape = "ellipsoid", size = V(0.98 * st, 1.1, 0.62) * u, color = P.bib, role = "Belly" })
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "Haunch", parent = body, at = CF(side * 0.48 * u * st, 0.02 * u, 0.82 * u * L), shape = "ellipsoid", size = V(0.62, 1.12, 1.05) * u, color = P.body, role = "Body" })
	end
	-- pescoço
	add(rig, { name = "Neck", parent = body, at = CF(0, (0.42 + neckUp * 0.5) * u, -(1.22 * L + neckUp * 0.12) * u) * ANG(rad(32), 0, 0), shape = "ellipsoid",
		size = V(1.0, 1.3 + neckUp, 1.05) * u, color = P.body, role = "Body" })
	add(rig, { name = "Throat", parent = body, at = CF(0, (0.18 + neckUp * 0.45) * u, -(1.45 * L + neckUp * 0.18) * u) * ANG(rad(32), 0, 0), shape = "ellipsoid",
		size = V(0.72, 1.0 + neckUp * 0.8, 0.55) * u, color = P.bib, role = "Belly" })
	local hs = V(1.72, 1.56, 1.62) * u
	local fluffy = m.ears == "pointy" or m.ears == "tufted"
	local hd = mammalHead(rig, m, P, u, body, CF(0, (0.82 + neckUp) * u, -(1.5 * L + neckUp * 0.25) * u), hs,
		{ ruff = fluffy, slit = m.glowEyes })
	addEars(rig, m, P, u, hd, hs, m.ears)
	addHorns(rig, m, P, u, hd, hs, m.horns)
	if m.crest then
		ModelKit.tri(rig, { name = "Crest", parent = hd, at = CF(0, hs.Y * 0.42, 0.1 * u) * ANG(rad(-18), rad(90), 0), width = 0.62 * u, height = 0.55 * u, thickness = 0.12 * u, color = P.accent, role = "Accent" })
	end
	if m.halo then
		addHalo(rig, P, u, hd, m.horns == "grand" and 2.6 or 1.35)
	end
	local thick = (m.legs and m.legs > 1.2 and 0.44 or 0.52) * u * (m.stocky and 1.15 or 1)
	local ground = 0
	for _, leg in ipairs({ { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } }) do
		ground = -0.36 * u + quadLeg(rig, P, u, body, leg[1], CF(leg[2] * 0.5 * u * st, -0.36 * u, leg[3] * 0.86 * u * L), legH, thick, m.paw or P.soft, leg[3] > 0)
	end
	addTail(rig, m, P, u, body, CF(0, 0.32 * u, 1.38 * u * L), m.tail)
	addBack(rig, m, P, u, body, m.back, L)
	if m.wings then
		addWings(rig, m, u, body, m.wings, CF(0, 0.55 * u, -0.25 * u), m.wingSpan or 0.9, { sweep = 35, dihedral = 30 })
	end
	return -ground -- altura do centro do root acima do chão (patas tocando o chão)
end

local function buildBiped(rig, m, P, u)
	local body = furVolume(rig, P, { name = "Torso", joint = "Body", at = CF(), size = V(1.65, 2.0, 1.45) * u })
	add(rig, { name = "Belly", parent = body, at = CF(0, -0.22 * u, -0.32 * u), shape = "ellipsoid", size = V(1.15, 1.35, 0.9) * u, color = P.bib, role = "Belly" })
	local hs = V(1.62, 1.5, 1.5) * u
	local hd = mammalHead(rig, m, P, u, body, CF(0, 1.5 * u, -0.08 * u), hs, { snout = m.snout ~= nil, eyeY = 0.1, eyeD = hs.X * 0.25 })
	addEars(rig, m, P, u, hd, hs, m.ears)
	addHorns(rig, m, P, u, hd, hs, m.horns)
	for _, side in ipairs({ -1, 1 }) do
		local a = hub(rig, side < 0 and "ArmL" or "ArmR", body, side < 0 and "ArmL" or "ArmR", CF(side * 0.86 * u, 0.48 * u, 0))
		add(rig, { name = "UpperArm", parent = a, at = CF(side * 0.12 * u, -0.32 * u, 0), shape = "ellipsoid", size = V(0.5, 0.82, 0.5) * u, color = P.body, role = "Body" })
		add(rig, { name = "Forearm", parent = a, at = CF(side * 0.2 * u, -0.85 * u, -0.06 * u), shape = "ellipsoid", size = V(0.42, 0.72, 0.42) * u, color = P.body:Lerp(P.deep, 0.2), role = "Body" })
		local hand = add(rig, { name = "Hand", parent = a, at = CF(side * 0.22 * u, -1.22 * u, -0.08 * u), shape = "ellipsoid", size = V(0.46, 0.4, 0.46) * u, color = P.accent, role = "Accent" })
		for i = -1, 1 do
			add(rig, { name = "Finger", parent = hand, at = CF(i * 0.12 * u, -0.17 * u, -0.12 * u), shape = "ball", size = Vector3.one * 0.15 * u, color = P.accent:Lerp(WHITE, 0.05), role = "Accent", shadow = false })
		end
		local l = hub(rig, side < 0 and "LegL" or "LegR", body, side < 0 and "LegL" or "LegR", CF(side * 0.45 * u, -0.8 * u, 0))
		add(rig, { name = "Thigh", parent = l, at = CF(0, -0.28 * u, 0), shape = "ellipsoid", size = V(0.66, 0.8, 0.7) * u, color = P.body, role = "Body" })
		add(rig, { name = "Shin", parent = l, at = CF(0, -0.72 * u, 0), shape = "ellipsoid", size = V(0.5, 0.6, 0.52) * u, color = P.body:Lerp(P.deep, 0.2), role = "Body" })
		add(rig, { name = "Foot", parent = l, at = CF(0, -0.98 * u, -0.14 * u), shape = "ellipsoid", size = V(0.62, 0.3, 0.88) * u, color = P.soft, role = "Belly" })
		for i = -1, 1 do
			add(rig, { name = "Toe", parent = l, at = CF(i * 0.17 * u, -1.0 * u, -0.56 * u), shape = "ball", size = Vector3.one * 0.2 * u, color = P.soft, role = "Belly", shadow = false })
		end
	end
	addBack(rig, m, P, u, body, m.back, 0.6)
	return 0.8 * u + 1.13 * u
end

local function buildFlyer(rig, m, P, u)
	local body = furVolume(rig, P, { name = "Torso", joint = "Body", at = CF(), size = V(1.35, 1.3, 1.95) * u })
	add(rig, { name = "Breast", parent = body, at = CF(0, -0.12 * u, -0.55 * u), shape = "ellipsoid", size = V(1.12, 1.1, 1.05) * u, color = P.bib, role = "Belly" })
	local hs = V(1.28, 1.22, 1.24) * u
	local hd = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 0.78 * u, -0.98 * u), shape = "ellipsoid", size = hs, color = P.body, role = "Body" })
	add(rig, { name = "Brow", parent = hd, at = CF(0, hs.Y * 0.1, hs.Z * 0.04), shape = "ellipsoid", size = V(hs.X * 0.84, hs.Y * 0.84, hs.Z * 0.9), color = P.dorsal, role = "Body" })
	add(rig, { name = "FaceMask", parent = hd, at = CF(0, -hs.Y * 0.12, -hs.Z * 0.12), shape = "ellipsoid", size = V(hs.X * 0.8, hs.Y * 0.62, hs.Z * 0.82), color = P.soft, role = "Body" })
	eyes(rig, m, P, hd, hs, 0.46, 0.12, hs.X * 0.27, { tilt = -6 })
	if m.drake then
		add(rig, { name = "Snout", parent = hd, at = CF(0, -0.14 * u, -0.72 * u), shape = "ellipsoid", size = V(0.68, 0.48, 0.82) * u, color = P.body, role = "Body" })
		for _, side in ipairs({ -1, 1 }) do
			add(rig, { name = "Nostril", parent = hd, at = CF(side * 0.12 * u, -0.06 * u, -1.1 * u), shape = "ball", size = Vector3.one * 0.08 * u, color = P.rim, role = "Detail", shadow = false })
		end
		add(rig, { name = "Jaw", parent = hd, joint = "Jaw", at = CF(0, -0.36 * u, -0.66 * u), shape = "ellipsoid", size = V(0.58, 0.24, 0.72) * u, color = P.belly, role = "Belly" })
	else
		local bc = P.accent:Lerp(Color3.fromRGB(232, 168, 64), 0.55)
		add(rig, { name = "Beak", parent = hd, at = CF(0, -0.06 * u, -0.74 * u) * ANG(0, rad(180), 0), shape = "wedge", size = V(0.34, 0.24, 0.52) * u, color = bc, role = "Detail" })
		add(rig, { name = "BeakLow", parent = hd, at = CF(0, -0.2 * u, -0.7 * u) * ANG(0, 0, rad(180)) * ANG(0, rad(180), 0), shape = "wedge", size = V(0.3, 0.12, 0.42) * u, color = darker(bc, 0.82), role = "Detail" })
		add(rig, { name = "Cere", parent = hd, at = CF(0, -0.08 * u, -0.56 * u), shape = "ellipsoid", size = V(0.36, 0.28, 0.18) * u, color = darker(bc, 0.92), role = "Detail" })
	end
	addEars(rig, m, P, u, hd, hs, m.ears)
	addHorns(rig, m, P, u, hd, hs, m.horns)
	if m.crest then
		for i = -1, 1 do
			add(rig, { name = "Crest", parent = hd, at = CF(i * 0.08 * u, 0.58 * u, (0.1 + math.abs(i) * 0.05) * u) * ANG(rad(-30), rad(i * 12), 0) * CF(0, 0.2 * u, 0), shape = "ellipsoid",
				size = V(0.12, 0.6 - math.abs(i) * 0.15, 0.22) * u, color = i == 0 and P.accent or P.accent:Lerp(P.body, 0.3), role = "Accent" })
		end
	end
	if m.halo then
		addHalo(rig, P, u, hd, 1.05)
	end
	addWings(rig, m, u, body, m.wings or "feather", CF(0, 0.35 * u, -0.1 * u), 1, { sweep = 28, dihedral = 18 })
	addTail(rig, m, P, u, body, CF(0, 0.15 * u, 0.95 * u), m.tail or "feather")
	for _, side in ipairs({ -1, 1 }) do
		local legCol = Color3.fromRGB(200, 150, 70):Lerp(P.accent, 0.3)
		add(rig, { name = "Tarsus", parent = body, at = CF(side * 0.3 * u, -0.72 * u, 0.12 * u), shape = "ellipsoid", size = V(0.12, 0.42, 0.12) * u, color = legCol, role = "Detail" })
		for i = -1, 1 do
			add(rig, { name = "Talon", parent = body, at = CF(side * 0.3 * u + i * 0.09 * u, -0.92 * u, 0.0 * u) * ANG(0, rad(i * 25), 0) * CF(0, 0, -0.1 * u), shape = "ellipsoid",
				size = V(0.07, 0.07, 0.26) * u, color = legCol, role = "Detail", shadow = false })
		end
	end
	return 2.2 * u -- voa: altura de flutuação
end

local function buildSerpent(rig, m, P, u)
	local body = furVolume(rig, P, { name = "Torso", joint = "Body", at = CF(), size = V(1.1, 1.0, 1.45) * u })
	local hs = V(1.2, 1.0, 1.5) * u
	local hd = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 0.9 * u, -0.8 * u) * ANG(rad(-10), 0, 0), shape = "ellipsoid", size = hs, color = P.body, role = "Body" })
	add(rig, { name = "Brow", parent = hd, at = CF(0, hs.Y * 0.12, 0), shape = "ellipsoid", size = V(hs.X * 0.82, hs.Y * 0.84, hs.Z * 0.92), color = P.dorsal, role = "Body" })
	add(rig, { name = "Snout", parent = hd, at = CF(0, -0.05 * u, -0.62 * u), shape = "ellipsoid", size = V(0.8, 0.55, 0.7) * u, color = P.body, role = "Body" })
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "Nostril", parent = hd, at = CF(side * 0.13 * u, 0.08 * u, -0.95 * u), shape = "ball", size = Vector3.one * 0.07 * u, color = P.rim, role = "Detail", shadow = false })
		add(rig, { name = "BrowScale", parent = hd, at = CF(side * 0.36 * u, 0.36 * u, -0.25 * u) * ANG(rad(-10), 0, side * rad(-14)), shape = "ellipsoid", size = V(0.42, 0.16, 0.5) * u, color = P.dorsal, role = "Body" })
	end
	eyes(rig, m, P, hd, hs, 0.55, 0.18, hs.X * 0.24, { slit = true, tilt = -10, lidColor = P.dorsal })
	add(rig, { name = "Jaw", parent = hd, joint = "Jaw", at = CF(0, -0.34 * u, -0.22 * u), shape = "ellipsoid", size = V(0.98, 0.34, 1.12) * u, color = P.belly, role = "Belly" })
	if m.halo then
		addHalo(rig, P, u, hd, 1.0)
	end
	local prev = body
	for i = 1, 5 do
		local s = 1 - i * 0.12
		prev = add(rig, { name = "Seg" .. i, parent = prev, joint = "Seg" .. i, at = CF(0, -0.05 * u, 0.95 * u * s), shape = "ellipsoid",
			size = V(1.05 * s, 0.95 * s, 1.4 * s) * u, color = i % 2 == 0 and P.dorsal or P.body, role = "Body" })
		add(rig, { name = "SegBelly", parent = prev, at = CF(0, -0.28 * u * s, 0), shape = "ellipsoid", size = V(0.78 * s, 0.42 * s, 1.15 * s) * u, color = P.belly, role = "Belly" })
		add(rig, { name = "SegSpot", parent = prev, at = CF(0, 0.38 * u * s, 0), shape = "ellipsoid", size = V(0.45 * s, 0.22 * s, 0.6 * s) * u, color = P.accent:Lerp(P.dorsal, 0.45), role = "Accent" })
		if m.back and i <= 4 then
			ModelKit.tri(rig, { name = "SegFin", parent = prev, at = CF(0, 0.36 * u * s, 0) * ANG(rad(-25), rad(90), 0), width = 0.6 * u * s, height = 0.5 * u * s, thickness = 0.07 * u,
				color = P.accent, material = m.back == "fins" and "Neon" or "Grass", role = "Accent" })
		end
	end
	if m.tail == "flame" then
		add(rig, { name = "TailFlame", parent = prev, at = CF(0, 0, 0.75 * u), shape = "ellipsoid", size = V(0.5, 0.5, 1.2) * u, color = P.accent, material = "Neon", transparency = 0.1, role = "Glow", shadow = false })
	else
		add(rig, { name = "TailTip", parent = prev, at = CF(0, 0, 0.7 * u), shape = "ellipsoid", size = V(0.4, 0.36, 0.9) * u, color = P.dorsal, role = "Body" })
	end
	return 0.55 * u
end

local function buildFloater(rig, m, P, u)
	local core = add(rig, { name = "Torso", joint = "Body", at = CF(), shape = "ball", size = Vector3.one * 1.7 * u, color = P.body, role = "Body", transparency = 0.06 })
	add(rig, { name = "Shell", parent = core, at = CF(0, 0.12 * u, 0.04 * u), shape = "ellipsoid", size = V(1.5, 1.5, 1.6) * u, color = P.dorsal, role = "Body", transparency = 0.1 })
	add(rig, { name = "Glow", parent = core, at = CF(0, -0.1 * u, 0), shape = "ball", size = Vector3.one * 1.15 * u, color = P.belly, material = "Neon", transparency = 0.45, role = "Glow", shadow = false })
	local hs = Vector3.one * 1.7 * u
	local hd = hub(rig, "Head", core, "Neck", CF())
	eyes(rig, m, P, hd, hs, 0.36, 0.12, 0.36 * u, { lidColor = P.body })
	add(rig, { name = "Mouth", parent = hd, at = ModelKit.surface(hs, 0, -0.22, 0), shape = "ellipsoid", size = V(0.22, 0.08, 0.06) * u, color = P.rim, role = "Detail", shadow = false })
	local tail = add(rig, { name = "Tail", parent = core, joint = "Tail", at = CF(0, -0.72 * u, 0.25 * u) * ANG(rad(25), 0, 0), shape = "ellipsoid", size = V(0.9, 1.2, 0.9) * u, color = P.body, transparency = 0.15, role = "Body" })
	local w2 = add(rig, { name = "TailWisp", parent = tail, joint = "TailSeg2", at = CF(0, -0.68 * u, 0.15 * u) * ANG(rad(15), 0, 0), shape = "ellipsoid", size = V(0.5, 0.85, 0.5) * u, color = P.accent, transparency = 0.25, role = "Accent" })
	add(rig, { name = "TailWisp", parent = w2, joint = "TailSeg3", at = CF(0, -0.55 * u, 0.1 * u), shape = "ellipsoid", size = V(0.26, 0.55, 0.26) * u, color = P.accent:Lerp(WHITE, 0.3), material = "Neon", transparency = 0.35, role = "Glow", shadow = false })
	addOrbit(rig, P, u, core, m.orbit)
	if m.halo then
		addHalo(rig, P, u, hd, 1.15)
	end
	return 2.0 * u
end

local function buildGolem(rig, m, P, u)
	local function rock(name, parent, joint, at, size, color, role)
		-- bloco de pedra com arestas chanfradas (bloco interno + "almofadas" elipsoides)
		local p = add(rig, { name = name, parent = parent, joint = joint, at = at, shape = "block", size = size * V(0.86, 0.86, 0.86), color = color, material = "Slate", role = role or "Body" })
		add(rig, { name = name .. "Bevel", parent = p, at = CF(), shape = "ellipsoid", size = size * 1.08, color = darker(color, 0.94), material = "Slate", role = role or "Body" })
		return p
	end
	local body = rock("Torso", nil, "Body", CF(), V(2.0, 1.9, 1.5) * u, P.body)
	add(rig, { name = "CoreRing", parent = body, at = CF(0, 0.1 * u, -0.74 * u), shape = "ellipsoid", size = V(0.82, 0.82, 0.2) * u, color = darker(P.body, 0.6), material = "Slate", role = "Detail" })
	add(rig, { name = "Core", parent = body, at = CF(0, 0.1 * u, -0.8 * u), shape = "ball", size = Vector3.one * 0.55 * u, color = P.accent, material = "Neon", role = "Glow" })
	for i = 1, 3 do
		add(rig, { name = "Crack", parent = body, at = CF((i - 2) * 0.55 * u, -0.45 * u + i * 0.1 * u, -0.79 * u) * ANG(0, 0, rad(i * 40 - 80)), shape = "block", size = V(0.05, 0.45, 0.04) * u,
			color = P.accent, material = "Neon", role = "Glow", shadow = false })
	end
	local hd = rock("Head", body, "Neck", CF(0, 1.3 * u, -0.1 * u), V(1.2, 0.9, 1.1) * u, P.body)
	add(rig, { name = "BrowRock", parent = hd, at = CF(0, 0.3 * u, -0.5 * u), shape = "block", size = V(1.1, 0.22, 0.25) * u, color = darker(P.body, 0.8), material = "Slate", role = "Body" })
	add(rig, { name = "Visor", parent = hd, at = CF(0, 0.05 * u, -0.55 * u), shape = "block", size = V(0.85, 0.18, 0.05) * u, color = m.eye or P.accent, material = "Neon", role = "Eye" })
	for _, side in ipairs({ -1, 1 }) do
		local a = hub(rig, side < 0 and "ArmL" or "ArmR", body, side < 0 and "ArmL" or "ArmR", CF(side * 1.35 * u, 0.5 * u, 0))
		rock("Shoulder", a, nil, CF(0, 0.1 * u, 0), V(0.9, 0.72, 0.9) * u, darker(P.body, 0.88))
		rock("Arm", a, nil, CF(side * 0.05 * u, -0.7 * u, 0), V(0.62, 1.0, 0.62) * u, P.body)
		rock("Fist", a, nil, CF(side * 0.05 * u, -1.35 * u, 0), V(0.86, 0.7, 0.86) * u, P.belly, "Belly")
		local l = hub(rig, side < 0 and "LegL" or "LegR", body, side < 0 and "LegL" or "LegR", CF(side * 0.55 * u, -0.95 * u, 0))
		rock("Leg", l, nil, CF(0, -0.4 * u, 0), V(0.76, 0.86, 0.82) * u, P.belly, "Belly")
	end
	addBack(rig, m, P, u, body, m.back, 0.5)
	addOrbit(rig, P, u, body, m.orbit)
	return 0.95 * u + 0.86 * u
end

-- Slime: gota gelatinosa translúcida, núcleo, bolhas, reflexo e base achatada.
local function buildSlime(rig, m, P, u)
	local bs = V(2.2, 1.7, 2.2) * u
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(), shape = "ellipsoid", size = bs, color = P.body, material = m.glassy and "Glass" or "SmoothPlastic",
		transparency = 0.18, reflectance = 0.08, role = "Body" })
	add(rig, { name = "Base", parent = body, at = CF(0, -0.55 * u, 0), shape = "ellipsoid", size = V(2.5, 0.55, 2.5) * u, color = darker(P.body, 0.9), transparency = 0.15, role = "Body" })
	add(rig, { name = "Core", parent = body, at = CF(0, -0.12 * u, 0.1 * u), shape = "ellipsoid", size = V(1.35, 1.0, 1.35) * u, color = P.belly, transparency = 0.3, role = "Belly", shadow = false })
	for i, o in ipairs({ { 0.5, -0.1, 0.3, 0.26 }, { -0.4, 0.2, 0.45, 0.18 }, { 0.2, 0.35, 0.55, 0.14 } }) do
		add(rig, { name = "Bubble", parent = body, at = CF(o[1] * u, o[2] * u, o[3] * u), shape = "ball", size = Vector3.one * o[4] * u, color = P.belly:Lerp(WHITE, 0.5), transparency = 0.35 + i * 0.05, role = "Belly", shadow = false })
	end
	add(rig, { name = "Shine", parent = body, at = ModelKit.surface(bs, -0.42, 0.55, -0.02 * u) * ANG(0, 0, rad(25)), shape = "ellipsoid", size = V(0.55, 0.26, 0.08) * u, color = WHITE, material = "Neon", transparency = 0.35, role = "Detail", shadow = false })
	add(rig, { name = "Shine", parent = body, at = ModelKit.surface(bs, -0.62, 0.25, -0.02 * u), shape = "ellipsoid", size = V(0.16, 0.16, 0.06) * u, color = WHITE, material = "Neon", transparency = 0.35, role = "Detail", shadow = false })
	local hd = hub(rig, "Head", body, "Neck", CF())
	eyes(rig, m, P, hd, bs, 0.3, 0.06, 0.4 * u, { lidColor = P.body:Lerp(P.dorsal, 0.4) })
	add(rig, { name = "Smile", parent = hd, at = ModelKit.surface(bs, 0, -0.18, -0.01 * u), shape = "ellipsoid", size = V(0.3, 0.1, 0.06) * u, color = P.rim, role = "Detail", shadow = false })
	local top = m.top
	if top == "sprout" then
		add(rig, { name = "Stem", parent = body, at = CF(0, 0.92 * u, 0), shape = "ellipsoid", size = V(0.1, 0.42, 0.1) * u, color = darker(P.accent, 0.8), role = "Accent" })
		for _, side in ipairs({ -1, 1 }) do
			add(rig, { name = "Sprout", parent = body, joint = side < 0 and "EarL" or "EarR", at = CF(side * 0.26 * u, 1.14 * u, 0) * ANG(0, 0, side * rad(-55)),
				shape = "ellipsoid", size = V(0.3, 0.68, 0.08) * u, color = P.accent, material = "Grass", role = "Accent" })
		end
	elseif top == "crystal" then
		for k = -1, 1 do
			ModelKit.tri(rig, { name = "TopCrystal", parent = body, at = CF(k * 0.32 * u, 0.7 * u, 0) * ANG(0, 0, rad(-k * 20)), width = 0.36 * u, height = (0.85 - math.abs(k) * 0.25) * u, thickness = 0.28 * u,
				color = P.accent, material = "Glass", role = "Accent" })
		end
	elseif top == "crown" then
		ModelKit.ring(rig, body, nil, CF(0, 0.9 * u, 0), 0.4 * u, 5, Vector3.one * 0.22 * u, P.accent, "Neon", "Glow", "block")
	end
	return 0.85 * u
end

-- Cogumelo: caule com rostinho, chapéu com borda, lamelas por baixo e pintas em relevo.
local function buildShroom(rig, m, P, u)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(), shape = "ellipsoid", size = V(1.3, 1.6, 1.3) * u, color = P.belly, role = "Belly" })
	add(rig, { name = "StemBase", parent = body, at = CF(0, -0.5 * u, 0), shape = "ellipsoid", size = V(1.45, 0.7, 1.45) * u, color = darker(P.belly, 0.92), role = "Belly" })
	add(rig, { name = "Ring", parent = body, at = CF(0, 0.42 * u, 0), shape = "ellipsoid", size = V(1.42, 0.2, 1.42) * u, color = P.belly:Lerp(WHITE, 0.2), role = "Belly" })
	local hd = add(rig, { name = "Head", parent = body, joint = "Neck", at = CF(0, 0.98 * u, 0), shape = "ellipsoid", size = V(2.65, 1.3, 2.65) * u, color = P.body, role = "Body" })
	add(rig, { name = "CapTop", parent = hd, at = CF(0, 0.16 * u, 0), shape = "ellipsoid", size = V(2.2, 1.05, 2.2) * u, color = P.body:Lerp(WHITE, 0.1), role = "Body" })
	add(rig, { name = "Gills", parent = hd, at = CF(0, -0.33 * u, 0), shape = "ellipsoid", size = V(2.45, 0.42, 2.45) * u, color = darker(P.belly, 0.78), role = "Detail" })
	for k = 1, 6 do
		local a = k * 1.15
		local r = k % 2 == 0 and 0.55 or 0.85
		add(rig, { name = "CapSpot", parent = hd, at = CF(math.cos(a) * r * u, (k % 2 == 0 and 0.62 or 0.45) * u, math.sin(a) * r * u), shape = "ellipsoid", size = V(0.36, 0.14, 0.36) * u * (k % 2 == 0 and 0.8 or 1),
			color = P.accent, material = m.glowSpots and "Neon" or "SmoothPlastic", role = "Accent" })
	end
	local fs = V(1.3, 1.6, 1.3) * u
	local face = hub(rig, "Face", body, nil, CF())
	eyes(rig, m, P, face, fs, 0.36, 0.08, 0.3 * u, { lidColor = P.belly:Lerp(P.dorsal, 0.2) })
	add(rig, { name = "Mouth", parent = face, at = ModelKit.surface(fs, 0, -0.14, 0), shape = "ellipsoid", size = V(0.18, 0.06, 0.05) * u, color = P.rim, role = "Detail", shadow = false })
	for _, side in ipairs({ -1, 1 }) do
		add(rig, { name = "Blush", parent = face, at = ModelKit.surface(fs, side * 0.55, -0.1, -0.01 * u), shape = "ellipsoid", size = V(0.24, 0.12, 0.04) * u, color = Color3.fromRGB(240, 150, 150), transparency = 0.35, role = "Detail", shadow = false })
		local l = hub(rig, side < 0 and "LegL" or "LegR", body, side < 0 and "LegL" or "LegR", CF(side * 0.35 * u, -0.7 * u, 0))
		add(rig, { name = "Foot", parent = l, at = CF(0, -0.25 * u, -0.08 * u), shape = "ellipsoid", size = V(0.45, 0.35, 0.6) * u, color = darker(P.belly, 0.85), role = "Belly" })
		local a = hub(rig, side < 0 and "ArmL" or "ArmR", body, side < 0 and "ArmL" or "ArmR", CF(side * 0.62 * u, 0, 0))
		add(rig, { name = "Arm", parent = a, at = CF(side * 0.12 * u, -0.25 * u, 0), shape = "ellipsoid", size = V(0.3, 0.6, 0.3) * u, color = P.belly, role = "Belly" })
	end
	return 1.2 * u
end

-- Ent/árvore viva: tronco com sulcos, rosto, braços de galho, raízes e copa em vários tons.
local function buildTreant(rig, m, P, u)
	local body = add(rig, { name = "Torso", joint = "Body", at = CF(), shape = "ellipsoid", size = V(1.6, 2.5, 1.4) * u, color = P.body, material = "Wood", role = "Body" })
	for i = -1, 1 do
		add(rig, { name = "BarkRidge", parent = body, at = CF(i * 0.42 * u, -0.1 * u, -0.6 * u + math.abs(i) * 0.12 * u) * ANG(0, rad(i * 25), 0), shape = "ellipsoid", size = V(0.2, 2.1, 0.22) * u,
			color = darker(P.body, 0.72), material = "Wood", role = "Body" })
	end
	add(rig, { name = "MossPatch", parent = body, at = CF(0.4 * u, 0.6 * u, -0.45 * u), shape = "ellipsoid", size = V(0.6, 0.4, 0.3) * u, color = Color3.fromRGB(96, 150, 62), material = "Grass", role = "Detail" })
	local hd = hub(rig, "Head", body, "Neck", CF(0, 1.5 * u, 0))
	local fs = V(1.6, 2.5, 1.4) * u
	local faceAt = CF(0, -1.5 * u, 0)
	for _, side in ipairs({ -1, 1 }) do
		local at = faceAt * ModelKit.surface(fs, side * 0.3, 0.26, -0.08 * u)
		ModelKit.detailedEye(rig, hd, at, 0.32 * u, side, { glow = true, iris = m.eye or P.accent, rim = darker(P.body, 0.35), lid = darker(P.body, 0.8), lidTilt = -14 })
	end
	add(rig, { name = "Mouth", parent = hd, at = faceAt * ModelKit.surface(fs, 0, 0.02, -0.02 * u), shape = "ellipsoid", size = V(0.4, 0.12, 0.08) * u, color = darker(P.body, 0.3), role = "Detail", shadow = false })
	local tones = { P.accent, darker(P.accent, 0.82), P.accent:Lerp(WHITE, 0.12), darker(P.accent, 0.7) }
	for k, o in ipairs({ { 0, 0.8, 0, 2.2 }, { 0.9, 0.4, 0.2, 1.5 }, { -0.9, 0.45, -0.1, 1.6 }, { 0.2, 0.5, 0.8, 1.4 }, { -0.2, 1.35, -0.3, 1.3 }, { 0.5, 1.1, -0.5, 1.0 } }) do
		add(rig, { name = "Canopy", parent = hd, at = CF(o[1] * u, o[2] * u, o[3] * u), shape = "ball", size = Vector3.one * o[4] * u,
			color = tones[(k - 1) % #tones + 1], material = m.glowCanopy and "Neon" or "Grass", transparency = m.glowCanopy and 0.25 or 0, role = "Accent" })
	end
	if m.blossoms then
		for k = 1, 5 do
			local a = k * 1.3
			add(rig, { name = "Blossom", parent = hd, at = CF(math.cos(a) * 1.0 * u, (0.9 + (k % 2) * 0.3) * u, math.sin(a) * 1.0 * u), shape = "ball", size = Vector3.one * 0.28 * u, color = m.blossoms, material = "Neon", role = "Glow", shadow = false })
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		local a = hub(rig, side < 0 and "ArmL" or "ArmR", body, side < 0 and "ArmL" or "ArmR", CF(side * 0.78 * u, 0.7 * u, 0))
		add(rig, { name = "Branch", parent = a, at = CF(side * 0.35 * u, -0.5 * u, 0) * ANG(0, 0, side * rad(25)), shape = "ellipsoid", size = V(0.38, 1.35, 0.38) * u, color = P.body, material = "Wood", role = "Body" })
		add(rig, { name = "Twig", parent = a, at = CF(side * 0.75 * u, -1.15 * u, 0) * ANG(0, 0, side * rad(-20)), shape = "ellipsoid", size = V(0.22, 0.65, 0.22) * u, color = P.body, material = "Wood", role = "Body" })
		add(rig, { name = "Twig", parent = a, at = CF(side * 0.6 * u, -1.15 * u, -0.1 * u) * ANG(rad(30), 0, side * rad(30)), shape = "ellipsoid", size = V(0.14, 0.5, 0.14) * u, color = P.body, material = "Wood", role = "Body" })
		add(rig, { name = "TwigLeaf", parent = a, at = CF(side * 0.85 * u, -1.5 * u, 0), shape = "ball", size = Vector3.one * 0.45 * u, color = P.accent, material = "Grass", role = "Accent" })
		local l = hub(rig, side < 0 and "LegL" or "LegR", body, side < 0 and "LegL" or "LegR", CF(side * 0.45 * u, -1.15 * u, 0))
		add(rig, { name = "Root", parent = l, at = CF(0, -0.4 * u, 0), shape = "ellipsoid", size = V(0.6, 1.0, 0.7) * u, color = darker(P.body, 0.85), material = "Wood", role = "Body" })
		for i = -1, 1 do
			add(rig, { name = "RootToe", parent = l, at = CF(side * 0.05 * u + i * 0.2 * u, -0.82 * u, -0.25 * u) * ANG(rad(-70), rad(i * 25), 0), shape = "ellipsoid", size = V(0.2, 0.62, 0.2) * u,
				color = darker(P.body, 0.78), material = "Wood", role = "Body" })
		end
	end
	if m.glowCore then
		add(rig, { name = "Core", parent = body, at = CF(0, 0.2 * u, -0.7 * u) * ANG(0, 0, rad(45)), shape = "block", size = V(0.4, 0.4, 0.1) * u, color = m.glowCore, material = "Neon", role = "Glow" })
	end
	return 1.25 * u + 0.85 * u
end

local BUILDERS = { quad = buildQuad, biped = buildBiped, flyer = buildFlyer, serpent = buildSerpent, floater = buildFloater, golem = buildGolem,
	slime = buildSlime, shroom = buildShroom, treant = buildTreant }

-- Constrói um pet. Retorna (model, alturaDoRootAcimaDoChao, flutua?)
function CreatureBuilder.build(speciesId: string, species, scaleMul: number?)
	local m = species.model
	local u = (m.size or 1) * (scaleMul or 1) * 1.1
	local rig = ModelKit.newRig(speciesId, Vector3.new(2 * u, 2 * u, 2.4 * u))
	local builder = BUILDERS[m.rig] or buildQuad
	local P = palette(m)
	local hoverHeight = builder(rig, m, P, u)
	rig.model:SetAttribute("Rig", m.rig)
	rig.model:SetAttribute("Species", speciesId)
	local flies = m.rig == "flyer" or m.rig == "floater"
	return rig.model, hoverHeight, flies
end

CreatureBuilder.addWings = addWings
CreatureBuilder.palette = palette

return CreatureBuilder

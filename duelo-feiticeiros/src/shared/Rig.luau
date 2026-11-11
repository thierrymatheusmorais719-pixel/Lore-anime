-- PERSONAGENS da cinemática: corpo de peças com juntas (Motor6D) no estilo de anime (cabeça um pouco maior,
-- casaco longo, cabelo espetado), e uma biblioteca de POSES de luta. Rig.pose muda a pose-alvo e Rig.step
-- mistura suavemente (ou corta seco, para os quadros de impacto).

local Rig = {}

local V = Vector3.new
local CF = CFrame.new
local A = CFrame.Angles
local rgb = Color3.fromRGB
local rad = math.rad

-- Personagens ORIGINAIS desta cinemática.
Rig.Fighters = {
	ren = {
		name = "Ren Arashi", title = "Feiticeiro da Tempestade",
		skin = rgb(240, 214, 196), hair = rgb(24, 26, 34), streak = rgb(80, 230, 255), coat = rgb(28, 34, 58), coatTrim = rgb(80, 230, 255),
		pants = rgb(20, 20, 26), band = rgb(80, 230, 255), eyes = rgb(120, 240, 255), energy = rgb(80, 220, 255),
	},
	akane = {
		name = "Akane Sumi", title = "Feiticeira da Tinta Carmesim",
		skin = rgb(236, 206, 188), hair = rgb(150, 20, 34), streak = rgb(255, 90, 90), coat = rgb(140, 18, 30), coatTrim = rgb(240, 236, 230),
		pants = rgb(18, 14, 18), band = rgb(240, 236, 230), eyes = rgb(255, 70, 70), energy = rgb(220, 20, 40),
	},
}

local function part(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Anchored = false
	p.Massless = true
	p.Parent = model
	return p
end

local function weld(a: BasePart, b: BasePart, c0: CFrame)
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = a, b, c0
	w.Parent = b
	return w
end

-- junta: Part1 pendurada em Part0 no ponto `at` (coordenadas de Part0), com o offset da peça filha
local function joint(name: string, p0: BasePart, p1: BasePart, at: CFrame, childOffset: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0, m.Part1 = p0, p1
	m.C0 = at
	m.C1 = childOffset
	m.Parent = p1
	return m
end

-- Versão com avatar R15 (itens do catálogo, ver Appearance.luau): clona o modelo que o servidor montou e
-- usa as juntas dele. Os nomes das juntas R15 (Root, Waist, Neck, LeftShoulder...) são os mesmos das poses.
local POSED = { "Root", "Waist", "Neck", "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist",
	"LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle" }
local function buildAvatar(key: string, template: Model, cf: CFrame)
	local d = Rig.Fighters[key]
	local model = template:Clone()
	model.Name = d.name
	model:SetAttribute("Avatar", true)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hipH = 3
	if hum then
		hipH = (hum.HipHeight or 2) + root.Size.Y / 2
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			animator:Destroy() -- quem mexe nas juntas é a cinemática
		end
	end
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
		end
	end
	root.Anchored = true
	model.PrimaryPart = root
	local joints = {}
	for _, m in ipairs(model:GetDescendants()) do
		if m:IsA("Motor6D") and table.find(POSED, m.Name) then
			joints[m.Name] = m
		end
	end
	root.CFrame = cf * CF(0, hipH, 0)
	local rig = { key = key, def = d, model = model, root = root, joints = joints, hipH = hipH, cur = {}, target = {}, speed = 14, base = {}, avatar = true }
	Rig.pose(rig, "idle", true)
	return rig
end

-- Monta um personagem (def = Rig.Fighters[...]) em `cf` (de pé, pés no chão de `cf`).
-- Se o servidor montou um avatar com itens do catálogo para ele, usa o avatar.
function Rig.build(key: string, cf: CFrame)
	local avatars = game:GetService("ReplicatedStorage"):FindFirstChild("DueloAvatars")
	local template = avatars and avatars:FindFirstChild(key)
	if template and template:IsA("Model") and template:FindFirstChild("HumanoidRootPart") then
		return buildAvatar(key, template, cf)
	end
	local d = Rig.Fighters[key]
	local model = Instance.new("Model")
	model.Name = d.name
	local root = part(model, "HumanoidRootPart", V(2, 2, 1), d.coat)
	root.Transparency = 1
	root.Anchored = true
	model.PrimaryPart = root
	-- corpo (proporção de anime: pernas longas, cabeça um pouco maior)
	local lower = part(model, "LowerTorso", V(1.9, 0.8, 1.05), d.pants)
	local upper = part(model, "UpperTorso", V(2.1, 1.7, 1.15), d.coat, Enum.Material.Fabric)
	local head = part(model, "Head", V(1.45, 1.55, 1.45), d.skin, nil, Enum.PartType.Ball)
	local joints = {}
	joints.Root = joint("Root", root, lower, CF(0, -0.4, 0), CF())
	joints.Waist = joint("Waist", lower, upper, CF(0, 0.4, 0), CF(0, -0.85, 0))
	joints.Neck = joint("Neck", upper, head, CF(0, 0.85, 0), CF(0, -0.75, 0))
	-- gola alta do casaco e faixa no peito
	weld(upper, part(model, "Collar", V(1.7, 0.6, 1.3), d.coat, Enum.Material.Fabric), CF(0, 0.85, 0))
	weld(upper, part(model, "Trim", V(0.25, 1.7, 1.2), d.coatTrim, Enum.Material.Neon), CF(0, 0, 0))
	-- rosto: olhos que brilham, faixa/tiara
	for _, s in ipairs({ -1, 1 }) do
		local eye = part(model, "Eye", V(0.28, 0.16, 0.08), d.eyes, Enum.Material.Neon)
		weld(head, eye, CF(s * 0.32, 0.05, -0.68))
	end
	weld(head, part(model, "Band", V(1.5, 0.22, 1.5), d.band, Enum.Material.Fabric), CF(0, 0.38, 0))
	-- cabelo espetado: blocos inclinados em leque por cima e atrás
	local rng = Random.new(#key * 31)
	for k = 0, 10 do
		local a = (k / 10 - 0.5) * math.pi * 1.25
		local len = 0.9 + rng:NextNumber(0, 0.5)
		local spike = part(model, "Hair", V(0.42, len, 0.42), (k % 4 == 0) and d.streak or d.hair, Enum.Material.SmoothPlastic)
		weld(head, spike, CF(math.sin(a) * 0.55, 0.6 + math.cos(a) * 0.15, 0.25 + math.cos(a) * 0.2) * A(rad(-35) + rng:NextNumber(-0.3, 0.1), 0, -a * 0.6) * CF(0, len / 2 - 0.2, 0))
	end
	weld(head, part(model, "HairCap", V(1.55, 0.9, 1.55), d.hair, nil, Enum.PartType.Ball), CF(0, 0.38, 0.12))
	if key == "akane" then
		-- rabo de cavalo longo, preso atrás
		for k = 1, 4 do
			local seg = part(model, "Ponytail", V(0.55 - k * 0.07, 0.9, 0.5 - k * 0.06), d.hair)
			weld(head, seg, CF(0, 0.3 - k * 0.75, 0.75 + k * 0.12) * A(rad(18), 0, 0))
		end
		-- pincel gigante nas costas
		local staff = part(model, "BrushStaff", V(0.22, 5.2, 0.22), rgb(60, 36, 24), Enum.Material.Wood)
		weld(upper, staff, CF(0, 0.2, 0.7) * A(0, 0, rad(32)))
		local tip = part(model, "BrushTip", V(0.6, 1, 0.6), rgb(150, 10, 24), Enum.Material.Fabric, Enum.PartType.Ball)
		weld(staff, tip, CF(0, -2.9, 0))
	end
	-- braços (ombro, cotovelo) e mãos
	local function arm(side: number, label: string)
		local u = part(model, label .. "UpperArm", V(0.7, 1.3, 0.7), d.coat, Enum.Material.Fabric)
		local l = part(model, label .. "LowerArm", V(0.62, 1.2, 0.62), d.coat, Enum.Material.Fabric)
		local h = part(model, label .. "Hand", V(0.55, 0.55, 0.55), d.skin, nil, Enum.PartType.Ball)
		joints[label .. "Shoulder"] = joint(label .. "Shoulder", upper, u, CF(side * 1.4, 0.55, 0), CF(0, 0.5, 0))
		joints[label .. "Elbow"] = joint(label .. "Elbow", u, l, CF(0, -0.6, 0), CF(0, 0.55, 0))
		joints[label .. "Wrist"] = joint(label .. "Wrist", l, h, CF(0, -0.65, 0), CF(0, 0.15, 0))
		weld(l, part(model, label .. "Cuff", V(0.72, 0.2, 0.72), d.coatTrim, Enum.Material.Neon), CF(0, -0.5, 0))
	end
	arm(-1, "Left")
	arm(1, "Right")
	-- pernas
	local function leg(side: number, label: string)
		local u = part(model, label .. "UpperLeg", V(0.8, 1.55, 0.8), d.pants)
		local l = part(model, label .. "LowerLeg", V(0.72, 1.5, 0.72), d.pants)
		local f = part(model, label .. "Foot", V(0.75, 0.4, 1.15), rgb(16, 16, 20))
		joints[label .. "Hip"] = joint(label .. "Hip", lower, u, CF(side * 0.5, -0.4, 0), CF(0, 0.7, 0))
		joints[label .. "Knee"] = joint(label .. "Knee", u, l, CF(0, -0.75, 0), CF(0, 0.7, 0))
		joints[label .. "Ankle"] = joint(label .. "Ankle", l, f, CF(0, -0.75, 0), CF(0, 0.15, 0.15))
	end
	leg(-1, "Left")
	leg(1, "Right")
	-- abas do casaco longo (balançam com o movimento)
	for _, s in ipairs({ -1, 1 }) do
		local tail = part(model, "CoatTail", V(0.95, 2.4, 0.18), d.coat, Enum.Material.Fabric)
		joints[(s < 0 and "Left" or "Right") .. "Coat"] = joint((s < 0 and "Left" or "Right") .. "Coat", lower, tail, CF(s * 0.5, -0.1, 0.48), CF(0, 1.1, 0))
	end
	local hipH = 0.4 + 1.55 + 1.5 + 0.4 - 0.3 -- altura do quadril até o chão
	root.CFrame = cf * CF(0, hipH, 0)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			p.CFrame = root.CFrame
		end
	end
	local rig = { key = key, def = d, model = model, root = root, joints = joints, hipH = hipH, cur = {}, target = {}, speed = 14, base = cf }
	Rig.pose(rig, "idle", true)
	return rig
end

-- POSES: ângulos (x, y, z em graus) por junta + deslocamento/rotação do corpo. Juntas sem entrada voltam a 0.
local P = {}
P.idle = { Waist = { 4, 0, 0 }, LeftShoulder = { 0, 0, -8 }, RightShoulder = { 0, 0, 8 }, LeftElbow = { -10, 0, 0 }, RightElbow = { -10, 0, 0 },
	LeftHip = { 0, 0, -3 }, RightHip = { 0, 0, 3 }, LeftCoat = { 6, 0, 0 }, RightCoat = { 6, 0, 0 } }
P.guard = { root = { 0, -0.35, 0 }, Waist = { 12, -18, 0 }, Neck = { -6, 14, 0 }, LeftShoulder = { 70, 0, -20 }, LeftElbow = { -95, 0, 0 },
	RightShoulder = { 40, 0, 25 }, RightElbow = { -110, 0, 0 }, LeftHip = { 20, 0, -6 }, LeftKnee = { -30, 0, 0 }, RightHip = { -14, 0, 6 },
	RightKnee = { -20, 0, 0 }, LeftCoat = { 15, 0, 0 }, RightCoat = { 15, 0, 0 } }
P.dash = { root = { 0, -0.6, 0 }, rootRot = { 28, 0, 0 }, Waist = { 14, 0, 0 }, Neck = { -24, 0, 0 }, LeftShoulder = { -50, 0, -10 }, RightShoulder = { -50, 0, 10 },
	LeftElbow = { -20, 0, 0 }, RightElbow = { -20, 0, 0 }, LeftHip = { 55, 0, 0 }, LeftKnee = { -80, 0, 0 }, RightHip = { -40, 0, 0 }, RightKnee = { -30, 0, 0 },
	LeftCoat = { 70, 0, 0 }, RightCoat = { 70, 0, 0 } }
P.punch = { root = { 0, -0.3, -0.4 }, rootRot = { 8, -25, 0 }, Waist = { 6, -35, 0 }, Neck = { 0, 30, 0 }, RightShoulder = { 90, 0, 0 }, RightElbow = { 0, 0, 0 },
	LeftShoulder = { 30, 0, -20 }, LeftElbow = { -120, 0, 0 }, LeftHip = { 30, 0, 0 }, LeftKnee = { -25, 0, 0 }, RightHip = { -30, 0, 0 }, RightKnee = { -10, 0, 0 },
	LeftCoat = { 30, 0, 0 }, RightCoat = { 30, 0, 0 } }
P.punchL = { root = { 0, -0.3, -0.4 }, rootRot = { 8, 25, 0 }, Waist = { 6, 35, 0 }, Neck = { 0, -30, 0 }, LeftShoulder = { 90, 0, 0 }, LeftElbow = { 0, 0, 0 },
	RightShoulder = { 30, 0, 20 }, RightElbow = { -120, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -25, 0, 0 }, LeftHip = { -30, 0, 0 }, LeftKnee = { -10, 0, 0 },
	LeftCoat = { 30, 0, 0 }, RightCoat = { 30, 0, 0 } }
P.kick = { root = { 0, 0.3, 0 }, rootRot = { -10, 30, 0 }, Waist = { -12, 20, 0 }, RightHip = { 100, 0, 10 }, RightKnee = { -5, 0, 0 }, LeftHip = { -10, 0, 0 },
	LeftKnee = { -25, 0, 0 }, LeftShoulder = { 20, 0, -60 }, RightShoulder = { -30, 0, 50 }, LeftElbow = { -40, 0, 0 }, RightElbow = { -40, 0, 0 },
	LeftCoat = { 40, 0, 0 }, RightCoat = { 50, 0, 0 } }
P.hurt = { root = { 0, -0.2, 0.6 }, rootRot = { -18, 0, 6 }, Waist = { -16, 0, 0 }, Neck = { -20, 0, 8 }, LeftShoulder = { -20, 0, -55 }, RightShoulder = { -30, 0, 60 },
	LeftElbow = { -30, 0, 0 }, RightElbow = { -40, 0, 0 }, LeftHip = { -12, 0, 0 }, RightHip = { 18, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftCoat = { -20, 0, 0 },
	RightCoat = { -20, 0, 0 } }
P.castUp = { root = { 0, 0, 0 }, rootRot = { -6, 0, 0 }, Waist = { -10, 0, 0 }, Neck = { -18, 0, 0 }, RightShoulder = { 170, 0, 8 }, RightElbow = { -5, 0, 0 },
	LeftShoulder = { 20, 0, -30 }, LeftElbow = { -60, 0, 0 }, LeftHip = { 6, 0, -8 }, RightHip = { -6, 0, 8 }, LeftCoat = { 12, 0, 0 }, RightCoat = { 12, 0, 0 } }
P.castPoint = { root = { 0, -0.25, 0 }, rootRot = { 0, -10, 0 }, Waist = { 4, -20, 0 }, Neck = { 0, 18, 0 }, RightShoulder = { 88, 0, 0 }, RightElbow = { 0, 0, 0 },
	RightWrist = { -20, 0, 0 }, LeftShoulder = { 40, 0, -10 }, LeftElbow = { -100, 0, 0 }, LeftHip = { 22, 0, -8 }, LeftKnee = { -25, 0, 0 }, RightHip = { -18, 0, 8 },
	LeftCoat = { 18, 0, 0 }, RightCoat = { 18, 0, 0 } }
-- sinal de mão das técnicas de arena (mãos juntas na frente do rosto)
P.handSign = { Waist = { 4, 0, 0 }, Neck = { 8, 0, 0 }, LeftShoulder = { 80, 0, 32 }, LeftElbow = { -110, 0, 0 }, RightShoulder = { 80, 0, -32 },
	RightElbow = { -110, 0, 0 }, LeftHip = { 0, 0, -6 }, RightHip = { 0, 0, 6 }, LeftCoat = { 4, 0, 0 }, RightCoat = { 4, 0, 0 } }
P.slash = { root = { 0, -0.45, -0.3 }, rootRot = { 10, 40, 0 }, Waist = { 8, 50, 0 }, Neck = { 0, -40, 0 }, RightShoulder = { 60, 0, 70 }, RightElbow = { -10, 0, 0 },
	LeftShoulder = { 10, 0, -40 }, LeftElbow = { -60, 0, 0 }, LeftHip = { 35, 0, 0 }, LeftKnee = { -45, 0, 0 }, RightHip = { -30, 0, 0 }, RightKnee = { -10, 0, 0 },
	LeftCoat = { 45, 0, 0 }, RightCoat = { 45, 0, 0 } }
P.kneel = { root = { 0, -1.5, 0 }, rootRot = { 18, 0, 0 }, Waist = { 20, 0, 0 }, Neck = { 22, 0, 0 }, LeftHip = { 90, 0, 0 }, LeftKnee = { -100, 0, 0 },
	RightHip = { 10, 0, 0 }, RightKnee = { -120, 0, 0 }, RightShoulder = { 20, 0, 10 }, LeftShoulder = { 50, 0, -10 }, LeftElbow = { -40, 0, 0 } }
P.float = { root = { 0, 0.6, 0 }, rootRot = { -4, 0, 0 }, Waist = { -4, 0, 0 }, LeftShoulder = { 10, 0, -40 }, RightShoulder = { 10, 0, 40 },
	LeftElbow = { -20, 0, 0 }, RightElbow = { -20, 0, 0 }, LeftHip = { 10, 0, -6 }, LeftKnee = { -30, 0, 0 }, RightHip = { 4, 0, 6 }, RightKnee = { -15, 0, 0 },
	LeftCoat = { -10, 0, 0 }, RightCoat = { -10, 0, 0 } }
Rig.Poses = P

-- Muda a pose-alvo. snap = corta seco (sem mistura); speed = rapidez da mistura (padrão 14).
function Rig.pose(rig, name: string, snap: boolean?, speed: number?)
	local p = P[name]
	assert(p, "pose desconhecida: " .. tostring(name))
	rig.poseName = name
	rig.speed = speed or 14
	table.clear(rig.target)
	for jn in pairs(rig.joints) do
		local a = p[jn]
		rig.target[jn] = a and V(rad(a[1]), rad(a[2]), rad(a[3])) or Vector3.zero
	end
	local r = p.root or { 0, 0, 0 }
	local rr = p.rootRot or { 0, 0, 0 }
	rig.target.__root = V(r[1], r[2], r[3])
	rig.target.__rootRot = V(rad(rr[1]), rad(rr[2]), rad(rr[3]))
	if snap then
		for k, v in pairs(rig.target) do
			rig.cur[k] = v
		end
		Rig.apply(rig)
	end
end

function Rig.apply(rig)
	for jn, m in pairs(rig.joints) do
		local a = rig.cur[jn] or Vector3.zero
		if jn == "Root" then
			local o = rig.cur.__root or Vector3.zero
			local rr = rig.cur.__rootRot or Vector3.zero
			m.Transform = CF(o) * A(rr.X, rr.Y, rr.Z)
		else
			m.Transform = A(a.X, a.Y, a.Z)
		end
	end
end

-- Um passo de mistura (chamar a cada quadro). `t` = tempo, para respirar/esvoaçar o casaco.
function Rig.step(rig, dt: number, t: number)
	local k = 1 - math.exp(-rig.speed * dt)
	for name, v in pairs(rig.target) do
		local c = rig.cur[name] or Vector3.zero
		rig.cur[name] = c + (v - c) * k
	end
	-- casaco esvoaça com o vento; leve respiração
	local flutter = math.sin(t * 7 + #rig.key) * 0.08
	for _, side in ipairs({ "LeftCoat", "RightCoat" }) do
		if rig.cur[side] then
			rig.cur[side] = rig.cur[side] + V(flutter, 0, 0) * k
		end
	end
	Rig.apply(rig)
end

-- Coloca o personagem (raiz ancorada) num ponto, olhando para outro.
function Rig.place(rig, at: Vector3, lookAt: Vector3?)
	local pos = at + V(0, rig.hipH, 0)
	if lookAt then
		local flat = V(lookAt.X, pos.Y, lookAt.Z)
		rig.root.CFrame = CFrame.lookAt(pos, flat)
	else
		rig.root.CFrame = CF(pos) * (rig.root.CFrame - rig.root.CFrame.Position)
	end
end

return Rig

-- PERSONAGENS da cinemática: corpo R15 do Roblox + as animações de luta feitas no Blender (Anims.luau,
-- gerado por tools/blender/r15_anims.py).
--   * Se o servidor conseguiu montar o avatar R15 do Roblox (Players:CreateHumanoidModelFromDescription, com as
--     cores do personagem e, se houver, os itens de Appearance.luau), a cinemática usa uma cópia dele.
--   * Se não, monta aqui um R15 "blocky" padrão com peças (mesmos nomes de peças e de juntas do R15).
-- As animações mexem só no Motor6D.Transform das juntas do R15 (Root, Waist, Neck, ombros, cotovelos, pulsos,
-- quadris, joelhos, tornozelos), então servem para os dois casos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Anims = require(script.Parent.Anims)

local Rig = {}

local V = Vector3.new
local CF = CFrame.new
local A = CFrame.Angles
local rgb = Color3.fromRGB
local rad = math.rad

-- Personagens ORIGINAIS desta cinemática (cores do corpo do R15 e detalhes).
Rig.Fighters = {
	ren = {
		name = "Ren Arashi", title = "Feiticeiro da Tempestade",
		skin = rgb(240, 214, 196), torso = rgb(28, 34, 58), arms = rgb(28, 34, 58), legs = rgb(20, 20, 26), hair = rgb(24, 26, 34),
		band = rgb(80, 230, 255), energy = rgb(80, 220, 255),
	},
	akane = {
		name = "Akane Sumi", title = "Feiticeira da Tinta Carmesim",
		skin = rgb(236, 206, 188), torso = rgb(140, 18, 30), arms = rgb(140, 18, 30), legs = rgb(18, 14, 18), hair = rgb(150, 20, 34),
		band = rgb(240, 236, 230), energy = rgb(220, 20, 40),
	},
}

local function part(model: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
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

local function motor(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0, m.Part1 = p0, p1
	m.C0, m.C1 = c0, c1
	m.Parent = p1
	return m
end

-- R15 "blocky" padrão (escala 1). Pivôs das juntas = os mesmos do esqueleto do Blender (r15_anims.py).
-- Linha: peça, pai, junta, tamanho, centro da peça, pivô da junta (pés em y = 0), cor.
local R15 = {
	{ "LowerTorso", "HumanoidRootPart", "Root", V(2, 0.4, 1), V(0, 2.8, 0), V(0, 3.0, 0), "torso" },
	{ "UpperTorso", "LowerTorso", "Waist", V(2, 1.6, 1), V(0, 3.8, 0), V(0, 3.0, 0), "torso" },
	{ "Head", "UpperTorso", "Neck", V(1.2, 1.2, 1.2), V(0, 5.2, 0), V(0, 4.6, 0), "skin" },
	{ "RightUpperArm", "UpperTorso", "RightShoulder", V(1, 1.2, 1), V(1.5, 4.0, 0), V(1.5, 4.4, 0), "arms" },
	{ "RightLowerArm", "RightUpperArm", "RightElbow", V(1, 1.05, 1), V(1.5, 2.95, 0), V(1.5, 3.45, 0), "skin" },
	{ "RightHand", "RightLowerArm", "RightWrist", V(1, 0.4, 1), V(1.5, 2.3, 0), V(1.5, 2.5, 0), "skin" },
	{ "LeftUpperArm", "UpperTorso", "LeftShoulder", V(1, 1.2, 1), V(-1.5, 4.0, 0), V(-1.5, 4.4, 0), "arms" },
	{ "LeftLowerArm", "LeftUpperArm", "LeftElbow", V(1, 1.05, 1), V(-1.5, 2.95, 0), V(-1.5, 3.45, 0), "skin" },
	{ "LeftHand", "LeftLowerArm", "LeftWrist", V(1, 0.4, 1), V(-1.5, 2.3, 0), V(-1.5, 2.5, 0), "skin" },
	{ "RightUpperLeg", "LowerTorso", "RightHip", V(1, 1.2, 1), V(0.5, 2.1, 0), V(0.5, 2.7, 0), "legs" },
	{ "RightLowerLeg", "RightUpperLeg", "RightKnee", V(1, 1.2, 1), V(0.5, 0.9, 0), V(0.5, 1.5, 0), "legs" },
	{ "RightFoot", "RightLowerLeg", "RightAnkle", V(1, 0.3, 1.1), V(0.5, 0.15, -0.05), V(0.5, 0.3, 0), "legs" },
	{ "LeftUpperLeg", "LowerTorso", "LeftHip", V(1, 1.2, 1), V(-0.5, 2.1, 0), V(-0.5, 2.7, 0), "legs" },
	{ "LeftLowerLeg", "LeftUpperLeg", "LeftKnee", V(1, 1.2, 1), V(-0.5, 0.9, 0), V(-0.5, 1.5, 0), "legs" },
	{ "LeftFoot", "LeftLowerLeg", "LeftAnkle", V(1, 0.3, 1.1), V(-0.5, 0.15, -0.05), V(-0.5, 0.3, 0), "legs" },
}
local ROOT_Y = 3.0

local function buildBlocky(d): (Model, number)
	local model = Instance.new("Model")
	local hrp = part(model, "HumanoidRootPart", V(2, 2, 1), d.torso)
	hrp.Transparency = 1
	local centers = { HumanoidRootPart = V(0, ROOT_Y, 0) }
	local parts = { HumanoidRootPart = hrp }
	for _, row in ipairs(R15) do
		local name, parentName, joint, size, center, pivot, colorKey = row[1], row[2], row[3], row[4], row[5], row[6], row[7]
		local p = part(model, name, size, d[colorKey])
		if name == "Head" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = V(1, 1, 1)
			mesh.Parent = p
			local face = Instance.new("Decal")
			face.Name = "face"
			face.Texture = "rbxasset://textures/face.png" -- rosto padrão do Roblox (arquivo embutido)
			face.Face = Enum.NormalId.Front
			face.Parent = p
		end
		motor(joint, parts[parentName], p, CF(pivot - centers[parentName]), CF(pivot - center))
		centers[name], parts[name] = center, p
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 2
	hum.Parent = model
	return model, ROOT_Y
end

-- detalhes de cada personagem (presos à cabeça / ao tronco por nome; servem no R15 real e no blocky)
local function addDetails(key: string, model: Model)
	local d = Rig.Fighters[key]
	local head = model:FindFirstChild("Head") :: BasePart?
	local upper = model:FindFirstChild("UpperTorso") :: BasePart?
	if not head or not upper then
		return
	end
	local hs = head.Size.Y
	local rng = Random.new(#key * 31)
	weld(head, part(model, "HairCap", V(hs * 1.08, hs * 0.5, hs * 1.08), d.hair), CF(0, hs * 0.38, hs * 0.06))
	for k = 0, 8 do
		local a = (k / 8 - 0.5) * math.pi * 1.2
		local len = hs * (0.55 + rng:NextNumber(0, 0.35))
		local spike = part(model, "Hair", V(hs * 0.3, len, hs * 0.3), d.hair)
		weld(head, spike, CF(math.sin(a) * hs * 0.42, hs * 0.55, hs * 0.2 + math.cos(a) * hs * 0.15) * A(rad(-35) + rng:NextNumber(-0.3, 0.1), 0, -a * 0.6)
			* CF(0, len / 2 - 0.1, 0))
	end
	weld(head, part(model, "Band", V(hs * 1.06, hs * 0.16, hs * 1.06), d.band, Enum.Material.Neon), CF(0, hs * 0.24, 0))
	if key == "akane" then
		for k = 1, 4 do
			weld(head, part(model, "Ponytail", V(hs * (0.45 - k * 0.05), hs * 0.7, hs * (0.4 - k * 0.05)), d.hair),
				CF(0, hs * (0.3 - k * 0.55), hs * (0.6 + k * 0.1)) * A(rad(18), 0, 0))
		end
		local staff = part(model, "BrushStaff", V(0.22, 5.2, 0.22), rgb(60, 36, 24), Enum.Material.Wood)
		weld(upper, staff, CF(0, 0.2, upper.Size.Z / 2 + 0.2) * A(0, 0, rad(32)))
		local tip = part(model, "BrushTip", V(0.6, 1, 0.6), rgb(150, 10, 24), Enum.Material.Fabric)
		tip.Shape = Enum.PartType.Ball
		weld(staff, tip, CF(0, -2.9, 0))
	end
end

-- Monta um personagem em `cf` (pés no chão de `cf`).
function Rig.build(key: string, cf: CFrame)
	local d = Rig.Fighters[key]
	local avatars = ReplicatedStorage:FindFirstChild("DueloAvatars")
	local template = avatars and avatars:FindFirstChild(key)
	local model: Model, hipH: number
	local isAvatar = false
	if template and template:IsA("Model") and template:FindFirstChild("HumanoidRootPart") then
		model = template:Clone()
		local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
		local h = model:FindFirstChildOfClass("Humanoid")
		hipH = ((h and h.HipHeight) or 2) + hrp.Size.Y / 2
		isAvatar = true
	else
		model, hipH = buildBlocky(d)
	end
	model.Name = d.name
	model:SetAttribute("Avatar", isAvatar)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			animator:Destroy() -- quem mexe nas juntas são as animações do Blender
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
	addDetails(key, model)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	model.PrimaryPart = root
	local joints = {}
	for _, m in ipairs(model:GetDescendants()) do
		if m:IsA("Motor6D") and table.find(Anims.Joints, m.Name) then
			joints[m.Name] = m
		end
	end
	root.CFrame = cf * CF(0, hipH, 0)
	local rig = {
		key = key, def = d, model = model, root = root, joints = joints, hipH = hipH, avatar = isAvatar,
		clip = nil :: string?, time = 0, fade = 1, fadeTime = 0.12, from = {}, pose = {},
	}
	Rig.pose(rig, "idle", true)
	Rig.step(rig, 0, 0)
	return rig
end

local function quat(arr, f: number)
	local i = f * 4
	return arr[i + 1], arr[i + 2], arr[i + 3], arr[i + 4]
end
local function nlerp(ax, ay, az, aw, bx, by, bz, bw, t)
	if ax * bx + ay * by + az * bz + aw * bw < 0 then
		bx, by, bz, bw = -bx, -by, -bz, -bw
	end
	local x, y, z, w = ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t, aw + (bw - aw) * t
	local l = math.sqrt(x * x + y * y + z * z + w * w)
	return x / l, y / l, z / l, w / l
end

-- Toca uma animação do Blender. snap = começa no quadro do golpe (sem transição), para casar com o impacto;
-- senão começa do início com uma transição curta. speed >= 20 = transição mais curta.
function Rig.pose(rig, name: string, snap: boolean?, speed: number?)
	local clip = Anims.Clips[name]
	assert(clip, "animação desconhecida: " .. tostring(name))
	for j, q in pairs(rig.pose) do
		rig.from[j] = q
	end
	rig.clip = name
	if snap then
		rig.time = clip.hit / Anims.FPS
		rig.fade = 1
	else
		rig.time = 0
		rig.fade = 0
		rig.fadeTime = (speed and speed >= 20) and 0.06 or 0.12
	end
end

-- Avança a animação (chamar a cada quadro) e aplica nas juntas.
function Rig.step(rig, dt: number, _t: number)
	local clip = rig.clip and Anims.Clips[rig.clip]
	if not clip then
		return
	end
	rig.time += dt
	if rig.fade < 1 then
		rig.fade = math.min(1, rig.fade + dt / rig.fadeTime)
	end
	local last = clip.frames - 1
	local f = rig.time * Anims.FPS
	if clip.loop then
		f = f % last
	elseif f > last then
		local hl = clip.holdLoop
		f = hl and (hl[1] + (f - hl[1]) % (hl[2] - hl[1])) or last
	end
	local f0 = math.floor(f)
	local f1 = math.min(f0 + 1, last)
	local k = f - f0
	local w = rig.fade * rig.fade * (3 - 2 * rig.fade)
	for j, m in pairs(rig.joints) do
		local arr = clip.J[j]
		if arr then
			local ax, ay, az, aw = quat(arr, f0)
			local bx, by, bz, bw = quat(arr, f1)
			local x, y, z, qw = nlerp(ax, ay, az, aw, bx, by, bz, bw, k)
			local px, py, pz = 0, 0, 0
			if j == "Root" then
				local P = clip.RootPos
				px = P[f0 * 3 + 1] + (P[f1 * 3 + 1] - P[f0 * 3 + 1]) * k
				py = P[f0 * 3 + 2] + (P[f1 * 3 + 2] - P[f0 * 3 + 2]) * k
				pz = P[f0 * 3 + 3] + (P[f1 * 3 + 3] - P[f0 * 3 + 3]) * k
			end
			local fr = rig.from[j]
			if w < 1 and fr then
				x, y, z, qw = nlerp(fr[1], fr[2], fr[3], fr[4], x, y, z, qw, w)
				px, py, pz = fr[5] + (px - fr[5]) * w, fr[6] + (py - fr[6]) * w, fr[7] + (pz - fr[7]) * w
			end
			rig.pose[j] = { x, y, z, qw, px, py, pz }
			m.Transform = CF(px, py, pz, x, y, z, qw)
		end
	end
end

-- Coloca o personagem (raiz ancorada) num ponto, olhando para outro.
function Rig.place(rig, at: Vector3, lookAt: Vector3?)
	local pos = at + V(0, rig.hipH, 0)
	if lookAt then
		rig.root.CFrame = CFrame.lookAt(pos, V(lookAt.X, pos.Y, lookAt.Z))
	else
		rig.root.CFrame = CF(pos) * (rig.root.CFrame - rig.root.CFrame.Position)
	end
end

return Rig

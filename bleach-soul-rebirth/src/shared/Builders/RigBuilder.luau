-- Constrói um rig R15 procedural (15 partes, Motor6D com nomes padrão) sem depender de assets.
-- Os nomes das juntas são os mesmos do R15 oficial, então as animações procedurais e
-- animações publicadas funcionam igualmente em NPCs e jogadores.
local RigBuilder = {}

-- Corpos de criatura (Hollows) gerados por tools/creatures/bodies.py — os mesmos usados para
-- compilar e verificar as animações de cada criatura (tools/creatures/author_creatures.py).
local CreatureRigs = require(script.Parent.Parent.Config.CreatureRigs) :: any

-- Medidas EXATAS do R15 padrão do Roblox (as mesmas do compilador de animações da skill
-- roblox-vfx-animation): animações verificadas lá caem iguais aqui, com os pés no chão.
-- name, size, parent part, joint name, C0 (no pai), C1 (na parte)
local PARTS = {
	{
		"LowerTorso",
		Vector3.new(1.99, 0.4, 1),
		"HumanoidRootPart",
		"Root",
		Vector3.new(0, -1, 0),
		Vector3.new(0, -0.2, 0),
	},
	{
		"UpperTorso",
		Vector3.new(1.94, 1.7, 1),
		"LowerTorso",
		"Waist",
		Vector3.new(0, 0.2, 0),
		Vector3.new(0, -0.849, 0),
	},
	{
		"Head",
		Vector3.new(1.16, 1.18, 1.16),
		"UpperTorso",
		"Neck",
		Vector3.new(0, 0.849, 0),
		Vector3.new(0, -0.576, 0),
	},
	{
		"RightUpperArm",
		Vector3.new(1, 1.24, 1),
		"UpperTorso",
		"RightShoulder",
		Vector3.new(0.972, 0.598, 0),
		Vector3.new(-0.501, 0.419, 0),
	},
	{
		"RightLowerArm",
		Vector3.new(1, 1.12, 1),
		"RightUpperArm",
		"RightElbow",
		Vector3.new(0, -0.355, 0),
		Vector3.new(0, 0.275, 0),
	},
	{
		"RightHand",
		Vector3.new(0.98, 0.32, 1.03),
		"RightLowerArm",
		"RightWrist",
		Vector3.new(0, -0.532, 0),
		Vector3.new(0, 0.132, 0),
	},
	{
		"LeftUpperArm",
		Vector3.new(1, 1.24, 1),
		"UpperTorso",
		"LeftShoulder",
		Vector3.new(-0.972, 0.598, 0),
		Vector3.new(0.501, 0.419, 0),
	},
	{
		"LeftLowerArm",
		Vector3.new(1, 1.12, 1),
		"LeftUpperArm",
		"LeftElbow",
		Vector3.new(0, -0.355, 0),
		Vector3.new(0, 0.275, 0),
	},
	{
		"LeftHand",
		Vector3.new(0.98, 0.32, 1.03),
		"LeftLowerArm",
		"LeftWrist",
		Vector3.new(0, -0.532, 0),
		Vector3.new(0, 0.132, 0),
	},
	{
		"RightUpperLeg",
		Vector3.new(0.99, 1.36, 0.97),
		"LowerTorso",
		"RightHip",
		Vector3.new(0.5, -0.2, 0),
		Vector3.new(0, 0.471, 0),
	},
	{
		"RightLowerLeg",
		Vector3.new(0.99, 1.3, 0.97),
		"RightUpperLeg",
		"RightKnee",
		Vector3.new(0, -0.449, 0),
		Vector3.new(0, 0.413, 0),
	},
	{
		"RightFoot",
		Vector3.new(1.01, 0.31, 1),
		"RightLowerLeg",
		"RightAnkle",
		Vector3.new(0, -0.596, 0),
		Vector3.new(0, 0.106, 0),
	},
	{
		"LeftUpperLeg",
		Vector3.new(0.99, 1.36, 0.97),
		"LowerTorso",
		"LeftHip",
		Vector3.new(-0.5, -0.2, 0),
		Vector3.new(0, 0.471, 0),
	},
	{
		"LeftLowerLeg",
		Vector3.new(0.99, 1.3, 0.97),
		"LeftUpperLeg",
		"LeftKnee",
		Vector3.new(0, -0.449, 0),
		Vector3.new(0, 0.413, 0),
	},
	{
		"LeftFoot",
		Vector3.new(1.01, 0.31, 1),
		"LeftLowerLeg",
		"LeftAnkle",
		Vector3.new(0, -0.596, 0),
		Vector3.new(0, 0.106, 0),
	},
}

local HIP_HEIGHT = 2.19

export type Look = {
	skin: Color3?,
	outfit: Color3?,
	pants: Color3?,
	hair: Color3?,
	mask: boolean?,
	partialMask: boolean?,
	maskColor: Color3?,
	eye: Color3?,
	hole: boolean?,
	stripes: Color3?,
	longNose: boolean?,
	mane: Color3?,
}

local function part(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = true
	p.CanTouch = false
	p.Massless = false
	p.Parent = parent
	return p
end

-- Anexa uma peça decorativa soldada a `base` com deslocamento local.
function RigBuilder.decorate(
	base: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.CFrame = base.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = base
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	p.Parent = base
	return p
end

function RigBuilder.build(name: string, look: Look, scale: number?): Model
	local s = scale or 1
	local skin = look.skin or Color3.fromRGB(230, 200, 170)
	local outfit = look.outfit or skin
	local pants = look.pants or outfit

	local model = Instance.new("Model")
	model.Name = name

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1) * s, skin, model)
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = false
	model.PrimaryPart = root

	local parts: { [string]: BasePart } = { HumanoidRootPart = root }
	for _, info in PARTS do
		local partName, size, parentName, jointName, c0, c1 = info[1], info[2], info[3], info[4], info[5], info[6]
		local color = skin
		if partName:find("Torso") or partName:find("UpperArm") then
			color = outfit
		elseif partName:find("Leg") or partName:find("Foot") then
			color = pants
		end
		local p = part(partName, size * s, color, model)
		parts[partName] = p
		local motor = Instance.new("Motor6D")
		motor.Name = jointName
		motor.Part0 = parts[parentName]
		motor.Part1 = p
		motor.C0 = CFrame.new(c0 * s)
		motor.C1 = CFrame.new(c1 * s)
		motor.Parent = p
		p.CFrame = parts[parentName].CFrame * motor.C0 * motor.C1:Inverse()
	end
	-- Pernas e tronco colidem para que o NPC não atravesse paredes
	parts.UpperTorso.CanCollide = true
	parts.LowerTorso.CanCollide = true

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = HIP_HEIGHT * s
	humanoid.AutomaticScalingEnabled = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	humanoid.Parent = model

	-- Rosto
	local head = parts.Head
	local eyeColor = look.eye or Color3.fromRGB(20, 20, 20)
	local eyeMaterial = if look.eye then Enum.Material.Neon else Enum.Material.SmoothPlastic
	if look.mask then
		local maskColor = look.maskColor or Color3.fromRGB(240, 236, 225)
		if look.partialMask then
			RigBuilder.decorate(
				head,
				"MaskFragment",
				Vector3.new(0.7, 0.5, 0.2) * s,
				CFrame.new(0.3 * s, 0.25 * s, -0.6 * s),
				maskColor
			)
			RigBuilder.decorate(
				head,
				"Jaw",
				Vector3.new(1.0, 0.25, 0.25) * s,
				CFrame.new(0, -0.45 * s, -0.55 * s),
				maskColor
			)
		else
			RigBuilder.decorate(head, "Mask", Vector3.new(1.3, 1.25, 0.25) * s, CFrame.new(0, 0, -0.6 * s), maskColor)
			if look.longNose then
				RigBuilder.decorate(
					head,
					"Nose",
					Vector3.new(0.35, 0.35, 1.4) * s,
					CFrame.new(0, -0.1 * s, -1.3 * s),
					maskColor
				)
			end
			if look.stripes then
				for i = -1, 1, 2 do
					RigBuilder.decorate(
						head,
						"Stripe",
						Vector3.new(0.12, 1.0, 0.05) * s,
						CFrame.new(0.35 * i * s, 0, -0.74 * s),
						look.stripes,
						Enum.Material.Neon
					)
				end
			end
			RigBuilder.decorate(
				head,
				"Teeth",
				Vector3.new(0.9, 0.15, 0.05) * s,
				CFrame.new(0, -0.38 * s, -0.74 * s),
				Color3.fromRGB(30, 30, 30)
			)
		end
	end
	for i = -1, 1, 2 do
		RigBuilder.decorate(
			head,
			"Eye",
			Vector3.new(0.22, 0.14, 0.05) * s,
			CFrame.new(0.25 * i * s, 0.12 * s, -0.76 * s),
			eyeColor,
			eyeMaterial
		)
	end
	if look.hair then
		RigBuilder.decorate(head, "Hair", Vector3.new(1.3, 0.45, 1.3) * s, CFrame.new(0, 0.5 * s, 0.05 * s), look.hair)
		RigBuilder.decorate(
			head,
			"HairBack",
			Vector3.new(1.3, 0.9, 0.3) * s,
			CFrame.new(0, 0.1 * s, 0.55 * s),
			look.hair
		)
	end
	if look.mane then
		RigBuilder.decorate(head, "Mane", Vector3.new(2.2, 2.0, 1.0) * s, CFrame.new(0, 0.1 * s, 0.55 * s), look.mane)
	end
	if look.hole then
		RigBuilder.decorate(
			parts.UpperTorso,
			"HollowHole",
			Vector3.new(0.12, 0.7, 0.7) * s,
			CFrame.new(0, 0.1 * s, -0.47 * s) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(5, 5, 8),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end

	model:SetAttribute("AnimScale", s)
	return model
end

RigBuilder.HipHeight = HIP_HEIGHT

local function transform(t: { number }, s: number): CFrame
	return CFrame.new(t[1] * s, t[2] * s, t[3] * s) * CFrame.Angles(math.rad(t[4]), math.rad(t[5]), math.rad(t[6]))
end

local function sphereMesh(p: BasePart)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
end

function RigBuilder.HasCreature(body: string?): boolean
	return body ~= nil and CreatureRigs[body] ~= nil
end

-- Monta uma criatura de CreatureRigs: peças orgânicas (esferas esticadas) presas por Motor6D com os
-- nomes do R15 (+ cauda), enfeites soldados por papel de cor (máscara, ossos, olhos, marcas) e o
-- HipHeight calculado pelo ponto mais baixo dos pés em repouso (pés no chão em qualquer escala).
-- O atributo AnimSet escolhe as animações da criatura; AnimScale escala as translações delas.
function RigBuilder.buildCreature(name: string, bodyName: string, look: Look, scale: number?): Model
	local body = CreatureRigs[bodyName]
	assert(body, "corpo de criatura desconhecido: " .. bodyName)
	local s = scale or 1
	local skin = look.skin or Color3.fromRGB(30, 28, 34)
	local maskColor = look.maskColor or Color3.fromRGB(240, 236, 225)
	local eye = look.eye or Color3.fromRGB(255, 60, 40)
	local palette: { [string]: Color3 } = {
		skin = skin,
		skin2 = skin:Lerp(Color3.new(0, 0, 0), 0.35),
		bone = maskColor:Lerp(Color3.fromRGB(150, 140, 125), 0.35),
		mask = maskColor,
		eye = eye,
		accent = look.stripes or eye,
		dark = Color3.fromRGB(6, 5, 9),
	}

	-- Cor de uma peça: explícita no corpo (`color` = {r, g, b}, para armaduras e tecidos com cor
	-- própria) ou pelo papel (pele, osso, máscara...), que o `look` do inimigo tinge
	local function colorOf(entry: any): Color3
		local c = entry.color
		if c then
			return Color3.fromRGB(c[1], c[2], c[3])
		end
		return palette[entry.role] or skin
	end

	local model = Instance.new("Model")
	model.Name = name
	local rootSize = body.root
	local root = part("HumanoidRootPart", Vector3.new(rootSize[1], rootSize[2], rootSize[3]) * s, skin, model)
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = false
	model.PrimaryPart = root

	local parts: { [string]: BasePart } = { HumanoidRootPart = root }
	local low = 0
	for _, info in body.parts do
		local size = Vector3.new(info.size[1], info.size[2], info.size[3]) * s
		local p = part(info.name, size, colorOf(info), model)
		p.Material = if info.material then (Enum.Material :: any)[info.material] else Enum.Material.Slate
		if info.mesh == "Sphere" then
			sphereMesh(p)
		end
		parts[info.name] = p
		local motor = Instance.new("Motor6D")
		motor.Name = info.joint
		motor.Part0 = parts[info.parent]
		motor.Part1 = p
		motor.C0 = transform(info.c0, s)
		motor.C1 = transform(info.c1, s)
		motor.Parent = p
		p.CFrame = parts[info.parent].CFrame * motor.C0 * motor.C1:Inverse()
		-- ponto mais baixo (cantos da caixa) em relação ao centro do HumanoidRootPart
		local half = size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = p.CFrame:PointToWorldSpace(half * Vector3.new(sx, sy, sz))
					low = math.min(low, root.CFrame:PointToObjectSpace(corner).Y)
				end
			end
		end
	end
	parts.UpperTorso.CanCollide = true
	parts.LowerTorso.CanCollide = true
	-- Ponto de empunhadura das garras (rastro da arma "Claws" sai da ponta das garras)
	for _, side in { "Right", "Left" } do
		local hand = parts[side .. "Hand"]
		if hand then
			local grip = Instance.new("Attachment")
			grip.Name = side .. "GripAttachment"
			grip.Position = Vector3.new(0, -0.12, -0.25) * s
			grip.Parent = hand
		end
	end

	for i, d in body.decor do
		local base = parts[d.part]
		if base then
			local material = if d.material
				then (Enum.Material :: any)[d.material]
				elseif d.role == "eye" or d.role == "accent" then Enum.Material.Neon
				elseif d.role == "bone" or d.role == "mask" then Enum.Material.SmoothPlastic
				else Enum.Material.Slate
			local shape = if d.shape == "Cylinder" then Enum.PartType.Cylinder else nil
			local size = Vector3.new(d.size[1], d.size[2], d.size[3]) * s
			local piece: BasePart
			if d.shape == "Wedge" then
				local w = Instance.new("WedgePart")
				w.Name = "Decor" .. i
				w.Size = size
				w.Color = colorOf(d)
				w.Material = material
				w.CanCollide = false
				w.CanQuery = false
				w.CanTouch = false
				w.Massless = true
				w.CastShadow = false
				w.CFrame = base.CFrame * transform(d.offset, s)
				local weld = Instance.new("Weld")
				weld.Part0 = base
				weld.Part1 = w
				weld.C0 = transform(d.offset, s)
				weld.Parent = w
				w.Parent = base
				piece = w
			else
				piece =
					RigBuilder.decorate(base, "Decor" .. i, size, transform(d.offset, s), colorOf(d), material, shape)
			end
			if d.mesh == "Sphere" then
				sphereMesh(piece)
			end
			if d.role == "eye" then
				piece.Name = "Eye"
			end
		end
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = -low - root.Size.Y / 2
	humanoid.AutomaticScalingEnabled = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	humanoid.Parent = model

	model:SetAttribute("AnimSet", body.animSet)
	model:SetAttribute("AnimScale", s)
	model:SetAttribute("Creature", bodyName)
	return model
end

return RigBuilder

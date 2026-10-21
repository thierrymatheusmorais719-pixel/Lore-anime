-- Constrói um rig R15 procedural (15 partes, Motor6D com nomes padrão) sem depender de assets.
-- Os nomes das juntas são os mesmos do R15 oficial, então as animações procedurais e
-- animações publicadas funcionam igualmente em NPCs e jogadores.
local RigBuilder = {}

-- name, size, parent part, joint name, C0 (no pai), C1 (na parte)
local PARTS = {
	{
		"LowerTorso",
		Vector3.new(2, 0.4, 1),
		"HumanoidRootPart",
		"Root",
		Vector3.new(0, -0.6, 0),
		Vector3.new(0, 0.2, 0),
	},
	{ "UpperTorso", Vector3.new(2, 1.6, 1), "LowerTorso", "Waist", Vector3.new(0, 0.2, 0), Vector3.new(0, -0.8, 0) },
	{ "Head", Vector3.new(1.2, 1.2, 1.2), "UpperTorso", "Neck", Vector3.new(0, 0.8, 0), Vector3.new(0, -0.6, 0) },
	{
		"RightUpperArm",
		Vector3.new(1, 1.2, 1),
		"UpperTorso",
		"RightShoulder",
		Vector3.new(1.5, 0.6, 0),
		Vector3.new(0, 0.4, 0),
	},
	{
		"RightLowerArm",
		Vector3.new(1, 1, 1),
		"RightUpperArm",
		"RightElbow",
		Vector3.new(0, -0.6, 0),
		Vector3.new(0, 0.5, 0),
	},
	{
		"RightHand",
		Vector3.new(1, 0.4, 1),
		"RightLowerArm",
		"RightWrist",
		Vector3.new(0, -0.5, 0),
		Vector3.new(0, 0.2, 0),
	},
	{
		"LeftUpperArm",
		Vector3.new(1, 1.2, 1),
		"UpperTorso",
		"LeftShoulder",
		Vector3.new(-1.5, 0.6, 0),
		Vector3.new(0, 0.4, 0),
	},
	{
		"LeftLowerArm",
		Vector3.new(1, 1, 1),
		"LeftUpperArm",
		"LeftElbow",
		Vector3.new(0, -0.6, 0),
		Vector3.new(0, 0.5, 0),
	},
	{
		"LeftHand",
		Vector3.new(1, 0.4, 1),
		"LeftLowerArm",
		"LeftWrist",
		Vector3.new(0, -0.5, 0),
		Vector3.new(0, 0.2, 0),
	},
	{
		"RightUpperLeg",
		Vector3.new(1, 1.2, 1),
		"LowerTorso",
		"RightHip",
		Vector3.new(0.5, -0.2, 0),
		Vector3.new(0, 0.6, 0),
	},
	{
		"RightLowerLeg",
		Vector3.new(1, 1, 1),
		"RightUpperLeg",
		"RightKnee",
		Vector3.new(0, -0.6, 0),
		Vector3.new(0, 0.5, 0),
	},
	{
		"RightFoot",
		Vector3.new(1, 0.3, 1),
		"RightLowerLeg",
		"RightAnkle",
		Vector3.new(0, -0.5, 0),
		Vector3.new(0, 0.15, 0),
	},
	{
		"LeftUpperLeg",
		Vector3.new(1, 1.2, 1),
		"LowerTorso",
		"LeftHip",
		Vector3.new(-0.5, -0.2, 0),
		Vector3.new(0, 0.6, 0),
	},
	{
		"LeftLowerLeg",
		Vector3.new(1, 1, 1),
		"LeftUpperLeg",
		"LeftKnee",
		Vector3.new(0, -0.6, 0),
		Vector3.new(0, 0.5, 0),
	},
	{
		"LeftFoot",
		Vector3.new(1, 0.3, 1),
		"LeftLowerLeg",
		"LeftAnkle",
		Vector3.new(0, -0.5, 0),
		Vector3.new(0, 0.15, 0),
	},
}

local HIP_HEIGHT = 2.5

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

	return model
end

RigBuilder.HipHeight = HIP_HEIGHT

return RigBuilder

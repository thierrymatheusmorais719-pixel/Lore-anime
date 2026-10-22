-- Personagem 3D posado de cada facção para os cartões da tela de seleção (estilo "arte de time").
-- Monta o rig com os mesmos construtores do servidor, aplica uma pose heroica resolvendo a
-- cadeia de juntas manualmente (funciona em ViewportFrame sem física) e exibe com câmera própria.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Elements = require(Shared.Config.Elements)
local RigBuilder = require(Shared.Builders.RigBuilder)
local WeaponBuilder = require(Shared.Builders.WeaponBuilder)
local OutfitBuilder = require(Shared.Builders.OutfitBuilder)

local FactionShowcase = {}

local rad = math.rad
local function J(p: number?, y: number?, r: number?): CFrame
	return CFrame.fromEulerAnglesYXZ(rad(p or 0), rad(y or 0), rad(r or 0))
end

local LOOKS = {
	Shinigami = {
		look = {
			skin = Color3.fromRGB(236, 205, 175),
			outfit = Color3.fromRGB(18, 18, 22),
			pants = Color3.fromRGB(18, 18, 22),
			hair = Color3.fromRGB(255, 120, 40),
		},
		outfit = {
			trim = Color3.fromRGB(235, 235, 240),
			robe = Color3.fromRGB(18, 18, 22),
			coat = Color3.fromRGB(240, 240, 245),
		},
		weapon = { style = "Katana", length = 5, blade = Color3.fromRGB(215, 225, 240), glow = true },
		element = "Reiatsu",
		pose = {
			RightShoulder = J(105, 25, 15),
			RightElbow = J(25),
			RightWrist = J(-55),
			LeftShoulder = J(25, -15, -25),
			LeftElbow = J(45),
			Waist = J(-5, -25),
			Neck = J(0, 20),
			RightHip = J(25, 0, 8),
			RightKnee = J(-30),
			LeftHip = J(-15, 0, -10),
			LeftKnee = J(-20),
			Root = CFrame.new(0, -0.3, 0),
		},
	},
	Quincy = {
		look = {
			skin = Color3.fromRGB(240, 220, 200),
			outfit = Color3.fromRGB(240, 242, 248),
			pants = Color3.fromRGB(235, 238, 245),
			hair = Color3.fromRGB(30, 35, 60),
		},
		outfit = { trim = Color3.fromRGB(60, 110, 200), robe = Color3.fromRGB(240, 242, 248), cape = true },
		weapon = { style = "LightBlade", length = 3.6, blade = Color3.fromRGB(170, 220, 255), glow = true },
		element = "Holy",
		bow = true,
		pose = {
			LeftShoulder = J(90, 15, 0),
			LeftElbow = J(0),
			RightShoulder = J(85, -85, 0),
			RightElbow = J(115),
			Waist = J(0, 45),
			Neck = J(0, -40),
			RightHip = J(-10, 0, 10),
			RightKnee = J(-15),
			LeftHip = J(20, 0, -6),
			LeftKnee = J(-20),
		},
	},
	Hollow = {
		look = {
			skin = Color3.fromRGB(30, 28, 34),
			mask = true,
			hole = true,
			maskColor = Color3.fromRGB(240, 236, 225),
			eye = Color3.fromRGB(255, 60, 40),
		},
		outfit = nil,
		weapon = { style = "Claws", length = 3.2, blade = Color3.fromRGB(235, 230, 220), glow = false },
		element = "Hollow",
		dual = true,
		pose = {
			RightShoulder = J(60, -20, 50),
			RightElbow = J(40),
			LeftShoulder = J(60, 20, -50),
			LeftElbow = J(40),
			Waist = J(-30),
			Neck = J(25),
			RightHip = J(45, 0, 15),
			RightKnee = J(-70),
			LeftHip = J(30, 0, -15),
			LeftKnee = J(-60),
			Root = CFrame.new(0, -0.9, 0),
		},
	},
	Fullbringer = {
		look = {
			skin = Color3.fromRGB(225, 190, 160),
			outfit = Color3.fromRGB(45, 50, 60),
			pants = Color3.fromRGB(30, 32, 40),
			hair = Color3.fromRGB(150, 60, 40),
		},
		outfit = { trim = Color3.fromRGB(110, 255, 170), robe = Color3.fromRGB(45, 50, 60) },
		weapon = {
			style = "Gauntlet",
			length = 2,
			blade = Color3.fromRGB(70, 75, 85),
			guard = Color3.fromRGB(110, 255, 170),
			glow = true,
		},
		element = "Verdant",
		dual = true,
		pose = {
			RightShoulder = J(90, 5, 0),
			RightElbow = J(0),
			LeftShoulder = J(35, -20, -20),
			LeftElbow = J(100),
			Waist = J(-8, 30),
			Neck = J(0, -20),
			RightHip = J(-20, 0, 6),
			RightKnee = J(-20),
			LeftHip = J(40, 0, -6),
			LeftKnee = J(-35),
			Root = CFrame.new(0, -0.5, -0.3),
		},
	},
}

-- Resolve CFrames a partir da raiz seguindo Motor6D/Weld (C0/C1) e WeldConstraint (offset gravado).
local function solve(model: Model, pose: { [string]: CFrame })
	local root = model.PrimaryPart :: BasePart
	type Edge = { child: BasePart, fn: (CFrame) -> CFrame }
	local edges: { [BasePart]: { Edge } } = {}
	local function add(parent: BasePart, child: BasePart, fn: (CFrame) -> CFrame)
		edges[parent] = edges[parent] or {}
		table.insert(edges[parent], { child = child, fn = fn })
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("Weld") then
			local joint = d :: any
			local p0, p1 = joint.Part0 :: BasePart?, joint.Part1 :: BasePart?
			if p0 and p1 and joint.Enabled ~= false then
				local c0 = joint.C0 * (if d:IsA("Motor6D") then (pose[d.Name] or CFrame.identity) else CFrame.identity)
				local c1inv = joint.C1:Inverse()
				add(p0, p1, function(cf: CFrame)
					return cf * c0 * c1inv
				end)
			end
		elseif d:IsA("WeldConstraint") then
			local p0, p1 = d.Part0, d.Part1
			if p0 and p1 then
				local rel = p0.CFrame:ToObjectSpace(p1.CFrame)
				add(p0, p1, function(cf: CFrame)
					return cf * rel
				end)
			end
		end
	end
	local visited: { [BasePart]: boolean } = { [root] = true }
	local queue = { root }
	while #queue > 0 do
		local parent = table.remove(queue, 1) :: BasePart
		local children: { Edge } = edges[parent] or {}
		for _, e in children do
			if not visited[e.child] then
				visited[e.child] = true
				e.child.CFrame = e.fn(parent.CFrame)
				table.insert(queue, e.child)
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

local function addBow(model: Model, color: Color3)
	local hand = model:FindFirstChild("LeftHand") :: BasePart?
	if not hand then
		return
	end
	local segments = 9
	for i = 1, segments do
		local a = rad(-70 + 140 * (i - 0.5) / segments)
		local p = Instance.new("Part")
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = Vector3.new(0.18, 0.7, 0.18)
		p.CanCollide = false
		p.Anchored = true
		p.CFrame = hand.CFrame
			* CFrame.new(0, -0.1, -0.6)
			* CFrame.Angles(0, 0, 0)
			* CFrame.new(0, math.sin(a) * 2.4, -math.cos(a) * 0.9)
			* CFrame.Angles(a, 0, 0)
		p.Parent = model
	end
	local string_ = Instance.new("Part")
	string_.Material = Enum.Material.Neon
	string_.Color = Color3.new(1, 1, 1)
	string_.Size = Vector3.new(0.05, 4.4, 0.05)
	string_.Anchored = true
	string_.CanCollide = false
	string_.CFrame = hand.CFrame * CFrame.new(0, -0.1, 0.4)
	string_.Parent = model
	local arrow = Instance.new("Part")
	arrow.Material = Enum.Material.Neon
	arrow.Color = color
	arrow.Size = Vector3.new(0.12, 0.12, 4)
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CFrame = hand.CFrame * CFrame.new(0, -0.1, -1.2)
	arrow.Parent = model
end

-- Cria o modelo posado da facção (fora de qualquer pai).
function FactionShowcase.Build(factionId: string): Model?
	local def = LOOKS[factionId]
	if not def then
		return nil
	end
	local model = RigBuilder.build("Showcase_" .. factionId, def.look, 1)
	model:PivotTo(CFrame.new(0, 3.5, 0))
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	if def.outfit then
		OutfitBuilder.apply(model, def.outfit)
	end
	local weapon = WeaponBuilder.buildModel(def.weapon, def.element)
	WeaponBuilder.attach(model, weapon, "RightHand")
	if def.dual then
		local left = WeaponBuilder.buildModel(def.weapon, def.element)
		WeaponBuilder.attach(model, left, "LeftHand")
	end
	solve(model, def.pose)
	if def.bow then
		addBow(model, Elements[def.element].primary)
	end
	-- Aura leve
	local root = model.PrimaryPart
	if root then
		local light = Instance.new("PointLight")
		light.Color = Elements[def.element].primary
		light.Range = 12
		light.Parent = root
	end
	return model
end

-- Monta ViewportFrame com o personagem, luz da facção e uma leve oscilação.
function FactionShowcase.Viewport(factionId: string, accent: Color3): (ViewportFrame, (number) -> ())
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(120, 120, 135)
	viewport.LightColor = accent:Lerp(Color3.new(1, 1, 1), 0.55)
	viewport.LightDirection = Vector3.new(-0.6, -1, -0.8)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local model = FactionShowcase.Build(factionId)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local base = CFrame.new(0, 0, 0)
	if model then
		model.Parent = world
		base = model:GetPivot()
	end
	local target = Vector3.new(0, 3.2, 0)
	local angle = 0
	local function update(dt: number)
		angle += dt
		if model then
			model:PivotTo(base * CFrame.Angles(0, math.rad(18 + math.sin(angle * 0.8) * 14), 0))
		end
		camera.CFrame = CFrame.lookAt(target + Vector3.new(0, 0.6, -16.5), target)
	end
	update(0)
	return viewport, update
end

return FactionShowcase

-- Cenário: personagem R15 do jogador local, Animate do projeto (atributo OwnLocomotion) que o
-- ApplyDescription encheu de valores; parado, andando (18), correndo (27), espada sacada.
local function part(name, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.CFrame = CFrame.new(0, 3, 0)
	p.Position = Vector3.new(0, 3, 0)
	p.Parent = parent
	return p
end
local character = Instance.new("Model")
character.Name = "Tester"
local hrp = part("HumanoidRootPart", character)
hrp.AssemblyLinearVelocity = Vector3.zero
hrp.AssemblyAngularVelocity = Vector3.zero
hrp.Size = Vector3.new(2, 2, 1)
local humanoid = Instance.new("Humanoid")
humanoid.FloorMaterial = Enum.Material.Plastic
humanoid.Health = 100
humanoid.HipHeight = 2
humanoid.RigType = Enum.HumanoidRigType.R15
humanoid.Parent = character
Instance.new("Animator").Parent = humanoid
local JOINTS = {
	{ "LowerTorso", "Root" }, { "UpperTorso", "Waist" }, { "Head", "Neck" },
	{ "RightUpperArm", "RightShoulder" }, { "RightLowerArm", "RightElbow" }, { "RightHand", "RightWrist" },
	{ "LeftUpperArm", "LeftShoulder" }, { "LeftLowerArm", "LeftElbow" }, { "LeftHand", "LeftWrist" },
	{ "RightUpperLeg", "RightHip" }, { "RightLowerLeg", "RightKnee" }, { "RightFoot", "RightAnkle" },
	{ "LeftUpperLeg", "LeftHip" }, { "LeftLowerLeg", "LeftKnee" }, { "LeftFoot", "LeftAnkle" },
}
-- SIM_JOINT: "Motor6D" (padrão) ou "AnimationConstraint" (atualização de juntas do Roblox)
local motors = {}
for _, j in JOINTS do
	local p = part(j[1], character)
	local m = Instance.new(SIM_JOINT or "Motor6D")
	m.Name = j[2]
	m.Transform = CFrame.identity
	m.Parent = p
	motors[j[2]] = m
end
local animate = Instance.new("LocalScript")
animate.Name = "Animate"
animate:SetAttribute("OwnLocomotion", true)
animate.Parent = character
-- o que o ApplyDescription costuma criar
for _, n in { "idle", "walk", "run", "jump", "fall" } do
	local v = Instance.new("StringValue")
	v.Name = n
	v.Parent = animate
end
local player = SERVICES.Players.LocalPlayer
player.Character = character
character:SetAttribute("Team", "Players")
character.Parent = workspace

local AnimController = MODULE("Client/Controllers/AnimController")
AnimController.Init()
AnimController.Start()

local function angleOf(cf)
	local r = cf.r
	return math.deg(math.acos(math.clamp((r[1] + r[5] + r[9] - 1) / 2, -1, 1)))
end
local function run(label, seconds, velocity, check)
	hrp.AssemblyLinearVelocity = velocity
	local frames = math.floor(seconds * 60)
	local seen = {}
	for _ = 1, frames do
		CLOCK += 1 / 60
		RUN_QUEUE()
		SERVICES.RunService.Stepped:Fire(CLOCK, 1 / 60)
		for name, m in motors do
			local a = angleOf(m.Transform)
			seen[name] = seen[name] or { min = math.huge, max = -math.huge }
			seen[name].min = math.min(seen[name].min, a)
			seen[name].max = math.max(seen[name].max, a)
		end
	end
	local moving = 0
	local line = {}
	for _, j in JOINTS do
		local s = seen[j[2]]
		local range = s.max - s.min
		if range > 1 then
			moving += 1
		end
		table.insert(line, string.format("%s %.0f°", j[2], range))
	end
	local ok = moving >= check
	print(string.format("%-5s %-22s juntas se mexendo: %d/%d", if ok then "ok" else "FALHA", label, moving, #JOINTS))
	print("      " .. table.concat(line, ", "))
end
run("parado", 4, Vector3.zero, 6)
run("andando (18)", 2, Vector3.new(0, 0, -18), 10)
run("correndo (27)", 2, Vector3.new(0, 0, -27), 10)
character:SetAttribute("Drawn", true)
run("espada sacada parado", 3, Vector3.zero, 6)
run("espada sacada andando", 2, Vector3.new(0, 0, -18), 10)

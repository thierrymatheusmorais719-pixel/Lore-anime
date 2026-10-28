--!strict
-- Arena procedural inspirada no cânion árido do vídeo: chão claro limpo no centro (para destacar a
-- transformação), muralhas de mesa ao redor com profundidade, rochas reativas e bonecos de treino.
-- Peças reativas recebem a tag "MugetsuReactive" (o cliente as faz tremer localmente).

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Mugetsu"):WaitForChild("Config"))

local ArenaBuilder = {}

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeDummy(parent: Instance, cf: CFrame, index: number): Model
	local m = Instance.new("Model")
	m.Name = `Dummy{index}`
	local hrp = block(m, "HumanoidRootPart", Vector3.new(2, 2, 1), cf, Color3.fromRGB(80, 80, 85), Enum.Material.SmoothPlastic)
	local torso = block(m, "Torso", Vector3.new(2, 2, 1), cf, Color3.fromRGB(110, 110, 118), Enum.Material.SmoothPlastic)
	local head = block(m, "Head", Vector3.new(1.4, 1.2, 1.2), cf * CFrame.new(0, 1.7, 0), Color3.fromRGB(170, 170, 176), Enum.Material.SmoothPlastic)
	hrp.Transparency = 1
	torso.CFrame = cf
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 200
	hum.Health = 200
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = m
	m.PrimaryPart = hrp
	m.Parent = parent
	CollectionService:AddTag(m, "MugetsuTarget")
	return m
end

function ArenaBuilder.build(): Folder
	local existing = Workspace:FindFirstChild("MugetsuArena")
	if existing then
		return existing :: Folder -- nunca sobrescreve
	end
	local arena = Instance.new("Folder")
	arena.Name = "MugetsuArena"
	local o = Config.Arena.Origin
	local R = Config.Arena.Radius

	-- chão: disco claro + anel escuro
	local floor = block(arena, "Floor", Vector3.new(R * 2, 4, R * 2), CFrame.new(o + Vector3.new(0, -2, 0)), Color3.fromRGB(176, 160, 130), Enum.Material.Sand)
	floor.Shape = Enum.PartType.Cylinder
	floor.CFrame = CFrame.new(o + Vector3.new(0, -2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	floor.Size = Vector3.new(4, R * 2, R * 2)
	local inner = block(arena, "InnerPlate", Vector3.new(0.4, 80, 80), CFrame.new(o + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(196, 184, 160), Enum.Material.Slate)
	inner.Shape = Enum.PartType.Cylinder

	-- muralha de mesas (camadas para profundidade)
	local rng = Random.new(1337)
	for i = 1, Config.Arena.Pillars do
		local a = (i / Config.Arena.Pillars) * math.pi * 2
		local dist = R - 6 + rng:NextNumber(-4, 8)
		local h = rng:NextNumber(40, 85)
		local w = rng:NextNumber(34, 56)
		local pos = o + Vector3.new(math.cos(a) * dist, h / 2 - 2, math.sin(a) * dist)
		local cf = CFrame.lookAt(pos, o + Vector3.new(0, pos.Y, 0))
		local wall = block(arena, "Mesa", Vector3.new(w, h, rng:NextNumber(18, 30)), cf, Color3.fromRGB(150, 128, 92), Enum.Material.Sandstone)
		wall:SetAttribute("ReactAmp", rng:NextNumber(0.4, 0.9))
		CollectionService:AddTag(wall, "MugetsuReactive")
		-- estratos
		for k = 1, 3 do
			local strip = block(arena, "Strata", Vector3.new(w + 0.4, 1.2, wall.Size.Z + 0.4), cf * CFrame.new(0, -h / 2 + k * (h / 4), 0), Color3.fromRGB(120, 100, 74), Enum.Material.Rock)
			strip.CanCollide = false
		end
	end

	-- rochas reativas ao redor da área limpa
	for i = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(46, 110)
		local s = rng:NextNumber(3, 9)
		local rock = block(arena, "Rock", Vector3.new(s, s * 0.8, s * 1.1), CFrame.new(o + Vector3.new(math.cos(a) * d, s * 0.3, math.sin(a) * d)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), rng:NextNumber(0, 1)), Color3.fromRGB(128, 112, 90), Enum.Material.Rock)
		rock:SetAttribute("ReactAmp", 1)
		CollectionService:AddTag(rock, "MugetsuReactive")
	end

	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MugetsuSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = o + Vector3.new(0, 0.5, 30)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Parent = arena

	-- bonecos de treino para testar o dano (respawn automático)
	local dummies = Instance.new("Folder")
	dummies.Name = "Dummies"
	dummies.Parent = arena
	for i = 1, 5 do
		local pos = o + Vector3.new(-40 + (i - 1) * 20, 3, -55)
		local cf = CFrame.new(pos)
		local d = makeDummy(dummies, cf, i)
		local function watch(model: Model)
			local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
			hum.Died:Once(function()
				task.delay(3, function()
					model:Destroy()
					watch(makeDummy(dummies, cf, i))
				end)
			end)
		end
		watch(d)
	end

	arena.Parent = Workspace
	return arena
end

return ArenaBuilder

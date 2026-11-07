-- Céu anime 2D no cliente (ver Shared/Builders/AnimeSky): monta o céu do mundo atual, mantém-no
-- centrado na câmera (parece infinitamente distante), faz as nuvens derivarem devagar, posiciona
-- o sol/lua 2D na direção real do sol do Roblox e faz as estrelas cintilarem.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AnimeSky = require(Shared.Builders.AnimeSky)
local Fx = require(script.Parent.Fx)

local SkyClient = {}

local player = Players.LocalPlayer
local anchor: BasePart
local folder: Folder
local handle = nil
local drift = 0

local DRIFT_DEG_PER_SEC = 0.12

-- Raios das nuvens de tempestade (Storm Islands e Tempest Arena): de tempos em tempos um raio cai
-- de uma nuvem perto da câmera até o chão (raycast) ou até 90 studs abaixo dela.
local stormSources: { BasePart } = {}
local nextStrike = 0

local function scanStorm(worldId: string)
	stormSources = {}
	local wf = workspace:FindFirstChild("World")
	local f = wf and wf:FindFirstChild(worldId)
	if not f then
		return
	end
	for _, d in ipairs(f:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("LightningSource") then
			table.insert(stormSources, d)
		end
	end
end

local function stormTick()
	if #stormSources == 0 or os.clock() < nextStrike then
		return
	end
	nextStrike = os.clock() + 2.5 + math.random() * 4
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local near = {}
	for _, s in ipairs(stormSources) do
		if (s.Position - cam.CFrame.Position).Magnitude < 650 then
			table.insert(near, s)
		end
	end
	if #near == 0 then
		return
	end
	local src = near[math.random(1, #near)]
	local from = src.Position + Vector3.new(math.random(-20, 20), -4, math.random(-20, 20))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace.CurrentCamera }
	local hit = workspace:Raycast(from, Vector3.new(0, -140, 0), params)
	Fx.lightning(from, hit and hit.Position or (from - Vector3.new(0, 90, 0)), Color3.fromRGB(170, 230, 255), 0.9)
end

local function rebuild(worldId: string)
	for _, c in ipairs(folder:GetChildren()) do
		c:Destroy()
	end
	handle = AnimeSky.build(folder, anchor, worldId)
	SkyClient.current = worldId
	scanStorm(worldId)
end

local function celestialDir(): Vector3?
	local t = handle and AnimeSky.theme(handle.worldId)
	local ok, dir = pcall(function()
		if t and t.moon then
			return Lighting:GetMoonDirection()
		end
		return Lighting:GetSunDirection()
	end)
	if ok and typeof(dir) == "Vector3" then
		return dir
	end
	return nil
end

local function updateOffsets(dt: number)
	if not handle then
		return
	end
	drift = (drift + dt * DRIFT_DEG_PER_SEC) % 360
	for _, c in ipairs(handle.clouds) do
		c.gui.StudsOffsetWorldSpace = AnimeSky.offset(c.data.az + drift, c.data.elev, c.data.dist)
	end
	for _, s in ipairs(handle.streaks) do
		s.gui.StudsOffsetWorldSpace = AnimeSky.offset(s.data.az + drift * 0.5, s.data.elev, s.data.dist)
	end
	local tw = os.clock()
	for _, s in ipairs(handle.stars) do
		s.frame.BackgroundTransparency = 0.15 + 0.5 * (0.5 + 0.5 * math.sin(tw * (1.2 + s.data.twinkle * 2) + s.data.twinkle * 10))
	end
	local dir = celestialDir()
	if dir and handle.sun then
		handle.sun.Enabled = dir.Y > -0.08
		handle.sun.StudsOffsetWorldSpace = dir.Unit * AnimeSky.SUN_DIST
	end
end

function SkyClient.init()
	-- o sol e a lua são desenhados em 2D: esconde os do Roblox para não aparecerem dois
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.CelestialBodiesShown = false
	end
	anchor = Instance.new("Part")
	anchor.Name = "AnimeSkyAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Parent = workspace.CurrentCamera
	folder = Instance.new("Folder")
	folder.Name = "AnimeSky"
	folder.Parent = player:WaitForChild("PlayerGui")
	rebuild(player:GetAttribute("World") or "verdant")
	player:GetAttributeChangedSignal("World"):Connect(function()
		local w = player:GetAttribute("World")
		if w and w ~= SkyClient.current then
			rebuild(w)
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if cam then
			anchor.CFrame = CFrame.new(cam.CFrame.Position)
		end
		acc += dt
		if acc >= 0.1 then
			updateOffsets(acc)
			stormTick()
			acc = 0
		end
	end)
end

SkyClient.rebuild = rebuild
SkyClient.stormSources = function()
	return stormSources
end
return SkyClient

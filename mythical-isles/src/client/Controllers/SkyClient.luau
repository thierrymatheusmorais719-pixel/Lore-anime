-- Céu anime 2D no cliente (ver Shared/Builders/AnimeSky): monta o céu do mundo atual, mantém-no
-- centrado na câmera (parece infinitamente distante), faz as nuvens derivarem devagar, posiciona
-- o sol/lua 2D na direção real do sol do Roblox e faz as estrelas cintilarem.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AnimeSky = require(Shared.Builders.AnimeSky)

local SkyClient = {}

local player = Players.LocalPlayer
local anchor: BasePart
local folder: Folder
local handle = nil
local drift = 0

local DRIFT_DEG_PER_SEC = 0.12

local function rebuild(worldId: string)
	for _, c in ipairs(folder:GetChildren()) do
		c:Destroy()
	end
	handle = AnimeSky.build(folder, anchor, worldId)
	SkyClient.current = worldId
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
		handle.sun.StudsOffsetWorldSpace = dir.Unit * (AnimeSky.PANEL_DIST - 40)
	end
end

function SkyClient.init()
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
			acc = 0
		end
	end)
end

SkyClient.rebuild = rebuild
return SkyClient

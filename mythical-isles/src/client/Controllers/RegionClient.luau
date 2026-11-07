-- Regiões no cliente: mostra o nome da região ao entrar (ex.: "Azure Caverns — Cavernas Azuis"),
-- ajusta luz/névoa da região (via WorldClient) e toca o som ambiente configurado em Regions.Sounds
-- (vazio = sem som; o projeto não inventa IDs de áudio).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Regions = require(Shared.Config.Regions)
local UIKit = require(script.Parent.UIKit)
local WorldClient = require(script.Parent.WorldClient)

local RegionClient = {}

local player = Players.LocalPlayer
local current: string? = nil
local banner, title, subtitle
local sounds: { [string]: Sound } = {}

local function soundFor(key: string?): Sound?
	if not key then
		return nil
	end
	local id = Regions.Sounds[key]
	if not id or id == "" then
		return nil
	end
	local snd = sounds[key]
	if not snd then
		snd = Instance.new("Sound")
		snd.Name = "Ambient_" .. key
		snd.SoundId = id
		snd.Looped = true
		snd.Volume = 0
		snd.Parent = SoundService
		sounds[key] = snd
	end
	return snd
end

local function showBanner(info)
	title.Text = info.name
	subtitle.Text = info.subtitle
	banner.Visible = true
	banner.GroupTransparency = 1
	TweenService:Create(banner, TweenInfo.new(0.6), { GroupTransparency = 0 }):Play()
	task.delay(3.2, function()
		if title.Text == info.name then
			TweenService:Create(banner, TweenInfo.new(0.8), { GroupTransparency = 1 }):Play()
		end
	end)
end

local function enter(regionId: string?)
	if regionId == current then
		return
	end
	local old = current and Regions.Info[current]
	current = regionId
	local info = regionId and Regions.Info[regionId]
	-- som: some o antigo, entra o novo
	local oldSnd = old and soundFor(old.sound)
	if oldSnd then
		TweenService:Create(oldSnd, TweenInfo.new(1.5), { Volume = 0 }):Play()
	end
	local newSnd = info and soundFor(info.sound)
	if newSnd then
		if not newSnd.IsPlaying then
			newSnd:Play()
		end
		TweenService:Create(newSnd, TweenInfo.new(1.5), { Volume = 0.45 }):Play()
	end
	WorldClient.setRegionProfile(info and next(info.profile) ~= nil and info.profile or nil)
	if info then
		showBanner(info)
	end
end

function RegionClient.init()
	local pg = player:WaitForChild("PlayerGui")
	local gui = UIKit.new("ScreenGui", { Name = "RegionBanner", ResetOnSpawn = false, DisplayOrder = 12, IgnoreGuiInset = true, Parent = pg })
	banner = UIKit.new("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.16, 0), Size = UDim2.fromOffset(560, 92), BackgroundTransparency = 1,
		Visible = false, Parent = gui })
	title = UIKit.label({ Size = UDim2.new(1, 0, 0, 56), Text = "", Font = UIKit.Theme.title, TextSize = 46, TextColor3 = Color3.fromRGB(220, 236, 255),
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, Parent = banner })
	subtitle = UIKit.label({ Position = UDim2.new(0, 0, 0, 56), Size = UDim2.new(1, 0, 0, 30), Text = "", Font = UIKit.Theme.bold, TextSize = 22,
		TextColor3 = Color3.fromRGB(190, 170, 255), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, Parent = banner })
	task.spawn(function()
		while true do
			task.wait(0.4)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				enter(Regions.at(player:GetAttribute("World"), (root :: BasePart).Position))
			end
		end
	end)
end

RegionClient.enter = enter
return RegionClient

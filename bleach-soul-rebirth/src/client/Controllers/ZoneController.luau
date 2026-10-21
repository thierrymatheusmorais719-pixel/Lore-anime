-- Iluminação e atmosfera por região (transição suave) + cartão de título ao entrar.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Kit = require(script.Parent.Parent.UI.Kit)

local ZoneController = {}

local player = Players.LocalPlayer
local atmosphere: Atmosphere
local correction: ColorCorrectionEffect
local bloom: BloomEffect
local titleGui: ScreenGui
local current: string? = nil

local function tween(instance: Instance, props: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(2.5, Enum.EasingStyle.Sine), props):Play()
end

local function showTitle(zone)
	local holder = titleGui:FindFirstChild("Title") :: Frame
	local kanji = holder:FindFirstChild("Kanji") :: TextLabel
	local name = holder:FindFirstChild("Name") :: TextLabel
	kanji.Text = zone.kanji
	name.Text = zone.name
	for _, label in { kanji, name } do
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
		Kit.tween(label, 0.8, { TextTransparency = 0, TextStrokeTransparency = 0.5 })
	end
	task.delay(3, function()
		for _, label in { kanji, name } do
			Kit.tween(label, 1, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

function ZoneController.Apply(zoneId: string, instant: boolean?)
	local zone = Zones.List[zoneId]
	if not zone or zoneId == current then
		return
	end
	current = zoneId
	local l = zone.lighting
	local set = if instant then function(instance: Instance, props: { [string]: any })
		for k, v in props do
			(instance :: any)[k] = v
		end
	end else tween
	set(Lighting, { ClockTime = l.ClockTime, Brightness = l.Brightness, Ambient = l.Ambient, OutdoorAmbient = l.OutdoorAmbient })
	set(atmosphere, l.atmosphere)
	set(correction, l.correction)
	set(bloom, l.bloom)
	if not instant then
		showTitle(zone)
	end
end

function ZoneController.Current(): string?
	return current
end

function ZoneController.Init()
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	correction = Lighting:FindFirstChild("BSR_Correction") :: ColorCorrectionEffect? or Instance.new("ColorCorrectionEffect")
	correction.Name = "BSR_Correction"
	correction.Parent = Lighting
	bloom = Lighting:FindFirstChild("BSR_Bloom") :: BloomEffect? or Instance.new("BloomEffect")
	bloom.Name = "BSR_Bloom"
	bloom.Parent = Lighting

	titleGui = Kit.new("ScreenGui", { Name = "ZoneTitle", ResetOnSpawn = false, DisplayOrder = 8, Parent = player:WaitForChild("PlayerGui") })
	local holder = Kit.new("Frame", { Name = "Title", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.16), Size = UDim2.fromOffset(700, 120), Parent = titleGui })
	Kit.label("", 64, { Name = "Kanji", Size = UDim2.new(1, 0, 0, 70), TextXAlignment = Enum.TextXAlignment.Center, Font = Kit.Theme.FontTitle, TextTransparency = 1, Parent = holder })
	Kit.label("", 26, { Name = "Name", Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, Font = Kit.Theme.FontBold, TextTransparency = 1, Parent = holder })
	Kit.autoScale(titleGui)
	ZoneController.Apply("Karakura", true)
end

function ZoneController.Start()
	local function update()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local zone = Zones.zoneAt(root.Position)
			if zone then
				ZoneController.Apply(zone)
			end
		end
	end
	task.spawn(function()
		while true do
			update()
			task.wait(0.5)
		end
	end)
end

return ZoneController

--!strict
-- Interface: barras de cinema, fade/flash, botões de transformação e habilidade (PC + mobile),
-- indicador de disponibilidade e cooldown. Construída por código (StarterGui não precisa de assets).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Mugetsu"):WaitForChild("Config"))

local Hud = {}

local gui: ScreenGui
local top: Frame, bottom: Frame, fade: Frame, flash: Frame
local transformBtn: TextButton, abilityBtn: TextButton
local cdOverlay: Frame, cdLabel: TextLabel
local toast: TextLabel
local cdConn: RBXScriptConnection? = nil

Hud.onTransform = function() end :: () -> ()
Hud.onAbility = function() end :: () -> ()

local function frame(name: string, parent: Instance, color: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function button(name: string, text: string, key: string, pos: UDim2): TextButton
	local touch = UserInputService.TouchEnabled
	local b = Instance.new("TextButton")
	b.Name = name
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = pos
	b.Size = touch and UDim2.fromOffset(104, 104) or UDim2.fromOffset(86, 86)
	b.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	b.BackgroundTransparency = 0.15
	b.AutoButtonColor = true
	b.Text = ""
	b.ClipsDescendants = true
	b.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 18)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(230, 230, 235)
	s.Thickness = 2
	s.Parent = b
	local l = Instance.new("TextLabel")
	l.Name = "Title"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 0.55)
	l.Position = UDim2.fromScale(0, 0.14)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = Color3.fromRGB(240, 240, 245)
	l.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = l
	if not touch then
		local k = Instance.new("TextLabel")
		k.Name = "Key"
		k.BackgroundTransparency = 1
		k.Size = UDim2.fromScale(1, 0.25)
		k.Position = UDim2.fromScale(0, 0.7)
		k.Font = Enum.Font.GothamMedium
		k.TextScaled = true
		k.Text = `[{key}]`
		k.TextColor3 = Color3.fromRGB(170, 170, 180)
		k.Parent = b
	end
	b.Parent = gui
	return b
end

function Hud.init()
	local player = Players.LocalPlayer
	gui = Instance.new("ScreenGui")
	gui.Name = "MugetsuHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	top = frame("BarTop", gui, Color3.new(0, 0, 0), 0)
	top.Size = UDim2.fromScale(1, 0)
	top.ZIndex = 20
	bottom = frame("BarBottom", gui, Color3.new(0, 0, 0), 0)
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.fromScale(0, 1)
	bottom.Size = UDim2.fromScale(1, 0)
	bottom.ZIndex = 20
	fade = frame("Fade", gui, Color3.new(0, 0, 0), 1)
	fade.Size = UDim2.fromScale(1, 1)
	fade.ZIndex = 30
	flash = frame("Flash", gui, Color3.new(1, 1, 1), 1)
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 31

	transformBtn = button("Transform", Config.Transform.MobileButtonLabel, Config.Transform.Keybind.Name, UDim2.new(1, -24, 1, -24))
	abilityBtn = button("Ability", Config.Ability.MobileButtonLabel, Config.Ability.Keybind.Name, UDim2.new(1, -24, 1, -24))
	cdOverlay = frame("Cooldown", abilityBtn, Color3.new(0, 0, 0), 0.35)
	cdOverlay.AnchorPoint = Vector2.new(0, 1)
	cdOverlay.Position = UDim2.fromScale(0, 1)
	cdOverlay.Size = UDim2.fromScale(1, 0)
	cdOverlay.ZIndex = 5
	cdLabel = Instance.new("TextLabel")
	cdLabel.BackgroundTransparency = 1
	cdLabel.Size = UDim2.fromScale(1, 1)
	cdLabel.Font = Enum.Font.GothamBlack
	cdLabel.TextSize = 30
	cdLabel.TextColor3 = Color3.new(1, 1, 1)
	cdLabel.Text = ""
	cdLabel.ZIndex = 6
	cdLabel.Parent = abilityBtn

	toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.fromScale(0.5, 0.08)
	toast.Size = UDim2.fromOffset(420, 36)
	toast.BackgroundColor3 = Color3.new(0, 0, 0)
	toast.BackgroundTransparency = 0.3
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.Font = Enum.Font.GothamMedium
	toast.TextSize = 18
	toast.Visible = false
	toast.Parent = gui

	transformBtn.Activated:Connect(function()
		Hud.onTransform()
	end)
	abilityBtn.Activated:Connect(function()
		Hud.onAbility()
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function Hud.setLetterbox(on: boolean, time: number)
	local ti = TweenInfo.new(time, Enum.EasingStyle.Sine)
	local h = on and 0.12 or 0
	TweenService:Create(top, ti, { Size = UDim2.fromScale(1, h) }):Play()
	TweenService:Create(bottom, ti, { Size = UDim2.fromScale(1, h) }):Play()
end

-- Fade de tela cheia (preto ou branco). to: 0 = opaco, 1 = transparente.
function Hud.fade(color: Color3, to: number, time: number)
	fade.BackgroundColor3 = color
	if time <= 0 then
		fade.BackgroundTransparency = to
		return
	end
	TweenService:Create(fade, TweenInfo.new(time, Enum.EasingStyle.Sine), { BackgroundTransparency = to }):Play()
end

function Hud.flash(color: Color3, hold: number, out: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0
	task.delay(hold, function()
		TweenService:Create(flash, TweenInfo.new(out, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	end)
end

-- Restaura barras e fades imediatamente (cancelamento seguro).
function Hud.resetCinematic()
	Hud.setLetterbox(false, 0.25)
	fade.BackgroundTransparency = 1
	flash.BackgroundTransparency = 1
end

function Hud.showButtons(transformVisible: boolean, abilityVisible: boolean)
	transformBtn.Visible = transformVisible
	abilityBtn.Visible = abilityVisible
	-- empilha à esquerda se ambos aparecerem
	abilityBtn.Position = UDim2.new(1, -24, 1, -24)
	transformBtn.Position = UDim2.new(1, -24, 1, -24)
end

function Hud.setCooldown(readyAt: number?, duration: number)
	if cdConn then
		cdConn:Disconnect()
		cdConn = nil
	end
	if not readyAt then
		cdOverlay.Size = UDim2.fromScale(1, 0)
		cdLabel.Text = ""
		return
	end
	cdConn = RunService.Heartbeat:Connect(function()
		local remaining = readyAt - Workspace:GetServerTimeNow()
		if remaining <= 0 then
			cdOverlay.Size = UDim2.fromScale(1, 0)
			cdLabel.Text = ""
			if cdConn then
				cdConn:Disconnect()
				cdConn = nil
			end
			return
		end
		cdOverlay.Size = UDim2.fromScale(1, math.clamp(remaining / duration, 0, 1))
		cdLabel.Text = string.format("%.1f", remaining)
	end)
end

function Hud.notify(text: string)
	toast.Text = text
	toast.Visible = true
	local token = os.clock()
	toast:SetAttribute("Token", token)
	task.delay(2.5, function()
		if toast:GetAttribute("Token") == token then
			toast.Visible = false
		end
	end)
end

return Hud

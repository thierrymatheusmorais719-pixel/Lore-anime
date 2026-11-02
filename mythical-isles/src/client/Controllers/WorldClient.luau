-- Atmosfera por ilha (iluminação, névoa, correção de cor), clima de batalha de boss por fase,
-- barras de vida flutuantes dos inimigos/recursos e feedback de dano no jogador.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local UIKit = require(script.Parent.UIKit)

local WorldClient = {}
local player = Players.LocalPlayer
local atmosphere, cc, bloom
local currentWorld = nil
local bars: { [Instance]: any } = {}

local function setupLighting()
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	cc = Lighting:FindFirstChild("WorldTint") or Instance.new("ColorCorrectionEffect")
	cc.Name = "WorldTint"
	cc.Parent = Lighting
	bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 22
	bloom.Threshold = 1.6 -- só o que é bem brilhante (Neon) floresce: evita excesso de brilho
	bloom.Parent = Lighting
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.StarCount = 3000
		sky.Parent = Lighting
	end
end

local function applyWorld(id: string)
	local w = Worlds.Info[id]
	if not w then
		return
	end
	currentWorld = id
	local info = TweenInfo.new(2.5)
	TweenService:Create(Lighting, info, { ClockTime = w.clockTime, Ambient = w.palette.ambient, OutdoorAmbient = w.palette.ambient:Lerp(Color3.new(1, 1, 1), 0.25) }):Play()
	TweenService:Create(atmosphere, info, {
		Color = w.palette.fog, Decay = w.palette.fog:Lerp(Color3.new(0, 0, 0), 0.4),
		Density = (id == "wilds" and 0.42) or (id == "crystal" and 0.38) or (id == "astral" and 0.3) or 0.25,
		Haze = (id == "wilds" and 2.2) or (id == "sky" and 0.6) or 1.2, Glare = id == "sky" and 0.6 or 0.1,
	}):Play()
	TweenService:Create(cc, info, { TintColor = Color3.new(1, 1, 1), Saturation = id == "wilds" and -0.05 or 0.08, Contrast = 0.05 }):Play()
end

-- Durante um boss: leve tom da cor do boss, mais forte nas fases finais.
local function bossMood()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local bf = workspace:FindFirstChild("Bosses")
	if not root or not bf then
		return
	end
	for _, b in ipairs(bf:GetChildren()) do
		local c, r = b:GetAttribute("ArenaCenter"), b:GetAttribute("ArenaRadius")
		if c and r and (((root :: BasePart).Position - c) * Vector3.new(1, 0, 1)).Magnitude <= r + 5 then
			local state = b:GetAttribute("BossState")
			if state == "Fight" or state == "Transition" or state == "Intro" then
				local phase = b:GetAttribute("Phase") or 1
				local k = math.clamp(0.05 + 0.05 * phase, 0, 0.3)
				cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 200, 230), k)
				cc.Contrast = 0.05 + 0.04 * phase
				return
			end
		end
	end
	cc.TintColor = Color3.new(1, 1, 1)
	cc.Contrast = 0.05
end

local function makeBar(model: Model, isResource: boolean)
	local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not pp then
		return
	end
	local h = model:GetExtentsSize().Y
	local gui = UIKit.new("BillboardGui", { Name = "HealthBar", Size = UDim2.fromOffset(isResource and 90 or 130, isResource and 14 or 34), StudsOffsetWorldSpace = Vector3.new(0, h * 0.6 + 1.5, 0),
		AlwaysOnTop = true, MaxDistance = isResource and 50 or 80, Adornee = pp, Enabled = false, Parent = model })
	local name
	if not isResource then
		name = UIKit.label({ Size = UDim2.new(1, 0, 0, 16), Text = "", TextSize = 13, Font = UIKit.Theme.bold, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, Parent = gui })
	end
	local _, fill = UIKit.bar(gui, { Position = UDim2.new(0, 0, 1, isResource and -12 or -14), Size = UDim2.new(1, 0, 0, isResource and 10 or 12),
		color = isResource and UIKit.Theme.gold or Color3.fromRGB(230, 80, 80), radius = 4 })
	bars[model] = { gui = gui, fill = fill, name = name, resource = isResource, model = model }
end

local function updateBars()
	for model, b in pairs(bars) do
		if not model.Parent then
			bars[model] = nil
		else
			local hp, maxHp = model:GetAttribute("Health") or 0, model:GetAttribute("MaxHealth") or 1
			local dead = model:GetAttribute("Dead") == true
			local damaged = hp < maxHp
			b.gui.Enabled = not dead and (not b.resource or damaged)
			UIKit.setBar(b.fill, hp / maxHp)
			if b.name then
				local evading = model:GetAttribute("Evading")
				b.name.Text = string.format("%s <font size=\"11\">Nv %d</font>%s", model:GetAttribute("DisplayName") or "", model:GetAttribute("Level") or 1, evading and " ↩" or "")
				local isTarget = model:GetAttribute("Entity") == player:GetAttribute("Target")
				b.name.TextColor3 = isTarget and UIKit.Theme.gold or Color3.new(1, 1, 1)
			end
		end
	end
end

local function hurtFlash()
	local pg = player:WaitForChild("PlayerGui")
	local gui = UIKit.new("ScreenGui", { Name = "HurtFx", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 30, Parent = pg })
	local frame = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 30, 30), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
	local function hook(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum then
			return
		end
		local last = hum.Health
		hum.HealthChanged:Connect(function(h)
			if h < last - 1 then
				frame.BackgroundTransparency = 0.75
				TweenService:Create(frame, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			end
			last = h
		end)
	end
	if player.Character then
		task.spawn(hook, player.Character)
	end
	player.CharacterAdded:Connect(hook)
end

function WorldClient.init()
	setupLighting()
	applyWorld(player:GetAttribute("World") or "verdant")
	player:GetAttributeChangedSignal("World"):Connect(function()
		local w = player:GetAttribute("World")
		if w and w ~= currentWorld then
			applyWorld(w)
		end
	end)
	task.spawn(function()
		local ef = workspace:WaitForChild("Enemies", 30)
		if ef then
			for _, m in ipairs(ef:GetChildren()) do
				makeBar(m, false)
			end
			ef.ChildAdded:Connect(function(m)
				task.wait()
				makeBar(m, false)
			end)
		end
		local rf = workspace:WaitForChild("Resources", 30)
		if rf then
			for _, m in ipairs(rf:GetChildren()) do
				makeBar(m, true)
			end
			rf.ChildAdded:Connect(function(m)
				task.wait()
				makeBar(m, true)
			end)
		end
	end)
	hurtFlash()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.15 then
			acc = 0
			updateBars()
			bossMood()
		end
	end)
end

return WorldClient

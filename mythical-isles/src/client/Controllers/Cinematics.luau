-- CINEMÁTICAS DOS BOSSES (cliente).
--   Entrada: barras de cinema, a câmera gira devagar em volta do boss vista de baixo (ele parece enorme),
--            tremor no rugido e o nome do boss em letras grandes, com o título embaixo.
--   Derrota: clarão branco, câmera abrindo devagar ao redor do boss caído e "VITÓRIA" em destaque.
-- A câmera volta sozinha ao normal no fim; qualquer tecla/toque pula. Só toca para quem está na luta
-- (o servidor só manda a mensagem aos participantes). Com efeitos em "Baixa", a câmera fica parada.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local State = require(script.Parent.State)
local UIKit = require(script.Parent.UIKit)

local Cinematics = {}

local lp = Players.LocalPlayer
local playing = false
local token = 0

local function lowVfx(): boolean
	return State.profile ~= nil and State.profile.settings ~= nil and State.profile.settings.vfx == "Low"
end

local function screen(): ScreenGui
	local pg = lp:WaitForChild("PlayerGui")
	local g = pg:FindFirstChild("Cinematic") :: ScreenGui?
	if not g then
		local ng = Instance.new("ScreenGui")
		ng.Name = "Cinematic"
		ng.IgnoreGuiInset = true
		ng.DisplayOrder = 50
		ng.ResetOnSpawn = false
		ng.Parent = pg
		g = ng
	end
	return g :: ScreenGui
end

local function bar(parent: Instance, top: boolean): Frame
	local f = Instance.new("Frame")
	f.Name = top and "BarTop" or "BarBottom"
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0, top and 0 or 1)
	f.Position = UDim2.fromScale(0, top and 0 or 1)
	f.Size = UDim2.new(1, 0, 0, 0)
	f.ZIndex = 10
	f.Parent = parent
	return f
end

local function title(parent: Instance, text: string, sub: string, color: Color3): (TextLabel, TextLabel)
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.7)
	t.Size = UDim2.fromScale(0.8, 0.12)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = string.upper(text)
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextTransparency = 1
	t.ZIndex = 12
	t.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 4
	stroke.Transparency = 1
	stroke.Parent = t
	local s = Instance.new("TextLabel")
	s.Name = "Subtitle"
	s.BackgroundTransparency = 1
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Position = UDim2.fromScale(0.5, 0.79)
	s.Size = UDim2.fromScale(0.6, 0.05)
	s.Font = Enum.Font.GothamBold
	s.TextScaled = true
	s.Text = sub
	s.TextColor3 = color
	s.TextTransparency = 1
	s.TextStrokeColor3 = Color3.new(0, 0, 0)
	s.TextStrokeTransparency = 1
	s.ZIndex = 12
	s.Parent = parent
	return t, s
end

local function tween(obj: Instance, time: number, props)
	local tw = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Câmera em órbita em volta de `focus`, de ângulo a0 a a1, do raio r0 a r1, altura h (relativa ao foco).
-- Devolve uma função que encerra e devolve a câmera ao jogador.
local function orbit(focus: Vector3, look: Vector3, a0: number, a1: number, r0: number, r1: number, h0: number, h1: number, dur: number, shakeAt: number?)
	local cam = workspace.CurrentCamera
	local oldType, oldFov = cam.CameraType, cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		local e = 1 - (1 - k) ^ 3 -- desacelera no fim
		local a = a0 + (a1 - a0) * e
		local r = r0 + (r1 - r0) * e
		local h = h0 + (h1 - h0) * e
		local pos = focus + Vector3.new(math.cos(a) * r, h, math.sin(a) * r)
		local jitter = Vector3.zero
		if shakeAt and math.abs(os.clock() - t0 - shakeAt) < 0.45 then
			local amp = 0.45 * (1 - math.abs(os.clock() - t0 - shakeAt) / 0.45)
			jitter = Vector3.new(math.noise(os.clock() * 30, 1) * amp, math.noise(os.clock() * 30, 2) * amp, 0)
		end
		cam.CFrame = CFrame.lookAt(pos, look + jitter)
		cam.FieldOfView = 58 - 10 * e
	end)
	return function()
		conn:Disconnect()
		cam.CameraType = oldType
		cam.FieldOfView = oldFov
	end
end

local function run(kind: string, p)
	if playing or typeof(p.at) ~= "Vector3" then
		return false
	end
	playing = true
	token += 1
	local my = token
	local g = screen()
	local top, bottom = bar(g, true), bar(g, false)
	local color = typeof(p.color) == "Color3" and p.color or Color3.fromRGB(255, 214, 110)
	local isIntro = kind == "intro"
	local dur = isIntro and math.clamp(tonumber(p.time) or 3, 2.4, 4) or 2.8
	local bigText = isIntro and tostring(p.name or "Boss") or "VITÓRIA!"
	local small = isIntro and tostring(p.title or "") or (tostring(p.name or "") .. " derrotado")
	local tl, sl = title(g, bigText, small, color)
	-- some com o resto da interface durante a cena (volta no fim)
	local hidden = {}
	for _, other in ipairs(g.Parent:GetChildren()) do
		if other:IsA("ScreenGui") and other ~= g and other.Enabled ~= false then
			other.Enabled = false
			table.insert(hidden, other)
		end
	end
	tween(top, 0.35, { Size = UDim2.new(1, 0, 0.11, 0) })
	tween(bottom, 0.35, { Size = UDim2.new(1, 0, 0.11, 0) })
	local stopCam = function() end
	if not lowVfx() then
		local r = math.max(18, (tonumber(p.radius) or 6) * 3.2)
		local char = lp.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local from = root and root.Position or (p.at + Vector3.new(r, 0, 0))
		local base = math.atan2(from.Z - p.at.Z, from.X - p.at.X)
		if isIntro then
			-- de baixo para cima, girando ~70°: o boss domina a tela
			stopCam = orbit(p.at, p.at + Vector3.new(0, (tonumber(p.radius) or 6) * 0.6, 0), base - 0.6, base + 0.6, r * 1.1, r * 0.85, -2, 3, dur, dur * 0.45)
		else
			-- abre devagar por cima do boss caído
			stopCam = orbit(p.at, p.at, base, base + 0.9, r * 0.7, r * 1.4, r * 0.25, r * 0.7, dur, nil)
		end
	end
	if not isIntro then
		local flash = Instance.new("Frame")
		flash.Name = "Flash"
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.Size = UDim2.fromScale(1, 1)
		flash.ZIndex = 20
		flash.Parent = g
		tween(flash, 0.6, { BackgroundTransparency = 1 })
		task.delay(0.7, function()
			flash:Destroy()
		end)
	end
	task.delay(isIntro and dur * 0.3 or 0.35, function()
		if token == my then
			tween(tl, 0.4, { TextTransparency = 0 })
			tween(tl:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.4, { Transparency = 0 })
			tween(sl, 0.5, { TextTransparency = 0, TextStrokeTransparency = 0.2 })
			tl.Size = UDim2.fromScale(0.95, 0.15)
			tween(tl, 0.5, { Size = UDim2.fromScale(0.8, 0.12) })
		end
	end)
	local skip
	local function finish()
		if token ~= my or not playing then
			return
		end
		playing = false
		if skip then
			skip:Disconnect()
		end
		stopCam()
		for _, other in ipairs(hidden) do
			if other.Parent then
				other.Enabled = true
			end
		end
		tween(top, 0.3, { Size = UDim2.new(1, 0, 0, 0) })
		tween(bottom, 0.3, { Size = UDim2.new(1, 0, 0, 0) })
		tween(tl, 0.3, { TextTransparency = 1 })
		tween(sl, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
		task.delay(0.35, function()
			top:Destroy()
			bottom:Destroy()
			tl:Destroy()
			sl:Destroy()
		end)
	end
	skip = UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and (input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1) then
			finish()
		end
	end)
	task.delay(dur + 0.2, finish)
	return true
end

Cinematics.play = run -- (testes)
function Cinematics.isPlaying(): boolean
	return playing
end

function Cinematics.init()
	State.on("BossIntro", function(p)
		run("intro", p)
	end)
	State.on("BossDefeated", function(p)
		run("victory", p)
	end)
	local _ = UIKit
end

return Cinematics

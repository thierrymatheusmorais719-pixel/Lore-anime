-- Tremor de câmera (trauma), FOV dinâmico, letterbox e cenas cinematográficas que podem ser puladas.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CameraController = {}

local player = Players.LocalPlayer
local trauma = 0
local fovKick = 0
local baseFov = 70
local shakeScale = 1
local cinematic: { [string]: any }? = nil
local letterbox: ScreenGui

function CameraController.SetShakeScale(scale: number)
	shakeScale = math.clamp(scale, 0, 2)
end

function CameraController.Shake(amount: number)
	trauma = math.min(1.2, trauma + amount * shakeScale)
end

function CameraController.Kick(fov: number)
	fovKick = math.max(fovKick, fov)
end

local function setLetterbox(visible: boolean)
	for _, bar in letterbox:GetChildren() do
		if bar:IsA("Frame") then
			TweenService:Create(
				bar,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad),
				{ Size = UDim2.new(1, 0, if visible then 0.12 else 0, 0) }
			):Play()
		end
	end
	local hint = letterbox:FindFirstChild("Hint") :: TextLabel?
	if hint then
		hint.Visible = visible
	end
end

function CameraController.InCinematic(): boolean
	return cinematic ~= nil
end

function CameraController.EndCinematic()
	if not cinematic then
		return
	end
	cinematic = nil
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	setLetterbox(false)
end

-- Plano orbital ao redor de `focus` (BasePart). shots: { {duration, fromAngle, toAngle, distance, height, fov} }
function CameraController.PlayCinematic(focus: BasePart, shots: { { [string]: number } })
	CameraController.EndCinematic()
	local total = 0
	for _, s in shots do
		total += s.duration
	end
	cinematic = { focus = focus, shots = shots, start = os.clock(), total = total }
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	setLetterbox(true)
end

local function cinematicFrame(c): CFrame?
	local elapsed = os.clock() - c.start
	if elapsed >= c.total or not c.focus.Parent then
		return nil
	end
	local acc = 0
	for _, s in c.shots do
		if elapsed < acc + s.duration then
			local a = (elapsed - acc) / s.duration
			a = a * a * (3 - 2 * a)
			local angle = math.rad(s.fromAngle + (s.toAngle - s.fromAngle) * a)
			local distance = s.distance
			if s.distanceEnd then
				distance = s.distance + (s.distanceEnd - s.distance) * a
			end
			local focusCf = c.focus.CFrame
			local offset = Vector3.new(math.sin(angle) * distance, s.height, -math.cos(angle) * distance)
			local position = focusCf.Position + focusCf:VectorToWorldSpace(offset)
			workspace.CurrentCamera.FieldOfView = s.fov or 60
			return CFrame.lookAt(position, focusCf.Position + Vector3.new(0, s.lookHeight or 1.5, 0))
		end
		acc += s.duration
	end
	return nil
end

function CameraController.Init()
	letterbox = Instance.new("ScreenGui")
	letterbox.Name = "Letterbox"
	letterbox.IgnoreGuiInset = true
	letterbox.DisplayOrder = 50
	letterbox.ResetOnSpawn = false
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		bar.Position = UDim2.fromScale(0, if top then 0 else 1)
		bar.Size = UDim2.new(1, 0, 0, 0)
		bar.Parent = letterbox
	end
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(1, 1)
	hint.Position = UDim2.new(1, -24, 1, -14)
	hint.Size = UDim2.fromOffset(260, 24)
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 14
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.TextColor3 = Color3.fromRGB(200, 200, 210)
	hint.Text = "Toque / qualquer tecla para pular"
	hint.Visible = false
	hint.ZIndex = 2
	hint.Parent = letterbox
	letterbox.Parent = player:WaitForChild("PlayerGui")
end

function CameraController.Start()
	UserInputService.InputBegan:Connect(function(input)
		if
			cinematic
			and (
				input.UserInputType == Enum.UserInputType.Keyboard
				or input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.Gamepad1
				or input.UserInputType == Enum.UserInputType.MouseButton1
			)
		then
			if os.clock() - cinematic.start > 0.25 then
				CameraController.EndCinematic()
			end
		end
	end)
	RunService:BindToRenderStep("BSR_Camera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		if cinematic then
			local frame = cinematicFrame(cinematic)
			if frame then
				camera.CFrame = frame
				return
			end
			CameraController.EndCinematic()
		end
		-- FOV: base + velocidade + chute
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local speedFov = 0
		if root then
			local v = root.AssemblyLinearVelocity
			speedFov = math.clamp((Vector3.new(v.X, 0, v.Z).Magnitude - 20) * 0.25, 0, 12)
		end
		fovKick = math.max(0, fovKick - dt * 40)
		local targetFov = baseFov + speedFov + fovKick
		camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 10)
		-- Tremor
		if trauma > 0 then
			local s = trauma * trauma
			local t = os.clock() * 28
			local rx = math.noise(t, 0.3) * 0.045 * s
			local ry = math.noise(t, 7.1) * 0.045 * s
			local rz = math.noise(t, 13.7) * 0.03 * s
			camera.CFrame *= CFrame.Angles(rx, ry, rz)
			trauma = math.max(0, trauma - dt * 1.8)
		end
	end)
end

return CameraController

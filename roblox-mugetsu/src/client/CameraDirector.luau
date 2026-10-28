--!strict
-- Câmera exclusiva da cutscene. Posição = f(tempo do servidor), nunca aleatória:
-- planos definidos na Timeline (posição/olhar/FOV relativos ao HumanoidRootPart), órbita,
-- transições suaves, impulsos de tremor com decaimento e restauração garantida da câmera original.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Timeline = require(game:GetService("ReplicatedStorage"):WaitForChild("Mugetsu"):WaitForChild("Timeline"))

local CameraDirector = {}

local BIND_NAME = "MugetsuCutsceneCamera"

type Shake = { start: number, duration: number, amplitude: number }
type Saved = { cameraType: Enum.CameraType, subject: Instance?, cframe: CFrame, fov: number }

local active = false
local saved: Saved? = nil
local subject: BasePart? = nil
local startServer = 0
local shakes: { Shake } = {}
local fovKick = 0
local fovKickDecay = 0

local function lerpV(a: Vector3, b: Vector3, k: number): Vector3
	return a:Lerp(b, k)
end

local function shotCFrame(root: CFrame, shot: Timeline.Shot, alpha: number): (CFrame, number)
	local k = Timeline.ease(shot.ease == "Orbit" and "Sine" or shot.ease, alpha)
	local focus
	local pos
	if shot.ease == "Orbit" and shot.orbit then
		local o = shot.orbit
		local ang = math.rad(o.degrees) * k
		local base = shot.from.pos
		local startAngle = math.atan2(base.X, base.Z)
		local a = startAngle + ang
		local local_ = Vector3.new(math.sin(a) * o.radius, o.height + 0.6 * math.sin(k * math.pi), math.cos(a) * o.radius)
		pos = root:PointToWorldSpace(local_)
		focus = root:PointToWorldSpace(lerpV(shot.from.look, shot.to.look, k))
	else
		pos = root:PointToWorldSpace(lerpV(shot.from.pos, shot.to.pos, k))
		focus = root:PointToWorldSpace(lerpV(shot.from.look, shot.to.look, k))
	end
	local fov = shot.from.fov + (shot.to.fov - shot.from.fov) * k
	return CFrame.lookAt(pos, focus), fov
end

-- pseudo-ruído suave e determinístico (sem aleatoriedade)
local function noise(t: number, seed: number): number
	return math.sin(t * 47.0 + seed) * 0.6 + math.sin(t * 81.0 + seed * 2.3) * 0.4
end

function CameraDirector.shake(amplitude: number, duration: number)
	table.insert(shakes, { start = os.clock(), duration = duration, amplitude = amplitude })
end

function CameraDirector.punchFov(amount: number, decayTime: number)
	fovKick = amount
	fovKickDecay = amount / math.max(decayTime, 0.05)
end

function CameraDirector.isActive(): boolean
	return active
end

function CameraDirector.stop()
	if not active then
		return
	end
	active = false
	pcall(function()
		RunService:UnbindFromRenderStep(BIND_NAME)
	end)
	local cam = Workspace.CurrentCamera
	local s = saved
	saved = nil
	shakes = {}
	fovKick = 0
	if cam and s then
		cam.CameraType = s.cameraType
		if s.subject then
			cam.CameraSubject = s.subject
		end
		cam.FieldOfView = s.fov
		-- a câmera padrão reassume e se reposiciona sozinha; mantemos o CFrame para evitar salto.
		cam.CFrame = s.cframe
	end
end

function CameraDirector.start(rootPart: BasePart, serverStart: number)
	if active then
		CameraDirector.stop()
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	saved = {
		cameraType = cam.CameraType, subject = cam.CameraSubject, cframe = cam.CFrame, fov = cam.FieldOfView,
	}
	subject = rootPart
	startServer = serverStart
	active = true
	cam.CameraType = Enum.CameraType.Scriptable

	local lastFrame = os.clock()
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local now = os.clock()
		local dt = now - lastFrame
		lastFrame = now
		if not active or not subject or not subject.Parent then
			CameraDirector.stop()
			return
		end
		local t = Workspace:GetServerTimeNow() - startServer
		-- raiz estável: posição do HRP mas orientação "congelada" na do início (o servidor ancora o HRP).
		local root = subject.CFrame
		local shot, alpha = Timeline.getShot(math.max(t, 0))
		if not shot then
			shot = Timeline.Shots[1]
			alpha = 0
		end
		local cf, fov = shotCFrame(root, shot :: Timeline.Shot, alpha)

		-- tremor: soma de impulsos com decaimento quadrático
		local offset = Vector3.zero
		local roll = 0
		for i = #shakes, 1, -1 do
			local sk = shakes[i]
			local age = now - sk.start
			if age >= sk.duration then
				table.remove(shakes, i)
			else
				local f = (1 - age / sk.duration) ^ 2 * sk.amplitude
				offset += Vector3.new(noise(now, 1) * f, noise(now, 7) * f, noise(now, 13) * f * 0.5)
				roll += noise(now, 19) * f * 0.02
			end
		end
		if fovKick ~= 0 then
			fovKick = fovKick > 0 and math.max(0, fovKick - fovKickDecay * dt) or math.min(0, fovKick - fovKickDecay * dt)
		end
		cam.CFrame = cf * CFrame.new(offset) * CFrame.Angles(0, 0, roll)
		cam.FieldOfView = math.clamp(fov + fovKick, 8, 110)
	end)
end

return CameraDirector

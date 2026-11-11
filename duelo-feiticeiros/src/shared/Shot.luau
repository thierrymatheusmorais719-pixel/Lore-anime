-- CÂMERA da cinemática: cortes secos, travellings, órbitas e tremor. Um único laço por quadro aplica
-- a tomada atual + o tremor na câmera (Scriptable).

local RunService = game:GetService("RunService")

local Shot = {}

local cam: Camera? = nil
local conn: RBXScriptConnection? = nil
local current: ((number) -> (CFrame, number))? = nil
local t0 = 0
local shakeAmp, shakeUntil = 0, 0
local oldType, oldFov

local function ease(k: number): number
	return k * k * (3 - 2 * k) -- suave nas pontas
end

function Shot.start()
	cam = workspace.CurrentCamera
	local c = cam :: Camera
	oldType, oldFov = c.CameraType, c.FieldOfView
	c.CameraType = Enum.CameraType.Scriptable
	conn = RunService.RenderStepped:Connect(function()
		if not current then
			return
		end
		local cf, fov = current(os.clock() - t0)
		local now = os.clock()
		if now < shakeUntil then
			local a = shakeAmp * (shakeUntil - now) / 0.5
			cf = cf * CFrame.new(math.noise(now * 31, 1) * a, math.noise(now * 31, 2) * a, 0) * CFrame.Angles(0, 0, math.noise(now * 23, 3) * a * 0.03)
		end
		c.CFrame = cf
		c.FieldOfView = fov
	end)
end

function Shot.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	current = nil
	local c = cam or workspace.CurrentCamera
	if c then
		c.CameraType = oldType or Enum.CameraType.Custom
		c.FieldOfView = oldFov or 70
	end
end

local function set(fn)
	current = fn
	t0 = os.clock()
end

-- Corte seco para uma posição fixa olhando para um ponto.
function Shot.cut(pos: Vector3, look: Vector3, fov: number?)
	local cf = CFrame.lookAt(pos, look)
	set(function()
		return cf, fov or 50
	end)
end

-- Travelling: de (p0 olhando l0) para (p1 olhando l1) em `time`, com zoom de fov0 a fov1.
function Shot.move(p0: Vector3, l0: Vector3, p1: Vector3, l1: Vector3, time: number, fov0: number?, fov1: number?)
	set(function(t)
		local k = ease(math.clamp(t / time, 0, 1))
		local f0, f1 = fov0 or 50, fov1 or fov0 or 50
		return CFrame.lookAt(p0:Lerp(p1, k), l0:Lerp(l1, k)), f0 + (f1 - f0) * k
	end)
end

-- Órbita em volta de um ponto (ângulos em radianos).
function Shot.orbit(center: Vector3, radius: number, a0: number, a1: number, height: number, time: number, fov: number?)
	set(function(t)
		local k = ease(math.clamp(t / time, 0, 1))
		local a = a0 + (a1 - a0) * k
		return CFrame.lookAt(center + Vector3.new(math.cos(a) * radius, height, math.sin(a) * radius), center), fov or 55
	end)
end

-- Segue uma peça (ex.: o rosto de alguém) com um deslocamento relativo ao mundo.
function Shot.follow(target: BasePart, offset: Vector3, lookOffset: Vector3?, fov: number?)
	set(function()
		local at = target.Position + (lookOffset or Vector3.zero)
		return CFrame.lookAt(target.Position + offset, at), fov or 40
	end)
end

function Shot.shake(amp: number, time: number)
	shakeAmp = math.max(shakeAmp * (os.clock() < shakeUntil and 1 or 0), amp)
	shakeUntil = math.max(shakeUntil, os.clock() + time)
end

return Shot

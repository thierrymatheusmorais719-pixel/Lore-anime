-- Mola amortecida crítica/sub-amortecida para câmera, tecidos e UI.
local Spring = {}
Spring.__index = Spring

function Spring.new(initial: any, speed: number?, damper: number?)
	return setmetatable({
		Position = initial,
		Velocity = initial * 0,
		Target = initial,
		Speed = speed or 12,
		Damper = damper or 0.6,
	}, Spring)
end

function Spring:Step(dt: number)
	-- Integração semi-implícita em sub-passos para estabilidade com dt alto (celulares).
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	local k = self.Speed * self.Speed
	local c = 2 * self.Damper * self.Speed
	for _ = 1, steps do
		local accel = (self.Target - self.Position) * k - self.Velocity * c
		self.Velocity += accel * h
		self.Position += self.Velocity * h
	end
	return self.Position
end

function Spring:Impulse(velocity: any)
	self.Velocity += velocity
end

return Spring

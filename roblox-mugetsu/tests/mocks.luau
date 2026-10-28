-- Mocks mínimos das APIs do Roblox usadas pelos módulos puros.
local V3 = {}
V3.__index = V3
local function new(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V3) end
V3.__add = function(a, b) return new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return new(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return new(a.X * b, a.Y * b, a.Z * b) end
	return new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.Dot = function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
V3.Lerp = function(a, b, k) return new(a.X + (b.X - a.X) * k, a.Y + (b.Y - a.Y) * k, a.Z + (b.Z - a.Z) * k) end
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		return new(t.X / m, t.Y / m, t.Z / m)
	end
	return V3[k]
end
Vector3 = { new = new, zero = new(0, 0, 0) }
local realtypeof = typeof
function typeof(v)
	if type(v) == "table" and getmetatable(v) == V3 then return "Vector3" end
	return type(v)
end
task = { spawn = function(f, ...) f(...) end }

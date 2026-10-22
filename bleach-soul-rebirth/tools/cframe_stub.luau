-- CFrame mínimo (rotação 3x3 + posição) com slerp, para rodar módulos de pose fora do Roblox.
local CF = {}
CF.__index = CF
local function new(px, py, pz, r)
	return setmetatable({ p = { px, py, pz }, r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CF)
end
local function mul3(a, b)
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7],
		a[1] * b[2] + a[2] * b[5] + a[3] * b[8],
		a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7],
		a[4] * b[2] + a[5] * b[5] + a[6] * b[8],
		a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7],
		a[7] * b[2] + a[8] * b[5] + a[9] * b[8],
		a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end
local function rx(t)
	local c, s = math.cos(t), math.sin(t)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(t)
	local c, s = math.cos(t), math.sin(t)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(t)
	local c, s = math.cos(t), math.sin(t)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
CF.__mul = function(a, b)
	local r = a.r
	local bp = b.p
	return new(
		a.p[1] + r[1] * bp[1] + r[2] * bp[2] + r[3] * bp[3],
		a.p[2] + r[4] * bp[1] + r[5] * bp[2] + r[6] * bp[3],
		a.p[3] + r[7] * bp[1] + r[8] * bp[2] + r[9] * bp[3],
		mul3(a.r, b.r)
	)
end
local function toQuat(m)
	local tr = m[1] + m[5] + m[9]
	local w, x, y, z
	if tr > 0 then
		local s = math.sqrt(tr + 1) * 2
		w = 0.25 * s
		x = (m[8] - m[6]) / s
		y = (m[3] - m[7]) / s
		z = (m[4] - m[2]) / s
	elseif m[1] > m[5] and m[1] > m[9] then
		local s = math.sqrt(1 + m[1] - m[5] - m[9]) * 2
		w = (m[8] - m[6]) / s
		x = 0.25 * s
		y = (m[2] + m[4]) / s
		z = (m[3] + m[7]) / s
	elseif m[5] > m[9] then
		local s = math.sqrt(1 + m[5] - m[1] - m[9]) * 2
		w = (m[3] - m[7]) / s
		x = (m[2] + m[4]) / s
		y = 0.25 * s
		z = (m[6] + m[8]) / s
	else
		local s = math.sqrt(1 + m[9] - m[1] - m[5]) * 2
		w = (m[4] - m[2]) / s
		x = (m[3] + m[7]) / s
		y = (m[6] + m[8]) / s
		z = 0.25 * s
	end
	return { w, x, y, z }
end
local function fromQuat(q)
	local w, x, y, z = q[1], q[2], q[3], q[4]
	return {
		1 - 2 * (y * y + z * z),
		2 * (x * y - z * w),
		2 * (x * z + y * w),
		2 * (x * y + z * w),
		1 - 2 * (x * x + z * z),
		2 * (y * z - x * w),
		2 * (x * z - y * w),
		2 * (y * z + x * w),
		1 - 2 * (x * x + y * y),
	}
end
function CF:Lerp(b, t)
	local qa, qb = toQuat(self.r), toQuat(b.r)
	local dot = qa[1] * qb[1] + qa[2] * qb[2] + qa[3] * qb[3] + qa[4] * qb[4]
	if dot < 0 then
		qb = { -qb[1], -qb[2], -qb[3], -qb[4] }
		dot = -dot
	end
	local q
	if dot > 0.9995 then
		q = {
			qa[1] + (qb[1] - qa[1]) * t,
			qa[2] + (qb[2] - qa[2]) * t,
			qa[3] + (qb[3] - qa[3]) * t,
			qa[4] + (qb[4] - qa[4]) * t,
		}
	else
		local th = math.acos(dot)
		local s0, s1 = math.sin((1 - t) * th) / math.sin(th), math.sin(t * th) / math.sin(th)
		q = { qa[1] * s0 + qb[1] * s1, qa[2] * s0 + qb[2] * s1, qa[3] * s0 + qb[3] * s1, qa[4] * s0 + qb[4] * s1 }
	end
	local n = math.sqrt(q[1] ^ 2 + q[2] ^ 2 + q[3] ^ 2 + q[4] ^ 2)
	q = { q[1] / n, q[2] / n, q[3] / n, q[4] / n }
	return new(
		self.p[1] + (b.p[1] - self.p[1]) * t,
		self.p[2] + (b.p[2] - self.p[2]) * t,
		self.p[3] + (b.p[3] - self.p[3]) * t,
		fromQuat(q)
	)
end
-- Euler XYZ (inverso de CFrame.Angles = Rx*Ry*Rz)
function CF:ToEulerAnglesXYZ()
	local m = self.r
	local y = math.asin(math.clamp(m[3], -1, 1))
	local x, z
	if math.abs(m[3]) < 0.99999 then
		x = math.atan2(-m[6], m[9])
		z = math.atan2(-m[2], m[1])
	else
		x = math.atan2(m[8], m[5])
		z = 0
	end
	return x, y, z
end
local CFrame = {
	new = function(x, y, z, ...)
		if type(x) == "table" then
			return new(x.X, x.Y, x.Z)
		end
		local rest = { ... }
		if #rest == 9 then
			return new(x, y, z, rest)
		end
		return new(x or 0, y or 0, z or 0)
	end,
	Angles = function(x, y, z)
		return new(0, 0, 0, mul3(mul3(rx(x), ry(y)), rz(z)))
	end,
	fromEulerAnglesYXZ = function(x, y, z)
		return new(0, 0, 0, mul3(mul3(ry(y), rx(x)), rz(z)))
	end,
}
CFrame.identity = new(0, 0, 0)
-- @@FIM_CFRAME@@
local Vector3 = {
	new = function(x, y, z)
		return { X = x, Y = y, Z = z }
	end,
}
local Color3 = {
	fromRGB = function()
		return {}
	end,
}

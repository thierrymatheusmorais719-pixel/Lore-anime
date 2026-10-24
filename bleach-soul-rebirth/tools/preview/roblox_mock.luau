-- Simulação mínima de tipos e instâncias do Roblox para rodar os construtores de modelos
-- (WeaponBuilder, RigBuilder...) fora do Studio e exportar as peças para desenhar.
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3Meta)
end
Vector3Meta = {
	__add = function(a, b)
		return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end,
	__sub = function(a, b)
		return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end,
	__mul = function(a, b)
		if type(a) == "number" then
			return v3(b.X * a, b.Y * a, b.Z * a)
		elseif type(b) == "number" then
			return v3(a.X * b, a.Y * b, a.Z * b)
		end
		return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end,
	__div = function(a, n)
		return v3(a.X / n, a.Y / n, a.Z / n)
	end,
	__unm = function(a)
		return v3(-a.X, -a.Y, -a.Z)
	end,
}
Vector3Meta.__index = function(self, k)
	if k == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif k == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		return v3(self.X / m, self.Y / m, self.Z / m)
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	elseif k == "Cross" then
		return function(a, b)
			return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
		end
	end
	return nil
end
CFrame.lookAt = function(at, target, up)
	up = up or v3(0, 1, 0)
	local z = (at - target).Unit
	if math.abs(z.X * up.X + z.Y * up.Y + z.Z * up.Z) > 0.999 then
		up = v3(1, 0, 0)
	end
	local x = v3(up.Y * z.Z - up.Z * z.Y, up.Z * z.X - up.X * z.Z, up.X * z.Y - up.Y * z.X).Unit
	local y = v3(z.Y * x.Z - z.Z * x.Y, z.Z * x.X - z.X * x.Z, z.X * x.Y - z.Y * x.X)
	return CFrame.new(at.X, at.Y, at.Z, x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z)
end
Vector3 = { new = v3, one = v3(1, 1, 1), zero = v3(0, 0, 0), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }
CF.__add = function(a, b)
	return new(a.p[1] + b.X, a.p[2] + b.Y, a.p[3] + b.Z, a.r)
end
CF.__index = function(self, k)
	if k == "Position" then
		return v3(self.p[1], self.p[2], self.p[3])
	elseif k == "Rotation" then
		return new(0, 0, 0, self.r)
	end
	return CF[k]
end
function CF:Inverse()
	local r = self.r
	local rt = { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
	local p = self.p
	return new(
		-(rt[1] * p[1] + rt[2] * p[2] + rt[3] * p[3]),
		-(rt[4] * p[1] + rt[5] * p[2] + rt[6] * p[3]),
		-(rt[7] * p[1] + rt[8] * p[2] + rt[9] * p[3]),
		rt
	)
end
function CF:PointToWorldSpace(v)
	local r = self.r
	return v3(
		self.p[1] + r[1] * v.X + r[2] * v.Y + r[3] * v.Z,
		self.p[2] + r[4] * v.X + r[5] * v.Y + r[6] * v.Z,
		self.p[3] + r[7] * v.X + r[8] * v.Y + r[9] * v.Z
	)
end
function CF:PointToObjectSpace(v)
	return self:Inverse():PointToWorldSpace(v)
end
Color3 = {
	fromRGB = function(r, g, b)
		return Color3.new(r / 255, g / 255, b / 255)
	end,
	new = function(r, g, b)
		local c = { R = r, G = g, B = b }
		function c:Lerp(o, t)
			return Color3.new(self.R + (o.R - self.R) * t, self.G + (o.G - self.G) * t, self.B + (o.B - self.B) * t)
		end
		return c
	end,
}
local function enumProxy(kind)
	return setmetatable({}, {
		__index = function(_, name)
			return { Name = name, EnumType = kind }
		end,
	})
end
Enum = setmetatable({}, {
	__index = function(_, kind)
		return enumProxy(kind)
	end,
})
ALL_PARTS = {}
local Inst = {}
Inst.__index = function(self, k)
	return rawget(Inst, k) or rawget(self, "_props")[k] or self:FindFirstChild(k)
end
Inst.__newindex = function(self, k, v)
	if k == "Parent" then
		local old = rawget(self, "_parent")
		if old then
			for i, c in old._children do
				if c == self then
					table.remove(old._children, i)
					break
				end
			end
		end
		rawset(self, "_parent", v)
		if v then
			table.insert(v._children, self)
		end
		return
	end
	if k == "CFrame" and rawget(self, "_isPart") then
		rawget(self, "_props").CFrame = v
		return
	end
	rawget(self, "_props")[k] = v
end
function Inst:FindFirstChild(name)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_props").Name == name then
			return c
		end
	end
	return nil
end
function Inst:GetChildren()
	return table.clone(rawget(self, "_children"))
end
function Inst:GetDescendants()
	local out = {}
	local function walk(i)
		for _, c in rawget(i, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Inst:IsA(class)
	local c = rawget(self, "_class")
	if class == "BasePart" then
		return c == "Part" or c == "WedgePart" or c == "MeshPart"
	end
	return c == class
end
function Inst:SetAttribute(k, v)
	rawget(self, "_attrs")[k] = v
end
function Inst:GetAttribute(k)
	return rawget(self, "_attrs")[k]
end
function Inst:Destroy()
	self.Parent = nil
end
function Inst:PivotTo() end
Instance = {
	new = function(class)
		local i = setmetatable({
			_class = class,
			_children = {},
			_attrs = {},
			_props = { Name = class, Transparency = 0, CFrame = CFrame.new() },
			_isPart = class == "Part" or class == "WedgePart",
		}, Inst)
		if rawget(i, "_isPart") then
			table.insert(ALL_PARTS, i)
		end
		return i
	end,
}
function game.GetService()
	return { Shared = { Config = { Elements = "ELEMENTS" } } }
end

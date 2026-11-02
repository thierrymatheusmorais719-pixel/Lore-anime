-- Mock MÍNIMO da API do Roblox para rodar os construtores de modelos fora do Studio.
-- Não simula física/render; serve para pegar erros de execução (nil, propriedade, matemática).

local function clamp(x, a, b)
	return math.max(a, math.min(b, x))
end

-- Vector3 --------------------------------------------------------------------
local V3 = {}
V3.__index = V3
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__index = function(t, k)
	if k == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
	elseif k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		return m > 0 and v3(t.X / m, t.Y / m, t.Z / m) or v3(0, 0, 0)
	end
	return V3[k]
end
function V3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3.Lerp(a, b, t)
	return a + (b - a) * t
end
Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }
Vector2 = { new = function(x, y)
	return { X = x or 0, Y = y or 0 }
end, zero = { X = 0, Y = 0 } }

-- CFrame (rotação 3x3 + posição) -------------------------------------------------
local CFm = {}
local function cf(px, py, pz, r)
	return setmetatable({ p = v3(px, py, pz), r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CFm)
end
local function mulR(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return r
end
local function rotV(r, v)
	return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function transpose(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
CFm.__mul = function(a, b)
	if getmetatable(b) == CFm then
		local p = a.p + rotV(a.r, b.p)
		return cf(p.X, p.Y, p.Z, mulR(a.r, b.r))
	end
	return a.p + rotV(a.r, b)
end
CFm.__add = function(a, v)
	return cf(a.p.X + v.X, a.p.Y + v.Y, a.p.Z + v.Z, a.r)
end
CFm.__sub = function(a, v)
	return cf(a.p.X - v.X, a.p.Y - v.Y, a.p.Z - v.Z, a.r)
end
CFm.__index = function(t, k)
	if k == "Position" or k == "p" then
		return rawget(t, "p")
	elseif k == "Rotation" then
		return cf(0, 0, 0, t.r)
	elseif k == "LookVector" then
		return v3(-t.r[3], -t.r[6], -t.r[9])
	elseif k == "X" then
		return t.p.X
	elseif k == "Y" then
		return t.p.Y
	elseif k == "Z" then
		return t.p.Z
	end
	return CFm[k]
end
function CFm.Inverse(a)
	local rt = transpose(a.r)
	local p = rotV(rt, -a.p)
	return cf(p.X, p.Y, p.Z, rt)
end
function CFm.VectorToWorldSpace(a, v)
	return rotV(a.r, v)
end
function CFm.VectorToObjectSpace(a, v)
	return rotV(transpose(a.r), v)
end
function CFm.ToObjectSpace(a, b)
	return a:Inverse() * b
end
function CFm.Lerp(a, b, t)
	local p = a.p:Lerp(b.p, t)
	return cf(p.X, p.Y, p.Z, b.r)
end
local function angles(x, y, z)
	local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	local rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(0, 0, 0, mulR(mulR(rx, ry), rz))
end
local function lookAt(pos, target)
	local f = (target - pos)
	if f.Magnitude < 1e-9 then
		return cf(pos.X, pos.Y, pos.Z)
	end
	f = f.Unit
	local up = v3(0, 1, 0)
	if math.abs(f:Dot(up)) > 0.999 then
		up = v3(0, 0, 1)
	end
	local right = f:Cross(up).Unit
	local u = right:Cross(f)
	local back = -f
	return cf(pos.X, pos.Y, pos.Z, { right.X, u.X, back.X, right.Y, u.Y, back.Y, right.Z, u.Z, back.Z })
end
CFrame = {
	new = function(a, b, c)
		if a == nil then
			return cf(0, 0, 0)
		end
		if type(a) == "table" then
			if b then
				return lookAt(a, b)
			end
			return cf(a.X, a.Y, a.Z)
		end
		return cf(a, b or 0, c or 0)
	end,
	Angles = angles,
	fromEulerAnglesXYZ = angles,
	lookAt = lookAt,
	identity = cf(0, 0, 0),
}

-- Color3 ---------------------------------------------------------------------
local C3 = {}
C3.__index = C3
local function c3(r, g, b)
	return setmetatable({ R = clamp(r, 0, 1), G = clamp(g, 0, 1), B = clamp(b, 0, 1) }, C3)
end
function C3.Lerp(a, b, t)
	return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function C3.ToHSV(c)
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == c.R then
			h = ((c.G - c.B) / d) % 6
		elseif mx == c.G then
			h = (c.B - c.R) / d + 2
		else
			h = (c.R - c.G) / d + 4
		end
		h /= 6
	end
	return h, mx > 0 and d / mx or 0, mx
end
function C3.ToHex(c)
	return string.format("%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end
Color3 = {
	new = c3,
	fromRGB = function(r, g, b)
		return c3(r / 255, g / 255, b / 255)
	end,
	fromHSV = function(h, s, v)
		return c3(v, v * (1 - s), v * (1 - s * h))
	end,
}

-- Tipos simples ----------------------------------------------------------------
local function ctor(name)
	return { new = function(...)
		return { __type = name, ... }
	end }
end
NumberSequence = ctor("NumberSequence")
NumberSequenceKeypoint = ctor("NumberSequenceKeypoint")
ColorSequence = ctor("ColorSequence")
ColorSequenceKeypoint = ctor("ColorSequenceKeypoint")
NumberRange = ctor("NumberRange")
UDim = ctor("UDim")
UDim2 = { new = function(...)
	return { ... }
end, fromScale = function(...)
	return { ... }
end, fromOffset = function(...)
	return { ... }
end }

-- Enum: qualquer Enum.X.Y existe (os nomes são verificados por tools/api_check.py).
-- Itens são cacheados para que comparações (==) funcionem.
local enumCache = {}
Enum = setmetatable({}, { __index = function(_, enumName)
	local e = enumCache[enumName]
	if not e then
		local items = {}
		e = setmetatable({}, { __index = function(_, item)
			local v = items[item]
			if not v then
				v = { EnumType = enumName, Name = item }
				items[item] = v
			end
			return v
		end })
		enumCache[enumName] = e
	end
	return e
end })

-- Instance -------------------------------------------------------------------
local PART_CLASSES = { Part = true, WedgePart = true, CornerWedgePart = true, MeshPart = true, SpawnLocation = true }
local IS = {
	BasePart = PART_CLASSES,
	Model = { Model = true },
	Motor6D = { Motor6D = true },
	JointInstance = { Motor6D = true, Weld = true },
	ParticleEmitter = { ParticleEmitter = true },
	Light = { PointLight = true },
}
local Inst = {}
Inst.__index = function(t, k)
	local m = rawget(Inst, k)
	if m then
		return m
	end
	local props = rawget(t, "_props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	if k == "Position" and props.CFrame then
		return props.CFrame.p
	end
	local hook = __MOCK_INDEX_HOOK and __MOCK_INDEX_HOOK(t, k)
	if hook ~= nil then
		return hook
	end
	local child = rawget(t, "_childByName")[k]
	if child then
		return child
	end
	return nil
end
Inst.__newindex = function(t, k, v)
	if k == "Parent" then
		local old = t._props.Parent
		if old then
			for i, c in ipairs(old._children) do
				if c == t then
					table.remove(old._children, i)
					break
				end
			end
			if old._childByName[t._props.Name] == t then
				old._childByName[t._props.Name] = nil
			end
		end
		t._props.Parent = v
		if v then
			table.insert(v._children, t)
			if v._childByName[t._props.Name] == nil then
				v._childByName[t._props.Name] = t
			end
		end
		return
	end
	if k == "Name" and t._props.Parent then
		local parent = t._props.Parent
		if parent._childByName[t._props.Name] == t then
			parent._childByName[t._props.Name] = nil
		end
		if parent._childByName[v] == nil then
			parent._childByName[v] = t
		end
	end
	if (k == "CFrame" or k == "Position") and type(v) == "table" then
		local pp = v.p or v
		if pp.X ~= pp.X or pp.Y ~= pp.Y or pp.Z ~= pp.Z then
			error("NaN atribuído a " .. k .. " de " .. tostring(t._props.Name), 2)
		end
	end
	if k == "Position" and t._props.CFrame then
		local c = t._props.CFrame
		t._props.CFrame = c.Rotation + v
		return
	end
	if k == "Shape" and t._props.ClassName == "Part" then
		-- o Roblox força tamanho uniforme em esferas
		t._props.Shape = v
		return
	end
	t._props[k] = v
end

__MOCK_INDEX_HOOK = nil -- o simulador instala ganchos (sinais, métodos por classe)
__MOCK_ON_NEW = nil
local function newInstance(className)
	local t = setmetatable({ _children = {}, _childByName = {}, _attrs = {}, _props = { ClassName = className, Name = className } }, Inst)
	if PART_CLASSES[className] then
		t._props.Size = v3(4, 1, 2)
		t._props.CFrame = cf(0, 0, 0)
		t._props.Transparency = 0
		t._props.Color = c3(0.6, 0.6, 0.6)
	elseif className == "Motor6D" then
		t._props.C0 = cf(0, 0, 0)
		t._props.C1 = cf(0, 0, 0)
		t._props.Transform = cf(0, 0, 0)
	end
	if __MOCK_ON_NEW then
		__MOCK_ON_NEW(t, className)
	end
	return t
end
Instance = { new = newInstance }
__MOCK_V3, __MOCK_C3, __MOCK_INST, __MOCK_CF = V3, C3, Inst, CFm

function Inst.IsA(self, cls)
	if self._props.ClassName == cls or cls == "Instance" then
		return true
	end
	local set = IS[cls]
	return set ~= nil and set[self._props.ClassName] == true
end
function Inst.GetChildren(self)
	return table.clone(self._children)
end
function Inst.GetDescendants(self)
	local out = {}
	local function walk(n)
		for _, c in ipairs(n._children) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Inst.FindFirstChild(self, name)
	return self._childByName[name]
end
function Inst.FindFirstChildOfClass(self, cls)
	for _, c in ipairs(self._children) do
		if c._props.ClassName == cls then
			return c
		end
	end
	return nil
end
function Inst.FindFirstChildWhichIsA(self, cls)
	for _, c in ipairs(self._children) do
		if c:IsA(cls) then
			return c
		end
	end
	return nil
end
function Inst.SetAttribute(self, k, v)
	assert(type(k) == "string", "SetAttribute: nome inválido")
	local tv = type(v)
	assert(v == nil or tv == "string" or tv == "number" or tv == "boolean" or (tv == "table" and (getmetatable(v) == V3 or getmetatable(v) == C3)),
		"SetAttribute: tipo não suportado para " .. k)
	self._attrs[k] = v
end
function Inst.GetAttribute(self, k)
	return self._attrs[k]
end
function Inst.Destroy(self)
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
function Inst.IsDescendantOf(self, other)
	local p = self._props.Parent
	while p do
		if p == other then
			return true
		end
		p = p._props.Parent
	end
	return false
end
function Inst.WaitForChild(self, name)
	local c = self._childByName[name]
	if c then
		return c
	end
	if __MOCK_WAIT_HOOK then
		local h = __MOCK_WAIT_HOOK(self, name)
		if h then
			return h
		end
	end
	error("WaitForChild travaria: " .. tostring(self._props.Name) .. "." .. name)
end
function Inst.SetNetworkOwner() end
local function modelParts(m)
	local list = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end
function Inst.GetPivot(self)
	if self._props.ClassName == "Model" then
		local pp = self._props.PrimaryPart
		if pp then
			return pp.CFrame
		end
		return self._pivot or cf(0, 0, 0)
	end
	return self._props.CFrame
end
local function isNaN(x)
	return x ~= x
end
function Inst.PivotTo(self, target)
	if isNaN(target.p.X) or isNaN(target.p.Y) or isNaN(target.p.Z) or isNaN(target.r[1]) or isNaN(target.r[5]) then
		error("PivotTo com NaN em " .. tostring(self._props.Name), 2)
	end
	if self._props.ClassName ~= "Model" then
		self._props.CFrame = target
		return
	end
	local pivot = self:GetPivot()
	local delta = target * pivot:Inverse()
	for _, p in ipairs(modelParts(self)) do
		local c = delta * p._props.CFrame
		-- como o motor do Roblox, mantém a rotação ortonormal (evita deriva numérica)
		local r = c.r
		local x = v3(r[1], r[4], r[7]).Unit
		local y = v3(r[2], r[5], r[8])
		y = (y - x * x:Dot(y)).Unit
		local z = x:Cross(y)
		p._props.CFrame = cf(c.p.X, c.p.Y, c.p.Z, { x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z })
	end
	self._pivot = target
end
function Inst.GetBoundingBox(self)
	local mn, mx = v3(math.huge, math.huge, math.huge), v3(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(modelParts(self)) do
		local c, s = p._props.CFrame.p, p._props.Size
		mn = v3(math.min(mn.X, c.X - s.X / 2), math.min(mn.Y, c.Y - s.Y / 2), math.min(mn.Z, c.Z - s.Z / 2))
		mx = v3(math.max(mx.X, c.X + s.X / 2), math.max(mx.Y, c.Y + s.Y / 2), math.max(mx.Z, c.Z + s.Z / 2))
	end
	if mn.X == math.huge then
		return cf(0, 0, 0), v3(0, 0, 0)
	end
	local c = (mn + mx) / 2
	return cf(c.X, c.Y, c.Z), mx - mn
end
function Inst.GetExtentsSize(self)
	local _, s = self:GetBoundingBox()
	return s
end

workspace = newInstance("Workspace")
game = newInstance("DataModel")
script = nil

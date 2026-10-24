-- Simulação do cliente Roblox para rodar o AnimController fora do Studio: instâncias com
-- eventos, Players/RunService/workspace, Vector3/Vector2, extensões de CFrame, task.*.
-- Usado por tools/sim/anim_sim.py (verifica que o jogador realmente se mexe).
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3 = {}
V3.__index = function(self, k)
	if k == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif k == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		return if m > 0 then v3(self.X / m, self.Y / m, self.Z / m) else v3(0, 0, 0)
	end
	return V3[k]
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, n)
	return v3(a.X / n, a.Y / n, a.Z / n)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
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
Vector3 = { new = v3, one = v3(1, 1, 1), zero = v3(0, 0, 0), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }

local function v2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
V2 = {}
V2.__index = function(self, k)
	if k == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y)
	end
	return V2[k]
end
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(b.X * a, b.Y * a)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
Vector2 = { new = v2, zero = v2(0, 0) }

-- extensões do CFrame da tools/cframe_stub.luau
local CFM = getmetatable(CFrame.identity)
local baseMul = CFM.__mul
CFM.__mul = function(a, b)
	if getmetatable(b) == V3 then
		local r, p = a.r, a.p
		return v3(p[1] + r[1] * b.X + r[2] * b.Y + r[3] * b.Z, p[2] + r[4] * b.X + r[5] * b.Y + r[6] * b.Z, p[3] + r[7] * b.X + r[8] * b.Y + r[9] * b.Z)
	end
	return baseMul(a, b)
end
CFM.__add = function(a, b)
	return CFrame.new(a.p[1] + b.X, a.p[2] + b.Y, a.p[3] + b.Z, table.unpack(a.r))
end
CFM.__sub = function(a, b)
	return CFrame.new(a.p[1] - b.X, a.p[2] - b.Y, a.p[3] - b.Z, table.unpack(a.r))
end
CFM.__index = function(self, k)
	local r = self.r
	if k == "Position" then
		return v3(self.p[1], self.p[2], self.p[3])
	elseif k == "Rotation" then
		return CFrame.new(0, 0, 0, table.unpack(r))
	elseif k == "LookVector" then
		return v3(-r[3], -r[6], -r[9])
	end
	return CFM[k]
end
function CFM:VectorToObjectSpace(v)
	local r = self.r
	return v3(r[1] * v.X + r[4] * v.Y + r[7] * v.Z, r[2] * v.X + r[5] * v.Y + r[8] * v.Z, r[3] * v.X + r[6] * v.Y + r[9] * v.Z)
end
function CFM:VectorToWorldSpace(v)
	local r = self.r
	return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
function CFM:PointToObjectSpace(v)
	local d = v - self.Position
	return self:VectorToObjectSpace(d)
end
function CFM:Inverse()
	local r = self.r
	local rt = { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
	local p = self.p
	return CFrame.new(-(rt[1] * p[1] + rt[2] * p[2] + rt[3] * p[3]), -(rt[4] * p[1] + rt[5] * p[2] + rt[6] * p[3]), -(rt[7] * p[1] + rt[8] * p[2] + rt[9] * p[3]), table.unpack(rt))
end
function CFM:GetComponents()
	return self.p[1], self.p[2], self.p[3], table.unpack(self.r)
end
CFM.__eq = function(a, b)
	for i = 1, 3 do
		if a.p[i] ~= b.p[i] then
			return false
		end
	end
	for i = 1, 9 do
		if a.r[i] ~= b.r[i] then
			return false
		end
	end
	return true
end

Color3 = {
	new = function(r, g, b)
		local c = { R = r or 0, G = g or 0, B = b or 0 }
		function c:Lerp(o, t)
			return Color3.new(self.R + (o.R - self.R) * t, self.G + (o.G - self.G) * t, self.B + (o.B - self.B) * t)
		end
		return c
	end,
	fromRGB = function(r, g, b)
		return Color3.new(r / 255, g / 255, b / 255)
	end,
}
ColorSequence = { new = function(...) return { ... } end }
ColorSequenceKeypoint = { new = function(...) return { ... } end }
NumberSequence = { new = function(...) return { ... } end }
NumberSequenceKeypoint = { new = function(...) return { ... } end }
NumberRange = { new = function(...) return { ... } end }
UDim2 = { new = function(...) return { ... } end, fromScale = function(...) return { ... } end, fromOffset = function(...) return { ... } end }

-- sinais
local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		local c = {}
		function c.Disconnect()
			for i, h in s.handlers do
				if h == fn then
					table.remove(s.handlers, i)
				end
			end
		end
		return c
	end
	function s:Fire(...)
		for _, h in table.clone(self.handlers) do
			h(...)
		end
	end
	function s:Wait()
		return coroutine.yield()
	end
	return s
end
SIGNAL = signal

Enum = setmetatable({}, {
	__index = function(_, kind)
		return setmetatable({}, {
			__index = function(_, name)
				return { Name = name, EnumType = kind, _id = kind .. "." .. name }
			end,
		})
	end,
})
-- enums comparáveis por ==: cache
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, kind)
		enumCache[kind] = enumCache[kind] or setmetatable({}, {
			__index = function(t, name)
				local e = { Name = name, EnumType = kind }
				rawset(t, name, e)
				return e
			end,
		})
		return enumCache[kind]
	end,
})

local Inst = {}
local EVENTS = { DescendantAdded = true, DescendantRemoving = true, AncestryChanged = true, ChildAdded = true, StateChanged = true }
Inst.__index = function(self, k)
	local m = rawget(Inst, k)
	if m then
		return m
	end
	local props = rawget(self, "_props")
	if props[k] ~= nil then
		return props[k]
	end
	if EVENTS[k] then
		props[k] = signal()
		return props[k]
	end
	return self:FindFirstChild(k)
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
			table.insert(rawget(v, "_children"), self)
			local a = v
			while a do
				a.DescendantAdded:Fire(self)
				a = rawget(a, "_parent")
			end
		end
		self.AncestryChanged:Fire(self, v)
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
Inst.WaitForChild = Inst.FindFirstChild
function Inst:FindFirstChildOfClass(class)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_class") == class then
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
		return c == "Part" or c == "MeshPart" or c == "WedgePart"
	end
	if class == "JointInstance" then
		return c == "Motor6D" or c == "Weld"
	end
	return c == class
end
function Inst:SetAttribute(k, v)
	rawget(self, "_attrs")[k] = v
end
function Inst:GetAttribute(k)
	return rawget(self, "_attrs")[k]
end
function Inst:GetAttributeChangedSignal()
	return signal()
end
function Inst:GetFullName()
	return rawget(self, "_props").Name
end
function Inst:Destroy()
	self.Parent = nil
end
Instance = {
	new = function(class)
		local props = { Name = class, ClassName = class }
		if class == "Part" or class == "MeshPart" or class == "WedgePart" then
			props.CFrame = CFrame.identity
			props.Size = Vector3.one
			props.Transparency = 0
		end
		return setmetatable({ _class = class, _children = {}, _attrs = {}, _props = props }, Inst)
	end,
}

-- agendador: task.delay/defer/spawn com relógio simulado
CLOCK = 0
local queue = {}
function SIM_CLOCK()
	return CLOCK
end
task = {
	spawn = function(fn, ...)
		if type(fn) == "thread" then
			coroutine.resume(fn, ...)
			return fn
		end
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err)
		end
		return co
	end,
	defer = function(fn, ...)
		local args = { ... }
		table.insert(queue, { at = CLOCK, fn = function()
			fn(table.unpack(args))
		end })
	end,
	delay = function(t, fn, ...)
		local args = { ... }
		local item = { at = CLOCK + t, fn = function()
			fn(table.unpack(args))
		end }
		table.insert(queue, item)
		return item
	end,
	wait = function()
		return 0
	end,
	cancel = function(item)
		item.cancelled = true
	end,
}
function RUN_QUEUE()
	local i = 1
	while i <= #queue do
		local item = queue[i]
		if item.at <= CLOCK then
			table.remove(queue, i)
			if not item.cancelled then
				item.fn()
			end
		else
			i += 1
		end
	end
end

workspace = Instance.new("Workspace")
workspace.CurrentCamera = { CFrame = CFrame.new(0, 5, 10) }
for _, name in { "Enemies", "Bosses", "NPCs" } do
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = workspace
end
local players = Instance.new("Players")
players.PlayerAdded = signal()
local localPlayer = Instance.new("Player")
localPlayer.Name = "Tester"
localPlayer.CharacterAdded = signal()
players.LocalPlayer = localPlayer
function players:GetPlayers()
	return { localPlayer }
end
function players:GetPlayerFromCharacter(model)
	return if model == localPlayer.Character then localPlayer else nil
end
local runService = { Stepped = signal(), Heartbeat = signal(), RenderStepped = signal() }
SERVICES = { Players = players, RunService = runService, Workspace = workspace }
game = {
	GetService = function(_, name)
		return SERVICES[name] or Instance.new(name)
	end,
}

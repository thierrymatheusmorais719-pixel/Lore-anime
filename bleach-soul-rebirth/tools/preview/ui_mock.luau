-- Ambiente mínimo do Roblox para rodar o código real de interface (HUD, menus) fora do Studio:
-- tipos de dados de UI, instâncias com propriedades/filhos/sinais, serviços, tweens instantâneos
-- e um carregador de módulos que segue a estrutura do Rojo (MODULES[caminho] preenchido pelo
-- tools/preview/ui.py). No fim, DUMP_GUI() imprime a árvore de cada ScreenGui em JSON.

-- ============================================================ tipos
local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local C3 = {}
C3.__index = C3
local function c3(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, C3)
end
function C3:Lerp(o, t)
	return c3(self.R + (o.R - self.R) * t, self.G + (o.G - self.G) * t, self.B + (o.B - self.B) * t)
end
function C3:ToHSV()
	local r, g, b = self.R, self.G, self.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then
			h = ((g - b) / d) % 6
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, if mx > 0 then d / mx else 0, mx
end
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
Color3 = {
	new = function(r, g, b)
		return c3(r or 0, g or 0, b or 0)
	end,
	fromRGB = function(r, g, b)
		return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
	end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		i %= 6
		if i == 0 then
			return c3(v, t, p)
		elseif i == 1 then
			return c3(q, v, p)
		elseif i == 2 then
			return c3(p, v, t)
		elseif i == 3 then
			return c3(p, q, v)
		elseif i == 4 then
			return c3(t, p, v)
		end
		return c3(v, p, q)
	end,
	fromHex = function(hex)
		hex = hex:gsub("#", "")
		return c3(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
	end,
}

local UD = {}
UD.__index = UD
UD.__add = function(a, b)
	return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset)
end
UDim = {
	new = function(s, o)
		return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD)
	end,
}
local UD2 = {}
UD2.__index = UD2
UD2.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UD2.__sub = function(a, b)
	return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
function UD2:Lerp(o, t)
	return UDim2.new(
		self.X.Scale + (o.X.Scale - self.X.Scale) * t,
		self.X.Offset + (o.X.Offset - self.X.Offset) * t,
		self.Y.Scale + (o.Y.Scale - self.Y.Scale) * t,
		self.Y.Offset + (o.Y.Offset - self.Y.Offset) * t
	)
end
UDim2 = {
	new = function(xs, xo, ys, yo)
		if type(xs) == "table" then
			return setmetatable({ X = xs, Y = xo, Width = xs, Height = xo }, UD2)
		end
		local x, y = UDim.new(xs, xo), UDim.new(ys, yo)
		return setmetatable({ X = x, Y = y, Width = x, Height = y }, UD2)
	end,
}
UDim2.fromScale = function(x, y)
	return UDim2.new(x, 0, y, 0)
end
UDim2.fromOffset = function(x, y)
	return UDim2.new(0, x, 0, y)
end

local V2 = {}
V2.__index = function(self, k)
	if k == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y)
	end
	return V2[k]
end
local function v2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(a * b.X, a * b.Y)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	return v2(a.X / b, a.Y / b)
end
Vector2 = { new = v2, zero = v2(0, 0), one = v2(1, 1) }

local V3 = {}
V3.__index = function(self, k)
	if k == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	elseif k == "Unit" then
		local m = math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
		return if m > 0 then Vector3.new(self.X / m, self.Y / m, self.Z / m) else Vector3.new()
	end
	return V3[k]
end
V3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
function V3:Lerp(o, t)
	return self + (o - self) * t
end
function V3:Dot(o)
	return self.X * o.X + self.Y * o.Y + self.Z * o.Z
end
function V3:Cross(o)
	return Vector3.new(self.Y * o.Z - self.Z * o.Y, self.Z * o.X - self.X * o.Z, self.X * o.Y - self.Y * o.X)
end
Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
	end,
}
Vector3.zero = Vector3.new()
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

local function seq(kind)
	return {
		new = function(a, b)
			if type(a) == "table" and a[1] then
				return { Keypoints = a, kind = kind }
			end
			local first = { Time = 0, Value = a }
			local last = { Time = 1, Value = if b ~= nil then b else a }
			return { Keypoints = { first, last }, kind = kind }
		end,
	}
end
ColorSequence = seq("color")
NumberSequence = seq("number")
ColorSequenceKeypoint = {
	new = function(t, v)
		return { Time = t, Value = v }
	end,
}
NumberSequenceKeypoint = {
	new = function(t, v, e)
		return { Time = t, Value = v, Envelope = e or 0 }
	end,
}
NumberRange = {
	new = function(a, b)
		return { Min = a, Max = b or a }
	end,
}
Rect = {
	new = function(...)
		return { ... }
	end,
}
TweenInfo = {
	new = function(...)
		return { ... }
	end,
}
Font = {
	new = function(family, weight, style)
		return { Family = family, Weight = weight, Style = style }
	end,
	fromEnum = function(e)
		return { Family = e.Name }
	end,
}
PhysicalProperties = {
	new = function(...)
		return { ... }
	end,
}
Content = {
	fromObject = function(o)
		return o
	end,
	fromUri = function(u)
		return u
	end,
}
DateTime = {
	now = function()
		return { UnixTimestamp = 0, UnixTimestampMillis = 0, FormatLocalTime = function()
			return "12:00"
		end }
	end,
}

local enumCache = {}
local function enumItem(kind, name)
	return { Name = name, EnumType = kind, Value = 0 }
end
Enum = setmetatable({}, {
	__index = function(_, kind)
		if not enumCache[kind] then
			local items = {}
			enumCache[kind] = setmetatable({}, {
				__index = function(t, name)
					if name == "GetEnumItems" then
						return function()
							return {}
						end
					end
					items[name] = items[name] or enumItem(kind, name)
					return items[name]
				end,
			})
		end
		return enumCache[kind]
	end,
})

-- ============================================================ sinais
local Signal = {}
Signal.__index = Signal
function newSignal()
	return setmetatable({ handlers = {} }, Signal)
end
function Signal:Connect(fn)
	table.insert(self.handlers, fn)
	local c = { Connected = true }
	function c.Disconnect()
		c.Connected = false
		for i, h in self.handlers do
			if h == fn then
				table.remove(self.handlers, i)
				break
			end
		end
	end
	return c
end
Signal.Once = Signal.Connect
function Signal:Fire(...)
	for _, h in table.clone(self.handlers) do
		local ok, err = pcall(h, ...)
		if not ok then
			print("[sinal] erro:", err)
		end
	end
end
function Signal:Wait()
	return nil
end

-- Objeto "mágico": aceita qualquer índice/chamada/Connect (stubs de controladores e remotes)
local Magic = {}
MAGIC = setmetatable({}, Magic)
Magic.__index = function(_, k)
	if k == "Connect" or k == "Once" then
		return function()
			return { Disconnect = function() end, Connected = true }
		end
	end
	return MAGIC
end
Magic.__call = function()
	return MAGIC
end

-- ============================================================ instâncias
local EVENT_NAMES = {
	Changed = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	DescendantRemoving = true,
	AncestryChanged = true,
	Destroying = true,
	MouseEnter = true,
	MouseLeave = true,
	MouseButton1Click = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	Activated = true,
	InputBegan = true,
	InputEnded = true,
	InputChanged = true,
	FocusLost = true,
	Focused = true,
	Completed = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	Heartbeat = true,
	RenderStepped = true,
	Stepped = true,
	OnClientEvent = true,
	Died = true,
	HealthChanged = true,
	StateChanged = true,
	Running = true,
	LastInputTypeChanged = true,
	TouchStarted = true,
	TouchEnded = true,
	JumpRequest = true,
	WindowFocused = true,
	WindowFocusReleased = true,
	MouseWheelForward = true,
	MouseWheelBackward = true,
	SelectionChanged = true,
	SelectionGained = true,
	SelectionLost = true,
	MouseMoved = true,
	TouchTap = true,
	TouchLongPress = true,
	TouchPan = true,
	ReturnPressedFromOnScreenKeyboard = true,
	MouseButton2Click = true,
	Triggered = true,
}

local DEFAULTS = {
	_GuiObject = {
		Visible = true,
		Size = UDim2.new(0, 100, 0, 100),
		Position = UDim2.new(0, 0, 0, 0),
		AnchorPoint = v2(0, 0),
		BackgroundColor3 = c3(163 / 255, 162 / 255, 165 / 255),
		BackgroundTransparency = 0,
		BorderSizePixel = 1,
		ZIndex = 1,
		LayoutOrder = 0,
		Rotation = 0,
		ClipsDescendants = false,
		AbsoluteSize = v2(100, 100),
		AbsolutePosition = v2(0, 0),
	},
	_Text = {
		Text = "Label",
		TextSize = 14,
		TextColor3 = c3(0, 0, 0),
		TextTransparency = 0,
		TextStrokeTransparency = 1,
		TextStrokeColor3 = c3(0, 0, 0),
		TextScaled = false,
		TextWrapped = false,
		RichText = false,
		LineHeight = 1,
		MaxVisibleGraphemes = -1,
	},
}
local GUI_CLASSES = {
	Frame = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
	ImageLabel = true,
	ImageButton = true,
	ScrollingFrame = true,
	ViewportFrame = true,
	CanvasGroup = true,
	VideoFrame = true,
}
local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

local Inst = {}
ALL_INSTANCES = {}
local counter = 0

local function new(class)
	counter += 1
	local props = { Name = class, ClassName = class }
	if GUI_CLASSES[class] then
		for k, v in DEFAULTS._GuiObject do
			props[k] = v
		end
	end
	if TEXT_CLASSES[class] then
		for k, v in DEFAULTS._Text do
			props[k] = v
		end
		props.Font = Enum.Font.Legacy
	end
	if class == "ImageLabel" or class == "ImageButton" then
		props.Image = ""
		props.ImageColor3 = c3(1, 1, 1)
		props.ImageTransparency = 0
	end
	if class == "ScrollingFrame" then
		props.ClipsDescendants = true
	end
	if class == "Part" or class == "MeshPart" then
		props.Size = Vector3.new(2, 1, 1)
		props.Position = Vector3.new(0, 0, 0)
	end
	if class == "ScreenGui" then
		props.Enabled = true
		props.DisplayOrder = 0
		props.IgnoreGuiInset = false
	end
	if class == "UIStroke" then
		props.Thickness = 1
		props.Transparency = 0
		props.Color = c3(0, 0, 0)
		props.Enabled = true
	end
	if class == "UIGradient" then
		props.Rotation = 0
		props.Offset = v2(0, 0)
		props.Enabled = true
	end
	if class == "UIScale" then
		props.Scale = 1
	end
	if class == "UIListLayout" then
		props.FillDirection = Enum.FillDirection.Vertical
		props.Padding = UDim.new(0, 0)
		props.SortOrder = Enum.SortOrder.Name
		props.HorizontalAlignment = Enum.HorizontalAlignment.Left
		props.VerticalAlignment = Enum.VerticalAlignment.Top
	end
	if class == "UIGridLayout" then
		props.CellSize = UDim2.new(0, 100, 0, 100)
		props.CellPadding = UDim2.new(0, 5, 0, 5)
		props.SortOrder = Enum.SortOrder.Name
		props.FillDirection = Enum.FillDirection.Horizontal
		props.HorizontalAlignment = Enum.HorizontalAlignment.Left
		props.VerticalAlignment = Enum.VerticalAlignment.Top
	end
	if class == "UIPadding" then
		for _, k in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
			props[k] = UDim.new(0, 0)
		end
	end
	if class == "UICorner" then
		props.CornerRadius = UDim.new(0, 8)
	end
	if class == "UIAspectRatioConstraint" then
		props.AspectRatio = 1
	end
	if class == "Camera" then
		props.ViewportSize = v2(1280, 720)
		props.CFrame = CFrame and CFrame.new() or nil
	end
	local self = setmetatable({ _class = class, _children = {}, _attrs = {}, _props = props, _signals = {}, _id = counter }, Inst)
	table.insert(ALL_INSTANCES, self)
	return self
end

Inst.__index = function(self, k)
	local m = rawget(Inst, k)
	if m ~= nil then
		return m
	end
	if k == "Parent" then
		return rawget(self, "_parent")
	end
	local props = rawget(self, "_props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	if EVENT_NAMES[k] then
		local signals = rawget(self, "_signals")
		signals[k] = signals[k] or newSignal()
		return signals[k]
	end
	local child = Inst.FindFirstChild(self, k)
	if child then
		return child
	end
	return nil
end
Inst.__newindex = function(self, k, v)
	if k == "Parent" then
		local old = rawget(self, "_parent")
		if old then
			local list = rawget(old, "_children")
			for i, c in list do
				if c == self then
					table.remove(list, i)
					break
				end
			end
		end
		rawset(self, "_parent", v)
		if v then
			table.insert(rawget(v, "_children"), self)
			local signals = rawget(v, "_signals")
			if signals.ChildAdded then
				signals.ChildAdded:Fire(self)
			end
		end
		return
	end
	local props = rawget(self, "_props")
	props[k] = v
	local changed = rawget(self, "_signals")["prop:" .. k]
	if changed then
		changed:Fire()
	end
end
Inst.__tostring = function(self)
	return rawget(self, "_props").Name
end
function Inst:GetPropertyChangedSignal(k)
	local signals = rawget(self, "_signals")
	signals["prop:" .. k] = signals["prop:" .. k] or newSignal()
	return signals["prop:" .. k]
end
function Inst:GetAttributeChangedSignal()
	return newSignal()
end
function Inst:FindFirstChild(name, recursive)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_props").Name == name then
			return c
		end
	end
	if recursive then
		for _, c in rawget(self, "_children") do
			local f = Inst.FindFirstChild(c, name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function Inst:WaitForChild(name)
	local c = Inst.FindFirstChild(self, name)
	if c then
		return c
	end
	-- cria vazio para o código seguir (pastas do workspace, PlayerGui)
	local made = new(if name == "PlayerGui" then "PlayerGui" else "Folder")
	made.Name = name
	made.Parent = self
	return made
end
function Inst:FindFirstChildOfClass(class)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_class") == class then
			return c
		end
	end
	return nil
end
Inst.FindFirstChildWhichIsA = Inst.FindFirstChildOfClass
function Inst:FindFirstAncestorOfClass(class)
	local p = rawget(self, "_parent")
	while p do
		if rawget(p, "_class") == class then
			return p
		end
		p = rawget(p, "_parent")
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
	if class == "GuiObject" then
		return GUI_CLASSES[c] == true
	elseif class == "GuiButton" then
		return c == "TextButton" or c == "ImageButton"
	elseif class == "BasePart" then
		return c == "Part" or c == "MeshPart" or c == "WedgePart"
	elseif class == "LayerCollector" then
		return c == "ScreenGui" or c == "BillboardGui" or c == "SurfaceGui"
	elseif class == "Instance" then
		return true
	end
	return c == class
end
function Inst:IsDescendantOf(a)
	local p = rawget(self, "_parent")
	while p do
		if p == a then
			return true
		end
		p = rawget(p, "_parent")
	end
	return false
end
function Inst:SetAttribute(k, v)
	rawget(self, "_attrs")[k] = v
end
function Inst:GetAttribute(k)
	return rawget(self, "_attrs")[k]
end
function Inst:GetAttributes()
	return table.clone(rawget(self, "_attrs"))
end
function Inst:Destroy()
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
function Inst:ClearAllChildren()
	for _, c in table.clone(rawget(self, "_children")) do
		c:Destroy()
	end
end
function Inst:Clone()
	local copy = new(rawget(self, "_class"))
	for k, v in rawget(self, "_props") do
		rawget(copy, "_props")[k] = v
	end
	for _, c in rawget(self, "_children") do
		c:Clone().Parent = copy
	end
	return copy
end
function Inst:GetFullName()
	return rawget(self, "_props").Name
end
function Inst:CaptureFocus() end
function Inst:ReleaseFocus() end
function Inst:TweenSize() end
function Inst:TweenPosition() end
function Inst:PivotTo() end
function Inst:GetPivot()
	return CFrame and CFrame.new() or nil
end
function Inst:LoadAnimation()
	return MAGIC
end

Instance = { new = function(class, parent)
	local i = new(class)
	if parent then
		i.Parent = parent
	end
	return i
end }

-- ============================================================ serviços
VIEWPORT = v2(1280, 720)
workspace = new("Workspace")
local camera = new("Camera")
camera.Name = "Camera"
rawget(camera, "_props").ViewportSize = VIEWPORT
workspace.CurrentCamera = camera
camera.Parent = workspace
for _, n in { "Enemies", "Bosses", "NPCs", "Map", "ClientVFX" } do
	local f = new("Folder")
	f.Name = n
	f.Parent = workspace
end

local players = new("Players")
local localPlayer = new("Player")
localPlayer.Name = "Ichigo"
localPlayer.DisplayName = "Ichigo"
localPlayer.UserId = 1
localPlayer.Parent = players
local playerGui = new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = localPlayer
players.LocalPlayer = localPlayer
function players:GetPlayers()
	return { localPlayer }
end
function players:GetPlayerFromCharacter()
	return nil
end
PLAYER_GUI = playerGui

local tweenService = new("TweenService")
function tweenService:Create(instance, _info, goal)
	local t = { Completed = newSignal(), PlaybackState = Enum.PlaybackState.Completed }
	function t:Play()
		-- prévia: estado final imediato
		for k, v in goal do
			instance[k] = v
		end
		t.Completed:Fire(Enum.PlaybackState.Completed)
	end
	function t:Cancel() end
	function t:Pause() end
	return t
end
function tweenService:GetValue(alpha)
	return alpha
end

local uis = new("UserInputService")
uis.TouchEnabled = false
uis.KeyboardEnabled = true
uis.GamepadEnabled = false
uis.MouseEnabled = true
uis.MouseBehavior = Enum.MouseBehavior.Default
uis.MouseIconEnabled = true
function uis:GetLastInputType()
	return Enum.UserInputType.Keyboard
end
function uis:IsKeyDown()
	return false
end
function uis:GetMouseLocation()
	return v2(0, 0)
end
function uis:GetConnectedGamepads()
	return {}
end
function uis:GetFocusedTextBox()
	return nil
end
function uis:IsMouseButtonPressed()
	return false
end

local guiService = new("GuiService")
function guiService:GetGuiInset()
	return v2(0, 36), v2(0, 0)
end
guiService.SelectedObject = nil

local runService = new("RunService")
function runService:IsStudio()
	return true
end
function runService:IsClient()
	return true
end
function runService:IsServer()
	return false
end
function runService:BindToRenderStep() end
function runService:UnbindFromRenderStep() end

local lighting = new("Lighting")
local replicated = nil -- definido pelo carregador (proxy de pasta)

local services = {
	Players = players,
	TweenService = tweenService,
	UserInputService = uis,
	GuiService = guiService,
	RunService = runService,
	Lighting = lighting,
	Workspace = workspace,
}
game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return replicated
		end
		if not services[name] then
			services[name] = new(name)
		end
		return services[name]
	end,
	Workspace = workspace,
	PlaceId = 0,
	JobId = "",
}
game.FindService = game.GetService
function SET_REPLICATED(proxy)
	replicated = proxy
end

-- ============================================================ tarefas
CLOCK = 0
local queue = {}
task = {
	spawn = function(fn, ...)
		if type(fn) == "thread" then
			coroutine.resume(fn, ...)
			return fn
		end
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			print("[task.spawn] erro:", err)
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
		local item = { at = CLOCK + (t or 0), fn = function()
			fn(table.unpack(args))
		end }
		table.insert(queue, item)
		return item
	end,
	wait = function(t)
		local co = coroutine.running()
		if co and coroutine.isyieldable() then
			table.insert(queue, { at = CLOCK + (t or 0.03), fn = function()
				coroutine.resume(co)
			end })
			coroutine.yield()
		end
		return t or 0
	end,
	cancel = function(item)
		if type(item) == "table" then
			item.cancelled = true
		end
	end,
}
wait = task.wait
spawn = task.spawn
delay = task.delay
tick = function()
	return CLOCK
end
-- os é somente leitura no luau: o ui.py troca os.clock() por OS_CLOCK() nos módulos
function OS_CLOCK()
	return CLOCK
end
function ADVANCE(seconds)
	local target = CLOCK + seconds
	while true do
		local nextItem, index = nil, nil
		for i, item in queue do
			if item.at <= target and (not nextItem or item.at < nextItem.at) then
				nextItem, index = item, i
			end
		end
		if not nextItem then
			break
		end
		table.remove(queue, index)
		CLOCK = math.max(CLOCK, nextItem.at)
		if not nextItem.cancelled then
			local ok, err = pcall(nextItem.fn)
			if not ok then
				print("[tarefa] erro:", err)
			end
		end
	end
	CLOCK = target
	runService.Heartbeat:Fire(seconds)
	runService.RenderStepped:Fire(seconds)
end

warn = function(...)
	print("[warn]", ...)
end

-- ============================================================ carregador de módulos
-- MODULES["src/client/Controllers/HUDController"] = function(script) ... end (gerado pelo ui.py)
MODULES = MODULES or {}
DIRS = DIRS or {}
STUBS = STUBS or {}
local loaded = {}
local Proxy = {}
local function proxy(path, name)
	return setmetatable({ _path = path, Name = name }, Proxy)
end
Proxy.__index = function(self, k)
	if k == "Parent" then
		local parent = rawget(self, "_path"):match("^(.*)/[^/]+$")
		return if parent then proxy(parent, parent:match("[^/]+$")) else nil
	end
	local m = rawget(Proxy, k)
	if m then
		return m
	end
	local path = rawget(self, "_path") .. "/" .. k
	if MODULES[path] or DIRS[path] or STUBS[path] then
		return proxy(path, k)
	end
	return nil
end
function Proxy:WaitForChild(k)
	return self[k]
end
function Proxy:FindFirstChild(k)
	return self[k]
end
function Proxy:GetChildren()
	local out = {}
	local prefix = rawget(self, "_path") .. "/"
	for path in MODULES do
		local rest = path:sub(#prefix + 1)
		if path:sub(1, #prefix) == prefix and not rest:find("/") then
			table.insert(out, proxy(path, rest))
		end
	end
	return out
end
function Proxy:IsA(class)
	return class == "ModuleScript" and MODULES[rawget(self, "_path")] ~= nil
end
function Proxy:GetAttribute()
	return nil
end
PATH_PROXY = proxy

local realRequire = require
require = function(target)
	if type(target) == "table" and rawget(target, "_path") then
		local path = rawget(target, "_path")
		if STUBS[path] then
			return STUBS[path]
		end
		if loaded[path] == nil then
			local fn = MODULES[path]
			if not fn then
				error("módulo não encontrado: " .. path)
			end
			loaded[path] = fn(target)
		end
		return loaded[path]
	end
	return realRequire(target)
end

-- ============================================================ dump
local function num(x)
	return string.format("%.3f", x or 0)
end
local function color(c)
	if not c then
		return "null"
	end
	return string.format("[%s,%s,%s]", num(c.R), num(c.G), num(c.B))
end
local function udim2(u)
	if not u then
		return "null"
	end
	return string.format("[%s,%s,%s,%s]", num(u.X.Scale), num(u.X.Offset), num(u.Y.Scale), num(u.Y.Offset))
end
local function str(s)
	s = tostring(s or "")
	s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", ""):gsub("\t", " ")
	return '"' .. s .. '"'
end
local function enumName(e)
	if type(e) == "table" and e.Name then
		return str(e.Name)
	end
	return "null"
end
local function seqJson(s)
	if not s or not s.Keypoints then
		return "null"
	end
	local out = {}
	for _, kp in s.Keypoints do
		if type(kp.Value) == "table" then
			table.insert(out, string.format("[%s,%s]", num(kp.Time), color(kp.Value)))
		else
			table.insert(out, string.format("[%s,%s]", num(kp.Time), num(kp.Value)))
		end
	end
	return "[" .. table.concat(out, ",") .. "]"
end

local function dumpNode(i)
	local p = rawget(i, "_props")
	local class = rawget(i, "_class")
	local fields = { '"c":' .. str(class), '"n":' .. str(p.Name) }
	local function add(k, v)
		table.insert(fields, '"' .. k .. '":' .. v)
	end
	if GUI_CLASSES[class] then
		add("pos", udim2(p.Position))
		add("size", udim2(p.Size))
		add("anchor", string.format("[%s,%s]", num(p.AnchorPoint.X), num(p.AnchorPoint.Y)))
		add("bg", color(p.BackgroundColor3))
		add("bgt", num(p.BackgroundTransparency))
		add("vis", tostring(p.Visible ~= false))
		add("z", tostring(p.ZIndex or 1))
		add("order", tostring(p.LayoutOrder or 0))
		add("rot", num(p.Rotation))
		add("clip", tostring(p.ClipsDescendants == true))
		add("border", tostring(p.BorderSizePixel or 0))
		if p.AutomaticSize then
			add("auto", enumName(p.AutomaticSize))
		end
		if p.GroupTransparency then
			add("gt", num(p.GroupTransparency))
		end
	end
	if TEXT_CLASSES[class] then
		add("text", str(p.Text))
		add("ts", num(p.TextSize))
		add("tc", color(p.TextColor3))
		add("tt", num(p.TextTransparency))
		add("tst", num(p.TextStrokeTransparency))
		add("tsc", color(p.TextStrokeColor3))
		add("font", enumName(p.Font))
		add("xa", enumName(p.TextXAlignment))
		add("ya", enumName(p.TextYAlignment))
		add("scaled", tostring(p.TextScaled == true))
		add("wrap", tostring(p.TextWrapped == true))
		add("rich", tostring(p.RichText == true))
		if p.TextTruncate then
			add("trunc", enumName(p.TextTruncate))
		end
		if p.PlaceholderText then
			add("ph", str(p.PlaceholderText))
		end
	end
	if class == "ImageLabel" or class == "ImageButton" then
		add("img", str(p.Image))
		add("ic", color(p.ImageColor3))
		add("it", num(p.ImageTransparency))
	end
	if class == "ScreenGui" or class == "BillboardGui" or class == "SurfaceGui" then
		add("enabled", tostring(p.Enabled ~= false))
		add("display", tostring(p.DisplayOrder or 0))
		add("inset", tostring(p.IgnoreGuiInset == true))
	end
	if class == "UICorner" then
		add("radius", string.format("[%s,%s]", num(p.CornerRadius.Scale), num(p.CornerRadius.Offset)))
	elseif class == "UIStroke" then
		add("color", color(p.Color))
		add("thick", num(p.Thickness))
		add("t", num(p.Transparency))
		add("enabled", tostring(p.Enabled ~= false))
		add("mode", enumName(p.ApplyStrokeMode))
	elseif class == "UIGradient" then
		add("color", seqJson(p.Color))
		add("transp", seqJson(p.Transparency))
		add("rot", num(p.Rotation))
		add("enabled", tostring(p.Enabled ~= false))
	elseif class == "UIListLayout" or class == "UIGridLayout" then
		add("dir", enumName(p.FillDirection))
		add("halign", enumName(p.HorizontalAlignment))
		add("valign", enumName(p.VerticalAlignment))
		add("sort", enumName(p.SortOrder))
		if class == "UIListLayout" then
			add("pad", string.format("[%s,%s]", num(p.Padding.Scale), num(p.Padding.Offset)))
		else
			add("cell", udim2(p.CellSize))
			add("cellpad", udim2(p.CellPadding))
		end
	elseif class == "UIPadding" then
		add(
			"pads",
			string.format(
				"[%s,%s,%s,%s,%s,%s,%s,%s]",
				num(p.PaddingTop.Scale),
				num(p.PaddingTop.Offset),
				num(p.PaddingBottom.Scale),
				num(p.PaddingBottom.Offset),
				num(p.PaddingLeft.Scale),
				num(p.PaddingLeft.Offset),
				num(p.PaddingRight.Scale),
				num(p.PaddingRight.Offset)
			)
		)
	elseif class == "UIScale" then
		add("scale", num(p.Scale))
	elseif class == "UITextSizeConstraint" then
		add("maxts", num(p.MaxTextSize or 100))
	elseif class == "UIAspectRatioConstraint" then
		add("ratio", num(p.AspectRatio))
	elseif class == "UISizeConstraint" then
		if p.MaxSize then
			add("max", string.format("[%s,%s]", num(math.min(p.MaxSize.X, 1e6)), num(math.min(p.MaxSize.Y, 1e6))))
		end
		if p.MinSize then
			add("min", string.format("[%s,%s]", num(p.MinSize.X), num(p.MinSize.Y)))
		end
	end
	local kids = {}
	for _, c in rawget(i, "_children") do
		local cc = rawget(c, "_class")
		if GUI_CLASSES[cc] or cc:sub(1, 2) == "UI" or cc == "ScreenGui" or cc == "Folder" then
			table.insert(kids, dumpNode(c))
		end
	end
	add("kids", "[" .. table.concat(kids, ",") .. "]")
	return "{" .. table.concat(fields, ",") .. "}"
end
function DUMP_GUI(label)
	local guis = {}
	for _, g in rawget(PLAYER_GUI, "_children") do
		if rawget(g, "_class") == "ScreenGui" then
			table.insert(guis, dumpNode(g))
		end
	end
	print('{"label":' .. str(label) .. ',"guis":[' .. table.concat(guis, ",") .. "]}")
end

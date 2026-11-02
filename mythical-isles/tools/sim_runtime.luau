-- Simulador de servidor Roblox (para tools/run_tests.py --sim).
-- Roda o código REAL de src/server sobre:
--   * relógio virtual + agendador de task.spawn/wait/delay/defer
--   * serviços em memória: Players, RunService, DataStoreService (serializa como JSON),
--     MessagingService, HttpService, PathfindingService (sempre sem caminho => usa a alternativa)
--   * física mínima: AlignPosition e Humanoid:MoveTo movem o modelo; Raycast acerta o chão das ilhas
-- NÃO simula: colisão entre peças, renderização, cliente, rede real.

local V3, C3, Inst, CFm = __MOCK_V3, __MOCK_C3, __MOCK_INST, __MOCK_CF
SIM = { now = 0, base = 1800000000, queue = {}, heartbeat = {}, errors = {}, warnings = {}, align = {}, humanoids = {}, outbox = {}, kicked = {} }

-------------------------------------------------------------------------------
-- Agendador
-------------------------------------------------------------------------------
local function pushQueue(item)
	table.insert(SIM.queue, item)
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		local msg = debug.traceback(co, tostring(err))
		table.insert(SIM.errors, msg)
		print("[ERRO NO SERVIDOR] " .. msg)
	end
end
local simTask = {}
function simTask.spawn(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	resume(co, ...)
	return co
end
function simTask.defer(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	pushQueue({ t = SIM.now, co = co, args = table.pack(...) })
	return co
end
function simTask.delay(t, f, ...)
	local co = coroutine.create(f)
	pushQueue({ t = SIM.now + (t or 0), co = co, args = table.pack(...) })
	return co
end
function simTask.wait(t)
	local co = coroutine.running()
	assert(co and coroutine.isyieldable(), "task.wait fora de corrotina")
	local start = SIM.now
	pushQueue({ t = SIM.now + (t or 1 / 60), co = co, args = table.pack() })
	coroutine.yield()
	return SIM.now - start
end
function simTask.cancel() end
SIM.task = simTask
SIM.os = {
	clock = function()
		return SIM.now
	end,
	time = function()
		return SIM.base + math.floor(SIM.now)
	end,
	date = os.date,
	difftime = os.difftime,
}

-------------------------------------------------------------------------------
-- Sinais
-------------------------------------------------------------------------------
local function Signal()
	local s = { _conns = {} }
	function s:Connect(fn)
		local c = { fn = fn, connected = true }
		function c:Disconnect()
			c.connected = false
		end
		table.insert(s._conns, c)
		return c
	end
	s.Once = s.Connect
	function s:Fire(...)
		for _, c in ipairs(table.clone(s._conns)) do
			if c.connected then
				simTask.spawn(c.fn, ...)
			end
		end
	end
	function s:Wait()
		return nil
	end
	return s
end
SIM.Signal = Signal

local SIGNALS = {
	ChildAdded = true, ChildRemoved = true, DescendantAdded = true, AncestryChanged = true, Triggered = true, OnServerEvent = true,
	CharacterAdded = true, HealthChanged = true, Changed = true, Touched = true, Died = true,
	OnClientEvent = true, TouchTapInWorld = true, Activated = true, MouseButton1Click = true, InputBegan = true, InputEnded = true, MouseEnter = true, MouseLeave = true,
}
local CLASS_METHODS = {}
__MOCK_INDEX_HOOK = function(t, k)
	if SIGNALS[k] then
		local s = Signal()
		t._props[k] = s
		return s
	end
	local cm = CLASS_METHODS[t._props.ClassName]
	if cm and cm[k] then
		return cm[k]
	end
	return nil
end
function Inst.GetAttributeChangedSignal(self, name)
	self._attrSignals = self._attrSignals or {}
	local s = self._attrSignals[name]
	if not s then
		s = Signal()
		self._attrSignals[name] = s
	end
	return s
end
function Inst.GetPropertyChangedSignal(self, _name)
	return Signal()
end
local origSetAttr = Inst.SetAttribute
function Inst.SetAttribute(self, k, v)
	origSetAttr(self, k, v)
	local s = self._attrSignals and self._attrSignals[k]
	if s then
		s:Fire()
	end
end

-------------------------------------------------------------------------------
-- Classes com comportamento
-------------------------------------------------------------------------------
__MOCK_ON_NEW = function(t, cls)
	if cls == "Humanoid" then
		t._props.Health = 100
		t._props.MaxHealth = 100
		t._props.WalkSpeed = 16
		t._props.HipHeight = 2
		table.insert(SIM.humanoids, t)
	elseif cls == "AlignPosition" then
		t._props.MaxVelocity = 1e9
		table.insert(SIM.align, t)
	elseif cls == "Part" or cls == "WedgePart" or cls == "SpawnLocation" then
		t._props.Anchored = false
	end
end
CLASS_METHODS.Humanoid = {
	MoveTo = function(self, pos)
		if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then
			error("Humanoid:MoveTo com NaN: " .. tostring(pos.X) .. "," .. tostring(pos.Y) .. "," .. tostring(pos.Z), 2)
		end
		self._props._moveTarget = pos
	end,
	TakeDamage = function(self, n)
		self._props.Health = math.max(0, self._props.Health - n)
		local s = rawget(self._props, "HealthChanged")
		if s then
			s:Fire(self._props.Health)
		end
	end,
	SetStateEnabled = function() end,
	GetState = function()
		return Enum.HumanoidStateType.Running
	end,
}
CLASS_METHODS.RemoteEvent = {
	FireClient = function(self, player, kind, payload)
		SIM.checkRemote(payload, "FireClient " .. tostring(kind))
		local box = SIM.outbox[player]
		if not box then
			box = {}
			SIM.outbox[player] = box
		end
		table.insert(box, { kind = kind, payload = payload, t = SIM.now })
		if SIM.localPlayer == player then
			self.OnClientEvent:Fire(kind, payload) -- cliente simulado recebe ao vivo
		end
	end,
	FireAllClients = function() end,
	FireServer = function(self, ...)
		self.OnServerEvent:Fire(SIM.localPlayer, ...)
	end,
}
CLASS_METHODS.ParticleEmitter = { Emit = function() end, Clear = function() end }
CLASS_METHODS.RemoteFunction = {
	InvokeServer = function(self, ...)
		return self.OnServerInvoke(SIM.localPlayer, ...)
	end,
}
CLASS_METHODS.Camera = {
	ViewportPointToRay = function(self, x, y)
		return { Origin = self.CFrame.p, Direction = Vector3.new(0, -1, 0) }
	end,
	ScreenPointToRay = function(self, x, y)
		return { Origin = self.CFrame.p, Direction = Vector3.new(0, -1, 0) }
	end,
}
CLASS_METHODS.Terrain = {
	FillCylinder = function() end, FillBall = function() end, FillBlock = function() end, SetMaterialColor = function() end, Clear = function() end,
}
local function makeCharacter(p)
	local char = Instance.new("Model")
	char.Name = p.Name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(0, 3, 14)
	root.Parent = char
	char.PrimaryPart = root
	local hum = Instance.new("Humanoid")
	hum.Name = "Humanoid"
	hum.Parent = char
	char.Parent = workspace
	return char
end
SIM.makeCharacter = makeCharacter
CLASS_METHODS.Player = {
	Kick = function(self, msg)
		SIM.kicked[self] = msg
	end,
	LoadCharacter = function(self)
		if self.Character then
			self.Character:Destroy()
		end
		local char = makeCharacter(self)
		self.Character = char
		SIM.loads = (SIM.loads or 0) + 1
		self.CharacterAdded:Fire(char)
	end,
}

-- Checa se um valor pode atravessar um RemoteEvent (sem tabelas mistas, sem funções).
function SIM.checkRemote(v, where, depth)
	depth = depth or 0
	local tv = type(v)
	if tv == "function" or tv == "thread" then
		error("valor não enviável por remote em " .. where)
	end
	if tv ~= "table" or getmetatable(v) ~= nil then
		return
	end
	assert(depth < 40, "tabela profunda demais em " .. where)
	local hasNum, hasStr = false, false
	for k, x in pairs(v) do
		if type(k) == "number" then
			hasNum = true
		elseif type(k) == "string" then
			hasStr = true
		else
			error("chave inválida em " .. where)
		end
		SIM.checkRemote(x, where, depth + 1)
	end
	if hasNum and hasStr then
		error("tabela mista (array + dicionário) não atravessa remotes: " .. where)
	end
end

-------------------------------------------------------------------------------
-- Serviços
-------------------------------------------------------------------------------
local function service(cls)
	local s = Instance.new(cls)
	s.Name = cls
	return s
end
workspace = Instance.new("Workspace")
workspace.Name = "Workspace"
local terrain = Instance.new("Terrain")
terrain.Name = "Terrain"
terrain.Parent = workspace
SIM.groundPlanes = {}
function workspace.GetServerTimeNow()
	return SIM.base + SIM.now
end
function workspace.Raycast(_, origin, dir, _params)
	if dir.Y >= 0 then
		return nil
	end
	for _, g in ipairs(SIM.groundPlanes) do
		local t = (g.y - origin.Y) / dir.Y
		if t >= 0 and t <= 1 then
			local hit = origin + dir * t
			local d = ((hit - g.center) * Vector3.new(1, 0, 1)).Magnitude
			if d <= g.radius then
				return { Position = hit, Instance = terrain, Normal = Vector3.new(0, 1, 0), Material = Enum.Material.Grass, Distance = t * dir.Magnitude }
			end
		end
	end
	return nil
end

local Players = service("Players")
Players.PlayerAdded = Signal()
Players.PlayerRemoving = Signal()
SIM.players = {}
function Players.GetPlayers()
	return table.clone(SIM.players)
end

local RunService = service("RunService")
RunService.Heartbeat = { Connect = function(_, fn)
	table.insert(SIM.heartbeat, fn)
	return { Disconnect = function() end }
end }
RunService.Stepped = RunService.Heartbeat
function RunService.IsStudio()
	return false
end
function RunService.IsServer()
	return true
end
function RunService.IsClient()
	return false
end

local DataStoreService = service("DataStoreService")
SIM.stores = {}
local function encode(v, path)
	local tv = type(v)
	if tv == "table" then
		assert(getmetatable(v) == nil, "DataStore não salva " .. path .. " (tipo do Roblox)")
		local out = {}
		local hasNum, hasStr = false, false
		for k, x in pairs(v) do
			if type(k) == "number" then
				hasNum = true
			else
				assert(type(k) == "string", "chave inválida em " .. path)
				hasStr = true
			end
			out[k] = encode(x, path .. "." .. tostring(k))
		end
		assert(not (hasNum and hasStr), "tabela mista não é salva corretamente pelo DataStore: " .. path)
		return out
	end
	assert(tv == "string" or tv == "number" or tv == "boolean" or v == nil, "DataStore não salva " .. tv .. " em " .. path)
	if tv == "number" then
		assert(v == v and v ~= math.huge and v ~= -math.huge, "número inválido em " .. path)
	end
	return v
end
SIM.encode = encode
function DataStoreService.GetDataStore(_, name)
	local store = SIM.stores[name]
	if store then
		return store
	end
	store = { data = {}, writes = 0 }
	function store.GetAsync(self, key)
		return self.data[key] and encode(self.data[key], key)
	end
	function store.UpdateAsync(self, key, fn)
		local current = self.data[key] and encode(self.data[key], key)
		local new = fn(current)
		if new ~= nil then
			self.data[key] = encode(new, key)
			self.writes += 1
		end
		return new
	end
	SIM.stores[name] = store
	return store
end

local MessagingService = service("MessagingService")
SIM.subs = {}
function MessagingService.PublishAsync(_, topic, data)
	SIM.checkRemote(data, "MessagingService")
	for _, cb in ipairs(SIM.subs[topic] or {}) do
		simTask.defer(cb, { Data = data, Sent = SIM.now })
	end
	SIM.published = (SIM.published or 0) + 1
end
function MessagingService.SubscribeAsync(_, topic, cb)
	SIM.subs[topic] = SIM.subs[topic] or {}
	table.insert(SIM.subs[topic], cb)
end

local HttpService = service("HttpService")
local guid = 0
function HttpService.GenerateGUID()
	guid += 1
	return string.format("guid-%06d", guid)
end
function HttpService.JSONEncode(_, v)
	return tostring(v)
end

local PathfindingService = service("PathfindingService")
function PathfindingService.CreatePath()
	return {
		Status = Enum.PathStatus.NoPath,
		ComputeAsync = function(self)
			self.Status = Enum.PathStatus.NoPath
		end,
		GetWaypoints = function()
			return {}
		end,
	}
end

local ReplicatedStorage = service("ReplicatedStorage")
__MOCK_WAIT_HOOK = function(inst, name)
	if inst == ReplicatedStorage and name == "Shared" then
		return __proxy("Shared")
	end
	return nil
end
local services = {
	Players = Players, RunService = RunService, DataStoreService = DataStoreService, MessagingService = MessagingService,
	HttpService = HttpService, PathfindingService = PathfindingService, ReplicatedStorage = ReplicatedStorage, Workspace = workspace,
	TweenService = service("TweenService"), Debris = service("Debris"), Lighting = service("Lighting"),
}
function SIM.registerService(name, inst)
	services[name] = inst
end
TweenInfo = { new = function(...)
	return { ... }
end }
services.TweenService.Create = function(_, inst, _info, goal)
	return { Play = function()
		for k, v in pairs(goal) do
			inst[k] = v
		end
	end, Cancel = function() end, Completed = Signal() }
end
game = Instance.new("DataModel")
game.JobId = "sim-job-1"
function game.GetService(_, name)
	local s = services[name]
	assert(s, "serviço não simulado: " .. name)
	return s
end
function game.BindToClose(_, fn)
	SIM.onClose = fn
end

-------------------------------------------------------------------------------
-- Tipos utilitários
-------------------------------------------------------------------------------
RaycastParams = { new = function()
	return {}
end }
Random = { new = function(seed)
	local state = (seed or 12345) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local r = {}
	function r.NextNumber(_, a, b)
		state = (state * 48271) % 2147483647
		local x = (state - 1) / 2147483646
		if a then
			return a + (b - a) * x
		end
		return x
	end
	function r.NextInteger(self, a, b)
		return math.floor(self:NextNumber(a, b + 1 - 1e-9))
	end
	return r
end }
SIM.typeof = function(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if mt == Inst then
			return "Instance"
		elseif mt == V3 then
			return "Vector3"
		elseif mt == C3 then
			return "Color3"
		elseif mt == CFm then
			return "CFrame"
		end
	end
	return typeof(v)
end
SIM.warn = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		table.insert(parts, tostring((select(i, ...))))
	end
	table.insert(SIM.warnings, table.concat(parts, " "))
end

-------------------------------------------------------------------------------
-- Física mínima + passo de simulação
-------------------------------------------------------------------------------
local function modelOf(part)
	local p = part
	while p and p._props.ClassName ~= "Model" do
		p = p._props.Parent
	end
	return p
end
local function moveModel(model, root, newPos)
	local cfr = root.CFrame
	local target = cfr.Rotation + newPos
	if model then
		model:PivotTo(target)
	else
		root.CFrame = target
	end
end
local function nanCheck(where)
	for _, h in ipairs(SIM.humanoids) do
		local m = h.Parent
		local r = m and m:FindFirstChild("HumanoidRootPart")
		if r and not rawget(SIM, "nanReported") then
			local p = r.Position
			local rr = r.CFrame.r
			local bad = p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z
			for i = 1, 9 do
				if rr[i] ~= rr[i] then
					bad = true
				end
			end
			if bad then
				SIM.nanReported = true
				table.insert(SIM.errors, "NaN em " .. tostring(m.Name))
				print("[NaN] detectado " .. where .. " em " .. tostring(m.Name) .. " estado=" .. tostring(m:GetAttribute("State")) .. " acao=" .. tostring(m:GetAttribute("Action")))
			end
		end
	end
end
SIM.nanCheck = nanCheck
local function physics(dt)
	nanCheck("antes da física")
	for i = #SIM.align, 1, -1 do
		local a = SIM.align[i]
		local att = a.Attachment0
		local part = att and att.Parent
		if a._destroyed or not part or part._destroyed then
			table.remove(SIM.align, i)
		elseif a.Position then
			local model = modelOf(part)
			if model and model.Parent then
				local delta = a.Position - part.Position
				local step = math.min(delta.Magnitude, (a.MaxVelocity or 1e9) * dt)
				if step > 1e-4 then
					moveModel(model, model.PrimaryPart or part, (model.PrimaryPart or part).Position + delta.Unit * step)
				end
			end
		end
	end
	for i = #SIM.humanoids, 1, -1 do
		local h = SIM.humanoids[i]
		local model = h.Parent
		if h._destroyed or not model then
			table.remove(SIM.humanoids, i)
		else
			local root = model:FindFirstChild("HumanoidRootPart")
			local target = h._props._moveTarget
			if root and target and model.Parent then
				local flat = (target - root.Position) * Vector3.new(1, 0, 1)
				local step = math.min(flat.Magnitude, h.WalkSpeed * dt)
				if step > 1e-4 then
					moveModel(model, root, root.Position + flat.Unit * step)
				end
			end
		end
	end
end

-- Avança a simulação em passos de `dt` até completar `seconds`.
function SIM.run(seconds, dt)
	dt = dt or 1 / 30
	local stop = SIM.now + seconds
	while SIM.now < stop - 1e-9 do
		SIM.now += dt
		for _, fn in ipairs(SIM.heartbeat) do
			local ok, err = pcall(fn, dt)
			if not ok then
				table.insert(SIM.errors, "Heartbeat: " .. tostring(err))
				print("[ERRO HEARTBEAT] " .. tostring(err))
			end
		end
		physics(dt)
		nanCheck("depois da física")
		-- acorda o que venceu (em ordem de tempo)
		local guard = 0
		while true do
			guard += 1
			local best, bi = nil, nil
			for i, it in ipairs(SIM.queue) do
				if it.t <= SIM.now and (not best or it.t < best.t) then
					best, bi = it, i
				end
			end
			if not best or guard > 5000 then
				break
			end
			table.remove(SIM.queue, bi)
			resume(best.co, table.unpack(best.args, 1, best.args.n))
		end
	end
end

-- Jogador simulado com personagem (HumanoidRootPart + Humanoid).
function SIM.addPlayer(name, userId)
	local p = Instance.new("Player")
	p.Name = name
	p.DisplayName = name
	p.UserId = userId
	p.Parent = Players
	table.insert(SIM.players, p)
	Players.PlayerAdded:Fire(p) -- o servidor chama LoadCharacter (CharacterAutoLoads = false)
	return p
end
function SIM.removePlayer(p)
	Players.PlayerRemoving:Fire(p)
	local i = table.find(SIM.players, p)
	if i then
		table.remove(SIM.players, i)
	end
	if p.Character then
		p.Character:Destroy()
	end
	p.Parent = nil
end
function SIM.teleport(p, pos)
	p.Character:PivotTo(CFrame.new(pos))
end
function SIM.messages(p, kind)
	local out = {}
	for _, m in ipairs(SIM.outbox[p] or {}) do
		if kind == nil or m.kind == kind then
			table.insert(out, m.payload)
		end
	end
	return out
end
function SIM.clearMessages(p)
	SIM.outbox[p] = {}
end

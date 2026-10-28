-- Simulador mínimo do Roblox para rodar os serviços do SERVIDOR de verdade (sem Studio).
-- Relógio virtual: SIM.advance(dt) dispara Heartbeat e os task.delay vencidos.
local SIM = { clock = 1000, delays = {}, log = {} }

-- Signal ---------------------------------------------------------------------------------------
local function Signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		local h = { fn = fn }
		table.insert(self.handlers, h)
		return { Disconnect = function() h.dead = true end, Connected = true }
	end
	function s:Once(fn)
		local conn
		conn = self:Connect(function(...) conn.Disconnect(); fn(...) end)
		return conn
	end
	function s:Fire(...)
		for _, h in ipairs({ table.unpack(self.handlers) }) do
			if not h.dead then h.fn(...) end
		end
	end
	function s:Count()
		local n = 0
		for _, h in ipairs(self.handlers) do if not h.dead then n += 1 end end
		return n
	end
	return s
end
SIM.Signal = Signal

-- typeof precisa ser (re)definido NESTE chunk: o compilador do Luau otimiza o builtin `typeof`
-- em chunks que não o atribuem, ignorando o mock de Vector3.
function typeof(v)
	if type(v) == "table" and rawget(v, "X") and rawget(v, "Y") and rawget(v, "Z") then return "Vector3" end
	return type(v)
end

-- Vetores / CFrame --------------------------------------------------------------------------
CFrame = {}
CFrame.lookAt = function(a, b)
	local d = b - a
	return { Position = a, LookVector = d.Unit }
end
CFrame.new = function(...) return { Position = Vector3.zero, LookVector = Vector3.new(0, 0, -1) } end

-- Enum: proxy recursivo
local function enumProxy(path)
	return setmetatable({ _p = path }, { __index = function(t, k) return enumProxy(path .. "." .. k) end })
end
Enum = enumProxy("Enum")
Color3 = { fromRGB = function() return {} end, new = function() return {} end }

-- Instância mínima ---------------------------------------------------------------------------
local function Inst(class, name)
	local i = { ClassName = class, Name = name or class, _children = {}, _attrs = {}, AncestryChanged = Signal() }
	function i:SetAttribute(k, v) self._attrs[k] = v end
	function i:GetAttribute(k) return self._attrs[k] end
	function i:Destroy() self.Destroyed = true; self.Parent = nil; self.AncestryChanged:Fire(self, nil) end
	function i:FindFirstChild(n) return self._children[n] end
	function i:FindFirstChildOfClass(c) for _, ch in pairs(self._children) do if ch.ClassName == c then return ch end end end
	function i:IsA(c) return self.ClassName == c end
	return i
end
Instance = { new = function(class) return Inst(class) end }

-- Remotes -----------------------------------------------------------------------------------------
SIM.remotes = {}
local function Remote(name)
	local r = { name = name, OnServerEvent = Signal(), fired = {} }
	function r:FireClient(p, payload) table.insert(self.fired, { player = p, payload = payload }); end
	function r:FireAllClients(payload) end
	function r:count(player) local n = 0 for _, f in ipairs(self.fired) do if f.player == player then n += 1 end end return n end
	function r:last(player) for i = #self.fired, 1, -1 do if self.fired[i].player == player then return self.fired[i].payload end end end
	return r
end
function SIM.getRemote(name)
	if not SIM.remotes[name] then SIM.remotes[name] = Remote(name) end
	return SIM.remotes[name]
end

-- Players / personagens -------------------------------------------------------------------------
SIM.players = {}
local Players = { PlayerAdded = Signal(), PlayerRemoving = Signal() }
function Players:GetPlayers() return SIM.players end

function SIM.newCharacter(pos, rig)
	local c = Inst("Model", "Character")
	local hum = Inst("Humanoid")
	hum.WalkSpeed, hum.JumpHeight, hum.JumpPower, hum.UseJumpPower, hum.AutoRotate = 16, 7.2, 50, false, true
	hum.Health, hum.MaxHealth, hum.RigType = 100, 100, rig or "R15"
	hum.Died = Signal()
	function hum:TakeDamage(n)
		if c._children.ForceField then return end
		self.Health = math.max(0, self.Health - n)
		self.damageTaken = (self.damageTaken or 0) + n
		if self.Health <= 0 then self.Died:Fire() end
	end
	local root = Inst("Part", "HumanoidRootPart")
	root.Position = pos
	root.Anchored = false
	root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
	root.AssemblyLinearVelocity = Vector3.zero
	c._children.Humanoid = hum
	c._children.HumanoidRootPart = root
	root.Parent, hum.Parent = c, c
	c.Parent = {}
	-- ForceField: Instance.new devolve algo que se registra no pai quando Parent é atribuído
	return c
end
function SIM.newPlayer(name, pos, rig)
	local p = Inst("Player", name)
	p.UserId = #SIM.players + 1
	p.CharacterAdded = Signal()
	p.Character = SIM.newCharacter(pos, rig)
	p.Neutral = true
	table.insert(SIM.players, p)
	return p
end
function SIM.removePlayer(p)
	for i, q in ipairs(SIM.players) do if q == p then table.remove(SIM.players, i) end end
	Players.PlayerRemoving:Fire(p)
end

-- Instance.new devolve objetos cujo Parent registra o filho por ClassName no pai (para FindFirstChild).
local realInstNew = Instance.new
Instance.new = function(class)
	local i = realInstNew(class)
	i.Parent = nil
	setmetatable(i, {
		__index = function(t, k) if k == "Parent" then return rawget(t, "_parent") end end,
		__newindex = function(t, k, v)
			if k == "Parent" then
				local old = rawget(t, "_parent")
				if old and old._children then old._children[t.ClassName] = nil end
				rawset(t, "_parent", v)
				if v and v._children then v._children[t.ClassName] = t end
			else
				rawset(t, k, v)
			end
		end,
	})
	return i
end

-- Serviços ---------------------------------------------------------------------------------------
local Heartbeat = Signal()
SIM.Heartbeat = Heartbeat
local services = {
	Players = Players,
	RunService = { Heartbeat = Heartbeat, IsServer = function() return true end },
	Workspace = { GetServerTimeNow = function() return SIM.clock end },
	CollectionService = { GetTagged = function(_, tag) return SIM.tagged and SIM.tagged[tag] or {} end },
}
game = { GetService = function(_, n) return services[n] or {} end }

-- Path proxy para WaitForChild/require
local function P(name)
	return setmetatable({ name = name }, { __index = function(t, k)
		if k == "WaitForChild" then return function(_, n) return P(n) end end
	end })
end
SIM.P = P
script = { Parent = P("root") }
services.ReplicatedStorage = P("RS")
services.ServerStorage = P("SS")

-- task / os com relógio virtual ---------------------------------------------------------------
task = {
	spawn = function(f, ...) f(...) end,
	defer = function(f, ...) f(...) end,
	delay = function(t, f, ...)
		local args = { ... }
		table.insert(SIM.delays, { at = SIM.clock + t, f = f, args = args })
	end,
	cancel = function() end,
}
local osShim = { clock = function() return SIM.clock end, time = function() return SIM.clock end }

function SIM.advance(dt, step)
	step = step or (1 / 30)
	local target = SIM.clock + dt
	while SIM.clock < target - 1e-9 do
		SIM.clock = math.min(target, SIM.clock + step)
		-- delays vencidos
		table.sort(SIM.delays, function(a, b) return a.at < b.at end)
		while SIM.delays[1] and SIM.delays[1].at <= SIM.clock do
			local d = table.remove(SIM.delays, 1)
			d.f(table.unpack(d.args))
		end
		Heartbeat:Fire(step)
	end
end

SIM.os = osShim
return SIM

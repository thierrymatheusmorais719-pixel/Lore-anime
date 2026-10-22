-- Motor de animação do cliente.
-- • Toca as animações procedurais (Shared/Anim/Poses) sobre os Motor6D de qualquer rig R15,
--   misturando por prioridade e peso (fade in/out) por cima das animações padrão do Roblox.
-- • Se Config/Animations tiver um assetId, usa AnimationTrack publicado no lugar da procedural.
-- • Locomoção procedural para NPCs, posturas de espada, hit-stop e tecidos com mola.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Poses = require(Shared.Anim.Poses)
local Clips = require(Shared.Anim.Clips)
local Animations = require(Shared.Config.Animations)
local Signal = require(Shared.Util.Signal)

local AnimController = {}
-- (modelo, animação, marcador) — efeitos/sons sincronizados ao quadro da animação, não a timers
AnimController.MarkerReached = Signal.new()

local IDENTITY = CFrame.identity
local MAX_DISTANCE = 220

type Track = {
	name: string,
	def: any,
	joints: { string },
	time: number,
	speed: number,
	weight: number,
	stopping: boolean,
	fadeIn: number,
	fadeOut: number,
	priority: number,
	loop: boolean,
	order: number,
	assetTrack: AnimationTrack?,
	onMarker: ((string) -> ())?,
	scale: number,
}

type Rig = {
	model: Model,
	humanoid: Humanoid?,
	root: BasePart?,
	motors: { [string]: Motor6D },
	cloth: { { motor: Motor6D, pitch: number, vel: number, side: number, sideVel: number } },
	written: { [Motor6D]: CFrame },
	tracks: { Track },
	manual: boolean,
	phase: number,
	frozenUntil: number,
	assetCache: { [string]: AnimationTrack },
	stance: string?,
	connections: { RBXScriptConnection },
	smooth: { [string]: CFrame },
	smoothW: { [string]: number },
	lean: Vector3,
	look: Vector2,
	land: number,
	lookTarget: BasePart?,
	lookTimer: number,
	loco: { [string]: { time: number, weight: number } },
}

-- Rigidez da mola de cada junta: braços rápidos, tronco médio, cabeça lenta (atraso natural).
local STIFFNESS = {
	RightShoulder = 40,
	LeftShoulder = 36,
	RightElbow = 44,
	LeftElbow = 40,
	RightWrist = 50,
	LeftWrist = 46,
	Waist = 24,
	Root = 26,
	Neck = 15,
	RightHip = 34,
	LeftHip = 34,
	RightKnee = 36,
	LeftKnee = 36,
}

local rigs: { [Model]: Rig } = {}
local proceduralLayer: (Rig, number, number) -> { [string]: CFrame }
local jointCache: { [any]: { string } } = {}
local orderCounter = 0

local EASE = {
	linear = function(a: number)
		return a
	end,
	out = function(a: number)
		return 1 - (1 - a) * (1 - a)
	end,
	inout = function(a: number)
		return if a < 0.5 then 2 * a * a else 1 - (-2 * a + 2) ^ 2 / 2
	end,
	expo = function(a: number)
		return if a >= 1 then 1 else 1 - 2 ^ (-10 * a)
	end,
}

local ClipSampler = require(Shared.Anim.ClipSampler)
local sampleKeys = ClipSampler.sample

local PRIORITY = { Core = 0, Idle = 1, Movement = 2, Action = 3, Action2 = 3, Action3 = 4, Action4 = 4 }
local clipDefs: { [string]: any } = {}

-- Definição tocável: clip compilado (preferido) ou pose procedural antiga como reserva.
local function definition(name: string): any?
	local cached = clipDefs[name]
	if cached then
		return cached
	end
	local clip = Clips[name]
	local legacy = Poses[name]
	if clip then
		local joints = {}
		for joint in clip.tracks do
			table.insert(joints, joint)
		end
		local def = {
			duration = clip.duration,
			loop = clip.loop,
			clip = clip,
			markers = clip.markers,
			priority = if type(legacy) == "table" and legacy.priority
				then legacy.priority
				else (PRIORITY[clip.priority] or 3),
			fadeIn = if type(legacy) == "table" then legacy.fadeIn else nil,
			fadeOut = if type(legacy) == "table" then legacy.fadeOut else nil,
			joints = joints,
		}
		clipDefs[name] = def
		return def
	end
	if type(legacy) == "table" and legacy.keyframes then
		return legacy
	end
	return nil
end

-- Nome efetivo da animação no modelo: criaturas (atributo AnimSet, ex.: "Hollow") tocam a própria
-- versão ("HollowSlash1") quando existe; senão, a animação comum.
function AnimController.Resolve(model: Model?, name: string): string
	local set = model and model:GetAttribute("AnimSet")
	if type(set) == "string" and definition(set .. name) then
		return set .. name
	end
	return name
end

-- Tempo de um marcador ("Hit", "Release"...) dentro da animação, se existir.
function AnimController.MarkerTime(name: string, marker: string, model: Model?): number?
	local def = definition(AnimController.Resolve(model, name))
	if def and def.clip then
		for _, m in def.markers do
			if m.name == marker then
				return m.time
			end
		end
	elseif def and def.markers then
		return def.markers[marker]
	end
	return nil
end

function AnimController.Length(name: string, model: Model?): number?
	local def = definition(AnimController.Resolve(model, name))
	return def and def.duration or nil
end

local function jointsOf(def): { string }
	if def.joints then
		return def.joints
	end
	local cached = jointCache[def]
	if cached then
		return cached
	end
	local set, list = {}, {}
	for _, kf in def.keyframes do
		for joint in kf.pose do
			if not set[joint] then
				set[joint] = true
				table.insert(list, joint)
			end
		end
	end
	jointCache[def] = list
	return list
end

local function scanMotors(rig: Rig)
	table.clear(rig.motors)
	table.clear(rig.cloth)
	for _, d in rig.model:GetDescendants() do
		if d:IsA("Motor6D") then
			if d.Name:sub(1, 5) == "Cloth" then
				table.insert(rig.cloth, { motor = d, pitch = 0, vel = 0, side = 0, sideVel = 0 })
			elseif not rig.motors[d.Name] then
				rig.motors[d.Name] = d
			end
		end
	end
end

function AnimController.Register(model: Model)
	if rigs[model] then
		return rigs[model]
	end
	local rig: Rig = {
		model = model,
		humanoid = model:FindFirstChildOfClass("Humanoid"),
		root = model:FindFirstChild("HumanoidRootPart") :: BasePart?,
		motors = {},
		cloth = {},
		written = {},
		tracks = {},
		manual = model:FindFirstChild("Animate") == nil,
		phase = 0,
		frozenUntil = 0,
		assetCache = {},
		stance = nil,
		connections = {},
		smooth = {},
		smoothW = {},
		lean = Vector3.zero,
		look = Vector2.zero,
		land = 0,
		lookTarget = nil,
		lookTimer = 0,
		loco = {},
	}
	scanMotors(rig)
	local humanoid = rig.humanoid
	if humanoid then
		table.insert(
			rig.connections,
			humanoid.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Landed then
					local root = rig.root
					local fall = if root then math.clamp(-root.AssemblyLinearVelocity.Y / 60, 0.3, 1) else 0.5
					rig.land = math.max(rig.land, fall)
				end
			end)
		)
	end
	local rescanQueued = false
	local function queueRescan(d: Instance)
		if d:IsA("Motor6D") and not rescanQueued then
			rescanQueued = true
			task.defer(function()
				rescanQueued = false
				if rigs[model] then
					scanMotors(rig)
				end
			end)
		end
	end
	table.insert(rig.connections, model.DescendantAdded:Connect(queueRescan))
	table.insert(rig.connections, model.DescendantRemoving:Connect(queueRescan))
	table.insert(
		rig.connections,
		model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				AnimController.Unregister(model)
			end
		end)
	)
	rigs[model] = rig
	return rig
end

function AnimController.Unregister(model: Model)
	local rig = rigs[model]
	if not rig then
		return
	end
	for _, c in rig.connections do
		c:Disconnect()
	end
	rigs[model] = nil
end

local function assetTrackFor(rig: Rig, name: string): AnimationTrack?
	local entry = Animations.List[name]
	if not entry or entry.assetId == "" then
		return nil
	end
	local cached = rig.assetCache[name]
	if cached then
		return cached
	end
	local humanoid = rig.humanoid
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = entry.assetId
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		rig.assetCache[name] = track
		return track
	end
	return nil
end

-- Toca `name` no modelo. options: speed, duration (reescala para durar X s), fadeIn, fadeOut, loop
function AnimController.Play(model: Model?, name: string, options: { [string]: any }?): Track?
	if not model then
		return nil
	end
	name = AnimController.Resolve(model, name)
	local def = definition(name)
	if not def then
		return nil
	end
	local rig = rigs[model] or AnimController.Register(model)
	local opts: { [string]: any } = options or {}
	local speed = opts.speed or 1
	if opts.duration and opts.duration > 0 then
		speed = def.duration / opts.duration
	end
	-- Remove instância anterior da mesma animação
	for _, t in rig.tracks do
		if t.name == name then
			t.stopping = true
			t.fadeOut = 0.05
		end
	end
	orderCounter += 1
	local track: Track = {
		name = name,
		def = def,
		joints = jointsOf(def),
		time = 0,
		speed = speed,
		weight = 0,
		stopping = false,
		fadeIn = opts.fadeIn or def.fadeIn or 0.08,
		fadeOut = opts.fadeOut or def.fadeOut or 0.15,
		priority = opts.priority or def.priority or 2,
		loop = if opts.loop ~= nil then opts.loop else def.loop == true,
		order = orderCounter,
		assetTrack = nil,
		onMarker = opts.onMarker,
		scale = model:GetAttribute("AnimScale") or 1,
	}
	local asset = assetTrackFor(rig, name)
	if asset then
		local entry = Animations.List[name]
		asset.Looped = track.loop
		asset:Play(track.fadeIn, 1, speed * (entry.speed or 1))
		track.assetTrack = asset
		track.joints = {}
	end
	table.insert(rig.tracks, track)
	return track
end

function AnimController.Stop(model: Model?, name: string, fade: number?)
	local rig = model and rigs[model]
	if not rig then
		return
	end
	name = AnimController.Resolve(model, name)
	for _, t in rig.tracks do
		if t.name == name and not t.stopping then
			t.stopping = true
			t.fadeOut = fade or t.fadeOut
			if t.assetTrack then
				t.assetTrack:Stop(t.fadeOut)
			end
		end
	end
end

-- Interrompe tudo com prioridade >= minPriority (ex.: ao ser atingido)
function AnimController.StopAll(model: Model?, minPriority: number?, fade: number?)
	local rig = model and rigs[model]
	if not rig then
		return
	end
	for _, t in rig.tracks do
		if t.priority >= (minPriority or 0) and not t.stopping then
			t.stopping = true
			t.fadeOut = fade or 0.08
			if t.assetTrack then
				t.assetTrack:Stop(t.fadeOut)
			end
		end
	end
end

function AnimController.IsPlaying(model: Model?, name: string): boolean
	local rig = model and rigs[model]
	if not rig then
		return false
	end
	name = AnimController.Resolve(model, name)
	for _, t in rig.tracks do
		if t.name == name and not t.stopping then
			return true
		end
	end
	return false
end

-- Hit-stop: congela as animações do modelo por `duration`.
function AnimController.Freeze(model: Model?, duration: number)
	local rig = model and rigs[model]
	if rig then
		rig.frozenUntil = math.max(rig.frozenUntil, os.clock() + duration)
		for _, t in rig.tracks do
			if t.assetTrack then
				t.assetTrack:AdjustSpeed(0)
				task.delay(duration, function()
					if t.assetTrack then
						t.assetTrack:AdjustSpeed(t.speed)
					end
				end)
			end
		end
	end
end

-- Clips são autorados no tamanho do corpo base; num modelo escalado as translações (quadril que
-- desce, avanço do tronco) crescem junto, como as juntas do próprio modelo.
local function scaled(cf: CFrame, scale: number): CFrame
	if scale == 1 then
		return cf
	end
	return cf.Rotation + cf.Position * scale
end

local function sample(track: Track, joint: string): CFrame?
	local clip = track.def.clip
	if clip then
		local keys = clip.tracks[joint]
		return if keys then scaled(sampleKeys(keys, track.time), track.scale) else IDENTITY
	end
	local keyframes = track.def.keyframes
	local t = track.time
	local count = #keyframes
	if t <= keyframes[1].t then
		return keyframes[1].pose[joint] or IDENTITY
	end
	for i = 1, count - 1 do
		local a, b = keyframes[i], keyframes[i + 1]
		if t < b.t then
			local span = b.t - a.t
			local alpha = if span > 0 then (t - a.t) / span else 1
			local ease = EASE[b.ease or "inout"] or EASE.inout
			local from = a.pose[joint] or IDENTITY
			local to = b.pose[joint] or IDENTITY
			return from:Lerp(to, ease(alpha))
		end
	end
	return keyframes[count].pose[joint] or IDENTITY
end

local function updateStance(rig: Rig)
	local model = rig.model
	if model:GetAttribute("Team") ~= "Players" then
		return
	end
	local drawn = model:GetAttribute("Drawn") == true
	local desired: string? = nil
	if drawn and rig.root then
		local v = rig.root.AssemblyLinearVelocity
		desired = if Vector3.new(v.X, 0, v.Z).Magnitude > 20 then "SwordRun" else "SwordIdle"
	end
	if desired ~= rig.stance then
		if rig.stance then
			AnimController.Stop(model, rig.stance)
		end
		rig.stance = desired
		if desired then
			AnimController.Play(model, desired)
		end
	end
end

local function updateCloth(rig: Rig, dt: number)
	if #rig.cloth == 0 or not rig.root then
		return
	end
	local root = rig.root
	local localVel = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
	-- Tecido voa para trás conforme a velocidade para frente e sobe na queda
	local targetPitch = math.clamp(-localVel.Z * 2.2 + math.max(0, -localVel.Y) * 1.5, -10, 75)
	local targetSide = math.clamp(localVel.X * 1.5, -25, 25)
	local wobble = math.sin(os.clock() * 7) * math.min(6, math.abs(localVel.Z) * 0.2)
	for _, c in rig.cloth do
		local k, damping = 90, 12
		c.vel += ((targetPitch + wobble) - c.pitch) * k * dt - c.vel * damping * dt
		c.pitch += c.vel * dt
		c.sideVel += (targetSide - c.side) * k * dt - c.sideVel * damping * dt
		c.side += c.sideVel * dt
		c.motor.Transform = CFrame.Angles(math.rad(c.pitch), 0, math.rad(c.side))
	end
end

local player = Players.LocalPlayer

-- Alvo para onde a cabeça olha: jogador local → inimigo mais próximo à frente;
-- inimigos → jogador local quando perto.
local function findLookTarget(rig: Rig): BasePart?
	local root = rig.root
	if not root then
		return nil
	end
	if rig.model == player.Character then
		local best, bestDistance = nil, 35
		for _, folderName in { "Enemies", "Bosses" } do
			local folder = workspace:FindFirstChild(folderName)
			if folder then
				for _, m in folder:GetChildren() do
					local head = m:FindFirstChild("Head") :: BasePart?
					if head then
						local offset = head.Position - root.Position
						local d = offset.Magnitude
						if d < bestDistance and root.CFrame.LookVector:Dot(offset.Unit) > 0.1 then
							best, bestDistance = head, d
						end
					end
				end
			end
		end
		return best
	elseif rig.model:GetAttribute("EnemyId") then
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if head and (head.Position - root.Position).Magnitude < 40 then
			return head
		end
	end
	return nil
end

-- Camada procedural aditiva: inclinação ao correr/virar, cabeça olhando o alvo, amortecer queda.
proceduralLayer = function(rig: Rig, dt: number, _now: number): { [string]: CFrame }
	local out: { [string]: CFrame } = {}
	local root = rig.root
	if not root or not rig.humanoid or rig.humanoid.Health <= 0 then
		return out
	end
	if rig.model:GetAttribute("NPC") then
		return out
	end
	-- Inclinação (lean) suavizada
	local localVel = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
	local turn = root.AssemblyAngularVelocity.Y
	local targetLean = Vector3.new(
		math.clamp(-localVel.Z * 0.45, -8, 12), -- frente/trás (graus)
		0,
		math.clamp(-localVel.X * 0.35 + turn * 2.5, -12, 12) -- lateral/curva
	)
	rig.lean += (targetLean - rig.lean) * (1 - math.exp(-6 * dt))
	if rig.lean.Magnitude > 0.3 then
		out.Waist = CFrame.Angles(math.rad(-rig.lean.X * 0.7), 0, math.rad(rig.lean.Z * 0.6))
		out.Root = CFrame.Angles(math.rad(-rig.lean.X * 0.3), 0, math.rad(rig.lean.Z * 0.4))
	end
	-- Cabeça olhando o alvo
	rig.lookTimer -= dt
	if rig.lookTimer <= 0 then
		rig.lookTimer = 0.25
		rig.lookTarget = findLookTarget(rig)
	end
	local targetLook = Vector2.zero
	local lookTarget = rig.lookTarget
	if lookTarget and lookTarget.Parent then
		local rel = root.CFrame:PointToObjectSpace(lookTarget.Position)
		local yaw = math.atan2(-rel.X, -rel.Z)
		local pitch = math.atan2(rel.Y - 1.5, Vector2.new(rel.X, rel.Z).Magnitude)
		targetLook = Vector2.new(math.clamp(yaw, -1.0, 1.0), math.clamp(pitch, -0.5, 0.5))
	end
	rig.look += (targetLook - rig.look) * (1 - math.exp(-8 * dt))
	if rig.look.Magnitude > 0.01 then
		out.Neck = CFrame.fromEulerAnglesYXZ(rig.look.Y, rig.look.X, 0)
	end
	-- Aterrissagem: agacha e recupera
	if rig.land > 0.01 then
		local a = rig.land
		out.Root = (out.Root or IDENTITY) * CFrame.new(0, -0.55 * a, 0)
		out.RightHip = CFrame.Angles(math.rad(28 * a), 0, 0)
		out.LeftHip = CFrame.Angles(math.rad(28 * a), 0, 0)
		out.RightKnee = CFrame.Angles(math.rad(-50 * a), 0, 0)
		out.LeftKnee = CFrame.Angles(math.rad(-50 * a), 0, 0)
		rig.land = math.max(0, rig.land - dt * 4.5)
	end
	return out
end

-- Locomoção de rigs sem Animate (NPCs/inimigos) com as marchas compiladas: parado, andar,
-- correr, disparar. Cada marcha toca na taxa velocidade ÷ velocidade de chão (0,5×–2×) para os
-- pés não deslizarem; troca com crossfade. `AnimSet` no modelo escolhe outro conjunto (ex.: "Hollow").
local GAITS = { "Walk", "Run", "Sprint" }
local function locomotionPose(rig: Rig, dt: number, speed: number, airborne: boolean): { [string]: CFrame }
	local set = rig.model:GetAttribute("AnimSet") or "Npc"
	local scale = rig.model:GetAttribute("AnimScale") or 1
	-- Criaturas só usam as próprias marchas (a marcha humana não serve no corpo delas)
	local creature = set ~= "Npc"
	local function get(state: string)
		return definition(set .. state) or (if creature then nil else definition("Npc" .. state))
	end
	-- Escolhe a marcha cuja faixa de taxa cobre a velocidade (a mais lenta que dá conta); a velocidade
	-- de chão cresce com a escala do modelo (passada maior)
	local target = "Idle"
	if airborne then
		target = if creature then "Run" else "Air"
	elseif speed > 0.6 then
		target = "Sprint"
		local fastest = nil
		for _, gait in GAITS do
			local def = get(gait)
			local gs = def and def.clip and def.clip.groundSpeed
			if gs then
				fastest = gait
				if speed <= gs * scale * 2 then
					target = gait
					break
				end
			end
		end
		if target == "Sprint" and not get("Sprint") and fastest then
			target = fastest
		end
	end
	local fade = 1 - math.exp(-10 * dt)
	for _, state in { "Idle", "Walk", "Run", "Sprint", "Air" } do
		local entry = rig.loco[state]
		if not entry then
			entry = { time = 0, weight = 0 }
			rig.loco[state] = entry
		end
		entry.weight += ((if state == target then 1 else 0) - entry.weight) * fade
	end
	local result: { [string]: CFrame } = {}
	local accumulated = 0
	for _, state in { "Idle", "Walk", "Run", "Sprint", "Air" } do
		local entry = rig.loco[state]
		if entry.weight > 0.01 then
			local def = if state == "Air" then definition("AirStep") else get(state)
			if def and def.clip then
				local rate = 1
				local gs = def.clip.groundSpeed
				if gs then
					rate = math.clamp(speed / (gs * scale), 0.5, 2)
				end
				if state == "Air" then
					entry.time = def.duration
				else
					entry.time = (entry.time + dt * rate) % def.duration
				end
				local share = entry.weight / (accumulated + entry.weight)
				accumulated += entry.weight
				for joint, keys in def.clip.tracks do
					if joint ~= "Weapon" and joint ~= "OffHand" then
						local cf = scaled(sampleKeys(keys, entry.time), scale)
						local current = result[joint]
						result[joint] = if current then current:Lerp(cf, share) else IDENTITY:Lerp(cf, share)
					end
				end
			end
		end
	end
	return result
end

local function stepRig(rig: Rig, dt: number, now: number)
	local frozen = now < rig.frozenUntil
	local adt = if frozen then 0 else dt
	updateStance(rig)

	-- Avança trilhas
	local tracks = rig.tracks
	for i = #tracks, 1, -1 do
		local t = tracks[i]
		local previous = t.time
		t.time += adt * t.speed
		local markers = t.def.clip and t.def.markers
		if markers and not t.stopping and t.time > previous then
			for _, m in markers do
				local mt = m.time
				if (mt > previous and mt <= t.time) or (previous == 0 and mt == 0) then
					AnimController.MarkerReached:Fire(rig.model, t.name, m.name)
					if t.onMarker then
						task.spawn(t.onMarker, m.name)
					end
				end
			end
		end
		if not t.loop and not t.stopping and t.time >= t.def.duration then
			t.stopping = true
		end
		if t.loop and t.time >= t.def.duration then
			t.time %= t.def.duration
		end
		if t.stopping then
			t.weight -= dt / math.max(0.01, t.fadeOut)
			if t.weight <= 0 then
				table.remove(tracks, i)
				if t.assetTrack and t.assetTrack.IsPlaying then
					t.assetTrack:Stop(0.1)
				end
			end
		else
			t.weight = math.min(1, t.weight + dt / math.max(0.01, t.fadeIn))
		end
	end

	-- Base: locomoção procedural (rigs manuais) ou saída do Animator
	local locomotion: { [string]: CFrame }? = nil
	if rig.manual and rig.root and rig.humanoid then
		local v = rig.root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		rig.phase += dt * speed * 0.42
		local airborne = rig.humanoid.FloorMaterial == Enum.Material.Air and math.abs(v.Y) > 6
		locomotion = locomotionPose(rig, dt, speed, airborne)
	end

	table.sort(tracks, function(a, b)
		if a.priority == b.priority then
			return a.order < b.order
		end
		return a.priority < b.priority
	end)

	local procedural = proceduralLayer(rig, dt, now)
	local active = #tracks > 0 or locomotion ~= nil or next(procedural) ~= nil or next(rig.smoothW) ~= nil
	if not active then
		return
	end

	for name, motor in rig.motors do
		-- Alvo combinado das trilhas (camadas por prioridade)
		local target: CFrame? = nil
		local weight = 0
		for _, t in tracks do
			if t.weight > 0 and table.find(t.joints, name) then
				local pose = sample(t, name)
				if target == nil then
					target = pose
					weight = t.weight
				else
					target = (target :: CFrame):Lerp(pose, t.weight)
					weight += (1 - weight) * t.weight
				end
			end
		end
		-- Mola: suaviza alvo e peso (movimento secundário); congela no hit-stop
		local k = STIFFNESS[name] or 30
		local alpha = if frozen then 0 else 1 - math.exp(-k * dt)
		local previous = rig.smooth[name]
		local smoothed: CFrame? = previous
		if target then
			smoothed = if previous then previous:Lerp(target, alpha) else target
		end
		local w = (rig.smoothW[name] or 0)
		w += (weight - w) * (if frozen then 0 else 1 - math.exp(-k * 0.8 * dt))
		if w < 0.002 and weight == 0 then
			rig.smoothW[name] = nil
			rig.smooth[name] = nil
			w = 0
		else
			rig.smoothW[name] = w
			rig.smooth[name] = smoothed :: any
		end

		local extra = procedural[name]
		if w > 0 or locomotion or extra then
			local base: CFrame
			if locomotion then
				base = locomotion[name] or IDENTITY
			else
				local current = motor.Transform
				base = if current == rig.written[motor] then IDENTITY else current
			end
			local result = base
			if w > 0 and smoothed then
				result = base:Lerp(smoothed, math.min(1, w))
			end
			if extra then
				result *= extra
			end
			motor.Transform = result
			rig.written[motor] = result
		end
	end
end

function AnimController.Init() end

function AnimController.Start()
	local function watchFolder(folder: Instance)
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
				AnimController.Register(child)
			end
		end
		folder.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				task.defer(function()
					if child:FindFirstChildOfClass("Humanoid") or child:WaitForChild("Humanoid", 5) then
						AnimController.Register(child)
					end
				end)
			end
		end)
	end
	for _, name in { "Enemies", "Bosses", "NPCs" } do
		task.spawn(function()
			watchFolder(workspace:WaitForChild(name))
		end)
	end
	local function onPlayer(player: Player)
		local function onCharacter(character: Model)
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Humanoid", 10)
			AnimController.Unregister(character)
			local rig = AnimController.Register(character)
			-- O Animate é inserido logo após o spawn
			task.delay(1, function()
				if rigs[character] then
					rig.manual = character:FindFirstChild("Animate") == nil
					scanMotors(rig)
				end
			end)
		end
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
		player.CharacterAdded:Connect(onCharacter)
	end
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerAdded:Connect(onPlayer)

	RunService.Stepped:Connect(function(_, dt)
		local camera = workspace.CurrentCamera
		local focus = camera and camera.CFrame.Position or Vector3.zero
		local now = os.clock()
		for model, rig in rigs do
			local root = rig.root
			if root and (root.Position - focus).Magnitude < MAX_DISTANCE then
				stepRig(rig, dt, now)
				updateCloth(rig, dt)
			end
		end
	end)
end

return AnimController

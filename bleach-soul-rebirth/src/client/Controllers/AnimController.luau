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
local Animations = require(Shared.Config.Animations)

local AnimController = {}

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

local function jointsOf(def): { string }
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
	local def = Poses[name]
	if type(def) ~= "table" or not def.keyframes then
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

local function sample(track: Track, joint: string): CFrame?
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

local function stepRig(rig: Rig, dt: number, now: number)
	local frozen = now < rig.frozenUntil
	local adt = if frozen then 0 else dt
	updateStance(rig)

	-- Avança trilhas
	local tracks = rig.tracks
	for i = #tracks, 1, -1 do
		local t = tracks[i]
		t.time += adt * t.speed
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
		locomotion = Poses.locomotion(rig.phase, speed, airborne, now)
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
			rig.smooth[name] = smoothed
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

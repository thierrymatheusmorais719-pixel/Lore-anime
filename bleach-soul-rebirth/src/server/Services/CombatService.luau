-- Núcleo de combate autoritativo no servidor.
-- O cliente só envia intenções; aqui ficam estados (stun, guarda, combos, cooldowns),
-- hitboxes, dano, knockback, parry/contra-ataque e Reiatsu.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Combat = require(Shared.Config.Combat)
local Zones = require(Shared.Config.Zones)
local CombatRules = require(Shared.Logic.CombatRules)
local Stats = require(Shared.Logic.Stats)
local Physics = require(Shared.Physics)
local Signal = require(Shared.Util.Signal)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Parent.Registry)

local log = Log.new("CombatService")

local CombatService = {}
CombatService.ActorRegistered = Signal.new() -- (actor)
CombatService.ActorRemoved = Signal.new() -- (actor)
CombatService.ActorDied = Signal.new() -- (actor, killer: Actor?)
CombatService.AttackStarted = Signal.new() -- (actor, spec, kind)
CombatService.HitLanded = Signal.new() -- (attacker, target, result, damage)
CombatService.Parried = Signal.new() -- (defender, attacker)

export type Actor = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	player: Player?,
	team: string,
	name: string,
	faction: string?,
	power: string?,
	enemyId: string?,
	isBoss: boolean,
	level: number,
	derived: any,
	baseWalkSpeed: number,
	form: string,
	mask: boolean,
	reiatsu: number,
	lastReiatsuUse: number,
	combo: { index: number, lastEnd: number, aerial: number, aerialLastEnd: number },
	busyUntil: number,
	cancelFrom: number,
	token: number,
	stunUntil: number,
	iframeUntil: number,
	superArmorUntil: number,
	blocking: boolean,
	blockStart: number,
	blockReleasedAt: number,
	guard: number,
	lastGuardHit: number,
	counterUntil: number,
	cooldowns: { [string]: number },
	buffs: { [string]: { value: any, untilTime: number } },
	channel: any?,
	charging: boolean,
	sprinting: boolean,
	drawn: boolean,
	lastCombatTime: number,
	damageBy: { [Player]: number },
	lastAttacker: any?,
	dead: boolean,
	extra: { [string]: any },
	trove: { RBXScriptConnection },
}

local actors: { [Model]: Actor } = {}
local overlapList: { Instance } = {}
local overlapDirty = true
local fxRemote: RemoteEvent
local impulseRemote: RemoteEvent
local stateRemote: RemoteEvent

local DEFAULT_DERIVED = {
	maxHealth = 100,
	maxReiatsu = 100,
	meleeMultiplier = 1,
	abilityMultiplier = 1,
	defense = 0,
	walkSpeedBonus = 0,
	cooldownMultiplier = 1,
	abilityCostMultiplier = 1,
	drainMultiplier = 1,
	parryBonus = 0,
	counterBonus = 0,
	guardMultiplier = 1,
	airDashes = 0,
	dashCooldownMultiplier = 1,
	finisherWave = false,
}

local function now(): number
	return os.clock()
end

CombatService.now = now

-- ============================================================
-- Registro de atores
-- ============================================================
function CombatService.Register(model: Model, options: { [string]: any }): Actor?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		log:Warn("Register sem Humanoid/HumanoidRootPart:", model:GetFullName())
		return nil
	end
	if actors[model] then
		CombatService.Unregister(model)
	end
	local derived = options.derived or table.clone(DEFAULT_DERIVED)
	local actor: Actor = {
		model = model,
		humanoid = humanoid,
		root = root,
		player = options.player,
		team = options.team or "Enemies",
		name = options.name or model.Name,
		faction = options.faction,
		power = options.power,
		enemyId = options.enemyId,
		isBoss = options.isBoss == true,
		level = options.level or 1,
		derived = derived,
		baseWalkSpeed = options.baseWalkSpeed or Combat.BaseWalkSpeed,
		form = "Base",
		mask = false,
		reiatsu = derived.maxReiatsu,
		lastReiatsuUse = 0,
		combo = { index = 0, lastEnd = 0, aerial = 0, aerialLastEnd = 0 },
		busyUntil = 0,
		cancelFrom = 0,
		token = 0,
		stunUntil = 0,
		iframeUntil = 0,
		superArmorUntil = 0,
		blocking = false,
		blockStart = -1e9,
		blockReleasedAt = -1e9,
		guard = Combat.MaxGuard * derived.guardMultiplier,
		lastGuardHit = 0,
		counterUntil = 0,
		cooldowns = {},
		buffs = {},
		channel = nil,
		charging = false,
		sprinting = false,
		drawn = false,
		lastCombatTime = 0,
		damageBy = {},
		lastAttacker = nil,
		dead = false,
		extra = {},
		trove = {},
	}
	actors[model] = actor
	overlapDirty = true

	humanoid.MaxHealth = derived.maxHealth
	humanoid.Health = derived.maxHealth
	model:SetAttribute("Team", actor.team)
	model:SetAttribute("DisplayName", actor.name)
	model:SetAttribute("Level", actor.level)
	model:SetAttribute("Form", "Base")
	model:SetAttribute("Mask", false)
	model:SetAttribute("Faction", actor.faction)
	model:SetAttribute("Power", actor.power)
	model:SetAttribute("Boss", actor.isBoss)
	model:SetAttribute("EnemyId", actor.enemyId)
	model:SetAttribute("Stunned", false)
	model:SetAttribute("Blocking", false)
	model:SetAttribute("Drawn", false)
	model:SetAttribute("Combatant", true)
	CombatService.ReplicateResources(actor, true)

	table.insert(
		actor.trove,
		humanoid.Died:Connect(function()
			CombatService.HandleDeath(actor)
		end)
	)
	table.insert(
		actor.trove,
		model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				CombatService.Unregister(model)
			end
		end)
	)
	CombatService.UpdateMovement(actor)
	CombatService.ActorRegistered:Fire(actor)
	return actor
end

function CombatService.Unregister(model: Model)
	local actor = actors[model]
	if not actor then
		return
	end
	actors[model] = nil
	overlapDirty = true
	for _, connection in actor.trove do
		connection:Disconnect()
	end
	actor.dead = true
	actor.token += 1
	CombatService.ActorRemoved:Fire(actor)
end

function CombatService.Get(model: Instance?): Actor?
	if not model then
		return nil
	end
	return actors[model :: Model]
end

function CombatService.GetByPlayer(player: Player): Actor?
	local character = player.Character
	return character and actors[character] or nil
end

function CombatService.All(): { [Model]: Actor }
	return actors
end

-- Atualiza atributos derivados (subida de nível, equipamento, árvore).
function CombatService.SetDerived(actor: Actor, derived: any)
	local ratio = if actor.humanoid.MaxHealth > 0 then actor.humanoid.Health / actor.humanoid.MaxHealth else 1
	actor.derived = derived
	actor.humanoid.MaxHealth = derived.maxHealth
	if actor.humanoid.Health > 0 then
		actor.humanoid.Health = math.max(1, derived.maxHealth * ratio)
	end
	actor.reiatsu = math.min(actor.reiatsu, derived.maxReiatsu)
	CombatService.ReplicateResources(actor, true)
	CombatService.UpdateMovement(actor)
end

-- ============================================================
-- Utilidades
-- ============================================================
function CombatService.IsAlive(actor: Actor?): boolean
	return actor ~= nil and not actor.dead and actor.humanoid.Health > 0 and actor.model.Parent ~= nil
end

function CombatService.IsStunned(actor: Actor, t: number?): boolean
	return (t or now()) < actor.stunUntil
end

-- Pode iniciar uma nova ação? `allowCancel` permite cancelar a recuperação de um golpe.
function CombatService.CanAct(actor: Actor, allowCancel: boolean?): boolean
	if not CombatService.IsAlive(actor) then
		return false
	end
	local t = now()
	if t < actor.stunUntil or actor.channel ~= nil then
		return false
	end
	if t < actor.busyUntil then
		return allowCancel == true and t >= actor.cancelFrom
	end
	return true
end

function CombatService.IsAirborne(actor: Actor): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { actor.model }
	local depth = actor.humanoid.HipHeight + actor.root.Size.Y / 2 + 1.6
	local result = workspace:Raycast(actor.root.Position, Vector3.new(0, -depth, 0), params)
	return result == nil
end

function CombatService.Broadcast(kind: string, data: { [string]: any }, position: Vector3?)
	if position then
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - position).Magnitude < 700 then
				fxRemote:FireClient(player, kind, data)
			end
		end
	else
		fxRemote:FireAllClients(kind, data)
	end
end

function CombatService.SendImpulse(actor: Actor, data: { [string]: any })
	if actor.player then
		impulseRemote:FireClient(actor.player, data)
	end
end

function CombatService.SendCooldowns(actor: Actor)
	if not actor.player then
		return
	end
	local t = now()
	local remaining = {}
	for key, readyAt in actor.cooldowns do
		if readyAt > t then
			remaining[key] = readyAt - t
		end
	end
	stateRemote:FireClient(actor.player, { cooldowns = remaining })
end

function CombatService.SetCooldown(actor: Actor, key: string, duration: number)
	actor.cooldowns[key] = now() + duration
	CombatService.SendCooldowns(actor)
end

function CombatService.CooldownReady(actor: Actor, key: string): boolean
	return now() >= (actor.cooldowns[key] or 0)
end

-- Ocupa o ator por `duration`; retorna token (mudará se a ação for interrompida).
function CombatService.SetBusy(actor: Actor, duration: number, cancelAfter: number?): number
	local t = now()
	actor.token += 1
	actor.busyUntil = t + duration
	actor.cancelFrom = t + (cancelAfter or duration)
	actor.lastCombatTime = t
	CombatService.UpdateMovement(actor)
	task.delay(duration + 0.02, function()
		if actors[actor.model] then
			CombatService.UpdateMovement(actor)
		end
	end)
	return actor.token
end

function CombatService.Interrupt(actor: Actor)
	actor.token += 1
	actor.busyUntil = 0
	actor.charging = false
	if actor.channel then
		local channel = actor.channel
		actor.channel = nil
		if channel.onCancel then
			task.spawn(channel.onCancel)
		end
	end
end

function CombatService.SpendReiatsu(actor: Actor, amount: number): boolean
	if amount <= 0 then
		return true
	end
	if actor.reiatsu < amount then
		return false
	end
	actor.reiatsu -= amount
	actor.lastReiatsuUse = now()
	CombatService.ReplicateResources(actor)
	return true
end

function CombatService.AddReiatsu(actor: Actor, amount: number)
	actor.reiatsu = math.clamp(actor.reiatsu + amount, 0, actor.derived.maxReiatsu)
	CombatService.ReplicateResources(actor)
end

function CombatService.Heal(actor: Actor, amount: number)
	if not CombatService.IsAlive(actor) then
		return
	end
	actor.humanoid.Health = math.min(actor.humanoid.MaxHealth, actor.humanoid.Health + amount)
end

-- Buffs nomeados: { damage = mult, defense = soma, speed = soma }
function CombatService.AddBuff(actor: Actor, id: string, value: { [string]: number }, duration: number)
	actor.buffs[id] = { value = value, untilTime = now() + duration }
	actor.model:SetAttribute("Buff_" .. id, true)
	CombatService.UpdateMovement(actor)
end

function CombatService.RemoveBuff(actor: Actor, id: string)
	if actor.buffs[id] then
		actor.buffs[id] = nil
		actor.model:SetAttribute("Buff_" .. id, nil)
		CombatService.UpdateMovement(actor)
	end
end

function CombatService.BuffValue(actor: Actor, key: string, multiplicative: boolean): number
	local t = now()
	local result = if multiplicative then 1 else 0
	for _, buff in actor.buffs do
		if buff.untilTime > t then
			local v = buff.value[key]
			if v then
				if multiplicative then
					result *= v
				else
					result += v
				end
			end
		end
	end
	return result
end

-- Multiplicador de forma (Shikai/Bankai etc.) e máscara.
function CombatService.FormMultiplier(actor: Actor): number
	local m = 1
	if actor.form == "Tier1" then
		m = 1.15
	elseif actor.form == "Tier2" then
		m = 1.35
	end
	if actor.mask then
		m *= 1.25
	end
	return m
end

function CombatService.Defense(actor: Actor): number
	local d = actor.derived.defense + CombatService.BuffValue(actor, "defense", false)
	if actor.form == "Tier2" then
		d += 0.1
	end
	return math.clamp(d, 0, 0.8)
end

-- ============================================================
-- Hostilidade e consultas espaciais
-- ============================================================
local function inPvpZone(actor: Actor): boolean
	local zoneId = Zones.zoneAt(actor.root.Position)
	local zone = zoneId and Zones.List[zoneId]
	return zone ~= nil and zone.pvp == true
end

function CombatService.AreHostile(a: Actor, b: Actor): boolean
	if a == b then
		return false
	end
	if a.team ~= b.team then
		return true
	end
	if a.team == "Players" and b.team == "Players" then
		return inPvpZone(a) and inPvpZone(b)
	end
	return false
end

local function refreshOverlap()
	if not overlapDirty then
		return
	end
	overlapDirty = false
	table.clear(overlapList)
	for model in actors do
		table.insert(overlapList, model)
	end
end

local function overlapParams(): OverlapParams
	refreshOverlap()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = overlapList
	params.MaxParts = 200
	return params
end

local function collectActors(parts: { BasePart }, source: Actor?, hostileOnly: boolean): { Actor }
	local seen: { [Model]: boolean } = {}
	local result = {}
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		while model and not actors[model] do
			model = model:FindFirstAncestorOfClass("Model")
		end
		if model and not seen[model] then
			seen[model] = true
			local actor = actors[model]
			if
				actor
				and CombatService.IsAlive(actor)
				and actor ~= source
				and (not hostileOnly or source == nil or CombatService.AreHostile(source, actor))
			then
				table.insert(result, actor)
			end
		end
	end
	return result
end

function CombatService.QueryBox(cframe: CFrame, size: Vector3, source: Actor?): { Actor }
	return collectActors(workspace:GetPartBoundsInBox(cframe, size, overlapParams()), source, true)
end

function CombatService.QueryRadius(position: Vector3, radius: number, source: Actor?): { Actor }
	return collectActors(workspace:GetPartBoundsInRadius(position, radius, overlapParams()), source, true)
end

-- Inimigo mais próximo dentro de um cone à frente (para auto-mira, execuções e "aparecer atrás").
function CombatService.FindTarget(source: Actor, direction: Vector3, range: number, maxAngle: number, filter: ((Actor) -> boolean)?): Actor?
	local best, bestScore = nil, math.huge
	local origin = source.root.Position
	local cosLimit = math.cos(math.rad(maxAngle))
	for _, actor in actors do
		if actor ~= source and CombatService.IsAlive(actor) and CombatService.AreHostile(source, actor) then
			local offset = actor.root.Position - origin
			local distance = offset.Magnitude
			if distance <= range and distance > 0.01 then
				local dot = Physics.flat(offset):Dot(direction)
				if dot >= cosLimit and (not filter or filter(actor)) then
					local score = distance * (2 - dot)
					if score < bestScore then
						best, bestScore = actor, score
					end
				end
			end
		end
	end
	return best
end

-- ============================================================
-- Movimento (velocidade conforme estado)
-- ============================================================
function CombatService.UpdateMovement(actor: Actor)
	local humanoid = actor.humanoid
	if humanoid.Health <= 0 then
		return
	end
	local t = now()
	local speed = actor.baseWalkSpeed + actor.derived.walkSpeedBonus + CombatService.BuffValue(actor, "speed", false)
	if actor.form == "Tier1" then
		speed += 2
	elseif actor.form == "Tier2" then
		speed += 4
	end
	if actor.mask then
		speed += 4
	end
	if actor.sprinting and actor.player then
		speed += Combat.SprintSpeed - Combat.BaseWalkSpeed
	end
	local jump = true
	if t < actor.stunUntil then
		speed = Combat.StunWalkSpeed
		jump = false
	elseif actor.channel then
		speed = 0
		jump = false
	elseif t < actor.busyUntil then
		speed = math.min(speed, Combat.AttackWalkSpeed)
	elseif actor.blocking then
		speed = math.min(speed, Combat.BlockWalkSpeed)
		jump = false
	elseif actor.charging then
		speed = Combat.ChargeWalkSpeed
		jump = false
	end
	humanoid.WalkSpeed = speed
	if actor.player then
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = if jump then 8.5 else 0
	end
end

-- ============================================================
-- Recursos replicados (atributos)
-- ============================================================
function CombatService.ReplicateResources(actor: Actor, force: boolean?)
	local model = actor.model
	local reiatsu = math.floor(actor.reiatsu + 0.5)
	if force or model:GetAttribute("Reiatsu") ~= reiatsu then
		model:SetAttribute("Reiatsu", reiatsu)
	end
	local maxReiatsu = actor.derived.maxReiatsu
	if force or model:GetAttribute("MaxReiatsu") ~= maxReiatsu then
		model:SetAttribute("MaxReiatsu", maxReiatsu)
	end
	local maxGuard = Combat.MaxGuard * actor.derived.guardMultiplier
	local guardPct = math.floor(actor.guard / maxGuard * 100 + 0.5)
	if force or model:GetAttribute("Guard") ~= guardPct then
		model:SetAttribute("Guard", guardPct)
	end
end

local function setStunned(actor: Actor, untilTime: number)
	actor.stunUntil = untilTime
	actor.model:SetAttribute("Stunned", true)
	CombatService.UpdateMovement(actor)
end

function CombatService.Stun(actor: Actor, duration: number)
	local t = now()
	setStunned(actor, CombatRules.applyStun(actor.stunUntil, t, duration, Combat.Stun.maxChain))
	CombatService.Interrupt(actor)
	if actor.blocking then
		CombatService.SetBlocking(actor, false)
	end
end

-- ============================================================
-- Dano
-- ============================================================
function CombatService.DealDamage(target: Actor, amount: number, attacker: Actor?)
	if not CombatService.IsAlive(target) or amount <= 0 then
		return
	end
	if attacker then
		target.lastAttacker = attacker
		attacker.lastCombatTime = now()
		if attacker.player then
			target.damageBy[attacker.player] = (target.damageBy[attacker.player] or 0) + math.min(amount, target.humanoid.Health)
		end
	end
	target.lastCombatTime = now()
	target.humanoid.Health = math.max(0, target.humanoid.Health - amount)
end

function CombatService.HandleDeath(actor: Actor)
	if actor.dead then
		return
	end
	actor.dead = true
	actor.token += 1
	actor.blocking = false
	actor.channel = nil
	actor.model:SetAttribute("Stunned", false)
	CombatService.Broadcast("Death", { actor = actor.model, team = actor.team }, actor.root.Position)
	CombatService.ActorDied:Fire(actor, actor.lastAttacker)
end

-- Aplica um golpe (corpo a corpo, projétil ou área) já validado pelo chamador.
-- spec: damage, stun, knockback, launch, juggle, spike, guardBreak, unparryable, guardDamage,
--       projectile, heavy, hitstop, shake, kind ("Melee"|"Ability"), counter, sourcePos
function CombatService.ApplyHit(attacker: Actor, target: Actor, spec: { [string]: any }): string
	if not CombatService.IsAlive(target) or not CombatService.IsAlive(attacker) and spec.kind == "Melee" then
		return "Immune"
	end
	if not CombatService.AreHostile(attacker, target) then
		return "Immune"
	end
	local t = now()
	local origin: Vector3 = spec.sourcePos or attacker.root.Position
	local toTarget = Physics.flat(target.root.Position - origin, -target.root.CFrame.LookVector)
	local facingDot = target.root.CFrame.LookVector:Dot(-toTarget)

	local maxGuard = Combat.MaxGuard * target.derived.guardMultiplier
	local result = CombatRules.resolveDefense({
		blocking = target.blocking,
		blockStart = target.blockStart,
		guard = target.guard * (Combat.MaxGuard / maxGuard),
		iframeUntil = target.iframeUntil,
		parryBonus = target.derived.parryBonus,
	}, spec, facingDot, t, Combat.ParryWindow, Combat.BlockFacingDot)

	local hitPos = target.root.Position + Vector3.new(0, 1, 0)

	if result == "Immune" then
		CombatService.Broadcast("Evade", { actor = target.model }, hitPos)
		return result
	end

	if result == "Parry" then
		target.counterUntil = t + Combat.CounterWindow
		target.guard = math.min(maxGuard, target.guard + 25)
		target.lastGuardHit = t
		if spec.kind == "Melee" then
			CombatService.Stun(attacker, Combat.ParriedStun)
		end
		CombatService.ReplicateResources(target)
		CombatService.Broadcast("Parry", {
			defender = target.model,
			attacker = attacker.model,
			position = (target.root.Position + attacker.root.Position) / 2 + Vector3.new(0, 1.5, 0),
		}, hitPos)
		CombatService.Parried:Fire(target, attacker)
		return result
	end

	local multiplier = if spec.kind == "Ability" then attacker.derived.abilityMultiplier else attacker.derived.meleeMultiplier
	multiplier *= CombatService.FormMultiplier(attacker) * CombatService.BuffValue(attacker, "damage", true)
	if spec.counter then
		multiplier *= Combat.CounterMultiplier + attacker.derived.counterBonus
	end
	if spec.multiplier then
		multiplier *= spec.multiplier
	end
	local damage = Stats.damage(spec.damage or 0, multiplier, CombatService.Defense(target))

	if result == "GuardBreak" then
		target.guard = 0
		target.lastGuardHit = t
		damage *= 0.5
		CombatService.Stun(target, Combat.GuardBreakStun)
		CombatService.Broadcast("GuardBreak", { actor = target.model, attacker = attacker.model }, hitPos)
	elseif result == "Blocked" then
		target.guard = math.max(0, target.guard - (spec.guardDamage or 10))
		target.lastGuardHit = t
		damage *= Combat.BlockDamageMultiplier
		local push = toTarget * math.min(18, (spec.knockback or 0) * 0.4 + 6)
		if target.player then
			CombatService.SendImpulse(target, { kind = "Knockback", velocity = push, duration = 0.1 })
		else
			Physics.impulse(target.root, push, 0.1)
		end
	end
	CombatService.ReplicateResources(target)
	damage = math.floor(damage * 10 + 0.5) / 10
	CombatService.DealDamage(target, damage, attacker)

	if result == "Hit" then
		local armored = t < target.superArmorUntil
		local stun = spec.stun or 0.5
		local knockback = spec.knockback or 0
		local vertical = spec.launch or 0
		if target.isBoss then
			stun *= 0.4
			knockback *= 0.15
			vertical *= 0.15
		end
		if not armored then
			CombatService.Stun(target, stun)
			local velocity = toTarget * knockback
			if spec.juggle then
				velocity = toTarget * knockback + Vector3.new(0, spec.juggle, 0)
			elseif spec.spike then
				velocity = toTarget * knockback + Vector3.new(0, -spec.spike, 0)
			elseif vertical > 0 then
				velocity += Vector3.new(0, vertical, 0)
			elseif knockback >= 30 then
				velocity += Vector3.new(0, 14, 0)
			end
			if velocity.Magnitude > 1 then
				local duration = if spec.spike then 0.2 elseif vertical > 0 or spec.juggle then 0.12 else 0.16
				if target.player then
					CombatService.SendImpulse(target, { kind = "Knockback", velocity = velocity, duration = duration })
				else
					Physics.impulse(target.root, velocity, duration)
				end
			end
		end
	end

	if spec.kind == "Melee" then
		CombatService.AddReiatsu(attacker, Combat.Reiatsu.onHitGain)
	end

	CombatService.Broadcast("Hit", {
		attacker = attacker.model,
		target = target.model,
		result = result,
		damage = damage,
		position = hitPos,
		heavy = spec.heavy == true,
		counter = spec.counter == true,
		hitstop = spec.hitstop or 0.05,
		shake = spec.shake or 0.15,
		element = spec.element,
		launched = (spec.launch or 0) > 20 or spec.juggle ~= nil,
	}, hitPos)
	CombatService.HitLanded:Fire(attacker, target, result, damage)
	return result
end

-- ============================================================
-- Ataques corpo a corpo
-- ============================================================
local function setDrawn(actor: Actor, drawn: boolean)
	if actor.drawn == drawn then
		return
	end
	actor.drawn = drawn
	actor.model:SetAttribute("Drawn", drawn)
	local characterService = Registry.CharacterService
	if characterService then
		characterService.SetWeaponDrawn(actor, drawn)
	end
end

CombatService.SetDrawn = setDrawn

local function hitboxFrame(actor: Actor, direction: Vector3, offset: CFrame): CFrame
	local position = actor.root.Position
	return CFrame.lookAt(position, position + direction) * offset
end

local function validDirection(actor: Actor, aimDir: any): Vector3
	if typeof(aimDir) == "Vector3" and aimDir.Magnitude > 0.5 and aimDir.Magnitude < 1.5 then
		return Physics.flat(aimDir, actor.root.CFrame.LookVector)
	end
	return Physics.flat(actor.root.CFrame.LookVector)
end

CombatService.ValidDirection = validDirection

-- kind: "Light" | "Heavy" | "Launcher"
function CombatService.TryAttack(actor: Actor, kind: string, aimDir: any): boolean
	if not CombatService.CanAct(actor, false) or actor.blocking then
		return false
	end
	local t = now()
	local direction = validDirection(actor, aimDir)
	local spec, animIndex
	local cooldownKey: string? = nil
	local aerial = false
	local executionTarget: Actor? = nil

	if kind == "Light" then
		if t < actor.counterUntil then
			spec = Combat.Counter
			actor.counterUntil = 0
		elseif CombatService.IsAirborne(actor) then
			aerial = true
			local index = CombatRules.nextComboIndex(actor.combo.aerial, actor.combo.aerialLastEnd, t, #Combat.Aerial, Combat.ComboResetTime)
			spec = Combat.Aerial[index]
			animIndex = index
			actor.combo.aerial = index
			actor.combo.aerialLastEnd = t + spec.duration
		else
			local index = CombatRules.nextComboIndex(actor.combo.index, actor.combo.lastEnd, t, #Combat.Light, Combat.ComboResetTime)
			spec = Combat.Light[index]
			animIndex = index
			actor.combo.index = index
			actor.combo.lastEnd = t + spec.duration
		end
	elseif kind == "Heavy" then
		executionTarget = CombatService.FindTarget(actor, direction, Combat.Execution.range, 50, function(target)
			return CombatService.IsStunned(target, t)
				and target.humanoid.Health / target.humanoid.MaxHealth <= Combat.Execution.healthThreshold
				and not target.isBoss
		end)
		if executionTarget and CombatService.CooldownReady(actor, "Execution") then
			spec = Combat.Execution
			cooldownKey = "Execution"
			direction = Physics.flat(executionTarget.root.Position - actor.root.Position, direction)
		else
			executionTarget = nil
			if not CombatService.CooldownReady(actor, "Heavy") then
				return false
			end
			spec = Combat.Heavy
			cooldownKey = "Heavy"
		end
	elseif kind == "Launcher" then
		if not CombatService.CooldownReady(actor, "Launcher") then
			return false
		end
		spec = Combat.Launcher
		cooldownKey = "Launcher"
	else
		return false
	end

	setDrawn(actor, true)
	local duration = spec.duration
	-- Fim de sequência ganha um pequeno atraso extra
	if spec.finisher then
		duration += Combat.ComboEndLag * 0.5
	end
	local token = CombatService.SetBusy(actor, duration, spec.windup + 0.04)
	if cooldownKey then
		CombatService.SetCooldown(actor, cooldownKey, (spec.cooldown or 0) * actor.derived.cooldownMultiplier)
	end
	if spec.cinematic or (actor.enemyId and actor.extra.superArmorAttacks) then
		actor.superArmorUntil = t + spec.windup + 0.05
	end
	if executionTarget then
		-- "Agarra" o alvo para a execução conectar
		CombatService.Stun(executionTarget, spec.windup + 0.4)
	end

	CombatService.Broadcast("Attack", {
		actor = actor.model,
		anim = spec.anim,
		kind = kind,
		index = animIndex,
		aerial = aerial,
		direction = direction,
		windup = spec.windup,
		duration = duration,
		target = executionTarget and executionTarget.model or nil,
		cinematic = spec.cinematic == true,
	}, actor.root.Position)
	CombatService.AttackStarted:Fire(actor, spec, kind)

	-- NPCs avançam no servidor; jogadores aplicam o próprio avanço localmente.
	if not actor.player and spec.lunge then
		Physics.impulse(actor.root, direction * spec.lunge * 4, 0.12)
	end

	task.delay(spec.windup, function()
		if actor.token ~= token or not CombatService.IsAlive(actor) then
			return
		end
		local frame = hitboxFrame(actor, direction, spec.hitbox.offset)
		local targets = CombatService.QueryBox(frame, spec.hitbox.size, actor)
		local hitSpec = {
			kind = "Melee",
			damage = spec.damage,
			stun = spec.stun,
			knockback = spec.knockback,
			launch = spec.launch,
			juggle = spec.juggle,
			spike = spec.spike,
			guardBreak = spec.guardBreak,
			unparryable = spec.unparryable,
			guardDamage = spec.guardDamage,
			heavy = spec.heavy,
			hitstop = spec.hitstop,
			shake = spec.shake,
			counter = spec == Combat.Counter,
		}
		local landed = false
		for _, target in targets do
			local result = CombatService.ApplyHit(actor, target, hitSpec)
			if result == "Hit" or result == "Blocked" or result == "GuardBreak" then
				landed = true
			end
		end
		if landed then
			if aerial then
				if actor.player then
					CombatService.SendImpulse(actor, { kind = "Hover", duration = Combat.AirHover })
				else
					Physics.hover(actor.root, Combat.AirHover)
				end
			end
			if spec.selfLaunch then
				if actor.player then
					CombatService.SendImpulse(actor, { kind = "Knockback", velocity = Vector3.new(0, spec.selfLaunch, 0) + direction * 4, duration = 0.12 })
				else
					Physics.impulse(actor.root, Vector3.new(0, spec.selfLaunch, 0), 0.12)
				end
			end
		end
		-- Especialização "Mestre da Lâmina": o 5º golpe libera uma onda de corte.
		if spec.finisher and not aerial and actor.derived.finisherWave and Registry.AbilityService then
			Registry.AbilityService.SpawnProjectile(actor, {
				id = "FinisherWave",
				shape = "Crescent",
				element = nil,
				speed = 130,
				range = 60,
				radius = 4,
				size = 1.3,
				pierce = true,
				damage = 9,
				stun = 0.6,
				knockback = 20,
			}, actor.root.Position + Vector3.new(0, 1, 0) + direction * 3, direction)
		end
	end)
	return true
end

-- ============================================================
-- Bloqueio / parry
-- ============================================================
function CombatService.SetBlocking(actor: Actor, blocking: boolean): boolean
	local t = now()
	if blocking then
		if actor.blocking or not CombatService.CanAct(actor, true) then
			return false
		end
		if t < actor.busyUntil then
			-- cancela recuperação do golpe
			actor.token += 1
			actor.busyUntil = 0
		end
		actor.blocking = true
		-- Soltar e apertar rápido demais não gera nova janela de parry (anti-spam)
		actor.blockStart = if t - actor.blockReleasedAt >= Combat.BlockCooldownAfterRelease then t else -1e9
		setDrawn(actor, true)
	else
		if not actor.blocking then
			return false
		end
		actor.blocking = false
		actor.blockReleasedAt = t
	end
	actor.model:SetAttribute("Blocking", actor.blocking)
	CombatService.UpdateMovement(actor)
	CombatService.Broadcast("Block", { actor = actor.model, blocking = actor.blocking }, actor.root.Position)
	return true
end

-- ============================================================
-- Dash (esquiva com i-frames)
-- ============================================================
function CombatService.TryDash(actor: Actor, direction: any): boolean
	if not CombatService.CanAct(actor, true) then
		return false
	end
	if not CombatService.CooldownReady(actor, "Dash") then
		return false
	end
	local t = now()
	local dir = validDirection(actor, direction)
	if t < actor.busyUntil then
		actor.token += 1
		actor.busyUntil = 0
	end
	if actor.blocking then
		CombatService.SetBlocking(actor, false)
	end
	actor.iframeUntil = t + Combat.Dash.iframes
	CombatService.SetCooldown(actor, "Dash", Combat.Dash.cooldown * actor.derived.dashCooldownMultiplier)
	if not actor.player then
		Physics.impulse(actor.root, dir * Combat.Dash.speed, Combat.Dash.duration)
	end
	CombatService.Broadcast("Dash", { actor = actor.model, direction = dir }, actor.root.Position)
	CombatService.UpdateMovement(actor)
	return true
end

-- ============================================================
-- Carregar Reiatsu / corrida
-- ============================================================
function CombatService.SetCharging(actor: Actor, charging: boolean)
	if charging and (not CombatService.CanAct(actor, false) or actor.blocking) then
		return
	end
	if actor.charging == charging then
		return
	end
	actor.charging = charging
	actor.model:SetAttribute("Charging", charging)
	CombatService.UpdateMovement(actor)
end

function CombatService.SetSprinting(actor: Actor, sprinting: boolean)
	actor.sprinting = sprinting == true
	CombatService.UpdateMovement(actor)
end

-- ============================================================
-- Laço de atualização (10 Hz)
-- ============================================================
local TICK = 0.1
local accumulator = 0

local function tick(dt: number)
	local t = now()
	for _, actor in actors do
		if actor.dead then
			continue
		end
		-- Fim do stun
		if actor.model:GetAttribute("Stunned") and t >= actor.stunUntil then
			actor.model:SetAttribute("Stunned", false)
			CombatService.UpdateMovement(actor)
		end
		-- Guarda
		local maxGuard = Combat.MaxGuard * actor.derived.guardMultiplier
		if actor.guard < maxGuard and not actor.blocking then
			actor.guard = CombatRules.regenGuard(actor.guard, maxGuard, t - actor.lastGuardHit, Combat.GuardRegenDelay, Combat.GuardRegenPerSecond, dt)
		end
		-- Reiatsu: carga, regeneração (só na forma base) e dreno de formas
		if actor.charging then
			if not CombatService.CanAct(actor, false) then
				CombatService.SetCharging(actor, false)
			else
				actor.reiatsu = math.min(actor.derived.maxReiatsu, actor.reiatsu + Combat.Charge.reiatsuPerSecond * dt)
			end
		elseif actor.form == "Base" and not actor.mask and t - actor.lastReiatsuUse > Combat.Reiatsu.regenDelay then
			actor.reiatsu = math.min(actor.derived.maxReiatsu, actor.reiatsu + Combat.Reiatsu.regenPerSecond * dt)
		end
		if Registry.TransformationService then
			Registry.TransformationService.Tick(actor, dt, t)
		end
		-- Buffs expirados
		for id, buff in actor.buffs do
			if buff.untilTime <= t then
				CombatService.RemoveBuff(actor, id)
			end
		end
		-- Embainhar após inatividade
		if actor.drawn and actor.player and t - actor.lastCombatTime > 10 and t > actor.busyUntil and not actor.blocking then
			setDrawn(actor, false)
		end
		CombatService.ReplicateResources(actor)
	end
end

-- ============================================================
-- Entrada do cliente
-- ============================================================
local VALID_ACTIONS = {
	Light = true,
	Heavy = true,
	Launcher = true,
	BlockStart = true,
	BlockEnd = true,
	Dash = true,
	ChargeStart = true,
	ChargeEnd = true,
	SprintStart = true,
	SprintEnd = true,
	Ability = true,
	Transform = true,
	Mask = true,
	Draw = true,
}

local RateLimiter = require(Shared.Util.RateLimiter)
local inputLimiter = RateLimiter.new(30, 40)

local function onCombatInput(player: Player, action: any, payload: any)
	if type(action) ~= "string" or not VALID_ACTIONS[action] then
		return
	end
	if not inputLimiter:Check(player) then
		return
	end
	local actor = CombatService.GetByPlayer(player)
	if not actor or not CombatService.IsAlive(actor) then
		return
	end
	if type(payload) ~= "table" then
		payload = {}
	end
	if action == "Light" or action == "Heavy" or action == "Launcher" then
		CombatService.TryAttack(actor, action, payload.direction)
	elseif action == "BlockStart" then
		CombatService.SetBlocking(actor, true)
	elseif action == "BlockEnd" then
		CombatService.SetBlocking(actor, false)
	elseif action == "Dash" then
		CombatService.TryDash(actor, payload.direction)
	elseif action == "ChargeStart" then
		CombatService.SetCharging(actor, true)
	elseif action == "ChargeEnd" then
		CombatService.SetCharging(actor, false)
	elseif action == "SprintStart" then
		CombatService.SetSprinting(actor, true)
	elseif action == "SprintEnd" then
		CombatService.SetSprinting(actor, false)
	elseif action == "Draw" then
		if CombatService.CanAct(actor, false) then
			setDrawn(actor, not actor.drawn)
			actor.lastCombatTime = now()
		end
	elseif action == "Ability" then
		if Registry.AbilityService then
			Registry.AbilityService.RequestSlot(actor, payload.slot, payload.direction, payload.aim)
		end
	elseif action == "Transform" then
		if Registry.TransformationService then
			Registry.TransformationService.RequestRelease(actor)
		end
	elseif action == "Mask" then
		if Registry.TransformationService then
			Registry.TransformationService.RequestMask(actor)
		end
	end
end

function CombatService.Init()
	fxRemote = Net.event("Fx")
	impulseRemote = Net.event("Impulse")
	stateRemote = Net.event("State")
end

function CombatService.Start()
	Net.event("CombatInput").OnServerEvent:Connect(onCombatInput)
	Players.PlayerRemoving:Connect(function(player)
		inputLimiter:Remove(player)
		for _, actor in actors do
			actor.damageBy[player] = nil
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		local step = accumulator
		accumulator = 0
		local ok, err = pcall(tick, step)
		if not ok then
			log:Error("tick:", err)
		end
	end)
end

return CombatService

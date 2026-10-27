-- Execução autoritativa de habilidades orientadas a dados (Config/Abilities).
-- Cada `kind` tem um handler genérico; o cliente recebe eventos para desenhar os efeitos.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Abilities = require(Shared.Config.Abilities)
local Factions = require(Shared.Config.Factions)
local Powers = require(Shared.Config.Powers)
local Loadout = require(Shared.Logic.Loadout)
local Physics = require(Shared.Physics)
local Signal = require(Shared.Util.Signal)
local Log = require(Shared.Util.Log)

local Registry = require(script.Parent.Parent.Registry)

local log = Log.new("AbilityService")

local AbilityService = {}
AbilityService.AbilityUsed = Signal.new() -- (actor, abilityId)

local CombatService -- preenchido no Init

local VALID_SLOTS = { Z = true, X = true, C = true, V = true }

local mapParams = RaycastParams.new()
mapParams.FilterType = Enum.RaycastFilterType.Include

local function refreshMapFilter()
	local map = workspace:FindFirstChild("Map")
	mapParams.FilterDescendantsInstances = if map then { map, workspace.Terrain } else { workspace.Terrain }
end

-- Elemento efetivo (habilidade > poder > facção)
local function elementFor(actor, def): string
	if def.element then
		return def.element
	end
	local power = actor.power and Powers.get(actor.power)
	if power and power.faction == actor.faction then
		return power.element
	end
	local faction = Factions.get(actor.faction)
	return faction and faction.element or "Reiatsu"
end

local function hitSpecFor(def, element: string, overrides: { [string]: any }?)
	local spec = {
		kind = "Ability",
		damage = def.damage,
		stun = def.stun,
		knockback = def.knockback,
		launch = def.launch,
		guardDamage = 22,
		heavy = def.ultimate == true or (def.damage or 0) >= 18,
		hitstop = if def.ultimate then 0.08 else 0.04,
		shake = if def.ultimate then 0.5 else 0.2,
		element = element,
	}
	if overrides then
		for k, v in overrides do
			spec[k] = v
		end
	end
	return spec
end

-- Mira: direção horizontal validada e ponto clamped ao alcance.
local function resolveAim(actor, def, direction: any, aim: any): (Vector3, Vector3)
	local dir = CombatService.ValidDirection(actor, direction)
	local origin = actor.root.Position
	local range = def.range or 40
	local point: Vector3
	if typeof(aim) == "Vector3" then
		local offset = aim - origin
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > range then
			flat = flat.Unit * range
		end
		point = origin + flat
	else
		point = origin + dir * math.min(range, 25)
	end
	-- Projeta no chão
	refreshMapFilter()
	local ground = workspace:Raycast(point + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), mapParams)
	if ground then
		point = ground.Position
	else
		point = Vector3.new(point.X, origin.Y - 3, point.Z)
	end
	return dir, point
end

-- ============================================================
-- Projéteis (simulados no servidor; o cliente desenha a mesma trajetória)
-- ============================================================
type Projectile = {
	id: number,
	owner: any,
	def: any,
	element: string,
	position: Vector3,
	direction: Vector3,
	speed: number,
	travelled: number,
	range: number,
	radius: number,
	pierce: boolean,
	hit: { [any]: boolean },
	spec: any,
}

local projectiles: { Projectile } = {}
local nextProjectileId = 0

local function explode(projectile: Projectile, position: Vector3)
	local def = projectile.def
	if def.explodeRadius then
		local targets = CombatService.QueryRadius(position, def.explodeRadius, projectile.owner)
		for _, target in targets do
			if not projectile.hit[target] then
				CombatService.ApplyHit(projectile.owner, target, projectile.spec)
			end
		end
	end
	CombatService.Broadcast("ProjectileEnd", {
		id = projectile.id,
		position = position,
		explode = def.explodeRadius,
		element = projectile.element,
	}, position)
end

function AbilityService.SpawnProjectile(actor, def, origin: Vector3, direction: Vector3)
	nextProjectileId += 1
	local element = elementFor(actor, def)
	local projectile: Projectile = {
		id = nextProjectileId,
		owner = actor,
		def = def,
		element = element,
		position = origin,
		direction = direction.Unit,
		speed = def.speed or 120,
		travelled = 0,
		range = def.range or 100,
		radius = def.radius or 3,
		pierce = def.pierce == true,
		hit = {},
		spec = hitSpecFor(def, element, { projectile = true, sourcePos = origin }),
	}
	table.insert(projectiles, projectile)
	CombatService.Broadcast("Projectile", {
		id = projectile.id,
		owner = actor.model,
		ability = def.id,
		shape = def.shape,
		size = def.size or 1,
		element = element,
		origin = origin,
		direction = projectile.direction,
		speed = projectile.speed,
		range = projectile.range,
	}, origin)
	return projectile.id
end

local function stepProjectiles(dt: number)
	if #projectiles == 0 then
		return
	end
	refreshMapFilter()
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		local alive = CombatService.IsAlive(p.owner) or p.owner.model.Parent ~= nil
		local step = p.speed * dt
		local finished = false
		local endPosition = p.position + p.direction * step

		-- Colisão com o mapa
		local wall = workspace:Raycast(p.position, p.direction * step, mapParams)
		if wall then
			endPosition = wall.Position
			finished = true
		end

		-- Colisão com atores ao longo do segmento (amostras evitam atravessar alvos rápidos)
		if alive then
			local samples = math.max(1, math.ceil(step / (p.radius * 1.5)))
			for s = 1, samples do
				local point = p.position:Lerp(endPosition, s / samples)
				p.spec.sourcePos = point - p.direction * 2
				local targets = CombatService.QueryRadius(point, p.radius, p.owner)
				for _, target in targets do
					if not p.hit[target] then
						p.hit[target] = true
						CombatService.ApplyHit(p.owner, target, p.spec)
						if not p.pierce then
							endPosition = point
							finished = true
							break
						end
					end
				end
				if finished then
					break
				end
			end
		end

		p.travelled += (endPosition - p.position).Magnitude
		p.position = endPosition
		if p.travelled >= p.range then
			finished = true
		end
		if finished or not alive then
			table.remove(projectiles, i)
			explode(p, p.position)
		end
	end
end

-- ============================================================
-- Handlers por tipo
-- ============================================================
local Handlers = {}

function Handlers.Projectile(actor, def, dir: Vector3, _point: Vector3, element: string)
	local count = def.count or 1
	local spread = math.rad(def.spread or 0)
	local origin = actor.root.Position + Vector3.new(0, 1.2, 0) + dir * 2.5
	for i = 1, count do
		local angle = 0
		if count > 1 then
			angle = -spread / 2 + spread * (i - 1) / (count - 1)
		end
		local direction = (CFrame.Angles(0, angle, 0) * CFrame.lookAt(Vector3.zero, dir)).LookVector
		AbilityService.SpawnProjectile(actor, def, origin, direction)
	end
	return element
end

function Handlers.Beam(actor, def, dir: Vector3, _point: Vector3, element: string, token: number)
	local origin = actor.root.Position + Vector3.new(0, 1.3, 0) + dir * 2
	refreshMapFilter()
	local length = def.length
	local wall = workspace:Raycast(origin, dir * length, mapParams)
	if wall then
		length = (wall.Position - origin).Magnitude
	end
	CombatService.Broadcast("Beam", {
		actor = actor.model,
		ability = def.id,
		shape = def.shape,
		element = element,
		origin = origin,
		direction = dir,
		length = length,
		radius = def.radius,
		duration = def.ticks * def.interval + 0.25,
		ultimate = def.ultimate == true,
	}, origin)
	local spec = hitSpecFor(def, element, { projectile = true, unparryable = true, sourcePos = origin })
	for tick = 1, def.ticks do
		if not CombatService.IsAlive(actor) or (actor.token ~= token and not def.superArmor) then
			break
		end
		local center = origin + dir * (length / 2)
		local frame = CFrame.lookAt(center, center + dir)
		local targets = CombatService.QueryBox(frame, Vector3.new(def.radius * 2, def.radius * 2, length), actor)
		for _, target in targets do
			CombatService.ApplyHit(actor, target, spec)
		end
		if tick < def.ticks then
			task.wait(def.interval)
		end
	end
end

function Handlers.DashStrike(actor, def, dir: Vector3, _point: Vector3, element: string)
	local start = actor.root.Position
	local destination: Vector3
	local target = CombatService.FindTarget(actor, dir, def.distance, if def.behind then 70 else 40)
	if def.behind and target then
		destination = (target.root.CFrame * CFrame.new(0, 0, 4)).Position
	elseif def.leap and target then
		destination = target.root.Position - Physics.flat(target.root.Position - start, dir) * 3
	else
		refreshMapFilter()
		local wall = workspace:Raycast(start, dir * def.distance, mapParams)
		local distance = if wall then math.max(0, (wall.Position - start).Magnitude - 2.5) else def.distance
		destination = start + dir * distance
	end
	local faceTarget = if target then target.root.Position else destination + dir
	local finalCFrame = CFrame.lookAt(destination, Vector3.new(faceTarget.X, destination.Y, faceTarget.Z))

	if actor.player then
		CombatService.SendImpulse(actor, { kind = "Teleport", cframe = finalCFrame, leap = def.leap == true })
	end
	actor.root.CFrame = finalCFrame
	actor.iframeUntil = math.max(actor.iframeUntil, CombatService.now() + 0.25)

	CombatService.Broadcast("DashStrike", {
		actor = actor.model,
		ability = def.id,
		element = element,
		from = start,
		to = destination,
		leap = def.leap == true,
		hits = def.hits or 1,
	}, start)

	local spec = hitSpecFor(def, element, { sourcePos = start })
	local path = destination - start
	local length = math.max(path.Magnitude, 4)
	local center = start + path / 2
	local direction = if path.Magnitude > 0.1 then path.Unit else dir
	for hit = 1, def.hits or 1 do
		local targets
		if def.leap then
			targets = CombatService.QueryRadius(destination, def.width, actor)
		else
			targets = CombatService.QueryBox(
				CFrame.lookAt(center, center + direction),
				Vector3.new(def.width, 8, length + 4),
				actor
			)
		end
		for _, t in targets do
			spec.sourcePos = if def.leap then destination else start
			CombatService.ApplyHit(actor, t, spec)
		end
		if hit < (def.hits or 1) then
			task.wait(0.12)
		end
	end
end

function Handlers.Burst(actor, def, dir: Vector3, point: Vector3, element: string, token: number)
	local center = if def.target == "Aim" then point else actor.root.Position - Vector3.new(0, 2.5, 0)
	local ticks = def.ticks or 1
	local interval = def.interval or 0.2
	CombatService.Broadcast("Burst", {
		actor = actor.model,
		ability = def.id,
		element = element,
		center = center,
		radius = def.radius,
		delay = def.delay or 0,
		ticks = ticks,
		interval = interval,
		ultimate = def.ultimate == true,
		follow = def.target ~= "Aim",
	}, center)
	if def.delay and def.delay > 0 then
		task.wait(def.delay)
	end
	local spec = hitSpecFor(def, element, { unparryable = true })
	for tick = 1, ticks do
		if
			not CombatService.IsAlive(actor) or (actor.token ~= token and not def.superArmor and def.target ~= "Aim")
		then
			break
		end
		if def.target ~= "Aim" then
			center = actor.root.Position - Vector3.new(0, 2.5, 0)
		end
		spec.sourcePos = center
		for _, target in CombatService.QueryRadius(center + Vector3.new(0, 2.5, 0), def.radius, actor) do
			CombatService.ApplyHit(actor, target, spec)
		end
		if tick < ticks then
			task.wait(interval)
		end
	end
	return dir
end

function Handlers.Rain(actor, def, _dir: Vector3, point: Vector3, element: string)
	CombatService.Broadcast("Rain", {
		actor = actor.model,
		ability = def.id,
		element = element,
		center = point,
		radius = def.radius,
		ticks = def.ticks,
		interval = def.interval,
		ultimate = def.ultimate == true,
	}, point)
	local spec =
		hitSpecFor(def, element, { projectile = true, unparryable = true, sourcePos = point + Vector3.new(0, 30, 0) })
	task.wait(0.25)
	for tick = 1, def.ticks do
		if not CombatService.IsAlive(actor) then
			break
		end
		for _, target in CombatService.QueryRadius(point + Vector3.new(0, 2, 0), def.radius, actor) do
			spec.sourcePos = target.root.Position + Vector3.new(0.1, 20, 0)
			CombatService.ApplyHit(actor, target, spec)
		end
		if tick < def.ticks then
			task.wait(def.interval)
		end
	end
end

function Handlers.Buff(actor, def, _dir: Vector3, _point: Vector3, element: string)
	CombatService.AddBuff(actor, def.id, def.buff or {}, def.buffDuration or 5)
	CombatService.Broadcast("Buff", {
		actor = actor.model,
		ability = def.id,
		element = element,
		duration = def.buffDuration or 5,
		radius = def.radius,
	}, actor.root.Position)
	if def.radius and (def.damage or 0) > 0 then
		local spec = hitSpecFor(def, element, { unparryable = true, sourcePos = actor.root.Position })
		for _, target in CombatService.QueryRadius(actor.root.Position, def.radius, actor) do
			CombatService.ApplyHit(actor, target, spec)
		end
	end
end

function Handlers.Pull(actor, def, dir: Vector3, _point: Vector3, element: string)
	local origin = actor.root.Position
	local center = origin + dir * (def.range / 2)
	local candidates =
		CombatService.QueryBox(CFrame.lookAt(center, center + dir), Vector3.new(def.width * 2, 8, def.range), actor)
	local target, best = nil, math.huge
	for _, c in candidates do
		local d = (c.root.Position - origin).Magnitude
		if d < best then
			target, best = c, d
		end
	end
	CombatService.Broadcast("Pull", {
		actor = actor.model,
		ability = def.id,
		element = element,
		target = target and target.model or nil,
		endPoint = if target then target.root.Position else origin + dir * def.range,
	}, origin)
	if not target then
		return
	end
	local spec = hitSpecFor(def, element, { knockback = 0, sourcePos = origin })
	local result = CombatService.ApplyHit(actor, target, spec)
	if result == "Hit" and not target.isBoss then
		local toCaster = origin + dir * 4 - target.root.Position
		local velocity = Physics.flat(toCaster) * math.clamp(toCaster.Magnitude * 4.5, 30, 160) + Vector3.new(0, 10, 0)
		if target.player then
			CombatService.SendImpulse(target, { kind = "Knockback", velocity = velocity, duration = 0.2 })
		else
			Physics.impulse(target.root, velocity, 0.2)
		end
	end
end

function Handlers.Barrage(actor, def, dir: Vector3, _point: Vector3, element: string, token: number)
	CombatService.Broadcast("Barrage", {
		actor = actor.model,
		ability = def.id,
		element = element,
		direction = dir,
		range = def.range,
		angle = def.angle,
		ticks = def.ticks,
		interval = def.interval,
		ultimate = def.ultimate == true,
	}, actor.root.Position)
	local cosLimit = math.cos(math.rad(def.angle / 2))
	local spec = hitSpecFor(def, element)
	for tick = 1, def.ticks do
		if not CombatService.IsAlive(actor) or (actor.token ~= token and not def.superArmor) then
			break
		end
		local origin = actor.root.Position
		spec.sourcePos = origin
		for _, target in CombatService.QueryRadius(origin, def.range, actor) do
			local offset = Physics.flat(target.root.Position - origin)
			if offset:Dot(dir) >= cosLimit then
				CombatService.ApplyHit(actor, target, spec)
			end
		end
		if tick < def.ticks then
			task.wait(def.interval)
		end
	end
end

-- ============================================================
-- Conjuração
-- ============================================================
function AbilityService.ResolveSlots(actor)
	return Loadout.resolve(Factions, Powers.List, actor.faction, actor.power, actor.form, actor.mask, actor.level)
end

-- Conjura a habilidade `abilityId` (já validada como pertencente ao ator).
function AbilityService.Cast(actor, abilityId: string, direction: any, aim: any, cooldownKey: string?): boolean
	local def = Abilities[abilityId]
	if not def then
		return false
	end
	if not CombatService.CanAct(actor, true) or actor.blocking then
		return false
	end
	local key = cooldownKey or ("Ability:" .. abilityId)
	if not CombatService.CooldownReady(actor, key) then
		return false
	end
	local cost = (def.cost or 0) * actor.derived.abilityCostMultiplier
	if actor.reiatsu < cost then
		if actor.player then
			Registry.UIService.Notify(actor.player, "Reiatsu insuficiente", "warn")
		end
		return false
	end
	CombatService.SpendReiatsu(actor, cost)

	local t = CombatService.now()
	local dir, point = resolveAim(actor, def, direction, aim)
	local element = elementFor(actor, def)
	CombatService.SetDrawn(actor, true)
	local token = CombatService.SetBusy(actor, def.duration, def.windup + 0.1)
	CombatService.SetCooldown(actor, key, def.cooldown * actor.derived.cooldownMultiplier)
	if def.superArmor then
		actor.superArmorUntil = t + def.duration
	end

	CombatService.Broadcast("Cast", {
		actor = actor.model,
		ability = abilityId,
		anim = def.anim,
		element = element,
		windup = def.windup,
		duration = def.duration,
		direction = dir,
		point = point,
		ultimate = def.ultimate == true,
		kind = def.kind,
	}, actor.root.Position)
	AbilityService.AbilityUsed:Fire(actor, abilityId)

	task.delay(def.windup, function()
		if not CombatService.IsAlive(actor) then
			return
		end
		if actor.token ~= token and not def.superArmor then
			-- Interrompido antes de liberar: devolve metade do custo
			CombatService.AddReiatsu(actor, cost * 0.5)
			return
		end
		local handler = Handlers[def.kind]
		if not handler then
			log:Warn("Sem handler para", def.kind)
			return
		end
		local ok, err = pcall(handler, actor, def, dir, point, element, token)
		if not ok then
			log:Error("Habilidade", abilityId, "falhou:", err)
		end
	end)
	return true
end

-- Pedido do jogador por espaço (Z/X/C/V). O servidor resolve qual habilidade é.
function AbilityService.RequestSlot(actor, slot: any, direction: any, aim: any): boolean
	if type(slot) ~= "string" or not VALID_SLOTS[slot] then
		return false
	end
	local slots = AbilityService.ResolveSlots(actor)
	local abilityId = slots[slot]
	if not abilityId then
		return false
	end
	return AbilityService.Cast(actor, abilityId, direction, aim, "Slot:" .. slot)
end

function AbilityService.Init()
	CombatService = Registry.CombatService
end

function AbilityService.Start()
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(stepProjectiles, dt)
		if not ok then
			log:Error("projéteis:", err)
		end
	end)
end

return AbilityService

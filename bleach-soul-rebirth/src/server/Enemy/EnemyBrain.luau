-- IA de inimigos: máquina de estados leve (8 Hz) que usa as mesmas APIs de combate dos jogadores.
-- Ociosa/Patrulha → Perseguir → Atacar (combo) / Habilidade / Reagir (esquiva, bloqueio, parry) → Recuar.
-- Navegação: linha reta quando o caminho está livre; PathfindingService quando há obstáculo ou o
-- inimigo emperra. Espaçamento: no máximo ATTACKERS inimigos atacam o mesmo jogador; os outros
-- rondam em círculo na distância de combate esperando a vez (grupos não se empilham no jogador).
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Abilities = require(Shared.Config.Abilities)
local Combat = require(Shared.Config.Combat)
local Clips = require(Shared.Anim.Clips)
local Physics = require(Shared.Physics)

local Registry = require(script.Parent.Parent.Registry)

local EnemyBrain = {}
EnemyBrain.__index = EnemyBrain

local rng = Random.new()

local ATTACKERS = 2 -- inimigos comuns atacando o mesmo jogador ao mesmo tempo
local PATH_REFRESH = 1.2 -- s entre recálculos de caminho
local slots: { [any]: { [any]: number } } = {} -- alvo → { cérebro → validade do slot }

local function attackSlot(brain, target, now: number): boolean
	if brain.def.boss then
		return true
	end
	local holders = slots[target]
	if not holders then
		holders = {}
		slots[target] = holders
	end
	local count = 0
	for other, untilTime in holders do
		if untilTime < now or other.target ~= target then
			holders[other] = nil
		elseif other ~= brain then
			count += 1
		end
	end
	if holders[brain] or count < ATTACKERS then
		holders[brain] = now + 2.5
		return true
	end
	return false
end

local function releaseSlot(brain)
	for _, holders in slots do
		holders[brain] = nil
	end
end

function EnemyBrain.new(actor, def, spawnPosition: Vector3)
	local self = setmetatable({}, EnemyBrain)
	self.actor = actor
	self.def = def
	self.spawn = spawnPosition
	self.target = nil
	self.comboLeft = 0
	self.nextDecision = 0
	self.nextAbility = os.clock() + rng:NextNumber(1.5, 3.5)
	self.blockUntil = 0
	self.phase = 1
	self.phaseDef = def.phases and def.phases[1] or nil
	self.speedMultiplier = 1
	self.lastMoveTarget = nil
	self.stuckSince = nil
	self.lastPosition = spawnPosition
	-- navegação
	self.path = nil :: { PathWaypoint }?
	self.pathIndex = 0
	self.pathGoal = nil :: Vector3?
	self.pathAt = 0
	self.computing = false
	self.forcePathUntil = 0
	-- ronda
	self.strafeSign = if rng:NextNumber() < 0.5 then 1 else -1
	self.strafeSwitch = 0
	self.engaged = false
	self.lastRoar = -math.huge
	return self
end

function EnemyBrain:Abilities()
	if self.phaseDef then
		return self.phaseDef.abilities or {}
	end
	return self.def.abilities or {}
end

local function horizontalDistance(a: Vector3, b: Vector3): number
	local d = a - b
	return Vector3.new(d.X, 0, d.Z).Magnitude
end

function EnemyBrain:FindTarget()
	local CombatService = Registry.CombatService
	local actor = self.actor
	local best, bestScore = nil, math.huge
	for _, other in CombatService.All() do
		if other.player and CombatService.IsAlive(other) then
			local distance = horizontalDistance(other.root.Position, actor.root.Position)
			local leash = horizontalDistance(other.root.Position, self.spawn)
			if distance <= self.def.aggroRange and leash <= self.def.leashRange then
				-- Chefes priorizam quem causou mais dano
				local threat = actor.damageBy[other.player] or 0
				local score = distance - threat * 0.05
				if score < bestScore then
					best, bestScore = other, score
				end
			end
		end
	end
	return best
end

function EnemyBrain:Face(position: Vector3)
	local root = self.actor.root
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	local ignore: { Instance } = {}
	for _, name in { "Enemies", "Bosses", "Effects" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	return params
end

-- Linha livre na altura da cintura e dos pés até o destino?
function EnemyBrain:ClearLine(goal: Vector3): boolean
	local root = self.actor.root
	local params = rayParams()
	local hip = self.actor.humanoid.HipHeight
	for _, height in { 0, -hip * 0.8 } do
		local from = root.Position + Vector3.new(0, height, 0)
		local to = Vector3.new(goal.X, from.Y, goal.Z)
		local delta = to - from
		if delta.Magnitude > 0.5 and workspace:Raycast(from, delta, params) then
			return false
		end
	end
	return true
end

function EnemyBrain:ComputePath(goal: Vector3)
	if self.computing then
		return
	end
	self.computing = true
	local root = self.actor.root
	local humanoid = self.actor.humanoid
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = math.max(root.Size.X, root.Size.Z) * 0.5 + 0.5,
			AgentHeight = humanoid.HipHeight + root.Size.Y,
			AgentCanJump = true,
			WaypointSpacing = 5,
		})
		local ok = pcall(function()
			path:ComputeAsync(root.Position, goal)
		end)
		self.computing = false
		self.pathAt = os.clock()
		self.pathGoal = goal
		if ok and path.Status == Enum.PathStatus.Success then
			self.path = path:GetWaypoints()
			self.pathIndex = 2
		else
			self.path = nil
		end
	end)
end

-- Vai até `position`: reto se livre, senão pelos pontos do caminho calculado.
function EnemyBrain:MoveTo(position: Vector3)
	local humanoid = self.actor.humanoid
	local root = self.actor.root
	local now = os.clock()

	-- Emperrado (parede baixa, quina): pula e força caminho calculado por um tempo
	if (root.Position - self.lastPosition).Magnitude < 0.6 and humanoid.WalkSpeed > 1 then
		self.stuckSince = self.stuckSince or now
		if now - self.stuckSince > 0.8 then
			humanoid.Jump = true
			self.stuckSince = nil
			self.forcePathUntil = now + 3
			self.path = nil
		end
	else
		self.stuckSince = nil
	end
	self.lastPosition = root.Position

	if now >= self.forcePathUntil and self:ClearLine(position) then
		self.path = nil
		humanoid:MoveTo(position)
		return
	end
	local goalMoved = self.pathGoal == nil or horizontalDistance(self.pathGoal, position) > 6
	if not self.path or goalMoved or now - self.pathAt > PATH_REFRESH * 3 then
		if now - self.pathAt > PATH_REFRESH then
			self:ComputePath(position)
		end
	end
	local waypoints = self.path
	if waypoints and self.pathIndex <= #waypoints then
		local waypoint = waypoints[self.pathIndex]
		if horizontalDistance(waypoint.Position, root.Position) < 3 then
			self.pathIndex += 1
			waypoint = waypoints[math.min(self.pathIndex, #waypoints)]
		end
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		humanoid:MoveTo(waypoint.Position)
	else
		humanoid:MoveTo(position)
	end
end

-- Ronda o alvo na distância de combate (de lado, alternando o sentido), como um predador.
function EnemyBrain:Circle(target, radius: number)
	local root = self.actor.root
	local now = os.clock()
	if now >= self.strafeSwitch then
		self.strafeSign = -self.strafeSign
		self.strafeSwitch = now + rng:NextNumber(1.2, 2.6)
	end
	local offset = Physics.flat(root.Position - target.root.Position)
	local angle = math.atan2(offset.Z, offset.X) + self.strafeSign * 0.6
	local goal = target.root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
	self:MoveTo(goal)
end

function EnemyBrain:Stop()
	self.actor.humanoid:MoveTo(self.actor.root.Position)
end

-- Reação ao início de um ataque de jogador próximo.
function EnemyBrain:OnThreat(attacker, spec)
	local def = self.def
	local actor = self.actor
	local CombatService = Registry.CombatService
	if def.passive or not CombatService.IsAlive(actor) or CombatService.IsStunned(actor) then
		return
	end
	if horizontalDistance(attacker.root.Position, actor.root.Position) > 14 then
		return
	end
	if not CombatService.CanAct(actor, true) then
		return
	end
	local roll = rng:NextNumber()
	if roll < def.parryChance and not spec.unparryable then
		self:Face(attacker.root.Position)
		if CombatService.SetBlocking(actor, true) then
			self.blockUntil = os.clock() + 0.35
		end
	elseif roll < def.parryChance + def.blockChance then
		self:Face(attacker.root.Position)
		task.delay(math.min(def.reactionTime * 0.4, 0.15), function()
			if CombatService.SetBlocking(actor, true) then
				self.blockUntil = os.clock() + rng:NextNumber(0.5, 0.9)
			end
		end)
	elseif roll < def.parryChance + def.blockChance + def.dodgeChance then
		local away = Physics.flat(actor.root.Position - attacker.root.Position)
		local side = Vector3.new(-away.Z, 0, away.X) * (if rng:NextNumber() < 0.5 then 1 else -1)
		CombatService.TryDash(actor, (side + away * 0.6).Unit)
	end
end

function EnemyBrain:TryAbility(distance: number): boolean
	local now = os.clock()
	if now < self.nextAbility then
		return false
	end
	local candidates, total = {}, 0
	for _, entry in self:Abilities() do
		local def = Abilities[entry.id]
		if def and distance >= (entry.minRange or 0) and distance <= (entry.maxRange or 999) then
			if Registry.CombatService.CooldownReady(self.actor, "Ability:" .. entry.id) then
				table.insert(candidates, entry)
				total += entry.weight or 1
			end
		end
	end
	if #candidates == 0 then
		return false
	end
	local pick = rng:NextNumber() * total
	local chosen = candidates[1]
	for _, entry in candidates do
		pick -= entry.weight or 1
		if pick <= 0 then
			chosen = entry
			break
		end
	end
	local target = self.target
	local direction = Physics.flat(target.root.Position - self.actor.root.Position)
	self:Face(target.root.Position)
	-- Mira com leve previsão de movimento
	local aim = target.root.Position + target.root.AssemblyLinearVelocity * 0.25
	local ok = Registry.AbilityService.Cast(self.actor, chosen.id, direction, aim)
	if ok then
		self.nextAbility = now + rng:NextNumber(2.5, 5) / (self.def.aggression + 0.3)
	end
	return ok
end

function EnemyBrain:Step()
	local CombatService = Registry.CombatService
	local actor = self.actor
	local def = self.def
	if not CombatService.IsAlive(actor) then
		return
	end
	local now = os.clock()

	if actor.blocking and now >= self.blockUntil then
		CombatService.SetBlocking(actor, false)
	end
	if def.passive then
		return
	end
	if CombatService.IsStunned(actor) or actor.channel or now < actor.busyUntil then
		return
	end

	-- Alvo
	if
		not self.target
		or not CombatService.IsAlive(self.target)
		or horizontalDistance(self.target.root.Position, self.spawn) > def.leashRange
	then
		self.target = self:FindTarget()
	end
	local target = self.target
	if not target then
		releaseSlot(self)
		self.engaged = false
		local home = horizontalDistance(actor.root.Position, self.spawn)
		if home > 6 then
			self:MoveTo(self.spawn)
		else
			self:Stop()
			-- Regenera fora de combate
			if actor.humanoid.Health < actor.humanoid.MaxHealth then
				CombatService.Heal(actor, actor.humanoid.MaxHealth * 0.05)
				table.clear(actor.damageBy)
			end
		end
		return
	end

	local distance = horizontalDistance(target.root.Position, actor.root.Position)
	local reach = def.attackRange * (actor.extra.reach or 1)
	if not self.engaged then
		-- Percebeu o alvo: encara e ruge (criaturas) antes de avançar; não ataca durante o rugido
		self.engaged = true
		self:Stop()
		self:Face(target.root.Position)
		local roar = 0
		local set = actor.model:GetAttribute("AnimSet")
		local clip = type(set) == "string" and Clips[set .. "Roar"]
		if clip and (now - self.lastRoar) > 20 then
			self.lastRoar = now
			roar = clip.duration
			CombatService.SetBusy(actor, roar)
			CombatService.Broadcast("Alert", { actor = actor.model }, actor.root.Position)
		end
		self.nextDecision = now + roar + rng:NextNumber(0.15, 0.4)
		return
	end
	if now < self.nextDecision then
		-- Pausa entre combos: ronda na borda do alcance em vez de ficar parado colado
		if distance > reach + 6 then
			self:MoveTo(target.root.Position)
		else
			self:Circle(target, reach + 2)
		end
		return
	end

	-- Habilidades à distância ou de controle
	if self:TryAbility(distance) then
		return
	end

	local mySlot = attackSlot(self, target, now)
	if not mySlot then
		-- Fila: ronda a uma distância maior, sem atacar, até um slot vagar
		self.comboLeft = 0
		self:Circle(target, reach + 5)
		return
	end
	if distance <= reach then
		self:Stop()
		self:Face(target.root.Position)
		if self.comboLeft <= 0 then
			self.comboLeft = math.max(1, def.comboLength - rng:NextInteger(0, 1))
		end
		local direction = Physics.flat(target.root.Position - actor.root.Position)
		local kind = "Light"
		-- Chefes e inimigos agressivos misturam ataques pesados contra quem bloqueia
		if
			target.blocking
			and rng:NextNumber() < 0.5 * def.aggression
			and CombatService.CooldownReady(actor, "Heavy")
		then
			kind = "Heavy"
		elseif
			def.boss
			and self.comboLeft == 1
			and rng:NextNumber() < 0.3
			and CombatService.CooldownReady(actor, "Launcher")
		then
			kind = "Launcher"
		end
		if CombatService.TryAttack(actor, kind, direction) then
			self.comboLeft -= 1
			if self.comboLeft <= 0 then
				-- Pausa após o combo (dá janela de punição ao jogador)
				self.nextDecision = now + rng:NextNumber(0.5, 1.2) / (def.aggression + 0.2)
			end
		end
	else
		self.comboLeft = 0
		-- Fecha distância com dash às vezes
		if distance > 20 and distance < 45 and rng:NextNumber() < 0.08 * def.aggression then
			CombatService.TryDash(actor, Physics.flat(target.root.Position - actor.root.Position))
		end
		self:MoveTo(target.root.Position)
	end
end

-- Troca de fase de chefe (chamado pelo EnemyService ao cruzar limiares de vida).
function EnemyBrain:EnterPhase(index: number)
	local phase = self.def.phases and self.def.phases[index]
	if not phase or index <= self.phase then
		return
	end
	self.phase = index
	self.phaseDef = phase
	local actor = self.actor
	local CombatService = Registry.CombatService
	actor.extra.phase = index
	actor.model:SetAttribute("Phase", index)
	if phase.speedMultiplier then
		actor.baseWalkSpeed = self.def.walkSpeed * phase.speedMultiplier
	end
	if phase.damageMultiplier then
		actor.derived.meleeMultiplier = (self.def.damageMultiplier or 1) * phase.damageMultiplier
		actor.derived.abilityMultiplier = actor.derived.meleeMultiplier
	end
	-- Pose de transição invulnerável
	actor.iframeUntil = CombatService.now() + 1.6
	actor.stunUntil = 0
	CombatService.SetBlocking(actor, false)
	CombatService.SetBusy(actor, 1.5)
	CombatService.Broadcast("BossPhase", {
		actor = actor.model,
		phase = index,
		title = phase.title,
	}, actor.root.Position)
	-- Onda de choque que afasta jogadores próximos
	task.delay(0.6, function()
		for _, target in CombatService.QueryRadius(actor.root.Position, 20, actor) do
			local away = Physics.flat(target.root.Position - actor.root.Position)
			local velocity = away * 70 + Vector3.new(0, 25, 0)
			if target.player then
				CombatService.SendImpulse(target, { kind = "Knockback", velocity = velocity, duration = 0.18 })
			end
		end
	end)
	CombatService.UpdateMovement(actor)
	self.nextAbility = os.clock() + 2
	return phase
end

EnemyBrain.AttackRangeDefault = Combat.Light[1].hitbox.size.Z

return EnemyBrain

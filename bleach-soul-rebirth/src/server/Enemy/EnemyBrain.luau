-- IA de inimigos: máquina de estados leve (8 Hz) que usa as mesmas APIs de combate dos jogadores.
-- Ociosa/Patrulha → Perseguir → Atacar (combo) / Habilidade / Reagir (esquiva, bloqueio, parry) → Recuar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Abilities = require(Shared.Config.Abilities)
local Combat = require(Shared.Config.Combat)
local Physics = require(Shared.Physics)

local Registry = require(script.Parent.Parent.Registry)

local EnemyBrain = {}
EnemyBrain.__index = EnemyBrain

local rng = Random.new()

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

function EnemyBrain:MoveTo(position: Vector3)
	local humanoid = self.actor.humanoid
	humanoid:MoveTo(position)
	-- Pulo simples quando preso em obstáculo
	local now = os.clock()
	local root = self.actor.root
	if (root.Position - self.lastPosition).Magnitude < 0.6 and humanoid.WalkSpeed > 1 then
		self.stuckSince = self.stuckSince or now
		if now - self.stuckSince > 0.8 then
			humanoid.Jump = true
			self.stuckSince = nil
		end
	else
		self.stuckSince = nil
	end
	self.lastPosition = root.Position
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
	if now < self.nextDecision then
		if distance > def.attackRange then
			self:MoveTo(target.root.Position)
		end
		return
	end

	-- Habilidades à distância ou de controle
	if self:TryAbility(distance) then
		return
	end

	if distance <= def.attackRange then
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

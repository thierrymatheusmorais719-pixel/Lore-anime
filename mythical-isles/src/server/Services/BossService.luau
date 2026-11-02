-- Bosses: um por mundo, em arena própria.
-- Estados: Dormant -> Intro -> Fight <-> Transition -> Defeated -> (respawn) Dormant
--   * só jogadores DENTRO da arena podem causar dano e participar
--   * ataques telegrafados com as mesmas formas do teste de acerto
--   * fases por vida, com transição invulnerável e aviso visual
--   * recompensas por participação verificada, uma vez por encontro (encounterId)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Bosses = require(Shared.Config.Bosses)
local Worlds = require(Shared.Config.Worlds)
local BossLogic = require(Shared.Logic.BossLogic)
local AttackShapes = require(Shared.Logic.AttackShapes)
local InventoryLogic = require(Shared.Logic.InventoryLogic)
local BossModels = require(Shared.Builders.BossModels)
local Make = require(Shared.Util.Make)
local Entities = require(script.Parent.Entities)
local Telegraph = require(script.Parent.Telegraph)

local BossService = {}

local S
local Rules = Bosses.Rules
local bosses: { any } = {}
local claimedThisServer: { [string]: { [number]: boolean } } = {}
local rng = Random.new()
local function rand()
	return rng:NextNumber()
end

function BossService.init(registry)
	S = registry
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function setState(b, state: string)
	b.state = state
	b.stateAt = os.clock()
	if b.model then
		b.model:SetAttribute("BossState", state)
	end
end

local function flatDist(a: Vector3, b: Vector3): number
	return ((a - b) * Vector3.new(1, 0, 1)).Magnitude
end

local function inArena(b, pos: Vector3): boolean
	return flatDist(pos, b.arena.center) <= b.arena.radius + 2 and math.abs(pos.Y - b.arena.center.Y) < 40
end

function BossService.participants(b)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local root = S.CombatService.charRoot(p)
		if root and inArena(b, root.Position) then
			table.insert(list, p)
		end
	end
	return list
end

-------------------------------------------------------------------------------
-- Spawn / reset
-------------------------------------------------------------------------------

local function spawnBoss(b)
	local cfg = b.cfg
	local model, centerHeight, radius = BossModels.build(b.id)
	local root = model.PrimaryPart :: BasePart
	root.CanCollide = false
	b.centerHeight = centerHeight
	local home = b.arena.center + Vector3.new(0, centerHeight + 1, 0)
	local facing = (Worlds.Info[b.world].center - b.arena.center) * Vector3.new(1, 0, 1)
	model:PivotTo(CFrame.lookAt(home, home + facing))
	local att = Make("Attachment", { Name = "MoveAtt", Parent = root })
	b.align = Make("AlignPosition", { Mode = Enum.PositionAlignmentMode.OneAttachment, Attachment0 = att, MaxForce = 1e8, Responsiveness = 10,
		MaxVelocity = 14, Position = home, Parent = root })
	b.orient = Make("AlignOrientation", { Mode = Enum.OrientationAlignmentMode.OneAttachment, Attachment0 = att, MaxTorque = 1e8, Responsiveness = 6,
		CFrame = CFrame.lookAt(Vector3.zero, facing.Unit), Parent = root })
	model.Parent = workspace:FindFirstChild("Bosses")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	b.home = home
	b.model = model
	model:SetAttribute("Title", cfg.title)
	model:SetAttribute("ArenaCenter", b.arena.center)
	model:SetAttribute("ArenaRadius", b.arena.radius)
	model:SetAttribute("Phase", 1)
	model:SetAttribute("PhaseLabel", cfg.phases[1].label)
	model:SetAttribute("Rig", "boss")
	b.entity = Entities.register({
		kind = "boss", id = b.id, model = model, root = root, cfg = cfg, maxHp = cfg.hp, def = cfg.def, level = cfg.level,
		world = b.world, radius = radius, name = cfg.name, flying = cfg.flying,
	})
	b.entity.boss = b
	b.entity.arena = b.arena
	b.entity.invulnerable = true
	b.entity.onDeath = function(e, killer)
		BossService.onDefeated(b, killer)
	end
	b.phase = 1
	b.summons = {}
	b.entity.summons = b.summons
	b.lastAttack = nil
	b.busyUntil = 0
	b.airborne = false
	setState(b, "Dormant")
end

local function clearSummons(b)
	for i = #b.summons, 1, -1 do
		S.EnemyService.despawn(b.summons[i])
		b.summons[i] = nil
	end
end

local function reset(b)
	clearSummons(b)
	local e = b.entity
	e.maxHp = b.cfg.hp
	e.hp = e.maxHp
	e.contrib = {}
	e.pets = {}
	e.invulnerable = true
	e.defMods = {}
	e.marks = {}
	b.model:SetAttribute("Health", e.hp)
	b.model:SetAttribute("MaxHealth", e.maxHp)
	b.model:SetAttribute("Phase", 1)
	b.model:SetAttribute("PhaseLabel", b.cfg.phases[1].label)
	b.phase = 1
	b.airborne = false
	b.align.Position = b.home
	setState(b, "Dormant")
end

-------------------------------------------------------------------------------
-- Integração com o combate
-------------------------------------------------------------------------------

-- Só quem está DENTRO da arena e com o boss em combate pode causar dano.
function BossService.canEngage(e, player: Player): boolean
	local b = e.boss
	if not b or b.state ~= "Fight" then
		return false
	end
	local root = S.CombatService.charRoot(player)
	return root ~= nil and inArena(b, root.Position)
end

-- Suporte (cura/escudo/buff) conta como participação nos bosses em que o jogador está lutando.
function BossService.recordSupport(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local root = S.CombatService.charRoot(player)
	if not root then
		return
	end
	for _, b in ipairs(bosses) do
		if b.state == "Fight" or b.state == "Transition" then
			if inArena(b, root.Position) then
				local c = Entities.contribution(b.entity, player)
				c.support += amount
				c.lastAt = os.time()
			end
		end
	end
end

function BossService.activeEntities()
	local list = {}
	for _, b in ipairs(bosses) do
		if b.entity and b.entity.alive then
			table.insert(list, b.entity)
		end
	end
	return list
end

-------------------------------------------------------------------------------
-- Ataques
-------------------------------------------------------------------------------

local function primaryTarget(b, participants)
	local e = b.entity
	if e.tauntPet and os.clock() < (e.tauntUntil or 0) and e.tauntPet.model and e.tauntPet.model.Parent then
		return e.tauntPet.root.Position
	end
	-- jogador com mais contribuição recente (ou aleatório)
	local best, bestV = nil, -1
	for _, p in ipairs(participants) do
		local c = e.contrib[p.UserId]
		local v = (c and c.damage or 0) + rand() * e.maxHp * 0.02
		if v > bestV then
			best, bestV = p, v
		end
	end
	local root = best and S.CombatService.charRoot(best)
	return root and root.Position or b.arena.center
end

local function resolveAttack(b, atk, shapes)
	local e = b.entity
	if not e.alive or b.state == "Defeated" then
		return
	end
	if atk.shape == "summon" then
		local alive = 0
		for _, s in ipairs(b.summons) do
			if s.alive then
				alive += 1
			end
		end
		for _ = 1, math.min(atk.count, (atk.maxAlive or 6) - alive) do
			local a = rand() * math.pi * 2
			local pos = b.arena.center + Vector3.new(math.cos(a), 0, math.sin(a)) * b.arena.radius * 0.55
			local minion = S.EnemyService.spawnSummon(atk.enemy, pos, b.world, e)
			table.insert(b.summons, minion)
		end
		return
	end
	for _, p in ipairs(BossService.participants(b)) do
		local root = S.CombatService.charRoot(p)
		if root and AttackShapes.hitsAny(shapes, root.Position.X, root.Position.Z, 1.5) then
			S.CombatService.hitPlayer(p, atk.pdmg, e)
		end
		for _, st in ipairs(S.PetService.team(p)) do
			if st.model and st.model.Parent and inArena(b, st.root.Position) and AttackShapes.hitsAny(shapes, st.root.Position.X, st.root.Position.Z, 1.5) then
				S.CombatService.hitPet(st, b.cfg.atk, atk.petMult, e)
			end
		end
	end
	S.CombatService.fx("bossImpact", { at = b.arena.center, shapes = shapes, color = b.cfg.color, y = b.arena.center.Y })
end

local function startAttack(b, participants, now: number)
	local phase = b.cfg.phases[b.phase]
	local atkId = BossLogic.pickAttack(phase, b.lastAttack, rand)
	b.lastAttack = atkId
	local atk = b.cfg.attacks[atkId]
	local bpos = b.entity.root.Position
	local tpos = primaryTarget(b, participants)
	local targets = {}
	for _, p in ipairs(participants) do
		local r = S.CombatService.charRoot(p)
		if r then
			table.insert(targets, { x = r.Position.X, z = r.Position.Z })
		end
	end
	local shapes = AttackShapes.build(atk, {
		bx = bpos.X, bz = bpos.Z, tx = tpos.X, tz = tpos.Z, targets = targets,
		ax = b.arena.center.X, az = b.arena.center.Z, ar = b.arena.radius, rng = rand,
	})
	-- vira para o alvo
	local face = (tpos - bpos) * Vector3.new(1, 0, 1)
	if face.Magnitude > 0.5 then
		b.orient.CFrame = CFrame.lookAt(Vector3.zero, face.Unit)
	end
	local tele = nil
	if atk.shape ~= "summon" then
		tele = Telegraph.show(shapes, b.arena.center.Y + 0.9, atk.telegraph, atk.label) -- piso da arena: topo em +1.0
	end
	S.CombatService.setAction(b.model, atk.anim == "slam" and "Slam" or atk.anim == "sweep" and "Sweep" or atk.anim == "roar" and "Roar"
		or atk.anim == "breath" and "Breath" or atk.anim == "dive" and "Dive" or "Cast")
	b.model:SetAttribute("AttackLabel", atk.label)
	b.model:SetAttribute("WindupEnd", serverNow() + atk.telegraph)
	local speed = phase.speedMult or 1
	b.busyUntil = now + atk.telegraph + 0.4
	b.nextAttackAt = now + atk.telegraph + BossLogic.interval(phase, now - b.fightStart, Rules) / speed
	local myPhase = b.phase
	task.delay(atk.telegraph, function()
		Telegraph.clear(tele)
		if b.phase ~= myPhase and atk.shape ~= "summon" then
			return -- ataque cancelado pela transição de fase (o aviso também some)
		end
		if atk.anim == "dive" and atk.shape == "line" then
			-- a serpe mergulha ao longo da linha mostrada
			local s = shapes[1]
			local dest = Vector3.new(s.x + s.dx * s.length * 0.8, b.home.Y, s.z + s.dz * s.length * 0.8)
			local fromCenter = (dest - b.arena.center) * Vector3.new(1, 0, 1)
			if fromCenter.Magnitude > b.arena.radius * 0.7 then
				dest = b.arena.center + fromCenter.Unit * b.arena.radius * 0.7 + Vector3.new(0, b.home.Y - b.arena.center.Y, 0)
			end
			b.align.Position = dest
		end
		resolveAttack(b, atk, shapes)
	end)
end

-------------------------------------------------------------------------------
-- Tick
-------------------------------------------------------------------------------

local function tickBoss(b, now: number)
	if not b.model or not b.entity then
		return
	end
	local e = b.entity
	local participants = BossService.participants(b)

	if b.state == "Dormant" then
		if #participants > 0 then
			b.encounter = (b.encounter or 0) + 1
			b.encounterId = string.format("%s:%s:%d:%d", b.id, game.JobId, b.spawnSerial or 0, b.encounter)
			e.maxHp = BossLogic.scaledHp(b.cfg.hp, #participants, Rules)
			e.hp = e.maxHp
			b.model:SetAttribute("MaxHealth", e.maxHp)
			b.model:SetAttribute("Health", e.hp)
			b.model:SetAttribute("Encounter", b.encounterId)
			S.CombatService.setAction(b.model, "Intro")
			setState(b, "Intro")
			for _, p in ipairs(participants) do
				S.Push:FireClient(p, "BossIntro", { name = b.cfg.name, title = b.cfg.title, color = b.cfg.color, players = #participants })
			end
		end
		return
	end

	if b.state == "Intro" then
		if now - b.stateAt >= Rules.introTime then
			e.invulnerable = false
			b.fightStart = now
			b.nextAttackAt = now + 1.5
			b.emptySince = nil
			setState(b, "Fight")
		end
		return
	end

	if b.state == "Fight" or b.state == "Transition" then
		if #participants == 0 then
			b.emptySince = b.emptySince or now
			if now - b.emptySince >= Rules.resetAfterEmpty then
				reset(b)
			end
			return
		end
		b.emptySince = nil
		-- vida escala se mais jogadores entrarem (nunca diminui durante a luta)
		local wanted = BossLogic.scaledHp(b.cfg.hp, #participants, Rules)
		if wanted > e.maxHp then
			local frac = e.hp / e.maxHp
			e.maxHp = wanted
			e.hp = wanted * frac
			b.model:SetAttribute("MaxHealth", e.maxHp)
			b.model:SetAttribute("Health", math.floor(e.hp))
		end
		if b.state == "Transition" then
			if now - b.stateAt >= Rules.phaseTransitionTime then
				e.invulnerable = false
				b.nextAttackAt = now + 1.0
				setState(b, "Fight")
			end
			return
		end
		-- troca de fase
		local idx = BossLogic.phaseIndex(e.hp / e.maxHp, b.cfg.phases)
		if idx > b.phase then
			b.phase = idx
			local ph = b.cfg.phases[idx]
			e.invulnerable = true
			b.airborne = ph.airborne == true
			b.model:SetAttribute("Phase", idx)
			b.model:SetAttribute("PhaseLabel", ph.label)
			b.model:SetAttribute("Airborne", b.airborne)
			S.CombatService.setAction(b.model, "Roar")
			setState(b, "Transition")
			for _, p in ipairs(participants) do
				S.Push:FireClient(p, "Phase", { boss = b.cfg.name, phase = idx, label = ph.label, color = b.cfg.color })
			end
			return
		end
		-- movimento: aproxima-se do alvo principal sem sair do centro da arena
		local slow = now < e.slowUntil and (1 - e.slowAmount) or 1
		b.align.MaxVelocity = 12 * slow * (b.cfg.phases[b.phase].speedMult or 1)
		if now >= b.busyUntil and os.clock() >= e.stunnedUntil then
			local tpos = primaryTarget(b, participants)
			local toT = (tpos - b.arena.center) * Vector3.new(1, 0, 1)
			local limit = b.arena.radius * 0.45
			local goal = b.arena.center + (toT.Magnitude > limit and toT.Unit * limit or toT * 0.6)
			local y = b.home.Y + (b.airborne and 18 or 0)
			b.align.Position = Vector3.new(goal.X, y, goal.Z)
			local face = (tpos - e.root.Position) * Vector3.new(1, 0, 1)
			if face.Magnitude > 1 then
				b.orient.CFrame = CFrame.lookAt(Vector3.zero, face.Unit)
			end
		end
		if now >= (b.nextAttackAt or 0) and now >= b.busyUntil then
			startAttack(b, participants, now)
		end
	end
end

-------------------------------------------------------------------------------
-- Derrota e recompensas
-------------------------------------------------------------------------------

function BossService.onDefeated(b, killer: Player?)
	if b.state == "Defeated" then
		return
	end
	setState(b, "Defeated")
	clearSummons(b)
	local e = b.entity
	S.CombatService.setAction(b.model, "Dead")
	b.model:SetAttribute("Dead", true)
	local encounterId = b.encounterId or (b.id .. ":" .. tostring(os.clock()))
	claimedThisServer[encounterId] = claimedThisServer[encounterId] or {}
	local now = os.time()
	local w = Worlds.Info[b.world]
	local participantsNow = {}
	for _, p in ipairs(BossService.participants(b)) do
		participantsNow[p] = true
	end
	for userId, c in pairs(e.contrib) do
		local player = c.player
		local data = player and player.Parent and S.DataService.get(player)
		if data then
			local ok, why = BossLogic.eligible(c, e.maxHp, now, participantsNow[player] == true)
			if not ok then
				S.Push:FireClient(player, "Toast", { text = b.cfg.name .. " derrotado — sem recompensa (" .. why .. ")", kind = "error" })
			elseif data.claimedEncounters[encounterId] or claimedThisServer[encounterId][userId] then
				-- proteção contra recompensa duplicada
				warn("[BossService] recompensa duplicada bloqueada", player.Name, encounterId)
			else
				claimedThisServer[encounterId][userId] = true
				data.claimedEncounters[encounterId] = now
				local isNew = InventoryLogic.registerFoe(data, "boss", b.id, now)
				data.stats.bossKills += 1
				S.RewardService.rollDrops(player, b.cfg.loot, b.cfg.name, { worldIndex = w.index })
				S.QuestService.event(player, { type = "defeat_boss", target = b.id })
				if isNew then
					S.QuestService.checkCollection(player)
				end
				local xp = {}
				local byPet = e.pets[userId] or {}
				for _, st in ipairs(S.PetService.team(player)) do
					xp[st.uid] = math.floor(b.cfg.level * 60 * (byPet[st.uid] and 1 or 0.4))
				end
				S.PetService.grantXp(player, xp)
				S.Push:FireClient(player, "BossDefeated", { name = b.cfg.name, firstTime = isNew })
				S.DataService.markDirty(player)
			end
		end
	end
	task.delay(4, function()
		Entities.unregister(e)
		b.model:Destroy()
		b.model = nil
		b.entity = nil
		task.delay(b.cfg.respawn, function()
			b.spawnSerial = (b.spawnSerial or 0) + 1
			spawnBoss(b)
		end)
	end)
end

-- Comando de teste (Studio): leva o boss à próxima fase.
function BossService.debugDamage(worldId: string, frac: number)
	for _, b in ipairs(bosses) do
		if b.world == worldId and b.entity and b.state == "Fight" then
			b.entity.hp = math.max(1, b.entity.hp - b.entity.maxHp * frac)
			b.model:SetAttribute("Health", math.floor(b.entity.hp))
			return true
		end
	end
	return false
end

function BossService.list()
	return bosses
end

function BossService.start()
	for _, worldId in ipairs(Worlds.Order) do
		local w = Worlds.Info[worldId]
		local layout = S.WorldService.Layout[worldId]
		if layout and layout.arena then
			local b = { id = w.bossId, cfg = Bosses.Info[w.bossId], world = worldId, arena = layout.arena, spawnSerial = 1 }
			local ok, err = pcall(spawnBoss, b)
			if ok then
				table.insert(bosses, b)
			else
				warn("[BossService] falha ao criar " .. w.bossId .. ": " .. tostring(err))
			end
		end
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local now = os.clock()
		for _, b in ipairs(bosses) do
			local ok, err = pcall(tickBoss, b, now)
			if not ok then
				warn("[BossService] erro no boss", b.id, err)
			end
		end
	end)
end

return BossService

-- Inimigos comuns: spawn por zona, IA (Logic/EnemyBrain), movimento com PathfindingService
-- (terrestres) ou voo direto com desvio por raycast (voadores), ataques telegrafados,
-- recompensas por participação e respawn.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Enemies = require(Shared.Config.Enemies)
local Worlds = require(Shared.Config.Worlds)
local EnemyBrain = require(Shared.Logic.EnemyBrain)
local BossLogic = require(Shared.Logic.BossLogic)
local AttackShapes = require(Shared.Logic.AttackShapes)
local InventoryLogic = require(Shared.Logic.InventoryLogic)
local EnemyModels = require(Shared.Builders.EnemyModels)
local Make = require(Shared.Util.Make)
local Entities = require(script.Parent.Entities)
local Telegraph = require(script.Parent.Telegraph)

local EnemyService = {}

local S
local AI = Enemies.AI
local active: { any } = {}
local rng = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

function EnemyService.init(registry)
	S = registry
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function refreshFilter()
	local ex = { workspace:FindFirstChild("Pets"), workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Bosses"),
		workspace:FindFirstChild("Telegraphs"), workspace:FindFirstChild("Fx"), workspace:FindFirstChild("Treasures"), workspace:FindFirstChild("Resources") }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ex
end

local function groundAt(pos: Vector3, fallback: number): number
	local hit = workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), rayParams)
	return hit and hit.Position.Y or fallback
end

local function randomPointIn(center: Vector3, radius: number): Vector3
	local a = rng:NextNumber(0, math.pi * 2)
	local d = math.sqrt(rng:NextNumber()) * radius
	return center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
end

-------------------------------------------------------------------------------
-- Spawn
-------------------------------------------------------------------------------

local function setState(e, state: string)
	if e.state ~= state then
		e.state = state
		e.stateAt = os.clock()
		e.model:SetAttribute("State", state)
		if state == "Chase" then
			e.lastEngage = os.clock()
		elseif state == "Idle" then
			e.idleDuration = rng:NextNumber(AI.idleMin, AI.idleMax)
		end
		e.path = nil
	end
end

function EnemyService.spawn(enemyId: string, pos: Vector3, worldId: string, opts)
	opts = opts or {}
	local cfg = Enemies.Info[enemyId]
	local model, centerHeight, radius = EnemyModels.build(enemyId, cfg)
	local root = model.PrimaryPart :: BasePart
	local gy = groundAt(pos, pos.Y)
	local hover = cfg.mover == "hover"
	local y = gy + centerHeight + (hover and (cfg.hoverHeight or 6) or 0)
	model:PivotTo(CFrame.new(Vector3.new(pos.X, y, pos.Z)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	local humanoid = nil
	local align, orient
	if hover then
		local att = Make("Attachment", { Name = "MoveAtt", Parent = root })
		align = Make("AlignPosition", { Mode = Enum.PositionAlignmentMode.OneAttachment, Attachment0 = att, MaxForce = 1e7, Responsiveness = 18,
			MaxVelocity = cfg.speed, Position = root.Position, Parent = root })
		orient = Make("AlignOrientation", { Mode = Enum.OrientationAlignmentMode.OneAttachment, Attachment0 = att, MaxTorque = 1e7, Responsiveness = 14,
			CFrame = root.CFrame.Rotation, Parent = root })
		root.CanCollide = false
	else
		humanoid = Make("Humanoid", {
			-- R15 é necessário para o HipHeight valer em rigs personalizados
			Name = "Humanoid", RigType = Enum.HumanoidRigType.R15, WalkSpeed = cfg.speed, HipHeight = math.max(0.1, centerHeight - root.Size.Y / 2),
			DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None, HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff,
			RequiresNeck = false, BreakJointsOnDeath = false, MaxHealth = 1e9, Health = 1e9, AutoRotate = true,
		})
		humanoid.RigType = Enum.HumanoidRigType.R15
		humanoid.HipHeight = math.max(0.1, centerHeight - root.Size.Y / 2) -- reaplica após o RigType
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid.Parent = model
	end
	model.Parent = workspace:FindFirstChild("Enemies")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local w = Worlds.Info[worldId]
	local maxHp = cfg.hp
	if cfg.hpScaleByWorld and w then
		maxHp = math.floor(cfg.hpScaleByWorld * (w.index ^ 2.4))
	end
	local e = Entities.register({
		kind = "enemy", id = enemyId, model = model, root = root, cfg = cfg, maxHp = maxHp, def = cfg.def, level = cfg.level,
		world = worldId, radius = radius, name = cfg.name, flying = hover, passive = cfg.passive, owner = opts.owner,
	})
	e.humanoid = humanoid
	e.align = align
	e.orient = orient
	e.home = Vector3.new(pos.X, gy, pos.Z)
	e.centerHeight = centerHeight
	e.leashCenter = opts.leashCenter or e.home
	e.leash = opts.leash or cfg.leash
	e.zone = opts.zone
	e.summoner = opts.summoner
	e.attackReadyAt = 0
	e.attackEndAt = 0
	e.lastSeeCheck = 0
	e.canSee = false
	e.lastProgress = { pos = root.Position, t = os.clock() }
	e.stuck = 0
	e.state = nil
	setState(e, "Idle")
	e.onDamaged = EnemyService.onDamaged
	e.onDeath = EnemyService.onDeath
	model:SetAttribute("Rig", cfg.mover == "hover" and "floater" or "enemy")
	table.insert(active, e)
	return e
end

-------------------------------------------------------------------------------
-- Alvos
-------------------------------------------------------------------------------

local function collectTargets(e)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local root = S.CombatService.charRoot(p)
		if root and S.WorldService.worldAt(root.Position) == e.world and not S.WorldService.inSafeZone(root.Position) then
			table.insert(list, { kind = "player", player = p, part = root, threat = 1, radius = 1.5 })
			for _, st in ipairs(S.PetService.team(p)) do
				if st.model and st.model.Parent and os.clock() >= st.knockedUntil and st.hp > 0 then
					table.insert(list, { kind = "pet", player = p, pet = st, part = st.root, threat = st.stats.threat, radius = 1.5 })
				end
			end
		end
	end
	return list
end

local function pickTarget(e, now: number)
	if e.passive then
		return nil
	end
	if e.tauntPet and now < (e.tauntUntil or 0) and e.tauntPet.model and e.tauntPet.model.Parent and now >= e.tauntPet.knockedUntil then
		return { kind = "pet", player = e.tauntPet.player, pet = e.tauntPet, part = e.tauntPet.root, threat = 9, radius = 1.5 }
	end
	local best, bestScore = nil, 0
	local pos = e.root.Position
	for _, t in ipairs(collectTargets(e)) do
		local d = (t.part.Position - pos).Magnitude
		local limit = e.cfg.detect * 1.25
		-- mantém o alvo atual com histerese (evita trocar a cada tick)
		local keep = e.targetRef and e.targetRef.part == t.part
		if d <= limit or (keep and d <= limit * 1.3) then
			local score = t.threat / math.max(d, 1) * (keep and 1.35 or 1)
			if score > bestScore then
				best, bestScore = t, score
			end
		end
	end
	return best
end

-------------------------------------------------------------------------------
-- Movimento
-------------------------------------------------------------------------------

local function stopMoving(e)
	if e.humanoid then
		e.humanoid:MoveTo(e.root.Position)
	elseif e.align then
		e.align.Position = e.root.Position
	end
end

local function directClear(e, goal: Vector3): boolean
	local from = e.root.Position
	local to = Vector3.new(goal.X, from.Y, goal.Z)
	local dir = to - from
	if dir.Magnitude < 1 then
		return true
	end
	local hit = workspace:Raycast(from, dir, rayParams)
	return hit == nil
end

local function computePath(e, goal: Vector3)
	if e.computing then
		return
	end
	e.computing = true
	e.pathAt = os.clock()
	task.spawn(function()
		local size = e.model:GetExtentsSize()
		local path = PathfindingService:CreatePath({
			AgentRadius = math.clamp(e.radius * 0.6, 1.5, 6), AgentHeight = math.clamp(size.Y, 3, 20), AgentCanJump = true, WaypointSpacing = 6,
		})
		local ok = pcall(function()
			path:ComputeAsync(e.root.Position, goal)
		end)
		e.computing = false
		if not e.alive then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			e.path = path:GetWaypoints()
			e.pathIndex = 2
			e.pathGoal = goal
		else
			e.path = nil
			e.pathFailed = os.clock()
		end
	end)
end

-- Move para `goal` com pathfinding quando o caminho direto está bloqueado.
local function moveTo(e, goal: Vector3, dt: number)
	if os.clock() < e.stunnedUntil then
		stopMoving(e)
		return
	end
	-- lentidão (Assinaturas: esporos, seiva, tremor): reduz a velocidade enquanto durar
	local speed = e.cfg.speed * (os.clock() < (e.slowUntil or 0) and (1 - (e.slowAmount or 0)) or 1)
	if e.humanoid and e.humanoid.WalkSpeed ~= speed then
		e.humanoid.WalkSpeed = speed
	end
	if e.align then
		-- voadores: linha reta; sobe se houver obstáculo à frente (alternativa ao pathfinding)
		local from = e.root.Position
		local flatGoal = Vector3.new(goal.X, from.Y, goal.Z)
		local dir = flatGoal - from
		local gy = groundAt(goal, e.home.Y)
		local y = gy + e.centerHeight + (e.cfg.hoverHeight or 6)
		if dir.Magnitude > 1 then
			local probe = workspace:Raycast(from, dir.Unit * math.min(dir.Magnitude, 10), rayParams)
			if probe then
				y = math.max(y, probe.Position.Y + 10)
			end
		end
		e.align.Position = Vector3.new(goal.X, y, goal.Z)
		e.align.MaxVelocity = speed
		if dir.Magnitude > 0.5 then
			e.orient.CFrame = CFrame.lookAt(Vector3.zero, dir.Unit)
		end
		return
	end
	local hum = e.humanoid
	if directClear(e, goal) then
		e.path = nil
		hum:MoveTo(goal)
	else
		local needNew = not e.path or (e.pathGoal and (e.pathGoal - goal).Magnitude > 8)
		if needNew and os.clock() - (e.pathAt or 0) > AI.pathRecompute then
			computePath(e, goal)
		end
		if e.path and e.path[e.pathIndex] then
			local wp = e.path[e.pathIndex]
			if wp.Action == Enum.PathWaypointAction.Jump then
				hum.Jump = true
			end
			hum:MoveTo(wp.Position)
			if (e.root.Position - wp.Position) * Vector3.new(1, 0, 1) == Vector3.zero or ((e.root.Position - wp.Position) * Vector3.new(1, 0, 1)).Magnitude < 3 then
				e.pathIndex += 1
			end
		else
			hum:MoveTo(goal) -- alternativa: direto (com detecção de travamento abaixo)
		end
	end
	-- detecção de travamento
	local now = os.clock()
	if (e.root.Position - e.lastProgress.pos).Magnitude > 1.5 then
		e.lastProgress = { pos = e.root.Position, t = now }
		e.stuck = 0
	elseif now - e.lastProgress.t > AI.stuckTime then
		e.stuck += 1
		e.lastProgress = { pos = e.root.Position, t = now }
		hum.Jump = true
		e.path = nil
		e.pathAt = 0
	end
end

-------------------------------------------------------------------------------
-- Ataques
-------------------------------------------------------------------------------

-- Aplica dano a todos os alvos (jogadores e pets) atingidos pelas formas.
local function resolveShapes(e, shapes, mult: number, pdmg: number)
	for _, t in ipairs(collectTargets(e)) do
		local p = t.part.Position
		if math.abs(p.Y - (e.home.Y + 3)) < 25 and AttackShapes.hitsAny(shapes, p.X, p.Z, t.radius) then
			if t.kind == "player" then
				S.CombatService.hitPlayer(t.player, pdmg, e)
				e.aggroPlayer = t.player
			else
				S.CombatService.hitPet(t.pet, e.cfg.atk, mult, e)
			end
			e.lastEngage = os.clock()
		end
	end
end

local function startAttack(e, now: number)
	local atk = e.cfg.attack
	local t = e.targetRef
	if not t then
		return
	end
	local tp = t.part.Position
	local pos = e.root.Position
	e.attackEndAt = now + atk.windup + 0.4
	e.attackReadyAt = now + atk.cooldown
	stopMoving(e)
	local look = (tp - pos) * Vector3.new(1, 0, 1)
	if look.Magnitude > 0.1 and e.humanoid then
		e.model:PivotTo(CFrame.lookAt(pos, pos + look))
	elseif look.Magnitude > 0.1 and e.orient then
		e.orient.CFrame = CFrame.lookAt(Vector3.zero, look.Unit)
	end
	local kind = atk.kind
	S.CombatService.setAction(e.model, kind == "slam" and "Slam" or kind == "lunge" and "Lunge" or kind == "projectile" and "Cast" or "Attack")
	e.model:SetAttribute("WindupEnd", serverNow() + atk.windup)
	local groundY = e.home.Y
	if kind == "melee" then
		task.delay(atk.windup, function()
			if not e.alive or os.clock() < e.stunnedUntil then
				return
			end
			local target = e.targetRef
			if target and (target.part.Position - e.root.Position).Magnitude <= atk.range + e.radius + target.radius + AI.maxAttackRangeSlack then
				if target.kind == "player" then
					S.CombatService.hitPlayer(target.player, e.cfg.pdmg, e)
				else
					S.CombatService.hitPet(target.pet, e.cfg.atk, atk.mult, e)
				end
				e.lastEngage = os.clock()
			end
		end)
	elseif kind == "slam" then
		local shapes = { { type = "circle", x = pos.X, z = pos.Z, r = atk.radius } }
		local tele = Telegraph.simple(shapes, groundY, atk.windup)
		task.delay(atk.windup, function()
			Telegraph.clear(tele)
			if e.alive and os.clock() >= e.stunnedUntil then
				resolveShapes(e, shapes, atk.mult, e.cfg.pdmg)
				S.CombatService.fx("slam", { at = Vector3.new(pos.X, groundY, pos.Z), radius = atk.radius, color = Color3.fromRGB(255, 170, 90) })
			end
		end)
	elseif kind == "lunge" then
		local dx, dz = AttackShapes.unit(tp.X - pos.X, tp.Z - pos.Z)
		local shapes = { { type = "rect", x = pos.X, z = pos.Z, dx = dx, dz = dz, length = atk.range, width = math.max(5, e.radius * 1.6) } }
		local tele = Telegraph.simple(shapes, groundY, atk.windup)
		task.delay(atk.windup, function()
			Telegraph.clear(tele)
			if e.alive and os.clock() >= e.stunnedUntil then
				-- avança ao longo da linha (verifica obstáculo para não atravessar paredes)
				local dir = Vector3.new(dx, 0, dz)
				local hit = workspace:Raycast(e.root.Position, dir * atk.range, rayParams)
				local dist = hit and math.max(0, (hit.Position - e.root.Position).Magnitude - e.radius) or atk.range * 0.8
				local dest = e.root.Position + dir * dist
				e.model:PivotTo(CFrame.lookAt(dest, dest + dir))
				resolveShapes(e, shapes, atk.mult, e.cfg.pdmg)
			end
		end)
	elseif kind == "projectile" then
		local target = Vector3.new(tp.X, tp.Y, tp.Z)
		local travel = math.clamp((target - pos).Magnitude / 45, 0.2, 1.2)
		local shapes = { { type = "circle", x = target.X, z = target.Z, r = 4.5 } }
		local tele = Telegraph.simple(shapes, groundAt(target, groundY), atk.windup + travel)
		task.delay(atk.windup, function()
			if not e.alive or os.clock() < e.stunnedUntil then
				Telegraph.clear(tele)
				return
			end
			S.CombatService.fx("orb", { from = e.root.Position, to = target, travel = travel, color = Color3.fromRGB(255, 120, 200) })
			task.delay(travel, function()
				Telegraph.clear(tele)
				if e.alive then
					resolveShapes(e, shapes, atk.mult, e.cfg.pdmg)
				end
			end)
		end)
	end
end

-------------------------------------------------------------------------------
-- Tick de IA
-------------------------------------------------------------------------------

local function tickEnemy(e, now: number, dt: number)
	if not e.alive then
		return
	end
	local pos = e.root.Position
	local homeDist = ((pos - e.leashCenter) * Vector3.new(1, 0, 1)).Magnitude
	local t = (e.state ~= "Return") and pickTarget(e, now) or nil
	e.targetRef = t
	if t then
		e.aggroPlayer = t.player
	elseif e.state == "Return" then
		e.aggroPlayer = nil
	end
	local targetDist = t and (t.part.Position - pos).Magnitude or math.huge
	if t and now - e.lastSeeCheck > 0.3 then
		e.lastSeeCheck = now
		local head = pos + Vector3.new(0, e.centerHeight * 0.5, 0)
		e.canSee = S.CombatService.lineOfSight(head, t.part.Position)
	end
	local cfg = e.cfg
	local goalReached = e.goal and ((pos - e.goal) * Vector3.new(1, 0, 1)).Magnitude < 4 or false
	local ctx = {
		hp = e.hp, hasTarget = t ~= nil, targetDist = targetDist, canSee = t ~= nil and e.canSee,
		homeDist = homeDist, timeInState = now - e.stateAt, chaseTime = now - (e.lastEngage or now),
		attackReady = now >= e.attackReadyAt, inAttackRange = t ~= nil and targetDist <= cfg.attack.range + e.radius + t.radius,
		heard = e.heard == true, reachedGoal = goalReached, idleDuration = e.idleDuration or 3, attackDone = now >= e.attackEndAt,
		passive = cfg.passive,
	}
	if e.stuck >= 3 and e.state ~= "Return" then
		ctx.homeDist = math.huge -- travado repetidamente: força o retorno
	end
	local brainCfg = { detect = cfg.detect, senseRadius = cfg.senseRadius, leash = e.leash, maxChase = cfg.maxChase, investigateTime = AI.investigateTime, recoverTime = AI.recoverTime }
	local nextState = EnemyBrain.decide(e.state, ctx, brainCfg)
	if nextState ~= e.state then
		if nextState == "Patrol" then
			e.goal = randomPointIn(e.leashCenter, AI.patrolRadius)
		elseif nextState == "Investigate" then
			e.goal = e.heardPos or (t and t.part.Position) or e.goal or pos
		elseif nextState == "Return" then
			e.goal = e.leashCenter
			e.invulnerable = true
			e.model:SetAttribute("Evading", true)
			e.stuck = 0
		end
		if e.state == "Return" then
			e.invulnerable = false
			e.model:SetAttribute("Evading", false)
			-- voltou para casa: zera contribuições (ninguém ganha por um combate abandonado)
			e.contrib = {}
			e.pets = {}
		end
		setState(e, nextState)
		if nextState == "Attack" then
			startAttack(e, now)
		end
		e.heard = false
	end

	local st = e.state
	if st == "Idle" or st == "Recover" or st == "Attack" then
		if st ~= "Attack" then
			stopMoving(e)
		end
	elseif st == "Patrol" or st == "Investigate" then
		moveTo(e, e.goal or e.home, dt)
	elseif st == "Chase" and t then
		moveTo(e, t.part.Position, dt)
	elseif st == "Return" then
		moveTo(e, e.leashCenter, dt)
		e.hp = math.min(e.maxHp, e.hp + e.maxHp * AI.returnHealRate * dt)
		e.model:SetAttribute("Health", math.floor(e.hp))
		if e.stuck >= 3 then
			-- preso no retorno: reposiciona na origem
			e.model:PivotTo(CFrame.new(e.leashCenter + Vector3.new(0, e.centerHeight, 0)))
			e.stuck = 0
		end
	end
end

-------------------------------------------------------------------------------
-- Eventos de combate
-------------------------------------------------------------------------------

function EnemyService.onDamaged(e, src, _dealt)
	if not src or not src.player then
		return
	end
	e.lastEngage = os.clock()
	e.aggroPlayer = src.player
	if e.passive then
		-- Estrela Errante foge
		local root = S.CombatService.charRoot(src.player)
		if root then
			local away = (e.root.Position - root.Position) * Vector3.new(1, 0, 1)
			e.goal = e.leashCenter + (away.Magnitude > 0 and away.Unit or Vector3.new(1, 0, 0)) * 25
			setState(e, "Patrol")
		end
		return
	end
	if e.state == "Idle" or e.state == "Patrol" or e.state == "Investigate" then
		local root = S.CombatService.charRoot(src.player)
		if root then
			e.heard = true
			e.heardPos = root.Position
		end
	end
end

function EnemyService.taunt(petState, pos: Vector3, radius: number, duration: number)
	local now = os.clock()
	for _, e in ipairs(active) do
		if e.alive and not e.passive and (e.root.Position - pos).Magnitude <= radius + e.radius then
			e.tauntPet = petState
			e.tauntUntil = now + duration
			e.lastEngage = now
			if e.state == "Idle" or e.state == "Patrol" or e.state == "Investigate" then
				setState(e, "Chase")
			end
		end
	end
	for _, b in ipairs(S.BossService.activeEntities()) do
		if b.alive and (b.root.Position - pos).Magnitude <= radius + b.radius + 10 then
			b.tauntPet = petState
			b.tauntUntil = now + duration * 0.5 -- bosses resistem a provocação
		end
	end
end

function EnemyService.onDeath(e, killer: Player?)
	setState(e, "Dead")
	e.model:SetAttribute("Dead", true)
	S.CombatService.setAction(e.model, "Dead")
	stopMoving(e)
	local now = os.time()
	local w = Worlds.Info[e.world]
	for userId, c in pairs(e.contrib) do
		local player = c.player
		if player and player.Parent then
			local eligible = BossLogic.enemyEligible(c.damage, e.maxHp, killer == player)
			if e.passive and e.owner and e.owner ~= player then
				eligible = false
			end
			local data = S.DataService.get(player)
			if eligible and data then
				local isNew = InventoryLogic.registerFoe(data, "enemy", e.id, now)
				if isNew then
					S.Push:FireClient(player, "Toast", { text = "Novo no bestiário: " .. e.name, kind = "bestiary" })
					S.QuestService.checkCollection(player)
				end
				data.stats.kills += 1
				S.RewardService.rollDrops(player, e.id, e.name, { worldIndex = w and w.index or 1 })
				S.QuestService.event(player, { type = "defeat_enemy", target = e.id, world = e.world })
				local xp = {}
				local byPet = e.pets[userId] or {}
				for _, st in ipairs(S.PetService.team(player)) do
					xp[st.uid] = byPet[st.uid] and e.cfg.xp or math.floor(e.cfg.xp * 0.3)
				end
				S.PetService.grantXp(player, xp)
			end
		end
	end
	task.delay(2.2, function()
		Entities.unregister(e)
		local i = table.find(active, e)
		if i then
			table.remove(active, i)
		end
		e.model:Destroy()
		if e.zone and e.cfg.respawn > 0 then
			task.delay(e.cfg.respawn, function()
				EnemyService.spawn(e.id, randomPointIn(e.zone.center, e.zone.radius), e.world, { zone = e.zone })
			end)
		end
		if e.summoner and e.summoner.summons then
			local j = table.find(e.summoner.summons, e)
			if j then
				table.remove(e.summoner.summons, j)
			end
		end
	end)
end

-- Invocações de bosses: presas à arena e removidas quando o boss reseta/morre.
function EnemyService.spawnSummon(enemyId: string, pos: Vector3, worldId: string, boss)
	local e = EnemyService.spawn(enemyId, pos, worldId, { leashCenter = boss.arena.center, leash = boss.arena.radius + 8, summoner = boss })
	setState(e, "Chase")
	return e
end

function EnemyService.despawn(e)
	if not e.alive then
		return
	end
	e.alive = false
	Entities.unregister(e)
	local i = table.find(active, e)
	if i then
		table.remove(active, i)
	end
	e.model:Destroy()
end

-- Evento secreto: Estrela Errante (só o dono pode derrotar).
function EnemyService.spawnWanderingStar(player: Player, pos: Vector3, worldId: string)
	local e = EnemyService.spawn("wandering_star", pos, worldId, { owner = player, leashCenter = pos, leash = 40 })
	e.model:SetAttribute("OwnerId", player.UserId)
	task.delay(60, function()
		if e.alive then
			EnemyService.despawn(e)
		end
	end)
	return e
end

function EnemyService.activeList()
	return active
end

function EnemyService.start()
	for _, worldId in ipairs(Worlds.Order) do
		local layout = S.WorldService.Layout[worldId]
		for enemyId, zone in pairs(layout and layout.enemyZones or {}) do
			local cfg = Enemies.Info[enemyId]
			for _ = 1, cfg.count do
				local ok, err = pcall(EnemyService.spawn, enemyId, randomPointIn(zone.center, zone.radius), worldId, { zone = zone })
				if not ok then
					warn("[EnemyService] falha ao criar " .. enemyId .. ": " .. tostring(err))
					break
				end
			end
		end
	end
	local acc, filterAcc = 0, 1
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		filterAcc += dt
		if filterAcc >= 1 then
			filterAcc = 0
			refreshFilter()
		end
		if acc < AI.tickRate then
			return
		end
		local step = acc
		acc = 0
		local now = os.clock()
		-- inimigos sem jogadores no mundo "dormem" (economiza servidor)
		local occupied = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local w = p:GetAttribute("World")
			if w then
				occupied[w] = true
			end
		end
		for i = #active, 1, -1 do
			local e = active[i]
			if e and (occupied[e.world] or e.state ~= "Idle") then
				local ok, err = pcall(tickEnemy, e, now, step)
				if not ok then
					warn("[EnemyService] erro na IA de", e.id, err)
				end
			end
		end
	end)
end

return EnemyService

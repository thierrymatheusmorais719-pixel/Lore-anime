-- Combate (autoridade total no servidor):
--   * alvo, ataque básico e habilidades pedidos pelo cliente são VALIDADOS aqui
--     (alcance pelas posições do servidor, recarga, energia, linha de visão, mundo, arena)
--   * IA de combate dos pets (escolha de alvo, ataque por velocidade, energia, nocaute)
--   * aplicação de dano/cura/escudo, contribuições para recompensas e números de dano

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Abilities = require(Shared.Config.Abilities)
local Pets = require(Shared.Config.Pets)
local CombatRules = require(Shared.Logic.CombatRules)
local PetStats = require(Shared.Logic.PetStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Net = require(Shared.Net)
local Entities = require(script.Parent.Entities)

local CombatService = {}

local S
local Push
local rng = Random.new()
local function rand()
	return rng:NextNumber()
end

local focus: { [Player]: any } = {} -- alvo escolhido pelo jogador (entidade)
local lastPlayerAttack: { [Player]: number } = {}
local abilityLimiter = RateLimiter.new(6, 2, Abilities.GlobalMinInterval)
local attackLimiter = RateLimiter.new(8, 2, 0.2)
local targetLimiter = RateLimiter.new(10, 2, 0.05)
local damageQueue = {}

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.IgnoreWater = true

function CombatService.init(registry)
	S = registry
	Push = Net.get("Push")
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function charRoot(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end
CombatService.charRoot = charRoot

local function refreshLosFilter()
	local ex = { workspace:FindFirstChild("Pets"), workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Bosses"),
		workspace:FindFirstChild("Telegraphs"), workspace:FindFirstChild("Fx"), workspace:FindFirstChild("Treasures"), workspace:FindFirstChild("Resources") }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	losParams.FilterDescendantsInstances = ex
end

-- Linha de visão entre dois pontos ignorando criaturas (só o cenário bloqueia).
function CombatService.lineOfSight(a: Vector3, b: Vector3): boolean
	local dir = b - a
	if dir.Magnitude < 1 then
		return true
	end
	local hit = workspace:Raycast(a, dir, losParams)
	return hit == nil or (hit.Position - b).Magnitude < 3
end

local function distanceTo(e, pos: Vector3): number
	local tp = e.root.Position
	if e.flying then
		-- alvos voadores: alcance medido no plano (com tolerância vertical)
		local flat = CombatRules.flatDistance(pos.X, pos.Z, tp.X, tp.Z)
		return math.max(flat, math.abs(pos.Y - tp.Y) - 30)
	end
	return (tp - pos).Magnitude
end
CombatService.distanceTo = distanceTo

-- O jogador pode atacar esta entidade agora? (mundo, arena de boss, invulnerabilidade)
local function canEngage(player: Player, e, fromPos: Vector3): (boolean, string?)
	if not e or not e.alive then
		return false, "alvo inválido"
	end
	if e.invulnerable then
		return false, "invulnerável"
	end
	local world = S.WorldService.worldAt(fromPos)
	if e.world ~= "any" and world ~= e.world then
		return false, "outro mundo"
	end
	if e.kind == "boss" and not S.BossService.canEngage(e, player) then
		return false, "fora da arena"
	end
	if e.passive and e.owner and e.owner ~= player then
		return false, "evento de outro jogador"
	end
	return true, nil
end
CombatService.canEngage = canEngage

-------------------------------------------------------------------------------
-- Números de dano (lote a cada 0,1s, apenas para jogadores próximos)
-------------------------------------------------------------------------------

local function queueNumber(pos: Vector3, amount: number, kind: string, crit: boolean?)
	table.insert(damageQueue, { p = pos, a = math.floor(amount), k = kind, c = crit or nil })
end
CombatService.queueNumber = queueNumber

local function flushNumbers()
	if #damageQueue == 0 then
		return
	end
	local q = damageQueue
	damageQueue = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local mine = {}
			for _, ev in ipairs(q) do
				if (ev.p - (root :: BasePart).Position).Magnitude < 160 then
					table.insert(mine, ev)
					if #mine >= 40 then
						break
					end
				end
			end
			if #mine > 0 then
				Push:FireClient(p, "Damage", mine)
			end
		end
	end
end

function CombatService.fx(kind: string, payload)
	payload.kind = kind
	local origin = payload.from or payload.at
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and origin and ((root :: BasePart).Position - origin).Magnitude < 220 then
			Push:FireClient(p, "AbilityFx", payload)
		end
	end
end

local function setAction(model: Model?, action: string)
	if model then
		model:SetAttribute("Action", action)
		model:SetAttribute("ActionAt", serverNow())
	end
end
CombatService.setAction = setAction

-------------------------------------------------------------------------------
-- Dano em entidades
-------------------------------------------------------------------------------

-- src = { player, pet? (estado do pet), kind = "pet"|"player"|"ability" }
function CombatService.damageEntity(e, amount: number, src, crit: boolean?)
	if not e.alive or e.invulnerable or amount <= 0 then
		return 0
	end
	-- poder de defesa do boss (ex.: Casca Ancestral): corta parte do dano por alguns segundos
	if e.guardUntil and os.clock() < e.guardUntil then
		amount *= 1 - (e.guardAmount or 0)
	end
	local dealt = math.min(e.hp, amount)
	e.hp -= dealt
	local now = os.clock()
	if src and src.player then
		local c = Entities.contribution(e, src.player)
		c.damage += dealt
		c.lastAt = os.time()
		if src.pet then
			local byPet = e.pets[src.player.UserId] or {}
			byPet[src.pet.uid] = (byPet[src.pet.uid] or 0) + dealt
			e.pets[src.player.UserId] = byPet
			src.pet.lastCombatAt = now
		end
	end
	e.model:SetAttribute("Health", math.max(0, math.floor(e.hp)))
	e.model:SetAttribute("HitAt", serverNow())
	queueNumber(e.root.Position + Vector3.new(0, (e.radius or 2) + 2, 0), dealt, crit and "crit" or "hit", crit)
	if e.onDamaged then
		e.onDamaged(e, src, dealt)
	end
	-- poder de contra-ataque do boss (Espelho Prismático reflete parte do dano; Carga Estática dá choque fixo)
	if e.thornsUntil and now < e.thornsUntil and src and src.pet and src.pet.model and dealt > 0 then
		local pet = src.pet
		local raw = e.thornsFrac and dealt * e.thornsFrac or (e.thornsAtk or 0)
		if raw > 0 and now >= (pet.thornsHitAt or 0) then
			pet.thornsHitAt = now + 0.35 -- no máximo ~3 choques por segundo em cada pet
			CombatService.hitPet(pet, raw, e.thornsMult or 1, e)
			CombatService.fx("chain", { from = e.root.Position + Vector3.new(0, (e.radius or 2), 0), to = pet.root.Position, color = e.thornsColor or Color3.fromRGB(150, 220, 255) })
		end
	end
	if e.hp <= 0 and e.alive then
		e.alive = false
		e.killer = src and src.player
		if e.onDeath then
			task.spawn(e.onDeath, e, src and src.player)
		end
	end
	return dealt
end

local function petDamage(st, e, mult: number, critBonus: number?)
	local now = os.clock()
	local bonus = 1 + Entities.markBonus(e, now)
	local _, _, sets = S.PetService.synergy(st.player)
	if sets[e.world] then
		bonus *= 1 + Combat.WorldSet.damage
	end
	-- força extra de um Assinatura de equipe (Uivo da Matilha, Chuva de Frutinhas...)
	if st.sigAtkUntil and now < st.sigAtkUntil then
		bonus *= 1 + (st.sigAtkBonus or 0)
	end
	return CombatRules.damage(st.stats.atk, mult, e.def, rand, { crit = st.stats.crit + (critBonus or 0), defReduction = Entities.defReduction(e, now), bonus = bonus })
end
CombatService.petDamage = petDamage

-- Velocidade do jogador: modificadores que se combinam sem se atropelar (corrida das habilidades e
-- lentidão/raízes dos bosses). WalkSpeed = base × (1 − lentidão) + corrida; ao acabar, volta à base.
local walkMods: { [Player]: { hum: Humanoid, base: number, haste: number, hasteUntil: number, slow: number, slowUntil: number } } = {}

local function applyWalk(player: Player)
	local m = walkMods[player]
	if not m then
		return
	end
	local hum = m.hum
	if not hum.Parent then
		walkMods[player] = nil
		return
	end
	local now = os.clock()
	local haste = now < m.hasteUntil and m.haste or 0
	local slow = now < m.slowUntil and m.slow or 0
	hum.WalkSpeed = math.max(0, m.base * (1 - slow) + (slow >= 1 and 0 or haste))
	if haste == 0 and slow == 0 then
		walkMods[player] = nil
	end
end

local function walkMod(player: Player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local m = walkMods[player]
	if m and m.hum ~= hum then
		m = nil -- personagem novo (renasceu): começa da velocidade dele
	end
	if not m then
		m = { hum = hum, base = hum.WalkSpeed, haste = 0, hasteUntil = 0, slow = 0, slowUntil = 0 }
		walkMods[player] = m
	end
	return m
end

-- Corrida mais rápida do dono por `duration` s (Vento Veloz e Assinaturas de vento). Não acumula.
function CombatService.boostWalk(player: Player, amount: number, duration: number)
	local m = walkMod(player)
	if not m or os.clock() < m.hasteUntil then
		return
	end
	m.haste, m.hasteUntil = amount, os.clock() + duration
	applyWalk(player)
	task.delay(duration + 0.02, applyWalk, player)
end

-- Lentidão do jogador (amount 0..1; 1 = preso no lugar) por `duration` s. Fica a mais forte/mais longa.
function CombatService.slowPlayer(player: Player, amount: number, duration: number)
	local m = walkMod(player)
	if not m then
		return
	end
	local now = os.clock()
	m.slow = math.max(now < m.slowUntil and m.slow or 0, math.clamp(amount, 0, 1))
	m.slowUntil = math.max(m.slowUntil, now + duration)
	applyWalk(player)
	task.delay(duration + 0.02, applyWalk, player)
end
CombatService._walkMods = walkMods -- (testes)

-------------------------------------------------------------------------------
-- Dano em pets e jogadores (vindo de inimigos/bosses)
-------------------------------------------------------------------------------

function CombatService.hitPet(st, rawAtk: number, mult: number, attacker)
	local now = os.clock()
	if now < st.knockedUntil or not st.model or not st.model.Parent then
		return 0
	end
	local dmg = CombatRules.damage(rawAtk, mult, st.stats.def, rand, {})
	if now < st.shieldUntil and st.shield > 0 then
		local rest, shield = CombatRules.absorb(dmg, st.shield)
		st.shield = shield
		dmg = rest
	end
	st.hp -= dmg
	st.lastCombatAt = now
	if attacker and attacker.kind == "boss" then
		local c = Entities.contribution(attacker, st.player)
		c.tanked += dmg
		c.lastAt = os.time()
	end
	queueNumber(st.root.Position + Vector3.new(0, 3, 0), dmg, "pet")
	st.model:SetAttribute("HitAt", serverNow())
	if st.hp <= 0 then
		st.hp = 0
		st.knockedUntil = now + Combat.KnockoutTime
		st.target = nil
		Push:FireClient(st.player, "Toast", { text = Pets.Species[st.species].name .. " foi nocauteado!", kind = "error" })
	end
	S.PetService.syncAttributes(st)
	return dmg
end

function CombatService.hitPlayer(player: Player, amount: number, attacker)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return 0
	end
	if S.WorldService.inSafeZone((char :: Model):GetPivot().Position) then
		return 0
	end
	local scaled = math.floor(amount * (0.9 + rand() * 0.2))
	hum:TakeDamage(scaled)
	queueNumber((char :: Model):GetPivot().Position + Vector3.new(0, 3, 0), scaled, "player")
	return scaled
end

function CombatService.refreshPlayerHealth(player: Player)
	local data = S.DataService.get(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not data or not hum then
		return
	end
	local n = 0
	for _ in pairs(data.worlds) do
		n += 1
	end
	local maxHp = Combat.Player.baseHealth + Combat.Player.healthPerWorld * (n - 1)
	local frac = hum.Health / math.max(1, hum.MaxHealth)
	hum.MaxHealth = maxHp
	hum.Health = math.max(1, maxHp * frac)
end

-------------------------------------------------------------------------------
-- Pedidos do cliente
-------------------------------------------------------------------------------

function CombatService.setFocus(player: Player, model: Instance?)
	if not targetLimiter:allow(player) then
		return
	end
	if model == nil then
		focus[player] = nil
		player:SetAttribute("Target", 0)
		return
	end
	if typeof(model) ~= "Instance" then
		return
	end
	local e = Entities.fromInstance(model)
	local root = charRoot(player)
	if not e or not root then
		return
	end
	if distanceTo(e, root.Position) > 140 then
		return
	end
	local ok = canEngage(player, e, root.Position)
	if not ok and not (e.kind == "boss") then
		return
	end
	focus[player] = e
	player:SetAttribute("Target", e.eid)
	S.ExplorationService.clearSelection(player)
end

function CombatService.focusOf(player: Player)
	local e = focus[player]
	if e and not e.alive then
		focus[player] = nil
		player:SetAttribute("Target", 0)
		return nil
	end
	return e
end

local function playerAttackPower(player: Player): number
	local team = S.PetService.team(player)
	local sum, n = 0, 0
	for _, st in ipairs(team) do
		sum += st.stats.atk
		n += 1
	end
	return Combat.Player.attack + (n > 0 and 0.35 * sum / n or 0)
end

function CombatService.playerAttack(player: Player, model: Instance?)
	if not attackLimiter:allow(player) then
		return
	end
	local now = os.clock()
	if now - (lastPlayerAttack[player] or 0) < Combat.Player.cooldown then
		return
	end
	local root = charRoot(player)
	local e = (typeof(model) == "Instance" and Entities.fromInstance(model)) or CombatService.focusOf(player)
	if not root or not e then
		return
	end
	local ok = canEngage(player, e, root.Position)
	if not ok then
		return
	end
	if not CombatRules.inRange(distanceTo(e, root.Position), Combat.Player.range, e.radius, 2) then
		return
	end
	if not CombatService.lineOfSight(root.Position, e.root.Position) then
		return
	end
	lastPlayerAttack[player] = now
	local dmg, crit = CombatRules.damage(playerAttackPower(player), 1, e.def, rand, {
		crit = Combat.Player.crit, defReduction = Entities.defReduction(e, now), bonus = 1 + Entities.markBonus(e, now),
	})
	CombatService.fx("bolt", { from = root.Position, to = e.root.Position, color = Color3.fromRGB(255, 240, 180), small = true })
	CombatService.damageEntity(e, dmg, { player = player, kind = "player" }, crit)
	if not focus[player] then
		focus[player] = e
		player:SetAttribute("Target", e.eid)
	end
end

local function abilityTarget(player: Player, st)
	local e = CombatService.focusOf(player) or (st.target and st.target.alive and st.target) or nil
	return e
end

-- Executa a habilidade do pet no `slot`. Tudo é verificado aqui.
function CombatService.useAbility(player: Player, slot: number)
	if type(slot) ~= "number" or slot ~= slot then
		return
	end
	slot = math.floor(slot)
	if not abilityLimiter:allow(player) then
		return
	end
	local team = S.PetService.team(player)
	local st = team[slot]
	if not st or not st.model or not st.model.Parent then
		return
	end
	local now = os.clock()
	if now < st.knockedUntil then
		return
	end
	if now < st.abilityReadyAt then
		return
	end
	local a = Abilities.Info[st.stats.ability]
	if not a or st.energy < a.cost then
		return
	end
	local effect, cooldown = PetStats.abilityValues(st.stats.ability, st.pet.abilityRank or 1, st.stats.cdr)
	local pos = st.root.Position
	local e = nil
	if a.target == "enemy" then
		e = abilityTarget(player, st)
		if st.stats.ability == "treasure_sense" and not e then
			e = nil -- pode usar sem alvo (só revela tesouros)
		else
			if not e then
				return
			end
			local ok = canEngage(player, e, pos)
			if not ok then
				return
			end
			if not CombatRules.inRange(distanceTo(e, pos), a.range, e.radius, 3) then
				Push:FireClient(player, "Toast", { text = a.label .. ": alvo fora de alcance", kind = "error" })
				return
			end
		end
	end

	st.energy -= a.cost
	st.abilityReadyAt = now + cooldown
	st.abilityReadyAtServer = serverNow() + cooldown
	st.lastCombatAt = now
	setAction(st.model, "Cast")
	local id = st.stats.ability
	local src = { player = player, pet = st, kind = "ability" }

	if id == "charge" then
		local dir = (pos - e.root.Position) * Vector3.new(1, 0, 1)
		dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
		local dest = e.root.Position + dir * ((e.radius or 2) + 2.5)
		CombatService.fx("charge", { from = pos, to = dest, color = Color3.fromRGB(255, 200, 120) })
		st.model:PivotTo(CFrame.new(Vector3.new(dest.X, pos.Y, dest.Z)))
		local dmg, crit = petDamage(st, e, a.power * effect)
		CombatService.damageEntity(e, dmg, src, crit)
	elseif id == "energy_bolt" then
		CombatService.fx("bolt", { from = pos, to = e.root.Position, color = Color3.fromRGB(150, 220, 255) })
		local travel = math.clamp((e.root.Position - pos).Magnitude / 90, 0.05, 0.6)
		task.delay(travel, function()
			if e.alive then
				local dmg, crit = petDamage(st, e, a.power * effect)
				CombatService.damageEntity(e, dmg, src, crit)
			end
		end)
	elseif id == "guard_shield" then
		st.shield = st.maxHp * a.power * effect
		st.shieldUntil = now + a.duration
		CombatService.fx("shield", { at = pos, model = st.model, duration = a.duration, color = Color3.fromRGB(140, 200, 255) })
		S.EnemyService.taunt(st, pos, 26, a.taunt)
		S.BossService.recordSupport(player, st.shield * 0.5)
	elseif id == "mend" then
		local healed = 0
		local amount = st.maxHp * a.power * effect
		for _, ally in ipairs(team) do
			if ally.model and ally.model.Parent and now >= ally.knockedUntil and (ally.root.Position - pos).Magnitude <= a.range then
				local before = ally.hp
				ally.hp = math.min(ally.maxHp, ally.hp + amount)
				healed += ally.hp - before
				queueNumber(ally.root.Position + Vector3.new(0, 3, 0), ally.hp - before, "heal")
				S.PetService.syncAttributes(ally)
			end
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local proot = charRoot(player)
		if hum and proot and (proot.Position - pos).Magnitude <= a.range then
			local before = hum.Health
			hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * a.power * effect)
			healed += (hum.Health - before) * 5
			queueNumber(proot.Position + Vector3.new(0, 3, 0), hum.Health - before, "heal")
		end
		CombatService.fx("heal", { at = pos, radius = a.range, color = Color3.fromRGB(140, 255, 170) })
		S.BossService.recordSupport(player, healed)
	elseif id == "shockwave" or id == "starfall" then
		local center = id == "starfall" and e.root.Position or pos
		local radius = id == "starfall" and a.radius or a.range
		CombatService.fx(id, { at = center, radius = radius, color = id == "starfall" and Color3.fromRGB(255, 230, 150) or Color3.fromRGB(200, 170, 255) })
		task.delay(id == "starfall" and 0.45 or 0.1, function()
			for _, other in ipairs(Entities.all()) do
				if other.alive and distanceTo(other, center) <= radius + (other.radius or 2) and canEngage(player, other, pos) then
					local dmg, crit = petDamage(st, other, a.power * effect)
					CombatService.damageEntity(other, dmg, src, crit)
				end
			end
		end)
	elseif id == "sunder" then
		table.insert(e.defMods, { amount = a.defReduction, untilT = now + a.duration })
		CombatService.fx("sunder", { from = pos, to = e.root.Position, color = Color3.fromRGB(255, 120, 90), duration = a.duration })
		local dmg, crit = petDamage(st, e, a.power * effect)
		CombatService.damageEntity(e, dmg, src, crit)
		e.model:SetAttribute("Sundered", serverNow() + a.duration)
	elseif id == "haste" then
		for _, ally in ipairs(team) do
			ally.hasteUntil = now + a.duration
		end
		CombatService.boostWalk(player, a.walkSpeed, a.duration)
		CombatService.fx("haste", { at = pos, radius = a.range, color = Color3.fromRGB(120, 255, 230) })
		S.BossService.recordSupport(player, st.maxHp * 0.3)
	elseif id == "treasure_sense" then
		S.ExplorationService.reveal(player, a.revealRadius, a.duration)
		CombatService.fx("sense", { at = pos, radius = a.revealRadius, color = Color3.fromRGB(255, 220, 120) })
		if e then
			table.insert(e.marks, { bonus = a.markBonus, untilT = now + a.duration })
			e.model:SetAttribute("Marked", serverNow() + a.duration)
			local dmg, crit = petDamage(st, e, a.power * effect)
			CombatService.damageEntity(e, dmg, src, crit)
		end
	elseif id == "root_snare" then
		if e.kind == "boss" then
			e.slowUntil = now + a.duration * 1.5
			e.slowAmount = a.bossSlow
		else
			e.stunnedUntil = now + a.duration * effect
		end
		e.model:SetAttribute("Snared", serverNow() + a.duration)
		CombatService.fx("snare", { at = e.root.Position, radius = (e.radius or 2) + 2, color = Color3.fromRGB(150, 230, 110), duration = a.duration })
		local dmg, crit = petDamage(st, e, a.power * effect)
		CombatService.damageEntity(e, dmg, src, crit)
	end
	S.QuestService.event(player, { type = "use_ability" })
	local data = S.DataService.get(player)
	if data then
		data.stats.abilities += 1
	end
	S.PetService.syncAttributes(st)
end

-------------------------------------------------------------------------------
-- IA de combate dos pets
-------------------------------------------------------------------------------

local function chooseTarget(player: Player, st, oroot: BasePart)
	local f = CombatService.focusOf(player)
	if f and f.alive and canEngage(player, f, st.root.Position) and distanceTo(f, oroot.Position) <= Combat.PetLeash then
		return f
	end
	-- revida quem está atacando o dono ou a equipe
	local best, bestD = nil, math.huge
	for _, e in ipairs(Entities.all()) do
		if e.alive and not e.passive and e.aggroPlayer == player then
			local d = distanceTo(e, oroot.Position)
			if d <= Combat.PetEngageRadius and d < bestD and canEngage(player, e, oroot.Position) then
				best, bestD = e, d
			end
		end
	end
	return best
end

local syncAcc = 0
local function markSync(st)
	-- atributos replicados com frequência reduzida (ver loop em start)
	st.needsSync = true
end

local function petTick(dt: number)
	local now = os.clock()
	for player, team in pairs(S.PetService.allTeams()) do
		local oroot = charRoot(player)
		for _, st in ipairs(team) do
			if st.model and st.model.Parent then
				-- energia e vida fora de combate
				st.energy = math.min(st.stats.energy, st.energy + st.stats.regen * dt)
				if now >= st.knockedUntil and st.hp <= 0 then
					st.hp = st.maxHp * Combat.ReviveFraction
				end
				if now - st.lastCombatAt > 5 and st.hp > 0 then
					st.hp = math.min(st.maxHp, st.hp + st.maxHp * Combat.OutOfCombatRegen * dt)
				end
				if now >= st.shieldUntil then
					st.shield = 0
				end
				if oroot and now >= st.knockedUntil and now >= (st.stunUntil or 0) then -- preso por raízes/vinhas de boss: não ataca
					st.target = chooseTarget(player, st, oroot)
					local e = st.target
					if e then
						st.mineTarget = nil
						local aspd = st.stats.aspd * (now < st.hasteUntil and 1.3 or 1)
						local d = distanceTo(e, st.root.Position)
						if d <= st.stats.range + (e.radius or 2) + 2.5 and now - st.lastAttackAt >= 1 / aspd then
							st.lastAttackAt = now
							-- Fúria cheia: este golpe vira o ataque Assinatura da espécie (SignatureService)
							local cast = S.SignatureService ~= nil and S.SignatureService.tryCast(player, st, e)
							if not cast then
								setAction(st.model, "Attack")
								local dmg, crit = petDamage(st, e, 1)
								if st.stats.range > 12 then
									CombatService.fx("bolt", { from = st.root.Position, to = e.root.Position, color = Color3.fromRGB(200, 220, 255), small = true })
								end
								CombatService.damageEntity(e, dmg, { player = player, pet = st, kind = "pet" }, crit)
								if S.SignatureService then
									S.SignatureService.addFury(st, 1)
								end
							end
						end
					end
				else
					st.target = nil
				end
				markSync(st)
			end
		end
	end
end

function CombatService.start()
	Players.PlayerRemoving:Connect(function(p)
		focus[p] = nil
		lastPlayerAttack[p] = nil
		walkMods[p] = nil
		abilityLimiter:clear(p)
		attackLimiter:clear(p)
		targetLimiter:clear(p)
	end)
	S.DataService.onLoaded(function(player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Humanoid")
			CombatService.refreshPlayerHealth(player)
		end)
		if player.Character then
			CombatService.refreshPlayerHealth(player)
		end
	end)
	local acc, flushAcc, losAcc = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		flushAcc += dt
		losAcc += dt
		syncAcc += dt
		if losAcc >= 1 then
			losAcc = 0
			refreshLosFilter()
		end
		if acc >= 0.1 then
			petTick(acc)
			acc = 0
		end
		if flushAcc >= 0.1 then
			flushAcc = 0
			flushNumbers()
		end
		if syncAcc >= 0.25 then
			syncAcc = 0
			for _, team in pairs(S.PetService.allTeams()) do
				for _, st in ipairs(team) do
					if st.needsSync then
						st.needsSync = false
						S.PetService.syncAttributes(st)
					end
				end
			end
		end
	end)
end

return CombatService

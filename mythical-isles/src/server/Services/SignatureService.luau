-- ATAQUES ASSINATURA (Config/Signatures): executados e validados no servidor.
-- Os ataques básicos dos pets enchem a Fúria (CombatService); com a Fúria cheia, o próximo golpe vira o
-- Assinatura da espécie: formas (alvo, cone, círculo, área, linha, ricochete, vários alvos, tornado),
-- golpes repetidos, controle (atordoar, prender, lentidão, empurrar, puxar), marcas e quebra de defesa,
-- sangramento e efeitos na equipe (cura, escudo, força, velocidade, provocar, faro). O cliente recebe um
-- evento "signature" e só desenha o efeito (Fx).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signatures = require(Shared.Config.Signatures)
local Pets = require(Shared.Config.Pets)
local Entities = require(script.Parent.Entities)

local SignatureService = {}

local S

function SignatureService.init(registry)
	S = registry
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Assinatura e Fúria máxima da espécie de um pet (ou nil se a espécie não tem).
function SignatureService.defFor(st)
	local def = Signatures.forSpecies(st.species)
	if not def then
		return nil, 0
	end
	local sp = Pets.Species[st.species]
	return def, Signatures.furyMax(sp and sp.rarity or "Common")
end

local function sync(st, max: number)
	if st.model and st.model.Parent then
		st.model:SetAttribute("Fury", st.fury or 0)
		st.model:SetAttribute("FuryMax", max)
	end
end

function SignatureService.addFury(st, n: number)
	local def, max = SignatureService.defFor(st)
	if not def then
		return
	end
	st.fury = math.min(max, (st.fury or 0) + n)
	sync(st, max)
end

-- Inimigos que o jogador pode atingir e que satisfazem `pred`.
local function enemies(player: Player, fromPos: Vector3, pred)
	local out = {}
	for _, other in ipairs(Entities.all()) do
		if other.alive and pred(other) and S.CombatService.canEngage(player, other, fromPos) then
			table.insert(out, other)
		end
	end
	return out
end

-- Controle e marcas num inimigo (em bosses: atordoar/prender viram lentidão; não são empurrados).
local function applyStatus(st, def, other, origin: Vector3, first: boolean)
	local now = os.clock()
	local boss = other.kind == "boss"
	local hold = math.max(def.stun or 0, def.root or 0)
	if hold > 0 then
		if boss then
			other.slowUntil = math.max(other.slowUntil or 0, now + hold * 1.5)
			other.slowAmount = math.max(other.slowAmount or 0, Signatures.BossSlow)
		else
			other.stunnedUntil = math.max(other.stunnedUntil or 0, now + hold)
		end
		other.model:SetAttribute("Snared", serverNow() + hold)
	end
	if def.slow then
		other.slowUntil = math.max(other.slowUntil or 0, now + def.slow.duration)
		other.slowAmount = math.max(now < (other.slowUntil or 0) and other.slowAmount or 0, def.slow.amount)
	end
	if def.defDown and first then
		table.insert(other.defMods, { amount = def.defDown.amount, untilT = now + def.defDown.duration })
		other.model:SetAttribute("Sundered", serverNow() + def.defDown.duration)
	end
	if def.mark and first then
		table.insert(other.marks, { bonus = def.mark.bonus, untilT = now + def.mark.duration })
		other.model:SetAttribute("Marked", serverNow() + def.mark.duration)
	end
	if not boss and (def.knock or def.pull) then
		local away = flat(other.root.Position - origin)
		local dist = away.Magnitude
		if dist > 0.1 then
			local move
			if def.knock then
				move = away.Unit * def.knock
			else
				move = -away.Unit * math.min(def.pull, math.max(0, dist - 3))
			end
			other.model:PivotTo(other.model:GetPivot() + move)
		end
	end
	if def.bleed and first then
		for i = 1, def.bleed.ticks do
			task.delay(i, function()
				if other.alive and st.model and st.model.Parent then
					local dmg = S.CombatService.petDamage(st, other, def.bleed.power)
					S.CombatService.damageEntity(other, dmg, { player = st.player, pet = st, kind = "pet" }, false)
				end
			end)
		end
	end
end

-- Efeitos na equipe (aliados num raio do pet e o dono).
local function teamEffects(player: Player, st, def, pos: Vector3, healOnly: boolean)
	local now = os.clock()
	local radius = def.radius and def.shape == "team" and def.radius or 30
	local support = 0
	for _, ally in ipairs(S.PetService.team(player)) do
		if ally.model and ally.model.Parent and now >= ally.knockedUntil and (ally.root.Position - pos).Magnitude <= radius then
			if def.heal then
				local before = ally.hp
				ally.hp = math.min(ally.maxHp, ally.hp + ally.maxHp * def.heal)
				support += ally.hp - before
				if ally.hp > before then
					S.CombatService.queueNumber(ally.root.Position + Vector3.new(0, 3, 0), ally.hp - before, "heal")
				end
			end
			if not healOnly then
				if def.shield then
					ally.shield = math.max(ally.shield, ally.maxHp * def.shield.amount)
					ally.shieldUntil = math.max(ally.shieldUntil, now + def.shield.duration)
					support += ally.maxHp * def.shield.amount * 0.5
				end
				if def.atkBuff then
					ally.sigAtkBonus = def.atkBuff.amount
					ally.sigAtkUntil = now + def.atkBuff.duration
				end
				if def.haste then
					ally.hasteUntil = math.max(ally.hasteUntil, now + def.haste)
				end
			end
			S.PetService.syncAttributes(ally)
		end
	end
	if def.heal then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local proot = S.CombatService.charRoot(player)
		if hum and proot and (proot.Position - pos).Magnitude <= radius then
			local before = hum.Health
			hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * def.heal)
			if hum.Health > before then
				S.CombatService.queueNumber(proot.Position + Vector3.new(0, 3, 0), hum.Health - before, "heal")
			end
		end
	end
	if healOnly then
		return support
	end
	if def.walk then
		S.CombatService.boostWalk(player, def.walk, def.haste or 6)
	end
	if def.taunt then
		S.EnemyService.taunt(st, pos, 26, def.taunt)
	end
	if def.reveal then
		S.ExplorationService.reveal(player, def.reveal, 8)
	end
	return support
end

--[[ Executa o Assinatura do pet `st` contra o alvo `e` (pode ser nil nos de equipe).
	Devolve um resumo { name, hits = golpes que acertaram, targets = { [entidade] = true } } ou nil. ]]
function SignatureService.cast(player: Player, st, e)
	local def = SignatureService.defFor(st)
	if not def or not st.model or not st.model.Parent then
		return nil
	end
	if def.shape ~= "team" and not (e and e.alive) then
		return nil
	end
	local pos = st.root.Position
	local ePos = e and e.root.Position or pos
	local dir = flat(ePos - pos)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, -1)
	if def.dash and e then
		local dest = ePos - dir * ((e.radius or 2) + 2.5)
		st.model:PivotTo(CFrame.lookAt(Vector3.new(dest.X, pos.Y, dest.Z), Vector3.new(ePos.X, pos.Y, ePos.Z)))
		pos = st.root.Position
	end
	S.CombatService.setAction(st.model, "Cast")
	st.lastCombatAt = os.clock()
	local summary = { name = def.name, hits = 0, targets = {} }
	local src = { player = player, pet = st, kind = "ability" }
	local hits = def.hits or 1
	local anchorPos = pos
	-- efeitos de equipe uma vez (e cura a cada pulso nos ataques de pulsos)
	local support = teamEffects(player, st, def, pos, false)
	local points = {}

	local function targetsFor(k: number)
		local center = def.anchor and anchorPos or (st.root and st.root.Position or pos)
		local shape = def.shape
		if shape == "single" then
			return (e and e.alive) and { e } or {}, center
		elseif shape == "circle" then
			local r = def.radius + (def.grow or 0) * (k - 1)
			return enemies(player, center, function(o)
				return S.CombatService.distanceTo(o, center) <= r
			end), center
		elseif shape == "area" or shape == "tornado" then
			local c = ePos
			if shape == "tornado" then
				c = pos:Lerp(ePos, math.min(1, k / math.max(1, hits - 2)))
			end
			return enemies(player, c, function(o)
				return S.CombatService.distanceTo(o, c) <= def.radius
			end), c
		elseif shape == "cone" then
			local cosA = math.cos(math.rad(def.angle / 2))
			return enemies(player, center, function(o)
				local v = flat(o.root.Position - center)
				local d = v.Magnitude
				if d > def.range + (o.radius or 2) then
					return false
				end
				return d < (o.radius or 2) + 1 or v.Unit:Dot(dir) >= cosA
			end), center
		elseif shape == "line" then
			return enemies(player, center, function(o)
				local v = flat(o.root.Position - center)
				local t = v:Dot(dir)
				local lateral = (v - dir * t).Magnitude
				return t >= -2 and t <= def.length + (o.radius or 2) and lateral <= def.width / 2 + (o.radius or 2)
			end), center
		elseif shape == "chain" then
			local list = { e }
			local others = enemies(player, ePos, function(o)
				return o ~= e and (o.root.Position - ePos).Magnitude <= def.bounce + (o.radius or 2)
			end)
			table.sort(others, function(a, b)
				return (a.root.Position - ePos).Magnitude < (b.root.Position - ePos).Magnitude
			end)
			for i = 1, math.min(def.chain, #others) do
				table.insert(list, others[i])
			end
			return list, center
		elseif shape == "multi" then
			local others = enemies(player, center, function(o)
				return o ~= e and S.CombatService.distanceTo(o, center) <= def.range
			end)
			table.sort(others, function(a, b)
				return (a.root.Position - center).Magnitude < (b.root.Position - center).Magnitude
			end)
			local list = { e }
			for i = 1, math.min(def.targets - 1, #others) do
				table.insert(list, others[i])
			end
			if def.splash then
				local seen = {}
				for _, t in ipairs(list) do
					seen[t] = true
				end
				for _, t in ipairs(table.clone(list)) do
					for _, o in ipairs(enemies(player, t.root.Position, function(x)
						return not seen[x] and (x.root.Position - t.root.Position).Magnitude <= def.splash + (x.radius or 2)
					end)) do
						seen[o] = true
						table.insert(list, o)
					end
				end
			end
			return list, center
		end
		return {}, center
	end

	local function pulse(k: number)
		if not st.model or not st.model.Parent then
			return
		end
		local list, center = targetsFor(k)
		for i, other in ipairs(list) do
			if other.alive then
				local power = def.power
				if def.shape == "chain" and i > 1 then
					power = def.chainPower or power
				end
				local critBonus = def.critBonus and (k == hits and def.critBonus or def.critBonus * 0.4) or nil
				local dmg, crit = S.CombatService.petDamage(st, other, power, critBonus)
				S.CombatService.damageEntity(other, dmg, src, crit)
				applyStatus(st, def, other, center, k == 1)
				summary.hits += 1
				summary.targets[other] = true
				if k == 1 then
					table.insert(points, other.root.Position)
				end
			end
		end
		if k > 1 and def.heal then
			support += teamEffects(player, st, def, center, true)
		end
	end

	if def.shape ~= "team" then
		pulse(1)
	end
	local fxPoints = {}
	for i = 1, math.min(#points, 6) do
		fxPoints[i] = points[i]
	end
	S.CombatService.fx("signature", {
		style = def.vfx, name = def.name, from = pos, to = ePos, at = (def.shape == "circle" or def.shape == "team") and pos or ePos, radius = def.radius, length = def.length,
		width = def.width, angle = def.angle, range = def.range, n = hits, interval = def.interval or 0, color = def.color, color2 = def.color2, model = st.model,
		points = fxPoints, grow = def.grow, anchor = def.anchor and anchorPos or nil,
	})
	for k = 2, hits do
		task.delay((k - 1) * (def.interval or 0.2), pulse, k)
	end
	if support > 0 then
		S.BossService.recordSupport(player, support)
	end
	return summary
end

-- Chamado pelo combate a cada golpe do pet: com a Fúria cheia, solta o Assinatura (true) e zera a Fúria.
function SignatureService.tryCast(player: Player, st, e): boolean
	local def, max = SignatureService.defFor(st)
	if not def or (st.fury or 0) < max then
		return false
	end
	local res = SignatureService.cast(player, st, e)
	if not res then
		return false
	end
	st.fury = 0
	sync(st, max)
	return true
end

function SignatureService.start()
	-- mostra a barra de Fúria (atributos) nos pets que têm Assinatura assim que entram em campo
	task.spawn(function()
		while true do
			for _, team in pairs(S.PetService.allTeams()) do
				for _, st in ipairs(team) do
					if st.model and st.model.Parent and st.model:GetAttribute("FuryMax") == nil then
						local def, max = SignatureService.defFor(st)
						if def then
							sync(st, max)
						end
					end
				end
			end
			task.wait(1)
		end
	end)
end

return SignatureService

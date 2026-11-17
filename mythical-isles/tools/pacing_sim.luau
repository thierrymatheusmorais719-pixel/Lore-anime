-- RITMO de um jogador novo (servidor REAL no simulador): um "bot" nasce no Verdant Haven com as moedas iniciais,
-- choca o primeiro ovo e então, em ciclos, minera o recurso vivo mais perto (Mine) e ataca o inimigo mais perto
-- (Target + Attack), chocando mais ovos quando sobra dinheiro (mantém 1 ovo de reserva para o portal).
-- Mede moedas e essência por minuto e quando daria para abrir o Mundo 2. Andar é simulado por teleporte até perto
-- do alvo (otimista: um jogador real perde tempo andando).
-- Uso: python3 tools/run_tests.py luau --pacing
local Worlds = require(__proxy("Shared/Config/Worlds"))
local Eggs = require(__proxy("Shared/Config/Eggs"))
for _, id in ipairs(Worlds.Order) do
	local w = Worlds.Info[id]
	table.insert(SIM.groundPlanes, { center = w.center, radius = w.radius, y = w.center.Y })
	if w.lowlands then
		table.insert(SIM.groundPlanes, { center = w.center, radius = w.lowlands.radius, y = w.center.Y - w.lowlands.drop })
	end
end
__modules["Server/Main"](__proxy("Server/Main"))
SIM.run(0.5)
local Request = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("Request")
local Action = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("Action")
local S = {
	DataService = require(__proxy("Server/Services/DataService")),
	WorldService = require(__proxy("Server/Services/WorldService")),
	EnemyService = require(__proxy("Server/Services/EnemyService")),
	PetService = require(__proxy("Server/Services/PetService")),
}
local p = SIM.addPlayer("Novato", 7)
SIM.run(1)
local d = S.DataService.get(p)
local function heal()
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = hum.MaxHealth
	end
end
local function req(action, payload)
	heal()
	SIM.run(0.1)
	return Request.OnServerInvoke(p, action, payload)
end
local function act(name, arg)
	heal()
	Action.OnServerEvent:Fire(p, name, arg)
	SIM.run(1 / 30)
end
local function teamLevel()
	local n, sum = 0, 0
	for _, uid in ipairs(d.team) do
		local pet = d.pets[uid]
		if pet then
			n += 1
			sum += pet.level
		end
	end
	return n > 0 and sum / n or 0
end
local function nearest(list, pos)
	local best, bd = nil, math.huge
	for _, m in ipairs(list) do
		local dd = (m:GetPivot().Position - pos).Magnitude
		if dd < bd then
			best, bd = m, dd
		end
	end
	return best
end

-- FASE de um mundo: minera e luta por `minutes`, chocando o ovo de moedas do mundo quando sobra dinheiro
-- (guarda o preço do próximo portal depois de 3 pets novos do mundo). Devolve o minuto em que juntou o portal.
local function farm(worldId: string, eggId: string, minutes: number, nextWorld: string?)
	local W = Worlds.Info[worldId]
	local center = W.center
	local station = S.WorldService.Layout[worldId].eggStations[eggId]
	local eggCost = Eggs.Info[eggId].cost
	local nextCost = nextWorld and Worlds.Info[nextWorld].unlockCost or math.huge
	local hatchedHere = 0
	local function hatch()
		SIM.teleport(p, station:GetPivot().Position + Vector3.new(0, 3, 6))
		SIM.run(0.4)
		local r = req("Hatch", { egg = eggId, count = 1 })
		if r.ok then
			hatchedHere += 1
			req("AutoTeam")
		end
		return r.ok
	end
	do
		local dps = 0
		for _, st in ipairs(S.PetService.team(p)) do
			dps += (st.stats.atk or 0) * (st.stats.aspd or 1)
		end
		print(string.format("PACE %s início: DPS somado da equipe %.0f", worldId, dps))
	end
	local t0 = SIM.now
	local unlockAt = nil
	local mineT, fightT, kills0, res0 = 0, 0, d.stats.kills or 0, d.stats.resources or 0
	local evolved = 0
	for minute = 1, minutes do
		local tEnd = SIM.now + 60
		while SIM.now < tEnd do
			local here = p.Character and p.Character.PrimaryPart and p.Character.PrimaryPart.Position or center
			local res = {}
			for _, r in ipairs(workspace:FindFirstChild("Resources"):GetChildren()) do
				if (r:GetAttribute("Health") or 0) > 0 and ((r:GetPivot().Position - center) * Vector3.new(1, 0, 1)).Magnitude < W.radius then
					table.insert(res, r)
				end
			end
			local foes = {}
			for _, e in ipairs(S.EnemyService.activeList()) do
				if e.alive and e.world == worldId and e.model and e.model.Parent then
					table.insert(foes, e.model)
				end
			end
			local r = nearest(res, here)
			local f = nearest(foes, here)
			if r and (not f or (SIM.now % 40) < 26) then
				SIM.teleport(p, r:GetPivot().Position + Vector3.new(5, 3, 0))
				local tm = SIM.now
				while (r:GetAttribute("Health") or 0) > 0 and r.Parent and SIM.now - tm < 12 do
					act("Mine", r)
					SIM.run(0.5)
				end
				mineT += SIM.now - tm
			elseif f then
				SIM.teleport(p, f:GetPivot().Position + Vector3.new(10, 3, 0))
				act("Target", f)
				local tf = SIM.now
				while f.Parent and not f:GetAttribute("Dead") and SIM.now - tf < 15 do
					act("Attack", f)
					SIM.run(0.6)
				end
				fightT += SIM.now - tf
			else
				SIM.run(1)
			end
			-- evolui quem chegou no nível máximo do estágio (como um jogador faria)
			local PetStatsL = require(__proxy("Shared/Logic/PetStats"))
			for _, uid in ipairs(d.team) do
				local pet = d.pets[uid]
				if pet and (pet.tier or 1) < 3 and (pet.level or 1) >= PetStatsL.levelCap(pet) then
					local ev = req("Evolve", { uid = uid })
					if ev.ok then
						evolved += 1
					end
				end
			end
			local reserve = (hatchedHere >= 3) and nextCost or 0
			if d.coins >= eggCost + reserve and hatchedHere < 6 then
				hatch()
			end
			if not unlockAt and d.coins >= nextCost then
				unlockAt = SIM.now - t0
			end
		end
		if minute % 5 == 0 or minute == 1 then
			print(string.format("PACE %s min %2d: %7d moedas, %5d essência, %d pets, nível médio %.1f, %d inimigos, %d recursos", worldId,
				minute, d.coins, d.essence, #d.team, teamLevel(), (d.stats.kills or 0) - kills0, (d.stats.resources or 0) - res0))
		end
	end
	-- força da equipe no fim do mundo: dano por segundo somado (atk × velocidade) e quem está nela
	do
		local Pets = require(__proxy("Shared/Config/Pets"))
		local dps, who = 0, {}
		for _, st in ipairs(S.PetService.team(p)) do
			dps += (st.stats.atk or 0) * (st.stats.aspd or 1)
			local sp = Pets.Species[st.species]
			table.insert(who, string.format("%s %s nv%d e%d", st.species, sp and sp.rarity or "?", st.pet.level, st.pet.tier or 1))
		end
		print(string.format("PACE %s equipe: DPS somado %.0f — %s; evoluções %d; pó de evolução %d", worldId, dps, table.concat(who, ", "),
			evolved, (d.items and d.items.evolution_dust) or 0))
	end
	print(string.format("PACE %s: minerando %.0f s, lutando %.0f s; portal seguinte (%s moedas) aos %s", worldId, mineT, fightT,
		tostring(nextCost), unlockAt and string.format("%.1f min", unlockAt / 60) or "não alcançado"))
end

print(string.format("PACE início: %d moedas", d.coins))
farm("verdant", "verdant_egg", 20, "crystal")
-- LUTA CONTRA UM BOSS com a equipe que o bot formou (sozinho). O bot fica dentro da arena, mira o boss, ataca
-- e usa as habilidades dos pets quando prontas. Conta o dano que o JOGADOR levaria (vida restaurada a cada
-- passo, para não precisar de respawn) e os nocautes de pets.
local function fight(bossId: string)
	local BossService = require(__proxy("Server/Services/BossService"))
	local boss
	for _, b in ipairs(BossService.list()) do
		if b.id == bossId then
			boss = b
		end
	end
	local hum = p.Character:FindFirstChildOfClass("Humanoid")
	local taken, knocks = 0, 0
	-- de onde veio cada dano no jogador (rótulo do ataque do boss no momento, ou o inimigo)
	local CombatService = require(__proxy("Server/Services/CombatService"))
	local bySource = {}
	local origHit = CombatService.hitPlayer
	CombatService.hitPlayer = function(pl, amount, attacker)
		local before = hum.Health
		local r = origHit(pl, amount, attacker)
		local lost = before - hum.Health
		if pl == p and lost > 0 then
			local key = (attacker == boss.entity or attacker == boss) and ("boss: " .. tostring(boss.model:GetAttribute("AttackLabel")))
				or (type(attacker) == "table" and attacker.id and ("inimigo " .. tostring(attacker.id))) or tostring(attacker)
			bySource[key] = (bySource[key] or 0) + lost
		end
		return r
	end
	local wasKnocked = {}
	local function track()
		if hum.Health < hum.MaxHealth then
			taken += hum.MaxHealth - hum.Health
			hum.Health = hum.MaxHealth
		end
		for _, st in ipairs(S.PetService.team(p)) do
			local k = os.clock() < (st.knockedUntil or 0)
			if k and not wasKnocked[st] then
				knocks += 1
			end
			wasKnocked[st] = k
		end
	end
	local spot = boss.arena.center + (boss.model.PrimaryPart.Position - boss.arena.center) * Vector3.new(1, 0, 1) * 0.3 + Vector3.new(14, 4, 0)
	SIM.teleport(p, spot)
	local t0 = SIM.now
	local maxT = 600
	-- desvio: com aviso de ataque (pasta Telegraphs) por perto, vai para o ponto da arena mais longe dos avisos
	local DODGE = DODGE_BOT ~= false
	local spotNow = boss.arena.center + Vector3.new(16, 4, 10)
	local dodges = 0
	local goalSpot, reactAt = spotNow, 0
	local function dodge()
		local tele = workspace:FindFirstChild("Telegraphs")
		local marks = {}
		for _, d in ipairs(tele and tele:GetDescendants() or {}) do
			if d:IsA("BasePart") then
				table.insert(marks, d)
			end
		end
		-- invocações do boss (brotos) que perseguem: o bot foge delas como foge dos avisos (raio de 8 studs)
		local chasers = {}
		for _, m in ipairs(boss.summons or {}) do
			if m.alive and m.model and m.model.PrimaryPart then
				table.insert(chasers, m.model.PrimaryPart.Position)
			end
		end
		if #marks == 0 and #chasers == 0 then
			return
		end
		local function danger(pos)
			local worst = math.huge
			for _, cpos in ipairs(chasers) do
				local dd = ((cpos - pos) * Vector3.new(1, 0, 1)).Magnitude - 8
				worst = math.min(worst, math.max(0, dd))
			end
			for _, m in ipairs(marks) do
				local rel = m.CFrame:Inverse() * pos
				-- distância até a "pegada" do aviso (caixa/cilindro achatado no chão)
				local hx, hz = m.Size.X / 2, m.Size.Z / 2
				if m:IsA("Part") and m.Shape == Enum.PartType.Cylinder then
					hx, hz = m.Size.Y / 2, m.Size.Z / 2
				end
				local dx, dz = math.max(0, math.abs(rel.X) - hx), math.max(0, math.abs(rel.Z) - hz)
				worst = math.min(worst, math.sqrt(dx * dx + dz * dz))
			end
			return worst
		end
		if danger(goalSpot) > 3 then
			return
		end
		-- como um jogador: o ponto SEGURO (fora dos avisos com 3 studs de folga) mais PERTO de onde está; só sem
		-- nenhum seguro vai para o mais longe dos avisos. (Antes ia sempre para o ponto mais longe da arena e
		-- atravessava as faixas do leque/cruz no caminho.)
		local best, bestD = goalSpot, danger(goalSpot)
		local bestSafe, bestTravel = nil, math.huge
		local cands = {}
		for k = 0, 15 do
			local a = k / 16 * math.pi * 2
			for _, r in ipairs({ 14, 24, 34 }) do
				table.insert(cands, boss.arena.center + Vector3.new(math.cos(a) * r, 4, math.sin(a) * r))
			end
			for _, r in ipairs({ 6, 11, 16 }) do
				local c = spotNow + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				if ((c - boss.arena.center) * Vector3.new(1, 0, 1)).Magnitude < boss.arena.radius - 2 then
					table.insert(cands, c)
				end
			end
		end
		for _, c in ipairs(cands) do
			local dd = danger(c)
			if dd > bestD then
				best, bestD = c, dd
			end
			local travel = ((c - spotNow) * Vector3.new(1, 0, 1)).Magnitude
			if dd > 3 and travel < bestTravel then
				bestSafe, bestTravel = c, travel
			end
		end
		if bestSafe then
			best = bestSafe
		end
		if best ~= goalSpot then
			goalSpot = best
			reactAt = SIM.now + 0.4 -- reação humana
			dodges += 1
		end
	end
	-- anda até o ponto escolhido a 16 studs/s (velocidade padrão do personagem), depois da reação
	local function walk(dt)
		if SIM.now < reactAt then
			return
		end
		local delta = (goalSpot - spotNow) * Vector3.new(1, 0, 1)
		local step = 16 * dt
		if delta.Magnitude <= step then
			spotNow = Vector3.new(goalSpot.X, spotNow.Y, goalSpot.Z)
		else
			spotNow += delta.Unit * step
		end
	end
	while SIM.now - t0 < maxT and boss.state ~= "Defeated" do
		if DODGE then
			dodge()
		end
		SIM.teleport(p, spotNow)
		Action.OnServerEvent:Fire(p, "Target", boss.model)
		Action.OnServerEvent:Fire(p, "Attack", boss.model)
		for i = 1, 4 do
			Action.OnServerEvent:Fire(p, "Ability", i)
		end
		for i = 1, 10 do
			SIM.run(0.1)
			track()
			if DODGE then
				if i % 2 == 0 then
					dodge()
				end
				walk(0.1)
				SIM.teleport(p, spotNow)
			end
		end
		if math.floor(SIM.now - t0) % 60 == 0 then
			print(string.format("BOSS t=%3.0fs vida %d/%d fase %d estado %s", SIM.now - t0, boss.entity.hp, boss.entity.maxHp, boss.phase, boss.state))
		end
	end
	CombatService.hitPlayer = origHit
	local srcs = {}
	for k, v in pairs(bySource) do
		table.insert(srcs, { k, v })
	end
	table.sort(srcs, function(a, b)
		return a[2] > b[2]
	end)
	for i = 1, math.min(5, #srcs) do
		print(string.format("BOSS   dano no jogador de %-34s %.0f", srcs[i][1], srcs[i][2]))
	end
	local maxHp = hum.MaxHealth
	print(string.format("BOSS %s sozinho (%s): %s em %.0f s; jogador levaria %.0f de dano (%.1f× a vida de %d); %d nocautes de pets; %d desvios",
		boss.cfg.name, DODGE and "desviando dos avisos com 0,4 s de reação e 16 studs/s" or "parado", boss.state == "Defeated" and "derrotado" or "NÃO derrotado", SIM.now - t0, taken, taken / maxHp, maxHp, knocks, dodges))
end

fight("elderroot")
-- MUNDO 2: abre o portal, viaja e joga mais 20 min; depois o Prism Titan
local un = req("UnlockWorld", { world = "crystal" })
local tp = req("Teleport", { world = "crystal" })
SIM.run(1.5)
print(string.format("PACE portal do Mundo 2: %s / viagem: %s; moedas restantes %d", tostring(un.ok or un.msg), tostring(tp.ok or tp.msg), d.coins))
farm("crystal", "crystal_egg", 20, "sky")
fight("prism_titan")
-- MUNDOS 3 a 5 (cada um: portal, 20 min, boss)
for _, step in ipairs({ { "sky", "sky_egg", "wilds", "tempest_wyrm", 30 }, { "wilds", "wilds_egg", "astral", "wilderbloom", 30 }, { "astral", "astral_egg", nil, "void_sovereign", 20 } }) do
	local u2 = req("UnlockWorld", { world = step[1] })
	local t2 = req("Teleport", { world = step[1] })
	SIM.run(1.5)
	print(string.format("PACE portal de %s: %s / viagem: %s; moedas restantes %d", step[1], tostring(u2.ok or u2.msg), tostring(t2.ok or t2.msg), d.coins))
	if u2.ok or p:GetAttribute("World") == step[1] then
		farm(step[1], step[2], step[5] or 20, step[3])
		fight(step[4])
	end
end
print("INFO erros " .. #SIM.errors)
for _, e in ipairs(SIM.errors) do
	print("INFO " .. e)
end

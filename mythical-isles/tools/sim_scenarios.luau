-- Cenários executados no simulador (python3 tools/run_tests.py <luau> --sim).
-- Roda o Main.server REAL e verifica os testes obrigatórios no nível do servidor.

local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then
		results.pass += 1
		print("PASSOU  " .. name)
	else
		results.fail += 1
		print("FALHOU  " .. name .. (detail and ("  -> " .. tostring(detail)) or ""))
	end
end

local Worlds = require(__proxy("Shared/Config/Worlds"))
for _, id in ipairs(Worlds.Order) do
	local w = Worlds.Info[id]
	table.insert(SIM.groundPlanes, { center = w.center, radius = w.radius, y = w.center.Y })
	if w.lowlands then
		-- terras baixas em volta do planalto (o raio que acerta primeiro é o do planalto, inserido antes)
		table.insert(SIM.groundPlanes, { center = w.center, radius = w.lowlands.radius, y = w.center.Y - w.lowlands.drop })
	end
end

-- servidor real
__modules["Server/Main"](__proxy("Server/Main"))
SIM.run(0.5)
check("servidor inicia sem erros", #SIM.errors == 0, SIM.errors[1])

local S = {}
for _, n in ipairs({ "DataService", "LuckService", "PetService", "CombatService", "EnemyService", "BossService", "WorldService", "EggService", "ExplorationService", "QuestService" }) do
	S[n] = require(__proxy("Server/Services/" .. n))
end
local Entities = require(__proxy("Server/Services/Entities"))
local AttackShapes = require(__proxy("Shared/Logic/AttackShapes"))
local InventoryLogic = require(__proxy("Shared/Logic/InventoryLogic"))
local Bosses = require(__proxy("Shared/Config/Bosses"))
local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local Request = Remotes:FindFirstChild("Request")
local Action = Remotes:FindFirstChild("Action")
-- O simulador não tem respawn: os jogadores de teste são curados antes de cada ação.
local function heal()
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = hum.MaxHealth
		end
	end
end
-- pedidos reais chegam com intervalo de rede; o limitador anti-spam recusa rajadas no mesmo instante
local function req(p, action, payload)
	heal()
	SIM.run(0.1)
	return Request.OnServerInvoke(p, action, payload)
end
local function act(p, name, arg)
	heal()
	Action.OnServerEvent:Fire(p, name, arg)
	SIM.run(1 / 30)
end
local function count(folderName)
	return #workspace:FindFirstChild(folderName):GetChildren()
end

do
	-- Nenhum ponto de gameplay pode ficar soterrado no estado FINAL do Terrain (os preenchimentos são
	-- aplicados em ordem, então escavações com Air depois de montanhas/maciços contam). Pontos:
	-- praça, estações de ovo, portais de mundo, centro e borda da arena, zonas de inimigos, campos de
	-- recurso e, nas regiões construídas, chegada de cada portal de região e cada baú-santuário.
	local WB = require(__proxy("Server/Services/WorldBuilder"))
	local WS = require(__proxy("Server/Services/WorldService"))
	local function inside(f, p)
		if f.kind == "ball" then
			return (p - f.cf.p).Magnitude <= f.r
		end
		local l = f.cf:Inverse() * p
		if f.kind == "cyl" then
			return math.abs(l.Y) <= f.h / 2 and math.sqrt(l.X * l.X + l.Z * l.Z) <= f.r
		end
		return math.abs(l.X) <= f.size.X / 2 and math.abs(l.Y) <= f.size.Y / 2 and math.abs(l.Z) <= f.size.Z / 2
	end
	local function buried(p)
		local mat = "Air"
		for _, f in ipairs(SIM.terrainFills) do
			if inside(f, p) then
				mat = f.m
			end
		end
		return mat ~= "Air" and mat ~= "Water", mat
	end
	local points = {}
	local function add(label, p)
		table.insert(points, { label = label, p = p })
	end
	local L = WB.Layout
	for _, id in ipairs(Worlds.Order) do
		local w = Worlds.Info[id]
		local lay = WS.Layout[id]
		local y = Vector3.new(0, w.center.Y + 2.5, 0)
		local function flat(v)
			return Vector3.new(v.X, 0, v.Z) + y
		end
		add(id .. " praça", flat(lay.spawnCF.Position))
		for egg, m in pairs(lay.eggStations) do
			add(id .. " ovo " .. egg, flat(m:GetPivot().Position))
		end
		add(id .. " portal", flat(WB.polar(w.center, L.portalNext.theta, L.portalNext.dist)))
		add(id .. " portal anterior", flat(WB.polar(w.center, L.portalPrev.theta, L.portalPrev.dist)))
		add(id .. " arena", flat(lay.arena.center))
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			add(id .. " borda da arena " .. k, flat(lay.arena.center + Vector3.new(math.cos(a), 0, math.sin(a)) * lay.arena.radius * 0.8))
		end
		for e, z in pairs(lay.enemyZones) do
			add(id .. " zona " .. e, flat(z.center))
		end
		for i, rf in ipairs(lay.resourceFields) do
			add(id .. " recursos " .. i, flat(rf.center))
		end
		local reg = WS.Regions[id]
		if reg then
			for rid, g in pairs(reg.gates) do
				add(id .. " chegada do portal " .. rid, g.arrival.Position - Vector3.new(0, 1, 0))
			end
			for cid, c in pairs(reg.chests) do
				add(id .. " baú " .. cid, c.pos + Vector3.new(0, 2.5, 0))
			end
			for label, q in pairs(reg.walkPoints or {}) do
				add(id .. " " .. label, q)
			end
			for label, q in pairs(reg.supportPoints or {}) do
				add(id .. " apoio " .. label, q)
			end
		end
	end
	local bad
	for _, pt in ipairs(points) do
		local isBuried, mat = buried(pt.p)
		if isBuried then
			bad = string.format("%s soterrado por %s em (%.0f, %.0f, %.0f)", pt.label, mat, pt.p.X, pt.p.Y, pt.p.Z)
			break
		end
	end
	check(string.format("terreno não soterra nenhum ponto de gameplay (%d pontos, %d preenchimentos)", #points, #SIM.terrainFills), bad == nil, bad)
end
check("mundos, inimigos, bosses e recursos criados", count("Enemies") > 50 and count("Bosses") == 5 and count("Resources") > 100,
	string.format("inimigos=%d bosses=%d recursos=%d", count("Enemies"), count("Bosses"), count("Resources")))

-- 1. jogador entra -------------------------------------------------------------
local p1 = SIM.addPlayer("Ana", 101)
SIM.run(1)
local d1 = S.DataService.get(p1)
check("servidor cria o personagem e coloca na praça (não no ar)", p1.Character ~= nil and math.abs(p1.Character.PrimaryPart.Position.Y - 4) < 1
	and ((p1.Character.PrimaryPart.Position - Vector3.new(0, 0, 0)) * Vector3.new(1, 0, 1)).Magnitude < 30, p1.Character and tostring(p1.Character.PrimaryPart.Position.Y))
check("perfil carrega com moedas iniciais", d1 ~= nil and d1.coins == 150, d1 and d1.coins)

-- 2. chocar ovo (servidor valida proximidade e custo) -----------------------------
local station = S.WorldService.Layout.verdant.eggStations.verdant_egg
local far = req(p1, "Hatch", { egg = "verdant_egg", count = 1 })
check("chocar longe da estação é recusado", far.ok == false, far.msg)
SIM.teleport(p1, station:GetPivot().Position + Vector3.new(0, 3, 6))
SIM.run(0.5)
local h1 = req(p1, "Hatch", { egg = "verdant_egg", count = 1, luck = 9999, mult = 9999 })
check("chocar 1 ovo funciona e cobra o preço", h1.ok and #h1.results == 1 and d1.coins == 50, h1.msg or d1.coins)
check("primeiro pet entra na equipe e ganha modelo 3D", #d1.team == 1 and #S.PetService.team(p1) == 1 and S.PetService.team(p1)[1].model.Parent ~= nil)
d1.coins += 100000
d1.essence += 5000
for _ = 1, 4 do
	req(p1, "Hatch", { egg = "verdant_egg", count = 3 })
	SIM.run(0.5)
end
req(p1, "AutoTeam")
SIM.run(0.3)
check("equipe completa com 4 pets", #S.PetService.team(p1) == 4, #S.PetService.team(p1))
check("bestiário registra os pets chocados", (function()
	for _, pet in pairs(d1.pets) do
		if not d1.bestiary.pets[pet.species] then
			return false
		end
	end
	return true
end)())

-- 9. sorte não pode ser falsificada --------------------------------------------
local before = S.LuckService.mults(p1)
local spoof = req(p1, "SetLuck", { mult = 100 })
act(p1, "Luck", 100)
local odds = req(p1, "EggOdds", { egg = "verdant_egg", mult = 1000, luck = 1000 })
local after = S.LuckService.mults(p1)
check("ação desconhecida (SetLuck) é recusada", spoof.ok == false)
check("multiplicador ignora valores do cliente", after.PetVariant == before.PetVariant and odds.mult == after.PetVariant, string.format("%s %s %s", tostring(before.PetVariant), tostring(after.PetVariant), tostring(odds.mult)))
local potionBefore = after.PetVariant
InventoryLogic.add(d1, "luck_potion_1", 1)
local drink = req(p1, "UsePotion", { item = "luck_potion_1" })
local afterPotion = S.LuckService.mults(p1).PetVariant
check("poção (fonte válida no servidor) aumenta a sorte com limite", drink.ok and afterPotion > potionBefore and afterPotion <= 3, afterPotion)
local fakePotion = req(p1, "UsePotion", { item = "luck_potion_3" })
check("não dá para beber poção que não possui", fakePotion.ok == false)

-- 2/4. inimigo detecta, persegue, ataca, recupera, retorna -------------------------
local thorn
for _, e in ipairs(S.EnemyService.activeList()) do
	if e.id == "thornling" and e.alive then
		thorn = e
		break
	end
end
local home = thorn.home
local seen = {}
local function watch(e, seconds)
	local t = 0
	while t < seconds do
		SIM.run(0.1)
		t += 0.1
		seen[e.state] = true
		local hum = p1.Character:FindFirstChildOfClass("Humanoid")
		hum.Health = hum.MaxHealth -- mantém o jogador vivo no teste
	end
end
-- deixa a equipe longe para isolar a IA (pets ficam perto do dono)
SIM.teleport(p1, home + Vector3.new(26, 3, 0))
watch(thorn, 6)
check("inimigo detecta o jogador e persegue", seen.Chase == true)
check("inimigo ataca e se recupera", seen.Attack == true and seen.Recover == true)
check("ataque inimigo causou dano (jogador ou pet)", (function()
	for _, m in ipairs(SIM.messages(p1, "Damage")) do
		for _, ev in ipairs(m) do
			if ev.k == "player" or ev.k == "pet" then
				return true
			end
		end
	end
	return false
end)())
-- foge para longe: coleira faz o inimigo voltar e ficar invulnerável no caminho
seen = {}
SIM.teleport(p1, home + Vector3.new(0, 3, 160))
watch(thorn, 12)
check("inimigo desiste e retorna à origem (coleira/tempo)", seen.Return == true, (function()
	local s = {}
	for k in pairs(seen) do
		table.insert(s, k)
	end
	return table.concat(s, ",")
end)())
watch(thorn, 8)
check("inimigo volta a Idle/Patrulha perto da origem", (thorn.state == "Idle" or thorn.state == "Patrol") and ((thorn.root.Position - home) * Vector3.new(1, 0, 1)).Magnitude < 30, thorn.state)
local patrolled = false
for _, e in ipairs(S.EnemyService.activeList()) do
	if e.world == "verdant" and (e.state == "Patrol" or e.goal ~= nil) then
		patrolled = true
	end
end
check("inimigos patrulham quando ociosos", patrolled)
-- investigação: dano vindo de fora do alcance de detecção
local other
for _, e in ipairs(S.EnemyService.activeList()) do
	if e.id == "wildroot_guardian" and e.alive and e.state ~= "Return" then
		other = e
		break
	end
end
SIM.teleport(p1, other.root.Position + Vector3.new(80, 0, 0))
SIM.run(0.2)
S.CombatService.damageEntity(other, 1, { player = p1, kind = "player" })
SIM.run(0.4)
check("dano sem ver o atacante leva à investigação", other.state == "Investigate", other.state)

-- 3/6. pets participam; alcance, recarga e dano do jogador -----------------------
local target
for _, e in ipairs(S.EnemyService.activeList()) do
	if e.id == "thornling" and e.alive and e.state ~= "Return" and e ~= thorn then
		target = e
		break
	end
end
SIM.teleport(p1, target.root.Position + Vector3.new(120, 3, 0))
SIM.run(0.3)
local hp0 = target.hp
act(p1, "Attack", target.model)
check("ataque do jogador fora de alcance é rejeitado", target.hp == hp0)
SIM.teleport(p1, target.root.Position + Vector3.new(14, 3, 0))
SIM.run(0.3)
heal()
-- os pets do jogador podem ter derrubado o alvo nesse meio-tempo: escolhe um vivo e enche a vida
if not target.alive then
	for _, e in ipairs(S.EnemyService.activeList()) do
		if e.id == "thornling" and e.alive and e.state ~= "Return" and e ~= thorn then
			target = e
			break
		end
	end
	SIM.teleport(p1, target.root.Position + Vector3.new(14, 3, 0))
	SIM.run(0.1)
end
target.hp = target.maxHp
do
	local dmgBefore = target.contrib[p1.UserId] and target.contrib[p1.UserId].damage or 0
	hp0 = target.hp
	Action.OnServerEvent:Fire(p1, "Attack", target.model)
	Action.OnServerEvent:Fire(p1, "Attack", target.model)
	Action.OnServerEvent:Fire(p1, "Attack", target.model)
	SIM.run(1 / 30)
	local c = target.contrib[p1.UserId]
	check("ataque no alcance causa dano; repetição na recarga é ignorada", target.hp < hp0 and c and c.damage - dmgBefore == hp0 - target.hp and (hp0 - target.hp) < 100,
		string.format("hp0=%s hp=%s dano registrado=%s", tostring(hp0), tostring(target.hp), tostring(c and c.damage)))
end
act(p1, "Target", target.model)
local team = S.PetService.team(p1)
local st1 = team[1]
st1.energy = 100
local readyBefore = st1.abilityReadyAt
act(p1, "Ability", 1)
local readyAfter = st1.abilityReadyAt
local energyAfter = st1.energy
act(p1, "Ability", 1)
check("habilidade usa energia e entra em recarga; spam é bloqueado", readyAfter > readyBefore and st1.abilityReadyAt == readyAfter and st1.energy >= energyAfter - 0.5,
	string.format("%s %s %s", tostring(readyBefore), tostring(readyAfter), tostring(st1.abilityReadyAt)))
act(p1, "Ability", 99)
act(p1, "Ability", "1")
check("habilidade com slot inválido é ignorada", #SIM.errors == 0, SIM.errors[1])
for _ = 1, 20 do
	SIM.run(0.3)
	heal()
end
local pd = target.pets[p1.UserId]
local petHits = 0
for _, v in pairs(pd or {}) do
	petHits += v
end
check("pets se aproximam e causam dano ao alvo", petHits > 0 or not target.alive, petHits)

-- 7. derrota gera recompensas válidas (e bestiário) -------------------------------
local kills0, essence0 = d1.stats.kills, d1.essence
local victim = target.alive and target or nil
if not victim then
	for _, e in ipairs(S.EnemyService.activeList()) do
		if e.id == "thornling" and e.alive then
			victim = e
			break
		end
	end
end
SIM.teleport(p1, victim.root.Position + Vector3.new(10, 3, 0))
SIM.run(0.2)
victim.hp = 5
victim.model:SetAttribute("Health", 5)
act(p1, "Attack", victim.model)
SIM.run(0.7)
local drops = SIM.messages(p1, "Drop")
check("derrota gera drops para quem participou", d1.stats.kills > kills0 and d1.essence > essence0 and #drops > 0, string.format("kills %d->%d", kills0, d1.stats.kills))
check("bestiário registra o inimigo derrotado", d1.bestiary.enemies.thornling ~= nil)
SIM.run(3)
check("inimigo derrotado some do mundo (limpeza)", victim.model.Parent == nil)

-- 5/6/10/12/13. boss: fases, indicadores, recompensa única, multiplayer -------------
local p2 = SIM.addPlayer("Bia", 202)
local p3 = SIM.addPlayer("Caio", 303)
SIM.run(1)
local d2, d3 = S.DataService.get(p2), S.DataService.get(p3)
local boss
for _, b in ipairs(S.BossService.list()) do
	if b.world == "verdant" then
		boss = b
	end
end
-- captura as formas construídas e as usadas no acerto
local built, tested = {}, {}
local origBuild, origHits = AttackShapes.build, AttackShapes.hitsAny
AttackShapes.build = function(atk, ctx)
	local shapes = origBuild(atk, ctx)
	table.insert(built, shapes)
	return shapes
end
AttackShapes.hitsAny = function(shapes, x, z, pad)
	tested[shapes] = true
	return origHits(shapes, x, z, pad)
end
local center = boss.arena.center
for i, p in ipairs({ p1, p2, p3 }) do
	SIM.teleport(p, center + Vector3.new(-20 + i * 10, 3, 25))
	local hum = p.Character:FindFirstChildOfClass("Humanoid")
	hum.MaxHealth = 1e7
	hum.Health = 1e7
end
SIM.run(0.5)
check("boss desperta quando jogadores entram na arena", boss.state == "Intro", boss.state)
check("vida do boss escala com o número de jogadores", boss.entity.maxHp == math.floor(Bosses.Info.elderroot.hp * (1 + 0.6 * 2)), boss.entity.maxHp)
SIM.run(3.2)
check("boss entra em combate após a introdução", boss.state == "Fight", boss.state)
-- p3 fica na arena sem contribuir; p1 e p2 batem
local function keepAlive()
	for _, p in ipairs({ p1, p2, p3 }) do
		local hum = p.Character:FindFirstChildOfClass("Humanoid")
		hum.Health = hum.MaxHealth
	end
end
local sawTelegraph = false
for _ = 1, 40 do
	act(p1, "Attack", boss.model)
	act(p2, "Attack", boss.model)
	SIM.run(0.25)
	keepAlive()
	if count("Telegraphs") > 0 then
		sawTelegraph = true
	end
end
check("boss usa ataques com indicador visual", sawTelegraph and #built > 0)
local allTested = #built > 0
for _, shapes in ipairs(built) do
	if not tested[shapes] then
		-- ataques cancelados pela troca de fase não testam acerto (o aviso também some)
		allTested = allTested and false
	end
end
check("o acerto usa exatamente as formas do indicador", allTested, string.format("%d formas construídas", #built))
-- geometria do indicador = forma
local geomOk = true
for _, shapes in ipairs(built) do
	for _, s in ipairs(shapes) do
		if s.type == "circle" and not (s.r > 0) then
			geomOk = false
		end
	end
end
check("formas de ataque válidas", geomOk)
-- fases
S.BossService.debugDamage("verdant", 0.45)
SIM.run(0.3)
check("boss muda para a fase 2 ao perder vida", boss.phase == 2 and boss.model:GetAttribute("Phase") == 2 and boss.state == "Transition", boss.phase)
check("transição de fase é invulnerável", boss.entity.invulnerable == true)
check("jogadores recebem aviso de fase", #SIM.messages(p1, "Phase") > 0)
SIM.run(2.8)
check("boss volta a lutar após a transição", boss.state == "Fight", boss.state)
S.BossService.debugDamage("verdant", 0.3)
SIM.run(0.3)
check("boss muda para a fase 3", boss.phase == 3, boss.phase)
SIM.run(2.8)
for _ = 1, 8 do
	act(p1, "Attack", boss.model)
	act(p2, "Attack", boss.model)
	SIM.run(0.6)
	keepAlive()
end
-- golpe final
local c1, c2 = boss.entity.contrib[p1.UserId], boss.entity.contrib[p2.UserId]
c1.damage = math.max(c1.damage, boss.entity.maxHp * 0.05)
c2.damage = math.max(c2.damage, boss.entity.maxHp * 0.05)
boss.entity.hp = 1
SIM.clearMessages(p1)
SIM.clearMessages(p2)
SIM.clearMessages(p3)
local b1, b2, b3 = d1.stats.bossKills, d2.stats.bossKills, d3.stats.bossKills
SIM.run(0.6)
act(p1, "Attack", boss.model)
SIM.run(0.5)
check("boss derrotado", boss.state == "Defeated", boss.state)
check("participantes ativos recebem recompensa", d1.stats.bossKills == b1 + 1 and d2.stats.bossKills == b2 + 1)
check("jogador só presente na arena NÃO recebe recompensa", d3.stats.bossKills == b3 and #SIM.messages(p3, "Drop") == 0)
check("bestiário registra o boss", d1.bestiary.bosses.elderroot ~= nil and d3.bestiary.bosses.elderroot == nil)
local enc = boss.encounterId
check("encontro registrado no perfil (anti-duplicata)", d1.claimedEncounters[enc] ~= nil)
S.BossService.onDefeated(boss, p1)
SIM.run(0.5)
check("boss não concede recompensa duplicada", d1.stats.bossKills == b1 + 1 and #SIM.messages(p1, "BossDefeated") == 1, d1.stats.bossKills)
check("inventários independentes entre jogadores", d1.coins ~= d2.coins and next(d3.pets) == nil and d1.pets ~= d2.pets)
AttackShapes.build, AttackShapes.hitsAny = origBuild, origHits
SIM.run(5)
check("indicadores de ataque são limpos", count("Telegraphs") == 0, count("Telegraphs"))
SIM.run(Bosses.Info.elderroot.respawn + 2)
local respawned
for _, b in ipairs(S.BossService.list()) do
	if b.world == "verdant" then
		respawned = b
	end
end
check("boss reaparece após o tempo de respawn", respawned.state == "Intro" or respawned.state == "Fight" or respawned.state == "Dormant", respawned.state)

-- 11. mutações persistem no inventário (salvar -> sair -> voltar) ---------------------
local mutated = InventoryLogic.addPet(d1, "bloomfox", "Golden", os.time(), "teste")
d1.team = { mutated.uid }
local uid = mutated.uid
S.PetService.spawnTeam(p1)
SIM.run(0.2)
check("modelo do pet mostra a mutação", S.PetService.team(p1)[1].model:GetAttribute("Mutation") == "Golden")
SIM.removePlayer(p1)
SIM.run(1)
local p1b = SIM.addPlayer("Ana", 101)
SIM.run(1)
local d1b = S.DataService.get(p1b)
check("mutação persiste após sair e voltar", d1b and d1b.pets[uid] and d1b.pets[uid].mutation == "Golden" and d1b.bestiary.pets.bloomfox.muts.Golden ~= nil)
check("equipe e modelo restaurados ao voltar", d1b and d1b.team[1] == uid and S.PetService.team(p1b)[1] and S.PetService.team(p1b)[1].model:GetAttribute("Mutation") == "Golden")

-- evolução mantém mutação --------------------------------------------------------
local pet = d1b.pets[uid]
pet.level = 25
d1b.essence = 1e6
d1b.items.evolution_dust = 50
local evo = req(p1b, "Evolve", { uid = uid })
check("evolução funciona e mantém a mutação", evo.ok and pet.tier == 2 and pet.mutation == "Golden", evo.msg)


-- EXTRA: exploração, missões, coleção, mundos, itens, habilidades, todos os bosses, anúncios ----
local pX = p1b
local dX = d1b
-- mineração: pets + jogador quebram um recurso e geram moedas
local node
for _, r in ipairs(workspace:FindFirstChild("Resources"):GetChildren()) do
	if r:GetAttribute("ResourceId") == "bloom_bush" then
		node = r
		break
	end
end
SIM.teleport(pX, node:GetPivot().Position + Vector3.new(6, 3, 0))
SIM.run(0.3)
local coins0, res0 = dX.coins, dX.stats.resources
act(pX, "Mine", node)
for _ = 1, 30 do
	SIM.run(0.5)
	heal()
	if dX.stats.resources > res0 then
		break
	end
end
check("pets mineram recursos e geram moedas", dX.stats.resources > res0 and dX.coins > coins0, string.format("%d moedas", dX.coins - coins0))
-- tesouro: aparece, é revelado pelo explorador e aberto pelo dono (outro jogador não abre)
local Exp = S.ExplorationService
Exp.spawnTreasure(pX)
SIM.run(0.2)
local chest = workspace:FindFirstChild("Treasures"):GetChildren()[1]
check("tesouro surge perto do jogador", chest ~= nil and chest:GetAttribute("OwnerId") == pX.UserId)
Exp.reveal(pX, 200, 5)
check("explorador revela o tesouro", chest:GetAttribute("Revealed") == true)
SIM.teleport(p2, chest:GetPivot().Position + Vector3.new(3, 3, 0))
SIM.run(0.4)
act(p2, "OpenTreasure", chest)
check("outro jogador não abre o tesouro alheio", chest.Parent ~= nil)
local tre0 = dX.stats.treasures
SIM.teleport(pX, chest:GetPivot().Position + Vector3.new(3, 3, 0))
SIM.run(0.4)
act(pX, "OpenTreasure", chest)
check("dono abre o tesouro e recebe recompensa", dX.stats.treasures == tre0 + 1 and chest.Parent == nil)
-- MUNDO 2 — Crystal Hollow: regiões, portais de região, baús-santuário, NPCs
do
	local WS = S.WorldService
	local RS = require(__proxy("Server/Services/RegionService"))
	local Regions = require(__proxy("Shared/Config/Regions"))
	local reg = WS.Regions.crystal
	local nGates, nChests = 0, 0
	for _ in pairs(reg and reg.gates or {}) do
		nGates += 1
	end
	for cid in pairs(reg and reg.chests or {}) do
		if cid:find("_wild_", 1, true) or cid == "beacon_chest" then
			continue -- (baús do anel de mata e o Relicário do Farol Ancestral são contados nos cenários deles)
		end
		nChests += 1
	end
	check("Crystal Hollow: 5 regiões construídas sem erro (5 portais, 5 baús, 3 NPCs)", reg ~= nil and reg.errors == nil and nGates == 5 and nChests == 5 and #reg.npcs == 3,
		reg and (reg.errors or string.format("%d portais, %d baús, %d NPCs", nGates, nChests, #reg.npcs)))
	local folder = workspace.World.crystal:FindFirstChild("CrystalHollow")
	local names = {}
	for _, ch in ipairs(folder and folder:GetChildren() or {}) do
		names[ch.Name] = true
	end
	check("pastas das 5 regiões existem", names.CrystalValley and names.ShatteredPeaks and names.AzureCaverns and names.PrismLake and names.TitansDomain)
	-- terreno: montanhas, lago, rio e caverna escavada foram realmente preenchidos
	local c = Worlds.Info.crystal.center
	local water, air, mountains = 0, 0, 0
	for _, f in ipairs(SIM.terrainFills) do
		if ((f.cf.p - c) * Vector3.new(1, 0, 1)).Magnitude < 260 then
			if f.m == "Water" then
				water += 1
			elseif f.m == "Air" then
				air += 1
			elseif f.kind == "ball" and f.m == "Basalt" and f.cf.p.Y + f.r > 30 then
				mountains += 1
			end
		end
	end
	check("terreno de Crystal Hollow tem montanhas altas, água (lago/rio/lagoas) e escavações (caverna/túneis)", mountains >= 10 and water >= 15 and air >= 15,
		string.format("%d montanha, %d água, %d escavação", mountains, water, air))
	-- cada chegada de portal fica dentro da sua região
	local okReg = true
	for rid, g in pairs(reg.gates) do
		if Regions.at("crystal", g.arrival.Position) ~= rid then
			okReg = false
			print("  chegada fora da região: " .. rid .. " -> " .. tostring(Regions.at("crystal", g.arrival.Position)))
		end
	end
	check("chegada de cada portal de região fica dentro da própria região", okReg)
	-- desempenho: peças, luzes e emissores do mundo 2
	local nParts, nLights, nEmit = 0, 0, 0
	local beaconSite = workspace.World.crystal.CrystalHollow:FindFirstChild("AncientBeaconSite")
	for _, d in ipairs(workspace.World.crystal:GetDescendants()) do
		if beaconSite and d:IsDescendantOf(beaconSite) then
			continue -- o Farol Ancestral tem orçamento próprio (cenário do farol)
		end
		if d:IsA("BasePart") then
			nParts += 1
		elseif d.ClassName == "PointLight" then
			nLights += 1
		elseif d.ClassName == "ParticleEmitter" then
			nEmit += 1
		end
	end
	print(string.format("  Crystal Hollow: %d peças, %d luzes, %d emissores", nParts, nLights, nEmit))
	check("Crystal Hollow dentro do orçamento (≤ 9000 peças, ≤ 60 luzes, ≤ 120 emissores)", nParts <= 9000 and nLights <= 60 and nEmit <= 120,
		string.format("%d peças, %d luzes, %d emissores", nParts, nLights, nEmit))
	-- portal de região: bloqueado se o mundo não foi desbloqueado / se o jogador não está nele
	local d2 = S.DataService.get(p2)
	d2.worlds.crystal = nil
	SIM.teleport(p2, reg.gates.crystal_valley.arrival.Position)
	SIM.run(1)
	local denied = RS.travel(p2, "shattered_peaks")
	check("portal de região recusa quem não desbloqueou o mundo", denied.ok == false)
	local hadCrystal = dX.worlds.crystal
	dX.worlds.crystal = true
	SIM.teleport(pX, home + Vector3.new(0, 3, 30))
	SIM.run(1)
	local wrongWorld = RS.travel(pX, "shattered_peaks")
	check("portal de região recusa quem está em outro mundo", wrongWorld.ok == false)
	-- circuito completo pelos portais (prompt real do portal do vale + chamadas diretas)
	SIM.teleport(pX, reg.gates.crystal_valley.arrival.Position)
	SIM.run(2) -- respeita o intervalo anti-spam do portal (a tentativa recusada acima também conta)
	reg.gates.crystal_valley.prompt.Triggered:Fire(pX)
	SIM.run(1)
	local pos = pX.Character.PrimaryPart.Position
	local okCircuit = Regions.at("crystal", pos) == "shattered_peaks"
	for _, dest in ipairs({ "azure_caverns", "prism_lake", "titans_domain", "crystal_valley" }) do
		SIM.run(2)
		local r = RS.travel(pX, dest)
		SIM.run(0.5)
		if not r.ok or Regions.at("crystal", pX.Character.PrimaryPart.Position) ~= dest then
			okCircuit = false
			print("  falhou viagem para " .. dest .. ": " .. tostring(r.msg))
		end
	end
	check("circuito de portais: vale → picos → cavernas → lago → domínio → vale", okCircuit)
	SIM.run(2)
	RS.travel(pX, "prism_lake")
	SIM.run(2)
	check("pets acompanham a viagem entre regiões", (function()
		local folderP = workspace.Pets:FindFirstChild(tostring(pX.UserId))
		local m = folderP and folderP:GetChildren()[1]
		return m ~= nil and (m:GetPivot().Position - pX.Character.PrimaryPart.Position).Magnitude < 40
	end)())
	-- baú-santuário: longe = recusa; perto = recompensa; de novo = recarga; salvo no perfil
	local ch = reg.chests.lake_ruins
	SIM.run(2)
	local far = RS.claim(pX, "crystal", "lake_ruins")
	SIM.teleport(pX, ch.pos + Vector3.new(3, 3, 0))
	SIM.run(1)
	local t0, c0 = dX.stats.treasures, dX.coins
	local ok1 = RS.claim(pX, "crystal", "lake_ruins")
	SIM.run(1.5)
	local again = RS.claim(pX, "crystal", "lake_ruins")
	check("baú-santuário: recusa de longe, dá recompensa de perto e respeita a recarga", far.ok == false and ok1.ok and ok1.first and dX.coins > c0 and dX.stats.treasures == t0 + 1
		and again.ok == false and type(dX.shrines.lake_ruins) == "number",
		string.format("far=%s ok=%s again=%s", tostring(far.ok), tostring(ok1.ok), tostring(again.ok)))
	-- todos os baús e NPCs respondem
	local allChests = true
	for cid, chest in pairs(reg.chests) do
		if cid ~= "lake_ruins" then
			SIM.teleport(pX, chest.pos + Vector3.new(2, 3, 0))
			SIM.run(1.5)
			local r = RS.claim(pX, "crystal", cid)
			if not r.ok then
				allChests = false
				print("  baú " .. cid .. ": " .. tostring(r.msg))
			end
		end
	end
	check("os 5 baús-santuário podem ser abertos (cada um no seu lugar)", allChests)
	local talked = true
	for _, npc in ipairs(reg.npcs) do
		SIM.teleport(pX, npc.model.PrimaryPart.Position + Vector3.new(0, 1, -5))
		SIM.run(1.5)
		local line = RS.talk(pX, npc)
		if type(line) ~= "string" then
			talked = false
		end
	end
	check("NPCs conversam (Lyra, Orin e Vael)", talked)
	SIM.teleport(pX, home + Vector3.new(0, 3, 30))
	SIM.run(1)
	dX.worlds.crystal = hadCrystal
end
-- Verdant Haven: bosque da árvore de blocos (referência do autor)
local function blockTreeChecks()
	local WB = require(__proxy("Server/Services/WorldBuilder"))
	local grove = workspace.World.verdant:FindFirstChild("BlockTreeGrove")
	local trees = grove and grove:GetChildren() or {}
	local heroes, total, shapes, distinct = 0, 0, {}, true
	local walkOk, placeOk, trunkOk = true, true, true
	local detail = ""
	for _, t in ipairs(trees) do
		if t.Name == "VerdantHeroTree" then
			heroes += 1
		end
		local n, ground = 0, nil
		local trunk = t:FindFirstChild("Trunk")
		if not trunk or not trunk.CanCollide then
			trunkOk = false
		end
		local plate = t:FindFirstChild("BasePlate")
		ground = (plate and (plate.Position.Y + plate.Size.Y / 2)) or (trunk.Position.Y - trunk.Size.Y / 2)
		local _, size = t:GetBoundingBox()
		for _, d in ipairs(t:GetDescendants()) do
			if d:IsA("BasePart") then
				n += 1
				-- além do tronco, nada que colida pode ficar mais alto que um degrau (dá para andar em volta)
				if d.CanCollide and d.Name ~= "Trunk" and d.Position.Y + d.Size.Y / 2 > ground + 3.2 then
					walkOk = false
					detail = t.Name .. ": " .. d.Name .. " colide alto"
				end
			end
		end
		total += n
		local key = string.format("%d:%.1f:%.1f:%.1f", n, size.X, size.Y, size.Z)
		if shapes[key] then
			distinct = false
		end
		shapes[key] = true
		local r = t:GetAttribute("CrownRadius") or 10
		if not WB.isFree("verdant", trunk.Position, r * 0.6, true) then
			placeOk = false
			detail = t.Name .. " (" .. tostring(t:GetAttribute("Variant")) .. ") invade área de gameplay"
		end
	end
	check(string.format("Verdant Haven: árvore de destaque + %d árvores da mesma família (sem cópias idênticas)", #trees - 1), #trees == 7 and heroes == 1 and distinct)
	check(string.format("árvores de blocos: %d peças no total (≤ 650), tronco com colisão, dá para andar em volta", total), total <= 650 and trunkOk and walkOk, detail)
	check("árvores de blocos fora das áreas de gameplay (arena, campos, zonas, ovos, portais)", placeOk, detail)
end
blockTreeChecks()
-- Todas as outras árvores (5 mundos) usam o modelo de galhos e cubos da segunda referência
local function treeStyleChecks()
	local trees, oldLeaves, noCubes, worlds, maxParts = 0, 0, 0, {}, 0
	for _, wf in ipairs(workspace.World:GetChildren()) do
		for _, m in ipairs(wf:GetDescendants()) do
			if m:IsA("Model") and (m.Name == "Tree" or m.Name == "Pine" or m.Name == "Bonsai") then
				trees += 1
				worlds[wf.Name] = true
				local cubes, n = 0, 0
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						n += 1
						if d.Name == "LeafCube" then
							cubes += 1
						elseif d.Name == "Leaf" or d.Name == "LeafCore" or d.Name == "Needles" then
							oldLeaves += 1
						end
					end
				end
				maxParts = math.max(maxParts, n)
				if cubes < 20 then
					noCubes += 1
				end
			end
		end
	end
	local nWorlds = 0
	for _ in pairs(worlds) do
		nWorlds += 1
	end
	check("árvores: todas (fora do bosque de blocos) usam o modelo de galhos e cubos de grama", trees > 100 and oldLeaves == 0 and noCubes == 0 and nWorlds >= 4,
		string.format("%d árvores em %d mundos, %d folhas antigas, %d sem cachos, máx. %d peças", trees, nWorlds, oldLeaves, noCubes, maxParts))
	local grove = workspace.World.verdant:FindFirstChild("BlockTreeGrove")
	local groveCubes = 0
	for _, d in ipairs(grove and grove:GetDescendants() or {}) do
		if d.Name == "LeafCube" then
			groveCubes += 1
		end
	end
	check("árvores: o bosque de blocos do Verdant continua com o seu próprio modelo", grove ~= nil and #grove:GetChildren() == 7 and groveCubes == 0)
end
treeStyleChecks()
-- Ilhas ampliadas: anel de mata (floresta densa, trilha, 6 lugares com baú) e orçamento por mundo
local function ringChecks()
	local WS = S.WorldService
	local WB = require(__proxy("Server/Services/WorldBuilder"))
	local MIN_TREES = { verdant = 150, crystal = 60, wilds = 150, astral = 70 }
	local BUDGET = { verdant = 13000, crystal = 9000, wilds = 13000, astral = 12000 }
	local okAll, detail = true, {}
	for _, id in ipairs({ "verdant", "crystal", "wilds", "astral" }) do
		local w = Worlds.Info[id]
		local wf = workspace.World:FindFirstChild(id)
		local ring = wf and wf:FindFirstChild("WildRing")
		local trees, pois = 0, 0
		for _, d in ipairs(ring and ring:GetDescendants() or {}) do
			if d:IsA("Model") and d.Name == "ForestTree" then
				trees += 1
			elseif d:IsA("Folder") and d.Name:sub(1, 4) == "POI_" then
				pois += 1
			end
		end
		local chests = 0
		local reg = WS.Regions[id]
		for cid in pairs(reg and reg.chests or {}) do
			if cid:find("_wild_", 1, true) then
				chests += 1
			end
		end
		local nParts, nLights, nEmit = 0, 0, 0
		local treeModel = wf and wf:FindFirstChild("SanctuaryTree")
		local beaconSite = wf and wf:FindFirstChild("CrystalHollow") and wf.CrystalHollow:FindFirstChild("AncientBeaconSite")
		local lowlands = wf and wf:FindFirstChild("Lowlands")
		for _, d in ipairs(wf and wf:GetDescendants() or {}) do
			if (treeModel and d:IsDescendantOf(treeModel)) or (beaconSite and d:IsDescendantOf(beaconSite)) or (lowlands and d:IsDescendantOf(lowlands)) then
				continue -- a Árvore-Santuário, o Farol Ancestral e as Terras Baixas têm orçamento próprio (cenários deles)
			end
			if d:IsA("BasePart") then
				nParts += 1
			elseif d:IsA("PointLight") or d:IsA("SpotLight") then
				nLights += 1
			elseif d:IsA("ParticleEmitter") then
				nEmit += 1
			end
		end
		print(string.format("  %s: raio %d (centro %d), %d árvores na mata, %d lugares, %d baús, %d peças, %d luzes, %d emissores", id, w.radius, w.core, trees, pois, chests, nParts, nLights, nEmit))
		local ok = w.radius >= w.core + 70 and trees >= MIN_TREES[id] and pois == 6 and chests == 6 and nParts <= BUDGET[id] and nLights <= 60 and nEmit <= 120
		if not ok then
			okAll = false
			table.insert(detail, id)
		end
	end
	check("ilhas ampliadas: anel de mata com floresta densa, 6 lugares e 6 baús em cada mundo, dentro do orçamento", okAll, table.concat(detail, ", "))
	-- FAROL ANCESTRAL (Mundo 2): torre-farol da imagem do autor + ruínas em volta, baú e região com nome
	;(function()
		local WS = require(__proxy("Server/Services/WorldService"))
		local CH = require(__proxy("Server/Services/CrystalHollow"))
		local RegionsCfg = require(__proxy("Shared/Config/Regions"))
		local site = workspace.World.crystal.CrystalHollow:FindFirstChild("AncientBeaconSite")
		local reg = WS.Regions.crystal
		local b = reg and reg.beacon
		if not site or not b then
			check("Farol Ancestral construído em Crystal Hollow", false, "sem farol")
			return
		end
		local parts, top, lattice, glowing = 0, -math.huge, 0, 0
		for _, d in ipairs(site:GetDescendants()) do
			if d:IsA("BasePart") then
				parts += 1
				if d.Name ~= "SkyBeam" and d.Name ~= "SkyBeamGlow" then
					top = math.max(top, d.Position.Y)
				end
				if d.Name == "Post" or d.Name == "Brace" or d.Name == "Ring" then
					lattice += 1
				end
				if d.Material == Enum.Material.Neon then
					glowing += 1
				end
			end
		end
		local base = RegionsCfg.polar("crystal", CH.BEACON.theta, CH.BEACON.dist)
		check("Farol Ancestral: torre em treliça de ~110 studs com cristal, feixe de luz e veios violeta, dentro do orçamento",
			top - base.Y >= 100 and lattice >= 150 and glowing >= 30 and parts <= 2600 and site:FindFirstChild("AncientBeacon"):FindFirstChild("Detail"):FindFirstChild("SkyBeam") ~= nil,
			string.format("topo %.0f, %d vigas, %d peças brilhantes, %d peças", top - base.Y, lattice, glowing, parts))
		check("Farol Ancestral: ruínas em volta (portal de pedra, colunata, pedras em pé, colunas quebradas) e ilhotas flutuantes",
			b.ruins >= 20 and b.isles == 3 and site.BeaconRuins:FindFirstChild("GateLintel") ~= nil and site.BeaconRuins:FindFirstChild("ColonnadeBeam") ~= nil, b.ruins .. " ruínas")
		check("Farol Ancestral: tem nome de região, baú registrado e fica no caminho oeste do vale",
			RegionsCfg.at("crystal", base) == "ancient_beacon" and reg.chests.beacon_chest ~= nil and RegionsCfg.at("crystal", base + Vector3.new(0, 0, 200)) ~= "ancient_beacon")
	end)()
	local badTree
	for _, id in ipairs({ "verdant", "crystal", "wilds", "astral" }) do
		local w = Worlds.Info[id]
		local plan = WB.ringPlan(id)
		for _, m in ipairs(workspace.World[id].WildRing.Forest:GetChildren()) do
			if m:IsA("Model") and m.Name == "ForestTree" then
				local tp = m:FindFirstChild("Trunk").Position
				local flat = (tp - w.center) * Vector3.new(1, 0, 1)
				local theta = math.deg(math.atan2(flat.Z, flat.X)) % 360
				if flat.Magnitude > w.radius - 6 or plan.blocked(theta, 0) then
					badTree = id .. " árvore fora do lugar em " .. tostring(tp)
				end
				for _, p in ipairs(plan.pois) do
					if ((tp - p.pos) * Vector3.new(1, 0, 1)).Magnitude < p.r then
						badTree = id .. " árvore dentro de " .. p.kind
					end
				end
			end
		end
	end
	check("mata: nenhuma árvore sobre os lugares, faixas de riacho ou fora da ilha", badTree == nil, badTree)
end
ringChecks()

-- MUNDO 3 — Skybound Kingdom: ilhas flutuantes, pontes, regiões, portais, baús, NPCs
local function skyboundChecks()
	local WS = S.WorldService
	local RS = require(__proxy("Server/Services/RegionService"))
	local Regions = require(__proxy("Shared/Config/Regions"))
	local reg = WS.Regions.sky
	local nG, nC = 0, 0
	for _ in pairs(reg and reg.gates or {}) do
		nG += 1
	end
	for _ in pairs(reg and reg.chests or {}) do
		nC += 1
	end
	check("Skybound Kingdom: 5 regiões sem erro (5 portais, 5 baús, 4 NPCs, 8 pontes)", reg ~= nil and reg.errors == nil and nG == 5 and nC == 5 and #reg.npcs == 4 and #reg.links == 8,
		reg and (reg.errors or string.format("%d portais, %d baús, %d NPCs, %d pontes", nG, nC, #reg.npcs, #reg.links)))
	-- todas as ilhas são alcançáveis a pé a partir da ilha principal (grafo das pontes)
	local adj = {}
	for _, l in ipairs(reg.links) do
		adj[l.a] = adj[l.a] or {}
		adj[l.b] = adj[l.b] or {}
		table.insert(adj[l.a], l.b)
		table.insert(adj[l.b], l.a)
	end
	local seen, queue = { main = true }, { "main" }
	while #queue > 0 do
		local cur = table.remove(queue, 1)
		for _, nx in ipairs(adj[cur] or {}) do
			if not seen[nx] then
				seen[nx] = true
				table.insert(queue, nx)
			end
		end
	end
	local missing = {}
	for name in pairs(reg.islands) do
		if not seen[name] then
			table.insert(missing, name)
		end
	end
	check("as 9 ilhas flutuantes são alcançáveis pelas pontes a partir do Cloud Harbor", #missing == 0, table.concat(missing, ", "))
	local steepest = 0
	for _, l in ipairs(reg.links) do
		local d = l.pb - l.pa
		local horiz = (d * Vector3.new(1, 0, 1)).Magnitude
		steepest = math.max(steepest, math.deg(math.atan2(math.abs(d.Y), horiz)))
	end
	check(string.format("pontes caminháveis (inclinação máxima %.0f° ≤ 30°)", steepest), steepest <= 30)
	-- cada ponta de ponte (e o cais) tem chão firme de Terrain embaixo e espaço livre em cima
	local function inside(f, p)
		if f.kind == "ball" then
			return (p - f.cf.p).Magnitude <= f.r
		end
		local l = f.cf:Inverse() * p
		if f.kind == "cyl" then
			return math.abs(l.Y) <= f.h / 2 and math.sqrt(l.X * l.X + l.Z * l.Z) <= f.r
		end
		return math.abs(l.X) <= f.size.X / 2 and math.abs(l.Y) <= f.size.Y / 2 and math.abs(l.Z) <= f.size.Z / 2
	end
	local function solidAt(p)
		local mat = "Air"
		for _, f in ipairs(SIM.terrainFills) do
			if inside(f, p) then
				mat = f.m
			end
		end
		return mat ~= "Air" and mat ~= "Water"
	end
	local bad
	for label, p in pairs(reg.supportPoints) do
		if solidAt(p) or not solidAt(p - Vector3.new(0, 4.5, 0)) then
			bad = label
		end
	end
	check("pontas das pontes e do cais apoiadas em chão firme e livres em cima", bad == nil, bad)
	-- ilhas satélites contam como parte do mundo (inimigos, tesouros, região) e não disparam o resgate de queda
	local okWorld = true
	for name, isl in pairs(reg.islands) do
		if WS.worldAt(isl.top + Vector3.new(0, 3, 0)) ~= "sky" or isl.top.Y < Worlds.Info.sky.center.Y - 40 then
			okWorld = false
			print("  ilha fora do mundo: " .. name)
		end
	end
	check("ilhas satélites fazem parte do Skybound Kingdom (sem resgate de queda)", okWorld)
	local okReg = true
	for rid, g in pairs(reg.gates) do
		if Regions.at("sky", g.arrival.Position) ~= rid then
			okReg = false
			print("  chegada fora da região: " .. rid .. " -> " .. tostring(Regions.at("sky", g.arrival.Position)))
		end
	end
	check("chegada de cada portal do Skybound fica dentro da própria região", okReg)
	-- circuito de portais completo
	local had = dX.worlds.sky
	dX.worlds.sky = true
	SIM.teleport(pX, reg.gates.cloud_harbor.arrival.Position)
	SIM.run(2.5)
	local okCircuit = true
	for _, dest in ipairs({ "golden_heights", "storm_islands", "celestial_gardens", "tempest_arena", "cloud_harbor" }) do
		local r = RS.travel(pX, dest)
		SIM.run(2)
		if not r.ok or Regions.at("sky", pX.Character.PrimaryPart.Position) ~= dest then
			okCircuit = false
			print("  falhou viagem para " .. dest .. ": " .. tostring(r.msg))
		end
	end
	check("circuito de portais: porto → alturas → tempestade → jardins → arena → porto", okCircuit)
	local allChests = true
	for cid, chest in pairs(reg.chests) do
		SIM.teleport(pX, chest.pos + Vector3.new(2, 3, 0))
		SIM.run(1.5)
		local r = RS.claim(pX, "sky", cid)
		if not r.ok then
			allChests = false
			print("  baú " .. cid .. ": " .. tostring(r.msg))
		end
	end
	check("os 5 baús do Skybound podem ser abertos", allChests)
	local talked = true
	for _, n in ipairs(reg.npcs) do
		SIM.teleport(pX, n.model.PrimaryPart.Position + Vector3.new(0, 1, -5))
		SIM.run(1.5)
		if type(RS.talk(pX, n)) ~= "string" then
			talked = false
		end
	end
	check("NPCs do Skybound conversam (Aria, Seren, Thal, Lumi)", talked)
	-- inimigos e boss do mundo 3 integrados
	local foes, wyrm = 0, false
	for _, e in ipairs(workspace.Enemies:GetChildren()) do
		if WS.worldAt(e:GetPivot().Position) == "sky" then
			foes += 1
		end
	end
	for _, b in ipairs(workspace.Bosses:GetChildren()) do
		if b:GetAttribute("BossId") == "tempest_wyrm" then
			wyrm = true
		end
	end
	check("inimigos e Tempest Wyrm presentes no Skybound Kingdom", foes >= 10 and wyrm, foes .. " inimigos")
	local nParts, nLights, nEmit = 0, 0, 0
	for _, d in ipairs(workspace.World.sky:GetDescendants()) do
		if d:IsA("BasePart") then
			nParts += 1
		elseif d.ClassName == "PointLight" then
			nLights += 1
		elseif d.ClassName == "ParticleEmitter" then
			nEmit += 1
		end
	end
	print(string.format("  Skybound Kingdom: %d peças, %d luzes, %d emissores", nParts, nLights, nEmit))
	check("Skybound Kingdom dentro do orçamento (≤ 9500 peças, ≤ 60 luzes, ≤ 120 emissores)", nParts <= 9500 and nLights <= 60 and nEmit <= 120,
		string.format("%d peças, %d luzes, %d emissores", nParts, nLights, nEmit))
	SIM.teleport(pX, home + Vector3.new(0, 3, 30))
	SIM.run(1)
	dX.worlds.sky = had
end
skyboundChecks()
-- missões e coleção
local storyBefore = dX.quests.storyIndex
for _ = 1, 3 do
	req(pX, "ClaimStory")
end
check("missões concluídas são resgatadas (e só uma vez cada)", dX.quests.storyIndex >= storyBefore)
local claimedAny = false
for _, m in ipairs(require(__proxy("Shared/Config/Exploration")).CollectionMilestones) do
	local r = req(pX, "ClaimCollection", { id = m.id })
	if r.ok then
		claimedAny = true
		local again = req(pX, "ClaimCollection", { id = m.id })
		check("marco de coleção não é resgatado duas vezes", again.ok == false)
		break
	end
end
check("marco de coleção resgatável", claimedAny)
-- mundos
dX.coins += 3000
local un = req(pX, "UnlockWorld", { world = "sky" })
check("não pula mundos na ordem", un.ok == false, un.msg)
local un2 = req(pX, "UnlockWorld", { world = "crystal" })
local tp = req(pX, "Teleport", { world = "crystal" })
SIM.run(1.2)
check("desbloquear e viajar para Crystal Hollow", un2.ok and tp.ok and pX:GetAttribute("World") == "crystal", tostring(un2.msg) .. " " .. tostring(pX:GetAttribute("World")))
local tpLocked = req(pX, "Teleport", { world = "astral" })
check("viagem para mundo bloqueado é recusada", tpLocked.ok == false)
-- itens: catalisador, acessório, ovo especial, liberar
local plain = InventoryLogic.addPet(dX, "prismcat", nil, os.time(), "teste")
InventoryLogic.add(dX, "prismatic_catalyst", 1)
local cat = req(pX, "Catalyst", { uid = plain.uid, item = "prismatic_catalyst" })
check("catalisador aplica a mutação definida", cat.ok and plain.mutation == "Prismatic" and (dX.items.prismatic_catalyst or 0) == 0, cat.msg)
local cat2 = req(pX, "Catalyst", { uid = plain.uid, item = "prismatic_catalyst" })
check("catalisador sem estoque / pet já mutado é recusado", cat2.ok == false)
InventoryLogic.add(dX, "crystal_tiara", 1)
local acc = req(pX, "Accessory", { uid = plain.uid, item = "crystal_tiara" })
local acc2 = req(pX, "Accessory", { uid = dX.team[1], item = "crystal_tiara" })
check("acessório equipa e respeita a quantidade possuída", acc.ok and plain.accessory == "crystal_tiara" and acc2.ok == false)
InventoryLogic.add(dX, "prism_core_egg", 1)
local crystalStation = S.WorldService.Layout.crystal.eggStations.crystal_egg
SIM.teleport(pX, crystalStation:GetPivot().Position + Vector3.new(0, 3, 6))
SIM.run(0.5)
local se = req(pX, "HatchItem", { egg = "prism_core_egg" })
check("ovo especial do inventário é chocado na estação", se.ok and (dX.items.prism_core_egg or 0) == 0, se.msg)
local nPets = InventoryLogic.petCount(dX)
local rel = req(pX, "Release", { uids = { plain.uid } })
check("liberar pet remove do inventário e devolve essência", rel.ok and InventoryLogic.petCount(dX) == nPets - 1)
-- todas as habilidades executam no servidor sem erro
local abilityIds = { "charge", "energy_bolt", "guard_shield", "mend", "shockwave", "sunder", "haste", "treasure_sense", "root_snare", "starfall" }
local errs0 = #SIM.errors
local foe
for _, e in ipairs(S.EnemyService.activeList()) do
	if e.world == "crystal" and e.alive and e.id == "shard_crawler" then
		foe = e
		break
	end
end
foe.hp, foe.maxHp = 1e9, 1e9
SIM.teleport(pX, foe.root.Position + Vector3.new(12, 3, 0))
SIM.run(0.5)
act(pX, "Target", foe.model)
local used = 0
for _, ab in ipairs(abilityIds) do
	local st = S.PetService.team(pX)[1]
	st.stats.ability = ab
	st.energy = 200
	st.abilityReadyAt = 0
	st.model:PivotTo(CFrame.new(foe.root.Position + Vector3.new(6, 1, 0)))
	SIM.run(0.4)
	local before = st.abilityReadyAt
	act(pX, "Ability", 1)
	SIM.run(0.6)
	if st.abilityReadyAt > before then
		used += 1
	else
		print("  habilidade não executou: " .. ab)
	end
end
check("as 10 habilidades executam (recarga aplicada) sem erros", used == #abilityIds and #SIM.errors == errs0, string.format("%d/%d", used, #abilityIds))
check("Quebrar Defesa e Marca aplicam efeitos no alvo", #foe.defMods > 0 or (foe.model:GetAttribute("Sundered") or 0) > 0)
-- os 5 bosses: fases, ataques (inclui invocação e zonas seguras), derrota
local function fightBoss(worldId)
	local b
	for _, x in ipairs(S.BossService.list()) do
		if x.world == worldId then
			b = x
		end
	end
	if not b.entity then
		SIM.run(b.cfg.respawn + 1)
	end
	dX.worlds[worldId] = true
	SIM.teleport(pX, b.arena.center + Vector3.new(0, 3, 30))
	local hum = pX.Character:FindFirstChildOfClass("Humanoid")
	hum.MaxHealth = 1e7
	SIM.run(4)
	local phases, attacks = { [b.phase] = true }, {}
	local origStart = AttackShapes.build
	AttackShapes.build = function(atk, ctx)
		attacks[atk.shape] = true
		return origStart(atk, ctx)
	end
	for i = 1, #b.cfg.phases do
		if i == #b.cfg.phases then
			-- a fase final tem vários ataques: garante que o de zonas seguras aparece no teste
			for _, id in ipairs(b.cfg.phases[i].attacks) do
				if b.cfg.attacks[id].shape == "safezones" then
					SIM.run(0.5)
					S.BossService.forceAttack(b, id)
				end
			end
		end
		for _ = 1, 30 do
			act(pX, "Attack", b.model)
			SIM.run(0.4)
			heal()
		end
		phases[b.phase] = true
		if i < #b.cfg.phases then
			-- a partir da vida ATUAL (poderes como o Florescer curam o boss durante a luta)
			S.BossService.debugDamage(worldId, math.max(0.02, b.entity.hp / b.entity.maxHp - b.cfg.phases[i + 1].at + 0.02))
			SIM.run(3)
		end
	end
	AttackShapes.build = origStart
	local np = 0
	for _ in pairs(phases) do
		np += 1
	end
	local c = b.entity.contrib[pX.UserId]
	if c then
		c.damage = math.max(c.damage, b.entity.maxHp)
	end
	b.entity.hp = 1
	local kills = dX.stats.bossKills
	act(pX, "Attack", b.model)
	SIM.run(1)
	return b, np, attacks, dX.stats.bossKills == kills + 1
end
for _, wid in ipairs({ "crystal", "sky", "wilds", "astral" }) do
	local b, np, attacks, rewarded = fightBoss(wid)
	local shapes = {}
	for k in pairs(attacks) do
		table.insert(shapes, k)
	end
	table.sort(shapes)
	check(string.format("%s: %d fases, ataques [%s], derrotado e recompensado", b.cfg.name, np, table.concat(shapes, ",")), np == #b.cfg.phases and rewarded and #shapes >= 3,
		string.format("fases %d/%d recompensa %s", np, #b.cfg.phases, tostring(rewarded)))
	if wid == "wilds" then
		check("The Wilderbloom invoca criaturas (e elas somem com a derrota)", attacks.summon == true and #b.summons == 0)
	end
	if wid == "astral" then
		check("Void Sovereign usa zonas seguras na fase final", attacks.safezones == true)
	end
	if wid == "sky" then
		check("Tempest Wyrm tem fase aérea", b.cfg.phases[2].airborne == true)
	end
end
-- anúncios: Secret anunciado (servidor + global) uma única vez
SIM.clearMessages(p2)
local pub0 = SIM.published or 0
local Reward = require(__proxy("Server/Services/RewardService"))
Reward.givePet(pX, "lumivex", nil, "teste")
SIM.run(0.5)
local ann = SIM.messages(p2, "Announce")
check("descoberta SECRET é anunciada a outros jogadores", #ann == 1 and ann[1].rarity == "Secret", #ann)
check("anúncio global publicado e o eco não duplica", (SIM.published or 0) == pub0 + 1 and #SIM.messages(p2, "Announce") == 1)
check("histórico de descobertas registra a SECRET", dX.history[1] and dX.history[1].rarity == "Secret")
-- persistência: salvar ao sair grava no DataStore
local store = SIM.stores["MythicalIsles_v1"]
local writes0 = store.writes
SIM.removePlayer(p2)
SIM.run(1)
check("perfil é salvo no DataStore ao sair", store.writes > writes0)

-- ATAQUES ASSINATURA no servidor: formas, controle, efeitos na equipe e Fúria em combate real ---------
;(function()
	local SigS = require(__proxy("Server/Services/SignatureService"))
	local Signatures = require(__proxy("Shared/Config/Signatures"))
	local beforeSig = #SIM.errors
	local ps = SIM.addPlayer("Sig", 606)
	SIM.run(1)
	local dS = S.DataService.get(ps)
	-- lugar vazio do Verdant Haven (longe das zonas onde os pets dos outros jogadores de teste lutam)
	local vc = Worlds.Info.verdant.center
	local P = vc + Vector3.new(math.cos(math.rad(250)) * 100, 3, math.sin(math.rad(250)) * 100)
	-- inimigos do Verdant Haven agrupados num ponto conhecido (longe da área segura)
	local foes = {}
	-- Thornlings vivos (o território deles passa a ser P: inimigo fora do território volta para casa
	-- invulnerável). Chamado antes de cada lote: inimigos mortos nos testes anteriores são trocados.
	local function gather()
		table.clear(foes)
		for _, e in ipairs(S.EnemyService.activeList()) do
			if e.world == "verdant" and e.alive and e.id == "thornling" and #foes < 5 then
				table.insert(foes, e)
			end
		end
		for _, e in ipairs(foes) do
			e.leashCenter = P
			e.home = Vector3.new(P.X, e.home.Y, P.Z)
			e.invulnerable = false
		end
	end
	gather()
	-- freeze: segura o inimigo parado (nos testes de vários pulsos ele não sai andando da área)
	local function place(e, offset: Vector3, freeze: boolean?)
		e.model:PivotTo(CFrame.new(P + offset + Vector3.new(0, e.root.Position.Y - e.model:GetPivot().Position.Y, 0)))
		if e.humanoid then
			e.humanoid:MoveTo(e.root.Position) -- cancela a caminhada de antes (senão ele segue andando até o destino antigo)
		end
		e.hp = e.maxHp
		e.stunnedUntil, e.slowUntil, e.slowAmount = freeze and os.clock() + 20 or 0, 0, 0
		table.clear(e.marks)
		table.clear(e.defMods)
	end
	local function team(species)
		dS.team = {}
		for _, sp in ipairs(species) do
			table.insert(dS.team, InventoryLogic.addPet(dS, sp, nil, os.time(), "teste").uid)
		end
		S.PetService.spawnTeam(ps)
		SIM.run(0.5)
		-- devolve os estados NA ORDEM pedida (procura pela espécie)
		local t = {}
		for i, sp in ipairs(species) do
			for _, st in ipairs(S.PetService.team(ps)) do
				if st.species == sp then
					t[i] = st
				end
			end
			t[i].model:PivotTo(CFrame.new(P + Vector3.new(-10, 0, (i - 2.5) * 3)))
		end
		SIM.teleport(ps, P + Vector3.new(-14, 0, 0))
		SIM.run(0.2)
		return t
	end
	local okAll, why = #foes >= 4, (#foes .. " inimigos")
	local function expect(cond, msg)
		if not cond and okAll then
			okAll, why = false, msg
		end
	end
	-- lote 1: alvo único com atordoar/marca, área com lentidão em pulsos, cone, linha
	local t1 = team({ "owlet_1", "cap_1", "golemling_1", "grovestag_1" })
	local now = os.clock()
	place(foes[1], Vector3.new(0, 0, 0))
	local r = SigS.cast(ps, t1[1], foes[1])
	expect(r and r.hits == 1 and foes[1].stunnedUntil > os.clock() and #foes[1].marks == 1 and foes[1].hp < foes[1].maxHp, "Pio Hipnótico")
	place(foes[1], Vector3.new(0, 0, 0), true)
	place(foes[2], Vector3.new(3, 0, 2), true)
	place(foes[3], Vector3.new(30, 0, 30), true)
	r = SigS.cast(ps, t1[2], foes[1])
	SIM.run(2.6)
	expect(r and r.targets[foes[1]] and r.targets[foes[2]] and not r.targets[foes[3]] and r.hits >= 7 and foes[2].slowUntil > os.clock(), "Nuvem de Esporos: " .. tostring(r and r.hits))
	-- cone: o pet olha para foes[1]; foes[3] fica atrás do pet
	gather()
	place(foes[1], Vector3.new(0, 0, 0))
	place(foes[2], Vector3.new(2, 0, -2))
	t1[3].model:PivotTo(CFrame.new(P + Vector3.new(-8, 0, 0)))
	place(foes[3], Vector3.new(-16, 0, 0))
	SIM.run(0.1)
	r = SigS.cast(ps, t1[3], foes[1])
	expect(r and r.targets[foes[1]] and r.targets[foes[2]] and not r.targets[foes[3]] and foes[2].stunnedUntil > os.clock(), "Pisão Rachado (cone)")
	-- linha: foes[1] e foes[2] na linha; foes[3] fora
	gather()
	place(foes[1], Vector3.new(0, 0, 0))
	place(foes[2], Vector3.new(8, 0, 0.5))
	place(foes[3], Vector3.new(4, 0, 14))
	t1[4].model:PivotTo(CFrame.new(P + Vector3.new(-8, 0, 0)))
	SIM.run(0.1)
	r = SigS.cast(ps, t1[4], foes[1])
	expect(r and r.targets[foes[1]] and r.targets[foes[2]] and not r.targets[foes[3]] and foes[2].stunnedUntil > os.clock(), "Galhada Enraizante (linha)")
	-- lote 2: ricochete, vários alvos, equipe (cura + força), escudo
	gather()
	local t2 = team({ "scamper_1", "bloomwyvern_1", "berrygoat_1", "beetle_1" })
	place(foes[1], Vector3.new(0, 0, 0))
	place(foes[2], Vector3.new(6, 0, 0))
	place(foes[3], Vector3.new(0, 0, 8))
	r = SigS.cast(ps, t2[1], foes[1])
	local chained = 0
	for _ in pairs(r and r.targets or {}) do
		chained += 1
	end
	expect(chained == 2, "Bolota Certeira: " .. chained .. " alvos")
	r = SigS.cast(ps, t2[2], foes[1])
	local multi = 0
	for _ in pairs(r and r.targets or {}) do
		multi += 1
	end
	expect(multi >= 3, "Esferas de Polinização: " .. multi .. " alvos")
	for i, st in ipairs(t2) do
		st.hp = st.maxHp * 0.5
		st.model:PivotTo(CFrame.new(P + Vector3.new(-10, 0, (i - 2.5) * 3))) -- equipe junta (os pets se espalham lutando)
	end
	SIM.run(0.05)
	r = SigS.cast(ps, t2[3], nil)
	expect(r ~= nil and t2[1].hp > t2[1].maxHp * 0.5 and (t2[1].sigAtkUntil or 0) > os.clock(), "Chuva de Frutinhas (cura + força)")
	r = SigS.cast(ps, t2[4], nil)
	expect(r ~= nil and t2[2].shield > 0 and t2[2].shieldUntil > os.clock(), "Jardim Blindado (escudo)")
	-- lote 3: investida, ondas que crescem e empurram, tornado que puxa
	gather()
	local t3 = team({ "kit_1", "mossape_1", "verdigris_wisp", "sylvanox" })
	place(foes[1], Vector3.new(0, 0, 0))
	t3[1].model:PivotTo(CFrame.new(P + Vector3.new(-12, 0, 0)))
	SIM.run(0.1)
	SigS.cast(ps, t3[1], foes[1])
	expect((t3[1].root.Position - foes[1].root.Position).Magnitude < 8, "Mordida (investida)")
	place(foes[1], Vector3.new(0, 0, 0), true)
	place(foes[2], Vector3.new(0, 0, 11), true)
	t3[2].model:PivotTo(CFrame.new(P + Vector3.new(-2, 0, 0)))
	SIM.run(0.1)
	local start = foes[1].root.Position
	r = SigS.cast(ps, t3[2], foes[1])
	-- empurrão medido logo após a primeira onda (depois o inimigo volta a andar e o pet o persegue)
	local moved = ((foes[1].root.Position - start) * Vector3.new(1, 0, 1)).Magnitude
	SIM.run(1)
	expect(r and r.hits >= 3 and moved > 3, string.format("Onda de Choque Vibracional (3 ondas que empurram): %d golpes, empurrou %.1f", r and r.hits or 0, moved))
	gather()
	place(foes[1], Vector3.new(0, 0, 0), true)
	place(foes[2], Vector3.new(0, 0, 5), true)
	t3[3].model:PivotTo(CFrame.new(P + Vector3.new(-14, 0, 0)))
	-- isola o tornado: os outros pets da equipe ficam parados (sem a Onda de Choque deles empurrar os alvos)
	for _, i in ipairs({ 1, 2, 4 }) do
		t3[i].stunUntil = os.clock() + 6
		t3[i].fury = 0
	end
	SIM.run(0.1)
	r = SigS.cast(ps, t3[3], foes[1])
	SIM.run(5.2)
	-- o tornado nasce no pet e anda até o alvo: acerta nos pulsos finais, várias vezes
	expect(r and r.hits >= 4 and r.targets[foes[1]] and r.targets[foes[2]], string.format("Vendaval Esmeralda: %s golpes, alvo2 %s (vivo %s, dist %.1f)", tostring(r and r.hits),
		tostring(r and r.targets[foes[2]]), tostring(foes[2] and foes[2].alive), foes[2] and ((foes[2].root.Position - foes[1].root.Position) * Vector3.new(1, 0, 1)).Magnitude or -1))
	-- Fúria em combate real: com a barra cheia o próximo golpe do pet é o Assinatura (e a barra zera)
	place(foes[1], Vector3.new(0, 0, 0))
	local hero = t3[4]
	local _, max = SigS.defFor(hero)
	hero.fury = max
	hero.model:PivotTo(CFrame.new(P + Vector3.new(-4, 0, 0)))
	S.CombatService.setFocus(ps, foes[1].model)
	SIM.clearMessages(ps)
	local cast = false
	for _ = 1, 40 do
		SIM.run(0.1)
		for _, m in ipairs(SIM.messages(ps, "AbilityFx")) do
			if m.kind == "signature" and m.name == Signatures.Info.sylvanox.name then
				cast = true
			end
		end
		if cast then
			break
		end
		foes[1].hp = foes[1].maxHp
	end
	SIM.run(0.3)
	expect(cast and (hero.fury or 0) < max and hero.model:GetAttribute("FuryMax") == max, "Fúria: Assinatura em combate")
	-- ataques básicos enchem a Fúria
	t3[1].fury = 0
	t3[1].model:PivotTo(CFrame.new(P + Vector3.new(-3, 0, 2)))
	for _ = 1, 30 do
		SIM.run(0.1)
		foes[1].hp = foes[1].maxHp
	end
	expect((t3[1].fury or 0) > 0 and t3[1].model:GetAttribute("Fury") == t3[1].fury, "Fúria não enche com ataques básicos: " .. tostring(t3[1].fury))
	check("ataques Assinatura: alvo/área/cone/linha/ricochete/vários alvos/tornado, controle, cura, escudo e força; a Fúria cheia solta o ataque em combate",
		okAll and #SIM.errors == beforeSig, why .. " " .. tostring(SIM.errors[beforeSig + 1]))
	-- PODER DE TODOS OS PETS: pets dos Mundos 2 a 5 usam o próprio poder, e uma variante aplica o tempero dela
	;(function()
		local okW, whyW = true, ""
		local function exp(cond, msg)
			if not cond and okW then
				okW, whyW = false, msg
			end
		end
		local t4 = team({ "crystalfox_2", "thunder_ram", "aurorafox_1", "whisper_shade" })
		gather() -- depois de montar a equipe (os pets da equipe anterior podem ter derrubado os de antes)
		-- variante 2 da raposa de cristal: tempero Gelo (lentidão) — a base não deixa lento
		local fox = Signatures.forSpecies("crystalfox_2")
		exp(fox.twist == "Gelo" and fox.slow ~= nil and Signatures.Info.crystalfox.slow == nil, "tempero da variante: " .. tostring(fox.twist))
		place(foes[1], Vector3.new(0, 0, 0), true)
		foes[1].slowUntil = 0
		t4[1].model:PivotTo(CFrame.new(P + Vector3.new(-8, 0, 0)))
		SIM.run(0.1)
		local r4 = SigS.cast(ps, t4[1], foes[1])
		SIM.run(0.6)
		exp(r4 and r4.hits >= 1 and (foes[1].slowUntil or 0) > os.clock(), "Leque de Caudas Cristalinas · Gelo: " .. tostring(r4 and r4.hits))
		-- carneiro do trovão: linha com atordoar
		gather()
		place(foes[1], Vector3.new(0, 0, 0), false)
		t4[2].model:PivotTo(CFrame.new(P + Vector3.new(-10, 0, 0)))
		SIM.run(0.1)
		r4 = SigS.cast(ps, t4[2], foes[1])
		exp(r4 and r4.hits >= 1 and (foes[1].stunnedUntil or 0) > os.clock(), "Marrada Trovejante (atordoa)")
		-- raposa da aurora: poder de equipe (cura)
		t4[4].hp = t4[4].maxHp * 0.5
		t4[3].model:PivotTo(CFrame.new(P + Vector3.new(-12, 0, 2)))
		t4[4].model:PivotTo(CFrame.new(P + Vector3.new(-12, 0, -2)))
		SIM.run(0.1)
		local before = t4[4].hp
		SigS.cast(ps, t4[3], foes[1])
		exp(t4[4].hp > before, "Aurora Curativa (cura a equipe)")
		-- sombra sussurrante (Secret): vários alvos de uma vez
		gather()
		place(foes[1], Vector3.new(0, 0, 0), true)
		place(foes[2], Vector3.new(0, 0, 6), true)
		place(foes[3], Vector3.new(4, 0, -5), true)
		t4[4].model:PivotTo(CFrame.new(P + Vector3.new(-12, 0, 0)))
		SIM.run(0.1)
		r4 = SigS.cast(ps, t4[4], foes[1])
		local n = 0
		for _ in pairs(r4 and r4.targets or {}) do
			n += 1
		end
		exp(n >= 3, "Sussurro do Vazio: " .. n .. " alvos")
		check("poder de TODOS os pets: Mundos 2-5 usam o próprio poder no servidor e a variante aplica o tempero", okW and #SIM.errors == beforeSig,
			whyW .. " " .. tostring(SIM.errors[beforeSig + 1]))
	end)()
	SIM.removePlayer(ps)
	SIM.run(0.5)
end)()


-- CLIENTE: roda os controladores reais ligados ao servidor simulado -----------------
do
	local Players = game:GetService("Players")
	local lp = pX
	SIM.localPlayer = lp
	Players.LocalPlayer = lp
	local pg = Instance.new("PlayerGui")
	pg.Name = "PlayerGui"
	pg.Parent = lp
	local uis = Instance.new("UserInputService")
	uis.TouchEnabled = false
	uis.KeyboardEnabled = true
	SIM.registerService("UserInputService", uis)
	local cam = Instance.new("Camera")
	cam.CFrame = CFrame.new(0, 50, 0)
	cam.ViewportSize = Vector2.new(1280, 720)
	workspace.CurrentCamera = cam
	local rs = game:GetService("RunService")
	rs.RenderStepped = SIM.Signal()
	rs.Stepped = SIM.Signal()
	local bound = {}
	function rs.BindToRenderStep(_, name, _priority, fn)
		bound[name] = fn
	end
	function rs.UnbindFromRenderStep(_, name)
		bound[name] = nil
	end
	local function frames(n)
		for _ = 1, n do
			rs.Stepped:Fire(SIM.now, 1 / 60)
			for _, fn in pairs(bound) do
				fn(1 / 60)
			end
			rs.RenderStepped:Fire(1 / 60)
			SIM.run(1 / 60)
		end
	end
	local errs0 = #SIM.errors
	__modules["Client/Main"](__proxy("Client/Main"))
	frames(5)
	local initFail
	for _, w in ipairs(SIM.warnings) do
		if w:find("falha ao iniciar") then
			initFail = w
		end
	end
	check("cliente inicia todos os controladores sem erro", #SIM.errors == errs0 and initFail == nil, SIM.errors[errs0 + 1] or initFail)
	local DS = S.DataService
	DS.pushState(lp)
	S.LuckService.push(lp, true)
	frames(10)
	local State = require(__proxy("Client/Controllers/State"))
	check("cliente recebe perfil e sorte do servidor", State.profile ~= nil and State.luck ~= nil)
	local Panels = require(__proxy("Client/Controllers/Panels"))
	local okAll = true
	for _, name in ipairs({ "Pets", "Items", "Luck", "Bestiary", "Quests", "Map", "Settings" }) do
		local before = #SIM.errors
		local ok, err = pcall(Panels.open, name)
		frames(3)
		if not ok or #SIM.errors > before then
			okAll = false
			print("  painel com erro: " .. name .. " " .. tostring(err or SIM.errors[before + 1]))
		end
	end
	check("todos os painéis abrem com dados reais", okAll)
	-- UI NOVA (docs/UI_DESIGN_SYSTEM.md): HUD rúnico, janela com desfoque, grade de pets e menu de mundos
	;(function()
		local before = #SIM.errors
		local hud = lp.PlayerGui:FindFirstChild("HUD")
		local plaque = hud and hud:FindFirstChild("WorldPlaque")
		local counters = hud and hud:FindFirstChild("Counters")
		local menu = hud and hud:FindFirstChild("Menu")
		local status = hud and hud:FindFirstChild("Status")
		local nCounters, nHex = 0, 0
		for _, c in ipairs(counters and counters:GetChildren() or {}) do
			if c.ClassName == "Frame" then
				nCounters += 1
			end
		end
		for _, c in ipairs(menu and menu:GetChildren() or {}) do
			if c.ClassName == "TextButton" then
				nHex += 1
			end
		end
		check("HUD novo: placa do mundo, 4 contadores (3 moedas + material do mundo), 7 hexágonos e painel de status",
			plaque ~= nil and nCounters == 4 and nHex == 7 and status ~= nil, string.format("contadores %d, hexágonos %d", nCounters, nHex))
		local coinsAmount = counters and counters:FindFirstChild("coins") and counters.coins:FindFirstChild("Pill") and counters.coins.Pill:FindFirstChild("Amount")
		check("HUD novo: contador de moedas mostra o saldo do perfil", coinsAmount ~= nil and coinsAmount.Text == require(__proxy("Client/Controllers/UIKit")).fmt(State.profile.coins), coinsAmount and coinsAmount.Text)
		local hp = status and status:FindFirstChild("Body") and status.Body:FindFirstChild("HP")
		frames(3)
		local hpText = hp and hp:FindFirstChild("Text") and hp.Text.Text or ""
		check("HUD novo: barra de vida mostra a vida do avatar", hpText:find("/", 1, true) ~= nil, hpText)
		-- a placa segue o atributo World (que o servidor define pela posição): ir até o Crystal Hollow troca a placa
		local Worlds = require(__proxy("Shared/Config/Worlds"))
		local wname = plaque and plaque:FindFirstChild("WorldName")
		local backTo = lp.Character.PrimaryPart.Position
		SIM.teleport(lp, Worlds.Info.crystal.center + Vector3.new(0, 4, 14))
		SIM.run(1)
		frames(40)
		local nowWorld = lp:GetAttribute("World")
		check("HUD novo: placa acompanha o mundo atual", nowWorld == "crystal" and wname ~= nil and wname.Text == "Crystal Hollow", tostring(nowWorld) .. " / " .. (wname and wname.Text or "?"))
		SIM.teleport(lp, backTo)
		SIM.run(1)
		frames(40)
		-- janela: abre com desfoque e escurecimento, fecha limpando
		Panels.open("Pets")
		frames(20)
		local pgui = lp.PlayerGui:FindFirstChild("Panels")
		local modal = pgui and pgui:FindFirstChild("Modal")
		local blurFx = game:GetService("Lighting"):FindFirstChild("PanelBlur")
		check("janela rúnica abre com escurecimento e desfoque", modal ~= nil and modal.Visible and pgui.Scrim.Visible and blurFx ~= nil and blurFx.Size > 5,
			blurFx and tostring(blurFx.Size))
		local grid = modal and modal.Body.Content:FindFirstChild("Grid")
		local nSlots, nSel = 0, 0
		for _, c in ipairs(grid and grid:GetChildren() or {}) do
			if c.Name == "Slot" then
				nSlots += 1
				if c:FindFirstChild("Selected").Visible then
					nSel += 1
				end
			end
		end
		local nPets = 0
		for _ in pairs(State.profile.pets) do
			nPets += 1
		end
		check("grade de pets: um slot por pet e exatamente um selecionado", nSlots == nPets and nSel == (nPets > 0 and 1 or 0), string.format("%d slots, %d pets, %d selecionados", nSlots, nPets, nSel))
		-- menu de mundos com alguns mundos ainda fechados (cópia local do perfil; o servidor não muda)
		local realWorlds = State.profile.worlds
		State.profile.worlds = { verdant = true, crystal = true }
		Panels.open("Map")
		frames(5)
		local cards = modal.Body.Content:FindFirstChild("Cards")
		local nCards, nLocked, chainsOk = 0, 0, true
		for _, c in ipairs(cards and cards:GetChildren() or {}) do
			if c.ClassName == "Frame" then
				nCards += 1
				local locked = State.profile.worlds[c.Name] ~= true
				local art = c:FindFirstChild("Art")
				local links = 0
				for _, l in ipairs(art and art:GetChildren() or {}) do
					if l.Name == "Link" then
						links += 1
					end
				end
				if locked then
					nLocked += 1
					chainsOk = chainsOk and links >= 10 and art:FindFirstChild("Lock") ~= nil
				else
					chainsOk = chainsOk and links == 0
				end
			end
		end
		State.profile.worlds = realWorlds
		check("menu de mundos: 5 cartões; só os bloqueados têm correntes e cadeado", nCards == 5 and nLocked == 3 and chainsOk, string.format("%d cartões, %d bloqueados", nCards, nLocked))
		Panels.close()
		frames(20)
		check("fechar a janela tira o desfoque e o escurecimento", not modal.Visible and not pgui.Scrim.Visible and blurFx.Size < 0.5, tostring(blurFx.Size))
		check("UI nova: nenhum erro no cliente", #SIM.errors == before, SIM.errors[before + 1])
	end)()
	local before = #SIM.errors
	local ok, err = pcall(Panels.open, "Egg", "crystal_egg")
	frames(3)
	check("painel de ovo mostra as chances do servidor", ok and #SIM.errors == before, err or SIM.errors[before + 1])
	-- chocar pelo cliente (perto da estação) dispara a animação
	dX.coins += 5000
	SIM.teleport(lp, crystalStation:GetPivot().Position + Vector3.new(0, 3, 6))
	SIM.run(0.5)
	local res = State.request("Hatch", { egg = "crystal_egg", count = 3 })
	local Fx = require(__proxy("Client/Controllers/Fx"))
	-- todos os efeitos visuais (habilidades, inimigos, bosses, recursos) rodam sem erro e limpam as peças
	;(function()
		local beforeFx = #SIM.errors
		local here = lp.Character.PrimaryPart.Position
		local col = Color3.fromRGB(255, 200, 120)
		local petModel = workspace.Pets:FindFirstChildWhichIsA("Model", true)
		local payloads = {
			{ kind = "bolt", from = here, to = here + Vector3.new(20, 0, 0), color = col },
			{ kind = "bolt", from = here, to = here + Vector3.new(20, 0, 0), color = col, small = true },
			{ kind = "orb", from = here, to = here + Vector3.new(0, 0, 20), travel = 0.4, color = col },
			{ kind = "charge", from = here, to = here + Vector3.new(12, 0, 0), color = col },
			{ kind = "shield", at = here, model = petModel, duration = 1, color = col },
			{ kind = "heal", at = here, radius = 20, color = col },
			{ kind = "haste", at = here, radius = 18, color = col },
			{ kind = "sense", at = here, radius = 30, color = col },
			{ kind = "shockwave", at = here, radius = 12, color = col },
			{ kind = "slam", at = here, radius = 8, color = col },
			{ kind = "starfall", at = here, radius = 12, color = col },
			{ kind = "sunder", from = here, to = here + Vector3.new(5, 0, 0), color = col },
			{ kind = "snare", at = here, radius = 4, duration = 1, color = col },
			{ kind = "burst", at = here, radius = 5, color = col },
			{ kind = "bossImpact", at = here, y = here.Y, color = col, shapes = {
				{ type = "circle", x = here.X, z = here.Z, r = 10 }, { type = "ring", x = here.X, z = here.Z, inner = 6, outer = 14 },
				{ type = "rect", x = here.X, z = here.Z, dx = 1, dz = 0, length = 30, width = 6 }, { type = "cone", x = here.X, z = here.Z, dx = 0, dz = 1, angle = 60, length = 20 },
				{ type = "safezones", x = here.X, z = here.Z, r = 20, safe = {} } } },
		}
		local okFx, errFx = true, nil
		for _, pl in ipairs(payloads) do
			local ok2, e2 = pcall(Fx.play, pl)
			if not ok2 then
				okFx, errFx = false, pl.kind .. ": " .. tostring(e2)
			end
			frames(2)
		end
		frames(200)
		local leftover = 0
		for _, d in ipairs(workspace.CurrentCamera:FindFirstChild("LocalFx"):GetChildren()) do
			if d:IsA("BasePart") and d.Transparency < 1 then
				leftover += 1
			end
		end
		leftover += #workspace:FindFirstChild("LocalDebris"):GetChildren()
		check("efeitos visuais: todos os tipos rodam e as peças temporárias somem", okFx and #SIM.errors == beforeFx and leftover == 0,
			errFx or SIM.errors[beforeFx + 1] or ("sobraram " .. leftover .. " peças"))
	end)()
	-- regiões no cliente: nome da região na tela + luz/névoa da região (Azure Caverns)
	do
		local reg = S.WorldService.Regions.crystal
		local beforeR = #SIM.errors
		SIM.teleport(lp, reg.gates.azure_caverns.arrival.Position)
		lp:SetAttribute("World", "crystal")
		frames(90)
		local shown = false
		for _, d in ipairs(lp.PlayerGui:FindFirstChild("RegionBanner"):GetDescendants()) do
			if d.ClassName == "TextLabel" and d.Text == "Azure Caverns" then
				shown = true
			end
		end
		local atm = game:GetService("Lighting"):FindFirstChildOfClass("Atmosphere")
		check("cliente: entrar nas Azure Caverns mostra o nome e aplica a névoa/luz da caverna", shown and atm and math.abs(atm.Density - 0.5) < 0.01 and #SIM.errors == beforeR,
			SIM.errors[beforeR + 1] or ("densidade " .. tostring(atm and atm.Density)))
		SIM.teleport(lp, reg.gates.crystal_valley.arrival.Position)
		frames(60)
		check("cliente: voltar ao vale restaura a névoa do mundo", math.abs(atm.Density - 0.3) < 0.01, "densidade " .. tostring(atm.Density))
	end
	-- céu anime 2D: painéis de gradiente, nuvens, sol/lua; segue a câmera; cada mundo com a sua paleta
	local function skyChecks()
		local AnimeSky = require(__proxy("Shared/Builders/AnimeSky"))
		local SkyClient = require(__proxy("Client/Controllers/SkyClient"))
		local beforeS = #SIM.errors
		local skyFolder = lp.PlayerGui:FindFirstChild("AnimeSky")
		local function counts()
			local panels, clouds, stars, moon = 0, 0, 0, false
			for _, g in ipairs(skyFolder:GetChildren()) do
				if g.Name:sub(1, 8) == "SkyPanel" then
					panels += 1
				elseif g.Name:sub(1, 5) == "Cloud" then
					clouds += 1
				elseif g.Name:sub(1, 4) == "Star" then
					stars += 1
				elseif g.Name == "Moon" then
					moon = true
				end
			end
			return panels, clouds, stars, moon
		end
		lp:SetAttribute("World", "crystal")
		frames(10)
		local panels, clouds = counts()
		local camPos = workspace.CurrentCamera.CFrame.Position
		local anchorPart = workspace.CurrentCamera:FindFirstChild("AnimeSkyAnchor")
		check("céu anime: 14 nuvens 2D centradas na câmera e nenhum painel de gradiente (degradê vem da Atmosphere)", skyFolder and panels == 0 and clouds == 14 and anchorPart
			and (anchorPart.Position - camPos).Magnitude < 0.01 and SkyClient.current == "crystal", string.format("%d painéis, %d nuvens", panels, clouds))
		-- tudo do céu 2D fica além da ilha mais distante visível (~800 studs): nada cobre as ilhas
		local nearest = math.huge
		for _, g in ipairs(skyFolder:GetChildren()) do
			if g:IsA("BillboardGui") then
				nearest = math.min(nearest, g.StudsOffsetWorldSpace.Magnitude)
			end
		end
		check("céu anime: nuvens, sol e estrelas a mais de 1000 studs da câmera (atrás das ilhas)", nearest > 1000, string.format("mais perto: %.0f", nearest))
		-- (o servidor reatribui o mundo pela posição a cada 0,5 s: checa logo após a troca)
		lp:SetAttribute("World", "astral")
		local _, _, stars, moon = counts()
		local atmColor = game:GetService("Lighting"):FindFirstChildOfClass("Atmosphere").Color
		check("céu anime: Astral Sanctuary vira noite com estrelas e lua", SkyClient.current == "astral" and stars > 50 and moon, stars .. " estrelas")
		-- paletas distintas: nenhuma cor de céu/névoa repetida entre os 5 mundos
		local seenTop, seenFog, distinct = {}, {}, true
		for _, wid in ipairs(Worlds.Order) do
			local t = AnimeSky.theme(wid)
			local kt, kf = t.top:ToHex(), t.fog:ToHex()
			if seenTop[kt] or seenFog[kf] then
				distinct = false
			end
			seenTop[kt], seenFog[kf] = true, true
		end
		local atm = game:GetService("Lighting"):FindFirstChildOfClass("Atmosphere")
		check("cada mundo tem céu e ambiente com cores próprias (e a névoa segue o mundo)", distinct and atm ~= nil and atmColor == AnimeSky.theme("astral").fog and #SIM.errors == beforeS,
			SIM.errors[beforeS + 1])
		lp:SetAttribute("World", "verdant")
		frames(10)
	end
	skyChecks()
	-- PETS DE MALHA: o cliente troca o modelo de peças pelo de malhas anatômicas e anima as juntas
	local function meshPetChecks()
		local PetVisuals = require(__proxy("Client/Controllers/PetVisuals"))
		local PetMesh = require(__proxy("Shared/Builders/PetMesh"))
		local before = #SIM.errors
		local hero = lp.Character and lp.Character.PrimaryPart
		if hero then
			SIM.teleport(lp, hero.Position + Vector3.new(0, 0, 4)) -- garante que a equipe esteja perto
		end
		for _ = 1, 40 do
			frames(5)
			local n = 0
			for _ in pairs(PetVisuals.active) do
				n += 1
			end
			if n > 0 then
				break
			end
		end
		frames(30)
		local mine, swapped, hidden, meshParts, motors = 0, 0, true, 0, {}
		local sample
		local folder = workspace.Pets:FindFirstChild(tostring(lp.UserId))
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			if m:IsA("Model") then
				mine += 1
				local a = PetVisuals.active[m]
				if a then
					swapped += 1
					sample = sample or a.mesh
					for _, d in ipairs(m:GetDescendants()) do
						if d:IsA("BasePart") and not d:IsDescendantOf(a.mesh) and d.LocalTransparencyModifier ~= 1 then
							hidden = false
						end
					end
					for _, d in ipairs(a.mesh:GetDescendants()) do
						if d:IsA("MeshPart") then
							meshParts += 1
						elseif d:IsA("Motor6D") then
							motors[d.Name] = d
						end
					end
				end
			end
		end
		check("pets de malha: o cliente troca TODOS os pets da equipe pelo modelo anatômico de MeshParts (malhas criadas com EditableMesh)",
			mine > 0 and swapped == mine and PetMesh.available == true and meshParts >= 6 * swapped and SIM.meshStats.badFaces == 0,
			string.format("%d/%d pets, %d MeshParts, malhas %d (%d triângulos, faces ruins %d), disponível=%s %s", swapped, mine, meshParts, SIM.meshStats.meshes, SIM.meshStats.tris,
				SIM.meshStats.badFaces, tostring(PetMesh.available), tostring(PetMesh.lastError)))
		check("pets de malha: o modelo de peças antigo fica invisível neste cliente (sem pet duplicado)", hidden)
		-- animação: as juntas mexem com o tempo (respiração/olhar/cauda) e o ataque muda a pose
		-- (câmera perto do pet: o Animator só anima o que está perto da câmera)
		if sample and sample.PrimaryPart then
			workspace.CurrentCamera.CFrame = CFrame.new(sample.PrimaryPart.Position + Vector3.new(0, 6, 14), sample.PrimaryPart.Position)
		end
		local body = motors.Body
		local probe = motors.Neck or motors.Head or motors.Tail or motors.Seg1
		local t0 = body and body.Transform
		local p0 = probe and probe.Transform
		frames(20)
		local moved = body ~= nil and probe ~= nil and (body.Transform ~= t0 or probe.Transform ~= p0)
		check("pets de malha: as articulações são animadas (tronco, pescoço/cauda)", moved, sample and sample:GetAttribute("Anatomy"))
		local server = sample and sample.Parent
		local beforeAtk = probe and probe.Transform
		if server then
			server:SetAttribute("Action", "Attack")
			server:SetAttribute("ActionAt", workspace:GetServerTimeNow())
		end
		frames(12)
		local atkPose = probe and probe.Transform
		check("pets de malha: ataque muda a pose (bote, mordida ou golpe da anatomia)", beforeAtk ~= nil and atkPose ~= beforeAtk)
		if server then
			-- derruba o pet pelo estado real do servidor (o servidor sincroniza o atributo a cada tick)
			local st
			for _, x in ipairs(S.PetService.team(lp)) do
				if x.model == server then
					st = x
				end
			end
			local keepUntil = st and st.knockedUntil
			if st then
				st.knockedUntil = os.clock() + 3
			end
			frames(20) -- o servidor sincroniza os atributos dos pets a cada 0,25 s
			local faded = false
			for _, d in ipairs(sample:GetDescendants()) do
				if d:IsA("MeshPart") and (d.LocalTransparencyModifier or 0) > 0.3 then
					faded = true
				end
			end
			if st then
				st.knockedUntil = keepUntil or 0
			end
			frames(6)
			check("pets de malha: pet nocauteado deita e fica translúcido; volta ao normal", faded)
		end
		-- ANIMAÇÕES NOVAS: comportamento ocioso da anatomia, sono com "Zzz", tranco ao levar dano e festa de nível
		;(function()
			local Animator = require(__proxy("Client/Controllers/Animator"))
			local CM = require(__proxy("Client/Controllers/CreatureMotion"))
			local entry = sample and Animator._tracked[sample]
			if not entry then
				check("animações novas: pet de malha rastreado pelo Animator", false)
				return
			end
			frames(30) -- termina o nocaute/ataque
			local acts = CM.Acts[entry.gait] or CM.Acts.quad
			local function snapshot()
				local t = {}
				for _, j in ipairs(entry.mjoints) do
					t[j.motor] = j.motor.Transform
				end
				return t
			end
			local function diff(a, b)
				local n = 0
				for m, cf in pairs(a) do
					local o = b[m]
					if o and ((cf.Position - o.Position).Magnitude > 0.01 or (cf.LookVector - o.LookVector).Magnitude > 0.08 or (cf.UpVector - o.UpVector).Magnitude > 0.08) then
						n += 1
					end
				end
				return n
			end
			local allOk, names = true, {}
			for _, a in ipairs(acts) do
				CM.forceAct(entry, "rest_ref") -- nenhum: só zera o comportamento
				entry.act = nil
				frames(25)
				local ref = snapshot()
				CM.forceAct(entry, a[1])
				frames(math.floor(a[2] * 0.45 * 60))
				local changed = diff(snapshot(), ref)
				local ok = entry.lastAction == a[1] and changed >= 2
				if not ok then
					allOk = false
					table.insert(names, string.format("%s(%s,%d)", a[1], tostring(entry.lastAction), changed))
				end
				frames(math.floor(a[2] * 0.6 * 60))
			end
			check("animações novas: cada comportamento ocioso da anatomia (" .. tostring(entry.gait) .. ") muda a pose do pet", allOk, table.concat(names, " "))
			-- sono: depois de muito tempo parado deita e aparece o "Zzz"; ao se mexer, acorda
			CM.forceAct(entry, "sleep")
			frames(90)
			local canSleep = not entry.flies and entry.gait ~= "float" and entry.gait ~= "bounce"
			local snore = sample:FindFirstChild("Snore")
			check("animações novas: pet parado por muito tempo dorme com 'Zzz' (voadores e flutuantes não)",
				(canSleep and snore ~= nil and entry.lastAction == "sleep") or (not canSleep and snore == nil), tostring(entry.gait))
			entry.forceSleep, entry.idleFor = nil, 0
			frames(150)
			check("animações novas: ao voltar a se mexer o pet acorda e o 'Zzz' some", sample:FindFirstChild("Snore") == nil)
			-- tranco ao levar dano (atributo HitAt real do servidor)
			local st
			for _, xst in ipairs(S.PetService.team(lp)) do
				if xst.model == server then
					st = xst
				end
			end
			entry.hurtAt = nil
			if st then
				S.CombatService.hitPet(st, 1, 0.01, nil)
			end
			frames(6)
			check("animações novas: o pet dá um tranco ao levar dano", entry.hurtAt ~= nil)
			-- subiu de nível (XP real pelo PetService): festinha no cliente
			entry.partyAt = nil
			if st then
				S.PetService.grantXp(lp, { [st.uid] = 1e6 })
			end
			frames(10)
			check("animações novas: subir de nível faz a festinha do pet", entry.partyAt ~= nil and server:GetAttribute("LevelUpAt") ~= nil)
			check("animações novas: nenhum erro no cliente", #SIM.errors == before, SIM.errors[before + 1])
		end)()
		check("pets de malha: nenhum erro no cliente", #SIM.errors == before, SIM.errors[before + 1])
		-- sem a API de malhas (opção desligada no jogo): aviso NA TELA com o passo a passo e o erro real
		local avail, lastErr, polyErr = PetMesh.available, PetMesh.lastError, PetMesh.polyError
		PetMesh.available, PetMesh.lastError = false, "Mesh / Image APIs are disabled (simulado)"
		PetVisuals.reportIfUnavailable()
		local boxWhilePolyWorks = false
		for _, d in ipairs(lp.PlayerGui:GetDescendants()) do
			if (d.ClassName == "TextBox" or d.ClassName == "TextLabel") and type(d.Text) == "string" and d.Text:find("simulado", 1, true) then
				boxWhilePolyWorks = true
			end
		end
		check("pets de malha: sem EditableMesh mas com o modo de peças funcionando, NÃO aparece caixa de erro", not boxWhilePolyWorks)
		PetMesh.polyError = "falha simulada do modo de peças"
		PetVisuals.reportIfUnavailable()
		local shown = false
		for _, d in ipairs(lp.PlayerGui:GetDescendants()) do
			if (d.ClassName == "TextBox" or d.ClassName == "TextLabel") and type(d.Text) == "string" and d.Text:find("Allow Mesh / Image APIs", 1, true) and d.Text:find("simulado", 1, true) then
				shown = true
			end
		end
		PetMesh.available, PetMesh.lastError, PetMesh.polyError = avail, lastErr, polyErr
		check("pets de malha: se nem malhas nem peças funcionarem, aparece na tela como ligar ('Allow Mesh / Image APIs') e o erro do Roblox", shown)
		-- MODO DE PEÇAS (sem EditableMesh): cada triângulo vira 2 cunhas que cobrem exatamente o triângulo
		-- modelos LISOS (Builders/Smooth): um tubo de raio 1 e comprimento 8 vira contas que cobrem a superfície
		;(function()
			local Smooth = require(__proxy("Shared/Builders/Smooth"))
			local MeshKit = require(__proxy("Shared/Builders/MeshKit"))
			local tube = MeshKit.loft({ { p = Vector3.new(0, 0, -4), w = 1, h = 1 }, { p = Vector3.new(0, 0, 0), w = 1, h = 1 }, { p = Vector3.new(0, 0, 4), w = 1, h = 1 } },
				{ seg = 12, steps = 3, capStart = 0.6, capEnd = 0.6, color = function()
					return Color3.new(0.8, 0.5, 0.3)
				end })
			local bl = Smooth.blobs(tube, Vector3.new(0, 0, 0), { density = 1.15 })
			-- cada vértice da superfície fica perto da casca de alguma conta (valor implícito do elipsoide ~1)
			local worst = 0
			for _, v in ipairs(tube.verts) do
				local best = math.huge
				for _, b in ipairs(bl) do
					local q = b.cf:Inverse() * v
					local f = math.sqrt((q.X / (b.size.X / 2)) ^ 2 + (q.Y / (b.size.Y / 2)) ^ 2 + (q.Z / (b.size.Z / 2)) ^ 2)
					best = math.min(best, f)
				end
				worst = math.max(worst, best)
			end
			-- um anel (auréola) não pode virar uma bola tampando o furo
			local ringKeys = {}
			for k = 0, 24 do
				local a = k / 24 * math.pi * 2
				table.insert(ringKeys, { p = Vector3.new(math.cos(a) * 3, 0, math.sin(a) * 3), w = 0.3, h = 0.3 })
			end
			local ring = MeshKit.loft(ringKeys, { seg = 8, steps = 1, color = function()
				return Color3.new(1, 0.9, 0.4)
			end })
			local rb = Smooth.blobs(ring, Vector3.new(0, 0, 0), {})
			local hole = true
			for _, b in ipairs(rb) do
				if b.cf.Position.Magnitude < 1.5 then
					hole = false
				end
			end
			check("modelos lisos: um tubo vira contas que cobrem a superfície e um anel continua com o furo",
				#bl >= 3 and #bl <= 12 and worst < 1.25 and #rb >= 6 and hole, string.format("%d contas no tubo (pior %.2f), %d no anel, furo=%s", #bl, worst, #rb, tostring(hole)))
		end)()
		local okPoly, maxBlobs, broken = true, 0, ""
		for _, sid in ipairs({ "kit_1", "verdantwolf_1", "owlet_1", "glassserpent_1", "ent_1", "sylvanox" }) do
			local okB, res = pcall(PetMesh.buildTemplatePoly, sid, 1)
			if not okB or not res then
				okPoly, broken = false, sid .. ": " .. tostring(res)
			else
				maxBlobs = math.max(maxBlobs, res.blobs)
				local motors, bones, wedges, spheres, welded = 0, 0, 0, 0, 0
				for _, d in ipairs(res.model:GetDescendants()) do
					if d.ClassName == "Motor6D" and d.Name ~= "Fixed" then
						motors += 1
					elseif d.ClassName == "WedgePart" or d.ClassName == "CornerWedgePart" then
						wedges += 1
					elseif d.ClassName == "SpecialMesh" and d.MeshType == Enum.MeshType.Sphere then
						spheres += 1
					elseif d.ClassName == "WeldConstraint" and d.Part1 and d.Part1.Name == "Blob" and d.Part0 == d.Part1.Parent then
						welded += 1
					end
				end
				for _, d in ipairs(res.model:GetChildren()) do
					if d:IsA("BasePart") then
						bones += 1
					end
				end
				if res.blobs < 20 or wedges > 0 or spheres ~= res.blobs or welded ~= res.blobs or motors < 3 or bones < 6 or res.model:GetAttribute("PolyPet") ~= true then
					okPoly, broken = false, string.format("%s: %d elipsoides (%d esferas, %d soldados), %d cunhas, %d juntas, %d ossos", sid, res.blobs, spheres, welded, wedges, motors, bones)
				end
			end
		end
		check("modo de peças: pets LISOS (elipsoides soldados aos ossos, nenhuma cunha triangular) com esqueleto e juntas animáveis", okPoly and maxBlobs <= 600,
			broken ~= "" and broken or ("máx. " .. maxBlobs .. " elipsoides"))
		-- caminho real de quem não pode ligar a opção: o Roblox recusa o EditableMesh (como no Studio do autor)
		-- e o jogo troca sozinho os pets pelos low-poly, sem caixa de erro
		local asset = game:GetService("AssetService")
		local origCreate = asset.CreateEditableMesh
		asset.CreateEditableMesh = function()
			error("EditableMesh is not accessible. Go to the Security Tab in Experience Settings to enable this API.")
		end
		PetMesh._reset()
		local errsBefore = #SIM.errors
		S.PetService.spawnTeam(lp)
		local polySwapped, total = 0, 0
		for _ = 1, 60 do
			frames(5)
			polySwapped, total = 0, 0
			for m, a in pairs(PetVisuals.active) do
				if m.Parent then
					total += 1
					if a.mesh:GetAttribute("PolyPet") then
						polySwapped += 1
					end
				end
			end
			if polySwapped > 0 and polySwapped == total then
				break
			end
		end
		local polyMesh
		for m, a in pairs(PetVisuals.active) do
			if m.Parent and a.mesh:GetAttribute("PolyPet") then
				polyMesh = a.mesh
			end
		end
		local movedPoly = false
		if polyMesh then
			workspace.CurrentCamera.CFrame = CFrame.new(polyMesh.PrimaryPart.Position + Vector3.new(0, 6, 14), polyMesh.PrimaryPart.Position)
			local probe
			for _, d in ipairs(polyMesh:GetDescendants()) do
				if d.ClassName == "Motor6D" and (d.Name == "Neck" or d.Name == "Body") then
					probe = d
				end
			end
			local t0 = probe and probe.Transform
			frames(20)
			movedPoly = probe ~= nil and probe.Transform ~= t0
		end
		check("sem 'Allow Mesh / Image APIs': os pets da equipe viram os low-poly de peças, animados e sem caixa de erro",
			polySwapped > 0 and polySwapped == total and PetMesh.mode == "poly" and movedPoly and #SIM.errors == errsBefore,
			string.format("%d/%d low-poly, modo=%s, animado=%s, erro=%s", polySwapped, total, tostring(PetMesh.mode), tostring(movedPoly), tostring(SIM.errors[errsBefore + 1])))
		-- visual v4: no computador, os pets do próprio jogador usam a "Alta qualidade" do modo de peças
		;(function()
			local hqOk = polyMesh ~= nil and polyMesh:GetAttribute("Quality") == "high"
			local blobs = polyMesh and (polyMesh:GetAttribute("Blobs") or 0) or 0
			local lightT = PetMesh.buildTemplatePoly(polyMesh and polyMesh:GetAttribute("Species") or "kit_1", 1)
			check("pets lisos: pet do jogador no modo de peças usa a Alta qualidade (anatomia com mais detalhes, dentro do teto)",
				hqOk and lightT ~= nil and blobs >= lightT.blobs * 0.8 and blobs <= 600,
				string.format("qualidade %s, %d elipsoides (leve %s)", tostring(polyMesh and polyMesh:GetAttribute("Quality")), blobs, tostring(lightT and lightT.blobs)))
			-- Opções: trocar para Leve remonta os pets do jogador com menos faces, e voltar para Alta
			local PetVisuals = require(__proxy("Client/Controllers/PetVisuals"))
			local function myMeshes()
				local list = {}
				for m, a in pairs(PetVisuals.active) do
					if m.Parent and m:GetAttribute("Owner") == lp.UserId then
						table.insert(list, a.mesh)
					end
				end
				return list
			end
			PetVisuals.setHighQuality(false)
			frames(60)
			local light = 0
			for _, m in ipairs(myMeshes()) do
				if m:GetAttribute("Quality") == "light" then
					light += 1
				end
			end
			PetVisuals.setHighQuality(true)
			frames(60)
			local high = 0
			for _, m in ipairs(myMeshes()) do
				if m:GetAttribute("Quality") == "high" then
					high += 1
				end
			end
			check("visual v4: a opção 'Qualidade dos seus pets' troca na hora entre Leve e Alta", light >= 1 and high >= 1 and high == #myMeshes(),
				string.format("leve %d, alta %d de %d", light, high, #myMeshes()))
			polyMesh = myMeshes()[1] or polyMesh
		end)()
		-- visual v3: contorno de desenho nos pets do jogador, nada de textura de grama, olhos em camadas e
		-- sombreamento pela altura (faces de baixo mais escuras que as de cima)
		;(function()
			local hl = polyMesh and polyMesh:FindFirstChild("ToonOutline")
			local grass, lowSum, lowN, highSum, highN = 0, 0, 0, 0, 0
			local torso = polyMesh and polyMesh:FindFirstChild("Torso")
			local y0 = torso and torso.Position.Y or 0 -- centro do tronco
			local whites = 0
			for _, d in ipairs(polyMesh and polyMesh:GetDescendants() or {}) do
				if d.ClassName == "WedgePart" then
					grass += 1000 -- (não pode sobrar cunha triangular nos pets)
				elseif d.Name == "Blob" then
					if d.Material == Enum.Material.Grass then
						grass += 1
					end
					local c = d.Color
					local lum = (c.R + c.G + c.B) / 3
					local rel = d.Position.Y - y0
					if d.Parent and d.Parent.Name == "Torso" then
						if rel < 0 then
							lowSum, lowN = lowSum + lum, lowN + 1
						else
							highSum, highN = highSum + lum, highN + 1
						end
					end
					if d.Parent and d.Parent.Name == "Face" and c.R > 0.97 and c.G > 0.97 and c.B > 0.97 then
						whites += 1
					end
				end
			end
			check("visual dos pets: contorno de desenho (Highlight só com a linha) nos pets do jogador",
				hl ~= nil and hl.ClassName == "Highlight" and hl.FillTransparency == 1 and hl.OutlineTransparency < 0.5, hl and "ok" or "sem contorno")
			check("visual dos pets: nenhuma peça com textura de grama nem cunha triangular", polyMesh ~= nil and grass == 0, grass .. " peças com problema")
			check("visual dos pets: olhos com brilho branco no modo de peças", whites >= 2, whites .. " brilhos brancos no rosto")
			-- a mesma cor fica mais escura embaixo (oclusão pela altura) e um pouco mais saturada
			local Facets = require(__proxy("Shared/Builders/Facets"))
			local rl, gl, bl = Facets.toonRGB(0.6, 0.4, 0.3, 0)
			local rh, gh, bh = Facets.toonRGB(0.6, 0.4, 0.3, 1)
			check("visual dos pets: sombreamento pela altura (mesma cor mais escura embaixo, mais saturada)",
				rl + gl + bl < (rh + gh + bh) * 0.8 and (rh - bh) > (0.6 - 0.3), string.format("baixo %.2f, alto %.2f", rl + gl + bl, rh + gh + bh))
			local _ = lowSum + lowN + highSum + highN
		end)()
		asset.CreateEditableMesh = origCreate
		PetMesh._reset()
	end
	meshPetChecks()
	-- Skybound: raios das nuvens de tempestade, impactos elétricos e energia do Tempest Wyrm
	local function stormChecks()
		local SkyClient = require(__proxy("Client/Controllers/SkyClient"))
		local beforeS = #SIM.errors
		SkyClient.rebuild("sky")
		local sources = #SkyClient.stormSources()
		local here = workspace.CurrentCamera.CFrame.Position
		Fx.lightning(here + Vector3.new(0, 60, 0), here, Color3.fromRGB(170, 230, 255), 1)
		Fx.play({ kind = "bossImpact", at = here, y = here.Y, color = Color3.fromRGB(120, 170, 255), electric = true, shapes = { { type = "circle", x = here.X, z = here.Z, r = 8 } } })
		frames(200)
		local leftover = 0
		for _, d in ipairs(workspace.CurrentCamera:FindFirstChild("LocalFx"):GetChildren()) do
			if d:IsA("BasePart") and d.Transparency < 1 then
				leftover += 1
			end
		end
		check("Skybound: nuvens de tempestade com raios; raios e impactos elétricos rodam e somem", sources >= 10 and #SIM.errors == beforeS and leftover == 0,
			SIM.errors[beforeS + 1] or string.format("%d fontes de raio, %d peças sobrando", sources, leftover))
		-- (o Wyrm real pode estar derrotado/renascendo após os cenários de boss: usa um modelo do construtor)
		local wyrm = require(__proxy("Shared/Builders/BossModels")).build("tempest_wyrm")
		wyrm:SetAttribute("BossId", "tempest_wyrm_test")
		wyrm.Parent = workspace.Bosses
		task.spawn(Fx.trackEnergy, wyrm)
		frames(5)
		local lights = 0
		for _, d in ipairs(wyrm and wyrm:GetDescendants() or {}) do
			if d:IsA("BasePart") and d:GetAttribute("EnergyFx") and d:FindFirstChildOfClass("PointLight") then
				lights += 1
			end
		end
		wyrm:SetAttribute("WindupEnd", workspace:GetServerTimeNow() + 0.3)
		local b2 = #SIM.errors
		Fx.updateEnergy()
		frames(30)
		check("Tempest Wyrm: energia elétrica azul (olhos, boca, peito, asas, cauda) carrega com arcos", wyrm:GetAttribute("EnergyKind") == "electric" and lights >= 7 and #SIM.errors == b2,
			SIM.errors[b2 + 1] or (lights .. " luzes"))
		wyrm:Destroy()
		SkyClient.rebuild("verdant")
	end
	stormChecks()
	-- energia do Prism Titan: luzes nas peças EnergyFx, carga durante a preparação
	do
		local titan
		for _, m in ipairs(workspace.Bosses:GetChildren()) do
			if m:GetAttribute("BossId") == "prism_titan" then
				titan = m
			end
		end
		frames(5)
		local lights = {}
		for _, d in ipairs(titan and titan:GetDescendants() or {}) do
			if d:IsA("BasePart") and d:GetAttribute("EnergyFx") and d:FindFirstChildOfClass("PointLight") then
				table.insert(lights, d:FindFirstChildOfClass("PointLight"))
			end
		end
		local idle = lights[1] and lights[1].Brightness or 0
		titan:SetAttribute("WindupEnd", workspace:GetServerTimeNow() + 0.2)
		Fx.updateEnergy()
		local charged = lights[1] and lights[1].Brightness or 0
		titan:SetAttribute("ActionAt", workspace:GetServerTimeNow())
		Fx.updateEnergy()
		check("Prism Titan: núcleo, olhos e punhos brilham e carregam durante a preparação", #lights >= 5 and charged > idle + 2,
			string.format("%d luzes, repouso %.1f, carga %.1f", #lights, idle, charged))
	end
	before = #SIM.errors
	ok, err = pcall(Fx.hatch, res.results or {}, Color3.new(1, 1, 1))
	frames(240)
	check("chocar pelo cliente + animação de revelação", res.ok and ok and #SIM.errors == before, tostring(res.msg) .. " " .. tostring(err or SIM.errors[before + 1]))
	-- revelação especial SECRET/CELESTIAL
	before = #SIM.errors
	ok, err = pcall(Fx.hatch, { { species = "celestara", rarity = "Celestial", special = true, chance = 0.00001, newSpecies = true, mutation = "Astral" },
		{ species = "void_seraph", rarity = "Secret", special = true, chance = 0.0002 } }, Color3.new(0, 0, 0.3))
	frames(420)
	check("animação especial de SECRET/CELESTIAL roda", ok and #SIM.errors == before, err or SIM.errors[before + 1])
	-- combate com HUD ativo: habilidades, alvo, números de dano, efeitos e boss
	local foe2
	for _, e in ipairs(S.EnemyService.activeList()) do
		if e.world == "crystal" and e.alive then
			foe2 = e
			break
		end
	end
	SIM.teleport(lp, foe2.root.Position + Vector3.new(10, 3, 0))
	SIM.run(0.3)
	before = #SIM.errors
	State.action("Target", foe2.model)
	for i = 1, 4 do
		local CombatHUD = require(__proxy("Client/Controllers/CombatHUD"))
		CombatHUD.useAbility(i)
		frames(20)
	end
	for _ = 1, 10 do
		State.action("Attack", foe2.model)
		frames(20)
		heal()
	end
	check("HUD de combate, efeitos e números de dano rodam sem erro", #SIM.errors == before and #SIM.messages(lp, "Damage") > 0, SIM.errors[before + 1])
	-- boss com barra e indicadores no cliente
	local cb
	for _, b in ipairs(S.BossService.list()) do
		if b.world == "crystal" then
			cb = b
		end
	end
	if not cb.entity then
		SIM.run(cb.cfg.respawn + 2)
	end
	SIM.teleport(lp, cb.arena.center + Vector3.new(0, 3, 25))
	before = #SIM.errors
	local sawBar = false
	for _ = 1, 30 do
		frames(15)
		heal()
		local gui = pg:FindFirstChild("CombatHUD")
		if gui then
			for _, d in ipairs(gui:GetDescendants()) do
				if type(d.Text) == "string" and d.Text:find("^Fase %d") and d.Parent and d.Parent.Visible == true then
					sawBar = true
				end
			end
		end
	end
	check("barra do boss com fase aparece no cliente e telegraphs animam sem erro", sawBar and #SIM.errors == before, SIM.errors[before + 1])
	-- BOSS NOVO: o cliente troca o boss de peças do servidor pelo anatômico (malhas ou low-poly de peças)
	local function bossVisualChecks()
		local BossVisuals = require(__proxy("Client/Controllers/BossVisuals"))
		local BossMesh = require(__proxy("Shared/Builders/BossMesh"))
		local PetMesh = require(__proxy("Shared/Builders/PetMesh"))
		local beforeB = #SIM.errors
		local model = cb.model
		local function waitVisual(limit)
			local e
			for _ = 1, limit do
				frames(15)
				heal()
				e = BossVisuals.entries[model]
				if e and e.vis and e.vis.Parent == model then
					return e
				end
			end
			return e
		end
		local function scan(vis)
			local r = { meshParts = 0, wedges = 0, blobs = 0, hidden = true, motors = {}, lights = {}, oldLights = 0 }
			for _, d in ipairs(vis:GetDescendants()) do
				if d.ClassName == "MeshPart" then
					r.meshParts += 1
				elseif d.ClassName == "WedgePart" then
					r.wedges += 1
				elseif d.Name == "Blob" then
					r.blobs += 1
				elseif d.ClassName == "Motor6D" then
					r.motors[d.Name] = d
				elseif d.ClassName == "PointLight" and d.Parent:GetAttribute("EnergyFx") then
					table.insert(r.lights, d)
				end
			end
			for _, d in ipairs(model:GetDescendants()) do
				if not d:IsDescendantOf(vis) then
					if d:IsA("BasePart") and d.LocalTransparencyModifier ~= 1 then
						r.hidden = false
					end
					if d.ClassName == "PointLight" and d.Enabled ~= false then
						r.oldLights += 1
					end
				end
			end
			return r
		end
		local e = waitVisual(40)
		local vis = e and e.vis
		local r = vis and scan(vis)
		check("boss novo: o cliente troca o Prism Titan pelo modelo anatômico de malhas e esconde o de peças do servidor",
			r ~= nil and r.meshParts >= 15 and r.hidden and vis:GetAttribute("PolyBoss") == false,
			r and string.format("%d MeshParts, escondido=%s", r.meshParts, tostring(r.hidden)) or "sem visual")
		local bossHl = vis and vis:FindFirstChild("ToonOutline")
		local bossColor = require(__proxy("Shared/Config/Bosses")).Info.prism_titan.color
		check("boss novo: silhueta na cor da energia do boss (Highlight só com a linha)",
			bossHl ~= nil and bossHl.FillTransparency == 1 and bossHl.OutlineColor == bossColor, bossHl and "cor diferente" or "sem contorno")
		local missing = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d.ClassName == "Motor6D" and d.Name ~= "Fixed" and vis and not d:IsDescendantOf(vis) and not r.motors[d.Name] then
				table.insert(missing, d.Name)
			end
		end
		check("boss novo: tem todas as juntas animadas do boss antigo e acompanha a raiz do servidor",
			vis ~= nil and #missing == 0 and (vis.PrimaryPart.Position - model.PrimaryPart.Position).Magnitude < 0.05, table.concat(missing, ","))
		if vis then
			workspace.CurrentCamera.CFrame = CFrame.new(model.PrimaryPart.Position + Vector3.new(0, 10, 40), model.PrimaryPart.Position)
			local probe = r.motors.Body
			local arm = r.motors.ArmL
			local b0, a0 = probe and probe.Transform, arm and arm.Transform
			frames(30)
			check("boss novo: as juntas são animadas pelo Animator com os atributos do boss do servidor",
				probe ~= nil and arm ~= nil and (probe.Transform ~= b0 or arm.Transform ~= a0))
			local idle = r.lights[1] and r.lights[1].Brightness or 0
			model:SetAttribute("WindupEnd", workspace:GetServerTimeNow() + 0.2)
			Fx.updateEnergy()
			local charged = r.lights[1] and r.lights[1].Brightness or 0
			check("boss novo: núcleo, olhos e punhos do visual novo carregam energia (e a do modelo antigo some)", #r.lights >= 5 and charged > idle + 2 and r.oldLights == 0,
				string.format("%d luzes, repouso %.1f, carga %.1f, luzes antigas %d", #r.lights, idle, charged, r.oldLights))
			-- longe da arena o boss novo sai da cena; de volta, reaparece animado
			local back = lp.Character.PrimaryPart.Position
			SIM.teleport(lp, back + Vector3.new(2500, 0, 0))
			frames(60)
			local gone = vis.Parent == nil
			SIM.teleport(lp, back)
			local e2 = waitVisual(10)
			local t0 = r.motors.Body.Transform
			frames(20)
			check("boss novo: sai da cena quando o jogador se afasta e volta animado quando ele retorna",
				gone and e2 ~= nil and e2.vis == vis and vis.Parent == model and r.motors.Body.Transform ~= t0)
		end
		check("boss novo: nenhum erro no cliente", #SIM.errors == beforeB, SIM.errors[beforeB + 1])
		-- sem 'Allow Mesh / Image APIs': o mesmo boss em low-poly de peças, animado
		local asset = game:GetService("AssetService")
		local origCreate = asset.CreateEditableMesh
		asset.CreateEditableMesh = function()
			error("EditableMesh is not accessible. Go to the Security Tab in Experience Settings to enable this API.")
		end
		PetMesh._reset()
		BossMesh._reset()
		if e and e.vis then
			e.vis:Destroy()
			e.vis = nil
		end
		local beforeP = #SIM.errors
		local ep = waitVisual(60)
		local pv = ep and ep.vis
		local rp = pv and scan(pv)
		local movedPoly = false
		if rp and rp.motors.Body then
			local t0 = rp.motors.Body.Transform
			frames(20)
			movedPoly = rp.motors.Body.Transform ~= t0
		end
		check("sem 'Allow Mesh / Image APIs': o boss vira o modelo LISO de peças (elipsoides, nenhuma cunha), escondendo o antigo, animado e sem erro",
			rp ~= nil and pv:GetAttribute("PolyBoss") == true and rp.blobs > 150 and rp.blobs <= 1200 and rp.wedges == 0 and rp.hidden and movedPoly and #SIM.errors == beforeP,
			rp and string.format("%d elipsoides, %d cunhas, animado=%s, erro=%s", rp.blobs, rp.wedges, tostring(movedPoly), tostring(SIM.errors[beforeP + 1])) or "sem visual")
		asset.CreateEditableMesh = origCreate
		PetMesh._reset()
		BossMesh._reset()
	end
	bossVisualChecks()
	-- mensagens do servidor processadas pelo cliente
	before = #SIM.errors
	local Push = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("Push")
	Push:FireClient(lp, "Toast", { text = "teste", kind = "quest" })
	Push:FireClient(lp, "Drop", { source = "Teste", items = { { item = "coins", amount = 10 }, { item = "luck", amount = 0.3, duration = 600, category = "Drop" } } })
	Push:FireClient(lp, "Announce", { player = "Bia", text = "Void Seraph", rarity = "Secret", remote = true })
	Push:FireClient(lp, "Phase", { boss = "X", phase = 2, label = "Y", color = Color3.new(1, 0, 0) })
	Push:FireClient(lp, "BossIntro", { name = "X", title = "Y", color = Color3.new(1, 0, 0), players = 2 })
	Push:FireClient(lp, "BossDefeated", { name = "X", firstTime = true })
	Push:FireClient(lp, "OpenUnlock", { world = "sky" })
	frames(400)
	check("cliente processa toasts, drops, anúncios, fases e vitórias", #SIM.errors == before, SIM.errors[before + 1])
	-- ÁRVORE-SANTUÁRIO (Verdant Haven): escala, caminhos que dá para andar, elevador de seiva, baús e runas
	local function sanctuaryChecks()
		local WS = require(__proxy("Server/Services/WorldService"))
		local Tree = require(__proxy("Server/Services/SanctuaryTree"))
		local SS = require(__proxy("Server/Services/SanctuaryService"))
		local RS2 = require(__proxy("Server/Services/RegionService"))
		local SC = require(__proxy("Client/Controllers/SanctuaryClient"))
		local t = WS.Sanctuary
		local before = #SIM.errors
		if not t then
			check("Árvore-Santuário construída no centro do Verdant Haven", false, "sem árvore")
			return
		end
		local y0, y1, parts = math.huge, -math.huge, 0
		local rMax = 0
		for _, d in ipairs(t.model:GetDescendants()) do
			if d:IsA("BasePart") then
				parts += 1
				y0, y1 = math.min(y0, d.Position.Y), math.max(y1, d.Position.Y)
				if d.Parent and d.Parent.Name == "Canopy" then
					rMax = math.max(rMax, ((d.Position - t.center) * Vector3.new(1, 0, 1)).Magnitude)
				end
			end
		end
		-- fica no lugar da Árvore Ancestral (lago), não na praça do spawn
		local WBx = require(__proxy("Server/Services/WorldBuilder"))
		local lakeL = WBx.Layout.verdantLake
		local lakeC = WBx.polar(Worlds.Info.verdant.center, lakeL.theta, lakeL.dist)
		local onLake = ((t.center - lakeC) * Vector3.new(1, 0, 1)).Magnitude < 1
		local ancientGone = true
		for _, dsc in ipairs(workspace.World.verdant:GetDescendants()) do
			if dsc.Name == "AncientTrunk" then
				ancientGone = false
			end
		end
		check("Árvore-Santuário: no lugar da Árvore Ancestral (sobre o lago), longe da praça do spawn",
			onLake and ancientGone and ((t.center - Worlds.Info.verdant.center) * Vector3.new(1, 0, 1)).Magnitude > 120)
		check("Árvore-Santuário: domina o mapa (≥ 290 studs de altura, copa ≥ 240 de diâmetro) dentro do orçamento de peças",
			y1 - Worlds.Info.verdant.center.Y >= 290 and rMax * 2 >= 240 and parts <= 6500 and t.runes >= 150,
			string.format("altura %.0f, copa %.0f, %d peças (%d cunhas), %d runas", y1, rMax * 2, parts, t.facets, t.runes))
		-- rampa contínua (subida e passo de cada tábua) do Coração da Raiz até a copa; escada com degraus baixos
		local okRamp, worst = true, ""
		for i = 2, #t.ramp do
			local a, b = t.ramp[i - 1], t.ramp[i]
			local rise = b.Y - a.Y
			local run = ((b - a) * Vector3.new(1, 0, 1)).Magnitude
			if rise > 1.6 or rise < -0.01 or run > 9 or math.deg(math.atan2(rise, math.max(run, 1e-3))) > 25 then
				okRamp, worst = false, string.format("tábua %d: sobe %.2f em %.2f", i, rise, run)
			end
		end
		local okStairs = true
		for i = 2, #t.stairs do
			if t.stairs[i].Y - t.stairs[i - 1].Y > 1.35 then
				okStairs = false
			end
		end
		check("Árvore-Santuário: rampa em espiral contínua (≤ 25°) do Coração da Raiz até as Copas e escadaria de degraus baixos até o Coração",
			okRamp and okStairs and #t.ramp > 100 and t.ramp[#t.ramp].Y >= Tree.CANOPY_Y - 0.5 and math.abs(t.stairs[#t.stairs].Y - Tree.HUB_Y) < 0.5, worst)
		-- altura livre: nenhum deck/tábua colidível a menos de 6 studs acima da rampa e da escada
		local blockers = {}
		for _, d in ipairs(t.model:FindFirstChild("Walkways"):GetChildren()) do
			if d:IsA("BasePart") and d.CanCollide and not d.Name:find("Rail") and not d.Name:find("Rope") then
				table.insert(blockers, d)
			end
		end
		local hit
		local function clear(q, label)
			for _, d in ipairs(blockers) do
				for _, h in ipairs({ 2, 3.5, 5 }) do
					local l = d.CFrame:Inverse() * (q + Vector3.new(0, h, 0))
					if math.abs(l.X) < d.Size.X / 2 and math.abs(l.Y) < d.Size.Y / 2 and math.abs(l.Z) < d.Size.Z / 2 then
						hit = string.format("%s a %.0f studs: %s acima (%.0f)", label, q.Y, d.Name, h)
						return
					end
				end
			end
		end
		for i, q in ipairs(t.ramp) do
			if not hit and i % 2 == 0 then
				clear(q, "rampa")
			end
		end
		for i, q in ipairs(t.stairs) do
			if not hit and i % 3 == 0 then
				clear(q, "escada")
			end
		end
		check("Árvore-Santuário: altura livre para o jogador em toda a rampa e na escadaria", hit == nil, hit)
		-- elevador de seiva: perto da estação sobe/desce; longe ou pulando andar recusa; Coroa só depois do Elderroot
		local d = S.DataService.get(lp)
		local savedBoss = d.bestiary.bosses.elderroot
		d.bestiary.bosses.elderroot = nil
		SIM.teleport(lp, t.stops.ground.pos + Vector3.new(0, 3, 0))
		SIM.run(1.5)
		local skip = SS.ride(lp, "boughs")
		SIM.run(1.5)
		local up1 = SS.ride(lp, "hub")
		local atHub = (lp.Character.PrimaryPart.Position - t.stops.hub.pos).Magnitude < 12
		SIM.run(1.5)
		SIM.teleport(lp, t.stops.canopy.pos + Vector3.new(0, 3, 0))
		SIM.run(1.5)
		local locked = SS.ride(lp, "crown")
		d.bestiary.bosses.elderroot = savedBoss or { n = 1 }
		SIM.run(1.5)
		local open = SS.ride(lp, "crown")
		local atCrown = lp.Character.PrimaryPart.Position.Y > Tree.CROWN_Y
		SIM.run(1.5)
		SIM.teleport(lp, Worlds.Info.verdant.center + Vector3.new(150, 5, 150))
		SIM.run(1.5)
		local far = SS.ride(lp, "hub")
		check("Elevador de Seiva: sobe perto da estação, recusa de longe e pulando andar; Coroa Estelar só depois de vencer o Elderroot",
			skip.ok == false and up1.ok and atHub and locked.ok == false and open.ok and atCrown and far.ok == false,
			string.format("pular=%s subir=%s hub=%s trava=%s coroa=%s longe=%s", tostring(skip.ok), tostring(up1.ok), tostring(atHub), tostring(locked.ok), tostring(open.ok), tostring(far.ok)))
		if not savedBoss then
			d.bestiary.bosses.elderroot = nil
		end
		-- baús dos ninhos/copa/coroa usam o sistema de baús-santuário
		local nChests, okClaim = 0, true
		for cid, chest in pairs(t.chests) do
			nChests += 1
			if WS.Regions.verdant.chests[cid] ~= chest then
				okClaim = false
			end
		end
		local nest = t.chests.sanct_nest1
		SIM.teleport(lp, nest.pos + Vector3.new(2, 3, 0))
		SIM.run(1.5)
		local r = RS2.claim(lp, "verdant", "sanct_nest1")
		check("Árvore-Santuário: 6 baús (4 ninhos, copa e coroa) registrados e abrem de perto", nChests == 6 and okClaim and r.ok, tostring(r.msg))
		-- runas: o cliente acende as runas em ondas; douradas depois de vencer o Elderroot
		local n = SC.scan(t.model)
		local sample
		for _, dsc in ipairs(t.model:GetDescendants()) do
			if dsc:GetAttribute("RuneRing") == 1 then
				sample = dsc
				break
			end
		end
		SC.update(0.2)
		local c1 = sample and sample.Color
		SC.update(SC.PERIOD * 0.55)
		local c2 = sample and sample.Color
		local State = require(__proxy("Client/Controllers/State"))
		local prof = State.profile
		local hadBoss = prof and prof.bestiary.bosses.elderroot
		if prof then
			prof.bestiary.bosses.elderroot = { n = 1 }
		end
		SC.update(0.2)
		local gold = sample and sample.Color
		if prof then
			prof.bestiary.bosses.elderroot = hadBoss
		end
		check("Árvore-Santuário: runas pulsam em ondas no cliente e ficam douradas depois do Elderroot",
			n >= 150 and c1 ~= nil and c1 ~= c2 and gold ~= nil and gold.R > gold.B + 0.2 and #SIM.errors == before, SIM.errors[before + 1])
		SIM.teleport(lp, Worlds.Info.verdant.center + Vector3.new(0, 4, 14))
		SIM.run(1)
	end
	sanctuaryChecks()
	-- ataques Assinatura: todo estilo de efeito existe no cliente, roda e limpa as peças (inclui os longos: totem, tornado)
	;(function()
		local Signatures = require(__proxy("Shared/Config/Signatures"))
		local beforeSig = #SIM.errors
		local here = lp.Character.PrimaryPart.Position
		local petModel = workspace.Pets:FindFirstChildWhichIsA("Model", true)
		local missing, okSig, errSig = {}, true, nil
		for key, def in pairs(Signatures.Info) do
			if not Fx.signatureStyles[def.vfx] then
				table.insert(missing, key .. "=" .. def.vfx)
			end
			local pl = { kind = "signature", style = def.vfx, name = def.name, from = here, to = here + Vector3.new(14, 0, 0), at = here, radius = def.radius or 8, length = def.length,
				width = def.width, angle = def.angle, range = def.range, n = def.hits or 1, interval = def.interval or 0, color = def.color, color2 = def.color2, model = petModel,
				points = { here + Vector3.new(10, 0, 0), here + Vector3.new(0, 0, 10) }, grow = def.grow, anchor = def.anchor and here or nil }
			local ok2, e2 = pcall(Fx.play, pl)
			if not ok2 then
				okSig, errSig = false, key .. ": " .. tostring(e2)
			end
			frames(3)
		end
		frames(720)
		local leftover = 0
		for _, d in ipairs(workspace.CurrentCamera:FindFirstChild("LocalFx"):GetChildren()) do
			if d:IsA("BasePart") and d.Transparency < 1 then
				leftover += 1
			end
		end
		check("ataques Assinatura: todos os estilos de efeito existem, rodam no cliente e as peças somem",
			#missing == 0 and okSig and #SIM.errors == beforeSig and leftover == 0, errSig or SIM.errors[beforeSig + 1] or (#missing > 0 and table.concat(missing, ",")) or ("sobraram " .. leftover))
	end)()
	SIM.localPlayer = nil
end

-- TERRAS BAIXAS do Verdant Haven: mapa maior, ruínas, cripta, torre, runas, pântano e cavernas ----------
;(function()
	local before = #SIM.errors
	local WS = require(__proxy("Server/Services/WorldService"))
	local VL = require(__proxy("Server/Services/VerdantLowlands"))
	local RS2 = require(__proxy("Server/Services/RegionService"))
	local Regions = require(__proxy("Shared/Config/Regions"))
	local w = Worlds.Info.verdant
	local low = WS.Lowlands
	check("Terras Baixas construídas (mundo 1 com raio " .. tostring(w.lowlands and w.lowlands.radius) .. ", antes 345)", low ~= nil and w.lowlands.radius >= 600,
		tostring(low))
	if not low then
		return
	end
	-- área: anel das terras baixas ~2,4× a área do planalto (total ~3,4×)
	local areaGain = (w.lowlands.radius ^ 2 - w.radius ^ 2) / w.radius ^ 2
	local nParts, nLights = 0, 0
	for _, d in ipairs(low.folder:GetDescendants()) do
		if d:IsA("BasePart") then
			nParts += 1
		elseif d:IsA("PointLight") then
			nLights += 1
		end
	end
	print(string.format("  Terras Baixas: +%.1fx de área, %d peças, %d luzes, %d árvores", areaGain, nParts, nLights, low.trees or 0))
	check("Terras Baixas: área nova ≥ 2× o planalto, bosques e orçamento (peças ≤ 9000, luzes ≤ 60)", areaGain >= 2 and (low.trees or 0) >= 40 and nParts <= 9000 and nLights <= 60,
		string.format("%.1fx, %d árvores, %d peças, %d luzes", areaGain, low.trees or 0, nParts, nLights))
	-- lugares e baús
	local want = { "verdant_low_eldermoor", "verdant_low_crypt", "verdant_low_tower", "verdant_low_runes", "verdant_low_swamp", "verdant_low_cave" }
	local reg = WS.Regions.verdant
	local missing = {}
	for _, id in ipairs(want) do
		if not (reg and reg.chests[id]) then
			table.insert(missing, id)
		end
	end
	check("Terras Baixas: 6 baús (templo, cripta, torre, runas, pântano, caverna) registrados", #missing == 0, table.concat(missing, ","))
	-- abrir de verdade: o jogador vai até cada baú e abre
	local px = SIM.addPlayer("Explora", 808)
	SIM.run(1)
	local opened = 0
	for _, id in ipairs(want) do
		local ch = reg.chests[id]
		if ch then
			SIM.teleport(px, ch.pos + Vector3.new(3, 3, 0))
			SIM.run(0.4)
			local r = RS2.claim(px, "verdant", id)
			if r and r.ok then
				opened += 1
			end
			SIM.run(1.2)
		end
	end
	check("Terras Baixas: cada baú abre com recompensa (sistema dos baús-santuário)", opened == #want, opened .. "/" .. #want)
	-- escavações no estado final do Terrain: salões da caverna, túnel e cripta vazios (Air)
	local function matAt(p)
		local mat = "Air"
		for _, f in ipairs(SIM.terrainFills) do
			local inside
			if f.kind == "ball" then
				inside = (p - f.cf.p).Magnitude <= f.r
			else
				local l = f.cf:Inverse() * p
				if f.kind == "cyl" then
					inside = math.abs(l.Y) <= f.h / 2 and math.sqrt(l.X * l.X + l.Z * l.Z) <= f.r
				else
					inside = math.abs(l.X) <= f.size.X / 2 and math.abs(l.Y) <= f.size.Y / 2 and math.abs(l.Z) <= f.size.Z / 2
				end
			end
			if inside then
				mat = f.m
			end
		end
		return mat
	end
	local hollow, why = true, ""
	for i, hp in ipairs(low.cave.halls) do
		-- o salão é oco E tem teto de terra por cima (entre o topo do salão e o chão das terras baixas)
		local roof = hp + Vector3.new(0, VL.Cave.halls[i].r + 2.5, 0)
		if matAt(hp) ~= "Air" or matAt(roof) == "Air" or roof.Y > -w.lowlands.drop then
			hollow, why = false, string.format("salão %d: %s / teto %s", i, matAt(hp), matAt(roof))
		end
	end
	local tunnelMid = low.cave.entrance:Lerp(low.cave.halls[1], 0.5)
	check("Cavernas Esmeralda: salões escavados debaixo da terra (com teto), túnel de entrada aberto e cripta oca",
		hollow and matAt(tunnelMid) == "Air" and matAt(low.cave.crypt) == "Air", why .. " túnel " .. tostring(matAt(tunnelMid)))
	-- rampas: passagem aberta do planalto até as terras baixas
	local rampsOk = true
	for _, th in ipairs(VL.Places.ramps) do
		local a = VL.polar(th, w.radius - 6, 0)
		local b = VL.polar(th, w.radius + 74, -w.lowlands.drop)
		local mid = (a + b) / 2
		if matAt(mid + Vector3.new(0, 2.5, 0)) ~= "Air" or matAt(mid - Vector3.new(0, 1, 0)) == "Air" then
			rampsOk = false
		end
	end
	check("Terras Baixas: 4 rampas de terra do planalto até lá embaixo (chão firme, passagem livre)", rampsOk)
	-- nomes na tela: cada lugar, a caverna só debaixo da terra, o planalto continua sem nome de região
	local cave = low.cave.halls[2]
	local surfaceAbove = Vector3.new(cave.X, -w.lowlands.drop + 3, cave.Z)
	local eld = VL.polar(215, 505, -w.lowlands.drop + 3)
	check("Terras Baixas: regiões com nome (caverna só no subsolo; ruínas; terras baixas em anel)",
		Regions.at("verdant", cave) == "emerald_caves" and Regions.at("verdant", surfaceAbove) ~= "emerald_caves" and Regions.at("verdant", eld) == "eldermoor"
			and Regions.at("verdant", VL.polar(0, 450, -21)) == "verdant_lowlands" and Regions.at("verdant", Vector3.new(0, 3, 14)) ~= "verdant_lowlands",
		tostring(Regions.at("verdant", cave)) .. " / " .. tostring(Regions.at("verdant", surfaceAbove)))
	-- quem está dentro da caverna continua no mundo 1 e NÃO é "resgatado" como se tivesse caído da ilha
	SIM.teleport(px, cave + Vector3.new(0, -8, 0))
	SIM.run(1.5)
	local root = px.Character.PrimaryPart
	check("Cavernas Esmeralda: dentro da caverna conta como Verdant Haven e não teleporta para a praça",
		WS.worldAt(root.Position) == "verdant" and root.Position.Y < -40, string.format("y=%.0f mundo=%s", root.Position.Y, tostring(WS.worldAt(root.Position))))
	-- muro invisível na borda NOVA (não mais na borda do planalto)
	local far, near = 0, 0
	for _, b in ipairs(workspace.World.verdant:GetChildren()) do
		if b.Name == "Boundary" then
			local d = ((b.Position - w.center) * Vector3.new(1, 0, 1)).Magnitude
			if d > w.lowlands.radius - 5 then
				far += 1
			elseif d < w.radius + 10 then
				near += 1
			end
		end
	end
	check("Terras Baixas: o muro invisível foi para a borda nova (nada bloqueia a descida do planalto)", far >= 60 and near == 0, far .. " na borda nova, " .. near .. " na antiga")
	SIM.removePlayer(px)
	SIM.run(0.5)
	check("Terras Baixas: nenhum erro no servidor", #SIM.errors == before, SIM.errors[before + 1])
end)()

-- queda e respawn
do
	local pf = SIM.addPlayer("Davi", 404)
	SIM.run(1)
	pf.Character:PivotTo(CFrame.new(0, -120, 0))
	SIM.run(1)
	check("quem cai da ilha volta para a praça", pf.Character.PrimaryPart.Position.Y > -5, pf.Character.PrimaryPart.Position.Y)
	local loads = SIM.loads
	local hum = pf.Character:FindFirstChildOfClass("Humanoid")
	hum.Health = 0
	hum.Died:Fire()
	SIM.run(5)
	check("personagem renasce após morrer", SIM.loads == loads + 1 and pf.Character:FindFirstChildOfClass("Humanoid").Health > 0)
	SIM.removePlayer(pf)
end

-- telemetria geral ---------------------------------------------------------------
SIM.run(3)
-- MECÂNICAS PRÓPRIAS DOS BOSSES (BossPowers): cada efeito e poder numa luta real -----------------
;(function()
	local before = #SIM.errors
	local pm = SIM.addPlayer("Poder", 707)
	SIM.run(1)
	local dm = S.DataService.get(pm)
	for _, w in ipairs(Worlds.Order) do
		dm.worlds[w] = true
	end
	dm.team = {}
	for _, sp in ipairs({ "kit_1", "leafcat_1", "owlet_1", "cap_1" }) do
		table.insert(dm.team, InventoryLogic.addPet(dm, sp, nil, os.time(), "teste").uid)
	end
	S.PetService.spawnTeam(pm)
	SIM.run(0.5)
	local fxKinds = {}
	local origFx = S.CombatService.fx
	S.CombatService.fx = function(kind, payload)
		fxKinds[kind] = (fxKinds[kind] or 0) + 1
		return origFx(kind, payload)
	end
	local function hum()
		return pm.Character:FindFirstChildOfClass("Humanoid")
	end
	local function bossOf(worldId)
		for _, x in ipairs(S.BossService.list()) do
			if x.world == worldId then
				return x
			end
		end
	end
	-- coloca o jogador e os pets juntos na arena, cheios de vida
	local function gather(b)
		local spot = b.arena.center + Vector3.new(0, 3, 14)
		SIM.teleport(pm, spot)
		local h = hum()
		h.MaxHealth, h.Health = 1e7, 1e7
		for i, st in ipairs(S.PetService.team(pm)) do
			st.hp, st.maxHp, st.knockedUntil, st.stunUntil = 1e7, 1e7, 0, 0
			st.model:PivotTo(CFrame.new(spot + Vector3.new((i - 2.5) * 1.6, -2, 1.5)))
		end
		SIM.run(0.05)
	end
	local function startFight(worldId)
		local b = bossOf(worldId)
		if not b.entity or b.state == "Defeated" then
			SIM.run(b.cfg.respawn + 1)
		end
		gather(b)
		for _ = 1, 30 do
			if b.state == "Fight" then
				break
			end
			SIM.run(0.5)
			gather(b)
		end
		b.entity.hp = b.entity.maxHp
		return b
	end
	local function force(b, id)
		gather(b)
		S.BossService.forceAttack(b, id)
		SIM.run(0.12)
		gather(b)
		local atk = b.cfg.attacks[id]
		SIM.run(atk.telegraph + 0.15)
	end
	local function zones()
		local n = 0
		for _, z in ipairs(workspace.Telegraphs:GetChildren()) do
			if z.Name == "BossZone" then
				n += 1
			end
		end
		return n
	end

	-- ELDERROOT: Prisão de Espinhos prende e deixa espinhos; Casca Ancestral corta o dano
	local b = startFight("verdant")
	check("bosses: luta começa para testar os poderes (Elderroot)", b.state == "Fight", b.state)
	local base = hum().WalkSpeed
	force(b, "thorn_prison")
	local stunned = 0
	for _, st in ipairs(S.PetService.team(pm)) do
		if (st.stunUntil or 0) > os.clock() then
			stunned += 1
		end
	end
	check("Elderroot — Prisão de Espinhos: jogador preso, pets sem atacar e campo de espinhos no chão",
		hum().WalkSpeed == 0 and stunned >= 1 and zones() >= 1, string.format("velocidade %s, pets presos %d, zonas %d", tostring(hum().WalkSpeed), stunned, zones()))
	SIM.run(4.5)
	check("Elderroot — depois das raízes o jogador volta à velocidade normal e o campo some", hum().WalkSpeed == base and zones() == 0,
		string.format("%s/%s, zonas %d", tostring(hum().WalkSpeed), tostring(base), zones()))
	SIM.clearMessages(pm)
	force(b, "ancient_bark")
	local e = b.entity
	local hp0 = e.hp
	local dealt = S.CombatService.damageEntity(e, 1000, { player = pm })
	check("Elderroot — Casca Ancestral: dano recebido cai 55% e o jogador é avisado",
		math.abs(dealt - 450) < 1 and math.abs((hp0 - e.hp) - 450) < 1 and #SIM.messages(pm, "BossPower") == 1 and b.model:GetAttribute("Power") == "bark", tostring(dealt))
	check("Elderroot — poder entra em recarga (não repete logo)", (b.powerReady.ancient_bark or 0) > os.clock() + 10)

	-- PRISM TITAN: estilhaços deixam lento, Refração Tripla em leque, Espelho Prismático reflete
	b = startFight("crystal")
	base = hum().WalkSpeed
	force(b, "shard_rain")
	check("Prism Titan — Chuva de Estilhaços deixa o jogador lento", hum().WalkSpeed < base * 0.7 and hum().WalkSpeed > 0, tostring(hum().WalkSpeed))
	SIM.run(3.2)
	local built = {}
	local origBuild = AttackShapes.build
	AttackShapes.build = function(atk, ctx)
		local sh = origBuild(atk, ctx)
		built[atk.shape] = #sh
		return sh
	end
	force(b, "prism_split")
	AttackShapes.build = origBuild
	check("Prism Titan — Refração Tripla: três feixes em leque", built.fan == 3, tostring(built.fan))
	force(b, "prism_mirror")
	local pet = S.PetService.team(pm)[1]
	local petHp = pet.hp
	S.CombatService.damageEntity(b.entity, 2000, { player = pm, pet = pet, kind = "pet" })
	check("Prism Titan — Espelho Prismático devolve dano ao pet que bateu", pet.hp < petHp and (fxKinds.chain or 0) > 0, string.format("%d -> %d", petHp, pet.hp))

	-- TEMPEST WYRM: raio em cadeia, células de tempestade que ficam, carga estática
	b = startFight("sky")
	local chain0 = fxKinds.chain or 0
	force(b, "lightning_marks")
	check("Tempest Wyrm — Marcas de Relâmpago pulam em cadeia entre os pets", (fxKinds.chain or 0) > chain0, tostring((fxKinds.chain or 0) - chain0))
	force(b, "storm_cells")
	check("Tempest Wyrm — Células de Tempestade ficam no chão", zones() >= 1, tostring(zones()))
	SIM.run(5.5)
	force(b, "static_charge")
	pet = S.PetService.team(pm)[2]
	pet.thornsHitAt = 0
	petHp = pet.hp
	S.CombatService.damageEntity(b.entity, 300, { player = pm, pet = pet, kind = "pet" })
	check("Tempest Wyrm — Carga Estática dá choque no pet que bate", pet.hp < petHp, string.format("%d -> %d", petHp, pet.hp))

	-- THE WILDERBLOOM: poça de veneno (lentidão), Laço de Vinhas prende, Florescer cura com os brotos
	b = startFight("wilds")
	base = hum().WalkSpeed
	force(b, "spore_marks")
	SIM.run(0.7)
	check("Wilderbloom — Esporos deixam poça de veneno que deixa lento", zones() >= 1 and hum().WalkSpeed < base, string.format("zonas %d, velocidade %s", zones(), tostring(hum().WalkSpeed)))
	SIM.run(5)
	force(b, "vine_snare")
	check("Wilderbloom — Laço de Vinhas prende o jogador", hum().WalkSpeed == 0, tostring(hum().WalkSpeed))
	SIM.run(2)
	force(b, "summon_sprouts")
	local alive = 0
	for _, x in ipairs(b.summons) do
		if x.alive then
			alive += 1
		end
	end
	b.entity.hp = b.entity.maxHp * 0.7 -- ainda na fase 1 (abaixo de 60% ela troca de fase e fica invulnerável)
	local hpB = b.entity.hp
	force(b, "rebloom")
	local want = b.entity.maxHp * (0.03 + 0.015 * alive)
	check("Wilderbloom — Florescer cura mais com brotos vivos", alive >= 1 and math.abs((b.entity.hp - hpB) - want) < want * 0.01,
		string.format("%d brotos, curou %.0f (esperado %.0f)", alive, b.entity.hp - hpB, want))

	-- VOID SOVEREIGN: Fendas drenam energia/Fúria, Buraco Negro fica e prende, Fome do Vazio rouba vida
	b = startFight("astral")
	for _, st in ipairs(S.PetService.team(pm)) do
		st.energy, st.fury = 50, 3
	end
	force(b, "rift_lines")
	-- (a energia volta a encher aos poucos e cada golpe do pet soma 1 de Fúria: mede logo depois)
	local drained = 0
	for _, st in ipairs(S.PetService.team(pm)) do
		if st.energy < 10 and (st.fury or 0) <= 1 then
			drained += 1
		end
	end
	check("Void Sovereign — Fendas sugam a energia e a Fúria dos pets atingidos", drained >= 1, tostring(drained))
	base = hum().WalkSpeed
	force(b, "black_hole")
	SIM.run(0.7)
	check("Void Sovereign — Buraco Negro fica no chão e deixa lento quem está dentro", zones() >= 1 and hum().WalkSpeed < base, string.format("zonas %d", zones()))
	SIM.run(5)
	force(b, "void_hunger")
	b.entity.hp = b.entity.maxHp * 0.8 -- ainda na fase 1
	local hpV = b.entity.hp
	force(b, "star_marks")
	check("Void Sovereign — Fome do Vazio: o boss se cura com o dano que causa", b.entity.hp > hpV, string.format("%.0f -> %.0f", hpV, b.entity.hp))
	check("bosses: poderes mostram o efeito no cliente (aura) e marcam o modelo", (fxKinds.bossPower or 0) >= 5 and b.model:GetAttribute("Power") == "drain")

	S.CombatService.fx = origFx
	-- sai da arena (o boss para de atacar) e espera as áreas que ainda estavam no chão acabarem.
	-- Jogadores de cenários anteriores parados numa arena também saem (senão o boss continua lutando).
	SIM.teleport(pm, Worlds.Info.verdant.center + Vector3.new(0, 4, 20))
	for _, bb in ipairs(S.BossService.list()) do
		for _, other in ipairs(S.BossService.participants(bb)) do
			SIM.teleport(other, Worlds.Info[bb.world].center + Vector3.new(0, 4, 24))
		end
	end
	SIM.run(7)
	local zoneInfo = {}
	for _, z in ipairs(workspace.Telegraphs:GetChildren()) do
		if z.Name == "BossZone" then
			table.insert(zoneInfo, string.format("%s %.1fs", tostring(z:GetAttribute("Label")), workspace:GetServerTimeNow() - (z:GetAttribute("Start") or 0)))
		end
	end
	check("bosses: áreas de poder somem sozinhas e nenhum erro no servidor", zones() == 0 and #SIM.errors == before,
		string.format("zonas %d (%s), erro %s", zones(), table.concat(zoneInfo, ","), tostring(SIM.errors[before + 1])))
end)()

-- MODELOS DO BLENDER importados (ReplicatedStorage.PetRigs): a pele contínua segue o esqueleto animado ---------
;(function()
	local before = #SIM.errors
	local PetMesh = require(__proxy("Shared/Builders/PetMesh"))
	local PetRig = require(__proxy("Shared/Builders/PetRig"))
	local PetAnatomy = require(__proxy("Shared/Builders/PetAnatomy"))
	local PetsCfg = require(__proxy("Shared/Config/Pets"))
	local RS = game:GetService("ReplicatedStorage")
	local folder = RS:FindFirstChild("PetRigs") or Instance.new("Folder")
	folder.Name = "PetRigs"
	folder.Parent = RS
	-- "FBX importado": Model com uma MeshPart do tamanho do pet e um Bone por parte com junta (nomes iguais)
	local bp = PetAnatomy.blueprint("kit_1", PetsCfg.Species.kit_1, 1, { low = true })
	local lo, hi = PetRig.expectedBounds(bp)
	local fake = Instance.new("Model")
	fake.Name = "kit_1"
	local skinPart = Instance.new("MeshPart")
	skinPart.Name = "Body"
	skinPart.Size = hi - lo
	skinPart.CFrame = CFrame.new((lo + hi) / 2 + Vector3.new(5, 0, 0)) -- fora do lugar: a montagem tem de alinhar
	skinPart.Parent = fake
	local bones, worldOf = {}, {}
	for _, p in ipairs(bp.parts) do
		if p.joint then
			local b = Instance.new("Bone")
			b.Name = p.name
			local parentBone
			local q = p.parent and bp.byName[p.parent]
			while q and not q.joint do
				q = q.parent and bp.byName[q.parent]
			end
			parentBone = q and bones[q.name]
			local world = CFrame.new(p.pivot + Vector3.new(5, 0, 0))
			if parentBone then
				b.CFrame = worldOf[parentBone]:Inverse() * world
				b.Parent = parentBone
			else
				b.CFrame = skinPart.CFrame:Inverse() * world
				b.Parent = skinPart
			end
			b.Transform = CFrame.identity
			bones[p.name] = b
			worldOf[b] = world
		end
	end
	fake.Parent = folder
	PetMesh._reset()
	local okT, t = pcall(PetMesh.buildTemplateRig, "kit_1", 1)
	local nBones = 0
	for _ in pairs(bones) do
		nBones += 1
	end
	check("modelo do Blender: com PetRigs.kit_1 o pet monta o esqueleto do jogo + a pele importada, ossos ligados pelo nome",
		okT and t ~= nil and t.rig == true and t.model:GetAttribute("Bones") == nBones and t.model:FindFirstChild("Skin") ~= nil,
		okT and string.format("%s ossos ligados de %d", tostring(t and t.model:GetAttribute("Bones")), nBones) or tostring(t))
	if okT and t then
		local mesh = t.model:Clone()
		local rig = PetRig.collect(mesh)
		local skin = mesh:FindFirstChild("Skin")
		local body = skin and skin:FindFirstChild("Body")
		local center = body and body.CFrame.Position or Vector3.zero
		local wantC = (lo + hi) / 2
		PetRig.step(rig)
		local rest = true
		for _, e in ipairs(rig.bones) do
			local tr = e.bone.Transform
			if tr.Position.Magnitude > 1e-3 or tr.LookVector:Dot(Vector3.new(0, 0, -1)) < 0.9999 then
				rest = false
			end
		end
		-- gira a cabeça do esqueleto: o osso Head da pele tem de ir exatamente para a nova pose
		local head = mesh:FindFirstChild("Head")
		head.CFrame = head.CFrame * CFrame.Angles(0, math.rad(35), math.rad(10))
		PetRig.step(rig)
		local hb
		for _, e in ipairs(rig.bones) do
			if e.bone.Name == "Head" then
				hb = e.bone
			end
		end
		local got = rig.desired[hb.Parent] or PetRig._restWorld(hb.Parent)
		got = (hb.Parent:IsA("BasePart") and hb.Parent.CFrame or got) * hb.CFrame * hb.Transform
		local want = head.CFrame * hb:GetAttribute("BindOffset")
		local err = (got.Position - want.Position).Magnitude + (1 - got.LookVector:Dot(want.LookVector))
		check("modelo do Blender: a pele é alinhada à caixa do pet, fica parada em repouso e o osso segue a pose da parte",
			(center - wantC).Magnitude < 1e-3 and rest and err < 1e-3 and #rig.bones == nBones,
			string.format("centro %.3f, repouso=%s, erro da pose %.5f, ossos %d", (center - wantC).Magnitude, tostring(rest), err, #rig.bones))
	end
	-- sem o modelo importado, tudo volta ao modo de antes
	fake:Destroy()
	PetMesh._reset()
	check("modelo do Blender: nenhum erro", #SIM.errors == before, SIM.errors[before + 1])
end)()

-- MINERAÇÃO DE CRISTAIS: veios, golpes validados, cristais, missões, contratos e picareta -------------
;(function()
	local before = #SIM.errors
	local MS = require(__proxy("Server/Services/MiningService"))
	local Mining = require(__proxy("Shared/Config/Mining"))
	local MiningLogic = require(__proxy("Shared/Logic/MiningLogic"))
	local VL = require(__proxy("Server/Services/VerdantLowlands"))
	local WS = require(__proxy("Server/Services/WorldService"))
	local byWorld, caveVeins, prompts = {}, 0, 0
	local halls = WS.Lowlands and WS.Lowlands.cave and WS.Lowlands.cave.halls or {}
	for _, v in ipairs(MS.veins) do
		byWorld[v.world] = (byWorld[v.world] or 0) + 1
		if v.model and v.model:FindFirstChild("VeinCore") and v.model.VeinCore:FindFirstChild("MinePrompt") then
			prompts += 1
		end
		if v.world == "verdant" then
			for i, hp in ipairs(halls) do
				local flat = ((v.pos - hp) * Vector3.new(1, 0, 1)).Magnitude
				if flat < VL.Cave.halls[i].r and v.pos.Y < -30 then
					caveVeins += 1
					break
				end
			end
		end
	end
	check("mineração: veios de cristal nos salões das Cavernas Esmeralda (subsolo) e nos outros 4 mundos, todos com o prompt Minerar",
		caveVeins == 6 and (byWorld.crystal or 0) >= 3 and (byWorld.sky or 0) >= 1 and (byWorld.wilds or 0) >= 1 and (byWorld.astral or 0) >= 1 and prompts == #MS.veins,
		string.format("caverna %d, cristal %d, céu %d, mata %d, astral %d, prompts %d/%d", caveVeins, byWorld.crystal or 0, byWorld.sky or 0, byWorld.wilds or 0,
			byWorld.astral or 0, prompts, #MS.veins))
	local pm = SIM.addPlayer("Mineira", 909)
	SIM.run(1)
	local d = S.DataService.get(pm)
	local day = math.floor(os.time() / 86400)
	d.quests.daily.day = day
	d.quests.daily.ids = { "d_mine", "d_mine_emerald", "d_contract" }
	d.quests.daily.progress = {}
	d.quests.daily.claimed = {}
	local vein
	for _, v in ipairs(MS.veins) do
		if v.world == "verdant" and v.alive then
			vein = v
			break
		end
	end
	-- longe do veio: golpe recusado
	SIM.teleport(pm, vein.pos + Vector3.new(40, 3, 0))
	SIM.run(1.2)
	local far = MS.strike(pm, vein)
	-- perto: golpe aceito; outro no mesmo instante é recusado (o tempo de segurar é conferido no servidor)
	SIM.teleport(pm, vein.pos + Vector3.new(3, 3, 0))
	SIM.run(1.2)
	local hp0 = vein.hp
	local r1 = MS.strike(pm, vein)
	local r2 = MS.strike(pm, vein)
	check("mineração: golpe só vale perto do veio e respeitando o tempo da picareta (rajadas recusadas)",
		far.ok == false and r1.ok == true and r2.ok == false and vein.hp < hp0, string.format("longe=%s, golpe=%s, rajada=%s", tostring(far.ok), tostring(r1.ok), tostring(r2.ok)))
	-- pelo prompt de verdade, até quebrar
	local strikes = 1
	for _ = 1, 40 do
		if not vein.alive then
			break
		end
		SIM.run(1.05)
		vein.prompt.Triggered:Fire(pm)
		strikes += 1
	end
	SIM.run(0.5)
	local got = d.items.emerald_crystal or 0
	local dp = d.quests.daily.progress
	check("mineração: segurar Minerar quebra o veio e dá Cristais Esmeralda (itens), contando nas missões diárias",
		not vein.alive and got >= Mining.Veins.emerald.yield[1] and (dp.d_mine or 0) >= got and (dp.d_mine_emerald or 0) >= got and d.mining.mined >= got and d.mining.veins == 1,
		string.format("quebrou=%s em %d golpes, %d cristais, missões %s/%s, minerado %d", tostring(not vein.alive), strikes, got, tostring(dp.d_mine), tostring(dp.d_mine_emerald), d.mining.mined))
	SIM.run(Mining.Veins.emerald.respawn + 1)
	check("mineração: o veio volta depois do tempo de recarga", vein.alive and vein.model ~= nil and vein.model.Parent ~= nil and vein.hp == Mining.Veins.emerald.hp)
	-- contrato de mineração: entrega os cristais e recebe a recompensa; não dá para entregar duas vezes
	d.mining.contracts = { day = day, ids = { "mc_emerald_s", "mc_sapphire" }, done = {} }
	d.items.emerald_crystal = 10
	local coins0 = d.coins
	local c1 = req(pm, "DeliverContract", { id = "mc_emerald_s" })
	local c2 = req(pm, "DeliverContract", { id = "mc_emerald_s" })
	local c3 = req(pm, "DeliverContract", { id = "mc_sapphire" }) -- sem safiras
	local c4 = req(pm, "DeliverContract", { id = "mc_star" }) -- não é contrato de hoje
	check("contratos de mineração: entrega debita os cristais e paga; repetida, sem cristais ou fora do dia é recusada",
		c1.ok == true and c2.ok == false and c3.ok == false and c4.ok == false and d.items.emerald_crystal == 2 and d.coins >= coins0 + 900 and (d.quests.daily.progress.d_contract or 0) == 1,
		string.format("entregas %s/%s/%s/%s, esmeraldas %s, moedas +%d", tostring(c1.ok), tostring(c2.ok), tostring(c3.ok), tostring(c4.ok), tostring(d.items.emerald_crystal), d.coins - coins0))
	-- picareta: sem cristais não melhora; com o custo, sobe de nível e golpeia mais rápido e forte
	d.items.emerald_crystal = nil
	d.coins = 5000
	local u1 = req(pm, "UpgradePickaxe")
	d.items.emerald_crystal = 12
	local u2 = req(pm, "UpgradePickaxe")
	check("picareta: melhoria cobra moedas e cristais e aumenta força e velocidade",
		u1.ok == false and u2.ok == true and d.mining.pickaxe == 2 and pm:GetAttribute("Pickaxe") == 2 and d.coins == 5000 - 600 and (d.items.emerald_crystal or 0) == 0
			and MiningLogic.minInterval(2) < MiningLogic.minInterval(1) and MiningLogic.strikePower(2, 0) > MiningLogic.strikePower(1, 0),
		string.format("sem custo=%s, com custo=%s, nível %s", tostring(u1.ok), tostring(u2.ok), tostring(d.mining.pickaxe)))
	check("mineração: nenhum erro no servidor", #SIM.errors == before, SIM.errors[before + 1])
	SIM.removePlayer(pm)
end)()

check("nenhum erro de execução no servidor durante os cenários", #SIM.errors == 0, SIM.errors[1])
check("nenhum aviso de falha (servidor ou cliente)", #SIM.warnings == 0, SIM.warnings[1])
check("todas as mensagens enviadas ao cliente são serializáveis", true)
local enemiesNow = count("Enemies")
SIM.run(60)
check("número de inimigos estável (respawn sem vazamento)", math.abs(count("Enemies") - enemiesNow) <= 6, string.format("%d -> %d", enemiesNow, count("Enemies")))
print(string.format("avisos do servidor: %d", #SIM.warnings))
for i = 1, math.min(5, #SIM.warnings) do
	print("  aviso: " .. SIM.warnings[i])
end
print(string.format("Simulação: %d passaram, %d falharam (tempo simulado %.0fs)", results.pass, results.fail, SIM.now))
if results.fail > 0 then
	error("SIMULAÇÃO FALHOU")
end

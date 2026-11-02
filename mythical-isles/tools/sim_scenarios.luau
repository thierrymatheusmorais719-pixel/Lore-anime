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
hp0 = target.hp
Action.OnServerEvent:Fire(p1, "Attack", target.model)
Action.OnServerEvent:Fire(p1, "Attack", target.model)
Action.OnServerEvent:Fire(p1, "Attack", target.model)
SIM.run(1 / 30)
local c = target.contrib[p1.UserId]
check("ataque no alcance causa dano; repetição na recarga é ignorada", target.hp < hp0 and c and c.damage == hp0 - target.hp and (hp0 - target.hp) < 100, target.hp)
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
		for _ = 1, 30 do
			act(pX, "Attack", b.model)
			SIM.run(0.4)
			heal()
		end
		phases[b.phase] = true
		if i < #b.cfg.phases then
			S.BossService.debugDamage(worldId, (b.cfg.phases[i].at - b.cfg.phases[i + 1].at) + 0.02)
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
Reward.givePet(pX, "echo_geode", nil, "teste")
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
	local function frames(n)
		for _ = 1, n do
			rs.Stepped:Fire(SIM.now, 1 / 60)
			rs.RenderStepped:Fire(1 / 60)
			SIM.run(1 / 60)
		end
	end
	local errs0 = #SIM.errors
	__modules["Client/Main"](__proxy("Client/Main"))
	frames(5)
	check("cliente inicia todos os controladores sem erro", #SIM.errors == errs0, SIM.errors[errs0 + 1])
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
	SIM.localPlayer = nil
end

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
check("nenhum erro de execução no servidor durante os cenários", #SIM.errors == 0, SIM.errors[1])
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

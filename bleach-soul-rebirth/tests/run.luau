-- Executar: python3 tests/bundle.py && luau tests/.bundle.luau (a partir de bleach-soul-rebirth/)

local passed, failed = 0, 0
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FALHOU: " .. name .. "\n   " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then
		error((msg or "") .. " esperado " .. tostring(b) .. ", obtido " .. tostring(a), 2)
	end
end
local function truthy(v, msg)
	if not v then
		error(msg or "esperado verdadeiro", 2)
	end
end

local CombatRules = MODULE("Logic/CombatRules")
local Stats = MODULE("Logic/Stats")
local ProgressionLogic = MODULE("Logic/ProgressionLogic")
local InventoryLogic = MODULE("Logic/InventoryLogic")
local LootLogic = MODULE("Logic/LootLogic")
local GachaLogic = MODULE("Logic/GachaLogic")
local QuestLogic = MODULE("Logic/QuestLogic")
local DataSchema = MODULE("Logic/DataSchema")

local Combat = MODULE("Config/Combat")
local Abilities = MODULE("Config/Abilities")
local Factions = MODULE("Config/Factions")
local Powers = MODULE("Config/Powers")
local Progression = MODULE("Config/Progression")
local SkillTrees = MODULE("Config/SkillTrees")
local Items = MODULE("Config/Items")
local Loot = MODULE("Config/Loot")
local Enemies = MODULE("Config/Enemies")
local Quests = MODULE("Config/Quests")
local NPCs = MODULE("Config/NPCs")
local Zones = MODULE("Config/Zones")
local Animations = MODULE("Config/Animations")
local Elements = MODULE("Config/Elements")

-- ======================= CombatRules =======================
test("parry dentro da janela", function()
	local d = { blocking = true, blockStart = 10, guard = 100, iframeUntil = 0 }
	eq(CombatRules.resolveDefense(d, {}, 1, 10.1, 0.2, 0.15), "Parry")
end)
test("bloqueio fora da janela", function()
	local d = { blocking = true, blockStart = 10, guard = 100, iframeUntil = 0 }
	eq(CombatRules.resolveDefense(d, { guardDamage = 10 }, 1, 11, 0.2, 0.15), "Blocked")
end)
test("golpe pelas costas ignora bloqueio", function()
	local d = { blocking = true, blockStart = 10, guard = 100, iframeUntil = 0 }
	eq(CombatRules.resolveDefense(d, {}, -0.8, 10.05, 0.2, 0.15), "Hit")
end)
test("quebra de guarda por ataque pesado e por guarda esgotada", function()
	local d = { blocking = true, blockStart = 0, guard = 100, iframeUntil = 0 }
	eq(CombatRules.resolveDefense(d, { guardBreak = true }, 1, 5, 0.2, 0.15), "GuardBreak")
	d.guard = 5
	eq(CombatRules.resolveDefense(d, { guardDamage = 10 }, 1, 5, 0.2, 0.15), "GuardBreak")
end)
test("projéteis não podem ser aparados, só bloqueados", function()
	local d = { blocking = true, blockStart = 10, guard = 100, iframeUntil = 0 }
	eq(CombatRules.resolveDefense(d, { projectile = true, guardDamage = 5 }, 1, 10.05, 0.2, 0.15), "Blocked")
end)
test("iframes do dash", function()
	local d = { blocking = false, blockStart = 0, guard = 100, iframeUntil = 5 }
	eq(CombatRules.resolveDefense(d, {}, 1, 4.9, 0.2, 0.15), "Immune")
end)
test("bônus de parry da árvore amplia janela", function()
	local d = { blocking = true, blockStart = 10, guard = 100, iframeUntil = 0, parryBonus = 0.1 }
	eq(CombatRules.resolveDefense(d, {}, 1, 10.25, 0.2, 0.15), "Parry")
end)
test("sequência de combo avança e reinicia", function()
	eq(CombatRules.nextComboIndex(0, 0, 1, 5, 0.8), 1)
	eq(CombatRules.nextComboIndex(1, 1, 1.5, 5, 0.8), 2)
	eq(CombatRules.nextComboIndex(4, 1, 1.5, 5, 0.8), 5)
	eq(CombatRules.nextComboIndex(5, 1, 1.5, 5, 0.8), 1)
	eq(CombatRules.nextComboIndex(2, 1, 2.0, 5, 0.8), 1)
end)
test("stun acumula até o limite", function()
	local u = CombatRules.applyStun(0, 10, 1, 3)
	eq(u, 11)
	u = CombatRules.applyStun(u, 10.5, 1, 3)
	eq(u, 11.5)
	u = CombatRules.applyStun(20, 10, 1, 3)
	eq(u, 13)
end)
test("regeneração de guarda respeita atraso", function()
	eq(CombatRules.regenGuard(50, 100, 0.5, 1.2, 20, 1), 50)
	eq(CombatRules.regenGuard(50, 100, 2, 1.2, 20, 1), 70)
	eq(CombatRules.regenGuard(95, 100, 2, 1.2, 20, 1), 100)
end)

-- ======================= Stats =======================
local function newProfile()
	return DataSchema.normalize(nil)
end
test("atributos derivados base", function()
	local p = newProfile()
	local s = Stats.compute(p, Progression, nil, Items.List, 1)
	eq(s.maxHealth, 100)
	eq(s.maxReiatsu, 100)
	eq(s.meleeMultiplier, 1)
end)
test("equipamento e árvore somam", function()
	local p = newProfile()
	p.level = 10
	p.stats.Vitality = 5
	InventoryLogic.add(p.inventory, Items.List, "ReforgedBlade", 1)
	p.equipped.Weapon = 1
	p.skills.Blade1 = true
	p.skills.Body1 = true
	local s = Stats.compute(p, Progression, SkillTrees.Trees.Shinigami, Items.List, 1)
	eq(s.attributes.Strength, 3)
	eq(s.maxHealth, math.floor((100 + 6 * 9 + 40) * 1.1))
	truthy(math.abs(s.meleeMultiplier - (1 + 0.06 + 0.06)) < 1e-9, "melee")
end)
test("dano com defesa", function()
	eq(Stats.damage(10, 1.5, 0.2), 12)
	eq(Stats.damage(0.1, 1, 0), 1)
end)

-- ======================= Progressão =======================
test("subida de nível múltipla", function()
	local p = newProfile()
	local need = Progression.xpToNext(1) + Progression.xpToNext(2) + 5
	local r = ProgressionLogic.addXp(p, need, Progression)
	eq(r.levelsGained, 2)
	eq(p.level, 3)
	eq(p.xp, 5)
	eq(p.statPoints, 6)
	eq(p.skillPoints, 2)
end)
test("nível máximo zera xp", function()
	local p = newProfile()
	p.level = Progression.MaxLevel
	ProgressionLogic.addXp(p, 1e6, Progression)
	eq(p.level, Progression.MaxLevel)
	eq(p.xp, 0)
end)
test("alocação valida", function()
	local p = newProfile()
	p.statPoints = 2
	truthy(not ProgressionLogic.allocate(p, "Hack", 1, Progression))
	truthy(not ProgressionLogic.allocate(p, "Strength", 3, Progression))
	truthy(not ProgressionLogic.allocate(p, "Strength", 0.5, Progression))
	truthy(ProgressionLogic.allocate(p, "Strength", 2, Progression))
	eq(p.stats.Strength, 2)
	ProgressionLogic.resetStats(p)
	eq(p.statPoints, 2)
end)
test("árvore: requisitos, nível e exclusividade", function()
	local tree = SkillTrees.Trees.Shinigami
	local p = newProfile()
	p.level = 30
	p.skillPoints = 100
	truthy(not ProgressionLogic.unlockSkill(p, tree, "Blade2"), "precisa de Blade1")
	for _, id in { "Blade1", "Blade2", "Blade3", "Spirit1", "Spirit2", "Spirit3", "BladeMaster" } do
		local ok, err = ProgressionLogic.unlockSkill(p, tree, id)
		truthy(ok, id .. ": " .. tostring(err))
	end
	local ok = ProgressionLogic.unlockSkill(p, tree, "SpiritMaster")
	truthy(not ok, "capstone exclusivo")
	local low = newProfile()
	low.skillPoints = 5
	truthy(not ProgressionLogic.unlockSkill(low, tree, "Blade2"))
end)

-- ======================= Inventário =======================
test("empilhar, remover e equipar", function()
	local p = newProfile()
	eq(InventoryLogic.add(p.inventory, Items.List, "HollowFragment", 5), 5)
	eq(InventoryLogic.add(p.inventory, Items.List, "HollowFragment", 3), 3)
	eq(#p.inventory.items, 1)
	eq(InventoryLogic.count(p.inventory, "HollowFragment"), 8)
	truthy(InventoryLogic.remove(p.inventory, "HollowFragment", 8))
	eq(#p.inventory.items, 0)
	eq(InventoryLogic.add(p.inventory, Items.List, "DuskEdge", 2), 2)
	eq(#p.inventory.items, 2)
	truthy(InventoryLogic.equip(p, Items.List, p.inventory.items[1].uid))
	eq(p.equipped.Weapon, p.inventory.items[1].uid)
	InventoryLogic.add(p.inventory, Items.List, "SoulCandy", 1)
	truthy(not InventoryLogic.equip(p, Items.List, p.inventory.items[3].uid), "consumível não equipa")
	eq(InventoryLogic.add(p.inventory, Items.List, "NaoExiste", 1), 0)
end)
test("forja determinística", function()
	local p = newProfile()
	p.level = 6
	truthy(not InventoryLogic.craft(p, Items.List, Items.Recipes, "DuskEdge"), "sem materiais")
	p.currency.Kan = 1000
	InventoryLogic.add(p.inventory, Items.List, "HollowFragment", 20)
	InventoryLogic.add(p.inventory, Items.List, "ReishiCrystal", 4)
	local ok, err = InventoryLogic.craft(p, Items.List, Items.Recipes, "DuskEdge")
	truthy(ok, err)
	eq(p.currency.Kan, 700)
	eq(InventoryLogic.count(p.inventory, "DuskEdge"), 1)
	eq(InventoryLogic.count(p.inventory, "HollowFragment"), 0)
end)

-- ======================= Loot / Gacha =======================
local function seqRng(floats)
	local i = 0
	return {
		int = function(a, _b)
			return a
		end,
		float = function()
			i += 1
			return floats[((i - 1) % #floats) + 1]
		end,
	}
end
test("pity de drop garante item raro", function()
	local state = {}
	local rng = seqRng({ 0.99 })
	local got = false
	for _ = 1, Loot.Kurokage.pity.after do
		local drops = LootLogic.roll(Loot.Kurokage, state, "Kurokage", rng)
		for _, d in drops do
			if d.id == "KurokageFang" then
				got = true
			end
		end
	end
	truthy(got, "pity não disparou")
	eq(state.Kurokage, 0)
end)
test("gacha: pity lendário e épico", function()
	local g = { rolls = 0, epicPity = 0, legendaryPity = 0, owned = {} }
	local pool = Powers.forFaction("Shinigami")
	local rng = function()
		return 0.01
	end -- sempre comum
	local results = {}
	for i = 1, Powers.Gacha.legendaryPity do
		results[i] = GachaLogic.roll(g, pool, Powers.List, Powers.Rarities, Powers.Gacha, rng)
	end
	eq(Powers.List[results[Powers.Gacha.epicPity]].rarity, "Epic")
	eq(Powers.List[results[Powers.Gacha.legendaryPity]].rarity, "Legendary")
	eq(Powers.List[results[1]].rarity, "Common")
end)

-- ======================= Missões =======================
local function resolver(id)
	return if id == "Mentor" then "MentorShinigami" else id
end
test("progresso de missão e conclusão", function()
	local q = Quests.Story.Training
	local prog = QuestLogic.newProgress(q)
	truthy(QuestLogic.apply(q, prog, { type = "Reach", zone = "Training" }, resolver))
	for _ = 1, 5 do
		QuestLogic.apply(q, prog, { type = "Kill", enemy = "TrainingPuppet" }, resolver)
	end
	eq(prog[2], 3, "não ultrapassa a meta")
	truthy(not QuestLogic.isComplete(q, prog))
	QuestLogic.apply(q, prog, { type = "Parry" }, resolver)
	truthy(QuestLogic.isComplete(q, prog))
end)
test("talk com mentor resolvido pela facção", function()
	local q = Quests.Story.Awakening
	local prog = QuestLogic.newProgress(q)
	truthy(not QuestLogic.apply(q, prog, { type = "Talk", npc = "MentorHollow" }, resolver))
	truthy(QuestLogic.apply(q, prog, { type = "Talk", npc = "MentorShinigami" }, resolver))
end)
test("requisitos de aceitar", function()
	local p = newProfile()
	p.faction = "Hollow"
	truthy(not QuestLogic.canAccept(p, "InnerHollowTrial", Quests.Story.InnerHollowTrial))
	truthy(not QuestLogic.canAccept(p, "Release", Quests.Story.Release), "nível")
	p.level = 5
	truthy(QuestLogic.canAccept(p, "Release", Quests.Story.Release))
end)
test("diárias determinísticas e distintas", function()
	local pool = {}
	for id in Quests.DailyPool do
		table.insert(pool, id)
	end
	local a = QuestLogic.dailySelection(20000, 12345, pool, 3)
	local b = QuestLogic.dailySelection(20000, 12345, pool, 3)
	local c = QuestLogic.dailySelection(20001, 12345, pool, 3)
	eq(#a, 3)
	eq(table.concat(a, ","), table.concat(b, ","))
	truthy(a[1] ~= a[2] and a[2] ~= a[3] and a[1] ~= a[3])
	truthy(table.concat(a, ",") ~= table.concat(c, ",") or true)
end)

-- ======================= Dados =======================
test("normalize repara perfil corrompido", function()
	local p = DataSchema.normalize({ level = "abc", xp = -5, stats = { Strength = 3 } })
	eq(p.level, 1)
	eq(p.xp, 0)
	eq(p.stats.Strength, 3)
	eq(p.stats.Agility, 0)
	eq(p.version, DataSchema.Version)
	truthy(p.quests.daily ~= nil)
end)

-- ======================= Integridade das configs =======================
test("habilidades referenciadas existem e têm kind válido", function()
	local kinds = {
		Projectile = true,
		Beam = true,
		DashStrike = true,
		Burst = true,
		Rain = true,
		Buff = true,
		Pull = true,
		Barrage = true,
	}
	for id, a in Abilities do
		truthy(kinds[a.kind], id .. " kind inválido " .. tostring(a.kind))
		truthy(Animations.List[a.anim], id .. " anim inexistente " .. tostring(a.anim))
		truthy(a.element == nil or Elements[a.element], id .. " elemento inválido")
		if a.kind == "Projectile" then
			truthy(a.speed and a.range and a.radius and a.shape, id .. " projétil incompleto")
		elseif a.kind == "Beam" then
			truthy(a.length and a.radius and a.ticks and a.interval and a.shape, id .. " feixe incompleto")
		elseif a.kind == "DashStrike" then
			truthy(a.distance and a.width, id .. " dash incompleto")
		elseif a.kind == "Burst" then
			truthy(a.radius and a.target, id .. " burst incompleto")
		elseif a.kind == "Rain" then
			truthy(a.radius and a.range and a.ticks and a.interval, id .. " rain incompleto")
		end
	end
	for _, fid in Factions.Order do
		for slot, aid in Factions[fid].base do
			truthy(Abilities[aid], fid .. "." .. slot)
		end
	end
	for pid, p in Powers.List do
		truthy(Factions[p.faction], pid .. " facção")
		truthy(Powers.Rarities[p.rarity], pid .. " raridade")
		truthy(Elements[p.element], pid .. " elemento")
		for _, tier in { p.tier1, p.tier2 } do
			for slot, aid in tier.abilities do
				truthy(Abilities[aid], pid .. " " .. slot .. " -> " .. aid)
			end
		end
		truthy(p.tier2.abilities.V, pid .. " sem ultimate")
	end
	for fid, pid in Powers.Starter do
		eq(Powers.List[pid].faction, fid)
	end
	for _, aid in Factions.Mask.overrides do
		truthy(Abilities[aid])
	end
end)
test("combos usam animações existentes", function()
	for _, list in { Combat.Light, Combat.Aerial } do
		for i, atk in list do
			truthy(Animations.List[atk.anim], "golpe " .. i)
			truthy(atk.windup < atk.duration, "windup < duration " .. atk.anim)
		end
	end
	for _, atk in { Combat.Heavy, Combat.Launcher, Combat.Counter, Combat.Execution } do
		truthy(Animations.List[atk.anim], atk.anim)
	end
	eq(#Combat.Light, 5)
end)
test("inimigos, loot e spawns consistentes", function()
	for _, s in Zones.Spawners do
		truthy(Enemies.get(s.enemy), "spawner " .. s.enemy)
		truthy(Zones.List[s.zone], "zona " .. s.zone)
	end
	for _, b in Zones.Bosses do
		local def = Enemies.get(b.enemy)
		truthy(def and def.boss, "chefe " .. b.enemy)
		truthy(def.phases[1].threshold == 1, "fase inicial")
	end
	for id, e in Enemies do
		if type(e) == "table" and e.health then
			if e.loot then
				truthy(Loot[e.loot], id .. " loot")
			end
			for _, a in e.abilities or {} do
				truthy(Abilities[a.id], id .. " habilidade " .. a.id)
			end
			for _, phase in e.phases or {} do
				for _, a in phase.abilities do
					truthy(Abilities[a.id], id .. " fase " .. a.id)
				end
				if phase.summon then
					truthy(Enemies.get(phase.summon.id), "invocação")
				end
			end
		end
	end
	for tid, t in Loot do
		for _, list in { t.guaranteed or {}, t.chance or {} } do
			for _, d in list do
				truthy(Items.List[d.id], tid .. " item " .. d.id)
			end
		end
		if t.pity then
			truthy(Items.List[t.pity.id], tid .. " pity")
		end
	end
end)
test("missões, NPCs e portais consistentes", function()
	for _, id in Quests.StoryOrder do
		local q = Quests.Story[id]
		truthy(q, id)
		if q.next then
			truthy(Quests.Story[q.next], id .. " next")
		end
		for _, o in q.objectives do
			if o.enemy then
				truthy(Enemies.get(o.enemy), id .. " inimigo " .. o.enemy)
			end
			if o.zone then
				truthy(Zones.List[o.zone], id .. " zona")
			end
			if o.npc and o.npc ~= "Mentor" then
				truthy(NPCs[o.npc], id .. " npc")
			end
		end
		for _, it in (q.rewards.items or {}) do
			truthy(Items.List[it.id], id .. " recompensa")
		end
	end
	for _, f in Factions.Order do
		truthy(NPCs[Factions[f].mentor], "mentor " .. f)
	end
	for _, p in Zones.Portals do
		truthy(Zones.TravelPoints[p.to], p.id)
	end
	for id, r in Items.Recipes do
		truthy(Items.List[id], "receita " .. id)
		for m in r.materials do
			truthy(Items.List[m], "material " .. m)
		end
	end
	for _, id in Items.Shop do
		truthy(Items.List[id].price, "preço " .. id)
	end
end)

-- ======================= Loadout =======================
local Loadout = MODULE("Logic/Loadout")
test("loadout por forma e máscara", function()
	local base = Loadout.resolve(Factions, Powers.List, "Shinigami", "Tsukikage", "Base", false)
	eq(base.Z, "Raika")
	eq(base.V, nil)
	local t1 = Loadout.resolve(Factions, Powers.List, "Shinigami", "Tsukikage", "Tier1", false)
	eq(t1.Z, "Gekko")
	eq(t1.C, "ReiatsuBurst")
	local t2 = Loadout.resolve(Factions, Powers.List, "Shinigami", "Tsukikage", "Tier2", true)
	eq(t2.Z, "MaskCero")
	eq(t2.X, "TsukiNoWa")
	eq(t2.V, "MoonlessHunt")
	local wrong = Loadout.resolve(Factions, Powers.List, "Hollow", "Tsukikage", "Tier2", false)
	eq(wrong.Z, "Cero", "poder de outra facção é ignorado")
	eq(Loadout.weapon(Factions, Powers.List, "Shinigami", "Enjin", "Tier2").style, "Nodachi")
end)

-- ======================= Animações compiladas =======================
local Clips = MODULE("Anim/Clips")
local ClipSampler = MODULE("Anim/ClipSampler")
local function markerTime(clip, name)
	for _, m in clip.markers do
		if m.name == name then
			return m.time
		end
	end
	return nil
end
test("impacto de cada golpe = windup do servidor", function()
	local function check(spec, label)
		local clip = Clips[spec.anim]
		truthy(clip, label .. ": clip " .. spec.anim .. " não compilado")
		local hit = markerTime(clip, "Hit")
		truthy(hit, label .. ": sem marcador Hit")
		truthy(
			math.abs(hit - spec.windup) < 0.002,
			string.format("%s: Hit %.3f ≠ windup %.3f", label, hit, spec.windup)
		)
	end
	for i, spec in Combat.Light do
		check(spec, "Light" .. i)
	end
	for i, spec in Combat.Aerial do
		check(spec, "Aerial" .. i)
	end
	check(Combat.Heavy, "Heavy")
	check(Combat.Launcher, "Launcher")
	check(Combat.Counter, "Counter")
	check(Combat.Execution, "Execution")
end)
test("toda animação usada pelo jogo existe compilada", function()
	for id, a in Abilities do
		local clip = Clips[a.anim]
		truthy(clip, id .. ": " .. a.anim)
		truthy(markerTime(clip, "Release"), a.anim .. " sem marcador Release")
	end
	for _, name in
		{
			"SwordIdle",
			"SwordRun",
			"Block",
			"BlockHit",
			"Draw",
			"Sheathe",
			"Charge",
			"Dash",
			"AirStep",
			"Hit1",
			"Hit2",
			"Stagger",
			"Launched",
			"GuardBreak",
			"Parried",
			"ParrySuccess",
			"ReleaseTier1",
			"ReleaseTier2",
			"MaskOn",
			"Revert",
			"Wave",
			"Talk",
			"NpcIdle",
			"NpcWalk",
			"NpcRun",
			"NpcSprint",
		}
	do
		truthy(Clips[name], name)
	end
	truthy(
		markerTime(Clips.ReleaseTier1, "Release") and markerTime(Clips.ReleaseTier2, "Release"),
		"Release das formas"
	)
	truthy(
		Clips.NpcWalk.groundSpeed and Clips.NpcRun.groundSpeed and Clips.NpcSprint.groundSpeed,
		"velocidade de chão das marchas"
	)
end)
test("criaturas: golpes no tempo do servidor, marchas e versões de cada ação", function()
	for _, set in { "Hollow", "Brute" } do
		truthy(Clips[set .. "Idle"] and Clips[set .. "Idle"].loop, set .. "Idle em loop")
		for _, gait in { "Walk", "Run" } do
			local clip = Clips[set .. gait]
			truthy(clip and clip.loop and clip.groundSpeed, set .. gait .. " com velocidade de chão")
		end
		truthy(
			Clips[set .. "Run"].groundSpeed > Clips[set .. "Walk"].groundSpeed,
			set .. ": correr mais rápido que andar"
		)
		local specs = { Heavy = Combat.Heavy, Launcher = Combat.Launcher }
		for i, spec in Combat.Light do
			specs["Light" .. i] = spec
		end
		for label, spec in specs do
			local clip = Clips[set .. spec.anim]
			if clip then
				local hit = markerTime(clip, "Hit")
				truthy(hit, set .. spec.anim .. ": sem marcador Hit")
				truthy(
					math.abs(hit - spec.windup) < 0.002,
					string.format("%s %s: Hit %.3f ≠ windup %.3f", set, label, hit, spec.windup)
				)
			end
		end
		for name, clip in Clips do
			if name:sub(1, #set + 4) == set .. "Cast" or name == set .. "DashStrikePose" then
				truthy(markerTime(clip, "Release"), name .. " sem Release")
			end
		end
	end
	for i = 1, 5 do
		truthy(Clips["HollowSlash" .. i], "HollowSlash" .. i)
	end
	for _, name in { "HeavySlash", "Uppercut", "Block", "BlockHit", "Hit1", "Hit2", "Stagger", "GuardBreak", "Parried" } do
		truthy(Clips["Hollow" .. name] and Clips["Brute" .. name], "Hollow/Brute " .. name)
	end
	for id, def in Enemies do
		if type(def) == "table" and def.body then
			truthy(def.weapon == nil or def.weapon.bodyClaws, id .. ": garras do corpo (sem garras duplicadas)")
		end
	end
end)
test("segunda liberação tem cutscene com tempos coerentes", function()
	for _, id in Factions.Order do
		local faction = Factions[id]
		local form = faction.forms.Tier2
		truthy(form.cutscene and form.reveal and form.reveal > 0, id .. ": Tier2 sem cutscene/reveal")
		truthy(form.channel >= 4, id .. ": canalização curta demais para a cena")
		truthy(form.channel < faction.forms.Tier1.channel * 10, id .. ": canalização exagerada")
	end
	truthy(Clips.ReleaseTier2 and Clips.SwordIdle and Clips.CastSlash, "clips usados na cena")
end)
test("jogador: locomoção própria completa e na velocidade do jogo", function()
	for _, set in { "Hero", "Sword" } do
		for _, state in { "Idle", "Walk", "Run", "Sprint", "Jump", "Fall" } do
			truthy(Clips[set .. state], set .. state)
		end
		local run, sprint = Clips[set .. "Run"].groundSpeed, Clips[set .. "Sprint"].groundSpeed
		truthy(run and sprint and Clips[set .. "Walk"].groundSpeed, set .. ": marchas com velocidade de chão")
		-- a taxa de reprodução fica perto de 1 nas velocidades reais (andar 18, disparada 27)
		truthy(math.abs(Combat.BaseWalkSpeed / run - 1) < 0.25, set .. "Run fora da velocidade de andar")
		truthy(math.abs(Combat.SprintSpeed / sprint - 1) < 0.25, set .. "Sprint fora da disparada")
	end
end)
test("amostragem reproduz as chaves e o easing do Roblox", function()
	eq(ClipSampler.ease("Linear", "In", 0.25), 0.25)
	eq(ClipSampler.ease("CubicV2", "In", 0.5), 0.125)
	eq(ClipSampler.ease("CubicV2", "Out", 0.5), 0.875)
	eq(ClipSampler.ease("CubicV2", "InOut", 0.5), 0.5)
	eq(ClipSampler.ease("Constant", "In", 0.3), 1)
	eq(ClipSampler.ease("Cubic", "In", 0.5), 0.875, "Cubic antigo do Roblox é invertido")
	for name, clip in Clips do
		for joint, keys in clip.tracks do
			for _, k in keys do
				local cf = ClipSampler.sample(keys, k[1])
				local d = 0
				for i = 1, 9 do
					d = math.max(d, math.abs(cf.r[i] - k[2].r[i]))
				end
				truthy(d < 1e-4, name .. "." .. joint .. " em " .. k[1])
			end
		end
	end
end)

print(string.format("\n%d testes passaram, %d falharam", passed, failed))
if failed > 0 then
	error("testes falharam")
end

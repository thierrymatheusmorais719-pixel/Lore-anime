-- Testes de combate: dano, atributos, papéis, sinergias, XP, evolução, IA e bosses.
local Shared = script.Parent.Parent
local Combat = require(Shared.Config.Combat)
local Pets = require(Shared.Config.Pets)
local Abilities = require(Shared.Config.Abilities)
local Enemies = require(Shared.Config.Enemies)
local Bosses = require(Shared.Config.Bosses)
local CombatRules = require(Shared.Logic.CombatRules)
local PetStats = require(Shared.Logic.PetStats)
local EnemyBrain = require(Shared.Logic.EnemyBrain)
local BossLogic = require(Shared.Logic.BossLogic)
local AttackShapes = require(Shared.Logic.AttackShapes)

return function(t)
	t.test("dano: defesa reduz, crítico aumenta, mínimo 1", function()
		local fixed = function()
			return 0.5
		end
		local d0 = CombatRules.damage(100, 1, 0, fixed)
		local d1 = CombatRules.damage(100, 1, 60, fixed)
		t.eq(d0, 100)
		t.eq(d1, 50)
		local crit = CombatRules.damage(100, 1, 0, function()
			return 0
		end, { crit = 0.5 })
		t.ok(crit > 100, "crítico")
		t.eq((CombatRules.damage(0.01, 1, 1000, fixed)), 1)
		local shred = CombatRules.damage(100, 1, 60, fixed, { defReduction = 0.5 })
		t.ok(shred > d1, "quebrar defesa")
	end)

	t.test("escudo absorve", function()
		local hp, sh = CombatRules.absorb(30, 50)
		t.eq(hp, 0)
		t.eq(sh, 20)
		hp, sh = CombatRules.absorb(80, 50)
		t.eq(hp, 30)
		t.eq(sh, 0)
	end)

	t.test("nenhuma função é superior em todos os atributos", function()
		local stats = { "hp", "atk", "def", "aspd", "range", "crit" }
		for a, ra in pairs(Combat.Roles) do
			for b, rb in pairs(Combat.Roles) do
				if a ~= b then
					local allBetter = true
					for _, s in ipairs(stats) do
						if ra[s] <= rb[s] then
							allBetter = false
						end
					end
					t.ok(not allBetter, a .. " domina " .. b)
				end
			end
		end
	end)

	t.test("todas as espécies têm função, habilidade e raridade válidas", function()
		for id, sp in pairs(Pets.Species) do
			t.ok(Combat.Roles[sp.role] ~= nil, id .. " role")
			t.ok(Abilities.Info[sp.ability] ~= nil, id .. " ability")
			t.ok(sp.model and sp.model.rig, id .. " model")
		end
	end)

	t.test("pet antigo evoluído continua competitivo", function()
		local oldPet = PetStats.compute({ species = "thornpup", tier = 3, level = 60 })
		local newPet = PetStats.compute({ species = "stardust_sprite", tier = 1, level = 1 })
		t.ok(oldPet.atk > newPet.atk, "Ascendido de V1 > comum novo de V5")
	end)

	t.test("XP sobe níveis e respeita o limite do estágio", function()
		local pet = { species = "mossling", tier = 1, level = 1, xp = 0 }
		local ups = PetStats.addXp(pet, 10 ^ 9)
		t.eq(pet.level, Combat.Tiers[1].levelCap)
		t.eq(ups, Combat.Tiers[1].levelCap - 1)
		t.eq(PetStats.addXp(pet, 1000), 0)
		local ok = PetStats.canEvolve(pet)
		t.ok(ok, "pode evoluir no nível máximo")
		t.ok(PetStats.evolutionCost(pet).items.evolution_dust >= 5, "custo")
	end)

	t.test("rank de habilidade reduz recarga e aumenta efeito", function()
		local e1, cd1 = PetStats.abilityValues("charge", 1)
		local e5, cd5 = PetStats.abilityValues("charge", 5, 0.1)
		t.ok(e5 > e1 and cd5 < cd1, "rank")
	end)

	t.test("sinergias detectadas pela composição", function()
		local active, fx = PetStats.synergies({ "Tank", "Support", "Attacker" })
		local ids = {}
		for _, s in ipairs(active) do
			ids[s.id] = true
		end
		t.ok(ids.bulwark and ids.balanced, "sinergias")
		t.near(fx.def, 0.15, 1e-9)
		local sets = PetStats.worldSets({ "mossling", "thornpup", "bloomfox", "glimmerbat" })
		t.ok(sets.verdant and not sets.crystal, "conjunto")
	end)

	-- IA ---------------------------------------------------------------------
	local cfg = { detect = 40, senseRadius = 10, leash = 70, maxChase = 14, investigateTime = 4, recoverTime = 0.6 }
	local function ctx(over)
		local c = {
			hp = 100, hasTarget = false, targetDist = 999, canSee = false, homeDist = 0, timeInState = 0, chaseTime = 0,
			attackReady = true, inAttackRange = false, heard = false, reachedGoal = false, idleDuration = 3, attackDone = false,
		}
		for k, v in pairs(over or {}) do
			c[k] = v
		end
		return c
	end

	t.test("IA: idle -> patrulha -> perseguição -> ataque -> recuperação", function()
		t.eq((EnemyBrain.decide("Idle", ctx({ timeInState = 4 }), cfg)), "Patrol")
		t.eq((EnemyBrain.decide("Patrol", ctx({ hasTarget = true, targetDist = 30, canSee = true }), cfg)), "Chase")
		t.eq((EnemyBrain.decide("Idle", ctx({ hasTarget = true, targetDist = 30, canSee = false }), cfg)), "Idle")
		t.eq((EnemyBrain.decide("Idle", ctx({ hasTarget = true, targetDist = 8, canSee = false }), cfg)), "Chase")
		t.eq((EnemyBrain.decide("Chase", ctx({ hasTarget = true, targetDist = 5, canSee = true, inAttackRange = true }), cfg)), "Attack")
		t.eq((EnemyBrain.decide("Chase", ctx({ hasTarget = true, targetDist = 5, canSee = true, inAttackRange = true, attackReady = false }), cfg)), "Chase")
		t.eq((EnemyBrain.decide("Attack", ctx({ attackDone = true }), cfg)), "Recover")
		t.eq((EnemyBrain.decide("Recover", ctx({ timeInState = 1, hasTarget = true }), cfg)), "Chase")
	end)

	t.test("IA: investiga, desiste e respeita a coleira", function()
		t.eq((EnemyBrain.decide("Idle", ctx({ heard = true }), cfg)), "Investigate")
		t.eq((EnemyBrain.decide("Investigate", ctx({ reachedGoal = true, timeInState = 5 }), cfg)), "Return")
		t.eq((EnemyBrain.decide("Chase", ctx({ hasTarget = true, targetDist = 5, canSee = true, homeDist = 80 }), cfg)), "Return")
		t.eq((EnemyBrain.decide("Chase", ctx({ hasTarget = true, targetDist = 20, canSee = true, chaseTime = 15 }), cfg)), "Return")
		t.eq((EnemyBrain.decide("Chase", ctx({ hasTarget = false }), cfg)), "Investigate")
		-- retornando ignora alvos até chegar (evita loop de perseguição)
		t.eq((EnemyBrain.decide("Return", ctx({ hasTarget = true, targetDist = 2, canSee = true, homeDist = 30 }), cfg)), "Return")
		t.eq((EnemyBrain.decide("Return", ctx({ homeDist = 2 }), cfg)), "Idle")
		t.eq((EnemyBrain.decide("Chase", ctx({ hp = 0 }), cfg)), "Dead")
		t.eq((EnemyBrain.decide("Dead", ctx({ hp = 50 }), cfg)), "Dead")
	end)

	t.test("configs de IA coerentes (alcance de ataque < detecção < coleira)", function()
		for id, e in pairs(Enemies.Info) do
			if not e.passive and not e.summon then
				t.ok(e.attack.range < e.detect, id .. " alcance")
				t.ok(e.detect < e.leash + 1, id .. " coleira")
				t.ok(e.maxChase > 0, id .. " tempo")
			end
		end
	end)

	-- BOSSES -----------------------------------------------------------------
	t.test("boss muda de fase conforme a vida", function()
		local phases = Bosses.Info.void_sovereign.phases
		t.eq(BossLogic.phaseIndex(1, phases), 1)
		t.eq(BossLogic.phaseIndex(0.71, phases), 1)
		t.eq(BossLogic.phaseIndex(0.7, phases), 2)
		t.eq(BossLogic.phaseIndex(0.39, phases), 3)
		t.eq(BossLogic.phaseIndex(0.01, phases), 4)
	end)

	t.test("todo boss tem fases decrescentes e ataques definidos", function()
		for id, b in pairs(Bosses.Info) do
			t.ok(#b.phases >= 3, id .. " fases")
			local last = 2
			for _, ph in ipairs(b.phases) do
				t.ok(ph.at < last, id .. " ordem")
				last = ph.at
				for _, a in ipairs(ph.attacks) do
					t.ok(b.attacks[a] ~= nil, id .. " ataque " .. a)
					t.ok(b.attacks[a].telegraph >= 1.0, id .. " aviso curto " .. a)
				end
			end
		end
	end)

	t.test("escolha de ataque não repete o anterior", function()
		local phase = Bosses.Info.elderroot.phases[1]
		local rng = t.rng(3)
		local last = nil
		for _ = 1, 500 do
			local a = BossLogic.pickAttack(phase, last, rng)
			t.ok(a ~= last, "repetiu")
			last = a
		end
	end)

	t.test("participação: presença sozinha não dá recompensa", function()
		local ok = BossLogic.eligible({ damage = 0, support = 0, tanked = 0, lastAt = 100 }, 10000, 100, true)
		t.ok(not ok, "presente sem contribuir")
		ok = BossLogic.eligible({ damage = 400, lastAt = 100 }, 10000, 100, true)
		t.ok(ok, "dano suficiente")
		ok = BossLogic.eligible({ damage = 400, lastAt = 10 }, 10000, 100, false)
		t.ok(not ok, "saiu antes do fim")
		ok = BossLogic.eligible({ support = 400, lastAt = 95 }, 10000, 100, false)
		t.ok(ok, "suporte recente")
	end)

	t.test("formas de ataque: indicador = área de acerto", function()
		local rng = t.rng(11)
		local c = AttackShapes.build({ shape = "slam", radius = 10 }, { bx = 0, bz = 0, tx = 0, tz = 10, targets = {}, ax = 0, az = 0, ar = 70, rng = rng })
		t.ok(AttackShapes.hitsAny(c, 9, 0), "dentro")
		t.ok(not AttackShapes.hitsAny(c, 11, 0), "fora")
		local ring = AttackShapes.build({ shape = "ring", inner = 10, outer = 20 }, { bx = 0, bz = 0, tx = 0, tz = 1, targets = {}, ax = 0, az = 0, ar = 70, rng = rng })
		t.ok(not AttackShapes.hitsAny(ring, 5, 0), "perto é seguro")
		t.ok(AttackShapes.hitsAny(ring, 15, 0), "no anel")
		t.ok(not AttackShapes.hitsAny(ring, 25, 0), "longe é seguro")
		local line = AttackShapes.build({ shape = "line", width = 6, length = 40 }, { bx = 0, bz = 0, tx = 0, tz = 10, targets = {}, ax = 0, az = 0, ar = 70, rng = rng })
		t.ok(AttackShapes.hitsAny(line, 2, 30), "na linha")
		t.ok(not AttackShapes.hitsAny(line, 5, 30), "ao lado")
		t.ok(not AttackShapes.hitsAny(line, 0, -5), "atrás")
		local cone = AttackShapes.build({ shape = "cone", angle = 60, length = 30 }, { bx = 0, bz = 0, tx = 10, tz = 0, targets = {}, ax = 0, az = 0, ar = 70, rng = rng })
		t.ok(AttackShapes.hitsAny(cone, 20, 5), "no cone")
		t.ok(not AttackShapes.hitsAny(cone, 0, 20), "fora do cone")
		local cross = AttackShapes.build({ shape = "cross", width = 6, length = 60 }, { bx = 0, bz = 0, tx = 0, tz = 10, targets = {}, ax = 0, az = 0, ar = 70, rng = rng })
		t.ok(AttackShapes.hitsAny(cross, 0, -25) and AttackShapes.hitsAny(cross, 25, 0), "braços")
		t.ok(not AttackShapes.hitsAny(cross, 15, 15), "diagonal segura")
		local safe = AttackShapes.build({ shape = "safezones", count = 3, radius = 10 }, { bx = 0, bz = 0, tx = 0, tz = 1, targets = {}, ax = 0, az = 0, ar = 70, rng = rng })
		local zone = safe[1].safe[1]
		t.ok(not AttackShapes.hitsAny(safe, zone.x, zone.z, 1.5), "na zona segura")
		t.ok(AttackShapes.hitsAny(safe, 0, 0, 1.5), "centro perigoso")
		local marks = AttackShapes.build({ shape = "target_circles", radius = 8, max = 2 }, { bx = 0, bz = 0, tx = 0, tz = 1,
			targets = { { x = 30, z = 0 }, { x = -30, z = 0 }, { x = 0, z = 30 } }, ax = 0, az = 0, ar = 70, rng = rng })
		t.eq(#marks, 2)
	end)

	t.test("vida do boss escala com jogadores (limitado)", function()
		local r = Bosses.Rules
		t.eq(BossLogic.scaledHp(1000, 1, r), 1000)
		t.eq(BossLogic.scaledHp(1000, 2, r), 1600)
		t.eq(BossLogic.scaledHp(1000, 50, r), BossLogic.scaledHp(1000, r.hpScaleMaxPlayers, r))
	end)
end

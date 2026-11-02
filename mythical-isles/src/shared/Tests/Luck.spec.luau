-- Testes do sistema de sorte.
local Shared = script.Parent.Parent
local LuckLogic = require(Shared.Logic.LuckLogic)
local LuckConfig = require(Shared.Config.Luck)
local Rarities = require(Shared.Config.Rarities)
local DataSchema = require(Shared.Logic.DataSchema)

return function(t)
	t.test("multiplicador base é 1 sem fontes", function()
		local mult = LuckLogic.multiplier({}, "PetVariant")
		t.eq(mult, 1)
	end)

	t.test("cada tipo de fonte respeita seu teto", function()
		local sources = {
			{ type = "potion", id = "a", label = "a", category = "All", bonus = 0.9 },
			{ type = "potion", id = "b", label = "b", category = "All", bonus = 0.9 },
		}
		local mult, byType = LuckLogic.multiplier(sources, "Drop")
		t.eq(byType.potion, LuckConfig.SourceCaps.potion)
		t.near(mult, math.min(1 + LuckConfig.SourceCaps.potion, LuckConfig.MaxMultiplier.Drop), 1e-9)
	end)

	t.test("multiplicador total nunca passa do máximo da categoria", function()
		local sources = {}
		for _, ty in ipairs({ "event", "potion", "quest", "pet", "collection", "login", "synergy" }) do
			table.insert(sources, { type = ty, id = ty, label = ty, category = "All", bonus = 10 })
		end
		for _, cat in ipairs(LuckConfig.Categories) do
			local mult = LuckLogic.multiplier(sources, cat)
			t.ok(mult <= LuckConfig.MaxMultiplier[cat] + 1e-9, cat)
		end
	end)

	t.test("fonte de categoria específica não vaza para outra", function()
		local sources = { { type = "potion", id = "x", label = "x", category = "Treasure", bonus = 0.5 } }
		t.eq(LuckLogic.multiplier(sources, "Treasure"), 1.5)
		t.eq(LuckLogic.multiplier(sources, "PetVariant"), 1)
	end)

	t.test("tipo de fonte desconhecido (falsificado) vale zero", function()
		local sources = { { type = "client_hack", id = "x", label = "x", category = "All", bonus = 100 } }
		t.eq(LuckLogic.multiplier(sources, "PetVariant"), 1)
	end)

	t.test("applyWeighted soma 1 e respeita tetos com sorte máxima", function()
		local entries = {
			{ key = "c", weight = 60, rarity = "Common" },
			{ key = "u", weight = 27, rarity = "Uncommon" },
			{ key = "r", weight = 9.5, rarity = "Rare" },
			{ key = "e", weight = 3, rarity = "Epic" },
			{ key = "l", weight = 0.48, rarity = "Legendary" },
			{ key = "s", weight = 0.02, rarity = "Secret" },
		}
		for _, mult in ipairs({ 1, 1.5, 2, 3, 50, 1e6 }) do
			local probs = LuckLogic.applyWeighted(entries, mult)
			local sum = 0
			for _, o in ipairs(probs) do
				sum += o.p
				t.ok(o.p >= 0, "p negativo")
				t.ok(o.p <= math.max(Rarities.Info[o.rarity].maxChance, o.base) + 1e-9, "teto violado " .. o.key .. " mult " .. mult)
			end
			t.near(sum, 1, 1e-9, "soma mult " .. mult)
		end
	end)

	t.test("sorte 1 = chances base exatas", function()
		local entries = { { key = "a", weight = 75, rarity = "Common" }, { key = "b", weight = 25, rarity = "Legendary" } }
		local probs = LuckLogic.applyWeighted(entries, 1)
		t.near(probs[1].p, 0.75, 1e-12)
		t.near(probs[2].p, 0.25, 1e-12)
	end)

	t.test("sorte aumenta raros e nunca diminui abaixo da base", function()
		local entries = { { key = "c", weight = 99, rarity = "Common" }, { key = "l", weight = 1, rarity = "Legendary" } }
		local base = LuckLogic.applyWeighted(entries, 1)[2].p
		local boosted = LuckLogic.applyWeighted(entries, 2)[2].p
		t.ok(boosted > base, "não aumentou")
		t.near(boosted, 2 / 101, 1e-9)
	end)

	t.test("entrada base acima do teto não é reduzida pela sorte", function()
		-- Secret com 1,5% de base (> teto de 1%) continua 1,5% e não sobe
		local entries = { { key = "c", weight = 98.5, rarity = "Epic" }, { key = "s", weight = 1.5, rarity = "Secret" } }
		local probs = LuckLogic.applyWeighted(entries, 3)
		t.near(probs[2].p, 0.015, 1e-9)
	end)

	t.test("entradas indisponíveis têm chance 0 e o resto renormaliza", function()
		local entries = { { key = "a", weight = 50, rarity = "Common" }, { key = "b", weight = 50, rarity = "Legendary", available = false } }
		local probs = LuckLogic.applyWeighted(entries, 3)
		t.eq(probs[2].p, 0)
		t.near(probs[1].p, 1, 1e-12)
	end)

	t.test("applyChance limites", function()
		t.near(LuckLogic.applyChance(0.1, 1, 1, 0.3), 0.1, 1e-12)
		t.near(LuckLogic.applyChance(0.1, 2, 1, 0.3), 0.2, 1e-12)
		t.near(LuckLogic.applyChance(0.1, 100, 1, 0.3), 0.3, 1e-12)
		t.near(LuckLogic.applyChance(0.5, 100, 1, 2), 1, 1e-12)
		t.near(LuckLogic.applyChance(0.1, 100, 1, nil), 0.1, 1e-12) -- sem teto = sem aumento
	end)

	t.test("eventos agendados seguem o relógio UTC", function()
		local ev = { { id = "e", label = "E", period = 100, offset = 10, duration = 20, bonus = 0.5, category = "All" } }
		t.eq(#LuckLogic.activeEvents(9, ev), 0)
		t.eq(#LuckLogic.activeEvents(10, ev), 1)
		t.eq(LuckLogic.activeEvents(15, ev)[1].ends, 30)
		t.eq(#LuckLogic.activeEvents(30, ev), 0)
		t.eq(#LuckLogic.activeEvents(115, ev), 1)
	end)

	t.test("collectSources ignora buffs expirados e soma coleção/login", function()
		local p = DataSchema.default()
		p.buffs = {
			{ id = "luck_potion_1", source = "potion", label = "P", category = "All", bonus = 0.25, expires = 1000 },
			{ id = "old", source = "potion", label = "O", category = "All", bonus = 0.5, expires = 10 },
		}
		p.bestiary.pets = { a = { n = 1, first = 0, muts = { Golden = 1 } }, b = { n = 1, first = 0, muts = {} } }
		p.login = { day = 1, streak = 2, claimedAt = 400 }
		local sources = LuckLogic.collectSources({ now = 500, profile = p, events = {} })
		local types = {}
		for _, s in ipairs(sources) do
			types[s.id] = s.bonus
		end
		t.eq(types.luck_potion_1, 0.25)
		t.eq(types.old, nil)
		t.near(types.collection, 2 * LuckConfig.Collection.perSpecies + LuckConfig.Collection.perMutationKind, 1e-9)
		t.near(types.login, 2 * LuckConfig.Login.perStreakDay, 1e-9)
	end)

	t.test("addBuff soma duração da mesma poção com teto", function()
		local buffs = {}
		LuckLogic.addBuff(buffs, 0, { id = "p", source = "potion", label = "P", category = "All", bonus = 0.25, duration = 600 })
		LuckLogic.addBuff(buffs, 100, { id = "p", source = "potion", label = "P", category = "All", bonus = 0.25, duration = 600 })
		t.eq(#buffs, 1)
		t.eq(buffs[1].expires, 1200)
		for _ = 1, 20 do
			LuckLogic.addBuff(buffs, 100, { id = "p", source = "potion", label = "P", category = "All", bonus = 0.25, duration = 600 })
		end
		t.eq(buffs[1].expires, 100 + LuckConfig.MaxPotionDuration)
	end)

	t.test("pick respeita as probabilidades (estatístico)", function()
		local probs = { { key = "a", p = 0.7 }, { key = "b", p = 0.25 }, { key = "c", p = 0.05 } }
		local rng = t.rng(42)
		local n, counts = 200000, { a = 0, b = 0, c = 0 }
		for _ = 1, n do
			local k = LuckLogic.pick(probs, rng())
			counts[k] += 1
		end
		t.near(counts.a / n, 0.7, 0.005)
		t.near(counts.b / n, 0.25, 0.005)
		t.near(counts.c / n, 0.05, 0.003)
	end)
end

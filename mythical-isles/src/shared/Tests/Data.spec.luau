-- Testes de persistência, inventário, bestiário, missões e coleção.
local Shared = script.Parent.Parent
local DataSchema = require(Shared.Logic.DataSchema)
local InventoryLogic = require(Shared.Logic.InventoryLogic)
local QuestLogic = require(Shared.Logic.QuestLogic)
local CollectionLogic = require(Shared.Logic.CollectionLogic)
local Quests = require(Shared.Config.Quests)
local Items = require(Shared.Config.Items)
local Pets = require(Shared.Config.Pets)
local Enemies = require(Shared.Config.Enemies)
local Bosses = require(Shared.Config.Bosses)
local Worlds = require(Shared.Config.Worlds)
local LuckConfig = require(Shared.Config.Luck)

-- Simula salvar/carregar (DataStore guarda JSON: sem funções, sem metatables).
local function roundtrip(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[k] = roundtrip(x)
	end
	return out
end

return function(t)
	t.test("mutação persiste após salvar e carregar", function()
		local d = DataSchema.default()
		local pet = InventoryLogic.addPet(d, "prismcat", "Prismatic", 100, "egg")
		local loaded = DataSchema.reconcile(roundtrip(d))
		t.eq(loaded.pets[pet.uid].mutation, "Prismatic")
		t.eq(loaded.pets[pet.uid].species, "prismcat")
		t.ok(loaded.bestiary.pets.prismcat.muts.Prismatic ~= nil, "bestiário com mutação")
	end)

	t.test("reconcile completa campos sem apagar dados", function()
		local old = { coins = 55, pets = { ["1"] = { uid = "1", species = "mossling", tier = 1, level = 3 } }, team = { "1", "999" }, stats = { hatched = 4 } }
		local d = DataSchema.reconcile(old)
		t.eq(d.coins, 55)
		t.eq(d.stats.hatched, 4)
		t.eq(d.stats.kills, 0)
		t.eq(#d.team, 1)
		t.ok(d.settings.announcements == true, "settings")
		t.ok(d.quests.daily ~= nil, "daily")
	end)

	t.test("inventário: gastar só com saldo; ids inválidos rejeitados", function()
		local d = DataSchema.default()
		d.coins = 0
		t.ok(InventoryLogic.add(d, "coins", 100), "coins")
		t.ok(not InventoryLogic.add(d, "item_que_nao_existe", 1), "id inválido")
		t.ok(not InventoryLogic.add(d, "coins", -50), "negativo")
		t.ok(not InventoryLogic.add(d, "coins", 0 / 0), "NaN")
		t.ok(not InventoryLogic.spend(d, { coins = 101 }), "sem saldo")
		t.ok(InventoryLogic.spend(d, { coins = 100 }), "pagar")
		t.eq(d.coins, 0)
		InventoryLogic.add(d, "evolution_dust", 3)
		t.ok(not InventoryLogic.spend(d, { items = { evolution_dust = 4 } }), "itens insuficientes")
		t.ok(InventoryLogic.spend(d, { items = { evolution_dust = 3 } }), "itens")
		t.eq(d.items.evolution_dust, nil)
	end)

	t.test("perfis são independentes (sem inventário compartilhado)", function()
		local a, b = DataSchema.default(), DataSchema.default()
		InventoryLogic.add(a, "coins", 10)
		InventoryLogic.addPet(a, "mossling", nil, 0)
		t.eq(b.coins, DataSchema.StartingCoins)
		t.eq(InventoryLogic.petCount(b), 0)
		t.ok(a.bestiary ~= b.bestiary, "tabelas distintas")
	end)

	t.test("pet trancado não pode ser removido; remover tira da equipe", function()
		local d = DataSchema.default()
		local p = InventoryLogic.addPet(d, "mossling", nil, 0)
		d.team = { p.uid }
		p.locked = true
		t.ok(not InventoryLogic.removePet(d, p.uid), "trancado")
		p.locked = false
		t.ok(InventoryLogic.removePet(d, p.uid), "remove")
		t.eq(#d.team, 0)
	end)

	t.test("bestiário registra pets e inimigos", function()
		local d = DataSchema.default()
		t.ok(InventoryLogic.registerFoe(d, "enemy", "thornling", 1), "novo")
		t.ok(not InventoryLogic.registerFoe(d, "enemy", "thornling", 2), "repetido")
		t.eq(d.bestiary.enemies.thornling.n, 2)
		InventoryLogic.registerFoe(d, "boss", "elderroot", 3)
		t.eq(d.bestiary.bosses.elderroot.n, 1)
		local c = CollectionLogic.counts(d)
		t.eq(c.enemies, 2)
	end)

	t.test("histórico limitado", function()
		local d = DataSchema.default()
		for i = 1, 40 do
			InventoryLogic.pushHistory(d, { t = i, text = "x" })
		end
		t.eq(#d.history, LuckConfig.HistorySize)
		t.eq(d.history[1].t, 40)
	end)

	t.test("missões: história avança e diárias são determinísticas", function()
		local d = DataSchema.default()
		local done = QuestLogic.onEvent(d, { type = "hatch", amount = 1 })
		t.eq(#done, 1)
		local reward = QuestLogic.claimStory(d)
		t.ok(reward ~= nil, "recompensa")
		t.eq(QuestLogic.claimStory(d), nil) -- não resgata duas vezes
		t.eq(d.quests.storyIndex, 2)
		local a, b = QuestLogic.dailyFor(20000), QuestLogic.dailyFor(20000)
		t.eq(#a, Quests.DailyCount)
		for i = 1, #a do
			t.eq(a[i], b[i])
		end
		QuestLogic.ensureDaily(d, 20000)
		local id = d.quests.daily.ids[1]
		local q = Quests.findDaily(id)
		t.eq(QuestLogic.claimDaily(d, id), nil)
		QuestLogic.onEvent(d, { type = q.goal.type, amount = q.goal.count })
		t.ok(QuestLogic.claimDaily(d, id) ~= nil, "diária")
		t.eq(QuestLogic.claimDaily(d, id), nil)
	end)

	t.test("referências das missões existem", function()
		local function checkReward(r, id)
			if r.items then
				for item in pairs(r.items) do
					t.ok(Items.Info[item] ~= nil, id .. " item " .. item)
				end
			end
		end
		for _, q in ipairs(Quests.Story) do
			local g = q.goal
			if g.type == "defeat_enemy" and g.target then
				t.ok(Enemies.Info[g.target] ~= nil, q.id)
			elseif g.type == "defeat_boss" and g.target then
				t.ok(Bosses.Info[g.target] ~= nil, q.id)
			elseif g.type == "unlock_world" then
				t.ok(Worlds.Info[g.target] ~= nil, q.id)
			end
			checkReward(q.reward, q.id)
		end
		for _, q in ipairs(Quests.DailyPool) do
			checkReward(q.reward, q.id)
		end
	end)

	t.test("marco de coleção só é resgatado uma vez", function()
		local d = DataSchema.default()
		for _, id in ipairs({ "mossling", "leafwing", "thornpup", "bloomfox", "grovekin" }) do
			InventoryLogic.addPet(d, id, nil, 0)
		end
		local list = CollectionLogic.claimable(d)
		t.ok(#list >= 1, "disponível")
		t.ok(CollectionLogic.claim(d, "c_pets5") ~= nil, "resgate")
		t.eq(CollectionLogic.claim(d, "c_pets5"), nil)
	end)

	t.test("encontros antigos são podados", function()
		local d = DataSchema.default()
		d.claimedEncounters = { a = 0, b = 3 * 86400 }
		DataSchema.pruneEncounters(d, 3 * 86400 + 10)
		t.eq(d.claimedEncounters.a, nil)
		t.ok(d.claimedEncounters.b ~= nil, "recente fica")
	end)

	t.test("mundo 1 tem 90 pets (80 + 10 da 2ª leva) e o mundo 2 tem 80, com exatamente 1 SECRET", function()
		local expected = { verdant = 90, crystal = 80 }
		for _, w in ipairs({ "verdant", "crystal" }) do
			local n, secret = 0, 0
			for _, sp in pairs(Pets.Species) do
				if sp.world == w and sp.rarity ~= "Celestial" then
					n += 1
					if sp.rarity == "Secret" then
						secret += 1
					end
				end
			end
			t.eq(n, expected[w], w)
			t.eq(secret, 1, w .. " secret")
		end
	end)

	t.test("pets por mundo cobrem todas as raridades base", function()
		local byWorld = {}
		for _, sp in pairs(Pets.Species) do
			byWorld[sp.world] = byWorld[sp.world] or {}
			byWorld[sp.world][sp.rarity] = true
		end
		for _, w in ipairs(Worlds.Order) do
			for _, r in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret" }) do
				t.ok(byWorld[w][r], w .. " " .. r)
			end
		end
	end)
end

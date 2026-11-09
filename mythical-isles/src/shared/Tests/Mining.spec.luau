-- Testes da mineração de cristais (regras puras: contratos, entrega, picareta, rendimento).
local Shared = script.Parent.Parent
local Mining = require(Shared.Config.Mining)
local MiningLogic = require(Shared.Logic.MiningLogic)
local DataSchema = require(Shared.Logic.DataSchema)
local Items = require(Shared.Config.Items)
local Quests = require(Shared.Config.Quests)

return function(t)
	t.test("todo cristal é item e todo veio/contrato/picareta usa itens que existem", function()
		for id in pairs(Mining.Crystals) do
			t.ok(Items.Info[id] ~= nil and Items.Info[id].kind == "crystal", "item " .. id)
		end
		for kind, v in pairs(Mining.Veins) do
			t.ok(Mining.Crystals[v.crystal] ~= nil, "veio " .. kind)
			t.ok(v.hp > 0 and v.yield[1] >= 1 and v.yield[2] >= v.yield[1], "números do veio " .. kind)
		end
		for _, c in ipairs(Mining.Contracts) do
			for item in pairs(c.need) do
				t.ok(Items.Info[item] ~= nil, "contrato " .. c.id .. " pede " .. item)
			end
		end
		for i = 2, #Mining.Pickaxes do
			for item in pairs(Mining.Pickaxes[i].cost.items or {}) do
				t.ok(Items.Info[item] ~= nil, "picareta " .. i .. " custa " .. item)
			end
		end
		for _, q in ipairs(Quests.DailyPool) do
			if q.goal.type == "mine_crystal" and q.goal.target then
				t.ok(Mining.Crystals[q.goal.target] ~= nil, "missão " .. q.id)
			end
		end
	end)

	t.test("picaretas ficam mais fortes e rápidas a cada nível", function()
		for i = 2, #Mining.Pickaxes do
			t.ok(Mining.Pickaxes[i].power > Mining.Pickaxes[i - 1].power, "força " .. i)
			t.ok(Mining.Pickaxes[i].hold < Mining.Pickaxes[i - 1].hold, "tempo " .. i)
			t.ok(MiningLogic.minInterval(i) > 0.3, "intervalo mínimo " .. i)
		end
		t.eq(MiningLogic.strikePower(1, 0), 1)
		t.eq(MiningLogic.strikePower(1, 4), 3) -- +1 a cada 2 pets
	end)

	t.test("contratos do dia: determinísticos, sem repetir e só dos mundos abertos", function()
		local a = MiningLogic.contractsFor(20000, { verdant = true, crystal = true })
		local b = MiningLogic.contractsFor(20000, { verdant = true, crystal = true })
		t.eq(#a, Mining.ContractsPerDay)
		t.eq(table.concat(a, ","), table.concat(b, ","))
		local seen = {}
		for _, id in ipairs(a) do
			t.ok(not seen[id], "repetido " .. id)
			seen[id] = true
			local w = Mining.findContract(id).world
			t.ok(w == "verdant" or w == "crystal", "mundo " .. w)
		end
		local differs = false
		for day = 20001, 20010 do
			if table.concat(MiningLogic.contractsFor(day, { verdant = true, crystal = true }), ",") ~= table.concat(a, ",") then
				differs = true
			end
		end
		t.ok(differs, "contratos mudam com o dia")
	end)

	t.test("entrega de contrato: debita, marca e não repete; recusa sem cristais", function()
		local d = DataSchema.default()
		d.mining.contracts = { day = 5, ids = { "mc_emerald_s" }, done = {} }
		local r, why = MiningLogic.deliver(d, "mc_emerald_s")
		t.ok(r == nil and type(why) == "string", "sem cristais")
		d.items.emerald_crystal = 9
		local r2 = MiningLogic.deliver(d, "mc_emerald_s")
		t.ok(r2 ~= nil, "entregou")
		t.eq(d.items.emerald_crystal, 1)
		t.ok(d.mining.contracts.done.mc_emerald_s == true, "marcado")
		d.items.emerald_crystal = 50
		t.ok(MiningLogic.deliver(d, "mc_emerald_s") == nil, "não entrega duas vezes")
		t.ok(MiningLogic.deliver(d, "mc_star") == nil, "fora do dia")
	end)

	t.test("melhorar picareta: cobra o custo e para no nível máximo", function()
		local d = DataSchema.default()
		t.ok(MiningLogic.upgrade(d) == nil, "sem custo")
		d.coins = 600
		d.items.emerald_crystal = 12
		t.eq(MiningLogic.upgrade(d), 2)
		t.eq(d.coins, 0)
		t.ok(d.items.emerald_crystal == nil, "cristais gastos")
		d.mining.pickaxe = #Mining.Pickaxes
		t.ok(MiningLogic.upgrade(d) == nil, "máximo")
	end)

	t.test("rendimento: faixa do veio + bônus da picareta; raro só com a chance", function()
		local lo = function(a, _b)
			return a
		end
		local hi = function(_a, b)
			return b
		end
		local never = function()
			return 0.99
		end
		local always = function()
			return 0
		end
		local y1 = MiningLogic.yield("emerald", 1, lo, never, 0.03)
		t.eq(y1.emerald_crystal, Mining.Veins.emerald.yield[1])
		t.ok(y1.prism_heart == nil, "sem raro")
		local y3 = MiningLogic.yield("emerald", 3, hi, always, 0.03)
		t.eq(y3.emerald_crystal, Mining.Veins.emerald.yield[2] + Mining.Pickaxes[3].bonus)
		t.eq(y3.prism_heart, 1)
	end)

	t.test("perfil antigo ganha a mineração sem perder nada", function()
		local d = DataSchema.reconcile({ coins = 77, items = { emerald_crystal = 3 } })
		t.eq(d.coins, 77)
		t.eq(d.items.emerald_crystal, 3)
		t.eq(d.mining.pickaxe, 1)
		t.ok(type(d.mining.contracts.ids) == "table", "contratos")
	end)
end

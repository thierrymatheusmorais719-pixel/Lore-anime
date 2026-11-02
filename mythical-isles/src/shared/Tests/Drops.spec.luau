-- Testes das tabelas de drop.
local Shared = script.Parent.Parent
local Drops = require(Shared.Config.Drops)
local Items = require(Shared.Config.Items)
local Pets = require(Shared.Config.Pets)
local Enemies = require(Shared.Config.Enemies)
local Bosses = require(Shared.Config.Bosses)
local DropLogic = require(Shared.Logic.DropLogic)
local InventoryLogic = require(Shared.Logic.InventoryLogic)

local function validItem(id)
	if InventoryLogic.isCurrency(id) then
		return true
	end
	local sp = id:match("^pet:(.+)$")
	if sp then
		return Pets.Species[sp] ~= nil
	end
	return Items.Info[id] ~= nil
end

return function(t)
	t.test("todo inimigo e boss tem tabela de drop válida", function()
		for id in pairs(Enemies.Info) do
			t.ok(Drops.Tables[id] ~= nil, "sem tabela: " .. id)
		end
		for id, b in pairs(Bosses.Info) do
			t.ok(Drops.Tables[b.loot] ~= nil, "sem tabela: " .. id)
		end
	end)

	t.test("entradas válidas, chances em [0,1] e teto obrigatório quando há sorte", function()
		local function check(name, tbl)
			for _, e in ipairs(tbl) do
				t.ok(validItem(e.item), name .. ": item inválido " .. e.item)
				t.ok(e.chance >= 0 and e.chance <= 1, name .. ": chance " .. e.item)
				t.ok((e.min or 1) <= (e.max or 1), name .. ": min>max " .. e.item)
				if e.luck then
					t.ok(e.maxChance ~= nil and e.maxChance >= e.chance and e.maxChance <= 1, name .. ": teto " .. e.item)
				end
			end
		end
		for id, tbl in pairs(Drops.Tables) do
			check(id, tbl)
		end
		check("treasure", Drops.Treasure)
	end)

	t.test("sorte enorme nunca passa do teto", function()
		local mults = { Drop = 1e9, SpecialEgg = 1e9, Treasure = 1e9 }
		for id, tbl in pairs(Drops.Tables) do
			for _, o in ipairs(DropLogic.odds(tbl, mults)) do
				t.ok(o.p <= 1, id)
			end
			for i, e in ipairs(tbl) do
				local p = DropLogic.effectiveChance(e, mults)
				t.ok(p <= (e.luck and e.maxChance or e.chance) + 1e-12, id .. "#" .. i)
			end
		end
	end)

	t.test("frequências reais batem com a configuração", function()
		local tbl = Drops.Tables.elderroot
		local mults = { Drop = 1.5, SpecialEgg = 1 }
		local rng = t.rng(2024)
		local n = 100000
		local hits = {}
		for _ = 1, n do
			for _, r in ipairs(DropLogic.roll(tbl, mults, rng)) do
				hits[r.item] = (hits[r.item] or 0) + 1
			end
		end
		for _, e in ipairs(tbl) do
			local p = DropLogic.effectiveChance(e, mults)
			local tol = math.max(0.002, 4 * math.sqrt(p * (1 - p) / n))
			t.near((hits[e.item] or 0) / n, p, tol, e.item)
		end
	end)

	t.test("quantidades ficam entre min e max", function()
		local rng = t.rng(5)
		for _ = 1, 5000 do
			for _, r in ipairs(DropLogic.roll(Drops.Tables.thornling, {}, rng)) do
				for _, e in ipairs(Drops.Tables.thornling) do
					if e.item == r.item then
						t.ok(r.amount >= e.min and r.amount <= e.max, r.item)
					end
				end
			end
		end
	end)
end

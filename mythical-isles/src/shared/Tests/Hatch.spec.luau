-- Testes de ovos, raridades SECRET/CELESTIAL e mutações.
local Shared = script.Parent.Parent
local Eggs = require(Shared.Config.Eggs)
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local HatchLogic = require(Shared.Logic.HatchLogic)
local DataSchema = require(Shared.Logic.DataSchema)

return function(t)
	t.test("pesos de cada ovo somam 100 e espécies existem", function()
		for id, egg in pairs(Eggs.Info) do
			local sum = 0
			for _, e in ipairs(egg.entries) do
				t.ok(Pets.Species[e.species] ~= nil, id .. ": espécie " .. e.species)
				sum += e.weight
			end
			t.near(sum, 100, 1e-6, id)
		end
	end)

	t.test("odds exibidas = odds usadas (sorte 1 = pesos base)", function()
		local p = DataSchema.default()
		local probs = HatchLogic.eggOdds("verdant_egg", p, 1)
		for i, e in ipairs(Eggs.Info.verdant_egg.entries) do
			t.near(probs[i].p, e.weight / 100, 1e-12, e.species)
		end
	end)

	t.test("Celestial do Ovo Astral exige condição de bestiário", function()
		local p = DataSchema.default()
		local probs = HatchLogic.eggOdds("astral_egg", p, 3)
		local cel
		for _, o in ipairs(probs) do
			if o.key == "celestara" then
				cel = o
			end
		end
		t.eq(cel.p, 0)
		t.ok(cel.reason ~= nil, "motivo exibido")
		for i = 1, 15 do
			p.bestiary.pets["sp" .. i] = { n = 1, first = 0, muts = {} }
		end
		probs = HatchLogic.eggOdds("astral_egg", p, 3)
		for _, o in ipairs(probs) do
			if o.key == "celestara" then
				cel = o
			end
		end
		t.ok(cel.p > 0, "liberado")
		t.ok(cel.p <= Rarities.Info.Celestial.maxChance, "teto celestial")
	end)

	t.test("rolagens reais batem com as probabilidades (estatístico, sorte 2)", function()
		local p = DataSchema.default()
		local probs = HatchLogic.eggOdds("grove_egg", p, 2)
		local rng = t.rng(7)
		local n, counts = 200000, {}
		for _ = 1, n do
			local sp = HatchLogic.roll("grove_egg", p, { PetVariant = 2, Mutation = 1 }, rng)
			counts[sp] = (counts[sp] or 0) + 1
		end
		for _, o in ipairs(probs) do
			local tol = math.max(0.004, 4 * math.sqrt(o.p * (1 - o.p) / n))
			t.near((counts[o.key] or 0) / n, o.p, tol, o.key)
		end
	end)

	t.test("chance de mutação respeita base e teto", function()
		t.near(HatchLogic.mutationChance(1), Mutations.BaseChance, 1e-12)
		t.near(HatchLogic.mutationChance(2), Mutations.BaseChance * 2, 1e-12)
		t.near(HatchLogic.mutationChance(1000), Mutations.MaxChance, 1e-12)
	end)

	t.test("mutações só aparecem nos mundos permitidos", function()
		local rng = t.rng(99)
		local seen = {}
		for _ = 1, 100000 do
			local m = HatchLogic.rollMutation("verdant", 3, rng)
			if m then
				seen[m] = true
			end
		end
		t.ok(seen.Golden and seen.Radiant and seen.Ancient, "esperadas")
		t.ok(not seen.Astral and not seen.Prismatic and not seen.Phantom, "proibidas em verdant")
	end)

	t.test("frequência de mutação bate com a chance", function()
		local rng = t.rng(1234)
		local n, hits = 200000, 0
		for _ = 1, n do
			if HatchLogic.rollMutation("astral", 1, rng) then
				hits += 1
			end
		end
		t.near(hits / n, Mutations.BaseChance, 0.002)
	end)

	t.test("existem pets SECRET e CELESTIAL obtíveis", function()
		local secret, celestial = 0, 0
		for id, egg in pairs(Eggs.Info) do
			for _, e in ipairs(egg.entries) do
				local r = Pets.Species[e.species].rarity
				if r == "Secret" then
					secret += 1
				elseif r == "Celestial" then
					celestial += 1
				end
			end
		end
		t.ok(secret >= 5, "secret")
		t.ok(celestial >= 2, "celestial")
	end)
end

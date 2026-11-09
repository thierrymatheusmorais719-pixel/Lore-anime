-- Testes dos ataques Assinatura (Config/Signatures).
local Shared = script.Parent.Parent
local Signatures = require(Shared.Config.Signatures)
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)

local SHAPES = {
	single = {}, cone = { "range", "angle" }, circle = { "radius" }, area = { "radius" }, line = { "length", "width" },
	chain = { "chain", "bounce" }, multi = { "targets", "range" }, tornado = { "radius" }, team = {},
}

-- dano "por alvo" de um Assinatura (golpes × poder), para conferir a escada de raridades
local function perTarget(s)
	return (s.power or 0) * (s.hits or 1)
end

return function(t)
	t.test("TODO pet (as 192 espécies) tem seu poder, e nenhum repete o de outro", function()
		local n, names = 0, {}
		for id in pairs(Pets.Species) do
			n += 1
			local s = Signatures.forSpecies(id)
			t.ok(s ~= nil, "sem poder: " .. id)
			if s then
				t.ok(names[s.name] == nil, "poder repetido: " .. s.name .. " (" .. id .. " e " .. tostring(names[s.name]) .. ")")
				names[s.name] = id
			end
		end
		t.ok(n >= 192, "esperava 192 espécies, achei " .. n)
	end)

	t.test("variantes da mesma família ganham temperos diferentes", function()
		local byFam = {}
		for id in pairs(Pets.Species) do
			local fam = id:match("^(.-)_%d+$")
			if fam and Signatures.Info[fam] then
				local s = Signatures.forSpecies(id)
				byFam[fam] = byFam[fam] or {}
				local tag = s.twist or "pura"
				t.ok(byFam[fam][tag] == nil, fam .. ": tempero repetido " .. tag)
				byFam[fam][tag] = true
				if s.twist then
					t.ok(s ~= Signatures.Info[fam] and s.name:find(" · ", 1, true) ~= nil, fam .. ": variante sem nome próprio")
				end
			end
		end
		t.ok(byFam.crystalfox ~= nil, "família de 12 variantes testada")
	end)

	t.test("Assinaturas têm forma, campos e números válidos (todas as espécies, com tempero)", function()
		local all = {}
		for id in pairs(Pets.Species) do
			all[id] = Signatures.forSpecies(id)
		end
		for key, s in pairs(all) do
			local need = SHAPES[s.shape]
			t.ok(need ~= nil, key .. ": forma desconhecida " .. tostring(s.shape))
			for _, f in ipairs(need or {}) do
				t.ok(type(s[f]) == "number" and s[f] > 0, key .. ": falta " .. f)
			end
			t.ok(type(s.name) == "string" and #s.name > 3 and type(s.desc) == "string" and type(s.vfx) == "string", key .. ": nome/descrição/efeito")
			t.ok(s.color ~= nil, key .. ": cor")
			if s.shape ~= "team" then
				t.ok((s.power or 0) > 0, key .. ": sem dano")
			else
				t.ok(s.heal or s.shield or s.atkBuff or s.haste, key .. ": ataque de equipe sem efeito")
			end
			if (s.hits or 1) > 1 then
				t.ok((s.interval or 0) > 0 and (s.hits - 1) * s.interval <= 8, key .. ": pulsos")
			end
			for _, f in ipairs({ "stun", "root" }) do
				t.ok(s[f] == nil or (s[f] > 0 and s[f] <= 2.5), key .. ": " .. f .. " longo demais")
			end
			if s.slow then
				t.ok(s.slow.amount > 0 and s.slow.amount <= 0.5, key .. ": lentidão")
			end
			if s.heal then
				t.ok(s.heal > 0 and s.heal <= 0.25, key .. ": cura")
			end
		end
	end)

	t.test("Fúria por raridade e força crescente (Comum < Raro < Lendário < Mítico, em média)", function()
		for r in pairs(Rarities.Info) do
			t.ok(Signatures.furyMax(r) >= 5 and Signatures.furyMax(r) <= 8, "fúria " .. r)
		end
		local sum, cnt = {}, {}
		for id, sp in pairs(Pets.Species) do
			local s = Signatures.forSpecies(id)
			if s and s.shape ~= "team" then
				local tier = (sp.rarity == "Common" or sp.rarity == "Uncommon") and 1 or (sp.rarity == "Rare" or sp.rarity == "Epic") and 2
					or (sp.rarity == "Legendary") and 3 or 4
				sum[tier] = (sum[tier] or 0) + perTarget(s)
				cnt[tier] = (cnt[tier] or 0) + 1
			end
		end
		local avg = {}
		for k = 1, 4 do
			avg[k] = sum[k] / cnt[k]
		end
		t.ok(avg[1] < avg[3] and avg[2] < avg[4] and avg[1] < avg[4], string.format("médias %.2f %.2f %.2f %.2f", avg[1], avg[2], avg[3], avg[4]))
	end)

	t.test("forSpecies acha a família pelo id da variante", function()
		t.ok(Signatures.forSpecies("kit_1") == Signatures.Info.kit)
		t.ok(Signatures.forSpecies("verdigris_wisp") == Signatures.Info.verdigris_wisp)
		t.ok(Signatures.forSpecies("nao_existe_9") == nil)
	end)
end

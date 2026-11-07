-- Teste de fumaça dos construtores 3D (roda com tools/run_tests.py --smoke).
-- Constrói TODOS os pets (com cada mutação e acessório), inimigos e bosses e verifica:
--   * PrimaryPart presente; toda peça (exceto o root) presa por exatamente um Motor6D
--   * nomes de peça únicos; contagem de peças dentro do orçamento
--   * mutação muda a aparência (cor/material/efeitos) sem mudar a contagem de juntas
local Pets = require(__proxy("Config/Pets"))
local Mutations = require(__proxy("Config/Mutations"))
local Items = require(__proxy("Config/Items"))
local Enemies = require(__proxy("Config/Enemies"))
local Bosses = require(__proxy("Config/Bosses"))
local CreatureBuilder = require(__proxy("Builders/CreatureBuilder"))
local MutationVisuals = require(__proxy("Builders/MutationVisuals"))
local Accessories = require(__proxy("Builders/Accessories"))
local EnemyModels = require(__proxy("Builders/EnemyModels"))
local BossModels = require(__proxy("Builders/BossModels"))

local failures, checks = 0, 0
local function fail(msg)
	failures += 1
	print("FALHOU " .. msg)
end

local function partsOf(model)
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function verify(label, model, budget)
	checks += 1
	if not model.PrimaryPart then
		fail(label .. ": sem PrimaryPart")
		return 0
	end
	local held = {}
	local names = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			if not d.Part0 or not d.Part1 then
				fail(label .. ": Motor6D sem peças " .. d.Name)
			else
				held[d.Part1] = (held[d.Part1] or 0) + 1
			end
		end
	end
	local parts = partsOf(model)
	for _, p in ipairs(parts) do
		if names[p.Name] then
			fail(label .. ": nome de peça repetido " .. p.Name)
		end
		names[p.Name] = true
		if p ~= model.PrimaryPart and held[p] ~= 1 then
			fail(string.format("%s: peça %s presa por %d juntas", label, p.Name, held[p] or 0))
		end
		if p.Size.X <= 0 or p.Size.Y <= 0 or p.Size.Z <= 0 then
			fail(label .. ": tamanho inválido em " .. p.Name)
		end
	end
	if #parts > budget then
		fail(string.format("%s: %d peças (orçamento %d)", label, #parts, budget))
	end
	return #parts
end

local function signature(model)
	local s = {}
	for _, p in ipairs(partsOf(model)) do
		table.insert(s, p.Name .. tostring(p.Material and p.Material.Name) .. string.format("%.2f%.2f%.2f%.2f", p.Color.R, p.Color.G, p.Color.B, p.Transparency or 0))
	end
	table.sort(s)
	return table.concat(s, "|")
end

local stats = { pets = 0, petParts = 0, maxPet = 0, enemies = 0, bosses = 0 }
for id, sp in pairs(Pets.Species) do
	local ok, err = pcall(function()
		local base = CreatureBuilder.build(id, sp, 1)
		local n = verify("pet " .. id, base, 140)
		stats.pets += 1
		stats.petParts += n
		stats.maxPet = math.max(stats.maxPet, n)
		local baseSig = signature(base)
		for _, mid in ipairs(Mutations.Order) do
			local m = CreatureBuilder.build(id, sp, 1.15)
			MutationVisuals.apply(m, mid)
			verify("pet " .. id .. " " .. mid, m, 170)
			checks += 1
			if signature(m) == baseSig then
				fail("mutação " .. mid .. " não mudou a aparência de " .. id)
			end
			if m:GetAttribute("Mutation") ~= mid then
				fail("atributo Mutation ausente em " .. id .. " " .. mid)
			end
		end
		for itemId, info in pairs(Items.Info) do
			if info.kind == "cosmetic" then
				local m = CreatureBuilder.build(id, sp, 1)
				Accessories.apply(m, itemId)
				verify("pet " .. id .. " + " .. itemId, m, 160)
			end
		end
	end)
	if not ok then
		fail("pet " .. id .. ": " .. tostring(err))
	end
end
for id, cfg in pairs(Enemies.Info) do
	local ok, err = pcall(function()
		local model, h, r = EnemyModels.build(id, cfg)
		verify("inimigo " .. id, model, 120)
		assert(type(h) == "number" and h > 0 and type(r) == "number" and r > 0, "altura/raio")
		assert(model.PrimaryPart.Name == "HumanoidRootPart", "root precisa se chamar HumanoidRootPart")
		stats.enemies += 1
	end)
	if not ok then
		fail("inimigo " .. id .. ": " .. tostring(err))
	end
end
for id in pairs(Bosses.Info) do
	local ok, err = pcall(function()
		local model, h, r = BossModels.build(id)
		local n = verify("boss " .. id, model, 280) -- um único boss por arena: mais detalhe permitido
		local size = model:GetExtentsSize()
		assert(math.max(size.X, size.Y, size.Z) >= 24 and size.Y >= 12, string.format("boss pequeno demais: %.0fx%.0fx%.0f", size.X, size.Y, size.Z))
		print(string.format("  boss %-15s %3d peças, %.0fx%.0fx%.0f studs", id, n, size.X, size.Y, size.Z))
		stats.bosses += 1
	end)
	if not ok then
		fail("boss " .. id .. ": " .. tostring(err))
	end
end
print(string.format("Construtores: %d pets (média %.0f peças, máx. %d), %d inimigos, %d bosses, %d verificações, %d falhas",
	stats.pets, stats.petParts / math.max(1, stats.pets), stats.maxPet, stats.enemies, stats.bosses, checks, failures))
if failures > 0 then
	error("SMOKE FALHOU")
end

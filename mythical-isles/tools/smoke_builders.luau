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
-- Malhas anatômicas (PetAnatomy): toda espécie tem esqueleto completo, malhas válidas e nada de "bolinha"
local PetAnatomy = require(__proxy("Builders/PetAnatomy"))
local MeshKit = require(__proxy("Builders/MeshKit"))
local meshStats = { species = 0, tris = 0, maxTris = 0, maxId = "", parts = 0, anat = {} }
local REQUIRED = {
	quad = { "Torso", "Neck", "Head", "Jaw", "UpperFL", "LowerFL", "FootFL", "UpperFR", "UpperBL", "UpperBR", "FootBR" },
	hop = { "Torso", "Head", "UpperFL", "UpperBL", "FootBL" },
	bird = { "Torso", "Head", "WingL", "WingR" },
	slither = { "Torso", "Head", "Jaw", "Seg1", "Seg6" },
	insect = { "Torso", "Head", "UpperFL", "UpperML", "UpperBR", "LowerBR" },
	biped = { "Torso" },
	bounce = { "Torso", "Face" },
	float = { "Torso", "Face", "Tail" },
}
for id, sp in pairs(Pets.Species) do
	checks += 1
	local ok, bp = pcall(PetAnatomy.blueprint, id, sp, 1)
	if not ok then
		fail("malha " .. id .. ": " .. tostring(bp))
	else
		meshStats.species += 1
		meshStats.anat[bp.anatomy] = (meshStats.anat[bp.anatomy] or 0) + 1
		local names, nTris = {}, 0
		local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
		for _, p in ipairs(bp.parts) do
			if names[p.name] then
				fail("malha " .. id .. ": parte repetida " .. p.name)
			end
			names[p.name] = true
			if p.parent and not names[p.parent] then
				fail("malha " .. id .. ": " .. p.name .. " antes do pai " .. tostring(p.parent))
			end
			local g = p.geom
			if #g.tris == 0 or #g.verts == 0 then
				fail("malha " .. id .. ": parte vazia " .. p.name)
			end
			for _, tri in ipairs(g.tris) do
				for k = 1, 3 do
					if tri[k] < 1 or tri[k] > #g.verts then
						fail("malha " .. id .. ": índice inválido em " .. p.name)
					end
				end
			end
			for i, v in ipairs(g.verts) do
				if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then
					fail("malha " .. id .. ": vértice NaN em " .. p.name)
					break
				end
				if not g.colors[i] then
					fail("malha " .. id .. ": vértice sem cor em " .. p.name)
					break
				end
				local w = v + p.pivot
				-- a silhueta é a do corpo (sem runas orbitando, auréola e fitas etéreas)
				if p.name ~= "OrbitRunes" and p.name ~= "Halo" and p.name ~= "SpiritRibbons" then
					x0, y0, z0 = math.min(x0, w.X), math.min(y0, w.Y), math.min(z0, w.Z)
					x1, y1, z1 = math.max(x1, w.X), math.max(y1, w.Y), math.max(z1, w.Z)
				end
			end
			nTris += #g.tris
		end
		for _, need in ipairs(REQUIRED[bp.gait] or {}) do
			if not names[need] then
				fail("malha " .. id .. " (" .. bp.gait .. "): falta a parte " .. need)
			end
		end
		-- não é "bolinha": várias partes articuladas e silhueta alongada em algum eixo
		local dims = { x1 - x0, y1 - y0, z1 - z0 }
		table.sort(dims)
		if #bp.parts < 6 or dims[3] / math.max(dims[1], 1e-3) < 1.3 then
			fail(string.format("malha %s: silhueta de bolinha (%d partes, proporção %.2f)", id, #bp.parts, dims[3] / math.max(dims[1], 1e-3)))
		end
		-- os pés tocam o chão (a altura da raiz bate com o ponto mais baixo da malha)
		if not bp.flies and math.abs(y0 + bp.hover) > 0.25 * bp.scale then
			fail(string.format("malha %s: pés fora do chão (base %.2f, altura da raiz %.2f)", id, y0, bp.hover))
		end
		if nTris > 18000 then
			fail(string.format("malha %s: %d triângulos (orçamento 18000)", id, nTris))
		end
		meshStats.tris += nTris
		meshStats.parts += #bp.parts
		if nTris > meshStats.maxTris then
			meshStats.maxTris, meshStats.maxId = nTris, id
		end
	end
end
-- modo de peças (sem EditableMesh): mesma anatomia em baixa resolução; cada triângulo vira 2 cunhas
local lowStats = { total = 0, max = 0, maxId = "" }
for id, sp in pairs(Pets.Species) do
	checks += 1
	local ok, bp = pcall(PetAnatomy.blueprint, id, sp, 1, { low = true })
	if not ok then
		fail("modo de peças " .. id .. ": " .. tostring(bp))
	else
		local n = PetAnatomy.triangles(bp, true)
		if n > 1600 then
			fail(string.format("modo de peças %s: %d triângulos (orçamento 1600 = ~3200 cunhas)", id, n))
		end
		lowStats.total += n
		if n > lowStats.max then
			lowStats.max, lowStats.maxId = n, id
		end
	end
end
print(string.format("Modo de peças: média %.0f triângulos por pet, máx. %d (%s)", lowStats.total / math.max(1, meshStats.species), lowStats.max, lowStats.maxId))
local anatList = {}
for k, n in pairs(meshStats.anat) do
	table.insert(anatList, k .. "=" .. n)
end
table.sort(anatList)
print(string.format("Malhas: %d espécies, %d anatomias, média %.0f triângulos e %.0f partes por pet, máx. %d (%s)", meshStats.species, #anatList,
	meshStats.tris / math.max(1, meshStats.species), meshStats.parts / math.max(1, meshStats.species), meshStats.maxTris, meshStats.maxId))
print("  anatomias: " .. table.concat(anatList, ", "))
local _ = MeshKit

print(string.format("Construtores: %d pets (média %.0f peças, máx. %d), %d inimigos, %d bosses, %d verificações, %d falhas",
	stats.pets, stats.petParts / math.max(1, stats.pets), stats.maxPet, stats.enemies, stats.bosses, checks, failures))
if failures > 0 then
	error("SMOKE FALHOU")
end

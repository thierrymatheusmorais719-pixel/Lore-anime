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
-- "Alta qualidade" do modo de peças (pets do próprio jogador no computador): mais faces, com teto
local hqStats = { total = 0, max = 0, maxId = "", n = 0 }
for id, sp in pairs(Pets.Species) do
	checks += 1
	local ok, bp = pcall(PetAnatomy.blueprint, id, sp, 1, { low = true, mid = true })
	if not ok then
		fail("alta qualidade " .. id .. ": " .. tostring(bp))
	else
		local n = PetAnatomy.triangles(bp, true)
		if n > 3400 then
			fail(string.format("alta qualidade %s: %d triângulos (orçamento 3400 = ~6800 cunhas)", id, n))
		end
		local nLow = PetAnatomy.triangles(PetAnatomy.blueprint(id, sp, 1, { low = true }), true)
		if n <= nLow then
			fail(string.format("alta qualidade %s não tem mais faces que o leve (%d <= %d)", id, n, nLow))
		end
		hqStats.total += n
		hqStats.n += 1
		if n > hqStats.max then
			hqStats.max, hqStats.maxId = n, id
		end
	end
end
print(string.format("Alta qualidade: média %.0f triângulos por pet, máx. %d (%s)", hqStats.total / math.max(1, hqStats.n), hqStats.max, hqStats.maxId))
local anatList = {}
for k, n in pairs(meshStats.anat) do
	table.insert(anatList, k .. "=" .. n)
end
table.sort(anatList)
print(string.format("Malhas: %d espécies, %d anatomias, média %.0f triângulos e %.0f partes por pet, máx. %d (%s)", meshStats.species, #anatList,
	meshStats.tris / math.max(1, meshStats.species), meshStats.parts / math.max(1, meshStats.species), meshStats.maxTris, meshStats.maxId))
print("  anatomias: " .. table.concat(anatList, ", "))
-- BOSSES NOVOS (BossAnatomy): mesmas juntas do modelo antigo (as animações dos bosses continuam),
-- pés no chão na altura do servidor, energia nas peças certas e orçamento dos dois modos
local BossAnatomy = require(__proxy("Builders/BossAnatomy"))
for id in pairs(Bosses.Info) do
	checks += 1
	local okOld, oldModel, oldH = pcall(BossModels.build, id)
	if not okOld then
		fail("boss antigo " .. id .. ": " .. tostring(oldModel))
		continue
	end
	local oldJoints, oldEnergy = {}, 0
	for _, d in ipairs(oldModel:GetDescendants()) do
		if d.ClassName == "Motor6D" and d.Name ~= "Fixed" then
			oldJoints[d.Name] = true
		elseif d:IsA("BasePart") and d:GetAttribute("EnergyFx") then
			oldEnergy += 1
		end
	end
	if not BossAnatomy.has(id) then
		fail("boss " .. id .. ": sem planta anatômica")
		continue
	end
	for _, low in ipairs({ false, true }) do
		local label = "boss novo " .. id .. (low and " (peças)" or " (malha)")
		local ok, bp = pcall(BossAnatomy.blueprint, id, { low = low })
		if not ok then
			fail(label .. ": " .. tostring(bp))
			continue
		end
		local names, joints, energy = {}, {}, 0
		local y0, y1 = math.huge, -math.huge
		for _, p in ipairs(bp.parts) do
			if names[p.name] then
				fail(label .. ": parte repetida " .. p.name)
			end
			names[p.name] = true
			if p.parent and not names[p.parent] then
				fail(label .. ": " .. p.name .. " antes do pai " .. tostring(p.parent))
			end
			if p.joint then
				joints[p.joint] = true
			end
			if p.attrs and p.attrs.EnergyFx then
				energy += 1
				if type(p.attrs.EnergyColor) ~= "table" and typeof(p.attrs.EnergyColor) ~= "Color3" or p.attrs.EnergyColor.R == nil then
					fail(label .. ": EnergyFx sem cor em " .. p.name)
				end
			end
			local g = p.geom
			if #g.tris == 0 then
				fail(label .. ": parte vazia " .. p.name)
			end
			for _, tri in ipairs(g.tris) do
				if tri[1] < 1 or tri[2] < 1 or tri[3] < 1 or tri[1] > #g.verts or tri[2] > #g.verts or tri[3] > #g.verts then
					fail(label .. ": índice inválido em " .. p.name)
					break
				end
			end
			for i, v in ipairs(g.verts) do
				if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z or not g.colors[i] then
					fail(label .. ": vértice inválido em " .. p.name)
					break
				end
				if p.name:sub(1, 5) ~= "Orbit" then
					y0, y1 = math.min(y0, v.Y + p.pivot.Y), math.max(y1, v.Y + p.pivot.Y)
				end
			end
		end
		for j in pairs(oldJoints) do
			if not joints[j] then
				fail(label .. ": falta a junta " .. j .. " (o Animator anima os bosses por ela)")
			end
		end
		if math.abs(bp.hover - oldH) > 1e-6 then
			fail(string.format("%s: altura da raiz %.2f diferente do servidor (%.2f)", label, bp.hover, oldH))
		end
		if math.abs(y0 + bp.hover) > 0.9 then
			fail(string.format("%s: pés fora do chão (base %.2f, raiz a %.2f do chão)", label, y0, bp.hover))
		end
		if y1 - y0 < 20 then
			fail(string.format("%s: pequeno demais (%.1f studs de altura)", label, y1 - y0))
		end
		if energy < math.min(oldEnergy, 5) then
			fail(string.format("%s: %d peças de energia (antigo tinha %d)", label, energy, oldEnergy))
		end
		local n = PetAnatomy.triangles(bp, low)
		if (low and n > 3400) or (not low and n > 20000) then
			fail(string.format("%s: %d triângulos (orçamento %d)", label, n, low and 3400 or 20000))
		end
		print(string.format("  boss novo %-15s %-7s %2d partes, %5d triângulos, %.0f studs de altura", id, low and "peças" or "malha", #bp.parts, n, y1 - y0))
	end
end
local _ = MeshKit

print(string.format("Construtores: %d pets (média %.0f peças, máx. %d), %d inimigos, %d bosses, %d verificações, %d falhas",
	stats.pets, stats.petParts / math.max(1, stats.pets), stats.maxPet, stats.enemies, stats.bosses, checks, failures))
if failures > 0 then
	error("SMOKE FALHOU")
end

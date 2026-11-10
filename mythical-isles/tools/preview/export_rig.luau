-- Exporta a anatomia COMPLETA de cada pet (malhas em alta resolução, pivôs, hierarquia, nomes das juntas e os
-- olhos) para o Blender montar o modelo contínuo com esqueleto (tools/blender/build_pets.py).
-- Uso: python3 tools/run_tests.py luau --rigexport [ids separados por vírgula em RIG_IDS]
--   saída: linhas "RIG <id> {json}" (coordenadas do Roblox: Y para cima, frente = -Z, em studs)

local Pets = require(__proxy("Config/Pets"))
local PetAnatomy = require(__proxy("Builders/PetAnatomy"))

local function num(x)
	return string.format("%.4f", x)
end
local function v3(v)
	return "[" .. num(v.X) .. "," .. num(v.Y) .. "," .. num(v.Z) .. "]"
end
local function c255(c)
	return string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local ids = {}
for id in pairs(Pets.Species) do
	table.insert(ids, id)
end
table.sort(ids)
local only = RIG_IDS
if only then
	ids = only
end

-- bosses: mesma planta (BossAnatomy), saem como "boss_<id>"
local BossAnatomy = require(__proxy("Builders/BossAnatomy"))
local BossIds = {}
if not only then
	for _, bid in ipairs(BossAnatomy.Ids) do
		table.insert(ids, "boss_" .. bid)
		BossIds["boss_" .. bid] = bid
	end
end

for _, id in ipairs(ids) do
	local sp = Pets.Species[id]
	if BossIds[id] then
		sp = { name = BossIds[id], rarity = "Boss", world = "bosses" }
	end
	if sp then
		local ok, bp
		if BossIds[id] then
			ok, bp = pcall(BossAnatomy.blueprint, BossIds[id], { low = false })
		else
			ok, bp = pcall(PetAnatomy.blueprint, id, sp, 1)
		end
		if not ok then
			print("RIGERR " .. id .. " " .. tostring(bp))
		else
			local parts = {}
			for _, p in ipairs(bp.parts) do
				local g = p.geom
				local v, c, t = {}, {}, {}
				local remap, k = {}, 0
				for i, tri in ipairs(g.tris) do
					if not g.keep or g.keep[i] then
						local idx = {}
						for q = 1, 3 do
							local vi = tri[q]
							if not remap[vi] then
								remap[vi] = k
								k += 1
								local w = g.verts[vi] + p.pivot
								v[#v + 1] = num(w.X) .. "," .. num(w.Y) .. "," .. num(w.Z)
								c[#c + 1] = c255(g.colors[vi])
							end
							idx[q] = remap[vi]
						end
						t[#t + 1] = string.format("%d,%d,%d", idx[1], idx[2], idx[3])
					end
				end
				if k > 0 then
					parts[#parts + 1] = string.format('{"n":"%s","parent":%s,"joint":%s,"pivot":%s,"role":"%s","m":"%s","tr":%s,"v":[%s],"c":[%s],"t":[%s]}', p.name,
						p.parent and ('"' .. p.parent .. '"') or "null", p.joint and ('"' .. p.joint .. '"') or "null", v3(p.pivot), p.role or "Body", p.material,
						num(p.transparency or 0), table.concat(v, ","), table.concat(c, ","), table.concat(t, ","))
				end
			end
			local eyes = {}
			for _, e in ipairs(bp.eyeSpecs or {}) do
				eyes[#eyes + 1] = string.format('{"c":%s,"n":%s,"r":%s,"iris":[%s],"glow":%s,"slit":%s,"tall":%s,"sclera":%s,"part":"%s"}', v3(e.c), v3(e.n), num(e.r), c255(e.iris),
					tostring(e.glow), tostring(e.slit), num(e.tall), e.sclera and ("[" .. c255(e.sclera) .. "]") or "null", tostring(e.part))
			end
			print(string.format('RIG %s {"id":"%s","name":"%s","rarity":"%s","world":"%s","anatomy":"%s","gait":"%s","hover":%s,"flies":%s,"parts":[%s],"eyes":[%s]}', id, id,
				sp.name or id, sp.rarity, sp.world or "", tostring(bp.anatomy or "boss"), tostring(bp.gait or "boss"), num(bp.hover or 0), tostring(bp.flies == true), table.concat(parts, ","), table.concat(eyes, ",")))
		end
	end
end
print("RIGEXPORT ok")

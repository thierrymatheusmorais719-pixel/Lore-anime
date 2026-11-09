-- Exporta as malhas dos pets (PetAnatomy) montadas na pose de repouso, para a prévia em three.js.
-- Uso: python3 tools/run_tests.py luau --petexport > saida.txt  (linhas "PETMESH <id> {json}")
local Pets = require(__proxy("Config/Pets"))
local PetAnatomy = require(__proxy("Builders/PetAnatomy"))

local function num(x)
	return string.format("%.3f", x)
end

local ONLY = {}
for id in (os.getenv and os.getenv("PET_ONLY") or ""):gmatch("[^,]+") do
	ONLY[id] = true
end
local ids = {}
for id in pairs(Pets.Species) do
	table.insert(ids, id)
end
table.sort(ids)
local total, maxTris, maxId = 0, 0, ""
for _, id in ipairs(ids) do
	local ok, bp = pcall(PetAnatomy.blueprint, id, Pets.Species[id], 1)
	if not ok then
		print("ERRO " .. id .. ": " .. tostring(bp))
	else
		local tris = PetAnatomy.triangles(bp)
		total += tris
		if tris > maxTris then
			maxTris, maxId = tris, id
		end
		local parts = {}
		for _, p in ipairs(bp.parts) do
			local v, c, t = {}, {}, {}
			for i, q in ipairs(p.geom.verts) do
				local w = q + p.pivot
				v[#v + 1] = num(w.X) .. "," .. num(w.Y + bp.hover) .. "," .. num(w.Z)
				local col = p.geom.colors[i]
				c[#c + 1] = string.format("%d,%d,%d", math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5))
			end
			for _, tri in ipairs(p.geom.tris) do
				t[#t + 1] = string.format("%d,%d,%d", tri[1] - 1, tri[2] - 1, tri[3] - 1)
			end
			parts[#parts + 1] = string.format('{"n":"%s","m":"%s","tr":%s,"flat":%s,"v":[%s],"c":[%s],"t":[%s]}', p.name, p.material, num(p.transparency), p.geom.flat and "true" or "false",
				table.concat(v, ","), table.concat(c, ","), table.concat(t, ","))
		end
		print(string.format('PETMESH %s {"id":"%s","anatomy":"%s","gait":"%s","rarity":"%s","hover":%s,"tris":%d,"parts":[%s]}', id, id, bp.anatomy, bp.gait, Pets.Species[id].rarity,
			num(bp.hover), tris, table.concat(parts, ",")))
	end
end
print(string.format("RESUMO %d espécies, %d triângulos no total, máximo %d (%s)", #ids, total, maxTris, maxId))

-- modo de peças (sem EditableMesh): elipsoides lisos (Builders/Smooth), como no jogo. Para a prévia cada
-- elipsoide vira uma esfera de triângulos com sombreamento suave.
local Smooth = require(__proxy("Builders/Smooth"))
for _, id in ipairs({ "kit_1", "leafcat_1", "verdantwolf_1", "astral_lion", "grovestag_1", "owlet_1", "zephyr_hawk", "turfmammoth_1", "leafpanda_1", "berrygoat_1",
	"glassserpent_1", "drakeling_1", "sylvanox", "mossape_1", "cap_1", "beetle_1", "hop_1", "lilyfrog_1", "ferret_1", "crystalgriffin_1" }) do
	local sp = Pets.Species[id]
	if sp then
		for _, hq in ipairs({ false, true }) do
			local bp = PetAnatomy.blueprint(id, sp, 1, { low = true, mid = hq })
			local byPart, total = Smooth.forBlueprint(bp, hq and "high" or nil)
			local parts = {}
			for _, p in ipairs(bp.parts) do
				local v, c, t = {}, {}, {}
				local k = 0
				for _, b in ipairs(byPart[p.name] or {}) do
					local verts, tris = Smooth.ellipsoidMesh(b)
					local col = string.format("%d,%d,%d", math.floor(b.color.R * 255 + 0.5), math.floor(b.color.G * 255 + 0.5), math.floor(b.color.B * 255 + 0.5))
					for _, w in ipairs(verts) do
						v[#v + 1] = num(w.X) .. "," .. num(w.Y + bp.hover) .. "," .. num(w.Z)
						c[#c + 1] = col
					end
					for _, tr in ipairs(tris) do
						t[#t + 1] = string.format("%d,%d,%d", k + tr[1] - 1, k + tr[2] - 1, k + tr[3] - 1)
					end
					k += #verts
				end
				if k > 0 then
					parts[#parts + 1] = string.format('{"n":"%s","m":"%s","tr":%s,"v":[%s],"c":[%s],"t":[%s]}', p.name, (p.material == "Fabric" or p.material == "Grass") and "SmoothPlastic" or p.material,
						num(p.transparency), table.concat(v, ","), table.concat(c, ","), table.concat(t, ","))
				end
			end
			print(string.format('PETMESH %s__%s {"id":"%s","anatomy":"%s","gait":"%s","rarity":"%s","hover":%s,"tris":%d,"parts":[%s]}', id, hq and "hq" or "low", id, bp.anatomy, bp.gait,
				sp.rarity, num(bp.hover), total, table.concat(parts, ",")))
		end
	end
end

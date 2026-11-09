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

-- modo de peças (low-poly): uma cor por face, como no jogo (cada triângulo = 2 cunhas de uma cor)
local MeshKit = require(__proxy("Builders/MeshKit"))
local Facets = require(__proxy("Builders/Facets"))
for _, id in ipairs({ "kit_1", "leafcat_1", "verdantwolf_1", "astral_lion", "grovestag_1", "owlet_1", "zephyr_hawk", "turfmammoth_1", "leafpanda_1", "berrygoat_1",
	"glassserpent_1", "drakeling_1", "sylvanox", "mossape_1", "cap_1", "beetle_1" }) do
	local sp = Pets.Species[id]
	if sp then
	  for _, hq in ipairs({ false, true }) do
		local bp = PetAnatomy.blueprint(id, sp, 1, { low = true, mid = hq })
		local parts = {}
		local yLo, yHi = Facets.heightRange(bp)
		for _, p in ipairs(bp.parts) do
			local v, c, t = {}, {}, {}
			local g = p.geom
			local k = 0
			local shade = p.material ~= "Neon" and p.transparency < 0.3 and p.material ~= "ForceField"
			for i, tri in ipairs(g.tris) do
				if not g.keep or g.keep[i] then
					local ca, cb, cc = g.colors[tri[1]], g.colors[tri[2]], g.colors[tri[3]]
					local r, gg, bb = (ca.R + cb.R + cc.R) / 3, (ca.G + cb.G + cc.G) / 3, (ca.B + cb.B + cc.B) / 3
					if shade then
						local cy = (g.verts[tri[1]].Y + g.verts[tri[2]].Y + g.verts[tri[3]].Y) / 3 + p.pivot.Y
						r, gg, bb = Facets.toonRGB(r, gg, bb, (cy - yLo) / (yHi - yLo))
						do
							local L = Facets.faceLight(g.verts[tri[1]], g.verts[tri[2]], g.verts[tri[3]], Facets.geomCenter(g))
							r, gg, bb = math.clamp(r * L, 0, 1), math.clamp(gg * L, 0, 1), math.clamp(bb * L, 0, 1)
						end
					end
					local col = string.format("%d,%d,%d", math.floor(r * 255 + 0.5), math.floor(gg * 255 + 0.5), math.floor(bb * 255 + 0.5))
					for q = 1, 3 do
						local w = g.verts[tri[q]] + p.pivot
						v[#v + 1] = num(w.X) .. "," .. num(w.Y + bp.hover) .. "," .. num(w.Z)
						c[#c + 1] = col
					end
					t[#t + 1] = string.format("%d,%d,%d", k, k + 1, k + 2)
					k += 3
				end
			end
			if k > 0 then
				parts[#parts + 1] = string.format('{"n":"%s","m":"%s","tr":%s,"flat":true,"twoSided":true,"v":[%s],"c":[%s],"t":[%s]}', p.name, (p.material == "Fabric" or p.material == "Grass") and "SmoothPlastic" or p.material,
					num(p.transparency), table.concat(v, ","), table.concat(c, ","), table.concat(t, ","))
			end
		end
		print(string.format('PETMESH %s__%s {"id":"%s","anatomy":"%s","gait":"%s","rarity":"%s","hover":%s,"tris":%d,"parts":[%s]}', id, hq and "hq" or "low", id, bp.anatomy, bp.gait,
			sp.rarity, num(bp.hover), PetAnatomy.triangles(bp, true), table.concat(parts, ",")))
	  end
	end
end

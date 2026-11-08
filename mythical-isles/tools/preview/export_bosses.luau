-- Exporta as malhas dos bosses (BossAnatomy) na pose de repouso, para a prévia em three.js.
-- Uso: python3 tools/run_tests.py luau --bossexport > saida.txt  (linhas "PETMESH boss_<id>[__low] {json}")
local BossAnatomy = require(__proxy("Builders/BossAnatomy"))
local PetAnatomy = require(__proxy("Builders/PetAnatomy"))

local function num(x)
	return string.format("%.3f", x)
end

local function col255(c)
	return string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

for _, id in ipairs(BossAnatomy.Ids) do
	for _, low in ipairs({ false, true }) do
		local t0 = os.clock()
		local bp = BossAnatomy.blueprint(id, { low = low })
		local parts = {}
		for _, p in ipairs(bp.parts) do
			local v, c, t = {}, {}, {}
			local g = p.geom
			if low then
				-- modo de peças: uma cor por face (cada triângulo = cunhas de uma cor)
				local k = 0
				for i, tri in ipairs(g.tris) do
					if not g.keep or g.keep[i] then
						local ca, cb, cc = g.colors[tri[1]], g.colors[tri[2]], g.colors[tri[3]]
						local cs = col255({ R = (ca.R + cb.R + cc.R) / 3, G = (ca.G + cb.G + cc.G) / 3, B = (ca.B + cb.B + cc.B) / 3 })
						for q = 1, 3 do
							local w = g.verts[tri[q]] + p.pivot
							v[#v + 1] = num(w.X) .. "," .. num(w.Y + bp.hover) .. "," .. num(w.Z)
							c[#c + 1] = cs
						end
						t[#t + 1] = string.format("%d,%d,%d", k, k + 1, k + 2)
						k += 3
					end
				end
			else
				for i, q in ipairs(g.verts) do
					local w = q + p.pivot
					v[#v + 1] = num(w.X) .. "," .. num(w.Y + bp.hover) .. "," .. num(w.Z)
					c[#c + 1] = col255(g.colors[i])
				end
				for _, tri in ipairs(g.tris) do
					t[#t + 1] = string.format("%d,%d,%d", tri[1] - 1, tri[2] - 1, tri[3] - 1)
				end
			end
			if #t > 0 then
				parts[#parts + 1] = string.format('{"n":"%s","m":"%s","tr":%s,"flat":%s,"twoSided":%s,"v":[%s],"c":[%s],"t":[%s]}', p.name,
					(low and p.material == "Fabric") and "SmoothPlastic" or p.material, num(p.transparency), (low or g.flat) and "true" or "false", low and "true" or "false",
					table.concat(v, ","), table.concat(c, ","), table.concat(t, ","))
			end
		end
		local tris = PetAnatomy.triangles(bp, low)
		print(string.format("RESUMO %s%s: %d peças, %d triângulos, %.2fs", id, low and " (peças)" or " (malha)", #bp.parts, tris, os.clock() - t0))
		print(string.format('PETMESH boss_%s%s {"id":"%s","anatomy":"boss","gait":"boss","rarity":"Boss","hover":%s,"tris":%d,"parts":[%s]}', id, low and "__low" or "", id,
			num(bp.hover), tris, table.concat(parts, ",")))
	end
end

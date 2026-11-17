-- PÉS NO CHÃO dos pets (malha do cliente, modo de peças e malhas): o visual fica bp.hover acima do chão, então o
-- vértice mais baixo da malha em repouso deve estar em −bp.hover (relativo à raiz). Lista quem flutua ou afunda.
-- Uso: python3 tools/run_tests.py luau --petground
local Pets = require(__proxy("Shared/Config/Pets"))
local PetAnatomy = require(__proxy("Shared/Builders/PetAnatomy"))
local ids = {}
for id in pairs(Pets.Species) do
	table.insert(ids, id)
end
table.sort(ids)
local rows = {}
local worstF, worstS = 0, 0
for _, sid in ipairs(ids) do
	local bp = PetAnatomy.blueprint(sid, Pets.Species[sid], 1, { low = true })
	if not bp.flies and bp.gait ~= "float" then
		local low = math.huge
		for _, p in ipairs(bp.parts) do
			if (p.transparency or 0) < 0.9 then
				for _, v in ipairs(p.geom.verts) do
					local y = v.Y + p.pivot.Y
					if y < low then
						low = y
					end
				end
			end
		end
		local err = low + bp.hover -- > 0 flutua, < 0 afunda
		table.insert(rows, { sid, err, bp.gait, bp.anatomy, bp.hover })
		worstF = math.max(worstF, err)
		worstS = math.min(worstS, err)
	end
end
table.sort(rows, function(a, b)
	return math.abs(a[2]) > math.abs(b[2])
end)
for i = 1, math.min(15, #rows) do
	local r = rows[i]
	print(string.format("PETGROUND %-20s %+.3f (%s/%s, hover %.2f)", r[1], r[2], r[3], r[4], r[5]))
end
local bad = 0
for _, r in ipairs(rows) do
	if math.abs(r[2]) > 0.08 then
		bad += 1
	end
end
print(string.format("PETGROUND %d espécies que andam; pior flutuando %+.3f, pior afundando %+.3f; %d fora de ±0,08", #rows, worstF, worstS, bad))

-- Exporta quadros da animação REAL dos pets (Client/Controllers/CreatureMotion) para a prévia 3D.
-- Monta o esqueleto do pet (as mesmas juntas Motor6D do PetMesh, modo de peças), roda o CreatureMotion
-- quadro a quadro no relógio do simulador e aplica as juntas na malha (cinemática direta):
--   parte posada = D(pai) · T(pivô) · Transform da junta · T(−pivô) · vértice
-- Uso: python3 tools/run_tests.py luau --animexport  (linhas "PETMESH anim_<espécie>_<ação>_<n> {json}")

local Pets = require(__proxy("Shared/Config/Pets"))
local PetAnatomy = require(__proxy("Shared/Builders/PetAnatomy"))
local Facets = require(__proxy("Shared/Builders/Facets"))
local CreatureMotion = require(__proxy("Client/Controllers/CreatureMotion"))
local MeshKit = require(__proxy("Shared/Builders/MeshKit"))

local function num(x)
	return string.format("%.3f", x)
end

-- uma espécie de cada anatomia principal (os comportamentos dependem do jeito de andar + anatomia)
local SPECIES = { "kit_1", "leafcat_1", "hop_1", "owlet_1", "mossape_1", "glassserpent_1", "cap_1", "verdantwolf_1", "grovestag_1", "turfmammoth_1",
	"drakeling_1", "beetle_1", "astral_lion" }
local FRAMES = 4

-- monta o "modelo" com as juntas, como o PetMesh.assemble (sem as cunhas: a malha vem da planta)
local function rig(bp)
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "Root"
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local motors, made = {}, {}
	for _, p in ipairs(bp.parts) do
		-- osso como no PetMesh (modo de peças): caixa da geometria, centrada nela
		local mn, mx = MeshKit.bounds(p.geom)
		local part = Instance.new("Part")
		part.Name = p.name
		part.Size = Vector3.new(math.max(mx.X - mn.X, 0.2), math.max(mx.Y - mn.Y, 0.2), math.max(mx.Z - mn.Z, 0.2))
		part.CFrame = CFrame.new(p.pivot + (mn + mx) / 2)
		for k, v in pairs(p.attrs or {}) do
			part:SetAttribute(k, v)
		end
		part.Parent = model
		made[p.name] = part
	end
	for _, p in ipairs(bp.parts) do
		local part = made[p.name]
		local parentPart = (p.parent and made[p.parent]) or root
		local m = Instance.new("Motor6D")
		m.Name = p.joint or "Fixed"
		m.Part0 = parentPart
		m.Part1 = part
		m.C0 = parentPart.CFrame:Inverse() * CFrame.new(p.pivot)
		m.C1 = part.CFrame:Inverse() * CFrame.new(p.pivot)
		m.Transform = CFrame.identity
		m.Parent = part
		motors[p.name] = m
	end
	model:SetAttribute("Gait", bp.gait)
	model:SetAttribute("Anatomy", bp.anatomy)
	model:SetAttribute("Heavy", bp.heavy == true)
	model:SetAttribute("Flies", bp.flies == true)
	model:SetAttribute("Hover", bp.hover)
	return model, root, motors
end

local function posedJson(bp, motors, id: string)
	local D = {}
	local yLo, yHi = Facets.heightRange(bp)
	local parts = {}
	local tris = 0
	for _, p in ipairs(bp.parts) do
		local parentD = (p.parent and D[p.parent]) or CFrame.identity
		local m = motors[p.name]
		local tr = (m and m.Name ~= "Fixed") and m.Transform or CFrame.identity
		local d = parentD * CFrame.new(p.pivot) * tr * CFrame.new(-p.pivot)
		D[p.name] = d
		local g = p.geom
		local v, c, t = {}, {}, {}
		local k = 0
		local shade = p.material ~= "Neon" and p.transparency < 0.3 and p.material ~= "ForceField"
		for i, tri in ipairs(g.tris) do
			if not g.keep or g.keep[i] then
				local ca, cb, cc = g.colors[tri[1]], g.colors[tri[2]], g.colors[tri[3]]
				local r, gg, bb = (ca.R + cb.R + cc.R) / 3, (ca.G + cb.G + cc.G) / 3, (ca.B + cb.B + cc.B) / 3
				if shade then
					local cy = (g.verts[tri[1]].Y + g.verts[tri[2]].Y + g.verts[tri[3]].Y) / 3 + p.pivot.Y
					r, gg, bb = Facets.toonRGB(r, gg, bb, (cy - yLo) / (yHi - yLo))
				end
				local col = string.format("%d,%d,%d", math.floor(r * 255 + 0.5), math.floor(gg * 255 + 0.5), math.floor(bb * 255 + 0.5))
				for q = 1, 3 do
					local w = d * (g.verts[tri[q]] + p.pivot)
					v[#v + 1] = num(w.X) .. "," .. num(w.Y + bp.hover) .. "," .. num(w.Z)
					c[#c + 1] = col
				end
				t[#t + 1] = string.format("%d,%d,%d", k, k + 1, k + 2)
				k += 3
				tris += 1
			end
		end
		if k > 0 then
			parts[#parts + 1] = string.format('{"n":"%s","m":"%s","tr":%s,"flat":true,"twoSided":true,"v":[%s],"c":[%s],"t":[%s]}', p.name,
				(p.material == "Fabric" or p.material == "Grass") and "SmoothPlastic" or p.material, num(p.transparency), table.concat(v, ","), table.concat(c, ","), table.concat(t, ","))
		end
	end
	return string.format('PETMESH %s {"id":"%s","anatomy":"%s","gait":"%s","rarity":"anim","hover":%s,"tris":%d,"parts":[%s]}', id, id, bp.anatomy, bp.gait, num(bp.hover), tris,
		table.concat(parts, ","))
end

local DT = 1 / 30
for _, sid in ipairs(SPECIES) do
	local sp = Pets.Species[sid]
	if sp then
		local bp = PetAnatomy.blueprint(sid, sp, 1, { low = true })
		local list = { "rest" }
		for _, a in ipairs(CreatureMotion.actsFor(bp.gait, bp.anatomy, bp.flies == true)) do
			table.insert(list, a[1])
		end
		for _, extra in ipairs({ "sleep", "levelup", "signature" }) do
			table.insert(list, extra)
		end
		print(string.format("ANIM %s gait=%s acts=%s", sid, bp.gait, table.concat(list, ",")))
		for _, act in ipairs(list) do
			local model, root, motors = rig(bp)
			-- escala = altura real do pet (no jogo vem de GetExtentsSize das peças; aqui, da malha)
			local lo, hi = Facets.heightRange(bp)
			local entry = { model = model, root = root, joints = {}, lastPos = root.Position, speed = 0, seed = 0, scale = math.max(hi - lo, 1), faded = false }
			CreatureMotion.prepare(entry)
			local function step(n)
				for _ = 1, n do
					SIM.run(DT)
					CreatureMotion.animate(entry, os.clock(), DT, workspace:GetServerTimeNow(), nil)
				end
			end
			step(2)
			local dur = 1.6
			if act == "sleep" then
				CreatureMotion.forceAct(entry, "sleep")
				step(math.floor(4 / DT))
				dur = 0.01
			elseif act == "signature" then
				model:SetAttribute("Action", "Cast")
				model:SetAttribute("ActionAt", workspace:GetServerTimeNow())
				dur = 0.9
			elseif act == "levelup" then
				CreatureMotion.forceAct(entry, "levelup")
			elseif act ~= "rest" then
				CreatureMotion.forceAct(entry, act)
				dur = entry.act and entry.act.dur or 2
			end
			-- amostras espalhadas pela duração (no sono: quadros parados)
			local elapsed = 0
			for f = 1, FRAMES do
				local target = act == "sleep" and f * 0.5 or dur * (f - 0.5) / FRAMES
				local n = math.max(1, math.floor((target - elapsed) / DT + 0.5))
				step(n)
				elapsed += n * DT
				print(posedJson(bp, motors, string.format("anim_%s_%s_%d", sid, act, f)))
			end
		end
	end
end
print("ANIMEXPORT ok")

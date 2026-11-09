-- VERIFICA AS ANIMAÇÕES DE TODOS OS PETS (as 192 espécies), rodando o CreatureMotion REAL no esqueleto de
-- cada uma (o mesmo do PetMesh, modo de peças):
--   * cada comportamento ocioso da espécie (jeito de andar + anatomia) muda a pose;
--   * nenhuma junta recebe valor inválido (NaN/infinito);
--   * nenhuma pose afunda o corpo no chão (ponto mais baixo das partes de apoio ≥ o de repouso − 6% da altura);
--   * dormir: a barriga encosta no chão (quem dorme); subir de nível e a Assinatura mexem a pose.
-- Uso: python3 tools/run_tests.py luau --animcheck
local Pets = require(__proxy("Shared/Config/Pets"))
local PetAnatomy = require(__proxy("Shared/Builders/PetAnatomy"))
local Facets = require(__proxy("Shared/Builders/Facets"))
local MeshKit = require(__proxy("Shared/Builders/MeshKit"))
local CreatureMotion = require(__proxy("Client/Controllers/CreatureMotion"))

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


local DT = 1 / 30
local ids = {}
for id in pairs(Pets.Species) do
	table.insert(ids, id)
end
table.sort(ids)
local species, acts, fails = 0, 0, 0
local perAct = {}
local function bad(cf: CFrame): boolean
	for _, v in ipairs({ cf.Position, cf.LookVector, cf.UpVector }) do
		for _, c in ipairs({ v.X, v.Y, v.Z }) do
			if c ~= c or math.abs(c) == math.huge then
				return true
			end
		end
	end
	return false
end
for _, sid in ipairs(ids) do
	local bp = PetAnatomy.blueprint(sid, Pets.Species[sid], 1, { low = true })
	species += 1
	local lo, hi = Facets.heightRange(bp)
	local height = math.max(hi - lo, 1)
	local list = { "sleep", "levelup", "signature" }
	for _, a in ipairs(CreatureMotion.actsFor(bp.gait, bp.anatomy, bp.flies == true)) do
		table.insert(list, a[1])
	end
	for _, act in ipairs(list) do
		local model, root, motors = rig(bp)
		local entry = { model = model, root = root, joints = {}, lastPos = root.Position, speed = 0, seed = 0, scale = height, faded = false }
		local ok, err = pcall(function()
			CreatureMotion.prepare(entry)
			local function step(n)
				for _ = 1, n do
					SIM.run(DT)
					CreatureMotion.animate(entry, os.clock(), DT, workspace:GetServerTimeNow(), nil)
				end
			end
			step(3)
			local rest = {}
			for name, m in pairs(motors) do
				rest[name] = m.Transform
			end
			local dur = 1.6
			if act == "sleep" then
				CreatureMotion.forceAct(entry, "sleep")
				dur = 4
			elseif act == "signature" then
				model:SetAttribute("Action", "Cast")
				model:SetAttribute("ActionAt", workspace:GetServerTimeNow())
				dur = 0.45
			elseif act == "levelup" then
				CreatureMotion.forceAct(entry, "levelup")
				dur = 0.4
			else
				CreatureMotion.forceAct(entry, act)
				dur = (entry.act and entry.act.dur or 2) * 0.5
			end
			local worst = math.huge
			local changed, nan = 0, false
			local n = math.max(1, math.floor(dur / DT))
			for i = 1, n do
				step(1)
				for _, m in pairs(motors) do
					if bad(m.Transform) then
						nan = true
					end
				end
				if i >= n * 0.4 then
					worst = math.min(worst, CreatureMotion.lowestPoint(entry))
				end
			end
			for name, m in pairs(motors) do
				local r = rest[name]
				if (m.Transform.Position - r.Position).Magnitude > 0.01 or (m.Transform.LookVector - r.LookVector).Magnitude > 0.06 or (m.Transform.UpVector - r.UpVector).Magnitude > 0.06 then
					changed += 1
				end
			end
			local canSleep = not entry.flies and entry.gait ~= "float" and entry.gait ~= "bounce"
			local problems = {}
			if nan then
				table.insert(problems, "valor inválido")
			end
			-- (slimes têm uma junta só: o corpo inteiro é a animação)
			local need = math.min(2, #entry.mjoints)
			if changed < need and not (act == "sleep" and not canSleep) then
				table.insert(problems, "pose quase não muda (" .. changed .. " juntas)")
			end
			local sink = entry.restLow - worst
			if act ~= "sleep" and sink > height * 0.06 then
				table.insert(problems, string.format("afunda %.2f no chão", sink))
			end
			if act == "sleep" and canSleep then
				local core = CreatureMotion.lowestPoint(entry, false, true)
				if math.abs(core - entry.restLow) > height * 0.08 then
					table.insert(problems, string.format("dormindo, barriga a %.2f do chão", core - entry.restLow))
				end
				if not entry.snore then
					table.insert(problems, "sem Zzz")
				end
			end
			if #problems > 0 then
				error(table.concat(problems, "; "), 0)
			end
		end)
		acts += 1
		perAct[act] = (perAct[act] or 0) + 1
		if not ok then
			fails += 1
			print(string.format("FALHOU  %s (%s/%s) %s: %s", sid, bp.gait, bp.anatomy, act, tostring(err)))
		end
	end
end
local names = {}
for k, v in pairs(perAct) do
	table.insert(names, k .. "×" .. v)
end
table.sort(names)
print("comportamentos verificados: " .. table.concat(names, ", "))
print(string.format("Animações: %d espécies, %d animações verificadas, %d falhas", species, acts, fails))
if fails > 0 then
	error("ANIMAÇÕES FALHARAM")
end

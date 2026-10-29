local Timeline = require("Timeline")
local StateMachine = require("StateMachine")
local AbilityMath = require("AbilityMath")
local PoseDriver = require("PoseDriver")

local passed, failed = 0, {}
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then passed += 1 else table.insert(failed, name .. ": " .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " esperado " .. tostring(b) .. " obtido " .. tostring(a), 2) end end
local function near(a, b, tol, msg) if math.abs(a - b) > (tol or 1e-6) then error((msg or "") .. " esperado ~" .. tostring(b) .. " obtido " .. tostring(a), 2) end end
local V = Vector3.new

-- Timeline ---------------------------------------------------------------------------------
test("timeline: estrutura válida (ordem, planos contíguos, duração)", function()
	local p = Timeline.validate()
	eq(#p, 0, table.concat(p, "; "))
end)
test("timeline: cada evento dispara exatamente uma vez ao varrer o tempo", function()
	local counts = {}
	local prev = -0.001
	local t = 0
	while t <= Timeline.Duration + 0.5 do
		for _, ev in Timeline.eventsBetween(prev, t) do counts[ev] = (counts[ev] or 0) + 1 end
		prev = t
		t += 1 / 60
	end
	for _, ev in Timeline.Events do eq(counts[ev], 1, ev.name .. "@" .. ev.t) end
end)
test("timeline: varredura com saltos grandes (lag) não perde nem duplica eventos", function()
	local counts, prev = {}, -0.001
	for _, t in { 0.4, 3.9, 4.0, 11.0, 19.7, 25, 31 } do
		for _, ev in Timeline.eventsBetween(prev, t) do counts[ev] = (counts[ev] or 0) + 1 end
		prev = t
	end
	for _, ev in Timeline.Events do eq(counts[ev], 1, ev.name) end
end)
test("timeline: eventos-chave existem e na ordem certa", function()
	local at = {}
	for _, ev in Timeline.Events do at[ev.name] = at[ev.name] or ev.t end
	assert(at.LockControls == 0)
	assert(at.MorphSwap > at.WhiteOut, "troca de modelo deve ocorrer DENTRO do branco")
	assert(at.MorphSwap < at.WhiteOutEnd)
	assert(at.ReleaseImpact > at.WhiteOutEnd)
	assert(at.EnableAbility > at.ReleaseImpact)
	assert(at.End == Timeline.Duration)
end)
test("timeline: getShot cobre todo o intervalo e alpha em [0,1]", function()
	local t = 0
	while t <= Timeline.Duration do
		local s, a = Timeline.getShot(t)
		assert(s ~= nil, "sem plano em t=" .. t)
		assert(a >= 0 and a <= 1)
		t += 0.05
	end
end)
test("timeline: ease monotônico e limites 0/1", function()
	for _, k in { "Linear", "Sine", "Quad", "Expo" } do
		eq(Timeline.ease(k, 0), 0, k)
		near(Timeline.ease(k, 1), 1, 1e-9, k)
		local last = -1
		for i = 0, 100 do
			local v = Timeline.ease(k, i / 100)
			assert(v >= last - 1e-9, k .. " não monotônico")
			last = v
		end
	end
end)
test("timeline: fases cobrem 0..Duration sem lacunas", function()
	local cursor = 0
	for _, p in Timeline.Phases do eq(p.start, cursor, p.name); cursor = p.finish end
	eq(cursor, Timeline.Duration)
end)

-- StateMachine -------------------------------------------------------------------------------
test("state machine: fluxo normal", function()
	local m = StateMachine.new()
	assert(m:transition("Starting"))
	assert(m:transition("Running"))
	assert(m:transition("Climax"))
	assert(m:transition("Finishing"))
	assert(m:transition("Idle"))
	eq(m.state, "Idle")
end)
test("state machine: transições inválidas são recusadas", function()
	local m = StateMachine.new()
	assert(not m:transition("Running"))
	assert(not m:transition("Climax"))
	m:transition("Starting")
	assert(not m:transition("Climax"))
	eq(m.state, "Starting")
end)
test("state machine: cancelamento de qualquer estado ativo volta a Idle", function()
	for _, path in { { "Starting" }, { "Starting", "Running" }, { "Starting", "Running", "Climax" }, { "Starting", "Running", "Finishing" } } do
		local m = StateMachine.new()
		for _, s in path do assert(m:transition(s)) end
		assert(m:transition("Cancelled"), "cancelar de " .. m.state)
		assert(m:transition("Idle"))
	end
end)
test("state machine: reset forçado e listeners", function()
	local m = StateMachine.new()
	local seen = {}
	m:onChanged(function(a, b) table.insert(seen, a .. ">" .. b) end)
	m:transition("Starting"); m:transition("Running")
	m:reset()
	eq(m.state, "Idle")
	eq(seen[#seen], "Running>Idle")
	assert(m:transition("Starting"), "deve poder reiniciar após reset")
end)

-- AbilityMath ---------------------------------------------------------------------------------
test("cooldown: pronto/restante", function()
	assert(AbilityMath.isReady(nil, 10))
	assert(not AbilityMath.isReady(16, 10))
	assert(AbilityMath.isReady(16, 16))
	eq(AbilityMath.remaining(16, 10), 6)
	eq(AbilityMath.remaining(5, 10), 0)
end)
test("sanitizeDirection: rejeita lixo do cliente (exploit)", function()
	assert(AbilityMath.sanitizeDirection(nil) == nil)
	assert(AbilityMath.sanitizeDirection("x") == nil)
	assert(AbilityMath.sanitizeDirection(12) == nil)
	assert(AbilityMath.sanitizeDirection({}) == nil)
	assert(AbilityMath.sanitizeDirection(V(0, 5, 0)) == nil, "vertical puro não tem direção horizontal")
	assert(AbilityMath.sanitizeDirection(V(0 / 0, 0, 1)) == nil, "NaN")
	assert(AbilityMath.sanitizeDirection(V(math.huge, 0, 0)) == nil, "inf")
	local d = AbilityMath.sanitizeDirection(V(3, 99, 4))
	near(d.Magnitude, 1, 1e-9); eq(d.Y, 0); near(d.X, 0.6, 1e-9); near(d.Z, 0.8, 1e-9)
end)
test("clampAim: mira muito diferente da frente do personagem é substituída", function()
	local facing = V(0, 0, -1)
	local ok = AbilityMath.clampAim(V(0.3, 0, -0.95).Unit, facing, 0.2)
	near(ok.Z, V(0.3, 0, -0.95).Unit.Z, 1e-9)
	local back = AbilityMath.clampAim(V(0, 0, 1), facing, 0.2)
	eq(back.Z, -1)
end)
test("insideBeam: acerta dentro, erra fora (comprimento, largura, altura, trás)", function()
	local o, d = V(0, 0, 0), V(0, 0, -1)
	assert(AbilityMath.insideBeam(V(0, 0, -10), o, d, 20, 8, 10))
	assert(AbilityMath.insideBeam(V(3.9, 2, -10), o, d, 20, 8, 10))
	assert(not AbilityMath.insideBeam(V(4.1, 0, -10), o, d, 20, 8, 10), "largura")
	assert(not AbilityMath.insideBeam(V(0, 0, -21), o, d, 20, 8, 10), "comprimento")
	assert(not AbilityMath.insideBeam(V(0, 0, 1), o, d, 20, 8, 10), "atrás")
	assert(not AbilityMath.insideBeam(V(0, 11, -5), o, d, 20, 8, 10), "altura")
end)
test("insideBeam: varredura em segmentos cobre todo o alcance sem buracos", function()
	local o, d = V(0, 0, 0), V(1, 0, 0)
	for x = 0, 90, 0.5 do
		local hit = false
		local last = 0
		for _, step in { 20, 50, 70, 90 } do
			if AbilityMath.insideBeam(V(x, 0, 0), o + d * last, d, (step - last) + 2, 11, 10) then hit = true end
			last = step
		end
		assert(hit, "buraco em x=" .. x)
	end
end)

-- PoseDriver -----------------------------------------------------------------------------------
test("posedriver: toda animação amostra todas as juntas sem NaN", function()
	for name, anim in PoseDriver.Animations do
		local t = 0
		while t <= anim.length + 1 do
			local pose = PoseDriver.sample(name, t, 1)
			assert(pose, name)
			for _, j in PoseDriver.Joints do
				local v = pose[j]
				assert(v, name .. " sem junta " .. j)
				for i = 1, 3 do assert(v[i] == v[i] and math.abs(v[i]) < 400, name .. "/" .. j .. " valor ruim") end
			end
			t += 0.1
		end
	end
end)
test("posedriver: contínuo (sem saltos > 25°/quadro a 60fps) e extremos exatos", function()
	for name, anim in PoseDriver.Animations do
		local prev = PoseDriver.sample(name, 0, 0)
		local t = 1 / 60
		while t < anim.length do
			local cur = PoseDriver.sample(name, t, 0)
			for _, j in PoseDriver.Joints do
				for i = 1, 3 do
					assert(math.abs(cur[j][i] - prev[j][i]) < 25, name .. "/" .. j .. " salto em t=" .. t)
				end
			end
			prev = cur
			t += 1 / 60
		end
	end
end)
test("posedriver: ataque tem wind-up -> impacto no tempo esperado (0.62..0.78s)", function()
	local a = PoseDriver.sample("Release", 0.6)
	local b = PoseDriver.sample("Release", 0.78)
	assert(a.RightShoulder[1] > 140, "braço levantado no wind-up")
	assert(b.RightShoulder[1] < 30, "braço desceu no golpe")
end)
test("posedriver: nome desconhecido retorna nil", function()
	assert(PoseDriver.sample("Nope", 0) == nil)
end)

-- KitData (obj e procedural) ------------------------------------------------------------------
local R15 = {}
for _, n in { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm",
	"RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" } do R15[n] = true end
for src, data in KITS do
	for _, form in { "Ichigo", "Mugetsu" } do
		local def = data.forms[form]
		test(`kit {src}/{form}: existe, membros R15 válidos e tamanhos sãos`, function()
			assert(def, "forma ausente")
			for _, p in def.parts do
				assert(R15[p.attach], p.name .. " preso a membro inválido: " .. tostring(p.attach))
				for i = 1, 3 do assert(p.size[i] > 0 and p.size[i] < 8, p.name .. " tamanho fora do esperado") end
				for i = 1, 3 do assert(math.abs(p.pos[i]) < 7, p.name .. " longe demais do membro") end
				assert(p.shape == "Block" or p.shape == "Wedge" or p.shape == "Cylinder" or p.shape == "Ball", p.name .. " forma desconhecida")
				for i = 1, 3 do assert(p.color[i] >= 0 and p.color[i] <= 255) end
			end
			for _, c in def.chains do assert(R15[c.attach] and #c.lengths >= 1) end
			for n in pairs(def.limbColors) do assert(R15[n], "cor para membro inválido " .. n) end
		end)
		test(`kit {src}/{form}: lâmina única com TrailA/TrailB/Tip na mão direita`, function()
			local blades = 0
			for _, p in def.parts do
				if p.name == "Blade" then
					blades += 1
					eq(p.attach, "RightHand")
					local names = {}
					for _, a in p.attachments or {} do names[a.name] = a.pos end
					assert(names.TrailA and names.TrailB and names.Tip, "attachments do rastro ausentes")
					assert(math.abs(names.TrailA[3] - names.TrailB[3]) > 2, "rastro deve cobrir a lâmina (base -> ponta)")
				end
			end
			eq(blades, 1, "número de lâminas")
		end)
		test(`kit {src}/{form}: orçamento de instâncias (<= 260)`, function()
			local n = #def.parts
			for _, c in def.chains do n += #c.lengths end
			assert(n <= 260, "instâncias demais: " .. n)
		end)
	end
end

-- MeshKitManifest (malha esculpida) ------------------------------------------------------------
test("malha: pedaços presos a membros R15 e dentro do orçamento", function()
	assert(MESH.rootName == "Root" and MESH.form == "Mugetsu")
	local total = 0
	for name, info in MESH.pieces do
		assert(R15[info.attach], name .. " preso a membro inválido")
		assert(info.triangles > 0 and info.triangles <= 10000, name .. " com triângulos demais para um MeshPart")
		total += info.triangles
	end
	eq(total, MESH.totalTriangles)
	assert(total <= 50000, "malha pesada demais: " .. total)
end)
test("malha: espada com rastro base->ponta e olhos presos à cabeça", function()
	local b = MESH.pieces.Blade
	assert(b and b.attach == "RightHand")
	local a = {}
	for _, at in b.attachments do a[at.name] = at.pos end
	assert(a.TrailA and a.TrailB and a.Tip)
	local d = 0
	for i = 1, 3 do d += (a.TrailA[i] - a.TrailB[i]) ^ 2 end
	assert(math.sqrt(d) > 3, "rastro deve cobrir a lâmina")
	eq(#MESH.extras, 2)
	for _, e in MESH.extras do eq(e.attach, "Head") end
end)

if #failed > 0 then
	return "FAILED " .. #failed .. " / " .. (passed + #failed) .. "\n" .. table.concat(failed, "\n")
end
return "ALL PASSED " .. passed .. " testes"

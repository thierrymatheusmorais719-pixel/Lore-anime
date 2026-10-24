-- Monta cada efeito na origem e despeja os triângulos visíveis de cada camada em cada instante.
local function num(n)
	return string.format("%.3f", n)
end
local REIATSU = { core = Color3.new(0.85, 0.93, 1), primary = Color3.new(0.35, 0.65, 1), secondary = Color3.new(0.6, 0.85, 1), dark = Color3.new(0.04, 0.08, 0.18) }
local FIRE = { core = Color3.new(1, 0.93, 0.8), primary = Color3.new(1, 0.45, 0.1), secondary = Color3.new(1, 0.75, 0.3), dark = Color3.new(0.2, 0.04, 0.02) }
local slashPoints = {}
for i = 0, 12 do
	local a = math.rad(-75 + 150 * i / 12)
	table.insert(slashPoints, Vector3.new(math.sin(a) * 4, 1.2 + math.cos(a) * 1.5, -math.cos(a) * 1.5))
end
-- rastro de onda crescente (projétil indo para +X): fantasmas deixados a cada 0,03 s
local trail = {}
for i = 0, 7 do
	local pos = Vector3.new(-6 + i * 1.6, 1.5, 0)
	local cf = CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0)) * CFrame.Angles(math.pi / 2, 0, 0)
	table.insert(trail, { shape = "Crescent", size = 3.6, frame = cf, t0 = i * 0.03, life = 0.22, scale = { { 0, 1 }, { 1, 0.82 } }, alpha = { { 0, 0.25 }, { 1, 1 } }, color = REIATSU.primary })
end
-- feixe (Cero) para +X: espirais e anéis como MeshFx.BeamFx
local beam = {}
do
	local origin, dir, length, radius, duration = Vector3.new(-7, 1.5, 0), Vector3.new(1, 0, 0), 16, 1.6, 0.5
	local along = CFrame.lookAt(origin, origin + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
	for i, d in { 1, -1 } do
		table.insert(beam, { shape = "Spiral", size = 1, frame = along, roll = i * 1.5, spin = 16 * d, life = duration,
			scale = { { 0, Vector3.new(radius * 0.4, length * 0.2, radius * 0.4) }, { 0.15, Vector3.new(radius * 1.25, length, radius * 1.25) }, { 1, Vector3.new(radius * 0.3, length, radius * 0.3) } },
			alpha = { { 0, 0.2 }, { 0.7, 0.3 }, { 1, 1 } }, color = if i == 1 then Color3.new(1, 0.7, 0.7) else Color3.new(0.9, 0.15, 0.2) })
	end
	for k = 1, 5 do
		table.insert(beam, { shape = "RingThin", size = radius * 1.6, frame = along * CFrame.new(0, length * (k - 0.5) / 5, 0), t0 = (k - 1) / 5 * duration * 0.4, life = duration * 0.45,
			scale = { { 0, 0.4 }, { 1, 1.6 } }, alpha = { { 0, 0.1 }, { 1, 1 } }, color = Color3.new(1, 0.3, 0.3) })
	end
end
local EFFECTS = {
	{ "Rastro do Getsuga", trail },
	{ "Feixe (Cero)", beam },
	{ "Impacto leve", Recipes.Impact(Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), REIATSU, 1, 5) },
	{ "Impacto pesado", Recipes.Impact(Vector3.new(0, 1, 0), Vector3.new(1, 0.2, 0), FIRE, 2, 6) },
	{ "Finalizador", Recipes.Impact(Vector3.new(0, 1, 0), Vector3.new(1, 0.3, 0), REIATSU, 3, 7) },
	{ "Corte", Recipes.Slash(slashPoints, Vector3.new(0, 1.2, 0), REIATSU, 1.1, 0.28, MeshShapes.strip) },
	{ "Raio", Recipes.Element(Vector3.new(0, 1, 0), nil, "Lightning", { core = Color3.new(0.9, 0.95, 1), primary = Color3.new(0.6, 0.75, 1), secondary = Color3.new(0.8, 0.9, 1), dark = Color3.new(0.05, 0.05, 0.15) }, 1, MeshShapes.strip, 3) },
	{ "Gelo", Recipes.Element(Vector3.new(0, 1, 0), nil, "Ice", { core = Color3.new(0.9, 1, 1), primary = Color3.new(0.55, 0.85, 1), secondary = Color3.new(0.8, 0.95, 1), dark = Color3.new(0.05, 0.1, 0.2) }, 1, MeshShapes.strip, 4) },
	{ "Fogo", Recipes.Element(Vector3.new(0, 1, 0), nil, "Fire", FIRE, 1, MeshShapes.strip, 5) },
	{ "Sagrado", Recipes.Element(Vector3.new(0, 1, 0), nil, "Holy", { core = Color3.new(1, 1, 0.92), primary = Color3.new(1, 0.85, 0.45), secondary = Color3.new(1, 0.95, 0.7), dark = Color3.new(0.2, 0.15, 0.05) }, 1, MeshShapes.strip, 6) },
	{ "Hollow", Recipes.Element(Vector3.new(0, 1, 0), nil, "Hollow", { core = Color3.new(1, 0.6, 0.6), primary = Color3.new(0.85, 0.1, 0.15), secondary = Color3.new(1, 0.3, 0.3), dark = Color3.new(0.1, 0, 0) }, 1, MeshShapes.strip, 7) },
	{ "Tempo", Recipes.Element(Vector3.new(0, 1, 0), nil, "Time", REIATSU, 1, MeshShapes.strip, 8) },
	{ "Rachaduras", Recipes.Cracks(Vector3.new(0, -1.5, 0), FIRE, 7, MeshShapes.strip, 9) },
	{ "Onda de choque", Recipes.Shockwave(Vector3.new(0, 0, 0), FIRE, 5, 0.5) },
	{ "Carga", Recipes.Charge(CFrame.new(0, 1, 0), REIATSU, 0.5, true) },
	{ "Pilar", Recipes.Pillar(Vector3.new(0, -1, 0), FIRE, 1.5, 8, 0.6) },
}
for _, e in EFFECTS do
	for _, t in TIMES do
		local tris = {}
		for _, layer in e[2] do
			local frame, scale, alpha = Recipes.Evaluate(layer, t, CAMERA)
			if frame and alpha < 0.99 then
				local shape = if type(layer.shape) == "string" then MeshShapes.Library[layer.shape]() else layer.shape
				local c = layer.color
				for _, tri in shape.t do
					local pts = {}
					for k = 1, 3 do
						local v = shape.v[tri[k]]
						local w = frame * Vector3.new(v.X * scale.X, v.Y * scale.Y, v.Z * scale.Z)
						table.insert(pts, "[" .. num(w.X) .. "," .. num(w.Y) .. "," .. num(w.Z) .. "]")
					end
					table.insert(tris, string.format('{"p":[%s],"c":[%s,%s,%s],"a":%s,"neon":%s}', table.concat(pts, ","), num(c.R), num(c.G), num(c.B), num(alpha), tostring(layer.neon ~= false)))
				end
			end
		end
		print(string.format('{"effect":"%s","time":%s,"tris":[%s]}', e[1], tostring(t), table.concat(tris, ",")))
	end
end

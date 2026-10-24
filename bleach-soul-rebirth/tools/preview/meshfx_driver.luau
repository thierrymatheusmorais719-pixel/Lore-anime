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
local EFFECTS = {
	{ "Impacto leve", Recipes.Impact(Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), REIATSU, 1, 5) },
	{ "Impacto pesado", Recipes.Impact(Vector3.new(0, 1, 0), Vector3.new(1, 0.2, 0), FIRE, 2, 6) },
	{ "Finalizador", Recipes.Impact(Vector3.new(0, 1, 0), Vector3.new(1, 0.3, 0), REIATSU, 3, 7) },
	{ "Corte", Recipes.Slash(slashPoints, Vector3.new(0, 1.2, 0), REIATSU, 1.1, 0.28, MeshShapes.strip) },
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

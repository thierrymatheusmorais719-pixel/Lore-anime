-- Peças do Hueco Mundo: formações de rocha e cânion em terreno liso (Terrain), carcaças de Hollow
-- gigantes semienterradas (costelas, coluna, crânio com máscara), árvores de quartzo com galhos
-- que se ramificam, a fenda dos Menos, o arco de pedra da Garganta e Las Noches ao fundo (cúpula
-- branca colossal, muralha e torres). Tudo determinístico pelo Random do chamador.
local Build = require(script.Parent.Build)

local Hueco = {}

local BONE = Color3.fromRGB(236, 230, 214)
local BONE_DARK = Color3.fromRGB(196, 188, 170)
local QUARTZ = Color3.fromRGB(226, 232, 240)
local PALACE = Color3.fromRGB(244, 242, 236)

local function quiet(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
end

-- Formação de rocha em terreno: pilha de cilindros que afinam e tortos (agulhas/mesas do deserto)
function Hueco.rock(position: Vector3, radius: number, height: number, rng: Random, material: Enum.Material?)
	local mat = material or Enum.Material.Sandstone
	local layers = math.max(3, math.floor(height / (radius * 0.6)))
	local drift = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * radius * 0.06
	for i = 0, layers - 1 do
		local t = i / layers
		local r = radius * (1 - t * rng:NextNumber(0.35, 0.6))
		local h = height / layers + 2
		local center = position + drift * i + Vector3.new(0, t * height + h / 2, 0)
		workspace.Terrain:FillCylinder(CFrame.new(center), h, r, if i == layers - 1 then Enum.Material.Rock else mat)
	end
	-- base arredondada que funde com a areia
	workspace.Terrain:FillBall(position - Vector3.new(0, radius * 0.4, 0), radius * 1.15, Enum.Material.Sand)
end

-- Paredão de cânion: crista longa de rocha entre `a` e `b`
function Hueco.ridge(a: Vector3, b: Vector3, width: number, height: number, rng: Random)
	local length = (b - a).Magnitude
	local steps = math.max(2, math.floor(length / (width * 0.32)))
	for i = 0, steps do
		local p = a:Lerp(b, i / steps)
		local h = height * rng:NextNumber(0.75, 1.15)
		workspace.Terrain:FillBall(
			p + Vector3.new(0, h * 0.25, 0),
			width * rng:NextNumber(0.5, 0.65),
			Enum.Material.Sandstone
		)
		workspace.Terrain:FillCylinder(
			CFrame.new(p + Vector3.new(rng:NextNumber(-3, 3), h / 2, rng:NextNumber(-3, 3))),
			h,
			width * rng:NextNumber(0.5, 0.68),
			Enum.Material.Rock
		)
	end
end

-- Osso curvo: segmentos de cilindro seguindo um arco (costela, presa, chifre)
local function curvedBone(
	parent: Instance,
	base: CFrame,
	length: number,
	thickness: number,
	bend: number,
	color: Color3
)
	local segments = 7
	local prev = base.Position
	local dir = base:VectorToWorldSpace(Vector3.yAxis)
	local axis = base:VectorToWorldSpace(Vector3.xAxis)
	local step = bend / segments
	local cos, sin = math.cos(step), math.sin(step)
	for i = 1, segments do
		local t = i / segments
		-- gira `dir` em torno do eixo (Rodrigues)
		dir = dir * cos + axis:Cross(dir) * sin + axis * axis:Dot(dir) * (1 - cos)
		local nextP = prev + dir * (length / segments)
		local r = thickness * (1 - t * 0.55)
		local seg = Build.cylinder(
			parent,
			(nextP - prev).Magnitude + r * 0.4,
			r,
			CFrame.lookAt((prev + nextP) / 2, nextP) * CFrame.Angles(0, math.rad(90), 0),
			color,
			Enum.Material.Limestone
		)
		seg.Name = "Bone"
		prev = nextP
	end
end

-- Carcaça de Hollow gigante semienterrada: coluna, costelas arqueadas e crânio com máscara/chifres
function Hueco.carcass(parent: Instance, cf: CFrame, scale: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Carcass"
	local spineLen = 70 * scale
	-- coluna: vértebras ao longo de -Z, afundando nas pontas
	local count = 14
	for i = 0, count do
		local t = i / count
		local p = cf * CFrame.new(0, 4 * scale * math.sin(t * math.pi) - 1, -spineLen / 2 + t * spineLen)
		local v = Build.part(model, Vector3.new(5, 4, 3.4) * scale, p, BONE_DARK, Enum.Material.Limestone, "Vertebra")
		v.CFrame = v.CFrame * CFrame.Angles(0, 0, rng:NextNumber(-0.1, 0.1))
		quiet(
			Build.wedge(
				model,
				Vector3.new(1.2, 4, 3) * scale,
				p * CFrame.new(0, 3.5 * scale, 0),
				BONE,
				Enum.Material.Limestone
			)
		)
	end
	-- costelas dos dois lados, arqueando para cima e para dentro
	for i = 1, 8 do
		local t = i / 9
		local z = -spineLen / 2 + spineLen * (0.15 + t * 0.6)
		local size = (1 - math.abs(t - 0.45) * 1.2) * 34 * scale
		for _, s in { -1, 1 } do
			local base = cf * CFrame.new(s * 2.5 * scale, 4 * scale, z) * CFrame.Angles(0, 0, math.rad(-s * 70))
			curvedBone(model, base, size, 3.4 * scale, math.rad(110) * s, BONE)
		end
	end
	-- crânio na frente (-Z): caixa óssea, mandíbula aberta, órbitas escuras, chifres
	local head = cf * CFrame.new(0, 6 * scale, -spineLen / 2 - 9 * scale) * CFrame.Angles(math.rad(-15), 0, 0)
	Build.part(model, Vector3.new(16, 12, 18) * scale, head, BONE, Enum.Material.Limestone, "Skull")
	Build.wedge(
		model,
		Vector3.new(14, 6, 12) * scale,
		head * CFrame.new(0, -7 * scale, -6 * scale) * CFrame.Angles(math.rad(20), math.pi, 0),
		BONE_DARK,
		Enum.Material.Limestone
	).Name =
		"Jaw"
	for _, s in { -1, 1 } do
		quiet(
			Build.part(
				model,
				Vector3.new(4, 3, 0.4) * scale,
				head * CFrame.new(s * 4 * scale, 1.5 * scale, -9.1 * scale),
				Color3.fromRGB(12, 10, 14),
				Enum.Material.SmoothPlastic,
				"Orbit"
			)
		)
		curvedBone(
			model,
			head * CFrame.new(s * 6 * scale, 5 * scale, 0) * CFrame.Angles(0, 0, math.rad(-s * 40)),
			20 * scale,
			2 * scale,
			math.rad(70) * s,
			BONE
		)
		for k = 1, 4 do
			quiet(
				Build.wedge(
					model,
					Vector3.new(1, 3, 1) * scale,
					head * CFrame.new(s * k * 1.4 * scale, -4.5 * scale, -9 * scale) * CFrame.Angles(math.pi, 0, 0),
					BONE,
					Enum.Material.Limestone
				)
			)
		end
	end
	-- areia cobrindo a metade de baixo
	workspace.Terrain:FillBall(cf.Position - Vector3.new(0, 10 * scale, 0), 26 * scale, Enum.Material.Sand)
	model.Parent = parent
	return model
end

-- Árvore de quartzo: tronco cristalino que se ramifica em dois níveis, pontas afiadas
function Hueco.quartzTree(parent: Instance, position: Vector3, rng: Random)
	local model = Instance.new("Model")
	model.Name = "QuartzTree"
	local scale = rng:NextNumber(0.8, 1.6)
	local function branch(from: Vector3, dir: Vector3, length: number, thick: number, depth: number)
		local to = from + dir * length
		local p = Build.part(
			model,
			Vector3.new(thick, thick, length),
			CFrame.lookAt((from + to) / 2, to),
			QUARTZ,
			Enum.Material.Glass,
			"Quartz"
		)
		p.Reflectance = 0.25
		if depth <= 0 then
			local tip = Build.wedge(
				model,
				Vector3.new(thick, thick * 0.9, thick * 3),
				CFrame.lookAt(to, to + dir) * CFrame.new(0, 0, -thick * 1.5) * CFrame.Angles(0, math.pi, 0),
				QUARTZ,
				Enum.Material.Glass
			)
			quiet(tip)
			return
		end
		for _ = 1, 2 do
			local spread = Vector3.new(rng:NextNumber(-0.9, 0.9), rng:NextNumber(0.3, 0.9), rng:NextNumber(-0.9, 0.9))
			branch(to, (dir + spread).Unit, length * 0.65, thick * 0.6, depth - 1)
		end
	end
	branch(
		position - Vector3.new(0, 1, 0),
		Vector3.new(rng:NextNumber(-0.15, 0.15), 1, rng:NextNumber(-0.15, 0.15)).Unit,
		12 * scale,
		1.4 * scale,
		2
	)
	model.Parent = parent
	return model
end

-- Fenda dos Menos: anel de rochas quebradas em volta de um poço escuro com rachaduras brilhando
function Hueco.menosRift(parent: Instance, center: Vector3, radius: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "MenosRift"
	local pit = Build.cylinder(
		model,
		0.3,
		radius * 1.8,
		CFrame.new(center + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(14, 12, 18),
		Enum.Material.Basalt
	)
	pit.Name = "Pit"
	for i = 1, 9 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local len = rng:NextNumber(radius * 0.4, radius * 0.9)
		local crack = Build.part(
			model,
			Vector3.new(0.6, 0.2, len),
			CFrame.new(center + Vector3.new(math.cos(angle) * len / 2, 0.45, math.sin(angle) * len / 2))
				* CFrame.Angles(0, -angle + math.pi / 2, 0),
			Color3.fromRGB(150, 60, 255),
			Enum.Material.Neon,
			"RiftCrack"
		)
		quiet(crack)
	end
	local glow = Build.part(
		model,
		Vector3.new(1, 1, 1),
		CFrame.new(center + Vector3.new(0, 2, 0)),
		Color3.new(),
		Enum.Material.SmoothPlastic,
		"RiftGlow"
	)
	glow.Transparency = 1
	quiet(glow)
	Build.light(glow, Color3.fromRGB(150, 70, 255), radius * 2.5, 2)
	for i = 0, 13 do
		local angle = i / 14 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local p = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius + rng:NextNumber(1, 4))
		local h = rng:NextNumber(4, 12)
		local rock = Build.wedge(
			model,
			Vector3.new(rng:NextNumber(4, 7), h, rng:NextNumber(3, 5)),
			CFrame.lookAt(p + Vector3.new(0, h / 2 - 1, 0), center + Vector3.new(0, h / 2 - 1, 0))
				* CFrame.Angles(math.rad(rng:NextNumber(-15, 5)), 0, 0),
			Color3.fromRGB(70, 64, 72),
			Enum.Material.Basalt
		)
		rock.Name = "RiftRock"
	end
	model.Parent = parent
	return model
end

-- Arco de pedra da Garganta (saída para Karakura): dois pilares tortos e um arco negro rachado
function Hueco.gargantaArch(parent: Instance, cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "GargantaArch"
	for _, s in { -1, 1 } do
		Build.part(
			model,
			Vector3.new(7, 30, 7),
			cf * CFrame.new(s * 14, 15, 0) * CFrame.Angles(0, 0, math.rad(s * 6)),
			Color3.fromRGB(60, 56, 62),
			Enum.Material.Basalt,
			"ArchPillar"
		)
	end
	for i = 0, 8 do
		local a = math.rad(-80 + i * 20)
		local p = cf * CFrame.new(math.sin(a) * 15, 28 + math.cos(a) * 9, 0)
		quiet(
			Build.part(
				model,
				Vector3.new(7, 5, 6),
				p * CFrame.Angles(0, 0, -a),
				Color3.fromRGB(50, 46, 52),
				Enum.Material.Basalt,
				"ArchStone"
			)
		)
	end
	local rng = Random.new(66)
	local rift = Build.part(
		model,
		Vector3.new(14, 22, 0.4),
		cf * CFrame.new(0, 14, 0),
		Color3.fromRGB(10, 8, 12),
		Enum.Material.SmoothPlastic,
		"Garganta"
	)
	quiet(rift)
	for _ = 1, 6 do
		quiet(
			Build.part(
				model,
				Vector3.new(0.3, rng:NextNumber(4, 9), 0.5),
				cf
					* CFrame.new(rng:NextNumber(-6, 6), rng:NextNumber(6, 22), -0.3)
					* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-40, 40))),
				Color3.fromRGB(80, 160, 255),
				Enum.Material.Neon,
				"RiftLine"
			)
		)
	end
	model.Parent = parent
	return model
end

-- Las Noches (fundo): muralha branca altíssima com contrafortes, cúpula colossal e cinco torres
-- finas; portão escuro na frente. Sem colisão (fica além do limite da região).
function Hueco.lasNoches(parent: Instance, cf: CFrame, width: number)
	local model = Instance.new("Model")
	model.Name = "LasNoches"
	local wallH = 120
	local segments = 12
	for i = 0, segments - 1 do
		local x = -width / 2 + (i + 0.5) * width / segments
		local seg = Build.part(
			model,
			Vector3.new(width / segments + 0.5, wallH, 30),
			cf * CFrame.new(x, wallH / 2, 0),
			PALACE,
			Enum.Material.Marble,
			"Wall"
		)
		quiet(seg)
		quiet(
			Build.part(
				model,
				Vector3.new(6, wallH + 6, 36),
				cf * CFrame.new(-width / 2 + i * width / segments, (wallH + 6) / 2, 0),
				PALACE:Lerp(Color3.new(0, 0, 0), 0.06),
				Enum.Material.Marble,
				"Buttress"
			)
		)
		quiet(
			Build.part(
				model,
				Vector3.new(width / segments - 6, 3, 1),
				cf * CFrame.new(x, wallH * 0.7, -15.2),
				Color3.fromRGB(200, 198, 192),
				Enum.Material.Marble,
				"Band"
			)
		)
	end
	-- portão
	quiet(
		Build.part(
			model,
			Vector3.new(40, 60, 2),
			cf * CFrame.new(0, 30, -15.5),
			Color3.fromRGB(26, 24, 30),
			Enum.Material.SmoothPlastic,
			"PalaceGate"
		)
	)
	quiet(
		Build.part(
			model,
			Vector3.new(48, 6, 4),
			cf * CFrame.new(0, 63, -16),
			PALACE,
			Enum.Material.Marble,
			"GateLintel"
		)
	)
	-- cúpula (atrás da muralha)
	local dome = Build.ball(model, 900, cf * CFrame.new(0, -260, 380), PALACE, Enum.Material.Marble)
	dome.Name = "Dome"
	quiet(dome)
	-- torres
	for i, x in { -0.42, -0.2, 0, 0.2, 0.42 } do
		local h = if i == 3 then 360 else 260
		local p = cf * CFrame.new(x * width, 0, 140 + math.abs(x) * 200)
		quiet(
			Build.part(
				model,
				Vector3.new(16, h, 16),
				p * CFrame.new(0, h / 2, 0),
				PALACE,
				Enum.Material.Marble,
				"Tower"
			)
		)
		quiet(
			Build.part(
				model,
				Vector3.new(24, 10, 24),
				p * CFrame.new(0, h + 5, 0),
				PALACE,
				Enum.Material.Marble,
				"TowerCap"
			)
		)
	end
	model.Parent = parent
	return model
end

return Hueco

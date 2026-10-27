-- Primitivas de construção do mapa (peças ancoradas, luzes, casas, árvores, postes).
-- Tudo é determinístico com o `Random` recebido, para o mapa ser igual em todo servidor.
local Build = {}

function Build.part(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	name: string?
): Part
	local p = Instance.new("Part")
	p.Name = name or "Part"
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Build.wedge(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Build.cylinder(
	parent: Instance,
	length: number,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Build.part(parent, Vector3.new(length, diameter, diameter), cframe, color, material, "Cylinder")
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Build.ball(parent: Instance, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Build.part(parent, Vector3.one * diameter, cframe, color, material, "Ball")
	p.Shape = Enum.PartType.Ball
	return p
end

function Build.light(part: BasePart, color: Color3, range: number, brightness: number, spot: boolean?): Light
	local light: any
	if spot then
		local s = Instance.new("SpotLight")
		s.Face = Enum.NormalId.Bottom
		s.Angle = 100
		light = s
	else
		light = Instance.new("PointLight")
	end
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
	return light
end

function Build.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Chão de terreno com topo em y = top.
function Build.ground(center: Vector3, size: Vector2, material: Enum.Material, top: number?)
	local y = (top or 0) - 4
	workspace.Terrain:FillBlock(CFrame.new(center.X, y, center.Z), Vector3.new(size.X, 8, size.Y), material)
end

-- Casa japonesa urbana (Karakura): paredes, janelas iluminadas, telhado de duas águas.
function Build.house(parent: Instance, cframe: CFrame, width: number, depth: number, floors: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "House"
	local floorHeight = 11
	local height = floors * floorHeight
	local palettes = {
		Color3.fromRGB(214, 206, 190),
		Color3.fromRGB(190, 196, 204),
		Color3.fromRGB(205, 186, 170),
		Color3.fromRGB(176, 186, 172),
		Color3.fromRGB(222, 218, 210),
	}
	local wallColor = palettes[rng:NextInteger(1, #palettes)]
	Build.part(
		model,
		Vector3.new(width, height, depth),
		cframe * CFrame.new(0, height / 2, 0),
		wallColor,
		Enum.Material.Concrete,
		"Walls"
	)
	-- Base
	Build.part(
		model,
		Vector3.new(width + 1, 1, depth + 1),
		cframe * CFrame.new(0, 0.5, 0),
		Color3.fromRGB(90, 90, 95),
		Enum.Material.Slate,
		"Base"
	)
	-- Janelas (frente e fundos); algumas acesas
	local windowColorOn = Color3.fromRGB(255, 214, 150)
	local windowColorOff = Color3.fromRGB(40, 46, 60)
	local columns = math.max(1, math.floor(width / 8))
	for floor = 1, floors do
		for c = 1, columns do
			local x = -width / 2 + (c - 0.5) * (width / columns)
			local y = (floor - 1) * floorHeight + 6
			for _, side in { -1, 1 } do
				local lit = rng:NextNumber() < 0.45
				local window = Build.part(
					model,
					Vector3.new(3.2, 3.6, 0.3),
					cframe * CFrame.new(x, y, side * (depth / 2 + 0.1)),
					if lit then windowColorOn else windowColorOff,
					if lit then Enum.Material.Neon else Enum.Material.Glass,
					"Window"
				)
				if lit and rng:NextNumber() < 0.3 then
					Build.light(window, windowColorOn, 14, 0.6)
				end
			end
		end
	end
	-- Porta
	Build.part(
		model,
		Vector3.new(3.5, 7, 0.4),
		cframe * CFrame.new(width * 0.2, 3.5, -depth / 2 - 0.15),
		Color3.fromRGB(70, 50, 40),
		Enum.Material.Wood,
		"Door"
	)
	-- Telhado de duas águas com beiral
	local roofColor = if rng:NextNumber() < 0.5 then Color3.fromRGB(60, 62, 75) else Color3.fromRGB(110, 55, 45)
	local overhang = 2
	local roofHeight = math.min(7, depth * 0.35)
	local half = (depth + overhang * 2) / 2
	for _, side in { -1, 1 } do
		Build.wedge(
			model,
			Vector3.new(width + overhang * 2, roofHeight, half),
			cframe
				* CFrame.new(0, height + roofHeight / 2, side * half / 2)
				* CFrame.Angles(0, if side < 0 then 0 else math.pi, 0),
			roofColor,
			Enum.Material.Slate
		)
	end
	model.Parent = parent
	return model
end

-- Poste de luz urbano.
function Build.lamp(parent: Instance, position: Vector3, color: Color3?)
	local model = Instance.new("Model")
	model.Name = "Lamp"
	Build.part(
		model,
		Vector3.new(0.6, 14, 0.6),
		CFrame.new(position + Vector3.new(0, 7, 0)),
		Color3.fromRGB(60, 62, 68),
		Enum.Material.Metal,
		"Pole"
	)
	Build.part(
		model,
		Vector3.new(3, 0.5, 0.6),
		CFrame.new(position + Vector3.new(1.2, 14, 0)),
		Color3.fromRGB(60, 62, 68),
		Enum.Material.Metal,
		"Arm"
	)
	local bulb = Build.part(
		model,
		Vector3.new(1.4, 0.4, 1),
		CFrame.new(position + Vector3.new(2.4, 13.7, 0)),
		color or Color3.fromRGB(255, 225, 170),
		Enum.Material.Neon,
		"Bulb"
	)
	Build.light(bulb, color or Color3.fromRGB(255, 220, 160), 30, 1.6, true)
	model.Parent = parent
	return model
end

-- Árvores: "cherry" (sakura), "broadleaf" (árvore de rua verde), "pine" (pinheiro japonês podado
-- em almofadas), "dead" (quartzo de Hueco Mundo).
-- Folhagem realista com peças: tronco cilíndrico afinando em segmentos com raízes, galhos que se
-- ramificam até as pontas e, em cada ponta, um cacho de esferas de folhagem (material LeafyGrass,
-- que tem textura de folhas) em tamanhos e tons variados — mais escuro por dentro, mais claro e
-- iluminado por fora. Folhas não colidem (o tronco sim).
local function cylinderBetween(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	name: string
): Part
	local len = (b - a).Magnitude
	local p = Build.part(
		parent,
		Vector3.new(len + diameter * 0.3, diameter, diameter),
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
		color,
		Enum.Material.Wood,
		name
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function leafCluster(
	parent: Instance,
	center: Vector3,
	radius: number,
	palette: { Color3 },
	rng: Random,
	count: number
)
	for k = 1, count do
		local offset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.55, 0.8), rng:NextNumber(-1, 1)) * radius
		local outer = offset.Magnitude / radius
		local base = palette[rng:NextInteger(1, #palette)]
		-- de dentro (sombra) para fora (luz)
		local color = base:Lerp(Color3.new(0, 0, 0), 0.22 * (1 - outer)):Lerp(Color3.new(1, 1, 1), 0.08 * outer)
		local d = rng:NextNumber(0.55, 1) * radius * (if k == 1 then 1.5 else 1.15)
		local leaf = Build.ball(
			parent,
			d,
			CFrame.new(center + (if k == 1 then Vector3.zero else offset)),
			color,
			Enum.Material.LeafyGrass
		)
		leaf.Name = "Leaves"
		leaf.CanCollide = false
		leaf.CanQuery = false
		leaf.CanTouch = false
	end
end

-- Galho recursivo: cilindro de `from` na direção `dir`; nas pontas, cachos de folhas
local function grow(
	parent: Instance,
	from: Vector3,
	dir: Vector3,
	length: number,
	thick: number,
	depth: number,
	rng: Random,
	bark: Color3,
	leaves: (Vector3, number) -> ()
)
	local to = from + dir * length
	cylinderBetween(parent, from, to, thick, bark, "Branch").CanCollide = false
	if depth <= 0 then
		leaves(to, length)
		return
	end
	local children = rng:NextInteger(2, 3)
	for c = 1, children do
		local angle = (c / children) * math.pi * 2 + rng:NextNumber(-0.6, 0.6)
		local side = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local newDir = (dir * 0.9 + side * rng:NextNumber(0.45, 0.8) + Vector3.new(0, rng:NextNumber(0.05, 0.35), 0)).Unit
		grow(parent, to, newDir, length * rng:NextNumber(0.62, 0.78), thick * 0.62, depth - 1, rng, bark, leaves)
	end
end

local function trunk(
	parent: Instance,
	position: Vector3,
	height: number,
	width: number,
	rng: Random,
	bark: Color3,
	lean: Vector3
): Vector3
	local segments = 3
	local p = position
	for i = 1, segments do
		local t = i / segments
		local nextP = position + Vector3.new(lean.X * t * t, height * t, lean.Z * t * t)
		cylinderBetween(
			parent,
			p,
			nextP,
			width * (1 - t * 0.35),
			bark:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.12)),
			"Trunk"
		)
		p = nextP
	end
	-- raízes abrindo na base
	for r = 1, 4 do
		local a = r / 4 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local out = position + Vector3.new(math.cos(a), 0, math.sin(a)) * width * 1.1
		cylinderBetween(
			parent,
			position + Vector3.new(0, width * 0.7, 0),
			out + Vector3.new(0, 0.1, 0),
			width * 0.38,
			bark,
			"Root"
		).CanCollide =
			false
	end
	return p
end

function Build.tree(parent: Instance, position: Vector3, kind: string, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local scale = rng:NextNumber(0.85, 1.3)
	if kind == "dead" then
		local trunkColor = Color3.fromRGB(225, 228, 235)
		local h = 14 * scale
		local top = trunk(model, position, h, 1.5 * scale, rng, trunkColor, Vector3.zero)
		for i = 1, 4 do
			local angle = i * math.pi / 2 + rng:NextNumber(-0.4, 0.4)
			grow(
				model,
				top - Vector3.new(0, h * 0.3, 0),
				Vector3.new(math.cos(angle), 0.8, math.sin(angle)).Unit,
				rng:NextNumber(4, 7) * scale,
				0.7,
				1,
				rng,
				trunkColor,
				function() end
			)
		end
	elseif kind == "pine" then
		-- pinheiro japonês (kuromatsu) podado: tronco curvo e almofadas de folhagem achatadas em camadas
		local bark = Color3.fromRGB(78, 58, 46)
		local h = 11 * scale
		local lean = Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5)) * scale
		local top = trunk(model, position, h, 1.3 * scale, rng, bark, lean)
		local greens = { Color3.fromRGB(38, 70, 44), Color3.fromRGB(46, 82, 50), Color3.fromRGB(56, 92, 58) }
		local pads = rng:NextInteger(4, 6)
		for k = 1, pads do
			local t = 0.35 + 0.65 * (k / pads)
			local center = position + Vector3.new(lean.X * t * t, h * t, lean.Z * t * t)
			local angle = k * 2.4 + rng:NextNumber(-0.4, 0.4)
			local reach = (1 - t * 0.6) * 5.5 * scale
			local tip = center + Vector3.new(math.cos(angle) * reach, 0.6, math.sin(angle) * reach)
			cylinderBetween(model, center, tip, 0.45 * scale, bark, "Branch").CanCollide = false
			-- almofada: discos empilhados que afinam + esferas por cima (nuvem de agulhas)
			local padW = (1 - t * 0.45) * 6 * scale
			for layer = 0, 2 do
				local disc = Build.cylinder(
					model,
					0.9 * scale,
					padW * (1 - layer * 0.28),
					CFrame.new(tip + Vector3.new(0, 0.2 + layer * 0.7 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)),
					greens[rng:NextInteger(1, #greens)]:Lerp(Color3.fromRGB(90, 120, 70), layer * 0.12),
					Enum.Material.LeafyGrass
				)
				disc.Name = "Leaves"
				disc.CanCollide = false
			end
			leafCluster(model, tip + Vector3.new(0, 0.9 * scale, 0), padW * 0.32, greens, rng, 3)
		end
		leafCluster(model, top + Vector3.new(0, 0.8, 0), 2.2 * scale, greens, rng, 4)
	else
		local cherry = kind ~= "broadleaf"
		local bark = if cherry then Color3.fromRGB(62, 40, 36) else Color3.fromRGB(82, 66, 52)
		local h = (if cherry then 7 else 9) * scale
		local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * scale
		local top = trunk(model, position, h, 1.25 * scale, rng, bark, lean)
		local palette = if cherry
			then {
				Color3.fromRGB(255, 183, 205),
				Color3.fromRGB(250, 200, 215),
				Color3.fromRGB(255, 222, 232),
				Color3.fromRGB(236, 150, 180),
			}
			else {
				Color3.fromRGB(64, 112, 52),
				Color3.fromRGB(78, 128, 58),
				Color3.fromRGB(96, 142, 66),
				Color3.fromRGB(54, 96, 48),
			}
		local spread = if cherry then 0.75 else 0.45 -- sakura abre em guarda-chuva; a de rua sobe
		for c = 1, rng:NextInteger(4, 5) do
			local angle = c * 1.4 + rng:NextNumber(-0.4, 0.4)
			local dir = Vector3.new(math.cos(angle) * spread, 1, math.sin(angle) * spread).Unit
			grow(model, top, dir, rng:NextNumber(3.2, 4.4) * scale, 0.7 * scale, 1, rng, bark, function(tip, len)
				leafCluster(model, tip + Vector3.new(0, 0.5, 0), len * 0.9, palette, rng, if cherry then 8 else 6)
			end)
		end
		-- copa central fechando o miolo
		leafCluster(model, top + Vector3.new(0, 2.6 * scale, 0), 3.4 * scale, palette, rng, 7)
	end
	model.Parent = parent
	return model
end

-- Verdadeiro se `point` estiver longe de todos os círculos {position, radius}.
function Build.clear(point: Vector3, keepOut: { { position: Vector3, radius: number } }): boolean
	for _, zone in keepOut do
		local d = point - zone.position
		if Vector2.new(d.X, d.Z).Magnitude < zone.radius then
			return false
		end
	end
	return true
end

return Build

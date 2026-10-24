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

-- Árvores: "cherry" (sakura), "dead" (quartzo de Hueco Mundo), "pine".
function Build.tree(parent: Instance, position: Vector3, kind: string, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local scale = rng:NextNumber(0.8, 1.3)
	if kind == "dead" then
		local trunkColor = Color3.fromRGB(225, 228, 235)
		local h = 14 * scale
		Build.part(
			model,
			Vector3.new(1.6, h, 1.6) * Vector3.new(scale, 1, scale),
			CFrame.new(position + Vector3.new(0, h / 2, 0)),
			trunkColor,
			Enum.Material.Glass,
			"Trunk"
		)
		for i = 1, 4 do
			local angle = i * math.pi / 2 + rng:NextNumber(-0.4, 0.4)
			local len = rng:NextNumber(4, 7) * scale
			local base = position + Vector3.new(0, h * rng:NextNumber(0.55, 0.9), 0)
			local dir = Vector3.new(math.cos(angle), 0.8, math.sin(angle)).Unit
			Build.part(
				model,
				Vector3.new(0.7, 0.7, len),
				CFrame.lookAt(base + dir * len / 2, base + dir * len),
				trunkColor,
				Enum.Material.Glass,
				"Branch"
			)
		end
	elseif kind == "pine" then
		local h = 16 * scale
		Build.part(
			model,
			Vector3.new(1.4, h * 0.4, 1.4),
			CFrame.new(position + Vector3.new(0, h * 0.2, 0)),
			Color3.fromRGB(80, 55, 40),
			Enum.Material.Wood,
			"Trunk"
		)
		for i = 1, 3 do
			local size = (4 - i) * 3.2 * scale
			Build.part(
				model,
				Vector3.new(size, h * 0.25, size),
				CFrame.new(position + Vector3.new(0, h * (0.25 + i * 0.18), 0)) * CFrame.Angles(0, math.rad(45 * i), 0),
				Color3.fromRGB(40, 80, 55),
				Enum.Material.Grass,
				"Leaves"
			)
		end
	else
		local h = 10 * scale
		Build.part(
			model,
			Vector3.new(1.4, h, 1.4),
			CFrame.new(position + Vector3.new(0, h / 2, 0)),
			Color3.fromRGB(70, 45, 40),
			Enum.Material.Wood,
			"Trunk"
		)
		-- galhos abrindo do topo do tronco e copa em muitos tufos pequenos (nada de bolas grandes)
		local top = position + Vector3.new(0, h, 0)
		for i = 1, 4 do
			local angle = i * math.pi / 2 + rng:NextNumber(-0.4, 0.4)
			local dir = Vector3.new(math.cos(angle), 0.9, math.sin(angle)).Unit
			local len = rng:NextNumber(3, 4.5) * scale
			Build.part(
				model,
				Vector3.new(0.6, 0.6, len),
				CFrame.lookAt(top - Vector3.new(0, 1.5, 0) + dir * len / 2, top - Vector3.new(0, 1.5, 0) + dir * len),
				Color3.fromRGB(70, 45, 40),
				Enum.Material.Wood,
				"Branch"
			)
		end
		local base = Color3.fromRGB(255, 180, 202)
		for _ = 1, 14 do
			local offset = Vector3.new(rng:NextNumber(-4.5, 4.5), rng:NextNumber(-0.5, 3.5), rng:NextNumber(-4.5, 4.5))
				* scale
			local tuft = Build.ball(
				model,
				rng:NextNumber(2.6, 4.2) * scale,
				CFrame.new(top + Vector3.new(0, 1.5, 0) + offset),
				base:Lerp(Color3.fromRGB(255, 232, 240), rng:NextNumber())
					:Lerp(Color3.fromRGB(200, 120, 150), rng:NextNumber(0, 0.25)),
				Enum.Material.Grass
			)
			tuft.Size = Vector3.new(tuft.Size.X, tuft.Size.Y * 0.75, tuft.Size.Z)
			tuft.CanCollide = false
		end
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

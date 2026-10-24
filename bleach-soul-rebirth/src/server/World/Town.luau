-- Peças da cidade de Karakura (noite): prédios comerciais com grade de janelas acesas, letreiros
-- verticais em neon, caixas d'água e ar-condicionado no telhado, lojas térreas com toldo; casas
-- japonesas com telhado de telha, muro e portão; calçadas com meio-fio, faixas de pedestre,
-- semáforos, postes de concreto com fiação (a marca de Karakura), máquinas de venda, loja de
-- conveniência, rua comercial coberta com lanternas, trilho elevado com estação.
-- Determinístico (Random do chamador): o mapa é igual em todo servidor.
local Build = require(script.Parent.Build)

local Town = {}

local WARM = Color3.fromRGB(255, 214, 150)
local COOL = Color3.fromRGB(190, 220, 255)
local DARK_GLASS = Color3.fromRGB(34, 40, 54)
local CONCRETE = Color3.fromRGB(150, 150, 155)
local CURB = Color3.fromRGB(175, 175, 172)
local POLE = Color3.fromRGB(120, 118, 112)
local WIRE = Color3.fromRGB(25, 25, 28)

local SIGN_TEXT = {
	"ラーメン",
	"カラオケ",
	"薬",
	"居酒屋",
	"書店",
	"珈琲",
	"寿司",
	"ゲーム",
	"本屋",
	"銭湯",
	"花屋",
	"床屋",
}
local NEON = {
	Color3.fromRGB(255, 70, 90),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(255, 190, 60),
	Color3.fromRGB(150, 255, 120),
	Color3.fromRGB(230, 110, 255),
}

local function neonPart(parent: Instance, size: Vector3, cf: CFrame, color: Color3, name: string?): Part
	return Build.part(parent, size, cf, color, Enum.Material.Neon, name)
end

local function noCollide(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-- Texto num painel (letreiro): SurfaceGui na face -Z do painel
local function signText(panel: BasePart, text: string, color: Color3, vertical: boolean?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.PixelsPerStud = 40
	gui.Parent = panel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	-- vertical: um caractere UTF-8 por linha (texto japonês empilhado)
	if vertical then
		local chars = {}
		for _, code in utf8.codes(text) do
			table.insert(chars, utf8.char(code))
		end
		label.Text = table.concat(chars, "\n")
	end
	return gui
end

-- ======================================================================= ruas
-- Calçada com meio-fio dos dois lados de uma via (eixo `along` = comprimento)
function Town.sidewalks(parent: Instance, center: Vector3, length: number, roadWidth: number, alongX: boolean)
	for _, side in { -1, 1 } do
		local offset = side * (roadWidth / 2 + 2.2)
		local size = if alongX then Vector3.new(length, 0.6, 4.4) else Vector3.new(4.4, 0.6, length)
		local pos = center + (if alongX then Vector3.new(0, 0.3, offset) else Vector3.new(offset, 0.3, 0))
		Build.part(parent, size, CFrame.new(pos), CONCRETE, Enum.Material.Concrete, "Sidewalk")
		local curbOffset = side * (roadWidth / 2 + 0.15)
		local curbSize = if alongX then Vector3.new(length, 0.7, 0.3) else Vector3.new(0.3, 0.7, length)
		local curbPos = center + (if alongX then Vector3.new(0, 0.35, curbOffset) else Vector3.new(curbOffset, 0.35, 0))
		Build.part(parent, curbSize, CFrame.new(curbPos), CURB, Enum.Material.Concrete, "Curb")
	end
end

-- Faixa de pedestre (zebra) atravessando a via na posição `at`
function Town.crosswalk(parent: Instance, at: Vector3, roadWidth: number, alongX: boolean)
	for i = -3, 3 do
		local offset = i * 2.2
		local size = if alongX then Vector3.new(1.2, 0.05, roadWidth - 2) else Vector3.new(roadWidth - 2, 0.05, 1.2)
		local pos = at + (if alongX then Vector3.new(offset, 0.43, 0) else Vector3.new(0, 0.43, offset))
		local p = Build.part(
			parent,
			size,
			CFrame.new(pos),
			Color3.fromRGB(235, 235, 228),
			Enum.Material.SmoothPlastic,
			"Zebra"
		)
		noCollide(p)
	end
end

-- Semáforo de esquina: poste, braço sobre a via, caixa com três luzes (vermelho aceso)
function Town.trafficLight(parent: Instance, cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "TrafficLight"
	Build.part(
		model,
		Vector3.new(0.5, 13, 0.5),
		cf * CFrame.new(0, 6.5, 0),
		Color3.fromRGB(70, 72, 78),
		Enum.Material.Metal,
		"Pole"
	)
	Build.part(
		model,
		Vector3.new(0.35, 0.35, 6),
		cf * CFrame.new(0, 12.5, -3),
		Color3.fromRGB(70, 72, 78),
		Enum.Material.Metal,
		"Arm"
	)
	Build.part(
		model,
		Vector3.new(3.4, 1.2, 0.9),
		cf * CFrame.new(0, 12.1, -5.6),
		Color3.fromRGB(40, 42, 46),
		Enum.Material.Metal,
		"Box"
	)
	for i, color in { Color3.fromRGB(40, 255, 140), Color3.fromRGB(255, 190, 40), Color3.fromRGB(255, 50, 50) } do
		local on = i == 3
		local lamp = Build.part(
			model,
			Vector3.new(0.8, 0.8, 0.2),
			cf * CFrame.new(-1.1 + (i - 1) * 1.1, 12.1, -6.1),
			if on then color else color:Lerp(Color3.new(0, 0, 0), 0.75),
			if on then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			"Signal"
		)
		noCollide(lamp)
	end
	model.Parent = parent
	return model
end

-- Poste de concreto com travessa, transformador às vezes; devolve o ponto de amarra dos fios
function Town.utilityPole(parent: Instance, position: Vector3, rng: Random): Vector3
	local model = Instance.new("Model")
	model.Name = "UtilityPole"
	Build.part(
		model,
		Vector3.new(0.9, 20, 0.9),
		CFrame.new(position + Vector3.new(0, 10, 0)),
		POLE,
		Enum.Material.Concrete,
		"Pole"
	)
	Build.part(
		model,
		Vector3.new(5, 0.35, 0.35),
		CFrame.new(position + Vector3.new(0, 18.6, 0)),
		Color3.fromRGB(60, 60, 62),
		Enum.Material.Metal,
		"Crossbar"
	)
	if rng:NextNumber() < 0.35 then
		Build.cylinder(
			model,
			2.2,
			1.4,
			CFrame.new(position + Vector3.new(0.9, 16, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(90, 92, 96),
			Enum.Material.Metal
		)
	end
	model.Parent = parent
	return position + Vector3.new(0, 18.4, 0)
end

-- Fio entre dois pontos com barriga (dois segmentos)
function Town.wire(parent: Instance, a: Vector3, b: Vector3, sag: number)
	local mid = (a + b) / 2 - Vector3.new(0, sag, 0)
	for _, pair in { { a, mid }, { mid, b } } do
		local p0, p1 = pair[1], pair[2]
		local length = (p1 - p0).Magnitude
		local w = Build.part(
			parent,
			Vector3.new(0.08, 0.08, length),
			CFrame.lookAt((p0 + p1) / 2, p1),
			WIRE,
			Enum.Material.SmoothPlastic,
			"Wire"
		)
		noCollide(w)
	end
end

-- Máquina de venda (frente acesa)
function Town.vending(parent: Instance, cf: CFrame, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Vending"
	local body = if rng:NextNumber() < 0.5 then Color3.fromRGB(230, 60, 60) else Color3.fromRGB(70, 120, 210)
	Build.part(
		model,
		Vector3.new(3.2, 6.5, 2.4),
		cf * CFrame.new(0, 3.25, 0),
		body,
		Enum.Material.SmoothPlastic,
		"Body"
	)
	local front = neonPart(
		model,
		Vector3.new(2.6, 3.2, 0.1),
		cf * CFrame.new(0, 4.3, -1.22),
		Color3.fromRGB(235, 245, 255),
		"Display"
	)
	noCollide(front)
	for row = 0, 1 do
		for col = -1, 1 do
			local can = Build.part(
				model,
				Vector3.new(0.5, 0.9, 0.1),
				cf * CFrame.new(col * 0.8, 3.6 + row * 1.3, -1.28),
				NEON[rng:NextInteger(1, #NEON)],
				Enum.Material.SmoothPlastic,
				"Can"
			)
			noCollide(can)
		end
	end
	Build.light(front, Color3.fromRGB(220, 235, 255), 10, 1.2)
	model.Parent = parent
end

-- Carro estacionado: carroceria, cabine com vidros, para-brisas inclinados, rodas, faróis e
-- lanternas acesas, retrovisores, placas. `cf`: centro no chão, frente para -Z.
local CAR_COLORS = {
	Color3.fromRGB(220, 222, 226),
	Color3.fromRGB(30, 32, 38),
	Color3.fromRGB(150, 20, 28),
	Color3.fromRGB(40, 70, 130),
	Color3.fromRGB(170, 172, 178),
	Color3.fromRGB(230, 200, 70),
	Color3.fromRGB(60, 95, 70),
}
function Town.car(parent: Instance, cf: CFrame, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Car"
	local paint = CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)]
	local w, l = 6.2, 13
	local function p(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
		local part = Build.part(model, size, cf * offset, color, material or Enum.Material.SmoothPlastic, name)
		return part
	end
	local body = p(Vector3.new(w, 2.1, l), CFrame.new(0, 2.05, 0), paint, Enum.Material.SmoothPlastic, "Body")
	body.Reflectance = 0.18
	-- cabine: vidro escuro com teto pintado
	local cabin = p(
		Vector3.new(w - 0.6, 1.9, l * 0.48),
		CFrame.new(0, 4.05, 0.6),
		Color3.fromRGB(20, 26, 34),
		Enum.Material.Glass,
		"Cabin"
	)
	cabin.Reflectance = 0.3
	p(Vector3.new(w - 0.5, 0.25, l * 0.44), CFrame.new(0, 5.1, 0.7), paint, Enum.Material.SmoothPlastic, "Roof").Reflectance =
		0.18
	-- para-brisas inclinados (cunhas de vidro)
	local front = Build.wedge(
		model,
		Vector3.new(w - 0.6, 1.9, 1.8),
		cf * CFrame.new(0, 4.05, -l * 0.24 + 0.6 - 0.9),
		Color3.fromRGB(20, 26, 34),
		Enum.Material.Glass
	)
	front.Reflectance = 0.35
	local rear = Build.wedge(
		model,
		Vector3.new(w - 0.6, 1.9, 1.4),
		cf * CFrame.new(0, 4.05, l * 0.24 + 0.6 + 0.7) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(20, 26, 34),
		Enum.Material.Glass
	)
	rear.Reflectance = 0.35
	-- rodas com calota
	for _, x in { -w / 2 + 0.3, w / 2 - 0.3 } do
		for _, z in { -l * 0.32, l * 0.32 } do
			Build.cylinder(
				model,
				0.9,
				2.4,
				cf * CFrame.new(x, 1.2, z),
				Color3.fromRGB(18, 18, 20),
				Enum.Material.Rubber
			)
			Build.cylinder(
				model,
				0.95,
				1.2,
				cf * CFrame.new(x, 1.2, z),
				Color3.fromRGB(170, 172, 176),
				Enum.Material.Metal
			)
		end
	end
	-- faróis e lanternas
	for _, x in { -w / 2 + 0.9, w / 2 - 0.9 } do
		local head = p(
			Vector3.new(1.2, 0.5, 0.15),
			CFrame.new(x, 2.4, -l / 2 - 0.05),
			Color3.fromRGB(255, 250, 235),
			Enum.Material.Neon,
			"Headlight"
		)
		noCollide(head)
		local tail = p(
			Vector3.new(1.2, 0.5, 0.15),
			CFrame.new(x, 2.5, l / 2 + 0.05),
			Color3.fromRGB(220, 20, 30),
			Enum.Material.Neon,
			"Taillight"
		)
		noCollide(tail)
		noCollide(
			p(
				Vector3.new(0.5, 0.35, 0.6),
				CFrame.new(x * 1.18, 3.4, -l * 0.2),
				paint,
				Enum.Material.SmoothPlastic,
				"Mirror"
			)
		)
	end
	for _, z in { -l / 2 - 0.06, l / 2 + 0.06 } do
		noCollide(
			p(
				Vector3.new(1.6, 0.6, 0.06),
				CFrame.new(0, 1.6, z),
				Color3.fromRGB(240, 240, 235),
				Enum.Material.SmoothPlastic,
				"Plate"
			)
		)
	end
	p(
		Vector3.new(w + 0.1, 0.5, l + 0.1),
		CFrame.new(0, 1.15, 0),
		Color3.fromRGB(28, 28, 30),
		Enum.Material.Plastic,
		"Bumper"
	)
	model.Parent = parent
	return model
end

-- Poça d'água no chão: manchas sobrepostas, escuras e refletoras
function Town.puddle(parent: Instance, position: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(2, 4) do
		local d = rng:NextNumber(2.5, 6)
		local p = Build.cylinder(
			parent,
			0.04,
			d,
			CFrame.new(position + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)))
				* CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(90)),
			Color3.fromRGB(14, 18, 26),
			Enum.Material.Glass
		)
		p.Name = "Puddle"
		p.Reflectance = 0.55
		p.Transparency = 0.15
		noCollide(p)
	end
end

-- Canteiro com arbustos e árvore de rua
function Town.planter(parent: Instance, cf: CFrame, rng: Random, tree: boolean)
	local model = Instance.new("Model")
	model.Name = "Planter"
	Build.part(
		model,
		Vector3.new(3.4, 1.2, 8),
		cf * CFrame.new(0, 0.6, 0),
		Color3.fromRGB(150, 146, 140),
		Enum.Material.Concrete,
		"Box"
	)
	Build.part(
		model,
		Vector3.new(3, 0.3, 7.6),
		cf * CFrame.new(0, 1.15, 0),
		Color3.fromRGB(70, 52, 38),
		Enum.Material.Ground,
		"Soil"
	)
	for i = -1, 1 do
		Build.part(
			model,
			Vector3.new(2.6, rng:NextNumber(1.4, 2), 2.4),
			cf * CFrame.new(0, 2, i * 2.4) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Color3.fromRGB(46, 84, 50):Lerp(Color3.fromRGB(70, 110, 60), rng:NextNumber()),
			Enum.Material.Grass,
			"Shrub"
		)
	end
	if tree then
		Build.tree(
			model,
			(cf * CFrame.new(0, 1.2, 0)).Position,
			if rng:NextNumber() < 0.5 then "pine" else "cherry",
			rng
		)
	end
	model.Parent = parent
end

-- Bicicleta encostada (quadro, rodas, guidão)
function Town.bicycle(parent: Instance, cf: CFrame, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Bicycle"
	local color = CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)]
	for _, z in { -1.6, 1.6 } do
		local wheel = Build.cylinder(
			model,
			0.12,
			2.6,
			cf * CFrame.new(0, 1.3, z),
			Color3.fromRGB(20, 20, 22),
			Enum.Material.Rubber
		)
		noCollide(wheel)
	end
	noCollide(
		Build.part(model, Vector3.new(0.15, 0.15, 3.2), cf * CFrame.new(0, 2.2, 0), color, Enum.Material.Metal, "Frame")
	)
	noCollide(
		Build.part(
			model,
			Vector3.new(0.15, 1.6, 0.15),
			cf * CFrame.new(0, 2.1, -1.1) * CFrame.Angles(math.rad(-15), 0, 0),
			color,
			Enum.Material.Metal,
			"Fork"
		)
	)
	noCollide(
		Build.part(
			model,
			Vector3.new(1.6, 0.12, 0.12),
			cf * CFrame.new(0, 3, -1.3),
			Color3.fromRGB(40, 40, 44),
			Enum.Material.Metal,
			"Bars"
		)
	)
	noCollide(
		Build.part(
			model,
			Vector3.new(0.5, 0.2, 0.9),
			cf * CFrame.new(0, 2.9, 0.9),
			Color3.fromRGB(30, 30, 30),
			Enum.Material.Fabric,
			"Seat"
		)
	)
	model.Parent = parent
end

-- Sacos de lixo na calçada
function Town.trash(parent: Instance, position: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(2, 4) do
		local s = rng:NextNumber(1.2, 1.9)
		local bag = Build.ball(
			parent,
			s,
			CFrame.new(position + Vector3.new(rng:NextNumber(-1.2, 1.2), s * 0.4, rng:NextNumber(-1.2, 1.2))),
			Color3.fromRGB(70, 90, 130):Lerp(Color3.fromRGB(30, 30, 34), rng:NextNumber()),
			Enum.Material.Plastic
		)
		bag.Size = Vector3.new(s, s * 0.85, s)
		bag.Name = "TrashBag"
		noCollide(bag)
	end
end

-- Tampa de bueiro no asfalto
function Town.manhole(parent: Instance, position: Vector3)
	local m = Build.cylinder(
		parent,
		0.05,
		2.6,
		CFrame.new(position + Vector3.new(0, 0.42, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(60, 58, 55),
		Enum.Material.DiamondPlate
	)
	m.Name = "Manhole"
	noCollide(m)
end

-- ======================================================================= prédios
-- Prédio comercial: térreo de loja (vidro aceso, toldo), andares com grade de janelas, faixa de
-- laje por andar, platibanda, caixa d'água e ar-condicionado no telhado, letreiro vertical.
-- `cf`: base no chão, frente para -Z.
function Town.building(parent: Instance, cf: CFrame, width: number, depth: number, floors: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Building"
	local floorH = 9
	local height = floors * floorH + 2
	local palettes = {
		Color3.fromRGB(196, 190, 182),
		Color3.fromRGB(150, 156, 166),
		Color3.fromRGB(176, 160, 146),
		Color3.fromRGB(120, 126, 136),
		Color3.fromRGB(212, 208, 200),
	}
	local wall = palettes[rng:NextInteger(1, #palettes)]
	Build.part(
		model,
		Vector3.new(width, height, depth),
		cf * CFrame.new(0, height / 2, 0),
		wall,
		Enum.Material.Concrete,
		"Walls"
	)
	-- térreo: loja com vitrine acesa e toldo listrado
	local shopLit = rng:NextNumber() < 0.8
	local glass = Build.part(
		model,
		Vector3.new(width - 3, 6, 0.3),
		cf * CFrame.new(0, 3.6, -depth / 2 - 0.1),
		if shopLit then WARM:Lerp(Color3.new(1, 1, 1), 0.3) else DARK_GLASS,
		if shopLit then Enum.Material.Neon else Enum.Material.Glass,
		"Storefront"
	)
	if shopLit then
		Build.light(glass, WARM, 16, 1.4)
	end
	local awning = NEON[rng:NextInteger(1, #NEON)]:Lerp(Color3.new(0.3, 0.3, 0.3), 0.35)
	local a = Build.wedge(
		model,
		Vector3.new(width - 1, 1.2, 3),
		cf * CFrame.new(0, 7.3, -depth / 2 - 1.5) * CFrame.Angles(0, math.pi, 0),
		awning,
		Enum.Material.Fabric
	)
	noCollide(a)
	-- faixas de laje e janelas por andar
	local columns = math.max(2, math.floor(width / 5))
	for floor = 1, floors - 1 do
		local y = floor * floorH + 1
		Build.part(
			model,
			Vector3.new(width + 0.4, 0.6, depth + 0.4),
			cf * CFrame.new(0, y, 0),
			wall:Lerp(Color3.new(0, 0, 0), 0.25),
			Enum.Material.Concrete,
			"Slab"
		)
		for c = 1, columns do
			local x = -width / 2 + (c - 0.5) * (width / columns)
			for _, side in { -1, 1 } do
				local lit = rng:NextNumber() < 0.42
				local tint = if rng:NextNumber() < 0.25 then COOL else WARM
				local win = Build.part(
					model,
					Vector3.new(width / columns - 1.6, 4.6, 0.25),
					cf * CFrame.new(x, y + 4.2, side * (depth / 2 + 0.08)),
					if lit then tint else DARK_GLASS,
					if lit then Enum.Material.Neon else Enum.Material.Glass,
					"Window"
				)
				noCollide(win)
				-- moldura escura em volta e peitoril saliente embaixo (profundidade na fachada)
				local frame = Build.part(
					model,
					Vector3.new(width / columns - 1.1, 5.1, 0.18),
					cf * CFrame.new(x, y + 4.2, side * (depth / 2 + 0.03)),
					wall:Lerp(Color3.new(0, 0, 0), 0.45),
					Enum.Material.Metal,
					"WindowFrame"
				)
				noCollide(frame)
				local sill = Build.part(
					model,
					Vector3.new(width / columns - 0.9, 0.25, 0.5),
					cf * CFrame.new(x, y + 1.7, side * (depth / 2 + 0.25)),
					wall:Lerp(Color3.new(1, 1, 1), 0.2),
					Enum.Material.Concrete,
					"Sill"
				)
				noCollide(sill)
			end
		end
		-- ar-condicionado pendurado nas laterais e varandinha às vezes
		for _, side in { -1, 1 } do
			if rng:NextNumber() < 0.45 then
				local ac = Build.part(
					model,
					Vector3.new(1.4, 1.8, 2.6),
					cf * CFrame.new(side * (width / 2 + 0.75), y + 2.4, rng:NextNumber(-depth / 3, depth / 3)),
					Color3.fromRGB(220, 220, 214),
					Enum.Material.Metal,
					"WallAC"
				)
				noCollide(ac)
				noCollide(
					Build.cylinder(
						model,
						0.1,
						1.2,
						ac.CFrame * CFrame.new(side * 0.72, 0, 0),
						Color3.fromRGB(60, 60, 64),
						Enum.Material.Metal
					)
				)
			end
		end
		if rng:NextNumber() < 0.25 then
			local bx = rng:NextNumber(-width / 4, width / 4)
			Build.part(
				model,
				Vector3.new(6, 0.35, 2.2),
				cf * CFrame.new(bx, y + 0.9, -depth / 2 - 1.1),
				Color3.fromRGB(150, 150, 152),
				Enum.Material.Concrete,
				"Balcony"
			)
			noCollide(
				Build.part(
					model,
					Vector3.new(6, 2.4, 0.15),
					cf * CFrame.new(bx, y + 2.1, -depth / 2 - 2.15),
					Color3.fromRGB(70, 75, 82),
					Enum.Material.Metal,
					"BalconyRail"
				)
			)
		end
	end
	-- calha descendo pela quina
	noCollide(
		Build.cylinder(
			model,
			height,
			0.35,
			cf * CFrame.new(width / 2 - 0.2, height / 2, depth / 2 + 0.25) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(110, 110, 112),
			Enum.Material.Metal
		)
	)
	-- antena no telhado
	if rng:NextNumber() < 0.4 then
		local ax = rng:NextNumber(-width / 3, width / 3)
		Build.part(
			model,
			Vector3.new(0.2, 6, 0.2),
			cf * CFrame.new(ax, height + 4, -depth / 4),
			Color3.fromRGB(80, 80, 85),
			Enum.Material.Metal,
			"Antenna"
		)
		local blink = neonPart(
			model,
			Vector3.new(0.4, 0.4, 0.4),
			cf * CFrame.new(ax, height + 7.1, -depth / 4),
			Color3.fromRGB(255, 40, 40),
			"AntennaLight"
		)
		noCollide(blink)
	end
	-- platibanda e telhado
	Build.part(
		model,
		Vector3.new(width + 0.6, 1.4, depth + 0.6),
		cf * CFrame.new(0, height + 0.2, 0),
		wall:Lerp(Color3.new(0, 0, 0), 0.15),
		Enum.Material.Concrete,
		"Parapet"
	)
	if rng:NextNumber() < 0.6 then
		local tank = cf
			* CFrame.new(rng:NextNumber(-width / 4, width / 4), height + 4.5, rng:NextNumber(-depth / 5, depth / 5))
		Build.cylinder(
			model,
			4,
			3.6,
			tank * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(200, 200, 196),
			Enum.Material.Metal
		)
		for _, dx in { -1.2, 1.2 } do
			Build.part(
				model,
				Vector3.new(0.3, 3, 0.3),
				tank * CFrame.new(dx, -2.8, 0),
				Color3.fromRGB(80, 80, 84),
				Enum.Material.Metal,
				"TankLeg"
			)
		end
	end
	for _ = 1, rng:NextInteger(1, 3) do
		Build.part(
			model,
			Vector3.new(2.2, 1.6, 1.6),
			cf
				* CFrame.new(
					rng:NextNumber(-width / 2.5, width / 2.5),
					height + 1.7,
					rng:NextNumber(-depth / 3, depth / 3)
				),
			Color3.fromRGB(210, 210, 206),
			Enum.Material.Metal,
			"AC"
		)
	end
	-- letreiro vertical em neon na quina da frente
	if floors >= 3 and rng:NextNumber() < 0.75 then
		local color = NEON[rng:NextInteger(1, #NEON)]
		local signH = math.min(floors * floorH - 6, 22)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local sign = Build.part(
			model,
			Vector3.new(0.6, signH, 3.2),
			cf
				* CFrame.new(side * (width / 2 + 0.3), 9 + signH / 2, -depth / 2 + 2)
				* CFrame.Angles(0, math.rad(90 * side), 0),
			Color3.fromRGB(18, 18, 24),
			Enum.Material.SmoothPlastic,
			"Sign"
		)
		local face = neonPart(
			model,
			Vector3.new(0.1, signH - 0.6, 2.8),
			sign.CFrame * CFrame.new(-0.36 * side, 0, 0),
			color,
			"SignGlow"
		)
		noCollide(face)
		face.Transparency = 0.55
		-- texto nas duas faces do letreiro
		local board = Build.part(
			model,
			Vector3.new(2.6, signH - 1, 0.1),
			cf * CFrame.new(side * (width / 2 + 0.3), 9 + signH / 2, -depth / 2 + 0.15),
			Color3.fromRGB(18, 18, 24),
			Enum.Material.SmoothPlastic,
			"SignBoard"
		)
		noCollide(board)
		signText(board, SIGN_TEXT[rng:NextInteger(1, #SIGN_TEXT)], color, true)
		Build.light(face, color, 18, 1.2)
	end
	model.Parent = parent
	return model
end

-- Casa japonesa: térreo + andar de cima recuado às vezes, telhado de telha com cumeeira e beiral,
-- varanda, muro baixo com portão e luminária na entrada
function Town.house(parent: Instance, cf: CFrame, width: number, depth: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "House"
	local floors = if rng:NextNumber() < 0.7 then 2 else 1
	local floorH = 9
	local height = floors * floorH
	local walls = {
		Color3.fromRGB(222, 214, 196),
		Color3.fromRGB(200, 204, 206),
		Color3.fromRGB(214, 196, 178),
		Color3.fromRGB(190, 200, 186),
	}
	local wall = walls[rng:NextInteger(1, #walls)]
	local roof = ({ Color3.fromRGB(58, 62, 78), Color3.fromRGB(110, 58, 48), Color3.fromRGB(70, 90, 80) })[rng:NextInteger(
		1,
		3
	)]
	Build.part(
		model,
		Vector3.new(width, height, depth),
		cf * CFrame.new(0, height / 2, 0),
		wall,
		Enum.Material.Plaster,
		"Walls"
	)
	Build.part(
		model,
		Vector3.new(width + 0.6, 0.8, depth + 0.6),
		cf * CFrame.new(0, 0.4, 0),
		Color3.fromRGB(110, 108, 104),
		Enum.Material.Concrete,
		"Base"
	)
	-- janelas com moldura de madeira, algumas acesas
	for floor = 1, floors do
		for _, x in { -width / 4, width / 4 } do
			for _, side in { -1, 1 } do
				local lit = rng:NextNumber() < 0.5
				local y = (floor - 1) * floorH + 5
				Build.part(
					model,
					Vector3.new(4, 3.6, 0.2),
					cf * CFrame.new(x, y, side * (depth / 2 + 0.05)),
					Color3.fromRGB(90, 66, 46),
					Enum.Material.Wood,
					"Frame"
				)
				local win = Build.part(
					model,
					Vector3.new(3.4, 3, 0.25),
					cf * CFrame.new(x, y, side * (depth / 2 + 0.1)),
					if lit then WARM else DARK_GLASS,
					if lit then Enum.Material.Neon else Enum.Material.Glass,
					"Window"
				)
				noCollide(win)
				-- grade de shoji: duas ripas
				noCollide(
					Build.part(
						model,
						Vector3.new(0.12, 3, 0.3),
						cf * CFrame.new(x, y, side * (depth / 2 + 0.12)),
						Color3.fromRGB(90, 66, 46),
						Enum.Material.Wood,
						"Mullion"
					)
				)
			end
		end
	end
	-- varanda no andar de cima
	if floors == 2 and rng:NextNumber() < 0.6 then
		Build.part(
			model,
			Vector3.new(width * 0.6, 0.4, 2.4),
			cf * CFrame.new(0, floorH + 0.2, -depth / 2 - 1.2),
			Color3.fromRGB(150, 150, 150),
			Enum.Material.Concrete,
			"Balcony"
		)
		Build.part(
			model,
			Vector3.new(width * 0.6, 2.4, 0.2),
			cf * CFrame.new(0, floorH + 1.6, -depth / 2 - 2.3),
			Color3.fromRGB(80, 80, 85),
			Enum.Material.Metal,
			"Rail"
		)
	end
	-- entrada: porta de correr e marquise com luz
	Build.part(
		model,
		Vector3.new(4, 6.5, 0.3),
		cf * CFrame.new(width * 0.22, 3.25, -depth / 2 - 0.1),
		Color3.fromRGB(80, 58, 42),
		Enum.Material.Wood,
		"Door"
	)
	local canopy = Build.wedge(
		model,
		Vector3.new(6, 1, 2.4),
		cf * CFrame.new(width * 0.22, 7.2, -depth / 2 - 1.2) * CFrame.Angles(0, math.pi, 0),
		roof,
		Enum.Material.Slate
	)
	noCollide(canopy)
	local entryLamp = neonPart(
		model,
		Vector3.new(0.6, 0.6, 0.3),
		cf * CFrame.new(width * 0.22 + 2.6, 5.6, -depth / 2 - 0.25),
		WARM,
		"EntryLamp"
	)
	noCollide(entryLamp)
	Build.light(entryLamp, WARM, 10, 0.9)
	-- telhado de duas águas com beiral largo e cumeeira escura
	local overhang = 2.2
	local roofH = math.min(6.5, depth * 0.32)
	local half = (depth + overhang * 2) / 2
	for _, side in { -1, 1 } do
		Build.wedge(
			model,
			Vector3.new(width + overhang * 2, roofH, half),
			cf
				* CFrame.new(0, height + roofH / 2, side * half / 2)
				* CFrame.Angles(0, if side < 0 then 0 else math.pi, 0),
			roof,
			Enum.Material.Slate
		)
	end
	Build.part(
		model,
		Vector3.new(width + overhang * 2 + 0.4, 0.6, 0.9),
		cf * CFrame.new(0, height + roofH + 0.2, 0),
		roof:Lerp(Color3.new(0, 0, 0), 0.4),
		Enum.Material.Slate,
		"Ridge"
	)
	-- muro baixo de bloco na frente com portão (vão) e luminária
	local wallZ = -depth / 2 - 5
	local gateX = width * 0.22
	for _, seg in { { -width / 2 - 1, gateX - 2.5 }, { gateX + 2.5, width / 2 + 1 } } do
		local len = seg[2] - seg[1]
		if len > 0.5 then
			Build.part(
				model,
				Vector3.new(len, 3.4, 0.8),
				cf * CFrame.new((seg[1] + seg[2]) / 2, 1.7, wallZ),
				Color3.fromRGB(170, 166, 158),
				Enum.Material.Brick,
				"BlockWall"
			)
			Build.part(
				model,
				Vector3.new(len, 0.3, 1),
				cf * CFrame.new((seg[1] + seg[2]) / 2, 3.5, wallZ),
				Color3.fromRGB(120, 116, 110),
				Enum.Material.Concrete,
				"WallCap"
			)
		end
	end
	for _, s in { -1, 1 } do
		Build.part(
			model,
			Vector3.new(1, 4.2, 1),
			cf * CFrame.new(gateX + s * 2.5, 2.1, wallZ),
			Color3.fromRGB(110, 106, 100),
			Enum.Material.Concrete,
			"GatePost"
		)
	end
	-- plantinha no quintal
	if rng:NextNumber() < 0.6 then
		Build.part(
			model,
			Vector3.new(2.2, 2.2, 2.2),
			cf * CFrame.new(-width * 0.3, 1.6, wallZ + 2.2) * CFrame.Angles(0, math.rad(45), 0),
			Color3.fromRGB(60, 100, 60),
			Enum.Material.Grass,
			"Shrub"
		)
	end
	model.Parent = parent
	return model
end

-- Loja de conveniência: vidro iluminado, faixa colorida, letreiro, máquinas de venda na frente
function Town.konbini(parent: Instance, cf: CFrame, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Konbini"
	local w, d, h = 28, 20, 10
	Build.part(
		model,
		Vector3.new(w, h, d),
		cf * CFrame.new(0, h / 2, 0),
		Color3.fromRGB(235, 235, 232),
		Enum.Material.Concrete,
		"Walls"
	)
	local glass = neonPart(
		model,
		Vector3.new(w - 2, 6.5, 0.3),
		cf * CFrame.new(0, 3.6, -d / 2 - 0.1),
		Color3.fromRGB(240, 250, 255),
		"Storefront"
	)
	Build.light(glass, Color3.fromRGB(230, 245, 255), 24, 2.2)
	for i, color in { Color3.fromRGB(40, 160, 90), Color3.fromRGB(255, 140, 40), Color3.fromRGB(40, 90, 200) } do
		Build.part(
			model,
			Vector3.new(w + 0.2, 0.7, d + 0.2),
			cf * CFrame.new(0, h - 2.6 + i * 0.7, 0),
			color,
			Enum.Material.SmoothPlastic,
			"Stripe"
		)
	end
	local sign = Build.part(
		model,
		Vector3.new(10, 2.2, 0.2),
		cf * CFrame.new(0, h + 1.6, -d / 2 + 0.5),
		Color3.fromRGB(250, 250, 250),
		Enum.Material.Neon,
		"Sign"
	)
	signText(sign, "コンビニ", Color3.fromRGB(40, 90, 200))
	for i = 0, 1 do
		Town.vending(model, cf * CFrame.new(w / 2 - 2 - i * 3.6, 0, -d / 2 - 2.2), rng)
	end
	model.Parent = parent
	return model
end

-- Rua comercial coberta (shōtengai): duas fileiras de lojinhas, teto translúcido, lanternas
-- vermelhas penduradas. `cf` no centro da rua; a rua corre em -Z/+Z por `length`.
function Town.arcade(parent: Instance, cf: CFrame, length: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Shotengai"
	local width = 14
	local shopD = 10
	local count = math.floor(length / 12)
	for _, side in { -1, 1 } do
		for i = 0, count - 1 do
			local z = -length / 2 + (i + 0.5) * (length / count)
			local x = side * (width / 2 + shopD / 2)
			local shopCf = cf * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(90 * side), 0)
			local wall = Color3.fromRGB(190, 180, 168):Lerp(Color3.fromRGB(150, 140, 130), rng:NextNumber())
			Build.part(
				model,
				Vector3.new(length / count - 0.6, 11, shopD),
				shopCf * CFrame.new(0, 5.5, 0),
				wall,
				Enum.Material.Concrete,
				"Shop"
			)
			local lit = rng:NextNumber() < 0.85
			local front = Build.part(
				model,
				Vector3.new(length / count - 2.2, 6, 0.3),
				shopCf * CFrame.new(0, 3.4, -shopD / 2 - 0.1),
				if lit then WARM:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.5)) else DARK_GLASS,
				if lit then Enum.Material.Neon else Enum.Material.Glass,
				"Front"
			)
			if lit and i % 2 == 0 then
				Build.light(front, WARM, 14, 1)
			end
			local noren = Build.part(
				model,
				Vector3.new(length / count - 3, 1.4, 0.1),
				shopCf * CFrame.new(0, 6.6, -shopD / 2 - 0.4),
				NEON[rng:NextInteger(1, #NEON)]:Lerp(Color3.new(0.2, 0.1, 0.1), 0.5),
				Enum.Material.Fabric,
				"Noren"
			)
			noCollide(noren)
		end
	end
	-- teto em arco simples: vigas e painéis translúcidos
	for i = 0, count do
		local z = -length / 2 + i * (length / count)
		Build.part(
			model,
			Vector3.new(width + 2, 0.6, 0.6),
			cf * CFrame.new(0, 13, z),
			Color3.fromRGB(90, 90, 96),
			Enum.Material.Metal,
			"Beam"
		)
	end
	local roof = Build.part(
		model,
		Vector3.new(width + 2, 0.3, length),
		cf * CFrame.new(0, 13.5, 0),
		Color3.fromRGB(200, 220, 230),
		Enum.Material.Glass,
		"Skylight"
	)
	roof.Transparency = 0.55
	-- lanternas vermelhas penduradas em duas fileiras
	for i = 0, count * 2 - 1 do
		local z = -length / 2 + (i + 0.5) * (length / (count * 2))
		for _, x in { -3.5, 3.5 } do
			local lantern = Build.cylinder(
				model,
				1.8,
				1.4,
				cf * CFrame.new(x, 10.5, z) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(230, 50, 40),
				Enum.Material.Neon
			)
			noCollide(lantern)
			noCollide(
				Build.part(
					model,
					Vector3.new(0.08, 2.5, 0.08),
					cf * CFrame.new(x, 12.4, z),
					WIRE,
					Enum.Material.SmoothPlastic,
					"Cord"
				)
			)
			if i % 3 == 0 and x < 0 then
				Build.light(lantern, Color3.fromRGB(255, 120, 90), 12, 1)
			end
		end
	end
	-- portais nas duas pontas com letreiro
	for _, s in { -1, 1 } do
		local gate = Build.part(
			model,
			Vector3.new(width + 2, 2.4, 0.6),
			cf * CFrame.new(0, 15, s * length / 2),
			Color3.fromRGB(30, 30, 36),
			Enum.Material.SmoothPlastic,
			"GateSign"
		)
		local glow = neonPart(
			model,
			Vector3.new(width, 1.8, 0.1),
			gate.CFrame * CFrame.new(0, 0, if s < 0 then -0.36 else 0.36),
			Color3.fromRGB(255, 200, 120),
			"GateGlow"
		)
		glow.Transparency = 0.4
		noCollide(glow)
		signText(gate, "空座商店街", Color3.fromRGB(255, 230, 180))
	end
	model.Parent = parent
	return model
end

-- Trilho elevado ao longo de Z: pilares (pulando `blocked(p)`), viga, trilhos, mureta
function Town.railway(parent: Instance, start: Vector3, finish: Vector3, height: number, blocked: (Vector3) -> boolean)
	local model = Instance.new("Model")
	model.Name = "Railway"
	local dir = finish - start
	local length = dir.Magnitude
	local frame = CFrame.lookAt(start, finish)
	Build.part(
		model,
		Vector3.new(12, 2.2, length),
		frame * CFrame.new(0, height, -length / 2),
		Color3.fromRGB(140, 140, 144),
		Enum.Material.Concrete,
		"Deck"
	)
	for _, x in { -2.6, 2.6 } do
		Build.part(
			model,
			Vector3.new(0.4, 0.5, length),
			frame * CFrame.new(x, height + 1.35, -length / 2),
			Color3.fromRGB(110, 100, 90),
			Enum.Material.Metal,
			"Rail"
		)
	end
	for _, x in { -5.8, 5.8 } do
		Build.part(
			model,
			Vector3.new(0.4, 2.2, length),
			frame * CFrame.new(x, height + 2.2, -length / 2),
			Color3.fromRGB(150, 150, 152),
			Enum.Material.Concrete,
			"Parapet"
		)
	end
	for t = 10, length - 10, 36 do
		local p = (frame * CFrame.new(0, 0, -t)).Position
		if not blocked(p) then
			Build.part(
				model,
				Vector3.new(3.2, height - 1, 3.2),
				CFrame.new(p + Vector3.new(0, (height - 1) / 2, 0)),
				Color3.fromRGB(150, 150, 154),
				Enum.Material.Concrete,
				"Pillar"
			)
			Build.part(
				model,
				Vector3.new(11, 1.6, 3.6),
				CFrame.new(p + Vector3.new(0, height - 1.6, 0)),
				Color3.fromRGB(150, 150, 154),
				Enum.Material.Concrete,
				"Capital"
			)
		end
	end
	-- trem parado: três vagões com janelas acesas
	for car = 0, 2 do
		local z = length * 0.3 + car * 21
		local body = Build.part(
			model,
			Vector3.new(7, 7, 20),
			frame * CFrame.new(0, height + 5, -z),
			Color3.fromRGB(225, 228, 232),
			Enum.Material.Metal,
			"Car"
		)
		Build.part(
			model,
			Vector3.new(7.1, 0.8, 20.1),
			body.CFrame * CFrame.new(0, -1, 0),
			Color3.fromRGB(60, 150, 90),
			Enum.Material.SmoothPlastic,
			"CarStripe"
		)
		for _, side in { -1, 1 } do
			local windows = neonPart(
				model,
				Vector3.new(0.1, 2, 17),
				body.CFrame * CFrame.new(side * 3.56, 1.2, 0),
				Color3.fromRGB(255, 240, 210),
				"CarWindows"
			)
			noCollide(windows)
		end
	end
	model.Parent = parent
	return model
end

return Town

-- Arquitetura do Seireitei (Soul Society): salões tradicionais em pódio de pedra com estrutura
-- de madeira aparente, painéis shoji, varanda (engawa) e telhado de quatro águas com beiral
-- grosso e pontas erguidas; muros brancos com capa de telha; portão monumental; pagode de cinco
-- andares; torre branca Senzaikyū; colina do Sōkyoku com a estrutura de execução; lago com ponte
-- arqueada vermelha; lanternas de pedra (tōrō) e estandartes das divisões.
-- Tudo em peças do Roblox (sem assets externos), determinístico pelo Random do chamador.
local Build = require(script.Parent.Build)

local Seireitei = {}

local PLASTER = Color3.fromRGB(240, 236, 228)
local WOOD = Color3.fromRGB(70, 42, 32)
local WOOD_LIGHT = Color3.fromRGB(150, 104, 70)
local ROOF = Color3.fromRGB(46, 56, 70)
local ROOF_EDGE = Color3.fromRGB(32, 38, 48)
local STONE = Color3.fromRGB(150, 146, 138)
local STONE_DARK = Color3.fromRGB(110, 106, 100)
local SHOJI = Color3.fromRGB(246, 236, 210)
local VERMILION = Color3.fromRGB(200, 52, 38)
local GOLD = Color3.fromRGB(226, 186, 92)

Seireitei.Colors = { plaster = PLASTER, wood = WOOD, roof = ROOF, stone = STONE, vermilion = VERMILION }

local function quiet(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
end

-- Texto num painel (face -Z); `vertical`: um caractere por linha (japonês empilhado)
local function sign(panel: BasePart, text: string, color: Color3, vertical: boolean?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0.4
	gui.PixelsPerStud = 40
	gui.Parent = panel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	if vertical then
		local chars = {}
		for _, code in utf8.codes(text) do
			table.insert(chars, utf8.char(code))
		end
		label.Text = table.concat(chars, "\n")
	else
		label.Text = text
	end
	label.Parent = gui
end
Seireitei.sign = sign

-- ======================================================================= telhado
-- Telhado de quatro águas sobre um retângulo W×D (cf no nível do beiral, centro): duas águas
-- longas (cunhas costas com costas) + duas águas das pontas, beiral grosso de madeira escura,
-- cumeeira com onigawara nas pontas e as quinas do beiral erguidas (curva dos telhados japoneses).
function Seireitei.roof(parent: Instance, cf: CFrame, w: number, d: number, h: number, overhang: number, color: Color3?)
	local tile = color or ROOF
	local W, D = w + overhang * 2, d + overhang * 2
	-- águas longas (frente/trás)
	for _, side in { 0, math.pi } do
		Build.wedge(
			parent,
			Vector3.new(W, h, D / 2),
			cf * CFrame.Angles(0, side, 0) * CFrame.new(0, h / 2 + 0.6, -D / 4),
			tile,
			Enum.Material.Slate
		)
	end
	-- águas das pontas (quatro águas): mais curtas, cruzam as longas na quina
	for _, side in { math.pi / 2, -math.pi / 2 } do
		local depth = math.min(D / 2, W / 2)
		Build.wedge(
			parent,
			Vector3.new(D, h, depth),
			cf * CFrame.Angles(0, side, 0) * CFrame.new(0, h / 2 + 0.6, -(W / 2 - depth / 2)),
			tile,
			Enum.Material.Slate
		)
	end
	-- beiral grosso (a linha escura marcante embaixo do telhado)
	local eave = Build.part(
		parent,
		Vector3.new(W + 0.4, 0.8, D + 0.4),
		cf * CFrame.new(0, 0.4, 0),
		ROOF_EDGE,
		Enum.Material.Wood,
		"Eave"
	)
	quiet(eave)
	-- quinas erguidas
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local tip = Build.wedge(
			parent,
			Vector3.new(1.6, 1.4, 3.2),
			cf
				* CFrame.new(corner[1] * (W / 2 - 0.4), 1.1, corner[2] * (D / 2 - 0.4))
				* CFrame.Angles(0, math.atan2(corner[1], corner[2]) + math.pi, 0)
				* CFrame.Angles(math.rad(-18), 0, 0),
			ROOF_EDGE,
			Enum.Material.Slate
		)
		quiet(tip)
	end
	-- cumeeira e onigawara
	local ridgeLen = math.max(1, W - D)
	local ridge = Build.part(
		parent,
		Vector3.new(ridgeLen + 1, 0.9, 1),
		cf * CFrame.new(0, h + 1, 0),
		ROOF_EDGE,
		Enum.Material.Slate,
		"Ridge"
	)
	quiet(ridge)
	for _, s in { -1, 1 } do
		local oni = Build.part(
			parent,
			Vector3.new(0.9, 1.8, 1.4),
			cf * CFrame.new(s * (ridgeLen / 2 + 0.5), h + 1.6, 0),
			ROOF_EDGE,
			Enum.Material.Slate,
			"Onigawara"
		)
		quiet(oni)
	end
end

-- ======================================================================= salão
export type HallOptions = {
	floors: number?,
	height: number?,
	podium: number?,
	wall: Color3?,
	roof: Color3?,
	shoji: boolean?,
	veranda: boolean?,
}

-- Salão tradicional (frente em -Z de `cf`, cf no chão): pódio de pedra com escada, paredes de
-- reboco com pilares e vigas de madeira, painéis shoji entre os pilares, engawa na frente e
-- telhado de quatro águas; `floors = 2` acrescenta um andar recuado com telhado próprio.
function Seireitei.hall(parent: Instance, cf: CFrame, w: number, d: number, options: HallOptions?): Model
	local o: HallOptions = options or {}
	local model = Instance.new("Model")
	model.Name = "Hall"
	local ph = o.podium or 2.4
	local wallH = o.height or 13
	local wall = o.wall or PLASTER
	-- pódio e escada
	Build.part(
		model,
		Vector3.new(w + 6, ph, d + 6),
		cf * CFrame.new(0, ph / 2, 0),
		STONE,
		Enum.Material.Granite,
		"Podium"
	)
	Build.part(
		model,
		Vector3.new(w + 6.6, 0.5, d + 6.6),
		cf * CFrame.new(0, ph - 0.1, 0),
		STONE:Lerp(Color3.new(1, 1, 1), 0.15),
		Enum.Material.Granite,
		"PodiumCap"
	)
	local steps = math.max(2, math.floor(ph / 0.8))
	for i = 1, steps do
		Build.part(
			model,
			Vector3.new(math.min(12, w * 0.4), ph * i / steps, 1.2),
			cf * CFrame.new(0, ph * i / steps / 2, -(d / 2 + 3) - (steps - i + 0.5) * 1.2),
			STONE_DARK,
			Enum.Material.Granite,
			"Step"
		)
	end

	local function storey(base: number, sw: number, sd: number, sh: number, last: boolean)
		local body = cf * CFrame.new(0, base, 0)
		Build.part(
			model,
			Vector3.new(sw, sh, sd),
			body * CFrame.new(0, sh / 2, 0),
			wall,
			Enum.Material.Plaster,
			"Walls"
		)
		-- pilares de madeira (frente/trás em vãos de ~6, laterais nas quinas e no meio)
		local bays = math.max(2, math.floor(sw / 6))
		for i = 0, bays do
			local x = -sw / 2 + i * sw / bays
			for _, z in { -sd / 2, sd / 2 } do
				local pillar = Build.part(
					model,
					Vector3.new(0.9, sh, 0.9),
					body * CFrame.new(x, sh / 2, z),
					WOOD,
					Enum.Material.Wood,
					"Pillar"
				)
				quiet(pillar)
			end
			-- shoji entre os pilares da frente (papel claro com travessas)
			if o.shoji ~= false and i < bays then
				local mid = x + sw / bays / 2
				local panel = Build.part(
					model,
					Vector3.new(sw / bays - 1.2, sh * 0.62, 0.2),
					body * CFrame.new(mid, sh * 0.42, -sd / 2 - 0.12),
					SHOJI,
					Enum.Material.SmoothPlastic,
					"Shoji"
				)
				quiet(panel)
				for _, k in { -0.25, 0.25 } do
					local bar = Build.part(
						model,
						Vector3.new(sw / bays - 1.2, 0.12, 0.1),
						panel.CFrame * CFrame.new(0, sh * 0.62 * k, -0.12),
						WOOD,
						Enum.Material.Wood,
						"Kumiko"
					)
					quiet(bar)
				end
				local stile = Build.part(
					model,
					Vector3.new(0.12, sh * 0.62, 0.1),
					panel.CFrame * CFrame.new(0, 0, -0.12),
					WOOD,
					Enum.Material.Wood,
					"Kumiko"
				)
				quiet(stile)
			end
		end
		for _, x in { -sw / 2, sw / 2 } do
			for _, z in { -sd / 4, sd / 4 } do
				quiet(
					Build.part(
						model,
						Vector3.new(0.9, sh, 0.9),
						body * CFrame.new(x, sh / 2, z),
						WOOD,
						Enum.Material.Wood,
						"Pillar"
					)
				)
			end
		end
		-- vigas horizontais (nageshi) em volta: no alto e na altura da porta
		for _, y in { sh - 0.5, sh * 0.78 } do
			quiet(
				Build.part(
					model,
					Vector3.new(sw + 0.5, 0.6, sd + 0.5),
					body * CFrame.new(0, y, 0),
					WOOD,
					Enum.Material.Wood,
					"Beam"
				)
			)
		end
		-- telhado
		local overhang = if last then 4 else 3
		Seireitei.roof(model, body * CFrame.new(0, sh, 0), sw, sd, math.min(sw, sd) * 0.32, overhang, o.roof)
	end

	local floors = o.floors or 1
	storey(ph, w, d, wallH, floors == 1)
	if floors >= 2 then
		storey(ph + wallH + 1.4, w * 0.72, d * 0.72, wallH * 0.7, true)
	end
	-- engawa (varanda de madeira) com corrimão
	if o.veranda ~= false then
		Build.part(
			model,
			Vector3.new(w + 2, 0.5, 3),
			cf * CFrame.new(0, ph + 0.25, -d / 2 - 1.5),
			WOOD_LIGHT,
			Enum.Material.WoodPlanks,
			"Engawa"
		)
		for _, s in { -1, 1 } do
			quiet(
				Build.part(
					model,
					Vector3.new(w / 2 - 4, 0.25, 0.25),
					cf * CFrame.new(s * (w / 4 + 2), ph + 2.4, -d / 2 - 2.9),
					VERMILION,
					Enum.Material.Wood,
					"Rail"
				)
			)
		end
	end
	model.Parent = parent
	return model
end

-- ======================================================================= muro branco
-- Muro do Seireitei: rodapé de pedra, reboco branco, capa de telha (duas águas) com cumeeira.
function Seireitei.wall(parent: Instance, a: Vector3, b: Vector3, height: number?)
	local h = height or 14
	local length = (b - a).Magnitude
	if length < 1 then
		return
	end
	local frame = CFrame.lookAt((a + b) / 2, b) -- comprimento ao longo de -Z
	Build.part(
		parent,
		Vector3.new(3.4, 2, length),
		frame * CFrame.new(0, 1, 0),
		STONE_DARK,
		Enum.Material.Granite,
		"WallBase"
	)
	Build.part(
		parent,
		Vector3.new(3, h - 2, length),
		frame * CFrame.new(0, 2 + (h - 2) / 2, 0),
		PLASTER,
		Enum.Material.Plaster,
		"Wall"
	)
	-- faixa escura logo abaixo da telha
	quiet(
		Build.part(
			parent,
			Vector3.new(3.1, 0.6, length),
			frame * CFrame.new(0, h - 0.3, 0),
			WOOD,
			Enum.Material.Wood,
			"WallBeam"
		)
	)
	for _, side in { -1, 1 } do
		local cap = Build.wedge(
			parent,
			Vector3.new(length + 1.2, 1.6, 2.8),
			frame * CFrame.new(side * 1.4, h + 0.8, 0) * CFrame.Angles(0, math.rad(-90 * side), 0),
			ROOF,
			Enum.Material.Slate
		)
		cap.Name = "WallRoof"
	end
	quiet(
		Build.part(
			parent,
			Vector3.new(0.9, 0.7, length + 1.2),
			frame * CFrame.new(0, h + 1.9, 0),
			ROOF_EDGE,
			Enum.Material.Slate,
			"WallRidge"
		)
	)
end

-- ======================================================================= portão
-- Portão monumental (frente em -Z): duas torres de guarda com pódio, portas de madeira enormes
-- com tachas de metal, viga com placa do nome e telhado de duas camadas por cima.
function Seireitei.gate(parent: Instance, cf: CFrame, opening: number, name: string)
	local model = Instance.new("Model")
	model.Name = "Gate"
	local towerW, towerH = 18, 34
	for _, s in { -1, 1 } do
		local x = s * (opening / 2 + towerW / 2)
		Build.part(
			model,
			Vector3.new(towerW + 4, 4, 22),
			cf * CFrame.new(x, 2, 0),
			STONE,
			Enum.Material.Granite,
			"TowerBase"
		)
		Seireitei.hall(
			model,
			cf * CFrame.new(x, 4, 0),
			towerW,
			18,
			{ height = towerH - 8, podium = 0.4, shoji = false, veranda = false }
		)
	end
	-- portas abertas para dentro, encostadas nas torres
	for _, s in { -1, 1 } do
		local door = Build.part(
			model,
			Vector3.new(opening / 2, towerH - 6, 1.2),
			cf
				* CFrame.new(s * (opening / 2 - 0.6), (towerH - 6) / 2, opening / 4 + 1)
				* CFrame.Angles(0, math.rad(90 * s), 0),
			WOOD,
			Enum.Material.Wood,
			"Door"
		)
		for row = -2, 2 do
			for col = -1, 1 do
				quiet(
					Build.part(
						model,
						Vector3.new(0.5, 0.5, 0.3),
						door.CFrame * CFrame.new(col * opening / 8, row * (towerH - 6) / 6, -0.7),
						GOLD,
						Enum.Material.Metal,
						"Stud"
					)
				)
			end
		end
	end
	-- viga sobre a passagem, placa e telhado em duas camadas
	local span = opening + towerW * 2 + 4
	Build.part(model, Vector3.new(span, 3, 6), cf * CFrame.new(0, towerH - 4.5, 0), WOOD, Enum.Material.Wood, "Lintel")
	local plaque = Build.part(
		model,
		Vector3.new(14, 4.6, 0.6),
		cf * CFrame.new(0, towerH - 9, -3.4),
		WOOD,
		Enum.Material.Wood,
		"Plaque"
	)
	quiet(plaque)
	quiet(
		Build.part(
			model,
			Vector3.new(15, 5.6, 0.4),
			plaque.CFrame * CFrame.new(0, 0, 0.2),
			GOLD,
			Enum.Material.Metal,
			"PlaqueFrame"
		)
	)
	sign(plaque, name, GOLD)
	Seireitei.roof(model, cf * CFrame.new(0, towerH - 3, 0), span, 10, 5, 3)
	Seireitei.roof(model, cf * CFrame.new(0, towerH + 3.4, 0), opening + 8, 6, 4, 2.4)
	model.Parent = parent
	return model
end

-- ======================================================================= pagode
-- Pagode de cinco andares: cada andar menor, beirais largos com as pontas erguidas, varandinha
-- vermelha no primeiro, sōrin dourado (mastro com nove anéis) no topo.
function Seireitei.pagoda(parent: Instance, cf: CFrame, base: number)
	local model = Instance.new("Model")
	model.Name = "Pagoda"
	Build.part(
		model,
		Vector3.new(base + 10, 3, base + 10),
		cf * CFrame.new(0, 1.5, 0),
		STONE,
		Enum.Material.Granite,
		"Platform"
	)
	local y = 3
	for i = 0, 4 do
		local s = base * (1 - i * 0.13)
		local h = if i == 0 then 13 else 9
		local body = cf * CFrame.new(0, y, 0)
		Build.part(
			model,
			Vector3.new(s, h, s),
			body * CFrame.new(0, h / 2, 0),
			PLASTER,
			Enum.Material.Plaster,
			"Storey"
		)
		for _, cx in { -1, 1 } do
			for _, cz in { -1, 1 } do
				quiet(
					Build.part(
						model,
						Vector3.new(1, h, 1),
						body * CFrame.new(cx * s / 2, h / 2, cz * s / 2),
						VERMILION,
						Enum.Material.Wood,
						"Pillar"
					)
				)
			end
		end
		quiet(
			Build.part(
				model,
				Vector3.new(s + 0.4, 0.8, s + 0.4),
				body * CFrame.new(0, h - 0.4, 0),
				VERMILION,
				Enum.Material.Wood,
				"Beam"
			)
		)
		if i == 0 then
			Build.part(
				model,
				Vector3.new(s + 6, 0.6, s + 6),
				body * CFrame.new(0, 0.3, 0),
				WOOD_LIGHT,
				Enum.Material.WoodPlanks,
				"Gallery"
			)
		end
		Seireitei.roof(model, body * CFrame.new(0, h, 0), s, s, s * 0.22, 5.5 - i * 0.4)
		y += h + s * 0.22 + 0.6
	end
	-- sōrin
	local mastH = 22
	Build.part(
		model,
		Vector3.new(1.2, mastH, 1.2),
		cf * CFrame.new(0, y + mastH / 2, 0),
		GOLD,
		Enum.Material.Metal,
		"Sorin"
	)
	for k = 1, 9 do
		quiet(
			Build.part(
				model,
				Vector3.new(3.2 - k * 0.18, 0.35, 3.2 - k * 0.18),
				cf * CFrame.new(0, y + 3 + k * 1.6, 0),
				GOLD,
				Enum.Material.Metal,
				"SorinRing"
			)
		)
	end
	local jewel = Build.ball(
		model,
		2.2,
		cf * CFrame.new(0, y + mastH + 0.6, 0),
		Color3.fromRGB(255, 225, 150),
		Enum.Material.Neon
	)
	Build.light(jewel, Color3.fromRGB(255, 220, 150), 40, 1.2)
	model.Parent = parent
	return model
end

-- ======================================================================= Senzaikyū
-- Torre branca alta (prisão do Seireitei): fuste quadrado com faixas, câmara no topo com telhado
-- escuro e janela única, ponte estreita para uma plataforma.
function Seireitei.whiteTower(parent: Instance, cf: CFrame, height: number)
	local model = Instance.new("Model")
	model.Name = "Senzaikyu"
	Build.part(model, Vector3.new(26, 6, 26), cf * CFrame.new(0, 3, 0), STONE, Enum.Material.Granite, "Base")
	Build.part(
		model,
		Vector3.new(12, height, 12),
		cf * CFrame.new(0, 6 + height / 2, 0),
		Color3.fromRGB(246, 246, 244),
		Enum.Material.Marble,
		"Shaft"
	)
	for k = 1, 6 do
		quiet(
			Build.part(
				model,
				Vector3.new(12.6, 0.8, 12.6),
				cf * CFrame.new(0, 6 + height * k / 7, 0),
				Color3.fromRGB(214, 214, 210),
				Enum.Material.Marble,
				"Band"
			)
		)
	end
	local top = cf * CFrame.new(0, 6 + height, 0)
	Build.part(
		model,
		Vector3.new(20, 14, 20),
		top * CFrame.new(0, 7, 0),
		Color3.fromRGB(246, 246, 244),
		Enum.Material.Marble,
		"Chamber"
	)
	local window = Build.part(
		model,
		Vector3.new(3, 5, 0.3),
		top * CFrame.new(0, 8, -10.1),
		Color3.fromRGB(20, 20, 26),
		Enum.Material.SmoothPlastic,
		"Window"
	)
	quiet(window)
	Seireitei.roof(model, top * CFrame.new(0, 14, 0), 20, 20, 7, 3)
	-- ponte estreita até um pilar de pedra
	local bridgeLen = 60
	Build.part(
		model,
		Vector3.new(4, 1, bridgeLen),
		top * CFrame.new(0, 0.5, -10 - bridgeLen / 2),
		WOOD_LIGHT,
		Enum.Material.WoodPlanks,
		"Bridge"
	)
	for _, s in { -1, 1 } do
		quiet(
			Build.part(
				model,
				Vector3.new(0.3, 1.2, bridgeLen),
				top * CFrame.new(s * 1.9, 1.6, -10 - bridgeLen / 2),
				VERMILION,
				Enum.Material.Wood,
				"BridgeRail"
			)
		)
	end
	Build.part(
		model,
		Vector3.new(10, 6 + height, 10),
		cf * CFrame.new(0, (6 + height) / 2, -10 - bridgeLen - 5),
		STONE_DARK,
		Enum.Material.Slate,
		"BridgePier"
	)
	model.Parent = parent
	return model
end

-- ======================================================================= Sōkyoku
-- Colina de pedra com escadaria e, no alto, a estrutura do Sōkyoku: dois pilares enormes, viga
-- com cordas e a lança gigante pendurada, envolta num brilho de chama.
function Seireitei.sokyoku(parent: Instance, cf: CFrame, radius: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Sokyoku"
	local hillH = radius * 0.9
	-- colina em camadas de rocha (do largo para o estreito)
	for i = 0, 5 do
		local r = radius * (1 - i * 0.14)
		local rock = Build.cylinder(
			model,
			hillH / 6 + 0.5,
			r * 2,
			cf
				* CFrame.new(rng:NextNumber(-1.5, 1.5), i * hillH / 6 + hillH / 12, rng:NextNumber(-1.5, 1.5))
				* CFrame.Angles(0, 0, math.rad(90)),
			STONE_DARK:Lerp(Color3.fromRGB(120, 116, 104), rng:NextNumber()),
			Enum.Material.Rock
		)
		rock.Name = "Hill"
	end
	-- escadaria de frente (-Z)
	local steps = 22
	for i = 1, steps do
		Build.part(
			model,
			Vector3.new(8, hillH * i / steps, 2),
			cf * CFrame.new(0, hillH * i / steps / 2, -radius - 2 + i * (radius * 0.75 / steps)),
			STONE,
			Enum.Material.Granite,
			"Stair"
		)
	end
	local top = cf * CFrame.new(0, hillH + 0.5, 0)
	-- estrutura de execução
	for _, s in { -1, 1 } do
		Build.part(
			model,
			Vector3.new(3, 46, 3),
			top * CFrame.new(s * 12, 23, 0),
			WOOD,
			Enum.Material.Wood,
			"SokyokuPost"
		)
	end
	Build.part(model, Vector3.new(30, 3, 3.4), top * CFrame.new(0, 46, 0), WOOD, Enum.Material.Wood, "SokyokuBeam")
	Build.part(model, Vector3.new(26, 1.6, 2.6), top * CFrame.new(0, 40, 0), WOOD, Enum.Material.Wood, "SokyokuBeam")
	-- lança gigante
	local spear = top * CFrame.new(0, 22, -6)
	Build.part(model, Vector3.new(1.4, 26, 1.4), spear, WOOD_LIGHT, Enum.Material.Wood, "SpearShaft")
	local blade = Build.wedge(
		model,
		Vector3.new(0.6, 10, 3),
		spear * CFrame.new(0, -18, 0) * CFrame.Angles(math.pi, 0, 0),
		Color3.fromRGB(220, 224, 230),
		Enum.Material.Metal
	)
	blade.Name = "SpearBlade"
	local flame = Build.ball(model, 5, spear * CFrame.new(0, -13, 0), Color3.fromRGB(255, 140, 50), Enum.Material.Neon)
	flame.Transparency = 0.45
	quiet(flame)
	Build.light(flame, Color3.fromRGB(255, 150, 70), 40, 1.6)
	for _, s in { -1, 1 } do
		quiet(
			Build.part(
				model,
				Vector3.new(0.3, 0.3, 14),
				top * CFrame.new(s * 6, 40, -3) * CFrame.Angles(math.rad(-40), math.rad(30 * s), 0),
				Color3.fromRGB(230, 220, 190),
				Enum.Material.Fabric,
				"Rope"
			)
		)
	end
	model.Parent = parent
	return model
end

-- ======================================================================= detalhes
-- Lanterna de pedra (tōrō): base, haste, caixa de fogo acesa, chapéu e ponta
function Seireitei.lantern(parent: Instance, position: Vector3, scale: number?)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Toro"
	local base = CFrame.new(position)
	Build.part(
		model,
		Vector3.new(2.2, 0.6, 2.2) * s,
		base * CFrame.new(0, 0.3 * s, 0),
		STONE,
		Enum.Material.Granite,
		"Base"
	)
	Build.part(
		model,
		Vector3.new(0.9, 3, 0.9) * s,
		base * CFrame.new(0, 2.1 * s, 0),
		STONE,
		Enum.Material.Granite,
		"Post"
	)
	Build.part(
		model,
		Vector3.new(2, 0.4, 2) * s,
		base * CFrame.new(0, 3.8 * s, 0),
		STONE,
		Enum.Material.Granite,
		"Platform"
	)
	local fire = Build.part(
		model,
		Vector3.new(1.4, 1.4, 1.4) * s,
		base * CFrame.new(0, 4.7 * s, 0),
		Color3.fromRGB(255, 214, 150),
		Enum.Material.Neon,
		"FireBox"
	)
	Build.light(fire, Color3.fromRGB(255, 200, 140), 16 * s, 0.9)
	for _, side in { 0, math.pi / 2 } do
		Build.wedge(
			model,
			Vector3.new(3, 0.9, 1.5) * s,
			base * CFrame.Angles(0, side, 0) * CFrame.new(0, 5.85 * s, -0.75 * s),
			STONE,
			Enum.Material.Granite
		)
		Build.wedge(
			model,
			Vector3.new(3, 0.9, 1.5) * s,
			base * CFrame.Angles(0, side + math.pi, 0) * CFrame.new(0, 5.85 * s, -0.75 * s),
			STONE,
			Enum.Material.Granite
		)
	end
	Build.ball(model, 0.7 * s, base * CFrame.new(0, 6.6 * s, 0), STONE, Enum.Material.Granite)
	model.Parent = parent
	return model
end

-- Ponte arqueada vermelha (taiko-bashi) de `a` a `b`, por cima de água
function Seireitei.archBridge(parent: Instance, a: Vector3, b: Vector3, width: number, rise: number)
	local model = Instance.new("Model")
	model.Name = "ArchBridge"
	local segments = 10
	local dir = b - a
	for i = 0, segments - 1 do
		local t0, t1 = i / segments, (i + 1) / segments
		local p0 = a + dir * t0 + Vector3.new(0, math.sin(t0 * math.pi) * rise, 0)
		local p1 = a + dir * t1 + Vector3.new(0, math.sin(t1 * math.pi) * rise, 0)
		local frame = CFrame.lookAt((p0 + p1) / 2, p1)
		local len = (p1 - p0).Magnitude + 0.2
		Build.part(model, Vector3.new(width, 0.6, len), frame, WOOD_LIGHT, Enum.Material.WoodPlanks, "Deck")
		for _, s in { -1, 1 } do
			quiet(
				Build.part(
					model,
					Vector3.new(0.35, 0.35, len),
					frame * CFrame.new(s * (width / 2 - 0.2), 2.4, 0),
					VERMILION,
					Enum.Material.Wood,
					"Rail"
				)
			)
			quiet(
				Build.part(
					model,
					Vector3.new(0.4, 2.4, 0.4),
					frame * CFrame.new(s * (width / 2 - 0.2), 1.2, 0),
					VERMILION,
					Enum.Material.Wood,
					"Baluster"
				)
			)
		end
	end
	model.Parent = parent
	return model
end

-- Estandarte vertical da divisão (pano branco com o número em kanji)
function Seireitei.banner(parent: Instance, cf: CFrame, text: string)
	local pole =
		Build.part(parent, Vector3.new(0.4, 16, 0.4), cf * CFrame.new(0, 8, 0), WOOD, Enum.Material.Wood, "BannerPole")
	quiet(pole)
	local cloth = Build.part(
		parent,
		Vector3.new(3, 10, 0.12),
		cf * CFrame.new(1.7, 10, 0),
		Color3.fromRGB(248, 246, 240),
		Enum.Material.Fabric,
		"Banner"
	)
	quiet(cloth)
	sign(cloth, text, Color3.fromRGB(20, 18, 22), true)
	quiet(
		Build.part(
			parent,
			Vector3.new(3.4, 0.25, 0.25),
			cf * CFrame.new(1.7, 15.1, 0),
			WOOD,
			Enum.Material.Wood,
			"BannerBar"
		)
	)
end

return Seireitei

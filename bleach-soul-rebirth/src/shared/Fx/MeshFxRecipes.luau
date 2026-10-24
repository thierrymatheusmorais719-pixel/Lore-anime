-- Receitas dos efeitos de malha (puras: só dados e matemática, sem instâncias). Cada receita
-- devolve camadas; o cliente (MeshFx) monta as peças e as anima com `MeshFxRecipes.Evaluate`.
-- A prévia (tools/preview/meshfx.py) usa as mesmas funções para desenhar os quadros congelados.
--
-- Princípios (guia de VFX da skill): camada preta atrás de cada forma clara (leitura em qualquer
-- fundo), núcleo branco/quase branco por cima da cor, pico curto (0,03–0,1 s) e queda longa,
-- formas que não se repetem (estrelas com seeds diferentes), escala pelo peso do golpe.
--
-- Camada:
--   shape    nome em MeshShapes.Library ou forma pronta { v, t } (corte pelo caminho da lâmina)
--   size     escala uniforme da forma (as da biblioteca têm raio 1)
--   frame    CFrame base no mundo; billboard = a face (+Y) vira para a câmera
--   roll     giro inicial em volta do Y local; spin = rad/s em volta do Y local
--   t0, life início e duração (s); scale/alpha = chaves {{u, valor}} com u = 0..1 da vida
--            (scale pode ser número ou Vector3 por eixo)
--   velocity, drag, gravity  movimento (estilhaços)
--   color, neon (false = fosco, para as camadas pretas), z = avanço para a câmera (ordem)
local MeshFxRecipes = {}

local BLACK = Color3.new(0, 0, 0)

export type Layer = { [string]: any }
export type Palette = { core: Color3, primary: Color3, secondary: Color3, dark: Color3 }

local function key(keys: { { any } }, u: number): any
	if u <= keys[1][1] then
		return keys[1][2]
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if u <= b[1] then
			local f = (u - a[1]) / math.max(1e-6, b[1] - a[1])
			f = f * f * (3 - 2 * f)
			return a[2] + (b[2] - a[2]) * f
		end
	end
	return keys[#keys][2]
end
MeshFxRecipes.key = key

-- Estado da camada no tempo `t` (s desde o início do efeito): CFrame, escala (Vector3), alfa.
-- Devolve nil fora da vida da camada.
function MeshFxRecipes.Evaluate(layer: Layer, t: number, cameraPosition: Vector3): (CFrame?, Vector3?, number?)
	local age = t - (layer.t0 or 0)
	if age < 0 or age > layer.life then
		return nil, nil, nil
	end
	local u = age / layer.life
	local frame: CFrame = layer.frame
	if layer.velocity then
		local drag = layer.drag or 0
		local travel = if drag > 0 then (1 - math.exp(-drag * age)) / drag else age
		local g = layer.gravity or 0
		frame = frame + layer.velocity * travel - Vector3.new(0, 0.5 * g * age * age, 0)
	end
	local position = frame.Position
	local rotation: CFrame
	if layer.billboard then
		local toCamera = cameraPosition - position
		if toCamera.Magnitude < 1e-3 then
			toCamera = Vector3.zAxis
		end
		-- +Y da forma para a câmera
		rotation = CFrame.lookAt(Vector3.zero, toCamera) * CFrame.Angles(-math.pi / 2, 0, 0)
		position += toCamera.Unit * (layer.z or 0)
	else
		rotation = frame.Rotation
	end
	local roll = (layer.roll or 0) + (layer.spin or 0) * age
	rotation *= CFrame.Angles(0, roll, 0)
	local s = if layer.scale then key(layer.scale, u) else 1
	local size = layer.size or 1
	local scale = if typeof(s) == "Vector3" then s * size else Vector3.new(s, s, s) * size
	local alpha = if layer.alpha then key(layer.alpha, u) else 0
	return CFrame.new(position) * rotation, scale, alpha
end

-- Duração total das camadas
function MeshFxRecipes.Length(layers: { Layer }): number
	local total = 0
	for _, l in layers do
		total = math.max(total, (l.t0 or 0) + l.life)
	end
	return total
end

local function rngFor(seed: number?): Random
	return if seed then Random.new(seed) else Random.new()
end

-- ======================================================================= IMPACTO
-- Estrela tripla (preta grande atrás, cor, núcleo branco) que estoura e some em ~0,12 s, anel que
-- abre, e nos golpes pesados bola de espinhos + estilhaços voando na direção do golpe.
function MeshFxRecipes.Impact(
	position: Vector3,
	direction: Vector3?,
	palette: Palette,
	tier: number,
	seed: number?
): { Layer }
	local rng = rngFor(seed)
	local s = if tier >= 3 then 2.6 elseif tier == 2 then 1.7 else 1
	local base = CFrame.new(position)
	local layers: { Layer } = {}
	local stars = { "StarA", "StarB", "StarC" }
	local pick = rng:NextInteger(1, 3)
	local function star(name: string, size: number, color: Color3, neon: boolean, z: number, t0: number, life: number)
		table.insert(layers, {
			shape = name,
			size = size * s,
			frame = base,
			billboard = true,
			roll = rng:NextNumber(0, math.pi * 2),
			t0 = t0,
			life = life,
			scale = { { 0, 0.35 }, { 0.3, 1 }, { 1, 1.12 } },
			alpha = { { 0, 0 }, { 0.6, 0 }, { 1, 1 } },
			color = color,
			neon = neon,
			z = z,
		})
	end
	star(stars[pick], 1.9, BLACK, false, -0.15, 0.015, 0.13)
	star(stars[pick % 3 + 1], 1.45, palette.primary, true, 0, 0, 0.11)
	star(stars[(pick + 1) % 3 + 1], 0.85, palette.core, true, 0.15, 0, 0.08)
	-- anel virado para a câmera
	table.insert(layers, {
		shape = "RingThin",
		size = 1.2 * s,
		frame = base,
		billboard = true,
		t0 = 0.02,
		life = 0.26,
		scale = { { 0, 0.4 }, { 1, 2.4 } },
		alpha = { { 0, 0.1 }, { 1, 1 } },
		color = palette.secondary,
		neon = true,
		z = 0.05,
	})
	if tier >= 2 then
		table.insert(layers, {
			shape = "SpikeBall",
			size = 2.2 * s,
			frame = base * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			t0 = 0.01,
			life = 0.16,
			scale = { { 0, 0.3 }, { 0.35, 1 }, { 1, 1.15 } },
			alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
			color = palette.core,
			neon = true,
		})
		local dir = if direction and direction.Magnitude > 0.01 then direction.Unit else Vector3.yAxis
		local count = if tier >= 3 then 8 else 4
		for _ = 1, count do
			local spread = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 1), rng:NextNumber(-1, 1))
			local v = (dir * 1.2 + spread).Unit * rng:NextNumber(30, 55) * (0.6 + s * 0.3)
			table.insert(layers, {
				shape = "Shard",
				size = rng:NextNumber(0.5, 1.1) * s,
				frame = CFrame.lookAt(position, position + v) * CFrame.Angles(-math.pi / 2, 0, 0),
				velocity = v,
				drag = 7,
				gravity = 18,
				spin = rng:NextNumber(-12, 12),
				t0 = 0.02,
				life = rng:NextNumber(0.3, 0.5),
				scale = { { 0, 1 }, { 1, 0.2 } },
				alpha = { { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } },
				color = if rng:NextNumber() < 0.5 then palette.core else palette.primary,
				neon = true,
			})
		end
	end
	return layers
end

-- ======================================================================= CORTE
-- Meia-lua sólida no caminho da lâmina: três fitas (preta mais larga atrás, cor, núcleo branco
-- fino na borda de fora), que "esticam" um pouco para fora e somem afinando.
-- points = ponta da lâmina (mundo), pivot = centro do movimento (ombro/peito).
function MeshFxRecipes.Slash(
	points: { Vector3 },
	pivot: Vector3,
	palette: Palette,
	width: number,
	duration: number,
	makeStrip: (outer: { Vector3 }, inner: { Vector3 }) -> any
): { Layer }
	local n = #points
	local layers: { Layer } = {}
	if n < 3 then
		return layers
	end
	-- plano do corte: normal pelo produto de dois raios do pivô
	local a, b = points[1] - pivot, points[n] - pivot
	local normal = a:Cross(b)
	if normal.Magnitude < 1e-4 then
		normal = a:Cross(points[n // 2 + 1] - pivot)
	end
	normal = if normal.Magnitude > 1e-4 then normal.Unit else Vector3.yAxis
	local frame = CFrame.new(pivot) -- as fitas ficam no espaço do pivô: a escala estica para fora
	-- shift: desloca a borda de fora (em larguras do corte; negativo = para dentro)
	local function band(widthScale: number, shift: number, lift: number)
		local outer, inner = {}, {}
		for i, p in points do
			local u = (i - 1) / (n - 1)
			local radial = p - pivot
			local dist = radial.Magnitude
			local dirR = if dist > 1e-4 then radial / dist else Vector3.yAxis
			local profile = math.sin(math.pi * u) ^ 0.6
			local w = width * widthScale * profile + 0.02
			local out = dist + width * shift * profile
			outer[i] = dirR * out + normal * lift
			inner[i] = dirR * math.max(out - w, dist * 0.35) + normal * lift
		end
		return makeStrip(outer, inner)
	end
	local stretch =
		{ { 0, Vector3.new(0.92, 0.92, 0.92) }, { 0.25, Vector3.one }, { 1, Vector3.new(1.08, 1.08, 1.08) } }
	table.insert(layers, {
		-- sombra preta na borda de dentro (atrás da cor): dá peso e leitura em fundo claro
		shape = band(0.85, -0.5, -0.06),
		frame = frame,
		t0 = 0,
		life = duration * 1.1,
		scale = stretch,
		alpha = { { 0, 0.25 }, { 0.3, 0.3 }, { 1, 1 } },
		color = BLACK,
		neon = false,
	})
	table.insert(layers, {
		shape = band(1, 0, 0),
		frame = frame,
		t0 = 0,
		life = duration,
		scale = stretch,
		alpha = { { 0, 0 }, { 0.35, 0.05 }, { 1, 1 } },
		color = palette.primary,
		neon = true,
	})
	-- rastros: duas cópias atrasadas, giradas um pouco para trás no plano do corte (borrão de
	-- movimento de anime)
	for k = 1, 2 do
		table.insert(layers, {
			shape = band(0.8 - k * 0.15, -0.1 * k, -0.02 * k),
			frame = CFrame.new(pivot) * CFrame.fromAxisAngle(normal, -0.14 * k),
			t0 = 0.025 * k,
			life = duration * (0.8 - k * 0.15),
			scale = stretch,
			alpha = { { 0, 0.45 + k * 0.15 }, { 1, 1 } },
			color = palette.secondary,
			neon = true,
		})
	end
	table.insert(layers, {
		shape = band(0.3, 0.04, 0.04),
		frame = frame,
		t0 = 0,
		life = duration * 0.75,
		scale = stretch,
		alpha = { { 0, 0 }, { 0.4, 0 }, { 1, 1 } },
		color = palette.core,
		neon = true,
	})
	return layers
end

-- ======================================================================= ASSINATURA POR ELEMENTO
-- Forma própria de cada poder por cima do impacto (golpes pesados, liberações):
--   Fogo/Sangue: línguas de fogo (coroas altas e finas) + brasas subindo
--   Gelo/Areia/Verdant: cristais/espinhos/espinheiros rompendo o chão em anel
--   Raio: raios ramificados em zigue-zague que piscam
--   Sagrado/Ouro: estrela de quatro pontas gigante + raios finos
--   Hollow/Sombra: bola de espinhos preta + anel vermelho escuro + garras em meia-lua
--   Lua: lua crescente enorme virada para a câmera; Reiatsu: meias-luas em X
--   Corrente: elos girando em volta; Tempo: mostrador com ponteiros girando
local function jagged(rng: Random, from: Vector3, to: Vector3, steps: number, amplitude: number): { Vector3 }
	local pts = { from }
	local dir = to - from
	local side = dir:Cross(Vector3.yAxis)
	if side.Magnitude < 1e-3 then
		side = Vector3.xAxis
	end
	side = side.Unit
	local up = dir.Unit:Cross(side)
	for i = 1, steps - 1 do
		local u = i / steps
		local off = side * rng:NextNumber(-amplitude, amplitude) + up * rng:NextNumber(-amplitude, amplitude)
		table.insert(pts, from + dir * u + off * math.sin(math.pi * u))
	end
	table.insert(pts, to)
	return pts
end

-- Fita fina ao longo de uma polilinha, virada para `facing` (formas dinâmicas: raio, rachadura)
local function ribbonAlong(points: { Vector3 }, width: number, facing: Vector3, makeStrip: any, taper: boolean?)
	local outer, inner = {}, {}
	for i, p in points do
		local a = points[math.max(1, i - 1)]
		local b = points[math.min(#points, i + 1)]
		local tangent = (b - a)
		tangent = if tangent.Magnitude > 1e-4 then tangent.Unit else Vector3.xAxis
		local side = tangent:Cross(facing)
		side = if side.Magnitude > 1e-4 then side.Unit else Vector3.zAxis
		local w = width * (if taper then 1 - (i - 1) / (#points - 1) * 0.85 else 1)
		outer[i] = p + side * w / 2
		inner[i] = p - side * w / 2
	end
	return makeStrip(outer, inner)
end

function MeshFxRecipes.Element(
	position: Vector3,
	direction: Vector3?,
	element: string,
	palette: Palette,
	scale: number,
	makeStrip: any,
	seed: number?
): { Layer }
	local rng = rngFor(seed)
	local s = scale
	local ground = position - Vector3.new(0, 2.5 * math.max(1, s * 0.7), 0)
	local layers: { Layer } = {}
	local function add(l: Layer)
		table.insert(layers, l)
	end
	if element == "Fire" or element == "Blood" then
		for i, h in { 1, 0.7 } do
			add({
				shape = "Crown",
				size = 1,
				frame = CFrame.new(ground),
				roll = rng:NextNumber(0, 6),
				spin = 2 * (if i == 1 then 1 else -1),
				t0 = 0.01 * i,
				life = 0.45,
				scale = {
					{ 0, Vector3.new(1.2 * s, 0.2, 1.2 * s) },
					{ 0.3, Vector3.new(1.6 * s, 4.2 * s * h, 1.6 * s) },
					{ 1, Vector3.new(1.9 * s, 0.4, 1.9 * s) },
				},
				alpha = { { 0, 0 }, { 0.55, 0.15 }, { 1, 1 } },
				color = if i == 1 then palette.primary else palette.core,
				neon = true,
			})
		end
		for _ = 1, 6 do
			local v = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(18, 34), rng:NextNumber(-8, 8))
				* (0.6 + s * 0.3)
			add({
				shape = "Shard",
				size = 0.45 * s,
				frame = CFrame.new(position),
				velocity = v,
				drag = 3,
				gravity = -6,
				spin = rng:NextNumber(-8, 8),
				life = rng:NextNumber(0.4, 0.7),
				scale = { { 0, 1 }, { 1, 0.1 } },
				alpha = { { 0, 0 }, { 1, 1 } },
				color = palette.secondary,
				neon = true,
			})
		end
	elseif element == "Ice" or element == "Sand" or element == "Verdant" then
		local count = 9
		for i = 1, count do
			local a = i / count * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local r = rng:NextNumber(1.2, 2.4) * s
			local base = ground + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local tilt = CFrame.Angles(math.sin(a) * 0.5, 0, -math.cos(a) * 0.5)
			local len = rng:NextNumber(2.2, 4) * s * (if element == "Sand" then 0.6 else 1)
			add({
				shape = "Shard",
				size = 1,
				frame = CFrame.new(base) * tilt,
				t0 = rng:NextNumber(0, 0.06),
				life = 0.75,
				scale = {
					{ 0, Vector3.new(0.6 * s, 0.05, 0.6 * s) },
					{ 0.12, Vector3.new(1.2 * s, len, 1.2 * s) },
					{ 0.8, Vector3.new(1.2 * s, len, 1.2 * s) },
					{ 1, Vector3.new(0.3 * s, len * 0.3, 0.3 * s) },
				},
				alpha = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } },
				color = if i % 3 == 0 then palette.core else palette.primary,
				neon = element ~= "Sand",
			})
		end
	elseif element == "Lightning" then
		for b = 1, 4 do
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 1), rng:NextNumber(-1, 1))
			dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.yAxis
			local pts = jagged(rng, Vector3.zero, dir * rng:NextNumber(4, 7) * s, 7, 0.9 * s)
			local facing = dir:Cross(Vector3.new(0.3, 1, 0.2)).Unit
			for layer = 1, 2 do
				add({
					shape = ribbonAlong(pts, (if layer == 1 then 0.5 else 0.18) * s, facing, makeStrip, true),
					frame = CFrame.new(position),
					t0 = (b - 1) * 0.02,
					life = 0.22,
					-- pisca: some e volta duas vezes
					alpha = {
						{ 0, 0 },
						{ 0.25, 0.1 },
						{ 0.35, 0.9 },
						{ 0.45, 0.05 },
						{ 0.6, 0.85 },
						{ 0.7, 0.2 },
						{ 1, 1 },
					},
					color = if layer == 1 then palette.primary else palette.core,
					neon = true,
				})
			end
		end
	elseif element == "Holy" or element == "Gold" then
		add({
			shape = "StarCross",
			size = 3.4 * s,
			frame = CFrame.new(position),
			billboard = true,
			roll = math.rad(45) * (if rng:NextNumber() < 0.5 then 1 else 0),
			life = 0.35,
			scale = { { 0, 0.2 }, { 0.15, 1.1 }, { 1, 0.6 } },
			alpha = { { 0, 0 }, { 0.5, 0.2 }, { 1, 1 } },
			color = palette.core,
			neon = true,
			z = 0.3,
		})
		add({
			shape = "StarRays",
			size = 5 * s,
			frame = CFrame.new(position),
			billboard = true,
			roll = rng:NextNumber(0, 6),
			spin = 1.5,
			life = 0.5,
			scale = { { 0, 0.5 }, { 1, 1.2 } },
			alpha = { { 0, 0.2 }, { 1, 1 } },
			color = palette.primary,
			neon = true,
		})
	elseif element == "Hollow" or element == "Shadow" then
		add({
			shape = "SpikeBall",
			size = 3.2 * s,
			frame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			life = 0.3,
			scale = { { 0, 0.3 }, { 0.3, 1 }, { 1, 1.1 } },
			alpha = { { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } },
			color = Color3.new(0.02, 0.01, 0.02),
			neon = false,
		})
		add({
			shape = "Ring",
			size = 2.2 * s,
			frame = CFrame.new(position),
			billboard = true,
			life = 0.35,
			scale = { { 0, 0.3 }, { 1, 2 } },
			alpha = { { 0, 0 }, { 1, 1 } },
			color = palette.primary,
			neon = true,
			z = 0.2,
		})
		for k = -1, 1, 2 do
			add({
				shape = "Crescent",
				size = 2.6 * s,
				frame = CFrame.new(position) * CFrame.Angles(math.rad(80), math.rad(25 * k), math.rad(30 * k)),
				life = 0.25,
				scale = { { 0, 0.6 }, { 1, 1.2 } },
				alpha = { { 0, 0 }, { 1, 1 } },
				color = palette.secondary,
				neon = true,
			})
		end
	elseif element == "Moon" then
		add({
			shape = "Crescent",
			size = 4.5 * s,
			frame = CFrame.new(position),
			billboard = true,
			roll = rng:NextNumber(0, 6),
			life = 0.5,
			scale = { { 0, 0.4 }, { 0.2, 1 }, { 1, 1.15 } },
			alpha = { { 0, 0 }, { 0.6, 0.15 }, { 1, 1 } },
			color = palette.core,
			neon = true,
		})
	elseif element == "Chain" then
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			add({
				shape = "RingThin",
				size = 0.5 * s,
				frame = CFrame.new(position + Vector3.new(math.cos(a), 0.2 * math.sin(a * 2), math.sin(a)) * 2.6 * s)
					* CFrame.Angles(math.rad(90), a, 0),
				spin = 4,
				life = 0.45,
				scale = {
					{ 0, Vector3.new(0.4, 1, 1) },
					{ 0.3, Vector3.new(1, 1, 1.8) },
					{ 1, Vector3.new(1.3, 1, 2.2) },
				},
				alpha = { { 0, 0 }, { 0.6, 0.1 }, { 1, 1 } },
				color = palette.primary,
				neon = true,
			})
		end
	elseif element == "Time" then
		add({
			shape = "Ring",
			size = 3 * s,
			frame = CFrame.new(position),
			billboard = true,
			life = 0.6,
			scale = { { 0, 0.5 }, { 0.2, 1 }, { 1, 1.05 } },
			alpha = { { 0, 0 }, { 0.7, 0.15 }, { 1, 1 } },
			color = palette.primary,
			neon = true,
		})
		for k, len in { 2.4, 1.6 } do
			add({
				shape = ribbonAlong(
					{ Vector3.zero, Vector3.new(len * s, 0, 0) },
					0.22 * s,
					Vector3.yAxis,
					makeStrip,
					true
				),
				frame = CFrame.new(position),
				billboard = true,
				spin = if k == 1 then 9 else 1.5,
				life = 0.6,
				alpha = { { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } },
				color = palette.core,
				neon = true,
				z = 0.25,
			})
		end
	else
		-- Reiatsu (padrão): duas meias-luas cruzadas em X
		for k = -1, 1, 2 do
			add({
				shape = "Crescent",
				size = 3.2 * s,
				frame = CFrame.new(position),
				billboard = true,
				roll = math.rad(45 * k),
				life = 0.3,
				scale = { { 0, 0.5 }, { 0.25, 1 }, { 1, 1.2 } },
				alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
				color = if k < 0 then palette.primary else palette.core,
				neon = true,
				z = 0.1 * k,
			})
		end
	end
	return layers
end

-- ======================================================================= RACHADURAS NO CHÃO
-- Golpes finalizadores: rachaduras pretas radiais com fio aceso por dentro, que ficam ~1,5 s
function MeshFxRecipes.Cracks(
	position: Vector3,
	palette: Palette,
	radius: number,
	makeStrip: any,
	seed: number?
): { Layer }
	local rng = rngFor(seed)
	local layers: { Layer } = {}
	local center = position + Vector3.new(0, 0.06, 0)
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local tip = Vector3.new(math.cos(a), 0, math.sin(a)) * radius * rng:NextNumber(0.6, 1)
		local pts = jagged(rng, Vector3.zero, tip, 6, radius * 0.08)
		for k, p in pts do
			pts[k] = Vector3.new(p.X, 0, p.Z)
		end
		for layer = 1, 2 do
			table.insert(layers, {
				shape = ribbonAlong(pts, if layer == 1 then 0.5 else 0.14, Vector3.yAxis, makeStrip, true),
				frame = CFrame.new(center + Vector3.new(0, layer * 0.02, 0)),
				t0 = 0.02 * i / 7,
				life = 1.6,
				scale = { { 0, Vector3.new(0.2, 1, 0.2) }, { 0.08, Vector3.one }, { 1, Vector3.one } },
				alpha = { { 0, 0 }, { 0.75, if layer == 1 then 0.1 else 0.3 }, { 1, 1 } },
				color = if layer == 1 then Color3.new(0.03, 0.03, 0.03) else palette.primary,
				neon = layer == 2,
			})
		end
	end
	return layers
end

-- ======================================================================= ONDA DE CHOQUE
-- Anel no chão que abre + anel fino branco por dentro + coroa de espinhos que rompe e afunda
function MeshFxRecipes.Shockwave(position: Vector3, palette: Palette, radius: number, duration: number): { Layer }
	local base = CFrame.new(position + Vector3.new(0, 0.05, 0))
	return {
		{
			shape = "Ring",
			size = radius,
			frame = base,
			life = duration,
			scale = { { 0, 0.15 }, { 0.4, 0.75 }, { 1, 1 } },
			alpha = { { 0, 0 }, { 0.5, 0.3 }, { 1, 1 } },
			color = palette.primary,
			neon = true,
		},
		{
			shape = "RingThin",
			size = radius * 0.95,
			frame = base + Vector3.new(0, 0.03, 0),
			life = duration * 0.7,
			scale = { { 0, 0.1 }, { 1, 0.85 } },
			alpha = { { 0, 0 }, { 1, 1 } },
			color = palette.core,
			neon = true,
		},
		{
			shape = "Crown",
			size = 1,
			frame = base,
			roll = math.random() * 6,
			t0 = 0.02,
			life = duration * 1.3,
			scale = {
				{ 0, Vector3.new(radius * 0.25, 0.1, radius * 0.25) },
				{ 0.25, Vector3.new(radius * 0.45, radius * 0.35, radius * 0.45) },
				{ 1, Vector3.new(radius * 0.6, 0.05, radius * 0.6) },
			},
			alpha = { { 0, 0 }, { 0.6, 0.15 }, { 1, 1 } },
			color = palette.secondary,
			neon = true,
		},
		{
			shape = "Crown",
			size = 1,
			frame = base,
			roll = math.random() * 6,
			t0 = 0.04,
			life = duration * 1.3,
			scale = {
				{ 0, Vector3.new(radius * 0.25, 0.1, radius * 0.25) },
				{ 0.25, Vector3.new(radius * 0.48, radius * 0.45, radius * 0.48) },
				{ 1, Vector3.new(radius * 0.62, 0.05, radius * 0.62) },
			},
			alpha = { { 0, 0.1 }, { 0.6, 0.3 }, { 1, 1 } },
			color = BLACK,
			neon = false,
		},
	}
end

-- ======================================================================= ESTOURO (liberação, explosão)
function MeshFxRecipes.Burst(position: Vector3, palette: Palette, scale: number, seed: number?): { Layer }
	local layers = MeshFxRecipes.Impact(position, Vector3.yAxis, palette, 3, seed)
	for _, l in layers do
		l.size = (l.size or 1) * scale * 0.6
	end
	for _, l in MeshFxRecipes.Shockwave(position - Vector3.new(0, 2.5, 0), palette, 9 * scale, 0.55) do
		table.insert(layers, l)
	end
	table.insert(layers, {
		shape = "Spiral",
		size = 1,
		frame = CFrame.new(position - Vector3.new(0, 2.5, 0)),
		spin = 9,
		t0 = 0,
		life = 0.6,
		scale = {
			{ 0, Vector3.new(2 * scale, 0.5 * scale, 2 * scale) },
			{ 0.4, Vector3.new(3 * scale, 9 * scale, 3 * scale) },
			{ 1, Vector3.new(4 * scale, 12 * scale, 4 * scale) },
		},
		alpha = { { 0, 0 }, { 0.5, 0.15 }, { 1, 1 } },
		color = palette.primary,
		neon = true,
	})
	return layers
end

-- ======================================================================= CARGA
-- Duas espirais em sentidos opostos que apertam em volta do ponto + anel que implode no fim
function MeshFxRecipes.Charge(frame: CFrame, palette: Palette, duration: number, big: boolean): { Layer }
	local r = if big then 3.2 else 2
	local layers: { Layer } = {}
	for i, dir in { 1, -1 } do
		table.insert(layers, {
			shape = "Spiral",
			size = 1,
			frame = frame * CFrame.new(0, -r * 0.6, 0),
			roll = i * 2,
			spin = 7 * dir,
			life = duration,
			scale = {
				{ 0, Vector3.new(r * 1.4, r * 1.6, r * 1.4) },
				{ 1, Vector3.new(r * 0.25, r * 1.2, r * 0.25) },
			},
			alpha = { { 0, 1 }, { 0.2, 0.35 }, { 0.85, 0.1 }, { 1, 1 } },
			color = if i == 1 then palette.primary else palette.secondary,
			neon = true,
		})
	end
	table.insert(layers, {
		shape = "RingThin",
		size = r * 1.5,
		frame = frame,
		billboard = true,
		t0 = math.max(0, duration - 0.25),
		life = 0.25,
		scale = { { 0, 1 }, { 1, 0.05 } },
		alpha = { { 0, 0.6 }, { 0.3, 0 }, { 1, 0.2 } },
		color = palette.core,
		neon = true,
	})
	return layers
end

-- ======================================================================= PILAR
function MeshFxRecipes.Pillar(
	position: Vector3,
	palette: Palette,
	radius: number,
	height: number,
	duration: number
): { Layer }
	local layers: { Layer } = {}
	for i, dir in { 1, -1 } do
		table.insert(layers, {
			shape = "Spiral",
			size = 1,
			frame = CFrame.new(position),
			roll = i * 1.7,
			spin = 6 * dir,
			life = duration,
			scale = {
				{ 0, Vector3.new(radius * 1.6, height * 0.1, radius * 1.6) },
				{ 0.2, Vector3.new(radius * 1.2, height * 0.8, radius * 1.2) },
				{ 1, Vector3.new(radius * 0.5, height, radius * 0.5) },
			},
			alpha = { { 0, 0.3 }, { 0.2, 0.1 }, { 1, 1 } },
			color = if i == 1 then palette.core else palette.primary,
			neon = true,
		})
	end
	for _, l in MeshFxRecipes.Shockwave(position, palette, radius * 3, math.min(0.8, duration)) do
		table.insert(layers, l)
	end
	return layers
end

return MeshFxRecipes

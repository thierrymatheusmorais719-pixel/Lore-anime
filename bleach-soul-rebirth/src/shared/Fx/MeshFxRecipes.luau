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

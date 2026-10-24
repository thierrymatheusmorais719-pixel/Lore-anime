-- Formas de efeito geradas por código (geometria pura: vértices + triângulos), desenhadas pelo
-- cliente como malha (EditableMesh) ou, sem essa API, com pares de cunhas (MeshFx).
-- Convenções: formas planas ficam no plano XZ (normal +Y); a meia-lua abre em volta de -Z, como
-- VFX.SlashArc; todas centradas na origem da forma (anel/meia-lua: centro do círculo).
-- Retorno: { v = { Vector3 }, t = { {a, b, c} } } com índices a partir de 1.
local MeshShapes = {}

export type Shape = { v: { Vector3 }, t: { { number } } }

local function shape(): Shape
	return { v = {}, t = {} }
end

local function add(s: Shape, p: Vector3): number
	table.insert(s.v, p)
	return #s.v
end

-- Anel plano (onda de choque, halo)
function MeshShapes.ring(segments: number, inner: number, outer: number): Shape
	local s = shape()
	local ins, outs = {}, {}
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local c, n = math.cos(a), math.sin(a)
		ins[i] = add(s, Vector3.new(c * inner, 0, n * inner))
		outs[i] = add(s, Vector3.new(c * outer, 0, n * outer))
	end
	for i = 0, segments - 1 do
		local j = (i + 1) % segments
		table.insert(s.t, { ins[i], outs[i], outs[j] })
		table.insert(s.t, { ins[i], outs[j], ins[j] })
	end
	return s
end

-- Meia-lua: arco de `span` radianos em volta de -Z, espessa no meio e afiada nas pontas.
-- bow: levanta o meio do arco em Y (a lâmina de energia "curva" no ar, não é um disco chapado)
function MeshShapes.crescent(segments: number, span: number, inner: number, outer: number, bow: number?): Shape
	local s = shape()
	local top, bottom = {}, {}
	for i = 0, segments do
		local u = i / segments
		local a = -span / 2 + span * u
		local taper = math.sin(math.pi * u) ^ 0.65
		local rOut = outer
		local rIn = outer - (outer - inner) * taper
		local y = (bow or 0) * math.sin(math.pi * u)
		top[i] = add(s, Vector3.new(-math.sin(a) * rOut, y, -math.cos(a) * rOut))
		bottom[i] = add(s, Vector3.new(-math.sin(a) * rIn, y * 0.6, -math.cos(a) * rIn))
	end
	for i = 0, segments - 1 do
		table.insert(s.t, { bottom[i], top[i], top[i + 1] })
		table.insert(s.t, { bottom[i], top[i + 1], bottom[i + 1] })
	end
	return s
end

-- Estrela de impacto (anime): pontas de comprimento irregular em volta do centro. `seed` fixa o
-- desenho (cada camada do mesmo golpe usa um seed diferente → silhuetas que não coincidem)
function MeshShapes.star(spikes: number, inner: number, outer: number, seed: number?): Shape
	local s = shape()
	local rng = Random.new(seed or 7)
	local center = add(s, Vector3.zero)
	local ring = {}
	local count = spikes * 2
	local offset = rng:NextNumber(0, math.pi * 2)
	for i = 0, count - 1 do
		local a = offset + i / count * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local r = if i % 2 == 0 then outer * rng:NextNumber(0.55, 1) else inner * rng:NextNumber(0.8, 1.1)
		ring[i] = add(s, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
	end
	for i = 0, count - 1 do
		table.insert(s.t, { center, ring[i], ring[(i + 1) % count] })
	end
	return s
end

-- Coroa: espinhos em pé em volta de um círculo, inclinados para fora (onda que rompe o chão)
function MeshShapes.crown(spikes: number, radius: number, height: number, lean: number?, seed: number?): Shape
	local s = shape()
	local rng = Random.new(seed or 3)
	local half = math.pi / spikes * 0.8
	for i = 0, spikes - 1 do
		local a = i / spikes * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local h = height * rng:NextNumber(0.55, 1)
		local out = (lean or 0.3) * h
		local p1 = add(s, Vector3.new(math.cos(a - half) * radius, 0, math.sin(a - half) * radius))
		local p2 = add(s, Vector3.new(math.cos(a + half) * radius, 0, math.sin(a + half) * radius))
		local tip = add(s, Vector3.new(math.cos(a) * (radius + out), h, math.sin(a) * (radius + out)))
		-- duas faces (frente e uma aresta para trás) dão volume ao espinho
		local back = add(s, Vector3.new(math.cos(a) * (radius - h * 0.12), 0, math.sin(a) * (radius - h * 0.12)))
		table.insert(s.t, { p1, p2, tip })
		table.insert(s.t, { p1, tip, back })
		table.insert(s.t, { back, tip, p2 })
	end
	return s
end

-- Espiral: fita em hélice subindo (carga, pilar, redemoinho). Afina nas pontas.
function MeshShapes.spiral(turns: number, segments: number, radius: number, height: number, width: number): Shape
	local s = shape()
	local up, down = {}, {}
	for i = 0, segments do
		local u = i / segments
		local a = turns * math.pi * 2 * u
		local r = radius * (1 - 0.25 * u)
		local w = width * math.sin(math.pi * u) ^ 0.5
		local c = Vector3.new(math.cos(a) * r, height * u, math.sin(a) * r)
		up[i] = add(s, c + Vector3.new(0, w / 2, 0))
		down[i] = add(s, c - Vector3.new(0, w / 2, 0))
	end
	for i = 0, segments - 1 do
		table.insert(s.t, { down[i], up[i], up[i + 1] })
		table.insert(s.t, { down[i], up[i + 1], down[i + 1] })
	end
	return s
end

-- Estilhaço: cristal alongado em Y (octaedro esticado, losango em corte)
function MeshShapes.shard(length: number, width: number): Shape
	local s = shape()
	local top = add(s, Vector3.new(0, length * 0.5, 0))
	local bottom = add(s, Vector3.new(0, -length * 0.5, 0))
	local mid = {}
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		mid[i] = add(
			s,
			Vector3.new(
				math.cos(a) * width * (if i % 2 == 0 then 0.5 else 0.3),
				length * 0.1,
				math.sin(a) * width * 0.4
			)
		)
	end
	for i = 0, 3 do
		local j = (i + 1) % 4
		table.insert(s.t, { top, mid[i], mid[j] })
		table.insert(s.t, { bottom, mid[j], mid[i] })
	end
	return s
end

-- Bola de espinhos: pontas finas saindo do centro em várias direções (estouro pesado)
function MeshShapes.spikeBall(spikes: number, length: number, width: number, seed: number?): Shape
	local s = shape()
	local rng = Random.new(seed or 11)
	for _ = 1, spikes do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		if dir.Magnitude < 0.1 then
			dir = Vector3.yAxis
		end
		dir = dir.Unit
		local side = dir:Cross(if math.abs(dir.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis).Unit
		local l = length * rng:NextNumber(0.5, 1)
		local tip = add(s, dir * l)
		local a = add(s, side * width)
		local b = add(s, -side * width)
		local c = add(s, dir:Cross(side).Unit * width)
		table.insert(s.t, { a, b, tip })
		table.insert(s.t, { b, c, tip })
		table.insert(s.t, { c, a, tip })
	end
	return s
end

-- Fita entre duas curvas (corte que segue o caminho da lâmina): pontos `outerPoints` e
-- `innerPoints` com o mesmo número de pontos, já no espaço da forma
function MeshShapes.strip(outerPoints: { Vector3 }, innerPoints: { Vector3 }): Shape
	local s = shape()
	local outs, ins = {}, {}
	for i, p in outerPoints do
		outs[i] = add(s, p)
		ins[i] = add(s, innerPoints[i])
	end
	for i = 1, #outerPoints - 1 do
		table.insert(s.t, { ins[i], outs[i], outs[i + 1] })
		table.insert(s.t, { ins[i], outs[i + 1], ins[i + 1] })
	end
	return s
end

-- Formas fixas usadas pelas receitas (pré-montadas uma vez no cliente)
MeshShapes.Library = {
	Ring = function()
		return MeshShapes.ring(40, 0.82, 1)
	end,
	RingThin = function()
		return MeshShapes.ring(40, 0.94, 1)
	end,
	Crescent = function()
		return MeshShapes.crescent(24, math.rad(160), 0.62, 1, 0.08)
	end,
	StarA = function()
		return MeshShapes.star(8, 0.28, 1, 101)
	end,
	StarB = function()
		return MeshShapes.star(11, 0.3, 1, 202)
	end,
	StarC = function()
		return MeshShapes.star(6, 0.35, 1, 303)
	end,
	Crown = function()
		return MeshShapes.crown(14, 1, 1, 0.45, 5)
	end,
	Spiral = function()
		return MeshShapes.spiral(2.2, 60, 1, 1, 0.22)
	end,
	Shard = function()
		return MeshShapes.shard(1, 0.35)
	end,
	SpikeBall = function()
		return MeshShapes.spikeBall(16, 1, 0.07, 9)
	end,
}

return MeshShapes

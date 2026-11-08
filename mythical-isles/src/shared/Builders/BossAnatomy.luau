-- Plantas anatômicas dos 5 bosses (mesmo formato das plantas dos pets — PetAnatomy — e montadas pelo
-- mesmo construtor do PetMesh): superfícies contínuas (lofts) com relevo por ruído (casca, rocha),
-- cor por vértice (musgo nas faces de cima, sulcos, escamas, ventre), cristais facetados, membranas
-- de asa, armaduras com friso dourado. Baseadas na arte conceitual do autor (docs/concept/bosses.png).
--
-- Coordenadas em studs no referencial do root do boss do servidor (mesmo do BossModels): o visual
-- fica exatamente onde o modelo antigo estava. As JUNTAS têm os mesmos nomes do modelo antigo (Body,
-- Neck, Jaw, ArmL/R, LegL/R, LegFL.., WingL/R, NeckSeg1..3, Seg1..8, Petal1..8, Root1..4, Orbit,
-- OrbitHalo), então as animações dos bosses (Animator) funcionam iguais. Peças com EnergyFx (núcleo,
-- olhos, punhos, gema, veios...) recebem a carga de energia antes dos ataques (Fx.luau).
--
-- opts.low = true: resolução menor para o modo de peças (sem EditableMesh), em que cada triângulo vira
-- WedgeParts — por isso o orçamento de triângulos de cada boss é bem menor nesse modo.

local MeshKit = require(script.Parent.MeshKit)
local PetAnatomy = require(script.Parent.PetAnatomy)

local BossAnatomy = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local rad = math.rad
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local merge = MeshKit.merge
local FWD = V(0, 0, -1)

-- altura do centro do root acima do chão (igual ao BossModels; o servidor posiciona o boss com ela)
BossAnatomy.Hover = { elderroot = 13, prism_titan = 12.3, tempest_wyrm = 12, wilderbloom = 7.4, void_sovereign = 13.5 }
BossAnatomy.Ids = { "elderroot", "prism_titan", "tempest_wyrm", "wilderbloom", "void_sovereign" }

local LOW = false

local function darker(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function hash(x: number, y: number, z: number): number
	local n = math.sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453
	return n - math.floor(n)
end

local function solid(c: Color3)
	return function()
		return c
	end
end

-------------------------------------------------------------------------------
-- Ferramentas de modelagem
-------------------------------------------------------------------------------

-- Loft com a resolução do modo atual (malhas lisas ou peças). o.pow vale para todas as seções.
local function L(keys, o)
	o = table.clone(o or {})
	if o.pow then
		for _, k in ipairs(keys) do
			k.pow = k.pow or o.pow
		end
	end
	if LOW then
		o.seg = math.max(o.minSeg or 4, math.floor((o.seg or 12) * (o.lowSeg or 0.5) + 0.5))
		o.steps = math.max(1, math.floor((o.steps or 3) * (o.lowSteps or 0.34) + 0.5))
		o.capRings = math.min(o.capRings or 2, o.lowCap or 0)
	end
	if not o.color then
		o.color = solid(o.col or WHITE)
	end
	return MeshKit.loft(keys, o)
end

-- Tubo por uma curva de pontos, raio r0 → r1.
local function tube(pts, r0: number, r1: number, o)
	o = o or {}
	local keys = {}
	local n = #pts
	for i, p in ipairs(pts) do
		local f = n > 1 and (i - 1) / (n - 1) or 0
		local r = r0 + (r1 - r0) * f
		keys[i] = { p = p, w = r * (o.wx or 1), h = r * (o.hy or 1) }
	end
	local lo = {
		seg = o.seg or 8, steps = o.steps or 3, up = o.up, pow = o.pow, capStart = o.capStart or r0 * 0.6, capEnd = o.capEnd or r1 * 0.8, capRings = o.capRings,
		col = o.col, color = o.color, flat = o.flat, lowSeg = o.lowSeg, minSeg = o.minSeg, lowSteps = o.lowSteps,
	}
	if LOW and math.max(r0, r1) < 0.36 then
		-- fios finos (veios, frisos, garras): seção triangular, um trecho por ponto
		lo.seg, lo.minSeg, lo.lowSeg, lo.steps, lo.lowSteps = 3, 3, 1, 1, 1
	end
	return L(keys, lo)
end

-- Espinho/garra/dente: cone pontudo.
local function spike(a: Vector3, dir: Vector3, len: number, r: number, col: Color3, o)
	o = o or {}
	dir = dir.Unit
	local b = a + dir * len * 0.7
	local mid = a + dir * len * 0.35 + (o.bend or Vector3.zero) * len
	local keys = { { p = a, w = r }, { p = mid, w = r * 0.72 }, { p = b, w = r * 0.32 } }
	if LOW then
		keys = { { p = a, w = r }, { p = (a + b) / 2 + (o.bend or Vector3.zero) * len * 0.5, w = r * 0.55 } }
	end
	return L(keys, { seg = o.seg or 6, steps = 1, capStart = o.capStart or 0, capEnd = LOW and len * 0.5 or len * 0.3, capRings = 0, col = col, flat = o.flat,
		lowSeg = r < 0.36 and 0.5 or 0.7, minSeg = 3, up = o.up })
end

-- Cristal facetado: prisma hexagonal com ponta piramidal, mais escuro na base e claro na ponta.
local function crystal(base: Vector3, dir: Vector3, len: number, r: number, col: Color3, o)
	o = o or {}
	dir = dir.Unit
	local up = math.abs(dir.Y) < 0.95 and V(0, 1, 0) or FWD
	local tipCol = col:Lerp(WHITE, o.light or 0.5)
	local deep = col:Lerp(BLACK, o.dark or 0.35)
	local fl = o.flatten or 1
	local keys = { { p = base - dir * len * 0.08, w = r * 0.72, h = r * 0.72 * fl }, { p = base + dir * len * 0.68, w = r, h = r * fl } }
	return L(keys, {
		seg = o.seg or 6, steps = 1, up = up, capStart = o.both and len * 0.25 or 0, capEnd = len * 0.32, capRings = 0, flat = true, lowSeg = 0.84, minSeg = 4,
		color = function(_t, ex, _ey, p)
			local f = math.clamp((p - base):Dot(dir) / len, 0, 1)
			local c = deep:Lerp(col, math.min(1, f * 1.7)):Lerp(tipCol, math.max(0, f - 0.55) * 2)
			if ex > 0.6 then
				c = c:Lerp(WHITE, 0.18) -- face que pega luz
			end
			return c
		end,
	})
end

-- Núcleo do cristal (mesmo eixo, mais fino) — para cristais de vidro com brilho por dentro.
local function crystalCore(base: Vector3, dir: Vector3, len: number, r: number, col: Color3)
	return crystal(base + dir.Unit * len * 0.05, dir, len * 0.82, r * 0.42, col, { light = 0.6, dark = 0.1, seg = 5 })
end

-- Leque de cristais saindo de um ponto (ombros, costas, coroas). Devolve as listas (cristais, núcleos).
local function cluster(base: Vector3, dir: Vector3, side: Vector3, count: number, len: number, r: number, col: Color3, cores: Color3?)
	local list, coreList = {}, {}
	dir = dir.Unit
	for i = 1, count do
		local t = count == 1 and 0 or (i - 1) / (count - 1) - 0.5
		local k = 1 - math.abs(t) * 0.55
		local d = (dir + side * t * 1.2 + V(0, 0, (i % 2) * 0.18)).Unit
		local b = base + side * t * r * 2.2
		table.insert(list, crystal(b, d, len * k, r * k, col))
		if cores then
			table.insert(coreList, crystalCore(b, d, len * k, r * k, cores))
		end
	end
	return list, coreList
end

-- Normais por vértice e relevo: desloca cada vértice na normal por um ruído (fn ajusta o ruído).
local function displace(g, amp: number, freq: number, seed: number, fn)
	local nrm = MeshKit.normals(g)
	local out = table.create(#g.verts)
	for i, v in ipairs(g.verts) do
		local d = math.noise(v.X * freq + seed, v.Y * freq + 0.37, v.Z * freq - seed)
		if fn then
			d = fn(v, nrm[i], d)
		end
		out[i] = v + nrm[i] * (d * amp)
	end
	return { verts = out, colors = g.colors, tris = g.tris, flat = g.flat, keep = g.keep }
end

-- Pinta pela posição e pela normal (musgo em cima, ventre embaixo, sulcos...).
local function shade(g, fn)
	local nrm = MeshKit.normals(g)
	local cols = table.create(#g.verts)
	for i, v in ipairs(g.verts) do
		cols[i] = fn(v, nrm[i], g.colors[i])
	end
	return { verts = g.verts, colors = cols, tris = g.tris, flat = g.flat, keep = g.keep }
end

-- Pontos espalhados na superfície (para espinhos, musgo...), determinísticos e com distância mínima.
local function scatter(g, n: number, minDist: number, filter, seed: number)
	local nrm = MeshKit.normals(g)
	local cand = {}
	for i, v in ipairs(g.verts) do
		if filter(v, nrm[i]) then
			table.insert(cand, { v, nrm[i], hash(v.X + seed, v.Y * 1.3, v.Z - seed) })
		end
	end
	table.sort(cand, function(a, b)
		return a[3] > b[3]
	end)
	local out = {}
	for _, c in ipairs(cand) do
		local ok = true
		for _, o in ipairs(out) do
			if (o[1] - c[1]).Magnitude < minDist then
				ok = false
				break
			end
		end
		if ok then
			table.insert(out, c)
			if #out >= n then
				break
			end
		end
	end
	return out
end

-- Linha em zigue-zague (rachaduras e raios), determinística.
local function zigzag(a: Vector3, b: Vector3, n: number, amp: number, seed: number, normal: Vector3?)
	local d = b - a
	local side = d:Cross(normal or V(0, 0, -1))
	side = side.Magnitude > 1e-4 and side.Unit or V(1, 0, 0)
	local pts = { a }
	for i = 1, n - 1 do
		local f = i / n
		table.insert(pts, a + d * f + side * (hash(i, seed, 3.7) - 0.5) * 2 * amp)
	end
	table.insert(pts, b)
	return pts
end

-- Anel (auréola): tubo fechado num círculo.
local function ring(center: Vector3, radius: number, r: number, n: number, tilt: number, col: Color3)
	local keys = {}
	if LOW then
		n = math.max(8, math.floor(n * 0.5 + 0.5))
	end
	local cf = CFrame.new(center) * CFrame.Angles(tilt, 0, 0)
	for i = 0, n do
		local a = i / n * math.pi * 2 * 1.02
		table.insert(keys, { p = cf * V(math.cos(a) * radius, 0, math.sin(a) * radius), w = r, h = r })
	end
	return L(keys, { seg = 8, steps = 2, capStart = 0, capEnd = 0, col = col, lowSeg = r < 0.36 and 0.375 or 0.5, minSeg = 3, lowSteps = 0.5 })
end

-- Peça na planta com geometria escrita no referencial do root (converte para o pivô da junta).
local function part(bp, name: string, parent: string?, joint: string?, pivot: Vector3, g, opts)
	return PetAnatomy.addPart(bp, name, parent, joint, pivot, MeshKit.transform(g, CFrame.new(-pivot)), opts)
end

-- Aumenta um grupo de peças em torno de um ponto (ex.: a cabeça em torno da junta do pescoço).
local function scaleParts(bp, names, c: Vector3, k: number)
	local set = {}
	for _, n in ipairs(names) do
		set[n] = true
	end
	for _, p in ipairs(bp.parts) do
		if set[p.name] then
			p.pivot = c + (p.pivot - c) * k
			local verts = table.create(#p.geom.verts)
			for i, v in ipairs(p.geom.verts) do
				verts[i] = v * k
			end
			p.geom = { verts = verts, colors = p.geom.colors, tris = p.geom.tris, flat = p.geom.flat, keep = p.geom.keep }
		end
	end
end

local function energy(c: Color3)
	return { EnergyFx = true, EnergyColor = c }
end

-- Ramo com galhos (galhadas, cipós secos). Devolve as pontas.
local function branch(list, a: Vector3, dir: Vector3, len: number, r: number, depth: number, side: number, col: Color3, tips)
	dir = dir.Unit
	local b = a + dir * len
	local bend = V(side * 0.12, 0.08, 0.06) * len
	table.insert(list, tube({ a, (a + b) / 2 + bend, b }, r, r * 0.62, { seg = 7, col = col, capStart = 0, capEnd = r * 0.5, lowSeg = 0.6 }))
	if depth <= 0 then
		table.insert(tips, { b, dir })
		return
	end
	branch(list, b, dir + V(-side * 0.15, 0.7, 0.05), len * 0.72, r * 0.62, depth - 1, side, col, tips)
	branch(list, b - dir * len * 0.15, dir + V(side * 0.95, -0.15, -0.25), len * 0.6, r * 0.55, depth - 1, side, col, tips)
end

-------------------------------------------------------------------------------
-- ELDERROOT — colosso de casca e madeira, musgo nas costas, galhada, cristais verdes que brilham.
-------------------------------------------------------------------------------
local function elderroot(bp)
	local bark, dark, moss, mossHi = rgb(98, 68, 42), rgb(52, 36, 22), rgb(70, 118, 40), rgb(128, 176, 64)
	local glow, claw = rgb(90, 255, 80), rgb(206, 214, 166)
	local eyesAt = { V(-0.95, 11.35, -3.55), V(0.95, 11.35, -3.55) }
	local function barkShade(p, n)
		local g = math.noise(p.X * 0.8 + 0.31, p.Y * 0.22, p.Z * 0.8 + 0.17)
		local col = bark:Lerp(dark, math.clamp((g - 0.02) * 4, 0, 0.85))
		col = col:Lerp(bark:Lerp(WHITE, 0.12), math.clamp(-g * 2 - 0.4, 0, 0.5))
		local m = math.noise(p.X * 0.33 + 7.3, p.Y * 0.33, p.Z * 0.33 + 1.1)
		if n.Y > 0.3 and m > -0.2 then
			col = col:Lerp(moss:Lerp(mossHi, math.clamp(m + 0.5, 0, 1)), math.clamp((n.Y - 0.3) * 2.6, 0, 1))
		end
		for _, e in ipairs(eyesAt) do
			local d = (p - e).Magnitude
			if d < 1.1 then
				col = col:Lerp(rgb(18, 14, 10), (1 - d / 1.1) * 0.9) -- órbitas fundas
			end
		end
		return col
	end
	local function barkDisp(v, _n, d)
		return d * 0.55 + math.abs(math.noise(v.X * 0.75 + 2.1, v.Y * 0.16, v.Z * 0.75 + 4.7)) * 0.9 - 0.3
	end
	local function barkify(g, amp)
		return shade(displace(g, amp, 0.3, 1.7, barkDisp), barkShade)
	end

	-- TRONCO: peito largo e corcunda, placas de casca no peito e na barriga
	local tp = V(0, 4, 0)
	local torso = { L({
		{ p = V(0, -2.6, 0.2), w = 3.2, h = 2.4, hb = 2.5 },
		{ p = V(0, -0.6, 0.1), w = 3.5, h = 2.6, hb = 2.7 },
		{ p = V(0, 2.4, 0), w = 4.7, h = 3.3, hb = 3.2 },
		{ p = V(0, 5.6, 0.2), w = 5.6, h = 3.4, hb = 3.7 },
		{ p = V(0, 8.0, 0.6), w = 4.5, h = 2.6, hb = 3.9 },
		{ p = V(0, 9.3, 0.4), w = 2.6, h = 1.9, hb = 2.4 },
	}, { seg = 22, steps = 3, up = FWD, pow = 2.3, capStart = 1.2, capEnd = 1.0 }) }
	for _, s in ipairs({ -1, 1 }) do
		table.insert(torso, L({ { p = V(s * 2.3, 7.0, -2.7), w = 2.0, h = 0.6, pow = 4 }, { p = V(s * 2.6, 5.0, -3.2), w = 2.4, h = 0.75, pow = 4 }, { p = V(s * 2.2, 3.4, -3.0), w = 1.8, h = 0.55, pow = 4 } },
			{ seg = 12, steps = 2, up = FWD, capStart = 0.4, capEnd = 0.4 }))
		table.insert(torso, L({ { p = V(s * 1.3, 1.6, -2.8), w = 1.3, h = 0.5, pow = 4 }, { p = V(s * 1.4, 0.2, -2.8), w = 1.4, h = 0.55, pow = 4 } },
			{ seg = 10, steps = 1, up = FWD, capStart = 0.35, capEnd = 0.35 }))
	end
	part(bp, "Torso", nil, "Body", tp, barkify(merge(torso), 1.0), { material = "Wood" })

	-- cristal do peito (carrega energia) + rachaduras verdes
	part(bp, "ChestCrystal", "Torso", nil, tp, merge({
		crystal(V(0, 4.9, -3.3), V(0, 0.2, -1), 3.0, 1.0, glow),
		crystal(V(-1.0, 3.9, -3.2), V(-0.6, -0.1, -1), 1.8, 0.55, glow),
		crystal(V(1.0, 4.0, -3.2), V(0.6, -0.15, -1), 1.6, 0.5, glow),
	}), { material = "Neon", role = "Glow", attrs = energy(glow) })
	local cracks = {}
	for i, c in ipairs({ { V(-0.5, 2.6, -3.6), V(-1.8, -0.9, -3.2) }, { V(0.5, 2.5, -3.6), V(2.3, 0.4, -3.3) }, { V(-0.2, 1.0, -3.5), V(0.4, -1.6, -3.0) },
		{ V(-2.6, 7.6, -2.4), V(-3.9, 5.2, -2.6) }, { V(2.4, 7.4, -2.5), V(4.0, 5.0, -2.6) } }) do
		table.insert(cracks, tube(zigzag(c[1], c[2], 4, 0.35, i), 0.15, 0.07, { seg = 5, steps = 1, lowSeg = 0.7, minSeg = 3, col = glow }))
	end
	part(bp, "Cracks", "Torso", nil, tp, merge(cracks), { material = "Neon", role = "Glow" })
	-- cristais das costas
	local back = {}
	for _, c in ipairs({ { V(0, 9.0, 2.6), V(0, 1, 0.55), 6.5, 1.3 }, { V(-2.2, 8.5, 2.8), V(-0.55, 1, 0.5), 5.2, 1.05 }, { V(2.2, 8.5, 2.8), V(0.55, 1, 0.5), 5.4, 1.1 },
		{ V(-3.7, 7.4, 2.0), V(-0.9, 0.8, 0.4), 3.6, 0.8 }, { V(3.7, 7.3, 2.0), V(0.9, 0.8, 0.4), 3.4, 0.75 }, { V(-1.2, 6.8, 3.7), V(-0.3, 0.6, 1), 3.0, 0.7 },
		{ V(1.2, 6.6, 3.7), V(0.4, 0.6, 1), 2.8, 0.65 } }) do
		table.insert(back, crystal(c[1], c[2], c[3], c[4], glow))
	end
	part(bp, "BackCrystals", "Torso", nil, tp, merge(back), { material = "Neon", role = "Glow" })
	-- tufos de musgo e folhas nas costas/ombros
	local mossList = {}
	for i, c in ipairs({ V(0, 9.4, 1.2), V(-2.6, 8.9, 1.6), V(2.6, 8.8, 1.5), V(-1.4, 8.0, 3.3), V(1.6, 7.8, 3.3) }) do
		table.insert(mossList, L({ { p = c + V(-1.1, 0, 0), w = 0.7, h = 0.55 }, { p = c + V(0, 0.15, 0), w = 1.0, h = 0.75 }, { p = c + V(1.1, 0, 0.1), w = 0.7, h = 0.5 } },
			{ seg = 9, steps = 2, capStart = 0.6, capEnd = 0.6, col = i % 2 == 0 and moss or mossHi }))
	end
	part(bp, "BackMoss", "Torso", nil, tp, displace(merge(mossList), 0.35, 1.1, 3.3), { material = "Grass", role = "Accent" })

	-- CABEÇA: testa pesada, órbitas fundas com olhos verdes, nariz de raiz, galhada e cristais
	local hp = V(0, 10.8, -1.4)
	local headBark = merge({
		L({ { p = V(0, 11.4, 0.2), w = 1.9, h = 1.7, hb = 1.5 }, { p = V(0, 11.3, -1.6), w = 2.3, h = 1.9, hb = 1.4 }, { p = V(0, 10.9, -3.0), w = 2.0, h = 1.5, hb = 1.0 },
			{ p = V(0, 10.6, -3.5), w = 1.5, h = 1.0, hb = 0.6 } }, { seg = 18, steps = 3, pow = 2.4, capStart = 0.9, capEnd = 0.35 }),
		tube({ V(-2.3, 12.5, -2.6), V(-1.0, 11.95, -3.6), V(0, 11.8, -3.8), V(1.0, 11.95, -3.6), V(2.3, 12.5, -2.6) }, 0.55, 0.5, { seg = 9 }),
		tube({ V(0, 11.75, -3.7), V(0, 11.05, -4.0), V(0, 10.6, -3.95) }, 0.42, 0.5, { seg = 8 }),
		tube({ V(-1.9, 10.9, -2.7), V(-1.3, 10.55, -3.4) }, 0.6, 0.45, { seg = 8 }),
		tube({ V(1.9, 10.9, -2.7), V(1.3, 10.55, -3.4) }, 0.6, 0.45, { seg = 8 }),
	})
	local fangs = {}
	for _, x in ipairs({ -1.15, -0.5, 0.5, 1.15 }) do
		table.insert(fangs, spike(V(x, 10.35, -3.45 + math.abs(x) * 0.25), V(0, -1, -0.12), math.abs(x) < 1 and 1.0 or 0.75, 0.24, claw))
	end
	part(bp, "Head", "Torso", "Neck", hp, merge({ barkify(headBark, 0.45), merge(fangs) }), { material = "Wood" })
	local face = {}
	for _, e in ipairs(eyesAt) do
		local s = e.X < 0 and -1 or 1
		table.insert(face, tube({ e + V(-s * 0.5, -0.14, -0.12), e + V(s * 0.5, 0.18, 0.12) }, 0.27, 0.2, { seg = 8, hy = 0.62, col = glow }))
	end
	table.insert(face, tube({ V(-1.2, 10.25, -3.2), V(0, 10.15, -3.45), V(1.2, 10.25, -3.2) }, 0.2, 0.2, { seg = 6, col = glow:Lerp(BLACK, 0.25) }))
	part(bp, "Face", "Head", nil, hp, merge(face), { material = "Neon", role = "Eye", attrs = energy(glow) })
	-- galhada (galhos ramificados) com folhas nas pontas
	local antlers, tips = {}, {}
	for _, s in ipairs({ -1, 1 }) do
		branch(antlers, V(s * 1.3, 12.5, -0.9), V(s * 0.55, 1, 0.25), 2.7, 0.62, 2, s, dark, tips)
	end
	part(bp, "Antlers", "Head", nil, hp, shade(merge(antlers), function(p)
		return dark:Lerp(bark, math.clamp(math.noise(p.X, p.Y * 2, p.Z) + 0.4, 0, 1))
	end), { material = "Wood", role = "Accent" })
	local leaves = {}
	for i, t in ipairs(tips) do
		local b, d = t[1], t[2]
		for k = 0, 1 do
			local dir = (d + V((hash(i, k, 1) - 0.5) * 1.4, 0.2, (hash(i, k, 2) - 0.5) * 1.4)).Unit
			local tip = b + dir * 1.1
			local perp = dir:Cross(V(0, 1, 0))
			perp = perp.Magnitude > 1e-3 and perp.Unit * 0.32 or V(0.32, 0, 0)
			table.insert(leaves, MeshKit.sheet({ b, (b + tip) / 2 + perp, tip, (b + tip) / 2 - perp }, 0.06, (i + k) % 2 == 0 and moss or mossHi))
		end
	end
	part(bp, "AntlerLeaves", "Head", nil, hp, merge(leaves), { material = "Grass", role = "Accent" })
	part(bp, "HeadCrystals", "Head", nil, hp, merge({
		crystal(V(0, 12.6, -2.3), V(0, 1, -0.3), 3.0, 0.7, glow),
		crystal(V(-0.95, 12.5, -1.7), V(-0.4, 1, -0.1), 2.0, 0.5, glow),
		crystal(V(0.95, 12.5, -1.7), V(0.4, 1, -0.1), 2.2, 0.5, glow),
	}), { material = "Neon", role = "Glow" })
	-- MANDÍBULA com presas e barba de raízes
	local jp = V(0, 10.2, -1.6)
	local jawBark = { L({ { p = V(0, 9.95, -1.0), w = 1.7, h = 0.6, hb = 0.8 }, { p = V(0, 9.85, -2.6), w = 1.6, h = 0.55, hb = 0.7 }, { p = V(0, 9.95, -3.35), w = 1.2, h = 0.45, hb = 0.5 } },
		{ seg = 12, steps = 2, pow = 2.5, capStart = 0.4, capEnd = 0.3 }) }
	for k = -2, 2 do
		local a = math.abs(k)
		table.insert(jawBark, tube({ V(k * 0.6, 9.3, -2.6 + a * 0.3), V(k * 0.72, 8.3 - a * 0.2, -3.0), V(k * 0.86, 7.2 - a * 0.4, -2.75) }, 0.26, 0.07, { seg = 6, capStart = 0, lowSeg = 0.7 }))
	end
	local lower = {}
	for _, x in ipairs({ -0.8, 0.8 }) do
		table.insert(lower, spike(V(x, 10.15, -3.2), V(0, 1, -0.1), 0.75, 0.2, claw))
	end
	part(bp, "Jaw", "Head", "Jaw", jp, merge({ barkify(merge(jawBark), 0.25), merge(lower) }), { material = "Wood", role = "Belly" })
	scaleParts(bp, { "Head", "Face", "Antlers", "AntlerLeaves", "HeadCrystals", "Jaw" }, hp, 1.3)

	-- BRAÇOS enormes com punho de nós de madeira; cristais e musgo nos ombros
	for _, s in ipairs({ -1, 1 }) do
		local t = s < 0 and "L" or "R"
		local ap = V(s * 6.6, 6.4, 0)
		local arm = {
			L({ { p = V(s * 6.8, 5.0, 0.1), w = 2.4, h = 2.4 }, { p = V(s * 7.0, 7.2, 0), w = 2.8, h = 2.7 }, { p = V(s * 6.7, 9.0, 0.2), w = 2.0, h = 2.0 } },
				{ seg = 16, steps = 2, up = FWD, pow = 2.2, capStart = 0.8, capEnd = 1.0 }),
			tube({ V(s * 7.1, 5.6, 0), V(s * 7.6, 3.2, -0.2), V(s * 7.8, 1.2, -0.4) }, 1.7, 1.5, { seg = 14, up = FWD }),
			tube({ V(s * 7.8, 1.4, -0.4), V(s * 8.0, -1.2, -0.7), V(s * 8.0, -3.4, -1.0) }, 1.75, 2.15, { seg = 14, up = FWD }),
			L({ { p = V(s * 8.0, -3.4, -1.0), w = 2.3, h = 2.5 }, { p = V(s * 8.0, -5.4, -1.2), w = 2.5, h = 2.7 }, { p = V(s * 8.0, -6.9, -1.2), w = 2.2, h = 2.4 } },
				{ seg = 14, steps = 2, up = FWD, pow = 2.8, capStart = 0.3, capEnd = 0.6 }),
		}
		for k = 0, 3 do
			local x = s * 8.0 + (k - 1.5) * 1.05
			table.insert(arm, tube({ V(x, -4.2, -3.3), V(x, -5.4, -3.9), V(x, -6.6, -3.5), V(x, -7.0, -2.6) }, 0.62, 0.52, { seg = 8 }))
		end
		table.insert(arm, tube({ V(s * 6.4, -4.4, -2.6), V(s * 6.1, -5.6, -3.4), V(s * 6.6, -6.2, -3.8) }, 0.55, 0.45, { seg = 8 }))
		part(bp, "Arm" .. t, "Torso", "Arm" .. t, ap, barkify(merge(arm), 0.9), { material = "Wood" })
		local sc = cluster(V(s * 6.9, 9.4, 0.4), V(s * 0.45, 1, 0.25), V(s, 0, 0), 3, 5.4, 1.15, glow)
		table.insert(sc, crystal(V(s * 9.6, -0.6, 0.1), V(s, 0.55, 0.35), 2.6, 0.75, glow))
		table.insert(sc, crystal(V(s * 9.4, 1.6, 0.6), V(s, 0.9, 0.5), 1.8, 0.55, glow))
		table.insert(sc, tube(zigzag(V(s * 8.2, 0.8, -2.3), V(s * 8.4, -3.0, -2.9), 4, 0.3, 7 + s), 0.13, 0.07, { seg = 5, steps = 1, lowSeg = 0.7, minSeg = 3, col = glow }))
		part(bp, "ArmCrystals" .. t, "Arm" .. t, nil, ap, merge(sc), { material = "Neon", role = "Glow" })
		local sm = {}
		for i, c in ipairs({ V(s * 6.6, 9.3, -0.6), V(s * 7.9, 8.6, 0.9), V(s * 5.8, 8.7, 1.2) }) do
			table.insert(sm, L({ { p = c - V(0.8, 0, 0), w = 0.65, h = 0.5 }, { p = c + V(0.8, 0.1, 0), w = 0.6, h = 0.45 } }, { seg = 9, steps = 2, capStart = 0.6, capEnd = 0.6, col = i % 2 == 0 and moss or mossHi }))
		end
		part(bp, "ArmMoss" .. t, "Arm" .. t, nil, ap, displace(merge(sm), 0.3, 1.2, 5.1 + s), { material = "Grass", role = "Accent" })
		-- PERNAS: coxa, canela e pé de raízes com garras claras
		local lp = V(s * 2.8, -3.5, 0)
		local leg = {
			tube({ V(s * 2.9, -2.6, 0.2), V(s * 3.1, -5.0, -0.1), V(s * 3.3, -7.4, -0.4) }, 2.1, 1.8, { seg = 14, up = FWD }),
			tube({ V(s * 3.3, -7.2, -0.4), V(s * 3.3, -9.2, -0.1), V(s * 3.3, -11.0, 0.1) }, 1.85, 2.1, { seg = 14, up = FWD }),
			L({ { p = V(s * 3.3, -11.85, 1.3), w = 2.1, h = 0.75 }, { p = V(s * 3.3, -11.8, -0.4), w = 2.5, h = 0.95 }, { p = V(s * 3.3, -11.85, -2.4), w = 2.4, h = 0.75 } },
				{ seg = 14, steps = 2, pow = 2.6, capStart = 0.6, capEnd = 0.5 }),
		}
		local claws = {}
		for k = -1, 1 do
			local a = V(s * 3.3 + k * 1.2, -11.6, -2.2)
			local b = V(s * 3.3 + k * 1.9, -12.25, -4.3)
			table.insert(leg, tube({ a, V(s * 3.3 + k * 1.6, -12.0, -3.5), b }, 0.7, 0.36, { seg = 8, capEnd = 0.1 }))
			table.insert(claws, spike(b, V(k * 0.3, -0.25, -1), 1.2, 0.34, claw))
		end
		part(bp, "Leg" .. t, "Torso", "Leg" .. t, lp, barkify(merge(leg), 0.8), { material = "Wood" })
		part(bp, "Claws" .. t, "Leg" .. t, nil, lp, merge(claws), { material = "SmoothPlastic", role = "Detail" })
	end
end

-------------------------------------------------------------------------------
-- PRISM TITAN — colosso de rocha escura em blocos facetados, aglomerados de cristal azul com
-- núcleo luminoso, coração de energia no peito com veios, olhos em fenda, punhos que carregam.
-------------------------------------------------------------------------------
local function prismTitan(bp)
	local rock, dark, plate = rgb(52, 52, 78), rgb(28, 28, 46), rgb(70, 70, 100)
	local glass, glow, pale = rgb(110, 180, 255), rgb(60, 150, 255), rgb(170, 220, 255)
	local function rockShade(p, n)
		local g = math.noise(p.X * 0.45 + 3.3, p.Y * 0.45, p.Z * 0.45 + 0.7)
		local col = rock:Lerp(plate, math.clamp(g + 0.45, 0, 1))
		if n.Y < -0.35 then
			col = col:Lerp(dark, 0.6)
		elseif n.Y > 0.6 then
			col = col:Lerp(plate:Lerp(WHITE, 0.1), 0.4)
		end
		-- reflexo azul dos cristais nas faces de cima e da frente
		if n.Z < -0.6 then
			col = col:Lerp(rgb(70, 90, 150), 0.18)
		end
		return col
	end
	local function rockify(g, amp)
		return shade(displace(g, amp, 0.24, 4.1), rockShade)
	end
	local function box(a: Vector3, b: Vector3, w: number, h: number, o)
		o = o or {}
		local tp_ = o.taper or 1
		if LOW then
			-- caixa de 4 lados alinhada (seção girada 45°, compensando o tamanho)
			local k = math.sqrt(2)
			return L({ { p = a, w = w * k, h = h * k }, { p = b, w = w * tp_ * k, h = h * tp_ * k } },
				{ seg = 4, steps = 1, phase = math.pi / 4, flat = true, up = o.up, capStart = 0.08, capEnd = 0.08, capRings = 0, lowSeg = 1, minSeg = 4 })
		end
		return L({ { p = a, w = w, h = h }, { p = b, w = w * tp_, h = h * tp_ } },
			{ seg = 8, steps = 1, pow = 5, flat = true, up = o.up, capStart = o.cap or math.min(w, h) * 0.35, capEnd = o.cap or math.min(w, h) * 0.35, capRings = 1 })
	end
	local function glassCrystals(list)
		local c, k = {}, {}
		for _, q in ipairs(list) do
			table.insert(c, crystal(q[1], q[2], q[3], q[4], glass))
			table.insert(k, crystalCore(q[1], q[2], q[3], q[4], glow))
		end
		return merge(c), merge(k)
	end

	-- TRONCO
	local tp = V(0, 4.5, 0)
	local torso = { L({
		{ p = V(0, -2.8, 0.2), w = 3.6, h = 2.6, hb = 2.8 },
		{ p = V(0, -0.6, 0.1), w = 3.9, h = 2.8, hb = 2.9 },
		{ p = V(0, 2.6, 0), w = 5.3, h = 3.6, hb = 3.4 },
		{ p = V(0, 6.2, 0.1), w = 6.3, h = 3.9, hb = 4.0 },
		{ p = V(0, 8.8, 0.6), w = 5.0, h = 3.0, hb = 4.4 },
		{ p = V(0, 10.1, 0.5), w = 2.8, h = 2.0, hb = 2.6 },
	}, { seg = 12, steps = 2, up = FWD, pow = 1.7, flat = true, capStart = 1.0, capEnd = 0.8, lowSeg = 0.75 }) }
	for _, s in ipairs({ -1, 1 }) do
		table.insert(torso, box(V(s * 2.9, 8.0, -3.4), V(s * 3.1, 5.6, -3.8), 2.3, 0.75, { up = FWD })) -- peitoral
		table.insert(torso, box(V(s * 5.6, 5.8, -0.6), V(s * 5.4, 1.4, -0.6), 0.7, 2.6, { up = V(s, 0, 0) })) -- costela
		for k = 0, 2 do
			table.insert(torso, box(V(s * 1.35, 3.0 - k * 1.55, -3.3 + k * 0.15), V(s * 1.35, 2.0 - k * 1.55, -3.3 + k * 0.15), 1.2, 0.5, { up = FWD })) -- abdômen
		end
	end
	table.insert(torso, box(V(0, 7.0, 4.0), V(0, 10.4, 3.4), 3.6, 1.4, { up = V(0, 0, 1) })) -- corcova das costas
	for i = 0, 3 do
		local a = rad(45 + i * 90)
		local c = V(math.cos(a) * 1.9, 5.4 + math.sin(a) * 1.9, -3.9)
		table.insert(torso, box(c - V(0, 0, -0.1), c + V(0, 0, -0.7), 0.8, 0.8))
	end
	part(bp, "Torso", nil, "Body", tp, rockify(merge(torso), 1.0), { material = "Slate" })
	-- NÚCLEO: casca de vidro + coração de energia e veios que irradiam
	local function diamond(c: Vector3, r: number, depth: number, col: Color3)
		return L({ { p = c + V(0, 0, depth * 0.3), w = r, h = r }, { p = c - V(0, 0, depth * 0.3), w = r, h = r } },
			{ seg = 4, steps = 1, capStart = depth * 0.7, capEnd = depth * 0.7, capRings = 0, flat = true, lowSeg = 1, color = function(_t, ex)
				return col:Lerp(WHITE, math.max(0, ex) * 0.4)
			end })
	end
	part(bp, "CoreShell", "Torso", nil, tp, diamond(V(0, 5.4, -4.1), 1.55, 1.3, glass), { material = "Glass", role = "Accent", transparency = 0.3 })
	local core = { diamond(V(0, 5.4, -4.15), 1.0, 1.1, glow) }
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.3
		local d = V(math.cos(a), math.sin(a), 0)
		local a0 = V(0, 5.4, -4.0) + d * 1.6
		local a1 = V(0, 5.4, -3.6) + d * 4.2 + V(0, 0, 0.4 * math.abs(d.X))
		table.insert(core, tube(zigzag(a0, a1, 4, 0.3, i + 11), 0.16, 0.08, { seg = 5, steps = 1, lowSeg = 0.7, minSeg = 3, col = glow }))
	end
	part(bp, "Core", "Torso", nil, tp, merge(core), { material = "Neon", role = "Glow", attrs = energy(glow) })
	local bc, bk = glassCrystals({
		{ V(0, 10.4, 3.5), V(0, 1, 0.5), 8.5, 1.7 }, { V(-2.4, 9.8, 3.6), V(-0.5, 1, 0.45), 7.0, 1.45 }, { V(2.4, 9.8, 3.6), V(0.5, 1, 0.45), 7.2, 1.45 },
		{ V(-4.2, 8.8, 3.0), V(-0.9, 0.9, 0.35), 5.0, 1.1 }, { V(4.2, 8.8, 3.0), V(0.9, 0.9, 0.35), 5.2, 1.1 },
		{ V(-1.5, 7.2, 4.8), V(-0.3, 0.55, 1), 4.6, 1.0 }, { V(1.5, 7.0, 4.8), V(0.35, 0.55, 1), 4.2, 0.95 }, { V(0, 5.6, 4.8), V(0, 0.3, 1), 3.4, 0.8 },
	})
	part(bp, "BackCrystals", "Torso", nil, tp, bc, { material = "Glass", role = "Accent", transparency = 0.22 })
	part(bp, "BackCores", "Torso", nil, tp, bk, { material = "Neon", role = "Glow" })

	-- CABEÇA de bloco: testa saliente, olhos em fenda, maçãs, coroa de cristais
	local hp = V(0, 11.5, -1.4)
	local head = merge({
		L({ { p = V(0, 12.0, 0), w = 2.1, h = 1.9, hb = 1.6 }, { p = V(0, 11.9, -1.8), w = 2.3, h = 1.9, hb = 1.5 }, { p = V(0, 11.4, -3.1), w = 1.9, h = 1.4, hb = 1.1 } },
			{ seg = 10, steps = 2, pow = 1.8, flat = true, capStart = 0.8, capEnd = 0.45, lowSeg = 0.8 }),
		box(V(-2.4, 12.55, -3.0), V(2.4, 12.55, -3.0), 0.55, 0.65, { up = V(0, 1, -0.4) }),
		box(V(-1.9, 11.0, -2.9), V(-1.1, 10.8, -3.4), 0.6, 0.55),
		box(V(1.9, 11.0, -2.9), V(1.1, 10.8, -3.4), 0.6, 0.55),
		box(V(0, 12.2, -3.4), V(0, 11.0, -3.75), 0.35, 0.4),
	})
	part(bp, "Head", "Torso", "Neck", hp, rockify(head, 0.35), { material = "Slate" })
	for _, s in ipairs({ -1, 1 }) do
		part(bp, s < 0 and "TitanEyeL" or "TitanEyeR", "Head", nil, hp, tube({ V(s * 0.45, 11.75, -3.55), V(s * 1.5, 12.05, -3.15) }, 0.22, 0.15, { seg = 6, hy = 0.6, col = pale }),
			{ material = "Neon", role = "Eye", attrs = energy(pale) })
	end
	local hc, hk = glassCrystals({
		{ V(0, 13.2, -1.6), V(0, 1, 0.1), 3.8, 0.95 }, { V(-1.2, 13.0, -1.2), V(-0.35, 1, 0.15), 3.0, 0.75 }, { V(1.2, 13.0, -1.2), V(0.35, 1, 0.15), 3.1, 0.75 },
		{ V(-1.9, 12.4, 0), V(-1, 0.75, 0.25), 3.4, 0.8 }, { V(1.9, 12.4, 0), V(1, 0.75, 0.25), 3.4, 0.8 }, { V(0, 12.9, 0.6), V(0, 0.8, 0.7), 2.6, 0.7 },
	})
	part(bp, "HeadCrystals", "Head", nil, hp, hc, { material = "Glass", role = "Accent", transparency = 0.22 })
	part(bp, "HeadCores", "Head", nil, hp, hk, { material = "Neon", role = "Glow" })
	local jp = V(0, 9.5, -1.9)
	local teeth = {}
	for k = -1, 1 do
		table.insert(teeth, crystal(V(k * 0.85, 10.0, -3.1), V(0, 1, -0.15), 0.9, 0.24, pale, { seg = 4 }))
	end
	part(bp, "Jaw", "Head", "Jaw", jp, merge({ rockify(box(V(0, 9.9, -1.0), V(0, 9.75, -3.2), 1.85, 0.6, {}), 0.2), merge(teeth) }), { material = "Slate", role = "Belly" })
	scaleParts(bp, { "Head", "TitanEyeL", "TitanEyeR", "HeadCrystals", "HeadCores", "Jaw" }, hp, 1.3)

	-- BRAÇOS: ombro de pedregulho com ombreira e cristais, antebraço largo com espinhos, punho que carrega
	for _, s in ipairs({ -1, 1 }) do
		local t = s < 0 and "L" or "R"
		local ap = V(s * 7.4, 7.5, 0)
		local arm = {
			L({ { p = V(s * 7.6, 6.0, 0), w = 2.9, h = 2.9 }, { p = V(s * 7.8, 8.4, 0), w = 3.2, h = 3.1 }, { p = V(s * 7.4, 10.2, 0.1), w = 2.2, h = 2.2 } },
				{ seg = 10, steps = 2, up = FWD, pow = 1.7, flat = true, capStart = 0.8, capEnd = 0.9, lowSeg = 0.8 }),
			box(V(s * 7.2, 10.2, 0), V(s * 9.4, 9.4, 0), 2.9, 0.6, { up = V(0, 1, 0), taper = 0.8 }), -- ombreira
			L({ { p = V(s * 7.8, 6.0, 0), w = 1.9, h = 1.9 }, { p = V(s * 8.1, 1.4, -0.2), w = 1.75, h = 1.75 } }, { seg = 9, steps = 1, up = FWD, pow = 1.8, flat = true, capStart = 0.5, capEnd = 0.6, lowSeg = 0.9 }),
			box(V(s * 8.15, 1.9, 0.9), V(s * 8.15, 0.6, -1.3), 1.8, 1.2, {}), -- cotovelo
			L({ { p = V(s * 8.2, 1.0, -0.4), w = 2.2, h = 2.2 }, { p = V(s * 8.3, -2.6, -0.6), w = 2.6, h = 2.6 } }, { seg = 9, steps = 1, up = FWD, pow = 1.8, flat = true, capStart = 0.5, capEnd = 0.4, lowSeg = 0.9 }),
			box(V(s * 8.3, -2.6, -0.6), V(s * 8.3, -3.6, -0.6), 2.85, 2.85, { up = FWD, cap = 0.25 }), -- bracelete
		}
		part(bp, "Arm" .. t, "Torso", "Arm" .. t, ap, rockify(merge(arm), 0.55), { material = "Slate" })
		local fist = { L({ { p = V(s * 8.3, -3.6, -0.8), w = 2.9, h = 2.9 }, { p = V(s * 8.3, -5.6, -0.9), w = 3.1, h = 3.1 }, { p = V(s * 8.3, -7.2, -0.9), w = 2.7, h = 2.7 } },
			{ seg = 10, steps = 1, up = FWD, pow = 2.4, flat = true, capStart = 0.3, capEnd = 0.6, lowSeg = 0.8 }) }
		for k = 0, 3 do
			local x = s * 8.3 + (k - 1.5) * 1.35
			table.insert(fist, box(V(x, -4.2, -3.4), V(x, -6.8, -3.7), 0.62, 0.75, { up = FWD }))
		end
		part(bp, "Fist" .. t, "Arm" .. t, nil, ap, rockify(merge(fist), 0.4), { material = "Slate", role = "Belly", attrs = energy(glow) })
		local list = {
			{ V(s * 7.9, 10.6, 0.3), V(s * 0.5, 1, 0.1), 7.0, 1.45 }, { V(s * 6.6, 10.4, 1.4), V(s * 0.2, 1, 0.5), 5.2, 1.1 }, { V(s * 9.4, 9.8, -0.6), V(s * 1, 0.8, -0.1), 4.8, 1.05 },
			{ V(s * 8.8, 10.0, 1.5), V(s * 0.8, 0.9, 0.7), 4.0, 0.9 },
		}
		for k = 0, 2 do
			table.insert(list, { V(s * 10.4, -0.2 - k * 1.2, -0.6 + (k - 1) * 0.9), V(s * 1, 0.25, (k - 1) * 0.2), 2.6 - k * 0.4, 0.75 })
		end
		local ac, ak = glassCrystals(list)
		part(bp, "ArmCrystals" .. t, "Arm" .. t, nil, ap, ac, { material = "Glass", role = "Accent", transparency = 0.22 })
		local knuck = {}
		for k = -1, 1 do
			table.insert(knuck, crystal(V(s * 8.3 + k * 1.6, -7.3, -3.0), V(0, -0.6, -1), 1.6, 0.42, pale, { seg = 5 }))
		end
		table.insert(knuck, ak)
		part(bp, "ArmCores" .. t, "Arm" .. t, nil, ap, merge(knuck), { material = "Neon", role = "Glow" })
		-- PERNAS
		local lp = V(s * 3, -3.5, 0)
		local leg = {
			L({ { p = V(s * 3.1, -2.4, 0.1), w = 2.2, h = 2.3 }, { p = V(s * 3.2, -6.6, -0.2), w = 2.0, h = 2.1 } }, { seg = 9, steps = 1, up = FWD, pow = 1.8, flat = true, capStart = 0.6, capEnd = 0.5, lowSeg = 0.9 }),
			L({ { p = V(s * 3.2, -6.8, -0.1), w = 2.2, h = 2.3 }, { p = V(s * 3.2, -10.6, 0.1), w = 2.4, h = 2.5 } }, { seg = 9, steps = 1, up = FWD, pow = 1.8, flat = true, capStart = 0.5, capEnd = 0.3, lowSeg = 0.9 }),
			box(V(s * 3.2, -6.2, -2.4), V(s * 3.2, -9.6, -2.6), 1.5, 0.4, { up = FWD }), -- caneleira
			box(V(s * 3.2, -11.4, 1.6), V(s * 3.2, -11.4, -2.4), 2.5, 0.75, { up = V(0, 1, 0) }), -- pé
		}
		for k = -1, 1 do
			table.insert(leg, box(V(s * 3.2 + k * 1.5, -11.5, -2.2), V(s * 3.2 + k * 1.7, -11.6, -3.9), 0.6, 0.45, { taper = 0.6 }))
		end
		part(bp, "Leg" .. t, "Torso", "Leg" .. t, lp, rockify(merge(leg), 0.45), { material = "Slate" })
		local lc, lk = glassCrystals({ { V(s * 3.2, -6.6, -2.2), V(s * 0.2, 0.3, -1), 2.2, 0.75 }, { V(s * 5.0, -3.6, 0.2), V(s * 1, 0.4, 0.2), 1.8, 0.6 } })
		part(bp, "LegCrystals" .. t, "Leg" .. t, nil, lp, merge({ lc, lk }), { material = "Glass", role = "Accent", transparency = 0.15 })
	end
end

-------------------------------------------------------------------------------
-- TEMPEST WYRM — dragão de prata e ouro com olhos e veios elétricos azuis: pescoço articulado,
-- chifres dourados, asas enormes com membrana dourada, 4 patas com garras e cauda de 8 segmentos.
-------------------------------------------------------------------------------
local function tempestWyrm(bp)
	local silver, scale, gold, blue, mouth = rgb(226, 230, 244), rgb(176, 186, 214), rgb(232, 182, 60), rgb(90, 190, 255), rgb(130, 210, 255)
	local belly, membrane, tooth = rgb(240, 214, 150), rgb(242, 190, 92), rgb(250, 248, 240)
	local function hide(p, n)
		if n.Y < -0.4 then
			local band = math.sin(p.Z * 1.7 - p.Y * 1.7) > 0.78
			return band and darker(belly, 0.78) or belly
		end
		local cell = hash(math.floor(p.Z * 0.8 + math.floor(p.Y * 0.8) * 0.5), math.floor(p.Y * 0.8), math.floor(p.X * 0.8))
		local col = silver:Lerp(scale, 0.1 + cell * 0.5)
		if n.Y > 0.15 then
			col = col:Lerp(rgb(140, 156, 200), math.clamp((n.Y - 0.15) * 0.75, 0, 0.55)) -- dorso azulado
		end
		if n.Y < -0.15 then
			col = col:Lerp(belly, 0.35)
		end
		return col
	end
	local function skin(g, amp)
		return shade(amp and displace(g, amp, 0.35, 8.2) or g, hide)
	end

	-- CORPO longo: peito fundo, cintura, quadris; espinhos dourados em fileira dupla e frisos
	local tp = V(0, 0, 0)
	local body = L({
		{ p = V(0, 2.2, -12.4), w = 3.0, h = 2.8, hb = 2.4 },
		{ p = V(0, 1.4, -8.4), w = 4.8, h = 4.4, hb = 4.6 },
		{ p = V(0, 0.8, -3.2), w = 4.8, h = 4.2, hb = 4.1 },
		{ p = V(0, 0.7, 2.0), w = 4.1, h = 3.8, hb = 3.4 },
		{ p = V(0, 1.0, 6.4), w = 4.6, h = 4.0, hb = 3.7 },
		{ p = V(0, 1.2, 10.4), w = 2.9, h = 2.7, hb = 2.3 },
	}, { seg = 24, steps = 3, capStart = 1.6, capEnd = 0, lowSeg = 0.5 })
	part(bp, "Torso", nil, "Body", tp, skin(body, 0.25), { material = "SmoothPlastic" })
	local goldList = {}
	for k = 0, 8 do
		local z = -10.5 + k * 2.3
		local top = 5.0 - math.abs(z + 2) * 0.05
		local hgt = 2.6 - math.abs(k - 4) * 0.25
		table.insert(goldList, spike(V(-0.7, top, z), V(-0.25, 1, 0.55), hgt, 0.42, gold, { flat = true }))
		table.insert(goldList, spike(V(0.7, top - 0.1, z + 1.1), V(0.25, 1, 0.55), hgt * 0.85, 0.38, gold, { flat = true }))
	end
	for _, s in ipairs({ -1, 1 }) do
		table.insert(goldList, tube({ V(s * 2.6, 4.6, -10.5), V(s * 3.4, 4.5, -5), V(s * 3.2, 4.2, 1), V(s * 3.3, 4.1, 6.2), V(s * 2.1, 3.4, 10) }, 0.22, 0.16, { seg = 5, col = gold, lowSeg = 0.8 }))
	end
	part(bp, "GoldTrim", "Torso", nil, tp, merge(goldList), { material = "Metal", role = "Accent", reflectance = 0.1 })
	part(bp, "ChestGem", "Torso", nil, tp, L({ { p = V(0, 2.4, -14.2), w = 0.95, h = 0.95 }, { p = V(0, 2.4, -14.6), w = 0.95, h = 0.95 } },
		{ seg = 4, steps = 1, capStart = 0.5, capEnd = 0.6, capRings = 0, flat = true, lowSeg = 1, col = blue }), { material = "Neon", role = "Glow", attrs = energy(blue) })
	local veins = {}
	for i, s in ipairs({ -1, 1 }) do
		table.insert(veins, tube(zigzag(V(s * 4.7, 2.0, -7.5), V(s * 4.2, 1.0, 5.0), 7, 0.6, i + 20, V(s, 0, 0)), 0.14, 0.08, { seg = 5, steps = 1, lowSeg = 0.7, minSeg = 3, col = blue }))
		table.insert(veins, tube(zigzag(V(s * 4.6, 0.6, -2.0), V(s * 3.8, -1.8, 2.0), 3, 0.4, i + 30, V(s, 0, 0)), 0.11, 0.06, { seg = 5, steps = 1, lowSeg = 0.7, minSeg = 3, col = blue }))
	end
	part(bp, "FlankVeins", "Torso", nil, tp, merge(veins), { material = "Neon", role = "Glow" })

	-- PESCOÇO articulado (3 juntas) e CABEÇA
	local np = { V(0, 3.2, -11.0), V(0, 6.2, -13.6), V(0, 9.2, -15.6), V(0, 11.8, -17.0) }
	local nr = { 2.9, 2.5, 2.15, 1.9 }
	for i = 1, 3 do
		local a, b = np[i], np[i + 1]
		local d = (b - a).Unit
		local seg = L({ { p = a - d * 1.2, w = nr[i], h = nr[i] * 1.02, hb = nr[i] * 0.95 }, { p = (a + b) / 2, w = (nr[i] + nr[i + 1]) / 2, h = (nr[i] + nr[i + 1]) / 2 },
			{ p = b + d * 0.6, w = nr[i + 1], h = nr[i + 1] } }, { seg = 18, steps = 2, capStart = 0.6, capEnd = 0.6, lowSeg = 0.5 })
		local back = (V(0, 1, 0) - d * d.Y).Unit:Lerp(V(0, 0, 1), 0.3).Unit
		local spikes = { spike(a + back * nr[i] * 0.95 + d * 0.6, back + V(0, 0, 0.5), 1.8 - i * 0.2, 0.36, gold, { flat = true }),
			spike(a + back * nr[i] * 0.9 + d * 1.9, back + V(0, 0, 0.5), 1.5 - i * 0.2, 0.3, gold, { flat = true }) }
		part(bp, "NeckSeg" .. i, i == 1 and "Torso" or "NeckSeg" .. (i - 1), "NeckSeg" .. i, a, merge({ skin(seg, 0.12), merge(spikes) }), { material = "SmoothPlastic" })
	end
	local hp = np[4]
	local head = merge({
		L({ { p = V(0, 12.5, -16.4), w = 1.95, h = 1.75, hb = 1.35 }, { p = V(0, 12.4, -18.4), w = 2.1, h = 1.6, hb = 1.05 }, { p = V(0, 12.0, -20.8), w = 1.45, h = 1.0, hb = 0.65 },
			{ p = V(0, 11.75, -22.8), w = 0.95, h = 0.72, hb = 0.45 } }, { seg = 20, steps = 3, capStart = 1.0, capEnd = 0.55, lowSeg = 0.5 }),
		tube({ V(-1.9, 13.25, -17.2), V(-1.45, 13.15, -18.9), V(-0.8, 12.75, -20.0) }, 0.45, 0.25, { seg = 7 }),
		tube({ V(1.9, 13.25, -17.2), V(1.45, 13.15, -18.9), V(0.8, 12.75, -20.0) }, 0.45, 0.25, { seg = 7 }),
	})
	head = shade(head, function(p, n)
		local c = hide(p, n)
		for _, s in ipairs({ -1, 1 }) do
			if (p - V(s * 0.45, 12.25, -23.3)).Magnitude < 0.35 then
				c = rgb(40, 50, 80) -- narinas
			end
		end
		return c
	end)
	local teeth = {}
	for k = 0, 5 do
		local z = -18.6 - k * 0.8
		local x = 1.25 - k * 0.12
		for _, s in ipairs({ -1, 1 }) do
			table.insert(teeth, spike(V(s * x, 11.45, z), V(0, -1, -0.15), k == 1 and 1.0 or 0.6, 0.15, tooth, { seg = 4 }))
		end
	end
	part(bp, "Head", "NeckSeg3", "Neck", hp, merge({ head, merge(teeth) }), { material = "SmoothPlastic" })
	local horns = {}
	for _, s in ipairs({ -1, 1 }) do
		table.insert(horns, tube({ V(s * 1.1, 13.5, -17.0), V(s * 1.9, 14.8, -15.2), V(s * 2.4, 15.7, -12.9), V(s * 2.5, 15.9, -11.0) }, 0.58, 0.06, { seg = 8, capEnd = 0.3 }))
		table.insert(horns, tube({ V(s * 1.75, 12.7, -16.5), V(s * 2.6, 13.0, -15.0), V(s * 3.2, 13.1, -13.5) }, 0.36, 0.05, { seg = 6, capEnd = 0.2 }))
		for k = 0, 2 do
			table.insert(horns, spike(V(s * (1.6 + k * 0.1), 11.6 - k * 0.15, -17.6 + k * 0.9), V(s * 1, -0.15, 0.8), 1.7 - k * 0.3, 0.3, gold, { flat = true }))
		end
	end
	for k = 0, 2 do
		table.insert(horns, spike(V(0, 13.85 - k * 0.15, -17.9 + k * 1.0), V(0, 1, 0.5), 1.1 - k * 0.2, 0.28, gold, { flat = true }))
	end
	part(bp, "Horns", "Head", nil, hp, shade(merge(horns), function(p)
		return gold:Lerp(rgb(255, 232, 150), math.clamp((p.Y - 13) / 3, 0, 1))
	end), { material = "Metal", role = "Accent", reflectance = 0.1 })
	local eyes = {}
	for _, s in ipairs({ -1, 1 }) do
		table.insert(eyes, tube({ V(s * 0.95, 12.6, -20.1), V(s * 1.6, 12.9, -18.8) }, 0.32, 0.24, { seg = 8, hy = 0.6, col = blue }))
	end
	part(bp, "WyrmEye", "Head", nil, hp, merge(eyes), { material = "Neon", role = "Eye", attrs = energy(blue) })
	part(bp, "Mouth", "Head", nil, hp, L({ { p = V(0, 11.2, -17.6), w = 1.3, h = 0.2 }, { p = V(0, 11.15, -21.8), w = 0.7, h = 0.15 } },
		{ seg = 8, steps = 1, capStart = 0.2, capEnd = 0.3, col = mouth }), { material = "Neon", role = "Glow", attrs = energy(mouth) })
	local jp = V(0, 11.3, -17.4)
	local jaw = L({ { p = V(0, 11.0, -17.1), w = 1.55, h = 0.55, hb = 0.85 }, { p = V(0, 10.9, -19.6), w = 1.2, h = 0.42, hb = 0.6 }, { p = V(0, 10.95, -22.3), w = 0.75, h = 0.32, hb = 0.4 } },
		{ seg = 14, steps = 2, capStart = 0.5, capEnd = 0.3, lowSeg = 0.6 })
	local lteeth = {}
	for k = 0, 4 do
		for _, s in ipairs({ -1, 1 }) do
			table.insert(lteeth, spike(V(s * (1.0 - k * 0.12), 11.35, -18.4 - k * 0.85), V(0, 1, -0.1), k == 0 and 0.85 or 0.55, 0.13, tooth, { seg = 4 }))
		end
	end
	part(bp, "Jaw", "Head", "Jaw", jp, merge({ skin(jaw), merge(lteeth) }), { material = "SmoothPlastic", role = "Belly" })

	-- ASAS enormes: ossos dourados, membrana dourada com bordas recortadas e veios elétricos
	for _, s in ipairs({ -1, 1 }) do
		local t = s < 0 and "L" or "R"
		local S = V(s * 3.6, 4.2, -6.5)
		local E = S + V(s * 5.5, 6.6, 2.0)
		local W = E + V(s * 6.2, 5.0, 1.5)
		local F = { W + V(s * 9.5, 2.2, 2.2), W + V(s * 9.0, -4.6, 4.2), W + V(s * 5.8, -9.2, 5.6), W + V(s * 1.6, -12.2, 6.6) }
		local R = S + V(s * 0.8, -1.2, 6.2)
		local bones = {
			tube({ S, (S + E) / 2 + V(0, 0.4, 0), E }, 0.85, 0.65, { seg = 9 }),
			tube({ E, (E + W) / 2 + V(0, 0.3, 0), W }, 0.65, 0.5, { seg = 9 }),
			spike(W, V(s * 0.3, 1, -0.3), 1.6, 0.38, gold, { flat = true }),
		}
		for i, f in ipairs(F) do
			table.insert(bones, tube({ W, W:Lerp(f, 0.5) + V(0, 0.4 - i * 0.1, 0), f }, 0.42, 0.12, { seg = 6, capEnd = 0.3 }))
		end
		local memb = {}
		local function scallop(a, b, k)
			return a:Lerp(b, 0.5):Lerp(W, k)
		end
		for i = 1, #F - 1 do
			table.insert(memb, MeshKit.sheet({ W, F[i], scallop(F[i], F[i + 1], 0.16), F[i + 1] }, 0.18, function(q)
				return membrane:Lerp(rgb(214, 150, 60), math.clamp((q - W).Magnitude / 12, 0, 1))
			end))
		end
		table.insert(memb, MeshKit.sheet({ S, E, W, F[4], scallop(F[4], R, 0.14), R }, 0.18, function(q)
			return membrane:Lerp(rgb(214, 150, 60), math.clamp((q - S).Magnitude / 16, 0, 1) * 0.6)
		end))
		part(bp, "Wing" .. t, "Torso", "Wing" .. t, S, shade(merge(bones), function(p)
			return gold:Lerp(rgb(255, 228, 140), math.clamp(hash(math.floor(p.X), math.floor(p.Y), 0) * 0.5, 0, 1))
		end), { material = "Metal", role = "Accent", reflectance = 0.1 })
		part(bp, "Membrane" .. t, "Wing" .. t, nil, S, merge(memb), { material = "SmoothPlastic", role = "Belly" })
		local v = {}
		for i, f in ipairs(F) do
			if i < 4 then
				local m = scallop(f, F[i + 1], 0.45)
				table.insert(v, tube(zigzag(W:Lerp(m, 0.15), m, 5, 0.45, i + s * 7), 0.12, 0.06, { seg = 4, steps = 1, minSeg = 3, lowSeg = 0.8, col = blue }))
			end
		end
		table.insert(v, tube(zigzag(E:Lerp(R, 0.1), E:Lerp(F[4], 0.5), 5, 0.5, 40 + s), 0.12, 0.06, { seg = 4, steps = 1, minSeg = 3, lowSeg = 0.8, col = blue }))
		part(bp, "WingVein" .. t, "Wing" .. t, nil, S, merge(v), { material = "Neon", role = "Glow", attrs = energy(blue) })
	end

	-- PATAS musculosas com garras douradas
	for _, leg in ipairs({ { "FL", -1, true }, { "FR", 1, true }, { "BL", -1, false }, { "BR", 1, false } }) do
		local s, front = leg[2], leg[3]
		local pv = front and V(s * 3.9, -1.2, -7.4) or V(s * 4.0, -0.8, 6.0)
		local pts
		if front then
			pts = { pv + V(0, 1.6, 0.4), V(s * 4.6, -5.4, -6.6), V(s * 4.7, -9.6, -7.8), V(s * 4.7, -10.9, -8.6) }
		else
			pts = { pv + V(0, 1.4, 0), V(s * 4.9, -4.6, 3.9), V(s * 4.9, -8.6, 7.4), V(s * 4.8, -10.9, 6.6) }
		end
		local g = {
			L({ { p = pts[1], w = front and 2.6 or 2.9, h = 2.8 }, { p = pts[1]:Lerp(pts[2], 0.5), w = front and 2.3 or 2.6, h = 2.5 }, { p = pts[2], w = 1.6, h = 1.7 } },
				{ seg = 14, steps = 2, up = V(0, 0, 1), capStart = 1.2, capEnd = 0.8, lowSeg = 0.6 }),
			tube({ pts[2], pts[2]:Lerp(pts[3], 0.5) + V(0, 0, front and 0.3 or -0.3), pts[3] }, 1.5, 1.05, { seg = 12, lowSeg = 0.6 }),
			L({ { p = pts[4] + V(0, 0.2, 1.4), w = 1.3, h = 0.6 }, { p = pts[4] + V(0, 0.1, -0.6), w = 1.5, h = 0.7 } }, { seg = 10, steps = 1, capStart = 0.4, capEnd = 0.6, lowSeg = 0.7 }),
		}
		local talons = {}
		for k = -1, 1 do
			table.insert(talons, spike(pts[4] + V(k * 0.75, -0.1, -1.1), V(k * 0.25, -0.35, -1), 1.5, 0.3, gold, { bend = V(0, -0.2, 0) }))
		end
		table.insert(talons, spike(pts[3] + V(0, 0.2, 1.0), V(0, -0.2, 1), 1.0, 0.25, gold))
		table.insert(talons, spike(pts[2] + V(0, 0.4, 1.0), V(s * 0.3, 0.3, 1), 1.4, 0.3, gold, { flat = true })) -- esporão no cotovelo
		table.insert(talons, spike(pts[2] + V(s * 1.1, 0.2, 0.3), V(s * 1, 0.2, 0.6), 1.1, 0.26, gold, { flat = true }))
		part(bp, "Leg" .. leg[1], "Torso", "Leg" .. leg[1], pv, skin(merge(g), 0.15), { material = "SmoothPlastic" })
		part(bp, "Talons" .. leg[1], "Leg" .. leg[1], nil, pv, merge(talons), { material = "Metal", role = "Accent", reflectance = 0.1 })
	end

	-- CAUDA: 8 segmentos que descem até o chão e se curvam para o lado; lâmina e brilho na ponta
	local tpts = { V(0, 1.2, 10.0), V(0, 0.4, 13.4), V(0, -1.0, 16.6), V(0.4, -2.9, 19.6), V(1.6, -4.8, 22.3), V(3.6, -6.4, 24.4), V(6.2, -7.5, 25.8), V(9.0, -8.1, 26.4), V(11.6, -8.1, 25.9) }
	for i = 1, 8 do
		local a, b = tpts[i], tpts[i + 1]
		local d = (b - a).Unit
		local r0, r1 = 2.6 * (1 - (i - 1) * 0.105), 2.6 * (1 - i * 0.105)
		local seg = L({ { p = a - d * 0.5, w = r0, h = r0 * 0.95, hb = r0 * 0.85 }, { p = b + d * 0.3, w = r1, h = r1 * 0.95, hb = r1 * 0.85 } },
			{ seg = 16, steps = 1, capStart = r0 * 0.5, capEnd = r1 * 0.5, lowSeg = 0.5 })
		local up = (V(0, 1, 0) - d * d.Y).Unit
		local sp = { spike(a:Lerp(b, 0.4) + up * r0 * 0.85, up - d * 0.6, 1.5 * (1 - i * 0.07), 0.3, gold, { flat = true }) }
		part(bp, "Seg" .. i, i == 1 and "Torso" or "Seg" .. (i - 1), "Seg" .. i, a, merge({ skin(seg), merge(sp) }), { material = "SmoothPlastic" })
	end
	local tip, tdir = tpts[9], (tpts[9] - tpts[8]).Unit
	part(bp, "TailBlade", "Seg8", nil, tpts[8], merge({
		L({ { p = tip - tdir * 0.6, w = 0.25, h = 1.4 }, { p = tip + tdir * 1.4, w = 0.2, h = 1.1 } }, { seg = 6, steps = 1, up = V(0, 1, 0), capStart = 0.2, capEnd = 1.6, capRings = 0, flat = true, col = gold }),
		spike(tip, V(0, 1, 0) + tdir * 0.4, 1.6, 0.3, gold, { flat = true }),
		spike(tip, V(0, -1, 0) + tdir * 0.4, 1.3, 0.3, gold, { flat = true }),
	}), { material = "Metal", role = "Accent", reflectance = 0.1 })
	part(bp, "TailGlow", "Seg8", nil, tpts[8], L({ { p = tip - tdir * 0.3, w = 0.55 }, { p = tip + tdir * 0.4, w = 0.55 } }, { seg = 8, steps = 1, capStart = 0.5, capEnd = 0.5, col = blue }),
		{ material = "Neon", role = "Glow", attrs = energy(blue) })
	bp.energyKind = "electric"
end

-------------------------------------------------------------------------------
-- THE WILDERBLOOM — fera vegetal corcunda, coração e coroa-flor de cristais rosa, braços com
-- garras, 4 cipós espinhosos enormes que se enrolam, espinhos e veios rosa pelo corpo.
-------------------------------------------------------------------------------
local function wilderbloom(bp)
	local bark, dark, moss, pink, pinkHi, thorn = rgb(84, 62, 40), rgb(46, 34, 24), rgb(84, 124, 46), rgb(255, 60, 200), rgb(255, 150, 230), rgb(214, 196, 150)
	local function barkShade(p, n)
		local g = math.noise(p.X * 0.9 + 1.3, p.Y * 0.3, p.Z * 0.9 + 0.2)
		local col = bark:Lerp(dark, math.clamp((g + 0.05) * 3.5, 0, 0.9))
		local m = math.noise(p.X * 0.4 + 3.3, p.Y * 0.4, p.Z * 0.4 + 9.1)
		if n.Y > 0.35 and m > 0 then
			col = col:Lerp(moss, math.clamp((n.Y - 0.35) * 2.2, 0, 0.85))
		end
		return col
	end
	local function barkify(g, amp)
		return shade(displace(g, amp, 0.34, 2.9, function(v, _n, d)
			return d * 0.6 + math.abs(math.noise(v.X * 0.8 + 1.1, v.Y * 0.2, v.Z * 0.8 + 6.7)) * 0.8 - 0.25
		end), barkShade)
	end

	local tp = V(0, 4, 0)
	local torsoG = L({
		{ p = V(0, -0.6, 1.8), w = 3.3, h = 2.8, hb = 2.6 },
		{ p = V(0, 2.0, 1.1), w = 4.0, h = 3.4, hb = 3.0 },
		{ p = V(0, 4.8, -0.1), w = 4.7, h = 3.7, hb = 3.0 },
		{ p = V(0, 7.0, -1.8), w = 4.0, h = 3.0, hb = 2.4 },
		{ p = V(0, 8.0, -3.0), w = 2.4, h = 1.8, hb = 1.6 },
	}, { seg = 22, steps = 3, up = V(0, 0.3, 1), pow = 2.2, capStart = 1.2, capEnd = 0.8 })
	torsoG = barkify(torsoG, 0.9)
	part(bp, "Torso", nil, "Body", tp, torsoG, { material = "Wood" })
	local th = {}
	for _, q in ipairs(scatter(torsoG, LOW and 14 or 26, 1.4, function(p, n)
		return n.Z > -0.2 or n.Y > 0.4
	end, 3)) do
		table.insert(th, spike(q[1] - q[2] * 0.15, q[2] + V(0, 0.3, 0.2), 1.1 + hash(q[1].X, q[1].Y, 1) * 0.8, 0.26, thorn, { seg = 5 }))
	end
	part(bp, "Thorns", "Torso", nil, tp, merge(th), { material = "SmoothPlastic", role = "Detail" })
	local glowList = { crystal(V(0, 4.0, -3.0), V(0, 0.15, -1), 2.4, 1.0, pink, { both = true }) }
	for i, c in ipairs({ { V(-0.6, 3.0, -3.2), V(-2.6, 0.6, -2.4) }, { V(0.7, 3.1, -3.2), V(2.8, 1.2, -2.5) }, { V(-0.4, 5.2, -3.1), V(-2.4, 7.2, -2.2) },
		{ V(0.5, 5.1, -3.1), V(2.5, 7.0, -2.3) }, { V(0, 2.6, -3.0), V(0.3, -0.4, -2.4) } }) do
		table.insert(glowList, tube(zigzag(c[1], c[2], 4, 0.3, i + 50), 0.14, 0.07, { seg = 5, steps = 1, lowSeg = 0.7, minSeg = 3, col = pink }))
	end
	part(bp, "Heart", "Torso", nil, tp, merge(glowList), { material = "Neon", role = "Glow", attrs = energy(pink) })
	part(bp, "BackCrystals", "Torso", nil, tp, merge(cluster(V(0, 7.2, 2.0), V(0, 1, 0.8), V(1, 0, 0), 3, 4.6, 1.1, pink)), { material = "Neon", role = "Glow" })

	-- CABEÇA baixa, olhos rosa, presas; coroa-flor de pétalas de cristal (Petal1..8)
	local hp = V(0, 8.4, -4.0)
	local headG = merge({
		L({ { p = V(0, 8.7, -3.0), w = 2.2, h = 1.8, hb = 1.4 }, { p = V(0, 8.4, -4.8), w = 2.3, h = 1.6, hb = 1.2 }, { p = V(0, 8.0, -6.0), w = 1.7, h = 1.1, hb = 0.8 } },
			{ seg = 18, steps = 3, pow = 2.2, capStart = 0.9, capEnd = 0.45 }),
		tube({ V(-2.1, 9.3, -5.0), V(-0.9, 8.9, -6.1), V(0, 8.75, -6.25), V(0.9, 8.9, -6.1), V(2.1, 9.3, -5.0) }, 0.42, 0.38, { seg = 8 }),
	})
	local fangs = {}
	for k = -2, 2 do
		table.insert(fangs, spike(V(k * 0.55, 7.35, -6.15 + math.abs(k) * 0.2), V(0, -1, -0.1), k == 0 and 0.6 or 0.9, 0.18, rgb(250, 230, 240), { seg = 4 }))
	end
	part(bp, "Head", "Torso", "Neck", hp, merge({ barkify(headG, 0.35), merge(fangs) }), { material = "Wood" })
	local eyes = {}
	for _, s in ipairs({ -1, 1 }) do
		table.insert(eyes, tube({ V(s * 0.45, 8.5, -6.3), V(s * 1.35, 8.75, -5.95) }, 0.24, 0.18, { seg = 8, hy = 0.6, col = pinkHi }))
	end
	part(bp, "Face", "Head", nil, hp, merge(eyes), { material = "Neon", role = "Eye" })
	local jp = V(0, 7.6, -4.6)
	local jl = {}
	for k = -1, 1, 2 do
		table.insert(jl, spike(V(k * 0.7, 7.35, -5.9), V(0, 1, -0.1), 0.7, 0.16, rgb(250, 230, 240), { seg = 4 }))
	end
	part(bp, "Jaw", "Head", "Jaw", jp, merge({ barkify(L({ { p = V(0, 7.45, -4.2), w = 1.6, h = 0.45, hb = 0.65 }, { p = V(0, 7.25, -6.0), w = 1.2, h = 0.35, hb = 0.5 } },
		{ seg = 12, steps = 2, capStart = 0.4, capEnd = 0.3 }), 0.2), merge(jl) }), { material = "Wood", role = "Belly" })
	part(bp, "BloomCore", "Head", nil, hp, L({ { p = V(0, 9.4, -3.6), w = 1.0, h = 1.0 }, { p = V(0, 10.4, -3.6), w = 0.8, h = 0.8 } },
		{ seg = 10, steps = 1, up = FWD, capStart = 0.4, capEnd = 0.7, col = pinkHi }), { material = "Neon", role = "Glow", attrs = energy(pinkHi) })
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local dir = V(math.cos(a), 0, math.sin(a))
		local base = V(0, 9.7, -3.6) + dir * 0.9
		local long = i % 2 == 0
		local g = merge({
			crystal(base, dir * 0.75 + V(0, 1, 0), long and 6.0 or 4.6, long and 1.15 or 0.95, long and pink or rgb(255, 110, 220), { flatten = 0.45 }),
			crystal(base + V(0, 0.2, 0), dir * 1.2 + V(0, 1, 0), long and 3.0 or 2.4, 0.55, pinkHi, { flatten = 0.5, seg = 5 }),
		})
		part(bp, "Petal" .. i, "Head", "Petal" .. i, base, g, { material = "Neon", role = "Glow" })
	end
	local crownParts = { "Head", "Face", "Jaw", "BloomCore" }
	for i = 1, 8 do
		table.insert(crownParts, "Petal" .. i)
	end
	scaleParts(bp, crownParts, hp, 1.3)

	-- BRAÇOS com garras de espinho e cristal no ombro
	for _, s in ipairs({ -1, 1 }) do
		local t = s < 0 and "L" or "R"
		local ap = V(s * 5.4, 6.4, -2.0)
		local arm = merge({
			L({ { p = V(s * 5.4, 5.2, -1.8), w = 2.0, h = 2.0 }, { p = V(s * 5.6, 7.2, -1.9), w = 2.2, h = 2.1 } }, { seg = 14, steps = 2, up = FWD, capStart = 1.0, capEnd = 1.2 }),
			tube({ V(s * 5.8, 5.8, -2.0), V(s * 6.6, 3.0, -2.4), V(s * 6.9, 0.6, -3.0) }, 1.2, 1.0, { seg = 12, up = FWD }),
			tube({ V(s * 6.9, 0.8, -3.0), V(s * 7.0, -1.5, -3.8), V(s * 6.9, -3.0, -4.4) }, 1.05, 1.25, { seg = 12, up = FWD }),
		})
		part(bp, "Arm" .. t, "Torso", "Arm" .. t, ap, barkify(arm, 0.5), { material = "Wood" })
		local claws = {}
		for k = -1, 1 do
			table.insert(claws, spike(V(s * 6.9 + k * 0.7, -3.4, -4.6), V(k * 0.2, -1, -0.45), 2.4, 0.32, thorn, { bend = V(0, 0, -0.25) }))
		end
		part(bp, "Claws" .. t, "Arm" .. t, nil, ap, merge(claws), { material = "SmoothPlastic", role = "Detail" })
		part(bp, "ArmCrystal" .. t, "Arm" .. t, nil, ap, merge({ crystal(V(s * 6.0, 8.2, -1.6), V(s * 0.6, 1, 0.2), 3.6, 1.0, pink),
			crystal(V(s * 6.8, 7.4, -1.2), V(s * 1, 0.6, 0.3), 2.0, 0.6, pinkHi) }), { material = "Neon", role = "Glow" })
		-- PERNAS curtas e grossas com pés de raiz
		local lp = V(s * 3.0, 0.4, 1.0)
		local leg = {
			L({ { p = V(s * 3.1, 1.2, 1.0), w = 2.0, h = 2.1 }, { p = V(s * 3.4, -2.6, 0.6), w = 1.7, h = 1.8 } }, { seg = 14, steps = 2, up = FWD, capStart = 1.0, capEnd = 0.6 }),
			tube({ V(s * 3.4, -2.4, 0.6), V(s * 3.4, -5.6, 0.2) }, 1.6, 1.8, { seg = 12, up = FWD }),
			L({ { p = V(s * 3.4, -6.35, 1.4), w = 1.8, h = 0.6 }, { p = V(s * 3.4, -6.3, -1.4), w = 2.0, h = 0.7 } }, { seg = 12, steps = 2, pow = 2.5, capStart = 0.5, capEnd = 0.5 }),
		}
		local toes = {}
		for k = -1, 1 do
			local b = V(s * 3.4 + k * 1.5, -6.85, -2.8)
			table.insert(leg, tube({ V(s * 3.4 + k * 0.9, -6.2, -1.6), b }, 0.55, 0.3, { seg = 7 }))
			table.insert(toes, spike(b, V(k * 0.3, -0.2, -1), 0.9, 0.28, thorn))
		end
		part(bp, "Leg" .. t, "Torso", "Leg" .. t, lp, barkify(merge(leg), 0.45), { material = "Wood" })
		part(bp, "Toes" .. t, "Leg" .. t, nil, lp, merge(toes), { material = "SmoothPlastic", role = "Detail" })
	end

	-- CIPÓS espinhosos (Root1..4): arqueiam para fora, descem e enrolam a ponta com um cristal
	local vines = {
		{ V(-4.4, 3.0, 0.0), { V(-7.5, 5.6, -1.2), V(-11.0, 5.4, -2.4), V(-13.6, 2.0, -3.4), V(-14.2, -2.6, -3.8), V(-13.4, -5.6, -4.0), V(-11.8, -5.8, -4.2), V(-11.2, -4.2, -4.3) } },
		{ V(4.4, 3.0, 0.0), { V(7.5, 5.6, -1.2), V(11.0, 5.4, -2.4), V(13.6, 2.0, -3.4), V(14.2, -2.6, -3.8), V(13.4, -5.6, -4.0), V(11.8, -5.8, -4.2), V(11.2, -4.2, -4.3) } },
		{ V(-3.4, 5.4, 3.0), { V(-6.0, 8.8, 4.4), V(-9.6, 9.8, 5.4), V(-12.6, 7.2, 6.3), V(-13.6, 3.0, 6.8), V(-12.6, 0.4, 7.0), V(-11.0, 0.6, 7.0), V(-10.6, 2.2, 6.9) } },
		{ V(3.4, 5.4, 3.0), { V(6.0, 8.8, 4.4), V(9.6, 9.8, 5.4), V(12.6, 7.2, 6.3), V(13.6, 3.0, 6.8), V(12.6, 0.4, 7.0), V(11.0, 0.6, 7.0), V(10.6, 2.2, 6.9) } },
	}
	for i, vdef in ipairs(vines) do
		local pv = vdef[1]
		local pts = { pv }
		for _, q in ipairs(vdef[2]) do
			table.insert(pts, q)
		end
		local body = tube(pts, 1.25, 0.32, { seg = 12, steps = 3, capStart = 0.6, capEnd = 0.3, lowSeg = 0.5 })
		local sp, gl = {}, {}
		for k = 2, #pts - 1 do
			local a, b = pts[k], pts[k + 1]
			local d = (b - a).Unit
			local out = d:Cross(V(0, 0, 1))
			out = (out.Magnitude > 1e-3 and out.Unit or V(1, 0, 0))
			if out:Dot(a - pv) < 0 then
				out = -out
			end
			local r = 1.25 + (0.32 - 1.25) * (k - 1) / (#pts - 1)
			local m = a:Lerp(b, 0.5)
			table.insert(sp, spike(m + out * r * 0.8, out + V(0, 0.3, 0), 0.9 + r * 0.5, 0.18 + r * 0.12, thorn, { seg = 4 }))
			table.insert(sp, spike(a + V(0, r * 0.85, 0), V(0, 1, 0) - d * 0.4, 0.6 + r * 0.4, 0.14 + r * 0.1, thorn, { seg = 4 }))
			if k % 2 == 0 then
				table.insert(gl, tube({ a:Lerp(b, 0.25) - out * r * 0.9, a:Lerp(b, 0.75) - out * r * 0.85 }, 0.16, 0.12, { seg = 5, steps = 1, minSeg = 3, lowSeg = 0.7, col = pink }))
			end
		end
		local last = pts[#pts]
		table.insert(gl, crystal(last - V(0, 0.3, 0), V(0, 1, 0) + (last - pts[#pts - 1]).Unit * 0.3, 2.8, 0.85, pink))
		part(bp, "Root" .. i, "Torso", "Root" .. i, pv, merge({ barkify(body, 0.3), merge(sp) }), { material = "Wood" })
		part(bp, "VineGlow" .. i, "Root" .. i, nil, pv, merge(gl), { material = "Neon", role = "Glow" })
	end
end

-------------------------------------------------------------------------------
-- VOID SOVEREIGN — senhor de armadura negra com frisos dourados, coroa de chifres, viseira e
-- olhos roxos, ombreiras com espinhos, túnica de placas até o chão, capa, auréola e cristais em órbita.
-------------------------------------------------------------------------------
local function voidSovereign(bp)
	local armor, armorHi, robe, gold, purple, glow = rgb(58, 48, 88), rgb(120, 104, 170), rgb(66, 38, 106), rgb(232, 186, 80), rgb(170, 80, 255), rgb(200, 130, 255)
	local cape, lining = rgb(28, 14, 50), rgb(96, 34, 160)
	local function metal(p, n)
		local c = armor:Lerp(armorHi, math.clamp(n.Y * 0.8 + math.noise(p.X * 0.6, p.Y * 0.6, p.Z * 0.6) * 0.3, 0, 0.8))
		return c
	end
	local function armorize(g)
		return shade(g, metal)
	end

	local tp = V(0, 5, 0)
	local torso = { L({
		{ p = V(0, 0.2, 0.1), w = 2.5, h = 1.9, hb = 1.8 },
		{ p = V(0, 2.4, 0), w = 2.9, h = 2.2, hb = 2.0 },
		{ p = V(0, 5.4, -0.2), w = 4.2, h = 2.7, hb = 2.3 },
		{ p = V(0, 8.2, -0.1), w = 4.7, h = 2.5, hb = 2.5 },
		{ p = V(0, 9.6, 0.1), w = 2.5, h = 1.7, hb = 1.8 },
	}, { seg = 16, steps = 2, up = FWD, pow = 2.6, flat = true, capStart = 0.8, capEnd = 0.6, lowSeg = 0.6 }) }
	for k = 0, 2 do
		table.insert(torso, L({ { p = V(0, 3.6 - k * 1.05, -0.05), w = 3.15 - k * 0.15, h = 2.45 - k * 0.12, hb = 2.2 }, { p = V(0, 3.0 - k * 1.05, -0.05), w = 3.0 - k * 0.15, h = 2.3 - k * 0.12, hb = 2.1 } },
			{ seg = 16, steps = 1, up = FWD, pow = 2.6, flat = true, capStart = 0.1, capEnd = 0.1, capRings = 0, lowSeg = 0.6 }))
	end
	for _, s in ipairs({ -1, 1 }) do
		table.insert(torso, L({ { p = V(s * 2.2, 8.4, -2.2), w = 1.9, h = 0.4 }, { p = V(s * 2.0, 6.0, -2.75), w = 1.7, h = 0.45 } }, { seg = 8, steps = 1, up = FWD, pow = 4, flat = true, capStart = 0.4, capEnd = 0.6 }))
	end
	part(bp, "Torso", nil, "Body", tp, armorize(merge(torso)), { material = "Metal", reflectance = 0.05 })
	local trim = {}
	for _, s in ipairs({ -1, 1 }) do
		table.insert(trim, tube({ V(s * 4.0, 9.0, -1.4), V(s * 2.2, 6.6, -2.95), V(s * 0.4, 3.4, -2.45) }, 0.17, 0.14, { seg = 5, col = gold }))
		table.insert(trim, tube({ V(s * 3.8, 8.6, -1.9), V(s * 3.95, 6.0, -2.2), V(s * 3.0, 4.2, -2.0) }, 0.13, 0.1, { seg = 5, col = gold }))
	end
	table.insert(trim, ring(V(0, 0.55, 0.05), 2.75, 0.32, 20, 0, gold)) -- cinto
	table.insert(trim, ring(V(0, 9.75, 0.1), 2.45, 0.2, 18, 0, gold)) -- gola
	table.insert(trim, L({ { p = V(0, 0.55, -2.8), w = 0.8, h = 0.8 }, { p = V(0, 0.55, -3.1), w = 0.8, h = 0.8 } }, { seg = 4, steps = 1, capStart = 0.2, capEnd = 0.3, capRings = 0, flat = true, col = gold }))
	part(bp, "GoldTrim", "Torso", nil, tp, merge(trim), { material = "Metal", role = "Accent", reflectance = 0.15 })
	part(bp, "ChestGem", "Torso", nil, tp, merge({
		L({ { p = V(0, 6.2, -2.95), w = 1.0, h = 1.35 }, { p = V(0, 6.2, -3.2), w = 1.0, h = 1.35 } }, { seg = 4, steps = 1, capStart = 0.2, capEnd = 0.55, capRings = 0, flat = true, lowSeg = 1, col = purple }),
		L({ { p = V(0, 0.55, -3.1), w = 0.4, h = 0.4 }, { p = V(0, 0.55, -3.25), w = 0.4, h = 0.4 } }, { seg = 4, steps = 1, capStart = 0.1, capEnd = 0.3, capRings = 0, flat = true, lowSeg = 1, col = glow }),
	}), { material = "Neon", role = "Glow", attrs = energy(purple) })
	-- túnica de placas até o chão (10 painéis em leque) com barra brilhante
	local panels, hem, ptrim = {}, {}, {}
	for k = 0, 9 do
		local a = rad(-90 + k * 36)
		local dir = V(math.cos(a), 0, math.sin(a))
		local tang = V(-dir.Z, 0, dir.X)
		local front = k == 0
		local top = V(0, 0.1, 0) + dir * 2.65
		local mid = V(0, -6.4, 0) + dir * 4.3
		local bot = V(0, -12.3, 0) + dir * 5.9
		local w0, w1, w2 = 1.05, 1.6, 1.95
		local g = L({ { p = top, w = w0, h = 0.16 }, { p = mid, w = w1, h = 0.18 }, { p = bot, w = w2, h = 0.2 }, { p = bot + V(0, -0.65, 0) + dir * 0.15, w = 0.3, h = 0.12 } },
			{ seg = 6, steps = 2, up = dir, pow = 3, flat = true, capStart = 0, capEnd = 0.1, capRings = 0, lowSeg = 1, lowSteps = 0.5,
				col = (k % 2 == 0) and armor or robe })
		table.insert(panels, g)
		table.insert(hem, tube({ bot + dir * 0.25 - tang * w2 * 0.9, bot + V(0, -0.55, 0) + dir * 0.3, bot + dir * 0.25 + tang * w2 * 0.9 }, 0.13, 0.13, { seg = 4, steps = 2, minSeg = 3, lowSeg = 0.8, col = purple }))
		if front or k == 1 or k == 9 then
			for _, e in ipairs({ -1, 1 }) do
				table.insert(ptrim, tube({ top + dir * 0.2 + tang * e * w0 * 0.85, mid + dir * 0.22 + tang * e * w1 * 0.85, bot + dir * 0.24 + tang * e * w2 * 0.85 }, 0.12, 0.12, { seg = 4, col = gold }))
			end
		end
	end
	part(bp, "Robe", "Torso", nil, tp, shade(merge(panels), function(p, n, c)
		return c:Lerp(armorHi, math.clamp(n.Y, 0, 1) * 0.5):Lerp(c:Lerp(BLACK, 0.4), math.clamp(-p.Y / 14, 0, 1) * 0.5)
	end), { material = "Metal", reflectance = 0.03 })
	part(bp, "RobeTrim", "Torso", nil, tp, merge(ptrim), { material = "Metal", role = "Accent", reflectance = 0.15 })
	part(bp, "Hem", "Torso", nil, tp, merge(hem), { material = "Neon", role = "Glow" })
	-- capa larga com dobras (forro roxo do lado de dentro)
	local capeG = L({ { p = V(0, 9.6, 2.2), w = 4.3, h = 0.22 }, { p = V(0, 4.0, 3.4), w = 5.2, h = 0.24 }, { p = V(0, -4.0, 4.6), w = 6.0, h = 0.26 }, { p = V(0, -12.4, 5.9), w = 6.8, h = 0.26 } },
		{ seg = 24, steps = 3, up = V(0, 0, 1), pow = 2, capStart = 0, capEnd = 0, lowSeg = 0.5 })
	capeG = displace(capeG, 0.55, 0.45, 6.6, function(v, _n, d)
		return math.sin(v.X * 1.3 + v.Y * 0.08) * 0.7 + d * 0.4
	end)
	part(bp, "Cape", "Torso", nil, tp, shade(capeG, function(p, n)
		return n.Z < 0 and lining:Lerp(cape, math.clamp(-p.Y / 14, 0, 0.6)) or cape:Lerp(rgb(48, 26, 80), math.clamp(n.Y, 0, 1))
	end), { material = "Fabric" })

	-- CABEÇA: elmo, viseira com olhos roxos, coroa de chifres dourados, auréola
	local hp = V(0, 11.6, -0.2)
	local helm = L({ { p = V(0, 9.9, -0.1), w = 1.3, h = 1.3 }, { p = V(0, 11.0, -0.25), w = 1.75, h = 1.85, hb = 1.7 }, { p = V(0, 12.4, -0.3), w = 1.8, h = 1.9, hb = 1.8 },
		{ p = V(0, 13.6, 0), w = 1.35, h = 1.45 } }, { seg = 12, steps = 2, up = FWD, pow = 2.4, flat = true, capStart = 0.2, capEnd = 0.8, lowSeg = 0.7 })
	local visor = L({ { p = V(0, 12.9, -1.75), w = 1.5, h = 0.25 }, { p = V(0, 11.4, -2.15), w = 1.15, h = 0.28 }, { p = V(0, 10.4, -1.95), w = 0.55, h = 0.22 } },
		{ seg = 8, steps = 1, up = FWD, pow = 3, flat = true, capStart = 0.1, capEnd = 0.3, col = rgb(12, 8, 20) })
	part(bp, "Head", "Torso", "Neck", hp, merge({ armorize(helm), visor }), { material = "Metal", reflectance = 0.05 })
	local face = {}
	for _, s in ipairs({ -1, 1 }) do
		table.insert(face, tube({ V(s * 0.22, 11.95, -2.35), V(s * 1.2, 12.4, -2.05) }, 0.26, 0.18, { seg = 6, hy = 0.6, col = glow }))
	end
	table.insert(face, L({ { p = V(0, 13.2, -1.75), w = 0.35, h = 0.5 }, { p = V(0, 13.2, -1.95), w = 0.35, h = 0.5 } }, { seg = 4, steps = 1, capStart = 0.1, capEnd = 0.25, capRings = 0, flat = true, col = purple }))
	part(bp, "Face", "Head", nil, hp, merge(face), { material = "Neon", role = "Eye", attrs = energy(glow) })
	local crown = {
		tube({ V(0, 13.3, -1.3), V(0, 15.5, -1.25), V(0, 17.9, -0.9) }, 0.55, 0.05, { seg = 6, flat = true, capEnd = 0.4 }),
		tube({ V(-1.7, 12.2, -1.0), V(-0.2, 12.9, -1.9), V(1.7, 12.2, -1.0) }, 0.22, 0.22, { seg = 5 }),
	}
	for _, s in ipairs({ -1, 1 }) do
		table.insert(crown, tube({ V(s * 1.15, 13.4, -0.6), V(s * 2.6, 14.6, -0.3), V(s * 3.5, 16.4, 0), V(s * 3.0, 18.3, 0.3) }, 0.42, 0.05, { seg = 6, flat = true, capEnd = 0.3 }))
		table.insert(crown, tube({ V(s * 1.7, 12.6, 0), V(s * 3.0, 13.3, 0.3), V(s * 4.2, 14.4, 0.6) }, 0.32, 0.04, { seg = 5, flat = true, capEnd = 0.2 }))
		table.insert(crown, tube({ V(s * 0.7, 13.8, -0.9), V(s * 1.0, 15.4, -0.7) }, 0.25, 0.04, { seg = 5, flat = true, capEnd = 0.2 }))
		table.insert(crown, tube({ V(s * 1.75, 12.8, -1.2), V(s * 1.55, 11.2, -1.75), V(s * 0.55, 10.3, -2.05) }, 0.17, 0.14, { seg = 5 })) -- guarda da face
	end
	part(bp, "Crown", "Head", nil, hp, shade(merge(crown), function(p)
		return gold:Lerp(rgb(255, 230, 150), math.clamp((p.Y - 13) / 5, 0, 1))
	end), { material = "Metal", role = "Accent", reflectance = 0.15 })
	local halo = { ring(V(0, 0, 0), 5.4, 0.3, 28, 0, glow) }
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local d = V(math.cos(a), 0, math.sin(a))
		table.insert(halo, spike(d * 5.5, d + V(0, 0.4, 0), 1.0, 0.18, purple, { seg = 4 }))
	end
	local haloP = V(0, 14.0, 0.8)
	part(bp, "OrbitHalo", "Head", "OrbitHalo", haloP, MeshKit.transform(merge(halo), CFrame.new(haloP) * CFrame.Angles(rad(-14), 0, 0)), { material = "Neon", role = "Glow" })

	-- BRAÇOS: ombreiras em camadas com espinhos e cristal, braço armado, manopla com garras douradas
	for _, s in ipairs({ -1, 1 }) do
		local t = s < 0 and "L" or "R"
		local ap = V(s * 5.6, 8.2, 0)
		local arm = {
			L({ { p = V(s * 5.9, 7.4, 0), w = 2.5, h = 2.4 }, { p = V(s * 6.1, 9.0, 0), w = 2.6, h = 2.5 } }, { seg = 14, steps = 2, up = FWD, pow = 2.2, flat = true, capStart = 0.4, capEnd = 1.5, lowSeg = 0.6 }),
			L({ { p = V(s * 6.3, 7.3, 0), w = 2.75, h = 2.65 }, { p = V(s * 6.3, 6.7, 0), w = 2.6, h = 2.5 } }, { seg = 14, steps = 1, up = FWD, pow = 2.2, flat = true, capStart = 0.1, capEnd = 0.1, capRings = 0, lowSeg = 0.6 }),
			L({ { p = V(s * 6.4, 6.4, 0), w = 2.5, h = 2.4 }, { p = V(s * 6.5, 5.8, 0), w = 2.3, h = 2.2 } }, { seg = 14, steps = 1, up = FWD, pow = 2.2, flat = true, capStart = 0.1, capEnd = 0.1, capRings = 0, lowSeg = 0.6 }),
			tube({ V(s * 6.1, 7.0, 0), V(s * 6.4, 4.4, -0.1) }, 0.95, 0.9, { seg = 10, up = FWD, flat = true }),
			L({ { p = V(s * 6.45, 4.6, 0.5), w = 1.1, h = 0.9 }, { p = V(s * 6.45, 4.0, -0.9), w = 1.0, h = 0.7 } }, { seg = 8, steps = 1, pow = 2.5, flat = true, capStart = 0.4, capEnd = 0.5 }),
			tube({ V(s * 6.5, 4.0, -0.3), V(s * 6.7, 1.6, -0.7), V(s * 6.8, 0.0, -1.0) }, 1.0, 1.3, { seg = 10, up = FWD, flat = true }),
			L({ { p = V(s * 6.8, -0.2, -1.0), w = 1.25, h = 1.0 }, { p = V(s * 6.8, -1.4, -1.2), w = 1.15, h = 0.95 } }, { seg = 10, steps = 1, up = FWD, pow = 2.4, flat = true, capStart = 0.2, capEnd = 0.5 }),
		}
		part(bp, "Arm" .. t, "Torso", "Arm" .. t, ap, armorize(merge(arm)), { material = "Metal", reflectance = 0.05 })
		local g = {
			ring(V(s * 6.3, 7.0, 0), 2.6, 0.16, 18, 0, gold),
			ring(V(s * 6.7, 0.6, -0.8), 1.3, 0.16, 14, 0, gold),
		}
		for k = 1, 3 do
			table.insert(g, spike(V(s * (6.2 + k * 0.55), 9.6 - k * 0.15, (k - 2) * 1.2), V(s * (0.5 + k * 0.25), 1, 0), 2.6 - k * 0.3, 0.38, gold, { flat = true }))
		end
		for k = 0, 3 do
			local x = s * 6.8 + (k - 1.5) * 0.55
			table.insert(g, tube({ V(x, -1.3, -1.9), V(x, -2.3, -2.3), V(x + s * 0.1, -3.2, -1.9) }, 0.2, 0.06, { seg = 5, capEnd = 0.2 }))
		end
		part(bp, "Gold" .. t, "Arm" .. t, nil, ap, merge(g), { material = "Metal", role = "Accent", reflectance = 0.15 })
		part(bp, "ArmCrystal" .. t, "Arm" .. t, nil, ap, merge({ crystal(V(s * 6.4, 10.0, 1.0), V(s * 0.3, 1, 0.45), 3.6, 0.95, purple), crystal(V(s * 7.4, 9.4, 1.4), V(s * 0.8, 0.8, 0.5), 2.2, 0.6, glow) }),
			{ material = "Neon", role = "Glow" })
	end

	-- CRISTAIS EM ÓRBITA (giram em volta do corpo): vidro roxo com núcleo luminoso
	local op = V(0, 4, 0)
	local oc, ok = {}, {}
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local c = op + V(math.cos(a) * 10.5, math.sin(i * 1.7) * 2.5, math.sin(a) * 10.5)
		local d = V(0, 1, 0) + V(math.cos(a), 0, math.sin(a)) * 0.25 * (i % 2 == 0 and 1 or -1)
		local len = 3.2 + (i % 3) * 0.8
		table.insert(oc, crystal(c - d.Unit * len * 0.5, d, len, 0.85, purple, { both = true }))
		table.insert(ok, crystalCore(c - d.Unit * len * 0.5, d, len, 0.85, glow))
	end
	part(bp, "Orbit", "Torso", "Orbit", op, merge(oc), { material = "Glass", role = "Accent", transparency = 0.2 })
	part(bp, "OrbitCores", "Orbit", nil, op, merge(ok), { material = "Neon", role = "Glow" })
end

local BUILDERS = { elderroot = elderroot, prism_titan = prismTitan, tempest_wyrm = tempestWyrm, wilderbloom = wilderbloom, void_sovereign = voidSovereign }

-- Planta do boss. opts.low = resolução do modo de peças.
function BossAnatomy.blueprint(id: string, opts)
	local fn = BUILDERS[id]
	assert(fn, "sem planta de boss: " .. tostring(id))
	local bp = { anatomy = "boss", kind = "boss", boss = id, parts = {}, byName = {}, effects = {}, hover = BossAnatomy.Hover[id], gait = "boss", scale = 1, tier = 1 }
	LOW = opts ~= nil and opts.low == true
	local ok, err = pcall(fn, bp)
	LOW = false
	if not ok then
		error(err, 0)
	end
	bp.flies = id == "tempest_wyrm"
	return bp
end

function BossAnatomy.has(id: string): boolean
	return BUILDERS[id] ~= nil
end

return BossAnatomy

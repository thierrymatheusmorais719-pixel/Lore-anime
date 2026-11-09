-- Anatomia dos pets: plantas de corpo por tipo de animal (canídeo, felino, cervídeo, caprino, lebre, roedor,
-- mustelídeo, urso, javali/mamute, réptil/dragão, ave, morcego, mariposa, serpente, besouro, sapo, tartaruga e
-- criaturas mágicas originais), feitas de MALHAS CONTÍNUAS (MeshKit), nunca de bolinhas.
--
-- Cada parte do corpo é uma malha própria com pivô na articulação real (ombro, cotovelo, joelho, tornozelo,
-- quadril, pescoço, mandíbula, base da orelha, base da cauda...), para o Animator mexer como esqueleto.
-- Saída: uma "planta" (blueprint) = lista de partes { name, parent, joint, pivot, geom, material, role }.
-- Tudo é calculado em "unidades" e escalado no final pelo tamanho da espécie.
--
-- Raridade muda a aparência (PetAnatomy.decorate): marcas no pelo, pelagem mais cheia, marcas que brilham,
-- ornamentos de ouro, partes etéreas, coroas e partículas — não só uma aura.

local MeshKit = require(script.Parent.MeshKit)

local PetAnatomy = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local rad = math.rad
local loft, merge, sheet = MeshKit.loft, MeshKit.merge, MeshKit.sheet

PetAnatomy.RarityTier = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7, Celestial = 8 }

local function darker(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function lum(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function hash(x: number, y: number, z: number): number
	local n = math.sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453
	return n - math.floor(n)
end

-------------------------------------------------------------------------------
-- Planta (blueprint)
-------------------------------------------------------------------------------

local function newBP(anatomy: string)
	return { anatomy = anatomy, parts = {}, byName = {}, effects = {}, hover = 1, gait = "quad" }
end

-- joint = nome do Motor6D (o Animator anima pelo nome); nil = preso fixo ao pai.
local function addPart(bp, name: string, parent: string?, joint: string?, pivot: Vector3, geom, opts)
	opts = opts or {}
	local p = {
		name = name, parent = parent, joint = joint, pivot = pivot, geom = geom, material = opts.material or "Fabric", role = opts.role or "Body",
		transparency = opts.transparency or 0, reflectance = opts.reflectance or 0, attrs = opts.attrs,
	}
	table.insert(bp.parts, p)
	bp.byName[name] = p
	return p
end
PetAnatomy.addPart = addPart

-------------------------------------------------------------------------------
-- Cores
-------------------------------------------------------------------------------

local function palette(m, tier: number)
	local body = m.body or rgb(170, 150, 130)
	local belly = m.belly or body:Lerp(WHITE, 0.45)
	local accent = m.accent or body
	local light = lum(body) > 0.62
	local P = {
		body = body, belly = belly, accent = accent, tier = tier,
		dorsal = darker(body, light and 0.82 or 0.7), deep = darker(body, 0.45),
		inner = belly:Lerp(rgb(236, 150, 160), 0.5), nose = light and rgb(176, 104, 116) or rgb(34, 28, 32),
		claw = rgb(58, 50, 48), horn = m.antler or rgb(214, 196, 160), hoof = rgb(52, 44, 40),
		glowEyes = m.glowEyes == true, glassy = m.glassy == true,
	}
	if m.glowEyes then
		P.iris = m.eye or accent
	elseif m.eye and lum(m.eye) > 0.22 then
		P.iris = m.eye
	else
		P.iris = rgb(150, 98, 42):Lerp(accent, 0.2)
	end
	-- Incomum+: meias/focinho claros; Raro+: pontas de orelha e cauda escuras
	P.sock = tier >= 2 and (m.sock or belly:Lerp(WHITE, 0.2)) or nil
	P.tips = tier >= 3 and darker(accent:Lerp(body, 0.5), 0.55) or nil
	if tier >= 7 then
		P.stars = true -- Secret/Celestial: pelagem salpicada de estrelas
	end
	return P
end
PetAnatomy.palette = palette

-- Cor de pelo por vértice: dorso mais escuro, barriga clara, pontas/raízes, listras, pintas, estrelas.
local function furFn(P, o)
	o = o or {}
	local off = o.at or Vector3.zero
	local base = o.base or P.body
	return function(t: number, _ex: number, ey: number, p: Vector3)
		local w = p + off
		local c = base
		if o.shade ~= false then
			if ey > 0.3 then
				c = c:Lerp(o.dorsal or P.dorsal, math.min(1, (ey - 0.3) / 0.7) * 0.8)
			elseif ey < -0.15 then
				c = c:Lerp(o.belly or P.belly, math.min(1, (-ey - 0.15) / 0.45))
			end
		end
		if o.tip and t > o.tipFrom then
			c = c:Lerp(o.tip, math.min(1, (t - o.tipFrom) / math.max(0.05, 1 - o.tipFrom) * 1.4))
		end
		if o.root and t < o.rootTo then
			c = c:Lerp(o.root, 1 - t / o.rootTo)
		end
		if o.pattern ~= false then
			if P.stripes then
				local sv = math.sin(w.Z * P.stripes + math.sin(w.Y * 3 + w.X * 2) * 0.9)
				if sv > 0.6 and ey > -0.4 then
					c = c:Lerp(P.stripeColor, 0.88)
				end
			end
			if P.spots then
				local q = 2.4
				if hash(math.floor(w.X * q), math.floor(w.Y * q), math.floor(w.Z * q)) > 0.78 and ey > -0.3 then
					c = c:Lerp(P.spotColor, 0.75)
				end
			end
			if P.stars and hash(math.floor(w.X * 6), math.floor(w.Y * 6), math.floor(w.Z * 6)) > 0.93 then
				c = c:Lerp(WHITE, 0.85)
			end
		end
		return c
	end
end
PetAnatomy.furFn = furFn

local function solid(c: Color3)
	return function()
		return c
	end
end

-- Está dentro do volume de um loft (aproximação pela seção interpolada ao longo de Z)?
local function insideKeys(keys, q: Vector3): boolean
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		local z0, z1 = a.p.Z, b.p.Z
		if (q.Z - z0) * (q.Z - z1) <= 0 and z0 ~= z1 then
			local f = (q.Z - z0) / (z1 - z0)
			local w = a.w + (b.w - a.w) * f
			local yc = a.p.Y + (b.p.Y - a.p.Y) * f
			local hu = (a.h or a.w) + ((b.h or b.w) - (a.h or a.w)) * f
			local hd = (a.hb or a.h or a.w) + ((b.hb or b.h or b.w) - (a.hb or a.h or a.w)) * f
			local hh = q.Y >= yc and hu or hd
			return (q.X / w) ^ 2 + ((q.Y - yc) / hh) ^ 2 < 1
		end
	end
	return false
end

-- Raio contra a malha (Möller–Trumbore): menor distância de acerto ou nil.
local function rayGeom(g, origin: Vector3, dir: Vector3): number?
	local best
	for _, t in ipairs(g.tris) do
		local a, b, c = g.verts[t[1]], g.verts[t[2]], g.verts[t[3]]
		local e1, e2 = b - a, c - a
		local pv = dir:Cross(e2)
		local det = e1:Dot(pv)
		if math.abs(det) > 1e-9 then
			local inv = 1 / det
			local tv = origin - a
			local u = tv:Dot(pv) * inv
			if u >= 0 and u <= 1 then
				local qv = tv:Cross(e1)
				local v = dir:Dot(qv) * inv
				if v >= 0 and u + v <= 1 then
					local d = e2:Dot(qv) * inv
					if d > 0 and (not best or d < best) then
						best = d
					end
				end
			end
		end
	end
	return best
end

-- Encaixa o olho na superfície REAL da cabeça (raio contra a malha), um pouco para dentro.
local function seatOnMesh(g, c: Vector3, n: Vector3, r: number): Vector3?
	local d = n.Unit
	local origin = c + d * 2
	local hit = rayGeom(g, origin, -d)
	if not hit then
		return nil
	end
	return origin - d * hit - d * r * 0.38
end

-- Leva o olho até a superfície da cabeça (na direção do olhar) e o encaixa um pouco para dentro.
local function seatEye(keys, c: Vector3, n: Vector3, r: number): Vector3
	local d = n.Unit
	local q = c - d * 0.3
	for _ = 1, 80 do
		if not insideKeys(keys, q) then
			break
		end
		q += d * 0.01
	end
	return q - d * r * 0.42
end

-------------------------------------------------------------------------------
-- Órgãos
-------------------------------------------------------------------------------

-- Olho integrado ao rosto: lente em domo com íris, pupila (redonda ou em fenda), contorno escuro e brilho.
-- Detalhes que só somem no modo de peças LEVE (na "Alta qualidade" do modo de peças eles ficam).
local function lowDetail(): boolean
	return MeshKit.low and not MeshKit.mid
end

local function eyeGeom(P, c: Vector3, n: Vector3, r: number, o)
	o = o or {}
	n = n.Unit
	local right = n:Cross(V(0, 1, 0))
	if right.Magnitude < 1e-3 then
		right = V(1, 0, 0)
	end
	right = right.Unit
	local upv = right:Cross(n).Unit
	local iris = o.iris or P.iris
	local glow = o.glow or P.glowEyes
	if MeshKit.low then
		-- Modo de peças: cada triângulo tem UMA cor (a média dos vértices), então o degradê de íris/pupila
		-- some num borrão escuro. Aqui o olho é feito em camadas de cor sólida (globo, íris, pupila e dois
		-- brilhos), como um ADESIVO: cada vértice é projetado na superfície real da cabeça (`o.surface`) e
		-- levantado um pouco por camada. Discos planos atravessavam a cabeça curva (a borda entrava de um
		-- lado e saía do outro); assim o olho acompanha a curva e nunca fura a cabeça.
		local surf = o.surface
		local R = r * (surf and 1.15 or 1.3)
		if not surf then
			c = c + n * r * 0.32 -- sem a malha da cabeça (olhos em posição fixa): disco um pouco para fora
		end
		local tall = o.tall or 1
		local step = math.max(0.012, r * 0.14) -- altura de cada camada acima da anterior
		local function onSurface(q: Vector3, lift: number): Vector3?
			if not surf then
				return q + n * lift
			end
			local origin = q + n * r * 3
			local t = rayGeom(surf, origin, -n)
			if t and t < r * 7 then
				return origin - n * t + n * lift
			end
			return nil
		end
		local function lens(center: Vector3, w: number, h: number, layer: number, col: Color3, segs: number)
			local lift = step * layer
			local mid = onSurface(center, lift + step * 0.25)
			if not mid then
				return nil
			end
			local verts, colors, tris = { mid }, { col }, {}
			for k = 0, segs - 1 do
				local a = k / segs * math.pi * 2
				local off = right * math.cos(a) * w + upv * math.sin(a) * h
				-- na borda da silhueta o raio pode passar fora da cabeça: encolhe o ponto até cair nela
				local q
				for _, f in ipairs({ 1, 0.85, 0.7, 0.55, 0.4 }) do
					q = onSurface(center + off * f, lift)
					if q then
						break
					end
				end
				table.insert(verts, q or mid)
				table.insert(colors, col)
			end
			for k = 1, segs do
				table.insert(tris, { 1, 1 + k, 1 + (k % segs) + 1 })
			end
			return { verts = verts, colors = colors, tris = tris, flat = true }
		end
		local layers = { lens(c, R, R * tall, 1, o.sclera or iris:Lerp(BLACK, 0.72), 10) }
		local irisCol = glow and iris:Lerp(WHITE, 0.3) or iris:Lerp(WHITE, 0.1)
		table.insert(layers, lens(c, R * 0.8, R * 0.8 * tall, 2, irisCol, 10))
		local pupilCol = glow and iris:Lerp(BLACK, 0.55) or rgb(10, 8, 12)
		if o.slit then
			table.insert(layers, lens(c, R * 0.17, R * 0.64 * tall, 3, pupilCol, 6))
		else
			table.insert(layers, lens(c, R * 0.42, R * 0.42 * tall, 3, pupilCol, 8))
		end
		table.insert(layers, lens(c + upv * R * 0.32 - right * R * 0.22, R * 0.2, R * 0.17, 4, WHITE, 5))
		table.insert(layers, lens(c - upv * R * 0.28 + right * R * 0.3, R * 0.09, R * 0.08, 4, WHITE, 4))
		-- bochecha rosada (pets fofos): oval logo abaixo do olho, colada na cabeça como o olho
		if P.blush and not glow and surf then
			table.insert(layers, lens(c - upv * R * 1.3, R * 0.62, R * 0.34, 1, P.body:Lerp(WHITE, 0.35):Lerp(rgb(255, 140, 165), 0.72), 8))
		end
		local ok = {}
		for _, g in ipairs(layers) do
			if g then
				table.insert(ok, g)
			end
		end
		return merge(ok)
	end
	local eye = loft({ { p = c - n * r * 0.5, w = r, h = r * (o.tall or 1) }, { p = c, w = r, h = r * (o.tall or 1) } }, {
		seg = 14, steps = 1, up = upv, capStart = 0, capEnd = r * 0.34, capRings = 4, detail = true,
		color = function(_t, _ex, _ey, p)
			local d = p - c
			local along = d:Dot(n)
			local lx, ly = d:Dot(right) / r, d:Dot(upv) / r
			local radial = math.sqrt(lx * lx + ly * ly)
			if along < -r * 0.05 then
				return o.rim or rgb(20, 16, 20)
			end
			local pupil = (o.slit and math.abs(lx) < 0.17 and math.abs(ly) < 0.64) or (not o.slit and radial < 0.38)
			if pupil then
				return glow and iris:Lerp(BLACK, 0.6) or rgb(10, 8, 12)
			end
			if radial < 0.84 then
				return iris:Lerp(WHITE, glow and 0.35 or 0.12):Lerp(iris:Lerp(BLACK, 0.4), math.clamp((radial - 0.38) / 0.46, 0, 1))
			end
			return o.sclera or iris:Lerp(BLACK, 0.72)
		end,
	})
	local shineP = c + n * r * 0.3 + upv * r * 0.36 - right * r * 0.22
	local shine = loft({ { p = shineP - n * r * 0.05, w = r * 0.16, h = r * 0.13 }, { p = shineP + n * r * 0.04, w = r * 0.16, h = r * 0.13 } },
		{ seg = 8, steps = 1, up = upv, capStart = 0, capEnd = r * 0.05, color = solid(WHITE) })
	return merge({ eye, shine })
end
PetAnatomy.eyeGeom = eyeGeom

-- Pálpebra (some dentro da cabeça; o Animator desliza para fechar). Devolve geometria e o vetor de piscar.
local function lidGeom(P, c: Vector3, n: Vector3, r: number, color: Color3?)
	n = n.Unit
	local hide = V(0, r * 1.25, 0) - n * r * 1.25
	local g = loft({ { p = c + hide - n * r * 0.4, w = r * 1.18, h = r * 1.1 }, { p = c + hide + n * r * 0.1, w = r * 1.18, h = r * 1.1 } },
		{ seg = 12, steps = 1, up = V(0, 1, 0), capStart = 0, capEnd = r * 0.42, color = solid(color or P.body) })
	return g, -hide
end

-- Orelhas (geometria no referencial da base da orelha; side = -1 esquerda, 1 direita).
local function earGeom(P, kind: string, size: number, side: number)
	local s = size
	local fwd = V(0, 0, -1)
	local tipCol = P.tips or P.deep
	local function earLoft(tip: Vector3, wBase: number, thick: number, pow: number?)
		local outer = loft({ { p = V(0, -0.06 * s, 0), w = wBase, h = thick }, { p = tip * 0.5, w = wBase * 0.82, h = thick * 0.85 }, { p = tip, w = wBase * 0.12, h = thick * 0.4 } },
			{ seg = 10, steps = 3, up = fwd, capStart = 0, capEnd = wBase * 0.15, pow = pow, color = furFn(P, { shade = false, tip = tipCol, tipFrom = 0.7, pattern = false }) })
		local inner = loft({ { p = V(0, 0.02 * s, -thick * 0.55), w = wBase * 0.6, h = thick * 0.35 }, { p = tip * 0.5 + V(0, 0, -thick * 0.5), w = wBase * 0.5, h = thick * 0.3 },
			{ p = tip * 0.85 + V(0, 0, -thick * 0.4), w = wBase * 0.1, h = thick * 0.2 } }, { seg = 8, steps = 3, up = fwd, capStart = 0, capEnd = 0.01, color = solid(P.inner) })
		if lowDetail() then
			return outer
		end
		return merge({ outer, inner })
	end
	if kind == "round" or kind == "mouse" then
		local big = kind == "mouse" and 1.5 or 1
		return earLoft(V(side * 0.08 * s, 0.42 * s * big, 0.02 * s), 0.3 * s * big, 0.07 * s, 2)
	elseif kind == "long" then
		return earLoft(V(side * 0.1 * s, 1.15 * s, 0.12 * s), 0.17 * s, 0.06 * s)
	elseif kind == "floppy" then
		return earLoft(V(side * 0.5 * s, -0.25 * s, 0.05 * s), 0.16 * s, 0.05 * s)
	elseif kind == "tufted" then
		local e = earLoft(V(side * 0.07 * s, 0.62 * s, 0.04 * s), 0.22 * s, 0.07 * s)
		local tuft = loft({ { p = V(side * 0.07 * s, 0.6 * s, 0.04 * s), w = 0.04 * s, h = 0.02 * s }, { p = V(side * 0.09 * s, 0.9 * s, 0.06 * s), w = 0.01 * s, h = 0.01 * s } },
			{ seg = 5, steps = 1, up = fwd, color = solid(darker(P.body, 0.3)) })
		return merge({ e, tuft })
	elseif kind == "leafy" then
		return MeshKit.paint(earLoft(V(side * 0.18 * s, 0.75 * s, 0.05 * s), 0.2 * s, 0.035 * s), function(v)
			return P.accent:Lerp(darker(P.accent, 0.7), math.clamp(v.Y / (0.8 * s), 0, 1))
		end)
	elseif kind == "crystal" then
		return loft({ { p = V(0, 0, 0), w = 0.2 * s, h = 0.12 * s, pow = 1.2 }, { p = V(side * 0.08 * s, 0.68 * s, 0.03 * s), w = 0.02 * s, h = 0.02 * s, pow = 1.2 } },
			{ seg = 4, steps = 1, up = fwd, capStart = 0, capEnd = 0.01, flat = true, color = solid(P.accent) })
	elseif kind == "feelers" then
		local stalk = loft({ { p = V(0, 0, 0), w = 0.035 * s, h = 0.035 * s }, { p = V(side * 0.25 * s, 0.5 * s, -0.25 * s), w = 0.025 * s }, { p = V(side * 0.35 * s, 0.75 * s, -0.5 * s), w = 0.02 * s } },
			{ seg = 6, steps = 3, up = fwd, color = solid(P.deep) })
		local tip = loft({ { p = V(side * 0.35 * s, 0.75 * s, -0.5 * s), w = 0.07 * s }, { p = V(side * 0.37 * s, 0.8 * s, -0.58 * s), w = 0.07 * s } },
			{ seg = 8, steps = 1, up = fwd, color = solid(P.accent) })
		return merge({ stalk, tip })
	end
	-- pointy (padrão)
	return earLoft(V(side * 0.1 * s, 0.6 * s, 0.05 * s), 0.24 * s, 0.07 * s)
end

-- Chifres/galhadas (geometria presa à cabeça; base em `at`, lado `side`).
local function hornGeom(P, kind: string, at: Vector3, side: number, s: number)
	local col = P.horn
	if kind == "antlers" or kind == "grand" or kind == "crystalAntlers" then
		local big = kind == "grand" and 1.5 or 1
		local crystal = kind == "crystalAntlers"
		local c = crystal and P.accent or col
		local function beam(a: Vector3, b: Vector3, r0: number, r1: number)
			return loft({ { p = a, w = r0, h = r0 }, { p = (a + b) / 2 + V(0, 0.04 * s, 0), w = (r0 + r1) / 2 }, { p = b, w = r1, h = r1 } },
				{ seg = crystal and 5 or 7, steps = 2, capEnd = r1 * 0.6, flat = crystal, color = function(t)
					return c:Lerp(c:Lerp(WHITE, 0.35), t)
				end })
		end
		local list = {}
		local b0 = at
		local b1 = at + V(side * 0.32, 0.55, 0.12) * s * big
		local b2 = b1 + V(side * 0.18, 0.5, 0.18) * s * big
		table.insert(list, beam(b0, b1, 0.07 * s, 0.055 * s))
		table.insert(list, beam(b1, b2, 0.055 * s, 0.03 * s))
		table.insert(list, beam(b1 - V(0, 0.15, 0) * s, b1 + V(side * 0.05, 0.35, -0.3) * s * big, 0.04 * s, 0.02 * s))
		table.insert(list, beam(b2 - V(0, 0.1, 0) * s, b2 + V(side * 0.32, 0.12, -0.05) * s * big, 0.035 * s, 0.018 * s))
		table.insert(list, beam(b2, b2 + V(-side * 0.05, 0.35, 0.1) * s * big, 0.03 * s, 0.015 * s))
		if kind == "grand" then
			table.insert(list, beam(b1, b1 + V(side * 0.45, 0.2, 0.25) * s * big, 0.04 * s, 0.02 * s))
		end
		return merge(list), crystal
	elseif kind == "curled" then
		-- chifre de carneiro: espiral que sai para trás e enrola para a frente
		local keys = {}
		for i = 0, 8 do
			local a = i / 8 * math.pi * 1.5
			local rr = (0.32 - i * 0.012) * s
			table.insert(keys, { p = at + V(side * (0.05 + i * 0.035) * s, math.sin(a) * rr + 0.05 * s, math.cos(a) * rr - rr * 0.6 + 0.12 * s), w = (0.1 - i * 0.009) * s })
		end
		return loft(keys, { seg = 8, steps = 2, color = function(t, ex, ey)
			local ridge = math.sin(t * 40) > 0.3 and 0.82 or 1
			return darker(col, ridge)
		end })
	elseif kind == "nubs" then
		return loft({ { p = at, w = 0.07 * s }, { p = at + V(side * 0.04, 0.18, 0.06) * s, w = 0.035 * s } }, { seg = 7, steps = 2, capEnd = 0.03 * s, color = solid(col) })
	elseif kind == "crystal" then
		return loft({ { p = at, w = 0.09 * s, h = 0.07 * s, pow = 1.2 }, { p = at + V(side * 0.12, 0.5, 0.25) * s, w = 0.012 * s, pow = 1.2 } },
			{ seg = 4, steps = 2, capEnd = 0.01, flat = true, color = solid(P.accent) }), true
	elseif kind == "straight" then
		return loft({ { p = at, w = 0.07 * s }, { p = at + V(side * 0.08, 0.4, 0.2) * s, w = 0.045 * s }, { p = at + V(side * 0.06, 0.7, 0.45) * s, w = 0.012 * s } },
			{ seg = 7, steps = 3, capEnd = 0.01, color = function(t)
				return col:Lerp(darker(col, 0.5), t)
			end })
	end
	return nil
end

-------------------------------------------------------------------------------
-- Cabeça de mamífero (crânio + focinho + mandíbula + nariz + bochechas)
-------------------------------------------------------------------------------

--[[ H = { len, w, h, mLen, mW, mH, stop, eyeX, eyeY, eyeZ, eyeR, eyeFwd, slit, ruff, beard, wide, round }
	Devolve { head, face (olhos/nariz brilhosos), jaw, jawPivot, eyes = { {c, n, r} }, earAt, hornAt, topY } no referencial da cabeça ]]
local function mammalHead(P, H)
	local L, w, h = H.len, H.w, H.h
	local mL, mW, mH = H.mLen, H.mW, H.mH
	local st = H.stop or 0.06
	local zM = -L * 0.5 -- início do focinho
	local headCol = furFn(P, { shade = true, pattern = H.pattern })
	local mask = P.sock and (H.mask ~= false) and P.belly:Lerp(WHITE, 0.15) or nil
	local keys = {
		{ p = V(0, 0.02, L * 0.42), w = w * 0.62, h = h * 0.6, hb = h * 0.55 },
		{ p = V(0, 0.06, L * 0.12), w = w, h = h * (H.round and 1.05 or 0.95), hb = h * 0.85 },
		{ p = V(0, 0.03, -L * 0.22), w = w * 0.92, h = h * 0.82, hb = h * 0.8 },
		{ p = V(0, -st * 0.6, zM), w = mW * 1.35 + w * 0.15, h = mH * 1.15, hb = mH * 1.05 },
		{ p = V(0, -st - 0.02, zM - mL * 0.55), w = mW * 1.05, h = mH * 0.95, hb = mH * 0.9 },
		{ p = V(0, -st - 0.03, zM - mL), w = mW * 0.78, h = mH * 0.72, hb = mH * 0.7 },
	}
	local head = loft(keys, { seg = 16, steps = 4, pow = 2.1, capEnd = mW * 0.5, capStart = w * 0.55, color = function(t, ex, ey, p)
		local c = headCol(t, ex, ey, p)
		-- focinho e queixo claros; máscara (Incomum+) em volta dos olhos/focinho
		if p.Z < zM * 0.9 and ey < 0.1 then
			c = c:Lerp(P.belly, 0.75)
		end
		if mask and p.Z < zM * 0.4 and p.Z > zM - mL * 0.8 and ey > -0.2 and ey < 0.5 then
			c = c:Lerp(mask, 0.5)
		end
		return c
	end })
	local list = { head }
	-- bochechas (volume nas laterais, tufos se `ruff`); no modo de peças ficam de fora
	for _, side in ipairs(lowDetail() and {} or { -1, 1 }) do
		local cz = -L * 0.12
		table.insert(list, loft({ { p = V(side * w * 0.45, -h * 0.25, cz + L * 0.15), w = w * 0.38, h = h * 0.42, jag = H.ruff and 0.25 or 0 },
			{ p = V(side * w * (H.ruff and 0.9 or 0.62), -h * 0.38, cz - L * 0.12), w = w * 0.3, h = h * 0.34, jag = H.ruff and 0.3 or 0 } },
			{ seg = 10, steps = 2, color = function(t, ex, ey, p)
				return P.body:Lerp(P.belly, 0.4 + t * 0.3)
			end }))
	end
	if H.beard then
		table.insert(list, loft({ { p = V(0, -mH * 1.0, zM - mL * 0.4), w = mW * 0.45, h = mW * 0.3 }, { p = V(0, -mH * 1.0 - 0.38, zM - mL * 0.25), w = mW * 0.15, h = mW * 0.1 } },
			{ seg = 8, steps = 2, color = solid(P.belly:Lerp(WHITE, 0.3)), up = V(0, 0, -1) }))
	end
	-- mandíbula (junta "Jaw" na dobradiça, abaixo das bochechas)
	local jawPivot = V(0, -h * 0.55, -L * 0.18)
	local jawLen = (L * 0.5 - 0.18 * L) + mL * 0.92
	local jaw = loft({ { p = V(0, 0, 0.05), w = w * 0.55, h = h * 0.25, hb = h * 0.28 }, { p = V(0, -0.02, -jawLen * 0.55), w = mW * 0.95, h = mH * 0.38, hb = mH * 0.45 },
		{ p = V(0, 0.02, -jawLen), w = mW * 0.62, h = mH * 0.3, hb = mH * 0.35 } }, { seg = 12, steps = 3, capEnd = mW * 0.3, color = function(t, ex, ey)
		return ey > 0.55 and rgb(150, 70, 80) or P.belly -- boca rosada por dentro
	end })
	-- nariz e olhos (peça brilhosa)
	local tip = V(0, -st - 0.03 + mH * 0.25, zM - mL - mW * 0.42)
	local nose = loft({ { p = tip + V(0, 0, 0.08), w = mW * 0.48, h = mH * 0.36 }, { p = tip, w = mW * 0.42, h = mH * 0.3 } },
		{ seg = 10, steps = 1, capEnd = mW * 0.18, capStart = 0, color = solid(H.noseColor or P.nose) })
	local face = { nose }
	local eyes = {}
	local browCol = furFn(P, { shade = false, base = P.dorsal })
	local skull = merge(list)
	for _, side in ipairs({ -1, 1 }) do
		local n = V(side * (1 - H.eyeFwd), 0.12, -H.eyeFwd * 1.2)
		local target = V(side * H.eyeX, H.eyeY, H.eyeZ)
		local c = seatOnMesh(skull, target, n, H.eyeR) or seatEye(keys, target, n, H.eyeR)
		local r = H.eyeR
		-- sobrancelha logo acima do olho (não cobre o olho)
		local b0 = c + V(-side * r * 0.9, r * 1.55, r * 0.6)
		local b1 = c + V(side * r * 0.75, r * 1.25, -r * 0.1)
		-- (no modo de peças o olho é maior e fica por cima: sobrancelha só nas malhas suaves)
		if not MeshKit.low then
			table.insert(list, loft({ { p = b0, w = r * 0.62, h = r * 0.34 }, { p = b1, w = r * 0.45, h = r * 0.26 } }, { seg = 8, steps = 2, capStart = r * 0.3, capEnd = r * 0.25, color = browCol }))
		end
		table.insert(face, eyeGeom(P, c, n, H.eyeR, { slit = H.slit, tall = H.eyeTall, surface = skull }))
		table.insert(eyes, { c = c, n = n.Unit, r = H.eyeR })
	end
	return {
		head = merge(list), face = merge(face), jaw = jaw, jawPivot = jawPivot, eyes = eyes,
		earAt = V(w * 0.55, h * 0.62, L * 0.12), hornAt = V(w * 0.4, h * 0.75, -L * 0.02), topY = h * 0.95,
	}
end
do
	-- na "Alta qualidade" do modo de peças a cabeça ganha mais faces (é o que mais se olha)
	local build = mammalHead
	mammalHead = function(...)
		MeshKit.focus = MeshKit.mid
		local r = build(...)
		MeshKit.focus = false
		return r
	end
end
PetAnatomy.mammalHead = mammalHead

-------------------------------------------------------------------------------
-- Membros (pernas em 3 partes com pivô no ombro/quadril, joelho/cotovelo e tornozelo/pulso)
-------------------------------------------------------------------------------

local FWD = V(0, 0, -1) -- referência "frente" para lofts verticais (pernas, orelhas)

--[[ o = { len (pivô→chão), t (meia-espessura), hind, digi, fold, splay, foot = "paw"|"hoof"|"pad"|"claw"|"web", side, sock }
	Devolve { upper, lower, foot, knee, ankle } (knee/ankle relativos ao pivô anterior) ]]
local function legGeoms(P, o)
	local len, t, side = o.len, o.t, o.side or 1
	local knee, ankle, footH
	local sx = o.splay and side * len * 0.22 or 0
	if o.fold then
		knee = V(sx, -len * 0.3, -len * 0.28)
		ankle = V(sx * 0.2, -len * 0.33, len * 0.5)
		footH = len * 0.37
	elseif o.hind and o.digi then
		knee = V(sx, -len * 0.34, -len * 0.14)
		ankle = V(sx * 0.2, -len * 0.36, len * 0.24)
		footH = len * 0.3
	else
		knee = V(sx, -len * 0.46, o.hind and 0.02 or -0.02)
		ankle = V(sx * 0.2, -len * 0.4, o.hind and -0.02 or 0.03)
		footH = len * 0.14
	end
	local fur = furFn(P, { shade = false, pattern = true })
	local thick = o.hind and 1.35 or 1
	local up = o.fold and 1.6 or 1
	local upper = loft({ { p = V(0, t * 0.9, o.hind and 0.05 or 0), w = t * 1.3 * thick, h = t * 1.65 * thick * up }, { p = knee * 0.45, w = t * 1.05 * thick, h = t * 1.3 * thick * up },
		{ p = knee, w = t * 0.72, h = t * 0.82 } }, { seg = 12, steps = 3, up = FWD, capStart = t * 0.6, capEnd = t * 0.5, color = fur })
	local sockCol = o.sock or P.body
	local lower = loft({ { p = V(0, t * 0.15, 0), w = t * 0.72, h = t * 0.8 }, { p = ankle * 0.55, w = t * 0.6, h = t * 0.66 }, { p = ankle, w = t * 0.5, h = t * 0.55 } },
		{ seg = 10, steps = 3, up = FWD, capStart = t * 0.4, capEnd = t * 0.4, color = function(tt, ex, ey, p)
			return P.body:Lerp(sockCol, math.clamp((tt - 0.4) / 0.6, 0, 1))
		end })
	local foot
	local kind = o.foot or "paw"
	if kind == "hoof" then
		foot = merge({
			loft({ { p = V(0, t * 0.2, 0), w = t * 0.45, h = t * 0.5 }, { p = V(0, -footH * 0.55, -0.02), w = t * 0.4, h = t * 0.45 } }, { seg = 10, steps = 2, up = FWD, color = solid(sockCol) }),
			loft({ { p = V(0, -footH * 0.5, -0.03), w = t * 0.5, h = t * 0.55 }, { p = V(0, -footH, -0.07), w = t * 0.62, h = t * 0.72 } },
				{ seg = 10, steps = 1, up = FWD, capStart = 0.02, capEnd = 0.005, pow = 2.4, color = solid(P.hoof) }),
		})
	else
		local pw = (kind == "pad" and 1.35 or (kind == "web" and 1.5 or 1)) * t * 1.05
		local ph = t * (kind == "pad" and 0.55 or 0.48)
		local pl = (kind == "pad" and 1.7 or (kind == "web" and 2.2 or 1.25)) * t
		local list = {
			loft({ { p = V(0, -footH + ph, t * 0.35), w = pw * 0.75, h = ph, hb = ph }, { p = V(0, -footH + ph, -pl * 0.4), w = pw, h = ph * 0.95, hb = ph },
				{ p = V(0, -footH + ph * 0.85, -pl * 0.8), w = pw * 0.85, h = ph * 0.8, hb = ph * 0.85 } }, { seg = 12, steps = 2, color = function(tt, ex, ey)
				return ey < -0.6 and darker(sockCol, 0.55) or sockCol
			end }),
		}
		-- tornozelo/metatarso: liga a perna à pata (também no modo de peças; sem ele a pata ficava solta no chão)
		-- (no modo de peças, seção de 4 lados: liga a pata gastando poucas cunhas)
		table.insert(list, loft({ { p = V(0, t * 0.2, 0), w = t * 0.5, h = t * 0.55 }, { p = V(0, -footH + ph * 1.3, -t * 0.15), w = t * 0.5, h = t * 0.55 } },
			{ seg = 10, steps = 2, up = FWD, phase = MeshKit.low and math.pi / 4 or nil, color = solid(sockCol) }))
		-- dedos e garras (no modo de peças fica só a pata)
		local nToes = MeshKit.low and 0 or 4
		for i = 1, nToes do
			local fx = ((i - 0.5) / nToes - 0.5) * 2 * pw * 0.7
			local spread = kind == "web" and 1.6 or 1
			local a = V(fx, -footH + ph * 0.8, -pl * 0.6)
			local b = V(fx * 1.15 * spread, -footH + ph * 0.6, -pl * (kind == "web" and 1.35 or 1.0))
			table.insert(list, loft({ { p = a, w = ph * 0.5, h = ph * 0.5 }, { p = b, w = ph * 0.42, h = ph * 0.42 } }, { seg = 8, steps = 1, capEnd = ph * 0.35, color = solid(sockCol) }))
			if kind ~= "web" then
				local cl = (kind == "claw" or kind == "pad") and 1.6 or 1
				table.insert(list, loft({ { p = b + V(0, 0.01, -ph * 0.2), w = ph * 0.2, h = ph * 0.2 }, { p = b + V(0, -ph * 0.35, -ph * 0.75 * cl), w = 0.01, h = 0.01 } },
					{ seg = 6, steps = 1, capStart = 0, capEnd = 0.005, color = solid(P.claw) }))
			end
		end
		if kind == "web" then
			table.insert(list, sheet({ V(-pw * 0.55, -footH + ph * 0.5, -pl * 0.5), V(-pw * 1.25, -footH + ph * 0.45, -pl * 1.35), V(pw * 1.25, -footH + ph * 0.45, -pl * 1.35),
				V(pw * 0.55, -footH + ph * 0.5, -pl * 0.5) }, 0.02, P.belly:Lerp(sockCol, 0.5)))
		end
		foot = merge(list)
	end
	return { upper = upper, lower = lower, foot = foot, knee = knee, ankle = ankle, footH = footH }
end

-- Adiciona uma perna (3 partes) à planta. tag = "FL"/"FR"/"BL"/"BR"/"L"/"R".
local function addLeg(bp, P, parent: string, tag: string, pivot: Vector3, o, material: string)
	local g = legGeoms(P, o)
	addPart(bp, "Upper" .. tag, parent, "Leg" .. tag, pivot, g.upper, { material = material })
	addPart(bp, "Lower" .. tag, "Upper" .. tag, "Knee" .. tag, pivot + g.knee, g.lower, { material = material })
	addPart(bp, "Foot" .. tag, "Lower" .. tag, "Foot" .. tag, pivot + g.knee + g.ankle, g.foot, { material = material, role = "Belly" })
	return pivot.Y + g.knee.Y + g.ankle.Y - g.footH -- altura do chão
end

-------------------------------------------------------------------------------
-- Caudas (cadeia de partes: "Tail", "TailSeg2", "TailSeg3"... ou várias caudas "Tail1".."TailN")
-------------------------------------------------------------------------------

local function tailCurve(n: number, segLen: number, ang: number, curl: number, yaw: number?)
	local pts = { Vector3.zero }
	local a = rad(ang)
	local y = rad(yaw or 0)
	for i = 1, n do
		local d = V(math.sin(y) * math.cos(a), math.sin(a), math.cos(y) * math.cos(a))
		table.insert(pts, pts[i] + d * segLen)
		a += rad(curl)
	end
	return pts
end

-- profile(t) -> raio; jag = tufos; colorOpts = furFn opts
local function addTail(bp, P, parent: string, pivot: Vector3, o)
	local kind = o.kind or "thin"
	if kind == "none" then
		return
	end
	local mat = o.material or "Fabric"
	if kind == "stub" or kind == "puff" or kind == "nub" then
		local r = (kind == "puff" and 0.2 or 0.12) * (o.scale or 1)
		local d = V(0, math.sin(rad(o.ang or 35)), math.cos(rad(o.ang or 35)))
		local g = loft({ { p = -d * r * 0.5, w = r, h = r * 1.1 }, { p = d * r * 1.6, w = r * (kind == "puff" and 1.15 or 0.75), h = r * 1.05, jag = kind == "puff" and 0.18 or 0 } },
			{ seg = 10, steps = 2, capEnd = r * 0.8, color = furFn(P, { tip = kind == "puff" and P.belly:Lerp(WHITE, 0.3) or (o.tip or P.belly), tipFrom = 0.3, pattern = false }) })
		addPart(bp, "Tail", parent, "Tail", pivot, g, { material = mat })
		return
	end
	local n = o.segs or 3
	local len = o.len or 1.2
	local pts = tailCurve(n, len / n, o.ang or 20, o.curl or -6, o.yaw)
	local t = o.t or 0.12
	local profile = o.profile or function(x)
		return t * (1 - 0.7 * x)
	end
	local prevName = parent
	for i = 1, n do
		local a, b = pts[i], pts[i + 1]
		local t0, t1 = (i - 1) / n, i / n
		local dir = (b - a).Unit
		local keys = {
			{ p = -dir * profile(t0) * 0.6, w = profile(t0), h = profile(t0), jag = o.jag },
			{ p = (b - a) * 0.5, w = profile((t0 + t1) / 2), h = profile((t0 + t1) / 2), jag = o.jag },
			{ p = b - a, w = profile(t1), h = profile(t1), jag = o.jag },
		}
		local col = furFn(P, { shade = true, pattern = o.pattern ~= false, tip = (i == n) and o.tip or nil, tipFrom = 0.25, belly = o.underside })
		local g = loft(keys, { seg = o.seg or 10, steps = 2, capStart = 0, capEnd = (i == n) and profile(t1) * 0.9 or 0, color = col })
		if i == n and o.tuft then
			g = merge({ g, loft({ { p = b - a - dir * 0.05, w = t * 1.2, h = t * 1.2, jag = 0.3 }, { p = b - a + dir * t * 2.2, w = t * 0.9, h = t * 0.9, jag = 0.35 } },
				{ seg = 10, steps = 2, capEnd = t * 0.8, color = solid(o.tuft) }) })
		end
		if i == n and o.gem then
			g = merge({ g, loft({ { p = b - a, w = t * 1.1, h = t * 0.8, pow = 1.2 }, { p = b - a + dir * t * 2.6, w = 0.01, pow = 1.2 } },
				{ seg = 4, steps = 1, capStart = t, capEnd = 0.01, flat = true, color = solid(o.gem) }) })
		end
		local name = i == 1 and (o.name or "Tail") or ((o.name or "Tail") .. "Seg" .. i)
		local joint = i == 1 and (o.joint or "Tail") or ("TailSeg" .. i)
		if o.joint and o.joint ~= "Tail" then
			joint = i == 1 and o.joint or nil -- caudas extras (leque): uma junta por cauda
		end
		addPart(bp, name, prevName, joint, pivot + a, g, { material = mat })
		prevName = name
	end
end

-------------------------------------------------------------------------------
-- Asas (geometria aberta no referencial do ombro; o Animator bate pela junta WingL/WingR)
-------------------------------------------------------------------------------

local function wingGeom(P, kind: string, span: number, side: number)
	local S = span
	local s = side
	local list = {}
	local edge = P.tips or darker(P.accent, 0.8)
	if kind == "membrane" or kind == "dragon" then
		local sh, el, wr = V(0, 0, 0), V(s * S * 0.38, 0.12, -0.1), V(s * S * 0.62, 0.18, 0.05)
		local bone = function(a, b, r0, r1)
			return loft({ { p = a, w = r0, h = r0 }, { p = b, w = r1, h = r1 } }, { seg = 7, steps = 1, capEnd = r1, color = solid(P.dorsal) })
		end
		table.insert(list, bone(sh, el, 0.09, 0.07))
		table.insert(list, bone(el, wr, 0.07, 0.05))
		local tips = { V(s * S, 0.1, 0.12), V(s * S * 0.9, 0.0, 0.55), V(s * S * 0.6, -0.05, 0.85) }
		for _, ft in ipairs(tips) do
			table.insert(list, bone(wr, ft, 0.04, 0.015))
		end
		table.insert(list, loft({ { p = wr, w = 0.05 }, { p = wr + V(s * 0.12, 0.12, -0.12), w = 0.01 } }, { seg = 6, steps = 1, color = solid(P.claw) }))
		local memCol = function(q)
			return P.belly:Lerp(P.accent, math.clamp(math.abs(q.X) / S, 0, 1) * 0.6)
		end
		local outline = { sh + V(0, 0, 0.1), el + V(0, 0, 0.02), wr, tips[1], tips[2] }
		table.insert(list, sheet(outline, 0.03, memCol))
		table.insert(list, sheet({ sh + V(0, 0, 0.1), wr, tips[2], tips[3], V(s * 0.2, -0.05, 0.75) }, 0.03, memCol))
		return merge(list), "SmoothPlastic"
	elseif kind == "leaf" then
		for k = 0, 2 do
			local dir = V(s * math.cos(rad(-10 + k * 28)), 0.02 * k, math.sin(rad(-10 + k * 28)))
			local tip = dir * S * (1 - k * 0.18)
			local mid = tip * 0.5
			local wv = V(-dir.Z, 0, dir.X) * S * 0.16
			table.insert(list, sheet({ V(0, 0, 0), mid + wv, tip, mid - wv }, 0.03, function(q)
				return P.accent:Lerp(darker(P.accent, 0.7), math.clamp(q.Magnitude / S, 0, 1))
			end))
		end
		return merge(list), "Grass"
	elseif kind == "crystal" then
		for k = 0, 2 do
			local dir = V(s * math.cos(rad(-5 + k * 25)), 0.05, math.sin(rad(-5 + k * 25)))
			table.insert(list, loft({ { p = V(0, 0, 0), w = 0.12, h = 0.04, pow = 1.2 }, { p = dir * S * 0.55, w = 0.16, h = 0.04, pow = 1.2 }, { p = dir * S * (1 - k * 0.15), w = 0.01, h = 0.01, pow = 1.2 } },
				{ seg = 4, steps = 2, capEnd = 0.01, flat = true, color = solid(P.accent) }))
		end
		return merge(list), "Glass"
	end
	-- penas (feather/seraph/cloud): braço + coberteiras + rêmiges primárias e secundárias
	local wr, tip = V(s * S * 0.45, 0.06, 0.04), V(s * S * 0.95, 0.02, 0.16)
	table.insert(list, loft({ { p = V(0, 0, 0), w = 0.11, h = 0.08 }, { p = wr, w = 0.08, h = 0.06 }, { p = tip, w = 0.04, h = 0.03 } }, { seg = 8, steps = 2, capEnd = 0.04, color = solid(P.body) }))
	local cov = { V(0, 0.02, -0.08), V(s * S * 0.5, 0.05, -0.06), V(s * S * 0.95, 0.03, 0.12), V(s * S * 0.55, 0.02, S * 0.28), V(0, 0.02, S * 0.32) }
	table.insert(list, sheet(cov, 0.05, function(q)
		return P.body:Lerp(P.belly, 0.25)
	end))
	local function feather(base: Vector3, dir: Vector3, l: number, fw: number, y: number)
		local perp = V(-dir.Z, 0, dir.X) * fw
		local tipP = base + dir * l
		return sheet({ base - perp * 0.6 + V(0, y, 0), base + dir * l * 0.55 - perp + V(0, y, 0), tipP + V(0, y, 0), base + dir * l * 0.55 + perp + V(0, y, 0), base + perp * 0.6 + V(0, y, 0) }, 0.025,
			function(q)
				local f = math.clamp((q - base).Magnitude / l, 0, 1)
				return P.body:Lerp(kind == "seraph" and P.accent or edge, f * f)
			end)
	end
	for i = 0, 5 do
		local f = i / 5
		local base = wr:Lerp(tip, f)
		local ang = rad(10 + f * 55)
		table.insert(list, feather(base, V(s * math.sin(ang), 0, math.cos(ang)).Unit, S * (0.42 - f * 0.08), 0.09, -0.01 - i * 0.004))
	end
	for i = 0, 4 do
		local base = V(0, 0, 0):Lerp(wr, i / 4)
		table.insert(list, feather(base, V(s * 0.12, 0, 1).Unit, S * 0.38, 0.1, -0.02))
	end
	return merge(list), kind == "seraph" and "SmoothPlastic" or "Fabric"
end
PetAnatomy.wingGeom = wingGeom

-- Asas na planta. rest = pose de repouso (ângulos de varredura para trás e diedro).
local function addWings(bp, P, parent: string, at: Vector3, kind: string, span: number, rest)
	for _, side in ipairs({ -1, 1 }) do
		local g, mat = wingGeom(P, kind, span, side)
		local cf = CFrame.Angles(0, -side * rad(rest.sweep or 0), 0) * CFrame.Angles(0, 0, side * rad(rest.dihedral or 0))
		g = MeshKit.transform(g, cf)
		addPart(bp, side < 0 and "WingL" or "WingR", parent, side < 0 and "WingL" or "WingR", at + V(side * (rest.inset or 0.2), 0, 0), g,
			{ material = mat, role = "Accent", transparency = kind == "crystal" and 0.12 or 0 })
	end
end

-------------------------------------------------------------------------------
-- Detalhes das costas (cristais, folhas, flores, espinhos, musgo, juba, casco, árvore)
-------------------------------------------------------------------------------

local function backExtras(bp, P, kind: string?, topY, L: number, scale: number)
	if not kind then
		return
	end
	local list = {}
	local mat, role, transp = "Fabric", "Accent", 0
	local zs = { -0.3, -0.1, 0.1, 0.3 }
	if kind == "crystals" then
		for i, z in ipairs({ -0.32, -0.12, 0.08, 0.26, 0.4 }) do
			local base = V((i % 2 == 0 and 0.12 or -0.12) * scale, topY(z * L) - 0.05, z * L)
			local h = (0.55 - math.abs(z) * 0.5) * scale
			table.insert(list, loft({ { p = base, w = 0.09 * scale, h = 0.07 * scale, pow = 1.2 }, { p = base + V((i % 2 == 0 and 0.08 or -0.08) * scale, h, 0.05), w = 0.01, pow = 1.2 } },
				{ seg = 5, steps = 1, capStart = 0.02, capEnd = 0.005, flat = true, color = solid(i % 2 == 0 and P.accent or P.accent:Lerp(WHITE, 0.3)) }))
		end
		mat, transp = "Glass", 0.1
	elseif kind == "leaves" or kind == "fronds" then
		for i, z in ipairs(zs) do
			local base = V(0, topY(z * L) - 0.02, z * L)
			local dir = V((i % 2 == 0 and 1 or -1) * 0.5, 0.55, 0.65).Unit
			local tip = base + dir * 0.55 * scale
			local perp = V(0.12 * scale, 0, -0.08 * scale)
			table.insert(list, sheet({ base, (base + tip) / 2 + perp, tip, (base + tip) / 2 - perp }, 0.02, function(q)
				return P.accent:Lerp(darker(P.accent, 0.7), math.clamp((q - base).Magnitude / (0.55 * scale), 0, 1))
			end))
		end
		mat = "Grass"
	elseif kind == "flowers" then
		for i, z in ipairs({ -0.25, 0.05, 0.3 }) do
			local c = V((i % 2 == 0 and 0.15 or -0.15) * scale, topY(z * L) - 0.01, z * L) -- encostada no dorso
			table.insert(list, loft({ { p = c - V(0, 0.04, 0), w = 0.07 * scale }, { p = c + V(0, 0.04, 0), w = 0.07 * scale } }, { seg = 8, steps = 1, up = FWD, color = solid(rgb(255, 222, 110)) }))
			for k = 1, 5 do
				local a = k / 5 * math.pi * 2
				local d = V(math.cos(a), 0.25, math.sin(a))
				table.insert(list, sheet({ c, c + (d + V(-d.Z, 0, d.X) * 0.45) * 0.14 * scale, c + d * 0.24 * scale, c + (d - V(-d.Z, 0, d.X) * 0.45) * 0.14 * scale }, 0.015,
					k % 2 == 0 and P.accent or P.accent:Lerp(WHITE, 0.3)))
			end
		end
		mat = "SmoothPlastic"
	elseif kind == "thorns" or kind == "spikes" or kind == "fins" then
		for i = 1, 6 do
			local z = (-0.4 + i * 0.14) * L
			local base = V(0, topY(z) - 0.04, z)
			local h = (0.32 - math.abs(i - 3.5) * 0.03) * scale
			table.insert(list, loft({ { p = base, w = 0.04 * scale, h = 0.1 * scale }, { p = base + V(0, h, h * 0.35), w = 0.005, h = 0.01 } },
				{ seg = 6, steps = 1, capStart = 0.02, capEnd = 0.004, color = solid(kind == "fins" and P.accent or darker(P.accent, 0.85)) }))
		end
		mat = kind == "fins" and "Neon" or "SmoothPlastic"
	elseif kind == "moss" then
		for i, z in ipairs({ -0.3, -0.05, 0.22 }) do
			local c = V((i - 2) * 0.12 * scale, topY(z * L) - 0.02, z * L)
			table.insert(list, loft({ { p = c + V(0, 0, 0.18 * scale), w = 0.3 * scale, h = 0.09 * scale, jag = 0.25 }, { p = c - V(0, 0, 0.2 * scale), w = 0.26 * scale, h = 0.08 * scale, jag = 0.3 } },
				{ seg = 12, steps = 2, color = solid(i % 2 == 0 and P.accent or darker(P.accent, 0.82)) }))
		end
		mat = "Grass"
	elseif kind == "wool" or kind == "clouds" then
		for _, z in ipairs({ -0.25, 0.05, 0.3 }) do
			local c = V(0, topY(z * L) - 0.1, z * L)
			table.insert(list, loft({ { p = c + V(0, 0, 0.25 * scale), w = 0.5 * scale, h = 0.3 * scale, jag = 0.22 }, { p = c - V(0, 0, 0.25 * scale), w = 0.48 * scale, h = 0.28 * scale, jag = 0.22 } },
				{ seg = 14, steps = 2, color = solid(P.belly:Lerp(WHITE, 0.4)) }))
		end
	elseif kind == "stars" then
		for i = 1, 5 do
			local z = (-0.35 + i * 0.15) * L
			local c = V(((i % 3) - 1) * 0.15 * scale, topY(z) + 0.02, z)
			table.insert(list, loft({ { p = c, w = 0.06 * scale, h = 0.06 * scale, jag = 0.6 }, { p = c + V(0, 0.03, 0), w = 0.06 * scale, jag = 0.6 } },
				{ seg = 10, steps = 1, up = FWD, color = solid(P.accent) }))
		end
		mat, role = "Neon", "Glow"
	else
		return
	end
	addPart(bp, "Back" .. kind:sub(1, 1):upper() .. kind:sub(2), "Torso", nil, V(0, 0, 0), merge(list), { material = mat, role = role, transparency = transp })
end

-------------------------------------------------------------------------------
-- QUADRÚPEDES (canídeos, felinos, cervídeos, caprinos, lebres, roedores, mustelídeos, ursos, javalis,
-- répteis/dragões, sapos, tartarugas, grifos): mesma estrutura, proporções e órgãos próprios por tipo.
-------------------------------------------------------------------------------

local function H(t)
	return t
end

PetAnatomy.Presets = {
	canine = { L = 2.4, cw = 0.48, ch = 0.56, ww = 0.36, wh = 0.42, hw = 0.44, hh = 0.5, legLen = 1.25, legT = 0.14, digi = true, foot = "paw",
		neckLen = 0.66, neckAng = 46, neckW = 0.26, ears = { kind = "pointy", size = 0.95 }, tail = { kind = "bushy", len = 1.25, t = 0.15, ang = 18, curl = -10 },
		head = H({ len = 0.86, w = 0.33, h = 0.29, mLen = 0.5, mW = 0.14, mH = 0.13, stop = 0.07, eyeX = 0.21, eyeY = 0.1, eyeZ = -0.3, eyeR = 0.072, eyeFwd = 0.55 }) },
	fox = { L = 2.2, cw = 0.42, ch = 0.5, ww = 0.32, wh = 0.38, hw = 0.4, hh = 0.46, legLen = 1.0, legT = 0.12, digi = true, foot = "paw",
		neckLen = 0.6, neckAng = 44, neckW = 0.23, ears = { kind = "pointy", size = 1.25 }, tail = { kind = "bushy", len = 1.5, t = 0.22, ang = 12, curl = -6, whiteTip = true },
		head = H({ len = 0.82, w = 0.31, h = 0.27, mLen = 0.5, mW = 0.115, mH = 0.105, stop = 0.06, eyeX = 0.2, eyeY = 0.09, eyeZ = -0.3, eyeR = 0.07, eyeFwd = 0.55, slit = true }) },
	wolf = { L = 2.8, cw = 0.56, ch = 0.66, ww = 0.42, wh = 0.48, hw = 0.5, hh = 0.56, legLen = 1.4, legT = 0.16, digi = true, foot = "paw", ruff = true,
		neckLen = 0.75, neckAng = 40, neckW = 0.33, ears = { kind = "pointy", size = 0.95 }, tail = { kind = "bushy", len = 1.4, t = 0.18, ang = 8, curl = -10 },
		head = H({ len = 0.92, w = 0.38, h = 0.34, mLen = 0.48, mW = 0.17, mH = 0.15, stop = 0.09, eyeX = 0.23, eyeY = 0.11, eyeZ = -0.32, eyeR = 0.072, eyeFwd = 0.6, ruff = true }) },
	pup = { L = 1.8, cw = 0.44, ch = 0.5, ww = 0.36, wh = 0.42, hw = 0.42, hh = 0.48, legLen = 0.85, legT = 0.13, digi = true, foot = "paw",
		neckLen = 0.42, neckAng = 52, neckW = 0.26, ears = { kind = "pointy", size = 0.85 }, tail = { kind = "bushy", len = 0.85, t = 0.12, ang = 40, curl = 12 },
		head = H({ len = 0.82, w = 0.4, h = 0.36, mLen = 0.3, mW = 0.16, mH = 0.14, stop = 0.08, eyeX = 0.22, eyeY = 0.12, eyeZ = -0.27, eyeR = 0.095, eyeFwd = 0.6, round = true }) },
	feline = { L = 2.3, cw = 0.44, ch = 0.5, ww = 0.34, wh = 0.4, hw = 0.42, hh = 0.48, legLen = 1.05, legT = 0.13, digi = true, foot = "paw",
		neckLen = 0.48, neckAng = 34, neckW = 0.25, ears = { kind = "pointy", size = 0.72 }, tail = { kind = "thin", len = 1.6, t = 0.085, ang = 28, curl = 8 },
		head = H({ len = 0.66, w = 0.36, h = 0.32, mLen = 0.14, mW = 0.16, mH = 0.12, stop = 0.1, eyeX = 0.19, eyeY = 0.08, eyeZ = -0.24, eyeR = 0.09, eyeFwd = 0.75, slit = true, round = true }) },
	lion = { L = 2.9, cw = 0.58, ch = 0.64, ww = 0.44, wh = 0.48, hw = 0.5, hh = 0.56, legLen = 1.25, legT = 0.17, digi = true, foot = "paw", mane = true,
		neckLen = 0.55, neckAng = 30, neckW = 0.34, ears = { kind = "round", size = 0.7 }, tail = { kind = "thin", len = 1.6, t = 0.08, ang = 20, curl = -6, tuft = true },
		head = H({ len = 0.86, w = 0.45, h = 0.41, mLen = 0.24, mW = 0.24, mH = 0.19, stop = 0.1, eyeX = 0.22, eyeY = 0.11, eyeZ = -0.3, eyeR = 0.078, eyeFwd = 0.72, round = true }) },
	lynx = { L = 2.2, cw = 0.44, ch = 0.52, ww = 0.36, wh = 0.42, hw = 0.44, hh = 0.5, legLen = 1.15, legT = 0.14, digi = true, foot = "paw",
		neckLen = 0.45, neckAng = 34, neckW = 0.26, ears = { kind = "tufted", size = 0.85 }, tail = { kind = "stub", scale = 1.2 },
		head = H({ len = 0.72, w = 0.37, h = 0.32, mLen = 0.22, mW = 0.16, mH = 0.12, stop = 0.09, eyeX = 0.19, eyeY = 0.08, eyeZ = -0.26, eyeR = 0.085, eyeFwd = 0.75, slit = true, ruff = true, round = true }) },
	cervid = { L = 2.2, cw = 0.4, ch = 0.54, ww = 0.34, wh = 0.42, hw = 0.4, hh = 0.5, legLen = 1.6, legT = 0.115, digi = true, foot = "hoof",
		neckLen = 1.0, neckAng = 62, neckW = 0.19, ears = { kind = "pointy", size = 0.95, splay = true }, tail = { kind = "stub", tip = WHITE },
		head = H({ len = 0.74, w = 0.23, h = 0.23, mLen = 0.42, mW = 0.115, mH = 0.125, stop = 0.05, eyeX = 0.2, eyeY = 0.07, eyeZ = -0.22, eyeR = 0.08, eyeFwd = 0.22 }) },
	caprine = { L = 2.0, cw = 0.44, ch = 0.55, ww = 0.38, wh = 0.46, hw = 0.4, hh = 0.5, legLen = 1.2, legT = 0.12, digi = true, foot = "hoof",
		neckLen = 0.65, neckAng = 52, neckW = 0.22, ears = { kind = "floppy", size = 0.85 }, tail = { kind = "stub" }, horns = "curled",
		head = H({ len = 0.7, w = 0.25, h = 0.25, mLen = 0.38, mW = 0.13, mH = 0.13, stop = 0.04, eyeX = 0.2, eyeY = 0.08, eyeZ = -0.2, eyeR = 0.075, eyeFwd = 0.25, beard = true }) },
	lagomorph = { L = 1.5, cw = 0.4, ch = 0.44, ww = 0.44, wh = 0.5, hw = 0.56, hh = 0.58, legLen = 0.7, legT = 0.09, fold = true, foot = "paw",
		neckLen = 0.2, neckAng = 62, neckW = 0.3, ears = { kind = "long", size = 0.95 }, tail = { kind = "puff" },
		head = H({ len = 0.6, w = 0.32, h = 0.3, mLen = 0.18, mW = 0.15, mH = 0.12, stop = 0.05, eyeX = 0.23, eyeY = 0.08, eyeZ = -0.1, eyeR = 0.085, eyeFwd = 0.3, round = true }) },
	rodent = { L = 1.45, cw = 0.34, ch = 0.36, ww = 0.33, wh = 0.37, hw = 0.4, hh = 0.42, legLen = 0.55, legT = 0.07, foot = "paw",
		neckLen = 0.16, neckAng = 40, neckW = 0.26, ears = { kind = "mouse", size = 0.75 }, tail = { kind = "thin", len = 1.6, t = 0.045, ang = 10, curl = 6, pattern = false },
		head = H({ len = 0.58, w = 0.26, h = 0.23, mLen = 0.3, mW = 0.095, mH = 0.085, stop = 0.03, eyeX = 0.18, eyeY = 0.07, eyeZ = -0.16, eyeR = 0.07, eyeFwd = 0.35, round = true }) },
	squirrel = { L = 1.4, cw = 0.33, ch = 0.38, ww = 0.32, wh = 0.38, hw = 0.42, hh = 0.45, legLen = 0.6, legT = 0.075, fold = true, foot = "paw",
		neckLen = 0.2, neckAng = 55, neckW = 0.24, ears = { kind = "tufted", size = 0.6 }, tail = { kind = "bushy", len = 1.5, t = 0.22, ang = 70, curl = -22 },
		head = H({ len = 0.56, w = 0.27, h = 0.25, mLen = 0.2, mW = 0.11, mH = 0.1, stop = 0.04, eyeX = 0.19, eyeY = 0.08, eyeZ = -0.12, eyeR = 0.075, eyeFwd = 0.3, round = true }) },
	mustelid = { L = 2.8, cw = 0.29, ch = 0.31, ww = 0.27, wh = 0.29, hw = 0.29, hh = 0.32, legLen = 0.52, legT = 0.085, foot = "paw",
		neckLen = 0.45, neckAng = 24, neckW = 0.21, ears = { kind = "round", size = 0.55 }, tail = { kind = "bushy", len = 1.0, t = 0.1, ang = 6, curl = -4 },
		head = H({ len = 0.58, w = 0.24, h = 0.21, mLen = 0.24, mW = 0.11, mH = 0.09, stop = 0.03, eyeX = 0.16, eyeY = 0.07, eyeZ = -0.17, eyeR = 0.062, eyeFwd = 0.45 }) },
	ursine = { L = 2.3, cw = 0.66, ch = 0.7, ww = 0.62, wh = 0.64, hw = 0.6, hh = 0.64, legLen = 1.0, legT = 0.23, foot = "pad",
		neckLen = 0.35, neckAng = 24, neckW = 0.42, ears = { kind = "round", size = 0.85 }, tail = { kind = "stub" },
		head = H({ len = 0.82, w = 0.44, h = 0.39, mLen = 0.32, mW = 0.19, mH = 0.17, stop = 0.06, eyeX = 0.22, eyeY = 0.1, eyeZ = -0.26, eyeR = 0.062, eyeFwd = 0.6, round = true }) },
	heavy = { L = 2.4, cw = 0.62, ch = 0.7, ww = 0.58, wh = 0.62, hw = 0.55, hh = 0.6, legLen = 0.85, legT = 0.2, foot = "hoof",
		neckLen = 0.3, neckAng = 8, neckW = 0.45, ears = { kind = "pointy", size = 0.7 }, tail = { kind = "thin", len = 0.5, t = 0.05, ang = -30, curl = 10, pattern = false },
		head = H({ len = 0.98, w = 0.4, h = 0.37, mLen = 0.45, mW = 0.25, mH = 0.22, stop = 0.03, eyeX = 0.24, eyeY = 0.12, eyeZ = -0.28, eyeR = 0.058, eyeFwd = 0.45 }) },
	reptile = { L = 2.6, cw = 0.45, ch = 0.45, ww = 0.4, wh = 0.4, hw = 0.42, hh = 0.42, legLen = 0.95, legT = 0.15, splay = true, foot = "claw", material = "SmoothPlastic",
		neckLen = 0.95, neckAng = 38, neckW = 0.23, ears = { kind = "none" }, tail = { kind = "reptile", len = 2.4, t = 0.24, ang = 4, curl = -4, segs = 4 }, horns = "straight", back = "spikes",
		head = H({ len = 0.86, w = 0.29, h = 0.24, mLen = 0.55, mW = 0.18, mH = 0.13, stop = 0.02, eyeX = 0.22, eyeY = 0.1, eyeZ = -0.25, eyeR = 0.072, eyeFwd = 0.4, slit = true }) },
	amphibian = { L = 1.3, cw = 0.55, ch = 0.42, ww = 0.55, wh = 0.42, hw = 0.6, hh = 0.45, legLen = 0.55, legT = 0.1, fold = true, foot = "web", material = "SmoothPlastic",
		neckLen = 0.05, neckAng = 20, neckW = 0.45, ears = { kind = "none" }, tail = { kind = "none" },
		head = H({ len = 0.5, w = 0.52, h = 0.28, mLen = 0.1, mW = 0.42, mH = 0.12, stop = 0, eyeX = 0.32, eyeY = 0.26, eyeZ = -0.08, eyeR = 0.13, eyeFwd = 0.3 }) },
	chelonian = { L = 2.1, cw = 0.52, ch = 0.38, ww = 0.52, wh = 0.38, hw = 0.48, hh = 0.36, legLen = 0.6, legT = 0.2, foot = "pad", shell = true, material = "SmoothPlastic",
		neckLen = 0.55, neckAng = 22, neckW = 0.19, ears = { kind = "none" }, tail = { kind = "stub" },
		head = H({ len = 0.52, w = 0.24, h = 0.21, mLen = 0.14, mW = 0.14, mH = 0.12, stop = 0.02, eyeX = 0.17, eyeY = 0.07, eyeZ = -0.15, eyeR = 0.06, eyeFwd = 0.45 }) },
}

local function copy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = type(v) == "table" and copy(v) or v
	end
	return c
end
PetAnatomy.copy = copy

-- Cabeça de ave (também usada no grifo): crânio, disco facial (corujas), bico (curto, cônico ou em gancho).
local function avianHead(P, o)
	local s = o.size or 1
	local owl = o.owl
	local keys = {
		{ p = V(0, 0.02, 0.26) * s, w = 0.21 * s, h = 0.21 * s },
		{ p = V(0, 0.05, 0.02) * s, w = (owl and 0.36 or 0.29) * s, h = 0.29 * s },
		{ p = V(0, 0.02, -0.17) * s, w = (owl and 0.34 or 0.25) * s, h = (owl and 0.3 or 0.24) * s },
		{ p = V(0, -0.02, -0.27) * s, w = (owl and 0.26 or 0.14) * s, h = (owl and 0.24 or 0.14) * s },
	}
	local discCol = P.belly:Lerp(WHITE, 0.25)
	local head = loft(keys, { seg = 16, steps = 3, pow = owl and 2.8 or 2.1, capEnd = (owl and 0.06 or 0.1) * s, color = function(t, ex, ey, p)
		local c = P.body:Lerp(P.dorsal, math.clamp(ey, 0, 1) * 0.5)
		if owl and p.Z < -0.12 * s then
			c = c:Lerp(discCol, 0.7)
		elseif p.Z < -0.1 * s and ey < 0 then
			c = c:Lerp(P.belly, 0.6)
		end
		return c
	end })
	local beakCol = o.beakColor or P.accent:Lerp(rgb(236, 176, 64), 0.55)
	local bz = (owl and -0.27 or -0.3) * s
	local hook = o.beak == "hook"
	local beak = loft({ { p = V(0, -0.01, bz + 0.06 * s), w = (hook and 0.1 or 0.085) * s, h = 0.08 * s }, { p = V(0, -0.025 * s, bz - (hook and 0.11 or 0.12) * s), w = 0.05 * s, h = 0.05 * s },
		{ p = V(0, (hook and -0.09 or -0.04) * s, bz - (hook and 0.18 or 0.2) * s), w = 0.012 * s, h = 0.012 * s } }, { seg = 10, steps = 3, capStart = 0, capEnd = 0.008, color = function(t)
		return beakCol:Lerp(darker(beakCol, 0.55), t * t)
	end })
	local face = { beak }
	-- maxila inferior (junta "Jaw": abre o bico)
	local jawPivot = V(0, -0.06 * s, bz + 0.05 * s)
	local jaw = loft({ { p = V(0, 0, 0), w = (hook and 0.08 or 0.07) * s, h = 0.035 * s }, { p = V(0, -0.005 * s, -0.12 * s), w = 0.035 * s, h = 0.02 * s }, { p = V(0, 0, -(hook and 0.16 or 0.18) * s), w = 0.008 * s, h = 0.008 * s } },
		{ seg = 8, steps = 2, capStart = 0, capEnd = 0.006, color = solid(darker(beakCol, 0.8)) })
	local eyes = {}
	local fwd = owl and 0.85 or (o.eyeFwd or 0.35)
	local r = (o.eyeR or (owl and 0.085 or 0.06)) * s
	for _, side in ipairs({ -1, 1 }) do
		local n = V(side * (1 - fwd), 0.1, -fwd * 1.1)
		local target = V(side * (owl and 0.13 or 0.17), 0.07, owl and -0.24 or -0.16) * s
		local c = seatOnMesh(head, target, n, r) or seatEye(keys, target, n, r)
		table.insert(face, eyeGeom(P, c, n, r, { sclera = owl and rgb(250, 210, 80) or nil, surface = head }))
		table.insert(eyes, { c = c, n = n.Unit, r = r })
	end
	local extra = {}
	if o.crest or o.tufts then
		for i = -1, 1 do
			local base = V(i * 0.06 * s + (o.tufts and i * 0.12 * s or 0), 0.26 * s, 0.02 * s)
			if not (o.tufts and i == 0) then
				table.insert(extra, sheet({ base - V(0.03, 0, 0.04) * s, base + V(i * 0.05, 0.28, 0.12) * s, base + V(0.03, 0, -0.02) * s }, 0.02, o.tufts and P.dorsal or P.accent))
			end
		end
	end
	return { head = merge({ head, table.unpack(extra) }), face = merge(face), jaw = jaw, jawPivot = jawPivot, eyes = eyes, earAt = V(0.2, 0.2, 0.05) * s, hornAt = V(0.14, 0.24, 0) * s, topY = 0.3 * s }
end
do
	-- na "Alta qualidade" do modo de peças a cabeça ganha mais faces (é o que mais se olha)
	local build = avianHead
	avianHead = function(...)
		MeshKit.focus = MeshKit.mid
		local r = build(...)
		MeshKit.focus = false
		return r
	end
end
PetAnatomy.avianHead = avianHead

local function addLids(bp, P, hp: Vector3, eyes, color: Color3?, parent: string?)
	if lowDetail() then
		return -- modo de peças leve: sem piscar
	end
	for i, e in ipairs(eyes) do
		local g, blink = lidGeom(P, e.c, e.n, e.r, color)
		local tag = i == 1 and "L" or "R"
		addPart(bp, "Lid" .. tag, parent or "Head", "Lid" .. tag, hp, g, { attrs = { BlinkVec = blink } })
	end
end

local function quadruped(bp, P, Q, m)
	local mat = Q.material or "Fabric"
	local L, cw, ch, ww, wh, hw, hh = Q.L, Q.cw, Q.ch, Q.ww, Q.wh, Q.hw, Q.hh
	local fur = furFn(P, {})
	local torsoKeys = {
		{ p = V(0, 0.06, -L * 0.52), w = cw * 0.66, h = ch * 0.62, hb = ch * 0.6 },
		{ p = V(0, 0, -L * 0.32), w = cw, h = ch * 0.82, hb = ch },
		{ p = V(0, 0.04, -L * 0.04), w = ww, h = wh * 0.92, hb = wh * 0.72 },
		{ p = V(0, 0.06, L * 0.26), w = hw, h = hh * 0.92, hb = hh * 0.84 },
		{ p = V(0, 0.03, L * 0.46), w = hw * 0.72, h = hh * 0.62, hb = hh * 0.6 },
	}
	local function topY(z: number): number
		for i = 1, #torsoKeys - 1 do
			local a, b = torsoKeys[i], torsoKeys[i + 1]
			if z >= a.p.Z and z <= b.p.Z then
				local f = (z - a.p.Z) / (b.p.Z - a.p.Z)
				return (a.p.Y + a.h) * (1 - f) + (b.p.Y + b.h) * f
			end
		end
		return torsoKeys[1].p.Y + torsoKeys[1].h
	end
	MeshKit.focus = MeshKit.mid -- tronco com mais faces na "Alta qualidade"
	local parts = { loft(torsoKeys, { seg = 18, steps = 4, pow = 2.15, capStart = cw * 0.45, capEnd = hw * 0.55, color = fur }) }
	MeshKit.focus = false
	-- músculos do ombro e da coxa: volumes que se fundem ao tronco (cor do flanco, sem a barriga)
	local flank = furFn(P, { shade = false })
	for _, side in ipairs(lowDetail() and {} or { -1, 1 }) do
		table.insert(parts, loft({ { p = V(side * cw * 0.5, ch * 0.4, -L * 0.27), w = cw * 0.3, h = cw * 0.24 }, { p = V(side * cw * 0.6, -ch * 0.3, -L * 0.31), w = cw * 0.32, h = cw * 0.28 } },
			{ seg = 10, steps = 2, up = FWD, capEnd = cw * 0.1, color = flank }))
		table.insert(parts, loft({ { p = V(side * hw * 0.45, hh * 0.5, L * 0.23), w = hw * 0.36, h = hw * 0.42 }, { p = V(side * hw * 0.6, -hh * 0.28, L * 0.29), w = hw * 0.38, h = hw * 0.44 } },
			{ seg = 10, steps = 2, up = FWD, capEnd = hw * 0.1, color = flank }))
	end
	if not lowDetail() and (Q.ruff or (P.tier >= 3 and Q.furry ~= false and mat == "Fabric")) then
		-- peitoral de pelo (Raro+ e lobos): tufos na frente do peito
		table.insert(parts, loft({ { p = V(0, ch * 0.1, -L * 0.42), w = cw * 0.7, h = ch * 0.55, jag = 0.22 }, { p = V(0, -ch * 0.35, -L * 0.5), w = cw * 0.55, h = ch * 0.4, jag = 0.28 } },
			{ seg = 14, steps = 2, color = furFn(P, { base = P.belly:Lerp(P.body, 0.25), shade = false }) }))
	end
	addPart(bp, "Torso", nil, "Body", V(0, 0, 0), merge(parts), { material = mat })

	-- pescoço e cabeça
	local nb = V(0, ch * 0.3, -L * 0.44)
	local a = rad(Q.neckAng)
	local nEnd = V(0, math.sin(a), -math.cos(a)) * Q.neckLen
	local nw = Q.neckW
	local neck = loft({ { p = V(0, -ch * 0.3, L * 0.14), w = nw * 1.45, h = nw * 1.5 }, { p = V(0, 0, 0), w = nw * 1.15, h = nw * 1.25 }, { p = nEnd * 0.55, w = nw, h = nw * 1.08 },
		{ p = nEnd, w = nw * 0.9, h = nw * 0.95 } }, { seg = 14, steps = 3, capStart = 0, capEnd = nw * 0.6, color = furFn(P, {}) })
	addPart(bp, "Neck", "Torso", "Neck", nb, neck, { material = mat })
	local hp = nb + nEnd
	local Hd
	if m.beak then
		Hd = avianHead(P, { size = 1.3, beak = "hook", crest = true })
	else
		Hd = mammalHead(P, Q.head)
	end
	addPart(bp, "Head", "Neck", "Head", hp, Hd.head, { material = mat })
	addPart(bp, "Face", "Head", nil, hp, Hd.face, { material = "SmoothPlastic", role = "Eye", reflectance = 0.12 })
	if Hd.jaw then
		addPart(bp, "Jaw", "Head", "Jaw", hp + Hd.jawPivot, Hd.jaw, { material = mat, role = "Belly" })
	end
	addLids(bp, P, hp, Hd.eyes)
	-- orelhas
	local ek = Q.ears and Q.ears.kind or "pointy"
	if ek ~= "none" then
		for _, side in ipairs({ -1, 1 }) do
			local g = earGeom(P, ek, (Q.ears.size or 1) * (Q.head.h / 0.3), side)
			if Q.ears.splay then
				g = MeshKit.transform(g, CFrame.Angles(0, 0, side * rad(-55)))
			end
			local em = ek == "crystal" and "Glass" or (ek == "leafy" and "Grass" or mat)
			local at = Hd.earAt
			addPart(bp, side < 0 and "EarL" or "EarR", "Head", side < 0 and "EarL" or "EarR", hp + V(side * at.X, at.Y, at.Z), g,
				{ material = em, role = ek == "crystal" and "Accent" or "Body", transparency = ek == "crystal" and 0.1 or 0 })
		end
	end
	-- chifres, galhadas e presas
	local hk = Q.horns
	if hk and hk ~= "tusks" then
		local list, crystal = {}, false
		for _, side in ipairs({ -1, 1 }) do
			local at = Hd.hornAt
			local g, cr = hornGeom(P, hk, V(side * at.X, at.Y, at.Z), side, Q.head.h / 0.3)
			table.insert(list, g)
			crystal = crystal or cr == true
		end
		addPart(bp, "Horns", "Head", nil, hp, merge(list), { material = crystal and "Glass" or "SmoothPlastic", role = "Accent", transparency = crystal and 0.08 or 0 })
	end
	if hk == "tusks" or Q.tusks then
		local list = {}
		local hd = Q.head
		for _, side in ipairs({ -1, 1 }) do
			local base = V(side * hd.mW * 0.9, -hd.stop - hd.mH * 0.5, -hd.len * 0.5 - hd.mLen * 0.55)
			table.insert(list, loft({ { p = base, w = 0.05, h = 0.05 }, { p = base + V(side * 0.05, 0.12, -0.12), w = 0.035 }, { p = base + V(side * 0.1, 0.3, -0.12), w = 0.01 } },
				{ seg = 8, steps = 3, capEnd = 0.01, color = solid(rgb(242, 234, 214)) }))
		end
		addPart(bp, "Tusks", "Head", nil, hp, merge(list), { material = "SmoothPlastic", role = "Detail" })
	end
	-- juba (leões)
	if Q.mane then
		local hd = Q.head
		local maneCol = m.mane or P.accent
		local mane = loft({ { p = V(0, -0.08, ch * 0.45), w = nw * 1.6, h = nw * 1.7, jag = 0.12 }, { p = nEnd * 0.45 + V(0, 0.06, 0.05), w = nw * 2.15, h = nw * 2.1, jag = 0.15 },
			{ p = nEnd + V(0, 0.06, 0.24), w = hd.w * 1.28, h = hd.h * 1.45, jag = 0.14 } }, { seg = 34, steps = 3, capStart = nw, capEnd = hd.w * 0.5, color = function(t, ex, ey)
			return darker(maneCol, 0.7):Lerp(maneCol, math.clamp(t + ey * 0.2, 0, 1))
		end })
		addPart(bp, "Mane", "Neck", nil, nb, mane, { material = "Fabric", role = "Accent" })
	end
	-- pernas
	local legOpts = function(len, hind, side)
		return { len = len, t = Q.legT, hind = hind, digi = Q.digi and hind, fold = Q.fold and hind, splay = Q.splay, foot = Q.foot, side = side, sock = P.sock }
	end
	local ground
	for _, side in ipairs({ -1, 1 }) do
		local tag = side < 0 and "L" or "R"
		local F = V(side * cw * 0.52, -ch * 0.25, -L * 0.3)
		ground = addLeg(bp, P, "Torso", "F" .. tag, F, legOpts(Q.legLen, false, side), mat)
	end
	for _, side in ipairs({ -1, 1 }) do
		local tag = side < 0 and "L" or "R"
		local B = V(side * hw * 0.5, -hh * 0.15, L * 0.28)
		addLeg(bp, P, "Torso", "B" .. tag, B, legOpts(B.Y - ground, true, side), mat)
	end
	bp.hover = -ground
	-- cauda
	local T = Q.tail or { kind = "thin" }
	local tk = T.kind
	local tp = V(0, hh * 0.35, L * 0.47)
	local tt = T.t or 0.12
	if tk == "bushy" then
		addTail(bp, P, "Torso", tp, { kind = tk, len = T.len, t = tt, ang = T.ang, curl = T.curl, jag = 0.16, seg = 12, material = mat,
			tip = T.whiteTip and WHITE or P.tips, profile = function(x)
				return tt * (0.45 + 0.75 * math.sin(math.pi * math.min(1, x * 1.05 + 0.08)))
			end })
	elseif tk == "multi" then
		local n = T.count or 3
		for i = 1, n do
			local f = n == 1 and 0 or (i - 1) / (n - 1) - 0.5
			addTail(bp, P, "Torso", tp, { kind = "bushy", len = (T.len or 1.2) * 0.9, t = tt, ang = 30 - math.abs(f) * 20, curl = -6, yaw = f * 110, segs = 1, jag = 0.16, seg = 12,
				name = "Tail" .. i, joint = "Tail" .. i, material = mat, tip = T.tipColor or WHITE, profile = function(x)
					return tt * (0.45 + 0.7 * math.sin(math.pi * math.min(1, x * 1.05 + 0.08)))
				end })
		end
	elseif tk == "reptile" then
		addTail(bp, P, "Torso", tp - V(0, hh * 0.2, 0), { kind = tk, len = T.len, t = tt, ang = T.ang, curl = T.curl, segs = T.segs or 4, material = mat, seg = 12, gem = T.gem and P.accent or nil, profile = function(x)
			return tt * (1 - 0.9 * x)
		end })
	elseif tk == "crystal" then
		addTail(bp, P, "Torso", tp, { kind = "thin", len = T.len or 1.2, t = tt, ang = 25, curl = 6, material = mat, gem = P.accent, tip = P.tips })
	elseif tk == "leaf" then
		local tipP = V(0, 0.35, 1.2)
		addPart(bp, "Tail", "Torso", "Tail", tp, merge({ sheet({ V(0, 0, 0), V(-0.28, 0.12, 0.6), tipP, V(0.28, 0.12, 0.6) }, 0.03, function(q)
			return P.accent:Lerp(darker(P.accent, 0.7), q.Z / 1.2)
		end) }), { material = "Grass", role = "Accent" })
	else
		addTail(bp, P, "Torso", tp, { kind = tk, len = T.len or 1.2, t = tt, ang = T.ang or 25, curl = T.curl or 6, material = mat, tip = T.tip or P.tips, tuft = T.tuft and darker(P.accent, 0.6) or nil,
			pattern = T.pattern, scale = T.scale })
	end
	-- asas (grifos, cervos alados, dragões)
	if Q.wings then
		addWings(bp, P, "Torso", V(0, ch * 0.75, -L * 0.24), Q.wings, 1.7 * (Q.wingSpan or 1), { sweep = 52, dihedral = 22, inset = cw * 0.45 })
	end
	-- casco (tartaruga) com árvore opcional
	if Q.shell then
		local shellCol = m.shell or darker(P.accent, 0.75)
		local shell = loft({ { p = V(0, 0.02, -L * 0.52), w = cw * 1.08, h = 0.14, hb = 0.06 }, { p = V(0, 0.12, -L * 0.22), w = cw * 1.3, h = ch * 1.35, hb = 0.12 },
			{ p = V(0, 0.14, L * 0.16), w = cw * 1.3, h = ch * 1.4, hb = 0.12 }, { p = V(0, 0.02, L * 0.5), w = cw * 1.0, h = 0.16, hb = 0.06 } },
			{ seg = 18, steps = 4, pow = 2.0, color = function(t, ex, ey, p)
				local plate = hash(math.floor(p.X * 2.6 + 10), 0, math.floor(p.Z * 2.6 + 10))
				local c = shellCol:Lerp(shellCol:Lerp(WHITE, 0.18), plate)
				return ey < 0.15 and darker(shellCol, 0.6) or c
			end })
		local list = { shell }
		if Q.tree then
			local top = V(0, ch * 1.45, 0)
			table.insert(list, loft({ { p = top - V(0, 0.2, 0), w = 0.12 }, { p = top + V(0.05, 0.7, 0), w = 0.08 }, { p = top + V(0.15, 1.0, -0.05), w = 0.05 } },
				{ seg = 8, steps = 2, color = solid(rgb(104, 74, 50)) }))
			for k = 1, 12 do
				local ang = k * 2.39996
				local yy = 0.95 + (k % 3) * 0.12
				local base = top + V(math.cos(ang) * 0.12, yy, math.sin(ang) * 0.12)
				local dir = V(math.cos(ang), 0.35 + (k % 2) * 0.2, math.sin(ang)).Unit
				local tipP = base + dir * 0.55
				local perp = V(-dir.Z, 0, dir.X) * 0.16
				table.insert(list, sheet({ base, (base + tipP) / 2 + perp, tipP, (base + tipP) / 2 - perp }, 0.03, ({ rgb(78, 150, 58), rgb(104, 178, 66), rgb(64, 128, 52) })[k % 3 + 1]))
			end
		end
		addPart(bp, "Shell", "Torso", nil, V(0, 0, 0), merge(list), { material = "SmoothPlastic", role = "Accent" })
	end
	backExtras(bp, P, Q.back, topY, L, (cw + hw) / 0.95)
	bp.L = L
end
PetAnatomy.quadruped = quadruped

-------------------------------------------------------------------------------
-- Espécie → tipo de corpo (pelo id e pelos parâmetros do modelo)
-------------------------------------------------------------------------------

local NAME_RULES = {
	{ "wolf", "wolf" }, { "hound", "wolf" }, { "kitsune", "fox" }, { "fox", "fox" }, { "kit_", "fox" },
	{ "pup", "pup" }, { "lion", "lion" }, { "thornmane", "lion" }, { "lynx", "lynx" }, { "panther", "feline" }, { "kitten", "feline" }, { "cat", "feline" },
	{ "griffin", "griffin" }, { "stag", "cervid" }, { "fawn", "cervid" }, { "celestara", "cervid" }, { "goat", "caprine" }, { "ram", "caprine" },
	{ "hare", "lagomorph" }, { "hop", "lagomorph" }, { "mouse", "rodent" }, { "scamper", "squirrel" }, { "ferret", "mustelid" },
	{ "boar", "heavy" }, { "behemoth", "heavy" }, { "mossling", "heavy" }, { "frog", "amphibian" }, { "tortoise", "chelonian" }, { "dragon", "reptile" },
	{ "beetle", "insect" }, { "mite", "insect" }, { "bear", "ursine" }, { "tiger", "tiger" },
}

function PetAnatomy.classify(speciesId: string, species): (string, string?)
	local m = species.model or {}
	local rig = m.rig or "quad"
	if rig == "flyer" then
		if m.drake then
			return "dragon", "reptile"
		elseif m.wings == "membrane" then
			return "bat", nil
		elseif m.wings == "moth" then
			return "moth", nil
		end
		return "avian", nil
	elseif rig ~= "quad" then
		return rig, nil -- serpent, floater, golem, slime, shroom, treant, biped, leafpanda, bushgoat, mammoth
	end
	for _, r in ipairs(NAME_RULES) do
		if speciesId:find(r[1], 1, true) then
			if r[2] == "insect" then
				return "insect", nil
			end
			return "quad", r[2]
		end
	end
	if m.ears == "long" then
		return "quad", "lagomorph"
	elseif m.horns == "antlers" then
		return "quad", "cervid"
	elseif m.stocky then
		return "quad", "heavy"
	end
	return "quad", "canine"
end

-- Ajusta o preset com os parâmetros da espécie (pernas, comprimento, focinho, orelhas, cauda, chifres...).
local EAR_MAP = { pointy = "pointy", round = "round", long = "long", tufted = "tufted", leafy = "leafy", crystal = "crystal", mouse = "mouse", feelers = "feelers" }
local TAIL_MAP = { fluffy = "bushy", leafy = "bushy", nub = "stub", multi = "multi", fan = "multi", thin = "thin", crystal = "crystal", leaf = "leaf", flame = "thin", cloud = "puff" }

local function tune(Q, m, preset: string)
	Q = copy(Q)
	if m.legs then
		Q.legLen *= math.clamp(m.legs, 0.5, 1.6) ^ 0.6
	end
	if m.long then
		Q.L *= m.long ^ 0.7
	end
	if m.snout then
		Q.head.mLen *= math.min(m.snout, 1.6) ^ 0.35
	end
	if m.neck then
		Q.neckLen += m.neck * 0.5
	end
	if m.stocky then
		Q.cw *= 1.15
		Q.ww *= 1.15
		Q.hw *= 1.12
		Q.legT *= 1.15
	end
	if m.ears and EAR_MAP[m.ears] and not (preset == "lion" and m.ears == "round") then
		Q.ears = Q.ears and copy(Q.ears) or {}
		Q.ears.kind = EAR_MAP[m.ears]
		if m.ears == "long" then
			Q.ears.size = (Q.ears.size or 1) * 0.95
		end
	end
	if m.tail and TAIL_MAP[m.tail] and preset ~= "lynx" then
		Q.tail = Q.tail and copy(Q.tail) or {}
		local k = TAIL_MAP[m.tail]
		if Q.tail.kind == "reptile" and k == "crystal" then
			Q.tail.gem = true
		elseif k ~= Q.tail.kind then
			Q.tail.kind = k
			if k == "bushy" then
				Q.tail.len = Q.tail.len or 1.3
				Q.tail.t = math.max(Q.tail.t or 0.15, 0.15)
				if m.tail == "leafy" then
					Q.tail.ang, Q.tail.curl = 55, -18
				end
			elseif k == "multi" then
				Q.tail.count = m.tailCount or (m.tail == "multi" and 5 or 3)
				Q.tail.len, Q.tail.t = 1.25, 0.16
			end
		end
	end
	if m.horns then
		Q.horns = m.horns
	end
	if m.back then
		Q.back = m.back
		if m.back == "mane" then
			Q.back = nil
			Q.mane = true
		elseif m.back == "tree" or m.back == "shell" then
			Q.shell = true
			Q.tree = m.back == "tree"
			Q.back = nil
		end
	end
	if m.wings then
		Q.wings = m.wings == "leaf" and "leaf" or (m.wings == "crystal" and "crystal" or (m.wings == "membrane" and "membrane" or "feather"))
		Q.wingSpan = m.wingSpan or 1.2
	end
	if m.glassy then
		Q.material = "Glass"
	end
	return Q
end
PetAnatomy.tune = tune

-------------------------------------------------------------------------------
-- AVES (pássaros, corujas, gaviões, pintinhos, serafins), MORCEGO e MARIPOSA
-------------------------------------------------------------------------------

local function birdLeg(P, side: number, len: number)
	local legCol = P.accent:Lerp(rgb(214, 160, 70), 0.5)
	local list = {
		loft({ { p = V(0, 0.08, 0), w = 0.13, h = 0.15 }, { p = V(0, -len * 0.35, 0.03), w = 0.1, h = 0.11 } }, { seg = 10, steps = 2, up = FWD, color = solid(P.belly) }),
		loft({ { p = V(0, -len * 0.3, 0.03), w = 0.035, h = 0.035 }, { p = V(0, -len + 0.03, -0.02), w = 0.03, h = 0.03 } }, { seg = 7, steps = 1, up = FWD, color = solid(legCol) }),
	}
	for k = -1, lowDetail() and 1 or 2 do
		local dir = k == 2 and V(0, 0, 1) or V(k * 0.45, 0, -1).Unit
		local a = V(0, -len + 0.03, -0.02)
		local b = a + dir * 0.17 + V(0, -0.02, 0)
		table.insert(list, loft({ { p = a, w = 0.022 }, { p = b, w = 0.018 } }, { seg = 6, steps = 1, color = solid(legCol) }))
		if not lowDetail() then
			table.insert(list, loft({ { p = b, w = 0.016 }, { p = b + dir * 0.06 + V(0, -0.03, 0), w = 0.003 } }, { seg = 5, steps = 1, color = solid(P.claw) }))
		end
	end
	return merge(list)
end

local function avian(bp, P, m, speciesId: string)
	local owl = speciesId:find("owl") ~= nil
	local hawk = speciesId:find("hawk") ~= nil or speciesId:find("eagle") ~= nil
	local chick = speciesId:find("chirp") ~= nil
	local seraph = speciesId:find("seraph") ~= nil
	local k = owl and 1.15 or (chick and 1.1 or 1)
	local fur = furFn(P, { pattern = true })
	local body = loft({
		{ p = V(0, 0.12, -0.6), w = 0.34 * k, h = 0.34 * k, hb = 0.38 * k },
		{ p = V(0, 0.02, -0.28), w = 0.5 * k, h = 0.47 * k, hb = 0.55 * k },
		{ p = V(0, 0.04, 0.12), w = 0.44 * k, h = 0.41 * k, hb = 0.42 * k },
		{ p = V(0, 0.1, 0.5), w = 0.25, h = 0.23, hb = 0.21 },
		{ p = V(0, 0.16, 0.72), w = 0.11, h = 0.09 },
	}, { seg = 16, steps = 3, capStart = 0.3, capEnd = 0.08, color = function(t, ex, ey, p)
		local c = fur(t, ex, ey, p)
		-- escamado das penas no peito
		if ey < -0.1 and math.sin(p.Z * 22 + math.abs(p.X) * 14) > 0.75 then
			c = darker(c, 0.88)
		end
		return c
	end })
	addPart(bp, "Torso", nil, "Body", V(0, 0, 0), body, { material = "Fabric" })
	local hp = V(0, 0.5 * k, -0.52)
	local Hd = avianHead(P, { size = owl and 1.25 or (chick and 1.2 or 1), owl = owl, beak = hawk and "hook" or (chick and "short" or "cone"), crest = m.crest or hawk, tufts = owl and m.ears == "tufted" })
	addPart(bp, "Head", "Torso", "Neck", hp, Hd.head, { material = "Fabric" })
	addPart(bp, "Face", "Head", nil, hp, Hd.face, { material = "SmoothPlastic", role = "Eye", reflectance = 0.15 })
	addPart(bp, "Jaw", "Head", "Jaw", hp + Hd.jawPivot, Hd.jaw, { material = "SmoothPlastic", role = "Detail" })
	addLids(bp, P, hp, Hd.eyes)
	local wk = m.wings or "feather"
	if seraph then
		wk = "seraph"
	end
	addWings(bp, P, "Torso", V(0, 0.3, -0.28), wk == "cloud" and "feather" or wk, (seraph and 1.9 or (hawk and 1.75 or 1.45)) * (m.wingSpan or 1), { sweep = 18, dihedral = 14, inset = 0.32 * k })
	if seraph then
		addWings(bp, P, "Torso", V(0, 0.05, -0.1), "seraph", 1.1, { sweep = 40, dihedral = -20, inset = 0.3 })
		bp.byName.WingL.name, bp.byName.WingR.name = "Wing2L", "Wing2R"
		bp.byName.WingL.joint, bp.byName.WingR.joint = "Wing2L", "Wing2R"
	end
	-- leque da cauda
	local fan = {}
	for i = -2, 2 do
		local dir = V(i * 0.22, 0.05, 1).Unit
		local base = V(i * 0.03, 0, 0)
		local l = (owl and 0.45 or (hawk and 0.75 or 0.6)) - math.abs(i) * 0.05
		local perp = V(-dir.Z, 0, dir.X) * 0.08
		table.insert(fan, sheet({ base - perp, base + dir * l * 0.6 - perp * 1.2, base + dir * l, base + dir * l * 0.6 + perp * 1.2, base + perp }, 0.025, function(q)
			return P.body:Lerp(P.tips or P.accent, math.clamp(q.Magnitude / l, 0, 1) ^ 2)
		end))
	end
	addPart(bp, "Tail", "Torso", "Tail", V(0, 0.15, 0.66), merge(fan), { material = "Fabric", role = "Accent" })
	local legLen = owl and 0.6 or 0.68
	for _, side in ipairs({ -1, 1 }) do
		addPart(bp, side < 0 and "LegL" or "LegR", "Torso", side < 0 and "LegL" or "LegR", V(side * 0.2, -0.36 * k, 0.04), birdLeg(P, side, legLen), { material = "SmoothPlastic", role = "Detail" })
	end
	bp.hover = 0.36 * k + legLen
	bp.gait = "bird"
end

local function bat(bp, P, m)
	local fur = furFn(P, {})
	addPart(bp, "Torso", nil, "Body", V(0, 0, 0), loft({ { p = V(0, 0.05, -0.4), w = 0.3, h = 0.3 }, { p = V(0, 0, -0.1), w = 0.36, h = 0.36, hb = 0.4 }, { p = V(0, 0.02, 0.35), w = 0.24, h = 0.22 } },
		{ seg = 14, steps = 3, capStart = 0.22, capEnd = 0.18, color = fur }), {})
	local hp = V(0, 0.3, -0.42)
	local Hd = mammalHead(P, { len = 0.45, w = 0.28, h = 0.25, mLen = 0.14, mW = 0.12, mH = 0.09, stop = 0.06, eyeX = 0.15, eyeY = 0.07, eyeZ = -0.15, eyeR = 0.07, eyeFwd = 0.7, round = true })
	addPart(bp, "Head", "Torso", "Neck", hp, Hd.head, {})
	addPart(bp, "Face", "Head", nil, hp, Hd.face, { material = "SmoothPlastic", role = "Eye", reflectance = 0.12 })
	addPart(bp, "Jaw", "Head", "Jaw", hp + Hd.jawPivot, Hd.jaw, { role = "Belly" })
	addLids(bp, P, hp, Hd.eyes)
	for _, side in ipairs({ -1, 1 }) do
		addPart(bp, side < 0 and "EarL" or "EarR", "Head", side < 0 and "EarL" or "EarR", hp + V(side * 0.16, 0.18, 0.05), earGeom(P, "pointy", 1.6, side), {})
	end
	addWings(bp, P, "Torso", V(0, 0.15, -0.2), "membrane", 1.6, { sweep = 10, dihedral = 8, inset = 0.2 })
	addPart(bp, "LegL", "Torso", "LegL", V(-0.12, -0.3, 0.25), birdLeg(P, -1, 0.3), { material = "SmoothPlastic" })
	addPart(bp, "LegR", "Torso", "LegR", V(0.12, -0.3, 0.25), birdLeg(P, 1, 0.3), { material = "SmoothPlastic" })
	bp.hover = 0.6
	bp.gait = "bird"
end

local function moth(bp, P, m)
	local body = loft({ { p = V(0, 0.05, -0.45), w = 0.22, h = 0.22, jag = 0.2 }, { p = V(0, 0, -0.1), w = 0.27, h = 0.27, jag = 0.2 }, { p = V(0, -0.02, 0.45), w = 0.18, h = 0.17 },
		{ p = V(0, -0.05, 0.75), w = 0.06, h = 0.06 } }, { seg = 14, steps = 3, capStart = 0.18, capEnd = 0.04, color = function(t, ex, ey, p)
		return (math.sin(p.Z * 18) > 0.4 and t > 0.4) and P.accent or P.body
	end })
	addPart(bp, "Torso", nil, "Body", V(0, 0, 0), body, {})
	local hp = V(0, 0.08, -0.55)
	local head = loft({ { p = V(0, 0, 0.1), w = 0.17, h = 0.16 }, { p = V(0, 0, -0.12), w = 0.15, h = 0.14 } }, { seg = 12, steps = 2, capEnd = 0.1, color = solid(P.body) })
	local face = {}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(face, eyeGeom(P, V(side * 0.11, 0.03, -0.1), V(side * 0.8, 0.1, -0.6), 0.08, { glow = true }))
		-- antenas plumosas
		local a = V(side * 0.05, 0.12, -0.12)
		table.insert(face, loft({ { p = a, w = 0.015 }, { p = a + V(side * 0.18, 0.35, -0.18), w = 0.01 } }, { seg = 5, steps = 1, color = solid(P.deep) }))
		for j = 1, 4 do
			local q = a + V(side * 0.18, 0.35, -0.18) * (j / 5)
			table.insert(face, sheet({ q, q + V(side * 0.08, 0.02, 0.02), q + V(0, 0.07, 0.01) }, 0.01, P.belly))
		end
	end
	addPart(bp, "Head", "Torso", "Neck", hp, head, {})
	addPart(bp, "Face", "Head", nil, hp, merge(face), { material = "SmoothPlastic", role = "Eye", reflectance = 0.1 })
	for _, side in ipairs({ -1, 1 }) do
		local fore = sheet({ V(0, 0, -0.1), V(side * 0.6, 0.05, -0.55), V(side * 1.35, 0.08, -0.35), V(side * 1.2, 0.04, 0.15), V(side * 0.4, 0, 0.2) }, 0.025, function(q)
			local spot = (q - V(side * 0.85, 0, -0.2)).Magnitude
			if spot < 0.14 then
				return BLACK
			elseif spot < 0.24 then
				return P.accent
			end
			return P.body:Lerp(P.belly, math.clamp(math.abs(q.X) / 1.3, 0, 1))
		end)
		local hind = sheet({ V(0, -0.02, 0.1), V(side * 0.85, 0, 0.2), V(side * 0.75, -0.02, 0.75), V(side * 0.2, -0.03, 0.55) }, 0.025, function(q)
			return P.belly:Lerp(P.accent, math.clamp(q.Z, 0, 1) * 0.6)
		end)
		addPart(bp, side < 0 and "WingL" or "WingR", "Torso", side < 0 and "WingL" or "WingR", V(side * 0.15, 0.12, -0.1), merge({ fore, hind }), { material = "Fabric", role = "Accent" })
	end
	local legs = {}
	for i = -1, 1 do
		for _, side in ipairs({ -1, 1 }) do
			local a = V(side * 0.15, -0.15, i * 0.18 - 0.1)
			legs[#legs + 1] = loft({ { p = a, w = 0.02 }, { p = a + V(side * 0.18, -0.08, i * 0.06), w = 0.016 }, { p = a + V(side * 0.24, -0.3, i * 0.1), w = 0.01 } },
				{ seg = 5, steps = 2, color = solid(P.deep) })
		end
	end
	addPart(bp, "Legs", "Torso", nil, V(0, 0, 0), merge(legs), { material = "SmoothPlastic", role = "Detail" })
	bp.hover = 0.5
	bp.gait = "bird"
end

-------------------------------------------------------------------------------
-- SERPENTE (cabeça erguida + corpo em segmentos "Seg1".."SegN" que ondulam)
-------------------------------------------------------------------------------

local function serpent(bp, P, m)
	local r0 = 0.3
	local colorFn = function(t, ex, ey, p)
		local c = P.body
		if ey > 0.25 and math.sin(p.Z * 7) > 0.35 then
			c = c:Lerp(P.accent, 0.75) -- losangos no dorso
		end
		if ey < -0.3 then
			c = P.belly:Lerp(darker(P.belly, 0.8), math.sin(p.Z * 26) > 0.7 and 1 or 0) -- escamas do ventre
		end
		return c
	end
	-- parte da frente (erguida) até a cabeça
	addPart(bp, "Torso", nil, "Body", V(0, 0, 0), loft({ { p = V(0, -0.02, 0.35), w = r0, h = r0 }, { p = V(0, 0.1, -0.1), w = r0 * 0.95, h = r0 * 0.92 },
		{ p = V(0, 0.42, -0.42), w = r0 * 0.78, h = r0 * 0.78 }, { p = V(0, 0.62, -0.52), w = r0 * 0.7, h = r0 * 0.7 } }, { seg = 14, steps = 3, capStart = 0, capEnd = r0 * 0.5, color = colorFn }),
		{ material = "SmoothPlastic", reflectance = 0.05 })
	local hp = V(0, 0.68, -0.58)
	local Hd = mammalHead(P, { len = 0.6, w = 0.27, h = 0.18, mLen = 0.32, mW = 0.17, mH = 0.09, stop = 0.01, eyeX = 0.18, eyeY = 0.08, eyeZ = -0.14, eyeR = 0.06, eyeFwd = 0.45, slit = true,
		noseColor = P.body, mask = false })
	addPart(bp, "Head", "Torso", "Neck", hp, Hd.head, { material = "SmoothPlastic", reflectance = 0.05 })
	addPart(bp, "Face", "Head", nil, hp, Hd.face, { material = "SmoothPlastic", role = "Eye", reflectance = 0.15 })
	addPart(bp, "Jaw", "Head", "Jaw", hp + Hd.jawPivot, Hd.jaw, { material = "SmoothPlastic", role = "Belly" })
	addLids(bp, P, hp, Hd.eyes, P.dorsal)
	local n, segLen = 6, 0.6
	local prev, at = "Torso", V(0, -0.02, 0.35)
	for i = 1, n do
		local ra = r0 * (1 - (i - 1) / n * 0.85)
		local rb = r0 * (1 - i / n * 0.85)
		local g = loft({ { p = V(0, 0, -0.12), w = ra, h = ra }, { p = V(0, 0, segLen * 0.5), w = (ra + rb) / 2, h = (ra + rb) / 2 }, { p = V(0, 0, segLen), w = rb, h = rb } },
			{ seg = 12, steps = 2, capStart = 0, capEnd = i == n and rb * 2.2 or 0, color = function(t, ex, ey, p)
				return colorFn(t, ex, ey, p + at)
			end })
		if i == n and m.tail == "flame" then
			g = merge({ g, loft({ { p = V(0, 0, segLen), w = rb * 1.6 }, { p = V(0, 0.05, segLen + 0.5), w = 0.01 } }, { seg = 8, steps = 1, color = solid(P.accent) }) })
		end
		addPart(bp, "Seg" .. i, prev, "Seg" .. i, at, g, { material = "SmoothPlastic", reflectance = 0.05 })
		if m.back == "fins" and i <= 4 then
			local fh = 0.3 * (1 - i / 6)
			addPart(bp, "Fin" .. i, "Seg" .. i, nil, at, sheet({ V(0, ra * 0.8, 0), V(0, ra * 0.8 + fh, segLen * 0.3), V(0, ra * 0.7, segLen * 0.85) }, 0.03, P.accent),
				{ material = "Neon", role = "Glow" })
		end
		prev = "Seg" .. i
		at += V(0, 0, segLen)
	end
	bp.hover = r0
	bp.gait = "slither"
end

-------------------------------------------------------------------------------
-- BESOURO / ÁCARO (6 patas articuladas, élitros brilhantes, antenas)
-------------------------------------------------------------------------------

local function insect(bp, P, m)
	local shell = loft({ { p = V(0, 0.05, -0.42), w = 0.48, h = 0.32, hb = 0.12 }, { p = V(0, 0.12, -0.05), w = 0.6, h = 0.5, hb = 0.16 }, { p = V(0, 0.08, 0.4), w = 0.5, h = 0.42, hb = 0.14 },
		{ p = V(0, 0.02, 0.62), w = 0.24, h = 0.2, hb = 0.08 } }, { seg = 16, steps = 3, capStart = 0.2, capEnd = 0.1, color = function(t, ex, ey, p)
		if math.abs(p.X) < 0.025 and ey > 0 then
			return darker(P.body, 0.4) -- sutura entre os élitros
		end
		local c = P.body:Lerp(P.body:Lerp(WHITE, 0.25), math.max(0, ey))
		if hash(math.floor(p.X * 5 + 9), 0, math.floor(p.Z * 5 + 9)) > 0.86 and ey > 0.2 then
			c = P.accent
		end
		return ey < -0.2 and P.belly or c
	end })
	addPart(bp, "Torso", nil, "Body", V(0, 0, 0), shell, { material = "SmoothPlastic", reflectance = 0.12 })
	local hp = V(0, 0.02, -0.5)
	local head = loft({ { p = V(0, 0, 0.12), w = 0.26, h = 0.18 }, { p = V(0, -0.02, -0.12), w = 0.22, h = 0.15 } }, { seg = 12, steps = 2, capEnd = 0.1, color = solid(P.dorsal) })
	local face = {}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(face, eyeGeom(P, V(side * 0.17, 0.05, -0.06), V(side * 0.85, 0.15, -0.5), 0.07, { glow = P.glowEyes, iris = P.glowEyes and P.iris or rgb(30, 26, 40) }))
		-- mandíbulas
		table.insert(face, loft({ { p = V(side * 0.08, -0.06, -0.2), w = 0.035 }, { p = V(side * 0.02, -0.07, -0.33), w = 0.01 } }, { seg = 6, steps = 1, color = solid(P.claw) }))
	end
	addPart(bp, "Head", "Torso", "Neck", hp, head, { material = "SmoothPlastic", reflectance = 0.1 })
	addPart(bp, "Face", "Head", nil, hp, merge(face), { material = "SmoothPlastic", role = "Eye", reflectance = 0.2 })
	for _, side in ipairs({ -1, 1 }) do
		addPart(bp, side < 0 and "EarL" or "EarR", "Head", side < 0 and "EarL" or "EarR", hp + V(side * 0.08, 0.1, -0.08), earGeom(P, "feelers", 1, side), { material = "SmoothPlastic" })
	end
	local legCol = darker(P.body, 0.5)
	for i, z in ipairs({ -0.3, 0.02, 0.32 }) do
		local row = ({ "F", "M", "B" })[i]
		for _, side in ipairs({ -1, 1 }) do
			local tag = row .. (side < 0 and "L" or "R")
			local pivot = V(side * 0.36, -0.08, z)
			local knee = V(side * 0.32, 0.18, (i - 2) * 0.12)
			addPart(bp, "Upper" .. tag, "Torso", "Leg" .. tag, pivot, loft({ { p = V(0, 0, 0), w = 0.05 }, { p = knee, w = 0.04 } }, { seg = 7, steps = 1, capEnd = 0.04, color = solid(legCol) }),
				{ material = "SmoothPlastic" })
			addPart(bp, "Lower" .. tag, "Upper" .. tag, "Knee" .. tag, pivot + knee, loft({ { p = V(0, 0, 0), w = 0.04 }, { p = V(side * 0.12, -0.52, (i - 2) * 0.08), w = 0.02 } },
				{ seg = 7, steps = 1, capEnd = 0.02, color = solid(legCol) }), { material = "SmoothPlastic" })
		end
	end
	bp.hover = 0.08 - 0.18 + 0.52
	bp.gait = "insect"
end

-------------------------------------------------------------------------------
-- CRIATURAS MÁGICAS E ESPECIAIS
-------------------------------------------------------------------------------

local function faceOn(P, center: Vector3, sx: number, r: number, o)
	o = o or {}
	local list = {}
	local eyes = {}
	for _, side in ipairs({ -1, 1 }) do
		local c = center + V(side * sx, 0, 0)
		local n = V(side * (o.side or 0.25), 0.05, -1)
		table.insert(list, eyeGeom(P, c, n, r, { glow = o.glow, sclera = o.sclera, surface = o.surface }))
		table.insert(eyes, { c = c, n = n.Unit, r = r })
	end
	if o.mouth ~= false then
		local mc = center + V(0, -r * 1.6, -r * 0.1)
		table.insert(list, loft({ { p = mc - V(r * 0.6, 0, 0), w = r * 0.12, h = r * 0.12 }, { p = mc + V(0, -r * 0.18, -0.01), w = r * 0.12 }, { p = mc + V(r * 0.6, 0, 0), w = r * 0.12 } },
			{ seg = 6, steps = 2, color = solid(o.mouthColor or rgb(60, 30, 40)) }))
	end
	return merge(list), eyes
end

local function slime(bp, P, m)
	local body = loft({ { p = V(0, -0.78, 0), w = 1.12, h = 1.08 }, { p = V(0, -0.5, 0), w = 1.1, h = 1.06 }, { p = V(0, 0.02, 0), w = 0.86, h = 0.84 }, { p = V(0, 0.48, 0.04), w = 0.46, h = 0.44 },
		{ p = V(0, 0.72, 0.12), w = 0.12, h = 0.12 } }, { seg = 20, steps = 4, up = FWD, capStart = 0.22, capEnd = 0.1, color = function(t)
		return darker(P.body, 0.8):Lerp(P.body:Lerp(WHITE, 0.2), t)
	end })
	addPart(bp, "Torso", nil, "Body", V(0, 0, 0), body, { material = m.glassy and "Glass" or "SmoothPlastic", transparency = 0.22, reflectance = 0.08 })
	-- poça que escorre pela base (a gosma se espalha no chão e deixa um rastro para trás)
	addPart(bp, "Puddle", "Torso", nil, V(0, 0, 0), loft({ { p = V(0, -0.86, -0.75), w = 1.25, h = 0.05, hb = 0.06 }, { p = V(0, -0.86, 0.1), w = 1.6, h = 0.08, hb = 0.06 },
		{ p = V(0.2, -0.88, 1.2), w = 0.9, h = 0.05, hb = 0.05 }, { p = V(0.35, -0.9, 1.75), w = 0.35, h = 0.03, hb = 0.03 } }, { seg = 16, steps = 3, capStart = 0.2, capEnd = 0.15, color = solid(darker(P.body, 0.85)) }),
		{ material = m.glassy and "Glass" or "SmoothPlastic", transparency = 0.3, reflectance = 0.1 })
	addPart(bp, "Core", "Torso", nil, V(0, 0, 0), loft({ { p = V(0, -0.6, 0.05), w = 0.55 }, { p = V(0, -0.05, 0.05), w = 0.45 }, { p = V(0, 0.25, 0.05), w = 0.2 } },
		{ seg = 12, steps = 2, up = FWD, color = solid(P.belly) }), { material = "Neon", role = "Glow", transparency = 0.45 })
	local face, eyes = faceOn(P, V(0, -0.18, -0.92), 0.3, 0.16, { side = 0.3, surface = body })
	addPart(bp, "Face", "Torso", nil, V(0, 0, 0), face, { material = "SmoothPlastic", role = "Eye", reflectance = 0.15 })
	bp._eyes = eyes
	if m.top == "sprout" then
		for _, side in ipairs({ -1, 1 }) do
			local leaf = sheet({ V(0, 0, 0), V(side * 0.22, 0.25, 0.05), V(side * 0.45, 0.4, 0), V(side * 0.2, 0.12, -0.05) }, 0.03, P.accent)
			addPart(bp, side < 0 and "EarL" or "EarR", "Torso", side < 0 and "EarL" or "EarR", V(0, 0.8, 0.12), leaf, { material = "Grass", role = "Accent" })
		end
	elseif m.top == "crystal" then
		local list = {}
		for k = -1, 1 do
			table.insert(list, loft({ { p = V(k * 0.18, 0.55, 0.1), w = 0.1, h = 0.08, pow = 1.2 }, { p = V(k * 0.28, 0.95 - math.abs(k) * 0.15, 0.1), w = 0.01, pow = 1.2 } },
				{ seg = 4, steps = 1, flat = true, color = solid(P.accent) }))
		end
		addPart(bp, "TopCrystals", "Torso", nil, V(0, 0, 0), merge(list), { material = "Glass", role = "Accent" })
	end
	bp.hover = 0.78 + 0.22 - 0.06
	bp.gait = "bounce"
end

local function shroom(bp, P, m)
	local stem = loft({ { p = V(0, -0.62, 0), w = 0.6, h = 0.58 }, { p = V(0, -0.15, 0), w = 0.54, h = 0.52 }, { p = V(0, 0.38, 0), w = 0.44, h = 0.42 } },
		{ seg = 16, steps = 3, up = FWD, capStart = 0.15, capEnd = 0, color = solid(P.belly) })
	addPart(bp, "Torso", nil, "Body", V(0, 0, 0), stem, { material = "SmoothPlastic", role = "Belly" })
	local face, eyes = faceOn(P, V(0, -0.05, -0.5), 0.2, 0.11, { surface = stem })
	addPart(bp, "Face", "Torso", nil, V(0, 0, 0), face, { material = "SmoothPlastic", role = "Eye", reflectance = 0.12 })
	bp._eyes = eyes
	local cap = loft({ { p = V(0, 0, 0), w = 1.55, h = 1.45 }, { p = V(0, 0.18, 0), w = 1.42, h = 1.34 }, { p = V(0, 0.45, 0), w = 0.95, h = 0.9 }, { p = V(0, 0.64, 0), w = 0.35, h = 0.33 } },
		{ seg = 20, steps = 3, up = FWD, capStart = 0.14, capEnd = 0.1, color = function(t, ex, ey, p)
			if t <= 0.02 then
				return darker(P.belly, 0.7) -- lamelas por baixo
			end
			local spot = hash(math.floor(p.X * 3.2 + 7), math.floor(p.Y * 3.2 + 7), math.floor(p.Z * 3.2 + 7)) > 0.8
			return spot and P.accent or P.body:Lerp(P.body:Lerp(WHITE, 0.15), t)
		end })
	addPart(bp, "Head", "Torso", "Neck", V(0, 0.38, 0), cap, { material = m.glowSpots and "Neon" or "SmoothPlastic", role = "Body" })
	for _, side in ipairs({ -1, 1 }) do
		local t = side < 0 and "L" or "R"
		addPart(bp, "Arm" .. t, "Torso", "Arm" .. t, V(side * 0.48, 0.0, 0), loft({ { p = V(0, 0, 0), w = 0.1 }, { p = V(side * 0.22, -0.32, -0.05), w = 0.08 } },
			{ seg = 8, steps = 1, capEnd = 0.07, color = solid(P.belly) }), { material = "SmoothPlastic", role = "Belly" })
		addPart(bp, "Leg" .. t, "Torso", "Leg" .. t, V(side * 0.28, -0.6, 0), loft({ { p = V(0, 0, 0), w = 0.14, h = 0.14 }, { p = V(0, -0.22, -0.06), w = 0.13, h = 0.16 } },
			{ seg = 8, steps = 1, up = FWD, capEnd = 0.08, color = solid(darker(P.belly, 0.85)) }), { material = "SmoothPlastic", role = "Belly" })
	end
	bp.hover = 0.6 + 0.3
	bp.gait = "biped"
end

-- Golens de pedra/cristal (facetados) e o gorila de musgo (com pelo).
local function golem(bp, P, m, speciesId: string)
	local ape = speciesId:find("ape") ~= nil
	local mat = ape and "Fabric" or "Slate"
	local seg = ape and 14 or 7
	local pw = ape and 2.1 or 1.55
	local flat = not ape
	local rockCol = function(t, ex, ey, p)
		local c = P.body:Lerp(P.belly, math.clamp(-ey, 0, 1) * 0.5)
		if not ape then
			c = c:Lerp(darker(c, 0.75), hash(math.floor(p.X * 4 + 3), math.floor(p.Y * 4 + 3), math.floor(p.Z * 4 + 3)) * 0.6)
		end
		return c
	end
	local torso = loft({ { p = V(0, -0.62, 0.05), w = 0.68, h = 0.5 }, { p = V(0, 0, 0), w = 0.92, h = 0.6 }, { p = V(0, 0.52, -0.06), w = 1.02, h = 0.6 } },
		{ seg = seg, steps = 3, up = FWD, pow = pw, flat = flat, capStart = 0.3, capEnd = 0.45, color = rockCol })
	addPart(bp, "Torso", nil, "Body", V(0, 0, 0), torso, { material = mat })
	local hp = V(0, 0.82, -0.2)
	local Hd
	if ape then
		Hd = mammalHead(P, { len = 0.62, w = 0.36, h = 0.34, mLen = 0.18, mW = 0.24, mH = 0.15, stop = 0.1, eyeX = 0.15, eyeY = 0.1, eyeZ = -0.22, eyeR = 0.06, eyeFwd = 0.85, round = true })
		addPart(bp, "Head", "Torso", "Neck", hp, Hd.head, { material = mat })
		addPart(bp, "Jaw", "Head", "Jaw", hp + Hd.jawPivot, Hd.jaw, { material = mat, role = "Belly" })
		addPart(bp, "Face", "Head", nil, hp, Hd.face, { material = "SmoothPlastic", role = "Eye", reflectance = 0.12 })
		addLids(bp, P, hp, Hd.eyes)
	else
		local head = loft({ { p = V(0, 0, 0.22), w = 0.38, h = 0.3 }, { p = V(0, 0.02, -0.18), w = 0.36, h = 0.28 } }, { seg = 6, steps = 1, pow = 1.5, flat = true, capStart = 0.15, capEnd = 0.1, color = rockCol })
		addPart(bp, "Head", "Torso", "Neck", hp, head, { material = mat })
		-- viseira luminosa
		addPart(bp, "Visor", "Head", nil, hp, loft({ { p = V(-0.24, 0.03, -0.33), w = 0.05, h = 0.035 }, { p = V(0.24, 0.03, -0.33), w = 0.05, h = 0.035 } }, { seg = 6, steps = 1, color = solid(m.eye or P.accent) }),
			{ material = "Neon", role = "Eye" })
		-- fendas brilhantes no peito
		addPart(bp, "Core", "Torso", nil, V(0, 0, 0), merge({
			loft({ { p = V(0, 0.15, -0.66), w = 0.16, h = 0.16, pow = 1.3 }, { p = V(0, 0.15, -0.6), w = 0.16, pow = 1.3 } }, { seg = 6, steps = 1, color = solid(P.accent) }),
			loft({ { p = V(-0.35, -0.3, -0.62), w = 0.02 }, { p = V(-0.1, 0.05, -0.66), w = 0.02 } }, { seg = 4, steps = 1, color = solid(P.accent) }),
			loft({ { p = V(0.32, 0.4, -0.62), w = 0.02 }, { p = V(0.12, 0.2, -0.66), w = 0.02 } }, { seg = 4, steps = 1, color = solid(P.accent) }),
		}), { material = "Neon", role = "Glow" })
	end
	for _, side in ipairs({ -1, 1 }) do
		local t = side < 0 and "L" or "R"
		local sh = V(side * 1.05, 0.42, -0.02)
		local el = V(side * 0.2, -0.68, 0.02)
		addPart(bp, "UpperArm" .. t, "Torso", "Arm" .. t, sh, loft({ { p = V(0, 0.15, 0), w = 0.36, h = 0.34 }, { p = el, w = 0.26, h = 0.25 } },
			{ seg = seg, steps = 2, up = FWD, pow = pw, flat = flat, capStart = 0.2, capEnd = 0.18, color = rockCol }), { material = mat })
		addPart(bp, "Forearm" .. t, "UpperArm" .. t, "Elbow" .. t, sh + el, loft({ { p = V(0, 0, 0), w = 0.26, h = 0.25 }, { p = V(side * 0.05, -0.62, -0.08), w = 0.36, h = 0.34 } },
			{ seg = seg, steps = 2, up = FWD, pow = pw, flat = flat, capStart = 0.16, capEnd = 0.3, color = function(tt, ex, ey, p)
				return rockCol(tt, ex, ey, p):Lerp(P.belly, tt * 0.4)
			end }), { material = mat })
		local hip = V(side * 0.42, -0.62, 0.02)
		addPart(bp, "Thigh" .. t, "Torso", "Leg" .. t, hip, loft({ { p = V(0, 0.1, 0), w = 0.32, h = 0.3 }, { p = V(0, -0.5, -0.03), w = 0.26, h = 0.26 } },
			{ seg = seg, steps = 2, up = FWD, pow = pw, flat = flat, capStart = 0.15, capEnd = 0.12, color = rockCol }), { material = mat })
		addPart(bp, "Shin" .. t, "Thigh" .. t, "Knee" .. t, hip + V(0, -0.5, -0.03), loft({ { p = V(0, 0, 0), w = 0.26, h = 0.26 }, { p = V(0, -0.42, -0.08), w = 0.3, h = 0.36 } },
			{ seg = seg, steps = 2, up = FWD, pow = pw, flat = flat, capStart = 0.12, capEnd = 0.06, color = rockCol }), { material = mat })
	end
	bp.hover = 0.62 + 0.5 + 0.42 + 0.06
	bp.gait = "biped"
	bp.heavy = true
end

local function treant(bp, P, m)
	local bark = function(t, ex, ey, p)
		local groove = math.sin(math.atan2(p.X, p.Z) * 9 + p.Y * 2) > 0.55
		return groove and darker(P.body, 0.6) or P.body
	end
	addPart(bp, "Torso", nil, "Body", V(0, 0, 0), loft({ { p = V(0, -0.85, 0), w = 0.62, h = 0.58 }, { p = V(0, -0.2, 0), w = 0.5, h = 0.46 }, { p = V(0, 0.55, 0), w = 0.46, h = 0.42 },
		{ p = V(0, 0.95, 0), w = 0.38, h = 0.36 } }, { seg = 14, steps = 3, up = FWD, capStart = 0.2, capEnd = 0.2, color = bark }), { material = "Wood" })
	local face, eyes = faceOn(P, V(0, 0.45, -0.47), 0.16, 0.08, { glow = true, mouthColor = darker(P.body, 0.3) })
	addPart(bp, "Face", "Torso", nil, V(0, 0, 0), face, { material = "SmoothPlastic", role = "Eye" })
	bp._eyes = eyes
	-- copa de folhas (cabeça)
	local leaves = {}
	for k = 1, 28 do
		local ang = k * 2.39996
		local y = 0.15 + (k % 5) * 0.12
		local base = V(math.cos(ang) * 0.45, y * 0.9, math.sin(ang) * 0.22)
		local dir = V(math.cos(ang) * 1.3, 0.45 + (k % 3) * 0.2, math.sin(ang) * 0.45).Unit
		local tip = base + dir * 0.95
		local perp = V(-dir.Z, 0, dir.X) * 0.22
		local col = ({ P.accent, darker(P.accent, 0.8), P.accent:Lerp(WHITE, 0.12) })[k % 3 + 1]
		table.insert(leaves, sheet({ base, (base + tip) / 2 + perp, tip, (base + tip) / 2 - perp }, 0.04, col))
	end
	addPart(bp, "Head", "Torso", "Neck", V(0, 1.0, 0), merge(leaves), { material = m.glowCanopy and "Neon" or "Grass", role = "Accent", transparency = m.glowCanopy and 0.2 or 0 })
	for _, side in ipairs({ -1, 1 }) do
		local t = side < 0 and "L" or "R"
		local sh = V(side * 0.42, 0.6, 0)
		local arm = merge({
			loft({ { p = V(0, 0, 0), w = 0.16 }, { p = V(side * 0.65, -0.35, -0.1), w = 0.12 }, { p = V(side * 0.95, -0.9, -0.15), w = 0.07 } }, { seg = 8, steps = 2, capEnd = 0.06, color = bark }),
			loft({ { p = V(side * 0.65, -0.35, -0.1), w = 0.07 }, { p = V(side * 1.15, -0.3, -0.3), w = 0.03 } }, { seg = 6, steps = 1, color = bark }),
			sheet({ V(side * 0.95, -0.9, -0.15), V(side * 1.15, -1.0, -0.35), V(side * 1.0, -1.25, -0.2), V(side * 0.82, -1.05, -0.1) }, 0.03, P.accent),
		})
		addPart(bp, "Arm" .. t, "Torso", "Arm" .. t, sh, arm, { material = "Wood" })
		local hip = V(side * 0.3, -0.8, 0)
		addPart(bp, "Leg" .. t, "Torso", "Leg" .. t, hip, merge({
			loft({ { p = V(0, 0.1, 0), w = 0.2 }, { p = V(side * 0.05, -0.45, 0), w = 0.17 } }, { seg = 8, steps = 1, color = bark }),
			loft({ { p = V(side * 0.05, -0.42, 0), w = 0.08 }, { p = V(side * 0.3, -0.55, -0.15), w = 0.03 } }, { seg = 6, steps = 1, color = bark }),
			loft({ { p = V(side * 0.05, -0.42, 0), w = 0.08 }, { p = V(side * 0.0, -0.55, -0.35), w = 0.03 } }, { seg = 6, steps = 1, color = bark }),
		}), { material = "Wood" })
	end
	if m.blossoms then
		local list = {}
		for k = 1, 8 do
			local ang = k * 1.3
			local c = V(math.cos(ang) * 0.65, 0.5 + (k % 3) * 0.15, math.sin(ang) * 0.65)
			for q = 1, 5 do
				local a = q / 5 * math.pi * 2
				local d = V(math.cos(a), 0.3, math.sin(a)) * 0.1
				table.insert(list, sheet({ c, c + d + V(-d.Z, 0, d.X) * 0.5, c + d * 1.6, c + d - V(-d.Z, 0, d.X) * 0.5 }, 0.015, m.blossoms))
			end
		end
		addPart(bp, "Blossoms", "Head", nil, V(0, 1.0, 0), merge(list), { material = "SmoothPlastic", role = "Accent" })
	end
	bp.hover = 0.8 + 0.55
	bp.gait = "biped"
	bp.heavy = true
end

-- Espíritos que flutuam: corpo em gota com cauda que ondula (variações: nuvem, estrela, geodo, sombra).
local function floater(bp, P, m, speciesId: string)
	local cloud = speciesId:find("puff") ~= nil
	local star = speciesId:find("star") ~= nil
	local geode = speciesId:find("geode") ~= nil
	local shade = speciesId:find("shade") ~= nil
	local jag = cloud and 0.22 or (star and 0.55 or (shade and 0.18 or 0))
	local seg = star and 10 or (geode and 7 or 18)
	local body = loft({ { p = V(0, 0.08, -0.3), w = 0.66, h = 0.62, jag = jag }, { p = V(0, -0.05, 0.12), w = 0.6, h = 0.58, jag = jag }, { p = V(0, -0.3, 0.5), w = 0.38, h = 0.36, jag = jag } },
		{ seg = seg, steps = 3, capStart = 0.4, capEnd = 0, flat = geode, pow = geode and 1.4 or 2, color = function(t, ex, ey)
			return P.body:Lerp(P.belly, math.clamp(-ey * 0.5 + t * 0.3, 0, 1))
		end })
	local mat = geode and "Glass" or (cloud and "SmoothPlastic" or "SmoothPlastic")
	addPart(bp, "Torso", nil, "Body", V(0, 0, 0), body, { material = mat, transparency = (cloud or geode) and 0.05 or 0.12 })
	addPart(bp, "Core", "Torso", nil, V(0, 0, 0), loft({ { p = V(0, 0, -0.1), w = 0.32 }, { p = V(0, -0.1, 0.25), w = 0.22 } }, { seg = 10, steps = 1, color = solid(P.belly) }),
		{ material = "Neon", role = "Glow", transparency = 0.4 })
	local face, eyes = faceOn(P, V(0, 0.1, -0.88), 0.22, 0.12, { glow = shade or m.glowEyes, side = 0.35, mouth = not shade, surface = body })
	addPart(bp, "Face", "Torso", nil, V(0, 0, 0), face, { material = "SmoothPlastic", role = "Eye", reflectance = 0.12 })
	bp._eyes = eyes
	-- cauda de fumaça/vento em cadeia (ondula)
	addTail(bp, P, "Torso", V(0, -0.3, 0.5), { kind = "wisp", len = 1.4, t = 0.36, ang = -30, curl = 14, segs = 3, jag = jag * 0.8, seg = seg, material = mat,
		tip = P.accent, profile = function(x)
			return 0.36 * (1 - 0.92 * x)
		end })
	if shade then
		-- capuz/manto rasgado
		addPart(bp, "Hood", "Torso", nil, V(0, 0, 0), loft({ { p = V(0, 0.55, 0.15), w = 0.5, h = 0.42 }, { p = V(0, 0.2, -0.2), w = 0.76, h = 0.7, jag = 0.12 }, { p = V(0, -0.35, 0.25), w = 0.8, h = 0.75, jag = 0.3 } },
			{ seg = 18, steps = 3, capStart = 0.2, capEnd = 0, color = solid(darker(P.body, 0.7)) }), { material = "Fabric" })
	end
	bp.hover = 1.4
	bp.gait = "float"
end

-- Pequeno guardião bípede (Grovekin): casca de árvore, galhada, musgo.
local function biped(bp, P, m)
	local bark = furFn(P, { shade = true })
	addPart(bp, "Torso", nil, "Body", V(0, 0, 0), loft({ { p = V(0, -0.5, 0.02), w = 0.42, h = 0.36 }, { p = V(0, 0, 0), w = 0.46, h = 0.38 }, { p = V(0, 0.45, -0.02), w = 0.42, h = 0.34 } },
		{ seg = 14, steps = 3, up = FWD, capStart = 0.25, capEnd = 0.25, color = bark }), { material = "Wood" })
	local hp = V(0, 0.65, -0.05)
	local Hd = mammalHead(P, { len = 0.55, w = 0.34, h = 0.32, mLen = 0.14, mW = 0.17, mH = 0.12, stop = 0.06, eyeX = 0.15, eyeY = 0.06, eyeZ = -0.2, eyeR = 0.085, eyeFwd = 0.8, round = true })
	addPart(bp, "Head", "Torso", "Neck", hp, Hd.head, { material = "Wood" })
	addPart(bp, "Face", "Head", nil, hp, Hd.face, { material = "SmoothPlastic", role = "Eye", reflectance = 0.12 })
	addLids(bp, P, hp, Hd.eyes)
	local list = {}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(list, (hornGeom(P, "antlers", V(side * 0.14, 0.26, 0), side, 0.8)))
	end
	addPart(bp, "Horns", "Head", nil, hp, merge(list), { material = "Wood", role = "Accent" })
	for _, side in ipairs({ -1, 1 }) do
		local t = side < 0 and "L" or "R"
		local sh = V(side * 0.48, 0.3, 0)
		addPart(bp, "UpperArm" .. t, "Torso", "Arm" .. t, sh, loft({ { p = V(0, 0.05, 0), w = 0.14 }, { p = V(side * 0.08, -0.4, 0), w = 0.11 } }, { seg = 10, steps = 1, up = FWD, color = bark }),
			{ material = "Wood" })
		addPart(bp, "Forearm" .. t, "UpperArm" .. t, "Elbow" .. t, sh + V(side * 0.08, -0.4, 0), loft({ { p = V(0, 0, 0), w = 0.11 }, { p = V(side * 0.02, -0.38, -0.06), w = 0.12 } },
			{ seg = 10, steps = 1, up = FWD, capEnd = 0.1, color = function()
				return P.accent
			end }), { material = "Wood" })
		local hip = V(side * 0.2, -0.5, 0)
		addPart(bp, "Thigh" .. t, "Torso", "Leg" .. t, hip, loft({ { p = V(0, 0.05, 0), w = 0.16 }, { p = V(0, -0.35, 0), w = 0.13 } }, { seg = 10, steps = 1, up = FWD, color = bark }), { material = "Wood" })
		addPart(bp, "Shin" .. t, "Thigh" .. t, "Knee" .. t, hip + V(0, -0.35, 0), loft({ { p = V(0, 0, 0), w = 0.13 }, { p = V(0, -0.32, -0.02), w = 0.12 }, { p = V(0, -0.36, -0.18), w = 0.12, h = 0.08 } },
			{ seg = 10, steps = 2, up = FWD, capEnd = 0.06, color = bark }), { material = "Wood" })
	end
	backExtras(bp, P, "moss", function()
		return 0.4
	end, 0.8, 0.8)
	bp.hover = 0.5 + 0.35 + 0.4
	bp.gait = "biped"
end

-- Panda de manto de folhas (2ª leva do Mundo 1): capuz-manto verde com barra de folhas, rosto de panda.
local function leafPanda(bp, P, m)
	local dark = rgb(26, 24, 28)
	addPart(bp, "Torso", nil, "Body", V(0, 0, 0), loft({ { p = V(0, -0.62, 0), w = 0.68, h = 0.6 }, { p = V(0, -0.2, 0), w = 0.74, h = 0.66 }, { p = V(0, 0.25, 0), w = 0.6, h = 0.55 } },
		{ seg = 16, steps = 3, up = FWD, capStart = 0.3, capEnd = 0.2, color = solid(P.belly) }), { material = "Fabric", role = "Belly" })
	local hp = V(0, 0.42, 0)
	local hood = loft({ { p = V(0, -0.72, 0), w = 0.86, h = 0.82 }, { p = V(0, -0.2, 0), w = 0.9, h = 0.86 }, { p = V(0, 0.4, 0.02), w = 0.78, h = 0.74 }, { p = V(0, 0.75, 0.04), w = 0.42, h = 0.4 } },
		{ seg = 18, steps = 3, up = FWD, capStart = 0, capEnd = 0.25, color = function(t, ex, ey, p)
			return P.body:Lerp(P.dorsal, math.clamp(p.Z * 1.2, 0, 1) * 0.7)
		end })
	local hem = {}
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local out = V(math.sin(a), 0, -math.cos(a))
		local base = out * 0.86 + V(0, -0.7, 0)
		local tip = out * 1.0 + V(0, -1.05, 0)
		local perp = V(-out.Z, 0, out.X) * 0.2
		table.insert(hem, sheet({ base - perp, tip, base + perp, base + V(0, 0.12, 0) }, 0.05, i % 2 == 0 and P.body or P.dorsal))
	end
	addPart(bp, "Head", "Torso", "Neck", hp, merge({ hood, table.unpack(hem) }), { material = "Fabric" })
	-- rosto de panda no capuz
	local face = {}
	local eyes = {}
	for _, side in ipairs({ -1, 1 }) do
		local c = V(side * 0.3, 0.12, -0.84)
		table.insert(face, loft({ { p = c + V(0, 0, 0.12), w = 0.22, h = 0.18 }, { p = c + V(0, 0, 0.02), w = 0.22, h = 0.18 } }, { seg = 12, steps = 1, capEnd = 0.05, color = solid(dark) }))
		local n = V(side * 0.3, 0.05, -1)
		table.insert(face, eyeGeom(P, c + V(0, 0.01, -0.03), n, 0.12, { sclera = WHITE, iris = rgb(120, 120, 130) }))
		table.insert(eyes, { c = c + V(0, 0.01, -0.03), n = n.Unit, r = 0.12 })
		table.insert(face, loft({ { p = V(side * 0.58, 0.72, 0.02), w = 0.2, h = 0.08 }, { p = V(side * 0.68, 0.92, 0.04), w = 0.2, h = 0.08 } }, { seg = 10, steps = 1, up = FWD, capEnd = 0.12, color = solid(dark) }))
	end
	table.insert(face, loft({ { p = V(0, -0.08, -0.82), w = 0.22, h = 0.15 }, { p = V(0, -0.1, -0.95), w = 0.2, h = 0.13 } }, { seg = 12, steps = 1, capEnd = 0.06, color = solid(WHITE) }))
	table.insert(face, loft({ { p = V(0, -0.03, -0.98), w = 0.08, h = 0.05 }, { p = V(0, -0.03, -1.03), w = 0.07, h = 0.045 } }, { seg = 8, steps = 1, capEnd = 0.03, color = solid(dark) }))
	addPart(bp, "Face", "Head", nil, hp, merge(face), { material = "SmoothPlastic", role = "Eye", reflectance = 0.1 })
	addLids(bp, P, hp, eyes, dark)
	-- broto
	addPart(bp, "EarL", "Head", "EarL", hp + V(0, 0.95, 0.04), merge({
		loft({ { p = V(0, -0.1, 0), w = 0.04 }, { p = V(0, 0.25, 0), w = 0.035 } }, { seg = 6, steps = 1, up = FWD, color = solid(darker(P.accent, 0.8)) }),
		sheet({ V(0, 0.2, 0), V(-0.24, 0.8, 0), V(0, 1.45, 0.02), V(0.24, 0.8, 0) }, 0.04, P.accent),
	}), { material = "SmoothPlastic", role = "Accent" })
	for _, side in ipairs({ -1, 1 }) do
		local t = side < 0 and "L" or "R"
		local sh = V(side * 0.82, 0.05, -0.1)
		local el = V(side * 0.42, 0.12, -0.05)
		addPart(bp, "UpperArm" .. t, "Torso", "Arm" .. t, sh, loft({ { p = V(-side * 0.1, 0, 0), w = 0.17 }, { p = el, w = 0.15 } }, { seg = 10, steps = 1, color = solid(dark) }), { role = "Detail" })
		local claws = { loft({ { p = V(0, 0, 0), w = 0.15 }, { p = V(side * 0.12, 0.42, -0.05), w = 0.16 } }, { seg = 10, steps = 1, capEnd = 0.12, color = solid(dark) }) }
		for f = -1, 1 do
			local b = V(side * 0.12 + f * 0.09, 0.52, -0.05)
			table.insert(claws, loft({ { p = b, w = 0.05 }, { p = b + V(f * 0.06 + side * 0.04, 0.24, -0.03), w = 0.035 } }, { seg = 6, steps = 1, capEnd = 0.035, color = solid(rgb(226, 226, 222)) }))
		end
		addPart(bp, "Forearm" .. t, "UpperArm" .. t, "Elbow" .. t, sh + el, merge(claws), { role = "Detail" })
		local hip = V(side * 0.36, -0.62, 0)
		addPart(bp, "Thigh" .. t, "Torso", "Leg" .. t, hip, loft({ { p = V(0, 0.05, 0), w = 0.24, h = 0.24 }, { p = V(0, -0.28, -0.05), w = 0.24, h = 0.3 } },
			{ seg = 12, steps = 1, up = FWD, capEnd = 0.12, color = solid(dark) }), { role = "Detail" })
	end
	bp.hover = 0.62 + 0.42
	bp.gait = "biped"
end

-- Mamute (2ª leva do Mundo 1): corpo pesado, tromba em cadeia, presas curvas e pelagem de capim.
local function mammoth(bp, P, m)
	local coat = P.accent
	local Q = tune(PetAnatomy.Presets.heavy, { stocky = true }, "heavy")
	Q.L, Q.legLen, Q.legT, Q.neckLen, Q.neckAng = 2.6, 1.05, 0.24, 0.32, 0
	Q.head = copy(Q.head)
	Q.head.mLen, Q.head.mW, Q.head.mH = 0.2, 0.2, 0.2
	Q.ears = { kind = "round", size = 1.3 }
	Q.tail = { kind = "thin", len = 0.6, t = 0.06, ang = -40, curl = 10 }
	Q.foot = "pad"
	quadruped(bp, P, Q, m)
	local hp = bp.byName.Head.pivot
	local hd = Q.head
	local front = V(0, -hd.stop - 0.02, -hd.len * 0.5 - hd.mLen - 0.02)
	-- tromba em 3 partes (Trunk1..3)
	local prev, at = "Head", hp + front
	local dirs = { V(0, -0.55, -0.6), V(0, -0.85, -0.2), V(0, -0.75, -0.05) }
	for i = 1, 3 do
		local d = dirs[i].Unit * 0.42
		local r0, r1 = 0.17 - (i - 1) * 0.035, 0.17 - i * 0.035
		addPart(bp, "Trunk" .. i, prev, "Trunk" .. i, at, loft({ { p = -d * 0.15, w = r0, h = r0 }, { p = d, w = r1, h = r1 } },
			{ seg = 10, steps = 2, capStart = 0, capEnd = i == 3 and r1 * 0.8 or 0, color = function(t, ex, ey, p)
				return math.sin(p.Y * 30) > 0.6 and darker(P.body, 0.85) or P.body
			end }), { material = "Fabric" })
		prev, at = "Trunk" .. i, at + d
	end
	local tusks = {}
	for _, side in ipairs({ -1, 1 }) do
		local base = front + V(side * 0.16, -0.08, 0.12)
		table.insert(tusks, loft({ { p = base, w = 0.07 }, { p = base + V(side * 0.12, -0.3, -0.3), w = 0.06 }, { p = base + V(side * 0.18, -0.25, -0.62), w = 0.04 }, { p = base + V(side * 0.1, 0.05, -0.8), w = 0.01 } },
			{ seg = 9, steps = 3, capEnd = 0.01, color = solid(m.tusk or rgb(242, 234, 214)) }))
	end
	addPart(bp, "Tusks", "Head", nil, hp, merge(tusks), { material = "SmoothPlastic", role = "Detail" })
	-- pelagem de capim: fios que caem pelas laterais e franja na testa
	local strands = {}
	local shades = { darker(coat, 0.7), darker(coat, 0.85), coat, coat:Lerp(rgb(230, 220, 120), 0.3) }
	-- modo de peças: as placas finas viravam lâminas gigantes; lá a pelagem é uma "saia" felpuda contínua
	-- que cobre o tronco e cai sobre o alto das pernas (bordas recortadas = tufos)
	for row = 0, MeshKit.low and -1 or 5 do
		local z = (row - 2.5) * 0.42
		for _, phi in ipairs({ -80, -55, -30, 30, 55, 80 }) do
			local s = math.sin(rad(phi))
			local anchor = V(s * 0.72, math.cos(rad(phi)) * 0.62 + 0.15, z)
			local len = 0.8 + math.abs(s) * 0.55 + ((row * 7 + phi) % 5) * 0.04
			local tip = anchor + V(s * 0.25, -len, 0.05)
			local perp = V(0, 0, 0.12) -- fios mais finos (antes 0.18: pareciam folhas largas)
			table.insert(strands, sheet({ anchor - perp, tip - perp * 0.3, tip + V(0, -0.08, 0), tip + perp * 0.3, anchor + perp }, 0.04, shades[(row + math.floor(math.abs(phi) / 25)) % 4 + 1],
				V(s, 0.3, 0).Unit))
		end
	end
	table.insert(strands, loft({ { p = V(0, 0.55, -0.9), w = 0.62, h = 0.18, jag = 0.25 }, { p = V(0, 0.62, 0.9), w = 0.62, h = 0.2, jag = 0.25 } }, { seg = 14, steps = 3, color = solid(shades[2]) }))
	if MeshKit.low then
		-- manta de capim sobre o dorso (até o meio do flanco) + franja de tufos pendurados nas laterais
		table.insert(strands, loft({ { p = V(0, 0.2, -1.0), w = 0.62, h = 0.6, hb = 0.36 }, { p = V(0, 0.22, -0.5), w = 0.78, h = 0.64, hb = 0.48 },
			{ p = V(0, 0.22, 0.1), w = 0.82, h = 0.66, hb = 0.5 }, { p = V(0, 0.21, 0.7), w = 0.76, h = 0.62, hb = 0.48 }, { p = V(0, 0.19, 1.05), w = 0.58, h = 0.54, hb = 0.36 } },
			{ seg = 14, steps = 1, detail = true, capStart = 0.14, capEnd = 0.14, color = function(_t, _ex, ey)
				return ey < -0.4 and shades[2] or shades[3]
			end }))
		for k = 0, 5 do
			local z = -0.85 + k * 0.34
			for _, side in ipairs({ -1, 1 }) do
				local top = V(side * 0.74, -0.12, z + (side > 0 and 0.08 or -0.08))
				local tip = top + V(side * 0.1, -0.42 - (k % 3) * 0.06, 0.04)
				table.insert(strands, loft({ { p = top, w = 0.13, h = 0.09 }, { p = tip, w = 0.02, h = 0.02 } },
					{ seg = 4, steps = 1, up = FWD, capStart = 0, capEnd = 0.01, color = solid(shades[(k + (side > 0 and 1 or 0)) % 2 == 0 and 1 or 4]) }))
			end
		end
	end
	addPart(bp, "Coat", "Torso", nil, V(0, 0, 0), merge(strands), { material = "Fabric", role = "Accent" })
	local fringe = {}
	for i, x in ipairs({ -0.3, -0.15, 0.0, 0.32 }) do
		local a = V(x, hd.h * 0.9, -0.05)
		table.insert(fringe, sheet({ a - V(0.08, 0, 0), a + V(x * 0.1, -0.55, -0.32), a + V(0.08, 0, 0) }, 0.04, shades[i % 4 + 1], V(0, 0.3, -1).Unit))
	end
	addPart(bp, "Fringe", "Head", nil, hp, merge(fringe), { material = "Grass", role = "Accent" })
end

-- Cabra-arbusto (2ª leva do Mundo 1): corpo fofo e redondo, arbusto de folhas com frutinhas nas costas.
local function bushGoat(bp, P, m)
	local Q = tune(PetAnatomy.Presets.caprine, { stocky = true }, "caprine")
	Q.L, Q.cw, Q.ch, Q.ww, Q.wh, Q.hw, Q.hh = 1.8, 0.6, 0.66, 0.6, 0.64, 0.56, 0.6
	Q.legLen, Q.legT, Q.neckLen = 0.75, 0.13, 0.35
	Q.ears = { kind = "floppy", size = 1.3 }
	Q.horns = "straight"
	Q.head = copy(Q.head)
	Q.head.beard = false
	Q.head.w, Q.head.h = 0.3, 0.28
	quadruped(bp, P, Q, m)
	local berry = m.berry or rgb(220, 50, 76)
	local bush = m.bush or P.accent
	local list = {}
	local c = V(0, 0.95, 0.15)
	for i = 1, 40 do
		local y = 1 - (i - 0.5) / 40 * 1.6
		local r = math.sqrt(math.max(0, 1 - y * y))
		local th = i * 2.39996
		local n = V(math.cos(th) * r, y, math.sin(th) * r)
		local base = c + V(n.X * 0.62, n.Y * 0.5, n.Z * 0.62)
		local tip = base + (n + V(0, -0.6, 0)).Unit * 0.38
		local perp = n:Cross(tip - base)
		perp = perp.Magnitude > 1e-3 and perp.Unit * 0.13 or V(0.13, 0, 0)
		table.insert(list, sheet({ base, (base + tip) / 2 + perp, tip, (base + tip) / 2 - perp }, 0.03, i % 3 == 0 and bush:Lerp(WHITE, 0.15) or bush))
	end
	table.insert(list, loft({ { p = c - V(0, 0.42, 0), w = 0.6, h = 0.6 }, { p = c + V(0, 0.38, 0), w = 0.5, h = 0.5 } }, { seg = 14, steps = 2, up = FWD, capEnd = 0.3, color = solid(darker(bush, 0.75)) }))
	local berries = {}
	for i = 1, 10 do
		local y = 0.85 - (i - 0.5) / 10 * 1.3
		local r = math.sqrt(math.max(0, 1 - y * y))
		local th = i * 4.08
		local n = V(math.cos(th) * r, y, math.sin(th) * r)
		local p = c + V(n.X * 0.74, n.Y * 0.6, n.Z * 0.74)
		table.insert(berries, loft({ { p = p - n * 0.05, w = 0.08 }, { p = p + n * 0.04, w = 0.08 } }, { seg = 8, steps = 1, capStart = 0.05, capEnd = 0.06, color = solid(berry) }))
	end
	addPart(bp, "Bush", "Torso", nil, V(0, 0, 0), merge(list), { material = "Grass", role = "Accent" })
	addPart(bp, "Berries", "Torso", nil, V(0, 0, 0), merge(berries), { material = "SmoothPlastic", role = "Detail", reflectance = 0.15 })
end

-------------------------------------------------------------------------------
-- RARIDADE: detalhes exclusivos (não só aura)
--   Incomum: meias e máscara claras (paleta)       Raro: peitoral de pelo, pontas escuras (paleta/quadrúpede)
--   Épico: marcas que brilham no dorso e gema na testa
--   Lendário: diadema e braceletes de ouro, brilho dourado e luz
--   Mítico: fitas etéreas (ForceField) e runas orbitando, rastro
--   Secret: pelagem estrelada, coroa de cristais, aura   Celestial: auréola de luz
-------------------------------------------------------------------------------

local function ring(center: Vector3, radius: number, tube: number, n: number, color: Color3, tilt: number?)
	if MeshKit.low then
		n = math.max(6, math.floor(n / 2))
	end
	local keys = {}
	local cf = CFrame.new(center) * CFrame.Angles(rad(tilt or 0), 0, 0)
	for i = 0, n do
		local a = i / n * math.pi * 2 * 1.04
		table.insert(keys, { p = cf * V(math.cos(a) * radius, 0, math.sin(a) * radius), w = tube, h = tube })
	end
	return loft(keys, { seg = MeshKit.low and 4 or 8, steps = MeshKit.low and 1 or 2, capStart = 0, capEnd = 0, color = solid(color) })
end

local function topOf(part)
	local mn, mx = MeshKit.bounds(part.geom)
	return V((mn.X + mx.X) / 2, mx.Y, (mn.Z + mx.Z) / 2), (mx.X - mn.X) / 2, (mx.Z - mn.Z) / 2
end

function PetAnatomy.decorate(bp, P, tier: number)
	local torso = bp.byName.Torso
	local head = bp.byName.Head
	if not torso then
		return
	end
	local gold = rgb(255, 198, 70)
	local tTop, tW, tD = topOf(torso)
	local hTop, hW = tTop, tW
	if head then
		local ht, hw = topOf(head)
		hTop, hW = ht, hw
	end
	local crownPart = head and "Head" or "Torso"
	local crownAt = hTop
	if head then
		-- topo do crânio: média dos vértices mais altos da cabeça. O centro da caixa caía no meio do
		-- focinho em cabeças compridas (lobo, cervo) e a tiara ficava flutuando na frente da testa.
		local g = head.geom
		local _, mx = MeshKit.bounds(g)
		local sx, sz, n, wMax = 0, 0, 0, 0
		for _, v in ipairs(g.verts) do
			if v.Y > mx.Y - 0.08 then
				sx, sz, n = sx + v.X, sz + v.Z, n + 1
			end
		end
		if n > 0 then
			local cx, cz = sx / n, sz / n
			for _, v in ipairs(g.verts) do
				if v.Y > mx.Y - 0.14 then
					wMax = math.max(wMax, math.abs(v.X - cx), math.abs(v.Z - cz))
				end
			end
			crownAt = V(cx, mx.Y, cz)
			hTop = crownAt
			hW = math.max(0.08, wMax)
		end
	end
	if tier >= 4 then
		-- marcas brilhantes em "V" ao longo do dorso
		local marks = {}
		for i = lowDetail() and -1 or -2, lowDetail() and 1 or 2 do
			local z = tTop.Z + i * tD * 0.32
			local y = tTop.Y - math.abs(i) * 0.04 - 0.01
			marks[#marks + 1] = loft({ { p = V(-0.16, y - 0.05, z + 0.08), w = 0.025, h = 0.025 }, { p = V(0, y + 0.01, z - 0.05), w = 0.03, h = 0.03 }, { p = V(0.16, y - 0.05, z + 0.08), w = 0.025, h = 0.025 } },
				{ seg = MeshKit.low and 4 or 6, steps = MeshKit.low and 1 or 2, capStart = MeshKit.low and 0 or nil, capEnd = MeshKit.low and 0 or nil, color = solid(P.accent) })
		end
		addPart(bp, "GlowMarks", "Torso", nil, torso.pivot, merge(marks), { material = "Neon", role = "Glow" })
		if head then
			addPart(bp, "Gem", "Head", nil, head.pivot, loft({ { p = hTop + V(0, -0.04, -0.06), w = 0.07, h = 0.09, pow = 1.3 }, { p = hTop + V(0, 0.02, -0.12), w = 0.06, h = 0.08, pow = 1.3 } },
				{ seg = 4, steps = 1, flat = true, capEnd = 0.04, color = solid(P.accent:Lerp(WHITE, 0.2)) }), { material = "Glass", role = "Glow", reflectance = 0.3 })
		end
	end
	if tier >= 5 then
		addPart(bp, "Circlet", crownPart, nil, (head or torso).pivot, ring(crownAt - V(0, 0.09, 0), hW * 0.95, 0.03, 16, gold), { material = "Metal", role = "Detail", reflectance = 0.25 })
		for _, tag in ipairs({ "FL", "FR" }) do
			local lower = bp.byName["Lower" .. tag]
			if lower then
				local mn, mx = MeshKit.bounds(lower.geom)
				local c = V((mn.X + mx.X) / 2, mn.Y + (mx.Y - mn.Y) * 0.35, (mn.Z + mx.Z) / 2)
				addPart(bp, "Band" .. tag, "Lower" .. tag, nil, lower.pivot, ring(c, math.max(mx.X - mn.X, mx.Z - mn.Z) * 0.55, 0.03, 10, gold, 90), { material = "Metal", role = "Detail", reflectance = 0.25 })
			end
		end
		table.insert(bp.effects, { kind = "sparkles", part = "Torso", color = rgb(255, 226, 140) })
		table.insert(bp.effects, { kind = "light", part = "Torso", color = rgb(255, 220, 150) })
	end
	if tier >= 6 then
		local ribbons = {}
		for _, side in ipairs({ -1, 1 }) do
			local a = tTop + V(side * tW * 0.5, -0.05, -tD * 0.4)
			ribbons[#ribbons + 1] = loft({ { p = a, w = 0.12, h = 0.02 }, { p = a + V(side * 0.35, 0.25, tD * 0.6), w = 0.14, h = 0.02 }, { p = a + V(side * 0.6, 0.1, tD * 1.4), w = 0.08, h = 0.015 },
				{ p = a + V(side * 0.75, 0.3, tD * 2.0), w = 0.01, h = 0.01 } }, { seg = 6, steps = 4, color = function(t)
				return P.accent:Lerp(WHITE, 0.4 * (1 - t))
			end })
		end
		addPart(bp, "SpiritRibbons", "Torso", nil, torso.pivot, merge(ribbons), { material = "ForceField", role = "Glow", transparency = 0.15 })
		local runes = {}
		local R = tW * 1.6 + 0.5
		for i = 1, 4 do
			local ang = i / 4 * math.pi * 2
			local c = V(math.cos(ang) * R, 0, math.sin(ang) * R)
			runes[#runes + 1] = loft({ { p = c - V(0, 0.16, 0), w = 0.01, pow = 1.2 }, { p = c, w = 0.09, h = 0.05, pow = 1.2 }, { p = c + V(0, 0.16, 0), w = 0.01, pow = 1.2 } },
				{ seg = 4, steps = 1, up = FWD, flat = true, color = solid(P.accent) })
		end
		addPart(bp, "OrbitRunes", "Torso", "Orbit", torso.pivot + V(tTop.X, tTop.Y * 0.6, tTop.Z), merge(runes), { material = "Neon", role = "Glow" })
		table.insert(bp.effects, { kind = "trail", part = "Torso", color = P.accent })
	end
	if tier >= 7 then
		local spikes = {}
		for i = 1, 5 do
			local ang = (i - 3) * 0.42
			local base = crownAt + V(math.sin(ang) * hW * 0.55, -0.04, -math.cos(ang) * hW * 0.25)
			local h = 0.32 - math.abs(i - 3) * 0.06
			spikes[#spikes + 1] = loft({ { p = base, w = 0.05, h = 0.04, pow = 1.2 }, { p = base + V(math.sin(ang) * 0.06, h, 0), w = 0.005, pow = 1.2 } }, { seg = 4, steps = 1, flat = true,
				color = solid(i == 3 and P.accent:Lerp(WHITE, 0.4) or P.accent) })
		end
		addPart(bp, "Crown", crownPart, nil, (head or torso).pivot, merge(spikes), { material = "Glass", role = "Glow", reflectance = 0.2 })
		table.insert(bp.effects, { kind = "aura", part = "Torso", color = P.accent })
	end
	if tier >= 8 then
		addPart(bp, "Halo", crownPart, "Orbit2", (head or torso).pivot + crownAt + V(0, 0.35, 0), ring(V(0, 0, 0), hW * 0.7 + 0.1, 0.04, 18, rgb(255, 246, 200)), { material = "Neon", role = "Glow" })
	end
end

-------------------------------------------------------------------------------
-- Entrada: espécie → planta pronta (escalada)
-------------------------------------------------------------------------------

local GAIT = { lagomorph = "hop", squirrel = "hop", amphibian = "hop" }

local function scaleBP(bp, u: number)
	for _, p in ipairs(bp.parts) do
		p.pivot *= u
		local g = p.geom
		local verts = table.create(#g.verts)
		for i, v in ipairs(g.verts) do
			verts[i] = v * u
		end
		p.geom = { verts = verts, colors = g.colors, tris = g.tris, flat = g.flat, keep = g.keep }
		if p.attrs and p.attrs.BlinkVec then
			p.attrs = { BlinkVec = p.attrs.BlinkVec * u }
		end
	end
	bp.hover *= u
	bp.scale = u
end

local buildBlueprint

-- opts.low = true: mesma anatomia em resolução baixa (modo de peças, sem EditableMesh)
function PetAnatomy.blueprint(speciesId: string, species, scaleMul: number?, opts)
	if opts and opts.low then
		MeshKit.low = true
		MeshKit.mid = opts.mid == true
		local ok, res = pcall(buildBlueprint, speciesId, species, scaleMul)
		MeshKit.low, MeshKit.mid, MeshKit.focus = false, false, false
		if not ok then
			error(res, 0)
		end
		return res
	end
	return buildBlueprint(speciesId, species, scaleMul)
end

buildBlueprint = function(speciesId: string, species, scaleMul: number?)
	local m = species.model or {}
	local tier = PetAnatomy.RarityTier[species.rarity] or 1
	local P = palette(m, tier)
	if speciesId:find("tiger") then
		P.stripes, P.stripeColor = 6, darker(P.body, 0.22)
	elseif speciesId:find("panther") or speciesId:find("lynx") then
		P.spots, P.spotColor = true, darker(P.body, 0.55)
	elseif speciesId:find("fawn") then
		P.spots, P.spotColor = true, P.belly:Lerp(WHITE, 0.5)
	end
	local kind, preset = PetAnatomy.classify(speciesId, species)
	-- pets "fofos" ganham bochechas rosadas (os imponentes, como lobo, leão e cervo, não)
	local CUTE = { fox = true, feline = true, pup = true, lagomorph = true, rodent = true, squirrel = true, mustelid = true, leafpanda = true,
		shroom = true, slime = true, avian = true, amphibian = true, canine = true, bushgoat = true, caprine = true }
	P.blush = CUTE[preset or kind] == true
	local bp = newBP(preset or kind)
	bp.kind = kind
	if kind == "quad" or kind == "dragon" then
		local base = preset
		if preset == "griffin" or preset == "tiger" then
			base = "lion"
		end
		local Q = tune(PetAnatomy.Presets[base], m, base)
		if preset == "griffin" then
			Q.mane, Q.ears = false, { kind = "none" }
			Q.wings = Q.wings or "feather"
			Q.wingSpan = (m.wingSpan or 1.3) * 1.1
		elseif preset == "tiger" then
			Q.mane = false
			Q.ears = { kind = "round", size = 0.75 }
		end
		if kind == "dragon" then
			Q.wings = m.wings == "crystal" and "crystal" or (m.wings == "leaf" and "leaf" or "dragon")
			Q.wingSpan = 1.35
			Q.horns = m.horns == "antlers" and "antlers" or (m.horns == "crystal" and "crystal" or "straight")
			if m.tail == "leaf" then
				Q.tail = { kind = "leaf" }
			end
		end
		if preset == "griffin" then
			m = table.clone(m)
			m.beak = true
		end
		quadruped(bp, P, Q, m)
		bp.gait = GAIT[preset] or "quad"
	elseif kind == "avian" then
		avian(bp, P, m, speciesId)
	elseif kind == "bat" then
		bat(bp, P, m)
	elseif kind == "moth" then
		moth(bp, P, m)
	elseif kind == "serpent" then
		serpent(bp, P, m)
	elseif kind == "insect" then
		insect(bp, P, m)
	elseif kind == "slime" then
		slime(bp, P, m)
	elseif kind == "shroom" then
		shroom(bp, P, m)
	elseif kind == "golem" then
		golem(bp, P, m, speciesId)
	elseif kind == "treant" then
		treant(bp, P, m)
	elseif kind == "floater" then
		floater(bp, P, m, speciesId)
	elseif kind == "leafpanda" then
		leafPanda(bp, P, m)
	elseif kind == "mammoth" then
		mammoth(bp, P, m)
		bp.gait = "quad"
	elseif kind == "bushgoat" then
		bushGoat(bp, P, m)
		bp.gait = "quad"
	else
		biped(bp, P, m)
	end
	if bp._eyes and not bp.byName.LidL then
		addLids(bp, P, V(0, 0, 0), bp._eyes, P.body, "Torso")
	end
	PetAnatomy.decorate(bp, P, tier)
	-- índice por nome (algumas plantas renomeiam partes)
	bp.byName = {}
	for _, p in ipairs(bp.parts) do
		bp.byName[p.name] = p
	end
	scaleBP(bp, (m.size or 1) * (scaleMul or 1) * 1.1)
	bp.flies = m.rig == "flyer" or m.rig == "floater"
	bp.tier = tier
	bp.species = speciesId
	return bp
end

-- Contagem de triângulos (orçamento/testes).
function PetAnatomy.triangles(bp, kept: boolean?): number
	local n = 0
	for _, p in ipairs(bp.parts) do
		n += kept and MeshKit.keptCount(p.geom) or #p.geom.tris
	end
	return n
end

return PetAnatomy

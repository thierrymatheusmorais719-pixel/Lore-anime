-- MODELOS LISOS SEM EditableMesh: transforma a geometria de uma parte do corpo (MeshKit) numa fileira de
-- ELIPSOIDES (esferas esticadas) que se sobrepõem, como contas. No Roblox cada elipsoide é uma Part com
-- SpecialMesh do tipo Sphere: a superfície é redonda e lisa, sem as faces triangulares das cunhas.
--
-- Como funciona, para cada pedaço conexo da geometria (o tronco, uma orelha, um olho...):
--   1. acha os 3 eixos principais do pedaço (PCA: autovetores da covariância dos vértices);
--   2. se o pedaço é comprido, fatia ao longo do eixo maior; cada fatia vira um elipsoide com o centro
--      e a largura/altura locais (acompanha a curva de um pescoço ou o afinar de uma perna);
--   3. a cor é a média dos vértices; se a parte de baixo tem outra cor (barriga, focinho claro), ganha
--      um segundo elipsoide menor por baixo com essa cor;
--   4. adesivos dos olhos (camadas de globo, íris, pupila e brilho coladas na cabeça) viram "cúpulas"
--      achatadas que saem da cabeça, uma acima da outra.
--
-- Função pura (só Vector3/CFrame/Color3): usada pelo PetMesh/BossMesh no cliente e pelas prévias/testes.

local Facets = require(script.Parent.Facets)

local Smooth = {}

export type Blob = { cf: CFrame, size: Vector3, color: Color3 }

-- Autovalores/autovetores de uma matriz simétrica 3x3 (método de Jacobi).
local function jacobi(a)
	local v = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
	for _ = 1, 24 do
		local p, q, big = 1, 2, math.abs(a[1][2])
		if math.abs(a[1][3]) > big then
			p, q, big = 1, 3, math.abs(a[1][3])
		end
		if math.abs(a[2][3]) > big then
			p, q, big = 2, 3, math.abs(a[2][3])
		end
		if big < 1e-12 then
			break
		end
		local theta = (a[q][q] - a[p][p]) / (2 * a[p][q])
		local t = (theta >= 0 and 1 or -1) / (math.abs(theta) + math.sqrt(theta * theta + 1))
		local c = 1 / math.sqrt(t * t + 1)
		local s = t * c
		for k = 1, 3 do
			local akp, akq = a[k][p], a[k][q]
			a[k][p], a[k][q] = c * akp - s * akq, s * akp + c * akq
		end
		for k = 1, 3 do
			local apk, aqk = a[p][k], a[q][k]
			a[p][k], a[q][k] = c * apk - s * aqk, s * apk + c * aqk
		end
		for k = 1, 3 do
			local vkp, vkq = v[k][p], v[k][q]
			v[k][p], v[k][q] = c * vkp - s * vkq, s * vkp + c * vkq
		end
	end
	local out = {}
	for i = 1, 3 do
		table.insert(out, { val = a[i][i], vec = Vector3.new(v[1][i], v[2][i], v[3][i]) })
	end
	table.sort(out, function(x, y)
		return x.val > y.val
	end)
	return out[1].vec, out[2].vec, out[3].vec
end
Smooth._jacobi = jacobi

-- Pedaços conexos (pelos triângulos visíveis; vértices na mesma posição contam como o mesmo).
local function components(g)
	local parent = {}
	local function find(i)
		while parent[i] ~= i do
			parent[i] = parent[parent[i]]
			i = parent[i]
		end
		return i
	end
	local function union(a, b)
		local ra, rb = find(a), find(b)
		if ra ~= rb then
			parent[ra] = rb
		end
	end
	local used = {}
	for i, t in ipairs(g.tris) do
		if not g.keep or g.keep[i] then
			for k = 1, 3 do
				local vi = t[k]
				if not used[vi] then
					used[vi] = true
					parent[vi] = vi
				end
			end
			union(t[1], t[2])
			union(t[1], t[3])
		end
	end
	local byPos = {}
	for vi in pairs(used) do
		local v = g.verts[vi]
		local key = string.format("%d,%d,%d", math.floor(v.X * 400 + 0.5), math.floor(v.Y * 400 + 0.5), math.floor(v.Z * 400 + 0.5))
		if byPos[key] then
			union(vi, byPos[key])
		else
			byPos[key] = vi
		end
	end
	local groups, order = {}, {}
	local idx = {}
	for vi in pairs(used) do
		table.insert(idx, vi)
	end
	table.sort(idx) -- ordem estável (o resultado não depende da ordem da tabela)
	for _, vi in ipairs(idx) do
		local r = find(vi)
		if not groups[r] then
			groups[r] = {}
			table.insert(order, r)
		end
		table.insert(groups[r], vi)
	end
	local list = {}
	for _, r in ipairs(order) do
		table.insert(list, groups[r])
	end
	return list
end
Smooth._components = components

local function frameOf(pts)
	local n = #pts
	local c = Vector3.zero
	for _, p in ipairs(pts) do
		c += p
	end
	c /= n
	local xx, xy, xz, yy, yz, zz = 0, 0, 0, 0, 0, 0
	for _, p in ipairs(pts) do
		local d = p - c
		xx += d.X * d.X
		xy += d.X * d.Y
		xz += d.X * d.Z
		yy += d.Y * d.Y
		yz += d.Y * d.Z
		zz += d.Z * d.Z
	end
	local e1, e2, e3 = jacobi({ { xx, xy, xz }, { xy, yy, yz }, { xz, yz, zz } })
	-- base direita (determinante +1), senão o CFrame espelha
	if e1:Cross(e2):Dot(e3) < 0 then
		e3 = -e3
	end
	return c, e1.Unit, e2.Unit, e3.Unit
end

local function avg(cols): Color3
	local r, g, b = 0, 0, 0
	for _, c in ipairs(cols) do
		r, g, b = r + c.R, g + c.G, b + c.B
	end
	local n = math.max(#cols, 1)
	return Color3.new(r / n, g / n, b / n)
end

local function mix2(a: Color3, b: Color3): Color3
	return Color3.new((a.R + b.R) / 2, (a.G + b.G) / 2, (a.B + b.B) / 2)
end

local function dist(a: Color3, b: Color3): number
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B)
end

local function blob(center: Vector3, e1: Vector3, e2: Vector3, e3: Vector3, h1: number, h2: number, h3: number, color: Color3, minHalf: number): Blob
	-- CFrame com X = e1, Y = e2, Z = e3 (o tamanho da peça segue esses eixos)
	return {
		cf = CFrame.fromMatrix(center, e1, e2, e3),
		size = Vector3.new(math.max(h1, minHalf) * 2, math.max(h2, minHalf) * 2, math.max(h3, minHalf) * 2),
		color = color,
	}
end

--[[ Elipsoides de uma geometria (coordenadas da própria geometria + `offset`).
	opts = {
		density = contas por "diâmetro" ao longo do eixo maior (1 = leve, 1.5 = alta qualidade),
		maxBeads = máximo de contas por pedaço,
		decal = true para adesivos colados numa superfície (olhos): cúpulas achatadas,
		ref = ponto de referência "de dentro" (centro da cabeça) para saber para onde a cúpula sai,
		minHalf = meia-espessura mínima (studs),
		belly = false desliga o segundo tom por baixo,
	} ]]
function Smooth.blobs(g, offset: Vector3?, opts): { Blob }
	opts = opts or {}
	offset = offset or Vector3.zero
	local density = opts.density or 1
	local maxBeads = opts.maxBeads or 10
	local minHalf = opts.minHalf or 0.012
	local out = {}
	-- elipsoides de um conjunto de pontos (um pedaço; depth 1 = setor de um anel)
	local function emit(pts, cols, depth: number, puff: number?)
		if #pts < 3 then
			return
		end
		local c, e1, e2, e3 = frameOf(pts)
		local t1, t2, t3 = {}, {}, {}
		local lo1, hi1, lo2, hi2, lo3, hi3 = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
		for i, p in ipairs(pts) do
			local d = p - c
			t1[i], t2[i], t3[i] = d:Dot(e1), d:Dot(e2), d:Dot(e3)
			lo1, hi1 = math.min(lo1, t1[i]), math.max(hi1, t1[i])
			lo2, hi2 = math.min(lo2, t2[i]), math.max(hi2, t2[i])
			lo3, hi3 = math.min(lo3, t3[i]), math.max(hi3, t3[i])
		end
		local L1, L2, L3 = hi1 - lo1, hi2 - lo2, hi3 - lo3
		-- JUBA/GOLA maciça em volta do pescoço (opts.radial): vira tufos em volta do eixo maior, só com a casca
		-- de fora (o miolo e a ponta da frente ficam vazios e o rosto aparece)
		if depth == 0 and opts.radial and #pts >= 24 then
			local rmax = 0
			for i = 1, #pts do
				rmax = math.max(rmax, math.sqrt(t2[i] ^ 2 + t3[i] ^ 2))
			end
			local K = 10
			local sp, sc = {}, {}
			for k = 1, K do
				sp[k], sc[k] = {}, {}
			end
			for i = 1, #pts do
				local r = math.sqrt(t2[i] ^ 2 + t3[i] ^ 2)
				if r > rmax * 0.55 then
					local a = math.atan2(t3[i], t2[i]) + math.pi
					local k = math.clamp(math.floor(a / (2 * math.pi) * K) + 1, 1, K)
					table.insert(sp[k], pts[i])
					table.insert(sc[k], cols[i])
				end
			end
			for k = 1, K do
				emit(sp[k], sc[k], 1, 1.8) -- tufos cheios (a casca sozinha é fina)
			end
			return
		end
		-- ANEL (juba, gola, auréola, coroa): oco no meio; uma única conta tamparia o furo (a juba virava uma
		-- boia por cima da cabeça). Divide em setores em volta do furo e cada setor vira suas contas.
		if depth == 0 and #pts >= 24 and not (opts.decal and L3 < 0.3 * L1) then
			local rmin, rmax = math.huge, 0
			local ox, oy = (lo1 + hi1) / 2, (lo2 + hi2) / 2
			for i = 1, #pts do
				local r = math.sqrt((t1[i] - ox) ^ 2 + (t2[i] - oy) ^ 2)
				rmin, rmax = math.min(rmin, r), math.max(rmax, r)
			end
			if rmax > 1e-3 and rmin > rmax * 0.4 and L3 < L1 * 0.8 then
				local rmid = (rmin + rmax) / 2
				local thick = math.max(rmax - rmin, L3, 1e-3)
				local K = math.clamp(math.floor(2 * math.pi * rmid / (thick * 1.1) + 0.5), 6, 16)
				local sp, sc = {}, {}
				for k = 1, K do
					sp[k], sc[k] = {}, {}
				end
				for i = 1, #pts do
					local a = math.atan2(t2[i] - oy, t1[i] - ox) + math.pi
					local k = math.clamp(math.floor(a / (2 * math.pi) * K) + 1, 1, K)
					table.insert(sp[k], pts[i])
					table.insert(sc[k], cols[i])
				end
				for k = 1, K do
					emit(sp[k], sc[k], 1)
				end
				return
			end
		end
		if opts.decal and L3 < 0.3 * L1 then
			-- adesivo (camada do olho, bochecha): pedaço achatado vira cúpula: cúpula achatada saindo da superfície
			local nrm = e3
			local ref = opts.ref or (c - nrm)
			if (c - ref):Dot(nrm) < 0 then
				nrm = -nrm
			end
			local top = -math.huge
			for _, p in ipairs(pts) do
				top = math.max(top, (p - c):Dot(nrm))
			end
			local mid = c + e1 * (lo1 + hi1) / 2 + e2 * (lo2 + hi2) / 2
			mid = mid - nrm * (mid - c):Dot(nrm) + nrm * top
			local half = math.max(L1, L2) / 2
			local ee3 = nrm
			local ee1 = e1
			local ee2 = ee3:Cross(ee1).Unit
			table.insert(out, blob(mid, ee1, ee2, ee3, L1 / 2, L2 / 2, math.max(half * 0.2, minHalf), avg(cols), minHalf)) -- fininho: olho "pintado" e brilhante
		else
			local cross = math.max(L2, L3, 1e-3)
			-- poucas formas GRANDES por pedaço (estilo Palworld: superfície contínua, sem "gomos"):
			-- 1 elipsoide se o pedaço é atarracado; 2 a 4 bem sobrepostos se é comprido (pernas, rabo)
			local n = 1
			local ratio = L1 / cross
			if ratio > 1.35 then
				n = math.clamp(math.floor(ratio * 0.5 * density + 0.5), 2, maxBeads)
			end
			-- achatado e comprido (orelha, folha, pétala): UMA folha alongada e mais fina que a base (silhueta
			-- de orelha pontuda; várias contas viravam "bolinhas empilhadas")
			-- pedaço que AFINA muito (focinho saindo do crânio, rabo): 3 formas acompanham o afinar
			if n == 2 then
				local th = {}
				for k = 1, 3 do
					th[k] = { a = math.huge, b = -math.huge, c = math.huge, d = -math.huge }
				end
				for i = 1, #pts do
					local k = math.clamp(math.floor((t1[i] - lo1) / math.max(L1, 1e-6) * 3) + 1, 1, 3)
					local q = th[k]
					q.a, q.b = math.min(q.a, t2[i]), math.max(q.b, t2[i])
					q.c, q.d = math.min(q.c, t3[i]), math.max(q.d, t3[i])
				end
				-- largura de cada terço (a maior das duas medidas transversais)
				local a = math.max(th[1].b - th[1].a, th[1].d - th[1].c)
				local b = math.max(th[3].b - th[3].a, th[3].d - th[3].c)
				if a > 0 and b > 0 and math.max(a, b) / math.min(a, b) > 1.3 then
					n = math.min(3, maxBeads + 1)
				end
			end
			local flatPiece = L3 < math.max(L2, 1e-3) * 0.45 and L1 > L2 * 1.15
			if flatPiece then
				n = 1
			end
			local s = L1 / n
			-- 1) medidas de cada conta (centro e largura locais)
			local beads = {}
			for k = 0, n - 1 do
				local tc = lo1 + (k + 0.5) * s
				local w = n == 1 and math.huge or s * 0.35
				local a2lo, a2hi, a3lo, a3hi = math.huge, -math.huge, math.huge, -math.huge
				local wc, idx = {}, {}
				for i = 1, #pts do
					if math.abs(t1[i] - tc) <= w then
						a2lo, a2hi = math.min(a2lo, t2[i]), math.max(a2hi, t2[i])
						a3lo, a3hi = math.min(a3lo, t3[i]), math.max(a3hi, t3[i])
						table.insert(wc, cols[i])
						table.insert(idx, i)
					end
				end
				if #idx > 0 then
					local h1
					if n == 1 then
						h1 = L1 / 2
					else
						-- contas se sobrepõem (sem "gomos" fundos); nas pontas não passam do fim do pedaço
						h1 = math.min(s * 1.1, (tc - lo1) + s * 0.15, (hi1 - tc) + s * 0.15)
					end
					local grow = (n == 1 and 1 or 1.04) * (puff or 1)
					if flatPiece then
						grow *= 0.72 -- folha: mais fina que a largura da base
					end
					table.insert(beads, { tc = tc, h1 = h1, h2 = (a2hi - a2lo) / 2 * grow, h3 = (a3hi - a3lo) / 2 * grow, m2 = (a2lo + a2hi) / 2, m3 = (a3lo + a3hi) / 2,
						wc = wc, idx = idx })
				end
			end
			-- 2) suaviza largura e centro entre vizinhas (as pontas ficam como estão): some o efeito de "gomos"
			if #beads >= 3 then
				local sm = {}
				for i = 2, #beads - 1 do
					local A, B, C = beads[i - 1], beads[i], beads[i + 1]
					sm[i] = {
						h2 = math.max(B.h2, (A.h2 + 2 * B.h2 + C.h2) / 4), h3 = math.max(B.h3, (A.h3 + 2 * B.h3 + C.h3) / 4),
						m2 = (A.m2 + 2 * B.m2 + C.m2) / 4, m3 = (A.m3 + 2 * B.m3 + C.m3) / 4,
					}
				end
				for i, v in pairs(sm) do
					beads[i].h2, beads[i].h3, beads[i].m2, beads[i].m3 = v.h2, v.h3, v.m2, v.m3
				end
			end
			-- 3) elipsoides (e o segundo tom por baixo: barriga, peito, focinho claro)
			for _, bd in ipairs(beads) do
				local h1, h2, h3 = bd.h1, bd.h2, bd.h3
				local center = c + e1 * bd.tc + e2 * bd.m2 + e3 * bd.m3
				local color = avg(bd.wc)
				local addBelly = nil
				if opts.belly ~= false and #bd.idx >= 6 then
					local vert = math.abs(e2.Y) >= math.abs(e3.Y) and 2 or 3
					local axis = vert == 2 and e2 or e3
					local hv = vert == 2 and h2 or h3
					local down = axis.Y > 0 and -axis or axis
					local low, high = {}, {}
					for _, i in ipairs(bd.idx) do
						if (pts[i] - center):Dot(down) > hv * 0.45 then
							table.insert(low, cols[i])
						else
							table.insert(high, cols[i])
						end
					end
					if #low >= 3 and #high >= 3 then
						local cl, ch = avg(low), avg(high)
						if dist(cl, ch) > 0.22 then
							color = ch
							addBelly = { color = cl, down = down, vert = vert, hv = hv }
						end
					end
				end
				table.insert(out, blob(center, e1, e2, e3, h1, h2, h3, color, minHalf))
				if addBelly then
					local bb = addBelly
					local bc = center + bb.down * bb.hv * 0.4
					local bh2 = bb.vert == 2 and h2 * 0.64 or h2 * 0.86
					local bh3 = bb.vert == 3 and h3 * 0.64 or h3 * 0.86
					table.insert(out, blob(bc, e1, e2, e3, h1 * 0.94, bh2, bh3, bb.color, minHalf))
				end
			end
		end
	end
	for _, comp in ipairs(components(g)) do
		local pts, cols = {}, {}
		local seen = {}
		for _, vi in ipairs(comp) do
			local v = g.verts[vi]
			local key = string.format("%d,%d,%d", math.floor(v.X * 400 + 0.5), math.floor(v.Y * 400 + 0.5), math.floor(v.Z * 400 + 0.5))
			if not seen[key] then
				seen[key] = true
				table.insert(pts, v + offset)
				table.insert(cols, g.colors[vi])
			end
		end
		if #pts >= 3 and not opts.noDensify then
			-- mais pontos (meio das arestas e centro dos triângulos): malhas com poucos anéis deixavam fatias
			-- vazias e a fileira de contas ficava "pontilhada"
			local inComp = {}
			for _, vi in ipairs(comp) do
				inComp[vi] = true
			end
			for i, t in ipairs(g.tris) do
				if (not g.keep or g.keep[i]) and inComp[t[1]] then
					local a, b, cc = g.verts[t[1]], g.verts[t[2]], g.verts[t[3]]
					local ca, cb, ccol = g.colors[t[1]], g.colors[t[2]], g.colors[t[3]]
					for _, q in ipairs({ { (a + b) / 2, mix2(ca, cb) }, { (b + cc) / 2, mix2(cb, ccol) }, { (a + cc) / 2, mix2(ca, ccol) },
						{ (a + b + cc) / 3, Color3.new((ca.R + cb.R + ccol.R) / 3, (ca.G + cb.G + ccol.G) / 3, (ca.B + cb.B + ccol.B) / 3) } }) do
						table.insert(pts, q[1] + offset)
						table.insert(cols, q[2])
					end
				end
			end
		end
		emit(pts, cols, 0)
	end
	return out
end

-- Distância ao longo do raio (origem o, direção unitária d) até sair do elipsoide b; nil se não cruza.
local function exitDistance(b: Blob, o: Vector3, d: Vector3): number?
	local inv = b.cf:Inverse()
	local lo = inv * o
	local ld = inv.Rotation * d
	local hx, hy, hz = b.size.X / 2, b.size.Y / 2, b.size.Z / 2
	local ox, oy, oz = lo.X / hx, lo.Y / hy, lo.Z / hz
	local dx, dy, dz = ld.X / hx, ld.Y / hy, ld.Z / hz
	local A = dx * dx + dy * dy + dz * dz
	local B = 2 * (ox * dx + oy * dy + oz * dz)
	local C = ox * ox + oy * oy + oz * oz - 1
	local disc = B * B - 4 * A * C
	if disc < 0 or A < 1e-12 then
		return nil
	end
	return (-B + math.sqrt(disc)) / (2 * A)
end
Smooth._exitDistance = exitDistance

-- Olhos por cima da cabeça LISA: a cabeça de elipsoides é um pouco mais cheia que a malha original onde o
-- adesivo do olho foi colado; cada olho (globo, íris, pupila, brilhos: o mesmo deslocamento para manter as
-- camadas) é empurrado ao longo da própria normal até a superfície da cabeça.
local function liftEyes(eyes: { Blob }, head: { Blob }, lift: number)
	local groups = {}
	for _, b in ipairs(eyes) do
		local placed = false
		for _, g in ipairs(groups) do
			local a = g[1]
			if (b.cf.Position - a.cf.Position).Magnitude < math.max(a.size.X, a.size.Y) * 0.55 then
				table.insert(g, b)
				placed = true
				break
			end
		end
		if not placed then
			table.insert(groups, { b })
		end
	end
	for _, g in ipairs(groups) do
		local a = g[1]
		local n = -a.cf.LookVector -- (ZVector)
		local far = 0
		for _, h in ipairs(head) do
			local t = exitDistance(h, a.cf.Position - n * a.size.Z * 2, n)
			if t then
				far = math.max(far, t - a.size.Z * 2)
			end
		end
		if far > 0 then
			local shift = n * (far + lift)
			for _, b in ipairs(g) do
				b.cf = b.cf + shift
			end
		end
	end
end

-- Elipsoides de cada parte de uma planta (PetAnatomy/BossAnatomy), em coordenadas do modelo na pose de
-- montagem. Peças de olho (role "Eye") viram cúpulas por cima da peça-mãe (a cabeça).
-- Devolve { [nome da parte] = { Blob } } e o total de elipsoides.
local RADIAL = { Mane = true, Ruff = true, Collar = true }
function Smooth.forBlueprint(bp, quality: string?)
	local centers = {}
	for _, p in ipairs(bp.parts) do
		local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
		for _, v in ipairs(p.geom.verts) do
			x0, y0, z0 = math.min(x0, v.X), math.min(y0, v.Y), math.min(z0, v.Z)
			x1, y1, z1 = math.max(x1, v.X), math.max(y1, v.Y), math.max(z1, v.Z)
		end
		centers[p.name] = p.pivot + Vector3.new(x0 + x1, y0 + y1, z0 + z1) / 2
	end
	local high = quality == "high"
	local yLo, yHi = Facets.heightRange(bp)
	local res, total = {}, 0
	for _, p in ipairs(bp.parts) do
		local list = Smooth.blobs(p.geom, p.pivot, {
			density = high and 1.25 or 1,
			maxBeads = high and 4 or 3,
			decal = p.role == "Eye",
			radial = RADIAL[p.name] == true,
			ref = (p.parent and centers[p.parent]) or centers[p.name],
			minHalf = 0.012 * (bp.scale or 1),
		})
		-- mesmas cores vivas do modo de peças (saturação e escurecido embaixo), sem a luz assada por face:
		-- o volume agora vem da iluminação real sobre a superfície lisa
		if p.role ~= "Eye" and p.material ~= "Neon" and p.material ~= "ForceField" and p.transparency < 0.3 then -- (olhos: cores puras, brilho branco)
			for _, b in ipairs(list) do
				local r, g, bb = Facets.toonRGB(b.color.R, b.color.G, b.color.B, (b.cf.Position.Y - yLo) / math.max(yHi - yLo, 1e-3))
				b.color = Color3.new(r, g, bb)
			end
		end
		res[p.name] = list
		total += #list
	end
	for _, p in ipairs(bp.parts) do
		if p.role == "Eye" and p.parent and res[p.parent] then
			liftEyes(res[p.name], res[p.parent], 0.006 * (bp.scale or 1))
		end
	end
	return res, total
end

-- Malha de um elipsoide (para as prévias fora do Roblox): devolve verts e tris.
function Smooth.ellipsoidMesh(b: Blob, segOpt: number?, ringsOpt: number?)
	local seg: number = segOpt or 14
	local rings: number = ringsOpt or 9
	local verts, tris = {}, {}
	local hx, hy, hz = b.size.X / 2, b.size.Y / 2, b.size.Z / 2
	for r = 0, rings do
		local phi = math.pi * r / rings
		for s = 0, seg - 1 do
			local th = 2 * math.pi * s / seg
			local local3 = Vector3.new(math.sin(phi) * math.cos(th) * hx, math.cos(phi) * hy, math.sin(phi) * math.sin(th) * hz)
			table.insert(verts, b.cf * local3)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, seg - 1 do
			local a = r * seg + s + 1
			local bb = r * seg + (s + 1) % seg + 1
			local c = (r + 1) * seg + s + 1
			local d = (r + 1) * seg + (s + 1) % seg + 1
			table.insert(tris, { a, bb, c })
			table.insert(tris, { bb, d, c })
		end
	end
	return verts, tris
end

return Smooth

-- Geometria orgânica para os pets (malhas contínuas e suaves, NÃO bolinhas de peças primitivas).
--
-- Cada forma é um "loft": uma superfície fechada que percorre uma curva (coluna, pescoço, perna, cauda,
-- focinho...) com seções transversais de largura/altura variáveis (superelipses: arredondadas ou mais
-- quadradas), pontas arredondadas e cor por vértice (contra-sombreamento do pelo, máscaras, meias,
-- listras, pintas). Várias formas se juntam numa malha só por parte do corpo.
--
-- É geometria pura (listas de vértices/triângulos): roda no cliente, no servidor, nos testes e na prévia.
-- `MeshKit.toEditable` grava a geometria num EditableMesh (AssetService) para virar MeshPart no jogo.

local MeshKit = {}

local V = Vector3.new

export type Geom = {
	verts: { Vector3 },
	colors: { Color3 },
	tris: { { number } },
	normals: { Vector3 }?,
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Catmull-Rom (uniforme) entre p1 e p2.
local function cr(p0, p1, p2, p3, t: number)
	local t2, t3 = t * t, t * t * t
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
end

local function crNum(a: number, b: number, c: number, d: number, t: number): number
	local t2, t3 = t * t, t * t * t
	return 0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (3 * b - a - 3 * c + d) * t3)
end

local KEYS = { "w", "h", "hb", "dy", "dx", "pow", "jag" }

-- Subdivide os pontos-chave de uma coluna numa curva suave (posição e parâmetros da seção).
local function subdivide(keys, steps: number)
	local out = {}
	local n = #keys
	if n == 1 then
		return { keys[1] }
	end
	for i = 1, n - 1 do
		local k0, k1, k2, k3 = keys[math.max(1, i - 1)], keys[i], keys[i + 1], keys[math.min(n, i + 2)]
		local last = i == n - 1
		for s = 0, (last and steps or steps - 1) do
			local t = s / steps
			local r = { p = cr(k0.p, k1.p, k2.p, k3.p, t) }
			for _, key in ipairs(KEYS) do
				local b, c = k1[key], k2[key]
				if b ~= nil or c ~= nil then
					local bb = b or c
					local cc = c or b
					local v = crNum(k0[key] or bb, bb, cc, k3[key] or cc, t)
					-- deslocamentos (dy/dx) podem ser negativos; medidas não
					r[key] = (key == "dy" or key == "dx") and v or math.max(0.001, v)
				end
			end
			r.t = (i - 1 + t) / (n - 1)
			table.insert(out, r)
		end
	end
	return out
end

local function sgnPow(x: number, e: number): number
	local a = math.abs(x) ^ e
	return x < 0 and -a or a
end

local function perpendicular(t: Vector3, up: Vector3): Vector3
	local r = t:Cross(up)
	if r.Magnitude < 1e-4 then
		r = t:Cross(V(0, 0, -1))
		if r.Magnitude < 1e-4 then
			r = t:Cross(V(1, 0, 0))
		end
	end
	return r.Unit
end

--[[
	MeshKit.loft(keys, opts) -> Geom
	keys: lista de { p = Vector3, w = meia-largura, h = meia-altura (em cima), hb = meia-altura (embaixo, opcional),
	       dy/dx = deslocamento da seção, pow = expoente da superelipse (2 = elipse, 3+ = mais quadrada) }
	opts: seg (lados da seção), steps (subdivisões por trecho), up (referência "para cima"),
	      capStart/capEnd (comprimento da ponta arredondada; 0 = sem tampa), color(t, ex, ey, p) -> Color3
]]
function MeshKit.loft(keys, opts): Geom
	opts = opts or {}
	local seg = opts.seg or 12
	local rings = subdivide(keys, opts.steps or 4)
	local up = opts.up or V(0, 1, 0)
	local colorFn = opts.color
	local baseColor = opts.base or Color3.new(1, 1, 1)
	local verts, colors, tris, centers = {}, {}, {}, {}
	local n = #rings
	-- tangentes
	for i, r in ipairs(rings) do
		local a = rings[math.max(1, i - 1)].p
		local b = rings[math.min(n, i + 1)].p
		local t = b - a
		if t.Magnitude < 1e-5 then
			t = V(0, 0, -1)
		end
		r.T = t.Unit
	end
	-- referenciais com rotação mínima (a seção não "torce" ao longo da curva)
	local R = perpendicular(rings[1].T, up)
	for _, r in ipairs(rings) do
		local proj = R - r.T * R:Dot(r.T)
		if proj.Magnitude < 1e-4 then
			proj = perpendicular(r.T, up)
		end
		R = proj.Unit
		r.R = R
		r.U = R:Cross(r.T)
		-- garante que U aponte para o lado de `up` (dorso para cima)
		if r.U:Dot(up) < -0.2 then
			r.R = -r.R
			r.U = -r.U
			R = r.R
		end
	end
	local function ringVerts(r, scale: number, shift: Vector3, tColor: number)
		local base = #verts
		local pw = r.pow or 2
		local e = 2 / pw
		local jag = r.jag or 0
		for j = 0, seg - 1 do
			local th = (j / seg) * math.pi * 2
			local ex, ey = sgnPow(math.cos(th), e), sgnPow(math.sin(th), e)
			local hh = ey >= 0 and (r.h or r.w) or (r.hb or r.h or r.w)
			-- "jag": seção em estrela (tufos de pelo da juba, do peito e da cauda)
			local m = jag > 0 and (j % 2 == 0 and 1 + jag or 1 - jag * 0.35) or 1
			local p = r.p + shift + r.R * (r.w * ex * scale * m + (r.dx or 0)) + r.U * (hh * ey * scale * m + (r.dy or 0))
			table.insert(verts, p)
			table.insert(colors, colorFn and colorFn(tColor, ex, ey, p) or baseColor)
			table.insert(centers, r.p + shift + r.R * (r.dx or 0) + r.U * (r.dy or 0))
		end
		return base
	end
	local starts = {}
	-- ponta arredondada no início
	local capS = opts.capStart == nil and math.min(rings[1].w, rings[1].h or rings[1].w) * 0.9 or opts.capStart
	local capE = opts.capEnd == nil and math.min(rings[n].w, rings[n].h or rings[n].w) * 0.9 or opts.capEnd
	local poleS, poleE
	if capS > 0 then
		poleS = #verts + 1
		local r = rings[1]
		table.insert(verts, r.p - r.T * capS + r.U * (r.dy or 0) + r.R * (r.dx or 0))
		table.insert(colors, colorFn and colorFn(0, 0, 0, r.p) or baseColor)
		table.insert(centers, r.p)
		local cr_ = opts.capRings or 2
		for k = cr_, 1, -1 do
			local phi = k / (cr_ + 1) * math.pi / 2
			table.insert(starts, ringVerts(r, math.cos(phi), -r.T * capS * math.sin(phi), 0))
		end
	end
	for _, r in ipairs(rings) do
		table.insert(starts, ringVerts(r, 1, Vector3.zero, r.t))
	end
	if capE > 0 then
		local r = rings[n]
		local cr_ = opts.capRings or 2
		for k = 1, cr_ do
			local phi = k / (cr_ + 1) * math.pi / 2
			table.insert(starts, ringVerts(r, math.cos(phi), r.T * capE * math.sin(phi), 1))
		end
		poleE = #verts + 1
		table.insert(verts, r.p + r.T * capE + r.U * (r.dy or 0) + r.R * (r.dx or 0))
		table.insert(colors, colorFn and colorFn(1, 0, 0, r.p) or baseColor)
		table.insert(centers, r.p)
	end
	-- faixas entre seções vizinhas
	for i = 1, #starts - 1 do
		local a0, b0 = starts[i], starts[i + 1]
		for j = 0, seg - 1 do
			local j2 = (j + 1) % seg
			local a, b, c, d = a0 + j + 1, a0 + j2 + 1, b0 + j + 1, b0 + j2 + 1
			table.insert(tris, { a, c, b })
			table.insert(tris, { b, c, d })
		end
	end
	if poleS then
		local first = starts[1]
		for j = 0, seg - 1 do
			table.insert(tris, { poleS, first + j + 1, first + (j + 1) % seg + 1 })
		end
	end
	if poleE then
		local last = starts[#starts]
		for j = 0, seg - 1 do
			table.insert(tris, { poleE, last + (j + 1) % seg + 1, last + j + 1 })
		end
	end
	-- orientação: todo triângulo com a frente para FORA (comparando com o centro da seção)
	for _, tri in ipairs(tris) do
		local a, b, c = verts[tri[1]], verts[tri[2]], verts[tri[3]]
		local nrm = (b - a):Cross(c - a)
		local mid = (a + b + c) / 3
		local ctr = (centers[tri[1]] + centers[tri[2]] + centers[tri[3]]) / 3
		if nrm:Dot(mid - ctr) < 0 then
			tri[2], tri[3] = tri[3], tri[2]
		end
	end
	return { verts = verts, colors = colors, tris = tris, flat = opts.flat }
end

-- Lâmina/membrana plana: polígono (pontos em ordem) com espessura, frente e verso (asas de membrana,
-- pétalas, folhas largas). color: Color3 ou função(p) -> Color3.
function MeshKit.sheet(points: { Vector3 }, thickness: number, color, normal: Vector3?): Geom
	local n = #points
	local ctr = Vector3.zero
	for _, q in ipairs(points) do
		ctr += q
	end
	ctr /= n
	local nrm = normal
	if not nrm then
		local acc = Vector3.zero
		for i = 1, n do
			acc += (points[i] - ctr):Cross(points[i % n + 1] - ctr)
		end
		nrm = acc.Magnitude > 1e-6 and acc.Unit or V(0, 1, 0)
	end
	local off = nrm * (thickness / 2)
	local verts, colors, tris = {}, {}, {}
	local function col(q)
		return type(color) == "function" and color(q) or color
	end
	table.insert(verts, ctr + off)
	table.insert(colors, col(ctr))
	table.insert(verts, ctr - off)
	table.insert(colors, col(ctr))
	for _, q in ipairs(points) do
		table.insert(verts, q + off)
		table.insert(colors, col(q))
		table.insert(verts, q - off)
		table.insert(colors, col(q))
	end
	for i = 1, n do
		local a, b = 3 + (i - 1) * 2, 3 + (i % n) * 2
		table.insert(tris, { 1, a, b }) -- frente
		table.insert(tris, { 2, b + 1, a + 1 }) -- verso
		table.insert(tris, { a, a + 1, b + 1 }) -- borda
		table.insert(tris, { a, b + 1, b })
	end
	-- orientação: frente na direção de +nrm, verso em -nrm, bordas para fora
	for _, t in ipairs(tris) do
		local A, B, C = verts[t[1]], verts[t[2]], verts[t[3]]
		local fn = (B - A):Cross(C - A)
		local mid = (A + B + C) / 3
		local ref = (t[1] == 1 and nrm) or (t[1] == 2 and -nrm) or (mid - ctr)
		if fn:Dot(ref) < 0 then
			t[2], t[3] = t[3], t[2]
		end
	end
	return { verts = verts, colors = colors, tris = tris, flat = true }
end

-- Junta várias geometrias numa só.
function MeshKit.merge(list): Geom
	local out = { verts = {}, colors = {}, tris = {} }
	local allFlat = #list > 0
	for _, g in ipairs(list) do
		if g and not g.flat then
			allFlat = false
		end
	end
	out.flat = allFlat or nil
	for _, g in ipairs(list) do
		if g then
			local base = #out.verts
			for i, v in ipairs(g.verts) do
				table.insert(out.verts, v)
				table.insert(out.colors, g.colors[i])
			end
			for _, t in ipairs(g.tris) do
				table.insert(out.tris, { t[1] + base, t[2] + base, t[3] + base })
			end
		end
	end
	return out
end

-- Aplica um CFrame (posição/rotação) a toda a geometria.
function MeshKit.transform(g: Geom, cf: CFrame): Geom
	local out = { verts = {}, colors = g.colors, tris = g.tris, flat = g.flat }
	for i, v in ipairs(g.verts) do
		out.verts[i] = cf * v
	end
	return out
end

-- Espelha no eixo X (lado esquerdo ↔ direito), mantendo a frente das faces.
function MeshKit.mirrorX(g: Geom): Geom
	local out = { verts = {}, colors = g.colors, tris = {}, flat = g.flat }
	for i, v in ipairs(g.verts) do
		out.verts[i] = V(-v.X, v.Y, v.Z)
	end
	for i, t in ipairs(g.tris) do
		out.tris[i] = { t[1], t[3], t[2] }
	end
	return out
end

-- Pinta todos os vértices com uma cor (ou função da posição).
function MeshKit.paint(g: Geom, color): Geom
	local out = { verts = g.verts, colors = {}, tris = g.tris, flat = g.flat }
	for i, v in ipairs(g.verts) do
		out.colors[i] = type(color) == "function" and color(v, g.colors[i]) or color
	end
	return out
end

-- Normais suaves (média das faces vizinhas, ponderada pela área).
function MeshKit.normals(g: Geom): { Vector3 }
	local acc = {}
	for i = 1, #g.verts do
		acc[i] = Vector3.zero
	end
	for _, t in ipairs(g.tris) do
		local a, b, c = g.verts[t[1]], g.verts[t[2]], g.verts[t[3]]
		local n = (b - a):Cross(c - a)
		for k = 1, 3 do
			acc[t[k]] += n
		end
	end
	for i, n in ipairs(acc) do
		acc[i] = n.Magnitude > 1e-9 and n.Unit or V(0, 1, 0)
	end
	return acc
end

function MeshKit.bounds(g: Geom): (Vector3, Vector3)
	local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for _, v in ipairs(g.verts) do
		x0, y0, z0 = math.min(x0, v.X), math.min(y0, v.Y), math.min(z0, v.Z)
		x1, y1, z1 = math.max(x1, v.X), math.max(y1, v.Y), math.max(z1, v.Z)
	end
	return V(x0, y0, z0), V(x1, y1, z1)
end

-- Centraliza a geometria na caixa envolvente (a MeshPart do Roblox fica centrada na própria malha).
-- Devolve (geometria centrada, centro original).
function MeshKit.centered(g: Geom): (Geom, Vector3)
	local mn, mx = MeshKit.bounds(g)
	local c = (mn + mx) / 2
	local out = { verts = {}, colors = g.colors, tris = g.tris, flat = g.flat }
	for i, v in ipairs(g.verts) do
		out.verts[i] = v - c
	end
	return out, c
end

-- Grava a geometria num EditableMesh (normais suaves e cor por vértice). Só no Roblox.
-- g.flat = true: normal por face (aspecto facetado: rochas, cristais, membranas).
function MeshKit.toEditable(g: Geom, editable)
	local normals = (not g.flat) and (g.normals or MeshKit.normals(g)) or nil
	local vid, nid, cid = {}, {}, {}
	for i, v in ipairs(g.verts) do
		vid[i] = editable:AddVertex(v)
		if normals then
			nid[i] = editable:AddNormal(normals[i])
		end
		cid[i] = editable:AddColor(g.colors[i] or Color3.new(1, 1, 1), 1)
	end
	for _, t in ipairs(g.tris) do
		local a, b, c = t[1], t[2], t[3]
		local f = editable:AddTriangle(vid[a], vid[b], vid[c])
		if normals then
			editable:SetFaceNormals(f, { nid[a], nid[b], nid[c] })
		else
			local fn = (g.verts[b] - g.verts[a]):Cross(g.verts[c] - g.verts[a])
			local id = editable:AddNormal(fn.Magnitude > 1e-9 and fn.Unit or V(0, 1, 0))
			editable:SetFaceNormals(f, { id, id, id })
		end
		editable:SetFaceColors(f, { cid[a], cid[b], cid[c] })
	end
	return editable
end

MeshKit.lerp = lerp
return MeshKit

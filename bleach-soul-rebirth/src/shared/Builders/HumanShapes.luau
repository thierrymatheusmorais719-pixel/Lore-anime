-- Formas humanas lisas (geometria pura: vértices + triângulos no espaço local de cada parte do
-- R15), montadas no cliente com EditableMesh (HumanSkin) por cima das partes em bloco dos NPCs.
-- • cabeça: crânio, mandíbula que afina, queixo, nariz sutil, pescoço que entra no tronco
-- • tronco: peito, ombros arredondados, cintura; quadril
-- • braços/pernas: perfil de músculo (deltoide, bíceps, antebraço; coxa, panturrilha), pontas
--   arredondadas que se sobrepõem à parte vizinha (articulação contínua)
-- • mão em luva (palma + polegar), pé em formato de sapato
-- • softBox: caixa de cantos arredondados (roupas e cabelo em bloco viram tecido/mechas macios)
-- Medidas para o R15 padrão (RigBuilder): cabeça 1,16 × 1,18 × 1,16 (rosto em z = -0,58).
local HumanShapes = {}

export type Shape = { v: { Vector3 }, t: { { number } } }

local SIDES = 18

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function profileAt(profile: { { number } }, t: number): (number, number, number)
	if t <= profile[1][1] then
		return profile[1][2], profile[1][3], profile[1][4] or 0
	end
	for i = 1, #profile - 1 do
		local a, b = profile[i], profile[i + 1]
		if t <= b[1] then
			local u = (t - a[1]) / math.max(1e-6, b[1] - a[1])
			u = u * u * (3 - 2 * u)
			return lerp(a[2], b[2], u), lerp(a[3], b[3], u), lerp(a[4] or 0, b[4] or 0, u)
		end
	end
	local last = profile[#profile]
	return last[2], last[3], last[4] or 0
end

local function superellipse(angle: number, rx: number, rz: number, n: number): (number, number)
	local c, s = math.cos(angle), math.sin(angle)
	local x = rx * math.sign(c) * math.abs(c) ^ (2 / n)
	local z = rz * math.sign(s) * math.abs(s) ^ (2 / n)
	return x, z
end

-- Superfície ao longo de Y, de `top` (t = 0) a `bottom` (t = 1). profile: {t, rx, rz, avançoZ}
-- (avanço negativo = para a frente, -Z). Pontas em calota que passam um pouco do comprimento.
local function loft(top: number, bottom: number, profile: { { number } }, n: number?, capScale: number?): Shape
	local shape: Shape = { v = {}, t = {} }
	local power = n or 2.3
	local stations = {}
	local rx0, rz0, f0 = profileAt(profile, 0)
	local rx1, rz1, f1 = profileAt(profile, 1)
	local capTop = math.min(rx0, rz0) * (capScale or 0.8)
	local capBottom = math.min(rx1, rz1) * (capScale or 0.8)
	local capSteps = 4
	for i = 0, capSteps - 1 do
		local a = i / capSteps * math.pi / 2
		table.insert(stations, { t = 0, k = math.sin(a), y = top + capTop * math.cos(a) })
	end
	local rings = 14
	for i = 0, rings do
		local t = i / rings
		table.insert(stations, { t = t, k = 1, y = lerp(top, bottom, t) })
	end
	for i = 1, capSteps do
		local a = i / capSteps * math.pi / 2
		table.insert(stations, { t = 1, k = math.cos(a), y = bottom - capBottom * math.sin(a) })
	end
	local ringIds = {}
	for _, st in stations do
		local rx, rz, forward = profileAt(profile, st.t)
		local ring = {}
		for j = 0, SIDES - 1 do
			local a = j / SIDES * math.pi * 2
			local x, z = superellipse(a, rx * math.max(st.k, 0.03), rz * math.max(st.k, 0.03), power)
			table.insert(shape.v, Vector3.new(x, st.y, z + forward))
			ring[j] = #shape.v
		end
		table.insert(ringIds, ring)
	end
	table.insert(shape.v, Vector3.new(0, top + capTop, f0))
	local topId = #shape.v
	table.insert(shape.v, Vector3.new(0, bottom - capBottom, f1))
	local bottomId = #shape.v
	for r = 1, #ringIds - 1 do
		for j = 0, SIDES - 1 do
			local k = (j + 1) % SIDES
			local a, b, c, d = ringIds[r][j], ringIds[r][k], ringIds[r + 1][j], ringIds[r + 1][k]
			table.insert(shape.t, { a, b, c })
			table.insert(shape.t, { b, d, c })
		end
	end
	for j = 0, SIDES - 1 do
		local k = (j + 1) % SIDES
		table.insert(shape.t, { topId, ringIds[1][k], ringIds[1][j] })
		table.insert(shape.t, { bottomId, ringIds[#ringIds][j], ringIds[#ringIds][k] })
	end
	return shape
end

-- Superelipsoide (cantos arredondados); `warp` deforma cada ponto (cabeça, mão, pé)
local function blob(
	rx: number,
	ry: number,
	rz: number,
	n: number,
	lat: number,
	lon: number,
	warp: ((Vector3) -> Vector3)?
): Shape
	local shape: Shape = { v = {}, t = {} }
	local function f(c: number): number
		return math.sign(c) * math.abs(c) ^ (2 / n)
	end
	for i = 0, lat do
		local v = -math.pi / 2 + math.pi * i / lat
		for j = 0, lon - 1 do
			local u = 2 * math.pi * j / lon
			local p = Vector3.new(
				rx * f(math.cos(v)) * f(math.cos(u)),
				ry * f(math.sin(v)),
				rz * f(math.cos(v)) * f(math.sin(u))
			)
			table.insert(shape.v, if warp then warp(p) else p)
		end
	end
	for i = 0, lat - 1 do
		for j = 0, lon - 1 do
			local a = i * lon + j + 1
			local b = i * lon + (j + 1) % lon + 1
			local c = (i + 1) * lon + j + 1
			local d = (i + 1) * lon + (j + 1) % lon + 1
			table.insert(shape.t, { a, c, b })
			table.insert(shape.t, { b, c, d })
		end
	end
	return shape
end

-- Caixa macia do tamanho dado (roupa/cabelo em bloco → volume de tecido). `name` aplica o ajuste
-- da peça (cabelo justo ao crânio liso, mangas acompanhando o braço mais fino e mais perto)
function HumanShapes.softBox(size: Vector3, roundness: number?, name: string?): Shape
	local fit = name and HumanShapes.Fit[name]
	local s = if fit then size * fit.scale else size
	local shape = blob(s.X / 2, s.Y / 2, s.Z / 2, roundness or 5, 10, 20)
	if fit and fit.offset then
		for i, v in shape.v do
			shape.v[i] = v + fit.offset
		end
	end
	return shape
end

local function merge(a: Shape, b: Shape): Shape
	local offset = #a.v
	for _, p in b.v do
		table.insert(a.v, p)
	end
	for _, tri in b.t do
		table.insert(a.t, { tri[1] + offset, tri[2] + offset, tri[3] + offset })
	end
	return a
end

-- ======================================================================= partes
local BUILD: { [string]: (Vector3) -> Shape } = {}

function BUILD.Head(size: Vector3): Shape
	local rx, ry, rz = size.X * 0.44, size.Y * 0.5, size.Z * 0.5
	local head = blob(rx, ry, rz, 2.25, 16, 24, function(p: Vector3): Vector3
		local x, y, z = p.X, p.Y, p.Z
		-- mandíbula e queixo: afina embaixo, queixo um pouco à frente
		if y < -0.05 then
			local k = math.clamp((-0.05 - y) / (ry - 0.05), 0, 1)
			x *= lerp(1, 0.68, k ^ 1.3)
			if z > 0 then
				z *= lerp(1, 0.72, k)
			else
				z *= lerp(1, 0.92, k)
			end
		end
		-- nuca mais cheia, testa reta
		if z > 0 and y > 0 then
			z *= 1.04
		end
		-- nariz: saliência suave no meio do rosto
		local nose = math.exp(-((x / 0.09) ^ 2 + ((y + 0.06) / 0.14) ^ 2))
		z -= nose * 0.07
		-- maçãs do rosto
		for _, sx in { -0.24, 0.24 } do
			z -= math.exp(-(((x - sx) / 0.12) ^ 2 + ((y + 0.08) / 0.1) ^ 2)) * 0.025
		end
		return Vector3.new(x, y + 0.02, z)
	end)
	-- pescoço descendo para dentro do tronco
	local neck = loft(-0.3, -0.85, { { 0, 0.24, 0.24, 0.04 }, { 1, 0.27, 0.26, 0.06 } }, 2, 0.4)
	return merge(head, neck)
end

function BUILD.UpperTorso(size: Vector3): Shape
	-- t = 0 em cima (ombros) → 1 embaixo (cintura). Ombros largos e arredondados, peito, cintura
	local h = size.Y / 2
	return loft(h - 0.08, -h + 0.05, {
		{ 0, 0.62, 0.36, 0.02 },
		{ 0.12, 0.9, 0.46, 0 },
		{ 0.35, 0.86, 0.5, -0.03 },
		{ 0.62, 0.76, 0.46, -0.02 },
		{ 1, 0.7, 0.43, 0 },
	}, 2.6, 0.6)
end

function BUILD.LowerTorso(size: Vector3): Shape
	local h = size.Y / 2
	return loft(h + 0.1, -h - 0.05, { { 0, 0.7, 0.43 }, { 0.6, 0.78, 0.46 }, { 1, 0.74, 0.44 } }, 2.6, 0.5)
end

local function arm(upper: boolean): (Vector3) -> Shape
	return function(size: Vector3): Shape
		local h = size.Y / 2
		if upper then
			-- deltoide no topo, bíceps à frente, afina no cotovelo
			return loft(h - 0.05, -h + 0.08, {
				{ 0, 0.36, 0.35 },
				{ 0.25, 0.34, 0.33, -0.02 },
				{ 0.55, 0.3, 0.31, -0.03 },
				{ 1, 0.25, 0.25 },
			})
		end
		-- antebraço: cheio perto do cotovelo, fino no punho
		return loft(h - 0.02, -h + 0.06, { { 0, 0.26, 0.25 }, { 0.25, 0.27, 0.26 }, { 1, 0.19, 0.17 } })
	end
end

local function leg(upper: boolean): (Vector3) -> Shape
	return function(size: Vector3): Shape
		local h = size.Y / 2
		if upper then
			return loft(h + 0.05, -h + 0.08, { { 0, 0.42, 0.43 }, { 0.3, 0.41, 0.44, -0.03 }, { 1, 0.31, 0.32 } })
		end
		-- panturrilha atrás, tornozelo fino
		return loft(h - 0.02, -h + 0.08, { { 0, 0.31, 0.32 }, { 0.3, 0.33, 0.37, 0.05 }, { 1, 0.21, 0.22 } })
	end
end

function BUILD.Hand(_size: Vector3): Shape
	-- luva: palma achatada pendendo do punho + polegar do lado de dentro
	local palm = blob(0.3, 0.36, 0.16, 2.8, 10, 16, function(p: Vector3): Vector3
		return Vector3.new(p.X * (1 - 0.15 * math.max(0, -p.Y)), p.Y - 0.14, p.Z)
	end)
	local thumb = loft(-0.02, -0.34, { { 0, 0.09, 0.08 }, { 1, 0.07, 0.06 } }, 2, 0.9)
	for i, v in thumb.v do
		thumb.v[i] = Vector3.new(v.X * 0.9 + 0.26, v.Y, v.Z - 0.08)
	end
	return merge(palm, thumb)
end

function BUILD.Foot(size: Vector3): Shape
	-- sapato: bico arredondado à frente (-Z), calcanhar alto atrás
	return blob(size.X * 0.4, size.Y * 0.55, size.Z * 0.56, 3.2, 10, 20, function(p: Vector3): Vector3
		local x, y, z = p.X, p.Y, p.Z
		if z < 0 then
			y *= lerp(1, 0.7, math.clamp(-z / 0.5, 0, 1)) -- bico mais baixo
			x *= lerp(1, 0.85, math.clamp(-z / 0.5, 0, 1))
		end
		return Vector3.new(x, y + 0.02, z - 0.06)
	end)
end

BUILD.RightUpperArm = arm(true)
BUILD.LeftUpperArm = arm(true)
BUILD.RightLowerArm = arm(false)
BUILD.LeftLowerArm = arm(false)
BUILD.RightUpperLeg = leg(true)
BUILD.LeftUpperLeg = leg(true)
BUILD.RightLowerLeg = leg(false)
BUILD.LeftLowerLeg = leg(false)
BUILD.RightHand = BUILD.Hand
BUILD.LeftHand = function(size: Vector3): Shape
	local s = BUILD.Hand(size)
	for i, v in s.v do
		s.v[i] = Vector3.new(-v.X, v.Y, v.Z)
	end
	-- espelhar inverte a volta dos triângulos
	for _, tri in s.t do
		tri[2], tri[3] = tri[3], tri[2]
	end
	return s
end
BUILD.RightFoot = BUILD.Foot
BUILD.LeftFoot = BUILD.Foot

-- Os braços do R15 ficam afastados do tronco (blocos de 1 stud); a malha do braço entra um pouco
-- na direção do corpo (a junta continua no mesmo lugar, só o desenho aproxima)
local ARM_INSET = 0.3

-- Deslocamento (no espaço da parte) do desenho do braço/mão `name`; peças presas a ele (mangas,
-- acessórios) acompanham o mesmo deslocamento
function HumanShapes.armInset(name: string): Vector3
	if name:find("Arm") or name:find("Hand") then
		return Vector3.new(if name:sub(1, 5) == "Right" then -ARM_INSET else ARM_INSET, 0, 0)
	end
	return Vector3.zero
end

-- Forma lisa para a parte do corpo `name` (nil se não for parte conhecida)
function HumanShapes.forPart(name: string, size: Vector3): Shape?
	local builder = BUILD[name]
	if not builder then
		return nil
	end
	local shape = builder(size)
	local inset = HumanShapes.armInset(name)
	if inset.Magnitude > 0 then
		for i, v in shape.v do
			shape.v[i] = v + inset
		end
	end
	return shape
end

-- ======================================================================= acessórios esculpidos
-- Formas próprias para peças do NpcStyle (substituem cunhas/caixas pela forma de verdade).
-- Cada construtor recebe o tamanho da peça e devolve a geometria no espaço dela.
local function grid(nu: number, nv: number, point: (number, number) -> Vector3): Shape
	local shape: Shape = { v = {}, t = {} }
	for j = 0, nv do
		for i = 0, nu do
			table.insert(shape.v, point(i / nu, j / nv))
		end
	end
	local row = nu + 1
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			local a = j * row + i + 1
			local b = a + 1
			local c = a + row
			local d = c + 1
			table.insert(shape.t, { a, b, c })
			table.insert(shape.t, { b, d, c })
		end
	end
	return shape
end

-- Tecido curvo: folha que envolve o corpo (bordas curvam para dentro, `wrap` > 0 = atrás do
-- corpo), abre embaixo (`flare`) e ondula de leve na barra
local function cloth(size: Vector3, wrap: number, flare: number, wave: number?): Shape
	local w, h = size.X, size.Y
	local thick = math.max(size.Z, 0.06)
	local front = grid(16, 12, function(u: number, v: number): Vector3
		local x = (u - 0.5) * w * (1 + flare * v)
		local y = h / 2 - v * h
		local z = -wrap * ((u - 0.5) * 2) ^ 2 * (0.25 + 0.2 * v) + (wave or 0) * v * v * math.sin(u * math.pi * 5)
		return Vector3.new(x, y, z)
	end)
	-- espessura: segunda folha atrás (as bordas ficam abertas, como tecido)
	local back = grid(16, 12, function(u: number, v: number): Vector3
		local x = (u - 0.5) * w * (1 + flare * v)
		local y = h / 2 - v * h
		local z = -wrap * ((u - 0.5) * 2) ^ 2 * (0.25 + 0.2 * v)
			+ (wave or 0) * v * v * math.sin(u * math.pi * 5)
			+ thick * 0.6
		return Vector3.new(x, y, z)
	end)
	return merge(front, back)
end

local ACC: { [string]: (Vector3) -> Shape } = {}

-- Chapéu-balde (estilo lojista): copa macia com topo em domo e vinco, aba caída e ondulada
function ACC.HatTop(size: Vector3): Shape
	local h = size.Y
	return loft(h / 2 + 0.05, -h / 2 - 0.02, {
		{ 0, size.X * 0.4, size.Z * 0.4 },
		{ 0.25, size.X * 0.46, size.Z * 0.46 },
		{ 1, size.X * 0.5, size.Z * 0.5 },
	}, 2.2, 0.35)
end

function ACC.HatBrim(size: Vector3): Shape
	local rIn, rOut = size.X * 0.3, size.X * 0.5
	local top = grid(40, 5, function(u: number, v: number): Vector3
		local a = u * math.pi * 2
		local r = lerp(rIn, rOut, v)
		local droop = -0.22 * v ^ 1.4 - 0.03 * math.sin(a * 3) * v
		-- aba um pouco mais baixa na frente (-Z), sombreando o rosto
		droop -= 0.06 * v * math.max(0, -math.sin(a))
		return Vector3.new(math.cos(a) * r, droop, math.sin(a) * r)
	end)
	local under = grid(40, 5, function(u: number, v: number): Vector3
		local a = u * math.pi * 2
		local r = lerp(rIn, rOut, v)
		local droop = -0.22 * v ^ 1.4 - 0.03 * math.sin(a * 3) * v - 0.06 * v * math.max(0, -math.sin(a))
		return Vector3.new(math.cos(a) * r, droop - 0.035, math.sin(a) * r)
	end)
	return merge(top, under)
end

function ACC.HatStripe(size: Vector3): Shape
	local r = size.X * 0.505
	return grid(40, 1, function(u: number, v: number): Vector3
		local a = u * math.pi * 2
		return Vector3.new(math.cos(a) * r, (v - 0.5) * size.Y, math.sin(a) * r)
	end)
end

-- Mecha de cabelo: lâmina achatada que afina até a ponta, com curva suave. Mesma caixa da
-- WedgePart que ela substitui: raiz em +Z (altura cheia), ponta em -Z na aresta de baixo.
ACC.Hair = function(size: Vector3): Shape
	local w, t, l = size.X, size.Y, size.Z
	return grid(10, 14, function(u: number, v: number): Vector3
		local a = u * math.pi * 2
		local k = (1 - v) ^ 0.75 -- afina para a ponta
		local z = l / 2 - v * l
		local y = -t / 2 * v * v + math.sin(v * math.pi) * t * 0.15
		return Vector3.new(math.cos(a) * w / 2 * k, y + math.sin(a) * t / 2 * k, z)
	end)
end

ACC.HaoriBack = function(size: Vector3): Shape
	return cloth(size, -0.12, 0.05)
end
ACC.HaoriSkirt = function(size: Vector3): Shape
	return cloth(size, -0.18, 0.18, 0.05)
end
ACC.Cape = function(size: Vector3): Shape
	return cloth(size, -0.22, 0.25, 0.06)
end
ACC.HaoriFront = function(size: Vector3): Shape
	return cloth(size, 0.04, 0.04)
end
ACC.CoatSkirt = function(size: Vector3): Shape
	return cloth(size, 0.12, 0.2, 0.04)
end
ACC.CoatFlap = function(size: Vector3): Shape
	return cloth(size, 0.1, 0.15, 0.03)
end
ACC.SailorBack = function(size: Vector3): Shape
	return cloth(size, -0.1, 0.08)
end
-- Cauda do haori (cunha): aba de tecido que afina e ondula
ACC.HaoriTail = function(size: Vector3): Shape
	local h, l = size.Y, size.Z
	return grid(8, 14, function(u: number, v: number): Vector3
		local z = (u - 0.5) * l * (1 - 0.6 * v)
		local y = h / 2 - v * h
		local x = 0.08 * math.sin(v * math.pi * 1.5) + (u - 0.5) * 0.02
		return Vector3.new(x, y, z + l * 0.25 * v)
	end)
end

-- Barba: volume arredondado que desce do queixo e afina (a cunha era um bloco)
ACC.Beard = function(size: Vector3): Shape
	return blob(size.X * 0.5, size.Y * 0.55, size.Z * 0.6, 2.4, 10, 18, function(p: Vector3): Vector3
		-- a cunha está de cabeça para baixo (180° em X): a ponta da barba fica em +Y local
		local k = math.clamp((p.Y / (size.Y * 0.55) + 1) / 2, 0, 1)
		return Vector3.new(p.X * (1 - 0.55 * k), p.Y, p.Z * (1 - 0.3 * k))
	end)
end

-- Caimento da manga larga do quimono: bolsa de tecido arredondada pendurada
ACC.SleeveDrape = function(size: Vector3): Shape
	return blob(size.X * 0.42, size.Y * 0.5, size.Z * 0.48, 2.6, 10, 18, function(p: Vector3): Vector3
		-- mais cheia embaixo (+Y local, a cunha está invertida), presa em cima
		local k = math.clamp((p.Y / (size.Y * 0.5) + 1) / 2, 0, 1)
		return Vector3.new(p.X * (0.8 + 0.25 * k), p.Y, p.Z * (0.85 + 0.2 * k) + 0.1 * k)
	end)
end

-- Forma esculpida para a peça de acessório `name` (nil se não houver)
function HumanShapes.accessory(name: string, size: Vector3): Shape?
	local builder = ACC[name]
	return if builder then builder(size) else nil
end

-- Ajustes de peças sobre o corpo liso: escala e deslocamento no espaço da peça
HumanShapes.Fit = {
	HairCap = { scale = Vector3.new(0.88, 0.9, 0.9), offset = Vector3.new(0, -0.03, 0) },
	HairBack = { scale = Vector3.new(0.86, 1, 1), offset = Vector3.new(0, 0, -0.06) },
	HairSide = { scale = Vector3.new(1, 1, 0.9), offset = Vector3.new(0, 0, 0) },
	HairBob = { scale = Vector3.new(1, 1, 0.9) },
	Fringe = { scale = Vector3.new(0.86, 1, 1), offset = Vector3.new(0, 0, 0.04) },
	Sleeve = { scale = Vector3.new(0.82, 1, 0.82) },
	SleeveBell = { scale = Vector3.new(0.85, 1, 0.9) },
	Armband = { scale = Vector3.new(0.7, 1, 0.7) },
	Cuff = { scale = Vector3.new(0.56, 1, 0.52) },
	Hakama = { scale = Vector3.new(0.95, 1, 0.95) },
}

-- Peças de roupa/cabelo em bloco que viram volume macio (nomes do NpcStyle)
HumanShapes.Soft = {
	Sleeve = 4,
	SleeveBell = 4,
	Hakama = 4,
	HakamaFlare = 3.5,
	Obi = 4,
	Skirt = 3.5,
	HighCollar = 4,
	JacketFront = 5,
	JacketPanel = 5,
	Hood = 3,
	HatTop = 3,
	Collar = 4,
	HaoriShoulder = 4,
	Armband = 4,
	Cuff = 4,
	Sandal = 6,
	Sole = 6,
	HairCap = 3,
	HairBack = 4,
	HairSide = 4,
	HairLong = 5,
	HairBob = 4,
	Fringe = 4,
	HairSideLock = 3,
	HairTie = 2.5,
	Mustache = 3,
	MaskJaw = 3,
	MaskFragment = 3,
	ObiKnot = 3,
	RibbonKnot = 3,
	Saya = 4,
	Tsuka = 3,
}

return HumanShapes

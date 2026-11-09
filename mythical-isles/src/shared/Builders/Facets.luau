-- Triângulo 3D feito de peças: duas WedgeParts que cobrem exatamente o triângulo (técnica clássica do
-- Roblox). É o que permite superfícies de malha (pets, bosses, a Árvore-Santuário) sem EditableMesh.
--
-- props = { color, material, transparency, reflectance, shadow, role?, anchored?, collide? }
-- Sem `anchored`: a cunha é solta e soldada (WeldConstraint) à peça `parent` (ossos animados).
-- Com `anchored`: cenário fixo, sem solda; `collide` liga a colisão.

local Facets = {}

function Facets.triangle(a: Vector3, b: Vector3, c: Vector3, th: number, props, parent: Instance): number
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local cr = ac:Cross(ab)
	if cr.Magnitude < 1e-7 or bc.Magnitude < 1e-4 then
		return 0
	end
	local right = cr.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	if height < 0.004 then
		return 0
	end
	local made = 0
	for k = 1, 2 do
		local len = k == 1 and math.abs(ab:Dot(back)) or math.abs(ac:Dot(back))
		if len > 0.004 then
			local w = Instance.new("WedgePart")
			w.Name = props.name or "Facet"
			w.Size = Vector3.new(th, height, len)
			w.CFrame = k == 1 and CFrame.fromMatrix((a + b) / 2, right, up, back) or CFrame.fromMatrix((a + c) / 2, -right, up, -back)
			w.Color = props.color
			w.Material = props.material
			w.Transparency = props.transparency or 0
			w.Reflectance = props.reflectance or 0
			w.CastShadow = props.shadow ~= false
			w.TopSurface, w.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			if props.role then
				w:SetAttribute("Role", props.role)
			end
			if props.anchored then
				w.Anchored = true
				w.CanCollide = props.collide == true
				w.CanQuery = props.collide == true
				w.CanTouch = false
			else
				w.CanCollide, w.CanQuery, w.CanTouch, w.Massless, w.Anchored = false, false, false, true, false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = parent :: BasePart
				weld.Part1 = w
				weld.Parent = w
			end
			w.Parent = parent
			made += 1
		end
	end
	return made
end

-- Toda a geometria (MeshKit) vira cunhas ancoradas. colorOf(i) opcional: cor da face i.
-- Devolve o número de cunhas criadas.
function Facets.build(g, th: number, props, parent: Instance, filter): number
	local n = 0
	local p = table.clone(props)
	for i, t in ipairs(g.tris) do
		if not g.keep or g.keep[i] then
			local a, b, c = g.verts[t[1]], g.verts[t[2]], g.verts[t[3]]
			if not filter or filter(a, b, c) then
				local ca, cb, cc = g.colors[t[1]], g.colors[t[2]], g.colors[t[3]]
				p.color = Color3.new((ca.R + cb.R + cc.R) / 3, (ca.G + cb.G + cc.G) / 3, (ca.B + cb.B + cc.B) / 3)
				n += Facets.triangle(a, b, c, th, p, parent)
			end
		end
	end
	return n
end

-- SOMBREAMENTO "ASSADO" do modo de peças (pets e bosses sem EditableMesh). Cada face é uma cor chapada,
-- então o volume vem daqui: cor um pouco mais saturada (visual de desenho) e oclusão pela altura do
-- corpo (patas e barriga mais escuras, costas e cabeça mais claras), como a luz de baixo que falta.
Facets.TOON_SAT = 1.18
Facets.TOON_AO = 0.3
function Facets.toonRGB(r: number, g: number, b: number, y01: number): (number, number, number)
	local gray = (r + g + b) / 3
	local k = Facets.TOON_SAT
	r, g, b = gray + (r - gray) * k, gray + (g - gray) * k, gray + (b - gray) * k
	local ao = (1 - Facets.TOON_AO) + Facets.TOON_AO * math.clamp(y01, 0, 1) ^ 0.7
	local lift = 1.05
	return math.clamp(r * ao * lift, 0, 1), math.clamp(g * ao * lift, 0, 1), math.clamp(b * ao * lift, 0, 1)
end

-- LUZ ASSADA POR FACE (modo de peças): cada triângulo é chapado, então o "volume" vem também do quanto a
-- face olha para a luz principal (de cima, à frente e à esquerda) e de uma leve variação de tom por face
-- (o visual "lapidado" do low-poly bem feito). A normal é orientada para FORA do centro da peça.
local KEY = Vector3.new(-0.4, 0.82, -0.42).Unit
Facets.LIGHT = 0.26
Facets.FACET = 0.07
function Facets.faceLight(a: Vector3, b: Vector3, c: Vector3, center: Vector3): number
	local nrm = (b - a):Cross(c - a)
	if nrm.Magnitude < 1e-9 then
		return 1
	end
	nrm = nrm.Unit
	local mid = (a + b + c) / 3
	if nrm:Dot(mid - center) < 0 then
		nrm = -nrm
	end
	local lambert = math.max(0, nrm:Dot(KEY))
	local sky = math.max(0, nrm.Y) * 0.05
	-- variação estável por face (hash da posição): sempre o mesmo tom na mesma face
	local h = math.sin(mid.X * 12.9898 + mid.Y * 78.233 + mid.Z * 37.719) * 43758.5453
	h -= math.floor(h)
	return (1 - Facets.LIGHT * 0.6) + Facets.LIGHT * lambert + sky + (h - 0.5) * Facets.FACET
end

-- Centro da caixa de uma geometria (para orientar as normais na luz assada).
local centers = setmetatable({}, { __mode = "k" })
function Facets.geomCenter(g): Vector3
	local c = centers[g]
	if c then
		return c
	end
	local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for _, v in ipairs(g.verts) do
		x0, y0, z0 = math.min(x0, v.X), math.min(y0, v.Y), math.min(z0, v.Z)
		x1, y1, z1 = math.max(x1, v.X), math.max(y1, v.Y), math.max(z1, v.Z)
	end
	c = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	centers[g] = c
	return c
end

-- Altura mínima e máxima de uma planta (pets/bosses), para a oclusão pela altura.
function Facets.heightRange(bp): (number, number)
	local lo, hi = math.huge, -math.huge
	for _, p in ipairs(bp.parts) do
		for _, v in ipairs(p.geom.verts) do
			local y = v.Y + p.pivot.Y
			if y < lo then
				lo = y
			end
			if y > hi then
				hi = y
			end
		end
	end
	if lo > hi then
		return 0, 1
	end
	return lo, math.max(hi, lo + 0.01)
end

return Facets

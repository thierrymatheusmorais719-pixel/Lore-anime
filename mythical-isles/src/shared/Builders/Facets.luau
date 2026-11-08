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

return Facets

-- Kit de modelagem procedural para criaturas (pets, inimigos, bosses).
--
-- Cada peça é ligada ao "pai" por um Motor6D (nome = junta animável, ex.: "LegFL", "WingL").
-- O Animator do cliente anima as juntas pelo NOME, então qualquer criatura que siga a convenção
-- ganha idle/movimento/ataque/dano/derrota.
--
-- Atributo "Role" em cada peça (Body, Belly, Accent, Eye, Detail, Glow) — usado pelas mutações.

local ModelKit = {}

export type Rig = {
	model: Model,
	root: BasePart,
	parts: { [string]: BasePart },
	scale: number,
}

local MATERIALS = Enum.Material

-- Cria um rig vazio com uma peça raiz invisível (é ela que se move/colide).
function ModelKit.newRig(name: string, rootSize: Vector3, rootName: string?): Rig
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = rootName or "Root"
	root.Size = rootSize
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = true
	root.CanTouch = false
	root.Anchored = false
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	return { model = model, root = root, parts = { [root.Name] = root }, scale = 1 }
end

-- spec = {
--   name, parent (nome da peça pai), joint (nome do Motor6D; nil = fixo), at = CFrame relativo ao pai,
--   shape = "ball"|"block"|"cyl"|"wedge"|"cwedge"|"ellipsoid", size = Vector3,
--   color = Color3, material = "SmoothPlastic"|..., role = "Body"|..., transparency, reflectance
-- }
function ModelKit.add(rig: Rig, spec): BasePart
	local parentPart = rig.parts[spec.parent or rig.root.Name]
	assert(parentPart, "peça pai inexistente: " .. tostring(spec.parent))
	local shape = spec.shape or "block"
	local p: BasePart
	if shape == "wedge" then
		p = Instance.new("WedgePart")
	elseif shape == "cwedge" then
		p = Instance.new("CornerWedgePart")
	else
		local part = Instance.new("Part")
		if shape == "ball" then
			part.Shape = Enum.PartType.Ball
		elseif shape == "cyl" then
			part.Shape = Enum.PartType.Cylinder
		end
		p = part
	end
	p.Name = spec.name or "Part"
	p.Size = spec.size
	p.Color = spec.color or Color3.new(1, 1, 1)
	p.Material = MATERIALS[spec.material or "SmoothPlastic"]
	p.Transparency = spec.transparency or 0
	p.Reflectance = spec.reflectance or 0
	p.CanCollide = false
	p.CanQuery = spec.query == true
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = spec.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p:SetAttribute("Role", spec.role or "Body")
	local at = spec.at or CFrame.new()
	p.CFrame = parentPart.CFrame * at
	local m = Instance.new("Motor6D")
	m.Name = spec.joint or "Fixed"
	m.Part0 = parentPart
	m.Part1 = p
	m.C0 = at
	m.C1 = CFrame.new()
	m.Parent = parentPart
	p.Parent = rig.model
	-- nomes repetidos: numera (Eye, Eye2, ...) para que `.Name` sempre identifique a peça
	local key = p.Name
	if rig.parts[key] then
		local i = 2
		while rig.parts[key .. i] do
			i += 1
		end
		key = key .. i
		p.Name = key
	end
	rig.parts[key] = p
	return p
end

-- Atalho para uma lista de olhos (par simétrico com brilho).
function ModelKit.eyes(rig: Rig, parent: string, x: number, y: number, z: number, r: number, color: Color3, glow: boolean?)
	for _, side in ipairs({ -1, 1 }) do
		ModelKit.add(rig, {
			name = "Eye", parent = parent, at = CFrame.new(side * x, y, z), shape = "ball", size = Vector3.one * r,
			color = color, material = glow and "Neon" or "SmoothPlastic", role = "Eye",
		})
		if not glow then
			ModelKit.add(rig, {
				name = "EyeShine", parent = parent, at = CFrame.new(side * x + side * r * 0.12, y + r * 0.22, z - r * 0.38),
				shape = "ball", size = Vector3.one * (r * 0.36), color = Color3.new(1, 1, 1), material = "Neon", role = "Eye", shadow = false,
			})
		end
	end
end

-- Referencial na superfície FRONTAL (-Z) de um elipsoide de tamanho `size`, no ponto de frações (fx, fy)
-- dos semi-eixos. O -Z local aponta para fora da superfície (normal); `out` desloca ao longo da normal.
function ModelKit.surface(size: Vector3, fx: number, fy: number, out: number?): CFrame
	local a, b, c = size.X / 2, size.Y / 2, size.Z / 2
	local zz = math.max(1 - fx * fx - fy * fy, 0.04)
	local pos = Vector3.new(fx * a, fy * b, -math.sqrt(zz) * c)
	local n = Vector3.new(pos.X / (a * a), pos.Y / (b * b), pos.Z / (c * c)).Unit
	local at = pos + n * (out or 0)
	return CFrame.lookAt(at, at + n)
end

-- Triângulo isósceles virado para a frente (-Z): base centrada na origem de `at`, ápice em +Y.
-- Feito com duas WedgePart espelhadas. Retorna o nome da primeira metade.
function ModelKit.tri(rig: Rig, spec): string
	local w, h, t = spec.width, spec.height, spec.thickness
	local first
	for _, side in ipairs({ -1, 1 }) do
		local p = ModelKit.add(rig, {
			name = spec.name or "Tri", parent = spec.parent, at = spec.at * CFrame.new(side * w / 4, h / 2, 0) * CFrame.Angles(0, side * math.rad(-90), 0),
			shape = "wedge", size = Vector3.new(t, h, w / 2), color = spec.color, material = spec.material, transparency = spec.transparency,
			role = spec.role, shadow = spec.shadow,
		})
		first = first or p.Name
	end
	return first
end

-- Olho detalhado (contorno, íris com profundidade, pupila, dois brilhos e pálpebra animável).
-- `at` = referencial na superfície da cabeça (-Z para fora). d = diâmetro.
-- A pálpebra superior usa a junta "LidL"/"LidR" (o Animator a desce para piscar; ver atributo BlinkDrop).
function ModelKit.detailedEye(rig: Rig, parent: string, at: CFrame, d: number, side: number, o)
	local glow = o.glow == true
	local iris = o.iris
	ModelKit.add(rig, { name = "EyeRim", parent = parent, at = at * CFrame.new(0, 0, 0.03 * d), shape = "ellipsoid", size = Vector3.new(d * 1.16, d * 1.04, d * 0.36),
		color = o.rim, role = "Detail", shadow = false })
	ModelKit.add(rig, { name = "Eye", parent = parent, at = at * CFrame.new(0, 0, -0.02 * d), shape = "ellipsoid", size = Vector3.new(d, d * 0.92, d * 0.36),
		color = iris, material = glow and "Neon" or "SmoothPlastic", role = "Eye", shadow = false })
	ModelKit.add(rig, { name = "EyeIris", parent = parent, at = at * CFrame.new(0, -0.1 * d, -0.06 * d), shape = "ellipsoid", size = Vector3.new(d * 0.7, d * 0.62, d * 0.3),
		color = iris:Lerp(Color3.new(1, 1, 1), glow and 0.45 or 0.28), material = glow and "Neon" or "SmoothPlastic", role = "Eye", shadow = false })
	ModelKit.add(rig, { name = "Pupil", parent = parent, at = at * CFrame.new(0, 0.01 * d, -0.1 * d), shape = "ellipsoid",
		size = o.slit and Vector3.new(d * 0.17, d * 0.66, d * 0.28) or Vector3.new(d * 0.5, d * 0.54, d * 0.28),
		color = glow and iris:Lerp(Color3.new(0, 0, 0), 0.7) or Color3.fromRGB(14, 11, 16), role = "Eye", shadow = false })
	ModelKit.add(rig, { name = "EyeShine", parent = parent, at = at * CFrame.new(-side * 0.17 * d, 0.14 * d, -0.17 * d), shape = "ball", size = Vector3.one * 0.28 * d,
		color = Color3.new(1, 1, 1), material = "Neon", role = "Detail", shadow = false })
	ModelKit.add(rig, { name = "EyeShine", parent = parent, at = at * CFrame.new(side * 0.16 * d, -0.19 * d, -0.15 * d), shape = "ball", size = Vector3.one * 0.12 * d,
		color = Color3.new(1, 1, 1), material = "Neon", transparency = 0.15, role = "Detail", shadow = false })
	if o.lid then
		-- em repouso a pálpebra fica recolhida DENTRO da cabeça, acima do olho (invisível);
		-- ao piscar o Animator a desliza para baixo e para fora (BlinkDrop/BlinkPush, no referencial do olho)
		local drop, push = 0.82 * d, 0.62 * d
		local lid = ModelKit.add(rig, { name = "Lid", parent = parent, joint = side < 0 and "LidL" or "LidR", at = at * CFrame.new(0, drop, push - 0.12 * d),
			shape = "ellipsoid", size = Vector3.new(d * 1.24, d * 1.02, d * 0.36), color = o.lid, role = "Body", shadow = false })
		lid:SetAttribute("BlinkDrop", drop)
		lid:SetAttribute("BlinkPush", push)
	end
end

-- Anel de pequenas peças (auréolas, órbitas, coroas).
function ModelKit.ring(rig: Rig, parent: string, joint: string?, at: CFrame, radius: number, count: number, pieceSize: Vector3, color: Color3, material: string?, role: string?, shape: string?)
	local hub = ModelKit.add(rig, {
		name = joint or "RingHub", parent = parent, joint = joint, at = at, shape = "block", size = Vector3.one * 0.2,
		color = color, transparency = 1, role = "Detail",
	})
	local hubKey = hub.Name
	for key, part in pairs(rig.parts) do
		if part == hub then
			hubKey = key
		end
	end
	for i = 1, count do
		local a = (i - 1) / count * math.pi * 2
		ModelKit.add(rig, {
			name = "RingPiece", parent = hubKey, at = CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius) * CFrame.Angles(0, -a, 0),
			shape = shape or "ball", size = pieceSize, color = color, material = material or "Neon", role = role or "Glow", shadow = false,
		})
	end
	return hub
end

-- Adiciona uma peça de colisão sólida (para inimigos/bosses grandes).
function ModelKit.hitbox(rig: Rig, size: Vector3, offset: CFrame?)
	local p = ModelKit.add(rig, { name = "Hitbox", at = offset or CFrame.new(), shape = "block", size = size, transparency = 1, role = "Detail", query = true })
	p.CanCollide = false
	return p
end

function ModelKit.lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

-- Ajusta o rig para ficar com a base em y = 0 relativo ao root e devolve a altura total.
function ModelKit.bounds(model: Model): (Vector3, CFrame)
	local cf, size = model:GetBoundingBox()
	return size, cf
end

return ModelKit

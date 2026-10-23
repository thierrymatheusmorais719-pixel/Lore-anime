-- Gera armas procedurais (katana, nodachi, lâmina de luz, garras, manopla) e as prende à mão.
-- O modelo tem atributos/attachments usados pelo cliente para rastros (TrailTop/TrailBottom).
local Elements = require(game:GetService("ReplicatedStorage").Shared.Config.Elements)

local WeaponBuilder = {}

local function newPart(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = model
	return p
end

local function weldAll(model: Model, handle: BasePart)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
		end
	end
end

local function trailAttachments(blade: BasePart, length: number)
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0, -length / 2)
	top.Parent = blade
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, 0, length * 0.15)
	bottom.Parent = blade
end

-- ===================================================================== ZANPAKUTŌ
-- Espada em peças com desenho próprio: cabo com amarração em losangos, pomo, tsuba (guarda)
-- conforme o `design`, habaki, lâmina em 3 segmentos com curvatura (sori), ponta (kissaki) em
-- cunha e linha do fio (hamon). O cabo corre ao longo de Z; a lâmina sai para -Z a partir da guarda.
-- designs: Classic (Asauchi), Flame, Ice, Lightning, Crescent, Manji (lâmina negra com corrente)
local DESIGN_FOR_STYLE = { LightBlade = "Quincy" }

local function cylinder(
	model: Model,
	name: string,
	diameter: number,
	thickness: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	-- Cilindro do Roblox corre em X; gira para o eixo Z do cabo
	local p = newPart(
		model,
		name,
		Vector3.new(thickness, diameter, diameter),
		cframe * CFrame.Angles(0, math.rad(90), 0),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function wedge(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Material = material or Enum.Material.Metal
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.Massless = true
	w.CastShadow = false
	w.Parent = model
	return w
end

local function buildGuard(model: Model, design: string, at: CFrame, color: Color3, accent: Color3, size: number)
	if design == "Flame" then
		cylinder(model, "Tsuba", size * 0.7, 0.1, at, color)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			wedge(
				model,
				"Flame",
				Vector3.new(0.08, size * 0.35, size * 0.22),
				at * CFrame.Angles(0, 0, a) * CFrame.new(0, size * 0.42, 0) * CFrame.Angles(math.rad(90), 0, 0),
				accent,
				Enum.Material.Neon
			)
		end
	elseif design == "Ice" then
		cylinder(model, "Tsuba", size * 0.55, 0.1, at, color:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Glass)
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + math.pi / 4
			newPart(
				model,
				"Crystal",
				Vector3.new(0.09, size * 0.62, 0.09),
				at * CFrame.Angles(0, 0, a) * CFrame.new(0, size * 0.32, 0),
				accent,
				Enum.Material.Glass
			).Transparency =
				0.25
		end
	elseif design == "Lightning" then
		newPart(model, "Tsuba", Vector3.new(size * 0.85, size * 0.45, 0.1), at, color)
		for i = -1, 1, 2 do
			newPart(
				model,
				"Bolt",
				Vector3.new(size * 0.35, 0.08, 0.12),
				at * CFrame.new(i * size * 0.5, size * 0.1, 0) * CFrame.Angles(0, 0, math.rad(35 * i)),
				accent,
				Enum.Material.Neon
			)
		end
	elseif design == "Crescent" then
		cylinder(model, "Tsuba", size * 0.45, 0.1, at, color)
		for i = -3, 3 do
			local a = math.rad(90 + i * 22)
			newPart(
				model,
				"Crescent",
				Vector3.new(0.14, 0.14, 0.1),
				at * CFrame.new(math.cos(a) * size * 0.42, math.sin(a) * size * 0.42 - size * 0.1, 0),
				accent,
				Enum.Material.Neon
			)
		end
	elseif design == "Manji" then
		-- guarda em manji (卍): quatro braços dobrados
		newPart(model, "Tsuba", Vector3.new(0.22, 0.22, 0.12), at, color)
		for i = 0, 3 do
			local r = at * CFrame.Angles(0, 0, i * math.pi / 2)
			newPart(model, "ManjiArm", Vector3.new(0.09, size * 0.45, 0.1), r * CFrame.new(0, size * 0.22, 0), color)
			newPart(
				model,
				"ManjiHook",
				Vector3.new(size * 0.25, 0.09, 0.1),
				r * CFrame.new(size * 0.11, size * 0.42, 0),
				color
			)
		end
	elseif design == "Quincy" then
		-- guarda em cruz (Quincy) com o centro aceso
		newPart(model, "Tsuba", Vector3.new(size * 0.9, 0.12, 0.12), at, color, Enum.Material.Neon)
		newPart(model, "CrossV", Vector3.new(0.12, size * 0.45, 0.12), at, color, Enum.Material.Neon)
		cylinder(model, "Core", 0.22, 0.14, at, accent, Enum.Material.Neon)
	else
		-- Classic: tsuba redonda escura com aro
		cylinder(model, "Tsuba", size * 0.7, 0.1, at, color)
		cylinder(model, "TsubaRim", size * 0.76, 0.06, at, accent)
	end
end

function WeaponBuilder.buildBlade(model: Model, handle: BasePart, spec: any, style: string, glowColor: Color3)
	local length = spec.length or 4
	local design = spec.design or DESIGN_FOR_STYLE[style] or "Classic"
	local bladeColor = spec.blade or Color3.fromRGB(210, 215, 225)
	local guardColor = spec.guard or Color3.fromRGB(35, 30, 28)
	local wrapColor = spec.wrap or Color3.fromRGB(28, 24, 36)
	local accent = if spec.glow then glowColor else Color3.fromRGB(190, 160, 90)
	local isLight = style == "LightBlade"
	local isNodachi = style == "Nodachi"
	local handleLength = if isNodachi then 1.6 else 1.15
	local width = if isNodachi then 0.32 else 0.24
	local origin = CFrame.new()

	-- Cabo: base envolvida, losangos da amarração, pomo (kashira)
	handle.Size = Vector3.new(0.24, 0.3, handleLength)
	handle.Color = wrapColor
	handle.Material = Enum.Material.Fabric
	if not isLight then
		local wraps = if isNodachi then 7 else 5
		for i = 0, wraps - 1 do
			local z = -handleLength / 2 + (i + 0.5) * handleLength / wraps
			local diamond = newPart(
				model,
				"Wrap",
				Vector3.new(0.26, 0.2, 0.2),
				origin * CFrame.new(0, 0, z) * CFrame.Angles(math.rad(45), 0, 0),
				Color3.fromRGB(225, 220, 205),
				Enum.Material.Fabric
			)
			diamond.Size = Vector3.new(0.27, 0.13, 0.13)
		end
		cylinder(model, "Kashira", 0.32, 0.12, origin * CFrame.new(0, 0, handleLength / 2 + 0.05), guardColor)
		if design == "Manji" then
			-- corrente presa ao pomo
			for i = 1, 5 do
				local link = newPart(
					model,
					"Chain",
					Vector3.new(0.06, 0.18, 0.28),
					origin
						* CFrame.new(0, -0.05 * i, handleLength / 2 + 0.12 + i * 0.22)
						* CFrame.Angles(0, if i % 2 == 0 then math.rad(90) else 0, 0),
					Color3.fromRGB(70, 70, 78)
				)
				link.Reflectance = 0.2
			end
		end
	else
		handle.Material = Enum.Material.Neon
		handle.Color = bladeColor:Lerp(Color3.new(1, 1, 1), 0.3)
		handle.Transparency = 0.2
	end

	-- Guarda e habaki
	local guardZ = -handleLength / 2 - 0.06
	buildGuard(model, design, origin * CFrame.new(0, 0, guardZ), guardColor, accent, if isNodachi then 1.0 else 0.82)
	if not isLight then
		newPart(
			model,
			"Habaki",
			Vector3.new(0.1, width + 0.06, 0.16),
			origin * CFrame.new(0, 0, guardZ - 0.13),
			Color3.fromRGB(200, 165, 80)
		)
	end

	-- Lâmina: 3 segmentos com curvatura crescente para o dorso (+Y), ponta em cunha
	local material = if isLight
		then Enum.Material.Neon
		elseif design == "Ice" then Enum.Material.Glass
		else Enum.Material.Metal
	local segments = 3
	local seg = (length - 0.45) / segments
	local frame = origin * CFrame.new(0, 0, guardZ - 0.2)
	local edgeParts = {}
	for i = 1, segments do
		local curve = if design == "Lightning" then (if i % 2 == 0 then -9 else 9) else 2.2 + i * 0.8
		local w = width * (1 - (i - 1) * 0.06)
		frame = frame * CFrame.Angles(math.rad(curve), 0, 0)
		local part = newPart(
			model,
			if i == 1 then "Blade" else "Blade" .. i,
			Vector3.new(0.065, w, seg + 0.02),
			frame * CFrame.new(0, 0, -seg / 2),
			bladeColor,
			material
		)
		part.Reflectance = if material == Enum.Material.Metal then 0.22 else 0
		if isLight or design == "Ice" then
			part.Transparency = if isLight then 0.15 else 0.2
		end
		-- linha do fio (lado -Y): clara no aço comum, acesa quando a arma brilha
		local edge = newPart(
			model,
			"Edge",
			Vector3.new(0.075, 0.045, seg),
			frame * CFrame.new(0, -w / 2 + 0.02, -seg / 2),
			if spec.glow then glowColor else bladeColor:Lerp(Color3.new(1, 1, 1), 0.6),
			if spec.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		)
		edge.Transparency = if spec.glow then 0.15 else 0.3
		table.insert(edgeParts, edge)
		frame = frame * CFrame.new(0, 0, -seg)
	end
	-- kissaki: cunha (face alta colada à lâmina em +Z); virada em Z para o fio subir até a ponta no dorso
	local tip = wedge(
		model,
		"Point",
		Vector3.new(0.065, width * 0.85, 0.5),
		frame * CFrame.new(0, 0, -0.25) * CFrame.Angles(0, 0, math.rad(180)),
		bladeColor,
		material
	)
	tip.Reflectance = if material == Enum.Material.Metal then 0.22 else 0
	if isLight or design == "Ice" then
		tip.Transparency = 0.15
	end
	if spec.glow then
		local light = Instance.new("PointLight")
		light.Color = glowColor
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = model:FindFirstChild("Blade")
	end

	-- Hospedeiro do rastro ao longo da lâmina real (mesmo comprimento e curvatura aproximada)
	local trailHost = newPart(
		model,
		"TrailHost",
		Vector3.new(0.05, 0.05, length),
		origin * CFrame.new(0, 0.12, guardZ - 0.2 - length / 2),
		bladeColor
	)
	trailHost.Transparency = 1
	trailAttachments(trailHost, length)
	model:SetAttribute("Grip", if isNodachi then 0.4 else 0.25)
	model:SetAttribute("Design", design)
end

-- Constrói o modelo com o cabo na origem e a lâmina apontando para -Z.
function WeaponBuilder.buildModel(spec: any, elementId: string?): Model
	local model = Instance.new("Model")
	model.Name = "Weapon"
	local element = Elements[elementId or "Reiatsu"] or Elements.Reiatsu
	local glowColor = element.primary
	local style = spec.style or "Katana"
	local length = spec.length or 4
	local bladeColor = spec.blade or Color3.fromRGB(210, 215, 225)
	local guardColor = spec.guard or Color3.fromRGB(35, 30, 28)
	local origin = CFrame.new()

	local handle =
		newPart(model, "Handle", Vector3.new(0.28, 0.28, 1.1), origin, Color3.fromRGB(25, 22, 30), Enum.Material.Fabric)
	model.PrimaryPart = handle
	model:SetAttribute("Style", style)

	if style == "Katana" or style == "Nodachi" or style == "LightBlade" then
		WeaponBuilder.buildBlade(model, handle, spec, style, glowColor)
	elseif style == "Claws" then
		-- bodyClaws: a criatura já tem garras no corpo; só o hospedeiro invisível do rastro é criado
		for i = -1, if spec.bodyClaws then -2 else 1 do
			local claw = newPart(
				model,
				"Claw",
				Vector3.new(0.12, 0.12, length),
				origin * CFrame.new(i * 0.28, -0.05, -0.2 - length / 2) * CFrame.Angles(0, math.rad(i * 6), 0),
				bladeColor,
				Enum.Material.SmoothPlastic
			)
			if spec.glow then
				claw.Material = Enum.Material.Neon
				claw.Color = bladeColor:Lerp(glowColor, 0.5)
			end
		end
		handle.Transparency = 1
		local trailHost = newPart(
			model,
			"TrailHost",
			Vector3.new(0.05, 0.05, length),
			origin * CFrame.new(0, 0, -0.2 - length / 2),
			bladeColor
		)
		trailHost.Transparency = 1
		trailAttachments(trailHost, length)
	elseif style == "Gauntlet" then
		handle.Transparency = 1
		newPart(
			model,
			"Gauntlet",
			Vector3.new(1.15, 0.6, 1.15),
			origin * CFrame.new(0, 0.15, 0),
			bladeColor,
			Enum.Material.Metal
		)
		newPart(
			model,
			"Cuff",
			Vector3.new(1.2, 0.35, 1.2),
			origin * CFrame.new(0, 0.6, 0),
			guardColor,
			Enum.Material.Neon
		)
		for i = -1, 1 do
			newPart(
				model,
				"Spike",
				Vector3.new(0.15, 0.15, 0.5),
				origin * CFrame.new(i * 0.32, 0.1, -0.7),
				guardColor,
				Enum.Material.Neon
			)
		end
		local trailHost =
			newPart(model, "TrailHost", Vector3.new(0.05, 0.05, length), origin * CFrame.new(0, 0, -0.3), bladeColor)
		trailHost.Transparency = 1
		trailAttachments(trailHost, length)
	end

	weldAll(model, handle)
	return model
end

-- Bainha decorativa (katanas) presa ao quadril esquerdo.
function WeaponBuilder.buildSheath(character: Model, length: number): BasePart?
	local lower = character:FindFirstChild("LowerTorso") :: BasePart?
	if not lower then
		return nil
	end
	local sheath = Instance.new("Part")
	sheath.Name = "Sheath"
	sheath.Size = Vector3.new(0.22, 0.32, length * 0.95)
	sheath.Color = Color3.fromRGB(20, 18, 24)
	sheath.Material = Enum.Material.SmoothPlastic
	sheath.CanCollide = false
	sheath.CanQuery = false
	sheath.CanTouch = false
	sheath.Massless = true
	local offset = CFrame.new(-1.15, -0.1, 0.25)
		* CFrame.Angles(math.rad(-160), 0, 0)
		* CFrame.new(0, 0, -(0.65 + length * 0.47))
	sheath.CFrame = lower.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = lower
	weld.Part1 = sheath
	weld.C0 = offset
	weld.Parent = sheath
	sheath.Parent = character
	return sheath
end

-- Prende o modelo à mão (empunhado) e prepara a solda de quadril (embainhado).
-- O atributo "Drawn" no personagem alterna entre as duas soldas.
function WeaponBuilder.attach(character: Model, model: Model, handName: string?): Model?
	local hand = character:FindFirstChild(handName or "RightHand") :: BasePart?
	local lower = character:FindFirstChild("LowerTorso") :: BasePart?
	local handle = model.PrimaryPart
	if not hand or not lower or not handle then
		model:Destroy()
		return nil
	end
	local style = model:GetAttribute("Style")
	local sheathable = style == "Katana" or style == "Nodachi" or style == "LightBlade"

	-- Empunhadura = Motor6D animável ("Weapon" na mão direita, "OffHand" na esquerda), no mesmo
	-- referencial das juntas de prop da skill roblox-vfx-animation: C0 no ponto de empunhadura
	-- girado -90° em X (lâmina = +Y do prop). Com Transform identidade a lâmina sai do punho para frente.
	local isRight = (handName or "RightHand") == "RightHand"
	local gripAttachment =
		hand:FindFirstChild(if isRight then "RightGripAttachment" else "LeftGripAttachment") :: Attachment?
	local gripPosition = if gripAttachment then gripAttachment.Position else Vector3.new(0, -0.158, 0)
	local grip = Instance.new("Motor6D")
	grip.Name = if isRight then "Weapon" else "OffHand"
	grip.Part0 = hand
	grip.Part1 = handle
	grip.C0 = CFrame.new(gripPosition) * CFrame.Angles(math.rad(-90), 0, 0)
	-- a mão fica perto da guarda, num ponto próprio de cada arma (cabo de nodachi é mais longo)
	local gripOffset = (model:GetAttribute("Grip") :: number?) or 0.3
	grip.C1 = CFrame.new(0, 0, gripOffset) * CFrame.Angles(math.rad(-90), 0, 0)
	grip:SetAttribute("Grip", true)
	grip.Parent = handle

	if sheathable and (handName or "RightHand") == "RightHand" then
		local hip = Instance.new("Weld")
		hip.Name = "HipWeld"
		hip.Part0 = lower
		hip.Part1 = handle
		hip.C0 = CFrame.new(-1.15, -0.1, 0.25) * CFrame.Angles(math.rad(-160), 0, 0)
		hip.Enabled = false
		hip.Parent = handle
	end
	model:SetAttribute("Hand", handName or "RightHand")
	model.Parent = character
	return model
end

-- Alterna mão/quadril conforme `drawn`.
function WeaponBuilder.setDrawn(model: Model, drawn: boolean)
	local handle = model.PrimaryPart
	if not handle then
		return
	end
	local grip = (handle:FindFirstChild("Weapon") or handle:FindFirstChild("OffHand")) :: Motor6D?
	local hip = handle:FindFirstChild("HipWeld") :: Weld?
	if not hip then
		return
	end
	if grip then
		grip.Enabled = drawn
	end
	hip.Enabled = not drawn
end

return WeaponBuilder

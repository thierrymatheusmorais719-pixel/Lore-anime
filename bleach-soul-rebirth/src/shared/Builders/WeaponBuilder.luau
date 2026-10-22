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
		local width = if style == "Nodachi" then 0.32 else 0.24
		local isLight = style == "LightBlade"
		if not isLight then
			newPart(model, "Guard", Vector3.new(0.75, 0.75, 0.1), origin * CFrame.new(0, 0, -0.6), guardColor)
		else
			newPart(
				model,
				"Guard",
				Vector3.new(0.5, 0.18, 0.18),
				origin * CFrame.new(0, 0, -0.6),
				guardColor,
				Enum.Material.Neon
			)
		end
		-- Lâmina em dois segmentos com leve curvatura
		local seg = length / 2
		local material = if isLight then Enum.Material.Neon else Enum.Material.Metal
		local blade1 = newPart(
			model,
			"Blade",
			Vector3.new(0.07, width, seg),
			origin * CFrame.new(0, 0, -0.65 - seg / 2),
			bladeColor,
			material
		)
		local blade2 = newPart(
			model,
			"BladeTip",
			Vector3.new(0.07, width * 0.9, seg),
			blade1.CFrame * CFrame.new(0, 0, -seg / 2) * CFrame.Angles(math.rad(4), 0, 0) * CFrame.new(0, 0, -seg / 2),
			bladeColor,
			material
		)
		local tip = newPart(
			model,
			"Point",
			Vector3.new(0.07, width * 0.9, 0.45),
			blade2.CFrame * CFrame.new(0, 0.05, -seg / 2 - 0.2) * CFrame.Angles(math.rad(12), 0, 0),
			bladeColor,
			material
		)
		if isLight then
			blade1.Transparency = 0.15
			blade2.Transparency = 0.15
			tip.Transparency = 0.15
		end
		if spec.glow then
			local edge = newPart(
				model,
				"Edge",
				Vector3.new(0.09, 0.05, length * 0.95),
				blade1.CFrame * CFrame.new(0, -width / 2, -seg / 2),
				glowColor,
				Enum.Material.Neon
			)
			edge.Transparency = 0.2
			local light = Instance.new("PointLight")
			light.Color = glowColor
			light.Range = 8
			light.Brightness = 1.2
			light.Parent = blade1
		end
		local trailHost = newPart(
			model,
			"TrailHost",
			Vector3.new(0.05, 0.05, length),
			origin * CFrame.new(0, 0, -0.65 - length / 2),
			bladeColor
		)
		trailHost.Transparency = 1
		trailAttachments(trailHost, length)
	elseif style == "Claws" then
		for i = -1, 1 do
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
	grip.C1 = CFrame.new(0, 0, 0.3) * CFrame.Angles(math.rad(-90), 0, 0)
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

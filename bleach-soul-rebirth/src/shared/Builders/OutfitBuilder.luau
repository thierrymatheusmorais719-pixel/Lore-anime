-- Acessórios de facção/forma sobre o avatar: faixa (obi), painéis de tecido nas costas
-- (haori/capa/sobretudo de Bankai), buraco Hollow e fragmentos de osso.
-- Painéis de tecido usam Motor6D "Cloth*" que o cliente anima com molas (ClothController).
local NpcStyle = require(script.Parent.NpcStyle)

local OutfitBuilder = {}

-- Uniforme de cada facção (roupa esculpida do NpcStyle por cima do avatar do jogador)
local UNIFORMS = {
	Shinigami = function(o: any)
		return "shihakusho", { robe = o.robe, obi = o.trim, inner = Color3.fromRGB(240, 240, 242) }
	end,
	Quincy = function(o: any)
		return "quincy", { coat = o.robe, trim = o.trim }
	end,
	Hollow = function(o: any)
		return "arrancar", { coat = o.robe, sash = o.trim }
	end,
	Fullbringer = function(o: any)
		return "fullbring", { jacket = o.robe, glow = o.trim }
	end,
}

-- Roupa do avatar (camisa/calça 2D e roupas em camadas) sai para o uniforme aparecer; cabelo,
-- chapéus, rosto e cor de pele ficam.
local CLOTHING_TYPES = {
	"Shirt",
	"Pants",
	"Jacket",
	"Sweater",
	"Shorts",
	"DressSkirt",
	"TShirt",
	"LeftShoe",
	"RightShoe",
}
function OutfitBuilder.stripClothing(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			local layered = handle and handle:FindFirstChildOfClass("WrapLayer")
			local typeName = (child :: any).AccessoryType and (child :: any).AccessoryType.Name
			if layered or (typeName and table.find(CLOTHING_TYPES, typeName)) then
				child:Destroy()
			end
		end
	end
end

-- Veste o uniforme da facção. Devolve true se havia uniforme para ela.
function OutfitBuilder.applyUniform(character: Model, factionId: string, outfit: any): boolean
	local make = UNIFORMS[factionId]
	if not make then
		NpcStyle.undress(character)
		return false
	end
	OutfitBuilder.stripClothing(character)
	local name, colors = make(outfit)
	NpcStyle.dress(character, name, colors)
	character:SetAttribute("UniformVersion", ((character:GetAttribute("UniformVersion") :: number?) or 0) + 1)
	return true
end

local function weldPart(
	base: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = base.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = base
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	return p
end

-- Painel articulado: Motor6D com pivô no topo, para o cliente balançar.
local function clothPanel(
	base: BasePart,
	name: string,
	size: Vector3,
	pivot: CFrame,
	color: Color3,
	folder: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Fabric
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	local motor = Instance.new("Motor6D")
	motor.Name = "Cloth" .. name
	motor.Part0 = base
	motor.Part1 = p
	motor.C0 = pivot
	motor.C1 = CFrame.new(0, size.Y / 2, 0)
	motor.Parent = p
	p.CFrame = base.CFrame * motor.C0 * motor.C1:Inverse()
	p.Parent = folder
	return p
end

export type OutfitSpec = {
	trim: Color3?,
	robe: Color3?,
	cape: boolean?,
	coat: Color3?, -- sobretudo longo (Bankai / formas finais)
	hollowHole: boolean?,
	bone: boolean?,
	uniform: boolean?, -- o uniforme esculpido já tem gola, faixa, capa e buraco: não duplica
}

-- Remove o traje anterior e aplica o novo. Retorna a pasta criada.
function OutfitBuilder.apply(character: Model, spec: OutfitSpec): Folder?
	local old = character:FindFirstChild("Outfit")
	if old then
		old:Destroy()
	end
	local upper = character:FindFirstChild("UpperTorso") :: BasePart?
	local lower = character:FindFirstChild("LowerTorso") :: BasePart?
	if not upper or not lower then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "Outfit"

	local trim = spec.trim or Color3.fromRGB(235, 235, 240)
	local robe = spec.robe or Color3.fromRGB(20, 20, 24)
	local uw, uh, ud = upper.Size.X, upper.Size.Y, upper.Size.Z
	local lw, ld = lower.Size.X, lower.Size.Z

	if not spec.uniform then
		weldPart(lower, "Sash", Vector3.new(lw + 0.08, 0.32, ld + 0.08), CFrame.new(0, 0.05, 0), trim).Parent = folder
		weldPart(upper, "Collar", Vector3.new(uw * 0.55, 0.25, ud + 0.06), CFrame.new(0, uh / 2 - 0.1, 0), trim).Parent =
			folder
	end

	if spec.coat then
		-- Sobretudo longo: dois painéis traseiros + mangas no ombro
		for i = -1, 1, 2 do
			-- nomes com forma esculpida no HumanSkin (tecido curvo em vez de chapa)
			clothPanel(
				upper,
				"HaoriBack",
				Vector3.new(uw * 0.5, 3.4, 0.1),
				CFrame.new(i * uw * 0.26, uh / 2 - 0.1, ud / 2 + 0.08),
				spec.coat,
				folder
			)
			weldPart(
				upper,
				"HaoriShoulder",
				Vector3.new(0.6, 0.3, ud + 0.12),
				CFrame.new(i * (uw / 2 + 0.2), uh / 2 - 0.05, 0),
				spec.coat
			).Parent =
				folder
		end
		if not spec.uniform then -- o uniforme já tem gola; a faixa neon no peito sobrava
			weldPart(
				upper,
				"CoatTrim",
				Vector3.new(uw + 0.06, 0.12, ud + 0.06),
				CFrame.new(0, uh / 2 - 0.3, 0),
				trim,
				Enum.Material.Neon
			).Parent =
				folder
		end
	elseif spec.uniform then
		-- uniforme esculpido já completo (capa Quincy inclusa)
	elseif spec.cape then
		clothPanel(
			upper,
			"Cape",
			Vector3.new(uw * 0.95, 3, 0.1),
			CFrame.new(0, uh / 2 - 0.05, ud / 2 + 0.08),
			Color3.fromRGB(245, 247, 252),
			folder
		)
	else
		-- Painel curto (haori/jaqueta)
		for i = -1, 1, 2 do
			clothPanel(
				lower,
				"HaoriSkirt",
				Vector3.new(lw * 0.48, 1.5, 0.1),
				CFrame.new(i * lw * 0.25, 0, ld / 2 + 0.06),
				robe,
				folder
			)
		end
	end

	if spec.hollowHole and not spec.uniform then
		local hole = weldPart(
			upper,
			"HollowHole",
			Vector3.new(0.12, 0.7, 0.7),
			CFrame.new(0, 0.1, -ud / 2 - 0.01) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(5, 5, 8),
			Enum.Material.SmoothPlastic
		)
		hole.Shape = Enum.PartType.Cylinder
		hole.Parent = folder
	end
	if spec.bone then
		for i = -1, 1, 2 do
			weldPart(
				upper,
				"Bone",
				Vector3.new(0.9, 0.35, 1.1),
				CFrame.new(i * (uw / 2 + 0.25), uh / 2, 0) * CFrame.Angles(0, 0, math.rad(-12 * i)),
				Color3.fromRGB(240, 236, 225),
				Enum.Material.SmoothPlastic
			).Parent =
				folder
		end
	end

	folder.Parent = character
	return folder
end

-- Máscara Hollow (Visored) no rosto.
function OutfitBuilder.setMask(character: Model, enabled: boolean)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local existing = character:FindFirstChild("HollowMask")
	if existing then
		existing:Destroy()
	end
	if not enabled then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "HollowMask"
	local hs = head.Size
	weldPart(
		head,
		"Mask",
		Vector3.new(hs.X * 1.08, hs.Y * 1.05, 0.2),
		CFrame.new(0, 0, -hs.Z / 2 - 0.08),
		Color3.fromRGB(248, 248, 245),
		Enum.Material.SmoothPlastic
	).Parent =
		folder
	for i = -1, 1, 2 do
		weldPart(
			head,
			"Stripe",
			Vector3.new(0.1, hs.Y * 0.85, 0.05),
			CFrame.new(i * hs.X * 0.3, 0, -hs.Z / 2 - 0.2),
			Color3.fromRGB(210, 20, 35),
			Enum.Material.Neon
		).Parent =
			folder
		weldPart(
			head,
			"Eye",
			Vector3.new(0.25, 0.12, 0.05),
			CFrame.new(i * hs.X * 0.2, hs.Y * 0.1, -hs.Z / 2 - 0.21),
			Color3.fromRGB(255, 200, 40),
			Enum.Material.Neon
		).Parent =
			folder
	end
	weldPart(
		head,
		"Teeth",
		Vector3.new(hs.X * 0.7, 0.1, 0.05),
		CFrame.new(0, -hs.Y * 0.3, -hs.Z / 2 - 0.2),
		Color3.fromRGB(20, 20, 20),
		Enum.Material.SmoothPlastic
	).Parent =
		folder
	folder.Parent = character
end

return OutfitBuilder

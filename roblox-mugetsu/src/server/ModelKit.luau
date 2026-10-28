--!strict
-- Kits visuais do personagem (Ichigo / Mugetsu) construídos sobre o rig R15 EXISTENTE.
-- Nada substitui o corpo: as peças são soldadas aos membros, então o rig, as juntas e as animações
-- continuam compatíveis. A troca de forma faz crossfade de Transparency + troca de cor da pele.
--
-- Ponto de integração: se existir ServerStorage.MugetsuAssets.MugetsuKit (Model) com peças que tenham
--   Attribute "AttachTo" (string, nome do membro R15) e "Offset" (CFrame relativo ao membro),
--   mais Attribute "Form" ("Ichigo" | "Mugetsu"), elas são usadas no lugar das peças procedurais.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Manifest = require(game:GetService("ReplicatedStorage"):WaitForChild("Mugetsu"):WaitForChild("AssetManifest"))

export type Form = "Ichigo" | "Mugetsu"

local ModelKit = {}

local SKIN = {
	Ichigo = Color3.fromRGB(240, 190, 150),
	Mugetsu = Color3.fromRGB(226, 218, 210),
}

local LIMBS = {
	"Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = true
	p:SetAttribute("BaseTransparency", 0)
	p.Parent = parent
	return p
end

local function weld(p0: BasePart, p1: BasePart, c0: CFrame)
	local w = Instance.new("Weld")
	w.Part0 = p0
	w.Part1 = p1
	w.C0 = c0
	w.Parent = p1
end

-- Cadeia de cabelo: segmentos ligados por Motor6D; o cliente balança via Transform (tag MugetsuHair).
local function hairStrand(
	kit: Folder, head: BasePart, name: string, root: CFrame, lengths: { number }, width: number, color: Color3, bend: number
)
	local prev: BasePart = head
	local prevLen = 0
	for i, len in lengths do
		local w = width * (1 - (i - 1) * 0.18)
		local seg = makePart(`{name}_{i}`, Vector3.new(w, len, w * 0.55), color, Enum.Material.SmoothPlastic, kit)
		local m = Instance.new("Motor6D")
		m.Part0 = prev
		m.Part1 = seg
		if i == 1 then
			m.C0 = root
		else
			m.C0 = CF(0, -prevLen / 2, 0) * ANG(rad(bend), 0, 0)
		end
		m.C1 = CF(0, len / 2, 0)
		m:SetAttribute("Index", i)
		m:SetAttribute("Phase", #name * 0.7)
		m.Parent = seg
		CollectionService:AddTag(m, "MugetsuHair")
		prev, prevLen = seg, len
	end
end

local function buildIchigo(char: Model, kit: Folder)
	local head = char:FindFirstChild("Head") :: BasePart
	local lower = char:FindFirstChild("LowerTorso") :: BasePart
	local rHand = char:FindFirstChild("RightHand") :: BasePart
	local upper = char:FindFirstChild("UpperTorso") :: BasePart
	local rUpper = char:FindFirstChild("RightUpperArm") :: BasePart
	local orange = Color3.fromRGB(255, 132, 20)
	local black = Color3.fromRGB(14, 14, 16)

	-- cabelo laranja espetado
	for i = 1, 11 do
		local a = (i / 11) * math.pi * 2
		local spike = makePart(`Spike{i}`, Vector3.new(0.34, 0.9, 0.34), orange, Enum.Material.SmoothPlastic, kit)
		weld(head, spike, CF(math.cos(a) * 0.5, 0.62, math.sin(a) * 0.45) * ANG(math.sin(a) * 0.7, 0, -math.cos(a) * 0.7))
	end
	local cap = makePart("HairCap", Vector3.new(1.15, 0.5, 1.1), orange, Enum.Material.SmoothPlastic, kit)
	weld(head, cap, CF(0, 0.45, 0.05))

	-- shihakushō: abas e traseira
	local back = makePart("CoatBack", Vector3.new(2.1, 3.5, 0.15), black, Enum.Material.Fabric, kit)
	weld(lower, back, CF(0, -1.7, 0.62) * ANG(rad(6), 0, 0))
	for _, s in { -1, 1 } do
		local flap = makePart("CoatFlap", Vector3.new(0.15, 3.2, 1.1), black, Enum.Material.Fabric, kit)
		weld(lower, flap, CF(s * 1.12, -1.6, 0.1) * ANG(0, 0, rad(-s * 6)))
	end
	local sash = makePart("Sash", Vector3.new(2.15, 0.35, 1.1), Color3.fromRGB(235, 235, 235), Enum.Material.Fabric, kit)
	weld(lower, sash, CF(0, 0.15, 0))
	local collar = makePart("Collar", Vector3.new(2.1, 0.5, 1.05), black, Enum.Material.Fabric, kit)
	weld(upper, collar, CF(0, 0.55, 0.05))
	local backUpper = makePart("CoatBackUpper", Vector3.new(2.1, 1.1, 0.12), black, Enum.Material.Fabric, kit)
	weld(upper, backUpper, CF(0, 0.2, 0.56))

	-- braço direito enfaixado
	local wrap = makePart("ArmWrap", Vector3.new(1.15, 1.3, 1.15), Color3.fromRGB(215, 205, 190), Enum.Material.Fabric, kit)
	weld(rUpper, wrap, CF(0, 0, 0))

	-- Tensa Zangetsu (Bankai): lâmina negra
	local handle = makePart("SwordHandle", Vector3.new(0.28, 0.28, 0.9), black, Enum.Material.Metal, kit)
	weld(rHand, handle, CF(0, -0.2, 0) * ANG(rad(-50), 0, 0))
	local blade = makePart("Blade", Vector3.new(0.12, 0.55, 3.6), Color3.fromRGB(10, 10, 12), Enum.Material.Metal, kit)
	weld(handle, blade, CF(0, 0, -(0.45 + 1.8)))
	local edgeA = Instance.new("Attachment")
	edgeA.Name = "TrailA"
	edgeA.Position = Vector3.new(0, 0.27, -1.7)
	edgeA.Parent = blade
	local edgeB = Instance.new("Attachment")
	edgeB.Name = "TrailB"
	edgeB.Position = Vector3.new(0, -0.27, -1.7)
	edgeB.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, 0, -1.8)
	tip.Parent = blade
end

local function buildMugetsu(char: Model, kit: Folder)
	local head = char:FindFirstChild("Head") :: BasePart
	local lower = char:FindFirstChild("LowerTorso") :: BasePart
	local upper = char:FindFirstChild("UpperTorso") :: BasePart
	local rHand = char:FindFirstChild("RightHand") :: BasePart
	local rUpper = char:FindFirstChild("RightUpperArm") :: BasePart
	local rLower = char:FindFirstChild("RightLowerArm") :: BasePart
	local black = Color3.fromRGB(8, 8, 10)

	-- cabelo longo: cortina frontal + mechas laterais + cascata traseira
	local strands = {
		{ "BackA", CF(0, 0.55, 0.38) * ANG(0, 0, 0) * ANG(rad(-40), 0, 0), { 1.3, 1.5, 1.7, 1.9 }, 1.3, -6 },
		{ "BackB", CF(0.3, 0.5, 0.35) * ANG(0, rad(-25), 0) * ANG(rad(-38), 0, 0), { 1.2, 1.5, 1.8, 1.8 }, 0.95, -7 },
		{ "BackC", CF(-0.3, 0.5, 0.35) * ANG(0, rad(25), 0) * ANG(rad(-38), 0, 0), { 1.2, 1.5, 1.8, 1.8 }, 0.95, -7 },
		{ "BackD", CF(0.5, 0.4, 0.25) * ANG(0, rad(-60), 0) * ANG(rad(-30), 0, 0), { 1.0, 1.3, 1.6 }, 0.8, -6 },
		{ "BackE", CF(-0.5, 0.4, 0.25) * ANG(0, rad(60), 0) * ANG(rad(-30), 0, 0), { 1.0, 1.3, 1.6 }, 0.8, -6 },
		{ "SideR", CF(0.55, 0.25, -0.1) * ANG(0, rad(-90), 0) * ANG(rad(-8), 0, 0), { 0.9, 1.1, 1.3 }, 0.55, -4 },
		{ "SideL", CF(-0.55, 0.25, -0.1) * ANG(0, rad(90), 0) * ANG(rad(-8), 0, 0), { 0.9, 1.1, 1.3 }, 0.55, -4 },
		{ "BangR", CF(0.3, 0.6, -0.45) * ANG(rad(8), 0, rad(-6)), { 0.8, 0.9 }, 0.26, -3 },
		{ "BangL", CF(-0.3, 0.6, -0.45) * ANG(rad(8), 0, rad(6)), { 0.8, 0.9 }, 0.26, -3 },
	}
	for _, s in strands do
		hairStrand(kit, head, s[1], s[2], s[3], s[4], black, s[5])
	end
	local crown = makePart("HairCrown", Vector3.new(1.2, 0.55, 1.15), black, Enum.Material.SmoothPlastic, kit)
	weld(head, crown, CF(0, 0.5, 0.08))

	-- máscara na parte inferior do rosto
	local mask = makePart("FaceMask", Vector3.new(1.05, 0.5, 0.2), Color3.fromRGB(86, 104, 118), Enum.Material.Fabric, kit)
	weld(head, mask, CF(0, -0.22, -0.52))
	-- olhos vermelhos (brilho mínimo, só detalhe)
	for _, s in { -1, 1 } do
		local eye = makePart("Eye", Vector3.new(0.22, 0.08, 0.05), Color3.fromRGB(200, 20, 30), Enum.Material.Neon, kit)
		weld(head, eye, CF(s * 0.25, 0.1, -0.53))
	end

	-- bandagem do torso (faixas diagonais) e braço direito
	for i = 1, 6 do
		local band = makePart(`Wrap{i}`, Vector3.new(2.08, 0.2, 1.08), Color3.fromRGB(205, 205, 200), Enum.Material.Fabric, kit)
		weld(upper, band, CF(0, 0.65 - i * 0.24, 0) * ANG(0, 0, rad(i % 2 == 0 and 5 or -5)))
	end
	for i = 1, 4 do
		local stripe = makePart(`Stripe{i}`, Vector3.new(1.08, 0.12, 1.08), black, Enum.Material.SmoothPlastic, kit)
		weld(rUpper, stripe, CF(0, 0.5 - i * 0.28, 0) * ANG(0, rad(i * 14), rad(8)))
	end
	local armBand = makePart("ForearmWrap", Vector3.new(1.08, 1.0, 1.08), Color3.fromRGB(205, 205, 200), Enum.Material.Fabric, kit)
	weld(rLower, armBand, CF(0, 0.1, 0))

	-- casaco longo rasgado
	local coatBack = makePart("CoatBack", Vector3.new(2.3, 4.2, 0.12), black, Enum.Material.Fabric, kit)
	weld(lower, coatBack, CF(0, -2.1, 0.66) * ANG(rad(8), 0, 0))
	for i = 1, 5 do
		local tatter = makePart(`Tatter{i}`, Vector3.new(0.42, 1.4 + (i % 3) * 0.5, 0.1), black, Enum.Material.Fabric, kit)
		weld(lower, tatter, CF(-0.92 + (i - 1) * 0.46, -4.6 - (i % 3) * 0.1, 0.72) * ANG(rad(10 + i * 2), 0, rad((i - 3) * 3)))
	end
	for _, s in { -1, 1 } do
		local flap = makePart("CoatFlap", Vector3.new(0.14, 3.6, 1.2), black, Enum.Material.Fabric, kit)
		weld(lower, flap, CF(s * 1.14, -1.8, 0.1) * ANG(0, 0, rad(-s * 9)))
	end
	local belt = makePart("Belt", Vector3.new(2.15, 0.3, 1.1), black, Enum.Material.Fabric, kit)
	weld(lower, belt, CF(0, 0.15, 0))

	-- Tensa Zangetsu (Mugetsu): katana negra com corrente no pomo
	local handle = makePart("SwordHandle", Vector3.new(0.26, 0.26, 0.9), black, Enum.Material.Metal, kit)
	weld(rHand, handle, CF(0, -0.2, 0) * ANG(rad(-50), 0, 0))
	local guard = makePart("Guard", Vector3.new(0.55, 0.55, 0.12), Color3.fromRGB(25, 25, 28), Enum.Material.Metal, kit)
	weld(handle, guard, CF(0, 0, -0.5))
	local blade = makePart("Blade", Vector3.new(0.1, 0.5, 3.4), black, Enum.Material.Metal, kit)
	weld(handle, blade, CF(0, 0, -(0.55 + 1.7)))
	local a = Instance.new("Attachment")
	a.Name = "TrailA"
	a.Position = Vector3.new(0, 0.25, -1.6)
	a.Parent = blade
	local b = Instance.new("Attachment")
	b.Name = "TrailB"
	b.Position = Vector3.new(0, -0.25, -1.6)
	b.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, 0, -1.7)
	tip.Parent = blade
	local prev: BasePart = handle
	for i = 1, 4 do
		local link = makePart(`Chain{i}`, Vector3.new(0.14, 0.14, 0.34), Color3.fromRGB(60, 60, 66), Enum.Material.Metal, kit)
		weld(prev, link, CF(0.0, -0.05 * i, (i == 1 and 0.6 or 0.3)) * ANG(rad(14), 0, 0))
		prev = link
	end
end

local function tagAuraAnchors(char: Model)
	local function anchor(partName: string, attName: string, pos: Vector3?)
		local p = char:FindFirstChild(partName)
		if p and p:IsA("BasePart") and not p:FindFirstChild(attName) then
			local at = Instance.new("Attachment")
			at.Name = attName
			at.Position = pos or Vector3.zero
			at.Parent = p
		end
	end
	anchor("UpperTorso", "AuraChest")
	anchor("LowerTorso", "AuraFeet", Vector3.new(0, -3.2, 0))
	anchor("Head", "AuraHead")
	anchor("RightLowerArm", "AuraRArm")
	anchor("LeftLowerArm", "AuraLArm")
	anchor("RightHand", "AuraHand")
end

local function tryCustomKit(char: Model, form: Form, kit: Folder): boolean
	local node: Instance? = ServerStorage
	for _, n in Manifest.CustomKitPath do
		node = node and node:FindFirstChild(n)
	end
	if not node then
		return false
	end
	local used = false
	for _, d in node:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Form") == form then
			local limb = char:FindFirstChild(d:GetAttribute("AttachTo") or "")
			local offset = d:GetAttribute("Offset")
			if limb and limb:IsA("BasePart") and typeof(offset) == "CFrame" then
				local c = d:Clone()
				c.Anchored = false
				c.CanCollide = false
				c.CanQuery = false
				c.CanTouch = false
				c.Massless = true
				c:SetAttribute("BaseTransparency", d.Transparency)
				c.Parent = kit
				weld(limb :: BasePart, c, offset :: CFrame)
				used = true
			end
		end
	end
	return used
end

local function setKitTransparency(kit: Folder, hidden: boolean)
	for _, d in kit:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = hidden and 1 or (d:GetAttribute("BaseTransparency") :: number? or 0)
		end
	end
end

function ModelKit.isR15(char: Model): boolean
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.RigType == Enum.HumanoidRigType.R15
end

-- Cria os dois kits (Ichigo visível, Mugetsu oculto). Idempotente.
function ModelKit.build(char: Model)
	if char:FindFirstChild("MugetsuKits") then
		return
	end
	local root = Instance.new("Folder")
	root.Name = "MugetsuKits"
	tagAuraAnchors(char)

	for _, form in { "Ichigo", "Mugetsu" } :: { Form } do
		local kit = Instance.new("Folder")
		kit.Name = form
		kit.Parent = root
		if not tryCustomKit(char, form, kit) then
			if form == "Ichigo" then
				buildIchigo(char, kit)
			else
				buildMugetsu(char, kit)
			end
		end
	end
	root.Parent = char
	setKitTransparency(root.Ichigo, false)
	setKitTransparency(root.Mugetsu, true)
	root:SetAttribute("Form", "Ichigo")

	local original = {}
	for _, n in LIMBS do
		local p = char:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			original[n] = p.Color
		end
	end
	for n, c in original do
		(root :: Instance):SetAttribute("Skin_" .. n, c)
	end
	for _, n in LIMBS do
		local p = char:FindFirstChild(n) :: BasePart?
		if p then
			p.Color = SKIN.Ichigo
		end
	end
end

local function fadeKit(kit: Folder, toHidden: boolean, duration: number)
	for _, d in kit:GetDescendants() do
		if d:IsA("BasePart") then
			local target = toHidden and 1 or (d:GetAttribute("BaseTransparency") :: number? or 0)
			if duration <= 0 then
				d.Transparency = target
			else
				TweenService:Create(d, TweenInfo.new(duration, Enum.EasingStyle.Sine), { Transparency = target }):Play()
			end
		end
	end
end

function ModelKit.currentForm(char: Model): Form
	local root = char:FindFirstChild("MugetsuKits")
	return (root and root:GetAttribute("Form") or "Ichigo") :: Form
end

function ModelKit.setForm(char: Model, form: Form, fadeTime: number)
	local root = char:FindFirstChild("MugetsuKits") :: Folder?
	if not root then
		return
	end
	local other: Form = form == "Mugetsu" and "Ichigo" or "Mugetsu"
	fadeKit(root:FindFirstChild(other) :: Folder, true, fadeTime)
	fadeKit(root:FindFirstChild(form) :: Folder, false, fadeTime)
	root:SetAttribute("Form", form)
	for _, n in LIMBS do
		local p = char:FindFirstChild(n) :: BasePart?
		if p then
			p.Color = SKIN[form]
		end
	end
end

function ModelKit.getBlade(char: Model): BasePart?
	local root = char:FindFirstChild("MugetsuKits")
	local form = ModelKit.currentForm(char)
	local kit = root and root:FindFirstChild(form)
	local b = kit and kit:FindFirstChild("Blade")
	return b and b:IsA("BasePart") and b or nil
end

return ModelKit

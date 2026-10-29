--!strict
-- Kits visuais do personagem (Ichigo / Mugetsu) construídos sobre o rig R15 EXISTENTE.
-- Nada substitui o corpo: as peças são soldadas aos membros, então o rig, as juntas e as animações
-- continuam compatíveis. Trocar de forma = alternar Transparency dos kits + cores dos membros.
--
-- Os kits vêm de DADOS (fonte única, a mesma da prévia three.js):
--   * KitDataObj.json        <- tools/import_obj.py  (modelos assets/models/*.obj enviados pelo usuário)
--   * KitDataProcedural.json <- tools/build_kits.py  (kit procedural mais detalhado, feito a partir das imagens)
-- Config.Kit.Source escolhe qual usar.
--
-- Kit de MALHA (modelo esculpido): tools/import_mesh.py gera assets/models/ichigo_mesh/IchigoMesh.obj
-- (pedaços nomeados por membro + cubo "Root") e MeshKitManifest.json. Depois de importar o OBJ no Studio
-- e colocar o Model resultante em ServerStorage.MugetsuAssets.IchigoMesh, a forma do manifesto usa a malha
-- (com prioridade sobre os dados acima) e o corpo R15 fica oculto por baixo dela.
--
-- Ponto de integração para arte final: se existir ServerStorage.MugetsuAssets.MugetsuKit (Model) com peças
-- (ex.: MeshParts importados no Studio) que tenham Attribute "AttachTo" (membro R15), "Offset" (CFrame
-- relativo ao membro) e "Form" ("Ichigo" | "Mugetsu"), elas substituem os dados daquela forma.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Mugetsu")
local Manifest = require(Shared:WaitForChild("AssetManifest"))
local Config = require(Shared:WaitForChild("Config"))

export type Form = "Ichigo" | "Mugetsu"

local ModelKit = {}

local LIMBS = {
	"Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local rad = math.rad

local function kitData(): any
	local name = Config.Kit.Source == "Procedural" and "KitDataProcedural" or "KitDataObj"
	return require(Shared:WaitForChild(name) :: ModuleScript)
end

local function color(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function vec(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local function cf(pos: { number }, rot: { number }): CFrame
	return CFrame.new(pos[1], pos[2], pos[3]) * CFrame.Angles(rad(rot[1]), rad(rot[2]), rad(rot[3]))
end

local function material(name: string?): Enum.Material
	local ok, m = pcall(function()
		return (Enum.Material :: any)[name or "SmoothPlastic"]
	end)
	return ok and m or Enum.Material.SmoothPlastic
end

local function newPart(shape: string): BasePart
	local p: BasePart
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		elseif shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		end
		p = part
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function weld(p0: BasePart, p1: BasePart, c0: CFrame)
	local w = Instance.new("Weld")
	w.Part0 = p0
	w.Part1 = p1
	w.C0 = c0
	w.Parent = p1
end

local function skinForm(form: string): boolean
	local sk = Config.Skins
	return sk ~= nil and sk.Enabled == true and #(sk[form] or {}) > 0
end

local function buildFromData(char: Model, kit: Folder, def: any, swordOnly: boolean?)
	for _, d in def.parts do
		if swordOnly and d.attach ~= "RightHand" then
			continue -- forma com skin do catálogo: o kit só fornece a espada
		end
		local limb = char:FindFirstChild(d.attach)
		if limb and limb:IsA("BasePart") then
			local p = newPart(d.shape)
			p.Name = d.name
			p.Size = vec(d.size)
			p.Color = color(d.color)
			p.Material = material(d.material)
			p:SetAttribute("BaseTransparency", d.transparency or 0)
			for _, a in d.attachments or {} do
				local at = Instance.new("Attachment")
				at.Name = a.name
				at.Position = vec(a.pos)
				at.Parent = p
			end
			p.Parent = kit
			weld(limb, p, cf(d.pos, d.rot))
		end
	end
	-- mechas de cabelo: segmentos ligados por Motor6D (o cliente balança via Transform; tag MugetsuHair)
	for _, c in (swordOnly and {} or def.chains) do
		local head = char:FindFirstChild(c.attach)
		if head and head:IsA("BasePart") then
			local prev: BasePart = head
			local prevLen = 0
			for i, len in c.lengths do
				local last = i == #c.lengths
				local w = c.width * (1 - (i - 1) * 0.18)
				local seg = newPart(last and "Wedge" or "Block")
				seg.Name = `{c.name}_{i}`
				seg.Size = Vector3.new(w, len, c.depth)
				seg.Color = color(c.color)
				seg.Material = material(c.material)
				seg:SetAttribute("BaseTransparency", 0)
				seg.Parent = kit
				local m = Instance.new("Motor6D")
				m.Part0 = prev
				m.Part1 = seg
				m.C0 = i == 1 and cf(c.pos, c.rot) or CFrame.new(0, -prevLen / 2, 0) * CFrame.Angles(rad(c.bend), 0, 0)
				-- último segmento é uma cunha virada (ponta para baixo)
				m.C1 = CFrame.new(0, len / 2, 0) * (last and CFrame.Angles(0, 0, math.pi) or CFrame.identity)
				m:SetAttribute("Index", i)
				m:SetAttribute("Phase", #c.name * 0.7 + (i - 1))
				m.Parent = seg
				CollectionService:AddTag(m, "MugetsuHair")
				prev, prevLen = seg, len
			end
		end
	end
end

-- CFrame do membro em REPOUSO relativo ao HumanoidRootPart, pela cadeia de Motor6D (C0 * C1^-1),
-- ignorando a animação atual (Transform). Assim o encaixe não depende da pose no momento da montagem.
local function restCFrame(char: Model, part: BasePart, depth: number?): CFrame
	if part.Name == "HumanoidRootPart" or (depth or 0) > 12 then
		return CFrame.identity
	end
	for _, m in part:GetChildren() do
		if m:IsA("Motor6D") and m.Part1 == part and m.Part0 then
			return restCFrame(char, m.Part0, (depth or 0) + 1) * m.C0 * m.C1:Inverse()
		end
	end
	return CFrame.identity
end

local function meshManifest(): any?
	local m = Shared:FindFirstChild("MeshKitManifest")
	return m and require(m :: ModuleScript) or nil
end

local function meshSource(): Model?
	local man = meshManifest()
	if not (Config.Kit.UseMesh and man) then
		return nil
	end
	local folder = ServerStorage:FindFirstChild(Manifest.CustomKitPath[1])
	local model = folder and folder:FindFirstChild(man.modelName or "IchigoMesh")
	return model and model:IsA("Model") and model or nil
end

-- Monta a forma a partir do Model importado (MeshParts nomeados como no MeshKitManifest + "Root").
local function buildFromMesh(char: Model, kit: Folder, model: Model, man: any): boolean
	local root = model:FindFirstChild(man.rootName, true)
	if not (root and root:IsA("BasePart")) then
		warn(`[Mugetsu] {model.Name} sem o cubo 'Root'; usando o kit de peças`)
		return false
	end
	-- se o Studio importou em outra escala, o cubo Root (0.2 stud no arquivo) revela o fator
	local k = 0.2 / math.max(root.Size.X, 1e-3)
	local used = 0
	for name, info in man.pieces do
		local src = model:FindFirstChild(name, true)
		local limb = char:FindFirstChild(info.attach)
		if src and src:IsA("BasePart") and limb and limb:IsA("BasePart") then
			local p = src:Clone()
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.Size = p.Size * k
			p.Color = color(info.color)
			p.Material = material(info.material)
			p:SetAttribute("BaseTransparency", 0)
			for _, c in p:GetChildren() do
				if c:IsA("Attachment") then
					c:Destroy()
				end
			end
			for _, a in info.attachments or {} do
				local at = Instance.new("Attachment")
				at.Name = a.name
				at.Position = vec(a.pos)
				at.Parent = p
			end
			local rel = root.CFrame:ToObjectSpace(src.CFrame)
			rel = rel - rel.Position + rel.Position * k -- posição relativa ao HRP em repouso (studs do jogo)
			p.Parent = kit
			weld(limb, p, restCFrame(char, limb):Inverse() * rel)
			used += 1
		end
	end
	local head = char:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		for _, e in man.extras or {} do
			local p = newPart(e.shape)
			p.Name = e.name
			p.Size = vec(e.size)
			p.Color = color(e.color)
			p.Material = material(e.material)
			p:SetAttribute("BaseTransparency", 0)
			p.Parent = kit
			weld(head, p, restCFrame(char, head):Inverse() * CFrame.new(vec(e.worldPos)))
		end
	end
	kit:SetAttribute("ReplaceBody", man.replaceBody == true)
	print(`[Mugetsu] forma {man.form} montada a partir da malha importada ({used} pedaços)`)
	return used > 0
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

local function applyLimbColors(char: Model, form: Form)
	local def = kitData().forms[form]
	if not def or skinForm(form) then
		return -- a skin traz as próprias cores/roupas
	end
	for _, n in LIMBS do
		local p = char:FindFirstChild(n)
		local c = def.limbColors[n]
		if p and p:IsA("BasePart") and c then
			p.Color = color(c)
		end
	end
	-- as roupas do avatar (Shirt/Pants) cobririam as cores dos membros: ficam ocultas enquanto o kit existe
	for _, inst in char:GetChildren() do
		if inst:IsA("Shirt") or inst:IsA("Pants") or inst:IsA("ShirtGraphic") then
			inst.Parent = nil
		end
	end
	-- acessórios do avatar (cabelos, chapéus) atravessariam o cabelo/roupa do kit
	for _, acc in char:GetChildren() do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Transparency = 1
			end
		end
	end
	local head = char:FindFirstChild("Head")
	local face = head and head:FindFirstChildOfClass("Decal")
	if face and def.hideFace then
		face.Transparency = 1 -- o rosto vem do kit (olhos/sobrancelhas/máscara)
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
	local data = kitData()
	for _, form in { "Ichigo", "Mugetsu" } :: { Form } do
		local kit = Instance.new("Folder")
		kit.Name = form
		kit.Parent = root
		local man = meshManifest()
		local model = meshSource()
		local done = false
		if skinForm(form) then
			buildFromData(char, kit, data.forms[form], true)
			done = true
		elseif model and man and man.form == form then
			done = buildFromMesh(char, kit, model, man)
		end
		if not done and not tryCustomKit(char, form, kit) then
			buildFromData(char, kit, data.forms[form])
		end
	end
	root.Parent = char
	setKitTransparency(root.Ichigo, false)
	setKitTransparency(root.Mugetsu, true)
	root:SetAttribute("Form", "Ichigo")
	ModelKit.setForm(char, "Ichigo", 0)
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
	applyLimbColors(char, form)
	local kitFolder = root:FindFirstChild(form)
	local replace = kitFolder and kitFolder:GetAttribute("ReplaceBody") == true
	for _, n in LIMBS do
		local p = char:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			p.Transparency = replace and 1 or 0
		end
	end
end

-- Depois de um ApplyDescription (skin), membros podem ter sido trocados e as soldas perdidas:
-- remonta os kits mantendo a forma atual.
function ModelKit.refresh(char: Model)
	local old = char:FindFirstChild("MugetsuKits")
	local form = ModelKit.currentForm(char)
	if old then
		old:Destroy()
	end
	for _, n in { "AuraChest", "AuraFeet", "AuraHead", "AuraRArm", "AuraLArm", "AuraHand" } do
		local at = char:FindFirstChild(n, true)
		if at and at:IsA("Attachment") then
			at:Destroy()
		end
	end
	ModelKit.build(char)
	if form == "Mugetsu" then
		ModelKit.setForm(char, "Mugetsu", 0)
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

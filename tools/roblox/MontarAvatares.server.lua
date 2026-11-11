--!strict
-- MontarAvatares (Script em ServerScriptService)
-- Cria os bonecos R15 da cutscene a partir de itens do catálogo do Roblox.
--
-- Cole os IDs no bloco AVATARES abaixo. Aceita qualquer combinação de:
--   outfitId  -> um outfit/traje guardado (o ID que aparece no link do outfit)
--   userId    -> copia o avatar de um utilizador
--   bundleIds -> pacotes do catálogo (corpo, cabeça dinâmica, etc.)
--   assetIds  -> itens soltos (cabelo, camisa, calça, rosto, acessórios, roupa 3D...)
-- O tipo de cada asset é detetado sozinho; não precisa de dizer se é cabelo ou camisa.
--
-- Como usar:
--   1. Cole o script em ServerScriptService e preencha os IDs.
--   2. Carregue em Play. Os bonecos aparecem no Workspace.
--   3. Para os guardar no place: selecione-os no Workspace durante o Play, Ctrl+C,
--      pare o Play e faça Ctrl+V. Depois pode apagar ou desativar este script.
--
-- As animações exportadas do Blender funcionam em qualquer R15, por isso estes
-- bonecos podem ser usados diretamente no CutscenePlayer (rigs = { GOJO_RIG = workspace.GOJO_RIG, ... }).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local AssetService = game:GetService("AssetService")

type AvatarSpec = {
	nome: string,
	outfitId: number?,
	userId: number?,
	bundleIds: { number }?,
	assetIds: { number }?,
	corPele: Color3?,
	posicao: CFrame,
}

local AVATARES: { AvatarSpec } = {
	{
		nome = "GOJO_RIG",
		outfitId = nil,
		bundleIds = {},
		assetIds = {}, -- cole aqui: { 123456, 234567, ... }
		posicao = CFrame.new(0, 0, 1.9), -- olha para -Z (para o outro)
	},
	{
		nome = "SUKUNA_RIG",
		outfitId = nil,
		bundleIds = {},
		assetIds = {},
		posicao = CFrame.new(0, 0, -1.9) * CFrame.Angles(0, math.pi, 0),
	},
}

-- Nome do AssetType -> campo de texto do HumanoidDescription
local CAMPO: { [string]: string } = {
	Shirt = "Shirt",
	Pants = "Pants",
	TShirt = "GraphicTShirt",
	Face = "Face",
	Head = "Head",
	DynamicHead = "Head",
	Torso = "Torso",
	LeftArm = "LeftArm",
	RightArm = "RightArm",
	LeftLeg = "LeftLeg",
	RightLeg = "RightLeg",
}

-- Nome do AssetType -> Enum.AccessoryType (rígidos e roupa 3D/layered)
local ACESSORIO: { [string]: string } = {
	Hat = "Hat",
	HairAccessory = "Hair",
	FaceAccessory = "Face",
	NeckAccessory = "Neck",
	ShoulderAccessory = "Shoulder",
	FrontAccessory = "Front",
	BackAccessory = "Back",
	WaistAccessory = "Waist",
	EyebrowAccessory = "Eyebrow",
	EyelashAccessory = "Eyelash",
	TShirtAccessory = "TShirt",
	ShirtAccessory = "Shirt",
	PantsAccessory = "Pants",
	JacketAccessory = "Jacket",
	SweaterAccessory = "Sweater",
	ShortsAccessory = "Shorts",
	LeftShoeAccessory = "LeftShoe",
	RightShoeAccessory = "RightShoe",
	DressSkirtAccessory = "DressSkirt",
}
local LAYERED = {
	TShirt = true, Shirt = true, Pants = true, Jacket = true, Sweater = true,
	Shorts = true, LeftShoe = true, RightShoe = true, DressSkirt = true,
}

local NOME_DO_TIPO: { [number]: string } = {}
for _, item in Enum.AssetType:GetEnumItems() do
	NOME_DO_TIPO[item.Value] = item.Name
end

local function tipoDoAsset(id: number): string?
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.Asset)
	if not ok or not info then
		warn(`[MontarAvatares] não consegui ler o asset {id}: {info}`)
		return nil
	end
	return NOME_DO_TIPO[info.AssetTypeId]
end

local function assetsDoBundle(bundleId: number): { number }
	local ok, details = pcall(AssetService.GetBundleDetailsAsync, AssetService, bundleId)
	if not ok then
		warn(`[MontarAvatares] bundle {bundleId} falhou: {details}`)
		return {}
	end
	local ids = {}
	for _, item in details.Items do
		if item.Type == "Asset" then
			table.insert(ids, item.Id)
		end
	end
	return ids
end

local function descricaoBase(spec: AvatarSpec): HumanoidDescription
	if spec.outfitId then
		return Players:GetHumanoidDescriptionFromOutfitId(spec.outfitId)
	elseif spec.userId then
		return Players:GetHumanoidDescriptionFromUserId(spec.userId)
	end
	return Instance.new("HumanoidDescription")
end

local function montar(spec: AvatarSpec): Model?
	local desc = descricaoBase(spec)

	local ids: { number } = table.clone(spec.assetIds or {})
	for _, bundleId in spec.bundleIds or {} do
		for _, id in assetsDoBundle(bundleId) do
			table.insert(ids, id)
		end
	end

	local acessorios = desc:GetAccessories(true)
	for _, id in ids do
		local tipo = tipoDoAsset(id)
		if not tipo then
			continue
		end
		local campo = CAMPO[tipo]
		local tipoAcc = ACESSORIO[tipo]
		if campo then
			(desc :: any)[campo] = id
		elseif tipoAcc then
			table.insert(acessorios, {
				AssetId = id,
				AccessoryType = (Enum.AccessoryType :: any)[tipoAcc],
				IsLayered = LAYERED[tipoAcc] == true,
				Order = if LAYERED[tipoAcc] then #acessorios + 1 else nil,
			})
		else
			print(`[MontarAvatares] asset {id} ({tipo}) ignorado — não é peça de avatar`)
		end
	end
	desc:SetAccessories(acessorios, true)

	if spec.corPele then
		for _, parte in { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" } do
			(desc :: any)[parte] = spec.corPele
		end
	end

	local ok, modelo = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	if not ok then
		warn(`[MontarAvatares] {spec.nome}: {modelo}`)
		return nil
	end
	local model = modelo :: Model
	model.Name = spec.nome

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
	hrp.Anchored = true

	-- Pivot no chão entre os pés (o CutscenePlayer posiciona por aqui)
	local centro, tamanho = model:GetBoundingBox()
	local chaoY = centro.Position.Y - tamanho.Y / 2
	model.WorldPivot = CFrame.new(hrp.Position.X, chaoY, hrp.Position.Z) * hrp.CFrame.Rotation

	local origem = workspace:FindFirstChild("SceneOrigin")
	local base = if origem and origem:IsA("BasePart") then origem.CFrame else CFrame.identity
	model:PivotTo(base * spec.posicao)
	model.Parent = workspace
	print(`[MontarAvatares] {spec.nome} pronto ({#ids} itens)`)
	return model
end

for _, spec in AVATARES do
	task.spawn(montar, spec)
end

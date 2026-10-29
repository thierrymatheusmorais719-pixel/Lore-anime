--!strict
-- Skins por ID do catálogo do Roblox, só durante a cutscene/forma.
-- Config.Skins.Ichigo / .Mugetsu: listas de IDs (números) ou { bundle = ID }.
-- O tipo de cada ID é descoberto no servidor (MarketplaceService), então não importa se é cabelo,
-- cabeça dinâmica, máscara, roupa clássica ou em camadas: cada um vai para o campo certo do
-- HumanoidDescription. A aparência original do jogador é salva antes e restaurada depois.

local AssetService = game:GetService("AssetService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Mugetsu"):WaitForChild("Config"))

local SkinService = {}

-- nome do Enum.AssetType -> campo do HumanoidDescription (acessórios rígidos são listas "id,id")
local RIGID = {
	Hat = "HatAccessory", HairAccessory = "HairAccessory", FaceAccessory = "FaceAccessory",
	NeckAccessory = "NeckAccessory", ShoulderAccessory = "ShouldersAccessory", FrontAccessory = "FrontAccessory",
	BackAccessory = "BackAccessory", WaistAccessory = "WaistAccessory",
}
local SINGLE = {
	Shirt = "Shirt", Pants = "Pants", TShirt = "GraphicTShirt", Face = "Face", Head = "Head", DynamicHead = "Head",
	Torso = "Torso", LeftArm = "LeftArm", RightArm = "RightArm", LeftLeg = "LeftLeg", RightLeg = "RightLeg",
}
-- roupas em camadas e acessórios de rosto dinâmico -> Enum.AccessoryType
local LAYERED = {
	TShirtAccessory = "TShirt", ShirtAccessory = "Shirt", PantsAccessory = "Pants", JacketAccessory = "Jacket",
	SweaterAccessory = "Sweater", ShortsAccessory = "Shorts", LeftShoeAccessory = "LeftShoe",
	RightShoeAccessory = "RightShoe", DressSkirtAccessory = "DressSkirt", EyebrowAccessory = "Eyebrow",
	EyelashAccessory = "Eyelash",
}

local typeCache: { [number]: string } = {}

-- avisos na tela do jogador (o TransformationService conecta ao remote Notify)
SkinService.onError = function(_player: Player, _msg: string) end
local originals: { [Player]: HumanoidDescription } = {}

local function assetTypeName(id: number): string?
	if typeCache[id] then
		return typeCache[id]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset)
	end)
	if not ok or type(info) ~= "table" then
		warn(`[Mugetsu] não consegui ler o item {id} do catálogo: {info}`)
		return nil
	end
	for _, e in Enum.AssetType:GetEnumItems() do
		if e.Value == info.AssetTypeId then
			typeCache[id] = e.Name
			print(`[Mugetsu] item {id} = {e.Name} ("{info.Name}")`)
			return e.Name
		end
	end
	warn(`[Mugetsu] item {id}: tipo {info.AssetTypeId} desconhecido`)
	return nil
end

-- expande { bundle = ID } nos itens do pacote
local function expand(list: { any }): { number }
	local out = {}
	for _, entry in list do
		if type(entry) == "number" then
			table.insert(out, entry)
		elseif type(entry) == "table" and type(entry.bundle) == "number" then
			local ok, details = pcall(function()
				return AssetService:GetBundleDetailsAsync(entry.bundle)
			end)
			if ok and details then
				for _, item in details.Items do
					if item.Type == "Asset" then
						table.insert(out, item.Id)
					end
				end
			else
				warn(`[Mugetsu] não consegui ler o pacote {entry.bundle}: {details}`)
			end
		end
	end
	return out
end

local function skinList(form: string): { any }
	local s = Config.Skins
	return (s and s.Enabled and s[form]) or {}
end

function SkinService.hasSkin(form: string): boolean
	return #skinList(form) > 0
end

function SkinService.anyActive(): boolean
	return SkinService.hasSkin("Ichigo") or SkinService.hasSkin("Mugetsu")
end

-- Monta a descrição: parte da ORIGINAL do jogador e sobrescreve só o que a skin traz.
-- Se a skin tem qualquer acessório, os acessórios originais saem (não empilha cabelo sobre cabelo).
function SkinService.describe(base: HumanoidDescription, ids: { number }): HumanoidDescription
	local d = base:Clone()
	local rigid: { [string]: { string } } = {}
	local layered = {}
	local cleared = false
	local function clearAccessories()
		if cleared then
			return
		end
		cleared = true
		for _, field in RIGID do
			(d :: any)[field] = ""
		end
		d:SetAccessories({}, true)
	end
	for _, id in ids do
		local t = assetTypeName(id)
		if t and RIGID[t] then
			clearAccessories()
			rigid[RIGID[t]] = rigid[RIGID[t]] or {}
			table.insert(rigid[RIGID[t]], tostring(id))
		elseif t and SINGLE[t] then
			(d :: any)[SINGLE[t]] = id
		elseif t and LAYERED[t] then
			clearAccessories()
			table.insert(layered, { AssetId = id, AccessoryType = (Enum.AccessoryType :: any)[LAYERED[t]], IsLayered = true, Order = #layered + 1 })
		elseif t then
			warn(`[Mugetsu] item {id} ({t}) não é parte de aparência; ignorado`)
		end
	end
	for field, list in rigid do
		(d :: any)[field] = table.concat(list, ",")
	end
	if #layered > 0 then
		d:SetAccessories(layered, true)
	end
	return d
end

function SkinService.saveOriginal(player: Player)
	if originals[player] then
		return
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		local ok, d = pcall(function()
			return hum:GetAppliedDescription()
		end)
		if ok and d then
			originals[player] = d
		end
	end
end

-- Aplica a skin da forma. Bloqueia até o Roblox carregar os itens. Retorna true se aplicou.
function SkinService.apply(player: Player, form: string): boolean
	local list = skinList(form)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if #list == 0 or not hum then
		return false
	end
	SkinService.saveOriginal(player)
	local base = originals[player]
	if not base then
		return false
	end
	local ids = expand(list)
	print(`[Mugetsu] aplicando skin {form} em {player.Name}: {#ids} itens`)
	local desc = SkinService.describe(base, ids)
	local ok, err = pcall(function()
		hum:ApplyDescription(desc)
	end)
	if ok then
		print(`[Mugetsu] skin {form} aplicada`)
	else
		warn(`[Mugetsu] falha ao aplicar a skin {form}: {err}`)
		SkinService.onError(player, `Falha na skin {form}: {err}`)
	end
	return ok
end

-- Volta a aparência original (se ela foi salva). Bloqueia.
function SkinService.restore(player: Player): boolean
	local d = originals[player]
	originals[player] = nil
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (d and hum and hum.Health > 0) then
		return false
	end
	local ok, err = pcall(function()
		hum:ApplyDescription(d)
	end)
	if not ok then
		warn(`[Mugetsu] falha ao restaurar a aparência: {err}`)
	end
	return ok
end

function SkinService.hasSaved(player: Player): boolean
	return originals[player] ~= nil
end

-- personagem novo = aparência do perfil de novo: esquece o que estava salvo
function SkinService.forget(player: Player)
	originals[player] = nil
end

Players.PlayerRemoving:Connect(function(p)
	originals[p] = nil
end)

return SkinService

-- Inventário, equipamentos, consumíveis, loja, forja e distribuição de drops.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local Loot = require(Shared.Config.Loot)
local InventoryLogic = require(Shared.Logic.InventoryLogic)
local LootLogic = require(Shared.Logic.LootLogic)

local Registry = require(script.Parent.Parent.Registry)

local InventoryService = {}

local rng = Random.new()
local rngAdapter = {
	int = function(a: number, b: number)
		return rng:NextInteger(a, b)
	end,
	float = function()
		return rng:NextNumber()
	end,
}

function InventoryService.Give(player: Player, itemId: string, qty: number): number
	local profile = Registry.DataService.Get(player)
	if not profile then
		return 0
	end
	local added = InventoryLogic.add(profile.inventory, Items.List, itemId, qty)
	if added < qty then
		Registry.UIService.Notify(player, "Inventário cheio!", "warn")
	end
	Registry.DataService.Sync(player)
	return added
end

-- Rola a tabela de drop para um jogador (cada participante rola separadamente).
function InventoryService.GrantLoot(player: Player, tableId: string)
	local profile = Registry.DataService.Get(player)
	local def = Loot[tableId]
	if not profile or not def then
		return
	end
	local drops, kan, shards = LootLogic.roll(def, profile.lootPity, tableId, rngAdapter)
	for _, drop in drops do
		local added = InventoryLogic.add(profile.inventory, Items.List, drop.id, drop.qty)
		if added > 0 then
			local item = Items.List[drop.id]
			Registry.UIService.Notify(player, "+" .. added .. " " .. item.name, "loot", { item = drop.id, rarity = item.rarity })
		end
	end
	Registry.ProgressionService.AddCurrency(player, kan, shards)
	if kan > 0 then
		Registry.UIService.Notify(player, "+" .. kan .. " Kan", "kan")
	end
	if shards > 0 then
		Registry.UIService.Notify(player, "+" .. shards .. " Fragmentos Espirituais", "loot", { rarity = "Epic" })
	end
	Registry.DataService.Sync(player)
end

local function equip(player: Player, payload: any): (boolean, any)
	local profile = Registry.DataService.Get(player)
	local uid = type(payload) == "table" and tonumber(payload.uid)
	if not profile or not uid then
		return false, "Pedido inválido"
	end
	local ok, err = InventoryLogic.equip(profile, Items.List, uid)
	if ok then
		Registry.CharacterService.RefreshStats(player)
		local actor = Registry.CombatService.GetByPlayer(player)
		if actor then
			Registry.CharacterService.RefreshAppearance(actor)
		end
		Registry.DataService.Sync(player)
	end
	return ok, err
end

function InventoryService.UseItem(player: Player, itemId: string): (boolean, any)
	local profile = Registry.DataService.Get(player)
	local def = Items.get(itemId)
	local actor = Registry.CombatService.GetByPlayer(player)
	if not profile or not def or def.kind ~= "Consumable" or not actor then
		return false, "Item inválido"
	end
	if not Registry.CombatService.IsAlive(actor) then
		return false, "Você está fora de combate"
	end
	local key = "Item:" .. itemId
	if not Registry.CombatService.CooldownReady(actor, key) then
		return false, "Aguarde a recarga"
	end
	if not InventoryLogic.remove(profile.inventory, itemId, 1) then
		return false, "Você não tem " .. def.name
	end
	if def.use.heal then
		Registry.CombatService.Heal(actor, actor.humanoid.MaxHealth * def.use.heal)
	end
	if def.use.reiatsu then
		Registry.CombatService.AddReiatsu(actor, actor.derived.maxReiatsu * def.use.reiatsu)
	end
	Registry.CombatService.SetCooldown(actor, key, def.cooldown or 10)
	Registry.CombatService.Broadcast("UseItem", { actor = actor.model, item = itemId }, actor.root.Position)
	Registry.DataService.Sync(player)
	return true, nil
end

local function useItem(player: Player, payload: any): (boolean, any)
	local itemId = type(payload) == "table" and payload.item
	if type(itemId) ~= "string" then
		return false, "Pedido inválido"
	end
	return InventoryService.UseItem(player, itemId)
end

local function craft(player: Player, payload: any): (boolean, any)
	local profile = Registry.DataService.Get(player)
	local itemId = type(payload) == "table" and payload.item
	if not profile or type(itemId) ~= "string" then
		return false, "Pedido inválido"
	end
	local ok, err = InventoryLogic.craft(profile, Items.List, Items.Recipes, itemId)
	if ok then
		Registry.UIService.Notify(player, "Forjado: " .. Items.List[itemId].name, "loot", { item = itemId, rarity = Items.List[itemId].rarity })
		Registry.DataService.Sync(player)
	end
	return ok, err
end

local function buy(player: Player, payload: any): (boolean, any)
	local profile = Registry.DataService.Get(player)
	local itemId = type(payload) == "table" and payload.item
	local qty = type(payload) == "table" and math.clamp(math.floor(tonumber(payload.qty) or 1), 1, 20) or 1
	if not profile or type(itemId) ~= "string" or not table.find(Items.Shop, itemId) then
		return false, "Item não vendido aqui"
	end
	local def = Items.List[itemId]
	local cost = def.price * qty
	if profile.currency.Kan < cost then
		return false, "Kan insuficiente"
	end
	local added = InventoryLogic.add(profile.inventory, Items.List, itemId, qty)
	if added <= 0 then
		return false, "Inventário cheio"
	end
	profile.currency.Kan -= def.price * added
	Registry.DataService.Sync(player)
	return true, nil
end

local function sell(player: Player, payload: any): (boolean, any)
	local profile = Registry.DataService.Get(player)
	local uid = type(payload) == "table" and tonumber(payload.uid)
	if not profile or not uid then
		return false, "Pedido inválido"
	end
	for _, equippedUid in profile.equipped do
		if equippedUid == uid then
			return false, "Desequipe antes de vender"
		end
	end
	local entry = InventoryLogic.find(profile.inventory, uid)
	if not entry then
		return false, "Item não encontrado"
	end
	local def = Items.List[entry.id]
	local qty = math.clamp(math.floor(tonumber(payload.qty) or entry.qty), 1, entry.qty)
	local value = (def and def.sell or 1) * qty
	entry.qty -= qty
	if entry.qty <= 0 then
		InventoryLogic.removeUid(profile.inventory, uid)
	end
	profile.currency.Kan += value
	Registry.DataService.Sync(player)
	return true, { kan = value }
end

function InventoryService.Init()
	local UI = Registry.UIService
	UI.Register("Equip", equip)
	UI.Register("UseItem", useItem)
	UI.Register("Craft", craft)
	UI.Register("Buy", buy)
	UI.Register("Sell", sell)
end

function InventoryService.Start() end

return InventoryService

--!strict
-- Inventário puro: empilháveis (materiais/consumíveis) e equipamentos únicos.
local InventoryLogic = {}

InventoryLogic.MaxEntries = 120

local function isStackable(def: any): boolean
	return def.kind == "Material" or def.kind == "Consumable"
end

function InventoryLogic.count(inventory: any, itemId: string): number
	local total = 0
	for _, entry in inventory.items do
		if entry.id == itemId then
			total += entry.qty
		end
	end
	return total
end

function InventoryLogic.find(inventory: any, uid: number): any?
	for _, entry in inventory.items do
		if entry.uid == uid then
			return entry
		end
	end
	return nil
end

-- Retorna quantas unidades foram realmente adicionadas.
function InventoryLogic.add(inventory: any, items: any, itemId: string, qty: number): number
	local def = items[itemId]
	if not def or qty <= 0 then
		return 0
	end
	if isStackable(def) then
		local stack = def.stack or 999
		for _, entry in inventory.items do
			if entry.id == itemId then
				local before = entry.qty
				entry.qty = math.min(stack, entry.qty + qty)
				return entry.qty - before
			end
		end
		if #inventory.items >= InventoryLogic.MaxEntries then
			return 0
		end
		local amount = math.min(stack, qty)
		table.insert(inventory.items, { uid = inventory.nextUid, id = itemId, qty = amount })
		inventory.nextUid += 1
		return amount
	end
	local added = 0
	for _ = 1, qty do
		if #inventory.items >= InventoryLogic.MaxEntries then
			break
		end
		table.insert(inventory.items, { uid = inventory.nextUid, id = itemId, qty = 1 })
		inventory.nextUid += 1
		added += 1
	end
	return added
end

function InventoryLogic.remove(inventory: any, itemId: string, qty: number): boolean
	if InventoryLogic.count(inventory, itemId) < qty then
		return false
	end
	local remaining = qty
	for i = #inventory.items, 1, -1 do
		local entry = inventory.items[i]
		if entry.id == itemId and remaining > 0 then
			local take = math.min(entry.qty, remaining)
			entry.qty -= take
			remaining -= take
			if entry.qty <= 0 then
				table.remove(inventory.items, i)
			end
		end
	end
	return true
end

function InventoryLogic.removeUid(inventory: any, uid: number): any?
	for i, entry in inventory.items do
		if entry.uid == uid then
			table.remove(inventory.items, i)
			return entry
		end
	end
	return nil
end

-- Equipa por uid; valida slot pelo tipo do item.
function InventoryLogic.equip(profile: any, items: any, uid: number): (boolean, string?)
	local entry = InventoryLogic.find(profile.inventory, uid)
	if not entry then
		return false, "Item não encontrado"
	end
	local def = items[entry.id]
	if not def or (def.kind ~= "Weapon" and def.kind ~= "Accessory") then
		return false, "Item não equipável"
	end
	if profile.equipped[def.kind] == uid then
		profile.equipped[def.kind] = nil
		return true, nil
	end
	profile.equipped[def.kind] = uid
	return true, nil
end

-- Forja determinística.
function InventoryLogic.craft(profile: any, items: any, recipes: any, itemId: string): (boolean, string?)
	local recipe = recipes[itemId]
	if not recipe then
		return false, "Receita inexistente"
	end
	if profile.level < recipe.level then
		return false, "Requer nível " .. recipe.level
	end
	if profile.currency.Kan < recipe.kan then
		return false, "Kan insuficiente"
	end
	for materialId, qty in recipe.materials do
		if InventoryLogic.count(profile.inventory, materialId) < qty then
			local def = items[materialId]
			return false, "Faltam materiais: " .. (def and def.name or materialId)
		end
	end
	if #profile.inventory.items >= InventoryLogic.MaxEntries then
		return false, "Inventário cheio"
	end
	profile.currency.Kan -= recipe.kan
	for materialId, qty in recipe.materials do
		InventoryLogic.remove(profile.inventory, materialId, qty)
	end
	InventoryLogic.add(profile.inventory, items, itemId, 1)
	return true, nil
end

return InventoryLogic

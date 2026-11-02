-- Operações puras de inventário sobre o perfil. O servidor é o único que as executa.

local Pets = require(script.Parent.Parent.Config.Pets)
local Items = require(script.Parent.Parent.Config.Items)
local LuckConfig = require(script.Parent.Parent.Config.Luck)
local DataSchema = require(script.Parent.DataSchema)

local InventoryLogic = {}

local CURRENCIES = { coins = true, essence = true, astral = true }
InventoryLogic.Currencies = CURRENCIES

function InventoryLogic.isCurrency(id: string): boolean
	return CURRENCIES[id] == true
end

function InventoryLogic.count(data, id: string): number
	if CURRENCIES[id] then
		return data[id] or 0
	end
	return data.items[id] or 0
end

-- Adiciona moeda ou item. Retorna false se o id não existir.
function InventoryLogic.add(data, id: string, amount: number): boolean
	if amount <= 0 or amount ~= amount then
		return false
	end
	amount = math.floor(amount)
	if CURRENCIES[id] then
		data[id] = (data[id] or 0) + amount
		if id == "coins" then
			data.stats.coinsEarned += amount
		end
		return true
	end
	if not Items.Info[id] then
		return false
	end
	data.items[id] = (data.items[id] or 0) + amount
	return true
end

-- Verifica se pode pagar um custo { coins, essence, astral, items = {id = n} }.
function InventoryLogic.canAfford(data, cost): (boolean, string?)
	for _, c in ipairs({ "coins", "essence", "astral" }) do
		if (cost[c] or 0) > (data[c] or 0) then
			return false, "Faltam " .. Items.label(c)
		end
	end
	if cost.items then
		for id, n in pairs(cost.items) do
			if (data.items[id] or 0) < n then
				return false, "Faltam " .. Items.label(id)
			end
		end
	end
	return true, nil
end

-- Debita um custo. Só chame depois de canAfford (verifica de novo por segurança).
function InventoryLogic.spend(data, cost): boolean
	if not InventoryLogic.canAfford(data, cost) then
		return false
	end
	for _, c in ipairs({ "coins", "essence", "astral" }) do
		data[c] -= (cost[c] or 0)
	end
	if cost.items then
		for id, n in pairs(cost.items) do
			data.items[id] -= n
			if data.items[id] <= 0 then
				data.items[id] = nil
			end
		end
	end
	return true
end

function InventoryLogic.petCount(data): number
	local n = 0
	for _ in pairs(data.pets) do
		n += 1
	end
	return n
end

-- Cria um pet novo no inventário. Retorna o registro (ou nil se o inventário estiver cheio).
function InventoryLogic.addPet(data, species: string, mutation: string?, now: number, origin: string?)
	if not Pets.Species[species] then
		return nil
	end
	if InventoryLogic.petCount(data) >= DataSchema.MaxPets then
		return nil
	end
	local uid = tostring(data.nextUid)
	data.nextUid += 1
	local pet = {
		uid = uid, species = species, tier = 1, level = 1, xp = 0, mutation = mutation,
		abilityRank = 1, accessory = nil, locked = false, hatchedAt = now, origin = origin or "egg",
	}
	data.pets[uid] = pet
	InventoryLogic.registerPet(data, species, mutation, now)
	return pet
end

-- Registra no bestiário (espécie + mutação). Retorna (novaEspecie, novaMutacao).
function InventoryLogic.registerPet(data, species: string, mutation: string?, now: number): (boolean, boolean)
	local entry = data.bestiary.pets[species]
	local newSpecies = false
	if not entry then
		entry = { n = 0, first = now, muts = {} }
		data.bestiary.pets[species] = entry
		newSpecies = true
	end
	entry.n += 1
	local newMut = false
	if mutation and not entry.muts[mutation] then
		entry.muts[mutation] = now
		newMut = true
	end
	return newSpecies, newMut
end

function InventoryLogic.registerFoe(data, kind: string, id: string, now: number): boolean
	local book = kind == "boss" and data.bestiary.bosses or data.bestiary.enemies
	local entry = book[id]
	if not entry then
		book[id] = { n = 1, first = now }
		return true
	end
	entry.n += 1
	return false
end

function InventoryLogic.removePet(data, uid: string): boolean
	local pet = data.pets[uid]
	if not pet or pet.locked then
		return false
	end
	data.pets[uid] = nil
	for i = #data.team, 1, -1 do
		if data.team[i] == uid then
			table.remove(data.team, i)
		end
	end
	return true
end

-- Histórico de descobertas importantes (limitado).
function InventoryLogic.pushHistory(data, entry)
	table.insert(data.history, 1, entry)
	while #data.history > LuckConfig.HistorySize do
		table.remove(data.history)
	end
end

return InventoryLogic

-- Concessão de recompensas: drops (com sorte do servidor), pacotes de missão/coleção,
-- histórico de descobertas e anúncios.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Drops = require(Shared.Config.Drops)
local Pets = require(Shared.Config.Pets)
local Items = require(Shared.Config.Items)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local DropLogic = require(Shared.Logic.DropLogic)
local HatchLogic = require(Shared.Logic.HatchLogic)
local InventoryLogic = require(Shared.Logic.InventoryLogic)
local Net = require(Shared.Net)

local RewardService = {}

local S
local Push
local rng = Random.new()

function RewardService.init(registry)
	S = registry
	Push = Net.get("Push")
end

function RewardService.random(): number
	return rng:NextNumber()
end

-- Registra uma descoberta importante no histórico e anuncia se a raridade pedir.
function RewardService.discovery(player: Player, entry)
	local data = S.DataService.get(player)
	if not data then
		return
	end
	entry.t = os.time()
	InventoryLogic.pushHistory(data, entry)
	local rarity = entry.rarity and Rarities.Info[entry.rarity]
	local scope = rarity and rarity.announce or "none"
	if entry.mutation and scope == "none" and (entry.rarity and Rarities.rank(entry.rarity) >= 4) then
		scope = "server" -- mutação em pet Épico+ é anunciada no servidor
	end
	if scope ~= "none" then
		S.AnnounceService.announce({
			id = entry.id, player = player.DisplayName, text = entry.text, rarity = entry.rarity, mutation = entry.mutation,
			kind = entry.kind, scope = scope,
		})
	end
	S.DataService.markDirty(player)
end

-- Cria um pet de recompensa/drop e registra a descoberta.
function RewardService.givePet(player: Player, species: string, mutation: string?, origin: string, chance: number?)
	local data = S.DataService.get(player)
	local sp = Pets.Species[species]
	if not data or not sp then
		return nil
	end
	local pet = InventoryLogic.addPet(data, species, mutation, os.time(), origin)
	if not pet then
		Push:FireClient(player, "Toast", { text = "Inventário de pets cheio! Libere espaço.", kind = "error" })
		return nil
	end
	if mutation then
		S.QuestService.event(player, { type = "discover_mutation", target = mutation })
	end
	S.QuestService.checkCollection(player)
	if Rarities.isNotable(sp.rarity) or mutation then
		RewardService.discovery(player, {
			id = S.AnnounceService.newId(), kind = "pet", species = species, rarity = sp.rarity, mutation = mutation, chance = chance,
			text = string.format("%s%s (%s)", mutation and (mutation .. " ") or "", sp.name, Rarities.Info[sp.rarity].label),
		})
	end
	return pet
end

-- Aplica um resultado de rolagem ao inventário.
local function applyResult(player: Player, data, r, label: string)
	local species = r.item:match("^pet:(.+)$")
	if species then
		local mutation = nil
		if r.mutation == "roll" then
			mutation = HatchLogic.rollMutation(Pets.Species[species].world, S.LuckService.mult(player, "Mutation"), RewardService.random)
		elseif r.mutation and Mutations.Info[r.mutation] then
			mutation = r.mutation
		end
		local pet = RewardService.givePet(player, species, mutation, "drop:" .. label, r.p)
		return pet ~= nil
	end
	local ok = InventoryLogic.add(data, r.item, r.amount)
	if ok and r.notable then
		RewardService.discovery(player, {
			id = S.AnnounceService.newId(), kind = "item", item = r.item, chance = r.p,
			text = string.format("%s x%d de %s", Items.label(r.item), r.amount, label),
		})
	end
	return ok
end

-- Rola uma tabela de drops para UM jogador, com a sorte DELE (calculada aqui no servidor).
-- tbl: lista de entradas ou id em Drops.Tables
function RewardService.rollDrops(player: Player, tbl, label: string, opts)
	local data = S.DataService.get(player)
	if not data then
		return {}
	end
	if type(tbl) == "string" then
		tbl = Drops.Tables[tbl]
	end
	if not tbl then
		return {}
	end
	local mults = S.LuckService.mults(player)
	local results = DropLogic.roll(tbl, mults, RewardService.random, opts)
	local granted = {}
	for _, r in ipairs(results) do
		if applyResult(player, data, r, label) then
			table.insert(granted, { item = r.item, amount = r.amount, notable = r.notable })
		end
	end
	S.DataService.markDirty(player)
	if #granted > 0 then
		Push:FireClient(player, "Drop", { source = label, items = granted })
	end
	return granted
end

-- Pacote fixo (missões, coleção, login). reward = { coins, essence, astral, items, luck }
function RewardService.grantBundle(player: Player, reward, label: string, id: string?)
	local data = S.DataService.get(player)
	if not data or not reward then
		return
	end
	local granted = {}
	for _, c in ipairs({ "coins", "essence", "astral" }) do
		if reward[c] and reward[c] > 0 then
			InventoryLogic.add(data, c, reward[c])
			table.insert(granted, { item = c, amount = reward[c] })
		end
	end
	if reward.items then
		for item, n in pairs(reward.items) do
			if InventoryLogic.add(data, item, n) then
				table.insert(granted, { item = item, amount = n })
			end
		end
	end
	if reward.luck then
		S.LuckService.addQuestBuff(player, id or label, label, reward.luck)
		table.insert(granted, { item = "luck", amount = reward.luck.bonus, duration = reward.luck.duration, category = reward.luck.category })
	end
	S.DataService.markDirty(player)
	Push:FireClient(player, "Drop", { source = label, items = granted })
end

-- Moedas com bônus de pets (perk "coins").
function RewardService.addCoins(player: Player, amount: number)
	local data = S.DataService.get(player)
	if not data then
		return 0
	end
	local bonus = S.PetService.coinBonus(player)
	local total = math.floor(amount * (1 + bonus))
	InventoryLogic.add(data, "coins", total)
	S.QuestService.event(player, { type = "earn_coins", amount = total })
	S.DataService.markDirty(player)
	return total
end

function RewardService.start() end

return RewardService

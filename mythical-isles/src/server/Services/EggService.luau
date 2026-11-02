-- Chocar ovos. As probabilidades exibidas (EggOdds) e as usadas (Hatch) saem da MESMA função
-- (HatchLogic.eggOdds) com o MESMO multiplicador de sorte calculado no servidor.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local HatchLogic = require(Shared.Logic.HatchLogic)
local InventoryLogic = require(Shared.Logic.InventoryLogic)
local DataSchema = require(Shared.Logic.DataSchema)
local RateLimiter = require(Shared.Util.RateLimiter)

local EggService = {}

local S
local limiter = RateLimiter.new(6, 3, 0.4)
local STATION_RANGE = 22

function EggService.init(registry)
	S = registry
end

-- Jogador está perto de alguma estação (do ovo pedido, ou qualquer uma para ovos especiais)?
local function nearStation(player: Player, eggId: string?): boolean
	local root = S.CombatService.charRoot(player)
	if not root then
		return false
	end
	for _, layout in pairs(S.WorldService.Layout) do
		for id, model in pairs(layout.eggStations) do
			if eggId == nil or id == eggId then
				if (model:GetPivot().Position - root.Position).Magnitude <= STATION_RANGE then
					return true
				end
			end
		end
	end
	return false
end

function EggService.odds(player: Player, eggId: string)
	local data = S.DataService.get(player)
	local egg = Eggs.Info[eggId]
	if not data or not egg then
		return { ok = false }
	end
	local mults, sources = S.LuckService.mults(player)
	local probs = HatchLogic.eggOdds(eggId, data, mults.PetVariant)
	local mutOdds, mutChance = HatchLogic.mutationOdds(egg.world, mults.Mutation)
	local active = {}
	for _, s in ipairs(sources) do
		if s.category == "All" or s.category == "PetVariant" or s.category == "Mutation" then
			table.insert(active, { label = s.label, type = s.type, category = s.category, bonus = s.bonus, expires = s.expires })
		end
	end
	return {
		ok = true, egg = eggId, name = egg.name, currency = egg.currency, cost = egg.cost, special = egg.special == true,
		owned = egg.special and InventoryLogic.count(data, eggId) or nil,
		entries = probs, mutation = { chance = mutChance, odds = mutOdds, max = Mutations.MaxChance },
		mult = mults.PetVariant, mutMult = mults.Mutation, sources = active,
	}
end

local function hatchOne(player: Player, data, eggId: string, mults)
	local egg = Eggs.Info[eggId]
	local species, mutation, p = HatchLogic.roll(eggId, data, mults, S.RewardService.random)
	local sp = Pets.Species[species]
	local newSpecies = data.bestiary.pets[species] == nil
	local pet = InventoryLogic.addPet(data, species, mutation, os.time(), "egg:" .. eggId)
	if not pet then
		return nil
	end
	data.stats.hatched += 1
	local rarity = Rarities.Info[sp.rarity]
	local result = {
		uid = pet.uid, species = species, name = sp.name, rarity = sp.rarity, mutation = mutation, chance = p,
		newSpecies = newSpecies, special = rarity.rank >= Rarities.Info.Secret.rank,
	}
	if Rarities.isNotable(sp.rarity) or mutation then
		S.RewardService.discovery(player, {
			id = S.AnnounceService.newId(), kind = "pet", species = species, rarity = sp.rarity, mutation = mutation, chance = p,
			text = string.format("%s%s (%s) do %s", mutation and (mutation .. " ") or "", sp.name, rarity.label, egg.name),
		})
	end
	if mutation then
		S.QuestService.event(player, { type = "discover_mutation", target = mutation })
	end
	return result
end

function EggService.hatch(player: Player, eggId: string, count: number?)
	if not limiter:allow(player) then
		return { ok = false, msg = "Devagar!" }
	end
	local data = S.DataService.get(player)
	local egg = Eggs.Info[eggId]
	if not data or not egg or egg.special then
		return { ok = false, msg = "Ovo inválido" }
	end
	count = (count == 3) and 3 or 1
	if not data.worlds[egg.world] then
		return { ok = false, msg = "Mundo bloqueado" }
	end
	if not nearStation(player, eggId) then
		return { ok = false, msg = "Vá até a estação do ovo" }
	end
	if InventoryLogic.petCount(data) + count > DataSchema.MaxPets then
		return { ok = false, msg = "Inventário de pets cheio" }
	end
	local cost = { [egg.currency] = egg.cost * count }
	local afford, missing = InventoryLogic.canAfford(data, cost)
	if not afford then
		return { ok = false, msg = missing }
	end
	InventoryLogic.spend(data, cost)
	local mults = S.LuckService.mults(player)
	local results = {}
	for _ = 1, count do
		local r = hatchOne(player, data, eggId, mults)
		if r then
			table.insert(results, r)
		end
	end
	S.QuestService.event(player, { type = "hatch", amount = #results })
	S.QuestService.checkCollection(player)
	-- primeiro pet: já entra na equipe
	if #data.team < 1 and results[1] then
		S.PetService.setTeam(player, { results[1].uid })
	end
	S.DataService.markDirty(player)
	return { ok = true, results = results, egg = eggId }
end

-- Ovo especial do inventário (obtido explorando/derrotando bosses).
function EggService.hatchItem(player: Player, eggId: string)
	if not limiter:allow(player) then
		return { ok = false, msg = "Devagar!" }
	end
	local data = S.DataService.get(player)
	local egg = Eggs.Info[eggId]
	if not data or not egg or not egg.special then
		return { ok = false, msg = "Ovo inválido" }
	end
	if InventoryLogic.count(data, eggId) < 1 then
		return { ok = false, msg = "Você não tem esse ovo" }
	end
	if not nearStation(player, nil) then
		return { ok = false, msg = "Leve o ovo até uma estação de ovos" }
	end
	if InventoryLogic.petCount(data) >= DataSchema.MaxPets then
		return { ok = false, msg = "Inventário de pets cheio" }
	end
	InventoryLogic.spend(data, { items = { [eggId] = 1 } })
	local r = hatchOne(player, data, eggId, S.LuckService.mults(player))
	S.QuestService.event(player, { type = "hatch", amount = 1 })
	S.QuestService.checkCollection(player)
	S.DataService.markDirty(player)
	return { ok = true, results = { r }, egg = eggId }
end

function EggService.start() end

return EggService

-- Atributos de combate, experiência e evolução dos pets (regras puras).

local Pets = require(script.Parent.Parent.Config.Pets)
local Rarities = require(script.Parent.Parent.Config.Rarities)
local Worlds = require(script.Parent.Parent.Config.Worlds)
local Combat = require(script.Parent.Parent.Config.Combat)
local Mutations = require(script.Parent.Parent.Config.Mutations)
local Abilities = require(script.Parent.Parent.Config.Abilities)

local PetStats = {}

-- pet = { species, tier, level, mutation, abilityRank }
function PetStats.compute(pet)
	local sp = Pets.Species[pet.species]
	local role = Combat.Roles[sp.role]
	local rarity = Rarities.Info[sp.rarity]
	local world = Worlds.Info[sp.world]
	local tier = Combat.Tiers[pet.tier or 1]
	local lvl = pet.level or 1
	local mut = pet.mutation and Mutations.Info[pet.mutation]
	local mult = rarity.statMult * world.statMult * tier.mult * (1 + Combat.LevelStatGrowth * (lvl - 1)) * (1 + (mut and mut.statBonus or 0))
	return {
		hp = math.floor(role.hp * mult),
		atk = math.floor(role.atk * mult * 10) / 10,
		def = math.floor(role.def * mult * 10) / 10,
		aspd = role.aspd,
		range = role.range,
		energy = role.energy,
		regen = role.regen,
		crit = role.crit,
		threat = role.threat,
		role = sp.role,
		ability = sp.ability,
		abilityRank = pet.abilityRank or 1,
		power = mult, -- usado para ordenar no inventário
	}
end

-- Recarga e efeito da habilidade considerando o rank e redução de recarga (sinergias).
function PetStats.abilityValues(abilityId: string, rank: number, cdr: number?)
	local a = Abilities.Info[abilityId]
	local r = math.clamp(rank or 1, 1, Abilities.MaxRank)
	local effect = 1 + Abilities.RankBonus * (r - 1)
	local cooldown = a.cooldown * (1 - Abilities.RankCdr * (r - 1)) * (1 - (cdr or 0))
	return effect, math.max(cooldown, 0.5)
end

function PetStats.levelCap(pet): number
	return Combat.Tiers[pet.tier or 1].levelCap
end

-- Adiciona XP e devolve quantos níveis subiu. Respeita o limite do estágio.
function PetStats.addXp(pet, amount: number): number
	local cap = PetStats.levelCap(pet)
	if (pet.level or 1) >= cap then
		pet.xp = 0
		return 0
	end
	pet.xp = (pet.xp or 0) + math.max(0, math.floor(amount))
	local ups = 0
	while pet.level < cap do
		local need = Combat.xpToNext(pet.level)
		if pet.xp < need then
			break
		end
		pet.xp -= need
		pet.level += 1
		ups += 1
	end
	if pet.level >= cap then
		pet.xp = 0
	end
	return ups
end

-- Custo de evolução do estágio atual para o próximo (nil = já está no máximo).
function PetStats.evolutionCost(pet)
	local nextTier = Combat.Tiers[(pet.tier or 1) + 1]
	if not nextTier then
		return nil
	end
	local sp = Pets.Species[pet.species]
	local w = Worlds.Info[sp.world].index
	local scale = 1 + Combat.EvolutionWorldCostScale * (w - 1)
	local items = {}
	for id, n in pairs(nextTier.cost.items) do
		items[id] = math.ceil(n * scale)
	end
	return { coins = math.floor(nextTier.cost.coins * scale), essence = math.floor(nextTier.cost.essence * scale), items = items }
end

-- Pode evoluir? Exige nível máximo do estágio atual.
function PetStats.canEvolve(pet): (boolean, string?)
	if not Combat.Tiers[(pet.tier or 1) + 1] then
		return false, "Estágio máximo"
	end
	if (pet.level or 1) < PetStats.levelCap(pet) then
		return false, string.format("Requer nível %d", PetStats.levelCap(pet))
	end
	return true, nil
end

-- Sinergias ativas para uma lista de funções (strings).
function PetStats.synergies(roles: { string })
	local counts, distinct = {}, 0
	for _, r in ipairs(roles) do
		if not counts[r] then
			distinct += 1
		end
		counts[r] = (counts[r] or 0) + 1
	end
	local active = {}
	local effects = { atk = 0, def = 0, hp = 0, cdr = 0, luckTreasure = 0 }
	for _, syn in ipairs(Combat.Synergies) do
		local ok = true
		if syn.need then
			for role, n in pairs(syn.need) do
				if (counts[role] or 0) < n then
					ok = false
				end
			end
		end
		if syn.needDistinct and distinct < syn.needDistinct then
			ok = false
		end
		if ok then
			table.insert(active, syn)
			for k, v in pairs(syn.effects) do
				effects[k] = (effects[k] or 0) + v
			end
		end
	end
	return active, effects
end

-- Mundos com conjunto ativo (3+ pets do mesmo mundo na equipe).
function PetStats.worldSets(speciesList: { string })
	local counts = {}
	for _, s in ipairs(speciesList) do
		local sp = Pets.Species[s]
		if sp then
			counts[sp.world] = (counts[sp.world] or 0) + 1
		end
	end
	local sets = {}
	for w, n in pairs(counts) do
		if n >= Combat.WorldSet.count then
			sets[w] = true
		end
	end
	return sets
end

return PetStats

-- Regras puras de chocar ovos e rolar mutações.
-- `rng` é uma função que retorna um número em [0, 1) (Random:NextNumber no servidor).

local Eggs = require(script.Parent.Parent.Config.Eggs)
local Pets = require(script.Parent.Parent.Config.Pets)
local Mutations = require(script.Parent.Parent.Config.Mutations)
local LuckLogic = require(script.Parent.LuckLogic)

local HatchLogic = {}

-- Verifica a condição extra de uma entrada. Retorna (ok, motivo legível).
function HatchLogic.conditionMet(cond, profile): (boolean, string?)
	if not cond then
		return true, nil
	end
	if cond.minSpeciesDiscovered then
		local species = LuckLogic.collectionCounts(profile.bestiary)
		if species < cond.minSpeciesDiscovered then
			return false, string.format("Requer %d espécies no bestiário (você tem %d)", cond.minSpeciesDiscovered, species)
		end
	end
	if cond.bossDefeated then
		local b = profile.bestiary and profile.bestiary.bosses and profile.bestiary.bosses[cond.bossDefeated]
		if not b or (b.n or 0) < 1 then
			return false, "Requer derrotar " .. cond.bossDefeated
		end
	end
	return true, nil
end

-- Probabilidades REAIS de um ovo para este perfil e multiplicador de sorte (categoria PetVariant).
function HatchLogic.eggOdds(eggId: string, profile, petMult: number)
	local egg = Eggs.Info[eggId]
	if not egg then
		return nil
	end
	local entries = {}
	local reasons = {}
	for _, e in ipairs(egg.entries) do
		local species = Pets.Species[e.species]
		local ok, reason = HatchLogic.conditionMet(e.condition, profile)
		reasons[e.species] = reason
		table.insert(entries, { key = e.species, weight = e.weight, rarity = species.rarity, available = ok })
	end
	local probs = LuckLogic.applyWeighted(entries, petMult)
	for _, o in ipairs(probs) do
		o.reason = reasons[o.key]
	end
	return probs
end

function HatchLogic.mutationChance(mutMult: number): number
	return LuckLogic.applyChance(Mutations.BaseChance, mutMult, Mutations.LuckInfluence, Mutations.MaxChance)
end

-- Probabilidade de cada mutação (já multiplicada pela chance de mutar) para um mundo.
function HatchLogic.mutationOdds(worldId: string, mutMult: number)
	local chance = HatchLogic.mutationChance(mutMult)
	local allowed = Mutations.allowedFor(worldId)
	local total = 0
	for _, id in ipairs(allowed) do
		total += Mutations.Info[id].weight
	end
	local out = {}
	for _, id in ipairs(allowed) do
		table.insert(out, { key = id, p = chance * Mutations.Info[id].weight / total })
	end
	return out, chance
end

function HatchLogic.rollMutation(worldId: string, mutMult: number, rng): string?
	local chance = HatchLogic.mutationChance(mutMult)
	if rng() >= chance then
		return nil
	end
	local allowed = Mutations.allowedFor(worldId)
	local total = 0
	for _, id in ipairs(allowed) do
		total += Mutations.Info[id].weight
	end
	local r = rng() * total
	local acc = 0
	for _, id in ipairs(allowed) do
		acc += Mutations.Info[id].weight
		if r < acc then
			return id
		end
	end
	return allowed[#allowed]
end

-- Sorteia um ovo. mults = { PetVariant = n, Mutation = n }
function HatchLogic.roll(eggId: string, profile, mults, rng)
	local egg = Eggs.Info[eggId]
	assert(egg, "ovo inválido")
	local probs = HatchLogic.eggOdds(eggId, profile, mults.PetVariant or 1)
	local species, entry = LuckLogic.pick(probs, rng())
	local mutation = HatchLogic.rollMutation(egg.world, mults.Mutation or 1, rng)
	return species, mutation, entry and entry.p or 0
end

return HatchLogic

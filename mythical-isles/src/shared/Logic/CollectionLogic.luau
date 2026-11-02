-- Marcos de coleção do bestiário (puro).

local Exploration = require(script.Parent.Parent.Config.Exploration)
local LuckLogic = require(script.Parent.LuckLogic)

local CollectionLogic = {}

function CollectionLogic.counts(data)
	local species, mutations = LuckLogic.collectionCounts(data.bestiary)
	local foes = 0
	for _ in pairs(data.bestiary.enemies) do
		foes += 1
	end
	for _ in pairs(data.bestiary.bosses) do
		foes += 1
	end
	return { species = species, mutations = mutations, enemies = foes }
end

function CollectionLogic.isComplete(milestone, counts): boolean
	for k, n in pairs(milestone.need) do
		if (counts[k] or 0) < n then
			return false
		end
	end
	return true
end

-- Marcos completos e ainda não resgatados.
function CollectionLogic.claimable(data)
	local counts = CollectionLogic.counts(data)
	local list = {}
	for _, m in ipairs(Exploration.CollectionMilestones) do
		if not data.collectionClaimed[m.id] and CollectionLogic.isComplete(m, counts) then
			table.insert(list, m)
		end
	end
	return list, counts
end

function CollectionLogic.claim(data, id: string)
	local counts = CollectionLogic.counts(data)
	for _, m in ipairs(Exploration.CollectionMilestones) do
		if m.id == id then
			if data.collectionClaimed[id] or not CollectionLogic.isComplete(m, counts) then
				return nil
			end
			data.collectionClaimed[id] = true
			return m.reward, m
		end
	end
	return nil
end

return CollectionLogic

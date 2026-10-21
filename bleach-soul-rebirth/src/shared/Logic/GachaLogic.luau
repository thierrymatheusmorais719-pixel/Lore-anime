--!strict
-- Invocação de poderes com raridade, pity e compra direta.
local GachaLogic = {}

-- pool: lista de ids de poderes da facção; powers: Config/Powers.List; rarities: Config/Powers.Rarities
function GachaLogic.roll(gacha: any, pool: { string }, powers: any, rarities: any, settings: any, rngFloat: () -> number): string
	gacha.rolls += 1
	gacha.epicPity += 1
	gacha.legendaryPity += 1

	local byRarity: { [string]: { string } } = {}
	local highestOrder = 0
	local highest = "Common"
	for _, id in pool do
		local rarity = powers[id].rarity
		byRarity[rarity] = byRarity[rarity] or {}
		table.insert(byRarity[rarity], id)
		if rarities[rarity].order > highestOrder then
			highestOrder = rarities[rarity].order
			highest = rarity
		end
	end

	local chosenRarity: string
	if gacha.legendaryPity >= settings.legendaryPity then
		chosenRarity = highest
	elseif gacha.epicPity >= settings.epicPity then
		-- Melhor entre Épico e o mais alto disponível
		chosenRarity = if byRarity.Epic then "Epic" else highest
	else
		local total = 0
		for rarity in byRarity do
			total += rarities[rarity].weight
		end
		local pick = rngFloat() * total
		chosenRarity = highest
		-- ordem determinística para reprodutibilidade
		local ordered = {}
		for rarity in byRarity do
			table.insert(ordered, rarity)
		end
		table.sort(ordered, function(a, b)
			return rarities[a].order < rarities[b].order
		end)
		for _, rarity in ordered do
			pick -= rarities[rarity].weight
			if pick <= 0 then
				chosenRarity = rarity
				break
			end
		end
	end

	local order = rarities[chosenRarity].order
	if order >= 3 then
		gacha.epicPity = 0
	end
	if chosenRarity == highest then
		gacha.legendaryPity = 0
	end
	local candidates = byRarity[chosenRarity]
	local index = math.clamp(math.floor(rngFloat() * #candidates) + 1, 1, #candidates)
	local id = candidates[index]
	gacha.owned[id] = true
	return id
end

return GachaLogic

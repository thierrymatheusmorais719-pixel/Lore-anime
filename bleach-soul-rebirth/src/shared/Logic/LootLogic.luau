--!strict
-- Rolagem de drops com proteção contra azar (pity). `rng(min,max)` e `chance()` são injetados.
local LootLogic = {}

export type Rng = { int: (number, number) -> number, float: () -> number }

export type Drop = { id: string, qty: number }

function LootLogic.roll(
	tableDef: any,
	pityState: { [string]: number },
	tableId: string,
	rng: Rng
): ({ Drop }, number, number)
	local drops: { Drop } = {}
	for _, entry in (tableDef.guaranteed or {}) :: any do
		table.insert(drops, { id = entry.id, qty = rng.int(entry.qty[1], entry.qty[2]) })
	end

	local pity = tableDef.pity
	local gotPityItem = false
	for _, entry in (tableDef.chance or {}) :: any do
		if rng.float() < entry.chance then
			table.insert(drops, { id = entry.id, qty = rng.int(entry.qty[1], entry.qty[2]) })
			if pity and entry.id == pity.id then
				gotPityItem = true
			end
		end
	end

	if pity then
		local key = tableId
		if gotPityItem then
			pityState[key] = 0
		else
			pityState[key] = (pityState[key] or 0) + 1
			if pityState[key] >= pity.after then
				table.insert(drops, { id = pity.id, qty = 1 })
				pityState[key] = 0
			end
		end
	end

	local kan = 0
	if tableDef.kan then
		kan = rng.int(tableDef.kan[1], tableDef.kan[2])
	end
	return drops, kan, tableDef.shards or 0
end

return LootLogic

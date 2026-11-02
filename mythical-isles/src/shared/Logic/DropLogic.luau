-- Rolagem pura de tabelas de drop. Cada entrada é independente.

local LuckLogic = require(script.Parent.LuckLogic)

local DropLogic = {}

-- Chance efetiva de uma entrada. mults[categoria] vem do LuckService (servidor).
function DropLogic.effectiveChance(entry, mults): number
	if not entry.luck then
		return math.clamp(entry.chance, 0, 1)
	end
	local cat = entry.category or "Drop"
	local mult = mults and mults[cat] or 1
	-- Sem teto configurado = a sorte não pode subir a chance (evita garantias não definidas).
	return LuckLogic.applyChance(entry.chance, mult, 1, entry.maxChance or entry.chance)
end

-- Lista de chances (para a interface mostrar o que realmente vale).
function DropLogic.odds(tbl, mults)
	local out = {}
	for _, e in ipairs(tbl) do
		table.insert(out, { item = e.item, base = e.chance, p = DropLogic.effectiveChance(e, mults), min = e.min, max = e.max, luck = e.luck == true })
	end
	return out
end

-- opts.worldIndex: usado por entradas que escalam com o mundo (tesouros)
function DropLogic.roll(tbl, mults, rng, opts)
	opts = opts or {}
	local results = {}
	for _, e in ipairs(tbl) do
		local p = DropLogic.effectiveChance(e, mults)
		if rng() < p then
			local span = (e.max or 1) - (e.min or 1)
			local amount = (e.min or 1) + math.floor(rng() * (span + 1))
			if amount > (e.max or 1) then
				amount = e.max or 1
			end
			local w = opts.worldIndex or 1
			if e.scaleByWorld then
				amount = math.floor(e.scaleByWorld * (w ^ 2.2) * (0.8 + rng() * 0.4))
			elseif e.scaleByWorldEssence then
				amount = math.floor(amount * (w ^ 1.6))
			end
			table.insert(results, { item = e.item, amount = amount, notable = e.notable == true, mutation = e.mutation, p = p })
		end
	end
	return results
end

return DropLogic

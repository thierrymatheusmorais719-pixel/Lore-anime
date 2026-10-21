--!strict
-- Resolve quais habilidades ocupam Z/X/C/V conforme facção, poder, forma e máscara.
local Loadout = {}

export type Slots = { Z: string?, X: string?, C: string?, V: string? }

Loadout.SlotOrder = { "Z", "X", "C", "V" }

function Loadout.resolve(
	factions: any,
	powers: any,
	faction: string?,
	powerId: string?,
	form: string?,
	mask: boolean?
): Slots
	local slots: { [string]: string } = {}
	local f = faction and factions[faction]
	if not f or type(f) ~= "table" or not f.base then
		return slots :: any
	end
	for slot, id in f.base do
		slots[slot] = id
	end
	local power = powerId and powers[powerId]
	if power and power.faction == faction then
		if form == "Tier1" or form == "Tier2" then
			for slot, id in power.tier1.abilities do
				slots[slot] = id
			end
		end
		if form == "Tier2" then
			for slot, id in power.tier2.abilities do
				slots[slot] = id
			end
		end
	end
	if mask and factions.Mask then
		for slot, id in factions.Mask.overrides do
			slots[slot] = id
		end
	end
	return slots :: any
end

-- Arma visível conforme a forma atual.
function Loadout.weapon(factions: any, powers: any, faction: string?, powerId: string?, form: string?): any
	local f = faction and factions[faction]
	if not f or type(f) ~= "table" or not f.weapon then
		return nil
	end
	local power = powerId and powers[powerId]
	if power and power.faction == faction then
		if form == "Tier2" then
			return power.tier2.weapon
		elseif form == "Tier1" then
			return power.tier1.weapon
		end
	end
	return f.weapon
end

return Loadout

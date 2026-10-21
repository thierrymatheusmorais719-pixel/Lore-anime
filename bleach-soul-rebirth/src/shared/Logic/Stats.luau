--!strict
-- Cálculo puro de atributos derivados a partir do perfil, equipamentos e árvore de habilidades.
local Stats = {}

export type Derived = {
	maxHealth: number,
	maxReiatsu: number,
	meleeMultiplier: number,
	abilityMultiplier: number,
	defense: number,
	walkSpeedBonus: number,
	cooldownMultiplier: number,
	abilityCostMultiplier: number,
	drainMultiplier: number,
	parryBonus: number,
	counterBonus: number,
	guardMultiplier: number,
	airDashes: number,
	dashCooldownMultiplier: number,
	finisherWave: boolean,
	attributes: { [string]: number },
}

-- progression: Config/Progression ; skillTree: nós da facção ; items: Config/Items.List
function Stats.compute(profile: any, progression: any, skillTree: any?, items: any, rarityMultiplier: number?): Derived
	local attrs: { [string]: number } = { Strength = 0, Spirit = 0, Vitality = 0, Agility = 0 }
	for name, value in profile.stats or {} do
		if attrs[name] ~= nil then
			attrs[name] += value
		end
	end

	-- Bônus de equipamentos
	local inventory = profile.inventory and profile.inventory.items or {}
	for _, uid in profile.equipped or {} do
		for _, entry in inventory do
			if entry.uid == uid then
				local def = items[entry.id]
				if def and def.stats then
					for name, value in def.stats do
						if attrs[name] ~= nil then
							attrs[name] += value
						end
					end
				end
				break
			end
		end
	end

	-- Efeitos da árvore
	local effects: { [string]: number } = {}
	if skillTree then
		for nodeId, owned in profile.skills or {} do
			local node = skillTree[nodeId]
			if owned and node then
				for key, value in node.effects do
					effects[key] = (effects[key] or 0) + value
				end
			end
		end
	end

	local A = progression.Attributes
	local level = profile.level or 1
	local rarity = rarityMultiplier or 1

	local baseHealth = progression.BaseHealth + progression.HealthPerLevel * (level - 1)
	local maxHealth = (baseHealth + attrs.Vitality * A.Vitality.healthPerPoint) * (1 + (effects.health or 0))
	local maxReiatsu = progression.BaseReiatsu
		+ progression.ReiatsuPerLevel * (level - 1)
		+ attrs.Spirit * A.Spirit.reiatsuPerPoint
		+ (effects.reiatsu or 0)

	return {
		maxHealth = math.floor(maxHealth),
		maxReiatsu = math.floor(maxReiatsu),
		meleeMultiplier = (1 + attrs.Strength * A.Strength.meleePerPoint + (effects.melee or 0)) * rarity,
		abilityMultiplier = (1 + attrs.Spirit * A.Spirit.abilityPerPoint + (effects.ability or 0)) * rarity,
		defense = math.min(A.Vitality.maxDefense, attrs.Vitality * A.Vitality.defensePerPoint),
		walkSpeedBonus = math.min(A.Agility.maxSpeed, attrs.Agility * A.Agility.speedPerPoint),
		cooldownMultiplier = math.max(
			0.5,
			1 - math.min(A.Agility.maxCooldown, attrs.Agility * A.Agility.cooldownPerPoint) + (effects.cooldown or 0)
		),
		abilityCostMultiplier = math.max(0.5, 1 + (effects.abilityCost or 0)),
		drainMultiplier = math.max(0.3, 1 + (effects.drain or 0)),
		parryBonus = effects.parryWindow or 0,
		counterBonus = effects.counter or 0,
		guardMultiplier = 1 + (effects.guard or 0),
		airDashes = math.floor(effects.airDashes or 0),
		dashCooldownMultiplier = math.max(0.5, 1 + (effects.dashCooldown or 0)),
		finisherWave = (effects.finisherWave or 0) > 0,
		attributes = attrs,
	}
end

-- Dano final: base * multiplicadores do atacante * (1 - defesa do alvo).
function Stats.damage(base: number, attackerMultiplier: number, defenderDefense: number): number
	local raw = base * attackerMultiplier * (1 - math.clamp(defenderDefense, 0, 0.8))
	return math.max(1, math.floor(raw * 10 + 0.5) / 10)
end

return Stats

-- Fórmulas de dano puras.

local Combat = require(script.Parent.Parent.Config.Combat)

local CombatRules = {}

-- atk: ataque do atacante; mult: multiplicador da habilidade; def: defesa do alvo
-- opts: { crit = chance, defReduction = 0..1, bonus = multiplicador extra (marcas, conjuntos) }
-- Retorna (dano inteiro >= 1, crítico?)
function CombatRules.damage(atk: number, mult: number, def: number, rng, opts): (number, boolean)
	opts = opts or {}
	local effDef = math.max(0, def * (1 - math.clamp(opts.defReduction or 0, 0, 0.9)))
	local base = atk * mult * Combat.DefenseK / (Combat.DefenseK + effDef)
	local variance = 1 + (rng() * 2 - 1) * Combat.Variance
	local crit = rng() < (opts.crit or 0)
	local dmg = base * variance * (opts.bonus or 1) * (crit and Combat.CritMult or 1)
	return math.max(1, math.floor(dmg + 0.5)), crit
end

-- Dano aplicado a um alvo com escudo: retorna (dano na vida, escudo restante).
function CombatRules.absorb(damage: number, shield: number): (number, number)
	if shield <= 0 then
		return damage, 0
	end
	if shield >= damage then
		return 0, shield - damage
	end
	return damage - shield, 0
end

-- Distância horizontal (XZ). Usada para alcance contra alvos voadores.
function CombatRules.flatDistance(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

-- Validação de alcance com folga máxima (o servidor usa as posições DELE, não as do cliente).
function CombatRules.inRange(distance: number, range: number, targetRadius: number?, slack: number?): boolean
	return distance <= range + (targetRadius or 0) + (slack or 1.5)
end

return CombatRules

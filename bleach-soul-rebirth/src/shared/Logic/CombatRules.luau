--!strict
-- Regras puras de combate (sem APIs do Roblox) — testáveis com o CLI `luau`.
local CombatRules = {}

export type DefenseState = {
	blocking: boolean,
	blockStart: number,
	guard: number,
	iframeUntil: number,
	parryBonus: number?,
}

export type HitSpec = {
	guardBreak: boolean?,
	unparryable: boolean?,
	guardDamage: number?,
	projectile: boolean?,
}

export type DefenseResult = "Immune" | "Parry" | "GuardBreak" | "Blocked" | "Hit"

-- Resolve como o defensor recebe um golpe.
-- facingDot = dot(lookVector do defensor, direção defensor->atacante). >0 = atacante à frente.
function CombatRules.resolveDefense(
	defender: DefenseState,
	spec: HitSpec,
	facingDot: number,
	now: number,
	parryWindow: number,
	facingThreshold: number
): DefenseResult
	if now < defender.iframeUntil then
		return "Immune"
	end
	if not defender.blocking or facingDot < facingThreshold then
		return "Hit"
	end
	local window = parryWindow + (defender.parryBonus or 0)
	if not spec.unparryable and not spec.projectile and now - defender.blockStart <= window then
		return "Parry"
	end
	if spec.guardBreak then
		return "GuardBreak"
	end
	if defender.guard - (spec.guardDamage or 10) <= 0 then
		return "GuardBreak"
	end
	return "Blocked"
end

-- Próximo índice da sequência de combo.
function CombatRules.nextComboIndex(
	current: number,
	lastEnd: number,
	now: number,
	maxHits: number,
	resetTime: number
): number
	if current <= 0 or current >= maxHits or now - lastEnd > resetTime then
		return 1
	end
	return current + 1
end

-- Acumula atordoamento sem ultrapassar o limite de corrente (evita stun-lock infinito).
function CombatRules.applyStun(currentUntil: number, now: number, duration: number, maxChain: number): number
	local base = math.max(currentUntil, now)
	local target = math.max(base, now + duration)
	return math.min(target, now + maxChain)
end

-- Regeneração de guarda após atraso desde o último bloqueio.
function CombatRules.regenGuard(
	guard: number,
	maxGuard: number,
	sinceLastHit: number,
	delay: number,
	rate: number,
	dt: number
): number
	if sinceLastHit < delay then
		return guard
	end
	return math.min(maxGuard, guard + rate * dt)
end

-- Distância horizontal entre dois pontos (tuplas x,z), usada na validação de alcance.
function CombatRules.withinRange(dx: number, dz: number, range: number): boolean
	return dx * dx + dz * dz <= range * range
end

return CombatRules

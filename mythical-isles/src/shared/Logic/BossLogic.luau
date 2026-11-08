-- Regras puras de bosses: fases, escolha de ataques, escala de vida e elegibilidade.

local Combat = require(script.Parent.Parent.Config.Combat)

local BossLogic = {}

-- Fase ativa para uma fração de vida. phases[i].at decrescente (1.0, 0.6, 0.3...).
function BossLogic.phaseIndex(hpFrac: number, phases): number
	local idx = 1
	for i, ph in ipairs(phases) do
		if hpFrac <= ph.at + 1e-9 then
			idx = i
		end
	end
	return idx
end

-- Escolhe um ataque da fase, evitando repetir o último quando há alternativa.
-- Sorteia o próximo ataque da fase, sem repetir o último. `blocked(id)` (opcional) tira da roleta o que
-- ainda está em recarga (poderes dos bosses); se tudo estiver bloqueado, ignora o bloqueio.
function BossLogic.pickAttack(phase, lastAttack: string?, rng, blocked: ((string) -> boolean)?): string
	local pool = phase.attacks
	if #pool == 1 then
		return pool[1]
	end
	local options, fallback = {}, {}
	for _, id in ipairs(pool) do
		if id ~= lastAttack then
			table.insert(fallback, id)
			if not blocked or not blocked(id) then
				table.insert(options, id)
			end
		end
	end
	if #options == 0 then
		options = fallback
	end
	local i = math.floor(rng() * #options) + 1
	return options[math.min(i, #options)]
end

function BossLogic.scaledHp(baseHp: number, players: number, rules): number
	local n = math.clamp(players, 1, rules.hpScaleMaxPlayers)
	return math.floor(baseHp * (1 + rules.hpScalePerExtraPlayer * (n - 1)))
end

-- Intervalo entre ataques (fase, enfurecer após muito tempo).
function BossLogic.interval(phase, fightTime: number, rules): number
	local base = phase.interval
	if fightTime > rules.enrageAfter then
		base *= 0.7
	end
	return base
end

-- Elegibilidade de recompensa de boss.
-- c = { damage, support, tanked, lastAt }; inArena = estava na arena na derrota
function BossLogic.eligible(c, bossMaxHp: number, now: number, inArena: boolean): (boolean, string)
	if not c then
		return false, "sem participação"
	end
	local P = Combat.Participation
	local contributed = (c.damage or 0) >= bossMaxHp * P.bossDamageFraction
		or (c.support or 0) >= bossMaxHp * P.bossSupportFraction
		or (c.tanked or 0) >= bossMaxHp * P.bossTankedFraction
	if not contributed then
		return false, "participação insuficiente"
	end
	local recent = c.lastAt and (now - c.lastAt) <= P.bossRecentSeconds
	if not (inArena or recent) then
		return false, "saiu do combate"
	end
	return true, "ok"
end

-- Elegibilidade para inimigos comuns: dano mínimo ou golpe final.
function BossLogic.enemyEligible(damage: number, maxHp: number, killingBlow: boolean): boolean
	return killingBlow or damage >= maxHp * Combat.Participation.enemyDamageFraction
end

return BossLogic

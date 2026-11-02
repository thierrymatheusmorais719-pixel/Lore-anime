-- Máquina de estados pura da IA dos inimigos.
-- O EnemyService monta o `ctx` a cada tick (com dados do servidor) e executa o estado retornado.
--
-- Estados: Idle, Patrol, Investigate, Chase, Attack, Recover, Return, Dead

local EnemyBrain = {}

EnemyBrain.States = { "Idle", "Patrol", "Investigate", "Chase", "Attack", "Recover", "Return", "Dead" }

-- O alvo está perceptível? (linha de visão dentro de `detect`, ou muito perto)
function EnemyBrain.detects(ctx, cfg): boolean
	if not ctx.hasTarget then
		return false
	end
	if ctx.targetDist <= cfg.senseRadius then
		return true
	end
	return ctx.canSee and ctx.targetDist <= cfg.detect
end

-- ctx: { hp, hasTarget, targetDist, canSee, homeDist, timeInState, chaseTime, attackReady,
--        inAttackRange, heard, reachedGoal, idleDuration, attackDone, passive }
-- cfg: { detect, senseRadius, leash, maxChase, investigateTime, recoverTime }
-- Retorna (novoEstado, motivo)
function EnemyBrain.decide(state: string, ctx, cfg): (string, string)
	if ctx.hp <= 0 then
		return "Dead", "sem vida"
	end
	if state == "Dead" then
		return "Dead", "derrotado"
	end

	if state == "Return" then
		if ctx.homeDist <= 4 then
			return "Idle", "voltou à origem"
		end
		return "Return", "retornando"
	end

	-- Coleira: nunca perseguir para sempre nem para longe demais
	if state == "Chase" or state == "Attack" or state == "Recover" or state == "Investigate" then
		if ctx.homeDist > cfg.leash then
			return "Return", "fora da área de origem"
		end
		if (state == "Chase" or state == "Investigate") and ctx.chaseTime > cfg.maxChase then
			return "Return", "perseguição longa demais"
		end
	end

	if ctx.passive then
		if state == "Idle" and ctx.timeInState >= ctx.idleDuration then
			return "Patrol", "passeio"
		elseif state == "Patrol" and (ctx.reachedGoal or ctx.timeInState > 8) then
			return "Idle", "pausa"
		end
		return state, "passivo"
	end

	if state == "Idle" or state == "Patrol" then
		if EnemyBrain.detects(ctx, cfg) then
			return "Chase", "detectou alvo"
		end
		if ctx.heard then
			return "Investigate", "ouviu algo"
		end
		if state == "Idle" and ctx.timeInState >= ctx.idleDuration then
			return "Patrol", "patrulha"
		end
		if state == "Patrol" and (ctx.reachedGoal or ctx.timeInState > 8) then
			return "Idle", "fim da patrulha"
		end
		return state, "rotina"
	end

	if state == "Investigate" then
		if EnemyBrain.detects(ctx, cfg) then
			return "Chase", "encontrou o alvo"
		end
		if (ctx.reachedGoal and ctx.timeInState >= cfg.investigateTime) or ctx.timeInState >= cfg.investigateTime * 2 then
			return "Return", "nada encontrado"
		end
		return "Investigate", "procurando"
	end

	if state == "Chase" then
		if not ctx.hasTarget then
			return "Investigate", "perdeu o alvo"
		end
		if not ctx.canSee and ctx.targetDist > cfg.senseRadius and ctx.targetDist > cfg.detect * 1.25 then
			return "Investigate", "alvo fora de vista"
		end
		if ctx.inAttackRange and ctx.attackReady and (ctx.canSee or ctx.targetDist <= cfg.senseRadius) then
			return "Attack", "no alcance"
		end
		return "Chase", "perseguindo"
	end

	if state == "Attack" then
		if ctx.attackDone then
			return "Recover", "ataque concluído"
		end
		return "Attack", "atacando"
	end

	if state == "Recover" then
		if ctx.timeInState >= cfg.recoverTime then
			if ctx.hasTarget then
				return "Chase", "retomando"
			end
			return "Investigate", "alvo sumiu"
		end
		return "Recover", "recuperando"
	end

	return "Idle", "estado desconhecido"
end

return EnemyBrain

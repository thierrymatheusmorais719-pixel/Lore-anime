-- DÁ PARA DESVIAR? Para cada ataque de boss com área: o tempo do aviso (telegraph) menos a reação do jogador, vezes a
-- velocidade de andar, contra a distância que o jogador precisa andar para sair da área, no PIOR lugar dentro dela
-- (círculo no jogador: o raio; linha/cruz/leque mirados nele: meia largura; anel: meia espessura; cone: o melhor
-- entre sair pelo lado ou para trás, no pior ponto; zonas seguras: a maior distância até a zona segura mais perto).
-- Uso: python3 tools/run_tests.py luau --dodge
local Bosses = require(__proxy("Shared/Config/Bosses"))
local SPEED, REACT = 16, 0.4
local rows = {}
for bid, b in pairs(Bosses.Info) do
	for aid, a in pairs(b.attacks) do
		local esc, how = nil, ""
		local sh = a.shape
		if sh == "target_circles" or sh == "random_circles" then
			esc, how = a.radius, "raio"
		elseif sh == "slam" then
			esc, how = math.max(0, a.radius - 4), "raio − colado no boss"
		elseif sh == "line" or sh == "cross" or sh == "fan" then
			esc, how = a.width / 2, "meia largura"
		elseif sh == "ring" then
			esc, how = (a.outer - a.inner) / 2, "meia espessura do anel"
		elseif sh == "cone" then
			local worst = 0
			local half = math.rad(a.angle / 2)
			for d = 1, a.length do
				worst = math.max(worst, math.min(d * math.sin(half), a.length - d))
			end
			esc, how = worst, "cone (lado ou trás)"
		elseif sh == "safezones" then
			local ar = b.arenaRadius or 60
			local worst = 0
			-- zonas igualmente espaçadas; o jogo sorteia a distância de cada uma entre 0,35 e 0,65 do raio da arena:
			-- vale o pior caso do sorteio (todas na mesma distância, nas pontas do intervalo)
			for _, k in ipairs({ 0.35, 0.5, 0.65 }) do
				for gx = -ar, ar, 2 do
					for gz = -ar, ar, 2 do
						if gx * gx + gz * gz <= ar * ar then
							local best = math.huge
							for i = 1, a.count do
								local ang = (i - 1) * math.pi * 2 / a.count
								local sx, sz = math.cos(ang) * ar * k, math.sin(ang) * ar * k
								best = math.min(best, math.max(0, math.sqrt((gx - sx) ^ 2 + (gz - sz) ^ 2) - a.radius))
							end
							worst = math.max(worst, best)
						end
					end
				end
			end
			esc, how = worst, string.format("até a zona segura (%d zonas de raio %d)", a.count, a.radius)
		end
		if esc then
			local can = math.max(0, (a.telegraph - REACT) * SPEED)
			table.insert(rows, { b.name, a.label, a.telegraph, esc, can, can - esc, how })
		end
	end
end
-- INIMIGOS: pancada (círculo no inimigo; o jogador encostado nele em luta), investida (faixa mirada no jogador,
-- largura max(5, raio × 1,6)) e projétil (círculo de 4,5 no jogador; aviso = preparação + tempo de voo mínimo 0,2 s)
local Enemies = require(__proxy("Shared/Config/Enemies"))
local EnemyModels = require(__proxy("Shared/Builders/EnemyModels"))
for eid, cfg in pairs(Enemies.Info) do
	local atk = cfg.attack
	if atk and (atk.kind == "slam" or atk.kind == "lunge" or atk.kind == "projectile") then
		local _, _, radius = EnemyModels.build(eid, cfg)
		local esc, how, tele
		if atk.kind == "slam" then
			esc, how, tele = math.max(0, atk.radius - (radius + 1)), "raio − encostado", atk.windup
		elseif atk.kind == "lunge" then
			esc, how, tele = math.max(5, radius * 1.6) / 2, "meia largura da investida", atk.windup
		else
			esc, how, tele = 4.5, "círculo no jogador", atk.windup + 0.2
		end
		local can = math.max(0, (tele - REACT) * SPEED)
		table.insert(rows, { "(inimigo) " .. eid, atk.kind, tele, esc, can, can - esc, how })
	end
end
table.sort(rows, function(x, y)
	return x[6] < y[6]
end)
local bad = 0
for _, r in ipairs(rows) do
	if r[6] < 0 then
		bad += 1
	end
	print(string.format("DODGE %-15s %-24s aviso %.1f s  precisa %5.1f  alcança %5.1f  folga %+6.1f  (%s)", r[1], r[2], r[3], r[4], r[5], r[6], r[7]))
end
print(string.format("DODGE %d ataques com área (bosses e inimigos); %d impossíveis de desviar do pior lugar (reação %.1f s, %d studs/s)", #rows, bad, REACT, SPEED))
if bad > 0 then
	error("há ataques de boss impossíveis de desviar")
end

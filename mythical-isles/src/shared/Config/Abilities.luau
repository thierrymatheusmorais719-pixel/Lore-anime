-- Habilidades de combate dos pets. Ativadas pelo jogador (teclas 1-4 / botões) e
-- validadas no servidor: recarga, energia, alcance, alvo válido e limite de frequência.
--
-- power: multiplicador do ataque do pet (dano) ou da vida máx. (cura/escudo)
-- rankBonus: +% de efeito por nível da habilidade (rank 1..MaxRank)
-- rankCdr: -% de recarga por nível acima de 1

local Abilities = {}

Abilities.MaxRank = 5
Abilities.RankBonus = 0.12
Abilities.RankCdr = 0.04
-- Custo para subir de rank: essência * rank e tomos.
Abilities.UpgradeCost = function(rank: number)
	return { essence = 80 * rank * rank, items = { skill_tome = rank } }
end
-- Intervalo mínimo entre pedidos de habilidade do mesmo jogador (anti-spam).
Abilities.GlobalMinInterval = 0.35

Abilities.Info = {
	charge = {
		label = "Investida", icon = "»", kind = "damage", target = "enemy",
		power = 1.7, cooldown = 6, cost = 20, range = 30, dash = true,
		desc = "Avança até o alvo e causa dano pesado.",
	},
	energy_bolt = {
		label = "Projétil de Energia", icon = "✦", kind = "damage", target = "enemy",
		power = 1.45, cooldown = 4, cost = 15, range = 42, projectile = true,
		desc = "Dispara um projétil de energia à distância.",
	},
	guard_shield = {
		label = "Escudo Temporário", icon = "⛨", kind = "shield", target = "self",
		power = 0.35, cooldown = 14, cost = 25, range = 0, duration = 6, taunt = 4,
		desc = "Ganha um escudo de 35% da vida e provoca inimigos próximos.",
	},
	mend = {
		label = "Cura", icon = "✚", kind = "heal", target = "allies",
		power = 0.22, cooldown = 10, cost = 30, range = 30,
		desc = "Cura a equipe e o dono em 22% da vida máx. do suporte.",
	},
	shockwave = {
		label = "Onda de Choque", icon = "◎", kind = "aoe", target = "self",
		power = 1.15, cooldown = 9, cost = 30, range = 16,
		desc = "Causa dano a todos os inimigos ao redor.",
	},
	sunder = {
		label = "Quebrar Defesa", icon = "⚔", kind = "debuff", target = "enemy",
		power = 0.85, cooldown = 10, cost = 20, range = 26, defReduction = 0.35, duration = 6,
		desc = "Reduz a defesa do alvo em 35% por 6s.",
	},
	haste = {
		label = "Vento Veloz", icon = "➤", kind = "buff", target = "allies",
		power = 0.30, cooldown = 16, cost = 30, range = 30, duration = 6, walkSpeed = 6,
		desc = "+30% velocidade de ataque da equipe e corrida do dono por 6s.",
	},
	treasure_sense = {
		label = "Faro do Tesouro", icon = "◈", kind = "mark", target = "enemy",
		power = 0.7, cooldown = 12, cost = 15, range = 36, markBonus = 0.15, duration = 8, revealRadius = 140,
		desc = "Marca o alvo (+15% dano recebido) e revela tesouros próximos.",
	},
	root_snare = {
		label = "Laço de Raízes", icon = "✣", kind = "control", target = "enemy",
		power = 0.6, cooldown = 12, cost = 25, range = 30, duration = 2.0, bossSlow = 0.4,
		desc = "Imobiliza o alvo por 2s (bosses: apenas lentidão).",
	},
	starfall = {
		label = "Chuva Estelar", icon = "✸", kind = "aoe_target", target = "enemy",
		power = 2.1, cooldown = 15, cost = 40, range = 40, radius = 13,
		desc = "Estrelas caem sobre o alvo, atingindo a área.",
	},
}

return Abilities

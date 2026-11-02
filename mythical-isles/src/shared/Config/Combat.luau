-- Regras gerais de combate e progressão.

local Combat = {}

Combat.TeamSize = 4

-- Modelos de atributos por FUNÇÃO. Valores de nível 1, raridade Comum, mundo 1, estágio 1.
-- hp, atk, def, aspd (ataques/s), range (studs), energy (máx.), crit (chance), regen (energia/s)
-- Nenhuma função ganha em tudo: tanque tem vida/defesa e pouco dano; atacante o contrário; etc.
Combat.Roles = {
	Tank = { label = "Tanque", hp = 240, atk = 13, def = 30, aspd = 0.8, range = 8, energy = 100, crit = 0.03, regen = 6, threat = 3.0,
		desc = "Resiste a dano e atrai a atenção dos inimigos." },
	Attacker = { label = "Atacante", hp = 125, atk = 27, def = 9, aspd = 1.15, range = 9, energy = 100, crit = 0.12, regen = 7, threat = 1.2,
		desc = "Causa muito dano, mas é frágil." },
	Support = { label = "Suporte", hp = 145, atk = 11, def = 15, aspd = 0.9, range = 24, energy = 120, crit = 0.04, regen = 9, threat = 0.8,
		desc = "Cura e fortalece a equipe." },
	Explorer = { label = "Explorador", hp = 135, atk = 16, def = 13, aspd = 1.0, range = 20, energy = 100, crit = 0.06, regen = 8, threat = 1.0,
		desc = "Encontra tesouros e marca alvos." },
	Specialist = { label = "Especialista", hp = 140, atk = 19, def = 14, aspd = 0.9, range = 22, energy = 110, crit = 0.08, regen = 8, threat = 1.0,
		desc = "Habilidades situacionais: controle e quebra de defesa." },
}

-- Estágios de evolução. Evoluir mantém mutação, nível e acessório.
Combat.Tiers = {
	{ label = "Base", mult = 1.0, levelCap = 25 },
	{ label = "Desperto", mult = 1.45, levelCap = 40, cost = { coins = 0, essence = 150, items = { evolution_dust = 5 } } },
	{ label = "Ascendido", mult = 2.1, levelCap = 60, cost = { coins = 0, essence = 900, items = { evolution_dust = 15, ascension_core = 1 } } },
}
-- Pets de mundos mais avançados exigem mais material (multiplicado pelo índice do mundo).
Combat.EvolutionWorldCostScale = 0.75

Combat.LevelStatGrowth = 0.06 -- +6% por nível

function Combat.xpToNext(level: number): number
	return math.floor(40 * level ^ 1.45)
end

-- Fórmula de dano: dano = ataque * mult * K / (K + defesaEfetiva) * variação, crítico * CritMult
Combat.DefenseK = 60
Combat.CritMult = 1.75
Combat.Variance = 0.08

-- Pets nocauteados voltam depois deste tempo com parte da vida.
Combat.KnockoutTime = 8
Combat.ReviveFraction = 0.5
Combat.OutOfCombatRegen = 0.08 -- fração da vida por segundo fora de combate

-- Ataque básico do jogador (o "Cajado de Domador").
Combat.Player = {
	attack = 12, range = 34, cooldown = 0.55, crit = 0.05,
	baseHealth = 100, healthPerWorld = 30,
}

-- Distância máxima entre pet e dono antes do pet abandonar o alvo e voltar.
Combat.PetLeash = 90
Combat.PetEngageRadius = 45 -- inimigos que atacam o dono dentro deste raio são revidados

-- Sinergias de equipe (verificadas no servidor pela composição da equipe).
-- need: contagem mínima de funções. Efeitos são somados.
Combat.Synergies = {
	{ id = "bulwark", label = "Baluarte", need = { Tank = 1, Support = 1 }, effects = { def = 0.10 },
		desc = "Tanque + Suporte: +10% defesa da equipe." },
	{ id = "pack", label = "Matilha", need = { Attacker = 2 }, effects = { atk = 0.08 },
		desc = "2 Atacantes: +8% ataque." },
	{ id = "balanced", label = "Equilíbrio", needDistinct = 3, effects = { atk = 0.05, def = 0.05, hp = 0.05 },
		desc = "3 funções diferentes: +5% em tudo." },
	{ id = "tactician", label = "Tático", need = { Specialist = 1, Support = 1 }, effects = { cdr = 0.10 },
		desc = "Especialista + Suporte: -10% recarga de habilidades." },
	{ id = "pathfinder", label = "Desbravador", need = { Explorer = 1 }, effects = { luckTreasure = 0.10 },
		desc = "Explorador na equipe: +10% sorte de tesouro." },
}

-- Conjunto: 3+ pets do mesmo mundo dão bônus de dano contra inimigos daquele mundo.
Combat.WorldSet = { count = 3, damage = 0.12 }

-- Participação mínima para receber recompensas.
Combat.Participation = {
	enemyDamageFraction = 0.10, -- inimigos comuns: causar >= 10% da vida máx. (ou golpe final)
	bossDamageFraction = 0.03, -- bosses: causar >= 3% da vida máx...
	bossSupportFraction = 0.03, -- ...ou curar/proteger o equivalente a 3% da vida do boss
	bossTankedFraction = 0.02, -- ...ou absorver (com seus pets) 2% da vida do boss em dano
	bossRecentSeconds = 30, -- e ter contribuído nos últimos N segundos ou estar na arena na derrota
}

return Combat

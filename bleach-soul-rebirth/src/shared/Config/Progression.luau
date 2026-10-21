-- Curva de experiência, atributos e efeitos por ponto.
local Progression = {}

Progression.MaxLevel = 50
Progression.StatPointsPerLevel = 3
Progression.SkillPointsPerLevel = 1

Progression.Attributes = {
	Strength = { name = "Força", kanji = "力", desc = "+2% de dano corpo a corpo por ponto.", meleePerPoint = 0.02 },
	Spirit = {
		name = "Espírito",
		kanji = "霊",
		desc = "+2,5% de dano de habilidades e +3 de Reiatsu máximo por ponto.",
		abilityPerPoint = 0.025,
		reiatsuPerPoint = 3,
	},
	Vitality = {
		name = "Vitalidade",
		kanji = "体",
		desc = "+8 de vida máxima e +0,5% de defesa por ponto (máx. 30%).",
		healthPerPoint = 8,
		defensePerPoint = 0.005,
		maxDefense = 0.3,
	},
	Agility = {
		name = "Agilidade",
		kanji = "速",
		desc = "+0,2 de velocidade (máx. +8) e −0,8% de recarga por ponto (máx. 25%).",
		speedPerPoint = 0.2,
		maxSpeed = 8,
		cooldownPerPoint = 0.008,
		maxCooldown = 0.25,
	},
}
Progression.AttributeOrder = { "Strength", "Spirit", "Vitality", "Agility" }

Progression.BaseHealth = 100
Progression.HealthPerLevel = 6
Progression.BaseReiatsu = 100
Progression.ReiatsuPerLevel = 2

-- XP necessária para ir do nível `level` para `level + 1`.
function Progression.xpToNext(level: number): number
	return math.floor(50 * level ^ 1.55 + 50)
end

-- XP de um inimigo ajustada pela diferença de nível (evita farm de inimigos fracos).
function Progression.scaledXp(baseXp: number, enemyLevel: number, playerLevel: number): number
	local diff = enemyLevel - playerLevel
	local factor = math.clamp(1 + diff * 0.08, 0.2, 1.5)
	return math.max(1, math.floor(baseXp * factor + 0.5))
end

return Progression

-- Arquétipos de inimigos e chefes. A IA (server/Enemy/EnemyBrain) lê estes parâmetros.
--   comboLength: quantos golpes leves encadeia
--   dodgeChance/blockChance/parryChance: reação ao ver o jogador iniciar um ataque
--   abilities: { {id, weight, minRange, maxRange} }
--   phases (chefes): limiar de vida -> novo comportamento
local Enemies = {}

local HOLLOW_LOOK = {
	skin = Color3.fromRGB(30, 28, 34),
	mask = true,
	hole = true,
	maskColor = Color3.fromRGB(240, 236, 225),
	eye = Color3.fromRGB(255, 60, 40),
}

Enemies.HollowGrunt = {
	name = "Hollow",
	level = 2,
	health = 120,
	walkSpeed = 15,
	damageMultiplier = 0.8,
	scale = 1,
	body = "HollowGrunt",
	look = HOLLOW_LOOK,
	weapon = { style = "Claws", length = 1.6, blade = Color3.fromRGB(230, 225, 215), bodyClaws = true },
	comboLength = 3,
	attackRange = 7,
	aggroRange = 60,
	leashRange = 120,
	reactionTime = 0.35,
	dodgeChance = 0.1,
	blockChance = 0.1,
	parryChance = 0,
	aggression = 0.7,
	abilities = { { id = "E_Leap", weight = 1, minRange = 12, maxRange = 30 } },
	xp = 35,
	loot = "HollowGrunt",
}

Enemies.HollowBrute = {
	name = "Hollow Brutamontes",
	level = 6,
	health = 300,
	walkSpeed = 12,
	damageMultiplier = 1.1,
	scale = 1.3,
	body = "HollowBrute",
	look = {
		skin = Color3.fromRGB(42, 34, 30),
		mask = true,
		maskColor = Color3.fromRGB(232, 226, 210),
		eye = Color3.fromRGB(255, 140, 40),
	},
	weapon = { style = "Claws", length = 1.2, blade = Color3.fromRGB(230, 225, 215), bodyClaws = true },
	comboLength = 2,
	attackRange = 9,
	aggroRange = 60,
	leashRange = 120,
	reactionTime = 0.5,
	dodgeChance = 0,
	blockChance = 0.25,
	parryChance = 0,
	aggression = 0.6,
	superArmorAttacks = true,
	abilities = { { id = "E_Slam", weight = 1, minRange = 0, maxRange = 12 } },
	xp = 85,
	loot = "HollowBrute",
}

Enemies.TrainingPuppet = {
	name = "Boneco de Treino",
	level = 1,
	health = 80,
	walkSpeed = 12,
	damageMultiplier = 0.5,
	scale = 1,
	look = { skin = Color3.fromRGB(150, 120, 80), mask = false, hole = false },
	weapon = { style = "Katana", length = 3.6, blade = Color3.fromRGB(140, 110, 70) },
	comboLength = 2,
	attackRange = 7,
	aggroRange = 35,
	leashRange = 70,
	reactionTime = 0.6,
	dodgeChance = 0.05,
	blockChance = 0.3,
	parryChance = 0.05,
	aggression = 0.5,
	abilities = {},
	xp = 18,
	loot = "TrainingPuppet",
}

Enemies.Dummy = {
	name = "Alvo de Treino",
	level = 1,
	health = 1000,
	walkSpeed = 0,
	scale = 1.2,
	look = { skin = Color3.fromRGB(170, 140, 95), mask = false, hole = false },
	passive = true, -- não ataca, regenera; serve para testar combos e dano
	regenerate = true,
	attackRange = 0,
	aggroRange = 0,
	leashRange = 0,
	reactionTime = 1,
	dodgeChance = 0,
	blockChance = 0,
	parryChance = 0,
	aggression = 0,
	abilities = {},
	xp = 0,
}

Enemies.Arrancar = {
	name = "Arrancar",
	level = 14,
	health = 420,
	walkSpeed = 20,
	damageMultiplier = 1.3,
	scale = 1,
	look = {
		skin = Color3.fromRGB(235, 225, 210),
		mask = true,
		hole = true,
		partialMask = true,
		maskColor = Color3.fromRGB(245, 242, 235),
		eye = Color3.fromRGB(80, 255, 140),
		outfit = Color3.fromRGB(240, 238, 232),
	},
	weapon = { style = "Katana", length = 4.2, blade = Color3.fromRGB(210, 215, 225) },
	comboLength = 4,
	attackRange = 7,
	aggroRange = 70,
	leashRange = 140,
	reactionTime = 0.25,
	dodgeChance = 0.25,
	blockChance = 0.2,
	parryChance = 0.12,
	aggression = 0.8,
	abilities = {
		{ id = "E_Cero", weight = 1, minRange = 15, maxRange = 70 },
		{ id = "E_Sonido", weight = 1, minRange = 10, maxRange = 28 },
	},
	xp = 150,
	loot = "Arrancar",
}

Enemies.MenosShade = {
	name = "Menos Sombrio",
	level = 18,
	health = 1200,
	walkSpeed = 9,
	damageMultiplier = 1.4,
	scale = 4,
	look = {
		skin = Color3.fromRGB(15, 15, 18),
		mask = true,
		hole = true,
		longNose = true,
		maskColor = Color3.fromRGB(245, 242, 235),
		eye = Color3.fromRGB(255, 255, 255),
	},
	comboLength = 1,
	attackRange = 16,
	aggroRange = 100,
	leashRange = 160,
	reactionTime = 0.8,
	dodgeChance = 0,
	blockChance = 0,
	parryChance = 0,
	aggression = 0.5,
	superArmorAttacks = true,
	abilities = {
		{ id = "E_MenosCero", weight = 2, minRange = 20, maxRange = 100 },
		{ id = "E_Slam", weight = 1, minRange = 0, maxRange = 18 },
	},
	xp = 320,
	loot = "MenosShade",
}

-- ======================== CHEFES ========================
Enemies.Kurokage = {
	name = "Kurokage, o Devorador",
	boss = true,
	level = 9,
	health = 2600,
	walkSpeed = 17,
	damageMultiplier = 1.2,
	scale = 2,
	body = "HollowGrunt",
	look = {
		skin = Color3.fromRGB(20, 12, 30),
		mask = true,
		hole = true,
		maskColor = Color3.fromRGB(235, 230, 220),
		eye = Color3.fromRGB(170, 80, 255),
		stripes = Color3.fromRGB(150, 70, 255),
	},
	weapon = {
		style = "Claws",
		length = 1.8,
		blade = Color3.fromRGB(60, 30, 90),
		glow = Color3.fromRGB(140, 70, 255),
		bodyClaws = true,
	},
	comboLength = 4,
	attackRange = 10,
	aggroRange = 80,
	leashRange = 140,
	reactionTime = 0.3,
	dodgeChance = 0.1,
	blockChance = 0.15,
	parryChance = 0.08,
	aggression = 0.85,
	superArmorAttacks = true,
	phases = {
		{
			threshold = 1,
			title = "Kurokage desperta",
			abilities = {
				{ id = "E_Leap", weight = 2, minRange = 12, maxRange = 32 },
				{ id = "E_Slam", weight = 1, minRange = 0, maxRange = 14 },
			},
		},
		{
			threshold = 0.5,
			title = "Fase 2 — Fome Sem Fim",
			speedMultiplier = 1.2,
			damageMultiplier = 1.25,
			summon = { id = "HollowGrunt", count = 3 },
			abilities = {
				{ id = "E_Tendrils", weight = 2, minRange = 8, maxRange = 45 },
				{ id = "E_Leap", weight = 1, minRange = 12, maxRange = 32 },
				{ id = "E_Roar", weight = 1, minRange = 0, maxRange = 14 },
			},
		},
	},
	xp = 1500,
	loot = "Kurokage",
	respawn = 120,
}

Enemies.InnerHollow = {
	name = "Hollow Interior",
	boss = true,
	level = 10,
	health = 3000,
	walkSpeed = 22,
	damageMultiplier = 1.25,
	scale = 1.15,
	look = {
		skin = Color3.fromRGB(245, 245, 245),
		mask = true,
		hole = false,
		maskColor = Color3.fromRGB(250, 250, 250),
		stripes = Color3.fromRGB(200, 20, 30),
		eye = Color3.fromRGB(255, 200, 40),
		outfit = Color3.fromRGB(245, 245, 245),
	},
	weapon = { style = "Katana", length = 4.4, blade = Color3.fromRGB(20, 20, 20), glow = Color3.fromRGB(220, 30, 50) },
	comboLength = 5,
	attackRange = 7,
	aggroRange = 80,
	leashRange = 120,
	reactionTime = 0.18,
	dodgeChance = 0.3,
	blockChance = 0.2,
	parryChance = 0.2,
	aggression = 0.95,
	phases = {
		{
			threshold = 1,
			title = "Seu reflexo sorri",
			abilities = {
				{ id = "E_Sonido", weight = 2, minRange = 10, maxRange = 28 },
				{ id = "E_Crescent", weight = 1, minRange = 14, maxRange = 60 },
			},
		},
		{
			threshold = 0.45,
			title = "Fase 2 — Instinto Puro",
			speedMultiplier = 1.25,
			damageMultiplier = 1.3,
			abilities = {
				{ id = "E_Cero", weight = 2, minRange = 12, maxRange = 70 },
				{ id = "E_Sonido", weight = 2, minRange = 8, maxRange = 28 },
			},
		},
	},
	xp = 1800,
	loot = "InnerHollow",
	respawn = 60,
}

Enemies.InnerSpirit = {
	name = "Manifestação Interior",
	boss = true,
	level = 15,
	health = 4200,
	walkSpeed = 21,
	damageMultiplier = 1.35,
	scale = 1.2,
	look = {
		skin = Color3.fromRGB(60, 70, 110),
		mask = false,
		hole = false,
		outfit = Color3.fromRGB(20, 22, 35),
		eye = Color3.fromRGB(150, 210, 255),
	},
	weapon = {
		style = "Nodachi",
		length = 5.8,
		blade = Color3.fromRGB(200, 225, 255),
		glow = Color3.fromRGB(150, 210, 255),
	},
	comboLength = 5,
	attackRange = 8,
	aggroRange = 80,
	leashRange = 120,
	reactionTime = 0.2,
	dodgeChance = 0.25,
	blockChance = 0.25,
	parryChance = 0.22,
	aggression = 0.9,
	phases = {
		{
			threshold = 1,
			title = "Prove que é digno",
			abilities = {
				{ id = "E_Crescent", weight = 2, minRange = 12, maxRange = 60 },
				{ id = "E_Sonido", weight = 1, minRange = 8, maxRange = 28 },
			},
		},
		{
			threshold = 0.66,
			title = "Fase 2 — Lâmina Desperta",
			speedMultiplier = 1.15,
			damageMultiplier = 1.2,
			abilities = {
				{ id = "E_Crescent", weight = 2, minRange = 10, maxRange = 60 },
				{ id = "E_Tendrils", weight = 1, minRange = 8, maxRange = 40 },
				{ id = "E_Sonido", weight = 1, minRange = 8, maxRange = 28 },
			},
		},
		{
			threshold = 0.33,
			title = "Fase 3 — Verdadeiro Nome",
			speedMultiplier = 1.3,
			damageMultiplier = 1.4,
			abilities = {
				{ id = "E_GranCero", weight = 1, minRange = 10, maxRange = 100 },
				{ id = "E_Crescent", weight = 2, minRange = 10, maxRange = 60 },
				{ id = "E_Sonido", weight = 2, minRange = 8, maxRange = 28 },
			},
		},
	},
	xp = 2600,
	loot = "InnerSpirit",
	respawn = 60,
}

Enemies.VastoLeon = {
	name = "Leonhart, Rei do Deserto",
	boss = true,
	level = 26,
	health = 9500,
	walkSpeed = 20,
	damageMultiplier = 1.6,
	scale = 1.9,
	look = {
		skin = Color3.fromRGB(240, 230, 210),
		mask = true,
		hole = true,
		partialMask = true,
		mane = Color3.fromRGB(240, 190, 80),
		maskColor = Color3.fromRGB(250, 245, 235),
		eye = Color3.fromRGB(255, 200, 40),
		outfit = Color3.fromRGB(240, 236, 228),
	},
	weapon = {
		style = "Nodachi",
		length = 6.4,
		blade = Color3.fromRGB(240, 220, 160),
		glow = Color3.fromRGB(255, 200, 60),
	},
	comboLength = 5,
	attackRange = 10,
	aggroRange = 100,
	leashRange = 160,
	reactionTime = 0.2,
	dodgeChance = 0.2,
	blockChance = 0.25,
	parryChance = 0.18,
	aggression = 0.9,
	superArmorAttacks = true,
	phases = {
		{
			threshold = 1,
			title = "O Rei observa",
			abilities = {
				{ id = "E_Cero", weight = 2, minRange = 15, maxRange = 80 },
				{ id = "E_Sonido", weight = 1, minRange = 10, maxRange = 28 },
			},
		},
		{
			threshold = 0.6,
			title = "Fase 2 — Resurrección: Leonhart",
			speedMultiplier = 1.2,
			damageMultiplier = 1.25,
			summon = { id = "Arrancar", count = 2 },
			abilities = {
				{ id = "E_CeroBarrage", weight = 2, minRange = 10, maxRange = 80 },
				{ id = "E_Roar", weight = 1, minRange = 0, maxRange = 16 },
				{ id = "E_Sonido", weight = 1, minRange = 10, maxRange = 28 },
			},
		},
		{
			threshold = 0.25,
			title = "Fase 3 — Fúria do Rei",
			speedMultiplier = 1.35,
			damageMultiplier = 1.4,
			abilities = {
				{ id = "E_GranCero", weight = 2, minRange = 10, maxRange = 120 },
				{ id = "E_Sonido", weight = 2, minRange = 8, maxRange = 28 },
				{ id = "E_Slam", weight = 1, minRange = 0, maxRange = 16 },
			},
		},
	},
	xp = 6000,
	loot = "VastoLeon",
	respawn = 180,
}

function Enemies.get(id: string?)
	if not id then
		return nil
	end
	local def = Enemies[id]
	if type(def) == "table" and def.health then
		return def
	end
	return nil
end

return Enemies

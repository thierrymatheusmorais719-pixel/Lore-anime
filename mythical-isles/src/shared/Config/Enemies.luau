-- Inimigos comuns (não-boss). Modelos em Builders/EnemyModels (chave = id).
--
-- mover: "ground" (Humanoid + PathfindingService) | "hover" (voador, direção direta com
--        checagem de obstáculos por raycast — alternativa ao pathfinding completo)
-- detect: raio de detecção (precisa linha de visão, exceto dentro de `senseRadius`)
-- leash: distância máxima da origem antes de desistir e voltar
-- maxChase: tempo máximo de perseguição sem causar/receber dano
-- pdmg: dano base contra JOGADORES (os jogadores não escalam como os pets)
-- attack: { kind = "melee"|"lunge"|"projectile"|"slam", range, cooldown, windup, mult, radius? }

local Enemies = {}

Enemies.Info = {
	-- VERDANT HAVEN ---------------------------------------------------------
	thornling = {
		name = "Thornling", world = "verdant", level = 2, hp = 180, atk = 9, def = 6, pdmg = 8, speed = 13, mover = "ground",
		detect = 38, senseRadius = 10, leash = 70, maxChase = 14, count = 7, respawn = 18, xp = 12,
		attack = { kind = "melee", range = 6, cooldown = 1.6, windup = 0.45, mult = 1 },
	},
	wildroot_guardian = {
		name = "Wildroot Guardian", world = "verdant", level = 5, hp = 520, atk = 16, def = 18, pdmg = 14, speed = 10, mover = "ground",
		detect = 40, senseRadius = 12, leash = 70, maxChase = 14, count = 4, respawn = 30, xp = 30,
		attack = { kind = "slam", range = 9, radius = 10, cooldown = 2.6, windup = 0.9, mult = 1.3 },
	},
	briar_beast = {
		name = "Briar Beast", world = "verdant", level = 8, hp = 900, atk = 22, def = 14, pdmg = 18, speed = 16, mover = "ground",
		detect = 46, senseRadius = 12, leash = 80, maxChase = 16, count = 3, respawn = 45, xp = 55,
		attack = { kind = "lunge", range = 18, cooldown = 3.2, windup = 0.8, mult = 1.4 },
	},
	-- Terras Baixas (zonas criadas pelo WorldService junto com as ruínas e o pântano)
	bog_lurker = {
		name = "Espreitador do Pântano", world = "verdant", level = 6, hp = 440, atk = 15, def = 9, pdmg = 12, speed = 14, mover = "ground",
		detect = 40, senseRadius = 10, leash = 60, maxChase = 14, count = 6, respawn = 22, xp = 34, lowlands = true,
		attack = { kind = "melee", range = 6, cooldown = 1.5, windup = 0.45, mult = 1.1 },
		model = "thornling", tint = Color3.fromRGB(70, 150, 140),
	},
	cave_crawler = {
		name = "Rastejador Esmeralda", world = "verdant", level = 7, hp = 620, atk = 18, def = 12, pdmg = 13, speed = 15, mover = "ground",
		detect = 22, senseRadius = 10, leash = 30, maxChase = 10, count = 5, respawn = 28, xp = 48, lowlands = true,
		attack = { kind = "melee", range = 6, cooldown = 1.4, windup = 0.4, mult = 1.1 },
		model = "shard_crawler", tint = Color3.fromRGB(80, 220, 140), recolor = 0.65,
	},
	ruin_sentinel = {
		name = "Sentinela das Ruínas", world = "verdant", level = 9, hp = 1150, atk = 24, def = 24, pdmg = 18, speed = 10, mover = "ground",
		detect = 42, senseRadius = 12, leash = 60, maxChase = 14, count = 4, respawn = 40, xp = 70, lowlands = true,
		attack = { kind = "slam", range = 9, radius = 10, cooldown = 2.8, windup = 0.9, mult = 1.35 },
		model = "wildroot_guardian", tint = Color3.fromRGB(150, 150, 165), recolor = 0.6,
	},

	-- CRYSTAL HOLLOW --------------------------------------------------------
	shard_crawler = {
		name = "Shard Crawler", world = "crystal", level = 12, hp = 1300, atk = 30, def = 24, pdmg = 12, speed = 17, mover = "ground",
		detect = 40, senseRadius = 12, leash = 70, maxChase = 14, count = 7, respawn = 20, xp = 70,
		attack = { kind = "melee", range = 6, cooldown = 1.4, windup = 0.4, mult = 1 },
	},
	prism_golem = {
		name = "Prism Golem", world = "crystal", level = 15, hp = 3000, atk = 42, def = 50, pdmg = 20, speed = 9, mover = "ground",
		detect = 40, senseRadius = 12, leash = 65, maxChase = 14, count = 4, respawn = 35, xp = 120,
		attack = { kind = "slam", range = 10, radius = 11, cooldown = 2.8, windup = 1.0, mult = 1.3 },
	},
	crystal_devourer = {
		name = "Crystal Devourer", world = "crystal", level = 18, hp = 3800, atk = 55, def = 36, pdmg = 24, speed = 12, mover = "ground",
		detect = 44, senseRadius = 14, leash = 60, maxChase = 15, count = 2, respawn = 60, xp = 220,
		attack = { kind = "projectile", range = 34, cooldown = 3.0, windup = 0.9, mult = 1.3 },
	},

	-- SKYBOUND KINGDOM ------------------------------------------------------
	storm_sprite = {
		name = "Storm Sprite", world = "sky", level = 22, hp = 4200, atk = 70, def = 40, pdmg = 16, speed = 18, mover = "hover", hoverHeight = 9,
		detect = 44, senseRadius = 12, leash = 75, maxChase = 14, count = 7, respawn = 20, xp = 260,
		attack = { kind = "projectile", range = 32, cooldown = 2.2, windup = 0.6, mult = 1 },
	},
	cloud_stalker = {
		name = "Cloud Stalker", world = "sky", level = 25, hp = 7500, atk = 95, def = 55, pdmg = 24, speed = 19, mover = "ground",
		detect = 48, senseRadius = 14, leash = 80, maxChase = 16, count = 4, respawn = 35, xp = 420,
		attack = { kind = "lunge", range = 20, cooldown = 3.0, windup = 0.75, mult = 1.4 },
	},
	tempest_guardian = {
		name = "Tempest Guardian", world = "sky", level = 28, hp = 9000, atk = 120, def = 80, pdmg = 30, speed = 10, mover = "ground",
		detect = 42, senseRadius = 14, leash = 60, maxChase = 15, count = 2, respawn = 60, xp = 700,
		attack = { kind = "slam", range = 11, radius = 13, cooldown = 3.0, windup = 1.1, mult = 1.35 },
	},

	-- WHISPERING WILDS ------------------------------------------------------
	mist_prowler = {
		name = "Mist Prowler", world = "wilds", level = 32, hp = 9000, atk = 150, def = 70, pdmg = 20, speed = 20, mover = "ground",
		detect = 30, senseRadius = 10, leash = 80, maxChase = 16, count = 6, respawn = 22, xp = 900, stealthy = true,
		attack = { kind = "lunge", range = 16, cooldown = 2.6, windup = 0.6, mult = 1.3 },
	},
	hollow_stag = {
		name = "Hollow Stag", world = "wilds", level = 35, hp = 14000, atk = 190, def = 110, pdmg = 28, speed = 15, mover = "ground",
		detect = 46, senseRadius = 14, leash = 75, maxChase = 15, count = 4, respawn = 40, xp = 1400,
		attack = { kind = "lunge", range = 22, cooldown = 3.2, windup = 0.9, mult = 1.4 },
	},
	ancient_bloom_beast = {
		name = "Ancient Bloom Beast", world = "wilds", level = 38, hp = 22000, atk = 240, def = 120, pdmg = 34, speed = 9, mover = "ground",
		detect = 44, senseRadius = 16, leash = 60, maxChase = 15, count = 2, respawn = 70, xp = 2400,
		attack = { kind = "slam", range = 12, radius = 15, cooldown = 3.2, windup = 1.2, mult = 1.35 },
	},

	-- ASTRAL SANCTUARY ------------------------------------------------------
	astral_sentinel = {
		name = "Astral Sentinel", world = "astral", level = 42, hp = 15000, atk = 320, def = 110, pdmg = 24, speed = 13, mover = "hover", hoverHeight = 5,
		detect = 50, senseRadius = 16, leash = 70, maxChase = 15, count = 6, respawn = 30, xp = 3200,
		attack = { kind = "projectile", range = 36, cooldown = 2.4, windup = 0.7, mult = 1.1 },
	},
	rift_keeper = {
		name = "Rift Keeper", world = "astral", level = 46, hp = 26000, atk = 420, def = 140, pdmg = 34, speed = 12, mover = "ground",
		detect = 46, senseRadius = 16, leash = 65, maxChase = 15, count = 4, respawn = 45, xp = 5200,
		attack = { kind = "slam", range = 12, radius = 14, cooldown = 3.0, windup = 1.1, mult = 1.35 },
	},

	-- Invocações / evento (não aparecem nos spawns normais) --------------------
	wilderbloom_sprout = {
		name = "Bloomling Sprout", world = "wilds", level = 34, hp = 3000, atk = 110, def = 50, pdmg = 16, speed = 16, mover = "ground",
		detect = 80, senseRadius = 80, leash = 90, maxChase = 60, count = 0, respawn = 0, xp = 60, summon = true,
		attack = { kind = "melee", range = 6, cooldown = 1.6, windup = 0.45, mult = 1 },
		model = "thornling", tint = Color3.fromRGB(200, 120, 220),
	},
	wandering_star = {
		name = "Estrela Errante", world = "any", level = 1, hp = 1, atk = 0, def = 0, pdmg = 0, speed = 14, mover = "hover", hoverHeight = 6,
		detect = 0, senseRadius = 0, leash = 40, maxChase = 0, count = 0, respawn = 0, xp = 0, passive = true, hpScaleByWorld = 2500,
		attack = { kind = "melee", range = 0, cooldown = 99, windup = 0, mult = 0 },
	},
}

-- Ticks e limites de IA (aplicados a todos).
Enemies.AI = {
	tickRate = 0.15, -- s entre decisões
	pathRecompute = 1.2, -- s mínimos entre recomputar caminho
	stuckTime = 2.0, -- s sem progresso => tenta pular / recalcular / desiste
	investigateTime = 4.0,
	recoverTime = 0.6, -- s após um ataque antes de voltar a perseguir
	returnHealRate = 0.25, -- fração da vida por segundo enquanto retorna
	idleMin = 2, idleMax = 5,
	patrolRadius = 22,
	maxAttackRangeSlack = 1.5, -- folga máxima do servidor para validar alcance
}

return Enemies

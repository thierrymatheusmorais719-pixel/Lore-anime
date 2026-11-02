-- Bosses. Cada um tem arena própria (WorldService constrói), fases e ataques telegrafados.
--
-- Os ataques usam as MESMAS formas para o indicador visual e para o teste de acerto
-- (Logic/AttackShapes), então o que aparece no chão é exatamente o que causa dano.
--
-- shape:
--   slam          círculo centrado no boss (radius)
--   target_circles um círculo em cada jogador da arena (radius, max)
--   random_circles n círculos aleatórios na arena (count, radius)
--   ring          anel ao redor do boss (inner, outer) — fique PERTO ou LONGE
--   cone          cone à frente do boss na direção do alvo (angle em graus, length)
--   line          retângulo do boss até o alvo (width, length)
--   cross         duas linhas perpendiculares passando pelo boss (width, length)
--   safezones     arena inteira EXCETO `count` círculos seguros (radius)
--   summon        invoca inimigos (enemy, count) — sem dano direto
-- telegraph: segundos de aviso antes do impacto
-- pdmg: dano em jogadores; petMult: multiplicador do ataque do boss contra pets

local Bosses = {}

Bosses.Info = {
	elderroot = {
		name = "Elderroot", title = "O Guardião Verde", world = "verdant", level = 10,
		hp = 12000, atk = 30, def = 20, scale = 1, respawn = 120, arenaRadius = 70,
		color = Color3.fromRGB(120, 200, 90),
		phases = {
			{ at = 1.0, label = "Despertar", interval = 3.4, attacks = { "root_slam", "root_lines", "root_burst" } },
			{ at = 0.6, label = "Fúria das Raízes", interval = 2.8, attacks = { "root_slam", "root_lines", "root_burst", "root_ring" } },
			{ at = 0.3, label = "Coração da Floresta", interval = 2.3, attacks = { "root_lines", "root_ring", "root_burst", "canopy_fall" } },
		},
		attacks = {
			root_slam = { label = "Golpe de Raiz", shape = "slam", radius = 18, telegraph = 1.4, pdmg = 22, petMult = 1.4, anim = "slam" },
			root_lines = { label = "Raízes Perfurantes", shape = "line", width = 9, length = 60, telegraph = 1.3, pdmg = 18, petMult = 1.2, anim = "sweep" },
			root_burst = { label = "Explosão de Raízes", shape = "target_circles", radius = 9, max = 6, telegraph = 1.5, pdmg = 16, petMult = 1.1, anim = "cast" },
			root_ring = { label = "Onda de Impacto", shape = "ring", inner = 16, outer = 38, telegraph = 1.6, pdmg = 24, petMult = 1.3, anim = "roar" },
			canopy_fall = { label = "Queda da Copa", shape = "random_circles", count = 9, radius = 10, telegraph = 1.8, pdmg = 26, petMult = 1.4, anim = "roar" },
		},
		loot = "elderroot",
	},
	prism_titan = {
		name = "Prism Titan", title = "O Colosso Cristalino", world = "crystal", level = 20,
		hp = 18000, atk = 60, def = 45, scale = 1, respawn = 150, arenaRadius = 72,
		color = Color3.fromRGB(150, 220, 255),
		phases = {
			{ at = 1.0, label = "Ressonância", interval = 3.2, attacks = { "crystal_slam", "prism_beam", "shard_rain" } },
			{ at = 0.55, label = "Refração", interval = 2.6, attacks = { "crystal_slam", "prism_cross", "shard_rain", "prism_beam" } },
			{ at = 0.25, label = "Sobrecarga", interval = 2.1, attacks = { "prism_cross", "energy_wave", "shard_rain", "prism_beam" }, speedMult = 1.25 },
		},
		attacks = {
			crystal_slam = { label = "Punho de Cristal", shape = "slam", radius = 17, telegraph = 1.4, pdmg = 24, petMult = 1.4, anim = "slam" },
			prism_beam = { label = "Feixe Prismático", shape = "line", width = 10, length = 70, telegraph = 1.3, pdmg = 22, petMult = 1.3, anim = "breath" },
			prism_cross = { label = "Cruz de Luz", shape = "cross", width = 9, length = 70, telegraph = 1.5, pdmg = 24, petMult = 1.3, anim = "cast" },
			shard_rain = { label = "Chuva de Estilhaços", shape = "target_circles", radius = 8, max = 6, telegraph = 1.4, pdmg = 18, petMult = 1.1, anim = "cast" },
			energy_wave = { label = "Onda de Energia", shape = "ring", inner = 14, outer = 42, telegraph = 1.6, pdmg = 28, petMult = 1.4, anim = "roar" },
		},
		loot = "prism_titan",
	},
	tempest_wyrm = {
		name = "Tempest Wyrm", title = "Serpe das Ilhas Celestes", world = "sky", level = 30,
		hp = 36000, atk = 130, def = 70, scale = 1, respawn = 180, arenaRadius = 76, flying = true,
		color = Color3.fromRGB(120, 170, 255),
		phases = {
			{ at = 1.0, label = "Céu Aberto", interval = 3.0, attacks = { "gale_breath", "tail_sweep", "lightning_marks" } },
			{ at = 0.65, label = "Voo da Tempestade", interval = 2.6, airborne = true, attacks = { "dive_line", "lightning_marks", "storm_field" } },
			{ at = 0.3, label = "Olho do Furacão", interval = 2.2, attacks = { "gale_breath", "cyclone_ring", "dive_line", "lightning_marks" }, speedMult = 1.2 },
		},
		attacks = {
			gale_breath = { label = "Sopro de Vendaval", shape = "cone", angle = 55, length = 50, telegraph = 1.3, pdmg = 24, petMult = 1.3, anim = "breath" },
			tail_sweep = { label = "Varrida de Cauda", shape = "slam", radius = 18, telegraph = 1.3, pdmg = 22, petMult = 1.3, anim = "sweep" },
			lightning_marks = { label = "Marcas de Relâmpago", shape = "target_circles", radius = 8, max = 6, telegraph = 1.4, pdmg = 20, petMult = 1.2, anim = "cast" },
			dive_line = { label = "Mergulho", shape = "line", width = 12, length = 80, telegraph = 1.5, pdmg = 28, petMult = 1.4, anim = "dive" },
			storm_field = { label = "Campo de Tempestade", shape = "random_circles", count = 10, radius = 9, telegraph = 1.7, pdmg = 24, petMult = 1.3, anim = "roar" },
			cyclone_ring = { label = "Ciclone", shape = "ring", inner = 15, outer = 44, telegraph = 1.6, pdmg = 30, petMult = 1.4, anim = "roar" },
		},
		loot = "tempest_wyrm",
	},
	wilderbloom = {
		name = "The Wilderbloom", title = "Guardiã da Floresta Encantada", world = "wilds", level = 40,
		hp = 50000, atk = 220, def = 90, scale = 1, respawn = 200, arenaRadius = 74,
		color = Color3.fromRGB(200, 130, 255),
		phases = {
			{ at = 1.0, label = "Desabrochar", interval = 3.0, attacks = { "petal_cone", "spore_marks", "summon_sprouts" } },
			{ at = 0.6, label = "Jardim Selvagem", interval = 2.6, attacks = { "petal_cone", "thorn_cross", "spore_marks", "summon_sprouts" } },
			{ at = 0.3, label = "Floração Final", interval = 2.2, attacks = { "pollen_storm", "thorn_cross", "spore_marks", "summon_sprouts" } },
		},
		attacks = {
			petal_cone = { label = "Leque de Pétalas", shape = "cone", angle = 70, length = 46, telegraph = 1.3, pdmg = 24, petMult = 1.3, anim = "sweep" },
			spore_marks = { label = "Esporos Explosivos", shape = "target_circles", radius = 9, max = 6, telegraph = 1.5, pdmg = 22, petMult = 1.2, anim = "cast" },
			thorn_cross = { label = "Cruz de Espinhos", shape = "cross", width = 10, length = 70, telegraph = 1.5, pdmg = 26, petMult = 1.3, anim = "slam" },
			pollen_storm = { label = "Tempestade de Pólen", shape = "safezones", count = 3, radius = 11, telegraph = 2.4, pdmg = 34, petMult = 1.5, anim = "roar" },
			summon_sprouts = { label = "Invocar Brotos", shape = "summon", enemy = "wilderbloom_sprout", count = 3, maxAlive = 6, telegraph = 1.0, pdmg = 0, petMult = 0, anim = "roar" },
		},
		loot = "wilderbloom",
	},
	void_sovereign = {
		name = "Void Sovereign", title = "Soberano do Vazio", world = "astral", level = 50,
		hp = 100000, atk = 380, def = 120, scale = 1, respawn = 240, arenaRadius = 80,
		color = Color3.fromRGB(150, 100, 255),
		phases = {
			{ at = 1.0, label = "Coroa do Vazio", interval = 2.9, attacks = { "void_slam", "rift_lines", "star_marks" } },
			{ at = 0.7, label = "Eclipse", interval = 2.5, attacks = { "void_cross", "rift_lines", "star_marks", "event_ring" } },
			{ at = 0.4, label = "Colapso", interval = 2.2, attacks = { "void_cross", "meteor_field", "event_ring", "star_marks" }, speedMult = 1.15 },
			{ at = 0.15, label = "Singularidade", interval = 2.0, attacks = { "void_collapse", "void_cross", "meteor_field", "star_marks" }, speedMult = 1.25 },
		},
		attacks = {
			void_slam = { label = "Impacto do Vazio", shape = "slam", radius = 19, telegraph = 1.4, pdmg = 26, petMult = 1.4, anim = "slam" },
			rift_lines = { label = "Fendas", shape = "line", width = 10, length = 80, telegraph = 1.3, pdmg = 24, petMult = 1.3, anim = "sweep" },
			star_marks = { label = "Marcas Estelares", shape = "target_circles", radius = 9, max = 6, telegraph = 1.4, pdmg = 22, petMult = 1.2, anim = "cast" },
			void_cross = { label = "Cruz do Vazio", shape = "cross", width = 11, length = 80, telegraph = 1.5, pdmg = 28, petMult = 1.4, anim = "cast" },
			event_ring = { label = "Horizonte de Eventos", shape = "ring", inner = 16, outer = 46, telegraph = 1.6, pdmg = 30, petMult = 1.4, anim = "roar" },
			meteor_field = { label = "Campo de Meteoros", shape = "random_circles", count = 12, radius = 9, telegraph = 1.8, pdmg = 28, petMult = 1.4, anim = "roar" },
			void_collapse = { label = "Colapso Total", shape = "safezones", count = 3, radius = 10, telegraph = 2.6, pdmg = 45, petMult = 1.6, anim = "roar" },
		},
		loot = "void_sovereign",
	},
}

-- Regras gerais de encontro.
Bosses.Rules = {
	introTime = 3.0, -- animação de entrada (invulnerável)
	phaseTransitionTime = 2.5, -- invulnerável durante a transição
	resetAfterEmpty = 15, -- s sem participantes na arena => boss reseta
	hpScalePerExtraPlayer = 0.6, -- +60% de vida por jogador extra no início do combate
	hpScaleMaxPlayers = 6,
	enrageAfter = 360, -- s: depois disso o intervalo entre ataques cai 30%
}

return Bosses

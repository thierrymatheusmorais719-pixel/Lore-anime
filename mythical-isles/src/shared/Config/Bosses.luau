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
--   fan           `count` linhas em leque saindo do boss (spread em graus entre elas)
--   power         PODER do boss (sem dano direto): veja `power` abaixo
-- telegraph: segundos de aviso antes do impacto (no poder: tempo de conjuração)
-- pdmg: dano em jogadores; petMult: multiplicador do ataque do boss contra pets
--
-- MECÂNICAS PRÓPRIAS (Services/BossPowers):
--   effect = { root = s }              prende quem foi atingido (jogador parado, pet sem atacar)
--   effect = { slow = 0..1, slowTime } deixa o jogador lento
--   effect = { drain = true }          zera a energia e a Fúria dos pets atingidos
--   effect = { chain = { n, range, mult } } o raio pula para outros `n` pets perto de cada pet atingido
--   linger = { duration, tick, pdmg, petMult, slow?, label, color }  a área fica no chão causando dano
--   power  = "bark"   reduz o dano recebido em `amount` por `duration` s
--            "mirror" devolve `amount` do dano de cada golpe de pet ao pet
--            "static" cada golpe de pet recebe um choque (ataque do boss × `amount`)
--            "bloom"  cura `base` + `perSummon` da vida máx. por broto vivo
--            "drain"  cura `amount` de todo dano que os ataques do boss causarem, por `duration` s
--   cooldown: segundos mínimos entre dois usos do mesmo poder

local Bosses = {}

Bosses.Info = {
	elderroot = {
		name = "Elderroot", title = "O Guardião Verde", world = "verdant", level = 10,
		hp = 12000, atk = 30, def = 20, scale = 1, respawn = 120, arenaRadius = 70,
		color = Color3.fromRGB(120, 200, 90),
		phases = {
			{ at = 1.0, label = "Despertar", interval = 3.4, attacks = { "root_slam", "root_lines", "root_burst", "thorn_prison" } },
			{ at = 0.6, label = "Fúria das Raízes", interval = 2.8, attacks = { "root_slam", "root_lines", "thorn_prison", "root_ring", "ancient_bark" } },
			{ at = 0.3, label = "Coração da Floresta", interval = 2.3, attacks = { "root_lines", "root_ring", "thorn_prison", "canopy_fall", "ancient_bark" } },
		},
		attacks = {
			root_slam = { label = "Golpe de Raiz", shape = "slam", radius = 18, telegraph = 1.4, pdmg = 22, petMult = 1.4, anim = "slam" },
			root_lines = { label = "Raízes Perfurantes", shape = "line", width = 9, length = 60, telegraph = 1.3, pdmg = 18, petMult = 1.2, anim = "sweep" },
			root_burst = { label = "Explosão de Raízes", shape = "target_circles", radius = 9, max = 6, telegraph = 1.5, pdmg = 16, petMult = 1.1, anim = "cast" },
			root_ring = { label = "Onda de Impacto", shape = "ring", inner = 16, outer = 38, telegraph = 1.6, pdmg = 24, petMult = 1.3, anim = "roar" },
			canopy_fall = { label = "Queda da Copa", shape = "random_circles", count = 9, radius = 10, telegraph = 1.8, pdmg = 26, petMult = 1.4, anim = "roar" },
			-- próprios: prende e deixa um campo de espinhos; casca de carvalho que corta o dano
			thorn_prison = { label = "Prisão de Espinhos", shape = "target_circles", radius = 7, max = 6, telegraph = 1.4, pdmg = 12, petMult = 0.8, anim = "cast",
				effect = { root = 2.0 }, linger = { duration = 4, tick = 0.6, pdmg = 5, petMult = 0.35, label = "Espinhos", color = Color3.fromRGB(120, 90, 50) } },
			ancient_bark = { label = "Casca Ancestral", shape = "power", power = "bark", amount = 0.55, duration = 6, cooldown = 18, telegraph = 0.9, anim = "roar",
				desc = "Dano recebido −55% por 6 s" },
		},
		loot = "elderroot",
	},
	prism_titan = {
		name = "Prism Titan", title = "O Colosso Cristalino", world = "crystal", level = 20,
		hp = 18000, atk = 60, def = 45, scale = 1, respawn = 150, arenaRadius = 72,
		color = Color3.fromRGB(150, 220, 255),
		phases = {
			{ at = 1.0, label = "Ressonância", interval = 3.2, attacks = { "crystal_slam", "prism_beam", "shard_rain", "prism_split" } },
			{ at = 0.55, label = "Refração", interval = 2.6, attacks = { "crystal_slam", "prism_cross", "shard_rain", "prism_split", "prism_mirror" } },
			{ at = 0.25, label = "Sobrecarga", interval = 2.1, attacks = { "prism_cross", "energy_wave", "prism_split", "prism_beam", "prism_mirror" }, speedMult = 1.25 },
		},
		attacks = {
			crystal_slam = { label = "Punho de Cristal", shape = "slam", radius = 17, telegraph = 1.4, pdmg = 24, petMult = 1.4, anim = "slam" },
			prism_beam = { label = "Feixe Prismático", shape = "line", width = 10, length = 70, telegraph = 1.3, pdmg = 22, petMult = 1.3, anim = "breath" },
			prism_cross = { label = "Cruz de Luz", shape = "cross", width = 9, length = 70, telegraph = 1.5, pdmg = 24, petMult = 1.3, anim = "cast" },
			shard_rain = { label = "Chuva de Estilhaços", shape = "target_circles", radius = 8, max = 6, telegraph = 1.4, pdmg = 18, petMult = 1.1, anim = "cast",
				effect = { slow = 0.45, slowTime = 3 } }, -- os estilhaços cristalizam os pés: lentidão
			energy_wave = { label = "Onda de Energia", shape = "ring", inner = 14, outer = 42, telegraph = 1.6, pdmg = 28, petMult = 1.4, anim = "roar" },
			-- próprios: o feixe se divide em leque; espelho que devolve o dano dos pets
			prism_split = { label = "Refração Tripla", shape = "fan", count = 3, spread = 28, width = 8, length = 66, telegraph = 1.4, pdmg = 22, petMult = 1.25, anim = "breath" },
			prism_mirror = { label = "Espelho Prismático", shape = "power", power = "mirror", amount = 0.3, duration = 6, cooldown = 20, telegraph = 0.9, anim = "cast",
				desc = "Devolve 30% do dano dos pets por 6 s" },
		},
		loot = "prism_titan",
	},
	tempest_wyrm = {
		name = "Tempest Wyrm", title = "Serpe das Ilhas Celestes", world = "sky", level = 30,
		hp = 36000, atk = 130, def = 70, scale = 1, respawn = 180, arenaRadius = 76, flying = true, electric = true,
		color = Color3.fromRGB(120, 170, 255),
		phases = {
			{ at = 1.0, label = "Céu Aberto", interval = 3.0, attacks = { "gale_breath", "tail_sweep", "lightning_marks", "storm_cells" } },
			{ at = 0.65, label = "Voo da Tempestade", interval = 2.6, airborne = true, attacks = { "dive_line", "lightning_marks", "storm_field", "storm_cells", "static_charge" } },
			{ at = 0.3, label = "Olho do Furacão", interval = 2.2, attacks = { "gale_breath", "cyclone_ring", "dive_line", "lightning_marks", "static_charge" }, speedMult = 1.2 },
		},
		attacks = {
			gale_breath = { label = "Sopro de Vendaval", shape = "cone", angle = 55, length = 50, telegraph = 1.3, pdmg = 24, petMult = 1.3, anim = "breath" },
			tail_sweep = { label = "Varrida de Cauda", shape = "slam", radius = 18, telegraph = 1.3, pdmg = 22, petMult = 1.3, anim = "sweep" },
			lightning_marks = { label = "Marcas de Relâmpago", shape = "target_circles", radius = 8, max = 6, telegraph = 1.4, pdmg = 20, petMult = 1.2, anim = "cast",
				effect = { chain = { n = 2, range = 16, mult = 0.7 } } }, -- o raio pula para pets próximos
			dive_line = { label = "Mergulho", shape = "line", width = 12, length = 80, telegraph = 1.5, pdmg = 28, petMult = 1.4, anim = "dive" },
			storm_field = { label = "Campo de Tempestade", shape = "random_circles", count = 10, radius = 9, telegraph = 1.7, pdmg = 24, petMult = 1.3, anim = "roar" },
			cyclone_ring = { label = "Ciclone", shape = "ring", inner = 15, outer = 44, telegraph = 1.6, pdmg = 30, petMult = 1.4, anim = "roar" },
			-- próprios: nuvens de tempestade que ficam soltando raios; carga estática que dá choque em quem bate
			storm_cells = { label = "Células de Tempestade", shape = "random_circles", count = 5, radius = 8, telegraph = 1.5, pdmg = 14, petMult = 0.9, anim = "cast",
				linger = { duration = 5, tick = 0.8, pdmg = 8, petMult = 0.5, label = "Tempestade", color = Color3.fromRGB(120, 170, 255) } },
			static_charge = { label = "Carga Estática", shape = "power", power = "static", amount = 0.6, duration = 7, cooldown = 18, telegraph = 0.8, anim = "roar",
				desc = "Pets que baterem levam choque por 7 s" },
		},
		loot = "tempest_wyrm",
	},
	wilderbloom = {
		name = "The Wilderbloom", title = "Guardiã da Floresta Encantada", world = "wilds", level = 40,
		hp = 50000, atk = 220, def = 90, scale = 1, respawn = 200, arenaRadius = 74,
		color = Color3.fromRGB(200, 130, 255),
		phases = {
			{ at = 1.0, label = "Desabrochar", interval = 3.0, attacks = { "petal_cone", "spore_marks", "summon_sprouts", "vine_snare" } },
			{ at = 0.6, label = "Jardim Selvagem", interval = 2.6, attacks = { "petal_cone", "thorn_cross", "spore_marks", "summon_sprouts", "vine_snare", "rebloom" } },
			{ at = 0.3, label = "Floração Final", interval = 2.2, attacks = { "pollen_storm", "thorn_cross", "spore_marks", "summon_sprouts", "rebloom" } },
		},
		attacks = {
			petal_cone = { label = "Leque de Pétalas", shape = "cone", angle = 70, length = 46, telegraph = 1.3, pdmg = 24, petMult = 1.3, anim = "sweep" },
			spore_marks = { label = "Esporos Explosivos", shape = "target_circles", radius = 9, max = 6, telegraph = 1.5, pdmg = 22, petMult = 1.2, anim = "cast",
				linger = { duration = 5, tick = 0.5, pdmg = 6, petMult = 0.35, slow = 0.3, label = "Veneno", color = Color3.fromRGB(170, 90, 220) } }, -- poça de veneno
			thorn_cross = { label = "Cruz de Espinhos", shape = "cross", width = 10, length = 70, telegraph = 1.5, pdmg = 26, petMult = 1.3, anim = "slam" },
			pollen_storm = { label = "Tempestade de Pólen", shape = "safezones", count = 3, radius = 11, telegraph = 2.4, pdmg = 34, petMult = 1.5, anim = "roar" },
			summon_sprouts = { label = "Invocar Brotos", shape = "summon", enemy = "wilderbloom_sprout", count = 3, maxAlive = 6, telegraph = 1.0, pdmg = 0, petMult = 0, anim = "roar" },
			-- próprios: vinhas que puxam e prendem; florescer que cura mais com brotos vivos
			vine_snare = { label = "Laço de Vinhas", shape = "cone", angle = 50, length = 40, telegraph = 1.3, pdmg = 16, petMult = 1.0, anim = "sweep", effect = { root = 1.6 } },
			rebloom = { label = "Florescer", shape = "power", power = "bloom", base = 0.03, perSummon = 0.015, cooldown = 16, telegraph = 1.2, anim = "roar",
				desc = "Cura 3% (+1,5% por broto vivo): derrube os brotos!" },
		},
		loot = "wilderbloom",
	},
	void_sovereign = {
		name = "Void Sovereign", title = "Soberano do Vazio", world = "astral", level = 50,
		hp = 100000, atk = 380, def = 120, scale = 1, respawn = 240, arenaRadius = 80,
		color = Color3.fromRGB(150, 100, 255),
		phases = {
			{ at = 1.0, label = "Coroa do Vazio", interval = 2.9, attacks = { "void_slam", "rift_lines", "star_marks", "black_hole" } },
			{ at = 0.7, label = "Eclipse", interval = 2.5, attacks = { "void_cross", "rift_lines", "star_marks", "event_ring", "black_hole", "void_hunger" } },
			{ at = 0.4, label = "Colapso", interval = 2.2, attacks = { "void_cross", "meteor_field", "event_ring", "black_hole", "void_hunger" }, speedMult = 1.15 },
			{ at = 0.15, label = "Singularidade", interval = 2.0, attacks = { "void_collapse", "void_cross", "meteor_field", "black_hole", "void_hunger" }, speedMult = 1.25 },
		},
		attacks = {
			void_slam = { label = "Impacto do Vazio", shape = "slam", radius = 19, telegraph = 1.4, pdmg = 26, petMult = 1.4, anim = "slam" },
			rift_lines = { label = "Fendas", shape = "line", width = 10, length = 80, telegraph = 1.3, pdmg = 24, petMult = 1.3, anim = "sweep",
				effect = { drain = true } }, -- a fenda suga a energia e a Fúria dos pets
			star_marks = { label = "Marcas Estelares", shape = "target_circles", radius = 9, max = 6, telegraph = 1.4, pdmg = 22, petMult = 1.2, anim = "cast" },
			void_cross = { label = "Cruz do Vazio", shape = "cross", width = 11, length = 80, telegraph = 1.5, pdmg = 28, petMult = 1.4, anim = "cast" },
			event_ring = { label = "Horizonte de Eventos", shape = "ring", inner = 16, outer = 46, telegraph = 1.6, pdmg = 30, petMult = 1.4, anim = "roar" },
			meteor_field = { label = "Campo de Meteoros", shape = "random_circles", count = 12, radius = 9, telegraph = 1.8, pdmg = 28, petMult = 1.4, anim = "roar" },
			void_collapse = { label = "Colapso Total", shape = "safezones", count = 3, radius = 10, telegraph = 2.6, pdmg = 45, petMult = 1.6, anim = "roar" },
			-- próprios: buraco negro que fica no chão e prende quem entra; fome do vazio que rouba vida
			black_hole = { label = "Buraco Negro", shape = "target_circles", radius = 10, max = 2, telegraph = 1.6, pdmg = 20, petMult = 1.1, anim = "cast",
				linger = { duration = 5, tick = 0.5, pdmg = 9, petMult = 0.5, slow = 0.6, label = "Singularidade", color = Color3.fromRGB(90, 40, 170) } },
			void_hunger = { label = "Fome do Vazio", shape = "power", power = "drain", amount = 0.4, duration = 8, cooldown = 20, telegraph = 1.0, anim = "roar",
				desc = "Cura 40% do dano que causar por 8 s" },
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

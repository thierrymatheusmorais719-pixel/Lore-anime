-- Ovos. `weight` são as chances BASE em porcentagem (soma 100 por ovo).
-- As chances finais (com sorte) são calculadas por Logic/LuckLogic.applyWeighted e
-- exibidas na interface exatamente como o servidor as usa.
--
-- currency: "coins" | "essence" | "item" (ovos especiais ficam no inventário e são chocados de graça)
-- condition (opcional por entrada): regra extra que precisa ser cumprida para a entrada existir.
--   { minSpeciesDiscovered = n }  -> espécies diferentes no bestiário
--   { bossDefeated = "id" }       -> precisa ter derrotado o boss
-- Entradas cuja condição não foi cumprida saem do sorteio (chance 0, mostrada com o motivo).

local Eggs = {}

Eggs.Info = {
	verdant_egg = {
		name = "Ovo do Bosque", world = "verdant", currency = "coins", cost = 100,
		color = Color3.fromRGB(150, 210, 110), spot = Color3.fromRGB(240, 230, 150),
		entries = {
			{ species = "mossling", weight = 60 },
			{ species = "leafwing", weight = 27 },
			{ species = "thornpup", weight = 9.5 },
			{ species = "bloomfox", weight = 3 },
			{ species = "grovekin", weight = 0.48 },
			{ species = "verdigris_wisp", weight = 0.02 },
		},
	},
	grove_egg = {
		name = "Ovo de Raiz Antiga", world = "verdant", currency = "essence", cost = 60,
		color = Color3.fromRGB(110, 80, 50), spot = Color3.fromRGB(160, 240, 120),
		entries = {
			{ species = "thornpup", weight = 62 },
			{ species = "bloomfox", weight = 30 },
			{ species = "grovekin", weight = 7.9 },
			{ species = "verdigris_wisp", weight = 0.1 },
		},
	},
	crystal_egg = {
		name = "Ovo de Quartzo", world = "crystal", currency = "coins", cost = 900,
		color = Color3.fromRGB(150, 210, 255), spot = Color3.fromRGB(200, 150, 255),
		entries = {
			{ species = "shardmite", weight = 60 },
			{ species = "glimmerbat", weight = 27 },
			{ species = "geodeling", weight = 9.5 },
			{ species = "prismcat", weight = 3 },
			{ species = "quartz_drake", weight = 0.48 },
			{ species = "echo_geode", weight = 0.02 },
		},
	},
	geode_egg = {
		name = "Ovo Geodo", world = "crystal", currency = "essence", cost = 180,
		color = Color3.fromRGB(90, 70, 120), spot = Color3.fromRGB(190, 120, 255),
		entries = {
			{ species = "geodeling", weight = 62 },
			{ species = "prismcat", weight = 30 },
			{ species = "quartz_drake", weight = 7.9 },
			{ species = "echo_geode", weight = 0.1 },
		},
	},
	sky_egg = {
		name = "Ovo de Nuvem", world = "sky", currency = "coins", cost = 6000,
		color = Color3.fromRGB(240, 245, 255), spot = Color3.fromRGB(150, 200, 255),
		entries = {
			{ species = "puffcloud", weight = 60 },
			{ species = "galepup", weight = 27 },
			{ species = "zephyr_hawk", weight = 9.5 },
			{ species = "thunder_ram", weight = 3 },
			{ species = "aurora_griffin", weight = 0.48 },
			{ species = "skyborn_seraph", weight = 0.02 },
		},
	},
	storm_egg = {
		name = "Ovo da Tempestade", world = "sky", currency = "essence", cost = 450,
		color = Color3.fromRGB(80, 90, 130), spot = Color3.fromRGB(255, 230, 90),
		entries = {
			{ species = "zephyr_hawk", weight = 62 },
			{ species = "thunder_ram", weight = 30 },
			{ species = "aurora_griffin", weight = 7.9 },
			{ species = "skyborn_seraph", weight = 0.1 },
		},
	},
	wilds_egg = {
		name = "Ovo do Musgo Sussurrante", world = "wilds", currency = "coins", cost = 30000,
		color = Color3.fromRGB(80, 120, 90), spot = Color3.fromRGB(180, 150, 255),
		entries = {
			{ species = "mistmoth", weight = 58 },
			{ species = "hollow_hare", weight = 28 },
			{ species = "fernsnake", weight = 10 },
			{ species = "dusk_lynx", weight = 3.3 },
			{ species = "elder_owl", weight = 0.6 },
			{ species = "moonveil_kitsune", weight = 0.08 },
			{ species = "whisper_shade", weight = 0.02 },
		},
	},
	moon_egg = {
		name = "Ovo do Luar", world = "wilds", currency = "essence", cost = 1100,
		color = Color3.fromRGB(220, 220, 255), spot = Color3.fromRGB(150, 110, 255),
		entries = {
			{ species = "fernsnake", weight = 60 },
			{ species = "dusk_lynx", weight = 30 },
			{ species = "elder_owl", weight = 9 },
			{ species = "moonveil_kitsune", weight = 0.9 },
			{ species = "whisper_shade", weight = 0.1 },
		},
	},
	astral_egg = {
		name = "Ovo Astral", world = "astral", currency = "coins", cost = 120000,
		color = Color3.fromRGB(60, 50, 120), spot = Color3.fromRGB(255, 220, 140),
		entries = {
			{ species = "stardust_sprite", weight = 58 },
			{ species = "nebula_pup", weight = 28 },
			{ species = "comet_serpent", weight = 10 },
			{ species = "orbit_golem", weight = 3.3 },
			{ species = "astral_lion", weight = 0.6 },
			{ species = "eclipse_drake", weight = 0.0789 },
			{ species = "void_seraph", weight = 0.02 },
			{ species = "celestara", weight = 0.0011, condition = { minSpeciesDiscovered = 15 } },
		},
	},
	nebula_egg = {
		name = "Ovo Nebular", world = "astral", currency = "essence", cost = 3000,
		color = Color3.fromRGB(140, 80, 200), spot = Color3.fromRGB(120, 220, 255),
		entries = {
			{ species = "comet_serpent", weight = 58 },
			{ species = "orbit_golem", weight = 30 },
			{ species = "astral_lion", weight = 10 },
			{ species = "eclipse_drake", weight = 1.88 },
			{ species = "void_seraph", weight = 0.1 },
			{ species = "solaris_leviathan", weight = 0.02, condition = { bossDefeated = "void_sovereign" } },
		},
	},

	-- Ovos especiais: não são vendidos. Encontrados explorando (recursos/tesouros) ou derrotando bosses.
	bloom_relic_egg = {
		name = "Ovo Relíquia Florida", world = "verdant", currency = "item", cost = 0, special = true,
		color = Color3.fromRGB(255, 190, 220), spot = Color3.fromRGB(140, 230, 110),
		entries = {
			{ species = "bloomfox", weight = 70 },
			{ species = "grovekin", weight = 28.5 },
			{ species = "verdigris_wisp", weight = 1.5 },
		},
	},
	prism_core_egg = {
		name = "Ovo Núcleo Prismático", world = "crystal", currency = "item", cost = 0, special = true,
		color = Color3.fromRGB(255, 255, 255), spot = Color3.fromRGB(120, 220, 255),
		entries = {
			{ species = "prismcat", weight = 70 },
			{ species = "quartz_drake", weight = 28.5 },
			{ species = "echo_geode", weight = 1.5 },
		},
	},
	tempest_egg = {
		name = "Ovo do Olho da Tempestade", world = "sky", currency = "item", cost = 0, special = true,
		color = Color3.fromRGB(110, 120, 170), spot = Color3.fromRGB(255, 240, 120),
		entries = {
			{ species = "thunder_ram", weight = 70 },
			{ species = "aurora_griffin", weight = 28.5 },
			{ species = "skyborn_seraph", weight = 1.5 },
		},
	},
	wildbloom_egg = {
		name = "Ovo do Coração Selvagem", world = "wilds", currency = "item", cost = 0, special = true,
		color = Color3.fromRGB(60, 40, 80), spot = Color3.fromRGB(170, 255, 200),
		entries = {
			{ species = "dusk_lynx", weight = 66 },
			{ species = "elder_owl", weight = 28 },
			{ species = "moonveil_kitsune", weight = 4.5 },
			{ species = "whisper_shade", weight = 1.5 },
		},
	},
	starfall_egg = {
		name = "Ovo da Chuva de Estrelas", world = "astral", currency = "item", cost = 0, special = true,
		color = Color3.fromRGB(30, 30, 70), spot = Color3.fromRGB(255, 240, 180),
		entries = {
			{ species = "astral_lion", weight = 75 },
			{ species = "eclipse_drake", weight = 22.6 },
			{ species = "void_seraph", weight = 2.2 },
			{ species = "celestara", weight = 0.1 },
			{ species = "solaris_leviathan", weight = 0.1 },
		},
	},
}

return Eggs

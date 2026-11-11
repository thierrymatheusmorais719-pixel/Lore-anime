-- Tabelas de drops. Cada entrada é rolada de forma INDEPENDENTE para cada jogador elegível.
--
-- item: id de Items.Info, ou "coins"/"essence"/"astral", ou "pet:<especie>" (variante de pet)
-- chance: probabilidade base (0..1)
-- luck: se true, a sorte de categoria `category` (padrão "Drop") multiplica a chance
-- maxChance: teto da chance mesmo com sorte (obrigatório quando luck = true)
-- notable: entra no histórico/anúncio
-- mutation: para drops "pet:", aplica esta mutação (ou "roll" para rolar normalmente)

local Drops = {}

Drops.Tables = {
	-- VERDANT -----------------------------------------------------------------
	thornling = {
		{ item = "essence", chance = 1, min = 2, max = 4 },
		{ item = "coins", chance = 1, min = 15, max = 30 },
		{ item = "verdant_sap", chance = 0.35, min = 1, max = 1 },
		{ item = "evolution_dust", chance = 0.08, min = 1, max = 1, luck = true, maxChance = 0.2 },
	},
	wildroot_guardian = {
		{ item = "essence", chance = 1, min = 5, max = 9 },
		{ item = "coins", chance = 1, min = 40, max = 70 },
		{ item = "verdant_sap", chance = 0.6, min = 1, max = 2 },
		{ item = "evolution_dust", chance = 0.18, min = 1, max = 1, luck = true, maxChance = 0.4 },
		{ item = "luck_potion_1", chance = 0.03, min = 1, max = 1, luck = true, maxChance = 0.08 },
	},
	briar_beast = {
		{ item = "essence", chance = 1, min = 8, max = 14 },
		{ item = "coins", chance = 1, min = 70, max = 120 },
		{ item = "elder_bark", chance = 0.3, min = 1, max = 1 },
		{ item = "skill_tome", chance = 0.06, min = 1, max = 1, luck = true, maxChance = 0.15 },
		{ item = "bloom_relic_egg", chance = 0.008, min = 1, max = 1, luck = true, category = "SpecialEgg", maxChance = 0.03, notable = true },
	},
	bog_lurker = {
		{ item = "essence", chance = 1, min = 6, max = 10 },
		{ item = "coins", chance = 1, min = 50, max = 90 },
		{ item = "verdant_sap", chance = 0.35, min = 1, max = 2 },
		{ item = "emerald_crystal", chance = 0.2, min = 1, max = 1 },
		{ item = "luck_potion_1", chance = 0.03, min = 1, max = 1, luck = true, maxChance = 0.1 },
	},
	cave_crawler = {
		{ item = "essence", chance = 1, min = 8, max = 12 },
		{ item = "coins", chance = 1, min = 70, max = 110 },
		{ item = "emerald_crystal", chance = 0.5, min = 1, max = 2 },
		{ item = "prism_heart", chance = 0.004, min = 1, max = 1, luck = true, maxChance = 0.02, notable = true },
	},
	ruin_sentinel = {
		{ item = "essence", chance = 1, min = 12, max = 20 },
		{ item = "coins", chance = 1, min = 110, max = 170 },
		{ item = "elder_bark", chance = 0.35, min = 1, max = 2 },
		{ item = "emerald_crystal", chance = 0.3, min = 1, max = 2 },
		{ item = "skill_tome", chance = 0.07, min = 1, max = 1, luck = true, maxChance = 0.18 },
		{ item = "ancient_catalyst", chance = 0.006, min = 1, max = 1, luck = true, maxChance = 0.025, notable = true },
	},
	elderroot = {
		{ item = "essence", chance = 1, min = 120, max = 180 },
		{ item = "coins", chance = 1, min = 800, max = 1200 },
		{ item = "elder_bark", chance = 1, min = 3, max = 5 },
		{ item = "evolution_dust", chance = 0.8, min = 2, max = 4 },
		{ item = "skill_tome", chance = 0.45, min = 1, max = 2, luck = true, maxChance = 0.8 },
		{ item = "leaf_crown", chance = 0.10, min = 1, max = 1, luck = true, maxChance = 0.25, notable = true },
		{ item = "ancient_catalyst", chance = 0.04, min = 1, max = 1, luck = true, maxChance = 0.1, notable = true },
		{ item = "bloom_relic_egg", chance = 0.12, min = 1, max = 1, luck = true, category = "SpecialEgg", maxChance = 0.3, notable = true },
		{ item = "pet:grovekin", chance = 0.01, min = 1, max = 1, luck = true, maxChance = 0.03, notable = true, mutation = "roll" },
		{ item = "elderroot_trophy", chance = 0.05, min = 1, max = 1, luck = true, maxChance = 0.12, notable = true },
	},

	-- CRYSTAL -----------------------------------------------------------------
	shard_crawler = {
		{ item = "essence", chance = 1, min = 6, max = 10 },
		{ item = "coins", chance = 1, min = 90, max = 140 },
		{ item = "prism_shard", chance = 0.35, min = 1, max = 1 },
		{ item = "evolution_dust", chance = 0.1, min = 1, max = 1, luck = true, maxChance = 0.25 },
	},
	prism_golem = {
		{ item = "essence", chance = 1, min = 12, max = 20 },
		{ item = "coins", chance = 1, min = 180, max = 260 },
		{ item = "prism_shard", chance = 0.6, min = 1, max = 2 },
		{ item = "skill_tome", chance = 0.05, min = 1, max = 1, luck = true, maxChance = 0.12 },
		{ item = "luck_potion_1", chance = 0.04, min = 1, max = 1, luck = true, maxChance = 0.1 },
	},
	crystal_devourer = {
		{ item = "essence", chance = 1, min = 20, max = 32 },
		{ item = "coins", chance = 1, min = 300, max = 450 },
		{ item = "titan_crystal", chance = 0.2, min = 1, max = 1 },
		{ item = "evolution_dust", chance = 0.3, min = 1, max = 2, luck = true, maxChance = 0.6 },
		{ item = "prism_core_egg", chance = 0.008, min = 1, max = 1, luck = true, category = "SpecialEgg", maxChance = 0.03, notable = true },
	},
	prism_titan = {
		{ item = "essence", chance = 1, min = 350, max = 500 },
		{ item = "coins", chance = 1, min = 4000, max = 6000 },
		{ item = "titan_crystal", chance = 1, min = 3, max = 5 },
		{ item = "evolution_dust", chance = 0.9, min = 3, max = 6 },
		{ item = "ascension_core", chance = 0.15, min = 1, max = 1, luck = true, maxChance = 0.35, notable = true },
		{ item = "crystal_tiara", chance = 0.1, min = 1, max = 1, luck = true, maxChance = 0.25, notable = true },
		{ item = "prismatic_catalyst", chance = 0.04, min = 1, max = 1, luck = true, maxChance = 0.1, notable = true },
		{ item = "prism_core_egg", chance = 0.12, min = 1, max = 1, luck = true, category = "SpecialEgg", maxChance = 0.3, notable = true },
		{ item = "titan_trophy", chance = 0.05, min = 1, max = 1, luck = true, maxChance = 0.12, notable = true },
	},

	-- SKY ---------------------------------------------------------------------
	storm_sprite = {
		{ item = "essence", chance = 1, min = 14, max = 22 },
		{ item = "coins", chance = 1, min = 400, max = 600 },
		{ item = "storm_feather", chance = 0.35, min = 1, max = 1 },
		{ item = "evolution_dust", chance = 0.12, min = 1, max = 1, luck = true, maxChance = 0.3 },
	},
	cloud_stalker = {
		{ item = "essence", chance = 1, min = 24, max = 36 },
		{ item = "coins", chance = 1, min = 700, max = 1000 },
		{ item = "storm_feather", chance = 0.6, min = 1, max = 2 },
		{ item = "skill_tome", chance = 0.07, min = 1, max = 1, luck = true, maxChance = 0.15 },
		{ item = "treasure_tonic", chance = 0.03, min = 1, max = 1, luck = true, maxChance = 0.08 },
	},
	tempest_guardian = {
		{ item = "essence", chance = 1, min = 40, max = 60 },
		{ item = "coins", chance = 1, min = 1300, max = 1800 },
		{ item = "wyrm_scale", chance = 0.2, min = 1, max = 1 },
		{ item = "evolution_dust", chance = 0.35, min = 1, max = 2, luck = true, maxChance = 0.6 },
		{ item = "tempest_egg", chance = 0.008, min = 1, max = 1, luck = true, category = "SpecialEgg", maxChance = 0.03, notable = true },
	},
	tempest_wyrm = {
		{ item = "essence", chance = 1, min = 900, max = 1300 },
		{ item = "coins", chance = 1, min = 15000, max = 22000 },
		{ item = "wyrm_scale", chance = 1, min = 3, max = 5 },
		{ item = "ascension_core", chance = 0.3, min = 1, max = 1, luck = true, maxChance = 0.6, notable = true },
		{ item = "storm_goggles", chance = 0.1, min = 1, max = 1, luck = true, maxChance = 0.25, notable = true },
		{ item = "luck_potion_2", chance = 0.25, min = 1, max = 1, luck = true, maxChance = 0.5 },
		{ item = "tempest_egg", chance = 0.12, min = 1, max = 1, luck = true, category = "SpecialEgg", maxChance = 0.3, notable = true },
		{ item = "pet:aurora_griffin", chance = 0.01, min = 1, max = 1, luck = true, maxChance = 0.03, notable = true, mutation = "roll" },
		{ item = "wyrm_trophy", chance = 0.05, min = 1, max = 1, luck = true, maxChance = 0.12, notable = true },
	},

	-- WILDS -------------------------------------------------------------------
	mist_prowler = {
		{ item = "essence", chance = 1, min = 30, max = 45 },
		{ item = "coins", chance = 1, min = 1800, max = 2600 },
		{ item = "moon_petal", chance = 0.35, min = 1, max = 1 },
		{ item = "evolution_dust", chance = 0.15, min = 1, max = 1, luck = true, maxChance = 0.35 },
		{ item = "phantom_catalyst", chance = 0.004, min = 1, max = 1, luck = true, maxChance = 0.012, notable = true },
	},
	hollow_stag = {
		{ item = "essence", chance = 1, min = 50, max = 70 },
		{ item = "coins", chance = 1, min = 3000, max = 4200 },
		{ item = "moon_petal", chance = 0.6, min = 1, max = 2 },
		{ item = "skill_tome", chance = 0.08, min = 1, max = 1, luck = true, maxChance = 0.18 },
		{ item = "mutation_elixir", chance = 0.03, min = 1, max = 1, luck = true, maxChance = 0.08 },
	},
	ancient_bloom_beast = {
		{ item = "essence", chance = 1, min = 80, max = 110 },
		{ item = "coins", chance = 1, min = 5000, max = 7000 },
		{ item = "bloom_heart", chance = 0.2, min = 1, max = 1 },
		{ item = "evolution_dust", chance = 0.4, min = 1, max = 2, luck = true, maxChance = 0.7 },
		{ item = "wildbloom_egg", chance = 0.008, min = 1, max = 1, luck = true, category = "SpecialEgg", maxChance = 0.03, notable = true },
	},
	wilderbloom = {
		{ item = "essence", chance = 1, min = 2200, max = 3000 },
		{ item = "coins", chance = 1, min = 50000, max = 70000 },
		{ item = "bloom_heart", chance = 1, min = 3, max = 5 },
		{ item = "ascension_core", chance = 0.45, min = 1, max = 1, luck = true, maxChance = 0.8, notable = true },
		{ item = "bloom_wreath", chance = 0.1, min = 1, max = 1, luck = true, maxChance = 0.25, notable = true },
		{ item = "phantom_catalyst", chance = 0.05, min = 1, max = 1, luck = true, maxChance = 0.12, notable = true },
		{ item = "wildbloom_egg", chance = 0.15, min = 1, max = 1, luck = true, category = "SpecialEgg", maxChance = 0.35, notable = true },
		{ item = "wilderbloom_trophy", chance = 0.05, min = 1, max = 1, luck = true, maxChance = 0.12, notable = true },
	},
	wilderbloom_sprout = { -- invocações do boss: drop mínimo para não virar "farm"
		{ item = "essence", chance = 0.5, min = 1, max = 3 },
	},

	-- ASTRAL ------------------------------------------------------------------
	astral_sentinel = {
		{ item = "essence", chance = 1, min = 70, max = 100 },
		{ item = "coins", chance = 1, min = 8000, max = 11000 },
		{ item = "astral", chance = 0.5, min = 1, max = 3 },
		{ item = "evolution_dust", chance = 0.25, min = 1, max = 2, luck = true, maxChance = 0.5 },
		{ item = "starfall_egg", chance = 0.004, min = 1, max = 1, luck = true, category = "SpecialEgg", maxChance = 0.015, notable = true },
	},
	rift_keeper = {
		{ item = "essence", chance = 1, min = 120, max = 160 },
		{ item = "coins", chance = 1, min = 14000, max = 19000 },
		{ item = "astral", chance = 0.8, min = 2, max = 5 },
		{ item = "void_essence", chance = 0.25, min = 1, max = 1 },
		{ item = "skill_tome", chance = 0.1, min = 1, max = 1, luck = true, maxChance = 0.2 },
		{ item = "luck_potion_2", chance = 0.03, min = 1, max = 1, luck = true, maxChance = 0.08 },
	},
	void_sovereign = {
		{ item = "essence", chance = 1, min = 6000, max = 8000 },
		{ item = "coins", chance = 1, min = 150000, max = 200000 },
		{ item = "astral", chance = 1, min = 25, max = 40 },
		{ item = "void_essence", chance = 1, min = 3, max = 6 },
		{ item = "ascension_core", chance = 0.7, min = 1, max = 2, luck = true, maxChance = 0.95, notable = true },
		{ item = "void_halo", chance = 0.08, min = 1, max = 1, luck = true, maxChance = 0.2, notable = true },
		{ item = "astral_catalyst", chance = 0.04, min = 1, max = 1, luck = true, maxChance = 0.1, notable = true },
		{ item = "luck_potion_3", chance = 0.15, min = 1, max = 1, luck = true, maxChance = 0.35, notable = true },
		{ item = "starfall_egg", chance = 0.1, min = 1, max = 1, luck = true, category = "SpecialEgg", maxChance = 0.25, notable = true },
		{ item = "pet:void_seraph", chance = 0.004, min = 1, max = 1, luck = true, maxChance = 0.012, notable = true, mutation = "roll" },
		{ item = "sovereign_trophy", chance = 0.05, min = 1, max = 1, luck = true, maxChance = 0.12, notable = true },
	},
	wandering_star = { -- evento secreto
		{ item = "astral", chance = 1, min = 3, max = 8 },
		{ item = "essence", chance = 1, min = 20, max = 60 },
		{ item = "luck_potion_1", chance = 0.5, min = 1, max = 1 },
		{ item = "mutation_elixir", chance = 0.25, min = 1, max = 1, luck = true, maxChance = 0.5, notable = true },
	},
}

-- Tesouros (baús) encontrados na exploração. Mesma regra de rolagem.
Drops.Treasure = {
	{ item = "coins", chance = 1, min = 1, max = 1, scaleByWorld = 300 },
	{ item = "essence", chance = 0.8, min = 3, max = 10, scaleByWorldEssence = true },
	{ item = "luck_potion_1", chance = 0.12, min = 1, max = 1, luck = true, category = "Treasure", maxChance = 0.3 },
	{ item = "treasure_tonic", chance = 0.05, min = 1, max = 1, luck = true, category = "Treasure", maxChance = 0.15 },
	{ item = "evolution_dust", chance = 0.25, min = 1, max = 2, luck = true, category = "Treasure", maxChance = 0.5 },
	{ item = "skill_tome", chance = 0.06, min = 1, max = 1, luck = true, category = "Treasure", maxChance = 0.15 },
}

-- Baús-santuário das regiões (locais escondidos: fim da ponte suspensa, câmara secreta, ilha das ruínas...).
-- Mais generoso que o tesouro comum, porque exige exploração e tem recarga de 30 min por baú.
Drops.Shrine = {
	{ item = "coins", chance = 1, min = 2, max = 3, scaleByWorld = 400 },
	{ item = "essence", chance = 1, min = 8, max = 20, scaleByWorldEssence = true },
	{ item = "luck_potion_1", chance = 0.35, min = 1, max = 1, luck = true, category = "Treasure", maxChance = 0.6 },
	{ item = "evolution_dust", chance = 0.5, min = 1, max = 3, luck = true, category = "Treasure", maxChance = 0.8 },
	{ item = "skill_tome", chance = 0.12, min = 1, max = 1, luck = true, category = "Treasure", maxChance = 0.25 },
	{ item = "mutation_elixir", chance = 0.03, min = 1, max = 1, luck = true, category = "Treasure", maxChance = 0.08, notable = true },
}

-- Ovo especial de cada mundo achado ao quebrar recursos (chance por recurso quebrado).
Drops.ResourceSpecialEgg = {
	verdant = { item = "bloom_relic_egg", chance = 0.0015, maxChance = 0.005 },
	crystal = { item = "prism_core_egg", chance = 0.0012, maxChance = 0.004 },
	sky = { item = "tempest_egg", chance = 0.001, maxChance = 0.0035 },
	wilds = { item = "wildbloom_egg", chance = 0.0009, maxChance = 0.003 },
	astral = { item = "starfall_egg", chance = 0.0006, maxChance = 0.002 },
}

-- Tesouro oculto: chance de surgir perto do jogador ao quebrar um recurso.
Drops.TreasureSpawnChance = 0.02
Drops.TreasureSpawnMaxChance = 0.08
-- Evento secreto (Estrela Errante): chance ao abrir um tesouro.
Drops.SecretEventChance = 0.03
Drops.SecretEventMaxChance = 0.09

return Drops

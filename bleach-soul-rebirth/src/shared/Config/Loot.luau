-- Tabelas de drop. `guaranteed` sempre cai; `chance` rola individualmente.
-- `pity`: após N mortes sem o drop raro, ele é garantido (por jogador e por tabela).
local Loot = {
	HollowGrunt = {
		kan = { 6, 12 },
		guaranteed = { { id = "HollowFragment", qty = { 1, 2 } } },
		chance = {
			{ id = "SoulCandy", qty = { 1, 1 }, chance = 0.08 },
			{ id = "ReishiCrystal", qty = { 1, 1 }, chance = 0.05 },
		},
	},
	HollowBrute = {
		kan = { 15, 25 },
		guaranteed = { { id = "HollowFragment", qty = { 2, 4 } } },
		chance = {
			{ id = "ReishiCrystal", qty = { 1, 1 }, chance = 0.2 },
			{ id = "ReiatsuPill", qty = { 1, 1 }, chance = 0.1 },
		},
		pity = { id = "ReishiCrystal", after = 6 },
	},
	TrainingPuppet = {
		kan = { 3, 6 },
		guaranteed = {},
		chance = { { id = "HollowFragment", qty = { 1, 1 }, chance = 0.4 } },
	},
	Arrancar = {
		kan = { 30, 50 },
		guaranteed = { { id = "ReishiCrystal", qty = { 1, 2 } } },
		chance = {
			{ id = "SpiritCore", qty = { 1, 1 }, chance = 0.06 },
			{ id = "SoulCandy", qty = { 1, 1 }, chance = 0.15 },
		},
		pity = { id = "SpiritCore", after = 15 },
	},
	MenosShade = {
		kan = { 60, 90 },
		guaranteed = { { id = "ReishiCrystal", qty = { 2, 4 } } },
		chance = { { id = "SpiritCore", qty = { 1, 1 }, chance = 0.2 } },
		pity = { id = "SpiritCore", after = 5 },
	},
	Kurokage = {
		kan = { 250, 350 },
		shards = 15,
		guaranteed = { { id = "SpiritCore", qty = { 1, 2 } }, { id = "ReishiCrystal", qty = { 3, 5 } } },
		chance = { { id = "KurokageFang", qty = { 1, 1 }, chance = 0.15 } },
		pity = { id = "KurokageFang", after = 6 },
	},
	InnerHollow = {
		kan = { 300, 400 },
		shards = 20,
		guaranteed = { { id = "SpiritCore", qty = { 2, 3 } } },
		chance = {},
	},
	InnerSpirit = {
		kan = { 300, 400 },
		shards = 20,
		guaranteed = { { id = "SpiritCore", qty = { 2, 3 } } },
		chance = {},
	},
	VastoLeon = {
		kan = { 800, 1200 },
		shards = 40,
		guaranteed = { { id = "SpiritCore", qty = { 3, 5 } } },
		chance = { { id = "KingsMane", qty = { 1, 1 }, chance = 0.35 } },
		pity = { id = "KingsMane", after = 3 },
	},
}

return Loot

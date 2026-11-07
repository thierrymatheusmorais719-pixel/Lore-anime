-- Mundos (ilhas). Cada ilha é construída proceduralmente pelo WorldService em `center`.
-- unlockCost: moedas para abrir o portal a partir do mundo anterior.
-- ground/cliff: materiais de Terrain EXCLUSIVOS por ilha (a cor de material do Terrain é global)
-- statMult: multiplicador de atributos dos pets nascidos neste mundo (progressão).
-- radius: raio da ilha. core: raio da parte central (praça, ovos, arena, zonas e regiões feitas à mão);
--   entre core e radius fica o anel de mata para exploração (WorldBuilder.wildRing).

local Worlds = {}

Worlds.Order = { "verdant", "crystal", "sky", "wilds", "astral" }

Worlds.Info = {
	verdant = {
		name = "Verdant Haven",
		index = 1,
		center = Vector3.new(0, 0, 0),
		radius = 345,
		core = 230,
		unlockCost = 0,
		statMult = 1.0,
		ground = "Grass",
		cliff = "Rock",
		palette = {
			ground = Color3.fromRGB(96, 168, 74),
			accent = Color3.fromRGB(255, 214, 120),
			fog = Color3.fromRGB(196, 230, 210),
			ambient = Color3.fromRGB(120, 140, 110),
		},
		clockTime = 14.5,
		bossId = "elderroot",
		enemies = { "thornling", "wildroot_guardian", "briar_beast" },
		resource = "bloom_bush",
		eggs = { "verdant_egg", "grove_egg" },
	},
	crystal = {
		name = "Crystal Hollow",
		index = 2,
		center = Vector3.new(1400, 0, 0),
		radius = 315,
		core = 230,
		unlockCost = 2500,
		statMult = 1.35,
		-- Grass: grama animada como na arte de referência. A cor do material Grass do Terrain é
		-- global, então é a MESMA do Verdant Haven (ver WorldBuilder.terrainFill).
		ground = "Grass",
		cliff = "Basalt",
		palette = {
			ground = Color3.fromRGB(96, 168, 74),
			accent = Color3.fromRGB(120, 220, 255),
			fog = Color3.fromRGB(150, 170, 230),
			ambient = Color3.fromRGB(110, 100, 170),
		},
		clockTime = 15.6,
		bossId = "prism_titan",
		enemies = { "shard_crawler", "prism_golem", "crystal_devourer" },
		resource = "crystal_cluster",
		eggs = { "crystal_egg", "geode_egg" },
	},
	sky = {
		name = "Skybound Kingdom",
		index = 3,
		center = Vector3.new(2800, 160, 0),
		radius = 220,
		extent = 390, -- ilhas satélites flutuam além da ilha principal (área de jogo do mundo)
		unlockCost = 15000,
		statMult = 1.75,
		-- Grass: a cor do material é global (a mesma do Verdant Haven); falésias de Limestone claro
		ground = "Grass",
		cliff = "Limestone",
		palette = {
			ground = Color3.fromRGB(96, 168, 74),
			accent = Color3.fromRGB(255, 255, 255),
			fog = Color3.fromRGB(205, 228, 255),
			ambient = Color3.fromRGB(150, 170, 200),
		},
		clockTime = 15.8, -- tarde dourada de céu azul (arte de referência do Mundo 3)
		bossId = "tempest_wyrm",
		enemies = { "storm_sprite", "cloud_stalker", "tempest_guardian" },
		resource = "cloud_puff",
		eggs = { "sky_egg", "storm_egg" },
	},
	wilds = {
		name = "Whispering Wilds",
		index = 4,
		center = Vector3.new(4200, 0, 0),
		radius = 335,
		core = 230,
		unlockCost = 60000,
		statMult = 2.2,
		ground = "LeafyGrass",
		cliff = "Mud",
		palette = {
			ground = Color3.fromRGB(58, 98, 70),
			accent = Color3.fromRGB(180, 140, 255),
			fog = Color3.fromRGB(120, 140, 150),
			ambient = Color3.fromRGB(90, 100, 120),
		},
		clockTime = 18.2,
		bossId = "wilderbloom",
		enemies = { "mist_prowler", "hollow_stag", "ancient_bloom_beast" },
		resource = "glow_mushroom",
		eggs = { "wilds_egg", "moon_egg" },
	},
	astral = {
		name = "Astral Sanctuary",
		index = 5,
		center = Vector3.new(5600, 60, 0),
		radius = 315,
		core = 220,
		unlockCost = 250000,
		statMult = 2.7,
		ground = "Pavement",
		cliff = "Concrete",
		palette = {
			ground = Color3.fromRGB(70, 66, 110),
			accent = Color3.fromRGB(255, 220, 140),
			fog = Color3.fromRGB(40, 30, 80),
			ambient = Color3.fromRGB(110, 90, 170),
		},
		clockTime = 22,
		bossId = "void_sovereign",
		enemies = { "astral_sentinel", "rift_keeper" },
		resource = "star_shard",
		eggs = { "astral_egg", "nebula_egg" },
	},
}

-- Zona segura ao redor do ponto de chegada de cada ilha (inimigos não perseguem aqui).
Worlds.SafeRadius = 45

function Worlds.indexOf(id: string): number
	local info = Worlds.Info[id]
	return info and info.index or 0
end

return Worlds

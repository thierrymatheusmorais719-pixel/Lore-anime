-- Exploração: recursos quebráveis, tesouros e recompensas de coleção (bestiário).

local Exploration = {}

-- Recursos que os pets quebram para gerar moedas (loop base do simulador).
Exploration.Resources = {
	bloom_bush = { label = "Arbusto Florido", hp = 60, coins = 6, count = 34, respawn = 12 },
	crystal_cluster = { label = "Aglomerado de Cristal", hp = 420, coins = 40, count = 34, respawn = 12 },
	cloud_puff = { label = "Nuvem Sólida", hp = 2400, coins = 210, count = 30, respawn = 12 },
	glow_mushroom = { label = "Cogumelo Brilhante", hp = 9000, coins = 900, count = 32, respawn = 12 },
	star_shard = { label = "Fragmento Estelar", hp = 30000, coins = 3600, count = 30, respawn = 12 },
}
-- Dano de mineração: soma do ataque dos pets da equipe * este fator, a cada `MineInterval`.
Exploration.MineFactor = 1.0
Exploration.MineInterval = 0.5
Exploration.MineRange = 30 -- jogador precisa estar a esta distância do recurso

-- Tesouros ocultos.
Exploration.Treasure = { lifetime = 90, maxPerPlayer = 2, spawnMin = 18, spawnMax = 45, openRange = 12 }

-- Baús-santuário fixos das regiões (Crystal Hollow): recarga por jogador, salva no perfil.
Exploration.Shrine = { cooldown = 30 * 60, range = 14 }

-- Marcos de coleção (bestiário). `species` conta espécies de PET descobertas;
-- `mutations` conta tipos de mutação descobertos; `enemies` conta inimigos/bosses registrados.
Exploration.CollectionMilestones = {
	{ id = "c_pets5", label = "Colecionador I", need = { species = 5 }, reward = { coins = 500, items = { luck_potion_1 = 1 } } },
	{ id = "c_pets10", label = "Colecionador II", need = { species = 10 }, reward = { essence = 200, items = { luck_potion_2 = 1 } } },
	{ id = "c_pets20", label = "Colecionador III", need = { species = 20 }, reward = { essence = 800, items = { mutation_elixir = 2 } } },
	{ id = "c_pets30", label = "Mestre do Bestiário", need = { species = 30 }, reward = { astral = 50, items = { luck_potion_3 = 1 } } },
	{ id = "c_pets60", label = "Naturalista", need = { species = 60 }, reward = { essence = 2000, items = { luck_potion_2 = 2 } } },
	{ id = "c_pets100", label = "Guardião das Ilhas", need = { species = 100 }, reward = { astral = 80, items = { luck_potion_3 = 2 } } },
	{ id = "c_pets150", label = "Lenda Viva", need = { species = 150 }, reward = { astral = 200, items = { luck_potion_3 = 3, mutation_elixir = 3 } } },
	{ id = "c_mut1", label = "Primeira Mutação", need = { mutations = 1 }, reward = { essence = 150 } },
	{ id = "c_mut4", label = "Mutagênico", need = { mutations = 4 }, reward = { essence = 600, items = { mutation_elixir = 1 } } },
	{ id = "c_mut6", label = "Espectro Completo", need = { mutations = 6 }, reward = { astral = 30, items = { void_halo = 1 } } },
	{ id = "c_foe8", label = "Caçador", need = { enemies = 8 }, reward = { essence = 300, items = { skill_tome = 2 } } },
	{ id = "c_foe16", label = "Lenda das Ilhas", need = { enemies = 16 }, reward = { astral = 40, items = { luck_potion_3 = 1 } } },
}

return Exploration

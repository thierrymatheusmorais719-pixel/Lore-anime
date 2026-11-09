-- MINERAÇÃO DE CRISTAIS: veios nas cavernas e nos campos de cada mundo, minerados pelo JOGADOR com a
-- picareta (os pets por perto ajudam). Os cristais viram itens do inventário e servem para os
-- CONTRATOS DE MINERAÇÃO (missões de entrega que renovam todo dia), para as missões diárias e para
-- melhorar a picareta.

local Mining = {}

-- Cristais (itens; o rótulo e a cor ficam também em Config/Items).
Mining.Crystals = {
	emerald_crystal = { label = "Cristal Esmeralda", color = Color3.fromRGB(80, 230, 140), world = "verdant" },
	sapphire_crystal = { label = "Cristal Safira", color = Color3.fromRGB(90, 160, 255), world = "crystal" },
	amethyst_crystal = { label = "Cristal Ametista", color = Color3.fromRGB(185, 120, 255), world = "crystal" },
	storm_crystal = { label = "Cristal Tempestade", color = Color3.fromRGB(255, 230, 110), world = "sky" },
	shadow_crystal = { label = "Cristal Sombrio", color = Color3.fromRGB(120, 90, 170), world = "wilds" },
	star_crystal = { label = "Cristal Estelar", color = Color3.fromRGB(255, 240, 200), world = "astral" },
	-- raro: sai de qualquer veio (a sorte de Drop aumenta a chance)
	prism_heart = { label = "Coração Prismático", color = Color3.fromRGB(255, 150, 230), rare = true },
}
Mining.CrystalOrder = { "emerald_crystal", "sapphire_crystal", "amethyst_crystal", "storm_crystal", "shadow_crystal", "star_crystal", "prism_heart" }

-- Tipos de veio: golpes de picareta para quebrar (hp), cristais por quebra e tempo para voltar.
Mining.Veins = {
	emerald = { crystal = "emerald_crystal", label = "Veio Esmeralda", hp = 6, yield = { 2, 4 }, respawn = 25 },
	sapphire = { crystal = "sapphire_crystal", label = "Veio Safira", hp = 9, yield = { 2, 4 }, respawn = 30 },
	amethyst = { crystal = "amethyst_crystal", label = "Veio Ametista", hp = 14, yield = { 1, 3 }, respawn = 45 },
	storm = { crystal = "storm_crystal", label = "Veio Tempestade", hp = 18, yield = { 2, 3 }, respawn = 40 },
	shadow = { crystal = "shadow_crystal", label = "Veio Sombrio", hp = 24, yield = { 2, 3 }, respawn = 45 },
	star = { crystal = "star_crystal", label = "Veio Estelar", hp = 32, yield = { 1, 3 }, respawn = 50 },
}
-- Quais veios nascem em cada mundo (no Verdant Haven ficam nos salões das Cavernas Esmeralda).
Mining.WorldVeins = {
	verdant = { "emerald" },
	crystal = { "sapphire", "sapphire", "amethyst" },
	sky = { "storm" },
	wilds = { "shadow" },
	astral = { "star" },
}
Mining.VeinsPerField = 3 -- nos outros mundos: veios em volta de cada campo de recursos
Mining.Range = 12 -- distância máxima do jogador ao veio (studs)
Mining.PetHelpRange = 18 -- pets da equipe a esta distância ajudam (+1 de força a cada 2 pets)
Mining.RareChance = 0.03 -- chance do Coração Prismático por quebra (antes da sorte)
Mining.RareMaxChance = 0.15

-- Picaretas: força por golpe, tempo segurando o botão e o custo para chegar nesse nível.
Mining.Pickaxes = {
	{ label = "Picareta de Madeira", power = 1, hold = 1.0, bonus = 0 },
	{ label = "Picareta de Pedra", power = 2, hold = 0.85, bonus = 0, cost = { coins = 600, items = { emerald_crystal = 12 } } },
	{ label = "Picareta de Ferro", power = 3, hold = 0.7, bonus = 1, cost = { coins = 6000, items = { emerald_crystal = 20, sapphire_crystal = 15 } } },
	{ label = "Picareta de Cristal", power = 5, hold = 0.55, bonus = 1, cost = { coins = 40000, items = { amethyst_crystal = 20, prism_heart = 1 } } },
	{ label = "Picareta da Tempestade", power = 7, hold = 0.5, bonus = 2, cost = { coins = 150000, items = { storm_crystal = 25, prism_heart = 2 } } },
	{ label = "Picareta Estelar", power = 10, hold = 0.45, bonus = 3, cost = { astral = 40, items = { shadow_crystal = 25, star_crystal = 25, prism_heart = 3 } } },
}

-- CONTRATOS DE MINERAÇÃO (missões de entrega). 3 por dia, iguais para todos no mesmo dia; cada um
-- só pode ser entregue uma vez por dia. `world` = mundo que precisa estar aberto para aparecer.
Mining.Contracts = {
	{ id = "mc_emerald_s", label = "Lanternas da Vila", desc = "O ferreiro precisa de cristais para as lanternas.", need = { emerald_crystal = 8 },
		reward = { coins = 900, items = { luck_potion_1 = 1 } }, world = "verdant" },
	{ id = "mc_emerald_l", label = "Muralha Brilhante", desc = "Reforçar a muralha de Eldermoor.", need = { emerald_crystal = 20 },
		reward = { coins = 2200, essence = 60, items = { evolution_dust = 1 } }, world = "verdant" },
	{ id = "mc_emerald_g", label = "Oferenda às Runas", desc = "Cristais para o Círculo das Runas.", need = { emerald_crystal = 12 },
		reward = { essence = 90, luck = { bonus = 0.25, duration = 600, category = "Drop" } }, world = "verdant" },
	{ id = "mc_sapphire", label = "Lentes do Farol", desc = "Polir as lentes do Farol Ancestral.", need = { sapphire_crystal = 12 },
		reward = { coins = 6000, essence = 120, items = { skill_tome = 1 } }, world = "crystal" },
	{ id = "mc_amethyst", label = "Tinta Ametista", desc = "Os escribas querem pó de ametista.", need = { amethyst_crystal = 6, sapphire_crystal = 6 },
		reward = { essence = 260, items = { evolution_dust = 3 } }, world = "crystal" },
	{ id = "mc_storm", label = "Para-raios", desc = "Proteger as torres das tempestades.", need = { storm_crystal = 10 },
		reward = { coins = 30000, essence = 300, items = { luck_potion_2 = 1 } }, world = "sky" },
	{ id = "mc_shadow", label = "Amuletos da Mata", desc = "Amuletos contra os sussurros.", need = { shadow_crystal = 10 },
		reward = { coins = 90000, essence = 700, items = { mutation_elixir = 1 } }, world = "wilds" },
	{ id = "mc_star", label = "Mapa das Estrelas", desc = "Cristais estelares para o observatório.", need = { star_crystal = 10 },
		reward = { astral = 15, items = { luck_potion_3 = 1 } }, world = "astral" },
	{ id = "mc_heart", label = "Joia do Rei", desc = "Um Coração Prismático para a coroa.", need = { prism_heart = 1 },
		reward = { essence = 500, items = { ascension_core = 1 } }, world = "verdant" },
}
Mining.ContractsPerDay = 3

function Mining.findContract(id: string)
	for _, c in ipairs(Mining.Contracts) do
		if c.id == id then
			return c
		end
	end
	return nil
end

return Mining

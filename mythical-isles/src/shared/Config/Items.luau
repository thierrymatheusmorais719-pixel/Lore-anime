-- Itens de inventário. Moedas (coins), Essência (essence) e Fragmentos Astrais (astral) são
-- recursos separados no perfil; aqui ficam os itens contáveis.
--
-- kind: material | potion | egg | cosmetic | collectible | catalyst

local Items = {}

Items.Currencies = {
	coins = { label = "Moedas", icon = "●", color = Color3.fromRGB(255, 210, 70) },
	essence = { label = "Essência", icon = "◆", color = Color3.fromRGB(120, 230, 200) },
	astral = { label = "Fragmentos Astrais", icon = "✦", color = Color3.fromRGB(170, 150, 255) },
}

Items.Info = {
	-- Materiais de evolução / aprimoramento
	evolution_dust = { kind = "material", label = "Pó de Evolução", color = Color3.fromRGB(255, 230, 140) },
	ascension_core = { kind = "material", label = "Núcleo de Ascensão", color = Color3.fromRGB(255, 120, 200) },
	skill_tome = { kind = "material", label = "Tomo de Habilidade", color = Color3.fromRGB(140, 180, 255) },
	verdant_sap = { kind = "material", label = "Seiva Verdejante", color = Color3.fromRGB(120, 210, 90) },
	elder_bark = { kind = "material", label = "Casca Anciã", color = Color3.fromRGB(140, 100, 60) },
	prism_shard = { kind = "material", label = "Estilhaço Prismático", color = Color3.fromRGB(150, 220, 255) },
	titan_crystal = { kind = "material", label = "Cristal de Titã", color = Color3.fromRGB(200, 140, 255) },
	storm_feather = { kind = "material", label = "Pena da Tempestade", color = Color3.fromRGB(200, 220, 255) },
	wyrm_scale = { kind = "material", label = "Escama de Serpe", color = Color3.fromRGB(90, 140, 220) },
	moon_petal = { kind = "material", label = "Pétala Lunar", color = Color3.fromRGB(200, 180, 255) },
	bloom_heart = { kind = "material", label = "Coração Florescente", color = Color3.fromRGB(255, 120, 160) },
	void_essence = { kind = "material", label = "Essência do Vazio", color = Color3.fromRGB(110, 60, 200) },

	-- Poções (efeitos em Config/Luck.Potions)
	luck_potion_1 = { kind = "potion", label = "Poção da Sorte I", color = Color3.fromRGB(120, 255, 140) },
	luck_potion_2 = { kind = "potion", label = "Poção da Sorte II", color = Color3.fromRGB(80, 230, 255) },
	luck_potion_3 = { kind = "potion", label = "Poção da Sorte III", color = Color3.fromRGB(255, 220, 80) },
	treasure_tonic = { kind = "potion", label = "Tônico do Caçador", color = Color3.fromRGB(255, 170, 60) },
	mutation_elixir = { kind = "potion", label = "Elixir Mutagênico", color = Color3.fromRGB(230, 120, 255) },

	-- Ovos especiais (chocados de graça em qualquer estação de ovos)
	bloom_relic_egg = { kind = "egg", label = "Ovo Relíquia Florida", color = Color3.fromRGB(255, 190, 220) },
	prism_core_egg = { kind = "egg", label = "Ovo Núcleo Prismático", color = Color3.fromRGB(230, 250, 255) },
	tempest_egg = { kind = "egg", label = "Ovo do Olho da Tempestade", color = Color3.fromRGB(110, 120, 170) },
	wildbloom_egg = { kind = "egg", label = "Ovo do Coração Selvagem", color = Color3.fromRGB(90, 60, 110) },
	starfall_egg = { kind = "egg", label = "Ovo da Chuva de Estrelas", color = Color3.fromRGB(40, 40, 90) },

	-- Catalisadores: aplicam uma mutação específica a um pet SEM mutação (regra definida, não sorteio).
	ancient_catalyst = { kind = "catalyst", label = "Catalisador Ancestral", mutation = "Ancient", color = Color3.fromRGB(150, 200, 120) },
	prismatic_catalyst = { kind = "catalyst", label = "Catalisador Prismático", mutation = "Prismatic", color = Color3.fromRGB(255, 140, 240) },
	phantom_catalyst = { kind = "catalyst", label = "Catalisador Fantasma", mutation = "Phantom", color = Color3.fromRGB(160, 220, 255) },
	astral_catalyst = { kind = "catalyst", label = "Catalisador Astral", mutation = "Astral", color = Color3.fromRGB(140, 120, 255) },

	-- Acessórios cosméticos para pets (equipáveis em qualquer pet; visual em Builders/Accessories)
	leaf_crown = { kind = "cosmetic", label = "Coroa de Folhas", color = Color3.fromRGB(120, 200, 90) },
	crystal_tiara = { kind = "cosmetic", label = "Tiara de Cristal", color = Color3.fromRGB(150, 220, 255) },
	storm_goggles = { kind = "cosmetic", label = "Óculos de Tempestade", color = Color3.fromRGB(255, 220, 90) },
	bloom_wreath = { kind = "cosmetic", label = "Guirlanda Florescente", color = Color3.fromRGB(255, 140, 190) },
	void_halo = { kind = "cosmetic", label = "Auréola do Vazio", color = Color3.fromRGB(160, 100, 255) },

	-- Colecionáveis (troféus de boss / bestiário)
	elderroot_trophy = { kind = "collectible", label = "Troféu: Elderroot", color = Color3.fromRGB(120, 90, 60) },
	titan_trophy = { kind = "collectible", label = "Troféu: Prism Titan", color = Color3.fromRGB(170, 140, 255) },
	wyrm_trophy = { kind = "collectible", label = "Troféu: Tempest Wyrm", color = Color3.fromRGB(110, 150, 230) },
	wilderbloom_trophy = { kind = "collectible", label = "Troféu: The Wilderbloom", color = Color3.fromRGB(200, 120, 200) },
	sovereign_trophy = { kind = "collectible", label = "Troféu: Void Sovereign", color = Color3.fromRGB(90, 60, 180) },
}

function Items.label(id: string): string
	local c = Items.Currencies[id]
	if c then
		return c.label
	end
	local i = Items.Info[id]
	return i and i.label or id
end

return Items

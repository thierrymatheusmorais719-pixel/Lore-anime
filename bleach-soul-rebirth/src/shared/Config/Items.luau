-- Itens: armas, acessórios, materiais e consumíveis. `stats` soma atributos.
local Items = {}

Items.Rarities = {
	Common = { order = 1, name = "Comum", color = Color3.fromRGB(190, 195, 205) },
	Rare = { order = 2, name = "Raro", color = Color3.fromRGB(90, 160, 255) },
	Epic = { order = 3, name = "Épico", color = Color3.fromRGB(190, 90, 255) },
	Legendary = { order = 4, name = "Lendário", color = Color3.fromRGB(255, 200, 60) },
}

Items.Slots = { "Weapon", "Accessory" }

Items.List = {
	-- Materiais
	HollowFragment = { name = "Fragmento de Máscara", kind = "Material", rarity = "Common", kanji = "片", stack = 999, desc = "Pedaço de máscara Hollow. Usado em forja.", sell = 2 },
	ReishiCrystal = { name = "Cristal de Reishi", kind = "Material", rarity = "Rare", kanji = "晶", stack = 999, desc = "Reishi condensado. Usado em forja.", sell = 8 },
	SpiritCore = { name = "Núcleo Espiritual", kind = "Material", rarity = "Epic", kanji = "核", stack = 999, desc = "Coração de um Hollow poderoso.", sell = 30 },
	KingsMane = { name = "Juba do Rei", kind = "Material", rarity = "Legendary", kanji = "鬣", stack = 999, desc = "Relíquia do Rei Leão do Deserto.", sell = 120 },

	-- Consumíveis
	SoulCandy = { name = "Bala de Alma", kind = "Consumable", rarity = "Common", kanji = "飴", stack = 20, desc = "Restaura 40% da vida.", use = { heal = 0.4 }, cooldown = 15, sell = 5, price = 25 },
	ReiatsuPill = { name = "Pílula de Reiatsu", kind = "Consumable", rarity = "Common", kanji = "丸", stack = 20, desc = "Restaura 50% do Reiatsu.", use = { reiatsu = 0.5 }, cooldown = 15, sell = 5, price = 25 },

	-- Armas (afetam atributos e a cor da lâmina)
	ReforgedBlade = { name = "Lâmina Reforjada", kind = "Weapon", rarity = "Common", kanji = "刀", desc = "Aço espiritual comum.", stats = { Strength = 3 }, sell = 10, price = 120 },
	DuskEdge = { name = "Fio do Crepúsculo", kind = "Weapon", rarity = "Rare", kanji = "暮", desc = "Forjada com cristais de Reishi.", stats = { Strength = 6, Spirit = 3 }, tint = Color3.fromRGB(255, 150, 110), sell = 40 },
	KurokageFang = { name = "Presa de Kurokage", kind = "Weapon", rarity = "Epic", kanji = "牙", desc = "Arrancada do Devorador.", stats = { Strength = 10, Agility = 4 }, tint = Color3.fromRGB(120, 60, 200), sell = 120 },
	DesertKingEdge = { name = "Lâmina do Rei do Deserto", kind = "Weapon", rarity = "Legendary", kanji = "覇", desc = "Corta até o vazio.", stats = { Strength = 16, Spirit = 8, Agility = 4 }, tint = Color3.fromRGB(255, 205, 80), sell = 400 },

	-- Acessórios
	FocusBand = { name = "Faixa do Foco", kind = "Accessory", rarity = "Common", kanji = "帯", desc = "Concentração espiritual.", stats = { Spirit = 3 }, sell = 10, price = 120 },
	BoneNecklace = { name = "Colar de Presas", kind = "Accessory", rarity = "Rare", kanji = "骨", desc = "Troféu de caça.", stats = { Strength = 4, Vitality = 4 }, sell = 40 },
	SpiritCross = { name = "Cruz Espiritual", kind = "Accessory", rarity = "Epic", kanji = "十", desc = "Amplifica o Reishi ao redor.", stats = { Spirit = 8, Vitality = 4 }, sell = 120 },
	InnerSeal = { name = "Selo Interior", kind = "Accessory", rarity = "Legendary", kanji = "封", desc = "Lacre do próprio espírito.", stats = { Strength = 6, Spirit = 6, Vitality = 6, Agility = 6 }, sell = 400 },
}

-- Forja: caminho determinístico para equipamentos (progressão que não depende de sorte).
Items.Recipes = {
	DuskEdge = { kan = 300, materials = { HollowFragment = 20, ReishiCrystal = 4 }, level = 6 },
	BoneNecklace = { kan = 300, materials = { HollowFragment = 25, ReishiCrystal = 3 }, level = 6 },
	KurokageFang = { kan = 900, materials = { ReishiCrystal = 12, SpiritCore = 3 }, level = 12 },
	SpiritCross = { kan = 900, materials = { ReishiCrystal = 15, SpiritCore = 3 }, level = 12 },
	DesertKingEdge = { kan = 2500, materials = { SpiritCore = 8, KingsMane = 1 }, level = 25 },
	InnerSeal = { kan = 2500, materials = { SpiritCore = 10, KingsMane = 1 }, level = 25 },
}

-- Loja do Velho Sōma.
Items.Shop = { "SoulCandy", "ReiatsuPill", "ReforgedBlade", "FocusBand" }

function Items.get(id: string?)
	return id and Items.List[id] or nil
end

return Items

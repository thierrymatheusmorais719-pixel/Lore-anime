-- Configuração central da SORTE.
--
-- A sorte é sempre um bônus aditivo por fonte (ex.: +0.25 = +25%). Para cada categoria:
--   multiplicador = clamp(1 + soma(bônus das fontes que valem para a categoria), 1, MaxMultiplier[categoria])
-- Cada fonte também tem um teto próprio (SourceCaps) para que nenhuma fonte sozinha domine.
--
-- O multiplicador NUNCA é enviado pelo cliente. Ele é calculado no servidor (LuckService) a
-- partir do perfil salvo, da equipe equipada e dos eventos ativos.
--
-- Como o multiplicador vira probabilidade:
--   * Sorteios por peso (ovos): peso' = peso * mult^influência(raridade); depois renormaliza.
--     Raridades com influência 0 (Comum/Incomum) não sobem, então perdem espaço naturalmente.
--     Em seguida aplica-se o teto `maxChance` da raridade e redistribui o excedente.
--   * Chances independentes (drops, mutação, tesouro): p' = min(p * mult^influência, teto).

local Luck = {}

Luck.Categories = { "PetVariant", "Mutation", "Treasure", "Drop", "SpecialEgg", "SecretEvent" }

Luck.CategoryLabels = {
	PetVariant = "Pets raros (ovos)",
	Mutation = "Mutações",
	Treasure = "Tesouros",
	Drop = "Drops raros",
	SpecialEgg = "Ovos especiais",
	SecretEvent = "Eventos secretos",
}

Luck.MaxMultiplier = {
	PetVariant = 3.0,
	Mutation = 3.0,
	Treasure = 4.0,
	Drop = 3.0,
	SpecialEgg = 3.0,
	SecretEvent = 3.0,
}

-- Teto de bônus somado por TIPO de fonte.
Luck.SourceCaps = {
	event = 1.0,
	potion = 1.0,
	quest = 0.5,
	pet = 0.30,
	collection = 0.30,
	login = 0.25,
	synergy = 0.15,
}

Luck.SourceLabels = {
	event = "Evento",
	potion = "Poção",
	quest = "Recompensa de missão",
	pet = "Habilidade de pet",
	collection = "Coleção",
	login = "Login diário",
	synergy = "Sinergia da equipe",
}

-- Poções (itens). Ganhas jogando: missões, tesouros, drops.
Luck.Potions = {
	luck_potion_1 = { label = "Poção da Sorte I", bonus = 0.25, duration = 600, category = "All" },
	luck_potion_2 = { label = "Poção da Sorte II", bonus = 0.5, duration = 900, category = "All" },
	luck_potion_3 = { label = "Poção da Sorte III", bonus = 1.0, duration = 900, category = "All" },
	treasure_tonic = { label = "Tônico do Caçador", bonus = 0.6, duration = 900, category = "Treasure" },
	mutation_elixir = { label = "Elixir Mutagênico", bonus = 0.5, duration = 600, category = "Mutation" },
}
Luck.MaxActivePotionsPerId = 1 -- beber a mesma poção de novo soma tempo (até MaxPotionDuration)
Luck.MaxPotionDuration = 3600

-- Coleção: +bônus a cada X espécies distintas descobertas (todas as categorias).
Luck.Collection = { perSpecies = 0.01, perMutationKind = 0.02 }

-- Login diário: +bônus por dia de sequência, válido por 24h após resgatar.
Luck.Login = { perStreakDay = 0.05, maxStreak = 5, duration = 24 * 3600 }

-- Eventos de sorte globais (iguais em todos os servidores, calculados pelo relógio UTC).
-- A cada `period` segundos, um evento de `duration` segundos começa em `offset`.
Luck.ScheduledEvents = {
	{ id = "lucky_hour", label = "Hora da Sorte", period = 3 * 3600, offset = 0, duration = 20 * 60, bonus = 0.5, category = "All" },
	{ id = "mutation_moon", label = "Lua Mutante", period = 4 * 3600, offset = 2 * 3600, duration = 15 * 60, bonus = 0.75, category = "Mutation" },
}

-- Histórico de descobertas mostrado na interface.
Luck.HistorySize = 25

return Luck

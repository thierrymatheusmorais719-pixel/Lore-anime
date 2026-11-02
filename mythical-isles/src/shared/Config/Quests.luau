-- Missões. A história é uma sequência; as diárias são 3 sorteadas por dia (iguais para todos,
-- determinadas pelo número do dia UTC).
--
-- goal.type: hatch | defeat_enemy | defeat_boss | earn_coins | break_resource | open_treasure |
--            discover_mutation | evolve | unlock_world | upgrade_ability | use_ability
-- goal.target: id específico (opcional; nil = qualquer)
-- reward: { coins, essence, astral, items = { id = n }, luck = { bonus, duration, category } }

local Quests = {}

Quests.Story = {
	{ id = "s1", label = "Primeiro Companheiro", desc = "Choque 1 ovo no Ovo do Bosque.", goal = { type = "hatch", count = 1 },
		reward = { coins = 150 } },
	{ id = "s2", label = "Colheita", desc = "Quebre 15 arbustos com seus pets.", goal = { type = "break_resource", count = 15 },
		reward = { coins = 300, items = { luck_potion_1 = 1 } } },
	{ id = "s3", label = "Espinhos no Caminho", desc = "Derrote 5 Thornlings.", goal = { type = "defeat_enemy", target = "thornling", count = 5 },
		reward = { essence = 40, items = { evolution_dust = 2 } } },
	{ id = "s4", label = "Equipe Completa", desc = "Choque mais 4 ovos.", goal = { type = "hatch", count = 4 },
		reward = { coins = 500, luck = { bonus = 0.3, duration = 600, category = "PetVariant" } } },
	{ id = "s5", label = "Guardiões das Raízes", desc = "Derrote 3 Wildroot Guardians.", goal = { type = "defeat_enemy", target = "wildroot_guardian", count = 3 },
		reward = { essence = 80, items = { skill_tome = 1 } } },
	{ id = "s6", label = "O Guardião Verde", desc = "Derrote Elderroot na arena da floresta.", goal = { type = "defeat_boss", target = "elderroot", count = 1 },
		reward = { coins = 1500, essence = 150, items = { luck_potion_2 = 1 } } },
	{ id = "s7", label = "Para as Profundezas", desc = "Abra o portal para Crystal Hollow.", goal = { type = "unlock_world", target = "crystal", count = 1 },
		reward = { essence = 100, items = { treasure_tonic = 1 } } },
	{ id = "s8", label = "Caçador de Cristais", desc = "Derrote 10 inimigos em Crystal Hollow.", goal = { type = "defeat_enemy", world = "crystal", count = 10 },
		reward = { essence = 200, items = { evolution_dust = 4 } } },
	{ id = "s9", label = "Despertar", desc = "Evolua um pet.", goal = { type = "evolve", count = 1 },
		reward = { essence = 250, luck = { bonus = 0.25, duration = 900, category = "Mutation" } } },
	{ id = "s10", label = "O Colosso", desc = "Derrote o Prism Titan.", goal = { type = "defeat_boss", target = "prism_titan", count = 1 },
		reward = { coins = 8000, items = { luck_potion_2 = 1, skill_tome = 2 } } },
	{ id = "s11", label = "Acima das Nuvens", desc = "Abra o portal para Skybound Kingdom.", goal = { type = "unlock_world", target = "sky", count = 1 },
		reward = { essence = 400 } },
	{ id = "s12", label = "Domador de Tempestades", desc = "Derrote a Tempest Wyrm.", goal = { type = "defeat_boss", target = "tempest_wyrm", count = 1 },
		reward = { coins = 25000, items = { ascension_core = 1, luck_potion_2 = 1 } } },
	{ id = "s13", label = "Sussurros", desc = "Abra o portal para Whispering Wilds.", goal = { type = "unlock_world", target = "wilds", count = 1 },
		reward = { essence = 900, items = { mutation_elixir = 1 } } },
	{ id = "s14", label = "Floração", desc = "Derrote The Wilderbloom.", goal = { type = "defeat_boss", target = "wilderbloom", count = 1 },
		reward = { coins = 80000, items = { ascension_core = 1, luck_potion_3 = 1 } } },
	{ id = "s15", label = "O Santuário", desc = "Abra o portal para Astral Sanctuary.", goal = { type = "unlock_world", target = "astral", count = 1 },
		reward = { astral = 20 } },
	{ id = "s16", label = "Fim do Vazio", desc = "Derrote o Void Sovereign.", goal = { type = "defeat_boss", target = "void_sovereign", count = 1 },
		reward = { astral = 100, items = { luck_potion_3 = 2 } } },
}

Quests.DailyPool = {
	{ id = "d_hatch", label = "Chocadeira", desc = "Choque 10 ovos.", goal = { type = "hatch", count = 10 },
		reward = { coins = 400, items = { luck_potion_1 = 1 } } },
	{ id = "d_hunt", label = "Caçada", desc = "Derrote 25 inimigos.", goal = { type = "defeat_enemy", count = 25 },
		reward = { essence = 120, items = { evolution_dust = 2 } } },
	{ id = "d_boss", label = "Desafio do Chefe", desc = "Derrote qualquer boss.", goal = { type = "defeat_boss", count = 1 },
		reward = { essence = 250, luck = { bonus = 0.4, duration = 900, category = "Drop" } } },
	{ id = "d_gather", label = "Coletor", desc = "Quebre 60 recursos.", goal = { type = "break_resource", count = 60 },
		reward = { coins = 600, items = { treasure_tonic = 1 } } },
	{ id = "d_treasure", label = "Mapa do Tesouro", desc = "Abra 3 tesouros.", goal = { type = "open_treasure", count = 3 },
		reward = { essence = 150, luck = { bonus = 0.5, duration = 900, category = "Treasure" } } },
	{ id = "d_skill", label = "Treino Tático", desc = "Use 30 habilidades em combate.", goal = { type = "use_ability", count = 30 },
		reward = { essence = 100, items = { skill_tome = 1 } } },
}
Quests.DailyCount = 3

function Quests.findStory(id: string)
	for i, q in ipairs(Quests.Story) do
		if q.id == id then
			return q, i
		end
	end
	return nil, nil
end

function Quests.findDaily(id: string)
	for _, q in ipairs(Quests.DailyPool) do
		if q.id == id then
			return q
		end
	end
	return nil
end

return Quests

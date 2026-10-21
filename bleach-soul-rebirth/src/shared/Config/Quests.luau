-- Missões de história (cadeia) e diárias.
-- Objetivos: Talk{npc}, Kill{enemy,count}, Reach{zone}, Boss{enemy}, Parry{count}, UseAbility{count}, Transform{count}
-- `giver`/`turnIn` = id de NPC ou "Mentor" (resolvido pela facção do jogador). turnIn nil = conclui sozinha.
local Quests = {}

Quests.Story = {
	Awakening = {
		name = "Primeiros Passos",
		desc = "Seu poder despertou. Procure seu mentor na praça de Karakura.",
		objectives = { { type = "Talk", npc = "Mentor", label = "Fale com seu mentor" } },
		rewards = { xp = 60, kan = 50 },
		next = "Purify",
	},
	Purify = {
		name = "Purificação",
		desc = "Hollows rondam as ruas. Elimine cinco deles.",
		giver = "Mentor",
		turnIn = "Mentor",
		objectives = { { type = "Kill", enemy = "HollowGrunt", count = 5, label = "Derrote Hollows" } },
		rewards = { xp = 300, kan = 120, shards = 10, items = { { id = "SoulCandy", qty = 3 } } },
		next = "Training",
	},
	Training = {
		name = "O Campo Subterrâneo",
		desc = "Vá ao campo de treino (portal laranja) e vença três Bonecos de Treino.",
		giver = "Mentor",
		objectives = {
			{ type = "Reach", zone = "Training", label = "Entre no Campo de Treino" },
			{ type = "Kill", enemy = "TrainingPuppet", count = 3, label = "Derrote Bonecos de Treino" },
			{ type = "Parry", count = 1, label = "Apare um golpe (F no momento certo)" },
		},
		rewards = { xp = 350, kan = 100, skillPoints = 1 },
		next = "Release",
	},
	Release = {
		name = "O Nome da Sua Alma",
		desc = "Derrote um Hollow Brutamontes e volte ao mentor para despertar sua primeira liberação.",
		giver = "Mentor",
		turnIn = "Mentor",
		level = 5,
		objectives = { { type = "Kill", enemy = "HollowBrute", count = 1, label = "Derrote um Brutamontes" } },
		rewards = { xp = 500, kan = 200, shards = 10, unlock = "Tier1" },
		next = "Beyond",
	},
	Beyond = {
		name = "Além do Portal",
		desc = "Use a Senkaimon para visitar a Soul Society e libere sua forma (G) uma vez.",
		giver = "Mentor",
		objectives = {
			{ type = "Reach", zone = "SoulSociety", label = "Chegue à Soul Society" },
			{ type = "Transform", count = 1, label = "Ative sua liberação (G)" },
		},
		rewards = { xp = 600, kan = 150, shards = 10 },
		next = "Devourer",
	},
	Devourer = {
		name = "O Devorador",
		desc = "Kurokage aterroriza o norte de Karakura. Derrote-o.",
		giver = "Mentor",
		turnIn = "Mentor",
		level = 7,
		objectives = { { type = "Boss", enemy = "Kurokage", label = "Derrote Kurokage" } },
		rewards = { xp = 1500, kan = 500, shards = 20, skillPoints = 1 },
		next = "Desert",
	},
	Desert = {
		name = "Areias Brancas",
		desc = "Atravesse a Garganta até Hueco Mundo e derrote três Arrancar.",
		giver = "Mentor",
		level = 12,
		objectives = {
			{ type = "Reach", zone = "HuecoMundo", label = "Chegue a Hueco Mundo" },
			{ type = "Kill", enemy = "Arrancar", count = 3, label = "Derrote Arrancar" },
		},
		rewards = { xp = 2500, kan = 600, shards = 15 },
		next = "BankaiTrial",
	},
	BankaiTrial = {
		name = "Materialização",
		desc = "Enfrente a manifestação do seu próprio poder no campo de treino.",
		giver = "Mentor",
		turnIn = "Mentor",
		level = 15,
		objectives = { { type = "Boss", enemy = "InnerSpirit", label = "Derrote a Manifestação Interior" } },
		rewards = { xp = 4000, kan = 1000, shards = 30, skillPoints = 2, unlock = "Tier2" },
		next = "DesertKing",
	},
	DesertKing = {
		name = "O Rei do Deserto",
		desc = "Leonhart governa as ruínas do palácio. Derrube o rei.",
		giver = "Mentor",
		turnIn = "Mentor",
		level = 22,
		objectives = { { type = "Boss", enemy = "VastoLeon", label = "Derrote Leonhart" } },
		rewards = { xp = 9000, kan = 3000, shards = 60, skillPoints = 3 },
	},

	-- Linha paralela (apenas Shinigami): Visored.
	InnerHollowTrial = {
		name = "A Voz Interior",
		desc = "Uma presença Hollow desperta dentro de você. Domine-a no campo de treino.",
		giver = "Mentor",
		turnIn = "Mentor",
		level = 10,
		faction = "Shinigami",
		requiresQuest = "Release",
		objectives = { { type = "Boss", enemy = "InnerHollow", label = "Derrote o Hollow Interior" } },
		rewards = { xp = 2000, kan = 600, shards = 20, unlock = "Mask" },
	},
}

Quests.StoryOrder = { "Awakening", "Purify", "Training", "Release", "Beyond", "Devourer", "Desert", "BankaiTrial", "DesertKing", "InnerHollowTrial" }

-- Diárias: 3 sorteadas por dia (semente = dia UTC + UserId, determinística).
Quests.DailyCount = 3
Quests.DailyPool = {
	DailyHollows = { name = "Patrulha Noturna", objectives = { { type = "Kill", enemy = "HollowGrunt", count = 12, label = "Derrote Hollows" } }, rewards = { xp = 400, kan = 150, shards = 5 } },
	DailyBrutes = { name = "Caça Pesada", objectives = { { type = "Kill", enemy = "HollowBrute", count = 4, label = "Derrote Brutamontes" } }, rewards = { xp = 500, kan = 180, shards = 5 } },
	DailyParry = { name = "Reflexos Afiados", objectives = { { type = "Parry", count = 6, label = "Apare golpes" } }, rewards = { xp = 350, kan = 120, shards = 5 } },
	DailyAbilities = { name = "Disciplina Espiritual", objectives = { { type = "UseAbility", count = 20, label = "Use habilidades" } }, rewards = { xp = 350, kan = 120, shards = 5 } },
	DailyPuppets = { name = "Treino Básico", objectives = { { type = "Kill", enemy = "TrainingPuppet", count = 8, label = "Derrote Bonecos" } }, rewards = { xp = 300, kan = 100, shards = 5 } },
	DailyBoss = { name = "Caçador de Chefes", objectives = { { type = "BossAny", count = 1, label = "Derrote qualquer chefe" } }, rewards = { xp = 800, kan = 300, shards = 10 } },
	DailyTransform = { name = "Liberação Controlada", objectives = { { type = "Transform", count = 3, label = "Libere sua forma" } }, rewards = { xp = 300, kan = 100, shards = 5 } },
}

function Quests.get(id: string?)
	if not id then
		return nil
	end
	return Quests.Story[id] or Quests.DailyPool[id]
end

return Quests

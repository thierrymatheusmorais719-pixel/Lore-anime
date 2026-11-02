-- Mutações visuais raras. A mutação NÃO troca a espécie: o modelo continua o mesmo,
-- só que com materiais, cores e partículas próprias (Builders/MutationVisuals).
--
-- Rolagem ao chocar um ovo:
--   1) chance de mutar = BaseChance (com sorte de categoria "Mutation", limitada por MaxChance)
--   2) se mutou, escolhe UMA mutação por peso entre as permitidas naquele mundo/ovo (`sources`).
-- statBonus: bônus pequeno de atributos (mutação é principalmente cosmética).

local Mutations = {}

Mutations.BaseChance = 0.02 -- 2% por ovo chocado
Mutations.MaxChance = 0.10 -- nunca passa de 10%, com qualquer sorte
Mutations.LuckInfluence = 1

Mutations.Order = { "Golden", "Radiant", "Phantom", "Prismatic", "Ancient", "Astral" }

Mutations.Info = {
	Golden = {
		label = "Golden", weight = 40, statBonus = 0.03,
		color = Color3.fromRGB(255, 200, 60),
		sources = { "any" },
		desc = "Acabamento de ouro polido com brilho suave.",
	},
	Radiant = {
		label = "Radiant", weight = 25, statBonus = 0.03,
		color = Color3.fromRGB(255, 250, 200),
		sources = { "any" },
		desc = "Emite uma luz quente e partículas luminosas.",
	},
	Phantom = {
		label = "Phantom", weight = 15, statBonus = 0.04,
		color = Color3.fromRGB(160, 220, 255),
		sources = { "crystal", "wilds", "astral" },
		desc = "Corpo translúcido envolto em névoa fantasmagórica.",
	},
	Prismatic = {
		label = "Prismatic", weight = 10, statBonus = 0.04,
		color = Color3.fromRGB(255, 140, 240),
		sources = { "crystal", "sky", "astral" },
		desc = "Superfície iridescente que muda de cor com o tempo.",
	},
	Ancient = {
		label = "Ancient", weight = 6, statBonus = 0.05,
		color = Color3.fromRGB(150, 200, 120),
		sources = { "verdant", "wilds" },
		desc = "Pedra ancestral com runas que pulsam.",
	},
	Astral = {
		label = "Astral", weight = 4, statBonus = 0.05,
		color = Color3.fromRGB(140, 120, 255),
		sources = { "astral" },
		desc = "Pele de céu noturno com símbolos cósmicos em órbita.",
	},
}

-- Mutações permitidas para um mundo (regra de obtenção).
function Mutations.allowedFor(worldId: string): { string }
	local list = {}
	for _, id in ipairs(Mutations.Order) do
		local info = Mutations.Info[id]
		for _, src in ipairs(info.sources) do
			if src == "any" or src == worldId then
				table.insert(list, id)
				break
			end
		end
	end
	return list
end

return Mutations

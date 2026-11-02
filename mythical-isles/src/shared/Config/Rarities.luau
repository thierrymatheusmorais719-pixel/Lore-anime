-- Raridades dos pets. A ordem (`rank`) define o que é "mais raro".
--
-- luckInfluence: expoente aplicado ao multiplicador de sorte para entradas desta raridade.
--   0   = a sorte não altera esta raridade (comuns ficam com o que sobrar após renormalizar)
--   1   = recebe o multiplicador inteiro
--   0.6 = recebe apenas parte (Celestial é propositalmente menos afetado)
-- maxChance: probabilidade máxima POR ROLAGEM que uma entrada desta raridade pode atingir,
--   mesmo com toda a sorte possível. É o que impede garantias que não foram definidas.
-- statMult: multiplicador de atributos de combate.
-- announce: "none" | "server" | "global" (anúncio entre servidores via MessagingService).

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Celestial" }

Rarities.Info = {
	Common = { rank = 1, color = Color3.fromRGB(190, 196, 204), luckInfluence = 0, maxChance = 1, statMult = 1.0, announce = "none", label = "Comum" },
	Uncommon = { rank = 2, color = Color3.fromRGB(110, 214, 120), luckInfluence = 0, maxChance = 1, statMult = 1.12, announce = "none", label = "Incomum" },
	Rare = { rank = 3, color = Color3.fromRGB(80, 160, 255), luckInfluence = 0.5, maxChance = 0.5, statMult = 1.26, announce = "none", label = "Raro" },
	Epic = { rank = 4, color = Color3.fromRGB(176, 98, 255), luckInfluence = 0.75, maxChance = 0.25, statMult = 1.42, announce = "none", label = "Épico" },
	Legendary = { rank = 5, color = Color3.fromRGB(255, 186, 48), luckInfluence = 1, maxChance = 0.15, statMult = 1.6, announce = "server", label = "Lendário" },
	Mythic = { rank = 6, color = Color3.fromRGB(255, 72, 120), luckInfluence = 1, maxChance = 0.05, statMult = 1.78, announce = "server", label = "Mítico" },
	Secret = { rank = 7, color = Color3.fromRGB(40, 40, 52), accent = Color3.fromRGB(235, 235, 255), luckInfluence = 1, maxChance = 0.01, statMult = 1.9, announce = "global", label = "SECRET" },
	Celestial = { rank = 8, color = Color3.fromRGB(150, 230, 255), accent = Color3.fromRGB(255, 240, 180), luckInfluence = 0.6, maxChance = 0.002, statMult = 2.0, announce = "global", label = "CELESTIAL" },
}

function Rarities.rank(name: string): number
	local info = Rarities.Info[name]
	return info and info.rank or 0
end

function Rarities.isNotable(name: string): boolean
	return Rarities.rank(name) >= Rarities.Info.Legendary.rank
end

return Rarities

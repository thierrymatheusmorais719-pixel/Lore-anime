-- Facções jogáveis. `base` define as habilidades Z/X/C iniciais; cada poder (Powers.luau)
-- sobrescreve espaços conforme a forma (Tier1 = Shikai/Resurrección..., Tier2 = Bankai/...).
local Factions = {}

Factions.Order = { "Shinigami", "Hollow", "Quincy", "Fullbringer" }

Factions.Shinigami = {
	id = "Shinigami",
	displayName = "Shinigami",
	kanji = "死神",
	element = "Reiatsu",
	color = Color3.fromRGB(120, 190, 255),
	description = "Guardiões das almas. Zanpakutō com Shikai e Bankai, Kidō e Shunpo.",
	base = { Z = "Raika", X = "SenkaStrike", C = "ReiatsuBurst" },
	weapon = {
		style = "Katana",
		length = 4.2,
		blade = Color3.fromRGB(205, 210, 220),
		guard = Color3.fromRGB(40, 35, 30),
	},
	outfit = { robe = Color3.fromRGB(18, 18, 22), trim = Color3.fromRGB(235, 235, 240), cape = false },
	forms = {
		Tier1 = { name = "Shikai", kanji = "始解", requiredLevel = 5, drainPerSecond = 1.4, channel = 0.9 },
		Tier2 = { name = "Bankai", kanji = "卍解", requiredLevel = 15, drainPerSecond = 3.2, channel = 1.7 },
	},
	maskAvailable = true,
	mentor = "MentorShinigami",
	startZone = "Karakura",
}

Factions.Hollow = {
	id = "Hollow",
	displayName = "Hollow / Arrancar",
	kanji = "虚",
	element = "Hollow",
	color = Color3.fromRGB(225, 40, 60),
	description = "Almas famintas que evoluem até Arrancar. Cero, Sonído e Resurrección.",
	base = { Z = "Cero", X = "Sonido", C = "HierroRoar" },
	weapon = {
		style = "Claws",
		length = 2.4,
		blade = Color3.fromRGB(240, 236, 225),
		guard = Color3.fromRGB(30, 10, 10),
	},
	outfit = {
		robe = Color3.fromRGB(235, 232, 225),
		trim = Color3.fromRGB(20, 20, 20),
		cape = false,
		hollowHole = true,
	},
	forms = {
		Tier1 = { name = "Resurrección", kanji = "帰刃", requiredLevel = 5, drainPerSecond = 1.4, channel = 0.9 },
		Tier2 = { name = "Segunda Etapa", kanji = "第二", requiredLevel = 15, drainPerSecond = 3.2, channel = 1.7 },
	},
	maskAvailable = false,
	mentor = "MentorHollow",
	startZone = "Karakura",
}

Factions.Quincy = {
	id = "Quincy",
	displayName = "Quincy",
	kanji = "滅却師",
	element = "Holy",
	color = Color3.fromRGB(150, 205, 255),
	description = "Arqueiros que dominam o Reishi do ambiente. Flechas sagradas e Blut.",
	base = { Z = "HeiligVolley", X = "Hirenkyaku", C = "BlutVene" },
	weapon = {
		style = "LightBlade",
		length = 3.6,
		blade = Color3.fromRGB(170, 220, 255),
		guard = Color3.fromRGB(230, 235, 245),
	},
	outfit = { robe = Color3.fromRGB(240, 242, 248), trim = Color3.fromRGB(60, 110, 200), cape = true },
	forms = {
		Tier1 = { name = "Licht Form", kanji = "光", requiredLevel = 5, drainPerSecond = 1.4, channel = 0.9 },
		Tier2 = { name = "Vollständig", kanji = "完聖体", requiredLevel = 15, drainPerSecond = 3.2, channel = 1.7 },
	},
	maskAvailable = false,
	mentor = "MentorQuincy",
	startZone = "Karakura",
}

Factions.Fullbringer = {
	id = "Fullbringer",
	displayName = "Fullbringer",
	kanji = "完現術",
	element = "Verdant",
	color = Color3.fromRGB(110, 255, 170),
	description = "Humanos que despertam a alma dos objetos. Força bruta e manipulação.",
	base = { Z = "BringerRush", X = "ChainLash", C = "FullbringOverdrive" },
	weapon = {
		style = "Gauntlet",
		length = 1.6,
		blade = Color3.fromRGB(70, 75, 85),
		guard = Color3.fromRGB(110, 255, 170),
	},
	outfit = { robe = Color3.fromRGB(45, 50, 60), trim = Color3.fromRGB(110, 255, 170), cape = false },
	forms = {
		Tier1 = { name = "Fullbring", kanji = "完現", requiredLevel = 5, drainPerSecond = 1.4, channel = 0.9 },
		Tier2 = {
			name = "Fullbring Completo",
			kanji = "完全",
			requiredLevel = 15,
			drainPerSecond = 3.2,
			channel = 1.7,
		},
	},
	maskAvailable = false,
	mentor = "MentorFullbringer",
	startZone = "Karakura",
}

Factions.Mask = {
	name = "Máscara Hollow",
	kanji = "仮面",
	requiredLevel = 10,
	duration = 20,
	cooldown = 45,
	damageMultiplier = 1.25,
	speedBonus = 4,
	overrides = { Z = "MaskCero" },
	channel = 0.6,
}

function Factions.get(id: string?)
	if id == nil then
		return nil
	end
	local faction = Factions[id]
	if type(faction) == "table" and faction.id == id then
		return faction
	end
	return nil
end

return Factions

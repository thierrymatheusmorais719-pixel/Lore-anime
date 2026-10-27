-- Facções jogáveis. `base` define as habilidades Z/X/C iniciais; cada poder (Powers.luau)
-- sobrescreve espaços conforme a forma (Tier1 = Shikai/Resurrección..., Tier2 = Bankai/...).
-- Tier2 tem cutscene (cliente: ReleaseCutscene): `channel` = até a tela branca (forma aplicada),
-- `reveal` = revelação em preto e branco depois dela. Invulnerável nos dois trechos.
local Factions = {}

-- Só duas classes para escolher: Humano (evolui para Shinigami) e Hollow (evolui até Arrancar).
-- Quincy e Fullbringer continuam definidos (poderes antigos, perfis migrados), mas não aparecem.
Factions.Order = { "Shinigami", "Hollow" }

-- Estágios por nível dentro de cada classe. Cada estágio pode trocar o nome/kanji mostrado, as
-- habilidades de base (as travadas ficam vazias), a arma e o traje (`outfit` = arquétipo do
-- NpcStyle). Bônus de atributos (`power`) multiplicam dano e vida derivados.
Factions.Stages = {
	Shinigami = {
		{
			id = "Human",
			level = 1,
			name = "Humano",
			kanji = "人",
			title = "Humano com Reiatsu",
			base = { C = "ReiatsuBurst" },
			weapon = {
				style = "Katana",
				length = 3.6,
				blade = Color3.fromRGB(176, 132, 86),
				guard = Color3.fromRGB(70, 46, 32),
			},
			outfit = "school",
			power = 1,
		},
		{
			id = "Shinigami",
			level = 5,
			name = "Shinigami",
			kanji = "死神",
			title = "Despertou como Shinigami",
			outfit = "shihakusho",
			power = 1.15,
		},
	},
	Hollow = {
		{
			id = "Hollow",
			level = 1,
			name = "Hollow",
			kanji = "虚",
			title = "Alma faminta",
			base = { C = "HierroRoar" },
			weapon = {
				style = "Claws",
				length = 1.8,
				blade = Color3.fromRGB(236, 230, 214),
				guard = Color3.fromRGB(30, 10, 10),
			},
			outfit = "hollowSpawn",
			power = 1,
		},
		{
			id = "Menos",
			level = 5,
			name = "Menos Grande",
			kanji = "大虚",
			title = "Evoluiu para Menos",
			base = { Z = "Cero", C = "HierroRoar" },
			weapon = {
				style = "Claws",
				length = 2.1,
				blade = Color3.fromRGB(236, 230, 214),
				guard = Color3.fromRGB(30, 10, 10),
			},
			outfit = "menos",
			power = 1.1,
		},
		{
			id = "Adjuchas",
			level = 10,
			name = "Adjuchas",
			kanji = "中級",
			title = "Evoluiu para Adjuchas",
			weapon = {
				style = "Claws",
				length = 2.4,
				blade = Color3.fromRGB(240, 236, 225),
				guard = Color3.fromRGB(30, 10, 10),
			},
			outfit = "adjuchas",
			power = 1.2,
		},
		{
			id = "VastoLorde",
			level = 15,
			name = "Vasto Lorde",
			kanji = "最上級",
			title = "Evoluiu para Vasto Lorde",
			weapon = {
				style = "Claws",
				length = 2.8,
				blade = Color3.fromRGB(246, 244, 238),
				guard = Color3.fromRGB(120, 10, 20),
			},
			outfit = "vastoLorde",
			power = 1.3,
		},
		{
			id = "Arrancar",
			level = 20,
			name = "Arrancar",
			kanji = "破面",
			title = "Arrancou a máscara: Arrancar",
			outfit = "arrancar",
			power = 1.35,
		},
	},
}

-- Estágio atual da classe `id` no nível `level` (e o índice dele)
function Factions.stage(id: string?, level: number?): (any, number)
	local stages = id and Factions.Stages[id]
	if not stages then
		return nil, 0
	end
	local current, index = stages[1], 1
	for i, stage in stages do
		if (level or 1) >= stage.level then
			current, index = stage, i
		end
	end
	return current, index
end

Factions.Shinigami = {
	id = "Shinigami",
	displayName = "Humano",
	kanji = "死神",
	element = "Reiatsu",
	color = Color3.fromRGB(120, 190, 255),
	description = "Começa como humano com Reiatsu e desperta como Shinigami no nível 5: Zanpakutō, Shikai, Bankai, Kidō e Shunpo.",
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
		Tier2 = {
			name = "Bankai",
			kanji = "卍解",
			requiredLevel = 15,
			drainPerSecond = 3.2,
			channel = 9,
			reveal = 4.6,
			cutscene = true,
		},
	},
	maskAvailable = true,
	mentor = "MentorShinigami",
	startZone = "Karakura",
}

Factions.Hollow = {
	id = "Hollow",
	displayName = "Hollow",
	kanji = "虚",
	element = "Hollow",
	color = Color3.fromRGB(225, 40, 60),
	description = "Alma faminta que evolui com o tempo: Hollow → Menos → Adjuchas → Vasto Lorde → Arrancar.",
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
		-- só o Arrancar (nível 20) libera a Resurrección; a Segunda Etapa vem depois
		Tier1 = { name = "Resurrección", kanji = "帰刃", requiredLevel = 20, drainPerSecond = 1.4, channel = 0.9 },
		Tier2 = {
			name = "Segunda Etapa",
			kanji = "第二",
			requiredLevel = 30,
			drainPerSecond = 3.2,
			channel = 9,
			reveal = 4.6,
			cutscene = true,
		},
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
		Tier2 = {
			name = "Vollständig",
			kanji = "完聖体",
			requiredLevel = 15,
			drainPerSecond = 3.2,
			channel = 9,
			reveal = 4.6,
			cutscene = true,
		},
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
			channel = 9,
			reveal = 4.6,
			cutscene = true,
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

-- Poderes por facção (Zanpakutō, Resurrección, Schrift, Fullbring) com raridade.
-- A raridade dá um bônus pequeno; todo poder é viável e pode ser comprado diretamente com Fragmentos.
local Powers = {}

Powers.Rarities = {
	Common = { order = 1, name = "Comum", color = Color3.fromRGB(190, 195, 205), multiplier = 1.0, weight = 60 },
	Rare = { order = 2, name = "Raro", color = Color3.fromRGB(90, 160, 255), multiplier = 1.04, weight = 28 },
	Epic = { order = 3, name = "Épico", color = Color3.fromRGB(190, 90, 255), multiplier = 1.08, weight = 10 },
	Legendary = { order = 4, name = "Lendário", color = Color3.fromRGB(255, 200, 60), multiplier = 1.12, weight = 2 },
}

Powers.Gacha = {
	rollCost = 10, -- Fragmentos Espirituais por invocação
	directCost = 60, -- compra direta de qualquer poder da facção (progressão sem sorte)
	epicPity = 10, -- garante Épico+ a cada 10 invocações sem Épico
	legendaryPity = 30, -- garante o melhor disponível a cada 30 sem Lendário
}

Powers.List = {
	-- Shinigami
	Enjin = {
		faction = "Shinigami",
		rarity = "Common",
		element = "Fire",
		name = "Enjin",
		releaseCommand = "Consuma tudo, Enjin!",
		tier1 = {
			name = "Enjin",
			abilities = { Z = "EnjinBlade", X = "Kagero" },
			weapon = { style = "Katana", length = 4.6, blade = Color3.fromRGB(255, 160, 90), glow = true },
		},
		tier2 = {
			name = "Enjin Kagutsuchi",
			abilities = { Z = "SolarWave", V = "KagutsuchiBlackSun" },
			weapon = { style = "Nodachi", length = 6.2, blade = Color3.fromRGB(40, 20, 15), glow = true },
			coat = Color3.fromRGB(25, 10, 8),
		},
	},
	Hyoketsu = {
		faction = "Shinigami",
		rarity = "Rare",
		element = "Ice",
		name = "Hyōketsu",
		releaseCommand = "Congele o firmamento, Hyōketsu!",
		tier1 = {
			name = "Hyōketsu",
			abilities = { Z = "Tsurara", X = "Hyoheki" },
			weapon = { style = "Katana", length = 4.8, blade = Color3.fromRGB(190, 240, 255), glow = true },
		},
		tier2 = {
			name = "Shirogane Hyōketsu Rōjō",
			abilities = { Z = "CrystalAvalanche", V = "EternalIceAge" },
			weapon = { style = "Nodachi", length = 6.4, blade = Color3.fromRGB(215, 250, 255), glow = true },
			coat = Color3.fromRGB(230, 245, 255),
		},
	},
	Raijinmaru = {
		faction = "Shinigami",
		rarity = "Epic",
		element = "Lightning",
		name = "Raijinmaru",
		releaseCommand = "Ruja, Raijinmaru!",
		tier1 = {
			name = "Raijinmaru",
			abilities = { Z = "Raigeki", X = "Senko" },
			weapon = { style = "Katana", length = 4.6, blade = Color3.fromRGB(255, 235, 140), glow = true },
		},
		tier2 = {
			name = "Raijin Hōkō-maru",
			abilities = { Z = "ThunderStorm", V = "ThunderJudgement" },
			weapon = { style = "Katana", length = 5, blade = Color3.fromRGB(255, 240, 160), glow = true, dual = true },
			coat = Color3.fromRGB(20, 20, 35),
		},
	},
	Tsukikage = {
		faction = "Shinigami",
		rarity = "Legendary",
		element = "Moon",
		name = "Tsukikage",
		releaseCommand = "Ilumine a noite eterna, Tsukikage!",
		tier1 = {
			name = "Tsukikage",
			abilities = { Z = "Gekko", X = "TsukiNoWa" },
			weapon = { style = "Nodachi", length = 5.6, blade = Color3.fromRGB(225, 232, 255), glow = true },
		},
		tier2 = {
			name = "Kōgetsu Tsukikage",
			abilities = { Z = "BlackCrescent", V = "MoonlessHunt" },
			weapon = { style = "Katana", length = 4.8, blade = Color3.fromRGB(15, 12, 22), glow = true },
			coat = Color3.fromRGB(10, 8, 14),
		},
	},

	-- Hollow / Arrancar
	ColmilloNegro = {
		faction = "Hollow",
		rarity = "Common",
		element = "Shadow",
		name = "Colmillo Negro",
		releaseCommand = "Devore, Colmillo Negro!",
		tier1 = {
			name = "Colmillo Negro",
			abilities = { Z = "ShadowClaw", X = "BeastLeap" },
			weapon = { style = "Claws", length = 3.2, blade = Color3.fromRGB(30, 20, 45), glow = true },
		},
		tier2 = {
			name = "Colmillo Negro: Segunda Etapa",
			abilities = { Z = "CeroOscuro", V = "EternalNight" },
			weapon = { style = "Claws", length = 4.2, blade = Color3.fromRGB(15, 8, 25), glow = true },
			coat = Color3.fromRGB(15, 10, 25),
		},
	},
	EscorpionArena = {
		faction = "Hollow",
		rarity = "Rare",
		element = "Sand",
		name = "Escorpión de Arena",
		releaseCommand = "Envenene, Escorpión de Arena!",
		tier1 = {
			name = "Escorpión de Arena",
			abilities = { Z = "Stinger", X = "Sandstorm" },
			weapon = { style = "Claws", length = 3.2, blade = Color3.fromRGB(230, 195, 120), glow = true },
		},
		tier2 = {
			name = "Escorpión: Segunda Etapa",
			abilities = { Z = "LivingDune", V = "InfiniteDesert" },
			weapon = { style = "Claws", length = 4.2, blade = Color3.fromRGB(200, 160, 80), glow = true },
			coat = Color3.fromRGB(120, 90, 50),
		},
	},
	HalconCarmesi = {
		faction = "Hollow",
		rarity = "Epic",
		element = "Blood",
		name = "Halcón Carmesí",
		releaseCommand = "Dilacere, Halcón Carmesí!",
		tier1 = {
			name = "Halcón Carmesí",
			abilities = { Z = "CrimsonCero", X = "Swoop" },
			weapon = { style = "Claws", length = 3.4, blade = Color3.fromRGB(200, 30, 50), glow = true },
		},
		tier2 = {
			name = "Halcón: Segunda Etapa",
			abilities = { Z = "BloodFeathers", V = "GranReyCarmesi" },
			weapon = { style = "Claws", length = 4.4, blade = Color3.fromRGB(150, 10, 30), glow = true },
			coat = Color3.fromRGB(60, 5, 15),
		},
	},

	-- Quincy
	Kranich = {
		faction = "Quincy",
		rarity = "Common",
		element = "Holy",
		name = "Kranich",
		releaseCommand = "Desperte, asas do Kranich!",
		tier1 = {
			name = "Kranich",
			abilities = { Z = "LichtRegen", X = "SprengerPfeil" },
			weapon = { style = "LightBlade", length = 4.2, blade = Color3.fromRGB(190, 230, 255), glow = true },
		},
		tier2 = {
			name = "Vollständig: Kranich",
			abilities = { Z = "HeiligLanze", V = "JudgementWings" },
			weapon = { style = "LightBlade", length = 5.6, blade = Color3.fromRGB(220, 240, 255), glow = true },
			coat = Color3.fromRGB(245, 248, 255),
		},
	},
	Loewe = {
		faction = "Quincy",
		rarity = "Rare",
		element = "Gold",
		name = "Löwe",
		releaseCommand = "Ruja, coração do Löwe!",
		tier1 = {
			name = "Löwe",
			abilities = { Z = "LionArrow", X = "LionRoar" },
			weapon = { style = "LightBlade", length = 4.4, blade = Color3.fromRGB(255, 220, 120), glow = true },
		},
		tier2 = {
			name = "Vollständig: Löwe",
			abilities = { Z = "GoldenRain", V = "KingLion" },
			weapon = { style = "LightBlade", length = 5.8, blade = Color3.fromRGB(255, 235, 160), glow = true },
			coat = Color3.fromRGB(255, 240, 200),
		},
	},
	Eisvogel = {
		faction = "Quincy",
		rarity = "Epic",
		element = "Time",
		name = "Eisvogel",
		releaseCommand = "Pare o tempo, Eisvogel!",
		tier1 = {
			name = "Eisvogel",
			abilities = { Z = "TimeArrows", X = "EternityStep" },
			weapon = { style = "LightBlade", length = 4.4, blade = Color3.fromRGB(200, 180, 255), glow = true },
		},
		tier2 = {
			name = "Vollständig: Eisvogel",
			abilities = { Z = "TimeFracture", V = "EternalMoment" },
			weapon = {
				style = "LightBlade",
				length = 5.8,
				blade = Color3.fromRGB(215, 195, 255),
				glow = true,
				dual = true,
			},
			coat = Color3.fromRGB(70, 55, 120),
		},
	},

	-- Fullbringer
	Ampulheta = {
		faction = "Fullbringer",
		rarity = "Common",
		element = "Gold",
		name = "Ampulheta de Ferro",
		releaseCommand = "Gire, Ampulheta de Ferro!",
		tier1 = {
			name = "Ampulheta de Ferro",
			abilities = { Z = "SandsOfTime", X = "Rewind" },
			weapon = { style = "Gauntlet", length = 1.8, blade = Color3.fromRGB(200, 170, 90), glow = true },
		},
		tier2 = {
			name = "Ampulheta: Fullbring Completo",
			abilities = { Z = "EndlessGrains", V = "ZeroHour" },
			weapon = { style = "Katana", length = 4.4, blade = Color3.fromRGB(230, 200, 110), glow = true },
			coat = Color3.fromRGB(70, 55, 30),
		},
	},
	CorrenteEscarlate = {
		faction = "Fullbringer",
		rarity = "Rare",
		element = "Chain",
		name = "Corrente Escarlate",
		releaseCommand = "Prenda o mundo, Corrente Escarlate!",
		tier1 = {
			name = "Corrente Escarlate",
			abilities = { Z = "ChainWhip", X = "ChainCyclone" },
			weapon = { style = "Gauntlet", length = 1.8, blade = Color3.fromRGB(180, 60, 30), glow = true },
		},
		tier2 = {
			name = "Corrente: Fullbring Completo",
			abilities = { Z = "LinkPrison", V = "ThousandChains" },
			weapon = { style = "Gauntlet", length = 2.2, blade = Color3.fromRGB(220, 80, 30), glow = true, dual = true },
			coat = Color3.fromRGB(60, 15, 10),
		},
	},
	PunhoEsmeralda = {
		faction = "Fullbringer",
		rarity = "Epic",
		element = "Verdant",
		name = "Punho Esmeralda",
		releaseCommand = "Desperte, Punho Esmeralda!",
		tier1 = {
			name = "Punho Esmeralda",
			abilities = { Z = "EmeraldImpact", X = "SeismicBlow" },
			weapon = { style = "Gauntlet", length = 2, blade = Color3.fromRGB(90, 230, 150), glow = true },
		},
		tier2 = {
			name = "Esmeralda: Fullbring Completo",
			abilities = { Z = "GreenMeteor", V = "EmeraldEnd" },
			weapon = {
				style = "Gauntlet",
				length = 2.4,
				blade = Color3.fromRGB(120, 255, 180),
				glow = true,
				dual = true,
			},
			coat = Color3.fromRGB(15, 50, 35),
		},
	},
}

-- Poder inicial garantido de cada facção (o jogador sempre começa com um).
Powers.Starter = {
	Shinigami = "Enjin",
	Hollow = "ColmilloNegro",
	Quincy = "Kranich",
	Fullbringer = "Ampulheta",
}

function Powers.get(id: string?)
	if id == nil then
		return nil
	end
	return Powers.List[id]
end

function Powers.forFaction(faction: string): { string }
	local ids = {}
	for id, power in Powers.List do
		if power.faction == faction then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local ra = Powers.Rarities[Powers.List[a].rarity].order
		local rb = Powers.Rarities[Powers.List[b].rarity].order
		if ra == rb then
			return a < b
		end
		return ra < rb
	end)
	return ids
end

return Powers

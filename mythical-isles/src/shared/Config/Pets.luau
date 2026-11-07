-- Espécies de pets. Todas são originais.
--
-- role: Tank | Attacker | Support | Explorer | Specialist (ver Config/Combat.Roles)
-- ability: habilidade de combate (Config/Abilities)
-- perk: bônus passivo enquanto o pet está na equipe (opcional)
--   { kind = "luck", category = "Treasure"|"Drop"|"Mutation"|"PetVariant"|"SpecialEgg"|"SecretEvent"|"All", bonus = 0.05 }
--   { kind = "coins", bonus = 0.1 }
-- model: parâmetros do construtor procedural (Builders/CreatureBuilder)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Pets = {}

Pets.Species = {
	-- VERDANT HAVEN ---------------------------------------------------------------
	mossling = {
		name = "Mossling", world = "verdant", rarity = "Common", role = "Tank", ability = "guard_shield",
		desc = "Bolinha de musgo teimosa que aguenta qualquer pancada.",
		model = { rig = "quad", size = 1.0, body = rgb(92, 140, 70), belly = rgb(170, 200, 120), accent = rgb(230, 240, 150), eye = rgb(30, 30, 30),
			ears = "round", back = "moss", tail = "nub", stocky = true },
	},
	leafwing = {
		name = "Leafwing Finch", world = "verdant", rarity = "Uncommon", role = "Explorer", ability = "treasure_sense",
		desc = "Pássaro de asas de folha que fareja tesouros enterrados.",
		perk = { kind = "luck", category = "Treasure", bonus = 0.05 },
		model = { rig = "flyer", size = 0.9, body = rgb(120, 190, 90), belly = rgb(240, 230, 170), accent = rgb(250, 160, 60), eye = rgb(20, 20, 20),
			wings = "leaf", tail = "leaf", crest = true },
	},
	thornpup = {
		name = "Thornpup", world = "verdant", rarity = "Rare", role = "Attacker", ability = "charge",
		desc = "Filhote espinhoso que avança sem pensar duas vezes.",
		model = { rig = "quad", size = 1.05, body = rgb(110, 80, 56), belly = rgb(180, 150, 110), accent = rgb(120, 200, 90), eye = rgb(255, 230, 120),
			ears = "pointy", back = "thorns", tail = "thin" },
	},
	bloomfox = {
		name = "Bloomfox", world = "verdant", rarity = "Epic", role = "Support", ability = "mend",
		desc = "Raposa florida cujo pólen fecha ferimentos.",
		model = { rig = "quad", size = 1.1, body = rgb(240, 150, 120), belly = rgb(255, 235, 220), accent = rgb(255, 120, 170), eye = rgb(40, 30, 30),
			ears = "pointy", tail = "fluffy", back = "flowers" },
	},
	grovekin = {
		name = "Grovekin", world = "verdant", rarity = "Legendary", role = "Specialist", ability = "root_snare",
		desc = "Pequeno guardião de casca que prende inimigos com raízes.",
		model = { rig = "biped", size = 1.2, body = rgb(120, 86, 60), belly = rgb(160, 120, 80), accent = rgb(140, 230, 110), eye = rgb(170, 255, 140),
			horns = "antlers", back = "moss", glowEyes = true },
	},
	verdigris_wisp = {
		name = "Verdigris Wisp", world = "verdant", rarity = "Mythic", role = "Support", ability = "haste",
		desc = "Uma luz antiga da floresta. Quase ninguém a viu de perto.",
		perk = { kind = "luck", category = "Mutation", bonus = 0.05 },
		model = { rig = "floater", size = 1.1, body = rgb(70, 170, 140), belly = rgb(200, 255, 230), accent = rgb(140, 255, 200), eye = rgb(255, 255, 255),
			orbit = "leaves", glowEyes = true },
	},

	-- CRYSTAL HOLLOW --------------------------------------------------------------
	shardmite = {
		name = "Shardmite", world = "crystal", rarity = "Common", role = "Tank", ability = "guard_shield",
		desc = "Besouro de carapaça de quartzo.",
		model = { rig = "quad", size = 0.95, body = rgb(80, 90, 120), belly = rgb(60, 66, 90), accent = rgb(140, 220, 255), eye = rgb(140, 220, 255),
			back = "crystals", ears = nil, stocky = true, glowEyes = true },
	},
	glimmerbat = {
		name = "Glimmerbat", world = "crystal", rarity = "Uncommon", role = "Attacker", ability = "energy_bolt",
		desc = "Morcego que reflete a luz das cavernas.",
		model = { rig = "flyer", size = 0.9, body = rgb(70, 60, 100), belly = rgb(110, 100, 150), accent = rgb(200, 150, 255), eye = rgb(255, 220, 255),
			wings = "membrane", ears = "long", glowEyes = true },
	},
	geodeling = {
		name = "Geodeling", world = "crystal", rarity = "Rare", role = "Tank", ability = "shockwave",
		desc = "Golem de bolso com um coração de ametista.",
		model = { rig = "golem", size = 1.0, body = rgb(110, 100, 120), belly = rgb(80, 70, 90), accent = rgb(190, 110, 255), eye = rgb(220, 170, 255),
			back = "crystals", glowEyes = true },
	},
	prismcat = {
		name = "Prismcat", world = "crystal", rarity = "Epic", role = "Attacker", ability = "sunder",
		desc = "Felino de cristal que estilhaça armaduras.",
		model = { rig = "quad", size = 1.05, body = rgb(200, 230, 255), belly = rgb(240, 250, 255), accent = rgb(120, 200, 255), eye = rgb(60, 140, 255),
			ears = "pointy", tail = "crystal", glassy = true },
	},
	quartz_drake = {
		name = "Quartz Drake", world = "crystal", rarity = "Legendary", role = "Specialist", ability = "energy_bolt",
		desc = "Dragãozinho que cospe fragmentos cintilantes.",
		model = { rig = "flyer", size = 1.25, body = rgb(90, 170, 200), belly = rgb(200, 240, 255), accent = rgb(255, 120, 220), eye = rgb(255, 240, 120),
			wings = "crystal", horns = "crystal", tail = "crystal", drake = true },
	},
	echo_geode = {
		name = "Echo Geode", world = "crystal", rarity = "Mythic", role = "Specialist", ability = "sunder",
		desc = "Um cristal que repete os sons da caverna.",
		perk = { kind = "luck", category = "Drop", bonus = 0.05 },
		model = { rig = "floater", size = 1.1, body = rgb(60, 50, 90), belly = rgb(200, 160, 255), accent = rgb(170, 120, 255), eye = rgb(255, 255, 255),
			orbit = "shards", glowEyes = true },
	},

	-- SKYBOUND KINGDOM ------------------------------------------------------------
	puffcloud = {
		name = "Puffcloud", world = "sky", rarity = "Common", role = "Support", ability = "mend",
		desc = "Nuvem fofa que chove remédio.",
		model = { rig = "floater", size = 1.0, body = rgb(245, 248, 255), belly = rgb(220, 230, 250), accent = rgb(170, 210, 255), eye = rgb(40, 50, 70),
			orbit = "puffs" },
	},
	galepup = {
		name = "Galepup", world = "sky", rarity = "Uncommon", role = "Explorer", ability = "treasure_sense",
		desc = "Cachorrinho com orelhas que captam o vento.",
		perk = { kind = "luck", category = "Treasure", bonus = 0.06 },
		model = { rig = "quad", size = 0.95, body = rgb(230, 230, 240), belly = rgb(255, 255, 255), accent = rgb(120, 190, 255), eye = rgb(30, 40, 60),
			ears = "long", tail = "cloud" },
	},
	zephyr_hawk = {
		name = "Zephyr Hawk", world = "sky", rarity = "Rare", role = "Attacker", ability = "charge",
		desc = "Falcão que mergulha mais rápido que o trovão.",
		model = { rig = "flyer", size = 1.1, body = rgb(90, 110, 150), belly = rgb(230, 230, 240), accent = rgb(255, 200, 80), eye = rgb(255, 200, 60),
			wings = "feather", tail = "feather", crest = true },
	},
	thunder_ram = {
		name = "Thunder Ram", world = "sky", rarity = "Epic", role = "Tank", ability = "shockwave",
		desc = "Carneiro de lã carregada de estática.",
		model = { rig = "quad", size = 1.2, body = rgb(235, 235, 240), belly = rgb(190, 190, 200), accent = rgb(255, 230, 90), eye = rgb(30, 30, 40),
			horns = "curled", back = "wool", stocky = true },
	},
	aurora_griffin = {
		name = "Aurora Griffin", world = "sky", rarity = "Legendary", role = "Specialist", ability = "haste",
		desc = "Grifo cujas penas mudam de cor ao amanhecer.",
		model = { rig = "quad", size = 1.3, body = rgb(250, 220, 160), belly = rgb(255, 245, 220), accent = rgb(120, 255, 210), eye = rgb(40, 120, 200),
			wings = "feather", tail = "fluffy", crest = true },
	},
	skyborn_seraph = {
		name = "Skyborn Seraph", world = "sky", rarity = "Secret", role = "Support", ability = "mend",
		desc = "Dizem que só aparece acima das nuvens mais altas.",
		perk = { kind = "luck", category = "PetVariant", bonus = 0.04 },
		model = { rig = "flyer", size = 1.15, body = rgb(255, 250, 235), belly = rgb(255, 255, 255), accent = rgb(255, 215, 120), eye = rgb(120, 180, 255),
			wings = "seraph", halo = true, glowEyes = true },
	},

	-- WHISPERING WILDS ------------------------------------------------------------
	mistmoth = {
		name = "Mistmoth", world = "wilds", rarity = "Common", role = "Explorer", ability = "treasure_sense",
		desc = "Mariposa que segue o brilho dos cogumelos.",
		perk = { kind = "luck", category = "Treasure", bonus = 0.04 },
		model = { rig = "flyer", size = 0.9, body = rgb(140, 130, 170), belly = rgb(200, 190, 220), accent = rgb(170, 255, 230), eye = rgb(20, 20, 30),
			wings = "moth", ears = "feelers" },
	},
	hollow_hare = {
		name = "Hollow Hare", world = "wilds", rarity = "Uncommon", role = "Support", ability = "haste",
		desc = "Lebre silenciosa que corre entre os troncos ocos.",
		model = { rig = "quad", size = 0.9, body = rgb(120, 110, 100), belly = rgb(220, 210, 200), accent = rgb(170, 140, 255), eye = rgb(30, 20, 40),
			ears = "long", tail = "fluffy" },
	},
	fernsnake = {
		name = "Fernsnake", world = "wilds", rarity = "Rare", role = "Attacker", ability = "energy_bolt",
		desc = "Serpente de samambaia que cospe esporos.",
		model = { rig = "serpent", size = 1.0, body = rgb(70, 130, 80), belly = rgb(200, 220, 150), accent = rgb(220, 255, 140), eye = rgb(255, 200, 60),
			back = "fronds" },
	},
	dusk_lynx = {
		name = "Dusk Lynx", world = "wilds", rarity = "Epic", role = "Attacker", ability = "charge",
		desc = "Felino do crepúsculo com pelagem estrelada.",
		model = { rig = "quad", size = 1.15, body = rgb(80, 60, 110), belly = rgb(150, 130, 180), accent = rgb(255, 180, 90), eye = rgb(255, 210, 90),
			ears = "tufted", tail = "thin", glowEyes = true },
	},
	elder_owl = {
		name = "Elder Owl", world = "wilds", rarity = "Legendary", role = "Support", ability = "mend",
		desc = "Coruja anciã que conhece todos os caminhos.",
		perk = { kind = "luck", category = "SecretEvent", bonus = 0.05 },
		model = { rig = "flyer", size = 1.25, body = rgb(130, 100, 70), belly = rgb(220, 200, 160), accent = rgb(255, 220, 140), eye = rgb(255, 200, 60),
			wings = "feather", ears = "tufted", glowEyes = true },
	},
	moonveil_kitsune = {
		name = "Moonveil Kitsune", world = "wilds", rarity = "Mythic", role = "Specialist", ability = "starfall",
		desc = "Raposa de muitas caudas tecidas com luar.",
		model = { rig = "quad", size = 1.25, body = rgb(240, 240, 255), belly = rgb(255, 255, 255), accent = rgb(170, 140, 255), eye = rgb(140, 100, 255),
			ears = "pointy", tail = "multi", glowEyes = true },
	},
	whisper_shade = {
		name = "Whisper Shade", world = "wilds", rarity = "Secret", role = "Attacker", ability = "sunder",
		desc = "Uma sombra que sussurra o seu nome.",
		perk = { kind = "luck", category = "All", bonus = 0.03 },
		model = { rig = "floater", size = 1.15, body = rgb(30, 26, 44), belly = rgb(80, 60, 120), accent = rgb(200, 120, 255), eye = rgb(255, 120, 200),
			orbit = "wisps", glowEyes = true },
	},

	-- ASTRAL SANCTUARY ------------------------------------------------------------
	stardust_sprite = {
		name = "Stardust Sprite", world = "astral", rarity = "Common", role = "Support", ability = "haste",
		desc = "Pozinho de estrela com vontade própria.",
		model = { rig = "floater", size = 0.9, body = rgb(90, 80, 160), belly = rgb(255, 230, 160), accent = rgb(255, 240, 180), eye = rgb(255, 255, 255),
			orbit = "stars", glowEyes = true },
	},
	nebula_pup = {
		name = "Nebula Pup", world = "astral", rarity = "Uncommon", role = "Explorer", ability = "treasure_sense",
		desc = "Filhote com galáxias no pelo.",
		perk = { kind = "luck", category = "SpecialEgg", bonus = 0.06 },
		model = { rig = "quad", size = 1.0, body = rgb(70, 50, 130), belly = rgb(200, 120, 220), accent = rgb(120, 220, 255), eye = rgb(255, 255, 255),
			ears = "pointy", tail = "fluffy", back = "stars" },
	},
	comet_serpent = {
		name = "Comet Serpent", world = "astral", rarity = "Rare", role = "Attacker", ability = "energy_bolt",
		desc = "Serpente com cauda de cometa.",
		model = { rig = "serpent", size = 1.1, body = rgb(60, 70, 140), belly = rgb(170, 200, 255), accent = rgb(255, 170, 80), eye = rgb(255, 230, 140),
			tail = "flame" },
	},
	orbit_golem = {
		name = "Orbit Golem", world = "astral", rarity = "Epic", role = "Tank", ability = "guard_shield",
		desc = "Golem com pequenos planetas em órbita.",
		model = { rig = "golem", size = 1.15, body = rgb(80, 80, 110), belly = rgb(60, 60, 90), accent = rgb(255, 200, 110), eye = rgb(255, 220, 140),
			orbit = "planets", glowEyes = true },
	},
	astral_lion = {
		name = "Astral Lion", world = "astral", rarity = "Legendary", role = "Attacker", ability = "shockwave",
		desc = "Leão com juba de constelações.",
		model = { rig = "quad", size = 1.35, body = rgb(230, 190, 120), belly = rgb(250, 230, 190), accent = rgb(140, 200, 255), eye = rgb(120, 200, 255),
			ears = "round", back = "mane", tail = "thin", glowEyes = true },
	},
	eclipse_drake = {
		name = "Eclipse Drake", world = "astral", rarity = "Mythic", role = "Specialist", ability = "starfall",
		desc = "Dragão que carrega um eclipse no peito.",
		model = { rig = "flyer", size = 1.4, body = rgb(30, 26, 50), belly = rgb(255, 170, 60), accent = rgb(255, 140, 40), eye = rgb(255, 200, 80),
			wings = "membrane", horns = "curled", tail = "flame", drake = true, glowEyes = true },
	},
	void_seraph = {
		name = "Void Seraph", world = "astral", rarity = "Secret", role = "Specialist", ability = "root_snare",
		desc = "Ninguém sabe de que lado do portal ele veio.",
		perk = { kind = "luck", category = "Drop", bonus = 0.06 },
		model = { rig = "flyer", size = 1.3, body = rgb(20, 16, 36), belly = rgb(90, 60, 160), accent = rgb(200, 140, 255), eye = rgb(255, 255, 255),
			wings = "seraph", halo = true, glowEyes = true },
	},

	-- CELESTIAL (somente ovos especiais / condição de coleção) ---------------------
	celestara = {
		name = "Celestara", world = "astral", rarity = "Celestial", role = "Support", ability = "starfall",
		desc = "Corça celeste cujos chifres guardam a aurora.",
		perk = { kind = "luck", category = "All", bonus = 0.05 },
		model = { rig = "quad", size = 1.4, body = rgb(250, 248, 255), belly = rgb(255, 255, 255), accent = rgb(150, 230, 255), eye = rgb(120, 200, 255),
			horns = "antlers", tail = "fluffy", halo = true, glowEyes = true },
	},
	solaris_leviathan = {
		name = "Solaris Leviathan", world = "astral", rarity = "Celestial", role = "Tank", ability = "shockwave",
		desc = "Serpente solar que nada entre as estrelas.",
		perk = { kind = "coins", bonus = 0.15 },
		model = { rig = "serpent", size = 1.5, body = rgb(255, 196, 90), belly = rgb(255, 245, 210), accent = rgb(255, 120, 60), eye = rgb(255, 255, 255),
			back = "fins", halo = true, glowEyes = true },
	},
}


-------------------------------------------------------------------------------
-- MUNDOS 1 E 2 — 80 PETS CADA (arte do autor: docs/concept/world1_pets.jpg e world2_pets.jpg)
-- Cada FAMÍLIA vira várias espécies (mesmo formato, cores e nomes próprios), como as fileiras
-- da arte. As espécies antigas do mundo contam dentro dos 80.
-------------------------------------------------------------------------------

local function clone(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	return c
end

-- family = { key, world, rarity, role, ability, desc, perk?, base (parâmetros de modelo), variants = { {name, body, belly, accent, eye, extra?} } }
local function family(f)
	for i, v in ipairs(f.variants) do
		local m = clone(f.base)
		m.body, m.belly, m.accent, m.eye = v[2], v[3], v[4], v[5] or Color3.fromRGB(25, 22, 28)
		if v[6] then
			for k, x in pairs(v[6]) do
				m[k] = x
			end
		end
		Pets.Species[f.key .. "_" .. i] = {
			name = v[1], world = f.world, rarity = f.rarity, role = f.role, ability = f.ability, desc = f.desc, perk = f.perk, model = m,
		}
	end
end

local G, W = Color3.fromRGB(110, 190, 70), Color3.fromRGB(245, 240, 225)

-- ===================== WORLD 1 — VERDANT HAVEN =====================
-- Comum (18 = 17 novos + Mossling)
family({ key = "fawn", world = "verdant", rarity = "Common", role = "Explorer", ability = "treasure_sense", desc = "Filhote de cervo que corre entre as samambaias.",
	base = { rig = "quad", size = 0.85, legs = 1.35, long = 1.05, ears = "pointy", tail = "nub", back = "leaves" },
	variants = { { "Mossfawn", rgb(170, 120, 70), rgb(245, 225, 190), G }, { "Dewfawn", rgb(190, 140, 90), rgb(250, 235, 205), rgb(150, 220, 255) },
		{ "Fernfawn", rgb(140, 110, 70), rgb(230, 215, 170), rgb(90, 170, 70) }, { "Clover Fawn", rgb(200, 160, 110), rgb(255, 245, 220), rgb(120, 210, 90), nil, { horns = "nubs" } } } })
family({ key = "hop", world = "verdant", rarity = "Common", role = "Support", ability = "mend", desc = "Coelhinho que planta flores por onde pula.",
	base = { rig = "quad", size = 0.75, ears = "long", tail = "fluffy", legs = 0.8 },
	variants = { { "Thistlehop", rgb(235, 230, 220), W, rgb(200, 140, 230) }, { "Cloverhop", rgb(200, 180, 150), W, rgb(120, 210, 90) },
		{ "Meadowhop", rgb(180, 150, 120), rgb(240, 230, 210), rgb(255, 200, 120) }, { "Petalhop", rgb(250, 220, 230), W, rgb(255, 150, 190) } } })
family({ key = "chirp", world = "verdant", rarity = "Common", role = "Explorer", ability = "treasure_sense", desc = "Pintinho de pena-folha, curioso e barulhento.",
	perk = { kind = "luck", category = "Treasure", bonus = 0.02 },
	base = { rig = "flyer", size = 0.72, wings = "leaf", crest = true },
	variants = { { "Sproutchick", rgb(255, 225, 90), rgb(255, 245, 190), G }, { "Dandelion Chirp", rgb(255, 210, 60), W, rgb(255, 255, 255) },
		{ "Pollen Chirp", rgb(240, 200, 80), rgb(255, 240, 180), rgb(255, 150, 60) } } })
family({ key = "kit", world = "verdant", rarity = "Common", role = "Attacker", ability = "charge", desc = "Raposinha de folhas, rápida e brincalhona.",
	base = { rig = "quad", size = 0.85, ears = "pointy", tail = "fluffy", back = "leaves" },
	variants = { { "Leafkit", rgb(220, 120, 60), W, G }, { "Ivykit", rgb(200, 100, 60), rgb(250, 235, 215), rgb(70, 150, 70) }, { "Acorn Kit", rgb(170, 110, 60), W, rgb(160, 120, 60) } } })
family({ key = "scamper", world = "verdant", rarity = "Common", role = "Explorer", ability = "treasure_sense", desc = "Esquilo que esconde tesouros em troncos ocos.",
	base = { rig = "quad", size = 0.72, ears = "tufted", tail = "leafy" },
	variants = { { "Acorn Scamper", rgb(170, 100, 50), rgb(240, 220, 190), G }, { "Hazel Scamper", rgb(140, 100, 70), rgb(230, 210, 180), rgb(200, 160, 80) } } })
family({ key = "lilyfrog", world = "verdant", rarity = "Common", role = "Tank", ability = "guard_shield", desc = "Sapo que dorme em vitórias-régias.",
	base = { rig = "quad", size = 0.8, legs = 0.6, stocky = true, back = "leaves" },
	variants = { { "Lilypad Frog", rgb(100, 180, 80), rgb(220, 240, 170), rgb(255, 150, 200) } } })

-- Incomum (18 = 17 novos + Leafwing)
family({ key = "cap", world = "verdant", rarity = "Uncommon", role = "Support", ability = "haste", desc = "Cogumelinho que solta esporos brilhantes.",
	base = { rig = "shroom", size = 0.85 },
	variants = { { "Capling", rgb(220, 60, 60), rgb(245, 235, 215), W }, { "Glowcap", rgb(140, 90, 220), rgb(240, 235, 250), rgb(200, 255, 230), rgb(120, 255, 200), { glowSpots = true, glowEyes = true } },
		{ "Toadstool Tot", rgb(170, 110, 60), rgb(245, 230, 200), rgb(255, 240, 200) }, { "Bluecap", rgb(70, 130, 220), rgb(235, 240, 250), rgb(200, 230, 255) } } })
family({ key = "goat", world = "verdant", rarity = "Uncommon", role = "Tank", ability = "guard_shield", desc = "Cabritinho das encostas cobertas de musgo.",
	base = { rig = "quad", size = 0.9, legs = 1.1, ears = "pointy", horns = "curled", back = "moss", tail = "nub" },
	variants = { { "Mossgoat", rgb(235, 230, 215), W, G }, { "Clovergoat", rgb(200, 180, 150), W, rgb(120, 210, 90) }, { "Ridge Kid", rgb(150, 140, 130), rgb(220, 215, 205), rgb(90, 150, 70) } } })
family({ key = "leafcat", world = "verdant", rarity = "Uncommon", role = "Attacker", ability = "charge", desc = "Gato da floresta com orelhas de folha.",
	base = { rig = "quad", size = 0.9, ears = "leafy", tail = "thin", back = "flowers" },
	variants = { { "Leafcat", rgb(150, 190, 90), rgb(230, 245, 200), rgb(90, 170, 60) }, { "Blossomcat", rgb(240, 200, 210), W, rgb(255, 140, 190) },
		{ "Fernpaw", rgb(110, 150, 80), rgb(210, 230, 180), rgb(70, 140, 60) }, { "Ivy Whisker", rgb(90, 120, 70), rgb(190, 210, 160), rgb(140, 220, 110) } } })
family({ key = "sproutslime", world = "verdant", rarity = "Uncommon", role = "Tank", ability = "shockwave", desc = "Gota de seiva viva com um broto na cabeça.",
	base = { rig = "slime", size = 0.85, top = "sprout" },
	variants = { { "Sprout Slime", rgb(120, 220, 100), rgb(200, 255, 170), rgb(70, 160, 60) }, { "Dew Slime", rgb(120, 210, 230), rgb(210, 245, 255), G },
		{ "Moss Slime", rgb(80, 150, 70), rgb(160, 210, 120), rgb(60, 120, 50) } } })
family({ key = "owlet", world = "verdant", rarity = "Uncommon", role = "Support", ability = "haste", desc = "Corujinha que vigia a floresta à noite.",
	base = { rig = "flyer", size = 0.8, wings = "feather", ears = "tufted" },
	variants = { { "Twig Owlet", rgb(140, 110, 80), rgb(230, 215, 190), rgb(255, 210, 120), rgb(255, 200, 60), { glowEyes = true } },
		{ "Fern Owlet", rgb(110, 140, 90), rgb(220, 230, 200), rgb(150, 220, 110) }, { "Moss Owlet", rgb(90, 120, 80), rgb(200, 215, 180), G } } })

-- Raro (16 = 15 novos + Thornpup)
family({ key = "golemling", world = "verdant", rarity = "Rare", role = "Tank", ability = "shockwave", desc = "Pequeno golem de pedra e musgo.",
	base = { rig = "golem", size = 0.85, back = "moss" },
	variants = { { "Moss Golemling", rgb(120, 125, 110), rgb(95, 100, 88), rgb(120, 220, 90), rgb(160, 255, 130) }, { "Stone Sprout", rgb(140, 135, 125), rgb(110, 105, 95), rgb(150, 230, 110), rgb(200, 255, 160) },
		{ "Root Golemling", rgb(110, 85, 60), rgb(85, 65, 45), rgb(110, 200, 80), rgb(140, 255, 120) }, { "Lichen Golemling", rgb(100, 115, 100), rgb(80, 92, 80), rgb(190, 230, 120), rgb(220, 255, 150) } } })
family({ key = "drakeling", world = "verdant", rarity = "Rare", role = "Attacker", ability = "energy_bolt", desc = "Dragãozinho de asas de folha.",
	base = { rig = "flyer", size = 0.95, drake = true, wings = "leaf", tail = "leaf", horns = "nubs" },
	variants = { { "Leaf Drakeling", rgb(110, 190, 80), rgb(230, 245, 190), rgb(70, 150, 60), rgb(255, 220, 80), { glowEyes = true } },
		{ "Fern Drake", rgb(80, 150, 90), rgb(210, 235, 190), rgb(60, 120, 60) }, { "Bloom Drakeling", rgb(150, 200, 110), rgb(250, 235, 240), rgb(255, 150, 200) },
		{ "Vine Drake", rgb(70, 120, 60), rgb(180, 210, 150), rgb(160, 230, 100) } } })
family({ key = "boar", world = "verdant", rarity = "Rare", role = "Attacker", ability = "charge", desc = "Javali de espinhos que derruba árvores.",
	base = { rig = "quad", size = 1.0, stocky = true, horns = "tusks", back = "thorns", ears = "pointy", tail = "nub" },
	variants = { { "Bramble Boar", rgb(110, 80, 60), rgb(170, 140, 110), rgb(120, 190, 80) }, { "Thorn Hog", rgb(130, 95, 70), rgb(190, 160, 120), rgb(200, 190, 140) } } })
family({ key = "beetle", world = "verdant", rarity = "Rare", role = "Tank", ability = "guard_shield", desc = "Besouro com um jardim nas costas.",
	base = { rig = "quad", size = 0.9, legs = 0.55, stocky = true, ears = "feelers", back = "flowers" },
	variants = { { "Bloom Beetle", rgb(60, 120, 80), rgb(40, 80, 55), rgb(255, 140, 190) }, { "Clover Beetle", rgb(80, 150, 70), rgb(50, 100, 45), rgb(255, 230, 120) },
		{ "Moss Beetle", rgb(70, 90, 60), rgb(50, 65, 45), rgb(180, 140, 255) } } })
family({ key = "ferret", world = "verdant", rarity = "Rare", role = "Explorer", ability = "treasure_sense", desc = "Furão que se esgueira pelas raízes atrás de tesouros.",
	perk = { kind = "luck", category = "Treasure", bonus = 0.03 },
	base = { rig = "quad", size = 0.8, long = 1.4, legs = 0.7, ears = "round", tail = "thin", back = "leaves" },
	variants = { { "Fern Ferret", rgb(150, 110, 80), rgb(235, 220, 200), G }, { "Reed Ferret", rgb(120, 100, 80), rgb(220, 210, 190), rgb(150, 200, 90) } } })

-- Épico (14 = 13 novos + Bloomfox)
family({ key = "grovestag", world = "verdant", rarity = "Epic", role = "Specialist", ability = "root_snare", desc = "Cervo nobre com galhada de raízes.",
	base = { rig = "quad", size = 1.15, legs = 1.5, long = 1.1, neck = 0.5, horns = "antlers", ears = "pointy", tail = "nub", back = "leaves" },
	variants = { { "Grove Stag", rgb(150, 105, 65), rgb(235, 215, 180), G }, { "Moss Stag", rgb(120, 100, 70), rgb(215, 200, 165), rgb(90, 160, 70) },
		{ "Blossom Stag", rgb(170, 120, 80), rgb(245, 230, 210), rgb(255, 160, 200) }, { "Dawn Stag", rgb(200, 150, 90), rgb(255, 240, 210), rgb(255, 200, 100) } } })
family({ key = "vinelynx", world = "verdant", rarity = "Epic", role = "Attacker", ability = "sunder", desc = "Lince de pelagem verde que caça nas copas.",
	base = { rig = "quad", size = 1.05, legs = 1.1, ears = "tufted", tail = "leafy", back = "leaves" },
	variants = { { "Vine Lynx", rgb(110, 150, 80), rgb(220, 235, 190), rgb(70, 140, 60), rgb(255, 220, 90), { glowEyes = true } },
		{ "Fern Lynx", rgb(140, 120, 80), rgb(225, 215, 185), rgb(90, 170, 70) }, { "Thistle Lynx", rgb(160, 130, 160), rgb(235, 225, 235), rgb(190, 130, 230) },
		{ "Shade Lynx", rgb(70, 90, 70), rgb(150, 170, 140), rgb(140, 230, 140), rgb(160, 255, 180), { glowEyes = true } } } })
family({ key = "bloomwyvern", world = "verdant", rarity = "Epic", role = "Specialist", ability = "energy_bolt", desc = "Wyvern que poliniza a floresta com suas asas.",
	base = { rig = "flyer", size = 1.15, drake = true, wings = "leaf", tail = "leaf", horns = "antlers" },
	variants = { { "Bloom Wyvern", rgb(120, 190, 90), rgb(240, 240, 210), rgb(255, 140, 200) }, { "Canopy Wyvern", rgb(80, 150, 70), rgb(200, 230, 170), rgb(150, 230, 100) },
		{ "Petal Wyvern", rgb(200, 160, 200), rgb(250, 235, 245), rgb(255, 120, 190) } } })
family({ key = "petalfox", world = "verdant", rarity = "Epic", role = "Support", ability = "mend", desc = "Raposa de três caudas de pétalas.",
	base = { rig = "quad", size = 1.05, ears = "pointy", tail = "multi", back = "flowers" },
	variants = { { "Petal Fox", rgb(240, 170, 150), W, rgb(255, 140, 190) }, { "Lotus Fox", rgb(230, 220, 240), W, rgb(190, 140, 255) } } })

-- Lendário (6 = 5 novos + Grovekin)
family({ key = "grovetortoise", world = "verdant", rarity = "Legendary", role = "Tank", ability = "guard_shield", desc = "Tartaruga anciã que carrega um bosque inteiro no casco.",
	base = { rig = "quad", size = 1.45, legs = 0.65, stocky = true, tail = "nub", back = "tree", shell = rgb(90, 110, 60) },
	variants = { { "Ancient Grove Tortoise", rgb(110, 150, 80), rgb(200, 210, 150), rgb(110, 180, 70) }, { "Mossback Tortoise", rgb(90, 130, 70), rgb(180, 195, 140), rgb(90, 160, 60), nil, { back = "shell" } } } })
family({ key = "verdantwolf", world = "verdant", rarity = "Legendary", role = "Attacker", ability = "charge", desc = "Lobo cujo pelo é feito de folhas vivas.",
	base = { rig = "quad", size = 1.3, legs = 1.2, long = 1.2, snout = 1.5, ears = "pointy", tail = "leafy", back = "leaves" },
	variants = { { "Verdant Wolf", rgb(110, 160, 90), rgb(220, 235, 200), rgb(70, 150, 60), rgb(200, 255, 140), { glowEyes = true } } } })
family({ key = "thornmane", world = "verdant", rarity = "Legendary", role = "Attacker", ability = "shockwave", desc = "Leão de juba de folhas e espinhos.",
	base = { rig = "quad", size = 1.35, legs = 1.1, long = 1.1, ears = "round", back = "mane", tail = "thin" },
	variants = { { "Thornmane Lion", rgb(170, 120, 70), rgb(230, 200, 150), rgb(90, 170, 60), rgb(255, 220, 90), { glowEyes = true } } } })
family({ key = "mossape", world = "verdant", rarity = "Legendary", role = "Tank", ability = "shockwave", desc = "Gorila de musgo, forte como uma montanha.",
	base = { rig = "golem", size = 1.4, back = "moss" },
	variants = { { "Mossback Ape", rgb(80, 120, 60), rgb(60, 90, 45), rgb(140, 220, 100), rgb(200, 255, 140) } } })

-- Mítico (7 = 6 novos + Verdigris Wisp)
family({ key = "spectralhound", world = "verdant", rarity = "Mythic", role = "Specialist", ability = "starfall", desc = "Espírito de folhas que corre entre os mundos.",
	base = { rig = "quad", size = 1.35, legs = 1.3, long = 1.2, snout = 1.4, ears = "leafy", tail = "multi", horns = "antlers", glowEyes = true },
	variants = { { "Spectral Leafhound", rgb(70, 190, 170), rgb(190, 255, 235), rgb(120, 255, 210), rgb(220, 255, 250) } } })
family({ key = "sylphstag", world = "verdant", rarity = "Mythic", role = "Support", ability = "haste", desc = "Cervo alado que dança com o vento.",
	base = { rig = "quad", size = 1.35, legs = 1.4, neck = 0.5, horns = "antlers", ears = "pointy", wings = "leaf", wingSpan = 1.3, tail = "leafy", glowEyes = true },
	variants = { { "Sylphwing Stag", rgb(120, 170, 90), rgb(225, 240, 200), rgb(110, 210, 80), rgb(220, 255, 150) } } })
family({ key = "elderstag", world = "verdant", rarity = "Mythic", role = "Specialist", ability = "root_snare", desc = "O cervo mais velho do bosque, de olhos verdes ancestrais.",
	base = { rig = "quad", size = 1.45, legs = 1.5, long = 1.15, neck = 0.6, horns = "antlers", ears = "pointy", back = "moss", tail = "nub", glowEyes = true },
	variants = { { "Elder Thornstag", rgb(110, 80, 55), rgb(200, 180, 140), rgb(90, 170, 60), rgb(140, 255, 120) } } })
family({ key = "ent", world = "verdant", rarity = "Mythic", role = "Tank", ability = "shockwave", desc = "Árvore viva que protege a floresta.",
	base = { rig = "treant", size = 1.3 },
	variants = { { "Canopy Ent", rgb(110, 80, 50), rgb(90, 65, 40), rgb(90, 170, 60), rgb(160, 255, 120) },
		{ "Bloom Ent", rgb(120, 90, 60), rgb(100, 75, 50), rgb(110, 180, 70), rgb(255, 200, 120), { blossoms = rgb(255, 150, 200) } },
		{ "Azure Warden", rgb(80, 90, 110), rgb(60, 70, 90), rgb(90, 200, 255), rgb(150, 230, 255), { glowCanopy = true, glowCore = rgb(80, 180, 255) } } } })

-- 2ª leva do autor (referências enviadas): modelos originais a partir das ideias — panda de manto de
-- folhas, cabra com arbusto de frutinhas e mamute de pelagem de capim (Builders/CreatureBuilder).
local PW = rgb(226, 226, 232) -- olhos claros (anel branco, pupila escura)
family({ key = "leafpanda", world = "verdant", rarity = "Common", role = "Support", ability = "mend", desc = "Filhote de panda que se esconde num manto de folhas e acena para todo mundo.",
	base = { rig = "leafpanda", size = 0.9 },
	variants = { { "Sprout Panda", rgb(92, 170, 72), rgb(240, 238, 230), rgb(70, 150, 58), PW }, { "Maple Panda", rgb(214, 120, 58), rgb(246, 240, 230), rgb(176, 74, 40), PW },
		{ "Blossom Panda", rgb(238, 158, 188), rgb(250, 244, 240), rgb(110, 180, 80), PW }, { "Mossy Panda", rgb(70, 130, 100), rgb(225, 230, 215), rgb(150, 210, 90), PW } } })
family({ key = "berrygoat", world = "verdant", rarity = "Rare", role = "Support", ability = "mend", desc = "Cabra fofinha que carrega um arbusto de frutinhas nas costas e divide com o time.",
	base = { rig = "bushgoat", size = 1.0 },
	variants = { { "Berrytuft Goat", rgb(176, 214, 110), rgb(244, 240, 222), rgb(70, 150, 60), rgb(240, 170, 40), { berry = rgb(220, 50, 76) } },
		{ "Bluebramble Goat", rgb(150, 200, 170), rgb(240, 244, 236), rgb(56, 130, 90), rgb(240, 170, 40), { berry = rgb(80, 110, 230) } },
		{ "Sunberry Goat", rgb(214, 212, 120), rgb(248, 242, 222), rgb(110, 160, 60), rgb(240, 150, 40), { berry = rgb(255, 190, 40) } } } })
family({ key = "turfmammoth", world = "verdant", rarity = "Epic", role = "Tank", ability = "shockwave", desc = "Mamute manso de pelagem de capim: quando pisa forte, o chão inteiro treme.",
	base = { rig = "mammoth", size = 1.2 },
	variants = { { "Meadow Mammoth", rgb(178, 112, 70), rgb(208, 152, 106), rgb(96, 170, 64), rgb(176, 60, 50) },
		{ "Autumn Mammoth", rgb(150, 100, 70), rgb(196, 150, 110), rgb(206, 130, 50), rgb(120, 70, 40) } } })
family({ key = "eldermammoth", world = "verdant", rarity = "Legendary", role = "Tank", ability = "guard_shield", desc = "O mamute mais velho do bosque: a pelagem virou um campo inteiro.",
	base = { rig = "mammoth", size = 1.5, glowEyes = true },
	variants = { { "Elder Grove Mammoth", rgb(122, 92, 72), rgb(170, 132, 100), rgb(70, 140, 56), rgb(150, 255, 130), { tusk = rgb(250, 240, 200), band = rgb(70, 120, 60) } } } })

-- SECRET
Pets.Species.sylvanox = {
	name = "Sylvanox", world = "verdant", rarity = "Secret", role = "Support", ability = "starfall",
	desc = "O guardião secreto de Verdant Haven: galhada coberta de flores e cipós que brilham.",
	perk = { kind = "luck", category = "All", bonus = 0.04 },
	model = { rig = "quad", size = 1.6, legs = 1.5, long = 1.15, neck = 0.6, horns = "grand", ears = "pointy", tail = "leafy", back = "leaves",
		body = rgb(150, 105, 65), belly = rgb(245, 225, 190), accent = rgb(100, 210, 90), eye = rgb(150, 255, 150), antler = rgb(110, 80, 55), glowEyes = true, halo = true },
}

-- ===================== WORLD 2 — CRYSTAL HOLLOW =====================
local CB, CP = rgb(150, 210, 255), rgb(190, 150, 255)
-- Comum (20 = 19 novos + Shardmite)
family({ key = "crystalkitten", world = "crystal", rarity = "Common", role = "Attacker", ability = "charge", desc = "Gatinho de cristal que ronrona como um sino.",
	base = { rig = "quad", size = 0.8, ears = "crystal", tail = "crystal" },
	variants = { { "Quartz Kitten", rgb(220, 235, 250), W, CB }, { "Glint Kitten", rgb(190, 220, 255), W, rgb(120, 190, 255) }, { "Frost Kitten", rgb(235, 245, 255), W, rgb(180, 230, 255) },
		{ "Opal Kitten", rgb(240, 225, 245), W, rgb(255, 170, 220) }, { "Mica Kitten", rgb(200, 200, 215), rgb(235, 235, 245), rgb(220, 220, 255) },
		{ "Rime Kitten", rgb(210, 240, 250), W, rgb(140, 230, 240) }, { "Lumen Kitten", rgb(250, 245, 225), W, rgb(255, 230, 140) } } })
family({ key = "crystalmouse", world = "crystal", rarity = "Common", role = "Explorer", ability = "treasure_sense", desc = "Ratinho que coleciona lascas brilhantes.",
	base = { rig = "quad", size = 0.6, legs = 0.6, ears = "mouse", tail = "thin" },
	variants = { { "Shard Mouse", rgb(200, 210, 230), W, CB }, { "Pebble Mouse", rgb(170, 175, 195), rgb(225, 225, 235), rgb(200, 210, 255) },
		{ "Gleam Mouse", rgb(220, 225, 245), W, rgb(255, 200, 240) }, { "Spar Mouse", rgb(190, 205, 230), W, rgb(150, 200, 255) },
		{ "Facet Mouse", rgb(210, 200, 235), W, CP }, { "Beryl Mouse", rgb(190, 230, 220), W, rgb(120, 230, 200) },
		{ "Azure Mouse", rgb(170, 200, 245), W, rgb(90, 160, 255) }, { "Topaz Mouse", rgb(235, 220, 190), W, rgb(255, 200, 100) } } })
family({ key = "prismhopper", world = "crystal", rarity = "Common", role = "Support", ability = "mend", desc = "Coelho que salta entre estalactites.",
	base = { rig = "quad", size = 0.75, legs = 0.8, ears = "long", tail = "fluffy", back = "crystals" },
	variants = { { "Prism Hopper", rgb(225, 235, 255), W, CB }, { "Opal Hopper", rgb(245, 230, 245), W, rgb(255, 170, 220) },
		{ "Frost Hopper", rgb(230, 245, 255), W, rgb(170, 230, 255) }, { "Violet Hopper", rgb(220, 205, 245), W, CP } } })

-- Incomum (14 = 13 novos + Glimmerbat)
family({ key = "crystalslime", world = "crystal", rarity = "Uncommon", role = "Tank", ability = "guard_shield", desc = "Gota cristalina que gruda nas paredes da caverna.",
	base = { rig = "slime", size = 0.85, top = "crystal", glassy = true },
	variants = { { "Azure Slime", rgb(110, 180, 255), rgb(190, 225, 255), rgb(160, 220, 255) }, { "Frost Slime", rgb(170, 225, 255), rgb(230, 245, 255), W },
		{ "Mint Slime", rgb(130, 230, 210), rgb(200, 250, 240), rgb(170, 255, 230) }, { "Opal Slime", rgb(210, 180, 240), rgb(240, 225, 250), rgb(255, 190, 230) },
		{ "Twin Slime", rgb(120, 200, 240), rgb(200, 240, 255), CB }, { "King Slime", rgb(90, 160, 240), rgb(180, 215, 255), rgb(255, 220, 100), nil, { top = "crown" } } } })
family({ key = "gempup", world = "crystal", rarity = "Uncommon", role = "Attacker", ability = "charge", desc = "Filhote com gemas crescendo nas costas.",
	base = { rig = "quad", size = 0.85, ears = "pointy", tail = "crystal", back = "crystals" },
	variants = { { "Gem Pup", rgb(190, 210, 240), W, CB }, { "Ruby Pup", rgb(210, 190, 200), W, rgb(255, 90, 120) }, { "Jade Pup", rgb(190, 230, 210), W, rgb(90, 230, 150) },
		{ "Citrine Pup", rgb(240, 225, 190), W, rgb(255, 210, 80) } } })
family({ key = "geobeetle", world = "crystal", rarity = "Uncommon", role = "Tank", ability = "shockwave", desc = "Besouro de casco geodo.",
	base = { rig = "quad", size = 0.85, legs = 0.55, stocky = true, ears = "feelers", back = "crystals" },
	variants = { { "Geode Beetle", rgb(70, 75, 100), rgb(50, 55, 75), CP }, { "Quartz Beetle", rgb(90, 100, 130), rgb(65, 72, 95), CB },
		{ "Ember Beetle", rgb(90, 70, 80), rgb(65, 50, 60), rgb(255, 140, 100) } } })

-- Raro (18 = 17 novos + Geodeling)
family({ key = "crystalfox", world = "crystal", rarity = "Rare", role = "Attacker", ability = "energy_bolt", desc = "Raposa com caudas de cristal em leque.",
	base = { rig = "quad", size = 0.95, ears = "crystal", tail = "fan", tailCount = 3, back = "crystals" },
	variants = { { "Glacier Fox", rgb(210, 235, 255), W, CB }, { "Shard Fox", rgb(190, 215, 250), W, rgb(120, 180, 255) }, { "Prism Fox", rgb(230, 230, 250), W, rgb(200, 170, 255) },
		{ "Frost Fox", rgb(235, 248, 255), W, rgb(170, 230, 255) }, { "Lumen Fox", rgb(245, 240, 225), W, rgb(255, 230, 150) }, { "Azure Fox", rgb(170, 205, 250), W, rgb(90, 160, 255) },
		{ "Opal Fox", rgb(245, 230, 245), W, rgb(255, 170, 220) }, { "Cobalt Fox", rgb(140, 170, 230), rgb(220, 230, 250), rgb(70, 120, 230) },
		{ "Rime Fox", rgb(215, 240, 245), W, rgb(140, 230, 240), nil, { tailCount = 5 } }, { "Gleam Fox", rgb(225, 225, 245), W, rgb(220, 220, 255), nil, { tailCount = 5 } },
		{ "Spectra Fox", rgb(200, 220, 250), W, rgb(255, 150, 230), nil, { tailCount = 5 } }, { "Nova Fox", rgb(230, 235, 255), W, rgb(150, 240, 255), rgb(150, 240, 255), { tailCount = 5, glowEyes = true } } } })
family({ key = "crystalferret", world = "crystal", rarity = "Rare", role = "Explorer", ability = "treasure_sense", desc = "Furão que fareja veios de cristal.",
	perk = { kind = "luck", category = "Treasure", bonus = 0.03 },
	base = { rig = "quad", size = 0.8, long = 1.4, legs = 0.7, ears = "round", tail = "crystal", back = "crystals" },
	variants = { { "Quartz Ferret", rgb(210, 215, 235), W, CB }, { "Amethyst Ferret", rgb(205, 190, 235), W, CP }, { "Sapphire Ferret", rgb(170, 195, 240), W, rgb(80, 140, 255) },
		{ "Mint Ferret", rgb(195, 235, 220), W, rgb(120, 240, 200) }, { "Rose Ferret", rgb(240, 210, 225), W, rgb(255, 140, 190) } } })

-- Épico (16 = 15 novos + Prismcat)
family({ key = "crystalwolf", world = "crystal", rarity = "Epic", role = "Attacker", ability = "sunder", desc = "Lobo de gelo cristalino que uiva nas profundezas.",
	base = { rig = "quad", size = 1.15, legs = 1.2, long = 1.2, snout = 1.5, ears = "crystal", tail = "crystal", back = "crystals" },
	variants = { { "Frostfang Wolf", rgb(210, 230, 250), W, CB }, { "Glacier Wolf", rgb(190, 215, 245), W, rgb(120, 190, 255) }, { "Shardmaw Wolf", rgb(170, 190, 230), W, rgb(90, 150, 255) },
		{ "Rime Wolf", rgb(225, 240, 250), W, rgb(160, 230, 255) }, { "Cobalt Wolf", rgb(130, 160, 220), rgb(210, 220, 245), rgb(60, 110, 230) },
		{ "Twilight Wolf", rgb(150, 150, 210), rgb(220, 215, 245), CP, rgb(200, 170, 255), { glowEyes = true } } } })
family({ key = "amethyststag", world = "crystal", rarity = "Epic", role = "Specialist", ability = "root_snare", desc = "Cervo de galhada de ametista.",
	base = { rig = "quad", size = 1.1, legs = 1.5, neck = 0.5, horns = "crystalAntlers", ears = "pointy", tail = "nub" },
	variants = { { "Amethyst Stag", rgb(170, 120, 210), rgb(230, 210, 245), rgb(200, 150, 255) }, { "Violet Stag", rgb(150, 100, 200), rgb(220, 200, 240), rgb(190, 130, 255) },
		{ "Lilac Stag", rgb(200, 160, 230), rgb(240, 225, 250), rgb(220, 180, 255) }, { "Orchid Stag", rgb(190, 120, 200), rgb(240, 215, 240), rgb(255, 150, 230) },
		{ "Dusk Stag", rgb(120, 90, 170), rgb(200, 185, 230), rgb(170, 120, 255), rgb(200, 170, 255), { glowEyes = true } },
		{ "Mist Stag", rgb(210, 190, 235), W, rgb(230, 210, 255) } } })
family({ key = "gemlynx", world = "crystal", rarity = "Epic", role = "Attacker", ability = "charge", desc = "Lince de garras de gema.",
	base = { rig = "quad", size = 1.05, legs = 1.1, ears = "tufted", tail = "crystal", back = "crystals" },
	variants = { { "Sapphire Lynx", rgb(150, 180, 230), W, rgb(80, 140, 255) }, { "Topaz Lynx", rgb(230, 210, 170), W, rgb(255, 200, 80) }, { "Garnet Lynx", rgb(200, 160, 170), W, rgb(230, 70, 100) } } })

-- Lendário (5 = 4 novos + Quartz Drake)
family({ key = "crystaldragon", world = "crystal", rarity = "Legendary", role = "Attacker", ability = "energy_bolt", desc = "Dragão de escamas de cristal que guarda os veios mais profundos.",
	base = { rig = "quad", size = 1.4, legs = 1.0, long = 1.6, snout = 1.6, ears = "crystal", horns = "crystal", tail = "crystal", back = "crystals" },
	variants = { { "Crystalback Dragon", rgb(130, 180, 240), rgb(200, 230, 255), rgb(170, 230, 255), rgb(200, 240, 255), { glowEyes = true } } } })
family({ key = "rubygolem", world = "crystal", rarity = "Legendary", role = "Tank", ability = "guard_shield", desc = "Golem de cristal com um coração de rubi.",
	base = { rig = "golem", size = 1.45, back = "crystals" },
	variants = { { "Rubyheart Golem", rgb(170, 175, 200), rgb(140, 145, 170), rgb(255, 60, 110), rgb(255, 120, 150) } } })
family({ key = "prismpanther", world = "crystal", rarity = "Legendary", role = "Attacker", ability = "sunder", desc = "Pantera de vidro que some na luz.",
	base = { rig = "quad", size = 1.3, legs = 1.15, long = 1.25, ears = "pointy", tail = "crystal", back = "crystals", glassy = true },
	variants = { { "Prism Panther", rgb(80, 90, 150), rgb(150, 160, 210), rgb(150, 220, 255), rgb(150, 240, 255), { glowEyes = true } } } })
family({ key = "glassserpent", world = "crystal", rarity = "Legendary", role = "Specialist", ability = "starfall", desc = "Serpente de cristal que desliza pelas paredes.",
	base = { rig = "serpent", size = 1.25, back = "fins" },
	variants = { { "Glass Serpent", rgb(160, 210, 250), rgb(225, 245, 255), rgb(120, 200, 255), rgb(200, 240, 255), { glowEyes = true } } } })

-- Mítico (6 = 5 novos + Echo Geode)
family({ key = "sapphiresentinel", world = "crystal", rarity = "Mythic", role = "Tank", ability = "shockwave", desc = "Golem blindado de safira com núcleo esmeralda.",
	base = { rig = "golem", size = 1.6, back = "crystals" },
	variants = { { "Sapphire Sentinel", rgb(110, 160, 230), rgb(80, 120, 190), rgb(60, 240, 170), rgb(120, 255, 210) } } })
family({ key = "crystalgriffin", world = "crystal", rarity = "Mythic", role = "Specialist", ability = "haste", desc = "Grifo de penas cristalinas e garras douradas.",
	base = { rig = "quad", size = 1.45, legs = 1.1, beak = true, ears = "crystal", wings = "feather", wingSpan = 1.4, tail = "fluffy", paw = rgb(240, 190, 60) },
	variants = { { "Crystal Griffin", rgb(210, 230, 250), W, rgb(150, 210, 255) } } })
family({ key = "aurorafox", world = "crystal", rarity = "Mythic", role = "Support", ability = "mend", desc = "Raposa de sete caudas que brilham como aurora.",
	base = { rig = "quad", size = 1.2, ears = "crystal", tail = "fan", tailCount = 7, glowEyes = true },
	variants = { { "Aurora Fox", rgb(220, 235, 255), W, rgb(150, 255, 220), rgb(170, 255, 230) } } })
family({ key = "prismwyvern", world = "crystal", rarity = "Mythic", role = "Attacker", ability = "starfall", desc = "Wyvern de asas prismáticas.",
	base = { rig = "flyer", size = 1.45, drake = true, wings = "crystal", horns = "crystal", tail = "crystal", glowEyes = true },
	variants = { { "Prism Wyvern", rgb(140, 170, 240), rgb(210, 230, 255), rgb(255, 150, 240), rgb(255, 200, 250) } } })
family({ key = "behemoth", world = "crystal", rarity = "Mythic", role = "Tank", ability = "guard_shield", desc = "Fera colossal com montanhas de cristal nas costas.",
	base = { rig = "quad", size = 1.65, legs = 0.9, stocky = true, ears = "round", horns = "tusks", back = "crystals", tail = "crystal" },
	variants = { { "Crystal Behemoth", rgb(90, 100, 140), rgb(130, 140, 180), rgb(150, 210, 255), rgb(150, 230, 255), { glowEyes = true } } } })

-- SECRET
Pets.Species.lumivex = {
	name = "Lumivex", world = "crystal", rarity = "Secret", role = "Specialist", ability = "starfall",
	desc = "A raposa-rainha de Crystal Hollow, coroada e cercada por um redemoinho de luz.",
	perk = { kind = "luck", category = "PetVariant", bonus = 0.04 },
	model = { rig = "quad", size = 1.45, legs = 1.1, ears = "crystal", tail = "fan", tailCount = 9, back = "crystals", halo = true, glowEyes = true,
		body = rgb(225, 240, 255), belly = rgb(255, 255, 255), accent = rgb(160, 220, 255), eye = rgb(180, 240, 255) },
}

-- Espécies de um mundo por raridade (usado pelos ovos).
function Pets.byWorldRarity(world: string, rarity: string): { string }
	local list = {}
	for id, sp in pairs(Pets.Species) do
		if sp.world == world and sp.rarity == rarity then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

function Pets.get(id: string)
	return Pets.Species[id]
end

function Pets.count(): number
	local n = 0
	for _ in pairs(Pets.Species) do
		n += 1
	end
	return n
end

return Pets

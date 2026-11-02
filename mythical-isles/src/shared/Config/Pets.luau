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
		name = "Verdigris Wisp", world = "verdant", rarity = "Secret", role = "Support", ability = "haste",
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
		name = "Echo Geode", world = "crystal", rarity = "Secret", role = "Specialist", ability = "sunder",
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

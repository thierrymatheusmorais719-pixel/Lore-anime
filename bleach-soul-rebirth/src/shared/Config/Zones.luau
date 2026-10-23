-- Regiões do mundo, iluminação por região, pontos de viagem, portais e spawns.
-- Posições de spawn/NPC são relativas ao `center` da região.
local Zones = {}

Zones.Order = { "Karakura", "Training", "SoulSociety", "HuecoMundo" }

Zones.List = {
	Karakura = {
		name = "Cidade de Karakura",
		kanji = "空座町",
		center = Vector3.new(0, 0, 0),
		size = Vector3.new(460, 300, 460),
		lighting = {
			ClockTime = 21.5,
			Brightness = 1.6,
			Ambient = Color3.fromRGB(45, 50, 75),
			OutdoorAmbient = Color3.fromRGB(70, 80, 120),
			atmosphere = {
				Density = 0.32,
				Offset = 0.1,
				Color = Color3.fromRGB(120, 130, 170),
				Decay = Color3.fromRGB(50, 50, 90),
				Glare = 0.2,
				Haze = 1.4,
			},
			correction = {
				Brightness = 0.02,
				Contrast = 0.12,
				Saturation = 0.05,
				TintColor = Color3.fromRGB(225, 232, 255),
			},
			bloom = { Intensity = 0.7, Size = 28, Threshold = 1.2 },
		},
		minLevel = 1,
	},
	Training = {
		name = "Campo de Treino Subterrâneo",
		kanji = "勉強部屋",
		center = Vector3.new(0, 0, 900),
		size = Vector3.new(380, 300, 380),
		lighting = {
			ClockTime = 17.4,
			Brightness = 2.4,
			Ambient = Color3.fromRGB(90, 80, 70),
			OutdoorAmbient = Color3.fromRGB(150, 130, 110),
			atmosphere = {
				Density = 0.25,
				Offset = 0,
				Color = Color3.fromRGB(230, 200, 160),
				Decay = Color3.fromRGB(150, 110, 80),
				Glare = 0.4,
				Haze = 1.5,
			},
			correction = {
				Brightness = 0.03,
				Contrast = 0.1,
				Saturation = 0.08,
				TintColor = Color3.fromRGB(255, 240, 225),
			},
			bloom = { Intensity = 0.6, Size = 24, Threshold = 1.4 },
		},
		minLevel = 1,
		pvp = true, -- PvP liberado apenas na arena de treino
	},
	SoulSociety = {
		name = "Soul Society — Seireitei",
		kanji = "瀞霊廷",
		center = Vector3.new(3000, 0, 0),
		size = Vector3.new(460, 300, 460),
		lighting = {
			ClockTime = 14.2,
			Brightness = 2.8,
			Ambient = Color3.fromRGB(110, 105, 100),
			OutdoorAmbient = Color3.fromRGB(150, 145, 140),
			atmosphere = {
				Density = 0.22,
				Offset = 0,
				Color = Color3.fromRGB(215, 225, 240),
				Decay = Color3.fromRGB(150, 170, 200),
				Glare = 0.3,
				Haze = 1,
			},
			correction = {
				Brightness = 0.02,
				Contrast = 0.06,
				Saturation = 0.12,
				TintColor = Color3.fromRGB(255, 250, 242),
			},
			bloom = { Intensity = 0.5, Size = 24, Threshold = 1.6 },
		},
		minLevel = 4,
	},
	HuecoMundo = {
		name = "Hueco Mundo",
		kanji = "虚圏",
		center = Vector3.new(-3000, 0, 0),
		size = Vector3.new(640, 300, 640),
		lighting = {
			ClockTime = 0,
			Brightness = 1.2,
			Ambient = Color3.fromRGB(60, 60, 75),
			OutdoorAmbient = Color3.fromRGB(110, 110, 130),
			atmosphere = {
				Density = 0.42,
				Offset = 0.2,
				Color = Color3.fromRGB(170, 170, 190),
				Decay = Color3.fromRGB(20, 20, 35),
				Glare = 0,
				Haze = 1.8,
			},
			correction = {
				Brightness = 0,
				Contrast = 0.12,
				Saturation = -0.2,
				TintColor = Color3.fromRGB(230, 232, 255),
			},
			bloom = { Intensity = 0.8, Size = 30, Threshold = 1.1 },
		},
		minLevel = 12,
	},
}

Zones.TravelPoints = {
	KarakuraPlaza = { name = "Praça de Karakura", zone = "Karakura", position = Vector3.new(0, 4, -42) },
	KarakuraRiver = { name = "Margem do Rio", zone = "Karakura", position = Vector3.new(-150, 4, 150) },
	TrainingGate = { name = "Entrada do Treino", zone = "Training", position = Vector3.new(0, 4, -150) },
	Seireitei = { name = "Portão do Seireitei", zone = "SoulSociety", position = Vector3.new(0, 4, -170) },
	Rukongai = { name = "Praça do Rukongai", zone = "SoulSociety", position = Vector3.new(120, 4, 120) },
	DesertEdge = { name = "Borda do Deserto", zone = "HuecoMundo", position = Vector3.new(0, 6, -250) },
	LasNoches = { name = "Ruínas do Palácio", zone = "HuecoMundo", position = Vector3.new(0, 6, 180) },
}

-- Portais físicos (tocar = viajar). `level`/`quest` bloqueiam o acesso.
Zones.Portals = {
	{
		id = "KarakuraToTraining",
		zone = "Karakura",
		position = Vector3.new(60, 0, -60),
		to = "TrainingGate",
		label = "Campo de Treino",
		color = Color3.fromRGB(255, 190, 120),
	},
	{
		id = "TrainingToKarakura",
		zone = "Training",
		position = Vector3.new(30, 0, -175),
		to = "KarakuraPlaza",
		label = "Karakura",
		color = Color3.fromRGB(150, 180, 255),
	},
	{
		id = "Senkaimon",
		zone = "Karakura",
		position = Vector3.new(-60, 0, -60),
		to = "Seireitei",
		label = "Senkaimon",
		level = 4,
		color = Color3.fromRGB(240, 240, 220),
	},
	{
		id = "SenkaimonBack",
		zone = "SoulSociety",
		position = Vector3.new(-30, 0, -200),
		to = "KarakuraPlaza",
		label = "Karakura",
		color = Color3.fromRGB(150, 180, 255),
	},
	{
		id = "Garganta",
		zone = "Karakura",
		position = Vector3.new(0, 0, -120),
		to = "DesertEdge",
		label = "Garganta",
		level = 12,
		color = Color3.fromRGB(20, 10, 30),
	},
	{
		id = "GargantaBack",
		zone = "HuecoMundo",
		position = Vector3.new(30, 0, -280),
		to = "KarakuraPlaza",
		label = "Karakura",
		color = Color3.fromRGB(150, 180, 255),
	},
}

Zones.Spawners = {
	-- matilhas de Caçadores (quadrúpedes)
	{
		zone = "Karakura",
		enemy = "HollowHound",
		position = Vector3.new(-150, 0, 180),
		count = 3,
		radius = 18,
		respawn = 14,
	},
	{
		zone = "HuecoMundo",
		enemy = "HollowHound",
		position = Vector3.new(-200, 0, -180),
		count = 4,
		radius = 25,
		respawn = 14,
	},
	{
		zone = "Karakura",
		enemy = "HollowGrunt",
		position = Vector3.new(140, 0, 60),
		count = 4,
		radius = 30,
		respawn = 12,
	},
	{
		zone = "Karakura",
		enemy = "HollowGrunt",
		position = Vector3.new(-140, 0, 80),
		count = 4,
		radius = 30,
		respawn = 12,
	},
	{
		zone = "Karakura",
		enemy = "HollowFeral",
		position = Vector3.new(120, 0, -150),
		count = 3,
		radius = 25,
		respawn = 14,
	},
	{
		zone = "Karakura",
		enemy = "HollowBrute",
		position = Vector3.new(-160, 0, -150),
		count = 2,
		radius = 25,
		respawn = 20,
	},
	{
		zone = "Training",
		enemy = "TrainingPuppet",
		position = Vector3.new(-90, 0, 0),
		count = 4,
		radius = 25,
		respawn = 8,
	},
	{
		zone = "Training",
		enemy = "Dummy",
		position = Vector3.new(90, 0, -40),
		count = 3,
		radius = 16,
		respawn = 5,
		line = true,
	},
	{
		zone = "Training",
		enemy = "HollowBrute",
		position = Vector3.new(-80, 0, 110),
		count = 2,
		radius = 20,
		respawn = 18,
	},
	{
		zone = "SoulSociety",
		enemy = "TrainingPuppet",
		position = Vector3.new(140, 0, -60),
		count = 3,
		radius = 25,
		respawn = 10,
	},
	{
		zone = "SoulSociety",
		enemy = "HollowBrute",
		position = Vector3.new(-150, 0, 120),
		count = 3,
		radius = 25,
		respawn = 16,
	},
	{
		zone = "HuecoMundo",
		enemy = "Arrancar",
		position = Vector3.new(150, 0, -60),
		count = 3,
		radius = 35,
		respawn = 18,
	},
	{
		zone = "HuecoMundo",
		enemy = "Arrancar",
		position = Vector3.new(-160, 0, 40),
		count = 3,
		radius = 35,
		respawn = 18,
	},
	{
		zone = "HuecoMundo",
		enemy = "MenosShade",
		position = Vector3.new(0, 0, -20),
		count = 1,
		radius = 10,
		respawn = 45,
	},
	{
		zone = "HuecoMundo",
		enemy = "HollowBrute",
		position = Vector3.new(200, 0, 180),
		count = 3,
		radius = 30,
		respawn = 16,
	},
}

Zones.Bosses = {
	{ zone = "Karakura", enemy = "Kurokage", position = Vector3.new(0, 0, 175), arena = 60 },
	{ zone = "Training", enemy = "InnerHollow", position = Vector3.new(100, 0, 120), arena = 45 },
	{ zone = "Training", enemy = "InnerSpirit", position = Vector3.new(0, 0, 150), arena = 45 },
	{ zone = "HuecoMundo", enemy = "VastoLeon", position = Vector3.new(0, 0, 230), arena = 70 },
}

function Zones.worldPosition(zoneId: string, relative: Vector3): Vector3
	return Zones.List[zoneId].center + relative
end

-- Determina a região de uma posição (caixa alinhada aos eixos).
function Zones.zoneAt(position: Vector3): string?
	for id, zone in Zones.List do
		local delta = position - zone.center
		local half = zone.size / 2
		if math.abs(delta.X) <= half.X and math.abs(delta.Z) <= half.Z and math.abs(delta.Y) <= half.Y then
			return id
		end
	end
	return nil
end

return Zones

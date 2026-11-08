-- Regiões dentro de uma ilha (por enquanto: as 5 regiões de Crystal Hollow, o Mundo 2).
-- Usado pelo servidor (construção, portais entre regiões, baús) e pelo cliente (nome da região
-- na tela, luz/névoa por região, sons ambientes).
--
-- Posições em coordenadas polares em torno do centro da ilha (θ em graus: 0 = +X, 90 = +Z),
-- o mesmo sistema de WorldBuilder.polar / WorldBuilder.Layout.

local Worlds = require(script.Parent.Worlds)

local Regions = {}

local function polar(worldId: string, theta: number, dist: number, y: number?): Vector3
	local c = Worlds.Info[worldId].center
	local r = math.rad(theta)
	return c + Vector3.new(math.cos(r) * dist, y or 0, math.sin(r) * dist)
end
Regions.polar = polar

-- Sons ambientes: o projeto não inventa IDs de áudio. Cole aqui IDs de sons do Creator Store
-- (ex.: "rbxassetid://123") e o cliente passa a tocá-los na região. Vazio = sem som.
Regions.Sounds = {
	valley = "", -- brisa / pássaros
	peaks = "", -- vento nas montanhas + cachoeira grande
	caverns = "", -- gotejamento e eco de caverna
	lake = "", -- água corrente / ondas leves
	titan = "", -- zumbido grave de cristais
	crystalHum = "", -- cintilar de cristais (perto dos aglomerados gigantes)
	harbor = "", -- vento suave, sinos, cordas do navio
	heights = "", -- vento alto, coral distante
	storm = "", -- trovões e vento forte
	gardens = "", -- pássaros, água de fonte
	arena = "", -- tempestade e zumbido elétrico
}

-- Perfis de luz por região (sobrepõem o perfil do mundo em WorldClient).
-- Só chaves presentes mudam; valores moderados (sem exagero de Bloom).
Regions.Info = {
	-- MUNDO 3 — Skybound Kingdom (ilha principal + ilhas satélites flutuando em volta)
	cloud_harbor = {
		world = "sky", name = "Cloud Harbor", subtitle = "Porto das Nuvens", theta = 0, dist = 0, radius = 130, priority = 1,
		sound = "harbor", profile = {},
	},
	golden_heights = {
		world = "sky", name = "Golden Heights", subtitle = "Alturas Douradas", theta = 34, dist = 322, radius = 92, priority = 3,
		sound = "heights", profile = { density = 0.2, haze = 1.0, glare = 0.5, rays = 0.14, exposure = 0.15, tint = Color3.fromRGB(255, 246, 228) },
	},
	storm_islands = {
		world = "sky", name = "Storm Islands", subtitle = "Ilhas da Tempestade", theta = 268, dist = 315, radius = 100, priority = 3,
		sound = "storm", profile = { density = 0.42, haze = 2.4, glare = 0.0, rays = 0.0, exposure = -0.25, bright = 1.8, contrast = 0.14, sat = -0.05,
			tint = Color3.fromRGB(214, 226, 255), fog = Color3.fromRGB(120, 134, 170), decay = Color3.fromRGB(40, 50, 90) },
	},
	celestial_gardens = {
		world = "sky", name = "Celestial Gardens", subtitle = "Jardins Celestes", theta = 160, dist = 312, radius = 92, priority = 3,
		sound = "gardens", profile = { density = 0.22, haze = 1.2, rays = 0.12, sat = 0.16, tint = Color3.fromRGB(255, 250, 240) },
	},
	tempest_arena = {
		world = "sky", name = "Tempest Arena", subtitle = "Arena da Tempestade", theta = 90, dist = 140, radius = 92, priority = 2,
		sound = "arena", profile = { density = 0.32, haze = 1.6, contrast = 0.12, rays = 0.04, exposure = -0.1, tint = Color3.fromRGB(226, 234, 255),
			fog = Color3.fromRGB(170, 186, 225) },
	},

	crystal_valley = {
		world = "crystal", name = "Crystal Valley", subtitle = "Vale dos Cristais", theta = 0, dist = 0, radius = 92, priority = 1,
		sound = "valley", profile = {},
	},
	shattered_peaks = {
		world = "crystal", name = "Shattered Peaks", subtitle = "Picos Estilhaçados", theta = 45, dist = 185, radius = 70, priority = 2,
		sound = "peaks", profile = { density = 0.26, haze = 2.2, offset = 0.35, rays = 0.12, exposure = 0.1 },
	},
	azure_caverns = {
		world = "crystal", name = "Azure Caverns", subtitle = "Cavernas Azuis", theta = 195, dist = 192, radius = 68, priority = 3,
		sound = "caverns",
		profile = { density = 0.5, haze = 0.4, offset = 0.0, rays = 0.0, exposure = -0.35, bright = 1.2, tint = Color3.fromRGB(214, 228, 255), sat = 0.18,
			fog = Color3.fromRGB(70, 100, 170), decay = Color3.fromRGB(30, 40, 90) },
	},
	prism_lake = {
		world = "crystal", name = "Prism Lake", subtitle = "Lago Prisma", theta = 140, dist = 165, radius = 76, priority = 3,
		sound = "lake", profile = { density = 0.24, haze = 1.4, glare = 0.4, rays = 0.1, sat = 0.12 },
	},
	ancient_beacon = {
		world = "crystal", name = "Farol Ancestral", subtitle = "Ruínas do Farol", theta = 294, dist = 100, radius = 52, priority = 2,
		sound = "valley", profile = { haze = 1.2, rays = 0.18, exposure = 0.12, tint = Color3.fromRGB(240, 236, 255) },
	},
	titans_domain = {
		world = "crystal", name = "Titan's Domain", subtitle = "Domínio do Titã", theta = 90, dist = 128, radius = 98, priority = 2,
		sound = "titan", profile = { density = 0.34, haze = 1.0, contrast = 0.14, tint = Color3.fromRGB(236, 230, 255), sat = 0.06 },
	},
}

-- Ordem do circuito de portais entre regiões (cada portal leva à próxima; todos voltam ao vale).
Regions.Circuits = {
	crystal = { "crystal_valley", "shattered_peaks", "azure_caverns", "prism_lake", "titans_domain" },
	sky = { "cloud_harbor", "golden_heights", "storm_islands", "celestial_gardens", "tempest_arena" },
}
Regions.Circuit = Regions.Circuits.crystal -- (compatibilidade)

-- Aberturas no muro invisível da borda da ilha principal (onde saem pontes e o cais). { theta, w (graus) }
Regions.Openings = {
	sky = { { theta = 40, w = 9 }, { theta = 268, w = 9 }, { theta = 160, w = 9 }, { theta = 345, w = 9 } },
}

-- Região "central" de cada mundo (destino do "Voltar" nos portais).
function Regions.hub(worldId: string): string?
	local c = Regions.Circuits[worldId]
	return c and c[1]
end

function Regions.circuitOf(regionId: string)
	local info = Regions.Info[regionId]
	return info and Regions.Circuits[info.world]
end

-- Áreas que a decoração aleatória e os detalhes do terreno não podem ocupar (lago, montanhas,
-- caverna, rio, lagoas). { theta, dist, r }
Regions.Reserved = {
	verdant = { -- bosque da árvore de blocos (árvore de destaque + família)
		{ theta = 38, dist = 120, r = 30 }, { theta = 24, dist = 152, r = 14 }, { theta = 52, dist = 185, r = 14 },
		{ theta = 34, dist = 196, r = 14 }, { theta = 20, dist = 132, r = 12 }, { theta = 40, dist = 80, r = 12 }, { theta = 66, dist = 216, r = 12 },
		-- (a Árvore-Santuário registra os pés das raízes, a escadaria e o elevador ao ser construída)
	},
	sky = {
		{ theta = 345, dist = 205, r = 24 }, -- cais do Cloud Harbor
		{ theta = 40, dist = 205, r = 18 }, -- cabeceira da ponte para Golden Heights
		{ theta = 268, dist = 205, r = 18 }, -- ponte para Storm Islands
		{ theta = 160, dist = 205, r = 18 }, -- ponte para Celestial Gardens
		{ theta = 25, dist = 200, r = 16 }, -- riacho e cachoeira da borda
		{ theta = 200, dist = 200, r = 16 },
		{ theta = 120, dist = 196, r = 16 },
		{ theta = 60, dist = 72, r = 16 }, -- pavilhão
		{ theta = 300, dist = 70, r = 14 }, -- templo pequeno
		{ theta = 90, dist = 228, r = 30 }, -- torres e cristais da arena
	},
	crystal = {
		{ theta = 45, dist = 190, r = 66 }, -- picos
		{ theta = 195, dist = 192, r = 48 }, -- maciço das cavernas
		{ theta = 140, dist = 165, r = 62 }, -- lago
		{ theta = 140, dist = 214, r = 18 }, -- riacho de saída do lago
		{ theta = 48, dist = 160, r = 16 }, -- rio (trechos)
		{ theta = 51, dist = 140, r = 14 },
		{ theta = 54, dist = 118, r = 14 },
		{ theta = 53, dist = 98, r = 14 },
		{ theta = 52, dist = 80, r = 16 }, -- lagoa do rio
		{ theta = 125, dist = 66, r = 13 }, -- lagoa do vale
		{ theta = 90, dist = 216, r = 30 }, -- templo, espigões e relicário atrás da arena
		{ theta = 294, dist = 100, r = 72 }, -- Farol Ancestral (torre, raízes e o campo de ruínas em volta)
	},
}

function Regions.center(id: string): Vector3
	local r = Regions.Info[id]
	return polar(r.world, r.theta, r.dist)
end

-- Região em que uma posição está (nil fora das regiões do mundo).
function Regions.at(worldId: string?, pos: Vector3): string?
	if not worldId then
		return nil
	end
	local best, bestPri = nil, -1
	for id, r in pairs(Regions.Info) do
		if r.world == worldId then
			local d = ((pos - polar(worldId, r.theta, r.dist)) * Vector3.new(1, 0, 1)).Magnitude
			if d <= r.radius and r.priority > bestPri then
				best, bestPri = id, r.priority
			end
		end
	end
	return best
end

function Regions.isReserved(worldId: string, pos: Vector3, margin: number?): boolean
	for _, a in ipairs(Regions.Reserved[worldId] or {}) do
		if ((pos - polar(worldId, a.theta, a.dist)) * Vector3.new(1, 0, 1)).Magnitude < a.r + (margin or 0) then
			return true
		end
	end
	return false
end

return Regions

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
}

-- Perfis de luz por região (sobrepõem o perfil do mundo em WorldClient).
-- Só chaves presentes mudam; valores moderados (sem exagero de Bloom).
Regions.Info = {
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
	titans_domain = {
		world = "crystal", name = "Titan's Domain", subtitle = "Domínio do Titã", theta = 90, dist = 128, radius = 98, priority = 2,
		sound = "titan", profile = { density = 0.34, haze = 1.0, contrast = 0.14, tint = Color3.fromRGB(236, 230, 255), sat = 0.06 },
	},
}

-- Ordem do circuito de portais entre regiões (cada portal leva à próxima; todos voltam ao vale).
Regions.Circuit = { "crystal_valley", "shattered_peaks", "azure_caverns", "prism_lake", "titans_domain" }

-- Áreas que a decoração aleatória e os detalhes do terreno não podem ocupar (lago, montanhas,
-- caverna, rio, lagoas). { theta, dist, r }
Regions.Reserved = {
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

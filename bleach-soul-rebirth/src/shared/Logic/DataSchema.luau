--!strict
-- Esquema do perfil salvo + migração de versões. Mantido puro para testes.
local DataSchema = {}

DataSchema.Version = 3

function DataSchema.template(): any
	return {
		version = DataSchema.Version,
		faction = nil,
		power = nil,
		level = 1,
		xp = 0,
		statPoints = 0,
		skillPoints = 0,
		stats = { Strength = 0, Spirit = 0, Vitality = 0, Agility = 0 },
		skills = {},
		unlocks = { Tier1 = false, Tier2 = false, Mask = false },
		currency = { Kan = 0, Shards = 0 },
		gacha = { rolls = 0, epicPity = 0, legendaryPity = 0, owned = {} },
		inventory = { items = {}, nextUid = 1 },
		equipped = {},
		lootPity = {},
		quests = {
			active = {},
			completed = {},
			tracked = nil,
			daily = { day = -1, ids = {}, progress = {}, claimed = {} },
		},
		discovered = { KarakuraPlaza = true },
		lastTravel = "KarakuraPlaza",
		settings = { shake = 1, vfx = "Ultra", cinematics = "Full", autoFace = true, music = 0.5 },
		record = { kills = 0, deaths = 0, bossKills = 0, playSeconds = 0 },
	}
end

-- Migrações: índice = versão de origem. Cada uma leva o perfil à versão seguinte.
DataSchema.Migrations = {
	-- v1 → v2: nível "Ultra" (acima de "Alta") vira o padrão; quem estava no antigo padrão sobe
	[1] = function(profile)
		if profile.settings and (profile.settings.vfx == nil or profile.settings.vfx == "High") then
			profile.settings.vfx = "Ultra"
		end
	end,
	-- v2 → v3: só duas classes (Humano → Shinigami e Hollow). Quincy e Fullbringer viram o caminho
	-- humano mantendo nível e itens; o poder antigo era da classe removida e sai (o servidor dá o
	-- poder inicial da nova classe no próximo spawn)
	[2] = function(profile)
		if profile.faction == "Quincy" or profile.faction == "Fullbringer" then
			profile.faction = "Shinigami"
			profile.power = nil
		end
	end,
} :: { [number]: (any) -> () }

function DataSchema.migrate(profile: any): any
	local version = profile.version or 0
	if version == 0 then
		profile.version = 1
		version = 1
	end
	while version < DataSchema.Version do
		local step = DataSchema.Migrations[version]
		if step then
			step(profile)
		end
		version += 1
		profile.version = version
	end
	return profile
end

local function reconcile(target: any, template: any)
	for k, v in template do
		if target[k] == nil then
			if type(v) == "table" then
				local copy = {}
				reconcile(copy, v)
				target[k] = copy
			else
				target[k] = v
			end
		elseif type(v) == "table" and type(target[k]) == "table" then
			reconcile(target[k], v)
		end
	end
end

-- Normaliza um perfil carregado (ou nil) para o formato atual.
function DataSchema.normalize(raw: any?): any
	local profile = if type(raw) == "table" then raw else DataSchema.template()
	DataSchema.migrate(profile)
	reconcile(profile, DataSchema.template())
	-- Sanidade numérica (dados corrompidos não podem derrubar o servidor)
	profile.level = math.max(1, math.floor(tonumber(profile.level) or 1))
	profile.xp = math.max(0, math.floor(tonumber(profile.xp) or 0))
	profile.statPoints = math.max(0, math.floor(tonumber(profile.statPoints) or 0))
	profile.skillPoints = math.max(0, math.floor(tonumber(profile.skillPoints) or 0))
	return profile
end

return DataSchema

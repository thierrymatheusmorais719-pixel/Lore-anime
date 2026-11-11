-- Esquema do perfil salvo + migração. Tudo que o jogador possui vive aqui.

local DataSchema = {}

DataSchema.Version = 1
DataSchema.MaxPets = 300
DataSchema.StartingCoins = 150 -- suficiente para o primeiro ovo

function DataSchema.default()
	return {
		version = DataSchema.Version,
		coins = DataSchema.StartingCoins,
		essence = 0,
		astral = 0,
		nextUid = 1,
		pets = {}, -- [uid string] = { uid, species, tier, level, xp, mutation, abilityRank, accessory, locked, hatchedAt, origin }
		team = {}, -- lista de uids (até Combat.TeamSize)
		items = {}, -- [itemId] = quantidade
		worlds = { verdant = true },
		bestiary = { pets = {}, enemies = {}, bosses = {} },
		collectionClaimed = {},
		buffs = {}, -- { id, source, label, category, bonus, expires }
		login = { day = 0, streak = 0, claimedAt = 0 },
		quests = { storyIndex = 1, storyProgress = 0, daily = { day = 0, ids = {}, progress = {}, claimed = {} }, side = {} },
		stats = { hatched = 0, kills = 0, bossKills = 0, coinsEarned = 0, resources = 0, treasures = 0, abilities = 0, evolutions = 0 },
		history = {}, -- descobertas importantes recentes
		claimedEncounters = {}, -- [encounterId] = os.time()  (anti-recompensa duplicada de boss)
		shrines = {}, -- [baúId] = os.time() da última abertura (baús-santuário das regiões)
		-- mineração de cristais (Config/Mining): nível da picareta, total minerado e contratos do dia
		mining = { pickaxe = 1, mined = 0, veins = 0, contractsDone = 0, contracts = { day = 0, ids = {}, done = {} } },
		settings = { announcements = true, vfx = "High", damageNumbers = true },
	}
end

local function fill(target, template)
	for k, v in pairs(template) do
		if target[k] == nil then
			if type(v) == "table" then
				local copy = {}
				fill(copy, v)
				target[k] = copy
			else
				target[k] = v
			end
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil then
			-- só completa sub-tabelas "de estrutura" (não listas/dicionários de conteúdo)
			local isStruct = false
			for kk in pairs(v) do
				if type(kk) == "string" then
					isStruct = true
					break
				end
			end
			if isStruct then
				fill(target[k], v)
			end
		end
	end
end

-- Completa campos faltantes e migra versões antigas. Nunca apaga dados do jogador.
function DataSchema.reconcile(data)
	if type(data) ~= "table" then
		return DataSchema.default()
	end
	fill(data, DataSchema.default())
	data.version = DataSchema.Version
	-- higiene: uids na equipe precisam existir
	local team = {}
	for _, uid in ipairs(data.team) do
		if data.pets[uid] then
			table.insert(team, uid)
		end
	end
	data.team = team
	return data
end

-- Remove encontros antigos (> 2 dias) para o perfil não crescer sem limite.
function DataSchema.pruneEncounters(data, now: number)
	for id, t in pairs(data.claimedEncounters) do
		if now - t > 2 * 86400 then
			data.claimedEncounters[id] = nil
		end
	end
end

return DataSchema

-- XP, níveis, atributos, árvore de habilidades e poderes (invocação com pity + compra direta).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Config.Progression)
local SkillTrees = require(Shared.Config.SkillTrees)
local Powers = require(Shared.Config.Powers)
local ProgressionLogic = require(Shared.Logic.ProgressionLogic)
local GachaLogic = require(Shared.Logic.GachaLogic)
local Signal = require(Shared.Util.Signal)

local Registry = require(script.Parent.Parent.Registry)

local ProgressionService = {}
ProgressionService.LevelUp = Signal.new() -- (player, newLevel)

local rng = Random.new()

function ProgressionService.AddXp(player: Player, amount: number, source: string?)
	local profile = Registry.DataService.Get(player)
	if not profile or amount <= 0 then
		return
	end
	local result = ProgressionLogic.addXp(profile, amount, Progression)
	Registry.UIService.Notify(
		player,
		"+" .. math.floor(amount) .. " XP" .. (if source then " · " .. source else ""),
		"xp"
	)
	if result.levelsGained > 0 then
		Registry.UIService.Notify(player, "NÍVEL " .. result.newLevel .. "!", "level", { level = result.newLevel })
		Registry.CharacterService.RefreshStats(player)
		local actor = Registry.CombatService.GetByPlayer(player)
		if actor then
			Registry.CombatService.Heal(actor, actor.humanoid.MaxHealth)
			Registry.CombatService.Broadcast(
				"LevelUp",
				{ actor = actor.model, level = result.newLevel },
				actor.root.Position
			)
		end
		ProgressionService.LevelUp:Fire(player, result.newLevel)
	end
	Registry.DataService.Sync(player)
end

function ProgressionService.AddCurrency(player: Player, kan: number, shards: number)
	local profile = Registry.DataService.Get(player)
	if not profile then
		return
	end
	profile.currency.Kan += math.max(0, math.floor(kan))
	profile.currency.Shards += math.max(0, math.floor(shards))
	Registry.DataService.Sync(player)
end

local function allocate(player: Player, payload: any): (boolean, any)
	local profile = Registry.DataService.Get(player)
	if not profile or type(payload) ~= "table" then
		return false, "Pedido inválido"
	end
	local ok, err = ProgressionLogic.allocate(profile, payload.attribute, tonumber(payload.amount) or 1, Progression)
	if ok then
		Registry.CharacterService.RefreshStats(player)
		Registry.DataService.Sync(player)
	end
	return ok, err
end

local function resetStats(player: Player): (boolean, any)
	local profile = Registry.DataService.Get(player)
	if not profile then
		return false, "Perfil não carregado"
	end
	ProgressionLogic.resetStats(profile)
	Registry.CharacterService.RefreshStats(player)
	Registry.DataService.Sync(player)
	return true, nil
end

local function unlockSkill(player: Player, payload: any): (boolean, any)
	local profile = Registry.DataService.Get(player)
	if not profile or type(payload) ~= "table" or type(payload.node) ~= "string" then
		return false, "Pedido inválido"
	end
	local ok, err = ProgressionLogic.unlockSkill(profile, SkillTrees.get(profile.faction), payload.node)
	if ok then
		Registry.CharacterService.RefreshStats(player)
		Registry.DataService.Sync(player)
	end
	return ok, err
end

local function rollPower(player: Player): (boolean, any)
	local profile = Registry.DataService.Get(player)
	if not profile or not profile.faction then
		return false, "Escolha uma facção primeiro"
	end
	if profile.currency.Shards < Powers.Gacha.rollCost then
		return false, "Fragmentos insuficientes (" .. Powers.Gacha.rollCost .. ")"
	end
	profile.currency.Shards -= Powers.Gacha.rollCost
	local pool = Powers.forFaction(profile.faction)
	local id = GachaLogic.roll(profile.gacha, pool, Powers.List, Powers.Rarities, Powers.Gacha, function()
		return rng:NextNumber()
	end)
	Registry.DataService.Sync(player)
	return true, { power = id }
end

local function buyPower(player: Player, payload: any): (boolean, any)
	local profile = Registry.DataService.Get(player)
	local id = type(payload) == "table" and payload.power
	local power = type(id) == "string" and Powers.get(id)
	if not profile or not power or power.faction ~= profile.faction then
		return false, "Poder inválido"
	end
	if profile.gacha.owned[id] then
		return false, "Você já possui este poder"
	end
	if profile.currency.Shards < Powers.Gacha.directCost then
		return false, "Fragmentos insuficientes (" .. Powers.Gacha.directCost .. ")"
	end
	profile.currency.Shards -= Powers.Gacha.directCost
	profile.gacha.owned[id] = true
	Registry.DataService.Sync(player)
	return true, { power = id }
end

function ProgressionService.Init()
	local UI = Registry.UIService
	UI.Register("AllocateStat", allocate)
	UI.Register("ResetStats", resetStats)
	UI.Register("UnlockSkill", unlockSkill)
	UI.Register("RollPower", rollPower)
	UI.Register("BuyPower", buyPower)
end

function ProgressionService.Start() end

return ProgressionService

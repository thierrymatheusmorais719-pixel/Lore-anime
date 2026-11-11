-- Missões (história + diárias), login diário e marcos de coleção.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local QuestLogic = require(Shared.Logic.QuestLogic)
local CollectionLogic = require(Shared.Logic.CollectionLogic)
local LuckConfig = require(Shared.Config.Luck)
local Net = require(Shared.Net)

local QuestService = {}

local S
local Push

local function today(): number
	return math.floor(os.time() / 86400)
end

function QuestService.init(registry)
	S = registry
	Push = Net.get("Push")
end

-- event = { type, target?, world?, amount? }
function QuestService.event(player: Player, event)
	local data = S.DataService.get(player)
	if not data then
		return
	end
	QuestLogic.ensureDaily(data, today())
	local completed = QuestLogic.onEvent(data, event)
	for _, q in ipairs(completed) do
		Push:FireClient(player, "Toast", { text = "Missão completa: " .. q.label .. " — resgate a recompensa!", kind = "quest" })
	end
	S.DataService.markDirty(player)
end

function QuestService.claimStory(player: Player)
	local data = S.DataService.get(player)
	if not data then
		return { ok = false }
	end
	local reward, q = QuestLogic.claimStory(data)
	if not reward then
		return { ok = false, msg = "Missão ainda não concluída" }
	end
	S.RewardService.grantBundle(player, reward, "Missão: " .. q.label, q.id)
	QuestLogic.syncState(data)
	return { ok = true }
end

function QuestService.claimSide(player: Player, lineId: string)
	local data = S.DataService.get(player)
	if not data or type(lineId) ~= "string" then
		return { ok = false }
	end
	local reward, q = QuestLogic.claimSide(data, lineId)
	if not reward then
		return { ok = false, msg = "Missão ainda não concluída" }
	end
	S.RewardService.grantBundle(player, reward, "Expedição: " .. q.label, "side:" .. lineId .. ":" .. q.id)
	return { ok = true }
end

function QuestService.claimDaily(player: Player, id: string)
	local data = S.DataService.get(player)
	if not data or type(id) ~= "string" then
		return { ok = false }
	end
	QuestLogic.ensureDaily(data, today())
	local reward, q = QuestLogic.claimDaily(data, id)
	if not reward then
		return { ok = false, msg = "Diária indisponível" }
	end
	S.RewardService.grantBundle(player, reward, "Diária: " .. q.label, "daily:" .. id .. ":" .. today())
	return { ok = true }
end

function QuestService.claimCollection(player: Player, id: string)
	local data = S.DataService.get(player)
	if not data or type(id) ~= "string" then
		return { ok = false }
	end
	local reward, m = CollectionLogic.claim(data, id)
	if not reward then
		return { ok = false, msg = "Marco indisponível" }
	end
	S.RewardService.grantBundle(player, reward, "Coleção: " .. m.label, id)
	return { ok = true }
end

-- Avisa quando um marco de coleção ficou disponível.
function QuestService.checkCollection(player: Player)
	local data = S.DataService.get(player)
	if not data then
		return
	end
	local list = CollectionLogic.claimable(data)
	if #list > 0 then
		player:SetAttribute("CollectionReady", #list)
	else
		player:SetAttribute("CollectionReady", 0)
	end
end

-- Login diário: sequência de dias consecutivos dá sorte por 24h (resgate automático ao entrar).
local function login(player: Player, data)
	local d = today()
	local l = data.login
	if l.day == d then
		return
	end
	if l.day == d - 1 then
		l.streak += 1
	else
		l.streak = 1
	end
	l.day = d
	l.claimedAt = os.time()
	local streak = math.min(l.streak, LuckConfig.Login.maxStreak)
	Push:FireClient(player, "Toast", {
		text = string.format("Login diário: sequência %d — +%d%% de sorte por 24h", l.streak, math.floor(streak * LuckConfig.Login.perStreakDay * 100 + 0.5)),
		kind = "luck",
	})
	S.DataService.markDirty(player)
end

function QuestService.start()
	S.DataService.onLoaded(function(player, data)
		QuestLogic.ensureDaily(data, today())
		QuestLogic.syncState(data)
		login(player, data)
		QuestService.checkCollection(player)
	end)
end

return QuestService

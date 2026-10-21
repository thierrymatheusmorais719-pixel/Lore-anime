-- Missões de história e diárias + diálogos dinâmicos com NPCs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Quests = require(Shared.Config.Quests)
local NPCs = require(Shared.Config.NPCs)
local Factions = require(Shared.Config.Factions)
local Zones = require(Shared.Config.Zones)
local QuestLogic = require(Shared.Logic.QuestLogic)
local Net = require(Shared.Net)
local Log = require(Shared.Util.Log)

local Registry = require(script.Parent.Parent.Registry)

local log = Log.new("QuestService")

local QuestService = {}

local dialogueRemote: RemoteEvent
local predecessor: { [string]: string } = {}
for id, quest in Quests.Story do
	if quest.next then
		predecessor[quest.next] = id
	end
end

local function profileOf(player: Player)
	return Registry.DataService.Get(player)
end

local function mentorResolver(profile)
	return function(id: string): string
		if id == "Mentor" then
			local faction = Factions.get(profile.faction)
			return faction and faction.mentor or "MentorShinigami"
		end
		return id
	end
end

local function today(): number
	return math.floor(os.time() / 86400)
end

-- Garante as diárias do dia atual.
function QuestService.EnsureDaily(player: Player, profile: any)
	local day = today()
	local daily = profile.quests.daily
	if daily.day == day then
		return
	end
	local pool = {}
	for id in Quests.DailyPool do
		table.insert(pool, id)
	end
	daily.day = day
	daily.ids = QuestLogic.dailySelection(day, player.UserId, pool, Quests.DailyCount)
	daily.progress = {}
	daily.claimed = {}
	for _, id in daily.ids do
		daily.progress[id] = QuestLogic.newProgress(Quests.DailyPool[id])
	end
end

local function grantRewards(player: Player, profile: any, rewards: any, title: string)
	if rewards.unlock then
		profile.unlocks[rewards.unlock] = true
		local faction = Factions.get(profile.faction)
		local label = rewards.unlock == "Mask" and Factions.Mask.name or (faction and faction.forms[rewards.unlock].name or rewards.unlock)
		Registry.UIService.Notify(player, "DESPERTAR: " .. label .. " desbloqueado! (" .. (rewards.unlock == "Mask" and "H" or "G") .. ")", "awaken", { unlock = rewards.unlock })
	end
	if rewards.skillPoints then
		profile.skillPoints += rewards.skillPoints
	end
	for _, item in rewards.items or {} do
		Registry.InventoryService.Give(player, item.id, item.qty)
	end
	Registry.ProgressionService.AddCurrency(player, rewards.kan or 0, rewards.shards or 0)
	if rewards.xp then
		Registry.ProgressionService.AddXp(player, rewards.xp, title)
	end
end

function QuestService.StartStory(player: Player, questId: string): (boolean, string?)
	local profile = profileOf(player)
	local quest = Quests.Story[questId]
	if not profile or not quest then
		return false, "Missão inválida"
	end
	local ok, err = QuestLogic.canAccept(profile, questId, quest)
	if not ok then
		return false, err
	end
	profile.quests.active[questId] = { progress = QuestLogic.newProgress(quest) }
	profile.quests.tracked = questId
	Registry.UIService.Notify(player, "Nova missão: " .. quest.name, "quest")
	Registry.DataService.Sync(player)
	-- Objetivos "Reach" já cumpridos contam imediatamente
	local actor = Registry.CombatService.GetByPlayer(player)
	if actor then
		local zone = Zones.zoneAt(actor.root.Position)
		if zone then
			QuestService.Event(player, { type = "Reach", zone = zone })
		end
	end
	return true, nil
end

function QuestService.CompleteStory(player: Player, questId: string)
	local profile = profileOf(player)
	local quest = Quests.Story[questId]
	local entry = profile and profile.quests.active[questId]
	if not profile or not quest or not entry or not QuestLogic.isComplete(quest, entry.progress) then
		return
	end
	profile.quests.active[questId] = nil
	profile.quests.completed[questId] = true
	if profile.quests.tracked == questId then
		profile.quests.tracked = quest.next
	end
	Registry.UIService.Notify(player, "Missão concluída: " .. quest.name, "questDone")
	grantRewards(player, profile, quest.rewards, quest.name)
	Registry.DataService.Sync(player)
end

-- Evento de jogo (abate, chegada, conversa, parry...) aplicado a todas as missões ativas.
function QuestService.Event(player: Player, event: QuestLogic.Event)
	local profile = profileOf(player)
	if not profile or not profile.faction then
		return
	end
	local resolve = mentorResolver(profile)
	local changed = false
	local toComplete = {}
	for questId, entry in profile.quests.active do
		local quest = Quests.Story[questId]
		if quest and QuestLogic.apply(quest, entry.progress, event, resolve) then
			changed = true
			if QuestLogic.isComplete(quest, entry.progress) then
				if quest.turnIn then
					Registry.UIService.Notify(player, quest.name .. ": volte e fale com seu mentor.", "quest")
				else
					table.insert(toComplete, questId)
				end
			end
		end
	end
	for _, questId in toComplete do
		QuestService.CompleteStory(player, questId)
	end
	QuestService.EnsureDaily(player, profile)
	local daily = profile.quests.daily
	for _, id in daily.ids do
		local quest = Quests.DailyPool[id]
		local progress = daily.progress[id]
		if quest and progress and not daily.claimed[id] and QuestLogic.apply(quest, progress, event, resolve) then
			changed = true
			if QuestLogic.isComplete(quest, progress) then
				daily.claimed[id] = true
				Registry.UIService.Notify(player, "Diária concluída: " .. quest.name, "questDone")
				grantRewards(player, profile, quest.rewards, quest.name)
			end
		end
	end
	if changed then
		Registry.DataService.Sync(player)
	end
end

-- Missões de história que o jogador pode aceitar agora.
function QuestService.Available(profile: any): { string }
	local list = {}
	for _, id in Quests.StoryOrder do
		local quest = Quests.Story[id]
		local prev = predecessor[id]
		local unlockedByChain = prev == nil or profile.quests.completed[prev]
		if id ~= "Awakening" and quest.giver and unlockedByChain and QuestLogic.canAccept(profile, id, quest) then
			table.insert(list, id)
		end
	end
	return list
end

-- ============================================================
-- Diálogo
-- ============================================================
local function npcModel(npcId: string): Model?
	local folder = workspace:FindFirstChild("NPCs")
	return folder and folder:FindFirstChild(npcId) :: Model? or nil
end

local function nearNpc(player: Player, npcId: string): boolean
	local model = npcModel(npcId)
	local character = player.Character
	if not model or not character or not model.PrimaryPart or not character.PrimaryPart then
		return false
	end
	return (model.PrimaryPart.Position - character.PrimaryPart.Position).Magnitude < 18
end

local function buildDialogue(player: Player, npcId: string, text: string?)
	local npc = NPCs[npcId]
	local profile = profileOf(player)
	if not npc or not profile then
		return nil
	end
	local options = {}
	local body = text or npc.greeting
	local isMentor = table.find(npc.roles, "Mentor") ~= nil
	local isMyMentor = isMentor and npc.faction == profile.faction

	if isMentor and not isMyMentor then
		body = text or "Você não é um dos meus. Procure quem fala a sua língua espiritual."
	end
	if isMyMentor then
		for questId, entry in profile.quests.active do
			local quest = Quests.Story[questId]
			if quest and quest.turnIn == "Mentor" and QuestLogic.isComplete(quest, entry.progress) then
				table.insert(options, { id = "turnin:" .. questId, text = "Entregar: " .. quest.name, accent = true })
			end
		end
		for _, questId in QuestService.Available(profile) do
			local quest = Quests.Story[questId]
			if quest.giver == "Mentor" then
				table.insert(options, { id = "accept:" .. questId, text = "Aceitar: " .. quest.name, accent = true, desc = quest.desc })
			end
		end
		-- Missões bloqueadas por nível: informar
		for _, questId in Quests.StoryOrder do
			local quest = Quests.Story[questId]
			local prev = predecessor[questId]
			if quest.level and profile.level < quest.level and not profile.quests.completed[questId] and not profile.quests.active[questId] and (prev == nil or profile.quests.completed[prev]) and (quest.faction == nil or quest.faction == profile.faction) then
				table.insert(options, { id = "locked:" .. questId, text = quest.name .. " (nível " .. quest.level .. ")", disabled = true })
			end
		end
	end
	if table.find(npc.roles, "Shop") then
		table.insert(options, { id = "shop", text = "Ver a loja" })
	end
	if table.find(npc.roles, "Forge") then
		table.insert(options, { id = "forge", text = "Forjar equipamentos" })
	end
	if table.find(npc.roles, "Daily") then
		table.insert(options, { id = "daily", text = "Quais são as tarefas de hoje?" })
	end
	if #npc.lore > 0 then
		table.insert(options, { id = "lore", text = "Algum conselho?" })
	end
	table.insert(options, { id = "close", text = "Até mais." })
	return {
		npc = npcId,
		name = npc.name,
		title = npc.title,
		text = body,
		options = options,
	}
end

function QuestService.OpenDialogue(player: Player, npcId: string)
	if not nearNpc(player, npcId) then
		return
	end
	QuestService.Event(player, { type = "Talk", npc = npcId })
	local payload = buildDialogue(player, npcId)
	if payload then
		dialogueRemote:FireClient(player, payload)
	end
end

local function dialogueChoice(player: Player, payload: any): (boolean, any)
	if type(payload) ~= "table" or type(payload.npc) ~= "string" or type(payload.option) ~= "string" then
		return false, "Pedido inválido"
	end
	local npcId, option = payload.npc, payload.option
	local npc = NPCs[npcId]
	local profile = profileOf(player)
	if not npc or not profile or not nearNpc(player, npcId) then
		return false, "Muito longe"
	end
	-- A opção precisa existir no estado atual (impede pular etapas via exploit)
	local current = buildDialogue(player, npcId)
	local valid = false
	for _, o in current and current.options or {} do
		if o.id == option and not o.disabled then
			valid = true
			break
		end
	end
	if not valid then
		return false, "Opção indisponível"
	end

	local kind, arg = option:match("^(%a+):?(.*)$")
	if kind == "accept" then
		local ok, err = QuestService.StartStory(player, arg)
		if not ok then
			return false, err
		end
		local quest = Quests.Story[arg]
		return true, { dialogue = buildDialogue(player, npcId, quest.desc) }
	elseif kind == "turnin" then
		QuestService.CompleteStory(player, arg)
		return true, { dialogue = buildDialogue(player, npcId, "Muito bem. Seu espírito ficou mais forte.") }
	elseif kind == "lore" then
		local line = npc.lore[math.random(1, #npc.lore)]
		return true, { dialogue = buildDialogue(player, npcId, line) }
	elseif kind == "shop" then
		return true, { open = "Shop" }
	elseif kind == "forge" then
		return true, { open = "Forge" }
	elseif kind == "daily" then
		QuestService.EnsureDaily(player, profile)
		return true, { open = "Quests" }
	elseif kind == "close" then
		return true, { close = true }
	end
	return false, "Opção desconhecida"
end

local function trackQuest(player: Player, payload: any): (boolean, any)
	local profile = profileOf(player)
	local id = type(payload) == "table" and payload.quest
	if not profile or type(id) ~= "string" or not profile.quests.active[id] then
		return false, "Missão inválida"
	end
	profile.quests.tracked = id
	Registry.DataService.Sync(player)
	return true, nil
end

function QuestService.Init()
	dialogueRemote = Net.event("Dialogue")
	Registry.UIService.Register("DialogueChoice", dialogueChoice)
	Registry.UIService.Register("TrackQuest", trackQuest)
end

function QuestService.Start()
	local CombatService = Registry.CombatService
	CombatService.Parried:Connect(function(defender)
		if defender.player then
			QuestService.Event(defender.player, { type = "Parry" })
		end
	end)
	Registry.AbilityService.AbilityUsed:Connect(function(actor)
		if actor.player then
			QuestService.Event(actor.player, { type = "UseAbility" })
		end
	end)
	Registry.TransformationService.Transformed:Connect(function(actor, form)
		if actor.player and form ~= "Base" then
			QuestService.Event(actor.player, { type = "Transform" })
		end
	end)
	Registry.DataService.ProfileLoaded:Connect(function(player, profile)
		QuestService.EnsureDaily(player, profile)
		Registry.DataService.Sync(player)
	end)
	log:Debug("QuestService pronto")
end

return QuestService

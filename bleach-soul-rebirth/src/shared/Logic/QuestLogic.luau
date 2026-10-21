--!strict
-- Progresso de missões (puro). Eventos: {type="Kill", enemy=id, boss=bool} {type="Reach", zone}
-- {type="Talk", npc} {type="Parry"} {type="UseAbility"} {type="Transform"}
local QuestLogic = {}

export type Event = { type: string, enemy: string?, zone: string?, npc: string?, boss: boolean? }

local function matches(objective: any, event: Event, resolveNpc: (string) -> string): boolean
	local t = objective.type
	if t == "Kill" then
		return event.type == "Kill" and event.enemy == objective.enemy
	elseif t == "Boss" then
		return event.type == "Kill" and event.boss == true and event.enemy == objective.enemy
	elseif t == "BossAny" then
		return event.type == "Kill" and event.boss == true
	elseif t == "Reach" then
		return event.type == "Reach" and event.zone == objective.zone
	elseif t == "Talk" then
		return event.type == "Talk" and event.npc == resolveNpc(objective.npc)
	elseif t == "Parry" or t == "UseAbility" or t == "Transform" then
		return event.type == t
	end
	return false
end

function QuestLogic.target(objective: any): number
	return objective.count or 1
end

function QuestLogic.isComplete(quest: any, progress: { number }): boolean
	for i, objective in quest.objectives do
		if (progress[i] or 0) < QuestLogic.target(objective) then
			return false
		end
	end
	return true
end

function QuestLogic.newProgress(quest: any): { number }
	local progress = {}
	for i in quest.objectives do
		progress[i] = 0
	end
	return progress
end

-- Aplica o evento a uma entrada de progresso. Retorna true se algo mudou.
function QuestLogic.apply(quest: any, progress: { number }, event: Event, resolveNpc: (string) -> string): boolean
	local changed = false
	for i, objective in quest.objectives do
		local current = progress[i] or 0
		local target = QuestLogic.target(objective)
		if current < target and matches(objective, event, resolveNpc) then
			progress[i] = current + 1
			changed = true
		end
	end
	return changed
end

-- Pode aceitar? (nível, facção, pré-requisito, não concluída nem ativa)
function QuestLogic.canAccept(profile: any, questId: string, quest: any): (boolean, string?)
	if profile.quests.completed[questId] then
		return false, "Já concluída"
	end
	if profile.quests.active[questId] then
		return false, "Já ativa"
	end
	if quest.level and profile.level < quest.level then
		return false, "Requer nível " .. quest.level
	end
	if quest.faction and profile.faction ~= quest.faction then
		return false, "Exclusiva de " .. quest.faction
	end
	if quest.requiresQuest and not profile.quests.completed[quest.requiresQuest] then
		return false, "Requer outra missão"
	end
	return true, nil
end

-- Seleção determinística das diárias (LCG simples, independente de math.random).
function QuestLogic.dailySelection(day: number, userId: number, poolIds: { string }, count: number): { string }
	local ids = table.clone(poolIds)
	table.sort(ids)
	local seed = (day * 7919 + userId % 2147483647) % 2147483647
	local function nextRandom(): number
		seed = (seed * 48271) % 2147483647
		return seed
	end
	for i = #ids, 2, -1 do
		local j = nextRandom() % i + 1
		ids[i], ids[j] = ids[j], ids[i]
	end
	local result = {}
	for i = 1, math.min(count, #ids) do
		result[i] = ids[i]
	end
	return result
end

return QuestLogic

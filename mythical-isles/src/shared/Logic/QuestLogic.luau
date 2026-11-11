-- Progresso de missões (puro).

local Quests = require(script.Parent.Parent.Config.Quests)

local QuestLogic = {}

-- 3 diárias determinísticas pelo número do dia (iguais em todos os servidores).
function QuestLogic.dailyFor(day: number): { string }
	local pool = {}
	for _, q in ipairs(Quests.DailyPool) do
		table.insert(pool, q.id)
	end
	local seed = (day * 1103515245 + 12345) % 2147483648
	local chosen = {}
	for _ = 1, math.min(Quests.DailyCount, #pool) do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local i = (seed % #pool) + 1
		table.insert(chosen, table.remove(pool, i))
	end
	return chosen
end

function QuestLogic.ensureDaily(data, day: number)
	local d = data.quests.daily
	if d.day ~= day then
		d.day = day
		d.ids = QuestLogic.dailyFor(day)
		d.progress = {}
		d.claimed = {}
	end
end

-- event = { type, target?, world?, amount }
function QuestLogic.matches(goal, event): boolean
	if goal.type ~= event.type then
		return false
	end
	if goal.target and goal.target ~= event.target then
		return false
	end
	if goal.world and goal.world ~= event.world then
		return false
	end
	return true
end

-- Atualiza progresso. Retorna lista de missões que acabaram de ficar completas.
function QuestLogic.onEvent(data, event)
	local completed = {}
	local amount = event.amount or 1
	local story = Quests.Story[data.quests.storyIndex]
	if story and QuestLogic.matches(story.goal, event) then
		local before = data.quests.storyProgress
		data.quests.storyProgress = math.min(story.goal.count, before + amount)
		if before < story.goal.count and data.quests.storyProgress >= story.goal.count then
			table.insert(completed, story)
		end
	end
	-- linhas paralelas (Quests.Side): a missão atual de cada linha
	for lineId, line in pairs(Quests.Side) do
		local st = QuestLogic.sideState(data, lineId)
		local q = line.list[st.index]
		if q and QuestLogic.matches(q.goal, event) then
			local before = st.progress
			st.progress = math.min(q.goal.count, before + amount)
			if before < q.goal.count and st.progress >= q.goal.count then
				table.insert(completed, q)
			end
		end
	end
	local d = data.quests.daily
	for _, id in ipairs(d.ids) do
		local q = Quests.findDaily(id)
		if q and not d.claimed[id] and QuestLogic.matches(q.goal, event) then
			local before = d.progress[id] or 0
			d.progress[id] = math.min(q.goal.count, before + amount)
			if before < q.goal.count and d.progress[id] >= q.goal.count then
				table.insert(completed, q)
			end
		end
	end
	return completed
end

-- Estado de uma linha paralela (cria se o perfil ainda não tem).
function QuestLogic.sideState(data, lineId: string)
	data.quests.side = data.quests.side or {}
	local st = data.quests.side[lineId]
	if not st then
		st = { index = 1, progress = 0 }
		data.quests.side[lineId] = st
	end
	return st
end

-- Resgata a missão atual de uma linha paralela. Retorna (recompensa, missão) ou nil.
function QuestLogic.claimSide(data, lineId: string)
	local line = Quests.Side[lineId]
	if not line then
		return nil
	end
	local st = QuestLogic.sideState(data, lineId)
	local q = line.list[st.index]
	if not q or st.progress < q.goal.count then
		return nil
	end
	st.index += 1
	st.progress = 0
	return q.reward, q
end

-- Resgata a missão da história atual. Retorna a recompensa ou nil.
function QuestLogic.claimStory(data)
	local story = Quests.Story[data.quests.storyIndex]
	if not story or data.quests.storyProgress < story.goal.count then
		return nil
	end
	data.quests.storyIndex += 1
	data.quests.storyProgress = 0
	return story.reward, story
end

function QuestLogic.claimDaily(data, id: string)
	local d = data.quests.daily
	local q = Quests.findDaily(id)
	if not q or d.claimed[id] or not table.find(d.ids, id) then
		return nil
	end
	if (d.progress[id] or 0) < q.goal.count then
		return nil
	end
	d.claimed[id] = true
	return q.reward, q
end

-- Missões cujo objetivo é um ESTADO (ex.: mundo já desbloqueado) — verifica ao carregar.
function QuestLogic.syncState(data)
	local story = Quests.Story[data.quests.storyIndex]
	if story and story.goal.type == "unlock_world" and data.worlds[story.goal.target] then
		data.quests.storyProgress = story.goal.count
	end
end

return QuestLogic

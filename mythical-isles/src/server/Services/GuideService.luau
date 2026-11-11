-- GUIA DO OBJETIVO: para cada jogador, descobre ONDE fica a missão atual (história; se ela não tem lugar no
-- mapa, a expedição das Terras Baixas) e publica nos atributos do jogador:
--   GuideTarget (Vector3), GuideLabel (texto), GuideWorld (id do mundo do alvo)
-- O cliente (Controllers/GuideClient) desenha o feixe e o marcador. Missões sem lugar (evoluir, usar
-- habilidade, ganhar moedas...) limpam o guia.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local Worlds = require(Shared.Config.Worlds)
local Enemies = require(Shared.Config.Enemies)
local Bosses = require(Shared.Config.Bosses)
local QuestLogic = require(Shared.Logic.QuestLogic)

local GuideService = {}

local S

function GuideService.init(registry)
	S = registry
end

local function flat(a: Vector3, b: Vector3): number
	return ((a - b) * Vector3.new(1, 0, 1)).Magnitude
end

local function bossWorld(bossId: string): string?
	for _, w in ipairs(Worlds.Order) do
		if Worlds.Info[w].bossId == bossId then
			return w
		end
	end
	return nil
end

-- Lugar de um objetivo. Devolve (posição, mundo) ou nil.
function GuideService.locate(goal, data, from: Vector3?, here: string?)
	local t = goal.type
	local worldId = goal.world or here or "verdant"
	if t == "defeat_enemy" then
		local wid = goal.target and Enemies.Info[goal.target] and Enemies.Info[goal.target].world or worldId
		local layout = S.WorldService.Layout[wid]
		if not layout then
			return nil
		end
		if goal.target and layout.enemyZones[goal.target] then
			return layout.enemyZones[goal.target].center, wid
		end
		local best, bd
		for _, z in pairs(layout.enemyZones) do
			local d = from and flat(z.center, from) or 0
			if not bd or d < bd then
				best, bd = z.center, d
			end
		end
		return best, wid
	elseif t == "defeat_boss" then
		local wid = goal.target and bossWorld(goal.target) or worldId
		local layout = S.WorldService.Layout[wid]
		return layout and layout.arena and layout.arena.center, wid
	elseif t == "hatch" then
		local layout = S.WorldService.Layout[worldId]
		if layout then
			for _, egg in ipairs(Worlds.Info[worldId].eggs) do
				local m = layout.eggStations[egg]
				if m and m.PrimaryPart then
					return m.PrimaryPart.Position, worldId
				elseif m then
					return m:GetPivot().Position, worldId
				end
			end
		end
	elseif t == "break_resource" then
		local layout = S.WorldService.Layout[worldId]
		local best, bd
		for _, f in ipairs(layout and layout.resourceFields or {}) do
			local d = from and flat(f.center, from) or 0
			if not bd or d < bd then
				best, bd = f.center, d
			end
		end
		return best, worldId
	elseif t == "unlock_world" then
		-- o portal que leva ao mundo pedido fica no mundo anterior a ele
		local target = goal.target
		local idx = target and Worlds.Info[target] and Worlds.Info[target].index
		local prev = idx and Worlds.Order[idx - 1]
		local layout = prev and S.WorldService.Layout[prev]
		return layout and layout.portalNext, prev
	elseif t == "mine_crystal" then
		local best, bd, bw
		for _, v in ipairs(S.MiningService.veins) do
			if v.alive and (not goal.target or v.cfg.crystal == goal.target) and (data.worlds[v.world] or v.world == "verdant") then
				local d = (from and v.world == here) and flat(v.pos, from) or (v.world == here and 0 or 1e6)
				if not bd or d < bd then
					best, bd, bw = v.pos, d, v.world
				end
			end
		end
		return best, bw
	elseif t == "open_shrine" or t == "open_treasure" then
		local reg = S.WorldService.Regions[worldId]
		local best, bd
		local now = os.time()
		for id, ch in pairs(reg and reg.chests or {}) do
			local last = data.shrines[id]
			local ready = not last or now - last >= 30 * 60
			if ready and ch.pos then
				local d = from and flat(ch.pos, from) or 0
				if not bd or d < bd then
					best, bd = ch.pos, d
				end
			end
		end
		return best, worldId
	end
	return nil
end

-- Missão a guiar: a da história se tiver lugar e não estiver pronta para resgatar; senão a expedição.
function GuideService.pick(data)
	local list = {}
	local story = Quests.Story[data.quests.storyIndex]
	if story and data.quests.storyProgress < story.goal.count then
		table.insert(list, story)
	end
	for _, lineId in ipairs(Quests.SideOrder) do
		local st = QuestLogic.sideState(data, lineId)
		local q = Quests.Side[lineId].list[st.index]
		if q and st.progress < q.goal.count then
			table.insert(list, q)
		end
	end
	return list
end

function GuideService.update(player: Player)
	local data = S.DataService.get(player)
	local root = S.CombatService.charRoot(player)
	if not data or not root then
		return
	end
	local here = player:GetAttribute("World") or S.WorldService.worldAt(root.Position)
	for _, q in ipairs(GuideService.pick(data)) do
		local pos, wid = GuideService.locate(q.goal, data, root.Position, here)
		if pos then
			player:SetAttribute("GuideTarget", pos)
			player:SetAttribute("GuideLabel", q.label)
			player:SetAttribute("GuideWorld", wid)
			return
		end
	end
	player:SetAttribute("GuideTarget", nil)
	player:SetAttribute("GuideLabel", nil)
	player:SetAttribute("GuideWorld", nil)
end

function GuideService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, p in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(GuideService.update, p)
				if not ok then
					warn("[GuideService]", err)
				end
			end
		end
	end)
	local _ = Bosses
end

return GuideService

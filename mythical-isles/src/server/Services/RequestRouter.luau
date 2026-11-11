-- Ponto único de entrada dos remotes. Valida tipos e frequência de CADA pedido antes de chamar
-- o serviço. Nada que o cliente envia é usado como valor (sorte, dano, preço, resultado).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RateLimiter = require(Shared.Util.RateLimiter)
local DropLogic = require(Shared.Logic.DropLogic)
local Drops = require(Shared.Config.Drops)
local Enemies = require(Shared.Config.Enemies)
local Bosses = require(Shared.Config.Bosses)

local RequestRouter = {}

local S
local requestLimiter = RateLimiter.new(20, 5, 0.05)

local function str(v)
	return type(v) == "string" and #v <= 64
end

local handlers = {}

handlers.Hatch = function(player, p)
	if type(p) ~= "table" or not str(p.egg) then
		return { ok = false }
	end
	return S.EggService.hatch(player, p.egg, p.count)
end
handlers.HatchItem = function(player, p)
	if type(p) ~= "table" or not str(p.egg) then
		return { ok = false }
	end
	return S.EggService.hatchItem(player, p.egg)
end
handlers.EggOdds = function(player, p)
	if type(p) ~= "table" or not str(p.egg) then
		return { ok = false }
	end
	return S.EggService.odds(player, p.egg)
end
handlers.SetTeam = function(player, p)
	if type(p) ~= "table" or type(p.uids) ~= "table" or #p.uids > 10 then
		return { ok = false }
	end
	return S.PetService.setTeam(player, p.uids)
end
handlers.AutoTeam = function(player)
	return S.PetService.autoTeam(player)
end
handlers.Evolve = function(player, p)
	if type(p) ~= "table" or not str(p.uid) then
		return { ok = false }
	end
	return S.PetService.evolve(player, p.uid)
end
handlers.UpgradeAbility = function(player, p)
	if type(p) ~= "table" or not str(p.uid) then
		return { ok = false }
	end
	return S.PetService.upgradeAbility(player, p.uid)
end
handlers.Lock = function(player, p)
	if type(p) ~= "table" or not str(p.uid) then
		return { ok = false }
	end
	return S.PetService.toggleLock(player, p.uid)
end
handlers.Release = function(player, p)
	if type(p) ~= "table" or type(p.uids) ~= "table" or #p.uids > 100 then
		return { ok = false }
	end
	return S.PetService.release(player, p.uids)
end
handlers.Accessory = function(player, p)
	if type(p) ~= "table" or not str(p.uid) or (p.item ~= nil and not str(p.item)) then
		return { ok = false }
	end
	return S.PetService.setAccessory(player, p.uid, p.item)
end
handlers.Catalyst = function(player, p)
	if type(p) ~= "table" or not str(p.uid) or not str(p.item) then
		return { ok = false }
	end
	return S.PetService.applyCatalyst(player, p.uid, p.item)
end
handlers.UsePotion = function(player, p)
	if type(p) ~= "table" or not str(p.item) then
		return { ok = false }
	end
	return S.LuckService.usePotion(player, p.item)
end
handlers.ClaimStory = function(player)
	return S.QuestService.claimStory(player)
end
handlers.ClaimDaily = function(player, p)
	if type(p) ~= "table" or not str(p.id) then
		return { ok = false }
	end
	return S.QuestService.claimDaily(player, p.id)
end
handlers.ClaimSide = function(player, p)
	if type(p) ~= "table" or not str(p.line) then
		return { ok = false }
	end
	return S.QuestService.claimSide(player, p.line)
end
handlers.ClaimCollection = function(player, p)
	if type(p) ~= "table" or not str(p.id) then
		return { ok = false }
	end
	return S.QuestService.claimCollection(player, p.id)
end
-- mineração: entregar contrato e melhorar a picareta (custos e cristais conferidos no servidor)
handlers.DeliverContract = function(player, p)
	if type(p) ~= "table" or not str(p.id) then
		return { ok = false }
	end
	return S.MiningService.deliver(player, p.id)
end
handlers.UpgradePickaxe = function(player)
	return S.MiningService.upgrade(player)
end
handlers.UnlockWorld = function(player, p)
	if type(p) ~= "table" or not str(p.world) then
		return { ok = false }
	end
	return S.WorldService.unlock(player, p.world)
end
handlers.Teleport = function(player, p)
	if type(p) ~= "table" or not str(p.world) then
		return { ok = false }
	end
	return S.WorldService.teleport(player, p.world)
end
handlers.Settings = function(player, p)
	local data = S.DataService.get(player)
	if not data or type(p) ~= "table" or not str(p.key) then
		return { ok = false }
	end
	if p.key == "announcements" or p.key == "damageNumbers" or p.key == "guide" then
		data.settings[p.key] = p.value == true
	elseif p.key == "vfx" and (p.value == "High" or p.value == "Low") then
		data.settings.vfx = p.value
	else
		return { ok = false }
	end
	S.DataService.markDirty(player)
	return { ok = true }
end
handlers.Luck = function(player)
	return { ok = true, luck = S.LuckService.view(player) }
end
-- Chances reais de drop de um inimigo/boss/tesouro com a sorte atual do jogador.
handlers.DropOdds = function(player, p)
	if type(p) ~= "table" or not str(p.source) then
		return { ok = false }
	end
	local tbl = p.source == "treasure" and Drops.Treasure or Drops.Tables[p.source]
	if not tbl then
		return { ok = false }
	end
	local name = (Enemies.Info[p.source] and Enemies.Info[p.source].name) or (Bosses.Info[p.source] and Bosses.Info[p.source].name) or "Tesouro"
	local mults = S.LuckService.mults(player)
	return { ok = true, source = p.source, name = name, odds = DropLogic.odds(tbl, mults), mults = mults }
end
handlers.Dev = function(player, p)
	return S.DevService.run(player, p)
end

function RequestRouter.init(registry)
	S = registry
end

function RequestRouter.start()
	local Request = Net.get("Request")
	local Action = Net.get("Action")
	Request.OnServerInvoke = function(player, action, payload)
		if type(action) ~= "string" or not handlers[action] then
			return { ok = false, msg = "Ação desconhecida" }
		end
		if not S.DataService.get(player) then
			return { ok = false, msg = "Carregando dados..." }
		end
		if not requestLimiter:allow(player) then
			return { ok = false, msg = "Muitos pedidos" }
		end
		local ok, result = pcall(handlers[action], player, payload)
		if not ok then
			warn("[RequestRouter]", action, result)
			return { ok = false, msg = "Erro no servidor" }
		end
		return result
	end
	Action.OnServerEvent:Connect(function(player, action, arg)
		if not S.DataService.get(player) then
			return
		end
		if action == "Target" then
			S.CombatService.setFocus(player, arg)
		elseif action == "Attack" then
			S.CombatService.playerAttack(player, arg)
		elseif action == "Ability" then
			S.CombatService.useAbility(player, arg)
		elseif action == "Mine" then
			S.ExplorationService.select(player, arg)
		elseif action == "OpenTreasure" then
			S.ExplorationService.open(player, arg)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		requestLimiter:clear(p)
	end)
end

return RequestRouter

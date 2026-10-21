-- Comandos de desenvolvimento — funcionam SOMENTE no Roblox Studio (RunService:IsStudio()).
-- Permitem testar progressão rapidamente: nível, desbloqueios, fragmentos, itens, teleporte.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local Zones = require(Shared.Config.Zones)
local Progression = require(Shared.Config.Progression)
local Log = require(Shared.Util.Log)

local Registry = require(script.Parent.Parent.Registry)

local log = Log.new("DevService")

local DevService = {}

local function dev(player: Player, payload: any): (boolean, any)
	if not RunService:IsStudio() then
		return false, "Indisponível"
	end
	local profile = Registry.DataService.Get(player)
	if not profile or type(payload) ~= "table" then
		return false, "Pedido inválido"
	end
	local command = payload.command
	if command == "level" then
		local target = math.clamp(math.floor(tonumber(payload.value) or 10), 1, Progression.MaxLevel)
		local total = 0
		for l = profile.level, target - 1 do
			total += Progression.xpToNext(l)
		end
		Registry.ProgressionService.AddXp(player, total - profile.xp + 1, "Dev")
	elseif command == "unlockAll" then
		profile.unlocks.Tier1 = true
		profile.unlocks.Tier2 = true
		profile.unlocks.Mask = true
		if profile.level < 15 then
			Registry.ProgressionService.AddXp(player, 1e6, "Dev")
		end
	elseif command == "shards" then
		Registry.ProgressionService.AddCurrency(player, 5000, 500)
	elseif command == "items" then
		for id in Items.List do
			Registry.InventoryService.Give(player, id, if Items.List[id].kind == "Material" then 30 else 1)
		end
	elseif command == "heal" then
		local actor = Registry.CombatService.GetByPlayer(player)
		if actor then
			Registry.CombatService.Heal(actor, 1e6)
			Registry.CombatService.AddReiatsu(actor, 1e6)
		end
	elseif command == "travel" then
		local point = tostring(payload.value)
		if Zones.TravelPoints[point] then
			profile.discovered[point] = true
			return Registry.WorldService.Teleport(player, point)
		end
		return false, "Ponto inválido"
	elseif command == "resetFaction" then
		profile.faction = nil
		profile.power = nil
		profile.quests.active = {}
		profile.quests.completed = {}
		if player.Character then
			player.Character:Destroy()
			player.Character = nil
		end
	else
		return false, "Comando desconhecido"
	end
	Registry.DataService.Sync(player)
	log:Info(player.Name, "usou comando dev:", command)
	return true, nil
end

function DevService.Init()
	Registry.UIService.Register("Dev", dev)
end

function DevService.Start() end

return DevService

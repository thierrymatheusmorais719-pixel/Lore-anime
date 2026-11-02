-- Comandos de TESTE. Funcionam SOMENTE no Roblox Studio (RunService:IsStudio()).
-- Em servidores publicados qualquer pedido é recusado.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Worlds = require(Shared.Config.Worlds)
local Combat = require(Shared.Config.Combat)
local InventoryLogic = require(Shared.Logic.InventoryLogic)

local DevService = {}

local S

function DevService.init(registry)
	S = registry
end

function DevService.enabled(): boolean
	return RunService:IsStudio()
end

function DevService.run(player: Player, p)
	if not DevService.enabled() then
		return { ok = false, msg = "Comandos de teste desativados" }
	end
	if type(p) ~= "table" or type(p.cmd) ~= "string" then
		return { ok = false }
	end
	local data = S.DataService.get(player)
	local cmd = p.cmd
	if cmd == "currency" then
		InventoryLogic.add(data, "coins", 1000000)
		InventoryLogic.add(data, "essence", 50000)
		InventoryLogic.add(data, "astral", 500)
	elseif cmd == "items" then
		for id, info in pairs(Items.Info) do
			InventoryLogic.add(data, id, info.kind == "material" and 50 or 3)
		end
	elseif cmd == "unlock" then
		for _, id in ipairs(Worlds.Order) do
			data.worlds[id] = true
		end
		S.CombatService.refreshPlayerHealth(player)
	elseif cmd == "levels" then
		for _, uid in ipairs(data.team) do
			local pet = data.pets[uid]
			pet.level = Combat.Tiers[pet.tier].levelCap
			pet.xp = 0
		end
		S.PetService.spawnTeam(player)
	elseif cmd == "luck_event" then
		S.LuckService.addManualEvent("dev_event", "Evento de teste (Studio)", 1.0, "All", 600)
	elseif cmd == "boss_phase" then
		local w = player:GetAttribute("World")
		if not S.BossService.debugDamage(w, 0.35) then
			return { ok = false, msg = "Nenhum boss em combate neste mundo (entre na arena)" }
		end
	elseif cmd == "treasure" then
		S.ExplorationService.spawnTreasure(player)
	elseif cmd == "star" then
		local root = S.CombatService.charRoot(player)
		if root then
			S.EnemyService.spawnWanderingStar(player, root.Position + Vector3.new(10, 0, 0), player:GetAttribute("World"))
		end
	elseif cmd == "luck_report" then
		local mults = S.LuckService.mults(player)
		return { ok = true, msg = game:GetService("HttpService"):JSONEncode(mults) }
	else
		return { ok = false, msg = "Comando desconhecido" }
	end
	S.DataService.markDirty(player)
	return { ok = true, msg = "OK: " .. cmd }
end

function DevService.start() end

return DevService

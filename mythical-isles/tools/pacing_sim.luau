-- RITMO de um jogador novo (servidor REAL no simulador): um "bot" nasce no Verdant Haven com as moedas iniciais,
-- choca o primeiro ovo e então, em ciclos, minera o recurso vivo mais perto (Mine) e ataca o inimigo mais perto
-- (Target + Attack), chocando mais ovos quando sobra dinheiro (mantém 1 ovo de reserva para o portal).
-- Mede moedas e essência por minuto e quando daria para abrir o Mundo 2. Andar é simulado por teleporte até perto
-- do alvo (otimista: um jogador real perde tempo andando).
-- Uso: python3 tools/run_tests.py luau --pacing
local Worlds = require(__proxy("Shared/Config/Worlds"))
local Eggs = require(__proxy("Shared/Config/Eggs"))
for _, id in ipairs(Worlds.Order) do
	local w = Worlds.Info[id]
	table.insert(SIM.groundPlanes, { center = w.center, radius = w.radius, y = w.center.Y })
	if w.lowlands then
		table.insert(SIM.groundPlanes, { center = w.center, radius = w.lowlands.radius, y = w.center.Y - w.lowlands.drop })
	end
end
__modules["Server/Main"](__proxy("Server/Main"))
SIM.run(0.5)
local Request = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("Request")
local Action = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("Action")
local S = {
	DataService = require(__proxy("Server/Services/DataService")),
	WorldService = require(__proxy("Server/Services/WorldService")),
	EnemyService = require(__proxy("Server/Services/EnemyService")),
	PetService = require(__proxy("Server/Services/PetService")),
}
local p = SIM.addPlayer("Novato", 7)
SIM.run(1)
local d = S.DataService.get(p)
local function heal()
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = hum.MaxHealth
	end
end
local function req(action, payload)
	heal()
	SIM.run(0.1)
	return Request.OnServerInvoke(p, action, payload)
end
local function act(name, arg)
	heal()
	Action.OnServerEvent:Fire(p, name, arg)
	SIM.run(1 / 30)
end
local center = Worlds.Info.verdant.center
local station = S.WorldService.Layout.verdant.eggStations.verdant_egg
local eggCost = Eggs.Info.verdant_egg.cost
local function hatch()
	SIM.teleport(p, station:GetPivot().Position + Vector3.new(0, 3, 6))
	SIM.run(0.4)
	local r = req("Hatch", { egg = "verdant_egg", count = 1 })
	if r.ok then
		req("AutoTeam")
	end
	return r.ok
end
print(string.format("PACE início: %d moedas, ovo %d", d.coins, eggCost))
hatch()
local function nearest(list, pos)
	local best, bd = nil, math.huge
	for _, m in ipairs(list) do
		local dd = (m:GetPivot().Position - pos).Magnitude
		if dd < bd then
			best, bd = m, dd
		end
	end
	return best
end
local unlockAt = nil
local mineT, fightT = 0, 0
for minute = 1, 20 do
	local tEnd = SIM.now + 60
	while SIM.now < tEnd do
		local here = p.Character and p.Character.PrimaryPart and p.Character.PrimaryPart.Position or center
		-- recurso vivo mais perto, dentro do planalto do Verdant Haven
		local res = {}
		for _, r in ipairs(workspace:FindFirstChild("Resources"):GetChildren()) do
			if (r:GetAttribute("Health") or 0) > 0 and ((r:GetPivot().Position - center) * Vector3.new(1, 0, 1)).Magnitude < Worlds.Info.verdant.radius then
				table.insert(res, r)
			end
		end
		local foes = {}
		for _, e in ipairs(S.EnemyService.activeList()) do
			if e.alive and e.world == "verdant" and e.model and e.model.Parent then
				table.insert(foes, e.model)
			end
		end
		local r = nearest(res, here)
		local f = nearest(foes, here)
		-- alterna: minera (o grosso das moedas) e luta (essência, XP)
		if r and (not f or (SIM.now % 40) < 26) then
			SIM.teleport(p, r:GetPivot().Position + Vector3.new(5, 3, 0))
			act("Mine", r)
			local t0 = SIM.now
			while (r:GetAttribute("Health") or 0) > 0 and r.Parent and SIM.now - t0 < 12 do
				act("Mine", r)
				SIM.run(0.5)
			end
			mineT += SIM.now - t0
		elseif f then
			SIM.teleport(p, f:GetPivot().Position + Vector3.new(10, 3, 0))
			act("Target", f)
			local t0 = SIM.now
			while f.Parent and not f:GetAttribute("Dead") and SIM.now - t0 < 15 do
				act("Attack", f)
				SIM.run(0.6)
			end
			fightT += SIM.now - t0
		else
			SIM.run(1)
		end
		-- mais ovos quando sobra (guarda o custo do portal do Mundo 2 depois de 3 pets)
		local reserve = (#d.team >= 3) and Worlds.Info.crystal.unlockCost or 0
		if d.coins >= eggCost + reserve and #d.team < 4 then
			hatch()
		end
		if not unlockAt and d.coins >= Worlds.Info.crystal.unlockCost then
			unlockAt = SIM.now
		end
	end
	print(string.format("PACE min %2d: %6d moedas, %4d essência, %d pets na equipe, nível médio %.1f, %d inimigos, %d recursos",
		minute, d.coins, d.essence, #d.team, (function()
			local n, s = 0, 0
			for _, uid in ipairs(d.team) do
				local pet = d.pets[uid]
				if pet then
					n += 1
					s += pet.level
				end
			end
			return n > 0 and s / n or 0
		end)(), d.stats.kills or 0, d.stats.resources or 0))
end
print(string.format("PACE tempo minerando %.0f s, lutando %.0f s; Mundo 2 (%d moedas) aos %s", mineT, fightT, Worlds.Info.crystal.unlockCost,
	unlockAt and string.format("%.1f min", unlockAt / 60) or "não alcançado em 20 min"))
print("INFO erros " .. #SIM.errors)
for _, e in ipairs(SIM.errors) do
	print("INFO " .. e)
end

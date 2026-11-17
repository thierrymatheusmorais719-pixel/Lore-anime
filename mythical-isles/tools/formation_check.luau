-- FORMAÇÃO dos pets (servidor real no simulador): uma equipe de tamanhos bem diferentes segue o dono, ataca um
-- inimigo e minera um recurso. Mede, em cada situação, a menor folga entre dois pets (distância horizontal entre os
-- centros menos a soma dos "raios" de cada um, metade do maior lado da caixa) e entre pet e dono. Folga negativa =
-- um pet dentro do outro.
-- Uso: python3 tools/run_tests.py luau --formation
local Worlds = require(__proxy("Shared/Config/Worlds"))
for _, id in ipairs(Worlds.Order) do
	local w = Worlds.Info[id]
	table.insert(SIM.groundPlanes, { center = w.center, radius = w.radius, y = w.center.Y })
	if w.lowlands then
		table.insert(SIM.groundPlanes, { center = w.center, radius = w.lowlands.radius, y = w.center.Y - w.lowlands.drop })
	end
end
__modules["Server/Main"](__proxy("Server/Main"))
SIM.run(0.5)
local S = {
	DataService = require(__proxy("Server/Services/DataService")),
	PetService = require(__proxy("Server/Services/PetService")),
	EnemyService = require(__proxy("Server/Services/EnemyService")),
}
local InventoryLogic = require(__proxy("Shared/Logic/InventoryLogic"))
local Action = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("Action")
local TEAMS = {
	{ "turfmammoth_1", "grovestag_1", "verdantwolf_1", "leafcat_1" },
	{ "eldermammoth_1", "behemoth_1", "elderstag_1", "astral_lion" },
	{ "kit_1", "hop_1", "owlet_1", "cap_1" },
}
local p = SIM.addPlayer("Formacao", 9)
SIM.run(1)
local d = S.DataService.get(p)
local center = Worlds.Info.verdant.center
local function radiusOf(m)
	local _, size = m:GetBoundingBox()
	return math.max(size.X, size.Z) / 2
end
local function measure(label)
	local team = S.PetService.team(p)
	local worstPP, worstPO = math.huge, math.huge
	local who = ""
	local char = p.Character
	local oroot = char and char.PrimaryPart
	for i = 1, #team do
		local a = team[i]
		if a.model and a.model.Parent then
			local ra = radiusOf(a.model)
			local pa = a.root.Position
			if oroot then
				local gap = ((pa - oroot.Position) * Vector3.new(1, 0, 1)).Magnitude - ra - 1.5
				worstPO = math.min(worstPO, gap)
			end
			for j = i + 1, #team do
				local b = team[j]
				if b.model and b.model.Parent then
					local gap = ((pa - b.root.Position) * Vector3.new(1, 0, 1)).Magnitude - ra - radiusOf(b.model)
					if gap < worstPP then
						worstPP = gap
						who = a.species .. " × " .. b.species
					end
				end
			end
		end
	end
	return worstPP, worstPO, who
end
for ti, species in ipairs(TEAMS) do
	-- equipe
	table.clear(d.team)
	for _, sp in ipairs(species) do
		local pet = InventoryLogic.addPet(d, sp, nil, os.time(), "formacao")
		table.insert(d.team, pet.uid)
	end
	S.PetService.spawnTeam(p)
	SIM.teleport(p, center + Vector3.new(30, 4, 30))
	SIM.run(3)
	-- seguindo: o dono anda em linha reta
	local wPP, wPO, who = math.huge, math.huge, ""
	for _ = 1, 40 do
		local root = p.Character.PrimaryPart
		SIM.teleport(p, root.Position + Vector3.new(0, 0, -0.6))
		SIM.run(0.1)
		local a, b, c = measure()
		if a < wPP then
			wPP, who = a, c
		end
		wPO = math.min(wPO, b)
	end
	print(string.format("FORM equipe %d seguindo: menor folga pet-pet %+.2f (%s), pet-dono %+.2f", ti, wPP, who, wPO))
	-- atacando um inimigo
	local foe
	for _, e in ipairs(S.EnemyService.activeList()) do
		if e.alive and e.world == "verdant" then
			foe = e
			break
		end
	end
	if foe then
		foe.maxHp = 1e9
		foe.hp = 1e9
		-- alvo parado (estado estável); a transição também é medida
		local foeHome = foe.root.Position
		foe.model.PrimaryPart.Anchored = true
		SIM.teleport(p, foe.root.Position + Vector3.new(12, 3, 0))
		Action.OnServerEvent:Fire(p, "Target", foe.model)
		wPP, who = math.huge, ""
		local steady, whoS = math.huge, ""
		for k = 1, 60 do
			foe.model:PivotTo(CFrame.new(foeHome))
			SIM.run(0.1)
			local a, _, c = measure()
			if a < wPP then
				wPP, who = a, c
			end
			if k > 40 and a < steady then
				steady, whoS = a, c
			end
		end
		print(string.format("FORM equipe %d atacando: estável %+.2f (%s); pior na chegada %+.2f (%s)", ti, steady, whoS, wPP, who))
		-- larga o alvo (a fase seguinte é de mineração)
		foe.hp = 0
		foe.alive = false
		for _, st in ipairs(S.PetService.team(p)) do
			st.target = nil
		end
	end
	-- minerando
	local node
	for _, r in ipairs(workspace:FindFirstChild("Resources"):GetChildren()) do
		if (r:GetAttribute("Health") or 0) > 0 and ((r:GetPivot().Position - center) * Vector3.new(1, 0, 1)).Magnitude < 150 then
			node = r
			break
		end
	end
	if node then
		node:SetAttribute("Health", 1e9)
		SIM.teleport(p, node:GetPivot().Position + Vector3.new(8, 3, 0))
		Action.OnServerEvent:Fire(p, "Mine", node)
		wPP, who = math.huge, ""
		local worstNode = math.huge
		local nodeR = math.max(node:GetExtentsSize().X, node:GetExtentsSize().Z) / 2
		for k = 1, 60 do
			if k % 10 == 1 then
				Action.OnServerEvent:Fire(p, "Mine", node) -- (como o jogador: clica de novo; o limitador ignora repetidos)
			end
			SIM.run(0.1)
			if k > 40 then
				local a, _, c = measure()
				if a < wPP then
					wPP, who = a, c
				end
				for _, st in ipairs(S.PetService.team(p)) do
					local gap = ((st.root.Position - node:GetPivot().Position) * Vector3.new(1, 0, 1)).Magnitude - radiusOf(st.model) - nodeR
					worstNode = math.min(worstNode, gap)
				end
			end
		end
		local mining = 0
		for _, st in ipairs(S.PetService.team(p)) do
			if st.mineTarget == node then
				mining += 1
			end
		end
		print(string.format("FORM equipe %d minerando (%d pets no recurso, estável): menor folga pet-pet %+.2f (%s), pet-recurso %+.2f", ti, mining, wPP, who, worstNode))
	end
end
print("INFO erros " .. #SIM.errors)

-- INIMIGOS: patrulhando nas zonas do Verdant Haven por 60 s, a menor folga entre dois inimigos vizinhos (informativo:
-- o simulador não tem colisão; no Roblox a raiz dos inimigos que andam colide, o que evita sobreposições fundas)
do
	SIM.teleport(p, Vector3.new(0, 500, 0) + Worlds.Info.verdant.center) -- longe (sem perseguição)
	local function rad(e)
		local _, size = e.model:GetBoundingBox()
		return math.max(size.X, size.Z) / 2
	end
	local worst, who = math.huge, ""
	local pairsBad = {}
	for k = 1, 120 do
		SIM.run(0.5)
		local list = {}
		for _, e in ipairs(S.EnemyService.activeList()) do
			if e.alive and e.world == "verdant" and e.model and e.model.Parent then
				table.insert(list, e)
			end
		end
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				local gap = ((a.root.Position - b.root.Position) * Vector3.new(1, 0, 1)).Magnitude - rad(a) - rad(b)
				if gap < worst then
					worst, who = gap, a.id .. " × " .. b.id
				end
				if gap < -0.5 then
					pairsBad[a.id .. "×" .. b.id] = true
				end
			end
		end
	end
	local nb = 0
	for _ in pairs(pairsBad) do
		nb += 1
	end
	print(string.format("FORM inimigos patrulhando (60 s): menor folga %+.2f (%s); %d pares chegaram a se sobrepor", worst, who, nb))
end

-- Pets da equipe: modelos no mundo (com mutação/acessório/estágio), movimento, gestão de equipe,
-- evolução, upgrades, catalisadores e bônus passivos. O estado de combate de cada pet vive aqui
-- e é usado pelo CombatService.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Pets = require(Shared.Config.Pets)
local Combat = require(Shared.Config.Combat)
local Abilities = require(Shared.Config.Abilities)
local Items = require(Shared.Config.Items)
local PetStats = require(Shared.Logic.PetStats)
local InventoryLogic = require(Shared.Logic.InventoryLogic)
local CreatureBuilder = require(Shared.Builders.CreatureBuilder)
local MutationVisuals = require(Shared.Builders.MutationVisuals)
local Accessories = require(Shared.Builders.Accessories)
local Make = require(Shared.Util.Make)

local PetService = {}

local S
local teams: { [Player]: { any } } = {}
local folderFor: { [Player]: Folder } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local TIER_SCALE = { 1.0, 1.15, 1.3 }

function PetService.init(registry)
	S = registry
end

function PetService.team(player: Player)
	return teams[player] or {}
end

function PetService.allTeams()
	return teams
end

-------------------------------------------------------------------------------
-- Estatísticas efetivas (com sinergias)
-------------------------------------------------------------------------------

local function teamComposition(data)
	local roles, species = {}, {}
	for _, uid in ipairs(data.team) do
		local pet = data.pets[uid]
		if pet then
			table.insert(roles, Pets.Species[pet.species].role)
			table.insert(species, pet.species)
		end
	end
	return roles, species
end

function PetService.synergy(player: Player)
	local data = S.DataService.get(player)
	if not data then
		return {}, { atk = 0, def = 0, hp = 0, cdr = 0, luckTreasure = 0 }, {}
	end
	local roles, species = teamComposition(data)
	local active, effects = PetStats.synergies(roles)
	local sets = PetStats.worldSets(species)
	return active, effects, sets
end

local function effectiveStats(pet, effects)
	local st = PetStats.compute(pet)
	st.hp = math.floor(st.hp * (1 + (effects.hp or 0)))
	st.atk = st.atk * (1 + (effects.atk or 0))
	st.def = st.def * (1 + (effects.def or 0))
	st.cdr = effects.cdr or 0
	return st
end

-- Contribuições de sorte da equipe (perks dos pets + sinergia de tesouro).
function PetService.luckContributions(player: Player)
	local data = S.DataService.get(player)
	local perks, synergy = {}, {}
	if not data then
		return perks, synergy
	end
	for _, uid in ipairs(data.team) do
		local pet = data.pets[uid]
		local sp = pet and Pets.Species[pet.species]
		if sp and sp.perk and sp.perk.kind == "luck" then
			table.insert(perks, { label = sp.name, category = sp.perk.category, bonus = sp.perk.bonus })
		end
	end
	local _, effects = PetService.synergy(player)
	if (effects.luckTreasure or 0) > 0 then
		table.insert(synergy, { label = "Desbravador", category = "Treasure", bonus = effects.luckTreasure })
	end
	return perks, synergy
end

function PetService.coinBonus(player: Player): number
	local data = S.DataService.get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, uid in ipairs(data.team) do
		local pet = data.pets[uid]
		local sp = pet and Pets.Species[pet.species]
		if sp and sp.perk and sp.perk.kind == "coins" then
			total += sp.perk.bonus
		end
	end
	return total
end

-------------------------------------------------------------------------------
-- Modelos
-------------------------------------------------------------------------------

function PetService.buildModel(pet)
	local sp = Pets.Species[pet.species]
	local scale = TIER_SCALE[pet.tier or 1] or 1
	local model, hover, flies = CreatureBuilder.build(pet.species, sp, scale)
	MutationVisuals.apply(model, pet.mutation)
	Accessories.apply(model, pet.accessory)
	if (pet.tier or 1) >= 2 then
		local torso = model:FindFirstChild("Torso")
		if torso then
			local aura = Instance.new("ParticleEmitter")
			aura.Name = "TierAura"
			aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			aura.Rate = pet.tier == 3 and 6 or 3
			aura.Lifetime = NumberRange.new(0.6, 1.0)
			aura.Speed = NumberRange.new(1, 2)
			aura.Size = NumberSequence.new(0.25, 0)
			aura.LightEmission = 0.7
			aura.Color = ColorSequence.new(pet.tier == 3 and Color3.fromRGB(255, 140, 220) or Color3.fromRGB(255, 230, 140))
			aura.Parent = torso
		end
	end
	model:SetAttribute("Tier", pet.tier or 1)
	-- para o visual de malha do cliente (PetVisuals): altura do servidor e escala da evolução
	model:SetAttribute("Hover", hover)
	model:SetAttribute("Scale", scale)
	return model, hover, flies
end

local function attachMovers(state)
	local root = state.root
	local att = Make("Attachment", { Name = "MoveAtt", Parent = root })
	state.align = Make("AlignPosition", {
		Mode = Enum.PositionAlignmentMode.OneAttachment, Attachment0 = att, MaxForce = 1e6, Responsiveness = 28,
		MaxVelocity = 60, Position = root.Position, Parent = root,
	})
	state.orient = Make("AlignOrientation", {
		Mode = Enum.OrientationAlignmentMode.OneAttachment, Attachment0 = att, MaxTorque = 1e6, Responsiveness = 22,
		CFrame = root.CFrame, Parent = root,
	})
end

local function despawnTeam(player: Player)
	local list = teams[player]
	if list then
		for _, st in ipairs(list) do
			if st.model then
				st.model:Destroy()
			end
		end
	end
	teams[player] = {}
end

local function ownerRoot(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- (Re)cria os modelos da equipe a partir do perfil.
function PetService.spawnTeam(player: Player)
	local data = S.DataService.get(player)
	if not data then
		return
	end
	local old = {}
	for _, st in ipairs(teams[player] or {}) do
		old[st.uid] = st
	end
	despawnTeam(player)
	local folder = folderFor[player]
	if not folder then
		folder = Make("Folder", { Name = tostring(player.UserId), Parent = workspace:FindFirstChild("Pets") })
		folderFor[player] = folder
	end
	local _, effects = PetService.synergy(player)
	local origin = ownerRoot(player)
	local list = {}
	for slot, uid in ipairs(data.team) do
		local pet = data.pets[uid]
		if pet then
			local model, hover, flies = PetService.buildModel(pet)
			local stats = effectiveStats(pet, effects)
			local prev = old[uid]
			local state = {
				uid = uid, slot = slot, player = player, pet = pet, species = pet.species, stats = stats,
				model = model, root = model.PrimaryPart, hover = hover, flies = flies,
				hp = prev and math.min(prev.hp, stats.hp) or stats.hp, maxHp = stats.hp,
				energy = prev and prev.energy or stats.energy, shield = 0, shieldUntil = 0,
				knockedUntil = prev and prev.knockedUntil or 0, target = nil, lastAttackAt = 0,
				abilityReadyAt = prev and prev.abilityReadyAt or 0, hasteUntil = 0, mode = "follow",
				goal = nil, lastCombatAt = prev and prev.lastCombatAt or 0,
			}
			model.Name = "Pet_" .. uid
			model:SetAttribute("Owner", player.UserId)
			model:SetAttribute("Uid", uid)
			model:SetAttribute("Slot", slot)
			model:SetAttribute("Flies", flies)
			local start = origin and (origin.CFrame * CFrame.new((slot - 2.5) * 4, 0, 6)) or CFrame.new(0, 10, 0)
			model:PivotTo(start)
			model.Parent = folder
			state.root.CanCollide = false
			pcall(function()
				state.root:SetNetworkOwner(nil)
			end)
			attachMovers(state)
			table.insert(list, state)
			PetService.syncAttributes(state)
		end
	end
	teams[player] = list
end

function PetService.syncAttributes(state)
	local m = state.model
	if not m or not m.Parent then
		return
	end
	m:SetAttribute("Health", math.floor(state.hp))
	m:SetAttribute("MaxHealth", state.maxHp)
	m:SetAttribute("Energy", math.floor(state.energy))
	m:SetAttribute("MaxEnergy", state.stats.energy)
	m:SetAttribute("Shield", math.floor(state.shield))
	m:SetAttribute("Knocked", os.clock() < state.knockedUntil)
	m:SetAttribute("AbilityReadyAt", state.abilityReadyAtServer or 0)
end

function PetService.teleportPets(player: Player, pos: Vector3)
	for i, st in ipairs(teams[player] or {}) do
		if st.model and st.model.Parent then
			st.model:PivotTo(CFrame.new(pos + Vector3.new((i - 2.5) * 4, 3, 6)))
			st.align.Position = st.root.Position
			st.target = nil
		end
	end
end

-------------------------------------------------------------------------------
-- Movimento
-------------------------------------------------------------------------------

local function groundY(pos: Vector3, fallback: number): number
	local result = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), rayParams)
	if result then
		return result.Position.Y
	end
	return fallback
end

local FORMATION = { Vector3.new(-4, 0, 5), Vector3.new(4, 0, 5), Vector3.new(-7, 0, 9), Vector3.new(7, 0, 9) }

local function updateMovement(dt: number)
	local excludes = { workspace:FindFirstChild("Pets"), workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Bosses"), workspace:FindFirstChild("Telegraphs"), workspace:FindFirstChild("Fx"), workspace:FindFirstChild("Treasures") }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(excludes, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = excludes
	local now = os.clock()
	for player, list in pairs(teams) do
		local oroot = ownerRoot(player)
		if oroot then
			for _, st in ipairs(list) do
				if st.model and st.model.Parent and st.align then
					local desired: Vector3
					local face: Vector3? = nil
					local knocked = now < st.knockedUntil
					local tgtPos = (not knocked) and st.target and st.target.alive and st.target.root and st.target.root.Position
					if tgtPos then
						local stop = math.max(st.stats.range * 0.75, 3) + (st.target.radius or 2)
						local from = st.root.Position
						local dir = (from - tgtPos) * Vector3.new(1, 0, 1)
						if dir.Magnitude < 0.1 then
							dir = Vector3.new(1, 0, 0)
						end
						-- espalha os pets ao redor do alvo para não empilharem
						local spread = CFrame.Angles(0, (st.slot - 2.5) * 0.5, 0):VectorToWorldSpace(dir.Unit)
						desired = tgtPos + spread * stop
						face = tgtPos
					elseif st.mineTarget and st.mineTarget.Parent then
						local rp = st.mineTarget:GetPivot().Position
						local a = st.slot / 4 * math.pi * 2
						desired = rp + Vector3.new(math.cos(a), 0, math.sin(a)) * 5
						face = rp
					else
						local off = FORMATION[st.slot] or Vector3.new(0, 0, 8)
						desired = (oroot.CFrame * CFrame.new(off)).Position
					end
					-- coleira: nunca longe demais do dono
					local toOwner = (desired - oroot.Position) * Vector3.new(1, 0, 1)
					if toOwner.Magnitude > Combat.PetLeash then
						desired = oroot.Position + toOwner.Unit * Combat.PetLeash
					end
					local gy = groundY(desired, oroot.Position.Y - 3)
					local height = st.flies and st.hover + 1.5 + math.sin(now * 2 + st.slot) * 0.4 or st.hover
					desired = Vector3.new(desired.X, gy + height, desired.Z)
					-- teleporta se ficou muito para trás (ex.: dono teleportou / caiu)
					if (st.root.Position - desired).Magnitude > 140 then
						st.model:PivotTo(CFrame.new(desired))
					end
					st.align.Position = desired
					st.align.MaxVelocity = knocked and 18 or 60
					local look = face or (desired + (desired - st.root.Position) * Vector3.new(1, 0, 1))
					local flat = (look - st.root.Position) * Vector3.new(1, 0, 1)
					if flat.Magnitude > 0.5 then
						st.orient.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
					end
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Gestão da equipe / inventário de pets
-------------------------------------------------------------------------------

function PetService.setTeam(player: Player, uids)
	local data = S.DataService.get(player)
	if not data or type(uids) ~= "table" then
		return { ok = false, msg = "Pedido inválido" }
	end
	local clean, seen = {}, {}
	for _, uid in ipairs(uids) do
		if type(uid) == "string" and data.pets[uid] and not seen[uid] then
			seen[uid] = true
			table.insert(clean, uid)
		end
		if #clean >= Combat.TeamSize then
			break
		end
	end
	data.team = clean
	PetService.spawnTeam(player)
	S.DataService.markDirty(player)
	S.LuckService.push(player, true)
	return { ok = true }
end

-- Melhor equipe por "poder" (atalho da interface).
function PetService.autoTeam(player: Player)
	local data = S.DataService.get(player)
	if not data then
		return { ok = false }
	end
	local list = {}
	for uid, pet in pairs(data.pets) do
		table.insert(list, { uid = uid, power = PetStats.compute(pet).power })
	end
	table.sort(list, function(a, b)
		return a.power > b.power
	end)
	local uids = {}
	for i = 1, math.min(Combat.TeamSize, #list) do
		table.insert(uids, list[i].uid)
	end
	return PetService.setTeam(player, uids)
end

local function refresh(player: Player, uid: string)
	local data = S.DataService.get(player)
	if data and table.find(data.team, uid) then
		PetService.spawnTeam(player)
	end
	S.DataService.markDirty(player)
end

function PetService.evolve(player: Player, uid: string)
	local data = S.DataService.get(player)
	local pet = data and data.pets[uid]
	if not pet then
		return { ok = false, msg = "Pet inválido" }
	end
	local can, why = PetStats.canEvolve(pet)
	if not can then
		return { ok = false, msg = why }
	end
	local cost = PetStats.evolutionCost(pet)
	local afford, missing = InventoryLogic.canAfford(data, cost)
	if not afford then
		return { ok = false, msg = missing }
	end
	InventoryLogic.spend(data, cost)
	pet.tier += 1
	pet.xp = 0
	data.stats.evolutions += 1
	S.QuestService.event(player, { type = "evolve" })
	refresh(player, uid)
	return { ok = true, msg = string.format("%s evoluiu para %s!", Pets.Species[pet.species].name, Combat.Tiers[pet.tier].label) }
end

function PetService.upgradeAbility(player: Player, uid: string)
	local data = S.DataService.get(player)
	local pet = data and data.pets[uid]
	if not pet then
		return { ok = false, msg = "Pet inválido" }
	end
	local rank = pet.abilityRank or 1
	if rank >= Abilities.MaxRank then
		return { ok = false, msg = "Habilidade no nível máximo" }
	end
	local cost = Abilities.UpgradeCost(rank)
	local afford, missing = InventoryLogic.canAfford(data, cost)
	if not afford then
		return { ok = false, msg = missing }
	end
	InventoryLogic.spend(data, cost)
	pet.abilityRank = rank + 1
	S.QuestService.event(player, { type = "upgrade_ability" })
	refresh(player, uid)
	return { ok = true, msg = "Habilidade melhorada para o nível " .. pet.abilityRank }
end

function PetService.toggleLock(player: Player, uid: string)
	local data = S.DataService.get(player)
	local pet = data and data.pets[uid]
	if not pet then
		return { ok = false }
	end
	pet.locked = not pet.locked
	S.DataService.markDirty(player)
	return { ok = true, locked = pet.locked }
end

-- Libera pets (não trancados). Devolve um pouco de essência para não ser só perda.
function PetService.release(player: Player, uids)
	local data = S.DataService.get(player)
	if not data or type(uids) ~= "table" then
		return { ok = false }
	end
	local count, essence = 0, 0
	local inTeam = false
	for _, uid in ipairs(uids) do
		if type(uid) == "string" then
			local pet = data.pets[uid]
			if pet and not pet.locked then
				if table.find(data.team, uid) then
					inTeam = true
				end
				local sp = Pets.Species[pet.species]
				essence += math.max(1, math.floor(require(Shared.Config.Rarities).Info[sp.rarity].rank * 2))
				InventoryLogic.removePet(data, uid)
				count += 1
			end
		end
		if count >= 100 then
			break
		end
	end
	if essence > 0 then
		InventoryLogic.add(data, "essence", essence)
	end
	if inTeam then
		PetService.spawnTeam(player)
	end
	S.DataService.markDirty(player)
	return { ok = true, msg = string.format("%d pets liberados (+%d essência)", count, essence) }
end

function PetService.setAccessory(player: Player, uid: string, itemId: string?)
	local data = S.DataService.get(player)
	local pet = data and data.pets[uid]
	if not pet then
		return { ok = false, msg = "Pet inválido" }
	end
	if itemId ~= nil then
		local info = Items.Info[itemId]
		if not info or info.kind ~= "cosmetic" or InventoryLogic.count(data, itemId) < 1 then
			return { ok = false, msg = "Acessório indisponível" }
		end
		-- um acessório equipado conta como "em uso": precisa de unidades livres
		local inUse = 0
		for _, other in pairs(data.pets) do
			if other.accessory == itemId and other.uid ~= uid then
				inUse += 1
			end
		end
		if inUse >= InventoryLogic.count(data, itemId) then
			return { ok = false, msg = "Todas as unidades já estão equipadas" }
		end
	end
	pet.accessory = itemId
	refresh(player, uid)
	return { ok = true }
end

function PetService.applyCatalyst(player: Player, uid: string, itemId: string)
	local data = S.DataService.get(player)
	local pet = data and data.pets[uid]
	local info = Items.Info[itemId]
	if not pet or not info or info.kind ~= "catalyst" then
		return { ok = false, msg = "Pedido inválido" }
	end
	if pet.mutation then
		return { ok = false, msg = "Este pet já possui mutação" }
	end
	if not InventoryLogic.spend(data, { items = { [itemId] = 1 } }) then
		return { ok = false, msg = "Você não tem esse catalisador" }
	end
	pet.mutation = info.mutation
	local _, newMut = InventoryLogic.registerPet(data, pet.species, pet.mutation, os.time())
	-- registerPet também conta +1 na espécie: desfaz a contagem (não é um pet novo)
	data.bestiary.pets[pet.species].n -= 1
	S.QuestService.event(player, { type = "discover_mutation", target = pet.mutation })
	S.QuestService.checkCollection(player)
	S.RewardService.discovery(player, {
		id = S.AnnounceService.newId(), kind = "mutation", species = pet.species, rarity = Pets.Species[pet.species].rarity, mutation = pet.mutation,
		text = string.format("%s %s (catalisador)%s", pet.mutation, Pets.Species[pet.species].name, newMut and " — nova no bestiário!" or ""),
	})
	refresh(player, uid)
	return { ok = true, msg = pet.mutation .. " aplicada!" }
end

-- Experiência de combate para os pets da equipe que participaram.
function PetService.grantXp(player: Player, uids: { [string]: number })
	local data = S.DataService.get(player)
	if not data then
		return
	end
	local leveled = false
	for uid, xp in pairs(uids) do
		local pet = data.pets[uid]
		if pet then
			local ups = PetStats.addXp(pet, xp)
			if ups > 0 then
				leveled = true
				-- o cliente faz a festinha de nível no pet (CreatureMotion)
				for _, st in ipairs(teams[player] or {}) do
					if st.uid == uid and st.model then
						st.model:SetAttribute("LevelUpAt", workspace:GetServerTimeNow())
					end
				end
				S.Push:FireClient(player, "Toast", { text = string.format("%s subiu para o nível %d!", Pets.Species[pet.species].name, pet.level), kind = "level" })
			end
		end
	end
	if leveled then
		-- recalcula atributos sem recriar os modelos
		local _, effects = PetService.synergy(player)
		for _, st in ipairs(teams[player] or {}) do
			local frac = st.hp / math.max(1, st.maxHp)
			st.stats = effectiveStats(st.pet, effects)
			st.maxHp = st.stats.hp
			st.hp = math.max(1, math.floor(st.maxHp * frac))
			PetService.syncAttributes(st)
		end
	end
	S.DataService.markDirty(player)
end

-- Dados derivados para a interface (atributos calculados no servidor).
function PetService.derivedView(player: Player)
	local data = S.DataService.get(player)
	if not data then
		return nil
	end
	local active, effects, sets = PetService.synergy(player)
	local petStats = {}
	for uid, pet in pairs(data.pets) do
		local st = PetStats.compute(pet)
		local _, cd = PetStats.abilityValues(st.ability, pet.abilityRank or 1, effects.cdr)
		petStats[uid] = {
			hp = st.hp, atk = st.atk, def = st.def, aspd = st.aspd, range = st.range, crit = st.crit, power = st.power,
			cooldown = cd, levelCap = PetStats.levelCap(pet), xpNext = require(Shared.Config.Combat).xpToNext(pet.level),
			evolution = PetStats.evolutionCost(pet), canEvolve = (PetStats.canEvolve(pet)),
			abilityCost = (pet.abilityRank or 1) < Abilities.MaxRank and Abilities.UpgradeCost(pet.abilityRank or 1) or nil,
		}
	end
	local synergyIds = {}
	for _, syn in ipairs(active) do
		table.insert(synergyIds, syn.id)
	end
	local setList = {}
	for w in pairs(sets) do
		table.insert(setList, w)
	end
	return { petStats = petStats, synergies = synergyIds, sets = setList }
end

function PetService.start()
	S.DataService.onLoaded(function(player)
		if player.Character then
			PetService.spawnTeam(player)
		end
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			PetService.spawnTeam(player)
		end)
	end)
	S.DataService.onLeaving(function(player)
		despawnTeam(player)
		teams[player] = nil
		if folderFor[player] then
			folderFor[player]:Destroy()
			folderFor[player] = nil
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 / 15 then
			updateMovement(acc)
			acc = 0
		end
	end)
end

return PetService

-- Spawns de inimigos e chefes, laço de IA escalonado, fases de chefes, recompensas e respawn.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Enemies = require(Shared.Config.Enemies)
local Zones = require(Shared.Config.Zones)
local Progression = require(Shared.Config.Progression)
local Log = require(Shared.Util.Log)

local RigBuilder = require(ReplicatedStorage.Shared.Builders.RigBuilder)
local EnemyBrain = require(script.Parent.Parent.Enemy.EnemyBrain)
local Registry = require(script.Parent.Parent.Registry)

local log = Log.new("EnemyService")

local EnemyService = {}

local CombatService
local brains: { [Model]: any } = {}
local enemiesFolder: Folder
local bossesFolder: Folder
local MAX_ENEMIES = 70
local BRAIN_RATE = 1 / 8

local rng = Random.new()

local function groundAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local map = workspace:FindFirstChild("Map")
	params.FilterDescendantsInstances = if map then { map, workspace.Terrain } else { workspace.Terrain }
	local result = workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
	return if result then result.Position else position
end

local function countAlive(): number
	local n = 0
	for _ in brains do
		n += 1
	end
	return n
end

-- Cria um inimigo do tipo `enemyId` na posição. `onDeath` é chamado após a morte.
function EnemyService.Spawn(enemyId: string, position: Vector3, onDeath: (() -> ())?): any?
	local def = Enemies.get(enemyId)
	if not def then
		log:Warn("Inimigo desconhecido:", enemyId)
		return nil
	end
	if not def.boss and countAlive() >= MAX_ENEMIES then
		return nil
	end
	local scale = def.scale or 1
	local model = RigBuilder.build(enemyId, def.look or {}, scale)
	local ground = groundAt(position)
	local height = RigBuilder.HipHeight * scale + model.PrimaryPart.Size.Y / 2 + 0.1
	model:PivotTo(CFrame.new(ground + Vector3.new(0, height, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = if def.boss then bossesFolder else enemiesFolder
	pcall(function()
		model.PrimaryPart:SetNetworkOwner(nil)
	end)

	local derived = {
		maxHealth = def.health,
		maxReiatsu = 200,
		meleeMultiplier = def.damageMultiplier or 1,
		abilityMultiplier = def.damageMultiplier or 1,
		defense = 0,
		walkSpeedBonus = 0,
		cooldownMultiplier = 1,
		abilityCostMultiplier = 0,
		drainMultiplier = 1,
		parryBonus = 0,
		counterBonus = 0,
		guardMultiplier = if def.boss then 2 else 1,
		airDashes = 0,
		dashCooldownMultiplier = 1.5,
		finisherWave = false,
	}
	local actor = CombatService.Register(model, {
		team = "Enemies",
		name = def.name,
		enemyId = enemyId,
		isBoss = def.boss == true,
		level = def.level,
		derived = derived,
		baseWalkSpeed = def.walkSpeed,
	})
	if not actor then
		model:Destroy()
		return nil
	end
	actor.extra.weaponSpec = def.weapon
	actor.extra.element = "Hollow"
	actor.extra.superArmorAttacks = def.superArmorAttacks == true
	if def.weapon then
		Registry.CharacterService.RefreshAppearance(actor)
		CombatService.SetDrawn(actor, true)
	end
	if def.boss then
		model:SetAttribute("Phase", 1)
	end

	local brain = EnemyBrain.new(actor, def, ground)
	brains[model] = brain

	-- Fases de chefe por limiar de vida
	if def.phases then
		actor.humanoid.HealthChanged:Connect(function(health)
			local ratio = health / actor.humanoid.MaxHealth
			for index = #def.phases, 2, -1 do
				if ratio <= def.phases[index].threshold and brain.phase < index then
					local phase = brain:EnterPhase(index)
					if phase and phase.summon then
						for i = 1, phase.summon.count do
							local angle = (i / phase.summon.count) * math.pi * 2
							local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 14
							EnemyService.Spawn(phase.summon.id, actor.root.Position + offset)
						end
					end
					break
				end
			end
		end)
	end

	-- Boneco de treino: regenera e mostra dano
	if def.regenerate then
		actor.humanoid.HealthChanged:Connect(function(health)
			if health < actor.humanoid.MaxHealth * 0.2 then
				task.delay(0.5, function()
					if actor.humanoid.Parent then
						actor.humanoid.Health = actor.humanoid.MaxHealth
					end
				end)
			end
		end)
	end

	actor.extra.onDeath = onDeath
	return actor
end

local function rewardPlayers(actor, def)
	local total = 0
	for _, amount in actor.damageBy do
		total += amount
	end
	for player, amount in actor.damageBy do
		if player.Parent and amount > 0 then
			local share = amount / math.max(1, actor.humanoid.MaxHealth)
			if not def.boss or share >= 0.05 then
				local profile = Registry.DataService.Get(player)
				if profile then
					local xp = Progression.scaledXp(def.xp, def.level, profile.level)
					Registry.ProgressionService.AddXp(player, xp, def.name)
					if def.loot then
						Registry.InventoryService.GrantLoot(player, def.loot)
					end
					profile.record.kills += 1
					if def.boss then
						profile.record.bossKills += 1
					end
				end
				Registry.QuestService.Event(player, { type = "Kill", enemy = actor.enemyId, boss = def.boss == true })
			end
		end
	end
	if total > 0 then
		log:Debug(def.name, "derrotado por", total, "de dano somado")
	end
end

local function onActorDied(actor)
	local brain = brains[actor.model]
	if not brain then
		return
	end
	brains[actor.model] = nil
	local def = brain.def
	if def.xp > 0 then
		rewardPlayers(actor, def)
	end
	local model = actor.model
	-- O cliente faz o efeito de dissolução; removemos depois.
	task.delay(2.2, function()
		model:Destroy()
	end)
	if actor.extra.onDeath then
		actor.extra.onDeath()
	end
end

-- Mantém `count` inimigos vivos em cada spawner.
local function runSpawner(spawner)
	local zone = Zones.List[spawner.zone]
	local center = zone.center + spawner.position
	local alive = 0
	local function spawnOne(index: number)
		local offset
		if spawner.line then
			offset = Vector3.new((index - (spawner.count + 1) / 2) * 10, 0, 0)
		else
			local angle = rng:NextNumber(0, math.pi * 2)
			offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(0, spawner.radius)
		end
		local actor = EnemyService.Spawn(spawner.enemy, center + offset, function()
			alive -= 1
			task.delay(spawner.respawn, function()
				spawnOne(index)
			end)
		end)
		if actor then
			alive += 1
		else
			task.delay(spawner.respawn, function()
				spawnOne(index)
			end)
		end
	end
	for i = 1, spawner.count do
		spawnOne(i)
	end
end

local function runBoss(entry)
	local def = Enemies.get(entry.enemy)
	local position = Zones.worldPosition(entry.zone, entry.position)
	local function spawnBoss()
		EnemyService.Spawn(entry.enemy, position, function()
			task.delay(def.respawn or 120, spawnBoss)
		end)
	end
	spawnBoss()
end

function EnemyService.Init()
	CombatService = Registry.CombatService
	enemiesFolder = workspace:FindFirstChild("Enemies") or Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = workspace
	bossesFolder = workspace:FindFirstChild("Bosses") or Instance.new("Folder")
	bossesFolder.Name = "Bosses"
	bossesFolder.Parent = workspace
end

function EnemyService.Start()
	CombatService.ActorDied:Connect(onActorDied)
	CombatService.AttackStarted:Connect(function(attacker, spec)
		if not attacker.player then
			return
		end
		for _, brain in brains do
			if brain.target == attacker or brain.target == nil then
				brain:OnThreat(attacker, spec)
			end
		end
	end)

	for _, spawner in Zones.Spawners do
		task.spawn(runSpawner, spawner)
	end
	for _, entry in Zones.Bosses do
		task.spawn(runBoss, entry)
	end

	-- IA escalonada: cada cérebro roda ~8x/s, distribuídos entre frames.
	-- Inimigos sem jogadores por perto (300 studs) dormem.
	local accumulator = 0
	local list: { any } = {}
	local cursor = 1
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if cursor == 1 then
			table.clear(list)
			for _, brain in brains do
				table.insert(list, brain)
			end
		end
		local perFrame = math.max(1, math.ceil(#list * dt / BRAIN_RATE))
		for _ = 1, perFrame do
			local brain = list[cursor]
			if not brain then
				cursor = 1
				break
			end
			cursor += 1
			local root = brain.actor.root
			local awake = false
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local pr = character and character.PrimaryPart
				if pr and (pr.Position - root.Position).Magnitude < 300 then
					awake = true
					break
				end
			end
			if awake and brains[brain.actor.model] then
				local ok, err = pcall(brain.Step, brain)
				if not ok then
					log:Error("IA de", brain.def.name, err)
				end
			end
		end
		if cursor > #list then
			cursor = 1
		end
	end)
end

return EnemyService

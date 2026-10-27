-- Personagens dos jogadores: escolha de facção, spawn/respawn, atributos derivados,
-- arma/traje por forma, máscara e estado de espada desembainhada.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Combat = require(Shared.Config.Combat)
local Factions = require(Shared.Config.Factions)
local Powers = require(Shared.Config.Powers)
local Progression = require(Shared.Config.Progression)
local SkillTrees = require(Shared.Config.SkillTrees)
local Items = require(Shared.Config.Items)
local Zones = require(Shared.Config.Zones)
local Elements = require(Shared.Config.Elements)
local Stats = require(Shared.Logic.Stats)
local Loadout = require(Shared.Logic.Loadout)
local Log = require(Shared.Util.Log)

local Builders = Shared.Builders
local WeaponBuilder = require(Builders.WeaponBuilder)
local OutfitBuilder = require(Builders.OutfitBuilder)
local PlayerLook = require(Builders.PlayerLook)

local Registry = require(script.Parent.Parent.Registry)

local log = Log.new("CharacterService")

local CharacterService = {}

local CombatService

function CharacterService.ComputeDerived(profile: any)
	local power = profile.power and Powers.get(profile.power)
	local rarity = power and Powers.Rarities[power.rarity].multiplier or 1
	local derived = Stats.compute(profile, Progression, SkillTrees.get(profile.faction), Items.List, rarity)
	-- cada estágio da classe (Humano → Shinigami, Hollow → Arrancar) deixa o personagem mais forte
	local stage = Factions.stage(profile.faction, profile.level)
	local boost = stage and stage.power or 1
	derived.maxHealth = math.floor(derived.maxHealth * boost)
	derived.meleeMultiplier *= boost
	derived.abilityMultiplier *= boost
	return derived
end

function CharacterService.RefreshStats(player: Player)
	local profile = Registry.DataService.Get(player)
	local actor = CombatService.GetByPlayer(player)
	if not profile or not actor then
		return
	end
	actor.level = profile.level
	actor.model:SetAttribute("Level", profile.level)
	-- evoluiu de estágio (ex.: Humano → Shinigami, Menos → Adjuchas): troca traje, arma e habilidades
	local stage = Factions.stage(actor.faction, profile.level)
	local stageId = stage and stage.id
	if stageId and actor.model:GetAttribute("Stage") ~= stageId then
		local previous = actor.model:GetAttribute("Stage")
		actor.model:SetAttribute("Stage", stageId)
		if previous ~= nil then
			CharacterService.RefreshAppearance(actor)
			Registry.UIService.Notify(player, string.upper(stage.title or stage.name) .. "!", "awaken")
			-- mesmo espetáculo de uma liberação (pilar de energia, kanji no mundo, título na tela)
			CombatService.Broadcast("TransformStart", {
				actor = actor.model,
				form = "Tier1",
				formKanji = stage.kanji,
				formName = stage.name,
				element = Factions.get(actor.faction) and Factions.get(actor.faction).element or "Reiatsu",
				channel = 1.5,
			}, actor.root.Position)
		end
	end
	CombatService.SetDerived(actor, CharacterService.ComputeDerived(profile))
end

local function weaponTint(actor): Color3?
	if not actor.player then
		return nil
	end
	local profile = Registry.DataService.Get(actor.player)
	local uid = profile and profile.equipped.Weapon
	if not uid then
		return nil
	end
	for _, entry in profile.inventory.items do
		if entry.uid == uid then
			local def = Items.List[entry.id]
			return def and def.tint or nil
		end
	end
	return nil
end

-- Reconstrói arma e traje conforme facção/forma.
function CharacterService.RefreshAppearance(actor)
	local character = actor.model
	for _, child in character:GetChildren() do
		if child.Name == "Weapon" and child:IsA("Model") then
			child:Destroy()
		end
	end
	local sheath = character:FindFirstChild("Sheath")
	if sheath then
		sheath:Destroy()
	end

	local spec = actor.extra.weaponSpec
	local element = actor.extra.element
	local faction = Factions.get(actor.faction)
	if actor.player and faction then
		spec = Loadout.weapon(Factions, Powers.List, actor.faction, actor.power, actor.form, actor.level)
		local power = actor.power and Powers.get(actor.power)
		element = if power and actor.form ~= "Base" then power.element else faction.element
	end
	if spec then
		local tinted = spec
		local tint = weaponTint(actor)
		if tint and actor.form == "Base" then
			tinted = table.clone(spec)
			tinted.blade = tint
			tinted.glow = true
		end
		local model = WeaponBuilder.buildModel(tinted, element)
		local attached = WeaponBuilder.attach(character, model, "RightHand")
		if attached then
			WeaponBuilder.setDrawn(attached, actor.drawn or actor.player == nil)
			local stage = actor.player and Factions.stage(actor.faction, actor.level)
			-- o humano carrega a espada de madeira sem bainha
			if attached:GetAttribute("Sheathable") and not (stage and stage.id == "Human") then
				WeaponBuilder.buildSheath(character, spec.length or 4)
			end
		end
		if spec.dual or spec.style == "Claws" or spec.style == "Gauntlet" then
			local left = WeaponBuilder.buildModel(tinted, element)
			left.Name = "Weapon"
			WeaponBuilder.attach(character, left, "LeftHand")
		end
	end

	if actor.player and faction then
		local power = actor.power and Powers.get(actor.power)
		local coat = nil
		if actor.form == "Tier2" and power then
			coat = power.tier2.coat
		end
		local stage = Factions.stage(actor.faction, actor.level)
		local uniform = OutfitBuilder.applyUniform(character, actor.faction, faction.outfit, stage and stage.outfit)
		OutfitBuilder.apply(character, {
			uniform = uniform,
			trim = if actor.form ~= "Base" and power then Elements[power.element].primary else faction.outfit.trim,
			robe = faction.outfit.robe,
			cape = faction.outfit.cape,
			coat = coat,
			hollowHole = faction.outfit.hollowHole,
			bone = actor.faction == "Hollow" and actor.form ~= "Base",
		})
	end
end

function CharacterService.SetWeaponDrawn(actor, drawn: boolean)
	for _, child in actor.model:GetChildren() do
		if child.Name == "Weapon" and child:IsA("Model") then
			WeaponBuilder.setDrawn(child, drawn)
		end
	end
end

function CharacterService.SetMaskVisual(actor, enabled: boolean)
	OutfitBuilder.setMask(actor.model, enabled)
end

function CharacterService.SpawnCFrame(profile: any): CFrame
	local point = Zones.TravelPoints[profile.lastTravel or "KarakuraPlaza"] or Zones.TravelPoints.KarakuraPlaza
	local position = Zones.worldPosition(point.zone, point.position)
	return CFrame.new(position + Vector3.new(math.random(-4, 4), 3, math.random(-4, 4)))
end

-- Avatar R6 (configuração do jogo "R6" ou "escolha do jogador"): as animações são todas de R15,
-- então troca o personagem por um R15 montado com a mesma aparência (roupas, cabelo, rosto).
local function replaceWithR15(player: Player, character: Model, humanoid: Humanoid): boolean
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(humanoid:GetAppliedDescription(), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		log:Warn("Não deu para montar o R15 de", player.Name, model)
		return false
	end
	model.Name = player.Name
	local defaultAnimate = model:FindFirstChild("Animate")
	if defaultAnimate then
		defaultAnimate:Destroy()
	end
	local starter = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts")
	if starter then
		for _, item in starter:GetChildren() do
			item:Clone().Parent = model
		end
	end
	model:PivotTo(character:GetPivot())
	player.Character = model
	model.Parent = workspace
	character:Destroy()
	return true
end

local function setupCharacter(player: Player, character: Model)
	local profile = Registry.DataService.Get(player)
	if not profile or not profile.faction then
		return
	end
	-- poder que não é da classe (perfil migrado de Quincy/Fullbringer): volta ao inicial dela
	local current = profile.power and Powers.get(profile.power)
	if not current or current.faction ~= profile.faction then
		local starter = Powers.Starter[profile.faction]
		if starter then
			profile.power = starter
			profile.gacha.owned[starter] = true
		end
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		log:Warn("Personagem sem Humanoid/HRP:", player.Name)
		return
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		log:Warn("O avatar de", player.Name, "é R6: trocando por R15 (Game Settings > Avatar > R15 evita isso).")
		if replaceWithR15(player, character, humanoid) then
			return -- o novo personagem dispara CharacterAdded e passa por aqui de novo
		end
	end
	-- Corpo nas proporções do R15 padrão (as animações são compiladas e verificadas nessas medidas:
	-- pés no chão, alcance dos braços, empunhadura). Mantém rosto, cabelo, roupas e acessórios do
	-- avatar; troca só as partes do corpo (Rthro/escala) pelas padrão.
	pcall(function()
		local description = humanoid:GetAppliedDescription()
		description.HeightScale = 1
		description.WidthScale = 1
		description.DepthScale = 1
		description.HeadScale = 1
		description.Head = 0 -- cabeça clássica: o rosto de anime do jogo é montado sobre ela
		description.BodyTypeScale = 0
		description.ProportionScale = 0
		description.Torso = 0
		description.LeftArm = 0
		description.RightArm = 0
		description.LeftLeg = 0
		description.RightLeg = 0
		humanoid:ApplyDescription(description)
	end)
	-- ApplyDescription pode criar os valores de animação do avatar dentro do Animate do projeto:
	-- a animação é toda do AnimController, então o Animate fica vazio
	local animate = character:FindFirstChild("Animate")
	if animate and animate:GetAttribute("OwnLocomotion") then
		for _, child in animate:GetChildren() do
			child:Destroy()
		end
	end
	-- Aguarda o rig montar (mãos e torso) antes de prender armas.
	character:WaitForChild("RightHand", 5)
	character:WaitForChild("LowerTorso", 5)
	-- visual de anime: rosto e cabelo do jogo (o uniforme da facção vem no RefreshAppearance)
	pcall(PlayerLook.apply, character, player.UserId, profile.look)

	humanoid.BreakJointsOnDeath = false
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 8.5
	humanoid.WalkSpeed = Combat.BaseWalkSpeed

	local actor = CombatService.Register(character, {
		player = player,
		team = "Players",
		name = player.DisplayName,
		faction = profile.faction,
		power = profile.power,
		level = profile.level,
		derived = CharacterService.ComputeDerived(profile),
		baseWalkSpeed = Combat.BaseWalkSpeed,
	})
	if not actor then
		return
	end
	local stage = Factions.stage(profile.faction, profile.level)
	character:SetAttribute("Stage", stage and stage.id or nil)
	CharacterService.RefreshAppearance(actor)
	character:PivotTo(CharacterService.SpawnCFrame(profile))

	humanoid.Died:Connect(function()
		profile.record.deaths += 1
		task.delay(Combat.RespawnTime, function()
			if player.Parent and player.Character == character then
				CharacterService.Spawn(player)
			end
		end)
	end)
end

function CharacterService.Spawn(player: Player)
	local profile = Registry.DataService.Get(player)
	if not profile or not profile.faction then
		return
	end
	local ok, err = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		log:Warn("LoadCharacter falhou para", player.Name, err)
	end
end

-- Pedido: escolher facção (somente uma vez; trocar exige reset explícito).
local function chooseFaction(player: Player, payload: any): (boolean, any)
	local profile = Registry.DataService.Get(player)
	if not profile then
		return false, "Perfil não carregado"
	end
	local factionId = type(payload) == "table" and payload.faction
	if type(factionId) ~= "string" or not Factions.get(factionId) then
		return false, "Facção inválida"
	end
	if profile.faction and profile.faction ~= factionId then
		return false, "Você já pertence a uma facção"
	end
	if not profile.faction then
		profile.faction = factionId
		local starter = Powers.Starter[factionId]
		profile.power = starter
		profile.gacha.owned[starter] = true
		Registry.QuestService.StartStory(player, "Awakening")
		Registry.DataService.Sync(player)
		log:Info(player.Name, "escolheu", factionId)
	end
	if not player.Character then
		CharacterService.Spawn(player)
	end
	return true, nil
end

-- Pedido: equipar um poder já obtido (fora de combate).
local function equipPower(player: Player, payload: any): (boolean, any)
	local profile = Registry.DataService.Get(player)
	local powerId = type(payload) == "table" and payload.power
	if not profile or type(powerId) ~= "string" then
		return false, "Pedido inválido"
	end
	local power = Powers.get(powerId)
	if not power or power.faction ~= profile.faction or not profile.gacha.owned[powerId] then
		return false, "Poder indisponível"
	end
	local actor = CombatService.GetByPlayer(player)
	if actor then
		if CombatService.now() - actor.lastCombatTime < 8 then
			return false, "Saia de combate para trocar de poder"
		end
		Registry.TransformationService.Revert(actor, "manual")
	end
	profile.power = powerId
	if actor then
		actor.power = powerId
		actor.model:SetAttribute("Power", powerId)
		CharacterService.RefreshStats(player)
		CharacterService.RefreshAppearance(actor)
	end
	Registry.DataService.Sync(player)
	return true, nil
end

local VALID_SETTINGS = {
	shake = "number",
	music = "number",
	vfx = { Low = true, Medium = true, High = true },
	cinematics = { Full = true, Off = true },
	autoFace = "boolean",
}

local function saveSettings(player: Player, payload: any): (boolean, any)
	local profile = Registry.DataService.Get(player)
	if not profile or type(payload) ~= "table" then
		return false, "Pedido inválido"
	end
	for key, value in payload do
		local rule = VALID_SETTINGS[key]
		if rule == "number" and type(value) == "number" then
			profile.settings[key] = math.clamp(value, 0, 2)
		elseif rule == "boolean" and type(value) == "boolean" then
			profile.settings[key] = value
		elseif type(rule) == "table" and type(value) == "string" and rule[value] then
			profile.settings[key] = value
		end
	end
	Registry.DataService.Sync(player)
	return true, nil
end

function CharacterService.Init()
	CombatService = Registry.CombatService
	Registry.UIService.Register("SaveSettings", saveSettings)
	Registry.UIService.Register("ChooseFaction", chooseFaction)
	Registry.UIService.Register("EquipPower", equipPower)
end

function CharacterService.Start()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			setupCharacter(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			setupCharacter(player, character)
		end)
	end
	Registry.DataService.ProfileLoaded:Connect(function(player, profile)
		if profile.faction then
			CharacterService.Spawn(player)
		end
		-- Sem facção: o cliente mostra a tela de seleção e chama ChooseFaction.
	end)
	if RunService:IsStudio() then
		log:Debug("CharacterService pronto (Studio)")
	end
end

return CharacterService

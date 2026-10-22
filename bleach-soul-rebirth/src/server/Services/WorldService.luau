-- Mundo: constrói regiões, portais, pontos de viagem e NPCs; rastreia a região de cada jogador.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Config.Zones)
local NPCs = require(Shared.Config.NPCs)
local Log = require(Shared.Util.Log)

local World = script.Parent.Parent.World
local Build = require(World.Build)
local Regions = require(World.Regions)
local RigBuilder = require(ReplicatedStorage.Shared.Builders.RigBuilder)
local OutfitBuilder = require(ReplicatedStorage.Shared.Builders.OutfitBuilder)
local Registry = require(script.Parent.Parent.Registry)

local log = Log.new("WorldService")

local WorldService = {}

local TRAVEL_COOLDOWN = 4
local lastTravel: { [Player]: number } = {}
local playerZone: { [Player]: string } = {}

local function travelPointCFrame(pointId: string): CFrame?
	local point = Zones.TravelPoints[pointId]
	if not point then
		return nil
	end
	return CFrame.new(Zones.worldPosition(point.zone, point.position) + Vector3.new(0, 3, 0))
end

function WorldService.Teleport(player: Player, pointId: string): (boolean, string?)
	local character = player.Character
	local cframe = travelPointCFrame(pointId)
	if not character or not cframe then
		return false, "Destino inválido"
	end
	local actor = Registry.CombatService.GetByPlayer(player)
	if actor and Registry.CombatService.IsStunned(actor) then
		return false, "Você está atordoado"
	end
	local now = os.clock()
	if now - (lastTravel[player] or 0) < TRAVEL_COOLDOWN then
		return false, "Aguarde para viajar novamente"
	end
	lastTravel[player] = now
	local profile = Registry.DataService.Get(player)
	if profile then
		profile.lastTravel = pointId
		profile.discovered[pointId] = true
		Registry.DataService.Sync(player)
	end
	Registry.CombatService.Broadcast(
		"Travel",
		{ actor = character, from = character:GetPivot().Position },
		character:GetPivot().Position
	)
	character:PivotTo(cframe * CFrame.new(math.random(-3, 3), 0, math.random(-3, 3)))
	return true, nil
end

local function requestTravel(player: Player, payload: any): (boolean, any)
	local pointId = type(payload) == "table" and payload.point
	local profile = Registry.DataService.Get(player)
	if not profile or type(pointId) ~= "string" or not Zones.TravelPoints[pointId] then
		return false, "Destino inválido"
	end
	if not profile.discovered[pointId] then
		return false, "Ponto de viagem ainda não descoberto"
	end
	local zone = Zones.List[Zones.TravelPoints[pointId].zone]
	if profile.level < (zone.minLevel or 1) then
		return false, "Requer nível " .. zone.minLevel
	end
	local actor = Registry.CombatService.GetByPlayer(player)
	if actor and Registry.CombatService.now() - actor.lastCombatTime < 6 then
		return false, "Não é possível viajar em combate"
	end
	return WorldService.Teleport(player, pointId)
end

-- Portal físico com rótulo e área de toque
local function buildPortal(parent: Instance, portal)
	local zone = Zones.List[portal.zone]
	local base = zone.center + portal.position
	local model = Instance.new("Model")
	model.Name = "Portal_" .. portal.id
	local color = portal.color
	if portal.id:find("Senkaimon") then
		for _, x in { -7, 7 } do
			Build.part(
				model,
				Vector3.new(2, 18, 2),
				CFrame.new(base + Vector3.new(x, 9, 0)),
				Color3.fromRGB(110, 60, 45),
				Enum.Material.Wood,
				"Pillar"
			)
		end
		Build.part(
			model,
			Vector3.new(20, 2, 3),
			CFrame.new(base + Vector3.new(0, 18, 0)),
			Color3.fromRGB(45, 48, 60),
			Enum.Material.Slate,
			"Lintel"
		)
	end
	local disc = Build.cylinder(
		model,
		0.6,
		12,
		CFrame.new(base + Vector3.new(0, 8, 0)) * CFrame.Angles(0, math.rad(90), 0),
		color,
		Enum.Material.Neon
	)
	disc.Name = "Gate"
	disc.Transparency = 0.25
	disc.CanCollide = false
	Build.light(disc, color, 26, 2)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Rate = 14
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 1
	emitter.Parent = disc

	local trigger = Build.part(
		model,
		Vector3.new(10, 14, 6),
		CFrame.new(base + Vector3.new(0, 7, 0)),
		color,
		Enum.Material.SmoothPlastic,
		"Trigger"
	)
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger.CanQuery = false

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 50)
	billboard.StudsOffset = Vector3.new(0, 11, 0)
	billboard.MaxDistance = 120
	billboard.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = portal.label .. (if portal.level then "  (Nv. " .. portal.level .. ")" else "")
	label.Parent = billboard
	billboard.Parent = disc

	local debounce: { [Player]: number } = {}
	trigger.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		if now - (debounce[player] or 0) < 2 then
			return
		end
		debounce[player] = now
		local profile = Registry.DataService.Get(player)
		if not profile then
			return
		end
		if portal.level and profile.level < portal.level then
			Registry.UIService.Notify(player, portal.label .. " exige nível " .. portal.level .. ".", "warn")
			return
		end
		local ok, err = WorldService.Teleport(player, portal.to)
		if not ok and err then
			Registry.UIService.Notify(player, err, "warn")
		end
	end)
	model.Parent = parent
end

local function buildTravelPoint(parent: Instance, id: string, point)
	local position = Zones.worldPosition(point.zone, point.position)
	local model = Instance.new("Model")
	model.Name = "TravelPoint_" .. id
	Build.cylinder(
		model,
		1,
		8,
		CFrame.new(position + Vector3.new(0, -2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(70, 70, 80),
		Enum.Material.Slate
	)
	local pillar = Build.part(
		model,
		Vector3.new(1.2, 7, 1.2),
		CFrame.new(position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Color3.fromRGB(150, 210, 255),
		Enum.Material.Neon,
		"Beacon"
	)
	Build.light(pillar, Color3.fromRGB(150, 210, 255), 16, 1)
	model:SetAttribute("TravelPoint", id)
	model.Parent = parent
end

local function buildNpc(parent: Instance, npcId: string, npc)
	local look = {
		skin = npc.look.skin,
		outfit = npc.look.robe,
		pants = npc.look.robe,
		hair = npc.look.hair,
		mask = npc.look.mask,
		partialMask = npc.look.mask,
	}
	local model = RigBuilder.build(npcId, look, 1)
	local position = Zones.worldPosition(npc.zone, npc.position)
	local center = Zones.List[npc.zone].center
	local faceDir = (center - position) * Vector3.new(1, 0, 1)
	local target = if faceDir.Magnitude > 1 then position + faceDir else position + Vector3.new(0, 0, -1)
	model:PivotTo(
		CFrame.lookAt(
			position + Vector3.new(0, RigBuilder.HipHeight + 1.1, 0),
			target + Vector3.new(0, RigBuilder.HipHeight + 1.1, 0)
		)
	)
	model.PrimaryPart.Anchored = true
	OutfitBuilder.apply(model, { trim = npc.look.haori, robe = npc.look.haori, cape = false })
	model:SetAttribute("NPC", true)
	model:SetAttribute("DisplayName", npc.name)
	model:SetAttribute("Title", npc.title)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = 1e6
		humanoid.Health = 1e6
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Conversar"
	prompt.ObjectText = npc.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		Registry.QuestService.OpenDialogue(player, npcId)
	end)
	model.Parent = parent
end

-- Rastreamento de região + descoberta de pontos de viagem (1 Hz).
local function trackPlayers()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local profile = Registry.DataService.Get(player)
			if root and profile and profile.faction then
				local zone = Zones.zoneAt(root.Position)
				if zone and playerZone[player] ~= zone then
					playerZone[player] = zone
					player:SetAttribute("Zone", zone)
					Registry.QuestService.Event(player, { type = "Reach", zone = zone })
				end
				for id, point in Zones.TravelPoints do
					if not profile.discovered[id] then
						local p = Zones.worldPosition(point.zone, point.position)
						if (p - root.Position).Magnitude < 25 then
							profile.discovered[id] = true
							Registry.UIService.Notify(player, "Ponto de viagem descoberto: " .. point.name, "discover")
							Registry.DataService.Sync(player)
						end
					end
				end
			end
		end
	end
end

function WorldService.Init()
	local started = os.clock()
	local map = workspace:FindFirstChild("Map") or Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	for _, zoneId in Zones.Order do
		local folder = Build.folder(map, zoneId)
		local builder = Regions[zoneId]
		local ok, err = pcall(builder, folder)
		if not ok then
			log:Error("Falha ao construir", zoneId, err)
		end
	end
	local portals = Build.folder(map, "Portals")
	for _, portal in Zones.Portals do
		buildPortal(portals, portal)
	end
	local travel = Build.folder(map, "TravelPoints")
	for id, point in Zones.TravelPoints do
		buildTravelPoint(travel, id, point)
	end
	local spawnFolder = Build.folder(workspace, "SpawnPoints")
	for id, point in Zones.TravelPoints do
		local marker = Instance.new("Part")
		marker.Name = id
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.Transparency = 1
		marker.Size = Vector3.one
		marker.Position = Zones.worldPosition(point.zone, point.position)
		marker.Parent = spawnFolder
	end
	local npcFolder = workspace:FindFirstChild("NPCs") or Build.folder(workspace, "NPCs")
	for npcId, npc in NPCs do
		buildNpc(npcFolder, npcId, npc)
	end
	log:Info(string.format("Mundo construído em %.2fs", os.clock() - started))
	Registry.UIService.Register("Travel", requestTravel)
end

function WorldService.Start()
	task.spawn(trackPlayers)
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
		playerZone[player] = nil
	end)
end

return WorldService

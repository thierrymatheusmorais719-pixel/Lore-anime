-- Combate local: responde na hora (anima e prevê), envia a intenção ao servidor e
-- reconcilia com o que ele confirmar. Inclui buffer de comandos, mira assistida, dash com
-- i-frames, pulo duplo (shunpo aéreo), knockback/flutuar/teleporte vindos do servidor.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Combat = require(Shared.Config.Combat)
local Abilities = require(Shared.Config.Abilities)
local Factions = require(Shared.Config.Factions)
local Powers = require(Shared.Config.Powers)
local CombatRules = require(Shared.Logic.CombatRules)
local Loadout = require(Shared.Logic.Loadout)
local Physics = require(Shared.Physics)
local Poses = require(Shared.Anim.Poses)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local Controllers = script.Parent
local InputController = require(Controllers.InputController)
local AnimController = require(Controllers.AnimController)
local VFX = require(Controllers.VFXController)
local SoundController = require(Controllers.SoundController)
local CameraController = require(Controllers.CameraController)

local CombatController = {}
CombatController.CooldownsChanged = Signal.new()

local player = Players.LocalPlayer
local inputRemote: RemoteEvent

local busyUntil = 0
local buffered: { action: string, time: number }? = nil
local combo = { index = 0, lastEnd = 0, aerial = 0, aerialLastEnd = 0 }
local cooldowns: { [string]: number } = {} -- chave → os.clock() de quando fica pronto
local predicted: { [string]: number } = {} -- anim → os.clock() em que foi prevista
local airDashesUsed = 0
local airStepsUsed = 0
local counterUntil = 0
local blocking = false

local function character(): (Model?, Humanoid?, BasePart?)
	local c = player.Character
	if not c then
		return nil, nil, nil
	end
	return c, c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function alive(): boolean
	local _, humanoid = character()
	return humanoid ~= nil and humanoid.Health > 0
end

local function stunned(): boolean
	local c = player.Character
	return c ~= nil and c:GetAttribute("Stunned") == true
end

function CombatController.CooldownRemaining(key: string): (number, number)
	local entry = cooldowns[key]
	if not entry then
		return 0, 1
	end
	return math.max(0, entry - os.clock()), cooldowns[key .. "#total"] or 1
end

local function setLocalCooldown(key: string, duration: number)
	cooldowns[key] = os.clock() + duration
	cooldowns[key .. "#total"] = duration
	CombatController.CooldownsChanged:Fire()
end

function CombatController.WasPredicted(anim: string): boolean
	local t = predicted[anim]
	return t ~= nil and os.clock() - t < 0.5
end

function CombatController.OnParrySuccess()
	counterUntil = os.clock() + Combat.CounterWindow - 0.1
end

-- Slots atuais (Z/X/C/V) a partir dos atributos replicados.
function CombatController.Slots(): { [string]: string }
	local c = player.Character
	if not c then
		return {}
	end
	return Loadout.resolve(
		Factions,
		Powers.List,
		c:GetAttribute("Faction"),
		c:GetAttribute("Power"),
		c:GetAttribute("Form"),
		c:GetAttribute("Mask")
	) :: any
end

-- ============================================================
-- Mira
-- ============================================================
local function hostileModels(): { Model }
	local list = {}
	for _, folderName in { "Enemies", "Bosses" } do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, m in folder:GetChildren() do
				if m:IsA("Model") then
					table.insert(list, m)
				end
			end
		end
	end
	if player:GetAttribute("Zone") == "Training" then
		for _, p in Players:GetPlayers() do
			if p ~= player and p.Character then
				table.insert(list, p.Character)
			end
		end
	end
	return list
end

-- Alvo mais próximo à frente (câmera) para mira assistida.
function CombatController.FindTarget(range: number?): Model?
	local _, _, root = character()
	if not root then
		return nil
	end
	local camera = workspace.CurrentCamera
	local look = Physics.flat(camera.CFrame.LookVector)
	local best, bestScore = nil, math.huge
	local cosLimit = math.cos(math.rad(Combat.AutoFaceAngle))
	for _, model in hostileModels() do
		local hum = model:FindFirstChildOfClass("Humanoid")
		local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and r and hum.Health > 0 then
			local offset = r.Position - root.Position
			local distance = offset.Magnitude
			if distance < (range or Combat.AutoFaceRange) then
				local dot = Physics.flat(offset):Dot(look)
				if dot > cosLimit or distance < 6 then
					local score = distance * (2 - dot)
					if score < bestScore then
						best, bestScore = model, score
					end
				end
			end
		end
	end
	return best
end

local function attackDirection(): Vector3
	local _, _, root = character()
	if not root then
		return Vector3.new(0, 0, -1)
	end
	local target = CombatController.FindTarget()
	local dir
	if target and target.PrimaryPart then
		dir = Physics.flat(target.PrimaryPart.Position - root.Position)
	else
		local _, humanoid = character()
		local move = humanoid and humanoid.MoveDirection or Vector3.zero
		if move.Magnitude > 0.1 then
			dir = Physics.flat(move)
		else
			dir = Physics.flat(workspace.CurrentCamera.CFrame.LookVector)
		end
	end
	-- Vira o personagem imediatamente (o dono controla a física do próprio personagem)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	return dir
end

-- Ponto mirado no mundo (mouse no PC; centro da tela no celular/controle).
local function aimPoint(range: number): Vector3?
	local camera = workspace.CurrentCamera
	local ray
	if InputController.Mode() == "Keyboard" then
		local mouse = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	else
		local target = CombatController.FindTarget(range)
		if target and target.PrimaryPart then
			return target.PrimaryPart.Position
		end
		local size = camera.ViewportSize
		ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("ClientVFX") }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	return if result then result.Position else ray.Origin + ray.Direction * range
end

-- ============================================================
-- Ações
-- ============================================================
local function isAirborne(humanoid: Humanoid): boolean
	return humanoid.FloorMaterial == Enum.Material.Air
end

local function slashFx(model: Model, spec, animName: string)
	local element = VFX.ElementOf(model)
	local color = VFX.Color(element)
	VFX.WeaponTrail(model, color, spec.windup + 0.15)
	task.delay(spec.windup * 0.6, function()
		SoundController.Play(spec.sound or "Slash", model.PrimaryPart)
	end)
	task.delay(spec.windup, function()
		local root = model.PrimaryPart
		if not root then
			return
		end
		local vertical = animName == "Slash3"
			or animName == "Slash5"
			or animName == "Air3"
			or animName == "Air4"
			or animName == "Uppercut"
		local frame = root.CFrame * CFrame.new(0, 0.8, -1.5)
		if vertical then
			frame *= CFrame.Angles(0, 0, math.rad(90))
		end
		local reverse = animName == "Slash2" or animName == "Air2" or animName == "Counter"
		VFX.SlashArc(frame, color, if spec.heavy then 7 else 5.5, if spec.heavy then 0.6 else 0.35, 0.22, reverse)
	end)
end
CombatController.SlashFx = slashFx

local function performAttack(kind: string): boolean
	local model, humanoid, root = character()
	if not model or not humanoid or not root then
		return false
	end
	local now = os.clock()
	local spec, animName
	if kind == "Light" then
		if now < counterUntil then
			spec = Combat.Counter
			counterUntil = 0
		elseif isAirborne(humanoid) then
			local index = CombatRules.nextComboIndex(
				combo.aerial,
				combo.aerialLastEnd,
				now,
				#Combat.Aerial,
				Combat.ComboResetTime
			)
			spec = Combat.Aerial[index]
			combo.aerial = index
			combo.aerialLastEnd = now + spec.duration
			Physics.hover(root, 0.35)
		else
			local index =
				CombatRules.nextComboIndex(combo.index, combo.lastEnd, now, #Combat.Light, Combat.ComboResetTime)
			spec = Combat.Light[index]
			combo.index = index
			combo.lastEnd = now + spec.duration
		end
	elseif kind == "Heavy" then
		if CombatController.CooldownRemaining("Heavy") > 0 then
			return false
		end
		spec = Combat.Heavy
	elseif kind == "Launcher" then
		if CombatController.CooldownRemaining("Launcher") > 0 then
			return false
		end
		spec = Combat.Launcher
	end
	if not spec then
		return false
	end
	animName = spec.anim
	local direction = attackDirection()
	busyUntil = now + spec.duration + (if spec.finisher then Combat.ComboEndLag * 0.5 else 0)
	-- Execução: o servidor decide; não prevemos a animação do pesado nesse caso
	local target = if kind == "Heavy" then CombatController.FindTarget(Combat.Execution.range) else nil
	local maybeExecution = target ~= nil and target:GetAttribute("Stunned") == true
	if not maybeExecution then
		predicted[animName] = now
		AnimController.Play(model, animName)
		slashFx(model, spec, animName)
	end
	if spec.lunge and not isAirborne(humanoid) then
		Physics.impulse(root, direction * spec.lunge * 4.2, 0.1)
	end
	inputRemote:FireServer(kind, { direction = direction })
	return true
end

local function performDash(): boolean
	local model, humanoid, root = character()
	if not model or not humanoid or not root then
		return false
	end
	if CombatController.CooldownRemaining("Dash") > 0 then
		return false
	end
	local airborne = isAirborne(humanoid)
	if airborne then
		if airDashesUsed >= Combat.Dash.airDashes then
			return false
		end
		airDashesUsed += 1
	end
	local move = humanoid.MoveDirection
	local direction = if move.Magnitude > 0.1
		then Physics.flat(move)
		else Physics.flat(workspace.CurrentCamera.CFrame.LookVector)
	setLocalCooldown("Dash", Combat.Dash.cooldown)
	busyUntil = 0
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	Physics.impulse(
		root,
		direction * Combat.Dash.speed + Vector3.new(0, if airborne then 6 else 0, 0),
		Combat.Dash.duration
	)
	AnimController.Play(model, "Dash")
	local color = VFX.Color(VFX.ElementOf(model))
	for i = 0, 3 do
		task.delay(i * 0.04, function()
			VFX.Afterimage(model, color, 0.3)
		end)
	end
	VFX.SpeedLines(0.25)
	VFX.Shockwave(root.Position - Vector3.new(0, 2.6, 0), color, 6, 0.3, 0.2)
	CameraController.Kick(12)
	SoundController.Play("Dash", root)
	inputRemote:FireServer("Dash", { direction = direction })
	return true
end

local function performAbility(slot: string): boolean
	local model, humanoid, root = character()
	if not model or not humanoid or not root then
		return false
	end
	local abilityId = CombatController.Slots()[slot]
	local def = abilityId and Abilities[abilityId]
	if not def then
		return false
	end
	if CombatController.CooldownRemaining("Slot:" .. slot) > 0 then
		return false
	end
	local reiatsu = model:GetAttribute("Reiatsu") or 0
	if reiatsu < def.cost * 0.5 then
		return false
	end
	local range = def.range or def.length or def.distance or 60
	local aim = aimPoint(range)
	local direction = if aim then Physics.flat(aim - root.Position, root.CFrame.LookVector) else attackDirection()
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	busyUntil = os.clock() + def.duration
	inputRemote:FireServer("Ability", { slot = slot, direction = direction, aim = aim })
	return true
end

-- Executa a ação; se ocupado, guarda no buffer.
local function tryAction(action: string)
	if not alive() then
		return
	end
	if CameraController.InCinematic() and action ~= "Block" then
		-- Pular a cena ao agir
		CameraController.EndCinematic()
	end
	local now = os.clock()
	if stunned() or now < busyUntil - 0.02 then
		buffered = { action = action, time = now }
		return
	end
	buffered = nil
	if action == "Dash" then
		performDash()
		return
	end
	if blocking then
		return
	end
	if action == "Attack" then
		performAttack("Light")
	elseif action == "Heavy" then
		performAttack("Heavy")
	elseif action == "Launcher" then
		performAttack("Launcher")
	elseif action == "Z" or action == "X" or action == "C" or action == "V" then
		performAbility(action)
	end
end

local function onAction(action: string, began: boolean)
	local model = player.Character
	if not model then
		return
	end
	if action == "Block" then
		if began and not stunned() then
			blocking = true
			busyUntil = 0
			buffered = nil
			AnimController.Play(model, "Block")
			inputRemote:FireServer("BlockStart")
		elseif not began and blocking then
			blocking = false
			AnimController.Stop(model, "Block")
			inputRemote:FireServer("BlockEnd")
		end
	elseif action == "Charge" then
		inputRemote:FireServer(if began then "ChargeStart" else "ChargeEnd")
		if began then
			AnimController.Play(model, "Charge")
		else
			AnimController.Stop(model, "Charge")
		end
	elseif action == "Sprint" then
		inputRemote:FireServer(if began then "SprintStart" else "SprintEnd")
	elseif not began then
		return
	elseif action == "Transform" then
		inputRemote:FireServer("Transform")
	elseif action == "Mask" then
		inputRemote:FireServer("Mask")
	elseif action == "Draw" then
		inputRemote:FireServer("Draw")
	else
		tryAction(action)
	end
end

-- Pulo duplo no ar
local function onJumpRequest()
	local model, humanoid, root = character()
	if not model or not humanoid or not root or stunned() then
		return
	end
	if not isAirborne(humanoid) or airStepsUsed >= Combat.AirStep.max then
		return
	end
	if root.AssemblyLinearVelocity.Y > 20 then
		return -- ainda subindo do primeiro pulo
	end
	airStepsUsed += 1
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, Combat.AirStep.velocity, v.Z)
	AnimController.Play(model, "AirStep")
	local color = VFX.Color(VFX.ElementOf(model))
	VFX.Shockwave(root.Position - Vector3.new(0, 3, 0), color, 5, 0.3, 0.2)
	SoundController.Play("Jump", root)
end

-- ============================================================
-- Eventos do servidor para o próprio jogador
-- ============================================================
local function onImpulse(data)
	local model, _, root = character()
	if not model or not root or type(data) ~= "table" then
		return
	end
	if data.kind == "Knockback" and typeof(data.velocity) == "Vector3" then
		Physics.impulse(root, data.velocity, math.clamp(tonumber(data.duration) or 0.15, 0.02, 0.4))
	elseif data.kind == "Hover" then
		Physics.hover(root, math.clamp(tonumber(data.duration) or 0.4, 0.05, 1))
	elseif data.kind == "Teleport" and typeof(data.cframe) == "CFrame" then
		VFX.Afterimage(model, VFX.Color(VFX.ElementOf(model)), 0.4)
		Physics.clear(root)
		model:PivotTo(data.cframe)
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function onState(data)
	if type(data) ~= "table" or type(data.cooldowns) ~= "table" then
		return
	end
	local now = os.clock()
	for key, remaining in data.cooldowns do
		if type(remaining) == "number" then
			local previousTotal = cooldowns[key .. "#total"]
			local current = cooldowns[key] and cooldowns[key] - now or 0
			if remaining > current + 0.05 or not previousTotal then
				cooldowns[key .. "#total"] = remaining
			end
			cooldowns[key] = now + remaining
		end
	end
	CombatController.CooldownsChanged:Fire()
end

function CombatController.Init()
	inputRemote = Net.event("CombatInput")
end

function CombatController.Start()
	InputController.Action:Connect(onAction)
	UserInputService.JumpRequest:Connect(onJumpRequest)
	Net.event("Impulse").OnClientEvent:Connect(onImpulse)
	Net.event("State").OnClientEvent:Connect(onState)

	player.CharacterAdded:Connect(function(model)
		busyUntil = 0
		buffered = nil
		blocking = false
		combo.index = 0
		combo.aerial = 0
		local humanoid = model:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
					airDashesUsed = 0
					airStepsUsed = 0
				end
			end)
		end
		model:GetAttributeChangedSignal("Stunned"):Connect(function()
			if model:GetAttribute("Stunned") then
				busyUntil = 0
				buffered = nil
				AnimController.StopAll(model, 2, 0.05)
				if blocking then
					blocking = false
				end
			elseif InputController.IsHeld("Block") then
				onAction("Block", true)
			end
		end)
	end)

	-- Consome o buffer quando o personagem fica livre
	RunService.Heartbeat:Connect(function()
		if buffered then
			local now = os.clock()
			if now - buffered.time > Combat.InputBuffer then
				buffered = nil
			elseif now >= busyUntil - 0.02 and not stunned() then
				local action = buffered.action
				buffered = nil
				tryAction(action)
			end
		end
	end)

	-- Ataque segurado = sequência contínua (útil no celular)
	task.spawn(function()
		while true do
			task.wait(0.05)
			if InputController.IsHeld("Attack") and not buffered and os.clock() >= busyUntil and not blocking then
				tryAction("Attack")
			end
		end
	end)
end

CombatController.PoseDuration = function(name: string): number
	local def = Poses[name]
	return def and def.duration or 0.5
end

return CombatController

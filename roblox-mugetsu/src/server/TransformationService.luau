--!strict
-- Autoridade da transformação. Valida o pedido, trava o personagem, executa os eventos do servidor
-- da Timeline (troca real do modelo, habilitar habilidade), e SEMPRE restaura o estado, mesmo em
-- cancelamento, morte, saída do jogador ou timeout (watchdog).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Mugetsu")
local Config = require(Shared:WaitForChild("Config"))
local Timeline = require(Shared:WaitForChild("Timeline"))
local StateMachine = require(Shared:WaitForChild("StateMachine"))
local AbilityMath = require(Shared:WaitForChild("AbilityMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ModelKit = require(script.Parent:WaitForChild("ModelKit"))
local RateLimiter = require(script.Parent:WaitForChild("RateLimiter"))

type Saved = {
	walkSpeed: number,
	jumpHeight: number,
	jumpPower: number,
	useJumpPower: boolean,
	autoRotate: boolean,
	anchored: boolean,
}

type Session = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	machine: StateMachine.Machine,
	startTime: number, -- GetServerTimeNow
	lastT: number,
	saved: Saved,
	forceField: ForceField?,
	conns: { RBXScriptConnection },
	swapped: boolean,
}

local TransformationService = {}

local sessions: { [Player]: Session } = {}
local transformCooldownReadyAt: { [Player]: number } = {}
local revertTokens: { [Player]: number } = {}
local heartbeatConn: RBXScriptConnection? = nil

local LEAD_TIME = 0.4 -- margem para o cliente receber o evento antes do t=0

local notify = Remotes.get("Notify")
local startRemote = Remotes.get("CutsceneStart")
local observeRemote = Remotes.get("CutsceneObserve")
local cancelRemote = Remotes.get("CutsceneCancel")
local endRemote = Remotes.get("CutsceneEnd")

local function nearbyPlayers(origin: Vector3, except: Player): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= except then
			local c = p.Character
			local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and (hrp.Position - origin).Magnitude <= Config.Transform.MaxRange then
				table.insert(list, p)
			end
		end
	end
	return list
end

local function restore(s: Session)
	local h, r = s.humanoid, s.root
	if h.Parent then
		h.WalkSpeed = s.saved.walkSpeed
		h.UseJumpPower = s.saved.useJumpPower
		h.JumpHeight = s.saved.jumpHeight
		h.JumpPower = s.saved.jumpPower
		h.AutoRotate = s.saved.autoRotate
	end
	if r.Parent then
		r.Anchored = s.saved.anchored
	end
	if s.forceField then
		s.forceField:Destroy()
		s.forceField = nil
	end
end

local function finish(s: Session, reason: string, completed: boolean)
	if sessions[s.player] ~= s then
		return
	end
	sessions[s.player] = nil
	for _, c in s.conns do
		c:Disconnect()
	end
	restore(s)
	if completed then
		s.machine:transition("Idle")
	else
		s.machine:transition("Cancelled")
		s.machine:transition("Idle")
	end
	s.player:SetAttribute("MugetsuCutscene", false)
	local payload = { reason = reason, form = s.swapped }
	if completed then
		endRemote:FireClient(s.player, payload)
	else
		cancelRemote:FireClient(s.player, payload)
	end
	for _, p in nearbyPlayers(s.root.Position, s.player) do
		(completed and endRemote or cancelRemote):FireClient(p, { userId = s.player.UserId, reason = reason })
	end
	-- Mantém o form final apenas se a troca já aconteceu; a habilidade fica ativa apenas se completou
	-- ou se a troca já aconteceu (o jogador já é Mugetsu).
	if s.swapped then
		s.player:SetAttribute("MugetsuForm", true)
		s.player:SetAttribute("MugetsuAbilityReady", true)
	end
end

local function revertForm(player: Player, character: Model)
	if ModelKit.currentForm(character) == "Mugetsu" then
		ModelKit.setForm(character, "Ichigo", 0.8)
	end
	player:SetAttribute("MugetsuForm", false)
end

local function onServerEvent(s: Session, name: string)
	if name == "ReleaseImpact" then
		s.machine:transition("Climax")
	elseif name == "MorphSwap" then
		if not s.swapped then
			ModelKit.setForm(s.character, "Mugetsu", 0) -- instantâneo: a tela está toda branca neste instante
			s.swapped = true
			s.player:SetAttribute("MugetsuForm", true)
			-- agenda o retorno à forma normal
			if Config.Transform.FormDuration > 0 then
				local token = (revertTokens[s.player] or 0) + 1
				revertTokens[s.player] = token
				local char = s.character
				task.delay(Config.Transform.FormDuration, function()
					if revertTokens[s.player] == token and char.Parent then
						revertForm(s.player, char)
					end
				end)
			end
		end
	elseif name == "FadeToBlack" then
		s.machine:transition("Finishing")
	elseif name == "EnableAbility" then
		s.player:SetAttribute("MugetsuAbilityReady", true)
	elseif name == "End" then
		finish(s, "completed", true)
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for _, s in sessions do
		local t = now - s.startTime
		if t > Timeline.Duration + Config.Safety.WatchdogMargin then
			finish(s, "watchdog", false)
		elseif t > 0 then
			if s.machine.state == "Starting" then
				s.machine:transition("Running")
			end
			local events = Timeline.eventsBetween(s.lastT, t)
			s.lastT = t
			for _, ev in events do
				-- se a sessão foi finalizada por um evento anterior, interrompe
				if sessions[s.player] ~= s then
					break
				end
				onServerEvent(s, ev.name)
			end
		end
	end
	if next(sessions) == nil and heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

function TransformationService.cancel(player: Player, reason: string)
	local s = sessions[player]
	if s then
		finish(s, reason, false)
	end
end

function TransformationService.isInCutscene(player: Player): boolean
	return sessions[player] ~= nil
end

local function reject(player: Player, msg: string)
	notify:FireClient(player, { kind = "warn", text = msg })
end

function TransformationService.request(player: Player)
	if not RateLimiter.allow(player, "Transform", 1) then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and hum and root) or hum.Health <= 0 then
		return
	end
	if sessions[player] then
		return
	end
	if Config.Transform.RequireR15 and not ModelKit.isR15(char) then
		return reject(player, "A transformação exige um avatar R15.")
	end
	if player:GetAttribute("MugetsuForm") == true then
		return reject(player, "Você já está na forma Mugetsu.")
	end
	local now = Workspace:GetServerTimeNow()
	if not AbilityMath.isReady(transformCooldownReadyAt[player], now) then
		return reject(player, `Aguarde {math.ceil(AbilityMath.remaining(transformCooldownReadyAt[player], now))}s.`)
	end

	ModelKit.build(char)
	transformCooldownReadyAt[player] = now + Config.Transform.Cooldown

	local saved: Saved = {
		walkSpeed = hum.WalkSpeed,
		jumpHeight = hum.JumpHeight,
		jumpPower = hum.JumpPower,
		useJumpPower = hum.UseJumpPower,
		autoRotate = hum.AutoRotate,
		anchored = root.Anchored,
	}
	local machine = StateMachine.new()
	machine:transition("Starting")
	local s: Session = {
		player = player,
		character = char,
		humanoid = hum,
		root = root,
		machine = machine,
		startTime = now + LEAD_TIME,
		lastT = 0,
		saved = saved,
		forceField = nil,
		conns = {},
		swapped = false,
	}
	sessions[player] = s

	-- trava de movimento + invulnerabilidade durante a cena
	hum.WalkSpeed = Config.Safety.HumanoidWalkSpeedDuringCutscene
	hum.JumpHeight = 0
	hum.JumpPower = 0
	hum.AutoRotate = false
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	local ff = Instance.new("ForceField")
	ff.Visible = false
	ff.Parent = char
	s.forceField = ff
	player:SetAttribute("MugetsuCutscene", true)
	player:SetAttribute("MugetsuAbilityReady", false)

	table.insert(s.conns, hum.Died:Connect(function()
		finish(s, "died", false)
	end))
	table.insert(s.conns, char.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			finish(s, "character-removed", false)
		end
	end))

	local cframe = root.CFrame
	startRemote:FireClient(player, { startTime = s.startTime, duration = Timeline.Duration })
	for _, p in nearbyPlayers(root.Position, player) do
		observeRemote:FireClient(p, { userId = player.UserId, startTime = s.startTime, duration = Timeline.Duration, cframe = cframe })
	end

	if not heartbeatConn then
		heartbeatConn = RunService.Heartbeat:Connect(step)
	end
end

function TransformationService.init()
	Remotes.get("RequestTransform").OnServerEvent:Connect(function(player: Player)
		TransformationService.request(player)
	end)
	local function onPlayer(p: Player)
		p.CharacterAdded:Connect(function(char)
			p:SetAttribute("MugetsuForm", false)
			p:SetAttribute("MugetsuAbilityReady", false)
			p:SetAttribute("MugetsuCutscene", false)
			revertTokens[p] = (revertTokens[p] or 0) + 1 -- invalida reversões pendentes
			task.defer(function()
				if char.Parent and char:FindFirstChildOfClass("Humanoid") and ModelKit.isR15(char) then
					ModelKit.build(char)
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		TransformationService.cancel(p, "left")
		transformCooldownReadyAt[p] = nil
		revertTokens[p] = nil
		RateLimiter.forget(p)
	end)
end

return TransformationService

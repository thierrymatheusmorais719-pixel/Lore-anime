--!strict
-- Orquestrador da cutscene no cliente.
-- Um único relógio (tempo do servidor) dirige: câmera, HUD, iluminação, áudio, poses e VFX.
-- O dono da cutscene recebe tudo; observadores próximos veem só pose + VFX + troca de modelo.
-- Máquina de estados: Idle -> Starting -> Running -> Climax -> Finishing -> Idle (e Cancelled).
-- Qualquer erro dentro de um handler é capturado; qualquer saída passa por teardown().

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Mugetsu")
local Config = require(Shared:WaitForChild("Config"))
local Timeline = require(Shared:WaitForChild("Timeline"))
local StateMachine = require(Shared:WaitForChild("StateMachine"))
local Manifest = require(Shared:WaitForChild("AssetManifest"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local CameraDirector = require(script.Parent:WaitForChild("CameraDirector"))
local LightingDirector = require(script.Parent:WaitForChild("LightingDirector"))
local AudioDirector = require(script.Parent:WaitForChild("AudioDirector"))
local InputController = require(script.Parent:WaitForChild("InputController"))
local PoseApplier = require(script.Parent:WaitForChild("PoseApplier"))
local VFX = require(script.Parent:WaitForChild("VFX"))
local Quality = require(script.Parent:WaitForChild("Quality"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local HairSway = require(script.Parent:WaitForChild("HairSway"))

local BIND = "MugetsuTimeline"
local localPlayer = Players.LocalPlayer

type Ctx = {
	isOwner: boolean,
	player: Player,
	char: Model,
	root: BasePart,
	start: number,
	lastT: number,
	vfx: VFX.Session,
	pose: PoseApplier.Applier,
	auraRamp: { from: number, to: number, t0: number, dur: number }?,
	markerOwned: { [string]: boolean },
	fired: { [string]: boolean },
	bindName: string,
	done: boolean,
}

local CutsceneController = {}
CutsceneController.machine = StateMachine.new()

local ownerCtx: Ctx? = nil
local observers: { [number]: Ctx } = {}
local counter = 0

local function floorCF(ctx: Ctx): CFrame
	return CFrame.new(ctx.root.Position - Vector3.new(0, 2.95, 0))
end

local function blade(ctx: Ctx): BasePart?
	local kits = ctx.char:FindFirstChild("MugetsuKits")
	if not kits then
		return nil
	end
	local form = kits:GetAttribute("Form") :: string?
	local kit = kits:FindFirstChild(form or "Ichigo")
	local b = kit and kit:FindFirstChild("Blade")
	return b and b:IsA("BasePart") and b or nil
end

local function setAura(ctx: Ctx, to: number, dur: number)
	ctx.auraRamp = { from = 0, to = to, t0 = os.clock(), dur = math.max(dur, 0.01) }
end

------------------------------------------------------------------------------------------------
-- Handlers: um por evento da Timeline. (ctx, arg)
------------------------------------------------------------------------------------------------
local H: { [string]: (Ctx, any) -> () } = {}

H.LockControls = function(ctx)
	if ctx.isOwner then
		InputController.lock()
		Hud.showButtons(false, false)
		Hud.setLetterbox(true, 0.9)
		LightingDirector.apply("Cold", 1.5)
	end
end
H.AmbientDuck = function(ctx, arg)
	if ctx.isOwner then
		AudioDirector.duck(arg or 0.25, 1.2)
		AudioDirector.play("AmbientBed", 1, true)
	end
end
local function animStart(name: string): number
	for _, ev in Timeline.Events do
		if ev.name == "Anim" and ev.arg == name then
			return ev.t
		end
	end
	return 0
end
H.Anim = function(ctx, arg)
	ctx.pose:play(arg, ctx.start + animStart(arg), arg == "Concentrate" and 1 or 0)
end
H.Lighting = function(ctx, arg)
	if ctx.isOwner then
		LightingDirector.apply(arg, arg == "Mugetsu" and 0.1 or 1.0)
	end
end
H.AuraWhispers = function(ctx)
	ctx.vfx:auraStart(ctx.char, "Blue")
	setAura(ctx, 0.25, 3)
end
H.SwordGlint = function(ctx)
	local b = blade(ctx)
	if b then
		ctx.vfx:glint(b)
	end
end
H.PauseBeat = function(ctx)
	if ctx.isOwner then
		CameraDirector.punchFov(-4, 0.5)
		AudioDirector.play("Heartbeat")
		LightingDirector.pulse(0.15)
	end
end
H.EnergyGather = function(ctx)
	setAura(ctx, 1, 7)
	ctx.vfx:gather(ctx.char, 6.5, VFX.Colors.Blue)
	if ctx.isOwner then
		AudioDirector.play("EnergyRise")
	end
end
H.GroundShards = function(ctx)
	local f = floorCF(ctx).Position
	ctx.vfx:shards(f, "rise", 22, 5.2, Color3.fromRGB(16, 18, 28), nil)
	ctx.vfx:shards(f, "rise", 14, 5.2, VFX.Colors.Blue, nil)
end
H.PulseLight = function(ctx, arg)
	local a = arg or 0.5
	ctx.vfx:lightPulse(ctx.root.Position + Vector3.new(0, 1, 0), VFX.Colors.Blue, 3 + 4 * a, 45, 0.55)
	if ctx.isOwner then
		LightingDirector.pulse(a * 0.5)
		CameraDirector.shake(0.05 + 0.08 * a, 0.3)
	end
end
H.EyeReiatsu = function(ctx)
	local head = ctx.char:FindFirstChild("Head") :: BasePart?
	if head then
		ctx.vfx:lightPulse(head.Position + Vector3.new(0, 0, -1.5), VFX.Colors.Blue, 4, 12, 2.4)
	end
	if ctx.isOwner then
		LightingDirector.pulse(0.4)
	end
end
H.PressureWave = function(ctx)
	ctx.vfx:shockwave(floorCF(ctx), 28, 1.3, VFX.Colors.Blue)
	ctx.vfx:dustBurst(floorCF(ctx).Position, 24, nil)
	ctx.vfx:shards(floorCF(ctx).Position, "burst", 10, 1.6, VFX.Colors.Blue, nil)
	if ctx.isOwner then
		CameraDirector.shake(0.25, 0.8)
	end
end
H.BlueSpire = function(ctx)
	if ctx.isOwner then
		LightingDirector.apply("Night", 0.6)
		LightingDirector.blur(2, 0.6)
	end
	ctx.vfx:spire(floorCF(ctx).Position + Vector3.new(0, 0, -2), 70, 3.6, VFX.Colors.Blue)
end
H.MaskForm = function(ctx)
	local head = ctx.char:FindFirstChild("Head") :: BasePart?
	if head then
		ctx.vfx:shards(head.Position + Vector3.new(0, 1, -6), "converge", 26, 1.1, VFX.Colors.White, function()
			return head.Position + Vector3.new(0, -0.2, -0.6)
		end)
		ctx.vfx:lightPulse(head.Position, VFX.Colors.White, 6, 16, 0.8)
	end
	if ctx.isOwner then
		CameraDirector.shake(0.18, 0.6)
		LightingDirector.blur(0, 0.4)
	end
end
H.ShakeSmall = function(ctx)
	if ctx.isOwner then
		CameraDirector.shake(0.12, 0.5)
	end
end
H.BeginFade = function(ctx)
	if ctx.isOwner then
		Hud.fade(Color3.new(1, 1, 1), 0, 0.4)
	end
end
H.WhiteOut = function(ctx)
	if ctx.isOwner then
		-- a troca real do modelo acontece no servidor durante o branco; aqui trocamos o cenário
		LightingDirector.apply("Overcast", 0.05)
		LightingDirector.blur(0, 0.1)
	end
	ctx.vfx:auraStop()
end
H.MorphSwap = function() end -- executado no servidor (ModelKit); o cliente só observa a replicação
H.BlackTendrils = function(ctx)
	ctx.vfx:tendrils(ctx.root.Position, 14, 2.8)
	if ctx.isOwner then
		AudioDirector.play("Tendrils")
	end
end
H.WhiteOutEnd = function(ctx)
	if ctx.isOwner then
		Hud.fade(Color3.new(1, 1, 1), 1, 0.35)
	end
end
H.ReleaseImpact = function(ctx)
	CutsceneController.machine:transition("Climax")
	local f = floorCF(ctx)
	ctx.vfx:auraStart(ctx.char, "Black")
	setAura(ctx, 1, 0.3)
	ctx.vfx:shockwave(f, 70, 1.2, VFX.Colors.White)
	local n = Quality.settings().Rings
	for i = 1, n do
		ctx.vfx:ring(f * CFrame.new(0, 0.2 + i * 0.4, 0), 36 + i * 16, 0.7 + i * 0.18, i % 2 == 0 and VFX.Colors.White or VFX.Colors.Black, 0.8 + i * 0.25)
	end
	ctx.vfx:ring(f * CFrame.new(0, 3, 0), 30, 0.9, VFX.Colors.Black, 1.2, CFrame.Angles(math.rad(18), 0, math.rad(-12)))
	ctx.vfx:shards(f.Position, "burst", 36, 1.8, Color3.fromRGB(10, 10, 12), nil)
	ctx.vfx:shards(f.Position, "burst", 12, 1.6, VFX.Colors.White, nil)
	ctx.vfx:dustBurst(f.Position, 40, nil)
	ctx.vfx:lightPulse(ctx.root.Position + Vector3.new(0, 2, 0), VFX.Colors.White, 10, 90, 0.7)
	HairSway.gust(1, 3)
	if ctx.isOwner then
		Hud.flash(Color3.new(1, 1, 1), 0.06, 0.4)
		CameraDirector.shake(0.8, 0.7)
		CameraDirector.punchFov(14, 0.5)
		LightingDirector.pulse(1.2)
		AudioDirector.play("Impact")
	end
end
H.SwordSlash = function(ctx)
	local b = blade(ctx)
	if b then
		ctx.vfx:swordTrail(b, 0.9)
	end
	if ctx.isOwner then
		AudioDirector.play("SwordSlash")
	end
end
H.EnvironmentReact = function(ctx)
	ctx.vfx:environmentReact(ctx.root.Position, 170, 1.3, 2.4)
end
H.ImpactFrame = function(ctx)
	if ctx.isOwner then
		LightingDirector.impactFrame(0.12)
		Hud.flash(Color3.new(0, 0, 0), 0.04, 0.12)
		CameraDirector.shake(0.3, 0.25)
	end
end
H.FadeToBlack = function(ctx)
	if ctx.isOwner then
		CutsceneController.machine:transition("Finishing")
		Hud.fade(Color3.new(0, 0, 0), 0, 1.3)
	end
end
H.FadeFromBlack = function(ctx)
	if ctx.isOwner then
		Hud.fade(Color3.new(0, 0, 0), 1, 1.4)
	end
end
H.EnableAbility = function(ctx)
	if ctx.isOwner then
		Hud.notify("Habilidade liberada: " .. Config.Ability.Name)
	end
end
H.End = function() end -- o servidor envia CutsceneEnd; o relógio local também encerra por segurança

------------------------------------------------------------------------------------------------
-- Ciclo de vida
------------------------------------------------------------------------------------------------
local function dispatch(ctx: Ctx, ev: Timeline.Event)
	local fn = H[ev.name]
	if not fn then
		return
	end
	-- eventos conduzidos por marker de animação real: o marker dispara; este fallback cobre atrasos
	if ctx.markerOwned[ev.name] then
		task.delay(0.6, function()
			if not ctx.done and not ctx.fired[ev.name] then
				ctx.fired[ev.name] = true
				local ok, err = pcall(fn, ctx, ev.arg)
				if not ok then
					warn("[Mugetsu] handler", ev.name, err)
				end
			end
		end)
		return
	end
	local ok, err = pcall(fn, ctx, ev.arg)
	if not ok then
		warn("[Mugetsu] handler", ev.name, err)
	end
end

local function eventCount(name: string): number
	local n = 0
	for _, ev in Timeline.Events do
		if ev.name == name then
			n += 1
		end
	end
	return n
end

local function teardownCtx(ctx: Ctx)
	if ctx.done then
		return
	end
	ctx.done = true
	pcall(function()
		RunService:UnbindFromRenderStep(ctx.bindName)
	end)
	ctx.vfx:auraStop()
	pcall(function()
		ctx.pose:stop()
	end)
	task.delay(1.4, function()
		ctx.vfx:clean()
	end)
end

local function teardownOwner(reason: string)
	local ctx = ownerCtx
	ownerCtx = nil
	if ctx then
		teardownCtx(ctx)
	end
	-- tudo abaixo é idempotente e executa mesmo se ctx for nil
	CameraDirector.stop()
	Hud.resetCinematic()
	Hud.showButtons(localPlayer:GetAttribute("MugetsuForm") ~= true, localPlayer:GetAttribute("MugetsuAbilityReady") == true and localPlayer:GetAttribute("MugetsuForm") == true)
	LightingDirector.restore(reason == "completed" and 1.0 or 0.4)
	AudioDirector.stopAll(0.6)
	InputController.unlock()
	CutsceneController.machine:reset()
end

local function makeCtx(player: Player, start: number, isOwner: boolean): Ctx?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and root) then
		return nil
	end
	counter += 1
	local ctx: Ctx = {
		isOwner = isOwner, player = player, char = char, root = root, start = start, lastT = -0.001,
		vfx = VFX.session(), pose = PoseApplier.new(char, isOwner), auraRamp = nil, markerOwned = {}, fired = {},
		bindName = `{BIND}{counter}`, done = false,
	}
	ctx.pose.onMarker = function(eventName: string)
		if not ctx.fired[eventName] and H[eventName] then
			ctx.fired[eventName] = true
			local ok, err = pcall(H[eventName], ctx, nil)
			if not ok then
				warn("[Mugetsu] marker", eventName, err)
			end
		end
	end
	-- marca eventos únicos que têm marker numa animação real publicada
	for _, entry in Manifest.Animations do
		if entry.id ~= "" then
			for _, ev in entry.markers do
				if eventCount(ev) == 1 and ev ~= "MorphSwap" then
					ctx.markerOwned[ev] = true
				end
			end
		end
	end
	return ctx
end

local function run(ctx: Ctx)
	RunService:BindToRenderStep(ctx.bindName, Enum.RenderPriority.Camera.Value - 3, function()
		if ctx.done then
			return
		end
		local ok, err = pcall(function()
			if not ctx.root.Parent then
				error("personagem removido")
			end
			local t = Workspace:GetServerTimeNow() - ctx.start
			if t > Timeline.Duration + Config.Safety.WatchdogMargin then
				error("watchdog")
			end
			if t < 0 then
				return
			end
			for _, ev in Timeline.eventsBetween(ctx.lastT, t) do
				dispatch(ctx, ev)
			end
			ctx.lastT = t
			local r = ctx.auraRamp
			if r then
				local k = math.clamp((os.clock() - r.t0) / r.dur, 0, 1)
				ctx.vfx:auraIntensity(r.from + (r.to - r.from) * k)
				if k >= 1 then
					ctx.auraRamp = nil
				end
			end
		end)
		if not ok then
			warn("[Mugetsu] cutscene loop:", err)
			if ctx.isOwner then
				teardownOwner("error")
			else
				teardownCtx(ctx)
			end
		end
	end)
end

function CutsceneController.startOwner(payload: { startTime: number, duration: number })
	if ownerCtx then
		teardownOwner("restart")
	end
	local m = CutsceneController.machine
	m:reset()
	m:transition("Starting")
	local ctx = makeCtx(localPlayer, payload.startTime, true)
	if not ctx then
		teardownOwner("no-character")
		return
	end
	ownerCtx = ctx
	InputController.lock() -- trava imediatamente, antes do t=0
	CameraDirector.start(ctx.root, payload.startTime)
	m:transition("Running")
	local hum = ctx.char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Once(function()
			teardownOwner("died")
		end)
	end
	run(ctx)
end

function CutsceneController.startObserver(payload: { userId: number, startTime: number })
	local player = Players:GetPlayerByUserId(payload.userId)
	if not player or player == localPlayer then
		return
	end
	local old = observers[payload.userId]
	if old then
		teardownCtx(old)
	end
	local ctx = makeCtx(player, payload.startTime, false)
	if not ctx then
		return
	end
	observers[payload.userId] = ctx
	run(ctx)
end

function CutsceneController.endObserver(userId: number)
	local ctx = observers[userId]
	observers[userId] = nil
	if ctx then
		teardownCtx(ctx)
	end
end

function CutsceneController.cancelOwner(reason: string)
	teardownOwner(reason)
end

function CutsceneController.isRunning(): boolean
	return ownerCtx ~= nil
end

function CutsceneController.init()
	Remotes.get("CutsceneStart").OnClientEvent:Connect(CutsceneController.startOwner)
	Remotes.get("CutsceneObserve").OnClientEvent:Connect(CutsceneController.startObserver)
	Remotes.get("CutsceneEnd").OnClientEvent:Connect(function(p)
		if p and p.userId then
			CutsceneController.endObserver(p.userId)
		else
			teardownOwner("completed")
		end
	end)
	Remotes.get("CutsceneCancel").OnClientEvent:Connect(function(p)
		if p and p.userId then
			CutsceneController.endObserver(p.userId)
		else
			teardownOwner("cancelled")
		end
	end)
	-- saída segura se o personagem do dono sumir
	localPlayer.CharacterRemoving:Connect(function()
		if ownerCtx then
			teardownOwner("character-removing")
		end
	end)
	Remotes.get("Notify").OnClientEvent:Connect(function(p)
		Hud.notify(p.text)
	end)
end

return CutsceneController

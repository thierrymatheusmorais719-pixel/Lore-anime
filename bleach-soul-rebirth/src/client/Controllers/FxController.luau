-- Recebe eventos "Fx" do servidor e sincroniza animação + efeitos + som + câmera para
-- qualquer ator (jogadores, inimigos, chefes). Ações do próprio jogador já previstas não repetem.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Combat = require(Shared.Config.Combat)
local Poses = require(Shared.Anim.Poses)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local Controllers = script.Parent
local AnimController = require(Controllers.AnimController)
local VFX = require(Controllers.VFXController)
local SoundController = require(Controllers.SoundController)
local CameraController = require(Controllers.CameraController)
local CombatController = require(Controllers.CombatController)

local FxController = {}
FxController.LocalHit = Signal.new() -- (damage, result) golpe do jogador local acertou
FxController.LocalParry = Signal.new()
FxController.LocalHurt = Signal.new() -- (damage)
FxController.ReleaseTitle = Signal.new() -- (data)
FxController.BossPhase = Signal.new() -- (data)
FxController.Settings = nil :: (() -> any)?

local player = Players.LocalPlayer
local rng = Random.new()

local function isLocal(model: Instance?): boolean
	return model ~= nil and model == player.Character
end

local function rootOf(model: Instance?): BasePart?
	if not model then
		return nil
	end
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function nearLocal(position: Vector3?, radius: number): boolean
	local root = rootOf(player.Character)
	return root ~= nil and position ~= nil and (root.Position - position).Magnitude < radius
end

local handlers: { [string]: (any) -> () } = {}

handlers.Attack = function(d)
	local model = d.actor
	if not model or not model.Parent then
		return
	end
	local spec
	if d.kind == "Light" then
		if d.anim == "Counter" then
			spec = Combat.Counter
		elseif d.aerial then
			spec = Combat.Aerial[d.index or 1]
		else
			spec = Combat.Light[d.index or 1]
		end
	elseif d.anim == "Execution" then
		spec = Combat.Execution
	elseif d.kind == "Heavy" then
		spec = Combat.Heavy
	else
		spec = Combat.Launcher
	end
	if isLocal(model) and CombatController.WasPredicted(d.anim) then
		return
	end
	AnimController.Play(model, d.anim)
	CombatController.SlashFx(model, spec, d.anim)
	if d.anim == "Execution" then
		local root = rootOf(model)
		if root then
			VFX.Pillar(root.Position - Vector3.new(0, 3, 0), VFX.Color(VFX.ElementOf(model)), 4, 18, spec.windup)
		end
		if isLocal(model) or isLocal(d.target) then
			local focus = rootOf(model)
			if focus then
				CameraController.PlayCinematic(focus, {
					{
						duration = spec.windup * 0.85,
						fromAngle = 150,
						toAngle = 110,
						distance = 9,
						height = 1.5,
						fov = 45,
					},
					{
						duration = 0.7,
						fromAngle = -40,
						toAngle = -80,
						distance = 14,
						distanceEnd = 18,
						height = 3,
						fov = 60,
					},
				})
			end
		end
	end
end

local reactionToggle = false
handlers.Hit = function(d)
	local attacker, target = d.attacker, d.target
	local element = VFX.ElementOf(attacker)
	local color = VFX.Color(element)
	local position: Vector3 = d.position
	local heavy = d.heavy or d.counter
	-- Hit-stop sincronizado
	local stop = d.hitstop or 0.05
	AnimController.Freeze(attacker, stop)
	AnimController.Freeze(target, stop)

	if d.result == "Blocked" then
		AnimController.Play(target, "BlockHit")
		VFX.Sparks(position, Color3.fromRGB(255, 230, 160), 10)
		SoundController.Play("Block", position)
		VFX.DamageNumber(position, d.damage, "Blocked")
	else
		local reaction
		if d.result == "GuardBreak" then
			reaction = "GuardBreak"
		elseif d.launched then
			reaction = "Launched"
		elseif heavy then
			reaction = "Stagger"
		else
			reactionToggle = not reactionToggle
			reaction = if reactionToggle then "Hit1" else "Hit2"
		end
		if target and not (target:GetAttribute("Boss") and reaction ~= "Hit1" and reaction ~= "Hit2") then
			AnimController.StopAll(target, 3, 0.04)
			AnimController.Play(target, reaction)
		end
		VFX.Sparks(position, color, if heavy then 26 else 12)
		VFX.Flash(position, color, if heavy then 7 else 3.5, if heavy then 0.25 else 0.15)
		if heavy then
			VFX.Shockwave(position, color, 7, 0.3, 0.3)
			VFX.emit("Wisp", position, color, 10)
		end
		SoundController.Play(if heavy then "HitHeavy" else "HitFlesh", position)
		VFX.DamageNumber(
			position,
			d.damage,
			if d.counter then "Counter" elseif heavy then "Heavy" elseif isLocal(target) then "Self" else nil
		)
	end
	if isLocal(attacker) then
		CameraController.Shake((d.shake or 0.15) * 0.8)
		if heavy then
			CameraController.Kick(6)
		end
		FxController.LocalHit:Fire(d.damage, d.result)
	elseif isLocal(target) then
		CameraController.Shake((d.shake or 0.15) + 0.1)
		FxController.LocalHurt:Fire(d.damage)
		if heavy then
			VFX.ScreenFlash(Color3.fromRGB(255, 40, 40), 0.25, 0.25)
		end
	elseif nearLocal(position, 40) and heavy then
		CameraController.Shake(0.08)
	end
end

handlers.Parry = function(d)
	local position: Vector3 = d.position
	AnimController.StopAll(d.attacker, 3, 0.03)
	AnimController.Play(d.attacker, "Parried")
	AnimController.Play(d.defender, "ParrySuccess")
	AnimController.Freeze(d.attacker, 0.14)
	AnimController.Freeze(d.defender, 0.14)
	VFX.Sparks(position, Color3.fromRGB(255, 220, 120), 30)
	VFX.Flash(position, Color3.fromRGB(255, 245, 200), 6, 0.2)
	VFX.Shockwave(position, Color3.fromRGB(255, 240, 200), 6, 0.25, 0.2)
	SoundController.Play("Parry", position)
	if isLocal(d.defender) then
		CombatController.OnParrySuccess()
		VFX.ScreenFlash(Color3.new(1, 1, 1), 0.2, 0.35)
		CameraController.Shake(0.3)
		FxController.LocalParry:Fire()
	elseif isLocal(d.attacker) then
		CameraController.Shake(0.35)
	end
end

handlers.GuardBreak = function(d)
	local root = rootOf(d.actor)
	if root then
		VFX.Shockwave(root.Position, Color3.fromRGB(255, 160, 80), 8, 0.35)
		VFX.Sparks(root.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 200, 120), 25)
		SoundController.Play("GuardBreak", root.Position)
	end
	AnimController.Stop(d.actor, "Block", 0.05)
end

handlers.Block = function(d)
	if isLocal(d.actor) then
		return
	end
	if d.blocking then
		AnimController.Play(d.actor, "Block")
	else
		AnimController.Stop(d.actor, "Block")
	end
end

handlers.Dash = function(d)
	if isLocal(d.actor) then
		return
	end
	local model = d.actor
	local root = rootOf(model)
	if not model or not root then
		return
	end
	AnimController.Play(model, "Dash")
	local color = VFX.Color(VFX.ElementOf(model))
	for i = 0, 2 do
		task.delay(i * 0.05, function()
			if model.Parent then
				VFX.Afterimage(model, color, 0.3)
			end
		end)
	end
	SoundController.Play("Dash", root)
end

handlers.Evade = function(d)
	local model = d.actor
	if model and model.Parent then
		VFX.Afterimage(model, Color3.fromRGB(200, 220, 255), 0.25)
	end
end

handlers.Cast = function(d)
	local model = d.actor
	if not model or not model.Parent then
		return
	end
	local poseDef = Poses[d.anim]
	local releaseAt = poseDef and poseDef.markers and poseDef.markers.Release or d.windup
	local speed = if d.windup > 0 then releaseAt / d.windup else 1
	AnimController.Play(model, d.anim, { speed = speed })
	local color = VFX.Color(d.element)
	local root = rootOf(model)
	if root then
		SoundController.Play("Cast", root)
		VFX.WeaponTrail(model, color, d.windup + 0.2)
		if d.windup >= 0.35 then
			-- Carga visível (Cero, ultimates)
			local charge =
				VFX.neon(Vector3.one * 0.5, root.CFrame * CFrame.new(0, 1, -2.5), color, 0.1, Enum.PartType.Ball)
			VFX.tween(charge, d.windup, { Size = Vector3.one * (if d.ultimate then 6 else 3) })
			task.delay(d.windup, function()
				charge:Destroy()
			end)
		end
	end
	if d.ultimate then
		if root and (isLocal(model) or nearLocal(root.Position, 60)) then
			VFX.ScreenFlash(color, 0.4, 0.3)
		end
		if isLocal(model) and root then
			CameraController.PlayCinematic(root, {
				{
					duration = d.windup * 0.6,
					fromAngle = 160,
					toAngle = 200,
					distance = 10,
					height = 2,
					fov = 50,
					lookHeight = 2.5,
				},
				{
					duration = d.windup * 0.5,
					fromAngle = 30,
					toAngle = 10,
					distance = 16,
					distanceEnd = 24,
					height = 6,
					fov = 70,
				},
			})
		end
	end
end

handlers.Projectile = function(d)
	VFX.SpawnProjectile(d)
end

handlers.ProjectileEnd = function(d)
	VFX.EndProjectile(d)
	if d.explode then
		SoundController.Play("Boom", d.position, 0.8)
		if nearLocal(d.position, 30) then
			CameraController.Shake(0.15)
		end
	end
end

handlers.Beam = function(d)
	VFX.Beam(d)
	SoundController.Play("Beam", d.origin)
	if nearLocal(d.origin, 60) then
		CameraController.Shake(if d.ultimate then 0.6 else 0.2)
	end
end

handlers.Burst = function(d)
	task.spawn(VFX.Burst, d, if d.follow then rootOf(d.actor) else nil)
	task.delay(d.delay or 0, function()
		SoundController.Play(if d.ultimate then "Ultimate" else "Boom", d.center)
		if nearLocal(d.center, d.radius * 2.5) then
			CameraController.Shake(if d.ultimate then 0.7 else 0.25)
		end
	end)
end

handlers.Rain = function(d)
	task.spawn(VFX.Rain, d)
	SoundController.Play("Cast", d.center)
end

handlers.DashStrike = function(d)
	local model = d.actor
	local color = VFX.Color(d.element)
	local from: Vector3, to: Vector3 = d.from, d.to
	local path = to - from
	if path.Magnitude > 1 then
		local slash = VFX.neon(
			Vector3.new(0.3, 0.3, path.Magnitude),
			CFrame.lookAt((from + to) / 2, to) + Vector3.new(0, 1, 0),
			color,
			0
		)
		VFX.tween(slash, 0.4, { Size = Vector3.new(0.05, 1.5, path.Magnitude), Transparency = 1 })
		task.delay(0.45, function()
			slash:Destroy()
		end)
	end
	if model and model.Parent then
		for i = 1, 4 do
			task.delay(i * 0.03, function()
				if model.Parent then
					VFX.Afterimage(model, color, 0.35)
				end
			end)
		end
	end
	for h = 1, d.hits or 1 do
		task.delay((h - 1) * 0.12 + 0.05, function()
			local frame = CFrame.lookAt(to, to + (if path.Magnitude > 0.1 then path.Unit else Vector3.new(0, 0, -1)))
				* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-60, 60)))
			VFX.SlashArc(frame + Vector3.new(0, 1, 0), color, 6, 0.4, 0.25, h % 2 == 0)
			SoundController.Play("Slash", to)
		end)
	end
	if d.leap then
		VFX.Shockwave(to - Vector3.new(0, 2.5, 0), color, 12, 0.4)
	end
	SoundController.Play("Dash", from)
end

handlers.Buff = function(d)
	local root = rootOf(d.actor)
	if not root then
		return
	end
	local color = VFX.Color(d.element)
	VFX.Shockwave(root.Position - Vector3.new(0, 2.5, 0), color, d.radius or 8, 0.4)
	VFX.Flash(root.Position, color, 8, 0.3)
	VFX.emit("Wisp", root.Position, color, 25)
	SoundController.Play("Cast", root)
end

handlers.Pull = function(d)
	local root = rootOf(d.actor)
	if not root then
		return
	end
	local color = VFX.Color(d.element)
	local from = root.Position + Vector3.new(0, 1, 0)
	local to: Vector3 = d.endPoint
	local links = math.clamp(math.floor((to - from).Magnitude / 2), 2, 30)
	for i = 1, links do
		local p = from:Lerp(to, i / links)
		local link = VFX.neon(
			Vector3.new(0.5, 0.5, 1.2),
			CFrame.lookAt(p, to) * CFrame.Angles(0, 0, if i % 2 == 0 then math.rad(90) else 0),
			color,
			0.1
		)
		link.Material = Enum.Material.Metal
		VFX.tween(link, 0.5, { Transparency = 1 })
		task.delay(0.5, function()
			link:Destroy()
		end)
	end
	SoundController.Play("Slash", to)
end

handlers.Barrage = function(d)
	local model = d.actor
	local color = VFX.Color(d.element)
	task.spawn(function()
		for t = 1, d.ticks do
			local root = rootOf(model)
			if not root then
				break
			end
			local yaw = math.rad(rng:NextNumber(-d.angle / 2, d.angle / 2))
			local frame = CFrame.lookAt(root.Position, root.Position + d.direction)
				* CFrame.Angles(0, yaw, math.rad(rng:NextNumber(-70, 70)))
				* CFrame.new(0, 0.5, -d.range * 0.35)
			VFX.SlashArc(frame, color, d.range * 0.35, 0.35, 0.18, t % 2 == 0)
			if t % 2 == 1 then
				SoundController.Play("Slash", root, 0.6)
			end
			task.wait(d.interval)
		end
	end)
end

local CINEMATIC_TIER1 = {
	{ duration = 0.5, fromAngle = 180, toAngle = 150, distance = 7, height = 1.2, fov = 45, lookHeight = 2 },
	{ duration = 0.7, fromAngle = 40, toAngle = 10, distance = 11, distanceEnd = 15, height = 2, fov = 60 },
}
local CINEMATIC_TIER2 = {
	{ duration = 0.8, fromAngle = 200, toAngle = 160, distance = 6, height = 0.5, fov = 40, lookHeight = 2.5 },
	{ duration = 0.8, fromAngle = 90, toAngle = 40, distance = 14, height = 8, fov = 55 },
	{
		duration = 0.9,
		fromAngle = 0,
		toAngle = -20,
		distance = 12,
		distanceEnd = 20,
		height = 1,
		fov = 70,
		lookHeight = 3,
	},
}

handlers.TransformStart = function(d)
	local model = d.actor
	local root = rootOf(model)
	if not model or not root then
		return
	end
	local anim = if d.form == "Tier2" then "ReleaseTier2" else "ReleaseTier1"
	local poseDef = Poses[anim]
	AnimController.Play(model, anim, { speed = poseDef.duration / (d.channel + 0.4) })
	local color = VFX.Color(d.element)
	SoundController.Play("Release", root)
	VFX.Pillar(
		root.Position - Vector3.new(0, 3, 0),
		color,
		if d.form == "Tier2" then 6 else 3.5,
		if d.form == "Tier2" then 90 else 40,
		d.channel + 0.3
	)
	VFX.emit("Wisp", root.Position, color, 40)
	if isLocal(model) then
		local getSettings = FxController.Settings
		local settings = if getSettings then getSettings() else nil
		if not settings or settings.cinematics ~= "Off" then
			CameraController.PlayCinematic(root, if d.form == "Tier2" then CINEMATIC_TIER2 else CINEMATIC_TIER1)
		end
		FxController.ReleaseTitle:Fire(d)
	elseif nearLocal(root.Position, 80) then
		FxController.ReleaseTitle:Fire(d)
	end
end

handlers.TransformComplete = function(d)
	local root = rootOf(d.actor)
	if not root then
		return
	end
	local color = VFX.Color(d.element)
	VFX.Shockwave(root.Position - Vector3.new(0, 2.5, 0), color, if d.form == "Tier2" then 40 else 22, 0.7, 0.8)
	VFX.Flash(root.Position, color, if d.form == "Tier2" then 26 else 14, 0.5)
	VFX.Sparks(root.Position, color, 40)
	SoundController.Play(if d.form == "Tier2" then "Ultimate" else "Boom", root)
	if nearLocal(root.Position, 70) then
		CameraController.Shake(if d.form == "Tier2" then 0.8 else 0.45)
		VFX.ScreenFlash(color, 0.5, if isLocal(d.actor) then 0.55 else 0.25)
	end
end

handlers.TransformCancel = function(d)
	AnimController.StopAll(d.actor, 4, 0.05)
	local root = rootOf(d.actor)
	if root then
		VFX.Sparks(root.Position, Color3.fromRGB(180, 180, 200), 15)
	end
	if isLocal(d.actor) then
		CameraController.EndCinematic()
	end
end

handlers.Revert = function(d)
	AnimController.Play(d.actor, "Revert")
	local root = rootOf(d.actor)
	if root then
		VFX.Shockwave(root.Position - Vector3.new(0, 2.5, 0), Color3.fromRGB(200, 210, 230), 10, 0.4)
	end
end

handlers.MaskStart = function(d)
	AnimController.Play(d.actor, "MaskOn")
	local root = rootOf(d.actor)
	if root then
		VFX.emit("Wisp", root.Position + Vector3.new(0, 2, 0), Color3.fromRGB(220, 30, 50), 30)
	end
end

handlers.MaskOn = function(d)
	local root = rootOf(d.actor)
	if root then
		local red = Color3.fromRGB(220, 30, 50)
		VFX.Shockwave(root.Position - Vector3.new(0, 2.5, 0), red, 18, 0.5, 0.6)
		VFX.Flash(root.Position + Vector3.new(0, 2, 0), Color3.new(0, 0, 0), 10, 0.4)
		SoundController.Play("Boom", root)
		if isLocal(d.actor) then
			VFX.ScreenFlash(red, 0.4, 0.4)
			CameraController.Shake(0.4)
		end
	end
end

handlers.MaskOff = function(d)
	local root = rootOf(d.actor)
	if root then
		VFX.Sparks(root.Position + Vector3.new(0, 2, 0), Color3.new(1, 1, 1), 12)
	end
end

handlers.Death = function(d)
	local model = d.actor
	if not model then
		return
	end
	AnimController.StopAll(model, 0, 0.1)
	AnimController.Play(model, "Launched")
	local color = if d.team == "Enemies" then Color3.fromRGB(40, 30, 50) else Color3.fromRGB(200, 220, 255)
	task.delay(0.6, function()
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				VFX.tween(part, 1.2, { Transparency = 1 })
			end
		end
		local root = rootOf(model)
		if root then
			VFX.emit("Wisp", root.Position, color, 40)
		end
	end)
end

handlers.LevelUp = function(d)
	local root = rootOf(d.actor)
	if root then
		local gold = Color3.fromRGB(255, 210, 90)
		VFX.Pillar(root.Position - Vector3.new(0, 3, 0), gold, 3, 30, 1)
		VFX.emit("Wisp", root.Position, gold, 40)
		SoundController.Play("LevelUp", root)
	end
end

handlers.BossPhase = function(d)
	AnimController.StopAll(d.actor, 0, 0.05)
	AnimController.Play(d.actor, "UltimateRaise", { speed = 1.3 })
	local root = rootOf(d.actor)
	if root then
		local color = VFX.Color("Hollow")
		VFX.Shockwave(root.Position - Vector3.new(0, 2, 0), color, 25, 0.8, 1)
		VFX.Pillar(root.Position - Vector3.new(0, 3, 0), color, 8, 80, 1.4)
		SoundController.Play("Ultimate", root)
		if nearLocal(root.Position, 120) then
			CameraController.Shake(0.7)
			FxController.BossPhase:Fire(d)
		end
	end
end

handlers.Travel = function(d)
	if d.from then
		VFX.Pillar(d.from - Vector3.new(0, 3, 0), Color3.fromRGB(150, 210, 255), 3, 25, 0.6)
	end
end

handlers.UseItem = function(d)
	local root = rootOf(d.actor)
	if root then
		VFX.emit("Wisp", root.Position, Color3.fromRGB(120, 255, 160), 20)
	end
end

function FxController.Init() end

function FxController.Start()
	Net.event("Fx").OnClientEvent:Connect(function(kind, data)
		local handler = handlers[kind]
		if handler and type(data) == "table" then
			local ok, err = pcall(handler, data)
			if not ok then
				warn("[FxController]", kind, err)
			end
		end
	end)
end

return FxController

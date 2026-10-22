-- Transformações: Base → Tier1 (Shikai/Resurrección/...) → Tier2 (Bankai/...) e Máscara Hollow.
-- A ativação é uma canalização curta no servidor: tomar um golpe que atordoa a interrompe.
-- A cena cinematográfica é apenas local (câmera) e pode ser pulada sem afetar a jogabilidade.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Factions = require(Shared.Config.Factions)
local Powers = require(Shared.Config.Powers)
local Signal = require(Shared.Util.Signal)

local Registry = require(script.Parent.Parent.Registry)

local TransformationService = {}
TransformationService.Transformed = Signal.new() -- (actor, form)

local CombatService

local REQUIRED_REIATSU = { Tier1 = 30, Tier2 = 50 }
local INTERRUPT_COOLDOWN = 5
local EXHAUST_DELAY = 4

local function profileOf(actor)
	return actor.player and Registry.DataService.Get(actor.player) or nil
end

local function notify(actor, text: string, kind: string?)
	if actor.player then
		Registry.UIService.Notify(actor.player, text, kind or "warn")
	end
end

local function isUnlocked(actor, tier: string): boolean
	local profile = profileOf(actor)
	if not profile then
		return actor.enemyId ~= nil
	end
	local faction = Factions.get(actor.faction)
	if not faction then
		return false
	end
	return profile.unlocks[tier] == true and profile.level >= faction.forms[tier].requiredLevel
end

local function applyForm(actor, form: string)
	actor.form = form
	actor.model:SetAttribute("Form", form)
	if Registry.CharacterService then
		Registry.CharacterService.RefreshAppearance(actor)
	end
	CombatService.UpdateMovement(actor)
	TransformationService.Transformed:Fire(actor, form)
end

function TransformationService.Revert(actor, reason: string?)
	if actor.form == "Base" then
		return
	end
	applyForm(actor, "Base")
	CombatService.Broadcast("Revert", { actor = actor.model, reason = reason }, actor.root.Position)
	if reason == "exhausted" then
		actor.lastReiatsuUse = CombatService.now() + EXHAUST_DELAY
		notify(actor, "Reiatsu esgotado — sua liberação se desfez.")
	end
end

-- G: próxima forma disponível ou volta à base.
function TransformationService.RequestRelease(actor)
	if not CombatService.CanAct(actor, false) or actor.blocking then
		return
	end
	if not CombatService.CooldownReady(actor, "Transform") then
		return
	end
	local faction = Factions.get(actor.faction)
	if not faction then
		return
	end
	local nextForm: string? = nil
	if actor.form == "Base" then
		nextForm = if isUnlocked(actor, "Tier1") then "Tier1" else nil
		if not nextForm then
			notify(
				actor,
				faction.forms.Tier1.name
					.. ' ainda não foi despertado (missão "O Nome da Sua Alma", nível '
					.. faction.forms.Tier1.requiredLevel
					.. ")."
			)
			return
		end
	elseif actor.form == "Tier1" then
		nextForm = if isUnlocked(actor, "Tier2") then "Tier2" else nil
	end
	if not nextForm then
		TransformationService.Revert(actor, "manual")
		CombatService.SetCooldown(actor, "Transform", 1.5)
		return
	end
	if actor.reiatsu < REQUIRED_REIATSU[nextForm] then
		notify(actor, "Reiatsu insuficiente para liberar (" .. REQUIRED_REIATSU[nextForm] .. ").")
		return
	end

	local formDef = faction.forms[nextForm]
	local power = actor.power and Powers.get(actor.power)
	local tierDef = power and power.faction == actor.faction and power[if nextForm == "Tier1" then "tier1" else "tier2"]
		or nil
	local t = CombatService.now()
	local channelTime = formDef.channel
	local reveal = formDef.reveal or 0
	actor.token += 1
	actor.busyUntil = t + channelTime
	actor.cancelFrom = actor.busyUntil
	if formDef.cutscene then
		-- Cutscene de liberação: ninguém interrompe a cena (canalização + revelação)
		actor.iframeUntil = math.max(actor.iframeUntil, t + channelTime + reveal)
	end
	CombatService.SetDrawn(actor, true)

	local channel
	channel = {
		kind = nextForm,
		endsAt = t + channelTime,
		onCancel = function()
			CombatService.Broadcast("TransformCancel", { actor = actor.model }, actor.root.Position)
			CombatService.SetCooldown(actor, "Transform", INTERRUPT_COOLDOWN)
			notify(actor, "Liberação interrompida!")
		end,
		onComplete = function()
			CombatService.SpendReiatsu(actor, REQUIRED_REIATSU[nextForm] * 0.5)
			applyForm(actor, nextForm)
			actor.superArmorUntil = CombatService.now() + 0.4
			if reveal > 0 then
				-- Revelação: parado posando enquanto a cena termina
				CombatService.SetBusy(actor, reveal)
			end
			CombatService.Broadcast("TransformComplete", {
				actor = actor.model,
				form = nextForm,
				element = power and power.element or faction.element,
			}, actor.root.Position)
			CombatService.SetCooldown(actor, "Transform", 2)
		end,
	}
	actor.channel = channel
	CombatService.UpdateMovement(actor)
	CombatService.Broadcast("TransformStart", {
		actor = actor.model,
		form = nextForm,
		formName = formDef.name,
		formKanji = formDef.kanji,
		releaseName = tierDef and tierDef.name or formDef.name,
		command = power and power.releaseCommand or nil,
		element = power and power.element or faction.element,
		channel = channelTime,
		reveal = reveal,
		cutscene = formDef.cutscene == true,
		faction = actor.faction,
	}, actor.root.Position)
end

-- H: Máscara Hollow (Shinigami com desbloqueio).
function TransformationService.RequestMask(actor)
	local maskDef = Factions.Mask
	if actor.mask then
		TransformationService.SetMask(actor, false)
		return
	end
	local faction = Factions.get(actor.faction)
	if not faction or not faction.maskAvailable then
		return
	end
	local profile = profileOf(actor)
	if profile and (not profile.unlocks.Mask or profile.level < maskDef.requiredLevel) then
		notify(actor, 'A Máscara Hollow exige a missão "A Voz Interior" (nível ' .. maskDef.requiredLevel .. ").")
		return
	end
	if not CombatService.CanAct(actor, false) or not CombatService.CooldownReady(actor, "Mask") then
		return
	end
	local t = CombatService.now()
	actor.token += 1
	actor.busyUntil = t + maskDef.channel
	actor.cancelFrom = actor.busyUntil
	actor.channel = {
		kind = "Mask",
		endsAt = t + maskDef.channel,
		onCancel = function()
			CombatService.Broadcast("TransformCancel", { actor = actor.model }, actor.root.Position)
			CombatService.SetCooldown(actor, "Mask", INTERRUPT_COOLDOWN)
		end,
		onComplete = function()
			TransformationService.SetMask(actor, true)
		end,
	}
	CombatService.UpdateMovement(actor)
	CombatService.Broadcast("MaskStart", { actor = actor.model, channel = maskDef.channel }, actor.root.Position)
end

function TransformationService.SetMask(actor, enabled: boolean)
	if actor.mask == enabled then
		return
	end
	actor.mask = enabled
	actor.model:SetAttribute("Mask", enabled)
	if Registry.CharacterService then
		Registry.CharacterService.SetMaskVisual(actor, enabled)
	end
	if enabled then
		actor.extra.maskUntil = CombatService.now() + Factions.Mask.duration
		CombatService.Broadcast(
			"MaskOn",
			{ actor = actor.model, duration = Factions.Mask.duration },
			actor.root.Position
		)
	else
		actor.extra.maskUntil = nil
		CombatService.SetCooldown(actor, "Mask", Factions.Mask.cooldown)
		CombatService.Broadcast("MaskOff", { actor = actor.model }, actor.root.Position)
	end
	CombatService.UpdateMovement(actor)
end

-- Chamado pelo laço de 10 Hz do CombatService.
function TransformationService.Tick(actor, dt: number, t: number)
	local channel = actor.channel
	if channel and t >= channel.endsAt then
		actor.channel = nil
		actor.busyUntil = 0
		channel.onComplete()
		CombatService.UpdateMovement(actor)
	end
	if actor.form ~= "Base" then
		local faction = Factions.get(actor.faction)
		local drain = faction and faction.forms[actor.form] and faction.forms[actor.form].drainPerSecond or 2
		actor.reiatsu -= drain * actor.derived.drainMultiplier * dt
		if actor.reiatsu <= 0 then
			actor.reiatsu = 0
			TransformationService.Revert(actor, "exhausted")
		end
	end
	if actor.mask and actor.extra.maskUntil and t >= actor.extra.maskUntil then
		TransformationService.SetMask(actor, false)
	end
end

-- Usado ao morrer/renascer.
function TransformationService.Reset(actor)
	actor.channel = nil
	if actor.form ~= "Base" then
		actor.form = "Base"
		actor.model:SetAttribute("Form", "Base")
	end
	if actor.mask then
		actor.mask = false
		actor.model:SetAttribute("Mask", false)
	end
end

function TransformationService.Init()
	CombatService = Registry.CombatService
end

function TransformationService.Start() end

return TransformationService

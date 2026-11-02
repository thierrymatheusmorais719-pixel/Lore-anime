-- Interface de combate: equipe (vida, energia, habilidade com recarga), alvo, barra de boss,
-- aviso de ataque perigoso, faixas de fase/introdução e botões de toque para celular.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Pets = require(Shared.Config.Pets)
local Abilities = require(Shared.Config.Abilities)
local Combat = require(Shared.Config.Combat)
local Rarities = require(Shared.Config.Rarities)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)

local CombatHUD = {}
local T = UIKit.Theme
local player = Players.LocalPlayer

local gui
local slots = {}
local targetFrame, targetName, targetFill, targetText, targetStatus
local bossFrame, bossName, bossFill, bossText, bossPhase, bossWarn
local entityCache: { [number]: Model } = {}

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

local function petModel(uid: string): Model?
	local folder = workspace:FindFirstChild("Pets")
	local mine = folder and folder:FindFirstChild(tostring(player.UserId))
	return mine and mine:FindFirstChild("Pet_" .. uid) :: Model?
end

function CombatHUD.useAbility(slot: number)
	State.action("Ability", slot)
	local s = slots[slot]
	if s then
		s.button.BackgroundColor3 = Color3.fromRGB(90, 90, 140)
		task.delay(0.1, function()
			s.button.BackgroundColor3 = T.panel2
		end)
	end
end

local function buildSlot(parent, i)
	local f = UIKit.frame({ Size = UDim2.fromOffset(150, 92), BackgroundColor3 = T.bg, BackgroundTransparency = 0.2, Parent = parent })
	UIKit.stroke(f, T.stroke, 1.5, 0.3)
	local name = UIKit.label({ Position = UDim2.fromOffset(6, 2), Size = UDim2.new(1, -12, 0, 18), Text = "—", TextSize = 13, Font = T.bold, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = f })
	local hpBack, hpFill, hpText = UIKit.bar(f, { Position = UDim2.fromOffset(6, 21), Size = UDim2.new(1, -12, 0, 10), color = T.good, textSize = 10 })
	local enBack, enFill = UIKit.bar(f, { Position = UDim2.fromOffset(6, 33), Size = UDim2.new(1, -12, 0, 5), color = Color3.fromRGB(110, 170, 255) })
	local button = UIKit.button({ Position = UDim2.fromOffset(6, 42), Size = UDim2.new(1, -12, 0, 44), Text = "", Parent = f }, function()
		CombatHUD.useAbility(i)
	end)
	local icon = UIKit.label({ Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(30, 44), Text = "", TextSize = 22, Font = T.title, Parent = button })
	local label = UIKit.label({ Position = UDim2.fromOffset(36, 2), Size = UDim2.new(1, -40, 0, 22), Text = "", TextSize = 12, Font = T.bold, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = button })
	local sub = UIKit.label({ Position = UDim2.fromOffset(36, 22), Size = UDim2.new(1, -40, 0, 18), Text = "", TextSize = 11, TextColor3 = T.muted, Parent = button })
	local cd = UIKit.frame({ Name = "Cooldown", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4, radius = 8, ZIndex = 4, Parent = button })
	local cdText = UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 18, Font = T.title, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5, Parent = button })
	local key = UIKit.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 2), Size = UDim2.fromOffset(16, 16), Text = tostring(i), TextSize = 11, Font = T.bold,
		TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6, Visible = not UIKit.isMobile(), Parent = button })
	local knocked = UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "NOCAUTE", TextColor3 = T.bad, Font = T.title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0.4, BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 8, Parent = f })
	UIKit.corner(knocked, 10)
	return { frame = f, name = name, hpFill = hpFill, hpText = hpText, enFill = enFill, button = button, icon = icon, label = label, sub = sub, cd = cd, cdText = cdText, key = key, knocked = knocked, hpBack = hpBack, enBack = enBack }
end

local function findEntity(eid: number): Model?
	local m = entityCache[eid]
	if m and m.Parent then
		return m
	end
	for _, folderName in ipairs({ "Enemies", "Bosses" }) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, c in ipairs(folder:GetChildren()) do
				if c:GetAttribute("Entity") == eid then
					entityCache[eid] = c
					return c
				end
			end
		end
	end
	return nil
end

local function update()
	local p = State.profile
	local now = workspace:GetServerTimeNow()
	-- equipe
	for i = 1, Combat.TeamSize do
		local s = slots[i]
		local uid = p and p.team[i]
		local pet = uid and p.pets[uid]
		if not pet then
			s.frame.Visible = false
		else
			s.frame.Visible = true
			local sp = Pets.Species[pet.species]
			local a = Abilities.Info[sp.ability]
			s.name.Text = string.format('<font color="#%s">●</font> %s <font size="11">Nv %d</font>', Rarities.Info[sp.rarity].color:ToHex(), sp.name, pet.level)
			s.icon.Text = a.icon
			s.label.Text = a.label
			s.sub.Text = string.format("%d energia", a.cost)
			local m = petModel(uid)
			if m then
				local hp, maxHp = m:GetAttribute("Health") or 0, m:GetAttribute("MaxHealth") or 1
				local en, maxEn = m:GetAttribute("Energy") or 0, m:GetAttribute("MaxEnergy") or 1
				UIKit.setBar(s.hpFill, hp / maxHp)
				s.hpText.Text = string.format("%s/%s", UIKit.fmt(hp), UIKit.fmt(maxHp))
				UIKit.setBar(s.enFill, en / maxEn)
				local ready = m:GetAttribute("AbilityReadyAt") or 0
				local derived = State.derived and State.derived.petStats and State.derived.petStats[uid]
				local total = derived and derived.cooldown or a.cooldown
				local left = ready - now
				if left > 0 then
					s.cd.Size = UDim2.fromScale(1, math.clamp(left / total, 0, 1))
					s.cdText.Text = string.format("%.1f", left)
				else
					s.cd.Size = UDim2.fromScale(1, 0)
					s.cdText.Text = en < a.cost and "⚡" or ""
				end
				s.knocked.Visible = m:GetAttribute("Knocked") == true
			end
		end
	end
	-- alvo
	local eid = player:GetAttribute("Target") or 0
	local tm = eid > 0 and findEntity(eid)
	if tm and not tm:GetAttribute("BossId") then
		targetFrame.Visible = true
		targetName.Text = string.format("%s  <font size=\"12\">Nv %d</font>", tm:GetAttribute("DisplayName") or "?", tm:GetAttribute("Level") or 1)
		local hp, maxHp = tm:GetAttribute("Health") or 0, tm:GetAttribute("MaxHealth") or 1
		UIKit.setBar(targetFill, hp / maxHp)
		targetText.Text = string.format("%s / %s", UIKit.fmt(hp), UIKit.fmt(maxHp))
		local status = {}
		if (tm:GetAttribute("Marked") or 0) > now then
			table.insert(status, "◈ Marcado")
		end
		if (tm:GetAttribute("Sundered") or 0) > now then
			table.insert(status, "⚔ Defesa reduzida")
		end
		if (tm:GetAttribute("Snared") or 0) > now then
			table.insert(status, "✣ Preso")
		end
		if tm:GetAttribute("Evading") then
			table.insert(status, "↩ Voltando (invulnerável)")
		end
		targetStatus.Text = table.concat(status, "   ")
	else
		targetFrame.Visible = false
	end
	-- boss da arena em que o jogador está
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local bossModel
	local bf = workspace:FindFirstChild("Bosses")
	if root and bf then
		for _, b in ipairs(bf:GetChildren()) do
			local c, r = b:GetAttribute("ArenaCenter"), b:GetAttribute("ArenaRadius")
			if c and r and (((root :: BasePart).Position - c) * Vector3.new(1, 0, 1)).Magnitude <= r + 30 then
				bossModel = b
			end
		end
	end
	if bossModel then
		bossFrame.Visible = true
		local state = bossModel:GetAttribute("BossState") or "Dormant"
		bossName.Text = string.format("%s — <i>%s</i>", bossModel:GetAttribute("DisplayName") or "?", bossModel:GetAttribute("Title") or "")
		local hp, maxHp = bossModel:GetAttribute("Health") or 0, bossModel:GetAttribute("MaxHealth") or 1
		UIKit.setBar(bossFill, hp / maxHp, true)
		bossText.Text = string.format("%s / %s", UIKit.fmt(hp), UIKit.fmt(maxHp))
		local stateText = state == "Dormant" and "Entre na arena para desafiar" or state == "Intro" and "Despertando..." or state == "Transition" and "Mudando de fase (invulnerável)"
			or state == "Defeated" and "Derrotado!" or ""
		bossPhase.Text = string.format("Fase %d: %s   %s", bossModel:GetAttribute("Phase") or 1, bossModel:GetAttribute("PhaseLabel") or "", stateText)
		local windup = bossModel:GetAttribute("WindupEnd") or 0
		if windup > now and state == "Fight" then
			bossWarn.Visible = true
			bossWarn.Text = string.format("⚠ %s em %.1fs", bossModel:GetAttribute("AttackLabel") or "Ataque", windup - now)
		else
			bossWarn.Visible = false
		end
	else
		bossFrame.Visible = false
	end
end

local function banner(text: string, sub: string?, color: Color3?)
	local f = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(700, 110), BackgroundTransparency = 1, Parent = gui })
	local t1 = UIKit.label({ Size = UDim2.new(1, 0, 0, 64), Text = text, Font = T.title, TextSize = 48, TextColor3 = color or T.gold, TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.1, Parent = f })
	local t2 = UIKit.label({ Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 32), Text = sub or "", TextSize = 22, Font = T.bold, TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3, Parent = f })
	t1.TextTransparency = 1
	t2.TextTransparency = 1
	TweenService:Create(t1, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	TweenService:Create(t2, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	task.delay(2.6, function()
		TweenService:Create(t1, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(t2, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.6)
		f:Destroy()
	end)
end
CombatHUD.banner = banner

function CombatHUD.init()
	gui = UIKit.screen("CombatHUD", 4)
	local team = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(4 * 158, 92), BackgroundTransparency = 1, Parent = gui })
	UIKit.list(team, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	for i = 1, Combat.TeamSize do
		slots[i] = buildSlot(team, i)
	end
	-- alvo (acima da equipe, sem cobrir o centro)
	targetFrame = UIKit.frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -112), Size = UDim2.fromOffset(340, 58), BackgroundColor3 = T.bg, BackgroundTransparency = 0.2, Visible = false, Parent = gui })
	UIKit.stroke(targetFrame, T.bad, 1.5, 0.3)
	targetName = UIKit.label({ Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 20), Text = "", Font = T.title, TextSize = 16, Parent = targetFrame })
	local _, tf, tt = UIKit.bar(targetFrame, { Position = UDim2.fromOffset(8, 23), Size = UDim2.new(1, -16, 0, 14), color = Color3.fromRGB(230, 80, 80) })
	targetFill, targetText = tf, tt
	targetStatus = UIKit.label({ Position = UDim2.fromOffset(8, 38), Size = UDim2.new(1, -16, 0, 18), Text = "", TextSize = 12, TextColor3 = T.gold, Parent = targetFrame })
	-- boss
	bossFrame = UIKit.frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80), Size = UDim2.fromOffset(600, 74), BackgroundColor3 = T.bg, BackgroundTransparency = 0.15, Visible = false, Parent = gui })
	UIKit.stroke(bossFrame, Color3.fromRGB(200, 80, 255), 2, 0.2)
	bossName = UIKit.label({ Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -20, 0, 24), Text = "", Font = T.title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Parent = bossFrame })
	local _, bfill, btext = UIKit.bar(bossFrame, { Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 18), color = Color3.fromRGB(200, 60, 90), textSize = 13 })
	bossFill, bossText = bfill, btext
	bossPhase = UIKit.label({ Position = UDim2.fromOffset(10, 48), Size = UDim2.new(1, -20, 0, 20), Text = "", TextSize = 13, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = bossFrame })
	bossWarn = UIKit.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6), Size = UDim2.fromOffset(420, 30), Text = "", Visible = false, Font = T.title, TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 110, 90), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, Parent = bossFrame })
	-- celular: botão de ataque grande
	if UIKit.isMobile() then
		local atk = UIKit.button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -130), Size = UDim2.fromOffset(96, 96), Text = "⚔", TextSize = 40,
			BackgroundColor3 = Color3.fromRGB(150, 60, 60), Parent = gui }, function()
			State.action("Attack", nil)
		end)
		UIKit.corner(atk, 48)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for i, k in ipairs(KEYS) do
			if input.KeyCode == k then
				CombatHUD.useAbility(i)
			end
		end
	end)
	State.on("Phase", function(p)
		banner("FASE " .. p.phase, p.boss .. ": " .. p.label, p.color)
	end)
	State.on("BossIntro", function(p)
		banner(p.name, p.title .. (p.players > 1 and string.format(" — %d desafiantes", p.players) or ""), p.color)
	end)
	State.on("BossDefeated", function(p)
		banner("VITÓRIA!", p.name .. " derrotado" .. (p.firstTime and " — registrado no bestiário!" or ""), T.gold)
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			update()
		end
	end)
end

return CombatHUD

-- Interface de combate (estilo simulador): cartões da equipe com borda da raridade, botões de
-- habilidade coloridos por tipo com recarga, quadro do alvo, barra de boss com marcas de fase e
-- aviso de ataque pulsante, faixas grandes de fase/entrada/vitória e botão de ataque no celular.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Pets = require(Shared.Config.Pets)
local Abilities = require(Shared.Config.Abilities)
local Combat = require(Shared.Config.Combat)
local Rarities = require(Shared.Config.Rarities)
local Bosses = require(Shared.Config.Bosses)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)

local CombatHUD = {}
local T = UIKit.Theme
local new = UIKit.new
local player = Players.LocalPlayer

local gui
local slots = {}
local targetFrame, targetName, targetFill, targetText, targetStatus
local bossFrame, bossName, bossFill, bossText, bossPhase, bossWarn, bossPips, bossPipsFor
local entityCache: { [number]: Model } = {}

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
local KIND_COLOR = {
	damage = T.orange, aoe = T.red, aoe_target = T.pink, shield = T.blue, heal = T.green, buff = T.teal,
	debuff = T.purple, mark = T.yellow, control = Color3.fromRGB(110, 200, 70),
}

local function petModel(uid: string): Model?
	local folder = workspace:FindFirstChild("Pets")
	local mine = folder and folder:FindFirstChild(tostring(player.UserId))
	return mine and mine:FindFirstChild("Pet_" .. uid) :: Model?
end

function CombatHUD.useAbility(slot: number)
	State.action("Ability", slot)
	local s = slots[slot]
	if s then
		UIKit.pop(s.button, -0.12)
	end
end

local function buildSlot(parent, i)
	local f = UIKit.frame({ LayoutOrder = i, Size = UDim2.fromOffset(160, 108), BackgroundColor3 = T.bg2, Parent = parent })
	local stroke = UIKit.stroke(f, T.stroke, 4, 0)
	local name = UIKit.label({ Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -52, 0, 20), Text = "—", TextSize = 15, Font = T.title,
		TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = f })
	local lvl = UIKit.frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 5), Size = UDim2.fromOffset(42, 18), BackgroundColor3 = T.yellow, radius = 9, Parent = f })
	UIKit.stroke(lvl, UIKit.darken(T.yellow, 0.6), 2, 0)
	local lvlText = UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "Nv 1", Font = T.title, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeColor3 = UIKit.darken(T.yellow, 0.6), TextStrokeTransparency = 0, Parent = lvl })
	local _, hpFill, hpText = UIKit.bar(f, { Position = UDim2.fromOffset(8, 27), Size = UDim2.new(1, -16, 0, 14), color = T.good, textSize = 11 })
	local enBack, enFill = UIKit.bar(f, { Position = UDim2.fromOffset(8, 44), Size = UDim2.new(1, -16, 0, 7), color = Color3.fromRGB(90, 170, 255), radius = 4 })
	-- Fúria (ataque Assinatura): divide a linha com a energia quando a espécie tem Assinatura
	local furyBack, furyFill = UIKit.bar(f, { Name = "Fury", Position = UDim2.new(0.5, 2, 0, 44), Size = UDim2.new(0.5, -10, 0, 7), color = Color3.fromRGB(255, 196, 80), radius = 4 })
	furyBack.Visible = false
	local button = UIKit.button({ Position = UDim2.fromOffset(8, 55), Size = UDim2.new(1, -16, 0, 46), Text = "", Parent = f }, function()
		CombatHUD.useAbility(i)
	end)
	local icon = UIKit.label({ Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(34, 46), Text = "", TextSize = 28, Font = T.title, TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.2, ZIndex = 3, Parent = button })
	local label = UIKit.label({ Position = UDim2.fromOffset(38, 3), Size = UDim2.new(1, -42, 0, 22), Text = "", TextSize = 14, Font = T.title, TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeTransparency = 0.2, ZIndex = 3, Parent = button })
	local sub = UIKit.label({ Position = UDim2.fromOffset(38, 24), Size = UDim2.new(1, -42, 0, 16), Text = "", TextSize = 11, TextColor3 = Color3.fromRGB(240, 240, 255), ZIndex = 3, Parent = button })
	local cd = new("Frame", { Name = "Cooldown", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 5, Parent = button })
	UIKit.corner(cd, 10)
	local cdText = UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 24, Font = T.title, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0, ZIndex = 6, Parent = button })
	local key = UIKit.icon(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 2, 1, -4), Size = UDim2.fromOffset(24, 24), color = T.gray, Text = tostring(i), ZIndex = 8 })
	key.Visible = not UIKit.isMobile()
	local knocked = UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "💫 NOCAUTE", TextColor3 = T.bad, Font = T.title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0.3, BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 9, Parent = f })
	UIKit.corner(knocked, 12)
	return { frame = f, stroke = stroke, name = name, lvl = lvlText, hpFill = hpFill, hpText = hpText, enFill = enFill, enBack = enBack, furyBack = furyBack, furyFill = furyFill,
		button = button, icon = icon, label = label,
		sub = sub, cd = cd, cdText = cdText, knocked = knocked, ready = true, ability = nil }
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

-- Marcas de fase na barra do boss (posição = vida em que a fase começa).
local function buildPips(bossId: string)
	if bossPipsFor == bossId then
		return
	end
	bossPipsFor = bossId
	for _, c in ipairs(bossPips:GetChildren()) do
		c:Destroy()
	end
	local cfg = Bosses.Info[bossId]
	if not cfg then
		return
	end
	for i = 2, #cfg.phases do
		local at = cfg.phases[i].at
		local pip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(at, 0.5), Size = UDim2.new(0, 4, 1, 6), BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0, ZIndex = 4, Parent = bossPips })
		UIKit.stroke(pip, T.stroke, 2, 0)
	end
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
			local rar = Rarities.Info[sp.rarity]
			local a = Abilities.Info[sp.ability]
			s.name.Text = sp.name
			s.lvl.Text = "Nv " .. pet.level
			s.stroke.Color = UIKit.darken(rar.color, 0.35)
			if s.ability ~= sp.ability then
				s.ability = sp.ability
				UIKit.recolor(s.button, KIND_COLOR[a.kind] or T.blue)
			end
			s.icon.Text = a.icon
			s.label.Text = a.label
			s.sub.Text = string.format("⚡ %d energia", a.cost)
			local m = petModel(uid)
			if m then
				local hp, maxHp = m:GetAttribute("Health") or 0, m:GetAttribute("MaxHealth") or 1
				local en, maxEn = m:GetAttribute("Energy") or 0, m:GetAttribute("MaxEnergy") or 1
				UIKit.setBar(s.hpFill, hp / maxHp)
				s.hpText.Text = string.format("%s/%s", UIKit.fmt(hp), UIKit.fmt(maxHp))
				UIKit.setBar(s.enFill, en / maxEn)
				local furyMax = m:GetAttribute("FuryMax")
				local hasFury = typeof(furyMax) == "number" and furyMax > 0
				if hasFury ~= s.furyBack.Visible then
					s.furyBack.Visible = hasFury
					s.enBack.Size = hasFury and UDim2.new(0.5, -10, 0, 7) or UDim2.new(1, -16, 0, 7)
				end
				if hasFury then
					local fury = m:GetAttribute("Fury") or 0
					UIKit.setBar(s.furyFill, fury / furyMax)
					if fury >= furyMax and not s.furyFull then
						UIKit.pop(s.furyBack, 0.15) -- Assinatura pronta: sai no próximo golpe
					end
					s.furyFull = fury >= furyMax
				end
				local ready = m:GetAttribute("AbilityReadyAt") or 0
				local derived = State.derived and State.derived.petStats and State.derived.petStats[uid]
				local total = derived and derived.cooldown or a.cooldown
				local left = ready - now
				if left > 0 then
					s.cd.Size = UDim2.fromScale(1, math.clamp(left / total, 0, 1))
					s.cdText.Text = string.format("%.1f", left)
					s.ready = false
				else
					s.cd.Size = UDim2.fromScale(1, en < a.cost and 1 or 0)
					s.cdText.Text = en < a.cost and "⚡" or ""
					if not s.ready and en >= a.cost then
						UIKit.pop(s.button, 0.15) -- habilidade pronta de novo
					end
					s.ready = en >= a.cost
				end
				s.knocked.Visible = m:GetAttribute("Knocked") == true
			end
		end
	end
	-- alvo
	local eid = player:GetAttribute("Target") or 0
	local tm = eid > 0 and findEntity(eid)
	if tm and not tm:GetAttribute("BossId") then
		if not targetFrame.Visible then
			UIKit.pop(targetFrame, 0.1)
		end
		targetFrame.Visible = true
		targetName.Text = string.format('%s  <font color="#FFD040">Nv %d</font>', tm:GetAttribute("DisplayName") or "?", tm:GetAttribute("Level") or 1)
		local hp, maxHp = tm:GetAttribute("Health") or 0, tm:GetAttribute("MaxHealth") or 1
		UIKit.setBar(targetFill, hp / maxHp, true)
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
		if not bossFrame.Visible then
			UIKit.pop(bossFrame, 0.15)
		end
		bossFrame.Visible = true
		buildPips(bossModel:GetAttribute("BossId"))
		local state = bossModel:GetAttribute("BossState") or "Dormant"
		bossName.Text = string.format('💀 %s <font size="16" color="#D8C8FF">— %s</font>', bossModel:GetAttribute("DisplayName") or "?", bossModel:GetAttribute("Title") or "")
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
			bossWarn.TextColor3 = (math.floor(now * 6) % 2 == 0) and Color3.fromRGB(255, 90, 80) or Color3.fromRGB(255, 220, 90)
		else
			bossWarn.Visible = false
		end
	else
		bossFrame.Visible = false
	end
end

local function banner(text: string, sub: string?, color: Color3?)
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(760, 130), BackgroundTransparency = 1, Parent = gui })
	local sc = new("UIScale", { Scale = 0.3, Parent = f })
	local c = color or T.gold
	local t1 = UIKit.label({ Size = UDim2.new(1, 0, 0, 80), Text = text, Font = T.title, TextSize = 64, TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0, TextStrokeColor3 = UIKit.darken(c, 0.75), Parent = f })
	UIKit.gradient(t1, UIKit.lighten(c, 0.5), c)
	local t2 = UIKit.label({ Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 36), Text = sub or "", Font = T.title, TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.1, Parent = f })
	TweenService:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
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
	local team = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(4 * 170, 108), BackgroundTransparency = 1, Parent = gui })
	UIKit.list(team, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	for i = 1, Combat.TeamSize do
		slots[i] = buildSlot(team, i)
	end
	-- alvo (acima da equipe, sem cobrir o centro)
	targetFrame = UIKit.frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -132), Size = UDim2.fromOffset(380, 66), BackgroundColor3 = Color3.fromRGB(90, 30, 50), Visible = false, Parent = gui })
	UIKit.stroke(targetFrame, Color3.fromRGB(40, 8, 16), 4, 0)
	UIKit.icon(targetFrame, { Position = UDim2.fromOffset(-14, -10), Size = UDim2.fromOffset(44, 44), color = T.red, Text = "🎯", ZIndex = 4 })
	targetName = UIKit.label({ Position = UDim2.fromOffset(36, 3), Size = UDim2.new(1, -44, 0, 22), Text = "", Font = T.title, TextSize = 19, Parent = targetFrame })
	local _, tf, tt = UIKit.bar(targetFrame, { Position = UDim2.fromOffset(36, 26), Size = UDim2.new(1, -46, 0, 16), color = Color3.fromRGB(240, 70, 70) })
	targetFill, targetText = tf, tt
	targetStatus = UIKit.label({ Position = UDim2.fromOffset(36, 44), Size = UDim2.new(1, -44, 0, 18), Text = "", TextSize = 12, TextColor3 = T.gold, Parent = targetFrame })
	-- boss
	bossFrame = UIKit.frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104), Size = UDim2.fromOffset(660, 86), BackgroundColor3 = Color3.fromRGB(70, 24, 90), Visible = false, Parent = gui })
	UIKit.stroke(bossFrame, Color3.fromRGB(26, 6, 34), 4, 0)
	bossName = UIKit.label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 28), Text = "", Font = T.title, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.1, Parent = bossFrame })
	local bback, bfill, btext = UIKit.bar(bossFrame, { Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -28, 0, 24), color = Color3.fromRGB(240, 50, 90), textSize = 15, radius = 10 })
	bossFill, bossText = bfill, btext
	bossPips = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = bback })
	bossPhase = UIKit.label({ Position = UDim2.fromOffset(12, 60), Size = UDim2.new(1, -24, 0, 22), Text = "", Font = T.title, TextSize = 15, TextColor3 = Color3.fromRGB(230, 210, 255),
		TextXAlignment = Enum.TextXAlignment.Center, Parent = bossFrame })
	bossWarn = UIKit.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8), Size = UDim2.fromOffset(520, 36), Text = "", Visible = false, Font = T.title, TextSize = 28,
		TextColor3 = Color3.fromRGB(255, 90, 80), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0, Parent = bossFrame })
	-- celular: botão de ataque grande
	if UIKit.isMobile() then
		local atk = UIKit.button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -140), Size = UDim2.fromOffset(104, 104), Text = "⚔", TextSize = 46,
			BackgroundColor3 = T.red, Parent = gui }, function()
			State.action("Attack", nil)
		end)
		UIKit.corner(atk, 52)
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

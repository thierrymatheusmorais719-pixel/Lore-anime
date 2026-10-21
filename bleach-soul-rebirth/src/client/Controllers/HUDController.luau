-- HUD: vida, Reiatsu, XP/nível, indicador de forma (Shikai/Bankai/Máscara), barra de habilidades
-- com recargas, contador de combo, avisos, título de liberação, barra de chefe, missão rastreada,
-- botões de toque (celular) e placas de nome sobre inimigos/NPCs.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Abilities = require(Shared.Config.Abilities)
local Factions = require(Shared.Config.Factions)
local Powers = require(Shared.Config.Powers)
local Progression = require(Shared.Config.Progression)
local Quests = require(Shared.Config.Quests)
local Items = require(Shared.Config.Items)
local Elements = require(Shared.Config.Elements)
local Net = require(Shared.Net)

local Controllers = script.Parent
local Kit = require(script.Parent.Parent.UI.Kit)
local InputController = require(Controllers.InputController)
local CombatController = require(Controllers.CombatController)
local DataController = require(Controllers.DataController)
local FxController = require(Controllers.FxController)
local SoundController = require(Controllers.SoundController)

local HUDController = {}

local T = Kit.Theme
local player = Players.LocalPlayer
local gui: ScreenGui
local bars: { [string]: any } = {}
local refs: { [string]: any } = {}
local slotFrames: { [string]: any } = {}

local KEY_LABELS = {
	Keyboard = {
		Z = "Z",
		X = "X",
		C = "C",
		V = "V",
		Heavy = "E",
		Launcher = "R",
		Dash = "Q",
		Transform = "G",
		Mask = "H",
	},
	Gamepad = {
		Z = "◀",
		X = "▲",
		C = "▶",
		V = "▼",
		Heavy = "R1",
		Launcher = "X",
		Dash = "B",
		Transform = "L1",
		Mask = "Y",
	},
	Touch = { Z = "", X = "", C = "", V = "", Heavy = "", Launcher = "", Dash = "", Transform = "", Mask = "" },
}

-- ============================================================
-- Avisos (toasts)
-- ============================================================
local NOTIFY_COLORS = {
	info = T.Text,
	warn = Color3.fromRGB(255, 190, 110),
	xp = Color3.fromRGB(170, 220, 255),
	level = T.Gold,
	loot = Color3.fromRGB(220, 220, 230),
	kan = Color3.fromRGB(255, 225, 140),
	quest = Color3.fromRGB(160, 230, 255),
	questDone = T.Success,
	awaken = T.Gold,
	discover = Color3.fromRGB(150, 210, 255),
}

function HUDController.Notify(text: string, kind: string?, extra: any?)
	local list = refs.toasts
	if not list then
		return
	end
	local color = NOTIFY_COLORS[kind or "info"] or T.Text
	if extra and extra.rarity and Items.Rarities[extra.rarity] then
		color = Items.Rarities[extra.rarity].color
	end
	local big = kind == "level" or kind == "awaken"
	local toast = Kit.new("Frame", {
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromOffset(if big then 420 else 320, if big then 46 else 30),
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = list,
	}, {
		Kit.corner(6),
		Kit.new(
			"Frame",
			{ BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 0) },
			{ Kit.corner(2) }
		),
	})
	local label = Kit.label(text, if big then 22 else 15, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -16, 1, 0),
		TextColor3 = color,
		Font = if big then T.FontTitle else T.FontBold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextTransparency = 1,
		Parent = toast,
	})
	Kit.tween(label, 0.2, { TextTransparency = 0 })
	if kind == "level" or kind == "awaken" then
		SoundController.Play("LevelUp")
	end
	task.delay(if big then 4.5 else 3, function()
		Kit.tween(toast, 0.3, { BackgroundTransparency = 1 })
		Kit.tween(label, 0.3, { TextTransparency = 1 })
		task.wait(0.32)
		toast:Destroy()
	end)
	local children = list:GetChildren()
	local frames = 0
	for _, c in children do
		if c:IsA("Frame") then
			frames += 1
		end
	end
	if frames > 7 then
		local oldest, order = nil, math.huge
		for _, c in children do
			if c:IsA("Frame") and -c.LayoutOrder < order then
				oldest, order = c, -c.LayoutOrder
			end
		end
		if oldest then
			oldest:Destroy()
		end
	end
end

-- ============================================================
-- Construção
-- ============================================================
local function buildStatus()
	local root = Kit.new("Frame", {
		Name = "Status",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -24),
		Size = UDim2.fromOffset(380, 110),
		Parent = gui,
	})
	-- Emblema de nível
	local badge = Kit.new("Frame", {
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromOffset(74, 74),
		Position = UDim2.fromOffset(0, 18),
		Parent = root,
	}, { Kit.new("UICorner", { CornerRadius = UDim.new(1, 0) }), Kit.stroke(T.Accent, 2.5, 0.1) })
	refs.badgeStroke = badge:FindFirstChildOfClass("UIStroke")
	refs.kanji = Kit.label("霊", 30, {
		Size = UDim2.new(1, 0, 0.62, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontTitle,
		Parent = badge,
	})
	refs.level = Kit.label("Nv 1", 14, {
		Position = UDim2.fromScale(0, 0.58),
		Size = UDim2.new(1, 0, 0.35, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = T.Gold,
		Parent = badge,
	})

	refs.name = Kit.label(player.DisplayName, 16, {
		Position = UDim2.fromOffset(86, 4),
		Size = UDim2.fromOffset(200, 20),
		Font = T.FontTitle,
		TextStrokeTransparency = 0.6,
		Parent = root,
	})
	refs.form = Kit.label("", 14, {
		Position = UDim2.fromOffset(200, 4),
		Size = UDim2.fromOffset(180, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = T.FontTitle,
		TextColor3 = T.Gold,
		TextStrokeTransparency = 0.5,
		Parent = root,
	})

	bars.health =
		Kit.bar({ Position = UDim2.fromOffset(86, 28), Size = UDim2.fromOffset(294, 18), Parent = root }, T.Health, 18)
	bars.reiatsu =
		Kit.bar({ Position = UDim2.fromOffset(86, 52), Size = UDim2.fromOffset(260, 14), Parent = root }, T.Accent, 14)
	bars.guard = Kit.bar(
		{ Position = UDim2.fromOffset(86, 70), Size = UDim2.fromOffset(140, 6), Parent = root },
		Color3.fromRGB(230, 230, 240),
		6
	)
	bars.xp =
		Kit.bar({ Position = UDim2.fromOffset(86, 82), Size = UDim2.fromOffset(294, 6), Parent = root }, T.Gold, 6)
	refs.currency = Kit.label("", 13, {
		Position = UDim2.fromOffset(232, 66),
		Size = UDim2.fromOffset(148, 14),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = T.Muted,
		Parent = root,
	})
end

local function makeSlot(parent: Instance, key: string, size: number, order: number)
	local frame = Kit.new("Frame", {
		Name = key,
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.corner(10), Kit.stroke(Color3.new(1, 1, 1), 1.5, 0.7) })
	local icon = Kit.label("", size * 0.48, {
		Size = UDim2.fromScale(1, 0.8),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontTitle,
		Parent = frame,
	})
	local shade = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		ZIndex = 2,
		Parent = frame,
	}, { Kit.corner(10) })
	local timer = Kit.label("", size * 0.32, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontTitle,
		ZIndex = 3,
		TextStrokeTransparency = 0.3,
		Parent = frame,
	})
	local keyLabel = Kit.label(key, 12, {
		Position = UDim2.new(0, 5, 1, -16),
		Size = UDim2.fromOffset(30, 14),
		TextColor3 = T.Muted,
		ZIndex = 3,
		Parent = frame,
	})
	local name = Kit.label("", 11, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 3),
		Size = UDim2.fromOffset(size + 30, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = T.Muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	slotFrames[key] = {
		frame = frame,
		icon = icon,
		shade = shade,
		timer = timer,
		key = keyLabel,
		name = name,
		stroke = frame:FindFirstChildOfClass("UIStroke"),
	}
end

local function buildSkillBar()
	local bar = Kit.new("Frame", {
		Name = "SkillBar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(520, 70),
		Parent = gui,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	refs.skillBar = bar
	makeSlot(bar, "Dash", 46, 1)
	makeSlot(bar, "Heavy", 46, 2)
	makeSlot(bar, "Launcher", 46, 3)
	makeSlot(bar, "Z", 62, 4)
	makeSlot(bar, "X", 62, 5)
	makeSlot(bar, "C", 62, 6)
	makeSlot(bar, "V", 62, 7)
	makeSlot(bar, "Transform", 46, 8)
	slotFrames.Dash.icon.Text = "瞬"
	slotFrames.Heavy.icon.Text = "重"
	slotFrames.Launcher.icon.Text = "昇"
	slotFrames.Transform.icon.Text = "解"
end

local function buildCombo()
	local holder = Kit.new("Frame", {
		Name = "Combo",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.42, 0),
		Size = UDim2.fromOffset(220, 120),
		Parent = gui,
	})
	refs.comboCount = Kit.label("", 84, {
		Size = UDim2.new(1, 0, 0, 84),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = T.FontAnime,
		TextColor3 = T.Gold,
		TextStrokeTransparency = 0,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.fromRGB(40, 10, 0),
		Parent = holder,
	})
	refs.comboText = Kit.label("HITS", 26, {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = T.FontAnime,
		TextTransparency = 1,
		TextStrokeTransparency = 0.2,
		Parent = holder,
	})
	refs.comboScale = Kit.new("UIScale", { Parent = holder })
end

local function buildCenter()
	refs.toasts = Kit.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(440, 300),
		Parent = gui,
	}, {
		Kit.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Título de liberação (Shikai/Bankai...)
	local title = Kit.new("Frame", {
		Name = "ReleaseTitle",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(800, 220),
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	refs.releaseKanji = Kit.label("", 110, {
		Size = UDim2.new(1, 0, 0, 120),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontTitle,
		TextStrokeTransparency = 0,
		ZIndex = 10,
		Parent = title,
	})
	refs.releaseName = Kit.label("", 40, {
		Position = UDim2.fromOffset(0, 118),
		Size = UDim2.new(1, 0, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontAnime,
		TextStrokeTransparency = 0,
		ZIndex = 10,
		Parent = title,
	})
	refs.releaseCommand = Kit.label("", 20, {
		Position = UDim2.fromOffset(0, 166),
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontBold,
		TextColor3 = T.Muted,
		TextStrokeTransparency = 0.4,
		ZIndex = 10,
		Parent = title,
	})
	refs.releaseTitle = title

	-- Popup de parry
	refs.parry = Kit.label("PARRY!", 64, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(400, 70),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontAnime,
		TextColor3 = Color3.fromRGB(255, 240, 180),
		TextStrokeTransparency = 0,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.fromRGB(80, 50, 0),
		Parent = gui,
	})

	-- Barra de chefe
	local boss = Kit.new("Frame", {
		Name = "BossBar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(560, 48),
		Visible = false,
		Parent = gui,
	})
	refs.bossName = Kit.label("", 18, {
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontTitle,
		TextStrokeTransparency = 0.4,
		Parent = boss,
	})
	bars.boss = Kit.bar(
		{ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 16), Parent = boss },
		Color3.fromRGB(170, 40, 60),
		16
	)
	refs.bossBar = boss

	-- Missão rastreada
	local quest = Kit.new("Frame", {
		Name = "Quest",
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.35,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 70),
		Size = UDim2.fromOffset(280, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	}, {
		Kit.corner(8),
		Kit.padding(10),
		Kit.new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.quest = quest
end

-- ============================================================
-- Botões de toque
-- ============================================================
local function touchButton(
	parent: Instance,
	action: string,
	text: string,
	size: number,
	position: UDim2,
	color: Color3?
)
	local button = Kit.new("TextButton", {
		Name = action,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color or T.Background,
		BackgroundTransparency = 0.35,
		Text = text,
		TextSize = size * 0.36,
		Font = T.FontTitle,
		TextColor3 = T.Text,
		AutoButtonColor = false,
		Parent = parent,
	}, { Kit.new("UICorner", { CornerRadius = UDim.new(1, 0) }), Kit.stroke(Color3.new(1, 1, 1), 2, 0.5) })
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			button.BackgroundTransparency = 0.1
			InputController.Fire(action, true)
		end
	end)
	button.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			button.BackgroundTransparency = 0.35
			InputController.Fire(action, false)
		end
	end)
	return button
end

local function buildTouch()
	local pad = Kit.new("Frame", {
		Name = "TouchControls",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(330, 300),
		Visible = InputController.Mode() == "Touch",
		Parent = gui,
	})
	touchButton(pad, "Attack", "斬", 96, UDim2.fromOffset(250, 220), Color3.fromRGB(80, 20, 30))
	touchButton(pad, "Block", "防", 62, UDim2.fromOffset(150, 250))
	touchButton(pad, "Dash", "瞬", 62, UDim2.fromOffset(260, 120))
	touchButton(pad, "Heavy", "重", 54, UDim2.fromOffset(160, 170))
	touchButton(pad, "Launcher", "昇", 54, UDim2.fromOffset(190, 110))
	touchButton(pad, "Z", "Z", 54, UDim2.fromOffset(60, 250))
	touchButton(pad, "X", "X", 54, UDim2.fromOffset(70, 185))
	touchButton(pad, "C", "C", 54, UDim2.fromOffset(105, 125))
	touchButton(pad, "V", "V", 54, UDim2.fromOffset(165, 60))
	touchButton(pad, "Transform", "解", 50, UDim2.fromOffset(250, 40), Color3.fromRGB(90, 70, 20))
	touchButton(pad, "Charge", "気", 46, UDim2.fromOffset(310, 40))
	touchButton(pad, "Mask", "仮", 46, UDim2.fromOffset(310, 100))
	refs.touch = pad
	InputController.ModeChanged:Connect(function(mode)
		pad.Visible = mode == "Touch"
		HUDController.RefreshSlots()
	end)
end

-- ============================================================
-- Atualizações
-- ============================================================
local combo = { count = 0, last = 0 }

local function onLocalHit()
	local now = os.clock()
	if now - combo.last > 2 then
		combo.count = 0
	end
	combo.count += 1
	combo.last = now
	refs.comboCount.Text = tostring(combo.count)
	refs.comboText.Text = if combo.count >= 20
		then "HITS · BRUTAL!"
		elseif combo.count >= 10 then "HITS · INCRÍVEL!"
		else "HITS"
	refs.comboCount.TextTransparency = 0
	refs.comboText.TextTransparency = 0
	refs.comboScale.Scale = 1.35
	Kit.tween(refs.comboScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
end

function HUDController.RefreshSlots()
	local slots = CombatController.Slots()
	local labels = KEY_LABELS[InputController.Mode()] or KEY_LABELS.Keyboard
	local character = player.Character
	local element = "Reiatsu"
	if character then
		local power = Powers.get(character:GetAttribute("Power"))
		if power and character:GetAttribute("Form") ~= "Base" then
			element = power.element
		else
			local faction = Factions.get(character:GetAttribute("Faction"))
			element = faction and faction.element or "Reiatsu"
		end
	end
	local color = (Elements[element] or Elements.Reiatsu).primary
	for _, key in { "Z", "X", "C", "V" } do
		local slot = slotFrames[key]
		local def = slots[key] and Abilities[slots[key]]
		slot.icon.Text = def and def.kanji or "—"
		slot.icon.TextColor3 = if def then color else T.Muted
		slot.name.Text = def and def.name or (if key == "V" then "Requer Tier 2" else "")
		slot.frame.BackgroundTransparency = if def then 0.15 else 0.6
		if slot.stroke then
			slot.stroke.Color = if def and def.ultimate then T.Gold else Color3.new(1, 1, 1)
		end
	end
	for key, slot in slotFrames do
		slot.key.Text = labels[key] or key
	end
	slotFrames.Transform.icon.TextColor3 = color
end

local function updateQuest(profile)
	local frame = refs.quest
	for _, c in frame:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local id = profile.quests.tracked
	local entry = id and profile.quests.active[id]
	local quest = id and Quests.Story[id]
	if not entry or not quest then
		frame.Visible = false
		return
	end
	frame.Visible = true
	Kit.label(
		quest.name,
		16,
		{ Size = UDim2.new(1, 0, 0, 20), Font = T.FontTitle, TextColor3 = T.Gold, LayoutOrder = 0, Parent = frame }
	)
	for i, objective in quest.objectives do
		local current = entry.progress[i] or 0
		local target = objective.count or 1
		local done = current >= target
		Kit.label(
			(if done then "✔ " else "• ")
				.. objective.label
				.. (if target > 1 then string.format(" (%d/%d)", current, target) else ""),
			14,
			{
				Size = UDim2.new(1, 0, 0, 18),
				TextColor3 = if done then T.Success else T.Text,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = i,
				Parent = frame,
			}
		)
	end
end

local function onProfile(profile)
	if not profile then
		return
	end
	local need = Progression.xpToNext(profile.level)
	bars.xp.set(profile.xp, need, "")
	refs.level.Text = "Nv " .. profile.level
	refs.currency.Text = string.format("%d Kan · %d ✦", profile.currency.Kan, profile.currency.Shards)
	local faction = Factions.get(profile.faction)
	if faction then
		refs.kanji.Text = faction.kanji:sub(1, 3)
		refs.kanji.TextColor3 = faction.color
		if refs.badgeStroke then
			refs.badgeStroke.Color = faction.color
		end
		bars.reiatsu.color(faction.color)
	end
	updateQuest(profile)
	HUDController.RefreshSlots()
end

local function showReleaseTitle(d)
	local title = refs.releaseTitle
	local color = (Elements[d.element] or Elements.Reiatsu).primary
	refs.releaseKanji.Text = d.formKanji or ""
	refs.releaseKanji.TextColor3 = color
	refs.releaseName.Text = string.upper(d.formName or "")
		.. (if d.releaseName and d.releaseName ~= d.formName then " · " .. d.releaseName else "")
	refs.releaseCommand.Text = if d.command then "\u{201C}" .. d.command .. "\u{201D}" else ""
	title.Visible = true
	for _, label in { refs.releaseKanji, refs.releaseName, refs.releaseCommand } do
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
	end
	refs.releaseKanji.Position = UDim2.fromOffset(0, -30)
	Kit.tween(
		refs.releaseKanji,
		0.4,
		{ TextTransparency = 0, TextStrokeTransparency = 0, Position = UDim2.fromOffset(0, 0) },
		Enum.EasingStyle.Back
	)
	task.delay(0.2, function()
		Kit.tween(refs.releaseName, 0.3, { TextTransparency = 0, TextStrokeTransparency = 0 })
		Kit.tween(refs.releaseCommand, 0.3, { TextTransparency = 0, TextStrokeTransparency = 0.4 })
	end)
	task.delay(math.max(1.6, (d.channel or 1) + 1), function()
		for _, label in { refs.releaseKanji, refs.releaseName, refs.releaseCommand } do
			Kit.tween(label, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
		task.wait(0.45)
		title.Visible = false
	end)
end

local function showBanner(text: string)
	local label = Kit.label(text, 34, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromOffset(800, 50),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontAnime,
		TextColor3 = Color3.fromRGB(255, 120, 120),
		TextStrokeTransparency = 0,
		TextTransparency = 1,
		Parent = gui,
	})
	Kit.tween(label, 0.3, { TextTransparency = 0 })
	task.delay(2.5, function()
		Kit.tween(label, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
		task.wait(0.55)
		label:Destroy()
	end)
end
HUDController.Banner = showBanner

-- Placas de nome (inimigos com vida, NPCs com título)
local plates: { [Model]: { gui: BillboardGui, bar: any?, humanoid: Humanoid? } } = {}
local function attachPlate(model: Model)
	if plates[model] or not model:IsA("Model") then
		return
	end
	local head = model:WaitForChild("Head", 5) :: BasePart?
	if not head then
		return
	end
	local isNpc = model:GetAttribute("NPC") == true
	local billboard = Kit.new("BillboardGui", {
		Size = UDim2.fromOffset(200, if isNpc then 40 else 34),
		StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y + 1.2, 0),
		MaxDistance = if isNpc then 60 else 90,
		AlwaysOnTop = false,
		LightInfluence = 0,
		Adornee = head,
		Parent = gui,
	})
	local name = model:GetAttribute("DisplayName") or model.Name
	local level = model:GetAttribute("Level")
	Kit.label(if level and not isNpc then string.format("%s  ·  Nv %d", name, level) else name, 14, {
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontTitle,
		TextStrokeTransparency = 0.4,
		TextColor3 = if isNpc
			then Color3.fromRGB(255, 230, 160)
			elseif model:GetAttribute("Boss") then Color3.fromRGB(255, 120, 120)
			else T.Text,
		Parent = billboard,
	})
	local entry: { gui: BillboardGui, bar: any?, humanoid: Humanoid? } = { gui = billboard, bar = nil, humanoid = nil }
	if isNpc then
		Kit.label(tostring(model:GetAttribute("Title") or ""), 12, {
			Position = UDim2.fromOffset(0, 18),
			Size = UDim2.new(1, 0, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = T.Muted,
			TextStrokeTransparency = 0.5,
			Parent = billboard,
		})
	else
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		entry.humanoid = humanoid
		entry.bar = Kit.bar(
			{ Position = UDim2.fromOffset(30, 20), Size = UDim2.new(1, -60, 0, 8), Parent = billboard },
			T.Health,
			8
		)
	end
	plates[model] = entry
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			billboard:Destroy()
			plates[model] = nil
		end
	end)
end

function HUDController.Init()
	gui = Kit.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Kit.autoScale(gui)
	buildStatus()
	buildSkillBar()
	buildCombo()
	buildCenter()
	buildTouch()
	gui.Enabled = false
end

function HUDController.SetVisible(visible: boolean)
	gui.Enabled = visible
end

function HUDController.Start()
	DataController.Changed:Connect(onProfile)
	FxController.LocalHit:Connect(onLocalHit)
	FxController.ReleaseTitle:Connect(showReleaseTitle)
	FxController.BossPhase:Connect(function(d)
		showBanner(d.title or "Nova fase!")
	end)
	FxController.LocalParry:Connect(function()
		refs.parry.TextTransparency = 0
		refs.parry.TextStrokeTransparency = 0
		refs.parry.Size = UDim2.fromOffset(520, 90)
		Kit.tween(refs.parry, 0.2, { Size = UDim2.fromOffset(400, 70) }, Enum.EasingStyle.Back)
		task.delay(0.6, function()
			Kit.tween(refs.parry, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end)
	end)
	Net.event("Notify").OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			HUDController.Notify(tostring(data.text), data.kind, data.extra)
		end
	end)

	for _, folderName in { "Enemies", "Bosses", "NPCs" } do
		task.spawn(function()
			local folder = workspace:WaitForChild(folderName)
			for _, m in folder:GetChildren() do
				task.spawn(attachPlate, m)
			end
			folder.ChildAdded:Connect(function(m)
				task.spawn(attachPlate, m :: Model)
			end)
		end)
	end

	local function onCharacter(character: Model)
		for _, attr in { "Form", "Mask", "Power", "Faction" } do
			character:GetAttributeChangedSignal(attr):Connect(HUDController.RefreshSlots)
		end
		HUDController.RefreshSlots()
		gui.Enabled = true
	end
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	-- Atualização a ~20 Hz (barras, recargas, combo, chefe, placas)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.05 then
			return
		end
		accumulator = 0
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid then
			bars.health.set(
				humanoid.Health,
				humanoid.MaxHealth,
				string.format("%d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth)
			)
			local r, maxR = character:GetAttribute("Reiatsu") or 0, character:GetAttribute("MaxReiatsu") or 100
			bars.reiatsu.set(r, maxR, string.format("霊 %d", r))
			bars.guard.set(character:GetAttribute("Guard") or 100, 100, "")
			local form = character:GetAttribute("Form")
			local faction = Factions.get(character:GetAttribute("Faction"))
			local formText = ""
			if faction and (form == "Tier1" or form == "Tier2") then
				formText = faction.forms[form].kanji .. " " .. string.upper(faction.forms[form].name)
			end
			if character:GetAttribute("Mask") then
				formText = formText .. "  仮面"
			end
			refs.form.Text = formText
		end
		-- Recargas
		local slotsMap = {
			Dash = "Dash",
			Heavy = "Heavy",
			Launcher = "Launcher",
			Transform = "Transform",
			Z = "Slot:Z",
			X = "Slot:X",
			C = "Slot:C",
			V = "Slot:V",
		}
		for key, cdKey in slotsMap do
			local slot = slotFrames[key]
			local remaining, total = CombatController.CooldownRemaining(cdKey)
			if remaining > 0 then
				slot.shade.Size = UDim2.fromScale(1, math.clamp(remaining / math.max(total, 0.01), 0, 1))
				slot.timer.Text = if remaining >= 1
					then tostring(math.ceil(remaining))
					else string.format("%.1f", remaining)
			else
				slot.shade.Size = UDim2.fromScale(1, 0)
				slot.timer.Text = ""
			end
		end
		-- Combo some após 2s sem acertos
		if combo.count > 0 and os.clock() - combo.last > 2 then
			combo.count = 0
			Kit.tween(refs.comboCount, 0.3, { TextTransparency = 1 })
			Kit.tween(refs.comboText, 0.3, { TextTransparency = 1 })
		end
		-- Chefe próximo
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local bossFolder = workspace:FindFirstChild("Bosses")
		local shown = false
		if root and bossFolder then
			for _, boss in bossFolder:GetChildren() do
				local bh = boss:FindFirstChildOfClass("Humanoid")
				local br = boss:FindFirstChild("HumanoidRootPart") :: BasePart?
				if bh and br and bh.Health > 0 and (br.Position - root.Position).Magnitude < 120 then
					shown = true
					refs.bossName.Text = string.format(
						"%s  —  Fase %d",
						boss:GetAttribute("DisplayName") or boss.Name,
						boss:GetAttribute("Phase") or 1
					)
					bars.boss.set(bh.Health, bh.MaxHealth, string.format("%d / %d", math.ceil(bh.Health), bh.MaxHealth))
					break
				end
			end
		end
		refs.bossBar.Visible = shown
		-- Placas
		for _, plate in plates do
			if plate.bar and plate.humanoid then
				plate.bar.set(plate.humanoid.Health, plate.humanoid.MaxHealth, "")
			end
		end
	end)
end

return HUDController

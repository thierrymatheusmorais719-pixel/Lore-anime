-- HUD principal (estilo simulador): pílulas de recursos com ícone e "pop" ao ganhar,
-- selo de sorte com brilho, menu de botões coloridos, cartão de missão, notificações que deslizam,
-- feed de drops com ícones e anúncios de descobertas raras.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Quests = require(Shared.Config.Quests)
local Rarities = require(Shared.Config.Rarities)
local LuckConfig = require(Shared.Config.Luck)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)

local HUD = {}
local T = UIKit.Theme
local new = UIKit.new

local gui
local currency = {} -- id -> { label, pill, value }
local luckText, eventBanner
local questTitle, questDesc, questFill, questText, questClaim
local toastHolder, feedHolder, announceHolder
local menuDots = {}
HUD.rewardHistory = {} -- últimas recompensas recebidas (sessão)
HUD.openPanel = nil -- definido pelo Panels

local CURRENCY_STYLE = {
	coins = { color = Color3.fromRGB(255, 196, 40), icon = "🪙" },
	essence = { color = Color3.fromRGB(40, 210, 180), icon = "💎" },
	astral = { color = Color3.fromRGB(160, 110, 255), icon = "✦" },
}

local function tween(obj, time, goal, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function itemLabel(id: string, amount: number, extra)
	if id == "luck" then
		return string.format("+%d%% sorte (%s) por %s", math.floor(amount * 100 + 0.5), LuckConfig.CategoryLabels[extra.category] or "tudo", UIKit.time(extra.duration or 0))
	end
	local sp = id:match("^pet:(.+)$")
	if sp then
		return "Pet: " .. sp
	end
	return string.format("%s x%s", Items.label(id), UIKit.fmt(amount))
end

local function itemColor(id: string): Color3
	if id == "luck" then
		return T.luck
	end
	local c = Items.Currencies[id]
	if c then
		return CURRENCY_STYLE[id].color
	end
	local i = Items.Info[id]
	return i and i.color or T.gold
end

local function itemIcon(id: string): string
	if CURRENCY_STYLE[id] then
		return CURRENCY_STYLE[id].icon
	end
	if id == "luck" then
		return "🍀"
	end
	local i = Items.Info[id]
	local kind = i and i.kind
	return kind == "potion" and "🧪" or kind == "egg" and "🥚" or kind == "cosmetic" and "👑" or kind == "catalyst" and "⚗" or kind == "collectible" and "🏆"
		or id:match("^pet:") and "🐾" or "◆"
end

-------------------------------------------------------------------------------
-- Notificações
-------------------------------------------------------------------------------

local TOAST_STYLE = {
	error = { T.red, "⚠" }, quest = { T.yellow, "📜" }, luck = { T.green, "🍀" }, level = { T.teal, "⬆" },
	bestiary = { T.purple, "📖" }, secret = { Color3.fromRGB(255, 230, 120), "✦" },
	region = { Color3.fromRGB(150, 200, 255), "🌀" }, npc = { Color3.fromRGB(200, 170, 255), "🗨" },
}

function HUD.toast(text: string, kind: string?)
	local st = TOAST_STYLE[kind or ""] or { T.blue, "💬" }
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = toastHolder })
	local card = UIKit.frame({ Position = UDim2.fromScale(1.2, 0), Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.bg2, Parent = holder })
	UIKit.stroke(card, UIKit.darken(st[1], 0.5), 3, 0)
	local strip = new("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = st[1], BorderSizePixel = 0, Parent = card })
	UIKit.corner(strip, 6)
	UIKit.icon(card, { Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(36, 36), color = st[1], Text = st[2] })
	UIKit.label({ Position = UDim2.fromOffset(58, 0), Size = UDim2.new(1, -64, 1, 0), Text = text, TextSize = 14, TextScaled = false, Parent = card })
	tween(card, 0.35, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back)
	task.delay(4.5, function()
		tween(card, 0.3, { Position = UDim2.fromScale(1.2, 0) })
		task.wait(0.32)
		holder:Destroy()
	end)
end

local function feed(source: string, items)
	local card = UIKit.frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.bg2, BackgroundTransparency = 0.05, Parent = feedHolder })
	UIKit.stroke(card, T.stroke, 3, 0)
	UIKit.pad(card, 8)
	UIKit.list(card, Enum.FillDirection.Vertical, 4)
	UIKit.label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 20), Text = "🎁 " .. source, Font = T.title, TextSize = 17, TextColor3 = T.gold, Parent = card })
	for i, it in ipairs(items) do
		local txt = itemLabel(it.item, it.amount, it)
		table.insert(HUD.rewardHistory, 1, { t = os.time(), source = source, text = txt, notable = it.notable })
		local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Parent = card })
		UIKit.icon(row, { Size = UDim2.fromOffset(24, 24), color = itemColor(it.item), Text = itemIcon(it.item) })
		UIKit.label({ Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -30, 1, 0), Text = (it.notable and "<b>★ " or "") .. txt .. (it.notable and "</b>" or ""),
			TextSize = 14, TextColor3 = it.notable and T.gold or T.text, Parent = row })
	end
	while #HUD.rewardHistory > 60 do
		table.remove(HUD.rewardHistory)
	end
	UIKit.pop(card, 0.12)
	task.delay(5, function()
		card:Destroy()
	end)
	State.emit("RewardHistory", HUD.rewardHistory)
end

local function announce(p)
	local rarity = p.rarity and Rarities.Info[p.rarity]
	local color = rarity and (rarity.accent or rarity.color) or T.gold
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, Parent = announceHolder })
	local card = UIKit.frame({ Position = UDim2.fromOffset(0, -70), Size = UDim2.fromScale(1, 1), BackgroundColor3 = rarity and rarity.color or T.purple, Parent = holder })
	UIKit.stroke(card, color, 4, 0)
	UIKit.shine(card, 1.5)
	UIKit.label({ Size = UDim2.fromScale(1, 1), Font = T.title, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.1,
		Text = string.format('%s %s encontrou <font color="#%s">%s</font>!', p.remote and "🌐" or "✨", p.player or "?", color:ToHex(), p.text or ""), Parent = card })
	tween(card, 0.45, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
	task.delay(7, function()
		tween(card, 0.3, { Position = UDim2.fromOffset(0, -70) })
		task.wait(0.32)
		holder:Destroy()
	end)
end

-------------------------------------------------------------------------------
-- Atualizações
-------------------------------------------------------------------------------

local function floatGain(pill: GuiObject, amount: number, color: Color3)
	local l = UIKit.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.6, 0, 0.5, 0), Size = UDim2.fromOffset(120, 26), Text = "+" .. UIKit.fmt(amount),
		Font = T.title, TextSize = 22, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.1, ZIndex = 10, Parent = pill })
	tween(l, 0.9, { Position = UDim2.new(0.6, 0, 1.8, 0), TextTransparency = 1, TextStrokeTransparency = 1 })
	task.delay(0.95, function()
		l:Destroy()
	end)
end

local function refresh()
	local p = State.profile
	if not p then
		return
	end
	for id, c in pairs(currency) do
		local v = p[id] or 0
		if c.value ~= nil and v > c.value then
			UIKit.pop(c.pill, 0.12)
			floatGain(c.pill, v - c.value, CURRENCY_STYLE[id].color)
		end
		c.value = v
		c.label.Text = UIKit.fmt(v)
	end
	local story = Quests.Story[p.quests.storyIndex]
	if story then
		local prog = p.quests.storyProgress
		questTitle.Text = story.label
		questDesc.Text = story.desc
		UIKit.setBar(questFill, prog / story.goal.count, true)
		questText.Text = string.format("%d / %d", prog, story.goal.count)
		local ready = prog >= story.goal.count
		if ready and not questClaim.Visible then
			UIKit.pop(questClaim, 0.25)
		end
		questClaim.Visible = ready
	else
		questTitle.Text = "História concluída!"
		questDesc.Text = "Continue nas missões diárias."
		questClaim.Visible = false
	end
	-- pontos de aviso no menu
	local d = p.quests.daily
	local dailyReady = false
	for _, id in ipairs(d.ids or {}) do
		local q = Quests.findDaily(id)
		if q and not d.claimed[id] and (d.progress[id] or 0) >= q.goal.count then
			dailyReady = true
		end
	end
	if menuDots.Quests then
		menuDots.Quests.Visible = dailyReady or (story and p.quests.storyProgress >= story.goal.count) or false
	end
end

local function refreshLuck()
	local l = State.luck
	if not l then
		return
	end
	local best = 1
	for _, c in pairs(l.categories) do
		best = math.max(best, c.mult)
	end
	local pv = l.categories.PetVariant and l.categories.PetVariant.mult or 1
	luckText.Text = string.format("Sorte x%.2f", pv) .. (best > pv + 0.001 and string.format(' <font size="13">(até x%.2f)</font>', best) or "")
	local ev
	for _, s in ipairs(l.sources) do
		if s.type == "event" then
			ev = s
		end
	end
	if ev then
		eventBanner.Visible = true
		eventBanner:FindFirstChild("Text").Text = string.format("✨ %s: +%d%% %s — %s", ev.label, math.floor(ev.bonus * 100 + 0.5),
			ev.category == "All" and "em tudo" or (LuckConfig.CategoryLabels[ev.category] or ev.category), UIKit.time((ev.expires or 0) - State.now()))
	else
		eventBanner.Visible = false
	end
end

-------------------------------------------------------------------------------

function HUD.init()
	gui = UIKit.screen("HUD", 5)

	-- recursos (pílulas com ícone)
	local bar = new("Frame", { Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(560, 46), BackgroundTransparency = 1, Parent = gui })
	UIKit.list(bar, Enum.FillDirection.Horizontal, 26)
	for i, id in ipairs({ "coins", "essence", "astral" }) do
		local st = CURRENCY_STYLE[id]
		local slot = new("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(150, 42), BackgroundTransparency = 1, Parent = bar })
		local pill = UIKit.frame({ Position = UDim2.fromOffset(16, 4), Size = UDim2.fromOffset(134, 36), BackgroundColor3 = UIKit.darken(st.color, 0.55), radius = 18, Parent = slot })
		UIKit.stroke(pill, UIKit.darken(st.color, 0.75), 3, 0)
		local label = UIKit.label({ Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -36, 1, 0), Text = "0", Font = T.title, TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, Parent = pill })
		UIKit.icon(slot, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(44, 44), color = st.color, Text = st.icon, ZIndex = 3 })
		currency[id] = { label = label, pill = pill }
	end

	-- selo de sorte
	local badge = UIKit.button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(270, 44), Text = "", BackgroundColor3 = T.green, Parent = gui }, function()
		if HUD.openPanel then
			HUD.openPanel("Luck")
		end
	end)
	UIKit.icon(badge, { Position = UDim2.fromOffset(-6, -4), Size = UDim2.fromOffset(50, 50), color = Color3.fromRGB(60, 200, 80), Text = "🍀", ZIndex = 4 })
	luckText = UIKit.label({ Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -52, 1, 0), Text = "Sorte x1.00", Font = T.title, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.1, TextStrokeColor3 = Color3.fromRGB(10, 60, 20), ZIndex = 4, Parent = badge })
	UIKit.shine(badge, 4)
	eventBanner = UIKit.frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(560, 30), BackgroundColor3 = T.purple, Visible = false, radius = 15, Parent = gui })
	UIKit.stroke(eventBanner, UIKit.darken(T.purple, 0.6), 3, 0)
	UIKit.label({ Name = "Text", Size = UDim2.fromScale(1, 1), Text = "", Font = T.title, TextSize = 16, TextColor3 = Color3.fromRGB(255, 240, 170), TextXAlignment = Enum.TextXAlignment.Center, Parent = eventBanner })
	UIKit.shine(eventBanner, 2.5)

	-- menu lateral: botões grandes coloridos
	local menu = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 10), Size = UDim2.fromOffset(160, 330), BackgroundTransparency = 1, Parent = gui })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(74, 74), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
	local buttons = {
		{ "Pets", "🐾", "Pets", T.orange }, { "Items", "🎒", "Itens", T.blue }, { "Luck", "🍀", "Sorte", T.green }, { "Bestiary", "📖", "Bestiário", T.purple },
		{ "Quests", "📜", "Missões", T.yellow }, { "Map", "🗺", "Mapa", T.teal }, { "Settings", "⚙", "Opções", T.gray },
	}
	for i, b in ipairs(buttons) do
		local btn = UIKit.button({ LayoutOrder = i, Text = "", BackgroundColor3 = b[4], Parent = menu }, function()
			if HUD.openPanel then
				HUD.openPanel(b[1])
			end
		end)
		UIKit.label({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 40), Text = b[2], TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, ZIndex = 3, Parent = btn })
		UIKit.label({ Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 22), Text = b[3], Font = T.title, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeColor3 = UIKit.darken(b[4], 0.6), TextStrokeTransparency = 0, ZIndex = 3, Parent = btn })
		local dot = UIKit.icon(btn, { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(22, 22), color = T.red, Text = "!", ZIndex = 6 })
		dot.Visible = false
		menuDots[b[1]] = dot
	end
	local lp = Players.LocalPlayer
	lp:GetAttributeChangedSignal("CollectionReady"):Connect(function()
		local v = (lp:GetAttribute("CollectionReady") or 0) > 0
		if v and not menuDots.Bestiary.Visible then
			UIKit.pop(menuDots.Bestiary, 0.5)
		end
		menuDots.Bestiary.Visible = v
	end)

	-- cartão de missão
	local qt = UIKit.frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 70), Size = UDim2.fromOffset(290, 132), BackgroundColor3 = T.bg2, Parent = gui })
	UIKit.stroke(qt, T.stroke, 3, 0)
	local ribbon = UIKit.frame({ Position = UDim2.fromOffset(10, -12), Size = UDim2.fromOffset(130, 26), BackgroundColor3 = T.yellow, radius = 13, Parent = qt })
	UIKit.stroke(ribbon, UIKit.darken(T.yellow, 0.6), 3, 0)
	UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "📜 MISSÃO", Font = T.title, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeColor3 = UIKit.darken(T.yellow, 0.6), TextStrokeTransparency = 0, Parent = ribbon })
	questTitle = UIKit.label({ Position = UDim2.fromOffset(12, 18), Size = UDim2.new(1, -24, 0, 24), Text = "", Font = T.title, TextSize = 20, TextColor3 = T.gold, Parent = qt })
	questDesc = UIKit.label({ Position = UDim2.fromOffset(12, 42), Size = UDim2.new(1, -24, 0, 34), Text = "", TextSize = 13, TextColor3 = T.muted, Parent = qt })
	local _, qf, qtext = UIKit.bar(qt, { Position = UDim2.fromOffset(12, 80), Size = UDim2.new(1, -24, 0, 18), color = T.yellow, textSize = 13 })
	questFill, questText = qf, qtext
	questClaim = UIKit.button({ Position = UDim2.fromOffset(12, 102), Size = UDim2.new(1, -24, 0, 26), Text = "✔ Resgatar recompensa", TextSize = 15, BackgroundColor3 = T.green, Visible = false, Parent = qt }, function()
		local r = State.request("ClaimStory")
		if not r.ok and r.msg then
			HUD.toast(r.msg, "error")
		end
	end)
	task.spawn(function()
		while questClaim.Parent do
			if questClaim.Visible then
				UIKit.pop(questClaim, 0.06)
			end
			task.wait(1.2)
		end
	end)

	-- notificações, feed e anúncios
	toastHolder = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 214), Size = UDim2.fromOffset(310, 320), BackgroundTransparency = 1, Parent = gui })
	UIKit.list(toastHolder, Enum.FillDirection.Vertical, 8)
	feedHolder = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 186, 1, -150), Size = UDim2.fromOffset(270, 300), BackgroundTransparency = 1, Parent = gui })
	local fl = UIKit.list(feedHolder, Enum.FillDirection.Vertical, 8)
	fl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	announceHolder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 98), Size = UDim2.fromOffset(640, 130), BackgroundTransparency = 1, Parent = gui })
	UIKit.list(announceHolder, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center)

	State.on("State", refresh)
	State.on("Luck", refreshLuck)
	State.on("Toast", function(p)
		HUD.toast(p.text, p.kind)
	end)
	State.on("Drop", function(p)
		feed(p.source, p.items)
	end)
	State.on("Announce", announce)
	State.on("State", function(payload)
		if payload.memoryMode and not HUD.warnedMemory then
			HUD.warnedMemory = true
			HUD.toast("Modo memória: o progresso NÃO será salvo nesta sessão (DataStore indisponível).", "error")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			refreshLuck()
		end
	end)
end

return HUD

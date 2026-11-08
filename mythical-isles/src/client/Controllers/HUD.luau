-- HUD principal no Design System (docs/UI_DESIGN_SYSTEM.md, seção 4): placa de madeira do mundo atual,
-- contadores de moeda que contam e soltam partículas, menu lateral de hexágonos rúnicos, painel de status
-- com barras "recipiente" (vida do avatar e XP da equipe), cartão de missão em pedra rúnica,
-- notificações que deslizam, feed de drops e anúncios de descobertas raras.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Quests = require(Shared.Config.Quests)
local Rarities = require(Shared.Config.Rarities)
local LuckConfig = require(Shared.Config.Luck)
local Worlds = require(Shared.Config.Worlds)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)

local HUD = {}
local T = UIKit.Theme
local new = UIKit.new

local gui
local counters = {} -- id da moeda -> UIKit.counter
local matCounter, matId -- contador do material do mundo atual
local plaque -- { scale, crest, glyph, sub, name }
local luckText, eventBanner
local questTitle, questDesc, questBar, questClaim
local hpBar, xpBar, levelText, portrait
local toastHolder, feedHolder, announceHolder
local menuDots = {}
local hexRims = {}
local lastTeamLevel
HUD.rewardHistory = {} -- últimas recompensas recebidas (sessão)
HUD.openPanel = nil -- definido pelo Panels

local CURRENCY_STYLE = {
	coins = { color = Color3.fromRGB(255, 196, 40), icon = "🪙", glyph = "●" },
	essence = { color = Color3.fromRGB(40, 210, 180), icon = "💎", glyph = "◆" },
	astral = { color = Color3.fromRGB(160, 110, 255), icon = "✦", glyph = "✦" },
}

-- material típico de cada mundo (cai dos inimigos de lá; ver Config/Drops) e o brasão da placa
local WORLD_MATERIAL = { verdant = "verdant_sap", crystal = "prism_shard", sky = "storm_feather", wilds = "moon_petal", astral = "void_essence" }
local WORLD_GLYPH = { verdant = "🌿", crystal = "💠", sky = "☁", wilds = "🌙", astral = "✦" }

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
	local st = TOAST_STYLE[kind or ""] or { T.info, "💬" }
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, Parent = toastHolder })
	local card, body = UIKit.runeFrame({ Name = "Toast", Position = UDim2.fromScale(1.2, 0), Size = UDim2.fromScale(1, 1), accent = st[1], runes = false, radius = 12, Parent = holder })
	local strip = new("Frame", { Position = UDim2.fromOffset(7, 9), Size = UDim2.new(0, 5, 1, -18), BackgroundColor3 = st[1], BorderSizePixel = 0, Parent = body })
	UIKit.corner(strip, 3)
	UIKit.icon(body, { Position = UDim2.fromOffset(18, 10), Size = UDim2.fromOffset(38, 38), color = st[1], Text = st[2] })
	UIKit.label({ Position = UDim2.fromOffset(64, 0), Size = UDim2.new(1, -72, 1, 0), Text = text, TextSize = 14, TextScaled = false, Parent = body })
	tween(card, 0.35, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back)
	task.delay(4.5, function()
		tween(card, 0.3, { Position = UDim2.fromScale(1.2, 0) })
		task.wait(0.32)
		holder:Destroy()
	end)
end

local function feed(source: string, items)
	local card, body = UIKit.runeFrame({ Name = "Feed", Size = UDim2.new(1, 0, 0, 40 + #items * 28), radius = 12, runes = false, Parent = feedHolder })
	UIKit.pad(body, 8)
	UIKit.list(body, Enum.FillDirection.Vertical, 4)
	UIKit.label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 20), Text = "🎁 " .. source, Font = T.title, TextSize = 17, TextColor3 = T.gold, Parent = body })
	for i, it in ipairs(items) do
		local txt = itemLabel(it.item, it.amount, it)
		table.insert(HUD.rewardHistory, 1, { t = os.time(), source = source, text = txt, notable = it.notable })
		local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = body })
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
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, Parent = announceHolder })
	local card, body = UIKit.runeFrame({ Name = "Announce", Position = UDim2.fromOffset(0, -80), Size = UDim2.fromScale(1, 1), accent = color, glow = true, radius = 16,
		top = UIKit.lighten(rarity and rarity.color or T.purple, 0.1), mid = rarity and rarity.color or T.purple, bottom = UIKit.darken(rarity and rarity.color or T.purple, 0.45), Parent = holder })
	UIKit.shine(body, 1.5)
	UIKit.label({ Size = UDim2.fromScale(1, 1), Font = T.title, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0, TextStrokeColor3 = T.edgeDark,
		Text = string.format('%s %s encontrou <font color="#%s">%s</font>!', p.remote and "🌐" or "✨", p.player or "?", color:ToHex(), p.text or ""), Parent = body })
	tween(card, 0.45, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
	task.delay(7, function()
		tween(card, 0.3, { Position = UDim2.fromOffset(0, -80) })
		task.wait(0.32)
		holder:Destroy()
	end)
end

-------------------------------------------------------------------------------
-- Atualizações
-------------------------------------------------------------------------------

-- XP da equipe: o jogador não tem nível próprio; o painel de status mostra o nível médio da equipe
-- e quanto falta (soma do XP / soma do XP necessário dos pets equipados).
local function teamProgress(p)
	local lv, xp, need, n = 0, 0, 0, 0
	for _, uid in ipairs(p.team or {}) do
		local pet = p.pets[uid]
		if pet then
			n += 1
			lv += pet.level or 1
			xp += pet.xp or 0
			local d = State.derived and State.derived.petStats and State.derived.petStats[uid]
			need += d and d.xpNext or 0
		end
	end
	if n == 0 then
		return 0, 0
	end
	return math.floor(lv / n), need > 0 and xp / need or 1
end

local function refresh()
	local p = State.profile
	if not p then
		return
	end
	for id, c in pairs(counters) do
		c.set(p[id] or 0)
	end
	if matCounter and matId then
		matCounter.set(p.items and p.items[matId] or 0)
	end
	local lv, frac = teamProgress(p)
	if levelText then
		levelText.Text = lv > 0 and ("Nv " .. lv) or "Nv —"
		xpBar.set(frac, lv > 0 and string.format("✦ Equipe Nv %d · %d%%", lv, math.floor(frac * 100)) or "✦ Sem equipe")
		if lastTeamLevel and lv > lastTeamLevel then
			UIKit.pop(portrait, 0.3)
			UIKit.burst(portrait, T.xp, 12)
		end
		lastTeamLevel = lv
	end
	local story = Quests.Story[p.quests.storyIndex]
	if story then
		local prog = p.quests.storyProgress
		questTitle.Text = story.label
		questDesc.Text = story.desc
		questBar.set(prog / story.goal.count, string.format("%d / %d", math.min(prog, story.goal.count), story.goal.count))
		local ready = prog >= story.goal.count
		if ready and not questClaim.Visible then
			UIKit.pop(questClaim, 0.25)
		end
		questClaim.Visible = ready
	else
		questTitle.Text = "História concluída!"
		questDesc.Text = "Continue nas missões diárias."
		questBar.set(1, "✔")
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
-- Mundo atual: placa, acento dos hexágonos e material do mundo
-------------------------------------------------------------------------------

local function recolorHex(rim: Instance, accent: Color3)
	for _, r in ipairs(rim:GetChildren()) do
		if r:IsA("Frame") then
			r.BackgroundColor3 = accent
			local g = r:FindFirstChildOfClass("UIGradient")
			if g then
				g.Color = ColorSequence.new(UIKit.lighten(accent, 0.35), UIKit.darken(accent, 0.25))
			end
		end
	end
end

local function applyWorld(animate: boolean)
	local id = Players.LocalPlayer:GetAttribute("World") or "verdant"
	local w = Worlds.Info[id] or Worlds.Info.verdant
	local accent = w.palette.accent
	local function set()
		plaque.sub.Text = "MUNDO " .. tostring(w.index)
		plaque.name.Text = w.name
		plaque.glyph.Text = WORLD_GLYPH[id] or "✦"
		plaque.crest.BackgroundColor3 = accent
		local st = plaque.crest:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = UIKit.darken(accent, 0.65)
		end
		for _, rim in ipairs(hexRims) do
			recolorHex(rim, accent)
		end
	end
	if animate then
		-- a placa "vira" (escala vai a zero e volta) e troca o mundo no meio do giro
		tween(plaque.scale, 0.18, { Scale = 0.05 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.19, function()
			set()
			tween(plaque.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			UIKit.burst(plaque.crest, accent, 10)
		end)
	else
		set()
	end
	-- contador do material do mundo
	local mat = WORLD_MATERIAL[id]
	if mat ~= matId then
		matId = mat
		local info = Items.Info[mat]
		local coin = matCounter.root:FindFirstChild("Coin")
		if coin and info then
			local g = coin:FindFirstChildOfClass("UIGradient")
			if g then
				g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, UIKit.lighten(info.color, 0.55)), ColorSequenceKeypoint.new(0.5, info.color),
					ColorSequenceKeypoint.new(1, UIKit.darken(info.color, 0.4)) })
			end
			local st = coin:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = UIKit.darken(info.color, 0.65)
			end
		end
		matCounter.value = nil -- troca de mundo não é "ganho": sem número flutuando
		local p = State.profile
		matCounter.set(p and p.items and p.items[mat] or 0)
	end
end

-------------------------------------------------------------------------------

function HUD.init()
	gui = UIKit.screen("HUD", 5)
	local lp = Players.LocalPlayer
	local accent = UIKit.worldAccent()

	-- placa de madeira do mundo atual (clique: Menu de Mundos)
	local pf = UIKit.woodPlaque({ Name = "WorldPlaque", Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(236, 52), Text = "", nails = false, radius = 16, Parent = gui })
	local pscale = new("UIScale", { Parent = pf })
	local crest = new("Frame", { Name = "Crest", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(30, 26), Size = UDim2.fromOffset(32, 32), Rotation = 45,
		BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 2, Parent = pf })
	UIKit.corner(crest, 6)
	UIKit.stroke(crest, UIKit.darken(accent, 0.65), 3, 0)
	new("UIGradient", { Rotation = 0, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)), Parent = crest })
	local glyph = UIKit.label({ Name = "Glyph", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(30, 26), Size = UDim2.fromOffset(26, 26), Text = "", TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, ZIndex = 3, Parent = pf })
	local sub = UIKit.label({ Name = "Sub", Position = UDim2.fromOffset(56, 5), Size = UDim2.new(1, -64, 0, 14), Text = "", Font = T.body, TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 226, 170), TextStrokeColor3 = T.woodEdge, TextStrokeTransparency = 0.3, ZIndex = 3, Parent = pf })
	local wname = UIKit.label({ Name = "WorldName", Position = UDim2.fromOffset(56, 18), Size = UDim2.new(1, -64, 0, 28), Text = "", Font = T.title, TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 246, 228), TextStrokeColor3 = T.woodEdge, TextStrokeTransparency = 0, TextWrapped = false, ZIndex = 3, Parent = pf })
	local hit = new("TextButton", { Name = "Hit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 4, Parent = pf })
	hit.Activated:Connect(function()
		UIKit.burst(crest, accent)
		if HUD.openPanel then
			HUD.openPanel("Map")
		end
	end)
	plaque = { scale = pscale, crest = crest, glyph = glyph, sub = sub, name = wname }

	-- contadores de moeda (+ material do mundo)
	local bar = new("Frame", { Name = "Counters", Position = UDim2.fromOffset(262, 12), Size = UDim2.fromOffset(660, 46), BackgroundTransparency = 1, Parent = gui })
	UIKit.list(bar, Enum.FillDirection.Horizontal, 8)
	for i, id in ipairs({ "coins", "essence", "astral" }) do
		local st = CURRENCY_STYLE[id]
		counters[id] = UIKit.counter({ Name = id, LayoutOrder = i, Size = UDim2.fromOffset(158, 46), color = st.color, icon = st.glyph, Parent = bar })
	end
	matCounter = UIKit.counter({ Name = "WorldMaterial", LayoutOrder = 4, Size = UDim2.fromOffset(150, 46), color = Items.Info.verdant_sap.color, icon = "⬢", Parent = bar })

	-- selo de sorte (pílula de pedra com trevo; clique abre o painel de Sorte)
	local luck = new("TextButton", { Name = "Luck", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(232, 46), BackgroundTransparency = 1,
		Text = "", AutoButtonColor = false, Parent = gui })
	local lpill = new("Frame", { Name = "Pill", Position = UDim2.fromOffset(18, 5), Size = UDim2.new(1, -18, 1, -10), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = luck })
	UIKit.corner(lpill, 100)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(UIKit.lighten(T.confirm, 0.1), UIKit.darken(T.confirm, 0.45)), Parent = lpill })
	UIKit.stroke(lpill, T.edgeDark, 3, 0)
	UIKit.shine(lpill, 4)
	local clover = new("Frame", { Name = "Coin", Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = luck })
	UIKit.corner(clover, 100)
	new("UIGradient", { Rotation = 45, Color = ColorSequence.new(Color3.fromRGB(170, 255, 170), Color3.fromRGB(30, 140, 60)), Parent = clover })
	UIKit.stroke(clover, Color3.fromRGB(10, 60, 24), 3, 0)
	UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "🍀", TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, ZIndex = 4, Parent = clover })
	luckText = UIKit.label({ Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -38, 1, 0), Text = "Sorte x1.00", Font = T.title, TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(8, 50, 20), ZIndex = 4, Parent = lpill })
	luck.Activated:Connect(function()
		UIKit.burst(clover, T.luck)
		if HUD.openPanel then
			HUD.openPanel("Luck")
		end
	end)
	eventBanner = UIKit.frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 66), Size = UDim2.fromOffset(540, 30), BackgroundColor3 = T.purple, Visible = false, radius = 15, Parent = gui })
	UIKit.stroke(eventBanner, T.edgeDark, 3, 0)
	UIKit.label({ Name = "Text", Size = UDim2.fromScale(1, 1), Text = "", Font = T.title, TextSize = 16, TextColor3 = Color3.fromRGB(255, 240, 170), TextXAlignment = Enum.TextXAlignment.Center, Parent = eventBanner })
	UIKit.shine(eventBanner, 2.5)

	-- menu lateral: hexágonos rúnicos em duas colunas desencontradas
	local menu = new("Frame", { Name = "Menu", Position = UDim2.fromOffset(18, 86), Size = UDim2.fromOffset(170, 380), BackgroundTransparency = 1, Parent = gui })
	local buttons = {
		{ "Pets", "🐾", "Pets" }, { "Items", "🎒", "Itens" }, { "Luck", "🍀", "Sorte" }, { "Bestiary", "📖", "Bestiário" },
		{ "Quests", "📜", "Missões" }, { "Map", "🌍", "Mundos" }, { "Settings", "⚙", "Opções" },
	}
	for i, b in ipairs(buttons) do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local btn, dot, parts = UIKit.hexButton({ Name = b[1], LayoutOrder = i, icon = b[2], label = b[3], size = 70, color = accent, Parent = menu }, function()
			if HUD.openPanel then
				HUD.openPanel(b[1])
			end
		end)
		btn.Position = UDim2.fromOffset(col * 86, row * 92 + col * 46)
		menuDots[b[1]] = dot
		table.insert(hexRims, parts.rim)
	end
	lp:GetAttributeChangedSignal("CollectionReady"):Connect(function()
		local v = (lp:GetAttribute("CollectionReady") or 0) > 0
		if v and not menuDots.Bestiary.Visible then
			UIKit.pop(menuDots.Bestiary, 0.5)
		end
		menuDots.Bestiary.Visible = v
	end)

	-- painel de status (canto inferior esquerdo): retrato, vida do avatar e XP da equipe
	local status, sbody = UIKit.runeFrame({ Name = "Status", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(282, 100), Parent = gui })
	portrait = new("Frame", { Name = "Portrait", Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = sbody })
	UIKit.corner(portrait, 100)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(UIKit.lighten(accent, 0.2), UIKit.darken(accent, 0.5)), Parent = portrait })
	UIKit.stroke(portrait, T.woodTop, 4, 0)
	local display = lp.DisplayName or lp.Name or "?"
	UIKit.label({ Name = "Initial", Size = UDim2.fromScale(1, 1), Text = string.upper(string.sub(display, 1, 1)), Font = T.title, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0, TextStrokeColor3 = T.edgeDark, Parent = portrait })
	local headshot = new("ImageLabel", { Name = "Headshot", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "", ZIndex = 2, Parent = portrait })
	UIKit.corner(headshot, 100)
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and type(url) == "string" then
			headshot.Image = url
		end
	end)
	local lvPlaque, lvLabel = UIKit.woodPlaque({ Name = "Level", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(44, 78), Size = UDim2.fromOffset(62, 22), Text = "Nv —",
		TextSize = 14, radius = 8, nails = false, ZIndex = 3, Parent = sbody })
	local _ = lvPlaque
	levelText = lvLabel
	UIKit.label({ Name = "PlayerName", Position = UDim2.fromOffset(88, 6), Size = UDim2.new(1, -98, 0, 20), Text = display, Font = T.title, TextSize = 17, TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeTransparency = 0, TextStrokeColor3 = T.edgeDark, Parent = sbody })
	hpBar = UIKit.vesselBar({ Name = "HP", Position = UDim2.fromOffset(88, 32), Size = UDim2.new(1, -100, 0, 24), color = T.hp, textSize = 13, Parent = sbody })
	xpBar = UIKit.vesselBar({ Name = "XP", Position = UDim2.fromOffset(88, 64), Size = UDim2.new(1, -100, 0, 18), color = T.xp, textSize = 11, Parent = sbody })
	local hpStroke = hpBar.root:FindFirstChildOfClass("UIStroke")
	local lastHp, lastMax = -1, -1
	UIKit.animate(status, function(t)
		local char = lp.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local h, m = hum and hum.Health or 0, hum and hum.MaxHealth or 100
		if h ~= lastHp or m ~= lastMax then
			lastHp, lastMax = h, m
			hpBar.set(m > 0 and h / m or 0, string.format("❤ %d / %d", math.floor(h + 0.5), math.floor(m + 0.5)))
		end
		-- vida baixa: o recipiente pulsa em vermelho
		if hpStroke then
			local low = m > 0 and h / m < 0.25 and h > 0
			hpStroke.Color = low and T.cancel:Lerp(T.edgeDark, (math.sin(t * 7.8) + 1) / 2) or T.edgeDark
		end
	end)

	-- cartão de missão em pedra rúnica
	local qt, qbody = UIKit.runeFrame({ Name = "Quest", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 76), Size = UDim2.fromOffset(292, 136), Parent = gui })
	UIKit.woodPlaque({ Name = "Ribbon", Position = UDim2.fromOffset(14, -13), Size = UDim2.fromOffset(136, 26), Text = "📜 MISSÃO", TextSize = 15, radius = 9, nails = false, ZIndex = 3, Parent = qt })
	questTitle = UIKit.label({ Position = UDim2.fromOffset(14, 18), Size = UDim2.new(1, -28, 0, 24), Text = "", Font = T.title, TextSize = 20, TextColor3 = T.gold, TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = qbody })
	questDesc = UIKit.label({ Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 34), Text = "", TextSize = 13, TextColor3 = T.muted, Parent = qbody })
	questBar = UIKit.vesselBar({ Name = "Progress", Position = UDim2.fromOffset(14, 80), Size = UDim2.new(1, -28, 0, 20), color = T.fury, textSize = 13, Parent = qbody })
	questClaim = UIKit.button({ Position = UDim2.fromOffset(14, 104), Size = UDim2.new(1, -28, 0, 24), Text = "✔ Resgatar recompensa", TextSize = 15, BackgroundColor3 = T.confirm,
		Visible = false, Parent = qbody }, function()
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
	toastHolder = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 226), Size = UDim2.fromOffset(310, 320), BackgroundTransparency = 1, Parent = gui })
	UIKit.list(toastHolder, Enum.FillDirection.Vertical, 8)
	feedHolder = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 196, 1, -150), Size = UDim2.fromOffset(270, 300), BackgroundTransparency = 1, Parent = gui })
	local fl = UIKit.list(feedHolder, Enum.FillDirection.Vertical, 8)
	fl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	announceHolder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104), Size = UDim2.fromOffset(640, 130), BackgroundTransparency = 1, Parent = gui })
	UIKit.list(announceHolder, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center)

	applyWorld(false)
	lp:GetAttributeChangedSignal("World"):Connect(function()
		applyWorld(true)
	end)
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

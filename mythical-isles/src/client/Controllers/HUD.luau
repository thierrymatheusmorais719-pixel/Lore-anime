-- HUD principal: recursos, selo de sorte, menu, rastreador de missão, notificações,
-- feed de drops (com histórico) e anúncios globais.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Quests = require(Shared.Config.Quests)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local LuckConfig = require(Shared.Config.Luck)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)

local HUD = {}
local T = UIKit.Theme

local gui
local currencyLabels = {}
local luckBadge, luckText, eventBanner
local questTitle, questDesc, questBar, questClaim
local toastHolder, feedHolder, announceHolder
HUD.rewardHistory = {} -- últimas recompensas recebidas (sessão)
HUD.openPanel = nil -- definido pelo Panels

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

function HUD.toast(text: string, kind: string?)
	local colors = { error = T.bad, quest = T.gold, luck = T.luck, level = T.essence, bestiary = T.astral, secret = Color3.fromRGB(255, 240, 160) }
	local f = UIKit.frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.bg, BackgroundTransparency = 0.15, Parent = toastHolder })
	UIKit.stroke(f, colors[kind or ""] or T.stroke, 2, 0.1)
	UIKit.pad(f, 8)
	UIKit.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text, TextSize = 15, TextColor3 = colors[kind or ""] or T.text, Parent = f })
	task.delay(4.5, function()
		f:Destroy()
	end)
end

local function feed(source: string, items)
	local lines = {}
	for _, it in ipairs(items) do
		local txt = itemLabel(it.item, it.amount, it)
		table.insert(lines, (it.notable and "<b>★ " or "") .. txt .. (it.notable and "</b>" or ""))
		table.insert(HUD.rewardHistory, 1, { t = os.time(), source = source, text = txt, notable = it.notable })
	end
	while #HUD.rewardHistory > 60 do
		table.remove(HUD.rewardHistory)
	end
	local f = UIKit.frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.bg, BackgroundTransparency = 0.25, Parent = feedHolder })
	UIKit.pad(f, 6)
	UIKit.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = '<font color="#FFD250">' .. source .. "</font>\n" .. table.concat(lines, "\n"),
		TextSize = 13, Parent = f })
	task.delay(5, function()
		f:Destroy()
	end)
	State.emit("RewardHistory", HUD.rewardHistory)
end

local function announce(p)
	local rarity = p.rarity and Rarities.Info[p.rarity]
	local color = rarity and (rarity.accent or rarity.color) or T.gold
	local f = UIKit.frame({ Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.bg, BackgroundTransparency = 0.1, Parent = announceHolder })
	UIKit.stroke(f, color, 2, 0)
	local mut = p.mutation and Mutations.Info[p.mutation]
	local prefix = p.remote and "🌐 " or "✦ "
	UIKit.label({ Size = UDim2.fromScale(1, 1), Text = string.format('%s<b>%s</b> encontrou <font color="#%s"><b>%s</b></font>%s', prefix, p.player or "?", color:ToHex(),
		p.text or "", mut and "" or ""), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Font = T.bold, Parent = f })
	task.delay(7, function()
		f:Destroy()
	end)
end

local function refreshCurrencies()
	local p = State.profile
	if not p then
		return
	end
	for id, label in pairs(currencyLabels) do
		label.Text = UIKit.fmt(p[id] or 0)
	end
	-- missão atual
	local story = Quests.Story[p.quests.storyIndex]
	if story then
		local prog = p.quests.storyProgress
		questTitle.Text = "📜 " .. story.label
		questDesc.Text = story.desc
		local _, fill, text = questBar, questBar:FindFirstChild("Fill"), questBar:FindFirstChild("Text")
		UIKit.setBar(fill, prog / story.goal.count, true)
		text.Text = string.format("%d / %d", prog, story.goal.count)
		questClaim.Visible = prog >= story.goal.count
	else
		questTitle.Text = "📜 História concluída!"
		questDesc.Text = "Você completou todas as missões da história. Continue nas diárias."
		questClaim.Visible = false
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
	luckText.Text = string.format("🍀 Sorte x%.2f", pv) .. (best > pv + 0.001 and string.format("  <font size=\"12\">(até x%.2f)</font>", best) or "")
	local ev
	for _, s in ipairs(l.sources) do
		if s.type == "event" then
			ev = s
		end
	end
	if ev then
		eventBanner.Visible = true
		eventBanner.Text = string.format("✨ %s: +%d%% %s — termina em %s", ev.label, math.floor(ev.bonus * 100 + 0.5),
			ev.category == "All" and "em tudo" or (LuckConfig.CategoryLabels[ev.category] or ev.category), UIKit.time((ev.expires or 0) - State.now()))
	else
		eventBanner.Visible = false
	end
end

function HUD.init()
	gui = UIKit.screen("HUD", 5)
	-- recursos
	local bar = UIKit.new("Frame", { Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(460, 40), BackgroundTransparency = 1, Parent = gui })
	UIKit.list(bar, Enum.FillDirection.Horizontal, 8)
	for _, id in ipairs({ "coins", "essence", "astral" }) do
		local info = Items.Currencies[id]
		local f = UIKit.frame({ Size = UDim2.fromOffset(140, 36), BackgroundColor3 = T.bg, BackgroundTransparency = 0.2, Parent = bar })
		UIKit.stroke(f, info.color, 1.5, 0.3)
		UIKit.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(26, 36), Text = info.icon, TextColor3 = info.color, TextSize = 22, Font = T.title, Parent = f })
		currencyLabels[id] = UIKit.label({ Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -40, 1, 0), Text = "0", TextSize = 18, Font = T.title, Parent = f })
	end
	-- selo de sorte
	luckBadge = UIKit.button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(250, 36), Text = "",
		BackgroundColor3 = Color3.fromRGB(26, 60, 40), Parent = gui }, function()
		if HUD.openPanel then
			HUD.openPanel("Luck")
		end
	end)
	UIKit.stroke(luckBadge, T.luck, 2, 0.2)
	luckText = UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "🍀 Sorte x1.00", Font = T.title, TextSize = 19, TextColor3 = T.luck, TextXAlignment = Enum.TextXAlignment.Center, Parent = luckBadge })
	eventBanner = UIKit.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50), Size = UDim2.fromOffset(520, 24), Text = "", Visible = false,
		BackgroundTransparency = 0.3, BackgroundColor3 = Color3.fromRGB(60, 40, 90), TextColor3 = Color3.fromRGB(255, 235, 160), TextSize = 14, Font = T.bold,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = gui })
	UIKit.corner(eventBanner, 8)
	-- menu lateral
	local menu = UIKit.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.45, 0), Size = UDim2.fromOffset(64, 420), BackgroundTransparency = 1, Parent = gui })
	UIKit.list(menu, Enum.FillDirection.Vertical, 8)
	local buttons = {
		{ "Pets", "🐾", "Pets" }, { "Items", "🎒", "Itens" }, { "Luck", "🍀", "Sorte" }, { "Bestiary", "📖", "Bestiário" },
		{ "Quests", "📜", "Missões" }, { "Map", "🗺", "Mapa" }, { "Settings", "⚙", "Opções" },
	}
	for _, b in ipairs(buttons) do
		local btn = UIKit.button({ Size = UDim2.fromOffset(64, 52), Text = "", BackgroundColor3 = T.bg, BackgroundTransparency = 0.15, Parent = menu }, function()
			if HUD.openPanel then
				HUD.openPanel(b[1])
			end
		end)
		UIKit.stroke(btn, T.stroke, 1.5, 0.3)
		UIKit.label({ Size = UDim2.new(1, 0, 0, 30), Text = b[2], TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, Parent = btn })
		UIKit.label({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 18), Text = b[3], TextSize = 11, Font = T.bold, TextXAlignment = Enum.TextXAlignment.Center, Parent = btn })
		if b[1] == "Bestiary" then
			local dot = UIKit.frame({ Name = "Dot", Position = UDim2.new(1, -14, 0, 4), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = T.bad, radius = 5, Visible = false, Parent = btn })
			local lp = game:GetService("Players").LocalPlayer
			lp:GetAttributeChangedSignal("CollectionReady"):Connect(function()
				dot.Visible = (lp:GetAttribute("CollectionReady") or 0) > 0
			end)
		end
	end
	-- rastreador de missão
	local qt = UIKit.frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 60), Size = UDim2.fromOffset(270, 118), BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.2, Parent = gui })
	UIKit.pad(qt, 8)
	questTitle = UIKit.label({ Size = UDim2.new(1, 0, 0, 22), Text = "📜", Font = T.title, TextSize = 17, TextColor3 = T.gold, Parent = qt })
	questDesc = UIKit.label({ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 34), Text = "", TextSize = 13, TextColor3 = T.muted, Parent = qt })
	questBar = UIKit.bar(qt, { Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 14), color = T.gold })
	questClaim = UIKit.button({ Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 22), Text = "Resgatar recompensa", TextSize = 13,
		BackgroundColor3 = Color3.fromRGB(70, 150, 90), Visible = false, Parent = qt }, function()
		local r = State.request("ClaimStory")
		if not r.ok and r.msg then
			HUD.toast(r.msg, "error")
		end
	end)
	-- notificações (direita, abaixo do rastreador)
	toastHolder = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 188), Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 1, Parent = gui })
	UIKit.list(toastHolder, Enum.FillDirection.Vertical, 6)
	-- feed de drops (esquerda, acima da equipe — não cobre o centro da tela)
	feedHolder = UIKit.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 86, 1, -150), Size = UDim2.fromOffset(250, 260), BackgroundTransparency = 1, Parent = gui })
	local fl = UIKit.list(feedHolder, Enum.FillDirection.Vertical, 6)
	fl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	-- anúncios globais (topo)
	announceHolder = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 82), Size = UDim2.fromOffset(620, 140), BackgroundTransparency = 1, Parent = gui })
	UIKit.list(announceHolder, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)

	State.on("State", refreshCurrencies)
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
			HUD.toast("Modo memória: o DataStore está indisponível, o progresso NÃO será salvo nesta sessão.", "error")
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

-- Painéis modais: Pets/Equipe, Itens, Sorte, Bestiário, Missões, Mapa, Opções (+Teste no Studio)
-- e o painel de Ovo com as chances REAIS calculadas pelo servidor.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Items = require(Shared.Config.Items)
local Eggs = require(Shared.Config.Eggs)
local Worlds = require(Shared.Config.Worlds)
local Quests = require(Shared.Config.Quests)
local Combat = require(Shared.Config.Combat)
local Abilities = require(Shared.Config.Abilities)
local Enemies = require(Shared.Config.Enemies)
local Bosses = require(Shared.Config.Bosses)
local LuckConfig = require(Shared.Config.Luck)
local Exploration = require(Shared.Config.Exploration)
local CollectionLogic = require(Shared.Logic.CollectionLogic)
local CreatureBuilder = require(Shared.Builders.CreatureBuilder)
local MutationVisuals = require(Shared.Builders.MutationVisuals)
local Accessories = require(Shared.Builders.Accessories)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)
local Fx = require(script.Parent.Fx)

local Panels = {}
local T = UIKit.Theme
local new = UIKit.new

local gui, modal, titleLabel, content
local current = nil
local selectedPet = nil

local function rarityColor(r: string): Color3
	return Rarities.Info[r].color
end

local function clear()
	for _, c in ipairs(content:GetChildren()) do
		c:Destroy()
	end
end

local function toastResult(r)
	if r and r.msg then
		HUD.toast(r.msg, r.ok and "quest" or "error")
	end
end

local function costText(cost)
	if not cost then
		return ""
	end
	local parts = {}
	for _, c in ipairs({ "coins", "essence", "astral" }) do
		if (cost[c] or 0) > 0 then
			table.insert(parts, UIKit.fmt(cost[c]) .. " " .. Items.label(c))
		end
	end
	for id, n in pairs(cost.items or {}) do
		table.insert(parts, n .. "x " .. Items.label(id))
	end
	return table.concat(parts, ", ")
end

local function preview(parent: Instance, pet)
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.panel2, BackgroundTransparency = 0.2, LightColor = Color3.new(1, 1, 1),
		Ambient = Color3.fromRGB(160, 160, 180), Parent = parent })
	UIKit.corner(vp, 10)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 38
	cam.Parent = vp
	vp.CurrentCamera = cam
	local model = CreatureBuilder.build(pet.species, Pets.Species[pet.species], 1)
	MutationVisuals.apply(model, pet.mutation)
	Accessories.apply(model, pet.accessory)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = vp
	local size = model:GetExtentsSize().Magnitude
	local a = 0.6
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not vp.Parent then
			conn:Disconnect()
			return
		end
		a += dt * 0.6
		cam.CFrame = CFrame.lookAt(Vector3.new(math.sin(a) * size * 1.25, size * 0.3, math.cos(a) * size * 1.25), Vector3.zero)
	end)
end

-------------------------------------------------------------------------------
-- PETS
-------------------------------------------------------------------------------

local function petDetail(parent, uid)
	local p = State.profile
	local pet = p.pets[uid]
	if not pet then
		return
	end
	local sp = Pets.Species[pet.species]
	local d = State.derived and State.derived.petStats and State.derived.petStats[uid]
	local role = Combat.Roles[sp.role]
	local ab = Abilities.Info[sp.ability]
	local box = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })
	local pv = new("Frame", { Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1, Parent = box })
	preview(pv, pet)
	local mut = pet.mutation and Mutations.Info[pet.mutation]
	UIKit.label({ Position = UDim2.fromOffset(0, 154), Size = UDim2.new(1, 0, 0, 24), Font = T.title, TextSize = 19,
		Text = (mut and string.format('<font color="#%s">%s</font> ', mut.color:ToHex(), pet.mutation) or "") .. sp.name
			.. string.format('  <font size="13" color="#%s">%s</font>', rarityColor(sp.rarity):ToHex(), Rarities.Info[sp.rarity].label), Parent = box })
	local stats = d and string.format("Vida %s · Ataque %.0f · Defesa %.0f · Vel. %.2f/s · Alcance %d · Crítico %d%%",
		UIKit.fmt(d.hp), d.atk, d.def, d.aspd, d.range, math.floor(d.crit * 100)) or ""
	UIKit.label({ Position = UDim2.fromOffset(0, 178), Size = UDim2.new(1, 0, 0, 34), TextSize = 12, TextColor3 = T.muted,
		Text = string.format("%s · %s · Nv %d/%d · XP %d/%d\n%s", role.label, Combat.Tiers[pet.tier].label, pet.level, d and d.levelCap or 0, pet.xp or 0, d and d.xpNext or 0, stats), Parent = box })
	UIKit.label({ Position = UDim2.fromOffset(0, 214), Size = UDim2.new(1, 0, 0, 34), TextSize = 12,
		Text = string.format("<b>%s %s</b> (rank %d/%d, recarga %.1fs, custo %d): %s", ab.icon, ab.label, pet.abilityRank or 1, Abilities.MaxRank, d and d.cooldown or ab.cooldown, ab.cost, ab.desc), Parent = box })
	local perkText = ""
	if sp.perk then
		perkText = sp.perk.kind == "luck" and string.format("Passiva: +%d%% sorte (%s) na equipe", math.floor(sp.perk.bonus * 100 + 0.5), LuckConfig.CategoryLabels[sp.perk.category] or "tudo")
			or string.format("Passiva: +%d%% moedas", math.floor(sp.perk.bonus * 100 + 0.5))
	end
	UIKit.label({ Position = UDim2.fromOffset(0, 248), Size = UDim2.new(1, 0, 0, 18), TextSize = 12, TextColor3 = T.luck, Text = perkText, Parent = box })
	local actions = new("Frame", { Position = UDim2.fromOffset(0, 270), Size = UDim2.new(1, 0, 1, -270), BackgroundTransparency = 1, Parent = box })
	local grid = new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 30), CellPadding = UDim2.fromOffset(6, 6), Parent = actions })
	local inTeam = table.find(p.team, uid) ~= nil
	UIKit.button({ Text = inTeam and "Remover da equipe" or "Colocar na equipe", TextSize = 13, BackgroundColor3 = inTeam and Color3.fromRGB(120, 70, 70) or Color3.fromRGB(60, 120, 80), Parent = actions }, function()
		local team = table.clone(p.team)
		if inTeam then
			table.remove(team, table.find(team, uid))
		else
			if #team >= Combat.TeamSize then
				table.remove(team, 1)
			end
			table.insert(team, uid)
		end
		toastResult(State.request("SetTeam", { uids = team }))
	end)
	local evoText = (d and d.evolution) and ("Evoluir: " .. costText(d.evolution)) or "Estágio máximo"
	UIKit.button({ Text = evoText, TextSize = 11, TextWrapped = true, BackgroundColor3 = (d and d.canEvolve) and Color3.fromRGB(150, 110, 40) or T.panel2, Parent = actions }, function()
		toastResult(State.request("Evolve", { uid = uid }))
	end)
	UIKit.button({ Text = d and d.abilityCost and ("Melhorar habilidade: " .. costText(d.abilityCost)) or "Habilidade no máximo", TextSize = 11, TextWrapped = true, Parent = actions }, function()
		toastResult(State.request("UpgradeAbility", { uid = uid }))
	end)
	UIKit.button({ Text = pet.locked and "🔒 Destrancar" or "🔓 Trancar", TextSize = 13, Parent = actions }, function()
		State.request("Lock", { uid = uid })
	end)
	-- acessório: alterna entre os cosméticos possuídos
	local owned = {}
	for id, n in pairs(p.items) do
		if Items.Info[id] and Items.Info[id].kind == "cosmetic" and n > 0 then
			table.insert(owned, id)
		end
	end
	table.sort(owned)
	UIKit.button({ Text = "Acessório: " .. (pet.accessory and Items.label(pet.accessory) or "nenhum"), TextSize = 11, Parent = actions }, function()
		local idx = pet.accessory and table.find(owned, pet.accessory) or 0
		local nextItem = owned[idx + 1]
		toastResult(State.request("Accessory", { uid = uid, item = nextItem }))
	end)
	if not pet.mutation then
		for id, n in pairs(p.items) do
			local info = Items.Info[id]
			if info and info.kind == "catalyst" and n > 0 then
				UIKit.button({ Text = string.format("Aplicar %s (%d)", info.label, n), TextSize = 11, BackgroundColor3 = Color3.fromRGB(110, 60, 140), Parent = actions }, function()
					toastResult(State.request("Catalyst", { uid = uid, item = id }))
				end)
			end
		end
	end
	UIKit.button({ Text = pet.locked and "Trancado" or "Liberar (+essência)", TextSize = 12, BackgroundColor3 = Color3.fromRGB(90, 50, 50), Parent = actions }, function()
		if not pet.locked then
			selectedPet = nil
			toastResult(State.request("Release", { uids = { uid } }))
		end
	end)
	local _ = grid
end

local function petsPanel()
	local p = State.profile
	local header = UIKit.frame({ Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = T.panel2, Parent = content })
	UIKit.pad(header, 6)
	local syn = {}
	for _, id in ipairs(State.derived and State.derived.synergies or {}) do
		for _, s in ipairs(Combat.Synergies) do
			if s.id == id then
				table.insert(syn, "<b>" .. s.label .. "</b>")
			end
		end
	end
	for _, w in ipairs(State.derived and State.derived.sets or {}) do
		table.insert(syn, "<b>Conjunto " .. Worlds.Info[w].name .. "</b> (+" .. math.floor(Combat.WorldSet.damage * 100) .. "% dano lá)")
	end
	UIKit.label({ Size = UDim2.new(1, -150, 1, 0), TextSize = 12, Text = string.format("Equipe %d/%d · Sinergias: %s", #p.team, Combat.TeamSize, #syn > 0 and table.concat(syn, ", ") or "nenhuma"), Parent = header })
	UIKit.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 140, 1, 0), Text = "Melhor equipe", TextSize = 13, Parent = header }, function()
		toastResult(State.request("AutoTeam"))
	end)
	local list = UIKit.scroll({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(0.55, -6, 1, -50), Parent = content })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(122, 64), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local detail = new("Frame", { Position = UDim2.new(0.55, 6, 0, 50), Size = UDim2.new(0.45, -6, 1, -50), BackgroundTransparency = 1, Parent = content })
	local entries = {}
	for uid, pet in pairs(p.pets) do
		local power = State.derived and State.derived.petStats and State.derived.petStats[uid] and State.derived.petStats[uid].power or 0
		table.insert(entries, { uid = uid, pet = pet, power = power })
	end
	table.sort(entries, function(a, b)
		local ta, tb = table.find(p.team, a.uid) ~= nil, table.find(p.team, b.uid) ~= nil
		if ta ~= tb then
			return ta
		end
		return a.power > b.power
	end)
	for i, e in ipairs(entries) do
		local sp = Pets.Species[e.pet.species]
		local card = UIKit.button({ LayoutOrder = i, Text = "", BackgroundColor3 = T.panel2, Parent = list }, function()
			selectedPet = e.uid
			for _, c in ipairs(detail:GetChildren()) do
				c:Destroy()
			end
			petDetail(detail, e.uid)
		end)
		UIKit.stroke(card, rarityColor(sp.rarity), 2, 0.1)
		local mut = e.pet.mutation and Mutations.Info[e.pet.mutation]
		UIKit.label({ Position = UDim2.fromOffset(6, 2), Size = UDim2.new(1, -12, 0, 32), TextSize = 12, Font = T.bold,
			Text = (mut and string.format('<font color="#%s">%s</font>\n', mut.color:ToHex(), e.pet.mutation) or "") .. sp.name, Parent = card })
		UIKit.label({ Position = UDim2.fromOffset(6, 40), Size = UDim2.new(1, -12, 0, 18), TextSize = 11, TextColor3 = T.muted,
			Text = string.format("Nv %d %s%s%s", e.pet.level, string.rep("★", e.pet.tier), table.find(p.team, e.uid) and "  ⚔" or "", e.pet.locked and " 🔒" or ""), Parent = card })
	end
	if #entries == 0 then
		UIKit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "Você ainda não tem pets. Vá até uma estação de ovos (E) para chocar o primeiro!", TextSize = 14, Parent = list })
	end
	if selectedPet and p.pets[selectedPet] then
		petDetail(detail, selectedPet)
	elseif entries[1] then
		petDetail(detail, entries[1].uid)
	end
end

-------------------------------------------------------------------------------
-- ITENS
-------------------------------------------------------------------------------

local KIND_LABEL = { potion = "Poções", egg = "Ovos especiais", catalyst = "Catalisadores", material = "Materiais", cosmetic = "Acessórios", collectible = "Colecionáveis" }

local function itemsPanel()
	local p = State.profile
	local list = UIKit.scroll({ Size = UDim2.fromScale(1, 1), Parent = content })
	UIKit.list(list, Enum.FillDirection.Vertical, 6)
	local order = 0
	for _, kind in ipairs({ "potion", "egg", "catalyst", "material", "cosmetic", "collectible" }) do
		local rows = {}
		for id, n in pairs(p.items) do
			local info = Items.Info[id]
			if info and info.kind == kind and n > 0 then
				table.insert(rows, { id = id, n = n, info = info })
			end
		end
		table.sort(rows, function(a, b)
			return a.info.label < b.info.label
		end)
		if #rows > 0 then
			order += 1
			UIKit.label({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 24), Text = KIND_LABEL[kind], Font = T.title, TextSize = 18, TextColor3 = T.gold, Parent = list })
			for _, r in ipairs(rows) do
				order += 1
				local row = UIKit.frame({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = T.panel2, Parent = list })
				UIKit.frame({ Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = r.info.color, radius = 10, Parent = row })
				local desc = ""
				if kind == "potion" then
					local pot = LuckConfig.Potions[r.id]
					desc = string.format(" — +%d%% sorte (%s) por %s", math.floor(pot.bonus * 100), pot.category == "All" and "tudo" or LuckConfig.CategoryLabels[pot.category], UIKit.time(pot.duration))
				elseif kind == "catalyst" then
					desc = " — aplica " .. r.info.mutation .. " a um pet sem mutação (painel Pets)"
				elseif kind == "egg" then
					desc = " — choque de graça em qualquer estação de ovos"
				end
				UIKit.label({ Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -180, 1, 0), TextSize = 13, Text = string.format("<b>%s</b> x%d%s", r.info.label, r.n, desc), Parent = row })
				if kind == "potion" then
					UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(120, 30), Text = "Beber", TextSize = 13,
						BackgroundColor3 = Color3.fromRGB(60, 130, 80), Parent = row }, function()
						toastResult(State.request("UsePotion", { item = r.id }))
					end)
				elseif kind == "egg" then
					UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(120, 30), Text = "Ver chances", TextSize = 13, Parent = row }, function()
						Panels.open("Egg", r.id)
					end)
				end
			end
		end
	end
	if order == 0 then
		UIKit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "Inventário vazio. Derrote inimigos, abra tesouros e complete missões!", TextSize = 14, Parent = list })
	end
end

-------------------------------------------------------------------------------
-- SORTE
-------------------------------------------------------------------------------

local function luckPanel()
	local l = State.luck
	local p = State.profile
	local left = UIKit.scroll({ Size = UDim2.new(0.5, -6, 1, 0), Parent = content })
	UIKit.list(left, Enum.FillDirection.Vertical, 6)
	UIKit.label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 52), TextSize = 12, TextColor3 = T.muted,
		Text = "A sorte multiplica apenas as chances <b>raras</b>, com limites por categoria e por fonte. Ela nunca garante um resultado: cada raridade tem uma chance máxima por tentativa. Tudo é calculado pelo servidor.", Parent = left })
	if l then
		for i, cat in ipairs(LuckConfig.Categories) do
			local c = l.categories[cat]
			local row = UIKit.frame({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = T.panel2, Parent = left })
			UIKit.label({ Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 20), TextSize = 13, Font = T.bold,
				Text = string.format("%s: <font color=\"#78FF96\">x%.2f</font> <font size=\"11\" color=\"#AAB0CD\">(máx. x%.1f)</font>", LuckConfig.CategoryLabels[cat], c.mult, c.max), Parent = row })
			local _, fill = UIKit.bar(row, { Position = UDim2.fromOffset(8, 25), Size = UDim2.new(1, -16, 0, 12), color = T.luck })
			UIKit.setBar(fill, (c.mult - 1) / math.max(0.01, c.max - 1))
		end
		UIKit.label({ LayoutOrder = 20, Size = UDim2.new(1, 0, 0, 22), Text = "Fontes ativas", Font = T.title, TextSize = 17, TextColor3 = T.gold, Parent = left })
		local any = false
		for i, s in ipairs(l.sources) do
			any = true
			local timeLeft = s.expires and (" — " .. UIKit.time(s.expires - State.now())) or ""
			UIKit.label({ LayoutOrder = 20 + i, Size = UDim2.new(1, 0, 0, 34), TextSize = 12,
				Text = string.format("<b>%s</b> (%s): +%d%% em %s%s", s.label, LuckConfig.SourceLabels[s.type] or s.type, math.floor(s.bonus * 100 + 0.5),
					s.category == "All" and "tudo" or (LuckConfig.CategoryLabels[s.category] or s.category), timeLeft), Parent = left })
		end
		if not any then
			UIKit.label({ LayoutOrder = 21, Size = UDim2.new(1, 0, 0, 30), TextSize = 12, TextColor3 = T.muted, Text = "Nenhuma fonte ativa. Beba poções, complete missões, entre todo dia e colecione espécies.", Parent = left })
		end
		local caps = {}
		for ty, cap in pairs(LuckConfig.SourceCaps) do
			table.insert(caps, string.format("%s até +%d%%", LuckConfig.SourceLabels[ty], math.floor(cap * 100)))
		end
		table.sort(caps)
		UIKit.label({ LayoutOrder = 60, Size = UDim2.new(1, 0, 0, 48), TextSize = 11, TextColor3 = T.muted, Text = "Limite por tipo de fonte: " .. table.concat(caps, " · "), Parent = left })
	end
	local right = UIKit.scroll({ Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), Parent = content })
	UIKit.list(right, Enum.FillDirection.Vertical, 4)
	UIKit.label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 22), Text = "Descobertas importantes", Font = T.title, TextSize = 17, TextColor3 = T.gold, Parent = right })
	for i, h in ipairs(p.history or {}) do
		local r = h.rarity and Rarities.Info[h.rarity]
		UIKit.label({ LayoutOrder = i, Size = UDim2.new(1, 0, 0, 30), TextSize = 12,
			Text = string.format('<font color="#%s">●</font> %s%s', (r and (r.accent or r.color) or T.gold):ToHex(), h.text or "", h.chance and string.format(' <font color="#AAB0CD">(%s)</font>', UIKit.pct(h.chance)) or ""), Parent = right })
	end
	UIKit.label({ LayoutOrder = 100, Size = UDim2.new(1, 0, 0, 22), Text = "Recompensas recentes (sessão)", Font = T.title, TextSize = 17, TextColor3 = T.gold, Parent = right })
	for i, h in ipairs(HUD.rewardHistory) do
		if i > 25 then
			break
		end
		UIKit.label({ LayoutOrder = 100 + i, Size = UDim2.new(1, 0, 0, 18), TextSize = 12, Text = string.format("%s%s — %s", h.notable and "★ " or "", h.text, h.source), Parent = right })
	end
end

-------------------------------------------------------------------------------
-- BESTIÁRIO
-------------------------------------------------------------------------------

local bestiaryTab = "pets"

local function dropOddsPopup(source: string)
	local r = State.request("DropOdds", { source = source })
	if not r.ok then
		return
	end
	clear()
	titleLabel.Text = "Drops: " .. r.name
	local list = UIKit.scroll({ Size = UDim2.new(1, 0, 1, -40), Parent = content })
	UIKit.list(list, Enum.FillDirection.Vertical, 4)
	UIKit.label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 34), TextSize = 12, TextColor3 = T.muted,
		Text = "Chances reais por jogador elegível, já com a sua sorte atual (servidor). ✦ = afetado pela sorte, até o limite indicado.", Parent = list })
	for i, o in ipairs(r.odds) do
		local name = o.item:match("^pet:(.+)$") and ("Pet " .. Pets.Species[o.item:match("^pet:(.+)$")].name) or Items.label(o.item)
		UIKit.label({ LayoutOrder = i, Size = UDim2.new(1, 0, 0, 20), TextSize = 13,
			Text = string.format("%s%s x%d-%d: <b>%s</b>%s", o.luck and "✦ " or "", name, o.min or 1, o.max or 1, UIKit.pct(o.p), (o.luck and o.p > o.base) and string.format(' <font color="#AAB0CD">(base %s)</font>', UIKit.pct(o.base)) or ""), Parent = list })
	end
	UIKit.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(140, 32), Text = "← Voltar", Parent = content }, function()
		Panels.open("Bestiary")
	end)
end

local function bestiaryPanel()
	local p = State.profile
	local tabs = new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Parent = content })
	UIKit.list(tabs, Enum.FillDirection.Horizontal, 6)
	for _, t in ipairs({ { "pets", "Pets" }, { "foes", "Inimigos e bosses" }, { "collection", "Coleção" } }) do
		UIKit.button({ Size = UDim2.fromOffset(170, 30), Text = t[2], TextSize = 13, BackgroundColor3 = bestiaryTab == t[1] and Color3.fromRGB(80, 90, 150) or T.panel2, Parent = tabs }, function()
			bestiaryTab = t[1]
			Panels.open("Bestiary")
		end)
	end
	local list = UIKit.scroll({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -38), Parent = content })
	local counts = CollectionLogic.counts(p)
	if bestiaryTab == "pets" then
		new("UIGridLayout", { CellSize = UDim2.fromOffset(170, 70), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		local ids = {}
		for id in pairs(Pets.Species) do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			local sa, sb = Pets.Species[a], Pets.Species[b]
			if sa.world ~= sb.world then
				return Worlds.indexOf(sa.world) < Worlds.indexOf(sb.world)
			end
			return Rarities.rank(sa.rarity) < Rarities.rank(sb.rarity)
		end)
		for i, id in ipairs(ids) do
			local sp = Pets.Species[id]
			local e = p.bestiary.pets[id]
			local card = UIKit.frame({ LayoutOrder = i, BackgroundColor3 = T.panel2, Parent = list })
			UIKit.stroke(card, rarityColor(sp.rarity), 1.5, e and 0.1 or 0.6)
			local muts = {}
			if e then
				for _, mid in ipairs(Mutations.Order) do
					if e.muts[mid] then
						table.insert(muts, string.format('<font color="#%s">%s</font>', Mutations.Info[mid].color:ToHex(), mid))
					end
				end
			end
			UIKit.label({ Position = UDim2.fromOffset(6, 2), Size = UDim2.new(1, -12, 1, -4), TextSize = 12,
				Text = e and string.format("<b>%s</b>\n%s · %s · x%d\n%s", sp.name, Rarities.Info[sp.rarity].label, Worlds.Info[sp.world].name, e.n, table.concat(muts, " "))
					or string.format("<b>???</b>\n%s · %s", Rarities.Info[sp.rarity].label, Worlds.Info[sp.world].name), Parent = card })
		end
	elseif bestiaryTab == "foes" then
		UIKit.list(list, Enum.FillDirection.Vertical, 4)
		local order = 0
		for _, wid in ipairs(Worlds.Order) do
			order += 1
			UIKit.label({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 22), Text = Worlds.Info[wid].name, Font = T.title, TextSize = 16, TextColor3 = T.gold, Parent = list })
			local foes = {}
			for id, e in pairs(Enemies.Info) do
				if e.world == wid then
					table.insert(foes, { id = id, name = e.name, kind = "enemy", level = e.level })
				end
			end
			local bossId = Worlds.Info[wid].bossId
			table.insert(foes, { id = bossId, name = Bosses.Info[bossId].name .. " (BOSS)", kind = "boss", level = Bosses.Info[bossId].level })
			table.sort(foes, function(a, b)
				return a.level < b.level
			end)
			for _, f in ipairs(foes) do
				order += 1
				local rec = f.kind == "boss" and p.bestiary.bosses[f.id] or p.bestiary.enemies[f.id]
				local row = UIKit.frame({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 34), BackgroundColor3 = T.panel2, Parent = list })
				UIKit.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -160, 1, 0), TextSize = 13,
					Text = rec and string.format("<b>%s</b> Nv %d — derrotado %dx", f.name, f.level, rec.n) or string.format("<b>???</b> Nv %d — ainda não registrado", f.level), Parent = row })
				UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(140, 26), Text = "Ver drops", TextSize = 12, Parent = row }, function()
					dropOddsPopup(f.id)
				end)
			end
		end
	else
		UIKit.list(list, Enum.FillDirection.Vertical, 4)
		UIKit.label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 22), TextSize = 13,
			Text = string.format("Espécies: %d/%d · Mutações: %d/%d · Inimigos/bosses: %d", counts.species, Pets.count(), counts.mutations, #Mutations.Order, counts.enemies), Parent = list })
		for i, m in ipairs(Exploration.CollectionMilestones) do
			local done = CollectionLogic.isComplete(m, counts)
			local claimed = p.collectionClaimed[m.id]
			local row = UIKit.frame({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = T.panel2, Parent = list })
			local need = {}
			for k, n in pairs(m.need) do
				table.insert(need, string.format("%s %d/%d", k == "species" and "espécies" or k == "mutations" and "mutações" or "inimigos", math.min(counts[k] or 0, n), n))
			end
			UIKit.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -170, 1, 0), TextSize = 12, Text = string.format("<b>%s</b> — %s — %s", m.label, table.concat(need, ", "), costText(m.reward)), Parent = row })
			UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(150, 28), TextSize = 12,
				Text = claimed and "Resgatado" or done and "Resgatar" or "Em andamento", BackgroundColor3 = (done and not claimed) and Color3.fromRGB(70, 150, 90) or T.panel, Parent = row }, function()
				if done and not claimed then
					toastResult(State.request("ClaimCollection", { id = m.id }))
				end
			end)
		end
	end
end

-------------------------------------------------------------------------------
-- MISSÕES
-------------------------------------------------------------------------------

local function rewardText(r)
	local s = costText(r)
	if r.luck then
		s = (s ~= "" and s .. ", " or "") .. string.format("+%d%% sorte (%s) %s", math.floor(r.luck.bonus * 100), LuckConfig.CategoryLabels[r.luck.category] or "tudo", UIKit.time(r.luck.duration))
	end
	return s
end

local function questsPanel()
	local p = State.profile
	local list = UIKit.scroll({ Size = UDim2.fromScale(1, 1), Parent = content })
	UIKit.list(list, Enum.FillDirection.Vertical, 6)
	UIKit.label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 22), Text = "História", Font = T.title, TextSize = 18, TextColor3 = T.gold, Parent = list })
	for i, q in ipairs(Quests.Story) do
		local idx = p.quests.storyIndex
		local status = i < idx and "✔" or i == idx and string.format("%d/%d", p.quests.storyProgress, q.goal.count) or "🔒"
		if i <= idx + 1 then
			local row = UIKit.frame({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 42), BackgroundColor3 = i == idx and Color3.fromRGB(50, 56, 90) or T.panel2, Parent = list })
			UIKit.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -150, 1, 0), TextSize = 12, Text = string.format("<b>%s</b> — %s\n<font color=\"#AAB0CD\">%s</font>", q.label, q.desc, rewardText(q.reward)), Parent = row })
			local canClaim = i == idx and p.quests.storyProgress >= q.goal.count
			UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(130, 28), Text = canClaim and "Resgatar" or status, TextSize = 12,
				BackgroundColor3 = canClaim and Color3.fromRGB(70, 150, 90) or T.panel, Parent = row }, function()
				if canClaim then
					toastResult(State.request("ClaimStory"))
				end
			end)
		end
	end
	UIKit.label({ LayoutOrder = 100, Size = UDim2.new(1, 0, 0, 22), Text = "Diárias (renovam à 00:00 UTC)", Font = T.title, TextSize = 18, TextColor3 = T.gold, Parent = list })
	local d = p.quests.daily
	for i, id in ipairs(d.ids or {}) do
		local q = Quests.findDaily(id)
		if q then
			local prog = d.progress[id] or 0
			local claimed = d.claimed[id]
			local done = prog >= q.goal.count
			local row = UIKit.frame({ LayoutOrder = 100 + i, Size = UDim2.new(1, -8, 0, 42), BackgroundColor3 = T.panel2, Parent = list })
			UIKit.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -150, 1, 0), TextSize = 12, Text = string.format("<b>%s</b> — %s (%d/%d)\n<font color=\"#AAB0CD\">%s</font>", q.label, q.desc, prog, q.goal.count, rewardText(q.reward)), Parent = row })
			UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(130, 28), TextSize = 12,
				Text = claimed and "Resgatada" or done and "Resgatar" or "Em andamento", BackgroundColor3 = (done and not claimed) and Color3.fromRGB(70, 150, 90) or T.panel, Parent = row }, function()
				if done and not claimed then
					toastResult(State.request("ClaimDaily", { id = id }))
				end
			end)
		end
	end
end

-------------------------------------------------------------------------------
-- MAPA
-------------------------------------------------------------------------------

local function mapPanel()
	local p = State.profile
	local list = UIKit.scroll({ Size = UDim2.fromScale(1, 1), Parent = content })
	UIKit.list(list, Enum.FillDirection.Vertical, 8)
	for i, id in ipairs(Worlds.Order) do
		local w = Worlds.Info[id]
		local unlocked = p.worlds[id]
		local prevOk = i == 1 or p.worlds[Worlds.Order[i - 1]]
		local row = UIKit.frame({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 62), BackgroundColor3 = T.panel2, Parent = list })
		UIKit.stroke(row, w.palette.accent, 2, unlocked and 0.1 or 0.6)
		local boss = Bosses.Info[w.bossId]
		UIKit.label({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -190, 1, 0), TextSize = 13,
			Text = string.format("<b>%d. %s</b>\nBoss: %s · Atributos de pets x%.2f", i, w.name, boss.name, w.statMult), Parent = row })
		local text = unlocked and "Viajar" or prevOk and string.format("Abrir (%s moedas)", UIKit.fmt(w.unlockCost)) or "Bloqueado"
		UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(170, 36), Text = text, TextSize = 13,
			BackgroundColor3 = unlocked and Color3.fromRGB(60, 110, 160) or prevOk and Color3.fromRGB(150, 110, 40) or T.panel, Parent = row }, function()
			if unlocked then
				local r = State.request("Teleport", { world = id })
				toastResult(r)
				if r.ok then
					Panels.close()
				end
			elseif prevOk then
				toastResult(State.request("UnlockWorld", { world = id }))
			end
		end)
	end
end

-------------------------------------------------------------------------------
-- OPÇÕES (+ testes no Studio)
-------------------------------------------------------------------------------

local function settingsPanel()
	local p = State.profile
	local list = UIKit.scroll({ Size = UDim2.fromScale(1, 1), Parent = content })
	UIKit.list(list, Enum.FillDirection.Vertical, 8)
	local function toggle(order, label, key, value, nextValue)
		UIKit.button({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 38), Text = label .. ": " .. tostring(value), TextSize = 14, Parent = list }, function()
			State.request("Settings", { key = key, value = nextValue })
			task.wait(0.3)
			Panels.open("Settings")
		end)
	end
	toggle(1, "Anúncios globais de descobertas", "announcements", p.settings.announcements and "ligado" or "desligado", not p.settings.announcements)
	toggle(2, "Números de dano", "damageNumbers", p.settings.damageNumbers ~= false and "ligado" or "desligado", p.settings.damageNumbers == false)
	toggle(3, "Qualidade de efeitos", "vfx", p.settings.vfx == "Low" and "Baixa" or "Alta", p.settings.vfx == "Low" and "High" or "Low")
	UIKit.label({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 70), TextSize = 12, TextColor3 = T.muted,
		Text = "Controles: clique/toque num inimigo para mirar e atacar · F ataque · 1-4 habilidades dos pets · Tab/Q próximo alvo · clique num recurso para os pets minerarem · E nas estações e portais." ..
			(State.memoryMode and "\n<font color=\"#FF6464\">Modo memória: progresso não está sendo salvo.</font>" or ""), Parent = list })
	if RunService:IsStudio() then
		UIKit.label({ LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 22), Text = "Testes (somente no Studio)", Font = T.title, TextSize = 17, TextColor3 = T.bad, Parent = list })
		for i, c in ipairs({ { "currency", "+1M moedas, +50K essência" }, { "items", "Todos os itens" }, { "unlock", "Desbloquear mundos" }, { "levels", "Equipe no nível máximo" },
			{ "luck_event", "Evento de sorte +100% (10 min)" }, { "boss_phase", "Boss atual: -35% vida (testar fases)" }, { "treasure", "Gerar tesouro" }, { "star", "Gerar Estrela Errante" },
			{ "luck_report", "Mostrar multiplicadores (servidor)" } }) do
			UIKit.button({ LayoutOrder = 10 + i, Size = UDim2.new(1, -8, 0, 32), Text = c[2], TextSize = 13, BackgroundColor3 = Color3.fromRGB(90, 50, 60), Parent = list }, function()
				toastResult(State.request("Dev", { cmd = c[1] }))
			end)
		end
	end
end

-------------------------------------------------------------------------------
-- OVO
-------------------------------------------------------------------------------

local function eggPanel(eggId: string)
	local r = State.request("EggOdds", { egg = eggId })
	if not r.ok then
		return
	end
	local egg = Eggs.Info[eggId]
	titleLabel.Text = r.name
	local list = UIKit.scroll({ Size = UDim2.new(0.6, -6, 1, -52), Parent = content })
	UIKit.list(list, Enum.FillDirection.Vertical, 4)
	UIKit.label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 30), TextSize = 12, TextColor3 = T.muted,
		Text = string.format("Chances reais com a sua sorte atual (Pets raros x%.2f). Valores calculados pelo servidor.", r.mult), Parent = list })
	for i, o in ipairs(r.entries) do
		local sp = Pets.Species[o.key]
		local rar = Rarities.Info[sp.rarity]
		local row = UIKit.frame({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, o.reason and 40 or 28), BackgroundColor3 = T.panel2, Parent = list })
		UIKit.stroke(row, rar.color, 1.5, 0.3)
		local changed = math.abs(o.p - o.base) > 1e-9
		UIKit.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), TextSize = 13,
			Text = string.format('<font color="#%s"><b>%s</b></font> %s — <b>%s</b>%s%s', (rar.accent or rar.color):ToHex(), rar.label, sp.name, UIKit.pct(o.p),
				changed and string.format(' <font color="#AAB0CD">(base %s)</font>', UIKit.pct(o.base)) or "",
				o.reason and ('\n<font color="#FF8C78">' .. o.reason .. "</font>") or ""), Parent = row })
	end
	local side = UIKit.scroll({ Position = UDim2.new(0.6, 6, 0, 0), Size = UDim2.new(0.4, -6, 1, -52), Parent = content })
	UIKit.list(side, Enum.FillDirection.Vertical, 4)
	UIKit.label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 22), Text = "Mutações", Font = T.title, TextSize = 16, TextColor3 = T.gold, Parent = side })
	UIKit.label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), TextSize = 12,
		Text = string.format("Chance de mutar: <b>%s</b> por ovo (máx. %s)", UIKit.pct(r.mutation.chance), UIKit.pct(r.mutation.max)), Parent = side })
	for i, m in ipairs(r.mutation.odds) do
		UIKit.label({ LayoutOrder = 1 + i, Size = UDim2.new(1, 0, 0, 18), TextSize = 12,
			Text = string.format('<font color="#%s">%s</font>: %s', Mutations.Info[m.key].color:ToHex(), m.key, UIKit.pct(m.p)), Parent = side })
	end
	UIKit.label({ LayoutOrder = 20, Size = UDim2.new(1, 0, 0, 22), Text = "Bônus ativos", Font = T.title, TextSize = 16, TextColor3 = T.gold, Parent = side })
	for i, s in ipairs(r.sources) do
		UIKit.label({ LayoutOrder = 20 + i, Size = UDim2.new(1, 0, 0, 30), TextSize = 11,
			Text = string.format("%s: +%d%% (%s)%s", s.label, math.floor(s.bonus * 100 + 0.5), s.category == "All" and "tudo" or LuckConfig.CategoryLabels[s.category],
				s.expires and (" " .. UIKit.time(s.expires - State.now())) or ""), Parent = side })
	end
	if #r.sources == 0 then
		UIKit.label({ LayoutOrder = 21, Size = UDim2.new(1, 0, 0, 20), TextSize = 11, TextColor3 = T.muted, Text = "Nenhum bônus que afete ovos.", Parent = side })
	end
	local function hatchRes(res)
		if res.ok then
			Panels.close()
			Fx.hatch(res.results, egg.color)
		else
			toastResult(res)
		end
	end
	if r.special then
		UIKit.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(260, 44), Text = string.format("Chocar (você tem %d)", r.owned or 0),
			BackgroundColor3 = Color3.fromRGB(150, 90, 200), Parent = content }, function()
			hatchRes(State.request("HatchItem", { egg = eggId }))
		end)
	else
		local cur = Items.label(r.currency)
		UIKit.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(230, 44), Text = string.format("Chocar 1 (%s %s)", UIKit.fmt(r.cost), cur),
			BackgroundColor3 = Color3.fromRGB(60, 130, 80), Parent = content }, function()
			hatchRes(State.request("Hatch", { egg = eggId, count = 1 }))
		end)
		UIKit.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 240, 1, 0), Size = UDim2.fromOffset(230, 44), Text = string.format("Chocar 3 (%s %s)", UIKit.fmt(r.cost * 3), cur),
			BackgroundColor3 = Color3.fromRGB(50, 110, 140), Parent = content }, function()
			hatchRes(State.request("Hatch", { egg = eggId, count = 3 }))
		end)
	end
end

-------------------------------------------------------------------------------

local BUILDERS = { Pets = petsPanel, Items = itemsPanel, Luck = luckPanel, Bestiary = bestiaryPanel, Quests = questsPanel, Map = mapPanel, Settings = settingsPanel }
local TITLES = { Pets = "Pets e Equipe", Items = "Itens", Luck = "Sorte", Bestiary = "Bestiário", Quests = "Missões", Map = "Mapa das Ilhas", Settings = "Opções" }

function Panels.open(name: string, arg)
	if not State.profile then
		return
	end
	current = { name = name, arg = arg }
	modal.Visible = true
	clear()
	titleLabel.Text = TITLES[name] or name
	if name == "Egg" then
		eggPanel(arg)
	elseif BUILDERS[name] then
		BUILDERS[name]()
	end
end

function Panels.close()
	modal.Visible = false
	current = nil
end

function Panels.init()
	gui = UIKit.screen("Panels", 10)
	modal = UIKit.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(820, 520), BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.04, Visible = false, Parent = gui })
	UIKit.stroke(modal, T.stroke, 2, 0.1)
	titleLabel = UIKit.label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 32), Text = "", Font = T.title, TextSize = 24, Parent = modal })
	UIKit.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(40, 32), Text = "✕", TextSize = 18,
		BackgroundColor3 = Color3.fromRGB(120, 50, 60), Parent = modal }, Panels.close)
	content = new("Frame", { Position = UDim2.fromOffset(14, 48), Size = UDim2.new(1, -28, 1, -60), BackgroundTransparency = 1, Parent = modal })
	HUD.openPanel = Panels.open
	State.on("OpenEgg", function(p)
		Panels.open("Egg", p.egg)
	end)
	State.on("OpenUnlock", function()
		Panels.open("Map")
	end)
	-- reconstrói o painel aberto quando o estado muda (exceto o de ovo, que consulta o servidor)
	local pending = false
	State.on("State", function()
		if current and current.name ~= "Egg" and modal.Visible and not pending then
			pending = true
			task.delay(0.15, function()
				pending = false
				if current and current.name ~= "Egg" then
					Panels.open(current.name, current.arg)
				end
			end)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape or (not processed and input.KeyCode == Enum.KeyCode.M) then
			if modal.Visible then
				Panels.close()
			elseif input.KeyCode == Enum.KeyCode.M then
				Panels.open("Map")
			end
		end
	end)
end

return Panels

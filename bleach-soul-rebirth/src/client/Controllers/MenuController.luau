-- Menus: Status/atributos, árvore de habilidades, inventário, missões, poderes (invocação/compra),
-- viagem rápida, loja, forja, configurações e painel de desenvolvimento (somente Studio).
-- Cada aba é redesenhada quando o perfil sincroniza; toda ação passa pelo servidor.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Config.Progression)
local SkillTrees = require(Shared.Config.SkillTrees)
local Items = require(Shared.Config.Items)
local Quests = require(Shared.Config.Quests)
local Powers = require(Shared.Config.Powers)
local Factions = require(Shared.Config.Factions)
local Abilities = require(Shared.Config.Abilities)
local Elements = require(Shared.Config.Elements)
local Zones = require(Shared.Config.Zones)
local InventoryLogic = require(Shared.Logic.InventoryLogic)

local Controllers = script.Parent
local Kit = require(script.Parent.Parent.UI.Kit)
local DataController = require(Controllers.DataController)
local InputController = require(Controllers.InputController)
local SoundController = require(Controllers.SoundController)
local HUDController = require(Controllers.HUDController)
local DialogueController = require(Controllers.DialogueController)
local CameraController = require(Controllers.CameraController)
local VFX = require(Controllers.VFXController)
local FxController = require(Controllers.FxController)

local MenuController = {}
MenuController.SideGui = nil :: ScreenGui?

local T = Kit.Theme
local player = Players.LocalPlayer
local gui: ScreenGui
local panel: Frame
local content: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local header: TextLabel
local status: TextLabel
local openTab: string? = nil

local TABS = {
	{ id = "Status", label = "Status", kanji = "体" },
	{ id = "Skills", label = "Árvore", kanji = "技" },
	{ id = "Inventory", label = "Inventário", kanji = "袋" },
	{ id = "Quests", label = "Missões", kanji = "任" },
	{ id = "Powers", label = "Poderes", kanji = "魂" },
	{ id = "Travel", label = "Viagem", kanji = "門" },
	{ id = "Shop", label = "Loja", kanji = "店", hidden = true },
	{ id = "Forge", label = "Forja", kanji = "鍛", hidden = true },
	{ id = "Settings", label = "Opções", kanji = "設" },
	{ id = "Dev", label = "Dev", kanji = "試", studio = true },
}

local function flash(text: string, ok: boolean)
	status.Text = text
	status.TextColor3 = if ok then T.Success else Color3.fromRGB(255, 140, 120)
	status.TextTransparency = 0
	task.delay(2.5, function()
		if status.Text == text then
			Kit.tween(status, 0.4, { TextTransparency = 1 })
		end
	end)
end

-- Envia pedido e mostra o resultado no rodapé.
local function request(kind: string, payload: any?, successText: string?): (boolean, any)
	SoundController.Play("UIClick")
	local ok, result = DataController.Request(kind, payload)
	if ok then
		if successText then
			flash(successText, true)
		end
	else
		flash(tostring(result or "Falhou"), false)
	end
	return ok, result
end

local function clear()
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function section(title: string, order: number)
	return Kit.label(title, 18, {
		Size = UDim2.new(1, 0, 0, 26),
		Font = T.FontTitle,
		TextColor3 = T.Gold,
		LayoutOrder = order,
		Parent = content,
	})
end

local function row(order: number, height: number?): Frame
	return Kit.new("Frame", {
		BackgroundColor3 = T.PanelLight,
		BackgroundTransparency = 0.3,
		Size = UDim2.new(1, 0, 0, height or 48),
		LayoutOrder = order,
		Parent = content,
	}, { Kit.corner(8) })
end

local function rarityColor(rarity: string?): Color3
	local r = rarity and (Items.Rarities[rarity] or Powers.Rarities[rarity])
	return r and r.color or T.Text
end

-- ============================================================
-- Abas
-- ============================================================
local Render = {}

function Render.Status(profile)
	local need = Progression.xpToNext(profile.level)
	section(string.format("Nível %d  ·  XP %d / %d", profile.level, profile.xp, need), 1)
	Kit.label(
		string.format(
			"Pontos de atributo: %d   ·   Pontos de habilidade: %d   ·   %d Kan   ·   %d Fragmentos",
			profile.statPoints,
			profile.skillPoints,
			profile.currency.Kan,
			profile.currency.Shards
		),
		15,
		{ Size = UDim2.new(1, 0, 0, 22), TextColor3 = T.Muted, LayoutOrder = 2, Parent = content }
	)
	for i, attr in Progression.AttributeOrder do
		local def = Progression.Attributes[attr]
		local r = row(10 + i, 56)
		Kit.label(def.kanji, 26, {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.fromOffset(36, 56),
			Font = T.FontTitle,
			TextColor3 = T.Accent,
			Parent = r,
		})
		Kit.label(
			string.format("%s  %d", def.name, profile.stats[attr] or 0),
			17,
			{ Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -230, 0, 22), Font = T.FontTitle, Parent = r }
		)
		Kit.label(def.desc, 13, {
			Position = UDim2.fromOffset(56, 28),
			Size = UDim2.new(1, -230, 0, 20),
			TextColor3 = T.Muted,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = r,
		})
		for j, amount in { 1, 5 } do
			local b = Kit.button("+" .. amount, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12 - (2 - j) * 70, 0.5, 0),
				Size = UDim2.fromOffset(60, 34),
			}, function()
				request("AllocateStat", { attribute = attr, amount = amount })
			end)
			b.Parent = r
			b.Active = profile.statPoints >= amount
			b.TextTransparency = if profile.statPoints >= amount then 0 else 0.6
		end
	end
	local reset = Kit.button(
		"Redistribuir pontos (grátis)",
		{ Size = UDim2.fromOffset(260, 36), LayoutOrder = 30 },
		function()
			request("ResetStats", nil, "Pontos devolvidos")
		end
	)
	reset.Parent = content

	section("Registro", 40)
	Kit.label(
		string.format(
			"Inimigos derrotados: %d   ·   Chefes: %d   ·   Mortes: %d   ·   Tempo: %d min",
			profile.record.kills,
			profile.record.bossKills,
			profile.record.deaths,
			math.floor(profile.record.playSeconds / 60)
		),
		14,
		{ Size = UDim2.new(1, 0, 0, 22), TextColor3 = T.Muted, LayoutOrder = 41, Parent = content }
	)
	local faction = Factions.get(profile.faction)
	if faction then
		section("Formas", 50)
		for i, tier in { "Tier1", "Tier2" } do
			local form = faction.forms[tier]
			local unlocked = profile.unlocks[tier]
			Kit.label(
				string.format(
					"%s %s — %s (nível %d)",
					form.kanji,
					form.name,
					if unlocked then "DESPERTO" else "bloqueado",
					form.requiredLevel
				),
				15,
				{
					Size = UDim2.new(1, 0, 0, 22),
					TextColor3 = if unlocked then T.Success else T.Muted,
					LayoutOrder = 50 + i,
					Parent = content,
				}
			)
		end
		if faction.maskAvailable then
			Kit.label(
				string.format(
					"仮面 Máscara Hollow — %s (nível %d)",
					if profile.unlocks.Mask then "DESPERTA" else "bloqueada",
					Factions.Mask.requiredLevel
				),
				15,
				{
					Size = UDim2.new(1, 0, 0, 22),
					TextColor3 = if profile.unlocks.Mask then T.Success else T.Muted,
					LayoutOrder = 53,
					Parent = content,
				}
			)
		end
	end
end

function Render.Skills(profile)
	local tree = SkillTrees.get(profile.faction)
	if not tree then
		section("Escolha uma facção primeiro", 1)
		return
	end
	section(string.format("Pontos de habilidade: %d", profile.skillPoints), 1)
	Kit.label(
		"Ramos: Lâmina (corpo a corpo) · Núcleo (mobilidade/vida) · Espírito (habilidades). A especialização final é exclusiva.",
		13,
		{ Size = UDim2.new(1, 0, 0, 34), TextWrapped = true, TextColor3 = T.Muted, LayoutOrder = 2, Parent = content }
	)
	local grid = Kit.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 4 * 96 + 10), LayoutOrder = 3, Parent = content }
	)
	local columns = 5
	for id, node in tree do
		local owned = profile.skills[id] == true
		local reqsMet = true
		for _, req in node.requires do
			if not profile.skills[req] then
				reqsMet = false
			end
		end
		local available = not owned and reqsMet and profile.level >= node.level and profile.skillPoints >= node.cost
		local cell = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = if owned
				then Color3.fromRGB(40, 60, 45)
				elseif available then Color3.fromRGB(55, 50, 25)
				else T.PanelLight,
			BackgroundTransparency = 0.1,
			Text = "",
			Position = UDim2.new((node.x - 1) / columns, 4, 0, (node.y - 1) * 96 + 4),
			Size = UDim2.new(1 / columns, -8, 0, 88),
			Parent = grid,
		}, {
			Kit.corner(8),
			Kit.stroke(
				if owned then T.Success elseif available then T.Gold else Color3.new(1, 1, 1),
				1.5,
				if owned or available then 0.2 else 0.8
			),
		})
		Kit.label(node.name, 13, {
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.new(1, -16, 0, 16),
			Font = T.FontTitle,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = cell,
		})
		Kit.label(node.desc, 11, {
			Position = UDim2.fromOffset(8, 24),
			Size = UDim2.new(1, -16, 0, 42),
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = T.Muted,
			Font = T.Font,
			Parent = cell,
		})
		Kit.label(if owned then "✔ Aprendido" else string.format("Nv %d · %d pt", node.level, node.cost), 11, {
			Position = UDim2.new(0, 8, 1, -18),
			Size = UDim2.new(1, -16, 0, 14),
			TextColor3 = if owned then T.Success else T.Gold,
			Parent = cell,
		})
		cell.Activated:Connect(function()
			if not owned then
				request("UnlockSkill", { node = id }, node.name .. " aprendido!")
			end
		end)
	end
end

function Render.Inventory(profile)
	section(
		string.format(
			"Inventário (%d/%d)  ·  %d Kan",
			#profile.inventory.items,
			InventoryLogic.MaxEntries,
			profile.currency.Kan
		),
		1
	)
	local equippedSet = {}
	for slot, uid in profile.equipped do
		equippedSet[uid] = slot
	end
	local entries = table.clone(profile.inventory.items)
	table.sort(entries, function(a, b)
		local da, db = Items.List[a.id], Items.List[b.id]
		local ka, kb = da and da.kind or "", db and db.kind or ""
		if ka ~= kb then
			return ka > kb
		end
		local ra = da and Items.Rarities[da.rarity].order or 0
		local rb = db and Items.Rarities[db.rarity].order or 0
		return ra > rb
	end)
	if #entries == 0 then
		Kit.label(
			"Vazio. Derrote Hollows para obter materiais.",
			15,
			{ Size = UDim2.new(1, 0, 0, 24), TextColor3 = T.Muted, LayoutOrder = 2, Parent = content }
		)
	end
	for i, entry in entries do
		local def = Items.List[entry.id]
		if def then
			local r = row(10 + i, 54)
			local color = rarityColor(def.rarity)
			Kit.new(
				"Frame",
				{ BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 0), Parent = r },
				{ Kit.corner(2) }
			)
			Kit.label(def.kanji or "?", 24, {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(34, 54),
				Font = T.FontTitle,
				TextColor3 = color,
				Parent = r,
			})
			local statsText = ""
			if def.stats then
				local parts = {}
				for attr, value in def.stats do
					table.insert(parts, "+" .. value .. " " .. Progression.Attributes[attr].name)
				end
				table.sort(parts)
				statsText = "  ·  " .. table.concat(parts, ", ")
			end
			Kit.label(
				def.name
					.. (if entry.qty > 1 then " ×" .. entry.qty else "")
					.. (if equippedSet[entry.uid] then "  [EQUIPADO]" else ""),
				15,
				{
					Position = UDim2.fromOffset(52, 6),
					Size = UDim2.new(1, -300, 0, 20),
					Font = T.FontTitle,
					TextColor3 = color,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = r,
				}
			)
			Kit.label(def.desc .. statsText, 12, {
				Position = UDim2.fromOffset(52, 28),
				Size = UDim2.new(1, -300, 0, 18),
				TextColor3 = T.Muted,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = r,
			})
			local x = -12
			local function action(text: string, fn: () -> ())
				local b = Kit.button(text, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, x, 0.5, 0),
					Size = UDim2.fromOffset(96, 32),
					TextSize = 14,
				}, fn)
				b.Parent = r
				x -= 104
			end
			if def.kind == "Weapon" or def.kind == "Accessory" then
				action(if equippedSet[entry.uid] then "Remover" else "Equipar", function()
					request("Equip", { uid = entry.uid })
				end)
			elseif def.kind == "Consumable" then
				action("Usar", function()
					request("UseItem", { item = entry.id }, def.name .. " usado")
				end)
			end
			if not equippedSet[entry.uid] then
				action("Vender " .. (def.sell or 1), function()
					request("Sell", { uid = entry.uid, qty = 1 }, "Vendido")
				end)
			end
		end
	end
end

function Render.Quests(profile)
	section("História", 1)
	local order = 2
	local any = false
	for _, id in Quests.StoryOrder do
		local entry = profile.quests.active[id]
		local quest = Quests.Story[id]
		if entry then
			any = true
			local r = row(order, 30 + #quest.objectives * 20 + 26)
			order += 1
			local tracked = profile.quests.tracked == id
			Kit.label((if tracked then "◆ " else "") .. quest.name, 16, {
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -150, 0, 20),
				Font = T.FontTitle,
				TextColor3 = if tracked then T.Gold else T.Text,
				Parent = r,
			})
			Kit.label(quest.desc, 12, {
				Position = UDim2.fromOffset(12, 26),
				Size = UDim2.new(1, -150, 0, 18),
				TextColor3 = T.Muted,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = r,
			})
			for i, objective in quest.objectives do
				local current, target = entry.progress[i] or 0, objective.count or 1
				Kit.label(
					string.format(
						"%s %s (%d/%d)",
						if current >= target then "✔" else "•",
						objective.label,
						math.min(current, target),
						target
					),
					13,
					{
						Position = UDim2.fromOffset(20, 26 + i * 20),
						Size = UDim2.new(1, -170, 0, 18),
						TextColor3 = if current >= target then T.Success else T.Text,
						Parent = r,
					}
				)
			end
			if not tracked then
				local b = Kit.button("Rastrear", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -12, 0, 8),
					Size = UDim2.fromOffset(110, 30),
					TextSize = 14,
				}, function()
					request("TrackQuest", { quest = id })
				end)
				b.Parent = r
			end
		end
	end
	if not any then
		Kit.label(
			"Nenhuma missão ativa. Fale com seu mentor na praça de Karakura.",
			14,
			{ Size = UDim2.new(1, 0, 0, 22), TextColor3 = T.Muted, LayoutOrder = order, Parent = content }
		)
		order += 1
	end
	section("Diárias (renovam à 00:00 UTC)", 50)
	local daily = profile.quests.daily
	for i, id in daily.ids or {} do
		local quest = Quests.DailyPool[id]
		local progress = daily.progress[id] or {}
		if quest then
			local done = daily.claimed[id] == true
			local r = row(50 + i, 52)
			Kit.label((if done then "✔ " else "") .. quest.name, 15, {
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -24, 0, 20),
				Font = T.FontTitle,
				TextColor3 = if done then T.Success else T.Text,
				Parent = r,
			})
			local objective = quest.objectives[1]
			Kit.label(
				string.format(
					"%s (%d/%d)  ·  %d XP, %d Kan, %d ✦",
					objective.label,
					math.min(progress[1] or 0, objective.count or 1),
					objective.count or 1,
					quest.rewards.xp or 0,
					quest.rewards.kan or 0,
					quest.rewards.shards or 0
				),
				12,
				{
					Position = UDim2.fromOffset(12, 28),
					Size = UDim2.new(1, -24, 0, 18),
					TextColor3 = T.Muted,
					Parent = r,
				}
			)
		end
	end
	section("Concluídas", 80)
	local done = {}
	for _, id in Quests.StoryOrder do
		if profile.quests.completed[id] then
			table.insert(done, Quests.Story[id].name)
		end
	end
	Kit.label(if #done > 0 then table.concat(done, " · ") else "—", 13, {
		Size = UDim2.new(1, 0, 0, 40),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = T.Muted,
		LayoutOrder = 81,
		Parent = content,
	})
end

function Render.Powers(profile)
	local faction = Factions.get(profile.faction)
	if not faction then
		section("Escolha uma facção primeiro", 1)
		return
	end
	local g = Powers.Gacha
	section(string.format("Fragmentos Espirituais: %d ✦", profile.currency.Shards), 1)
	Kit.label(
		string.format(
			"Invocar custa %d ✦. Garantia: Épico+ a cada %d invocações e o melhor poder a cada %d. Ou compre qualquer poder diretamente por %d ✦ — progressão sem depender de sorte.",
			g.rollCost,
			g.epicPity,
			g.legendaryPity,
			g.directCost
		),
		13,
		{ Size = UDim2.new(1, 0, 0, 36), TextWrapped = true, TextColor3 = T.Muted, LayoutOrder = 2, Parent = content }
	)
	Kit.label(
		string.format(
			"Pity: %d/%d (Épico)  ·  %d/%d (Lendário)",
			profile.gacha.epicPity,
			g.epicPity,
			profile.gacha.legendaryPity,
			g.legendaryPity
		),
		13,
		{ Size = UDim2.new(1, 0, 0, 20), TextColor3 = T.Accent, LayoutOrder = 3, Parent = content }
	)
	local roll = Kit.button(
		"Invocar (" .. g.rollCost .. " ✦)",
		{ Size = UDim2.fromOffset(220, 40), LayoutOrder = 4, BackgroundColor3 = Color3.fromRGB(60, 45, 90) },
		function()
			local ok, result = request("RollPower")
			if ok and result and result.power then
				local power = Powers.List[result.power]
				flash("Você obteve: " .. power.name .. " (" .. Powers.Rarities[power.rarity].name .. ")", true)
				VFX.ScreenFlash(Powers.Rarities[power.rarity].color, 0.6, 0.4)
			end
		end
	)
	roll.Parent = content
	for i, id in Powers.forFaction(profile.faction) do
		local power = Powers.List[id]
		local owned = profile.gacha.owned[id] == true
		local equipped = profile.power == id
		local r = row(10 + i, 92)
		local color = rarityColor(power.rarity)
		local element = Elements[power.element]
		Kit.new(
			"Frame",
			{ BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 0), Parent = r },
			{ Kit.corner(2) }
		)
		Kit.label(element.kanji, 34, {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.fromOffset(44, 92),
			Font = T.FontTitle,
			TextColor3 = element.primary,
			Parent = r,
		})
		Kit.label(
			string.format(
				"%s  ·  %s%s",
				power.name,
				Powers.Rarities[power.rarity].name,
				if equipped then "  [EQUIPADO]" else ""
			),
			16,
			{
				Position = UDim2.fromOffset(62, 6),
				Size = UDim2.new(1, -250, 0, 20),
				Font = T.FontTitle,
				TextColor3 = color,
				Parent = r,
			}
		)
		local t1, t2 = power.tier1, power.tier2
		local lines = string.format(
			"%s: %s, %s\n%s: %s, %s  ·  Ultimate: %s",
			faction.forms.Tier1.name,
			Abilities[t1.abilities.Z].name,
			Abilities[t1.abilities.X].name,
			faction.forms.Tier2.name .. " (" .. t2.name .. ")",
			Abilities[t2.abilities.Z].name,
			Abilities[t1.abilities.X].name,
			Abilities[t2.abilities.V].name
		)
		Kit.label(lines, 12, {
			Position = UDim2.fromOffset(62, 28),
			Size = UDim2.new(1, -250, 0, 34),
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = T.Muted,
			Parent = r,
		})
		Kit.label("“" .. power.releaseCommand .. "”", 12, {
			Position = UDim2.fromOffset(62, 66),
			Size = UDim2.new(1, -250, 0, 18),
			TextColor3 = element.primary,
			Font = T.Font,
			Parent = r,
		})
		local b
		if equipped then
			b = Kit.button("Equipado", { Active = false, TextTransparency = 0.5 })
		elseif owned then
			b = Kit.button("Equipar", nil, function()
				request("EquipPower", { power = id }, power.name .. " equipado")
			end)
		else
			b = Kit.button("Comprar " .. g.directCost .. " ✦", nil, function()
				request("BuyPower", { power = id }, power.name .. " obtido!")
			end)
		end
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -12, 0.5, 0)
		b.Size = UDim2.fromOffset(160, 38)
		b.Parent = r
	end
end

function Render.Travel(profile)
	section("Viagem rápida (fora de combate)", 1)
	local order = 2
	for _, zoneId in Zones.Order do
		local zone = Zones.List[zoneId]
		Kit.label(
			zone.kanji
				.. "  "
				.. zone.name
				.. (if profile.level < (zone.minLevel or 1) then "  (nível " .. zone.minLevel .. ")" else ""),
			15,
			{
				Size = UDim2.new(1, 0, 0, 24),
				Font = T.FontTitle,
				TextColor3 = T.Accent,
				LayoutOrder = order,
				Parent = content,
			}
		)
		order += 1
		for id, point in Zones.TravelPoints do
			if point.zone == zoneId then
				local discovered = profile.discovered[id] == true
				local r = row(order, 44)
				order += 1
				Kit.label(if discovered then point.name else "??? (não descoberto)", 14, {
					Position = UDim2.fromOffset(14, 0),
					Size = UDim2.new(1, -150, 1, 0),
					TextColor3 = if discovered then T.Text else T.Muted,
					Parent = r,
				})
				if discovered then
					local b = Kit.button("Viajar", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(110, 32),
						TextSize = 14,
					}, function()
						local ok = request("Travel", { point = id })
						if ok then
							MenuController.Close()
						end
					end)
					b.Parent = r
				end
			end
		end
	end
end

function Render.Shop(profile)
	section(string.format("Loja do Velho Sōma  ·  %d Kan", profile.currency.Kan), 1)
	for i, id in Items.Shop do
		local def = Items.List[id]
		local r = row(10 + i, 50)
		Kit.label(def.kanji, 22, {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.fromOffset(30, 50),
			Font = T.FontTitle,
			TextColor3 = rarityColor(def.rarity),
			Parent = r,
		})
		Kit.label(
			def.name .. "  ·  " .. def.price .. " Kan",
			15,
			{ Position = UDim2.fromOffset(48, 6), Size = UDim2.new(1, -300, 0, 20), Font = T.FontTitle, Parent = r }
		)
		Kit.label(
			def.desc,
			12,
			{ Position = UDim2.fromOffset(48, 26), Size = UDim2.new(1, -300, 0, 18), TextColor3 = T.Muted, Parent = r }
		)
		for j, qty in { 1, 5 } do
			local b = Kit.button("Comprar ×" .. qty, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10 - (2 - j) * 128, 0.5, 0),
				Size = UDim2.fromOffset(120, 32),
				TextSize = 14,
			}, function()
				request("Buy", { item = id, qty = qty }, "Comprado: " .. def.name)
			end)
			b.Parent = r
		end
	end
end

function Render.Forge(profile)
	section(string.format("Forja  ·  %d Kan  ·  caminho garantido para equipamentos", profile.currency.Kan), 1)
	local ids = {}
	for id in Items.Recipes do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Items.Recipes[a].level < Items.Recipes[b].level
	end)
	for i, id in ids do
		local recipe = Items.Recipes[id]
		local def = Items.List[id]
		local r = row(10 + i, 62)
		local color = rarityColor(def.rarity)
		Kit.label(def.kanji, 24, {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.fromOffset(32, 62),
			Font = T.FontTitle,
			TextColor3 = color,
			Parent = r,
		})
		Kit.label(string.format("%s  ·  Nv %d  ·  %d Kan", def.name, recipe.level, recipe.kan), 15, {
			Position = UDim2.fromOffset(50, 6),
			Size = UDim2.new(1, -200, 0, 20),
			Font = T.FontTitle,
			TextColor3 = color,
			Parent = r,
		})
		local parts = {}
		for materialId, qty in recipe.materials do
			local have = InventoryLogic.count(profile.inventory, materialId)
			table.insert(parts, string.format("%s %d/%d", Items.List[materialId].name, have, qty))
		end
		table.sort(parts)
		Kit.label(table.concat(parts, "  ·  "), 12, {
			Position = UDim2.fromOffset(50, 30),
			Size = UDim2.new(1, -200, 0, 24),
			TextWrapped = true,
			TextColor3 = T.Muted,
			Parent = r,
		})
		local b = Kit.button("Forjar", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(120, 34),
		}, function()
			request("Craft", { item = id })
		end)
		b.Parent = r
	end
end

function Render.Settings(profile)
	local settings = profile.settings
	section("Configurações", 1)
	local function choice(order: number, label: string, key: string, options: { { any } })
		local r = row(order, 48)
		Kit.label(label, 15, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.4, 0, 1, 0), Parent = r })
		for i, option in options do
			local selected = settings[key] == option[1]
			local b = Kit.button(option[2], {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10 - (#options - i) * 118, 0.5, 0),
				Size = UDim2.fromOffset(110, 32),
				TextSize = 14,
				BackgroundColor3 = if selected then Color3.fromRGB(45, 70, 100) else T.PanelLight,
			}, function()
				request("SaveSettings", { [key] = option[1] })
			end)
			b.Parent = r
		end
	end
	choice(2, "Qualidade dos efeitos", "vfx", { { "Low", "Baixa" }, { "Medium", "Média" }, { "High", "Alta" } })
	choice(3, "Tremor de câmera", "shake", { { 0, "Desligado" }, { 0.5, "Suave" }, { 1, "Normal" }, { 1.5, "Forte" } })
	choice(4, "Cenas de transformação", "cinematics", { { "Full", "Completas" }, { "Off", "Desligadas" } })
	Kit.label(
		"Dica: as cenas também podem ser puladas com qualquer tecla/toque. Use qualidade Baixa em celulares modestos.",
		13,
		{ Size = UDim2.new(1, 0, 0, 34), TextWrapped = true, TextColor3 = T.Muted, LayoutOrder = 10, Parent = content }
	)
	section("Controles", 20)
	Kit.label(
		table.concat({
			"Clique/R2: ataque (5 golpes; no ar: combo aéreo)  ·  E/R1: pesado (quebra guarda; alvo atordoado com pouca vida = EXECUÇÃO)",
			"R/X: lançador  ·  F/L2: bloquear (no instante do golpe = PARRY → próximo ataque é contra-ataque)",
			"Q/B: dash com invencibilidade  ·  Espaço no ar: pulo duplo  ·  Shift: correr  ·  T/R3: carregar Reiatsu",
			"Z X C (V no Tier 2): habilidades  ·  G/L1: liberar forma (Shikai → Bankai → voltar)  ·  H/Y: Máscara Hollow",
			"1: desembainhar  ·  4: Bala de Alma  ·  M/Select: menu",
		}, "\n"),
		13,
		{
			Size = UDim2.new(1, 0, 0, 110),
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 21,
			Parent = content,
		}
	)
end

function Render.Dev(_profile)
	section("Painel de desenvolvimento (somente Studio)", 1)
	local commands = {
		{ "Nível 5", { command = "level", value = 5 } },
		{ "Nível 15", { command = "level", value = 15 } },
		{ "Nível 30", { command = "level", value = 30 } },
		{ "Desbloquear formas e máscara", { command = "unlockAll" } },
		{ "+5000 Kan / +500 ✦", { command = "shards" } },
		{ "Todos os itens", { command = "items" } },
		{ "Curar", { command = "heal" } },
		{ "Ir: Campo de Treino", { command = "travel", value = "TrainingGate" } },
		{ "Ir: Soul Society", { command = "travel", value = "Seireitei" } },
		{ "Ir: Hueco Mundo", { command = "travel", value = "DesertEdge" } },
		{ "Ir: Karakura", { command = "travel", value = "KarakuraPlaza" } },
		{ "Trocar facção (reset)", { command = "resetFaction" } },
	}
	for i, c in commands do
		local b = Kit.button(c[1], { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 10 + i }, function()
			request("Dev", c[2], "OK: " .. c[1])
		end)
		b.Parent = content
	end
end

-- ============================================================
-- Abrir/fechar
-- ============================================================
local function render()
	if not openTab then
		return
	end
	local profile = DataController.Profile
	if not profile then
		return
	end
	clear()
	for id, b in tabButtons do
		b.BackgroundColor3 = if id == openTab then Color3.fromRGB(45, 60, 95) else T.PanelLight
	end
	for _, tab in TABS do
		if tab.id == openTab then
			header.Text = tab.kanji .. "  " .. tab.label
		end
	end
	local renderer = Render[openTab]
	if renderer then
		local ok, err = pcall(renderer, profile)
		if not ok then
			warn("[Menu]", openTab, err)
		end
	end
end

function MenuController.Open(tab: string?)
	local wasOpen = gui.Enabled
	openTab = tab or openTab or "Status"
	if tabButtons.Shop then
		tabButtons.Shop.Visible = openTab == "Shop" or openTab == "Forge"
		tabButtons.Forge.Visible = openTab == "Shop" or openTab == "Forge"
	end
	if not wasOpen then
		gui.Enabled = true
		InputController.PushBlock()
		panel.Position = UDim2.new(0.5, 0, 0.53, 0)
		Kit.tween(panel, 0.25, { Position = UDim2.fromScale(0.5, 0.5) })
	end
	render()
end

function MenuController.Close()
	if not gui.Enabled then
		return
	end
	gui.Enabled = false
	InputController.PopBlock()
end

function MenuController.Toggle()
	if gui.Enabled then
		MenuController.Close()
	else
		MenuController.Open()
	end
end

function MenuController.Init()
	gui = Kit.new("ScreenGui", {
		Name = "Menu",
		ResetOnSpawn = false,
		DisplayOrder = 25,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Kit.new("TextButton", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		AutoButtonColor = false,
		Parent = gui,
	}).Activated
		:Connect(MenuController.Close)
	panel = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(960, 580),
		Parent = gui,
	})
	header = Kit.label(
		"",
		24,
		{ Position = UDim2.fromOffset(190, 14), Size = UDim2.new(1, -260, 0, 30), Font = T.FontTitle, Parent = panel }
	)
	status = Kit.label("", 14, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 190, 1, -10),
		Size = UDim2.new(1, -210, 0, 20),
		TextTransparency = 1,
		Parent = panel,
	})
	local closeButton = Kit.button(
		"✕",
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(34, 34) },
		MenuController.Close
	)
	closeButton.Parent = panel

	local tabs = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(0, 160, 1, -28),
		Parent = panel,
	}, {
		Kit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, tab in TABS do
		if tab.studio and not RunService:IsStudio() then
			continue
		end
		local b = Kit.button(
			tab.kanji .. "  " .. tab.label,
			{ Size = UDim2.new(1, 0, 0, 42), LayoutOrder = i, TextXAlignment = Enum.TextXAlignment.Left },
			function()
				openTab = tab.id
				render()
			end
		)
		Kit.padding(12).Parent = b
		b.Visible = not tab.hidden
		b.Parent = tabs
		tabButtons[tab.id] = b
	end

	content = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(190, 54),
		Size = UDim2.new(1, -210, 1, -94),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		BorderSizePixel = 0,
		Parent = panel,
	}, {
		Kit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Kit.new("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})
	Kit.autoScale(gui)

	-- Barra lateral de atalhos (estilo dos RPGs de anime populares): botões quadrados com
	-- ícone, legenda e cor própria, sempre visível — essencial no celular.
	local sideGui = Kit.new(
		"ScreenGui",
		{ Name = "SideMenu", ResetOnSpawn = false, DisplayOrder = 11, Parent = player:WaitForChild("PlayerGui") }
	)
	local column = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.45, 0),
		Size = UDim2.fromOffset(70, 480),
		Parent = sideGui,
	}, {
		Kit.new("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	local SIDE = {
		{ tab = "Status", label = "Status", icon = "体", color = Color3.fromRGB(235, 90, 90) },
		{ tab = "Skills", label = "Árvore", icon = "技", color = Color3.fromRGB(255, 170, 60) },
		{ tab = "Inventory", label = "Itens", icon = "袋", color = Color3.fromRGB(90, 200, 120) },
		{ tab = "Quests", label = "Missões", icon = "任", color = Color3.fromRGB(90, 170, 255) },
		{ tab = "Powers", label = "Poderes", icon = "魂", color = Color3.fromRGB(190, 110, 255) },
		{ tab = "Travel", label = "Viagem", icon = "門", color = Color3.fromRGB(80, 220, 220) },
		{ tab = "Settings", label = "Opções", icon = "設", color = Color3.fromRGB(170, 175, 190) },
	}
	for i, entry in SIDE do
		local button = Kit.new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			Size = UDim2.fromOffset(62, 58),
			BackgroundColor3 = entry.color:Lerp(Color3.new(0, 0, 0), 0.55),
			LayoutOrder = i,
			Parent = column,
		}, {
			Kit.corner(10),
			Kit.new(
				"UIStroke",
				{ Color = Color3.new(0, 0, 0), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
			),
			Kit.new("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)),
			}),
		})
		Kit.label(entry.icon, 26, {
			Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.fromOffset(0, 2),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = T.FontTitle,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = button,
		}, { Kit.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5 }) })
		Kit.label(entry.label, 11, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -3),
			Size = UDim2.new(1, 0, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = T.FontTitle,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = button,
		}, { Kit.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1 }) })
		local scale = Kit.new("UIScale", { Parent = button })
		button.MouseEnter:Connect(function()
			Kit.tween(scale, 0.12, { Scale = 1.08 }, Enum.EasingStyle.Back)
		end)
		button.MouseLeave:Connect(function()
			Kit.tween(scale, 0.12, { Scale = 1 })
		end)
		button.Activated:Connect(function()
			if gui.Enabled and openTab == entry.tab then
				MenuController.Close()
			else
				MenuController.Open(entry.tab)
			end
		end)
	end
	Kit.autoScale(sideGui)
	MenuController.SideGui = sideGui
end

local function applySettings(profile)
	local settings = profile and profile.settings
	if not settings then
		return
	end
	CameraController.SetShakeScale(settings.shake or 1)
	VFX.SetQuality(settings.vfx or "High")
end

function MenuController.Start()
	InputController.Action:Connect(function(action, began)
		if action == "Menu" and began then
			MenuController.Toggle()
		elseif action == "Item" and began then
			local ok, err = DataController.Request("UseItem", { item = "SoulCandy" })
			if not ok then
				HUDController.Notify(tostring(err), "warn")
			end
		end
	end)
	DataController.Changed:Connect(function(profile)
		applySettings(profile)
		if gui.Enabled then
			render()
		end
	end)
	DialogueController.OpenMenu = MenuController.Open
	FxController.Settings = function()
		local profile = DataController.Profile
		return profile and profile.settings
	end
	applySettings(DataController.Profile)
end

return MenuController

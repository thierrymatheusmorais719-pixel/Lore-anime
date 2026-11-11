-- Painéis modais: Pets/Equipe, Itens, Sorte, Bestiário, Missões, Mapa, Opções (+Teste no Studio)
-- e o painel de Ovo com as chances REAIS calculadas pelo servidor.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Items = require(Shared.Config.Items)
local Eggs = require(Shared.Config.Eggs)
local Worlds = require(Shared.Config.Worlds)
local Quests = require(Shared.Config.Quests)
local Mining = require(Shared.Config.Mining)
local Combat = require(Shared.Config.Combat)
local Abilities = require(Shared.Config.Abilities)
local Signatures = require(Shared.Config.Signatures)
local Enemies = require(Shared.Config.Enemies)
local Bosses = require(Shared.Config.Bosses)
local LuckConfig = require(Shared.Config.Luck)
local Exploration = require(Shared.Config.Exploration)
local CollectionLogic = require(Shared.Logic.CollectionLogic)
local PetMesh = require(Shared.Builders.PetMesh)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)
local Fx = require(script.Parent.Fx)

local Panels = {}
local T = UIKit.Theme
local new = UIKit.new

local gui, modal, titleLabel, content, scrim, blur, titlePlaque
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
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, LightColor = Color3.new(1, 1, 1),
		Ambient = Color3.fromRGB(160, 160, 180), Parent = parent })
	UIKit.corner(vp, 10)
	vp:SetAttribute("Species", pet.species)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 38
	cam.Parent = vp
	vp.CurrentCamera = cam
	local model = PetMesh.display(pet.species, pet.mutation, pet.accessory)
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

-- Miniatura 3D estática (sem girar) do modelo REAL do pet, com mutação e acessório.
local function thumb(parent: Instance, species: string, mutation: string?, accessory: string?)
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, LightColor = Color3.new(1, 1, 1),
		Ambient = Color3.fromRGB(170, 170, 190), LightDirection = Vector3.new(-1, -1.5, -1), ZIndex = 3, Parent = parent })
	vp:SetAttribute("Species", species)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	cam.Parent = vp
	vp.CurrentCamera = cam
	local model = PetMesh.display(species, mutation, accessory)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	model:PivotTo(CFrame.Angles(0, math.rad(200), 0))
	model.Parent = vp
	local size = model:GetExtentsSize().Magnitude
	cam.CFrame = CFrame.lookAt(Vector3.new(size * 0.55, size * 0.35, -size * 1.25), Vector3.new(0, 0, 0))
	return vp
end
local MAX_THUMBS = 48

-------------------------------------------------------------------------------
-- PETS
-------------------------------------------------------------------------------

local RARITY_ABBR = { Common = "C", Uncommon = "I", Rare = "R", Epic = "É", Legendary = "L", Mythic = "M", Secret = "S", Celestial = "✦" }

-- chip de atributo (ícone + valor) no detalhe do pet
local function statChip(parent, icon: string, value: string, color: Color3)
	local f = new("Frame", { BackgroundColor3 = T.inset, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = parent })
	UIKit.corner(f, 8)
	UIKit.stroke(f, T.edgeDark, 2, 0)
	UIKit.label({ Position = UDim2.fromOffset(6, 0), Size = UDim2.new(0, 22, 1, 0), Text = icon, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Parent = f })
	UIKit.label({ Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -34, 1, 0), Text = value, Font = T.title, TextSize = 15, TextColor3 = color, TextWrapped = false,
		TextStrokeTransparency = 0.2, TextStrokeColor3 = T.edgeDark, Parent = f })
	return f
end

local function petDetail(parent, uid)
	local p = State.profile
	local pet = p.pets[uid]
	if not pet then
		return
	end
	local sp = Pets.Species[pet.species]
	local rar = Rarities.Info[sp.rarity]
	local d = State.derived and State.derived.petStats and State.derived.petStats[uid]
	local role = Combat.Roles[sp.role]
	local ab = Abilities.Info[sp.ability]
	local box = new("Frame", { Name = "Detail", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })
	-- palco do retrato: gradiente da raridade + modelo 3D girando
	local stage = new("Frame", { Name = "Stage", Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 128), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = box })
	UIKit.corner(stage, 12)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, UIKit.darken(rar.color, 0.55)), ColorSequenceKeypoint.new(0.65, UIKit.darken(rar.color, 0.15)),
		ColorSequenceKeypoint.new(1, UIKit.darken(rar.color, 0.7)) }), Parent = stage })
	UIKit.stroke(stage, UIKit.darken(rar.color, 0.6), 3, 0)
	local pedestal = new("Frame", { Name = "Pedestal", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(150, 22), BackgroundColor3 = UIKit.lighten(rar.color, 0.3),
		BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = stage })
	UIKit.corner(pedestal, 100)
	preview(stage, pet)
	-- nome, mutação e raridade
	local mut = pet.mutation and Mutations.Info[pet.mutation]
	UIKit.label({ Position = UDim2.fromOffset(10, 144), Size = UDim2.new(1, -120, 0, 26), Font = T.title, TextSize = 22, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeTransparency = 0, TextStrokeColor3 = T.edgeDark,
		Text = (mut and string.format('<font color="#%s">%s</font> ', mut.color:ToHex(), pet.mutation) or "") .. sp.name, Parent = box })
	local pill = new("Frame", { Name = "Rarity", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 146), Size = UDim2.fromOffset(104, 22), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Parent = box })
	UIKit.corner(pill, 100)
	UIKit.rarityFill(pill, rar.color, rar.rank, rar.accent)
	UIKit.stroke(pill, UIKit.darken(rar.color, 0.6), 2, 0)
	UIKit.label({ Size = UDim2.fromScale(1, 1), Text = rar.label, Font = T.title, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0,
		TextStrokeColor3 = UIKit.darken(rar.color, 0.7), Parent = pill })
	-- nível e XP (recipiente)
	local xpb = UIKit.vesselBar({ Name = "XP", Position = UDim2.fromOffset(10, 176), Size = UDim2.new(1, -20, 0, 20), color = T.xp, textSize = 12, Parent = box })
	local xpNext = d and d.xpNext or 0
	xpb.set(xpNext > 0 and (pet.xp or 0) / xpNext or 1, string.format("Nv %d/%d · %s · %s · XP %s/%s", pet.level, d and d.levelCap or 0, role.label, Combat.Tiers[pet.tier].label,
		UIKit.fmt(pet.xp or 0), UIKit.fmt(xpNext)))
	-- atributos
	local chips = new("Frame", { Name = "Stats", Position = UDim2.fromOffset(10, 204), Size = UDim2.new(1, -20, 0, 54), BackgroundTransparency = 1, Parent = box })
	new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -4, 0, 25), CellPadding = UDim2.fromOffset(6, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chips })
	if d then
		statChip(chips, "❤", UIKit.fmt(d.hp), T.hp)
		statChip(chips, "⚔", string.format("%.0f", d.atk), Color3.fromRGB(255, 150, 110))
		statChip(chips, "🛡", string.format("%.0f", d.def), T.info)
		statChip(chips, "⚡", string.format("%.2f/s", d.aspd), T.fury)
		statChip(chips, "🎯", tostring(d.range), T.energy)
		statChip(chips, "💥", math.floor(d.crit * 100) .. "%", T.cancel)
	end
	-- ataques próprios (habilidade, Assinatura e passiva) numa área rolável
	local actionsCount = 5
	if not pet.mutation then
		for id, n in pairs(p.items) do
			local info = Items.Info[id]
			if info and info.kind == "catalyst" and n > 0 then
				actionsCount += 1
			end
		end
	end
	local rows = math.ceil(actionsCount / 2)
	local actionsH = rows * 30 + (rows - 1) * 5
	local info = UIKit.scroll({ Name = "Moves", Position = UDim2.fromOffset(10, 264), Size = UDim2.new(1, -20, 1, -(264 + actionsH + 18)), ScrollBarThickness = 5, Parent = box })
	UIKit.list(info, Enum.FillDirection.Vertical, 4)
	UIKit.label({ LayoutOrder = 1, Size = UDim2.new(1, -6, 0, 34), TextSize = 12,
		Text = string.format("<b>%s %s</b> (rank %d/%d, recarga %.1fs, custo %d): %s", ab.icon, ab.label, pet.abilityRank or 1, Abilities.MaxRank, d and d.cooldown or ab.cooldown, ab.cost, ab.desc), Parent = info })
	local sig = Signatures.forSpecies(pet.species)
	if sig then
		UIKit.label({ LayoutOrder = 2, Size = UDim2.new(1, -6, 0, 32), TextSize = 12, TextColor3 = Color3.fromRGB(255, 220, 140),
			Text = string.format("<b>✦ Assinatura: %s</b> (Fúria %d golpes): %s", sig.name, Signatures.furyMax(sp.rarity), sig.desc), Parent = info })
	end
	if sp.perk then
		UIKit.label({ LayoutOrder = 3, Size = UDim2.new(1, -6, 0, 16), TextSize = 12, TextColor3 = T.luck,
			Text = sp.perk.kind == "luck" and string.format("Passiva: +%d%% sorte (%s) na equipe", math.floor(sp.perk.bonus * 100 + 0.5), LuckConfig.CategoryLabels[sp.perk.category] or "tudo")
				or string.format("Passiva: +%d%% moedas", math.floor(sp.perk.bonus * 100 + 0.5)), Parent = info })
	end
	-- ações
	local actions = new("Frame", { Name = "Actions", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, actionsH), BackgroundTransparency = 1, Parent = box })
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -3, 0, 30), CellPadding = UDim2.fromOffset(6, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = actions })
	local inTeam = table.find(p.team, uid) ~= nil
	UIKit.button({ LayoutOrder = 1, Text = inTeam and "Remover da equipe" or "⚔ Equipar", TextSize = 13, BackgroundColor3 = inTeam and T.cancel or T.confirm, Parent = actions }, function()
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
	UIKit.button({ LayoutOrder = 2, Text = evoText, TextSize = 11, TextWrapped = true, BackgroundColor3 = (d and d.canEvolve) and T.yellow or T.gray, Parent = actions }, function()
		toastResult(State.request("Evolve", { uid = uid }))
	end)
	UIKit.button({ LayoutOrder = 3, Text = d and d.abilityCost and ("Melhorar habilidade: " .. costText(d.abilityCost)) or "Habilidade no máximo", TextSize = 11, TextWrapped = true,
		BackgroundColor3 = T.info, Parent = actions }, function()
		toastResult(State.request("UpgradeAbility", { uid = uid }))
	end)
	UIKit.button({ LayoutOrder = 4, Text = pet.locked and "🔒 Destrancar" or "🔓 Trancar", TextSize = 13, BackgroundColor3 = T.info, Parent = actions }, function()
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
	UIKit.button({ LayoutOrder = 5, Text = "Acessório: " .. (pet.accessory and Items.label(pet.accessory) or "nenhum"), TextSize = 11, BackgroundColor3 = T.purple, Parent = actions }, function()
		local idx = pet.accessory and table.find(owned, pet.accessory) or 0
		local nextItem = owned[idx + 1]
		toastResult(State.request("Accessory", { uid = uid, item = nextItem }))
	end)
	if not pet.mutation then
		for id, n in pairs(p.items) do
			local cinfo = Items.Info[id]
			if cinfo and cinfo.kind == "catalyst" and n > 0 then
				UIKit.button({ LayoutOrder = 6, Text = string.format("Aplicar %s (%d)", cinfo.label, n), TextSize = 11, BackgroundColor3 = T.purple, Parent = actions }, function()
					toastResult(State.request("Catalyst", { uid = uid, item = id }))
				end)
			end
		end
	end
	UIKit.button({ LayoutOrder = 9, Text = pet.locked and "Trancado" or "Liberar (+essência)", TextSize = 12, BackgroundColor3 = pet.locked and T.gray or T.cancel, Parent = actions }, function()
		if not pet.locked then
			selectedPet = nil
			toastResult(State.request("Release", { uids = { uid } }))
		end
	end)
end

-- SLOT DE PET (Design System 3.5): gradiente da raridade (brilho girando do Épico para cima), retrato 3D,
-- sigla da raridade, mutação, nível, marca de equipado e cadeado.
local function petSlot(parent, order: number, e, inTeam: boolean, withThumb: boolean, onClick)
	local sp = Pets.Species[e.pet.species]
	local rar = Rarities.Info[sp.rarity]
	local slot = new("TextButton", { Name = "Slot", LayoutOrder = order, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = parent })
	UIKit.corner(slot, 12)
	UIKit.rarityFill(slot, rar.color, rar.rank, rar.accent)
	UIKit.stroke(slot, inTeam and T.confirm or UIKit.darken(rar.color, 0.6), inTeam and 4 or 3, 0)
	local sc = new("UIScale", { Parent = slot })
	-- brilho de seleção (aceso só no pet selecionado; trocar a seleção não reconstrói a grade)
	local glow = new("Frame", { Name = "Selected", Position = UDim2.fromOffset(-5, -5), Size = UDim2.new(1, 10, 1, 10), BackgroundTransparency = 1, Visible = e.uid == selectedPet, Parent = slot })
	UIKit.corner(glow, 16)
	local gs = UIKit.stroke(glow, Color3.new(1, 1, 1), 3, 0.1)
	UIKit.animate(glow, function(t)
		if glow.Visible then
			gs.Transparency = 0.15 + (math.sin(t * 5) + 1) * 0.2
		end
	end)
	sc.Scale = e.uid == selectedPet and 1.05 or 1
	local view = new("Frame", { Name = "View", Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 0, 72), BackgroundColor3 = T.inset, BackgroundTransparency = 0.6,
		BorderSizePixel = 0, ZIndex = 2, Parent = slot })
	UIKit.corner(view, 9)
	if withThumb then
		thumb(view, e.pet.species, e.pet.mutation, e.pet.accessory)
	end
	local abbr = new("Frame", { Name = "Abbr", Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(20, 18), BackgroundColor3 = UIKit.darken(rar.color, 0.45), BorderSizePixel = 0, ZIndex = 5, Parent = slot })
	UIKit.corner(abbr, 6)
	UIKit.stroke(abbr, T.edgeDark, 2, 0)
	UIKit.label({ Size = UDim2.fromScale(1, 1), Text = RARITY_ABBR[sp.rarity] or "?", Font = T.title, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6,
		TextStrokeTransparency = 0.4, Parent = abbr })
	local mut = e.pet.mutation and Mutations.Info[e.pet.mutation]
	if mut then
		local m = new("Frame", { Name = "Mutation", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, inTeam and 25 or 3), Size = UDim2.fromOffset(20, 20), Rotation = 45,
			BackgroundColor3 = mut.color, BorderSizePixel = 0, ZIndex = 5, Parent = slot })
		UIKit.corner(m, 4)
		UIKit.stroke(m, UIKit.darken(mut.color, 0.6), 2, 0)
	end
	if inTeam then
		UIKit.icon(slot, { Name = "Equipped", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(22, 22), color = T.confirm, Text = "✓", ZIndex = 6 })
	end
	UIKit.label({ Name = "PetName", Position = UDim2.fromOffset(4, 78), Size = UDim2.new(1, -8, 0, 16), TextSize = 12, Font = T.title, TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Text = sp.name, ZIndex = 3, TextStrokeTransparency = 0, TextStrokeColor3 = T.edgeDark, Parent = slot })
	local lv = new("Frame", { Name = "Level", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -10, 0, 17), BackgroundColor3 = T.inset,
		BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 3, Parent = slot })
	UIKit.corner(lv, 100)
	UIKit.label({ Size = UDim2.fromScale(1, 1), Text = string.format("Nv %d %s%s", e.pet.level, string.rep("★", e.pet.tier), e.pet.locked and " 🔒" or ""), Font = T.title, TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 232, 140), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, ZIndex = 4, Parent = lv })
	slot.MouseEnter:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1.07 }):Play()
	end)
	slot.MouseLeave:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.12), { Scale = e.uid == selectedPet and 1.05 or 1 }):Play()
	end)
	slot.Activated:Connect(function()
		UIKit.burst(slot, rar.accent or rar.color)
		onClick()
	end)
	return slot
end

local function petsPanel()
	local p = State.profile
	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = T.inset, BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = content })
	UIKit.corner(header, 12)
	UIKit.stroke(header, T.edgeDark, 2, 0)
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
	local count = 0
	for _ in pairs(p.pets) do
		count += 1
	end
	UIKit.label({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -310, 1, 0), TextSize = 12,
		Text = string.format("⚔ <b>Equipe %d/%d</b> · Sinergias: %s", #p.team, Combat.TeamSize, #syn > 0 and table.concat(syn, ", ") or "nenhuma"), Parent = header })
	UIKit.label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -176, 0.5, 0), Size = UDim2.fromOffset(110, 30), Text = "🐾 " .. count .. " pets", Font = T.title, TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.muted, Parent = header })
	UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0), Size = UDim2.fromOffset(160, 34), Text = "★ Equipar Melhor", TextSize = 15, BackgroundColor3 = T.confirm,
		Parent = header }, function()
		toastResult(State.request("AutoTeam"))
	end)
	local list = UIKit.scroll({ Name = "Grid", Position = UDim2.fromOffset(0, 54), Size = UDim2.new(0.56, -6, 1, -54), Parent = content })
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = list })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(104, 118), CellPadding = UDim2.fromOffset(8, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local detail = new("Frame", { Name = "DetailPane", Position = UDim2.new(0.56, 6, 0, 54), Size = UDim2.new(0.44, -6, 1, -54), BackgroundColor3 = T.panelDark, BackgroundTransparency = 0.15,
		BorderSizePixel = 0, Parent = content })
	UIKit.corner(detail, 14)
	UIKit.stroke(detail, T.edgeDark, 3, 0)
	local entries = {}
	for uid, pet in pairs(p.pets) do
		local power = State.derived and State.derived.petStats and State.derived.petStats[uid] and State.derived.petStats[uid].power or 0
		table.insert(entries, { uid = uid, pet = pet, power = power, rank = Rarities.rank(Pets.Species[pet.species].rarity) })
	end
	-- equipados primeiro, depois raridade e poder
	table.sort(entries, function(a, b)
		local ta, tb = table.find(p.team, a.uid) ~= nil, table.find(p.team, b.uid) ~= nil
		if ta ~= tb then
			return ta
		end
		if a.rank ~= b.rank then
			return a.rank > b.rank
		end
		return a.power > b.power
	end)
	local slots = {}
	local function select(uid: string)
		selectedPet = uid
		for id, sl in pairs(slots) do
			local on = id == uid
			sl:FindFirstChild("Selected").Visible = on
			sl:FindFirstChildOfClass("UIScale").Scale = on and 1.05 or 1
		end
		for _, c in ipairs(detail:GetChildren()) do
			if c.Name == "Detail" then
				c:Destroy()
			end
		end
		petDetail(detail, uid)
	end
	for i, e in ipairs(entries) do
		slots[e.uid] = petSlot(list, i, e, table.find(p.team, e.uid) ~= nil, i <= MAX_THUMBS, function()
			select(e.uid)
		end)
	end
	if #entries == 0 then
		UIKit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "Você ainda não tem pets. Vá até uma estação de ovos (E) para chocar o primeiro!", TextSize = 14, Parent = list })
	end
	if selectedPet and p.pets[selectedPet] then
		select(selectedPet)
	elseif entries[1] then
		select(entries[1].uid)
	end
end

-------------------------------------------------------------------------------
-- ITENS
-------------------------------------------------------------------------------

local KIND_LABEL = { potion = "Poções", egg = "Ovos especiais", catalyst = "Catalisadores", crystal = "Cristais minerados", material = "Materiais", cosmetic = "Acessórios", collectible = "Colecionáveis" }

local function itemsPanel()
	local p = State.profile
	local list = UIKit.scroll({ Size = UDim2.fromScale(1, 1), Parent = content })
	UIKit.list(list, Enum.FillDirection.Vertical, 6)
	local order = 0
	for _, kind in ipairs({ "potion", "egg", "catalyst", "crystal", "material", "cosmetic", "collectible" }) do
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
				local row = UIKit.frame({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = T.bg2, Parent = list })
				UIKit.frame({ Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = r.info.color, radius = 10, Parent = row })
				local desc = ""
				if kind == "potion" then
					local pot = LuckConfig.Potions[r.id]
					desc = string.format(" — +%d%% sorte (%s) por %s", math.floor(pot.bonus * 100), pot.category == "All" and "tudo" or LuckConfig.CategoryLabels[pot.category], UIKit.time(pot.duration))
				elseif kind == "catalyst" then
					desc = " — aplica " .. r.info.mutation .. " a um pet sem mutação (painel Pets)"
				elseif kind == "egg" then
					desc = " — choque de graça em qualquer estação de ovos"
				elseif kind == "crystal" then
					desc = " — para contratos de mineração e picaretas (Missões → Mineração)"
				end
				UIKit.label({ Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -180, 1, 0), TextSize = 13, Text = string.format("<b>%s</b> x%d%s", r.info.label, r.n, desc), Parent = row })
				if kind == "potion" then
					UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(120, 30), Text = "Beber", TextSize = 13,
						BackgroundColor3 = T.green, Parent = row }, function()
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
			local row = UIKit.frame({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = T.bg2, Parent = left })
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
		UIKit.button({ Size = UDim2.fromOffset(170, 30), Text = t[2], TextSize = 13, BackgroundColor3 = bestiaryTab == t[1] and T.purple or T.gray, Parent = tabs }, function()
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
			local card = UIKit.frame({ LayoutOrder = i, BackgroundColor3 = T.bg2, Parent = list })
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
				local row = UIKit.frame({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 34), BackgroundColor3 = T.bg2, Parent = list })
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
			local row = UIKit.frame({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = T.bg2, Parent = list })
			local need = {}
			for k, n in pairs(m.need) do
				table.insert(need, string.format("%s %d/%d", k == "species" and "espécies" or k == "mutations" and "mutações" or "inimigos", math.min(counts[k] or 0, n), n))
			end
			UIKit.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -170, 1, 0), TextSize = 12, Text = string.format("<b>%s</b> — %s — %s", m.label, table.concat(need, ", "), costText(m.reward)), Parent = row })
			UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(150, 28), TextSize = 12,
				Text = claimed and "Resgatado" or done and "Resgatar" or "Em andamento", BackgroundColor3 = (done and not claimed) and T.green or T.gray, Parent = row }, function()
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
			local row = UIKit.frame({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 42), BackgroundColor3 = i == idx and T.purple or T.bg2, Parent = list })
			UIKit.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -150, 1, 0), TextSize = 12, Text = string.format("<b>%s</b> — %s\n<font color=\"#AAB0CD\">%s</font>", q.label, q.desc, rewardText(q.reward)), Parent = row })
			local canClaim = i == idx and p.quests.storyProgress >= q.goal.count
			UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(130, 28), Text = canClaim and "Resgatar" or status, TextSize = 12,
				BackgroundColor3 = canClaim and T.green or T.gray, Parent = row }, function()
				if canClaim then
					toastResult(State.request("ClaimStory"))
				end
			end)
		end
	end
	-- linhas paralelas (expedições): a missão atual de cada linha, com o passo dentro da linha
	for li, lineId in ipairs(Quests.SideOrder) do
		local line = Quests.Side[lineId]
		local st = (p.quests.side and p.quests.side[lineId]) or { index = 1, progress = 0 }
		local q = line.list[st.index]
		UIKit.label({ LayoutOrder = 40 + li * 3, Size = UDim2.new(1, 0, 0, 22), Font = T.title, TextSize = 18, TextColor3 = T.gold,
			Text = string.format("%s (%d/%d)", line.label, math.min(st.index - 1, #line.list), #line.list), Parent = list })
		if q then
			local done = st.progress >= q.goal.count
			local row = UIKit.frame({ LayoutOrder = 41 + li * 3, Size = UDim2.new(1, -8, 0, 42), BackgroundColor3 = T.teal, Parent = list })
			UIKit.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -150, 1, 0), TextSize = 12,
				Text = string.format("<b>%s</b> — %s (%d/%d)\n<font color=\"#DDE6F5\">%s</font>", q.label, q.desc, st.progress, q.goal.count, rewardText(q.reward)), Parent = row })
			UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(130, 28), TextSize = 12,
				Text = done and "Resgatar" or "Em andamento", BackgroundColor3 = done and T.green or T.gray, Parent = row }, function()
				if done then
					toastResult(State.request("ClaimSide", { line = lineId }))
				end
			end)
		else
			UIKit.label({ LayoutOrder = 41 + li * 3, Size = UDim2.new(1, -8, 0, 20), TextSize = 12, TextColor3 = T.muted, Text = "Linha concluída. Parabéns!", Parent = list })
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
			local row = UIKit.frame({ LayoutOrder = 100 + i, Size = UDim2.new(1, -8, 0, 42), BackgroundColor3 = T.bg2, Parent = list })
			UIKit.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -150, 1, 0), TextSize = 12, Text = string.format("<b>%s</b> — %s (%d/%d)\n<font color=\"#AAB0CD\">%s</font>", q.label, q.desc, prog, q.goal.count, rewardText(q.reward)), Parent = row })
			UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(130, 28), TextSize = 12,
				Text = claimed and "Resgatada" or done and "Resgatar" or "Em andamento", BackgroundColor3 = (done and not claimed) and T.green or T.gray, Parent = row }, function()
				if done and not claimed then
					toastResult(State.request("ClaimDaily", { id = id }))
				end
			end)
		end
	end
	-- MINERAÇÃO DE CRISTAIS: picareta, cristais e contratos do dia (entregas)
	local m = p.mining or { pickaxe = 1, contracts = { ids = {}, done = {} } }
	local lvl = math.clamp(m.pickaxe or 1, 1, #Mining.Pickaxes)
	local pk = Mining.Pickaxes[lvl]
	UIKit.label({ LayoutOrder = 200, Size = UDim2.new(1, 0, 0, 22), Text = "⛏ Mineração de Cristais", Font = T.title, TextSize = 18, TextColor3 = T.gold, Parent = list })
	UIKit.label({ LayoutOrder = 201, Size = UDim2.new(1, -8, 0, 34), TextSize = 12, TextColor3 = T.muted,
		Text = "Segure <b>Minerar</b> perto de um veio de cristal: Cavernas Esmeralda (Terras Baixas do Verdant Haven) e em volta dos campos de recursos dos outros mundos. Pets da equipe por perto ajudam.",
		Parent = list })
	local pkRow = UIKit.frame({ LayoutOrder = 202, Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = T.bg2, Parent = list })
	local nextP = Mining.Pickaxes[lvl + 1]
	UIKit.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -170, 1, 0), TextSize = 12,
		Text = string.format("<b>%s</b> (nível %d) — força %d, %.2fs por golpe%s\n<font color=\"#AAB0CD\">%s</font>", pk.label, lvl, pk.power, pk.hold,
			pk.bonus > 0 and string.format(", +%d cristal por veio", pk.bonus) or "", nextP and ("Próxima: " .. nextP.label .. " — " .. costText(nextP.cost)) or "Nível máximo"),
		Parent = pkRow })
	UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(150, 30), TextSize = 12,
		Text = nextP and "Melhorar picareta" or "Máximo", BackgroundColor3 = nextP and T.orange or T.gray, Parent = pkRow }, function()
		if nextP then
			toastResult(State.request("UpgradePickaxe"))
		end
	end)
	local have = {}
	for _, id in ipairs(Mining.CrystalOrder) do
		local n = p.items[id] or 0
		if n > 0 then
			table.insert(have, string.format('<font color="#%s">%s</font> x%d', Mining.Crystals[id].color:ToHex(), Mining.Crystals[id].label, n))
		end
	end
	UIKit.label({ LayoutOrder = 203, Size = UDim2.new(1, -8, 0, 22), TextSize = 12,
		Text = "Seus cristais: " .. (#have > 0 and table.concat(have, " · ") or "nenhum ainda") .. string.format("  (total minerado: %d)", m.mined or 0), Parent = list })
	UIKit.label({ LayoutOrder = 204, Size = UDim2.new(1, 0, 0, 22), Text = "Contratos de mineração (renovam à 00:00 UTC)", Font = T.title, TextSize = 16, TextColor3 = T.gold, Parent = list })
	local cs = m.contracts or { ids = {}, done = {} }
	for i, id in ipairs(cs.ids or {}) do
		local ct = Mining.findContract(id)
		if ct then
			local need, ready = {}, true
			for item, n in pairs(ct.need) do
				local got = p.items[item] or 0
				if got < n then
					ready = false
				end
				table.insert(need, string.format("%s %d/%d", Items.label(item), math.min(got, n), n))
			end
			local done = cs.done and cs.done[id]
			local row = UIKit.frame({ LayoutOrder = 204 + i, Size = UDim2.new(1, -8, 0, 60), BackgroundColor3 = T.bg2, Parent = list })
			UIKit.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -150, 1, 0), TextSize = 12,
				Text = string.format("<b>%s</b> — %s\nEntregar: %s\n<font color=\"#AAB0CD\">%s</font>", ct.label, ct.desc, table.concat(need, ", "), rewardText(ct.reward)), Parent = row })
			UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(130, 28), TextSize = 12,
				Text = done and "Entregue" or ready and "Entregar" or "Faltam cristais", BackgroundColor3 = (ready and not done) and T.green or T.gray, Parent = row }, function()
				if ready and not done then
					toastResult(State.request("DeliverContract", { id = id }))
				end
			end)
		end
	end
end

-------------------------------------------------------------------------------
-- MAPA
-------------------------------------------------------------------------------

-- MENU DE MUNDOS (Design System, seção 7): cartões com a arte do mundo; os bloqueados ficam escuros,
-- presos por correntes e com um cadeado de runa pulsando. Trilha de progresso embaixo.
local WORLD_ART = { verdant = "🌳", crystal = "💎", sky = "🏛", wilds = "🌲", astral = "⭐" }

-- corrente em diagonal: elos girados posicionados ao longo da reta (cada elo é independente,
-- assim a rotação não depende de herança entre Frames)
local function chain(parent: Instance, x0: number, y0: number, x1: number, y1: number)
	local dx, dy = x1 - x0, y1 - y0
	local len = math.sqrt(dx * dx + dy * dy)
	local ang = math.deg(math.atan2(dy, dx))
	local n = math.floor(len / 13)
	for k = 0, n do
		local f = k / n
		local side = k % 2 == 1
		local link = new("Frame", { Name = "Link", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x0 + dx * f, y0 + dy * f),
			Size = side and UDim2.fromOffset(16, 5) or UDim2.fromOffset(18, 10), Rotation = ang, BackgroundColor3 = side and Color3.fromRGB(108, 110, 128) or Color3.fromRGB(138, 140, 160),
			BorderSizePixel = 0, ZIndex = 6, Parent = parent })
		UIKit.corner(link, 5)
		UIKit.stroke(link, Color3.fromRGB(30, 30, 40), 2, 0)
	end
end

local function travelFx(worldId: string)
	local w = Worlds.Info[worldId]
	local veil = new("Frame", { Name = "TravelVeil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIKit.darken(w.palette.accent, 0.55), BackgroundTransparency = 1, ZIndex = 80, Parent = gui })
	local title = UIKit.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(900, 80), Text = w.name, Font = T.title, TextSize = 64,
		TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, TextStrokeTransparency = 1, TextStrokeColor3 = T.edgeDark, ZIndex = 81, Parent = veil })
	TweenService:Create(veil, TweenInfo.new(0.35), { BackgroundTransparency = 0.05 }):Play()
	TweenService:Create(title, TweenInfo.new(0.35), { TextTransparency = 0, TextStrokeTransparency = 0 }):Play()
	task.delay(1.1, function()
		TweenService:Create(veil, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(title, TweenInfo.new(0.45), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.5)
		veil:Destroy()
	end)
end

local function mapPanel()
	local p = State.profile
	local here = Players.LocalPlayer:GetAttribute("World") or "verdant"
	UIKit.label({ Size = UDim2.new(1, 0, 0, 26), Text = "Escolha um mundo para viajar. Cada mundo aberto libera ovos, inimigos e um boss novos.", TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = T.muted, Parent = content })
	local row = new("Frame", { Name = "Cards", Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 356), BackgroundTransparency = 1, Parent = content })
	UIKit.list(row, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
	local CARD_W, ART_H = 160, 150
	for i, id in ipairs(Worlds.Order) do
		local w = Worlds.Info[id]
		local unlocked = p.worlds[id] == true
		local prevOk = i == 1 or p.worlds[Worlds.Order[i - 1]] == true
		local accent = w.palette.accent
		local card = new("Frame", { Name = id, LayoutOrder = i, Size = UDim2.fromOffset(CARD_W, 350), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = row })
		UIKit.corner(card, 14)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(T.stoneTop, T.stoneBot), Parent = card })
		UIKit.stroke(card, unlocked and accent or Color3.fromRGB(70, 70, 86), unlocked and 4 or 3, 0)
		-- arte do mundo
		local art = new("Frame", { Name = "Art", Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, ART_H), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
			ClipsDescendants = true, Parent = card })
		UIKit.corner(art, 10)
		local top, bottom = w.palette.fog, w.palette.ground
		if not unlocked then
			top, bottom = Color3.fromRGB(96, 96, 112), Color3.fromRGB(48, 48, 60)
		end
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(0.62, top:Lerp(bottom, 0.5)), ColorSequenceKeypoint.new(1, bottom) }), Parent = art })
		-- colina e marco do mundo
		local hill = new("Frame", { Name = "Hill", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -34), Size = UDim2.new(1.4, 0, 0, 80), BackgroundColor3 = unlocked and UIKit.darken(w.palette.ground, 0.15) or Color3.fromRGB(40, 40, 50),
			BorderSizePixel = 0, Parent = art })
		UIKit.corner(hill, 100)
		UIKit.label({ Name = "Landmark", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(96, 96), Text = WORLD_ART[id] or "✦", TextSize = 78,
			TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, TextTransparency = unlocked and 0 or 0.55, ZIndex = 2, Parent = art })
		if not unlocked then
			local shade = new("Frame", { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 4, Parent = art })
			UIKit.corner(shade, 10)
			local aw = CARD_W - 12
			chain(art, -6, 8, aw + 6, ART_H - 8)
			chain(art, aw + 6, 8, -6, ART_H - 8)
			-- cadeado mágico com runa do acento pulsando
			local lock = new("Frame", { Name = "Lock", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0, ZIndex = 8, Parent = art })
			UIKit.corner(lock, 100)
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(240, 210, 130), Color3.fromRGB(150, 104, 40)), Parent = lock })
			UIKit.stroke(lock, T.woodEdge, 3, 0)
			UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "🔒", TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, ZIndex = 9, Parent = lock })
			local ring = new("Frame", { Name = "Rune", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(72, 72), BackgroundTransparency = 1, ZIndex = 7, Parent = art })
			UIKit.corner(ring, 100)
			local rs = UIKit.stroke(ring, accent, 4, 0.4)
			UIKit.animate(ring, function(t)
				rs.Transparency = 0.6 + math.sin(t * (2 * math.pi / 1.4)) * 0.2
			end)
		end
		-- textos
		UIKit.label({ Position = UDim2.fromOffset(10, ART_H + 12), Size = UDim2.new(1, -20, 0, 14), Text = "MUNDO " .. i, Font = T.body, TextSize = 11, TextColor3 = unlocked and accent or T.muted,
			TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		UIKit.label({ Position = UDim2.fromOffset(8, ART_H + 26), Size = UDim2.new(1, -16, 0, 46), Text = w.name, Font = T.title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0, TextStrokeColor3 = T.edgeDark, Parent = card })
		local boss = Bosses.Info[w.bossId]
		UIKit.label({ Position = UDim2.fromOffset(8, ART_H + 72), Size = UDim2.new(1, -16, 0, 30), Text = string.format("Boss: %s\nAtributos x%.2f", boss.name, w.statMult), TextSize = 11,
			TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		local bottomY = 350 - 10
		if id == here and unlocked then
			local tag = new("Frame", { Name = "Here", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, bottomY), Size = UDim2.new(1, -20, 0, 34), BackgroundColor3 = accent,
				BorderSizePixel = 0, Parent = card })
			UIKit.corner(tag, 100)
			UIKit.stroke(tag, UIKit.darken(accent, 0.6), 3, 0)
			UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "📍 Você está aqui", Font = T.title, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0,
				TextStrokeColor3 = UIKit.darken(accent, 0.7), Parent = tag })
			local tsc = new("UIScale", { Parent = tag })
			UIKit.animate(tag, function(t)
				tsc.Scale = 1 + math.sin(t * 3) * 0.035
			end)
		elseif unlocked then
			UIKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, bottomY), Size = UDim2.new(1, -20, 0, 36), Text = "Teleportar", TextSize = 16, BackgroundColor3 = T.confirm,
				Parent = card }, function()
				local r = State.request("Teleport", { world = id })
				toastResult(r)
				if r.ok then
					Panels.close()
					travelFx(id)
				end
			end)
		else
			local cost = w.unlockCost
			local have = p.coins or 0
			UIKit.label({ Position = UDim2.fromOffset(8, ART_H + 106), Size = UDim2.new(1, -16, 0, 20), Text = "● " .. UIKit.fmt(cost) .. " Moedas", Font = T.title, TextSize = 15,
				TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0, TextStrokeColor3 = T.edgeDark, Parent = card })
			local prog = UIKit.vesselBar({ Name = "Need", Position = UDim2.fromOffset(12, ART_H + 130), Size = UDim2.new(1, -24, 0, 14), color = T.gold, textSize = 10, Parent = card })
			prog.set(cost > 0 and have / cost or 1, "")
			local canPay = prevOk and have >= cost
			local text = not prevOk and ("Abra o Mundo " .. (i - 1)) or canPay and "Desbloquear" or ("Faltam ● " .. UIKit.fmt(cost - have))
			UIKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, bottomY), Size = UDim2.new(1, -20, 0, 36), Text = text, TextSize = canPay and 16 or 12,
				BackgroundColor3 = canPay and T.yellow or T.gray, Parent = card }, function()
				if canPay then
					local r = State.request("UnlockWorld", { world = id })
					toastResult(r)
					if r.ok then
						UIKit.burst(card, accent, 16)
						UIKit.pop(card, 0.2)
					end
				end
			end)
		end
	end
	-- trilha de progresso
	local track = new("Frame", { Name = "Track", Position = UDim2.fromOffset(0, 400), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = content })
	local total = #Worlds.Order * CARD_W + (#Worlds.Order - 1) * 12
	local x0 = -total / 2 + CARD_W / 2
	local line = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(total - CARD_W, 6), BackgroundColor3 = T.inset, BorderSizePixel = 0, Parent = track })
	UIKit.corner(line, 3)
	UIKit.stroke(line, T.edgeDark, 2, 0)
	for i, id in ipairs(Worlds.Order) do
		local on = p.worlds[id] == true
		local dot = new("Frame", { Name = "Stop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x0 + (i - 1) * (CARD_W + 12), 0.5, 0), Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = on and Worlds.Info[id].palette.accent or T.inset, BorderSizePixel = 0, ZIndex = 2, Parent = track })
		UIKit.corner(dot, 100)
		UIKit.stroke(dot, T.edgeDark, 3, 0)
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
	toggle(4, "Guia do objetivo (feixe até a missão)", "guide", p.settings.guide ~= false and "ligado" or "desligado", p.settings.guide == false)
	toggle(3, "Qualidade de efeitos", "vfx", p.settings.vfx == "Low" and "Baixa" or "Alta", p.settings.vfx == "Low" and "High" or "Low")
	-- qualidade do modelo dos SEUS pets no modo de peças (sem EditableMesh): só neste aparelho
	local PetVisuals = require(script.Parent.PetVisuals)
	UIKit.button({ LayoutOrder = 3, Size = UDim2.new(1, -8, 0, 38), TextSize = 14, Parent = list,
		Text = "Qualidade dos seus pets: " .. (PetVisuals.highQuality and "Alta (mais detalhes)" or "Leve (mais rápido)") }, function()
		PetVisuals.setHighQuality(not PetVisuals.highQuality)
		Panels.open("Settings")
	end)
	UIKit.label({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 70), TextSize = 12, TextColor3 = T.muted,
		Text = "Controles: clique/toque num inimigo para mirar e atacar · F ataque · 1-4 habilidades dos pets · Tab/Q próximo alvo · clique num recurso para os pets minerarem · E nas estações e portais." ..
			(State.memoryMode and "\n<font color=\"#FF6464\">Modo memória: progresso não está sendo salvo.</font>" or ""), Parent = list })
	if RunService:IsStudio() then
		UIKit.label({ LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 22), Text = "Testes (somente no Studio)", Font = T.title, TextSize = 17, TextColor3 = T.bad, Parent = list })
		for i, c in ipairs({ { "currency", "+1M moedas, +50K essência" }, { "items", "Todos os itens" }, { "unlock", "Desbloquear mundos" }, { "levels", "Equipe no nível máximo" },
			{ "luck_event", "Evento de sorte +100% (10 min)" }, { "boss_phase", "Boss atual: -35% vida (testar fases)" }, { "treasure", "Gerar tesouro" }, { "star", "Gerar Estrela Errante" },
			{ "luck_report", "Mostrar multiplicadores (servidor)" } }) do
			UIKit.button({ LayoutOrder = 10 + i, Size = UDim2.new(1, -8, 0, 32), Text = c[2], TextSize = 13, BackgroundColor3 = T.red, Parent = list }, function()
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
	local info = UIKit.label({ Size = UDim2.new(0.6, -6, 0, 30), TextSize = 13, TextColor3 = T.muted,
		Text = string.format("Chances REAIS com a sua sorte atual (pets raros x%.2f), calculadas pelo servidor.", r.mult), Parent = content })
	local list = UIKit.scroll({ Position = UDim2.fromOffset(0, 32), Size = UDim2.new(0.6, -6, 1, -90), Parent = content })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(118, 156), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local _ = info
	-- mais raros primeiro (ovos com 70+ pets): miniaturas 3D só para os primeiros
	table.sort(r.entries, function(a, b)
		local ra, rb = Rarities.rank(Pets.Species[a.key].rarity), Rarities.rank(Pets.Species[b.key].rarity)
		if ra ~= rb then
			return ra > rb
		end
		return a.key < b.key
	end)
	for i, o in ipairs(r.entries) do
		local sp = Pets.Species[o.key]
		local rar = Rarities.Info[sp.rarity]
		local card = UIKit.frame({ LayoutOrder = i, BackgroundColor3 = UIKit.darken(rar.color, 0.2), Parent = list })
		UIKit.stroke(card, UIKit.darken(rar.color, 0.65), 3, 0)
		local view = new("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 76), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82,
			BorderSizePixel = 0, ZIndex = 2, Parent = card })
		UIKit.corner(view, 10)
		local known = State.profile.bestiary.pets[o.key] ~= nil
		if i <= MAX_THUMBS then
			thumb(view, o.key, nil, nil)
		end
		if not known then
			-- ainda não descoberto: silhueta
			for _, d in ipairs(view:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Color = Color3.fromRGB(20, 16, 40)
					d.Material = Enum.Material.SmoothPlastic
				end
			end
		end
		local tag = UIKit.frame({ Position = UDim2.fromOffset(6, 82), Size = UDim2.new(1, -12, 0, 18), BackgroundColor3 = rar.color, radius = 9, Parent = card })
		UIKit.stroke(tag, UIKit.darken(rar.color, 0.6), 2, 0)
		UIKit.label({ Size = UDim2.fromScale(1, 1), Text = rar.label, Font = T.title, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeColor3 = UIKit.darken(rar.color, 0.7), TextStrokeTransparency = 0, Parent = tag })
		UIKit.label({ Position = UDim2.fromOffset(4, 101), Size = UDim2.new(1, -8, 0, 18), Text = known and sp.name or "???", Font = T.title, TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
		local changed = math.abs(o.p - o.base) > 1e-9
		UIKit.label({ Position = UDim2.fromOffset(4, 119), Size = UDim2.new(1, -8, 0, 22), Text = UIKit.pct(o.p), Font = T.title, TextSize = 20,
			TextColor3 = o.reason and T.bad or (changed and T.luck or Color3.new(1, 1, 1)), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0, Parent = card })
		UIKit.label({ Position = UDim2.fromOffset(4, 139), Size = UDim2.new(1, -8, 0, 14), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = T.muted,
			Text = o.reason and "🔒 bloqueado" or (changed and ("base " .. UIKit.pct(o.base)) or ""), Parent = card })
		if o.reason then
			card:SetAttribute("Reason", o.reason)
		end
	end
	local reasons = {}
	for _, o in ipairs(r.entries) do
		if o.reason then
			table.insert(reasons, "🔒 " .. Pets.Species[o.key].name .. ": " .. o.reason)
		end
	end
	if #reasons > 0 then
		UIKit.label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -54), Size = UDim2.new(0.6, -6, 0, 30), TextSize = 12, TextColor3 = Color3.fromRGB(255, 160, 140),
			Text = table.concat(reasons, "\n"), Parent = content })
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
		UIKit.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(280, 50), TextSize = 20, Text = string.format("🥚 Chocar (você tem %d)", r.owned or 0),
			BackgroundColor3 = T.pink, Parent = content }, function()
			hatchRes(State.request("HatchItem", { egg = eggId }))
		end)
	else
		local cur = Items.label(r.currency)
		UIKit.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(240, 50), TextSize = 20, Text = string.format("🥚 Chocar 1 (%s %s)", UIKit.fmt(r.cost), cur),
			BackgroundColor3 = T.green, Parent = content }, function()
			hatchRes(State.request("Hatch", { egg = eggId, count = 1 }))
		end)
		UIKit.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 250, 1, 0), Size = UDim2.fromOffset(240, 50), TextSize = 20, Text = string.format("🥚🥚🥚 Chocar 3 (%s %s)", UIKit.fmt(r.cost * 3), cur),
			BackgroundColor3 = T.blue, Parent = content }, function()
			hatchRes(State.request("Hatch", { egg = eggId, count = 3 }))
		end)
	end
end

-------------------------------------------------------------------------------

local BUILDERS = { Pets = petsPanel, Items = itemsPanel, Luck = luckPanel, Bestiary = bestiaryPanel, Quests = questsPanel, Map = mapPanel, Settings = settingsPanel }
local TITLES = { Pets = "Pets e Equipe", Items = "Itens", Luck = "Sorte", Bestiary = "Bestiário", Quests = "Missões", Map = "Mundos", Settings = "Opções" }

local PANEL_COLORS = {
	Pets = T.orange, Items = T.blue, Luck = T.green, Bestiary = T.purple, Quests = T.yellow, Map = T.teal, Settings = T.gray, Egg = T.pink,
}

function Panels.open(name: string, arg)
	if not State.profile then
		return
	end
	current = { name = name, arg = arg }
	if not modal.Visible then
		-- abertura (Design System 6): escurece e desfoca o mundo, a janela entra com "Back Out"
		local os = modal:FindFirstChild("OpenScale") :: UIScale
		os.Scale = 0.85
		TweenService:Create(os, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		scrim.Visible = true
		scrim.BackgroundTransparency = 1
		TweenService:Create(scrim, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()
		TweenService:Create(blur, TweenInfo.new(0.25), { Size = 14 }):Play()
	end
	modal.Visible = true
	-- cor do painel nas runas dos cantos, no brilho e nos cristais da placa
	local color = PANEL_COLORS[name] or T.orange
	for _, c in ipairs(modal:GetChildren()) do
		if c.Name == "CornerRune" then
			c.BackgroundColor3 = color
		elseif c.Name == "Glow" then
			local st = c:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = color
			end
		end
	end
	for _, c in ipairs(titlePlaque:GetChildren()) do
		if c.Name == "Gem" then
			c.BackgroundColor3 = color
		end
	end
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
	scrim.Visible = false
	TweenService:Create(blur, TweenInfo.new(0.2), { Size = 0 }):Play()
	current = nil
end

function Panels.init()
	gui = UIKit.screen("Panels", 10)
	scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.scrim, BackgroundTransparency = 1, BorderSizePixel = 0, Active = true, Visible = false, Parent = gui })
	blur = Lighting:FindFirstChild("PanelBlur") or new("BlurEffect", { Name = "PanelBlur", Size = 0, Parent = Lighting })
	local body
	modal, body = UIKit.runeFrame({ Name = "Modal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(900, 560), Visible = false,
		glow = true, radius = 20, Parent = gui })
	-- placa de madeira do título com cristais nas pontas
	titlePlaque, titleLabel = UIKit.woodPlaque({ Name = "TitlePlaque", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(360, 54), Text = "",
		TextSize = 30, radius = 16, ZIndex = 4, Parent = modal })
	for _, x in ipairs({ 0, 1 }) do
		local gem = new("Frame", { Name = "Gem", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, 0, 0.5, 0), Size = UDim2.fromOffset(22, 22), Rotation = 45,
			BackgroundColor3 = T.orange, BorderSizePixel = 0, ZIndex = 5, Parent = titlePlaque })
		UIKit.corner(gem, 4)
		UIKit.stroke(gem, T.edgeDark, 3, 0)
		new("UIGradient", { Rotation = 0, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 140)), Parent = gem })
	end
	local close = UIKit.button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(50, 50), Text = "✕", TextSize = 26,
		BackgroundColor3 = T.cancel, ZIndex = 6, Parent = modal }, Panels.close)
	UIKit.corner(close, 25)
	content = new("Frame", { Name = "Content", Position = UDim2.fromOffset(22, 42), Size = UDim2.new(1, -44, 1, -60), BackgroundTransparency = 1, Parent = body })
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

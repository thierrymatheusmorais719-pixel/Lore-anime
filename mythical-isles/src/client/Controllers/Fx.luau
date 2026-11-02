-- Efeitos visuais do cliente (todos locais e com limite de objetos):
--   números de dano, efeitos de habilidades e impactos, animação dos indicadores de ataque,
--   visibilidade dos tesouros e a animação de chocar ovos (com revelação especial SECRET/CELESTIAL).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local CreatureBuilder = require(Shared.Builders.CreatureBuilder)
local MutationVisuals = require(Shared.Builders.MutationVisuals)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)

local Fx = {}

local player = Players.LocalPlayer
local folder: Folder
local activeParts = 0
local MAX_PARTS = 90
local numberPool = {}
local NUMBER_POOL = 36

local function lowVfx(): boolean
	return State.profile and State.profile.settings and State.profile.settings.vfx == "Low"
end

local function part(props, life: number)
	if activeParts >= MAX_PARTS then
		return nil
	end
	activeParts += 1
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = folder
	task.delay(life, function()
		p:Destroy()
		activeParts -= 1
	end)
	return p
end

local function tween(inst, time: number, goal, style)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

-- Anel que se expande no chão.
local function ring(at: Vector3, radius: number, color: Color3, time: number?)
	local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1, 1), CFrame = CFrame.new(at + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color, Transparency = 0.2 }, (time or 0.5) + 0.05)
	if p then
		tween(p, time or 0.5, { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 })
	end
end

local function orb(from: Vector3, to: Vector3, color: Color3, travel: number, size: number)
	local p = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(from), Color = color }, travel + 0.05)
	if p then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8
		light.Brightness = 2
		light.Parent = p
		tween(p, travel, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Linear)
	end
end

local function sparks(at: Vector3, color: Color3, count: number)
	local anchor = part({ Size = Vector3.one * 0.2, CFrame = CFrame.new(at), Transparency = 1 }, 1.2)
	if not anchor then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.8
	e.Size = NumberSequence.new(0.5, 0)
	e.Speed = NumberRange.new(8, 16)
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = anchor
	e:Emit(lowVfx() and math.ceil(count / 2) or count)
end

-------------------------------------------------------------------------------
-- Números de dano
-------------------------------------------------------------------------------

local COLORS = {
	hit = Color3.fromRGB(255, 255, 255), crit = Color3.fromRGB(255, 200, 60), pet = Color3.fromRGB(255, 120, 120),
	player = Color3.fromRGB(255, 80, 80), heal = Color3.fromRGB(120, 255, 150), coins = Color3.fromRGB(255, 220, 90),
}

local function showNumber(ev)
	local slot
	for _, s in ipairs(numberPool) do
		if not s.busy then
			slot = s
			break
		end
	end
	if not slot then
		return
	end
	slot.busy = true
	local offset = Vector3.new(math.random() * 2 - 1, math.random(), math.random() * 2 - 1)
	slot.part.CFrame = CFrame.new(ev.p + offset)
	local label = slot.label
	label.Text = (ev.k == "heal" and "+" or ev.k == "coins" and "+● " or "") .. UIKit.fmt(ev.a) .. (ev.c and "!" or "")
	label.TextColor3 = COLORS[ev.k] or COLORS.hit
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.3
	slot.gui.Size = UDim2.fromOffset(ev.c and 120 or 90, ev.c and 44 or 32)
	slot.gui.Enabled = true
	tween(slot.part, 0.8, { CFrame = slot.part.CFrame + Vector3.new(0, 3, 0) })
	task.delay(0.45, function()
		tween(label, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(0.85, function()
		slot.gui.Enabled = false
		slot.busy = false
	end)
end

-------------------------------------------------------------------------------
-- Habilidades e impactos
-------------------------------------------------------------------------------

local function onAbilityFx(p)
	local c = p.color or Color3.new(1, 1, 1)
	local k = p.kind
	if k == "bolt" then
		orb(p.from, p.to, c, math.clamp((p.to - p.from).Magnitude / 90, 0.05, 0.4), p.small and 0.6 or 1.2)
		if not p.small then
			task.delay(0.2, sparks, p.to, c, 10)
		end
	elseif k == "orb" then
		orb(p.from, p.to, c, p.travel or 0.5, 1.6)
		task.delay(p.travel or 0.5, function()
			ring(p.to, 5, c, 0.35)
		end)
	elseif k == "charge" then
		local mid = (p.from + p.to) / 2
		local len = (p.to - p.from).Magnitude
		local streak = part({ Size = Vector3.new(0.8, 0.8, math.max(len, 1)), CFrame = CFrame.lookAt(mid, p.to), Color = c, Transparency = 0.3 }, 0.35)
		if streak then
			tween(streak, 0.3, { Transparency = 1, Size = Vector3.new(0.1, 0.1, math.max(len, 1)) })
		end
		sparks(p.to, c, 16)
	elseif k == "shield" and p.model and p.model.PrimaryPart then
		local size = p.model:GetExtentsSize().Magnitude * 0.75
		local bubble = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = p.model.PrimaryPart.CFrame, Color = c,
			Material = Enum.Material.ForceField, Transparency = 0.1 }, p.duration or 6)
		if bubble then
			local conn
			conn = RunService.RenderStepped:Connect(function()
				if not bubble.Parent or not p.model.PrimaryPart then
					conn:Disconnect()
					return
				end
				bubble.CFrame = p.model.PrimaryPart.CFrame
			end)
		end
	elseif k == "heal" or k == "haste" or k == "sense" then
		ring(p.at, p.radius or 20, c, k == "sense" and 0.9 or 0.6)
		sparks(p.at + Vector3.new(0, 2, 0), c, 14)
	elseif k == "shockwave" or k == "slam" then
		ring(p.at, p.radius or 12, c, 0.45)
		sparks(p.at, c, 12)
	elseif k == "starfall" then
		for i = 1, (lowVfx() and 3 or 6) do
			local a = i / 6 * math.pi * 2
			local land = p.at + Vector3.new(math.cos(a), 0, math.sin(a)) * (p.radius or 10) * 0.5 * math.random()
			task.delay(i * 0.05, orb, land + Vector3.new(4, 30, 4), land, c, 0.4, 1.4)
		end
		task.delay(0.45, ring, p.at, p.radius or 12, c, 0.5)
	elseif k == "sunder" then
		sparks(p.to, c, 20)
		ring(p.to, 4, c, 0.3)
	elseif k == "snare" then
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local base = p.at + Vector3.new(math.cos(a), 0, math.sin(a)) * (p.radius or 4)
			local vine = part({ Size = Vector3.new(0.5, 0.1, 0.5), CFrame = CFrame.new(base), Color = c, Material = Enum.Material.Grass }, (p.duration or 2) + 0.3)
			if vine then
				tween(vine, 0.25, { Size = Vector3.new(0.5, 6, 0.5), CFrame = CFrame.new(base + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(-12)) })
			end
		end
	elseif k == "burst" then
		sparks(p.at, c, 18)
		ring(p.at, p.radius or 5, c, 0.4)
	elseif k == "bossImpact" and p.shapes then
		for _, s in ipairs(p.shapes) do
			if s.type == "circle" then
				ring(Vector3.new(s.x, p.y + 1, s.z), s.r, c, 0.4)
			elseif s.type == "ring" then
				ring(Vector3.new(s.x, p.y + 1, s.z), s.outer, c, 0.5)
			elseif s.type == "rect" then
				local mid = Vector3.new(s.x + s.dx * s.length / 2, p.y + 1.5, s.z + s.dz * s.length / 2)
				local slab = part({ Size = Vector3.new(s.width, 1.5, s.length), CFrame = CFrame.lookAt(mid, mid + Vector3.new(s.dx, 0, s.dz)), Color = c, Transparency = 0.2 }, 0.45)
				if slab then
					tween(slab, 0.4, { Transparency = 1 })
				end
			elseif s.type == "cone" then
				ring(Vector3.new(s.x, p.y + 1, s.z), s.length, c, 0.4)
			elseif s.type == "safezones" then
				ring(Vector3.new(s.x, p.y + 1, s.z), s.r, c, 0.6)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Indicadores de ataque (geometria vem do servidor; aqui só a animação)
-------------------------------------------------------------------------------

local function animateTelegraph(model: Instance)
	task.wait()
	local start = model:GetAttribute("Start") or workspace:GetServerTimeNow()
	local duration = model:GetAttribute("Duration") or 1
	local label = model:GetAttribute("Label")
	local fills = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("TelegraphFill") then
			table.insert(fills, { part = d, size = d.Size, circle = (d :: any).Shape == Enum.PartType.Cylinder })
		end
	end
	if label and label ~= "" then
		local first = model:FindFirstChildWhichIsA("BasePart")
		if first then
			local gui = UIKit.new("BillboardGui", { Size = UDim2.fromOffset(240, 34), StudsOffsetWorldSpace = Vector3.new(0, 6, 0), AlwaysOnTop = true, MaxDistance = 200, Adornee = first, Parent = model })
			UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "⚠ " .. label, TextColor3 = Color3.fromRGB(255, 120, 100), Font = UIKit.Theme.title, TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, Parent = gui })
		end
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not model.Parent then
			conn:Disconnect()
			return
		end
		local f = math.clamp((workspace:GetServerTimeNow() - start) / duration, 0, 1)
		for _, fd in ipairs(fills) do
			if fd.part.Parent then
				if fd.circle then
					local k = 0.05 + 0.95 * f
					fd.part.Size = Vector3.new(fd.size.X, fd.size.Y * k, fd.size.Z * k)
				else
					fd.part.Transparency = 0.75 - 0.45 * f + math.sin(os.clock() * 18) * 0.05 * f
				end
			end
		end
	end)
end

-------------------------------------------------------------------------------
-- Tesouros (cada jogador só vê os próprios)
-------------------------------------------------------------------------------

local function setupTreasure(m: Instance)
	task.wait()
	if not m:IsA("Model") then
		return
	end
	local mine = m:GetAttribute("OwnerId") == player.UserId
	local function refresh()
		local revealed = m:GetAttribute("Revealed") == true
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = (not mine) and 1 or (revealed and 0 or (d.Name == "Glint" and 0 or 0.65))
			end
		end
		local h = m:FindFirstChild("RevealHighlight")
		if mine and revealed and not h then
			UIKit.new("Highlight", { Name = "RevealHighlight", FillColor = Color3.fromRGB(255, 220, 120), OutlineColor = Color3.fromRGB(255, 240, 180),
				FillTransparency = 0.6, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = m })
			local gui = UIKit.new("BillboardGui", { Size = UDim2.fromOffset(120, 30), StudsOffset = Vector3.new(0, 5, 0), AlwaysOnTop = true, Adornee = m.PrimaryPart, Parent = m })
			UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "◈ Tesouro", TextColor3 = UIKit.Theme.gold, Font = UIKit.Theme.title, TextSize = 20,
				TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, Parent = gui })
		end
	end
	refresh()
	m:GetAttributeChangedSignal("Revealed"):Connect(refresh)
	if mine and m.PrimaryPart then
		local prompt = UIKit.new("ProximityPrompt", { ActionText = "Abrir", ObjectText = "Tesouro", HoldDuration = 0.5, MaxActivationDistance = 10,
			RequiresLineOfSight = false, Parent = m.PrimaryPart })
		prompt.Triggered:Connect(function()
			State.action("OpenTreasure", m)
		end)
	end
end

-------------------------------------------------------------------------------
-- Animação de chocar ovo
-------------------------------------------------------------------------------

local hatchGui
local function viewport(parent: Instance, species: string, mutation: string?)
	local vp = UIKit.new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, LightColor = Color3.new(1, 1, 1),
		Ambient = Color3.fromRGB(170, 170, 190), LightDirection = Vector3.new(-1, -1, -1), Parent = parent })
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam
	local model = CreatureBuilder.build(species, Pets.Species[species], 1)
	MutationVisuals.apply(model, mutation)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = vp
	local size = model:GetExtentsSize().Magnitude
	local angle = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not vp.Parent then
			conn:Disconnect()
			return
		end
		angle += dt * 0.9
		cam.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle) * size * 1.3, size * 0.35, math.cos(angle) * size * 1.3), Vector3.new(0, 0, 0))
	end)
	return vp
end

function Fx.hatch(results, eggColor: Color3?)
	if hatchGui then
		hatchGui:Destroy()
	end
	local gui = UIKit.screen("HatchFx", 50)
	hatchGui = gui
	local special = false
	for _, r in ipairs(results) do
		if r.special then
			special = true
		end
	end
	local dim = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = special and Color3.fromRGB(5, 4, 12) or Color3.fromRGB(10, 10, 20),
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
	tween(dim, 0.3, { BackgroundTransparency = special and 0.1 or 0.35 })
	local row = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(#results * 300, 360),
		BackgroundTransparency = 1, Parent = gui })
	UIKit.list(row, Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center)
	for _, r in ipairs(results) do
		local sp = Pets.Species[r.species]
		local rarity = Rarities.Info[r.rarity]
		local card = UIKit.new("Frame", { Size = UDim2.fromOffset(280, 360), BackgroundTransparency = 1, Parent = row })
		-- ovo que treme
		local egg = UIKit.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(120, 150),
			BackgroundColor3 = eggColor or Color3.fromRGB(240, 230, 200), radius = 70, Parent = card })
		UIKit.stroke(egg, Color3.new(1, 1, 1), 3, 0.3)
		local buildup = r.special and 2.6 or 1.2
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < buildup do
				local k = (os.clock() - t0) / buildup
				egg.Rotation = math.sin(os.clock() * (12 + k * 30)) * (6 + k * 14)
				if r.special then
					dim.BackgroundColor3 = rarity.color:Lerp(Color3.new(0, 0, 0), 0.85 - k * 0.5)
				end
				task.wait()
			end
			egg:Destroy()
			-- clarão + revelação
			local glow = UIKit.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(40, 40),
				BackgroundColor3 = rarity.accent or rarity.color, radius = 200, Parent = card })
			tween(glow, 0.5, { Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 1 })
			local view = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 250), BackgroundTransparency = 1, Parent = card })
			viewport(view, r.species, r.mutation)
			local title = r.rarity == "Secret" and "SECRET!" or r.rarity == "Celestial" and "CELESTIAL!" or rarity.label
			local rl = UIKit.label({ Position = UDim2.fromOffset(0, 244), Size = UDim2.new(1, 0, 0, 34), Text = title, Font = UIKit.Theme.title,
				TextSize = r.special and 34 or 26, TextColor3 = rarity.accent or rarity.color, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, Parent = card })
			if r.special then
				local grad = UIKit.new("UIGradient", { Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, rarity.color), ColorSequenceKeypoint.new(0.5, rarity.accent or Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, rarity.color) }),
					Parent = rl })
				task.spawn(function()
					while grad.Parent do
						grad.Offset = Vector2.new(math.sin(os.clock() * 2) * 0.5, 0)
						task.wait()
					end
				end)
			end
			local mut = r.mutation and Mutations.Info[r.mutation]
			UIKit.label({ Position = UDim2.fromOffset(0, 278), Size = UDim2.new(1, 0, 0, 26),
				Text = (mut and string.format('<font color="#%s">%s</font> ', mut.color:ToHex(), r.mutation) or "") .. sp.name,
				Font = UIKit.Theme.title, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, Parent = card })
			UIKit.label({ Position = UDim2.fromOffset(0, 306), Size = UDim2.new(1, 0, 0, 40),
				Text = string.format("Chance: %s%s", UIKit.pct(r.chance or 0), r.newSpecies and "  •  NOVO no bestiário!" or ""),
				TextSize = 14, TextColor3 = UIKit.Theme.muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		end)
	end
	local closeAt = special and 6.5 or 3.6
	local close = UIKit.button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromOffset(180, 44), Text = "Continuar",
		BackgroundColor3 = Color3.fromRGB(70, 160, 110), Parent = gui }, function()
		gui:Destroy()
	end)
	close.Visible = false
	task.delay(special and 2.8 or 1.4, function()
		close.Visible = true
	end)
	task.delay(closeAt, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

function Fx.init()
	folder = Instance.new("Folder")
	folder.Name = "LocalFx"
	folder.Parent = workspace.CurrentCamera
	for _ = 1, NUMBER_POOL do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Transparency = 1
		p.Size = Vector3.one * 0.2
		p.Parent = folder
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(90, 32)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 140
		gui.Enabled = false
		gui.Adornee = p
		gui.Parent = p
		local label = UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "", Font = UIKit.Theme.title, TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, Parent = gui })
		table.insert(numberPool, { part = p, gui = gui, label = label, busy = false })
	end
	State.on("Damage", function(list)
		if State.profile and State.profile.settings and State.profile.settings.damageNumbers == false then
			return
		end
		for _, ev in ipairs(list) do
			showNumber(ev)
		end
	end)
	State.on("AbilityFx", onAbilityFx)
	task.spawn(function()
		local tele = workspace:WaitForChild("Telegraphs", 30)
		if tele then
			tele.ChildAdded:Connect(function(m)
				task.spawn(animateTelegraph, m)
			end)
		end
	end)
	task.spawn(function()
		local tf = workspace:WaitForChild("Treasures", 30)
		if tf then
			for _, m in ipairs(tf:GetChildren()) do
				task.spawn(setupTreasure, m)
			end
			tf.ChildAdded:Connect(function(m)
				task.spawn(setupTreasure, m)
			end)
		end
	end)
	-- Estrela Errante de outro jogador aparece translúcida
	task.spawn(function()
		local ef = workspace:WaitForChild("Enemies", 30)
		if ef then
			ef.ChildAdded:Connect(function(m)
				task.wait()
				local owner = m:GetAttribute("OwnerId")
				if owner and owner ~= player.UserId then
					for _, d in ipairs(m:GetDescendants()) do
						if d:IsA("BasePart") then
							d.LocalTransparencyModifier = 0.7
						end
					end
				end
			end)
		end
	end)
end

Fx.sparks = sparks
Fx.ring = ring
return Fx

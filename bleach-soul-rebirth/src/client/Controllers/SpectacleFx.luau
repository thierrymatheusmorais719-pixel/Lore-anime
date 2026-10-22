-- Efeitos de "espetáculo" estilo anime, todos locais:
-- • Impact frame (quadro estourado/negativo P&B), pulso de desfoque, zoom de impacto
-- • Crateras com rachaduras, detritos balísticos, linhas de impacto radiais
-- • Kanji gigante no mundo, espiral de Reiatsu, pedras que levitam pela pressão espiritual
-- • Auras por elemento: arcos elétricos, chamas, névoa de gelo, anel lunar, chamas negras,
--   auréola/asas de luz (Quincy), pedras orbitando os pés no Tier 2
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local VFX = require(script.Parent.VFXController)

local SpectacleFx = {}

local player = Players.LocalPlayer
local rng = Random.new()
local impactCC: ColorCorrectionEffect
local blur: BlurEffect
local impactToken = 0

local mapParams = RaycastParams.new()
mapParams.FilterType = Enum.RaycastFilterType.Include

local function refreshMapFilter()
	local map = workspace:FindFirstChild("Map")
	mapParams.FilterDescendantsInstances = if map then { map, workspace.Terrain } else { workspace.Terrain }
end

local function lowQuality(): boolean
	return VFX.Quality() == "Low"
end

-- ============================================================
-- Tela
-- ============================================================

-- Impact frame: 1 quadro estourado em branco, 1 quadro escuro de alto contraste, volta ao normal.
function SpectacleFx.ImpactFrame(strength: number?)
	local s = strength or 1
	impactToken += 1
	local token = impactToken
	impactCC.Enabled = true
	impactCC.Saturation = -1
	impactCC.Contrast = 2.2 * s
	impactCC.Brightness = 0.45 * s
	impactCC.TintColor = Color3.new(1, 1, 1)
	task.delay(0.045, function()
		if impactToken ~= token then
			return
		end
		impactCC.Brightness = -0.35 * s
		impactCC.Contrast = 3 * s
	end)
	task.delay(0.1, function()
		if impactToken ~= token then
			return
		end
		impactCC.Saturation = -0.4
		impactCC.Contrast = 0.6
		impactCC.Brightness = 0.05
		VFX.tween(impactCC, 0.18, { Saturation = 0, Contrast = 0, Brightness = 0 })
	end)
	task.delay(0.3, function()
		if impactToken == token then
			impactCC.Enabled = false
		end
	end)
end

function SpectacleFx.BlurPulse(size: number?, duration: number?)
	if lowQuality() then
		return
	end
	blur.Size = size or 14
	VFX.tween(blur, duration or 0.25, { Size = 0 })
end

-- Escurece o ambiente por `duration` (pressão espiritual de um Bankai/ultimate).
function SpectacleFx.DarkenWorld(color: Color3, duration: number)
	impactToken += 1
	local token = impactToken
	impactCC.Enabled = true
	impactCC.Saturation = 0
	impactCC.Brightness = 0
	impactCC.Contrast = 0
	impactCC.TintColor = Color3.new(1, 1, 1)
	VFX.tween(impactCC, 0.4, {
		TintColor = color:Lerp(Color3.new(1, 1, 1), 0.55),
		Brightness = -0.18,
		Contrast = 0.35,
		Saturation = -0.35,
	})
	task.delay(duration, function()
		if impactToken == token then
			VFX.tween(impactCC, 0.5, { TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0, Saturation = 0 })
			task.delay(0.55, function()
				if impactToken == token then
					impactCC.Enabled = false
				end
			end)
		end
	end)
end

-- ============================================================
-- Impactos no mundo
-- ============================================================

-- Linhas radiais brancas viradas para a câmera (estilo mangá).
function SpectacleFx.HitLines(position: Vector3, color: Color3?, count: number?, length: number?)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local n = if lowQuality() then 4 else (count or 8)
	local face = CFrame.lookAt(position, camera.CFrame.Position)
	local base = rng:NextNumber(0, math.pi * 2)
	for i = 1, n do
		local angle = base + i / n * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local len = (length or 3) * rng:NextNumber(0.7, 1.4)
		local cf = face * CFrame.Angles(0, 0, angle) * CFrame.new(0, 1.2 + len / 2, 0)
		local line = VFX.neon(Vector3.new(0.12, len, 0.05), cf, color or Color3.new(1, 1, 1), 0)
		VFX.tween(
			line,
			0.16,
			{ Size = Vector3.new(0.02, len * 1.6, 0.02), CFrame = cf * CFrame.new(0, len * 0.6, 0), Transparency = 1 }
		)
		Debris:AddItem(line, 0.2)
	end
end

type Chunk = { part: BasePart, velocity: Vector3, spin: Vector3, landed: boolean, born: number }
local chunks: { Chunk } = {}

local function groundInfo(position: Vector3): (Vector3, Color3, Enum.Material)
	refreshMapFilter()
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), mapParams)
	if hit then
		local color = if hit.Instance:IsA("BasePart") and hit.Instance ~= workspace.Terrain
			then (hit.Instance :: BasePart).Color
			else Color3.fromRGB(120, 115, 105)
		if hit.Instance == workspace.Terrain then
			if hit.Material == Enum.Material.Sand then
				color = Color3.fromRGB(230, 228, 220)
			elseif hit.Material == Enum.Material.Grass then
				color = Color3.fromRGB(80, 110, 60)
			elseif hit.Material == Enum.Material.Sandstone then
				color = Color3.fromRGB(170, 130, 95)
			end
		end
		return hit.Position, color, hit.Material
	end
	return position - Vector3.new(0, 3, 0), Color3.fromRGB(120, 115, 105), Enum.Material.Slate
end

-- Detritos com trajetória balística simulada (sem física real → baratos e sem empurrar ninguém).
function SpectacleFx.Debris(position: Vector3, count: number, power: number, color: Color3?)
	local _, groundColor = groundInfo(position)
	local n = if lowQuality() then math.ceil(count / 3) else count
	for _ = 1, n do
		local size = rng:NextNumber(0.4, 1.4)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Slate
		part.Color = color or groundColor
		part.Size = Vector3.new(size, size * rng:NextNumber(0.5, 1), size * rng:NextNumber(0.6, 1.2))
		part.CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-1, 1), 0.5, rng:NextNumber(-1, 1)))
		part.Parent = workspace:FindFirstChild("ClientVFX") or workspace
		local angle = rng:NextNumber(0, math.pi * 2)
		local horizontal = rng:NextNumber(0.3, 1) * power
		table.insert(chunks, {
			part = part,
			velocity = Vector3.new(
				math.cos(angle) * horizontal,
				rng:NextNumber(0.6, 1.3) * power,
				math.sin(angle) * horizontal
			),
			spin = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)),
			landed = false,
			born = os.clock(),
		})
	end
end

local function stepChunks(dt: number)
	local now = os.clock()
	for i = #chunks, 1, -1 do
		local c = chunks[i]
		if not c.part.Parent or now - c.born > 4 then
			c.part:Destroy()
			table.remove(chunks, i)
		elseif not c.landed then
			c.velocity += Vector3.new(0, -workspace.Gravity * 0.6 * dt, 0)
			local from = c.part.Position
			local step = c.velocity * dt
			local hit = if c.velocity.Y < 0 then workspace:Raycast(from, step, mapParams) else nil
			if hit then
				c.part.CFrame = CFrame.new(hit.Position + Vector3.new(0, c.part.Size.Y / 2, 0)) * c.part.CFrame.Rotation
				c.landed = true
				task.delay(1.5, function()
					if c.part.Parent then
						VFX.tween(c.part, 0.8, { Transparency = 1, Size = c.part.Size * 0.5 })
					end
				end)
			else
				local spin = c.spin * dt
				c.part.CFrame = (c.part.CFrame + step) * CFrame.Angles(spin.X, spin.Y, spin.Z)
			end
		end
	end
end

-- Cratera: anel de blocos inclinados + rachaduras + poeira + detritos.
function SpectacleFx.Crater(position: Vector3, radius: number, glow: Color3?)
	local ground, color = groundInfo(position)
	local folder = Instance.new("Model")
	folder.Name = "Crater"
	local pieces = if lowQuality() then 6 else math.clamp(math.floor(radius * 1.6), 8, 22)
	for i = 1, pieces do
		local angle = i / pieces * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local dist = radius * rng:NextNumber(0.75, 1)
		local size = Vector3.new(
			rng:NextNumber(1.5, 3) * radius / 6,
			rng:NextNumber(0.6, 1.4) * radius / 6,
			rng:NextNumber(1, 2.2) * radius / 6
		)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Slate
		p.Color = color:Lerp(Color3.new(0, 0, 0), 0.15)
		p.Size = size
		local base = ground + Vector3.new(math.cos(angle) * dist, -size.Y * 0.6, math.sin(angle) * dist)
		local final = CFrame.lookAt(base, ground)
			* CFrame.Angles(math.rad(-rng:NextNumber(25, 45)), 0, math.rad(rng:NextNumber(-15, 15)))
		p.CFrame = final - Vector3.new(0, size.Y, 0)
		p.Parent = folder
		VFX.tween(p, 0.12, { CFrame = final }, Enum.EasingStyle.Back)
	end
	-- Rachaduras radiais (brilhantes se `glow`)
	local cracks = if lowQuality() then 3 else 7
	for i = 1, cracks do
		local angle = i / cracks * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local length = radius * rng:NextNumber(1.1, 1.8)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local crack = Instance.new("Part")
		crack.Anchored = true
		crack.CanCollide = false
		crack.CanQuery = false
		crack.CanTouch = false
		crack.Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		crack.Color = glow or Color3.fromRGB(25, 22, 20)
		crack.Size = Vector3.new(rng:NextNumber(0.25, 0.5), 0.08, 0.1)
		local center = ground + dir * (length / 2) + Vector3.new(0, 0.05, 0)
		crack.CFrame = CFrame.lookAt(center, center + dir)
		crack.Parent = folder
		VFX.tween(crack, 0.15, { Size = Vector3.new(crack.Size.X, 0.08, length) })
	end
	folder.Parent = workspace:FindFirstChild("ClientVFX") or workspace
	VFX.emit("Dust", ground + Vector3.new(0, 1, 0), color:Lerp(Color3.new(1, 1, 1), 0.4), math.floor(radius * 2))
	SpectacleFx.Debris(ground, math.floor(radius * 1.5), 20 + radius * 2.5)
	task.delay(3.5, function()
		for _, p in folder:GetChildren() do
			if p:IsA("BasePart") then
				VFX.tween(p, 1, { Transparency = 1, CFrame = p.CFrame - Vector3.new(0, 1.5, 0) })
			end
		end
		task.wait(1.05)
		folder:Destroy()
	end)
end

-- Kanji gigante no mundo atrás do personagem (Bankai/ultimates/chefes).
function SpectacleFx.WorldKanji(anchor: BasePart, text: string, color: Color3, duration: number, size: number?)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.1
	holder.CFrame = anchor.CFrame * CFrame.new(0, 6, 8)
	holder.Parent = workspace:FindFirstChild("ClientVFX") or workspace
	local s = size or 22
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(s, s)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.MaxDistance = 400
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.TextTransparency = 1
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 1
	label.Parent = gui
	VFX.tween(label, 0.35, { TextTransparency = 0.15, TextStrokeTransparency = 0.3 })
	gui.Size = UDim2.fromScale(s * 1.4, s * 1.4)
	VFX.tween(gui, 0.5, { Size = UDim2.fromScale(s, s) }, Enum.EasingStyle.Back)
	task.delay(duration, function()
		VFX.tween(label, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
		VFX.tween(gui, 0.5, { Size = UDim2.fromScale(s * 1.6, s * 1.6) })
		task.wait(0.55)
		holder:Destroy()
	end)
end

-- Espiral de Reiatsu subindo ao redor do personagem.
function SpectacleFx.Helix(root: BasePart, color: Color3, duration: number, radius: number?, height: number?)
	local strands = if lowQuality() then 1 else 3
	local r = radius or 4
	local h = height or 40
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < duration and root.Parent do
			local t = os.clock() - start
			for s = 1, strands do
				local angle = t * 9 + s * (math.pi * 2 / strands)
				local base = root.Position - Vector3.new(0, 3, 0)
				local p = VFX.neon(
					Vector3.new(0.6, 2.2, 0.6),
					CFrame.new(base + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)),
					color,
					0.1
				)
				VFX.tween(p, 0.9, {
					CFrame = CFrame.new(
						base + Vector3.new(math.cos(angle + 2.5) * r * 0.4, h, math.sin(angle + 2.5) * r * 0.4)
					),
					Size = Vector3.new(0.1, 3, 0.1),
					Transparency = 1,
				}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
				Debris:AddItem(p, 0.95)
			end
			task.wait(0.05)
		end
	end)
end

-- Pedras sobem lentamente pela pressão espiritual e explodem para fora em `burstAt`.
function SpectacleFx.LiftRocks(root: BasePart, count: number, duration: number)
	local ground = groundInfo(root.Position)
	local n = if lowQuality() then math.ceil(count / 3) else count
	local rocks = {}
	for _ = 1, n do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(4, 14)
		local size = rng:NextNumber(0.6, 2.2)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Slate
		p.Color = Color3.fromRGB(110, 105, 100)
		p.Size = Vector3.new(size, size * 0.8, size)
		local start = CFrame.new(ground + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist))
		p.CFrame = start
		p.Parent = workspace:FindFirstChild("ClientVFX") or workspace
		VFX.tween(p, duration, {
			CFrame = start
				* CFrame.new(0, rng:NextNumber(4, 12), 0)
				* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
		}, Enum.EasingStyle.Sine)
		table.insert(rocks, { part = p, angle = angle })
	end
	task.delay(duration, function()
		for _, rock in rocks do
			local p = rock.part
			local outward = Vector3.new(math.cos(rock.angle), 0.3, math.sin(rock.angle)) * rng:NextNumber(25, 45)
			VFX.tween(p, 0.6, { CFrame = p.CFrame + outward, Transparency = 1 }, Enum.EasingStyle.Quad)
			Debris:AddItem(p, 0.65)
		end
	end)
end

-- Flash branco no corpo atingido (Highlight reutilizado; limite do motor = 31 simultâneos)
local flashPool: { Highlight } = {}
local flashBusy: { [Highlight]: boolean } = {}
function SpectacleFx.HitFlash(model: Model?, color: Color3?)
	if not model or not model.Parent then
		return
	end
	local highlight: Highlight? = nil
	for _, h in flashPool do
		if not flashBusy[h] then
			highlight = h
			break
		end
	end
	if not highlight then
		if #flashPool >= 6 then
			return
		end
		local h = Instance.new("Highlight")
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.OutlineTransparency = 1
		h.Parent = workspace:FindFirstChild("ClientVFX") or workspace
		table.insert(flashPool, h)
		highlight = h
	end
	local h = highlight :: Highlight
	flashBusy[h] = true
	h.Adornee = model
	h.FillColor = color or Color3.new(1, 1, 1)
	h.FillTransparency = 0.05
	h.Enabled = true
	VFX.tween(h, 0.14, { FillTransparency = 1 })
	task.delay(0.15, function()
		h.Enabled = false
		h.Adornee = nil
		flashBusy[h] = nil
	end)
end

-- Domo de energia com material de shader (ForceField) que se expande e dissolve.
function SpectacleFx.Dome(position: Vector3, radius: number, color: Color3, duration: number?)
	local d = duration or 0.6
	local dome = VFX.neon(Vector3.one * 2, CFrame.new(position), color, 0, Enum.PartType.Ball)
	dome.Material = Enum.Material.ForceField
	VFX.tween(dome, d, { Size = Vector3.one * radius * 2 }, Enum.EasingStyle.Quint)
	task.delay(d * 0.55, function()
		VFX.tween(dome, d * 0.45, { Transparency = 1 })
	end)
	Debris:AddItem(dome, d + 0.05)
	if not lowQuality() then
		local core =
			VFX.neon(Vector3.one * radius * 0.4, CFrame.new(position), Color3.new(1, 1, 1), 0.2, Enum.PartType.Ball)
		VFX.tween(core, d * 0.5, { Size = Vector3.one * radius * 0.9, Transparency = 1 })
		Debris:AddItem(core, d * 0.5 + 0.05)
	end
end

-- ============================================================
-- Auras por elemento (extras sobre a aura de partículas do VFXController)
-- ============================================================
type AuraRig = {
	model: Model,
	key: string,
	element: string,
	parts: { BasePart },
	orbit: { BasePart },
	instances: { Instance },
	nextArc: number,
	t: number,
}

local rigs: { [Model]: AuraRig } = {}
local outlineCount = 0

local function auraKey(model: Model): string?
	if model:GetAttribute("Mask") then
		return "Mask"
	end
	local form = model:GetAttribute("Form")
	if form == "Tier1" or form == "Tier2" then
		return form :: string
	end
	return nil
end

local function clearRig(rig: AuraRig)
	for _, p in rig.parts do
		p:Destroy()
	end
	for _, p in rig.orbit do
		p:Destroy()
	end
	for _, i in rig.instances do
		i:Destroy()
	end
end

local function weldTo(base: BasePart, part: BasePart, offset: CFrame)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = base.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = base
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
end

local function buildRig(model: Model, key: string): AuraRig?
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local upper = model:FindFirstChild("UpperTorso") :: BasePart?
	local head = model:FindFirstChild("Head") :: BasePart?
	if not root then
		return nil
	end
	local element = if key == "Mask" then "Hollow" else VFX.ElementOf(model)
	local palette = Elements[element] or Elements.Reiatsu
	local rig: AuraRig =
		{ model = model, key = key, element = element, parts = {}, orbit = {}, instances = {}, nextArc = 0, t = 0 }
	local folder = workspace:FindFirstChild("ClientVFX") or workspace
	local low = lowQuality()

	-- Chamas negras/vermelhas (Hollow, sombra, sangue, máscara)
	if element == "Hollow" or element == "Shadow" or element == "Blood" then
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/fire_main.dds"
		e.Color = ColorSequence.new(palette.primary, Color3.new(0, 0, 0))
		e.LightEmission = 0.2
		e.Rate = if low then 10 else 35
		e.Lifetime = NumberRange.new(0.4, 0.8)
		e.Speed = NumberRange.new(2, 5)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0.2) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		e.Acceleration = Vector3.new(0, 12, 0)
		e.Parent = root
		table.insert(rig.instances, e)
	elseif element == "Fire" then
		local fire = Instance.new("Fire")
		fire.Color = palette.primary
		fire.SecondaryColor = palette.secondary
		fire.Size = if key == "Tier2" then 9 else 6
		fire.Heat = 12
		fire.Parent = root
		table.insert(rig.instances, fire)
	elseif element == "Ice" then
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
		e.Rate = if low then 6 else 20
		e.Lifetime = NumberRange.new(1, 1.8)
		e.Speed = NumberRange.new(0.5, 2)
		e.SpreadAngle = Vector2.new(180, 20)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		e.Acceleration = Vector3.new(0, -2, 0)
		e.Parent = root
		table.insert(rig.instances, e)
	end

	-- Anel lunar orbitando (Lua) ou anel de reiatsu (Tier 2 genérico)
	if not low and (element == "Moon" or key == "Tier2") then
		local count = if element == "Moon" then 10 else 6
		for i = 1, count do
			local p = VFX.neon(
				Vector3.new(0.35, 0.35, 1.6),
				root.CFrame,
				if i % 2 == 0 then palette.primary else palette.secondary:Lerp(palette.primary, 0.5),
				0.2
			)
			p.Parent = folder
			p:SetAttribute("Index", i)
			p:SetAttribute("Count", count)
			table.insert(rig.orbit, p)
		end
	end

	-- Auréola (Holy/Gold/Time) e asas de luz no Tier 2 (Quincy)
	if head and (element == "Holy" or element == "Gold" or element == "Time") then
		local halo = Instance.new("Part")
		halo.Shape = Enum.PartType.Cylinder
		halo.Material = Enum.Material.Neon
		halo.Color = palette.primary
		halo.Size = Vector3.new(0.15, 2.6, 2.6)
		halo.Transparency = 0.15
		halo.CastShadow = false
		weldTo(head, halo, CFrame.new(0, head.Size.Y / 2 + 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)))
		halo.Parent = folder
		table.insert(rig.parts, halo)
		if key == "Tier2" and upper then
			for side = -1, 1, 2 do
				for f = 1, 4 do
					local feather = Instance.new("Part")
					feather.Material = Enum.Material.Neon
					feather.Color = palette.primary:Lerp(Color3.new(1, 1, 1), f * 0.12)
					feather.Transparency = 0.25 + f * 0.08
					feather.Size = Vector3.new(0.2, 1.2 + f * 0.6, 5.5 - f * 0.6)
					feather.CastShadow = false
					local offset = CFrame.new(side * (0.9 + f * 0.5), 0.4 + f * 0.35, upper.Size.Z / 2 + 0.6)
						* CFrame.Angles(math.rad(15), math.rad(side * (55 + f * 8)), math.rad(side * (10 + f * 10)))
					weldTo(upper, feather, offset)
					feather.Parent = folder
					table.insert(rig.parts, feather)
				end
			end
		end
	end

	-- Contorno brilhante (forma final e máscara)
	if (key == "Tier2" or key == "Mask") and outlineCount < 8 then
		local outline = Instance.new("Highlight")
		outline.Adornee = model
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.FillColor = palette.primary
		outline.FillTransparency = 0.88
		outline.OutlineColor = palette.primary:Lerp(Color3.new(1, 1, 1), 0.3)
		outline.OutlineTransparency = 0.15
		outline.Parent = folder
		outlineCount += 1
		outline.Destroying:Connect(function()
			outlineCount -= 1
		end)
		table.insert(rig.instances, outline)
	end

	-- Pedras flutuando aos pés (pressão espiritual do Tier 2)
	if key == "Tier2" and not low then
		for i = 1, 6 do
			local rock = Instance.new("Part")
			rock.Anchored = true
			rock.CanCollide = false
			rock.CanQuery = false
			rock.CanTouch = false
			rock.Material = Enum.Material.Slate
			rock.Color = Color3.fromRGB(105, 100, 95)
			local s = rng:NextNumber(0.5, 1.3)
			rock.Size = Vector3.new(s, s * 0.8, s)
			rock:SetAttribute("Rock", i)
			rock.CFrame = root.CFrame
			rock.Parent = folder
			table.insert(rig.orbit, rock)
		end
	end
	return rig
end

function SpectacleFx.UpdateAura(model: Model)
	local key = auraKey(model)
	local current = rigs[model]
	if
		current
		and current.key == key
		and current.element == (if key == "Mask" then "Hollow" else VFX.ElementOf(model))
	then
		return
	end
	if current then
		clearRig(current)
		rigs[model] = nil
	end
	if key then
		local rig = buildRig(model, key)
		if rig then
			rigs[model] = rig
		end
	end
end

local function lightningArc(root: BasePart, color: Color3)
	local from = root.Position
		+ Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(-2.5, 2.5), rng:NextNumber(-1.5, 1.5))
	local last = from
	for _ = 1, 3 do
		local target = last
			+ Vector3.new(rng:NextNumber(-1.6, 1.6), rng:NextNumber(-1.6, 1.6), rng:NextNumber(-1.6, 1.6))
		local mid = (last + target) / 2
		local seg = VFX.neon(Vector3.new(0.12, 0.12, (target - last).Magnitude), CFrame.lookAt(mid, target), color, 0)
		Debris:AddItem(seg, 0.07)
		last = target
	end
end

local function stepAuras(dt: number)
	local camera = workspace.CurrentCamera
	local focus = camera and camera.CFrame.Position or Vector3.zero
	local now = os.clock()
	for model, rig in rigs do
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not model.Parent then
			clearRig(rig)
			rigs[model] = nil
			continue
		end
		if (root.Position - focus).Magnitude > 200 then
			continue
		end
		rig.t += dt
		local palette = Elements[rig.element] or Elements.Reiatsu
		for _, p in rig.orbit do
			local rockIndex = p:GetAttribute("Rock")
			if rockIndex then
				local a = rig.t * 0.8 + rockIndex * math.pi / 3
				local bob = math.sin(rig.t * 2 + rockIndex) * 0.6
				p.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(a) * 4.5, -2 + bob, math.sin(a) * 4.5))
					* CFrame.Angles(rig.t * 0.7 + rockIndex, rig.t * 0.5, 0)
			else
				local i = p:GetAttribute("Index") :: number
				local count = p:GetAttribute("Count") :: number
				local a = rig.t * 2.4 + i / count * math.pi * 2
				local tilt = CFrame.Angles(math.rad(18), 0, math.rad(10))
				local offset = tilt:VectorToWorldSpace(Vector3.new(math.cos(a) * 3.2, 0, math.sin(a) * 3.2))
				local pos = root.Position + Vector3.new(0, 0.5, 0) + offset
				p.CFrame = CFrame.lookAt(pos, pos + tilt:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a))))
			end
		end
		if rig.element == "Lightning" and now >= rig.nextArc then
			rig.nextArc = now + (if rig.key == "Tier2" then 0.08 else 0.16)
			lightningArc(root, if rng:NextNumber() < 0.5 then palette.primary else palette.secondary)
		end
	end
end

-- ============================================================
function SpectacleFx.Init()
	impactCC = Instance.new("ColorCorrectionEffect")
	impactCC.Name = "BSR_Impact"
	impactCC.Enabled = false
	impactCC.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Name = "BSR_Blur"
	blur.Size = 0
	blur.Parent = Lighting
end

function SpectacleFx.Start()
	local function watch(model: Instance)
		if not model:IsA("Model") then
			return
		end
		for _, attr in { "Form", "Mask", "Power" } do
			model:GetAttributeChangedSignal(attr):Connect(function()
				SpectacleFx.UpdateAura(model)
			end)
		end
		SpectacleFx.UpdateAura(model)
	end
	local function onPlayer(p: Player)
		p.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			watch(character)
		end)
		if p.Character then
			watch(p.Character)
		end
	end
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerAdded:Connect(onPlayer)
	refreshMapFilter()
	RunService.RenderStepped:Connect(function(dt)
		stepChunks(dt)
		stepAuras(dt)
	end)
	player.CharacterAdded:Connect(function()
		impactCC.Enabled = false
	end)
end

return SpectacleFx

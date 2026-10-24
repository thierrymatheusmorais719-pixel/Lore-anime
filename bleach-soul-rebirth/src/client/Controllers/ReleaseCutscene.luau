-- Cutscene da segunda liberação (Bankai / Segunda Etapa / Vollständig / Fullbring Completo),
-- montada como abertura de anime (faixas de cinema o tempo todo):
--   1. mundo real: câmera baixa com inclinação holandesa avança pelo ombro; pedras se soltam do
--      chão e flutuam, o mundo escurece, linhas de velocidade começam a pulsar
--   2. corte branco diagonal (wipe) → palco de vazio com estrelas, nebulosa e o kanji gigante ao
--      fundo; o personagem ajoelha, faixas de reiatsu giram, rachaduras acesas crescem no chão,
--      pedras sobem em volta
--   3. close extremo no rosto: os olhos acendem com um brilho de lente + quadro de impacto
--      (silhueta preta no branco / branca no preto)
--   4. pilar de energia rompe o chão e arremessa as pedras; dolly zoom olhando o topo
--   5. explosão na cor do elemento: três quadros de impacto, anel de choque, branco total
--      (o servidor aplica a forma aqui)
--   6. revelação em preto e branco: estouro de tinta, título com o kanji batendo na tela, rajadas,
--      golpe com faixas brancas; a cor volta no fim com a aura do elemento e um plano heroico
-- Só o jogador que libera vê a cena (local); os outros veem os efeitos normais no mundo.
-- O personagem do palco é um clone local (antes e depois da forma, para mostrar a roupa nova).
-- Tempos: `channel` (até a tela branca) e `reveal` vêm do servidor (Config/Factions).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AnimController = require(script.Parent.AnimController)
local CameraController = require(script.Parent.CameraController)
local ImpactFx = require(script.Parent.ImpactFx)
local SoundController = require(script.Parent.SoundController)
local VFX = require(script.Parent.VFXController)

local ReleaseCutscene = {}

local player = Players.LocalPlayer
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local STAGE = Vector3.new(0, 4000, 0) -- palco longe do mapa, escondido pela atmosfera densa
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- Linha do tempo de referência (channel = 7,2 s): escalada pelo channel real
local REFERENCE = 7.2
local BEAT = {
	wipe = 1.15, -- corte branco começa
	swap = 1.35, -- troca para o palco por baixo do branco
	eyes = 3.0, -- close nos olhos
	flare = 3.2, -- olhos acendem (quadro de impacto)
	pillar = 3.75, -- pilar sobe
	burst = 5.6, -- explosão
	whiteIn = 6.35, -- branco cresce até `channel`
}
-- Revelação (segundos depois do branco, escalados por `reveal` / 3,4)
local REVEAL_REFERENCE = 3.4
local AFTER = {
	open = 0.32, -- o branco abre: tinta, título
	slash = 1.45, -- golpe final
	color = 2.15, -- a cor volta, plano heroico
}

local active: any = nil

local function tween(
	instance: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local function seq(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function newPart(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- ======================================================================= clone do personagem
local function cloneCharacter(model: Model, folder: Instance, at: CFrame): Model?
	local wasArchivable = model.Archivable
	model.Archivable = true
	local ok, copy = pcall(function()
		return model:Clone()
	end)
	model.Archivable = wasArchivable
	if not ok or not copy then
		return nil
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = false
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	local root = copy:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		copy:Destroy()
		return nil
	end
	root.Anchored = true
	copy.Name = "CutsceneActor"
	copy:PivotTo(at)
	copy.Parent = folder
	return copy
end

-- ======================================================================= faixas (trails em trajetórias)
type Ribbon = { part: Part, trail: Trail, path: (number) -> Vector3 }

local function ribbon(
	folder: Instance,
	width: number,
	color: ColorSequence,
	lifetime: number,
	path: (number) -> Vector3
): Ribbon
	local p = newPart(folder, Vector3.one * 0.1, CFrame.new(path(0)), WHITE)
	p.Transparency = 1
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = lifetime
	trail.MinLength = 0
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Brightness = 3
	trail.Color = color
	trail.Transparency = seq({ { 0, 0 }, { 0.5, 0.35 }, { 1, 1 } })
	trail.WidthScale = seq({ { 0, 1 }, { 1, 0.1 } })
	trail.Parent = p
	return { part = p, trail = trail, path = path }
end

-- ======================================================================= palco
local function buildStage(s, palette)
	local folder = s.folder
	local origin = CFrame.new(STAGE)
	-- Chão escuro e levemente reflexivo (o anel de choque e as luzes aparecem nele)
	local floorY = STAGE.Y - s.hip
	s.floor = newPart(
		folder,
		Vector3.new(1, 500, 500),
		CFrame.new(STAGE.X, floorY - 0.5, STAGE.Z) * CFrame.Angles(0, 0, math.rad(90)),
		palette.dark:Lerp(BLACK, 0.6),
		Enum.Material.Glass
	)
	s.floor.Shape = Enum.PartType.Cylinder
	s.floor.Reflectance = 0.18

	-- Estrelas: pontos minúsculos espalhados num volume grande
	local starBox = newPart(folder, Vector3.new(260, 140, 260), origin * CFrame.new(0, 50, 0), WHITE)
	starBox.Transparency = 1
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = SPARK
	stars.Shape = Enum.ParticleEmitterShape.Box
	stars.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	stars.LightEmission = 1
	stars.Brightness = 2
	stars.Color = ColorSequence.new(WHITE, palette.secondary)
	stars.Size = seq({ { 0, 0 }, { 0.2, 0.35 }, { 0.8, 0.25 }, { 1, 0 } })
	stars.Lifetime = NumberRange.new(3, 5)
	stars.Speed = NumberRange.new(0.2, 1)
	stars.Rate = 70
	stars.Parent = starBox
	stars:Emit(140)
	s.stars = stars

	-- Nebulosa: fumaça grande e escura ao fundo, na cor do elemento
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2
		local holder = newPart(
			folder,
			Vector3.one,
			origin * CFrame.new(math.cos(angle) * 110, 20 + (i % 3) * 18, math.sin(angle) * 110),
			WHITE
		)
		holder.Transparency = 1
		local fog = Instance.new("ParticleEmitter")
		fog.Texture = SMOKE
		fog.LightEmission = 0.35
		fog.Brightness = 1
		fog.Color = ColorSequence.new(palette.primary:Lerp(BLACK, 0.55), palette.dark)
		fog.Size = seq({ { 0, 45 }, { 1, 75 } })
		fog.Transparency = seq({ { 0, 1 }, { 0.3, 0.55 }, { 0.7, 0.6 }, { 1, 1 } })
		fog.Lifetime = NumberRange.new(7, 10)
		fog.Speed = NumberRange.new(1, 3)
		fog.Rotation = NumberRange.new(0, 360)
		fog.RotSpeed = NumberRange.new(-6, 6)
		fog.Rate = 0.8
		fog.Parent = holder
		fog:Emit(4)
	end

	-- Luz principal: azulada de cima, reforça a silhueta
	local key = Instance.new("PointLight")
	key.Color = palette.secondary
	key.Range = 30
	key.Brightness = 2
	key.Shadows = false
	local keyHolder = newPart(folder, Vector3.one, origin * CFrame.new(-6, 10, -6), WHITE)
	keyHolder.Transparency = 1
	key.Parent = keyHolder
	s.keyLight = key
end

-- Faixas de reiatsu girando (planos inclinados, como no vídeo: diagonais que cruzam a tela)
local function startSwirl(s, palette)
	local color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.35, palette.secondary),
		ColorSequenceKeypoint.new(1, palette.primary),
	})
	local rng = Random.new()
	local count = if VFX.Quality() == "Low" then 10 else 22
	for i = 1, count do
		local radius = rng:NextNumber(5, 26)
		local speed = rng:NextNumber(2.2, 4.5) * (if i % 2 == 0 then 1 else -1) * (12 / radius)
		local tiltX = math.rad(rng:NextNumber(-35, 35))
		local tiltZ = math.rad(rng:NextNumber(-30, 30))
		local tilt = CFrame.Angles(tiltX, 0, tiltZ)
		local height = rng:NextNumber(-1, 9)
		local phase = rng:NextNumber(0, math.pi * 2)
		local wobble = rng:NextNumber(1, 3)
		local center = STAGE + Vector3.new(0, height, 0)
		local r = ribbon(s.folder, rng:NextNumber(0.25, 1.4), color, rng:NextNumber(0.25, 0.45), function(t)
			local a = phase + t * speed
			local rr = radius + math.sin(t * 1.7 + phase) * wobble
			return center
				+ tilt:VectorToWorldSpace(Vector3.new(math.cos(a) * rr, math.sin(a * 2) * 0.8, math.sin(a) * rr))
		end)
		table.insert(s.ribbons, r)
	end
end

-- Rajadas horizontais da revelação (vento rasante que atravessa o quadro)
local function startWind(s)
	local rng = Random.new()
	local color = ColorSequence.new(WHITE, Color3.fromRGB(200, 200, 200))
	for i = 1, 12 do
		local y = STAGE.Y - s.hip + rng:NextNumber(0.3, 7)
		local z = STAGE.Z + rng:NextNumber(-14, 14)
		local speed = rng:NextNumber(70, 120) * (if i % 3 == 0 then -1 else 1)
		local offset = rng:NextNumber(0, 60)
		local r = ribbon(s.folder, rng:NextNumber(0.3, 1.6), color, 0.5, function(t)
			local x = ((offset + t * speed) % 120) - 60
			return Vector3.new(STAGE.X + x, y + math.sin(t * 3 + offset) * 0.4, z)
		end)
		r.trail.Brightness = 2
		table.insert(s.ribbons, r)
	end
end

local function clearRibbons(s)
	for _, r in s.ribbons do
		r.part:Destroy()
	end
	table.clear(s.ribbons)
end

-- Pilar de energia: núcleo branco + casca na cor do elemento + faíscas subindo
local function raisePillar(s, palette)
	local folder = s.folder
	local base = STAGE - Vector3.new(0, s.hip, 0)
	local height = 220
	local core = newPart(
		folder,
		Vector3.new(0.1, 1.1, 1.1),
		CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)),
		palette.core,
		Enum.Material.Neon
	)
	core.Shape = Enum.PartType.Cylinder
	local shell = newPart(
		folder,
		Vector3.new(0.1, 4, 4),
		CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)),
		palette.primary,
		Enum.Material.ForceField
	)
	shell.Shape = Enum.PartType.Cylinder
	for _, p in { core, shell } do
		tween(p, 0.4, {
			Size = Vector3.new(height, p.Size.Y, p.Size.Z),
			CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		}, Enum.EasingStyle.Quart)
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK
	sparks.Shape = Enum.ParticleEmitterShape.Cylinder
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.Rotation = NumberRange.new(-90)
	sparks.Squash = seq({ { 0, -2.5 }, { 1, -1 } })
	sparks.LightEmission = 1
	sparks.Brightness = 4
	sparks.Color = ColorSequence.new(WHITE, palette.primary)
	sparks.Size = seq({ { 0, 0.5 }, { 1, 0 } })
	sparks.Lifetime = NumberRange.new(0.25, 0.5)
	sparks.Speed = NumberRange.new(30, 70)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Rate = if VFX.Quality() == "Low" then 60 else 220
	sparks.Parent = shell
	local light = Instance.new("PointLight")
	light.Color = palette.primary
	light.Range = 40
	light.Brightness = 5
	light.Shadows = false
	light.Parent = core
	-- tremulação do núcleo
	s.pillar = { core = core, shell = shell, sparks = sparks }
	ImpactFx.Hit(base + Vector3.new(0, 1, 0), Vector3.yAxis, s.element, 3)
	SoundController.Play("Boom", core, 1)
end

local function burst(s, palette)
	local folder = s.folder
	local center = STAGE
	ImpactFx.Hit(center, nil, s.element, 3)
	SoundController.Play("Ultimate", s.anchor, 1)
	-- Fumaça de energia que engole o personagem (aditiva, cresce sem parar até o branco)
	local holder = newPart(folder, Vector3.new(6, 6, 6), CFrame.new(center), WHITE)
	holder.Transparency = 1
	local aura = Instance.new("ParticleEmitter")
	aura.Texture = SMOKE
	aura.Shape = Enum.ParticleEmitterShape.Sphere
	aura.LightEmission = 1
	aura.Brightness = 3
	aura.Color = ColorSequence.new(WHITE, palette.primary)
	aura.Size = seq({ { 0, 4 }, { 1, 22 } })
	aura.Transparency = seq({ { 0, 0.3 }, { 1, 1 } })
	aura.Lifetime = NumberRange.new(0.6, 1.1)
	aura.Speed = NumberRange.new(20, 45)
	aura.Drag = 3
	aura.Rotation = NumberRange.new(0, 360)
	aura.RotSpeed = NumberRange.new(-60, 60)
	aura.Rate = if VFX.Quality() == "Low" then 25 else 70
	aura.Parent = holder
	aura:Emit(30)
	s.aura = aura
	-- Anel no chão que se espalha
	local ring = newPart(
		folder,
		Vector3.new(0.2, 2, 2),
		CFrame.new(center - Vector3.new(0, s.hip - 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		palette.core,
		Enum.Material.Neon
	)
	ring.Shape = Enum.PartType.Cylinder
	tween(ring, 0.7, { Size = Vector3.new(0.05, 140, 140), Transparency = 1 }, Enum.EasingStyle.Quint)
	local light = Instance.new("PointLight")
	light.Color = palette.core
	light.Range = 60
	light.Brightness = 0
	light.Shadows = false
	light.Parent = holder
	tween(light, 0.9, { Brightness = 10 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

-- Revelação P&B: estouro de tinta preta com anel branco, linhas de impacto
local function inkBurst(s)
	local folder = s.folder
	local holder = newPart(folder, Vector3.new(4, 4, 4), CFrame.new(STAGE), WHITE)
	holder.Transparency = 1
	local ink = Instance.new("ParticleEmitter")
	ink.Texture = SMOKE
	ink.Shape = Enum.ParticleEmitterShape.Sphere
	ink.LightEmission = 0
	ink.Brightness = 0
	ink.Color = ColorSequence.new(BLACK)
	ink.Size = seq({ { 0, 6 }, { 1, 26 } })
	ink.Transparency = seq({ { 0, 0.05 }, { 0.6, 0.3 }, { 1, 1 } })
	ink.Lifetime = NumberRange.new(0.5, 0.9)
	ink.Speed = NumberRange.new(40, 70)
	ink.Drag = 6
	ink.Rotation = NumberRange.new(0, 360)
	ink.ZOffset = -1
	ink.Parent = holder
	ink:Emit(26)
	local ring = newPart(
		folder,
		Vector3.new(0.2, 3, 3),
		CFrame.new(STAGE - Vector3.new(0, s.hip - 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		WHITE,
		Enum.Material.Neon
	)
	ring.Shape = Enum.PartType.Cylinder
	tween(ring, 0.5, { Size = Vector3.new(0.05, 90, 90), Transparency = 1 }, Enum.EasingStyle.Quint)
	ImpactFx.Hit(STAGE + Vector3.new(0, 1, 0), nil, "Holy", 3)
end

-- ======================================================================= tela (wipes e branco)
local function buildScreen(s, palette)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ReleaseCutscene"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")
	s.gui = gui
	local white = Instance.new("Frame")
	white.Size = UDim2.fromScale(1, 1)
	white.BackgroundColor3 = WHITE
	white.BackgroundTransparency = 1
	white.BorderSizePixel = 0
	white.ZIndex = 5
	white.Parent = gui
	s.white = white
	s.edgeColor = palette.secondary
end

-- Corte diagonal: uma lâmina branca com borda na cor do elemento atravessa a tela e cobre tudo
local function diagonalWipe(s, duration: number)
	local band = Instance.new("Frame")
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Size = UDim2.fromScale(0.25, 3)
	band.Position = UDim2.fromScale(-0.4, 0.5)
	band.Rotation = 28
	band.BackgroundColor3 = WHITE
	band.BorderSizePixel = 0
	band.ZIndex = 4
	band.Parent = s.gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = s.edgeColor
	stroke.Thickness = 10
	stroke.Parent = band
	tween(
		band,
		duration,
		{ Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(2.6, 3) },
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.In
	)
	task.delay(duration + 0.12, function()
		tween(band, 0.18, { BackgroundTransparency = 1 })
		tween(stroke, 0.18, { Transparency = 1 })
		task.delay(0.2, function()
			band:Destroy()
		end)
	end)
end

-- Faixas brancas horizontais (o golpe final corta a tela)
local function horizontalBands(s)
	for i, y in { 0.38, 0.5, 0.62 } do
		local band = Instance.new("Frame")
		band.AnchorPoint = Vector2.new(0, 0.5)
		band.Position = UDim2.fromScale(-1, y)
		band.Size = UDim2.new(1, 0, 0, if i == 2 then 70 else 26)
		band.BackgroundColor3 = WHITE
		band.BorderSizePixel = 0
		band.ZIndex = 4
		band.Parent = s.gui
		task.delay((i - 1) * 0.04, function()
			tween(band, 0.18, { Position = UDim2.fromScale(0, y) }, Enum.EasingStyle.Quart)
			task.delay(0.22, function()
				tween(band, 0.25, { Position = UDim2.fromScale(1, y), BackgroundTransparency = 1 })
				task.delay(0.3, function()
					band:Destroy()
				end)
			end)
		end)
	end
end

-- ======================================================================= iluminação do palco
local LIGHT_PROPS =
	{ "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" }
local ATMO_PROPS = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" }

local function saveLighting(s)
	local saved = { lighting = {}, atmosphere = {} }
	for _, k in LIGHT_PROPS do
		saved.lighting[k] = (Lighting :: any)[k]
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		for _, k in ATMO_PROPS do
			saved.atmosphere[k] = (atmosphere :: any)[k]
		end
	end
	s.saved = saved
	s.atmosphere = atmosphere
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BSR_Cutscene"
	cc.Parent = Lighting
	s.cc = cc
end

local function voidLighting(s, palette)
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.6
	Lighting.Ambient = palette.primary:Lerp(BLACK, 0.7)
	Lighting.OutdoorAmbient = palette.primary:Lerp(BLACK, 0.6)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.6
	local atmosphere = s.atmosphere
	if atmosphere then
		-- atmosfera densa: o céu vira um degradê azul-profundo e o mapa lá embaixo some
		atmosphere.Density = 0.62
		atmosphere.Offset = 0.15
		atmosphere.Color = palette.primary:Lerp(Color3.fromRGB(10, 20, 60), 0.75)
		atmosphere.Decay = palette.dark:Lerp(BLACK, 0.5)
		atmosphere.Glare = 0
		atmosphere.Haze = 0.4
	end
	s.cc.Saturation = 0.15
	s.cc.Contrast = 0.12
	s.cc.Brightness = 0
	s.cc.TintColor = WHITE
end

local function monochromeLighting(s)
	Lighting.Brightness = 0.4
	Lighting.Ambient = Color3.fromRGB(70, 70, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(60, 60, 60)
	local atmosphere = s.atmosphere
	if atmosphere then
		atmosphere.Color = Color3.fromRGB(8, 8, 8)
		atmosphere.Decay = BLACK
		atmosphere.Density = 0.7
	end
	s.cc.Saturation = -1
	s.cc.Contrast = 0.55
	s.cc.Brightness = -0.04
	if s.floor then
		s.floor.Color = Color3.fromRGB(6, 6, 6)
	end
	if s.keyLight then
		s.keyLight.Color = WHITE
		s.keyLight.Brightness = 3
	end
end

local function restoreLighting(s)
	for k, v in s.saved.lighting do
		(Lighting :: any)[k] = v
	end
	if s.atmosphere then
		for k, v in s.saved.atmosphere do
			(s.atmosphere :: any)[k] = v
		end
	end
	if s.cc then
		s.cc:Destroy()
	end
end

-- ======================================================================= linhas de velocidade
-- Traços finos radiais que piscam (mangá): intensidade 0..1 em s.lineLevel
local function buildSpeedLines(s)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 3
	holder.Parent = s.gui
	s.lines = {}
	local count = if VFX.Quality() == "Low" then 24 else 56
	for i = 1, count do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = WHITE
		line.BorderSizePixel = 0
		line.BackgroundTransparency = 1
		line.ZIndex = 3
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = seq({ { 0, 1 }, { 0.6, 0.2 }, { 1, 0 } })
		gradient.Parent = line
		line.Parent = holder
		table.insert(s.lines, { frame = line, angle = (i / count) * math.pi * 2 })
	end
	s.lineLevel = 0
	s.lineColor = WHITE
end

local function updateSpeedLines(s, frameIndex: number)
	if not s.lines then
		return
	end
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local radius = size.Magnitude * 0.5
	local level = s.lineLevel or 0
	-- sorteia de novo a cada 2 quadros: o tremido das linhas desenhadas à mão
	if frameIndex % 2 ~= 0 then
		return
	end
	for _, l in s.lines do
		local f = l.frame
		if level <= 0.01 or s.rng:NextNumber() > 0.35 + level * 0.6 then
			f.BackgroundTransparency = 1
		else
			local angle = l.angle + s.rng:NextNumber(-0.05, 0.05)
			local length = radius * s.rng:NextNumber(0.35, 0.75)
			local inner = radius * s.rng:NextNumber(0.42, 0.7) * (1.15 - level * 0.35)
			local r = inner + length / 2
			f.Size = UDim2.fromOffset(length, s.rng:NextNumber(1.5, 2 + level * 5))
			f.Position = UDim2.new(0.5, math.cos(angle) * r, 0.5, math.sin(angle) * r)
			f.Rotation = math.deg(angle)
			f.BackgroundColor3 = s.lineColor
			f.BackgroundTransparency = 1 - level * s.rng:NextNumber(0.5, 0.95)
		end
	end
end

-- ======================================================================= quadro de impacto
-- Silhueta chapada: painel neon enorme atrás do personagem (de frente para a câmera) + Highlight
-- no personagem com a cor oposta. Dois ou três quadros alternando = o "impact frame" do anime.
local function impactFrames(s, pattern: { boolean }, each: number)
	local camera = workspace.CurrentCamera
	if not camera or not s.actor then
		return
	end
	local panel = newPart(s.folder, Vector3.new(900, 900, 1), CFrame.identity, WHITE, Enum.Material.Neon)
	panel.Transparency = 1
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = s.actor
	highlight.Parent = s.folder
	local hidden = {}
	for _, item in { s.floor } do
		if item then
			table.insert(hidden, { item, item.Transparency })
			item.Transparency = 1
		end
	end
	for i, inverted in pattern do
		task.delay((i - 1) * each, function()
			if s.done or not panel.Parent then
				return
			end
			local cam = camera.CFrame
			local distance = (STAGE - cam.Position).Magnitude + 40
			panel.CFrame = CFrame.lookAt(cam.Position + cam.LookVector * distance, cam.Position)
			panel.Color = if inverted then BLACK else WHITE
			panel.Transparency = 0
			highlight.FillColor = if inverted then WHITE else BLACK
			highlight.FillTransparency = 0
		end)
	end
	task.delay(#pattern * each, function()
		panel:Destroy()
		highlight:Destroy()
		for _, h in hidden do
			if h[1].Parent then
				h[1].Transparency = h[2]
			end
		end
	end)
end

-- ======================================================================= pedras, rachaduras
type Rock = { part: Part, base: Vector3, rise: number, spin: Vector3, phase: number, velocity: Vector3? }

local function spawnRocks(s, list: { Rock }, center: Vector3, floorY: number, count: number, spread: number)
	local rng = s.rng
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(3, spread)
		local size = rng:NextNumber(0.35, 1.5)
		local p = newPart(
			s.folder,
			Vector3.new(size, size * rng:NextNumber(0.5, 0.9), size * rng:NextNumber(0.7, 1.1)),
			CFrame.new(
				center.X + math.cos(angle) * distance,
				floorY + size * 0.3,
				center.Z + math.sin(angle) * distance
			) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
			Color3.fromRGB(58, 54, 52):Lerp(BLACK, rng:NextNumber(0, 0.5)),
			Enum.Material.Slate
		)
		p.CastShadow = true
		table.insert(list, {
			part = p,
			base = p.Position,
			rise = rng:NextNumber(0.6, 2.2),
			spin = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)),
			phase = rng:NextNumber(0, 6),
		})
	end
end

local function updateRocks(list: { Rock }, t: number, dt: number, since: number)
	for _, r in list do
		local p = r.part
		if not p.Parent then
			continue
		end
		local spin = CFrame.Angles(r.spin.X * dt, r.spin.Y * dt, r.spin.Z * dt)
		if r.velocity then
			-- arremessada pelo pilar: voo balístico girando rápido
			r.velocity -= Vector3.new(0, 30 * dt, 0)
			p.CFrame = (p.CFrame + r.velocity * dt) * CFrame.Angles(r.spin.X * dt * 8, r.spin.Y * dt * 8, 0)
		else
			-- sobe devagar e flutua (anti-gravidade da pressão espiritual)
			local lift = math.min(1, (t - since) / 2.5)
			local y = r.base.Y + lift * lift * r.rise * 3 + math.sin(t * 1.6 + r.phase) * 0.15 * lift
			p.CFrame = CFrame.new(r.base.X, y, r.base.Z) * p.CFrame.Rotation * spin
		end
	end
end

local function blastRocks(s, list: { Rock }, center: Vector3)
	for _, r in list do
		local out = r.part.Position - center
		out = Vector3.new(out.X, 0, out.Z)
		local dir = if out.Magnitude > 0.01 then out.Unit else Vector3.xAxis
		r.velocity = dir * s.rng:NextNumber(25, 60) + Vector3.new(0, s.rng:NextNumber(20, 45), 0)
	end
end

-- Rachaduras acesas no chão do palco: linhas quebradas que saem dos pés e crescem
local function growCracks(s, palette, duration: number)
	local rng = s.rng
	local floorY = STAGE.Y - s.hip + 0.03
	local count = if VFX.Quality() == "Low" then 7 else 14
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local point = Vector3.new(STAGE.X, floorY, STAGE.Z) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 0.8
		local segments = rng:NextInteger(3, 5)
		for j = 1, segments do
			angle += rng:NextNumber(-0.45, 0.45)
			local length = rng:NextNumber(1.6, 4) * (1 - j / (segments + 2))
			local nextPoint = point + Vector3.new(math.cos(angle), 0, math.sin(angle)) * length
			local mid = (point + nextPoint) / 2
			local crack = newPart(
				s.folder,
				Vector3.new(0.12 * (1.2 - j * 0.15), 0.05, 0.01),
				CFrame.lookAt(mid, nextPoint),
				palette.core,
				Enum.Material.Neon
			)
			crack.Transparency = 1
			local delay = duration * ((j - 1) / segments) * 0.8
			task.delay(delay, function()
				if crack.Parent then
					tween(
						crack,
						duration / segments,
						{ Size = Vector3.new(crack.Size.X, 0.05, length), Transparency = 0 }
					)
				end
			end)
			point = nextPoint
		end
	end
	-- brilho do chão rachado
	local glow = Instance.new("PointLight")
	glow.Color = palette.primary
	glow.Range = 18
	glow.Brightness = 0
	glow.Shadows = false
	local holder = newPart(s.folder, Vector3.one, CFrame.new(STAGE.X, floorY + 0.5, STAGE.Z), WHITE)
	holder.Transparency = 1
	glow.Parent = holder
	tween(glow, duration, { Brightness = 4 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

-- Kanji gigante e translúcido no fundo do vazio
local function backdropKanji(s, palette, text: string)
	local holder = newPart(s.folder, Vector3.one, CFrame.new(STAGE + Vector3.new(0, 14, 55)), WHITE)
	holder.Transparency = 1
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(70, 40)
	board.LightInfluence = 0
	board.Brightness = 2
	board.MaxDistance = 1000
	board.Adornee = holder
	board.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = palette.secondary
	label.TextTransparency = 1
	label.Parent = board
	tween(label, 1.2, { TextTransparency = 0.72 })
	s.backdrop = label
end

-- Olhos acendem: dois pontos neon + brilho de lente horizontal
local function eyeFlare(s, palette)
	local actor = s.actor
	local head = actor and actor:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 0.12
		eye.Material = Enum.Material.Neon
		eye.Color = palette.core
		eye.CanCollide = false
		eye.CanQuery = false
		eye.CanTouch = false
		eye.Massless = true
		eye.CastShadow = false
		eye.CFrame = head.CFrame * CFrame.new(side * 0.17, 0.12, -0.56)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = eye
		weld.Parent = eye
		eye.Parent = s.folder
	end
	local board = Instance.new("BillboardGui")
	board.Adornee = head
	board.StudsOffsetWorldSpace = head.CFrame:VectorToWorldSpace(Vector3.new(0, 0.12, -0.6))
	board.Size = UDim2.fromScale(0.2, 0.25)
	board.LightInfluence = 0
	board.Brightness = 4
	board.AlwaysOnTop = true
	board.Parent = s.folder
	local streak = Instance.new("Frame")
	streak.AnchorPoint = Vector2.new(0.5, 0.5)
	streak.Position = UDim2.fromScale(0.5, 0.5)
	streak.Size = UDim2.fromScale(1, 0.12)
	streak.BackgroundColor3 = palette.core
	streak.BorderSizePixel = 0
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = seq({ { 0, 1 }, { 0.35, 0.3 }, { 0.5, 0 }, { 0.65, 0.3 }, { 1, 1 } })
	gradient.Parent = streak
	streak.Parent = board
	tween(board, 0.18, { Size = UDim2.fromScale(9, 0.5) }, Enum.EasingStyle.Quart)
	task.delay(0.35, function()
		if board.Parent then
			tween(board, 0.4, { Size = UDim2.fromScale(14, 0.2) })
			tween(streak, 0.4, { BackgroundTransparency = 1 })
		end
	end)
	local light = Instance.new("PointLight")
	light.Color = palette.primary
	light.Range = 8
	light.Brightness = 6
	light.Shadows = false
	light.Parent = head
	s.eyeLight = light
end

-- ======================================================================= título
local function titleCard(s, palette, d)
	local gui = s.gui
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 6
	frame.Parent = gui
	-- pincelada na cor do elemento atrás do kanji
	local brush = Instance.new("Frame")
	brush.AnchorPoint = Vector2.new(0.5, 0.5)
	brush.Position = UDim2.fromScale(0.62, 0.5)
	brush.Size = UDim2.fromScale(0, 0.2)
	brush.Rotation = -6
	brush.BackgroundColor3 = palette.primary
	brush.BorderSizePixel = 0
	brush.ZIndex = 6
	local brushGradient = Instance.new("UIGradient")
	brushGradient.Transparency = seq({ { 0, 1 }, { 0.08, 0.15 }, { 0.85, 0.05 }, { 1, 1 } })
	brushGradient.Parent = brush
	brush.Parent = frame
	tween(brush, 0.16, { Size = UDim2.fromScale(0.75, 0.2) }, Enum.EasingStyle.Quart)

	local kanji = Instance.new("TextLabel")
	kanji.AnchorPoint = Vector2.new(0.5, 0.5)
	kanji.Position = UDim2.fromScale(0.62, 0.47)
	kanji.Size = UDim2.fromScale(0.5, 0.36)
	kanji.BackgroundTransparency = 1
	kanji.Text = d.formKanji or "解"
	kanji.TextScaled = true
	kanji.Font = Enum.Font.GothamBlack
	kanji.TextColor3 = WHITE
	kanji.ZIndex = 8
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = BLACK
	stroke.Parent = kanji
	local scale = Instance.new("UIScale")
	scale.Scale = 3
	scale.Parent = kanji
	kanji.Parent = frame
	tween(scale, 0.13, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local name = Instance.new("TextLabel")
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.fromScale(0.62, 0.64)
	name.Size = UDim2.fromScale(0.5, 0.06)
	name.BackgroundTransparency = 1
	-- letras espaçadas (por caractere UTF-8: "Vollständig", "Resurrección")
	local spaced = {}
	for _, code in utf8.codes(string.upper(d.formName or d.releaseName or "")) do
		table.insert(spaced, utf8.char(code))
	end
	name.Text = table.concat(spaced, " ")
	name.TextScaled = true
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = WHITE
	name.TextTransparency = 1
	name.ZIndex = 8
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 2
	nameStroke.Transparency = 1
	nameStroke.Parent = name
	name.Parent = frame
	task.delay(0.15, function()
		tween(name, 0.3, { TextTransparency = 0, Position = UDim2.fromScale(0.6, 0.64) })
		tween(nameStroke, 0.3, { Transparency = 0 })
	end)
	if d.command then
		local command = Instance.new("TextLabel")
		command.AnchorPoint = Vector2.new(0.5, 1)
		command.Position = UDim2.fromScale(0.62, 0.3)
		command.Size = UDim2.fromScale(0.55, 0.05)
		command.BackgroundTransparency = 1
		command.Text = "「" .. d.command .. "」"
		command.TextScaled = true
		command.Font = Enum.Font.GothamMedium
		command.TextColor3 = WHITE
		command.TextTransparency = 1
		command.ZIndex = 8
		command.Parent = frame
		tween(command, 0.4, { TextTransparency = 0.1 })
	end
	-- tremida do impacto
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.35 and frame.Parent do
			local a = 1 - (os.clock() - t0) / 0.35
			frame.Position = UDim2.new(0.5, s.rng:NextNumber(-14, 14) * a, 0.5, s.rng:NextNumber(-10, 10) * a)
			task.wait()
		end
		frame.Position = UDim2.fromScale(0.5, 0.5)
	end)
	s.title = frame
end

local function hideTitle(s)
	local frame = s.title
	if not frame then
		return
	end
	s.title = nil
	for _, d in frame:GetDescendants() do
		if d:IsA("TextLabel") then
			tween(d, 0.35, { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, 0.35, { Transparency = 1 })
		elseif d:IsA("Frame") then
			tween(d, 0.35, { BackgroundTransparency = 1 })
		end
	end
	tween(frame, 0.35, { Position = UDim2.fromScale(0.56, 0.5) })
	task.delay(0.4, function()
		frame:Destroy()
	end)
end

-- A cor volta: forma nova em cores, aura do elemento e luz de contorno
local function colorBleed(s, palette)
	tween(s.cc, 0.6, { Saturation = 0.2, Contrast = 0.18, Brightness = 0 })
	tween(Lighting, 0.6, {
		Ambient = palette.primary:Lerp(BLACK, 0.55),
		OutdoorAmbient = palette.primary:Lerp(BLACK, 0.5),
		Brightness = 0.8,
	})
	if s.atmosphere then
		tween(s.atmosphere, 0.6, { Color = palette.primary:Lerp(BLACK, 0.7), Decay = palette.dark:Lerp(BLACK, 0.4) })
	end
	if s.floor then
		s.floor.Color = palette.dark:Lerp(BLACK, 0.6)
	end
	local root = s.actor and s.actor:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local aura = Instance.new("ParticleEmitter")
	aura.Texture = SMOKE
	aura.LightEmission = 1
	aura.Brightness = 2
	aura.Color = ColorSequence.new(palette.core, palette.primary)
	aura.Size = seq({ { 0, 2.5 }, { 1, 5 } })
	aura.Transparency = seq({ { 0, 1 }, { 0.25, 0.6 }, { 1, 1 } })
	aura.Lifetime = NumberRange.new(0.6, 1)
	aura.Speed = NumberRange.new(4, 9)
	aura.Acceleration = Vector3.new(0, 10, 0)
	aura.SpreadAngle = Vector2.new(25, 25)
	aura.EmissionDirection = Enum.NormalId.Top
	aura.Rotation = NumberRange.new(0, 360)
	aura.RotSpeed = NumberRange.new(-40, 40)
	aura.Rate = if VFX.Quality() == "Low" then 12 else 35
	aura.Parent = root
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK
	sparks.LightEmission = 1
	sparks.Brightness = 4
	sparks.Color = ColorSequence.new(WHITE, palette.primary)
	sparks.Size = seq({ { 0, 0.25 }, { 1, 0 } })
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Speed = NumberRange.new(6, 14)
	sparks.Acceleration = Vector3.new(0, 14, 0)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Rate = if VFX.Quality() == "Low" then 15 else 45
	sparks.Parent = root
	local rim = Instance.new("PointLight")
	rim.Color = palette.primary
	rim.Range = 14
	rim.Brightness = 5
	rim.Shadows = false
	local holder = newPart(s.folder, Vector3.one, CFrame.new(STAGE + Vector3.new(0, 3, 4)), WHITE)
	holder.Transparency = 1
	rim.Parent = holder
	ImpactFx.Hit(STAGE, Vector3.yAxis, s.element, 2)
end

-- ======================================================================= câmera
local function actorPoint(s, part: string, fallback: Vector3): Vector3
	local p = s.actor and s.actor:FindFirstChild(part) :: BasePart?
	return if p then p.Position else fallback
end

-- Cada plano: função do tempo (s) → (CFrame, FOV). Tremor de mão leve sempre; tremor forte nos
-- impactos (s.shakeUntil).
local function cameraFrame(s, t: number): (CFrame, number)
	local C = s.channel
	local k = C / REFERENCE
	local function beat(name: string): number
		return BEAT[name] * k
	end
	local shake = Vector3.new(math.noise(t * 1.3, 11) * 0.06, math.noise(t * 1.1, 12) * 0.06, 0)
	if s.shakeUntil and t < s.shakeUntil then
		local amount = math.min(1, (s.shakeUntil - t) * 1.8) * 0.45
		shake += Vector3.new(
			math.noise(t * 28, 1) * amount,
			math.noise(t * 28, 2) * amount,
			math.noise(t * 28, 3) * amount
		)
	end
	-- 1) mundo real: câmera baixa e inclinada avança pelo ombro até o rosto
	if t < beat("swap") then
		local root = s.realRoot
		local a = smooth(t / beat("swap"))
		local from = root.CFrame * Vector3.new(-6, 0.4, -10)
		local to = root.CFrame * Vector3.new(-1.4, 2.1, -3.8)
		local look = root.CFrame * Vector3.new(0, 1.4 + a * 0.4, 0)
		local roll = math.rad(10 * (1 - a))
		return CFrame.lookAt(from:Lerp(to, a) + shake, look) * CFrame.Angles(0, 0, roll), 62 - a * 14
	end
	local actor = STAGE
	-- 2) vazio: plano aberto que aproxima girando em volta
	if t < beat("eyes") then
		local a = smooth((t - beat("swap")) / (beat("eyes") - beat("swap")))
		local angle = math.rad(210 + a * 120)
		local distance = 36 - a * 28
		local height = 7 - a * 5
		local position = actor + Vector3.new(math.sin(angle) * distance, height, math.cos(angle) * distance)
		return CFrame.lookAt(position + shake, actor + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(-6 * a)),
			62 - a * 14
	end
	-- 3) close extremo no rosto, empurrando devagar
	if t < beat("pillar") then
		local a = smooth((t - beat("eyes")) / (beat("pillar") - beat("eyes")))
		local head = actorPoint(s, "Head", actor + Vector3.new(0, 1.2, 0))
		local position = head + Vector3.new(0.35, 0.05, -2.4 + a * 0.8)
		return CFrame.lookAt(position + shake * 0.5, head + Vector3.new(0, 0.05, 0)), 30 - a * 6
	end
	-- 4) pilar: dolly zoom de baixo (câmera entra enquanto o FOV abre), olhando o topo
	if t < beat("burst") then
		local a = (t - beat("pillar")) / (beat("burst") - beat("pillar"))
		local up = if a < 0.55 then smooth(a / 0.55) else 1 - smooth((a - 0.55) / 0.45) * 0.85
		local dolly = smooth(a)
		local position = actor + Vector3.new(5 - dolly * 1.6, -1.2, 9.5 - dolly * 4.5)
		local look = actor + Vector3.new(0, 2 + up * 70, -2)
		return CFrame.lookAt(position + shake, look), 48 + dolly * 34
	end
	-- 5) explosão: close frontal baixo, câmera recua com o impacto
	if t < C + 0.2 then
		local a = smooth((t - beat("burst")) / (C + 0.2 - beat("burst")))
		local position = actor + Vector3.new(-2.6, 0.2 + a * 0.6, -4.2 - a * 4)
		return CFrame.lookAt(position + shake, actor + Vector3.new(0, 1.6, 0)), 50 + a * 20
	end
	-- 6) revelação
	local r = s.reveal / REVEAL_REFERENCE
	local rt = t - C
	local slashAt, colorAt = AFTER.slash * r, AFTER.color * r
	if rt < slashAt then
		-- contra-plongée lento orbitando
		local a = smooth((rt - 0.2) / math.max(0.3, slashAt - 0.2))
		local angle = math.rad(200 - a * 40)
		local distance = 6.5 - a * 1.4
		local position = actor + Vector3.new(math.sin(angle) * distance, -1.2, math.cos(angle) * distance)
		return CFrame.lookAt(position + shake, actor + Vector3.new(0, 2.2, 0)), 58
	end
	if rt < colorAt then
		-- golpe: chicote de câmera para o lado acompanhando o corte
		local a = smooth((rt - slashAt) / (colorAt - slashAt))
		local whip = 1 - (1 - a) ^ 4
		local angle = math.rad(160 - whip * 75)
		local distance = 5.1 + a * 1.5
		local position = actor + Vector3.new(math.sin(angle) * distance, -0.8 + a * 0.6, math.cos(angle) * distance)
		return CFrame.lookAt(position + shake, actor + Vector3.new(0, 2, 0)) * CFrame.Angles(
			0,
			0,
			math.rad(8 * (1 - a))
		),
			60 - a * 6
	end
	-- plano heroico: recua e sobe, a cor de volta
	local a = smooth((rt - colorAt) / math.max(0.3, s.reveal - colorAt))
	local angle = math.rad(85 + a * 25)
	local distance = 6.6 + a * 9
	local position = actor + Vector3.new(math.sin(angle) * distance, -0.4 + a * 2.6, math.cos(angle) * distance)
	return CFrame.lookAt(position + shake, actor + Vector3.new(0, 2 - a * 0.3, 0)), 54 - a * 8
end

-- ======================================================================= fluxo
local function finish(s)
	if s.done then
		return
	end
	s.done = true
	if s.heartbeat then
		s.heartbeat:Disconnect()
	end
	for _, thread in s.threads do
		pcall(task.cancel, thread)
	end
	restoreLighting(s)
	if s.eyeLight then
		s.eyeLight:Destroy()
	end
	for _, r in s.worldRocks do
		r.part:Destroy()
	end
	if s.folder then
		s.folder:Destroy()
	end
	if s.gui then
		-- volta do branco curto para esconder a troca de cenário
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = WHITE
		flash.BorderSizePixel = 0
		flash.ZIndex = 10
		flash.Parent = s.gui
		for _, l in s.lines or {} do
			l.frame.Visible = false
		end
		tween(flash, 0.3, { BackgroundTransparency = 1 })
		task.delay(0.35, function()
			s.gui:Destroy()
		end)
	end
	if active == s then
		active = nil
	end
end

local function at(s, time: number, fn: () -> ())
	table.insert(
		s.threads,
		task.delay(time, function()
			if not s.done then
				fn()
			end
		end)
	)
end

-- Clona de novo com a aparência da forma liberada (roupa/arma novas aplicadas pelo servidor)
local function recloneActor(s)
	if s.revealed or not s.real.Parent then
		return
	end
	s.revealed = true
	local fresh = cloneCharacter(s.real, s.folder, s.actorFrame)
	if fresh then
		if s.actor then
			s.actor:Destroy()
		end
		s.actor = fresh
		AnimController.Play(fresh, "SwordIdle", { loop = true, fadeIn = 0 })
	end
end

-- d: dados do TransformStart (channel, reveal, element, formKanji, formName, command...)
function ReleaseCutscene.Play(model: Model, d: { [string]: any }, onReveal: (() -> ())?): boolean
	local realRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not realRoot or not humanoid or active then
		return false
	end
	local palette = ImpactFx.Palette(d.element)
	local channel = d.channel or REFERENCE
	local reveal = d.reveal or REVEAL_REFERENCE
	local k = channel / REFERENCE
	local r = reveal / REVEAL_REFERENCE
	local s: any = {
		real = model,
		realRoot = realRoot,
		element = d.element or "Reiatsu",
		channel = channel,
		reveal = reveal,
		hip = humanoid.HipHeight + realRoot.Size.Y / 2,
		ribbons = {},
		threads = {},
		rocks = {},
		worldRocks = {},
		done = false,
		rng = Random.new(),
	}
	active = s
	s.folder = Instance.new("Folder")
	s.folder.Name = "ReleaseCutscene"
	s.folder.Parent = workspace
	s.anchor = newPart(s.folder, Vector3.one, CFrame.new(STAGE), WHITE)
	s.anchor.Transparency = 1
	-- o personagem do palco olha para -Z (a câmera se posiciona em volta dele)
	s.actorFrame = CFrame.new(STAGE)
	saveLighting(s)
	buildScreen(s, palette)
	buildSpeedLines(s)
	s.lineColor = WHITE

	-- 1) mundo real: pedras se soltam do chão, o mundo escurece e perde cor
	local realFloor = realRoot.Position.Y - s.hip
	spawnRocks(s, s.worldRocks, realRoot.Position, realFloor, if VFX.Quality() == "Low" then 8 else 18, 11)
	tween(s.cc, BEAT.swap * k, { Saturation = -0.45, Contrast = 0.25, Brightness = -0.08 })

	local start = os.clock()
	local last = start
	local frameIndex = 0
	s.heartbeat = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local t = now - start
		local dt = now - last
		last = now
		frameIndex += 1
		for _, rb in s.ribbons do
			rb.part.CFrame = CFrame.new(rb.path(t))
		end
		if s.pillar then
			s.pillar.core.Transparency = 0.1 + math.noise(t * 30) * 0.25
		end
		updateRocks(s.worldRocks, t, dt, 0)
		updateRocks(s.rocks, t, dt, s.rocksSince or t)
		-- linhas de velocidade: sobem no carregamento, explodem nos impactos
		local target = 0
		if t < BEAT.swap * k then
			target = 0.25 * (t / (BEAT.swap * k))
		elseif t < BEAT.eyes * k then
			target = 0.15
		elseif t < BEAT.pillar * k then
			target = if t > BEAT.flare * k then 1 else 0.35
		elseif t < channel then
			target = 0.75
		elseif t < channel + AFTER.open * r then
			target = 0
		elseif t < channel + (AFTER.open + 0.5) * r then
			target = 0.9
		elseif t > channel + AFTER.slash * r and t < channel + (AFTER.slash + 0.5) * r then
			target = 0.8
		end
		s.lineLevel += (target - s.lineLevel) * math.min(1, dt * 12)
		updateSpeedLines(s, frameIndex)
	end)

	SoundController.Play("Release", realRoot)
	-- 1 → 2: corte diagonal e troca para o palco por baixo do branco
	at(s, BEAT.wipe * k, function()
		diagonalWipe(s, (BEAT.swap - BEAT.wipe) * k + 0.05)
		SoundController.Play("Lunge", realRoot)
	end)
	at(s, BEAT.swap * k, function()
		for _, rock in s.worldRocks do
			rock.part:Destroy()
		end
		table.clear(s.worldRocks)
		buildStage(s, palette)
		voidLighting(s, palette)
		backdropKanji(s, palette, d.formKanji or "解")
		s.actor = cloneCharacter(model, s.folder, s.actorFrame)
		if s.actor then
			-- ajoelha devagar segurando a espada; o "Release" do clip cai na explosão
			local releaseAt = AnimController.MarkerTime("ReleaseTier2", "Release", s.actor) or 1.6
			AnimController.Play(s.actor, "ReleaseTier2", {
				speed = releaseAt / math.max(0.5, (BEAT.burst - BEAT.swap) * k),
				fadeIn = 0,
			})
		end
		startSwirl(s, palette)
		spawnRocks(s, s.rocks, STAGE, STAGE.Y - s.hip, if VFX.Quality() == "Low" then 10 else 26, 16)
		s.rocksSince = os.clock() - start
		growCracks(s, palette, (BEAT.pillar - BEAT.swap) * k)
	end)
	-- 3) olhos acendem
	at(s, BEAT.flare * k, function()
		eyeFlare(s, palette)
		impactFrames(s, { false, true }, 0.05)
		s.lineColor = palette.core
		s.shakeUntil = os.clock() - start + 0.3
		SoundController.Play("Parry", s.anchor, 1)
	end)
	at(s, BEAT.pillar * k, function()
		raisePillar(s, palette)
		blastRocks(s, s.rocks, STAGE)
		s.lineColor = WHITE
		s.shakeUntil = os.clock() - start + 0.7
		if s.backdrop then
			tween(s.backdrop, 0.3, { TextTransparency = 0.35 })
		end
	end)
	at(s, BEAT.burst * k, function()
		burst(s, palette)
		impactFrames(s, { true, false, true }, 0.045)
		s.shakeUntil = os.clock() - start + 1
	end)
	at(s, BEAT.whiteIn * k, function()
		tween(
			s.white,
			channel - BEAT.whiteIn * k,
			{ BackgroundTransparency = 0 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
	end)
	-- tela branca: monta a revelação por baixo
	at(s, channel + 0.05, function()
		clearRibbons(s)
		if s.pillar then
			s.pillar.core:Destroy()
			s.pillar.shell:Destroy()
			s.pillar = nil
		end
		if s.aura then
			s.aura.Enabled = false
		end
		if s.stars then
			s.stars.Enabled = false
		end
		for _, rock in s.rocks do
			rock.part:Destroy()
		end
		table.clear(s.rocks)
		if s.backdrop then
			s.backdrop.TextTransparency = 1
		end
		if s.eyeLight then
			s.eyeLight:Destroy()
			s.eyeLight = nil
		end
		monochromeLighting(s)
		startWind(s)
	end)
	-- se o TransformComplete não chegar a tempo, revela com o que houver
	at(s, channel + AFTER.open * r - 0.02, function()
		recloneActor(s)
	end)
	at(s, channel + AFTER.open * r, function()
		tween(s.white, 0.12, { BackgroundTransparency = 1 })
		inkBurst(s)
		impactFrames(s, { false, true }, 0.05)
		titleCard(s, palette, d)
		s.shakeUntil = os.clock() - start + 0.45
		SoundController.Play("HitHeavy", s.anchor, 1)
		SoundController.Play("Ultimate", s.anchor, 1)
		if onReveal then
			task.spawn(onReveal)
		end
	end)
	-- golpe final: corte de energia com faixas brancas atravessando a tela
	at(s, channel + AFTER.slash * r, function()
		if s.actor then
			AnimController.Play(s.actor, "CastSlash", { fadeIn = 0.05 })
		end
		task.delay(0.25, function()
			if s.done then
				return
			end
			horizontalBands(s)
			impactFrames(s, { true }, 0.06)
			SoundController.Play("Slash", s.anchor, 1)
			s.shakeUntil = os.clock() - start + 0.4
		end)
	end)
	-- a cor volta com a forma nova
	at(s, channel + AFTER.color * r, function()
		hideTitle(s)
		colorBleed(s, palette)
		SoundController.Play("Boom", s.anchor, 1)
	end)

	CameraController.PlayScripted(channel + reveal, function(t)
		return cameraFrame(s, t)
	end, function()
		finish(s)
	end)
	return true
end

-- Chamado no TransformComplete do jogador local: a forma nova já está no personagem.
function ReleaseCutscene.OnComplete()
	local s = active
	if s and not s.done then
		task.delay(0.08, function()
			if active == s and not s.done then
				recloneActor(s)
			end
		end)
	end
end

function ReleaseCutscene.Cancel()
	if active then
		CameraController.EndCinematic()
	end
end

function ReleaseCutscene.IsPlaying(): boolean
	return active ~= nil
end

return ReleaseCutscene

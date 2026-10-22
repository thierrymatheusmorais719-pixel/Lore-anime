-- Cutscene da segunda liberação (Bankai / Segunda Etapa / Vollständig / Fullbring Completo),
-- no estilo do vídeo de referência:
--   1. plano no mundo real, câmera avançando pelo ombro
--   2. corte branco diagonal (wipe) → palco de vazio azul-escuro com estrelas e nebulosa
--   3. faixas de reiatsu girando em volta do personagem; câmera aproxima por trás
--   4. pilar de energia sobe; câmera inclina seguindo o topo e volta
--   5. explosão branca na cor do elemento engole tudo → tela branca (servidor aplica a forma aqui)
--   6. revelação em preto e branco: estouro de tinta, rajadas horizontais, golpe com faixa branca
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

-- Linha do tempo de referência (channel = 5,6 s): escalada pelo channel real
local BEAT = {
	wipe = 0.95, -- corte branco começa
	swap = 1.12, -- troca para o palco por baixo do branco
	void = 1.3, -- plano do vazio
	pillar = 2.9, -- pilar sobe
	burst = 4.4, -- explosão
	whiteIn = 5.0, -- branco cresce até `channel`
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

-- ======================================================================= câmera
-- Cada plano: função do tempo local (0..1) → (CFrame, FOV)
local function cameraFrame(s, t: number): (CFrame, number)
	local C = s.channel
	local k = C / 5.6
	local function beat(name: string): number
		return BEAT[name] * k
	end
	local shake = Vector3.zero
	if s.shakeUntil and t < s.shakeUntil then
		local amount = (s.shakeUntil - t) * 0.35
		shake = Vector3.new(math.noise(t * 25, 1) * amount, math.noise(t * 25, 2) * amount, 0)
	end
	-- 1) mundo real: avanço pelo ombro até o rosto
	if t < beat("swap") then
		local root = s.realRoot
		local a = smooth(t / beat("swap"))
		local from = root.CFrame * Vector3.new(-4.5, 1.6, -9)
		local to = root.CFrame * Vector3.new(-1.4, 2.1, -3.8)
		local look = root.CFrame * Vector3.new(0, 1.7, 0)
		return CFrame.lookAt(from:Lerp(to, a), look), 55 - a * 10
	end
	local actor = STAGE
	-- 2) vazio: plano aberto que aproxima por trás e gira em volta
	if t < beat("pillar") then
		local a = smooth((t - beat("swap")) / (beat("pillar") - beat("swap")))
		local angle = math.rad(210 + a * 110)
		local distance = 34 - a * 27
		local height = 6 - a * 4
		local position = actor + Vector3.new(math.sin(angle) * distance, height, math.cos(angle) * distance)
		return CFrame.lookAt(position + shake, actor + Vector3.new(0, 1.5, 0)), 60 - a * 12
	end
	-- 3) pilar: câmera baixa atrás, inclina seguindo o topo do pilar e volta ao personagem
	if t < beat("burst") then
		local a = (t - beat("pillar")) / (beat("burst") - beat("pillar"))
		local up = if a < 0.6 then smooth(a / 0.6) else 1 - smooth((a - 0.6) / 0.4) * 0.85
		local position = actor + Vector3.new(4.5, -1, 7.5)
		local look = actor + Vector3.new(0, 2 + up * 60, -2)
		return CFrame.lookAt(position + shake, look), 62 + up * 8
	end
	-- 4) explosão: close frontal baixo, câmera recua com o impacto
	if t < C + 0.2 then
		local a = smooth((t - beat("burst")) / (C + 0.2 - beat("burst")))
		local position = actor + Vector3.new(-2.6, 0.2 + a * 0.6, -4.2 - a * 3)
		return CFrame.lookAt(position + shake, actor + Vector3.new(0, 1.6, 0)), 50 + a * 18
	end
	-- 5) revelação P&B: contra-plongée lento orbitando; recua depois do golpe
	local r = math.clamp((t - C - 0.2) / math.max(0.5, s.reveal - 0.2), 0, 1)
	local angle = math.rad(200 - r * 45)
	local distance = 6.5 - smooth(r) * 1.2 + (if r > 0.6 then smooth((r - 0.6) / 0.4) * 4 else 0)
	local position = actor + Vector3.new(math.sin(angle) * distance, -1.2, math.cos(angle) * distance)
	return CFrame.lookAt(position + shake, actor + Vector3.new(0, 2.2, 0)), 58
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
	if s.folder then
		s.folder:Destroy()
	end
	if s.gui then
		-- volta do branco curto para esconder a troca de cenário
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = WHITE
		flash.BorderSizePixel = 0
		flash.Parent = s.gui
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

-- d: dados do TransformStart (channel, reveal, element, formKanji...)
function ReleaseCutscene.Play(model: Model, d: { [string]: any }, onReveal: (() -> ())?): boolean
	local realRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not realRoot or not humanoid or active then
		return false
	end
	local palette = ImpactFx.Palette(d.element)
	local channel = d.channel or 5.6
	local reveal = d.reveal or 2
	local k = channel / 5.6
	local s: any = {
		real = model,
		realRoot = realRoot,
		element = d.element or "Reiatsu",
		channel = channel,
		reveal = reveal,
		hip = humanoid.HipHeight + realRoot.Size.Y / 2,
		ribbons = {},
		threads = {},
		done = false,
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

	local start = os.clock()
	s.heartbeat = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		for _, r in s.ribbons do
			r.part.CFrame = CFrame.new(r.path(t))
		end
		if s.pillar then
			s.pillar.core.Transparency = 0.1 + math.noise(t * 30) * 0.25
		end
	end)

	SoundController.Play("Release", realRoot)
	-- 1 → 2: corte diagonal e troca para o palco por baixo do branco
	at(s, BEAT.wipe * k, function()
		diagonalWipe(s, (BEAT.swap - BEAT.wipe) * k + 0.05)
		SoundController.Play("Lunge", realRoot)
	end)
	at(s, BEAT.swap * k, function()
		buildStage(s, palette)
		voidLighting(s, palette)
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
	end)
	at(s, BEAT.pillar * k, function()
		raisePillar(s, palette)
		s.shakeUntil = os.clock() - start + 0.5
	end)
	at(s, BEAT.burst * k, function()
		burst(s, palette)
		s.shakeUntil = os.clock() - start + 0.8
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
		monochromeLighting(s)
		startWind(s)
	end)
	-- se o TransformComplete não chegar a tempo, revela com o que houver
	at(s, channel + 0.3, function()
		recloneActor(s)
	end)
	at(s, channel + 0.32, function()
		tween(s.white, 0.12, { BackgroundTransparency = 1 })
		inkBurst(s)
		s.shakeUntil = os.clock() - start + 0.4
		SoundController.Play("HitHeavy", s.anchor, 1)
		if onReveal then
			task.spawn(onReveal)
		end
	end)
	-- golpe final: corte de energia com faixas brancas atravessando a tela
	at(s, channel + reveal * 0.5, function()
		if s.actor then
			AnimController.Play(s.actor, "CastSlash", { fadeIn = 0.05 })
		end
		task.delay(0.25, function()
			if s.done then
				return
			end
			horizontalBands(s)
			SoundController.Play("Slash", s.anchor, 1)
			s.shakeUntil = os.clock() - start + 0.35
		end)
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

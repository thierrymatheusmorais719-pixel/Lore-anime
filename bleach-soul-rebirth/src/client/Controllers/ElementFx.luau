-- Assinatura visual por elemento: a camada que dá identidade a cada conjunto de habilidades.
-- Não é troca de cor — cada elemento tem forma, movimento e materiais próprios:
--   Fire      línguas de fogo que sobem e esfriam até o preto, brasas
--   Ice       estilhaços de gelo que voam e caem, névoa fria rente ao chão
--   Lightning raios em zigue-zague que piscam 3 vezes
--   Moon      lâminas em meia-lua pálidas com sombra escura
--   Hollow    tinta preta que estoura com rasgos vermelhos
--   Shadow    tentáculos escuros que se enrolam para fora
--   Sand      nuvem pesada de areia e grãos que caem
--   Blood     gotas carmesim com gravidade
--   Holy      cruz de luz e raios subindo
--   Gold      anel dourado e faíscas lentas
--   Verdant   espíritos verdes em espiral subindo
--   Chain     faíscas de metal laranja e elos voando
--   Time      anel de relógio que gira e para
--   Reiatsu   penas de energia azul subindo (pressão espiritual)
-- Orçamento: no máximo N objetos temporários vivos (qualidade decide N); acima disso a camada
-- é pulada (o impacto base do ImpactFx continua).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local VFX = require(script.Parent.VFXController)

local ElementFx = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local folder: Folder
local live = 0
local rng = Random.new()

local function budget(): number
	local q = VFX.Quality()
	return if q == "Low" then 12 elseif q == "Medium" then 30 else 55
end

-- Registra um objeto temporário e o remove depois de `life` segundos.
local function temp(instance: Instance, life: number): boolean
	if live >= budget() then
		instance:Destroy()
		return false
	end
	live += 1
	instance.Parent = folder
	task.delay(life, function()
		live -= 1
		instance:Destroy()
	end)
	return true
end

function ElementFx.Live(): number
	return live
end

local function seq(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function tween(
	instance: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	TweenService
		:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
		:Play()
end

-- Emissor de rajada única num ponto (anexo numa peça invisível que some sozinha)
local function burstEmitter(
	position: Vector3,
	direction: Vector3?,
	props: { [string]: any },
	count: number,
	life: number
)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	local dir = direction
	if dir and dir.Magnitude > 0.01 and math.abs(dir.Unit.Y) < 0.98 then
		holder.CFrame = CFrame.lookAt(position, position + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
	else
		holder.CFrame = CFrame.new(position)
	end
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = holder
	if not temp(holder, life) then
		return
	end
	local q = VFX.Quality()
	e:Emit(if q == "Low" then math.max(1, math.floor(count * 0.4)) else count)
end

local function neonPart(
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	if shape then
		p.Shape = shape
	end
	return p
end

-- Raio em zigue-zague entre dois pontos (peças finas), pisca e some
local function bolt(from: Vector3, to: Vector3, color: Color3, width: number)
	local segments = 6
	local points = { from }
	local axis = to - from
	local side = axis:Cross(Vector3.yAxis)
	if side.Magnitude < 0.01 then
		side = Vector3.xAxis
	end
	side = side.Unit
	local up = side:Cross(axis).Unit
	for i = 1, segments - 1 do
		local base = from + axis * (i / segments)
		table.insert(
			points,
			base
				+ side * rng:NextNumber(-1, 1) * axis.Magnitude * 0.12
				+ up * rng:NextNumber(-1, 1) * axis.Magnitude * 0.08
		)
	end
	table.insert(points, to)
	local model = Instance.new("Model")
	model.Name = "Bolt"
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = neonPart(Vector3.new(width, width, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color)
		seg.Parent = model
	end
	if not temp(model, 0.3) then
		return
	end
	-- pisca 3 vezes
	task.spawn(function()
		for i = 1, 3 do
			for _, p in model:GetChildren() do
				(p :: Part).Transparency = if i % 2 == 0 then 0.7 else 0
			end
			task.wait(0.05)
		end
		for _, p in model:GetChildren() do
			tween(p, 0.12, { Transparency = 1 })
		end
	end)
end

local function ring(position: Vector3, color: Color3, from: number, to: number, life: number, material: Enum.Material?)
	local p = neonPart(
		Vector3.new(0.12, from, from),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.PartType.Cylinder,
		material
	)
	p.Transparency = 0.15
	if temp(p, life + 0.05) then
		tween(p, life, { Size = Vector3.new(0.05, to, to), Transparency = 1 }, Enum.EasingStyle.Quint)
	end
end

-- ======================================================================= assinaturas
local SIGNATURES: { [string]: (Vector3, Vector3?, number, any) -> () } = {}

SIGNATURES.Fire = function(pos, dir, s, e)
	burstEmitter(pos, Vector3.yAxis, {
		Texture = FIRE,
		LightEmission = 0.6,
		Brightness = 4,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 180)),
			ColorSequenceKeypoint.new(0.3, e.primary),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(120, 20, 10)),
			ColorSequenceKeypoint.new(1, BLACK),
		}),
		Size = seq({ { 0, 1.2 * s }, { 0.4, 2.6 * s }, { 1, 0.4 * s } }),
		Transparency = seq({ { 0, 0.1 }, { 0.7, 0.4 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.35, 0.7),
		Speed = NumberRange.new(10 * s, 20 * s),
		Drag = 3,
		SpreadAngle = Vector2.new(40, 40),
		Acceleration = Vector3.new(0, 18, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
	}, math.floor(12 * s), 1.2)
	burstEmitter(pos, Vector3.yAxis, {
		Texture = SPARK,
		LightEmission = 1,
		Brightness = 3,
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), e.primary),
		Size = seq({ { 0, 0.25 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(8, 18),
		Drag = 2,
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, 6, 0),
	}, math.floor(14 * s), 1.6)
end

SIGNATURES.Ice = function(pos, dir, s, e)
	-- estilhaços sólidos que voam e caem
	local count = math.floor(5 * s)
	for _ = 1, count do
		local shard = neonPart(
			Vector3.new(0.18, 0.18, rng:NextNumber(0.6, 1.4) * s),
			CFrame.new(pos),
			e.primary:Lerp(WHITE, 0.4),
			nil,
			Enum.Material.Glass
		)
		shard.Transparency = 0.2
		if temp(shard, 0.75) then
			local fly = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.3, 1.2), rng:NextNumber(-1, 1)).Unit
				* rng:NextNumber(4, 8)
				* s
			local land = pos + fly + Vector3.new(0, -2.5, 0)
			shard.CFrame = CFrame.lookAt(pos, pos + fly)
			tween(
				shard,
				0.7,
				{ CFrame = CFrame.lookAt(land, land + fly) * CFrame.Angles(math.rad(80), 0, 0), Transparency = 1 },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
		end
	end
	burstEmitter(pos - Vector3.new(0, 1.5, 0), Vector3.yAxis, {
		Texture = SMOKE,
		LightEmission = 0.3,
		LightInfluence = 0.6,
		Color = ColorSequence.new(WHITE, e.primary),
		Size = seq({ { 0, 2 * s }, { 1, 6 * s } }),
		Transparency = seq({ { 0, 0.5 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(4, 8),
		Drag = 3,
		SpreadAngle = Vector2.new(180, 8),
		TimeScale = 0.8,
	}, math.floor(6 * s), 1.6)
end

SIGNATURES.Lightning = function(pos, dir, s, e)
	for i = 1, math.max(2, math.floor(3 * s)) do
		local out = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 1), rng:NextNumber(-1, 1)).Unit
			* rng:NextNumber(4, 7)
			* s
		task.delay((i - 1) * 0.03, function()
			bolt(pos, pos + out, if i % 2 == 0 then e.secondary else e.primary:Lerp(WHITE, 0.3), 0.12 * s)
		end)
	end
end

SIGNATURES.Moon = function(pos, dir, s, e)
	-- meias-luas pálidas cruzadas, com uma escura atrás (contraste)
	for i = 0, 1 do
		local angle = math.rad(if i == 0 then 25 else -35)
		local frame = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), angle)
		task.delay(i * 0.05, function()
			VFX.SlashArc(frame, if i == 0 then e.primary:Lerp(WHITE, 0.4) else e.secondary, 4.5 * s, 0.4, 0.3, i == 1)
		end)
	end
end

SIGNATURES.Hollow = function(pos, dir, s, e)
	burstEmitter(pos, dir, {
		Texture = SMOKE,
		LightEmission = 0,
		Brightness = 0,
		Color = ColorSequence.new(BLACK),
		Size = seq({ { 0, 1.5 * s }, { 1, 4.5 * s } }),
		Transparency = seq({ { 0, 0.15 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(14 * s, 26 * s),
		Drag = 6,
		SpreadAngle = Vector2.new(60, 60),
		ZOffset = -1,
	}, math.floor(8 * s), 1)
	burstEmitter(pos, dir, {
		Texture = SPARK,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rotation = NumberRange.new(-90),
		Squash = seq({ { 0, -3 }, { 1, -1 } }),
		LightEmission = 0.4,
		Brightness = 6,
		Color = ColorSequence.new(e.primary, Color3.fromRGB(60, 0, 10)),
		Size = seq({ { 0, 0.6 * s }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(50, 80),
		Drag = 12,
		SpreadAngle = Vector2.new(50, 50),
	}, math.floor(6 * s), 0.6)
end

SIGNATURES.Shadow = function(pos, dir, s, e)
	-- tentáculos: fitas escuras que se enrolam para fora
	for i = 1, math.max(2, math.floor(4 * s)) do
		local yaw = (i / 4) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local points = {}
		for k = 0, 8 do
			local t = k / 8
			local r = t * 6 * s
			local a = yaw + t * 1.6
			table.insert(
				points,
				pos + Vector3.new(math.cos(a) * r, math.sin(t * math.pi) * 2.2 * s - t * 1.2, math.sin(a) * r)
			)
		end
		task.delay(i * 0.02, function()
			VFX.SweepRibbon(points, if i % 2 == 0 then e.primary else e.secondary:Lerp(e.primary, 0.3), 0.3 * s, 0.35)
		end)
	end
end

SIGNATURES.Sand = function(pos, dir, s, e)
	burstEmitter(pos - Vector3.new(0, 1, 0), Vector3.yAxis, {
		Texture = SMOKE,
		LightEmission = 0,
		LightInfluence = 1,
		Color = ColorSequence.new(e.primary, e.secondary),
		Size = seq({ { 0, 2.5 * s }, { 1, 8 * s } }),
		Transparency = seq({ { 0, 0.3 }, { 0.4, 0.45 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(8, 16),
		Drag = 3,
		SpreadAngle = Vector2.new(80, 30),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-30, 30),
		TimeScale = 0.75,
	}, math.floor(8 * s), 2.2)
	burstEmitter(pos, Vector3.yAxis, {
		Texture = SPARK,
		LightEmission = 0,
		Color = ColorSequence.new(e.secondary),
		Size = seq({ { 0, 0.18 }, { 1, 0.12 } }),
		Lifetime = NumberRange.new(0.7, 1.1),
		Speed = NumberRange.new(14, 24),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -40, 0),
	}, math.floor(20 * s), 1.4)
end

SIGNATURES.Blood = function(pos, dir, s, e)
	burstEmitter(pos, dir, {
		Texture = SPARK,
		LightEmission = 0.1,
		Brightness = 2,
		Color = ColorSequence.new(e.primary, Color3.fromRGB(70, 0, 10)),
		Size = seq({ { 0, 0.35 * s }, { 1, 0.15 * s } }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(16, 28),
		Drag = 1,
		SpreadAngle = Vector2.new(55, 55),
		Acceleration = Vector3.new(0, -60, 0),
	}, math.floor(16 * s), 1.2)
end

SIGNATURES.Holy = function(pos, dir, s, e)
	-- cruz de luz (dois flares finos) e raios curtos subindo
	for i = 0, 1 do
		local beam = neonPart(
			if i == 0 then Vector3.new(0.15, 7 * s, 0.15) else Vector3.new(4.5 * s, 0.15, 0.15),
			CFrame.new(pos + Vector3.new(0, i * 0.8, 0)),
			e.secondary
		)
		if temp(beam, 0.35) then
			tween(beam, 0.3, {
				Transparency = 1,
				Size = beam.Size * Vector3.new(if i == 0 then 0.2 else 1.3, if i == 0 then 1.3 else 0.2, 1),
			})
		end
	end
	for _ = 1, math.floor(4 * s) do
		local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)) * s
		local ray = neonPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos + offset), e.primary)
		if temp(ray, 0.6) then
			tween(ray, 0.55, {
				Size = Vector3.new(0.12, 9 * s, 0.12),
				CFrame = CFrame.new(pos + offset + Vector3.new(0, 4.5 * s, 0)),
				Transparency = 1,
			})
		end
	end
end

SIGNATURES.Gold = function(pos, dir, s, e)
	ring(pos - Vector3.new(0, 1.8, 0), e.primary, 1, 14 * s, 0.5)
	burstEmitter(pos, Vector3.yAxis, {
		Texture = SPARK,
		LightEmission = 1,
		Brightness = 3,
		Color = ColorSequence.new(e.secondary, e.primary),
		Size = seq({ { 0, 0 }, { 0.2, 0.45 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(4, 10),
		Drag = 2,
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 2, 0),
		RotSpeed = NumberRange.new(-200, 200),
	}, math.floor(18 * s), 1.5)
end

SIGNATURES.Verdant = function(pos, dir, s, e)
	-- espíritos em espiral subindo
	for i = 1, math.max(2, math.floor(3 * s)) do
		local phase = i / 3 * math.pi * 2
		local points = {}
		for k = 0, 10 do
			local t = k / 10
			local a = phase + t * math.pi * 2.2
			local r = (1 - t) * 2.5 * s + 0.5
			table.insert(points, pos + Vector3.new(math.cos(a) * r, t * 7 * s, math.sin(a) * r))
		end
		VFX.SweepRibbon(points, e.primary, 0.18 * s, 0.6)
	end
end

SIGNATURES.Chain = function(pos, dir, s, e)
	burstEmitter(pos, dir, {
		Texture = SPARK,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rotation = NumberRange.new(-90),
		Squash = seq({ { 0, -2 }, { 1, -0.5 } }),
		LightEmission = 1,
		Brightness = 5,
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 160), e.primary),
		Size = seq({ { 0, 0.4 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(30, 55),
		Drag = 4,
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -50, 0),
	}, math.floor(14 * s), 1)
	for _ = 1, math.floor(3 * s) do
		local link = neonPart(
			Vector3.new(0.12, 0.45, 0.7),
			CFrame.new(pos),
			e.secondary:Lerp(Color3.fromRGB(90, 90, 100), 0.5),
			nil,
			Enum.Material.Metal
		)
		if temp(link, 0.7) then
			local out = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1), rng:NextNumber(-1, 1)).Unit * 6 * s
			tween(link, 0.65, {
				CFrame = CFrame.new(pos + out - Vector3.new(0, 2, 0))
					* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
				Transparency = 1,
			})
		end
	end
end

SIGNATURES.Time = function(pos, dir, s, e)
	-- anel de relógio: aro + 12 marcas que giram e param de repente
	local model = Instance.new("Model")
	local radius = 5 * s
	local base = CFrame.new(pos) * CFrame.Angles(math.rad(90), 0, 0)
	local rim = neonPart(
		Vector3.new(0.1, radius * 2, radius * 2),
		base * CFrame.Angles(0, math.rad(90), 0),
		e.primary,
		Enum.PartType.Cylinder,
		Enum.Material.ForceField
	)
	rim.Parent = model
	local ticks = {}
	for i = 0, 11 do
		local tick =
			neonPart(Vector3.new(0.12, if i % 3 == 0 then 1 else 0.5, 0.12), CFrame.new(), e.secondary:Lerp(WHITE, 0.6))
		tick.Parent = model
		table.insert(ticks, tick)
	end
	if not temp(model, 0.9) then
		return
	end
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > 0.85 or not model.Parent then
			connection:Disconnect()
			return
		end
		local spin = if t < 0.45 then t * 8 else 0.45 * 8 -- gira e congela
		for i, tick in ticks do
			local a = (i - 1) / 12 * math.pi * 2 + spin
			tick.CFrame = base
				* CFrame.new(math.cos(a) * radius * 0.85, 0, math.sin(a) * radius * 0.85)
				* CFrame.Angles(0, -a, math.rad(90))
			tick.Transparency = math.clamp((t - 0.5) / 0.35, 0, 1)
		end
		rim.Transparency = math.clamp(0.3 + (t - 0.45) / 0.4, 0.3, 1)
	end)
end

SIGNATURES.Reiatsu = function(pos, dir, s, e)
	burstEmitter(pos, Vector3.yAxis, {
		Texture = SPARK,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rotation = NumberRange.new(-90),
		Squash = seq({ { 0, -2.5 }, { 1, -1 } }),
		LightEmission = 1,
		Brightness = 3,
		Color = ColorSequence.new(e.secondary, e.primary),
		Size = seq({ { 0, 0.7 * s }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(14, 26),
		Drag = 4,
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, 12, 0),
	}, math.floor(12 * s), 1.1)
end

-- Executa a assinatura do elemento num ponto. scale: 1 = golpe pesado, 2+ = finalizador/explosão.
function ElementFx.Signature(position: Vector3, direction: Vector3?, element: string?, scale: number?)
	local id = element or "Reiatsu"
	local fn = SIGNATURES[id] or SIGNATURES.Reiatsu
	local e = Elements[id] or Elements.Reiatsu
	local ok, err = pcall(fn, position, direction, scale or 1, e)
	if not ok then
		warn("[ElementFx]", id, err)
	end
end

ElementFx.Elements = SIGNATURES

function ElementFx.Init()
	folder = Instance.new("Folder")
	folder.Name = "ElementFx"
	folder.Parent = workspace
end

return ElementFx

--!strict
-- Impactos, cargas e liberações em camadas, seguindo as medições da skill roblox-vfx-animation
-- (references/vfx-design.md):
--   • paleta de ~5 cores por elemento (núcleo quente, primária, secundária, escuro, fumaça neutra);
--   • valor: camada preta atrás do clarão, cópias que esfriam (LightEmission 1 → 0);
--   • tempo: clarão em 0, o resto a +0,03 s em degraus; intensidade só cai (clarão → estilhaços →
--     resíduo), mas a massa (poeira) continua crescendo depois do clarão;
--   • movimento: estouro com arrasto forte (sai rápido e para), poeira lenta e acinzentada.
-- Texturas: as embutidas do Roblox (rbxasset://textures/particles/*) — substitutas até haver
-- texturas próprias (ver README: dependências externas).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local VFX = require(script.Parent.VFXController)
local ElementFx = require(script.Parent.ElementFx)
local MeshFx = require(script.Parent.MeshFx)

local ImpactFx = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

export type Palette = {
	core: Color3,
	primary: Color3,
	secondary: Color3,
	dark: Color3,
	smoke: Color3,
}

local folder: Folder
local anchor: Part
local emitters: { [string]: ParticleEmitter } = {}
local function qualityOf(): string
	return VFX.Quality()
end

local function luminance(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

-- Paleta: núcleo = primária quase branca; secundária = a do elemento; escuro = primária afundada
-- (ou a secundária, quando ela já é escura); fumaça = cinza quente levemente tingido.
function ImpactFx.Palette(element: string?): Palette
	local e = Elements[element or "Reiatsu"] or Elements.Reiatsu
	local primary: Color3 = e.primary
	local secondary: Color3 = e.secondary
	local darkSecondary = luminance(secondary) < 0.25
	return {
		core = primary:Lerp(WHITE, 0.72),
		primary = primary,
		secondary = if darkSecondary then primary:Lerp(WHITE, 0.35) else secondary,
		dark = if darkSecondary then secondary else primary:Lerp(BLACK, 0.85),
		smoke = Color3.fromRGB(118, 112, 106):Lerp(primary, 0.12),
	}
end

local function seq(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function make(name: string, props: { [string]: any }): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = anchor
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled = false
	e.Rate = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = attachment
	emitters[name] = e
	return e
end

local function scaleCount(count: number): number
	local q = qualityOf()
	if q == "Low" then
		return math.max(1, math.floor(count * 0.35))
	elseif q == "Medium" then
		return math.max(1, math.floor(count * 0.65))
	end
	return count
end

-- Dispara a camada `name` em `position`, apontada para `direction`, com cor e escala de tamanho.
local function fire(
	name: string,
	position: Vector3,
	direction: Vector3?,
	color: ColorSequence,
	count: number,
	sizeScale: number
)
	local e = emitters[name]
	if not e then
		return
	end
	local attachment = e.Parent :: Attachment
	if direction and direction.Magnitude > 0.01 and math.abs(direction.Unit.Y) < 0.98 then
		-- o emissor solta partículas no +Y do anexo
		attachment.WorldCFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
	elseif direction and direction.Y < 0 then
		attachment.WorldCFrame = CFrame.new(position) * CFrame.Angles(math.pi, 0, 0)
	else
		attachment.WorldCFrame = CFrame.new(position)
	end
	e.Color = color
	local base = e:GetAttribute("BaseSize") :: number?
	if base then
		local keys = {}
		for _, k in (e:GetAttribute("SizeShape") :: string):split(";") do
			local t, v = k:match("([%d.]+):([%d.]+)")
			table.insert(keys, NumberSequenceKeypoint.new(tonumber(t) :: number, (tonumber(v) :: number) * sizeScale))
		end
		e.Size = NumberSequence.new(keys)
	end
	e:Emit(scaleCount(count))
end

-- Curva de tamanho que escala por golpe (guardada como texto no próprio emissor)
local function sized(props: { [string]: any }, shape: { { number } }): { [string]: any }
	local parts = {}
	for _, p in shape do
		table.insert(parts, string.format("%g:%g", p[1], p[2]))
	end
	props.Size = seq(shape)
	props._shape = table.concat(parts, ";")
	return props
end

local function define(name: string, props: { [string]: any })
	local shape = props._shape
	props._shape = nil
	local e = make(name, props)
	if shape then
		e:SetAttribute("BaseSize", 1)
		e:SetAttribute("SizeShape", shape)
	end
end

local function light(position: Vector3, color: Color3, range: number, duration: number)
	if qualityOf() == "Low" then
		return
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = anchor
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 4
	l.Shadows = false
	l.Parent = holder
	TweenService:Create(l, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
		:Play()
	Debris:AddItem(holder, duration + 0.05)
end

-- ======================================================================= IMPACTO
-- tier 1 = golpe leve, 2 = pesado/contra-ataque, 3 = finalizador/execução.
-- Tamanhos pelo guia: um golpe entre muitos ~10 studs no clarão; finalizador bem maior.
function ImpactFx.Hit(position: Vector3, direction: Vector3?, element: string?, tier: number?, palette: Palette?)
	local p = palette or ImpactFx.Palette(element)
	local t = tier or 1
	local s = if t >= 3 then 2.4 elseif t == 2 then 1.6 else 1
	local dir = if direction and direction.Magnitude > 0.01 then direction.Unit else nil

	-- silhuetas fortes de malha: estrela tripla com fundo preto, anel, espinhos e estilhaços
	MeshFx.Impact(position, dir, element, t)
	-- 0,00 s: clarão (forma espinhosa que encolhe) + fundo preto + linha de flare + brilho
	fire("Flash", position, nil, ColorSequence.new(p.core), 1, s)
	fire("FlashBack", position, nil, ColorSequence.new(BLACK), 1, s)
	fire("Flare", position, nil, ColorSequence.new(WHITE), if t >= 2 then 2 else 1, s)
	fire("Glow", position, nil, ColorSequence.new(p.primary), 1, s)
	light(position, p.primary, 10 * s, 0.18)

	-- +0,03 s: estilhaços de energia (estouro com arrasto) e cópias que esfriam
	task.delay(0.03, function()
		local streakColor = ColorSequence.new({
			ColorSequenceKeypoint.new(0, p.core),
			ColorSequenceKeypoint.new(0.4, p.primary),
			ColorSequenceKeypoint.new(1, p.secondary),
		})
		fire("Streak", position, dir, streakColor, math.floor(9 * s), s)
		fire("StreakCool", position, dir, ColorSequence.new(p.primary, p.dark), math.floor(5 * s), s)
	end)
	-- +0,06 s: poeira neutra (matéria dessaturada ao lado da energia) que cresce enquanto some
	task.delay(0.06, function()
		fire("Dust", position, Vector3.yAxis, ColorSequence.new(p.smoke), math.floor(3 * s), s)
	end)
	-- +0,05 s: assinatura do elemento (forma própria de cada poder; golpes leves em escala menor)
	task.delay(0.05, function()
		ElementFx.Signature(position, dir, element, if t >= 3 then 2 elseif t == 2 then 1 else 0.5)
	end)
	-- +0,10 s: resíduo — brasas lentas subindo (só pesados)
	if t >= 2 then
		task.delay(0.1, function()
			fire("Ember", position, Vector3.yAxis, ColorSequence.new(p.secondary, p.primary), math.floor(6 * s), 1)
		end)
	end
end

-- ======================================================================= CARGA E LIBERAÇÃO
-- Carga: energia converge para o ponto (esfera de emissão "Inward") com rastros finos, núcleo
-- pequeno que pulsa e, no fim, um anel que implode — em vez de uma esfera neon que só cresce.
-- Devolve uma função para cancelar.
function ImpactFx.Charge(host: BasePart, offset: CFrame, element: string?, duration: number, big: boolean?): () -> ()
	-- espirais de malha apertando em volta do ponto de carga
	MeshFx.Charge(host.CFrame * offset, element, duration, big)
	local p = ImpactFx.Palette(element)
	local scale = if big then 1.8 else 1
	local attachment = Instance.new("Attachment")
	attachment.CFrame = offset
	attachment.Parent = host

	local radius = 7 * scale
	local inward = Instance.new("ParticleEmitter")
	inward.Texture = SPARK
	inward.Shape = Enum.ParticleEmitterShape.Sphere
	inward.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	inward.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	inward.ShapePartial = 1
	inward.Orientation = Enum.ParticleOrientation.VelocityParallel
	inward.Rotation = NumberRange.new(-90)
	inward.Squash = seq({ { 0, -1.5 }, { 1, -3 } })
	inward.Speed = NumberRange.new(radius * 2.2)
	inward.Lifetime = NumberRange.new(0.42)
	inward.Size = seq({ { 0, 0.15 * scale }, { 0.7, 0.4 * scale }, { 1, 0 } })
	inward.Transparency = seq({ { 0, 1 }, { 0.25, 0.1 }, { 1, 0 } })
	inward.LightEmission = 1
	inward.Brightness = 3
	inward.Color = ColorSequence.new(p.secondary, p.core)
	inward.Rate = if qualityOf() == "Low" then 25 else 70
	-- a forma da emissão vem do tamanho do anexo-pai: usa uma peça invisível como volume
	local volume = Instance.new("Part")
	volume.Name = "ChargeVolume"
	volume.Shape = Enum.PartType.Ball
	volume.Size = Vector3.one * radius * 2
	volume.Transparency = 1
	volume.CanCollide = false
	volume.CanQuery = false
	volume.CanTouch = false
	volume.Massless = true
	volume.CFrame = host.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = host
	weld.Part1 = volume
	weld.Parent = volume
	volume.Parent = folder
	inward.Parent = volume

	-- Núcleo: pequeno, quente, com fundo escuro para ler contra o céu
	local core = Instance.new("ParticleEmitter")
	core.Texture = SPARK
	core.LightEmission = 0.6
	core.Brightness = 8
	core.Color = ColorSequence.new(p.core)
	core.Size = seq({ { 0, 0.8 * scale }, { 0.5, 1.3 * scale }, { 1, 0.8 * scale } })
	core.Transparency = seq({ { 0, 0.2 }, { 1, 1 } })
	core.Lifetime = NumberRange.new(0.12)
	core.RotSpeed = NumberRange.new(-200, 200)
	core.Rotation = NumberRange.new(0, 360)
	core.Speed = NumberRange.new(0)
	core.Rate = 40
	core.LockedToPart = true
	core.ZOffset = 1
	core.Parent = attachment
	local back = Instance.new("ParticleEmitter")
	back.Texture = SMOKE
	back.LightEmission = 0
	back.Brightness = 0
	back.Color = ColorSequence.new(BLACK)
	back.Size = seq({ { 0, 1.6 * scale }, { 1, 2.2 * scale } })
	back.Transparency = seq({ { 0, 0.55 }, { 1, 1 } })
	back.Lifetime = NumberRange.new(0.2)
	back.Speed = NumberRange.new(0)
	back.Rate = 18
	back.LockedToPart = true
	back.ZOffset = -1
	back.Parent = attachment
	local glow = Instance.new("PointLight")
	glow.Color = p.primary
	glow.Range = 8 * scale
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = attachment
	TweenService:Create(glow, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Brightness = 4,
	}):Play()

	local alive = true
	-- Implosão: anel neon que encolhe de ~11 a 0 nos últimos 0,18 s
	task.delay(math.max(0, duration - 0.18), function()
		if not alive or not host.Parent then
			return
		end
		local ring = Instance.new("Part")
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = p.core
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.12, 11 * scale, 11 * scale)
		ring.CFrame = (host.CFrame * offset) * CFrame.Angles(0, math.rad(90), 0)
		ring.Transparency = 0.35
		ring.Parent = folder
		TweenService:Create(ring, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = Vector3.new(0.12, 0.2, 0.2),
			Transparency = 0,
		}):Play()
		Debris:AddItem(ring, 0.2)
	end)

	local function stop()
		if not alive then
			return
		end
		alive = false
		inward.Enabled = false
		core.Enabled = false
		back.Enabled = false
		Debris:AddItem(volume, 0.5)
		Debris:AddItem(attachment, 0.3)
	end
	task.delay(duration, stop)
	return stop
end

-- Liberação: ~10× o núcleo da carga, num quadro; o corpo do efeito vem da habilidade em si.
function ImpactFx.Release(position: Vector3, direction: Vector3?, element: string?, big: boolean?)
	ImpactFx.Hit(position, direction, element, if big then 3 else 2)
	if big then
		MeshFx.Burst(position, element, 0.8)
	end
end

function ImpactFx.Init()
	folder = Instance.new("Folder")
	folder.Name = "ImpactFx"
	folder.Parent = workspace
	anchor = Instance.new("Part")
	anchor.Name = "ImpactAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.identity
	anchor.Parent = folder

	-- Clarão: forma espinhosa que nasce grande e encolhe (0,08 s), mais quente que tudo
	define(
		"Flash",
		sized({
			Texture = SPARK,
			LightEmission = 0.6,
			Brightness = 12,
			Lifetime = NumberRange.new(0.08),
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 360),
			Transparency = seq({ { 0, 0 }, { 1, 0.6 } }),
			ZOffset = 2,
		}, { { 0, 7 }, { 1, 0 } })
	)
	-- Fundo preto: 1,4× o clarão, atrás (ZOffset -1), dá contraste ao núcleo sobre chão claro
	define(
		"FlashBack",
		sized({
			Texture = SMOKE,
			LightEmission = 0,
			Brightness = 0,
			Lifetime = NumberRange.new(0.12),
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 360),
			Transparency = seq({ { 0, 0.35 }, { 1, 1 } }),
			ZOffset = -1,
		}, { { 0, 6 }, { 1, 9 } })
	)
	-- Linha de flare achatada (Squash negativo), fina e curtíssima
	define(
		"Flare",
		sized({
			Texture = SPARK,
			LightEmission = 1,
			Brightness = 4,
			Squash = seq({ { 0, -4 }, { 1, -4 } }),
			Lifetime = NumberRange.new(0.07),
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(-20, 20),
			Transparency = seq({ { 0, 0 }, { 1, 1 } }),
			ZOffset = 3,
		}, { { 0, 9 }, { 1, 11 } })
	)
	-- Halo de cor: aditivo e baixo (o trabalho dele é o bloom em volta)
	define(
		"Glow",
		sized({
			Texture = SMOKE,
			LightEmission = 1,
			Brightness = 2,
			Lifetime = NumberRange.new(0.16),
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 360),
			Transparency = seq({ { 0, 0.3 }, { 1, 1 } }),
			ZOffset = 1,
		}, { { 0, 4 }, { 1, 7 } })
	)
	-- Estilhaços: rastros paralelos à velocidade, estouram e param (arrasto forte)
	define(
		"Streak",
		sized({
			Texture = SPARK,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Rotation = NumberRange.new(-90),
			Squash = seq({ { 0, -2.5 }, { 1, -0.8 } }),
			LightEmission = 1,
			Brightness = 4,
			Lifetime = NumberRange.new(0.16, 0.32),
			Speed = NumberRange.new(70, 110),
			Drag = 14,
			SpreadAngle = Vector2.new(55, 55),
			Transparency = seq({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
			ZOffset = 1,
		}, { { 0, 0.55 }, { 1, 0 } })
	)
	-- Cópia que esfria: sem brilho aditivo, vive mais, mais escura
	define(
		"StreakCool",
		sized({
			Texture = SPARK,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Rotation = NumberRange.new(-90),
			Squash = seq({ { 0, -1.5 }, { 1, -0.5 } }),
			LightEmission = 0,
			Brightness = 1.5,
			Lifetime = NumberRange.new(0.3, 0.55),
			Speed = NumberRange.new(45, 75),
			Drag = 10,
			Acceleration = Vector3.new(0, -20, 0),
			SpreadAngle = Vector2.new(65, 65),
			Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
		}, { { 0, 0.35 }, { 1, 0 } })
	)
	-- Poeira: cinza iluminada pela cena, lenta (TimeScale), cresce ~20% enquanto some
	define(
		"Dust",
		sized({
			Texture = SMOKE,
			LightEmission = 0,
			LightInfluence = 1,
			Brightness = 1,
			Lifetime = NumberRange.new(0.7, 1.3),
			Speed = NumberRange.new(5, 12),
			Drag = 3,
			SpreadAngle = Vector2.new(70, 70),
			Acceleration = Vector3.new(0, 2, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-40, 40),
			Transparency = seq({ { 0, 0.55 }, { 0.3, 0.6 }, { 1, 1 } }),
			TimeScale = 0.85,
			ZOffset = -2,
		}, { { 0, 1.5 }, { 1, 5 } })
	)
	-- Brasas do resíduo: pequenas, sobem devagar
	define("Ember", {
		Texture = SPARK,
		LightEmission = 1,
		Brightness = 3,
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(4, 9),
		Drag = 2,
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, 5, 0),
		Size = seq({ { 0, 0.25 }, { 1, 0 } }),
		Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
	})
end

return ImpactFx

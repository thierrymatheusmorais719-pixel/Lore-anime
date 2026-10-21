-- Biblioteca de efeitos visuais do cliente: cortes no ar, faíscas, clarões, ondas de choque,
-- pilares, projéteis, feixes, chuva, imagens residuais, rastros de espada, auras e números de dano.
-- Emissores compartilhados + pools reduzem custo; a qualidade "Low" corta partículas e luzes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Elements = require(Shared.Config.Elements)
local Powers = require(Shared.Config.Powers)
local Factions = require(Shared.Config.Factions)
local Pool = require(Shared.Util.Pool)

local VFX = {}

local player = Players.LocalPlayer
local folder: Folder
local anchor: Part
local quality = "High"
local rng = Random.new()

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

function VFX.SetQuality(q: string)
	quality = q
end

function VFX.Quality(): string
	return quality
end

function VFX.Color(element: string?): Color3
	local e = Elements[element or "Reiatsu"] or Elements.Reiatsu
	return e.primary
end

function VFX.Secondary(element: string?): Color3
	local e = Elements[element or "Reiatsu"] or Elements.Reiatsu
	return e.secondary
end

-- Elemento atual de um personagem (forma liberada usa o elemento do poder)
function VFX.ElementOf(model: Model?): string
	if not model then
		return "Reiatsu"
	end
	local enemyId = model:GetAttribute("EnemyId")
	if enemyId then
		return "Hollow"
	end
	local power = Powers.get(model:GetAttribute("Power") :: string?)
	if power and model:GetAttribute("Form") ~= "Base" then
		return power.element
	end
	local faction = Factions.get(model:GetAttribute("Faction") :: string?)
	return faction and faction.element or "Reiatsu"
end

local function tween(
	instance: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end
VFX.tween = tween

local function neon(size: Vector3, cframe: CFrame, color: Color3, transparency: number?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end
VFX.neon = neon

-- ===================== EMISSORES COMPARTILHADOS =====================
local emitters: { [string]: ParticleEmitter } = {}

local function makeEmitter(name: string, props: { [string]: any }): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = anchor
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = attachment
	emitters[name] = e
	return e
end

local function emit(name: string, position: Vector3, color: Color3, count: number, direction: Vector3?)
	local e = emitters[name]
	if not e then
		return
	end
	if quality == "Low" then
		count = math.max(1, math.floor(count * 0.35))
	elseif quality == "Medium" then
		count = math.max(1, math.floor(count * 0.65))
	end
	local attachment = e.Parent :: Attachment
	if direction and direction.Magnitude > 0 then
		attachment.WorldCFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
	else
		attachment.WorldCFrame = CFrame.new(position)
	end
	e.Color = ColorSequence.new(color)
	e:Emit(count)
end
VFX.emit = emit

-- ===================== EFEITOS BÁSICOS =====================
function VFX.Flash(position: Vector3, color: Color3, size: number, duration: number?)
	local d = duration or 0.25
	local ball = neon(Vector3.one * size * 0.3, CFrame.new(position), color, 0.1, Enum.PartType.Ball)
	tween(ball, d, { Size = Vector3.one * size, Transparency = 1 })
	if quality ~= "Low" then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = size * 3
		light.Brightness = 3
		light.Parent = ball
		tween(light, d, { Brightness = 0 })
	end
	Debris:AddItem(ball, d + 0.05)
end

function VFX.Shockwave(position: Vector3, color: Color3, radius: number, duration: number?, thickness: number?)
	local d = duration or 0.4
	local ring = neon(
		Vector3.new(thickness or 0.4, 1, 1),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		0.2,
		Enum.PartType.Cylinder
	)
	tween(ring, d, { Size = Vector3.new(0.1, radius * 2, radius * 2), Transparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(ring, d + 0.05)
	if quality ~= "Low" then
		emit("Dust", position, Color3.fromRGB(200, 195, 185), math.floor(radius * 0.8))
	end
end

function VFX.Pillar(position: Vector3, color: Color3, radius: number, height: number, duration: number?)
	local d = duration or 0.6
	local pillar = neon(
		Vector3.new(height, radius * 0.3, radius * 0.3),
		CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		0.15,
		Enum.PartType.Cylinder
	)
	tween(pillar, d * 0.3, { Size = Vector3.new(height, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	task.delay(d * 0.3, function()
		tween(pillar, d * 0.7, { Size = Vector3.new(height * 1.1, 0.2, 0.2), Transparency = 1 })
	end)
	Debris:AddItem(pillar, d + 0.1)
end

-- Corte no ar: arco de lâminas finas no plano do golpe (meia-lua).
function VFX.SlashArc(
	cframe: CFrame,
	color: Color3,
	radius: number,
	thickness: number?,
	duration: number?,
	reverse: boolean?
)
	local d = duration or 0.22
	local segments = if quality == "Low" then 5 else 9
	local arc = math.rad(150)
	local model = Instance.new("Model")
	for i = 1, segments do
		local a = -arc / 2 + arc * (i - 0.5) / segments
		if reverse then
			a = -a
		end
		local taper = 1 - math.abs((i - 0.5) / segments - 0.5) * 1.6
		local length = radius * arc / segments * 1.15
		local cf = cframe * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
		local p = neon(Vector3.new(length, (thickness or 0.35) * taper, 0.15), cf, color, 0.05)
		p.Parent = model
	end
	model.Parent = folder
	for i, p in model:GetChildren() do
		local delayTime = (if reverse then segments - i else i) * d * 0.25 / segments
		local part = p :: BasePart
		part.Transparency = 1
		task.delay(delayTime, function()
			part.Transparency = 0.05
			tween(part, d, { Transparency = 1, Size = part.Size * Vector3.new(1.1, 0.2, 1) })
		end)
	end
	Debris:AddItem(model, d * 1.5 + 0.1)
end

function VFX.Sparks(position: Vector3, color: Color3, count: number, direction: Vector3?)
	emit("Spark", position, color, count, direction)
end

-- Número de dano flutuante
local damagePool
function VFX.DamageNumber(position: Vector3, amount: number, kind: string?)
	local gui = damagePool:Get() :: BillboardGui
	local label = gui:FindFirstChild("Label") :: TextLabel
	local holder = gui.Adornee :: BasePart
	holder.CFrame =
		CFrame.new(position + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1), rng:NextNumber(-1, 1)))
	local text = if amount >= 10 then tostring(math.floor(amount + 0.5)) else string.format("%.1f", amount)
	local color = Color3.fromRGB(255, 255, 255)
	local size = 28
	if kind == "Blocked" then
		color = Color3.fromRGB(150, 170, 200)
		size = 20
	elseif kind == "Heavy" then
		color = Color3.fromRGB(255, 200, 70)
		size = 38
	elseif kind == "Counter" then
		color = Color3.fromRGB(255, 90, 90)
		size = 40
		text = text .. "!"
	elseif kind == "Self" then
		color = Color3.fromRGB(255, 80, 80)
	end
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.2
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.Enabled = true
	label.Size = UDim2.fromScale(1.4, 1.4)
	tween(label, 0.12, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
	tween(gui, 0.8, { StudsOffset = Vector3.new(0, 4.5, 0) })
	task.delay(0.45, function()
		tween(label, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(0.85, function()
		gui.Enabled = false
		damagePool:Release(gui)
	end)
end

-- Imagem residual do personagem (dash/shunpo)
function VFX.Afterimage(model: Model, color: Color3, duration: number?)
	if quality == "Low" then
		return
	end
	local d = duration or 0.35
	local ghost = Instance.new("Model")
	for _, part in model:GetDescendants() do
		if
			part:IsA("BasePart")
			and part.Transparency < 0.9
			and part.Name ~= "HumanoidRootPart"
			and part.Size.Magnitude < 8
		then
			local p = neon(part.Size, part.CFrame, color, 0.45)
			p.Material = Enum.Material.ForceField
			p.Parent = ghost
			tween(p, d, { Transparency = 1 })
		end
	end
	ghost.Parent = folder
	Debris:AddItem(ghost, d + 0.05)
end

-- Rastro da arma: Trail entre TrailTop/TrailBottom, ligado por `duration`
function VFX.WeaponTrail(model: Model, color: Color3, duration: number)
	for _, weapon in model:GetChildren() do
		if weapon.Name == "Weapon" and weapon:IsA("Model") then
			local host = weapon:FindFirstChild("TrailHost")
			if host then
				local trail = host:FindFirstChild("SwordTrail") :: Trail?
				if not trail then
					local t = Instance.new("Trail")
					t.Name = "SwordTrail"
					t.Attachment0 = host:FindFirstChild("TrailTop") :: Attachment
					t.Attachment1 = host:FindFirstChild("TrailBottom") :: Attachment
					t.Lifetime = 0.16
					t.MinLength = 0
					t.LightEmission = 1
					t.FaceCamera = false
					t.Transparency =
						NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
					t.WidthScale =
						NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) })
					t.Parent = host
					trail = t
				end
				local tr = trail :: Trail
				tr.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
				tr.Enabled = true
				local token = (tr:GetAttribute("Token") or 0) + 1
				tr:SetAttribute("Token", token)
				task.delay(duration, function()
					if tr:GetAttribute("Token") == token then
						tr.Enabled = false
					end
				end)
			end
		end
	end
end

-- Linhas de velocidade na tela (dash)
local speedLines: ScreenGui
function VFX.SpeedLines(duration: number)
	if quality == "Low" then
		return
	end
	for _ = 1, 14 do
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BackgroundTransparency = 0.35
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.32, 0.45)
		line.Position = UDim2.fromScale(0.5 + math.cos(angle) * r, 0.5 + math.sin(angle) * r)
		line.Size = UDim2.fromOffset(rng:NextInteger(80, 180), 2)
		line.Rotation = math.deg(angle)
		line.Parent = speedLines
		tween(line, duration, {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5 + math.cos(angle) * (r + 0.15), 0.5 + math.sin(angle) * (r + 0.15)),
		})
		Debris:AddItem(line, duration + 0.05)
	end
end

-- Clarão de tela (impactos fortes, transformações)
function VFX.ScreenFlash(color: Color3, duration: number, alpha: number?)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1 - (alpha or 0.5)
	f.BorderSizePixel = 0
	f.Parent = speedLines
	tween(f, duration, { BackgroundTransparency = 1 })
	Debris:AddItem(f, duration + 0.05)
end

-- ===================== AURAS =====================
local auras: { [Model]: { emitter: ParticleEmitter, light: PointLight, key: string } } = {}

local function auraKey(model: Model): string?
	local form = model:GetAttribute("Form")
	local mask = model:GetAttribute("Mask")
	local charging = model:GetAttribute("Charging")
	if mask then
		return "Mask"
	end
	if form == "Tier2" then
		return "Tier2"
	end
	if form == "Tier1" then
		return "Tier1"
	end
	if charging then
		return "Charge"
	end
	return nil
end

function VFX.UpdateAura(model: Model)
	local key = auraKey(model)
	local current = auras[model]
	if current and current.key == key then
		return
	end
	if current then
		current.emitter.Enabled = false
		Debris:AddItem(current.emitter, 2)
		current.light:Destroy()
		auras[model] = nil
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not key or not root then
		return
	end
	local element = if key == "Mask" then "Hollow" else VFX.ElementOf(model)
	local color = VFX.Color(element)
	local e = Instance.new("ParticleEmitter")
	e.Texture = if element == "Fire" then FIRE else SPARK
	e.Color = ColorSequence.new(color, VFX.Secondary(element))
	e.LightEmission = 1
	e.Rate = (if key == "Tier2" then 60 elseif key == "Charge" then 45 else 28) * (if quality == "Low" then 0.3 else 1)
	e.Lifetime = NumberRange.new(0.5, 1.1)
	e.Speed = NumberRange.new(3, 8)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, 10, 0)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if key == "Tier2" then 1.6 else 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.EmissionDirection = Enum.NormalId.Top
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = root
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = if key == "Tier2" then 16 else 10
	light.Brightness = 1.5
	light.Parent = root
	auras[model] = { emitter = e, light = light, key = key }
end

-- ===================== PROJÉTEIS / FEIXES =====================
type ProjectileVisual = {
	model: Model,
	origin: Vector3,
	direction: Vector3,
	speed: number,
	range: number,
	start: number,
	spin: number,
}
local projectiles: { [number]: ProjectileVisual } = {}

local function buildProjectile(shape: string, size: number, color: Color3, secondary: Color3): Model
	local model = Instance.new("Model")
	local s = size
	if shape == "Crescent" then
		local segments = 9
		local arc = math.rad(140)
		local radius = 3.2 * s
		for i = 1, segments do
			local a = -arc / 2 + arc * (i - 0.5) / segments
			local taper = 1 - math.abs((i - 0.5) / segments - 0.5) * 1.5
			local p = neon(
				Vector3.new(radius * arc / segments * 1.2, 0.5 * s * taper, 0.6 * s * taper),
				CFrame.Angles(0, 0, a) * CFrame.new(0, radius, 0) * CFrame.Angles(math.pi / 2, 0, 0),
				if i % 2 == 0 then color else secondary:Lerp(color, 0.5),
				0.05
			)
			p.Parent = model
		end
	elseif shape == "Arrow" then
		local shaft = neon(Vector3.new(0.25 * s, 0.25 * s, 5 * s), CFrame.identity, color, 0)
		shaft.Parent = model
		local head = neon(
			Vector3.new(0.6 * s, 0.6 * s, 1.2 * s),
			CFrame.new(0, 0, -2.8 * s) * CFrame.Angles(0, 0, math.rad(45)),
			secondary,
			0
		)
		head.Parent = model
	elseif shape == "Bolt" then
		local core = neon(Vector3.new(0.4 * s, 0.4 * s, 4 * s), CFrame.identity, Color3.new(1, 1, 1), 0)
		core.Parent = model
		local glow = neon(Vector3.new(1.1 * s, 1.1 * s, 4.6 * s), CFrame.identity, color, 0.5)
		glow.Parent = model
	elseif shape == "Shard" then
		local shard = neon(Vector3.new(0.5 * s, 0.5 * s, 3 * s), CFrame.Angles(0, 0, math.rad(45)), color, 0.1)
		shard.Material = Enum.Material.Glass
		shard.Parent = model
		local core = neon(Vector3.new(0.2 * s, 0.2 * s, 2.6 * s), CFrame.identity, secondary, 0)
		core.Parent = model
	else -- Orb
		local orb = neon(Vector3.one * 2 * s, CFrame.identity, color, 0.15, Enum.PartType.Ball)
		orb.Parent = model
		local core = neon(Vector3.one * 1.1 * s, CFrame.identity, Color3.new(1, 1, 1), 0, Enum.PartType.Ball)
		core.Parent = model
	end
	local first = model:FindFirstChildWhichIsA("BasePart")
	if first and quality ~= "Low" then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10 * s
		light.Brightness = 2
		light.Parent = first
	end
	-- Rastro de luz atrás do projétil
	if first and quality ~= "Low" then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.9 * s, 0)
		a0.Parent = first
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.9 * s, 0)
		a1.Parent = first
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		trail.LightEmission = 1
		trail.Lifetime = 0.25
		trail.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
		trail.FaceCamera = true
		trail.Parent = first
	end
	-- Guarda offsets relativos para mover como corpo rígido
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			p:SetAttribute("Offset", p.CFrame)
		end
	end
	model.Parent = folder
	return model
end

function VFX.SpawnProjectile(data: { [string]: any })
	local color = VFX.Color(data.element)
	local model = buildProjectile(data.shape or "Orb", data.size or 1, color, VFX.Secondary(data.element))
	projectiles[data.id] = {
		model = model,
		origin = data.origin,
		direction = data.direction,
		speed = data.speed,
		range = data.range,
		start = os.clock(),
		spin = if data.shape == "Shard" or data.shape == "Arrow" then 0 else 0,
	}
	Debris:AddItem(model, data.range / data.speed + 1)
end

function VFX.EndProjectile(data: { [string]: any })
	local p = projectiles[data.id]
	if p then
		projectiles[data.id] = nil
		p.model:Destroy()
	end
	local color = VFX.Color(data.element)
	if data.explode then
		VFX.Flash(data.position, color, data.explode * 1.2, 0.35)
		VFX.Shockwave(data.position - Vector3.new(0, 1.5, 0), color, data.explode, 0.4)
		VFX.Sparks(data.position, color, 24)
	else
		VFX.Flash(data.position, color, 5, 0.18)
		VFX.Sparks(data.position, color, 8)
	end
end

function VFX.Beam(data: { [string]: any })
	local color = VFX.Color(data.element)
	local secondary = VFX.Secondary(data.element)
	local origin: Vector3 = data.origin
	local dir: Vector3 = data.direction
	local length: number = data.length
	local radius: number = data.radius
	local center = origin + dir * (length / 2)
	local frame = CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.rad(90), 0)
	local outer = neon(Vector3.new(length, radius * 0.4, radius * 0.4), frame, color, 0.25, Enum.PartType.Cylinder)
	local inner = neon(
		Vector3.new(length, radius * 0.2, radius * 0.2),
		frame,
		if data.shape == "Cero" then secondary:Lerp(Color3.new(1, 1, 1), 0.3) else Color3.new(1, 1, 1),
		0,
		Enum.PartType.Cylinder
	)
	tween(outer, 0.08, { Size = Vector3.new(length, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	tween(inner, 0.08, { Size = Vector3.new(length, radius, radius) }, Enum.EasingStyle.Back)
	VFX.Flash(origin, color, radius * 3, 0.3)
	local duration = data.duration or 0.5
	-- Raio: segmentos irregulares
	if data.shape == "Lightning" and quality ~= "Low" then
		for _ = 1, 3 do
			local last = origin
			local steps = 8
			for s = 1, steps do
				local target = origin
					+ dir * (length * s / steps)
					+ Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
						* radius
						* 0.8
				local mid = (last + target) / 2
				local seg =
					neon(Vector3.new(0.25, 0.25, (target - last).Magnitude), CFrame.lookAt(mid, target), color, 0)
				tween(seg, duration * 0.6, { Transparency = 1 })
				Debris:AddItem(seg, duration)
				last = target
			end
		end
	end
	task.delay(duration * 0.7, function()
		tween(outer, duration * 0.3, { Size = Vector3.new(length, 0.1, 0.1), Transparency = 1 })
		tween(inner, duration * 0.3, { Size = Vector3.new(length, 0.05, 0.05), Transparency = 1 })
	end)
	Debris:AddItem(outer, duration + 0.1)
	Debris:AddItem(inner, duration + 0.1)
	VFX.Sparks(origin + dir * length, color, 20, -dir)
end

-- Explosão em área (Burst) com pulsos
function VFX.Burst(data: { [string]: any }, follow: BasePart?)
	local color = VFX.Color(data.element)
	local center: Vector3 = data.center
	local radius: number = data.radius
	if data.delay and data.delay > 0 then
		-- Marcação no chão antes do impacto
		local marker = neon(
			Vector3.new(0.2, radius * 2, radius * 2),
			CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			color,
			0.75,
			Enum.PartType.Cylinder
		)
		tween(marker, data.delay, { Transparency = 0.45 })
		Debris:AddItem(marker, data.delay + 0.05)
		task.wait(data.delay)
	end
	for tick = 1, data.ticks or 1 do
		local c = if follow then follow.Position - Vector3.new(0, 2.5, 0) else center
		VFX.Shockwave(c + Vector3.new(0, 0.5, 0), color, radius, 0.45)
		if tick == 1 or data.ultimate then
			VFX.Pillar(c, color, radius * (if data.ultimate then 0.6 else 0.35), if data.ultimate then 60 else 22, 0.6)
			VFX.Flash(c + Vector3.new(0, 3, 0), color, radius * 0.8, 0.3)
		end
		VFX.Sparks(c + Vector3.new(0, 2, 0), color, if data.ultimate then 40 else 18)
		if tick < (data.ticks or 1) then
			task.wait(data.interval or 0.2)
		end
	end
end

-- Chuva de projéteis
function VFX.Rain(data: { [string]: any })
	local color = VFX.Color(data.element)
	local center: Vector3 = data.center
	local radius: number = data.radius
	local marker = neon(
		Vector3.new(0.2, radius * 2, radius * 2),
		CFrame.new(center + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		0.6,
		Enum.PartType.Cylinder
	)
	Debris:AddItem(marker, 0.25 + data.ticks * data.interval + 0.3)
	task.wait(0.15)
	local perTick = if quality == "Low" then 2 else if data.ultimate then 7 else 4
	for _ = 1, data.ticks do
		for _ = 1, perTick do
			local angle = rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rng:NextNumber()) * radius
			local hit = center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
			local top = hit + Vector3.new(rng:NextNumber(-6, 6), 45, rng:NextNumber(-6, 6))
			local streak = neon(Vector3.new(0.4, 0.4, 7), CFrame.lookAt(top, hit), color, 0.05)
			tween(streak, 0.12, { CFrame = CFrame.lookAt(hit, hit + (hit - top).Unit) }, Enum.EasingStyle.Linear)
			Debris:AddItem(streak, 0.14)
			task.delay(0.12, function()
				VFX.Flash(hit, color, 4, 0.2)
				VFX.Sparks(hit, color, 5)
			end)
		end
		task.wait(data.interval)
	end
	tween(marker, 0.3, { Transparency = 1 })
end

-- ===================== INIT =====================
function VFX.Init()
	folder = Instance.new("Folder")
	folder.Name = "ClientVFX"
	folder.Parent = workspace
	anchor = Instance.new("Part")
	anchor.Name = "VFXAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.identity
	anchor.Parent = folder

	makeEmitter("Spark", {
		Texture = SPARK,
		LightEmission = 1,
		Lifetime = NumberRange.new(0.2, 0.45),
		Speed = NumberRange.new(25, 55),
		SpreadAngle = Vector2.new(70, 70),
		Drag = 6,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0),
		Acceleration = Vector3.new(0, -40, 0),
	})
	makeEmitter("Dust", {
		Texture = SMOKE,
		LightEmission = 0,
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(10, 22),
		SpreadAngle = Vector2.new(180, 10),
		Drag = 4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
	})
	makeEmitter("Wisp", {
		Texture = SPARK,
		LightEmission = 1,
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(4, 12),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 2,
		Acceleration = Vector3.new(0, 8, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
	})

	damagePool = Pool.new({
		max = 40,
		create = function()
			local holder = Instance.new("Part")
			holder.Anchored = true
			holder.CanCollide = false
			holder.CanQuery = false
			holder.CanTouch = false
			holder.Transparency = 1
			holder.Size = Vector3.one * 0.1
			holder.Parent = folder
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(120, 50)
			gui.AlwaysOnTop = true
			gui.LightInfluence = 0
			gui.MaxDistance = 150
			gui.Adornee = holder
			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromScale(0.5, 0.5)
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.Bangers
			label.TextStrokeColor3 = Color3.new(0, 0, 0)
			label.Parent = gui
			gui.Parent = holder
			return gui
		end,
	})

	speedLines = Instance.new("ScreenGui")
	speedLines.Name = "ScreenFx"
	speedLines.IgnoreGuiInset = true
	speedLines.ResetOnSpawn = false
	speedLines.DisplayOrder = 5
	speedLines.Parent = player:WaitForChild("PlayerGui")
end

function VFX.Start()
	-- Auras reagem a atributos (forma, máscara, carga)
	local function watch(model: Instance)
		if not model:IsA("Model") then
			return
		end
		for _, attr in { "Form", "Mask", "Charging", "Power" } do
			model:GetAttributeChangedSignal(attr):Connect(function()
				VFX.UpdateAura(model)
			end)
		end
		VFX.UpdateAura(model)
		model.AncestryChanged:Connect(function(_, parent)
			if parent == nil and auras[model] then
				auras[model] = nil
			end
		end)
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
	task.spawn(function()
		local bosses = workspace:WaitForChild("Bosses")
		bosses.ChildAdded:Connect(function(child)
			task.defer(watch, child)
		end)
	end)

	-- Movimento dos projéteis visuais (mesma trajetória simulada pelo servidor)
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for id, p in projectiles do
			local distance = (now - p.start) * p.speed
			if distance > p.range + 5 then
				projectiles[id] = nil
				p.model:Destroy()
			else
				local cf = CFrame.lookAt(p.origin + p.direction * distance, p.origin + p.direction * (distance + 1))
				for _, part in p.model:GetChildren() do
					if part:IsA("BasePart") then
						part.CFrame = cf * (part:GetAttribute("Offset") :: CFrame)
					end
				end
			end
		end
	end)
end

return VFX

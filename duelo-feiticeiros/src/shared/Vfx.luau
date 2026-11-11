-- EFEITOS da cinemática (locais, no cliente). Texturas: só as embutidas no Roblox (rbxasset://).
-- Tudo some sozinho; a pasta "CinematicFx" guarda as peças.

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Vfx = {}

local V = Vector3.new
local CF = CFrame.new
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local TEX = {
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
}

local folder: Folder? = nil
local function root(): Folder
	if not folder or not folder.Parent then
		local f = Instance.new("Folder")
		f.Name = "CinematicFx"
		f.Parent = workspace
		folder = f
	end
	return folder :: Folder
end

local function tween(inst: Instance, time: number, goal, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
Vfx.tween = tween

function Vfx.part(props, life: number)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = root()
	task.delay(life, function()
		p:Destroy()
	end)
	return p
end

local function seq(...)
	local pts, a = {}, { ... }
	for i = 1, #a, 2 do
		table.insert(pts, NumberSequenceKeypoint.new(a[i], a[i + 1]))
	end
	return NumberSequence.new(pts)
end

function Vfx.emit(at: Vector3, cfg, count: number, life: number?)
	local a = Vfx.part({ Size = V(0.2, 0.2, 0.2), CFrame = CF(at), Transparency = 1 }, life or 3)
	local e = Instance.new("ParticleEmitter")
	e.Texture = cfg.tex or TEX.spark
	e.Color = ColorSequence.new(cfg.c0 or WHITE, cfg.c1 or WHITE)
	e.LightEmission = cfg.glow or 1
	e.LightInfluence = 0
	e.Size = cfg.size or seq(0, 0.6, 1, 0)
	e.Transparency = cfg.transparency or seq(0, 0, 1, 1)
	e.Speed = NumberRange.new(cfg.speed and cfg.speed[1] or 6, cfg.speed and cfg.speed[2] or 16)
	e.Lifetime = NumberRange.new(cfg.lifeR and cfg.lifeR[1] or 0.3, cfg.lifeR and cfg.lifeR[2] or 0.8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = cfg.accel or Vector3.zero
	e.Drag = cfg.drag or 2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	if cfg.orient then
		e.Orientation = cfg.orient
	end
	e.Rate = cfg.rate or 0
	e.Parent = a
	if count > 0 then
		e:Emit(count)
	end
	return e, a
end

function Vfx.flash(at: Vector3, color: Color3, range: number, brightness: number, time: number)
	local a = Vfx.part({ Size = V(0.2, 0.2, 0.2), CFrame = CF(at), Transparency = 1 }, time + 0.1)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness, false
	l.Parent = a
	tween(l, time, { Brightness = 0 })
end

-- Faíscas + clarão + aro: o "pá!" de um golpe acertando.
function Vfx.impact(at: Vector3, color: Color3, power: number)
	Vfx.emit(at, { c0 = WHITE, c1 = color, size = seq(0, 0.35 * power, 1, 0), speed = { 18 * power, 40 * power }, lifeR = { 0.15, 0.4 },
		orient = Enum.ParticleOrientation.VelocityParallel, accel = V(0, -30, 0) }, math.floor(18 * power))
	Vfx.emit(at, { tex = TEX.smoke, c0 = color:Lerp(WHITE, 0.4), c1 = color, glow = 0.6, size = seq(0, 1.5 * power, 1, 5 * power), transparency = seq(0, 0.3, 1, 1),
		speed = { 4, 10 }, lifeR = { 0.3, 0.6 } }, 6)
	Vfx.flash(at, color, 18 + power * 10, 4 + power * 2, 0.3)
	Vfx.shock(at, 6 + power * 6, color, 0.3, CFrame.Angles(math.random() * 0.6, math.random() * 6, math.random() * 0.6))
end

-- Onda de choque: aro que se expande e some (pode ser inclinado).
function Vfx.shock(at: Vector3, radius: number, color: Color3, time: number, tilt: CFrame?)
	local ring = Vfx.part({ Shape = Enum.PartType.Cylinder, Size = V(0.25, 1, 1), CFrame = CF(at) * (tilt or CFrame.identity) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color, Transparency = 0.2 }, time + 0.05)
	tween(ring, time, { Size = V(0.05, radius * 2, radius * 2), Transparency = 1 })
end

-- Esfera de energia que cresce na mão (preparação de técnica).
function Vfx.orb(attach: BasePart, color: Color3, size: number, time: number)
	local orb = Vfx.part({ Shape = Enum.PartType.Ball, Size = V(0.2, 0.2, 0.2), CFrame = attach.CFrame, Color = WHITE:Lerp(color, 0.25) }, time + 0.1)
	local glow = Vfx.part({ Shape = Enum.PartType.Ball, Size = V(0.4, 0.4, 0.4), CFrame = attach.CFrame, Color = color, Transparency = 0.6, Material = Enum.Material.ForceField }, time + 0.1)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, 4, 1, false
	l.Parent = orb
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < time and orb.Parent and attach.Parent do
			local k = (os.clock() - t0) / time
			local s = size * (0.2 + 0.8 * k) * (1 + 0.08 * math.sin(os.clock() * 40))
			orb.Size = V(s, s, s)
			glow.Size = V(s * 1.9, s * 1.9, s * 1.9)
			orb.CFrame = attach.CFrame
			glow.CFrame = attach.CFrame
			l.Range = 6 + 14 * k
			l.Brightness = 1 + 4 * k
			task.wait()
		end
	end)
	Vfx.emit(attach.Position, { c0 = WHITE, c1 = color, size = seq(0, 0.25, 1, 0), speed = { 2, 6 }, lifeR = { 0.4, 0.8 }, rate = 60 }, 0, time)
	return orb
end

-- Raio em zigue-zague com ramos.
function Vfx.lightning(from: Vector3, to: Vector3, color: Color3, width: number, life: number)
	local n = 9
	local prev = from
	local dir = to - from
	for i = 1, n do
		local k = i / n
		local nxt = from + dir * k
		if i < n then
			nxt += V(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * dir.Magnitude * 0.08
		end
		local seg = nxt - prev
		local p = Vfx.part({ Size = V(width, width, seg.Magnitude), CFrame = CFrame.lookAt(prev + seg / 2, nxt), Color = WHITE:Lerp(color, 0.3) }, life)
		tween(p, life, { Transparency = 1, Size = V(width * 0.2, width * 0.2, seg.Magnitude) })
		if math.random() < 0.35 then
			local b = nxt + V(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * dir.Magnitude * 0.15
			local bs = b - nxt
			local bp = Vfx.part({ Size = V(width * 0.5, width * 0.5, bs.Magnitude), CFrame = CFrame.lookAt(nxt + bs / 2, b), Color = color }, life * 0.8)
			tween(bp, life * 0.8, { Transparency = 1 })
		end
		prev = nxt
	end
	Vfx.flash(to, color, 40, 6, life)
end

-- Feixe grosso (lança/rajada) que se estica até o alvo, com núcleo branco.
function Vfx.beam(from: Vector3, to: Vector3, color: Color3, width: number, life: number)
	local d = to - from
	local core = Vfx.part({ Shape = Enum.PartType.Cylinder, Size = V(0.1, width * 0.5, width * 0.5), CFrame = CFrame.lookAt(from, to) * CFrame.Angles(0, math.rad(90), 0),
		Color = WHITE }, life + 0.1)
	local shell = Vfx.part({ Shape = Enum.PartType.Cylinder, Size = V(0.1, width, width), CFrame = core.CFrame, Color = color, Transparency = 0.35 }, life + 0.1)
	for _, p in ipairs({ core, shell }) do
		local mid = CFrame.lookAt(from + d / 2, to) * CFrame.Angles(0, math.rad(90), 0)
		tween(p, 0.12, { Size = V(d.Magnitude, p.Size.Y, p.Size.Z), CFrame = mid })
		task.delay(life * 0.6, function()
			if p.Parent then
				tween(p, life * 0.4, { Size = V(d.Magnitude, 0.05, 0.05), Transparency = 1 })
			end
		end)
	end
end

-- Corte de tinta carmesim: lâmina fina e comprida (borda vermelha, miolo preto) que voa e some.
function Vfx.inkSlash(center: Vector3, dir: Vector3, length: number, color: Color3, life: number, roll: number?)
	local look = CFrame.lookAt(center, center + dir) * CFrame.Angles(0, 0, roll or 0)
	local blade = Vfx.part({ Size = V(length, 0.35, 0.12), CFrame = look * CFrame.Angles(0, math.rad(90), 0), Color = color }, life + 0.1)
	local ink = Vfx.part({ Size = V(length * 0.9, 0.16, 0.14), CFrame = blade.CFrame, Color = BLACK, Material = Enum.Material.SmoothPlastic }, life + 0.1)
	for _, p in ipairs({ blade, ink }) do
		tween(p, life, { CFrame = p.CFrame + dir.Unit * length * 1.4, Transparency = 1 }, Enum.EasingStyle.Quint)
	end
	Vfx.emit(center, { c0 = color, c1 = BLACK, glow = 0.3, size = seq(0, 0.5, 1, 0), speed = { 4, 12 }, lifeR = { 0.3, 0.7 }, accel = V(0, -20, 0) }, 10)
end

-- Pedaço de prédio cortado: um bloco que escorrega e cai (com poeira).
function Vfx.cutChunk(at: Vector3, size: Vector3, color: Color3, slideDir: Vector3)
	local p = Vfx.part({ Size = size, CFrame = CF(at), Color = color, Material = Enum.Material.Concrete, Transparency = 0 }, 4)
	p.Anchored = false
	p.CanCollide = true
	p.AssemblyLinearVelocity = slideDir * 18 + V(0, 4, 0)
	p.AssemblyAngularVelocity = V(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2
	local line = Vfx.part({ Size = V(size.X * 1.05, 0.12, size.Z * 1.05), CFrame = CF(at - V(0, size.Y / 2, 0)), Color = Color3.fromRGB(255, 40, 60) }, 0.8)
	tween(line, 0.8, { Transparency = 1 })
	Vfx.emit(at - V(0, size.Y / 2, 0), { tex = TEX.smoke, c0 = Color3.fromRGB(120, 116, 120), c1 = Color3.fromRGB(70, 68, 74), glow = 0, size = seq(0, 3, 1, 9),
		transparency = seq(0, 0.3, 1, 1), speed = { 4, 10 }, lifeR = { 1, 2 } }, 14)
end

-- Cúpula de técnica de arena: esfera que cresce a partir de um ponto e fica.
function Vfx.dome(at: Vector3, color: Color3, radius: number, time: number, life: number, material: Enum.Material?)
	local s = Vfx.part({ Shape = Enum.PartType.Ball, Size = V(1, 1, 1), CFrame = CF(at), Color = color, Transparency = 0.15,
		Material = material or Enum.Material.ForceField }, life)
	tween(s, time, { Size = V(radius * 2, radius * 2, radius * 2) }, Enum.EasingStyle.Quint)
	task.delay(life - 0.6, function()
		if s.Parent then
			tween(s, 0.5, { Transparency = 1 })
		end
	end)
	return s
end

-- Pedrinhas voando.
function Vfx.debris(at: Vector3, color: Color3, count: number, power: number)
	for _ = 1, count do
		local sz = 0.4 + math.random() * 0.8
		local p = Vfx.part({ Size = V(sz, sz * 0.7, sz), CFrame = CF(at) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Color = color,
			Material = Enum.Material.Slate }, 2.5)
		p.Anchored = false
		p.CanCollide = true
		local a = math.random() * math.pi * 2
		p.AssemblyLinearVelocity = V(math.cos(a) * power * (0.4 + math.random() * 0.6), power * (0.5 + math.random() * 0.6), math.sin(a) * power * (0.4 + math.random() * 0.6))
	end
end

-- QUADRO DE IMPACTO (estilo anime): a imagem vira duas cores (preto e branco + tinta forte) por um instante.
local function cc(name: string): ColorCorrectionEffect
	local e = Lighting:FindFirstChild(name) :: ColorCorrectionEffect?
	if not e then
		local n = Instance.new("ColorCorrectionEffect")
		n.Name = name
		n.Parent = Lighting
		e = n
	end
	return e :: ColorCorrectionEffect
end
function Vfx.impactFrame(tint: Color3, time: number)
	local e = cc("ImpactFrame")
	e.Saturation = -1
	e.Contrast = 1.2
	e.Brightness = 0.12
	e.TintColor = tint
	task.delay(time, function()
		e.Saturation, e.Contrast, e.Brightness, e.TintColor = 0, 0, 0, WHITE
	end)
end

-- Clima do mundo durante as técnicas de arena (cor da imagem fica até `clearWorld`).
function Vfx.worldTone(tint: Color3, saturation: number, contrast: number)
	local e = cc("WorldTone")
	tween(e, 0.4, { TintColor = tint, Saturation = saturation, Contrast = contrast })
end
function Vfx.clearWorld()
	local e = cc("WorldTone")
	tween(e, 0.6, { TintColor = WHITE, Saturation = 0, Contrast = 0 })
	local f = cc("ImpactFrame")
	f.Saturation, f.Contrast, f.Brightness, f.TintColor = 0, 0, 0, WHITE
end

function Vfx.cleanup()
	if folder then
		folder:Destroy()
		folder = nil
	end
	Vfx.clearWorld()
end

return Vfx

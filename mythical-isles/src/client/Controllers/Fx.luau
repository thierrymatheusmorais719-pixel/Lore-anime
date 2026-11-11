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
local PetMesh = require(Shared.Builders.PetMesh)
local UIKit = require(script.Parent.UIKit)
local CreatureMotion = require(script.Parent.CreatureMotion)
local State = require(script.Parent.State)

local Fx = {}

local player = Players.LocalPlayer
local folder: Folder
local debrisFolder: Folder -- fragmentos com física (peças dentro da Camera não são simuladas)
local activeParts = 0
local MAX_PARTS = 220 -- (a encenação dos poderes usa ~20 peças por lançamento)
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

-------------------------------------------------------------------------------
-- Blocos de VFX "realistas": tudo em camadas (clarão de luz + faíscas + brasas + fumaça/poeira +
-- fragmentos com física + tremor de câmera). Texturas: só as embutidas no cliente Roblox.
-------------------------------------------------------------------------------

local TEX = {
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
}
local WHITE = Color3.new(1, 1, 1)
local DUST = Color3.fromRGB(150, 132, 108)

local function seq(...)
	local pts = {}
	local args = { ... }
	for i = 1, #args, 2 do
		table.insert(pts, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(pts)
end

local function scaled(n: number): number
	return lowVfx() and math.max(1, math.ceil(n * 0.4)) or n
end

-- Peça invisível que segura emissores/luzes e se apaga sozinha.
local function anchorAt(pos: Vector3, life: number)
	return part({ Size = Vector3.one * 0.2, CFrame = CFrame.new(pos), Transparency = 1 }, life)
end

local function emit(anchor: BasePart, cfg, count: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = cfg.tex or TEX.spark
	e.Color = cfg.color
	e.LightEmission = cfg.emission or 0
	e.LightInfluence = cfg.influence or ((cfg.emission or 0) > 0.5 and 0 or 1)
	e.Size = cfg.size
	e.Transparency = cfg.transparency or seq(0, 0, 1, 1)
	e.Speed = cfg.speed
	e.Lifetime = cfg.life
	e.SpreadAngle = cfg.spread or Vector2.new(180, 180)
	e.EmissionDirection = cfg.dir or Enum.NormalId.Top
	e.Acceleration = cfg.accel or Vector3.zero
	e.Drag = cfg.drag or 0
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = cfg.rot or NumberRange.new(-60, 60)
	if cfg.orient then
		e.Orientation = cfg.orient
	end
	if cfg.squash then
		e.Squash = cfg.squash
	end
	e.ZOffset = cfg.z or 0
	e.Rate = cfg.rate or 0
	e.Parent = anchor
	if count > 0 then
		e:Emit(scaled(count))
	end
	return e
end

-- Clarão: luz que acende e se apaga (ilumina o chão e as criaturas em volta).
local function flash(pos: Vector3, color: Color3, range: number, brightness: number, time: number)
	local a = anchorAt(pos, time + 0.05)
	if not a then
		return
	end
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = a
	tween(l, time, { Brightness = 0 })
end

-- Faíscas alongadas na direção do movimento, caindo com a gravidade.
local function sparks(at: Vector3, color: Color3, count: number, speed: number?)
	local a = anchorAt(at, 1.2)
	if not a then
		return
	end
	local sp = speed or 14
	emit(a, { color = ColorSequence.new(WHITE, color), emission = 1, size = seq(0, 0.28, 1, 0), speed = NumberRange.new(sp * 0.5, sp),
		life = NumberRange.new(0.25, 0.55), accel = Vector3.new(0, -40, 0), drag = 2.5, orient = Enum.ParticleOrientation.VelocityParallel,
		squash = seq(0, -1.2, 1, -0.6), z = 1 }, count)
end

-- Brasas/centelhas mágicas que sobem devagar e piscam.
local function embers(at: Vector3, color: Color3, count: number, radius: number?)
	local a = anchorAt(at, 2.4)
	if not a then
		return
	end
	a.Size = Vector3.new(radius or 2, 0.5, radius or 2)
	emit(a, { color = ColorSequence.new(color:Lerp(WHITE, 0.4), color), emission = 1, size = seq(0, 0, 0.2, 0.32, 1, 0), speed = NumberRange.new(1, 4),
		life = NumberRange.new(0.8, 1.8), accel = Vector3.new(0, 5, 0), drag = 1.5, transparency = seq(0, 1, 0.15, 0, 1, 1) }, count)
end

-- Poeira/fumaça: nuvens que crescem, se espalham rente ao chão e somem.
local function dust(at: Vector3, color: Color3?, count: number, size: number?, speed: number?)
	local a = anchorAt(at, 2.6)
	if not a then
		return
	end
	local sz = size or 3
	emit(a, { tex = TEX.smoke, color = ColorSequence.new(color or DUST), emission = 0, influence = 1, size = seq(0, sz * 0.4, 1, sz * 1.6),
		transparency = seq(0, 0.45, 0.6, 0.7, 1, 1), speed = NumberRange.new((speed or 10) * 0.4, speed or 10), life = NumberRange.new(0.9, 1.8),
		spread = Vector2.new(85, 85), accel = Vector3.new(0, 1.5, 0), drag = 3.5, rot = NumberRange.new(-25, 25) }, count)
end

-- Bola de fogo/energia: núcleo brilhante que incha e se dissipa, com fumaça escura subindo.
local function fireball(at: Vector3, color: Color3, scale: number)
	local a = anchorAt(at, 2.2)
	if not a then
		return
	end
	emit(a, { tex = TEX.fire, color = ColorSequence.new(WHITE:Lerp(color, 0.3), color), emission = 1, size = seq(0, scale * 0.6, 0.4, scale * 1.6, 1, scale * 2),
		transparency = seq(0, 0.1, 0.7, 0.5, 1, 1), speed = NumberRange.new(scale * 1.5, scale * 4), life = NumberRange.new(0.35, 0.6), drag = 4 }, 14)
	emit(a, { tex = TEX.smoke, color = ColorSequence.new(Color3.fromRGB(70, 62, 58)), size = seq(0, scale * 0.8, 1, scale * 2.6), transparency = seq(0, 0.5, 1, 1),
		speed = NumberRange.new(scale, scale * 2.5), life = NumberRange.new(1, 1.8), accel = Vector3.new(0, 4, 0), drag = 2 }, 8)
	flash(at, color, 14 + scale * 6, 4, 0.45)
end

-- Onda de choque: aro fino translúcido que se expande rente ao chão.
local function shockRing(at: Vector3, radius: number, color: Color3, time: number?)
	local t = time or 0.4
	local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1, 1), CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color, Transparency = 0.55 }, t + 0.05)
	if p then
		tween(p, t, { Size = Vector3.new(0.15, radius * 2, radius * 2), Transparency = 1 })
	end
end

-- Fragmentos com física (pedrinhas/lascas) que voam, quicam no chão e somem.
local function debris(at: Vector3, color: Color3, count: number, power: number?, material: Enum.Material?)
	for _ = 1, scaled(count) do
		local sz = 0.25 + math.random() * 0.45
		local p = part({ Size = Vector3.new(sz, sz * 0.7, sz * 1.1), CFrame = CFrame.new(at + Vector3.new(0, 0.6, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
			Color = color:Lerp(Color3.new(0, 0, 0), math.random() * 0.3), Material = material or Enum.Material.Slate, Anchored = false, CanCollide = true, CastShadow = true }, 1.8)
		if p then
			p.Parent = debrisFolder
			local a = math.random() * math.pi * 2
			local pw = power or 18
			p.AssemblyLinearVelocity = Vector3.new(math.cos(a) * pw * (0.3 + math.random() * 0.5), pw * (0.6 + math.random() * 0.5), math.sin(a) * pw * (0.3 + math.random() * 0.5))
			p.AssemblyAngularVelocity = Vector3.new(math.random() * 20 - 10, math.random() * 20 - 10, math.random() * 20 - 10)
			task.delay(1.2, function()
				if p.Parent then
					tween(p, 0.5, { Transparency = 1 })
				end
			end)
		end
	end
end

-- Tremor de câmera (só perto do impacto; mais fraco com "efeitos: baixa").
local shakeAmp, shakeUntil = 0, 0
local function shake(at: Vector3, power: number, time: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local k = math.clamp(1 - (cam.CFrame.Position - at).Magnitude / 110, 0, 1)
	if k <= 0 then
		return
	end
	shakeAmp = math.max(shakeAmp, power * k * (lowVfx() and 0.4 or 1))
	shakeUntil = math.max(shakeUntil, os.clock() + time)
end

-- Projétil com núcleo brilhante, rastro (Trail), partículas e luz. Chama onHit ao chegar.
local function projectile(from: Vector3, to: Vector3, color: Color3, travel: number, size: number, style: string, onHit)
	local p = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.55, CFrame = CFrame.lookAt(from, to), Color = WHITE:Lerp(color, 0.35) }, travel + 0.6)
	if not p then
		if onHit then
			task.delay(travel, onHit)
		end
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size * 0.35, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -size * 0.35, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = style == "meteor" and 0.45 or 0.22
	trail.Color = ColorSequence.new(WHITE, color)
	trail.Transparency = seq(0, 0.1, 1, 1)
	trail.WidthScale = seq(0, 1, 1, 0)
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = p
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 6 + size * 4
	light.Brightness = 2.5
	light.Shadows = false
	light.Parent = p
	if style == "meteor" or style == "fire" then
		emit(p, { tex = TEX.fire, color = ColorSequence.new(WHITE:Lerp(color, 0.4), color), emission = 1, size = seq(0, size * 1.1, 1, 0), speed = NumberRange.new(0.5, 1.5),
			life = NumberRange.new(0.2, 0.4), rate = 70, drag = 1 }, 0)
		emit(p, { tex = TEX.smoke, color = ColorSequence.new(Color3.fromRGB(80, 72, 70)), size = seq(0, size * 0.6, 1, size * 2), transparency = seq(0, 0.6, 1, 1),
			speed = NumberRange.new(0.2, 1), life = NumberRange.new(0.5, 1), rate = 25 }, 0)
	else
		emit(p, { color = ColorSequence.new(WHITE, color), emission = 1, size = seq(0, size * 0.35, 1, 0), speed = NumberRange.new(0.5, 2), life = NumberRange.new(0.2, 0.45),
			rate = 45, drag = 2 }, 0)
	end
	tween(p, travel, { CFrame = CFrame.lookAt(to, to + (to - from)) }, Enum.EasingStyle.Linear)
	task.delay(travel, function()
		if p.Parent then
			p.Transparency = 1
			light.Enabled = false
			for _, d in ipairs(p:GetChildren()) do
				if d:IsA("ParticleEmitter") then
					d.Enabled = false
				end
			end
		end
		if onHit then
			onHit()
		end
	end)
end

-- Impacto genérico (golpe acertando): faíscas + clarão + um pouco de poeira.
local function impact(at: Vector3, color: Color3, power: number)
	sparks(at, color, math.floor(6 + power * 6), 10 + power * 8)
	flash(at, color, 8 + power * 6, 2 + power, 0.25)
	if power >= 1 then
		dust(at - Vector3.new(0, 1, 0), nil, math.floor(power * 3), 1.6 + power * 0.6, 6)
	end
end

-- Raio: zigue-zague de segmentos Neon com ramificações, clarão forte e brilho no ponto de impacto.
local function lightning(from: Vector3, to: Vector3, color: Color3?, width: number?)
	local col = color or Color3.fromRGB(170, 230, 255)
	local w = width or 0.6
	local function bolt(a: Vector3, b: Vector3, segs: number, jitter: number, wid: number, depth: number)
		local prev = a
		for i = 1, segs do
			local t = i / segs
			local p = a:Lerp(b, t)
			if i < segs then
				p += Vector3.new(math.random() - 0.5, (math.random() - 0.5) * 0.4, math.random() - 0.5) * jitter
			end
			local seg = part({ Size = Vector3.new(wid, wid, (p - prev).Magnitude + wid), CFrame = CFrame.lookAt((prev + p) / 2, p), Color = WHITE:Lerp(col, 0.35) }, 0.2)
			if seg then
				tween(seg, 0.18, { Transparency = 1 })
			end
			if depth < 1 and i < segs - 1 and math.random() < 0.35 then
				bolt(p, p + (b - a).Unit * (b - a).Magnitude * 0.25 + Vector3.new(math.random() - 0.5, -0.3, math.random() - 0.5) * jitter * 2, 3, jitter * 0.6, wid * 0.55, depth + 1)
			end
			prev = p
		end
	end
	local len = (to - from).Magnitude
	bolt(from, to, math.clamp(math.floor(len / 6), 4, 12), math.clamp(len * 0.12, 1.5, 9), w, 0)
	flash(to + Vector3.new(0, 2, 0), col, 40, 6, 0.3)
	sparks(to, col, 10, 18)
end
Fx.lightning = lightning

local function ring(at: Vector3, radius: number, color: Color3, time: number?)
	shockRing(at, radius, color, time)
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

local function s_len(sh): number
	return sh.length or 10
end

local onAbilityFxRef
-------------------------------------------------------------------------------
-- Ataques ASSINATURA dos pets (SignatureService): um estilo de efeito por ataque
-------------------------------------------------------------------------------

local V3 = Vector3.new

local function flatDir(a: Vector3, b: Vector3): Vector3
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	return d.Magnitude > 0.05 and d.Unit or Vector3.new(0, 0, -1)
end

-- Nome do ataque sobre o pet (sobe e some).
local function sigName(model: Model?, text: string, color: Color3)
	if not model or not model.PrimaryPart then
		return
	end
	local a = part({ Size = Vector3.one * 0.2, CFrame = model.PrimaryPart.CFrame + V3(0, 3.5, 0), Transparency = 1 }, 1.5)
	if not a then
		return
	end
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(280, 34)
	g.AlwaysOnTop = true
	g.MaxDistance = 150
	g.Parent = a
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = "✦ " .. text .. " ✦"
	l.TextColor3 = WHITE:Lerp(color, 0.55)
	l.TextStrokeTransparency = 0.1
	l.TextStrokeColor3 = Color3.new(0, 0, 0):Lerp(color, 0.25)
	l.Parent = g
	tween(a, 1.4, { CFrame = a.CFrame + V3(0, 3, 0) })
	task.delay(0.9, function()
		tween(l, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
end

-- Folhas/pétalas que giram para fora de um ponto.
local function leafSwirl(at: Vector3, radius: number, color: Color3, n: number, rise: number?)
	n = scaled(n)
	for i = 1, n do
		local a = i / n * math.pi * 2 + math.random() * 0.4
		local leaf = part({ Size = V3(0.7, 0.12, 1.1), CFrame = CFrame.new(at + V3(0, 1, 0)) * CFrame.Angles(0, a, 0), Color = color:Lerp(WHITE, math.random() * 0.25),
			Material = Enum.Material.SmoothPlastic }, 0.9)
		if leaf then
			local dest = at + V3(math.cos(a) * radius, 1 + (rise or 1.5) * math.random(), math.sin(a) * radius)
			tween(leaf, 0.7, { CFrame = CFrame.new(dest) * CFrame.Angles(math.random() * 3, a + 2.5, math.random() * 3), Transparency = 1 })
		end
	end
end

-- Raízes que brotam do chão em volta de um ponto.
local function rootSpikes(at: Vector3, radius: number, color: Color3, count: number, height: number, life: number)
	count = scaled(count)
	for i = 1, count do
		local a = i / count * math.pi * 2 + math.random() * 0.3
		local d = radius * (0.35 + math.random() * 0.65)
		local base = at + V3(math.cos(a) * d, -0.5, math.sin(a) * d)
		local root = part({ Size = V3(0.9, 0.2, 0.9), CFrame = CFrame.new(base), Color = Color3.fromRGB(92, 64, 40):Lerp(color, 0.25), Material = Enum.Material.Wood }, life)
		if root then
			local h = height * (0.6 + math.random() * 0.6)
			tween(root, 0.22 + math.random() * 0.15, { Size = V3(0.9, h, 0.9), CFrame = CFrame.new(base) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(15 + math.random() * 20)) * CFrame.new(0, h / 2, 0) })
			task.delay(life - 0.35, function()
				if root.Parent then
					tween(root, 0.3, { Size = V3(0.9, 0.2, 0.9), Transparency = 1 })
				end
			end)
		end
	end
	dust(at, nil, 6, 1.6 + radius * 0.12, radius)
	embers(at + V3(0, 1, 0), color, 10, radius)
end

-- Rachadura/onda ao longo de uma linha no chão.
local function groundLine(from: Vector3, dir: Vector3, length: number, color: Color3, roots: boolean)
	local steps = math.clamp(math.floor(length / 4), 3, 9)
	for i = 0, steps do
		local f = i / steps
		local at = from + dir * length * f
		task.delay(f * 0.3, function()
			dust(at, nil, 3, 2, 6)
			if roots then
				rootSpikes(at, 2, color, 3, 4, 1.6)
			else
				sparks(at, color, 4, 12)
				debris(at, DUST, 1, 14)
			end
		end)
	end
end

local SIG = {}

SIG.bite = function(p, c)
	impact(p.to, c, 0.9)
	leafSwirl(p.to, 4, c, 8)
	sparks(p.to + V3(0, 1, 0), WHITE, 8, 14)
end
SIG.bloom = function(p, c)
	shockRing(p.at, p.radius or 6, c, 0.45)
	leafSwirl(p.at, p.radius or 6, c, 14, 3)
	flash(p.at + V3(0, 2, 0), c, 14, 2, 0.5)
end
SIG.roll = function(p, c)
	for k = 0, (p.n or 2) - 1 do
		task.delay(k * (p.interval or 0.3), function()
			projectile(p.from, p.to, c, 0.18, 2.4, "energy", function()
				impact(p.to, c, 0.8)
				dust(p.to, nil, 4, 2, 6)
			end)
		end)
	end
end
SIG.kick = function(p, c)
	for k = 0, (p.n or 2) - 1 do
		task.delay(k * (p.interval or 0.2), function()
			impact(p.to, c, 0.8)
			leafSwirl(p.to, 3, c, 6)
			shockRing(p.to, 3.5, c, 0.25)
		end)
	end
end
SIG.peck = function(p, c)
	for k = 0, (p.n or 3) - 1 do
		task.delay(k * (p.interval or 0.15), function()
			sparks(p.to + V3(0, 1, 0), c, 6, 12)
			flash(p.to, c, 6, 2, 0.12)
		end)
	end
end
SIG.acorn = function(p, c)
	local pts = p.points or {}
	local prev = p.from
	for i, q in ipairs(pts) do
		local from = prev
		task.delay((i - 1) * 0.22, function()
			projectile(from, q, c, 0.2, 0.9, "energy", function()
				impact(q, c, 0.6)
			end)
		end)
		prev = q
	end
end
SIG.tongue = function(p, c)
	local len = (p.to - p.from).Magnitude
	local t = part({ Size = V3(0.45, 0.45, 0.2), CFrame = CFrame.lookAt(p.from, p.to), Color = c, Material = Enum.Material.SmoothPlastic }, 0.6)
	if t then
		tween(t, 0.15, { Size = V3(0.45, 0.45, len), CFrame = CFrame.lookAt(p.from, p.to) * CFrame.new(0, 0, -len / 2) })
		task.delay(0.2, function()
			tween(t, 0.25, { Size = V3(0.45, 0.45, 0.2), CFrame = CFrame.lookAt(p.from, p.to), Transparency = 1 })
		end)
	end
	task.delay(0.15, impact, p.to, c, 0.6)
end
SIG.leafwrap = function(p, c)
	leafSwirl(p.to, 2.5, c, 12, 3)
	shockRing(p.from, 10, Color3.fromRGB(150, 220, 255), 0.5)
end
SIG.feathers = function(p, c)
	local dir = flatDir(p.from, p.to)
	local half = math.rad((p.angle or 40) / 2)
	local n = p.n or 5
	for i = 1, n do
		local a = -half + (i - 1) / math.max(1, n - 1) * half * 2
		local d = CFrame.Angles(0, a, 0):VectorToWorldSpace(dir)
		task.delay(i * 0.04, function()
			local dest = p.from + d * (p.range or 20)
			projectile(p.from, dest, c, 0.22, 0.7, "energy", function()
				sparks(dest, c, 3, 8)
			end)
		end)
	end
end
SIG.spores = function(p, c)
	for k = 0, (p.n or 4) - 1 do
		task.delay(k * (p.interval or 0.7), function()
			local a = anchorAt(p.at + V3(0, 1.5, 0), 1.6)
			if a then
				emit(a, { color = ColorSequence.new(WHITE, c), emission = 1, size = seq(0, 0, 0.3, 0.5, 1, 0), speed = NumberRange.new(1, (p.radius or 8) * 0.6),
					life = NumberRange.new(1, 1.5), spread = Vector2.new(180, 180), drag = 1.5, accel = V3(0, 1, 0) }, 22)
			end
			shockRing(p.at, p.radius or 8, c, 0.6)
		end)
	end
end
SIG.ram = function(p, c)
	onAbilityFxRef({ kind = "charge", from = p.from, to = p.to, color = c })
	debris(p.to, DUST, 4, 18)
end
SIG.claw = function(p, c)
	for k = 0, 1 do
		task.delay(k * (p.interval or 0.2), function()
			local cf = CFrame.lookAt(p.to + V3(0, 1.5, 0), p.from + V3(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(k == 0 and 45 or -45))
			local s = part({ Size = V3(0.25, 0.25, 0.25), CFrame = cf, Color = c }, 0.5)
			if s then
				tween(s, 0.18, { Size = V3(0.25, 5, 0.25) })
				task.delay(0.2, function()
					tween(s, 0.25, { Transparency = 1 })
				end)
			end
			sparks(p.to + V3(0, 1.5, 0), c, 8, 14)
		end)
	end
end
SIG.splash = function(p, c)
	projectile(p.from + V3(0, 2, 0), p.at, c, 0.3, 1.6, "energy", function()
		shockRing(p.at, p.radius or 7, c, 0.5)
		local pool = part({ Shape = Enum.PartType.Cylinder, Size = V3(0.2, (p.radius or 7) * 1.6, (p.radius or 7) * 1.6), CFrame = CFrame.new(p.at + V3(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = c, Transparency = 0.35 }, 3)
		if pool then
			task.delay(2.4, function()
				tween(pool, 0.5, { Transparency = 1 })
			end)
		end
		sparks(p.at, c, 12, 14)
	end)
end
SIG.hoot = function(p, c)
	for k = 0, 2 do
		task.delay(k * 0.12, function()
			shockRing(p.from:Lerp(p.to, (k + 1) / 3) + V3(0, 1.5, 0), 2 + k, c, 0.35)
		end)
	end
	task.delay(0.35, function()
		flash(p.to, c, 10, 3, 0.4)
		embers(p.to + V3(0, 2, 0), c, 8, 2)
	end)
end
SIG.thorns = function(p, c)
	local n = scaled(14)
	for i = 1, n do
		local a = i / n * math.pi * 2
		local d = V3(math.cos(a), 0, math.sin(a))
		local spike = part({ Size = V3(0.3, 0.3, 1.4), CFrame = CFrame.lookAt(p.at + V3(0, 1.2, 0), p.at + V3(0, 1.2, 0) + d), Color = c, Material = Enum.Material.SmoothPlastic }, 0.5)
		if spike then
			tween(spike, 0.35, { CFrame = CFrame.lookAt(p.at + V3(0, 1.2, 0) + d * (p.radius or 9), p.at + V3(0, 1.2, 0) + d * ((p.radius or 9) + 1)), Transparency = 0.6 })
		end
	end
	shockRing(p.at, p.radius or 9, c, 0.35)
end
SIG.quake = function(p, c)
	local at = p.angle and (p.from + flatDir(p.from, p.to) * (p.range or 12) * 0.5) or p.at
	local r = p.radius or (p.range or 12) * 0.6
	shockRing(at, r, c, 0.4)
	dust(at, nil, 12, 3, r * 1.3)
	debris(at, DUST, 6, 18)
	sparks(at + V3(0, 1, 0), c, 10, 16)
	shake(at, 0.7, 0.3)
end
SIG.breath = function(p, c)
	local dir = flatDir(p.from, p.to)
	local half = math.rad((p.angle or 35) / 2)
	for k = 0, (p.n or 6) - 1 do
		task.delay(k * (p.interval or 0.25), function()
			for _ = 1, 2 do
				local d = CFrame.Angles(0, (math.random() * 2 - 1) * half, 0):VectorToWorldSpace(dir)
				local dest = p.from + d * (p.range or 20) * (0.6 + math.random() * 0.4)
				projectile(p.from + V3(0, 1.5, 0), dest, c, 0.25, 0.9, "energy", function()
					embers(dest, c, 3, 2)
				end)
			end
		end)
	end
end
SIG.stampede = function(p, c)
	local dir = flatDir(p.from, p.to)
	onAbilityFxRef({ kind = "charge", from = p.from, to = p.to, color = c })
	groundLine(p.from, dir, p.length or 20, c, false)
end
SIG.dome = function(p, c)
	local r = (p.radius or 14) * 0.9
	local b = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = CFrame.new(p.at), Color = c, Material = Enum.Material.ForceField, Transparency = 0.2 }, 5)
	if b then
		tween(b, 0.35, { Size = Vector3.one * r * 2 })
		task.delay(4.4, function()
			tween(b, 0.5, { Transparency = 1 })
		end)
	end
	leafSwirl(p.at, r, Color3.fromRGB(255, 200, 230), 12, 4)
	flash(p.at + V3(0, 2, 0), c, r * 1.5, 2, 0.6)
end
SIG.ambush = function(p, c)
	dust(p.from, nil, 10, 3, 6)
	task.delay(0.12, function()
		impact(p.to, c, 1)
		flash(p.to, c, 10, 3, 0.25)
		sparks(p.to + V3(0, 1, 0), WHITE, 10, 16)
	end)
end
SIG.berries = function(p, c)
	local r = (p.radius or 18) * 0.6
	for i = 1, scaled(12) do
		local land = p.at + V3((math.random() * 2 - 1) * r, 0, (math.random() * 2 - 1) * r)
		task.delay(i * 0.05, function()
			projectile(land + V3(0, 16, 0), land, c, 0.45, 0.8, "energy", function()
				sparks(land, c, 3, 8)
			end)
		end)
	end
	onAbilityFxRef({ kind = "heal", at = p.at, radius = p.radius or 18, color = Color3.fromRGB(140, 255, 170) })
end
SIG.petals = function(p, c)
	for k = 0, (p.n or 3) - 1 do
		task.delay(k * (p.interval or 0.3), function()
			leafSwirl(p.at, p.radius or 8, c, 12, 2.5)
			shockRing(p.at, p.radius or 8, c, 0.3)
		end)
	end
end
SIG.rootline = function(p, c)
	local dir = flatDir(p.from, p.to)
	groundLine(p.from, dir, p.length or 24, c, true)
	shake(p.from + dir * (p.length or 24) * 0.5, (p.width or 6) > 8 and 0.9 or 0.5, 0.35)
end
SIG.pounce = function(p, c)
	local mid = (p.from + p.to) / 2 + V3(0, 8, 0)
	projectile(p.from, mid, c, 0.15, 1.6, "energy", function()
		projectile(mid, p.to, c, 0.15, 1.6, "energy", function()
			impact(p.to, c, 1.2)
			shockRing(p.to, 5, c, 0.35)
			sparks(p.to, Color3.fromRGB(255, 200, 120), 14, 18)
		end)
	end)
end
SIG.orbs = function(p, c)
	for i, q in ipairs(p.points or { p.to }) do
		task.delay(i * 0.08, function()
			projectile(p.from + V3(0, 2, 0), q, c, 0.45, 1.5, "energy", function()
				impact(q, c, 0.9)
				shockRing(q, 4, c, 0.3)
			end)
		end)
	end
end
SIG.totem = function(p, c)
	local at = p.anchor or p.at
	local life = (p.n or 8) * (p.interval or 1) + 0.4
	local pole = part({ Size = V3(1.6, 0.2, 1.6), CFrame = CFrame.new(at), Color = Color3.fromRGB(110, 76, 46), Material = Enum.Material.Wood }, life)
	if pole then
		tween(pole, 0.3, { Size = V3(1.6, 7, 1.6), CFrame = CFrame.new(at + V3(0, 3.5, 0)) })
	end
	local crown = part({ Size = V3(1.2, 1.2, 1.2), CFrame = CFrame.new(at + V3(0, 7.6, 0)) * CFrame.Angles(math.rad(45), math.rad(45), 0), Color = c }, life)
	if crown then
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = c, 16, 2
		l.Parent = crown
	end
	for k = 0, (p.n or 8) - 1 do
		task.delay(k * (p.interval or 1) + 0.2, function()
			shockRing(at, p.radius or 12, c, 0.5)
			embers(at + V3(0, 6, 0), c, 4, 2)
		end)
	end
end
SIG.fortress = function(p, c)
	local r = 6
	for i = 1, scaled(10) do
		local a = i / 10 * math.pi * 2
		local base = p.at + V3(math.cos(a) * r, -0.5, math.sin(a) * r)
		local t = part({ Size = V3(1.6, 0.2, 1.6), CFrame = CFrame.new(base), Color = Color3.fromRGB(100, 70, 44), Material = Enum.Material.Wood }, 6)
		if t then
			tween(t, 0.35, { Size = V3(1.6, 7, 1.6), CFrame = CFrame.new(base + V3(0, 3.5, 0)) })
			task.delay(5.4, function()
				tween(t, 0.4, { Size = V3(1.6, 0.2, 1.6), CFrame = CFrame.new(base), Transparency = 1 })
			end)
		end
	end
	SIG.dome(p, c)
end
SIG.howl = function(p, c)
	shockRing(p.from, 10, c, 0.5)
	flash(p.from + V3(0, 2, 0), c, 14, 2, 0.4)
	for i, q in ipairs(p.points or { p.to }) do
		task.delay(0.15 + i * 0.1, function()
			projectile(p.from + V3(0, 1.5, 0), q, c, 0.35, 2.2, "energy", function()
				impact(q, c, 1)
				leafSwirl(q, 3, c, 6)
			end)
		end)
	end
end
SIG.roar = function(p, c)
	SIG.thorns(p, c)
	flash(p.at + V3(0, 3, 0), c, (p.radius or 16) * 1.5, 3, 0.4)
	dust(p.at, nil, 10, 3, (p.radius or 16))
	shake(p.at, 0.9, 0.4)
end
SIG.vibration = function(p, c)
	for k = 0, (p.n or 3) - 1 do
		task.delay(k * (p.interval or 0.3), function()
			local r = (p.radius or 8) + (p.grow or 0) * k
			shockRing(p.at, r, c, 0.45)
			dust(p.at, nil, 6, 2.5, r)
			flash(p.at + V3(0, 2, 0), c, r, 2, 0.25)
			shake(p.at, 0.5, 0.2)
		end)
	end
end
SIG.tornado = function(p, c)
	local total = (p.n or 10) * (p.interval or 0.5)
	local a = anchorAt(p.from + V3(0, 3, 0), total + 0.5)
	if a then
		a.Size = V3(4, 6, 4)
		emit(a, { tex = TEX.smoke, color = ColorSequence.new(WHITE, c), emission = 0.6, size = seq(0, 1.5, 1, 3), transparency = seq(0, 0.5, 1, 1), speed = NumberRange.new(3, 6),
			life = NumberRange.new(0.6, 1), spread = Vector2.new(10, 180), accel = V3(0, 10, 0), rot = NumberRange.new(-300, 300), rate = lowVfx() and 12 or 40 }, 0)
		emit(a, { color = ColorSequence.new(c), emission = 1, size = seq(0, 0.4, 1, 0), speed = NumberRange.new(6, 10), life = NumberRange.new(0.5, 0.9),
			spread = Vector2.new(20, 180), accel = V3(0, 14, 0), rate = lowVfx() and 8 or 24 }, 0)
		tween(a, total, { CFrame = CFrame.new(p.to + V3(0, 3, 0)) }, Enum.EasingStyle.Sine)
	end
	for k = 0, (p.n or 10) - 1, 2 do
		task.delay(k * (p.interval or 0.5), function()
			local at = p.from:Lerp(p.to, math.min(1, k / math.max(1, (p.n or 10) - 2)))
			leafSwirl(at, p.radius or 7, c, 6, 6)
		end)
	end
end
SIG.meteors = function(p, c)
	for k = 0, (p.n or 7) - 1 do
		task.delay(k * (p.interval or 0.18), function()
			local a = math.random() * math.pi * 2
			local land = p.at + V3(math.cos(a), 0, math.sin(a)) * (p.radius or 16) * 0.7 * math.random()
			projectile(land + V3(12, 42, 8), land, c, 0.4, 2, "meteor", function()
				fireball(land + V3(0, 1, 0), c, 1.3)
				shockRing(land, 5, c, 0.35)
				dust(land, nil, 4, 2.5, 8)
				shake(land, 0.4, 0.2)
			end)
		end)
	end
	task.delay(0.1, shockRing, p.at, p.radius or 16, c, 1)
end
SIG.winddance = function(p, c)
	onAbilityFxRef({ kind = "haste", at = p.at, radius = p.radius or 12, color = c })
	leafSwirl(p.at, p.radius or 12, c, 14, 5)
end
SIG.ancientroots = function(p, c)
	rootSpikes(p.at, p.radius or 18, c, 22, 9, 2.4)
	shockRing(p.at, p.radius or 18, c, 0.6)
	flash(p.at + V3(0, 3, 0), c, (p.radius or 18) * 1.3, 3, 0.5)
	shake(p.at, 1, 0.45)
end
SIG.forestheart = function(p, c)
	onAbilityFxRef({ kind = "heal", at = p.at, radius = p.radius or 20, color = c })
	shockRing(p.at, p.radius or 20, c, 0.6)
	leafSwirl(p.at, p.radius or 20, c, 18, 5)
	rootSpikes(p.at, 4, c, 8, 5, 1.8)
	shake(p.at, 0.7, 0.35)
end
SIG.eclipse = function(p, c)
	local c2 = p.color2 or Color3.fromRGB(80, 40, 140)
	local r = p.radius or 22
	local disc = part({ Shape = Enum.PartType.Cylinder, Size = V3(0.4, 2, 2), CFrame = CFrame.new(p.at + V3(0, 26, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = c2, Transparency = 0.25 },
		(p.n or 4) * (p.interval or 0.4) + 1)
	if disc then
		tween(disc, 0.4, { Size = V3(0.4, r * 2, r * 2) })
	end
	for k = 0, (p.n or 4) - 1 do
		task.delay(0.3 + k * (p.interval or 0.4), function()
			for _ = 1, 3 do
				local land = p.at + V3((math.random() * 2 - 1) * r * 0.7, 0, (math.random() * 2 - 1) * r * 0.7)
				projectile(land + V3(0, 26, 0), land, c, 0.25, 1.4, "energy", function()
					impact(land, c, 0.9)
				end)
			end
			shockRing(p.at, r, c, 0.4)
		end)
	end
end

-- Estilos dos Mundos 2 a 5 (cristal, céu, floresta sombria, astral) ---------------------------------

-- espinhos de cristal que brotam do chão (Glass), em volta de um ponto
local function crystalSpikes(at: Vector3, radius: number, color: Color3, count: number, height: number, life: number)
	count = scaled(count)
	for i = 1, count do
		local a = i / count * math.pi * 2 + math.random() * 0.4
		local d = radius * (0.25 + math.random() * 0.75)
		local base = at + V3(math.cos(a) * d, -0.4, math.sin(a) * d)
		local sp = part({ Size = V3(0.8, 0.2, 0.8), CFrame = CFrame.new(base), Color = color:Lerp(WHITE, 0.25), Material = Enum.Material.Glass, Transparency = 0.15 }, life)
		if sp then
			local h = height * (0.5 + math.random() * 0.7)
			tween(sp, 0.18, { Size = V3(0.8, h, 0.8), CFrame = CFrame.new(base) * CFrame.Angles(0, a, math.rad((math.random() * 2 - 1) * 22)) * CFrame.new(0, h / 2, 0) })
			task.delay(life - 0.3, function()
				if sp.Parent then
					tween(sp, 0.25, { Transparency = 1 })
				end
			end)
		end
	end
	sparks(at + V3(0, 1, 0), color, 12, 16)
end

SIG.shards = function(p, c)
	local at = p.at or p.to
	for k = 0, (p.n or 1) - 1 do
		task.delay(k * (p.interval or 0.3), function()
			crystalSpikes(at, p.radius or 6, c, 10, 3.2, 1.4)
			shockRing(at, p.radius or 6, c, 0.35)
		end)
	end
	flash(at + V3(0, 2, 0), c, 16, 2.5, 0.35)
end
SIG.thunder = function(p, c)
	local targets = p.points and #p.points > 0 and p.points or { p.to or p.at }
	for k = 0, (p.n or 1) - 1 do
		task.delay(k * (p.interval or 0.2), function()
			for _, q in ipairs(targets) do
				lightning(q + V3(math.random() * 4 - 2, 34, math.random() * 4 - 2), q, c, 0.6)
				shockRing(q, 4, c, 0.25)
			end
		end)
	end
	shake(targets[1], 0.5, 0.2)
end
SIG.shadow = function(p, c)
	local at = p.to or p.at
	dust(at, Color3.fromRGB(30, 20, 45), 12, 3.2, 10)
	for k = 0, (p.n or 1) - 1 do
		task.delay(k * (p.interval or 0.2), function()
			impact(at, c, 0.9)
			sparks(at + V3(0, 1, 0), c, 8, 12)
		end)
	end
	flash(at + V3(0, 2, 0), Color3.fromRGB(120, 60, 200), 12, 1.5, 0.4)
end
SIG.prismbeam = function(p, c)
	local from = p.from
	local dir = flatDir(p.from, p.to or p.at)
	local len = p.length or 20
	local hues = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 120), Color3.fromRGB(140, 255, 180), Color3.fromRGB(140, 200, 255), Color3.fromRGB(200, 150, 255) }
	for i, h in ipairs(hues) do
		local off = (i - 3) * 0.35
		local side = V3(-dir.Z, 0, dir.X) * off
		local beam = part({ Size = V3(0.35, 0.35, 0.2), CFrame = CFrame.lookAt(from + V3(0, 1.4, 0) + side, from + V3(0, 1.4, 0) + side + dir), Color = h, Transparency = 0.1 }, 0.6)
		if beam then
			tween(beam, 0.14, { Size = V3(0.35, 0.35, len), CFrame = CFrame.lookAt(from + V3(0, 1.4, 0) + side, from + V3(0, 1.4, 0) + side + dir) * CFrame.new(0, 0, -len / 2) })
			task.delay(0.3, function()
				if beam.Parent then
					tween(beam, 0.25, { Transparency = 1 })
				end
			end)
		end
	end
	task.delay(0.15, function()
		flash(from + dir * len + V3(0, 1.5, 0), c, 14, 2.5, 0.3)
		sparks(from + dir * len, c, 10, 16)
	end)
end
SIG.frost = function(p, c)
	local at = p.at or p.to
	crystalSpikes(at, p.radius or 7, Color3.fromRGB(200, 240, 255), 8, 2, 1.8)
	shockRing(at, p.radius or 7, Color3.fromRGB(220, 245, 255), 0.6)
	dust(at, Color3.fromRGB(230, 245, 255), 8, 2.5, 6)
end
SIG.nova = function(p, c)
	local at = p.at or p.from
	local r = p.radius or 12
	for k = 0, (p.n or 1) - 1 do
		task.delay(k * (p.interval or 0.35), function()
			shockRing(at, r * (0.5 + 0.5 * (k + 1) / (p.n or 1)), c, 0.45)
			flash(at + V3(0, 2, 0), c, r * 1.4, 3, 0.35)
			sparks(at + V3(0, 1.5, 0), WHITE:Lerp(c, 0.5), 14, 20)
		end)
	end
end

-------------------------------------------------------------------------------
-- ENCENAÇÃO DOS PODERES (vale para todos os estilos): preparação, cut-in de anime, pulso na tela e rastro.
-------------------------------------------------------------------------------

-- Círculo de runas que gira no chão sob quem lança (aro duplo + raios), e some.
local function castCircle(at: Vector3, radius: number, color: Color3, life: number)
	local base = CFrame.new(at - V3(0, 1.6, 0))
	local outer = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, radius * 2, radius * 2), CFrame = base * CFrame.Angles(0, 0, math.rad(90)),
		Color = color, Transparency = 0.35 }, life)
	local inner = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, radius * 1.3, radius * 1.3), CFrame = base * CFrame.Angles(0, 0, math.rad(90)),
		Color = WHITE:Lerp(color, 0.5), Transparency = 0.55 }, life)
	local hole = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, radius * 1.85, radius * 1.85), CFrame = base * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.new(0, 0, 0), Transparency = 0.82 }, life)
	local spokes = {}
	for k = 0, 5 do
		local sp = part({ Size = Vector3.new(radius * 1.7, 0.1, 0.12), CFrame = base * CFrame.Angles(0, k * math.pi / 6, 0), Color = color, Transparency = 0.45 }, life)
		if sp then
			table.insert(spokes, sp)
		end
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > life then
			conn:Disconnect()
			return
		end
		local fade = math.clamp((t - life * 0.6) / (life * 0.4), 0, 1)
		for k, sp in ipairs(spokes) do
			sp.CFrame = base * CFrame.Angles(0, k * math.pi / 6 + t * 2.4, 0)
			sp.Transparency = 0.45 + 0.55 * fade
		end
		if outer then
			outer.Transparency = 0.35 + 0.65 * fade
		end
		if inner then
			inner.CFrame = base * CFrame.Angles(0, -t * 3, math.rad(90))
			inner.Transparency = 0.55 + 0.45 * fade
		end
		if hole then
			hole.Transparency = 0.82 + 0.18 * fade
		end
	end)
end

-- Energia convergindo para quem lança (fagulhas que vêm de fora para dentro).
local function gather(at: Vector3, color: Color3, radius: number, time: number)
	for k = 1, scaled(10) do
		local a = k / 10 * math.pi * 2 + math.random() * 0.5
		local from = at + V3(math.cos(a) * radius, math.random() * radius * 0.6, math.sin(a) * radius)
		local p = part({ Size = Vector3.new(0.16, 0.16, 0.9), CFrame = CFrame.lookAt(from, at), Color = WHITE:Lerp(color, 0.5) }, time + 0.05)
		if p then
			tween(p, time, { CFrame = CFrame.lookAt(at, at + (at - from)), Size = Vector3.new(0.05, 0.05, 0.3) }, Enum.EasingStyle.Quint)
		end
	end
	flash(at, color, 10, 1.5, time)
end

-- Pilar de luz + brasas no ponto do golpe (o poder "deixa marca" por um instante).
local function afterglow(at: Vector3, color: Color3, radius: number)
	local h = 10 + radius
	local pillar = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, radius * 0.6, radius * 0.6), CFrame = CFrame.new(at + V3(0, h / 2 - 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = WHITE:Lerp(color, 0.4), Transparency = 0.45 }, 0.75)
	if pillar then
		tween(pillar, 0.7, { Size = Vector3.new(h * 1.2, 0.05, 0.05), Transparency = 1 })
	end
	shockRing(at, radius * 1.4, color, 0.5)
	embers(at, color, 14, radius)
end

-- CUT-IN DE ANIME (só os poderes dos SEUS pets): faixa diagonal colorida atravessando a tela com o nome do
-- poder, linhas de velocidade e o nome do pet. Um de cada vez.
local ACCENT_UP = { ["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê", ["í"] = "Í", ["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ",
	["ú"] = "Ú", ["ç"] = "Ç" }
-- maiúsculas que funcionam com acentos (string.upper só mexe em letras sem acento)
local function upperPT(text: string): string
	local out = string.upper(text)
	for lo, up in pairs(ACCENT_UP) do
		out = string.gsub(out, lo, up)
	end
	return out
end
Fx._upperPT = upperPT

local cutInUntil = 0
local function cutIn(power: string, petName: string, color: Color3)
	if os.clock() < cutInUntil then
		return
	end
	cutInUntil = os.clock() + 1.1
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "SignatureCutIn"
	g.IgnoreGuiInset = true
	g.DisplayOrder = 40
	g.ResetOnSpawn = false
	g.Parent = pg
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(-0.6, 0.42)
	band.Size = UDim2.fromScale(1.6, 0.16)
	band.Rotation = -7
	band.BackgroundColor3 = color
	band.BorderSizePixel = 0
	band.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0):Lerp(color, 0.35)), ColorSequenceKeypoint.new(0.5, color),
		ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0):Lerp(color, 0.35)) })
	grad.Parent = band
	for _, y in ipairs({ 0, 1 }) do -- bordas brancas da faixa
		local edge = Instance.new("Frame")
		edge.Name = "Edge"
		edge.BackgroundColor3 = WHITE
		edge.BorderSizePixel = 0
		edge.AnchorPoint = Vector2.new(0, y)
		edge.Position = UDim2.fromScale(0, y)
		edge.Size = UDim2.new(1, 0, 0, 5)
		edge.Parent = band
	end
	for k = 1, 9 do -- linhas de velocidade
		local ln = Instance.new("Frame")
		ln.Name = "Speed"
		ln.BackgroundColor3 = WHITE
		ln.BackgroundTransparency = 0.35 + (k % 3) * 0.2
		ln.BorderSizePixel = 0
		ln.Size = UDim2.new(0.12 + (k % 4) * 0.05, 0, 0, 2 + k % 3)
		ln.Position = UDim2.fromScale(1.1, (k - 0.5) / 9)
		ln.Parent = band
		tween(ln, 0.55 + (k % 3) * 0.12, { Position = UDim2.fromScale(-0.3, (k - 0.5) / 9) }, Enum.EasingStyle.Linear)
	end
	local title = Instance.new("TextLabel")
	title.Name = "Power"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.45)
	title.Size = UDim2.fromScale(0.5, 0.62)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = upperPT(power)
	title.TextColor3 = WHITE
	title.TextStrokeColor3 = Color3.new(0, 0, 0)
	title.TextStrokeTransparency = 0
	title.Parent = band
	local sub = Instance.new("TextLabel")
	sub.Name = "Pet"
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.fromScale(0.5, 0.78)
	sub.Size = UDim2.fromScale(0.3, 0.2)
	sub.Font = Enum.Font.GothamBlack
	sub.TextScaled = true
	sub.Text = petName
	sub.TextColor3 = WHITE:Lerp(color, 0.3)
	sub.TextStrokeTransparency = 0.3
	sub.Parent = band
	-- entra rápido, segura, sai rápido para o outro lado
	tween(band, 0.18, { Position = UDim2.fromScale(0.5, 0.42) }, Enum.EasingStyle.Back)
	task.delay(0.75, function()
		tween(band, 0.2, { Position = UDim2.fromScale(1.6, 0.42) }, Enum.EasingStyle.Quad)
	end)
	task.delay(1.0, function()
		g:Destroy()
	end)
end

-- Pulso na tela (só os seus pets): tinta na cor do poder + "soco" de zoom.
local function screenPulse(color: Color3)
	local Lighting = game:GetService("Lighting")
	local cc = Lighting:FindFirstChild("SignaturePulse") :: ColorCorrectionEffect?
	if not cc then
		local n = Instance.new("ColorCorrectionEffect")
		n.Name = "SignaturePulse"
		n.Parent = Lighting
		cc = n
	end
	local c = cc :: ColorCorrectionEffect
	c.TintColor = WHITE:Lerp(color, 0.35)
	c.Brightness = 0.08
	c.Saturation = 0.25
	tween(c, 0.45, { TintColor = WHITE, Brightness = 0, Saturation = 0 })
	local cam = workspace.CurrentCamera
	local fov = cam and tonumber(cam.FieldOfView)
	if cam and fov and cam.CameraType ~= Enum.CameraType.Scriptable then
		cam.FieldOfView = fov - 5
		tween(cam, 0.35, { FieldOfView = fov }, Enum.EasingStyle.Back)
	end
end
Fx._cutIn, Fx._screenPulse = cutIn, screenPulse -- (testes/prévias)

-- ARCO DE CORTE: no instante do golpe de um pet, um arco brilhante abre na frente da cabeça (cor do pelo,
-- clareada) e some rápido; mais um sopro de faíscas. Só perto da câmera.
local function slashArc(entry, model: Model)
	if lowVfx() or not model.Parent then
		return
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	local root = model.PrimaryPart
	if not root then
		return
	end
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - root.Position).Magnitude > 90 then
		return
	end
	local s = math.max(0.8, entry.scale or 2)
	local look = root.CFrame.LookVector
	local base = (head and head.Position or root.Position) + look * s * 0.45
	local tint = WHITE
	local torso = model:FindFirstChild("Torso", true)
	if torso and torso:IsA("BasePart") then
		tint = WHITE:Lerp(torso.Color, 0.45)
	end
	local frame = CFrame.lookAt(base, base + look)
	local r = s * 0.55
	local n = 7
	for k = 0, n - 1 do
		local a = -1.1 + 2.2 * k / (n - 1)
		local pos = frame * Vector3.new(math.sin(a) * r, math.cos(a) * r * 0.55, -math.cos(a) * r * 0.25)
		local w = 0.12 + 0.14 * math.sin(k / (n - 1) * math.pi)
		local seg = part({ Size = Vector3.new(w, w, r * 0.42), CFrame = CFrame.lookAt(pos, pos + frame.RightVector * math.cos(a) - frame.UpVector * math.sin(a) * 0.55),
			Color = tint, Transparency = 0.15 }, 0.22)
		if seg then
			tween(seg, 0.2, { Transparency = 1, Size = Vector3.new(0.02, 0.02, r * 0.6), CFrame = seg.CFrame + look * s * 0.25 })
		end
	end
	sparks(base + look * s * 0.3, tint, 5, 9)
end
Fx._slashArc = slashArc

local function signatureFx(p)
	local c = p.color or Color3.new(1, 1, 1)
	local origin = p.from or p.at
	local mine = p.model ~= nil and p.model:GetAttribute("Owner") == player.UserId
	sigName(p.model, p.name or "", c)
	if typeof(origin) == "Vector3" then
		castCircle(origin, 3.2, c, 0.9)
		if not lowVfx() then
			gather(origin + V3(0, 1, 0), c, 5, 0.2)
		end
	end
	if mine then
		local sp = p.model and Pets.Species[p.model:GetAttribute("Species") or ""]
		cutIn(p.name or "", sp and sp.name or "", c)
		if not lowVfx() then
			screenPulse(c)
		end
	end
	local fn = SIG[p.style]
	local function main()
		if fn then
			fn(p, c)
		else
			impact(p.to or p.at, c, 1)
		end
		local hit = p.to or p.at
		if typeof(hit) == "Vector3" and not lowVfx() then
			afterglow(hit, c, math.clamp((p.radius or 4) * 0.5, 2, 7))
		end
	end
	-- o golpe sai depois da preparação (bem curta: o dano já foi aplicado no servidor)
	if lowVfx() then
		main()
	else
		task.delay(0.18, main)
	end
end
Fx.signatureStyles = SIG

local function onAbilityFx(p)
	local c = p.color or Color3.new(1, 1, 1)
	local k = p.kind
	if k == "bolt" then
		local travel = math.clamp((p.to - p.from).Magnitude / 90, 0.05, 0.4)
		projectile(p.from, p.to, c, travel, p.small and 0.6 or 1.2, "energy", function()
			impact(p.to, c, p.small and 0.4 or 1)
			if not p.small then
				embers(p.to, c, 8, 2)
			end
		end)
	elseif k == "orb" then
		-- projétil inimigo: esfera de energia com rastro; explode em brilho e fumaça colorida
		projectile(p.from, p.to, c, p.travel or 0.5, 1.6, "energy", function()
			impact(p.to, c, 1)
			dust(p.to, c:Lerp(Color3.new(0.3, 0.3, 0.3), 0.5), 6, 2.4, 6)
			shockRing(p.to, 5, c, 0.35)
		end)
	elseif k == "charge" then
		-- investida: poeira levantada na partida, rastro de vento e impacto com tremor
		dust(p.from - Vector3.new(0, 1.5, 0), nil, 8, 2.2, 12)
		local runner = part({ Size = Vector3.one * 0.3, CFrame = CFrame.lookAt(p.from, p.to), Transparency = 1 }, 0.7)
		if runner then
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.9, 0)
			a0.Parent = runner
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -0.9, 0)
			a1.Parent = runner
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Lifetime = 0.3
			trail.Color = ColorSequence.new(WHITE, c)
			trail.Transparency = seq(0, 0.3, 1, 1)
			trail.LightEmission = 0.6
			trail.Parent = runner
			tween(runner, 0.15, { CFrame = CFrame.lookAt(p.to, p.to + (p.to - p.from)) }, Enum.EasingStyle.Linear)
		end
		task.delay(0.15, function()
			impact(p.to, c, 1.2)
			debris(p.to - Vector3.new(0, 1, 0), DUST, 4, 14)
			shake(p.to, 0.6, 0.25)
		end)
	elseif k == "shield" and p.model and p.model.PrimaryPart then
		local size = p.model:GetExtentsSize().Magnitude * 0.75
		local dur = p.duration or 6
		local bubble = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = p.model.PrimaryPart.CFrame, Color = c,
			Material = Enum.Material.ForceField, Transparency = 0.1 }, dur)
		flash(p.model.PrimaryPart.Position, c, 14, 3, 0.4)
		if bubble then
			-- cintilação percorrendo a superfície do escudo
			emit(bubble, { color = ColorSequence.new(WHITE, c), emission = 1, size = seq(0, 0, 0.3, 0.25, 1, 0), speed = NumberRange.new(0, 0.5),
				life = NumberRange.new(0.4, 0.9), rate = lowVfx() and 4 or 12, z = 1 }, 0)
			local conn
			conn = RunService.RenderStepped:Connect(function()
				if not bubble.Parent or not p.model.PrimaryPart then
					conn:Disconnect()
					return
				end
				bubble.CFrame = p.model.PrimaryPart.CFrame
			end)
		end
	elseif k == "heal" then
		-- coluna de luz suave: centelhas verdes subindo + brilho no chão
		local a = anchorAt(p.at, 2.6)
		if a then
			a.Size = Vector3.new((p.radius or 20) * 0.6, 0.5, (p.radius or 20) * 0.6)
			local e = emit(a, { color = ColorSequence.new(WHITE, c), emission = 1, size = seq(0, 0, 0.2, 0.4, 1, 0), speed = NumberRange.new(2, 5),
				life = NumberRange.new(0.8, 1.4), accel = Vector3.new(0, 6, 0), spread = Vector2.new(15, 15), drag = 0.5 }, 30)
			e.Rate = lowVfx() and 8 or 25
			task.delay(0.8, function()
				e.Enabled = false
			end)
		end
		flash(p.at + Vector3.new(0, 2, 0), c, (p.radius or 20) * 0.8, 2.5, 1.2)
		shockRing(p.at, p.radius or 20, c, 0.8)
	elseif k == "haste" then
		-- rajada de vento: riscos brancos rápidos girando em volta + centelhas
		local a = anchorAt(p.at + Vector3.new(0, 1.5, 0), 1.6)
		if a then
			emit(a, { tex = TEX.smoke, color = ColorSequence.new(WHITE), size = seq(0, 0.6, 1, 0.1), transparency = seq(0, 0.55, 1, 1), speed = NumberRange.new(18, 28),
				life = NumberRange.new(0.25, 0.45), spread = Vector2.new(5, 180), dir = Enum.NormalId.Front, orient = Enum.ParticleOrientation.VelocityParallel,
				squash = seq(0, -2, 1, -2), drag = 3 }, 24)
		end
		embers(p.at, c, 14, 6)
		shockRing(p.at, p.radius or 18, c, 0.5)
	elseif k == "sense" then
		-- faro: cintilações douradas que se espalham pela área revelada
		local a = anchorAt(p.at + Vector3.new(0, 2, 0), 2.5)
		if a then
			emit(a, { color = ColorSequence.new(WHITE, c), emission = 1, size = seq(0, 0, 0.15, 0.45, 1, 0), speed = NumberRange.new(10, (p.radius or 30) * 0.9),
				life = NumberRange.new(1, 1.6), spread = Vector2.new(70, 180), drag = 1.8, accel = Vector3.new(0, -2, 0) }, 40)
		end
		shockRing(p.at, p.radius or 30, c, 1)
	elseif k == "shockwave" or k == "slam" then
		local r = p.radius or 12
		shockRing(p.at, r, c, 0.35)
		dust(p.at, nil, 14, 3 + r * 0.12, r * 1.4)
		debris(p.at, DUST, 6, 16 + r * 0.6)
		sparks(p.at + Vector3.new(0, 1, 0), c, 10, 18)
		flash(p.at + Vector3.new(0, 2, 0), c, r * 2, 3, 0.35)
		shake(p.at, k == "slam" and 1 or 0.7, 0.35)
	elseif k == "starfall" then
		-- chuva de meteoros: bolas de fogo com rastro caindo na diagonal; cada uma explode no chão
		local n = lowVfx() and 3 or 6
		for i = 1, n do
			local ang = i / n * math.pi * 2
			local land = p.at + Vector3.new(math.cos(ang), 0, math.sin(ang)) * (p.radius or 10) * 0.6 * math.random()
			task.delay(i * 0.07, function()
				projectile(land + Vector3.new(10, 38, 6), land, c, 0.4, 1.6, "meteor", function()
					fireball(land + Vector3.new(0, 1, 0), c, 1.2)
					dust(land, nil, 5, 2.5, 8)
					debris(land, Color3.fromRGB(90, 80, 74), 2, 14)
					shake(land, 0.5, 0.2)
				end)
			end)
		end
		task.delay(0.55, shockRing, p.at, p.radius or 12, c, 0.5)
	elseif k == "sunder" then
		-- quebrar defesa: chuva de faíscas metálicas + estalo de luz
		sparks(p.to, Color3.fromRGB(255, 200, 120), 26, 24)
		flash(p.to, c, 12, 4, 0.2)
		dust(p.to, Color3.fromRGB(110, 100, 96), 4, 1.6, 4)
		shockRing(p.to, 4, c, 0.25)
	elseif k == "snare" then
		-- raízes que brotam do chão com terra levantada e folhinhas
		dust(p.at, nil, 8, 2, 6)
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local base = p.at + Vector3.new(math.cos(a), 0, math.sin(a)) * (p.radius or 4)
			for seg = 0, 1 do
				local vine = part({ Size = Vector3.new(0.55 - seg * 0.2, 0.1, 0.55 - seg * 0.2), CFrame = CFrame.new(base), Color = c:Lerp(Color3.fromRGB(70, 50, 30), 0.4 - seg * 0.3),
					Material = Enum.Material.Wood, Transparency = 0 }, (p.duration or 2) + 0.3)
				if vine then
					local h = 3.2 - seg * 0.6
					local lean = CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(18 + seg * 20))
					tween(vine, 0.25 + seg * 0.1, { Size = Vector3.new(vine.Size.X, h, vine.Size.Z),
						CFrame = CFrame.new(base) * lean * CFrame.new(0, h / 2 + seg * 2.6, 0) })
				end
			end
		end
		embers(p.at + Vector3.new(0, 1, 0), c, 12, (p.radius or 4) * 2)
	elseif k == "burst" then
		-- recurso/tesouro quebrado: lascas com física + faíscas + poeira + clarão
		debris(p.at, c, 7, 18)
		sparks(p.at, c, 14, 16)
		dust(p.at - Vector3.new(0, 1, 0), nil, 6, 2, 7)
		flash(p.at, c, 14, 3, 0.35)
	elseif k == "bossImpact" and p.shapes then
		local strongest = 0
		for _, sh in ipairs(p.shapes) do
			local y = p.y + 0.5
			if sh.type == "circle" then
				local at = Vector3.new(sh.x, y, sh.z)
				if p.electric then
					lightning(at + Vector3.new(math.random(-6, 6), 60, math.random(-6, 6)), at, c, 1)
				end
				shockRing(at, sh.r, c, 0.4)
				fireball(at + Vector3.new(0, 1.5, 0), c, math.clamp(sh.r * 0.18, 1, 3))
				dust(at, nil, 12, 2.5 + sh.r * 0.12, sh.r * 1.3)
				debris(at, Color3.fromRGB(110, 100, 90), 6, 20)
				strongest = math.max(strongest, 1)
			elseif sh.type == "ring" then
				shockRing(Vector3.new(sh.x, y, sh.z), sh.outer, c, 0.5)
				for i = 1, 6 do
					local a = i / 6 * math.pi * 2
					local rr = (sh.inner + sh.outer) / 2
					dust(Vector3.new(sh.x + math.cos(a) * rr, y, sh.z + math.sin(a) * rr), nil, 4, 3, 8)
				end
				strongest = math.max(strongest, 0.8)
			elseif sh.type == "rect" then
				-- rachadura em linha: rajadas de poeira e lascas ao longo do retângulo
				local steps = math.clamp(math.floor(s_len(sh) / 7), 2, 8)
				for i = 0, steps do
					local f = i / steps
					local at = Vector3.new(sh.x + sh.dx * sh.length * f, y, sh.z + sh.dz * sh.length * f)
					task.delay(f * 0.25, function()
						dust(at, nil, 4, 2 + sh.width * 0.15, 7)
						debris(at, Color3.fromRGB(110, 100, 90), 1, 16)
						sparks(at, c, 4, 12)
					end)
				end
				strongest = math.max(strongest, 0.9)
			elseif sh.type == "cone" then
				local at = Vector3.new(sh.x, y, sh.z)
				for i = -2, 2 do
					local a = math.atan2(sh.dz or 0, sh.dx or 1) + i * 0.25
					local d = sh.length * 0.6
					dust(at + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), nil, 4, 2.5, 8)
				end
				sparks(at + Vector3.new(0, 1.5, 0), c, 14, 22)
				strongest = math.max(strongest, 0.8)
			elseif sh.type == "safezones" then
				shockRing(Vector3.new(sh.x, y, sh.z), sh.r, c, 0.6)
				embers(Vector3.new(sh.x, y, sh.z), c, 10, sh.r)
			end
		end
		if strongest > 0 then
			shake(Vector3.new(p.at.X, p.y, p.at.Z), 1.3 * strongest, 0.45)
		end
	elseif k == "signature" then
		signatureFx(p)
	elseif k == "chain" then
		-- raio em cadeia (Tempest Wyrm) e choques de poderes dos bosses: raio curto entre dois pontos
		lightning(p.from, p.to, c, 0.35)
	elseif k == "chill" then
		-- estilhaços cristalizam os pés: cristais em volta + anel gelado
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local base = p.at + Vector3.new(math.cos(a), 0, math.sin(a)) * 1.8
			local shard = part({ Size = Vector3.new(0.5, 0.2, 0.5), CFrame = CFrame.new(base) * CFrame.Angles(0, a, math.rad(15)), Color = c:Lerp(WHITE, 0.4),
				Material = Enum.Material.Glass, Transparency = 0.2 }, (p.duration or 3) + 0.3)
			if shard then
				tween(shard, 0.2, { Size = Vector3.new(0.5, 1.6 + (i % 3) * 0.4, 0.5), CFrame = CFrame.new(base + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, a, math.rad(15)) })
				task.delay(p.duration or 3, function()
					if shard.Parent then
						tween(shard, 0.25, { Transparency = 1 })
					end
				end)
			end
		end
		ring(p.at, 2.6, c:Lerp(WHITE, 0.5), 0.5)
	elseif k == "bossPower" and p.model then
		-- PODER de boss: aura na cor do poder em volta do boss pela duração
		local model = p.model :: Model
		local root = model.PrimaryPart
		local dur = p.duration or 2
		local look = {
			bark = { Color3.fromRGB(130, 92, 52), Enum.Material.Wood, 0.35 },
			mirror = { Color3.fromRGB(190, 240, 255), Enum.Material.Glass, 0.55 },
			static = { Color3.fromRGB(150, 200, 255), Enum.Material.ForceField, 0.2 },
			drain = { Color3.fromRGB(110, 50, 200), Enum.Material.ForceField, 0.15 },
			bloom = { Color3.fromRGB(150, 255, 160), Enum.Material.Neon, 0.6 },
		}
		local L = look[p.power] or { c, Enum.Material.ForceField, 0.3 }
		local r = (p.radius or 6) * 2.3
		local shell = root and part({ Shape = Enum.PartType.Ball, Size = Vector3.one * r, CFrame = root.CFrame, Color = L[1], Material = L[2], Transparency = 1 }, dur + 0.5)
		if shell then
			tween(shell, 0.3, { Transparency = L[3] })
			local conn
			conn = RunService.Heartbeat:Connect(function()
				if not shell.Parent or not root.Parent then
					conn:Disconnect()
					return
				end
				shell.CFrame = root.CFrame
			end)
			task.delay(math.max(0.2, dur - 0.3), function()
				if shell.Parent then
					tween(shell, 0.3, { Transparency = 1 })
				end
			end)
		end
		if p.power == "bloom" then
			onAbilityFx({ kind = "heal", at = p.at, radius = r, color = L[1] })
		elseif p.power == "static" and root then
			for i = 1, 4 do
				local a = i / 4 * math.pi * 2
				lightning(root.Position + Vector3.new(0, r * 0.4, 0), root.Position + Vector3.new(math.cos(a) * r * 0.7, -r * 0.2, math.sin(a) * r * 0.7), L[1], 0.4)
			end
		else
			shockRing(p.at, r * 0.8, L[1], 0.6)
		end
		sparks(p.at + Vector3.new(0, r * 0.3, 0), L[1], 16, 14)
	end
end
onAbilityFxRef = onAbilityFx

-------------------------------------------------------------------------------
-- Energia dos bosses: peças marcadas com o atributo EnergyFx (núcleo, olhos, punhos do Prism
-- Titan) pulsam em repouso, CARREGAM durante a preparação de um ataque (WindupEnd) e soltam uma
-- rajada de faíscas e luz no golpe (ActionAt).
-------------------------------------------------------------------------------

local energy: { [Model]: any } = {}
local bossStaging: (Model, any, Instance, number) -> ()

-- Cor da energia de uma peça (as malhas novas guardam a cor no atributo; a cor da MeshPart é branca).
local function energyColor(p: BasePart): Color3
	local c = p:GetAttribute("EnergyColor")
	return typeof(c) == "Color3" and c or p.Color
end

-- model: onde estão as peças EnergyFx; source: de onde vêm os atributos (o boss do servidor, quando o
-- visual é o boss novo do BossVisuals).
local function setupEnergy(model: Instance, source: Instance?, now: boolean?)
	if not now then
		task.wait()
	end
	if not model:IsA("Model") or energy[model :: Model] then
		return
	end
	if not source and model:GetAttribute("MeshVisual") then
		return -- o boss antigo está escondido: a energia vai para o visual novo
	end
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("EnergyFx") then
			local color = energyColor(d)
			-- reaproveita a luz/partículas se o visual já esteve na cena (sai e volta com a distância)
			local l = d:FindFirstChild("EnergyLight") :: PointLight?
			if not l then
				l = Instance.new("PointLight")
				l.Name = "EnergyLight"
				l.Color = color
				l.Range = 10
				l.Brightness = 0.6
				l.Shadows = false
				l.Parent = d
			end
			local e = d:FindFirstChild("EnergyEmit") :: ParticleEmitter?
			if not e then
				e = emit(d :: BasePart, { color = ColorSequence.new(WHITE, color), emission = 1, size = seq(0, 0.7, 1, 0), speed = NumberRange.new(2, 6),
					life = NumberRange.new(0.3, 0.6), drag = 3, z = 1 }, 0)
				e.Name = "EnergyEmit"
			end
			table.insert(list, { part = d, light = l, emit = e, color = color })
		end
	end
	local src = source or model
	if #list > 0 then
		energy[model :: Model] = { parts = list, lastAt = src:GetAttribute("ActionAt") or 0, source = src }
	end
end

-- O boss novo (BossVisuals) assumiu: tira a energia do modelo antigo e liga nas peças novas.
local function retargetEnergy(server: Model, visual: Model)
	local old = energy[server]
	if old then
		energy[server] = nil
		for _, p in ipairs(old.parts) do
			p.light:Destroy()
			p.emit:Destroy()
		end
	end
	setupEnergy(visual, server, true)
end

-- Pés e tamanho do boss (para o círculo de runas e o pilar de luz).
local function bossFootprint(model: Model): (Vector3, number)
	local cf, size = model:GetBoundingBox()
	local radius = math.clamp(math.max(size.X, size.Z) * 0.55, 6, 22)
	return cf.Position - Vector3.new(0, size.Y / 2, 0), radius
end

-- Preparação de um ataque de boss (mesma linguagem dos poderes dos pets): círculo de runas girando sob o
-- boss durante toda a preparação, energia convergindo para o núcleo no último segundo e, se for um PODER
-- (escudo, espelho, invocação...), o cut-in de anime com o nome. No golpe: pilar de luz e pulso na tela.
-- Só perto da câmera (e sem cut-in/pulso no modo de efeitos reduzidos).
bossStaging = function(model: Model, st, src: Instance, left: number)
	local cam = workspace.CurrentCamera
	local core = st.parts[1]
	if not cam or not core or not model.Parent then
		return
	end
	local feet, radius = bossFootprint(model)
	-- distância até o boss do servidor (o visual novo fica no mesmo lugar; o pivô do servidor é sempre confiável)
	local anchor = src:IsA("Model") and (src :: Model):GetPivot().Position or core.part.Position
	local dist = (cam.CFrame.Position - anchor).Magnitude
	if dist > 220 then
		return
	end
	local color = core.color
	local isPower = src:GetAttribute("AttackPower") == true
	castCircle(feet + Vector3.new(0, 1.7, 0), radius, color, left + 0.35)
	local gt = math.min(left, 1.1)
	task.delay(math.max(0, left - gt), function()
		if core.part.Parent then
			gather(core.part.Position, color, radius * 0.8, gt)
		end
	end)
	if isPower and not lowVfx() and dist < 140 then
		cutIn(tostring(src:GetAttribute("AttackLabel") or "Poder"), src.Name, color)
	end
	task.delay(left, function()
		if not model.Parent or src:GetAttribute("Dead") == true then
			return
		end
		local f2 = bossFootprint(model)
		afterglow(f2 + Vector3.new(0, 1, 0), color, radius * 0.5)
		if not lowVfx() and (cam.CFrame.Position - f2).Magnitude < 110 then
			screenPulse(color)
		end
	end)
end

local function updateEnergy()
	local now = workspace:GetServerTimeNow()
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 3)
	for model, st in pairs(energy) do
		if not model.Parent then
			energy[model] = nil
			continue
		end
		local src = st.source
		local wEnd = src:GetAttribute("WindupEnd") or 0
		local left = wEnd - now
		local charging = left > 0 and left < 3 and src:GetAttribute("Dead") ~= true
		local k = charging and (1 - math.clamp(left / 1.6, 0, 1)) or 0
		for _, p in ipairs(st.parts) do
			p.light.Brightness = 0.5 + pulse * 0.4 + k * 4
			p.light.Range = 10 + k * 14
			p.emit.Rate = charging and (lowVfx() and 12 or 40) or 0
		end
		-- energia elétrica (Tempest Wyrm): arcos curtos saltando das peças carregadas
		if charging and src:GetAttribute("EnergyKind") == "electric" and os.clock() - (st.lastArc or 0) > (lowVfx() and 0.35 or 0.12) then
			st.lastArc = os.clock()
			local pick = st.parts[math.random(1, #st.parts)]
			local off = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5) * 12
			lightning(pick.part.Position, pick.part.Position + off, pick.color, 0.25)
		end
		-- ENCENAÇÃO de cada ataque do boss (preparação nova = WindupEnd mudou)
		if wEnd ~= (st.lastWind or 0) then
			st.lastWind = wEnd
			if left > 0 and src:GetAttribute("Dead") ~= true then
				bossStaging(model, st, src, left)
			end
		end
		local at = src:GetAttribute("ActionAt") or 0
		if at > st.lastAt then
			st.lastAt = at
			if now - at < 1 then
				for _, p in ipairs(st.parts) do
					p.emit:Emit(lowVfx() and 6 or 16)
				end
				local core = st.parts[1]
				flash(core.part.Position, core.color, 30, 5, 0.4)
			end
		end
	end
end
Fx.updateEnergy = updateEnergy
Fx.trackEnergy = setupEnergy
Fx.retargetEnergy = retargetEnergy

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
	local model = PetMesh.display(species, mutation, nil)
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
	CreatureMotion.onStrike = slashArc
	folder = Instance.new("Folder")
	folder.Name = "LocalFx"
	folder.Parent = workspace.CurrentCamera
	debrisFolder = Instance.new("Folder")
	debrisFolder.Name = "LocalDebris"
	debrisFolder.Parent = workspace
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
		local hits = 0
		for _, ev in ipairs(list) do
			showNumber(ev)
			-- golpe que acertou: pequeno impacto no ponto (crítico = maior)
			if hits < 10 and (ev.k == "hit" or ev.k == "crit" or ev.k == "pet" or ev.k == "player") then
				hits += 1
				impact(ev.p, ev.k == "player" and Color3.fromRGB(255, 90, 80) or Color3.fromRGB(255, 230, 170), ev.c and 1 or 0.35)
			end
		end
	end)
	State.on("AbilityFx", onAbilityFx)
	task.spawn(function()
		local bf = workspace:WaitForChild("Bosses", 30)
		if bf then
			for _, m in ipairs(bf:GetChildren()) do
				task.spawn(setupEnergy, m)
			end
			bf.ChildAdded:Connect(function(m)
				task.spawn(setupEnergy, m)
			end)
		end
	end)
	local energyAcc = 0
	RunService.Heartbeat:Connect(function(dt)
		energyAcc += dt
		if energyAcc >= 1 / 30 then
			energyAcc = 0
			updateEnergy()
		end
	end)
	-- tremor de câmera aplicado depois do script de câmera padrão (prioridade Camera + 1 = 201)
	RunService:BindToRenderStep("FxShake", 201, function()
		if shakeAmp <= 0 then
			return
		end
		local left = shakeUntil - os.clock()
		local cam = workspace.CurrentCamera
		if left <= 0 or not cam then
			shakeAmp = 0
			return
		end
		local a = shakeAmp * math.min(1, left / 0.25)
		local t = os.clock() * 38
		cam.CFrame = cam.CFrame * CFrame.new(math.noise(t, 1.3) * a * 0.25, math.noise(2.7, t) * a * 0.25, 0)
			* CFrame.Angles(math.noise(t, 5.1) * a * 0.012, math.noise(7.9, t) * a * 0.012, 0)
	end)
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
Fx.play = onAbilityFx -- usado pelo simulador para exercitar todos os efeitos
return Fx

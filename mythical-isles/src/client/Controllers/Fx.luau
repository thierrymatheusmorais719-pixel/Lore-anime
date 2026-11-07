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
local debrisFolder: Folder -- fragmentos com física (peças dentro da Camera não são simuladas)
local activeParts = 0
local MAX_PARTS = 160
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
	end
end

-------------------------------------------------------------------------------
-- Energia dos bosses: peças marcadas com o atributo EnergyFx (núcleo, olhos, punhos do Prism
-- Titan) pulsam em repouso, CARREGAM durante a preparação de um ataque (WindupEnd) e soltam uma
-- rajada de faíscas e luz no golpe (ActionAt).
-------------------------------------------------------------------------------

local energy: { [Model]: any } = {}

local function setupEnergy(model: Instance)
	task.wait()
	if not model:IsA("Model") then
		return
	end
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("EnergyFx") then
			local l = Instance.new("PointLight")
			l.Color = d.Color
			l.Range = 10
			l.Brightness = 0.6
			l.Shadows = false
			l.Parent = d
			local e = emit(d :: BasePart, { color = ColorSequence.new(WHITE, d.Color), emission = 1, size = seq(0, 0.7, 1, 0), speed = NumberRange.new(2, 6),
				life = NumberRange.new(0.3, 0.6), drag = 3, z = 1 }, 0)
			table.insert(list, { part = d, light = l, emit = e })
		end
	end
	if #list > 0 then
		energy[model :: Model] = { parts = list, lastAt = model:GetAttribute("ActionAt") or 0 }
	end
end

local function updateEnergy()
	local now = workspace:GetServerTimeNow()
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 3)
	for model, st in pairs(energy) do
		if not model.Parent then
			energy[model] = nil
			continue
		end
		local wEnd = model:GetAttribute("WindupEnd") or 0
		local left = wEnd - now
		local charging = left > 0 and left < 3 and model:GetAttribute("Dead") ~= true
		local k = charging and (1 - math.clamp(left / 1.6, 0, 1)) or 0
		for _, p in ipairs(st.parts) do
			p.light.Brightness = 0.5 + pulse * 0.4 + k * 4
			p.light.Range = 10 + k * 14
			p.emit.Rate = charging and (lowVfx() and 12 or 40) or 0
		end
		local at = model:GetAttribute("ActionAt") or 0
		if at > st.lastAt then
			st.lastAt = at
			if now - at < 1 then
				for _, p in ipairs(st.parts) do
					p.emit:Emit(lowVfx() and 6 or 16)
				end
				local core = st.parts[1].part
				flash(core.Position, core.Color, 30, 5, 0.4)
			end
		end
	end
end
Fx.updateEnergy = updateEnergy

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

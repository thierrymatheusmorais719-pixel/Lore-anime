--!strict
-- Biblioteca de efeitos reutilizável. Todo efeito:
--   * nasce de uma origem (personagem/attachment/posição) com trajetória analítica e duração definidas;
--   * pertence a uma Session; Session:clean() remove tudo (cancelamento/fim);
--   * usa peças de um pool e um único laço Heartbeat compartilhado (zero conexões por efeito);
--   * respeita o orçamento do nível de qualidade (Low/Medium/High).
-- Os efeitos são locais (cada cliente os desenha a partir do mesmo evento replicado), então nada
-- precisa ser replicado individualmente pelo servidor.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Quality = require(script.Parent:WaitForChild("Quality"))

local VFX = {}

local BLUE = Color3.fromRGB(80, 170, 255)
local WHITE = Color3.fromRGB(238, 246, 255)
local BLACK = Color3.fromRGB(6, 6, 8)
local RED = Color3.fromRGB(190, 22, 34)
VFX.Colors = { Blue = BLUE, White = WHITE, Black = BLACK, Red = RED }

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

------------------------------------------------------------------------------------------------
-- Pool de peças + scheduler
------------------------------------------------------------------------------------------------
local folder: Folder? = nil
local pool: { [string]: { Part } } = {}
local activePartCount = 0
local MAX_PARTS = 220

type Actor = {
	t0: number,
	dur: number,
	update: (k: number, dt: number) -> (),
	finish: (() -> ())?,
	owner: any,
}
local actors: { Actor } = {}
local loopConn: RBXScriptConnection? = nil
local lastStep = 0

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "MugetsuVFX_Local"
	f.Parent = Workspace
	folder = f
	return f
end

local function acquire(shape: string): Part?
	if activePartCount >= MAX_PARTS then
		return nil
	end
	local list = pool[shape]
	local p = list and table.remove(list)
	if not p then
		p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		if shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
		else
			p.Shape = Enum.PartType.Block
		end
		p:SetAttribute("Shape", shape)
	end
	activePartCount += 1
	p.Material = Enum.Material.Neon
	p.Transparency = 0
	p.Parent = getFolder()
	return p
end

local function release(p: Part)
	activePartCount = math.max(0, activePartCount - 1)
	p.Parent = nil
	for _, c in p:GetChildren() do
		c:Destroy()
	end
	local shape = p:GetAttribute("Shape") :: string
	local list = pool[shape]
	if not list then
		list = {}
		pool[shape] = list
	end
	if #list < 80 then
		table.insert(list, p)
	else
		p:Destroy()
	end
end

local function loop()
	local now = os.clock()
	local dt = now - lastStep
	lastStep = now
	for i = #actors, 1, -1 do
		local a = actors[i]
		local k = (now - a.t0) / a.dur
		if k >= 1 then
			a.update(1, dt)
			if a.finish then
				a.finish()
			end
			table.remove(actors, i)
		else
			a.update(math.max(k, 0), dt)
		end
	end
	if #actors == 0 and loopConn then
		loopConn:Disconnect()
		loopConn = nil
	end
end

local function addActor(owner: any, dur: number, update: (number, number) -> (), finish: (() -> ())?): Actor
	local a: Actor = { t0 = os.clock(), dur = math.max(dur, 0.05), update = update, finish = finish, owner = owner }
	table.insert(actors, a)
	if not loopConn then
		lastStep = os.clock()
		loopConn = RunService.Heartbeat:Connect(loop)
	end
	return a
end

local function easeOut(k: number): number
	return 1 - (1 - k) * (1 - k)
end

------------------------------------------------------------------------------------------------
-- Session
------------------------------------------------------------------------------------------------
local Session = {}
Session.__index = Session
export type Session = typeof(setmetatable(
	{} :: { instances: { Instance }, myActors: { Actor }, q: any, aura: { emitters: { ParticleEmitter }, base: { number } }?, dead: boolean },
	Session
))

function VFX.session(): Session
	return setmetatable({ instances = {}, myActors = {}, q = Quality.settings(), aura = nil, dead = false }, Session)
end

local function track(self: Session, inst: Instance): Instance
	table.insert(self.instances, inst)
	return inst
end

local function run(self: Session, dur: number, update: (number, number) -> (), finish: (() -> ())?): Actor
	local a = addActor(self, dur, update, finish)
	table.insert(self.myActors, a)
	return a
end

function Session.clean(self: Session)
	self.dead = true
	for i = #actors, 1, -1 do
		local a = actors[i]
		if a.owner == self then
			if a.finish then
				pcall(a.finish)
			end
			table.remove(actors, i)
		end
	end
	for _, inst in self.instances do
		inst:Destroy() -- peças do pool nunca entram aqui: voltam ao pool no finish() do ator
	end
	self.instances = {}
	self.myActors = {}
	self.aura = nil
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

------------------------------------------------------------------------------------------------
-- Aura em camadas (fumaça escura + faíscas + fiapos nos braços), acompanha o corpo por Attachments
------------------------------------------------------------------------------------------------
function Session.auraStart(self: Session, char: Model, palette: string)
	if self.aura then
		return
	end
	local black = palette ~= "Blue"
	local col = black and BLACK or BLUE
	local spark = black and ColorSequence.new(WHITE, RED) or ColorSequence.new(WHITE, BLUE)
	local sc = self.q.ParticleScale
	local emitters: { ParticleEmitter } = {}
	local base: { number } = {}
	local function add(attName: string, props: { [string]: any }, rate: number)
		local at = char:FindFirstChild(attName, true)
		if at and at:IsA("Attachment") then
			props.Rate = 0
			props.Enabled = true
			local e = emitter(at, props)
			table.insert(emitters, e)
			table.insert(base, rate * sc)
			track(self, e)
		end
	end
	add("AuraFeet", {
		Texture = SMOKE, Color = ColorSequence.new(col), LightEmission = 0, Lifetime = NumberRange.new(1.4, 2.4),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
		Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(30, 30), Acceleration = Vector3.new(0, 7, 0),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-25, 25),
		EmissionDirection = Enum.NormalId.Top, Orientation = Enum.ParticleOrientation.FacingCamera,
	}, 22)
	add("AuraChest", {
		Texture = SMOKE, Color = ColorSequence.new(col), LightEmission = 0, Lifetime = NumberRange.new(0.9, 1.6),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 3.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 4, 0),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40),
	}, 12)
	add("AuraChest", {
		Texture = SPARK, Color = spark, LightEmission = 1, Lifetime = NumberRange.new(0.5, 1.1),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0),
		Speed = NumberRange.new(5, 11), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 2, 0),
	}, 18)
	for _, n in { "AuraRArm", "AuraLArm", "AuraHand" } do
		add(n, {
			Texture = SMOKE, Color = ColorSequence.new(col), LightEmission = 0, Lifetime = NumberRange.new(0.6, 1.1),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1.8) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, 5, 0),
			Rotation = NumberRange.new(0, 360),
		}, 9)
	end
	self.aura = { emitters = emitters, base = base }
end

function Session.auraIntensity(self: Session, intensity: number)
	local a = self.aura
	if not a then
		return
	end
	for i, e in a.emitters do
		e.Rate = a.base[i] * intensity
	end
end

function Session.auraStop(self: Session)
	if self.aura then
		for _, e in self.aura.emitters do
			e.Rate = 0
		end
	end
end

------------------------------------------------------------------------------------------------
-- Anéis, ondas de choque
------------------------------------------------------------------------------------------------
-- Anel VAZADO sem assets: peça plana invisível com SurfaceGui (Frame redondo só com contorno).
-- (Uma peça Cylinder é maciça e viraria um disco tampando o chão.)
function Session.ring(self: Session, origin: CFrame, maxRadius: number, duration: number, color: Color3, thickness: number, tilt: CFrame?)
	local p = acquire("Block")
	if not p then
		return
	end
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = 1
	local base = origin * (tilt or CFrame.identity)
	local strokes: { UIStroke } = {}
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.LightInfluence = 0
		sg.Brightness = 2
		sg.CanvasSize = Vector2.new(512, 512)
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.Parent = p
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.Parent = sg
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
		local st = Instance.new("UIStroke")
		st.Color = color
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Thickness = 8
		st.Parent = f
		table.insert(strokes, st)
	end
	run(self, duration, function(k)
		local r = math.max(maxRadius * easeOut(k), 0.5)
		p.Size = Vector3.new(r * 2, 0.2, r * 2)
		p.CFrame = base
		-- espessura em studs convertida para pixels do canvas (512 px cobrem 2r studs)
		local px = math.max(1, thickness * (1 - k * 0.7) * 256 / r)
		for _, st in strokes do
			st.Thickness = px
			st.Transparency = k ^ 2
		end
	end, function()
		release(p)
	end)
end

-- Cúpula translúcida + poeira: lê como onda de pressão, sem tapar o personagem.
function Session.shockwave(self: Session, origin: CFrame, radius: number, duration: number, color: Color3)
	local p = acquire("Ball")
	if p then
		p.Color = color
		p.Material = Enum.Material.ForceField
			run(self, duration, function(k)
			local r = radius * easeOut(k)
			p.Size = Vector3.new(r * 2, r * 0.6, r * 2)
			p.CFrame = origin
			p.Transparency = 0.4 + 0.6 * k
		end, function()
			release(p)
		end)
	end
	self:ring(origin, radius * 1.15, duration * 0.9, WHITE, 0.6)
	self:ring(origin, radius * 0.8, duration * 0.7, color, 0.4)
end

function Session.dustBurst(self: Session, position: Vector3, amount: number, color: Color3?)
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.one
	a.Position = position
	a.Parent = getFolder()
	track(self, a)
	local e = emitter(a, {
		Texture = SMOKE, Color = ColorSequence.new(color or Color3.fromRGB(150, 130, 100)), Rate = 0,
		Lifetime = NumberRange.new(1.2, 2.2),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 11) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Speed = NumberRange.new(18, 34), SpreadAngle = Vector2.new(90, 5), Drag = 3,
		EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360),
	})
	e:Emit(math.max(1, math.floor(amount * self.q.ParticleScale)))
	task.delay(3, function()
		a:Destroy()
	end)
end

------------------------------------------------------------------------------------------------
-- Fragmentos com trajetória: "burst" (balístico), "rise" (sobe do chão e orbita), "converge" (para um alvo)
------------------------------------------------------------------------------------------------
function Session.shards(self: Session, origin: Vector3, mode: string, count: number, duration: number, color: Color3, target: (() -> Vector3)?)
	local n = math.min(count, self.q.Shards)
	if n <= 0 then
		return
	end
	local rng = Random.new(math.floor(origin.X * 31 + origin.Z * 17 + n))
	type Sh = { part: Part, p0: Vector3, v0: Vector3, spin: Vector3, size: number, phase: number, radius: number }
	local list: { Sh } = {}
	for i = 1, n do
		local p = acquire("Block")
		if not p then
			break
		end
		p.Color = color
		local s = rng:NextNumber(0.25, 0.9)
		p.Size = Vector3.new(s * 0.5, s * 1.6, s * 0.4)
			local a = rng:NextNumber(0, math.pi * 2)
		local sh: Sh = { part = p, p0 = origin, v0 = Vector3.zero, spin = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-6, 6), rng:NextNumber(-6, 6)), size = s, phase = a, radius = rng:NextNumber(4, 14) }
		if mode == "burst" then
			local speed = rng:NextNumber(18, 70)
			sh.v0 = Vector3.new(math.cos(a) * speed, rng:NextNumber(10, 34), math.sin(a) * speed)
		elseif mode == "rise" then
			sh.p0 = origin + Vector3.new(math.cos(a) * sh.radius, 0, math.sin(a) * sh.radius)
			sh.v0 = Vector3.new(0, rng:NextNumber(5, 12), 0)
		else
			sh.p0 = origin + Vector3.new(math.cos(a) * sh.radius * 2.2, rng:NextNumber(0, 6), math.sin(a) * sh.radius * 2.2)
		end
		table.insert(list, sh)
	end
	run(self, duration, function(k)
		local t = k * duration
		local goal = target and target() or origin + Vector3.new(0, 3, 0)
		for _, sh in list do
			local pos: Vector3
			if mode == "burst" then
				pos = sh.p0 + sh.v0 * t + Vector3.new(0, -0.5 * 60 * t * t, 0)
				pos = Vector3.new(pos.X, math.max(pos.Y, origin.Y + 0.2), pos.Z)
			elseif mode == "rise" then
				local ang = sh.phase + t * 0.9
				local r = sh.radius * (1 - 0.25 * k)
				pos = Vector3.new(origin.X + math.cos(ang) * r, origin.Y + sh.v0.Y * t, origin.Z + math.sin(ang) * r)
			else
				local e = k * k
				pos = sh.p0:Lerp(goal, e)
			end
			sh.part.CFrame = CFrame.new(pos) * CFrame.Angles(sh.spin.X * t, sh.spin.Y * t, sh.spin.Z * t)
			sh.part.Transparency = mode == "converge" and (k > 0.85 and (k - 0.85) / 0.15 or 0) or math.clamp((k - 0.6) / 0.4, 0, 1)
		end
	end, function()
		for _, sh in list do
			release(sh.part)
		end
	end)
end

-- Gather contínuo: gera pequenos lotes convergindo para o peito (energia se acumulando).
function Session.gather(self: Session, char: Model, duration: number, color: Color3)
	local chest = char:FindFirstChild("UpperTorso") :: BasePart?
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (chest and root) then
		return
	end
	local floorPos = root.Position - Vector3.new(0, 2.9, 0)
	local acc = 0
	run(self, duration, function(k, dt)
		acc += dt * (4 + 10 * k) * self.q.ParticleScale
		while acc >= 1 do
			acc -= 1
			self:shards(floorPos, "converge", 3, 0.9 + (1 - k) * 0.4, color, function()
				return chest.Position
			end)
		end
	end)
end

------------------------------------------------------------------------------------------------
-- Luzes, pilar, tentáculos, rastro
------------------------------------------------------------------------------------------------
function Session.lightPulse(self: Session, position: Vector3, color: Color3, brightness: number, range: number, duration: number)
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.one
	a.Position = position
	a.Parent = getFolder()
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = a
	track(self, a)
	run(self, duration, function(k)
		l.Brightness = brightness * (1 - k) ^ 2
	end, function()
		a:Destroy()
	end)
end

function Session.spire(self: Session, base: Vector3, height: number, duration: number, color: Color3)
	local outer = acquire("Cylinder")
	local inner = acquire("Cylinder")
	if not (outer and inner) then
		return
	end
	outer.Color = color
	outer.Transparency = 0.45
	inner.Color = WHITE
	local up = CFrame.Angles(0, 0, math.rad(90))
	run(self, duration, function(k)
		local grow = easeOut(math.min(k / 0.25, 1))
		local fadeOut = k > 0.75 and (k - 0.75) / 0.25 or 0
		local h = height * grow
		local w = (1 - fadeOut) * (7 + math.sin(k * 40) * 0.5)
		outer.Size = Vector3.new(h, w * 1.6, w * 1.6)
		inner.Size = Vector3.new(h, w * 0.6, w * 0.6)
		local cf = CFrame.new(base + Vector3.new(0, h / 2, 0)) * up
		outer.CFrame = cf
		inner.CFrame = cf
		outer.Transparency = 0.45 + 0.55 * fadeOut
		inner.Transparency = fadeOut
	end, function()
		release(outer)
		release(inner)
	end)
	self:lightPulse(base + Vector3.new(0, 8, 0), color, 6, 90, duration * 0.8)
end

-- Fitas negras (Beam) caindo sobre o personagem: tentáculos de energia escura legíveis sobre o branco.
function Session.tendrils(self: Session, center: Vector3, count: number, duration: number)
	local n = math.max(2, math.floor(count * self.q.ParticleScale))
	local rng = Random.new(77)
	for i = 1, n do
		local ang = (i / n) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local rad = rng:NextNumber(3, 11)
		local anchorTop = Instance.new("Part")
		anchorTop.Anchored = true
		anchorTop.CanCollide = false
		anchorTop.CanQuery = false
		anchorTop.CanTouch = false
		anchorTop.Transparency = 1
		anchorTop.Size = Vector3.one
		anchorTop.Parent = getFolder()
		track(self, anchorTop)
		local a0 = Instance.new("Attachment")
		a0.Parent = anchorTop
		local a1 = Instance.new("Attachment")
		a1.Parent = anchorTop
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(BLACK)
		beam.LightEmission = 0
		beam.FaceCamera = true
		beam.Segments = 12
		beam.CurveSize0 = rng:NextNumber(-7, 7)
		beam.CurveSize1 = rng:NextNumber(-5, 5)
		beam.Width0 = rng:NextNumber(1.6, 3.2)
		beam.Width1 = 0.1
		beam.Transparency = NumberSequence.new(0)
		beam.Parent = anchorTop
		local top = center + Vector3.new(math.cos(ang) * rad, 20 + rng:NextNumber(0, 10), math.sin(ang) * rad)
		local bottom = center + Vector3.new(math.cos(ang) * rad * 0.35, 0.5, math.sin(ang) * rad * 0.35)
		local delay = rng:NextNumber(0, 0.35)
		run(self, duration, function(k)
			local kk = math.clamp((k - delay) / (1 - delay), 0, 1)
			local fall = easeOut(math.min(kk / 0.4, 1))
			local fade = kk > 0.7 and (kk - 0.7) / 0.3 or 0
			anchorTop.Position = top
			a0.WorldPosition = top:Lerp(bottom, fall * 0.35)
			a1.WorldPosition = top:Lerp(bottom, fall)
			beam.Transparency = NumberSequence.new(fade)
		end, function()
			anchorTop:Destroy()
		end)
	end
end

-- Luz de preenchimento presa à cabeça: mantém o rosto legível nos closes sob iluminação escura.
function Session.faceLight(self: Session, char: Model, color: Color3, brightness: number, range: number)
	local head = char:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local at = Instance.new("Attachment")
	at.Name = "MugetsuFaceLight"
	at.Position = Vector3.new(0.6, 0.5, -2.4)
	at.Parent = head
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = at
	track(self, at)
end

function Session.swordTrail(self: Session, blade: BasePart, duration: number)
	local a, b = blade:FindFirstChild("TrailA"), blade:FindFirstChild("TrailB")
	if not (a and b) then
		return
	end
	local function mk(color: Color3, width: number, emission: number)
		local t = Instance.new("Trail")
		t.Attachment0 = a :: Attachment
		t.Attachment1 = b :: Attachment
		t.Lifetime = 0.4
		t.Color = ColorSequence.new(color)
		t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, width), NumberSequenceKeypoint.new(1, 0) })
		t.LightEmission = emission
		t.FaceCamera = true
		t.MinLength = 0.05
		t.Parent = blade
		track(self, t)
		return t
	end
	-- TrailA = base da lâmina, TrailB = ponta: largura 1 = lâmina inteira (arco de corte)
	mk(BLACK, 1, 0)
	mk(WHITE, 0.35, 1)
	task.delay(duration, function()
		-- os Trails são destruídos por Session:clean(); aqui só desligamos a emissão
		for _, c in blade:GetChildren() do
			if c:IsA("Trail") then
				c.Enabled = false
			end
		end
	end)
end

function Session.glint(self: Session, blade: BasePart)
	local tip = blade:FindFirstChild("Tip")
	if tip and tip:IsA("Attachment") then
		self:lightPulse(tip.WorldPosition, WHITE, 5, 14, 0.5)
		local e = emitter(tip, {
			Texture = SPARK, Color = ColorSequence.new(WHITE), LightEmission = 1, Rate = 0, Lifetime = NumberRange.new(0.3, 0.6),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
			Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(180, 180),
		})
		track(self, e)
		e:Emit(math.floor(14 * self.q.ParticleScale) + 2)
	end
end

------------------------------------------------------------------------------------------------
-- Reação do cenário: as peças tagueadas tremem LOCALMENTE e voltam exatamente à posição original.
------------------------------------------------------------------------------------------------
function Session.environmentReact(self: Session, origin: Vector3, radius: number, strength: number, duration: number)
	local items: { { part: BasePart, cf: CFrame, amp: number, dist: number } } = {}
	for _, inst in CollectionService:GetTagged("MugetsuReactive") do
		if inst:IsA("BasePart") and inst.Anchored then
			local d = (inst.Position - origin).Magnitude
			if d <= radius then
				table.insert(items, { part = inst, cf = inst.CFrame, amp = (inst:GetAttribute("ReactAmp") :: number? or 1) * strength, dist = d })
			end
		end
	end
	table.sort(items, function(a, b)
		return a.dist < b.dist
	end)
	for i = 1, math.min(#items, 6) do
		self:dustBurst(items[i].part.Position - Vector3.new(0, items[i].part.Size.Y / 2 - 1, 0), 10, nil)
	end
	if #items == 0 then
		return
	end
	run(self, duration, function(k)
		for _, it in items do
			-- onda: atraso proporcional à distância para a reação "viajar" pelo cenário
			local delay = math.clamp(it.dist / radius, 0, 1) * 0.35
			local kk = math.clamp((k - delay) / (1 - delay), 0, 1)
			local d = (1 - kk) ^ 2 * it.amp * (k > delay and 1 or 0)
			local t = os.clock() * 38
			if it.part.Parent then
				it.part.CFrame = it.cf * CFrame.new(math.sin(t + it.dist) * 0.25 * d, math.sin(t * 1.3) * 0.12 * d, math.cos(t * 0.9) * 0.25 * d)
			end
		end
	end, function()
		for _, it in items do
			if it.part.Parent then
				it.part.CFrame = it.cf
			end
		end
	end)
end

-- Projétil do Getsuga: crescente vertical (arco de segmentos que afinam nas pontas) negro com borda
-- branca. Posição = origem + dir * velocidade * (tempo do servidor), igual em todos os clientes.
function Session.projectile(self: Session, origin: Vector3, dir: Vector3, speed: number, range: number, width: number, serverStart: number)
	local SEG = 11
	local radius = width * 0.6
	local maxAngle = math.rad(68)
	local core: { Part } = {}
	local rim: { Part } = {}
	for i = 1, SEG do
		local c = acquire("Block")
		local r = acquire("Block")
		if not (c and r) then
			if c then
				release(c)
			end
			if r then
				release(r)
			end
			break
		end
		c.Color = BLACK
		c.Material = Enum.Material.SmoothPlastic
		r.Color = WHITE
		table.insert(core, c)
		table.insert(rim, r)
	end
	if #core == 0 then
		return
	end
	local emitterPart = Instance.new("Part")
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.one
	emitterPart.Parent = getFolder()
	track(self, emitterPart)
	local trail = emitter(emitterPart, {
		Texture = SMOKE, Color = ColorSequence.new(BLACK), LightEmission = 0, Rate = 40 * self.q.ParticleScale,
		Lifetime = NumberRange.new(0.5, 0.9),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, width * 0.4), NumberSequenceKeypoint.new(1, width * 0.8) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Speed = NumberRange.new(0, 2), SpreadAngle = Vector2.new(25, 25),
	})
	local basis = CFrame.lookAt(Vector3.zero, dir)
	local n = #core
	local segLen = 2 * radius * math.sin(maxAngle) / (n - 1) * 1.15
	local duration = range / speed
	local startDelay = math.max(0, serverStart - Workspace:GetServerTimeNow())
	run(self, duration + startDelay, function()
		local d = math.clamp((Workspace:GetServerTimeNow() - serverStart) * speed, 0, range)
		local pos = origin + dir * d
		local fade = math.clamp((d - range * 0.8) / (range * 0.2), 0, 1)
		local frame = CFrame.new(pos) * basis.Rotation
		for i = 1, n do
			local theta = -maxAngle + (i - 1) / (n - 1) * 2 * maxAngle
			local thick = 0.3 + 1.3 * math.cos(theta / maxAngle * math.pi / 2)
			local local_ = CFrame.new(0, radius * math.sin(theta), -(radius * math.cos(theta) - radius)) * CFrame.Angles(-theta, 0, 0)
			core[i].Size = Vector3.new(width * 0.35, segLen, thick)
			core[i].CFrame = frame * local_
			core[i].Transparency = fade
			rim[i].Size = Vector3.new(width * 0.3, segLen, 0.18)
			rim[i].CFrame = frame * local_ * CFrame.new(0, 0, -(thick / 2 + 0.05))
			rim[i].Transparency = fade
		end
		emitterPart.Position = pos
	end, function()
		trail.Rate = 0
		for i = 1, n do
			release(core[i])
			release(rim[i])
		end
		task.delay(1, function()
			emitterPart:Destroy()
		end)
	end)
end

function VFX.activeParts(): number
	return activePartCount
end

function VFX.activeActors(): number
	return #actors
end

return VFX

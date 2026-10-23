-- Presença dos Hollows (tudo local, visual):
--   • Garganta: ao surgir, um rasgo negro de bordas vermelhas abre no ar, a criatura sai dele
--     envolta em fumaça escura e o rasgo fecha
--   • aura de reiatsu sombria: fumaça escura subindo do tronco, brasas na cor dos olhos, wisps
--     saindo do buraco do peito
--   • olhos acesos (luz + rastro que risca o ar quando ela corre)
--   • morte: a máscara racha (clarão), estilhaça em pedaços que giram e caem, e o corpo se
--     desfaz em partículas escuras que sobem
-- Qualidade "Low" corta luzes, rastros e metade das partículas.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local VFX = require(script.Parent.VFXController)
local SoundController = require(script.Parent.SoundController)
local CameraController = require(script.Parent.CameraController)

local HollowFx = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local BLACK = Color3.new(0, 0, 0)
local RIFT_EDGE = Color3.fromRGB(220, 30, 52)

local decorated: { [Model]: boolean } = {}
local rng = Random.new()

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

local function low(): boolean
	return VFX.Quality() == "Low"
end

local function eyeColor(model: Model): Color3
	for _, d in model:GetDescendants() do
		if d.Name == "Eye" and d:IsA("BasePart") then
			return d.Color
		end
	end
	return RIFT_EDGE
end

-- ======================================================================= presença
function HollowFx.Decorate(model: Model)
	if decorated[model] then
		return
	end
	local torso = model:FindFirstChild("UpperTorso") :: BasePart?
	if not torso then
		return
	end
	decorated[model] = true
	local scale = (model:GetAttribute("AnimScale") :: number?) or 1
	local glow = eyeColor(model)

	-- fumaça escura subindo do tronco (lenta, LightEmission 0: lê como sombra, não como brilho)
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "HollowAura"
	aura.Texture = SMOKE
	aura.LightEmission = 0
	aura.LightInfluence = 0.3
	aura.Color = ColorSequence.new(Color3.fromRGB(18, 10, 24), BLACK)
	aura.Size = seq({ { 0, 1.2 * scale }, { 1, 3.2 * scale } })
	aura.Transparency = seq({ { 0, 1 }, { 0.2, 0.55 }, { 1, 1 } })
	aura.Lifetime = NumberRange.new(1.2, 2)
	aura.Speed = NumberRange.new(1.5, 3)
	aura.SpreadAngle = Vector2.new(30, 30)
	aura.Acceleration = Vector3.new(0, 2, 0)
	aura.Rotation = NumberRange.new(0, 360)
	aura.RotSpeed = NumberRange.new(-25, 25)
	aura.Rate = if low() then 3 else 7
	aura.Parent = torso

	-- brasas na cor dos olhos
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "HollowEmbers"
	embers.Texture = SPARK
	embers.LightEmission = 1
	embers.Brightness = 3
	embers.Color = ColorSequence.new(glow)
	embers.Size = seq({ { 0, 0 }, { 0.2, 0.18 * scale }, { 1, 0 } })
	embers.Lifetime = NumberRange.new(0.8, 1.4)
	embers.Speed = NumberRange.new(2, 5)
	embers.SpreadAngle = Vector2.new(60, 60)
	embers.Acceleration = Vector3.new(0, 4, 0)
	embers.Rate = if low() then 1 else 4
	embers.Parent = torso

	-- wisps do buraco do peito
	local hole = Instance.new("Attachment")
	hole.Name = "HoleWisps"
	hole.Position = Vector3.new(0, 0.05, -torso.Size.Z / 2 - 0.1)
	hole.Parent = torso
	local wisps = Instance.new("ParticleEmitter")
	wisps.Texture = SMOKE
	wisps.LightEmission = 0
	wisps.Color = ColorSequence.new(BLACK)
	wisps.Size = seq({ { 0, 0.3 * scale }, { 1, 1.1 * scale } })
	wisps.Transparency = seq({ { 0, 0.4 }, { 1, 1 } })
	wisps.Lifetime = NumberRange.new(0.6, 1)
	wisps.Speed = NumberRange.new(1.5, 3)
	wisps.EmissionDirection = Enum.NormalId.Front
	wisps.SpreadAngle = Vector2.new(15, 15)
	wisps.Acceleration = Vector3.new(0, 1.5, 0)
	wisps.Rate = if low() then 2 else 5
	wisps.Parent = hole

	-- olhos: luz e rastro (só aparece quando ela se move rápido)
	if not low() then
		for _, eye in model:GetDescendants() do
			if eye.Name == "Eye" and eye:IsA("BasePart") then
				local light = Instance.new("PointLight")
				light.Color = eye.Color
				light.Range = 5 * scale
				light.Brightness = 1.6
				light.Shadows = false
				light.Parent = eye
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(0, eye.Size.Y * 0.35, 0)
				a0.Parent = eye
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, -eye.Size.Y * 0.35, 0)
				a1.Parent = eye
				local trail = Instance.new("Trail")
				trail.Attachment0 = a0
				trail.Attachment1 = a1
				trail.Lifetime = 0.22
				trail.MinLength = 0.15
				trail.LightEmission = 1
				trail.Brightness = 3
				trail.FaceCamera = true
				trail.Color = ColorSequence.new(eye.Color)
				trail.Transparency = seq({ { 0, 0.1 }, { 1, 1 } })
				trail.WidthScale = seq({ { 0, 1 }, { 1, 0 } })
				trail.Parent = eye
			end
		end
	end
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			decorated[model] = nil
		end
	end)
end

-- ======================================================================= Garganta
local function hideLocally(model: Model, hidden: boolean): RBXScriptConnection?
	local value = if hidden then 1 else 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = value
		end
	end
	if hidden then
		-- peles e enfeites que chegarem durante a chegada também ficam escondidos
		return model.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			end
		end)
	end
	return nil
end

function HollowFx.Garganta(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - root.Position).Magnitude > 160 then
		return
	end
	local scale = (model:GetAttribute("AnimScale") :: number?) or 1
	local height = (humanoid.HipHeight + root.Size.Y) * 1.25 + 1
	local base = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local facing = root.CFrame.LookVector
	local riftCenter = base + Vector3.new(0, height / 2, 0) - facing * (1.2 * scale)
	local frame = CFrame.lookAt(riftCenter, riftCenter + facing)

	local holdConnection = hideLocally(model, true)
	local folder = Instance.new("Model")
	folder.Name = "Garganta"
	folder.Parent = workspace

	-- rasgo em zigue-zague: segmentos pretos com borda acesa, abre na largura
	local segments = 7
	local pieces = {}
	for i = 1, segments do
		local y0 = -height / 2 + (i - 1) * height / segments
		local y1 = y0 + height / segments
		local x0 = if i % 2 == 0 then 0.35 * scale else -0.35 * scale
		local x1 = -x0
		local a = Vector3.new(x0, y0, 0)
		local b = Vector3.new(x1, y1, 0)
		local mid = (a + b) / 2
		local length = (b - a).Magnitude
		local angle = math.atan2(b.X - a.X, b.Y - a.Y)
		local cf = frame * CFrame.new(mid) * CFrame.Angles(0, 0, -angle)
		local edge = Instance.new("Part")
		edge.Anchored = true
		edge.CanCollide = false
		edge.CanQuery = false
		edge.CanTouch = false
		edge.CastShadow = false
		edge.Material = Enum.Material.Neon
		edge.Color = RIFT_EDGE
		edge.Size = Vector3.new(0.05, length, 0.12)
		edge.CFrame = cf
		edge.Parent = folder
		local void = edge:Clone()
		void.Material = Enum.Material.SmoothPlastic
		void.Color = BLACK
		void.Size = Vector3.new(0.02, length, 0.1)
		void.Parent = folder
		table.insert(pieces, { edge = edge, void = void, length = length })
	end
	SoundController.Play("Release", root)
	-- abre: o vazio alarga (borda acompanha), depois a criatura sai e o rasgo fecha
	for _, p in pieces do
		tween(p.void, 0.35, { Size = Vector3.new(2.6 * scale, p.length, 0.1) }, Enum.EasingStyle.Back)
		tween(p.edge, 0.35, { Size = Vector3.new(2.9 * scale, p.length, 0.08) }, Enum.EasingStyle.Back)
	end
	local light = Instance.new("PointLight")
	light.Color = RIFT_EDGE
	light.Range = 14 * scale
	light.Brightness = 3
	light.Parent = pieces[math.ceil(segments / 2)].edge

	task.delay(0.45, function()
		if holdConnection then
			holdConnection:Disconnect()
		end
		if model.Parent then
			hideLocally(model, false)
			VFX.emit("Dust", base, Color3.fromRGB(30, 18, 34), 14)
			VFX.Shockwave(base + Vector3.new(0, 0.2, 0), RIFT_EDGE, 7 * scale, 0.45, 0.12)
			SoundController.Play("Roar", root)
			if camera and (camera.CFrame.Position - root.Position).Magnitude < 45 then
				CameraController.Shake(0.15)
			end
		end
	end)
	task.delay(1.0, function()
		for _, p in pieces do
			tween(
				p.void,
				0.3,
				{ Size = Vector3.new(0.02, p.length * 0.6, 0.1), Transparency = 1 },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			tween(
				p.edge,
				0.3,
				{ Size = Vector3.new(0.02, p.length * 0.6, 0.08), Transparency = 1 },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
		end
		tween(light, 0.3, { Brightness = 0 })
		Debris:AddItem(folder, 0.4)
	end)
end

-- ======================================================================= morte
function HollowFx.Shatter(model: Model)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local scale = (model:GetAttribute("AnimScale") :: number?) or 1
	local glow = eyeColor(model)
	-- 1) racha: clarão branco na máscara
	task.delay(0.25, function()
		if not head.Parent then
			return
		end
		VFX.Flash(head.Position, Color3.new(1, 1, 1), 2.5 * scale, 0.15)
		SoundController.Play("Parry", head)
	end)
	-- 2) estilhaça: cópias locais dos pedaços da máscara/ossos voam girando e caem
	task.delay(0.4, function()
		if not head.Parent then
			return
		end
		local count = 0
		for _, piece in head:GetChildren() do
			if piece:IsA("BasePart") and (piece.Name == "Mask" or piece.Name == "Bone") then
				count += 1
				if count > (if low() then 6 else 16) then
					break
				end
				local shard = piece:Clone()
				for _, j in shard:GetChildren() do
					if j:IsA("JointInstance") or j:IsA("Constraint") then
						j:Destroy()
					end
				end
				shard.Anchored = true
				shard.CanCollide = false
				shard.Parent = workspace
				piece.LocalTransparencyModifier = 1
				local away = (piece.Position - head.Position)
				if away.Magnitude < 0.05 then
					away = head.CFrame.LookVector
				end
				local fly = away.Unit * rng:NextNumber(3, 6) * scale + Vector3.new(0, rng:NextNumber(1, 3) * scale, 0)
				local landing = piece.Position + fly - Vector3.new(0, 4 * scale, 0)
				tween(shard, 0.9, {
					CFrame = CFrame.new(landing)
						* CFrame.Angles(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), rng:NextNumber(-3, 3)),
					Transparency = 1,
				}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				Debris:AddItem(shard, 1)
			end
		end
		VFX.emit("Spark", head.Position, Color3.new(1, 1, 1), 14)
	end)
	-- 3) o corpo se desfaz em partículas escuras que sobem (na cor dos olhos por dentro)
	task.delay(0.6, function()
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				local e = Instance.new("ParticleEmitter")
				e.Texture = SMOKE
				e.LightEmission = 0.2
				e.Color = ColorSequence.new(glow:Lerp(BLACK, 0.6), BLACK)
				e.Size = seq({ { 0, 0.5 * scale }, { 1, 1.6 * scale } })
				e.Transparency = seq({ { 0, 0.3 }, { 1, 1 } })
				e.Lifetime = NumberRange.new(0.8, 1.4)
				e.Speed = NumberRange.new(2, 5)
				e.Acceleration = Vector3.new(0, 6, 0)
				e.SpreadAngle = Vector2.new(40, 40)
				e.Enabled = false
				e.Parent = part
				e:Emit(if low() then 2 else 6)
			end
		end
	end)
end

function HollowFx.Init() end

function HollowFx.Start()
	local function watch(folder: Instance)
		local function try(child: Instance)
			if not child:IsA("Model") then
				return
			end
			task.defer(function()
				local model = child :: Model
				if model:GetAttribute("Creature") == nil then
					model:GetAttributeChangedSignal("Creature"):Wait()
				end
				model:WaitForChild("UpperTorso", 5)
				local entrance = model:GetAttribute("Entrance") :: number?
				if entrance and workspace:GetServerTimeNow() - entrance < 1 then
					HollowFx.Garganta(model)
				end
				HollowFx.Decorate(model)
			end)
		end
		for _, child in folder:GetChildren() do
			try(child)
		end
		folder.ChildAdded:Connect(try)
	end
	for _, name in { "Enemies", "Bosses" } do
		task.spawn(function()
			watch(workspace:WaitForChild(name))
		end)
	end
end

return HollowFx

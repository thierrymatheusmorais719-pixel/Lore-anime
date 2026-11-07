-- Atmosfera por ilha (iluminação, névoa, correção de cor), clima de batalha de boss por fase,
-- barras de vida flutuantes dos inimigos/recursos e feedback de dano no jogador.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local AnimeSky = require(Shared.Builders.AnimeSky)
local UIKit = require(script.Parent.UIKit)

local WorldClient = {}
local player = Players.LocalPlayer
local atmosphere, cc, bloom, sunrays
local currentWorld = nil
local bars: { [Instance]: any } = {}

local clouds, depth

local function setupLighting()
	-- os efeitos já vêm no place (default.project.json); aqui só garantimos que existam
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	cc = Lighting:FindFirstChild("WorldTint") or Instance.new("ColorCorrectionEffect")
	cc.Name = "WorldTint"
	cc.Parent = Lighting
	bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.45
	bloom.Size = 28
	bloom.Threshold = 1.8 -- só o que é bem brilhante (Neon) floresce
	bloom.Parent = Lighting
	sunrays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	sunrays.Spread = 0.7
	sunrays.Parent = Lighting
	depth = Lighting:FindFirstChildOfClass("DepthOfFieldEffect") or Instance.new("DepthOfFieldEffect")
	depth.NearIntensity = 0
	depth.Parent = Lighting
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.StarCount = 3000
		sky.SunAngularSize = 14
		sky.Parent = Lighting
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Parent = terrain
	end
	-- iluminação física: reflexos do céu nos materiais, sombras suaves
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.22
	Lighting.GeographicLatitude = 35
end

-- Perfil de "clima" de cada ilha: névoa (Atmosphere), nuvens, cor, raios de sol e profundidade de campo.
local PROFILES = {
	verdant = { fog = Color3.fromRGB(196, 226, 232), decay = Color3.fromRGB(104, 150, 176), density = 0.3, offset = 0.2, haze = 1.6, glare = 0.3,
		sat = 0.1, contrast = 0.08, tint = Color3.fromRGB(255, 252, 244), rays = 0.12, cover = 0.55, cloudDensity = 0.4, exposure = 0.15, bright = 3 },
	-- Crystal Hollow: tarde clara de céu azul (como na arte de referência), névoa azul-violeta leve
	crystal = { fog = Color3.fromRGB(176, 192, 238), decay = Color3.fromRGB(96, 104, 170), density = 0.3, offset = 0.18, haze = 1.5, glare = 0.25,
		sat = 0.12, contrast = 0.08, tint = Color3.fromRGB(246, 244, 255), rays = 0.1, cover = 0.5, cloudDensity = 0.42, exposure = 0.1, bright = 2.8 },
	sky = { density = 0.24, offset = 0.3, haze = 0.6, glare = 0.6, sat = 0.04, contrast = 0.05, tint = Color3.fromRGB(255, 252, 248), rays = 0.1,
		cover = 0.42, cloudDensity = 0.35, exposure = 0.2, bright = 3.2 },
	wilds = { density = 0.42, offset = 0.05, haze = 2.2, glare = 0.05, sat = -0.05, contrast = 0.12, tint = Color3.fromRGB(236, 248, 240), rays = 0.03,
		cover = 0.8, cloudDensity = 0.6, exposure = -0.1, bright = 1.8 },
	astral = { density = 0.3, offset = 0.15, haze = 1.0, glare = 0.2, sat = 0.08, contrast = 0.1, tint = Color3.fromRGB(246, 240, 255), rays = 0.05,
		cover = 0.3, cloudDensity = 0.3, exposure = 0, bright = 2 },
}

local regionOverride = nil

local function applyWorld(id: string)
	local w = Worlds.Info[id]
	if not w then
		return
	end
	currentWorld = id
	local pr = table.clone(PROFILES[id] or PROFILES.verdant)
	-- cada mundo tem a sua cor de ambiente (mesma paleta do céu anime): névoa, decaimento, tom e ambiente
	local th = AnimeSky.theme(id)
	pr.fog, pr.decay, pr.tint, pr.ambient = th.fog, th.decay, th.tint, th.ambient
	-- região atual (ex.: Azure Caverns) sobrepõe parte do perfil do mundo
	if regionOverride then
		for k, v in pairs(regionOverride) do
			pr[k] = v
		end
	end
	local info = TweenInfo.new(2.5)
	TweenService:Create(Lighting, info, { ClockTime = w.clockTime, Ambient = (pr.ambient or w.palette.ambient):Lerp(Color3.new(0, 0, 0), 0.4),
		OutdoorAmbient = (pr.ambient or w.palette.ambient):Lerp(Color3.new(1, 1, 1), 0.2), Brightness = pr.bright, ExposureCompensation = pr.exposure }):Play()
	local fog = pr.fog or w.palette.fog
	TweenService:Create(atmosphere, info, {
		Color = fog, Decay = pr.decay or fog:Lerp(Color3.new(0, 0, 0), 0.45), Density = pr.density, Offset = pr.offset, Haze = pr.haze, Glare = pr.glare,
	}):Play()
	TweenService:Create(cc, info, { TintColor = pr.tint, Saturation = pr.sat, Contrast = pr.contrast }):Play()
	TweenService:Create(sunrays, info, { Intensity = pr.rays }):Play()
	TweenService:Create(depth, info, { FarIntensity = 0.16, FocusDistance = 55, InFocusRadius = 80 }):Play()
	if clouds then
		TweenService:Create(clouds, info, { Cover = pr.cover, Density = pr.cloudDensity }):Play()
	end
end

-- Chamado pelo RegionClient ao entrar/sair de uma região (nil = só o perfil do mundo).
function WorldClient.setRegionProfile(override)
	regionOverride = override
	if currentWorld then
		applyWorld(currentWorld)
	end
end

-- Durante um boss: leve tom da cor do boss, mais forte nas fases finais.
local function bossMood()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local bf = workspace:FindFirstChild("Bosses")
	if not root or not bf then
		return
	end
	for _, b in ipairs(bf:GetChildren()) do
		local c, r = b:GetAttribute("ArenaCenter"), b:GetAttribute("ArenaRadius")
		if c and r and (((root :: BasePart).Position - c) * Vector3.new(1, 0, 1)).Magnitude <= r + 5 then
			local state = b:GetAttribute("BossState")
			if state == "Fight" or state == "Transition" or state == "Intro" then
				local phase = b:GetAttribute("Phase") or 1
				local k = math.clamp(0.05 + 0.05 * phase, 0, 0.3)
				local base = (PROFILES[currentWorld or "verdant"] or PROFILES.verdant)
				cc.TintColor = base.tint:Lerp(Color3.fromRGB(255, 200, 230), k)
				cc.Contrast = base.contrast + 0.04 * phase
				return
			end
		end
	end
	local base = (PROFILES[currentWorld or "verdant"] or PROFILES.verdant)
	cc.TintColor = base.tint
	cc.Contrast = base.contrast
end

local function makeBar(model: Model, isResource: boolean)
	local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not pp then
		return
	end
	local h = model:GetExtentsSize().Y
	local gui = UIKit.new("BillboardGui", { Name = "HealthBar", Size = UDim2.fromOffset(isResource and 90 or 130, isResource and 14 or 34), StudsOffsetWorldSpace = Vector3.new(0, h * 0.6 + 1.5, 0),
		AlwaysOnTop = true, MaxDistance = isResource and 50 or 80, Adornee = pp, Enabled = false, Parent = model })
	local name
	if not isResource then
		name = UIKit.label({ Size = UDim2.new(1, 0, 0, 16), Text = "", TextSize = 13, Font = UIKit.Theme.bold, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, Parent = gui })
	end
	local _, fill = UIKit.bar(gui, { Position = UDim2.new(0, 0, 1, isResource and -12 or -14), Size = UDim2.new(1, 0, 0, isResource and 10 or 12),
		color = isResource and UIKit.Theme.gold or Color3.fromRGB(230, 80, 80), radius = 4 })
	bars[model] = { gui = gui, fill = fill, name = name, resource = isResource, model = model }
end

local function updateBars()
	for model, b in pairs(bars) do
		if not model.Parent then
			bars[model] = nil
		else
			local hp, maxHp = model:GetAttribute("Health") or 0, model:GetAttribute("MaxHealth") or 1
			local dead = model:GetAttribute("Dead") == true
			local damaged = hp < maxHp
			b.gui.Enabled = not dead and (not b.resource or damaged)
			UIKit.setBar(b.fill, hp / maxHp)
			if b.name then
				local evading = model:GetAttribute("Evading")
				b.name.Text = string.format("%s <font size=\"11\">Nv %d</font>%s", model:GetAttribute("DisplayName") or "", model:GetAttribute("Level") or 1, evading and " ↩" or "")
				local isTarget = model:GetAttribute("Entity") == player:GetAttribute("Target")
				b.name.TextColor3 = isTarget and UIKit.Theme.gold or Color3.new(1, 1, 1)
			end
		end
	end
end

local function hurtFlash()
	local pg = player:WaitForChild("PlayerGui")
	local gui = UIKit.new("ScreenGui", { Name = "HurtFx", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 30, Parent = pg })
	local frame = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 30, 30), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
	local function hook(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum then
			return
		end
		local last = hum.Health
		hum.HealthChanged:Connect(function(h)
			if h < last - 1 then
				frame.BackgroundTransparency = 0.75
				TweenService:Create(frame, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			end
			last = h
		end)
	end
	if player.Character then
		task.spawn(hook, player.Character)
	end
	player.CharacterAdded:Connect(hook)
end

function WorldClient.init()
	setupLighting()
	applyWorld(player:GetAttribute("World") or "verdant")
	player:GetAttributeChangedSignal("World"):Connect(function()
		local w = player:GetAttribute("World")
		if w and w ~= currentWorld then
			applyWorld(w)
		end
	end)
	task.spawn(function()
		local ef = workspace:WaitForChild("Enemies", 30)
		if ef then
			for _, m in ipairs(ef:GetChildren()) do
				makeBar(m, false)
			end
			ef.ChildAdded:Connect(function(m)
				task.wait()
				makeBar(m, false)
			end)
		end
		local rf = workspace:WaitForChild("Resources", 30)
		if rf then
			for _, m in ipairs(rf:GetChildren()) do
				makeBar(m, true)
			end
			rf.ChildAdded:Connect(function(m)
				task.wait()
				makeBar(m, true)
			end)
		end
	end)
	hurtFlash()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.15 then
			acc = 0
			updateBars()
			bossMood()
		end
	end)
end

return WorldClient

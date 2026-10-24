-- Gráficos realistas (local, por cima da iluminação de cada região do ZoneController):
-- • iluminação Future no estilo "Realistic" com prioridade de qualidade, reflexos do ambiente
--   no máximo, sombras mais nítidas
-- • céu com milhares de estrelas e lua grande, nuvens volumétricas do Terrain, raios de sol,
--   desfoque de distância suave (profundidade de campo), bloom fino
-- • Ultra: todas as luzes do mapa (postes, janelas, letreiros) projetam sombra; ruas molhadas
--   (asfalto refletindo os neons); água com reflexo e ondas
-- Os níveis Low/Medium desligam as partes caras (sombras das luzes, profundidade de campo).
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local VFX = require(script.Parent.VFXController)

local GraphicsController = {}

local applied: string? = nil
local depth: DepthOfFieldEffect
local rays: SunRaysEffect
local shadowed: { [Light]: boolean } = {}

local function try(fn: () -> ())
	-- propriedades novas do motor (LightingStyle, PrioritizeLightingQuality...) podem não existir
	-- em todas as versões: ignora as que faltarem
	pcall(fn)
end

local function ensure(className: string, name: string, parent: Instance): any
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

-- Luzes do mapa com sombra (só no Ultra); também acompanha luzes criadas depois
local function setMapShadows(on: boolean)
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end
	for _, d in map:GetDescendants() do
		if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			if on and not d.Shadows then
				d.Shadows = true
				shadowed[d] = true
			elseif not on and shadowed[d] then
				d.Shadows = false
				shadowed[d] = nil
			end
		end
	end
end

-- Asfalto e calçadas molhados: refletem os neons e postes (local)
local function setWetStreets(on: boolean)
	local map = workspace:FindFirstChild("Map")
	local karakura = map and map:FindFirstChild("Karakura")
	local roads = karakura and karakura:FindFirstChild("Roads")
	if not roads then
		return
	end
	for _, p in roads:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "Road" then
				p.Reflectance = if on then 0.14 else 0
			elseif p.Name == "Sidewalk" then
				p.Reflectance = if on then 0.06 else 0
			end
		end
	end
end

function GraphicsController.Apply(quality: string)
	if applied == quality then
		return
	end
	applied = quality
	local ultra = quality == "Ultra"
	local high = ultra or quality == "High"

	try(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	try(function()
		(Lighting :: any).LightingStyle = (Enum :: any).LightingStyle.Realistic
	end)
	try(function()
		(Lighting :: any).PrioritizeLightingQuality = high
	end)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = if ultra then 0.08 else 0.2
	Lighting.EnvironmentDiffuseScale = if high then 1 else 0.5
	Lighting.EnvironmentSpecularScale = if high then 1 else 0.5

	-- céu
	local sky = Lighting:FindFirstChildOfClass("Sky") or ensure("Sky", "BSR_Sky", Lighting)
	sky.StarCount = if high then 5000 else 2000
	sky.CelestialBodiesShown = true
	sky.MoonAngularSize = 14
	sky.SunAngularSize = 18

	-- nuvens volumétricas
	try(function()
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = 0.52
		clouds.Density = 0.55
		clouds.Color = Color3.fromRGB(150, 160, 190)
		clouds.Enabled = quality ~= "Low"
		clouds.Parent = workspace.Terrain
	end)

	-- água realista
	try(function()
		local terrain = workspace.Terrain
		terrain.WaterReflectance = if high then 1 else 0.5
		terrain.WaterTransparency = 0.35
		terrain.WaterWaveSize = 0.18
		terrain.WaterWaveSpeed = 9
		terrain.WaterColor = Color3.fromRGB(16, 40, 56)
		terrain.Decoration = high
	end)

	-- pós-processamento
	rays.Enabled = high
	rays.Intensity = 0.09
	rays.Spread = 0.55
	depth.Enabled = high
	depth.FarIntensity = if ultra then 0.22 else 0.12
	depth.FocusDistance = 28
	depth.InFocusRadius = 70
	depth.NearIntensity = 0

	setMapShadows(ultra)
	setWetStreets(high)
end

function GraphicsController.Init()
	depth = ensure("DepthOfFieldEffect", "BSR_Depth", Lighting)
	rays = ensure("SunRaysEffect", "BSR_SunRays", Lighting)
end

function GraphicsController.Start()
	GraphicsController.Apply(VFX.Quality())
	-- o mapa é montado pelo servidor e chega aos poucos: reaplica sombras/ruas por um tempo, e
	-- acompanha a troca de qualidade no menu
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 then
			return
		end
		elapsed = 0
		local q = VFX.Quality()
		if q ~= applied then
			GraphicsController.Apply(q)
		end
	end)
	task.spawn(function()
		for _ = 1, 6 do
			task.wait(5)
			setMapShadows(applied == "Ultra")
			setWetStreets(applied == "Ultra" or applied == "High")
		end
	end)
end

return GraphicsController

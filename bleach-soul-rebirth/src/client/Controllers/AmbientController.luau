-- Clima/partículas ambientes por região, seguindo a câmera:
-- Karakura (reishi flutuando), Soul Society (pétalas de sakura), Hueco Mundo (vento de areia),
-- Campo de Treino (brasas). Quantidade reduzida na qualidade "Low".
local RunService = game:GetService("RunService")

local Controllers = script.Parent
local ZoneController = require(Controllers.ZoneController)
local VFX = require(Controllers.VFXController)

local AmbientController = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local hosts: { [string]: Part } = {}
local emitters: { [string]: ParticleEmitter } = {}
local active: string? = nil

local PRESETS = {
	Karakura = {
		Texture = SPARK,
		Color = ColorSequence.new(Color3.fromRGB(140, 200, 255), Color3.fromRGB(220, 240, 255)),
		LightEmission = 1,
		Rate = 22,
		Lifetime = NumberRange.new(6, 10),
		Speed = NumberRange.new(0.5, 2),
		Acceleration = Vector3.new(0, 1.2, 0),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new(0.2),
		SpreadAngle = Vector2.new(180, 180),
		boxHeight = 2,
		yOffset = -6,
	},
	SoulSociety = {
		Texture = SPARK,
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 200), Color3.fromRGB(255, 225, 235)),
		LightEmission = 0.3,
		Rate = 40,
		Lifetime = NumberRange.new(7, 11),
		Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(2.5, -3, 1),
		Size = NumberSequence.new(0.45),
		Transparency = NumberSequence.new(0.1),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
		SpreadAngle = Vector2.new(40, 40),
		boxHeight = 1,
		yOffset = 35,
	},
	HuecoMundo = {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(235, 235, 230)),
		LightEmission = 0,
		Rate = 26,
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(14, 22),
		Acceleration = Vector3.new(6, -1, 2),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
		SpreadAngle = Vector2.new(10, 10),
		EmissionDirection = Enum.NormalId.Right,
		boxHeight = 10,
		yOffset = -2,
	},
	Training = {
		Texture = FIRE,
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 80), Color3.fromRGB(255, 90, 30)),
		LightEmission = 1,
		Rate = 18,
		Lifetime = NumberRange.new(3, 6),
		Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(0.5, 2.5, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.1),
		SpreadAngle = Vector2.new(180, 180),
		boxHeight = 2,
		yOffset = -6,
	},
}

local function build(zone: string, preset)
	local host = Instance.new("Part")
	host.Name = "Ambient_" .. zone
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.CastShadow = false
	host.Transparency = 1
	host.Size = Vector3.new(160, preset.boxHeight, 160)
	host.Parent = workspace
	hosts[zone] = host
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Enabled = false
	for key, value in preset do
		if key ~= "boxHeight" and key ~= "yOffset" then
			(e :: any)[key] = value
		end
	end
	e.Parent = host
	emitters[zone] = e
	return e
end

local function setZone(zone: string?)
	if zone == active then
		return
	end
	active = zone
	for id, e in emitters do
		e.Enabled = id == zone
	end
end

function AmbientController.Init()
	for zone, preset in PRESETS do
		build(zone, preset)
	end
end

function AmbientController.Start()
	local lastQuality = ""
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			local p = camera.CFrame.Position
			for zone, host in hosts do
				host.CFrame = CFrame.new(p.X, p.Y + 8 + PRESETS[zone].yOffset, p.Z)
			end
		end
		setZone(ZoneController.Current())
		local quality = VFX.Quality()
		if quality ~= lastQuality then
			lastQuality = quality
			local scale = if quality == "Low"
				then 0.25
				elseif quality == "Medium" then 0.6
				elseif quality == "Ultra" then 1.6
				else 1
			for zone, e in emitters do
				e.Rate = PRESETS[zone].Rate * scale
			end
		end
	end)
end

return AmbientController

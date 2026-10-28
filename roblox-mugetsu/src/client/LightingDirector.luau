--!strict
-- Iluminação cinematográfica e pós-processamento (moderado). Guarda o estado original e o restaura.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Quality = require(script.Parent:WaitForChild("Quality"))

local LightingDirector = {}

local saved: { [string]: any }? = nil
local created: { Instance } = {}
local cc: ColorCorrectionEffect?
local bloom: BloomEffect?
local blur: BlurEffect?
local atmosphere: Atmosphere?
local createdAtmosphere = false

local PRESETS = {
	Cold = {
		ClockTime = 17.2, Brightness = 1.4, ExposureCompensation = -0.5,
		Ambient = Color3.fromRGB(52, 62, 84), OutdoorAmbient = Color3.fromRGB(70, 84, 112),
		ColorShift_Top = Color3.fromRGB(120, 150, 255),
		cc = { Saturation = -0.25, Contrast = 0.25, Brightness = -0.05, TintColor = Color3.fromRGB(205, 220, 255) },
		bloom = { Intensity = 0.4, Size = 24, Threshold = 1.0 },
		haze = { Density = 0.38, Color = Color3.fromRGB(90, 104, 130) },
	},
	Night = {
		ClockTime = 0.5, Brightness = 0.6, ExposureCompensation = -0.8,
		Ambient = Color3.fromRGB(20, 40, 90), OutdoorAmbient = Color3.fromRGB(26, 52, 110),
		ColorShift_Top = Color3.fromRGB(80, 150, 255),
		cc = { Saturation = -0.1, Contrast = 0.35, Brightness = -0.1, TintColor = Color3.fromRGB(170, 200, 255) },
		bloom = { Intensity = 0.9, Size = 32, Threshold = 0.9 },
		haze = { Density = 0.45, Color = Color3.fromRGB(30, 60, 120) },
	},
	Overcast = {
		ClockTime = 13, Brightness = 3, ExposureCompensation = 0.2,
		Ambient = Color3.fromRGB(150, 150, 155), OutdoorAmbient = Color3.fromRGB(170, 170, 176),
		ColorShift_Top = Color3.fromRGB(255, 255, 255),
		cc = { Saturation = -0.55, Contrast = 0.4, Brightness = 0.02, TintColor = Color3.fromRGB(255, 255, 255) },
		bloom = { Intensity = 0.5, Size = 24, Threshold = 1.2 },
		haze = { Density = 0.3, Color = Color3.fromRGB(215, 215, 220) },
	},
	Mugetsu = {
		ClockTime = 16.5, Brightness = 1.0, ExposureCompensation = -0.9,
		Ambient = Color3.fromRGB(26, 26, 30), OutdoorAmbient = Color3.fromRGB(46, 46, 52),
		ColorShift_Top = Color3.fromRGB(255, 255, 255),
		cc = { Saturation = -0.85, Contrast = 0.6, Brightness = -0.12, TintColor = Color3.fromRGB(240, 240, 245) },
		bloom = { Intensity = 0.35, Size = 18, Threshold = 1.1 },
		haze = { Density = 0.5, Color = Color3.fromRGB(30, 30, 34) },
	},
}

local function ensure()
	if saved then
		return
	end
	saved = {
		ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness,
		ExposureCompensation = Lighting.ExposureCompensation, Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient, ColorShift_Top = Lighting.ColorShift_Top,
	}
	local q = Quality.settings()
	if q.PostFx then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "MugetsuCC"
		cc.Parent = Lighting
		bloom = Instance.new("BloomEffect")
		bloom.Name = "MugetsuBloom"
		bloom.Intensity = 0
		bloom.Parent = Lighting
		blur = Instance.new("BlurEffect")
		blur.Name = "MugetsuBlur"
		blur.Size = 0
		blur.Parent = Lighting
		table.insert(created, cc :: Instance)
		table.insert(created, bloom :: Instance)
		table.insert(created, blur :: Instance)
	end
	if q.Fog then
		atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if not atmosphere then
			atmosphere = Instance.new("Atmosphere")
			atmosphere.Name = "MugetsuAtmosphere"
			atmosphere.Density = 0
			atmosphere.Parent = Lighting
			createdAtmosphere = true
			table.insert(created, atmosphere :: Instance)
		else
			saved.AtmDensity = atmosphere.Density
			saved.AtmColor = atmosphere.Color
		end
	end
end

local function tween(inst: Instance?, time: number, props: { [string]: any })
	if inst then
		TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Sine), props):Play()
	end
end

function LightingDirector.apply(preset: string, time: number)
	local p = PRESETS[preset]
	if not p then
		return
	end
	ensure()
	tween(Lighting, time, {
		ClockTime = p.ClockTime, Brightness = p.Brightness, ExposureCompensation = p.ExposureCompensation,
		Ambient = p.Ambient, OutdoorAmbient = p.OutdoorAmbient, ColorShift_Top = p.ColorShift_Top,
	})
	tween(cc, time, p.cc)
	tween(bloom, time, p.bloom)
	tween(atmosphere, time, { Density = p.haze.Density, Color = p.haze.Color })
end

-- Pulso curto de brilho (sincronizado com eventos de energia).
function LightingDirector.pulse(strength: number)
	ensure()
	if bloom then
		local base = bloom.Intensity
		bloom.Intensity = base + strength
		tween(bloom, 0.45, { Intensity = base })
	end
	if cc then
		local b = cc.Brightness
		cc.Brightness = b + strength * 0.12
		tween(cc, 0.4, { Brightness = b })
	end
end

-- Impact frame: alto contraste e dessaturação total por poucos quadros.
function LightingDirector.impactFrame(duration: number)
	ensure()
	if not cc then
		return
	end
	local s, c, br = cc.Saturation, cc.Contrast, cc.Brightness
	cc.Saturation = -1
	cc.Contrast = 1.8
	cc.Brightness = 0.1
	task.delay(duration, function()
		if cc then
			cc.Saturation, cc.Contrast, cc.Brightness = s, c, br
		end
	end)
end

function LightingDirector.blur(size: number, time: number)
	ensure()
	tween(blur, time, { Size = size })
end

function LightingDirector.restore(time: number)
	local s = saved
	if not s then
		return
	end
	saved = nil
	tween(Lighting, time, {
		ClockTime = s.ClockTime, Brightness = s.Brightness, ExposureCompensation = s.ExposureCompensation,
		Ambient = s.Ambient, OutdoorAmbient = s.OutdoorAmbient, ColorShift_Top = s.ColorShift_Top,
	})
	if atmosphere and not createdAtmosphere and s.AtmDensity then
		tween(atmosphere, time, { Density = s.AtmDensity, Color = s.AtmColor })
	end
	tween(cc, time, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
	tween(bloom, time, { Intensity = 0 })
	tween(blur, time, { Size = 0 })
	local toDestroy = created
	created = {}
	createdAtmosphere = false
	cc, bloom, blur, atmosphere = nil, nil, nil, nil
	task.delay(time + 0.1, function()
		for _, i in toDestroy do
			i:Destroy()
		end
	end)
end

return LightingDirector

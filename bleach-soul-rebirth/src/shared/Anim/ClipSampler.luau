--!strict
-- Amostragem de clips compilados com o mesmo easing das poses do Roblox (KeyframeSequence),
-- portado do compilador da skill roblox-vfx-animation. Puro: testável fora do Roblox.
local ClipSampler = {}

-- Easing das poses do Roblox (Linear, Constant, Cubic, CubicV2, Elastic, Bounce; In/Out/InOut),
-- portado do compilador da skill para que a reprodução aqui seja igual à de um AnimationTrack.
local function bounceOut(t: number): number
	if t < 1 / 2.75 then
		return 7.5625 * t * t
	elseif t < 2 / 2.75 then
		t -= 1.5 / 2.75
		return 7.5625 * t * t + 0.75
	elseif t < 2.5 / 2.75 then
		t -= 2.25 / 2.75
		return 7.5625 * t * t + 0.9375
	end
	t -= 2.625 / 2.75
	return 7.5625 * t * t + 0.984375
end

local function elasticIn(t: number, period: number): number
	if t == 0 or t == 1 then
		return t
	end
	return -(2 ^ (10 * (t - 1))) * math.sin((t - 1 - period / 4) * 2 * math.pi / period)
end

local function easeIn(style: string, t: number): number
	if style == "Linear" then
		return t
	elseif style == "Cubic" or style == "CubicV2" then
		return t * t * t
	elseif style == "Bounce" then
		return 1 - bounceOut(1 - t)
	elseif style == "Elastic" then
		return elasticIn(t, 0.3)
	end
	return if t < 1 then 0 else 1
end

function ClipSampler.ease(style: string, direction: string, t: number): number
	if style == "Constant" then
		if direction == "In" then
			return if t > 0 then 1 else 0
		elseif direction == "InOut" then
			return if t >= 0.5 then 1 else 0
		end
		return 0
	end
	local effective = direction
	if style == "Cubic" and direction ~= "InOut" then
		effective = if direction == "In" then "Out" else "In"
	end
	if effective == "In" then
		return easeIn(style, t)
	elseif effective == "Out" then
		return 1 - easeIn(style, 1 - t)
	end
	if style == "Bounce" then
		return if t < 0.5 then easeIn(style, t * 2) / 2 else 0.5 + easeIn(style, t * 2 - 1) / 2
	end
	if style == "Elastic" then
		return if t < 0.5 then elasticIn(t * 2, 0.45) / 2 else 1 - elasticIn((1 - t) * 2, 0.45) / 2
	end
	return if t < 0.5 then easeIn(style, t * 2) / 2 else 1 - easeIn(style, (1 - t) * 2) / 2
end

-- Amostra uma faixa compilada { {tempo, CFrame, estilo, direção}, ... } (easing da pose de saída).
function ClipSampler.sample(keys: { any }, t: number): CFrame
	local count = #keys
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for i = 1, count - 1 do
		local a, b = keys[i], keys[i + 1]
		if t < b[1] then
			local span = b[1] - a[1]
			local alpha = if span > 0 then ClipSampler.ease(a[3], a[4], (t - a[1]) / span) else 1
			return (a[2] :: CFrame):Lerp(b[2], alpha)
		end
	end
	return keys[count][2]
end

return ClipSampler

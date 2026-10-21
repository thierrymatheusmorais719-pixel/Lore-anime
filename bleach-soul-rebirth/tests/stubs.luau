-- Stubs mínimos (incluídos no topo do bundle pelo bundle.py) de tipos Roblox para carregar configs fora do Studio.
local function vec(x, y, z)
	local v = { X = x or 0, Y = y or 0, Z = z or 0 }
	return setmetatable(v, {
		__add = function(a, b)
			return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
		end,
		__sub = function(a, b)
			return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
		end,
		__div = function(a, n)
			return vec(a.X / n, a.Y / n, a.Z / n)
		end,
		__mul = function(a, n)
			return vec(a.X * n, a.Y * n, a.Z * n)
		end,
	})
end
local Vector3 = { new = vec }
local Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}
local CFrame = {
	new = function(x, y, z)
		return { x = x, y = y, z = z }
	end,
	Angles = function()
		return {}
	end,
	fromEulerAnglesYXZ = function()
		return {}
	end,
}

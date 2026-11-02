-- Acessórios cosméticos de pets (drops de bosses / coleção). Presos à cabeça ("Head").

local ModelKit = require(script.Parent.ModelKit)

local Accessories = {}

local V = Vector3.new
local CF = CFrame.new

local function rigFromModel(model: Model)
	local parts = {}
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("BasePart") then
			parts[d.Name] = d
		end
	end
	return { model = model, root = model.PrimaryPart, parts = parts, scale = 1 }
end

function Accessories.apply(model: Model, id: string?)
	if not id then
		return
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local rig = rigFromModel(model)
	local s = math.max(head.Size.X, 0.8) / 1.8
	local top = math.max(head.Size.Y, 0.8) * 0.5
	if head.Transparency >= 1 then
		top = 1.0 * s -- espíritos: cabeça invisível no centro do núcleo
	end
	model:SetAttribute("Accessory", id)
	if id == "leaf_crown" then
		for i = 1, 7 do
			local a = i / 7 * math.pi * 2
			ModelKit.add(rig, { name = "AccLeaf", parent = "Head", at = CF(math.cos(a) * 0.55 * s, top, math.sin(a) * 0.55 * s) * CFrame.Angles(0, -a, math.rad(70)),
				shape = "ellipsoid", size = V(0.45 * s, 0.08 * s, 0.25 * s), color = Color3.fromRGB(110, 200, 80), material = "Grass", role = "Detail" })
		end
	elseif id == "crystal_tiara" then
		for i = -1, 1 do
			ModelKit.add(rig, { name = "AccGem", parent = "Head", at = CF(i * 0.3 * s, top + 0.15 * s - math.abs(i) * 0.1 * s, -0.35 * s),
				shape = "wedge", size = V(0.12 * s, (0.5 - math.abs(i) * 0.15) * s, 0.2 * s), color = Color3.fromRGB(150, 225, 255), material = "Glass", role = "Detail" })
		end
		ModelKit.add(rig, { name = "AccBand", parent = "Head", at = CF(0, top - 0.05 * s, -0.25 * s), shape = "block", size = V(0.9 * s, 0.08 * s, 0.08 * s), color = Color3.fromRGB(230, 230, 255), material = "Metal", role = "Detail" })
	elseif id == "storm_goggles" then
		ModelKit.add(rig, { name = "AccStrap", parent = "Head", at = CF(0, top * 0.6, 0), shape = "block", size = V(head.Size.X * 1.02, 0.15 * s, head.Size.Z * 1.02), color = Color3.fromRGB(70, 50, 40), material = "Fabric", role = "Detail", transparency = 0 })
		for _, side in ipairs({ -1, 1 }) do
			ModelKit.add(rig, { name = "AccLens", parent = "Head", at = CF(side * 0.28 * s, top * 0.75, -0.45 * s) * CFrame.Angles(0, math.rad(90), 0),
				shape = "cyl", size = V(0.15 * s, 0.35 * s, 0.35 * s), color = Color3.fromRGB(255, 220, 90), material = "Glass", role = "Detail" })
		end
	elseif id == "bloom_wreath" then
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			ModelKit.add(rig, { name = "AccBloom", parent = "Head", at = CF(math.cos(a) * 0.5 * s, top - 0.05 * s, math.sin(a) * 0.5 * s),
				shape = "ball", size = Vector3.one * 0.26 * s, color = i % 2 == 0 and Color3.fromRGB(255, 140, 190) or Color3.fromRGB(255, 240, 150), role = "Detail" })
		end
	elseif id == "void_halo" then
		ModelKit.ring(rig, "Head", "OrbitAcc", CF(0, top + 0.45 * s, 0), 0.5 * s, 9, Vector3.one * 0.13 * s, Color3.fromRGB(170, 110, 255), "Neon", "Glow")
	end
end

return Accessories

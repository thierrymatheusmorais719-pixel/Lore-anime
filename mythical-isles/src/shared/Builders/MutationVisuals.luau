-- Aplica uma mutação visual a um modelo de pet JÁ construído.
-- A forma (silhueta) da espécie é mantida; mudam materiais, cores, brilho e partículas,
-- e algumas mutações adicionam detalhes (runas, estrelas, anel orbital).
-- O cliente anima o efeito Prismatic (ciclo de cor) e o anel Astral (junta "OrbitMut").

local Mutations = require(script.Parent.Parent.Config.Mutations)
local ModelKit = require(script.Parent.ModelKit)

local MutationVisuals = {}

local function partsByRole(model: Model)
	local out = { Body = {}, Belly = {}, Accent = {}, Eye = {}, Detail = {}, Glow = {} }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local role = d:GetAttribute("Role") or "Body"
			if out[role] then
				table.insert(out[role], d)
			end
		end
	end
	return out
end

local function bodyPart(model: Model): BasePart?
	return model:FindFirstChild("Torso") :: BasePart?
end

local function emitter(parent: Instance, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = "MutationFx"
	e.LightEmission = props.lightEmission or 0.6
	e.LightInfluence = 0
	e.Rate = props.rate or 4
	e.Lifetime = props.lifetime or NumberRange.new(0.8, 1.4)
	e.Speed = props.speed or NumberRange.new(0.5, 1.5)
	e.SpreadAngle = props.spread or Vector2.new(180, 180)
	e.Size = props.size or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = props.transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Color = props.color
	e.Acceleration = props.acceleration or Vector3.new(0, 1.5, 0)
	e.Texture = props.texture or "rbxasset://textures/particles/sparkles_main.dds"
	e.Parent = parent
	return e
end

local function rigFromModel(model: Model)
	-- Reconstrói um "rig" mínimo para usar ModelKit.add em peças já existentes.
	local parts = {}
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("BasePart") then
			parts[d.Name] = d
		end
	end
	return { model = model, root = model.PrimaryPart, parts = parts, scale = 1 }
end

function MutationVisuals.apply(model: Model, mutation: string?)
	if not mutation or not Mutations.Info[mutation] then
		return
	end
	model:SetAttribute("Mutation", mutation)
	local roles = partsByRole(model)
	local torso = bodyPart(model)
	local size = torso and torso.Size.Magnitude or 3
	local u = size / 3.6

	if mutation == "Golden" then
		local gold, light = Color3.fromRGB(255, 196, 56), Color3.fromRGB(255, 228, 140)
		for _, p in ipairs(roles.Body) do
			p.Color = p.Color:Lerp(gold, 0.8)
			p.Material = Enum.Material.Metal
			p.Reflectance = 0.12
		end
		for _, p in ipairs(roles.Belly) do
			p.Color = p.Color:Lerp(light, 0.8)
			p.Material = Enum.Material.Metal
			p.Reflectance = 0.08
		end
		for _, p in ipairs(roles.Accent) do
			p.Color = p.Color:Lerp(Color3.fromRGB(255, 250, 230), 0.5)
		end
		if torso then
			emitter(torso, { color = ColorSequence.new(Color3.fromRGB(255, 220, 90)), rate = 3, size = NumberSequence.new(0.18 * u, 0) })
		end
	elseif mutation == "Radiant" then
		for _, p in ipairs(roles.Body) do
			p.Color = p.Color:Lerp(Color3.new(1, 1, 0.95), 0.35)
		end
		for _, p in ipairs(roles.Belly) do
			p.Color = p.Color:Lerp(Color3.new(1, 1, 1), 0.4)
		end
		for _, p in ipairs(roles.Accent) do
			p.Material = Enum.Material.Neon
			p.Color = p.Color:Lerp(Color3.fromRGB(255, 245, 200), 0.4)
		end
		if torso then
			local light = Instance.new("PointLight")
			light.Name = "MutationLight"
			light.Color = Color3.fromRGB(255, 240, 200)
			light.Brightness = 0.9
			light.Range = 8 * u
			light.Shadows = false
			light.Parent = torso
			emitter(torso, { color = ColorSequence.new(Color3.fromRGB(255, 250, 210)), rate = 5, acceleration = Vector3.new(0, 2.5, 0), size = NumberSequence.new(0.2 * u, 0) })
		end
	elseif mutation == "Prismatic" then
		for _, p in ipairs(roles.Body) do
			p.Material = Enum.Material.Glass
			p.Reflectance = 0.1
			p.Transparency = math.max(p.Transparency, 0.08)
		end
		for _, p in ipairs(roles.Accent) do
			p.Material = Enum.Material.Neon
		end
		model:SetAttribute("PrismaticCycle", true) -- o cliente gira a matiz das peças Body/Accent
		if torso then
			emitter(torso, {
				color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 200)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(120, 220, 255)),
					ColorSequenceKeypoint.new(0.66, Color3.fromRGB(180, 255, 140)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 120)),
				}),
				rate = 4, size = NumberSequence.new(0.2 * u, 0),
			})
		end
	elseif mutation == "Ancient" then
		local stone = Color3.fromRGB(118, 112, 98)
		for _, p in ipairs(roles.Body) do
			p.Color = p.Color:Lerp(stone, 0.65)
			p.Material = Enum.Material.Slate
		end
		for _, p in ipairs(roles.Belly) do
			p.Color = p.Color:Lerp(Color3.fromRGB(160, 150, 125), 0.6)
			p.Material = Enum.Material.Sandstone
		end
		for _, p in ipairs(roles.Eye) do
			p.Color = Color3.fromRGB(120, 255, 200)
			p.Material = Enum.Material.Neon
		end
		if torso then
			local rig = rigFromModel(model)
			local rune = Color3.fromRGB(110, 255, 190)
			for _, side in ipairs({ -1, 1 }) do
				local half = torso.Size.X / 2
				ModelKit.add(rig, { name = "Rune", parent = torso.Name, at = CFrame.new(side * half * 0.92, torso.Size.Y * 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
					shape = "block", size = Vector3.new(torso.Size.Y * 0.45, 0.06, torso.Size.Z * 0.12), color = rune, material = "Neon", role = "Glow", shadow = false })
				ModelKit.add(rig, { name = "Rune", parent = torso.Name, at = CFrame.new(side * half * 0.9, -torso.Size.Y * 0.1, torso.Size.Z * 0.2) * CFrame.Angles(0, 0, math.rad(90)),
					shape = "block", size = Vector3.new(torso.Size.Y * 0.25, 0.06, torso.Size.Z * 0.08), color = rune, material = "Neon", role = "Glow", shadow = false })
			end
			ModelKit.add(rig, { name = "AncientMoss", parent = torso.Name, at = CFrame.new(0, torso.Size.Y * 0.45, 0), shape = "ellipsoid",
				size = Vector3.new(torso.Size.X * 0.6, torso.Size.Y * 0.2, torso.Size.Z * 0.5), color = Color3.fromRGB(80, 120, 60), material = "Grass", role = "Detail" })
		end
	elseif mutation == "Phantom" then
		local pale = Color3.fromRGB(185, 230, 255)
		for _, list in ipairs({ roles.Body, roles.Belly }) do
			for _, p in ipairs(list) do
				p.Color = p.Color:Lerp(pale, 0.55)
				p.Transparency = math.max(p.Transparency, 0.4)
				p.CastShadow = false
			end
		end
		for _, p in ipairs(roles.Accent) do
			p.Material = Enum.Material.ForceField
			p.Color = pale
		end
		for _, p in ipairs(roles.Eye) do
			p.Color = Color3.new(1, 1, 1)
			p.Material = Enum.Material.Neon
		end
		if torso then
			emitter(torso, {
				color = ColorSequence.new(Color3.fromRGB(200, 240, 255)), rate = 6, lightEmission = 0.4,
				size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * u), NumberSequenceKeypoint.new(1, 1.2 * u) }),
				transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
				acceleration = Vector3.new(0, 1, 0), texture = "rbxasset://textures/particles/smoke_main.dds",
			})
		end
	elseif mutation == "Astral" then
		local night = Color3.fromRGB(28, 24, 70)
		for _, p in ipairs(roles.Body) do
			p.Color = p.Color:Lerp(night, 0.8)
		end
		for _, p in ipairs(roles.Belly) do
			p.Color = p.Color:Lerp(Color3.fromRGB(110, 80, 200), 0.7)
		end
		for _, p in ipairs(roles.Accent) do
			p.Material = Enum.Material.Neon
			p.Color = p.Color:Lerp(Color3.fromRGB(255, 230, 160), 0.5)
		end
		if torso then
			local rig = rigFromModel(model)
			for i = 1, 7 do
				local a = i * 2.3
				ModelKit.add(rig, { name = "AstralStar", parent = torso.Name,
					at = CFrame.new(math.cos(a) * torso.Size.X * 0.42, math.sin(i * 1.3) * torso.Size.Y * 0.3 + torso.Size.Y * 0.15, math.sin(a) * torso.Size.Z * 0.42),
					shape = "ball", size = Vector3.one * 0.12 * u, color = Color3.fromRGB(255, 250, 220), material = "Neon", role = "Glow", shadow = false })
			end
			ModelKit.ring(rig, torso.Name, "OrbitMut", CFrame.new(0, torso.Size.Y * 0.1, 0) * CFrame.Angles(math.rad(18), 0, 0),
				torso.Size.X * 0.95, 8, Vector3.one * 0.16 * u, Color3.fromRGB(190, 170, 255), "Neon", "Glow")
			emitter(torso, { color = ColorSequence.new(Color3.fromRGB(200, 190, 255)), rate = 3, size = NumberSequence.new(0.16 * u, 0) })
		end
	end
end

return MutationVisuals

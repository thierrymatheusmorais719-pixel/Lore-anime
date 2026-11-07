-- Visual dos pets no cliente: troca o modelo de peças do servidor (que continua cuidando de posição,
-- combate, seguir o dono e inventário) pelo modelo de MALHAS anatômicas (PetMesh), animado pelo
-- CreatureMotion. O modelo do servidor fica invisível só neste cliente.
-- Se as malhas não puderem ser criadas, nada muda: o pet antigo continua visível e animado.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PetMesh = require(Shared.Builders.PetMesh)
local MutationVisuals = require(Shared.Builders.MutationVisuals)
local Accessories = require(Shared.Builders.Accessories)
local State = require(script.Parent.State)
local CreatureMotion = require(script.Parent.CreatureMotion)

local PetVisuals = {}

local active: { [Model]: { mesh: Model, root: BasePart, server: BasePart, offset: CFrame } } = {}
local claimed: { [Model]: boolean } = {}

local function hideServerPart(d: Instance, mesh: Model)
	if d:IsDescendantOf(mesh) then
		return
	end
	if d:IsA("BasePart") then
		d.LocalTransparencyModifier = 1
	elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Light") then
		(d :: any).Enabled = false
	end
end

local function attach(model: Model)
	if claimed[model] or model:GetAttribute("MeshPet") or not model:GetAttribute("Species") or not model:GetAttribute("Uid") then
		return
	end
	claimed[model] = true
	task.spawn(function()
		local species = model:GetAttribute("Species")
		local scale = model:GetAttribute("Scale") or 1
		local t = PetMesh.await(species, scale, 40)
		local server = model.PrimaryPart
		if not t or not model.Parent or not server then
			claimed[model] = nil
			return
		end
		local mesh = t.model:Clone()
		MutationVisuals.apply(mesh, model:GetAttribute("Mutation"))
		Accessories.apply(mesh, model:GetAttribute("Accessory"))
		if (model:GetAttribute("Tier") or 1) >= 2 then
			-- aura de evolução (mesma do modelo do servidor)
			local torso = mesh:FindFirstChild("Torso")
			if torso then
				local aura = Instance.new("ParticleEmitter")
				aura.Name = "TierAura"
				aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				aura.Rate = model:GetAttribute("Tier") == 3 and 6 or 3
				aura.Lifetime = NumberRange.new(0.6, 1.0)
				aura.Speed = NumberRange.new(1, 2)
				aura.Size = NumberSequence.new(0.25, 0)
				aura.LightEmission = 0.7
				aura.Color = ColorSequence.new(model:GetAttribute("Tier") == 3 and Color3.fromRGB(255, 140, 220) or Color3.fromRGB(255, 230, 140))
				aura.Parent = torso
			end
		end
		local flies = model:GetAttribute("Flies") == true
		local serverHover = model:GetAttribute("Hover") or t.bp.hover
		local offset = CFrame.new(0, flies and 0 or (t.bp.hover - serverHover), 0)
		local mroot = mesh.PrimaryPart :: BasePart
		mroot.Anchored = true
		mroot.CFrame = server.CFrame * offset
		mesh.Name = "Visual"
		model:SetAttribute("MeshVisual", true) -- atributo local: o Animator deixa o modelo antigo de lado
		mesh.Parent = model
		for _, d in ipairs(model:GetDescendants()) do
			hideServerPart(d, mesh)
		end
		model.DescendantAdded:Connect(function(d)
			hideServerPart(d, mesh)
		end)
		active[model] = { mesh = mesh, root = mroot, server = server, offset = offset }
	end)
end

function PetVisuals.init()
	local folder = workspace:WaitForChild("Pets", 30)
	if not folder then
		return
	end
	local function consider(d)
		if d:IsA("Model") and d.Parent and d.Parent.Parent == folder then
			task.defer(attach, d)
		end
	end
	for _, d in ipairs(folder:GetDescendants()) do
		consider(d)
	end
	folder.DescendantAdded:Connect(consider)
	-- a raiz do visual acompanha a raiz do pet no servidor (antes da física, para as juntas seguirem)
	RunService.Stepped:Connect(function()
		for model, a in pairs(active) do
			if model.Parent and a.server.Parent and a.mesh.Parent then
				a.root.CFrame = a.server.CFrame * a.offset
			else
				active[model] = nil
				claimed[model] = nil
			end
		end
	end)
	-- comemoração dos pets ao derrotar um boss
	State.on("BossDefeated", function()
		CreatureMotion.celebrate(game:GetService("Players").LocalPlayer.UserId, 4)
	end)
end

PetVisuals.active = active
return PetVisuals

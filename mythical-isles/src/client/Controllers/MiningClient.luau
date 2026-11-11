-- Mineração (cliente): o tempo de segurar "Minerar" segue a picareta do jogador (o servidor confere o
-- intervalo de verdade, isto é só para a barra do botão bater com o que vale), e cada veio mostra
-- quantos golpes faltam no nome do prompt.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Mining = require(Shared.Config.Mining)

local MiningClient = {}

local lp = Players.LocalPlayer
local prompts: { [ProximityPrompt]: Model } = {}

local function holdFor(): number
	local lvl = math.clamp(tonumber(lp:GetAttribute("Pickaxe")) or 1, 1, #Mining.Pickaxes)
	return Mining.Pickaxes[lvl].hold
end

-- PICARETA NA MÃO: enquanto o jogador segura "Minerar", uma picareta aparece na mão direita e balança.
-- É só visual (local): cabo de madeira e cabeça na cor do nível da picareta.
local RunService = game:GetService("RunService")
local HEAD_COLORS = { Color3.fromRGB(150, 110, 70), Color3.fromRGB(140, 140, 150), Color3.fromRGB(190, 195, 205), Color3.fromRGB(120, 220, 255),
	Color3.fromRGB(255, 230, 110), Color3.fromRGB(255, 240, 200) }
local swing: { model: Model, weld: Weld, conn: RBXScriptConnection }? = nil

local function stopSwing()
	if swing then
		swing.conn:Disconnect()
		swing.model:Destroy()
		swing = nil
	end
end

local function startSwing()
	stopSwing()
	local char = lp.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local lvl = math.clamp(tonumber(lp:GetAttribute("Pickaxe")) or 1, 1, #Mining.Pickaxes)
	local m = Instance.new("Model")
	m.Name = "Pickaxe"
	local function piece(name: string, size: Vector3, color: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.Parent = m
		return p
	end
	local handle = piece("Handle", Vector3.new(0.28, 3.2, 0.28), Color3.fromRGB(120, 84, 52), Enum.Material.Wood)
	local head = piece("Head", Vector3.new(2.4, 0.42, 0.36), HEAD_COLORS[lvl], lvl >= 4 and Enum.Material.Neon or Enum.Material.Metal)
	local hw = Instance.new("Weld")
	hw.Part0, hw.Part1, hw.C0 = handle, head, CFrame.new(0, 1.45, 0)
	hw.Parent = head
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1 = hand, handle
	weld.Parent = handle
	m.Parent = char
	local t0 = os.clock()
	local period = math.max(0.3, holdFor())
	local conn = RunService.RenderStepped:Connect(function()
		-- sobe devagar e desce rápido, um golpe por tempo de segurar
		local k = ((os.clock() - t0) % period) / period
		local a = k < 0.7 and (k / 0.7) * 1.9 or (1 - (k - 0.7) / 0.3) * 1.9
		weld.C0 = CFrame.new(0, -0.9, -0.3) * CFrame.Angles(math.rad(-90) + a - 0.9, 0, 0) * CFrame.new(0, 1.1, 0)
	end)
	swing = { model = m, weld = weld, conn = conn }
end

local function refresh(prompt: ProximityPrompt, model: Model)
	prompt.HoldDuration = holdFor()
	local hp = model:GetAttribute("Health") or 0
	local max = model:GetAttribute("MaxHealth") or hp
	prompt.ObjectText = string.format("%s · %d/%d", tostring(model:GetAttribute("Label") or "Veio"), hp, max)
end

local function track(model: Instance)
	if not model:IsA("Model") or model.Name ~= "CrystalVein" then
		return
	end
	task.defer(function()
		local core = model:FindFirstChild("VeinCore")
		local prompt = core and core:FindFirstChild("MinePrompt")
		if not prompt or not prompt:IsA("ProximityPrompt") then
			return
		end
		prompts[prompt] = model :: Model
		refresh(prompt, model :: Model)
		prompt.PromptButtonHoldBegan:Connect(startSwing)
		prompt.PromptButtonHoldEnded:Connect(stopSwing)
		model:GetAttributeChangedSignal("Health"):Connect(function()
			refresh(prompt, model :: Model)
		end)
		model.AncestryChanged:Connect(function()
			if not model.Parent then
				prompts[prompt] = nil
			end
		end)
	end)
end

function MiningClient.init()
	task.spawn(function()
		local f = workspace:WaitForChild("CrystalVeins", 60)
		if not f then
			return
		end
		for _, m in ipairs(f:GetChildren()) do
			track(m)
		end
		f.ChildAdded:Connect(track)
	end)
	lp:GetAttributeChangedSignal("Pickaxe"):Connect(function()
		for prompt, model in pairs(prompts) do
			refresh(prompt, model)
		end
	end)
end

return MiningClient

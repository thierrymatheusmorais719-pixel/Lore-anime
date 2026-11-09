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

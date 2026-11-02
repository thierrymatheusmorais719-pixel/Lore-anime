-- Entrada: clique/toque no mundo (mirar inimigo, minerar recurso, abrir tesouro),
-- F = ataque básico, Tab/Q = alternar alvo próximo. O servidor valida tudo.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local State = require(script.Parent.State)

local Input = {}
local player = Players.LocalPlayer
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function classify(inst: Instance?)
	local enemies, bosses, res, tre = workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Bosses"), workspace:FindFirstChild("Resources"), workspace:FindFirstChild("Treasures")
	while inst and inst ~= workspace do
		local parent = inst.Parent
		if parent == enemies or parent == bosses then
			return "enemy", inst
		elseif parent == res then
			return "resource", inst
		elseif parent == tre then
			return "treasure", inst
		end
		inst = parent
	end
	return nil, nil
end

-- viewport = true para posições de TouchTapInWorld (coordenadas do viewport);
-- false para InputObject.Position do mouse (coordenadas de GUI, sem o inset do topo).
local function pick(screenPos: Vector2, viewport: boolean?)
	local cam = workspace.CurrentCamera
	local ray = viewport and cam:ViewportPointToRay(screenPos.X, screenPos.Y) or cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	local ex = { workspace:FindFirstChild("Pets"), workspace:FindFirstChild("Telegraphs"), cam }
	if player.Character then
		table.insert(ex, player.Character)
	end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if not hit then
		return
	end
	local kind, model = classify(hit.Instance)
	if kind == "enemy" then
		State.action("Target", model)
		State.action("Attack", model)
	elseif kind == "resource" then
		State.action("Mine", model)
	elseif kind == "treasure" then
		State.action("OpenTreasure", model)
	end
end

local function nearestEnemy()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local folder = workspace:FindFirstChild("Enemies")
	if not root or not folder then
		return
	end
	local current = player:GetAttribute("Target")
	local best, bestD = nil, 60
	for _, m in ipairs(folder:GetChildren()) do
		local pp = m.PrimaryPart
		if pp and not m:GetAttribute("Dead") and m:GetAttribute("Entity") ~= current then
			local d = (pp.Position - (root :: BasePart).Position).Magnitude
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	if best then
		State.action("Target", best)
	end
end

function Input.init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pick(Vector2.new(input.Position.X, input.Position.Y), false)
		elseif input.KeyCode == Enum.KeyCode.F then
			State.action("Attack", nil)
		elseif input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.Q then
			nearestEnemy()
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(pos, processedByUI)
		if not processedByUI then
			pick(pos, true)
		end
	end)
end

return Input

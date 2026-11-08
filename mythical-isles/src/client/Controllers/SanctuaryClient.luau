-- Efeitos da Árvore-Santuário (Verdant Haven) no cliente: as runas do tronco acendem em ondas que sobem
-- anel por anel (a cada ~6 s); depois que o jogador vence o Elderroot, a luz das runas fica dourada.
-- A estrela da Coroa Estelar gira. Só anima quando o jogador está perto da árvore.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local State = require(script.Parent.State)

local SanctuaryClient = {}

SanctuaryClient.RANGE = 1200
SanctuaryClient.PERIOD = 6

local DIM, BRIGHT = Color3.fromRGB(40, 110, 60), Color3.fromRGB(150, 255, 160)
local GOLD_DIM, GOLD = Color3.fromRGB(120, 90, 30), Color3.fromRGB(255, 220, 120)

local runes: { { part: BasePart, ring: number } } = {}
local rings = 1
local spinners: { BasePart } = {}
local center: Vector3? = nil

local function awakened(): boolean
	local p = State.profile
	return p ~= nil and p.bestiary ~= nil and p.bestiary.bosses ~= nil and p.bestiary.bosses.elderroot ~= nil
end

-- Brilho do anel `ring` no instante t (onda que sobe de 1 até `rings`).
function SanctuaryClient.glow(ring: number, t: number): number
	local phase = (t / SanctuaryClient.PERIOD) % 1
	local head = phase * (rings + 2)
	return math.clamp(1 - math.abs(head - ring), 0, 1)
end

function SanctuaryClient.update(t: number)
	if #runes == 0 or not center then
		return
	end
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = workspace.CurrentCamera
	local pos = hrp and hrp.Position or (cam and cam.CFrame.Position)
	if pos and (pos - center).Magnitude > SanctuaryClient.RANGE then
		return
	end
	local gold = awakened()
	local dim, bright = gold and GOLD_DIM or DIM, gold and GOLD or BRIGHT
	for _, r in ipairs(runes) do
		local k = SanctuaryClient.glow(r.ring, t)
		r.part.Color = dim:Lerp(bright, 0.25 + 0.75 * k)
	end
	for _, s in ipairs(spinners) do
		if s.Parent then
			s.CFrame = CFrame.new(s.Position) * CFrame.Angles(math.rad(45), t * 0.8, 0)
		end
	end
end

function SanctuaryClient.scan(tree: Instance)
	table.clear(runes)
	table.clear(spinners)
	rings = 1
	for _, d in ipairs(tree:GetDescendants()) do
		if d:IsA("BasePart") then
			local ring = d:GetAttribute("RuneRing")
			if ring then
				table.insert(runes, { part = d, ring = ring })
				rings = math.max(rings, ring)
			elseif d:GetAttribute("Spin") then
				table.insert(spinners, d)
			end
		end
	end
	center = (tree :: Model):GetPivot().Position
	return #runes
end

function SanctuaryClient.init()
	task.spawn(function()
		local world = workspace:WaitForChild("World", 30)
		local verdant = world and world:WaitForChild("verdant", 30)
		local tree = verdant and verdant:WaitForChild("SanctuaryTree", 30)
		if not tree then
			return
		end
		SanctuaryClient.scan(tree)
		local t, acc = 0, 0
		RunService.Heartbeat:Connect(function(dt)
			t += dt
			acc += dt
			if acc >= 1 / 15 then
				acc = 0
				SanctuaryClient.update(t)
			end
		end)
	end)
end

return SanctuaryClient

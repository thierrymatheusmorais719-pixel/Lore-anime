--!strict
-- Balanço do cabelo de Mugetsu: soma de senoides em Motor6D.Transform dos segmentos (tag MugetsuHair).
-- Só processa segmentos da forma ativa, com limite de distância; um único laço para todos.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HairSway = {}

local motors: { [Motor6D]: boolean } = {}
local wind = 0
local windDecay = 0
local MAX_DIST = 120

function HairSway.gust(strength: number, decayTime: number)
	wind = strength
	windDecay = strength / math.max(decayTime, 0.1)
end

function HairSway.init()
	local function add(i: Instance)
		if i:IsA("Motor6D") then
			motors[i] = true
		end
	end
	for _, i in CollectionService:GetTagged("MugetsuHair") do
		add(i)
	end
	CollectionService:GetInstanceAddedSignal("MugetsuHair"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("MugetsuHair"):Connect(function(i)
		motors[i :: Motor6D] = nil
	end)
	RunService.PreRender:Connect(function(dt)
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		if wind > 0 then
			wind = math.max(0, wind - windDecay * dt)
		end
		local t = os.clock()
		local camPos = cam.CFrame.Position
		for m in motors do
			local seg = m.Part1
			local kit = seg and seg.Parent
			local root = kit and kit.Parent
			if seg and root and root.Name == "MugetsuKits" then
				if root:GetAttribute("Form") == "Mugetsu" and (seg.Position - camPos).Magnitude < MAX_DIST then
					local idx = (m:GetAttribute("Index") :: number? or 1)
					local ph = (m:GetAttribute("Phase") :: number? or 0)
					local amp = math.rad(3 + idx * 2.2) * (1 + wind * 2.5)
					m.Transform = CFrame.Angles(math.sin(t * 1.6 + ph + idx * 0.7) * amp, 0, math.sin(t * 1.1 + ph * 1.3 + idx * 0.5) * amp * 0.8)
				else
					m.Transform = CFrame.identity
				end
			end
		end
	end)
end

return HairSway

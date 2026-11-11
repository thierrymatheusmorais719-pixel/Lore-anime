-- Cliente: assim que o personagem aparece, toca a cinemática. No fim, cartão final com "Assistir de novo".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Duelo = ReplicatedStorage:WaitForChild("Duelo")
local Timeline = require(Duelo:WaitForChild("Timeline"))
local Ui = require(Duelo:WaitForChild("Ui"))

local lp = Players.LocalPlayer

local function setCore(on: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, on)
	end)
end

local function freeze(on: boolean)
	local char = lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = on
	end
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = on and 1 or 0
			end
		end
	end
end

local function play()
	setCore(false)
	freeze(true)
	Timeline.play(function()
		Ui.mount()
		local g = Ui.get()
		if g then
			local fade = g:FindFirstChild("Fade") :: Frame
			fade.BackgroundTransparency = 0
			local skip = g:FindFirstChild("Skip")
			if skip then
				skip:Destroy()
			end
			for _, n in ipairs({ "BarTop", "BarBottom" }) do
				local b = g:FindFirstChild(n)
				if b then
					b:Destroy()
				end
			end
		end
		Ui.endCard("CONTINUA...", "Ren Arashi  ✦  Akane Sumi", function()
			Ui.unmount()
			play()
		end)
		freeze(false)
		setCore(true)
	end)
end

if not lp.Character then
	lp.CharacterAdded:Wait()
end
task.wait(1)
play()

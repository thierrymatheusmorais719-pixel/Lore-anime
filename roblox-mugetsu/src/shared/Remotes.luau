--!strict
-- Criação/obtenção centralizada dos RemoteEvents. O servidor cria; o cliente espera.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = {
	"RequestTransform", -- C->S
	"RequestAbility", -- C->S
	"CutsceneStart", -- S->C  (alvo: dono da cutscene)
	"CutsceneObserve", -- S->C  (observadores próximos)
	"CutsceneCancel", -- S->C
	"CutsceneEnd", -- S->C
	"AbilityTelegraph", -- S->C (todos)
	"AbilityFire", -- S->C (todos)
	"AbilityCooldown", -- S->C (dono)
	"Notify", -- S->C
}

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "MugetsuRemotes"
	for _, n in NAMES do
		local r = Instance.new("RemoteEvent")
		r.Name = n
		r.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("MugetsuRemotes") :: Folder
end

function Remotes.get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes

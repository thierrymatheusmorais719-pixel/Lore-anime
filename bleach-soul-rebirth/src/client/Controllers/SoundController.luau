-- Sons 3D com variação de tom e pool por nome.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local SoundController = {}

local rng = Random.new()
local holder: Part

-- Toca `name` em `where` (Vector3 = posição no mundo; BasePart = preso à peça; nil = 2D).
function SoundController.Play(name: string, where: (Vector3 | BasePart)?, volumeScale: number?)
	local def = Sounds[name]
	if not def then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.id
	sound.Volume = def.volume * (volumeScale or 1)
	sound.PlaybackSpeed = rng:NextNumber(def.pitch[1], def.pitch[2])
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = 220
	if typeof(where) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = where
		attachment.Parent = holder
		sound.Parent = attachment
		Debris:AddItem(attachment, 4)
	elseif typeof(where) == "Instance" then
		sound.Parent = where
		Debris:AddItem(sound, 4)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, 4)
	end
	sound:Play()
	return sound
end

function SoundController.Init()
	holder = Instance.new("Part")
	holder.Name = "SoundHolder"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.identity
	holder.Parent = workspace
end

function SoundController.Start() end

return SoundController

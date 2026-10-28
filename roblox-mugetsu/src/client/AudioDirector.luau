--!strict
-- Áudio da cutscene. Só toca sons cujo ID existe no AssetManifest (nenhum ID é inventado).
-- Também abaixa o volume dos sons ambientes existentes e os restaura ao final.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Manifest = require(game:GetService("ReplicatedStorage"):WaitForChild("Mugetsu"):WaitForChild("AssetManifest"))

local AudioDirector = {}

local ducked: { [Sound]: number } = {}
local live: { Sound } = {}

function AudioDirector.missing(): { string }
	local out = {}
	for name, entry in Manifest.Sounds do
		if entry.id == "" then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end

function AudioDirector.play(name: string, volumeScale: number?, looped: boolean?): Sound?
	local entry = Manifest.Sounds[name]
	if not entry or entry.id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Mugetsu_" .. name
	s.SoundId = entry.id
	s.Volume = entry.volume * (volumeScale or 1)
	s.Looped = looped == true
	s.Parent = SoundService
	s:Play()
	table.insert(live, s)
	if not s.Looped then
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
	return s
end

function AudioDirector.duck(scale: number, time: number)
	local function consider(root: Instance)
		for _, d in root:GetDescendants() do
			if d:IsA("Sound") and not string.find(d.Name, "^Mugetsu_") and ducked[d] == nil then
				ducked[d] = d.Volume
			end
		end
	end
	consider(Workspace)
	consider(SoundService)
	for s, base in ducked do
		if s.Parent then
			TweenService:Create(s, TweenInfo.new(time), { Volume = base * scale }):Play()
		end
	end
end

function AudioDirector.stopAll(fadeTime: number)
	for s, base in ducked do
		if s.Parent then
			TweenService:Create(s, TweenInfo.new(fadeTime), { Volume = base }):Play()
		end
	end
	ducked = {}
	for _, s in live do
		if s.Parent then
			TweenService:Create(s, TweenInfo.new(fadeTime), { Volume = 0 }):Play()
			task.delay(fadeTime + 0.05, function()
				s:Destroy()
			end)
		end
	end
	live = {}
end

return AudioDirector

-- Servidor: monta a cidade à noite (todos veem o mesmo cenário). A luta em si é uma cinemática no cliente.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local City = require(ReplicatedStorage:WaitForChild("Duelo"):WaitForChild("City"))

City.build(workspace)
City.lighting()

-- ponto de nascimento no telhado da arena (o jogador assiste daqui; a câmera é da cinemática)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Anchored = true
spawn.Size = Vector3.new(6, 1, 6)
spawn.Transparency = 1
spawn.CanCollide = true
spawn.CFrame = CFrame.new(City.ArenaCenter + Vector3.new(0, 0.6, 30))
spawn.Parent = workspace

-- Avatares com itens do catálogo (só se Appearance tiver algum ID). Ficam em ReplicatedStorage.DueloAvatars.
local Players = game:GetService("Players")
local Appearance = require(ReplicatedStorage:WaitForChild("Duelo"):WaitForChild("Appearance"))
local Rig = require(ReplicatedStorage:WaitForChild("Duelo"):WaitForChild("Rig"))
if Appearance.anyUsed() then
	local folder = Instance.new("Folder")
	folder.Name = "DueloAvatars"
	for key, a in pairs(Appearance.Fighters) do
		if Appearance.uses(key) then
			local ok, model = pcall(function()
				local d = Instance.new("HumanoidDescription")
				d.Shirt = a.shirt or 0
				d.Pants = a.pants or 0
				d.HairAccessory = a.hair or ""
				d.HatAccessory = a.accessories or ""
				d.Face = a.face or 0
				local skin = a.skin or Rig.Fighters[key].skin
				d.HeadColor, d.TorsoColor = skin, skin
				d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor = skin, skin, skin, skin
				return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
			end)
			if ok and model then
				model.Name = key
				model.Parent = folder
			else
				warn("[Duelo] avatar de " .. key .. " não carregou (usando o modelo de peças): " .. tostring(model))
			end
		end
	end
	folder.Parent = ReplicatedStorage
end
ReplicatedStorage:SetAttribute("AvatarsReady", true)

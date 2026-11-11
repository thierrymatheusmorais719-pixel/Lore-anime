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

-- Avatares R15 do Roblox para os dois lutadores (cores de cada personagem + itens de Appearance.luau, se houver).
-- Ficam em ReplicatedStorage.DueloAvatars; se não der para montar, o cliente usa o R15 "blocky" de peças.
local Players = game:GetService("Players")
local Appearance = require(ReplicatedStorage:WaitForChild("Duelo"):WaitForChild("Appearance"))
local Rig = require(ReplicatedStorage:WaitForChild("Duelo"):WaitForChild("Rig"))
local folder = Instance.new("Folder")
folder.Name = "DueloAvatars"
for key, def in pairs(Rig.Fighters) do
	local a = Appearance.Fighters[key] or {}
	local ok, model = pcall(function()
		local d = Instance.new("HumanoidDescription")
		d.Shirt = a.shirt or 0
		d.Pants = a.pants or 0
		d.HairAccessory = a.hair or ""
		d.HatAccessory = a.accessories or ""
		d.Face = a.face or 0
		local skin = a.skin or def.skin
		d.HeadColor = skin
		d.TorsoColor = def.torso
		d.LeftArmColor, d.RightArmColor = def.arms, def.arms
		d.LeftLegColor, d.RightLegColor = def.legs, def.legs
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		model.Name = key
		model.Parent = folder
	else
		warn("[Duelo] avatar R15 de " .. key .. " não foi montado (usando o R15 de peças): " .. tostring(model))
	end
end
folder.Parent = ReplicatedStorage
ReplicatedStorage:SetAttribute("AvatarsReady", true)

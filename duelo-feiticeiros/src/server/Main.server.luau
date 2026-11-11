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

-- Definição central dos remotes. O servidor cria; o cliente espera.
--
-- Request (RemoteFunction): pedidos com resposta { ok, msg?, ... } — chocar, equipar, evoluir...
-- Action  (RemoteEvent C->S): ações rápidas de combate (alvo, ataque, habilidade).
-- Push    (RemoteEvent S->C): estado e notificações ("State", "Luck", "Toast", "Discovery",
--          "Announce", "Drop", "Damage", "AbilityFx", "BossUI", "Treasure", "Phase").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local FOLDER = "Remotes"
local DEFS = { Request = "RemoteFunction", Action = "RemoteEvent", Push = "RemoteEvent" }

function Net.setup()
	assert(RunService:IsServer(), "Net.setup só no servidor")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER
		folder.Parent = ReplicatedStorage
	end
	for name, class in pairs(DEFS) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new(class)
			r.Name = name
			r.Parent = folder
		end
	end
	return folder
end

function Net.get(name: string): any
	local folder = ReplicatedStorage:WaitForChild(FOLDER)
	return folder:WaitForChild(name)
end

return Net

-- Definição central dos RemoteEvents/RemoteFunctions. O servidor cria; o cliente aguarda.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Events = {
	CombatInput = true, -- C→S: intenção de ação (ataque, bloqueio, dash, habilidade, transformação)
	Fx = true, -- S→todos: animações/efeitos de atores
	Impulse = true, -- S→dono: knockback, teleporte, flutuar
	State = true, -- S→dono: cooldowns e estados privados
	DataSync = true, -- S→dono: dados do perfil
	Notify = true, -- S→dono: avisos na tela
	Dialogue = true, -- S→dono: abrir/fechar diálogo
}

Net.Functions = {
	Request = true, -- C→S: menus (atributos, inventário, missões, poderes, viagem, configurações)
}

local FOLDER_NAME = "Remotes"

function Net.init()
	assert(RunService:IsServer(), "Net.init só no servidor")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for name in Net.Events do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for name in Net.Functions do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

local function folder(): Instance
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Net.event(name: string): RemoteEvent
	assert(Net.Events[name], "RemoteEvent desconhecido: " .. name)
	return folder():WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	assert(Net.Functions[name], "RemoteFunction desconhecida: " .. name)
	return folder():WaitForChild(name) :: RemoteFunction
end

return Net

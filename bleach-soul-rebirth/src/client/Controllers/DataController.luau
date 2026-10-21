-- Cache local do perfil (somente leitura) e pedidos ao servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local DataController = {}
DataController.Changed = Signal.new() -- (profile)
DataController.Profile = nil :: any

local requestRemote: RemoteFunction

-- Envia pedido de menu; retorna (ok, dadosOuErro).
function DataController.Request(kind: string, payload: any?): (boolean, any)
	local ok, result = pcall(function()
		return requestRemote:InvokeServer(kind, payload)
	end)
	if not ok or type(result) ~= "table" then
		return false, "Sem resposta do servidor"
	end
	if result.ok then
		return true, result.data
	end
	return false, result.err
end

function DataController.WaitForProfile(): any
	while not DataController.Profile do
		DataController.Changed:Wait()
	end
	return DataController.Profile
end

function DataController.Init()
	requestRemote = Net.func("Request")
end

function DataController.Start()
	Net.event("DataSync").OnClientEvent:Connect(function(profile)
		DataController.Profile = profile
		DataController.Changed:Fire(profile)
	end)
end

return DataController

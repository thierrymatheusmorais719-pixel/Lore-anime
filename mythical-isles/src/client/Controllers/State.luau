-- Estado recebido do servidor (somente leitura no cliente) + barramento de eventos local.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local State = {
	profile = nil,
	derived = nil,
	luck = nil,
	serverOffset = 0,
	memoryMode = false,
}

local listeners: { [string]: { (any) -> () } } = {}

function State.on(event: string, fn)
	listeners[event] = listeners[event] or {}
	table.insert(listeners[event], fn)
end

function State.emit(event: string, payload)
	for _, fn in ipairs(listeners[event] or {}) do
		task.spawn(fn, payload)
	end
end

local Request

function State.request(action: string, payload)
	Request = Request or Net.get("Request")
	local ok, result = pcall(function()
		return Request:InvokeServer(action, payload)
	end)
	if not ok then
		return { ok = false, msg = "Sem resposta do servidor" }
	end
	return result or { ok = false }
end

local Action
function State.action(name: string, arg)
	Action = Action or Net.get("Action")
	Action:FireServer(name, arg)
end

function State.now(): number
	return os.time() + State.serverOffset
end

function State.init()
	local Push = Net.get("Push")
	Push.OnClientEvent:Connect(function(kind: string, payload)
		if kind == "State" then
			State.profile = payload.profile
			State.derived = payload.derived
			State.memoryMode = payload.memoryMode
			State.serverOffset = (payload.serverTime or os.time()) - os.time()
			State.emit("State", payload)
		elseif kind == "Luck" then
			State.luck = payload
			State.emit("Luck", payload)
		else
			State.emit(kind, payload)
		end
	end)
end

return State

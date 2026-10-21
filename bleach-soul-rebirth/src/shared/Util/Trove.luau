-- Trove: agrupa conexões, instâncias, threads e funções de limpeza para descarte único.
local Trove = {}
Trove.__index = Trove

function Trove.new()
	return setmetatable({ _items = {} }, Trove)
end

function Trove:Add<T>(item: T): T
	table.insert(self._items, item)
	return item
end

function Trove:Connect(signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(fn)
	table.insert(self._items, connection)
	return connection
end

function Trove:Extend()
	return self:Add(Trove.new())
end

local function cleanup(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		if coroutine.status(item) == "suspended" then
			pcall(task.cancel, item)
		end
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.Clean) == "function" then
			item:Clean()
		end
	end
end

function Trove:Clean()
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local ok, err = pcall(cleanup, items[i])
		if not ok then
			warn("[Trove] falha ao limpar item:", err)
		end
	end
end

Trove.Destroy = Trove.Clean

return Trove

--!strict
-- Coletor de limpeza: conexões, instâncias, funções, threads e tweens.

local Maid = {}
Maid.__index = Maid

export type Maid = typeof(setmetatable({} :: { tasks: { any }, destroyed: boolean }, Maid))

function Maid.new(): Maid
	return setmetatable({ tasks = {}, destroyed = false }, Maid)
end

function Maid.give(self: Maid, task_: any): any
	if self.destroyed then
		Maid._clean(task_)
		return task_
	end
	table.insert(self.tasks, task_)
	return task_
end

function Maid._clean(t: any)
	local ty = typeof(t)
	if ty == "RBXScriptConnection" then
		t:Disconnect()
	elseif ty == "Instance" then
		pcall(function()
			t:Destroy()
		end)
	elseif ty == "function" then
		pcall(t)
	elseif ty == "thread" then
		pcall(task.cancel, t)
	elseif ty == "table" then
		if type(t.Destroy) == "function" then
			pcall(t.Destroy, t)
		elseif type(t.Cancel) == "function" then
			pcall(t.Cancel, t)
		end
	end
end

function Maid.clean(self: Maid)
	local tasks = self.tasks
	self.tasks = {}
	for i = #tasks, 1, -1 do
		Maid._clean(tasks[i])
	end
end

function Maid.destroy(self: Maid)
	self:clean()
	self.destroyed = true
end

return Maid

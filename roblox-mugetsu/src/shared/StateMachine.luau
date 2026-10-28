--!strict
-- Máquina de estados da cutscene (lógica pura, testável fora do Roblox).
-- Idle -> Starting -> Running -> Climax -> Finishing -> Idle
-- Cancelled pode ser alcançado a partir de qualquer estado ativo e sempre volta para Idle.

export type State = "Idle" | "Starting" | "Running" | "Climax" | "Finishing" | "Cancelled"

local ALLOWED: { [State]: { [State]: boolean } } = {
	Idle = { Starting = true },
	Starting = { Running = true, Cancelled = true },
	Running = { Climax = true, Cancelled = true, Finishing = true },
	Climax = { Finishing = true, Cancelled = true },
	Finishing = { Idle = true, Cancelled = true },
	Cancelled = { Idle = true },
}

local StateMachine = {}
StateMachine.__index = StateMachine

export type Machine = typeof(setmetatable(
	{} :: { state: State, listeners: { (State, State) -> () } },
	StateMachine
))

function StateMachine.new(): Machine
	return setmetatable({ state = "Idle" :: State, listeners = {} }, StateMachine)
end

function StateMachine.canTransition(self: Machine, to: State): boolean
	local row = ALLOWED[self.state]
	return row ~= nil and row[to] == true
end

function StateMachine.transition(self: Machine, to: State): boolean
	if not StateMachine.canTransition(self, to) then
		return false
	end
	local from = self.state
	self.state = to
	for _, fn in self.listeners do
		task.spawn(fn, from, to)
	end
	return true
end

-- Reset forçado para o recuperar de erros/cancelamento: sempre termina em Idle.
function StateMachine.reset(self: Machine)
	if self.state ~= "Idle" then
		local from = self.state
		self.state = "Idle"
		for _, fn in self.listeners do
			task.spawn(fn, from, "Idle" :: State)
		end
	end
end

function StateMachine.onChanged(self: Machine, fn: (State, State) -> ())
	table.insert(self.listeners, fn)
end

function StateMachine.isActive(self: Machine): boolean
	return self.state ~= "Idle"
end

return StateMachine

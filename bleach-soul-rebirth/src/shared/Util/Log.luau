-- Logger com escopo. Debug só aparece no Studio ou com Log.Verbose = true.
local RunService = game:GetService("RunService")

local Log = {}
Log.__index = Log
Log.Verbose = RunService:IsStudio()

function Log.new(scope: string)
	return setmetatable({ _prefix = "[" .. scope .. "]" }, Log)
end

function Log:Info(...: any)
	print(self._prefix, ...)
end

function Log:Debug(...: any)
	if Log.Verbose then
		print(self._prefix, "(debug)", ...)
	end
end

function Log:Warn(...: any)
	warn(self._prefix, ...)
end

function Log:Error(...: any)
	-- Não lança: registra com traceback para facilitar investigação.
	warn(self._prefix, "ERRO:", ..., "\n" .. debug.traceback(nil, 2))
end

return Log

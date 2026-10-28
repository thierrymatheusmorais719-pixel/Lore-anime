--!strict
-- Teclas configuráveis (Config) + trava de controles durante a cutscene.
-- Trava: sorve todo input via ContextActionService e desativa os Controls do PlayerModule.
-- unlock() é idempotente e é chamado por TODOS os caminhos de saída (fim, cancelamento, erro).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Mugetsu"):WaitForChild("Config"))

local InputController = {}

local LOCK = "MugetsuLockInput"
local locked = false

local function controls(): any?
	local ok, c = pcall(function()
		local ps = Players.LocalPlayer:WaitForChild("PlayerScripts", 2)
		local pm = ps and ps:WaitForChild("PlayerModule", 2)
		return pm and require(pm :: ModuleScript):GetControls()
	end)
	return ok and c or nil
end

function InputController.bind(onTransform: () -> (), onAbility: () -> ())
	ContextActionService:BindAction("MugetsuTransform", function(_, state)
		if state == Enum.UserInputState.Begin then
			onTransform()
		end
		return Enum.ContextActionResult.Pass
	end, false, Config.Transform.Keybind)
	ContextActionService:BindAction("MugetsuAbility", function(_, state)
		if state == Enum.UserInputState.Begin then
			onAbility()
		end
		return Enum.ContextActionResult.Pass
	end, false, Config.Ability.Keybind)
end

function InputController.lock()
	if locked then
		return
	end
	locked = true
	ContextActionService:BindActionAtPriority(LOCK, function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 10,
		Enum.UserInputType.Keyboard, Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2,
		Enum.UserInputType.Gamepad1)
	local c = controls()
	if c then
		pcall(function()
			c:Disable()
		end)
	end
end

function InputController.unlock()
	if not locked then
		return
	end
	locked = false
	ContextActionService:UnbindAction(LOCK)
	local c = controls()
	if c then
		pcall(function()
			c:Enable()
		end)
	end
end

function InputController.isLocked(): boolean
	return locked
end

return InputController

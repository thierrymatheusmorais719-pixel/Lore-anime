-- Mapeamento unificado de entrada: teclado/mouse, controle e toque (botões da HUD chamam Fire).
-- Emite Action(nome, começou: boolean). Menus abertos desativam as ações de combate.
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local InputController = {}
InputController.Action = Signal.new() -- (action: string, began: boolean)
InputController.ModeChanged = Signal.new() -- ("Keyboard" | "Gamepad" | "Touch")

-- Ação → teclas
InputController.Bindings = {
	Attack = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
	Heavy = { Enum.KeyCode.E, Enum.KeyCode.ButtonR1 },
	Launcher = { Enum.KeyCode.R, Enum.KeyCode.ButtonX },
	Block = { Enum.KeyCode.F, Enum.KeyCode.ButtonL2 },
	Dash = { Enum.KeyCode.Q, Enum.KeyCode.ButtonB },
	Z = { Enum.KeyCode.Z, Enum.KeyCode.DPadLeft },
	X = { Enum.KeyCode.X, Enum.KeyCode.DPadUp },
	C = { Enum.KeyCode.C, Enum.KeyCode.DPadRight },
	V = { Enum.KeyCode.V, Enum.KeyCode.DPadDown },
	Transform = { Enum.KeyCode.G, Enum.KeyCode.ButtonL1 },
	Mask = { Enum.KeyCode.H, Enum.KeyCode.ButtonY },
	Charge = { Enum.KeyCode.T, Enum.KeyCode.ButtonR3 },
	Sprint = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 },
	Draw = { Enum.KeyCode.One },
	Item = { Enum.KeyCode.Four },
	Menu = { Enum.KeyCode.M, Enum.KeyCode.ButtonSelect },
}

-- Ações que não disparam com menu aberto
local COMBAT = {
	Attack = true, Heavy = true, Launcher = true, Block = true, Dash = true,
	Z = true, X = true, C = true, V = true, Transform = true, Mask = true,
	Charge = true, Sprint = true, Draw = true, Item = true,
}

local lookup: { [any]: string } = {}
local held: { [string]: boolean } = {}
local blocked = 0
local mode = "Keyboard"

local function rebuild()
	table.clear(lookup)
	for action, inputs in InputController.Bindings do
		for _, input in inputs do
			lookup[input] = action
		end
	end
end

function InputController.Fire(action: string, began: boolean)
	if began and COMBAT[action] and blocked > 0 then
		return
	end
	if held[action] == began then
		return
	end
	held[action] = began
	InputController.Action:Fire(action, began)
end

function InputController.IsHeld(action: string): boolean
	return held[action] == true
end

-- Bloqueio por menus (contador para menus aninhados)
function InputController.PushBlock()
	blocked += 1
	for action in COMBAT do
		if held[action] then
			InputController.Fire(action, false)
		end
	end
end

function InputController.PopBlock()
	blocked = math.max(0, blocked - 1)
end

function InputController.IsBlocked(): boolean
	return blocked > 0
end

function InputController.Mode(): string
	return mode
end

local function setMode(new: string)
	if new ~= mode then
		mode = new
		InputController.ModeChanged:Fire(mode)
	end
end

local function resolve(input: InputObject): string?
	return lookup[input.KeyCode] or lookup[input.UserInputType]
end

function InputController.Init()
	rebuild()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		mode = "Touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		mode = "Gamepad"
	end
end

function InputController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			setMode("Touch")
			return -- toque usa os botões da HUD
		elseif input.UserInputType == Enum.UserInputType.Gamepad1 then
			setMode("Gamepad")
		elseif input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setMode("Keyboard")
		end
		if processed or GuiService.MenuIsOpen then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		local action = resolve(input)
		if action then
			InputController.Fire(action, true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local action = resolve(input)
		if action and held[action] then
			InputController.Fire(action, false)
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		for action in held do
			if held[action] then
				InputController.Fire(action, false)
			end
		end
	end)
end

return InputController

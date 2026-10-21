-- Caixa de diálogo com NPCs (texto com efeito de digitação e opções validadas pelo servidor).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)
local DataController = require(script.Parent.DataController)
local InputController = require(script.Parent.InputController)
local SoundController = require(script.Parent.SoundController)

local DialogueController = {}
DialogueController.OpenMenu = nil :: ((string) -> ())?

local T = Kit.Theme
local player = Players.LocalPlayer
local gui: ScreenGui
local refs: { [string]: any } = {}
local current: any = nil
local typing = 0

local function close()
	if current then
		current = nil
		InputController.PopBlock()
	end
	gui.Enabled = false
end

local function show(payload)
	if not current then
		InputController.PushBlock()
	end
	current = payload
	gui.Enabled = true
	refs.name.Text = payload.name
	refs.title.Text = payload.title or ""
	typing += 1
	local token = typing
	local text = payload.text or ""
	refs.text.Text = text
	refs.text.MaxVisibleGraphemes = 0
	task.spawn(function()
		local count = utf8.len(text) or #text
		for i = 1, count, 2 do
			if typing ~= token then
				return
			end
			refs.text.MaxVisibleGraphemes = i
			task.wait(0.012)
		end
		refs.text.MaxVisibleGraphemes = -1
	end)
	for _, c in refs.options:GetChildren() do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	for i, option in payload.options do
		local button = Kit.button(option.text, {
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = i,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 15,
			BackgroundColor3 = if option.accent
				then Color3.fromRGB(50, 42, 20)
				elseif option.disabled then Color3.fromRGB(25, 25, 30)
				else T.PanelLight,
			TextColor3 = if option.disabled then T.Muted elseif option.accent then T.Gold else T.Text,
		})
		Kit.padding(10).Parent = button
		button.Parent = refs.options
		button.Activated:Connect(function()
			if option.disabled or current ~= payload then
				return
			end
			SoundController.Play("UIClick")
			local ok, result = DataController.Request("DialogueChoice", { npc = payload.npc, option = option.id })
			if not ok then
				refs.text.Text = tostring(result)
				refs.text.MaxVisibleGraphemes = -1
				return
			end
			if result and result.dialogue then
				show(result.dialogue)
			elseif result and result.open then
				close()
				if DialogueController.OpenMenu then
					DialogueController.OpenMenu(result.open)
				end
			else
				close()
			end
		end)
	end
end

function DialogueController.Init()
	gui = Kit.new("ScreenGui", {
		Name = "Dialogue",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local panel = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(760, 250),
		Parent = gui,
	})
	refs.name = Kit.label("", 22, {
		Position = UDim2.fromOffset(22, 14),
		Size = UDim2.fromOffset(500, 26),
		Font = T.FontTitle,
		TextColor3 = T.Gold,
		Parent = panel,
	})
	refs.title = Kit.label(
		"",
		14,
		{ Position = UDim2.fromOffset(22, 40), Size = UDim2.fromOffset(500, 18), TextColor3 = T.Muted, Parent = panel }
	)
	refs.text = Kit.label("", 17, {
		Position = UDim2.fromOffset(22, 64),
		Size = UDim2.new(0.55, -22, 1, -80),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = T.Font,
		Parent = panel,
	})
	refs.options = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0.57, 0, 0, 16),
		Size = UDim2.new(0.43, -18, 1, -32),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		BorderSizePixel = 0,
		Parent = panel,
	}, { Kit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local closeButton = Kit.button(
		"✕",
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(30, 30) },
		close
	)
	closeButton.Parent = panel
	Kit.autoScale(gui)
end

function DialogueController.Start()
	Net.event("Dialogue").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			show(payload)
		end
	end)
	player.CharacterRemoving:Connect(close)
end

return DialogueController

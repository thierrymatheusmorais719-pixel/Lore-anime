-- Tela de carregamento + diagnóstico visível.
-- Mostra "Construindo as ilhas..." até o personagem existir e, se o servidor ou o cliente
-- tiverem erro, mostra o texto do erro NA TELA (dá para tirar foto ou copiar).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.UIKit)

local Status = {}
local player = Players.LocalPlayer
local clientErrors = {}
local errorBox, errorText

local function refreshErrors()
	local server = ReplicatedStorage:GetAttribute("ServerErrors")
	local parts = {}
	if server and server ~= "" then
		table.insert(parts, "SERVIDOR:\n" .. server)
	end
	if #clientErrors > 0 then
		table.insert(parts, "CLIENTE:\n" .. table.concat(clientErrors, "\n\n"))
	end
	if errorBox then
		errorBox.Visible = #parts > 0
		errorText.Text = "⚠ O jogo encontrou um erro. Tire uma foto desta caixa e mande para o desenvolvedor:\n\n" .. table.concat(parts, "\n\n")
	end
end

function Status.reportClientError(msg: string)
	table.insert(clientErrors, msg)
	refreshErrors()
end

function Status.init()
	local gui = UIKit.screen("Status", 100)
	-- carregamento
	local loading = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 18, 34), BorderSizePixel = 0, Parent = gui })
	local title = UIKit.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(700, 70),
		Text = "Mythical Isles", Font = UIKit.Theme.title, TextSize = 56, TextColor3 = UIKit.Theme.gold, TextXAlignment = Enum.TextXAlignment.Center, Parent = loading })
	local sub = UIKit.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(700, 60),
		Text = "Construindo as ilhas...", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Parent = loading })
	-- caixa de erro (por cima de tudo)
	errorBox = UIKit.frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(820, 300),
		BackgroundColor3 = Color3.fromRGB(60, 14, 20), Visible = false, ZIndex = 50, Parent = gui })
	UIKit.stroke(errorBox, Color3.fromRGB(255, 90, 90), 2, 0)
	local scroll = UIKit.scroll({ Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20), ZIndex = 51, Parent = errorBox })
	errorText = UIKit.new("TextBox", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.Code, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		ClearTextOnFocus = false, TextEditable = false, MultiLine = true, Text = "", ZIndex = 52, Parent = scroll })
	ReplicatedStorage:GetAttributeChangedSignal("ServerErrors"):Connect(refreshErrors)
	refreshErrors()

	task.spawn(function()
		local t0 = os.clock()
		while not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") do
			task.wait(0.25)
			local elapsed = os.clock() - t0
			if elapsed > 20 then
				sub.Text = "O servidor ainda não criou seu personagem (" .. math.floor(elapsed) .. "s).\n"
					.. "No Studio, abra View → Output e mande o texto vermelho."
			elseif ReplicatedStorage:GetAttribute("ServerReady") then
				sub.Text = "Preparando seu personagem..."
			end
		end
		TweenService:Create(loading, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(title, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		TweenService:Create(sub, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		task.wait(0.7)
		loading.Visible = false
	end)
end

return Status

-- Tela de seleção de facção no estilo "escolha seu time": quatro cartões grandes lado a lado
-- (Shinigami, Quincy, Hollow, Fullbringer), cada um com personagem 3D posado, cor da facção,
-- nome gigante, kanji de fundo, etiquetas de estilo de luta e animações de foco/clique.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Factions = require(Shared.Config.Factions)
local Powers = require(Shared.Config.Powers)

local Kit = require(script.Parent.Parent.UI.Kit)
local FactionShowcase = require(script.Parent.Parent.UI.FactionShowcase)
local DataController = require(script.Parent.DataController)
local SoundController = require(script.Parent.SoundController)

local FactionSelectController = {}

local T = Kit.Theme
local player = Players.LocalPlayer
local gui: ScreenGui
local orbit: RBXScriptConnection? = nil
local viewportUpdaters: { (number) -> () } = {}
local busy = false

-- Ordem e textos dos cartões (equivalente a Piratas/Marinha, com quatro caminhos)
local CARDS = {
	{
		id = "Shinigami",
		tagline = "GUARDIÕES DAS ALMAS",
		tags = { "Espada", "Kidō", "Bankai" },
		difficulty = 2,
	},
	{
		id = "Quincy",
		tagline = "ARQUEIROS DO REISHI",
		tags = { "Arco", "Distância", "Vollständig" },
		difficulty = 3,
	},
	{
		id = "Hollow",
		tagline = "PREDADORES DO VAZIO",
		tags = { "Garras", "Cero", "Resurrección" },
		difficulty = 1,
	},
	{
		id = "Fullbringer",
		tagline = "A ALMA DOS OBJETOS",
		tags = { "Punhos", "Correntes", "Fullbring" },
		difficulty = 2,
	},
}

local function startOrbit()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	orbit = RunService.RenderStepped:Connect(function(dt)
		local a = (os.clock() - start) * 0.05
		local center = Vector3.new(0, 10, 0)
		camera.CFrame = CFrame.lookAt(center + Vector3.new(math.cos(a) * 80, 34, math.sin(a) * 80), center)
		for _, update in viewportUpdaters do
			update(dt)
		end
	end)
end

local function stopOrbit()
	if orbit then
		orbit:Disconnect()
		orbit = nil
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

local function difficultyText(level: number): string
	return string.rep("★", level) .. string.rep("☆", 3 - level)
end

local function choose(factionId: string, button: TextButton)
	if busy then
		return
	end
	busy = true
	SoundController.Play("Draw")
	button.Text = "ENTRANDO..."
	local ok, err = DataController.Request("ChooseFaction", { faction = factionId })
	busy = false
	if ok then
		FactionSelectController.Hide()
	else
		button.Text = "JOGAR"
		warn("[FactionSelect]", err)
	end
end

local function buildCard(parent: Instance, info, order: number)
	local faction = Factions[info.id]
	local color: Color3 = faction.color
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.82)

	local card = Kit.new("TextButton", {
		Name = info.id,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = dark,
		Size = UDim2.fromOffset(250, 470),
		LayoutOrder = order,
		ClipsDescendants = true,
		Parent = parent,
	}, {
		Kit.corner(14),
		Kit.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(0, 0, 0), 0.45)),
				ColorSequenceKeypoint.new(0.55, dark),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 6, 10)),
			}),
		}),
	})
	local stroke = Kit.new(
		"UIStroke",
		{
			Color = color,
			Thickness = 2,
			Transparency = 0.55,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = card,
		}
	)
	local scale = Kit.new("UIScale", { Parent = card })

	-- Kanji gigante de fundo
	Kit.label(faction.kanji, 150, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(1.4, 0, 0, 170),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontTitle,
		TextColor3 = color,
		TextTransparency = 0.82,
		TextScaled = true,
		Parent = card,
	})
	-- Feixe de luz atrás do personagem
	Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0.55, 0, 0.72, 0),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Parent = card,
	}, {
		Kit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		}),
	})

	-- Personagem 3D
	local viewHolder = Kit.new(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 300), Parent = card }
	)
	local ok, viewport, update = pcall(FactionShowcase.Viewport, info.id, color)
	if ok and viewport then
		viewport.Parent = viewHolder
		table.insert(viewportUpdaters, update)
	end

	-- Faixa inferior com nome
	local bottom = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 175),
		BackgroundColor3 = Color3.fromRGB(8, 8, 12),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Parent = card,
	}, {
		Kit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.25, 0.15),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}),
	})
	Kit.label(info.tagline, 12, {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontBold,
		TextColor3 = color,
		Parent = bottom,
	})
	Kit.label(string.upper(faction.id), 38, {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 42),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontAnime,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = bottom,
	}, { Kit.new("UIStroke", { Color = color:Lerp(Color3.new(0, 0, 0), 0.5), Thickness = 2.5 }) })
	-- Etiquetas
	local tags = Kit.new(
		"Frame",
		{
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 90),
			Size = UDim2.new(1, -20, 0, 22),
			Parent = bottom,
		},
		{
			Kit.new(
				"UIListLayout",
				{
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 5),
				}
			),
		}
	)
	for _, tag in info.tags do
		Kit.new("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.75,
			Text = "  " .. tag .. "  ",
			TextSize = 12,
			Font = T.FontBold,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = tags,
		}, { Kit.corner(10) })
	end
	Kit.label(
		"Dificuldade  "
			.. difficultyText(info.difficulty)
			.. "   ·   Poder inicial: "
			.. Powers.List[Powers.Starter[info.id]].name,
		11,
		{
			Position = UDim2.fromOffset(0, 116),
			Size = UDim2.new(1, 0, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = T.Muted,
			Font = T.Font,
			Parent = bottom,
		}
	)
	local play = Kit.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -40, 0, 30),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "JOGAR",
		TextSize = 18,
		Font = T.FontTitle,
		TextColor3 = Color3.fromRGB(10, 10, 14),
		Parent = bottom,
	}, { Kit.corner(8) })

	-- Interações
	local function hover(on: boolean)
		Kit.tween(scale, 0.18, { Scale = if on then 1.05 else 1 }, Enum.EasingStyle.Back)
		Kit.tween(stroke, 0.18, { Transparency = if on then 0 else 0.55, Thickness = if on then 3.5 else 2 })
		if on then
			SoundController.Play("UIClick")
		end
	end
	card.MouseEnter:Connect(function()
		hover(true)
	end)
	card.MouseLeave:Connect(function()
		hover(false)
	end)
	card.SelectionGained:Connect(function()
		hover(true)
	end)
	card.SelectionLost:Connect(function()
		hover(false)
	end)
	card.Activated:Connect(function()
		choose(info.id, play)
	end)
	play.Activated:Connect(function()
		choose(info.id, play)
	end)
	return card
end

function FactionSelectController.Show()
	if gui.Enabled then
		return
	end
	gui.Enabled = true
	startOrbit()
	-- Entrada em cascata dos cartões
	local row = gui:FindFirstChild("Row", true)
	if row then
		for i, card in row:GetChildren() do
			if card:IsA("TextButton") then
				local s = card:FindFirstChildOfClass("UIScale")
				if s then
					s.Scale = 0.6
					task.delay(i * 0.08, function()
						Kit.tween(s, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
					end)
				end
			end
		end
	end
end

function FactionSelectController.Hide()
	gui.Enabled = false
	stopOrbit()
end

function FactionSelectController.Init()
	gui = Kit.new(
		"ScreenGui",
		{
			Name = "FactionSelect",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 30,
			Enabled = false,
			Parent = player:WaitForChild("PlayerGui"),
		}
	)
	-- Fundo escurecido com vinheta
	Kit.new(
		"Frame",
		{
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			Size = UDim2.fromScale(1, 1),
			Parent = gui,
		},
		{
			Kit.new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.5, 0.5),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}),
		}
	)
	local content = Kit.new(
		"Frame",
		{
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromOffset(1140, 620),
			Parent = gui,
		}
	)
	Kit.label("ESCOLHA SEU CAMINHO", 54, {
		Size = UDim2.new(1, 0, 0, 58),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontAnime,
		Parent = content,
	}, { Kit.new("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = 3 }) })
	Kit.label("BLEACH — SOUL REBIRTH", 16, {
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.FontTitle,
		TextColor3 = T.Gold,
		Parent = content,
	})
	local row = Kit.new("ScrollingFrame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 500),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		BorderSizePixel = 0,
		Parent = content,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 20),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, info in CARDS do
		buildCard(row, info, i)
	end
	Kit.label(
		"Toque ou clique em um cartão para escolher. A facção define suas habilidades, transformações e mentor.",
		14,
		{
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = T.Muted,
			Parent = content,
		}
	)
	Kit.autoScale(gui)
end

function FactionSelectController.Start()
	DataController.Changed:Connect(function(profile)
		if profile and not profile.faction then
			FactionSelectController.Show()
		elseif gui.Enabled and profile and profile.faction then
			FactionSelectController.Hide()
		end
	end)
	if DataController.Profile and not DataController.Profile.faction then
		FactionSelectController.Show()
	end
	if UserInputService.GamepadEnabled then
		local first = gui:FindFirstChild("Shinigami", true)
		if first and first:IsA("GuiObject") then
			first.Selectable = true
		end
	end
end

return FactionSelectController

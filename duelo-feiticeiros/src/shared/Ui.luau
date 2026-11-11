-- INTERFACE da cinemática: barras de cinema, legendas com o nome de quem fala, nome das técnicas em letras
-- enormes, linhas de velocidade, clarão/escurecer, cartão final e os botões Pular / Assistir de novo.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Ui = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local gui: ScreenGui? = nil

local function tween(inst: Instance, time: number, goal, style: Enum.EasingStyle?)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function new(class: string, props, parent: Instance?)
	local i = Instance.new(class)
	for k, v in pairs(props) do
		(i :: any)[k] = v
	end
	i.Parent = parent
	return i
end

function Ui.mount()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("Cinematic")
	if old then
		old:Destroy()
	end
	local g = new("ScreenGui", { Name = "Cinematic", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100 }, pg) :: ScreenGui
	gui = g
	new("Frame", { Name = "BarTop", BackgroundColor3 = BLACK, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0.12, 0), ZIndex = 20 }, g)
	new("Frame", { Name = "BarBottom", BackgroundColor3 = BLACK, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0.12, 0), ZIndex = 20 }, g)
	new("Frame", { Name = "Fade", BackgroundColor3 = BLACK, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 30 }, g)
	new("Frame", { Name = "Flash", BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 29 }, g)
	-- legenda (na barra de baixo)
	local sub = new("TextLabel", { Name = "Subtitle", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.94),
		Size = UDim2.fromScale(0.8, 0.05), Font = Enum.Font.GothamBold, TextScaled = true, RichText = true, TextColor3 = WHITE, Text = "", ZIndex = 25,
		TextTransparency = 1 }, g)
	local _ = sub
	-- nome da técnica
	local card = new("TextLabel", { Name = "Technique", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.16), Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE, Text = "", ZIndex = 26, TextTransparency = 1 }, g)
	new("UIStroke", { Name = "Stroke", Thickness = 5, Color = BLACK, Transparency = 1 }, card)
	new("TextLabel", { Name = "TechniqueSub", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.61),
		Size = UDim2.fromScale(0.6, 0.05), Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = WHITE, Text = "", ZIndex = 26, TextTransparency = 1,
		TextStrokeTransparency = 1 }, g)
	-- linhas de velocidade (radiais, a partir do centro)
	local lines = new("Frame", { Name = "SpeedLines", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 15 }, g)
	for k = 1, 28 do
		local a = k / 28 * 360
		new("Frame", { Name = "Line", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.75, 0, 0, 2 + (k % 3) * 2),
			Rotation = a, BackgroundColor3 = WHITE, BackgroundTransparency = 0.35 + (k % 4) * 0.12, BorderSizePixel = 0, ZIndex = 15 }, lines)
	end
	-- botão pular
	new("TextButton", { Name = "Skip", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0.02, 0), Size = UDim2.fromOffset(120, 34), Text = "Pular ▸",
		Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = WHITE, BackgroundColor3 = Color3.fromRGB(30, 30, 40), BackgroundTransparency = 0.3, ZIndex = 40 }, g)
	return g
end

local function g(): ScreenGui
	return gui :: ScreenGui
end

function Ui.fadeIn(time: number)
	tween(g().Fade, time, { BackgroundTransparency = 1 })
end

function Ui.fadeOut(time: number)
	tween(g().Fade, time, { BackgroundTransparency = 0 })
end

function Ui.flash(time: number, color: Color3?)
	local f = g().Flash :: Frame
	f.BackgroundColor3 = color or WHITE
	f.BackgroundTransparency = 0
	tween(f, time, { BackgroundTransparency = 1 })
end

function Ui.subtitle(speaker: string?, color: Color3?, text: string, time: number)
	local s = g().Subtitle :: TextLabel
	if speaker then
		s.Text = string.format('<font color="#%s"><b>%s:</b></font> %s', (color or WHITE):ToHex(), speaker, text)
	else
		s.Text = text
	end
	s.TextTransparency = 0
	task.delay(time, function()
		if s.Text ~= "" then
			tween(s, 0.3, { TextTransparency = 1 })
		end
	end)
end

local CARD_SCALE = 0.16
function Ui.technique(text: string, sub: string, color: Color3, time: number)
	local c = g().Technique :: TextLabel
	local st = c:FindFirstChild("Stroke") :: UIStroke
	local s2 = g().TechniqueSub :: TextLabel
	c.Text, c.TextColor3 = text, WHITE
	st.Color = color
	s2.Text, s2.TextColor3 = sub, color
	c.Size = UDim2.fromScale(1.2, CARD_SCALE * 1.4)
	c.TextTransparency, st.Transparency = 0, 0
	s2.TextTransparency, s2.TextStrokeTransparency = 0, 0.3
	tween(c, 0.18, { Size = UDim2.fromScale(0.9, CARD_SCALE) }, Enum.EasingStyle.Back)
	task.delay(time, function()
		tween(c, 0.25, { TextTransparency = 1 })
		tween(st, 0.25, { Transparency = 1 })
		tween(s2, 0.25, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
end

function Ui.speedLines(on: boolean, color: Color3?)
	local f = g().SpeedLines :: Frame
	f.Visible = on
	for _, l in ipairs(f:GetChildren()) do
		if l:IsA("Frame") then
			l.BackgroundColor3 = color or WHITE
		end
	end
end

-- Cartão final + botão "Assistir de novo". Chama onReplay quando clicado.
function Ui.endCard(title: string, sub: string, onReplay: () -> ())
	local gg = g()
	new("TextLabel", { Name = "EndTitle", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.8, 0.12), Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE, Text = title, ZIndex = 35 }, gg)
	new("TextLabel", { Name = "EndSub", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.6, 0.045), Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Color3.fromRGB(200, 200, 215), Text = sub, ZIndex = 35 }, gg)
	local b = new("TextButton", { Name = "Replay", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromOffset(240, 52),
		Text = "▶ Assistir de novo", Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = WHITE, BackgroundColor3 = Color3.fromRGB(150, 30, 50), ZIndex = 35 }, gg) :: TextButton
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, b)
	b.Activated:Connect(onReplay)
end

function Ui.unmount()
	if gui then
		gui:Destroy()
		gui = nil
	end
end

function Ui.get(): ScreenGui?
	return gui
end

return Ui

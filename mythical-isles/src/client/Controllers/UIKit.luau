-- Kit de interface no estilo "simulador de pets": botões coloridos com volume (gradiente +
-- borda grossa + sombra), cartões com brilho, barras com gradiente, animações de clique/hover/pop
-- e escala responsiva (PC / tablet / celular). Tudo feito com objetos de UI (sem imagens externas).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Theme = {
	bg = Color3.fromRGB(34, 28, 72),
	bg2 = Color3.fromRGB(58, 44, 120),
	panel = Color3.fromRGB(46, 38, 96),
	panel2 = Color3.fromRGB(70, 92, 220),
	stroke = Color3.fromRGB(20, 14, 44),
	text = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(200, 196, 240),
	gold = Color3.fromRGB(255, 205, 60),
	essence = Color3.fromRGB(70, 230, 200),
	astral = Color3.fromRGB(175, 140, 255),
	good = Color3.fromRGB(90, 220, 110),
	bad = Color3.fromRGB(255, 80, 90),
	luck = Color3.fromRGB(120, 255, 140),
	-- cores de botão
	green = Color3.fromRGB(80, 210, 90),
	blue = Color3.fromRGB(60, 150, 255),
	orange = Color3.fromRGB(255, 150, 40),
	purple = Color3.fromRGB(170, 90, 255),
	pink = Color3.fromRGB(255, 90, 170),
	red = Color3.fromRGB(240, 70, 80),
	teal = Color3.fromRGB(40, 200, 200),
	yellow = Color3.fromRGB(255, 200, 40),
	gray = Color3.fromRGB(120, 120, 150),
	title = Enum.Font.FredokaOne,
	body = Enum.Font.GothamBold,
	bold = Enum.Font.GothamBlack,
}
local T = UIKit.Theme

function UIKit.isMobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function UIKit.new(className: string, props, children)
	local inst = Instance.new(className)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			(inst :: any)[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local new = UIKit.new

function UIKit.lighten(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), k)
end
function UIKit.darken(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), k)
end

function UIKit.corner(parent: Instance, r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12), Parent = parent })
end

function UIKit.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	return new("UIStroke", { Color = color or T.stroke, Thickness = thickness or 3, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round, Parent = parent })
end

-- Gradiente vertical (claro em cima, escuro embaixo) = aparência de "volume".
function UIKit.gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
	return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90, Parent = parent })
end

function UIKit.pad(parent: Instance, px: number)
	return new("UIPadding", { PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px), Parent = parent })
end

function UIKit.list(parent: Instance, dir: Enum.FillDirection?, spacing: number?, align: Enum.HorizontalAlignment?)
	return new("UIListLayout", { FillDirection = dir or Enum.FillDirection.Vertical, Padding = UDim.new(0, spacing or 6), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left, Parent = parent })
end

-- Sombra suave atrás de um elemento (irmão com deslocamento).
function UIKit.shadow(target: GuiObject, radius: number?, offset: number?)
	local parent = target.Parent
	if not parent then
		return nil
	end
	local s = new("Frame", {
		Name = target.Name .. "_Shadow", AnchorPoint = target.AnchorPoint, Position = target.Position + UDim2.fromOffset(0, offset or 5), Size = target.Size,
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = math.max(0, (target.ZIndex or 1) - 1),
		LayoutOrder = target.LayoutOrder, Visible = target.Visible, Parent = parent,
	})
	UIKit.corner(s, radius or 12)
	target:GetPropertyChangedSignal("Visible"):Connect(function()
		s.Visible = target.Visible
	end)
	return s
end

-- Cartão/painel: fundo com gradiente, borda escura grossa e brilho interno claro.
function UIKit.frame(props)
	local radius = props.radius
	props.radius = nil -- não é propriedade do Frame
	local base = props.BackgroundColor3 or T.panel
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	props.BorderSizePixel = 0
	local f = new("Frame", props)
	UIKit.corner(f, radius or 12)
	UIKit.gradient(f, UIKit.lighten(base, 0.12), UIKit.darken(base, 0.12))
	return f
end

-- Rótulo com contorno escuro (legível sobre qualquer fundo).
function UIKit.label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or T.text
	props.Font = props.Font or T.body
	props.TextSize = props.TextSize or 16
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextWrapped = props.TextWrapped ~= false
	props.TextStrokeColor3 = props.TextStrokeColor3 or T.stroke
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.55
	props.RichText = true
	return new("TextLabel", props)
end

-- Animação de "pop" (cresce e volta) em qualquer GuiObject.
function UIKit.pop(obj: GuiObject, amount: number?)
	local sc = obj:FindFirstChild("PopScale") :: UIScale?
	if not sc then
		sc = new("UIScale", { Name = "PopScale", Parent = obj })
	end
	local s = sc :: UIScale
	s.Scale = 1 + (amount or 0.18)
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Botão "doce": cor viva com gradiente, borda escura grossa, texto com contorno,
-- cresce no hover e afunda no clique.
function UIKit.button(props, onClick)
	local base = props.BackgroundColor3 or T.blue
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	props.TextColor3 = props.TextColor3 or T.text
	props.Font = props.Font or T.title
	props.TextSize = props.TextSize or 18
	props.TextStrokeColor3 = UIKit.darken(base, 0.6)
	props.TextStrokeTransparency = 0.2
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	props.RichText = true
	local b = new("TextButton", props)
	UIKit.corner(b, 12)
	local grad = UIKit.gradient(b, UIKit.lighten(base, 0.25), UIKit.darken(base, 0.15))
	UIKit.stroke(b, UIKit.darken(base, 0.55), 3, 0)
	-- faixa de brilho no topo
	local shine = new("Frame", { Name = "Shine", Size = UDim2.new(1, -10, 0.38, 0), Position = UDim2.fromOffset(5, 3), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = b.ZIndex or 1, Parent = b })
	UIKit.corner(shine, 9)
	local sc = new("UIScale", { Name = "PressScale", Parent = b })
	local function to(v)
		TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = v }):Play()
	end
	b.MouseEnter:Connect(function()
		to(1.05)
	end)
	b.MouseLeave:Connect(function()
		to(1)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.92)
	end)
	b.MouseButton1Up:Connect(function()
		to(1.05)
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	b:SetAttribute("BaseColor", base)
	local _ = grad
	return b
end

-- Muda a cor de um botão doce já criado.
function UIKit.recolor(b: TextButton, base: Color3)
	local g = b:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(UIKit.lighten(base, 0.25), UIKit.darken(base, 0.15))
	end
	local s = b:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = UIKit.darken(base, 0.55)
	end
	b.TextStrokeColor3 = UIKit.darken(base, 0.6)
end

-- Ícone circular (bolinha colorida com emoji/símbolo).
function UIKit.icon(parent: Instance, props)
	local c = props.color or T.gold
	local f = new("Frame", { Name = props.Name or "Icon", Position = props.Position, AnchorPoint = props.AnchorPoint, Size = props.Size or UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = props.ZIndex or 2, Parent = parent })
	UIKit.corner(f, 100)
	UIKit.gradient(f, UIKit.lighten(c, 0.35), UIKit.darken(c, 0.1))
	UIKit.stroke(f, UIKit.darken(c, 0.55), 3, 0)
	UIKit.label({ Size = UDim2.fromScale(1, 1), Text = props.Text or "", TextScaled = true, Font = T.title, TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3, TextStrokeColor3 = UIKit.darken(c, 0.6), ZIndex = (props.ZIndex or 2) + 1, Parent = f })
	return f
end

function UIKit.bar(parent: Instance, props)
	local back = new("Frame", { Name = props.Name or "Bar", Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = Color3.fromRGB(20, 16, 40), BorderSizePixel = 0, Parent = parent })
	UIKit.corner(back, props.radius or 8)
	UIKit.stroke(back, T.stroke, 2, 0)
	local c = props.color or T.good
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = back })
	UIKit.corner(fill, props.radius or 8)
	UIKit.gradient(fill, UIKit.lighten(c, 0.35), UIKit.darken(c, 0.1))
	local text = UIKit.label({ Name = "Text", Size = UDim2.fromScale(1, 1), Text = "", TextSize = props.textSize or 13, Font = T.title,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, ZIndex = 3, Parent = back })
	return back, fill, text
end

function UIKit.setBar(fill: Frame, frac: number, animate: boolean?)
	frac = math.clamp(frac, 0, 1)
	if animate then
		TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(frac, 1) }):Play()
	else
		fill.Size = UDim2.fromScale(frac, 1)
	end
	fill.Visible = frac > 0.005
end

function UIKit.scroll(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = props.ScrollBarThickness or 8
	props.ScrollBarImageColor3 = props.ScrollBarImageColor3 or T.gold
	props.AutomaticCanvasSize = props.AutomaticCanvasSize or Enum.AutomaticSize.Y
	props.CanvasSize = UDim2.new()
	props.ScrollingDirection = Enum.ScrollingDirection.Y
	local s = new("ScrollingFrame", props)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12), Parent = s })
	return s
end

-- Brilho que atravessa um elemento de tempos em tempos (selos, botões importantes).
function UIKit.shine(obj: GuiObject, period: number?)
	local sweep = new("Frame", { Name = "Sweep", Size = UDim2.new(0.25, 0, 1.6, 0), Position = UDim2.fromScale(-0.4, -0.3), Rotation = 20,
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = (obj.ZIndex or 1) + 1, Parent = obj })
	obj.ClipsDescendants = true
	task.spawn(function()
		while sweep.Parent do
			sweep.Position = UDim2.fromScale(-0.4, -0.3)
			TweenService:Create(sweep, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(1.2, -0.3) }):Play()
			task.wait(period or 3.5)
		end
	end)
	return sweep
end

function UIKit.fmt(n: number): string
	if n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

function UIKit.pct(p: number): string
	if p <= 0 then
		return "0%"
	elseif p < 0.0001 then
		return string.format("%.4f%%", p * 100)
	elseif p < 0.01 then
		return string.format("%.3f%%", p * 100)
	elseif p < 0.1 then
		return string.format("%.2f%%", p * 100)
	end
	return string.format("%.1f%%", p * 100)
end

function UIKit.time(sec: number): string
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then
		return string.format("%dh%02dm", sec // 3600, (sec % 3600) // 60)
	end
	return string.format("%d:%02d", sec // 60, sec % 60)
end

-- ScreenGui raiz com UIScale responsivo.
function UIKit.screen(name: string, order: number?)
	local gui = new("ScreenGui", { Name = name, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = order or 1,
		IgnoreGuiInset = false, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	local scale = new("UIScale", { Parent = gui })
	local function update()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local v = cam.ViewportSize
		local s = math.min(v.X / 1280, v.Y / 720)
		if UIKit.isMobile() then
			s = math.clamp(s * 1.15, 0.55, 1.1)
		else
			s = math.clamp(s, 0.65, 1.25)
		end
		scale.Scale = s
	end
	update()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	return gui
end

return UIKit

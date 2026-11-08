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
	speech = Enum.Font.PatrickHand,
	-- Design System (docs/UI_DESIGN_SYSTEM.md): pedra rúnica, madeira polida, cristal/neon
	scrim = Color3.fromRGB(10, 8, 22),
	panelDark = Color3.fromRGB(28, 24, 48),
	slot = Color3.fromRGB(42, 36, 72),
	inset = Color3.fromRGB(18, 15, 34),
	edgeDark = Color3.fromRGB(11, 9, 20),
	edgeLight = Color3.fromRGB(108, 98, 168),
	stoneTop = Color3.fromRGB(74, 69, 96),
	stoneBot = Color3.fromRGB(34, 30, 48),
	woodTop = Color3.fromRGB(150, 98, 54),
	woodBot = Color3.fromRGB(90, 56, 32),
	woodEdge = Color3.fromRGB(42, 26, 16),
	confirm = Color3.fromRGB(46, 204, 113),
	cancel = Color3.fromRGB(229, 72, 77),
	info = Color3.fromRGB(59, 169, 255),
	energy = Color3.fromRGB(90, 200, 255),
	fury = Color3.fromRGB(255, 196, 80),
	hp = Color3.fromRGB(61, 220, 106),
	xp = Color3.fromRGB(177, 140, 255),
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
	-- três tons: topo claro, meio na cor, base escura (aparência de botão de jogo com volume)
	local grad = new("UIGradient", { Rotation = 90, Parent = b, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UIKit.lighten(base, 0.32)), ColorSequenceKeypoint.new(0.55, base), ColorSequenceKeypoint.new(1, UIKit.darken(base, 0.22)) }) })
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
	b.Activated:Connect(function()
		UIKit.burst(b, UIKit.lighten(base, 0.45))
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
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, UIKit.lighten(base, 0.32)), ColorSequenceKeypoint.new(0.55, base), ColorSequenceKeypoint.new(1, UIKit.darken(base, 0.22)) })
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

-------------------------------------------------------------------------------
-- DESIGN SYSTEM (docs/UI_DESIGN_SYSTEM.md): componentes da interface nova
-------------------------------------------------------------------------------

local RunService = game:GetService("RunService")

-- Um único laço de animação para toda a UI (30 quadros/s): gradientes girando, seiva fluindo,
-- pulsos. Cada entrada some sozinha quando o objeto sai da tela (Parent nil).
local anims: { { obj: Instance, fn: (number) -> () } } = {}
local animClock = 0
local animStarted = false
function UIKit.animate(obj: Instance, fn: (number) -> ())
	table.insert(anims, { obj = obj, fn = fn })
	if animStarted then
		return
	end
	animStarted = true
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		animClock += dt
		acc += dt
		if acc < 1 / 30 then
			return
		end
		acc = 0
		for i = #anims, 1, -1 do
			local a = anims[i]
			if not a.obj.Parent then
				table.remove(anims, i)
			else
				a.fn(animClock)
			end
		end
	end)
end
UIKit._anims = anims

-- Acento do mundo em que o jogador está (o tema da UI acompanha o mundo).
function UIKit.worldAccent(): Color3
	local ok, Worlds = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Worlds)
	end)
	local w = Players.LocalPlayer and Players.LocalPlayer:GetAttribute("World") or "verdant"
	local info = ok and Worlds.Info[w]
	return info and info.palette.accent or Color3.fromRGB(124, 230, 90)
end

-- Partículas de UI: losangos que saem do centro de um objeto (clique, ganho, desbloqueio).
function UIKit.burst(obj: GuiObject, color: Color3?, count: number?)
	local gui = obj:FindFirstAncestorWhichIsA("ScreenGui")
	if not gui then
		return
	end
	local layer = gui:FindFirstChild("BurstLayer") :: Frame?
	if not layer then
		layer = new("Frame", { Name = "BurstLayer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 50, Parent = gui })
	end
	local ap, as = obj.AbsolutePosition, obj.AbsoluteSize
	if not ap or not as then
		return
	end
	local scale = gui:FindFirstChildOfClass("UIScale")
	local k = scale and scale.Scale or 1
	local cx, cy = (ap.X + as.X / 2) / k, (ap.Y + as.Y / 2) / k
	local n = count or 7
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + math.random() * 0.5
		local d = 34 + math.random() * 40
		local sz = 5 + math.random() * 4
		local p = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(sz, sz), Rotation = 45,
			BackgroundColor3 = color or Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 51, Parent = layer })
		TweenService:Create(p, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(cx + math.cos(a) * d, cy + math.sin(a) * d), Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, Rotation = 45 + 180 }):Play()
		task.delay(0.4, function()
			p:Destroy()
		end)
	end
end

-- MOLDURA RÚNICA: sombra + corpo de pedra com gradiente + contorno escuro + friso de relevo +
-- runas de cristal nos cantos (+ brilho opcional). Devolve (raiz, corpo): o conteúdo vai no corpo;
-- anime a raiz (UIScale "OpenScale") para abrir/fechar.
function UIKit.runeFrame(props)
	local accent = props.accent or UIKit.worldAccent()
	local radius = props.radius or 18
	local root = new("Frame", { Name = props.Name or "RuneFrame", AnchorPoint = props.AnchorPoint, Position = props.Position, Size = props.Size, BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder, Visible = props.Visible ~= false, ZIndex = props.ZIndex, Parent = props.Parent })
	local shadow = new("Frame", { Name = "Shadow", Position = UDim2.fromOffset(0, 7), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = root })
	UIKit.corner(shadow, radius)
	local body = new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = props.transparency or 0.06,
		BorderSizePixel = 0, Parent = root })
	UIKit.corner(body, radius)
	new("UIGradient", { Rotation = 90, Parent = body, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, props.top or T.stoneTop), ColorSequenceKeypoint.new(0.18, props.mid or T.panelDark), ColorSequenceKeypoint.new(1, props.bottom or T.stoneBot) }) })
	UIKit.stroke(body, T.edgeDark, props.stroke or 4, 0)
	-- friso de relevo (claro em cima, some embaixo)
	local bevel = new("Frame", { Name = "Bevel", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, Parent = root })
	UIKit.corner(bevel, math.max(4, radius - 3))
	local bs = UIKit.stroke(bevel, T.edgeLight, 1.5, 0.2)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.7), NumberSequenceKeypoint.new(1, 1) }), Parent = bs })
	-- runas de cristal nos cantos
	if props.runes ~= false then
		for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
			local gem = new("Frame", { Name = "CornerRune", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(c[1], c[1] == 0 and 10 or -10, c[2], c[2] == 0 and 10 or -10),
				Size = UDim2.fromOffset(12, 12), Rotation = 45, BackgroundColor3 = accent, BorderSizePixel = 0, Parent = root })
			UIKit.stroke(gem, T.edgeDark, 2, 0)
			new("UIGradient", { Rotation = 45, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.6, 0.6, 0.6)), Parent = gem })
		end
	end
	if props.glow then
		local g = new("Frame", { Name = "Glow", Position = UDim2.fromOffset(-4, -4), Size = UDim2.new(1, 8, 1, 8), BackgroundTransparency = 1, Parent = root })
		UIKit.corner(g, radius + 4)
		local gs = UIKit.stroke(g, accent, 4, 0.55)
		UIKit.animate(g, function(t)
			gs.Transparency = 0.5 + math.sin(t * 2.2) * 0.2
		end)
	end
	new("UIScale", { Name = "OpenScale", Parent = root })
	return root, body
end

-- PLACA DE MADEIRA POLIDA (títulos de janela, nome de NPC, mundo atual).
function UIKit.woodPlaque(props)
	local f = new("Frame", { Name = props.Name or "Plaque", AnchorPoint = props.AnchorPoint, Position = props.Position, Size = props.Size, BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = props.ZIndex, LayoutOrder = props.LayoutOrder, Parent = props.Parent })
	UIKit.corner(f, props.radius or 14)
	new("UIGradient", { Rotation = 90, Parent = f, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UIKit.lighten(T.woodTop, 0.15)), ColorSequenceKeypoint.new(0.5, T.woodTop), ColorSequenceKeypoint.new(1, T.woodBot) }) })
	UIKit.stroke(f, T.woodEdge, 3, 0)
	-- veios da madeira
	for i, y in ipairs({ 0.32, 0.58, 0.8 }) do
		new("Frame", { Name = "Grain", Position = UDim2.new(0.06 + i * 0.03, 0, y, 0), Size = UDim2.new(0.8 - i * 0.12, 0, 0, 2), BackgroundColor3 = T.woodEdge,
			BackgroundTransparency = 0.82, BorderSizePixel = 0, Parent = f })
	end
	-- pregos
	for _, x in ipairs(props.nails == false and {} or { 0, 1 }) do
		local nail = new("Frame", { Name = "Nail", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, x == 0 and 12 or -12, 0.5, 0), Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = Color3.fromRGB(214, 176, 104), BorderSizePixel = 0, Parent = f })
		UIKit.corner(nail, 4)
		UIKit.stroke(nail, T.woodEdge, 1.5, 0)
	end
	local inset = props.nails == false and 4 or 20
	local label = UIKit.label({ Name = "Title", Position = UDim2.fromOffset(inset, 0), Size = UDim2.new(1, -inset * 2, 1, 0), Text = props.Text or "", Font = T.title, TextSize = props.TextSize or 26,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(255, 244, 222), TextStrokeColor3 = T.woodEdge, TextStrokeTransparency = 0, Parent = f })
	return f, label
end

-- BARRA "RECIPIENTE" com seiva/energia fluindo (vida, XP, energia, Fúria).
-- Devolve { root, fill, text, set(frac, text) }.
function UIKit.vesselBar(props)
	local c = props.color or T.hp
	local root = new("Frame", { Name = props.Name or "Vessel", Position = props.Position, Size = props.Size, AnchorPoint = props.AnchorPoint, BackgroundColor3 = T.inset,
		BorderSizePixel = 0, LayoutOrder = props.LayoutOrder, Parent = props.Parent })
	UIKit.corner(root, 100)
	UIKit.stroke(root, T.edgeDark, 3, 0)
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ClipsDescendants = true, Parent = root })
	UIKit.corner(fill, 100)
	new("UIGradient", { Rotation = 90, Parent = fill, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UIKit.lighten(c, 0.45)), ColorSequenceKeypoint.new(0.45, c), ColorSequenceKeypoint.new(1, UIKit.darken(c, 0.35)) }) })
	-- faixa de luz que corre por dentro (a seiva "flui")
	local flow = new("Frame", { Name = "Flow", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, BorderSizePixel = 0, Parent = fill })
	UIKit.corner(flow, 100)
	local fg = new("UIGradient", { Parent = flow, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) }) })
	-- bolhas subindo
	local bubbles = {}
	for i = 1, 4 do
		local b = new("Frame", { Name = "Bubble", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(i / 5, 0.7), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = fill })
		UIKit.corner(b, 2)
		bubbles[i] = b
	end
	-- vidro do recipiente
	local glass = new("Frame", { Name = "Glass", Position = UDim2.fromScale(0.03, 0.08), Size = UDim2.fromScale(0.94, 0.38), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 2, Parent = root })
	UIKit.corner(glass, 100)
	local text = UIKit.label({ Name = "Text", Size = UDim2.fromScale(1, 1), Text = "", Font = T.title, TextSize = props.textSize or 14, TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0, TextStrokeColor3 = T.edgeDark, ZIndex = 3, Parent = root })
	local seed = math.random() * 10
	UIKit.animate(root, function(t)
		local x = ((t + seed) * 0.6) % 1
		fg.Offset = Vector2.new(x * 2 - 1, 0)
		for i, b in ipairs(bubbles) do
			local f = ((t + seed) * 0.5 + i * 0.27) % 1
			b.Position = UDim2.fromScale((i / 5 + f * 0.08) % 1, 0.85 - f * 0.7)
			b.BackgroundTransparency = 0.35 + f * 0.6
		end
	end)
	local bar = { root = root, fill = fill, text = text, value = nil }
	function bar.set(frac: number, label: string?)
		frac = math.clamp(frac, 0, 1)
		if bar.value and frac < bar.value - 0.01 then
			-- dano "fantasma": a parte perdida pisca em branco antes de sumir
			local ghost = new("Frame", { Name = "Ghost", Position = UDim2.fromScale(frac, 0), Size = UDim2.fromScale(bar.value - frac, 1), BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0, ZIndex = 2, Parent = root })
			UIKit.corner(ghost, 100)
			TweenService:Create(ghost, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 1 }):Play()
			task.delay(0.5, function()
				ghost:Destroy()
			end)
		end
		bar.value = frac
		TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.max(frac, 0.0001), 1) }):Play()
		fill.Visible = frac > 0.005
		if label then
			text.Text = label
		end
	end
	return bar
end

-- BOTÃO HEXÁGONO RÚNICO (menu lateral): hexágono de pedra com friso do acento, ícone grande,
-- rótulo de madeira que desliza no hover e distintivo de aviso.
function UIKit.hexButton(props, onClick)
	local size = props.size or 72
	local accent = props.color or UIKit.worldAccent()
	local b = new("TextButton", { Name = props.Name or "Hex", LayoutOrder = props.LayoutOrder, Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, Parent = props.Parent })
	local holder = new("Frame", { Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = b })
	local sc = new("UIScale", { Parent = holder })
	-- hexágono = três retângulos arredondados girados 0/60/120 (camada escura atrás = contorno)
	local function hexLayer(name: string, inset: number, color: Color3, grad: boolean)
		local layer = new("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -inset, 1, -inset), BackgroundTransparency = 1, Parent = holder })
		for k = 0, 2 do
			local r = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.58, 1), Rotation = k * 60,
				BackgroundColor3 = color, BorderSizePixel = 0, Parent = layer })
			UIKit.corner(r, 6)
			if grad then
				new("UIGradient", { Rotation = 90 - k * 60, Parent = r, Color = ColorSequence.new(UIKit.lighten(color, 0.35), UIKit.darken(color, 0.25)) })
			end
		end
		return layer
	end
	hexLayer("Edge", 0, T.edgeDark, false)
	local rim = hexLayer("Rim", 6, accent, true)
	local face = hexLayer("Face", 12, props.face or T.stoneTop, true)
	local icon = UIKit.label({ Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromScale(0.62, 0.62), Text = props.icon or "?",
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Parent = holder })
	-- placa de madeira com o nome, sempre visível (no celular não existe hover)
	local label = UIKit.woodPlaque({ Name = "Label", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.fromOffset(size + 6, 22), Text = props.label or "",
		TextSize = 14, radius = 8, nails = false, Parent = b })
	local glow = new("Frame", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 14, 1, 14), BackgroundTransparency = 1, Parent = holder })
	UIKit.corner(glow, 100)
	local gs = UIKit.stroke(glow, accent, 6, 1)
	local dot = UIKit.icon(b, { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 8), Size = UDim2.fromOffset(22, 22), color = T.red, Text = "!", ZIndex = 6 })
	dot.Visible = false
	local function to(scale: number, rot: number)
		TweenService:Create(sc, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = scale }):Play()
		TweenService:Create(holder, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = rot }):Play()
	end
	b.MouseEnter:Connect(function()
		to(1.12, 6)
		TweenService:Create(gs, TweenInfo.new(0.15), { Transparency = 0.45 }):Play()
	end)
	b.MouseLeave:Connect(function()
		to(1, 0)
		TweenService:Create(gs, TweenInfo.new(0.15), { Transparency = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		to(0.94, 0)
	end)
	b.MouseButton1Up:Connect(function()
		to(1.08, 4)
	end)
	b.Activated:Connect(function()
		UIKit.burst(b, accent)
		if onClick then
			onClick()
		end
	end)
	-- distintivo pulsando quando visível
	local dsc = new("UIScale", { Parent = dot })
	UIKit.animate(dot, function(t)
		if dot.Visible then
			local ph = (t % 1.2) / 1.2
			dsc.Scale = ph < 0.3 and 1 + math.sin(ph / 0.3 * math.pi) * 0.18 or 1
		end
	end)
	return b, dot, { rim = rim, face = face, icon = icon, label = label, glow = gs }
end

-- CONTADOR DE MOEDA: pílula escura + moeda de cristal sobreposta + número que conta + botão "+".
-- Devolve { root, set(value) }.
function UIKit.counter(props)
	local c = props.color or T.gold
	local root = new("Frame", { Name = props.Name or "Counter", LayoutOrder = props.LayoutOrder, Size = props.Size or UDim2.fromOffset(176, 46), BackgroundTransparency = 1, Parent = props.Parent })
	local pill = new("Frame", { Name = "Pill", Position = UDim2.fromOffset(18, 5), Size = UDim2.new(1, -18, 1, -10), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.05,
		BorderSizePixel = 0, Parent = root })
	UIKit.corner(pill, 100)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(T.stoneTop, T.stoneBot), Parent = pill })
	UIKit.stroke(pill, T.edgeDark, 3, 0)
	local coin = new("Frame", { Name = "Coin", Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = root })
	UIKit.corner(coin, 100)
	local cg = new("UIGradient", { Rotation = 45, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, UIKit.lighten(c, 0.55)), ColorSequenceKeypoint.new(0.5, c),
		ColorSequenceKeypoint.new(1, UIKit.darken(c, 0.4)) }), Parent = coin })
	UIKit.stroke(coin, UIKit.darken(c, 0.65), 3, 0)
	UIKit.label({ Name = "Glyph", Size = UDim2.fromScale(1, 1), Text = props.icon or "●", TextScaled = true, Font = T.title, TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.new(1, 1, 1), TextStrokeColor3 = UIKit.darken(c, 0.7), TextStrokeTransparency = 0, ZIndex = 4, Parent = coin })
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = coin:FindFirstChild("Glyph") })
	local amount = UIKit.label({ Name = "Amount", Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, props.plus and -66 or -40, 1, 0), Text = "0", Font = T.title, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right, TextStrokeColor3 = T.edgeDark, TextStrokeTransparency = 0, Parent = pill })
	if props.plus then
		local plus = UIKit.button({ Name = "Plus", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(28, 28), Text = "+", TextSize = 20,
			BackgroundColor3 = T.confirm, Parent = pill }, props.plus)
		UIKit.corner(plus, 14)
	end
	-- brilho que gira devagar na moeda
	UIKit.animate(coin, function(t)
		cg.Rotation = 45 + math.sin(t * 1.3) * 25
	end)
	local counter = { root = root, value = nil :: number?, shown = 0 }
	local nv = new("NumberValue", { Parent = root })
	nv.Changed:Connect(function(v)
		amount.Text = UIKit.fmt(v)
	end)
	function counter.set(v: number)
		if counter.value ~= nil and v > counter.value then
			TweenService:Create(nv, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Value = v }):Play()
			UIKit.pop(coin, 0.25)
			local gain = UIKit.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.6, 0, 0.5, 0), Size = UDim2.fromOffset(140, 26), Text = "+" .. UIKit.fmt(v - counter.value),
				Font = T.title, TextSize = 22, TextColor3 = UIKit.lighten(c, 0.2), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0, TextStrokeColor3 = T.edgeDark,
				ZIndex = 10, Parent = root })
			TweenService:Create(gain, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Position = UDim2.new(0.6, 0, 1.9, 0), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.delay(0.95, function()
				gain:Destroy()
			end)
			if v - counter.value >= math.max(10, counter.value * 0.1) then
				UIKit.burst(coin, c, 10)
			end
		else
			nv.Value = v
			amount.Text = UIKit.fmt(v)
		end
		counter.value = v
	end
	return counter
end

-- Gradiente de raridade com brilho girando (Épico+), para slots e faixas.
function UIKit.rarityFill(obj: GuiObject, color: Color3, rank: number, accent: Color3?)
	local g = new("UIGradient", { Name = "RarityGradient", Rotation = 90, Parent = obj, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UIKit.lighten(color, 0.35)), ColorSequenceKeypoint.new(0.5, color), ColorSequenceKeypoint.new(1, UIKit.darken(color, 0.4)) }) })
	if rank >= 4 then
		local hi = accent or UIKit.lighten(color, 0.6)
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, UIKit.darken(color, 0.25)), ColorSequenceKeypoint.new(0.45, color), ColorSequenceKeypoint.new(0.5, hi),
			ColorSequenceKeypoint.new(0.55, color), ColorSequenceKeypoint.new(1, UIKit.darken(color, 0.35)) })
		local speed = rank >= 6 and 60 or rank >= 5 and 40 or 22
		UIKit.animate(obj, function(t)
			g.Rotation = (t * speed) % 360
		end)
	end
	return g
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

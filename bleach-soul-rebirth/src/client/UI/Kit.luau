-- Kit de UI: tema visual (estética de anime/tinta), construtor de instâncias e componentes.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Kit = {}

Kit.Theme = {
	Background = Color3.fromRGB(10, 10, 16),
	Panel = Color3.fromRGB(16, 16, 24),
	PanelLight = Color3.fromRGB(28, 28, 40),
	Text = Color3.fromRGB(240, 240, 246),
	Muted = Color3.fromRGB(150, 152, 170),
	Accent = Color3.fromRGB(120, 190, 255),
	Gold = Color3.fromRGB(255, 205, 90),
	Danger = Color3.fromRGB(235, 60, 70),
	Health = Color3.fromRGB(80, 220, 100),
	Success = Color3.fromRGB(110, 230, 150),
	-- identidade Soul Rebirth: tinta preta, carmesim de destaque, linhas finas claras
	Ink = Color3.fromRGB(8, 8, 12),
	Crimson = Color3.fromRGB(214, 38, 58),
	Bone = Color3.fromRGB(236, 230, 214),
	FontTitle = Enum.Font.GothamBlack,
	FontBold = Enum.Font.GothamBold,
	Font = Enum.Font.GothamMedium,
	FontAnime = Enum.Font.Bangers,
}

-- Kit.new("Frame", { props }, { filhos })
function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	for key, value in (props or {}) :: any do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in (children or {}) :: any do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Kit.corner(radius: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Kit.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or Color3.fromRGB(255, 255, 255),
		Thickness = thickness or 1,
		Transparency = transparency or 0.75,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return Kit.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Kit.tween(
	instance: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

function Kit.label(text: string, size: number, props: { [string]: any }?, children: { Instance }?): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		Font = Kit.Theme.FontBold,
		TextColor3 = Kit.Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in (props or {}) :: any do
		base[k] = v
	end
	return Kit.new("TextLabel", base, children)
end

-- Barra com preenchimento suave, "rastro" de dano, brilho no topo e marcações a cada 10%.
-- `textRight`: valor alinhado à direita dentro da barra (vida, Reiatsu).
function Kit.bar(props: { [string]: any }, color: Color3, height: number, textRight: boolean?)
	local radius = math.max(2, height // 2)
	local frame = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(14, 14, 20),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
	}, { Kit.corner(radius), Kit.stroke(Color3.new(0, 0, 0), 1.5, 0.2) })
	for k, v in props do
		(frame :: any)[k] = v
	end
	local trail = Kit.new("Frame", {
		Name = "Trail",
		BackgroundColor3 = Color3.fromRGB(255, 236, 214),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	}, { Kit.corner(radius) })
	local fill = Kit.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	}, {
		Kit.corner(radius),
		Kit.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.45, Color3.fromRGB(235, 235, 235)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)),
			}),
			Rotation = 90,
		}),
	})
	if height >= 8 then
		-- brilho fino no topo do preenchimento
		Kit.new("Frame", {
			Name = "Shine",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Position = UDim2.new(0, radius, 0, 1),
			Size = UDim2.new(1, -radius * 2, 0, math.max(1, height // 6)),
			ZIndex = 2,
			Parent = fill,
		})
	end
	if height >= 12 then
		for i = 1, 9 do
			Kit.new("Frame", {
				Name = "Tick",
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Position = UDim2.new(i / 10, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(0, 1, 0.55, 0),
				ZIndex = 3,
				Parent = frame,
			})
		end
	end
	local label = Kit.label("", math.max(10, height - 5), {
		Position = UDim2.fromOffset(if textRight then 0 else 0, 0),
		Size = UDim2.new(1, if textRight then -8 else 0, 1, 0),
		TextXAlignment = if textRight then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.35,
		ZIndex = 4,
		Parent = frame,
	})
	local api = { frame = frame, fill = fill, label = label, last = 1 }
	function api.set(value: number, max: number, text: string?)
		local ratio = if max > 0 then math.clamp(value / max, 0, 1) else 0
		if math.abs(ratio - api.last) < 0.001 and label.Text == (text or "") then
			return
		end
		Kit.tween(fill, 0.15, { Size = UDim2.fromScale(ratio, 1) })
		if ratio < api.last then
			task.delay(0.35, function()
				Kit.tween(trail, 0.4, { Size = UDim2.fromScale(ratio, 1) })
			end)
		else
			trail.Size = UDim2.fromScale(ratio, 1)
		end
		api.last = ratio
		label.Text = text or ""
	end
	function api.color(c: Color3)
		fill.BackgroundColor3 = c
	end
	return api
end

-- 12850 → "12.850" (separador de milhar como no Brasil)
function Kit.number(n: number): string
	local text = tostring(math.floor(n))
	local sign, digits = text:match("^(-?)(%d+)$")
	if not digits then
		return text
	end
	return sign .. digits:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
end

-- Tecla (keycap): pílula escura com o atalho
function Kit.keycap(text: string, props: { [string]: any }?): TextLabel
	local base = {
		BackgroundColor3 = Color3.fromRGB(4, 4, 6),
		BackgroundTransparency = 0.05,
		Text = text,
		TextSize = 10,
		Font = Kit.Theme.FontTitle,
		TextColor3 = Kit.Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(18, 14),
	}
	for k, v in (props or {}) :: any do
		base[k] = v
	end
	return Kit.new("TextLabel", base, { Kit.corner(4), Kit.stroke(Color3.new(1, 1, 1), 1, 0.7) })
end

-- Pílula com texto (tags de forma, nível, carteira)
function Kit.pill(text: string, color: Color3, props: { [string]: any }?): TextLabel
	local base = {
		BackgroundColor3 = Kit.Theme.Ink,
		BackgroundTransparency = 0.2,
		Text = text,
		TextSize = 12,
		Font = Kit.Theme.FontTitle,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(60, 18),
	}
	for k, v in (props or {}) :: any do
		base[k] = v
	end
	return Kit.new(
		"TextLabel",
		base,
		{ Kit.new("UICorner", { CornerRadius = UDim.new(1, 0) }), Kit.stroke(color, 1, 0.55) }
	)
end

function Kit.button(text: string, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local base = {
		BackgroundColor3 = Kit.Theme.PanelLight,
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = text,
		TextSize = 16,
		Font = Kit.Theme.FontBold,
		TextColor3 = Kit.Theme.Text,
		Size = UDim2.fromOffset(160, 40),
	}
	for k, v in (props or {}) :: any do
		base[k] = v
	end
	local button = Kit.new("TextButton", base, { Kit.corner(8), Kit.stroke(Kit.Theme.Accent, 1.2, 0.6) })
	local normal = button.BackgroundColor3
	button.MouseEnter:Connect(function()
		Kit.tween(button, 0.12, { BackgroundColor3 = normal:Lerp(Color3.new(1, 1, 1), 0.12) })
	end)
	button.MouseLeave:Connect(function()
		Kit.tween(button, 0.12, { BackgroundColor3 = normal })
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function Kit.panel(props: { [string]: any }?): Frame
	-- painel de tinta: fundo quase preto, borda fina clara, leve degradê e filete carmesim no topo
	local base = {
		BackgroundColor3 = Color3.fromRGB(12, 12, 18),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
	}
	for k, v in (props or {}) :: any do
		base[k] = v
	end
	return Kit.new("Frame", base, {
		Kit.corner(12),
		Kit.stroke(Color3.new(1, 1, 1), 1, 0.86),
		Kit.new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 195)),
			Rotation = 90,
		}),
		Kit.new("Frame", {
			Name = "Accent",
			BackgroundColor3 = Kit.Theme.Crimson,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(24, 0),
			Size = UDim2.new(0.3, 0, 0, 2),
			ZIndex = 2,
		}),
	})
end

-- Escala global para telas pequenas (celular) e grandes.
function Kit.autoScale(gui: ScreenGui)
	local scale = Kit.new("UIScale", { Parent = gui })
	local function update()
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
		-- celular: piso maior para o texto não ficar ilegível (a tela é pequena mas fica perto do rosto)
		local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), if touchOnly then 0.72 else 0.55, 1.4)
	end
	update()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	return scale
end

return Kit

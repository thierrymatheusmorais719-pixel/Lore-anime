-- Kit de interface: tema, componentes e escala responsiva (PC / tablet / celular).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Theme = {
	bg = Color3.fromRGB(18, 20, 32),
	panel = Color3.fromRGB(28, 31, 48),
	panel2 = Color3.fromRGB(38, 42, 64),
	stroke = Color3.fromRGB(90, 96, 140),
	text = Color3.fromRGB(240, 242, 255),
	muted = Color3.fromRGB(170, 176, 205),
	gold = Color3.fromRGB(255, 210, 80),
	essence = Color3.fromRGB(110, 235, 205),
	astral = Color3.fromRGB(175, 155, 255),
	good = Color3.fromRGB(110, 230, 140),
	bad = Color3.fromRGB(255, 100, 100),
	luck = Color3.fromRGB(120, 255, 150),
	title = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
}

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

function UIKit.corner(parent: Instance, r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 10), Parent = parent })
end

function UIKit.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	return new("UIStroke", { Color = color or UIKit.Theme.stroke, Thickness = thickness or 1.5, Transparency = transparency or 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

function UIKit.pad(parent: Instance, px: number)
	return new("UIPadding", { PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px), Parent = parent })
end

function UIKit.list(parent: Instance, dir: Enum.FillDirection?, spacing: number?, align: Enum.HorizontalAlignment?)
	return new("UIListLayout", { FillDirection = dir or Enum.FillDirection.Vertical, Padding = UDim.new(0, spacing or 6), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left, Parent = parent })
end

function UIKit.frame(props)
	local radius = props.radius
	props.radius = nil -- não é propriedade do Frame
	props.BackgroundColor3 = props.BackgroundColor3 or UIKit.Theme.panel
	props.BorderSizePixel = 0
	local f = new("Frame", props)
	UIKit.corner(f, radius)
	return f
end

function UIKit.label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or UIKit.Theme.text
	props.Font = props.Font or UIKit.Theme.body
	props.TextSize = props.TextSize or 16
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextWrapped = props.TextWrapped ~= false
	props.RichText = true
	return new("TextLabel", props)
end

function UIKit.button(props, onClick)
	props.BackgroundColor3 = props.BackgroundColor3 or UIKit.Theme.panel2
	props.TextColor3 = props.TextColor3 or UIKit.Theme.text
	props.Font = props.Font or UIKit.Theme.bold
	props.TextSize = props.TextSize or 16
	props.AutoButtonColor = true
	props.BorderSizePixel = 0
	props.RichText = true
	local b = new("TextButton", props)
	UIKit.corner(b, 8)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

function UIKit.bar(parent: Instance, props)
	local back = UIKit.frame({ Name = props.Name or "Bar", Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, BackgroundColor3 = Color3.fromRGB(20, 20, 26),
		BackgroundTransparency = 0.2, radius = props.radius or 6, Parent = parent })
	local fill = UIKit.frame({ Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = props.color or UIKit.Theme.good, radius = props.radius or 6, Parent = back })
	local text = UIKit.label({ Name = "Text", Size = UDim2.fromScale(1, 1), Text = "", TextSize = props.textSize or 13, Font = UIKit.Theme.bold,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5, ZIndex = 3, Parent = back })
	return back, fill, text
end

function UIKit.setBar(fill: Frame, frac: number, animate: boolean?)
	frac = math.clamp(frac, 0, 1)
	if animate then
		TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(frac, 1) }):Play()
	else
		fill.Size = UDim2.fromScale(frac, 1)
	end
end

function UIKit.scroll(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = props.ScrollBarThickness or 6
	props.AutomaticCanvasSize = props.AutomaticCanvasSize or Enum.AutomaticSize.Y
	props.CanvasSize = UDim2.new()
	props.ScrollingDirection = Enum.ScrollingDirection.Y
	return new("ScrollingFrame", props)
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

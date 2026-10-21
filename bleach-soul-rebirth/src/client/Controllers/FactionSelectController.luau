-- Tela de seleção de facção (primeira entrada), com câmera orbitando a praça de Karakura.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Factions = require(Shared.Config.Factions)
local Powers = require(Shared.Config.Powers)
local Abilities = require(Shared.Config.Abilities)

local Kit = require(script.Parent.Parent.UI.Kit)
local DataController = require(script.Parent.DataController)
local SoundController = require(script.Parent.SoundController)

local FactionSelectController = {}

local T = Kit.Theme
local player = Players.LocalPlayer
local gui: ScreenGui
local orbit: RBXScriptConnection? = nil
local busy = false

local function startOrbit()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	orbit = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - start) * 0.06
		local center = Vector3.new(0, 8, 0)
		camera.CFrame = CFrame.lookAt(center + Vector3.new(math.cos(a) * 70, 28, math.sin(a) * 70), center)
	end)
end

local function stopOrbit()
	if orbit then
		orbit:Disconnect()
		orbit = nil
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

local function card(parent: Instance, factionId: string, order: number)
	local faction = Factions[factionId]
	local starter = Powers.List[Powers.Starter[factionId]]
	local frame = Kit.panel({ Size = UDim2.fromOffset(250, 400), LayoutOrder = order, Parent = parent })
	local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = faction.color
	stroke.Transparency = 0.5
	Kit.label(faction.kanji, 54, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 64), TextXAlignment = Enum.TextXAlignment.Center, Font = T.FontTitle, TextColor3 = faction.color, Parent = frame })
	Kit.label(faction.displayName, 24, { Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, Font = T.FontTitle, Parent = frame })
	Kit.label(faction.description, 15, { Position = UDim2.fromOffset(18, 124), Size = UDim2.new(1, -36, 0, 70), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = T.Muted, Font = T.Font, Parent = frame })
	local lines = {}
	for _, slot in { "Z", "X", "C" } do
		local def = Abilities[faction.base[slot]]
		table.insert(lines, slot .. "  " .. def.name)
	end
	table.insert(lines, "G  " .. faction.forms.Tier1.name .. " → " .. faction.forms.Tier2.name)
	if faction.maskAvailable then
		table.insert(lines, "H  Máscara Hollow")
	end
	Kit.label(table.concat(lines, "\n"), 14, { Position = UDim2.fromOffset(18, 200), Size = UDim2.new(1, -36, 0, 110), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = T.FontBold, Parent = frame })
	Kit.label("Poder inicial: " .. starter.name, 13, { Position = UDim2.fromOffset(18, 312), Size = UDim2.new(1, -36, 0, 18), TextColor3 = T.Gold, Parent = frame })
	local button = Kit.button("ESCOLHER", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(1, -36, 0, 42), BackgroundColor3 = faction.color:Lerp(Color3.new(0, 0, 0), 0.55) })
	button.Parent = frame
	button.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		SoundController.Play("Draw")
		button.Text = "..."
		local ok, err = DataController.Request("ChooseFaction", { faction = factionId })
		busy = false
		if ok then
			FactionSelectController.Hide()
		else
			button.Text = "ESCOLHER"
			warn("[FactionSelect]", err)
		end
	end)
end

function FactionSelectController.Show()
	if gui.Enabled then
		return
	end
	gui.Enabled = true
	startOrbit()
end

function FactionSelectController.Hide()
	gui.Enabled = false
	stopOrbit()
end

function FactionSelectController.Init()
	gui = Kit.new("ScreenGui", { Name = "FactionSelect", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	Kit.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Parent = gui })
	local content = Kit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1120, 560), Parent = gui })
	Kit.label("BLEACH — SOUL REBIRTH", 42, { Size = UDim2.new(1, 0, 0, 48), TextXAlignment = Enum.TextXAlignment.Center, Font = T.FontTitle, Parent = content })
	Kit.label("Escolha o caminho da sua alma", 18, { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = T.Muted, Parent = content })
	local row = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 420),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		BorderSizePixel = 0,
		Parent = content,
	}, { Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, id in Factions.Order do
		card(row, id, i)
	end
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
end

return FactionSelectController

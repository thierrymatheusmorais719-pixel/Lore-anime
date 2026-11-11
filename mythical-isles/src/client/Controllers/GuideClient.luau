-- GUIA DO OBJETIVO (cliente): feixe saindo do jogador até o alvo da missão atual, com um marcador flutuante
-- (nome da missão + distância). Some perto do alvo. Se o alvo é em outro mundo, o marcador avisa para viajar
-- pelo menu Mundos. O servidor (GuideService) decide o alvo e publica nos atributos do jogador.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local State = require(script.Parent.State)

local GuideClient = {}

local lp = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 214, 110)
local NEAR = 18

local anchor: Part?
local beam: Beam?
local att1: Attachment?
local label: TextLabel?
local gui: BillboardGui?

local function build()
	local folder = workspace.CurrentCamera
	local a = Instance.new("Part")
	a.Name = "GuideTarget"
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
	a.Transparency = 1
	a.Size = Vector3.one * 0.5
	a.Parent = folder
	local at = Instance.new("Attachment")
	at.Parent = a
	local bb = Instance.new("BillboardGui")
	bb.Name = "GuideMarker"
	bb.Size = UDim2.fromOffset(220, 56)
	bb.StudsOffset = Vector3.new(0, 7, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 2000
	bb.Parent = a
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = GOLD
	t.TextStrokeTransparency = 0.3
	t.RichText = true
	t.Parent = bb
	local b = Instance.new("Beam")
	b.Name = "GuideBeam"
	b.Attachment1 = at
	b.Width0, b.Width1 = 0.5, 0.5
	b.FaceCamera = true
	b.LightEmission = 1
	b.Color = ColorSequence.new(GOLD)
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.15, 0.35), NumberSequenceKeypoint.new(1, 0.1) })
	b.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = 3
	b.TextureSpeed = 1.5
	b.Segments = 10
	b.CurveSize0 = 6
	b.Parent = a
	anchor, beam, att1, label, gui = a, b, at, t, bb
end

local function step()
	local target = lp:GetAttribute("GuideTarget")
	local char = lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local off = State.profile and State.profile.settings and State.profile.settings.guide == false
	if off or typeof(target) ~= "Vector3" or not root or not anchor or not beam or not label or not gui then
		if gui then
			gui.Enabled = false
		end
		if beam then
			beam.Enabled = false
		end
		return
	end
	local a0 = root:FindFirstChild("GuideFrom")
	if not a0 then
		a0 = Instance.new("Attachment")
		a0.Name = "GuideFrom"
		a0.Position = Vector3.new(0, -1.5, 0)
		a0.Parent = root
	end
	beam.Attachment0 = a0 :: Attachment
	anchor.Position = target + Vector3.new(0, 1, 0)
	local wid = lp:GetAttribute("GuideWorld")
	local here = lp:GetAttribute("World")
	local otherWorld = wid ~= nil and here ~= nil and wid ~= here
	local dist = (root.Position - target).Magnitude
	local name = tostring(lp:GetAttribute("GuideLabel") or "Objetivo")
	if otherWorld then
		beam.Enabled = false
		gui.Enabled = true
		label.Text = string.format("%s\n<font size=\"14\">viaje para %s (menu Mundos)</font>", name, Worlds.Info[wid] and Worlds.Info[wid].name or wid)
	else
		beam.Enabled = dist > NEAR
		gui.Enabled = dist > NEAR * 0.6
		label.Text = string.format("%s\n<font size=\"14\">%d studs</font>", name, math.floor(dist))
	end
	local _ = att1
end

function GuideClient.init()
	build()
	RunService.Heartbeat:Connect(step)
end

return GuideClient

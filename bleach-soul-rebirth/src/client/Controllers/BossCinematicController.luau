-- Introdução cinematográfica de chefes (primeira aproximação de cada spawn) e derrota em câmera lenta.
local Players = game:GetService("Players")

local Controllers = script.Parent
local Kit = require(script.Parent.Parent.UI.Kit)
local CameraController = require(Controllers.CameraController)
local SoundController = require(Controllers.SoundController)
local SpectacleFx = require(Controllers.SpectacleFx)
local VFX = require(Controllers.VFXController)
local DataController = require(Controllers.DataController)

local BossCinematicController = {}

local T = Kit.Theme
local player = Players.LocalPlayer
local gui: ScreenGui
local card: Frame
local seen: { [Model]: boolean } = {}

local function cinematicsEnabled(): boolean
	local profile = DataController.Profile
	return not (profile and profile.settings and profile.settings.cinematics == "Off")
end

local function showCard(kanji: string, title: string, subtitle: string, color: Color3, duration: number)
	local k = card:FindFirstChild("Kanji") :: TextLabel
	local t = card:FindFirstChild("Title") :: TextLabel
	local s = card:FindFirstChild("Subtitle") :: TextLabel
	local stripe = card:FindFirstChild("Stripe") :: Frame
	k.Text = kanji
	k.TextColor3 = color
	t.Text = title
	s.Text = subtitle
	stripe.BackgroundColor3 = color
	card.Visible = true
	stripe.Size = UDim2.new(0, 0, 0, 4)
	Kit.tween(stripe, 0.4, { Size = UDim2.new(1, 0, 0, 4) })
	for _, label in { k, t, s } do
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
	end
	t.Position = UDim2.new(0, -60, 0, 96)
	Kit.tween(k, 0.3, { TextTransparency = 0.1, TextStrokeTransparency = 0.4 })
	task.delay(0.15, function()
		Kit.tween(
			t,
			0.35,
			{ TextTransparency = 0, TextStrokeTransparency = 0, Position = UDim2.new(0, 0, 0, 96) },
			Enum.EasingStyle.Back
		)
		Kit.tween(s, 0.35, { TextTransparency = 0, TextStrokeTransparency = 0.5 })
	end)
	task.delay(duration, function()
		for _, label in { k, t, s } do
			Kit.tween(label, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
		Kit.tween(stripe, 0.4, { Size = UDim2.new(0, 0, 0, 4) })
		task.wait(0.45)
		card.Visible = false
	end)
end

function BossCinematicController.Intro(boss: Model)
	local root = boss:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local color = VFX.Color("Hollow")
	local name = tostring(boss:GetAttribute("DisplayName") or boss.Name)
	local level = boss:GetAttribute("Level") or 1
	SoundController.Play("Ultimate")
	SpectacleFx.WorldKanji(root, "虚", color, 2.6, 30)
	if cinematicsEnabled() then
		CameraController.PlayCinematic(root, {
			{
				duration = 1.1,
				fromAngle = 200,
				toAngle = 170,
				distance = 30,
				distanceEnd = 18,
				height = 3,
				fov = 55,
				lookHeight = 4,
			},
			{ duration = 1.3, fromAngle = 20, toAngle = -15, distance = 14, height = 0, fov = 40, lookHeight = 5 },
		})
		task.delay(1.1, function()
			SpectacleFx.ImpactFrame(0.9)
			CameraController.Shake(0.6)
			VFX.Shockwave(root.Position - Vector3.new(0, 3, 0), color, 30, 0.7, 1)
		end)
	end
	showCard("虚", string.upper(name), string.format("CHEFE  ·  NÍVEL %d", level), color, 2.8)
end

function BossCinematicController.Defeat(boss: Model)
	local root = boss:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local gold = Color3.fromRGB(255, 210, 90)
	SpectacleFx.ImpactFrame(1.3)
	SpectacleFx.BlurPulse(18, 0.6)
	CameraController.Shake(0.9)
	if cinematicsEnabled() then
		CameraController.PlayCinematic(root, {
			{
				duration = 2.2,
				fromAngle = 120,
				toAngle = 200,
				distance = 16,
				distanceEnd = 24,
				height = 4,
				fov = 50,
				lookHeight = 2,
			},
		})
	end
	task.delay(0.5, function()
		VFX.Pillar(root.Position - Vector3.new(0, 3, 0), gold, 6, 120, 1.6)
		SpectacleFx.Crater(root.Position, 12, gold)
	end)
	showCard("勝", "VITÓRIA", tostring(boss:GetAttribute("DisplayName") or boss.Name) .. " foi derrotado", gold, 3)
end

function BossCinematicController.Init()
	gui = Kit.new(
		"ScreenGui",
		{
			Name = "BossCard",
			ResetOnSpawn = false,
			DisplayOrder = 55,
			IgnoreGuiInset = true,
			Parent = player:WaitForChild("PlayerGui"),
		}
	)
	card = Kit.new(
		"Frame",
		{
			Name = "Card",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 80, 0.62, 0),
			Size = UDim2.fromOffset(800, 170),
			Visible = false,
			Parent = gui,
		}
	)
	Kit.label(
		"",
		96,
		{ Name = "Kanji", Size = UDim2.fromOffset(120, 110), Font = T.FontTitle, TextTransparency = 1, Parent = card }
	)
	Kit.label(
		"",
		54,
		{
			Name = "Title",
			Position = UDim2.fromOffset(0, 96),
			Size = UDim2.new(1, 0, 0, 56),
			Font = T.FontAnime,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextTransparency = 1,
			Parent = card,
		}
	)
	Kit.label(
		"",
		18,
		{
			Name = "Subtitle",
			Position = UDim2.fromOffset(4, 150),
			Size = UDim2.new(1, 0, 0, 22),
			Font = T.FontBold,
			TextColor3 = T.Muted,
			TextTransparency = 1,
			Parent = card,
		}
	)
	Kit.new(
		"Frame",
		{
			Name = "Stripe",
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 92),
			Size = UDim2.new(0, 0, 0, 4),
			Parent = card,
		}
	)
	Kit.autoScale(gui)
end

function BossCinematicController.Start()
	task.spawn(function()
		local bosses = workspace:WaitForChild("Bosses")
		while true do
			task.wait(0.5)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				for _, boss in bosses:GetChildren() do
					if boss:IsA("Model") and not seen[boss] then
						local bossRoot = boss:FindFirstChild("HumanoidRootPart") :: BasePart?
						local humanoid = boss:FindFirstChildOfClass("Humanoid")
						if
							bossRoot
							and humanoid
							and humanoid.Health > 0
							and (bossRoot.Position - root.Position).Magnitude < 70
						then
							seen[boss] = true
							boss.AncestryChanged:Connect(function(_, parent)
								if parent == nil then
									seen[boss] = nil
								end
							end)
							BossCinematicController.Intro(boss)
						end
					end
				end
			end
		end
	end)
end

return BossCinematicController

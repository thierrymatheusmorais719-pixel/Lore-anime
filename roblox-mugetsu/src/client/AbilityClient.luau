--!strict
-- Lado cliente da habilidade: telegraph visual, projétil, cooldown e animação de lançamento.
-- O servidor decide tudo (dano, cooldown); aqui só se desenha e se envia o pedido.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Mugetsu")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local PoseApplier = require(script.Parent:WaitForChild("PoseApplier"))
local VFX = require(script.Parent:WaitForChild("VFX"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local CameraDirector = require(script.Parent:WaitForChild("CameraDirector"))

local AbilityClient = {}

local localPlayer = Players.LocalPlayer
local clientCooldownUntil = 0 -- só para não spammar o remote; o servidor é quem valida de verdade

local function groundY(pos: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { localPlayer.Character :: Instance? }
	local r = Workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	return r and r.Position.Y + 0.08 or pos.Y - 3
end

function AbilityClient.request()
	if localPlayer:GetAttribute("MugetsuForm") ~= true or localPlayer:GetAttribute("MugetsuAbilityReady") ~= true then
		return
	end
	if localPlayer:GetAttribute("MugetsuCutscene") == true then
		return
	end
	if Workspace:GetServerTimeNow() < clientCooldownUntil then
		return
	end
	local cam = Workspace.CurrentCamera
	local look = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local aim = Vector3.new(look.X, 0, look.Z)
	if aim.Magnitude < 0.01 and root then
		aim = root.CFrame.LookVector
	end
	clientCooldownUntil = Workspace:GetServerTimeNow() + 0.3
	Remotes.get("RequestAbility"):FireServer(aim)
end

local function showTelegraph(p: any)
	local origin: Vector3, dir: Vector3 = p.origin, p.dir
	local y = groundY(origin)
	local length, width, tele = p.range, p.width, p.telegraph
	local q = VFX.session()
	local base = Instance.new("Part")
	base.Name = "MugetsuTelegraph"
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.CastShadow = false
	base.Material = Enum.Material.Neon
	base.Color = Color3.fromRGB(190, 22, 34)
	base.Transparency = 0.8
	base.Size = Vector3.new(width, 0.12, length)
	local mid = Vector3.new(origin.X, y, origin.Z) + dir * (length / 2)
	base.CFrame = CFrame.lookAt(mid, mid + dir)
	base.Parent = Workspace
	local fill = base:Clone()
	fill.Color = Color3.fromRGB(255, 255, 255)
	fill.Transparency = 0.45
	fill.Size = Vector3.new(width, 0.16, 0.1)
	fill.Parent = Workspace
	local start = os.clock()
	local conn
	conn = game:GetService("RunService").Heartbeat:Connect(function()
		local k = math.clamp((os.clock() - start) / tele, 0, 1)
		fill.Size = Vector3.new(width * k, 0.16, length * k)
		local m = Vector3.new(origin.X, y + 0.02, origin.Z) + dir * (length * k / 2)
		fill.CFrame = CFrame.lookAt(m, m + dir)
		if k >= 1 then
			conn:Disconnect()
		end
	end)
	task.delay(tele + 0.05, function()
		if conn then
			conn:Disconnect()
		end
		base:Destroy()
		fill:Destroy()
		q:clean()
	end)

	-- animação de lançamento + brilho de carga
	local who = Players:GetPlayerByUserId(p.userId)
	local char = who and who.Character
	if char then
		local applier = PoseApplier.new(char, who == localPlayer)
		applier:play("GetsugaCast", p.startTime)
		task.delay(1.3, function()
			applier:stop()
		end)
		local s = VFX.session()
		s:lightPulse(origin, VFX.Colors.Red, 3, 22, tele)
		task.delay(tele + 0.5, function()
			s:clean()
		end)
	end
end

local function showFire(p: any)
	local s = VFX.session()
	s:projectile(p.origin, p.dir, p.speed, p.range, p.width, p.startTime)
	s:shockwave(CFrame.new(p.origin.X, groundY(p.origin), p.origin.Z), 12, 0.5, VFX.Colors.White)
	if p.userId == localPlayer.UserId and CameraDirector.isActive() == false then
		local cam = Workspace.CurrentCamera
		if cam then
			local fov = cam.FieldOfView
			cam.FieldOfView = fov + 6
			TweenService:Create(cam, TweenInfo.new(0.3), { FieldOfView = fov }):Play()
		end
	end
	task.delay(p.range / p.speed + 1.5, function()
		s:clean()
	end)
end

function AbilityClient.init()
	Remotes.get("AbilityTelegraph").OnClientEvent:Connect(showTelegraph)
	Remotes.get("AbilityFire").OnClientEvent:Connect(showFire)
	Remotes.get("AbilityCooldown").OnClientEvent:Connect(function(p)
		Hud.setCooldown(p.readyAt, p.duration)
	end)
end

return AbilityClient

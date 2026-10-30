--!strict
-- Aplica animações em um personagem R15:
--   * se AssetManifest.Animations[nome].id existe -> usa a animação REAL (Animator) e repassa os
--     KeyframeMarkers como eventos;
--   * senão -> usa o PoseDriver (poses procedurais em Motor6D.Transform), determinístico pelo
--     relógio do servidor (todos os clientes veem a mesma pose).
-- Ao parar, zera as Transforms e devolve o script Animate ao estado original.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Mugetsu")
local PoseDriver = require(Shared:WaitForChild("PoseDriver"))
local Manifest = require(Shared:WaitForChild("AssetManifest"))

local JOINT_PATH = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	RightShoulder = { "RightUpperArm", "RightShoulder" },
	RightElbow = { "RightLowerArm", "RightElbow" },
	LeftShoulder = { "LeftUpperArm", "LeftShoulder" },
	LeftElbow = { "LeftLowerArm", "LeftElbow" },
	RightWrist = { "RightHand", "RightWrist" },
	LeftWrist = { "LeftHand", "LeftWrist" },
	RightHip = { "RightUpperLeg", "RightHip" },
	RightKnee = { "RightLowerLeg", "RightKnee" },
	LeftHip = { "LeftUpperLeg", "LeftHip" },
	LeftKnee = { "LeftLowerLeg", "LeftKnee" },
}

local PoseApplier = {}
PoseApplier.__index = PoseApplier

export type Applier = typeof(setmetatable(
	{} :: {
		char: Model,
		joints: { [string]: Motor6D },
		anim: string?,
		startServer: number,
		intensity: number,
		bindName: string,
		bound: boolean,
		animate: LocalScript?,
		animateWasEnabled: boolean,
		track: AnimationTrack?,
		markerConns: { RBXScriptConnection },
		onMarker: ((string) -> ())?,
		isOwner: boolean,
	},
	PoseApplier
))

local counter = 0

function PoseApplier.new(char: Model, isOwner: boolean): Applier
	counter += 1
	local joints: { [string]: Motor6D } = {}
	for name, path in JOINT_PATH do
		local limb = char:FindFirstChild(path[1])
		local m = limb and limb:FindFirstChild(path[2])
		if m and m:IsA("Motor6D") then
			joints[name] = m
		end
	end
	local animate = char:FindFirstChild("Animate")
	return setmetatable({
		char = char, joints = joints, anim = nil, startServer = 0, intensity = 0,
		bindName = `MugetsuPose{counter}`, bound = false,
		animate = animate and animate:IsA("LocalScript") and animate or nil,
		animateWasEnabled = true, track = nil, markerConns = {}, onMarker = nil, isOwner = isOwner,
	}, PoseApplier)
end

local function stopTracks(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, t in animator:GetPlayingAnimationTracks() do
			t:Stop(0.15)
		end
	end
end

local function clearMarkers(self: Applier)
	for _, c in self.markerConns do
		c:Disconnect()
	end
	self.markerConns = {}
end

local function bind(self: Applier)
	if self.bound then
		return
	end
	self.bound = true
	RunService:BindToRenderStep(self.bindName, Enum.RenderPriority.Camera.Value - 2, function()
		local anim = self.anim
		if not anim or self.track then
			return -- animação real em execução: o Animator cuida das juntas
		end
		local t = Workspace:GetServerTimeNow() - self.startServer
		local pose = PoseDriver.sample(anim, math.max(t, 0), self.intensity)
		if not pose then
			return
		end
		for name, j in pose do
			local m = self.joints[name]
			if m then
				local yOff = name == "Root" and j[4] or 0
				m.Transform = CFrame.new(0, yOff or 0, 0) * CFrame.Angles(math.rad(j[1]), math.rad(j[2]), math.rad(j[3]))
			end
		end
	end)
end

-- Retorna true se há animação real (os markers chegam por onMarker).
function PoseApplier.play(self: Applier, name: string, serverStart: number, intensity: number?): boolean
	self.anim = name
	self.startServer = serverStart
	self.intensity = intensity or 0
	clearMarkers(self)
	if self.track then
		self.track:Stop(0.1)
		self.track = nil
	end
	if self.isOwner then
		if self.animate and self.animate.Enabled then
			self.animateWasEnabled = true
			self.animate.Enabled = false
		end
		stopTracks(self.char)
	end
	local entry = Manifest.Animations[name]
	if self.isOwner and entry and entry.id ~= "" then
		local hum = self.char:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then
			local a = Instance.new("Animation")
			a.AnimationId = entry.id
			local ok, track = pcall(function()
				return animator:LoadAnimation(a)
			end)
			if ok and track then
				track.Looped = entry.looped
				track.Priority = Enum.AnimationPriority.Action4
				for marker in entry.markers do
					table.insert(self.markerConns, track:GetMarkerReachedSignal(marker):Connect(function()
						if self.onMarker then
							self.onMarker(entry.markers[marker])
						end
					end))
				end
				track:Play(0.1)
				self.track = track
				return true
			end
		end
	end
	bind(self)
	return false
end

function PoseApplier.setIntensity(self: Applier, v: number)
	self.intensity = v
end

function PoseApplier.stop(self: Applier)
	clearMarkers(self)
	if self.bound then
		pcall(function()
			RunService:UnbindFromRenderStep(self.bindName)
		end)
		self.bound = false
	end
	if self.track then
		self.track:Stop(0.2)
		self.track = nil
	end
	self.anim = nil
	for _, m in self.joints do
		if m.Parent then
			m.Transform = CFrame.identity
		end
	end
	if self.isOwner and self.animate and self.animate.Parent then
		self.animate.Enabled = self.animateWasEnabled
	end
end

return PoseApplier

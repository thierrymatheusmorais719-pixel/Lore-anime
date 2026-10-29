--!strict
-- Ponto de entrada do cliente.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Mugetsu")
local Remotes = require(Shared:WaitForChild("Remotes"))

local Hud = require(script.Parent:WaitForChild("Hud"))
local InputController = require(script.Parent:WaitForChild("InputController"))
local CutsceneController = require(script.Parent:WaitForChild("CutsceneController"))
local AbilityClient = require(script.Parent:WaitForChild("AbilityClient"))
local HairSway = require(script.Parent:WaitForChild("HairSway"))
local AudioDirector = require(script.Parent:WaitForChild("AudioDirector"))

local player = Players.LocalPlayer

Hud.init()
HairSway.init()
CutsceneController.init()
AbilityClient.init()

local function requestTransform()
	if CutsceneController.isRunning() or player:GetAttribute("MugetsuForm") == true then
		return
	end
	Remotes.get("RequestTransform"):FireServer()
end

Hud.onTransform = requestTransform
Hud.onAbility = AbilityClient.request
InputController.bind(requestTransform, AbilityClient.request)

local function refreshButtons()
	local inForm = player:GetAttribute("MugetsuForm") == true
	local inScene = player:GetAttribute("MugetsuCutscene") == true
	local ready = player:GetAttribute("MugetsuAbilityReady") == true
	Hud.showButtons(not inForm and not inScene, inForm and ready and not inScene)
end
for _, a in { "MugetsuForm", "MugetsuCutscene", "MugetsuAbilityReady" } do
	player:GetAttributeChangedSignal(a):Connect(refreshButtons)
end
refreshButtons()

print("[Mugetsu] cliente pronto: aperte " .. require(Shared:WaitForChild("Config")).Transform.Keybind.Name .. " para transformar")
local missing = AudioDirector.missing()
if #missing > 0 then
	print("[Mugetsu] sons ainda sem ID no AssetManifest: " .. table.concat(missing, ", "))
end

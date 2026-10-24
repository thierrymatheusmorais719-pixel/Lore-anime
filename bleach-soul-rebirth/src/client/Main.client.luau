-- Inicialização do cliente: Init em ordem, depois Start.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Controllers = script.Parent.Controllers

local ORDER = {
	"DataController",
	"InputController",
	"SoundController",
	"CameraController",
	"VFXController",
	"SpectacleFx",
	"ElementFx",
	"MeshFx",
	"ImpactFx",
	"ReleaseCutscene",
	"AnimController",
	"CreatureSkin",
	"HumanSkin",
	"HollowFx",
	"CombatController",
	"BossCinematicController",
	"FxController",
	"ZoneController",
	"GraphicsController",
	"AmbientController",
	"HUDController",
	"DialogueController",
	"FactionSelectController",
	"MenuController",
}

local loaded = {}
for _, name in ORDER do
	local module = Controllers:FindFirstChild(name)
	if module then
		-- um módulo que quebra ao carregar não derruba os outros (animação, HUD...)
		local ok, result = pcall(require, module)
		if ok then
			loaded[name] = result
		else
			warn("[Client] " .. name .. " não carregou: " .. tostring(result))
		end
	end
end

for _, name in ORDER do
	local controller = loaded[name]
	if controller and controller.Init then
		local ok, err = pcall(controller.Init)
		if not ok then
			warn("[Client] Init de " .. name .. " falhou: " .. tostring(err))
		end
	end
end

for _, name in ORDER do
	local controller = loaded[name]
	if controller and controller.Start then
		local ok, err = pcall(controller.Start)
		if not ok then
			warn("[Client] Start de " .. name .. " falhou: " .. tostring(err))
		end
	end
end

-- HUD própria substitui barra de vida padrão
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

print("[Client] Bleach — Soul Rebirth carregado para", Players.LocalPlayer.Name)

--!strict
-- Seleciona o nível de qualidade dos efeitos. Pode ser forçado com o atributo "MugetsuQuality"
-- no LocalPlayer ("Low" | "Medium" | "High").
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Mugetsu"):WaitForChild("Config"))

local Quality = {}

function Quality.level(): Config.QualityLevel
	local forced = Players.LocalPlayer:GetAttribute("MugetsuQuality")
	if forced == "Low" or forced == "Medium" or forced == "High" then
		return forced :: Config.QualityLevel
	end
	local ok, saved = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	local n = ok and saved.Value or 0
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return n >= 8 and "Medium" or "Low"
	end
	if n == 0 then
		return "High"
	end
	return n <= 3 and "Low" or (n <= 7 and "Medium" or "High")
end

function Quality.settings()
	return Config.Quality[Quality.level()]
end

return Quality

-- Inicialização do cliente do Mythical Isles.
local Controllers = script.Parent:WaitForChild("Controllers")

local State = require(Controllers.State)
State.init()

for _, name in ipairs({ "Animator", "Fx", "WorldClient", "HUD", "CombatHUD", "Panels", "Input" }) do
	local ok, err = pcall(function()
		require(Controllers:WaitForChild(name)).init()
	end)
	if not ok then
		warn("[MythicalIsles] falha ao iniciar " .. name .. ": " .. tostring(err))
	end
end

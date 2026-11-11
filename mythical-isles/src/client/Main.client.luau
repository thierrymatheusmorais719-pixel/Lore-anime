-- Inicialização do cliente do Mythical Isles.
local Controllers = script.Parent:WaitForChild("Controllers")

local State = require(Controllers.State)
State.init()
local Status = require(Controllers.Status)
Status.init()

for _, name in ipairs({ "Animator", "PetVisuals", "Fx", "BossVisuals", "SanctuaryClient", "WorldClient", "SkyClient", "RegionClient", "MiningClient", "GuideClient", "HUD", "CombatHUD", "Cinematics", "Panels", "Input" }) do
	local ok, err = xpcall(function()
		require(Controllers:WaitForChild(name)).init()
	end, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	if not ok then
		warn("[MythicalIsles] falha ao iniciar " .. name .. ": " .. tostring(err))
		Status.reportClientError(name .. ": " .. tostring(err))
	end
end

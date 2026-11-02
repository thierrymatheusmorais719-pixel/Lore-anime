-- Inicialização do servidor do Mythical Isles.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
Net.setup()

local Services = script.Parent:WaitForChild("Services")
local registry = {}
registry.Push = Net.get("Push")

local ORDER = {
	"DataService", "LuckService", "AnnounceService", "RewardService", "QuestService", "WorldService",
	"PetService", "CombatService", "EnemyService", "BossService", "ExplorationService", "EggService",
	"DevService", "RequestRouter",
}

for _, name in ipairs(ORDER) do
	registry[name] = require(Services:WaitForChild(name))
end
for _, name in ipairs(ORDER) do
	registry[name].init(registry)
end

local t0 = os.clock()
registry.WorldService.build()
print(string.format("[MythicalIsles] mundos construídos em %.2fs", os.clock() - t0))

-- DataService por último: ao iniciar ele carrega os jogadores e dispara os callbacks onLoaded.
for _, name in ipairs(ORDER) do
	if name ~= "DataService" then
		registry[name].start()
	end
end
registry.DataService.start()
print("[MythicalIsles] servidor pronto")

-- Testes de lógica pura no Studio (os mesmos do CLI: tools/run_tests.py)
if RunService:IsStudio() then
	task.spawn(function()
		local TestRunner = require(Shared.Tests.TestRunner)
		local specs = {}
		for _, m in ipairs(Shared.Tests:GetChildren()) do
			if m:IsA("ModuleScript") and m.Name:match("%.spec$") then
				table.insert(specs, { name = m.Name, mod = require(m) })
			end
		end
		TestRunner.run(specs, function(line)
			print("[Testes] " .. line)
		end)
	end)
end

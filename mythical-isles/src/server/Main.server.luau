-- Inicialização do servidor do Mythical Isles.
-- Cada etapa roda protegida: um erro numa parte NÃO impede o resto do jogo de subir, e o erro
-- aparece no Output E na tela do jogador (atributo ServerErrors no ReplicatedStorage).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local errors = {}
local function report(label: string, err)
	local msg = label .. ": " .. tostring(err)
	warn("[MythicalIsles] ERRO " .. msg)
	table.insert(errors, msg)
	ReplicatedStorage:SetAttribute("ServerErrors", table.concat(errors, "\n\n"))
end
local function safe(label: string, fn, ...)
	local ok, err = xpcall(fn, function(e)
		return debug.traceback(tostring(e), 2)
	end, ...)
	if not ok then
		report(label, err)
	end
	return ok
end
ReplicatedStorage:SetAttribute("ServerReady", false)

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

-- Rede de segurança: se por qualquer motivo o personagem não for criado, cria depois de alguns segundos.
local joinedAt: { [Player]: number } = {}
local function watchPlayer(p: Player)
	joinedAt[p] = os.clock()
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(p)
	joinedAt[p] = nil
end)
for _, p in ipairs(Players:GetPlayers()) do
	watchPlayer(p)
end
task.spawn(function()
	while true do
		task.wait(2)
		for p, t in pairs(joinedAt) do
			if p.Parent and not p.Character and os.clock() - t > 6 then
				joinedAt[p] = os.clock()
				safe("LoadCharacter (rede de segurança) " .. p.Name, function()
					p:LoadCharacter()
				end)
			end
		end
	end
end)

for _, name in ipairs(ORDER) do
	safe("require " .. name, function()
		registry[name] = require(Services:WaitForChild(name))
	end)
end
for _, name in ipairs(ORDER) do
	if registry[name] then
		safe("init " .. name, registry[name].init, registry)
	end
end

local t0 = os.clock()
if registry.WorldService then
	safe("construção do mundo", registry.WorldService.build)
end
print(string.format("[MythicalIsles] mundos construídos em %.2fs", os.clock() - t0))

-- DataService por último: ao iniciar ele carrega os jogadores e dispara os callbacks onLoaded.
for _, name in ipairs(ORDER) do
	if name ~= "DataService" and registry[name] then
		safe("start " .. name, registry[name].start)
	end
end
if registry.DataService then
	safe("start DataService", registry.DataService.start)
end
ReplicatedStorage:SetAttribute("ServerReady", true)
print(string.format("[MythicalIsles] servidor pronto (%d erro(s))", #errors))

-- Testes de lógica pura no Studio (os mesmos do CLI: tools/run_tests.py)
if RunService:IsStudio() then
	task.spawn(function()
		safe("testes", function()
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
	end)
end

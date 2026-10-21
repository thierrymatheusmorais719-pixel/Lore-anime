-- Inicialização do servidor: cria remotes, registra serviços, Init (ordem) e Start (paralelo seguro).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Log = require(Shared.Util.Log)
local Registry = require(script.Parent.Registry)

local log = Log.new("Main")
local started = os.clock()

Net.init()

local ORDER = {
	"UIService",
	"DataService",
	"CombatService",
	"AbilityService",
	"TransformationService",
	"CharacterService",
	"ProgressionService",
	"InventoryService",
	"QuestService",
	"WorldService",
	"EnemyService",
	"DevService",
}

local services = script.Parent.Services
for _, name in ORDER do
	Registry[name] = require(services:FindFirstChild(name))
end

for _, name in ORDER do
	local ok, err = pcall(Registry[name].Init)
	if not ok then
		log:Error("Init de", name, "falhou:", err)
	end
end

for _, name in ORDER do
	local ok, err = pcall(Registry[name].Start)
	if not ok then
		log:Error("Start de", name, "falhou:", err)
	end
end

workspace:SetAttribute("ServerReady", true)
log:Info(string.format("Bleach — Soul Rebirth pronto em %.2fs", os.clock() - started))

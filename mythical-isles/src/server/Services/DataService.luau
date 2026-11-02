-- Persistência dos perfis.
--   * DataStore com UpdateAsync + trava de sessão (evita dois servidores gravando o mesmo perfil)
--   * novas tentativas com espera crescente
--   * autosave periódico + salvamento ao sair + BindToClose
--   * modo memória (sem salvar) quando o DataStore não está disponível (ex.: Studio sem API)
-- Também envia o estado do perfil ao dono (Push "State"), com limitação de frequência.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DataSchema = require(Shared.Logic.DataSchema)
local Net = require(Shared.Net)

local DataService = {}

local STORE_NAME = "MythicalIsles_v1"
local AUTOSAVE = 120
local LOCK_STALE = 300 -- trava mais velha que isso é considerada abandonada
local RETRIES = 5

local S -- registro de serviços
local store: DataStore? = nil
local memoryMode = false
local profiles: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local loadedCallbacks = {}
local leavingCallbacks = {}
local Push

local function keyFor(player: Player): string
	return "p_" .. player.UserId
end

local function retry(fn)
	local delay = 1
	local lastErr
	for _ = 1, RETRIES do
		local ok, a, b = pcall(fn)
		if ok then
			return true, a, b
		end
		lastErr = a
		task.wait(delay)
		delay *= 2
	end
	return false, lastErr
end

function DataService.init(registry)
	S = registry
	Push = Net.get("Push")
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		-- No Studio sem "Enable Studio Access to API Services" a primeira chamada falha.
		local probeOk = pcall(function()
			(store :: DataStore):GetAsync("__probe")
		end)
		if not probeOk then
			memoryMode = true
		end
	else
		memoryMode = true
	end
	if memoryMode then
		warn("[DataService] DataStore indisponível: MODO MEMÓRIA (nada será salvo). No Studio, ative Game Settings > Security > Enable Studio Access to API Services.")
	end
end

function DataService.isMemoryMode(): boolean
	return memoryMode
end

function DataService.onLoaded(cb)
	table.insert(loadedCallbacks, cb)
end

function DataService.onLeaving(cb)
	table.insert(leavingCallbacks, cb)
end

function DataService.get(player: Player)
	return profiles[player]
end

function DataService.markDirty(player: Player)
	if profiles[player] then
		dirty[player] = true
	end
end

-- Visão enviada ao cliente: o próprio perfil + valores derivados que o servidor calcula.
function DataService.pushState(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	local view = {
		profile = data,
		derived = S.PetService and S.PetService.derivedView(player) or nil,
		serverTime = os.time(),
		memoryMode = memoryMode,
	}
	Push:FireClient(player, "State", view)
end

local function load(player: Player)
	if memoryMode then
		return DataSchema.reconcile(DataSchema.default())
	end
	local key = keyFor(player)
	for attempt = 1, RETRIES do
		local data = nil
		local lockedElsewhere = false
		local ok, err = retry(function()
			(store :: DataStore):UpdateAsync(key, function(record)
				record = record or {}
				local lock = record.lock
				local now = os.time()
				if lock and lock.job ~= game.JobId and now - (lock.t or 0) < LOCK_STALE then
					lockedElsewhere = true
					return nil -- não altera
				end
				lockedElsewhere = false
				record.lock = { job = game.JobId, t = now }
				data = record.data
				return record
			end)
		end)
		if not ok then
			warn("[DataService] falha ao carregar", player.Name, err)
			return nil
		end
		if not lockedElsewhere then
			return DataSchema.reconcile(data or DataSchema.default())
		end
		task.wait(2 * attempt)
	end
	return nil
end

function DataService.save(player: Player, release: boolean?)
	local data = profiles[player]
	if not data or memoryMode then
		return true
	end
	DataSchema.pruneEncounters(data, os.time())
	local key = keyFor(player)
	local ok, err = retry(function()
		(store :: DataStore):UpdateAsync(key, function(record)
			record = record or {}
			if record.lock and record.lock.job ~= game.JobId and os.time() - (record.lock.t or 0) < LOCK_STALE then
				return nil -- outro servidor assumiu: não sobrescreve
			end
			record.data = data
			record.lock = (not release) and { job = game.JobId, t = os.time() } or nil
			return record
		end)
	end)
	if not ok then
		warn("[DataService] falha ao salvar", player.Name, err)
	end
	return ok
end

local function onJoin(player: Player)
	local data = load(player)
	if not player.Parent then
		return
	end
	if not data then
		player:Kick("Não foi possível carregar seus dados com segurança. Tente novamente em instantes.")
		return
	end
	profiles[player] = data
	player:SetAttribute("Loaded", true)
	for _, cb in ipairs(loadedCallbacks) do
		task.spawn(cb, player, data)
	end
	DataService.pushState(player)
end

local function onLeave(player: Player)
	for _, cb in ipairs(leavingCallbacks) do
		pcall(cb, player)
	end
	if profiles[player] then
		DataService.save(player, true)
	end
	profiles[player] = nil
	dirty[player] = nil
end

function DataService.start()
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(onLeave)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onJoin, p)
	end
	-- envio de estado limitado a ~4x/s
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in pairs(dirty) do
				dirty[player] = nil
				DataService.pushState(player)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for player in pairs(profiles) do
				task.spawn(DataService.save, player, false)
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() and memoryMode then
			return
		end
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				DataService.save(player, true)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService

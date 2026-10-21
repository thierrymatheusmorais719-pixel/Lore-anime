-- Persistência com DataStoreService: trava de sessão via UpdateAsync, salvamento automático,
-- tentativas com backoff, BindToClose e modo em memória quando o Studio não tem acesso às APIs.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DataSchema = require(Shared.Logic.DataSchema)
local Signal = require(Shared.Util.Signal)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)

local log = Log.new("DataService")

local DataService = {}
DataService.ProfileLoaded = Signal.new()

local STORE_NAME = "BSR_Profiles_v1"
local AUTOSAVE_INTERVAL = 90
local LOCK_EXPIRY = 600
local MAX_ATTEMPTS = 5

local store: DataStore? = nil
local memoryMode = false
local profiles: { [Player]: any } = {}
local loading: { [Player]: boolean } = {}
local dirtySync: { [Player]: boolean } = {}
local dataSyncRemote: RemoteEvent

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function withRetry<T>(label: string, fn: () -> T): (boolean, T?)
	local delay = 1
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		local message = tostring(result)
		-- No Studio (lugar não publicado ou sem acesso às APIs) qualquer falha vira modo memória:
		-- o jogo continua jogável em vez de expulsar o jogador.
		if RunService:IsStudio() or message:find("StudioAccessToApisNotAllowed") or message:find("403") or message:find("publish") then
			if not memoryMode then
				log:Warn(
					"Sem acesso às APIs do DataStore (Studio). Usando memória — nada será salvo. Ative em Game Settings > Security > Enable Studio Access to API Services."
				)
			end
			memoryMode = true
			return false, nil
		end
		log:Warn(label, "falhou (tentativa", attempt, "):", message)
		if attempt < MAX_ATTEMPTS then
			task.wait(delay)
			delay *= 2
		end
	end
	return false, nil
end

local function loadProfile(player: Player): any?
	if memoryMode or not store then
		return DataSchema.normalize(nil)
	end
	local jobId = game.JobId ~= "" and game.JobId or "studio"
	for _ = 1, 4 do
		local lockedByOther = false
		local ok, data = withRetry("Carregar " .. player.UserId, function()
			return (store :: DataStore):UpdateAsync(key(player), function(old)
				local now = os.time()
				if type(old) == "table" and type(old.session) == "table" then
					local s = old.session
					if s.job ~= jobId and now - (s.time or 0) < LOCK_EXPIRY then
						lockedByOther = true
						return nil -- não altera
					end
				end
				local profile = DataSchema.normalize(old)
				profile.session = { job = jobId, time = now }
				return profile
			end)
		end)
		if memoryMode then
			return DataSchema.normalize(nil)
		end
		if not ok then
			return nil
		end
		if not lockedByOther and data then
			return DataSchema.normalize(data)
		end
		log:Warn("Perfil de", player.UserId, "travado por outro servidor; aguardando...")
		task.wait(4)
		if not player.Parent then
			return nil
		end
	end
	-- Trava antiga demais ou servidor anterior travado: assume a sessão.
	local ok, data = withRetry("Forçar sessão " .. player.UserId, function()
		return (store :: DataStore):UpdateAsync(key(player), function(old)
			local profile = DataSchema.normalize(old)
			profile.session = { job = jobId, time = os.time() }
			return profile
		end)
	end)
	if ok and data then
		return DataSchema.normalize(data)
	end
	return nil
end

local function saveProfile(player: Player, release: boolean): boolean
	local profile = profiles[player]
	if not profile or memoryMode or not store then
		return true
	end
	local jobId = game.JobId ~= "" and game.JobId or "studio"
	local ok = withRetry("Salvar " .. player.UserId, function()
		return (store :: DataStore):UpdateAsync(key(player), function(old)
			if type(old) == "table" and type(old.session) == "table" and old.session.job ~= jobId then
				-- Outro servidor assumiu: não sobrescreve
				return nil
			end
			local copy = table.clone(profile)
			copy.session = if release then nil else { job = jobId, time = os.time() }
			return copy
		end)
	end)
	return ok
end

-- Snapshot seguro para o cliente.
local function snapshot(profile: any): any
	local copy = table.clone(profile)
	copy.lootPity = nil
	copy.session = nil
	return copy
end

function DataService.Get(player: Player): any?
	return profiles[player]
end

function DataService.WaitFor(player: Player, timeout: number?): any?
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

-- Marca para envio ao cliente (agrupa várias mudanças no mesmo frame).
function DataService.Sync(player: Player)
	dirtySync[player] = true
end

function DataService.IsMemoryMode(): boolean
	return memoryMode
end

function DataService.Init()
	dataSyncRemote = Net.event("DataSync")
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		memoryMode = true
		log:Warn("DataStore indisponível:", result)
	end
end

function DataService.Start()
	local function onPlayer(player: Player)
		if loading[player] or profiles[player] then
			return
		end
		loading[player] = true
		local profile = loadProfile(player)
		loading[player] = nil
		if not player.Parent then
			return
		end
		if not profile then
			player:Kick("Não foi possível carregar seus dados. Tente novamente em instantes.")
			return
		end
		profiles[player] = profile
		log:Info("Perfil carregado:", player.Name, "nível", profile.level, memoryMode and "(memória)" or "")
		dataSyncRemote:FireClient(player, snapshot(profile))
		DataService.ProfileLoaded:Fire(player, profile)
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		if profiles[player] then
			saveProfile(player, true)
		end
		profiles[player] = nil
		dirtySync[player] = nil
	end)

	-- Envio agrupado de sincronização
	RunService.Heartbeat:Connect(function()
		if next(dirtySync) == nil then
			return
		end
		for player in dirtySync do
			local profile = profiles[player]
			if profile and player.Parent then
				dataSyncRemote:FireClient(player, snapshot(profile))
			end
		end
		table.clear(dirtySync)
	end)

	-- Salvamento automático + tempo de jogo
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				profile.record.playSeconds += AUTOSAVE_INTERVAL
				task.spawn(saveProfile, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return DataService

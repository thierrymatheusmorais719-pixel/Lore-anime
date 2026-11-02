-- Anúncios de descobertas extraordinárias.
--   * "server": todos os jogadores deste servidor (que não desativaram anúncios)
--   * "global": também outros servidores via MessagingService
-- Proteção contra duplicados: cada descoberta tem um id único; ids já vistos são ignorados
-- (inclusive a mensagem que volta do MessagingService para o próprio servidor).

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RateLimiter = require(Shared.Util.RateLimiter)

local AnnounceService = {}

local TOPIC = "MythicalIsles_Discoveries"
local S
local Push
local seen: { [string]: number } = {}
local publishLimiter = RateLimiter.new(10, 60) -- MessagingService tem limites: no máx. 10/min daqui

function AnnounceService.init(registry)
	S = registry
	Push = Net.get("Push")
end

function AnnounceService.newId(): string
	return HttpService:GenerateGUID(false)
end

local function deliver(payload)
	if seen[payload.id] then
		return false
	end
	seen[payload.id] = os.time()
	for _, p in ipairs(Players:GetPlayers()) do
		local data = S.DataService.get(p)
		if data and data.settings.announcements ~= false then
			Push:FireClient(p, "Announce", payload)
		end
	end
	return true
end

-- payload = { id, player, text, rarity, kind, scope = "server"|"global" }
function AnnounceService.announce(payload)
	payload.id = payload.id or AnnounceService.newId()
	payload.jobId = game.JobId
	if not deliver(payload) then
		return
	end
	if payload.scope == "global" and publishLimiter:allow("global") then
		task.spawn(function()
			pcall(function()
				MessagingService:PublishAsync(TOPIC, payload)
			end)
		end)
	end
end

function AnnounceService.start()
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local payload = message.Data
				if type(payload) ~= "table" or type(payload.id) ~= "string" or payload.jobId == game.JobId then
					return
				end
				payload.remote = true
				deliver(payload)
			end)
		end)
		if not ok then
			warn("[AnnounceService] MessagingService indisponível (anúncios só neste servidor):", err)
		end
	end)
	-- limpa ids antigos
	task.spawn(function()
		while true do
			task.wait(300)
			local now = os.time()
			for id, t in pairs(seen) do
				if now - t > 600 then
					seen[id] = nil
				end
			end
		end
	end)
end

return AnnounceService

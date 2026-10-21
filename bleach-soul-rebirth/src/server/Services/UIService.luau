-- Notificações para o cliente e roteador de pedidos de menu (RemoteFunction "Request").
-- Todo handler recebe (player, payload) e retorna (ok, mensagemOuDados).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.Util.RateLimiter)
local Log = require(Shared.Util.Log)

local log = Log.new("UIService")

local UIService = {}

local handlers: { [string]: (Player, any) -> (boolean, any) } = {}
local notifyRemote: RemoteEvent
local limiter = RateLimiter.new(8, 15)

function UIService.Notify(player: Player, text: string, kind: string?, extra: { [string]: any }?)
	if notifyRemote and player.Parent then
		notifyRemote:FireClient(player, { text = text, kind = kind or "info", extra = extra })
	end
end

function UIService.Register(kind: string, handler: (Player, any) -> (boolean, any))
	assert(not handlers[kind], "Handler duplicado: " .. kind)
	handlers[kind] = handler
end

function UIService.Init()
	notifyRemote = Net.event("Notify")
end

function UIService.Start()
	Net.func("Request").OnServerInvoke = function(player: Player, kind: any, payload: any)
		if type(kind) ~= "string" then
			return { ok = false, err = "Pedido inválido" }
		end
		if not limiter:Check(player) then
			return { ok = false, err = "Muitas ações seguidas — aguarde um instante." }
		end
		local handler = handlers[kind]
		if not handler then
			return { ok = false, err = "Pedido desconhecido" }
		end
		local ok, okResult, data = pcall(handler, player, payload)
		if not ok then
			log:Error("Handler", kind, "falhou:", okResult)
			return { ok = false, err = "Erro interno" }
		end
		if okResult then
			return { ok = true, data = data }
		end
		return { ok = false, err = data }
	end
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(player)
	end)
end

return UIService

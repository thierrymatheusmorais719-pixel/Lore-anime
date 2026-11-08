-- Elevador de Seiva da Árvore-Santuário (Verdant Haven): estações nos andares da árvore, cada uma com
-- "Subir" e "Descer" para a estação vizinha. Tudo validado no servidor: o jogador precisa estar no
-- Verdant Haven, PERTO de uma estação vizinha ao destino; a Coroa Estelar só abre depois de vencer o
-- Elderroot (bestiário do perfil). Os pets vão junto.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RateLimiter = require(Shared.Util.RateLimiter)
local Bosses = require(Shared.Config.Bosses)

local SanctuaryService = {}

local S
local limiter = RateLimiter.new(1, 1.2)
SanctuaryService.RANGE = 16

function SanctuaryService.init(registry)
	S = registry
end

local function tree()
	return S.WorldService.Sanctuary
end

local function byOrder(order: number)
	local t = tree()
	for _, st in pairs(t and t.stops or {}) do
		if st.order == order then
			return st
		end
	end
	return nil
end

-- Leva o jogador até a estação `toId`. Devolve { ok, msg }.
function SanctuaryService.ride(player: Player, toId: string)
	local t = tree()
	local dest = t and t.stops[toId]
	if not dest then
		return { ok = false, msg = "Estação inválida" }
	end
	if not limiter:allow(player) then
		return { ok = false, msg = "Aguarde um instante" }
	end
	local data = S.DataService.get(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not root then
		return { ok = false, msg = "Indisponível" }
	end
	if S.WorldService.playerWorld(player) ~= "verdant" then
		return { ok = false, msg = "O Elevador de Seiva fica no Verdant Haven" }
	end
	-- precisa estar perto de uma estação vizinha (não dá para "pular" andares nem chamar de longe)
	local near = false
	for _, st in pairs(t.stops) do
		if math.abs(st.order - dest.order) == 1 and (root.Position - st.pos).Magnitude <= SanctuaryService.RANGE then
			near = true
		end
	end
	if not near then
		return { ok = false, msg = "Chegue mais perto da estação de seiva" }
	end
	if dest.requiresBoss and not (data.bestiary and data.bestiary.bosses and data.bestiary.bosses[dest.requiresBoss]) then
		local msg = string.format("A seiva ainda não sobe até a %s: vença o %s para despertá-la", dest.label, Bosses.Info[dest.requiresBoss].name)
		S.Push:FireClient(player, "Toast", { text = msg, kind = "error" })
		return { ok = false, msg = msg }
	end
	(char :: Model):PivotTo(dest.arrival)
	root.AssemblyLinearVelocity = Vector3.zero
	S.PetService.teleportPets(player, dest.arrival.Position)
	S.Push:FireClient(player, "Toast", { text = "🌳 " .. dest.label, kind = "region" })
	return { ok = true }
end

function SanctuaryService.start()
	local t = tree()
	if not t then
		return
	end
	for _, st in pairs(t.stops) do
		local up, down = byOrder(st.order + 1), byOrder(st.order - 1)
		for _, info in ipairs({ { up, "Subir", Enum.KeyCode.E, 0 }, { down, "Descer", Enum.KeyCode.R, 70 } }) do
			local dest = info[1]
			if dest then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = info[2]
				prompt.ObjectText = "Elevador de Seiva → " .. dest.label
				prompt.KeyboardKeyCode = info[3]
				prompt.UIOffset = Vector2.new(0, info[4])
				prompt.HoldDuration = 0.3
				prompt.MaxActivationDistance = 12
				prompt.RequiresLineOfSight = false
				prompt.Parent = st.part
				prompt.Triggered:Connect(function(player)
					SanctuaryService.ride(player, dest.id)
				end)
				st[info[2] == "Subir" and "upPrompt" or "downPrompt"] = prompt
			end
		end
	end
end

return SanctuaryService

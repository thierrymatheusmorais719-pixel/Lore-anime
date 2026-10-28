--!strict
-- Limite simples por jogador e por chave.
local RateLimiter = {}
local last: { [Player]: { [string]: number } } = {}

function RateLimiter.allow(player: Player, key: string, minInterval: number): boolean
	local now = os.clock()
	local row = last[player]
	if not row then
		row = {}
		last[player] = row
	end
	local prev = row[key]
	if prev and now - prev < minInterval then
		return false
	end
	row[key] = now
	return true
end

function RateLimiter.forget(player: Player)
	last[player] = nil
end

return RateLimiter

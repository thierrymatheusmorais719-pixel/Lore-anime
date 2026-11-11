-- Limitador por jogador e por chave (janela deslizante simples + intervalo mínimo).
local RateLimiter = {}
RateLimiter.__index = RateLimiter

-- maxPerWindow pedidos por `window` segundos, com pelo menos `minInterval` entre eles.
function RateLimiter.new(maxPerWindow: number, window: number, minInterval: number?)
	return setmetatable({ max = maxPerWindow, window = window, minInterval = minInterval or 0, buckets = setmetatable({}, { __mode = "k" }) }, RateLimiter) -- chaves fracas: jogador que saiu não fica preso aqui
end

function RateLimiter:allow(key: any, now: number?): boolean
	now = now or os.clock()
	local b = self.buckets[key]
	if not b then
		b = { count = 0, start = now, last = -math.huge }
		self.buckets[key] = b
	end
	if now - b.last < self.minInterval then
		return false
	end
	if now - b.start >= self.window then
		b.start = now
		b.count = 0
	end
	if b.count >= self.max then
		return false
	end
	b.count += 1
	b.last = now
	return true
end

function RateLimiter:clear(key: any)
	self.buckets[key] = nil
end

return RateLimiter

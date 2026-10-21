-- Token bucket por chave (ex.: jogador). Protege RemoteEvents contra spam.
local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(ratePerSecond: number, burst: number)
	return setmetatable({ _rate = ratePerSecond, _burst = burst, _buckets = {} }, RateLimiter)
end

function RateLimiter:Check(key: any, now: number?): boolean
	local t = now or os.clock()
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = self._burst, last = t }
		self._buckets[key] = bucket
	end
	bucket.tokens = math.min(self._burst, bucket.tokens + (t - bucket.last) * self._rate)
	bucket.last = t
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter:Remove(key: any)
	self._buckets[key] = nil
end

return RateLimiter

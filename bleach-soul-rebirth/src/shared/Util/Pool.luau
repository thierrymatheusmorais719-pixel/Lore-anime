-- Pool genérico de objetos (usado para efeitos repetitivos: números de dano, faíscas, sons).
local Pool = {}
Pool.__index = Pool

export type PoolOptions<T> = {
	create: () -> T,
	reset: ((T) -> ())?,
	max: number?,
}

function Pool.new<T>(options: PoolOptions<T>)
	return setmetatable({
		_create = options.create,
		_reset = options.reset,
		_max = options.max or 32,
		_free = {},
	}, Pool)
end

function Pool:Get()
	local free = self._free
	local n = #free
	if n > 0 then
		local item = free[n]
		free[n] = nil
		return item
	end
	return self._create()
end

function Pool:Release(item: any)
	if self._reset then
		self._reset(item)
	end
	if #self._free < self._max then
		table.insert(self._free, item)
	elseif typeof(item) == "Instance" then
		item:Destroy()
	end
end

return Pool

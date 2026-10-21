local TableUtil = {}

function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[TableUtil.deepCopy(k)] = TableUtil.deepCopy(v)
	end
	return copy :: any
end

-- Preenche chaves ausentes de `target` a partir de `template` (recursivo). Não remove extras.
function TableUtil.reconcile(target: { [any]: any }, template: { [any]: any })
	for k, v in template do
		if target[k] == nil then
			target[k] = TableUtil.deepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil then
			TableUtil.reconcile(target[k], v)
		end
	end
	return target
end

function TableUtil.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function TableUtil.keys(t: { [any]: any }): { any }
	local out = {}
	for k in t do
		table.insert(out, k)
	end
	return out
end

function TableUtil.freezeDeep<T>(t: T): T
	if type(t) == "table" and not table.isfrozen(t :: any) then
		for _, v in t :: any do
			TableUtil.freezeDeep(v)
		end
		table.freeze(t :: any)
	end
	return t
end

return TableUtil

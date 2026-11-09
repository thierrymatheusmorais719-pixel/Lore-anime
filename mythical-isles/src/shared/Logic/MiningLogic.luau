-- Regras puras da mineração de cristais (o servidor executa; os testes de unidade conferem).

local Mining = require(script.Parent.Parent.Config.Mining)
local InventoryLogic = require(script.Parent.InventoryLogic)

local MiningLogic = {}

function MiningLogic.pickaxe(data)
	local lvl = math.clamp(math.floor(tonumber(data.mining and data.mining.pickaxe) or 1), 1, #Mining.Pickaxes)
	return Mining.Pickaxes[lvl], lvl
end

-- Força de um golpe: picareta + ajuda dos pets por perto (+1 a cada 2 pets).
function MiningLogic.strikePower(level: number, petsNearby: number): number
	local pk = Mining.Pickaxes[math.clamp(level, 1, #Mining.Pickaxes)]
	return pk.power + math.floor(math.max(0, petsNearby) / 2)
end

-- Intervalo mínimo entre golpes aceitos pelo servidor (um pouco abaixo do tempo de segurar o botão).
function MiningLogic.minInterval(level: number): number
	local pk = Mining.Pickaxes[math.clamp(level, 1, #Mining.Pickaxes)]
	return pk.hold * 0.85
end

-- Cristais de uma quebra. roll(a, b) = inteiro sorteado em [a, b]; rand() = número em [0, 1).
function MiningLogic.yield(veinKind: string, level: number, roll, rand, rareChance: number)
	local v = Mining.Veins[veinKind]
	local pk = Mining.Pickaxes[math.clamp(level, 1, #Mining.Pickaxes)]
	local out = { [v.crystal] = roll(v.yield[1], v.yield[2]) + pk.bonus }
	if rand() < rareChance then
		out.prism_heart = 1
	end
	return out
end

-- Contratos do dia (iguais para todos no mesmo dia), só dos mundos que o jogador já abriu.
function MiningLogic.contractsFor(day: number, worlds): { string }
	local pool = {}
	for _, c in ipairs(Mining.Contracts) do
		if not worlds or worlds[c.world] then
			table.insert(pool, c.id)
		end
	end
	local seed = (day * 69069 + 1013904223) % 4294967296
	local chosen = {}
	for _ = 1, math.min(Mining.ContractsPerDay, #pool) do
		seed = (seed * 69069 + 1013904223) % 4294967296
		local i = (seed % #pool) + 1
		table.insert(chosen, table.remove(pool, i))
	end
	return chosen
end

function MiningLogic.ensureContracts(data, day: number)
	local m = data.mining
	local c = m.contracts
	if c.day ~= day then
		c.day = day
		c.ids = MiningLogic.contractsFor(day, data.worlds)
		c.done = {}
	end
end

-- Entrega um contrato: confere se é do dia, se ainda não foi entregue e se tem os cristais; debita.
-- Devolve (recompensa, contrato) ou (nil, motivo).
function MiningLogic.deliver(data, id: string)
	local c = data.mining.contracts
	local ct = Mining.findContract(id)
	if not ct or not table.find(c.ids, id) then
		return nil, "Contrato indisponível hoje"
	end
	if c.done[id] then
		return nil, "Contrato já entregue"
	end
	local cost = { items = ct.need }
	local ok, why = InventoryLogic.canAfford(data, cost)
	if not ok then
		return nil, why
	end
	InventoryLogic.spend(data, cost)
	c.done[id] = true
	data.mining.contractsDone = (data.mining.contractsDone or 0) + 1
	return ct.reward, ct
end

-- Melhora a picareta para o próximo nível. Devolve (novo nível) ou (nil, motivo).
function MiningLogic.upgrade(data)
	local lvl = math.clamp(math.floor(data.mining.pickaxe or 1), 1, #Mining.Pickaxes)
	local nextP = Mining.Pickaxes[lvl + 1]
	if not nextP then
		return nil, "Picareta já no nível máximo"
	end
	local ok, why = InventoryLogic.canAfford(data, nextP.cost)
	if not ok then
		return nil, why
	end
	InventoryLogic.spend(data, nextP.cost)
	data.mining.pickaxe = lvl + 1
	return lvl + 1
end

return MiningLogic

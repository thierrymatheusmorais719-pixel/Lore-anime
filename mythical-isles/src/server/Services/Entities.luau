-- Registro dos alvos de combate do servidor (inimigos e bosses).
-- A vida, defesa, efeitos e contribuições ficam AQUI (servidor). O modelo só espelha
-- atributos para a interface (Health, MaxHealth, Level, DisplayName, Shielded...).

local Entities = {}

local byModel: { [Instance]: any } = {}
local list: { any } = {}
local nextId = 0

-- e = { kind = "enemy"|"boss", id = configId, model, root, cfg, maxHp, def, level, world, radius, name }
function Entities.register(e)
	nextId += 1
	e.eid = nextId
	e.hp = e.maxHp
	e.alive = true
	e.defMods = {} -- { { amount, untilT } }
	e.marks = {} -- { { bonus, untilT } }
	e.stunnedUntil = 0
	e.slowUntil = 0
	e.slowAmount = 0
	e.invulnerable = false
	e.contrib = {} -- [userId] = { damage, support, tanked, lastAt, player }
	e.pets = {} -- [userId] = { [uid] = dano } para XP
	byModel[e.model] = e
	table.insert(list, e)
	e.model:SetAttribute("Entity", e.eid)
	e.model:SetAttribute("Health", e.hp)
	e.model:SetAttribute("MaxHealth", e.maxHp)
	e.model:SetAttribute("Level", e.level)
	e.model:SetAttribute("DisplayName", e.name)
	e.model:SetAttribute("Kind", e.kind)
	return e
end

function Entities.unregister(e)
	byModel[e.model] = nil
	local i = table.find(list, e)
	if i then
		table.remove(list, i)
	end
end

function Entities.fromInstance(inst: Instance?)
	while inst do
		local e = byModel[inst]
		if e then
			return e
		end
		inst = inst.Parent
	end
	return nil
end

function Entities.all()
	return list
end

function Entities.defReduction(e, now: number): number
	local total = 0
	for i = #e.defMods, 1, -1 do
		local m = e.defMods[i]
		if m.untilT <= now then
			table.remove(e.defMods, i)
		else
			total = math.max(total, m.amount) -- não acumula: vale o maior
		end
	end
	return total
end

function Entities.markBonus(e, now: number): number
	local total = 0
	for i = #e.marks, 1, -1 do
		local m = e.marks[i]
		if m.untilT <= now then
			table.remove(e.marks, i)
		else
			total = math.max(total, m.bonus)
		end
	end
	return total
end

function Entities.contribution(e, player: Player)
	local c = e.contrib[player.UserId]
	if not c then
		c = { damage = 0, support = 0, tanked = 0, lastAt = 0, player = player }
		e.contrib[player.UserId] = c
	end
	return c
end

return Entities

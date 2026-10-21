--!strict
-- Ganho de XP e subida de nível (puro).
local ProgressionLogic = {}

export type LevelResult = { levelsGained: number, newLevel: number, xp: number }

function ProgressionLogic.addXp(profile: any, amount: number, progression: any): LevelResult
	local gained = 0
	profile.xp += math.max(0, math.floor(amount))
	while profile.level < progression.MaxLevel do
		local need = progression.xpToNext(profile.level)
		if profile.xp < need then
			break
		end
		profile.xp -= need
		profile.level += 1
		profile.statPoints += progression.StatPointsPerLevel
		profile.skillPoints += progression.SkillPointsPerLevel
		gained += 1
	end
	if profile.level >= progression.MaxLevel then
		profile.xp = 0
	end
	return { levelsGained = gained, newLevel = profile.level, xp = profile.xp }
end

function ProgressionLogic.allocate(
	profile: any,
	attribute: string,
	amount: number,
	progression: any
): (boolean, string?)
	if progression.Attributes[attribute] == nil then
		return false, "Atributo inválido"
	end
	if amount ~= math.floor(amount) or amount < 1 or amount > 100 then
		return false, "Quantidade inválida"
	end
	if profile.statPoints < amount then
		return false, "Pontos insuficientes"
	end
	profile.statPoints -= amount
	profile.stats[attribute] = (profile.stats[attribute] or 0) + amount
	return true, nil
end

-- Reembolsa todos os pontos de atributo (respec gratuito: incentiva experimentação).
function ProgressionLogic.resetStats(profile: any)
	local total = 0
	for name, value in profile.stats do
		total += value
		profile.stats[name] = 0
	end
	profile.statPoints += total
end

-- Valida e compra um nó da árvore.
function ProgressionLogic.unlockSkill(profile: any, tree: any, nodeId: string): (boolean, string?)
	local node = tree and tree[nodeId]
	if not node then
		return false, "Nó inexistente"
	end
	if profile.skills[nodeId] then
		return false, "Já desbloqueado"
	end
	if profile.level < node.level then
		return false, "Requer nível " .. node.level
	end
	if profile.skillPoints < node.cost then
		return false, "Pontos de habilidade insuficientes"
	end
	for _, req in node.requires do
		if not profile.skills[req] then
			return false, "Requer " .. (tree[req] and tree[req].name or req)
		end
	end
	if node.exclusive then
		for ownedId in profile.skills do
			local other = tree[ownedId]
			if other and other.exclusive == node.exclusive then
				return false, "Especialização exclusiva já escolhida: " .. other.name
			end
		end
	end
	profile.skillPoints -= node.cost
	profile.skills[nodeId] = true
	return true, nil
end

return ProgressionLogic

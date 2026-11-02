-- Regras puras de SORTE (sem APIs do Roblox: testável fora do Studio).
--
-- Fluxo no servidor:
--   sources = LuckLogic.collectSources(ctx)        -- fontes válidas agora
--   mult    = LuckLogic.multiplier(sources, cat)    -- multiplicador limitado da categoria
--   probs   = LuckLogic.applyWeighted(entries, mult) -- probabilidades finais (somam 1)
--   p       = LuckLogic.applyChance(base, mult, influencia, teto)

local LuckConfig = require(script.Parent.Parent.Config.Luck)
local Rarities = require(script.Parent.Parent.Config.Rarities)

local LuckLogic = {}

export type Source = {
	type: string, -- event | potion | quest | pet | collection | login | synergy
	id: string,
	label: string,
	category: string, -- categoria de Luck.Categories ou "All"
	bonus: number,
	expires: number?, -- os.time() de expiração (nil = permanente enquanto a condição valer)
}

local function appliesTo(source: Source, category: string): boolean
	return source.category == "All" or source.category == category
end

-- Eventos agendados ativos em `now` (UTC). Mesmo resultado em todos os servidores.
function LuckLogic.activeEvents(now: number, scheduled)
	local list = {}
	for _, ev in ipairs(scheduled or LuckConfig.ScheduledEvents) do
		local t = (now - ev.offset) % ev.period
		if t >= 0 and t < ev.duration then
			table.insert(list, { id = ev.id, label = ev.label, bonus = ev.bonus, category = ev.category, ends = now - t + ev.duration })
		end
	end
	return list
end

-- Quantas espécies de pet e tipos de mutação o perfil já descobriu.
function LuckLogic.collectionCounts(bestiary)
	local species, mutations = 0, 0
	local seenMut = {}
	if bestiary and bestiary.pets then
		for _, entry in pairs(bestiary.pets) do
			species += 1
			if entry.muts then
				for mut in pairs(entry.muts) do
					if not seenMut[mut] then
						seenMut[mut] = true
						mutations += 1
					end
				end
			end
		end
	end
	return species, mutations
end

-- Reúne todas as fontes de sorte válidas para um jogador.
-- ctx = { now, profile, teamPerks = { {label, category, bonus} }, synergy = { {label, category, bonus} }, events = {...}? }
function LuckLogic.collectSources(ctx): { Source }
	local now = ctx.now
	local profile = ctx.profile
	local sources: { Source } = {}

	-- Eventos globais agendados (+ eventos extras passados pelo servidor, ex.: evento manual de admin)
	local events = ctx.events or LuckLogic.activeEvents(now)
	for _, ev in ipairs(events) do
		table.insert(sources, { type = "event", id = ev.id, label = ev.label, category = ev.category, bonus = ev.bonus, expires = ev.ends })
	end

	-- Buffs temporários salvos (poções e recompensas de missão)
	if profile.buffs then
		for _, b in ipairs(profile.buffs) do
			if b.expires > now then
				table.insert(sources, { type = b.source, id = b.id, label = b.label, category = b.category, bonus = b.bonus, expires = b.expires })
			end
		end
	end

	-- Pets equipados com perk de sorte
	for _, perk in ipairs(ctx.teamPerks or {}) do
		table.insert(sources, { type = "pet", id = "pet:" .. perk.label, label = perk.label, category = perk.category, bonus = perk.bonus })
	end

	-- Sinergias de equipe que afetam sorte
	for _, syn in ipairs(ctx.synergy or {}) do
		table.insert(sources, { type = "synergy", id = "syn:" .. syn.label, label = syn.label, category = syn.category, bonus = syn.bonus })
	end

	-- Coleção
	local species, mutations = LuckLogic.collectionCounts(profile.bestiary)
	local collectionBonus = species * LuckConfig.Collection.perSpecies + mutations * LuckConfig.Collection.perMutationKind
	if collectionBonus > 0 then
		table.insert(sources, {
			type = "collection", id = "collection",
			label = string.format("Bestiário (%d espécies, %d mutações)", species, mutations),
			category = "All", bonus = collectionBonus,
		})
	end

	-- Login diário
	local login = profile.login
	if login and login.streak and login.streak > 0 and login.claimedAt and now < login.claimedAt + LuckConfig.Login.duration then
		local streak = math.min(login.streak, LuckConfig.Login.maxStreak)
		table.insert(sources, {
			type = "login", id = "login", label = string.format("Login diário (sequência %d)", login.streak),
			category = "All", bonus = streak * LuckConfig.Login.perStreakDay, expires = login.claimedAt + LuckConfig.Login.duration,
		})
	end

	return sources
end

-- Multiplicador de uma categoria. Retorna (mult, detalhamento por tipo de fonte).
function LuckLogic.multiplier(sources: { Source }, category: string, cfg): (number, { [string]: number })
	cfg = cfg or LuckConfig
	local byType: { [string]: number } = {}
	for _, s in ipairs(sources) do
		if appliesTo(s, category) and s.bonus > 0 then
			byType[s.type] = (byType[s.type] or 0) + s.bonus
		end
	end
	local total = 0
	for t, v in pairs(byType) do
		local cap = cfg.SourceCaps[t] or 0
		local capped = math.min(v, cap)
		byType[t] = capped
		total += capped
	end
	local maxMult = cfg.MaxMultiplier[category] or 1
	local mult = math.clamp(1 + total, 1, maxMult)
	return mult, byType
end

-- Estado completo (para a interface): multiplicador de cada categoria + fontes.
function LuckLogic.state(sources: { Source }, cfg)
	cfg = cfg or LuckConfig
	local cats = {}
	for _, c in ipairs(cfg.Categories) do
		cats[c] = (LuckLogic.multiplier(sources, c, cfg))
	end
	return { categories = cats, sources = sources }
end

-- Chance independente com sorte. Nunca fica abaixo da base, nunca passa de max(teto, base) e
-- nunca passa de 1.
function LuckLogic.applyChance(base: number, mult: number, influence: number?, cap: number?): number
	local infl = influence or 1
	local boosted = base * (mult ^ infl)
	local limit = math.max(cap or base, base)
	return math.clamp(math.min(boosted, limit), 0, 1)
end

-- Sorteio por peso com sorte.
-- entries: { { key, weight, rarity, available? } }
-- Retorna lista { key, p, base, rarity, available } com p somando 1 (entre as disponíveis).
function LuckLogic.applyWeighted(entries, mult: number)
	local out = {}
	local totalBase, total = 0, 0
	for _, e in ipairs(entries) do
		if e.available ~= false and e.weight > 0 then
			totalBase += e.weight
		end
	end
	for _, e in ipairs(entries) do
		local info = Rarities.Info[e.rarity]
		local infl = info and info.luckInfluence or 0
		local ok = e.available ~= false and e.weight > 0
		local w = ok and e.weight * (mult ^ infl) or 0
		total += w
		table.insert(out, {
			key = e.key, rarity = e.rarity, available = ok, w = w,
			base = ok and totalBase > 0 and e.weight / totalBase or 0,
			cap = info and info.maxChance or 1,
		})
	end
	if total <= 0 then
		for _, o in ipairs(out) do
			o.p = 0
		end
		return out
	end
	for _, o in ipairs(out) do
		o.p = o.w / total
	end

	-- Aplica tetos por raridade (teto efetivo = max(teto, chance base)) e redistribui o excedente
	-- proporcionalmente entre as entradas que ainda não estão no teto.
	local fixed = {}
	for _ = 1, #out + 1 do
		local excess = 0
		local violated = false
		for i, o in ipairs(out) do
			if not fixed[i] and o.available then
				local limit = math.max(o.cap, o.base)
				if o.p > limit + 1e-12 then
					excess += o.p - limit
					o.p = limit
					fixed[i] = true
					violated = true
				end
			end
		end
		if not violated then
			break
		end
		local freeSum = 0
		for i, o in ipairs(out) do
			if not fixed[i] and o.available then
				freeSum += o.p
			end
		end
		if freeSum <= 0 then
			break
		end
		for i, o in ipairs(out) do
			if not fixed[i] and o.available then
				o.p += excess * (o.p / freeSum)
			end
		end
	end
	for _, o in ipairs(out) do
		o.w = nil
	end
	return out
end

-- Escolhe uma entrada dado r em [0, 1).
function LuckLogic.pick(probs, r: number)
	local acc = 0
	local last = nil
	for _, o in ipairs(probs) do
		if o.p > 0 then
			acc += o.p
			last = o
			if r < acc then
				return o.key, o
			end
		end
	end
	return last and last.key, last -- erro de arredondamento: última entrada válida
end

-- Adiciona um buff temporário à lista do perfil (poção/missão). Mesma poção soma duração.
function LuckLogic.addBuff(buffs, now: number, buff)
	for i = #buffs, 1, -1 do
		if buffs[i].expires <= now then
			table.remove(buffs, i)
		end
	end
	for _, b in ipairs(buffs) do
		if b.id == buff.id then
			b.expires = math.min(math.max(b.expires, now) + buff.duration, now + LuckConfig.MaxPotionDuration)
			b.bonus = math.max(b.bonus, buff.bonus)
			return b
		end
	end
	local entry = {
		id = buff.id, source = buff.source, label = buff.label, category = buff.category,
		bonus = buff.bonus, expires = now + math.min(buff.duration, LuckConfig.MaxPotionDuration),
	}
	table.insert(buffs, entry)
	return entry
end

return LuckLogic

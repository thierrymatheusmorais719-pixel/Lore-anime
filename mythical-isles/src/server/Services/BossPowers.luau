-- MECÂNICAS PRÓPRIAS DOS BOSSES (Config/Bosses: campos effect, linger e os ataques com shape = "power").
--
-- Cada boss tem algo que só ele faz, além das formas no chão:
--   Elderroot       Prisão de Espinhos (prende + campo de espinhos) e Casca Ancestral (corta o dano)
--   Prism Titan     estilhaços que deixam lento, Refração Tripla (leque) e Espelho Prismático (reflete)
--   Tempest Wyrm    raio em cadeia, Células de Tempestade (ficam caindo raios) e Carga Estática (choque)
--   The Wilderbloom poças de veneno, Laço de Vinhas (prende) e Florescer (cura mais com brotos vivos)
--   Void Sovereign  Fendas que sugam energia/Fúria, Buraco Negro (fica no chão) e Fome do Vazio (rouba vida)
--
-- O BossService chama: BossPowers.onHit (cada alvo atingido), BossPowers.afterHits (raio em cadeia e roubo
-- de vida), BossPowers.linger (áreas que ficam) e BossPowers.activate (poderes).

local Telegraph = require(script.Parent.Telegraph)

local BossPowers = {}

local S

function BossPowers.bind(registry)
	S = registry
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function flat(a: Vector3, b: Vector3): number
	return ((a - b) * Vector3.new(1, 0, 1)).Magnitude
end

-- Efeito num jogador atingido.
function BossPowers.onHitPlayer(b, atk, player: Player)
	local ef = atk.effect
	if not ef then
		return
	end
	local root = S.CombatService.charRoot(player)
	if ef.root then
		S.CombatService.slowPlayer(player, 1, ef.root)
		if root then
			S.CombatService.fx("snare", { at = root.Position - Vector3.new(0, 2, 0), radius = 2.4, duration = ef.root, color = b.cfg.color })
		end
	end
	if ef.slow then
		S.CombatService.slowPlayer(player, ef.slow, ef.slowTime or 3)
		if root then
			S.CombatService.fx("chill", { at = root.Position - Vector3.new(0, 2, 0), duration = ef.slowTime or 3, color = b.cfg.color })
		end
	end
end

-- Efeito num pet atingido.
function BossPowers.onHitPet(b, atk, st)
	local ef = atk.effect
	if not ef then
		return
	end
	local now = os.clock()
	if ef.root then
		st.stunUntil = math.max(st.stunUntil or 0, now + ef.root)
		S.CombatService.fx("snare", { at = st.root.Position - Vector3.new(0, 1, 0), radius = 1.6, duration = ef.root, color = b.cfg.color })
	end
	if ef.drain then
		-- a fenda suga a energia (habilidades) e a Fúria (Assinatura) do pet
		st.energy = 0
		st.fury = 0
		if st.model then
			st.model:SetAttribute("Fury", 0)
		end
		S.CombatService.fx("bolt", { from = st.root.Position, to = b.entity.root.Position + Vector3.new(0, 4, 0), color = b.cfg.color, small = true })
	end
end

-- Depois de todos os acertos: raio em cadeia e roubo de vida (Fome do Vazio).
function BossPowers.afterHits(b, atk, hitPets, dealtToPlayers: number, dealtToPets: number)
	local e = b.entity
	local ef = atk.effect
	if ef and ef.chain and #hitPets > 0 then
		local already = {}
		for _, st in ipairs(hitPets) do
			already[st] = true
		end
		local all = {}
		for _, p in ipairs(S.BossService.participants(b)) do
			for _, st in ipairs(S.PetService.team(p)) do
				if st.model and st.model.Parent then
					table.insert(all, st)
				end
			end
		end
		local extra = 0
		for _, src in ipairs(hitPets) do
			local jumps = 0
			for _, st in ipairs(all) do
				if jumps >= ef.chain.n then
					break
				end
				if not already[st] and flat(st.root.Position, src.root.Position) <= ef.chain.range then
					already[st] = true
					jumps += 1
					extra += S.CombatService.hitPet(st, b.cfg.atk, ef.chain.mult, e) or 0
					S.CombatService.fx("chain", { from = src.root.Position + Vector3.new(0, 1.5, 0), to = st.root.Position + Vector3.new(0, 1.5, 0), color = b.cfg.color })
				end
			end
		end
		dealtToPets += extra
	end
	if e.drainUntil and os.clock() < e.drainUntil and e.alive then
		local heal = (dealtToPlayers + dealtToPets) * (e.drainFrac or 0)
		if heal > 0 then
			e.hp = math.min(e.maxHp, e.hp + heal)
			b.model:SetAttribute("Health", math.floor(e.hp))
			S.CombatService.fx("heal", { at = e.root.Position, radius = 10, color = b.cfg.color })
		end
	end
end

-- Área que fica no chão causando dano em intervalos (espinhos, nuvens de raio, veneno, buraco negro).
function BossPowers.linger(b, atk, shapes)
	local ld = atk.linger
	if not ld or #shapes == 0 then
		return
	end
	local AttackShapes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Logic.AttackShapes)
	local zone = Telegraph.show(shapes, b.arena.center.Y + 0.9, ld.duration, ld.label, ld.color)
	if zone then
		zone.Name = "BossZone"
		zone:SetAttribute("Linger", true)
	end
	local encounter = b.encounterId
	task.spawn(function()
		local stop = os.clock() + ld.duration
		while os.clock() < stop do
			task.wait(ld.tick)
			if b.encounterId ~= encounter or b.state == "Defeated" or b.state == "Dormant" or not b.entity or not b.entity.alive then
				break
			end
			for _, p in ipairs(S.BossService.participants(b)) do
				local root = S.CombatService.charRoot(p)
				if root and AttackShapes.hitsAny(shapes, root.Position.X, root.Position.Z, 1) then
					S.CombatService.hitPlayer(p, ld.pdmg, b.entity)
					if ld.slow then
						S.CombatService.slowPlayer(p, ld.slow, ld.tick + 0.3)
					end
				end
				for _, st in ipairs(S.PetService.team(p)) do
					if st.model and st.model.Parent and AttackShapes.hitsAny(shapes, st.root.Position.X, st.root.Position.Z, 1) then
						S.CombatService.hitPet(st, b.cfg.atk, ld.petMult, b.entity)
					end
				end
			end
		end
		Telegraph.clear(zone)
	end)
end

-- PODER: o boss se fortalece por alguns segundos (ou se cura). Marca o modelo para o cliente mostrar.
function BossPowers.activate(b, atk)
	local e = b.entity
	if not e or not e.alive then
		return
	end
	local now = os.clock()
	local dur = atk.duration or 0
	local kind = atk.power
	if kind == "bark" then
		e.guardUntil, e.guardAmount = now + dur, atk.amount
	elseif kind == "mirror" then
		e.thornsUntil, e.thornsFrac, e.thornsAtk, e.thornsMult, e.thornsColor = now + dur, atk.amount, nil, 1, b.cfg.color
	elseif kind == "static" then
		e.thornsUntil, e.thornsFrac, e.thornsAtk, e.thornsMult, e.thornsColor = now + dur, nil, b.cfg.atk, atk.amount, b.cfg.color
	elseif kind == "drain" then
		e.drainUntil, e.drainFrac = now + dur, atk.amount
	elseif kind == "bloom" then
		local alive = 0
		for _, s in ipairs(b.summons or {}) do
			if s.alive then
				alive += 1
			end
		end
		local heal = e.maxHp * ((atk.base or 0) + (atk.perSummon or 0) * alive)
		e.hp = math.min(e.maxHp, e.hp + heal)
		b.model:SetAttribute("Health", math.floor(e.hp))
		b.lastBloomHeal = heal
		dur = 1.5
	end
	b.model:SetAttribute("Power", kind)
	b.model:SetAttribute("PowerLabel", atk.label)
	b.model:SetAttribute("PowerUntil", serverNow() + dur)
	S.CombatService.fx("bossPower", { at = e.root.Position, model = b.model, power = kind, duration = dur, color = b.cfg.color, radius = e.radius or 6 })
	for _, p in ipairs(S.BossService.participants(b)) do
		S.Push:FireClient(p, "BossPower", { boss = b.cfg.name, label = atk.label, desc = atk.desc or "", color = b.cfg.color })
	end
end

-- Limpa os poderes (boss reiniciado ou derrotado).
function BossPowers.clear(b)
	local e = b.entity
	if e then
		e.guardUntil, e.thornsUntil, e.drainUntil = nil, nil, nil
	end
	if b.model then
		b.model:SetAttribute("Power", nil)
		b.model:SetAttribute("PowerUntil", nil)
	end
end

return BossPowers

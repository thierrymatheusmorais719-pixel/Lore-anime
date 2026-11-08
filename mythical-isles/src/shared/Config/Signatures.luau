-- ATAQUES ASSINATURA: um ataque próprio por pet do Verdant Haven (Mundo 1).
--
-- Cada ataque básico do pet enche a barra de FÚRIA; quando ela enche (FuryMax pela raridade), o próximo
-- ataque é o Assinatura da espécie. Não gasta energia nem compete com a habilidade de classe (teclas 1-4).
-- Tudo é executado e validado no servidor (SignatureService); o cliente só desenha o efeito (`vfx`).
--
-- Campos:
--   name, desc, vfx (estilo do efeito no cliente), color/color2
--   shape: "single" (o alvo) | "cone" (à frente do pet: range, angle) | "circle" (em volta do pet: radius)
--          | "area" (em volta do alvo: radius) | "line" (do pet na direção do alvo: length, width)
--          | "chain" (alvo + ricochete: chain, bounce, chainPower) | "multi" (até `targets` inimigos: range, splash?)
--          | "tornado" (área que anda do pet até o alvo: radius) | "team" (só efeitos na equipe)
--   power: multiplicador do ataque do pet por golpe; hits/interval: golpes repetidos (pulsos)
--   grow: o raio cresce a cada pulso (ondas); anchor: os pulsos ficam onde o ataque começou (totem)
--   dash: o pet salta até o alvo antes do golpe
--   efeitos nos inimigos: stun (s) | root (s) | slow = { amount, duration } | knock (studs) | pull (studs)
--          | defDown = { amount, duration } | mark = { bonus, duration } | bleed = { power, ticks } | critBonus
--          (em bosses, atordoar/prender vira lentidão de BossSlow; empurrar/puxar não move bosses)
--   efeitos na equipe: heal (fração da vida máx.) | shield = { amount, duration } | atkBuff = { amount, duration }
--          | haste (s, também acelera a corrida do dono em `walk`) | taunt (s) | reveal (raio de faro)

local Signatures = {}

Signatures.FuryMax = { Common = 5, Uncommon = 5, Rare = 6, Epic = 6, Legendary = 7, Mythic = 8, Secret = 8, Celestial = 8 }
Signatures.BossSlow = 0.4

local rgb = Color3.fromRGB
local LEAF, PINK, GOLD, SPORE, SAP = rgb(120, 230, 90), rgb(255, 140, 200), rgb(255, 214, 110), rgb(255, 232, 130), rgb(255, 196, 80)
local ROOT, WIND, EMERALD, THORN = rgb(150, 230, 110), rgb(190, 255, 230), rgb(80, 255, 150), rgb(210, 190, 140)

Signatures.Info = {
	-- COMUNS: diretos e rápidos (vento, folhas, mordidas)
	kit = { name = "Mordida de Folha Cortante", shape = "single", dash = true, power = 1.5, vfx = "bite", color = LEAF,
		desc = "Avança e morde, soltando um arco de folhas cortantes." },
	hop = { name = "Pulo Florido", shape = "area", radius = 6, power = 1.2, heal = 0.03, vfx = "bloom", color = PINK,
		desc = "Pula sobre o alvo; flores brotam na queda e curam a equipe." },
	mossling = { name = "Bola de Musgo", shape = "single", hits = 2, interval = 0.35, power = 0.7, taunt = 2, vfx = "roll", color = rgb(150, 200, 90),
		desc = "Vira uma bola de musgo, quica duas vezes no alvo e atrai os ataques." },
	fawn = { name = "Coice Saltitante", shape = "single", hits = 2, interval = 0.2, power = 0.75, knock = 5, vfx = "kick", color = LEAF,
		desc = "Coice duplo com rajada de folhas que empurra o inimigo." },
	chirp = { name = "Bicada Tripla", shape = "single", hits = 3, interval = 0.15, power = 0.5, critBonus = 0.1, vfx = "peck", color = rgb(255, 230, 140),
		desc = "Três bicadas rápidas com penas-folha voando." },
	scamper = { name = "Bolota Certeira", shape = "chain", chain = 1, bounce = 14, power = 1.0, chainPower = 0.6, vfx = "acorn", color = rgb(190, 130, 70),
		desc = "Arremessa uma bolota que ricocheteia num segundo inimigo." },
	lilyfrog = { name = "Língua de Vitória-Régia", shape = "single", power = 0.9, pull = 8, stun = 0.4, vfx = "tongue", color = rgb(255, 150, 190),
		desc = "Língua elástica que puxa o alvo e interrompe o golpe dele." },
	leafpanda = { name = "Abraço de Folhas", shape = "single", power = 1.1, shield = { amount = 0.06, duration = 5 }, vfx = "leafwrap", color = LEAF,
		desc = "Rola até o alvo e o envolve no manto de folhas; protege a equipe." },
	-- INCOMUNS
	leafwing = { name = "Leque de Penas", shape = "cone", range = 22, angle = 40, hits = 5, interval = 0.06, power = 0.35, vfx = "feathers", color = LEAF,
		desc = "Dispara cinco penas verdes em leque." },
	cap = { name = "Nuvem de Esporos", shape = "area", radius = 8, hits = 4, interval = 0.75, power = 0.25, slow = { amount = 0.25, duration = 3 }, vfx = "spores", color = SPORE,
		desc = "Nuvem de esporos que brilha, deixa os inimigos lentos e causa dano contínuo." },
	goat = { name = "Marrada de Musgo", shape = "single", dash = true, power = 1.4, knock = 8, vfx = "ram", color = rgb(160, 210, 110),
		desc = "Corrida curta e chifrada que arremessa o inimigo." },
	leafcat = { name = "Garra do Vento Verde", shape = "single", hits = 2, interval = 0.2, power = 0.8, critBonus = 0.25, vfx = "claw", color = WIND,
		desc = "Corte em X com rastro verde; o segundo corte acerta mais crítico." },
	sproutslime = { name = "Splash de Seiva", shape = "area", radius = 7, power = 0.9, slow = { amount = 0.3, duration = 3 }, vfx = "splash", color = SAP,
		desc = "Pula e estoura numa poça de seiva pegajosa." },
	owlet = { name = "Pio Hipnótico", shape = "single", power = 0.6, stun = 1, mark = { bonus = 0.15, duration = 5 }, vfx = "hoot", color = rgb(200, 180, 255),
		desc = "Anéis de som que atordoam o alvo e o deixam vulnerável." },

	-- RAROS: área, controle e projéteis
	thornpup = { name = "Rajada de Espinhos", shape = "circle", radius = 9, power = 1.1, bleed = { power = 0.15, ticks = 3 }, vfx = "thorns", color = THORN,
		desc = "Eriça o pelo e dispara espinhos em círculo; os feridos sangram." },
	golemling = { name = "Pisão Rachado", shape = "cone", range = 14, angle = 60, power = 1.3, stun = 0.8, vfx = "quake", color = ROOT,
		desc = "Bate no chão e abre rachaduras verdes que atordoam." },
	drakeling = { name = "Sopro de Pólen", shape = "cone", range = 20, angle = 35, hits = 6, interval = 0.25, power = 0.4, vfx = "breath", color = GOLD,
		desc = "Jato contínuo de pólen dourado." },
	boar = { name = "Estouro de Espinhos", shape = "line", length = 20, width = 6, dash = true, power = 1.4, stun = 1, vfx = "stampede", color = THORN,
		desc = "Dispara em linha reta derrubando todos no caminho." },
	beetle = { name = "Jardim Blindado", shape = "team", radius = 22, shield = { amount = 0.15, duration = 5 }, vfx = "dome", color = rgb(150, 220, 120),
		desc = "O jardim das costas floresce numa cúpula que protege a equipe." },
	ferret = { name = "Emboscada nas Raízes", shape = "single", dash = true, power = 1.8, reveal = 60, vfx = "ambush", color = rgb(190, 150, 100),
		desc = "Some nas raízes, reaparece atrás do alvo e fareja baús por perto." },
	berrygoat = { name = "Chuva de Frutinhas", shape = "team", radius = 26, heal = 0.10, atkBuff = { amount = 0.10, duration = 6 }, vfx = "berries", color = rgb(255, 90, 120),
		desc = "Frutinhas caem sobre os aliados: curam e dão mais força." },
	-- ÉPICOS
	bloomfox = { name = "Dança das Pétalas", shape = "circle", radius = 10, hits = 4, interval = 0.3, power = 0.45, heal = 0.02, vfx = "petals", color = PINK,
		desc = "Furacão de pétalas: cada volta fere os inimigos e cura a equipe." },
	grovestag = { name = "Galhada Enraizante", shape = "line", length = 24, width = 6, power = 1.2, root = 1.5, vfx = "rootline", color = ROOT,
		desc = "Crava a galhada no chão: raízes brotam em linha e prendem os inimigos." },
	vinelynx = { name = "Bote das Copas", shape = "single", dash = true, power = 2.0, defDown = { amount = 0.35, duration = 5 }, vfx = "pounce", color = LEAF,
		desc = "Cai das copas sobre o alvo e quebra a defesa dele." },
	bloomwyvern = { name = "Esferas de Polinização", shape = "multi", targets = 3, range = 45, splash = 4, power = 0.7, vfx = "orbs", color = GOLD,
		desc = "Três esferas de luz perseguem inimigos diferentes e explodem." },
	petalfox = { name = "Três Caudas Floridas", shape = "circle", radius = 8, hits = 3, interval = 0.35, power = 0.6, heal = 0.02, vfx = "petals", color = rgb(255, 170, 220),
		desc = "As três caudas soltam ondas de pétalas que ferem e curam." },
	turfmammoth = { name = "Tremor da Pradaria", shape = "circle", radius = 14, power = 1.3, slow = { amount = 0.4, duration = 3 }, vfx = "quake", color = rgb(170, 210, 100),
		desc = "Empina e pisa: o chão ondula em anéis e deixa todos lentos." },

	-- LENDÁRIOS: habilidades-espetáculo
	grovekin = { name = "Guardião Elemental", shape = "circle", anchor = true, radius = 12, hits = 8, interval = 1, power = 0.5, taunt = 8, vfx = "totem", color = EMERALD,
		desc = "Invoca um totem de runas que pulsa por 8 s e atrai os ataques." },
	grovetortoise = { name = "Bosque Fortaleza", shape = "team", radius = 26, shield = { amount = 0.25, duration = 6 }, taunt = 4, vfx = "fortress", color = rgb(130, 200, 110),
		desc = "O bosque do casco cresce numa muralha: escudo forte para a equipe." },
	verdantwolf = { name = "Uivo da Matilha", shape = "multi", targets = 3, range = 34, power = 0.9, atkBuff = { amount = 0.2, duration = 6 }, vfx = "howl", color = EMERALD,
		desc = "Uiva: três lobos espectrais de folhas atacam e a equipe fica mais forte." },
	thornmane = { name = "Rugido de Espinhos", shape = "circle", radius = 16, power = 1.8, stun = 1, vfx = "roar", color = THORN,
		desc = "Rugido que dispara uma coroa de espinhos e atordoa." },
	mossape = { name = "Onda de Choque Vibracional", shape = "circle", radius = 8, grow = 5, hits = 3, interval = 0.3, power = 0.9, knock = 4, vfx = "vibration", color = rgb(140, 255, 160),
		desc = "Bate no peito três vezes: ondas com aura verde se espalham e empurram." },
	eldermammoth = { name = "Avalanche de Raízes", shape = "line", length = 30, width = 10, power = 2.4, stun = 1.5, vfx = "rootline", color = rgb(160, 210, 110),
		desc = "Uma onda de terra e raízes rola para a frente e derruba tudo." },

	-- MÍTICOS
	verdigris_wisp = { name = "Vendaval Esmeralda", shape = "tornado", radius = 7, hits = 10, interval = 0.5, power = 0.6, pull = 2, vfx = "tornado", color = EMERALD,
		desc = "Vira um tornado de luz verde que anda até o alvo puxando os inimigos." },
	spectralhound = { name = "Chuva de Meteoros de Esmeralda", shape = "area", radius = 16, hits = 7, interval = 0.18, power = 0.8, vfx = "meteors", color = EMERALD,
		desc = "O céu escurece e sete meteoros de esmeralda caem sobre a área." },
	sylphstag = { name = "Dança do Vento Alado", shape = "circle", radius = 12, power = 1.0, haste = 8, walk = 8, vfx = "winddance", color = WIND,
		desc = "Voa em círculo: a equipe ataca mais rápido e o dono corre mais." },
	elderstag = { name = "Despertar das Raízes Ancestrais", shape = "area", radius = 18, power = 2.8, root = 2, vfx = "ancientroots", color = EMERALD,
		desc = "Raízes gigantes saem do chão em espiral e prendem todos na área." },
	ent = { name = "Coração da Floresta", shape = "circle", radius = 20, power = 2.2, heal = 0.20, vfx = "forestheart", color = rgb(150, 255, 150),
		desc = "Finca as raízes e solta uma onda que fere os inimigos e cura a equipe." },
	-- SECRET
	sylvanox = { name = "Eclipse do Santuário", shape = "area", radius = 22, hits = 4, interval = 0.4, power = 0.8, atkBuff = { amount = 0.25, duration = 8 }, vfx = "eclipse", color = SPORE,
		color2 = rgb(80, 40, 140), desc = "A sombra da Árvore-Santuário cobre a área e despeja luz; a equipe fica mais forte." },
}

-- Assinatura de uma espécie: pelo id exato ou pela família ("kit_3" → "kit").
function Signatures.forSpecies(speciesId: string)
	local s = Signatures.Info[speciesId]
	if s then
		return s, speciesId
	end
	local fam = speciesId:match("^(.-)_%d+$")
	if fam and Signatures.Info[fam] then
		return Signatures.Info[fam], fam
	end
	return nil
end

function Signatures.furyMax(rarity: string): number
	return Signatures.FuryMax[rarity] or 6
end

return Signatures

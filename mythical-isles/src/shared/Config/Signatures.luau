-- ATAQUES ASSINATURA: o PODER próprio de cada pet (as 192 espécies dos 5 mundos).
-- Cada família tem a sua Assinatura; cada variante de cor da família ganha um "tempero" diferente
-- (Signatures.Twists: gelo, veneno, faísca, flor...), então nenhum pet repete exatamente o poder de outro.
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
local CRYSTAL, ICE, AMETHYST, PRISM, RUBY, SAPPHIRE = rgb(150, 220, 255), rgb(190, 235, 255), rgb(190, 120, 255), rgb(255, 170, 240), rgb(255, 80, 100), rgb(80, 130, 255)
local AURORA, SKY, STORM, MIST, DUSK, MOON = rgb(140, 255, 210), rgb(170, 220, 255), rgb(150, 190, 255), rgb(210, 220, 240), rgb(150, 90, 220), rgb(220, 220, 255)
local STAR, NEBULA, ECLIPSE, SUN = rgb(255, 240, 160), rgb(200, 130, 255), rgb(130, 70, 220), rgb(255, 170, 60)

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
	-- ============================ MUNDO 2 — CRYSTAL HOLLOW ============================
	crystalkitten = { name = "Arranhão Cintilante", shape = "single", hits = 2, interval = 0.2, power = 0.75, critBonus = 0.15, vfx = "claw", color = CRYSTAL,
		desc = "Dois arranhões rápidos que deixam rastros de brilho." },
	crystalmouse = { name = "Faísca de Quartzo", shape = "single", power = 1.1, reveal = 50, vfx = "peck", color = CRYSTAL,
		desc = "Mordisca o alvo soltando faíscas e fareja tesouros por perto." },
	prismhopper = { name = "Salto Prismático", shape = "area", radius = 6, power = 0.9, heal = 0.04, vfx = "bloom", color = PRISM,
		desc = "Pula sobre o alvo; a luz refratada da queda cura a equipe." },
	shardmite = { name = "Casca de Estilhaços", shape = "circle", radius = 6, power = 0.9, taunt = 2, shield = { amount = 0.05, duration = 4 }, vfx = "shards", color = CRYSTAL,
		desc = "Eriça a casca de cristal: estilhaços em volta e um escudo leve." },
	crystalslime = { name = "Gota Cristalizada", shape = "area", radius = 7, power = 0.9, slow = { amount = 0.3, duration = 3 }, taunt = 2, vfx = "frost", color = ICE,
		desc = "Estoura numa poça que cristaliza os pés dos inimigos." },
	gempup = { name = "Mordida de Gema", shape = "single", dash = true, power = 1.6, critBonus = 0.1, vfx = "bite", color = AMETHYST,
		desc = "Avança e morde com dentes de gema." },
	geobeetle = { name = "Couraça Geode", shape = "team", radius = 22, shield = { amount = 0.12, duration = 5 }, vfx = "dome", color = CRYSTAL,
		desc = "O casco se abre como um geode e cobre a equipe de cristal." },
	glimmerbat = { name = "Grito Ultrassônico", shape = "cone", range = 18, angle = 45, power = 1.0, stun = 0.5, vfx = "hoot", color = AMETHYST,
		desc = "Um grito que faz os cristais vibrarem e atordoa quem está à frente." },
	crystalferret = { name = "Túnel de Cristal", shape = "single", dash = true, power = 1.8, reveal = 70, vfx = "ambush", color = CRYSTAL,
		desc = "Cava um túnel, sai debaixo do alvo e fareja baús escondidos." },
	crystalfox = { name = "Leque de Caudas Cristalinas", shape = "cone", range = 20, angle = 50, hits = 3, interval = 0.15, power = 0.55, vfx = "feathers", color = CRYSTAL,
		desc = "As caudas em leque disparam três rajadas de lascas." },
	geodeling = { name = "Geode Explosiva", shape = "circle", radius = 9, power = 1.2, stun = 0.8, taunt = 3, vfx = "shards", color = AMETHYST,
		desc = "Se fecha e explode em cristais que atordoam e atraem os ataques." },
	crystalwolf = { name = "Uivo de Cristal", shape = "multi", targets = 3, range = 32, power = 0.9, defDown = { amount = 0.25, duration = 5 }, vfx = "howl", color = ICE,
		desc = "Três lobos de cristal atacam e racham a defesa dos inimigos." },
	amethyststag = { name = "Galhada de Ametista", shape = "line", length = 24, width = 6, power = 1.3, root = 1.2, vfx = "prismbeam", color = AMETHYST,
		desc = "A galhada dispara um feixe violeta que prende os inimigos no caminho." },
	gemlynx = { name = "Bote Facetado", shape = "single", dash = true, power = 2.0, critBonus = 0.2, bleed = { power = 0.15, ticks = 3 }, vfx = "pounce", color = AMETHYST,
		desc = "Salto com garras de gema que cortam fundo." },
	prismcat = { name = "Raio Refratado", shape = "chain", chain = 2, bounce = 16, power = 1.1, chainPower = 0.7, vfx = "acorn", color = PRISM,
		desc = "Um raio de luz que se refrata e pula para mais dois inimigos." },
	crystaldragon = { name = "Sopro Cristalino", shape = "cone", range = 24, angle = 40, hits = 6, interval = 0.22, power = 0.55, slow = { amount = 0.3, duration = 3 }, vfx = "breath", color = ICE,
		desc = "Sopro de geada cristalina que deixa os inimigos lentos." },
	glassserpent = { name = "Espiral de Vidro", shape = "circle", radius = 12, hits = 3, interval = 0.35, power = 0.8, root = 1, vfx = "shards", color = ICE,
		desc = "Enrola-se e ergue espirais de vidro que prendem quem está perto." },
	prismpanther = { name = "Garra Prismática", shape = "single", hits = 3, interval = 0.15, power = 0.85, critBonus = 0.25, defDown = { amount = 0.3, duration = 5 }, vfx = "claw", color = PRISM,
		desc = "Três golpes de luz que quebram a defesa do alvo." },
	quartz_drake = { name = "Prisma de Quartzo", shape = "line", length = 28, width = 6, power = 2.0, mark = { bonus = 0.2, duration = 6 }, vfx = "prismbeam", color = PRISM,
		desc = "Feixe de arco-íris em linha que marca os atingidos." },
	rubygolem = { name = "Punho de Rubi", shape = "cone", range = 14, angle = 70, power = 1.8, stun = 1, taunt = 4, vfx = "quake", color = RUBY,
		desc = "Soca o chão: rachaduras vermelhas atordoam e todos olham para ele." },
	aurorafox = { name = "Aurora Curativa", shape = "team", radius = 28, heal = 0.18, atkBuff = { amount = 0.15, duration = 6 }, vfx = "nova", color = AURORA,
		desc = "Uma aurora desce sobre a equipe: cura e deixa todos mais fortes." },
	behemoth = { name = "Terremoto de Gemas", shape = "circle", radius = 16, power = 2.4, stun = 1.2, taunt = 4, vfx = "quake", color = AMETHYST,
		desc = "Pisa com tudo: o chão explode em gemas e todos ficam atordoados." },
	crystalgriffin = { name = "Tempestade de Estilhaços", shape = "area", radius = 16, hits = 6, interval = 0.2, power = 0.6, slow = { amount = 0.3, duration = 3 }, vfx = "meteors", color = ICE,
		desc = "Bate as asas e faz chover estilhaços de cristal." },
	echo_geode = { name = "Eco Ressonante", shape = "circle", radius = 10, grow = 5, hits = 3, interval = 0.35, power = 1.0, stun = 0.6, vfx = "vibration", color = AMETHYST,
		desc = "Ressoa três vezes: ondas de som cristalino que crescem e atordoam." },
	prismwyvern = { name = "Chuva Prismática", shape = "multi", targets = 4, range = 45, splash = 5, power = 0.9, vfx = "orbs", color = PRISM,
		desc = "Quatro esferas de arco-íris perseguem inimigos diferentes." },
	sapphiresentinel = { name = "Égide de Safira", shape = "team", radius = 28, shield = { amount = 0.3, duration = 6 }, taunt = 5, vfx = "fortress", color = SAPPHIRE,
		desc = "Ergue uma muralha de safira: escudo forte para a equipe." },
	lumivex = { name = "Supernova Cristalina", shape = "area", radius = 22, hits = 4, interval = 0.4, power = 0.9, mark = { bonus = 0.25, duration = 8 }, vfx = "nova", color = PRISM,
		desc = "Explode em luz pura quatro vezes; os atingidos ficam marcados." },

	-- ============================ MUNDO 3 — SKYBOUND KINGDOM ============================
	puffcloud = { name = "Chuvinha Revigorante", shape = "team", radius = 22, heal = 0.08, vfx = "bloom", color = SKY,
		desc = "Uma nuvenzinha chove sobre a equipe e cura." },
	galepup = { name = "Rajada Brincalhona", shape = "cone", range = 16, angle = 50, power = 1.0, knock = 6, vfx = "feathers", color = WIND,
		desc = "Late uma rajada de vento que empurra os inimigos." },
	zephyr_hawk = { name = "Mergulho do Zéfiro", shape = "single", dash = true, power = 2.0, critBonus = 0.2, vfx = "peck", color = SKY,
		desc = "Sobe alto e mergulha no alvo como uma flecha." },
	thunder_ram = { name = "Marrada Trovejante", shape = "line", length = 18, width = 6, dash = true, power = 1.5, stun = 1, taunt = 3, vfx = "thunder", color = STORM,
		desc = "Corre com os chifres carregados: raios caem em quem ficar no caminho." },
	aurora_griffin = { name = "Asas da Aurora", shape = "circle", radius = 14, power = 1.4, haste = 6, walk = 6, vfx = "winddance", color = AURORA,
		desc = "Bate as asas coloridas: a equipe ataca mais rápido e o dono corre mais." },
	skyborn_seraph = { name = "Bênção Celeste", shape = "team", radius = 30, heal = 0.22, shield = { amount = 0.2, duration = 6 }, atkBuff = { amount = 0.2, duration = 8 }, vfx = "nova", color = GOLD,
		desc = "Abre as seis asas: cura, protege e fortalece toda a equipe." },

	-- ============================ MUNDO 4 — WHISPERING WILDS ============================
	mistmoth = { name = "Pó de Névoa", shape = "area", radius = 7, power = 0.8, slow = { amount = 0.25, duration = 3 }, reveal = 50, vfx = "spores", color = MIST,
		desc = "Solta pó de névoa que deixa os inimigos lentos e revela tesouros." },
	hollow_hare = { name = "Pulo Sombrio", shape = "area", radius = 6, power = 0.9, heal = 0.05, vfx = "shadow", color = DUSK,
		desc = "Some na sombra e cai sobre o alvo; a equipe se recupera." },
	fernsnake = { name = "Bote Venenoso", shape = "single", dash = true, power = 1.4, bleed = { power = 0.2, ticks = 4 }, vfx = "bite", color = rgb(150, 230, 90),
		desc = "Bote rápido com presas que envenenam." },
	dusk_lynx = { name = "Garras do Crepúsculo", shape = "single", hits = 3, interval = 0.15, power = 0.8, defDown = { amount = 0.3, duration = 5 }, vfx = "shadow", color = DUSK,
		desc = "Ataca das sombras três vezes e quebra a defesa." },
	elder_owl = { name = "Sabedoria Ancestral", shape = "team", radius = 28, heal = 0.12, atkBuff = { amount = 0.2, duration = 6 }, reveal = 80, vfx = "nova", color = MOON,
		desc = "Pia uma canção antiga: a equipe se cura, fica mais forte e vê tesouros." },
	moonveil_kitsune = { name = "Véu Lunar", shape = "area", radius = 16, hits = 5, interval = 0.3, power = 0.7, mark = { bonus = 0.25, duration = 6 }, vfx = "eclipse", color = MOON,
		color2 = rgb(60, 40, 110), desc = "Cobre a área com um véu de lua: cinco ondas de luz que marcam os inimigos." },
	whisper_shade = { name = "Sussurro do Vazio", shape = "multi", targets = 5, range = 45, power = 1.2, bleed = { power = 0.2, ticks = 3 }, vfx = "shadow", color = DUSK,
		desc = "Sussurra para cinco inimigos ao mesmo tempo, que sangram de medo." },

	-- ============================ MUNDO 5 — ASTRAL SANCTUARY ============================
	stardust_sprite = { name = "Poeira de Estrelas", shape = "team", radius = 22, heal = 0.07, haste = 3, vfx = "nova", color = STAR,
		desc = "Espalha poeira de estrelas: cura e acelera a equipe." },
	nebula_pup = { name = "Faro Nebuloso", shape = "single", dash = true, power = 1.3, reveal = 70, vfx = "bite", color = NEBULA,
		desc = "Pula no alvo e fareja tesouros pelo cheiro das estrelas." },
	comet_serpent = { name = "Rabo de Cometa", shape = "line", length = 24, width = 5, dash = true, power = 1.6, vfx = "stampede", color = STAR,
		desc = "Dispara como um cometa, deixando um rastro de fogo estelar." },
	orbit_golem = { name = "Órbita Gravitacional", shape = "circle", radius = 12, power = 1.2, pull = 5, taunt = 4, vfx = "vibration", color = NEBULA,
		desc = "Cria gravidade: puxa os inimigos para perto e atrai os ataques." },
	astral_lion = { name = "Rugido Estelar", shape = "circle", radius = 16, power = 2.0, stun = 1, vfx = "roar", color = STAR,
		desc = "Ruge como uma estrela nascendo e atordoa tudo em volta." },
	eclipse_drake = { name = "Sopro do Eclipse", shape = "cone", range = 26, angle = 40, hits = 6, interval = 0.22, power = 0.65, defDown = { amount = 0.3, duration = 5 }, vfx = "breath", color = ECLIPSE,
		desc = "Sopro de luz negra que corrói a defesa dos inimigos." },
	void_seraph = { name = "Fenda do Vazio", shape = "tornado", radius = 8, hits = 10, interval = 0.45, power = 0.75, pull = 3, vfx = "tornado", color = ECLIPSE,
		desc = "Abre uma fenda que anda até o alvo engolindo os inimigos." },
	celestara = { name = "Constelação Guardiã", shape = "team", radius = 34, heal = 0.25, shield = { amount = 0.25, duration = 8 }, atkBuff = { amount = 0.25, duration = 8 }, vfx = "nova", color = STAR,
		desc = "Desenha uma constelação sobre a equipe: cura total, escudo e força." },
	solaris_leviathan = { name = "Erupção Solar", shape = "area", radius = 22, hits = 5, interval = 0.3, power = 1.2, stun = 1, taunt = 5, vfx = "meteors", color = SUN,
		desc = "Cinco erupções de sol caem sobre a área e atordoam." },

	sylvanox = { name = "Eclipse do Santuário", shape = "area", radius = 22, hits = 4, interval = 0.4, power = 0.8, atkBuff = { amount = 0.25, duration = 8 }, vfx = "eclipse", color = SPORE,
		color2 = rgb(80, 40, 140), desc = "A sombra da Árvore-Santuário cobre a área e despeja luz; a equipe fica mais forte." },
}

-- TEMPEROS DAS VARIANTES: a variante 1 de cada família usa a Assinatura pura; as outras ganham um efeito
-- extra diferente cada (nome "Assinatura · Tempero"), sem repetir dentro da família.
Signatures.Twists = {
	{ tag = "Gelo", color = rgb(170, 225, 255), text = "deixa os inimigos lentos", apply = function(d)
		d.slow = { amount = 0.3, duration = 2.5 }
	end, field = "slow" },
	{ tag = "Veneno", color = rgb(160, 230, 90), text = "envenena (dano por 3 s)", apply = function(d)
		d.bleed = { power = 0.12, ticks = 3 }
	end, field = "bleed" },
	{ tag = "Faísca", color = rgb(255, 230, 120), text = "+15% de chance de crítico", apply = function(d)
		d.critBonus = (d.critBonus or 0) + 0.15
	end, field = "critBonus" },
	{ tag = "Flor", color = rgb(255, 160, 200), text = "cura um pouco a equipe", team = true, apply = function(d)
		d.heal = 0.03
	end, field = "heal" },
	{ tag = "Escudo", color = rgb(150, 210, 255), text = "dá um escudo leve à equipe", team = true, apply = function(d)
		d.shield = { amount = 0.05, duration = 4 }
	end, field = "shield" },
	{ tag = "Ventania", color = rgb(200, 255, 230), text = "empurra os inimigos", apply = function(d)
		d.knock = 4
	end, field = "knock" },
	{ tag = "Marca", color = rgb(255, 200, 120), text = "marca o alvo (+12% de dano recebido)", apply = function(d)
		d.mark = { bonus = 0.12, duration = 5 }
	end, field = "mark" },
	{ tag = "Pressa", color = rgb(190, 255, 200), text = "a equipe ataca mais rápido por 3 s", team = true, apply = function(d)
		d.haste = 3
	end, field = "haste" },
	{ tag = "Força", color = rgb(255, 140, 90), text = "+12% de dano", apply = function(d)
		d.power = (d.power or 0) * 1.12
	end, field = "power" },
	{ tag = "Trovão", color = rgb(150, 190, 255), text = "atordoa por 0,5 s", apply = function(d)
		d.stun = 0.5
	end, field = "stun" },
	{ tag = "Raiz", color = rgb(150, 230, 110), text = "prende por 0,8 s", apply = function(d)
		d.root = 0.8
	end, field = "root" },
	{ tag = "Brilho", color = rgb(255, 245, 190), text = "a equipe fica 8% mais forte por 5 s", team = true, apply = function(d)
		d.atkBuff = { amount = 0.08, duration = 5 }
	end, field = "atkBuff" },
}

-- Família e número da variante ("crystalfox_7" → "crystalfox", 7). Espécies únicas: (id, 1).
local function familyOf(speciesId: string): (string, number)
	local fam, n = speciesId:match("^(.-)_(%d+)$")
	if fam and Signatures.Info[fam] then
		return fam, tonumber(n) or 1
	end
	return speciesId, 1
end

-- Tempero da variante `index` (2, 3, ...) de uma Assinatura base: o primeiro da lista, a partir de um ponto
-- que depende do índice, que a base ainda não tem (e, em poderes de equipe, só os que valem na equipe).
function Signatures.twistFor(base, index: number)
	if index <= 1 then
		return nil
	end
	local list = Signatures.Twists
	local usable = {}
	for _, tw in ipairs(list) do
		local conflict = base[tw.field] ~= nil and tw.field ~= "power" and tw.field ~= "critBonus"
		if not conflict and (base.shape ~= "team" or tw.team) then
			table.insert(usable, tw)
		end
	end
	return usable[(index - 2) % #usable + 1]
end

local cache = {}

-- Assinatura (PODER) de uma espécie: pelo id exato ou pela família com o tempero da variante.
function Signatures.forSpecies(speciesId: string)
	local direct = Signatures.Info[speciesId]
	if direct then
		return direct, speciesId
	end
	local fam, index = familyOf(speciesId)
	local base = Signatures.Info[fam]
	if not base then
		return nil
	end
	if index <= 1 then
		return base, fam
	end
	local hit = cache[speciesId]
	if hit then
		return hit, fam
	end
	local tw = Signatures.twistFor(base, index)
	local d = table.clone(base)
	tw.apply(d)
	d.name = base.name .. " · " .. tw.tag
	d.desc = base.desc .. " Tempero " .. tw.tag .. ": " .. tw.text .. "."
	local a, b = base.color, tw.color
	d.color = Color3.new(a.R + (b.R - a.R) * 0.45, a.G + (b.G - a.G) * 0.45, a.B + (b.B - a.B) * 0.45)
	d.twist = tw.tag
	cache[speciesId] = d
	return d, fam
end

function Signatures.furyMax(rarity: string): number
	return Signatures.FuryMax[rarity] or 6
end

return Signatures

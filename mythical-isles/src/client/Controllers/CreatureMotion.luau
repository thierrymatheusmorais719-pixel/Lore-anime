-- Animação procedural dos pets de malha (PetMesh), própria de cada anatomia:
--   quadrúpedes: passo (trote em diagonal) e corrida (galope com a coluna flexionando), pulo, ataque
--     (bote/mordida nos canídeos, patada nos felinos, cabeçada/empinada nos cervídeos e caprinos,
--     pisada nos pesados); lebres/esquilos/sapos andam aos saltos
--   aves/morcegos/mariposas: voo com batida de asas, pernas recolhidas, bicada/rasante no ataque
--   serpentes: onda que percorre o corpo, bote com a boca aberta
--   insetos: marcha em tripé; bípedes (golens, ents, cogumelos, panda): passada com braços opostos,
--     golpe com os dois braços; espíritos e slimes: flutuar/quicar
-- Em todos: respiração, piscar, orelhas, cauda abanando, olhar para o dono quando ele chega perto
-- (reação), comemoração (vitória sobre boss) e desmaio (pet nocauteado).
-- Parados, fazem COISAS DE BICHO de vez em quando (cada anatomia tem as suas): sentar, espreguiçar,
-- coçar a orelha, chacoalhar, bocejar, farejar, chamar para brincar; aves arrumam as penas e abrem as
-- asas; bípedes acenam, se espreguiçam e dançam; serpentes se erguem e põem a língua; slimes e
-- espíritos giram e se achatam. Depois de muito tempo parados, DORMEM (com "Zzz"). Ao levar dano dão um
-- tranco; ao subir de nível fazem uma festinha; o ataque Assinatura tem pose própria (empinar e rugir,
-- braços para o alto, asas abertas).
--
-- Juntas pelo nome (PetMesh/PetAnatomy): Body, Neck, Head, Jaw, Ear*, Lid*, Leg??/Knee??/Foot??,
-- LegL/LegR, KneeL/KneeR, ArmL/ArmR, ElbowL/ElbowR, Wing*, Tail/TailSegN/TailN, SegN, TrunkN, Orbit*.

local Players = game:GetService("Players")

local CreatureMotion = {}
-- chamado no instante em que um golpe sai (Fx desenha o arco de corte); (entry, model)
CreatureMotion.onStrike = nil :: ((any, Model) -> ())?

local celebrateUntil: { [number]: number } = {}

-- Comemoração dos pets de um jogador (ex.: boss derrotado).
function CreatureMotion.celebrate(userId: number, duration: number?)
	celebrateUntil[userId] = os.clock() + (duration or 3.5)
end

local function classify(name: string)
	if name == "Body" then
		return "body"
	elseif name == "Neck" then
		return "neck"
	elseif name == "Head" then
		return "head"
	elseif name == "Jaw" then
		return "jaw"
	elseif name:sub(1, 3) == "Ear" then
		return "ear"
	elseif name:sub(1, 3) == "Lid" then
		return "lid"
	elseif name:match("^Leg[FMB][LR]$") then
		return "legq"
	elseif name:match("^Knee[FMB][LR]$") then
		return "kneeq"
	elseif name:match("^Foot[FMB][LR]$") then
		return "footq"
	elseif name == "LegL" or name == "LegR" then
		return "leg2"
	elseif name == "KneeL" or name == "KneeR" then
		return "knee2"
	elseif name == "ArmL" or name == "ArmR" then
		return "arm"
	elseif name == "ElbowL" or name == "ElbowR" then
		return "elbow"
	elseif name:sub(1, 4) == "Wing" then
		return "wing"
	elseif name:match("^TailSeg%d") then
		return "tailseg"
	elseif name:match("^Tail%d") then
		return "tailmulti"
	elseif name:sub(1, 4) == "Tail" then
		return "tail"
	elseif name:match("^Seg%d") then
		return "seg"
	elseif name:match("^Trunk%d") then
		return "trunk"
	elseif name:sub(1, 5) == "Orbit" then
		return "orbit"
	end
	return nil
end

-- Fases das patas: trote (diagonais juntas) e galope (sequência rotatória).
local TROT = { FL = 0, BR = 0, FR = math.pi, BL = math.pi, ML = math.pi, MR = 0 }
local GALLOP = { FL = 0, FR = 0.45 * math.pi, BL = 1.1 * math.pi, BR = 1.55 * math.pi }
local TRIPOD = { FL = 0, MR = 0, BL = 0, FR = math.pi, ML = math.pi, BR = math.pi }

function CreatureMotion.prepare(entry)
	local model = entry.model
	entry.meshPet = true
	entry.source = model.Parent and model.Parent:IsA("Model") and model.Parent or model
	entry.gait = model:GetAttribute("Gait") or "quad"
	entry.anatomy = model:GetAttribute("Anatomy") or ""
	entry.heavy = model:GetAttribute("Heavy") == true
	entry.flies = model:GetAttribute("Flies") == true
	entry.hover = model:GetAttribute("Hover") or 1
	entry.phase = math.random() * 6
	entry.jumpT = -10
	entry.lastOwnerAir = false
	entry.mjoints = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name ~= "Fixed" then
			local kind = classify(d.Name)
			if kind then
				local tag = d.Name:match("([FMB][LR])$") or ""
				local last = d.Name:sub(-1)
				local blinkVec = kind == "lid" and d.Part1 and d.Part1:GetAttribute("BlinkVec") or nil
				table.insert(entry.mjoints, {
					motor = d, kind = kind, name = d.Name, tag = tag, side = (last == "L") and -1 or ((last == "R") and 1 or 0),
					front = tag:sub(1, 1) == "F", hind = tag:sub(1, 1) == "B", idx = tonumber(d.Name:match("(%d+)$")) or 1, blink = blinkVec,
				})
			end
		end
	end
	-- cadeia de juntas (pai antes do filho) para saber onde o corpo fica depois da pose (ver groundLift)
	local chain = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 and d.Part1:IsA("BasePart") then
			-- só o corpo de apoio conta para o chão (cauda, asas e enfeites podem encostar/ficar por cima)
			local n = d.Part1.Name
			local support = n == "Torso" or n == "Neck" or n == "Head" or n:match("^Upper") or n:match("^Lower") or n:match("^Foot")
				or n:match("^Thigh") or n:match("^Shin") or n:match("^Arm") or n:match("^Forearm") or n:match("^Hand") or n:match("^Seg%d") or n:match("^Leg")
			local depth, p0 = 0, d.Part0
			while p0 and p0 ~= model.PrimaryPart and depth < 40 do
				local m = p0:FindFirstChildOfClass("Motor6D")
				p0 = m and m.Part0 or nil
				depth += 1
			end
			table.insert(chain, { motor = d, depth = depth, half = d.Part1.Size / 2, support = support ~= nil and support ~= false,
				core = n == "Torso" or n == "Neck" or n == "Head" or n:match("^Seg%d") ~= nil })
		end
	end
	table.sort(chain, function(a, b)
		return a.depth < b.depth
	end)
	entry.chain = chain
	entry.restLow = CreatureMotion.lowestPoint(entry, true)
end

-- Ponto mais baixo do pet em relação à raiz, com as juntas na pose atual (ou em repouso). Cada parte é
-- tratada como o elipsoide inscrito na caixa dela: o ponto mais baixo de um elipsoide girado é exato e
-- barato (sem olhar as faces). Usado para que sentar/deitar/coçar não afundem o pet no chão.
-- coreOnly: só tronco/cabeça (deitado, as patas dobradas ficam por baixo do corpo)
function CreatureMotion.lowestPoint(entry, rest: boolean?, coreOnly: boolean?): number
	local world = {}
	local low = math.huge
	local rootPart = entry.model.PrimaryPart
	for _, c in ipairs(entry.chain or {}) do
		local m = c.motor
		local p0 = (m.Part0 == rootPart) and CFrame.identity or world[m.Part0]
		if p0 then
			local cf = p0 * m.C0 * (rest and CFrame.identity or m.Transform) * m.C1:Inverse()
			world[m.Part1] = cf
			if c.support and (not coreOnly or c.core) then
				local h = c.half
				local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
				local drop = math.sqrt((r.Y * h.X) ^ 2 + (u.Y * h.Y) ^ 2 + (l.Y * h.Z) ^ 2)
				low = math.min(low, cf.Position.Y - drop)
			end
		end
	end
	return low
end

local function ownerInfo(entry)
	local uid = entry.source:GetAttribute("Owner")
	local plr = uid and Players:GetPlayerByUserId(uid)
	local char = plr and plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return uid, root, hum
end

local A = CFrame.Angles

-------------------------------------------------------------------------------
-- COMPORTAMENTOS OCIOSOS (parado), sono, tranco ao levar dano e festa de nível
-------------------------------------------------------------------------------

local ACTS = {
	quad = { { "sit", 5 }, { "stretch", 2.6 }, { "scratch", 2.2 }, { "shake", 1.4 }, { "yawn", 2.0 }, { "sniff", 2.8 }, { "playbow", 2.0 } },
	hop = { { "beg", 3.2 }, { "groom", 2.6 }, { "yawn", 2.0 }, { "sniff", 2.4 }, { "shake", 1.2 } },
	bird = { { "preen", 2.6 }, { "wingstretch", 2.2 }, { "peck", 2.0 }, { "shake", 1.2 } },
	biped = { { "wave", 2.6 }, { "armstretch", 2.8 }, { "yawn", 2.0 }, { "dance", 3.0 } },
	slither = { { "rise", 3.0 }, { "tongue", 1.6 }, { "sway", 3.0 } },
	insect = { { "clean", 2.4 }, { "wiggle", 1.8 } },
	float = { { "spin", 1.8 }, { "squish", 1.6 } },
	bounce = { { "spin", 1.8 }, { "squish", 1.6 } },
}
-- Comportamentos PRÓPRIOS de cada anatomia (somados aos do jeito de andar). Quadrúpedes que voam (dragões)
-- trocam os de chão pelos de voo.
local ANATOMY_ACTS = {
	wolf = { { "howl", 3.0 } }, canine = { { "howl", 3.0 }, { "tailchase", 2.4 } }, pup = { { "tailchase", 2.4 }, { "pounce", 1.6 } },
	fox = { { "pounce", 1.6 }, { "tailchase", 2.4 } },
	feline = { { "lickpaw", 2.6 }, { "pounce", 1.6 } }, lynx = { { "lickpaw", 2.6 }, { "pounce", 1.6 } }, lion = { { "roar", 2.2 }, { "lickpaw", 2.6 } },
	griffin = { { "roar", 2.2 }, { "wingstretch", 2.2 } },
	cervid = { { "graze", 3.2 }, { "headtoss", 1.6 } }, caprine = { { "graze", 3.2 }, { "headtoss", 1.6 } }, bushgoat = { { "graze", 3.2 }, { "headtoss", 1.6 } },
	heavy = { { "stomp", 1.8 }, { "graze", 3.2 } }, mammoth = { { "trumpet", 2.4 }, { "stomp", 1.8 } }, chelonian = { { "hide", 3.0 } },
	rodent = { { "beg", 3.2 }, { "groom", 2.6 } }, mustelid = { { "beg", 3.2 }, { "tailchase", 2.4 } }, reptile = { { "tongue", 1.6 } },
	lagomorph = { { "thump", 1.6 } }, squirrel = { { "groom", 2.6 } }, amphibian = { { "croak", 2.0 }, { "tongue", 1.6 } },
	avian = { { "headturn", 2.4 } }, bat = { { "barrelroll", 1.6 } }, moth = { { "flutter", 1.8 } },
	golem = { { "flex", 2.4 }, { "stomp", 1.8 } }, treant = { { "sway", 3.0 }, { "flex", 2.4 } }, shroom = { { "spin", 1.8 } },
	leafpanda = { { "rollover", 2.6 }, { "flex", 2.4 } }, biped = { { "flex", 2.4 } },
	slime = { { "jumpjoy", 1.6 } }, floater = { { "barrelroll", 1.6 } }, serpent = { { "coilup", 2.6 } }, insect = { { "flutter", 1.8 } },
}
local FLYING_QUAD = { { "barrelroll", 1.6 }, { "roar", 2.2 }, { "wingstretch", 2.2 }, { "headturn", 2.4 } }
CreatureMotion.Acts = ACTS
CreatureMotion.AnatomyActs = ANATOMY_ACTS

-- Lista de comportamentos de um pet (jeito de andar + anatomia).
function CreatureMotion.actsFor(gait: string, anatomy: string, flies: boolean): { any }
	local base = (flies and gait == "quad") and FLYING_QUAD or (ACTS[gait] or ACTS.quad)
	local list = table.clone(base)
	for _, a in ipairs(ANATOMY_ACTS[anatomy] or {}) do
		local dup = false
		for _, b in ipairs(list) do
			if b[1] == a[1] then
				dup = true
			end
		end
		if not dup then
			table.insert(list, a)
		end
	end
	return list
end
CreatureMotion.SleepAfter = 28 -- s parado até dormir

-- entra/sai suave (0.3 s) dentro da duração do comportamento
local function envelope(u: number, dur: number): number
	local a = math.clamp(u / 0.3, 0, 1)
	local b = math.clamp((dur - u) / 0.3, 0, 1)
	local e = math.min(a, b)
	return e * e * (3 - 2 * e)
end

-- (prévias e testes) força um comportamento agora: "sit", "sleep", "hurt", "levelup", "signature"...
function CreatureMotion.forceAct(entry, name: string, clock: number?)
	local c = clock or os.clock()
	if name == "sleep" then
		entry.idleFor = CreatureMotion.SleepAfter + 1
		entry.forceSleep = true
		return
	elseif name == "hurt" then
		entry.hurtAt = c
		return
	elseif name == "levelup" then
		entry.partyAt = c
		return
	end
	local dur = 2
	for _, list in ipairs({ ACTS, ANATOMY_ACTS, { FLYING_QUAD } }) do
		for _, l in pairs(list) do
			for _, a in ipairs(l) do
				if a[1] == name then
					dur = a[2]
				end
			end
		end
	end
	entry.act = { name = name, t0 = c, dur = dur }
	entry.idleFor = 10
end

-- Escolhe e avança o comportamento ocioso. Devolve (nome, intensidade 0..1, tempo dentro dele, dormindo).
local function idleBehaviour(entry, idle: boolean, dt: number, clock: number)
	if not idle then
		entry.idleFor, entry.act, entry.forceSleep = 0, nil, nil
		entry.nextActAt = 3 + math.random() * 4
		return nil, 0, 0, false
	end
	entry.idleFor = (entry.idleFor or 0) + dt
	local canSleep = not entry.flies and entry.gait ~= "float" and entry.gait ~= "bounce"
	local asleep = canSleep and (entry.forceSleep or entry.idleFor >= CreatureMotion.SleepAfter)
	if asleep then
		entry.act = nil
		return nil, 0, 0, true
	end
	local act = entry.act
	if act and clock - act.t0 >= act.dur then
		entry.act, act = nil, nil
		entry.nextActAt = entry.idleFor + 4 + math.random() * 6
	end
	if not act and entry.idleFor >= (entry.nextActAt or 4) then
		local list = entry.acts or CreatureMotion.actsFor(entry.gait, entry.anatomy, entry.flies)
		entry.acts = list
		local pick = list[math.random(1, #list)]
		if entry.lastAct == pick[1] and #list > 1 then
			pick = list[(table.find(list, pick) or 1) % #list + 1]
		end
		entry.lastAct = pick[1]
		act = { name = pick[1], t0 = clock, dur = pick[2] }
		entry.act = act
	end
	if not act then
		return nil, 0, 0, false
	end
	local u = clock - act.t0
	return act.name, envelope(u, act.dur), u, false
end

-- "Zzz" acima da cabeça enquanto dorme (só no cliente; some ao acordar)
local function setSnore(entry, on: boolean)
	if on == (entry.snore ~= nil) then
		return
	end
	if not on then
		entry.snore:Destroy()
		entry.snore = nil
		return
	end
	local head = entry.model:FindFirstChild("Head") or entry.model:FindFirstChild("Torso") or entry.root
	local bb = Instance.new("BillboardGui")
	bb.Name = "Snore"
	bb.Size = UDim2.fromOffset(60, 40)
	bb.StudsOffset = Vector3.new(0.6, 1.4, 0)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Name = "Z"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "z Z z"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(235, 240, 255)
	label.TextStrokeTransparency = 0.3
	label.Parent = bb
	bb.Adornee = head
	bb.Parent = entry.model
	entry.snore = bb
end

-- Pose extra (somada às poses de andar/atacar) do comportamento/estado atual. Ângulos em radianos.
-- Convenções (eixos do modelo, frente = −Z): pitch > 0 ergue a frente; perna > 0 vai para a frente.
local function extraPose(entry, act: string?, e: number, u: number, sleep: number, hurt: number, party: number, sig: number, tt: number)
	local P = {}
	local gait = entry.gait
	local function add(k, v)
		P[k] = (P[k] or 0) + v
	end
	if act and e > 0 then
		if act == "sit" then
			add("bodyPitch", 0.42 * e)
			add("bodyY", -0.16 * e)
			add("legF", -0.42 * e)
			add("legB", 1.25 * e)
			add("kneeB", -1.9 * e)
			add("footB", 0.7 * e)
			add("neck", -0.2 * e)
			add("tailLift", -0.35 * e)
			add("wag", 0.4 * e)
		elseif act == "stretch" or act == "playbow" then
			local bow = act == "playbow" and (0.8 + 0.2 * math.sin(u * 10)) or 1
			add("bodyPitch", -0.4 * e * bow)
			add("bodyY", -0.1 * e)
			add("legF", 0.95 * e)
			add("kneeF", 0.35 * e)
			add("legB", -0.15 * e)
			add("neck", 0.35 * e)
			add("jaw", act == "stretch" and 0.4 * e * math.max(0, math.sin(u * 2)) or 0)
			add("tailLift", 0.45 * e)
			add("wag", act == "playbow" and 1.2 * e or 0)
		elseif act == "scratch" then
			-- senta de lado e coça a orelha com a pata de trás
			add("bodyPitch", 0.14 * e)
			add("bodyRoll", 0.16 * e)
			add("bodyY", -0.12 * e)
			add("legB", 0.5 * e)
			add("kneeB", -0.9 * e)
			add("headRoll", 0.45 * e)
			add("neckYaw", 0.45 * e)
			add("neck", -0.15 * e)
			P.scratch = e
			add("lid", 0.6 * e)
		elseif act == "shake" then
			local w = math.sin(u * 32) * e
			add("bodyRoll", w * 0.22)
			add("headRoll", -w * 0.4)
			add("ear", w * 0.6)
			add("wing", math.abs(w) * 0.4)
		elseif act == "yawn" then
			local y = math.sin(math.clamp(u / 1.7, 0, 1) * math.pi) * e
			add("jaw", 0.75 * y)
			add("neck", 0.35 * y)
			add("lid", 0.85 * y)
			add("ear", -0.3 * y)
			add("arm", -0.5 * y)
		elseif act == "sniff" then
			add("neck", -0.55 * e)
			add("headYaw", math.sin(u * 3) * 0.35 * e)
			add("jaw", math.max(0, math.sin(u * 18)) * 0.06 * e)
			add("ear", 0.15 * e)
		elseif act == "beg" then
			-- coelho de pé nas patas de trás, patinhas da frente para cima
			add("bodyPitch", 0.95 * e)
			add("bodyY", 0.05 * e)
			add("legF", -1.0 * e)
			add("kneeF", 0.9 * e)
			add("legB", 0.9 * e)
			add("kneeB", -1.4 * e)
			add("neck", -0.55 * e)
			add("ear", 0.25 * e)
		elseif act == "groom" then
			add("bodyPitch", 0.55 * e)
			add("legF", -0.2 * e + math.sin(u * 9) * 0.35 * e)
			add("kneeF", 1.1 * e)
			add("legB", 0.7 * e)
			add("kneeB", -1.1 * e)
			add("neck", -0.5 * e)
			add("headRoll", math.sin(u * 4.5) * 0.2 * e)
			add("lid", 0.5 * e)
		elseif act == "preen" then
			-- vira a cabeça para trás e "mordisca" as penas
			add("neckYaw", 1.25 * e)
			add("headYaw", 0.6 * e)
			add("head", (-0.3 + math.max(0, math.sin(u * 12)) * 0.2) * e)
			add("wing", 0.25 * e)
		elseif act == "wingstretch" then
			add("wing", (1.0 + math.sin(u * 2.5) * 0.25) * e)
			add("neck", 0.3 * e)
			add("tailLift", 0.3 * e)
		elseif act == "peck" then
			add("bodyPitch", -0.25 * e)
			add("neck", (-0.8 + math.max(0, math.sin(u * 7)) * 0.6) * e)
		elseif act == "wave" then
			P.armR = (P.armR or 0) - 2.7 * e
			P.armRz = (P.armRz or 0) + (0.35 + math.sin(u * 9) * 0.35) * e
			add("headRoll", 0.15 * e)
			add("headYaw", -0.25 * e)
		elseif act == "armstretch" then
			add("arm", -2.9 * e)
			P.armZ = (P.armZ or 0) + 0.25 * e
			add("bodyPitch", 0.1 * e)
			add("neck", 0.4 * e)
			add("jaw", 0.5 * e * math.max(0, math.sin(u * 1.4)))
		elseif act == "dance" then
			local b = math.sin(u * 8)
			add("bodyRoll", b * 0.18 * e)
			add("bodyY", math.abs(b) * 0.08 * e)
			P.armL = (P.armL or 0) + (-1.2 + b * 0.8) * e
			P.armR = (P.armR or 0) + (-1.2 - b * 0.8) * e
			add("headRoll", -b * 0.2 * e)
			add("leg2", b * 0.3 * e)
		elseif act == "rise" then
			add("rise", 0.9 * e)
			add("headYaw", math.sin(u * 1.6) * 0.5 * e)
		elseif act == "tongue" then
			add("jaw", math.max(0, math.sin(u * 22)) * 0.35 * e)
			add("rise", 0.35 * e)
		elseif act == "sway" then
			add("rise", 0.5 * e)
			add("coil", math.sin(u * 2.2) * 0.6 * e)
		elseif act == "clean" then
			add("neck", -0.4 * e)
			add("headRoll", math.sin(u * 7) * 0.25 * e)
			add("legF", math.sin(u * 14) * 0.4 * e)
		elseif act == "wiggle" then
			add("bodyRoll", math.sin(u * 18) * 0.12 * e)
			add("bodyY", -0.05 * e)
			add("legF", math.sin(u * 18) * 0.3 * e)
			add("ear", math.sin(u * 24) * 0.5 * e)
		elseif act == "spin" then
			add("bodyYaw", math.pi * 2 * math.clamp((u - 0.2) / 1.4, 0, 1) * (e > 0 and 1 or 0))
			add("bodyY", math.sin(math.clamp(u / 1.6, 0, 1) * math.pi) * 0.4)
			add("ear", 0.5 * e) -- folhas/orelhas abertas pelo giro
		elseif act == "squish" then
			local q = math.sin(u * 7) * e
			add("bodyY", -math.abs(q) * 0.15)
			add("bodyPitch", q * 0.12)
			add("ear", -math.abs(q) * 0.6)
		-- próprios das anatomias -------------------------------------------------------------------
		elseif act == "howl" then
			-- senta e uiva para o alto, focinho para cima, boca abrindo e fechando devagar
			add("bodyPitch", 0.35 * e)
			add("bodyY", -0.1 * e)
			add("legB", 0.9 * e)
			add("kneeB", -1.4 * e)
			add("neck", 0.95 * e)
			add("head", 0.3 * e)
			add("jaw", (0.35 + math.sin(u * 3) * 0.15) * e)
			add("ear", -0.3 * e)
			add("tailLift", -0.3 * e)
		elseif act == "tailchase" then
			-- corre atrás do rabo: gira no lugar com a cabeça virada para trás
			add("bodyYaw", u * 7 * (e > 0.05 and 1 or 0) % (math.pi * 2))
			add("neckYaw", 0.9 * e)
			add("headYaw", 0.4 * e)
			add("wag", 1.5 * e)
			add("bodyY", math.abs(math.sin(u * 14)) * 0.04 * e)
		elseif act == "pounce" then
			-- agacha, rebola e dá o bote para a frente
			local k = math.clamp((u - 0.9) / 0.4, 0, 1)
			local crouch = (1 - k) * e
			add("bodyPitch", (-0.25 * crouch) + 0.3 * math.sin(k * math.pi) * e)
			add("bodyY", -0.12 * crouch + math.sin(k * math.pi) * 0.25 * e)
			add("bodyRoll", math.sin(u * 16) * 0.05 * crouch)
			add("legF", (0.5 * crouch) + 0.8 * math.sin(k * math.pi) * e)
			add("legB", -0.5 * math.sin(k * math.pi) * e)
			add("ear", 0.25 * e)
			add("tailLift", 0.3 * e)
		elseif act == "lickpaw" then
			-- senta, levanta a pata da frente e lambe
			add("bodyPitch", 0.3 * e)
			add("bodyY", -0.08 * e)
			add("legB", 0.9 * e)
			add("kneeB", -1.4 * e)
			P.pawR = (P.pawR or 0) + 1.1 * e
			add("neck", -0.35 * e)
			add("neckYaw", -0.3 * e)
			add("jaw", math.max(0, math.sin(u * 10)) * 0.2 * e)
			add("lid", 0.5 * e)
		elseif act == "roar" then
			add("bodyPitch", 0.2 * e)
			add("legF", -0.15 * e)
			add("neck", 0.45 * e)
			add("jaw", 0.85 * e * math.min(1, u * 3))
			add("headRoll", math.sin(u * 30) * 0.05 * e)
			add("wing", 0.9 * e)
			add("tailLift", 0.5 * e)
			add("ear", -0.4 * e)
		elseif act == "graze" then
			-- abaixa a cabeça até o chão e mastiga
			add("neck", -1.6 * e)
			add("head", -0.45 * e)
			add("bodyPitch", -0.1 * e)
			add("legF", 0.18 * e)
			add("jaw", math.max(0, math.sin(u * 8)) * 0.18 * e)
			add("ear", 0.15 * math.sin(u * 2) * e)
			add("wag", 0.3 * e)
		elseif act == "headtoss" then
			add("neck", math.sin(u * 7) * 0.45 * e)
			add("headRoll", math.sin(u * 7 + 1) * 0.35 * e)
			add("ear", math.sin(u * 14) * 0.4 * e)
		elseif act == "stomp" then
			-- levanta a pata da frente e pisa forte
			local k = math.sin(math.clamp(u / 1.2, 0, 1) * math.pi)
			P.pawR = (P.pawR or 0) + 1.0 * k * e
			add("bodyPitch", 0.12 * k * e)
			add("bodyRoll", -0.06 * k * e)
			add("arm", -1.0 * k * e)
			add("neck", 0.2 * k * e)
		elseif act == "trumpet" then
			-- mamute ergue a tromba e barra
			add("trunk", -0.75 * e)
			add("neck", 0.45 * e)
			add("bodyPitch", 0.15 * e)
			add("legF", -0.2 * e)
			add("jaw", 0.4 * e)
			add("ear", 0.5 * e)
		elseif act == "hide" then
			-- tartaruga recolhe cabeça e patas
			add("neck", -0.9 * e)
			add("head", -0.4 * e)
			add("bodyY", -0.1 * e)
			add("legF", 0.6 * e)
			add("kneeF", -0.8 * e)
			add("legB", -0.6 * e)
			add("kneeB", 0.8 * e)
			add("lid", e)
		elseif act == "thump" then
			-- coelho bate a pata de trás no chão
			add("bodyPitch", 0.12 * e)
			add("legB", math.max(0, math.sin(u * 12)) * 0.5 * e)
			add("ear", 0.35 * e)
		elseif act == "croak" then
			-- sapo infla e coaxa
			local c = math.max(0, math.sin(u * 6)) * e
			add("bodyY", c * 0.05)
			add("jaw", c * 0.3)
			add("bodyPitch", 0.1 * c)
		elseif act == "headturn" then
			-- coruja gira a cabeça para os lados
			add("headYaw", math.sin(u * 2.6) * 1.3 * e)
			add("neckYaw", math.sin(u * 2.6) * 0.3 * e)
			add("headRoll", math.sin(u * 5.2) * 0.25 * e)
		elseif act == "barrelroll" then
			-- pirueta no ar (voadores e flutuantes)
			add("bodyRoll", math.pi * 2 * math.clamp((u - 0.2) / 1.2, 0, 1) * (e > 0.05 and 1 or 0))
			add("bodyY", math.sin(math.clamp(u / 1.6, 0, 1) * math.pi) * 0.3)
			add("wing", 0.5 * e)
		elseif act == "flutter" then
			add("wing", math.sin(u * 30) * 0.6 * e)
			add("bodyY", math.abs(math.sin(u * 15)) * 0.06 * e)
		elseif act == "flex" then
			-- bípede faz pose de força com os dois braços
			add("arm", -1.6 * e)
			add("elbow", -1.6 * e)
			P.armZ = (P.armZ or 0) + 0.9 * e
			add("bodyPitch", 0.08 * e)
			add("neck", 0.2 * e)
			add("headRoll", math.sin(u * 4) * 0.1 * e)
		elseif act == "rollover" then
			-- panda tomba de lado e rola de volta
			add("bodyRoll", math.sin(math.clamp(u / 2.4, 0, 1) * math.pi) * 1.3 * e)
			add("bodyY", -0.1 * e)
			add("arm", -1.2 * e)
			add("leg2", 0.6 * e)
		elseif act == "jumpjoy" then
			local k = math.abs(math.sin(u * 5)) * e
			add("bodyY", k * 0.5)
			add("bodyYaw", u * 3 * (e > 0.05 and 1 or 0) % (math.pi * 2))
			add("ear", (0.3 + k * 0.5))
		elseif act == "coilup" then
			add("rise", 0.7 * e)
			add("coil", math.sin(u * 4) * 0.8 * e)
			add("jaw", math.max(0, math.sin(u * 20)) * 0.25 * e)
		end
	end
	if sleep > 0 and gait == "slither" then
		-- serpente dormindo: enrolada de lado, cabeça encostada no chão
		add("coil", 0.7 * sleep)
		add("lid", 1 * sleep)
		add("neck", -0.12 * sleep)
		add("bodyY", math.sin(tt * 1.1) * 0.01)
	elseif sleep > 0 then
		-- deitado, patas dobradas, cabeça baixa, olhos fechados, cauda enrolada
		local br = math.sin(tt * 1.1) * 0.02
		add("bodyY", -0.3 * sleep + br)
		add("bodyPitch", -0.06 * sleep)
		add("legF", 1.15 * sleep)
		add("kneeF", -1.9 * sleep)
		add("legB", -1.1 * sleep)
		add("kneeB", 1.9 * sleep)
		add("neck", -0.55 * sleep + br * 3)
		add("headRoll", 0.15 * sleep)
		add("lid", 1 * sleep)
		add("ear", -0.35 * sleep)
		add("tailLift", -0.4 * sleep)
		add("tailCurl", 0.9 * sleep)
		add("wag", -1 * sleep)
		add("arm", 0.5 * sleep)
		add("elbow", -0.9 * sleep)
		add("leg2", 1.0 * sleep)
		add("knee2", -1.6 * sleep)
		add("wing", -0.1 * sleep)
		add("rise", -0.3 * sleep)
	end
	if hurt > 0 then
		-- tranco: recua, sacode a cabeça, orelhas para trás, fecha os olhos
		add("bodyPitch", 0.18 * hurt)
		add("bodyY", -0.05 * hurt)
		add("headYaw", math.sin(hurt * 20) * 0.3 * hurt)
		add("ear", -0.5 * hurt)
		add("lid", 0.8 * hurt)
		add("tailLift", -0.3 * hurt)
	end
	if party > 0 then
		-- subiu de nível: pulinho girando, cabeça para o alto, cauda abanando forte
		add("bodyY", math.abs(math.sin(party * math.pi * 3)) * 0.28 * math.min(1, party * 4))
		add("bodyYaw", (1 - party) * math.pi * 2)
		add("neck", 0.4 * math.min(1, party * 3))
		add("jaw", 0.35 * math.min(1, party * 3))
		add("wag", 1.5 * math.min(1, party * 3))
		add("arm", -2.4 * math.min(1, party * 3))
		add("wing", 0.9 * math.min(1, party * 3))
		add("ear", 0.45 * math.min(1, party * 3))
	end
	if sig > 0 then
		-- Assinatura: empina e ruge (quadrúpedes), braços ao alto (bípedes), asas abertas (aves)
		if gait == "quad" or gait == "hop" then
			add("bodyPitch", 0.55 * sig)
			add("legF", -0.6 * sig)
			add("kneeF", -0.8 * sig)
			add("legB", 0.35 * sig)
			add("neck", 0.5 * sig)
		end
		add("jaw", 0.7 * sig)
		add("arm", -2.8 * sig)
		add("wing", 1.2 * sig)
		add("rise", 0.8 * sig)
		add("tailLift", 0.6 * sig)
		add("ear", 0.3 * sig)
	end
	return P
end
CreatureMotion._extraPose = extraPose -- (testes)

function CreatureMotion.animate(entry, t: number, dt: number, now: number, flash)
	local model, src = entry.model, entry.source
	local root = entry.root
	local pos = root.Position
	local vel = (pos - entry.lastPos) / math.max(dt, 1 / 240)
	entry.lastPos = pos
	local flat = (vel * Vector3.new(1, 0, 1)).Magnitude
	entry.speed += (flat - entry.speed) * math.min(1, dt * 6)
	local speed = entry.speed
	local s = entry.scale
	local walk = math.clamp(speed / 6, 0, 1)
	local run = math.clamp((speed - 12) / 10, 0, 1)
	local heavy = entry.heavy and 0.65 or 1
	-- frequência da passada cresce com a velocidade (e diminui com o tamanho)
	local freq = (3 + speed * 0.42) * heavy / math.max(0.75, math.sqrt(s / 2.4))
	entry.phase += dt * freq
	local ph = entry.phase
	local tt = t + entry.seed

	-- estados vindos do modelo do servidor
	local action = src:GetAttribute("Action")
	local since = now - (src:GetAttribute("ActionAt") or 0)
	-- ATAQUE EM 3 TEMPOS: preparação (wind: encolhe, recua, arma o golpe), golpe rápido (attack sobe de 0 a 1 em
	-- 0,12 s) e recuperação com um quique (settle). As poses de cada parte usam wind e attack.
	local attack, wind, settle = 0, 0, 0
	if (action == "Attack" or action == "Cast") and since < 0.72 then
		local W, S2, R = 0.22, 0.12, 0.38
		if since < W then
			wind = math.sin(since / W * math.pi / 2)
		elseif since < W + S2 then
			local u = (since - W) / S2
			wind = 1 - u
			attack = math.sin(u * math.pi / 2)
		else
			local u = math.clamp((since - W - S2) / R, 0, 1)
			attack = (1 - u) ^ 2
			settle = math.sin(u * math.pi * 2) * (1 - u) * 0.3
		end
		-- golpe acabou de sair: avisa (arco de corte no Fx)
		if since >= W and entry.struckAt ~= src:GetAttribute("ActionAt") then
			entry.struckAt = src:GetAttribute("ActionAt")
			if CreatureMotion.onStrike then
				task.spawn(CreatureMotion.onStrike, entry, model)
			end
		end
	end
	local cast = action == "Cast" and attack or 0
	local knocked = src:GetAttribute("Knocked") == true
	if knocked ~= entry.knocked then
		entry.knocked = knocked
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = knocked and 0.45 or 0
			end
		end
	end
	local hitAt = src:GetAttribute("HitAt") or 0
	if now - hitAt < 0.05 and entry.lastHit ~= hitAt then
		entry.lastHit = hitAt
		entry.hurtAt = os.clock()
		if flash then
			flash(model)
		end
	end
	-- subiu de nível (o servidor marca LevelUpAt): festinha
	local lvAt = src:GetAttribute("LevelUpAt") or 0
	if lvAt ~= (entry.lastLevelUp or 0) then
		if entry.lastLevelUp ~= nil and now - lvAt < 2 then
			entry.partyAt = os.clock()
		end
		entry.lastLevelUp = lvAt
	end
	local down = knocked and 1 or 0

	-- dono: pulo, reação e comemoração
	local uid, oroot, hum = ownerInfo(entry)
	local ownerAir = hum ~= nil and hum.FloorMaterial == Enum.Material.Air and oroot ~= nil and oroot.AssemblyLinearVelocity.Y > 6
	if ownerAir and not entry.lastOwnerAir then
		entry.jumpT = os.clock() + (entry.idxDelay or math.random() * 0.15)
	end
	entry.lastOwnerAir = ownerAir
	local jt = os.clock() - entry.jumpT
	local jump = (jt >= 0 and jt < 0.6) and math.sin(jt / 0.6 * math.pi) or 0
	local celebrating = uid ~= nil and (celebrateUntil[uid] or 0) > os.clock()
	local cele = celebrating and 1 or 0
	local near, lookYaw = 0, 0
	if oroot and walk < 0.25 then
		local toOwner = (oroot.Position - pos) * Vector3.new(1, 0, 1)
		if toOwner.Magnitude < 9 then
			near = 1
			local fwd = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			if fwd.Magnitude > 0.1 and toOwner.Magnitude > 0.1 then
				local a = math.atan2(fwd:Cross(toOwner.Unit).Y, fwd.Unit:Dot(toOwner.Unit))
				lookYaw = math.clamp(a, -0.9, 0.9)
			end
		end
	end
	entry.near = (entry.near or 0) + (near - (entry.near or 0)) * math.min(1, dt * 3)
	local happy = math.max(entry.near, cele)
	-- pequeno salto de comemoração
	local hop = cele * math.abs(math.sin(tt * 6)) + jump
	local breathe = math.sin(tt * (entry.heavy and 1.4 or 2.2))
	local gait = entry.gait
	local idleLook = math.sin(tt * 0.45) * 0.35 * (1 - walk) * (1 - entry.near)
	local sniff = (1 - walk) * (1 - entry.near) * math.max(0, math.sin(tt * 0.21) - 0.75) * 4

	-- comportamento ocioso / sono / tranco / festa / pose da Assinatura
	local clock = os.clock()
	local isIdle = walk < 0.08 and attack == 0 and wind == 0 and not knocked and not celebrating and jump == 0
	local actName, actE, actU, asleep = idleBehaviour(entry, isIdle, dt, clock)
	entry.sleepW = (entry.sleepW or 0) + ((asleep and 1 or 0) - (entry.sleepW or 0)) * math.min(1, dt * 1.5)
	setSnore(entry, entry.sleepW > 0.6)
	local hurtT = clock - (entry.hurtAt or -10)
	local hurt = hurtT < 0.35 and (1 - hurtT / 0.35) or 0
	local partyT = clock - (entry.partyAt or -10)
	local party = partyT < 1.6 and (1 - partyT / 1.6) or 0
	local sig = (action == "Cast" and since < 0.9) and math.sin(math.clamp(since / 0.9, 0, 1) * math.pi) or 0
	local X = extraPose(entry, actName, actE, actU, entry.sleepW, hurt, party, sig, tt)
	local function x(k: string): number
		return X[k] or 0
	end
	entry.lastAction = actName or (entry.sleepW > 0.6 and "sleep" or nil)

	for _, j in ipairs(entry.mjoints) do
		local k = j.kind
		local cf = CFrame.identity
		if k == "body" then
			local bob, pitch, roll, fwdMove = 0, 0, 0, 0
			if gait == "quad" or gait == "insect" then
				bob = math.abs(math.sin(ph * 2)) * 0.05 * s * walk * (1 - run) + math.sin(ph * 2) * 0.09 * s * run
				pitch = math.sin(ph * 2 + 0.5) * 0.06 * run
				roll = math.sin(ph) * 0.03 * walk
			elseif gait == "hop" then
				bob = math.abs(math.sin(ph)) * 0.35 * s * walk
				pitch = -math.cos(ph) * 0.18 * walk
			elseif gait == "bird" or gait == "float" then
				bob = math.sin(tt * 2.2) * 0.12 * s
				pitch = 0.15 * walk
				roll = math.sin(tt * 1.3) * 0.06
			elseif gait == "bounce" then
				bob = math.abs(math.sin(tt * (3 + walk * 4))) * 0.3 * s * (0.35 + walk)
			elseif gait == "biped" then
				bob = math.abs(math.sin(ph)) * 0.06 * s * walk
				roll = math.sin(ph) * 0.05 * walk
			elseif gait == "slither" then
				roll = math.sin(ph) * 0.05 * walk
			end
			bob += breathe * 0.012 * s + hop * 0.55 * s
			-- ataque: bote para a frente (quadrúpedes), empinada (cervídeos/pesados), avanço (aves)
			local an = entry.anatomy
			if gait == "quad" then
				if an == "cervid" or an == "caprine" or an == "heavy" or an == "mammoth" or an == "bushgoat" then
					-- pesados: empinam na preparação e batem com tudo no golpe
					pitch += wind * 0.5 - attack * 0.22
					bob += wind * 0.3 * s - attack * 0.08 * s
				else
					-- bote: encolhe e recua, depois salta para a frente esticado
					pitch += wind * 0.12 - attack * 0.22
					-- (furões e bichos rentes ao chão quase não têm como se encolher: senão afundam)
					bob -= wind * 0.1 * s * (an == "mustelid" and 0.15 or 1)
					fwdMove = attack * 0.45 * s - wind * 0.18 * s
				end
			elseif gait == "bird" then
				pitch += wind * 0.35 - attack * 0.55
				fwdMove = attack * 0.55 * s - wind * 0.15 * s
			elseif gait == "biped" or gait == "bounce" then
				bob -= wind * 0.12 * s
				pitch += wind * 0.15 - attack * 0.25
				fwdMove = attack * 0.25 * s
			end
			bob += settle * 0.12 * s
			pitch += cele * math.sin(tt * 6) * 0.08 - jump * 0.15
			if gait == "slither" then
				pitch += x("rise") * 0.55
			end
			cf = CFrame.new(0, bob - down * 0.35 * s + x("bodyY") * s, -fwdMove) * A(pitch + x("bodyPitch"), x("bodyYaw"), roll + down * 1.25 + x("bodyRoll"))
		elseif k == "neck" or k == "head" then
			local w = k == "neck" and 0.55 or 0.45
			local nod = math.sin(ph * 2) * 0.05 * walk
			local pitch = nod - sniff * 0.35 + breathe * 0.015
			pitch += (attack * (gait == "quad" and -0.35 or -0.6)) + wind * 0.4 + cele * 0.35 + entry.near * 0.08
			if entry.anatomy == "cervid" or entry.anatomy == "caprine" then
				pitch -= attack * 0.5 -- cabeçada
			end
			if gait == "slither" then
				pitch += attack * 0.4 + wind * 0.5 -- serpente ergue a cabeça antes do bote
			end
			local yaw = (idleLook + lookYaw * entry.near) * w
			if k == "neck" then
				pitch += x("neck") / (w * 2)
				yaw += x("neckYaw")
				-- serpentes erguem a parte da frente pelo pescoço
				pitch += x("rise") * 0.5 / (w * 2)
			else
				pitch += x("head") / (w * 2)
				yaw += x("headYaw")
			end
			cf = A(pitch * w * 2, yaw, k == "head" and x("headRoll") or 0)
		elseif k == "jaw" then
			local pant = (entry.anatomy == "canine" or entry.anatomy == "fox" or entry.anatomy == "wolf" or entry.anatomy == "pup") and run * (0.12 + math.sin(tt * 14) * 0.05) or 0
			cf = A(math.max(attack * 0.75, pant, cele * 0.35 * math.max(0, math.sin(tt * 3)), x("jaw")), 0, 0)
		elseif k == "ear" then
			local twitch = math.max(0, math.sin(tt * 1.7 + j.side * 2.3)) ^ 10 * 0.45
			local perk = entry.near * 0.12 - attack * 0.35
			cf = A(-twitch * 0.4 + perk + x("ear"), 0, j.side * (twitch * 0.25 + run * 0.25 - x("ear") * 0.5))
		elseif k == "lid" then
			local cyc = (tt * 0.26 + entry.seed) % 1
			local blink = (knocked and 1) or (cyc < 0.035 and math.sin(cyc / 0.035 * math.pi) or 0)
			blink = math.clamp(math.max(blink, x("lid")), 0, 1)
			cf = CFrame.new((j.blink or Vector3.zero) * blink)
			j.motor.Transform = cf
			continue
		elseif k == "legq" then
			local phases = (gait == "insect") and TRIPOD or (run > 0.3 and GALLOP or TROT)
			local p = ph + (phases[j.tag] or 0)
			if gait == "hop" then
				p = ph + (j.front and 0.6 or 0)
			end
			local amp = (gait == "insect" and 0.35 or (0.42 + run * 0.4)) * walk
			local swing = math.sin(p) * amp
			if gait == "hop" then
				swing = (j.front and 0.5 or -0.6) * math.max(0, math.sin(p)) * walk
			end
			-- pulo: patas recolhidas; ataque: patas da frente avançam (felinos dão patada)
			local tuck = (jump + cele * 0.3) * (j.front and 0.55 or -0.5)
			local strike = 0
			if j.front and attack > 0 then
				local cat = entry.anatomy == "feline" or entry.anatomy == "lion" or entry.anatomy == "lynx" or entry.anatomy == "tiger" or entry.anatomy == "griffin"
				if cat then
					strike = (j.side > 0 and 1.3 or 0.2) * attack
				else
					strike = 0.6 * attack
				end
			end
			if j.front and wind > 0 then
				local cat = entry.anatomy == "feline" or entry.anatomy == "lion" or entry.anatomy == "lynx" or entry.anatomy == "tiger" or entry.anatomy == "griffin"
				-- preparação: felino arma a pata para trás; os outros firmam as patas da frente
				strike += (cat and j.side > 0) and -0.7 * wind or 0.25 * wind
			elseif j.hind and wind > 0 then
				strike -= 0.2 * wind -- patas de trás dobram para dar o impulso
			end
			local idle = (1 - walk) * math.sin(tt * 0.9 + j.side) * 0.015
			local extra = j.front and x("legF") or x("legB")
			-- coçar: a pata de trás do lado direito chuta rápido para a frente
			if X.scratch and j.hind and j.side > 0 then
				extra += (1.9 + math.sin(tt * 22) * 0.35) * X.scratch
			end
			if X.pawR and j.front and j.side > 0 then
				extra += X.pawR
			end
			if gait == "insect" then
				cf = A(j.front and x("legF") or 0, swing * (j.side), math.max(0, math.cos(p)) * 0.3 * walk * j.side)
			else
				cf = A(swing + tuck + strike + idle + down * (j.front and 0.9 or -0.6) + extra, 0, 0)
			end
		elseif k == "kneeq" then
			local phases = (gait == "insect") and TRIPOD or (run > 0.3 and GALLOP or TROT)
			local p = ph + (phases[j.tag] or 0)
			local lift = math.max(0, math.cos(p)) * walk
			if gait == "hop" then
				lift = math.max(0, -math.sin(ph + (j.front and 0.6 or 0))) * walk
			end
			local bend = (j.front and -0.9 or 0.75) * lift * (0.7 + run * 0.5)
			local tuck = (jump + cele * 0.3) * (j.front and -0.9 or 0.9)
			local strike = (j.front and attack > 0) and -0.6 * attack or 0
			local extra = j.front and x("kneeF") or x("kneeB")
			if X.scratch and j.hind and j.side > 0 then
				extra += -1.7 * X.scratch
			end
			if X.pawR and j.front and j.side > 0 then
				extra += -1.3 * X.pawR
			end
			cf = A(bend + tuck + strike + down * (j.front and -1.2 or 1.0) + extra, 0, 0)
		elseif k == "footq" then
			local phases = run > 0.3 and GALLOP or TROT
			local p = ph + (phases[j.tag] or 0)
			local lift = math.max(0, math.cos(p)) * walk
			cf = A((j.front and 0.5 or -0.4) * lift + jump * (j.front and 0.4 or -0.4) + (j.front and x("footF") or x("footB")), 0, 0)
		elseif k == "leg2" then
			if gait == "bird" then
				cf = A(0.6 * (entry.flies and 1 or walk), 0, 0) -- pernas recolhidas no voo
			else
				local swing = math.sin(ph + (j.side > 0 and math.pi or 0)) * 0.5 * walk
				cf = A(swing - jump * 0.4 + cele * 0.1 + x("leg2") * (gait == "biped" and (j.side > 0 and 1 or -1) * (X.sleepSide or 1) or 1), 0, 0)
			end
		elseif k == "knee2" then
			local lift = math.max(0, math.cos(ph + (j.side > 0 and math.pi or 0))) * walk
			cf = A(-0.8 * lift + jump * 0.6 + x("knee2"), 0, 0)
		elseif k == "arm" then
			local swing = -math.sin(ph + (j.side > 0 and math.pi or 0)) * 0.45 * walk
			-- punhos sobem na preparação e descem com tudo no golpe
			local smash = -2.6 * wind - 0.9 * attack
			local raise = -2.6 * cele + -0.6 * cast
			local idle = math.sin(tt * 1.6 + j.side) * 0.06
			local own = j.side > 0 and x("armR") or x("armL")
			local ownZ = j.side > 0 and x("armRz") or 0
			cf = A(swing + smash + raise + idle + x("arm") + own, 0, j.side * (0.1 + cele * 0.3 + x("armZ") + ownZ))
		elseif k == "elbow" then
			cf = A(-0.4 * walk - 0.6 * attack - 0.8 * wind + math.sin(tt * 1.6) * 0.05 + x("elbow"), 0, 0)
		elseif k == "wing" then
			local second = j.name:sub(1, 5) == "Wing2"
			local flapRate = entry.flies and (7 + walk * 5) or 2
			local amp = entry.flies and (0.55 + walk * 0.25) or (0.08 + cele * 0.6)
			local flap = math.sin(tt * flapRate + (second and 1.2 or 0)) * amp + cele * 0.4 + attack * 0.7 + wind * 0.9
			if not entry.flies then
				flap += math.max(0, math.sin(tt * 0.35) - 0.92) * 9 -- ajeita as asas de vez em quando
			end
			cf = A(0, 0, j.side * (flap + x("wing")))
		elseif k == "tail" or k == "tailseg" or k == "tailmulti" then
			local i = k == "tail" and 1 or j.idx
			local wagRate = 3 + math.max(happy, x("wag")) * 9
			local wagAmp = math.max(0, (0.22 + happy * 0.35 + x("wag") * 0.3) * (1 - run * 0.6))
			-- ataque: rabo levanta duro na preparação e chicoteia no golpe
			local yaw = math.sin(tt * wagRate - i * 0.7) * wagAmp + math.sin(since * 30 - i * 0.8) * attack * 0.45
			local lift = wind * 0.45 + run * 0.25 - (k == "tail" and 0.05 or 0.08) * math.sin(tt * 1.2 - i * 0.5) - down * 0.4
			if k == "tailmulti" then
				yaw = math.sin(tt * 2.2 + j.idx * 1.3) * (0.18 + happy * 0.2)
			end
			cf = A(-lift - x("tailLift") * (k == "tail" and 1 or 0.4), yaw + x("tailCurl") * (k == "tail" and 0.6 or 0.35), 0)
		elseif k == "seg" then
			local amp = 0.16 + walk * 0.32
			-- erguer (rise): os primeiros segmentos levantam a frente da serpente; coil: balança de lado
			-- o corpo (frente) inclina para cima e o 1º segmento compensa: a cauda fica no chão
			local rise = j.idx == 1 and -x("rise") * 0.55 or 0
			cf = A(math.sin(tt * 1.8 - j.idx * 0.7) * 0.03 + rise, math.sin(ph * 1.4 - j.idx * 0.95) * amp + x("coil") * (j.idx <= 3 and 0.3 or 0), 0)
		elseif k == "trunk" then
			cf = A(math.sin(tt * 1.4 - j.idx * 0.6) * 0.18 - attack * 0.5 + wind * 0.6 + cele * -0.4 + x("trunk"), math.sin(tt * 0.9 - j.idx) * 0.15, 0)
		elseif k == "orbit" then
			cf = A(0, (tt * (j.name == "Orbit2" and -0.9 or 1.3)) % (math.pi * 2), 0)
		end
		j.motor.Transform = cf
		if k == "body" then
			entry.bodyMotor = j.motor
		end
	end
	-- poses de comportamento (sentar, deitar, coçar...) não podem afundar no chão: levanta o corpo o que for
	-- preciso para o ponto mais baixo voltar à altura de repouso (só enquanto há pose extra)
	local extraOn = (actE > 0) or entry.sleepW > 0.01 or hurt > 0 or party > 0 or sig > 0
	local lift = 0
	if extraOn and entry.bodyMotor and entry.restLow and entry.restLow < math.huge then
		if entry.sleepW > 0.5 then
			-- deitado: a barriga encosta no chão (altura de repouso), as patas dobradas ficam por baixo
			lift = entry.restLow - CreatureMotion.lowestPoint(entry, false, true)
		else
			lift = math.max(0, entry.restLow - CreatureMotion.lowestPoint(entry))
		end
	end
	entry.groundLift = (entry.groundLift or 0) + (lift - (entry.groundLift or 0)) * math.min(1, dt * 12)
	if math.abs(entry.groundLift) > 0.002 and entry.bodyMotor then
		entry.bodyMotor.Transform = CFrame.new(0, entry.groundLift, 0) * entry.bodyMotor.Transform
	end
end

return CreatureMotion

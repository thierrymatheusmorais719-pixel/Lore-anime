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
--
-- Juntas pelo nome (PetMesh/PetAnatomy): Body, Neck, Head, Jaw, Ear*, Lid*, Leg??/Knee??/Foot??,
-- LegL/LegR, KneeL/KneeR, ArmL/ArmR, ElbowL/ElbowR, Wing*, Tail/TailSegN/TailN, SegN, TrunkN, Orbit*.

local Players = game:GetService("Players")

local CreatureMotion = {}

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
	local attack = 0
	if (action == "Attack" or action == "Cast") and since < 0.6 then
		attack = math.sin(math.clamp(since / 0.55, 0, 1) * math.pi)
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
		if flash then
			flash(model)
		end
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
					pitch += attack * 0.45
					bob += attack * 0.25 * s
				else
					pitch -= attack * 0.2
					fwdMove = attack * 0.35 * s
				end
			elseif gait == "bird" then
				pitch -= attack * 0.5
				fwdMove = attack * 0.5 * s
			end
			pitch += cele * math.sin(tt * 6) * 0.08 - jump * 0.15
			cf = CFrame.new(0, bob - down * 0.35 * s, -fwdMove) * A(pitch, 0, roll + down * 1.25)
		elseif k == "neck" or k == "head" then
			local w = k == "neck" and 0.55 or 0.45
			local nod = math.sin(ph * 2) * 0.05 * walk
			local pitch = nod - sniff * 0.35 + breathe * 0.015
			pitch += (attack * (gait == "quad" and -0.35 or -0.6)) + cele * 0.35 + entry.near * 0.08
			if entry.anatomy == "cervid" or entry.anatomy == "caprine" then
				pitch -= attack * 0.5 -- cabeçada
			end
			if gait == "slither" then
				pitch += attack * 0.4
			end
			local yaw = (idleLook + lookYaw * entry.near) * w
			cf = A(pitch * w * 2, yaw, 0)
		elseif k == "jaw" then
			local pant = (entry.anatomy == "canine" or entry.anatomy == "fox" or entry.anatomy == "wolf" or entry.anatomy == "pup") and run * (0.12 + math.sin(tt * 14) * 0.05) or 0
			cf = A(math.max(attack * 0.6, pant, cele * 0.35 * math.max(0, math.sin(tt * 3))), 0, 0)
		elseif k == "ear" then
			local twitch = math.max(0, math.sin(tt * 1.7 + j.side * 2.3)) ^ 10 * 0.45
			local perk = entry.near * 0.12 - attack * 0.35
			cf = A(-twitch * 0.4 + perk, 0, j.side * (twitch * 0.25 + run * 0.25))
		elseif k == "lid" then
			local cyc = (tt * 0.26 + entry.seed) % 1
			local blink = (knocked and 1) or (cyc < 0.035 and math.sin(cyc / 0.035 * math.pi) or 0)
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
			local idle = (1 - walk) * math.sin(tt * 0.9 + j.side) * 0.015
			if gait == "insect" then
				cf = A(0, swing * (j.side), math.max(0, math.cos(p)) * 0.3 * walk * j.side)
			else
				cf = A(swing + tuck + strike + idle + down * (j.front and 0.9 or -0.6), 0, 0)
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
			cf = A(bend + tuck + strike + down * (j.front and -1.2 or 1.0), 0, 0)
		elseif k == "footq" then
			local phases = run > 0.3 and GALLOP or TROT
			local p = ph + (phases[j.tag] or 0)
			local lift = math.max(0, math.cos(p)) * walk
			cf = A((j.front and 0.5 or -0.4) * lift + jump * (j.front and 0.4 or -0.4), 0, 0)
		elseif k == "leg2" then
			if gait == "bird" then
				cf = A(0.6 * (entry.flies and 1 or walk), 0, 0) -- pernas recolhidas no voo
			else
				local swing = math.sin(ph + (j.side > 0 and math.pi or 0)) * 0.5 * walk
				cf = A(swing - jump * 0.4 + cele * 0.1, 0, 0)
			end
		elseif k == "knee2" then
			local lift = math.max(0, math.cos(ph + (j.side > 0 and math.pi or 0))) * walk
			cf = A(-0.8 * lift + jump * 0.6, 0, 0)
		elseif k == "arm" then
			local swing = -math.sin(ph + (j.side > 0 and math.pi or 0)) * 0.45 * walk
			local smash = -2.2 * attack + (since > 0.3 and since < 0.6 and 0.6 or 0) * attack
			local raise = -2.6 * cele + -0.6 * cast
			local idle = math.sin(tt * 1.6 + j.side) * 0.06
			cf = A(swing + smash + raise + idle, 0, j.side * (0.1 + cele * 0.3))
		elseif k == "elbow" then
			cf = A(-0.4 * walk - 0.6 * attack + math.sin(tt * 1.6) * 0.05, 0, 0)
		elseif k == "wing" then
			local second = j.name:sub(1, 5) == "Wing2"
			local flapRate = entry.flies and (7 + walk * 5) or 2
			local amp = entry.flies and (0.55 + walk * 0.25) or (0.08 + cele * 0.6)
			local flap = math.sin(tt * flapRate + (second and 1.2 or 0)) * amp + cele * 0.4 + attack * 0.7
			if not entry.flies then
				flap += math.max(0, math.sin(tt * 0.35) - 0.92) * 9 -- ajeita as asas de vez em quando
			end
			cf = A(0, 0, j.side * flap)
		elseif k == "tail" or k == "tailseg" or k == "tailmulti" then
			local i = k == "tail" and 1 or j.idx
			local wagRate = 3 + happy * 9
			local wagAmp = (0.22 + happy * 0.35) * (1 - run * 0.6)
			local yaw = math.sin(tt * wagRate - i * 0.7) * wagAmp
			local lift = run * 0.25 - (k == "tail" and 0.05 or 0.08) * math.sin(tt * 1.2 - i * 0.5) - down * 0.4
			if k == "tailmulti" then
				yaw = math.sin(tt * 2.2 + j.idx * 1.3) * (0.18 + happy * 0.2)
			end
			cf = A(-lift, yaw, 0)
		elseif k == "seg" then
			local amp = 0.16 + walk * 0.32
			cf = A(math.sin(tt * 1.8 - j.idx * 0.7) * 0.03, math.sin(ph * 1.4 - j.idx * 0.95) * amp, 0)
		elseif k == "trunk" then
			cf = A(math.sin(tt * 1.4 - j.idx * 0.6) * 0.18 - attack * 0.5 + cele * -0.4, math.sin(tt * 0.9 - j.idx) * 0.15, 0)
		elseif k == "orbit" then
			cf = A(0, (tt * (j.name == "Orbit2" and -0.9 or 1.3)) % (math.pi * 2), 0)
		end
		j.motor.Transform = cf
	end
end

return CreatureMotion

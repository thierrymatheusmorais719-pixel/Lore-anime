-- Animação procedural de TODAS as criaturas (pets, inimigos, bosses), no cliente.
-- Lê o nome das juntas (Motor6D) e os atributos replicados pelo servidor:
--   Action/ActionAt (ataque, magia, rugido...), WindupEnd (preparação), HitAt (dano), Dead, Knocked
-- e escreve Motor6D.Transform a cada frame. Também anima: ciclo de cor Prismatic e órbitas.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CreatureMotion = require(script.Parent.CreatureMotion)

local Animator = {}

local tracked: { [Model]: any } = {}
local highlights = {}
local HIGHLIGHT_POOL = 8

local function serverNow()
	return workspace:GetServerTimeNow()
end

-- Rotação do frame da junta em relação ao root (em repouso) para animar em "espaço do root".
local function restRotation(model: Model, motor: Motor6D): CFrame
	local root = model.PrimaryPart
	local p0 = motor.Part0
	if not root or not p0 then
		return CFrame.identity
	end
	return ((root.CFrame:Inverse() * p0.CFrame) * motor.C0).Rotation
end

local function classify(name: string)
	if name == "Body" then
		return "body"
	elseif name == "Neck" then
		return "neck"
	elseif name:sub(1, 3) == "Leg" then
		return "leg"
	elseif name:sub(1, 3) == "Arm" then
		return "arm"
	elseif name:sub(1, 4) == "Wing" then
		return "wing"
	elseif name:match("^NeckSeg%d") then
		return "neckseg"
	elseif name:sub(1, 7) == "TailSeg" then
		return "tailseg"
	elseif name:sub(1, 4) == "Tail" then
		return "tail"
	elseif name:match("^Seg%d") then
		return "seg"
	elseif name:sub(1, 3) == "Ear" then
		return "ear"
	elseif name:sub(1, 5) == "Orbit" then
		return "orbit"
	elseif name:sub(1, 5) == "Petal" then
		return "petal"
	elseif name:sub(1, 3) == "Jaw" then
		return "jaw"
	elseif name:match("^Root%d") then
		return "root"
	elseif name:sub(1, 3) == "Lid" then
		return "lid"
	end
	return nil
end

-- Fase do passo: diagonais alternadas (FL+BR / FR+BL), pernas do meio invertidas, bípedes L/R.
local LEG_PHASE = { FL = 0, BR = 0, FR = math.pi, BL = math.pi, ML = math.pi, MR = 0, L = 0, R = math.pi }
local function legPhase(name: string): number
	return LEG_PHASE[name:sub(4)] or 0
end

-- source: modelo de onde vêm os atributos (Action, WindupEnd, Dead...). O visual novo dos bosses
-- (BossVisuals) é animado aqui com os atributos do boss do servidor.
local function track(model: Model, source: Model?)
	if tracked[model] or not model:IsA("Model") then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Root")
	if not root then
		return
	end
	local joints = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name ~= "Fixed" then
			local kind = classify(d.Name)
			if kind then
				local idx = tonumber(d.Name:match("(%d+)$")) or 0
				table.insert(joints, { motor = d, kind = kind, rest = restRotation(model, d), name = d.Name, idx = idx,
					drop = kind == "lid" and d.Part1 and (d.Part1:GetAttribute("BlinkDrop") or d.Part1.Size.Y * 0.8) or 0,
					push = kind == "lid" and d.Part1 and (d.Part1:GetAttribute("BlinkPush") or 0) or 0,
					side = (d.Name:sub(-1) == "L") and 1 or (d.Name:sub(-1) == "R" and -1 or 0), phase = legPhase(d.Name) })
			end
		end
	end
	local size = model:GetExtentsSize()
	if model:GetAttribute("MeshPet") then
		-- pet de malha (PetVisuals): animação própria da anatomia (CreatureMotion)
		local entry = { model = model, root = root, joints = {}, lastPos = root.Position, speed = 0, seed = math.random() * 10, scale = math.max(size.Y, 1), faded = false }
		CreatureMotion.prepare(entry)
		tracked[model] = entry
		model.AncestryChanged:Connect(function(_, parent)
			if not parent then
				tracked[model] = nil
			end
		end)
		return
	end
	local src = source or model
	local entry = {
		model = model, source = src, root = root, joints = joints, lastPos = root.Position, speed = 0, seed = math.random() * 10,
		scale = math.max(size.Y, 2), isBoss = src:GetAttribute("BossId") ~= nil, prism = nil, faded = false,
		flies = src:GetAttribute("Flies") == true or src:GetAttribute("Rig") == "floater" or src:GetAttribute("BossId") == "tempest_wyrm",
	}
	if model:GetAttribute("PrismaticCycle") then
		entry.prism = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and (d:GetAttribute("Role") == "Body" or d:GetAttribute("Role") == "Accent") and d.Transparency < 1 then
				local h, s, v = d.Color:ToHSV()
				table.insert(entry.prism, { part = d, h = h, s = math.max(s, 0.35), v = math.max(v, 0.75) })
			end
		end
	end
	tracked[model] = entry
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			tracked[model] = nil
		end
	end)
end

local function rs(j, cf: CFrame): CFrame
	return j.rest:Inverse() * cf * j.rest
end

local function flash(model: Model)
	local h = highlights[1]
	for _, cand in ipairs(highlights) do
		if not cand.Adornee or (cand:GetAttribute("At") or 0) < (h:GetAttribute("At") or 0) then
			h = cand
		end
	end
	if not h then
		return
	end
	h.Adornee = model
	h:SetAttribute("At", os.clock())
	h.FillTransparency = 0.35
	h.Enabled = true
	task.delay(0.12, function()
		if h.Adornee == model then
			h.Enabled = false
			h.Adornee = nil
		end
	end)
end

local function fadeOut(entry)
	if entry.faded then
		return
	end
	entry.faded = true
	task.delay(0.9, function()
		for _, d in ipairs(entry.model:GetDescendants()) do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(1.1), { LocalTransparencyModifier = 1 }):Play()
			end
		end
	end)
end

local function animate(entry, t: number, dt: number, now: number)
	if entry.meshPet then
		CreatureMotion.animate(entry, t, dt, now, flash)
		return
	end
	if entry.model:GetAttribute("MeshVisual") then
		return -- modelo antigo do pet escondido: quem aparece é o de malha
	end
	local model = entry.model
	local src = entry.source or model
	local root = entry.root
	local pos = root.Position
	local vel = (pos - entry.lastPos) / math.max(dt, 1 / 240)
	entry.lastPos = pos
	local flatSpeed = (vel * Vector3.new(1, 0, 1)).Magnitude
	entry.speed += (flatSpeed - entry.speed) * math.min(1, dt * 8)
	local moving = math.clamp(entry.speed / 10, 0, 1)
	local s = entry.scale
	local tt = t + entry.seed

	local action = src:GetAttribute("Action")
	local actionAt = src:GetAttribute("ActionAt") or 0
	local since = now - actionAt
	local windupEnd = src:GetAttribute("WindupEnd") or 0
	local dead = src:GetAttribute("Dead") == true
	local hitAt = src:GetAttribute("HitAt") or 0
	local hurt = math.clamp(1 - (now - hitAt) / 0.25, 0, 1)
	if hurt > 0.95 and entry.lastHit ~= hitAt then
		entry.lastHit = hitAt
		flash(model)
	end

	-- curvas de ação em 3 TEMPOS (como os ataques dos pets):
	--   preparação: enrola rápido e segura, tremendo no fim (a carga "transborda");
	--   golpe: estalo de 0,12 s que passa do ponto (1,15);
	--   acomodação: 0,55 s de oscilação amortecida (recua um pouco antes de parar).
	local strike, wind, tremble, settleT = 0, 0, 0, 1
	if action and action ~= "Dead" then
		if now < windupEnd then
			local total = math.max(0.2, windupEnd - actionAt)
			local k = math.clamp(since / total, 0, 1)
			wind = 1 - (1 - k) ^ 2.2
			tremble = k > 0.65 and math.sin(now * 55) * 0.05 * (k - 0.65) / 0.35 or 0
		elseif since < 6 then
			local after = now - math.max(windupEnd, actionAt)
			if after < 0.12 then
				strike = (after / 0.12) ^ 0.6 * 1.15
				wind = 1 - after / 0.12
				settleT = 0
			elseif after < 0.67 then
				local u = (after - 0.12) / 0.55
				strike = 1.15 * math.exp(-4 * u) * math.cos(u * 9)
				settleT = u
			end
		end
	end
	entry.lastStrike = strike
	local sweep = action == "Sweep" and 1 or 0
	local breathHold = (action == "Breath" and settleT < 1 and windupEnd > 0 and now >= windupEnd and now - windupEnd < 1.4) and 1 or 0
	local roar = (action == "Roar" or action == "Intro") and strike + wind or 0
	local slam = (action == "Slam" or action == "Lunge") and 1 or 0
	local deathT = dead and math.clamp((now - actionAt) / 0.8, 0, 1) or 0
	if dead then
		fadeOut(entry)
	end

	local knocked = src:GetAttribute("Knocked") == true
	if knocked ~= entry.knocked then
		entry.knocked = knocked
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = knocked and 0.55 or 0
			end
		end
	end

	local bobAmp = (entry.flies and 0.25 or 0.06) * s * 0.3
	local breathe = math.sin(tt * (entry.isBoss and 1.4 or 2.6)) * bobAmp
	local stepBob = math.abs(math.sin(tt * 9)) * 0.12 * moving * s * 0.2

	for _, j in ipairs(entry.joints) do
		local k = j.kind
		local cf = CFrame.identity
		if k == "body" then
			local pitch = -wind * 0.25 + strike * 0.35 - hurt * 0.25 + roar * -0.15 + tremble
			local yaw = sweep * (wind * 0.55 - strike * 0.9) -- varrida: torce para um lado e chicoteia para o outro
			local lift = slam * (wind * 0.18 - math.max(strike, 0) * 0.28) * s -- pancada: ergue-se e despenca
			cf = CFrame.new(0, breathe + stepBob - deathT * s * 0.25 + lift, 0) * CFrame.Angles(pitch, yaw, deathT * 1.35 + math.sin(tt * 1.3) * 0.02 + tremble * 0.5)
		elseif k == "neck" then
			local look = math.sin(tt * 0.7) * 0.15 * (1 - moving)
			cf = CFrame.Angles(-strike * 0.45 + wind * 0.3 - roar * 0.5 + hurt * 0.2, look, 0)
		elseif k == "leg" then
			local stride = entry.isBoss and 4 or 10
			local swing = math.sin(tt * stride + j.phase) * 0.55 * moving
			cf = CFrame.Angles(swing, 0, 0)
		elseif k == "arm" then
			local swing = math.sin(tt * 9 + (j.side > 0 and math.pi or 0)) * 0.45 * moving
			local raise = -wind * 2.2 * (slam > 0 and 1 or 0.6) + strike * (slam > 0 and 1.2 or 0.9)
			local idle = math.sin(tt * 2 + j.side) * 0.06
			cf = CFrame.Angles(swing + raise + idle, 0, j.side * (0.1 + roar * 0.6))
		elseif k == "wing" then
			local rate = entry.flies and (6 + moving * 5) or (2 + moving * 6)
			local amp = entry.flies and 0.55 or 0.2 + moving * 0.3
			local flap = math.sin(tt * rate) * amp + roar * 0.6
			cf = CFrame.Angles(0, 0, j.side * flap)
		elseif k == "tail" then
			cf = CFrame.Angles(math.sin(tt * 2) * 0.08, math.sin(tt * 3.2 + j.idx) * 0.35, 0)
		elseif k == "neckseg" then
			-- pescoço articulado: cada segmento acompanha parte do movimento da cabeça, com ondulação suave
			local sway = math.sin(tt * 1.3 - j.idx * 0.6) * 0.05
			cf = CFrame.Angles(-strike * 0.12 + wind * 0.1 - roar * 0.14 + sway, math.sin(tt * 0.7 - j.idx * 0.3) * 0.06 * (1 - moving), 0)
		elseif k == "tailseg" then
			-- onda que percorre a cauda articulada (atrasada e mais suave a cada segmento)
			cf = CFrame.Angles(math.sin(tt * 2 - j.idx * 0.6) * 0.05, math.sin(tt * 3.2 - j.idx * 0.9) * (0.16 + moving * 0.06), 0)
		elseif k == "lid" then
			-- piscar: a cada ~3-5 s a pálpebra desce sobre o olho por ~0,15 s (fechada ao ser derrotado)
			local cyc = (tt * 0.27 + entry.seed) % 1
			local blink = dead and 1 or (cyc < 0.04 and math.sin(cyc / 0.04 * math.pi) or 0)
			j.motor.Transform = CFrame.new(0, -j.drop * blink, -j.push * blink) -- já no referencial do olho
			continue
		elseif k == "seg" then
			cf = CFrame.Angles(math.sin(tt * 2.5 - j.idx * 0.7) * 0.05, math.sin(tt * 3 - j.idx * 0.8) * (0.22 + moving * 0.15), 0)
		elseif k == "ear" then
			local twitch = math.max(0, math.sin(tt * 1.7 + j.side * 2)) ^ 8 * 0.4
			cf = CFrame.Angles(-twitch, 0, j.side * twitch * 0.5)
		elseif k == "orbit" then
			cf = CFrame.Angles(0, (tt * (j.name == "Orbit2" and -0.8 or 1.2)) % (math.pi * 2), 0)
		elseif k == "petal" then
			local open = 0.15 * math.sin(tt * 1.5 + j.idx) + roar * 0.5 + wind * 0.3
			cf = CFrame.Angles(open, 0, 0)
		elseif k == "jaw" then
			local open = math.max(strike, wind * 0.6, roar, breathHold * 0.9) * 0.45
			cf = CFrame.Angles(open, 0, 0)
		elseif k == "root" then
			cf = CFrame.Angles(math.sin(tt * 1.2 + j.idx) * 0.06 - wind * 0.2 * slam, 0, 0)
		end
		j.motor.Transform = rs(j, cf)
	end

	if entry.prism then
		local shift = (t * 0.12) % 1
		for _, pdata in ipairs(entry.prism) do
			pdata.part.Color = Color3.fromHSV((pdata.h + shift) % 1, pdata.s, pdata.v)
		end
	end
end

function Animator.init()
	for i = 1, HIGHLIGHT_POOL do
		local h = Instance.new("Highlight")
		h.Name = "HitFlash" .. i
		h.FillColor = Color3.fromRGB(255, 255, 255)
		h.OutlineTransparency = 1
		h.FillTransparency = 0.35
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Enabled = false
		h.Parent = workspace.CurrentCamera
		table.insert(highlights, h)
	end
	local function watch(folderName: string, deep: boolean)
		local folder = workspace:WaitForChild(folderName, 30)
		if not folder then
			return
		end
		local function consider(inst)
			if inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChild("Root")) then
				task.defer(track, inst)
			end
		end
		if deep then
			for _, d in ipairs(folder:GetDescendants()) do
				consider(d)
			end
			folder.DescendantAdded:Connect(consider)
		else
			for _, c in ipairs(folder:GetChildren()) do
				consider(c)
			end
			folder.ChildAdded:Connect(consider)
		end
	end
	task.spawn(watch, "Pets", true)
	task.spawn(watch, "Enemies", false)
	task.spawn(watch, "Bosses", false)

	local t = 0
	local frame = 0
	RunService.Stepped:Connect(function(_, dt)
		t += dt
		frame += 1
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		local now = serverNow()
		for model, entry in pairs(tracked) do
			if model.Parent and entry.root.Parent then
				local d = (entry.root.Position - camPos).Magnitude
				-- LOD: longe = atualiza menos; muito longe = não anima (bosses sempre)
				local limit = entry.isBoss and 600 or 260
				if d < limit and (d < 120 or entry.isBoss or (frame + math.floor(entry.seed * 10)) % 3 == 0) then
					animate(entry, t, d < 120 and dt or dt * 3, now)
				end
			else
				tracked[model] = nil
			end
		end
	end)
end

Animator.track = track
Animator._tracked = tracked -- (testes)
return Animator

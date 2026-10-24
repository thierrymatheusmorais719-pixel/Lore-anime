-- Espada no corpo: monta o R15 padrão (RigBuilder) com a arma do Shinigami (WeaponBuilder.attach),
-- roda o AnimController e resolve a cinemática (Part1 = Part0 * C0 * Transform * C1⁻¹) para medir
-- se a lâmina atravessa o tronco — embainhada, sacada, andando e nos golpes.
local RigBuilder = MODULE("Shared/Builders/RigBuilder")
local WeaponBuilder = MODULE("Shared/Builders/WeaponBuilder")
local Factions = MODULE("Shared/Config/Factions")

local character = RigBuilder.build("Tester", {})
local hrp = character:FindFirstChild("HumanoidRootPart")
hrp.CFrame = CFrame.new(0, 3, 0)
hrp.Position = Vector3.new(0, 3, 0)
hrp.AssemblyLinearVelocity = Vector3.zero
hrp.AssemblyAngularVelocity = Vector3.zero
local humanoid = character:FindFirstChildOfClass("Humanoid")
humanoid.FloorMaterial = Enum.Material.Plastic
humanoid.Health = 100
local weapon = WeaponBuilder.buildModel(Factions.Shinigami.weapon, "Reiatsu")
-- posição de cada peça da arma relativa ao cabo (montadas com o cabo na origem)
local relative = {}
for _, p in weapon:GetDescendants() do
	if p:IsA("BasePart") then
		relative[p] = p.CFrame
	end
end
WeaponBuilder.attach(character, weapon, "RightHand")
local handle = weapon.PrimaryPart
local player = SERVICES.Players.LocalPlayer
player.Character = character
character:SetAttribute("Team", "Players")
character.Parent = workspace

local AnimController = MODULE("Client/Controllers/AnimController")
AnimController.Init()
AnimController.Start()

local function solve()
	local cf = { [hrp] = hrp.CFrame }
	local joints = {}
	for _, d in character:GetDescendants() do
		if (d:IsA("Motor6D") or d:IsA("Weld")) and d.Enabled ~= false and d.Part0 and d.Part1 then
			table.insert(joints, d)
		end
	end
	local changed = true
	while changed do
		changed = false
		for _, j in joints do
			if cf[j.Part0] and not cf[j.Part1] then
				-- STIFF_BODY: como era antes da correção das AnimationConstraints (só a arma animada)
				local transform = if STIFF_BODY and j.Name ~= "Weapon" then CFrame.identity else (j.Transform or CFrame.identity)
				cf[j.Part1] = cf[j.Part0] * (j.C0 or CFrame.identity) * transform * (j.C1 or CFrame.identity):Inverse()
				changed = true
			end
		end
	end
	return cf
end

local function measure()
	local cf = solve()
	local h = cf[handle]
	if not h then
		return nil
	end
	local worst, worstName = -math.huge, ""
	for _, torsoName in { "UpperTorso", "LowerTorso", "Head" } do
		local torso = character:FindFirstChild(torsoName)
		local tcf = cf[torso]
		local half = torso.Size / 2
		for part, rel in relative do
			if part.Name:find("Blade") or part.Name == "Kissaki" or part.Name == "TrailHost" then
				local world = h * rel
				for k = -4, 4 do
					local p = world * Vector3.new(0, 0, k / 8 * part.Size.Z)
					local l = tcf:PointToObjectSpace(p)
					-- profundidade dentro da caixa (positivo = dentro)
					local depth = math.min(half.X - math.abs(l.X), half.Y - math.abs(l.Y), half.Z - math.abs(l.Z))
					if depth > worst then
						worst, worstName = depth, torsoName
					end
				end
			end
		end
	end
	return worst, worstName
end

local function step(seconds, velocity)
	hrp.AssemblyLinearVelocity = velocity
	local worst, where = -math.huge, ""
	for _ = 1, math.floor(seconds * 60) do
		CLOCK += 1 / 60
		RUN_QUEUE()
		SERVICES.RunService.Stepped:Fire(CLOCK, 1 / 60)
		local d, w = measure()
		if d and d > worst then
			worst, where = d, w
		end
	end
	return worst, where
end

-- folga mínima da lâmina ao tronco e à cabeça nas posturas de parado/andar (nos golpes a lâmina
-- pode passar perto; só não pode entrar)
local function report(label, worst, where, clearance)
	local inside = worst > -(clearance or 0) + 0.02
	print(string.format("%-5s %-26s lâmina %s (%.2f studs %s %s)", if inside then "FALHA" else "ok", label,
		if inside then "DENTRO" else "fora", math.abs(worst), if inside then "dentro de" else "da superfície de", where))
end

WeaponBuilder.setDrawn(weapon, false)
character:SetAttribute("Drawn", false)
report("embainhada parado", step(2, Vector3.zero))
report("embainhada andando", step(2, Vector3.new(0, 0, -18)))
report("embainhada correndo", step(2, Vector3.new(0, 0, -27)))
WeaponBuilder.setDrawn(weapon, true)
character:SetAttribute("Drawn", true)
local function withClearance(c)
	return function(worst, where)
		return worst, where, c
	end
end
report("sacada parado (folga 0,6)", withClearance(0.6)(step(2, Vector3.zero)))
report("sacada andando (folga 0,6)", withClearance(0.6)(step(2, Vector3.new(0, 0, -18))))
report("sacada correndo (folga 0,6)", withClearance(0.6)(step(2, Vector3.new(0, 0, -27))))
-- (Draw/Sheathe não são tocados no jogo: a arma troca de solda direto)
for _, name in { "Slash1", "Slash2", "Slash3", "Slash4", "Slash5", "HeavySlash", "Uppercut", "Counter", "Execution", "CastSlash", "Block" } do
	AnimController.Play(character, name, { fadeIn = 0.05 })
	report("golpe " .. name, step(1.2, Vector3.zero))
end

-- pose para a imagem (tools/sim/anim_sim.py desenha as linhas {"label": ...})
local function dumpPose(label)
	local cf = solve()
	local items = {}
	local function add(part, world)
		local c = part.Color or Color3.new(0.6, 0.6, 0.6)
		local r = world.r
		table.insert(items, string.format('{"n":"%s","shape":"Block","s":[%.3f,%.3f,%.3f],"p":[%.3f,%.3f,%.3f],"r":[%s],"c":[%.3f,%.3f,%.3f],"t":0,"m":"Plastic"}',
			part.Name, part.Size.X, part.Size.Y, part.Size.Z, world.p[1], world.p[2], world.p[3],
			table.concat({ r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] }, ","), c.R, c.G, c.B))
	end
	for part, world in cf do
		if part ~= hrp and part:IsA("BasePart") and part.Name ~= "Handle" then
			add(part, world)
		end
	end
	local h = cf[handle]
	if h then
		for part, rel in relative do
			add(part, h * rel)
		end
	end
	print('{"label":"' .. label .. '","parts":[' .. table.concat(items, ",") .. "]}")
end
STIFF_BODY = false
AnimController.StopAll(character, 0, 0) -- o Block fica em loop
character:SetAttribute("Drawn", true)
WeaponBuilder.setDrawn(weapon, true)
step(1.5, Vector3.zero)
dumpPose("Espada sacada — parado")
step(0.3, Vector3.new(0, 0, -18))
dumpPose("Espada sacada — andando")
character:SetAttribute("Drawn", false)
WeaponBuilder.setDrawn(weapon, false)
step(1.5, Vector3.zero)
dumpPose("Embainhada — parado")
STIFF_BODY = true
report("[corpo duro] sacada parado", step(1.5, Vector3.zero))
report("[corpo duro] sacada andando", step(1.5, Vector3.new(0, 0, -18)))

-- atualização de juntas do Roblox: uma cópia AnimationConstraint da empunhadura sobrando no cabo
-- não pode sobreviver a guardar/sacar (era o que deixava a espada atravessada no peito)
local function handleLinks()
	local names = {}
	for _, d in character:GetDescendants() do
		if d:IsA("JointInstance") and (d.Part0 == handle or d.Part1 == handle) then
			table.insert(names, d.Name)
		elseif d:IsA("Constraint") and ((d.Attachment0 and d.Attachment0.Parent == handle) or (d.Attachment1 and d.Attachment1.Parent == handle)) then
			table.insert(names, d.Name)
		end
	end
	table.sort(names)
	return table.concat(names, ",")
end
for _, drawn in { false, true } do
	local a0 = Instance.new("Attachment")
	a0.Parent = character:FindFirstChild("RightHand")
	local a1 = Instance.new("Attachment")
	a1.Parent = handle
	local ghost = Instance.new("AnimationConstraint")
	ghost.Name = "WeaponCopy"
	ghost.Attachment0 = a0
	ghost.Attachment1 = a1
	ghost.Parent = handle
	WeaponBuilder.setDrawn(weapon, drawn)
	local links = handleLinks()
	local want = if drawn then "Weapon" else "HipWeld"
	print(string.format("%-5s %-26s juntas no cabo: %s", if links == want then "ok" else "FALHA",
		if drawn then "sobra removida (sacada)" else "sobra removida (guardada)", links))
end

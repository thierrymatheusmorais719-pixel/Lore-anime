-- Exporta quadros de ATAQUES de bosses (o jogo real no simulador: servidor, cliente, BossVisuals, Animator e Fx)
-- para a prévia em three.js. Para cada boss e cada tipo de golpe (pancada, varrida, magia, rugido, sopro,
-- mergulho), dispara o ataque direto nos atributos do boss e grava o visual anatômico (modo de peças) em
-- instantes da preparação, do golpe e da acomodação, mais as peças de efeito (círculo de runas etc.).
-- Uso: python3 tools/run_tests.py luau --bossatk > saida.txt
--   linhas "SCENE <boss>_<golpe>_<n> [...]" e "BOSSINFO <boss> x y z lookX lookZ altura chão"
-- Variável BOSSATK_ONLY (texto no topo do arquivo, opcional) limita a um boss.
local Worlds = require(__proxy("Shared/Config/Worlds"))
for _, id in ipairs(Worlds.Order) do
	local w = Worlds.Info[id]
	table.insert(SIM.groundPlanes, { center = w.center, radius = w.radius, y = w.center.Y })
end
__modules["Server/Main"](__proxy("Server/Main"))
SIM.run(0.5)
local BossService = require(__proxy("Server/Services/BossService"))
local p = SIM.addPlayer("Jogador", 1)
SIM.run(1)
-- cliente
local Players = game:GetService("Players")
SIM.localPlayer = p
Players.LocalPlayer = p
local pg = Instance.new("PlayerGui")
pg.Name = "PlayerGui"
pg.Parent = p
local uis = Instance.new("UserInputService")
uis.TouchEnabled = false
uis.KeyboardEnabled = true
SIM.registerService("UserInputService", uis)
local cam = Instance.new("Camera")
cam.CFrame = CFrame.new(0, 50, 0)
cam.ViewportSize = Vector2.new(1280, 720)
cam.FieldOfView = 70
workspace.CurrentCamera = cam
local rs = game:GetService("RunService")
rs.RenderStepped = SIM.Signal()
rs.Stepped = SIM.Signal()
local bound = {}
function rs.BindToRenderStep(_, name, _priority, fn)
	bound[name] = fn
end
function rs.UnbindFromRenderStep(_, name)
	bound[name] = nil
end
local function frames(n)
	for _ = 1, n do
		rs.Stepped:Fire(SIM.now, 1 / 60)
		for _, fn in pairs(bound) do
			fn(1 / 60)
		end
		rs.RenderStepped:Fire(1 / 60)
		SIM.run(1 / 60, 1 / 60)
	end
end
-- modo de peças (o que aparece quando o Roblox não libera o EditableMesh)
require(__proxy("Shared/Builders/PetMesh")).available = false
__modules["Client/Main"](__proxy("Client/Main"))
local vis -- visual do boss sendo exportado
local function num(x)
	return string.format("%.3f", x)
end
local function partJson(d, cf)
	local shape = "Block"
	if d.ClassName == "WedgePart" then
		shape = "Wedge"
	elseif d.Shape then
		shape = d.Shape.Name
	end
	if d:FindFirstChildOfClass("SpecialMesh") then
		shape = "Ellipsoid"
	end
	local col = d.Color or Color3.new(0.6, 0.6, 0.6)
	local r = cf.r
	return string.format('{"s":"%s","z":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s],"c":[%d,%d,%d],"m":"%s","t":%s,"l":0}', shape,
		num(d.Size.X), num(d.Size.Y), num(d.Size.Z), num(cf.p.X), num(cf.p.Y), num(cf.p.Z),
		table.concat({ num(r[1]), num(r[2]), num(r[3]), num(r[4]), num(r[5]), num(r[6]), num(r[7]), num(r[8]), num(r[9]) }, ","),
		math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5),
		d.Material and d.Material.Name or "Plastic", num(math.max(d.Transparency or 0, d.LocalTransparencyModifier or 0)))
end
-- resolve as juntas do visual (o simulador não move peças por Motor6D/Weld): Part1 = Part0 · C0 · Transform · C1⁻¹
local function solve(model)
	local cfs = {}
	local joints = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d.ClassName == "Motor6D" or d.ClassName == "Weld" or d.ClassName == "WeldConstraint" then
			table.insert(joints, d)
		end
	end
	local child = {}
	for _, j in ipairs(joints) do
		if j.Part1 then
			child[j.Part1] = true
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and not child[d] then
			cfs[d] = d.CFrame
		end
	end
	local changed = true
	while changed do
		changed = false
		for _, j in ipairs(joints) do
			if j.Part0 and j.Part1 and cfs[j.Part0] and not cfs[j.Part1] then
				if j.ClassName == "WeldConstraint" then
					cfs[j.Part1] = cfs[j.Part0] * (j.Part0.CFrame:Inverse() * j.Part1.CFrame)
				else
					local tr = (j.ClassName == "Motor6D" and j.Transform) or CFrame.new()
					cfs[j.Part1] = cfs[j.Part0] * (j.C0 or CFrame.new()) * tr * (j.C1 or CFrame.new()):Inverse()
				end
				changed = true
			end
		end
	end
	return cfs
end
local function dump(name)
	local out = {}
	local cfs = solve(vis)
	for _, d in ipairs(vis:GetDescendants()) do
		if d:IsA("BasePart") and (d.Transparency or 0) < 1 and d.Name ~= "HumanoidRootPart" then
			table.insert(out, partJson(d, cfs[d] or d.CFrame))
		end
	end
	local fx = cam:FindFirstChild("LocalFx")
	for _, d in ipairs(fx and fx:GetDescendants() or {}) do
		if d:IsA("BasePart") and (d.Transparency or 0) < 0.98 then
			table.insert(out, partJson(d, d.CFrame))
		end
	end
	print("SCENE " .. name .. " [" .. table.concat(out, ",") .. "]")
end


local BossVisuals = require(__proxy("Client/Controllers/BossVisuals"))
local Bosses = require(__proxy("Shared/Config/Bosses"))

local PLAN = {
	{ "elderroot", { "Slam", "Sweep", "Cast", "Roar" } },
	{ "prism_titan", { "Slam", "Breath", "Cast", "Roar" } },
	{ "tempest_wyrm", { "Breath", "Sweep", "Dive", "Roar" } },
	{ "wilderbloom", { "Sweep", "Slam", "Cast", "Roar" } },
	{ "void_sovereign", { "Slam", "Sweep", "Cast", "Roar" } },
}
local WIND = 1.0
local SHOTS = { { -1, "0" }, { 0.45, "1" }, { 0.93, "2" }, { WIND + 0.07, "3" }, { WIND + 0.13, "4" }, { WIND + 0.32, "5" }, { WIND + 0.8, "6" } }

for _, plan in ipairs(PLAN) do
	local id = plan[1]
	if BOSSATK_ONLY and BOSSATK_ONLY ~= id then
		continue
	end
	local boss
	for _, b in ipairs(BossService.list()) do
		if b.id == id then
			boss = b
		end
	end
	if not boss then
		print("INFO sem boss " .. id)
		continue
	end
	local bpos = boss.model.PrimaryPart.Position
	local toCenter = (bpos - boss.arena.center) * Vector3.new(1, 0, 1)
	local standDir = toCenter.Magnitude > 1 and toCenter.Unit or Vector3.new(0, 0, 1)
	SIM.teleport(p, boss.arena.center + Vector3.new(0, 4, 0) - standDir * (boss.arena.radius + 12))
	cam.CFrame = CFrame.new(bpos + Vector3.new(30, 18, 40), bpos)
	local e
	for _ = 1, 120 do
		frames(15)
		e = BossVisuals.entries[boss.model]
		if e and e.vis and e.vis.Parent == boss.model then
			break
		end
	end
	if not (e and e.vis) then
		print("INFO visual não apareceu: " .. id)
		continue
	end
	vis = e.vis
	frames(20)
	local root = boss.model.PrimaryPart
	local look = root.CFrame.LookVector
	local _, size = vis:GetBoundingBox()
	print(string.format("BOSSINFO %s %s %s %s %s %s %s %s", id, num(root.Position.X), num(root.Position.Y), num(root.Position.Z), num(look.X), num(look.Z),
		num(boss.cfg.size or size.Y), num(boss.arena.center.Y)))
	for _, action in ipairs(plan[2]) do
		local t0 = workspace:GetServerTimeNow()
		for _, shot in ipairs(SHOTS) do
			if shot[1] < 0 then
				dump(string.format("%s_%s_%s", id, action, shot[2]))
				boss.model:SetAttribute("Action", action)
				boss.model:SetAttribute("AttackLabel", action)
				boss.model:SetAttribute("AttackPower", false)
				t0 = workspace:GetServerTimeNow()
				boss.model:SetAttribute("ActionAt", t0)
				boss.model:SetAttribute("WindupEnd", t0 + WIND)
			else
				while workspace:GetServerTimeNow() - t0 < shot[1] do
					frames(1)
				end
				dump(string.format("%s_%s_%s", id, action, shot[2]))
			end
		end
		-- volta ao repouso antes do próximo golpe
		boss.model:SetAttribute("Action", nil)
		frames(120)
	end
	local _ = Bosses
end
-- troca de fase (escudo, ondas, círculo) no Prism Titan: SCENE prism_titan_Phase_<n>
do
	local boss
	for _, b in ipairs(BossService.list()) do
		if b.id == "prism_titan" then
			boss = b
		end
	end
	local e = boss and BossVisuals.entries[boss.model]
	if e and e.vis then
		vis = e.vis
		local bpos = boss.model.PrimaryPart.Position
		local toCenter = (bpos - boss.arena.center) * Vector3.new(1, 0, 1)
		local standDir = toCenter.Magnitude > 1 and toCenter.Unit or Vector3.new(0, 0, 1)
		SIM.teleport(p, boss.arena.center + Vector3.new(0, 4, 0) - standDir * (boss.arena.radius + 12))
		cam.CFrame = CFrame.new(bpos + Vector3.new(30, 18, 40), bpos)
		for _ = 1, 20 do
			frames(15)
			if e.vis.Parent == boss.model then
				break
			end
		end
		frames(80)
		local State = require(__proxy("Client/Controllers/State"))
		boss.model:SetAttribute("Action", "Roar")
		boss.model:SetAttribute("ActionAt", workspace:GetServerTimeNow())
		boss.model:SetAttribute("WindupEnd", 0)
		State.emit("Phase", { boss = "Prism Titan", bossId = "prism_titan", phase = 2, label = "Refração", color = boss.cfg.color, time = 2.5 })
		local t0 = os.clock()
		for k, at in ipairs({ 0.1, 0.5, 1.2, 2.0, 2.56 }) do
			while os.clock() - t0 < at do
				frames(1)
			end
			dump(string.format("prism_titan_Phase_%d", k))
		end
	end
end
print("INFO erros " .. #SIM.errors)
for _, er in ipairs(SIM.errors) do
	print("INFO " .. er)
end

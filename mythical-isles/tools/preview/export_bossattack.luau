-- Exporta quadros de um ATAQUE de boss (o jogo real no simulador: servidor, cliente, BossVisuals, Animator e Fx)
-- para a prévia em three.js. Dispara a pancada do Elderroot direto nos atributos do boss e grava o visual
-- anatômico (modo de peças) em instantes da preparação, do golpe e da acomodação, mais as peças de efeito.
-- Uso: python3 tools/run_tests.py luau --bossatk > saida.txt  (linhas "SCENE atk_<n> [...]" e "CAM ...")
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
local boss
for _, b in ipairs(BossService.list()) do
	if b.id == "elderroot" then
		boss = b
	end
end
assert(boss, "sem Elderroot")
-- jogador fora da arena (o boss fica dormindo) mas perto o bastante para o visual novo
local bpos = boss.model.PrimaryPart.Position
local toCenter = (bpos - boss.arena.center) * Vector3.new(1, 0, 1)
local standDir = Vector3.new(0, 0, 1)
if toCenter.Magnitude > 1 then
	standDir = toCenter.Unit
end
SIM.teleport(p, boss.arena.center + Vector3.new(0, 4, 0) - standDir * (boss.arena.radius + 12))

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
cam.CFrame = CFrame.new(bpos + Vector3.new(30, 18, 40), bpos)
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
local BossVisuals = require(__proxy("Client/Controllers/BossVisuals"))
local e
for _ = 1, 80 do
	frames(15)
	e = BossVisuals.entries[boss.model]
	if e and e.vis and e.vis.Parent == boss.model then
		break
	end
end
assert(e and e.vis, "o visual do boss não apareceu")
local vis = e.vis

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

local root = boss.model.PrimaryPart.Position
print(string.format("BOSS %s %s %s", num(root.X), num(root.Y), num(root.Z)))
local look = boss.model.PrimaryPart.CFrame.LookVector
print(string.format("LOOK %s %s %s", num(look.X), num(look.Y), num(look.Z)))
local ground = boss.arena.center.Y
print(string.format("GROUND %s", num(ground)))
frames(30)
dump("atk_0_repouso")
-- pancada: 1,0 s de preparação
local WIND = 1.0
local t0 = workspace:GetServerTimeNow()
boss.model:SetAttribute("Action", "Slam")
boss.model:SetAttribute("ActionAt", t0)
boss.model:SetAttribute("AttackLabel", "Pancada de Raízes")
boss.model:SetAttribute("AttackPower", false)
boss.model:SetAttribute("WindupEnd", t0 + WIND)
local shots = { { 0.35, "atk_1_preparacao" }, { 0.92, "atk_2_carga" }, { WIND + 0.07, "atk_3_golpe" }, { WIND + 0.12, "atk_4_passa_do_ponto" },
	{ WIND + 0.3, "atk_5_recuo" }, { WIND + 0.75, "atk_6_assenta" } }
for _, s in ipairs(shots) do
	while workspace:GetServerTimeNow() - t0 < s[1] do
		frames(1)
	end
	dump(s[2])
end
print("INFO erros " .. #SIM.errors)
for _, er in ipairs(SIM.errors) do
	print("INFO " .. er)
end

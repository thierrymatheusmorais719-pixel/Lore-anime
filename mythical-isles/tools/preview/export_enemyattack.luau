-- Exporta quadros dos ATAQUES dos inimigos comuns (o jogo real no simulador: cliente, Animator e Fx) para a
-- prévia em three.js. Monta cada tipo de inimigo com o construtor do jogo numa fileira longe das ilhas, dispara
-- o ataque próprio dele (golpe, investida, magia ou pancada, com a preparação da config) nos atributos e grava
-- o modelo em instantes da preparação, do golpe e da acomodação.
-- Uso: python3 tools/run_tests.py luau --enemyatk > saida.txt  (linhas "SCENE ea_<inimigo>_<n> [...]" e "ENEMYINFO ...")
local Worlds = require(__proxy("Shared/Config/Worlds"))
for _, id in ipairs(Worlds.Order) do
	local w = Worlds.Info[id]
	table.insert(SIM.groundPlanes, { center = w.center, radius = w.radius, y = w.center.Y })
end
__modules["Server/Main"](__proxy("Server/Main"))
SIM.run(0.5)
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
__modules["Client/Main"](__proxy("Client/Main"))
frames(10)
local vis -- modelo sendo exportado
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



local Enemies = require(__proxy("Shared/Config/Enemies"))
local EnemyModels = require(__proxy("Shared/Builders/EnemyModels"))
local ids = {}
for id in pairs(Enemies.Info) do
	table.insert(ids, id)
end
table.sort(ids)
local BASE = Vector3.new(-3000, 0, 0)
local list = {}
for k, id in ipairs(ids) do
	local cfg = Enemies.Info[id]
	local ok, model, centerHeight = pcall(EnemyModels.build, id, cfg)
	if ok and model then
		local hover = cfg.mover == "hover"
		-- em círculo de raio 70 em volta da câmera: o Animator só anima inimigos a menos de 260 studs (e a cada
		-- quadro só os a menos de 120)
		local a = k / #ids * math.pi * 2
		local pos = BASE + Vector3.new(math.cos(a) * 70, centerHeight + (hover and (cfg.hoverHeight or 6) or 0), math.sin(a) * 70)
		model:PivotTo(CFrame.new(pos)) -- olha para -Z
		model.PrimaryPart.Anchored = true
		model.Parent = workspace:FindFirstChild("Enemies")
		table.insert(list, { id = id, model = model, cfg = cfg })
		print(string.format("ENEMYINFO %s %s %s %s %s %s", id, num(pos.X), num(pos.Y), num(pos.Z), cfg.attack and cfg.attack.kind or "none",
			num(cfg.attack and cfg.attack.windup or 0)))
	else
		print("INFO sem modelo " .. id .. ": " .. tostring(model))
	end
end
cam.CFrame = CFrame.new(BASE + Vector3.new(0, 30, 0), BASE)
frames(30)
local function action(kind)
	return kind == "slam" and "Slam" or kind == "lunge" and "Lunge" or kind == "projectile" and "Cast" or "Attack"
end
-- todos ao mesmo tempo, cada um com a sua preparação; quadros nos mesmos pontos relativos da preparação
for _, e in ipairs(list) do
	vis = e.model
	dump(string.format("ea_%s_0", e.id))
end
local t0 = workspace:GetServerTimeNow()
for _, e in ipairs(list) do
	local atk = e.cfg.attack or { kind = "melee", windup = 0.45 }
	e.windup = math.max(atk.windup or 0.45, 0.3)
	e.model:SetAttribute("Action", action(atk.kind))
	e.model:SetAttribute("ActionAt", t0)
	e.model:SetAttribute("WindupEnd", t0 + e.windup)
end
-- instantes: metade da preparação, fim da preparação, golpe +0,07, +0,13, acomodação +0,32 e +0,8
local REL = { { 0.5, 0, "1" }, { 0.93, 0, "2" }, { 1, 0.07, "3" }, { 1, 0.13, "4" }, { 1, 0.32, "5" }, { 1, 0.8, "6" } }
local pending = {}
for _, e in ipairs(list) do
	for _, r in ipairs(REL) do
		table.insert(pending, { at = e.windup * r[1] + r[2], e = e, tag = r[3] })
	end
end
table.sort(pending, function(a, b)
	return a.at < b.at
end)
for _, pnd in ipairs(pending) do
	while workspace:GetServerTimeNow() - t0 < pnd.at do
		frames(1)
	end
	vis = pnd.e.model
	dump(string.format("ea_%s_%s", pnd.e.id, pnd.tag))
end
print("INFO erros " .. #SIM.errors)
for _, er in ipairs(SIM.errors) do
	print("INFO " .. er)
end

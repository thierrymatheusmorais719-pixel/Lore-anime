-- Auditoria: cilindros que o Roblox desenharia diferente do que o código pretendia.
-- No Roblox o cilindro tem ALTURA = Size.X e DIÂMETRO = o menor de Size.Y/Size.Z. Um tamanho como (0.25, 5, 0.25)
-- vira um disco de 0,25 (o 5 é ignorado). Lista cilindros em que Y e Z diferem muito (uma dimensão desperdiçada).
-- Uso: python3 tools/run_tests.py luau --cylaudit
local Worlds = require(__proxy("Shared/Config/Worlds"))
for _, id in ipairs(Worlds.Order) do
	local w = Worlds.Info[id]
	table.insert(SIM.groundPlanes, { center = w.center, radius = w.radius, y = w.center.Y })
end
__modules["Server/Main"](__proxy("Server/Main"))
SIM.run(0.5)
local bad, seen = {}, 0
local function check(where, d)
	if d:IsA("Part") and d.Shape == Enum.PartType.Cylinder then
		seen += 1
		local s = d.Size
		local hi, lo = math.max(s.Y, s.Z), math.min(s.Y, s.Z)
		if lo > 0 and hi > lo * 1.5 and hi - lo > 0.3 then
			local key = where .. " / " .. d.Name .. string.format(" (%.2f, %.2f, %.2f)", s.X, s.Y, s.Z)
			bad[key] = (bad[key] or 0) + 1
		end
	end
end
-- mundo inteiro (servidor)
for _, d in ipairs(workspace:GetDescendants()) do
	local top = d
	while top.Parent and top.Parent ~= workspace do
		top = top.Parent
	end
	check("mundo:" .. top.Name, d)
end
-- todos os construtores de modelos
local Enemies = require(__proxy("Shared/Config/Enemies"))
local EnemyModels = require(__proxy("Shared/Builders/EnemyModels"))
for id, cfg in pairs(Enemies.Info) do
	local m = EnemyModels.build(id, cfg)
	for _, d in ipairs(m:GetDescendants()) do
		check("inimigo:" .. id, d)
	end
end
local Pets = require(__proxy("Shared/Config/Pets"))
local CreatureBuilder = require(__proxy("Shared/Builders/CreatureBuilder"))
for id, sp in pairs(Pets.Species) do
	local ok, m = pcall(CreatureBuilder.build, id, sp)
	if ok and m then
		for _, d in ipairs(m:GetDescendants()) do
			check("pet:" .. id, d)
		end
	end
end
local BossModels = require(__proxy("Shared/Builders/BossModels"))
local Bosses = require(__proxy("Shared/Config/Bosses"))
for id in pairs(Bosses.Info) do
	local ok, m = pcall(BossModels.build, id)
	if ok and m then
		for _, d in ipairs(m:GetDescendants()) do
			check("boss:" .. id, d)
		end
	end
end
local keys = {}
for k in pairs(bad) do
	table.insert(keys, k)
end
table.sort(keys)
for _, k in ipairs(keys) do
	print(string.format("CILINDRO %s  x%d", k, bad[k]))
end
print(string.format("cilindros vistos: %d, suspeitos: %d tipos", seen, #keys))

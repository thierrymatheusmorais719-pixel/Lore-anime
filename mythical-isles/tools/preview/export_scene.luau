-- Exporta a geometria REAL construída pelo jogo (via simulador) em JSON, para renderização de prévia.
local Worlds = require(__proxy("Shared/Config/Worlds"))
for _, id in ipairs(Worlds.Order) do
	local w = Worlds.Info[id]
	table.insert(SIM.groundPlanes, { center = w.center, radius = w.radius, y = w.center.Y })
end
__modules["Server/Main"](__proxy("Server/Main"))
SIM.run(0.5)

local function num(x)
	return string.format("%.3f", x)
end
local function partJson(p)
	local cf = p.CFrame
	local shape = "Block"
	local cls = p.ClassName
	if cls == "WedgePart" then
		shape = "Wedge"
	elseif cls == "CornerWedgePart" then
		shape = "CornerWedge"
	elseif p.Shape then
		shape = p.Shape.Name
	end
	for _, c in ipairs(p:GetChildren()) do
		if c.ClassName == "SpecialMesh" then
			shape = "Ellipsoid"
		end
	end
	local col = p.Color or Color3.new(0.6, 0.6, 0.6)
	local r = cf.r
	local light = 0
	for _, c in ipairs(p:GetChildren()) do
		if c.ClassName == "PointLight" then
			light = c.Range or 8
		end
	end
	return string.format('{"s":"%s","z":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s],"c":[%d,%d,%d],"m":"%s","t":%s,"l":%s}',
		shape, num(p.Size.X), num(p.Size.Y), num(p.Size.Z), num(cf.p.X), num(cf.p.Y), num(cf.p.Z),
		table.concat({ num(r[1]), num(r[2]), num(r[3]), num(r[4]), num(r[5]), num(r[6]), num(r[7]), num(r[8]), num(r[9]) }, ","),
		math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5),
		p.Material and p.Material.Name or "Plastic", num(p.Transparency or 0), num(light))
end
local function dump(name, roots, filter)
	local out = {}
	for _, root in ipairs(roots) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") and (d.Transparency or 0) < 1 and d.Name ~= "Boundary" and (not filter or filter(d)) then
				table.insert(out, partJson(d))
			end
		end
	end
	print("SCENE " .. name .. " [" .. table.concat(out, ",") .. "]")
end

-- jogador com equipe (um pet mutado) passeando na praça
local S = {
	DataService = require(__proxy("Server/Services/DataService")),
	PetService = require(__proxy("Server/Services/PetService")),
}
local InventoryLogic = require(__proxy("Shared/Logic/InventoryLogic"))
local p = SIM.addPlayer("Jogador", 1)
SIM.run(1)
local d = S.DataService.get(p)
local uids = {}
for _, sp in ipairs({ "bloomfox", "leafwing", "grovekin", "mossling" }) do
	table.insert(uids, InventoryLogic.addPet(d, sp, sp == "bloomfox" and "Golden" or nil, os.time(), "preview").uid)
end
d.team = uids
S.PetService.spawnTeam(p)
SIM.teleport(p, Vector3.new(6, 3, 30))
SIM.run(3)
local char = p.Character
print(string.format("PLAYER %s %s %s", num(char.PrimaryPart.Position.X), num(char.PrimaryPart.Position.Y), num(char.PrimaryPart.Position.Z)))
local verdant = Worlds.Info.verdant
local function inVerdant(part)
	return ((part.Position - verdant.center) * Vector3.new(1, 0, 1)).Magnitude < verdant.radius + 30 and math.abs(part.Position.Y) < 120
end
dump("island", { workspace:FindFirstChild("World"):FindFirstChild("verdant"), workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Bosses"),
	workspace:FindFirstChild("Resources"), workspace:FindFirstChild("Pets") }, inVerdant)

-- terreno (preenchimentos registrados pelo simulador) da ilha 1
do
	local out = {}
	for _, f in ipairs(SIM.terrainFills) do
		local pp = f.cf.p
		if ((pp - verdant.center) * Vector3.new(1, 0, 1)).Magnitude < verdant.radius + 40 and math.abs(pp.Y) < 150 then
			local col = SIM.terrainColors[f.m]
			table.insert(out, string.format('{"k":"%s","p":[%s,%s,%s],"h":%s,"r":%s,"m":"%s","c":[%d,%d,%d]}', f.kind, num(pp.X), num(pp.Y), num(pp.Z),
				num(f.h or (f.size and f.size.Y) or 0), num(f.r or 0), f.m, col and math.floor(col.R * 255) or -1, col and math.floor(col.G * 255) or -1, col and math.floor(col.B * 255) or -1))
		end
	end
	print("SCENE terrain [" .. table.concat(out, ",") .. "]")
end

-- vitrines
local Pets = require(__proxy("Shared/Config/Pets"))
local CreatureBuilder = require(__proxy("Shared/Builders/CreatureBuilder"))
local MutationVisuals = require(__proxy("Shared/Builders/MutationVisuals"))
local EnemyModels = require(__proxy("Shared/Builders/EnemyModels"))
local BossModels = require(__proxy("Shared/Builders/BossModels"))
local Enemies = require(__proxy("Shared/Config/Enemies"))
local Mutations = require(__proxy("Shared/Config/Mutations"))
local Rarities = require(__proxy("Shared/Config/Rarities"))

local function lineup(name, models)
	local holder = Instance.new("Folder")
	for _, m in ipairs(models) do
		m.Parent = holder
	end
	dump(name, { holder })
end
-- pets ordenados por mundo e raridade
local ids = {}
for id in pairs(Pets.Species) do
	table.insert(ids, id)
end
table.sort(ids, function(a, b)
	local sa, sb = Pets.Species[a], Pets.Species[b]
	if sa.world ~= sb.world then
		return Worlds.indexOf(sa.world) < Worlds.indexOf(sb.world)
	end
	return Rarities.rank(sa.rarity) < Rarities.rank(sb.rarity)
end)
local pets = {}
for i, id in ipairs(ids) do
	local m, hover = CreatureBuilder.build(id, Pets.Species[id], 1)
	local col, row = (i - 1) % 7, math.floor((i - 1) / 7)
	m:PivotTo(CFrame.new(col * 7, hover, row * 8) * CFrame.Angles(0, math.rad(200), 0))
	table.insert(pets, m)
end
lineup("pets", pets)
for _, wid in ipairs({ "verdant", "crystal" }) do
	local list = {}
	for id, sp in pairs(Pets.Species) do
		if sp.world == wid and sp.rarity ~= "Celestial" then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = Rarities.rank(Pets.Species[a].rarity), Rarities.rank(Pets.Species[b].rarity)
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	local models = {}
	for i, id in ipairs(list) do
		local m, hover = CreatureBuilder.build(id, Pets.Species[id], 1)
		local col, row = (i - 1) % 10, math.floor((i - 1) / 10)
		local spacing = i == 1 and 0 or 0
		m:PivotTo(CFrame.new(col * 7.5 + spacing, hover, row * 8.5) * CFrame.Angles(0, math.rad(200), 0))
		table.insert(models, m)
	end
	lineup("pets_" .. wid, models)
end
local muts = {}
for i, mid in ipairs({ "none", "Golden", "Radiant", "Prismatic", "Ancient", "Phantom", "Astral" }) do
	local m, hover = CreatureBuilder.build("astral_lion", Pets.Species.astral_lion, 1)
	if mid ~= "none" then
		MutationVisuals.apply(m, mid)
	end
	m:PivotTo(CFrame.new((i - 1) * 8, hover, 0) * CFrame.Angles(0, math.rad(200), 0))
	table.insert(muts, m)
end
lineup("mutations", muts)
local eids = {}
for id, cfg in pairs(Enemies.Info) do
	if not cfg.summon then
		table.insert(eids, id)
	end
end
table.sort(eids, function(a, b)
	return Enemies.Info[a].level < Enemies.Info[b].level
end)
local foes = {}
local x = 0
for i, id in ipairs(eids) do
	local m, h, r = EnemyModels.build(id, Enemies.Info[id])
	local cfg = Enemies.Info[id]
	local hover = cfg.mover == "hover" and (cfg.hoverHeight or 6) * 0.4 or 0
	local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
	m:PivotTo(CFrame.new(col * 16, h + hover, row * 16) * CFrame.Angles(0, math.rad(200), 0))
	table.insert(foes, m)
end
lineup("enemies", foes)
local bosses = {}
local BOSS_X = { 0, 50, 125, 205, 265 }
for i, id in ipairs({ "elderroot", "prism_titan", "tempest_wyrm", "wilderbloom", "void_sovereign" }) do
	local m, h = BossModels.build(id)
	m:PivotTo(CFrame.new(BOSS_X[i], h + (id == "tempest_wyrm" and 6 or 0), 0) * CFrame.Angles(0, math.rad(200), 0))
	table.insert(bosses, m)
end
lineup("bosses", bosses)

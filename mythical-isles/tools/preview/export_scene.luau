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
	return ((part.Position - verdant.center) * Vector3.new(1, 0, 1)).Magnitude < verdant.radius + 30 and part.Position.Y > -120 and part.Position.Y < 360
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
			local sz = f.size or Vector3.new(0, 0, 0)
			local r = f.cf.r
			table.insert(out, string.format('{"k":"%s","p":[%s,%s,%s],"h":%s,"r":%s,"m":"%s","c":[%d,%d,%d],"z":[%s,%s,%s],"rot":[%s]}', f.kind, num(pp.X), num(pp.Y), num(pp.Z),
				num(f.h or sz.Y), num(f.r or 0), f.m, col and math.floor(col.R * 255) or -1, col and math.floor(col.G * 255) or -1, col and math.floor(col.B * 255) or -1,
				num(sz.X), num(sz.Y), num(sz.Z), table.concat({ num(r[1]), num(r[2]), num(r[3]), num(r[4]), num(r[5]), num(r[6]), num(r[7]), num(r[8]), num(r[9]) }, ",")))
		end
	end
	print("SCENE terrain [" .. table.concat(out, ",") .. "]")
end

-- Mundo 2 (Crystal Hollow): peças e terreno
do
	local crystal = Worlds.Info.crystal
	local function inCrystal(part)
		return ((part.Position - crystal.center) * Vector3.new(1, 0, 1)).Magnitude < crystal.radius + 40 and math.abs(part.Position.Y) < 180
	end
	dump("crystal", { workspace:FindFirstChild("World"):FindFirstChild("crystal"), workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Bosses"),
		workspace:FindFirstChild("Resources") }, inCrystal)
	local out = {}
	for _, f in ipairs(SIM.terrainFills) do
		local pp = f.cf.p
		if ((pp - crystal.center) * Vector3.new(1, 0, 1)).Magnitude < crystal.radius + 60 and math.abs(pp.Y) < 200 then
			local col = SIM.terrainColors[f.m]
			local sz = f.size or Vector3.new(0, 0, 0)
			local r = f.cf.r
			table.insert(out, string.format('{"k":"%s","p":[%s,%s,%s],"h":%s,"r":%s,"m":"%s","c":[%d,%d,%d],"z":[%s,%s,%s],"rot":[%s]}', f.kind, num(pp.X), num(pp.Y), num(pp.Z),
				num(f.h or sz.Y), num(f.r or 0), f.m, col and math.floor(col.R * 255) or -1, col and math.floor(col.G * 255) or -1, col and math.floor(col.B * 255) or -1,
				num(sz.X), num(sz.Y), num(sz.Z), table.concat({ num(r[1]), num(r[2]), num(r[3]), num(r[4]), num(r[5]), num(r[6]), num(r[7]), num(r[8]), num(r[9]) }, ",")))
		end
	end
	print("SCENE terrain_crystal [" .. table.concat(out, ",") .. "]")
end

-- Mundo 3 (Skybound Kingdom): peças, terreno e nuvens de tempestade
do
	local sky = Worlds.Info.sky
	local function inSky(part)
		local d = ((part.Position - sky.center) * Vector3.new(1, 0, 1)).Magnitude
		return d < (sky.extent or 400) + 30 and math.abs(part.Position.Y - sky.center.Y) < 260
	end
	dump("sky", { workspace:FindFirstChild("World"):FindFirstChild("sky"), workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Bosses"),
		workspace:FindFirstChild("Resources") }, inSky)
	local out = {}
	for _, f in ipairs(SIM.terrainFills) do
		local pp = f.cf.p
		if ((pp - sky.center) * Vector3.new(1, 0, 1)).Magnitude < (sky.extent or 400) + 60 and math.abs(pp.Y - sky.center.Y) < 260 then
			local col = SIM.terrainColors[f.m]
			local sz = f.size or Vector3.new(0, 0, 0)
			local r = f.cf.r
			table.insert(out, string.format('{"k":"%s","p":[%s,%s,%s],"h":%s,"r":%s,"m":"%s","c":[%d,%d,%d],"z":[%s,%s,%s],"rot":[%s]}', f.kind, num(pp.X), num(pp.Y), num(pp.Z),
				num(f.h or sz.Y), num(f.r or 0), f.m, col and math.floor(col.R * 255) or -1, col and math.floor(col.G * 255) or -1, col and math.floor(col.B * 255) or -1,
				num(sz.X), num(sz.Y), num(sz.Z), table.concat({ num(r[1]), num(r[2]), num(r[3]), num(r[4]), num(r[5]), num(r[6]), num(r[7]), num(r[8]), num(r[9]) }, ",")))
		end
	end
	print("SCENE terrain_sky [" .. table.concat(out, ",") .. "]")
	local storms = {}
	for _, d in ipairs(workspace:FindFirstChild("World"):FindFirstChild("sky"):GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("CloudKind") then
			table.insert(storms, string.format('[%s,%s,%s,%s,"%s"]', num(d.Position.X), num(d.Position.Y), num(d.Position.Z), num(d:GetAttribute("CloudWidth") or 100), d:GetAttribute("CloudKind")))
		end
	end
	print("SCENE storm_sky [" .. table.concat(storms, ",") .. "]")
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

-- vitrine de perto: um pet de cada tipo de corpo
local show = {}
for i, id in ipairs({ "kit_1", "hop_1", "fawn_1", "leafcat_1", "owlet_1", "verdantwolf_1", "petalfox_1", "sproutslime_1", "cap_1", "ent_1", "drakeling_1", "grovetortoise_1" }) do
	if Pets.Species[id] then
		local m, hover = CreatureBuilder.build(id, Pets.Species[id], 1)
		local col, row = (i - 1) % 6, math.floor((i - 1) / 6)
		m:PivotTo(CFrame.new(col * 6, hover, row * 7) * CFrame.Angles(0, math.rad(205), 0))
		table.insert(show, m)
	else
		print("WARN showcase sem espécie " .. id)
	end
end
lineup("showcase", show)

-- 2ª leva do Mundo 1 (panda de folhas, cabra-arbusto, mamute de capim): frente e perfil
local novos = {}
local NX = { 0, 6, 12, 18, 25, 32, 39, 50, 62, 76 }
for i, id in ipairs({ "leafpanda_1", "leafpanda_2", "leafpanda_3", "leafpanda_4", "berrygoat_1", "berrygoat_2", "berrygoat_3", "turfmammoth_1", "turfmammoth_2", "eldermammoth_1" }) do
	local m, hover = CreatureBuilder.build(id, Pets.Species[id], 1)
	m:PivotTo(CFrame.new(NX[i], hover, 0) * CFrame.Angles(0, math.rad(i % 2 == 0 and 230 or 200), 0))
	table.insert(novos, m)
end
lineup("pets_novos", novos)

-- céu anime de cada mundo (paleta + layout, para o renderizador desenhar igual ao jogo)
do
	local AnimeSky = require(__proxy("Shared/Builders/AnimeSky"))
	local function col(c)
		return string.format("[%d,%d,%d]", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
	end
	for _, wid in ipairs(Worlds.Order) do
		local t = AnimeSky.theme(wid)
		local L = AnimeSky.layout(wid)
		local parts = {}
		local stops = {}
		for _, st in ipairs(AnimeSky.gradient(wid)) do
			table.insert(stops, string.format("[%s,%s]", num(st[1]), col(st[2])))
		end
		table.insert(parts, '"stops":[' .. table.concat(stops, ",") .. "]")
		local tk = {}
		for _, k in ipairs({ "top", "mid", "horizon", "below", "cloud", "shade", "hi", "streak", "sun", "glow", "fog", "decay", "tint", "ambient" }) do
			table.insert(tk, string.format('"%s":%s', k, col(t[k])))
		end
		table.insert(parts, '"theme":{' .. table.concat(tk, ",") .. string.format(',"moon":%s,"stars":%s}', tostring(t.moon == true), tostring(t.stars == true)))
		local cl = {}
		for _, c in ipairs(L.clouds) do
			local pf = {}
			for _, p in ipairs(c.puffs) do
				table.insert(pf, string.format('[%s,%s,%s,"%s"]', num(p.x), num(p.y), num(p.r), p.layer))
			end
			table.insert(cl, string.format('{"az":%s,"elev":%s,"dist":%s,"w":%s,"h":%s,"base":%s,"puffs":[%s]}', num(c.az), num(c.elev), num(c.dist), num(c.w), num(c.h), num(c.base), table.concat(pf, ",")))
		end
		table.insert(parts, '"clouds":[' .. table.concat(cl, ",") .. "]")
		local sk = {}
		for _, s in ipairs(L.streaks) do
			table.insert(sk, string.format("[%s,%s,%s,%s,%s]", num(s.az), num(s.elev), num(s.dist), num(s.w), num(s.h)))
		end
		table.insert(parts, '"streaks":[' .. table.concat(sk, ",") .. "]")
		local stz = {}
		for _, s in ipairs(L.stars) do
			table.insert(stz, string.format("[%s,%s,%s]", num(s.az), num(s.elev), num(s.size)))
		end
		table.insert(parts, '"stars":[' .. table.concat(stz, ",") .. "]")
		table.insert(parts, string.format('"panel":[%s,%s,%s]', num(AnimeSky.PANEL_DIST), num(AnimeSky.PANEL_LOW), num(AnimeSky.PANEL_HIGH)))
		print("SCENE sky_" .. wid .. " {" .. table.concat(parts, ",") .. "}")
	end
end

-- posições dos lugares do anel de mata (para enquadrar as prévias)
do
	local WB = require(__proxy("Server/Services/WorldBuilder"))
	for _, id in ipairs({ "verdant", "crystal", "wilds", "astral" }) do
		local plan = WB.ringPlan(id)
		for _, p in ipairs(plan and plan.pois or {}) do
			print(string.format("POI %s %s %.0f %.0f %.0f entrada %.2f %.2f", id, p.kind, p.pos.X, p.pos.Y, p.pos.Z, p.inward.X, p.inward.Z))
		end
	end
end

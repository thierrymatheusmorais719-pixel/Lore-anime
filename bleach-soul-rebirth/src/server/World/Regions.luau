-- Construtores das quatro regiões. Cada função recebe a pasta da região e o centro do mundo.
-- Protótipo jogável com peças simples, organizado para ser substituído por modelos próprios
-- (basta trocar o conteúdo da função mantendo as áreas livres de spawns/portais/chefes).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Build = require(script.Parent.Build)

local Regions = {}

local function keepOutFor(zoneId: string, extra: { { position: Vector3, radius: number } }?)
	local zone = Zones.List[zoneId]
	local list = {}
	for _, s in Zones.Spawners do
		if s.zone == zoneId then
			table.insert(list, { position = zone.center + s.position, radius = s.radius + 14 })
		end
	end
	for _, b in Zones.Bosses do
		if b.zone == zoneId then
			table.insert(list, { position = zone.center + b.position, radius = b.arena + 6 })
		end
	end
	for _, p in Zones.Portals do
		if p.zone == zoneId then
			table.insert(list, { position = zone.center + p.position, radius = 16 })
		end
	end
	for _, t in Zones.TravelPoints do
		if t.zone == zoneId then
			table.insert(list, { position = zone.center + t.position, radius = 14 })
		end
	end
	if extra then
		for _, e in extra do
			table.insert(list, e)
		end
	end
	return list
end

-- Muro de contenção invisível nas bordas da região
local function boundary(folder: Instance, center: Vector3, size: Vector3)
	local h = 120
	for _, side in
		{
			{ Vector3.new(size.X / 2, 0, 0), Vector3.new(2, h, size.Z) },
			{ Vector3.new(-size.X / 2, 0, 0), Vector3.new(2, h, size.Z) },
			{ Vector3.new(0, 0, size.Z / 2), Vector3.new(size.X, h, 2) },
			{ Vector3.new(0, 0, -size.Z / 2), Vector3.new(size.X, h, 2) },
		}
	do
		local wall = Build.part(
			folder,
			side[2],
			CFrame.new(center + side[1] + Vector3.new(0, h / 2, 0)),
			Color3.new(),
			Enum.Material.SmoothPlastic,
			"Boundary"
		)
		wall.Transparency = 1
		wall.CanQuery = false
	end
end

-- ===================== KARAKURA =====================
function Regions.Karakura(folder: Instance)
	local zone = Zones.List.Karakura
	local c = zone.center
	local rng = Random.new(1001)
	local size = Vector2.new(zone.size.X, zone.size.Z)
	Build.ground(c, size, Enum.Material.Concrete)
	boundary(folder, c, zone.size)

	local roads = Build.folder(folder, "Roads")
	local asphalt = Color3.fromRGB(48, 50, 56)
	local stripe = Color3.fromRGB(230, 230, 220)
	local avenues = { -150, 0, 150 }
	for _, x in avenues do
		Build.part(
			roads,
			Vector3.new(18, 0.4, size.Y),
			CFrame.new(c + Vector3.new(x, 0.2, 0)),
			asphalt,
			Enum.Material.Asphalt,
			"Road"
		)
		for z = -size.Y / 2 + 10, size.Y / 2 - 10, 16 do
			Build.part(
				roads,
				Vector3.new(0.5, 0.42, 6),
				CFrame.new(c + Vector3.new(x, 0.22, z)),
				stripe,
				Enum.Material.SmoothPlastic,
				"Stripe"
			)
		end
	end
	for _, z in avenues do
		Build.part(
			roads,
			Vector3.new(size.X, 0.4, 18),
			CFrame.new(c + Vector3.new(0, 0.21, z)),
			asphalt,
			Enum.Material.Asphalt,
			"Road"
		)
	end

	-- Praça central
	local plaza = Build.folder(folder, "Plaza")
	Build.cylinder(
		plaza,
		0.6,
		70,
		CFrame.new(c + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(175, 170, 160),
		Enum.Material.Pavement
	)
	Build.cylinder(
		plaza,
		2.5,
		14,
		CFrame.new(c + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(140, 140, 145),
		Enum.Material.Marble
	)
	local crystal = Build.part(
		plaza,
		Vector3.new(2.5, 9, 2.5),
		CFrame.new(c + Vector3.new(0, 7, 0)) * CFrame.Angles(0, math.rad(45), math.rad(8)),
		Color3.fromRGB(120, 190, 255),
		Enum.Material.Neon,
		"SpiritCrystal"
	)
	Build.light(crystal, Color3.fromRGB(120, 190, 255), 40, 2)
	for i = 0, 7 do
		local angle = i * math.pi / 4
		local p = c + Vector3.new(math.cos(angle) * 30, 0, math.sin(angle) * 30)
		if i % 2 == 0 then
			Build.lamp(plaza, p)
		else
			Build.tree(plaza, p, "cherry", rng)
		end
	end

	-- Bairros
	local extra = {
		{ position = c, radius = 45 },
	}
	local keepOut = keepOutFor("Karakura", extra)
	local houses = Build.folder(folder, "Houses")
	for gx = -200, 200, 36 do
		for gz = -200, 200, 36 do
			local point = c + Vector3.new(gx, 0, gz)
			local nearRoad = false
			for _, a in avenues do
				if math.abs(gx - a) < 24 or math.abs(gz - a) < 24 then
					nearRoad = true
				end
			end
			if not nearRoad and Build.clear(point, keepOut) and rng:NextNumber() < 0.85 then
				local w, d = rng:NextInteger(16, 24), rng:NextInteger(14, 22)
				local floors = if rng:NextNumber() < 0.25 then 3 elseif rng:NextNumber() < 0.6 then 2 else 1
				local facing = if rng:NextNumber() < 0.5 then 0 else math.pi
				Build.house(houses, CFrame.new(point) * CFrame.Angles(0, facing, 0), w, d, floors, rng)
			end
		end
	end

	-- Postes ao longo das avenidas
	local lamps = Build.folder(folder, "Lamps")
	for _, a in avenues do
		for t = -210, 210, 42 do
			local p1 = c + Vector3.new(a + 11, 0, t)
			local p2 = c + Vector3.new(t, 0, a + 11)
			if Build.clear(p1, { { position = c, radius = 36 } }) then
				Build.lamp(lamps, p1)
			end
			if Build.clear(p2, { { position = c, radius = 36 } }) then
				Build.lamp(lamps, p2)
			end
		end
	end

	-- Rio a oeste com ponte
	workspace.Terrain:FillBlock(
		CFrame.new(c + Vector3.new(-205, -2, 0)),
		Vector3.new(26, 6, zone.size.Z - 4),
		Enum.Material.Water
	)
	Build.part(
		folder,
		Vector3.new(30, 1.2, 14),
		CFrame.new(c + Vector3.new(-205, 1, 150)),
		Color3.fromRGB(120, 85, 60),
		Enum.Material.Wood,
		"Bridge"
	)

	-- Escola (arena do chefe ao norte)
	local boss = Zones.Bosses[1]
	local arena = c + boss.position
	local school = Build.folder(folder, "School")
	Build.part(
		school,
		Vector3.new(90, 26, 20),
		CFrame.new(arena + Vector3.new(0, 13, 75)),
		Color3.fromRGB(225, 222, 210),
		Enum.Material.Concrete,
		"SchoolBuilding"
	)
	for x = -40, 40, 8 do
		local w = Build.part(
			school,
			Vector3.new(4, 4, 0.3),
			CFrame.new(arena + Vector3.new(x, 18, 64.8)),
			Color3.fromRGB(40, 50, 70),
			Enum.Material.Glass,
			"Window"
		)
		w.Transparency = 0.2
	end
	Build.part(
		school,
		Vector3.new(120, 0.3, 110),
		CFrame.new(arena + Vector3.new(0, 0.15, 0)),
		Color3.fromRGB(150, 110, 80),
		Enum.Material.Ground,
		"Field"
	)
	for x = -60, 60, 6 do
		Build.part(
			school,
			Vector3.new(0.3, 6, 0.3),
			CFrame.new(arena + Vector3.new(x, 3, -55)),
			Color3.fromRGB(90, 100, 95),
			Enum.Material.Metal,
			"Fence"
		)
	end
	Build.part(
		school,
		Vector3.new(120, 0.3, 0.3),
		CFrame.new(arena + Vector3.new(0, 5.8, -55)),
		Color3.fromRGB(90, 100, 95),
		Enum.Material.Metal,
		"FenceRail"
	)
	for _, x in { -55, 55 } do
		Build.lamp(school, arena + Vector3.new(x, 0, -40), Color3.fromRGB(200, 220, 255))
	end
end

-- ===================== CAMPO DE TREINO =====================
function Regions.Training(folder: Instance)
	local zone = Zones.List.Training
	local c = zone.center
	local rng = Random.new(2002)
	Build.ground(c, Vector2.new(zone.size.X, zone.size.Z), Enum.Material.Sandstone)
	boundary(folder, c, zone.size)
	local keepOut = keepOutFor("Training", { { position = c, radius = 40 } })

	-- Paredões de rocha na borda (cânion)
	local rocks = Build.folder(folder, "Rocks")
	for i = 0, 47 do
		local angle = i / 48 * math.pi * 2
		local radius = zone.size.X / 2 - 12
		local p = c + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local h = rng:NextNumber(30, 70)
		Build.part(
			rocks,
			Vector3.new(rng:NextNumber(18, 30), h, rng:NextNumber(18, 30)),
			CFrame.new(p + Vector3.new(0, h / 2 - 2, 0)) * CFrame.Angles(0, angle, math.rad(rng:NextNumber(-6, 6))),
			Color3.fromRGB(165, 125, 95),
			Enum.Material.Rock,
			"Cliff"
		)
	end
	-- Pedras e espinhos no interior
	for _ = 1, 40 do
		local p = c + Vector3.new(rng:NextNumber(-150, 150), 0, rng:NextNumber(-150, 150))
		if Build.clear(p, keepOut) then
			local h = rng:NextNumber(6, 22)
			Build.part(
				rocks,
				Vector3.new(rng:NextNumber(4, 10), h, rng:NextNumber(4, 10)),
				CFrame.new(p + Vector3.new(0, h / 2 - 1, 0))
					* CFrame.Angles(
						math.rad(rng:NextNumber(-10, 10)),
						rng:NextNumber(0, 6),
						math.rad(rng:NextNumber(-10, 10))
					),
				Color3.fromRGB(150, 115, 90),
				Enum.Material.Rock,
				"Spire"
			)
		end
	end

	-- Arena PvP central (marcação + tochas)
	local arena = Build.folder(folder, "Arena")
	Build.cylinder(
		arena,
		0.4,
		70,
		CFrame.new(c + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(130, 95, 70),
		Enum.Material.Slate
	)
	local ring = Build.cylinder(
		arena,
		0.45,
		72,
		CFrame.new(c + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 160, 80),
		Enum.Material.Neon
	)
	ring.Transparency = 0.4
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		local p = c + Vector3.new(math.cos(angle) * 38, 0, math.sin(angle) * 38)
		Build.part(
			arena,
			Vector3.new(1.4, 8, 1.4),
			CFrame.new(p + Vector3.new(0, 4, 0)),
			Color3.fromRGB(80, 60, 45),
			Enum.Material.Wood,
			"Torch"
		)
		local flame = Build.part(
			arena,
			Vector3.new(1.6, 1.6, 1.6),
			CFrame.new(p + Vector3.new(0, 8.8, 0)),
			Color3.fromRGB(255, 150, 60),
			Enum.Material.Neon,
			"Flame"
		)
		Build.light(flame, Color3.fromRGB(255, 150, 70), 24, 1.5)
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Parent = flame
	end
	local sign = Build.part(
		arena,
		Vector3.new(10, 3, 0.5),
		CFrame.new(c + Vector3.new(0, 3, -40)),
		Color3.fromRGB(60, 40, 30),
		Enum.Material.Wood,
		"PvPSign"
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "ARENA · PvP LIBERADO"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 200, 120)
	label.Parent = gui
	gui.Parent = sign

	-- Arenas dos chefes (círculos rúnicos)
	for _, b in Zones.Bosses do
		if b.zone == "Training" then
			local p = c + b.position
			local circle = Build.cylinder(
				arena,
				0.3,
				b.arena * 1.4,
				CFrame.new(p + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(90, 70, 120),
				Enum.Material.Slate
			)
			circle.Name = "BossCircle"
			local glow = Build.cylinder(
				arena,
				0.32,
				b.arena * 1.45,
				CFrame.new(p + Vector3.new(0, 0.13, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(150, 110, 255),
				Enum.Material.Neon
			)
			glow.Transparency = 0.5
		end
	end
end

-- ===================== SOUL SOCIETY =====================
function Regions.SoulSociety(folder: Instance)
	local zone = Zones.List.SoulSociety
	local c = zone.center
	local rng = Random.new(3003)
	Build.ground(c, Vector2.new(zone.size.X, zone.size.Z), Enum.Material.Pavement)
	boundary(folder, c, zone.size)
	local white = Color3.fromRGB(238, 234, 226)
	local roof = Color3.fromRGB(45, 48, 60)
	local wood = Color3.fromRGB(110, 60, 45)
	local keepOut = keepOutFor("SoulSociety", { { position = c, radius = 50 } })

	-- Muros brancos do Seireitei com telhas (labirinto em grade)
	local walls = Build.folder(folder, "Walls")
	local function wall(from: Vector3, to: Vector3)
		local mid = (from + to) / 2
		local length = (to - from).Magnitude
		local frame = CFrame.lookAt(mid, to)
		Build.part(walls, Vector3.new(3, 14, length), frame * CFrame.new(0, 7, 0), white, Enum.Material.Plaster, "Wall")
		Build.part(
			walls,
			Vector3.new(6, 1.2, length + 2),
			frame * CFrame.new(0, 14.4, 0),
			roof,
			Enum.Material.Slate,
			"WallRoof"
		)
	end
	for _, x in { -170, -90, 90, 170 } do
		for z = -190, 150, 85 do
			local a = c + Vector3.new(x, 0, z)
			local b = c + Vector3.new(x, 0, z + 60)
			if Build.clear((a + b) / 2, keepOut) then
				wall(a, b)
			end
		end
	end
	for _, z in { -110, 60 } do
		for x = -200, 160, 90 do
			local a = c + Vector3.new(x, 0, z)
			local b = c + Vector3.new(x + 60, 0, z)
			if Build.clear((a + b) / 2, keepOut) then
				wall(a, b)
			end
		end
	end

	-- Portão principal (sul)
	local gate = Build.folder(folder, "Gate")
	local gp = c + Vector3.new(0, 0, -195)
	for _, x in { -16, 16 } do
		Build.part(
			gate,
			Vector3.new(4, 34, 4),
			CFrame.new(gp + Vector3.new(x, 17, 0)),
			wood,
			Enum.Material.Wood,
			"Pillar"
		)
	end
	Build.part(gate, Vector3.new(44, 3, 6), CFrame.new(gp + Vector3.new(0, 34, 0)), wood, Enum.Material.Wood, "Beam")
	Build.part(
		gate,
		Vector3.new(52, 2, 9),
		CFrame.new(gp + Vector3.new(0, 37, 0)),
		roof,
		Enum.Material.Slate,
		"GateRoof"
	)

	-- Torre central (Pagode) e pátio de treino
	local tower = Build.folder(folder, "Tower")
	local tp = c + Vector3.new(0, 0, 120)
	for i = 0, 4 do
		local s = 40 - i * 6
		local y = i * 14
		Build.part(
			tower,
			Vector3.new(s, 12, s),
			CFrame.new(tp + Vector3.new(0, y + 6, 0)),
			white,
			Enum.Material.Plaster,
			"Floor"
		)
		Build.part(
			tower,
			Vector3.new(s + 8, 1.5, s + 8),
			CFrame.new(tp + Vector3.new(0, y + 12.75, 0)),
			roof,
			Enum.Material.Slate,
			"Eave"
		)
	end
	local spire = Build.part(
		tower,
		Vector3.new(2, 14, 2),
		CFrame.new(tp + Vector3.new(0, 82, 0)),
		Color3.fromRGB(230, 190, 90),
		Enum.Material.Neon,
		"Spire"
	)
	Build.light(spire, Color3.fromRGB(255, 220, 140), 60, 1.5)

	-- Pátio central com cerejeiras e lanternas
	local garden = Build.folder(folder, "Garden")
	Build.cylinder(
		garden,
		0.4,
		80,
		CFrame.new(c + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(205, 195, 175),
		Enum.Material.Sand
	)
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		Build.tree(garden, c + Vector3.new(math.cos(angle) * 44, 0, math.sin(angle) * 44), "cherry", rng)
	end
	for _ = 1, 25 do
		local p = c + Vector3.new(rng:NextNumber(-200, 200), 0, rng:NextNumber(-200, 200))
		if Build.clear(p, keepOut) then
			Build.tree(garden, p, "cherry", rng)
		end
	end
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2 + 0.2
		local p = c + Vector3.new(math.cos(angle) * 28, 0, math.sin(angle) * 28)
		Build.part(
			garden,
			Vector3.new(1.6, 4, 1.6),
			CFrame.new(p + Vector3.new(0, 2, 0)),
			Color3.fromRGB(130, 130, 125),
			Enum.Material.Slate,
			"LanternBase"
		)
		local l = Build.part(
			garden,
			Vector3.new(2.4, 2.4, 2.4),
			CFrame.new(p + Vector3.new(0, 5.2, 0)),
			Color3.fromRGB(255, 220, 160),
			Enum.Material.Neon,
			"Lantern"
		)
		Build.light(l, Color3.fromRGB(255, 210, 150), 18, 1)
	end
end

-- ===================== HUECO MUNDO =====================
function Regions.HuecoMundo(folder: Instance)
	local zone = Zones.List.HuecoMundo
	local c = zone.center
	local rng = Random.new(4004)
	Build.ground(c, Vector2.new(zone.size.X, zone.size.Z), Enum.Material.Sand)
	boundary(folder, c, zone.size)
	local keepOut = keepOutFor("HuecoMundo", {})

	-- Dunas (bolas de areia parcialmente enterradas)
	for _ = 1, 26 do
		local p = c + Vector3.new(rng:NextNumber(-290, 290), 0, rng:NextNumber(-290, 290))
		if Build.clear(p, keepOut) then
			workspace.Terrain:FillBall(
				p - Vector3.new(0, rng:NextNumber(14, 22), 0),
				rng:NextNumber(22, 40),
				Enum.Material.Sand
			)
		end
	end

	-- Árvores de quartzo
	local trees = Build.folder(folder, "QuartzTrees")
	for _ = 1, 60 do
		local p = c + Vector3.new(rng:NextNumber(-300, 300), 0, rng:NextNumber(-300, 300))
		if Build.clear(p, keepOut) then
			Build.tree(trees, p, "dead", rng)
		end
	end

	-- Ruínas do palácio (arena do Rei)
	local boss = nil
	for _, b in Zones.Bosses do
		if b.zone == "HuecoMundo" then
			boss = b
		end
	end
	if boss then
		local ruins = Build.folder(folder, "Ruins")
		local p = c + boss.position
		Build.cylinder(
			ruins,
			1,
			boss.arena * 2.2,
			CFrame.new(p + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(235, 232, 225),
			Enum.Material.Marble
		)
		for i = 0, 11 do
			local angle = i / 12 * math.pi * 2
			local radius = boss.arena + 6
			local pos = p + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local h = if i % 3 == 0 then rng:NextNumber(10, 18) else rng:NextNumber(28, 46)
			Build.part(
				ruins,
				Vector3.new(6, h, 6),
				CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, angle, math.rad(rng:NextNumber(-5, 5))),
				Color3.fromRGB(240, 238, 232),
				Enum.Material.Marble,
				"Pillar"
			)
		end
		-- Cúpula quebrada ao fundo
		Build.ball(
			ruins,
			150,
			CFrame.new(p + Vector3.new(0, -20, 150)),
			Color3.fromRGB(240, 238, 232),
			Enum.Material.Marble
		)
	end

	-- Lua crescente gigante no horizonte
	local sky = Build.folder(folder, "Sky")
	local moonCenter = c + Vector3.new(0, 260, 520)
	for i = -6, 6 do
		local a = i / 6 * math.rad(70)
		local pos = moonCenter + Vector3.new(math.sin(a) * 80, math.cos(a) * 80, 0)
		local thickness = 22 * (1 - math.abs(i) / 7.5)
		local piece = Build.part(
			sky,
			Vector3.new(thickness, 26, 4),
			CFrame.new(pos) * CFrame.Angles(0, 0, -a),
			Color3.fromRGB(245, 245, 235),
			Enum.Material.Neon,
			"Moon"
		)
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CastShadow = false
	end
end

return Regions

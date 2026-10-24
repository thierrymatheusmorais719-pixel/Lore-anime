-- Construtores das quatro regiões. Cada função recebe a pasta da região e o centro do mundo.
-- Protótipo jogável com peças simples, organizado para ser substituído por modelos próprios
-- (basta trocar o conteúdo da função mantendo as áreas livres de spawns/portais/chefes).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Build = require(script.Parent.Build)
local Town = require(script.Parent.Town)
local NPCs = require(ReplicatedStorage.Shared.Config.NPCs)

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
-- Cidade à noite: centro comercial (prédios de vários andares, letreiros, loja de conveniência,
-- rua comercial coberta) cercado por bairros residenciais (casas japonesas com muro e portão),
-- avenidas com calçada, faixas, semáforos e postes com fiação, trilho elevado a leste, rio com
-- margem e ponte a oeste, escola ao norte (arena do chefe). Áreas de spawn, chefes, portais,
-- pontos de viagem e NPCs ficam livres.
function Regions.Karakura(folder: Instance)
	local zone = Zones.List.Karakura
	local c = zone.center
	local rng = Random.new(1001)
	local size = Vector2.new(zone.size.X, zone.size.Z)
	local halfX, halfZ = size.X / 2, size.Y / 2
	Build.ground(c, size, Enum.Material.Concrete)
	boundary(folder, c, zone.size)

	-- áreas livres
	local extra = { { position = c, radius = 45 } }
	for _, npc in NPCs do
		if npc.zone == "Karakura" then
			table.insert(extra, { position = c + npc.position, radius = 9 })
		end
	end
	-- rua comercial (a oeste-norte do centro)
	local arcadeCenter = c + Vector3.new(-75, 0, 75)
	for dz = -50, 50, 20 do
		table.insert(extra, { position = arcadeCenter + Vector3.new(0, 0, dz), radius = 22 })
	end
	local keepOut = keepOutFor("Karakura", extra)

	-- ruas: asfalto, faixa central, calçadas com meio-fio, faixas de pedestre, semáforos
	local roads = Build.folder(folder, "Roads")
	local asphalt = Color3.fromRGB(44, 46, 52)
	local stripe = Color3.fromRGB(230, 220, 160)
	local avenues = { -150, 0, 150 }
	local ROAD = 18
	for _, a in avenues do
		Build.part(
			roads,
			Vector3.new(ROAD, 0.4, size.Y),
			CFrame.new(c + Vector3.new(a, 0.2, 0)),
			asphalt,
			Enum.Material.Asphalt,
			"Road"
		)
		Build.part(
			roads,
			Vector3.new(size.X, 0.4, ROAD),
			CFrame.new(c + Vector3.new(0, 0.21, a)),
			asphalt,
			Enum.Material.Asphalt,
			"Road"
		)
		Town.sidewalks(roads, c + Vector3.new(a, 0, 0), size.Y, ROAD, false)
		Town.sidewalks(roads, c + Vector3.new(0, 0, a), size.X, ROAD, true)
		for t = -halfZ + 10, halfZ - 10, 14 do
			local nearCross = false
			for _, b in avenues do
				if math.abs(t - b) < 16 then
					nearCross = true
				end
			end
			if not nearCross then
				Build.part(
					roads,
					Vector3.new(0.5, 0.42, 6),
					CFrame.new(c + Vector3.new(a, 0.22, t)),
					stripe,
					Enum.Material.SmoothPlastic,
					"Stripe"
				)
				Build.part(
					roads,
					Vector3.new(6, 0.43, 0.5),
					CFrame.new(c + Vector3.new(t, 0.23, a)),
					stripe,
					Enum.Material.SmoothPlastic,
					"Stripe"
				)
			end
		end
	end
	for _, ax in avenues do
		for _, az in avenues do
			local corner = c + Vector3.new(ax, 0, az)
			for _, s in { -1, 1 } do
				Town.crosswalk(roads, corner + Vector3.new(s * 13, 0, 0), ROAD, false)
				Town.crosswalk(roads, corner + Vector3.new(0, 0, s * 13), ROAD, true)
			end
			Town.trafficLight(
				roads,
				CFrame.new(corner + Vector3.new(11.5, 0.6, 11.5)) * CFrame.Angles(0, math.rad(-90), 0)
			)
			Town.trafficLight(
				roads,
				CFrame.new(corner + Vector3.new(-11.5, 0.6, -11.5)) * CFrame.Angles(0, math.rad(90), 0)
			)
		end
	end

	-- postes de concreto com fiação ao longo de todas as avenidas (lado de fora da calçada)
	local poles = Build.folder(folder, "Poles")
	for _, a in avenues do
		for _, alongX in { false, true } do
			local last: Vector3? = nil
			for t = -halfZ + 12, halfZ - 12, 30 do
				local onCross = false
				for _, b in avenues do
					if math.abs(t - b) < 14 then
						onCross = true
					end
				end
				local pos = if alongX then c + Vector3.new(t, 0.6, a + 12.4) else c + Vector3.new(a - 12.4, 0.6, t)
				if onCross or not Build.clear(pos, keepOut) then
					last = nil
				else
					local top = Town.utilityPole(poles, pos, rng)
					if last then
						for k, dy in { 0, -0.7, -1.4 } do
							Town.wire(poles, last + Vector3.new(0, dy, 0), top + Vector3.new(0, dy, 0), 1.2 + k * 0.2)
						end
					end
					last = top
				end
			end
		end
	end
	-- postes de luz alternados com os de fiação
	local lamps = Build.folder(folder, "Lamps")
	for _, a in avenues do
		for t = -halfZ + 27, halfZ - 27, 60 do
			for _, p in { c + Vector3.new(a + 12.4, 0.6, t), c + Vector3.new(t, 0.6, a - 12.4) } do
				if Build.clear(p, keepOut) then
					Build.lamp(lamps, p)
				end
			end
		end
	end

	-- praça central (cristal espiritual, postes e cerejeiras)
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
		0.62,
		52,
		CFrame.new(c + Vector3.new(0, 0.31, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(150, 146, 140),
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

	-- lotes nas bordas de cada quarteirão, de frente para a rua
	local cuts = { -halfX, -150, 0, 150, halfX }
	local MARGIN = 14.5
	local buildings = Build.folder(folder, "Buildings")
	local houses = Build.folder(folder, "Houses")
	local riverEdge = -halfX + 42 -- a oeste disso fica o rio e a margem
	local props = Build.folder(folder, "StreetProps")
	local konbiniDone = false
	local function placeLot(center: Vector3, facing: Vector3, frontage: number, depth: number, downtown: boolean)
		if not Build.clear(center, keepOut) or center.X - c.X < riverEdge then
			return
		end
		local cf = CFrame.lookAt(center, center + facing)
		if downtown then
			local dist = Vector2.new(center.X - c.X, center.Z - c.Z).Magnitude
			-- horizonte: torres de 20+ andares no miolo, caindo para prédios médios nas bordas
			local floors = math.clamp(math.floor(27 - dist / 8.5 + rng:NextInteger(-3, 3)), 6, 30)
			if not konbiniDone and dist < 110 and dist > 60 and rng:NextNumber() < 0.25 then
				konbiniDone = true
				Town.konbini(buildings, cf, rng)
			elseif floors >= 11 then
				Town.tower(buildings, cf, frontage - 2, depth, floors, rng)
			else
				Town.building(buildings, cf, frontage - 2, depth, floors, rng)
			end
		elseif rng:NextNumber() < 0.3 then
			-- prédios médios misturados às casas fora do centro
			Town.building(buildings, cf, frontage - 4, depth - 4, rng:NextInteger(4, 8), rng)
		else
			local w, d = frontage - 6, depth - 8
			Town.house(houses, cf, w, d, rng)
			-- bicicleta encostada no muro e lixo na calçada de alguns
			if rng:NextNumber() < 0.35 then
				Town.bicycle(
					props,
					cf * CFrame.new(w / 2 - 1.5, 0.3, -d / 2 - 6.2) * CFrame.Angles(0, math.rad(90), 0),
					rng
				)
			end
			if rng:NextNumber() < 0.25 then
				Town.trash(props, (cf * CFrame.new(-w / 2 + 1.5, 0.3, -d / 2 - 6.5)).Position, rng)
			end
		end
	end
	for xi = 1, #cuts - 1 do
		for zi = 1, #cuts - 1 do
			local x0, x1 =
				cuts[xi] + (if xi == 1 then 6 else MARGIN), cuts[xi + 1] - (if xi == #cuts - 1 then 6 else MARGIN)
			local z0, z1 =
				cuts[zi] + (if zi == 1 then 6 else MARGIN), cuts[zi + 1] - (if zi == #cuts - 1 then 6 else MARGIN)
			local downtown = xi >= 2 and xi <= 3 and zi >= 2 and zi <= 3
			local depth = if downtown then rng:NextInteger(28, 38) else 26
			-- frentes: norte/sul (ao longo de X) e leste/oeste (ao longo de Z, encurtadas nas quinas)
			for _, edge in
				{
					{ z0, Vector3.new(0, 0, -1), true },
					{ z1, Vector3.new(0, 0, 1), true },
					{ x0, Vector3.new(-1, 0, 0), false },
					{ x1, Vector3.new(1, 0, 0), false },
				}
			do
				local fixed, facing, alongX = edge[1], edge[2], edge[3]
				local from = if alongX then x0 else z0 + depth
				local to = if alongX then x1 else z1 - depth
				local t = from
				while to - t > 14 do
					local frontage = math.min(to - t, rng:NextInteger(24, if downtown then 36 else 30))
					local mid = t + frontage / 2
					local inward = -facing * (depth / 2)
					local center = if alongX
						then c + Vector3.new(mid, 0, fixed) + inward
						else c + Vector3.new(fixed, 0, mid) + inward
					placeLot(center, facing, frontage, depth, downtown)
					t += frontage
				end
			end
			-- miolo do quarteirão: gramado com árvores
			local inner = c + Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2)
			if Build.clear(inner, keepOut) and (x1 - x0) > 60 and (z1 - z0) > 60 then
				workspace.Terrain:FillBlock(
					CFrame.new(inner.X, -0.6, inner.Z),
					Vector3.new(30, 1.2, 30),
					Enum.Material.Grass
				)
				for _ = 1, 3 do
					local p = inner + Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
					Build.tree(houses, p, if rng:NextNumber() < 0.5 then "cherry" else "pine", rng)
				end
			end
		end
	end
	-- máquinas de venda nas calçadas
	for _ = 1, 22 do
		local a = avenues[rng:NextInteger(1, 3)]
		local t = rng:NextNumber(-halfZ + 20, halfZ - 20)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local alongX = rng:NextNumber() < 0.5
		local p = if alongX then c + Vector3.new(t, 0.6, a + side * 13.6) else c + Vector3.new(a + side * 13.6, 0.6, t)
		local ok = Build.clear(p, keepOut)
		for _, b in avenues do
			if math.abs(t - b) < 16 then
				ok = false
			end
		end
		if ok then
			local face = if alongX then Vector3.new(0, 0, -side) else Vector3.new(-side, 0, 0)
			Town.vending(lamps, CFrame.lookAt(p, p + face), rng)
		end
	end

	-- carros estacionados junto ao meio-fio, poças, bueiros, canteiros com árvores
	local function nearCrossing(t: number, margin: number): boolean
		for _, b in avenues do
			if math.abs(t - b) < margin then
				return true
			end
		end
		return false
	end
	for _, a in avenues do
		for _, alongX in { false, true } do
			for _, side in { -1, 1 } do
				local t = -halfZ + 20 + rng:NextNumber(0, 15)
				while t < halfZ - 20 do
					local pos = if alongX
						then c + Vector3.new(t, 0.4, a + side * 6.2)
						else c + Vector3.new(a + side * 6.2, 0.4, t)
					if not nearCrossing(t, 24) and Build.clear(pos, keepOut) and rng:NextNumber() < 0.45 then
						local forward = if alongX then Vector3.new(side, 0, 0) else Vector3.new(0, 0, side)
						Town.car(props, CFrame.lookAt(pos, pos + forward), rng)
					end
					t += rng:NextNumber(16, 30)
				end
			end
			-- canteiros na calçada (centro e bairros), entre os postes
			for t = -halfZ + 30, halfZ - 30, 60 do
				for _, side in { -1, 1 } do
					local pos = if alongX
						then c + Vector3.new(t + 15, 0.6, a + side * 11.2)
						else c + Vector3.new(a + side * 11.2, 0.6, t + 15)
					if not nearCrossing(t + 15, 20) and Build.clear(pos, keepOut) then
						local cf = if alongX
							then CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0)
							else CFrame.new(pos)
						Town.planter(props, cf, rng, rng:NextNumber() < 0.6)
					end
				end
			end
			for _ = 1, 8 do
				local t = rng:NextNumber(-halfZ + 15, halfZ - 15)
				local off = rng:NextNumber(-6, 6)
				local pos = if alongX then c + Vector3.new(t, 0.42, a + off) else c + Vector3.new(a + off, 0.42, t)
				Town.puddle(props, pos, rng)
			end
			for t = -halfZ + 25, halfZ - 25, 55 do
				if not nearCrossing(t, 16) then
					Town.manhole(props, if alongX then c + Vector3.new(t, 0, a + 3) else c + Vector3.new(a - 3, 0, t))
				end
			end
		end
	end

	-- rua comercial coberta
	Town.arcade(folder, CFrame.new(arcadeCenter), 110, rng)

	-- trilho elevado ao longo da avenida leste
	Town.railway(folder, c + Vector3.new(150, 0, -halfZ + 4), c + Vector3.new(150, 0, halfZ - 4), 26, function(p)
		return not Build.clear(p, keepOut)
	end)

	-- rio a oeste: água, margens em rampa de grama, calçadão, ponte com guarda-corpo e postes
	local river = Build.folder(folder, "River")
	local riverX = -halfX + 25
	workspace.Terrain:FillBlock(
		CFrame.new(c + Vector3.new(riverX, -2.5, 0)),
		Vector3.new(26, 7, zone.size.Z - 4),
		Enum.Material.Water
	)
	for _, s in { -1, 1 } do
		Build.wedge(
			river,
			Vector3.new(zone.size.Z - 4, 4, 6),
			CFrame.new(c + Vector3.new(riverX + s * 16, -1, 0))
				* CFrame.Angles(0, math.rad(if s < 0 then -90 else 90), 0),
			Color3.fromRGB(70, 100, 60),
			Enum.Material.Grass
		)
	end
	Build.part(
		river,
		Vector3.new(6, 0.5, zone.size.Z - 4),
		CFrame.new(c + Vector3.new(riverX + 22, 0.25, 0)),
		Color3.fromRGB(150, 130, 105),
		Enum.Material.Pavement,
		"Promenade"
	)
	for z = -halfZ + 20, halfZ - 20, 40 do
		local p = c + Vector3.new(riverX + 24.5, 0.5, z)
		if Build.clear(p, keepOut) then
			Build.lamp(river, p, Color3.fromRGB(200, 220, 255))
		end
	end
	local bridgeZ = 150
	local bridge = Build.part(
		river,
		Vector3.new(44, 1.4, 16),
		CFrame.new(c + Vector3.new(riverX + 8, 1, bridgeZ)),
		Color3.fromRGB(150, 150, 155),
		Enum.Material.Concrete,
		"Bridge"
	)
	for _, s in { -1, 1 } do
		Build.part(
			river,
			Vector3.new(44, 2.2, 0.5),
			bridge.CFrame * CFrame.new(0, 1.8, s * 7.6),
			Color3.fromRGB(190, 60, 50),
			Enum.Material.Metal,
			"Railing"
		)
		for x = -18, 18, 12 do
			Build.part(
				river,
				Vector3.new(0.6, 3.4, 0.6),
				bridge.CFrame * CFrame.new(x, 2.4, s * 7.6),
				Color3.fromRGB(190, 60, 50),
				Enum.Material.Metal,
				"Post"
			)
		end
	end

	-- escola ao norte (arena do chefe): prédio com janelas, relógio, quadra, grade
	local boss = Zones.Bosses[1]
	local arena = c + boss.position
	local school = Build.folder(folder, "School")
	local schoolCf = CFrame.new(arena + Vector3.new(0, 0, 75))
	Town.building(school, schoolCf * CFrame.Angles(0, math.pi, 0), 90, 20, 3, Random.new(77))
	local clock = Build.cylinder(
		school,
		0.6,
		6,
		schoolCf * CFrame.new(0, 24, -10.4) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(240, 240, 235),
		Enum.Material.SmoothPlastic
	)
	clock.Name = "Clock"
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

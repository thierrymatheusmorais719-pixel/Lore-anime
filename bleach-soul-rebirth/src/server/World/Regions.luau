-- Construtores das quatro regiões. Cada função recebe a pasta da região e o centro do mundo.
-- Protótipo jogável com peças simples, organizado para ser substituído por modelos próprios
-- (basta trocar o conteúdo da função mantendo as áreas livres de spawns/portais/chefes).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Build = require(script.Parent.Build)
local Town = require(script.Parent.Town)
local Seireitei = require(script.Parent.Seireitei)
local Hueco = require(script.Parent.Hueco)
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
			local floors = math.clamp(math.floor(24 - dist / 9 + rng:NextInteger(-4, 3)), 6, 26)
			if not konbiniDone and dist < 110 and dist > 60 and rng:NextNumber() < 0.25 then
				konbiniDone = true
				Town.konbini(buildings, cf, rng)
			elseif floors >= 14 then
				Town.tower(buildings, cf, frontage - 2, depth, floors, rng)
			else
				Town.building(buildings, cf, frontage - 2, depth, floors, rng)
			end
		elseif rng:NextNumber() < 0.6 then
			-- prédios médios dominam a paisagem (como no anime), com casas entre eles
			Town.building(buildings, cf, frontage - 4, depth - 4, rng:NextInteger(4, 10), rng)
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
			-- miolo do quarteirão: na maioria, mais prédios (Karakura é um mar de prédios); às vezes
			-- um pátio com gramado e árvores
			local inner = c + Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2)
			local courtyard = rng:NextNumber() < 0.3
			if not courtyard then
				local ix0, ix1 = x0 + depth + 3, x1 - depth - 3
				local iz0, iz1 = z0 + depth + 3, z1 - depth - 3
				local cell = 24
				local nx, nz = math.floor((ix1 - ix0) / cell), math.floor((iz1 - iz0) / cell)
				for gx = 0, nx - 1 do
					for gz = 0, nz - 1 do
						local spanX, spanZ = (ix1 - ix0) / nx, (iz1 - iz0) / nz
						local p = c + Vector3.new(ix0 + (gx + 0.5) * spanX, 0, iz0 + (gz + 0.5) * spanZ)
						if Build.clear(p, keepOut) and p.X - c.X >= riverEdge then
							local facing = ({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis })[rng:NextInteger(
								1,
								4
							)]
							local floors = if downtown then rng:NextInteger(7, 14) else rng:NextInteger(4, 9)
							-- largura é o eixo X local: virado para ±X, a largura corre ao longo de Z
							local sideways = math.abs(facing.X) > 0.5
							Town.building(
								buildings,
								CFrame.lookAt(p, p + facing),
								(if sideways then spanZ else spanX) - 4,
								(if sideways then spanX else spanZ) - 4,
								floors,
								rng
							)
						end
					end
				end
			end
			if courtyard and Build.clear(inner, keepOut) and (x1 - x0) > 60 and (z1 - z0) > 60 then
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
	-- cidade até o horizonte em volta da área jogável (sem invadir as outras regiões)
	local others = {}
	for id, other in Zones.List do
		if id ~= "Karakura" then
			table.insert(others, {
				position = other.center,
				radius = math.max(other.size.X, other.size.Z) * 0.6,
			})
		end
	end
	Town.skyline(folder, c, math.max(halfX, halfZ), 1500, others, Random.new(2002))

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
-- Seireitei planejado como no anime: o Portão (sul) abre na avenida principal, que corta a
-- praça central (lago com ponte arqueada) e termina no pagode de cinco andares (norte). Dos dois
-- lados, quarteirões murados das divisões (muros brancos com telha, portão com estandarte,
-- salões em pódio). Leste: campo de treino (bonecos). Noroeste: colina do Sōkyoku e o pátio em
-- ruínas onde os Hollows invadem. Nordeste: torre Senzaikyū e o pátio de chegada do Rukongai.
-- Fora dos muros, um mar de telhados até as montanhas. Spawns, portais, viagem e NPCs ficam livres.
function Regions.SoulSociety(folder: Instance)
	local zone = Zones.List.SoulSociety
	local c = zone.center
	local rng = Random.new(3003)
	local half = zone.size.X / 2
	Build.ground(c, Vector2.new(zone.size.X, zone.size.Z), Enum.Material.Pavement)
	boundary(folder, c, zone.size)
	local extra = { { position = c, radius = 52 } }
	for _, npc in NPCs do
		if npc.zone == "SoulSociety" then
			table.insert(extra, { position = c + npc.position, radius = 9 })
		end
	end
	local keepOut = keepOutFor("SoulSociety", extra)
	local function at(x: number, z: number): Vector3
		return c + Vector3.new(x, 0, z)
	end

	-- ruas de pedra: avenida principal (N-S) e duas transversais
	local streets = Build.folder(folder, "Streets")
	local paving = Color3.fromRGB(196, 190, 178)
	local function road(center: Vector3, size: Vector2)
		local p = Build.part(
			streets,
			Vector3.new(size.X, 0.3, size.Y),
			CFrame.new(center + Vector3.new(0, 0.15, 0)),
			paving,
			Enum.Material.Cobblestone,
			"Road"
		)
		p.CanQuery = true
		-- meio-fio escuro dos dois lados
		local alongZ = size.Y > size.X
		for _, s in { -1, 1 } do
			Build.part(
				streets,
				if alongZ then Vector3.new(0.8, 0.5, size.Y) else Vector3.new(size.X, 0.5, 0.8),
				CFrame.new(
					center
						+ (
							if alongZ
								then Vector3.new(s * size.X / 2, 0.25, 0)
								else Vector3.new(0, 0.25, s * size.Y / 2)
						)
				),
				Color3.fromRGB(120, 116, 108),
				Enum.Material.Granite,
				"Curb"
			)
		end
	end
	road(at(0, -60), Vector2.new(26, 330))
	road(at(0, -110), Vector2.new(2 * half - 16, 18))
	road(at(0, 60), Vector2.new(2 * half - 16, 18))

	-- muro externo (com a abertura do portão)
	local walls = Build.folder(folder, "Walls")
	local edge = half - 8
	Seireitei.wall(walls, at(-edge, edge), at(edge, edge), 18)
	Seireitei.wall(walls, at(-edge, -edge), at(-edge, edge), 18)
	Seireitei.wall(walls, at(edge, -edge), at(edge, edge), 18)
	Seireitei.wall(walls, at(-edge, -edge), at(-33, -edge), 18)
	Seireitei.wall(walls, at(33, -edge), at(edge, -edge), 18)
	Seireitei.gate(walls, CFrame.new(at(0, -edge)), 26, "瀞霊門")

	-- quarteirões das divisões: muro em volta, portão com estandarte voltado para a rua
	local divisions = {
		"一番隊",
		"二番隊",
		"三番隊",
		"四番隊",
		"五番隊",
		"六番隊",
		"七番隊",
		"八番隊",
		"九番隊",
		"十番隊",
		"十一番隊",
		"十二番隊",
		"十三番隊",
	}
	local nextDivision = 1
	local compounds = Build.folder(folder, "Divisions")
	local function compound(x0: number, x1: number, z0: number, z1: number, gateSide: string, fill: string?)
		local model = Instance.new("Model")
		model.Name = "Compound"
		local gateW = 14
		local corners = { at(x0, z0), at(x1, z0), at(x1, z1), at(x0, z1) }
		local sides = { south = { 1, 2 }, east = { 2, 3 }, north = { 3, 4 }, west = { 4, 1 } }
		for name, idx in sides do
			local a, b = corners[idx[1]], corners[idx[2]]
			if name == gateSide then
				local mid = (a + b) / 2
				local dir = (b - a).Unit
				Seireitei.wall(model, a, mid - dir * gateW / 2, 12)
				Seireitei.wall(model, mid + dir * gateW / 2, b, 12)
				-- portãozinho: dois pilares, viga e telhado
				local outward = Vector3.new(dir.Z, 0, -dir.X)
				local toCenter = at((x0 + x1) / 2, (z0 + z1) / 2) - mid
				if outward:Dot(toCenter) > 0 then
					outward = -outward
				end
				local gcf = CFrame.lookAt(mid, mid + outward)
				for _, s in { -1, 1 } do
					Build.part(
						model,
						Vector3.new(1.6, 14, 1.6),
						gcf * CFrame.new(s * (gateW / 2 + 0.6), 7, 0),
						Seireitei.Colors.wood,
						Enum.Material.Wood,
						"GatePost"
					)
				end
				Build.part(
					model,
					Vector3.new(gateW + 3, 1.4, 2),
					gcf * CFrame.new(0, 13.6, 0),
					Seireitei.Colors.wood,
					Enum.Material.Wood,
					"GateBeam"
				)
				Seireitei.roof(model, gcf * CFrame.new(0, 14.4, 0), gateW + 3, 4, 2.4, 1.6)
				if not fill and divisions[nextDivision] then
					Seireitei.banner(model, gcf * CFrame.new(gateW / 2 + 3, 0, -2), divisions[nextDivision])
					nextDivision += 1
				end
			else
				Seireitei.wall(model, a, b, 12)
			end
		end
		-- pátio de cascalho claro
		Build.part(
			model,
			Vector3.new(x1 - x0 - 4, 0.2, z1 - z0 - 4),
			CFrame.new(at((x0 + x1) / 2, (z0 + z1) / 2) + Vector3.new(0, 0.1, 0)),
			Color3.fromRGB(214, 208, 192),
			Enum.Material.Sand,
			"Yard"
		)
		local w, d = x1 - x0, z1 - z0
		local mid = at((x0 + x1) / 2, (z0 + z1) / 2)
		-- frente dos salões para o portão
		local facing = ({
			south = Vector3.new(0, 0, -1),
			north = Vector3.new(0, 0, 1),
			east = Vector3.new(1, 0, 0),
			west = Vector3.new(-1, 0, 0),
		})[gateSide]
		local depthAxis = if math.abs(facing.Z) > 0 then d else w
		local spanAxis = if math.abs(facing.Z) > 0 then w else d
		if fill ~= "open" then
			-- salão principal no fundo, frente para o portão
			local hw = math.min(spanAxis - 22, 46)
			local hd = math.min(depthAxis * 0.4, 24)
			local hallPos = mid - facing * (depthAxis / 2 - hd / 2 - 9)
			if Build.clear(hallPos, keepOut) then
				Seireitei.hall(model, CFrame.lookAt(hallPos, hallPos + facing), hw, hd, {
					floors = if rng:NextNumber() < 0.45 then 2 else 1,
					height = rng:NextNumber(11, 14),
				})
			end
			-- salão menor de lado
			local side = Vector3.new(facing.Z, 0, -facing.X)
			local smallPos = mid + side * (spanAxis / 2 - 13) + facing * 4
			if spanAxis > 60 and Build.clear(smallPos, keepOut) then
				Seireitei.hall(model, CFrame.lookAt(smallPos, smallPos - side), 16, 12, { height = 10, podium = 1.6 })
			end
		end
		-- lanternas junto ao caminho do portão e árvores
		for _, s in { -1, 1 } do
			local side = Vector3.new(facing.Z, 0, -facing.X)
			local p = mid + facing * (depthAxis / 2 - 10) + side * s * 6
			if Build.clear(p, keepOut) then
				Seireitei.lantern(model, p)
			end
		end
		for _ = 1, rng:NextInteger(2, 4) do
			local p = mid + Vector3.new(rng:NextNumber(-w / 2 + 8, w / 2 - 8), 0, rng:NextNumber(-d / 2 + 8, d / 2 - 8))
			if Build.clear(p, keepOut) then
				Build.tree(model, p, if rng:NextNumber() < 0.65 then "cherry" else "pine", rng)
			end
		end
		model.Parent = compounds
	end
	-- sul (entre o portão e a transversal sul)
	compound(-edge + 4, -118, -edge + 4, -121, "north")
	compound(-114, -46, -edge + 4, -121, "east")
	compound(16, 110, -edge + 4, -121, "west")
	compound(114, edge - 4, -edge + 4, -121, "north")
	-- meio (a praça central fica livre)
	compound(-edge + 4, -136, -99, 49, "east")
	compound(-132, -58, -99, 49, "east")
	-- leste-meio: campo de treino (bonecos), salão do dojo ao fundo
	compound(58, edge - 4, -99, 49, "west", "open")
	Seireitei.hall(compounds, CFrame.lookAt(at(150, 30), at(150, 0)), 44, 20, { height = 14, floors = 1 })
	for i = 0, 5 do
		local p = at(80 + i * 22, -88)
		Build.part(
			compounds,
			Vector3.new(1.2, 6, 1.2),
			CFrame.new(p + Vector3.new(0, 3, 0)),
			Seireitei.Colors.wood,
			Enum.Material.Wood,
			"TrainingPost"
		)
		Build.part(
			compounds,
			Vector3.new(3, 0.8, 0.8),
			CFrame.new(p + Vector3.new(0, 4.6, 0)),
			Seireitei.Colors.wood,
			Enum.Material.Wood,
			"TrainingArm"
		)
	end
	-- norte (a praça do pagode fica no eixo)
	compound(-100, -34, 71, edge - 4, "east")
	compound(34, 100, 71, 150, "west")
	compound(104, edge - 4, 150, edge - 4, "south", "open")

	-- praça central: lajes, lago com ponte arqueada, cerejeiras e lanternas
	local plaza = Build.folder(folder, "Plaza")
	workspace.Terrain:FillBlock(
		CFrame.new(at(0, 0) + Vector3.new(0, -2.4, 0)),
		Vector3.new(30, 4, 40),
		Enum.Material.Water
	)
	for _, s in { -1, 1 } do
		Build.part(
			plaza,
			Vector3.new(2, 1, 42),
			CFrame.new(at(s * 16, 0) + Vector3.new(0, 0.5, 0)),
			Color3.fromRGB(130, 126, 118),
			Enum.Material.Rock,
			"PondRim"
		)
		Build.part(
			plaza,
			Vector3.new(30, 1, 2),
			CFrame.new(at(0, s * 21) + Vector3.new(0, 0.5, 0)),
			Color3.fromRGB(130, 126, 118),
			Enum.Material.Rock,
			"PondRim"
		)
	end
	-- lajes em volta do lago (o chão da praça não cobre a água)
	for _, strip in
		{
			{ Vector3.new(100, 0.3, 29), at(0, -35.5) },
			{ Vector3.new(100, 0.3, 29), at(0, 35.5) },
			{ Vector3.new(34, 0.3, 42), at(-33, 0) },
			{ Vector3.new(34, 0.3, 42), at(33, 0) },
		}
	do
		Build.part(
			plaza,
			strip[1],
			CFrame.new(strip[2] + Vector3.new(0, 0.16, 0)),
			Color3.fromRGB(206, 200, 188),
			Enum.Material.Granite,
			"Plaza"
		)
	end
	Seireitei.archBridge(plaza, at(0, -22) + Vector3.new(0, 0.4, 0), at(0, 22) + Vector3.new(0, 0.4, 0), 7, 4.5)
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2 + 0.3
		Build.tree(plaza, at(math.cos(angle) * 44, math.sin(angle) * 44), "cherry", rng)
	end
	for _, p in { at(-22, -26), at(22, -26), at(-22, 26), at(22, 26) } do
		Seireitei.lantern(plaza, p, 1.3)
	end
	-- avenida: lanternas e cerejeiras alternadas dos dois lados
	for z = -200, 40, 24 do
		for _, s in { -1, 1 } do
			local p = at(s * 11, z)
			if math.abs(z) > 55 and Build.clear(p, keepOut) then
				if (z / 24) % 2 == 0 then
					Seireitei.lantern(streets, p)
				else
					Build.tree(streets, p, "cherry", rng)
				end
			end
		end
	end

	-- pagode no fim da avenida
	local landmarks = Build.folder(folder, "Landmarks")
	Seireitei.pagoda(landmarks, CFrame.new(at(0, 150)), 26)
	-- Sōkyoku (noroeste) e Senzaikyū (nordeste)
	Seireitei.sokyoku(landmarks, CFrame.new(at(-176, 192)), 26, rng)
	Seireitei.whiteTower(landmarks, CFrame.lookAt(at(186, 196), at(186, 100)), 120)
	-- pátio invadido (noroeste): muros quebrados, entulho e a fenda por onde os Hollows entram
	local breach = Build.folder(folder, "Breach")
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2
		local p = at(-150 + math.cos(angle) * 46, 120 + math.sin(angle) * 46)
		local a = p + Vector3.new(math.sin(angle) * 6, 0, -math.cos(angle) * 6)
		local b = p - Vector3.new(math.sin(angle) * 6, 0, -math.cos(angle) * 6)
		Seireitei.wall(breach, a, b, rng:NextNumber(5, 10))
		for _ = 1, 3 do
			local chunk = Build.part(
				breach,
				Vector3.new(rng:NextNumber(1, 3), rng:NextNumber(0.8, 2), rng:NextNumber(1, 3)),
				CFrame.new(p + Vector3.new(rng:NextNumber(-6, 6), 0.6, rng:NextNumber(-6, 6)))
					* CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), rng:NextNumber(0, 1)),
				Seireitei.Colors.plaster:Lerp(Color3.fromRGB(80, 76, 70), rng:NextNumber(0, 0.4)),
				Enum.Material.Plaster,
				"Rubble"
			)
			chunk.CanCollide = false
		end
	end
	local rift = Build.part(
		breach,
		Vector3.new(30, 0.3, 4),
		CFrame.new(at(-150, 150) + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0.4, 0),
		Color3.fromRGB(40, 8, 30),
		Enum.Material.Neon,
		"Rift"
	)
	rift.CanCollide = false
	Build.light(rift, Color3.fromRGB(180, 40, 120), 30, 1.4)

	-- além dos muros: mar de telhados do Seireitei até as montanhas (sem colisão)
	local beyond = Build.folder(folder, "Beyond")
	local brng = Random.new(3010)
	for gx = -22, 22 do
		for gz = -22, 22 do
			local p = Vector3.new(gx * 40, 0, gz * 40)
			local square = math.max(math.abs(p.X), math.abs(p.Z))
			if square > half + 30 and p.Magnitude < 880 and brng:NextNumber() < 0.85 then
				local w, d = brng:NextNumber(18, 30), brng:NextNumber(14, 24)
				local h = brng:NextNumber(8, 16)
				local base = CFrame.new(c + p + Vector3.new(brng:NextNumber(-5, 5), 0, brng:NextNumber(-5, 5)))
					* CFrame.Angles(0, if brng:NextNumber() < 0.5 then 0 else math.pi / 2, 0)
				local body = Build.part(
					beyond,
					Vector3.new(w, h, d),
					base * CFrame.new(0, h / 2, 0),
					Seireitei.Colors.plaster,
					Enum.Material.Plaster,
					"Far"
				)
				body.CanCollide = false
				body.CastShadow = false
				for _, side in { 0, math.pi } do
					local r = Build.wedge(
						beyond,
						Vector3.new(w + 4, d * 0.35, d / 2 + 2),
						base * CFrame.Angles(0, side, 0) * CFrame.new(0, h + d * 0.175, -(d / 2 + 2) / 2),
						Seireitei.Colors.roof,
						Enum.Material.Slate
					)
					r.CanCollide = false
					r.CastShadow = false
				end
			end
		end
	end
	for i = 1, 22 do
		local angle = i / 22 * math.pi * 2
		local size = brng:NextNumber(500, 800)
		local hill = Build.ball(
			beyond,
			size,
			CFrame.new(c + Vector3.new(math.cos(angle) * 1150, -size * 0.3, math.sin(angle) * 1150)),
			Color3.fromRGB(80, 110, 90):Lerp(Color3.fromRGB(130, 150, 170), brng:NextNumber(0, 0.5)),
			Enum.Material.Grass
		)
		hill.CanCollide = false
		hill.CastShadow = false
	end
end

-- ===================== HUECO MUNDO =====================
-- Deserto noturno sem fim: dunas, agulhas e mesas de rocha, cânion a oeste, floresta de quartzo
-- a sudeste, carcaças de Hollows gigantes semienterradas, a fenda dos Menos no meio, a Garganta
-- ao sul (saída para Karakura) e, ao norte, as ruínas da arena diante da muralha de Las Noches,
-- com a cúpula e as torres sob a lua crescente. Spawns, portais, viagem, NPC e arena ficam livres.
function Regions.HuecoMundo(folder: Instance)
	local zone = Zones.List.HuecoMundo
	local c = zone.center
	local rng = Random.new(4004)
	local half = zone.size.X / 2
	Build.ground(c, Vector2.new(zone.size.X, zone.size.Z), Enum.Material.Sand)
	boundary(folder, c, zone.size)
	local extra = {}
	for _, npc in NPCs do
		if npc.zone == "HuecoMundo" then
			table.insert(extra, { position = c + npc.position, radius = 10 })
		end
	end
	local keepOut = keepOutFor("HuecoMundo", extra)
	local function at(x: number, z: number): Vector3
		return c + Vector3.new(x, 0, z)
	end
	local function clearFor(p: Vector3, r: number): boolean
		for _, k in keepOut do
			if Vector2.new(p.X - k.position.X, p.Z - k.position.Z).Magnitude < k.radius + r then
				return false
			end
		end
		return true
	end

	-- dunas (terreno liso)
	for _ = 1, 40 do
		local p = at(rng:NextNumber(-300, 300), rng:NextNumber(-300, 300))
		local r = rng:NextNumber(22, 44)
		if clearFor(p, r * 0.5) then
			workspace.Terrain:FillBall(p - Vector3.new(0, r * rng:NextNumber(0.62, 0.8), 0), r, Enum.Material.Sand)
		end
	end
	-- cânion a oeste: dois paredões de rocha
	Hueco.ridge(at(-245, -110), at(-245, 150), 22, 46, rng)
	Hueco.ridge(at(-305, -150), at(-305, 300), 26, 70, rng)
	-- agulhas e mesas de rocha
	local placed = 0
	for _ = 1, 60 do
		if placed >= 16 then
			break
		end
		local p = at(rng:NextNumber(-280, 290), rng:NextNumber(-280, 140))
		local r = rng:NextNumber(7, 16)
		if clearFor(p, r + 8) then
			Hueco.rock(p, r, rng:NextNumber(24, 70), rng)
			placed += 1
		end
	end

	-- carcaças de Hollow gigantes
	local bones = Build.folder(folder, "Carcasses")
	Hueco.carcass(bones, CFrame.new(at(205, 62)), 1.2, rng)
	Hueco.carcass(bones, CFrame.lookAt(at(-100, -150), at(-20, -150)), 0.8, rng)

	-- floresta de quartzo (sudeste) e árvores soltas
	local trees = Build.folder(folder, "QuartzTrees")
	for _ = 1, 70 do
		local p = if rng:NextNumber() < 0.65
			then at(rng:NextNumber(90, 300), rng:NextNumber(-300, -150))
			else at(rng:NextNumber(-300, 300), rng:NextNumber(-300, 140))
		if clearFor(p, 4) then
			Hueco.quartzTree(trees, p, rng)
		end
	end

	-- fenda dos Menos (onde as sombras de Menos surgem)
	for _, s in Zones.Spawners do
		if s.zone == "HuecoMundo" and s.enemy == "MenosShade" then
			Hueco.menosRift(folder, c + s.position, 22, rng)
		end
	end
	-- Garganta: arco de pedra atrás do portal de volta
	for _, portal in Zones.Portals do
		if portal.zone == "HuecoMundo" then
			Hueco.gargantaArch(
				folder,
				CFrame.lookAt(c + portal.position - Vector3.new(0, 0, 13), c + portal.position + Vector3.new(0, 0, 10))
			)
		end
	end

	-- ruínas da arena diante de Las Noches
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
		Build.cylinder(
			ruins,
			0.4,
			boss.arena * 1.2,
			CFrame.new(p + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(214, 210, 202),
			Enum.Material.Marble
		)
		-- degraus da entrada (sul)
		for i = 1, 3 do
			Build.part(
				ruins,
				Vector3.new(40 - i * 4, i * 0.4, 3),
				CFrame.new(p + Vector3.new(0, i * 0.2, -boss.arena * 1.1 - 6 + i * 3)),
				Color3.fromRGB(226, 222, 214),
				Enum.Material.Marble,
				"Step"
			)
		end
		for i = 0, 11 do
			local angle = i / 12 * math.pi * 2
			local radius = boss.arena + 6
			local pos = p + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local broken = i % 3 == 0
			local h = if broken then rng:NextNumber(10, 18) else rng:NextNumber(30, 48)
			Build.part(
				ruins,
				Vector3.new(6, h, 6),
				CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, angle, math.rad(rng:NextNumber(-5, 5))),
				Color3.fromRGB(240, 238, 232),
				Enum.Material.Marble,
				"Pillar"
			)
			Build.part(
				ruins,
				Vector3.new(8, 2, 8),
				CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, angle, 0),
				Color3.fromRGB(220, 216, 208),
				Enum.Material.Marble,
				"PillarBase"
			)
			if broken then
				-- pedaço caído ao lado
				local fall = pos + Vector3.new(math.cos(angle + 0.6), 0, math.sin(angle + 0.6)) * 12
				Build.part(
					ruins,
					Vector3.new(6, 6, rng:NextNumber(14, 22)),
					CFrame.new(fall + Vector3.new(0, 3, 0))
						* CFrame.Angles(0, angle + rng:NextNumber(-0.6, 0.6), math.rad(rng:NextNumber(-8, 8))),
					Color3.fromRGB(232, 230, 222),
					Enum.Material.Marble,
					"FallenPillar"
				)
			else
				Build.part(
					ruins,
					Vector3.new(9, 2.4, 9),
					CFrame.new(pos + Vector3.new(0, h + 1.2, 0)) * CFrame.Angles(0, angle, 0),
					Color3.fromRGB(226, 222, 214),
					Enum.Material.Marble,
					"Capital"
				)
			end
		end
	end
	-- Las Noches ao fundo (além do limite norte)
	Hueco.lasNoches(folder, CFrame.lookAt(at(0, half + 45), at(0, 0)), 760)

	-- lua crescente gigante (mais segmentos: curva lisa) com halo
	local sky = Build.folder(folder, "Sky")
	local moonCenter = c + Vector3.new(-420, 420, 1150)
	local radius = 150
	for i = -14, 14 do
		local a = i / 14 * math.rad(78)
		local pos = moonCenter + Vector3.new(math.sin(a) * radius, math.cos(a) * radius, 0)
		local thickness = 46 * (1 - math.abs(i) / 15.5)
		local piece = Build.part(
			sky,
			Vector3.new(thickness, radius * 0.12, 6),
			CFrame.new(pos) * CFrame.Angles(0, 0, -a),
			Color3.fromRGB(248, 248, 238),
			Enum.Material.Neon,
			"Moon"
		)
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CastShadow = false
	end
end

return Regions

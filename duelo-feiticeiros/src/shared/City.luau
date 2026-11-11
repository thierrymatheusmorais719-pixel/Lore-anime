-- CIDADE À NOITE (cenário da luta): quarteirões de prédios com janelas acesas, o telhado-arena no centro,
-- caixas d'água, antenas, letreiros, lua grande e névoa. Tudo ancorado; construído uma vez pelo servidor.

local City = {}

local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

City.ArenaTop = 60 -- altura do telhado da arena (studs)
City.ArenaCenter = V(0, City.ArenaTop, 0)
City.ArenaSize = V(90, 2, 70)

local function part(parent: Instance, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end
City._part = part

local WALLS = { rgb(58, 60, 72), rgb(70, 66, 74), rgb(48, 52, 64), rgb(80, 76, 84), rgb(62, 58, 66) }
local WINDOW = { rgb(255, 214, 140), rgb(170, 220, 255), rgb(255, 170, 120) }

-- Um prédio: bloco com faixas, janelas acesas (algumas), caixa d'água e antena no topo.
local function building(parent: Instance, rng: Random, x: number, z: number, w: number, d: number, h: number, isArena: boolean?)
	local col = WALLS[rng:NextInteger(1, #WALLS)]
	local m = Instance.new("Model")
	m.Name = isArena and "ArenaBuilding" or "Building"
	m.Parent = parent
	part(m, { Name = "Block", Size = V(w, h, d), CFrame = CF(x, h / 2, z), Color = col, Material = Enum.Material.Concrete })
	-- beiral do telhado
	part(m, { Name = "Ledge", Size = V(w + 1.2, 1.2, d + 1.2), CFrame = CF(x, h + 0.6, z), Color = col:Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.Slate })
	-- janelas: grade nas faces; só uma parte acende. Janelas vizinhas acesas viram UMA peça (faixa), só as
	-- faces voltadas para a arena ganham janelas e, longe, um andar sim outro não (orçamento de peças).
	local floors = math.floor(h / 6)
	local ring = math.max(math.abs(x), math.abs(z)) / 80
	local floorStep = ring >= 3.5 and 2 or 1
	local faces = { { V(0, 0, d / 2 + 0.05), V(1, 0, 0), w, V(0, 0, 1) }, { V(0, 0, -d / 2 - 0.05), V(1, 0, 0), w, V(0, 0, -1) },
		{ V(w / 2 + 0.05, 0, 0), V(0, 0, 1), d, V(1, 0, 0) }, { V(-w / 2 - 0.05, 0, 0), V(0, 0, 1), d, V(-1, 0, 0) } }
	for f = 1, floors - 1, floorStep do
		local y = f * 6
		for _, face in ipairs(faces) do
			local toArena = V(-x, 0, -z)
			if isArena or toArena.Magnitude < 1 or face[4]:Dot(toArena.Unit) > -0.2 then
				local cols = math.floor(face[3] / 5)
				local c = 1
				while c <= cols do
					if rng:NextNumber() < 0.3 then
						local run = 1
						while c + run <= cols and run < 4 and rng:NextNumber() < 0.45 do
							run += 1
						end
						local mid = c + (run - 1) / 2
						local off = (mid - (cols + 1) / 2) * 5
						local len = run * 5 - 2.6
						local pos = V(x, y, z) + face[1] + face[2] * off
						part(m, { Name = "Window", Size = (face[2].X ~= 0) and V(len, 2.8, 0.15) or V(0.15, 2.8, len), CFrame = CF(pos),
							Color = WINDOW[rng:NextInteger(1, #WINDOW)], Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
						c += run
					else
						c += 1
					end
				end
			end
		end
	end
	if not isArena and rng:NextNumber() < 0.5 then
		local tx, tz = x + rng:NextNumber(-w * 0.25, w * 0.25), z + rng:NextNumber(-d * 0.25, d * 0.25)
		local tank = part(m, { Name = "WaterTank", Shape = Enum.PartType.Cylinder, Size = V(5, 5, 5), CFrame = CF(tx, h + 4.8, tz) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(96, 84, 76), Material = Enum.Material.WoodPlanks })
		for _, s in ipairs({ -1, 1 }) do
			part(m, { Name = "TankLeg", Size = V(0.4, 3.4, 0.4), CFrame = CF(tx + s * 1.6, h + 2.1, tz), Color = rgb(40, 40, 46), Material = Enum.Material.Metal })
		end
		local _ = tank
	end
	if rng:NextNumber() < 0.35 then
		local ah = rng:NextNumber(6, 14)
		local ax, az = x + w * 0.3, z - d * 0.3
		part(m, { Name = "Antenna", Size = V(0.3, ah, 0.3), CFrame = CF(ax, h + 1.2 + ah / 2, az), Color = rgb(30, 30, 36), Material = Enum.Material.Metal })
		part(m, { Name = "AntennaLight", Shape = Enum.PartType.Ball, Size = V(0.7, 0.7, 0.7), CFrame = CF(ax, h + 1.2 + ah, az), Color = rgb(255, 60, 60), Material = Enum.Material.Neon })
	end
	return m
end

-- Constrói a cidade inteira. Devolve a pasta.
function City.build(parent: Instance?)
	local folder = Instance.new("Folder")
	folder.Name = "City"
	folder.Parent = parent or workspace
	local rng = Random.new(1989)
	-- chão da rua (bem lá embaixo) e asfalto
	part(folder, { Name = "Street", Size = V(900, 2, 900), CFrame = CF(0, -1, 0), Color = rgb(30, 30, 36), Material = Enum.Material.Asphalt })
	-- a arena: prédio largo no centro, telhado plano
	local arena = building(folder, rng, 0, 0, City.ArenaSize.X, City.ArenaSize.Z, City.ArenaTop - 1.2, true)
	part(arena, { Name = "ArenaRoof", Size = City.ArenaSize, CFrame = CF(City.ArenaCenter - V(0, 1, 0)), Color = rgb(72, 72, 82), Material = Enum.Material.Concrete })
	-- marcas no telhado (heliponto apagado)
	part(arena, { Name = "RoofMark", Shape = Enum.PartType.Cylinder, Size = V(0.1, 26, 26), CFrame = CF(City.ArenaCenter + V(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(150, 150, 160), Material = Enum.Material.SmoothPlastic, Transparency = 0.6, CanCollide = false })
	-- quarteirões em volta (anéis), mais altos ao fundo
	for gx = -5, 5 do
		for gz = -5, 5 do
			local d = math.max(math.abs(gx), math.abs(gz))
			if d >= 1 then
				local x = gx * 80 + rng:NextNumber(-10, 10)
				local z = gz * 80 + rng:NextNumber(-10, 10)
				local h = rng:NextNumber(30, 70) + d * rng:NextNumber(6, 16)
				building(folder, rng, x, z, rng:NextNumber(30, 55), rng:NextNumber(30, 55), h)
			end
		end
	end
	-- letreiros de neon em alguns prédios perto da arena
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		local p = V(math.cos(a) * 95, rng:NextNumber(30, 55), math.sin(a) * 95)
		part(folder, { Name = "Sign", Size = V(10, 3, 0.4), CFrame = CF(p, V(0, p.Y, 0)), Color = k % 2 == 0 and rgb(255, 70, 140) or rgb(70, 220, 255),
			Material = Enum.Material.Neon, CanCollide = false })
	end
	-- lua cheia, enorme, atrás da arena
	part(folder, { Name = "Moon", Shape = Enum.PartType.Ball, Size = V(120, 120, 120), CFrame = CF(-180, 330, -700), Color = rgb(230, 236, 255),
		Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	return folder
end

-- Céu, luz e névoa da noite (servidor e cliente podem chamar: só ajusta propriedades).
function City.lighting()
	local L = game:GetService("Lighting")
	L.ClockTime = 0.3
	L.Brightness = 1.2
	L.Ambient = rgb(40, 40, 62)
	L.OutdoorAmbient = rgb(56, 52, 84)
	local atm = L:FindFirstChild("Atmosphere") :: Atmosphere?
	if not atm then
		local a = Instance.new("Atmosphere")
		a.Parent = L
		atm = a
	end
	local a = atm :: Atmosphere
	a.Density = 0.38
	a.Offset = 0.15
	a.Color = rgb(90, 90, 140)
	a.Decay = rgb(40, 30, 70)
	a.Glare = 0.2
	a.Haze = 1.8
	local bloom = L:FindFirstChild("Bloom") :: BloomEffect?
	if not bloom then
		local b = Instance.new("BloomEffect")
		b.Name = "Bloom"
		b.Parent = L
		bloom = b
	end
	local b = bloom :: BloomEffect
	b.Intensity = 0.9
	b.Size = 30
	b.Threshold = 0.85
end

return City

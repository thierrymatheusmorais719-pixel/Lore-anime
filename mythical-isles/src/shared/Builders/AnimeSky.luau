-- Céu estilo ANIME 2D, desenhado no próprio jogo (sem imagens externas nem IDs de asset):
--   * gradiente de céu pintado em painéis BillboardGui ao redor da câmera (UIGradient)
--   * nuvens planas "cel-shaded": sombra pastel embaixo, preenchimento, brilho em cima
--   * faixas de nuvem finas no horizonte, sol (ou lua) 2D com halo e estrelas nos mundos noturnos
-- Tudo com LightInfluence = 0: cor chapada, sem sombreamento 3D e sem estourar o Bloom.
-- Cada mundo tem a sua paleta (Themes) — usada também pela luz/névoa em WorldClient.
--
-- Compartilhado: o cliente (SkyClient) monta e anima; tools/preview usa o mesmo layout.

local AnimeSky = {}

local rgb = Color3.fromRGB

-- Distâncias (studs) a partir da câmera. Os painéis do gradiente ficam atrás de tudo da ilha.
AnimeSky.PANEL_DIST = 900
AnimeSky.PANEL_LOW = -15 -- elevação (graus) da borda de baixo do gradiente
AnimeSky.PANEL_HIGH = 72 -- elevação da borda de cima

AnimeSky.Themes = {
	verdant = { -- manhã esmeralda: azul vivo, horizonte verde-menta, nuvens brancas
		label = "Manhã Esmeralda", top = rgb(28, 112, 232), mid = rgb(92, 184, 250), horizon = rgb(204, 242, 230), below = rgb(222, 246, 238),
		cloud = rgb(255, 255, 255), shade = rgb(170, 210, 232), hi = rgb(255, 255, 246), streak = rgb(236, 250, 255),
		sun = rgb(255, 250, 214), glow = rgb(255, 238, 160), fog = rgb(196, 236, 222), decay = rgb(90, 158, 172), tint = rgb(250, 255, 240), ambient = rgb(118, 146, 112),
	},
	crystal = { -- tarde safira: anil profundo, lavanda no horizonte, nuvens com sombra violeta
		label = "Tarde Safira", top = rgb(58, 80, 214), mid = rgb(124, 158, 255), horizon = rgb(214, 214, 255), below = rgb(228, 224, 255),
		cloud = rgb(248, 244, 255), shade = rgb(176, 156, 240), hi = rgb(255, 255, 255), streak = rgb(232, 226, 255),
		sun = rgb(255, 250, 236), glow = rgb(216, 196, 255), fog = rgb(192, 186, 250), decay = rgb(86, 90, 190), tint = rgb(242, 238, 255), ambient = rgb(114, 104, 178),
	},
	sky = { -- tarde dourada celestial: azul profundo, horizonte creme-dourado, sombras lavanda (arte do Mundo 3)
		label = "Tarde Dourada Celestial", top = rgb(34, 92, 222), mid = rgb(104, 170, 255), horizon = rgb(255, 234, 196), below = rgb(244, 246, 255),
		cloud = rgb(255, 255, 255), shade = rgb(196, 198, 242), hi = rgb(255, 250, 228), streak = rgb(255, 242, 222),
		sun = rgb(255, 244, 204), glow = rgb(255, 212, 136), fog = rgb(228, 232, 255), decay = rgb(116, 146, 220), tint = rgb(255, 248, 236), ambient = rgb(168, 166, 198),
	},
	wilds = { -- crepúsculo turquesa
		label = "Crepúsculo Turquesa", top = rgb(16, 52, 80), mid = rgb(40, 128, 130), horizon = rgb(156, 226, 192), below = rgb(180, 232, 206),
		cloud = rgb(206, 240, 224), shade = rgb(88, 150, 150), hi = rgb(234, 255, 242), streak = rgb(170, 220, 200),
		sun = rgb(255, 222, 168), glow = rgb(255, 190, 130), fog = rgb(112, 182, 160), decay = rgb(30, 80, 90), tint = rgb(226, 250, 238), ambient = rgb(80, 112, 104),
	},
	astral = { -- noite violeta com estrelas e lua
		label = "Noite Violeta", top = rgb(10, 8, 36), mid = rgb(58, 28, 112), horizon = rgb(182, 82, 168), below = rgb(120, 60, 140),
		cloud = rgb(146, 116, 214), shade = rgb(70, 50, 142), hi = rgb(222, 192, 255), streak = rgb(150, 96, 190),
		sun = rgb(250, 242, 255), glow = rgb(196, 166, 255), fog = rgb(92, 62, 142), decay = rgb(24, 14, 60), tint = rgb(240, 226, 255), ambient = rgb(104, 84, 168),
		stars = true, moon = true,
	},
}

local function theme(worldId: string)
	return AnimeSky.Themes[worldId] or AnimeSky.Themes.verdant
end
AnimeSky.theme = theme

-- Elevação (graus) → fração vertical no painel (0 = topo, 1 = base).
function AnimeSky.panelFrac(elev: number): number
	local D = AnimeSky.PANEL_DIST
	local yTop = D * math.tan(math.rad(AnimeSky.PANEL_HIGH))
	local yBot = D * math.tan(math.rad(AnimeSky.PANEL_LOW))
	local y = D * math.tan(math.rad(elev))
	return math.clamp((yTop - y) / (yTop - yBot), 0, 1)
end

-- Paradas do gradiente (fração, cor) para um mundo.
function AnimeSky.gradient(worldId: string)
	local t = theme(worldId)
	local f = AnimeSky.panelFrac
	return {
		{ 0, t.top }, { f(42), t.top:Lerp(t.mid, 0.35) }, { f(22), t.mid }, { f(8), t.mid:Lerp(t.horizon, 0.6) }, { f(0), t.horizon }, { 1, t.below },
	}
end

-- Layout determinístico das nuvens de um mundo (mesmo resultado no jogo e na prévia).
-- Cada nuvem: az/elev (graus), dist, w/h (studs) e "puffs" { x, y, r, layer } em frações do quadro
-- (x relativo à largura, y e r relativos à altura). Camadas: "shade", "fill", "hi", "base".
function AnimeSky.layout(worldId: string)
	local seed = 0
	for i = 1, #worldId do
		seed += string.byte(worldId, i) * i
	end
	local rng = Random.new(seed)
	local clouds = {}
	local count = 14
	for i = 1, count do
		local az = (i / count) * 360 + rng:NextNumber(-12, 12)
		local w = rng:NextNumber(150, 300)
		local h = w * rng:NextNumber(0.42, 0.55)
		local puffs = {}
		-- bolotas arredondadas em cima, base reta (anime cumulus)
		local n = rng:NextInteger(4, 7)
		for k = 1, n do
			local x = 0.14 + (k - 1) / (n - 1) * 0.72 + rng:NextNumber(-0.04, 0.04)
			local mid = 1 - math.abs(x - 0.5) * 1.6
			local r = rng:NextNumber(0.22, 0.32) + mid * 0.16
			-- o quadro do BillboardGui corta o que passa da borda: mantém cada bolota inteira dentro
			local margin = r * h / w + 0.015
			x = math.clamp(x, margin, 1 - margin)
			local y = 0.86 - r * 0.95
			table.insert(puffs, { x = x, y = y + 0.07, r = r, layer = "shade" })
			table.insert(puffs, { x = x, y = y, r = r * 0.98, layer = "fill" })
			if k > 1 and k < n and rng:NextNumber() < 0.7 then
				table.insert(puffs, { x = x - r * 0.12, y = y - r * 0.45, r = r * 0.42, layer = "hi" })
			end
		end
		table.insert(clouds, { az = az, elev = rng:NextNumber(7, 26), dist = rng:NextNumber(560, 740), w = w, h = h, puffs = puffs, base = 0.86 })
	end
	local streaks = {}
	for i = 1, 9 do
		table.insert(streaks, { az = i * 40 + rng:NextNumber(-15, 15), elev = rng:NextNumber(1.5, 6), dist = 820, w = rng:NextNumber(220, 420), h = rng:NextNumber(10, 18) })
	end
	local stars = {}
	if theme(worldId).stars then
		for _ = 1, 140 do
			table.insert(stars, { az = rng:NextNumber(0, 360), elev = rng:NextNumber(14, 70), size = rng:NextNumber(1.5, 4.2), twinkle = rng:NextNumber() })
		end
	end
	return { clouds = clouds, streaks = streaks, stars = stars }
end

-- Direção horizontal (graus) e elevação → deslocamento a partir da câmera.
function AnimeSky.offset(az: number, elev: number, dist: number): Vector3
	local a, e = math.rad(az), math.rad(elev)
	return Vector3.new(math.cos(a) * math.cos(e) * dist, math.sin(e) * dist, math.sin(a) * math.cos(e) * dist)
end

-------------------------------------------------------------------------------
-- Construção com GUIs (cliente)
-------------------------------------------------------------------------------

local function billboard(parent: Instance, anchor: BasePart, name: string, w: number, h: number, offset: Vector3)
	local b = Instance.new("BillboardGui")
	b.Name = name
	b.Size = UDim2.new(w, 0, h, 0)
	b.StudsOffsetWorldSpace = offset
	b.LightInfluence = 0
	b.AlwaysOnTop = false
	b.MaxDistance = 100000
	b.ClipsDescendants = false
	b.Adornee = anchor
	b.Parent = parent
	return b
end

local function circle(parent: Instance, x: number, y: number, r: number, color: Color3, z: number)
	-- r relativo à ALTURA do quadro; SizeConstraint RelativeYY mantém o círculo redondo
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(r * 2, r * 2)
	f.SizeConstraint = Enum.SizeConstraint.RelativeYY
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	f.Parent = parent
	return f
end

-- Monta o céu de um mundo dentro de `parent`, preso à peça `anchor` (que segue a câmera).
-- Devolve { clouds = { {gui, data} }, streaks = {...}, sun = gui }.
function AnimeSky.build(parent: Instance, anchor: BasePart, worldId: string)
	local t = theme(worldId)
	local L = AnimeSky.layout(worldId)
	local handle = { clouds = {}, streaks = {}, stars = {} }
	-- gradiente: 8 painéis ao redor
	local D = AnimeSky.PANEL_DIST
	local yTop = D * math.tan(math.rad(AnimeSky.PANEL_HIGH))
	local yBot = D * math.tan(math.rad(AnimeSky.PANEL_LOW))
	local H = yTop - yBot
	local W = 2 * D * math.tan(math.rad(27)) + 60
	local stops = {}
	for _, s in ipairs(AnimeSky.gradient(worldId)) do
		table.insert(stops, ColorSequenceKeypoint.new(s[1], s[2]))
	end
	local seq = ColorSequence.new(stops)
	for i = 0, 7 do
		local az = i * 45
		local off = Vector3.new(math.cos(math.rad(az)) * D, (yTop + yBot) / 2, math.sin(math.rad(az)) * D)
		local b = billboard(parent, anchor, "SkyPanel" .. i, W, H, off)
		local fr = Instance.new("Frame")
		fr.Size = UDim2.fromScale(1, 1)
		fr.BackgroundColor3 = Color3.new(1, 1, 1)
		fr.BorderSizePixel = 0
		local g = Instance.new("UIGradient")
		g.Color = seq
		g.Rotation = 90
		g.Parent = fr
		fr.Parent = b
	end
	-- estrelas (mundos noturnos)
	for i, s in ipairs(L.stars) do
		local b = billboard(parent, anchor, "Star" .. i, s.size, s.size, AnimeSky.offset(s.az, s.elev, D - 30))
		local st = circle(b, 0.5, 0.5, 0.5, Color3.new(1, 1, 1), 1)
		st.SizeConstraint = Enum.SizeConstraint.RelativeXY
		st.Size = UDim2.fromScale(1, 1)
		table.insert(handle.stars, { gui = b, frame = st, data = s })
	end
	-- faixas finas no horizonte
	for i, s in ipairs(L.streaks) do
		local b = billboard(parent, anchor, "Streak" .. i, s.w, s.h, AnimeSky.offset(s.az, s.elev, s.dist))
		local fr = Instance.new("Frame")
		fr.Size = UDim2.fromScale(1, 1)
		fr.BackgroundColor3 = t.streak
		fr.BackgroundTransparency = 0.15
		fr.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = fr
		fr.Parent = b
		table.insert(handle.streaks, { gui = b, data = s })
	end
	-- nuvens cel-shaded
	local colors = { shade = t.shade, fill = t.cloud, hi = t.hi }
	local zOf = { shade = 1, fill = 2, hi = 3 }
	for i, c in ipairs(L.clouds) do
		local b = billboard(parent, anchor, "Cloud" .. i, c.w, c.h, AnimeSky.offset(c.az, c.elev, c.dist))
		-- base reta: barra arredondada na cor da sombra
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.fromScale(0.5, c.base + 0.08)
		bar.Size = UDim2.fromScale(0.82, 0.26)
		bar.BackgroundColor3 = t.shade
		bar.BorderSizePixel = 0
		bar.ZIndex = 1
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0.5, 0)
		bc.Parent = bar
		bar.Parent = b
		for _, p in ipairs(c.puffs) do
			circle(b, p.x, p.y, p.r, colors[p.layer], zOf[p.layer])
		end
		table.insert(handle.clouds, { gui = b, data = c })
	end
	-- sol (ou lua) 2D com halo
	local sun = billboard(parent, anchor, t.moon and "Moon" or "Sun", 150, 150, AnimeSky.offset(60, 40, D - 40))
	local halo = circle(sun, 0.5, 0.5, 0.5, t.glow, 1)
	halo.BackgroundTransparency = 0.72
	circle(sun, 0.5, 0.5, 0.34, t.glow, 2).BackgroundTransparency = 0.45
	circle(sun, 0.5, 0.5, 0.22, t.sun, 3)
	if t.moon then
		circle(sun, 0.57, 0.44, 0.17, t.top:Lerp(t.mid, 0.3), 4) -- recorte da lua crescente
	end
	handle.sun = sun
	handle.worldId = worldId
	return handle
end

return AnimeSky

-- Visual dos personagens de missão (NPCs) sobre o rig R15 do RigBuilder: rosto de anime (olhos com
-- íris, pupila e brilho, sobrancelhas com expressão, boca), cabelo em mechas de cunha (sem bolhas),
-- roupas por arquétipo (shihakushō com hakama e mangas largas, haori de capitão com caudas,
-- jaqueta de Arrancar, sobretudo Quincy com capa, jaqueta de Fullbringer, quimono de lojista com
-- chapéu listrado, uniforme escolar de marinheiro, braçadeira de tenente) e acessórios (katana na
-- cintura, arco espiritual, bengala, livros, máscara Hollow partida).
-- Peças soldadas às partes do corpo: as animações (NpcIdle, Talk, Wave) movem tudo junto.
-- Medidas do R15 padrão (RigBuilder): cabeça 1,16 × 1,18 × 1,16 (frente em z = -0,58), tronco
-- 1,94 × 1,7 × 1, quadril 1,99 × 0,4 × 1, braço 1 × 1,24, antebraço 1 × 1,12, coxa 0,99 × 1,36,
-- canela 0,99 × 1,3, pé 1,01 × 0,31 × 1.
local NpcStyle = {}

export type Style = {
	skin: Color3,
	hair: { kind: string, color: Color3 }?,
	eyes: Color3?,
	brows: string?, -- "calm", "stern", "soft", "sly"
	outfit: string,
	colors: { [string]: Color3 }?,
	props: { string }?,
	glasses: boolean?,
	beard: Color3?,
	nose: boolean?,
	mask: string?, -- "jaw", "horn"
}

-- Enquanto `dressing`, toda peça criada é marcada "Uniform" (o uniforme do jogador é refeito a
-- cada troca de forma sem mexer no avatar)
local dressing = false

local WHITE = Color3.fromRGB(240, 240, 242)
local BLACK = Color3.fromRGB(16, 16, 20)
local INK = Color3.fromRGB(28, 22, 24)

local function piece(
	base: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	class: string?
): BasePart
	local p = Instance.new(class or "Part") :: BasePart
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.CFrame = base.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = base
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	if dressing then
		p:SetAttribute("Uniform", true)
	end
	p.Parent = base
	return p
end

local function wedge(
	base: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
)
	return piece(base, name, size, offset, color, material, "WedgePart")
end

local function deg(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local function part(model: Model, name: string): BasePart?
	return model:FindFirstChild(name) :: BasePart?
end

local function paint(model: Model, names: { string }, color: Color3, material: Enum.Material?)
	for _, n in names do
		local p = part(model, n)
		if p then
			p.Color = color
			if material then
				p.Material = material
			end
		end
	end
end

local ARMS = { "LeftUpperArm", "RightUpperArm" }
local FOREARMS = { "LeftLowerArm", "RightLowerArm" }
local THIGHS = { "LeftUpperLeg", "RightUpperLeg" }
local SHINS = { "LeftLowerLeg", "RightLowerLeg" }
local FEET = { "LeftFoot", "RightFoot" }

-- ======================================================================= rosto
local BROWS = {
	calm = { 0, 0.3 },
	stern = { -16, 0.27 }, -- ponta de dentro desce: cara fechada
	soft = { 12, 0.31 },
	sly = { -8, 0.29 },
}

local function face(head: BasePart, style: Style)
	local z = -head.Size.Z / 2
	local eye = style.eyes or Color3.fromRGB(70, 50, 40)
	local brow = BROWS[style.brows or "calm"] or BROWS.calm
	local hairColor = if style.hair then style.hair.color else INK
	for _, side in { -1, 1 } do
		local x = 0.22 * side
		piece(head, "EyeWhite", Vector3.new(0.27, 0.17, 0.02), CFrame.new(x, 0.06, z - 0.005), WHITE)
		piece(head, "Iris", Vector3.new(0.15, 0.16, 0.02), CFrame.new(x - 0.02 * side, 0.055, z - 0.013), eye)
		piece(head, "Pupil", Vector3.new(0.07, 0.09, 0.02), CFrame.new(x - 0.02 * side, 0.05, z - 0.02), BLACK)
		piece(
			head,
			"EyeShine",
			Vector3.new(0.04, 0.04, 0.02),
			CFrame.new(x - 0.05 * side, 0.09, z - 0.027),
			WHITE,
			Enum.Material.Neon
		)
		-- cílio superior: linha escura grossa por cima do olho (leitura de anime)
		piece(head, "Lash", Vector3.new(0.31, 0.04, 0.02), CFrame.new(x, 0.15, z - 0.016) * deg(0, 0, 6 * side), INK)
		piece(
			head,
			"Brow",
			Vector3.new(0.28, 0.05, 0.02),
			-- olhando de frente, +X da cabeça fica à esquerda: o ângulo inverte por lado
			CFrame.new(x, brow[2], z - 0.012) * deg(0, 0, -brow[1] * side),
			hairColor:Lerp(BLACK, 0.35)
		)
	end
	piece(head, "Mouth", Vector3.new(0.2, 0.03, 0.02), CFrame.new(0, -0.27, z - 0.008), Color3.fromRGB(120, 60, 60))
	if style.nose then
		-- risco do nariz (traço de anime) entre os olhos e a boca
		piece(
			head,
			"Nose",
			Vector3.new(0.03, 0.14, 0.02),
			CFrame.new(0.02, -0.1, z - 0.008),
			Color3.fromRGB(150, 95, 70)
		)
	end
	if style.glasses then
		for _, side in { -1, 1 } do
			piece(
				head,
				"GlassRim",
				Vector3.new(0.34, 0.24, 0.02),
				CFrame.new(0.22 * side, 0.06, z - 0.05),
				Color3.fromRGB(200, 220, 255),
				Enum.Material.Glass
			).Transparency =
				0.6
		end
		piece(head, "GlassBridge", Vector3.new(0.12, 0.03, 0.02), CFrame.new(0, 0.1, z - 0.05), INK)
	end
	if style.beard then
		wedge(
			head,
			"Beard",
			Vector3.new(0.7, 0.45, 0.25),
			CFrame.new(0, -0.62, z + 0.08) * deg(180, 0, 0),
			style.beard,
			Enum.Material.Fabric
		)
		piece(head, "Mustache", Vector3.new(0.45, 0.07, 0.06), CFrame.new(0, -0.2, z - 0.02), style.beard)
	end
end

-- ======================================================================= cabelo
-- Mecha: cunha fina da raiz até a ponta (a face larga para fora); `tip` relativo à raiz.
local function lock(head: BasePart, root: Vector3, tip: Vector3, width: number, thick: number, color: Color3)
	local dir = tip - root
	local length = dir.Magnitude
	if length < 1e-3 then
		return
	end
	-- WedgePart: face alta em +Z, afina até a aresta de baixo em -Z → raiz em +Z, ponta em -Z
	wedge(head, "Hair", Vector3.new(width, thick, length), CFrame.lookAt(root + dir / 2, tip), color)
end

local function hairCap(head: BasePart, color: Color3, back: number?)
	local s = head.Size
	piece(head, "HairCap", Vector3.new(s.X + 0.12, 0.3, s.Z + 0.12), CFrame.new(0, s.Y / 2 + 0.06, 0.02), color)
	piece(
		head,
		"HairBack",
		Vector3.new(s.X + 0.1, s.Y * (back or 0.75), 0.18),
		CFrame.new(0, s.Y / 2 - s.Y * (back or 0.75) / 2 + 0.08, s.Z / 2 + 0.05),
		color
	)
	for _, side in { -1, 1 } do
		piece(
			head,
			"HairSide",
			Vector3.new(0.14, s.Y * 0.55, s.Z * 0.85),
			-- rente ao crânio (o corpo liso tem a cabeça mais estreita que o bloco)
			CFrame.new(side * (s.X * 0.42), s.Y * 0.2, 0.06),
			color
		)
	end
end

local function bangs(head: BasePart, color: Color3, count: number, length: number)
	local s = head.Size
	for i = 1, count do
		local u = (i - 0.5) / count * 2 - 1
		local root = Vector3.new(u * s.X * 0.45, s.Y / 2 + 0.06, -s.Z / 2 + 0.02)
		local tip = root + Vector3.new(u * 0.1, -length * (0.75 + 0.25 * math.cos(u * 2)), -0.1)
		lock(head, root, tip, s.X / count + 0.08, 0.12, color)
	end
end

local HAIR = {}

function HAIR.spiky(head: BasePart, color: Color3)
	hairCap(head, color, 0.7)
	bangs(head, color, 4, 0.4)
	local s = head.Size
	local spikes = {
		{ Vector3.new(0, 0.62, 0.1), Vector3.new(0.05, 1.25, 0.35) },
		{ Vector3.new(-0.35, 0.58, 0.05), Vector3.new(-0.75, 1.05, 0.25) },
		{ Vector3.new(0.35, 0.58, 0.05), Vector3.new(0.78, 1.0, 0.3) },
		{ Vector3.new(-0.2, 0.5, 0.45), Vector3.new(-0.45, 0.85, 1.0) },
		{ Vector3.new(0.2, 0.5, 0.45), Vector3.new(0.5, 0.8, 1.0) },
		{ Vector3.new(0, 0.3, 0.6), Vector3.new(0.05, 0.25, 1.15) },
		{ Vector3.new(-0.5, 0.25, 0.3), Vector3.new(-0.95, 0.15, 0.6) },
		{ Vector3.new(0.5, 0.25, 0.3), Vector3.new(0.95, 0.1, 0.62) },
	}
	for _, sp in spikes do
		lock(head, sp[1] * Vector3.new(s.X / 1.16, s.Y / 1.18, s.Z / 1.16), sp[2], 0.38, 0.28, color)
	end
end

-- Ichigo: o espetado com mais mechas, mais altas e jogadas para trás, franja pontuda na testa
function HAIR.ichigo(head: BasePart, color: Color3)
	HAIR.spiky(head, color)
	local s = head.Size
	local extra = {
		{ Vector3.new(-0.15, 0.62, -0.1), Vector3.new(-0.35, 1.35, 0.15) },
		{ Vector3.new(0.18, 0.62, -0.05), Vector3.new(0.42, 1.3, 0.2) },
		{ Vector3.new(0, 0.55, 0.3), Vector3.new(0, 1.15, 0.85) },
		-- franja pontuda para a frente, acima das sobrancelhas (o rosto fica à mostra)
		{ Vector3.new(-0.3, 0.55, -0.4), Vector3.new(-0.45, 0.48, -0.95) },
		{ Vector3.new(0.3, 0.55, -0.4), Vector3.new(0.48, 0.5, -0.95) },
		{ Vector3.new(0, 0.58, -0.42), Vector3.new(0.05, 0.52, -1.0) },
	}
	for _, sp in extra do
		lock(head, sp[1] * Vector3.new(s.X / 1.16, s.Y / 1.18, s.Z / 1.16), sp[2], 0.36, 0.26, color)
	end
end

-- Ichigo (cartão da escolha): volume grande, espetos em volta da cabeça toda, coroa alta e franja
-- pontuda caindo até as sobrancelhas; tons levemente diferentes por mecha (leitura de volume)
function HAIR.ichigoFull(head: BasePart, color: Color3)
	local s = head.Size
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	piece(head, "HairCap", Vector3.new(s.X + 0.18, 0.42, s.Z + 0.18), CFrame.new(0, hy + 0.12, 0.02), color)
	piece(
		head,
		"HairBack",
		Vector3.new(s.X + 0.16, s.Y * 0.8, 0.22),
		CFrame.new(0, hy - s.Y * 0.4 + 0.12, hz + 0.08),
		color
	)
	for _, side in { -1, 1 } do
		piece(
			head,
			"HairSide",
			Vector3.new(0.16, s.Y * 0.5, s.Z * 0.9),
			CFrame.new(side * (hx + 0.06), s.Y * 0.22, 0.06),
			color
		)
	end
	local function tone(k: number): Color3
		return color:Lerp(Color3.new(1, 1, 1), (k % 3) * 0.04):Lerp(Color3.new(0, 0, 0), (k % 2) * 0.06)
	end
	-- anel de espetos em volta (para os lados e para trás, um pouco para cima)
	for k = 0, 13 do
		local a = k / 14 * math.pi * 2
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		if dir.Z < -0.55 then
			continue -- a frente fica para a franja
		end
		local root = Vector3.new(dir.X * hx * 0.8, hy * 0.75, dir.Z * hz * 0.8)
		local tip = root + dir * 0.75 + Vector3.new(0, 0.32 + (k % 3) * 0.1, 0)
		lock(head, root, tip, 0.42, 0.3, tone(k))
	end
	-- coroa: espetos altos
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		local root = Vector3.new(math.sin(a) * 0.25, hy + 0.25, math.cos(a) * 0.25 + 0.05)
		local tip = root + Vector3.new(math.sin(a) * 0.45, 0.75 + (k % 2) * 0.2, math.cos(a) * 0.45)
		lock(head, root, tip, 0.4, 0.3, tone(k + 1))
	end
	-- franja: pontas caindo na testa até a linha das sobrancelhas
	for k = -2, 2 do
		local root = Vector3.new(k * 0.22, hy + 0.12, -hz + 0.05)
		local tip = Vector3.new(k * 0.26 + (if k == 0 then 0.05 else 0), 0.3 + math.abs(k) * 0.04, -hz - 0.12)
		lock(head, root, tip, 0.3, 0.14, tone(k + 3))
	end
end

function HAIR.long(head: BasePart, color: Color3)
	hairCap(head, color, 0.9)
	bangs(head, color, 5, 0.5)
	local s = head.Size
	-- cortina longa nas costas até o meio das costas, pontas desfiadas
	piece(head, "HairLong", Vector3.new(s.X + 0.15, 1.7, 0.2), CFrame.new(0, -0.55, s.Z / 2 + 0.1), color)
	for i = -2, 2 do
		lock(
			head,
			Vector3.new(i * 0.24, -1.35, s.Z / 2 + 0.1),
			Vector3.new(i * 0.27, -1.75, s.Z / 2 + 0.16),
			0.26,
			0.14,
			color
		)
	end
	-- mechas laterais na frente dos ombros
	for _, side in { -1, 1 } do
		piece(
			head,
			"HairSideLock",
			Vector3.new(0.2, 1.2, 0.22),
			CFrame.new(side * (s.X / 2 + 0.02), -0.45, -0.25),
			color
		)
	end
end

function HAIR.ponytail(head: BasePart, color: Color3)
	hairCap(head, color, 0.6)
	bangs(head, color, 4, 0.42)
	local s = head.Size
	piece(head, "HairTie", Vector3.new(0.3, 0.3, 0.2), CFrame.new(0, 0.32, s.Z / 2 + 0.12), Color3.fromRGB(200, 40, 50))
	local points = {
		Vector3.new(0, 0.32, s.Z / 2 + 0.2),
		Vector3.new(0, 0.1, s.Z / 2 + 0.55),
		Vector3.new(0, -0.5, s.Z / 2 + 0.6),
		Vector3.new(0, -1.15, s.Z / 2 + 0.45),
	}
	for i = 1, #points - 1 do
		lock(head, points[i], points[i + 1], 0.42 - i * 0.08, 0.3 - i * 0.05, color)
	end
end

function HAIR.bob(head: BasePart, color: Color3)
	hairCap(head, color, 0.8)
	local s = head.Size
	-- corte reto na altura do queixo, franja reta
	for _, side in { -1, 1 } do
		piece(head, "HairBob", Vector3.new(0.2, 0.95, s.Z * 0.9), CFrame.new(side * (s.X * 0.45), 0, 0.05), color)
	end
	piece(head, "Fringe", Vector3.new(s.X + 0.1, 0.28, 0.12), CFrame.new(0, s.Y / 2 - 0.08, -s.Z / 2 - 0.04), color)
end

function HAIR.slick(head: BasePart, color: Color3)
	hairCap(head, color, 0.65)
	local s = head.Size
	-- penteado para trás com mechas varridas
	for i = -1, 1 do
		lock(
			head,
			Vector3.new(i * 0.3, s.Y / 2 + 0.08, -0.3),
			Vector3.new(i * 0.35, s.Y / 2 + 0.05, 0.75),
			0.35,
			0.16,
			color
		)
	end
end

function HAIR.wild(head: BasePart, color: Color3)
	HAIR.spiky(head, color)
	local s = head.Size
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local root = Vector3.new(math.cos(a) * s.X * 0.45, 0.35, math.sin(a) * s.Z * 0.45 + 0.1)
		lock(head, root, root + Vector3.new(math.cos(a) * 0.55, 0.35, math.sin(a) * 0.55 + 0.2), 0.3, 0.24, color)
	end
end

-- ======================================================================= roupas
local OUTFIT = {}

-- Mangas largas de quimono: caem abaixo do braço como sino
local function kimonoSleeves(model: Model, color: Color3, cuff: Color3?)
	for _, side in { "Left", "Right" } do
		local arm = part(model, side .. "UpperArm")
		local fore = part(model, side .. "LowerArm")
		if arm then
			piece(arm, "Sleeve", Vector3.new(1.12, 1.3, 1.12), CFrame.new(0, 0, 0), color, Enum.Material.Fabric)
		end
		if fore then
			piece(
				fore,
				"SleeveBell",
				Vector3.new(1.18, 1.05, 1.25),
				CFrame.new(0, 0.05, 0.06),
				color,
				Enum.Material.Fabric
			)
			wedge(
				fore,
				"SleeveDrape",
				Vector3.new(1.16, 0.55, 1.2),
				CFrame.new(0, -0.7, 0.05) * deg(180, 0, 0),
				color,
				Enum.Material.Fabric
			)
			if cuff then
				piece(fore, "Cuff", Vector3.new(1.2, 0.08, 1.27), CFrame.new(0, -0.47, 0.06), cuff)
			end
		end
	end
end

-- Gola em V (por dentro branca) e faixa (obi)
local function vCollar(model: Model, inner: Color3, outer: Color3)
	local upper = part(model, "UpperTorso")
	if not upper then
		return
	end
	local z = -upper.Size.Z / 2 - 0.02
	for _, side in { -1, 1 } do
		piece(
			upper,
			"CollarInner",
			Vector3.new(0.2, 1.1, 0.03),
			CFrame.new(0.2 * side, 0.35, z) * deg(0, 0, -28 * side),
			inner
		)
		piece(
			upper,
			"CollarOuter",
			Vector3.new(0.12, 1.15, 0.04),
			CFrame.new(0.32 * side, 0.32, z - 0.005) * deg(0, 0, -28 * side),
			outer:Lerp(BLACK, 0.3)
		)
	end
end

local function obi(model: Model, color: Color3, knot: boolean?)
	local lower = part(model, "LowerTorso")
	if not lower then
		return
	end
	piece(
		lower,
		"Obi",
		Vector3.new(lower.Size.X + 0.1, 0.42, lower.Size.Z + 0.1),
		CFrame.new(0, 0.12, 0),
		color,
		Enum.Material.Fabric
	)
	if knot then
		piece(lower, "ObiKnot", Vector3.new(0.4, 0.3, 0.2), CFrame.new(0.55, 0.1, -lower.Size.Z / 2 - 0.12), color)
	end
end

-- Hakama: calça-saia larga que abre embaixo, pregas na frente
local function hakama(model: Model, color: Color3)
	for _, side in { "Left", "Right" } do
		local thigh = part(model, side .. "UpperLeg")
		local shin = part(model, side .. "LowerLeg")
		if thigh then
			piece(thigh, "Hakama", Vector3.new(1.1, 1.4, 1.1), CFrame.new(0, 0, 0), color, Enum.Material.Fabric)
		end
		if shin then
			piece(
				shin,
				"HakamaFlare",
				Vector3.new(1.22, 1.25, 1.22),
				CFrame.new(0, 0.05, 0),
				color,
				Enum.Material.Fabric
			)
			for _, x in { -0.3, 0, 0.3 } do
				piece(shin, "Pleat", Vector3.new(0.04, 1.2, 0.03), CFrame.new(x, 0.05, -0.625), color:Lerp(BLACK, 0.35))
			end
		end
	end
end

local function tabi(model: Model, sock: Color3, sandal: Color3)
	paint(model, FEET, sock)
	for _, n in FEET do
		local foot = part(model, n)
		if foot then
			piece(foot, "Sandal", Vector3.new(1.05, 0.08, 1.08), CFrame.new(0, -0.16, 0), sandal)
			piece(foot, "Strap", Vector3.new(0.08, 0.06, 0.5), CFrame.new(0, 0.12, -0.22), sandal:Lerp(BLACK, 0.4))
		end
	end
end

function OUTFIT.shihakusho(model: Model, style: Style)
	local c = style.colors or {}
	local robe = c.robe or BLACK
	paint(model, { "UpperTorso", "LowerTorso" }, robe, Enum.Material.Fabric)
	paint(model, ARMS, robe, Enum.Material.Fabric)
	paint(model, FOREARMS, robe, Enum.Material.Fabric)
	paint(model, THIGHS, robe, Enum.Material.Fabric)
	paint(model, SHINS, robe, Enum.Material.Fabric)
	vCollar(model, c.inner or WHITE, robe)
	kimonoSleeves(model, robe)
	obi(model, c.obi or WHITE)
	hakama(model, robe)
	tabi(model, WHITE, Color3.fromRGB(150, 110, 70))
end

-- Haori de capitão: casaco branco sem mangas por cima, caudas longas atrás, forro colorido,
-- emblema da divisão nas costas
function OUTFIT.captain(model: Model, style: Style)
	OUTFIT.shihakusho(model, style)
	local c = style.colors or {}
	local haori = c.haori or WHITE
	local lining = c.lining or Color3.fromRGB(60, 80, 140)
	local upper = part(model, "UpperTorso")
	if not upper then
		return
	end
	local w, h, d = upper.Size.X, upper.Size.Y, upper.Size.Z
	piece(
		upper,
		"HaoriBack",
		Vector3.new(w + 0.2, h + 0.1, 0.08),
		CFrame.new(0, 0.02, d / 2 + 0.06),
		haori,
		Enum.Material.Fabric
	)
	for _, side in { -1, 1 } do
		piece(
			upper,
			"HaoriFront",
			Vector3.new(0.42, h + 0.1, 0.08),
			CFrame.new(side * (w / 2 - 0.12), 0.02, -d / 2 - 0.06),
			haori,
			Enum.Material.Fabric
		)
		piece(
			upper,
			"HaoriShoulder",
			Vector3.new(0.45, 0.12, d + 0.24),
			CFrame.new(side * (w / 2 - 0.1), h / 2 + 0.03, 0),
			haori
		)
		piece(
			upper,
			"HaoriLining",
			Vector3.new(0.06, h, 0.06),
			CFrame.new(side * (w / 2 - 0.33), 0, -d / 2 - 0.1),
			lining
		)
		-- caudas: duas abas que descem até a canela, abrindo um pouco
		wedge(
			upper,
			"HaoriTail",
			Vector3.new(0.08, 2.9, 1.1),
			CFrame.new(side * 0.5, -h / 2 - 1.4, d / 2 + 0.12) * deg(0, 90 * side, 0) * deg(0, 0, 0),
			haori,
			Enum.Material.Fabric
		)
		piece(
			upper,
			"HaoriSkirt",
			Vector3.new(w / 2 + 0.1, 2.6, 0.08),
			CFrame.new(side * (w / 4 + 0.03), -h / 2 - 1.25, d / 2 + 0.08) * deg(-4, 0, 3 * side),
			haori,
			Enum.Material.Fabric
		)
	end
	-- emblema: losango preto nas costas
	piece(upper, "Emblem", Vector3.new(0.5, 0.5, 0.03), CFrame.new(0, 0.1, d / 2 + 0.11) * deg(0, 0, 45), BLACK)
	piece(upper, "EmblemInner", Vector3.new(0.3, 0.3, 0.03), CFrame.new(0, 0.1, d / 2 + 0.12) * deg(0, 0, 45), haori)
end

function OUTFIT.lieutenant(model: Model, style: Style)
	OUTFIT.shihakusho(model, style)
	local arm = part(model, "LeftUpperArm")
	if arm then
		piece(arm, "Armband", Vector3.new(1.16, 0.32, 1.16), CFrame.new(0, 0.15, 0), WHITE, Enum.Material.Fabric)
		piece(arm, "Badge", Vector3.new(0.05, 0.22, 0.3), CFrame.new(-0.59, 0.15, 0), Color3.fromRGB(40, 40, 50))
	end
end

-- Arrancar: jaqueta branca de gola alta, faixa preta, hakama branca, buraco no peito
function OUTFIT.arrancar(model: Model, style: Style)
	local c = style.colors or {}
	local coat = c.coat or WHITE
	local sash = c.sash or BLACK
	paint(model, { "UpperTorso", "LowerTorso" }, coat, Enum.Material.Fabric)
	paint(model, ARMS, coat, Enum.Material.Fabric)
	paint(model, FOREARMS, coat, Enum.Material.Fabric)
	paint(model, THIGHS, coat, Enum.Material.Fabric)
	paint(model, SHINS, coat, Enum.Material.Fabric)
	local upper = part(model, "UpperTorso")
	if upper then
		local w, h, d = upper.Size.X, upper.Size.Y, upper.Size.Z
		piece(upper, "HighCollar", Vector3.new(w * 0.6, 0.45, d + 0.1), CFrame.new(0, h / 2 + 0.15, 0.05), coat)
		piece(upper, "Zip", Vector3.new(0.06, h, 0.03), CFrame.new(0, 0, -d / 2 - 0.02), sash)
		local hole = piece(
			upper,
			"HollowHole",
			Vector3.new(0.12, 0.62, 0.62),
			CFrame.new(0.3, -0.15, -d / 2 - 0.01) * deg(0, 90, 0),
			Color3.fromRGB(5, 5, 8)
		);
		(hole :: Part).Shape = Enum.PartType.Cylinder
		-- abas do casaco abaixo da cintura
		for _, side in { -1, 1 } do
			piece(
				upper,
				"CoatFlap",
				Vector3.new(w / 2 + 0.05, 1.4, 0.08),
				CFrame.new(side * w / 4, -h / 2 - 0.65, -d / 2 - 0.05),
				coat,
				Enum.Material.Fabric
			)
		end
	end
	obi(model, sash, true)
	hakama(model, coat)
	paint(model, FEET, BLACK)
end

-- Humano (estágio inicial do jogador): uniforme do colégio de Karakura — blazer cinza, camisa
-- branca com gola e gravata vermelha, calça cinza-escuro e sapato marrom
function OUTFIT.human(model: Model, style: Style)
	local c = style.colors or {}
	local blazer = c.blazer or Color3.fromRGB(118, 118, 126)
	local pants = c.pants or Color3.fromRGB(62, 62, 70)
	paint(model, { "UpperTorso" }, blazer, Enum.Material.Fabric)
	paint(model, ARMS, blazer, Enum.Material.Fabric)
	paint(model, FOREARMS, blazer, Enum.Material.Fabric)
	paint(model, { "LowerTorso" }, pants, Enum.Material.Fabric)
	paint(model, THIGHS, pants, Enum.Material.Fabric)
	paint(model, SHINS, pants, Enum.Material.Fabric)
	paint(model, FEET, Color3.fromRGB(70, 44, 30))
	local upper = part(model, "UpperTorso")
	if upper then
		local w, h, d = upper.Size.X, upper.Size.Y, upper.Size.Z
		local z = -d / 2 - 0.02
		-- camisa aparecendo no V do blazer, gravata, lapelas e botões
		piece(upper, "ShirtV", Vector3.new(0.5, 0.75, 0.03), CFrame.new(0, h / 2 - 0.38, z), WHITE)
		piece(
			upper,
			"Tie",
			Vector3.new(0.14, 0.62, 0.03),
			CFrame.new(0, h / 2 - 0.42, z - 0.01),
			Color3.fromRGB(170, 30, 40)
		)
		for _, side in { -1, 1 } do
			piece(
				upper,
				"Lapel",
				Vector3.new(0.12, 0.85, 0.04),
				CFrame.new(0.27 * side, h / 2 - 0.42, z - 0.015) * deg(0, 0, -20 * side),
				blazer:Lerp(BLACK, 0.25)
			)
		end
		for k = 0, 1 do
			piece(
				upper,
				"Button",
				Vector3.new(0.08, 0.08, 0.03),
				CFrame.new(0.12, -0.15 - k * 0.3, z - 0.01),
				Color3.fromRGB(40, 40, 44)
			)
		end
		piece(upper, "Collar", Vector3.new(w * 0.5, 0.2, d + 0.06), CFrame.new(0, h / 2 - 0.05, 0), WHITE)
	end
	for _, side in { "Left", "Right" } do
		local fore = part(model, side .. "LowerArm")
		if fore then
			piece(fore, "Cuff", Vector3.new(1.06, 0.1, 1.06), CFrame.new(0, -0.5, 0), WHITE)
		end
	end
end

-- Ichigo humano: uniforme do colégio de Karakura do jeito dele — blazer cinza aberto, camisa
-- branca para fora da calça e aberta no colarinho, sem gravata, calça cinza e tênis
function OUTFIT.ichigo(model: Model, style: Style)
	local blazer = Color3.fromRGB(112, 114, 124)
	local pants = Color3.fromRGB(84, 86, 96)
	paint(model, { "UpperTorso" }, WHITE, Enum.Material.Fabric)
	paint(model, ARMS, blazer, Enum.Material.Fabric)
	paint(model, FOREARMS, blazer, Enum.Material.Fabric)
	paint(model, { "LowerTorso" }, pants, Enum.Material.Fabric)
	paint(model, THIGHS, pants, Enum.Material.Fabric)
	paint(model, SHINS, pants, Enum.Material.Fabric)
	paint(model, FEET, Color3.fromRGB(235, 235, 238))
	local upper = part(model, "UpperTorso")
	if upper then
		local w, h, d = upper.Size.X, upper.Size.Y, upper.Size.Z
		-- blazer aberto: costas e as duas frentes, deixando a camisa à mostra no meio
		piece(
			upper,
			"JacketPanel",
			Vector3.new(w + 0.08, h + 0.05, 0.1),
			CFrame.new(0, 0, d / 2 + 0.02),
			blazer,
			Enum.Material.Fabric
		)
		for _, side in { -1, 1 } do
			piece(
				upper,
				"JacketFront",
				Vector3.new(w * 0.3, h + 0.05, 0.1),
				CFrame.new(side * w * 0.36, 0, -d / 2 - 0.03),
				blazer,
				Enum.Material.Fabric
			)
			piece(
				upper,
				"Lapel",
				Vector3.new(0.14, 0.9, 0.05),
				CFrame.new(side * w * 0.22, h / 2 - 0.45, -d / 2 - 0.07) * deg(0, 0, -16 * side),
				blazer:Lerp(BLACK, 0.2)
			)
			piece(
				upper,
				"JacketSide",
				Vector3.new(0.1, h + 0.05, d + 0.1),
				CFrame.new(side * (w / 2 + 0.03), 0, 0),
				blazer,
				Enum.Material.Fabric
			)
		end
		-- colarinho aberto e a barra da camisa para fora
		for _, side in { -1, 1 } do
			piece(
				upper,
				"Collar",
				Vector3.new(0.3, 0.14, 0.3),
				CFrame.new(side * 0.2, h / 2 - 0.02, -d / 2 + 0.05) * deg(0, 0, 25 * side),
				WHITE
			)
		end
	end
	local lower = part(model, "LowerTorso")
	if lower then
		piece(
			lower,
			"ShirtHem",
			Vector3.new(lower.Size.X * 0.55, 0.3, 0.06),
			CFrame.new(0, -0.05, -lower.Size.Z / 2 - 0.03),
			WHITE,
			Enum.Material.Fabric
		)
	end
	for _, n in FEET do
		local foot = part(model, n)
		if foot then
			piece(foot, "Sole", Vector3.new(1.05, 0.1, 1.05), CFrame.new(0, -0.15, 0), Color3.fromRGB(60, 60, 66))
		end
	end
end

-- Ichigo do modelo de referência: camisa branca de manga curta aberta (gola de lapela, bolso
-- no peito, manga dobrada com etiqueta vermelha, para fora da calça) sobre camiseta preta, calça
-- cinza larga e sapato preto; antebraços à mostra
function OUTFIT.ichigoShirt(model: Model, style: Style)
	local shirt = Color3.fromRGB(236, 238, 246)
	local fold = Color3.fromRGB(206, 210, 228)
	local pants = Color3.fromRGB(142, 142, 150)
	-- antebraço com a cor da cabeça (pele já aplicada pelo rosto)
	local head = part(model, "Head")
	local skin = if head then head.Color else style.skin
	paint(model, { "UpperTorso" }, shirt, Enum.Material.Fabric)
	paint(model, ARMS, shirt, Enum.Material.Fabric)
	paint(model, FOREARMS, skin)
	paint(model, { "LowerTorso" }, pants, Enum.Material.Fabric)
	paint(model, THIGHS, pants, Enum.Material.Fabric)
	paint(model, SHINS, pants, Enum.Material.Fabric)
	paint(model, FEET, Color3.fromRGB(28, 28, 32))
	local upper = part(model, "UpperTorso")
	if upper then
		local h, d = upper.Size.Y, upper.Size.Z
		local z = -d / 2 - 0.02
		-- camiseta preta no decote em V
		wedge(
			upper,
			"TeeV",
			Vector3.new(0.5, 0.42, 0.03),
			CFrame.new(0, h / 2 - 0.21, z) * deg(0, 0, 180),
			Color3.fromRGB(20, 20, 24)
		)
		for _, side in { -1, 1 } do
			-- lapelas da gola e a borda da camisa aberta
			piece(
				upper,
				"Lapel",
				Vector3.new(0.3, 0.42, 0.05),
				CFrame.new(side * 0.3, h / 2 - 0.2, z - 0.01) * deg(0, 0, -28 * side),
				shirt
			)
			piece(upper, "PlacketLine", Vector3.new(0.03, h * 0.62, 0.02), CFrame.new(0.02, -h * 0.17, z - 0.01), fold)
		end
		-- bolso no peito (lado esquerdo do personagem = -X do R15)
		piece(upper, "Pocket", Vector3.new(0.42, 0.38, 0.03), CFrame.new(-0.5, 0.05, z - 0.01), shirt:Lerp(fold, 0.35))
		piece(upper, "PocketFlap", Vector3.new(0.44, 0.06, 0.04), CFrame.new(-0.5, 0.25, z - 0.02), fold)
		-- vincos de tecido
		for _, k in { -1, 1 } do
			piece(
				upper,
				"Crease",
				Vector3.new(0.4, 0.03, 0.02),
				CFrame.new(k * 0.45, -0.45, z - 0.005) * deg(0, 0, 20 * k),
				fold
			)
		end
	end
	-- barra da camisa para fora, cobrindo o quadril
	local lower = part(model, "LowerTorso")
	if lower then
		piece(
			lower,
			"ShirtHem",
			Vector3.new(lower.Size.X + 0.06, 0.5, lower.Size.Z + 0.06),
			CFrame.new(0, 0.05, 0),
			shirt,
			Enum.Material.Fabric
		)
	end
	-- manga dobrada com a etiqueta vermelha no braço esquerdo
	for _, side in { "Left", "Right" } do
		local arm = part(model, side .. "UpperArm")
		if arm then
			piece(
				arm,
				"SleeveFold",
				Vector3.new(arm.Size.X + 0.08, 0.26, arm.Size.Z + 0.08),
				CFrame.new(0, -arm.Size.Y / 2 + 0.12, 0),
				fold:Lerp(shirt, 0.5),
				Enum.Material.Fabric
			)
			if side == "Left" then
				piece(
					arm,
					"SleeveTag",
					Vector3.new(0.05, 0.2, 0.14),
					CFrame.new(arm.Size.X / 2 + 0.05, -arm.Size.Y / 2 + 0.12, 0),
					Color3.fromRGB(210, 30, 40)
				)
			end
		end
	end
	-- sapato com sola mais clara
	for _, n in FEET do
		local foot = part(model, n)
		if foot then
			piece(foot, "Sole", Vector3.new(1.06, 0.1, 1.06), CFrame.new(0, -0.15, 0), Color3.fromRGB(70, 70, 76))
		end
	end
end

-- ===================================================================== estágios Hollow
-- Corpo de Hollow: pele quase preta, buraco no peito (atravessa o tronco)
local SHADOW = Color3.fromRGB(26, 24, 30)
local BONE = Color3.fromRGB(238, 232, 218)
local function hollowBody(model: Model, skin: Color3)
	for _, names in { { "UpperTorso", "LowerTorso" }, ARMS, FOREARMS, THIGHS, SHINS, FEET, { "LeftHand", "RightHand" } } do
		paint(model, names, skin, Enum.Material.SmoothPlastic)
	end
	local upper = part(model, "UpperTorso")
	if upper then
		local hole = piece(
			upper,
			"HollowHole",
			Vector3.new(upper.Size.Z + 0.06, 0.62, 0.62),
			CFrame.new(0, -0.1, 0) * deg(0, 90, 0),
			Color3.fromRGB(4, 4, 6)
		);
		(hole :: Part).Shape = Enum.PartType.Cylinder
	end
end

-- Máscara de Hollow no rosto: placa óssea com olhos vazados em brilho e fileira de dentes
local function hollowMask(model: Model, eye: Color3, opts: { nose: boolean?, horns: number?, stripes: boolean? }?)
	local head = part(model, "Head")
	if not head then
		return
	end
	local o = opts or {}
	local hs = head.Size
	local z = -hs.Z / 2
	piece(head, "MaskFull", Vector3.new(hs.X * 1.08, hs.Y * 1.02, 0.24), CFrame.new(0, 0.02, z - 0.06), BONE)
	for _, side in { -1, 1 } do
		piece(
			head,
			"MaskEye",
			Vector3.new(0.26, 0.11, 0.04),
			CFrame.new(side * 0.24, 0.1, z - 0.2) * deg(0, 0, -12 * side),
			eye,
			Enum.Material.Neon
		)
		if o.stripes then
			piece(
				head,
				"MaskStripe",
				Vector3.new(0.06, hs.Y * 0.7, 0.03),
				CFrame.new(side * 0.36, -0.05, z - 0.2),
				Color3.fromRGB(200, 20, 40),
				Enum.Material.Neon
			)
		end
	end
	for k = -3, 3 do
		piece(
			head,
			"MaskTooth",
			Vector3.new(0.07, 0.15, 0.04),
			CFrame.new(k * 0.11, -0.32, z - 0.2),
			Color3.fromRGB(250, 248, 240)
		)
	end
	if o.nose then
		-- nariz comprido dos Menos
		wedge(head, "MaskNose", Vector3.new(0.3, 0.3, 1.3), CFrame.new(0, -0.02, z - 0.75) * deg(-8, 180, 0), BONE)
	end
	for i = 1, (o.horns or 0) do
		local side = if i % 2 == 1 then -1 else 1
		local len = if i <= 2 then 1.1 else 0.7
		wedge(
			head,
			"MaskHorn",
			Vector3.new(0.16, 0.5, len),
			CFrame.new(side * 0.45, hs.Y / 2 + 0.1 + (if i > 2 then -0.3 else 0), 0.1) * deg(-55, 20 * side, -25 * side),
			BONE
		)
	end
end

local function boneSpikes(model: Model, count: number, length: number)
	local upper = part(model, "UpperTorso")
	if not upper then
		return
	end
	local w, h = upper.Size.X, upper.Size.Y
	for _, side in { -1, 1 } do
		for k = 1, count do
			wedge(
				upper,
				"BoneSpike",
				Vector3.new(0.18, 0.2, length * (1 - k * 0.18)),
				CFrame.new(side * (w / 2 - 0.1 - k * 0.12), h / 2 + 0.05, 0.1 + k * 0.12) * deg(-50, 30 * side, 0),
				BONE
			)
		end
	end
end

-- 1. Hollow: sombra com máscara inteira e espinhos de osso nos ombros
function OUTFIT.hollowSpawn(model: Model, style: Style)
	hollowBody(model, SHADOW)
	hollowMask(model, Color3.fromRGB(255, 200, 60))
	boneSpikes(model, 2, 0.9)
	-- marcas pretas na máscara (testa e bochechas) e cauda de osso segmentada
	local head = part(model, "Head")
	if head then
		local z = -head.Size.Z / 2 - 0.2
		piece(head, "MaskMark", Vector3.new(0.08, 0.32, 0.03), CFrame.new(0, 0.34, z), BLACK)
		for _, side in { -1, 1 } do
			piece(
				head,
				"MaskMark",
				Vector3.new(0.07, 0.3, 0.03),
				CFrame.new(side * 0.3, -0.12, z) * deg(0, 0, 20 * side),
				BLACK
			)
		end
	end
	local lower = part(model, "LowerTorso")
	if lower then
		local frame = CFrame.new(0, -0.1, lower.Size.Z / 2 + 0.1) * deg(35, 0, 0)
		for k = 1, 5 do
			local size = 0.5 - k * 0.07
			piece(
				lower,
				"TailSegment",
				Vector3.new(size, size, 0.7),
				frame * CFrame.new(0, 0, 0.35),
				if k % 2 == 0 then BONE else SHADOW
			)
			frame = frame * CFrame.new(0, 0, 0.62) * deg(-14, 0, 0)
		end
		wedge(lower, "TailTip", Vector3.new(0.14, 0.2, 0.5), frame * CFrame.new(0, 0, 0.3), BONE)
	end
end

-- 2. Menos: manto preto longo até os pés, gola de espinhos, máscara de nariz comprido
function OUTFIT.menos(model: Model, style: Style)
	hollowBody(model, Color3.fromRGB(14, 13, 18))
	hollowMask(model, Color3.fromRGB(255, 60, 60), { nose = true })
	local upper = part(model, "UpperTorso")
	if upper then
		local w, h, d = upper.Size.X, upper.Size.Y, upper.Size.Z
		piece(
			upper,
			"Cape",
			Vector3.new(w + 0.3, 3.4, 0.12),
			CFrame.new(0, -1.1, d / 2 + 0.12),
			Color3.fromRGB(10, 10, 14),
			Enum.Material.Fabric
		)
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2
			wedge(
				upper,
				"BoneSpike",
				Vector3.new(0.12, 0.14, 0.42),
				CFrame.new(math.cos(a) * w * 0.32, h / 2 + 0.12, math.sin(a) * d * 0.55)
					* deg(-70, -math.deg(a) + 90, 0),
				BONE
			)
		end
	end
end

-- 3. Adjuchas: placas de osso no peito, antebraços e canelas; máscara com dois chifres
function OUTFIT.adjuchas(model: Model, style: Style)
	hollowBody(model, Color3.fromRGB(32, 28, 34))
	hollowMask(model, Color3.fromRGB(255, 120, 40), { horns = 2 })
	local upper = part(model, "UpperTorso")
	if upper then
		local w, h, d = upper.Size.X, upper.Size.Y, upper.Size.Z
		for _, side in { -1, 1 } do
			piece(
				upper,
				"BonePlate",
				Vector3.new(w * 0.42, h * 0.45, 0.16),
				CFrame.new(side * w * 0.22, h * 0.18, -d / 2 - 0.06),
				BONE
			)
		end
	end
	for _, names in { FOREARMS, SHINS } do
		for _, n in names do
			local limb = part(model, n)
			if limb then
				piece(
					limb,
					"BonePlate",
					Vector3.new(limb.Size.X + 0.1, limb.Size.Y * 0.7, 0.18),
					CFrame.new(0, 0, -limb.Size.Z / 2 - 0.05),
					BONE
				)
			end
		end
	end
	boneSpikes(model, 3, 1.1)
end

-- 4. Vasto Lorde: armadura de osso branca no corpo todo com juntas escuras, gola de pelo,
-- chifres longos e listras vermelhas na máscara
function OUTFIT.vastoLorde(model: Model, style: Style)
	hollowBody(model, BONE)
	paint(model, { "LowerTorso", "LeftHand", "RightHand" }, Color3.fromRGB(30, 26, 30), Enum.Material.SmoothPlastic)
	hollowMask(model, Color3.fromRGB(255, 40, 60), { horns = 4, stripes = true })
	local upper = part(model, "UpperTorso")
	if upper then
		local w, h, d = upper.Size.X, upper.Size.Y, upper.Size.Z
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			local fur = piece(
				upper,
				"Fur",
				Vector3.new(0.5, 0.5, 0.5),
				CFrame.new(math.cos(a) * w * 0.4, h / 2 + 0.05, math.sin(a) * d * 0.6),
				Color3.fromRGB(70, 20, 26),
				Enum.Material.Fabric
			);
			(fur :: Part).Shape = Enum.PartType.Ball
		end
		for _, side in { -1, 1 } do
			piece(
				upper,
				"RedLine",
				Vector3.new(0.06, h * 0.8, 0.03),
				CFrame.new(side * w * 0.3, 0, -d / 2 - 0.02),
				Color3.fromRGB(200, 20, 40),
				Enum.Material.Neon
			)
		end
	end
end

-- Quincy: sobretudo branco longo com friso azul, capa curta, cruz no peito
function OUTFIT.quincy(model: Model, style: Style)
	local c = style.colors or {}
	local coat = c.coat or WHITE
	local trim = c.trim or Color3.fromRGB(60, 110, 200)
	paint(model, { "UpperTorso", "LowerTorso" }, coat, Enum.Material.Fabric)
	paint(model, ARMS, coat, Enum.Material.Fabric)
	paint(model, FOREARMS, coat, Enum.Material.Fabric)
	paint(model, THIGHS, coat:Lerp(BLACK, 0.08), Enum.Material.Fabric)
	paint(model, SHINS, coat:Lerp(BLACK, 0.08), Enum.Material.Fabric)
	paint(model, FEET, Color3.fromRGB(40, 40, 50))
	local upper = part(model, "UpperTorso")
	if upper then
		local w, h, d = upper.Size.X, upper.Size.Y, upper.Size.Z
		piece(upper, "TrimFront", Vector3.new(0.1, h, 0.03), CFrame.new(-0.25, 0, -d / 2 - 0.02), trim)
		piece(upper, "Collar", Vector3.new(w * 0.7, 0.35, d + 0.12), CFrame.new(0, h / 2 + 0.1, 0.03), coat)
		-- capa: até a cintura, forro azul
		piece(
			upper,
			"Cape",
			Vector3.new(w + 0.35, h + 0.4, 0.07),
			CFrame.new(0, -0.15, d / 2 + 0.09),
			coat,
			Enum.Material.Fabric
		)
		piece(upper, "CapeLining", Vector3.new(w + 0.3, 0.1, 0.08), CFrame.new(0, -h / 2 - 0.33, d / 2 + 0.1), trim)
		-- cruz Quincy (cinco pontas simplificada)
		piece(
			upper,
			"CrossV",
			Vector3.new(0.08, 0.45, 0.03),
			CFrame.new(0.42, 0.35, -d / 2 - 0.03),
			trim,
			Enum.Material.Neon
		)
		piece(
			upper,
			"CrossH",
			Vector3.new(0.36, 0.08, 0.03),
			CFrame.new(0.42, 0.42, -d / 2 - 0.03),
			trim,
			Enum.Material.Neon
		)
		for _, side in { -1, 1 } do
			piece(
				upper,
				"CoatSkirt",
				Vector3.new(w / 2 + 0.05, 2.2, 0.08),
				CFrame.new(side * w / 4, -h / 2 - 1.05, -d / 2 - 0.05) * deg(4, 0, -3 * side),
				coat,
				Enum.Material.Fabric
			)
			piece(
				upper,
				"SkirtTrim",
				Vector3.new(w / 2 + 0.06, 0.1, 0.09),
				CFrame.new(side * w / 4 + 0.05 * side, -h / 2 - 2.12, -d / 2 - 0.12) * deg(4, 0, -3 * side),
				trim
			)
		end
	end
	for _, n in FOREARMS do
		local fore = part(model, n)
		if fore then
			piece(fore, "Cuff", Vector3.new(1.06, 0.12, 1.06), CFrame.new(0, -0.48, 0), trim)
		end
	end
end

-- Fullbringer: jaqueta escura aberta com capuz, camiseta clara, jeans, tênis, corrente acesa
function OUTFIT.fullbring(model: Model, style: Style)
	local c = style.colors or {}
	local jacket = c.jacket or Color3.fromRGB(45, 50, 60)
	local shirt = c.shirt or Color3.fromRGB(220, 220, 225)
	local glow = c.glow or Color3.fromRGB(110, 255, 170)
	paint(model, { "UpperTorso" }, shirt, Enum.Material.Fabric)
	paint(model, ARMS, jacket, Enum.Material.Fabric)
	paint(model, FOREARMS, jacket, Enum.Material.Fabric)
	paint(model, { "LowerTorso" }, Color3.fromRGB(50, 60, 90), Enum.Material.Fabric)
	paint(model, THIGHS, Color3.fromRGB(50, 60, 90), Enum.Material.Fabric)
	paint(model, SHINS, Color3.fromRGB(50, 60, 90), Enum.Material.Fabric)
	paint(model, FEET, WHITE)
	local upper = part(model, "UpperTorso")
	if upper then
		local w, h, d = upper.Size.X, upper.Size.Y, upper.Size.Z
		for _, side in { -1, 1 } do
			piece(
				upper,
				"JacketFront",
				Vector3.new(w / 2 - 0.25, h + 0.25, d + 0.1),
				CFrame.new(side * (w / 4 + 0.12), -0.1, 0),
				jacket,
				Enum.Material.Fabric
			)
		end
		piece(
			upper,
			"Hood",
			Vector3.new(w * 0.7, 0.55, 0.5),
			CFrame.new(0, h / 2 - 0.05, d / 2 + 0.15),
			jacket,
			Enum.Material.Fabric
		)
		-- corrente de energia cruzando o peito
		for i = 0, 5 do
			piece(
				upper,
				"ChainLink",
				Vector3.new(0.18, 0.08, 0.05),
				CFrame.new(-0.6 + i * 0.24, 0.55 - i * 0.2, -d / 2 - 0.06) * deg(0, 0, -40 + (i % 2) * 80),
				glow,
				Enum.Material.Neon
			)
		end
	end
	for _, n in FEET do
		local foot = part(model, n)
		if foot then
			piece(foot, "Sole", Vector3.new(1.05, 0.1, 1.05), CFrame.new(0, -0.15, 0), Color3.fromRGB(200, 60, 60))
		end
	end
end

-- Lojista: quimono verde, haori curto escuro, chapéu-balde listrado, tamancos
function OUTFIT.shopkeeper(model: Model, style: Style)
	local c = style.colors or {}
	local kimono = c.kimono or Color3.fromRGB(70, 90, 70)
	local jacket = c.jacket or Color3.fromRGB(40, 40, 40)
	paint(model, { "UpperTorso", "LowerTorso" }, kimono, Enum.Material.Fabric)
	paint(model, ARMS, jacket, Enum.Material.Fabric)
	paint(model, FOREARMS, jacket, Enum.Material.Fabric)
	paint(model, THIGHS, kimono, Enum.Material.Fabric)
	paint(model, SHINS, kimono, Enum.Material.Fabric)
	vCollar(model, kimono:Lerp(WHITE, 0.4), kimono)
	kimonoSleeves(model, jacket)
	obi(model, Color3.fromRGB(120, 90, 50))
	tabi(model, Color3.fromRGB(230, 225, 215), Color3.fromRGB(110, 80, 50))
	local upper = part(model, "UpperTorso")
	if upper then
		local w, h, d = upper.Size.X, upper.Size.Y, upper.Size.Z
		for _, side in { -1, 1 } do
			piece(
				upper,
				"JacketPanel",
				Vector3.new(0.45, h + 0.3, d + 0.12),
				CFrame.new(side * (w / 2 - 0.2), -0.12, 0),
				jacket,
				Enum.Material.Fabric
			)
		end
	end
	local head = part(model, "Head")
	if head then
		local hat = Color3.fromRGB(60, 90, 60)
		-- chapéu-balde listrado: aba caída (esculpida no HumanSkin), copa macia, duas listras
		local tilt = CFrame.new(0, 0.42, 0.02) * deg(-7, 0, 0)
		piece(head, "HatBrim", Vector3.new(2.1, 0.08, 2.1), tilt, hat, Enum.Material.Fabric)
		piece(head, "HatTop", Vector3.new(1.28, 0.62, 1.28), tilt * CFrame.new(0, 0.3, 0), hat, Enum.Material.Fabric)
		for i, y in { 0.12, 0.3 } do
			piece(
				head,
				"HatStripe",
				Vector3.new(1.32 - i * 0.04, 0.08, 1.32 - i * 0.04),
				tilt * CFrame.new(0, y, 0),
				WHITE,
				Enum.Material.Fabric
			)
		end
	end
end

-- Estudante: camisa branca, gola de marinheiro azul com laço vermelho, saia plissada, meias
function OUTFIT.school(model: Model, style: Style)
	local c = style.colors or {}
	local navy = c.navy or Color3.fromRGB(40, 50, 90)
	paint(model, { "UpperTorso" }, WHITE, Enum.Material.Fabric)
	paint(model, ARMS, WHITE, Enum.Material.Fabric)
	paint(model, { "LowerTorso" }, navy, Enum.Material.Fabric)
	paint(model, SHINS, Color3.fromRGB(235, 235, 240), Enum.Material.Fabric)
	paint(model, FEET, Color3.fromRGB(60, 40, 30))
	local upper = part(model, "UpperTorso")
	if upper then
		local w, h, d = upper.Size.X, upper.Size.Y, upper.Size.Z
		piece(upper, "SailorBack", Vector3.new(w * 0.85, 0.75, 0.05), CFrame.new(0, h / 2 - 0.38, d / 2 + 0.03), navy)
		piece(
			upper,
			"SailorStripe",
			Vector3.new(w * 0.85, 0.05, 0.06),
			CFrame.new(0, h / 2 - 0.68, d / 2 + 0.035),
			WHITE
		)
		for _, side in { -1, 1 } do
			piece(
				upper,
				"SailorFront",
				Vector3.new(0.16, 0.9, 0.04),
				CFrame.new(0.22 * side, 0.4, -d / 2 - 0.02) * deg(0, 0, -30 * side),
				navy
			)
			wedge(
				upper,
				"Ribbon",
				Vector3.new(0.04, 0.25, 0.3),
				CFrame.new(0.13 * side, 0.02, -d / 2 - 0.06) * deg(0, 90 * side, 0),
				Color3.fromRGB(200, 40, 50)
			)
		end
		piece(
			upper,
			"RibbonKnot",
			Vector3.new(0.16, 0.14, 0.06),
			CFrame.new(0, 0.08, -d / 2 - 0.05),
			Color3.fromRGB(200, 40, 50)
		)
	end
	-- saia plissada: aba por coxa abrindo um pouco
	for _, n in THIGHS do
		local thigh = part(model, n)
		if thigh then
			thigh.Color = style.skin
			piece(thigh, "Skirt", Vector3.new(1.15, 0.9, 1.15), CFrame.new(0, 0.3, 0), navy, Enum.Material.Fabric)
			for _, x in { -0.38, -0.13, 0.13, 0.38 } do
				piece(thigh, "Pleat", Vector3.new(0.04, 0.88, 0.03), CFrame.new(x, 0.3, -0.585), navy:Lerp(BLACK, 0.4))
			end
		end
	end
	for _, n in FOREARMS do
		local fore = part(model, n)
		if fore then
			fore.Color = style.skin
		end
	end
end

-- ======================================================================= acessórios
local PROPS = {}

function PROPS.katana(model: Model, style: Style)
	local lower = part(model, "LowerTorso")
	if not lower then
		return
	end
	local c = style.colors or {}
	-- presa no obi do lado esquerdo, quase horizontal: cabo para a frente, bainha para trás e para baixo
	local offset = CFrame.new(-1.08, 0.05, -0.15) * deg(-18, -8, 0)
	piece(
		lower,
		"Saya",
		Vector3.new(0.2, 0.26, 3.4),
		offset * CFrame.new(0, 0, 1.2),
		c.saya or Color3.fromRGB(30, 26, 34)
	)
	piece(
		lower,
		"Tsuba",
		Vector3.new(0.45, 0.45, 0.08),
		offset * CFrame.new(0, 0, -0.52),
		Color3.fromRGB(190, 160, 90),
		Enum.Material.Metal
	)
	piece(
		lower,
		"Tsuka",
		Vector3.new(0.18, 0.2, 1.0),
		offset * CFrame.new(0, 0, -1.08),
		c.tsuka or Color3.fromRGB(240, 235, 220),
		Enum.Material.Fabric
	)
end

function PROPS.bow(model: Model, style: Style)
	local hand = part(model, "LeftHand")
	if not hand then
		return
	end
	local glow = (style.colors and style.colors.trim) or Color3.fromRGB(120, 180, 255)
	-- arco de luz em pé ao lado do corpo: curva lisa (segmentos alinhados à tangente) + corda fina
	local radius, span, count = 1.6, math.rad(110), 10
	local function point(a: number): Vector3
		return Vector3.new(0, math.sin(a) * radius, -(math.cos(a) * radius - radius * math.cos(span / 2)) - 0.25)
	end
	for i = 0, count - 1 do
		local a0 = -span / 2 + span * i / count
		local a1 = -span / 2 + span * (i + 1) / count
		local p0, p1 = point(a0), point(a1)
		local thick = 0.1 + 0.06 * math.cos((a0 + a1) / 2 / (span / 2) * math.pi / 2)
		piece(
			hand,
			"SpiritBow",
			Vector3.new(thick, thick, (p1 - p0).Magnitude + 0.04),
			CFrame.lookAt((p0 + p1) / 2, p1),
			glow,
			Enum.Material.Neon
		)
	end
	local top, bottom = point(span / 2), point(-span / 2)
	piece(
		hand,
		"BowString",
		Vector3.new(0.025, 0.025, (top - bottom).Magnitude),
		CFrame.lookAt((top + bottom) / 2, top),
		Color3.new(1, 1, 1),
		Enum.Material.Neon
	)
end

function PROPS.cane(model: Model, _style: Style)
	local hand = part(model, "RightHand")
	if hand then
		piece(
			hand,
			"Cane",
			Vector3.new(0.14, 3.2, 0.14),
			CFrame.new(0, -1.5, -0.25),
			Color3.fromRGB(110, 75, 45),
			Enum.Material.Wood
		)
		piece(
			hand,
			"CaneHandle",
			Vector3.new(0.18, 0.18, 0.5),
			CFrame.new(0, 0.12, -0.35),
			Color3.fromRGB(80, 55, 35),
			Enum.Material.Wood
		)
	end
end

function PROPS.books(model: Model, _style: Style)
	local hand = part(model, "LeftHand")
	if hand then
		for i, color in { Color3.fromRGB(180, 60, 60), Color3.fromRGB(60, 90, 160), Color3.fromRGB(220, 200, 120) } do
			piece(
				hand,
				"Book",
				Vector3.new(0.85, 0.16, 0.65),
				CFrame.new(0, -0.15 - i * 0.17, -0.1) * deg(0, i * 7, 0),
				color
			)
		end
	end
end

function PROPS.mask(model: Model, style: Style)
	local head = part(model, "Head")
	if not head then
		return
	end
	local z = -head.Size.Z / 2
	local bone = Color3.fromRGB(240, 236, 225)
	if style.mask == "horn" then
		-- fragmento na têmpora com chifre curvo
		piece(
			head,
			"MaskFragment",
			Vector3.new(0.45, 0.55, 0.12),
			CFrame.new(0.38, 0.32, z - 0.03) * deg(0, -20, 0),
			bone
		)
		wedge(head, "MaskHorn", Vector3.new(0.14, 0.5, 0.75), CFrame.new(0.5, 0.75, -0.05) * deg(-60, 0, -20), bone)
	else
		-- mandíbula de osso com dentes
		piece(head, "MaskJaw", Vector3.new(1.0, 0.32, 0.14), CFrame.new(0, -0.48, z - 0.04), bone)
		for i = -3, 3 do
			piece(head, "MaskTooth", Vector3.new(0.07, 0.14, 0.03), CFrame.new(i * 0.12, -0.3, z - 0.1), bone)
		end
	end
end

-- ======================================================================= aplicar
-- Uniforme de facção sobre qualquer R15 (jogadores): só a roupa, sem trocar rosto nem cabelo.
-- Peças marcadas "Uniform"; chamar de novo troca o uniforme.
function NpcStyle.dress(model: Model, outfit: string, colors: { [string]: Color3 }?)
	NpcStyle.undress(model)
	local builder = OUTFIT[outfit]
	if not builder then
		return
	end
	dressing = true
	local ok, err = pcall(
		builder,
		model,
		{
			skin = Color3.new(1, 1, 1),
			outfit = outfit,
			colors = colors,
		} :: Style
	)
	dressing = false
	if not ok then
		warn("[NpcStyle] uniforme", outfit, err)
	end
end

-- Acessório marcado como uniforme (some ao trocar de estágio)
function NpcStyle.dressProp(model: Model, name: string, style: Style)
	local builder = (PROPS :: any)[name]
	if not builder then
		return
	end
	dressing = true
	pcall(builder, model, style)
	dressing = false
end

function NpcStyle.undress(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Uniform") then
			d:Destroy()
		end
	end
end

-- Só rosto e cabelo (jogadores com o visual do jogo, cartões de facção)
function NpcStyle.head(model: Model, style: Style)
	local head = part(model, "Head")
	if not head then
		return
	end
	head.Color = style.skin
	-- tira o rosto/cabelo de blocos do RigBuilder (e o decal de rosto do avatar)
	for _, child in head:GetChildren() do
		if child:IsA("BasePart") or child:IsA("Decal") then
			child:Destroy()
		end
	end
	face(head, style)
	if style.hair then
		local builder = HAIR[style.hair.kind] or HAIR.spiky
		builder(head, style.hair.color)
	end
end

-- Acessório avulso (ex.: "mask" com style.mask = "jaw"/"horn")
function NpcStyle.prop(model: Model, name: string, style: Style)
	local builder = (PROPS :: any)[name]
	if builder then
		builder(model, style)
	end
end

NpcStyle.HairKinds = { "spiky", "long", "ponytail", "bob", "slick", "wild" }

function NpcStyle.apply(model: Model, style: Style)
	local skin = style.skin
	for _, n in { "Head", "LeftHand", "RightHand" } do
		local p = part(model, n)
		if p then
			p.Color = skin
		end
	end
	NpcStyle.head(model, style)
	local outfit = OUTFIT[style.outfit] or OUTFIT.shihakusho
	outfit(model, style)
	if style.mask then
		PROPS.mask(model, style)
	end
	local props: { string } = style.props or {}
	for _, prop in props do
		local builder = (PROPS :: any)[prop]
		if builder then
			builder(model, style)
		end
	end
end

return NpcStyle

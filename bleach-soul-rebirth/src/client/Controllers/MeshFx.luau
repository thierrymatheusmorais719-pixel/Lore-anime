-- Efeitos de malha: monta e anima as camadas das receitas (Shared/Fx/MeshFxRecipes) — estrelas de
-- impacto com fundo preto, meias-luas sólidas no caminho da lâmina, anéis e coroas de espinhos
-- que rompem o chão, espirais de carga e de pilar, estilhaços de cristal.
-- • Malhas geradas por código (Shared/Fx/MeshShapes) viram MeshParts com EditableMesh; cada forma
--   tem um estoque de peças reaproveitadas (nada de criar/destruir a cada golpe).
-- • Sem EditableMesh (API indisponível ou sem memória): as mesmas formas desenhadas com pares de
--   cunhas (triângulos), mais simples mas com o mesmo desenho.
-- • Por cima das partículas do ImpactFx/ElementFx (que continuam): aqui ficam as silhuetas fortes.
-- • Qualidade: Low desliga; Medium limita a 10 efeitos simultâneos; High a 28; Ultra a 64.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MeshShapes = require(ReplicatedStorage.Shared.Fx.MeshShapes)
local Recipes = require(ReplicatedStorage.Shared.Fx.MeshFxRecipes)
local VFX = require(script.Parent.VFXController)

local MeshFx = {}

type Piece = {
	part: BasePart?, -- malha (EditableMesh)
	model: Model?, -- reserva com cunhas
	wedges: { BasePart }?,
	center: Vector3, -- centro da caixa da forma (a peça fica centrada nele)
	extent: Vector3, -- tamanho da forma em escala 1
	pool: { BasePart }?,
	editable: any?,
}

local folder: Folder
local useMesh = true
local templates: { [string]: { editable: any, center: Vector3, extent: Vector3, pool: { BasePart } } } = {}
local triangleCache: { [string]: any } = {}
local active: { { layers: { any }, pieces: { Piece }, start: number, length: number, done: boolean } } = {}

local function limit(): number
	local q = VFX.Quality()
	return if q == "Low" then 0 elseif q == "Medium" then 10 elseif q == "Ultra" then 64 else 28
end

-- ======================================================================= malha (EditableMesh)
local function bounds(shape: any): (Vector3, Vector3)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for _, p in shape.v do
		minV = minV:Min(p)
		maxV = maxV:Max(p)
	end
	local extent = maxV - minV
	-- formas planas: espessura mínima para a caixa não ter lado zero
	extent = Vector3.new(math.max(extent.X, 0.02), math.max(extent.Y, 0.02), math.max(extent.Z, 0.02))
	return (minV + maxV) / 2, extent
end

-- Casca dupla (voltas opostas) com normais suaves iguais nas duas: aparece dos dois lados
local function buildEditable(shape: any, center: Vector3): any
	local mesh = AssetService:CreateEditableMesh() :: any
	local outer, inner = {}, {}
	local sums = {}
	for i, p in shape.v do
		outer[i] = mesh:AddVertex(p - center)
		inner[i] = mesh:AddVertex(p - center)
		sums[i] = Vector3.zero
	end
	for _, tri in shape.t do
		local a, b, c = tri[1], tri[2], tri[3]
		local n = (shape.v[b] - shape.v[a]):Cross(shape.v[c] - shape.v[a])
		sums[a] += n
		sums[b] += n
		sums[c] += n
	end
	local faces = {}
	for _, tri in shape.t do
		local a, b, c = tri[1], tri[2], tri[3]
		table.insert(faces, { mesh:AddTriangle(outer[a], outer[b], outer[c]), a, b, c })
		table.insert(faces, { mesh:AddTriangle(inner[a], inner[c], inner[b]), a, c, b })
	end
	pcall(function()
		local normals = {}
		for i, n in sums do
			normals[i] = mesh:AddNormal(if n.Magnitude > 1e-9 then n.Unit else Vector3.yAxis)
		end
		for _, f in faces do
			mesh:SetFaceNormals(f[1], { normals[f[2]], normals[f[3]], normals[f[4]] })
		end
	end)
	return mesh
end

local function styleMeshPart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
end

local function newMeshPart(editable: any): BasePart
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(editable)) :: BasePart
	styleMeshPart(part)
	return part
end

local function template(name: string)
	local t = templates[name]
	if t then
		return t
	end
	local shape = MeshShapes.Library[name]()
	local center, extent = bounds(shape)
	t = { editable = buildEditable(shape, center), center = center, extent = extent, pool = {} }
	templates[name] = t
	return t
end

-- ======================================================================= reserva: cunhas
-- Um triângulo = duas WedgeParts (técnica clássica). Feito no espaço da forma, dentro de um Model
-- com pivô na origem da forma: o efeito move com PivotTo e cresce com ScaleTo.
local function wedge(parent: Instance): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.CastShadow = false
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

local function triangle(model: Model, list: { BasePart }, a: Vector3, b: Vector3, c: Vector3)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local cross = ac:Cross(ab)
	if cross.Magnitude < 1e-6 or bc.Magnitude < 1e-6 then
		return
	end
	local right = cross.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local w1 = wedge(model)
	w1.Size = Vector3.new(0.02, math.max(height, 0.01), math.max(math.abs(ab:Dot(back)), 0.01))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
	local w2 = wedge(model)
	w2.Size = Vector3.new(0.02, math.max(height, 0.01), math.max(math.abs(ac:Dot(back)), 0.01))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
	table.insert(list, w1)
	table.insert(list, w2)
end

local function wedgeModel(shape: any): (Model, { BasePart })
	local model = Instance.new("Model")
	local list = {}
	for _, tri in shape.t do
		triangle(model, list, shape.v[tri[1]], shape.v[tri[2]], shape.v[tri[3]])
	end
	model.WorldPivot = CFrame.identity
	return model, list
end

-- ======================================================================= peças
local function acquire(layer: any): Piece?
	local shape = layer.shape
	if useMesh then
		local ok, result = pcall(function()
			if type(shape) == "string" then
				local t = template(shape)
				local part = table.remove(t.pool) or newMeshPart(t.editable)
				return { part = part, center = t.center, extent = t.extent, pool = t.pool }
			end
			local center, extent = bounds(shape)
			local editable = buildEditable(shape, center)
			return { part = newMeshPart(editable), center = center, extent = extent, editable = editable }
		end)
		if ok then
			return result
		end
		useMesh = false
		warn("[MeshFx] malhas de efeito desativadas (usando cunhas):", result)
	end
	local geometry = if type(shape) == "string" then triangleCache[shape] else shape
	if not geometry then
		geometry = MeshShapes.Library[shape]()
		triangleCache[shape] = geometry
	end
	-- a reserva fica leve: formas com muitos triângulos não entram
	if #geometry.t > 60 then
		return nil
	end
	local model, list = wedgeModel(geometry)
	return { model = model, wedges = list, center = Vector3.zero, extent = Vector3.one }
end

local function release(piece: Piece)
	if piece.part then
		if piece.pool and #piece.pool < 12 then
			piece.part.Parent = nil
			table.insert(piece.pool, piece.part)
		else
			piece.part:Destroy()
			if piece.editable then
				pcall(function()
					piece.editable:Destroy()
				end)
			end
		end
	elseif piece.model then
		piece.model:Destroy()
	end
end

local function setup(piece: Piece, layer: any)
	local material = if layer.neon == false then Enum.Material.SmoothPlastic else Enum.Material.Neon
	if piece.part then
		piece.part.Color = layer.color
		piece.part.Material = material
		piece.part.Transparency = 1
		piece.part.Parent = folder
	elseif piece.model then
		for _, w in piece.wedges :: { BasePart } do
			w.Color = layer.color
			w.Material = material
			w.Transparency = 1
		end
		piece.model.Parent = folder
	end
end

local function place(piece: Piece, frame: CFrame, scale: Vector3, alpha: number)
	if piece.part then
		local part = piece.part
		part.Size = piece.extent * scale
		part.CFrame = frame * CFrame.new(piece.center * scale)
		part.Transparency = alpha
	elseif piece.model then
		local model = piece.model
		local s = math.max(0.01, (scale.X + scale.Y + scale.Z) / 3)
		if math.abs(model:GetScale() - s) > s * 0.02 then
			model:ScaleTo(s)
		end
		model:PivotTo(frame)
		for _, w in piece.wedges :: { BasePart } do
			w.Transparency = alpha
		end
	end
end

-- ======================================================================= tocar
-- Toca as camadas (já calculadas por uma receita). Assíncrono: as peças são montadas numa thread.
function MeshFx.Play(layers: { any })
	if #layers == 0 or #active >= limit() then
		return
	end
	local effect = { layers = layers, pieces = {}, start = os.clock(), length = Recipes.Length(layers), done = false }
	table.insert(active, effect)
	task.spawn(function()
		for i, layer in layers do
			local piece = acquire(layer)
			if piece and effect.done then
				-- o efeito acabou enquanto a peça era montada
				release(piece)
			elseif piece then
				setup(piece, layer)
				effect.pieces[i] = piece :: any
			end
		end
	end)
end

-- Paleta por elemento (a mesma das partículas do ImpactFx) ou derivada de uma cor
function MeshFx.Palette(element: string?)
	local ImpactFx = require(script.Parent.ImpactFx) :: any
	return ImpactFx.Palette(element)
end

function MeshFx.PaletteOf(color: Color3)
	return {
		core = color:Lerp(Color3.new(1, 1, 1), 0.75),
		primary = color,
		secondary = color:Lerp(Color3.new(1, 1, 1), 0.35),
		dark = color:Lerp(Color3.new(0, 0, 0), 0.8),
	}
end

function MeshFx.Impact(position: Vector3, direction: Vector3?, element: string?, tier: number?)
	if limit() == 0 then
		return
	end
	MeshFx.Play(Recipes.Impact(position, direction, MeshFx.Palette(element), tier or 1))
end

function MeshFx.Slash(points: { Vector3 }, pivot: Vector3, color: Color3, width: number?, duration: number?)
	if limit() == 0 or #points < 3 then
		return
	end
	MeshFx.Play(Recipes.Slash(points, pivot, MeshFx.PaletteOf(color), width or 1.1, duration or 0.28, MeshShapes.strip))
end

-- Forma própria do elemento (golpes pesados e liberações) e rachaduras no chão (finalizadores)
function MeshFx.Element(position: Vector3, direction: Vector3?, element: string?, scale: number?)
	if limit() == 0 then
		return
	end
	local id = element or "Reiatsu"
	MeshFx.Play(Recipes.Element(position, direction, id, MeshFx.Palette(id), scale or 1, MeshShapes.strip))
end

-- `exact`: `position` já é o chão (pula o raio para baixo)
function MeshFx.Cracks(position: Vector3, element: string?, radius: number, exact: boolean?)
	if limit() == 0 then
		return
	end
	if exact then
		MeshFx.Play(Recipes.Cracks(position, MeshFx.Palette(element), radius, MeshShapes.strip))
		return
	end
	-- assenta no chão de verdade (ignora personagens e efeitos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { folder }
	for _, name in { "Enemies", "Bosses", "NPCs" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), params)
	if not hit then
		return
	end
	MeshFx.Play(Recipes.Cracks(hit.Position, MeshFx.Palette(element), radius, MeshShapes.strip))
end

function MeshFx.Shockwave(position: Vector3, color: Color3, radius: number, duration: number?)
	if limit() == 0 then
		return
	end
	MeshFx.Play(Recipes.Shockwave(position, MeshFx.PaletteOf(color), radius, duration or 0.5))
end

function MeshFx.Burst(position: Vector3, element: string?, scale: number?)
	if limit() == 0 then
		return
	end
	MeshFx.Play(Recipes.Burst(position, MeshFx.Palette(element), scale or 1))
end

function MeshFx.Charge(frame: CFrame, element: string?, duration: number, big: boolean?)
	if limit() == 0 then
		return
	end
	MeshFx.Play(Recipes.Charge(frame, MeshFx.Palette(element), duration, big == true))
end

function MeshFx.Pillar(position: Vector3, color: Color3, radius: number, height: number, duration: number)
	if limit() == 0 then
		return
	end
	MeshFx.Play(Recipes.Pillar(position, MeshFx.PaletteOf(color), radius, height, duration))
end

function MeshFx.Init()
	folder = Instance.new("Folder")
	folder.Name = "MeshFx"
	folder.Parent = workspace
end

function MeshFx.Start()
	-- monta as formas fixas e um estoque pequeno de cada em segundo plano
	task.spawn(function()
		for name in MeshShapes.Library do
			if not useMesh then
				break
			end
			local ok, err = pcall(function()
				local t = template(name)
				for _ = 1, 3 do
					table.insert(t.pool, newMeshPart(t.editable))
				end
			end)
			if not ok then
				useMesh = false
				warn("[MeshFx] malhas de efeito desativadas (usando cunhas):", err)
			end
			task.wait()
		end
	end)
	RunService.RenderStepped:Connect(function()
		if #active == 0 then
			return
		end
		local camera = workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		for i = #active, 1, -1 do
			local effect = active[i]
			local t = now - effect.start
			if t > effect.length + 0.05 then
				effect.done = true
				for _, piece in effect.pieces do
					release(piece)
				end
				table.remove(active, i)
				continue
			end
			for j, layer in effect.layers do
				local piece = effect.pieces[j]
				if piece then
					local frame, scale, alpha = Recipes.Evaluate(layer, t, cameraPosition)
					if frame and scale and alpha then
						place(piece, frame, scale, math.clamp(alpha, 0, 1))
					elseif piece.part then
						piece.part.Transparency = 1
					elseif piece.wedges then
						for _, w in piece.wedges do
							w.Transparency = 1
						end
					end
				end
			end
		end
	end)
end

return MeshFx

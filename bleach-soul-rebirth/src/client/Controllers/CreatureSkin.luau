-- Pele esculpida das criaturas: troca as partes do corpo (blocos animados pelo esqueleto) por
-- malhas lisas geradas em tools/creatures/sculpt.py (Config/CreatureMeshes), montadas no cliente
-- com EditableMesh → MeshPart. Músculos, tronco com peitoral/barriga, membros que afinam,
-- articulações contínuas (as pontas de cada segmento se sobrepõem às do vizinho).
-- • Visual apenas: hitbox, colisão e animação continuam nas partes originais (ficam invisíveis).
-- • Cada malha leva casca externa e interna com voltas opostas: aparece certo qualquer que seja a
--   convenção de frente/verso, e cada casca tem as próprias normais.
-- • Entradas com `part` são peças extras soldadas àquela parte (máscara de caveira, chifres, dedos,
--   garras, marcas assentadas na pele): herdam cor/material das peças marcadas com o atributo
--   Sculpt = chave, que ficam invisíveis (continuam como reserva se a malha falhar).
-- • Normais suaves calculadas aqui (média das faces em cada vértice), iguais nas duas cascas:
--   a luz fica certa qualquer que seja a casca visível.
-- • Uma EditableMesh por (corpo, parte, escala), reaproveitada por todos os inimigos iguais.
-- • Sem EditableMesh (API indisponível, orçamento de memória cheio): mantém os blocos.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureMeshes = require(ReplicatedStorage.Shared.Config.CreatureMeshes) :: any

local CreatureSkin = {}

local editableCache: { [string]: any } = {}
local disabled = false
local skinned: { [Model]: boolean } = {}

local function editableFor(bodyName: string, partName: string, scale: number): (any, Vector3)
	local key = bodyName .. "/" .. partName .. "/" .. string.format("%.3f", scale)
	local cached = editableCache[key]
	if cached then
		return cached.mesh, cached.center
	end
	local data = CreatureMeshes[bodyName] and CreatureMeshes[bodyName][partName]
	if not data then
		return nil, Vector3.zero
	end
	local v, t = data.v, data.t
	local count = #v // 3
	-- centro da caixa da malha: os vértices entram centrados na origem e a solda desloca a pele
	-- até o lugar certo na parte (independe de como o MeshPart posiciona a malha)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for i = 0, count - 1 do
		local p = Vector3.new(v[i * 3 + 1], v[i * 3 + 2], v[i * 3 + 3]) * scale
		minV = minV:Min(p)
		maxV = maxV:Max(p)
	end
	local center = (minV + maxV) / 2
	local mesh = AssetService:CreateEditableMesh() :: any
	local outer, inner = table.create(count), table.create(count)
	local points = table.create(count)
	for i = 0, count - 1 do
		local p = Vector3.new(v[i * 3 + 1], v[i * 3 + 2], v[i * 3 + 3]) * scale - center
		points[i + 1] = p
		outer[i + 1] = mesh:AddVertex(p)
		inner[i + 1] = mesh:AddVertex(p)
	end
	-- normais por vértice: soma das normais das faces (ponderada pela área) na orientação de fora
	local sums = table.create(count, Vector3.zero)
	for i = 1, #t, 3 do
		local a, b, c = t[i], t[i + 1], t[i + 2]
		local n = (points[b] - points[a]):Cross(points[c] - points[a])
		sums[a] += n
		sums[b] += n
		sums[c] += n
	end
	local faces = table.create(#t // 3 * 2)
	for i = 1, #t, 3 do
		local a, b, c = t[i], t[i + 1], t[i + 2]
		table.insert(faces, mesh:AddTriangle(outer[a], outer[b], outer[c]))
		table.insert(faces, mesh:AddTriangle(inner[a], inner[c], inner[b]))
	end
	-- sem a API de normais a malha continua válida (normais automáticas)
	pcall(function()
		local normals = table.create(count)
		for i = 1, count do
			local n = sums[i]
			normals[i] = mesh:AddNormal(if n.Magnitude > 1e-9 then n.Unit else Vector3.yAxis)
		end
		local f = 0
		for i = 1, #t, 3 do
			local a, b, c = t[i], t[i + 1], t[i + 2]
			f += 1
			mesh:SetFaceNormals(faces[f], { normals[a], normals[b], normals[c] })
			f += 1
			mesh:SetFaceNormals(faces[f], { normals[a], normals[c], normals[b] })
		end
	end)
	editableCache[key] = { mesh = mesh, center = center }
	return mesh, center
end

-- Monta a pele de um modelo de criatura (atributo Creature = nome do corpo). Assíncrono.
function CreatureSkin.Apply(model: Model)
	if disabled or skinned[model] then
		return
	end
	local bodyName = model:GetAttribute("Creature")
	if type(bodyName) ~= "string" or not CreatureMeshes[bodyName] then
		return
	end
	skinned[model] = true
	local scale = (model:GetAttribute("AnimScale") :: number?) or 1
	task.spawn(function()
		for key, data in CreatureMeshes[bodyName] do
			local base = model:FindFirstChild(data.part or key) :: BasePart?
			if not base or not model.Parent then
				continue
			end
			-- peça extra: só existe se o corpo montado tiver as peças que ela substitui
			local replaced: { BasePart } = {}
			if data.part then
				for _, piece in base:GetChildren() do
					if piece:IsA("BasePart") and piece:GetAttribute("Sculpt") == key then
						table.insert(replaced, piece)
					end
				end
				if #replaced == 0 then
					continue
				end
			end
			local ok, err = pcall(function()
				local mesh, center = editableFor(bodyName, key, scale)
				if not mesh then
					return
				end
				local skin = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
				-- cor da peça principal (a máscara, não um dente ou um detalhe escuro)
				local look: BasePart = base
				for _, piece in replaced do
					if look == base or piece.Name == "Mask" and look.Name ~= "Mask" then
						look = piece
					end
				end
				-- extras levam o nome do papel (Mask, Bone...): a morte estilhaça a máscara de verdade
				skin.Name = if data.part then look.Name else "Skin"
				skin.Color = look.Color
				skin.Material = look.Material
				skin.CanCollide = false
				skin.CanQuery = false
				skin.CanTouch = false
				skin.Massless = true
				skin.CastShadow = true
				skin.CFrame = base.CFrame * CFrame.new(center)
				local weld = Instance.new("Weld")
				weld.Part0 = base
				weld.Part1 = skin
				weld.C0 = CFrame.new(center)
				weld.Parent = skin
				skin.Parent = base
				if data.part then
					for _, piece in replaced do
						piece.Transparency = 1
						piece.Name = "Sculpted"
					end
					return
				end
				base.Transparency = 1
				-- a malha substitui a forma da peça (esfera, bloco) de vez
				local special = base:FindFirstChildOfClass("SpecialMesh")
				if special then
					special:Destroy()
				end
			end)
			if not ok then
				-- API indisponível ou sem memória: fica com os blocos e não tenta mais
				disabled = true
				warn("[CreatureSkin] malhas esculpidas desativadas:", err)
				return
			end
		end
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			skinned[model] = nil
		end
	end)
end

function CreatureSkin.Init() end

function CreatureSkin.Start()
	local function watch(folder: Instance)
		local function try(child: Instance)
			if child:IsA("Model") then
				-- espera o servidor terminar de montar o corpo (atributos e partes replicados)
				task.defer(function()
					if child:GetAttribute("Creature") == nil then
						child:GetAttributeChangedSignal("Creature"):Wait()
					end
					child:WaitForChild("UpperTorso", 5)
					CreatureSkin.Apply(child)
				end)
			end
		end
		for _, child in folder:GetChildren() do
			try(child)
		end
		folder.ChildAdded:Connect(try)
	end
	for _, name in { "Enemies", "Bosses" } do
		task.spawn(function()
			watch(workspace:WaitForChild(name))
		end)
	end
end

return CreatureSkin

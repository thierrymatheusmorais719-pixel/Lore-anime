-- Pele esculpida das criaturas: troca as partes do corpo (blocos animados pelo esqueleto) por
-- malhas lisas geradas em tools/creatures/sculpt.py (Config/CreatureMeshes), montadas no cliente
-- com EditableMesh → MeshPart. Músculos, tronco com peitoral/barriga, membros que afinam,
-- articulações contínuas (as pontas de cada segmento se sobrepõem às do vizinho).
-- • Visual apenas: hitbox, colisão e animação continuam nas partes originais (ficam invisíveis).
-- • Cada malha leva casca externa e interna com voltas opostas: aparece certo qualquer que seja a
--   convenção de frente/verso, e cada casca tem as próprias normais.
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
	for i = 0, count - 1 do
		local p = Vector3.new(v[i * 3 + 1], v[i * 3 + 2], v[i * 3 + 3]) * scale - center
		outer[i + 1] = mesh:AddVertex(p)
		inner[i + 1] = mesh:AddVertex(p)
	end
	for i = 1, #t, 3 do
		local a, b, c = t[i], t[i + 1], t[i + 2]
		mesh:AddTriangle(outer[a], outer[b], outer[c])
		mesh:AddTriangle(inner[a], inner[c], inner[b])
	end
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
		for partName in CreatureMeshes[bodyName] do
			local base = model:FindFirstChild(partName) :: BasePart?
			if not base or not model.Parent then
				continue
			end
			local ok, err = pcall(function()
				local mesh, center = editableFor(bodyName, partName, scale)
				if not mesh then
					return
				end
				local skin = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
				skin.Name = "Skin"
				skin.Color = base.Color
				skin.Material = base.Material
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

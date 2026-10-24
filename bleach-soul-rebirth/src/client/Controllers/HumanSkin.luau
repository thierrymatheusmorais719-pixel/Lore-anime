-- Corpo humano liso nos NPCs: troca as partes em bloco do R15 por malhas esculpidas
-- (Shared/Builders/HumanShapes) e as peças de roupa/cabelo em bloco por volumes macios, tudo com
-- EditableMesh montado no cliente. As partes originais ficam invisíveis (animação e cliques
-- continuam nelas); sem EditableMesh, fica o visual de blocos.
-- • Malha centrada na caixa e soldada à parte; casca dupla com normais suaves (como CreatureSkin)
-- • Uma EditableMesh por (forma, tamanho), reaproveitada entre NPCs
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HumanShapes = require(ReplicatedStorage.Shared.Builders.HumanShapes)

local HumanSkin = {}

local cache: { [string]: { mesh: any, center: Vector3 } } = {}
local disabled = false

-- Orienta cada triângulo para fora do eixo vertical da forma (formas de loft) e devolve a malha
local function buildEditable(shape: any): (any, Vector3)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	local sum = Vector3.zero
	for _, p in shape.v do
		minV = minV:Min(p)
		maxV = maxV:Max(p)
		sum += p
	end
	local center = (minV + maxV) / 2
	local centroid = sum / #shape.v
	local tris = {}
	for _, tri in shape.t do
		local a, b, c = shape.v[tri[1]], shape.v[tri[2]], shape.v[tri[3]]
		local n = (b - a):Cross(c - a)
		local mid = (a + b + c) / 3
		local ref = mid - Vector3.new(centroid.X, mid.Y, centroid.Z)
		if ref.Magnitude < 1e-4 then
			ref = mid - centroid
		end
		if n:Dot(ref) >= 0 then
			table.insert(tris, { tri[1], tri[2], tri[3] })
		else
			table.insert(tris, { tri[1], tri[3], tri[2] })
		end
	end
	local mesh = AssetService:CreateEditableMesh() :: any
	local outer, inner, sums = {}, {}, {}
	for i, p in shape.v do
		outer[i] = mesh:AddVertex(p - center)
		inner[i] = mesh:AddVertex(p - center)
		sums[i] = Vector3.zero
	end
	for _, tri in tris do
		local a, b, c = tri[1], tri[2], tri[3]
		local n = (shape.v[b] - shape.v[a]):Cross(shape.v[c] - shape.v[a])
		sums[a] += n
		sums[b] += n
		sums[c] += n
	end
	local faces = {}
	for _, tri in tris do
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
	return mesh, center
end

local function editableFor(key: string, make: () -> any): (any, Vector3)
	local entry = cache[key]
	if entry then
		return entry.mesh, entry.center
	end
	local mesh, center = buildEditable(make())
	cache[key] = { mesh = mesh, center = center }
	return mesh, center
end

local function sizeKey(size: Vector3): string
	return string.format("%.2f,%.2f,%.2f", size.X, size.Y, size.Z)
end

-- Cria a malha lisa sobre `base` e esconde a peça original
local function skin(base: BasePart, key: string, make: () -> any)
	local mesh, center = editableFor(key, make)
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
	part.Name = base.Name .. "Skin"
	part.Color = base.Color
	part.Material = base.Material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
	part.CFrame = base.CFrame * CFrame.new(center)
	local weld = Instance.new("Weld")
	weld.Part0 = base
	weld.Part1 = part
	weld.C0 = CFrame.new(center)
	weld.Parent = part
	part.Parent = base
	base.Transparency = 1
end

-- `outfitOnly` (jogadores): o corpo e a cabeça do avatar ficam como estão; só as peças do uniforme
-- viram volumes lisos. Pode ser chamado de novo a cada troca de uniforme (peças já lisas são puladas).
function HumanSkin.Apply(model: Model, outfitOnly: boolean?)
	if disabled or (not outfitOnly and model:GetAttribute("HumanSkin")) then
		return
	end
	if not outfitOnly then
		model:SetAttribute("HumanSkin", true)
	end
	task.spawn(function()
		local ok, err = pcall(function()
			-- peças presas aos braços/mãos acompanham o braço desenhado mais perto do tronco
			-- (uniforme refeito num corpo já liso: só as peças novas do uniforme)
			local bodySmooth = outfitOnly and model:GetAttribute("HumanSkin")
			for _, d in (if outfitOnly and not bodySmooth then {} else model:GetDescendants()) :: { Instance } do
				if
					outfitOnly
					and not (
						d.Parent
						and d.Parent:GetAttribute("Uniform")
						and not d.Parent:FindFirstChild(d.Parent.Name .. "Skin")
					)
				then
					continue
				end
				if d:IsA("Weld") and d.Part0 and d.Part0.Parent == model then
					local inset = HumanShapes.armInset(d.Part0.Name)
					if inset.Magnitude > 0 and d.Part1 and d.Part1.Parent == d.Part0 then
						d.C0 = CFrame.new(inset) * d.C0
					end
				end
			end
			for _, d in model:GetDescendants() do
				if not d:IsA("BasePart") or d.Name == "HumanoidRootPart" or d.Transparency >= 1 then
					continue
				end
				local part = d :: BasePart
				local isBody = part.Parent == model
				if part:FindFirstChild(part.Name .. "Skin") then
					continue
				elseif isBody and outfitOnly then
					continue
				elseif outfitOnly and not part:GetAttribute("Uniform") then
					continue -- acessórios do avatar (cabelo, chapéus) ficam como são
				elseif isBody then
					local shape = HumanShapes.forPart(part.Name, part.Size)
					if shape then
						skin(part, "body/" .. part.Name .. "/" .. sizeKey(part.Size), function()
							return HumanShapes.forPart(part.Name, part.Size)
						end)
					end
				elseif HumanShapes.accessory(part.Name, part.Size) then
					skin(part, "acc/" .. part.Name .. "/" .. sizeKey(part.Size), function()
						return HumanShapes.accessory(part.Name, part.Size)
					end)
				elseif part.ClassName == "Part" and HumanShapes.Soft[part.Name] then
					local roundness = HumanShapes.Soft[part.Name]
					skin(part, "soft/" .. part.Name .. "/" .. roundness .. "/" .. sizeKey(part.Size), function()
						return HumanShapes.softBox(part.Size, roundness, part.Name)
					end)
				end
			end
		end)
		if not ok then
			disabled = true
			warn("[HumanSkin] corpos lisos desativados:", err)
		end
	end)
end

function HumanSkin.Init() end

function HumanSkin.Start()
	task.spawn(function()
		local folder = workspace:WaitForChild("NPCs")
		local function try(child: Instance)
			if child:IsA("Model") then
				task.defer(function()
					child:WaitForChild("UpperTorso", 5)
					task.wait(0.5) -- roupa e cabelo chegam junto com o modelo
					HumanSkin.Apply(child)
				end)
			end
		end
		for _, child in folder:GetChildren() do
			try(child)
		end
		folder.ChildAdded:Connect(try)
	end)
	-- jogadores: uniforme liso (refeito quando o servidor troca o uniforme)
	local function watchCharacter(character: Model)
		local function refresh()
			task.delay(0.4, function()
				if not character.Parent then
					return
				end
				if character:GetAttribute("GameLook") and not character:GetAttribute("HumanSkin") then
					HumanSkin.Apply(character) -- visual do jogo: corpo, cabeça, rosto, cabelo e uniforme lisos
				else
					HumanSkin.Apply(character, true)
				end
			end)
		end
		character:GetAttributeChangedSignal("UniformVersion"):Connect(refresh)
		if character:GetAttribute("UniformVersion") then
			refresh()
		end
	end
	local function onPlayer(p: Player)
		p.CharacterAdded:Connect(watchCharacter)
		if p.Character then
			watchCharacter(p.Character)
		end
	end
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return HumanSkin

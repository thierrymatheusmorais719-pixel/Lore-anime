-- MODELOS FEITOS NO BLENDER (tools/blender/build_pets.py) e importados no Studio pelo Importador 3D.
--
-- Quando existe ReplicatedStorage.PetRigs.<id da espécie> (o Model que o Importador 3D cria a partir do FBX:
-- MeshParts com textura + ossos (Bone) com os MESMOS nomes das partes do corpo do jogo), o pet usa esse modelo
-- liso e contínuo como "pele" do esqueleto invisível que o jogo já anima (Motor6D). A cada quadro, cada Bone
-- importado copia a pose da parte de mesmo nome:
--   mundo desejado do osso  D = parte.CFrame * offset   (offset medido em repouso, na montagem)
--   Bone.Transform          = (mundo do pai * Bone.CFrame)^-1 * D
-- Não precisa de EditableMesh: a malha é um asset comum, enviado pelo próprio Importador 3D do Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetRig = {}

function PetRig.find(speciesId: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("PetRigs")
	local m = folder and folder:FindFirstChild(speciesId)
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

local function corners(p: BasePart)
	local h = p.Size / 2
	local out = {}
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				table.insert(out, p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
			end
		end
	end
	return out
end

local function bounds(points)
	local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for _, q in ipairs(points) do
		x0, y0, z0 = math.min(x0, q.X), math.min(y0, q.Y), math.min(z0, q.Z)
		x1, y1, z1 = math.max(x1, q.X), math.max(y1, q.Y), math.max(z1, q.Z)
	end
	return Vector3.new(x0, y0, z0), Vector3.new(x1, y1, z1)
end

-- Caixa do pet pela planta (em repouso, coordenadas do modelo: raiz na origem).
function PetRig.expectedBounds(bp)
	local pts = {}
	for _, p in ipairs(bp.parts) do
		if p.name:sub(1, 3) ~= "Lid" then
			for _, v in ipairs(p.geom.verts) do
				table.insert(pts, v + p.pivot)
			end
		end
	end
	return bounds(pts)
end

local function skinParts(skin: Model)
	local list = {}
	for _, d in ipairs(skin:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- mundo do osso em repouso (sem depender de Bone.WorldCFrame): pai * CFrame
local function restWorld(b: Instance): CFrame
	local parent = b.Parent
	if parent and parent:IsA("BasePart") then
		return parent.CFrame * (b :: any).CFrame
	elseif parent and parent.ClassName == "Bone" then
		return restWorld(parent) * (b :: any).CFrame
	end
	return (b :: any).CFrame
end
PetRig._restWorld = restWorld

--[[ Prende a pele importada ao esqueleto do molde (`model`, montado pelo PetMesh com os ossos invisíveis).
	Ajusta escala e posição pela caixa da planta, solda as MeshParts na raiz e grava em cada Bone qual parte ele
	segue (atributo BindPart) e o offset de repouso (BindOffset). Devolve (ossos ligados, ossos sem parte). ]]
function PetRig.attach(model: Model, skin: Model, bp)
	local root = model.PrimaryPart :: BasePart
	local parts = skinParts(skin)
	local lo, hi = PetRig.expectedBounds(bp)
	local pts = {}
	for _, p in ipairs(parts) do
		for _, q in ipairs(corners(p)) do
			table.insert(pts, q)
		end
	end
	local slo, shi = bounds(pts)
	-- escala: o FBX pode chegar em outra unidade (metro, centímetro); acerta pela altura
	local want, got = hi.Y - lo.Y, shi.Y - slo.Y
	if got > 1e-3 and math.abs(want / got - 1) > 0.03 then
		local okScale = pcall(function()
			skin:ScaleTo(skin:GetScale() * want / got)
		end)
		if okScale then
			pts = {}
			for _, p in ipairs(parts) do
				for _, q in ipairs(corners(p)) do
					table.insert(pts, q)
				end
			end
			slo, shi = bounds(pts)
		else
			warn("[PetRig] não deu para ajustar a escala do modelo importado de " .. skin.Name .. " (importe em studs)")
		end
	end
	-- posição: centro da caixa importada no centro da caixa da planta (relativo à raiz)
	local delta = root.CFrame * ((lo + hi) / 2) - (slo + shi) / 2
	for _, p in ipairs(parts) do
		p.CFrame = p.CFrame + delta
		p.Anchored = false
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
	end
	local linked, missing = 0, {}
	for _, d in ipairs(skin:GetDescendants()) do
		if d.ClassName == "Bone" then
			local part = model:FindFirstChild(d.Name)
			if part and part:IsA("BasePart") then
				d:SetAttribute("BindPart", d.Name)
				d:SetAttribute("BindOffset", part.CFrame:Inverse() * restWorld(d))
				linked += 1
			else
				table.insert(missing, d.Name)
			end
		end
	end
	skin.Name = "Skin"
	skin.Parent = model
	model:SetAttribute("RigPet", true)
	return linked, missing
end

-- Lista dos ossos de um visual (clone do molde), pai antes de filho, para PetRig.step.
function PetRig.collect(mesh: Model)
	local skin = mesh:FindFirstChild("Skin")
	if not skin then
		return nil
	end
	local list = {}
	for _, d in ipairs(skin:GetDescendants()) do
		if d.ClassName == "Bone" and d:GetAttribute("BindPart") then
			local part = mesh:FindFirstChild(d:GetAttribute("BindPart"))
			if part then
				local depth, p = 0, d.Parent
				while p and p.ClassName == "Bone" do
					depth += 1
					p = p.Parent
				end
				table.insert(list, { bone = d, part = part, offset = d:GetAttribute("BindOffset"), depth = depth })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.depth < b.depth
	end)
	return { bones = list, desired = {} }
end

-- Um quadro: cada osso importado vai para a pose da parte que ele segue.
function PetRig.step(rig)
	local desired = rig.desired
	for _, e in ipairs(rig.bones) do
		local b = e.bone
		local d = e.part.CFrame * e.offset
		local parent = b.Parent
		local pw
		if parent and parent.ClassName == "Bone" then
			pw = desired[parent] or restWorld(parent)
		elseif parent and parent:IsA("BasePart") then
			pw = parent.CFrame
		else
			pw = CFrame.identity
		end
		b.Transform = (pw * b.CFrame):Inverse() * d
		desired[b] = d
	end
end

return PetRig

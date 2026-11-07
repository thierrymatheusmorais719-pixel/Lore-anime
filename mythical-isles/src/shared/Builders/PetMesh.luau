-- Transforma a planta anatômica de um pet (PetAnatomy) num modelo de MeshParts com esqueleto (Motor6D).
--
-- As malhas são geradas em tempo de execução com AssetService:CreateEditableMesh + CreateMeshPartAsync:
-- nenhuma malha é enviada/inventada como asset. Cada parte do corpo vira uma MeshPart com pivô na
-- articulação; o Animator do cliente anima as juntas pelo nome.
--
-- Usado no CLIENTE (o conteúdo de um EditableMesh não é replicado). Um molde por espécie fica em cache e
-- cada pet na tela é um clone. Se a API não estiver disponível (ex.: "Allow Mesh / Image APIs" desligado
-- nas configurações do jogo), `PetMesh.available` vira false e o jogo continua com o modelo antigo.

local AssetService = game:GetService("AssetService")

local MeshKit = require(script.Parent.MeshKit)
local PetAnatomy = require(script.Parent.PetAnatomy)
local CreatureBuilder = require(script.Parent.CreatureBuilder)
local MutationVisuals = require(script.Parent.MutationVisuals)
local Accessories = require(script.Parent.Accessories)
local Pets = require(script.Parent.Parent.Config.Pets)

local PetMesh = {}

PetMesh.available = nil -- nil = ainda não testado
PetMesh.lastError = nil

local templates = {} -- [chave] = { model = Model, bp = planta } | false (falhou)
local pending = {} -- [chave] = true enquanto constrói
local keep = {} -- referências aos EditableMesh (mantêm as malhas vivas)

local MATERIALS = {
	Fabric = Enum.Material.Fabric, SmoothPlastic = Enum.Material.SmoothPlastic, Glass = Enum.Material.Glass, Neon = Enum.Material.Neon,
	Metal = Enum.Material.Metal, Grass = Enum.Material.Grass, Wood = Enum.Material.Wood, Slate = Enum.Material.Slate, ForceField = Enum.Material.ForceField,
}

local function key(speciesId: string, scale: number): string
	return speciesId .. "@" .. string.format("%.2f", scale)
end

-- Uma MeshPart a partir da geometria (centrada na própria caixa, como o Roblox faz com malhas).
local function meshPart(geom)
	local g, center = MeshKit.centered(geom)
	local em = AssetService:CreateEditableMesh()
	MeshKit.toEditable(g, em)
	local content = Content.fromObject(em)
	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(content, { CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	if not ok or not mp then
		mp = AssetService:CreateMeshPartAsync(content)
	end
	table.insert(keep, em)
	return mp, center
end

local function effects(model: Model, bp)
	for _, fx in ipairs(bp.effects or {}) do
		local host = model:FindFirstChild(fx.part) :: BasePart?
		if host then
			if fx.kind == "sparkles" or fx.kind == "aura" then
				local e = Instance.new("ParticleEmitter")
				e.Name = fx.kind == "aura" and "RarityAura" or "RaritySparkles"
				e.Texture = fx.kind == "aura" and "rbxasset://textures/particles/smoke_main.dds" or "rbxasset://textures/particles/sparkles_main.dds"
				e.Color = ColorSequence.new(fx.color)
				e.LightEmission = 1
				e.LightInfluence = 0
				e.Rate = fx.kind == "aura" and 5 or 4
				e.Lifetime = NumberRange.new(0.8, 1.6)
				e.Speed = NumberRange.new(0.3, 1.2)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Size = fx.kind == "aura" and NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1.6 * bp.scale), NumberSequenceKeypoint.new(1, 0) })
					or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22 * bp.scale), NumberSequenceKeypoint.new(1, 0) })
				e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, fx.kind == "aura" and 0.75 or 0.1), NumberSequenceKeypoint.new(1, 1) })
				e.Parent = host
			elseif fx.kind == "light" then
				local l = Instance.new("PointLight")
				l.Name = "RarityLight"
				l.Color = fx.color
				l.Range = 8 * bp.scale
				l.Brightness = 0.8
				l.Shadows = false
				l.Parent = host
			elseif fx.kind == "trail" then
				local a0 = Instance.new("Attachment")
				a0.Name = "TrailTop"
				a0.Position = Vector3.new(0, host.Size.Y * 0.4, 0)
				a0.Parent = host
				local a1 = Instance.new("Attachment")
				a1.Name = "TrailBottom"
				a1.Position = Vector3.new(0, -host.Size.Y * 0.1, 0)
				a1.Parent = host
				local t = Instance.new("Trail")
				t.Name = "RarityTrail"
				t.Attachment0, t.Attachment1 = a0, a1
				t.Color = ColorSequence.new(fx.color)
				t.LightEmission = 1
				t.Lifetime = 0.45
				t.Transparency = NumberSequence.new(0.5, 1)
				t.FaceCamera = true
				t.Parent = host
			end
		end
	end
end

-- Constrói o molde de uma espécie (pode demorar: cria as malhas). Devolve { model, bp } ou nil.
function PetMesh.buildTemplate(speciesId: string, scale: number)
	local sp = Pets.Species[speciesId]
	if not sp then
		return nil
	end
	local bp = PetAnatomy.blueprint(speciesId, sp, scale)
	local model = Instance.new("Model")
	model.Name = "PetMesh"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.4
	root.Transparency = 1
	root.CanCollide, root.CanQuery, root.CanTouch, root.Massless, root.Anchored = false, false, false, true, false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local made = {}
	for _, p in ipairs(bp.parts) do
		local mp, center = meshPart(p.geom)
		mp.Name = p.name
		mp.Color = Color3.new(1, 1, 1) -- as cores estão nos vértices
		mp.Material = MATERIALS[p.material] or Enum.Material.SmoothPlastic
		mp.Transparency = p.transparency
		mp.Reflectance = p.reflectance
		mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.Massless, mp.Anchored = false, false, false, true, false
		mp.CastShadow = p.transparency < 0.5 and p.material ~= "Neon" and p.material ~= "ForceField"
		mp:SetAttribute("Role", p.role)
		for k, v in pairs(p.attrs or {}) do
			mp:SetAttribute(k, v)
		end
		mp.CFrame = CFrame.new(p.pivot + center)
		mp.Parent = model
		made[p.name] = mp
	end
	for _, p in ipairs(bp.parts) do
		local part = made[p.name]
		local parentPart = (p.parent and made[p.parent]) or root
		local m6 = Instance.new("Motor6D")
		m6.Name = p.joint or "Fixed"
		m6.Part0 = parentPart
		m6.Part1 = part
		m6.C0 = parentPart.CFrame:Inverse() * CFrame.new(p.pivot)
		m6.C1 = part.CFrame:Inverse() * CFrame.new(p.pivot)
		m6.Parent = part
	end
	effects(model, bp)
	model:SetAttribute("Anatomy", bp.anatomy)
	model:SetAttribute("Gait", bp.gait)
	model:SetAttribute("Kind", bp.kind)
	model:SetAttribute("Hover", bp.hover)
	model:SetAttribute("Flies", bp.flies == true)
	model:SetAttribute("Species", speciesId)
	model:SetAttribute("Tier", bp.tier)
	model:SetAttribute("Heavy", bp.heavy == true)
	model:SetAttribute("MeshPet", true)
	return { model = model, bp = bp }
end

-- Molde pronto (ou nil). Se ainda não existe, começa a construir em segundo plano.
function PetMesh.request(speciesId: string, scale: number?)
	local s = scale or 1
	local k = key(speciesId, s)
	local t = templates[k]
	if t ~= nil then
		return t or nil
	end
	if PetMesh.available == false or pending[k] then
		return nil
	end
	pending[k] = true
	task.spawn(function()
		local ok, res = pcall(PetMesh.buildTemplate, speciesId, s)
		pending[k] = nil
		if ok and res then
			templates[k] = res
			PetMesh.available = true
		else
			templates[k] = false
			PetMesh.lastError = tostring(res)
			if PetMesh.available == nil then
				PetMesh.available = false -- a API não funciona aqui: fica o modelo antigo
				warn("[PetMesh] malhas indisponíveis, usando modelos antigos: " .. tostring(res))
			end
		end
	end)
	return nil
end

-- Espera o molde (até `timeout` s). Devolve { model, bp } ou nil.
function PetMesh.await(speciesId: string, scale: number?, timeout: number?)
	local limit = os.clock() + (timeout or 20)
	while os.clock() < limit do
		local t = PetMesh.request(speciesId, scale)
		if t then
			return t
		end
		if PetMesh.available == false or templates[key(speciesId, scale or 1)] == false then
			return nil
		end
		task.wait(0.1)
	end
	return nil
end

-- Clone pronto para usar, com mutação e acessório.
function PetMesh.instance(speciesId: string, scale: number?, mutation: string?, accessory: string?)
	local t = PetMesh.request(speciesId, scale)
	if not t then
		return nil
	end
	local m = t.model:Clone()
	MutationVisuals.apply(m, mutation)
	Accessories.apply(m, accessory)
	return m, t.bp
end

-- Para miniaturas e vitrines (inventário, chocar ovo): malha se já estiver pronta, senão o modelo antigo
-- (e pede a malha para a próxima vez).
function PetMesh.display(speciesId: string, mutation: string?, accessory: string?): Model
	local m = PetMesh.instance(speciesId, 1, mutation, accessory)
	if m then
		return m
	end
	local old = CreatureBuilder.build(speciesId, Pets.Species[speciesId], 1)
	MutationVisuals.apply(old, mutation)
	Accessories.apply(old, accessory)
	return old
end

function PetMesh.stats()
	local n = 0
	for _, t in pairs(templates) do
		if t then
			n += 1
		end
	end
	return { templates = n, meshes = #keep, available = PetMesh.available, lastError = PetMesh.lastError }
end

return PetMesh

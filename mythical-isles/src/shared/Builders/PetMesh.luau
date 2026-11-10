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
local Smooth = require(script.Parent.Smooth)
local PetRig = require(script.Parent.PetRig)
local PetAnatomy = require(script.Parent.PetAnatomy)
local CreatureBuilder = require(script.Parent.CreatureBuilder)
local MutationVisuals = require(script.Parent.MutationVisuals)
local Accessories = require(script.Parent.Accessories)
local Pets = require(script.Parent.Parent.Config.Pets)

local PetMesh = {}

PetMesh.available = nil -- EditableMesh funciona? nil = ainda não testado
PetMesh.lastError = nil
-- "mesh" = malhas lisas (EditableMesh); "poly" = mesma anatomia feita de peças LISAS (elipsoides: Part com
-- SpecialMesh de esfera, Builders/Smooth), usada quando o Roblox não libera o EditableMesh
PetMesh.mode = nil
PetMesh.polyError = nil

local templates = {} -- [chave] = { model = Model, bp = planta } | false (falhou)
local pending = {} -- [chave] = true enquanto constrói
local keep = {} -- referências aos EditableMesh (mantêm as malhas vivas)

local MATERIALS = {
	Fabric = Enum.Material.Fabric, SmoothPlastic = Enum.Material.SmoothPlastic, Glass = Enum.Material.Glass, Neon = Enum.Material.Neon,
	-- folhas e musgo dos pets/bosses: liso (a textura de grama do Roblox deixava o bicho com cara de gramado)
	Metal = Enum.Material.Metal, Grass = Enum.Material.SmoothPlastic, Wood = Enum.Material.Wood, Slate = Enum.Material.Slate, ForceField = Enum.Material.ForceField,
}

local function key(speciesId: string, scale: number): string
	return speciesId .. "@" .. string.format("%.2f", scale)
end

-- Uma MeshPart a partir da geometria (centrada na própria caixa, como o Roblox faz com malhas).
local function meshPart(geom)
	local g, center = MeshKit.centered(geom)
	local em = AssetService:CreateEditableMesh()
	if not em then
		error("o Roblox recusou criar a malha (CreateEditableMesh devolveu nil). Quase sempre é a opção 'Allow Mesh / Image APIs' desligada ou o jogo ainda não publicado; mais raramente, falta de memória do aparelho")
	end
	MeshKit.toEditable(g, em)
	local content = Content.fromObject(em)
	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(content, { CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	if not ok or not mp then
		mp = AssetService:CreateMeshPartAsync(content)
	end
	if not mp then
		error("CreateMeshPartAsync devolveu nil")
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

-- Texto para o jogador quando as malhas não puderem ser criadas (o motivo mais comum é a opção desligada).
PetMesh.HELP = "Os pets 3D novos (malhas anatômicas) estão DESLIGADOS e os pets antigos continuam no lugar.\n"
	.. "Para ligar no Roblox Studio:\n"
	.. "  1) Arquivo → Publicar no Roblox (as Configurações do jogo só abrem num jogo publicado)\n"
	.. "  2) Início → Configurações do jogo (Game Settings) → Segurança (Security)\n"
	.. "  3) Ative 'Allow Mesh / Image APIs' e salve (o Roblox exige dono da experiência com 13+ e ID verificado)\n"
	.. "  4) Pare e dê Play de novo.\n"
	.. "Erro do Roblox: "

-- texturas de tecido e de grama ficam ruidosas em faces pequenas (e a de grama parecia capim no pet)
local POLY_MATERIAL = { Fabric = Enum.Material.SmoothPlastic, Grass = Enum.Material.SmoothPlastic }

local function avgColor(g): Color3
	local r, gg, b, n = 0, 0, 0, 0
	for _, c in ipairs(g.colors) do
		r, gg, b, n = r + c.R, gg + c.G, b + c.B, n + 1
	end
	if n == 0 then
		return Color3.new(1, 1, 1)
	end
	return Color3.new(r / n, gg / n, b / n)
end

local function whiteColors(g)
	local cols = table.create(#g.colors)
	local white = Color3.new(1, 1, 1)
	for i = 1, #g.colors do
		cols[i] = white
	end
	return { verts = g.verts, colors = cols, tris = g.tris, flat = g.flat, keep = g.keep }
end

--[[ Monta um Model a partir de uma planta (pets e bosses usam o mesmo formato).
	poly = false: uma MeshPart por parte do corpo (EditableMesh, cor por vértice).
	poly = true: cada parte vira um "osso" invisível com elipsoides lisos soldados (Builders/Smooth: Part +
	SpecialMesh de esfera; nada de faces triangulares). opts.quality = "high": mais elipsoides.
	Juntas Motor6D nos pivôs (eixos alinhados) com os nomes da planta. Peças Neon ficam com a cor
	média na própria peça (o brilho do Neon usa a cor da peça). opts.yieldEvery: no modo de peças,
	espera um frame a cada N peças criadas. Devolve (model, número de elipsoides). ]]
function PetMesh.assemble(bp, poly: boolean, opts)
	opts = opts or {}
	local model = Instance.new("Model")
	model.Name = opts.name or "PetMesh"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.4
	root.Transparency = 1
	root.CanCollide, root.CanQuery, root.CanTouch, root.Massless, root.Anchored = false, false, false, true, false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local made, blobCount, sinceYield = {}, 0, 0
	local blobs = (poly and not opts.skeletonOnly) and Smooth.forBlueprint(bp, opts.quality) or nil -- skeletonOnly: só os ossos (pele do Blender)
	for _, p in ipairs(bp.parts) do
		local neon = p.material == "Neon"
		local avg = avgColor(p.geom)
		local inst: BasePart
		if not poly then
			local mp, center = meshPart(neon and whiteColors(p.geom) or p.geom)
			mp.Color = neon and avg or Color3.new(1, 1, 1) -- as cores estão nos vértices
			mp.Material = MATERIALS[p.material] or Enum.Material.SmoothPlastic
			mp.Transparency = p.transparency
			mp.Reflectance = p.reflectance
			mp.CastShadow = p.transparency < 0.5 and p.material ~= "Neon" and p.material ~= "ForceField"
			mp.CFrame = CFrame.new(p.pivot + center)
			inst = mp
		else
			local mn, mx = MeshKit.bounds(p.geom)
			local sz = mx - mn
			local bone = Instance.new("Part")
			bone.Size = Vector3.new(math.max(sz.X, 0.2), math.max(sz.Y, 0.2), math.max(sz.Z, 0.2))
			bone.Transparency = 1
			bone.Color = avg
			bone.CFrame = CFrame.new(p.pivot + (mn + mx) / 2)
			inst = bone
		end
		inst.Name = p.name
		inst.CanCollide, inst.CanQuery, inst.CanTouch, inst.Massless, inst.Anchored = false, false, false, true, false
		inst:SetAttribute("Role", p.role)
		for k, v in pairs(p.attrs or {}) do
			inst:SetAttribute(k, v)
		end
		inst.Parent = model
		made[p.name] = inst
		if poly and blobs then
			local material = POLY_MATERIAL[p.material] or MATERIALS[p.material] or Enum.Material.SmoothPlastic
			local shadow = p.transparency < 0.5 and p.material ~= "Neon" and p.material ~= "ForceField"
			for _, b in ipairs((blobs :: any)[p.name] or {}) do
				local e = Instance.new("Part")
				e.Name = "Blob"
				e.Size = b.size
				e.CFrame = b.cf
				e.Color = b.color
				e.Material = material
				e.Transparency = p.transparency
				e.Reflectance = p.reflectance or 0
				e.CastShadow = shadow
				e.TopSurface, e.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
				e.CanCollide, e.CanQuery, e.CanTouch, e.Massless, e.Anchored = false, false, false, true, false
				if p.role then
					e:SetAttribute("Role", p.role)
				end
				-- a forma vem da malha especial de esfera, esticada no tamanho da peça (elipsoide)
				local sm = Instance.new("SpecialMesh")
				sm.MeshType = Enum.MeshType.Sphere
				sm.Parent = e
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = inst
				weld.Part1 = e
				weld.Parent = e
				e.Parent = inst
				blobCount += 1
				sinceYield += 1
				if opts.yieldEvery and sinceYield >= opts.yieldEvery then
					sinceYield = 0
					task.wait()
				end
			end
		end
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
	return model, blobCount
end

local function petAttributes(model: Model, bp, speciesId: string)
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
end

-- Constrói o molde de uma espécie (pode demorar: cria as malhas). Devolve { model, bp } ou nil.
function PetMesh.buildTemplate(speciesId: string, scale: number)
	local sp = Pets.Species[speciesId]
	if not sp then
		return nil
	end
	local bp = PetAnatomy.blueprint(speciesId, sp, scale)
	local model = PetMesh.assemble(bp, false)
	petAttributes(model, bp, speciesId)
	return { model = model, bp = bp }
end

-------------------------------------------------------------------------------
-- Modo de peças (sem EditableMesh): cada parte do corpo vira elipsoides lisos presos ao "osso" da parte;
-- os ossos têm as mesmas juntas (Motor6D) e a mesma animação do modo de malhas.
-------------------------------------------------------------------------------

-- quality "high": "Alta qualidade" (mais faces na cabeça e no tronco, bochechas, sobrancelhas, músculos e
-- pálpebras); usada nos pets do próprio jogador no computador. Sem quality: modo leve.
function PetMesh.buildTemplatePoly(speciesId: string, scale: number, quality: string?)
	local sp = Pets.Species[speciesId]
	if not sp then
		return nil
	end
	local bp = PetAnatomy.blueprint(speciesId, sp, scale, { low = true, mid = quality == "high" })
	local model, blobs = PetMesh.assemble(bp, true, { quality = quality })
	petAttributes(model, bp, speciesId)
	model:SetAttribute("PolyPet", true)
	model:SetAttribute("SmoothPet", true)
	model:SetAttribute("Blobs", blobs)
	model:SetAttribute("Quality", quality == "high" and "high" or "light")
	return { model = model, bp = bp, poly = true, blobs = blobs }
end

-- MODELO DO BLENDER (ReplicatedStorage.PetRigs.<id>, importado no Studio): esqueleto invisível do jogo +
-- a pele lisa e contínua importada, que segue os ossos (Builders/PetRig). Funciona sem EditableMesh.
function PetMesh.buildTemplateRig(speciesId: string, scale: number)
	local sp = Pets.Species[speciesId]
	local src = PetRig.find(speciesId)
	if not sp or not src then
		return nil
	end
	local bp = PetAnatomy.blueprint(speciesId, sp, scale, { low = true })
	local model = PetMesh.assemble(bp, true, { skeletonOnly = true })
	petAttributes(model, bp, speciesId)
	local linked, missing = PetRig.attach(model, src:Clone(), bp)
	if linked == 0 then
		error("o modelo importado de " .. speciesId .. " não tem ossos com os nomes das partes (" .. table.concat(missing, ", ") .. ")")
	end
	model:SetAttribute("Bones", linked)
	return { model = model, bp = bp, rig = true }
end

-- Molde pronto (ou nil). Se ainda não existe, começa a construir em segundo plano.
function PetMesh.request(speciesId: string, scale: number?, quality: string?)
	if PetMesh.available == true then
		quality = nil -- com EditableMesh as malhas já são suaves: a "Alta qualidade" é do modo de peças
	end
	local s = scale or 1
	local k = key(speciesId, s) .. (quality == "high" and "#hq" or "")
	local t = templates[k]
	if t ~= nil then
		return t or nil
	end
	if pending[k] then
		return nil
	end
	pending[k] = true
	task.spawn(function()
		local res
		-- 1º: modelo feito no Blender e importado no Studio, se existir para esta espécie
		if PetRig.find(speciesId) then
			local okR, r = pcall(PetMesh.buildTemplateRig, speciesId, s)
			if okR and r then
				res = r
			else
				warn("[PetMesh] modelo importado de " .. speciesId .. " não pôde ser usado: " .. tostring(r))
			end
		end
		if not res and PetMesh.available ~= false then
			local ok, r = pcall(PetMesh.buildTemplate, speciesId, s)
			if ok and r then
				res = r
				PetMesh.available = true
				PetMesh.mode = PetMesh.mode or "mesh"
			else
				PetMesh.lastError = tostring(r)
				if PetMesh.available == nil then
					PetMesh.available = false
					PetMesh.mode = "poly"
					-- não é erro: o jogo segue com os pets low-poly (aviso informativo no Output)
					print("[PetMesh] o Roblox não liberou o EditableMesh; usando os pets low-poly feitos de peças: " .. tostring(r))
				end
			end
		end
		if not res then
			-- sem EditableMesh: mesma anatomia em baixa resolução, feita de peças
			local ok2, r2 = pcall(PetMesh.buildTemplatePoly, speciesId, s, quality)
			if ok2 and r2 then
				res = r2
			else
				PetMesh.polyError = tostring(r2)
				warn("[PetMesh] falhou também o modo de peças: " .. tostring(r2))
			end
		end
		templates[k] = res or false
		pending[k] = nil
	end)
	return nil
end

-- Espera o molde (até `timeout` s). Devolve { model, bp } ou nil.
function PetMesh.await(speciesId: string, scale: number?, timeout: number?, quality: string?)
	local limit = os.clock() + (timeout or 20)
	while os.clock() < limit do
		local t = PetMesh.request(speciesId, scale, quality)
		if t then
			return t
		end
		if templates[key(speciesId, scale or 1) .. ((quality == "high" and PetMesh.available ~= true) and "#hq" or "")] == false then
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
	local t = PetMesh.request(speciesId, 1)
	if t and not t.poly then
		local m = t.model:Clone()
		MutationVisuals.apply(m, mutation)
		Accessories.apply(m, accessory)
		return m
	end
	local old = CreatureBuilder.build(speciesId, Pets.Species[speciesId], 1)
	MutationVisuals.apply(old, mutation)
	Accessories.apply(old, accessory)
	return old
end

-- CONTORNO DE DESENHO: um Highlight só com a linha (sem preenchimento) em volta do modelo inteiro,
-- como o traço de um anime. O Roblox desenha no máximo 31 Highlights por cliente, então o jogo usa
-- só nos pets do próprio jogador (até 4) e no boss por perto.
function PetMesh.outline(model: Model, color: Color3?, transparency: number?): Highlight
	local h = model:FindFirstChild("ToonOutline") :: Highlight?
	if not h then
		h = Instance.new("Highlight")
		h.Name = "ToonOutline"
		h.FillTransparency = 1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
	end
	local hl = h :: Highlight
	hl.OutlineColor = color or Color3.fromRGB(28, 20, 34)
	hl.OutlineTransparency = transparency or 0.2
	hl.Adornee = model
	return hl
end

-- (testes) esquece moldes e o estado da API
function PetMesh._reset()
	table.clear(templates)
	table.clear(pending)
	PetMesh.available, PetMesh.mode, PetMesh.lastError, PetMesh.polyError = nil, nil, nil, nil
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

-- Moldes dos bosses novos (BossAnatomy), no CLIENTE: malhas lisas (EditableMesh) quando o Roblox libera,
-- senão a mesma anatomia feita de peças lisas (elipsoides, Builders/Smooth). Usa a mesma decisão de modo dos
-- pets (PetMesh.available): se o EditableMesh já falhou para um pet, vai direto para o modo de peças.
-- Se os dois modos falharem, devolve nil e o boss antigo (do servidor) continua visível.

local PetMesh = require(script.Parent.PetMesh)
local BossAnatomy = require(script.Parent.BossAnatomy)
local PetRig = require(script.Parent.PetRig)

local BossMesh = {}

local templates = {} -- [bossId] = { model, bp, poly, blobs } | false (falhou)
local pending = {}
BossMesh.lastError = nil

local function build(id: string, poly: boolean)
	local bp = BossAnatomy.blueprint(id, { low = poly })
	-- no modo de peças são centenas de elipsoides: cria em lotes, um frame por lote, sem travar o jogo
	local model, blobs = PetMesh.assemble(bp, poly, { name = "BossVisual", yieldEvery = poly and 120 or nil, quality = poly and "high" or nil })
	model:SetAttribute("BossVisual", id)
	model:SetAttribute("PolyBoss", poly)
	model:SetAttribute("SmoothBoss", poly)
	model:SetAttribute("Blobs", blobs)
	return { model = model, bp = bp, poly = poly, blobs = blobs }
end

-- Boss feito no Blender e importado no Studio (ReplicatedStorage.PetRigs.boss_<id>): esqueleto invisível do
-- jogo + a pele contínua importada (Builders/PetRig). As peças de energia continuam nos ossos (luzes do Fx).
local function buildRig(id: string)
	local src = PetRig.find("boss_" .. id)
	if not src then
		return nil
	end
	local bp = BossAnatomy.blueprint(id, { low = true })
	local model = PetMesh.assemble(bp, true, { name = "BossVisual", skeletonOnly = true })
	local linked, missing = PetRig.attach(model, src:Clone(), bp)
	if linked == 0 then
		error("o modelo importado do boss " .. id .. " não tem ossos com os nomes das partes (" .. table.concat(missing, ", ") .. ")")
	end
	model:SetAttribute("BossVisual", id)
	model:SetAttribute("PolyBoss", false)
	model:SetAttribute("Bones", linked)
	return { model = model, bp = bp, poly = false, rig = true }
end
BossMesh._buildRig = buildRig

-- Molde pronto (ou nil). Se ainda não existe, começa a construir em segundo plano.
function BossMesh.request(id: string)
	if not BossAnatomy.has(id) then
		return nil
	end
	local t = templates[id]
	if t ~= nil then
		return t or nil
	end
	if pending[id] then
		return nil
	end
	pending[id] = true
	task.spawn(function()
		local res
		if PetRig.find("boss_" .. id) then
			local okR, r = pcall(buildRig, id)
			if okR and r then
				res = r
			else
				warn("[BossMesh] modelo importado do boss " .. id .. " não pôde ser usado: " .. tostring(r))
			end
		end
		if not res and PetMesh.available ~= false then
			local ok, r = pcall(build, id, false)
			if ok and r then
				res = r
				PetMesh.available = true
				PetMesh.mode = PetMesh.mode or "mesh"
			else
				PetMesh.lastError = tostring(r)
				if PetMesh.available == nil then
					PetMesh.available = false
					PetMesh.mode = "poly"
					print("[BossMesh] o Roblox não liberou o EditableMesh; usando os bosses low-poly feitos de peças: " .. tostring(r))
				end
			end
		end
		if not res then
			local ok2, r2 = pcall(build, id, true)
			if ok2 and r2 then
				res = r2
			else
				BossMesh.lastError = tostring(r2)
				warn("[BossMesh] não foi possível montar o boss " .. id .. " (o modelo antigo continua): " .. tostring(r2))
			end
		end
		templates[id] = res or false
		pending[id] = nil
	end)
	return nil
end

-- Espera o molde (até `timeout` s). Devolve o molde ou nil.
function BossMesh.await(id: string, timeout: number?)
	local limit = os.clock() + (timeout or 30)
	while os.clock() < limit do
		local t = BossMesh.request(id)
		if t then
			return t
		end
		if templates[id] == false or not BossAnatomy.has(id) then
			return nil
		end
		task.wait(0.1)
	end
	return nil
end

-- (testes)
function BossMesh._reset()
	table.clear(templates)
	table.clear(pending)
	BossMesh.lastError = nil
end

return BossMesh

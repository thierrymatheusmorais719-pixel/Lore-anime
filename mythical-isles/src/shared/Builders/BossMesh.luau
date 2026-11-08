-- Moldes dos bosses novos (BossAnatomy), no CLIENTE: malhas lisas (EditableMesh) quando o Roblox libera,
-- senão a mesma anatomia em resolução menor feita de peças (WedgeParts). Usa a mesma decisão de modo dos
-- pets (PetMesh.available): se o EditableMesh já falhou para um pet, vai direto para o modo de peças.
-- Se os dois modos falharem, devolve nil e o boss antigo (do servidor) continua visível.

local PetMesh = require(script.Parent.PetMesh)
local BossAnatomy = require(script.Parent.BossAnatomy)

local BossMesh = {}

local templates = {} -- [bossId] = { model, bp, poly, facets } | false (falhou)
local pending = {}
BossMesh.lastError = nil

local function build(id: string, poly: boolean)
	local bp = BossAnatomy.blueprint(id, { low = poly })
	-- no modo de peças são milhares de cunhas: cria em lotes, um frame por lote, sem travar o jogo
	local model, facets = PetMesh.assemble(bp, poly, { name = "BossVisual", yieldEvery = poly and 300 or nil })
	model:SetAttribute("BossVisual", id)
	model:SetAttribute("PolyBoss", poly)
	model:SetAttribute("Facets", facets)
	return { model = model, bp = bp, poly = poly, facets = facets }
end

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
		if PetMesh.available ~= false then
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

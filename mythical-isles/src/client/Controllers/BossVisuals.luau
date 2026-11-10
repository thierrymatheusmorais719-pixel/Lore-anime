-- Visual dos bosses no cliente: troca o modelo de peças do servidor (que continua cuidando de posição,
-- combate, vida, hitbox e ataques) pelo boss anatômico novo (BossAnatomy → BossMesh), animado pelo
-- Animator com os mesmos nomes de juntas e atributos do servidor, e com a energia (Fx) nas peças novas.
-- O modelo do servidor fica invisível só neste cliente. Só monta o boss de que o jogador está perto
-- (são milhares de peças no modo low-poly) e o tira da cena quando ele se afasta.
-- Se o boss novo não puder ser montado, nada muda: o modelo antigo continua visível e animado.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BossMesh = require(Shared.Builders.BossMesh)
local PetMesh = require(Shared.Builders.PetMesh)
local PetRig = require(Shared.Builders.PetRig)
local BossConfig = require(Shared.Config.Bosses)
local Animator = require(script.Parent.Animator)
local Fx = require(script.Parent.Fx)

local BossVisuals = {}

BossVisuals.NEAR = 650 -- monta o visual a esta distância
BossVisuals.FAR = 900 -- tira da cena a esta distância
BossVisuals.PREFETCH = 1100 -- começa a construir o molde

local player = Players.LocalPlayer
local entries: { [Model]: any } = {}

local function hide(d: Instance, vis: Instance?)
	if vis and d:IsDescendantOf(vis) then
		return
	end
	if d:IsA("BasePart") then
		d.LocalTransparencyModifier = 1
	elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Light") then
		(d :: any).Enabled = false
	end
end

local function viewerPos(): Vector3?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		return (hrp :: BasePart).Position
	end
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position or nil
end

local function attach(e): boolean
	local model = e.server
	local sroot = model.PrimaryPart
	if not sroot then
		return false
	end
	if not e.vis then
		local t = BossMesh.request(model:GetAttribute("BossId"))
		if not t then
			return false -- ainda construindo (ou falhou: o modelo antigo segue)
		end
		local vis = t.model:Clone()
		vis.Name = "Visual"
		-- silhueta na cor da energia do boss (contorno que destaca o boss no escuro da arena)
		local info = BossConfig.Info[model:GetAttribute("BossId")]
		PetMesh.outline(vis, info and info.color or Color3.fromRGB(14, 10, 20), 0.3)
		-- durante um PODER o boss fica tingido da cor dele (preenchimento leve do Highlight)
		local hl = vis:FindFirstChild("ToonOutline") :: Highlight
		local function tint()
			local untilT = model:GetAttribute("PowerUntil")
			local on = untilT ~= nil and workspace:GetServerTimeNow() < untilT
			hl.FillColor = info and info.color or Color3.new(1, 1, 1)
			hl.FillTransparency = on and 0.72 or 1
			if on then
				task.delay(untilT - workspace:GetServerTimeNow() + 0.05, tint)
			end
		end
		model:GetAttributeChangedSignal("PowerUntil"):Connect(tint)
		tint()
		local root = vis.PrimaryPart :: BasePart
		root.Anchored = true
		e.vis, e.root, e.poly = vis, root, t.poly
		e.rig = t.rig and PetRig.collect(vis) or nil -- pele do Blender seguindo o esqueleto
	end
	e.root.CFrame = sroot.CFrame
	e.last = sroot.CFrame
	model:SetAttribute("MeshVisual", true) -- atributo local: o Animator e o Fx deixam o modelo antigo de lado
	e.vis.Parent = model
	if not e.conn then
		for _, d in ipairs(model:GetDescendants()) do
			hide(d, e.vis)
		end
		e.conn = model.DescendantAdded:Connect(function(d)
			hide(d, e.vis)
		end)
	end
	Animator.track(e.vis, model)
	Fx.retargetEnergy(model, e.vis)
	return true
end

local function consider(model: Instance)
	if model:IsA("Model") and model:GetAttribute("BossId") and not entries[model] then
		entries[model] = { server = model }
	end
end

function BossVisuals.update()
	local pos = viewerPos()
	for model, e in pairs(entries) do
		if not model.Parent then
			entries[model] = nil
			if e.conn then
				e.conn:Disconnect()
			end
			if e.vis then
				e.vis:Destroy()
			end
			continue
		end
		local sroot = model.PrimaryPart
		local d = (pos and sroot) and (pos - sroot.Position).Magnitude or math.huge
		local attached = e.vis ~= nil and e.vis.Parent == model
		if not attached then
			if d < BossVisuals.PREFETCH then
				BossMesh.request(model:GetAttribute("BossId"))
			end
			if d < BossVisuals.NEAR then
				attach(e)
			end
		elseif d > BossVisuals.FAR then
			e.vis.Parent = nil -- longe: sai da cena (o molde e o clone ficam guardados)
		end
	end
end

function BossVisuals.init()
	task.spawn(function()
		local folder = workspace:WaitForChild("Bosses", 30)
		if not folder then
			return
		end
		for _, c in ipairs(folder:GetChildren()) do
			consider(c)
		end
		folder.ChildAdded:Connect(function(c)
			task.defer(consider, c)
		end)
		while true do
			BossVisuals.update()
			task.wait(0.5)
		end
	end)
	RunService.RenderStepped:Connect(function()
		for model, e in pairs(entries) do
			if e.rig and e.vis and e.vis.Parent == model then
				PetRig.step(e.rig)
			end
		end
	end)
	-- a raiz do visual acompanha a raiz do boss no servidor (antes da física, para as juntas seguirem)
	RunService.Stepped:Connect(function()
		for model, e in pairs(entries) do
			if e.vis and e.vis.Parent == model then
				local sroot = model.PrimaryPart
				if sroot then
					local cf = sroot.CFrame
					if cf ~= e.last then
						e.root.CFrame = cf
						e.last = cf
					end
				end
			end
		end
	end)
end

BossVisuals.entries = entries
return BossVisuals

--!strict
-- Habilidade "Getsuga Tenshō Negro". Todo o julgamento é do servidor:
-- forma ativa, cooldown, rate limit, direção sanitizada, tempo de telegraph, varredura de acerto
-- e dano. O cliente só pede e desenha efeitos.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Mugetsu")
local Config = require(Shared:WaitForChild("Config"))
local AbilityMath = require(Shared:WaitForChild("AbilityMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RateLimiter = require(script.Parent:WaitForChild("RateLimiter"))
local TransformationService = require(script.Parent:WaitForChild("TransformationService"))

local AbilityService = {}

local A = Config.Ability
local readyAt: { [Player]: number } = {}
local casting: { [Player]: boolean } = {}

type Beam = {
	owner: Player,
	origin: Vector3,
	dir: Vector3,
	startTime: number,
	travelled: number,
	hit: { [Model]: boolean },
	hits: number,
	conn: RBXScriptConnection?,
}
local beams: { [Beam]: boolean } = {}

local cooldownRemote = Remotes.get("AbilityCooldown")
local telegraphRemote = Remotes.get("AbilityTelegraph")
local fireRemote = Remotes.get("AbilityFire")

local function alive(char: Model?): (Humanoid?, BasePart?)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hum and root and hum.Health > 0 then
		return hum, root
	end
	return nil, nil
end

local function broadcast(remote: RemoteEvent, origin: Vector3, payload: any)
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and (hrp.Position - origin).Magnitude <= Config.Transform.MaxRange + A.Range then
			remote:FireClient(p, payload)
		end
	end
end

local function candidates(owner: Player): { Model }
	local list: { Model } = {}
	for _, p in Players:GetPlayers() do
		if p ~= owner and p.Character then
			-- sem fogo amigo entre colegas de time
			if not (owner.Team ~= nil and p.Team == owner.Team and not owner.Neutral) then
				table.insert(list, p.Character)
			end
		end
	end
	for _, m in CollectionService:GetTagged("MugetsuTarget") do
		if m:IsA("Model") then
			table.insert(list, m)
		end
	end
	return list
end

local function sweep(b: Beam, from: number, to: number)
	local segOrigin = b.origin + b.dir * from
	local length = to - from
	for _, model in candidates(b.owner) do
		if b.hit[model] or b.hits >= A.MaxHitsPerCast then
			continue
		end
		local hum, root = alive(model)
		if hum and root then
			-- tolerância de meia espessura do alvo em cada eixo
			local inside = AbilityMath.insideBeam(root.Position, segOrigin, b.dir, length + 2, A.Width + 2, A.Height)
			if inside then
				b.hit[model] = true
				b.hits += 1
				hum:TakeDamage(A.Damage)
			end
		end
	end
end

local function endBeam(b: Beam)
	if b.conn then
		b.conn:Disconnect()
		b.conn = nil
	end
	beams[b] = nil
end

local function launch(owner: Player, origin: Vector3, dir: Vector3)
	local now = Workspace:GetServerTimeNow()
	local b: Beam = { owner = owner, origin = origin, dir = dir, startTime = now, travelled = 0, hit = {}, hits = 0, conn = nil }
	beams[b] = true
	broadcast(fireRemote, origin, {
		userId = owner.UserId, origin = origin, dir = dir, speed = A.ProjectileSpeed,
		range = A.Range, width = A.Width, startTime = now,
	})
	local last = 0
	b.conn = RunService.Heartbeat:Connect(function()
		local d = math.min(A.Range, (Workspace:GetServerTimeNow() - b.startTime) * A.ProjectileSpeed)
		if d > last then
			sweep(b, last, d)
			last = d
		end
		if d >= A.Range then
			endBeam(b)
		end
	end)
end

function AbilityService.request(player: Player, aimDir: any)
	if not RateLimiter.allow(player, "Ability", Config.Ability.RemoteRateLimit) then
		return
	end
	local char = player.Character
	local hum, root = alive(char)
	if not (hum and root) then
		return
	end
	if player:GetAttribute("MugetsuForm") ~= true or player:GetAttribute("MugetsuAbilityReady") ~= true then
		return
	end
	if TransformationService.isInCutscene(player) or casting[player] then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if not AbilityMath.isReady(readyAt[player], now) then
		return
	end
	local dir = AbilityMath.sanitizeDirection(aimDir)
	if not dir then
		return
	end
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	dir = AbilityMath.clampAim(dir, facing, A.AimTolerance)

	-- aceitou: cooldown começa agora (servidor), o dono é avisado com o instante exato
	readyAt[player] = now + A.Cooldown
	cooldownRemote:FireClient(player, { readyAt = readyAt[player], duration = A.Cooldown })
	casting[player] = true

	-- trava leve de movimento durante o telegraph
	local prevSpeed = hum.WalkSpeed
	hum.WalkSpeed = 0
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	local origin = root.Position + Vector3.new(0, 1, 0) + dir * 3
	broadcast(telegraphRemote, origin, {
		userId = player.UserId, origin = origin, dir = dir, range = A.Range, width = A.Width,
		startTime = now, telegraph = A.TelegraphTime,
	})

	task.delay(A.TelegraphTime, function()
		casting[player] = false
		if hum.Parent then
			hum.WalkSpeed = prevSpeed
		end
		local h2, r2 = alive(player.Character)
		if not (h2 and r2) or TransformationService.isInCutscene(player) then
			return -- morreu/cena: cancela o disparo, cooldown permanece
		end
		launch(player, origin, dir)
	end)
end

function AbilityService.init()
	Remotes.get("RequestAbility").OnServerEvent:Connect(function(player: Player, aim: any)
		AbilityService.request(player, aim)
	end)
	Players.PlayerRemoving:Connect(function(p)
		readyAt[p] = nil
		casting[p] = nil
		for b in beams do
			if b.owner == p then
				endBeam(b)
			end
		end
	end)
end


return AbilityService

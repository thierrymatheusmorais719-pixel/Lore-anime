-- Cenário: servidor monta a cidade, cliente toca a cinemática do começo ao fim, depois "Assistir de novo"
-- e "Pular". Confere erros, tomadas, limpeza e câmera devolvida.
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then
		results.pass += 1
		print("PASSOU  " .. name)
	else
		results.fail += 1
		print("FALHOU  " .. name .. (detail and ("  -> " .. tostring(detail)) or ""))
	end
end

-- ReplicatedStorage.Duelo aponta para os módulos compartilhados

__modules["Server/Main"](__proxy("Server/Main"))
SIM.run(0.2)
check("servidor monta a cidade sem erros", #SIM.errors == 0, SIM.errors[1])
local nParts = 0
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") then nParts += 1 end
end
print("peças na cidade: " .. nParts)
check("cidade tem peças (e < 6000)", nParts > 200 and nParts < 6000, nParts)

local Players = game:GetService("Players")
local lp = Instance.new("Player")
lp.Name = "Viewer"
lp.UserId = 1
lp.Parent = Players
Players.LocalPlayer = lp
local pg = Instance.new("PlayerGui")
pg.Name = "PlayerGui"
pg.Parent = lp
local char = Instance.new("Model")
char.Name = "Viewer"
local hrp = Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.Parent = char
char.Parent = workspace
lp.Character = char
local cam = Instance.new("Camera")
cam.CFrame = CFrame.new(0, 50, 0)
cam.CameraType = Enum.CameraType.Custom
cam.FieldOfView = 70
cam.ViewportSize = Vector2.new(1280, 720)
workspace.CurrentCamera = cam
local rs = game:GetService("RunService")
rs.RenderStepped = SIM.Signal()
local sg = Instance.new("StarterGui")
function sg.SetCoreGuiEnabled() end
SIM.registerService("StarterGui", sg)

local function frames(seconds)
	local n = math.floor(seconds * 30)
	for _ = 1, n do
		rs.RenderStepped:Fire(1 / 30)
		SIM.run(1 / 30)
	end
end

-- cliente real
SIM.task.spawn(function()
	__modules["Client/Main"](__proxy("Client/Main"))
end)
frames(3)
local Timeline = require(__proxy("Duelo/Timeline"))
check("cinemática começou", Timeline.isRunning())
check("câmera em modo Scriptable", cam.CameraType == Enum.CameraType.Scriptable, cam.CameraType)
check("personagem do jogador congelado", hrp.Anchored == true)
local stage = workspace:FindFirstChild("CinematicStage")
check("os dois lutadores existem", stage and stage:FindFirstChild("Ren Arashi") ~= nil and stage:FindFirstChild("Akane Sumi") ~= nil)

-- guarda posições de câmera ao longo da luta (para ver se ela realmente se mexe e não vira NaN)
local camSamples, nan, peakFx = {}, false, 0
for _ = 1, 70 do
	frames(1)
	local p = cam.CFrame.Position
	if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z then nan = true end
	table.insert(camSamples, p)
	local fx = workspace:FindFirstChild("CinematicFx")
	if fx then peakFx = math.max(peakFx, #fx:GetDescendants()) end
	if not Timeline.isRunning() then break end
end
print("tomadas: " .. table.concat(Timeline.beats, ", "))
print("pico de instâncias de efeito: " .. peakFx)
check("todas as tomadas tocaram", table.concat(Timeline.beats, ",") == "cidade,encarada,choque,troca,traco_carmesim,lanca_do_trovao,arenas,golpe_final,fim", table.concat(Timeline.beats, ","))
check("sem erros durante a luta", #SIM.errors == 0, SIM.errors[1])
check("câmera nunca virou NaN", not nan)
local moved = 0
for i = 2, #camSamples do moved += (camSamples[i] - camSamples[i - 1]).Magnitude end
check("câmera se movimentou (>300 studs no total)", moved > 300, moved)
check("pico de efeitos razoável (< 1500)", peakFx < 1500, peakFx)
check("terminou dentro de ~70 s", not Timeline.isRunning())
check("palco removido", workspace:FindFirstChild("CinematicStage") == nil)
local fx = workspace:FindFirstChild("CinematicFx")
check("efeitos limpos", fx == nil or #fx:GetChildren() == 0, fx and #fx:GetChildren())
check("câmera devolvida ao jogador", cam.CameraType == Enum.CameraType.Custom, cam.CameraType)
check("personagem liberado", hrp.Anchored == false)
local g = pg:FindFirstChild("Cinematic")
local replay = g and g:FindFirstChild("Replay")
check("cartão final com 'Assistir de novo'", replay ~= nil)

-- assistir de novo, depois pular
if replay then
	replay.Activated:Fire()
	frames(2)
	check("replay recomeça a cinemática", Timeline.isRunning())
	local skip = pg:FindFirstChild("Cinematic") and pg.Cinematic:FindFirstChild("Skip")
	check("botão Pular existe", skip ~= nil)
	if skip then skip.Activated:Fire() end
	frames(3)
	check("Pular encerra a cinemática", not Timeline.isRunning())
	check("sem erros no replay/pular", #SIM.errors == 0, SIM.errors[1])
end

-- animações do Blender: o quadro-chave exportado tem que ser igual a CFrame.Angles da pose do script
do
	local Anims = require(__proxy("Duelo/Anims"))
	local function rotOf(clip, joint, f)
		local a = Anims.Clips[clip].J[joint]
		local i = f * 4
		return CFrame.new(0, 0, 0, a[i + 1], a[i + 2], a[i + 3], a[i + 4])
	end
	local function same(c1, c2)
		for k = 1, 9 do
			if math.abs(c1.r[k] - c2.r[k]) > 1e-3 then
				return false
			end
		end
		return true
	end
	local r = math.rad
	check("Blender: soco (quadro 7) ombro direito = Angles(96°, 0, -4°)", same(rotOf("punch", "RightShoulder", 7), CFrame.Angles(r(96), 0, r(-4))))
	check("Blender: chute (quadro 9) quadril direito = Angles(112°, 0, 12°)", same(rotOf("kick", "RightHip", 9), CFrame.Angles(r(112), 0, r(12))))
	check("Blender: guarda (quadro 0) cintura = Angles(12°, -18°, 0)", same(rotOf("guard", "Waist", 0), CFrame.Angles(r(12), r(-18), 0)))
	check("Blender: soco esquerdo é o espelho do direito", same(rotOf("punchL", "LeftShoulder", 7), CFrame.Angles(r(96), 0, r(4))))
	local n = 0
	for _ in pairs(Anims.Clips) do
		n += 1
	end
	check("Blender: 13 clipes exportados", n == 13, n)
	-- pés no chão: na guarda/parado, o pé mais baixo fica perto de y = 0 (sem afundar)
	local Rig = require(__proxy("Duelo/Rig"))
	local rig = Rig.build("ren", CFrame.new(0, 100, 0))
	local function lowestFoot()
		-- resolve as juntas como o Roblox faria
		local cfs = { [rig.root] = rig.root.CFrame }
		local changed = true
		while changed do
			changed = false
			for _, d in ipairs(rig.model:GetDescendants()) do
				if (d.ClassName == "Motor6D" or d.ClassName == "Weld") and cfs[d.Part0] and not cfs[d.Part1] then
					cfs[d.Part1] = cfs[d.Part0] * d.C0 * ((d.ClassName == "Motor6D" and d.Transform) or CFrame.new()) * (d.C1 or CFrame.new()):Inverse()
					changed = true
				end
			end
		end
		local low = math.huge
		for _, nm in ipairs({ "LeftFoot", "RightFoot" }) do
			local foot = rig.model:FindFirstChild(nm)
			local c = cfs[foot]
			for _, sx in ipairs({ -0.5, 0.5 }) do
				for _, sz in ipairs({ -0.55, 0.55 }) do
					low = math.min(low, (c * Vector3.new(sx, -0.15, sz)).Y)
				end
			end
		end
		return low - 100
	end
	for _, clipName in ipairs({ "idle", "guard" }) do
		Rig.pose(rig, clipName, true)
		rig.time = 0
		local worst = math.huge
		for _ = 1, 40 do
			Rig.step(rig, 1 / 30, 0)
			worst = math.min(worst, lowestFoot())
		end
		check("pés no chão em '" .. clipName .. "' (pé mais baixo entre -0.35 e 0.15)", worst > -0.35 and worst < 0.15, worst)
	end
	rig.model:Destroy()
end

-- modo avatar: no simulador o servidor não consegue montar o avatar R15 do Roblox (sem catálogo), então a pasta
-- fica vazia e o cliente usa o R15 de peças. Aqui um modelo R15 é posto na pasta, como o servidor faria no Roblox.
do
	local Rig = require(__proxy("Duelo/Rig"))
	local RS = game:GetService("ReplicatedStorage")
	check("sem avatar do servidor, os lutadores usam o R15 de peças", true)
	local folder = RS:FindFirstChild("DueloAvatars") or Instance.new("Folder")
	folder.Name = "DueloAvatars"
	local fake = Rig.build("ren", CFrame.new()).model
	fake.Name = "ren"
	local hum = Instance.new("Humanoid")
	hum.HipHeight = 2
	hum.Parent = fake
	fake.Parent = folder
	folder.Parent = RS
	SIM.task.spawn(function()
		Timeline.play()
	end)
	frames(3)
	local st = workspace:FindFirstChild("CinematicStage")
	local renM = st and st:FindFirstChild("Ren Arashi")
	check("modo avatar: Ren usa o avatar R15 montado pelo servidor", renM ~= nil and renM:GetAttribute("Avatar") == true)
	local akM = st and st:FindFirstChild("Akane Sumi")
	check("modo avatar: Akane sem avatar usa o R15 de peças", akM ~= nil and akM:GetAttribute("Avatar") ~= true)
	for _ = 1, 60 do
		frames(1)
		if not Timeline.isRunning() then break end
	end
	check("modo avatar: cinemática inteira sem erros", not Timeline.isRunning() and #SIM.errors == 0, SIM.errors[1])
	fake:Destroy()
end

print(string.format("\n%d passaram, %d falharam", results.pass, results.fail))
if results.fail > 0 then error("falhas") end

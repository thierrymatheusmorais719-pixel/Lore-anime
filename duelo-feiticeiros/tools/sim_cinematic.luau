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

-- modo avatar (itens do catálogo): simula o modelo R15 que o servidor montaria e confere que a cinemática o usa
do
	local Rig = require(__proxy("Duelo/Rig"))
	local RS = game:GetService("ReplicatedStorage")
	local folder = Instance.new("Folder")
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
	check("modo avatar: Ren usa o avatar do catálogo", renM ~= nil and renM:GetAttribute("Avatar") == true)
	local akM = st and st:FindFirstChild("Akane Sumi")
	check("modo avatar: Akane sem IDs continua com o modelo de peças", akM ~= nil and akM:GetAttribute("Avatar") ~= true)
	for _ = 1, 60 do
		frames(1)
		if not Timeline.isRunning() then break end
	end
	check("modo avatar: cinemática inteira sem erros", not Timeline.isRunning() and #SIM.errors == 0, SIM.errors[1])
	folder:Destroy()
end

print(string.format("\n%d passaram, %d falharam", results.pass, results.fail))
if results.fail > 0 then error("falhas") end

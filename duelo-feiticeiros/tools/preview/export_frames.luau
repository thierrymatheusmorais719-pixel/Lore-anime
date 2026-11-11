-- Exporta a cinemática quadro a quadro (geometria REAL dos módulos, rodando no simulador) para a prévia
-- em vídeo (tools/preview/render.html + shoot.js). O simulador não tem física de juntas nem tweens com
-- tempo, então aqui: (1) os tweens são interpolados de verdade e (2) as juntas Motor6D/Weld são resolvidas
-- (Part1 = Part0 · C0 · Transform · C1⁻¹). Partículas não aparecem na prévia.
local FPS = tonumber(SIM_FPS) or 12

-- tweens com tempo (linear com suavização simples)
local active = {}
game:GetService("TweenService").Create = function(_, inst, info, goal)
	local t = { Completed = SIM.Signal() }
	function t.Play()
		local from = {}
		for k in pairs(goal) do
			from[k] = inst[k]
		end
		table.insert(active, { inst = inst, from = from, goal = goal, t0 = SIM.now, dur = math.max(info[1] or 0.25, 1e-3), tw = t })
	end
	function t.Cancel()
		for i, a in ipairs(active) do
			if a.tw == t then
				table.remove(active, i)
				break
			end
		end
	end
	return t
end
local function stepTweens()
	for i = #active, 1, -1 do
		local a = active[i]
		local k = math.clamp((SIM.now - a.t0) / a.dur, 0, 1)
		local e = 1 - (1 - k) * (1 - k)
		for key, g in pairs(a.goal) do
			local f = a.from[key]
			if type(g) == "number" and type(f) == "number" then
				a.inst[key] = f + (g - f) * e
			elseif type(f) == "table" and f.Lerp then
				a.inst[key] = f:Lerp(g, e)
			elseif k >= 1 then
				a.inst[key] = g
			end
		end
		if k >= 1 then
			table.remove(active, i)
		end
	end
end
table.insert(SIM.heartbeat, function()
	pcall(stepTweens)
end)

__modules["Server/Main"](__proxy("Server/Main"))
SIM.run(0.2)

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
local hrp = Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.Transparency = 1
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

local function num(x)
	return string.format("%.2f", x)
end
local function partJson(p, cf)
	local shape = p.Shape and p.Shape.Name or "Block"
	local col = p.Color or Color3.new(0.6, 0.6, 0.6)
	local r = cf.r
	return string.format('{"s":"%s","z":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s],"c":[%d,%d,%d],"m":"%s","t":%s}', shape, num(p.Size.X), num(p.Size.Y), num(p.Size.Z),
		num(cf.p.X), num(cf.p.Y), num(cf.p.Z), table.concat({ string.format("%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f", r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]) }),
		math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5), p.Material and p.Material.Name or "Plastic", num(p.Transparency or 0))
end

-- cidade (uma vez)
do
	local out = {}
	for _, d in ipairs(workspace:FindFirstChild("City"):GetDescendants()) do
		if d:IsA("BasePart") and (d.Transparency or 0) < 1 then
			table.insert(out, partJson(d, d.CFrame))
		end
	end
	print("CITY [" .. table.concat(out, ",") .. "]")
end

-- resolve juntas do modelo a partir da raiz ancorada
local function solve(model)
	local cfs = {}
	local root = model:FindFirstChild("HumanoidRootPart")
	cfs[root] = root.CFrame
	local joints = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d.ClassName == "Motor6D" or d.ClassName == "Weld" then
			table.insert(joints, d)
		end
	end
	local changed = true
	while changed do
		changed = false
		for _, j in ipairs(joints) do
			if j.Part0 and j.Part1 and cfs[j.Part0] and not cfs[j.Part1] then
				local tr = (j.ClassName == "Motor6D" and j.Transform) or CFrame.new()
				cfs[j.Part1] = cfs[j.Part0] * j.C0 * tr * (j.C1 or CFrame.new()):Inverse()
				changed = true
			end
		end
	end
	return cfs
end

-- como no Roblox: as peças seguem as juntas (assim a câmera que segue a cabeça mira no lugar certo)
table.insert(SIM.heartbeat, function()
	local stage = workspace:FindFirstChild("CinematicStage")
	if stage then
		for _, m in ipairs(stage:GetChildren()) do
			for part, cf in pairs(solve(m)) do
				if part.Name ~= "HumanoidRootPart" then
					rawset(part, "__solved", true)
					part.CFrame = cf
				end
			end
		end
	end
end)

local function cc(name)
	local e = game:GetService("Lighting"):FindFirstChild(name)
	if not e then
		return "null"
	end
	local t = e.TintColor or Color3.new(1, 1, 1)
	return string.format('{"sat":%s,"con":%s,"bri":%s,"tint":[%d,%d,%d]}', num(e.Saturation or 0), num(e.Contrast or 0), num(e.Brightness or 0),
		math.floor(t.R * 255), math.floor(t.G * 255), math.floor(t.B * 255))
end
local function esc(s)
	return (tostring(s or ""):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", " "))
end
local function uiJson()
	local g = pg:FindFirstChild("Cinematic")
	if not g then
		return "null"
	end
	local function tr(n)
		local x = g:FindFirstChild(n)
		return x and (x.BackgroundTransparency or 1) or 1
	end
	local function txt(n)
		local x = g:FindFirstChild(n)
		if not x then
			return '""', 1
		end
		return '"' .. esc(x.Text) .. '"', x.TextTransparency or 0
	end
	local sub, subT = txt("Subtitle")
	local tech, techT = txt("Technique")
	local tsub = txt("TechniqueSub")
	local st = g:FindFirstChild("Technique") and g.Technique:FindFirstChild("Stroke")
	local stc = st and st.Color or Color3.new(1, 1, 1)
	local flash = g:FindFirstChild("Flash")
	local fc = flash and flash.BackgroundColor3 or Color3.new(1, 1, 1)
	local sl = g:FindFirstChild("SpeedLines")
	local slc = Color3.new(1, 1, 1)
	if sl then
		for _, l in ipairs(sl:GetChildren()) do
			slc = l.BackgroundColor3 or slc
			break
		end
	end
	local endT = g:FindFirstChild("EndTitle")
	return string.format('{"fade":%s,"flash":%s,"flashC":[%d,%d,%d],"sub":%s,"subT":%s,"tech":%s,"techT":%s,"techSub":%s,"techC":[%d,%d,%d],"lines":%s,"linesC":[%d,%d,%d],"bars":%s,"end":%s,"endSub":"%s"}',
		num(tr("Fade")), num(tr("Flash")), math.floor(fc.R * 255), math.floor(fc.G * 255), math.floor(fc.B * 255), sub, num(subT), tech, num(techT), tsub,
		math.floor(stc.R * 255), math.floor(stc.G * 255), math.floor(stc.B * 255), (sl and sl.Visible) and "true" or "false",
		math.floor(slc.R * 255), math.floor(slc.G * 255), math.floor(slc.B * 255), g:FindFirstChild("BarTop") and "true" or "false",
		endT and ('"' .. esc(endT.Text) .. '"') or "null", g:FindFirstChild("EndSub") and esc(g.EndSub.Text) or "")
end

local function frame(i)
	local out = {}
	local stage = workspace:FindFirstChild("CinematicStage")
	if stage then
		for _, m in ipairs(stage:GetChildren()) do
			local cfs = solve(m)
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") and (d.Transparency or 0) < 1 and d.Name ~= "HumanoidRootPart" then
					table.insert(out, partJson(d, cfs[d] or d.CFrame))
				end
			end
		end
	end
	local fx = workspace:FindFirstChild("CinematicFx")
	if fx then
		for _, d in ipairs(fx:GetDescendants()) do
			if d:IsA("BasePart") and (d.Transparency or 0) < 0.98 then
				table.insert(out, partJson(d, d.CFrame))
			end
		end
	end
	local c = cam.CFrame
	local look = c.p + c.LookVector * 10
	print(string.format('FRAME {"i":%d,"cam":[%s,%s,%s],"look":[%s,%s,%s],"up":[%s,%s,%s],"fov":%s,"impact":%s,"tone":%s,"ui":%s,"parts":[%s]}', i,
		num(c.p.X), num(c.p.Y), num(c.p.Z), num(look.X), num(look.Y), num(look.Z), num(c.UpVector.X), num(c.UpVector.Y), num(c.UpVector.Z), num(cam.FieldOfView or 70),
		cc("ImpactFrame"), cc("WorldTone"), uiJson(), table.concat(out, ",")))
end

SIM.task.spawn(function()
	__modules["Client/Main"](__proxy("Client/Main"))
end)
local Timeline = require(__proxy("Duelo/Timeline"))
local i, dt = 0, 1 / 60
local per = math.floor(60 / FPS + 0.5)
local started = false
for n = 1, 60 * 75 do
	rs.RenderStepped:Fire(dt)
	SIM.run(dt, dt)
	if Timeline.isRunning() then
		started = true
	end
	if started and n % per == 0 then
		i += 1
		frame(i)
	end
	if started and not Timeline.isRunning() then
		-- alguns quadros do cartão final
		for _ = 1, FPS * 2 do
			for _ = 1, per do
				rs.RenderStepped:Fire(dt)
				SIM.run(dt, dt)
			end
			i += 1
			frame(i)
		end
		break
	end
end
print(string.format("INFO quadros: %d, erros: %d", i, #SIM.errors))
for _, e in ipairs(SIM.errors) do
	print("INFO " .. e)
end

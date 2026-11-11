-- O ROTEIRO da luta (~45 s), tomada por tomada. Personagens originais: Ren Arashi (tempestade, ciano) e
-- Akane Sumi (tinta carmesim). Tudo local no cliente: personagens, efeitos e câmera.
--   1. Cidade à noite, a câmera desce até o telhado      5. Akane: Traço Carmesim (cortes partem um prédio)
--   2. Os dois se encaram, falas                          6. Ren: Lança do Trovão
--   3. Choque no meio do telhado (quadro de impacto)      7. Técnicas de arena ao mesmo tempo (cúpulas)
--   4. Troca de golpes em órbita, chute                   8. Golpe final, explosão, cartão "continua..."

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local City = require(script.Parent.City)
local Rig = require(script.Parent.Rig)
local Vfx = require(script.Parent.Vfx)
local Shot = require(script.Parent.Shot)
local Ui = require(script.Parent.Ui)

local Timeline = {}

local V = Vector3.new
local CYAN = Rig.Fighters.ren.energy
local RED = Rig.Fighters.akane.energy
local PURPLE = Color3.fromRGB(170, 90, 255)

-- branco puxado para a cor (aros do choque)
local function WHITE_or(c: Color3): Color3
	return Color3.new(1, 1, 1):Lerp(c, 0.4)
end

Timeline.Length = 45
Timeline.beats = {} -- (testes) nomes das tomadas já tocadas

local running = false
local skipped = false

local function wait(t: number)
	local stop = os.clock() + t
	while os.clock() < stop and not skipped do
		task.wait()
	end
end

local function beat(name: string)
	table.insert(Timeline.beats, name)
end

local function move(rig, to: Vector3, time: number, lookAt: Vector3?, style: Enum.EasingStyle?)
	local pos = to + V(0, rig.hipH, 0)
	local goal = lookAt and CFrame.lookAt(pos, V(lookAt.X, pos.Y, lookAt.Z)) or CFrame.new(pos) * (rig.root.CFrame - rig.root.CFrame.Position)
	local tw = TweenService:Create(rig.root, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal })
	tw:Play()
	return tw
end

local function feet(rig): Vector3
	return rig.root.Position - V(0, rig.hipH, 0)
end

local function part(rig, name: string): BasePart
	return rig.model:FindFirstChild(name) :: BasePart
end

-- Toca a cinemática. onEnd é chamado no fim (ou ao pular).
function Timeline.play(onEnd: (() -> ())?)
	if running then
		return false
	end
	running, skipped = true, false
	table.clear(Timeline.beats)
	City.lighting()
	local C = City.ArenaCenter
	local stage = Instance.new("Folder")
	stage.Name = "CinematicStage"
	stage.Parent = workspace
	local ren = Rig.build("ren", CFrame.new(C + V(-16, 0, 0)))
	local akane = Rig.build("akane", CFrame.new(C + V(16, 0, 0)))
	ren.model.Parent = stage
	akane.model.Parent = stage
	Rig.place(ren, C + V(-16, 0, 0), C)
	Rig.place(akane, C + V(16, 0, 0), C)
	local rigs = { ren, akane }
	local t0 = os.clock()
	local stepConn = RunService.RenderStepped:Connect(function(dt)
		for _, r in ipairs(rigs) do
			Rig.step(r, dt, os.clock() - t0)
		end
	end)
	local g = Ui.mount()
	local skipBtn = g:FindFirstChild("Skip") :: TextButton
	skipBtn.Activated:Connect(function()
		skipped = true
	end)
	Shot.start()

	local function finish()
		stepConn:Disconnect()
		Shot.stop()
		Vfx.cleanup()
		stage:Destroy()
		running = false
		if onEnd then
			onEnd()
		end
	end

	task.spawn(function()
		-- 1. CIDADE: a câmera desce entre os prédios até o telhado ------------------------------------------
		beat("cidade")
		Shot.move(C + V(-160, 150, 220), C + V(0, 40, 0), C + V(-40, 14, 46), C + V(0, 4, 0), 6, 60, 48)
		Ui.fadeIn(1.5)
		Ui.subtitle(nil, nil, "Distrito Velho — 00:17", 3)
		wait(6)
		-- 2. ENCARADA ----------------------------------------------------------------------------------------
		beat("encarada")
		Rig.pose(ren, "idle")
		Rig.pose(akane, "idle")
		Shot.follow(part(ren, "Head"), V(4, 0.4, -5), V(0, -0.1, 0), 30)
		Ui.subtitle("Ren", CYAN, "Então foi você que acordou a cidade inteira.", 2.6)
		wait(3)
		Shot.follow(part(akane, "Head"), V(-4, 0.3, 5), V(0, -0.1, 0), 30)
		Ui.subtitle("Akane", RED, "Eu só vim buscar o que é meu. Saia do caminho.", 2.6)
		wait(3)
		Rig.pose(ren, "guard")
		Rig.pose(akane, "guard")
		Shot.move(C + V(0, 2.5, 34), C + V(0, 4, 0), C + V(0, 1.5, 24), C + V(0, 4, 0), 2, 40, 34)
		Vfx.emit(C + V(0, 1, 0), { tex = "rbxasset://textures/particles/smoke_main.dds", c0 = Color3.fromRGB(150, 150, 170), c1 = Color3.fromRGB(90, 90, 110), glow = 0,
			size = NumberSequence.new(2, 6), transparency = NumberSequence.new(0.6, 1), speed = { 6, 12 }, lifeR = { 1, 2 } }, 18)
		wait(2)
		-- 3. CHOQUE ------------------------------------------------------------------------------------------
		beat("choque")
		Rig.pose(ren, "dash", false, 20)
		Rig.pose(akane, "dash", false, 20)
		Ui.speedLines(true)
		Shot.cut(C + V(0, 0.8, 16), C + V(0, 4, 0), 62)
		move(ren, C + V(-2.2, 0, 0), 0.35, C, Enum.EasingStyle.Quint)
		move(akane, C + V(2.2, 0, 0), 0.35, C, Enum.EasingStyle.Quint)
		wait(0.33)
		Rig.pose(ren, "punch", true)
		Rig.pose(akane, "punchL", true)
		Vfx.impactFrame(Color3.fromRGB(255, 120, 140), 0.12)
		Ui.flash(0.25)
		Vfx.impact(C + V(0, 4.5, 0), PURPLE, 2.4)
		Vfx.shock(C + V(0, 0.4, 0), 40, WHITE_or(PURPLE), 0.6)
		Vfx.debris(C + V(0, 1, 0), Color3.fromRGB(80, 80, 90), 18, 40)
		Shot.shake(1.6, 0.6)
		wait(0.15)
		Ui.speedLines(false)
		wait(0.9)
		-- 4. TROCA DE GOLPES (câmera girando em volta) -----------------------------------------------------
		beat("troca")
		Shot.orbit(C + V(0, 4, 0), 14, math.rad(70), math.rad(200), 3, 4.2, 48)
		for k = 1, 8 do
			local renHits = k % 2 == 1
			local hitter = renHits and ren or akane
			local other = renHits and akane or ren
			Rig.pose(hitter, (k % 4 < 2) and "punch" or "punchL", true)
			Rig.pose(other, "guard", false, 25)
			local at = (feet(ren) + feet(akane)) / 2 + V(0, 4.5, 0)
			Vfx.impact(at, renHits and CYAN or RED, 1)
			if k % 3 == 0 then
				Vfx.impactFrame(renHits and CYAN or RED, 0.07)
			end
			Shot.shake(0.5, 0.2)
			wait(0.42)
		end
		-- chute de Ren: Akane voa até a beira do telhado
		Rig.pose(ren, "kick", true)
		Rig.pose(akane, "hurt", true)
		Vfx.impactFrame(CYAN, 0.12)
		Ui.flash(0.2)
		Vfx.impact(feet(akane) + V(0, 4, 0), CYAN, 2)
		Shot.shake(1.2, 0.5)
		Shot.cut(C + V(-6, 3, 20), C + V(18, 3, 0), 46)
		move(akane, C + V(30, 0, 4), 0.8, feet(ren), Enum.EasingStyle.Quint)
		wait(1.4)
		-- 5. TRAÇO CARMESIM (Akane) ---------------------------------------------------------------------------
		beat("traco_carmesim")
		Rig.pose(akane, "guard")
		Rig.pose(ren, "guard")
		Shot.follow(part(akane, "Head"), V(-5, 1, 4), V(0, -0.5, 0), 34)
		Ui.subtitle("Akane", RED, "Você vai precisar de mais que vento.", 2)
		wait(2)
		Rig.pose(akane, "slash", true)
		Ui.technique("TRAÇO CARMESIM", "Akane Sumi — Técnica de Tinta", RED, 1.6)
		Vfx.impactFrame(RED, 0.1)
		Shot.cut(C + V(10, 6, 30), C + V(0, 6, 0), 55)
		local from = feet(akane) + V(0, 4, 0)
		for k = 1, 6 do
			local dir = (feet(ren) - feet(akane)) * V(1, 0, 1)
			dir = (CFrame.Angles(0, (k - 3.5) * 0.12, 0) * dir.Unit)
			Vfx.inkSlash(from + V(0, (k % 3) * 1.4, 0), dir, 16, RED, 0.5, (k % 2 == 0) and 0.5 or -0.5)
			wait(0.12)
		end
		-- os cortes passam por Ren (que pula) e partem o topo de um prédio atrás dele
		Rig.pose(ren, "float")
		move(ren, feet(ren) + V(-4, 9, 0), 0.4, feet(akane))
		local cutAt = C + V(-75, 8, -8)
		Vfx.cutChunk(cutAt + V(0, 6, 0), V(26, 12, 28), Color3.fromRGB(64, 64, 76), V(-1, 0, 0))
		Shot.move(C + V(-30, 20, 40), cutAt, C + V(-40, 16, 34), cutAt + V(-6, -4, 0), 2.2, 50, 44)
		Shot.shake(0.8, 1)
		wait(2.4)
		-- 6. LANÇA DO TROVÃO (Ren) -------------------------------------------------------------------------
		beat("lanca_do_trovao")
		move(ren, C + V(-12, 0, 0), 0.5, feet(akane))
		Rig.pose(ren, "castUp")
		Shot.follow(part(ren, "RightHand"), V(3, -2, -6), V(0, -1, 0), 50)
		Vfx.orb(part(ren, "RightHand"), CYAN, 3.2, 1.6)
		for _ = 1, 4 do
			Vfx.lightning(part(ren, "RightHand").Position + V(math.random(-12, 12), 18, math.random(-12, 12)), part(ren, "RightHand").Position, CYAN, 0.25, 0.25)
			wait(0.3)
		end
		Ui.technique("LANÇA DO TROVÃO", "Ren Arashi — Técnica da Tempestade", CYAN, 1.4)
		Rig.pose(ren, "castPoint", true)
		local hand = part(ren, "RightHand").Position
		local target = feet(akane) + V(0, 4, 0)
		Shot.cut(hand + V(-3, 2, 6), target, 58)
		Vfx.beam(hand, target, CYAN, 2.4, 0.9)
		Vfx.lightning(hand, target, CYAN, 0.5, 0.4)
		Vfx.impactFrame(CYAN, 0.12)
		Ui.flash(0.3, Color3.fromRGB(200, 250, 255))
		wait(0.15)
		Rig.pose(akane, "hurt", true)
		Vfx.impact(target, CYAN, 3)
		Vfx.debris(feet(akane), Color3.fromRGB(80, 80, 90), 24, 50)
		Shot.shake(2, 0.8)
		Shot.cut(C + V(34, 10, 26), target, 50)
		wait(1.6)
		-- 7. TÉCNICAS DE ARENA AO MESMO TEMPO -------------------------------------------------------------
		beat("arenas")
		Rig.pose(akane, "guard")
		move(akane, C + V(14, 0, 0), 0.6, C)
		move(ren, C + V(-14, 0, 0), 0.6, C)
		wait(0.6)
		Rig.pose(ren, "handSign")
		Rig.pose(akane, "handSign")
		Shot.follow(part(ren, "Head"), V(2.5, 0, -4.5), V(0, -0.6, 0), 32)
		Ui.subtitle("Ren", CYAN, "Expansão de técnica...", 1.4)
		wait(1.4)
		Shot.follow(part(akane, "Head"), V(-2.5, 0, 4.5), V(0, -0.6, 0), 32)
		Ui.subtitle("Akane", RED, "...expansão de técnica.", 1.4)
		wait(1.4)
		Shot.move(C + V(0, 30, 70), C, C + V(0, 50, 110), C, 4, 55, 65)
		Vfx.dome(feet(ren) + V(0, 4, 0), CYAN, 40, 2.2, 6.5)
		Vfx.dome(feet(akane) + V(0, 4, 0), RED, 40, 2.2, 6.5)
		Ui.technique("OLHO DA TEMPESTADE", "Ren Arashi", CYAN, 1.3)
		Vfx.worldTone(Color3.fromRGB(150, 210, 255), -0.4, 0.3)
		Shot.shake(0.8, 1.5)
		wait(1.6)
		Ui.technique("PERGAMINHO SEM FIM", "Akane Sumi", RED, 1.3)
		Vfx.worldTone(Color3.fromRGB(255, 170, 170), -0.8, 0.6)
		wait(1.2)
		-- as duas arenas se empurram: quadros alternando ciano e vermelho
		for k = 1, 8 do
			Vfx.impactFrame(k % 2 == 0 and CYAN or RED, 0.09)
			Vfx.lightning(C + V(0, 30, 0), C + V(math.random(-20, 20), 0, math.random(-20, 20)), k % 2 == 0 and CYAN or RED, 0.6, 0.2)
			Shot.shake(1, 0.2)
			wait(0.16)
		end
		Vfx.clearWorld()
		-- 8. GOLPE FINAL -------------------------------------------------------------------------------------
		beat("golpe_final")
		Rig.pose(ren, "castPoint")
		Rig.pose(akane, "castPoint")
		Shot.orbit(C + V(0, 4, 0), 22, math.rad(-80), math.rad(-100), 2, 1.8, 46)
		Vfx.orb(part(ren, "RightHand"), CYAN, 4, 2)
		Vfx.orb(part(akane, "RightHand"), RED, 4, 2)
		Ui.subtitle("Ren", CYAN, "Acabou!", 1)
		wait(1)
		Ui.subtitle("Akane", RED, "Ainda não!", 1)
		wait(1)
		Rig.pose(ren, "dash", false, 20)
		Rig.pose(akane, "dash", false, 20)
		Ui.speedLines(true, PURPLE)
		Shot.cut(C + V(0, 1, 12), C + V(0, 4, 0), 70)
		move(ren, C + V(-1.5, 0, 0), 0.3, C, Enum.EasingStyle.Quint)
		move(akane, C + V(1.5, 0, 0), 0.3, C, Enum.EasingStyle.Quint)
		wait(0.3)
		Rig.pose(ren, "punch", true)
		Rig.pose(akane, "punchL", true)
		Vfx.beam(C + V(0, 4.5, -60), C + V(0, 4.5, 60), PURPLE, 6, 1.2)
		Vfx.dome(C + V(0, 4, 0), PURPLE, 70, 0.8, 2.2, Enum.Material.Neon)
		Ui.flash(1.6)
		Shot.shake(3, 1.5)
		Ui.speedLines(false)
		wait(1.2)
		Vfx.debris(C + V(0, 2, 0), Color3.fromRGB(80, 80, 90), 40, 70)
		Shot.move(C + V(0, 60, 120), C, C + V(0, 140, 260), C, 3.5, 55, 60)
		wait(3)
		Ui.fadeOut(1.2)
		wait(1.4)
		beat("fim")
		finish()
	end)
	return true
end

function Timeline.isRunning(): boolean
	return running
end

function Timeline.skip()
	skipped = true
end

return Timeline

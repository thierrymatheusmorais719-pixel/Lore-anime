--!strict
-- CutscenePlayer (ModuleScript, lado do cliente)
-- Reproduz um clip exportado por tools/blender/roblox_cutscene_export.py:
--   * toca as animações de todos os rigs no mesmo frame
--   * conduz a câmera frame a frame a partir dos dados do Blender
--   * dispara os eventos (VFX:/FACE:/SFX:/SHAKE:) nos tempos certos
--
-- Uso (LocalScript):
--   local CutscenePlayer = require(ReplicatedStorage.Cutscene.CutscenePlayer)
--   local data = require(ReplicatedStorage.Cutscene.Data["02_hollow_purple__CutsceneData"])
--   CutscenePlayer.play(data, {
--       origin = workspace.Arena.SceneOrigin.CFrame,
--       rigs = { GOJO_RIG = workspace.Gojo, SUKUNA_RIG = workspace.Sukuna },
--       animations = { GOJO_RIG = "rbxassetid://000", SUKUNA_RIG = "rbxassetid://000" },
--       onEvent = function(name) print("evento", name) end,
--   })
--
-- Requisitos dos modelos: HumanoidRootPart ancorado, Animator dentro do
-- Humanoid (ou AnimationController), Pivot do modelo no chão entre os pés.

local RunService = game:GetService("RunService")

export type ClipData = {
	name: string,
	fps: number,
	length: number,
	rigs: { [string]: { number } },
	events: { { t: number, name: string } },
	camera: { { number } },
}

export type PlayOptions = {
	origin: CFrame?,
	rigs: { [string]: Model },
	animations: { [string]: string },
	onEvent: ((name: string) -> ())?,
	restoreCamera: boolean?,
}

local CutscenePlayer = {}

local function rowToCFrame(r: { number }): CFrame
	return CFrame.new(r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12])
end

local function getAnimator(model: Model): Animator
	local holder: Instance? = model:FindFirstChildOfClass("Humanoid")
		or model:FindFirstChildOfClass("AnimationController")
	assert(holder, `{model.Name}: sem Humanoid/AnimationController`)
	local animator = holder:FindFirstChildOfClass("Animator")
	if not animator then
		local created = Instance.new("Animator")
		created.Parent = holder
		animator = created
	end
	return animator :: Animator
end

-- Pré-carrega as animações (chame durante um ecrã de loading para evitar atraso no 1º frame)
function CutscenePlayer.preload(data: ClipData, opts: PlayOptions): { [string]: AnimationTrack }
	local tracks: { [string]: AnimationTrack } = {}
	for rigName, model in opts.rigs do
		local id = opts.animations[rigName]
		if id then
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local track = getAnimator(model):LoadAnimation(anim)
			track.Priority = Enum.AnimationPriority.Action4
			track.Looped = false
			tracks[rigName] = track
		end
	end
	return tracks
end

function CutscenePlayer.play(
	data: ClipData,
	opts: PlayOptions,
	preloaded: { [string]: AnimationTrack }?
): { [string]: AnimationTrack }
	local origin = opts.origin or CFrame.identity
	local camera = workspace.CurrentCamera
	local tracks = preloaded or CutscenePlayer.preload(data, opts)

	-- Posiciona os rigs exatamente como no Blender
	for rigName, model in opts.rigs do
		local row = data.rigs[rigName]
		if row then
			model:PivotTo(origin * rowToCFrame(row))
		end
	end

	local oldType, oldFov = camera.CameraType, camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable

	-- Relógio mestre = primeira track (mantém câmera e corpo no mesmo frame)
	local master: AnimationTrack? = nil
	for _, track in tracks do
		track:Play(0, 1, 1) -- fadeTime 0: sem blend no início do corte
		master = master or track
	end

	local startClock = os.clock()
	local nextEvent = 1
	local frames = data.camera
	local done = Instance.new("BindableEvent")

	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = if master and master.IsPlaying then master.TimePosition else os.clock() - startClock

		-- Câmera: interpola entre frames, exceto quando o frame seguinte é um corte
		local f = t * data.fps + 1
		local i = math.clamp(math.floor(f), 1, #frames)
		local j = math.min(i + 1, #frames)
		local a, b = frames[i], frames[j]
		local alpha = if b[14] == 1 then 0 else f - i
		local cf = rowToCFrame(a):Lerp(rowToCFrame(b), alpha)
		camera.CFrame = origin * cf
		camera.FieldOfView = a[13] + (b[13] - a[13]) * alpha

		-- Eventos
		while nextEvent <= #data.events and data.events[nextEvent].t <= t do
			if opts.onEvent then
				task.spawn(opts.onEvent, data.events[nextEvent].name)
			end
			nextEvent += 1
		end

		if t >= data.length - 1 / data.fps then
			-- Congela o último pose (uma track não-looped que termina volta ao idle)
			for _, track in tracks do
				track:AdjustSpeed(0)
			end
			conn:Disconnect()
			if opts.restoreCamera ~= false then
				camera.CameraType = oldType
				camera.FieldOfView = oldFov
			end
			done:Fire()
		end
	end)

	done.Event:Wait()
	done:Destroy()
	return tracks -- chame track:Stop() quando quiser libertar os personagens
end

return CutscenePlayer

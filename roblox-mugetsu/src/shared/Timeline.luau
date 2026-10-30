--!strict
-- Linha do tempo da cutscene (dados puros, sem dependência de Roblox para poder ser testada).
-- Coreografia baseada no vídeo de referência (Ichigo -> Mugetsu):
--   costas/espada  -> pose frontal -> close dos olhos -> pilar de luz azul -> máscara
--   -> flash branco -> tentáculos negros -> emerge Mugetsu -> close do olho -> blackout.
-- Todos os tempos são em segundos desde o início da cutscene (relógio do servidor).

export type Phase = {
	name: string,
	start: number,
	finish: number,
}

export type Shot = {
	t: number, -- início do plano
	duration: number,
	-- offsets em espaço do personagem (X direita, Y cima, -Z frente do personagem)
	from: { pos: Vector3, look: Vector3, fov: number },
	to: { pos: Vector3, look: Vector3, fov: number },
	ease: string, -- "Linear" | "Sine" | "Quad" | "Expo" | "Orbit"
	orbit: { degrees: number, radius: number, height: number }?,
}

export type Event = {
	t: number,
	name: string,
	arg: any?,
}

local V = Vector3.new

local Timeline = {}

Timeline.Duration = 30

Timeline.Phases = {
	{ name = "Activation", start = 0, finish = 5 },
	{ name = "Concentration", start = 5, finish = 12 },
	{ name = "Transformation", start = 12, finish = 19 },
	{ name = "Release", start = 19, finish = 26 },
	{ name = "Outro", start = 26, finish = 30 },
} :: { Phase }

-- Planos de câmera. "look" e "pos" são relativos ao HumanoidRootPart (CFrame do personagem).
-- Referências R15 relativas ao HRP: pés -3, quadril 0, peito +1.0, olhos +2.4, topo da cabeça +2.9.
Timeline.Shots = {
	-- FASE 1: aproximação lenta por trás, espada baixa
	{ t = 0, duration = 2.6, ease = "Sine",
		from = { pos = V(2.5, 1.2, 14), look = V(0, 0.6, 0), fov = 55 },
		to = { pos = V(1.2, 1.0, 8.5), look = V(0, 1.0, 0), fov = 48 } },
	-- corte para a lâmina (close na espada, que desce da mão direita para frente/baixo)
	{ t = 2.6, duration = 2.4, ease = "Quad",
		from = { pos = V(4.2, -0.4, -5.2), look = V(1.6, -1.6, -0.8), fov = 36 },
		to = { pos = V(3.0, -1.1, -3.6), look = V(1.6, -2.3, -1.0), fov = 30 } },
	-- FASE 2: pose frontal + órbita
	{ t = 5, duration = 4.2, ease = "Orbit",
		from = { pos = V(0, 1.4, -11), look = V(0, 1.0, 0), fov = 52 },
		to = { pos = V(0, 1.4, -11), look = V(0, 1.0, 0), fov = 44 },
		orbit = { degrees = 110, radius = 11, height = 1.4 } },
	-- close dos olhos com DOLLY ZOOM (efeito vertigem): a câmera avança enquanto o FOV abre na mesma
	-- proporção (distância * tan(fov/2) constante) -> o rosto fica do mesmo tamanho e o fundo "estica"
	{ t = 9.2, duration = 2.8, ease = "Sine",
		from = { pos = V(0.4, 2.4, -6.0), look = V(0, 2.35, 0), fov = 22 },
		to = { pos = V(0.2, 2.45, -2.4), look = V(0, 2.4, 0), fov = 52 } },
	-- FASE 3: plano aberto (pilar de energia) com a câmera subindo
	{ t = 12, duration = 3.0, ease = "Quad",
		from = { pos = V(0, -2.0, -17), look = V(0, 6, 0), fov = 70 },
		to = { pos = V(0, -0.5, -13), look = V(0, 8, 0), fov = 62 } },
	-- close da máscara (rosto)
	{ t = 15, duration = 2.0, ease = "Quad",
		from = { pos = V(0.3, 2.5, -2.9), look = V(0, 2.4, 0), fov = 32 },
		to = { pos = V(0, 2.5, -2.1), look = V(0, 2.4, 0), fov = 28 } },
	-- plano de espera durante o flash branco (câmera cai de cima)
	{ t = 17, duration = 2.0, ease = "Sine",
		from = { pos = V(0, 12, -3), look = V(0, 0, 0), fov = 60 },
		to = { pos = V(0, 7, -7), look = V(0, 1, 0), fov = 54 } },
	-- FASE 4: whip rápido para a pose de Mugetsu (impacto em t=19.6)
	{ t = 19, duration = 0.45, ease = "Expo",
		from = { pos = V(9, 0.4, -6), look = V(0, 1.2, 0), fov = 90 },
		to = { pos = V(1.8, 0.6, -9), look = V(0, 1.2, 0), fov = 56 } },
	{ t = 19.45, duration = 3.6, ease = "Sine",
		from = { pos = V(1.8, 0.6, -9), look = V(0, 1.4, 0), fov = 56 },
		to = { pos = V(-2.4, 0.2, -12.5), look = V(0, 1.6, 0), fov = 50 } },
	-- reverso: plano de baixo para cima mostrando o cabelo ao vento
	{ t = 23.05, duration = 2.95, ease = "Sine",
		from = { pos = V(-5, -1.8, -8), look = V(0, 1.6, 0), fov = 58 },
		to = { pos = V(4.5, -1.4, -7), look = V(0, 1.8, 0), fov = 46 } },
	-- OUTRO: close do olho vermelho
	{ t = 26, duration = 4.0, ease = "Quad",
		from = { pos = V(0.6, 2.45, -3.6), look = V(0, 2.4, 0), fov = 34 },
		to = { pos = V(0.2, 2.45, -2.4), look = V(0, 2.4, 0), fov = 28 } },
} :: { Shot }

-- Eventos sincronizados. O servidor e o cliente consomem a mesma lista.
-- Quando existir animação real com KeyframeMarker de mesmo nome, o marker tem prioridade.
Timeline.Events = {
	{ t = 0.0, name = "LockControls" },
	{ t = 0.0, name = "AmbientDuck", arg = 0.25 },
	{ t = 0.2, name = "Anim", arg = "Prepare" },
	{ t = 0.5, name = "Lighting", arg = "Cold" },
	{ t = 1.0, name = "AuraWhispers" },
	{ t = 1.2, name = "TitleCard", arg = "Ichigo" }, -- 黒崎 一護 / FINAL GETSUGA TENSHŌ
	{ t = 2.6, name = "SwordGlint" },
	{ t = 4.7, name = "PauseBeat" },
	{ t = 5.0, name = "Anim", arg = "Concentrate" },
	{ t = 5.0, name = "EnergyGather", arg = 1 },
	{ t = 6.0, name = "Levitate" }, -- pedras sobem e orbitam até o golpe
	{ t = 6.5, name = "GroundShards" },
	{ t = 7.0, name = "PulseLight", arg = 0.5 },
	{ t = 8.0, name = "PulseLight", arg = 0.7 },
	{ t = 9.0, name = "PulseLight", arg = 0.9 },
	{ t = 9.2, name = "EyeReiatsu" },
	{ t = 9.2, name = "SpeedLines", arg = 0.7 },
	{ t = 11.6, name = "PressureWave", arg = 1 },
	{ t = 12.0, name = "Anim", arg = "Transform" },
	{ t = 12.0, name = "BlueSpire" },
	{ t = 12.3, name = "Spiral" }, -- espiral negra/branca dentro do pilar azul (plano aberto)
	{ t = 14.8, name = "MaskForm" },
	{ t = 14.85, name = "SpeedLines", arg = 0.9 },
	{ t = 15.2, name = "ShakeSmall" },
	{ t = 16.6, name = "BeginFade", arg = "White" },
	{ t = 17.0, name = "WhiteOut" },
	{ t = 17.4, name = "MorphSwap" }, -- troca real do modelo (servidor) durante o branco
	{ t = 18.0, name = "BlackTendrils" },
	{ t = 18.7, name = "PauseBeat" },
	{ t = 19.0, name = "Anim", arg = "Release" },
	{ t = 19.0, name = "WhiteOutEnd" },
	{ t = 19.45, name = "SwordSlash" }, -- rastro liga no começo do corte
	{ t = 19.6, name = "ReleaseImpact" }, -- clímax: lâmina termina o corte = anéis, shockwave, tremor
	{ t = 19.6, name = "ImpactSilhouette" }, -- frames de impacto: silhueta branca no preto -> preta no branco
	{ t = 19.6, name = "GroundCracks" },
	{ t = 19.6, name = "DebrisBlast" },
	{ t = 19.75, name = "SpeedLines", arg = 1.2 },
	{ t = 19.9, name = "EnvironmentReact" },
	{ t = 20.8, name = "ImpactFrame" },
	{ t = 22.0, name = "Anim", arg = "FinalPose" },
	{ t = 24.0, name = "PauseBeat" },
	{ t = 25.4, name = "FadeToBlack" },
	{ t = 26.0, name = "Lighting", arg = "Mugetsu" },
	{ t = 27.5, name = "FadeFromBlack" },
	{ t = 27.7, name = "MugetsuTitle" }, -- 無月
	{ t = 29.4, name = "EnableAbility" },
	{ t = 30.0, name = "End" },
} :: { Event }

local function ease(kind: string, a: number): number
	a = math.clamp(a, 0, 1)
	if kind == "Linear" then
		return a
	elseif kind == "Sine" then
		return 0.5 - 0.5 * math.cos(a * math.pi)
	elseif kind == "Quad" then
		return a < 0.5 and 2 * a * a or 1 - (-2 * a + 2) ^ 2 / 2
	elseif kind == "Expo" then
		if a <= 0 then
			return 0
		elseif a >= 1 then
			return 1
		end
		return a < 0.5 and 2 ^ (20 * a - 10) / 2 or (2 - 2 ^ (-20 * a + 10)) / 2
	end
	return 0.5 - 0.5 * math.cos(a * math.pi)
end
Timeline.ease = ease

function Timeline.getShot(t: number): (Shot?, number)
	local current: Shot? = nil
	for _, shot in Timeline.Shots do
		if t >= shot.t then
			current = shot
		end
	end
	if current == nil then
		return nil, 0
	end
	local s = current :: Shot
	local alpha = (t - s.t) / math.max(s.duration, 1e-3)
	return s, math.clamp(alpha, 0, 1)
end

function Timeline.getPhase(t: number): string
	local name = "Outro"
	for _, p in Timeline.Phases do
		if t >= p.start and t < p.finish then
			name = p.name
			break
		end
	end
	return name
end

-- Retorna os eventos com (prev, now] para disparo exatamente uma vez.
function Timeline.eventsBetween(prev: number, now: number): { Event }
	local out = {}
	for _, ev in Timeline.Events do
		if ev.t > prev and ev.t <= now then
			table.insert(out, ev)
		end
	end
	return out
end

-- Validação estrutural: usada nos testes.
function Timeline.validate(): { string }
	local problems = {}
	local lastT = -1
	for i, ev in Timeline.Events do
		if ev.t < lastT then
			table.insert(problems, `evento {i} ({ev.name}) fora de ordem`)
		end
		lastT = ev.t
		if ev.t < 0 or ev.t > Timeline.Duration then
			table.insert(problems, `evento {ev.name} fora da duração`)
		end
	end
	local cursor = 0
	for i, shot in Timeline.Shots do
		if math.abs(shot.t - cursor) > 0.01 and i > 1 then
			table.insert(problems, `plano {i} deixa lacuna/sobreposição ({cursor} -> {shot.t})`)
		end
		cursor = shot.t + shot.duration
	end
	if math.abs(cursor - Timeline.Duration) > 0.01 then
		table.insert(problems, `planos terminam em {cursor}, duração é {Timeline.Duration}`)
	end
	return problems
end

return Timeline

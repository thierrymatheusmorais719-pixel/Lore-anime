-- Biblioteca de animações procedurais para rigs R15.
-- Cada animação: keyframes { t, pose = { Junta = CFrame }, ease } + duration/loop/priority/fade.
-- Ataques são gerados a partir de Config/Combat, então o quadro de impacto coincide com o
-- `windup` usado pela hitbox do servidor (antecipação → impacto → recuperação).
--
-- Convenção de ângulos (graus) em J(pitch, yaw, roll):
--   ombros: pitch+ levanta o braço para frente; yaw+ gira para a esquerda; roll+ abre o braço direito
--   cotovelo: pitch+ dobra; joelho: pitch− dobra; cintura: pitch− inclina para frente
local Combat = require(script.Parent.Parent.Config.Combat)

local rad = math.rad

local function J(pitch: number?, yaw: number?, roll: number?): CFrame
	return CFrame.fromEulerAnglesYXZ(rad(pitch or 0), rad(yaw or 0), rad(roll or 0))
end

-- Junta com deslocamento (usada no Root para agachar/avançar)
local function JP(x: number, y: number, z: number, pitch: number?, yaw: number?, roll: number?): CFrame
	return CFrame.new(x, y, z) * J(pitch, yaw, roll)
end

-- Nomes curtos → Motor6D do R15
local JOINTS = {
	Root = "Root",
	Waist = "Waist",
	Neck = "Neck",
	RS = "RightShoulder",
	RE = "RightElbow",
	RW = "RightWrist",
	LS = "LeftShoulder",
	LE = "LeftElbow",
	LW = "LeftWrist",
	RH = "RightHip",
	RK = "RightKnee",
	LH = "LeftHip",
	LK = "LeftKnee",
}

local function pose(t: { [string]: CFrame }): { [string]: CFrame }
	local out = {}
	for short, cf in t do
		out[JOINTS[short] or short] = cf
	end
	return out
end

local Poses = {}
Poses.Joints = JOINTS

-- Posturas reutilizáveis
local STANCE_LEGS = {
	RH = J(18, 0, 6),
	RK = J(-22),
	LH = J(-12, 0, -6),
	LK = J(-18),
	Root = JP(0, -0.25, 0),
}
local LUNGE_LEGS = {
	RH = J(45, 0, 4),
	RK = J(-35),
	LH = J(-30, 0, -4),
	LK = J(-30),
	Root = JP(0, -0.6, -0.6, -10),
}
local AIR_LEGS = {
	RH = J(50),
	RK = J(-70),
	LH = J(25),
	LK = J(-55),
}

local function merge(...: { [string]: CFrame }): { [string]: CFrame }
	local out = {}
	for _, t in { ... } do
		for k, v in t do
			out[k] = v
		end
	end
	return out
end

-- Constrói ataque: antecipação (até 70% do windup), impacto (windup), seguimento e recuperação.
local function attack(spec, anticipation, strike, follow, legs)
	local w, d = spec.windup, spec.duration
	legs = legs or STANCE_LEGS
	return {
		duration = d + 0.18,
		priority = 3,
		fadeIn = 0.05,
		fadeOut = 0.18,
		markers = { Hit = w },
		keyframes = {
			{ t = 0, pose = pose(merge(legs, anticipation)), ease = "out" },
			{ t = w * 0.7, pose = pose(merge(legs, anticipation)), ease = "inout" },
			{ t = w, pose = pose(merge(legs, strike)), ease = "expo" },
			{ t = w + 0.1, pose = pose(merge(legs, follow)), ease = "out" },
			{ t = d, pose = pose(merge(legs, follow)), ease = "inout" },
		},
	}
end

-- ===================== POSTURAS =====================
Poses.SwordIdle = {
	duration = 2.4,
	loop = true,
	priority = 1,
	fadeIn = 0.2,
	fadeOut = 0.25,
	keyframes = {
		{
			t = 0,
			pose = pose({
				RS = J(28, 18, 12),
				RE = J(25),
				RW = J(-10),
				LS = J(22, -12, -10),
				LE = J(55),
				Waist = J(0, -12),
			}),
			ease = "inout",
		},
		{
			t = 1.2,
			pose = pose({
				RS = J(31, 18, 12),
				RE = J(28),
				RW = J(-10),
				LS = J(24, -12, -10),
				LE = J(58),
				Waist = J(-2, -12),
			}),
			ease = "inout",
		},
		{
			t = 2.4,
			pose = pose({
				RS = J(28, 18, 12),
				RE = J(25),
				RW = J(-10),
				LS = J(22, -12, -10),
				LE = J(55),
				Waist = J(0, -12),
			}),
			ease = "inout",
		},
	},
}
Poses.SwordRun = {
	duration = 1,
	loop = true,
	priority = 1,
	fadeIn = 0.15,
	fadeOut = 0.2,
	keyframes = {
		{ t = 0, pose = pose({ RS = J(-35, -10, 18), RE = J(15), RW = J(-60), Waist = J(-12) }), ease = "linear" },
		{ t = 1, pose = pose({ RS = J(-35, -10, 18), RE = J(15), RW = J(-60), Waist = J(-12) }), ease = "linear" },
	},
}
Poses.Block = {
	duration = 1,
	loop = true,
	priority = 2,
	fadeIn = 0.04,
	fadeOut = 0.12,
	keyframes = {
		{
			t = 0,
			pose = pose(merge(STANCE_LEGS, {
				RS = J(85, 35, 15),
				RE = J(70),
				RW = J(-20),
				LS = J(80, -35, -10),
				LE = J(85),
				Waist = J(-6, -10),
				Neck = J(-8),
			})),
			ease = "out",
		},
		{
			t = 1,
			pose = pose(merge(STANCE_LEGS, {
				RS = J(85, 35, 15),
				RE = J(70),
				RW = J(-20),
				LS = J(80, -35, -10),
				LE = J(85),
				Waist = J(-6, -10),
				Neck = J(-8),
			})),
			ease = "linear",
		},
	},
}
Poses.Draw = {
	duration = 0.45,
	priority = 2,
	fadeIn = 0.05,
	fadeOut = 0.15,
	keyframes = {
		{ t = 0, pose = pose({ RS = J(35, 65, -20), RE = J(75), LS = J(10, 0, -15), LE = J(30) }), ease = "out" },
		{ t = 0.15, pose = pose({ RS = J(35, 65, -20), RE = J(75), LS = J(10, 0, -15), LE = J(30) }), ease = "linear" },
		{ t = 0.3, pose = pose({ RS = J(115, -30, 35), RE = J(5), RW = J(-40) }), ease = "expo" },
		{ t = 0.45, pose = pose({ RS = J(28, 18, 12), RE = J(25) }), ease = "inout" },
	},
}
Poses.Sheathe = {
	duration = 0.55,
	priority = 2,
	fadeIn = 0.08,
	fadeOut = 0.15,
	keyframes = {
		{ t = 0, pose = pose({ RS = J(60, -20, 20), RE = J(20) }), ease = "out" },
		{ t = 0.3, pose = pose({ RS = J(30, 60, -20), RE = J(75), LS = J(10, 0, -15), LE = J(30) }), ease = "inout" },
		{ t = 0.55, pose = pose({}), ease = "inout" },
	},
}
Poses.Charge = {
	duration = 0.8,
	loop = true,
	priority = 2,
	fadeIn = 0.15,
	fadeOut = 0.2,
	keyframes = {
		{
			t = 0,
			pose = pose({
				RS = J(10, 0, 40),
				LS = J(10, 0, -40),
				RE = J(35),
				LE = J(35),
				Waist = J(-10),
				Neck = J(-12),
				RH = J(30, 0, 8),
				RK = J(-50),
				LH = J(30, 0, -8),
				LK = J(-50),
				Root = JP(0, -0.7, 0),
			}),
			ease = "inout",
		},
		{
			t = 0.4,
			pose = pose({
				RS = J(14, 0, 44),
				LS = J(14, 0, -44),
				RE = J(40),
				LE = J(40),
				Waist = J(-6),
				Neck = J(-6),
				RH = J(30, 0, 8),
				RK = J(-50),
				LH = J(30, 0, -8),
				LK = J(-50),
				Root = JP(0, -0.65, 0),
			}),
			ease = "inout",
		},
		{
			t = 0.8,
			pose = pose({
				RS = J(10, 0, 40),
				LS = J(10, 0, -40),
				RE = J(35),
				LE = J(35),
				Waist = J(-10),
				Neck = J(-12),
				RH = J(30, 0, 8),
				RK = J(-50),
				LH = J(30, 0, -8),
				LK = J(-50),
				Root = JP(0, -0.7, 0),
			}),
			ease = "inout",
		},
	},
}
Poses.Dash = {
	duration = 0.3,
	priority = 2,
	fadeIn = 0.03,
	fadeOut = 0.15,
	keyframes = {
		{
			t = 0,
			pose = pose({
				Waist = J(-30),
				Neck = J(15),
				RS = J(-45, 0, 15),
				RE = J(10),
				LS = J(-45, 0, -15),
				LE = J(10),
				RH = J(40),
				RK = J(-60),
				LH = J(-20),
				LK = J(-30),
			}),
			ease = "expo",
		},
		{
			t = 0.3,
			pose = pose({
				Waist = J(-25),
				Neck = J(12),
				RS = J(-40, 0, 15),
				LS = J(-40, 0, -15),
				RH = J(30),
				RK = J(-40),
				LH = J(-10),
				LK = J(-20),
			}),
			ease = "inout",
		},
	},
}
Poses.AirStep = {
	duration = 0.4,
	priority = 2,
	fadeIn = 0.03,
	fadeOut = 0.15,
	keyframes = {
		{
			t = 0,
			pose = pose(merge(AIR_LEGS, { Root = JP(0, 0, 0, -20), RS = J(-30, 0, 30), LS = J(-30, 0, -30) })),
			ease = "expo",
		},
		{ t = 0.4, pose = pose(merge(AIR_LEGS, { Root = JP(0, 0, 0, 0) })), ease = "inout" },
	},
}

-- ===================== COMBO TERRESTRE =====================
local L = Combat.Light
-- 1: corte horizontal (direita → esquerda)
Poses.Slash1 = attack(L[1], {
	RS = J(85, -75, 0),
	RE = J(15),
	RW = J(-80),
	LS = J(30, 20, -10),
	LE = J(60),
	Waist = J(0, -35),
	Neck = J(0, 20),
}, {
	RS = J(85, 60, 0),
	RE = J(5),
	RW = J(-85),
	LS = J(10, 0, -25),
	LE = J(30),
	Waist = J(-5, 30),
	Neck = J(0, -15),
}, {
	RS = J(80, 75, 0),
	RE = J(10),
	RW = J(-80),
	LS = J(5, 0, -25),
	LE = J(25),
	Waist = J(-5, 35),
	Neck = J(0, -20),
})
-- 2: corte reverso (esquerda → direita)
Poses.Slash2 = attack(L[2], {
	RS = J(90, 70, -10),
	RE = J(25),
	RW = J(-80),
	LS = J(20, -10, -20),
	LE = J(40),
	Waist = J(0, 35),
}, {
	RS = J(85, -70, 10),
	RE = J(5),
	RW = J(-85),
	LS = J(20, 20, -20),
	LE = J(40),
	Waist = J(-5, -35),
}, {
	RS = J(80, -85, 10),
	RE = J(10),
	RW = J(-80),
	Waist = J(-5, -40),
})
-- 3: diagonal descendente
Poses.Slash3 = attack(L[3], {
	RS = J(165, -25, 25),
	RE = J(20),
	RW = J(-70),
	LS = J(150, 20, -10),
	LE = J(70),
	Waist = J(10, -20),
	Neck = J(10),
}, {
	RS = J(25, 40, 0),
	RE = J(5),
	RW = J(-80),
	LS = J(20, 10, -20),
	LE = J(40),
	Waist = J(-25, 25),
	Neck = J(-10),
}, {
	RS = J(10, 50, 0),
	RE = J(10),
	RW = J(-75),
	Waist = J(-25, 30),
}, LUNGE_LEGS)
-- 4: estocada
Poses.Slash4 = attack(L[4], {
	RS = J(40, -15, 25),
	RE = J(85),
	RW = J(-60),
	LS = J(70, -30, -10),
	LE = J(20),
	Waist = J(0, -40),
}, {
	RS = J(90, 5, 0),
	RE = J(0),
	RW = J(-90),
	LS = J(-20, 0, -30),
	LE = J(10),
	Waist = J(-10, 25),
}, {
	RS = J(88, 5, 0),
	RE = J(5),
	RW = J(-90),
	LS = J(-20, 0, -30),
	Waist = J(-10, 25),
}, LUNGE_LEGS)
-- 5: finalizador (golpe acima da cabeça com as duas mãos)
Poses.Slash5 = attack(L[5], {
	RS = J(175, 0, 5),
	RE = J(25),
	RW = J(-60),
	LS = J(175, 0, -5),
	LE = J(30),
	Waist = J(15),
	Neck = J(15),
	RH = J(25),
	RK = J(-40),
	LH = J(10),
	LK = J(-30),
	Root = JP(0, 0.2, 0.3),
}, {
	RS = J(15, 15, 0),
	RE = J(5),
	RW = J(-80),
	LS = J(20, -15, 0),
	LE = J(15),
	Waist = J(-30),
	Neck = J(-15),
}, {
	RS = J(5, 15, 0),
	RE = J(10),
	RW = J(-80),
	LS = J(10, -15, 0),
	LE = J(20),
	Waist = J(-30),
	Neck = J(-10),
}, LUNGE_LEGS)

-- ===================== COMBO AÉREO =====================
local A = Combat.Aerial
Poses.Air1 = attack(
	A[1],
	{ RS = J(85, -70, 0), RW = J(-80), Waist = J(0, -30) },
	{ RS = J(85, 65, 0), RW = J(-85), Waist = J(0, 30) },
	{ RS = J(80, 75, 0), RW = J(-80), Waist = J(0, 35) },
	AIR_LEGS
)
Poses.Air2 = attack(
	A[2],
	{ RS = J(90, 70, -10), RW = J(-80), Waist = J(0, 35) },
	{ RS = J(85, -70, 10), RW = J(-85), Waist = J(0, -35) },
	{ RS = J(80, -80, 10), RW = J(-80), Waist = J(0, -40) },
	AIR_LEGS
)
Poses.Air3 = attack(
	A[3],
	{ RS = J(10, -30, 20), RW = J(-80), Waist = J(-15, -20) },
	{ RS = J(165, 20, 0), RW = J(-70), Waist = J(15, 15), Neck = J(15) },
	{ RS = J(170, 25, 0), RW = J(-70), Waist = J(15, 15) },
	AIR_LEGS
)
Poses.Air4 = attack(A[4], {
	RS = J(175, 0, 5),
	RE = J(20),
	RW = J(-60),
	LS = J(175, 0, -5),
	LE = J(25),
	Waist = J(20),
	Root = JP(0, 0, 0, 25),
}, {
	RS = J(0, 0, 0),
	RW = J(-85),
	LS = J(10, 0, 0),
	Waist = J(-35),
	Root = JP(0, 0, 0, -45),
}, {
	RS = J(-5, 0, 0),
	RW = J(-85),
	Waist = J(-30),
	Root = JP(0, 0, 0, -30),
}, AIR_LEGS)

-- ===================== ESPECIAIS =====================
Poses.HeavySlash = attack(Combat.Heavy, {
	RS = J(70, -110, 10),
	RE = J(30),
	RW = J(-80),
	LS = J(60, -80, -10),
	LE = J(70),
	Waist = J(5, -60),
	Neck = J(0, 45),
	RH = J(30, 0, 10),
	RK = J(-45),
	LH = J(-10, 0, -10),
	LK = J(-40),
	Root = JP(0, -0.7, 0.2),
}, {
	RS = J(80, 85, 0),
	RE = J(0),
	RW = J(-85),
	LS = J(60, 60, -10),
	LE = J(40),
	Waist = J(-10, 55),
	Neck = J(0, -30),
}, {
	RS = J(75, 95, 0),
	RE = J(5),
	RW = J(-85),
	LS = J(50, 60, -10),
	Waist = J(-10, 60),
}, LUNGE_LEGS)
Poses.Uppercut = attack(Combat.Launcher, {
	RS = J(-25, -25, 20),
	RE = J(15),
	RW = J(-80),
	Waist = J(-25, -25),
	RH = J(45),
	RK = J(-70),
	LH = J(10),
	LK = J(-60),
	Root = JP(0, -0.9, 0),
}, {
	RS = J(170, 15, 0),
	RE = J(0),
	RW = J(-70),
	Waist = J(15, 15),
	Neck = J(20),
	RH = J(10),
	RK = J(-10),
	LH = J(40),
	LK = J(-60),
	Root = JP(0, 0.3, 0),
}, {
	RS = J(175, 20, 0),
	RW = J(-70),
	Waist = J(15, 15),
	Neck = J(20),
	RH = J(10),
	RK = J(-10),
	LH = J(40),
	LK = J(-60),
	Root = JP(0, 0.3, 0),
}, {})
Poses.Counter = attack(Combat.Counter, {
	RS = J(60, 80, -20),
	RE = J(40),
	RW = J(-60),
	Waist = J(0, 50),
}, {
	RS = J(85, -95, 15),
	RE = J(0),
	RW = J(-90),
	LS = J(30, 40, -30),
	Waist = J(-15, -55),
	Neck = J(0, 30),
}, {
	RS = J(80, -100, 15),
	RW = J(-90),
	Waist = J(-15, -55),
}, LUNGE_LEGS)

-- Execução: postura de saque (pausa dramática) → corte atravessando → pose final.
do
	local e = Combat.Execution
	local w = e.windup
	local kamae = pose(merge(STANCE_LEGS, {
		RS = J(95, 30, -20),
		RE = J(95),
		RW = J(-90),
		LS = J(90, -20, 0),
		LE = J(100),
		Waist = J(-5, -35),
		Neck = J(-5, 30),
		Root = JP(0, -0.8, 0.3),
	}))
	Poses.Execution = {
		duration = e.duration + 0.3,
		priority = 4,
		fadeIn = 0.05,
		fadeOut = 0.25,
		markers = { Hit = w },
		keyframes = {
			{ t = 0, pose = kamae, ease = "out" },
			{ t = w * 0.85, pose = kamae, ease = "linear" },
			{
				t = w,
				pose = pose(merge(LUNGE_LEGS, {
					RS = J(70, -120, 20),
					RE = J(0),
					RW = J(-90),
					LS = J(-30, 0, -40),
					Waist = J(-20, -40),
					Neck = J(0, 20),
					Root = JP(0, -1, -1.2, -15),
				})),
				ease = "expo",
			},
			{
				t = w + 0.35,
				pose = pose(merge(LUNGE_LEGS, {
					RS = J(70, -125, 20),
					RW = J(-90),
					LS = J(-30, 0, -40),
					Waist = J(-20, -40),
					Root = JP(0, -1, -1.2, -15),
				})),
				ease = "linear",
			},
			{
				t = e.duration,
				pose = pose({ RS = J(30, 60, -20), RE = J(70), LS = J(15, 0, -10), Waist = J(0, 10) }),
				ease = "inout",
			},
		},
	}
end

-- ===================== REAÇÕES =====================
local function reaction(duration: number, hit: { [string]: CFrame }, priority: number?)
	return {
		duration = duration,
		priority = priority or 3,
		fadeIn = 0.02,
		fadeOut = 0.2,
		keyframes = {
			{ t = 0, pose = pose({}), ease = "linear" },
			{ t = 0.06, pose = pose(hit), ease = "expo" },
			{ t = duration * 0.6, pose = pose(hit), ease = "inout" },
			{ t = duration, pose = pose({}), ease = "inout" },
		},
	}
end

Poses.Hit1 = reaction(0.45, {
	Waist = J(18, 10),
	Neck = J(20),
	RS = J(20, 0, 25),
	LS = J(20, 0, -25),
	RE = J(30),
	LE = J(30),
	Root = JP(0, 0, 0.3),
})
Poses.Hit2 = reaction(
	0.45,
	{ Waist = J(12, -22, 8), Neck = J(10, -20), RS = J(-10, 0, 35), LS = J(30, 0, -15), Root = JP(0, 0, 0.3) }
)
Poses.Stagger = reaction(0.8, {
	Waist = J(30),
	Neck = J(25),
	RS = J(40, 0, 60),
	LS = J(40, 0, -60),
	RE = J(30),
	LE = J(30),
	RH = J(-20),
	LH = J(30),
	LK = J(-30),
	Root = JP(0, -0.3, 0.6, 10),
})
Poses.Launched = reaction(1.1, {
	Waist = J(35),
	Neck = J(30),
	RS = J(60, 0, 70),
	LS = J(60, 0, -70),
	RH = J(40),
	RK = J(-70),
	LH = J(20),
	LK = J(-50),
	Root = JP(0, 0, 0, 25),
}, 3)
Poses.GuardBreak = reaction(1.0, {
	Waist = J(25),
	Neck = J(25),
	RS = J(160, -20, 30),
	LS = J(150, 20, -30),
	RE = J(20),
	LE = J(20),
	Root = JP(0, -0.2, 0.5),
}, 4)
Poses.Parried = reaction(0.85, {
	Waist = J(20, 20),
	Neck = J(15),
	RS = J(165, -40, 30),
	RE = J(10),
	RW = J(-60),
	LS = J(20, 0, -40),
	Root = JP(0, 0, 0.5),
}, 4)
Poses.ParrySuccess = {
	duration = 0.4,
	priority = 4,
	fadeIn = 0.02,
	fadeOut = 0.15,
	keyframes = {
		{ t = 0, pose = pose({ RS = J(85, 35, 15), RE = J(70) }), ease = "linear" },
		{ t = 0.08, pose = pose({ RS = J(110, -50, 20), RE = J(10), RW = J(-80), Waist = J(0, -20) }), ease = "expo" },
		{ t = 0.4, pose = pose({ RS = J(40, 0, 15), RE = J(30), Waist = J(0, -10) }), ease = "inout" },
	},
}
Poses.BlockHit = reaction(
	0.25,
	{ Waist = J(10), RS = J(80, 35, 15), RE = J(85), LS = J(75, -35, -10), LE = J(95), Root = JP(0, -0.3, 0.3) },
	3
)

-- ===================== HABILIDADES =====================
local function cast(windup: number, anticipation: { [string]: CFrame }, release: { [string]: CFrame }, hold: number?)
	return {
		duration = windup + (hold or 0.35) + 0.2,
		priority = 3,
		fadeIn = 0.06,
		fadeOut = 0.2,
		markers = { Release = windup },
		keyframes = {
			{ t = 0, pose = pose(anticipation), ease = "out" },
			{ t = windup * 0.8, pose = pose(anticipation), ease = "inout" },
			{ t = windup, pose = pose(release), ease = "expo" },
			{ t = windup + (hold or 0.35), pose = pose(release), ease = "linear" },
		},
	}
end

-- Duração real é escalada pelo cliente para casar com o `windup` de cada habilidade.
Poses.CastPoint = cast(
	0.25,
	merge(STANCE_LEGS, { LS = J(40, 30, -10), LE = J(90), RS = J(10, 0, 20), Waist = J(0, 25) }),
	merge(STANCE_LEGS, { LS = J(90, -5, 0), LE = J(0), RS = J(-15, 0, 25), Waist = J(-5, 40), Neck = J(0, -30) })
)
Poses.CastSlash = cast(
	0.25,
	merge(STANCE_LEGS, { RS = J(165, -30, 25), RE = J(20), RW = J(-70), Waist = J(10, -30) }),
	merge(LUNGE_LEGS, { RS = J(30, 60, 0), RW = J(-80), Waist = J(-25, 35), LS = J(20, -20, -30) })
)
Poses.CastOverhead = cast(
	0.3,
	merge(STANCE_LEGS, { RS = J(175, 0, 10), LS = J(175, 0, -10), RE = J(20), LE = J(20), Waist = J(15), Neck = J(15) }),
	merge(LUNGE_LEGS, { RS = J(0, 10, 10), LS = J(10, -10, -10), RW = J(-80), Waist = J(-40), Neck = J(-20) })
)
Poses.CastBurst = cast(
	0.3,
	merge(STANCE_LEGS, {
		RS = J(70, 50, 0),
		LS = J(70, -50, 0),
		RE = J(80),
		LE = J(80),
		Waist = J(-15),
		Neck = J(-20),
		Root = JP(0, -0.6, 0),
	}),
	{ RS = J(10, 0, 110), LS = J(10, 0, -110), RE = J(5), LE = J(5), Waist = J(15), Neck = J(25), Root = JP(0, 0.1, 0) }
)
Poses.CastCharge = cast(
	0.45,
	merge(STANCE_LEGS, { RS = J(60, 45, 0), LS = J(60, -45, 0), RE = J(70), LE = J(70), Waist = J(5, 20) }),
	merge(LUNGE_LEGS, { RS = J(90, 15, 0), LS = J(90, -15, 0), RE = J(0), LE = J(0), Waist = J(-10), Neck = J(-5) })
)
Poses.CastBow = cast(
	0.25,
	merge(
		STANCE_LEGS,
		{ LS = J(90, 10, 0), LE = J(0), RS = J(90, -40, 0), RE = J(120), Waist = J(0, 45), Neck = J(0, -40) }
	),
	merge(
		STANCE_LEGS,
		{ LS = J(90, 10, 0), LE = J(0), RS = J(70, -95, 0), RE = J(60), Waist = J(0, 45), Neck = J(0, -40) }
	),
	0.25
)
Poses.DashStrikePose = cast(
	0.1,
	{ Waist = J(-30), RS = J(-30, 0, 15), RW = J(-80), RH = J(40), RK = J(-60) },
	merge(LUNGE_LEGS, {
		RS = J(60, -110, 15),
		RE = J(0),
		RW = J(-90),
		LS = J(-30, 0, -35),
		Waist = J(-20, -35),
		Root = JP(0, -0.9, -0.4, -10),
	}),
	0.3
)
Poses.UltimateRaise = cast(
	1.0,
	merge(
		STANCE_LEGS,
		{ RS = J(178, 0, 5), RE = J(5), RW = J(-90), LS = J(30, 0, -60), LE = J(30), Waist = J(15), Neck = J(25) }
	),
	merge(LUNGE_LEGS, { RS = J(20, 20, 0), RW = J(-85), LS = J(10, 0, -50), Waist = J(-35), Neck = J(-15) }),
	0.8
)

-- ===================== TRANSFORMAÇÕES =====================
Poses.ReleaseTier1 = {
	duration = 1.3,
	priority = 4,
	fadeIn = 0.1,
	fadeOut = 0.3,
	keyframes = {
		{
			t = 0,
			pose = pose(merge(STANCE_LEGS, {
				RS = J(80, 25, 0),
				RE = J(35),
				RW = J(0),
				LS = J(85, -15, 0),
				LE = J(75),
				Waist = J(0, -10),
				Neck = J(-10),
			})),
			ease = "out",
		},
		{
			t = 0.7,
			pose = pose(merge(STANCE_LEGS, {
				RS = J(85, 25, 0),
				RE = J(30),
				RW = J(0),
				LS = J(90, -10, 0),
				LE = J(70),
				Waist = J(0, -10),
				Neck = J(-15),
			})),
			ease = "linear",
		},
		{
			t = 0.9,
			pose = pose(merge(LUNGE_LEGS, {
				RS = J(75, -90, 10),
				RE = J(0),
				RW = J(-85),
				LS = J(10, 0, -45),
				Waist = J(-10, -40),
				Neck = J(0, 20),
			})),
			ease = "expo",
		},
		{ t = 1.3, pose = pose(merge(STANCE_LEGS, { RS = J(30, 18, 12), RE = J(25) })), ease = "inout" },
	},
}
Poses.ReleaseTier2 = {
	duration = 2.1,
	priority = 4,
	fadeIn = 0.1,
	fadeOut = 0.3,
	keyframes = {
		{
			t = 0,
			pose = pose({
				RS = J(40, 10, 5),
				RE = J(15),
				RW = J(70),
				LS = J(40, -10, -5),
				LE = J(25),
				Waist = J(-25),
				Neck = J(-25),
				RH = J(40),
				RK = J(-80),
				LH = J(20),
				LK = J(-70),
				Root = JP(0, -1.2, 0),
			}),
			ease = "out",
		},
		{
			t = 1.2,
			pose = pose({
				RS = J(45, 10, 5),
				RE = J(15),
				RW = J(70),
				LS = J(45, -10, -5),
				LE = J(25),
				Waist = J(-30),
				Neck = J(-30),
				RH = J(40),
				RK = J(-80),
				LH = J(20),
				LK = J(-70),
				Root = JP(0, -1.3, 0),
			}),
			ease = "linear",
		},
		{
			t = 1.6,
			pose = pose({
				RS = J(30, 0, 100),
				RE = J(5),
				RW = J(-60),
				LS = J(30, 0, -100),
				LE = J(5),
				Waist = J(15),
				Neck = J(30),
				Root = JP(0, 0.2, 0),
			}),
			ease = "expo",
		},
		{ t = 2.1, pose = pose({ RS = J(30, 18, 12), RE = J(25), Waist = J(0, -10) }), ease = "inout" },
	},
}
Poses.MaskOn = {
	duration = 0.9,
	priority = 4,
	fadeIn = 0.05,
	fadeOut = 0.2,
	keyframes = {
		{ t = 0, pose = pose({ LS = J(125, -35, -10), LE = J(115), Neck = J(-10) }), ease = "out" },
		{
			t = 0.45,
			pose = pose({ LS = J(130, -35, -10), LE = J(120), Neck = J(-15), Waist = J(-10) }),
			ease = "linear",
		},
		{ t = 0.6, pose = pose({ LS = J(30, 30, -40), LE = J(10), Neck = J(10), Waist = J(10) }), ease = "expo" },
		{ t = 0.9, pose = pose({}), ease = "inout" },
	},
}
Poses.Revert = {
	duration = 0.6,
	priority = 3,
	fadeIn = 0.1,
	fadeOut = 0.2,
	keyframes = {
		{ t = 0, pose = pose({ Waist = J(-15), Neck = J(-15), RS = J(5, 0, 10), LS = J(5, 0, -10) }), ease = "out" },
		{ t = 0.6, pose = pose({}), ease = "inout" },
	},
}

-- ===================== NPC =====================
Poses.Wave = {
	duration = 1.2,
	priority = 2,
	fadeIn = 0.15,
	fadeOut = 0.3,
	keyframes = {
		{ t = 0, pose = pose({ RS = J(0, 0, 150), RE = J(40) }), ease = "inout" },
		{ t = 0.3, pose = pose({ RS = J(0, 0, 160), RE = J(10) }), ease = "inout" },
		{ t = 0.6, pose = pose({ RS = J(0, 0, 150), RE = J(40) }), ease = "inout" },
		{ t = 0.9, pose = pose({ RS = J(0, 0, 160), RE = J(10) }), ease = "inout" },
		{ t = 1.2, pose = pose({}), ease = "inout" },
	},
}
Poses.Talk = {
	duration = 1.6,
	priority = 2,
	fadeIn = 0.2,
	fadeOut = 0.3,
	keyframes = {
		{ t = 0, pose = pose({ RS = J(30, 20, 10), RE = J(60), Neck = J(5) }), ease = "inout" },
		{ t = 0.8, pose = pose({ RS = J(40, 30, 15), RE = J(45), Neck = J(-3, 8) }), ease = "inout" },
		{ t = 1.6, pose = pose({ RS = J(30, 20, 10), RE = J(60), Neck = J(5) }), ease = "inout" },
	},
}

-- Locomoção procedural para rigs sem script Animate (NPCs/inimigos).
function Poses.locomotion(phase: number, speed: number, airborne: boolean, time: number): { [string]: CFrame }
	if airborne then
		return pose({ RH = J(35), RK = J(-55), LH = J(15), LK = J(-35), RS = J(20, 0, 30), LS = J(20, 0, -30) })
	end
	local amount = math.clamp(speed / 16, 0, 1.3)
	if amount < 0.05 then
		local breath = math.sin(time * 1.8) * 2
		return pose({
			Waist = J(breath * 0.5),
			Neck = J(-breath * 0.4),
			RS = J(0, 0, 4 + breath * 0.3),
			LS = J(0, 0, -4 - breath * 0.3),
		})
	end
	local s = math.sin(phase)
	local legSwing = 38 * amount
	return pose({
		RH = J(s * legSwing),
		LH = J(-s * legSwing),
		RK = J(-math.max(0, -s) * 55 * amount - 8),
		LK = J(-math.max(0, s) * 55 * amount - 8),
		RS = J(-s * 30 * amount, 0, 6),
		LS = J(s * 30 * amount, 0, -6),
		RE = J(20 * amount),
		LE = J(20 * amount),
		Waist = J(-6 * amount, s * 6 * amount),
		Root = JP(0, -math.abs(math.cos(phase)) * 0.15 * amount, 0),
	})
end

return Poses

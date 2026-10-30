--!strict
-- Animação procedural por keyframes de poses (fallback enquanto não existem animações publicadas).
-- Dados puros: sample() devolve ângulos em graus por junta; o cliente converte em Motor6D.Transform.
--
-- Convenção (R15, personagem olha para -Z, direita = +X), derivada da geometria dos eixos:
--   Ombro/Quadril/Cotovelo +X = membro vai para a FRENTE; Ombro direito +Z = abre para fora.
--   Waist/Neck +X = inclina para TRÁS / olha para cima. Root.y = deslocamento vertical em studs.
-- Os sinais devem ser conferidos no Studio (veja README, "Testes manuais").

export type Joint = { number } -- {x, y, z, extra?}
export type Pose = { [string]: Joint }

type Key = { t: number, pose: Pose }

local PoseDriver = {}

PoseDriver.Joints = {
	"Root", "Waist", "Neck",
	"RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist",
	"RightHip", "RightKnee", "LeftHip", "LeftKnee",
}

local function P(t: number, p: Pose): Key
	return { t = t, pose = p }
end

-- Copia uma pose trocando só algumas juntas (variações sem repetir tudo).
local function with(base: Pose, changes: Pose): Pose
	local out: Pose = {}
	for k, v in base do
		out[k] = v
	end
	for k, v in changes do
		out[k] = v
	end
	return out
end

-- Coreografia (referência: o vídeo). Juntas omitidas = 0. Root[4] = altura (studs).
-- 1. guarda baixa, peso numa perna, cabeça baixa ("I'll show you")
local STANCE: Pose = {
	Root = { 0, -4, 0, 0 }, Waist = { 3, -8, 0 }, Neck = { 12, 6, 0 },
	RightShoulder = { 25, 0, 8 }, RightElbow = { 18, 0, 0 }, RightWrist = { -8, 0, 0 },
	LeftShoulder = { -5, 0, -8 }, LeftElbow = { 12, 0, 0 },
	RightHip = { 6, -4, 4 }, RightKnee = { -8, 0, 0 },
	LeftHip = { -10, 6, -4 }, LeftKnee = { -6, 0, 0 },
}
local STANCE_LOOK = with(STANCE, { Neck = { 2, 0, 0 }, Waist = { 0, -4, 0 } }) -- ergue o olhar
-- 2. espada na horizontal à frente, mão esquerda indo ao cabo, joelhos dobrados (concentração)
local GUARD: Pose = {
	Root = { 4, -10, 0, -0.45 }, Waist = { 8, -14, 0 }, Neck = { 22, 10, 0 },
	RightShoulder = { 30, -10, -18 }, RightElbow = { 42, 0, 0 }, RightWrist = { 10, 0, 0 },
	LeftShoulder = { 48, 0, 30 }, LeftElbow = { 46, 0, 0 }, LeftWrist = { 0, 0, 0 },
	RightHip = { 24, -6, 8 }, RightKnee = { -36, 0, 0 },
	LeftHip = { -18, 8, -8 }, LeftKnee = { -20, 0, 0 },
}
local GUARD_EYES = with(GUARD, { Neck = { -4, 4, 0 }, Waist = { 2, -10, 0 } }) -- encara a câmera (close dos olhos)
-- 3. mão esquerda cobre o rosto, espada aberta ao lado
local FACE_HAND: Pose = {
	Root = { 0, -6, 0, -0.2 }, Waist = { 16, -6, 0 }, Neck = { 30, 0, 0 },
	RightShoulder = { 20, 0, 36 }, RightElbow = { 14, 0, 0 }, RightWrist = { -10, 0, 0 },
	LeftShoulder = { 95, 0, -15 }, LeftElbow = { 105, 0, 0 },
	RightHip = { 10, 0, 6 }, RightKnee = { -14, 0, 0 },
	LeftHip = { -10, 0, -6 }, LeftKnee = { -8, 0, 0 },
}
-- 4. rugido quando a máscara se forma: braços abertos para trás, cabeça jogada para trás
local ROAR: Pose = {
	Root = { -6, 0, 0, -0.1 }, Waist = { 22, 0, 0 }, Neck = { 34, 0, 0 },
	RightShoulder = { -12, 0, 72 }, RightElbow = { 12, 0, 0 }, RightWrist = { -20, 0, 0 },
	LeftShoulder = { -12, 0, -72 }, LeftElbow = { 12, 0, 0 },
	RightHip = { 8, 0, 10 }, RightKnee = { -12, 0, 0 },
	LeftHip = { -8, 0, -10 }, LeftKnee = { -10, 0, 0 },
}
-- 5. encolhido, juntando energia (durante o flash branco)
local CROUCH: Pose = {
	Root = { 18, 0, 0, -0.85 }, Waist = { -24, 0, 0 }, Neck = { -20, 0, 0 },
	RightShoulder = { 42, 0, 14 }, RightElbow = { 30, 0, 0 }, RightWrist = { 0, 0, 0 },
	LeftShoulder = { 40, 0, -16 }, LeftElbow = { 34, 0, 0 },
	RightHip = { 46, 0, 8 }, RightKnee = { -72, 0, 0 },
	LeftHip = { 38, 0, -8 }, LeftKnee = { -64, 0, 0 },
}
-- 6. golpe: espada atrás da cabeça -> corte diagonal descendente -> continuação
local WINDUP: Pose = {
	Root = { -6, 10, 0, -0.3 }, Waist = { 16, 14, 0 }, Neck = { 8, -8, 0 },
	RightShoulder = { 150, 0, 22 }, RightElbow = { 42, 0, 0 }, RightWrist = { 20, 0, 0 },
	LeftShoulder = { -22, 0, -32 }, LeftElbow = { 20, 0, 0 },
	RightHip = { -14, 0, 8 }, RightKnee = { -24, 0, 0 },
	LeftHip = { 22, 0, -8 }, LeftKnee = { -32, 0, 0 },
}
local SLASH: Pose = {
	Root = { 12, -14, 0, -0.55 }, Waist = { -24, -16, 0 }, Neck = { 6, 10, 0 },
	RightShoulder = { 20, 0, -6 }, RightElbow = { 12, 0, 0 }, RightWrist = { -14, 0, 0 },
	LeftShoulder = { -42, 0, -42 }, LeftElbow = { 10, 0, 0 },
	RightHip = { 32, 0, 8 }, RightKnee = { -44, 0, 0 },
	LeftHip = { -16, 0, -8 }, LeftKnee = { -6, 0, 0 },
}
local FOLLOW = with(SLASH, { Waist = { -32, -22, 0 }, RightShoulder = { 2, 0, -16 }, Root = { 16, -18, 0, -0.6 } })
-- 7. Mugetsu: ereto, espada baixa ao lado, cabeça levemente baixa (pose final)
local FINAL: Pose = {
	Root = { 0, 4, 0, 0 }, Waist = { -3, 6, 0 }, Neck = { 14, -4, 0 },
	RightShoulder = { 18, 0, 12 }, RightElbow = { 14, 0, 0 }, RightWrist = { -6, 0, 0 },
	LeftShoulder = { -6, 0, -12 }, LeftElbow = { 10, 0, 0 },
	RightHip = { 4, 2, 8 }, RightKnee = { -6, 0, 0 },
	LeftHip = { -6, -2, -8 }, LeftKnee = { -3, 0, 0 },
}
local FINAL_B = with(FINAL, { Neck = { 10, 6, 0 }, Waist = { -2, 2, 0 }, LeftShoulder = { -2, 0, -16 } })
-- 8. Getsuga: carrega baixo atrás -> corte ascendente
local CAST_LOW: Pose = with(WINDUP, {
	RightShoulder = { -40, 0, 30 }, RightElbow = { 20, 0, 0 }, Waist = { 10, 24, 0 }, Root = { 6, 16, 0, -0.5 },
	RightKnee = { -40, 0, 0 }, LeftKnee = { -40, 0, 0 },
})
local CAST_UP: Pose = with(SLASH, { RightShoulder = { 115, 0, -22 }, RightElbow = { 10, 0, 0 }, Waist = { -14, -18, 0 }, Neck = { -6, 8, 0 } })

-- breath = amplitude (graus) da respiração somada por cima (Waist/Neck/ombros)
PoseDriver.Animations = {
	Prepare = { length = 4.8, looped = false, breath = 1.4, keys = {
		P(0, STANCE), P(2.2, STANCE_LOOK), P(3.4, STANCE_LOOK), P(4.8, GUARD),
	} },
	Concentrate = { length = 7, looped = false, breath = 0.8, keys = {
		P(0, GUARD), P(3.8, GUARD), P(4.5, GUARD_EYES), P(6.6, GUARD_EYES), P(7, GUARD),
	} },
	Transform = { length = 7, looped = false, breath = 0.5, keys = {
		P(0, GUARD), P(1.0, FACE_HAND), P(2.5, FACE_HAND), P(2.85, ROAR), P(4.4, ROAR), P(5.0, CROUCH), P(7, CROUCH),
	} },
	-- golpe sincronizado com o clímax: ReleaseImpact em 19.6s = 0.6s após o início desta animação
	Release = { length = 3.0, looped = false, breath = 0, keys = {
		P(0, CROUCH), P(0.32, WINDUP), P(0.46, WINDUP), P(0.6, SLASH), P(0.85, FOLLOW), P(1.6, FOLLOW), P(3.0, FINAL),
	} },
	FinalPose = { length = 4, looped = true, breath = 1.2, keys = { P(0, FINAL), P(2, FINAL_B), P(4, FINAL) } },
	GetsugaCast = { length = 1.2, looped = false, breath = 0, keys = {
		P(0, FINAL), P(0.55, CAST_LOW), P(0.72, CAST_LOW), P(0.9, CAST_UP), P(1.2, FINAL),
	} },
}

-- Momentos (s, relativos ao início da animação) dos KeyframeMarkers exportados para o Animation Editor.
PoseDriver.Markers = {
	Concentrate = { Pulse = 2.0 },
	Transform = { Mask = 2.8, Swap = 5.4 },
	Release = { Slash = 0.45, Impact = 0.6 },
	GetsugaCast = { Fire = 0.9 },
}

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

local function lerpJoint(a: Joint, b: Joint, k: number): Joint
	return {
		a[1] + (b[1] - a[1]) * k,
		a[2] + (b[2] - a[2]) * k,
		a[3] + (b[3] - a[3]) * k,
		(a[4] or 0) + ((b[4] or 0) - (a[4] or 0)) * k,
	}
end

-- t = segundos desde o início da animação; intensity (0..1) controla o tremor da Concentração.
function PoseDriver.sample(animName: string, t: number, intensity: number?): Pose?
	local anim = PoseDriver.Animations[animName]
	if anim == nil then
		return nil
	end
	local keys = anim.keys :: { Key }
	local tt = anim.looped and t % anim.length or math.clamp(t, 0, anim.length)
	if not anim.looped then
		tt = math.clamp(t, 0, keys[#keys].t)
	end
	local lo, hi = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if tt >= keys[i].t and tt <= keys[i + 1].t then
			lo, hi = keys[i], keys[i + 1]
			break
		end
	end
	local span = hi.t - lo.t
	local k = span > 1e-6 and smooth((tt - lo.t) / span) or 1
	local out: Pose = {}
	local ZERO: Joint = { 0, 0, 0, 0 }
	for _, j in PoseDriver.Joints do
		out[j] = lerpJoint(lo.pose[j] or ZERO, hi.pose[j] or ZERO, k)
	end
	local breath = anim.breath or 0
	if breath > 0 then
		local b1 = math.sin(t * 2.1) * breath
		out.Waist[1] += b1 * 0.6
		out.Neck[1] -= b1 * 0.4
		out.RightShoulder[3] += b1 * 0.5
		out.LeftShoulder[3] -= b1 * 0.5
		out.Root[4] += b1 * 0.012
	end
	if animName == "Concentrate" and intensity and intensity > 0 then
		local amp = intensity * 2.2
		for _, j in { "RightShoulder", "LeftShoulder", "Neck", "Waist" } do
			local o = out[j]
			if o then
				o[1] += math.sin(t * 31 + #j) * amp
				o[3] += math.sin(t * 27 + #j * 2) * amp * 0.6
			end
		end
	end
	return out
end

function PoseDriver.length(animName: string): number
	local a = PoseDriver.Animations[animName]
	return a and a.length or 0
end

return PoseDriver

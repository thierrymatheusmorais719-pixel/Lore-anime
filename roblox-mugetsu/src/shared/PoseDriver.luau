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
	"RightShoulder", "RightElbow", "LeftShoulder", "LeftElbow",
	"RightHip", "RightKnee", "LeftHip", "LeftKnee",
}

local function P(t: number, p: Pose): Key
	return { t = t, pose = p }
end

local STANCE: Pose = {
	Root = { 0, 0, 0, 0 }, Waist = { 2, 0, 0 }, Neck = { 8, 0, 0 },
	RightShoulder = { -8, 0, 6 }, RightElbow = { 10, 0, 0 },
	LeftShoulder = { -5, 0, -8 }, LeftElbow = { 12, 0, 0 },
	RightHip = { 6, 0, 3 }, RightKnee = { -8, 0, 0 },
	LeftHip = { -8, 0, -3 }, LeftKnee = { -4, 0, 0 },
}

local GUARD: Pose = {
	Root = { 4, 0, 0, -0.5 }, Waist = { 6, 0, 0 }, Neck = { 20, 0, 0 },
	RightShoulder = { 55, 0, -30 }, RightElbow = { 70, 0, 0 },
	LeftShoulder = { 30, 0, -10 }, LeftElbow = { 40, 0, 0 },
	RightHip = { 22, 0, 8 }, RightKnee = { -34, 0, 0 },
	LeftHip = { -20, 0, -8 }, LeftKnee = { -18, 0, 0 },
}

local FACE_HAND: Pose = {
	Root = { 0, 0, 0, -0.2 }, Waist = { 18, 0, 0 }, Neck = { 34, 0, 0 },
	RightShoulder = { 20, 0, 12 }, RightElbow = { 20, 0, 0 },
	LeftShoulder = { 95, 0, -15 }, LeftElbow = { 105, 0, 0 },
	RightHip = { 10, 0, 6 }, RightKnee = { -14, 0, 0 },
	LeftHip = { -10, 0, -6 }, LeftKnee = { -8, 0, 0 },
}

local TALL: Pose = {
	Root = { 0, 0, 0, 0 }, Waist = { -6, 0, 0 }, Neck = { -8, 0, 0 },
	RightShoulder = { 10, 0, 8 }, RightElbow = { 8, 0, 0 },
	LeftShoulder = { 10, 0, -8 }, LeftElbow = { 10, 0, 0 },
	RightHip = { 4, 0, 6 }, RightKnee = { -6, 0, 0 },
	LeftHip = { -6, 0, -6 }, LeftKnee = { -3, 0, 0 },
}

local WINDUP: Pose = {
	Root = { -6, 0, 0, -0.3 }, Waist = { 16, 0, 0 }, Neck = { 10, 0, 0 },
	RightShoulder = { 150, 0, 20 }, RightElbow = { 40, 0, 0 },
	LeftShoulder = { -20, 0, -30 }, LeftElbow = { 20, 0, 0 },
	RightHip = { -14, 0, 8 }, RightKnee = { -24, 0, 0 },
	LeftHip = { 20, 0, -8 }, LeftKnee = { -30, 0, 0 },
}

local SLASH: Pose = {
	Root = { 12, 0, 0, -0.5 }, Waist = { -24, 0, 0 }, Neck = { 6, 0, 0 },
	RightShoulder = { 20, 0, -5 }, RightElbow = { 14, 0, 0 },
	LeftShoulder = { -40, 0, -40 }, LeftElbow = { 10, 0, 0 },
	RightHip = { 30, 0, 8 }, RightKnee = { -42, 0, 0 },
	LeftHip = { -16, 0, -8 }, LeftKnee = { -6, 0, 0 },
}

local FINAL: Pose = {
	Root = { 0, 0, 0, 0 }, Waist = { -3, 0, 0 }, Neck = { 14, 0, 0 },
	RightShoulder = { -4, 0, 10 }, RightElbow = { 8, 0, 0 },
	LeftShoulder = { -6, 0, -12 }, LeftElbow = { 10, 0, 0 },
	RightHip = { 4, 0, 8 }, RightKnee = { -6, 0, 0 },
	LeftHip = { -6, 0, -8 }, LeftKnee = { -3, 0, 0 },
}

PoseDriver.Animations = {
	Prepare = { length = 5, looped = false, keys = { P(0, STANCE), P(3.5, STANCE), P(5, GUARD) } },
	Concentrate = { length = 7, looped = true, keys = { P(0, GUARD), P(7, GUARD) } },
	Transform = { length = 7, looped = false, keys = {
		P(0, GUARD), P(1.5, FACE_HAND), P(2.8, FACE_HAND), P(3.4, TALL), P(7, TALL),
	} },
	Release = { length = 3.2, looped = false, keys = {
		P(0, TALL), P(0.55, WINDUP), P(0.62, WINDUP), P(0.78, SLASH), P(1.6, SLASH), P(3.2, FINAL),
	} },
	FinalPose = { length = 4, looped = true, keys = { P(0, FINAL), P(4, FINAL) } },
	GetsugaCast = { length = 1.2, looped = false, keys = {
		P(0, FINAL), P(0.6, WINDUP), P(0.72, WINDUP), P(0.9, SLASH), P(1.2, FINAL),
	} },
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
	for _, j in PoseDriver.Joints do
		local a, b = lo.pose[j], hi.pose[j]
		if a and b then
			out[j] = lerpJoint(a, b, k)
		end
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

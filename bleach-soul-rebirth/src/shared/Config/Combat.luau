-- Parâmetros de combate. Valores em segundos/studs. O servidor e o cliente leem daqui,
-- então as animações locais e as hitboxes do servidor ficam sincronizadas.
local function box(width: number, height: number, length: number, forward: number?, up: number?)
	return {
		size = Vector3.new(width, height, length),
		offset = CFrame.new(0, up or 0, -(forward or length / 2)),
	}
end

local Combat = {}

Combat.ParryWindow = 0.2 -- janela após apertar bloquear em que o golpe é aparado
Combat.BlockDamageMultiplier = 0.15
Combat.BlockFacingDot = 0.15 -- bloqueio só funciona contra golpes vindos da frente
Combat.MaxGuard = 100
Combat.GuardRegenPerSecond = 22
Combat.GuardRegenDelay = 1.2
Combat.GuardBreakStun = 1.1
Combat.ParriedStun = 0.85
Combat.CounterWindow = 0.9
Combat.CounterMultiplier = 1.5
Combat.BlockStartupLock = 0.05
Combat.BlockCooldownAfterRelease = 0.15

Combat.BaseWalkSpeed = 18
Combat.SprintSpeed = 27
Combat.BlockWalkSpeed = 7
Combat.AttackWalkSpeed = 6
Combat.StunWalkSpeed = 0
Combat.ChargeWalkSpeed = 4

Combat.ComboResetTime = 0.8 -- tempo após o fim de um golpe para continuar a sequência
Combat.ComboEndLag = 0.5 -- pausa após o último golpe da sequência
Combat.InputBuffer = 0.28 -- cliente guarda o próximo comando durante este tempo

Combat.AutoFaceRange = 16
Combat.AutoFaceAngle = 75 -- graus; mira assistida para teclado/celular
Combat.HitDistanceSlack = 8 -- tolerância de latência na validação de alcance

Combat.Dash = {
	speed = 96,
	duration = 0.17,
	cooldown = 0.6,
	iframes = 0.2,
	airDashes = 1,
	maxServerDistance = 32, -- distância máxima aceita pelo servidor por dash (anti-teleporte)
}

Combat.AirStep = { velocity = 52, max = 1 } -- pulo duplo (shunpo aéreo)
Combat.AirHover = 0.45 -- tempo que o atacante flutua ao acertar no ar

-- Sequência terrestre de 5 golpes.
Combat.Light = {
	{
		anim = "Slash1",
		windup = 0.1,
		duration = 0.3,
		damage = 5,
		stun = 0.55,
		knockback = 6,
		guardDamage = 12,
		hitbox = box(7, 6, 8),
		lunge = 6,
		hitstop = 0.045,
		shake = 0.12,
		sound = "Slash",
	},
	{
		anim = "Slash2",
		windup = 0.1,
		duration = 0.3,
		damage = 5,
		stun = 0.55,
		knockback = 6,
		guardDamage = 12,
		hitbox = box(8, 6, 8),
		lunge = 6,
		hitstop = 0.045,
		shake = 0.12,
		sound = "Slash",
	},
	{
		anim = "Slash3",
		windup = 0.12,
		duration = 0.34,
		damage = 6,
		stun = 0.6,
		knockback = 8,
		guardDamage = 14,
		hitbox = box(9, 6, 8),
		lunge = 7,
		hitstop = 0.05,
		shake = 0.16,
		sound = "Slash",
	},
	{
		anim = "Slash4",
		windup = 0.11,
		duration = 0.34,
		damage = 6,
		stun = 0.65,
		knockback = 8,
		guardDamage = 14,
		hitbox = box(7, 7, 9),
		lunge = 8,
		hitstop = 0.05,
		shake = 0.16,
		sound = "Lunge",
	},
	{
		anim = "Slash5",
		windup = 0.17,
		duration = 0.5,
		damage = 10,
		stun = 0.95,
		knockback = 55,
		guardDamage = 30,
		hitbox = box(10, 7, 10),
		lunge = 10,
		hitstop = 0.11,
		shake = 0.5,
		heavy = true,
		finisher = true,
		sound = "Lunge",
	},
}

-- Sequência aérea: mantém o alvo no ar; o último golpe arremessa para baixo.
Combat.Aerial = {
	{
		anim = "Air1",
		windup = 0.09,
		duration = 0.28,
		damage = 5,
		stun = 0.7,
		knockback = 2,
		juggle = 14,
		guardDamage = 12,
		hitbox = box(9, 9, 9),
		hitstop = 0.045,
		shake = 0.12,
		sound = "Slash",
	},
	{
		anim = "Air2",
		windup = 0.09,
		duration = 0.28,
		damage = 5,
		stun = 0.7,
		knockback = 2,
		juggle = 14,
		guardDamage = 12,
		hitbox = box(9, 9, 9),
		hitstop = 0.045,
		shake = 0.12,
		sound = "Slash",
	},
	{
		anim = "Air3",
		windup = 0.1,
		duration = 0.3,
		damage = 6,
		stun = 0.75,
		knockback = 3,
		juggle = 16,
		guardDamage = 14,
		hitbox = box(9, 9, 9),
		hitstop = 0.05,
		shake = 0.15,
		sound = "Slash",
	},
	{
		anim = "Air4",
		windup = 0.16,
		duration = 0.5,
		damage = 10,
		stun = 1.0,
		knockback = 10,
		spike = 90, -- velocidade para baixo
		guardDamage = 30,
		hitbox = box(10, 10, 10),
		hitstop = 0.11,
		shake = 0.55,
		heavy = true,
		finisher = true,
		sound = "Lunge",
	},
}

Combat.Heavy = {
	anim = "HeavySlash",
	windup = 0.4,
	duration = 0.75,
	damage = 12,
	stun = 1.0,
	knockback = 38,
	guardBreak = true,
	unparryable = false,
	guardDamage = 100,
	hitbox = box(9, 7, 10),
	lunge = 10,
	cooldown = 2.2,
	hitstop = 0.1,
	shake = 0.45,
	heavy = true,
	sound = "Lunge",
}

Combat.Launcher = {
	anim = "Uppercut",
	windup = 0.15,
	duration = 0.45,
	damage = 6,
	stun = 1.15,
	knockback = 4,
	launch = 62,
	selfLaunch = 60,
	guardDamage = 25,
	hitbox = box(7, 8, 8),
	cooldown = 3,
	hitstop = 0.07,
	shake = 0.3,
	sound = "Slash",
}

-- Contra-ataque: substitui o próximo golpe leve após um parry bem-sucedido.
Combat.Counter = {
	anim = "Counter",
	windup = 0.05,
	duration = 0.42,
	damage = 9,
	stun = 1.0,
	knockback = 30,
	guardBreak = true,
	guardDamage = 100,
	hitbox = box(9, 7, 9),
	lunge = 8,
	hitstop = 0.12,
	shake = 0.5,
	heavy = true,
	sound = "Lunge",
}

-- Execução cinematográfica: ataque pesado contra alvo atordoado com pouca vida.
Combat.Execution = {
	anim = "Execution",
	healthThreshold = 0.18,
	range = 11,
	windup = 0.95,
	duration = 1.55,
	damage = 40,
	stun = 1.6,
	knockback = 70,
	unparryable = true,
	guardBreak = true,
	guardDamage = 100,
	hitbox = box(10, 8, 12),
	cooldown = 12,
	hitstop = 0.18,
	shake = 0.9,
	heavy = true,
	cinematic = true,
	sound = "Lunge",
}

Combat.Stun = {
	maxChain = 3.0, -- stun máximo acumulado (evita travar alguém para sempre)
	hitReactions = { "Hit1", "Hit2" },
}

Combat.Charge = {
	reiatsuPerSecond = 22,
}

Combat.Reiatsu = {
	regenPerSecond = 3.5,
	regenDelay = 1.5,
	onHitGain = 1.5, -- golpes corpo a corpo carregam Reiatsu
}

Combat.RespawnTime = 4

return Combat

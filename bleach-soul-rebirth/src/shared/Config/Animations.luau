-- Mapa de animações. Cada entrada pode receber um ID de animação PUBLICADA E AUTORIZADA
-- (ex.: "rbxassetid://1234567890"). Enquanto `assetId` estiver vazio, o jogo usa a versão
-- procedural (Shared/Anim/Poses), que anima os Motor6D do rig R15 em tempo real.
--
-- Para trocar por uma animação feita no Animation Editor/Moon Animator:
--   1. Publique a animação (mesmo dono da experiência — usuário ou grupo).
--   2. Cole o ID em `assetId`. Use os mesmos eventos de marcador da tabela `markers`
--      (ex.: "Hit") se quiser sincronizar efeitos com KeyframeMarkers.
--   3. `speed` ajusta a velocidade para casar com `windup`/`duration` em Config/Combat.
local Animations = {}

local NAMES = {
	-- Postura / locomoção com espada
	"SwordIdle",
	"SwordRun",
	"Block",
	"Draw",
	"Sheathe",
	"Charge",
	"Dash",
	"AirStep",
	-- Combos
	"Slash1",
	"Slash2",
	"Slash3",
	"Slash4",
	"Slash5",
	"Air1",
	"Air2",
	"Air3",
	"Air4",
	"HeavySlash",
	"Uppercut",
	"Counter",
	"Execution",
	-- Reações
	"Hit1",
	"Hit2",
	"Stagger",
	"Launched",
	"GuardBreak",
	"Parried",
	"ParrySuccess",
	"BlockHit",
	-- Habilidades
	"CastPoint",
	"CastSlash",
	"CastOverhead",
	"CastBurst",
	"CastCharge",
	"CastBow",
	"DashStrikePose",
	"UltimateRaise",
	-- Transformações
	"ReleaseTier1",
	"ReleaseTier2",
	"MaskOn",
	"Revert",
	-- NPC
	"Talk",
	"Wave",
}

Animations.List = {}
for _, name in NAMES do
	Animations.List[name] = { assetId = "", speed = 1 }
end

-- Exemplo de substituição:
-- Animations.List.Slash1.assetId = "rbxassetid://SEU_ID_AQUI"

return Animations

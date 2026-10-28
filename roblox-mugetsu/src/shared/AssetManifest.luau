--!strict
-- Manifesto de assets EXTERNOS. Nenhum ID foi inventado: tudo que está vazio ("") ainda precisa
-- ser produzido/publicado por você. O código detecta o vazio e usa o fallback procedural
-- (PoseDriver para animação; sons sintetizados por Sound sem SoundId ficam silenciosos).
--
-- Para integrar: publique a animação/áudio, cole o ID ("rbxassetid://123") e (opcional) liste os
-- KeyframeMarkers que a animação emite, com o nome do evento da Timeline correspondente.

export type AnimEntry = {
	id: string, -- "" = ainda não existe
	looped: boolean,
	markers: { [string]: string }, -- nome do marker -> nome do evento da Timeline
	expectedLength: number, -- duração desejada (segundos) para quem for animar
	brief: string, -- descrição para o animador
}

export type SoundEntry = {
	id: string,
	volume: number,
	brief: string,
}

local Manifest = {}

Manifest.Animations = {
	Prepare = { id = "", looped = false, markers = {}, expectedLength = 5,
		brief = "Costas para a câmera, espada baixa na mão direita, peso no pé de trás, respiração lenta." },
	Concentrate = { id = "", looped = true, markers = { Pulse = "PulseLight" }, expectedLength = 7,
		brief = "Pose frontal: espada atravessada na frente do corpo, braço esquerdo tenso, cabeça baixa; tremor crescente." },
	Transform = { id = "", looped = false, markers = { Mask = "MaskForm", Swap = "MorphSwap" }, expectedLength = 7,
		brief = "Mão esquerda cobre o rosto, cabeça para trás, corpo se curva; mão cai revelando a máscara." },
	Release = { id = "", looped = false, markers = { Impact = "ReleaseImpact", Slash = "SwordSlash" }, expectedLength = 3,
		brief = "Golpe diagonal descendente com a espada: wind-up 0.3s, impacto no frame 'Impact', follow-through." },
	FinalPose = { id = "", looped = true, markers = {}, expectedLength = 4,
		brief = "Mugetsu ereto, espada baixa ao lado, braço esquerdo relaxado, cabelo ao vento." },
	GetsugaCast = { id = "", looped = false, markers = { Fire = "AbilityFire" }, expectedLength = 1.2,
		brief = "Ataque especial: carga com espada atrás (0.9s) e corte frontal ascendente no marker 'Fire'." },
} :: { [string]: AnimEntry }

Manifest.Sounds = {
	AmbientBed = { id = "", volume = 0.5, brief = "Drone grave contínuo, tensão crescente (loop)." },
	Heartbeat = { id = "", volume = 0.8, brief = "Batimento grave para as PauseBeat." },
	EnergyRise = { id = "", volume = 0.9, brief = "Riser de 7s para a Concentração." },
	Impact = { id = "", volume = 1.0, brief = "Impacto sub-grave + crack para ReleaseImpact." },
	SwordSlash = { id = "", volume = 0.9, brief = "Whoosh de lâmina." },
	Getsuga = { id = "", volume = 0.9, brief = "Disparo do Getsuga negro." },
	Tendrils = { id = "", volume = 0.8, brief = "Textura de chamas negras/sussurros." },
} :: { [string]: SoundEntry }

-- Kit de modelo opcional: se existir ServerStorage.MugetsuAssets.MugetsuKit (Model) com a estrutura
-- documentada no README, o ModelKit o usa no lugar das peças procedurais.
Manifest.CustomKitPath = { "MugetsuAssets", "MugetsuKit" }

return Manifest

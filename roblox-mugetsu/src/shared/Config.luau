--!strict
-- Configuração central. Tudo que é ajustável fica aqui.

export type QualityLevel = "Low" | "Medium" | "High"

local Config = {}

Config.Transform = {
	Keybind = Enum.KeyCode.G,
	MobileButtonLabel = "MUGETSU",
	Cooldown = 90, -- segundos entre transformações
	FormDuration = 120, -- segundos na forma Mugetsu (0 = até morrer)
	MaxRange = 120, -- observadores além disso recebem só o resultado final
	RequireR15 = true,
}

Config.Kit = {
	-- "OBJ": modelos enviados (assets/models/*.obj, convertidos por tools/import_obj.py)
	-- "Procedural": kit mais detalhado gerado por tools/build_kits.py a partir das imagens de referência
	Source = "OBJ",
}

Config.Ability = {
	Name = "Getsuga Tenshō Negro",
	Keybind = Enum.KeyCode.F,
	MobileButtonLabel = "GETSUGA",
	Cooldown = 6,
	TelegraphTime = 0.9, -- tempo de aviso antes do disparo
	Damage = 35,
	Range = 90,
	Width = 9, -- largura da faixa de dano (studs)
	Height = 10,
	ProjectileSpeed = 140,
	MaxHitsPerCast = 8,
	RemoteRateLimit = 0.25, -- mínimo entre requisições aceitas
	AimTolerance = 0.2, -- direção enviada pelo cliente é normalizada e limitada
}

Config.Quality = {
	Low = { ParticleScale = 0.35, Shards = 14, Rings = 2, PostFx = false, Fog = false },
	Medium = { ParticleScale = 0.65, Shards = 28, Rings = 3, PostFx = true, Fog = true },
	High = { ParticleScale = 1.0, Shards = 48, Rings = 4, PostFx = true, Fog = true },
}

Config.Arena = {
	Origin = Vector3.new(0, 0, 0),
	Radius = 160,
	SpawnOffset = Vector3.new(0, 6, 0),
	Pillars = 14,
}

Config.Safety = {
	-- Se a cutscene durar mais que isto (timeline + margem), o watchdog a cancela.
	WatchdogMargin = 6,
	HumanoidWalkSpeedDuringCutscene = 0,
}

return Config

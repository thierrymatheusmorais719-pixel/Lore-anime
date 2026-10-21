-- Árvore de habilidades por facção. Dois ramos (Lâmina / Espírito) + especialização exclusiva.
-- Efeitos (`effects`) são somados pelo servidor em Logic/Stats.
local SkillTrees = {}

-- Nomes com sabor por facção; a estrutura é compartilhada para manter balanceamento.
local FLAVOR = {
	Shinigami = { blade = "Zanjutsu", spirit = "Kidō", move = "Hohō", body = "Hakuda" },
	Hollow = { blade = "Garras", spirit = "Cero", move = "Sonído", body = "Hierro" },
	Quincy = { blade = "Seele Schneider", spirit = "Heilig", move = "Hirenkyaku", body = "Blut" },
	Fullbringer = { blade = "Bringer", spirit = "Fullbring", move = "Passo Bringer", body = "Corpo Bringer" },
}

local function build(faction: string)
	local f = FLAVOR[faction]
	return {
		Blade1 = { name = f.blade .. " I", branch = "Blade", cost = 1, level = 2, requires = {}, desc = "+6% dano corpo a corpo.", effects = { melee = 0.06 }, x = 1, y = 1 },
		Blade2 = { name = f.blade .. " II", branch = "Blade", cost = 1, level = 6, requires = { "Blade1" }, desc = "+8% dano corpo a corpo.", effects = { melee = 0.08 }, x = 1, y = 2 },
		Parry = { name = "Aparar Perfeito", branch = "Blade", cost = 1, level = 8, requires = { "Blade1" }, desc = "Janela de parry +0,06s.", effects = { parryWindow = 0.06 }, x = 2, y = 2 },
		Counter = { name = "Lâmina de Resposta", branch = "Blade", cost = 2, level = 12, requires = { "Parry" }, desc = "+30% de dano em contra-ataques.", effects = { counter = 0.3 }, x = 2, y = 3 },
		Blade3 = { name = f.blade .. " III", branch = "Blade", cost = 2, level = 14, requires = { "Blade2" }, desc = "+10% dano corpo a corpo.", effects = { melee = 0.1 }, x = 1, y = 3 },

		Spirit1 = { name = f.spirit .. " I", branch = "Spirit", cost = 1, level = 2, requires = {}, desc = "+6% dano de habilidades.", effects = { ability = 0.06 }, x = 4, y = 1 },
		Reservoir = { name = "Reservatório", branch = "Spirit", cost = 1, level = 5, requires = { "Spirit1" }, desc = "+25 Reiatsu máximo.", effects = { reiatsu = 25 }, x = 5, y = 2 },
		Spirit2 = { name = f.spirit .. " II", branch = "Spirit", cost = 1, level = 6, requires = { "Spirit1" }, desc = "+8% dano de habilidades.", effects = { ability = 0.08 }, x = 4, y = 2 },
		Release = { name = "Domínio da Liberação", branch = "Spirit", cost = 2, level = 10, requires = { "Reservoir" }, desc = "Formas drenam 30% menos Reiatsu.", effects = { drain = -0.3 }, x = 5, y = 3 },
		Spirit3 = { name = f.spirit .. " III", branch = "Spirit", cost = 2, level = 14, requires = { "Spirit2" }, desc = "+10% dano de habilidades.", effects = { ability = 0.1 }, x = 4, y = 3 },

		Move1 = { name = f.move, branch = "Core", cost = 1, level = 3, requires = {}, desc = "−20% recarga do dash e +1 dash aéreo.", effects = { dashCooldown = -0.2, airDashes = 1 }, x = 3, y = 1 },
		Body1 = { name = f.body, branch = "Core", cost = 1, level = 4, requires = {}, desc = "+10% vida máxima.", effects = { health = 0.1 }, x = 3, y = 2 },
		Body2 = { name = f.body .. " II", branch = "Core", cost = 2, level = 12, requires = { "Body1" }, desc = "+15% guarda e +10% vida.", effects = { guard = 0.15, health = 0.1 }, x = 3, y = 3 },

		-- Especializações exclusivas (escolha uma).
		BladeMaster = {
			name = "Mestre da Lâmina",
			branch = "Blade",
			cost = 3,
			level = 20,
			requires = { "Blade3" },
			exclusive = "Capstone",
			desc = "O 5º golpe do combo libera uma onda de corte.",
			effects = { finisherWave = 1, melee = 0.05 },
			x = 1,
			y = 4,
		},
		SpiritMaster = {
			name = "Mestre do Espírito",
			branch = "Spirit",
			cost = 3,
			level = 20,
			requires = { "Spirit3" },
			exclusive = "Capstone",
			desc = "Habilidades custam 20% menos e recarregam 10% mais rápido.",
			effects = { abilityCost = -0.2, cooldown = -0.1 },
			x = 4,
			y = 4,
		},
	}
end

SkillTrees.Trees = {}
for faction in FLAVOR do
	SkillTrees.Trees[faction] = build(faction)
end

function SkillTrees.get(faction: string?)
	return faction and SkillTrees.Trees[faction] or nil
end

return SkillTrees

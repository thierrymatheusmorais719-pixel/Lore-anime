-- Sons. Por padrão usamos apenas arquivos embutidos no cliente Roblox (rbxasset://sounds/...),
-- que existem em qualquer instalação. Troque por IDs próprios ("rbxassetid://...") para
-- sons de maior qualidade. `pitch` aceita {min, max} para variação natural.
local Sounds = {
	Slash = { id = "rbxasset://sounds/swordslash.wav", volume = 0.7, pitch = { 1.05, 1.25 } },
	-- garras de Hollow: o mesmo corte, mais grave e áspero (som do preparo, marcador "Swing")
	Claw = { id = "rbxasset://sounds/swordslash.wav", volume = 0.75, pitch = { 0.62, 0.75 } },
	Lunge = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.8, pitch = { 0.95, 1.1 } },
	Draw = { id = "rbxasset://sounds/unsheath.wav", volume = 0.7, pitch = { 1, 1.1 } },
	Sheathe = { id = "rbxasset://sounds/unsheath.wav", volume = 0.5, pitch = { 0.7, 0.75 } },
	HitFlesh = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.9, pitch = { 0.55, 0.7 } },
	HitHeavy = { id = "rbxasset://sounds/swordlunge.wav", volume = 1, pitch = { 0.4, 0.48 } },
	Block = { id = "rbxasset://sounds/swordslash.wav", volume = 0.8, pitch = { 1.6, 1.8 } },
	Parry = { id = "rbxasset://sounds/unsheath.wav", volume = 1, pitch = { 1.8, 2 } },
	GuardBreak = { id = "rbxasset://sounds/unsheath.wav", volume = 1, pitch = { 0.5, 0.55 } },
	Dash = { id = "rbxasset://sounds/swordslash.wav", volume = 0.45, pitch = { 0.5, 0.6 } },
	Jump = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.5, pitch = { 1.1, 1.2 } },
	Land = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.6, pitch = { 0.9, 1 } },
	Cast = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.7, pitch = { 1.4, 1.6 } },
	Boom = { id = "rbxasset://sounds/swordlunge.wav", volume = 1, pitch = { 0.3, 0.36 } },
	Beam = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.9, pitch = { 0.6, 0.7 } },
	Release = { id = "rbxasset://sounds/unsheath.wav", volume = 1, pitch = { 0.6, 0.65 } },
	Ultimate = { id = "rbxasset://sounds/swordlunge.wav", volume = 1, pitch = { 0.25, 0.3 } },
	UIClick = { id = "rbxasset://sounds/swordslash.wav", volume = 0.25, pitch = { 2.4, 2.6 } },
	LevelUp = { id = "rbxasset://sounds/unsheath.wav", volume = 0.8, pitch = { 1.4, 1.5 } },
}

return Sounds

-- NPCs com diálogo. O DialogueService monta as opções dinamicamente (missões, loja, forja).
local NPCs = {
	MentorShinigami = {
		name = "Capitã Ayame Shirogane",
		title = "Mentora Shinigami",
		zone = "Karakura",
		-- na borda da praça, perto de onde o jogador nasce
		position = Vector3.new(18, 0, -38),
		look = {
			skin = Color3.fromRGB(240, 210, 180),
			robe = Color3.fromRGB(18, 18, 22),
			haori = Color3.fromRGB(240, 240, 240),
			hair = Color3.fromRGB(30, 30, 40),
		},
		-- capitã: cabelo longo preto, haori branco com forro lilás, katana na cintura
		style = {
			skin = Color3.fromRGB(240, 210, 180),
			hair = { kind = "long", color = Color3.fromRGB(30, 30, 40) },
			eyes = Color3.fromRGB(110, 80, 170),
			brows = "calm",
			outfit = "captain",
			colors = { haori = Color3.fromRGB(242, 242, 245), lining = Color3.fromRGB(120, 90, 170) },
			props = { "katana" },
		},
		greeting = "Sua Zanpakutō ainda dorme. Ouça-a — e ela responderá com seu nome.",
		lore = {
			"Shikai é o primeiro diálogo com a sua alma. Bankai é quando ela se manifesta por inteiro.",
			"O Shunpo não é velocidade, é a ausência de hesitação. Use o dash (Q) entre os golpes.",
			"Aparar exige coragem: aperte F no último instante antes do impacto.",
		},
		faction = "Shinigami",
		roles = { "Mentor" },
	},
	MentorHollow = {
		name = "Vex Oscura",
		title = "Arrancar Renegada",
		zone = "Karakura",
		-- calçada da avenida oeste, perto da margem do rio
		position = Vector3.new(-138.8, 0.6, 112),
		facing = Vector3.new(-1, 0, 0),
		look = {
			skin = Color3.fromRGB(235, 225, 210),
			robe = Color3.fromRGB(240, 238, 232),
			haori = Color3.fromRGB(20, 20, 20),
			hair = Color3.fromRGB(20, 20, 25),
			mask = true,
		},
		-- Arrancar: jaqueta branca de gola alta, cabelo selvagem, fragmento de máscara com chifre
		style = {
			skin = Color3.fromRGB(235, 225, 210),
			hair = { kind = "wild", color = Color3.fromRGB(25, 25, 30) },
			eyes = Color3.fromRGB(80, 220, 200),
			brows = "sly",
			outfit = "arrancar",
			mask = "horn",
			props = { "katana" },
			colors = { saya = Color3.fromRGB(240, 238, 232), tsuka = Color3.fromRGB(30, 30, 35) },
		},
		greeting = "Fome é força. Aprenda a controlá-la e o deserto se curvará.",
		lore = {
			"Resurrección devolve ao Arrancar sua verdadeira forma. Não tenha medo do monstro.",
			"O Cero cresce com seu Espírito. Distribua pontos em Espírito se gosta de destruir à distância.",
		},
		faction = "Hollow",
		roles = { "Mentor" },
	},
	Soma = {
		name = "Velho Sōma",
		title = "Lojista e Ferreiro",
		zone = "Karakura",
		-- dentro da rua comercial coberta
		position = Vector3.new(-75, 0, 60),
		facing = Vector3.new(0, 0, -1), -- de frente para a entrada da rua coberta
		look = {
			skin = Color3.fromRGB(220, 190, 160),
			robe = Color3.fromRGB(70, 90, 70),
			haori = Color3.fromRGB(40, 40, 40),
			hair = Color3.fromRGB(230, 230, 230),
		},
		-- lojista: chapéu-balde listrado, quimono verde, haori escuro, bengala, barba branca
		style = {
			skin = Color3.fromRGB(220, 190, 160),
			hair = { kind = "slick", color = Color3.fromRGB(230, 230, 230) },
			eyes = Color3.fromRGB(90, 70, 50),
			brows = "soft",
			outfit = "shopkeeper",
			beard = Color3.fromRGB(235, 235, 235),
			props = { "cane" },
		},
		greeting = "Balas de alma, lâminas reforjadas... e se trouxer materiais, forjo algo melhor.",
		lore = { "Fragmentos de máscara caem de qualquer Hollow. Junte-os e eu faço o resto." },
		roles = { "Shop", "Forge" },
	},
	Akane = {
		name = "Akane",
		title = "Estudante Médium",
		zone = "Karakura",
		-- calçada da avenida central, no portão da escola
		position = Vector3.new(11.2, 0.6, 104),
		facing = Vector3.new(-1, 0, 0),
		look = {
			skin = Color3.fromRGB(245, 215, 190),
			robe = Color3.fromRGB(40, 50, 90),
			haori = Color3.fromRGB(220, 220, 230),
			hair = Color3.fromRGB(120, 60, 40),
		},
		-- estudante médium: corte chanel castanho, uniforme de marinheiro, livros
		style = {
			skin = Color3.fromRGB(245, 215, 190),
			hair = { kind = "bob", color = Color3.fromRGB(120, 60, 40) },
			eyes = Color3.fromRGB(150, 90, 50),
			brows = "soft",
			outfit = "school",
			props = { "books" },
		},
		greeting = "Eu vejo espíritos desde criança... Pode me ajudar com algumas tarefas hoje?",
		lore = { "As tarefas mudam todo dia. Volte amanhã para novas recompensas!" },
		roles = { "Daily" },
	},
	Kenji = {
		name = "Tenente Kenji",
		title = "Guarda do Seireitei",
		zone = "SoulSociety",
		position = Vector3.new(10, 0, -140),
		look = {
			skin = Color3.fromRGB(230, 200, 170),
			robe = Color3.fromRGB(18, 18, 22),
			haori = Color3.fromRGB(18, 18, 22),
			hair = Color3.fromRGB(20, 20, 20),
		},
		-- tenente: cabelo espetado, shihakushō, braçadeira de tenente, katana
		style = {
			skin = Color3.fromRGB(230, 200, 170),
			hair = { kind = "spiky", color = Color3.fromRGB(25, 25, 25) },
			eyes = Color3.fromRGB(60, 60, 70),
			brows = "stern",
			outfit = "lieutenant",
			props = { "katana" },
		},
		greeting = "Bem-vindo ao Seireitei. Treine no pátio, mas não cause confusão.",
		lore = { "Dizem que um Rei Leão governa as ruínas de Hueco Mundo. Só tolos vão até lá antes do Bankai." },
		roles = {},
	},
	Lilith = {
		name = "Lilith",
		title = "Informante do Deserto",
		zone = "HuecoMundo",
		position = Vector3.new(15, 0, -230),
		look = {
			skin = Color3.fromRGB(235, 225, 215),
			robe = Color3.fromRGB(240, 238, 232),
			haori = Color3.fromRGB(240, 238, 232),
			hair = Color3.fromRGB(230, 230, 240),
			mask = true,
		},
		-- informante Arrancar: cabelo longo branco, mandíbula de máscara
		style = {
			skin = Color3.fromRGB(235, 225, 215),
			hair = { kind = "long", color = Color3.fromRGB(232, 232, 242) },
			eyes = Color3.fromRGB(200, 60, 80),
			brows = "sly",
			outfit = "arrancar",
			mask = "jaw",
			colors = { sash = Color3.fromRGB(120, 30, 50) },
		},
		greeting = "Um shinigami... ou algo parecido. Leonhart sente seu Reiatsu. Cuidado.",
		lore = { "O Menos Sombrio no centro do deserto dispara Ceros enormes. Use o dash para escapar." },
		roles = {},
	},
}

return NPCs

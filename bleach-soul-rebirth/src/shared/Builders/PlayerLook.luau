-- Visual de anime do jogador: rosto (olhos com íris e brilho, sobrancelhas, boca) e cabelo em
-- mechas do NpcStyle no lugar do rosto/cabelo/chapéus do avatar. Mantém o tom de pele do avatar.
-- Cabelo, cor de cabelo, olhos e sobrancelha saem do UserId (cada jogador fica sempre igual e
-- diferente dos outros) e podem ser sobrescritos por `custom` (perfil) quando houver tela de
-- personalização.
local NpcStyle = require(script.Parent.NpcStyle)

local PlayerLook = {}

local HAIR_COLORS = {
	Color3.fromRGB(28, 24, 26), -- preto
	Color3.fromRGB(70, 46, 32), -- castanho
	Color3.fromRGB(232, 120, 40), -- laranja
	Color3.fromRGB(236, 232, 226), -- branco
	Color3.fromRGB(196, 40, 52), -- vermelho
	Color3.fromRGB(40, 52, 96), -- azul-escuro
	Color3.fromRGB(226, 196, 120), -- loiro
	Color3.fromRGB(150, 150, 160), -- cinza
	Color3.fromRGB(120, 70, 140), -- roxo
}
local EYES = {
	Color3.fromRGB(70, 50, 40),
	Color3.fromRGB(120, 80, 40),
	Color3.fromRGB(60, 110, 170),
	Color3.fromRGB(60, 130, 90),
	Color3.fromRGB(150, 60, 50),
	Color3.fromRGB(170, 150, 60),
}
local BROWS = { "calm", "stern", "soft", "sly" }

export type Custom = { hair: string?, hairColor: number?, eyes: number?, brows: string? }

function PlayerLook.styleFor(userId: number, skin: Color3, custom: Custom?): any
	local rng = Random.new(math.abs(userId) + 7)
	local kinds = NpcStyle.HairKinds
	local c: Custom = custom or {}
	local hairColor = HAIR_COLORS[c.hairColor or rng:NextInteger(1, #HAIR_COLORS)] or HAIR_COLORS[1]
	return {
		skin = skin,
		hair = { kind = c.hair or kinds[rng:NextInteger(1, #kinds)], color = hairColor },
		eyes = EYES[c.eyes or rng:NextInteger(1, #EYES)] or EYES[1],
		brows = c.brows or BROWS[rng:NextInteger(1, #BROWS)],
		outfit = "none",
	}
end

-- Tira acessórios do avatar (cabelo, chapéus, acessórios de rosto) e monta rosto + cabelo do jogo.
function PlayerLook.apply(character: Model, userId: number, custom: Custom?)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			child:Destroy()
		end
	end
	NpcStyle.head(character, PlayerLook.styleFor(userId, head.Color, custom))
	character:SetAttribute("GameLook", true)
end

return PlayerLook

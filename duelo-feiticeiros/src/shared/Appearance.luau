-- APARÊNCIA dos lutadores com itens do catálogo do Roblox (opcional).
-- Deixe tudo em 0 / "" para usar os modelos feitos de peças (padrão). Se preencher algum ID, o servidor monta
-- um avatar R15 com esses itens (Players:CreateHumanoidModelFromDescription) e a cinemática usa esse avatar
-- no lugar do modelo de peças, com as mesmas poses e golpes.
--   shirt / pants : ID da Camisa / Calça clássica (o número do link do catálogo)
--   hair          : IDs de cabelo, separados por vírgula ("123,456")
--   accessories   : outros acessórios (chapéu, rosto, costas...), separados por vírgula
--   face          : ID de rosto (0 = padrão)
--   skin          : cor da pele (nil = cor padrão do personagem)
-- Observação: só carregam itens públicos do catálogo; se algum falhar, a cinemática volta para o modelo de peças.
local Appearance = {}

Appearance.Fighters = {
	ren = { shirt = 0, pants = 0, hair = "", accessories = "", face = 0, skin = nil :: Color3? },
	akane = { shirt = 0, pants = 0, hair = "", accessories = "", face = 0, skin = nil :: Color3? },
}

function Appearance.uses(key: string): boolean
	local a = Appearance.Fighters[key]
	return a ~= nil and ((a.shirt or 0) > 0 or (a.pants or 0) > 0 or (a.hair or "") ~= "" or (a.accessories or "") ~= "" or (a.face or 0) > 0)
end

function Appearance.anyUsed(): boolean
	for key in pairs(Appearance.Fighters) do
		if Appearance.uses(key) then
			return true
		end
	end
	return false
end

return Appearance

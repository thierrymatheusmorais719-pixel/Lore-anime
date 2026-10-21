-- Registro de serviços. O Main preenche antes de Init; serviços acessam outros em tempo de
-- execução via Registry.X (evita require circular entre serviços).
local Registry = {} :: { [string]: any }
return Registry

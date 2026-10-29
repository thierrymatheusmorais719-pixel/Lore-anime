-- Cenários do servidor (TransformationService + AbilityService reais) sobre o simulador.
local SIM = __SIM
local Players = game:GetService("Players")
local Timeline = require("Timeline")
local Config = require("Config")

local formCalls = {}
__src.ModelKit = function()
	return {
		isR15 = function(char) return char:FindFirstChildOfClass("Humanoid").RigType == "R15" end,
		build = function(char) char._built = true end,
		currentForm = function(char) return char._form or "Ichigo" end,
		setForm = function(char, form, t) char._form = form; table.insert(formCalls, form) end,
		refresh = function(char) char._refreshed = (char._refreshed or 0) + 1 end,
	}
end
-- SkinService falso: registra chamadas; quais formas têm skin é controlado pelo teste
local SKIN = { forms = {}, log = {}, saved = {} }
__src.SkinService = function()
	return {
		hasSkin = function(form) return SKIN.forms[form] == true end,
		apply = function(p, form) table.insert(SKIN.log, p.Name .. ":apply:" .. form .. "@" .. string.format("%.1f", SIM.clock)); SKIN.saved[p] = true; return true end,
		restore = function(p) table.insert(SKIN.log, p.Name .. ":restore@" .. string.format("%.1f", SIM.clock)); SKIN.saved[p] = nil; return true end,
		hasSaved = function(p) return SKIN.saved[p] == true end,
		forget = function(p) SKIN.saved[p] = nil end,
	}
end
__src.Remotes = function()
	return { get = function(name) return SIM.getRemote(name) end }
end

local TS = require("TransformationService")
local AS = require("AbilityService")
TS.init()
AS.init()

local passed, failed = 0, {}
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then passed += 1 else table.insert(failed, name .. ": " .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " esperado " .. tostring(b) .. " obtido " .. tostring(a), 2) end end
local V = Vector3.new

local function reqTransform(p) SIM.getRemote("RequestTransform").OnServerEvent:Fire(p) end
local function reqAbility(p, aim) SIM.getRemote("RequestAbility").OnServerEvent:Fire(p, aim) end
local function hum(p) return p.Character:FindFirstChildOfClass("Humanoid") end
local function root(p) return p.Character:FindFirstChild("HumanoidRootPart") end
local function fresh(name, pos, rig)
	local p = SIM.newPlayer(name, pos or V(0, 3, 0), rig)
	Players.PlayerAdded:Fire(p)
	p.CharacterAdded:Fire(p.Character)
	return p
end
-- gasta o cooldown de rate limit (RateLimiter usa o relógio virtual)
local function wait(dt) SIM.advance(dt) end

------------------------------------------------------------------------------------------------
test("transformação completa: trava, eventos do servidor, troca de modelo, fim e restauração", function()
	local p = fresh("A", V(0, 3, 0))
	local obs = fresh("Near", V(20, 3, 0))
	local far = fresh("Far", V(500, 3, 0))
	local h, r = hum(p), root(p)
	reqTransform(p)
	eq(p:GetAttribute("MugetsuCutscene"), true)
	eq(h.WalkSpeed, 0, "WalkSpeed travado")
	eq(r.Anchored, true, "HRP ancorado")
	assert(p.Character._children.ForceField, "invulnerável durante a cena")
	local start = SIM.getRemote("CutsceneStart"):last(p)
	assert(start and start.startTime > SIM.clock, "startTime com margem de preparo")
	eq(start.duration, Timeline.Duration)
	assert(SIM.getRemote("CutsceneObserve"):last(obs), "observador próximo notificado")
	eq(SIM.getRemote("CutsceneObserve"):count(far), 0, "jogador distante não recebe")
	eq(p.Character._form, nil, "ainda Ichigo antes do branco")

	SIM.advance(0.4 + 17.0) -- t = 17.0 (antes do MorphSwap em 17.4)
	eq(p.Character._form, nil, "sem troca antes do tempo")
	SIM.advance(0.6)
	eq(p.Character._form, "Mugetsu", "troca real do modelo no evento MorphSwap")
	eq(p:GetAttribute("MugetsuForm"), true)
	eq(p:GetAttribute("MugetsuAbilityReady"), false, "habilidade ainda bloqueada")
	SIM.advance(12.6)
	eq(p:GetAttribute("MugetsuAbilityReady"), true, "habilidade liberada no fim")
	assert(SIM.getRemote("CutsceneEnd"):last(p), "CutsceneEnd enviado")
	eq(SIM.getRemote("CutsceneCancel"):count(p), 0)
	eq(h.WalkSpeed, 16, "WalkSpeed restaurado")
	eq(h.JumpHeight, 7.2, "JumpHeight restaurado")
	eq(h.AutoRotate, true)
	eq(r.Anchored, false, "HRP desancorado")
	eq(p.Character._children.ForceField, nil, "ForceField removido")
	eq(p:GetAttribute("MugetsuCutscene"), false)
	eq(TS.isInCutscene(p), false)
	eq(SIM.Heartbeat:Count() >= 0, true)
end)

test("pedido duplicado durante a cena e re-transformação são recusados", function()
	local p = fresh("B")
	reqTransform(p)
	local before = SIM.getRemote("CutsceneStart"):count(p)
	wait(1.1); reqTransform(p)
	eq(SIM.getRemote("CutsceneStart"):count(p), before, "não reinicia a cena em andamento")
	wait(31)
	reqTransform(p)
	eq(SIM.getRemote("CutsceneStart"):count(p), before, "já está em Mugetsu")
	local n = SIM.getRemote("Notify"):last(p)
	assert(n and n.text:find("Mugetsu"), "mensagem ao jogador")
end)

test("cancelamento por morte ANTES da troca: forma permanece Ichigo, controles restaurados", function()
	local p = fresh("C")
	local h, r = hum(p), root(p)
	reqTransform(p)
	wait(6)
	h.Health = 0; h.Died:Fire()
	assert(SIM.getRemote("CutsceneCancel"):last(p), "cancelamento notificado")
	eq(p:GetAttribute("MugetsuForm"), false)
	eq(p:GetAttribute("MugetsuAbilityReady"), false)
	eq(h.WalkSpeed, 16); eq(r.Anchored, false)
	eq(p:GetAttribute("MugetsuCutscene"), false)
	wait(40) -- nenhum evento tardio pode aplicar a troca
	eq(p.Character._form, nil, "sem troca após cancelamento")
	eq(TS.isInCutscene(p), false)
end)

test("cancelamento DEPOIS da troca: mantém Mugetsu + habilidade e devolve os controles", function()
	local p = fresh("D")
	local h, r = hum(p), root(p)
	reqTransform(p)
	wait(18.5)
	eq(p.Character._form, "Mugetsu")
	TS.cancel(p, "teste")
	eq(p:GetAttribute("MugetsuForm"), true)
	eq(p:GetAttribute("MugetsuAbilityReady"), true)
	eq(h.WalkSpeed, 16); eq(r.Anchored, false)
	assert(p.Character._children.ForceField == nil)
end)

test("jogador sai no meio da cena: sessão limpa sem erro", function()
	local p = fresh("E")
	reqTransform(p)
	wait(3)
	SIM.removePlayer(p)
	eq(TS.isInCutscene(p), false)
	wait(35) -- nada deve quebrar ao varrer eventos
end)

test("watchdog: salto de relógio gigante encerra e restaura", function()
	local p = fresh("F")
	local h, r = hum(p), root(p)
	reqTransform(p)
	SIM.clock += 200 -- simula travamento do servidor
	SIM.advance(1 / 30)
	eq(TS.isInCutscene(p), false)
	eq(h.WalkSpeed, 16); eq(r.Anchored, false)
	assert(SIM.getRemote("CutsceneCancel"):last(p), "watchdog notifica cancelamento")
end)

test("R6 é recusado com mensagem; nada é travado", function()
	local p = fresh("G", V(0, 3, 0), "R6")
	reqTransform(p)
	eq(TS.isInCutscene(p), false)
	eq(hum(p).WalkSpeed, 16)
	assert(SIM.getRemote("Notify"):last(p).text:find("R15"))
end)

test("personagem morto não inicia", function()
	local p = fresh("H")
	hum(p).Health = 0
	reqTransform(p)
	eq(TS.isInCutscene(p), false)
end)

test("rate limit do pedido de transformação", function()
	local p = fresh("I")
	for _ = 1, 50 do reqTransform(p) end
	eq(SIM.getRemote("CutsceneStart"):count(p), 1, "spam inicia uma única cena")
	wait(31)
end)

test("forma expira após FormDuration e volta a Ichigo", function()
	local p = fresh("J")
	reqTransform(p)
	wait(31)
	eq(p.Character._form, "Mugetsu")
	wait(Config.Transform.FormDuration + 1)
	eq(p.Character._form, "Ichigo")
	eq(p:GetAttribute("MugetsuForm"), false)
end)

------------------------------------------------------------------------------------------------
-- Habilidade
------------------------------------------------------------------------------------------------
local function mugetsu(name, pos)
	local p = fresh(name, pos)
	reqTransform(p)
	wait(31)
	assert(p:GetAttribute("MugetsuAbilityReady") == true, "preparo: habilidade pronta")
	return p
end
local function dummy(pos)
	local m = SIM.newCharacter(pos)
	m._children.Humanoid.MaxHealth = 200; m._children.Humanoid.Health = 200
	m.IsA = function(_, c) return c == "Model" end
	return m
end

test("habilidade: servidor ignora quem não está na forma", function()
	local p = fresh("K")
	reqAbility(p, V(0, 0, -1))
	eq(SIM.getRemote("AbilityTelegraph"):count(p) + SIM.getRemote("AbilityCooldown"):count(p), 0)
end)

test("habilidade: telegraph -> disparo -> dano único e correto; cooldown validado no servidor", function()
	local p = mugetsu("L", V(1000, 3, 0))
	local inLine = dummy(V(1000, 3, -40))
	local offLine = dummy(V(1030, 3, -40))
	local tooFar = dummy(V(1000, 3, -150))
	local behind = dummy(V(1000, 3, 30))
	SIM.tagged = { MugetsuTarget = { inLine, offLine, tooFar, behind } }
	wait(0.3)
	reqAbility(p, V(0, 0, -1))
	local tele = SIM.getRemote("AbilityTelegraph"):last(p)
	assert(tele, "telegraph enviado")
	eq(tele.telegraph, Config.Ability.TelegraphTime)
	local cd = SIM.getRemote("AbilityCooldown"):last(p)
	assert(cd and cd.duration == Config.Ability.Cooldown, "cooldown informado")
	eq(hum(p).WalkSpeed, 0, "parado durante telegraph")
	eq(SIM.getRemote("AbilityFire"):count(p), 0, "ainda não disparou")
	wait(Config.Ability.TelegraphTime + 0.05)
	assert(SIM.getRemote("AbilityFire"):last(p), "disparo após telegraph")
	eq(hum(p).WalkSpeed, 16, "movimento devolvido")
	wait(2)
	eq(inLine._children.Humanoid.damageTaken, Config.Ability.Damage, "alvo na linha leva dano exato, uma vez")
	eq(offLine._children.Humanoid.damageTaken, nil, "fora da faixa")
	eq(tooFar._children.Humanoid.damageTaken, nil, "além do alcance")
	eq(behind._children.Humanoid.damageTaken, nil, "atrás")
	-- segundo pedido dentro do cooldown
	local n = SIM.getRemote("AbilityTelegraph"):count(p)
	wait(0.5); reqAbility(p, V(0, 0, -1))
	eq(SIM.getRemote("AbilityTelegraph"):count(p), n, "cooldown bloqueia")
	-- cliente adulterado tentando 'limpar' o cooldown: nada muda
	wait(Config.Ability.Cooldown + 0.5)
	reqAbility(p, V(0, 0, -1))
	eq(SIM.getRemote("AbilityTelegraph"):count(p), n + 1, "após cooldown, libera")
	wait(3)
	SIM.tagged = nil
end)

test("habilidade: entradas inválidas não consomem cooldown", function()
	local p = mugetsu("M", V(2000, 3, 0))
	for _, bad in ipairs({ "x", 5, V(0 / 0, 0, 1), V(0, 9, 0) }) do
		wait(0.3); reqAbility(p, bad)
	end
	eq(SIM.getRemote("AbilityCooldown"):count(p), 0)
	wait(0.3); reqAbility(p, V(0, 0, -1))
	eq(SIM.getRemote("AbilityCooldown"):count(p), 1)
	wait(3)
end)

test("habilidade: spam de remote (rate limit) gera no máximo 1 conjuntura", function()
	local p = mugetsu("N", V(3000, 3, 0))
	wait(0.3)
	for _ = 1, 30 do reqAbility(p, V(0, 0, -1)) end
	eq(SIM.getRemote("AbilityTelegraph"):count(p), 1)
	wait(3)
end)

test("habilidade: mira oposta à frente do personagem é substituída pela frente", function()
	local p = mugetsu("O", V(4000, 3, 0))
	wait(0.3)
	reqAbility(p, V(0, 0, 1)) -- personagem olha -Z; cliente tenta mirar +Z
	local tele = SIM.getRemote("AbilityTelegraph"):last(p)
	assert(tele.dir.Z < 0, "direção forçada para a frente")
	wait(3)
end)

test("habilidade: morrer durante o telegraph cancela o disparo", function()
	local p = mugetsu("P", V(5000, 3, 0))
	wait(0.3)
	local fires = SIM.getRemote("AbilityFire"):count(p)
	reqAbility(p, V(0, 0, -1))
	hum(p).Health = 0
	wait(1.2)
	eq(SIM.getRemote("AbilityFire"):count(p), fires)
end)

test("múltiplos jogadores: cooldowns independentes e sem fogo em si mesmo", function()
	local a = mugetsu("Q1", V(6000, 3, 0))
	local b = mugetsu("Q2", V(6000, 3, -30))
	SIM.tagged = nil
	wait(0.3)
	reqAbility(a, V(0, 0, -1))
	wait(0.3)
	reqAbility(b, V(0, 0, -1))
	eq(SIM.getRemote("AbilityCooldown"):count(a), 1)
	eq(SIM.getRemote("AbilityCooldown"):count(b), 1)
	wait(2)
	eq(hum(b).damageTaken, Config.Ability.Damage, "B está na linha de A e leva dano")
	eq(hum(a).damageTaken, nil, "A (atrás de B, B atirou antes de A sair da frente) não se fere pelo próprio golpe")
end)

------------------------------------------------------------------------------------------------
-- Skins do catálogo
------------------------------------------------------------------------------------------------
local function logFor(name)
	local out = {}
	for _, l in ipairs(SKIN.log) do if l:sub(1, #name + 1) == name .. ":" then table.insert(out, l) end end
	return out
end

test("skin: Mugetsu carrega no começo do flash e só volta quando a forma acaba (RestoreAfter=Form)", function()
	SKIN.forms = { Mugetsu = true }
	local p = fresh("SK1", V(7000, 3, 0))
	local t0 = SIM.clock
	reqTransform(p)
	SIM.advance(0.4 + 16.5)
	eq(#logFor("SK1"), 0, "nada aplicado antes do flash")
	SIM.advance(0.3)
	local l = logFor("SK1")
	eq(#l, 1); assert(l[1]:find("apply:Mugetsu"), l[1])
	SIM.advance(14)
	eq(#logFor("SK1"), 1, "fim da cena não restaura com RestoreAfter=Form")
	assert(p.Character._refreshed and p.Character._refreshed >= 1, "kit remontado depois da skin")
	SIM.advance(Config.Transform.FormDuration + 1)
	l = logFor("SK1")
	eq(#l, 2); assert(l[2]:find("restore"), "restaura ao fim da forma")
	SKIN.forms = {}
	_ = t0
end)

test("skin: Ichigo aplicada ANTES da cena começar; cancelar antes da troca restaura", function()
	SKIN.forms = { Ichigo = true, Mugetsu = true }
	local p = fresh("SK2", V(8000, 3, 0))
	reqTransform(p)
	local l = logFor("SK2")
	eq(#l, 1); assert(l[1]:find("apply:Ichigo"))
	local st = SIM.getRemote("CutsceneStart"):last(p)
	assert(st and st.startTime > SIM.clock, "cena anunciada depois da skin, com margem")
	SIM.advance(5)
	hum(p).Health = 0; hum(p).Died:Fire()
	l = logFor("SK2")
	assert(l[#l]:find("restore"), "cancelamento antes da troca volta a aparência original")
	eq(hum(p).WalkSpeed, 16)
	SKIN.forms = {}
end)

test("skin: cancelar DEPOIS da troca mantém a skin do Mugetsu (forma continua)", function()
	SKIN.forms = { Mugetsu = true }
	local p = fresh("SK3", V(9000, 3, 0))
	reqTransform(p)
	SIM.advance(0.4 + 18.5)
	TS.cancel(p, "teste")
	local l = logFor("SK3")
	eq(#l, 1, "sem restore: a forma Mugetsu segue ativa")
	eq(p:GetAttribute("MugetsuForm"), true)
	SKIN.forms = {}
end)

if #failed > 0 then
	return "FAILED " .. #failed .. " / " .. (passed + #failed) .. "\n" .. table.concat(failed, "\n")
end
return "ALL PASSED " .. passed .. " cenários de servidor"

-- Exporta a INTERFACE REAL do cliente (ScreenGuis criados pelos controladores, ligados ao servidor
-- simulado) com o layout calculado (UDim2, AnchorPoint, UIListLayout, UIGridLayout, UIPadding, UIScale da
-- tela), cores, gradientes, cantos, contornos e textos. tools/preview/ui.html desenha o resultado.
-- Uso: python3 tools/run_tests.py luau --uiexport > saida.txt  (linhas "UISCENE <nome> {json}")
local Worlds = require(__proxy("Shared/Config/Worlds"))
for _, id in ipairs(Worlds.Order) do
	local w = Worlds.Info[id]
	table.insert(SIM.groundPlanes, { center = w.center, radius = w.radius, y = w.center.Y })
end
__modules["Server/Main"](__proxy("Server/Main"))
SIM.run(0.5)

local S = {
	DataService = require(__proxy("Server/Services/DataService")),
	PetService = require(__proxy("Server/Services/PetService")),
	LuckService = require(__proxy("Server/Services/LuckService")),
}
local InventoryLogic = require(__proxy("Shared/Logic/InventoryLogic"))
local lp = SIM.addPlayer("Jogador", 1)
SIM.run(1)
local d = S.DataService.get(lp)
d.coins, d.essence, d.astral = 1254300, 3420, 87
d.worlds.crystal = true
local team = {}
for _, spec in ipairs({ { "bloomfox", "Golden" }, { "verdantwolf_1" }, { "grovekin" }, { "mossling" }, { "kit_1" }, { "owlet_1", "Radiant" }, { "thornpup" },
	{ "elderstag_1" }, { "spectralhound_1" }, { "sylvanox" }, { "hop_1" }, { "leafcat_1" }, { "golemling_1" }, { "turfmammoth_1" }, { "fawn_1" }, { "cap_1" } }) do
	local pet = InventoryLogic.addPet(d, spec[1], spec[2], os.time(), "preview")
	pet.level = math.random(3, 30)
	if #team < 4 then
		table.insert(team, pet.uid)
	end
end
d.team = team
S.PetService.spawnTeam(lp)

-- cliente real
local Players = game:GetService("Players")
SIM.localPlayer = lp
Players.LocalPlayer = lp
local pg = Instance.new("PlayerGui")
pg.Name = "PlayerGui"
pg.Parent = lp
local uis = Instance.new("UserInputService")
uis.TouchEnabled = false
uis.KeyboardEnabled = true
SIM.registerService("UserInputService", uis)
local VW, VH = 1600, 900
local cam = Instance.new("Camera")
cam.CFrame = CFrame.new(0, 50, 0)
cam.ViewportSize = Vector2.new(VW, VH)
workspace.CurrentCamera = cam
local rs = game:GetService("RunService")
rs.RenderStepped = SIM.Signal()
rs.Stepped = SIM.Signal()
local bound = {}
function rs.BindToRenderStep(_, name, _priority, fn)
	bound[name] = fn
end
function rs.UnbindFromRenderStep(_, name)
	bound[name] = nil
end
local function frames(n)
	for _ = 1, n do
		rs.Stepped:Fire(SIM.now, 1 / 60)
		for _, fn in pairs(bound) do
			fn(1 / 60)
		end
		rs.RenderStepped:Fire(1 / 60)
		SIM.run(1 / 60)
	end
end
lp:SetAttribute("World", "verdant")
__modules["Client/Main"](__proxy("Client/Main"))
frames(10)
S.DataService.pushState(lp)
S.LuckService.push(lp, true)
frames(40)

-------------------------------------------------------------------------------
-- Layout e serialização
-------------------------------------------------------------------------------

local GUI_CLASSES = { Frame = true, TextLabel = true, TextButton = true, TextBox = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true, ViewportFrame = true, CanvasGroup = true }
local INSET = 36 -- barra superior do Roblox (IgnoreGuiInset = false)

local function num(x)
	return string.format("%.1f", x)
end
local function col(c)
	if not c then
		return "null"
	end
	return string.format("[%d,%d,%d]", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function jstr(s)
	s = tostring(s or "")
	s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", ""):gsub("\t", " ")
	return '"' .. s .. '"'
end
local function udim2(u, def)
	if type(u) ~= "table" or not u.X then
		return def or { xs = 0, xo = 100, ys = 0, yo = 100 }
	end
	return { xs = u.X.Scale, xo = u.X.Offset, ys = u.Y.Scale, yo = u.Y.Offset }
end
local function udim(u, size)
	if type(u) ~= "table" then
		return 0
	end
	return (u.Scale or 0) * size + (u.Offset or 0)
end
local function child(obj, cls)
	for _, c in ipairs(obj:GetChildren()) do
		if c.ClassName == cls then
			return c
		end
	end
	return nil
end

-- sequências (ColorSequence/NumberSequence do mock: argumentos posicionais)
local function colorKeys(seq)
	if type(seq) ~= "table" then
		return nil
	end
	local a1, a2 = seq[1], seq[2]
	if type(a1) == "table" and a1.R ~= nil then
		return { { 0, a1 }, { 1, a2 or a1 } }
	end
	if type(a1) == "table" then
		local out = {}
		for _, kp in ipairs(a1) do
			table.insert(out, { kp[1], kp[2] })
		end
		return out
	end
	return nil
end
local function numKeys(seq)
	if type(seq) ~= "table" then
		return nil
	end
	local a1, a2 = seq[1], seq[2]
	if type(a1) == "number" then
		return { { 0, a1 }, { 1, a2 or a1 } }
	end
	if type(a1) == "table" then
		local out = {}
		for _, kp in ipairs(a1) do
			table.insert(out, { kp[1], kp[2] })
		end
		return out
	end
	return nil
end
local function gradJson(g)
	if not g or g.Enabled == false then
		return "null"
	end
	local ck = colorKeys(g.Color) or { { 0, Color3.new(1, 1, 1) }, { 1, Color3.new(1, 1, 1) } }
	local tk = numKeys(g.Transparency) or { { 0, 0 }, { 1, 0 } }
	local cs, ts = {}, {}
	for _, k in ipairs(ck) do
		table.insert(cs, string.format("[%s,%s]", num(k[1]), col(k[2])))
	end
	for _, k in ipairs(tk) do
		table.insert(ts, string.format("[%s,%s]", num(k[1]), num(k[2])))
	end
	local off = g.Offset
	return string.format('{"rot":%s,"c":[%s],"t":[%s],"ox":%s,"oy":%s}', num(g.Rotation or 0), table.concat(cs, ","), table.concat(ts, ","), num(off and off.X or 0), num(off and off.Y or 0))
end

local out = {}
local scaleK = 1
local clip = nil -- retângulo de recorte atual (ClipsDescendants / ScrollingFrame), em pixels finais

local function emit(obj, r)
	local cls = obj.ClassName
	local parts = { string.format('"k":"%s","x":%s,"y":%s,"w":%s,"h":%s', cls, num(r.x * scaleK), num(INSET + r.y * scaleK), num(r.w * scaleK), num(r.h * scaleK)) }
	if (obj.Rotation or 0) ~= 0 then
		table.insert(parts, '"rot":' .. num(obj.Rotation))
	end
	local bgT = obj.BackgroundTransparency
	if bgT == nil then
		bgT = 0
	end
	if cls ~= "ViewportFrame" then
		table.insert(parts, '"bg":' .. col(obj.BackgroundColor3 or Color3.new(1, 1, 1)) .. ',"bgT":' .. num(bgT))
	else
		table.insert(parts, '"bg":' .. col(obj.BackgroundColor3 or Color3.new(0.2, 0.2, 0.25)) .. ',"bgT":' .. num(bgT))
	end
	local corner = child(obj, "UICorner")
	if corner then
		local cr = corner.CornerRadius
		local px = type(cr) == "table" and ((cr.Scale or 0) * math.min(r.w, r.h) + (cr.Offset or 0)) or 8
		table.insert(parts, '"rad":' .. num(math.min(px, math.min(r.w, r.h) / 2) * scaleK))
	end
	local stroke = child(obj, "UIStroke")
	if stroke and stroke.Enabled ~= false then
		local tg = child(stroke, "UIGradient")
		table.insert(parts, string.format('"st":{"c":%s,"th":%s,"t":%s,"mode":"%s","g":%s}', col(stroke.Color or Color3.new(0, 0, 0)), num((stroke.Thickness or 1) * scaleK),
			num(stroke.Transparency or 0), stroke.ApplyStrokeMode and stroke.ApplyStrokeMode.Name or "Contextual", gradJson(tg)))
	end
	local grad = child(obj, "UIGradient")
	if grad then
		table.insert(parts, '"gr":' .. gradJson(grad))
	end
	if cls == "TextLabel" or cls == "TextButton" or cls == "TextBox" then
		local text = obj.Text or ""
		if text ~= "" then
			local fnt = obj.Font and obj.Font.Name or "GothamBold"
			local xa = obj.TextXAlignment and obj.TextXAlignment.Name or "Center"
			local ya = obj.TextYAlignment and obj.TextYAlignment.Name or "Center"
			local textStroke = child(obj, "UIStroke")
			table.insert(parts, string.format('"tx":%s,"ts":%s,"tsc":%s,"f":"%s","tc":%s,"tt":%s,"tsk":%s,"tst":%s,"xa":"%s","ya":"%s","rich":%s,"wrap":%s', jstr(text), num((obj.TextSize or 14) * scaleK),
				obj.TextScaled and "true" or "false", fnt, col(obj.TextColor3 or Color3.new(0, 0, 0)), num(obj.TextTransparency or 0), col(obj.TextStrokeColor3 or Color3.new(0, 0, 0)),
				num(obj.TextStrokeTransparency == nil and 1 or obj.TextStrokeTransparency), xa, ya, obj.RichText and "true" or "false", obj.TextWrapped and "true" or "false"))
			local _ = textStroke
		end
	end
	if cls == "ViewportFrame" and obj:GetAttribute("Species") then
		table.insert(parts, '"sp":' .. jstr(obj:GetAttribute("Species")))
	end
	if clip then
		table.insert(parts, string.format('"cl":[%s,%s,%s,%s]', num(clip.x), num(clip.y), num(clip.w), num(clip.h)))
	end
	table.insert(out, "{" .. table.concat(parts, ",") .. "}")
end

-- calcula o retângulo dos filhos de `obj` (que ocupa `r`) e desce na árvore
local layoutChildren

local function place(obj, r)
	if obj.Visible == false then
		return
	end
	emit(obj, r)
	local saved = clip
	if obj.ClipsDescendants == true or obj.ClassName == "ScrollingFrame" then
		local x0, y0 = r.x * scaleK, INSET + r.y * scaleK
		local x1, y1 = x0 + r.w * scaleK, y0 + r.h * scaleK
		if clip then
			x0, y0 = math.max(x0, clip.x), math.max(y0, clip.y)
			x1, y1 = math.min(x1, clip.x + clip.w), math.min(y1, clip.y + clip.h)
		end
		clip = { x = x0, y = y0, w = math.max(0, x1 - x0), h = math.max(0, y1 - y0) }
	end
	layoutChildren(obj, r)
	clip = saved
end

local function sortedGui(obj)
	local list = {}
	for i, c in ipairs(obj:GetChildren()) do
		if GUI_CLASSES[c.ClassName] and c.Visible ~= false then
			table.insert(list, { obj = c, i = i })
		end
	end
	return list
end

layoutChildren = function(obj, r)
	local pad = child(obj, "UIPadding")
	local cr = { x = r.x, y = r.y, w = r.w, h = r.h }
	if pad then
		local pl, pr = udim(pad.PaddingLeft, r.w), udim(pad.PaddingRight, r.w)
		local pt, pb = udim(pad.PaddingTop, r.h), udim(pad.PaddingBottom, r.h)
		cr = { x = r.x + pl, y = r.y + pt, w = math.max(0, r.w - pl - pr), h = math.max(0, r.h - pt - pb) }
	end
	local kids = sortedGui(obj)
	local list, grid = child(obj, "UIListLayout"), child(obj, "UIGridLayout")
	local function sizeOf(c, base)
		local s = udim2(c.Size)
		return base.w * s.xs + s.xo, base.h * s.ys + s.yo
	end
	if grid then
		table.sort(kids, function(a, b)
			local la, lb = a.obj.LayoutOrder or 0, b.obj.LayoutOrder or 0
			if la ~= lb then
				return la < lb
			end
			return a.i < b.i
		end)
		local cs = udim2(grid.CellSize, { xs = 0, xo = 100, ys = 0, yo = 100 })
		local cp = udim2(grid.CellPadding, { xs = 0, xo = 5, ys = 0, yo = 5 })
		local cw, ch = cr.w * cs.xs + cs.xo, cr.h * cs.ys + cs.yo
		local px, py = cr.w * cp.xs + cp.xo, cr.h * cp.ys + cp.yo
		local cols = math.max(1, math.floor((cr.w + px) / (cw + px)))
		for idx, k in ipairs(kids) do
			local col_, row = (idx - 1) % cols, math.floor((idx - 1) / cols)
			local cell = { x = cr.x + col_ * (cw + px), y = cr.y + row * (ch + py), w = cw, h = ch }
			place(k.obj, cell)
		end
		return
	end
	if list then
		table.sort(kids, function(a, b)
			local la, lb = a.obj.LayoutOrder or 0, b.obj.LayoutOrder or 0
			if la ~= lb then
				return la < lb
			end
			return a.i < b.i
		end)
		local vertical = not (list.FillDirection and list.FillDirection.Name == "Horizontal")
		local padPx = udim(list.Padding, vertical and cr.h or cr.w)
		local sizes, total = {}, 0
		for _, k in ipairs(kids) do
			local w, h = sizeOf(k.obj, cr)
			if k.obj.AutomaticSize and k.obj.AutomaticSize.Name ~= "None" then
				-- altura automática: mede o conteúdo (aproximação: maior fundo dos filhos)
				local tmp = { x = 0, y = 0, w = w, h = h }
				local maxB = h
				local function measure(o, rr)
					local bottom = 0
					local kk = sortedGui(o)
					local l2 = child(o, "UIListLayout")
					local p2 = child(o, "UIPadding")
					local ptop = p2 and udim(p2.PaddingTop, rr.h) or 0
					local pbot = p2 and udim(p2.PaddingBottom, rr.h) or 0
					local acc = ptop
					for _, c2 in ipairs(kk) do
						local s2 = udim2(c2.obj.Size)
						local h2 = rr.h * s2.ys + s2.yo
						if l2 then
							acc += h2 + udim(l2.Padding, rr.h)
							bottom = acc
						else
							local p = udim2(c2.obj.Position, { xs = 0, xo = 0, ys = 0, yo = 0 })
							bottom = math.max(bottom, p.yo + h2)
						end
					end
					return bottom + pbot
				end
				maxB = math.max(h, measure(k.obj, tmp))
				h = maxB
				k.autoH = h
			end
			sizes[k] = { w, h }
			total += (vertical and h or w)
		end
		total += math.max(0, #kids - 1) * padPx
		local cursor
		local valign = list.VerticalAlignment and list.VerticalAlignment.Name or "Top"
		local halign = list.HorizontalAlignment and list.HorizontalAlignment.Name or "Left"
		if vertical then
			cursor = valign == "Bottom" and (cr.y + cr.h - total) or valign == "Center" and (cr.y + (cr.h - total) / 2) or cr.y
		else
			cursor = halign == "Right" and (cr.x + cr.w - total) or halign == "Center" and (cr.x + (cr.w - total) / 2) or cr.x
		end
		for _, k in ipairs(kids) do
			local w, h = sizes[k][1], sizes[k][2]
			local cell
			if vertical then
				local x = halign == "Center" and cr.x + (cr.w - w) / 2 or halign == "Right" and cr.x + cr.w - w or cr.x
				cell = { x = x, y = cursor, w = w, h = h }
				cursor += h + padPx
			else
				local y = valign == "Center" and cr.y + (cr.h - h) / 2 or valign == "Bottom" and cr.y + cr.h - h or cr.y
				cell = { x = cursor, y = y, w = w, h = h }
				cursor += w + padPx
			end
			place(k.obj, cell)
		end
		return
	end
	-- posicionamento livre: filhos em ordem de ZIndex (estável)
	table.sort(kids, function(a, b)
		local za, zb = a.obj.ZIndex or 1, b.obj.ZIndex or 1
		if za ~= zb then
			return za < zb
		end
		return a.i < b.i
	end)
	for _, k in ipairs(kids) do
		local c = k.obj
		local w, h = sizeOf(c, cr)
		local p = udim2(c.Position, { xs = 0, xo = 0, ys = 0, yo = 0 })
		local ap = c.AnchorPoint or Vector2.new(0, 0)
		local x = cr.x + cr.w * p.xs + p.xo - (ap.X or 0) * w
		local y = cr.y + cr.h * p.ys + p.yo - (ap.Y or 0) * h
		if c.AutomaticSize and c.AutomaticSize.Name ~= "None" then
			local maxB = 0
			for _, c2 in ipairs(sortedGui(c)) do
				local s2 = udim2(c2.obj.Size)
				local p2 = udim2(c2.obj.Position, { xs = 0, xo = 0, ys = 0, yo = 0 })
				maxB = math.max(maxB, p2.yo + h * s2.ys + s2.yo)
			end
			h = math.max(h, maxB)
		end
		place(c, { x = x, y = y, w = w, h = h })
	end
end

local function snapshot(name: string)
	frames(20)
	out = {}
	local guis = {}
	for _, g in ipairs(pg:GetChildren()) do
		if g.ClassName == "ScreenGui" and g.Enabled ~= false then
			table.insert(guis, g)
		end
	end
	table.sort(guis, function(a, b)
		return (a.DisplayOrder or 0) < (b.DisplayOrder or 0)
	end)
	for _, g in ipairs(guis) do
		clip = nil
		local sc = child(g, "UIScale")
		scaleK = sc and sc.Scale or 1
		local ignore = g.IgnoreGuiInset == true
		INSET = ignore and 0 or 36
		local root = { x = 0, y = 0, w = VW / scaleK, h = (VH - INSET) / scaleK }
		layoutChildren(g, root)
	end
	print(string.format('UISCENE %s {"w":%d,"h":%d,"items":[%s]}', name, VW, VH, table.concat(out, ",")))
end

local Panels = require(__proxy("Client/Controllers/Panels"))
snapshot("hud")
-- notificações reais vindas do servidor: toast, feed de drops e anúncio de raro
local Push = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("Push")
Push:FireClient(lp, "Toast", { text = "Missão concluída: <b>Primeiro Companheiro</b>!", kind = "quest" })
Push:FireClient(lp, "Drop", { source = "Thornling", items = { { item = "coins", amount = 120 }, { item = "verdant_sap", amount = 2 }, { item = "pet:Bloomfox", amount = 1, notable = true } } })
Push:FireClient(lp, "Announce", { player = "Bia", text = "Celestial Lumifox", rarity = "Celestial", remote = true })
snapshot("hud_fx")
-- cinemática de entrada de boss (barras, nome e título)
do
	local Push2 = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("Push")
	Push2:FireClient(lp, "BossIntro", { name = "Elderroot", title = "Guardião da Floresta Ancestral", color = Color3.fromRGB(120, 220, 110), players = 1,
		at = Vector3.new(60, 8, 0), radius = 6, time = 3 })
	frames(45)
	snapshot("cinematic")
	frames(200)
end
Panels.open("Pets")
snapshot("pets")
Panels.open("Map")
snapshot("map")
-- missões com a mineração de cristais (cristais e contratos do dia no perfil real do servidor)
do
	local DS = require(__proxy("Server/Services/DataService"))
	local d = DS.get(lp)
	if d then
		d.items.emerald_crystal = 14
		d.items.sapphire_crystal = 3
		d.mining.mined = 31
		d.mining.contracts = { day = math.floor(os.time() / 86400), ids = { "mc_emerald_s", "mc_emerald_l", "mc_heart" }, done = {} }
		d.quests.daily.ids = { "d_mine", "d_mine_emerald", "d_contract" }
		d.quests.daily.progress = { d_mine = 14, d_mine_emerald = 12 }
		DS.pushState(lp)
		frames(10)
	end
	Panels.open("Quests")
	snapshot("quests")
end
Panels.close()
frames(10)

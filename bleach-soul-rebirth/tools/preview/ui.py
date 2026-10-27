#!/usr/bin/env python3
"""Prévia da interface: roda o código REAL de UI (HUD, menus, seleção de facção) num ambiente
simulado do Roblox (tools/preview/ui_mock.luau), despeja a árvore de ScreenGuis e desenha com o
layout do Roblox (Scale/Offset, AnchorPoint, UIListLayout/UIGridLayout, UIPadding, UIScale,
UIAspectRatioConstraint, UISizeConstraint), cantos, bordas, gradientes, texto (TextScaled,
quebra, contorno) e ClipsDescendants.

Uso:
  LUAU=caminho/luau python3 tools/preview/ui.py cena saida.png [LxA] [fundo.png]
Cenas: hud, hud-boss, menu-<aba>, faction, dialogue, touch (HUD de celular)
Fontes (opcional): UI_FONTS=pasta com Montserrat.ttf e Bangers.ttf; sem elas usa DejaVu."""
import json, math, os, re, subprocess, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, "..", ".."))
LUAU = os.environ.get("LUAU", "luau")
SS = 2  # supersampling

# ------------------------------------------------------------------ módulos
SKIP = ("src/shared/Anim/Clips", "src/shared/Fx/CreatureMeshes", "src/shared/Config/CreatureRigs")


def virtual(path):
    rel = os.path.relpath(path, root).replace(os.sep, "/")
    rel = re.sub(r"\.luau$", "", rel)
    if rel.startswith("src/shared/"):
        return "RS/Shared/" + rel[len("src/shared/"):]
    if rel.startswith("src/client/"):
        return "Client/" + rel[len("src/client/"):]
    return None


def bundle_modules():
    mods, dirs = [], set()
    for base in ("src/shared", "src/client"):
        for dirpath, _, files in os.walk(os.path.join(root, base)):
            for f in files:
                if not f.endswith(".luau") or f.endswith(".client.luau") or f.endswith(".server.luau"):
                    continue
                full = os.path.join(dirpath, f)
                rel = os.path.relpath(full, root).replace(os.sep, "/")
                if rel.startswith(SKIP):
                    continue
                v = virtual(full)
                parts = v.split("/")
                for i in range(1, len(parts)):
                    dirs.add("/".join(parts[:i]))
                src = open(full, encoding="utf-8").read()
                src = re.sub(r"^--!strict\s*\n", "", src)
                src = src.replace("os.clock()", "OS_CLOCK()")
                mods.append(f'MODULES["{v}"] = function(script)\n{src}\nend')
    dirs.update({"RS/Shared/Anim", "RS/Shared/Fx", "RS/Shared/Config"})
    head = "MODULES = {}\nDIRS = {" + ",".join(f'["{d}"]=true' for d in sorted(dirs)) + "}\nSTUBS = {}\n"
    return head + "\n".join(mods)


STUB_LUA = r'''
local function stub(path, t)
	STUBS[path] = setmetatable(t or {}, { __index = function() return MAGIC end })
end
-- módulos pesados ou de 3D: objeto mágico (qualquer acesso funciona)
for _, p in { "RS/Shared/Anim/Clips", "RS/Shared/Fx/CreatureMeshes", "RS/Shared/Config/CreatureRigs" } do
	stub(p)
end
-- remotes: eventos que a cena pode disparar (NET_EVENTS.Dialogue:Fire(payload))
NET_EVENTS = {}
local function remote(name)
	NET_EVENTS[name] = NET_EVENTS[name] or newSignal()
	return setmetatable({ OnClientEvent = NET_EVENTS[name], FireServer = function() end, InvokeServer = function() return true end }, { __index = function() return MAGIC end })
end
stub("RS/Shared/Net", { event = remote, func = remote, unreliable = remote, get = remote })
PROFILE = nil
local dataChanged = newSignal()
local dataStub = {
	Changed = dataChanged,
	Get = function() return PROFILE end,
	Request = function() return true, "ok" end,
}
stub("Client/Controllers/DataController", dataStub)
function SET_PROFILE(p)
	PROFILE = p
	dataStub.Profile = p
	dataChanged:Fire(p)
end
-- entrada e combate: respostas plausíveis para a UI (modo de controle, slots, recargas)
INPUT_MODE = INPUT_MODE or "Keyboard"
stub("Client/Controllers/InputController", {
	Mode = function() return INPUT_MODE end,
	ModeChanged = newSignal(),
	Action = newSignal(),
})
stub("Client/Controllers/CombatController", {
	Slots = function()
		local Loadout = require(PATH_PROXY("RS/Shared/Logic/Loadout"))
		local Factions = require(PATH_PROXY("RS/Shared/Config/Factions"))
		local Powers = require(PATH_PROXY("RS/Shared/Config/Powers"))
		return Loadout.resolve(Factions, Powers.List, "Shinigami", nil, "Tier1", false)
	end,
	CooldownRemaining = function(key)
		if key == "Slot:X" then return 3.2, 8 end
		if key == "Slot:V" then return 0.6, 12 end
		return 0, 1
	end,
	CooldownsChanged = newSignal(),
})
-- controladores de jogo (efeitos, câmera) viram mágicos; os de UI rodam de verdade
for _, name in { "FxController", "SoundController", "AnimController",
	"CameraController", "VFXController", "ImpactFx", "SpectacleFx", "MeshFx", "ElementFx", "HollowFx",
	"CreatureSkin", "HumanSkin", "GraphicsController", "AmbientController", "ReleaseCutscene", "ZoneController",
	"BossCinematicController" } do
	stub("Client/Controllers/" .. name)
end
SET_REPLICATED(PATH_PROXY("RS", "ReplicatedStorage"))
'''

SCENES = {
    "hud": r'''
local HUD = require(PATH_PROXY("Client/Controllers/HUDController"))
HUD.Init(); HUD.Start(); HUD.SetVisible(true)
DEMO_WORLD(false)
local p = DEMO_PROFILE()
SET_PROFILE(p)
ADVANCE(0.5)
HUD.Notify("Missão concluída: Patrulha de Karakura", "questDone")
HUD.Notify("+240 XP", "xp")
ADVANCE(0.2)
DUMP_GUI("hud")
''',
    "hud-boss": r'''
local HUD = require(PATH_PROXY("Client/Controllers/HUDController"))
HUD.Init(); HUD.Start(); HUD.SetVisible(true)
DEMO_WORLD(true)
SET_PROFILE(DEMO_PROFILE())
ADVANCE(0.5)
ADVANCE(0.2)
DUMP_GUI("hud-boss")
''',
    "faction": r'''
local FS = require(PATH_PROXY("Client/Controllers/FactionSelectController"))
FS.Init(); FS.Start()
local p = DEMO_PROFILE()
p.faction = nil
SET_PROFILE(p)
ADVANCE(1.5)
DUMP_GUI("faction")
''',
    "dialogue": r'''
local D = require(PATH_PROXY("Client/Controllers/DialogueController"))
local HUD = require(PATH_PROXY("Client/Controllers/HUDController"))
HUD.Init(); HUD.Start(); HUD.SetVisible(true)
DEMO_WORLD(false)
SET_PROFILE(DEMO_PROFILE())
D.Init(); D.Start()
NET_EVENTS.Dialogue:Fire({
	name = "Tenente Kenji",
	title = "Guarda do Seireitei",
	text = "Bem-vindo ao Seireitei. Treine no pátio, mas não cause confusão. Os Hollows andam rondando o pátio norte desde ontem à noite.",
	options = { { text = "Aceitar missão: Brecha no Pátio Norte", id = "accept" }, { text = "Conte sobre as divisões", id = "lore" }, { text = "Até mais", id = "bye" } },
})
ADVANCE(2)
DUMP_GUI("dialogue")
''',
}


def menu_scene(tab):
    return r'''
local HUD = require(PATH_PROXY("Client/Controllers/HUDController"))
HUD.Init(); HUD.Start(); HUD.SetVisible(true)
local Menu = require(PATH_PROXY("Client/Controllers/MenuController"))
Menu.Init(); Menu.Start()
SET_PROFILE(DEMO_PROFILE())
ADVANCE(0.3)
Menu.Open("''' + tab + r'''")
ADVANCE(0.6)
DUMP_GUI("menu-''' + tab + r'''")
'''


DEMO_WORLD = r'''
-- personagem do jogador e um chefe por perto (barras com valores reais no Heartbeat do HUD)
function DEMO_WORLD(withBoss)
	local Players = game:GetService("Players")
	local char = Instance.new("Model")
	char.Name = "Ichigo"
	local hum = Instance.new("Humanoid")
	hum.Health = 980
	hum.MaxHealth = 1250
	hum.Parent = char
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Position = Vector3.new(0, 3, 0)
	hrp.Parent = char
	char:SetAttribute("Faction", "Shinigami")
	char:SetAttribute("Form", "Tier1")
	char:SetAttribute("Reiatsu", 64)
	char:SetAttribute("MaxReiatsu", 100)
	char:SetAttribute("Guard", 72)
	char.Parent = workspace
	Players.LocalPlayer.Character = char
	Players.LocalPlayer.CharacterAdded:Fire(char)
	if withBoss then
		local boss = Instance.new("Model")
		boss.Name = "Kurokage"
		local bh = Instance.new("Humanoid")
		bh.Health = 31500
		bh.MaxHealth = 48000
		bh.Parent = boss
		local br = Instance.new("Part")
		br.Name = "HumanoidRootPart"
		br.Position = Vector3.new(20, 3, 30)
		br.Parent = boss
		boss:SetAttribute("DisplayName", "Kurokage, a Sombra Devoradora")
		boss:SetAttribute("Phase", 2)
		boss.Parent = workspace.Bosses
	end
end
'''

DEMO_PROFILE = r'''
function DEMO_PROFILE()
	local DataSchema = require(PATH_PROXY("RS/Shared/Logic/DataSchema"))
	local p = DataSchema.template()
	p.faction = "Shinigami"
	p.power = nil
	p.level = 14
	p.xp = 820
	p.statPoints = 3
	p.skillPoints = 2
	p.currency.Kan = 12850
	p.currency.Shards = 42
	p.unlocks.Tier1 = true
	p.discovered.Seireitei = true
	p.quests.active.Training = { progress = { 1, 2, 0 } }
	p.quests.tracked = "Training"
	return p
end
'''


def run_scene(scene, size, touch):
    cframe = open(os.path.join(root, "tools", "cframe_stub.luau"), encoding="utf-8").read().split("-- @@FIM_CFRAME@@")[0]
    mock = open(os.path.join(here, "ui_mock.luau"), encoding="utf-8").read()
    body = SCENES.get(scene) or (menu_scene(scene[5:]) if scene.startswith("menu-") else None)
    if body is None:
        raise SystemExit("cena desconhecida: " + scene)
    w, h = size
    setup = f"VIEWPORT_W, VIEWPORT_H = {w}, {h}\n"
    src = "\n".join([
        "game = nil",
        mock,
        cframe,
        f'rawget(workspace.CurrentCamera, "_props").ViewportSize = Vector2.new({w}, {h})',
        "game:GetService('UserInputService').TouchEnabled = " + ("true" if touch else "false"),
        "INPUT_MODE = " + ('"Touch"' if touch else '"Keyboard"'),
        "game:GetService('UserInputService').KeyboardEnabled = " + ("false" if touch else "true"),
        bundle_modules(),
        STUB_LUA,
        DEMO_PROFILE,
        DEMO_WORLD,
        setup,
        "local ok, err = pcall(function()\n" + body + "\nend)\nif not ok then print('ERRO_CENA: ' .. tostring(err)) DUMP_GUI('erro') end",
    ])
    path = os.path.join(here, ".ui.luau")
    open(path, "w", encoding="utf-8").write(src)
    res = subprocess.run([LUAU, path], capture_output=True, text=True, timeout=300)
    out = res.stdout
    for line in out.splitlines():
        if not line.startswith("{"):
            print("  lua:", line[:300])
    if res.returncode != 0 or res.stderr.strip():
        print(res.stderr[-3000:])
    dumps = [json.loads(l) for l in out.splitlines() if l.startswith("{")]
    if not dumps:
        raise SystemExit("sem dump")
    return dumps[-1]


# ------------------------------------------------------------------ fontes
FONT_DIR = os.environ.get("UI_FONTS", "")
_fonts = {}


def font_for(name, size, text):
    size = max(4, int(round(size)))
    cjk = any(ord(ch) > 0x2E80 for ch in text)
    key = (name, size, cjk)
    if key in _fonts:
        return _fonts[key]
    f = None
    if cjk:
        for p in ("/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc", "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"):
            if os.path.exists(p):
                f = ImageFont.truetype(p, size)
                break
    if f is None and any(ch in "✕✔✦★☆✖✓▶◀▲▼●○◆◇♦→←↑↓⚔✚" for ch in text):
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)
    if f is None and name == "Bangers" and os.path.exists(os.path.join(FONT_DIR, "Bangers.ttf")):
        f = ImageFont.truetype(os.path.join(FONT_DIR, "Bangers.ttf"), size)
    if f is None and os.path.exists(os.path.join(FONT_DIR, "Montserrat.ttf")):
        f = ImageFont.truetype(os.path.join(FONT_DIR, "Montserrat.ttf"), size)
        weight = {"GothamBlack": 900, "GothamBold": 700, "GothamMedium": 500, "Gotham": 400, "GothamSemibold": 600,
                  "Bangers": 800, "SourceSansBold": 700, "SourceSans": 400}.get(name, 600)
        try:
            f.set_variation_by_axes([weight])
        except Exception:
            pass
    if f is None:
        bold = name not in ("Gotham", "SourceSans", "GothamMedium")
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans" + ("-Bold" if bold else "") + ".ttf", size)
    _fonts[key] = f
    return f


# ------------------------------------------------------------------ layout
def kids_of(node, cls=None):
    return [k for k in node["kids"] if cls is None or k["c"] == cls]


def first(node, cls):
    for k in node["kids"]:
        if k["c"] == cls:
            return k
    return None


GUI = {"Frame", "TextLabel", "TextButton", "TextBox", "ImageLabel", "ImageButton", "ScrollingFrame", "ViewportFrame", "CanvasGroup"}


def text_extent(node, max_w=None):
    f = font_for(node.get("font"), node["ts"], node["text"])
    lines = wrap(node["text"], f, max_w) if (node.get("wrap") and max_w) else node["text"].split("\n")
    w = max([f.getlength(l) for l in lines] + [0])
    return w, len(lines) * node["ts"] * 1.15


def wrap(text, f, max_w):
    out = []
    for para in text.split("\n"):
        line = ""
        for word in para.split(" "):
            test = (line + " " + word).strip()
            if f.getlength(test) <= max_w or not line:
                line = test
            else:
                out.append(line)
                line = word
        out.append(line)
    return out


def layout(node, rect, out):
    """rect = (x, y, w, h) do conteúdo do pai. Preenche node['_r'] e desce nos filhos."""
    x, y, w, h = rect
    node["_r"] = rect
    pad = first(node, "UIPadding")
    cx, cy, cw, ch = x, y, w, h
    if pad:
        p = pad["pads"]
        top, bottom = p[0] * h + p[1], p[2] * h + p[3]
        left, right = p[4] * w + p[5], p[6] * w + p[7]
        cx, cy, cw, ch = x + left, y + top, max(0, w - left - right), max(0, h - top - bottom)
    content = (cx, cy, cw, ch)
    gui_kids = [k for k in node["kids"] if k["c"] in GUI]
    sizes = {}
    for k in gui_kids:
        s = k["size"]
        kw, kh = cw * s[0] + s[1], ch * s[2] + s[3]
        ar = first(k, "UIAspectRatioConstraint")
        if ar and ar["ratio"] > 0:
            r = ar["ratio"]
            if kw / max(kh, 1e-6) > r:
                kw = kh * r
            else:
                kh = kw / r
        sc = first(k, "UISizeConstraint")
        if sc:
            if sc.get("max"):
                kw, kh = min(kw, sc["max"][0]), min(kh, sc["max"][1])
            if sc.get("min"):
                kw, kh = max(kw, sc["min"][0]), max(kh, sc["min"][1])
        auto = k.get("auto")
        if auto and auto != "None" and k["c"] in ("TextLabel", "TextButton", "TextBox") and k.get("text"):
            tw, th = text_extent(k, kw if auto == "Y" else None)
            if auto in ("X", "XY"):
                kw = max(kw, tw + 4)
            if auto in ("Y", "XY"):
                kh = max(kh, th + 2)
        sizes[id(k)] = [kw, kh]
    lst = first(node, "UIListLayout")
    grid = first(node, "UIGridLayout")
    order = list(gui_kids)
    if lst or grid:
        l = lst or grid
        keyf = (lambda k: (k["order"],)) if l["sort"] == "LayoutOrder" else (lambda k: (k["n"],))
        order = sorted([k for k in gui_kids if k["vis"]], key=keyf)
    if lst:
        horizontal = lst["dir"] == "Horizontal"
        gap = lst["pad"][0] * (cw if horizontal else ch) + lst["pad"][1]
        total = sum(sizes[id(k)][0 if horizontal else 1] for k in order) + gap * max(0, len(order) - 1)
        if horizontal:
            start = cx + {"Left": 0, "Center": (cw - total) / 2, "Right": cw - total}.get(lst["halign"], 0)
        else:
            start = cy + {"Top": 0, "Center": (ch - total) / 2, "Bottom": ch - total}.get(lst["valign"], 0)
        cur = start
        for k in order:
            kw, kh = sizes[id(k)]
            if horizontal:
                ky = cy + {"Top": 0, "Center": (ch - kh) / 2, "Bottom": ch - kh}.get(lst["valign"], 0)
                kx = cur
                cur += kw + gap
            else:
                kx = cx + {"Left": 0, "Center": (cw - kw) / 2, "Right": cw - kw}.get(lst["halign"], 0)
                ky = cur
                cur += kh + gap
            k["_box"] = (kx, ky, kw, kh)
        node["_content_extent"] = total
    elif grid:
        cs, cp = grid["cell"], grid["cellpad"]
        cwid, chei = cw * cs[0] + cs[1], ch * cs[2] + cs[3]
        px, py = cw * cp[0] + cp[1], ch * cp[2] + cp[3]
        per_row = max(1, int((cw + px) // (cwid + px)))
        for i, k in enumerate(order):
            r, c = divmod(i, per_row)
            k["_box"] = (cx + c * (cwid + px), cy + r * (chei + py), cwid, chei)
            sizes[id(k)] = [cwid, chei]
        rows = math.ceil(len(order) / per_row) if order else 0
        node["_content_extent"] = rows * (chei + py)
    else:
        for k in gui_kids:
            kw, kh = sizes[id(k)]
            p, a = k["pos"], k["anchor"]
            kx = cx + cw * p[0] + p[1] - a[0] * kw
            ky = cy + ch * p[2] + p[3] - a[1] * kh
            k["_box"] = (kx, ky, kw, kh)
    for k in gui_kids:
        if "_box" not in k:
            k["_box"] = (0, 0, 0, 0)
        layout(k, k["_box"], out)
    # AutomaticSize em Frames com lista: cresce para caber
    for k in gui_kids:
        auto = k.get("auto")
        if auto in ("Y", "XY") and k["c"] in ("Frame", "ScrollingFrame") and "_content_extent" in k:
            bx, by, bw, bh = k["_box"]
            pad = first(k, "UIPadding")
            extra = (pad["pads"][1] + pad["pads"][3]) if pad else 0
            if k["_content_extent"] + extra > bh:
                k["_box"] = (bx, by, bw, k["_content_extent"] + extra)


# ------------------------------------------------------------------ desenho
def rgba(c, t):
    return (int(c[0] * 255), int(c[1] * 255), int(c[2] * 255), int(255 * max(0, min(1, 1 - t))))


def seq_at(seq, t):
    if not seq:
        return None
    if t <= seq[0][0]:
        return seq[0][1]
    for (t0, v0), (t1, v1) in zip(seq, seq[1:]):
        if t <= t1:
            u = (t - t0) / max(t1 - t0, 1e-6)
            if isinstance(v0, list):
                return [v0[i] + (v1[i] - v0[i]) * u for i in range(3)]
            return v0 + (v1 - v0) * u
    return seq[-1][1]


def gradient_layer(w, h, grad, base_color, base_t):
    """Camada RGBA com a cor/transparência do UIGradient multiplicadas pela cor do objeto."""
    w, h = max(1, int(w)), max(1, int(h))
    img = Image.new("RGBA", (w, h))
    px = img.load()
    rot = math.radians(grad.get("rot", 0))
    dx, dy = math.cos(rot), math.sin(rot)
    span = abs(dx) * w + abs(dy) * h
    step = 2
    for yy in range(0, h, step):
        for xx in range(0, w, step):
            u = ((xx - w / 2) * dx + (yy - h / 2) * dy) / max(span, 1) + 0.5
            col = seq_at(grad.get("color"), u) or [1, 1, 1]
            tr = seq_at(grad.get("transp"), u)
            tr = 0 if tr is None else tr
            c = [base_color[i] * col[i] for i in range(3)]
            a = (1 - base_t) * (1 - tr)
            v = (int(c[0] * 255), int(c[1] * 255), int(c[2] * 255), int(255 * max(0, min(1, a))))
            for oy in range(step):
                for ox in range(step):
                    if xx + ox < w and yy + oy < h:
                        px[xx + ox, yy + oy] = v
    return img


def radius_of(node, w, h):
    c = first(node, "UICorner")
    if not c:
        return 0
    return min(w, h) * c["radius"][0] + c["radius"][1]


def draw_node(canvas, node, origin, scale, clip=None, alpha=1.0):
    if node["c"] in GUI and not node.get("vis", True):
        return
    if node["c"] == "ScreenGui":
        for k in sorted([k for k in node["kids"] if k["c"] in GUI], key=lambda k: k.get("z", 1)):
            draw_node(canvas, k, origin, scale, clip, alpha)
        return
    if node["c"] not in GUI:
        return
    if node.get("gt") is not None:
        alpha *= 1 - node["gt"]
    x, y, w, h = node["_box"]
    X, Y, W, H = [(v * scale) * SS for v in (x, y, w, h)]
    X += origin[0] * SS
    Y += origin[1] * SS
    layer = Image.new("RGBA", canvas.size)
    d = ImageDraw.Draw(layer)
    r = radius_of(node, w, h) * scale * SS
    grad = first(node, "UIGradient")
    if grad and not grad.get("enabled", True):
        grad = None
    if node["bgt"] < 0.999 and W > 0.5 and H > 0.5 and node["c"] not in ("TextLabel",) or (node["c"] == "TextLabel" and node["bgt"] < 0.999):
        if grad:
            g = gradient_layer(W, H, grad, node["bg"], node["bgt"])
            mask = Image.new("L", g.size, 0)
            ImageDraw.Draw(mask).rounded_rectangle((0, 0, g.size[0] - 1, g.size[1] - 1), radius=r, fill=255)
            g.putalpha(ImageChops.multiply(g.getchannel("A"), mask))
            layer.alpha_composite(g, (int(X), int(Y)))
        else:
            d.rounded_rectangle((X, Y, X + W, Y + H), radius=r, fill=rgba(node["bg"], node["bgt"]))
    if node["c"] in ("ImageLabel", "ImageButton") and node.get("img") and node.get("it", 1) < 0.99:
        # imagens de asset não são carregadas: área tracejada com a cor da imagem
        d.rounded_rectangle((X, Y, X + W, Y + H), radius=r, outline=rgba(node.get("ic", [1, 1, 1]), 0.6), width=SS)
    if node["c"] == "ViewportFrame":
        d.rounded_rectangle((X, Y, X + W, Y + H), radius=r, fill=(255, 255, 255, 18))
        f = font_for("GothamBold", 12 * scale * SS, "3D")
        d.text((X + W / 2, Y + H / 2), "[personagem 3D]", font=f, fill=(255, 255, 255, 90), anchor="mm")
    stroke = first(node, "UIStroke")
    text_stroke = None
    if stroke and stroke.get("enabled", True) and stroke["t"] < 0.999:
        sw = max(1, stroke["thick"] * scale * SS)
        if node["c"] in ("TextLabel", "TextButton", "TextBox") and stroke.get("mode") != "Border":
            text_stroke = (sw, rgba(stroke["color"], stroke["t"]))
        else:
            d.rounded_rectangle((X - sw / 2, Y - sw / 2, X + W + sw / 2, Y + H + sw / 2), radius=r + sw / 2,
                                outline=rgba(stroke["color"], stroke["t"]), width=int(round(sw)))
    if node["c"] in ("TextLabel", "TextButton", "TextBox"):
        text = node.get("text") or node.get("ph") or ""
        if node.get("rich"):
            text = re.sub(r"<[^>]+>", "", text)
        if text and node["tt"] < 0.999:
            draw_text(d, node, text, X, Y, W, H, scale, text_stroke, grad)
    if alpha < 0.999:
        a = layer.getchannel("A").point(lambda v: int(v * alpha))
        layer.putalpha(a)
    if clip:
        m = Image.new("L", canvas.size, 0)
        ImageDraw.Draw(m).rectangle(clip, fill=255)
        layer.putalpha(ImageChops.multiply(layer.getchannel("A"), m))
    canvas.alpha_composite(layer)
    child_clip = clip
    if node.get("clip"):
        box = (X, Y, X + W, Y + H)
        child_clip = box if not clip else (max(box[0], clip[0]), max(box[1], clip[1]), min(box[2], clip[2]), min(box[3], clip[3]))
    for k in sorted([k for k in node["kids"] if k["c"] in GUI], key=lambda k: k.get("z", 1)):
        draw_node(canvas, k, origin, scale, child_clip, alpha)


def draw_text(d, node, text, X, Y, W, H, scale, stroke, grad):
    size = node["ts"] * scale * SS
    fname = node.get("font")
    if node.get("scaled"):
        tsc = first(node, "UITextSizeConstraint")
        cap = (tsc["maxts"] if tsc else 100) * scale * SS
        size = min(H * 0.92, cap)
        while size > 4:
            f = font_for(fname, size, text)
            lines = wrap(text, f, W) if node.get("wrap") else text.split("\n")
            tw = max(f.getlength(l) for l in lines)
            th = len(lines) * size * 1.12
            if tw <= W * 0.98 and th <= H:
                break
            size *= 0.92
    f = font_for(fname, size, text)
    lines = wrap(text, f, W) if node.get("wrap") else text.split("\n")
    lh = size * 1.15
    total = lh * len(lines)
    ya = node.get("ya", "Center")
    ty = Y + {"Top": 0, "Center": (H - total) / 2, "Bottom": H - total}.get(ya, (H - total) / 2)
    col = list(node["tc"])
    if grad and grad.get("color"):
        mid = seq_at(grad["color"], 0.5)
        col = [col[i] * mid[i] for i in range(3)]
    fill = rgba(col, node["tt"])
    sw, scol = 0, None
    if node["tst"] < 0.999:
        sw = max(1, int(size / 14))
        scol = rgba(node["tsc"], max(node["tst"], node["tt"]))
    if stroke:
        sw, scol = int(round(stroke[0])), stroke[1]
    if node.get("trunc") == "AtEnd":
        cut = []
        for line in lines:
            if f.getlength(line) > W:
                while line and f.getlength(line + "…") > W:
                    line = line[:-1]
                line += "…"
            cut.append(line)
        lines = cut
    for i, line in enumerate(lines):
        lw = f.getlength(line)
        xa = node.get("xa", "Center")
        tx = X + {"Left": 0, "Center": (W - lw) / 2, "Right": W - lw}.get(xa, (W - lw) / 2)
        d.text((tx, ty + i * lh + (lh - size) / 2), line, font=f, fill=fill, stroke_width=sw, stroke_fill=scol)


def render(dump, size, background, out):
    w, h = size
    tile = None
    if background and "#" in background:
        background, tile = background.split("#")
    if background and os.path.exists(background):
        bg = Image.open(background).convert("RGB")
        if tile is not None:
            # folha de prévias 2×N de 640×400: usa um quadro só
            i = int(tile)
            bg = bg.crop(((i % 2) * 640, (i // 2) * 400 + 14, (i % 2) * 640 + 640, (i // 2) * 400 + 400))
        k = max(w / bg.width, h / bg.height)
        bg = bg.resize((int(bg.width * k) + 1, int(bg.height * k) + 1)).crop((0, 0, w, h))
    else:
        bg = Image.new("RGB", (w, h), (60, 70, 85))
    canvas = Image.new("RGBA", (w * SS, h * SS))
    for gui in sorted(dump["guis"], key=lambda g: g.get("display", 0)):
        if not gui.get("enabled", True):
            continue
        inset = 0 if gui.get("inset") else 36
        sc = first(gui, "UIScale")
        s = sc["scale"] if sc else 1.0
        vw, vh = w / s, (h - inset) / s
        layout(gui, (0, 0, vw, vh), None)
        draw_node(canvas, gui, (0, inset), s)
    canvas = canvas.resize((w, h), Image.LANCZOS)
    final = bg.convert("RGBA")
    final.alpha_composite(canvas)
    # barra superior do Roblox (referência de área reservada)
    ImageDraw.Draw(final).rectangle((0, 0, w, 35), fill=(0, 0, 0, 60))
    final.convert("RGB").save(out)


if __name__ == "__main__":
    scene, out = sys.argv[1], sys.argv[2]
    size = tuple(int(v) for v in (sys.argv[3] if len(sys.argv) > 3 else "1280x720").split("x"))
    background = sys.argv[4] if len(sys.argv) > 4 else os.path.join(here, "soulsociety.png") + "#2"
    touch = scene == "touch" or os.environ.get("TOUCH") == "1"
    dump = run_scene("hud" if scene == "touch" else scene, size, touch)
    render(dump, size, background, out)
    print("ok", out)

#!/usr/bin/env python3
"""Roda construtores de modelo do jogo (código Luau real) com a simulação de tools/preview/roblox_mock.luau
e desenha as peças num PNG (vistas de lado e em 3/4), para conferir geometria sem o Studio.
Uso: python3 tools/preview/preview.py weapons <saida.png>"""
import json, math, os, re, subprocess, sys
from PIL import Image, ImageDraw

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, "..", ".."))
LUAU = os.environ.get("LUAU", "luau")


def module(path, requires):
    code = open(os.path.join(root, path), encoding="utf-8").read()
    code = re.sub(r"^--!\w+\n", "", code)
    code = re.sub(r"^export type ", "type ", code, flags=re.M)
    for pattern, name in requires.items():
        code = re.sub(pattern, name, code)
    return code


def run_weapons():
    cframe = open(os.path.join(root, "tools", "cframe_stub.luau"), encoding="utf-8").read().split("-- @@FIM_CFRAME@@")[0]
    mock = open(os.path.join(here, "roblox_mock.luau"), encoding="utf-8").read()
    elements = module("src/shared/Config/Elements.luau", {})
    weapon = module("src/shared/Builders/WeaponBuilder.luau",
                    {r'require\(game:GetService\("ReplicatedStorage"\)\.Shared\.Config\.Elements\)': "ELEMENTS"})
    powers_src = module("src/shared/Config/Powers.luau", {})
    factions_src = module("src/shared/Config/Factions.luau", {})
    driver = r'''
local function num(n) return string.format("%.4f", n) end
local function dump(label, model)
	local items = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local cf = p.CFrame
			local c = p.Color or Color3.new(0.5, 0.5, 0.5)
			local shape = p.Shape and p.Shape.Name or (if rawget(p, "_class") == "WedgePart" then "Wedge" else "Block")
			table.insert(items, string.format('{"n":"%s","shape":"%s","s":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s],"c":[%s,%s,%s],"t":%s,"m":"%s"}',
				p.Name, shape, num(p.Size.X), num(p.Size.Y), num(p.Size.Z), num(cf.p[1]), num(cf.p[2]), num(cf.p[3]),
				table.concat((function() local t = {} for i = 1, 9 do t[i] = num(cf.r[i]) end return t end)(), ","),
				num(c.R), num(c.G), num(c.B), num(p.Transparency or 0), p.Material and p.Material.Name or "Plastic"))
		end
	end
	print('{"label":"' .. label .. '","parts":[' .. table.concat(items, ",") .. ']}')
end
local specs = {}
table.insert(specs, { "Asauchi (Shinigami)", FACTIONS.Shinigami.weapon, "Reiatsu" })
for _, id in { "Enjin", "Hyoketsu", "Raijinmaru", "Tsukikage" } do
	local p = POWERS.List[id]
	table.insert(specs, { p.tier1.name, p.tier1.weapon, p.element })
	table.insert(specs, { p.tier2.name, p.tier2.weapon, p.element })
end
table.insert(specs, { "Quincy", POWERS.List.Kranich.tier1.weapon, "Holy" })
for _, s in specs do
	local m = WeaponBuilder.buildModel(s[2], s[3])
	dump(s[1], m)
end
'''
    src = "\n".join([
        "game = {}", cframe, mock,
        "ELEMENTS = (function()\n" + elements + "\nend)()",
        "local WeaponBuilder = (function()\n" + weapon + "\nend)()",
        "POWERS = (function()\n" + powers_src + "\nend)()",
        "FACTIONS = (function()\n" + factions_src + "\nend)()",
        driver,
    ])
    path = os.path.join(here, ".weapons.luau")
    open(path, "w", encoding="utf-8").write(src)
    res = subprocess.run([LUAU, path], capture_output=True, text=True)
    if res.returncode != 0 or res.stderr.strip():
        raise SystemExit(res.stdout[-2000:] + res.stderr[-3000:])
    return [json.loads(l) for l in res.stdout.splitlines() if l.startswith("{")]


def lua_literal(v):
    if isinstance(v, dict):
        return "{" + ", ".join(f'["{k}"] = {lua_literal(x)}' for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "{" + ", ".join(lua_literal(x) for x in v) + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return json.dumps(v)
    return repr(v)


DUMP = r'''
local function num(n) return string.format("%.4f", n) end
local function dump(label, model)
	local items = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			local cf = p.CFrame
			local c = p.Color or Color3.new(0.5, 0.5, 0.5)
			local shape = p.Shape and p.Shape.Name or (if rawget(p, "_class") == "WedgePart" then "Wedge" else "Block")
			local mesh = p:FindFirstChild("SpecialMesh")
			if mesh then
				shape = "Ball"
			end
			table.insert(items, string.format('{"n":"%s","shape":"%s","s":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s],"c":[%s,%s,%s],"t":%s,"m":"%s"}',
				p.Name, shape, num(p.Size.X), num(p.Size.Y), num(p.Size.Z), num(cf.p[1]), num(cf.p[2]), num(cf.p[3]),
				table.concat((function() local t = {} for i = 1, 9 do t[i] = num(cf.r[i]) end return t end)(), ","),
				num(c.R), num(c.G), num(c.B), num(p.Transparency or 0), p.Material and p.Material.Name or "Plastic"))
		end
	end
	print('{"label":"' .. label .. '","parts":[' .. table.concat(items, ",") .. ']}')
end
'''


def run_creatures(bodies, enemies):
    """Monta corpos com RigBuilder.buildCreature (código real) usando o `look` de cada inimigo."""
    cframe = open(os.path.join(root, "tools", "cframe_stub.luau"), encoding="utf-8").read().split("-- @@FIM_CFRAME@@")[0]
    mock = open(os.path.join(here, "roblox_mock.luau"), encoding="utf-8").read()
    rigs = json.load(open(os.path.join(root, "src", "shared", "Config", "CreatureRigs.json")))
    rigbuilder = module("src/shared/Builders/RigBuilder.luau",
                        {r"require\(script\.Parent\.Parent\.Config\.CreatureRigs\)": "CREATURE_RIGS"})
    enemies_src = module("src/shared/Config/Enemies.luau", {})
    driver = DUMP + "\n"
    for body, enemy in zip(bodies, enemies):
        driver += f'do local def = ENEMIES["{enemy}"]; local m = RigBuilder.buildCreature("{enemy}", "{body}", def.look or {{}}, 1); dump("{enemy} ({body})", m) end\n'
    src = "\n".join([
        "game = {}", cframe, mock,
        "CREATURE_RIGS = " + lua_literal(rigs),
        "local RigBuilder = (function()\n" + rigbuilder + "\nend)()",
        "ENEMIES = (function()\n" + enemies_src + "\nend)()",
        driver,
    ])
    path = os.path.join(here, ".creatures.luau")
    open(path, "w", encoding="utf-8").write(src)
    res = subprocess.run([LUAU, path], capture_output=True, text=True)
    if res.returncode != 0 or res.stderr.strip():
        raise SystemExit(res.stdout[-2000:] + res.stderr[-3000:])
    return [json.loads(l) for l in res.stdout.splitlines() if l.startswith("{")]


def corners(part):
    sx, sy, sz = [v / 2 for v in part["s"]]
    r, p = part["r"], part["p"]
    pts = []
    for x in (-sx, sx):
        for y in (-sy, sy):
            for z in (-sz, sz):
                yy = -sy if (part["shape"] == "Wedge" and y > 0 and z < 0) else y  # WedgePart: face alta em +Z, rampa até a base em -Z
                pts.append((p[0] + r[0] * x + r[1] * yy + r[2] * z, p[1] + r[3] * x + r[4] * yy + r[5] * z, p[2] + r[6] * x + r[7] * yy + r[8] * z))
    return pts


FACES = [(0, 1, 3, 2), (4, 5, 7, 6), (0, 1, 5, 4), (2, 3, 7, 6), (0, 2, 6, 4), (1, 3, 7, 5)]


def local_polys(part):
    """Polígonos no espaço local da peça conforme a forma (caixa, cunha, esfera, cilindro)."""
    sx, sy, sz = [v / 2 for v in part["s"]]
    shape = part["shape"]
    polys = []
    if shape == "Ball":
        lat, lon = 6, 10
        def pt(i, j):
            th = math.pi * i / lat - math.pi / 2
            ph = 2 * math.pi * j / lon
            return (sx * math.cos(th) * math.cos(ph), sy * math.sin(th), sz * math.cos(th) * math.sin(ph))
        for i in range(lat):
            for j in range(lon):
                polys.append([pt(i, j), pt(i + 1, j), pt(i + 1, j + 1), pt(i, j + 1)])
    elif shape == "Cylinder":
        n = 12
        ring = lambda x: [(x, sy * math.cos(2 * math.pi * k / n), sz * math.sin(2 * math.pi * k / n)) for k in range(n)]
        a, b = ring(-sx), ring(sx)
        for k in range(n):
            polys.append([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]])
        polys.append(a)
        polys.append(b)
    else:
        pts = []
        for x in (-sx, sx):
            for y in (-sy, sy):
                for z in (-sz, sz):
                    yy = -sy if (shape == "Wedge" and y > 0 and z < 0) else y
                    pts.append((x, yy, z))
        polys = [[pts[i] for i in f] for f in FACES]
    return polys


def to_world(part, v):
    r, p = part["r"], part["p"]
    x, y, z = v
    return (p[0] + r[0] * x + r[1] * y + r[2] * z, p[1] + r[3] * x + r[4] * y + r[5] * z, p[2] + r[6] * x + r[7] * y + r[8] * z)


def render(models, out, cols=2, cell=(520, 300), views=None):
    """views: lista de (rótulo, yaw em graus) por modelo; padrão = uma vista lateral em 3/4."""
    views = views or [("", -70)]
    cols = cols * len(views) if len(views) > 1 else cols
    per_row = cols
    entries = [(m, v) for m in models for v in views]
    rows = math.ceil(len(entries) / per_row)
    img = Image.new("RGB", (cell[0] * per_row, cell[1] * rows), (22, 24, 30))
    d = ImageDraw.Draw(img)
    light = (0.35, 0.8, -0.45)
    pitch = math.radians(12)
    for idx, (m, (vlabel, yaw_deg)) in enumerate(entries):
        yaw = math.radians(yaw_deg)
        ox, oy = (idx % per_row) * cell[0], (idx // per_row) * cell[1]
        polys, allpts = [], []
        for part in m["parts"]:
            if part["t"] >= 0.99:
                continue
            for poly in local_polys(part):
                world = [to_world(part, v) for v in poly]
                view = []
                for (x, y, z) in world:
                    x1 = x * math.cos(yaw) + z * math.sin(yaw)
                    z1 = -x * math.sin(yaw) + z * math.cos(yaw)
                    y2 = y * math.cos(pitch) - z1 * math.sin(pitch)
                    z2 = y * math.sin(pitch) + z1 * math.cos(pitch)
                    view.append((x1, y2, z2))
                allpts += view
                if len(world) >= 3:
                    a, b, c = world[0], world[1], world[2]
                    ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
                    vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
                    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
                    ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1
                    shade = 0.42 + 0.58 * abs((nx * light[0] + ny * light[1] + nz * light[2]) / ln)
                else:
                    shade = 1
                if part["m"] == "Neon":
                    shade = 1.2
                depth = sum(p_[2] for p_ in view) / len(view)
                col = tuple(min(255, int(255 * c_ * shade)) for c_ in part["c"])
                polys.append((depth, view, col, part["t"]))
        if not allpts:
            continue
        minx, maxx = min(p_[0] for p_ in allpts), max(p_[0] for p_ in allpts)
        miny, maxy = min(p_[1] for p_ in allpts), max(p_[1] for p_ in allpts)
        scale = min((cell[0] - 40) / max(0.1, maxx - minx), (cell[1] - 60) / max(0.1, maxy - miny))
        cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
        polys.sort(key=lambda q: q[0])  # longe (z menor) primeiro: a câmera fica do lado +z da vista
        for _, quad, col, t in polys:
            pts = [(ox + cell[0] / 2 + (x - cx) * scale, oy + 20 + (cell[1] - 40) / 2 - (y - cy) * scale) for x, y, _ in quad]
            if t > 0.05:
                bg = (22, 24, 30)
                col = tuple(int(c_ * (1 - t * 0.6) + bg[i] * t * 0.6) for i, c_ in enumerate(col))
            d.polygon(pts, fill=col)
        d.text((ox + 10, oy + 8), m["label"] + (" — " + vlabel if vlabel else ""), fill=(230, 230, 230))
    img.save(out)


if __name__ == "__main__":
    what, out = sys.argv[1], sys.argv[2]
    if what == "weapons":
        models = run_weapons()
        render(models, out)
        for m in models:
            print(m["label"], len(m["parts"]), "peças")
    elif what == "creatures":
        # creatures saida.png Corpo:Inimigo [Corpo:Inimigo ...]
        pairs = [a.split(":") for a in sys.argv[3:]]
        models = run_creatures([p[0] for p in pairs], [p[1] for p in pairs])
        render(models, out, cols=1, cell=(420, 460), views=[("frente", 180), ("3/4", 145), ("lado", 90), ("costas", 0)])
        for m in models:
            print(m["label"], len(m["parts"]), "peças")

#!/usr/bin/env python3
"""Renderiza a cidade (Regions.Karakura, código real do mapa) à noite, em perspectiva:
iluminação = ambiente noturno + lua + as luzes do próprio mapa (PointLight/SpotLight das peças),
neon emissivo, água e chão do Terrain. Uso:
  LUAU=caminho/luau python3 tools/preview/city.py saida.png"""
import json, math, os, re, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, "..", ".."))
LUAU = os.environ.get("LUAU", "luau")
REGION = os.environ.get("REGION", "Karakura")  # REGION=SoulSociety para o Seireitei
DAY = os.environ.get("NIGHT") is None  # Karakura é de tarde; NIGHT=1 renderiza à noite
sys.path.insert(0, here)
from preview import module, local_polys  # noqa: E402


def run():
    cframe = open(os.path.join(root, "tools", "cframe_stub.luau"), encoding="utf-8").read().split("-- @@FIM_CFRAME@@")[0]
    mock = open(os.path.join(here, "roblox_mock.luau"), encoding="utf-8").read()
    zones = module("src/shared/Config/Zones.luau", {})
    npcs = module("src/shared/Config/NPCs.luau", {})
    build = module("src/server/World/Build.luau", {})
    town = module("src/server/World/Town.luau", {r"require\(script\.Parent\.Build\)": "BUILD"})
    seireitei = module("src/server/World/Seireitei.luau", {r"require\(script\.Parent\.Build\)": "BUILD"})
    hueco = module("src/server/World/Hueco.luau", {r"require\(script\.Parent\.Build\)": "BUILD"})
    regions = module("src/server/World/Regions.luau", {
        r"require\(ReplicatedStorage\.Shared\.Config\.Zones\)": "ZONES",
        r"require\(ReplicatedStorage\.Shared\.Config\.NPCs\)": "NPCS",
        r"require\(script\.Parent\.Build\)": "BUILD",
        r"require\(script\.Parent\.Town\)": "TOWN",
        r"require\(script\.Parent\.Seireitei\)": "SEIREITEI",
        r"require\(script\.Parent\.Hueco\)": "HUECO",
    })
    driver = r'''
workspace = Instance.new("Workspace")
workspace.Terrain = { FillBlock = function(_, cf, size, material)
	print(string.format('{"terrain":"%s","p":[%.2f,%.2f,%.2f],"s":[%.2f,%.2f,%.2f]}', material.Name, cf.p[1], cf.p[2], cf.p[3], size.X, size.Y, size.Z))
end }
local TERRAIN_COLORS = { Sand = "0.86,0.84,0.78", Sandstone = "0.74,0.66,0.56", Rock = "0.48,0.46,0.45", Basalt = "0.26,0.25,0.28", Grass = "0.3,0.45,0.25" }
local function terrainPart(shape, size, p, r, material)
	print(string.format('{"n":"Terrain","shape":"%s","s":[%.2f,%.2f,%.2f],"p":[%.2f,%.2f,%.2f],"r":[%s],"c":[%s],"t":0,"m":"%s"}',
		shape, size.X, size.Y, size.Z, p.X, p.Y, p.Z, r, TERRAIN_COLORS[material.Name] or "0.5,0.5,0.5", material.Name))
end
workspace.Terrain.FillBall = function(_, center, radius, material)
	terrainPart("Ball", Vector3.new(radius * 2, radius * 2, radius * 2), center, "1,0,0,0,1,0,0,0,1", material)
end
workspace.Terrain.FillCylinder = function(_, cf, height, radius, material)
	local p = Vector3.new(cf.p[1], cf.p[2], cf.p[3])
	terrainPart("Cylinder", Vector3.new(height, radius * 2, radius * 2), p, "0,-1,0,1,0,0,0,0,1", material)
end
local folder = Instance.new("Folder")
if "@@REGION@@" == "Trees" then
	local rng = Random.new(7)
	for i, kind in { "cherry", "broadleaf", "pine", "cherry", "pine", "broadleaf" } do
		BUILD.tree(folder, Vector3.new((i - 3.5) * 16, 0, (i % 2) * 10), kind, rng)
	end
	workspace.Terrain:FillBlock(CFrame.new(0, -4, 0), Vector3.new(200, 8, 200), Enum.Material.Grass)
else
	REGIONS["@@REGION@@"](folder)
end
local function num(n) return string.format("%.3f", n) end
for _, p in folder:GetDescendants() do
	if p:IsA("BasePart") and (p.Transparency or 0) < 0.99 then
		local cf = p.CFrame
		local c = p.Color or Color3.new(0.5, 0.5, 0.5)
		local shape = p.Shape and p.Shape.Name or (if rawget(p, "_class") == "WedgePart" then "Wedge" else "Block")
		local light = ""
		for _, l in p:GetChildren() do
			local cls = rawget(l, "_class")
			if cls == "PointLight" or cls == "SpotLight" then
				light = string.format(',"L":[%s,%s,%s,%s,%s]', num(l.Color.R), num(l.Color.G), num(l.Color.B), num(l.Range), num(l.Brightness))
			end
		end
		print(string.format('{"n":"%s","shape":"%s","s":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s],"c":[%s,%s,%s],"t":%s,"m":"%s"%s}',
			p.Name, shape, num(p.Size.X), num(p.Size.Y), num(p.Size.Z), num(cf.p[1]), num(cf.p[2]), num(cf.p[3]),
			table.concat((function() local t = {} for i = 1, 9 do t[i] = num(cf.r[i]) end return t end)(), ","),
			num(c.R), num(c.G), num(c.B), num(p.Transparency or 0), p.Material and p.Material.Name or "Plastic", light))
	end
end
'''
    driver = driver.replace("@@REGION@@", REGION)
    src = "\n".join(["game = {}", cframe, mock,
                     "ZONES = (function()\n" + zones + "\nend)()",
                     "NPCS = (function()\n" + npcs + "\nend)()",
                     "BUILD = (function()\n" + build + "\nend)()",
                     "TOWN = (function()\n" + town + "\nend)()",
                     "SEIREITEI = (function()\n" + seireitei + "\nend)()",
                     "HUECO = (function()\n" + hueco + "\nend)()",
                     "REGIONS = (function()\n" + regions + "\nend)()", driver])
    path = os.path.join(here, ".city.luau")
    open(path, "w", encoding="utf-8").write(src)
    res = subprocess.run([LUAU, path], capture_output=True, text=True)
    if res.returncode != 0 or res.stderr.strip():
        raise SystemExit(res.stdout[-1500:] + res.stderr[-3000:])
    parts, terrain = [], []
    for line in res.stdout.splitlines():
        if line.startswith('{"terrain"'):
            terrain.append(json.loads(line))
        elif line.startswith("{"):
            parts.append(json.loads(line))
    return parts, terrain


def polys_of(parts, terrain):
    """Lista de (pontos mundo Nx3, cor, emissivo, transparência)."""
    out = []
    for t in terrain:
        (x, y, z), (sx, sy, sz) = t["p"], t["s"]
        top = y + sy / 2
        col = {"Water": (0.05, 0.12, 0.2), "Concrete": (0.33, 0.33, 0.35)}.get(t["terrain"], (0.3, 0.3, 0.3))
        if t["terrain"] == "Water":
            top -= 0.6
        # em ladrilhos: a luz das lâmpadas é calculada por face
        step = 12
        for gx in np.arange(x - sx / 2, x + sx / 2, step):
            for gz in np.arange(z - sz / 2, z + sz / 2, step):
                x1, z1 = min(gx + step, x + sx / 2), min(gz + step, z + sz / 2)
                quad = [(gx, top, gz), (x1, top, gz), (x1, top, z1), (gx, top, z1)]
                out.append((np.array(quad), col, t["terrain"] == "Water", 0, "terrain"))
    for part in parts:
        r, p = part["r"], part["p"]
        R = np.array(r).reshape(3, 3)
        P = np.array(p)
        neon = part["m"] == "Neon"
        for poly in local_polys(part):
            pts = np.array(poly) @ R.T + P
            # faces grandes (fachadas de torre) em ladrilhos: a ordenação por profundidade não deixa
            # a fachada inteira cobrir as janelas e lajes que estão na frente dela
            if len(pts) == 4:
                nu = max(1, int(np.linalg.norm(pts[1] - pts[0]) // 10))
                nv = max(1, int(np.linalg.norm(pts[3] - pts[0]) // 10))
                if nu * nv > 1:
                    for i in range(nu):
                        for j in range(nv):
                            def at(u, v):
                                a = pts[0] + (pts[1] - pts[0]) * u
                                b = pts[3] + (pts[2] - pts[3]) * u
                                return a + (b - a) * v
                            u0, u1, v0, v1 = i / nu, (i + 1) / nu, j / nv, (j + 1) / nv
                            quad = np.array([at(u0, v0), at(u1, v0), at(u1, v1), at(u0, v1)])
                            out.append((quad, tuple(part["c"]), neon, part["t"], part.get("L") if i == 0 and j == 0 else None))
                    continue
            out.append((pts, tuple(part["c"]), neon, part["t"], part.get("L")))
    return out


def render(polys, lights, cam, target, fov, size, out, label):
    W, H = size
    cam, target = np.array(cam, float), np.array(target, float)
    fwd = target - cam; fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    focal = (W / 2) / math.tan(math.radians(fov) / 2)
    moon = np.array([-0.4, 0.8, 0.45]); moon /= np.linalg.norm(moon)
    sun = np.array([0.35, 0.75, -0.55]); sun /= np.linalg.norm(sun)
    fog = np.array([0.80, 0.85, 0.91])
    L = np.array([l[0] for l in lights]) if lights else np.zeros((0, 3))
    LC = np.array([l[1] for l in lights]) if lights else np.zeros((0, 3))
    LR = np.array([l[2] for l in lights]) if lights else np.zeros(0)
    LB = np.array([l[3] for l in lights]) if lights else np.zeros(0)
    items = []
    centers = np.array([pts.mean(0) for pts, *_ in polys])
    # luz das lâmpadas por face (vetorizado)
    glow = np.zeros((len(polys), 3))
    if len(L):
        for k in range(0, len(L), 64):
            d = np.linalg.norm(centers[:, None, :] - L[None, k:k + 64, :], axis=2)
            f = np.clip(1 - d / LR[None, k:k + 64], 0, 1) ** 2 * LB[None, k:k + 64]
            glow += f @ LC[k:k + 64]
    for i, (pts, col, emissive, transp, _) in enumerate(polys):
        rel = pts - cam
        z = rel @ fwd
        if (z < 0.5).any():
            continue
        x = rel @ right; y = rel @ up
        sx = W / 2 + focal * x / z; sy = H / 2 - focal * y / z
        if sx.max() < 0 or sx.min() > W or sy.max() < 0 or sy.min() > H:
            continue
        c = np.array(col)
        if emissive and col != (0.05, 0.12, 0.2):
            shade = c * 1.25 + 0.1
        else:
            if len(pts) >= 3:
                n = np.cross(pts[1] - pts[0], pts[2] - pts[0]); nn = np.linalg.norm(n)
                n = n / nn if nn > 0 else np.array([0, 1, 0])
            else:
                n = np.array([0, 1, 0])
            if DAY:
                # tarde: luz do sol + céu; superfícies voltadas para baixo ficam na sombra
                shade = c * (0.52 + 0.5 * max(0.0, float(n @ sun)) + 0.12 * max(0.0, float(n[1])))
            else:
                diffuse = abs(n @ moon) * 0.22
                shade = c * (0.16 + diffuse) + c * glow[i] * 0.55 + glow[i] * 0.05
            if col == (0.05, 0.12, 0.2):  # água reflete as luzes
                shade = c + glow[i] * 0.12 + 0.04
        if DAY:
            # névoa azulada da Atmosphere: some no horizonte como no anime
            haze = 1 - math.exp(-max(0.0, float(z.mean()) - 60) / 1100)
            shade = shade * (1 - haze) + fog * haze
        rgb = tuple(int(255 * min(1, v)) for v in shade)
        # o chão do Terrain fica sempre atrás do que está apoiado nele (calçadas, pátios, ruas)
        key = z.mean() + (4.0 if polys[i][4] == "terrain" else 0.0)
        items.append((key, list(zip(sx, sy)), rgb, transp, emissive))
    items.sort(key=lambda q: -q[0])
    img = Image.new("RGB", (W, H), (10, 14, 30))
    # céu noturno em degradê
    sky = ImageDraw.Draw(img)
    for yy in range(H):
        t = yy / H
        if DAY:
            sky.line([(0, yy), (W, yy)], fill=(int(150 + 60 * t), int(180 + 40 * t), int(222 + 15 * t)))
        else:
            sky.line([(0, yy), (W, yy)], fill=(int(14 + 30 * t), int(18 + 34 * t), int(40 + 50 * t)))
    draw = ImageDraw.Draw(img)
    bloom = Image.new("RGB", (W, H), (0, 0, 0))
    bdraw = ImageDraw.Draw(bloom)
    for _, pts, rgb, transp, emissive in items:
        if transp > 0.05:
            continue
        draw.polygon(pts, fill=rgb)
        # brilho só do que aparece: o que não emite tapa o brilho de trás
        bdraw.polygon(pts, fill=rgb if emissive else (0, 0, 0))
    bloom = bloom.filter(ImageFilter.GaussianBlur(6))
    if DAY:
        bloom = Image.eval(bloom, lambda v: v // 4)
    img = Image.blend(img, Image.fromarray(np.clip(np.array(img, int) + np.array(bloom, int) * 0.8, 0, 255).astype("uint8")), 1)
    ImageDraw.Draw(img).text((8, 6), label, fill=(240, 240, 240))
    return img


if __name__ == "__main__":
    parts, terrain = run()
    polys = polys_of(parts, terrain)
    lights = []
    for part in parts:
        if part.get("L"):
            l = part["L"]
            lights.append((part["p"], l[:3], l[3], min(l[4], 3)))
    views = [
        ("Karakura do alto (como no anime)", (-60, 330, -620), (40, 0, 260), 60),
        ("Vista aérea (sudeste)", (470, 300, -470), (0, 70, 0), 55),
        ("Avenida central (rua)", (4, 6, -215), (0, 8, 40), 70),
        ("Centro: cruzamento e praça", (6, 16, -110), (-10, 4, 10), 70),
        ("Horizonte do centro (da margem do rio)", (-250, 10, -20), (0, 95, 0), 72),
        ("Bairro residencial", (-215, 9, -150), (-100, 6, -150), 70),
    ]
    if REGION == "Trees":
        views = [
            ("Arvores: cerejeira, de rua, pinheiro", (0, 12, -55), (0, 8, 0), 70),
            ("Arvores de perto", (-14, 9, -22), (-22, 9, 0), 70),
        ]
    if REGION == "HuecoMundo":
        o = -3000
        views = [
            ("Deserto rumo a Las Noches", (o + 10, 18, -250), (o, 70, 300), 70),
            ("Hueco Mundo do alto", (o + 320, 250, -430), (o, 0, 60), 60),
            ("Carcaca de Hollow", (o + 140, 16, -20), (o + 205, 12, 60), 70),
            ("Fenda dos Menos", (o + 45, 24, -80), (o, 0, -20), 70),
            ("Arena diante de Las Noches", (o + 6, 26, 110), (o, 50, 330), 72),
            ("Floresta de quartzo", (o + 110, 9, -270), (o + 220, 12, -200), 70),
        ]
    if REGION == "SoulSociety":
        o = 3000
        views = [
            ("Seireitei do alto", (o - 80, 230, -430), (o, 0, 30), 60),
            ("Portao do Seireitei (de dentro)", (o + 6, 12, -150), (o, 18, -226), 70),
            ("Avenida rumo ao pagode", (o + 4, 9, -190), (o, 34, 150), 68),
            ("Lago e ponte da praça", (o + 34, 12, -46), (o, 3, 6), 70),
            ("Sokyoku e Senzaikyu", (o + 10, 110, -40), (o, 70, 190), 70),
            ("Quarteirao de divisao", (o - 30, 34, -150), (o - 150, 6, -185), 70),
        ]
    tiles = [render(polys, lights, cam, tgt, fov, (640, 400), None, label) for label, cam, tgt, fov in views]
    sheet = Image.new("RGB", (1280, 1200))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 2) * 640, (i // 2) * 400))
    sheet.save(sys.argv[1])
    print(len(parts), "peças,", len(lights), "luzes")

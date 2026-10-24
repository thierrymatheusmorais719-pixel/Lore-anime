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
sys.path.insert(0, here)
from preview import module, local_polys  # noqa: E402


def run():
    cframe = open(os.path.join(root, "tools", "cframe_stub.luau"), encoding="utf-8").read().split("-- @@FIM_CFRAME@@")[0]
    mock = open(os.path.join(here, "roblox_mock.luau"), encoding="utf-8").read()
    zones = module("src/shared/Config/Zones.luau", {})
    npcs = module("src/shared/Config/NPCs.luau", {})
    build = module("src/server/World/Build.luau", {})
    town = module("src/server/World/Town.luau", {r"require\(script\.Parent\.Build\)": "BUILD"})
    regions = module("src/server/World/Regions.luau", {
        r"require\(ReplicatedStorage\.Shared\.Config\.Zones\)": "ZONES",
        r"require\(ReplicatedStorage\.Shared\.Config\.NPCs\)": "NPCS",
        r"require\(script\.Parent\.Build\)": "BUILD",
        r"require\(script\.Parent\.Town\)": "TOWN",
    })
    driver = r'''
workspace = Instance.new("Workspace")
workspace.Terrain = { FillBlock = function(_, cf, size, material)
	print(string.format('{"terrain":"%s","p":[%.2f,%.2f,%.2f],"s":[%.2f,%.2f,%.2f]}', material.Name, cf.p[1], cf.p[2], cf.p[3], size.X, size.Y, size.Z))
end }
local folder = Instance.new("Folder")
REGIONS.Karakura(folder)
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
    src = "\n".join(["game = {}", cframe, mock,
                     "ZONES = (function()\n" + zones + "\nend)()",
                     "NPCS = (function()\n" + npcs + "\nend)()",
                     "BUILD = (function()\n" + build + "\nend)()",
                     "TOWN = (function()\n" + town + "\nend)()",
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
                out.append((np.array(quad), col, t["terrain"] == "Water", 0, None))
    for part in parts:
        r, p = part["r"], part["p"]
        R = np.array(r).reshape(3, 3)
        P = np.array(p)
        neon = part["m"] == "Neon"
        for poly in local_polys(part):
            pts = np.array(poly) @ R.T + P
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
            diffuse = abs(n @ moon) * 0.22
            shade = c * (0.16 + diffuse) + c * glow[i] * 0.55 + glow[i] * 0.05
            if col == (0.05, 0.12, 0.2):  # água reflete as luzes
                shade = c + glow[i] * 0.12 + 0.04
        rgb = tuple(int(255 * min(1, v)) for v in shade)
        items.append((z.mean(), list(zip(sx, sy)), rgb, transp, emissive))
    items.sort(key=lambda q: -q[0])
    img = Image.new("RGB", (W, H), (10, 14, 30))
    # céu noturno em degradê
    sky = ImageDraw.Draw(img)
    for yy in range(H):
        t = yy / H
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
        ("Vista aérea (sudeste)", (330, 210, -330), (-20, 0, 30), 55),
        ("Avenida central (rua)", (4, 6, -215), (0, 8, 40), 70),
        ("Centro: cruzamento e praça", (6, 16, -110), (-10, 4, 10), 70),
        ("Rua comercial coberta", (-75, 7, 22), (-75, 7, 140), 75),
        ("Trilho elevado (avenida leste)", (143, 7, -222), (150, 20, 20), 70),
        ("Bairro residencial", (-215, 9, -150), (-100, 6, -150), 70),
    ]
    tiles = [render(polys, lights, cam, tgt, fov, (640, 400), None, label) for label, cam, tgt, fov in views]
    sheet = Image.new("RGB", (1280, 1200))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 2) * 640, (i // 2) * 400))
    sheet.save(sys.argv[1])
    print(len(parts), "peças,", len(lights), "luzes")

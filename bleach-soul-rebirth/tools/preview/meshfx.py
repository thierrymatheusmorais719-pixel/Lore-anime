#!/usr/bin/env python3
"""Quadros congelados dos efeitos de malha (Shared/Fx/MeshFxRecipes + MeshShapes, código real)
vistos da câmera do jogador: cada linha é um efeito, cada coluna um instante. Fundo médio
(nem preto nem branco) para ver as camadas pretas e as claras. Uso:
  LUAU=caminho/luau python3 tools/preview/meshfx.py saida.png"""
import json, math, os, re, subprocess, sys
from PIL import Image, ImageDraw

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, "..", ".."))
LUAU = os.environ.get("LUAU", "luau")
TIMES = [0.01, 0.04, 0.08, 0.14, 0.25, 0.45]
CAMERA = (3.5, 2.5, 12.0)


def module(path):
    code = open(os.path.join(root, path), encoding="utf-8").read()
    code = re.sub(r"^export type ", "type ", code, flags=re.M)
    return code


def run():
    cframe = open(os.path.join(root, "tools", "cframe_stub.luau"), encoding="utf-8").read().split("-- @@FIM_CFRAME@@")[0]
    cframe = cframe.replace("local CFrame = {", "CFrame = {")
    mock = open(os.path.join(root, "tools", "sim", "client_mock.luau"), encoding="utf-8").read()
    extra = r'''
Color3 = { new = function(r, g, b) local c = { R = r, G = g, B = b }
	function c:Lerp(o, t) return Color3.new(self.R + (o.R - self.R) * t, self.G + (o.G - self.G) * t, self.B + (o.B - self.B) * t) end
	return c end }
function typeof(v) if type(v) == "table" and getmetatable(v) == V3 then return "Vector3" end return type(v) end
Random = { new = function(seed)
	local state = (seed or 12345) % 2147483647
	if state <= 0 then state += 2147483646 end
	local r = {}
	local function nxt() state = (state * 16807) % 2147483647 return state / 2147483647 end
	function r:NextNumber(a, b) if a == nil then return nxt() end return a + (b - a) * nxt() end
	function r:NextInteger(a, b) return math.floor(a + (b - a + 1) * nxt()) end
	return r end }
function V3.Min(a, b) return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function V3.Max(a, b) return Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
CFrame.fromAxisAngle = function(axis, angle)
	local u = axis.Unit
	local c, sn = math.cos(angle), math.sin(angle)
	local t = 1 - c
	local x, y, z = u.X, u.Y, u.Z
	return CFrame.new(0, 0, 0, t * x * x + c, t * x * y - sn * z, t * x * z + sn * y, t * x * y + sn * z, t * y * y + c, t * y * z - sn * x, t * x * z - sn * y, t * y * z + sn * x, t * z * z + c)
end
CFrame.lookAt = function(at, target, up)
	up = up or Vector3.yAxis
	local z = (at - target).Unit
	if math.abs(z:Dot(up)) > 0.999 then up = Vector3.xAxis end
	local x = up:Cross(z).Unit
	local y = z:Cross(x)
	return CFrame.new(at.X, at.Y, at.Z, x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z)
end
'''
    shapes = module("src/shared/Fx/MeshShapes.luau")
    recipes = module("src/shared/Fx/MeshFxRecipes.luau")
    driver = open(os.path.join(here, "meshfx_driver.luau"), encoding="utf-8").read()
    src = "\n".join([cframe, mock, extra,
                     "local MeshShapes = (function()\n" + shapes + "\nend)()",
                     "local Recipes = (function()\n" + recipes + "\nend)()",
                     f"local CAMERA = Vector3.new({CAMERA[0]}, {CAMERA[1]}, {CAMERA[2]})",
                     "local TIMES = {" + ",".join(str(t) for t in TIMES) + "}", driver])
    path = os.path.join(here, ".meshfx.luau")
    open(path, "w", encoding="utf-8").write(src)
    res = subprocess.run([LUAU, path], capture_output=True, text=True)
    if res.returncode != 0 or res.stderr.strip():
        raise SystemExit(res.stdout[-2000:] + res.stderr[-3000:])
    return [json.loads(l) for l in res.stdout.splitlines() if l.startswith("{")]


def render(frames, out, cell=260):
    labels = []
    for f in frames:
        if f["effect"] not in labels:
            labels.append(f["effect"])
    img = Image.new("RGB", (cell * len(TIMES), cell * len(labels)), (0, 0, 0))
    cam = CAMERA
    target = (0, 1, 0)
    fwd = [target[i] - cam[i] for i in range(3)]
    n = math.sqrt(sum(x * x for x in fwd)); fwd = [x / n for x in fwd]
    right = [fwd[2] * 0 - fwd[1] * 0, 0, 0]
    up0 = (0, 1, 0)
    right = [fwd[1] * up0[2] - fwd[2] * up0[1], fwd[2] * up0[0] - fwd[0] * up0[2], fwd[0] * up0[1] - fwd[1] * up0[0]]
    n = math.sqrt(sum(x * x for x in right)); right = [x / n for x in right]
    up = [right[1] * fwd[2] - right[2] * fwd[1], right[2] * fwd[0] - right[0] * fwd[2], right[0] * fwd[1] - right[1] * fwd[0]]
    focal = cell * 0.9
    for f in frames:
        row, col = labels.index(f["effect"]), TIMES.index(f["time"]) if f["time"] in TIMES else 0
        ox, oy = col * cell, row * cell
        tile = Image.new("RGBA", (cell, cell), (70, 78, 92, 255))
        polys = []
        for tri in f["tris"]:
            pts, depth = [], 0
            ok = True
            for v in tri["p"]:
                d = [v[i] - cam[i] for i in range(3)]
                z = sum(d[i] * fwd[i] for i in range(3))
                if z < 0.1:
                    ok = False
                    break
                x = sum(d[i] * right[i] for i in range(3))
                y = sum(d[i] * up[i] for i in range(3))
                pts.append((cell / 2 + focal * x / z, cell / 2 - focal * y / z))
                depth += z
            if ok:
                polys.append((depth / 3, pts, tri["c"], tri["a"], tri["neon"]))
        polys.sort(key=lambda q: -q[0])
        for _, pts, c, a, neon in polys:
            boost = 1.25 if neon else 1
            col_ = tuple(min(255, int(255 * x * boost)) for x in c) + (int(255 * (1 - a)),)
            layer = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
            ImageDraw.Draw(layer).polygon(pts, fill=col_)
            tile = Image.alpha_composite(tile, layer)
        ImageDraw.Draw(tile).text((6, 4), f'{f["effect"]}  t={f["time"]:.2f}s', fill=(235, 235, 235, 255))
        img.paste(tile.convert("RGB"), (ox, oy))
    img.save(out)


if __name__ == "__main__":
    frames = run()
    render(frames, sys.argv[1])
    print(len(frames), "quadros")

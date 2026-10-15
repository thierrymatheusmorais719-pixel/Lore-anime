#!/usr/bin/env python3
"""
Edit cinematográfica medieval 16:9: renderizador procedural (numpy + OpenCV + ffmpeg).

Dá vida às 7 pinturas de referência sem redesenhá-las:
  * câmera 2.5D: mapas de profundidade (Depth Anything V2) dão parallax real
    entre primeiro plano, personagens e fundo durante pans, tilts e dollies;
  * "rigs" de marionete: braços, mãos, cabeças e troncos giram/respiram em
    torno de articulações (pivôs), recortados pela profundidade;
  * vento em cabelos, capas, vestidos, relva e flores;
  * estrelas cintilando, lua/sol pulsando, raios de luz, brilho metálico,
    nuvens, chuva, relâmpagos e partículas;
  * cortes, gestos, pulsos de câmera e luz presos à grade de batidas da música.

Uso:
    python3 depth.py MODELO.onnx          # uma vez: gera depth/*.png
    python3 render.py AUDIO [saida.mp4]   # renderiza
    python3 render.py AUDIO saida.mp4 --stills 1.5,6.8
"""
import math, os, subprocess, sys
from multiprocessing import Pool

import cv2
import numpy as np
from PIL import Image

cv2.setNumThreads(1)
HERE = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1920, 1080, 30
LW, LH = W // 2, H // 2           # grade de baixa resolução para os campos de deslocamento
OVERSAMPLE = 1.10

# Grade da música (≈84,6 BPM): colcheia 0,3548 s, tempo 0,71 s, compasso 2,84 s
BEAT = 0.3548
BAR = 8 * BEAT
CUTS = [0.0, 3.98, 6.82, 9.66, 12.50, 15.34, 18.18]
DUR = 21.05
ACCENTS = [1.14, 2.21, 2.90, 3.98, 4.33, 5.76, 6.48, 8.23, 9.30, 10.37, 10.72,
           13.55, 15.66, 18.89, 19.95]

def S(a, period=BAR, ph=0.0):
    """Oscilação presa ao compasso."""
    return lambda t, u: a * math.sin(2 * math.pi * t / period + ph)

def ramp(a, b=0.0, osc=0.0, period=BAR, ph=0.0):
    """Gesto progressivo de a até b ao longo do plano + oscilação no ritmo."""
    return lambda t, u: a + (b - a) * (0.5 - 0.5 * math.cos(math.pi * u)) + osc * math.sin(2 * math.pi * t / period + ph)

ZERO = lambda t, u: 0.0

def rig(c, r, pivot, rot=ZERO, tx=ZERO, ty=ZERO, scale=ZERO, gate=0.16):
    return dict(c=c, r=r, pivot=pivot, rot=rot, tx=tx, ty=ty, scale=scale, gate=gate)

# ---------------------------------------------------------------------------
# Direção. Coordenadas normalizadas na pintura original (x, y em 0..1).
#   cam: [(cx, cy, zoom, rot°), ...]  keyframes distribuídos no plano
#   orbit: deslocamento lateral/vertical da câmera 3D (parallax) início->fim
#   dolly: aproximação 3D (planos próximos crescem mais) início->fim
# ---------------------------------------------------------------------------
SHOTS = [
    dict(file="01-varanda-rosa", note="o cavaleiro oferece a rosa",
         cam=[(0.62, 0.24, 1.00, 0.0), (0.50, 0.38, 1.10, 0.0), (0.45, 0.40, 1.28, -0.5)],
         orbit=((-1.0, 0.3), (1.0, -0.2)), dolly=(0.0, 1.0),
         rigs=[
             # antebraço + mão + rosa: ergue a rosa em direção à dama
             rig((0.455, 0.375), (0.050, 0.075), (0.405, 0.445), rot=ramp(1.5, -3.5, osc=0.8)),
             # cabeça do cavaleiro inclina para ela
             rig((0.335, 0.345), (0.050, 0.055), (0.335, 0.400), rot=ramp(0.0, -2.2, osc=0.4, ph=1.0)),
             # cabeça da dama se aproxima da rosa
             rig((0.565, 0.400), (0.045, 0.055), (0.575, 0.455), rot=ramp(0.0, 2.6, osc=0.5, ph=2.0)),
             # respiração da dama
             rig((0.585, 0.500), (0.070, 0.060), (0.585, 0.545), scale=S(0.010, 2 * BAR / 3)),
         ],
         sway=[(0.610, 0.440, 0.030, 0.060, 1.6), (0.58, 0.80, 0.12, 0.10, 1.4)],
         ground=lambda x, y: np.clip((y - 0.62) / 0.1, 0, 1) * np.clip((0.30 - x) / 0.1, 0, 1),
         sky=lambda x, y: np.clip((x - 0.42) / 0.06, 0, 1) * np.clip((0.50 - y) / 0.06, 0, 1),
         stars=1.2, clouds=0.0, glint=0.8, glow=1.0, wind=1.4, rays=None, rain=0,
         parts=dict(kind="firefly", n=70, color=(1.0, 0.85, 0.55)), petals_from=(0.47, 0.33),
         grade=(1.00, 0.98, 1.03)),
    dict(file="02-varanda-lua", note="a dama olha a lua; ele a observa",
         cam=[(0.55, 0.22, 1.05, 0.0), (0.45, 0.40, 1.02, 0.0), (0.50, 0.45, 1.10, 0.0)],
         orbit=((1.0, -0.6), (-1.0, 0.4)), dolly=(0.2, 0.8),
         rigs=[
             rig((0.245, 0.270), (0.050, 0.060), (0.250, 0.335), rot=ramp(-1.0, 2.5, osc=0.5)),     # elmo vira para ela
             rig((0.790, 0.420), (0.045, 0.050), (0.800, 0.480), rot=ramp(1.0, -2.0, osc=0.5, ph=1.5)),  # dama ergue o olhar
             rig((0.810, 0.560), (0.080, 0.070), (0.810, 0.620), scale=S(0.010, 2 * BAR / 3)),       # respiração
             rig((0.350, 0.530), (0.045, 0.035), (0.300, 0.530), rot=S(1.6, BAR, 0.7)),             # mãos no joelho
         ],
         sway=[(0.790, 0.400, 0.040, 0.040, 0.9), (0.62, 0.78, 0.12, 0.12, 1.2)],
         ground=lambda x, y: np.clip((y - 0.55) / 0.1, 0, 1) * 0.5,
         sky=lambda x, y: np.clip((x - 0.30) / 0.06, 0, 1) * np.clip((0.40 - y) / 0.1, 0, 1),
         stars=1.3, clouds=0.0, glint=0.9, glow=1.2, wind=1.2, rays=None, rain=0,
         parts=dict(kind="firefly", n=90, color=(1.0, 0.88, 0.6)),
         grade=(0.97, 1.00, 1.04)),
    dict(file="03-juramento-castelo", note="o juramento diante do castelo",
         cam=[(0.45, 0.28, 1.02, 0.0), (0.48, 0.45, 1.00, 0.0), (0.50, 0.56, 1.12, 0.4)],
         orbit=((-1.0, 0.0), (1.0, 0.0)), dolly=(0.0, 1.0),
         rigs=[
             rig((0.410, 0.505), (0.050, 0.050), (0.400, 0.560), rot=ramp(0.0, 3.0, osc=0.6)),      # cavaleiro curva a cabeça
             rig((0.640, 0.320), (0.040, 0.050), (0.660, 0.370), rot=ramp(0.0, 2.2, osc=0.5, ph=1)),  # dama inclina
             rig((0.420, 0.660), (0.050, 0.070), (0.420, 0.620), rot=S(1.0, BAR, 0.4)),             # mãos no punho da espada
             rig((0.380, 0.560), (0.070, 0.060), (0.380, 0.620), scale=S(0.010, 2 * BAR / 3)),       # respiração
         ],
         sway=[(0.70, 0.62, 0.07, 0.16, 1.4), (0.76, 0.80, 0.08, 0.06, 1.8), (0.64, 0.33, 0.03, 0.04, 0.8)],
         ground=lambda x, y: np.clip((y - 0.62) / 0.1, 0, 1),
         sky=lambda x, y: np.clip((0.26 - y) / 0.06, 0, 1) * np.clip((0.80 - x) / 0.1, 0, 1),
         stars=0.0, clouds=0.6, glint=1.1, glow=0.5, wind=1.8, rays=(0.12, 0.08, 0.35), rain=0,
         parts=dict(kind="dust", n=70, color=(1.0, 0.93, 0.78)),
         grade=(1.02, 1.00, 0.97)),
    dict(file="04-abraco-elmo", note="ela segura o elmo dele",
         cam=[(0.45, 0.36, 1.00, -0.8), (0.48, 0.42, 1.10, 0.0), (0.52, 0.44, 1.22, 0.8)],
         orbit=((0.8, 0.2), (-0.8, -0.2)), dolly=(0.0, 1.0),
         rigs=[
             # elmo + mãos dela: ele encosta o rosto nas mãos dela
             rig((0.610, 0.430), (0.120, 0.130), (0.640, 0.620), rot=ramp(-1.0, 2.0, osc=0.6), gate=0.25),
             # cabeça dela se inclina sobre ele
             rig((0.360, 0.270), (0.110, 0.120), (0.360, 0.420), rot=ramp(0.0, -2.2, osc=0.5, ph=1.2), gate=0.25),
             # manopla dele aperta a mão dela
             rig((0.580, 0.530), (0.070, 0.080), (0.600, 0.640), rot=S(1.4, BAR, 0.5)),
             # respiração dele
             rig((0.800, 0.700), (0.180, 0.150), (0.800, 0.800), scale=S(0.010, 2 * BAR / 3)),
         ],
         sway=[(0.16, 0.30, 0.12, 0.20, 1.6), (0.20, 0.82, 0.18, 0.14, 1.2), (0.86, 0.55, 0.10, 0.10, 1.4)],
         ground=lambda x, y: np.zeros_like(x),
         sky=lambda x, y: np.zeros_like(x),
         stars=0.0, clouds=0.0, glint=1.4, glow=0.6, wind=1.0, rays=None, rain=0,
         parts=dict(kind="dust", n=55, color=(1.0, 0.9, 0.7)),
         grade=(1.03, 1.00, 0.96)),
    dict(file="05-tempestade", note="a tempestade",
         cam=[(0.60, 0.58, 1.30, 0.0), (0.52, 0.52, 1.12, 0.0), (0.50, 0.48, 1.00, -0.4)],
         orbit=((1.0, 0.3), (-1.0, -0.2)), dolly=(1.0, 0.0),
         rigs=[
             rig((0.400, 0.380), (0.060, 0.070), (0.370, 0.460), rot=ramp(0.0, 2.5, osc=0.7)),      # cavaleiro baixa a cabeça
             rig((0.600, 0.600), (0.040, 0.050), (0.590, 0.670), rot=ramp(0.0, -2.0, osc=0.6, ph=2)),  # dama
             rig((0.610, 0.700), (0.060, 0.050), (0.600, 0.740), scale=S(0.012, 2 * BAR / 3)),       # respiração
         ],
         sway=[(0.530, 0.620, 0.070, 0.050, 3.2), (0.12, 0.45, 0.11, 0.09, 2.8), (0.80, 0.86, 0.15, 0.09, 2.0)],
         ground=lambda x, y: np.clip((y - 0.70) / 0.06, 0, 1),
         sky=lambda x, y: np.clip((0.58 - y) / 0.06, 0, 1) * np.clip((x - 0.30) / 0.1, 0, 1) + np.clip((0.30 - y) / 0.06, 0, 1),
         stars=0.0, clouds=1.0, glint=0.8, glow=0.7, wind=2.6, rays=(0.66, 0.45, 0.26), rain=1,
         parts=dict(kind="petal", n=45, color=(0.85, 0.55, 0.6)),
         grade=(0.95, 0.99, 1.05)),
    dict(file="06-armadura-relva", note="a armadura vazia",
         cam=[(0.45, 0.48, 1.20, 2.0), (0.48, 0.50, 1.12, 0.0), (0.52, 0.50, 1.05, -2.0)],
         orbit=((0.0, -1.0), (0.0, 1.0)), dolly=(1.0, 0.0),
         rigs=[],
         sway=[],
         ground=lambda x, y: np.ones_like(x),
         sky=lambda x, y: np.zeros_like(x),
         stars=0.0, clouds=0.0, glint=1.2, glow=0.4, wind=2.4, rays=None, rain=0,
         parts=dict(kind="pollen", n=60, color=(1.0, 0.95, 0.8)),
         grade=(1.00, 1.00, 0.98)),
    dict(file="07-armadura-flores", note="memória dourada",
         cam=[(0.45, 0.62, 1.00, 0.0), (0.52, 0.48, 1.08, 0.0), (0.60, 0.36, 1.20, 0.4)],
         orbit=((-1.0, 0.5), (1.0, -0.5)), dolly=(0.0, 1.0),
         rigs=[],
         sway=[],
         ground=lambda x, y: np.ones_like(x),
         sky=lambda x, y: np.zeros_like(x),
         stars=0.0, clouds=0.0, glint=1.3, glow=1.1, wind=2.4, rays=(0.08, 0.05, 0.40), rain=0,
         parts=dict(kind="pollen", n=100, color=(1.0, 0.82, 0.5)),
         grade=(1.05, 0.99, 0.92)),
]
TRANS = [None, ("leak", 0.70), ("whip", 0.36), ("flash", 0.40),
         ("lightning", 0.50), ("dissolve", 1.10), ("leak", 0.90)]

# ---------------------------------------------------------------------------
def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)

def ease_io(x):
    return 0.5 - 0.5 * math.cos(math.pi * min(max(x, 0.0), 1.0))

def gblur(a, sigma):
    return cv2.GaussianBlur(a, (0, 0), sigma) if sigma > 0 else a

def fbm(w, h, seed, octaves=5, base=6):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32); amp, tot = 1.0, 0.0
    for o in range(octaves):
        g = base * 2 ** o
        n = rng.random((g, max(2, int(g * w / h)))).astype(np.float32)
        out += amp * cv2.resize(n, (w, h), interpolation=cv2.INTER_CUBIC)
        tot += amp; amp *= 0.5
    return out / tot

def interp_cam(keys, e):
    """Spline suave pelos keyframes de câmera (e em 0..1)."""
    n = len(keys) - 1
    x = e * n; i = min(int(x), n - 1); f = ease_io(x - i)
    a, b = keys[i], keys[i + 1]
    return [a[k] + (b[k] - a[k]) * f for k in range(4)]

# ---------------------------------------------------------------------------
_cache = {}

def load_shot(i):
    if i in _cache:
        return _cache[i]
    if len(_cache) >= 2:
        _cache.pop(next(iter(_cache)))
    sh = SHOTS[i]
    im = Image.open(os.path.join(HERE, "refs", sh["file"] + ".jpg")).convert("RGB")
    ow, oh = im.size
    s = max(W / ow, H / oh) * OVERSAMPLE
    sw, shh = int(ow * s), int(oh * s)
    rgb = np.asarray(im.resize((sw, shh), Image.LANCZOS), np.float32) / 255
    sharp = rgb + (rgb - gblur(rgb, 2.0)) * 0.6
    rgb = np.clip(sharp, 0, 1).astype(np.float32)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    sat, lum = hsv[..., 1], rgb.mean(2)
    yy, xx = np.mgrid[0:shh, 0:sw].astype(np.float32)
    xn, yn = xx / sw, yy / shh
    dep = np.asarray(Image.open(os.path.join(HERE, "depth", sh["file"] + ".png")), np.float32) / 65535
    dep = cv2.resize(dep, (sw, shh), interpolation=cv2.INTER_CUBIC)
    sky = gblur(np.clip(sh["sky"](xn, yn), 0, 1).astype(np.float32), 10) * np.clip((0.45 - dep) / 0.2, 0, 1)
    ground = gblur(sh["ground"](xn, yn).astype(np.float32), 10)
    star = np.clip(lum - gblur(lum, 2.2 * s) - 0.05, 0, 1) * sky * 3.0
    metal = np.clip((lum - 0.30) / 0.45, 0, 1) * np.clip(1 - sat / 0.38, 0, 1) * (1 - sky)
    metal = gblur(metal, 1.5)
    glow = gblur(np.clip((lum - 0.68) / 0.3, 0, 1), 12 * s)
    phase = cv2.resize(np.random.default_rng(i).random((shh // 3 + 1, sw // 3 + 1)).astype(np.float32),
                       (sw, shh), interpolation=cv2.INTER_NEAREST)
    hi_a = np.dstack([rgb, star]).astype(np.float32)
    hi_b = np.dstack([metal, glow, sky, phase]).astype(np.float32)
    # ---- campos de baixa resolução: profundidade, vento e máscaras dos rigs ----
    q = 4
    lw, lh = sw // q, shh // q
    xl, yl = xn[::q, ::q][:lh, :lw], yn[::q, ::q][:lh, :lw]
    depl = cv2.resize(dep, (lw, lh), interpolation=cv2.INTER_AREA)
    # dilata o primeiro plano um pouco para o recorte não "rasgar" nas bordas
    depl = gblur(cv2.dilate(depl, np.ones((3, 3), np.uint8)), 1.2)
    satl = cv2.resize(sat, (lw, lh), interpolation=cv2.INTER_AREA)
    metl = cv2.resize(metal, (lw, lh), interpolation=cv2.INTER_AREA)
    grl = cv2.resize(ground, (lw, lh), interpolation=cv2.INTER_AREA)
    veg = np.clip((satl - 0.12) / 0.25, 0, 1) * (1 - np.clip(metl * 2.5, 0, 1)) * grl
    for (cx, cy, rx, ry, a) in sh["sway"]:
        e = np.exp(-(((xl - cx) / rx) ** 2 + ((yl - cy) / ry) ** 2) * 2.0)
        veg = np.maximum(veg, e * a / 2.0)
    veg = gblur(veg.astype(np.float32), 2)
    masks = []
    for r in sh["rigs"]:
        (cx, cy), (rx, ry) = r["c"], r["r"]
        e2 = ((xl - cx) / rx) ** 2 + ((yl - cy) / ry) ** 2
        core = e2 < 0.3
        dc = float(np.median(depl[core])) if core.any() else 0.5
        gate = np.clip(1 - np.abs(depl - dc) / r["gate"], 0, 1)
        m = smooth((1.0 - e2) / 0.7) * gate
        masks.append(gblur(m.astype(np.float32), 2.0))
    lo = np.dstack([depl, veg] + masks).astype(np.float32)
    _cache[i] = dict(hi_a=hi_a, hi_b=hi_b, lo=lo, q=q, s=s, sw=sw, sh=shh)
    return _cache[i]

def remap(src, mx, my, interp=cv2.INTER_LINEAR):
    return cv2.remap(src, mx, my, interp, borderMode=cv2.BORDER_REFLECT_101)

LGY, LGX = np.mgrid[0:LH, 0:LW].astype(np.float32) * 2 + 0.5
GY, GX = np.mgrid[0:H, 0:W].astype(np.float32)

def accent(t, decay=0.22):
    v = 0.0
    for a in ACCENTS:
        if 0 <= t - a < 1.0:
            v = max(v, math.exp(-(t - a) / decay))
    return v

# ---- partículas ------------------------------------------------------------
def particles(i, tl, t):
    cfg = SHOTS[i]["parts"]; kind = cfg["kind"]
    rng = np.random.default_rng(100 + i)
    n = cfg["n"]
    x0 = rng.random(n) * W; y0 = rng.random(n) * H
    depth = rng.random(n) ** 1.6
    ph = rng.random(n) * 6.283
    if kind == "firefly":
        vx, vy, wob = (rng.random(n) - .5) * 40, -10 - 25 * rng.random(n), 30
    elif kind == "dust":
        vx, vy, wob = 15 + 30 * rng.random(n), -5 - 12 * rng.random(n), 14
    elif kind == "petal":
        vx, vy, wob = -260 - 320 * rng.random(n), 60 + 90 * rng.random(n), 40
    else:
        vx, vy, wob = 20 + 35 * rng.random(n), -14 - 26 * rng.random(n), 18
    sp = 0.6 + depth * 1.2
    px = (x0 + vx * sp * tl + wob * np.sin(0.9 * tl + ph)) % (W + 80) - 40
    py = (y0 + vy * sp * tl + wob * np.cos(0.7 * tl + ph * 1.3)) % (H + 80) - 40
    size = 2 + depth * (12 if kind != "petal" else 9)
    if kind == "firefly":
        alpha = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * math.pi * t / (2 * BEAT) + ph * 3))
    else:
        alpha = 0.25 + 0.35 * (0.5 + 0.5 * np.sin(1.3 * t + ph))
    alpha = alpha * (0.35 + 0.65 * depth)
    return px, py, size, alpha, np.array(cfg["color"], np.float32), kind

def draw_particles(img, parts, rot=None):
    px, py, size, alpha, col, kind = parts
    for x, y, s, a in zip(px, py, size, alpha):
        r = int(s * 2.5) + 2
        xi, yi = int(x), int(y)
        xa, xb, ya, yb = max(xi - r, 0), min(xi + r + 1, W), max(yi - r, 0), min(yi + r + 1, H)
        if xa >= xb or ya >= yb:
            continue
        gx = np.arange(xa, xb, dtype=np.float32) - x
        gy = np.arange(ya, yb, dtype=np.float32)[:, None] - y
        d = (gx * 0.55) ** 2 + gy ** 2 if kind == "petal" else gx ** 2 + gy ** 2
        g = np.exp(-d / (2 * (s * 0.6) ** 2)) * a
        if kind == "firefly":
            g += np.exp(-d / (2 * (s * 1.8) ** 2)) * a * 0.35
        if kind == "petal":
            img[ya:yb, xa:xb] = img[ya:yb, xa:xb] * (1 - g[..., None] * 0.8) + col * g[..., None] * 0.8
        else:
            img[ya:yb, xa:xb] += col * g[..., None]

def rose_petals(img, t, t_start, src_xy):
    """Pétalas que se soltam da rosa e caem girando."""
    rng = np.random.default_rng(7)
    for k in range(7):
        t0 = t_start + 0.4 + k * 0.45 + rng.random() * 0.2
        if t < t0:
            continue
        a = t - t0
        x = src_xy[0] + 90 * a + 25 * math.sin(2.5 * a + k) - 60 * a * a * 0.2
        y = src_xy[1] + 70 * a * a + 30 * a
        if not (0 <= x < W and 0 <= y < H):
            continue
        ang = 2.0 * a + k
        sz = 7 + 3 * rng.random()
        r = int(sz * 2) + 2
        xa, xb, ya, yb = max(int(x) - r, 0), min(int(x) + r, W), max(int(y) - r, 0), min(int(y) + r, H)
        gx = np.arange(xa, xb, dtype=np.float32) - x
        gy = np.arange(ya, yb, dtype=np.float32)[:, None] - y
        u = gx * math.cos(ang) + gy * math.sin(ang); v = -gx * math.sin(ang) + gy * math.cos(ang)
        g = np.exp(-((u / sz) ** 2 + (v / (sz * 0.45 * (0.6 + 0.4 * abs(math.sin(3 * a + k))))) ** 2) * 2) * 0.85
        img[ya:yb, xa:xb] = img[ya:yb, xa:xb] * (1 - g[..., None]) + np.array([0.92, 0.55, 0.58], np.float32) * g[..., None]

CLOUD = None
def cloud_tex():
    global CLOUD
    if CLOUD is None:
        c = fbm(W * 2, H, 7, octaves=5, base=3)
        CLOUD = np.clip((c - 0.42) / 0.35, 0, 1)
    return CLOUD

RAIN = None
def rain_layer(t):
    global RAIN
    if RAIN is None:
        rng = np.random.default_rng(3)
        n = 380
        RAIN = (rng.random(n) * (W + 400) - 200, rng.random(n) * H, 0.5 + rng.random(n), rng.random(n))
    x0, y0, z, a = RAIN
    lay = np.zeros((H, W), np.float32)
    for x, y, zz, aa in zip(x0, y0, z, a):
        yy = (y + t * 1500 * zz) % (H + 100) - 50
        xx = x - (yy - y) * 0.30
        L = 30 * zz
        cv2.line(lay, (int(xx), int(yy)), (int(xx - L * 0.3), int(yy - L)), 0.12 + 0.18 * aa * zz, 1, cv2.LINE_AA)
    return gblur(lay, 0.6)

# ---------------------------------------------------------------------------
def shot_span(i):
    t0 = CUTS[i]
    t1 = CUTS[i + 1] if i + 1 < len(CUTS) else DUR
    pre = TRANS[i][1] / 2 if TRANS[i] else 0
    post = TRANS[i + 1][1] / 2 if i + 1 < len(TRANS) and TRANS[i + 1] else 0
    return t0 - pre, t1 + post

def render_shot(i, t, extra_zoom=1.0, blur_dir=0.0):
    sh = SHOTS[i]
    D = load_shot(i)
    sw, shh, s, q = D["sw"], D["sh"], D["s"], D["q"]
    a, b = shot_span(i)
    u = min(max((t - a) / (b - a), 0.0), 1.0)
    tl = t - a
    cx, cy, z, rotd = interp_cam(sh["cam"], u)
    z *= extra_zoom * (1 + 0.015 * accent(t))
    rot = math.radians(rotd)
    jx = 1.6 * math.sin(t * 0.71 + i) + 0.8 * math.sin(t * 1.93 + 2 * i)
    jy = 1.4 * math.sin(t * 0.53 + 3 * i) + 0.7 * math.sin(t * 1.61 + i)
    base = max(W / sw, H / shh)
    k = 1.0 / (base * z) / (1 + abs(math.sin(rot)) * 1.8)
    hw, hh = W / 2 * k, H / 2 * k
    m = 12 * s   # margem para o parallax não puxar a borda
    ccx = min(max(cx * sw, hw + m), sw - hw - m) + jx
    ccy = min(max(cy * shh, hh + m), shh - hh - m) + jy
    X, Y = LGX - W / 2, LGY - H / 2
    cr, sr = math.cos(rot), math.sin(rot)
    sx = ccx + (X * cr - Y * sr) * k
    sy = ccy + (X * sr + Y * cr) * k
    # ---- câmera 2.5D: parallax por profundidade ----
    e = ease_io(u)
    (ox0, oy0), (ox1, oy1) = sh["orbit"]
    ox, oy = ox0 + (ox1 - ox0) * e, oy0 + (oy1 - oy0) * e
    d0, d1 = sh["dolly"]
    dl = d0 + (d1 - d0) * e
    P = 0.018 * sw           # amplitude do parallax (px fonte por unidade de profundidade)
    lo = D["lo"]
    bx, by = sx.copy(), sy.copy()
    for _ in range(2):
        dep = remap(lo[..., 0], sx / q, sy / q)
        rel = dep - 0.45
        sx = bx - ox * P * rel - (bx - ccx) * rel * 0.05 * dl
        sy = by - oy * P * rel - (by - ccy) * rel * 0.05 * dl
    # ---- campos dos rigs e do vento ----
    ch = remap(lo[..., 1:], sx / q, sy / q)
    if ch.ndim == 2:
        ch = ch[..., None]
    veg = ch[..., 0]
    for n_, r in enumerate(sh["rigs"]):
        w = ch[..., 1 + n_]
        px, py = r["pivot"][0] * sw, r["pivot"][1] * shh
        th = math.radians(r["rot"](t, u)) * w
        sc = 1 + r["scale"](t, u) * w
        dx, dy = sx - px, sy - py
        c_, s_ = np.cos(th), np.sin(th)
        sx = px + (dx * c_ + dy * s_) / sc - r["tx"](t, u) * sw * w
        sy = py + (-dx * s_ + dy * c_) / sc - r["ty"](t, u) * shh * w
    A = sh["wind"] * s / 2.2
    gust = 0.7 + 0.3 * math.sin(2 * math.pi * t / BAR + i)
    sx = sx + veg * A * gust * (np.sin(t * 1.9 + sy * 0.011 + sx * 0.004) + 0.45 * np.sin(t * 3.3 + sy * 0.037))
    sy = sy + veg * A * 0.35 * np.sin(t * 1.4 + sx * 0.009)
    mx = cv2.resize(sx, (W, H), interpolation=cv2.INTER_LINEAR)
    my = cv2.resize(sy, (W, H), interpolation=cv2.INTER_LINEAR)
    A_ = remap(D["hi_a"], mx, my, cv2.INTER_CUBIC)
    B_ = remap(D["hi_b"], mx, my)
    if blur_dir:
        taps = (-1.0, -0.66, -0.33, 0.33, 0.66, 1.0)
        for o in taps:
            A_ = A_ + remap(D["hi_a"], mx + blur_dir * o * k, my)
        A_ /= len(taps) + 1
    rgb = A_[..., :3].copy()
    star = A_[..., 3]
    metal, glow, sky, phase = B_[..., 0], B_[..., 1], B_[..., 2], B_[..., 3]
    if sh["stars"]:
        tw = 0.5 + 0.5 * np.sin(t * (2.0 + 3.0 * phase) + phase * 40)
        rgb += (star * (tw - 0.35) * 0.55 * sh["stars"])[..., None] * np.array([0.95, 0.97, 1.0], np.float32)
    breath = 0.5 + 0.5 * math.sin(2 * math.pi * t / (2 * BAR / 4) + i)   # pulsa a cada 2 tempos
    rgb += (glow * (0.06 + 0.07 * breath) * sh["glow"])[..., None] * np.array([1.0, 0.92, 0.75], np.float32)
    if sh["glint"]:
        pos = -0.4 + 1.8 * u
        dd = (GX / W * 0.7 + GY / H * 0.5) - pos
        bandv = np.exp(-(dd / 0.06) ** 2) + 0.25 * np.exp(-(dd / 0.2) ** 2)
        rgb += (np.maximum(metal, 0) ** 1.5 * bandv * (0.30 + 0.25 * accent(t)) * sh["glint"])[..., None] * np.array([1.0, 0.93, 0.80], np.float32)
    if sh["clouds"]:
        ct = cloud_tex()
        off = int((t * 45) % W)
        c = ct[:, off:off + W]
        light = 0.55 + 0.45 * math.sin(t * 0.6)
        tint = np.array([0.62, 0.66, 0.70], np.float32)
        mm = (c * sky * sh["clouds"] * 0.40)[..., None]
        rgb = rgb * (1 - mm) + (tint * (0.7 + 0.3 * light)) * mm
    off = int((t * 18 + 500) % W)
    fog = (cloud_tex()[:, off:off + W] * np.clip((GY / H - 0.55) / 0.45, 0, 1) * 0.06)[..., None]
    rgb = rgb * (1 - fog) + np.array([0.7, 0.72, 0.75], np.float32) * fog
    # raios de luz (god rays) a partir da fonte de luz
    if sh["rays"]:
        lx, ly, amt = sh["rays"]
        # posição da luz na tela (inversa aproximada da câmera)
        dxs, dys = lx * sw - ccx, ly * shh - ccy
        Lx = W / 2 + (dxs * cr + dys * sr) / k
        Ly = H / 2 + (-dxs * sr + dys * cr) / k
        small = cv2.resize(rgb, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
        hi = np.clip((small.mean(2) - 0.55) / 0.35, 0, 1)
        acc = np.zeros_like(hi)
        cxs, cys = Lx / 4, Ly / 4
        for j in range(24):
            sc = 1 - j * 0.025
            M = np.float32([[sc, 0, cxs * (1 - sc)], [0, sc, cys * (1 - sc)]])
            acc += cv2.warpAffine(hi, M, (W // 4, H // 4), borderMode=cv2.BORDER_CONSTANT) * (1 - j / 24)
        acc /= 12
        flick = 0.85 + 0.15 * math.sin(2 * math.pi * t / BAR * 2) + 0.2 * accent(t)
        rays = cv2.resize(acc, (W, H), interpolation=cv2.INTER_LINEAR)
        rgb += (rays * amt * flick)[..., None] * np.array([1.0, 0.9, 0.7], np.float32)
    if sh["rain"]:
        rgb += rain_layer(t)[..., None] * np.array([0.75, 0.8, 0.9], np.float32)
    draw_particles(rgb, particles(i, tl, t))
    if "petals_from" in sh:
        lx, ly = sh["petals_from"]
        dxs, dys = lx * sw - ccx, ly * shh - ccy
        rose_petals(rgb, t, a, (W / 2 + (dxs * cr + dys * sr) / k, H / 2 + (-dxs * sr + dys * cr) / k))
    rgb *= np.array(sh["grade"], np.float32)
    return rgb

# ---------------------------------------------------------------------------
VIG = None
def finish(rgb, t, rng):
    global VIG
    if VIG is None:
        d = np.sqrt(((GX - W / 2) / (W * 0.60)) ** 2 + ((GY - H / 2) / (H * 0.62)) ** 2)
        VIG = (1 - 0.55 * smooth((d - 0.45) / 0.75))[..., None].astype(np.float32)
    hi = np.clip((rgb - 0.62) / 0.38, 0, 1).astype(np.float32)
    sm = cv2.resize(hi, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
    rgb = rgb + cv2.resize(gblur(sm, 7), (W, H)) * 0.32 + cv2.resize(gblur(sm, 2), (W, H)) * 0.12
    lum = rgb.mean(2, keepdims=True)
    rgb = lum + (rgb - lum) * 0.88
    rgb = rgb + np.array([-0.012, 0.004, 0.010], np.float32) * (1 - smooth(lum / 0.5)) \
              + np.array([0.030, 0.012, -0.022], np.float32) * smooth((lum - 0.45) / 0.5)
    rgb = np.clip(rgb, 0, None)
    rgb = rgb / (1 + 0.18 * rgb)
    c = np.clip(rgb * 1.10 - 0.025, 0, 1)
    rgb = smooth(c) * 0.35 + c * 0.65
    rgb *= VIG
    g = rng.standard_normal((H // 2, W // 2)).astype(np.float32)
    g = cv2.resize(g, (W, H), interpolation=cv2.INTER_LINEAR)
    rgb += g[..., None] * 0.020 * (0.6 + 0.4 * (1 - lum))
    fade = smooth(t / 1.0) * smooth((DUR - t) / 1.6)
    rgb = rgb * fade
    # barras de cinema finas
    bar = int(round(H * 0.06))
    rgb[:bar] = 0; rgb[H - bar:] = 0
    return np.clip(rgb, 0, 1)

def leak(t, center, dur, warm=(1.0, 0.62, 0.30)):
    p = max(1 - abs(t - center) / (dur / 2), 0) ** 1.5
    cx = W * (0.15 + 0.7 * ((t - center) / dur + 0.5))
    d = np.sqrt(((GX - cx) / (W * 0.6)) ** 2 + ((GY - H * 0.3) / (H * 0.9)) ** 2)
    return (np.exp(-d * d * 2.2) * p * 0.42)[..., None] * np.array(warm, np.float32)

def transition(kind, j, t, p, d):
    A = lambda **kw: render_shot(j - 1, t, **kw)
    B = lambda **kw: render_shot(j, t, **kw)
    if kind == "leak":
        m = smooth(p)
        return A() * (1 - m) + B() * m + leak(t, CUTS[j], d)
    if kind == "whip":
        s = math.sin(math.pi * p)
        bd = 60 * s
        if p < 0.5:
            return A(extra_zoom=1 + 0.06 * s, blur_dir=bd)
        return B(extra_zoom=1 + 0.06 * s, blur_dir=-bd)
    if kind == "flash":
        if p < 0.5:
            img = A(extra_zoom=1 + 0.04 * p); f = smooth(p * 2) ** 2
        else:
            img = B(extra_zoom=1 + 0.03 * (1 - p)); f = smooth((1 - p) * 2) ** 2
        return img * (1 - 0.25 * f) + f * 0.55 * np.array([1.0, 0.95, 0.88], np.float32)
    if kind == "lightning":
        if p < 0.5:
            return A() * (1 - smooth(p * 2))
        return B() * smooth((p - 0.5) * 2.2)
    if kind == "dissolve":
        a, b = A(), B()
        lum = b.mean(2, keepdims=True)
        m = smooth(np.clip((p * 1.6 - (1 - lum) * 0.6), 0, 1))
        return a * (1 - m) + b * m
    raise ValueError(kind)

def frame(fi):
    t = fi / FPS
    rng = np.random.default_rng(10_000 + fi)
    cur = max(k for k in range(len(CUTS)) if CUTS[k] <= t)
    out = None
    for j in (cur, cur + 1):
        if 0 < j < len(TRANS) and TRANS[j]:
            kind, d = TRANS[j]
            c = CUTS[j]
            if c - d / 2 <= t < c + d / 2:
                out = transition(kind, j, t, (t - (c - d / 2)) / d, d)
                break
    if out is None:
        out = render_shot(cur, t)
    if CUTS[4] <= t < CUTS[5]:   # relâmpagos na tempestade, nos acentos
        for lt in (CUTS[4] + 0.02, CUTS[4] + 0.20, 13.55, 13.66):
            if 0 <= t - lt < 0.25:
                out = out + (math.exp(-(t - lt) / 0.06) * 0.28) * np.array([0.85, 0.9, 1.0], np.float32)
    return (finish(out, t, rng) * 255 + 0.5).astype(np.uint8)

# ---------------------------------------------------------------------------
def render_chunk(args):
    k, frames, path = args
    with open(path, "wb") as f:
        for fi in frames:
            f.write(frame(fi).tobytes())
    return path

def main():
    audio = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else os.path.join(HERE, "edit-medieval-16x9.mp4")
    if "--stills" in sys.argv:
        for t in [float(x) for x in sys.argv[sys.argv.index("--stills") + 1].split(",")]:
            Image.fromarray(frame(int(round(t * FPS)))).save(os.path.join(os.path.dirname(os.path.abspath(out)), f"still_{t:05.2f}.jpg"), quality=90)
        return
    n = int(DUR * FPS)
    tmp = os.path.dirname(os.path.abspath(out))
    procs = os.cpu_count() or 4
    step = math.ceil(n / procs)
    chunks = [(k, list(range(k * step, min(n, (k + 1) * step))), os.path.join(tmp, f"_chunk{k}.raw"))
              for k in range(procs) if k * step < n]
    with Pool(len(chunks)) as pool:
        paths = pool.map(render_chunk, chunks)
    cat = subprocess.Popen(["cat", *paths], stdout=subprocess.PIPE)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
                    "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-i", audio,
                    "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-preset", "slow",
                    "-crf", "21", "-pix_fmt", "yuv420p", "-tune", "film",
                    "-af", f"afade=t=in:d=0.3,afade=t=out:st={DUR-1.6:.2f}:d=1.6",
                    "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", "-shortest", out],
                   stdin=cat.stdout, check=True)
    for p in paths:
        os.remove(p)
    print("ok:", out)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Edit cinematográfica medieval — renderizador procedural (numpy + PIL + ffmpeg).

Anima as 7 pinturas de referência sem redesenhá-las: câmera virtual (push-in,
pan, tilt, pull-out, rotação lenta), parallax por profundidade vertical, vento
nas flores/relva/cabelos/tecidos, estrelas cintilando, lua/sol respirando,
brilho metálico varrendo as armaduras, nuvens/névoa em movimento, partículas,
transições sincronizadas à grade de batidas da música e grade de cor de cinema.

Uso:
    python3 render.py AUDIO.m4a [saida.mp4] [--preview]
"""
import math, os, subprocess, sys
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
REFS = os.path.join(HERE, "refs")
W, H, FPS = 1080, 1920, 30
OVERSAMPLE = 1.12          # fonte ampliada um pouco acima do "cover" para zooms nítidos

# Grade de batidas medida na música (≈84,6 BPM; colcheia = 0,355 s; 8 colcheias = 2,84 s)
BEAT0, BEAT = 1.14, 0.3548
CUTS = [0.0, 3.98, 6.82, 9.66, 12.50, 15.34, 18.18]
DUR = 21.05
# Acentos fortes (onsets medidos) — pequenos "pulsos" de câmera/exposição
ACCENTS = [1.14, 2.21, 2.90, 3.98, 4.33, 5.76, 6.48, 8.23, 9.30, 10.37, 10.72,
           13.55, 15.66, 18.89, 19.95]

# ---------------------------------------------------------------------------
# Direção de cada plano. Coordenadas normalizadas na pintura original.
#   cam: (t0, t1) -> (cx, cy, zoom, rot_graus) com easing
#   sky: função (x,y)->[0,1] para estrelas/nuvens;  ground: área de vegetação
#   sway: elipses (cx, cy, rx, ry, amplitude px) para cabelo/tecido
# ---------------------------------------------------------------------------
def band(y, a, b):   # 1 acima de a, 0 abaixo de b, suave
    return np.clip((b - y) / max(b - a, 1e-6), 0, 1)

SHOTS = [
    dict(file="01-varanda-rosa.jpg",   # amor nascendo: push-in lento até a rosa
         cam=[(0.56, 0.47, 1.00, 0.0), (0.47, 0.40, 1.20, -0.4)],
         sky=lambda x, y: np.clip((x - 0.40) / 0.1, 0, 1) * band(y, 0.45, 0.55),
         ground=lambda x, y: np.clip((y - 0.62) / 0.1, 0, 1) * np.clip((0.30 - x) / 0.1, 0, 1),
         sway=[(0.58, 0.85, 0.12, 0.08, 1.2)],
         stars=1.0, clouds=0.0, glint=0.7, glow=0.9, wind=1.6,
         parts=dict(kind="firefly", n=55, color=(1.0, 0.85, 0.55)),
         grade=(1.00, 0.98, 1.03)),
    dict(file="02-varanda-lua.jpg",    # saudade: travelling lateral do cavaleiro à dama
         cam=[(0.36, 0.52, 1.06, 0.0), (0.62, 0.50, 1.10, 0.0)],
         sky=lambda x, y: np.clip((x - 0.33) / 0.08, 0, 1) * band(y, 0.38, 0.52),
         ground=lambda x, y: np.clip((y - 0.55) / 0.1, 0, 1) * 0.6,
         sway=[(0.76, 0.12, 0.05, 0.05, 0.0)],
         stars=1.2, clouds=0.0, glint=0.9, glow=1.1, wind=1.4,
         parts=dict(kind="firefly", n=70, color=(1.0, 0.88, 0.6)),
         grade=(0.97, 1.00, 1.04)),
    dict(file="03-juramento-castelo.jpg",  # honra: tilt-down do castelo ao juramento
         cam=[(0.44, 0.27, 1.28, 0.0), (0.46, 0.56, 1.06, 0.3)],
         sky=lambda x, y: band(y, 0.22, 0.42) * np.clip((0.78 - x) / 0.1, 0, 1),
         ground=lambda x, y: np.clip((y - 0.55) / 0.1, 0, 1),
         sway=[(0.68, 0.80, 0.08, 0.10, 1.4)],
         stars=0.0, clouds=0.55, glint=1.0, glow=0.5, wind=1.8,
         parts=dict(kind="dust", n=60, color=(1.0, 0.93, 0.78)),
         grade=(1.02, 1.00, 0.97)),
    dict(file="04-abraco-elmo.jpg",    # ternura: push-in com leve rotação
         cam=[(0.47, 0.50, 1.00, -0.8), (0.45, 0.42, 1.18, 0.6)],
         sky=lambda x, y: np.zeros_like(x),
         ground=lambda x, y: np.zeros_like(x),
         sway=[(0.12, 0.30, 0.10, 0.18, 1.6), (0.20, 0.80, 0.18, 0.15, 1.4)],
         stars=0.0, clouds=0.0, glint=1.4, glow=0.6, wind=1.0,
         parts=dict(kind="dust", n=45, color=(1.0, 0.9, 0.7)),
         grade=(1.03, 1.00, 0.96)),
    dict(file="05-tempestade.jpg",     # sacrifício: pull-out na tempestade, relâmpago
         cam=[(0.55, 0.60, 1.30, 0.0), (0.50, 0.52, 1.04, -0.3)],
         sky=lambda x, y: band(y, 0.40, 0.58),
         ground=lambda x, y: np.clip((y - 0.62) / 0.08, 0, 1),
         sway=[(0.62, 0.56, 0.08, 0.07, 2.2), (0.14, 0.42, 0.10, 0.12, 2.0),
               (0.82, 0.84, 0.14, 0.10, 1.6)],
         stars=0.0, clouds=0.9, glint=0.8, glow=0.7, wind=2.4,
         parts=dict(kind="petal", n=40, color=(0.85, 0.55, 0.6)),
         grade=(0.95, 0.99, 1.05)),
    dict(file="06-armadura-relva.jpg", # morte: plano zenital com rotação lenta
         cam=[(0.45, 0.50, 1.22, 2.0), (0.50, 0.50, 1.08, -1.5)],
         sky=lambda x, y: np.zeros_like(x),
         ground=lambda x, y: np.ones_like(x),
         sway=[],
         stars=0.0, clouds=0.0, glint=1.2, glow=0.4, wind=2.0,
         parts=dict(kind="pollen", n=50, color=(1.0, 0.95, 0.8)),
         grade=(1.00, 1.00, 0.98)),
    dict(file="07-armadura-flores.jpg",  # memória: push-in dourado e fade final
         cam=[(0.50, 0.55, 1.02, 0.0), (0.58, 0.38, 1.24, 0.4)],
         sky=lambda x, y: np.zeros_like(x),
         ground=lambda x, y: np.ones_like(x),
         sway=[],
         stars=0.0, clouds=0.0, glint=1.3, glow=1.1, wind=2.0,
         parts=dict(kind="pollen", n=80, color=(1.0, 0.82, 0.5)),
         grade=(1.05, 0.99, 0.92)),
]
# transições na entrada de cada plano (índice = plano que entra) e sua duração
TRANS = [None, ("leak", 0.70), ("whip", 0.36), ("flash", 0.40),
         ("lightning", 0.50), ("dissolve", 1.10), ("leak", 0.90)]

# ---------------------------------------------------------------------------
def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)

def ease_io(x):  # easeInOutSine
    return 0.5 - 0.5 * math.cos(math.pi * min(max(x, 0), 1))

def blur(a, r):
    """Blur ~gaussiano de um array float 2D (3 passadas de box blur separável)."""
    a = a.astype(np.float32)
    k = max(1, int(round(r * 0.58)))      # 3 boxes de raio k ≈ gaussiana de sigma r
    for _ in range(3):
        for ax in (0, 1):
            p = np.pad(a, [(k + 1, k) if d == ax else (0, 0) for d in (0, 1)], mode="edge")
            c = np.cumsum(p, axis=ax, dtype=np.float64)
            hi = np.take(c, np.arange(2 * k + 1, c.shape[ax]), axis=ax)
            lo = np.take(c, np.arange(0, c.shape[ax] - 2 * k - 1), axis=ax)
            a = ((hi - lo) / (2 * k + 1)).astype(np.float32)
    return a

def blur_rgb(a, r, down=1):
    h, w = a.shape[:2]
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    if down > 1:
        im = im.resize((w // down, h // down), Image.BILINEAR)
    im = im.filter(ImageFilter.GaussianBlur(r / down))
    if down > 1:
        im = im.resize((w, h), Image.BILINEAR)
    return np.asarray(im, np.float32) / 255

def fbm(w, h, seed, octaves=5, base=6):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32); amp, tot = 1.0, 0.0
    for o in range(octaves):
        g = base * 2 ** o
        n = rng.random((g, max(2, int(g * w / h)))).astype(np.float32)
        out += amp * np.asarray(Image.fromarray(n, "F").resize((w, h), Image.BICUBIC))
        tot += amp; amp *= 0.5
    return out / tot

# ---------------------------------------------------------------------------
_cache = {}

def load_shot(i):
    """Prepara a pintura ampliada + canais auxiliares (estrelas, metal, céu, vegetação, brilho)."""
    if i in _cache:
        return _cache[i]
    if len(_cache) >= 2:
        _cache.pop(next(iter(_cache)))
    sh = SHOTS[i]
    im = Image.open(os.path.join(REFS, sh["file"])).convert("RGB")
    ow, oh = im.size
    s = max(W / ow, H / oh) * OVERSAMPLE
    sw, shh = int(ow * s), int(oh * s)
    big = im.resize((sw, shh), Image.LANCZOS).filter(ImageFilter.UnsharpMask(2.2, 70, 2))
    rgb = np.asarray(big, np.float32) / 255
    hsv = np.asarray(big.convert("HSV"), np.float32) / 255
    sat, lum = hsv[..., 1], rgb.mean(2)
    yy, xx = np.mgrid[0:shh, 0:sw].astype(np.float32)
    xn, yn = xx / sw, yy / shh
    sky = blur(sh["sky"](xn, yn).astype(np.float32), 12)
    ground = blur(sh["ground"](xn, yn).astype(np.float32), 12)
    # estrelas: picos locais de luz no céu
    star = np.clip(lum - blur(lum, 5 * s / 2) - 0.06, 0, 1) * sky * 3.0
    star = np.clip(star, 0, 1)
    # metal: realces claros e pouco saturados (prata/aço)
    metal = np.clip((lum - 0.30) / 0.45, 0, 1) * np.clip(1 - sat / 0.38, 0, 1) * (1 - sky)
    metal = blur(metal, 1.5)
    # vegetação/tecido para o vento
    veg = np.clip((sat - 0.12) / 0.25, 0, 1) * (1 - np.clip(metal * 2.5, 0, 1)) * ground
    for (cx, cy, rx, ry, a) in sh["sway"]:
        e = np.exp(-(((xn - cx) / rx) ** 2 + ((yn - cy) / ry) ** 2) * 2.0)
        veg = np.maximum(veg, e * a / 2.0)
    veg = blur(veg, 4)
    # halo de luz (lua, pôr do sol, reflexos)
    glow = blur(np.clip((lum - 0.68) / 0.3, 0, 1), 28 * s / 2.3)
    phase = np.asarray(Image.fromarray(
        np.random.default_rng(i).random((shh // 3 + 1, sw // 3 + 1)).astype(np.float32), "F"
    ).resize((sw, shh), Image.NEAREST))
    src = np.dstack([rgb, star, metal, sky, veg, glow, phase]).astype(np.float32)
    _cache[i] = (src, s)
    return _cache[i]

def sample(src, sx, sy):
    """Amostragem bilinear (remap) de todos os canais."""
    h, w = src.shape[:2]
    sx = np.clip(sx, 0, w - 1.001); sy = np.clip(sy, 0, h - 1.001)
    x0 = sx.astype(np.int32); y0 = sy.astype(np.int32)
    fx = (sx - x0)[..., None]; fy = (sy - y0)[..., None]
    a = src[y0, x0]; b = src[y0, x0 + 1]; c = src[y0 + 1, x0]; d = src[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy

GY, GX = np.mgrid[0:H, 0:W].astype(np.float32)

def accent(t, decay=0.22):
    v = 0.0
    for a in ACCENTS:
        if 0 <= t - a < 1.0:
            v = max(v, math.exp(-(t - a) / decay))
    return v

# ---- partículas (estado determinístico por plano) ----
def particles(i, t_local, t):
    cfg = SHOTS[i]["parts"]; kind = cfg["kind"]
    rng = np.random.default_rng(100 + i)
    n = cfg["n"]
    x0 = rng.random(n) * W; y0 = rng.random(n) * H
    depth = rng.random(n) ** 1.6          # 0 = longe, 1 = perto (maior e mais desfocada)
    ph = rng.random(n) * 6.283
    if kind == "firefly":
        vx, vy = (rng.random(n) - .5) * 25, -8 - 18 * rng.random(n)
        wob = 22
    elif kind == "dust":
        vx, vy = 10 + 20 * rng.random(n), -4 - 8 * rng.random(n); wob = 10
    elif kind == "petal":
        vx, vy = -160 - 220 * rng.random(n), 40 + 60 * rng.random(n); wob = 30
    else:  # pollen
        vx, vy = 15 + 25 * rng.random(n), -10 - 20 * rng.random(n); wob = 14
    sp = 0.6 + depth * 1.2
    px = (x0 + vx * sp * t_local + wob * np.sin(0.9 * t_local + ph)) % (W + 80) - 40
    py = (y0 + vy * sp * t_local + wob * np.cos(0.7 * t_local + ph * 1.3)) % (H + 80) - 40
    size = 1.5 + depth * (9 if kind != "petal" else 7)
    if kind == "firefly":
        alpha = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2.2 * t + ph * 3))
    else:
        alpha = 0.25 + 0.35 * (0.5 + 0.5 * np.sin(1.3 * t + ph))
    alpha = alpha * (0.35 + 0.65 * depth)
    return px, py, size, alpha, np.array(cfg["color"], np.float32), kind

def draw_particles(img, parts):
    px, py, size, alpha, col, kind = parts
    for x, y, s, a in zip(px, py, size, alpha):
        r = int(s * 2.5) + 2
        xi, yi = int(x), int(y)
        xa, xb, ya, yb = max(xi - r, 0), min(xi + r + 1, W), max(yi - r, 0), min(yi + r + 1, H)
        if xa >= xb or ya >= yb:
            continue
        gx = np.arange(xa, xb, dtype=np.float32) - x
        gy = np.arange(ya, yb, dtype=np.float32)[:, None] - y
        if kind == "petal":
            d = (gx * 0.55) ** 2 + gy ** 2
        else:
            d = gx ** 2 + gy ** 2
        g = np.exp(-d / (2 * (s * 0.6) ** 2)) * a
        if kind == "firefly":  # núcleo + halo
            g += np.exp(-d / (2 * (s * 1.8) ** 2)) * a * 0.35
        if kind == "petal":
            img[ya:yb, xa:xb] = img[ya:yb, xa:xb] * (1 - g[..., None] * 0.8) + col * g[..., None] * 0.8
        else:
            img[ya:yb, xa:xb] += col * g[..., None]

CLOUD = None
def cloud_tex():
    global CLOUD
    if CLOUD is None:
        c = fbm(W * 2, H, 7, octaves=5, base=3)
        CLOUD = np.clip((c - 0.42) / 0.35, 0, 1)
    return CLOUD

# ---------------------------------------------------------------------------
def shot_span(i):
    t0 = CUTS[i]
    t1 = CUTS[i + 1] if i + 1 < len(CUTS) else DUR
    pre = TRANS[i][1] / 2 if TRANS[i] else 0
    post = TRANS[i + 1][1] / 2 if i + 1 < len(TRANS) and TRANS[i + 1] else 0
    return t0 - pre, t1 + post

def render_shot(i, t, extra_zoom=1.0, blur_dir=0.0):
    sh = SHOTS[i]
    src, s = load_shot(i)
    sh_h, sh_w = src.shape[:2]
    a, b = shot_span(i)
    u = (t - a) / (b - a)
    e = ease_io(u)
    (cx0, cy0, z0, r0), (cx1, cy1, z1, r1) = sh["cam"]
    cx, cy = cx0 + (cx1 - cx0) * e, cy0 + (cy1 - cy0) * e
    z = (z0 + (z1 - z0) * e) * extra_zoom * (1 + 0.012 * accent(t))
    rot = math.radians(r0 + (r1 - r0) * e)
    # micro "câmera na mão" muito sutil
    jx = 1.4 * math.sin(t * 0.71 + i) + 0.7 * math.sin(t * 1.93 + 2 * i)
    jy = 1.2 * math.sin(t * 0.53 + 3 * i) + 0.6 * math.sin(t * 1.61 + i)
    base = max(W / sh_w, H / sh_h)
    k = 1.0 / (base * z)
    zmargin = 1 + abs(math.sin(rot)) * 1.2
    k /= zmargin
    hw, hh = W / 2 * k, H / 2 * k
    ccx = min(max(cx * sh_w, hw + 4), sh_w - hw - 4) + jx
    ccy = min(max(cy * sh_h, hh + 4), sh_h - hh - 4) + jy
    X, Y = GX - W / 2, GY - H / 2
    cr, sr = math.cos(rot), math.sin(rot)
    sx = ccx + (X * cr - Y * sr) * k
    sy = ccy + (X * sr + Y * cr) * k
    # parallax: primeiro plano (baixo) desliza mais que o fundo durante o movimento
    par = (cx1 - cx0) * sh_w * 0.06 + 18 * (z1 - z0)
    sx += par * (e - 0.5) * (GY / H - 0.45) * 2
    # vento: deslocamento dirigido pela máscara de vegetação/tecido
    yi = np.clip(sy, 0, sh_h - 1).astype(np.int32)[::4, ::4]
    xi = np.clip(sx, 0, sh_w - 1).astype(np.int32)[::4, ::4]
    veg = np.asarray(Image.fromarray(src[yi, xi, 6], "F").resize((W, H), Image.BILINEAR))
    A = sh["wind"] * s / 2.2
    gust = 0.75 + 0.25 * math.sin(t * 0.45 + i)
    sx = sx + veg * A * gust * (np.sin(t * 1.7 + sy * 0.011 + sx * 0.004)
                                + 0.45 * np.sin(t * 3.1 + sy * 0.037))
    sy = sy + veg * A * 0.35 * np.sin(t * 1.3 + sx * 0.009)
    smp = sample(src, sx, sy)
    if blur_dir:
        taps = (-1.0, -0.66, -0.33, 0.33, 0.66, 1.0)
        for o in taps:
            smp = smp + sample(src, sx + blur_dir * o * k, sy)
        smp /= len(taps) + 1
    rgb = smp[..., :3].copy()
    star, metal, sky, glow, phase = smp[..., 3], smp[..., 4], smp[..., 5], smp[..., 7], smp[..., 8]
    # estrelas cintilando
    if sh["stars"]:
        tw = 0.5 + 0.5 * np.sin(t * (2.0 + 3.0 * phase) + phase * 40)
        rgb += (star * (tw - 0.35) * 0.55 * sh["stars"])[..., None] * np.array([0.95, 0.97, 1.0], np.float32)
    # lua / sol respirando
    breath = 0.5 + 0.5 * math.sin(t * 1.1 + i)
    rgb += (glow * (0.06 + 0.07 * breath) * sh["glow"])[..., None] * np.array([1.0, 0.92, 0.75], np.float32)
    # reflexo metálico varrendo a armadura
    if sh["glint"]:
        pos = -0.4 + 1.8 * ((t - a) / (b - a))
        d = (GX / W * 0.8 + GY / H * 0.6) - pos
        bandv = np.exp(-(d / 0.07) ** 2) + 0.25 * np.exp(-(d / 0.22) ** 2)
        shimmer = 0.85 + 0.15 * math.sin(t * 2.3)
        rgb += (metal ** 1.5 * bandv * 0.30 * sh["glint"] * shimmer)[..., None] * np.array([1.0, 0.93, 0.80], np.float32)
    # nuvens/névoa deslizando no céu
    if sh["clouds"]:
        ct = cloud_tex()
        off = int((t * 38) % W)
        c = ct[:, off:off + W]
        light = 0.55 + 0.45 * math.sin(t * 0.6)
        tint = np.array([0.62, 0.66, 0.70], np.float32)
        m = (c * sky * sh["clouds"] * 0.35)[..., None]
        rgb = rgb * (1 - m) + (tint * (0.7 + 0.3 * light)) * m
    # névoa baixa geral (atmosfera)
    fog = (cloud_tex()[:, int((t * 15 + 500) % W):int((t * 15 + 500) % W) + W]
           * np.clip((GY / H - 0.55) / 0.45, 0, 1) * 0.06)[..., None]
    rgb = rgb * (1 - fog) + np.array([0.7, 0.72, 0.75], np.float32) * fog
    # partículas
    draw_particles(rgb, particles(i, t - a, t))
    rgb *= np.array(sh["grade"], np.float32)
    return rgb

# ---------------------------------------------------------------------------
VIG = None
def finish(rgb, t, rng):
    global VIG
    if VIG is None:
        d = np.sqrt(((GX - W / 2) / (W * 0.62)) ** 2 + ((GY - H / 2) / (H * 0.60)) ** 2)
        VIG = (1 - 0.55 * smooth((d - 0.45) / 0.75))[..., None]
    # bloom
    hi = np.clip((rgb - 0.62) / 0.38, 0, 1)
    rgb = rgb + blur_rgb(hi, 30, down=4) * 0.32 + blur_rgb(hi, 8, down=2) * 0.12
    # grade: preto profundo, sombras verde-musgo/azul, altas douradas
    lum = rgb.mean(2, keepdims=True)
    rgb = lum + (rgb - lum) * 0.88
    sh_t = np.array([-0.012, 0.004, 0.010], np.float32)
    hi_t = np.array([0.030, 0.012, -0.022], np.float32)
    rgb = rgb + sh_t * (1 - smooth(lum / 0.5)) + hi_t * smooth((lum - 0.45) / 0.5)
    rgb = np.clip(rgb, 0, None)
    rgb = rgb / (1 + 0.18 * rgb)          # roll-off suave
    rgb = smooth(np.clip(rgb * 1.10 - 0.025, 0, 1)) * 0.35 + np.clip(rgb * 1.10 - 0.025, 0, 1) * 0.65
    rgb *= VIG
    # granulação de filme
    g = rng.standard_normal((H // 2, W // 2)).astype(np.float32)
    g = np.asarray(Image.fromarray(g, "F").resize((W, H), Image.BILINEAR))
    rgb += g[..., None] * 0.022 * (0.6 + 0.4 * (1 - lum))
    # fade de entrada e saída
    fade = smooth(t / 1.0) * smooth((DUR - t) / 1.6)
    return np.clip(rgb * fade, 0, 1)

def leak(t, center, dur, warm=(1.0, 0.62, 0.30)):
    p = 1 - abs(t - center) / (dur / 2)
    p = max(p, 0) ** 1.5
    cx = W * (0.15 + 0.7 * ((t - center) / dur + 0.5))
    d = np.sqrt(((GX - cx) / (W * 0.8)) ** 2 + ((GY - H * 0.3) / (H * 0.7)) ** 2)
    return (np.exp(-d * d * 2.2) * p * 0.42)[..., None] * np.array(warm, np.float32)

def frame(fi):
    t = fi / FPS
    rng = np.random.default_rng(10_000 + fi)
    # plano atual
    cur = max(k for k in range(len(CUTS)) if CUTS[k] <= t)
    # está em transição com o próximo ou com o anterior?
    out = None
    for j in (cur, cur + 1):
        if j < len(TRANS) and TRANS[j] and j > 0:
            kind, d = TRANS[j]
            c = CUTS[j]
            if c - d / 2 <= t < c + d / 2:
                p = (t - (c - d / 2)) / d
                out = transition(kind, j, t, p, d)
                break
    if out is None:
        out = render_shot(cur, t)
    # relâmpagos extras no plano da tempestade
    if CUTS[4] <= t < CUTS[5]:
        for lt in (CUTS[4] + 0.02, CUTS[4] + 0.20, 13.55, 13.66):
            if 0 <= t - lt < 0.25:
                out = out + (math.exp(-(t - lt) / 0.06) * 0.28) * np.array([0.85, 0.9, 1.0], np.float32)
    return (finish(out, t, rng) * 255 + 0.5).astype(np.uint8)

def transition(kind, j, t, p, d):
    A = lambda **kw: render_shot(j - 1, t, **kw)
    B = lambda **kw: render_shot(j, t, **kw)
    if kind == "leak":
        m = smooth(p)
        img = A() * (1 - m) + B() * m
        return img + leak(t, CUTS[j], d)
    if kind == "whip":   # chicote lateral com motion blur
        s = math.sin(math.pi * p)
        bd = 45 * s
        if p < 0.5:
            return A(extra_zoom=1 + 0.06 * s, blur_dir=bd)
        return B(extra_zoom=1 + 0.06 * s, blur_dir=-bd)
    if kind == "flash":  # explosão de luz no corte
        if p < 0.5:
            img = A(extra_zoom=1 + 0.04 * p); f = smooth(p * 2) ** 2
        else:
            img = B(extra_zoom=1 + 0.03 * (1 - p)); f = smooth((1 - p) * 2) ** 2
        return img * (1 - 0.25 * f) + f * 0.55 * np.array([1.0, 0.95, 0.88], np.float32)
    if kind == "lightning":  # mergulho ao preto e revelação pela tempestade
        if p < 0.5:
            return A() * (1 - smooth(p * 2))
        return B() * smooth((p - 0.5) * 2.2)
    if kind == "dissolve":  # dissolução pelas sombras (o escuro chega primeiro)
        a, b = A(), B()
        lum = b.mean(2, keepdims=True)
        m = np.clip((p * 1.6 - (1 - lum) * 0.6), 0, 1)
        m = smooth(m)
        return a * (1 - m) + b * m
    raise ValueError(kind)

# ---------------------------------------------------------------------------
def render_chunk(args):
    idx, frames, path = args
    with open(path, "wb") as f:
        for fi in frames:
            f.write(frame(fi).tobytes())
    return path

def main():
    audio = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else os.path.join(HERE, "edit-medieval.mp4")
    if "--stills" in sys.argv:
        for t in [float(x) for x in sys.argv[sys.argv.index("--stills") + 1].split(",")]:
            Image.fromarray(frame(int(t * FPS))).save(os.path.join(os.path.dirname(out), f"still_{t:05.2f}.jpg"), quality=90)
        return
    n = int(DUR * FPS)
    tmp = os.path.dirname(os.path.abspath(out))
    procs = os.cpu_count() or 4
    chunks, step = [], math.ceil(n / procs)
    for k in range(procs):
        fr = list(range(k * step, min(n, (k + 1) * step)))
        if fr:
            chunks.append((k, fr, os.path.join(tmp, f"_chunk{k}.raw")))
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

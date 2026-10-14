#!/usr/bin/env python3
"""Edit cristã "Golden Brown" (~40 s) com as imagens de Jesus do usuário.

Pipeline: cada imagem (upscale 4x Real-ESRGAN em imagens_hd/) é separada em figura (máscara) +
fundo (inpaint) para parallax 2.5D e animada por uma câmera virtual. Os cortes seguem o início
de cada frase da letra e, no trecho instrumental, as batidas do baixo.
Efeitos: texto "GOD" dourado 3D entre nuvens (intro), nuvens em movimento, raios de luz,
partículas, light leaks, dissolves com brilho, zoom/whip blur, flashes, bloom e grão.
Legendas palavra por palavra em ouro marrom (fonte Cinzel), no tempo do vídeo de referência.

Uso:  python3 render.py            -> saida/edit_jesus.mp4
      python3 render.py --preview  -> saida/preview.jpg (1 frame a cada 0,5 s)
      python3 render.py --frames 10,200
"""
import math
import os
import subprocess
import sys
from multiprocessing import Pool

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1440, 1080, 30
DUR = 40.4
NFRAMES = int(round(DUR * FPS))
AUDIO = os.path.join(ROOT, "audio", "golden_brown.m4a")
OUT = os.path.join(ROOT, "saida", "edit_jesus.mp4")
FONT = os.path.join(ROOT, "fontes", "cinzel-latin-700-normal.woff")

cv2.setNumThreads(1)


def ease_out(x, p=3):
    x = min(max(x, 0.0), 1.0)
    return 1 - (1 - x) ** p


def ease_io(x):
    x = min(max(x, 0.0), 1.0)
    return 0.5 - 0.5 * math.cos(math.pi * x)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def fbm(h, w, seed, base=6, octaves=6, persistence=0.55):
    rng = np.random.default_rng(seed)
    acc = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        gh, gw = base * 2 ** o, int(base * 2 ** o * w / h) + 1
        g = rng.random((gh, gw)).astype(np.float32)
        acc += amp * cv2.resize(g, (w, h), interpolation=cv2.INTER_CUBIC)
        tot += amp
        amp *= persistence
    acc /= tot
    return (acc - acc.min()) / (acc.max() - acc.min())


def make_god_text(width_px):
    """Letras 'GOD' douradas 3D (extrusão + bisel + especular). Retorna RGBA float."""
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 400)
    tw = font.getbbox("GOD")
    size = int(400 * width_px / (tw[2] - tw[0]))
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)
    bb = font.getbbox("GOD")
    pad = int(size * 0.25)
    cw, ch = bb[2] - bb[0] + 2 * pad, bb[3] - bb[1] + 2 * pad
    pil = Image.new("L", (cw, ch), 0)
    ImageDraw.Draw(pil).text((pad - bb[0], pad - bb[1]), "GOD", font=font, fill=255)
    face = cv2.GaussianBlur(np.asarray(pil, np.float32) / 255, (0, 0), 1.0)

    depth = int(size * 0.075)
    rgb = np.zeros((ch, cw, 3), np.float32)
    alpha = np.zeros((ch, cw), np.float32)
    # extrusão: camadas escuras deslocadas para baixo/direita
    for k in range(depth, 0, -1):
        dx, dy = k * 0.35, k * 0.9
        M = np.float32([[1, 0, dx], [0, 1, dy]])
        lay = cv2.warpAffine(face, M, (cw, ch))
        shade = 0.55 - 0.3 * k / depth
        col = np.array([0.78, 0.52, 0.14], np.float32) * shade
        a = lay[..., None]
        rgb = rgb * (1 - a) + col * a
        alpha = np.maximum(alpha, lay)

    # bisel: altura a partir da distância à borda
    dist = cv2.distanceTransform((face > 0.5).astype(np.uint8), cv2.DIST_L2, 5)
    bev = size * 0.045
    hgt = cv2.GaussianBlur(np.clip(dist / bev, 0, 1), (0, 0), 1.5)
    gx = cv2.Sobel(hgt, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(hgt, cv2.CV_32F, 0, 1, ksize=3)
    n = np.dstack([-gx * 2.2, -gy * 2.2, np.ones_like(gx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    L = np.array([-0.45, -0.65, 0.62], np.float32)
    L /= np.linalg.norm(L)
    diff = np.clip((n * L).sum(2), 0, 1)
    Hh = L + np.array([0, 0, 1], np.float32)
    Hh /= np.linalg.norm(Hh)
    spec = np.clip((n * Hh).sum(2), 0, 1) ** 40
    yy = np.linspace(0, 1, ch, dtype=np.float32)[:, None]
    # gradiente dourado vertical com faixa de reflexo
    g1 = np.array([1.00, 0.86, 0.46], np.float32)
    g2 = np.array([0.80, 0.53, 0.13], np.float32)
    g3 = np.array([0.98, 0.78, 0.36], np.float32)
    t = ((yy - pad / ch) / (1 - 2 * pad / ch))[..., None]
    base = np.where(t < 0.55, g1 + (g2 - g1) * np.clip(t / 0.55, 0, 1),
                    g2 + (g3 - g2) * np.clip((t - 0.55) / 0.45, 0, 1))
    base = np.broadcast_to(base, (ch, cw, 3))
    flat = (hgt >= 0.98)[..., None]
    lit = base * (0.45 + 0.75 * diff[..., None]) + 0.55 * spec[..., None]
    lit = np.where(flat, base * 0.98 + 0.08, lit)
    edge = smoothstep(0.0, 0.12, hgt)[..., None]
    lit = lit * (0.55 + 0.45 * edge)
    a = face[..., None]
    rgb = rgb * (1 - a) + np.clip(lit, 0, 1) * a
    alpha = np.maximum(alpha, face)
    # sombra suave atrás
    sh = cv2.GaussianBlur(alpha, (0, 0), size * 0.04) * 0.45
    out_a = np.clip(alpha + sh * (1 - alpha), 0, 1)
    out_rgb = rgb * alpha[..., None] / np.maximum(out_a[..., None], 1e-4)
    out_rgb = np.where(alpha[..., None] > 1e-3, out_rgb, 0.08)
    return np.dstack([out_rgb, out_a]).astype(np.float32)


def make_cloud_texture(w, h, seed, top, soft, tint):
    """Banco de nuvens (RGBA) mais denso embaixo. top/soft em fração da altura."""
    n = fbm(h, w, seed, base=3, octaves=7)
    n2 = fbm(h, w, seed + 7, base=5, octaves=5)
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    bias = (y - top) / soft
    d = smoothstep(0.30, 0.80, n * 0.7 + n2 * 0.3 + bias * 0.55 - 0.25)
    d = cv2.GaussianBlur(d, (0, 0), 2.5)
    # topo das nuvens iluminado, miolo levemente sombreado
    db = cv2.GaussianBlur(d, (0, 0), 14)
    light = np.clip(1.02 - 0.12 * db + 0.08 * (n2 - 0.5), 0.86, 1.05)
    rgb = np.array(tint, np.float32) * light[..., None]
    return np.dstack([np.clip(rgb, 0, 1), d]).astype(np.float32)




# ---------------------------------------------------------------- assets
def load_image(i):
    """Carrega a imagem HD (Real-ESRGAN) + máscara + fundo inpaint, em dois níveis de resolução."""
    hd_path = os.path.join(ROOT, "imagens_hd", f"{i}.png")
    orig = cv2.imread(os.path.join(ROOT, "imagens", f"{i}.jpg"))
    if os.path.exists(hd_path):
        img = cv2.imread(hd_path)
    else:  # fallback sem a IA: Lanczos 4x
        img = cv2.resize(orig, None, fx=4, fy=4, interpolation=cv2.INTER_LANCZOS4)
    img = img[:, :, ::-1].copy()
    h, w = img.shape[:2]
    m = cv2.imread(os.path.join(ROOT, "mascaras", f"{i}.png"), cv2.IMREAD_GRAYSCALE)
    mk = cv2.resize(m, (w, h), interpolation=cv2.INTER_CUBIC).astype(np.float32) / 255
    mk = np.clip((mk - 0.08) / 0.8, 0, 1)
    # fundo sem a figura: inpaint na resolução original, revelado só nas bordas do parallax
    dil = cv2.dilate((m > 20).astype(np.uint8) * 255, np.ones((15, 15), np.uint8))
    inp = cv2.inpaint(orig, dil, 12, cv2.INPAINT_TELEA)[:, :, ::-1]
    inp = cv2.GaussianBlur(inp, (0, 0), 3)
    inp = cv2.resize(inp, (w, h), interpolation=cv2.INTER_CUBIC).astype(np.float32)
    dm = cv2.GaussianBlur(cv2.resize(dil, (w, h)).astype(np.float32) / 255, (0, 0), 20)[..., None]
    bg = img.astype(np.float32) * (1 - dm) + inp * dm
    ys, xs = np.nonzero(mk > 0.5)
    d = dict(w=w, h=h, bbox=(xs.min(), ys.min(), xs.max(), ys.max()))
    # nível 0 (HD) e nível 1 (metade) para reduzir sem serrilhado nos planos abertos
    d["lv"] = []
    for lvl in range(2):
        f = 0.5 ** lvl
        rs = (lambda a: a) if lvl == 0 else (lambda a: cv2.resize(a, (w // 2, h // 2), interpolation=cv2.INTER_AREA))
        d["lv"].append(dict(img=rs(img), bg=rs(np.clip(bg, 0, 255).astype(np.uint8)),
                            mask=rs((mk * 255).astype(np.uint8)), f=f))
    return d


print("carregando imagens…", flush=True)
IMGS = {i: load_image(i) for i in range(1, 14)}

# texto GOD no espaço da imagem 4 (fica atrás de Jesus e na frente do céu)
_i4 = IMGS[4]
GOD = make_god_text(int(_i4["w"] * 0.84))
_gh, _gw = GOD.shape[:2]
_gx, _gy = int(_i4["w"] * 0.5 - _gw / 2), int(_i4["h"] * 0.215 - _gh / 2)
_bg4 = _i4["lv"][0]["bg"].astype(np.float32) / 255
_sx0, _sy0 = max(0, -_gx), max(0, -_gy)
_dx0, _dy0 = max(0, _gx), max(0, _gy)
_dx1, _dy1 = min(_i4["w"], _gx + _gw), min(_i4["h"], _gy + _gh)
_g = GOD[_sy0:_sy0 + _dy1 - _dy0, _sx0:_sx0 + _dx1 - _dx0]
_reg = _bg4[_dy0:_dy1, _dx0:_dx1]
_bg4[_dy0:_dy1, _dx0:_dx1] = _reg * (1 - _g[..., 3:4]) + _g[..., :3] * _g[..., 3:4]
_ib = (np.clip(_bg4, 0, 1) * 255 + 0.5).astype(np.uint8)
INTRO_BG = [_ib, cv2.resize(_ib, (_i4["w"] // 2, _i4["h"] // 2), interpolation=cv2.INTER_AREA)]
del _bg4, _reg, _g

CLOUDS = {
    "intro": [make_cloud_texture(W * 2, H, 11, 0.70, 0.22, (1.0, 0.96, 0.9)),
              make_cloud_texture(W * 2, H, 23, 0.80, 0.18, (0.97, 0.92, 0.86))],
    "warm": [make_cloud_texture(W * 2, H, 31, 0.86, 0.16, (1.0, 0.93, 0.80)),
             make_cloud_texture(W * 2, H, 37, 0.93, 0.12, (0.98, 0.9, 0.78))],
    "cool": [make_cloud_texture(W * 2, H, 41, 0.88, 0.15, (0.97, 0.96, 0.95)),
             make_cloud_texture(W * 2, H, 47, 0.95, 0.10, (0.94, 0.94, 0.95))],
}
_rng = np.random.default_rng(5)
RAY_NOISE = cv2.GaussianBlur(_rng.random((1, 720)).astype(np.float32), (0, 0), 2.2)[0]
RAY_NOISE = (RAY_NOISE - RAY_NOISE.min()) / (RAY_NOISE.max() - RAY_NOISE.min())
_YY, _XX = np.mgrid[0:H // 2, 0:W // 2].astype(np.float32)
_yy, _xx = np.mgrid[0:H, 0:W].astype(np.float32)
_r = np.sqrt(((_xx - W / 2) / (W / 2)) ** 2 + ((_yy - H / 2) / (H / 2)) ** 2) / math.sqrt(2)
VIGNETTE = (1 - 0.30 * smoothstep(0.45, 1.0, _r))[..., None]
BOTTOM_SHADE = smoothstep(0.55, 1.0, _yy / H)[..., None]  # escurece a base para as legendas
del _yy, _xx, _r


# ---------------------------------------------------------------- roteiro
# crop: (cx, cy, w) normalizados na imagem; w = fração da largura enquadrada (4:3)
# cut:  transição de ENTRADA: intro | zoom | dissolve | flash | punch | slide | spin
# lat:  deslocamento lateral da figura em relação ao fundo (parallax de travelling)
S = lambda **k: k  # noqa: E731
# grade da música: pulso de 0,321 s (compasso de 3 = 0,963 s), fase 0,15 s. Todos os cortes caem em
# pulsos da grade; nos versos, no pulso mais próximo do início de cada frase.
PULSE, PHASE = 0.321, 0.15


def G(k):
    """Tempo do k-ésimo pulso da música."""
    return round(PHASE + PULSE * k, 3)


SHOTS = [
    # --- versos
    S(img=4, t0=0.00, t1=G(12), a=(0.50, 0.40, 1.00), b=(0.52, 0.32, 0.62), cut="intro",
      clouds="intro", rays=(0.53, 0.20, 0.30), particles=45, par=0.06),
    S(img=11, t0=G(12), t1=G(20), a=(0.50, 0.50, 0.95), b=(0.44, 0.52, 0.78), cut="zoom",
      rays=(0.85, 0.30, 0.22), particles=45, par=0.07, lat=0.012),
    S(img=2, t0=G(20), t1=G(29), a=(0.52, 0.44, 1.00), b=(0.44, 0.38, 0.80), cut="dissolve",
      particles=35, par=0.07, lat=-0.012, pcol=(0.85, 0.95, 1.0)),
    S(img=12, t0=G(29), t1=G(35), a=(0.50, 0.27, 1.00), b=(0.58, 0.25, 0.84), cut="flash",
      rays=(0.66, 0.10, 0.22), particles=40, par=0.07, lat=0.010),
    S(img=8, t0=G(35), t1=G(41), a=(0.50, 0.36, 1.00), b=(0.50, 0.30, 0.84), cut="dissolve",
      rays=(0.48, 0.10, 0.22), particles=40, par=0.07, lat=-0.010),
    S(img=7, t0=G(41), t1=G(48), a=(0.50, 0.40, 0.86), b=(0.50, 0.30, 0.58), cut="zoom",
      rays=(0.50, 0.24, 0.32), particles=50, par=0.05),
    # --- instrumental
    S(img=10, t0=G(48), t1=G(52), a=(0.50, 0.50, 0.95), b=(0.47, 0.45, 0.80), cut="flash",
      particles=40, par=0.06, lat=0.010),
    S(img=10, t0=G(52), t1=G(57), a=(0.49, 0.36, 0.50), b=(0.49, 0.33, 0.42), cut="punch",
      particles=30, par=0.04),
    S(img=13, t0=G(57), t1=G(63), a=(0.50, 0.45, 1.00), b=(0.50, 0.40, 0.84), cut="dissolve",
      rays=(0.72, 0.0, 0.30), particles=55, par=0.06, lat=-0.010),
    S(img=1, t0=G(63), t1=G(69), a=(0.53, 0.38, 1.00), b=(0.55, 0.33, 0.80), cut="zoom",
      particles=45, par=0.07, lat=0.012),
    S(img=6, t0=G(69), t1=G(72), a=(0.50, 0.43, 1.00), b=(0.52, 0.40, 0.90), cut="slide", wdir=1,
      particles=30, par=0.06, lat=-0.012),
    S(img=6, t0=G(72), t1=G(74), a=(0.45, 0.41, 0.62), b=(0.45, 0.40, 0.58), cut="punch", par=0.03),
    S(img=3, t0=G(74), t1=G(80), a=(0.50, 0.42, 1.00), b=(0.50, 0.36, 0.82), cut="zoom",
      rays=(0.52, 0.12, 0.24), particles=40, par=0.07, lat=0.010),
    S(img=5, t0=G(80), t1=G(83), a=(0.50, 0.38, 1.00), b=(0.53, 0.36, 0.88), cut="flash",
      rays=(0.75, 0.0, 0.24), particles=40, par=0.06),
    S(img=5, t0=G(83), t1=G(85), a=(0.45, 0.40, 0.58), b=(0.45, 0.39, 0.54), cut="punch", par=0.03),
    S(img=13, t0=G(85), t1=G(91), a=(0.53, 0.38, 0.62), b=(0.55, 0.35, 0.52), cut="spin",
      rays=(0.72, 0.0, 0.30), particles=45, par=0.04),
    S(img=12, t0=G(91), t1=G(98), a=(0.60, 0.26, 0.62), b=(0.63, 0.23, 0.52), cut="zoom",
      rays=(0.66, 0.10, 0.22), particles=35, par=0.04),
    S(img=11, t0=G(98), t1=G(101), a=(0.45, 0.55, 0.55), b=(0.43, 0.52, 0.46), cut="slide", wdir=-1,
      rays=(0.85, 0.30, 0.22), particles=40, par=0.04),
    S(img=2, t0=G(101), t1=G(105), a=(0.44, 0.34, 0.68), b=(0.41, 0.31, 0.57), cut="flash",
      particles=35, par=0.04, lat=-0.008, pcol=(0.85, 0.95, 1.0)),
    S(img=8, t0=G(105), t1=G(111), a=(0.50, 0.25, 0.66), b=(0.50, 0.23, 0.55), cut="dissolve",
      rays=(0.48, 0.10, 0.22), particles=40, par=0.04, lat=-0.008),
    # --- volta da letra
    S(img=4, t0=G(111), t1=G(116), a=(0.50, 0.46, 1.00), b=(0.51, 0.40, 0.84), cut="flash",
      clouds="warm", rays=(0.53, 0.25, 0.36), particles=60, par=0.07),
    S(img=7, t0=G(116), t1=G(120), a=(0.50, 0.30, 0.62), b=(0.50, 0.29, 0.54), cut="zoom",
      rays=(0.50, 0.24, 0.32), particles=40, par=0.03),
    S(img=9, t0=G(120), t1=40.40, a=(0.50, 0.37, 0.76), b=(0.50, 0.41, 1.00), cut="dissolve",
      clouds="cool", rays=(0.50, 0.36, 0.45), particles=70, par=0.04, fade=1.4),
]
# pulsos com acento forte do baixo (fora dos cortes): pulso de zoom + leve brilho no tempo da música
BEATS = [G(k) for k in (1, 2, 8, 10, 13, 14, 15, 19, 21, 25, 26, 30, 31, 32, 33, 37, 38, 39, 40, 43, 46, 49,
                        50, 71, 73, 78, 81, 82, 88, 99, 102, 108, 113, 115, 119, 123)]
for k, s in enumerate(SHOTS):
    s["f0"], s["f1"] = int(round(s["t0"] * FPS)), int(round(s["t1"] * FPS))
    s["next"] = SHOTS[k + 1]["cut"] if k + 1 < len(SHOTS) else None
    s["next_dir"] = SHOTS[k + 1].get("wdir", 1) if k + 1 < len(SHOTS) else 1
    s["seed"] = 100 + k
    s["idx"] = k
# letra (tempo de entrada de cada palavra, tirado do vídeo de referência)
# cada linha tem fileiras "hero" (itálico serifado em ouro metálico) e "small" (caixa-alta espaçada, marfim)
LYRICS = [
    dict(end=3.70, fin="wipe", fout="blur", rows=[("hero", [("golden", 0.77), ("brown", 0.93)]),
                         ("small", [("texture", 1.60), ("like", 2.43), ("sun", 2.77)])]),
    dict(end=6.42, fin="slot", fout="slot", rows=[("small", [("lays", 3.93), ("me", 4.60), ("down", 4.77)]),
                         ("hero", [("with", 5.60), ("my", 6.10), ("mind", 6.27)])]),
    dict(end=9.25, fin="cascade", fout="wipe", rows=[("small", [("she", 6.60), ("runs", 6.93), ("throughout", 7.60)]),
                         ("hero", [("the", 8.35), ("night", 8.43)])]),
    dict(end=11.25, fin="track", fout="punch", rows=[("small", [("no", 9.43), ("need", 9.93)]),
                          ("hero", [("to", 10.27), ("fight", 10.43)])]),
    dict(end=15.40, fin="glow", fout="drift", rows=[("small", [("never", 11.43), ("a", 11.93), ("frown", 12.27)]),
                          ("hero", [("with", 13.27), ("golden", 13.77), ("brown", 14.43)])]),
    dict(end=40.30, fin="cascade", fout="blur", rows=[("hero", [("golden", 35.97), ("brown", 36.97)]),
                          ("small", [("finer", 37.47), ("temptress", 38.63), ("through", 39.80)])]),
]


# ---------------------------------------------------------------- legendas (estilo editorial)
HERO_FONT = os.path.join(ROOT, "fontes", "cormorant-garamond-latin-600-italic.woff")
SMALL_FONT = os.path.join(ROOT, "fontes", "cinzel-latin-600-normal.woff")
HERO_SZ, SMALL_SZ = 112, 40
SMALL_TRACK = 0.30  # espaçamento entre letras (em) da fileira pequena
OUT_T = 0.28  # duração da saída da linha (s)
_SPR = {}


def _gold(t):
    """Rampa de ouro metálico ao longo da altura da letra (0 = topo, 1 = base)."""
    stops = [(0.00, (1.00, 0.95, 0.76)), (0.30, (0.97, 0.80, 0.45)), (0.52, (0.74, 0.48, 0.18)),
             (0.60, (0.62, 0.38, 0.13)), (0.70, (0.92, 0.74, 0.42)), (1.00, (0.80, 0.56, 0.26))]
    out = np.zeros(t.shape + (3,), np.float32)
    for (a, ca), (b, cb) in zip(stops[:-1], stops[1:]):
        k = np.clip((t - a) / (b - a), 0, 1)[..., None]
        sel = ((t >= a) & (t <= b))[..., None]
        out = np.where(sel, np.array(ca, np.float32) * (1 - k) + np.array(cb, np.float32) * k, out)
    return out


def text_mask(text, font_path, size, track=0.0, ss=3):
    """Máscara da palavra (supersample), com tracking opcional. Retorna máscara, avanço, baseline."""
    font = ImageFont.truetype(font_path, size * ss)
    asc, desc = font.getmetrics()
    pad = int(size * ss * 0.45)
    if track:
        adv = sum(font.getlength(c) for c in text) + track * size * ss * (len(text) - 1)
    else:
        adv = font.getlength(text)
    cw, ch = int(adv + 2 * pad), int(asc + desc + 2 * pad)
    pil = Image.new("L", (cw, ch), 0)
    dr = ImageDraw.Draw(pil)
    if track:
        x = pad
        for c in text:
            dr.text((x, pad), c, font=font, fill=255)
            x += font.getlength(c) + track * size * ss
    else:
        dr.text((pad, pad), text, font=font, fill=255)
    m = np.asarray(pil, np.float32) / 255
    m = cv2.resize(m, (cw // ss, ch // ss), interpolation=cv2.INTER_AREA)
    return m, adv / ss, (pad + asc) / ss, pad / ss


def word_sprite(word, kind):
    key = (word, kind)
    if key in _SPR:
        return _SPR[key]
    if kind == "hero":
        m, adv, base, top = text_mask(word, HERO_FONT, HERO_SZ)
        h, w = m.shape
        yy = np.linspace(0, 1, h, dtype=np.float32)[:, None]
        cap_top, cap_bot = top + HERO_SZ * 0.18, base + HERO_SZ * 0.05
        t = np.clip((yy * h - cap_top) / (cap_bot - cap_top), 0, 1)
        face = np.broadcast_to(_gold(t), (h, w, 3)).copy()
        # bisel sutil: realce em cima, sombra embaixo das hastes
        hb = cv2.GaussianBlur(m, (0, 0), 1.4)
        gy = cv2.Sobel(hb, cv2.CV_32F, 0, 1, ksize=3)
        face = np.clip(face + 0.22 * np.clip(gy, 0, 1)[..., None] - 0.18 * np.clip(-gy, 0, 1)[..., None], 0, 1)
        glow_col, glow_r, glow_k = (1.0, 0.78, 0.42), 16, 0.30
    else:
        m, adv, base, top = text_mask(word.upper(), SMALL_FONT, SMALL_SZ, SMALL_TRACK)
        h, w = m.shape
        yy = np.linspace(0, 1, h, dtype=np.float32)[:, None]
        t = np.clip((yy * h - top) / (base - top), 0, 1)[..., None]
        face = np.array([0.99, 0.95, 0.87], np.float32) * (1 - t) + np.array([0.90, 0.82, 0.68], np.float32) * t
        face = np.broadcast_to(face, (h, w, 3)).copy()
        glow_col, glow_r, glow_k = (1.0, 0.85, 0.6), 10, 0.12
    # sombra projetada macia (legibilidade sem contorno grosseiro)
    sh = cv2.GaussianBlur(m, (0, 0), HERO_SZ * 0.09 if kind == "hero" else 5)
    sh = np.roll(sh, 3, 0) * (0.62 if kind == "hero" else 0.70)
    glow = cv2.GaussianBlur(m, (0, 0), glow_r) * glow_k
    # composição pré-multiplicada: sombra escura + brilho quente + face
    a_sh = sh * (1 - m)
    rgbp = np.zeros((h, w, 3), np.float32)
    rgbp += np.array([0.06, 0.035, 0.015], np.float32) * a_sh[..., None]
    rgbp = rgbp * (1 - glow[..., None]) + np.array(glow_col, np.float32) * glow[..., None]
    alpha = np.clip(a_sh + glow - a_sh * glow, 0, 1)
    rgbp = rgbp * (1 - m[..., None]) + face * m[..., None]
    alpha = alpha * (1 - m) + m
    xs = np.linspace(0, 1, w, dtype=np.float32)[None, :].repeat(h, 0)
    bloom = np.clip(cv2.GaussianBlur(m, (0, 0), 14 if kind == "hero" else 8) * 1.6, 0, 1)
    spr = dict(rgbp=rgbp.astype(np.float32), a=alpha.astype(np.float32), m=m, xs=xs, w=w, h=h, adv=adv,
               base=base, kind=kind, bloom=bloom)
    _SPR[key] = spr
    return spr


def char_offsets(word, kind):
    """Deslocamento x (px de saída) de cada letra dentro da palavra."""
    ss = 3
    if kind == "hero":
        font = ImageFont.truetype(HERO_FONT, HERO_SZ * ss)
        return [font.getlength(word[:i]) / ss for i in range(len(word))]
    font = ImageFont.truetype(SMALL_FONT, SMALL_SZ * ss)
    w = word.upper()
    offs, x = [], 0.0
    for c in w:
        offs.append(x / ss)
        x += font.getlength(c) + SMALL_TRACK * SMALL_SZ * ss
    return offs


def layout_line(line):
    """Fileiras centralizadas; o bloco fica no terço inferior."""
    gap = {"hero": HERO_SZ * 0.26, "small": SMALL_SZ * 0.95}
    row_h = {"hero": HERO_SZ * 0.98, "small": SMALL_SZ * 2.0}
    rows = line["rows"]
    total_h = sum(row_h[k] for k, _ in rows)
    y = H * 0.835 - total_h / 2
    out = []
    for r, (kind, words) in enumerate(rows):
        sprs = [word_sprite(w, kind) for w, _ in words]
        tot = sum(s["adv"] for s in sprs) + gap[kind] * (len(words) - 1)
        x = W / 2 - tot / 2
        base_y = y + row_h[kind] * (0.80 if kind == "hero" else 0.72)
        for (w, tw), s in zip(words, sprs):
            text = w if kind == "hero" else w.upper()
            chars = [(word_sprite(c, kind), o) for c, o in zip(text, char_offsets(w, kind)) if c.strip()]
            out.append(dict(word=w, t=tw, x=x, base_y=base_y, spr=s, row=r, kind=kind,
                            step=s["adv"] + gap[kind], chars=chars,
                            size=HERO_SZ if kind == "hero" else SMALL_SZ))
            x += s["adv"] + gap[kind]
        y += row_h[kind]
    xs = [wd["x"] for wd in out] + [wd["x"] + wd["spr"]["adv"] for wd in out]
    return out, H * 0.835, (min(xs), max(xs))


LAYOUT = [(ln,) + layout_line(ln) for ln in LYRICS]
_EY, _EX = np.mgrid[0:H // 4, 0:W // 4].astype(np.float32)


def comp(frame, rgbp, a, x0, y0, clip=None):
    """Composição pré-multiplicada; clip=(y_min, y_max) recorta em coordenadas de tela."""
    h, w = a.shape
    x0, y0 = int(round(x0)), int(round(y0))
    sx0, sy0 = max(0, -x0), max(0, -y0)
    dx0, dy0, dx1, dy1 = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
    if clip:
        dy0, dy1 = max(dy0, int(clip[0])), min(dy1, int(clip[1]))
        sy0 = dy0 - y0
    if dx1 <= dx0 or dy1 <= dy0:
        return
    s = (slice(sy0, sy0 + dy1 - dy0), slice(sx0, sx0 + dx1 - dx0))
    frame[dy0:dy1, dx0:dx1] = frame[dy0:dy1, dx0:dx1] * (1 - a[s][..., None]) + rgbp[s]


def draw_sprite(frame, spr, x, base_y, fade, dy=0.0, blur=0.0, scale=1.0, wipe=None, xmask=None,
                clip=None, shimmer=None, bloom=0.0):
    """Desenha um sprite (palavra ou letra) com as transformações da animação."""
    rgbp, a = spr["rgbp"], spr["a"]
    if wipe is not None:
        rgbp, a = rgbp * wipe[..., None], a * wipe
    if shimmer is not None:
        yy = np.linspace(0, 1, spr["h"], dtype=np.float32)[:, None]
        band = np.exp(-(((spr["xs"] + 0.25 * yy) - shimmer) / 0.07) ** 2) * spr["m"]
        if wipe is not None:
            band = band * wipe
        rgbp = rgbp + band[..., None] * np.array([0.55, 0.45, 0.28], np.float32)
    if bloom > 0.01:
        b = spr["bloom"] * bloom
        rgbp = rgbp * (1 - b[..., None]) + b[..., None] * np.array([1.0, 0.82, 0.5], np.float32)
        a = a + b - a * b
    if xmask is not None:
        rgbp, a = rgbp * xmask[None, :, None], a * xmask[None, :]
    x0 = x - (spr["w"] - spr["adv"]) / 2
    y0 = base_y - spr["base"] + dy
    if scale != 1.0:
        cxs, cys = x0 + spr["w"] / 2, y0 + spr["base"] * 0.8
        nw, nh = max(1, int(spr["w"] * scale)), max(1, int(spr["h"] * scale))
        rgbp = cv2.resize(rgbp, (nw, nh), interpolation=cv2.INTER_LINEAR)
        a = cv2.resize(a, (nw, nh), interpolation=cv2.INTER_LINEAR)
        x0, y0 = cxs - nw / 2, cys - spr["base"] * 0.8 * scale
    if blur > 0.4:
        k = int(blur * 3) | 1
        rgbp, a = cv2.GaussianBlur(rgbp, (k, k), blur), cv2.GaussianBlur(a, (k, k), blur)
    comp(frame, np.clip(rgbp, 0, None) * fade, np.clip(a, 0, 1) * fade, x0, y0, clip)


def draw_lyrics(frame, t):
    for line, words, cy, (lx0, lx1) in LAYOUT:
        start = words[0]["t"]
        if not (start - 0.05 <= t < line["end"] + OUT_T):
            continue
        fin, fout = line.get("fin", "wipe"), line.get("fout", "blur")
        o = ease_io((t - line["end"]) / OUT_T) if t > line["end"] else 0.0
        vis = min(1.0, (t - start) / 0.4) * (1 - o)
        d = ((_EX * 4 - W / 2) / (W * 0.42)) ** 2 + ((_EY * 4 - cy) / (H * 0.17)) ** 2
        sh = cv2.resize(np.exp(-d * 1.6), (W, H), interpolation=cv2.INTER_LINEAR)[..., None]
        frame *= 1 - 0.38 * vis * sh
        shift = {}
        for wd in words:
            e = ease_io((t - wd["t"]) / 0.4)
            shift[wd["row"]] = shift.get(wd["row"], 0.0) + wd["step"] / 2 * (1 - e)
        for wd in words:
            age = t - wd["t"]
            if age < 0:
                continue
            spr, sz, hero = wd["spr"], wd["size"], wd["kind"] == "hero"
            x = wd["x"] + shift[wd["row"]]
            by = wd["base_y"]
            # ---- saída da linha
            fade, dy, blur, scale, clip, xmask = 1.0, 0.0, 0.0, 1.0, None, None
            if o > 0:
                if fout == "blur":
                    fade, dy, blur = 1 - o, -10 * o, 6 * o
                elif fout == "slot":  # sobe e some atrás de uma linha invisível
                    dy, clip = -o * sz * 1.1, (by - sz * (0.95 if hero else 1.0), H)
                elif fout == "wipe":  # apagada da esquerda para a direita
                    edge = lerp(lx0 - 60, lx1 + 60, o)
                    xpx = x - (spr["w"] - spr["adv"]) / 2 + np.arange(spr["w"], dtype=np.float32)
                    xmask = np.clip((xpx - edge) / 60, 0, 1)
                elif fout == "punch":
                    fade, scale, blur = 1 - o, 1 + 0.2 * o, 3 * o
                elif fout == "drift":
                    fade, dy = 1 - o, -26 * o
            # ---- entrada da palavra
            shimmer = None
            if hero:
                sp = (age - 0.45) / 1.1
                if 0 < sp < 1:
                    shimmer = lerp(-0.3, 1.3, ease_io(sp))
            if fin in ("cascade", "track"):
                per = 0.045 if fin == "cascade" else 0.0
                dur = 0.42 if fin == "cascade" else 0.6
                if age < per * len(wd["chars"]) + dur:
                    for i, (cs, off) in enumerate(wd["chars"]):
                        pc = (age - i * per) / dur
                        if pc <= 0:
                            continue
                        e = ease_out(pc, 3)
                        cx = x + off
                        cdy = dy
                        if fin == "cascade":  # letras caem uma a uma
                            cdy += -(1 - e) * sz * 0.45
                        else:  # tracking: letras afastadas que se juntam
                            mid = off + cs["adv"] / 2 - spr["adv"] / 2
                            cx += mid * lerp(0.45, 0.0, e)
                        draw_sprite(frame, cs, cx, by, fade * e, cdy, blur + (1 - e) * (5 if hero else 3),
                                    scale, clip=clip)
                    continue
                draw_sprite(frame, spr, x, by, fade, dy, blur, scale, xmask=xmask, clip=clip, shimmer=shimmer)
            elif fin == "slot":  # sobe de dentro de uma fenda invisível
                e = ease_out(age / 0.5, 4)
                c2 = (clip[0] if clip else 0, by + sz * 0.3)
                draw_sprite(frame, spr, x, by, fade, dy + (1 - e) * sz * 1.1, blur, scale, xmask=xmask,
                            clip=c2, shimmer=shimmer)
            elif fin == "glow":  # acende com um clarão dourado e assenta
                e = ease_out(age / 0.5, 3)
                draw_sprite(frame, spr, x, by, fade * e, dy, blur + (1 - e) * 3, scale * lerp(0.9, 1.0, e),
                            xmask=xmask, clip=clip, shimmer=shimmer, bloom=(1 - e) ** 1.3 * (1.0 if hero else 0.6))
            else:  # wipe: revelação macia da esquerda para a direita com desfoque
                p = min(1.0, age / (0.55 if hero else 0.38))
                e = ease_out(p, 3)
                soft = 0.35
                wipe = np.clip((p * (1 + soft) * 1.15 - spr["xs"]) / soft, 0, 1)
                draw_sprite(frame, spr, x, by, fade * e, dy + (1 - e) * (14 if hero else 9),
                            blur + (1 - e) * (7 if hero else 4), scale, wipe=wipe, xmask=xmask, clip=clip,
                            shimmer=shimmer)


# ---------------------------------------------------------------- câmera e efeitos
def camera_matrix(src, cx, cy, wf, rot_deg, extra_scale, off):
    cw = min(wf, 1.0, src["h"] / (src["w"] * 0.75)) * src["w"]
    ch = cw * 0.75
    px, py = cx * src["w"], cy * src["h"]
    px = min(max(px, cw / 2), src["w"] - cw / 2)
    py = min(max(py, ch / 2), src["h"] - ch / 2)
    s = W / cw * extra_scale
    a = math.radians(rot_deg)
    c, si = math.cos(a) * s, math.sin(a) * s
    M = np.float32([[c, -si, 0], [si, c, 0]])
    M[:, 2] = np.float32([W / 2 + off[0], H / 2 + off[1]]) - M[:, :2] @ np.float32([px, py])
    return M


def apply_pt(M, x, y):
    return M[0, 0] * x + M[0, 1] * y + M[0, 2], M[1, 0] * x + M[1, 1] * y + M[1, 2]


def warp_level(src, M, key, intro=False):
    """Escolhe o nível de resolução adequado à escala (evita serrilhado) e aplica o warp."""
    scale = math.hypot(M[0, 0], M[1, 0])
    lv = 1 if scale < 0.6 else 0
    L = src["lv"][lv]
    Ml = M.copy()
    Ml[:, :2] /= L["f"]
    arr = INTRO_BG[lv] if intro else L[key]
    interp = cv2.INTER_LINEAR if key == "mask" else cv2.INTER_CUBIC
    return cv2.warpAffine(arr, Ml, (W, H), flags=interp, borderMode=cv2.BORDER_REFLECT)


def radial_blur(img, k, cx, cy, n=10):
    if k <= 1e-3:
        return img
    sm = cv2.resize(img, (W // 2, H // 2), interpolation=cv2.INTER_AREA)
    acc = np.zeros_like(sm)
    for i in range(n):
        s = 1 + k * i / (n - 1)
        M = np.float32([[s, 0, (1 - s) * cx / 2], [0, s, (1 - s) * cy / 2]])
        acc += cv2.warpAffine(sm, M, (W // 2, H // 2), borderMode=cv2.BORDER_REFLECT)
    bl = cv2.resize(acc / n, (W, H), interpolation=cv2.INTER_LINEAR)
    r = np.sqrt(((_XX * 2 - cx) / W) ** 2 + ((_YY * 2 - cy) / H) ** 2)
    wgt = cv2.resize(np.clip(r * 2.2, 0, 1) * min(1.0, k * 12), (W, H))[..., None]
    return img * (1 - wgt) + bl * wgt


def dir_blur(img, length):
    L = int(abs(length))
    if L < 3:
        return img
    sm = cv2.resize(img, (W // 2, H // 2), interpolation=cv2.INTER_AREA)
    ker = np.ones((1, max(3, L // 2)), np.float32)
    ker /= ker.sum()
    bl = cv2.filter2D(sm, -1, ker, borderType=cv2.BORDER_REFLECT)
    return cv2.resize(bl, (W, H), interpolation=cv2.INTER_LINEAR)


def god_rays(ox, oy, t, seed, strength):
    ang = np.arctan2(_YY - oy / 2, _XX - ox / 2)
    r = np.sqrt((_XX - ox / 2) ** 2 + (_YY - oy / 2) ** 2) / (H / 2)
    u = (ang / (2 * math.pi) + 0.5) * 720 + t * 6 + seed * 37
    i0 = np.floor(u).astype(np.int32)
    fr = u - i0
    nz = RAY_NOISE[i0 % 720] * (1 - fr) + RAY_NOISE[(i0 + 1) % 720] * fr
    rays = smoothstep(0.35, 1.0, nz) * np.exp(-r * 1.25) * smoothstep(0.0, 0.25, r)
    glow = np.exp(-r * 4.0) * 0.7
    v = (rays * 0.9 + glow) * strength * (0.9 + 0.1 * math.sin(t * 1.3 + seed))
    v = cv2.resize(v, (W, H), interpolation=cv2.INTER_LINEAR)
    return v[..., None] * np.array([1.0, 0.86, 0.6], np.float32)


def particles(seed, t, count, col):
    rng = np.random.default_rng(seed)
    x = rng.random(count) * W
    y = rng.random(count) * H
    z = rng.random(count) ** 1.5
    sp = 18 + 55 * z
    ph = rng.random(count) * 6.28
    canvas = np.zeros((H // 2, W // 2), np.float32)
    big = np.zeros_like(canvas)
    for j in range(count):
        px = (x[j] + 22 * math.sin(t * 0.7 + ph[j]) + t * 8 * (z[j] - 0.4)) % W
        py = (y[j] - sp[j] * t) % H
        tw = 0.55 + 0.45 * math.sin(t * 2.4 + ph[j] * 3)
        rad = 0.6 + 2.6 * z[j]
        tgt = big if z[j] > 0.75 else canvas
        cv2.circle(tgt, (int(px / 2), int(py / 2)), max(1, int(round(rad))), float(tw * (0.4 + 0.6 * z[j])), -1, cv2.LINE_AA)
    lay = cv2.GaussianBlur(canvas, (0, 0), 1.2) * 1.6 + cv2.GaussianBlur(big, (0, 0), 3.5) * 1.2
    lay = cv2.resize(lay, (W, H), interpolation=cv2.INTER_LINEAR)
    return np.clip(lay, 0, 1)[..., None] * np.array(col, np.float32)


def light_leak(t, strength):
    """Vazamentos de luz quentes que passeiam pelas bordas (película)."""
    acc = np.zeros((H // 2, W // 2), np.float32)
    for k, (sx, sy, ph, rr) in enumerate([(0.13, 0.09, 0.0, 0.55), (0.08, 0.15, 2.1, 0.45)]):
        cx = W / 4 + math.cos(t * sx * 2 * math.pi / 3 + ph) * W * 0.42 / 2 * 1.9
        cy = H / 4 + math.sin(t * sy * 2 * math.pi / 3 + ph * 1.3) * H * 0.40 / 2 * 1.9
        d = ((_XX - cx) / (W * rr / 2)) ** 2 + ((_YY - cy) / (H * rr / 2)) ** 2
        acc += np.exp(-d * 2.2) * (0.7 + 0.3 * math.sin(t * 0.9 + k * 2))
    acc = cv2.resize(acc, (W, H), interpolation=cv2.INTER_LINEAR)[..., None]
    return acc * strength * np.array([1.0, 0.62, 0.28], np.float32)


# ---------------------------------------------------------------- figura viva
# rosto de Jesus em cada imagem: (cx, cy, raio) normalizados pela largura/altura da imagem
FACE = {1: (0.57, 0.25, 0.07), 2: (0.355, 0.235, 0.07), 3: (0.50, 0.30, 0.06), 4: (0.51, 0.19, 0.07),
        5: (0.41, 0.36, 0.06), 6: (0.41, 0.33, 0.07), 7: (0.50, 0.27, 0.06), 8: (0.45, 0.16, 0.06),
        9: (0.55, 0.255, 0.04), 10: (0.49, 0.226, 0.03), 11: (0.41, 0.45, 0.035), 12: (0.655, 0.185, 0.045),
        13: (0.53, 0.31, 0.08)}
_QY, _QX = np.mgrid[0:H // 4, 0:W // 4].astype(np.float32) * 4
_FY, _FX = np.mgrid[0:H, 0:W].astype(np.float32)


def alive_field(shot, src, Mf, t):
    """Campo de deslocamento (tela) que dá vida à figura: respiração, balanço do corpo,
    cabeça inclinando devagar (rígida, o rosto não deforma) e roupa/cabelo ondulando."""
    fxn, fyn, frn = FACE[shot["img"]]
    fx, fy = apply_pt(Mf, fxn * src["w"], fyn * src["h"])
    R = frn * src["w"] * math.hypot(Mf[0, 0], Mf[1, 0])
    x0, y0, x1, y1 = src["bbox"]
    floating = shot["img"] in (4, 9)
    px, py = apply_pt(Mf, (x0 + x1) / 2, (y0 + y1) / 2 if floating else y1)
    ph = shot["img"] * 1.7
    X, Y = _QX, _QY
    dx = np.zeros_like(X)
    dy = np.zeros_like(Y)
    dist = np.sqrt((X - fx) ** 2 + (Y - fy) ** 2)

    # 1) cabeça: rotação rígida em torno do pescoço, com transição suave para o corpo
    nx, ny = fx, fy + 1.25 * R
    th = math.radians(1.1 * math.sin(2 * math.pi * t / 5.3 + ph) + 0.45 * math.sin(2 * math.pi * t / 3.1 + ph * 2))
    wh = 1 - smoothstep(1.35 * R, 2.6 * R, dist)
    rx, ry = X - nx, Y - ny
    dx += (math.cos(th) * rx - math.sin(th) * ry - rx) * wh
    dy += (math.sin(th) * rx + math.cos(th) * ry - ry) * wh

    # 2) corpo: balanço leve em torno dos pés (ou do centro, se flutua)
    tb = math.radians(0.45 * math.sin(2 * math.pi * t / 6.4 + ph))
    span = max(py - fy, 1.0)
    wb = np.ones_like(X) if floating else np.clip((py - Y) / span, 0, 1.2)
    rx, ry = X - px, Y - py
    dx += (math.cos(tb) * rx - math.sin(tb) * ry - rx) * wb
    dy += (math.sin(tb) * rx + math.cos(tb) * ry - ry) * wb

    # 3) respiração: o peito sobe e expande
    cx, cyy = fx, fy + 2.7 * R
    br = 0.5 - 0.5 * math.cos(2 * math.pi * t / 4.2 + ph)
    g = np.exp(-((X - cx) ** 2 + (Y - cyy) ** 2) / (2 * (2.3 * R) ** 2))
    dy += -0.10 * R * br * g
    dx += (X - cx) * 0.025 * br * g

    # 4) roupa e cabelo: onda que desce pelo tecido (longe do rosto)
    wc = smoothstep(2.0 * R, 4.5 * R, dist) * np.clip((Y - fy) / (5 * R), 0, 1)
    wave = 2 * math.pi * (Y / (7 * R) + X / (21 * R)) - 2 * math.pi * t / 2.7 + ph
    dx += 0.055 * R * wc * np.sin(wave)
    dy += 0.018 * R * wc * np.cos(wave * 0.8)
    return dx, dy


def animate_figure(fg, mk, shot, src, Mf, t):
    dx, dy = alive_field(shot, src, Mf, t)
    dx = cv2.resize(dx, (W, H), interpolation=cv2.INTER_LINEAR)
    dy = cv2.resize(dy, (W, H), interpolation=cv2.INTER_LINEAR)
    mx, my = _FX - dx, _FY - dy
    fg = cv2.remap(fg, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    mk = cv2.remap(mk, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    return fg, mk


# ---------------------------------------------------------------- render de um plano
def render_shot(shot, f, tx=None):
    """Renderiza o plano no frame f (pode ser antes/depois do plano, durante transições).
    tx: transformação extra de tela vinda da transição (scale, dx, dy, rot)."""
    src = IMGS[shot["img"]]
    n = shot["f1"] - shot["f0"]
    lf = f - shot["f0"]
    u = lf / max(n - 1, 1)
    t = f / FPS
    cut = shot["cut"]
    prog = 0.3 * ease_out(u, 3) + 0.7 * u
    if cut == "intro":
        hold = n - 16
        prog = 0.12 * ease_io(min(lf / hold, 1.0)) + 0.88 * min(1.0, max(0.0, (lf - hold) / 15)) ** 2
    cx, cy, wf = (lerp(shot["a"][i], shot["b"][i], prog) for i in range(3))

    # micro-movimento de câmera na mão (bem sutil)
    sd = shot["seed"]
    off = [5 * math.sin(t * 0.73 + sd) + 3 * math.sin(t * 1.9 + sd * 2),
           4 * math.sin(t * 0.61 + sd * 3) + 2 * math.sin(t * 1.7 + sd)]
    rot = 0.22 * math.sin(t * 0.45 + sd)
    extra, rblur, flash = 1.0, 0.0, 0.0
    for b in BEATS:
        d = t - b
        if 0 <= d < 0.3:
            extra *= 1 + 0.022 * (1 - d / 0.3) ** 2

    if cut == "intro":
        if lf < 23:
            e = ease_out(lf / 23, 3)
            ang, zin = lerp(-5.0, -1.5, e), lerp(1.30, 1.0, e)
        else:
            e = ease_io(min(1.0, (lf - 23) / 40))
            ang, zin = lerp(-1.5, 0.0, e), 1.0
        rot += ang
        extra *= zin
        if lf < 7:
            k_ = 1 - ease_out(lf / 7, 2)
            flash = 0.9 * k_
            rblur = 0.14 * k_
    if tx:
        extra *= tx.get("scale", 1.0)
        off[0] += tx.get("dx", 0.0)
        off[1] += tx.get("dy", 0.0)
        rot += tx.get("rot", 0.0)
    # escala mínima que cobre a tela com a rotação + margem do micro-movimento
    a_ = math.radians(abs(rot))
    extra *= (math.cos(a_) + W / H * math.sin(a_)) * 1.012

    M = camera_matrix(src, cx, cy, wf, rot, extra, off)

    # parallax 2.5D: a figura aproxima mais que o fundo e desliza lateralmente
    x0, y0, x1, y1 = src["bbox"]
    floating = shot["img"] in (4, 9)
    pvx, pvy = apply_pt(M, (x0 + x1) / 2, (y0 + y1) / 2 if floating else y1)
    k = 1 + shot.get("par", 0.04) * ease_io(u)
    lat = shot.get("lat", 0.0) * (min(max(u, -0.2), 1.2) - 0.5) * W
    Pm = np.float32([[k, 0, (1 - k) * pvx + lat], [0, k, (1 - k) * pvy]])
    Mf = (Pm[:, :2] @ M).astype(np.float32)
    Mf[:, 2] += Pm[:, 2]

    bg = warp_level(src, M, "bg", intro=(cut == "intro")).astype(np.float32) / 255
    fg = warp_level(src, Mf, "img").astype(np.float32) / 255
    mk = warp_level(src, Mf, "mask").astype(np.float32) / 255
    fg, mk = animate_figure(fg, mk, shot, src, Mf, t)  # Jesus "vivo"
    mk = mk[..., None]

    rays = None
    if shot.get("rays"):
        rx, ry, rs = shot["rays"]
        ox, oy = apply_pt(M, rx * src["w"], ry * src["h"])
        rays = np.clip(god_rays(ox, oy, t, sd, rs), 0, 1)
        bg = 1 - (1 - bg) * (1 - rays)
    frame = bg * (1 - mk) + fg * mk

    if shot.get("clouds"):
        tex = CLOUDS[shot["clouds"]]
        rise = (1 - ease_out(min(max(u, 0), 1), 2)) * 60 if shot["clouds"] != "intro" else 0
        for li, (layer, spd) in enumerate(zip(tex, (32, 60))):
            x = int((t * spd + li * 300) % W)
            sl = layer[:, x:x + W]
            dy = int(rise * (li + 1) * 0.6)
            if dy > 0:
                sl = np.concatenate([np.zeros_like(sl[:dy]), sl[:-dy]], axis=0)
            a = sl[..., 3:4] * (0.95 if shot["clouds"] == "intro" else 0.8)
            frame = frame * (1 - a) + sl[..., :3] * a

    if rays is not None:
        frame = 1 - (1 - frame) * (1 - rays * 0.25)
    if shot.get("particles"):
        p = particles(sd, t, shot["particles"], shot.get("pcol", (1.0, 0.85, 0.55)))
        frame = 1 - (1 - frame) * (1 - p * 0.7)
    if rblur > 0:
        frame = radial_blur(frame, rblur, W / 2, H * 0.4)
    if flash > 0:
        frame = frame + (1 - frame) * flash * np.array([1.0, 0.94, 0.82], np.float32)
    return frame


# ---------------------------------------------------------------- transições
# janela (frames antes, frames depois do corte) de cada tipo
TWIN = {"zoom": (7, 8), "dissolve": (10, 10), "slide": (6, 6), "flash": (3, 9), "spin": (6, 7),
        "punch": (0, 6)}


def chroma(img, amt):
    """Aberração cromática radial (separa R e B do centro para as bordas)."""
    if amt < 0.3:
        return img
    out = img.copy()
    for c, s in ((0, 1 + amt / W), (2, 1 - amt / W)):
        M = np.float32([[s, 0, (1 - s) * W / 2], [0, s, (1 - s) * H / 2]])
        out[..., c] = cv2.warpAffine(img[..., c], M, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    return out


def spin_blur(img, ang_deg, n=8):
    if abs(ang_deg) < 0.5:
        return img
    sm = cv2.resize(img, (W // 2, H // 2), interpolation=cv2.INTER_AREA)
    acc = np.zeros_like(sm)
    for i in range(n):
        a = ang_deg * (i / (n - 1) - 0.5)
        M = cv2.getRotationMatrix2D((W / 4, H / 4), a, 1.0)
        acc += cv2.warpAffine(sm, M, (W // 2, H // 2), borderMode=cv2.BORDER_REFLECT)
    bl = cv2.resize(acc / n, (W, H), interpolation=cv2.INTER_LINEAR)
    r = np.sqrt(((_XX * 2 - W / 2) / W) ** 2 + ((_YY * 2 - H / 2) / H) ** 2)
    wgt = cv2.resize(np.clip(r * 2.5, 0, 1), (W, H))[..., None]
    return img * (1 - wgt) + bl * wgt


def shake(e, seed):
    """Tremor de impacto que decai (dx, dy, rot)."""
    a = (1 - e) ** 2
    return dict(dx=14 * a * math.sin(seed * 7.1 + e * 40), dy=10 * a * math.sin(seed * 3.3 + e * 33),
                rot=0.5 * a * math.sin(seed * 5.7 + e * 37))


def transition_frame(f):
    """Se f cai na janela de uma transição, devolve o frame composto; senão None."""
    for k in range(1, len(SHOTS)):
        B = SHOTS[k]
        typ = B["cut"]
        pre, post = TWIN.get(typ, (0, 0))
        c = B["f0"]
        if not (c - pre <= f < c + post):
            continue
        A = SHOTS[k - 1]
        p = (f - (c - pre) + 0.5) / (pre + post)  # 0..1 ao longo da janela
        m = pre / (pre + post)  # ponto do corte
        fx = None
        if typ == "zoom":
            # zoom contínuo: A acelera para dentro, B chega desacelerando de dentro
            if p < m:
                q = p / m
                fr = render_shot(A, f, dict(scale=1 + 0.85 * q ** 2.2))
                amt = q ** 2
            else:
                q = (p - m) / (1 - m)
                fr = render_shot(B, f, dict(scale=1 + 0.85 * (1 - ease_out(q, 3))))
                amt = (1 - ease_out(q, 2)) ** 1.5
                if q < 0.2:  # dois frames de mistura no ponto do corte
                    fa = render_shot(A, f, dict(scale=1.85))
                    fr = fr * (q / 0.2) + fa * (1 - q / 0.2)
            fr = radial_blur(fr, 0.32 * amt, W / 2, H / 2)
            fr = chroma(fr, 18 * amt)
            fr = 1 - (1 - fr) * (1 - 0.10 * amt)
            return fr
        if typ == "dissolve":
            # dissolve por luminância: as luzes da cena nova surgem primeiro, com brilho
            fa = render_shot(A, f, dict(scale=1 + 0.03 * p))
            fb = render_shot(B, f, dict(scale=1.03 - 0.03 * p))
            lum = cv2.GaussianBlur(fb.mean(2), (0, 0), 6)
            th = lerp(1.25, -0.25, ease_io(p))
            w = smoothstep(th - 0.22, th + 0.22, lum)[..., None]
            fr = fa * (1 - w) + fb * w
            pk = math.sin(math.pi * p)
            fr = 1 - (1 - fr) * (1 - 0.16 * pk * np.array([1.0, 0.86, 0.62], np.float32))
            return fr
        if typ == "slide":
            # as duas cenas deslizam juntas com motion blur proporcional à velocidade
            d = B.get("wdir", 1)
            e = ease_io(p) ** 1.0
            sh = e * W
            fa = render_shot(A, f, dict(dx=-d * sh))
            fb = render_shot(B, f, dict(dx=d * (W - sh)))
            xx = np.arange(W, dtype=np.float32)[None, :, None]
            edge = W - sh if d > 0 else sh
            sel = (xx >= edge) if d > 0 else (xx < edge)
            fr = np.where(sel, fb, fa)
            v = math.pi / 2 * math.sin(math.pi * p) * W / (pre + post)
            fr = dir_blur(fr, v * 0.6)
            return chroma(fr, 8 * math.sin(math.pi * p))
        if typ == "flash":
            if p < m:  # A estoura a exposição
                q = p / m
                fr = render_shot(A, f, dict(scale=1 + 0.04 * q))
                g = q ** 2
            else:
                q = (p - m) / (1 - m)
                tx = shake(q, k)
                tx["scale"] = 1 + 0.07 * (1 - ease_out(q, 2))
                fr = render_shot(B, f, tx)
                g = (1 - ease_out(q, 2))
            fr = 1 - (1 - fr) ** (1 + 3 * g)  # superexposição suave (não é branco chapado)
            fr = fr + (1 - fr) * 0.55 * g * np.array([1.0, 0.95, 0.85], np.float32)
            return fr
        if typ == "spin":
            if p < m:
                q = p / m
                fr = render_shot(A, f, dict(rot=28 * q ** 2.2, scale=1 + 0.2 * q ** 2))
                fr = spin_blur(fr, 30 * q ** 1.5)
                amt = q
            else:
                q = (p - m) / (1 - m)
                e = 1 - ease_out(q, 3)
                fr = render_shot(B, f, dict(rot=-28 * e, scale=1 + 0.2 * e))
                fr = spin_blur(fr, 30 * e ** 1.2)
                amt = e
            return chroma(fr, 14 * amt)
        if typ == "punch":
            q = p
            tx = shake(q, k)
            tx["scale"] = 1 + 0.12 * (1 - ease_out(q, 3))
            fr = render_shot(B, f, tx)
            return chroma(fr, 10 * (1 - q))
        return fx
    return None


def beat_env(t):
    v = 0.0
    for b in BEATS:
        d = t - b
        if 0 <= d < 0.25:
            v = max(v, 0.045 * (1 - d / 0.25) ** 2)
    return v


def render_frame(f):
    t = f / FPS
    shot = next(s for s in SHOTS if s["f0"] <= f < s["f1"])
    frame = transition_frame(f)
    if frame is None:
        frame = render_shot(shot, f)
    frame = 1 - (1 - frame) * (1 - light_leak(t, 0.09))
    frame = grade(frame, f)
    frame = frame * (1 + beat_env(t))  # leve pulso de luz em cada batida forte
    if shot.get("fade"):
        n, lf = shot["f1"] - shot["f0"], f - shot["f0"]
        nf = int(shot["fade"] * FPS)
        e = max(0.0, (lf - (n - nf)) / (nf - 1))
        frame = frame + (1 - frame) * (ease_io(e) * 0.85) * np.array([1.0, 0.94, 0.82], np.float32)
    draw_lyrics(frame, t)
    if shot.get("fade"):
        frame = frame * (1 - ease_io(max(0.0, (f - (shot["f1"] - 10)) / 9)))
    return (np.clip(frame, 0, 1) * 255 + 0.5).astype(np.uint8)


def grade(fr, f):
    lum = fr.mean(2, keepdims=True)
    hi = fr * smoothstep(0.62, 1.0, lum)
    sm = cv2.resize(hi, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
    bloom = cv2.resize(cv2.GaussianBlur(sm, (0, 0), 9), (W, H), interpolation=cv2.INTER_LINEAR)
    fr = 1 - (1 - fr) * (1 - bloom * 0.32)
    fr = fr + (smoothstep(0.4, 1.0, lum) * 0.035) * np.array([1.0, 0.45, -0.6], np.float32)
    fr = fr + 0.06 * (fr - 0.5) * (1 - np.abs(2 * fr - 1))
    fr = fr * VIGNETTE
    g = np.random.default_rng(f).standard_normal((H // 2, W // 2)).astype(np.float32)
    g = cv2.resize(g, (W, H), interpolation=cv2.INTER_LINEAR)[..., None]
    return fr + g * 0.009


# ---------------------------------------------------------------- main
def main():
    os.makedirs(os.path.join(ROOT, "saida"), exist_ok=True)
    if "--preview" in sys.argv:
        fs = list(range(0, NFRAMES, 15))
        with Pool(os.cpu_count()) as pool:
            frames = pool.map(render_frame, fs)
        th = [cv2.resize(fr, (320, 240), interpolation=cv2.INTER_AREA) for fr in frames]
        while len(th) % 9:
            th.append(np.zeros_like(th[0]))
        rows = [np.hstack(th[i:i + 9]) for i in range(0, len(th), 9)]
        cv2.imwrite(os.path.join(ROOT, "saida", "preview.jpg"), np.vstack(rows)[:, :, ::-1])
        return
    if "--frames" in sys.argv:
        for a in sys.argv[sys.argv.index("--frames") + 1].split(","):
            cv2.imwrite(os.path.join(ROOT, "saida", f"f{int(a):04d}.jpg"), render_frame(int(a))[:, :, ::-1])
        return
    cmd = ["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
           "-r", str(FPS), "-i", "-", "-i", AUDIO, "-map", "0:v", "-map", "1:a",
           "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-tune", "film",
           "-profile:v", "high", "-pix_fmt", "yuv420p",
           "-af", f"afade=t=out:st={DUR - 0.8}:d=0.8", "-c:a", "aac", "-b:a", "320k",
           "-t", str(DUR), "-movflags", "+faststart", OUT]
    ff = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    with Pool(os.cpu_count()) as pool:
        for i, fr in enumerate(pool.imap(render_frame, range(NFRAMES), chunksize=2)):
            ff.stdin.write(fr.tobytes())
            if i % 120 == 0:
                print(f"frame {i}/{NFRAMES}", flush=True)
    ff.stdin.close()
    ff.wait()
    print("ok ->", OUT)


if __name__ == "__main__":
    main()

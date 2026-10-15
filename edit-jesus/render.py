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

from god_text import make_god

ROOT = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1920, 1440, 120
SC = W / 1440  # escala dos tamanhos em pixel (referência 1440 px)
R30 = FPS / 30  # quadros de saída por quadro de 30 fps (animações foram afinadas a 30 fps)
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
# auréolas que o recorte automático deixou de fora: entram na figura (disco com borda suave),
# senão o parallax as descola da cabeça. (cx, cy, raio) normalizados pela largura/altura
HALO_ADD = {2: [(0.355, 0.22, 0.075)], 7: [(0.50, 0.255, 0.07)], 10: [(0.49, 0.215, 0.045)],
            12: [(0.655, 0.17, 0.085)], 13: [(0.55, 0.25, 0.21)]}
PAR_GAIN, LAT_GAIN = 0.6, 0.5  # parallax mais contido: revela menos fundo preenchido


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
    hh_, ww_ = m.shape
    yy_, xx_ = np.mgrid[0:hh_, 0:ww_].astype(np.float32)
    for hx, hy, hr in HALO_ADD.get(i, []):
        d_ = np.sqrt((xx_ - hx * ww_) ** 2 + (yy_ - hy * hh_) ** 2) / (hr * ww_)
        m = np.maximum(m, ((1 - smoothstep(0.85, 1.08, d_)) * 255).astype(np.uint8))
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

# letreiro GOD (camada própria no espaço da imagem 4: atrás de Jesus, na frente do céu)
_i4 = IMGS[4]
GOD = make_god(int(_i4["w"] * 0.84))
GOD_POS = (_i4["w"] * 0.5 - GOD["w"] / 2, _i4["h"] * 0.215 - GOD["h"] / 2)
GOD_LV = [GOD, {k: (cv2.resize(v, (GOD["w"] // 2, GOD["h"] // 2), interpolation=cv2.INTER_AREA)
                    if isinstance(v, np.ndarray) else v) for k, v in GOD.items()}]
GOD_SWEEPS = [(0.45, 1.25), (2.75, 1.25)]  # (início, duração) do reflexo, nas batidas da introdução


def draw_god(bg, M, t):
    """Compõe o GOD sobre o fundo já projetado na tela, com reflexo de luz e faísca animados."""
    scale = math.hypot(M[0, 0], M[1, 0])
    lv = 1 if scale < 0.6 else 0
    g = GOD_LV[lv]
    f = 0.5 ** lv
    Mt = M.copy()
    Mt[:, :2] /= f
    Mt[:, 2] = M[:, :2] @ np.float32(GOD_POS) + M[:, 2]
    kw = dict(flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT)
    rgbp = cv2.warpAffine(g["rgbp"], Mt, (W, H), **kw)
    a = np.clip(cv2.warpAffine(g["a"], Mt, (W, H), **kw), 0, 1)[..., None]
    out = bg * (1 - a) + np.clip(rgbp, 0, None)
    for t0, dur in GOD_SWEEPS:
        p = (t - t0) / dur
        if 0 < p < 1:
            sh = cv2.warpAffine(g["shine"], Mt, (W, H), **kw)
            pos = lerp(-0.25, 1.35, ease_io(p))
            band = np.exp(-(((_XF / W) + 0.45 * (_YF / H) - pos) / 0.055) ** 2) * sh
            out = out + band[..., None] * np.float32([0.75, 0.62, 0.40])
            # faísca em estrela no topo do "O" quando o reflexo passa por ele
            sx, sy = apply_pt(M, GOD_POS[0] + GOD["w"] * 0.505, GOD_POS[1] + GOD["h"] * 0.20)
            k = math.exp(-(((sx / W) + 0.45 * (sy / H) - pos) / 0.05) ** 2)
            if k > 0.02:
                out = out + star(sx, sy, 140 * SC * k, k)
    return out


def star(cx, cy, size, k):
    """Faísca de 4 pontas (brilho de lente) centrada em (cx, cy)."""
    x0, x1 = int(max(0, cx - size)), int(min(W, cx + size))
    y0, y1 = int(max(0, cy - size)), int(min(H, cy + size))
    out = np.zeros((H, W, 3), np.float32)
    if x1 <= x0 or y1 <= y0:
        return out
    X, Y = _XF[y0:y1, x0:x1] - cx, _YF[y0:y1, x0:x1] - cy
    r = np.sqrt(X ** 2 + Y ** 2) / size
    rays = np.exp(-np.abs(Y) / (size * 0.018)) * np.exp(-np.abs(X) / (size * 0.55))
    rays += np.exp(-np.abs(X) / (size * 0.018)) * np.exp(-np.abs(Y) / (size * 0.40))
    core = np.exp(-r * 9)
    v = (rays * 0.8 + core) * k
    out[y0:y1, x0:x1] = v[..., None] * np.float32([1.0, 0.93, 0.78])
    return out


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
_YF, _XF = np.mgrid[0:H, 0:W].astype(np.float32)
_yy, _xx = np.mgrid[0:H, 0:W].astype(np.float32)
_r = np.sqrt(((_xx - W / 2) / (W / 2)) ** 2 + ((_yy - H / 2) / (H / 2)) ** 2) / math.sqrt(2)
VIGNETTE = (1 - 0.30 * smoothstep(0.45, 1.0, _r))[..., None]
BOTTOM_SHADE = smoothstep(0.55, 1.0, _yy / H)[..., None]  # escurece a base para as legendas
del _yy, _xx, _r


# ---------------------------------------------------------------- roteiro
# crop: (cx, cy, w) normalizados na imagem; w = fração da largura enquadrada (4:3)
# cut:  transição de ENTRADA: intro | burn | iris | cloud | flare | smoke | bloom | punch
# lat:  deslocamento lateral da figura em relação ao fundo (parallax de travelling)
S = lambda **k: k  # noqa: E731
# Sincronia: os cortes caem exatamente nas batidas do baixo/percussão detectadas no áudio
# (as mais fortes viram cortes; as demais, pulsos de zoom e luz). Nos versos, a batida mais
# próxima do início da frase cantada.
SHOTS = [
    # --- versos (corte na batida mais próxima do início de cada frase)
    S(img=4, t0=0.00, t1=3.855, a=(0.50, 0.40, 1.00), b=(0.52, 0.32, 0.62), cut="intro",
      clouds="intro", rays=(0.53, 0.20, 0.30), particles=45, par=0.06),
    S(img=11, t0=3.855, t1=6.56, a=(0.50, 0.50, 0.95), b=(0.44, 0.52, 0.78), cut="bloom",
      rays=(0.85, 0.30, 0.22), particles=45, par=0.07, lat=0.012),
    S(img=2, t0=6.56, t1=9.317, a=(0.52, 0.44, 1.00), b=(0.44, 0.38, 0.80), cut="smoke",
      particles=35, par=0.07, lat=-0.012, pcol=(0.85, 0.95, 1.0)),
    S(img=12, t0=9.317, t1=11.238, a=(0.50, 0.27, 1.00), b=(0.58, 0.25, 0.84), cut="flare",
      rays=(0.66, 0.10, 0.22), particles=40, par=0.07, lat=0.010),
    S(img=8, t0=11.238, t1=13.502, a=(0.50, 0.36, 1.00), b=(0.50, 0.30, 0.84), cut="cloud",
      rays=(0.48, 0.10, 0.22), particles=40, par=0.07, lat=-0.010),
    S(img=7, t0=13.502, t1=15.447, a=(0.50, 0.35, 0.90), b=(0.50, 0.28, 0.70), cut="iris",
      rays=(0.50, 0.24, 0.32), particles=50, par=0.05),
    # --- instrumental (cada foto uma vez, ~2 s; os planos abertos avançam devagar até o close)
    S(img=10, t0=15.447, t1=18.303, a=(0.50, 0.50, 0.95), b=(0.49, 0.35, 0.54), cut="burn",
      particles=40, par=0.06, lat=0.010),
    S(img=13, t0=18.303, t1=20.55, a=(0.50, 0.45, 1.00), b=(0.52, 0.38, 0.72), cut="bloom",
      beam=True, particles=40, par=0.06, lat=-0.010),
    S(img=1, t0=20.55, t1=22.5, a=(0.53, 0.38, 1.00), b=(0.55, 0.33, 0.80), cut="cloud",
      particles=45, par=0.07, lat=0.012),
    S(img=6, t0=22.5, t1=24.735, a=(0.50, 0.43, 1.00), b=(0.46, 0.40, 0.62), cut="flare",
      particles=30, par=0.06, lat=-0.012),
    S(img=3, t0=24.735, t1=26.662, a=(0.50, 0.42, 1.00), b=(0.49, 0.38, 0.76), cut="iris",
      rays=(0.52, 0.12, 0.24), particles=40, par=0.06, lat=0.010),
    S(img=5, t0=26.662, t1=28.909, a=(0.50, 0.38, 1.00), b=(0.46, 0.39, 0.62), cut="smoke",
      rays=(0.75, 0.0, 0.24), particles=40, par=0.06),
    S(img=12, t0=28.909, t1=30.824, a=(0.60, 0.24, 0.66), b=(0.62, 0.22, 0.58), cut="burn",
      rays=(0.66, 0.10, 0.22), particles=35, par=0.04),
    S(img=11, t0=30.824, t1=33.03, a=(0.47, 0.54, 0.62), b=(0.43, 0.52, 0.50), cut="cloud",
      rays=(0.85, 0.30, 0.22), particles=40, par=0.04),
    S(img=2, t0=33.03, t1=35.927, a=(0.46, 0.36, 0.74), b=(0.41, 0.31, 0.58), cut="iris",
      particles=35, par=0.04, lat=-0.008, pcol=(0.85, 0.95, 1.0)),
    # --- volta da letra
    S(img=4, t0=35.927, t1=37.576, a=(0.50, 0.42, 1.00), b=(0.51, 0.38, 0.86), cut="bloom",
      clouds="warm", rays=(0.53, 0.25, 0.36), particles=60, par=0.07),
    S(img=7, t0=37.576, t1=38.83, a=(0.50, 0.29, 0.72), b=(0.50, 0.28, 0.66), cut="flare",
      rays=(0.50, 0.24, 0.32), particles=40, par=0.03),
    S(img=9, t0=38.83, t1=40.40, a=(0.50, 0.37, 0.76), b=(0.50, 0.41, 1.00), cut="bloom",
      clouds="cool", rays=(0.50, 0.36, 0.45), particles=70, par=0.04, fade=1.4),
]
# demais batidas (tempo, força): pulso de zoom + pulso de luz proporcionais à força
PULSES = [
    (0.342, 0.7), (0.946, 0.71), (1.602, 0.64), (1.904, 0.61), (2.113, 0.57), (2.891, 0.7),
    (3.21, 0.51), (3.529, 0.86), (4.824, 0.59), (5.462, 0.71), (5.782, 0.55), (6.751, 0.6),
    (7.378, 0.74), (7.692, 0.83), (8.655, 0.5), (9.642, 0.66), (10.252, 0.54), (10.919, 0.53),
    (11.587, 0.78), (12.841, 0.71), (14.449, 0.58), (16.086, 0.52), (16.382, 0.65), (16.579, 0.55),
    (16.887, 0.58), (17.995, 0.71), (18.959, 0.51), (19.574, 0.83), (20.248, 0.78), (21.206, 0.57),
    (21.513, 0.67), (21.705, 0.52), (22.187, 0.76), (23.15, 0.68), (24.416, 0.68), (25.385, 0.65),
    (26.337, 0.71), (27.005, 0.53), (27.307, 0.66), (28.613, 0.6), (29.547, 0.68), (30.511, 0.65),
    (32.119, 0.67), (32.7, 0.64), (33.379, 0.7), (33.698, 0.62), (34.017, 0.91), (35.289, 0.75),
    (35.619, 0.75), (36.304, 0.63), (36.891, 0.9), (37.256, 0.52), (37.878, 0.88), (38.412, 0.67),
    (39.491, 1.15), (39.811, 0.82),
    # antigos cortes (agora pulsos fortes)
    (17.345, 0.95), (23.783, 0.95), (25.71, 0.9), (27.951, 0.95), (31.782, 0.9), (34.963, 0.95),
]
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
HERO_SZ, SMALL_SZ = round(80 * SC), round(27 * SC)
SMALL_TRACK = 0.36  # espaçamento entre letras (em) da fileira pequena
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
        glow_col, glow_r, glow_k = (1.0, 0.78, 0.42), 16 * SC, 0.30
    else:
        m, adv, base, top = text_mask(word.upper(), SMALL_FONT, SMALL_SZ, SMALL_TRACK)
        h, w = m.shape
        yy = np.linspace(0, 1, h, dtype=np.float32)[:, None]
        t = np.clip((yy * h - top) / (base - top), 0, 1)[..., None]
        face = np.array([0.99, 0.95, 0.87], np.float32) * (1 - t) + np.array([0.90, 0.82, 0.68], np.float32) * t
        face = np.broadcast_to(face, (h, w, 3)).copy()
        glow_col, glow_r, glow_k = (1.0, 0.85, 0.6), 10 * SC, 0.12
    # sombra projetada macia (legibilidade sem contorno grosseiro)
    sh = cv2.GaussianBlur(m, (0, 0), HERO_SZ * 0.09 if kind == "hero" else 5 * SC)
    sh = np.roll(sh, round(3 * SC), 0) * (0.62 if kind == "hero" else 0.70)
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
    bloom = np.clip(cv2.GaussianBlur(m, (0, 0), (14 if kind == "hero" else 8) * SC) * 1.6, 0, 1)
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
    gap = {"hero": HERO_SZ * 0.26, "small": SMALL_SZ * 1.0}
    row_h = {"hero": HERO_SZ * 1.0, "small": SMALL_SZ * 2.6}
    rows = line["rows"]
    total_h = sum(row_h[k] for k, _ in rows)
    y = CY - total_h / 2
    out, seps = [], []
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
        if r < len(rows) - 1:
            seps.append(y + (SMALL_SZ * 0.15 if kind == "hero" else -SMALL_SZ * 0.05))
    xs = [wd["x"] for wd in out] + [wd["x"] + wd["spr"]["adv"] for wd in out]
    return out, CY, (min(xs), max(xs)), seps


CY = H * 0.86  # centro vertical do bloco de legenda
LAYOUT = [(ln,) + layout_line(ln) for ln in LYRICS]


def _ornament(w=round(300 * SC), h=round(11 * SC) | 1):
    """Filete dourado com losango central (pré-multiplicado)."""
    xs = np.linspace(-1, 1, w, dtype=np.float32)
    line = np.zeros((h, w), np.float32)
    yc = h // 2
    fade = np.clip(1 - np.abs(xs) ** 1.8, 0, 1)
    line[yc] = fade * 0.9
    line[yc - 1] = line[yc + 1] = fade * 0.25
    gap = (np.abs(xs) < 0.05)  # espaço em volta do losango
    line[:, gap] = 0
    dm = np.zeros((h, w), np.uint8)
    cx = w // 2
    q = round(4 * SC)
    cv2.fillConvexPoly(dm, np.int32([[cx, yc - q], [cx + q, yc], [cx, yc + q], [cx - q, yc]]), 255, cv2.LINE_AA)
    a = np.clip(line + dm.astype(np.float32) / 255, 0, 1)
    col = np.array([0.96, 0.82, 0.52], np.float32)
    return a, col, xs


ORN_A, ORN_COL, ORN_X = _ornament()


def draw_ornament(frame, y, grow, fade):
    if fade <= 0.01 or grow <= 0.01:
        return
    a = ORN_A * (np.abs(ORN_X) <= grow)[None, :].astype(np.float32) * fade
    h, w = a.shape
    comp(frame, a[..., None] * ORN_COL, a, W / 2 - w / 2, y - h / 2)
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


def _rnd(*k):
    """Número pseudo-aleatório estável em [0, 1) a partir de uma chave."""
    h = 2166136261
    for v in k:
        for ch in str(v):
            h = ((h ^ ord(ch)) * 16777619) & 0xFFFFFFFF
    return (h % 100000) / 100000.0


DUST_IN, DUST_OUT, CHAR_GAP = 0.62, 0.34, 0.035
LEAD = 0.22  # a letra começa a se formar antes da voz para ficar pronta quando a palavra é cantada  # durações (s) e atraso entre letras


def draw_lyrics(frame, t):
    """Legendas que se formam de pó de ouro: partículas convergem para cada letra, a letra
    acende do desfoque para o nítido com uma faísca; na saída, a letra se desfaz em pó que sobe."""
    dust = np.zeros((H // 2, W // 2), np.float32)
    sparks = []
    for line, words, cy, (lx0, lx1), seps in LAYOUT:
        start = words[0]["t"] - LEAD
        end = line["end"] - 0.15
        if not (start - 0.05 <= t < end + DUST_OUT + 0.1):
            continue
        vis = min(1.0, (t - start) / 0.4) * (1 - ease_io((t - end) / (DUST_OUT + 0.1)) if t > end else 1.0)
        d = ((_EX * 4 - W / 2) / (W * 0.36)) ** 2 + ((_EY * 4 - cy) / (H * 0.12)) ** 2
        sh = cv2.resize(np.exp(-d * 1.6), (W, H), interpolation=cv2.INTER_LINEAR)[..., None]
        frame *= 1 - 0.30 * vis * sh
        for sy in seps:
            draw_ornament(frame, sy, ease_out((t - start - 0.1) / 0.7, 3), vis)
        shift = {}
        for wd in words:
            e = ease_io((t - wd["t"] + LEAD) / 0.5)
            shift[wd["row"]] = shift.get(wd["row"], 0.0) + wd["step"] / 2 * (1 - e)
        nchar_line = 0
        for wd in words:
            age = t - wd["t"] + LEAD
            if age < 0:
                nchar_line += len(wd["chars"])
                continue
            spr, sz, hero = wd["spr"], wd["size"], wd["kind"] == "hero"
            x = wd["x"] + shift[wd["row"]]
            by = wd["base_y"]
            n = len(wd["chars"])
            done_in = age > CHAR_GAP * n + DUST_IN
            leaving = t > end
            if done_in and not leaving:
                # palavra pronta: desenha inteira, com o reflexo de luz nas palavras de destaque
                shimmer = None
                if hero:
                    sp = (age - CHAR_GAP * n - DUST_IN) / 1.1
                    if 0 < sp < 1:
                        shimmer = lerp(-0.3, 1.3, ease_io(sp))
                draw_sprite(frame, spr, x, by, 1.0, shimmer=shimmer)
                nchar_line += n
                continue
            for i, (cs, off) in enumerate(wd["chars"]):
                key = (wd["word"], wd["t"], i)
                ccx = x + off + cs["adv"] / 2
                ccy = by - sz * (0.38 if hero else 0.36)
                # ---- entrada
                pi_ = (age - i * CHAR_GAP) / DUST_IN
                if pi_ <= 0:
                    continue
                e = ease_out(min(pi_, 1.0), 3)
                a_char = smoothstep(0.35, 0.9, min(pi_, 1.0))
                blur = (1 - smoothstep(0.3, 1.0, min(pi_, 1.0))) * (6 if hero else 4) * SC
                dy = (1 - e) * 6 * SC
                sc_ = lerp(1.18, 1.0, e)
                # ---- saída: a letra se desfaz em pó que sobe (da esquerda para a direita)
                po = 0.0
                if leaving:
                    po = float(np.clip((t - end - (nchar_line + i) * 0.008) / DUST_OUT, 0, 1))
                    a_char *= (1 - smoothstep(0.0, 0.8, po))
                    blur += po * 5 * SC
                    dy -= po * 14 * SC
                if a_char > 0.01:
                    draw_sprite(frame, cs, x + off, by, a_char, dy=dy, blur=blur, scale=sc_)
                # ---- partículas de pó de ouro
                npart = 9 if hero else 5
                for j in range(npart):
                    r1, r2, r3 = _rnd(*key, j, "a"), _rnd(*key, j, "b"), _rnd(*key, j, "c")
                    if pi_ < 1.0:  # convergindo para a letra
                        q = min(pi_ / 0.8, 1.0)
                        ang = r1 * 6.283
                        rad = (40 + 110 * r2) * SC * (1 - ease_out(q, 2))
                        px = ccx + math.cos(ang) * rad + (r3 - 0.5) * cs["adv"] * 0.6
                        py = ccy + math.sin(ang) * rad * 0.7 + (r3 - 0.5) * sz * 0.4
                        al = math.sin(math.pi * q) * (0.9 if hero else 0.6)
                        if al > 0.02:
                            dust_dot(dust, px, py, (1.0 + 1.6 * r3) * SC, al)
                    if po > 0:  # subindo como pó
                        px = ccx + (r1 - 0.5) * cs["adv"] * 1.4 + math.sin(po * 5 + r2 * 6) * 8 * SC
                        py = ccy + (r2 - 0.5) * sz * 0.6 - po * (40 + 70 * r3) * SC
                        al = math.sin(math.pi * po) * (0.8 if hero else 0.5)
                        if al > 0.02:
                            dust_dot(dust, px, py, (1.0 + 1.4 * r3) * SC, al)
                # faísca quando a letra de destaque termina de se formar
                if hero and 0.75 < pi_ < 1.25 and _rnd(*key, "s") < 0.45:
                    k_ = 1 - abs(pi_ - 1.0) / 0.25
                    sparks.append((ccx + (_rnd(*key, "x") - 0.5) * cs["adv"] * 0.5, by - sz * 0.72, k_))
            nchar_line += n
    if dust.max() > 0:
        g = cv2.GaussianBlur(dust, (0, 0), 1.1) * 1.4 + cv2.GaussianBlur(dust, (0, 0), 4) * 0.8
        g = cv2.resize(np.clip(g, 0, 1), (W, H), interpolation=cv2.INTER_LINEAR)[..., None]
        frame[:] = 1 - (1 - frame) * (1 - g * np.float32([1.0, 0.84, 0.5]))
    for sx, sy, k_ in sparks:
        frame[:] = frame + star(sx, sy, 34 * SC * k_ + 1, k_ * 0.9)


def dust_dot(canvas, x, y, r, a):
    xi, yi = int(x / 2), int(y / 2)
    if 0 <= xi < canvas.shape[1] and 0 <= yi < canvas.shape[0]:
        cv2.circle(canvas, (xi, yi), max(1, int(round(r / 2))), float(a), -1, cv2.LINE_AA)



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


def warp_level(src, M, key):
    """Escolhe o nível de resolução adequado à escala (evita serrilhado) e aplica o warp."""
    scale = math.hypot(M[0, 0], M[1, 0])
    lv = 1 if scale < 0.6 else 0
    L = src["lv"][lv]
    Ml = M.copy()
    Ml[:, :2] /= L["f"]
    arr = L[key]
    interp = cv2.INTER_LINEAR if key == "mask" else cv2.INTER_CUBIC
    return cv2.warpAffine(arr, Ml, (W, H), flags=interp, borderMode=cv2.BORDER_REFLECT)


def warp_figure(src, Mf, dx, dy):
    """Projeta a figura na tela já com a animação (dx, dy), lendo direto da imagem original.
    Como a leitura é na imagem inteira, a animação nunca puxa pixels de fora da tela (sem cortes
    retos em mãos/braços perto da borda)."""
    scale = math.hypot(Mf[0, 0], Mf[1, 0])
    lv = 1 if scale < 0.6 else 0
    L = src["lv"][lv]
    Ml = Mf.copy()
    Ml[:, :2] /= L["f"]
    Mi = cv2.invertAffineTransform(Ml)
    X, Y = _FX - dx, _FY - dy
    sx = (Mi[0, 0] * X + Mi[0, 1] * Y + Mi[0, 2]).astype(np.float32)
    sy = (Mi[1, 0] * X + Mi[1, 1] * Y + Mi[1, 2]).astype(np.float32)
    fg = cv2.remap(L["img"], sx, sy, cv2.INTER_CUBIC, borderMode=cv2.BORDER_REFLECT)
    mk = cv2.remap(L["mask"], sx, sy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    return fg, mk


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
    sp = (18 + 55 * z) * SC
    ph = rng.random(count) * 6.28
    canvas = np.zeros((H // 2, W // 2), np.float32)
    big = np.zeros_like(canvas)
    for j in range(count):
        px = (x[j] + 22 * SC * math.sin(t * 0.7 + ph[j]) + t * 8 * SC * (z[j] - 0.4)) % W
        py = (y[j] - sp[j] * t) % H
        tw = 0.55 + 0.45 * math.sin(t * 2.4 + ph[j] * 3)
        rad = (0.6 + 2.6 * z[j]) * SC
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
        13: (0.55, 0.27, 0.075)}
_QY, _QX = np.mgrid[0:H // 4, 0:W // 4].astype(np.float32) * 4
# outros rostos na cena que também não podem deformar (Pedro, anjos, o tentador) e ganho da onda
EXTRA_RIGID = {2: [(0.55, 0.30, 0.07)], 7: [(0.22, 0.66, 0.05), (0.80, 0.68, 0.05)], 12: [(0.20, 0.20, 0.06)]}
WAVE_GAIN = {10: 0.4}
# pontos presos ao cenário (mão apoiada na parede): a figura se curva ao redor deles e o ponto
# acompanha o fundo, compensando até o parallax — a mão não escorrega
PINS = {8: [(0.09, 0.24, 0.045)]}
# braços articulados: (ombro, cotovelo, mão) normalizados na imagem, espessura (fração da largura),
# amplitude no ombro e no cotovelo (graus), período (s) e fase
ARMS = {
    3: [((0.42, 0.37), (0.38, 0.30), (0.36, 0.22), 0.035, 2.5, 4.0, 3.6, 0.0)],
    4: [((0.35, 0.25), (0.24, 0.27), (0.23, 0.10), 0.065, 2.2, 3.0, 4.2, 0.0),
        ((0.66, 0.25), (0.76, 0.27), (0.75, 0.08), 0.065, 2.2, 3.0, 4.2, 2.2)],
    7: [((0.42, 0.27), (0.36, 0.20), (0.33, 0.15), 0.040, 2.4, 3.2, 4.0, 0.5),
        ((0.57, 0.27), (0.63, 0.19), (0.66, 0.15), 0.040, 2.4, 3.2, 4.0, 2.6)],
    9: [((0.47, 0.27), (0.37, 0.25), (0.27, 0.20), 0.040, 2.6, 3.4, 4.6, 0.0),
        ((0.62, 0.28), (0.73, 0.29), (0.83, 0.29), 0.040, 2.6, 3.4, 4.6, 2.4)],
    10: [((0.43, 0.28), (0.40, 0.22), (0.395, 0.13), 0.030, 2.4, 3.0, 3.8, 0.0),
         ((0.57, 0.29), (0.60, 0.30), (0.655, 0.25), 0.030, 2.0, 2.6, 3.4, 1.8)],
    12: [((0.50, 0.27), (0.45, 0.20), (0.47, 0.10), 0.040, 2.2, 3.0, 3.9, 0.7)],
}


def _seg(X, Y, a, b):
    """Distância de cada ponto ao segmento a-b e parâmetro ao longo dele (0 em a, 1 em b)."""
    vx, vy = b[0] - a[0], b[1] - a[1]
    L2 = vx * vx + vy * vy + 1e-6
    s_ = ((X - a[0]) * vx + (Y - a[1]) * vy) / L2
    sc = np.clip(s_, 0, 1)
    return np.sqrt((X - a[0] - sc * vx) ** 2 + (Y - a[1] - sc * vy) ** 2), s_


def arm_field(shot, src, Mf, t, X, Y):
    """Braços se mexendo como ossos rígidos (ombro gira o braço todo, cotovelo gira o antebraço);
    mãos e dedos se movem inteiros, sem deformar."""
    dx = np.zeros_like(X)
    dy = np.zeros_like(Y)
    wall = np.zeros_like(X)
    scl = math.hypot(Mf[0, 0], Mf[1, 0])
    for (S, E, Hn, wd, a_sh, a_el, per, ph) in ARMS.get(shot["img"], []):
        Sp = apply_pt(Mf, S[0] * src["w"], S[1] * src["h"])
        Ep = apply_pt(Mf, E[0] * src["w"], E[1] * src["h"])
        Hp = apply_pt(Mf, Hn[0] * src["w"], Hn[1] * src["h"])
        Hx = (Hp[0] + 0.25 * (Hp[0] - Ep[0]), Hp[1] + 0.25 * (Hp[1] - Ep[1]))  # inclui os dedos
        r = wd * src["w"] * scl
        d1, s1 = _seg(X, Y, Sp, Ep)
        d2, s2 = _seg(X, Y, Ep, Hx)
        w_up = (1 - smoothstep(r, 1.9 * r, d1)) * smoothstep(-0.15, 0.45, s1)
        w_fo = 1 - smoothstep(r, 1.9 * r, d2)
        w_arm = np.maximum(w_up, w_fo)
        w_el = w_fo * smoothstep(-0.05, 0.3, s2)
        ths = math.radians(1.4 * a_sh * math.sin(2 * math.pi * t / per + ph))
        the = math.radians(1.4 * a_el * math.sin(2 * math.pi * t / per + ph - 0.9))  # cotovelo atrasado
        rx, ry = X - Sp[0], Y - Sp[1]
        dx += (math.cos(ths) * rx - math.sin(ths) * ry - rx) * w_arm
        dy += (math.sin(ths) * rx + math.cos(ths) * ry - ry) * w_arm
        rx, ry = X - Ep[0], Y - Ep[1]
        dx += (math.cos(the) * rx - math.sin(the) * ry - rx) * w_el
        dy += (math.sin(the) * rx + math.cos(the) * ry - ry) * w_el
        wall = np.maximum(wall, w_arm)
    return dx, dy, wall
_FY, _FX = _YF, _XF


def alive_field(shot, src, Mf, t, M=None):
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

    # braços articulados
    adx, ady, armw = arm_field(shot, src, Mf, t, X, Y)
    dx += adx
    dy += ady
    free = 1 - armw  # cabelo e onda da roupa não entram nos braços (mãos ficam rígidas)

    # 4) cabelo: mechas balançando com vento (raiz presa no topo da cabeça, pontas soltas);
    #    o rosto e a barba ficam rígidos
    hair_reg = 1 - smoothstep(0.85, 1.15, ((X - fx) / (2.4 * R)) ** 2 + ((Y - (fy + 1.1 * R)) / (3.4 * R)) ** 2)
    face_e = ((X - fx) / (1.05 * R)) ** 2 + ((Y - (fy + 0.3 * R)) / (1.5 * R)) ** 2
    w_hair = hair_reg * smoothstep(1.0, 1.7, face_e)
    s_len = np.clip((Y - (fy - 1.1 * R)) / (3.8 * R), 0, 1) ** 1.2 + 0.35 * np.clip(np.abs(X - fx) / (2 * R), 0, 1)
    gust = 0.6 + 0.4 * math.sin(2 * math.pi * t / 4.7 + ph)
    yh = (Y - fy) / R
    a1 = 2 * math.pi * t / 2.2 - yh / 1.3 + ph
    a2 = 2 * math.pi * t / 1.15 - yh / 0.7 + (X - fx) / (1.1 * R) + 2 * ph
    a3 = 2 * math.pi * t / 0.6 - yh / 0.35 + (X - fx) / (0.5 * R)
    amp = 0.12 * R * w_hair * s_len * gust * free
    dx += amp * (np.sin(a1) + 0.5 * np.sin(a2) + 0.22 * np.sin(a3))
    dy += amp * (0.35 * np.cos(a1) + 0.12 * np.cos(a3))

    # 5) roupa: onda que desce pelo tecido (longe do rosto)
    wc = smoothstep(2.0 * R, 4.5 * R, dist) * np.clip((Y - fy) / (5 * R), 0, 1) * WAVE_GAIN.get(shot["img"], 1.0)
    sc_ = math.hypot(Mf[0, 0], Mf[1, 0])
    for ex, ey, er in EXTRA_RIGID.get(shot["img"], []):
        qx, qy = apply_pt(Mf, ex * src["w"], ey * src["h"])
        rr = er * src["w"] * sc_
        wc = wc * smoothstep(1.2 * rr, 2.2 * rr, np.sqrt((X - qx) ** 2 + (Y - qy) ** 2))
    wave = 2 * math.pi * (Y / (7 * R) + X / (21 * R)) - 2 * math.pi * t / 2.7 + ph
    wc = wc * free
    dx += 0.055 * R * wc * np.sin(wave)
    dy += 0.018 * R * wc * np.cos(wave * 0.8)

    # 6) pontos presos: anula a animação perto do ponto e o leva para onde o fundo está
    for pxn, pyn, prn in PINS.get(shot["img"], []):
        fpx, fpy = apply_pt(Mf, pxn * src["w"], pyn * src["h"])
        bpx, bpy = apply_pt(M, pxn * src["w"], pyn * src["h"]) if M is not None else (fpx, fpy)
        rr = prn * src["w"] * math.hypot(Mf[0, 0], Mf[1, 0])
        dd = np.sqrt((X - bpx) ** 2 + (Y - bpy) ** 2)  # o remap é inverso: centra no destino
        hold = 1 - smoothstep(rr, 7 * rr, dd)
        dx = dx * (1 - hold) + (bpx - fpx) * hold
        dy = dy * (1 - hold) + (bpy - fpy) * hold
    return dx, dy


# ---------------------------------------------------------------- ambiente vivo
# zonas por imagem (caixas normalizadas na imagem): o fundo se mexe conforme o tipo
#   sky   = nuvens derivando com o vento e mudando de forma devagar
#   water = ondas que correm, com brilhos de luz que piscam na superfície
#   sway  = folhas, galhos, flores e capim balançando
#   haze  = névoa / calor tremulando no horizonte
ENV = {
    1: [("sky", 0, 0, 1, 0.60), ("haze", 0, 0.52, 1, 0.70)],
    2: [("water", 0, 0, 1, 1)],
    3: [("sky", 0, 0, 1, 0.55)],
    4: [("sky", 0, 0, 1, 1)],
    5: [("sky", 0.25, 0, 1, 0.42)],
    6: [("sky", 0, 0, 1, 0.75)],
    8: [("sway", 0.70, 0.0, 1.0, 0.80)],
    9: [("sky", 0, 0, 1, 1)],
    10: [("sky", 0, 0, 1, 0.45)],
    11: [("sky", 0.30, 0, 1, 0.42), ("haze", 0.45, 0.40, 1, 0.80), ("sway", 0, 0, 0.32, 0.55),
         ("sway", 0, 0.70, 0.5, 1)],
    12: [("sky", 0, 0, 1, 0.60)],
    13: [("sky", 0, 0, 1, 0.45), ("sway", 0.55, 0.62, 1, 1)],
}


def _box(sx, sy, x0, y0, x1, y1, fe=0.05):
    return (smoothstep(x0 - fe, x0 + fe, sx) * (1 - smoothstep(x1 - fe, x1 + fe, sx)) *
            smoothstep(y0 - fe, y0 + fe, sy) * (1 - smoothstep(y1 - fe, y1 + fe, sy)))


def _periodic_noise(n, seed, beta=1.7):
    """Ruído fractal que se repete sem emenda (filtrado no espectro), valores ~[-1, 1]."""
    rng = np.random.default_rng(seed)
    f = np.fft.fftfreq(n)[:, None] ** 2 + np.fft.fftfreq(n)[None, :] ** 2
    f[0, 0] = 1
    spec = (rng.standard_normal((n, n)) + 1j * rng.standard_normal((n, n))) / f ** (beta / 2)
    spec[0, 0] = 0
    x = np.real(np.fft.ifft2(spec)).astype(np.float32)
    return x / (np.abs(x).max() + 1e-6)


NOISE_N = 256
NOISE = [_periodic_noise(NOISE_N, s_) for s_ in (11, 29, 47)]


def tex(T, u, v):
    """Amostra o ruído periódico nas coordenadas (u, v) em unidades de repetição."""
    return cv2.remap(T, (u * NOISE_N).astype(np.float32), (v * NOISE_N).astype(np.float32),
                     cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)


def env_field(shot, src, M, t):
    """Deslocamento (dx, dy) e sombreamento do fundo, em 1/4 da resolução da tela."""
    zones = ENV.get(shot["img"])
    if not zones:
        return None
    Mi = cv2.invertAffineTransform(M)
    sx = (Mi[0, 0] * _QX + Mi[0, 1] * _QY + Mi[0, 2]) / src["w"]
    sy = (Mi[1, 0] * _QX + Mi[1, 1] * _QY + Mi[1, 2]) / src["h"]
    asp = src["h"] / src["w"]
    dx = np.zeros_like(_QX)
    dy = np.zeros_like(_QX)
    shade = np.zeros_like(_QX)
    tau = 2 * math.pi
    tm = t - (shot["t0"] + shot["t1"]) / 2
    for kind, x0, y0, x1, y1 in zones:
        w = _box(sx, sy, x0, y0, x1, y1)
        if kind == "sky":
            # turbulência lenta (as nuvens mudam de forma) + deriva com o vento
            u, v = sx * 1.2, sy * 1.2 * asp
            n1 = tex(NOISE[0], u + t * 0.020, v + t * 0.006)
            n2 = tex(NOISE[1], u * 2.1 - t * 0.030, v * 2.1 + t * 0.010)
            A = 9 * SC
            dx += w * (A * (n1 + 0.5 * n2) + 12 * SC * tm)
            dy += w * A * 0.5 * (n2 - 0.4 * n1)
            shade += w * 0.025 * n2
        elif kind == "water":
            # ondulação orgânica: ruído esticado na horizontal correndo em direção à câmera,
            # duas camadas cruzadas; brilhos onde as cristas se encontram
            depth = 0.5 + 0.8 * np.clip(sy, 0, 1)
            u, v = sx * 2.2, sy * 2.2 * asp
            n1 = tex(NOISE[0], u * 0.9 + t * 0.03, v * 3.2 - t * 0.22)
            n2 = tex(NOISE[1], u * 1.7 - t * 0.05, v * 5.0 - t * 0.35)
            n3 = tex(NOISE[2], u * 4.0 + t * 0.07, v * 9.0 - t * 0.55)
            A = 6.5 * SC * depth
            dy += w * A * (n1 + 0.55 * n2 + 0.25 * n3)
            dx += w * A * 0.45 * (n2 - 0.5 * n3)
            crest = np.clip(n2 + 0.6 * n3 - 0.55, 0, 1)
            shade += w * (0.035 * n1 + 0.30 * crest ** 2 * depth)
        elif kind == "sway":
            A = 7 * SC
            n1 = tex(NOISE[2], sx * 2 + t * 0.15, sy * 2 * asp)
            p1 = tau * t / 2.4 + sx * 3.0
            p2 = tau * t / 0.9 + sy * 12 + sx * 5
            dx += w * A * (np.sin(p1) * (0.7 + 0.3 * n1) + 0.35 * np.sin(p2))
            dy += w * A * 0.3 * np.cos(p1 * 1.1)
        elif kind == "haze":
            n1 = tex(NOISE[1], sx * 6 + t * 0.05, sy * 30 * asp - t * 0.8)
            dx += w * (2.2 * SC * n1 + 6 * SC * tm)
            shade += w * 0.02 * n1
    return dx, dy, shade


def animate_env(bg, shot, src, M, t):
    fld = env_field(shot, src, M, t)
    if fld is None:
        return bg
    dx, dy, shade = (cv2.resize(a, (W, H), interpolation=cv2.INTER_LINEAR) for a in fld)
    bg = cv2.remap(bg, _FX - dx, _FY - dy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    return np.clip(bg * (1 + shade[..., None]), 0, 1)


# ---------------------------------------------------------------- feixe de luz animado (imagem 13)
BEAM_QUAD = [(0.67, 0.0), (0.79, 0.0), (0.87, 0.70), (0.58, 0.70)]  # normalizado na imagem
BEAM_GLOW = (0.70, 0.31)  # onde a luz toca o rosto


def light_beam(M, src, t, seed):
    """Luz que desce do céu: raios internos que ondulam, faixas de brilho descendo,
    partículas caindo dentro do feixe, respiração da intensidade e pulso nas batidas."""
    pts = np.float32([apply_pt(M, x * src["w"], y * src["h"]) for x, y in BEAM_QUAD]) / 2
    canvas = np.zeros((H // 2, W // 2), np.float32)
    cv2.fillConvexPoly(canvas, pts.astype(np.int32), 1.0, cv2.LINE_AA)
    mask = cv2.GaussianBlur(canvas, (0, 0), 16 * SC)
    tc, bc = (pts[0] + pts[1]) / 2, (pts[2] + pts[3]) / 2
    axis = bc - tc
    Lb = float(np.hypot(*axis)) + 1e-3
    d = axis / Lb
    nrm = np.float32([-d[1], d[0]])
    hw0, hw1 = float(np.hypot(*(pts[1] - pts[0]))) / 2, float(np.hypot(*(pts[2] - pts[3]))) / 2
    rx, ry = _XX - tc[0], _YY - tc[1]
    along = (rx * d[0] + ry * d[1]) / Lb
    across = (rx * nrm[0] + ry * nrm[1]) / (hw0 + (hw1 - hw0) * np.clip(along, 0, 1))
    # raios finos dentro do feixe que ondulam devagar
    u = (across * 0.5 + 0.5) * 140 + 30 * math.sin(t * 0.35 + seed) + seed * 13
    i0 = np.floor(u).astype(np.int32)
    fr = u - i0
    nz = RAY_NOISE[i0 % 720] * (1 - fr) + RAY_NOISE[(i0 + 1) % 720] * fr
    streak = smoothstep(0.25, 1.0, nz)
    # faixas de brilho descendo pelo feixe
    bands = 0.5 + 0.5 * np.sin(2 * math.pi * (along * 3.2 - t * 0.55))
    breath = 0.85 + 0.15 * math.sin(2 * math.pi * t / 2.6) + 4 * beat_env(t)
    lay = mask * (0.10 + 0.40 * streak * (0.5 + 0.5 * bands)) * breath
    # partículas de luz caindo dentro do feixe
    rng = np.random.default_rng(seed + 7)
    motes = np.zeros_like(canvas)
    for j in range(55):
        a0, c0, sp, sz = rng.random(), rng.random() * 2 - 1, 0.06 + 0.10 * rng.random(), rng.random()
        al = (a0 + t * sp) % 1.0
        hw = hw0 + (hw1 - hw0) * al
        p = tc + axis * al + nrm * (c0 * 0.85 * hw + 6 * SC * math.sin(t * 1.3 + j))
        tw = 0.5 + 0.5 * math.sin(t * 3 + j * 1.7)
        cv2.circle(motes, (int(p[0]), int(p[1])), 1 + int(sz * 2.2 * SC), float(0.5 + 0.5 * tw), -1, cv2.LINE_AA)
    lay = lay + cv2.GaussianBlur(motes, (0, 0), 1.3) * mask * 1.4
    # brilho onde a luz toca o rosto
    gx, gy = apply_pt(M, BEAM_GLOW[0] * src["w"], BEAM_GLOW[1] * src["h"])
    r = np.sqrt((_XX - gx / 2) ** 2 + (_YY - gy / 2) ** 2) / (H / 2)
    lay = lay + np.exp(-r * 9) * 0.18 * breath
    lay = cv2.resize(np.clip(lay, 0, 1), (W, H), interpolation=cv2.INTER_LINEAR)[..., None]
    return lay * np.array([1.0, 0.93, 0.76], np.float32)


# ---------------------------------------------------------------- render de um plano
def render_shot(shot, f, tx=None):
    """Renderiza o plano no frame f (pode ser antes/depois do plano, durante transições).
    tx: transformação extra de tela vinda da transição (scale, dx, dy, rot)."""
    src = IMGS[shot["img"]]
    n = shot["f1"] - shot["f0"]
    lf = (f - shot["f0"]) / R30  # em quadros de 30 fps (pode ser fracionário)
    n = n / R30
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
    off = [SC * (5 * math.sin(t * 0.73 + sd) + 3 * math.sin(t * 1.9 + sd * 2)),
           SC * (4 * math.sin(t * 0.61 + sd * 3) + 2 * math.sin(t * 1.7 + sd))]
    rot = 0.22 * math.sin(t * 0.45 + sd)
    extra, rblur, flash = 1.0, 0.0, 0.0
    for b, st in PULSES:
        d = t - b
        if 0 <= d < 0.28:
            extra *= 1 + (0.010 + 0.022 * st) * (1 - d / 0.28) ** 2

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
    k = 1 + PAR_GAIN * shot.get("par", 0.04) * ease_io(u)
    lat = LAT_GAIN * shot.get("lat", 0.0) * (min(max(u, -0.2), 1.2) - 0.5) * W
    Pm = np.float32([[k, 0, (1 - k) * pvx + lat], [0, k, (1 - k) * pvy]])
    Mf = (Pm[:, :2] @ M).astype(np.float32)
    Mf[:, 2] += Pm[:, 2]

    bg = warp_level(src, M, "bg").astype(np.float32) / 255
    bg = animate_env(bg, shot, src, M, t)  # céu, água, vegetação e névoa em movimento
    if cut == "intro":
        bg = draw_god(bg, M, t)
    fxn_, fyn_, _ = FACE[shot["img"]]
    LAST_FACE[0] = apply_pt(Mf, fxn_ * src["w"], fyn_ * src["h"])
    adx, ady = alive_field(shot, src, Mf, t, M)  # Jesus "vivo"
    adx = cv2.resize(adx, (W, H), interpolation=cv2.INTER_LINEAR)
    ady = cv2.resize(ady, (W, H), interpolation=cv2.INTER_LINEAR)
    fg, mk = warp_figure(src, Mf, adx, ady)
    fg = fg.astype(np.float32) / 255
    mk = (mk.astype(np.float32) / 255)[..., None]

    rays = None
    if shot.get("rays"):
        rx, ry, rs = shot["rays"]
        ox, oy = apply_pt(M, rx * src["w"], ry * src["h"])
        rays = np.clip(god_rays(ox, oy, t, sd, rs), 0, 1)
        bg = 1 - (1 - bg) * (1 - rays)
    frame = bg * (1 - mk) + fg * mk

    if shot.get("clouds"):
        tex = CLOUDS[shot["clouds"]]
        rise = (1 - ease_out(min(max(u, 0), 1), 2)) * 60 * SC if shot["clouds"] != "intro" else 0
        for li, (layer, spd) in enumerate(zip(tex, (32 * SC, 60 * SC))):
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
    if shot.get("beam"):
        frame = 1 - (1 - frame) * (1 - 0.5 * light_beam(M, src, t, sd))
    if rblur > 0:
        frame = radial_blur(frame, rblur, W / 2, H * 0.4)
    if flash > 0:
        frame = frame + (1 - frame) * flash * np.array([1.0, 0.94, 0.82], np.float32)
    return frame


# ---------------------------------------------------------------- transições
# janela (quadros de 30 fps antes, depois do corte); o corte (impacto) cai na batida
TWIN = {"burn": (18, 20), "iris": (14, 22), "cloud": (21, 21), "flare": (17, 17), "smoke": (22, 22),
        "bloom": (13, 20), "punch": (0, 8)}
LAST_FACE = [None]  # posição do rosto de Jesus na tela no último plano renderizado


def chroma(img, amt):
    """Aberração cromática radial (separa R e B do centro para as bordas)."""
    if amt < 0.3:
        return img
    out = img.copy()
    for c, s in ((0, 1 + amt / W), (2, 1 - amt / W)):
        M = np.float32([[s, 0, (1 - s) * W / 2], [0, s, (1 - s) * H / 2]])
        out[..., c] = cv2.warpAffine(img[..., c], M, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    return out


def shake(e, seed):
    """Tremor de impacto que decai (dx, dy, rot)."""
    a = (1 - e) ** 2
    return dict(dx=14 * SC * a * math.sin(seed * 7.1 + e * 40), dy=10 * SC * a * math.sin(seed * 3.3 + e * 33),
                rot=0.5 * a * math.sin(seed * 5.7 + e * 37))


def _scr_noise(seed, t, scale=2.2, speed=0.05):
    """Ruído orgânico em coordenadas de tela (1/4 da resolução), animado."""
    u = _QX / W * scale + t * speed + seed * 0.37
    v = _QY / H * scale * H / W + seed * 0.61
    n = tex(NOISE[seed % 3], u, v) * 0.65 + tex(NOISE[(seed + 1) % 3], u * 2.3 - t * speed, v * 2.3) * 0.35
    return cv2.resize(n, (W, H), interpolation=cv2.INTER_LINEAR)


def _mix(a, b, w):
    return a * (1 - w[..., None]) + b * w[..., None]


def transition_frame(f):
    """Se f cai na janela de uma transição, devolve o frame composto; senão None."""
    t = f / FPS
    for k in range(1, len(SHOTS)):
        B = SHOTS[k]
        typ = B["cut"]
        pre, post = (v * R30 for v in TWIN.get(typ, (0, 0)))
        pre = min(pre, 0.45 * (SHOTS[k - 1]["f1"] - SHOTS[k - 1]["f0"]))
        post = min(post, 0.45 * (B["f1"] - B["f0"]))
        c = B["f0"]
        if not (c - pre <= f < c + post):
            continue
        A = SHOTS[k - 1]
        p = (f - (c - pre) + 0.5) / (pre + post)  # 0..1 ao longo da janela
        m = pre / (pre + post)                    # ponto do corte (na batida)
        pk = math.exp(-((p - m) / 0.18) ** 2)     # pico de intensidade no corte

        if typ == "burn":
            # queima de filme: a cena nova "queima" a antiga a partir de um canto, borda incandescente
            fa = render_shot(A, f, dict(scale=1 + 0.03 * p))
            fb = render_shot(B, f, dict(scale=1.04 - 0.04 * p))
            corner = (k * 0.37) % 1.0
            grad = np.clip((_XF / W) * (0.6 + 0.4 * corner) + (_YF / H) * (1.0 - 0.4 * corner), 0, 2) / 1.6
            fld = 0.75 * (1 - grad) + 0.25 * (_scr_noise(k, t, 1.6, 0.08) * 0.5 + 0.5)
            th = lerp(1.15, -0.15, ease_io(p))
            w = smoothstep(th - 0.03, th + 0.03, fld)
            edge = np.exp(-((fld - th) / 0.035) ** 2)
            fr = _mix(fa, fb, w)
            glow = cv2.GaussianBlur(edge, (0, 0), 18 * SC) * 0.9 + edge * 0.6
            fr = 1 - (1 - fr) * (1 - np.clip(glow, 0, 1)[..., None] * np.float32([1.0, 0.68, 0.30]))
            return fr + (edge[..., None] * 0.35) * np.float32([1.0, 0.88, 0.6])

        if typ == "iris":
            # íris dourada: círculo de luz se abre a partir do rosto de Jesus na cena nova
            fb = render_shot(B, f, dict(scale=1.06 - 0.06 * ease_out(p, 2)))
            cx, cy = LAST_FACE[0] or (W / 2, H * 0.38)
            fa = render_shot(A, f, dict(scale=1 + 0.08 * ease_io(p)))
            R = math.hypot(max(cx, W - cx), max(cy, H - cy)) * 1.05
            q = max(0.0, (p - m * 0.6) / (1 - m * 0.6))
            r = R * ease_io(q) ** 1.3
            d = np.sqrt((_XF - cx) ** 2 + (_YF - cy) ** 2)
            soft = 30 * SC + 0.08 * r
            w = 1 - smoothstep(r - soft, r + soft, d)
            fr = _mix(fa, fb, w)
            ring = np.exp(-((d - r) / (14 * SC + 0.03 * r)) ** 2) * math.sin(math.pi * min(q * 1.2, 1.0))
            halo = cv2.GaussianBlur(ring, (0, 0), 22 * SC)
            fr = 1 - (1 - fr) * (1 - np.clip(ring * 0.9 + halo * 1.2, 0, 1)[..., None] * np.float32([1.0, 0.84, 0.5]))
            return fr

        if typ == "cloud":
            # passagem de nuvens: um banco de nuvens atravessa a tela e a cena troca por trás dele
            pos = lerp(1.45, -0.45, ease_io(p))
            fa = render_shot(A, f, dict(dx=-60 * SC * ease_io(p)))
            fb = render_shot(B, f, dict(dx=60 * SC * (1 - ease_io(p))))
            n = _scr_noise(k + 5, t, 2.6, 0.03)
            xn = _XF / W + 0.18 * n + 0.06 * np.sin(_YF / H * 6 + k)
            w = (xn > pos).astype(np.float32)
            w = cv2.GaussianBlur(w, (0, 0), 25 * SC)
            fr = _mix(fa, fb, w)  # atrás da frente de nuvens (lado direito) já é a cena nova
            dens = np.clip(1.3 - np.abs(xn - pos) * 3.0 + 0.35 * n, 0, 1) ** 1.2
            shade = 0.82 + 0.18 * (_scr_noise(k + 9, t, 5.0, 0.06) * 0.5 + 0.5) - 0.08 * (_YF / H)
            col = np.dstack([shade, shade * 0.96, shade * 0.9]).astype(np.float32)
            return _mix(fr, col, dens)

        if typ == "flare":
            # raio de luz: faixa dourada diagonal com brilho de lente varre a tela e troca a cena
            fa = render_shot(A, f)
            fb = render_shot(B, f, dict(scale=1.03 - 0.03 * p))
            pos = lerp(-0.35, 1.35, ease_io(p))
            dd = (_XF / W) * 0.8 + (_YF / H) * 0.35 - pos * 1.15
            w = smoothstep(0.04, -0.04, dd)
            fr = _mix(fa, fb, w)
            band = np.exp(-(dd / 0.05) ** 2)
            core = np.exp(-(dd / 0.012) ** 2)
            fr = 1 - (1 - fr) * (1 - np.clip(band * 0.85, 0, 1)[..., None] * np.float32([1.0, 0.82, 0.45]))
            fr = fr + core[..., None] * 0.7
            # streak anamórfico horizontal pela tela, no centro da faixa
            sy = H * (0.2 + 0.6 * ease_io(p))
            streak = np.exp(-((_YF - sy) / (6 * SC)) ** 2) * (0.35 + 0.65 * np.exp(-(dd / 0.15) ** 2)) * pk
            fr = fr + streak[..., None] * np.float32([0.55, 0.75, 1.0]) * 0.55
            return chroma(fr, 10 * SC * pk)

        if typ == "smoke":
            # fumaça: dissolve orgânico com bordas de fumaça e leve desfoque nas bordas da troca
            fa = render_shot(A, f, dict(scale=1 + 0.03 * p, dy=-10 * SC * p))
            fb = render_shot(B, f, dict(scale=1.03 - 0.03 * p, dy=10 * SC * (1 - p)))
            fld = _scr_noise(k + 2, t, 0.9, 0.10) * 0.35 + 0.5 + 0.15 * (_XF / W - 0.5)
            th = lerp(1.0, 0.0, ease_io(p))
            w = smoothstep(th - 0.18, th + 0.18, fld)
            edge = np.exp(-((fld - th) / 0.08) ** 2)
            fr = _mix(fa, fb, w)
            soft = cv2.GaussianBlur(fr, (0, 0), 8 * SC)
            fr = _mix(fr, soft, np.clip(edge * 0.9, 0, 1))
            return 1 - (1 - fr) * (1 - (edge * 0.18)[..., None] * np.float32([1.0, 0.92, 0.78]))

        if typ == "bloom":
            # clarão: a cena se desfaz em luz dourada e a próxima nasce dela
            if p < m:
                q = p / m
                fr = render_shot(A, f, dict(scale=1 + 0.05 * q ** 2))
                g = q ** 1.6
            else:
                q = (p - m) / (1 - m)
                fr = render_shot(B, f, dict(scale=1 + 0.05 * (1 - ease_out(q, 2))))
                g = (1 - ease_out(q, 2))
            sm = cv2.resize(fr, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
            bl = cv2.resize(cv2.GaussianBlur(sm, (0, 0), 6), (W, H), interpolation=cv2.INTER_LINEAR)
            fr = _mix(fr, bl, np.full((H, W), 0.6 * g, np.float32))
            fr = 1 - (1 - np.clip(fr, 0, 1)) ** (1 + 3.5 * g)
            return fr + (1 - fr) * 0.5 * g * np.float32([1.0, 0.9, 0.7])

        if typ == "punch":
            q = p
            tx = shake(q, k)
            tx["scale"] = 1 + 0.12 * (1 - ease_out(q, 3))
            fr = render_shot(B, f, tx)
            return chroma(fr, 10 * SC * (1 - q))
        return None
    return None


def beat_env(t):
    v = 0.0
    for b, st in PULSES:
        d = t - b
        if 0 <= d < 0.22:
            v = max(v, 0.055 * st * (1 - d / 0.22) ** 2)
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
        frame = frame * (1 - ease_io(max(0.0, (f - (shot["f1"] - 10 * R30)) / (9 * R30))))
    return (np.clip(np.nan_to_num(frame), 0, 1) * 255 + 0.5).astype(np.uint8)


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
        fs = list(range(0, NFRAMES, FPS // 2))
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

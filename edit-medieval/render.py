#!/usr/bin/env python3
"""Edit cinematográfica medieval (16:9, HD) no estilo 2.5D da edit de Jesus (edit-jesus/).

Pipeline: cada pintura (upscale 4x Real-ESRGAN em refs_hd/) é separada em personagens (máscara)
+ fundo (inpaint) para parallax 2.5D e animada por uma câmera virtual. Os personagens ganham vida
como na edit de Jesus: cabeça girando rígida em torno do pescoço (rosto não deforma), respiração,
balanço do corpo, braços articulados (ombro e cotovelo, mãos inteiras), cabelo em mechas com vento
e tecido ondulando. O ambiente se mexe (céu, folhagem, relva, névoa) e recebe estrelas cintilando,
raios de luz, brilho metálico, chuva, relâmpagos, vagalumes e pétalas.
Cortes, pulsos de zoom/luz e gestos ficam presos às batidas da música.

Uso:  python3 render.py AUDIO [saida.mp4]
      python3 render.py AUDIO saida.mp4 --stills 1.5,6.8      (quadros de teste)
"""
import math
import os
import subprocess
import sys
from multiprocessing import Pool

import cv2
import numpy as np

ROOT = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1920, 1080, 60
SC = W / 1440            # escala dos tamanhos em pixel (referência 1440 px, como na edit de Jesus)
R30 = FPS / 30           # quadros de saída por quadro de 30 fps
DUR = 21.05
NFRAMES = int(round(DUR * FPS))
BEAT = 0.3548            # colcheia da música (≈84,6 BPM); compasso = 8 colcheias
BAR = 8 * BEAT

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
    """Banco de nuvens (RGBA) mais denso embaixo (ou em cima, com top < 0). top/soft em fração da altura."""
    n = fbm(h, w, seed, base=3, octaves=7)
    n2 = fbm(h, w, seed + 7, base=5, octaves=5)
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    bias = (y - top) / soft if top >= 0 else ((-top) - y) / soft
    d = smoothstep(0.30, 0.80, n * 0.7 + n2 * 0.3 + bias * 0.55 - 0.25)
    d = cv2.GaussianBlur(d, (0, 0), 2.5)
    db = cv2.GaussianBlur(d, (0, 0), 14)
    light = np.clip(1.02 - 0.12 * db + 0.08 * (n2 - 0.5), 0.86, 1.05)
    rgb = np.array(tint, np.float32) * light[..., None]
    return np.dstack([np.clip(rgb, 0, 1), d]).astype(np.float32)


# ---------------------------------------------------------------- assets
PAR_GAIN, LAT_GAIN = 0.6, 0.5


def load_image(name):
    """Pintura HD (Real-ESRGAN) + máscara dos personagens + fundo inpaint + estrelas, em 2 níveis."""
    hd_path = os.path.join(ROOT, "refs_hd", f"{name}.png")
    orig = cv2.imread(os.path.join(ROOT, "refs", f"{name}.jpg"))
    if os.path.exists(hd_path):
        img = cv2.imread(hd_path)
    else:  # sem o upscale: Lanczos 4x
        img = cv2.resize(orig, None, fx=4, fy=4, interpolation=cv2.INTER_LANCZOS4)
    img = img[:, :, ::-1].copy()
    h, w = img.shape[:2]
    m = cv2.imread(os.path.join(ROOT, "mascaras", f"{name}.png"), cv2.IMREAD_GRAYSCALE)
    mk = cv2.resize(m, (w, h), interpolation=cv2.INTER_CUBIC).astype(np.float32) / 255
    mk = np.clip((mk - 0.08) / 0.8, 0, 1)
    # fundo sem os personagens: inpaint na resolução original, revelado só nas bordas do parallax
    dil = cv2.dilate((m > 20).astype(np.uint8) * 255, np.ones((15, 15), np.uint8))
    inp = cv2.inpaint(orig, dil, 12, cv2.INPAINT_TELEA)[:, :, ::-1]
    inp = cv2.GaussianBlur(inp, (0, 0), 3)
    inp = cv2.resize(inp, (w, h), interpolation=cv2.INTER_CUBIC).astype(np.float32)
    dm = cv2.GaussianBlur(cv2.resize(dil, (w, h)).astype(np.float32) / 255, (0, 0), 20)[..., None]
    bg = img.astype(np.float32) * (1 - dm) + inp * dm
    # estrelas: picos de luz no céu (fora dos personagens) + fase aleatória para cintilar
    lum = img.astype(np.float32).mean(2) / 255
    sw_ = max(3, w // 300)
    star = np.clip(lum - cv2.GaussianBlur(lum, (0, 0), sw_) - 0.05, 0, 1) * 3 * (1 - cv2.dilate(mk, np.ones((9, 9))))
    star *= smoothstep(0.55, 0.3, cv2.GaussianBlur(lum, (0, 0), 30))  # só onde o céu é escuro
    phase = cv2.resize(np.random.default_rng(len(name)).random((h // 12 + 1, w // 12 + 1)).astype(np.float32),
                       (w, h), interpolation=cv2.INTER_NEAREST)
    fx = (np.dstack([np.clip(star, 0, 1), phase]) * 255).astype(np.uint8)
    ys, xs = np.nonzero(mk > 0.5)
    d = dict(w=w, h=h, bbox=(xs.min(), ys.min(), xs.max(), ys.max()))
    d["lv"] = []
    for lvl in range(2):
        f = 0.5 ** lvl
        rs = (lambda a: a) if lvl == 0 else (lambda a: cv2.resize(a, (w // 2, h // 2), interpolation=cv2.INTER_AREA))
        d["lv"].append(dict(img=rs(img), bg=rs(np.clip(bg, 0, 255).astype(np.uint8)),
                            mask=rs((mk * 255).astype(np.uint8)), fx=rs(fx), f=f))
    return d


NAMES = ["01-varanda-rosa", "02-varanda-lua", "03-juramento-castelo", "04-abraco-elmo",
         "05-tempestade", "06-armadura-relva", "07-armadura-flores"]
print("carregando imagens…", flush=True)
IMGS = {k + 1: load_image(n) for k, n in enumerate(NAMES)}

CLOUDS = {
    "storm": [make_cloud_texture(W * 2, H, 41, -0.42, 0.20, (0.42, 0.46, 0.52)),
              make_cloud_texture(W * 2, H, 47, -0.30, 0.16, (0.34, 0.37, 0.43))],
    "warm": [make_cloud_texture(W * 2, H, 31, 0.90, 0.14, (1.0, 0.86, 0.66)),
             make_cloud_texture(W * 2, H, 37, 0.96, 0.10, (0.98, 0.82, 0.62))],
}
_rng = np.random.default_rng(5)
RAY_NOISE = cv2.GaussianBlur(_rng.random((1, 720)).astype(np.float32), (0, 0), 2.2)[0]
RAY_NOISE = (RAY_NOISE - RAY_NOISE.min()) / (RAY_NOISE.max() - RAY_NOISE.min())
_YY, _XX = np.mgrid[0:H // 2, 0:W // 2].astype(np.float32)
_YF, _XF = np.mgrid[0:H, 0:W].astype(np.float32)
_FY, _FX = _YF, _XF
_QY, _QX = np.mgrid[0:H // 4, 0:W // 4].astype(np.float32) * 4
_r = np.sqrt(((_XF - W / 2) / (W / 2)) ** 2 + ((_YF - H / 2) / (H / 2)) ** 2) / math.sqrt(2)
VIGNETTE = (1 - 0.34 * smoothstep(0.45, 1.0, _r))[..., None]
del _r

# ---------------------------------------------------------------- roteiro
# a=(cx, cy, w) início, b=(cx, cy, w) fim: centro normalizado e fração da largura enquadrada
# cut: transição de ENTRADA: fade | iris | cloud | flare | smoke | burn | bloom | punch
# par: quanto os personagens aproximam além do fundo · lat: travelling lateral (parallax)
S = lambda **k: k  # noqa: E731
SHOTS = [
    S(img=1, t0=0.00, t1=3.98, a=(0.60, 0.30, 1.00), b=(0.45, 0.39, 0.62), cut="fade",
      particles=55, pcol=(1.0, 0.86, 0.55), par=0.07, lat=0.012, petals=(0.47, 0.33)),
    S(img=2, t0=3.98, t1=5.76, a=(0.55, 0.26, 1.00), b=(0.48, 0.38, 0.92), cut="iris",
      particles=60, pcol=(1.0, 0.88, 0.6), par=0.07, lat=-0.012),
    S(img=2, t0=5.76, t1=6.82, a=(0.74, 0.43, 0.42), b=(0.75, 0.42, 0.36), cut="punch",
      particles=30, pcol=(1.0, 0.88, 0.6), par=0.04),
    S(img=3, t0=6.82, t1=9.66, a=(0.46, 0.27, 1.00), b=(0.50, 0.52, 0.78), cut="cloud",
      rays=(0.10, 0.06, 0.26), particles=45, pcol=(1.0, 0.93, 0.78), par=0.07, lat=0.012),
    S(img=4, t0=9.66, t1=10.72, a=(0.48, 0.38, 1.00), b=(0.50, 0.40, 0.90), cut="flare",
      particles=35, par=0.05, lat=-0.010),
    S(img=4, t0=10.72, t1=12.50, a=(0.52, 0.42, 0.62), b=(0.54, 0.44, 0.54), cut="punch",
      particles=30, par=0.04),
    S(img=5, t0=12.50, t1=13.55, a=(0.55, 0.52, 1.00), b=(0.50, 0.50, 0.94), cut="burn",
      clouds="storm", rays=(0.66, 0.46, 0.20), particles=30, pcol=(0.85, 0.92, 1.0), par=0.07,
      lat=0.012, rain=True),
    S(img=5, t0=13.55, t1=15.34, a=(0.58, 0.58, 0.56), b=(0.55, 0.55, 0.66), cut="punch",
      clouds="storm", rays=(0.66, 0.46, 0.20), particles=25, pcol=(0.85, 0.92, 1.0), par=0.05,
      rain=True),
    S(img=6, t0=15.34, t1=18.18, a=(0.45, 0.48, 0.80), b=(0.52, 0.50, 0.96), cut="smoke",
      particles=50, pcol=(1.0, 0.95, 0.8), par=0.05, lat=-0.012, rot=(2.0, -1.5)),
    S(img=7, t0=18.18, t1=21.05, a=(0.45, 0.62, 1.00), b=(0.60, 0.36, 0.74), cut="bloom",
      clouds="warm", rays=(0.06, 0.04, 0.34), particles=80, pcol=(1.0, 0.82, 0.5), par=0.06,
      lat=0.010),
]
# batidas (tempo, força) medidas na música: pulso de zoom + pulso de luz proporcionais à força
PULSES = [(1.14, 1.0), (1.51, 0.7), (2.21, 1.0), (2.54, 0.55), (2.90, 0.9), (3.62, 0.7),
          (3.98, 0.9), (4.33, 0.95), (5.03, 0.75), (5.39, 0.75), (5.76, 0.9), (6.12, 0.85),
          (6.48, 1.1), (7.19, 0.65), (7.52, 0.7), (8.23, 0.8), (8.59, 0.65), (9.30, 0.9),
          (9.65, 0.7), (10.02, 0.85), (10.37, 0.9), (10.72, 0.9), (11.42, 0.7), (12.14, 0.6),
          (12.48, 0.55), (13.55, 0.8), (14.61, 0.55), (15.66, 0.65), (16.70, 0.45), (18.52, 0.6),
          (18.89, 0.8), (19.23, 0.55), (19.95, 0.6)]
LIGHTNING = [12.52, 12.70, 13.55, 13.66, 14.95]
for k, s in enumerate(SHOTS):
    s["f0"], s["f1"] = int(round(s["t0"] * FPS)), int(round(s["t1"] * FPS))
    s["seed"] = 100 + k
    s["idx"] = k


# ---------------------------------------------------------------- câmera e efeitos
def camera_matrix(src, cx, cy, wf, rot_deg, extra_scale, off):
    cw = min(wf, 1.0, src["h"] / (src["w"] * H / W)) * src["w"]
    ch = cw * H / W
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
    interp = cv2.INTER_LINEAR if key in ("mask", "fx") else cv2.INTER_CUBIC
    return cv2.warpAffine(L[key], Ml, (W, H), flags=interp, borderMode=cv2.BORDER_REFLECT)


def warp_figure(src, Mf, dx, dy):
    """Projeta os personagens na tela já com a animação (dx, dy), lendo direto da imagem HD."""
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


def god_rays(ox, oy, t, seed, strength):
    ang = np.arctan2(_YY - oy / 2, _XX - ox / 2)
    r = np.sqrt((_XX - ox / 2) ** 2 + (_YY - oy / 2) ** 2) / (H / 2)
    u = (ang / (2 * math.pi) + 0.5) * 720 + t * 6 + seed * 37
    i0 = np.floor(u).astype(np.int32)
    fr = u - i0
    nz = RAY_NOISE[i0 % 720] * (1 - fr) + RAY_NOISE[(i0 + 1) % 720] * fr
    rays = smoothstep(0.35, 1.0, nz) * np.exp(-r * 1.25) * smoothstep(0.0, 0.25, r)
    glow = np.exp(-r * 4.0) * 0.7
    v = (rays * 0.9 + glow) * strength * (0.9 + 0.1 * math.sin(2 * math.pi * t / (BAR / 2) + seed))
    v = cv2.resize(v, (W, H), interpolation=cv2.INTER_LINEAR)
    return v[..., None] * np.array([1.0, 0.86, 0.6], np.float32)


def particles(seed, t, count, col):
    """Vagalumes / poeira / pólen subindo devagar e piscando no ritmo (2 colcheias)."""
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
        tw = 0.55 + 0.45 * math.sin(2 * math.pi * t / (2 * BEAT) + ph[j] * 3)
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


_RAIN = np.random.default_rng(3)
RAIN = (_RAIN.random(420) * (W + 500) - 250, _RAIN.random(420) * H, 0.5 + _RAIN.random(420), _RAIN.random(420))


def rain_layer(t):
    x0, y0, z, a = RAIN
    lay = np.zeros((H // 2, W // 2), np.float32)
    for x, y, zz, aa in zip(x0, y0, z, a):
        yy = (y + t * 1600 * zz * SC) % (H + 100) - 50
        xx = x - (yy - y) * 0.30
        L = 34 * zz * SC
        cv2.line(lay, (int(xx / 2), int(yy / 2)), (int((xx - L * 0.3) / 2), int((yy - L) / 2)),
                 0.10 + 0.18 * aa * zz, 1, cv2.LINE_AA)
    return cv2.resize(lay, (W, H), interpolation=cv2.INTER_LINEAR)[..., None] * np.float32([0.78, 0.84, 0.95])


def rose_petals(frame, t, t0, M, src, pos):
    """Pétalas que se soltam da rosa e caem girando (acompanham a câmera)."""
    sx, sy = apply_pt(M, pos[0] * src["w"], pos[1] * src["h"])
    rng = np.random.default_rng(7)
    for k in range(8):
        ts = t0 + 0.5 + k * 0.42 + rng.random() * 0.2
        if t < ts:
            continue
        a = t - ts
        x = sx + (70 * a + 22 * math.sin(2.5 * a + k)) * SC
        y = sy + (55 * a * a + 26 * a) * SC
        if not (0 <= x < W and 0 <= y < H):
            continue
        ang = 2.0 * a + k
        sz = (7 + 3 * rng.random()) * SC
        r = int(sz * 2) + 2
        xa, xb, ya, yb = max(int(x) - r, 0), min(int(x) + r, W), max(int(y) - r, 0), min(int(y) + r, H)
        gx = np.arange(xa, xb, dtype=np.float32) - x
        gy = np.arange(ya, yb, dtype=np.float32)[:, None] - y
        u = gx * math.cos(ang) + gy * math.sin(ang)
        v = -gx * math.sin(ang) + gy * math.cos(ang)
        g = np.exp(-((u / sz) ** 2 + (v / (sz * 0.45 * (0.6 + 0.4 * abs(math.sin(3 * a + k))))) ** 2) * 2) * 0.85
        frame[ya:yb, xa:xb] = frame[ya:yb, xa:xb] * (1 - g[..., None]) + np.float32([0.92, 0.55, 0.58]) * g[..., None]


# ---------------------------------------------------------------- personagens vivos
# rostos/cabeças: (cx, cy, raio, cabelo, ganho) normalizados pela largura/altura da imagem.
# Cabeças giram rígidas em torno do pescoço (o rosto não deforma); "cabelo" liga as mechas ao vento.
FACE = {
    1: [(0.335, 0.345, 0.045, False, 1.0), (0.555, 0.395, 0.035, True, 1.0)],
    2: [(0.245, 0.270, 0.050, False, 1.2), (0.790, 0.420, 0.040, True, 0.8)],
    3: [(0.410, 0.505, 0.040, False, 1.2), (0.645, 0.320, 0.033, True, 0.9)],
    4: [(0.370, 0.280, 0.075, True, 0.8), (0.620, 0.400, 0.095, False, 0.8)],
    5: [(0.400, 0.380, 0.055, False, 1.0), (0.600, 0.600, 0.040, True, 1.6)],
    6: [], 7: [],
}
# balanço do corpo (graus) por imagem; as armaduras vazias (6, 7) ficam paradas
SWAY = {1: 0.5, 2: 0.45, 3: 0.4, 4: 0.35, 5: 0.6, 6: 0.0, 7: 0.0}
# braços articulados: (ombro, cotovelo, mão) normalizados, espessura (fração da largura),
# amplitude no ombro e no cotovelo (graus), período (s) e fase. Mão e dedos se movem inteiros.
ARMS = {
    1: [((0.360, 0.430), (0.425, 0.455), (0.470, 0.345), 0.030, 2.4, 4.5, BAR, 0.0)],     # ergue a rosa
    2: [((0.200, 0.380), (0.270, 0.500), (0.350, 0.530), 0.035, 1.4, 2.6, BAR, 1.2)],     # mãos no joelho
    3: [((0.360, 0.560), (0.345, 0.640), (0.420, 0.650), 0.030, 1.6, 2.4, BAR, 0.6)],     # mão no punho
    4: [((0.800, 0.780), (0.680, 0.700), (0.580, 0.520), 0.060, 1.2, 2.0, BAR, 0.4)],     # manopla e mão dela
    5: [((0.330, 0.480), (0.420, 0.600), (0.540, 0.660), 0.040, 1.2, 2.0, BAR, 0.9)],
}
# pontos que não podem ondular (a rosa, o elmo)
EXTRA_RIGID = {1: [(0.47, 0.33, 0.03)], 4: [(0.62, 0.40, 0.10)]}
LAST_FACE = [None]


def _seg(X, Y, a, b):
    vx, vy = b[0] - a[0], b[1] - a[1]
    L2 = vx * vx + vy * vy + 1e-6
    s_ = ((X - a[0]) * vx + (Y - a[1]) * vy) / L2
    sc = np.clip(s_, 0, 1)
    return np.sqrt((X - a[0] - sc * vx) ** 2 + (Y - a[1] - sc * vy) ** 2), s_


def arm_field(shot, src, Mf, t, X, Y):
    """Braços como ossos rígidos: ombro gira o braço todo, cotovelo gira o antebraço com atraso."""
    dx = np.zeros_like(X)
    dy = np.zeros_like(Y)
    wall = np.zeros_like(X)
    scl = math.hypot(Mf[0, 0], Mf[1, 0])
    for (S_, E, Hn, wd, a_sh, a_el, per, ph) in ARMS.get(shot["img"], []):
        Sp = apply_pt(Mf, S_[0] * src["w"], S_[1] * src["h"])
        Ep = apply_pt(Mf, E[0] * src["w"], E[1] * src["h"])
        Hp = apply_pt(Mf, Hn[0] * src["w"], Hn[1] * src["h"])
        Hx = (Hp[0] + 0.25 * (Hp[0] - Ep[0]), Hp[1] + 0.25 * (Hp[1] - Ep[1]))
        r = wd * src["w"] * scl
        d1, s1 = _seg(X, Y, Sp, Ep)
        d2, s2 = _seg(X, Y, Ep, Hx)
        w_up = (1 - smoothstep(r, 1.9 * r, d1)) * smoothstep(-0.15, 0.45, s1)
        w_fo = 1 - smoothstep(r, 1.9 * r, d2)
        w_arm = np.maximum(w_up, w_fo)
        w_el = w_fo * smoothstep(-0.05, 0.3, s2)
        ths = math.radians(1.4 * a_sh * math.sin(2 * math.pi * t / per + ph))
        the = math.radians(1.4 * a_el * math.sin(2 * math.pi * t / per + ph - 0.9))
        rx, ry = X - Sp[0], Y - Sp[1]
        dx += (math.cos(ths) * rx - math.sin(ths) * ry - rx) * w_arm
        dy += (math.sin(ths) * rx + math.cos(ths) * ry - ry) * w_arm
        rx, ry = X - Ep[0], Y - Ep[1]
        dx += (math.cos(the) * rx - math.sin(the) * ry - rx) * w_el
        dy += (math.sin(the) * rx + math.cos(the) * ry - ry) * w_el
        wall = np.maximum(wall, w_arm)
    return dx, dy, wall


def alive_field(shot, src, Mf, t):
    """Deslocamento (tela, 1/4 da resolução) que dá vida aos personagens."""
    i = shot["img"]
    X, Y = _QX, _QY
    dx = np.zeros_like(X)
    dy = np.zeros_like(Y)
    faces = FACE.get(i, [])
    if not faces and i not in ARMS:
        return dx, dy
    scl = math.hypot(Mf[0, 0], Mf[1, 0])
    x0, y0, x1, y1 = src["bbox"]
    ph = i * 1.7

    # corpo: balanço leve em torno da base dos personagens
    px, py = apply_pt(Mf, (x0 + x1) / 2, y1)
    tb = math.radians(SWAY.get(i, 0.4) * math.sin(2 * math.pi * t / (2 * BAR) + ph))
    top = apply_pt(Mf, 0, y0)[1]
    wb = np.clip((py - Y) / max(py - top, 1.0), 0, 1.2)
    rx, ry = X - px, Y - py
    dx += (math.cos(tb) * rx - math.sin(tb) * ry - rx) * wb
    dy += (math.sin(tb) * rx + math.cos(tb) * ry - ry) * wb

    adx, ady, armw = arm_field(shot, src, Mf, t, X, Y)
    free = 1 - armw
    rigid = np.ones_like(X)
    for ex, ey, er in EXTRA_RIGID.get(i, []):
        qx, qy = apply_pt(Mf, ex * src["w"], ey * src["h"])
        rr = er * src["w"] * scl
        rigid = rigid * smoothstep(1.0 * rr, 2.0 * rr, np.sqrt((X - qx) ** 2 + (Y - qy) ** 2))

    for k, (fxn, fyn, frn, hair, gain) in enumerate(faces):
        fx, fy = apply_pt(Mf, fxn * src["w"], fyn * src["h"])
        R = frn * src["w"] * scl
        dist = np.sqrt((X - fx) ** 2 + (Y - fy) ** 2)
        pk = ph + k * 2.3
        # cabeça: rotação rígida em torno do pescoço, no ritmo do compasso
        nx, ny = fx, fy + 1.25 * R
        th = math.radians(gain * (1.8 * math.sin(2 * math.pi * t / BAR + pk)
                                  + 0.6 * math.sin(2 * math.pi * t / (BAR / 2) + 2 * pk)))
        wh = 1 - smoothstep(1.35 * R, 2.4 * R, dist)
        rx, ry = X - nx, Y - ny
        dx += (math.cos(th) * rx - math.sin(th) * ry - rx) * wh
        dy += (math.sin(th) * rx + math.cos(th) * ry - ry) * wh
        # respiração: o peito sobe e expande (um ciclo a cada meio compasso)
        cx, cyy = fx, fy + 2.7 * R
        br = 0.5 - 0.5 * math.cos(2 * math.pi * t / (BAR / 2) + pk)
        g = np.exp(-((X - cx) ** 2 + (Y - cyy) ** 2) / (2 * (2.3 * R) ** 2))
        dy += -0.12 * R * br * g
        dx += (X - cx) * 0.03 * br * g
        # cabelo: mechas presas na raiz, pontas soltas balançando com rajadas de vento
        if hair:
            hair_reg = 1 - smoothstep(0.85, 1.15, ((X - fx) / (2.4 * R)) ** 2 + ((Y - (fy + 1.1 * R)) / (3.4 * R)) ** 2)
            face_e = ((X - fx) / (1.05 * R)) ** 2 + ((Y - (fy + 0.3 * R)) / (1.5 * R)) ** 2
            w_hair = hair_reg * smoothstep(1.0, 1.7, face_e)
            s_len = np.clip((Y - (fy - 1.1 * R)) / (3.8 * R), 0, 1) ** 1.2 + 0.35 * np.clip(np.abs(X - fx) / (2 * R), 0, 1)
            gust = 0.6 + 0.4 * math.sin(2 * math.pi * t / BAR + pk)
            yh = (Y - fy) / R
            a1 = 2 * math.pi * t / 2.2 - yh / 1.3 + pk
            a2 = 2 * math.pi * t / 1.15 - yh / 0.7 + (X - fx) / (1.1 * R) + 2 * pk
            a3 = 2 * math.pi * t / 0.6 - yh / 0.35 + (X - fx) / (0.5 * R)
            amp = 0.15 * R * w_hair * s_len * gust * free * gain
            dx += amp * (np.sin(a1) + 0.5 * np.sin(a2) + 0.22 * np.sin(a3))
            dy += amp * (0.35 * np.cos(a1) + 0.12 * np.cos(a3))
        # tecido (capas, vestidos): onda descendo longe do rosto
        wc = smoothstep(2.0 * R, 4.5 * R, dist) * np.clip((Y - fy) / (5 * R), 0, 1) * free * rigid / len(faces)
        wave = 2 * math.pi * (Y / (7 * R) + X / (21 * R)) - 2 * math.pi * t / 2.7 + pk
        dx += 0.05 * R * wc * np.sin(wave)
        dy += 0.016 * R * wc * np.cos(wave * 0.8)
    dx += adx
    dy += ady
    return dx, dy


# ---------------------------------------------------------------- ambiente vivo
# zonas por imagem (caixas normalizadas): sky = céu derivando, sway = folhas, flores e
# relva balançando, haze = névoa tremulando
ENV = {
    1: [("sky", 0.40, 0.0, 1.0, 0.50), ("sway", 0.0, 0.62, 0.32, 1.0), ("sway", 0.85, 0.45, 1.0, 0.56)],
    2: [("sky", 0.30, 0.0, 1.0, 0.32), ("sway", 0.30, 0.08, 1.0, 0.66)],
    3: [("sky", 0.0, 0.0, 1.0, 0.28), ("haze", 0.0, 0.28, 0.45, 0.50), ("sway", 0.72, 0.0, 1.0, 1.0),
        ("sway", 0.0, 0.80, 1.0, 1.0)],
    4: [("haze", 0.0, 0.0, 1.0, 1.0)],
    5: [("sky", 0.0, 0.0, 1.0, 0.62), ("haze", 0.55, 0.60, 1.0, 0.74), ("sway", 0.0, 0.72, 1.0, 1.0)],
    6: [("sway", 0.0, 0.0, 1.0, 1.0)],
    7: [("sway", 0.0, 0.0, 1.0, 1.0)],
}
SWAY_GAIN = {5: 2.0, 6: 1.6, 7: 1.5}


def _box(sx, sy, x0, y0, x1, y1, fe=0.05):
    return (smoothstep(x0 - fe, x0 + fe, sx) * (1 - smoothstep(x1 - fe, x1 + fe, sx)) *
            smoothstep(y0 - fe, y0 + fe, sy) * (1 - smoothstep(y1 - fe, y1 + fe, sy)))


def _periodic_noise(n, seed, beta=1.7):
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
    return cv2.remap(T, (u * NOISE_N).astype(np.float32), (v * NOISE_N).astype(np.float32),
                     cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)


def env_field(shot, src, M, t):
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
    sg = SWAY_GAIN.get(shot["img"], 1.0)
    for kind, x0, y0, x1, y1 in zones:
        w = _box(sx, sy, x0, y0, x1, y1)
        if kind == "sky":
            u, v = sx * 1.2, sy * 1.2 * asp
            n1 = tex(NOISE[0], u + t * 0.020, v + t * 0.006)
            n2 = tex(NOISE[1], u * 2.1 - t * 0.030, v * 2.1 + t * 0.010)
            A = 9 * SC
            dx += w * (A * (n1 + 0.5 * n2) + 12 * SC * tm)
            dy += w * A * 0.5 * (n2 - 0.4 * n1)
            shade += w * 0.025 * n2
        elif kind == "sway":
            A = 7 * SC * sg
            n1 = tex(NOISE[2], sx * 2 + t * 0.15, sy * 2 * asp)
            p1 = tau * t / BAR * 2 + sx * 3.0
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


def stars(src, M, t):
    """Estrelas cintilando (cada uma com sua fase): só existem onde o céu é escuro."""
    fx = warp_level(src, M, "fx").astype(np.float32) / 255
    st, phs = fx[..., 0], fx[..., 1]
    if st.max() < 0.05:
        return None
    tw = 0.5 + 0.5 * np.sin(t * (2.0 + 3.0 * phs) + phs * 40)
    return (st * (tw - 0.3) * 0.6)[..., None] * np.float32([0.95, 0.97, 1.0])


def metal_glint(frame, u, t):
    """Reflexo de luz que varre as armaduras (realces claros e pouco saturados)."""
    sm = cv2.resize(frame, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
    mx, mn = sm.max(2), sm.min(2)
    sat = (mx - mn) / (mx + 1e-3)
    metal = np.clip((sm.mean(2) - 0.30) / 0.45, 0, 1) * np.clip(1 - sat / 0.35, 0, 1)
    pos = -0.4 + 1.8 * u
    dd = (_QX / W * 0.7 + _QY / H * 0.5) - pos
    band = np.exp(-(dd / 0.06) ** 2) + 0.25 * np.exp(-(dd / 0.2) ** 2)
    v = cv2.resize(metal ** 1.5 * band * (0.30 + 4 * beat_env(t)), (W, H), interpolation=cv2.INTER_LINEAR)
    return v[..., None] * np.float32([1.0, 0.93, 0.80])


# ---------------------------------------------------------------- render de um plano
def render_shot(shot, f, tx=None):
    src = IMGS[shot["img"]]
    n = (shot["f1"] - shot["f0"]) / R30
    lf = (f - shot["f0"]) / R30
    u = lf / max(n - 1, 1)
    t = f / FPS
    prog = 0.3 * ease_out(u, 3) + 0.7 * u
    cx, cy, wf = (lerp(shot["a"][i], shot["b"][i], prog) for i in range(3))

    sd = shot["seed"]
    off = [SC * (5 * math.sin(t * 0.73 + sd) + 3 * math.sin(t * 1.9 + sd * 2)),
           SC * (4 * math.sin(t * 0.61 + sd * 3) + 2 * math.sin(t * 1.7 + sd))]
    rot = 0.22 * math.sin(t * 0.45 + sd)
    if shot.get("rot"):
        rot += lerp(shot["rot"][0], shot["rot"][1], ease_io(u))
    extra = 1.0
    for b, st in PULSES:
        d = t - b
        if 0 <= d < 0.28:
            extra *= 1 + (0.010 + 0.022 * st) * (1 - d / 0.28) ** 2
    if tx:
        extra *= tx.get("scale", 1.0)
        off[0] += tx.get("dx", 0.0)
        off[1] += tx.get("dy", 0.0)
        rot += tx.get("rot", 0.0)
    a_ = math.radians(abs(rot))
    extra *= (math.cos(a_) + W / H * math.sin(a_)) * 1.012

    M = camera_matrix(src, cx, cy, wf, rot, extra, off)

    # parallax 2.5D: os personagens aproximam mais que o fundo e deslizam lateralmente
    x0, y0, x1, y1 = src["bbox"]
    pvx, pvy = apply_pt(M, (x0 + x1) / 2, y1)
    k = 1 + PAR_GAIN * shot.get("par", 0.04) * ease_io(u)
    lat = LAT_GAIN * shot.get("lat", 0.0) * (min(max(u, -0.2), 1.2) - 0.5) * W
    Pm = np.float32([[k, 0, (1 - k) * pvx + lat], [0, k, (1 - k) * pvy]])
    Mf = (Pm[:, :2] @ M).astype(np.float32)
    Mf[:, 2] += Pm[:, 2]

    bg = warp_level(src, M, "bg").astype(np.float32) / 255
    bg = animate_env(bg, shot, src, M, t)
    st = stars(src, M, t)
    if st is not None:
        bg = bg + st
    faces = FACE.get(shot["img"], [])
    if faces:
        LAST_FACE[0] = apply_pt(Mf, faces[-1][0] * src["w"], faces[-1][1] * src["h"])
    adx, ady = alive_field(shot, src, Mf, t)
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
        tex_ = CLOUDS[shot["clouds"]]
        for li, (layer, spd) in enumerate(zip(tex_, (32 * SC, 60 * SC))):
            x = int((t * spd + li * 300) % W)
            sl = layer[:, x:x + W]
            a = sl[..., 3:4] * 0.55
            frame = frame * (1 - a) + sl[..., :3] * a
    frame = frame + metal_glint(frame, u, t)
    if rays is not None:
        frame = 1 - (1 - frame) * (1 - rays * 0.25)
    if shot.get("rain"):
        frame = frame + rain_layer(t)
    if shot.get("particles"):
        p = particles(sd, t, shot["particles"], shot.get("pcol", (1.0, 0.85, 0.55)))
        frame = 1 - (1 - frame) * (1 - p * 0.7)
    if shot.get("petals"):
        rose_petals(frame, t, shot["t0"], Mf, src, shot["petals"])
    return frame


# ---------------------------------------------------------------- transições (da edit de Jesus)
TWIN = {"burn": (9, 10), "iris": (6, 10), "cloud": (12, 12), "flare": (8, 8), "smoke": (12, 12),
        "bloom": (6, 9), "punch": (0, 6)}


def chroma(img, amt):
    if amt < 0.3:
        return img
    out = img.copy()
    for c, s in ((0, 1 + amt / W), (2, 1 - amt / W)):
        M = np.float32([[s, 0, (1 - s) * W / 2], [0, s, (1 - s) * H / 2]])
        out[..., c] = cv2.warpAffine(img[..., c], M, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    return out


def shake(e, seed):
    a = (1 - e) ** 2
    return dict(dx=14 * SC * a * math.sin(seed * 7.1 + e * 40), dy=10 * SC * a * math.sin(seed * 3.3 + e * 33),
                rot=0.5 * a * math.sin(seed * 5.7 + e * 37))


def _scr_noise(seed, t, scale=2.2, speed=0.05):
    u = _QX / W * scale + t * speed + seed * 0.37
    v = _QY / H * scale * H / W + seed * 0.61
    n = tex(NOISE[seed % 3], u, v) * 0.65 + tex(NOISE[(seed + 1) % 3], u * 2.3 - t * speed, v * 2.3) * 0.35
    return cv2.resize(n, (W, H), interpolation=cv2.INTER_LINEAR)


def _mix(a, b, w):
    return a * (1 - w[..., None]) + b * w[..., None]


def transition_frame(f):
    t = f / FPS
    for k in range(1, len(SHOTS)):
        B = SHOTS[k]
        typ = B["cut"]
        pre, post = (v * R30 for v in TWIN.get(typ, (0, 0)))
        c = B["f0"]
        if not (c - pre <= f < c + post):
            continue
        A = SHOTS[k - 1]
        p = (f - (c - pre) + 0.5) / (pre + post)
        m = pre / (pre + post)
        pk = math.exp(-((p - m) / 0.18) ** 2)

        if typ == "burn":
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
            return 1 - (1 - fr) * (1 - np.clip(ring * 0.9 + halo * 1.2, 0, 1)[..., None] * np.float32([1.0, 0.84, 0.5]))

        if typ == "cloud":
            pos = lerp(1.45, -0.45, ease_io(p))
            fa = render_shot(A, f, dict(dx=-60 * SC * ease_io(p)))
            fb = render_shot(B, f, dict(dx=60 * SC * (1 - ease_io(p))))
            n = _scr_noise(k + 5, t, 2.6, 0.03)
            xn = _XF / W + 0.18 * n + 0.06 * np.sin(_YF / H * 6 + k)
            w = cv2.GaussianBlur((xn > pos).astype(np.float32), (0, 0), 25 * SC)
            fr = _mix(fb, fa, w)
            dens = np.clip(1.3 - np.abs(xn - pos) * 3.0 + 0.35 * n, 0, 1) ** 1.2
            shade = 0.82 + 0.18 * (_scr_noise(k + 9, t, 5.0, 0.06) * 0.5 + 0.5) - 0.08 * (_YF / H)
            col = np.dstack([shade, shade * 0.96, shade * 0.9]).astype(np.float32)
            return _mix(fr, col, dens)

        if typ == "flare":
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
            sy = H * (0.2 + 0.6 * ease_io(p))
            streak = np.exp(-((_YF - sy) / (6 * SC)) ** 2) * (0.35 + 0.65 * np.exp(-(dd / 0.15) ** 2)) * pk
            fr = fr + streak[..., None] * np.float32([0.55, 0.75, 1.0]) * 0.55
            return chroma(fr, 10 * SC * pk)

        if typ == "smoke":
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
            tx = shake(p, k)
            tx["scale"] = 1 + 0.12 * (1 - ease_out(p, 3))
            fr = render_shot(B, f, tx)
            return chroma(fr, 10 * SC * (1 - p))
        return None
    return None


def beat_env(t):
    v = 0.0
    for b, st in PULSES:
        d = t - b
        if 0 <= d < 0.22:
            v = max(v, 0.055 * st * (1 - d / 0.22) ** 2)
    return v


def grade(fr, f):
    lum = fr.mean(2, keepdims=True)
    hi = fr * smoothstep(0.62, 1.0, lum)
    sm = cv2.resize(hi, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
    bloom = cv2.resize(cv2.GaussianBlur(sm, (0, 0), 9), (W, H), interpolation=cv2.INTER_LINEAR)
    fr = 1 - (1 - fr) * (1 - bloom * 0.32)
    fr = fr + (smoothstep(0.4, 1.0, lum) * 0.035) * np.array([1.0, 0.45, -0.6], np.float32)
    fr = fr + (1 - smoothstep(0.0, 0.35, lum)) * 0.012 * np.array([-0.6, 0.15, 0.6], np.float32)  # sombras frias
    fr = fr + 0.06 * (fr - 0.5) * (1 - np.abs(2 * fr - 1))
    fr = fr * VIGNETTE
    g = np.random.default_rng(f).standard_normal((H // 2, W // 2)).astype(np.float32)
    g = cv2.resize(g, (W, H), interpolation=cv2.INTER_LINEAR)[..., None]
    return fr + g * 0.009


def render_frame(f):
    t = f / FPS
    shot = next((s for s in SHOTS if s["f0"] <= f < s["f1"]), SHOTS[-1])
    frame = transition_frame(f)
    if frame is None:
        frame = render_shot(shot, f)
    for lt in LIGHTNING:  # relâmpagos da tempestade, nos acentos
        if 0 <= t - lt < 0.25:
            frame = frame + (math.exp(-(t - lt) / 0.06) * 0.30) * np.float32([0.85, 0.9, 1.0])
    frame = 1 - (1 - np.clip(frame, 0, 1)) * (1 - light_leak(t, 0.08))
    frame = grade(frame, f)
    frame = frame * (1 + beat_env(t))
    frame = frame * ease_io(min(1.0, t / 1.0)) * ease_io(min(1.0, (DUR - t) / 1.6))  # entrada e saída do preto
    return (np.clip(np.nan_to_num(frame), 0, 1) * 255 + 0.5).astype(np.uint8)


# ---------------------------------------------------------------- main
def main():
    audio = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else os.path.join(ROOT, "edit-medieval-16x9.mp4")
    if "--stills" in sys.argv:
        ts = [float(x) for x in sys.argv[sys.argv.index("--stills") + 1].split(",")]
        with Pool(os.cpu_count()) as pool:
            frames = pool.map(render_frame, [int(round(x * FPS)) for x in ts])
        for x, fr in zip(ts, frames):
            cv2.imwrite(os.path.join(os.path.dirname(os.path.abspath(out)), f"still_{x:05.2f}.jpg"), fr[:, :, ::-1],
                        [cv2.IMWRITE_JPEG_QUALITY, 92])
        return
    cmd = ["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
           "-r", str(FPS), "-i", "-", "-i", audio, "-map", "0:v", "-map", "1:a",
           "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-tune", "film",
           "-profile:v", "high", "-pix_fmt", "yuv420p",
           "-af", f"afade=t=in:d=0.3,afade=t=out:st={DUR - 1.6:.2f}:d=1.6", "-c:a", "aac", "-b:a", "320k",
           "-t", str(DUR), "-movflags", "+faststart", out]
    ff = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    with Pool(os.cpu_count()) as pool:
        for i, fr in enumerate(pool.imap(render_frame, range(NFRAMES), chunksize=2)):
            ff.stdin.write(fr.tobytes())
            if i % 120 == 0:
                print(f"frame {i}/{NFRAMES}", flush=True)
    ff.stdin.close()
    ff.wait()
    print("ok ->", out)


if __name__ == "__main__":
    main()

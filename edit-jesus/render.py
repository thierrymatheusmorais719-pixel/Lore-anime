#!/usr/bin/env python3
"""Edit cristã (~20 s) recriando o estilo do vídeo de referência com as imagens do usuário.

Pipeline: cada imagem é separada em figura (máscara) + fundo (inpaint) para parallax 2.5D,
animada por uma câmera virtual com cortes sincronizados aos beats da música de referência.
Efeitos: texto "GOD" dourado 3D entre nuvens (intro), nuvens procedurais em movimento,
raios de luz, partículas douradas, zoom/whip blur nas transições, flashes, bloom e grão.

Uso:  python3 render.py            -> saida/edit_jesus.mp4
      python3 render.py --preview  -> folha de contato com 1 frame a cada 0,5 s
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
DUR = 19.8
NFRAMES = int(round(DUR * FPS))  # 594
AUDIO = os.path.join(ROOT, "audio", "musica_referencia.m4a")
OUT = os.path.join(ROOT, "saida", "edit_jesus.mp4")

cv2.setNumThreads(1)


# ---------------------------------------------------------------- utilidades
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


# ---------------------------------------------------------------- assets
def load_image(i):
    img = cv2.imread(os.path.join(ROOT, "imagens", f"{i}.jpg"))
    img = cv2.fastNlMeansDenoisingColored(img, None, 3, 3, 5, 15)[:, :, ::-1]  # remove blocos JPEG
    m = cv2.imread(os.path.join(ROOT, "mascaras", f"{i}.png"), cv2.IMREAD_GRAYSCALE)
    h, w = img.shape[:2]
    # upscale 2x Lanczos + nitidez leve (fiel ao original, sem IA generativa)
    up = cv2.resize(img, (w * 2, h * 2), interpolation=cv2.INTER_LANCZOS4).astype(np.float32) / 255
    blur = cv2.GaussianBlur(up, (0, 0), 1.6)
    up = np.clip(up + 0.45 * (up - blur), 0, 1)
    mk = cv2.resize(m, (w * 2, h * 2), interpolation=cv2.INTER_LINEAR).astype(np.float32) / 255
    mk = np.clip((mk - 0.08) / 0.8, 0, 1)
    # fundo sem a figura (inpaint em meia resolução, revelado só nas bordas do parallax)
    dil = cv2.dilate((m > 20).astype(np.uint8) * 255, np.ones((15, 15), np.uint8))
    inp = cv2.inpaint(img, dil, 12, cv2.INPAINT_TELEA)
    inp = cv2.GaussianBlur(inp, (0, 0), 3)
    inp = cv2.resize(inp, (w * 2, h * 2), interpolation=cv2.INTER_CUBIC).astype(np.float32) / 255
    dm = cv2.GaussianBlur(cv2.resize(dil, (w * 2, h * 2)).astype(np.float32) / 255, (0, 0), 6)[..., None]
    bg = up * (1 - dm) + inp * dm
    ys, xs = np.nonzero(mk > 0.5)
    bbox = (xs.min(), ys.min(), xs.max(), ys.max())
    return dict(img=up, mask=mk, bg=bg, w=w * 2, h=h * 2, bbox=bbox)


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


print("carregando imagens…", flush=True)
IMGS = {i: load_image(i) for i in range(1, 10)}

# texto GOD no espaço da imagem 4 (fica atrás de Jesus e na frente do céu)
_i4 = IMGS[4]
GOD = make_god_text(int(_i4["w"] * 0.84))
_gh, _gw = GOD.shape[:2]
_gx, _gy = int(_i4["w"] * 0.5 - _gw / 2), int(_i4["h"] * 0.215 - _gh / 2)
INTRO_BG = _i4["bg"].copy()
_sx0, _sy0 = max(0, -_gx), max(0, -_gy)
_dx0, _dy0 = max(0, _gx), max(0, _gy)
_dx1, _dy1 = min(_i4["w"], _gx + _gw), min(_i4["h"], _gy + _gh)
_g = GOD[_sy0:_sy0 + _dy1 - _dy0, _sx0:_sx0 + _dx1 - _dx0]
_reg = INTRO_BG[_dy0:_dy1, _dx0:_dx1]
INTRO_BG[_dy0:_dy1, _dx0:_dx1] = _reg * (1 - _g[..., 3:4]) + _g[..., :3] * _g[..., 3:4]

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
VIGNETTE = None


# ---------------------------------------------------------------- roteiro
# crop: (cx, cy, w) normalizados na imagem; w = fração da largura enquadrada (4:3)
# cut:  transição de ENTRADA: zoom | whip | flash | punch | intro
S = lambda **k: k  # noqa: E731
SHOTS = [
    S(img=4, t0=0.00, t1=1.30, a=(0.50, 0.40, 1.00), b=(0.52, 0.32, 0.62), cut="intro",
      clouds="intro", rays=(0.53, 0.20, 0.30), particles=40, par=0.05),
    S(img=1, t0=1.30, t1=2.20, a=(0.54, 0.37, 1.00), b=(0.55, 0.34, 0.88), cut="zoom",
      particles=45, par=0.04),
    S(img=2, t0=2.20, t1=3.73, a=(0.50, 0.43, 1.00), b=(0.44, 0.39, 0.86), cut="whip", wdir=1,
      particles=35, par=0.05, pcol=(0.85, 0.95, 1.0)),
    S(img=3, t0=3.73, t1=4.97, a=(0.50, 0.42, 1.00), b=(0.50, 0.37, 0.86), cut="zoom",
      rays=(0.52, 0.12, 0.22), particles=40, par=0.05),
    S(img=5, t0=4.97, t1=6.13, a=(0.52, 0.37, 1.00), b=(0.56, 0.32, 0.86), cut="flash",
      rays=(0.75, 0.0, 0.22), particles=40, par=0.04),
    S(img=6, t0=6.13, t1=7.17, a=(0.50, 0.42, 1.00), b=(0.52, 0.39, 0.90), cut="whip", wdir=-1,
      particles=30, par=0.05),
    S(img=6, t0=7.17, t1=7.50, a=(0.45, 0.40, 0.62), b=(0.45, 0.40, 0.58), cut="punch", par=0.02),
    S(img=7, t0=7.50, t1=8.07, a=(0.50, 0.40, 0.86), b=(0.50, 0.42, 1.00), cut="zoom",
      rays=(0.50, 0.24, 0.30), particles=50, par=0.04),
    S(img=7, t0=8.07, t1=8.63, a=(0.50, 0.30, 0.58), b=(0.50, 0.29, 0.53), cut="flash",
      rays=(0.50, 0.24, 0.30), particles=40, par=0.03),
    S(img=8, t0=8.63, t1=9.93, a=(0.50, 0.34, 1.00), b=(0.50, 0.30, 0.85), cut="whip", wdir=1,
      rays=(0.48, 0.10, 0.20), particles=40, par=0.05),
    S(img=9, t0=9.93, t1=11.23, a=(0.50, 0.41, 1.00), b=(0.50, 0.39, 0.90), cut="zoom",
      clouds="cool", rays=(0.50, 0.36, 0.38), particles=60, par=0.03),
    S(img=1, t0=11.23, t1=12.47, a=(0.56, 0.32, 0.62), b=(0.56, 0.31, 0.56), cut="whip", wdir=-1,
      particles=40, par=0.03),
    S(img=2, t0=12.47, t1=13.60, a=(0.44, 0.33, 0.66), b=(0.42, 0.31, 0.58), cut="zoom",
      particles=35, par=0.03, pcol=(0.85, 0.95, 1.0)),
    S(img=5, t0=13.60, t1=14.87, a=(0.52, 0.42, 0.64), b=(0.52, 0.40, 0.56), cut="whip", wdir=1,
      rays=(0.80, 0.0, 0.24), particles=40, par=0.03),
    S(img=4, t0=14.87, t1=16.07, a=(0.50, 0.46, 1.00), b=(0.51, 0.40, 0.86), cut="flash",
      clouds="warm", rays=(0.53, 0.25, 0.34), particles=60, par=0.06),
    S(img=3, t0=16.07, t1=17.03, a=(0.48, 0.40, 0.58), b=(0.48, 0.38, 0.52), cut="punch",
      rays=(0.52, 0.10, 0.22), particles=35, par=0.03),
    S(img=7, t0=17.03, t1=17.37, a=(0.50, 0.29, 0.60), b=(0.50, 0.29, 0.56), cut="flash",
      rays=(0.50, 0.24, 0.30), particles=30, par=0.02),
    S(img=8, t0=17.37, t1=18.47, a=(0.50, 0.25, 0.64), b=(0.50, 0.23, 0.57), cut="zoom",
      rays=(0.48, 0.10, 0.20), particles=40, par=0.03),
    S(img=9, t0=18.47, t1=19.80, a=(0.50, 0.36, 0.74), b=(0.50, 0.41, 1.00), cut="flash",
      clouds="cool", rays=(0.50, 0.36, 0.45), particles=70, par=0.03, fade=True),
]
# batidas (fora dos cortes) que recebem um pulso de zoom
BEATS = [2.53, 2.69, 4.18, 4.37, 13.37, 13.98, 14.26, 15.46, 18.85]
for k, s in enumerate(SHOTS):
    s["f0"], s["f1"] = int(round(s["t0"] * FPS)), int(round(s["t1"] * FPS))
    s["next"] = SHOTS[k + 1]["cut"] if k + 1 < len(SHOTS) else None
    s["next_dir"] = SHOTS[k + 1].get("wdir", 1) if k + 1 < len(SHOTS) else 1
    s["seed"] = 100 + k


# ---------------------------------------------------------------- render de um shot
def camera_matrix(src, cx, cy, wf, rot_deg, extra_scale, off):
    cw = min(wf, 1.0, src["h"] / (src["w"] * 0.75)) * src["w"]
    ch = cw * 0.75
    # mantém o enquadramento dentro da imagem (margem p/ rotação/escala)
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
    # centro mais nítido, bordas borradas (como na referência)
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
    """Raios de luz volumétricos (meia resolução, espaço de tela)."""
    ang = np.arctan2(_YY - oy / 2, _XX - ox / 2)
    r = np.sqrt((_XX - ox / 2) ** 2 + (_YY - oy / 2) ** 2) / (H / 2)
    u = (ang / (2 * math.pi) + 0.5) * 720 + t * 6 + seed * 37
    i0 = np.floor(u).astype(np.int32)
    fr = u - i0
    nz = RAY_NOISE[i0 % 720] * (1 - fr) + RAY_NOISE[(i0 + 1) % 720] * fr
    rays = smoothstep(0.35, 1.0, nz) * np.exp(-r * 1.25) * smoothstep(0.0, 0.25, r)
    glow = np.exp(-r * 4.0) * 0.7
    v = (rays * 0.9 + glow) * strength
    v = cv2.resize(v, (W, H), interpolation=cv2.INTER_LINEAR)
    return v[..., None] * np.array([1.0, 0.86, 0.6], np.float32)


def particles(shot, t, count, col):
    rng = np.random.default_rng(shot["seed"])
    x = rng.random(count) * W
    y = rng.random(count) * H
    z = rng.random(count) ** 1.5  # profundidade
    sp = 25 + 70 * z
    ph = rng.random(count) * 6.28
    canvas = np.zeros((H // 2, W // 2), np.float32)
    big = np.zeros_like(canvas)
    for j in range(count):
        px = (x[j] + 18 * math.sin(t * 0.9 + ph[j]) + t * 10 * (z[j] - 0.4)) % W
        py = (y[j] - sp[j] * t) % H
        tw = 0.55 + 0.45 * math.sin(t * 3.0 + ph[j] * 3)
        rad = 0.6 + 2.6 * z[j]
        tgt = big if z[j] > 0.75 else canvas
        cv2.circle(tgt, (int(px / 2), int(py / 2)), max(1, int(round(rad))), float(tw * (0.4 + 0.6 * z[j])), -1, cv2.LINE_AA)
    lay = cv2.GaussianBlur(canvas, (0, 0), 1.2) * 1.6 + cv2.GaussianBlur(big, (0, 0), 3.5) * 1.2
    lay = cv2.resize(lay, (W, H), interpolation=cv2.INTER_LINEAR)
    return np.clip(lay, 0, 1)[..., None] * np.array(col, np.float32)


def render_frame(f):
    shot = next(s for s in SHOTS if s["f0"] <= f < s["f1"])
    src = IMGS[shot["img"]]
    n = shot["f1"] - shot["f0"]
    lf = f - shot["f0"]  # frame local
    u = lf / max(n - 1, 1)
    t = f / FPS
    # progresso: impacto rápido no início + deriva contínua
    prog = 0.4 * ease_out(u, 4) + 0.6 * ease_io(u)
    if shot["cut"] == "intro":
        # quase parado enquanto o quadro abre; depois um zoom acelerado no rosto
        prog = 0.08 * min(lf / 23, 1.0) + 0.92 * max(0.0, (lf - 23) / (n - 24)) ** 2
    cx, cy, wf = (lerp(shot["a"][i], shot["b"][i], prog) for i in range(3))

    extra, off, rblur, wblur, flash = 1.0, [0.0, 0.0], 0.0, 0.0, 0.0
    rot = 0.0
    cut = shot["cut"]
    # ---- transição de entrada
    if cut == "zoom" and lf < 7:
        e = 1 - ease_out(lf / 7, 2)
        extra *= 1 + 0.22 * e
        rblur = max(rblur, 0.16 * e)
    elif cut == "whip" and lf < 6:
        e = 1 - ease_out(lf / 6, 3)
        off[0] += shot.get("wdir", 1) * W * 0.30 * e
        wblur = max(wblur, 160 * e)
        rot += shot.get("wdir", 1) * 1.5 * e
    elif cut == "flash" and lf < 8:
        e = 1 - ease_out(lf / 8, 2)
        flash = 0.85 * e
        extra *= 1 + 0.08 * e
    elif cut == "punch" and lf < 5:
        extra *= 1 + 0.10 * (1 - ease_out(lf / 5, 2))
    # ---- transição de saída (antecipa o próximo corte)
    rem = n - 1 - lf
    nxt = shot["next"]
    if nxt == "zoom" and rem < 3:
        e = ease_out((3 - rem) / 3, 2)
        extra *= 1 + 0.12 * e
        rblur = max(rblur, 0.12 * e)
    elif nxt == "whip" and rem < 3:
        e = ease_out((3 - rem) / 3, 2) ** 1.5
        off[0] -= shot["next_dir"] * W * 0.25 * e
        wblur = max(wblur, 140 * e)
    elif nxt == "flash" and rem < 2:
        flash = max(flash, 0.35 * (2 - rem) / 2)
    # pulso nas batidas
    for b in BEATS:
        d = t - b
        if 0 <= d < 0.25:
            extra *= 1 + 0.025 * (1 - d / 0.25) ** 2

    # ---- intro em tela cheia: entra com flash de luz, leve giro e zoom que assenta
    if cut == "intro":
        if lf < 23:
            e = ease_out(lf / 23, 3)
            ang, zin = lerp(-5.0, -1.5, e), lerp(1.30, 1.0, e)
        else:
            e = ease_out((lf - 23) / (n - 23), 2)
            ang, zin = lerp(-1.5, 0.0, e), 1.0
        rot += ang
        a_ = math.radians(abs(ang))
        extra *= zin * (math.cos(a_) + W / H * math.sin(a_))  # cobre a tela sem bordas
        if lf < 7:
            k_ = 1 - ease_out(lf / 7, 2)
            flash = max(flash, 0.9 * k_)
            rblur = max(rblur, 0.14 * k_)
    M = camera_matrix(src, cx, cy, wf, rot, extra, off)

    # ---- parallax 2.5D: figura aproxima mais que o fundo
    x0, y0, x1, y1 = src["bbox"]
    floating = shot["img"] in (4, 9)
    pvx, pvy = apply_pt(M, (x0 + x1) / 2, (y0 + y1) / 2 if floating else y1)
    k = 1 + shot.get("par", 0.04) * ease_io(u)
    Pm = np.float32([[k, 0, (1 - k) * pvx], [0, k, (1 - k) * pvy]])
    Mf = (Pm[:, :2] @ M).astype(np.float32)
    Mf[:, 2] += Pm[:, 2]

    bgsrc = INTRO_BG if cut == "intro" else src["bg"]
    flags = dict(flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REFLECT)
    bg = cv2.warpAffine(bgsrc, M, (W, H), **flags)
    fg = cv2.warpAffine(src["img"], Mf, (W, H), **flags)
    mk = cv2.warpAffine(src["mask"], Mf, (W, H), flags=cv2.INTER_LINEAR)[..., None]
    rays = None
    if shot.get("rays"):
        rx, ry, rs = shot["rays"]
        ox, oy = apply_pt(M, rx * src["w"], ry * src["h"])
        rays = np.clip(god_rays(ox, oy, t, shot["seed"], rs), 0, 1)
        bg = 1 - (1 - bg) * (1 - rays)  # raios atrás da figura
    frame = bg * (1 - mk) + fg * mk

    # ---- nuvens em movimento (na frente da figura)
    if shot.get("clouds"):
        tex = CLOUDS[shot["clouds"]]
        rise = (1 - ease_out(u, 2)) * 60 if shot["clouds"] != "intro" else 0
        for li, (layer, spd) in enumerate(zip(tex, (40, 75))):
            x = int((t * spd + li * 300) % W)
            sl = layer[:, x:x + W]
            if rise:
                dy = int(rise * (li + 1) * 0.6)  # nuvens sobem ao entrar na cena
                if dy > 0:
                    sl = np.concatenate([np.zeros_like(sl[:dy]), sl[:-dy]], axis=0)
            a = sl[..., 3:4] * (0.95 if shot["clouds"] == "intro" else 0.8)
            frame = frame * (1 - a) + sl[..., :3] * a

    # ---- raios de luz
    if rays is not None:  # leve névoa luminosa também na frente
        frame = 1 - (1 - frame) * (1 - rays * 0.25)

    # ---- partículas douradas
    if shot.get("particles"):
        p = particles(shot, t, shot["particles"], shot.get("pcol", (1.0, 0.85, 0.55)))
        frame = 1 - (1 - frame) * (1 - p * 0.75)

    if cut == "intro":
        if lf >= 27:
            rblur = max(rblur, 0.30 * ease_out((lf - 27) / (n - 27), 1.5))
    if cut == "zoom" and shot["f0"] == SHOTS[1]["f0"] and lf < 9:  # saída da intro
        rblur = max(rblur, 0.30 * (1 - ease_out(lf / 9, 2)))

    # ---- blur de transição
    if rblur > 0:
        fx, fy = apply_pt(Mf, (x0 + x1) / 2, y0 + (y1 - y0) * 0.25)
        fx, fy = min(max(fx, W * 0.3), W * 0.7), min(max(fy, H * 0.3), H * 0.7)
        frame = radial_blur(frame, rblur, fx, fy)
    if wblur > 0:
        frame = dir_blur(frame, wblur)

    frame = grade(frame, f)
    if flash > 0:
        frame = frame + (1 - frame) * flash * np.array([1.0, 0.95, 0.85], np.float32)
    if shot.get("fade"):
        e = max(0.0, (lf - (n - 14)) / 13)
        frame = frame + (1 - frame) * (ease_io(e) * 0.92) * np.array([1.0, 0.94, 0.82], np.float32)
        frame = frame * (1 - ease_io(max(0.0, (lf - (n - 4)) / 3)))
    return (np.clip(frame, 0, 1) * 255 + 0.5).astype(np.uint8)


def grade(fr, f):
    global VIGNETTE
    if VIGNETTE is None:
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2) / math.sqrt(2)
        VIGNETTE = (1 - 0.32 * smoothstep(0.45, 1.0, r))[..., None]
    # bloom suave nas altas luzes (atmosfera celestial)
    lum = fr.mean(2, keepdims=True)
    hi = fr * smoothstep(0.62, 1.0, lum)
    sm = cv2.resize(hi, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
    bloom = cv2.resize(cv2.GaussianBlur(sm, (0, 0), 9), (W, H), interpolation=cv2.INTER_LINEAR)
    fr = 1 - (1 - fr) * (1 - bloom * 0.35)
    # tom dourado leve nas altas luzes, contraste suave
    fr = fr + (smoothstep(0.4, 1.0, lum) * 0.035) * np.array([1.0, 0.45, -0.6], np.float32)
    fr = fr + 0.06 * (fr - 0.5) * (1 - np.abs(2 * fr - 1))
    fr = fr * VIGNETTE
    # grão de filme
    g = np.random.default_rng(f).standard_normal((H // 2, W // 2)).astype(np.float32)
    g = cv2.resize(g, (W, H), interpolation=cv2.INTER_LINEAR)[..., None]
    return fr + g * 0.012


# ---------------------------------------------------------------- main
def main():
    if "--preview" in sys.argv:
        fs = list(range(0, NFRAMES, 15))
        with Pool(os.cpu_count()) as pool:
            frames = pool.map(render_frame, fs)
        th = [cv2.resize(fr, (320, 240), interpolation=cv2.INTER_AREA) for fr in frames]
        while len(th) % 8:
            th.append(np.zeros_like(th[0]))
        rows = [np.hstack(th[i:i + 8]) for i in range(0, len(th), 8)]
        cv2.imwrite(os.path.join(ROOT, "saida", "preview.jpg"), np.vstack(rows)[:, :, ::-1])
        return
    if "--frames" in sys.argv:
        for a in sys.argv[sys.argv.index("--frames") + 1].split(","):
            cv2.imwrite(os.path.join(ROOT, "saida", f"f{int(a):03d}.jpg"), render_frame(int(a))[:, :, ::-1])
        return
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    cmd = ["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
           "-r", str(FPS), "-i", "-", "-i", AUDIO, "-map", "0:v", "-map", "1:a",
           "-c:v", "libx264", "-preset", "slow", "-crf", "14", "-tune", "film",
           "-profile:v", "high", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "320k",
           "-shortest", "-movflags", "+faststart", OUT]
    ff = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    with Pool(os.cpu_count()) as pool:
        for i, fr in enumerate(pool.imap(render_frame, range(NFRAMES), chunksize=2)):
            ff.stdin.write(fr.tobytes())
            if i % 60 == 0:
                print(f"frame {i}/{NFRAMES}", flush=True)
    ff.stdin.close()
    ff.wait()
    print("ok ->", OUT)


if __name__ == "__main__":
    main()

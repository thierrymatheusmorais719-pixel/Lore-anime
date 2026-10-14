"""Letreiro "GOD" em ouro: fonte romana (Cinzel Black), bisel arredondado, reflexo de ambiente,
metal escovado, extrusão com oclusão e sombra. Gera camadas pré-multiplicadas + máscara de brilho
para o reflexo de luz animado no render."""
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(ROOT, "fontes", "cinzel-latin-900-normal.woff")


def _ramp(x, stops):
    out = np.zeros(x.shape + (3,), np.float32)
    for (a, ca), (b, cb) in zip(stops[:-1], stops[1:]):
        k = np.clip((x - a) / (b - a), 0, 1)[..., None]
        sel = ((x >= a) & (x <= b))[..., None]
        out = np.where(sel, np.float32(ca) * (1 - k) + np.float32(cb) * k, out)
    return out


def make_god(width_px, text="GOD", track=0.07, seed=3):
    # ---- máscara da fonte (supersample 2x)
    ss = 2
    probe = ImageFont.truetype(FONT, 400)
    adv = sum(probe.getlength(c) for c in text) + track * 400 * (len(text) - 1)
    size = int(400 * width_px / adv)
    font = ImageFont.truetype(FONT, size * ss)
    asc, desc = font.getmetrics()
    bb = font.getbbox(text[0])
    cap = (bb[3] - bb[1]) / ss  # altura da maiúscula em px
    pad = int(cap * 0.35)
    w = int(width_px + 2 * pad)
    h = int(cap + 2 * pad + cap * 0.15)
    pil = Image.new("L", (w * ss, h * ss), 0)
    dr = ImageDraw.Draw(pil)
    x = pad * ss
    for c in text:
        dr.text((x, pad * ss - bb[1]), c, font=font, fill=255)
        x += font.getlength(c) + track * size * ss
    m = cv2.resize(np.asarray(pil, np.float32) / 255, (w, h), interpolation=cv2.INTER_AREA)
    mb = (m > 0.5).astype(np.uint8)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    rng = np.random.default_rng(seed)

    # ---- relevo: bisel arredondado (chanfro) e topo levemente abaulado
    dist = cv2.distanceTransform(mb, cv2.DIST_L2, 5)
    bw = cap * 0.075
    t = np.clip(dist / bw, 0, 1)
    hgt = np.sqrt(1 - (1 - t) ** 2)  # perfil arredondado
    hgt = cv2.GaussianBlur(hgt, (0, 0), cap * 0.004 + 0.6)
    gx = cv2.Sobel(hgt, cv2.CV_32F, 1, 0, ksize=3) * (bw * 0.55) / 8
    gy = cv2.Sobel(hgt, cv2.CV_32F, 0, 1, ksize=3) * (bw * 0.55) / 8
    n = np.dstack([-gx, -gy, np.ones_like(gx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)

    # ---- reflexo do ambiente (céu claro, horizonte escuro, chão quente) — o "ouro de verdade"
    # direção refletida aproximada pela normal + curvatura falsa ao longo da altura da letra
    vy = (yy - pad) / cap  # 0 topo da letra → 1 base
    ry = np.clip(-n[..., 1] * 1.6 + (vy - 0.5) * 1.15, -1.2, 1.4)
    env = _ramp(ry, [(-1.2, (1.00, 0.97, 0.88)), (-0.35, (1.00, 0.90, 0.62)), (0.05, (0.95, 0.70, 0.30)),
                     (0.22, (0.36, 0.20, 0.06)), (0.40, (0.55, 0.33, 0.10)), (0.75, (0.98, 0.80, 0.42)),
                     (1.4, (0.75, 0.50, 0.20))])
    rx = n[..., 0]
    env *= (1 + 0.18 * rx)[..., None]  # lado esquerdo/direito do bisel com tons diferentes

    # ---- metal escovado + micro-arranhões
    brush = cv2.GaussianBlur(rng.standard_normal((h, w)).astype(np.float32), (0, 0), sigmaX=cap * 0.08, sigmaY=0.6)
    brush = brush / (brush.std() + 1e-6)
    scratches = np.zeros((h, w), np.float32)
    for _ in range(140):
        x0, y0 = rng.random() * w, rng.random() * h
        ang = rng.normal(0, 0.25)
        ln = cap * (0.05 + 0.25 * rng.random())
        cv2.line(scratches, (int(x0), int(y0)), (int(x0 + np.cos(ang) * ln), int(y0 + np.sin(ang) * ln)),
                 float(0.4 + 0.6 * rng.random()), 1, cv2.LINE_AA)
    scratches = cv2.GaussianBlur(scratches, (0, 0), 0.5)

    # ---- iluminação: luz principal quente de cima/esquerda + contraluz
    L = np.float32([-0.45, -0.70, 0.55])
    L /= np.linalg.norm(L)
    Hv = L + np.float32([0, 0, 1])
    Hv /= np.linalg.norm(Hv)
    nh = np.clip((n * Hv).sum(2), 0, 1)
    spec = nh ** 60 * 1.2 + nh ** 12 * 0.25
    L2 = np.float32([0.7, 0.3, 0.6])
    L2 /= np.linalg.norm(L2)
    rim = np.clip((n * L2).sum(2), 0, 1) ** 6 * 0.35
    albedo = np.float32([1.0, 0.85, 0.52])
    face = env * albedo * 1.08
    face *= (1 + 0.035 * brush + 0.08 * scratches)[..., None]
    face += (spec[..., None] * np.float32([1.0, 0.95, 0.82]) + rim[..., None] * np.float32([1.0, 0.85, 0.55]))
    # oclusão nas junções internas do bisel
    ao = 0.75 + 0.25 * np.clip(dist / (bw * 0.35), 0, 1)
    face *= ao[..., None]
    # filete claro na quina externa superior
    edge = np.clip(cv2.dilate(m, np.ones((3, 3), np.uint8)) - cv2.erode(m, np.ones((3, 3), np.uint8)), 0, 1)
    face += (edge * np.clip(-n[..., 1], 0, 1) * 0.35)[..., None] * np.float32([1.0, 0.92, 0.7])
    face = np.clip(face, 0, 1.6)

    # ---- extrusão (profundidade) para baixo/direita com escurecimento e luz lateral
    depth = int(cap * 0.10)
    rgbp = np.zeros((h, w, 3), np.float32)
    alpha = np.zeros((h, w), np.float32)
    for k in range(depth, 0, -1):
        M = np.float32([[1, 0, k * 0.30], [0, 1, k * 0.95]])
        lay = cv2.warpAffine(m, M, (w, h))
        tt = k / depth
        col = _ramp(np.float32([tt]), [(0, (0.62, 0.40, 0.14)), (0.5, (0.36, 0.21, 0.06)), (1, (0.16, 0.09, 0.03))])[0]
        band = 1 + 0.25 * np.sin(yy / cap * 9 + k * 0.05)  # leve reflexo nas laterais
        a = lay[..., None]
        rgbp = rgbp * (1 - a) + (col * band[..., None]) * a
        alpha = np.maximum(alpha, lay)
    # sombra de contato logo abaixo da face
    cs = cv2.GaussianBlur(cv2.warpAffine(m, np.float32([[1, 0, 0], [0, 1, cap * 0.03]]), (w, h)), (0, 0), cap * 0.02)
    rgbp *= (1 - 0.35 * cs * (1 - m))[..., None]
    a = m[..., None]
    rgbp = rgbp * (1 - a) + face * a
    alpha = np.maximum(alpha, m)
    # sombra projetada macia atrás (sobre o céu) + brilho dourado leve
    sh = cv2.GaussianBlur(cv2.warpAffine(alpha, np.float32([[1, 0, cap * 0.04], [0, 1, cap * 0.07]]), (w, h)),
                          (0, 0), cap * 0.05) * 0.45
    glow = cv2.GaussianBlur(m, (0, 0), cap * 0.10) * 0.22
    ext = np.clip(sh + glow - sh * glow, 0, 1) * (1 - alpha)
    ext_rgb = (np.float32([0.10, 0.06, 0.02]) * sh[..., None] + np.float32([1.0, 0.80, 0.45]) * glow[..., None])
    ext_rgb = ext_rgb / np.maximum((sh + glow)[..., None], 1e-4)
    rgbp = rgbp * alpha[..., None] + ext_rgb * ext[..., None]
    alpha = alpha + ext
    # máscara onde o reflexo animado passa (face + quinas do bisel)
    shine = m * (0.6 + 0.4 * np.clip(1 - t, 0, 1))
    return dict(rgbp=rgbp.astype(np.float32), a=alpha.astype(np.float32), shine=shine.astype(np.float32),
                cap=cap, w=w, h=h, pad=pad)


if __name__ == "__main__":
    g = make_god(1600)
    bg = np.zeros((g["h"], g["w"], 3), np.float32)
    bg[:] = np.linspace(0.75, 0.45, g["h"])[:, None, None] * np.float32([0.85, 0.80, 0.70])
    out = bg * (1 - g["a"][..., None]) + g["rgbp"]
    cv2.imwrite(os.path.join(ROOT, "saida", "god_test.png"), (np.clip(out, 0, 1)[..., ::-1] * 255).astype(np.uint8))

#!/usr/bin/env python3
"""Gera assets/models/guerreiro_cutscene.obj (+ .mtl).

Busto de guerreiro de cabelo longo com espada serrilhada, modelado a partir dos
prints de referencia (vista frontal, costas e laterais). Eixo Y para cima, +Z e a
frente do personagem, base da saia em y=0. Sem esferas: o corpo e feito por
secoes superelipticas (quadradas/anatomicas) com relevo de musculos.
"""
import os
import numpy as np
from scipy.interpolate import CubicSpline

rng = np.random.default_rng(11)
SCALE = 0.42                      # unidades de projeto -> ~2.0 de altura total
parts = []                        # (nome, verts, faces)


def gauss(x, s):
    return np.exp(-(x / s) ** 2)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def superellipse(a, b, n, N):
    ph = np.linspace(0, 2 * np.pi, N, endpoint=False)
    c, s = np.cos(ph), np.sin(ph)
    return a * np.sign(c) * np.abs(c) ** (2 / n), b * np.sign(s) * np.abs(s) ** (2 / n)


def loft(rings, cap_a=True, cap_b=True):
    R = np.array(rings); m, N = R.shape[:2]
    v = R.reshape(-1, 3).tolist(); f = []
    for i in range(m - 1):
        for k in range(N):
            a = i * N + k; b = i * N + (k + 1) % N
            f += [[a, b, b + N], [a, b + N, a + N]]
    for flag, idx in ((cap_a, 0), (cap_b, m - 1)):
        if flag:
            v.append(R[idx].mean(0).tolist()); c = len(v) - 1
            for k in range(N):
                f.append([c, idx * N + (k + 1) % N, idx * N + k] if idx == 0
                         else [c, idx * N + k, idx * N + (k + 1) % N])
    return np.array(v), f


def add(name, v, f):
    v = np.asarray(v, float); F = np.array(f)
    t = v[F]; vol = np.einsum('ij,ij->i', t[:, 0], np.cross(t[:, 1], t[:, 2])).sum()
    if vol < 0:
        F = F[:, ::-1]
    parts.append((name, v, F.tolist()))


def keyframes(ys, **kw):
    return {k: (lambda y, arr=np.array(val, float): np.interp(y, ys, arr)) for k, val in kw.items()}


def body_loft(ys_dense, ys, a, b, zc, n, xc=None, N=96, disp=None):
    K = keyframes(ys, a=a, b=b, zc=zc, n=n)
    rings = []
    for y in ys_dense:
        ex, ez = superellipse(K['a'](y), K['b'](y), K['n'](y), N)
        r = np.stack([ex, np.full(N, y), ez + K['zc'](y)], 1)
        if disp is not None:
            d = disp(r[:, 0], r[:, 1], r[:, 2] - K['zc'](y))
            dirv = np.stack([ex, ez], 1); dirv /= np.linalg.norm(dirv, axis=1, keepdims=True) + 1e-9
            r[:, 0] += d * dirv[:, 0]; r[:, 2] += d * dirv[:, 1]
        rings.append(r)
    return rings


def limb(path, w, h, n=2.6, seg=40, closed_end=True, ys_noise=0.0):
    path = np.asarray(path, float)
    t = np.r_[0, np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))]
    cs = CubicSpline(t, path, bc_type='natural'); u = np.linspace(0, t[-1], 28); P = cs(u)
    W = np.interp(u, t, np.broadcast_to(w, (len(path),)) if np.ndim(w) == 0 else np.interp(t, np.linspace(0, t[-1], len(w)), w))
    Hh = np.interp(u, t, np.broadcast_to(h, (len(path),)) if np.ndim(h) == 0 else np.interp(t, np.linspace(0, t[-1], len(h)), h))
    ex, ez = superellipse(1, 1, n, seg)
    T = cs(u, 1); T /= np.linalg.norm(T, axis=1, keepdims=True)
    nrm = np.cross(T[0], [0, 0, 1.0] if abs(T[0][2]) < .9 else [1.0, 0, 0]); nrm /= np.linalg.norm(nrm)
    rings = []
    for i in range(len(u)):
        nrm = nrm - T[i] * np.dot(nrm, T[i]); nrm /= np.linalg.norm(nrm); bi = np.cross(T[i], nrm)
        jit = 1 + ys_noise * rng.uniform(-1, 1, seg) if ys_noise else 1
        rings.append(P[i] + (np.outer(ex, nrm) * W[i] + np.outer(ez, bi) * Hh[i]) * np.atleast_1d(jit)[:, None])
    return loft(rings, True, closed_end)


def strip(path, w, t, seg=4, jag=0.0):
    """Mecha/lamina achatada: secao em losango."""
    return limb(path, w, t, n=2.0, seg=seg, ys_noise=jag)


# ---------------- torso (peitoral, abdomen, costas) ----------------
def torso_disp(x, y, z):
    ax = np.abs(x); front = smoothstep(0.0, 0.25, z); back = smoothstep(0.0, 0.25, -z)
    d = np.zeros_like(x)
    for s in (-1, 1):                                    # peitorais
        d += 0.075 * gauss((x - s * 0.31) / 0.30, 1) * gauss((y - 3.18) / 0.20, 1) * front
    d -= 0.040 * gauss((y - 2.97) / 0.03, 1) * smoothstep(0.05, 0.12, ax) * (1 - smoothstep(0.5, 0.62, ax)) * front
    for yy in (2.80, 2.52, 2.24):                        # abdomen
        d -= 0.030 * gauss((y - yy) / 0.025, 1) * (1 - smoothstep(0.22, 0.30, ax)) * front
    d -= 0.035 * gauss(x / 0.02, 1) * smoothstep(2.05, 2.15, y) * (1 - smoothstep(2.95, 3.05, y)) * front
    d -= 0.030 * gauss(x / 0.02, 1) * smoothstep(3.0, 3.25, y) * front * (1 - smoothstep(3.3, 3.55, y)) * 0.8
    d -= 0.025 * gauss((y - (3.52 - 0.12 * ax)) / 0.02, 1) * smoothstep(0.1, 0.2, ax) * front   # claviculas
    d -= 0.030 * gauss(x / 0.02, 1) * smoothstep(1.9, 2.1, y) * back                            # coluna
    for s in (-1, 1):
        d += 0.06 * gauss((x - s * 0.36) / 0.20, 1) * gauss((y - 3.05) / 0.25, 1) * back        # omoplatas
        d += 0.03 * gauss((x - s * 0.42) / 0.14, 1) * gauss((y - 2.35) / 0.35, 1) * front * 0.6  # obliquos
    return d


ys = [1.80, 2.05, 2.45, 2.85, 3.20, 3.45, 3.62, 3.75, 3.88]
ty = np.linspace(1.80, 3.88, 150)
rings = body_loft(ty, ys,
                  a=[.64, .58, .57, .62, .74, .84, .78, .34, .20],
                  b=[.40, .36, .34, .36, .42, .40, .34, .26, .20],
                  zc=[.00, .00, .02, .04, .05, .03, .0, .0, .02],
                  n=[2.6, 2.6, 2.7, 2.7, 2.6, 2.5, 2.4, 2.3, 2.2], N=128, disp=torso_disp)
add("torso", *loft(rings))

# pescoco + trapezio
add("pescoco", *loft(body_loft(np.linspace(3.7, 4.12, 14), [3.7, 4.12], a=[.22, .19], b=[.2, .18], zc=[.02, .05], n=[2.3, 2.3], N=40)))

# ---------------- cabeca (mandibula, macas do rosto, cranio) ----------------
def head_disp(x, y, z):
    front = smoothstep(0.0, 0.12, z); d = np.zeros_like(x)
    d += 0.05 * gauss(x / 0.04, 1) * gauss((y - 4.03) / 0.09, 1) * front            # nariz
    for s in (-1, 1):
        d -= 0.025 * gauss((x - s * 0.1) / 0.05, 1) * gauss((y - 4.2) / 0.025, 1) * front  # olhos
    d += 0.02 * gauss((y - 4.26) / 0.02, 1) * front                                  # arcada
    return d


hy = [3.70, 3.78, 3.92, 4.10, 4.30, 4.48, 4.62, 4.72]
rings = body_loft(np.linspace(3.70, 4.72, 46), hy,
                  a=[.06, .14, .20, .245, .255, .235, .17, .06],
                  b=[.07, .15, .19, .215, .225, .21, .16, .06],
                  zc=[.14, .11, .07, .03, .02, .0, -.02, -.02],
                  n=[2.3, 2.4, 2.5, 2.5, 2.4, 2.3, 2.2, 2.2], N=56, disp=head_disp)
add("cabeca", *loft(rings))

# ---------------- bracos (sem articulacao esferica: tubos continuos) ----------------
d_w = [.30, .33, .29, .24, .22, .20, .18, .16]
d_h = [.27, .30, .27, .22, .20, .18, .15, .14]
add("braco_dir_personagem", *limb([[.40, 3.55, 0], [.82, 3.38, 0], [.95, 2.85, .02], [.92, 2.30, .12],
                                   [.82, 1.98, .42], [.68, 1.84, .78]], d_w[:6], d_h[:6], n=2.7))
add("braco_esq_personagem", *limb([[-.40, 3.55, 0], [-.82, 3.38, .04], [-1.0, 2.95, .26], [-.96, 2.62, .52],
                                   [-.98, 3.00, .78], [-1.06, 3.40, .78]], [.30, .33, .29, .23, .19, .16], [.27, .30, .27, .21, .17, .14], n=2.7))
add("punho", *limb([[-1.08, 3.42, .76], [-1.08, 3.58, .76], [-1.08, 3.82, .76]], [.17, .20, .15], [.15, .17, .13], n=3.4))

# ---------------- saia rasgada ----------------
def skirt():
    N, M = 144, 22
    ph = np.linspace(0, 2 * np.pi, N, endpoint=False); v = []
    teeth = (np.abs(((ph * 9 / (2 * np.pi)) % 1) - .5) * 2)                # dentes triangulares
    hem = .22 + .34 * teeth ** 1.3 + .12 * np.abs(np.sin(ph * 23 + 1)) + .06 * rng.random(N)
    for i in range(M + 1):
        t = i / M
        y = 2.02 - t * (2.02 - hem)
        r = .60 + 1.00 * t ** 1.15
        fold = 1 + (.03 + .09 * t) * np.cos(ph * 26) + .05 * t * np.cos(ph * 9 + .6)
        v.append(np.stack([r * 1.02 * np.cos(ph) * fold, y, r * .70 * np.sin(ph) * fold], 1))
    return loft(v, True, True)


add("saia", *skirt())
ph = np.linspace(0, 2 * np.pi, 5)
ex, ez = superellipse(1, 1, 2.4, 96)
ring = lambda y, a, b: np.stack([a * ex, np.full(96, y), b * ez], 1)
add("faixa", *loft([ring(1.92, .64, .44), ring(1.98, .68, .47), ring(2.14, .68, .47), ring(2.22, .62, .42)]))
for k, (x0, dx) in enumerate(((.55, .18), (.62, .38))):                       # pontas da faixa
    add(f"faixa_ponta{k}", *strip([[x0, 2.05, .45], [x0 + dx * .5, 1.5, .52], [x0 + dx, .95, .55 + .1 * k]], [.09, .08, .05], [.02, .02, .015], seg=4))
for k in range(16):                                                            # tiras rasgadas
    a = rng.uniform(0, 2 * np.pi); r = 1.35 + rng.uniform(-.2, .15)
    s = np.array([r * 1.02 * np.cos(a), .45, r * .7 * np.sin(a)]); L = rng.uniform(.25, .6)
    add(f"retalho{k}", *strip([s, s + [0.03 * np.cos(a), -L * .5, .02], s + [.06 * np.cos(a), -L, .04]], [.1, .08, 0.0], [.02, .02, .0], seg=4))

# ---------------- cabelo: mechas achatadas (nada de volume redondo) ----------------
add("cabelo_calota", *loft(body_loft(np.linspace(4.30, 4.80, 20), [4.30, 4.55, 4.70, 4.80],
                                      a=[.275, .27, .20, .05], b=[.255, .25, .19, .05], zc=[.02, -.01, -.02, -.02],
                                      n=[2.4, 2.3, 2.2, 2.2], N=56)))
for i in range(230):
    ang = rng.uniform(0, 2 * np.pi); r = rng.uniform(.04, .26)
    st = np.array([r * np.cos(ang), 4.72 - 0.9 * (r / .27) ** 2 + rng.uniform(-.03, .03), r * np.sin(ang) * .95 + .01])
    right = np.cos(ang) + rng.uniform(-.7, .9) > 0
    L = rng.uniform(1.4, 3.3)
    dx = (rng.uniform(.5, 2.1) if right else rng.uniform(-.55, -.1))
    end = st + np.array([dx * (1 + .3 * L / 3), -L * rng.uniform(.75, 1.0) - 0.3, -rng.uniform(.1, .85)])
    ctrl = [st, st + [.30 * np.sign(st[0] or 1) + dx * .12, -.30, -.02 + .10 * np.sin(ang)],
            (st + end) / 2 + [dx * .25, .1, -.18], end]
    add(f"mecha{i}", *strip(ctrl, np.interp(np.linspace(0, 1, 6), [0, .25, 1], [.11, .16, .0]), .024, seg=4, jag=.12))
for i in range(16):                                                           # franja sobre o rosto
    x = -.22 + .44 * i / 15
    s = np.array([x, 4.74 - .5 * abs(x), .12]); e = np.array([x * 1.35 + rng.uniform(-.04, .04), 3.98 + rng.uniform(-.1, .18), .34])
    add(f"franja{i}", *strip([s, [x * 1.1, 4.58, .30], e], [.075, .08, .0], .018, seg=4))

# ---------------- espada serrilhada ----------------
stem = np.array([[-2.85, -.62, 2.10], [-2.30, 1.00, 1.55], [-1.55, 2.50, 1.05], [-1.08, 3.65, .76],
                 [-.82, 4.85, -.15], [-.52, 5.75, -.85], [-.34, 6.30, -1.40]])
add("espada_haste", *strip(stem, [.03, .30, .32, .26, .22, .12, .02], [.05, .08, .09, .08, .07, .05, .02], seg=4, jag=.12))
arc = [[-.88, 4.95, -.30], [-.30, 5.62, -.55], [.60, 5.82, -.72], [1.50, 5.46, -.84], [2.12, 4.50, -.92]]
add("espada_arco", *strip(arc, [.22, .21, .16, .10, .015], [.06, .06, .05, .04, .01], seg=4, jag=.12))
cs = CubicSpline(np.r_[0, np.cumsum(np.linalg.norm(np.diff(stem, axis=0), axis=1))], stem)
ts = np.linspace(.4, cs.x[-1] - .3, 16)
for k, t0 in enumerate(ts):                                                    # espinhos da lamina
    p = cs(t0); tg = cs(t0, 1); tg /= np.linalg.norm(tg)
    sd = np.cross(tg, [0, 0, 1.0]); sd /= np.linalg.norm(sd); sd *= rng.choice([-1, 1])
    tip = p + (sd * .8 + tg * .5) * rng.uniform(.25, .55) + [0, 0, rng.uniform(-.1, .1)]
    add(f"espinho{k}", *strip([p, (p + tip) / 2, tip], [.07, .045, .0], [.03, .02, .0], seg=4))
for k in range(8):                                                             # espinhos do arco
    t = rng.uniform(.1, .9); idx = np.interp(t, [0, 1], [0, len(arc) - 1]); i0 = int(idx)
    p = np.array(arc[i0]) + (np.array(arc[min(i0 + 1, 4)]) - np.array(arc[i0])) * (idx - i0)
    tip = p + [rng.uniform(-.15, .15), rng.uniform(.15, .45), 0]
    add(f"espinho_arco{k}", *strip([p, (p + tip) / 2, tip], [.05, .03, 0], [.025, .02, 0], seg=4))


# ---------------- exporta ----------------
def export():
    V = []; faces = []; groups = []
    for name, v, f in parts:
        off = len(V); V += (np.asarray(v) * SCALE).tolist()
        fl = [[i + off for i in tri] for tri in f]; faces += fl; groups.append((name, fl))
    V = np.array(V); N = np.zeros_like(V)
    for a, b, c in faces:
        nn = np.cross(V[b] - V[a], V[c] - V[a]); N[a] += nn; N[b] += nn; N[c] += nn
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "models")
    os.makedirs(root, exist_ok=True)
    with open(os.path.join(root, "guerreiro_cutscene.mtl"), "w") as m:
        m.write("newmtl pedra\nKa 0.8 0.8 0.8\nKd 0.78 0.78 0.80\nKs 0.05 0.05 0.05\nNs 10\nd 1.0\nillum 2\n")
    with open(os.path.join(root, "guerreiro_cutscene.obj"), "w") as o:
        o.write("# Guerreiro (busto) - tools/gen_guerreiro_obj.py\n# Y para cima, +Z frente, base da saia em y=0\n"
                "mtllib guerreiro_cutscene.mtl\nusemtl pedra\n")
        for x, y, z in V: o.write(f"v {x:.4f} {y:.4f} {z:.4f}\n")
        for x, y, z in N: o.write(f"vn {x:.4f} {y:.4f} {z:.4f}\n")
        for name, fl in groups:
            o.write(f"g {name}\ns 1\n")
            for a, b, c in fl: o.write(f"f {a+1}//{a+1} {b+1}//{b+1} {c+1}//{c+1}\n")
    print(len(V), "vertices,", len(faces), "faces,", "bbox", V.min(0).round(2), V.max(0).round(2))


export()

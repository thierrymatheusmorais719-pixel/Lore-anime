#!/usr/bin/env python3
"""Escultura procedural dos corpos de criatura (malhas de verdade, sem blocos nem "massinha").
Para cada parte do corpo em CreatureRigs.json gera uma malha lisa:
  • membros: superfície "lofted" ao longo do osso com seção quase elíptica e perfil de músculo
    (deltoide/bíceps no braço, antebraço que afina no punho, coxa, panturrilha atrás), pontas
    arredondadas que se sobrepõem à parte vizinha → cotovelo/joelho contínuos
  • tronco: cintura → peitoral largo → trapézio; estilo "ogre" com barriga saliente
  • mãos, pés, cabeça: superelipsoides (cantos arredondados, sem cara de bloco)
Saída: src/shared/Config/CreatureMeshes.luau (vértices/triângulos no espaço da parte), lido pelo
cliente (CreatureSkin) para montar MeshParts com EditableMesh. Uso: python3 sculpt.py"""
import json, math, os

import numpy as np

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, "..", ".."))
SOURCE = os.path.join(root, "src", "shared", "Config", "CreatureRigs.json")
DEST = os.path.join(root, "src", "shared", "Config", "CreatureMeshes.luau")

# estilo do tronco e intensidade dos músculos por corpo
STYLE = {
    "HollowGrunt": {"torso": "lean", "muscle": 0.9},
    "HollowFeral": {"torso": "lean", "muscle": 1.0},
    "HollowBrute": {"torso": "ogre", "muscle": 1.25},
    "HollowHound": {"torso": "beast", "muscle": 0.9},
}
SIDES = 20
RINGS = 18

# perfis: (t, largura, profundidade, deslocamento p/ frente) — t = 0 na junta de cima (proximal)
PROFILES = {
    "UpperArm": [(0.0, 0.92, 0.95, 0.0), (0.18, 1.06, 1.0, 0.0), (0.42, 1.08, 1.12, 0.08), (0.72, 0.88, 0.92, 0.02), (1.0, 0.78, 0.8, 0.0)],
    "LowerArm": [(0.0, 0.86, 0.86, 0.0), (0.22, 1.06, 1.04, 0.02), (0.55, 0.92, 0.9, 0.0), (1.0, 0.7, 0.68, 0.0)],
    "UpperLeg": [(0.0, 1.0, 1.0, 0.0), (0.3, 1.08, 1.1, 0.06), (0.7, 0.92, 0.92, 0.02), (1.0, 0.8, 0.82, 0.0)],
    "LowerLeg": [(0.0, 0.84, 0.86, 0.0), (0.3, 1.0, 1.1, -0.1), (0.75, 0.74, 0.76, -0.02), (1.0, 0.66, 0.68, 0.0)],
    "Tail": [(0.0, 1.0, 1.0, 0.0), (0.5, 0.86, 0.86, 0.0), (1.0, 0.62, 0.62, 0.0)],
}
TORSO = {
    # t = 0 embaixo (cintura) → 1 em cima (ombros)
    "lean": [(0.0, 0.82, 0.86, 0.0), (0.35, 0.86, 0.92, 0.02), (0.7, 1.04, 1.0, 0.08), (0.88, 1.0, 0.96, 0.04), (1.0, 0.72, 0.8, -0.02)],
    "ogre": [(0.0, 0.96, 1.05, 0.12), (0.25, 1.02, 1.22, 0.28), (0.5, 1.0, 1.12, 0.2), (0.78, 1.04, 0.98, 0.06), (1.0, 0.78, 0.82, 0.0)],
    "beast": [(0.0, 0.8, 0.86, 0.0), (0.4, 0.95, 1.0, 0.0), (0.8, 1.04, 1.04, 0.05), (1.0, 0.82, 0.86, 0.0)],
}
HIPS = [(0.0, 0.92, 0.9, 0.0), (0.5, 1.04, 1.04, 0.0), (1.0, 0.94, 0.95, 0.0)]


def interp(profile, t):
    for i in range(len(profile) - 1):
        a, b = profile[i], profile[i + 1]
        if t <= b[0]:
            u = (t - a[0]) / max(1e-6, b[0] - a[0])
            u = u * u * (3 - 2 * u)
            return [a[k] + (b[k] - a[k]) * u for k in range(1, 4)]
    return list(profile[-1][1:])


def superellipse(angle, rx, rz, n=2.6):
    c, s = math.cos(angle), math.sin(angle)
    x = rx * math.copysign(abs(c) ** (2 / n), c)
    z = rz * math.copysign(abs(s) ** (2 / n), s)
    return x, z


def loft(length, rx, rz, profile, muscle, n=2.6):
    """Superfície ao longo de Y: t=0 (proximal) em +Y, t=1 (distal) em -Y. Frente = -Z.
    Pontas em calota que avançam um pouco além do osso para sobrepor a parte vizinha."""
    verts, tris = [], []
    cap = min(rx, rz) * 0.6
    span = max(0.05, length - cap * 1.1)
    stations = []
    cap_steps = 4
    for i in range(cap_steps):
        ang = (i / cap_steps) * (math.pi / 2)
        stations.append((0.0, math.sin(ang), span / 2 + cap * math.cos(ang)))
    for i in range(RINGS + 1):
        t = i / RINGS
        stations.append((t, 1.0, span / 2 - span * t))
    for i in range(1, cap_steps + 1):
        ang = (i / cap_steps) * (math.pi / 2)
        stations.append((1.0, math.cos(ang), -span / 2 - cap * math.sin(ang)))
    rings, centers = [], []
    for t, scale, y in stations:
        w, d, f = interp(profile, t)
        w, d = 1 + (w - 1) * muscle, 1 + (d - 1) * muscle
        ring = []
        zc = -f * rz * muscle
        for k in range(SIDES):
            ang = k / SIDES * math.pi * 2
            x, z = superellipse(ang, rx * w * max(scale, 0.04), rz * d * max(scale, 0.04), n)
            ring.append(len(verts))
            verts.append((x, y, z + zc))
        rings.append(ring)
        centers.append((0.0, y, zc))
    top = len(verts)
    verts.append((0.0, span / 2 + cap, -interp(profile, 0.0)[2] * rz * muscle))
    bottom = len(verts)
    verts.append((0.0, -span / 2 - cap, -interp(profile, 1.0)[2] * rz * muscle))
    for r in range(len(rings) - 1):
        for k in range(SIDES):
            p0, p1 = rings[r][k], rings[r][(k + 1) % SIDES]
            q0, q1 = rings[r + 1][k], rings[r + 1][(k + 1) % SIDES]
            tris += [(p0, q0, p1), (p1, q0, q1)]
    for k in range(SIDES):
        tris.append((top, rings[0][k], rings[0][(k + 1) % SIDES]))
        tris.append((bottom, rings[-1][(k + 1) % SIDES], rings[-1][k]))
    # eixo para orientar as faces para fora: segmento entre os centros das pontas
    axis = (verts[top], verts[bottom])
    return verts, tris, axis


def orient_outward(verts, tris, axis=None):
    """Garante normais (b-a)x(c-a) apontando para fora do eixo (ou do centro)."""
    out = []
    if axis:
        a0, a1 = np.array(axis[0]), np.array(axis[1])
        seg = a1 - a0
        L2 = float(seg @ seg) or 1.0
    center = np.mean(np.array(verts), axis=0)
    for a, b, c in tris:
        A, B, C = np.array(verts[a]), np.array(verts[b]), np.array(verts[c])
        n = np.cross(B - A, C - A)
        cen = (A + B + C) / 3
        if axis:
            t = max(0.0, min(1.0, float((cen - a0) @ seg) / L2))
            ref = cen - (a0 + seg * t)
        else:
            ref = cen - center
        out.append((a, b, c) if float(n @ ref) >= 0 else (a, c, b))
    return out


def rot_x_neg90(verts):
    """(x, y, z) → (x, z, -y): o eixo Y da malha passa a correr em -Z (rotação própria)."""
    return [(x, z, -y) for x, y, z in verts]


def superellipsoid(sx, sy, sz, n=3.2, lat=10, lon=16):
    verts, tris = [], []
    for i in range(lat + 1):
        v = -math.pi / 2 + math.pi * i / lat
        cv, sv = math.cos(v), math.sin(v)
        for j in range(lon):
            u = 2 * math.pi * j / lon
            cu, su = math.cos(u), math.sin(u)
            f = lambda c: math.copysign(abs(c) ** (2 / n), c)
            verts.append((sx * f(cv) * f(cu), sy * f(sv), sz * f(cv) * f(su)))
    for i in range(lat):
        for j in range(lon):
            a, b = i * lon + j, i * lon + (j + 1) % lon
            c, d = (i + 1) * lon + j, (i + 1) * lon + (j + 1) % lon
            tris += [(a, b, c), (b, d, c)]
    return verts, tris


def mesh_for(body_name, body, part):
    style = STYLE.get(body_name)
    if not style:
        return None
    name = part["name"]
    sx, sy, sz = part["size"]
    feet = body["declarations"].get("feet")
    quad = isinstance(feet, list) and "RightHand" in feet
    kind = next((k for k in PROFILES if k in name), None)
    m = style["muscle"]
    if kind == "Tail":
        # cauda corre em Z, junta no -Z da parte (proximal) → loft com proximal em +Y girado p/ -Z
        verts, tris, axis = loft(sz, sx / 2, sy / 2, PROFILES["Tail"], 1.0)
        verts = rot_x_neg90(verts)
        axis = tuple(rot_x_neg90([axis[0], axis[1]]))
        return verts, orient_outward(verts, tris, axis)
    if kind:
        # membros pendem da junta no +Y: proximal em cima
        verts, tris, axis = loft(sy, sx / 2, sz / 2, PROFILES[kind], m)
        return verts, orient_outward(verts, tris, axis)
    if name in ("UpperTorso", "LowerTorso"):
        profile = TORSO[style["torso"]] if name == "UpperTorso" else HIPS
        if quad:
            # tronco deitado: t=0 atrás (+Z) → peito na frente (-Z); "frente" do perfil = barriga (baixo)
            verts, tris, axis = loft(sz, sx / 2, sy / 2, list(reversed([(1 - t, w, d, f) for t, w, d, f in profile])), 1.0)
            verts = rot_x_neg90(verts)  # proximal (peito) vai para a frente (-Z); a "frente" do loft vira baixo
            axis = tuple(rot_x_neg90([axis[0], axis[1]]))
            return verts, orient_outward(verts, tris, axis)
        # tronco em pé: perfil vai da cintura (embaixo) aos ombros (em cima) → inverte t do loft
        flipped = [(1 - t, w, d, f) for t, w, d, f in reversed(profile)]
        verts, tris, axis = loft(sy, sx / 2, sz / 2, flipped, 1.0, n=2.9)
        return verts, orient_outward(verts, tris, axis)
    if name in ("Head", "Jaw") or "Hand" in name or "Foot" in name:
        verts, tris = superellipsoid(sx / 2, sy / 2, sz / 2, n=3.4 if ("Foot" in name or "Hand" in name) else 2.4)
        return verts, orient_outward(verts, tris)
    return None


# ------------------------------------------------------------------ máscaras de caveira
# Casca em domo na frente da cabeça (espaço da Head), com relevo: órbitas fundas (os olhos acesos
# e o fundo escuro ficam dentro delas), arcada da sobrancelha, maçãs do rosto, cavidade do nariz,
# boca rebaixada onde os dentes encaixam; a parte de baixo pode avançar (focinho). A borda dobra
# para trás (espessura aparente). Substitui as elipses marcadas com sculpt="Mask" em bodies.py.
MASKS = {
    "HollowGrunt": dict(cy=0.0, top=0.68, bottom=0.7, wtop=0.68, wbot=0.52, front=-0.95, back=-0.28, lean=0.0,
                        eyes=(0.27, 0.18, 0.17, 0.1), brow=(0.37, 0.05), cheek=(0.42, -0.1, 0.04),
                        nose=(-0.08, 0.06), mouth=(-0.22, -0.55, 0.42, 0.065), ridge=0.0, n=2.4),
    "HollowFeral": dict(cy=0.1, top=0.72, bottom=1.0, wtop=0.6, wbot=0.42, front=-0.98, back=-0.3, lean=0.24,
                        eyes=(0.28, 0.32, 0.13, 0.08), brow=(0.5, 0.05), cheek=(0.4, 0.05, 0.03),
                        nose=(-0.22, 0.04), mouth=(-0.28, -0.8, 0.36, 0.03), ridge=0.05, n=2.2,
                        teeth=(-0.54, 0.12, 0.045)),
}
MASK_RINGS, MASK_SIDES = 16, 40


def _g(x, y, cx, cy, sx, sy):
    return math.exp(-(((x - cx) / sx) ** 2 + ((y - cy) / sy) ** 2))


def _smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def mask_mesh(m):
    verts, tris = [], []
    depth = m["back"] - m["front"]

    def surface(x, y, rho):
        z = m["back"] - depth * max(0.0, 1 - rho * rho) ** 0.35
        k = 1 - rho ** 4  # relevo some na borda
        ex, ey, er, ed = m["eyes"]
        for sx_ in (ex, -ex):
            z += ed * k * _g(x, y, sx_, ey, er, er * 0.85)  # órbita
            z -= 0.03 * k * _g(x, y, sx_ * 1.15, ey + er * 1.1, er * 1.2, er * 0.45)  # arcada
        by, bh = m["brow"]
        z -= bh * k * _g(x, y, 0, by, 0.45, 0.1)
        cx_, cyy, ch = m["cheek"]
        for sx_ in (cx_, -cx_):
            z -= ch * k * _g(x, y, sx_, cyy, 0.15, 0.12)
        ny, nd = m["nose"]
        z += nd * k * _g(x, y, 0, ny, 0.07, 0.09)
        top, bot, half, md = m["mouth"]
        z += md * k * _smooth(top, top - 0.06, y) * _smooth(bot, bot + 0.06, y) * _smooth(half, half - 0.08, abs(x))
        if m.get("teeth"):
            # dentes em relevo: fileira de cima e de baixo, sulco fundo entre elas (a sombra faz a boca)
            line, spacing, amp = m["teeth"]
            band = _smooth(top, top - 0.06, y) * _smooth(bot, bot + 0.06, y) * _smooth(half, half - 0.06, abs(x))
            tooth = abs(math.cos(math.pi * x / spacing)) ** 0.6
            z -= amp * k * band * tooth
            z += 0.09 * k * band * math.exp(-((y - line) / 0.035) ** 2)
        if m["ridge"]:
            z -= m["ridge"] * k * math.exp(-(x / 0.12) ** 2) * _smooth(0.25, 0.0, y) * _smooth(-0.6, -0.3, y)
        if m["lean"]:
            z -= m["lean"] * max(0.0, m["cy"] - y)
        return z

    def outline(theta, rho):
        c, s_ = math.cos(theta), math.sin(theta)
        n = m["n"]
        w = m["wtop"] if s_ >= 0 else m["wbot"]
        # largura vai do topo à base suavemente (queixo mais estreito)
        w = m["wbot"] + (m["wtop"] - m["wbot"]) * _smooth(-0.6, 0.4, s_)
        h = m["top"] if s_ >= 0 else m["bottom"]
        x = w * rho * math.copysign(abs(c) ** (2 / n), c)
        y = m["cy"] + h * rho * math.copysign(abs(s_) ** (2 / n), s_)
        return x, y

    verts.append((0.0, m["cy"], surface(0.0, m["cy"], 0.0)))
    rings = []
    for i in range(1, MASK_RINGS + 1):
        rho = i / MASK_RINGS
        ring = []
        for j in range(MASK_SIDES):
            th = j / MASK_SIDES * math.pi * 2
            x, y = outline(th, rho)
            ring.append(len(verts))
            verts.append((x, y, surface(x, y, rho)))
        rings.append(ring)
    # dobra da borda para trás (dá espessura vista de lado)
    lip = []
    for j in range(MASK_SIDES):
        th = j / MASK_SIDES * math.pi * 2
        x, y = outline(th, 0.95)
        lip.append(len(verts))
        verts.append((x, y, m["back"] + 0.12 - (m["lean"] * max(0.0, m["cy"] - y))))
    rings.append(lip)
    for j in range(MASK_SIDES):
        tris.append((0, rings[0][j], rings[0][(j + 1) % MASK_SIDES]))
    for r in range(len(rings) - 1):
        for j in range(MASK_SIDES):
            a, b = rings[r][j], rings[r][(j + 1) % MASK_SIDES]
            c, d = rings[r + 1][j], rings[r + 1][(j + 1) % MASK_SIDES]
            tris += [(a, c, b), (b, c, d)]
    # orienta para a frente (-Z) pelo centro do domo atrás da casca
    center = np.array([0.0, m["cy"], m["back"] + 0.5])
    out = []
    for a, b, c in tris:
        A, B, C = np.array(verts[a]), np.array(verts[b]), np.array(verts[c])
        n_ = np.cross(B - A, C - A)
        out.append((a, b, c) if float(n_ @ ((A + B + C) / 3 - center)) >= 0 else (a, c, b))
    return verts, out


# ------------------------------------------------------------------ tubos (chifres, dedos, garras)
TUBE_SIDES = 10


def _euler_matrix(rx, ry, rz):
    rx, ry, rz = (math.radians(a) for a in (rx, ry, rz))
    X = np.array([[1, 0, 0], [0, math.cos(rx), -math.sin(rx)], [0, math.sin(rx), math.cos(rx)]])
    Y = np.array([[math.cos(ry), 0, math.sin(ry)], [0, 1, 0], [-math.sin(ry), 0, math.cos(ry)]])
    Z = np.array([[math.cos(rz), -math.sin(rz), 0], [math.sin(rz), math.cos(rz), 0], [0, 0, 1]])
    return X @ Y @ Z


def tube_groups(body):
    """{id: (parte, [pontos], [raios], ponta afiada)} a partir dos segmentos marcados em bodies.py."""
    groups = {}
    for d in body["decor"]:
        if "tube" not in d or "sculpt" not in d:
            continue
        groups.setdefault(d["sculpt"], []).append(d)
    out = {}
    for key, segs in groups.items():
        segs.sort(key=lambda d: d["tube"][1])
        pts, radii = [], []
        for i, d in enumerate(segs):
            o = d["offset"]
            R = _euler_matrix(o[3], o[4], o[5])
            zdir = R @ np.array([0.0, 0.0, 1.0])
            t = d["size"][0]
            length = d["size"][2] - t * 0.4
            c = np.array(o[:3])
            a, b = c - zdir * length / 2, c + zdir * length / 2
            if i == 0:
                pts.append(a)
                radii.append(t / 2)
            pts.append(b)
            radii.append(t / 2 * (0.8 if i == len(segs) - 1 else 1.0))
        out[key] = (segs[0]["part"], pts, radii, bool(segs[0]["tube"][2]))
    return out


def tube_mesh(pts, radii, sharp, sub=4):
    # Catmull-Rom pelos pontos → caminho liso; raio interpolado
    P = [pts[0] * 2 - pts[1]] + list(pts) + [pts[-1] * 2 - pts[-2]]
    path, rad = [], []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(sub):
            t = k / sub
            q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)
            path.append(q)
            rad.append(radii[i - 1] + (radii[i] - radii[i - 1]) * t)
    path.append(pts[-1])
    rad.append(radii[-1])
    if sharp:
        # afina até a ponta (último trecho cai a zero)
        n = len(path)
        for i in range(n):
            u = i / (n - 1)
            rad[i] *= 1 - _smooth(0.55, 1.0, u) * 0.97
    verts, tris = [], []
    # quadros por transporte paralelo
    tangent = lambda i: path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
    t0 = tangent(0) / (np.linalg.norm(tangent(0)) or 1)
    ref = np.array([0.0, 1.0, 0.0]) if abs(t0[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
    nrm = np.cross(t0, ref)
    nrm /= np.linalg.norm(nrm)
    rings = []
    prev_t = t0
    for i, c in enumerate(path):
        t = tangent(i)
        t = t / (np.linalg.norm(t) or 1)
        nrm = nrm - t * float(nrm @ t)
        nrm /= np.linalg.norm(nrm) or 1
        bn = np.cross(t, nrm)
        ring = []
        for k in range(TUBE_SIDES):
            a = k / TUBE_SIDES * math.pi * 2
            ring.append(len(verts))
            verts.append(tuple(c + (nrm * math.cos(a) + bn * math.sin(a)) * rad[i]))
        rings.append(ring)
        prev_t = t
    t_start = path[0] - path[1]
    t_start /= np.linalg.norm(t_start) or 1
    start = len(verts)
    verts.append(tuple(path[0] + t_start * rad[0] * 0.6))
    end = len(verts)
    t_end = path[-1] - path[-2]
    t_end /= np.linalg.norm(t_end) or 1
    verts.append(tuple(path[-1] + t_end * (rad[-1] * 0.6 if not sharp else 0.04)))
    for r in range(len(rings) - 1):
        for k in range(TUBE_SIDES):
            a, b = rings[r][k], rings[r][(k + 1) % TUBE_SIDES]
            c, d = rings[r + 1][k], rings[r + 1][(k + 1) % TUBE_SIDES]
            tris += [(a, c, b), (b, c, d)]
    for k in range(TUBE_SIDES):
        tris.append((start, rings[0][(k + 1) % TUBE_SIDES], rings[0][k]))
        tris.append((end, rings[-1][k], rings[-1][(k + 1) % TUBE_SIDES]))
    axis = (tuple(path[0]), tuple(path[-1]))
    # orienta para fora do caminho (ponto mais próximo do caminho, não da reta: tubos curvos)
    V = np.array(verts)
    Pth = np.array(path)
    out = []
    for a, b, c in tris:
        A, B, C = V[a], V[b], V[c]
        n_ = np.cross(B - A, C - A)
        cen = (A + B + C) / 3
        near = Pth[int(np.argmin(((Pth - cen) ** 2).sum(1)))]
        ref_ = cen - near
        if float(ref_ @ ref_) < 1e-10:
            ref_ = cen - Pth.mean(0)
        out.append((a, b, c) if float(n_ @ ref_) >= 0 else (a, c, b))
    return [tuple(float(x) for x in v) for v in verts], out


def _raycast(V, T, origin, direction):
    """Primeira interseção do raio com a malha (Möller–Trumbore vetorizado) ou None."""
    A, B, C = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
    e1, e2 = B - A, C - A
    h = np.cross(direction, e2)
    det = (e1 * h).sum(1)
    ok = np.abs(det) > 1e-9
    inv = np.where(ok, 1.0 / np.where(ok, det, 1), 0)
    sv = origin - A
    u = (sv * h).sum(1) * inv
    q = np.cross(sv, e1)
    v = (q * direction).sum(1) * inv
    t = (e2 * q).sum(1) * inv
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0)
    if not hit.any():
        return None
    return float(t[hit].min())


def mark_mesh(V, T, d, nu=3, nv=9, lift=0.02):
    """Gota pintada assentada na pele: grade no plano XY da marca (gira em Z), projetada ao longo de
    Z até a malha da parte e erguida um pouco para fora."""
    w, h = d["size"][0], d["size"][1]
    ox, oy, oz, rz = d["offset"][0], d["offset"][1], d["offset"][2], math.radians(d["offset"][5])
    direction = np.array([0.0, 0.0, 1.0 if oz < 0 else -1.0])
    verts, grid = [], []
    for j in range(nv):
        v = -1 + 2 * j / (nv - 1)
        width = math.sqrt(max(0.0, 1 - v * v)) * (0.8 - 0.35 * v)  # gota: ponta em cima, barriga embaixo
        row = []
        for i in range(nu):
            u = -1 + 2 * i / (nu - 1)
            lx, ly = u * w / 2 * width, -v * h / 2
            x = ox + lx * math.cos(rz) - ly * math.sin(rz)
            y = oy + lx * math.sin(rz) + ly * math.cos(rz)
            origin = np.array([x, y, -direction[2] * 5.0])
            t = _raycast(V, T, origin, direction)
            if t is None:
                return None
            z = origin[2] + direction[2] * t - direction[2] * lift
            row.append(len(verts))
            verts.append((x, y, z))
        grid.append(row)
    tris = []
    for j in range(nv - 1):
        for i in range(nu - 1):
            a, b, c, e = grid[j][i], grid[j][i + 1], grid[j + 1][i], grid[j + 1][i + 1]
            tris += [(a, c, b), (b, c, e)]
    out = []
    for a, b, c in tris:
        n_ = np.cross(np.array(verts[b]) - verts[a], np.array(verts[c]) - verts[a])
        out.append((a, b, c) if float(n_ @ -direction) >= 0 else (a, c, b))
    return verts, out


def overlays_for(body_name, body):
    """Malhas extras soldadas a uma parte, cada uma substituindo as peças marcadas com o mesmo id:
    [(id, parte, verts, tris)]."""
    if body_name not in STYLE:
        return []
    out = []
    if body_name in MASKS:
        v, t = mask_mesh(MASKS[body_name])
        out.append(("Mask", "Head", v, t))
    for key, (part, pts, radii, sharp) in sorted(tube_groups(body).items()):
        v, t = tube_mesh([np.array(p) for p in pts], radii, sharp)
        out.append((key, part, v, t))
    parts = {p["name"]: p for p in body["parts"]}
    meshes = {}
    for d in body["decor"]:
        if not d.get("conform") or "sculpt" not in d:
            continue
        if d["part"] not in meshes:
            res = mesh_for(body_name, body, parts[d["part"]])
            meshes[d["part"]] = (np.array(res[0]), np.array(res[1])) if res else None
        if meshes[d["part"]] is None:
            continue
        res = mark_mesh(*meshes[d["part"]], d)
        if res:
            out.append((d["sculpt"], d["part"], res[0], res[1]))
    return out


def fmt(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def main():
    rigs = json.load(open(SOURCE))
    out = ["-- GERADO por tools/creatures/sculpt.py — malhas esculpidas das criaturas (espaço local de",
           "-- cada parte). v = {x,y,z, ...}; t = {a,b,c, ...} (índices a partir de 1). Entradas com `part`",
           "-- são peças extras (máscara, tubos) que substituem os enfeites com o atributo Sculpt = chave.",
           "-- Não edite à mão.",
           "return {"]
    total_v = total_t = 0
    for body_name, body in rigs.items():
        if body_name not in STYLE:
            continue
        out.append(f'\t["{body_name}"] = {{')
        for part in body["parts"]:
            res = mesh_for(body_name, body, part)
            if not res:
                continue
            verts, tris = res
            total_v += len(verts)
            total_t += len(tris)
            vs = ",".join(fmt(c) for v in verts for c in v)
            ts = ",".join(str(i + 1) for t in tris for i in t)
            out.append(f'\t\t["{part["name"]}"] = {{ v = {{{vs}}}, t = {{{ts}}} }},')
        for key, part_name, verts, tris in overlays_for(body_name, body):
            total_v += len(verts)
            total_t += len(tris)
            vs = ",".join(fmt(c) for v in verts for c in v)
            ts = ",".join(str(i + 1) for t in tris for i in t)
            out.append(f'\t\t["{key}"] = {{ part = "{part_name}", v = {{{vs}}}, t = {{{ts}}} }},')
        out.append("\t},")
    out.append("}")
    open(DEST, "w").write("\n".join(out) + "\n")
    print(f"malhas: {total_v} vértices, {total_t} triângulos → {os.path.relpath(DEST, root)}")


if __name__ == "__main__":
    main()

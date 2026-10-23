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
SIDES = 14
RINGS = 14

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


def fmt(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def main():
    rigs = json.load(open(SOURCE))
    out = ["-- GERADO por tools/creatures/sculpt.py — malhas esculpidas das criaturas (espaço local de",
           "-- cada parte). v = {x,y,z, ...}; t = {a,b,c, ...} (índices a partir de 1). Não edite à mão.",
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
        out.append("\t},")
    out.append("}")
    open(DEST, "w").write("\n".join(out) + "\n")
    print(f"malhas: {total_v} vértices, {total_t} triângulos → {os.path.relpath(DEST, root)}")


if __name__ == "__main__":
    main()

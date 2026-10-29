#!/usr/bin/env python3
"""Converte os modelos OBJ (assets/models/ichigo.obj e mugetsu.obj) em src/shared/KitDataObj.json, no mesmo
formato do KitData procedural, para o jogo (ModelKit.luau) e para a prévia three.js.

Os OBJ são compostos só de primitivas, então a conversão vira Parts do Roblox sem upload de mesh:
  * 8 vértices  -> caixa   (Part Block, orientação pelas arestas)
  * 18 vértices -> prisma octogonal = cilindro (Part Cylinder; eixo = eixo X local no Roblox)
  * 42 vértices -> esfera  (Part Ball)
Partes do CORPO (Head, Torso_Robe, Robe_Sleeve, Hand, Trouser_Leg, Sandal_Boot) viram a cor do membro R15
correspondente. ACESSÓRIOS são reposicionados proporcionalmente no membro R15 (cada um relativo à parte do
corpo do OBJ a que pertence), porque o corpo do OBJ não tem as proporções do R15 nem juntas.

Eixos: o OBJ é Z para cima com o rosto em -Y. A espada e as correntes estão no lado +X, que nas referências
é a mão DIREITA; por isso o mapeamento é (x, y, z) -> (x, z, y) (personagem olha -Z, direita +X).

Rodar: python3 tools/import_obj.py   (depois: python3 preview/gen_data.py)
"""
import json, math, pathlib, sys
import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from build_kits import to_euler, mmul, rx  # mesma decomposição de ângulos verificada

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = {"Ichigo": ROOT / "assets/models/ichigo.obj", "Mugetsu": ROOT / "assets/models/mugetsu.obj"}
OUT = ROOT / "src/shared/KitDataObj.json"


def parse(path):
    objs, cur = [], None
    for line in open(path):
        t = line.split()
        if not t:
            continue
        if t[0] == "o":
            cur = {"name": t[1], "v": [], "c": None}
            objs.append(cur)
        elif t[0] == "v":
            v = list(map(float, t[1:]))
            cur["v"].append([v[0], v[2], v[1]])  # -> espaço do corpo (Y para cima, rosto em -Z)
            if len(v) >= 6 and cur["c"] is None:
                cur["c"] = [round(x * 255) for x in v[3:6]]
    for o in objs:
        o["v"] = np.array(o["v"])
    return {o["name"]: o for o in objs}


def box_of(V):
    """Caixa: centro, tamanho e eixos a partir das 3 arestas ortogonais que saem do vértice 0."""
    d = V - V[0]
    lens = np.linalg.norm(d, axis=1)
    order = [i for i in np.argsort(lens) if lens[i] > 1e-9]
    axes = []
    for i in order:
        u = d[i] / lens[i]
        if all(abs(np.dot(u, a)) < 1e-3 for a in axes):
            axes.append(u)
        if len(axes) == 3:
            break
    A = np.array(axes)  # linhas = eixos
    proj = (V - V.mean(0)) @ A.T
    size = proj.max(0) - proj.min(0)
    return V.mean(0), size, A


def bounds(o):
    c, s, A = box_of(o["v"])
    return c, np.abs(A.T) @ s  # extensão aproximada nos eixos do mundo


def rot_from_axes(X, Y, Z):
    return [[X[0], Y[0], Z[0]], [X[1], Y[1], Z[1]], [X[2], Y[2], Z[2]]]


def fit(o, mapper):
    """Ajusta a primitiva no espaço JÁ mapeado para o membro R15 (suporta escala não uniforme)."""
    V = np.array([mapper(v) for v in o["v"]])
    n = len(V)
    c = V.mean(0)
    if n == 8:
        c, size, A = box_of(V)
        X, Y, Z = A[0], A[1], A[2]
        if np.dot(np.cross(X, Y), Z) < 0:
            Z = -Z
        return "Block", size, c, rot_from_axes(X, Y, Z)
    if n == 42:
        r = float(np.linalg.norm(V - c, axis=1).mean())
        return "Ball", np.array([2 * r] * 3), c, None
    # prisma octogonal -> cilindro (eixo = maior variância)
    _, _, vt = np.linalg.svd(V - c)
    axis = vt[0]
    t = (V - c) @ axis
    length = t.max() - t.min()
    radial = (V - c) - np.outer(t, axis)
    r = float(np.linalg.norm(radial, axis=1).mean())
    X = axis / np.linalg.norm(axis)
    tmp = np.array([0, 1, 0]) if abs(X[1]) < 0.9 else np.array([1, 0, 0])
    Y = np.cross(tmp, X); Y /= np.linalg.norm(Y)
    Z = np.cross(X, Y)
    Y = np.cross(Z, X)
    return "Cylinder", np.array([length, 2 * r, 2 * r]), c, rot_from_axes(X, Y, Z)


# Regiões do R15 em repouso, relativas ao centro do membro de fixação (mesmo layout da prévia).
REGION = {
    "Head": ("Head", [0, 0, 0], [1.2, 1.2, 1.2]),
    "Torso_Robe": ("LowerTorso", [0, 0.8, 0], [2.0, 2.0, 1.0]),
    "Robe_Sleeve_1": ("RightUpperArm", [0, -0.55, 0], [1.0, 2.3, 1.0]),
    "Robe_Sleeve_-1": ("LeftUpperArm", [0, -0.55, 0], [1.0, 2.3, 1.0]),
}
OWNER = [  # prefixo do nome -> parte do corpo do OBJ que serve de referência
    ("Eye_", "Head"), ("Brow_", "Head"), ("Hair_Cap", "Head"), ("Orange_Hair_Spike", "Head"), ("Long_Black_Hair_Strand", "Head"),
    ("Mugetsu_Face_Shadow", "Head"), ("Long_Hair_Lock", "Head"), ("Waist_Sash", "Torso_Robe"), ("Robe_Tail", "Torso_Robe"),
    ("Chain_Link", "Robe_Sleeve_1"),
]
BODY = {"Head": ["Head"], "Torso_Robe": ["UpperTorso", "LowerTorso"],
        "Robe_Sleeve_1": ["RightUpperArm", "RightLowerArm"], "Robe_Sleeve_-1": ["LeftUpperArm", "LeftLowerArm"],
        "Hand_1": ["RightHand"], "Hand_-1": ["LeftHand"], "Trouser_Leg_1": ["RightUpperLeg", "RightLowerLeg"],
        "Trouser_Leg_-1": ["LeftUpperLeg", "LeftLowerLeg"], "Sandal_Boot_1": ["RightFoot"], "Sandal_Boot_-1": ["LeftFoot"]}
MATERIAL = {"Chain_Link": "Metal", "Zanpakuto": "Metal", "Robe_Tail": "Fabric", "Waist_Sash": "Fabric"}


def r4(v):
    return [round(float(x), 4) for x in v]


def sword(objs):
    """A espada do OBJ é refeita na MESMA empunhadura das animações (grip -50°, lâmina em -Z local), com as
    medidas e cores do OBJ (escala do torso ~1.3). Assim rastro/poses continuam corretos."""
    S = 1.3
    blade, grip, guard = objs["Zanpakuto_Blade"], objs["Zanpakuto_Grip"], objs["Zanpakuto_Guard"]
    bl = fit(blade, lambda v: v * S)[1]
    gl = fit(grip, lambda v: v * S)[1]
    _, gs, _ = box_of(guard["v"] * S)
    L, br, hl = float(bl[0]), float(bl[1]) / 2, float(gl[0])
    G = rx(-50)
    gp = np.array([0, -0.2, 0])

    def at(local, size, color, name=None, attachments=None, material="Metal"):
        pos = gp + np.array(G) @ np.array(local)
        p = {"name": name or f"S{len(parts)}", "attach": "RightHand", "shape": "Block", "size": r4(size), "pos": r4(pos),
             "rot": r4(to_euler(G)), "color": color, "material": material}
        if attachments:
            p["attachments"] = [{"name": a, "pos": r4(v)} for a, v in attachments]
        parts.append(p)

    parts = []
    at([0, 0, 0], [2 * float(gl[1]) / 2 + 0.02, 2 * float(gl[1]) / 2 + 0.02, hl], grip["c"], "SwordHandle", material="Fabric")
    gsz = sorted(gs.tolist())
    at([0, 0, -hl / 2 - 0.05], [gsz[2], gsz[1], gsz[0]], guard["c"])
    at([0, 0, -hl / 2 - 0.1 - L / 2], [2 * br, 2 * br, L], blade["c"], "Blade",
       [("TrailA", [0, 0, L / 2 - 0.15]), ("TrailB", [0, 0, -L / 2]), ("Tip", [0, 0, -L / 2])])
    return parts


def convert(form, path):
    objs = parse(path)
    colors = {}
    for body, limbs in BODY.items():
        for l in limbs:
            colors[l] = objs[body]["c"]
    parts = []
    regions = {k: (REGION[k], *bounds(objs[k])) for k in REGION}
    for name, o in objs.items():
        if name in BODY or name.startswith("Zanpakuto"):
            continue
        owner = next((own for pre, own in OWNER if name.startswith(pre)), None)
        if owner is None:
            print(f"  aviso: '{name}' sem regra de fixação; ignorado")
            continue
        (limb, off, rsize), pc, ps = regions[owner]
        ratio = np.array(rsize) / ps

        def mapper(v, pc=pc, ratio=ratio, off=off):
            return np.array(off) + (v - pc) * ratio

        shape, size, center, R = fit(o, mapper)
        attach = limb
        if limb == "RightUpperArm" and center[1] < -0.6:  # abaixo do cotovelo: vai com o antebraço
            attach, center = "RightLowerArm", center + np.array([0, 1.15, 0])
        p = {"name": name, "attach": attach, "shape": shape, "size": r4(size), "pos": r4(center),
             "rot": r4(to_euler(R)) if R is not None else [0, 0, 0], "color": o["c"],
             "material": next((m for pre, m in MATERIAL.items() if name.startswith(pre)), "SmoothPlastic")}
        parts.append(p)
    parts += sword(objs)
    print(f"{form}: {len(parts)} peças a partir de {len(objs)} objetos do OBJ")
    return {"limbColors": colors, "hideFace": True, "parts": parts, "chains": []}


def main():
    data = {"version": 2, "source": "tools/import_obj.py <- assets/models/*.obj", "forms": {f: convert(f, p) for f, p in SRC.items()}}
    OUT.write_text(json.dumps(data, separators=(",", ":")))
    print("escrito", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Converte um corpo de CreatureRigs.json na "leitura de rig" do animate.mjs (--rig-json), no mesmo
formato que scripts/read_rig.lua devolveria do modelo montado pelo RigBuilder no jogo:
peças, juntas (C0/C1 com 12 componentes), enfeites soldados (desenhados na folha de contato),
HipHeight e as declarações AnimRig. Também calcula o HipHeight que o RigBuilder usa (pés no chão).
Uso: python3 rig_reading.py HollowGrunt saida.json"""
import json, math, os, sys

here = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(here, "..", "..", "src", "shared", "Config", "CreatureRigs.json")


def rot(rx, ry, rz):
    """CFrame.Angles(rx, ry, rz) em graus → matriz 3x3 (linhas). Roblox: R = Rx * Ry * Rz."""
    a, b, c = (math.radians(v) for v in (rx, ry, rz))
    rxm = [[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]]
    rym = [[math.cos(b), 0, math.sin(b)], [0, 1, 0], [-math.sin(b), 0, math.cos(b)]]
    rzm = [[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]]
    return matmul(matmul(rxm, rym), rzm)


def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def frame(t):
    return (list(t[:3]), rot(*t[3:]))


def mul(f, g):
    (fp, fr), (gp, gr) = f, g
    return ([fp[i] + sum(fr[i][k] * gp[k] for k in range(3)) for i in range(3)], matmul(fr, gr))


def inv(f):
    p, r = f
    rt = [[r[j][i] for j in range(3)] for i in range(3)]
    return ([-sum(rt[i][k] * p[k] for k in range(3)) for i in range(3)], rt)


def components(t):
    p, r = frame(t)
    return [round(v, 6) for v in p + [r[i][j] for i in range(3) for j in range(3)]]


def rest_frames(body):
    """Pose de repouso: quadro de cada peça relativo ao HumanoidRootPart."""
    frames = {"HumanoidRootPart": ([0, 0, 0], rot(0, 0, 0))}
    pending = list(body["parts"])
    while pending:
        progressed = False
        for part in list(pending):
            if part["parent"] in frames:
                frames[part["name"]] = mul(mul(frames[part["parent"]], frame(part["c0"])), inv(frame(part["c1"])))
                pending.remove(part)
                progressed = True
        if not progressed:
            raise SystemExit("peças sem pai: " + ", ".join(p["name"] for p in pending))
    return frames


def lowest_point(body):
    frames = rest_frames(body)
    sizes = {p["name"]: p["size"] for p in body["parts"]}
    low = math.inf
    for name, (p, r) in frames.items():
        if name == "HumanoidRootPart":
            continue
        s = sizes[name]
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    corner = [sx * s[0] / 2, sy * s[1] / 2, sz * s[2] / 2]
                    low = min(low, p[1] + sum(r[1][k] * corner[k] for k in range(3)))
    return low


def hip_height(body):
    """HipHeight do Humanoid: distância do fundo do HumanoidRootPart ao chão (ponto mais baixo dos pés)."""
    return round(-lowest_point(body) - body["root"][1] / 2, 3)


SHAPE = {"Sphere": "Ball", "Block": "Block", "Wedge": "Wedge", "Cylinder": "Cylinder"}


def reading(name):
    body = json.load(open(SOURCE))[name]
    parts = [{"name": "HumanoidRootPart", "size": body["root"], "shape": "Block", "hidden": True}]
    joints = []
    for p in body["parts"]:
        parts.append({"name": p["name"], "size": p["size"], "shape": "Ball" if p.get("mesh") == "Sphere" else "Block"})
        joints.append({"name": p["joint"], "part0": p["parent"], "part1": p["name"], "c0": components(p["c0"]), "c1": components(p["c1"])})
    welded = []
    for i, d in enumerate(body.get("decor", [])):
        shape = SHAPE["Sphere"] if d.get("mesh") == "Sphere" else SHAPE.get(d["shape"], "Block")
        welded.append({"name": f"Decor{i}", "to": d["part"], "offset": components(d["offset"]), "size": d["size"], "shape": shape})
    return {
        "path": "game.Workspace." + name,
        "revision": "creature-" + name,
        "rootPart": "HumanoidRootPart",
        "controller": "Humanoid",
        "hipHeight": hip_height(body),
        "parts": parts,
        "joints": joints,
        "welded": welded,
        "declarations": json.dumps(body["declarations"]),
    }


if __name__ == "__main__":
    out = reading(sys.argv[1])
    json.dump(out, open(sys.argv[2], "w"), indent=1)
    print(sys.argv[1], "hipHeight", out["hipHeight"])

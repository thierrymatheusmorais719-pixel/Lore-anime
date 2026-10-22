#!/usr/bin/env python3
"""Mira a lâmina: encontra a rotação da junta `Weapon` que aponta a espada para uma direção
no espaço do personagem [direita, cima, frente], para uma pose de braço dada.
Compila todas as candidatas de uma vez com animate.mjs e faz cinemática direta com as juntas
do R15 padrão (as mesmas do compilador). Uso como módulo: solve(joints, target) → [x, y, z]."""
import json, math, os, subprocess, sys, tempfile

here = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.abspath(os.path.join(here, "..", "..", "..", ".claude", "skills", "vfxskill", "scripts", "animate.mjs"))
sys.path.insert(0, here)

# Juntas do R15 padrão (references/animate.mjs R15_RIG): (pai, filho, offsetPai, offsetFilho)
CHAIN = {
    "Root": ("HumanoidRootPart", "LowerTorso", (0, -1, 0), (0, -0.2, 0)),
    "Waist": ("LowerTorso", "UpperTorso", (0, 0.2, 0), (0, -0.849, 0)),
    "RightShoulder": ("UpperTorso", "RightUpperArm", (0.972, 0.598, 0), (-0.501, 0.419, 0)),
    "RightElbow": ("RightUpperArm", "RightLowerArm", (0, -0.355, 0), (0, 0.275, 0)),
    "RightWrist": ("RightLowerArm", "RightHand", (0, -0.532, 0), (0, 0.132, 0)),
    "Weapon": ("RightHand", "BodyAttach", (0, -0.158, 0), (0, 0, 0)),
}
ORDER = ["Root", "Waist", "RightShoulder", "RightElbow", "RightWrist", "Weapon"]
GRIP = [1, 0, 0, 0, 0, 1, 0, -1, 0]  # Rx(-90)


def mul(a, b):
    (ap, ar), (bp, br) = a, b
    p = [ap[i] + ar[3 * i] * bp[0] + ar[3 * i + 1] * bp[1] + ar[3 * i + 2] * bp[2] for i in range(3)]
    r = [sum(ar[3 * i + k] * br[3 * k + j] for k in range(3)) for i in range(3) for j in range(3)]
    return (p, r)


def trans(v):
    return (list(v), [1, 0, 0, 0, 1, 0, 0, 0, 1])


def inv_trans(v):
    return ([-v[0], -v[1], -v[2]], [1, 0, 0, 0, 1, 0, 0, 0, 1])


def blade_direction(poses):
    """poses: {junta: (p, r)} (Transforms). Retorna direção +Y do BodyAttach no espaço do HRP."""
    frames = {"HumanoidRootPart": ([0, 0, 0], [1, 0, 0, 0, 1, 0, 0, 0, 1])}
    for joint in ORDER:
        parent, child, po, co = CHAIN[joint]
        t = poses.get(joint, ([0, 0, 0], [1, 0, 0, 0, 1, 0, 0, 0, 1]))
        c0 = trans(po)
        if joint == "Weapon":
            c0 = mul(c0, ([0, 0, 0], GRIP))
        frames[child] = mul(mul(mul(frames[parent], c0), t), inv_trans(co))
    r = frames["BodyAttach"][1]
    return (r[1], r[4], r[7])  # coluna Y


def to_character(v):
    # espaço do HRP (Roblox: frente = -Z) → [direita, cima, frente]
    return (v[0], v[1], -v[2])


def _evaluate(joints, target, candidates):
    """Compila as candidatas em lotes (≤ 200 quadros) e devolve (dot, rotação) de cada uma."""
    from build import parse_luau  # noqa: E402
    results = []
    for start in range(0, len(candidates), 200):
        batch = candidates[start:start + 200]
        keys = []
        for i, rot in enumerate(batch):
            j = json.loads(json.dumps(joints))
            j["Weapon"] = {"rotation": list(rot)}
            keys.append({"time": round(i * 0.25, 3), "easing": {"style": "Constant", "direction": "In"}, "joints": j})
        with tempfile.TemporaryDirectory() as tmp:
            src = os.path.join(tmp, "aim.json")
            lua = os.path.join(tmp, "aim.lua")
            json.dump({"name": "Aim", "rig": "R15", "keyframes": keys}, open(src, "w"))
            res = subprocess.run(["node", SKILL, src, "--out", lua, "--waive", "velocity,jointLimits,rootDrift"], capture_output=True, text=True)
            if not os.path.exists(lua):
                raise SystemExit(res.stdout[-800:])
            tracks, _ = parse_luau(open(lua).read())
        for i, rot in enumerate(batch):
            t = round(i * 0.25, 3)
            poses = {}
            for joint, keylist in tracks.items():
                sample = None
                for kt, nums, _, _ in keylist:
                    if kt <= t + 1e-6:
                        sample = nums
                if sample:
                    poses[joint] = (sample[:3], sample[3:])
            d = to_character(blade_direction(poses))
            results.append((sum(a * b for a, b in zip(d, target)), list(rot)))
    return results


def _best(results):
    best_dot = max(r[0] for r in results)
    near = [r for r in results if r[0] >= best_dot - 1e-3]
    near.sort(key=lambda r: abs(r[1][0]) + abs(r[1][1]))
    return near[0][1], near[0][0]


def solve(joints, target, step=20):
    """joints: poses no formato da skill (sem Weapon). target: [direita, cima, frente].
    Rotação em torno dos eixos da MÃO: X inclina a lâmina, Y gira em torno do antebraço (Z só rola)."""
    tn = math.sqrt(sum(x * x for x in target))
    target = [x / tn for x in target]
    coarse = [(x, y, 0) for x in range(-180, 180, step) for y in range(-180, 180, step)]
    rot, _ = _best(_evaluate(joints, target, coarse))
    fine = [(rot[0] + dx, rot[1] + dy, 0) for dx in range(-step, step + 1, 5) for dy in range(-step, step + 1, 5)]
    return _best(_evaluate(joints, target, fine))


if __name__ == "__main__":
    joints = json.loads(sys.argv[1])
    target = json.loads(sys.argv[2])
    print(solve(joints, target))

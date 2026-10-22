#!/usr/bin/env python3
"""Fonte dos corpos de criatura (Hollows). Gera src/shared/Config/CreatureRigs.json, lido:
  • pelo jogo (RigBuilder.luau monta o modelo; Rojo transforma .json em ModuleScript)
  • pelas ferramentas (rig_reading.py → --rig-json do animate.mjs) para verificar as animações
    no corpo real de cada criatura.
Juntas mantêm os nomes do R15 (combate/animação compatíveis) + cauda (Tail1..3).
Transformações: [x, y, z, rx, ry, rz] = CFrame.new(x,y,z) * CFrame.Angles(rx,ry,rz) (graus).
Papéis de cor: skin, skin2 (mais escuro), bone, mask, eye (neon), accent (neon), dark."""
import json, os

here = os.path.dirname(os.path.abspath(__file__))
dest = os.path.join(here, "..", "..", "src", "shared", "Config", "CreatureRigs.json")


def P(name, size, parent, joint, c0, c1, role="skin", mesh="Sphere"):
    return {"name": name, "size": size, "parent": parent, "joint": joint, "c0": c0, "c1": c1, "role": role, "mesh": mesh}


def D(part, size, offset, role, shape="Block", material=None, mesh=None):
    d = {"part": part, "size": size, "offset": offset, "role": role, "shape": shape}
    if material:
        d["material"] = material
    if mesh:
        d["mesh"] = mesh
    return d


def mirror(items):
    """Duplica peças do lado direito (Right*) para o esquerdo, espelhando X e rotações Y/Z."""
    out = []
    for it in items:
        out.append(it)
        if "Right" in json.dumps(it):
            m = json.loads(json.dumps(it).replace("Right", "Left"))
            for key in ("c0", "c1", "offset"):
                if key in m:
                    v = m[key]
                    m[key] = [-v[0], v[1], v[2], v[3], -v[4], -v[5]]
            out.append(m)
    return out


def biped_declarations(tail=True, knee_rest=0):
    """knee_rest: quanto o joelho já vem dobrado no corpo (graus); a perna pode esticar até reta."""
    d = {
        "version": 1,
        "feet": ["LeftFoot", "RightFoot"],
        "hips": ["LeftHip", "RightHip"],
        "hinges": {
            "LeftElbow": {"axis": "X", "flex": 1}, "RightElbow": {"axis": "X", "flex": 1},
            "LeftKnee": {"axis": "X", "flex": -1}, "RightKnee": {"axis": "X", "flex": -1},
        },
        "limbs": {
            "LeftShoulder": {"hinge": "LeftElbow"}, "RightShoulder": {"hinge": "RightElbow"},
            "LeftHip": {"hinge": "LeftKnee", "foot": "LeftAnkle"}, "RightHip": {"hinge": "RightKnee", "foot": "RightAnkle"},
        },
        "limits": {
            "Root": "free", "Waist": {"turn": 90}, "Neck": {"turn": 90},
            "LeftShoulder": {"turn": 180}, "RightShoulder": {"turn": 180},
            "LeftElbow": {"min": -15, "max": 160}, "RightElbow": {"min": -15, "max": 160},
            "LeftWrist": {"turn": 100}, "RightWrist": {"turn": 100},
            "LeftHip": {"turn": 150}, "RightHip": {"turn": 150},
            "LeftKnee": {"min": -160, "max": knee_rest + 5}, "RightKnee": {"min": -160, "max": knee_rest + 5},
            "LeftAnkle": {"turn": 80}, "RightAnkle": {"turn": 80},
        },
    }
    if tail:
        for t in ("Tail1", "Tail2", "Tail3"):
            d["limits"][t] = {"turn": 70}
    return d


# ======================================================================= GRUNT
# Predador magro e curvado: tronco inclinado, braços longos com garras, pernas dobradas
# (dão folga para passadas), cauda de três segmentos, máscara de caveira com chifres.
grunt_parts = mirror([
    P("LowerTorso", [1.5, 0.75, 1.15], "HumanoidRootPart", "Root", [0, -0.65, 0, 0, 0, 0], [0, 0.05, 0, 0, 0, 0], "skin2"),
    P("UpperTorso", [2.0, 1.8, 1.45], "LowerTorso", "Waist", [0, 0.3, 0, -28, 0, 0], [0, -0.82, 0.12, 0, 0, 0]),
    P("Head", [1.15, 1.05, 1.25], "UpperTorso", "Neck", [0, 0.82, -0.4, 30, 0, 0], [0, -0.45, 0.15, 0, 0, 0], "skin2"),
    P("RightUpperArm", [0.7, 1.65, 0.7], "UpperTorso", "RightShoulder", [1.15, 0.5, -0.1, 36, 0, 0], [0, 0.72, 0, 0, 0, 0]),
    P("RightLowerArm", [0.6, 1.6, 0.6], "RightUpperArm", "RightElbow", [0, -0.78, 0, 18, 0, 0], [0, 0.72, 0, 0, 0, 0], "skin2"),
    P("RightHand", [0.85, 0.45, 0.95], "RightLowerArm", "RightWrist", [0, -0.78, 0, 0, 0, 0], [0, 0.18, 0, 0, 0, 0], "skin2"),
    P("RightUpperLeg", [0.85, 1.45, 0.85], "LowerTorso", "RightHip", [0.5, -0.25, 0, 22, 0, 0], [0, 0.66, 0, 0, 0, 0]),
    P("RightLowerLeg", [0.7, 1.45, 0.7], "RightUpperLeg", "RightKnee", [0, -0.68, 0, -48, 0, 0], [0, 0.68, 0, 0, 0, 0], "skin2"),
    P("RightFoot", [0.85, 0.35, 1.25], "RightLowerLeg", "RightAnkle", [0, -0.68, 0, 26, 0, 0], [0, 0.12, -0.2, 0, 0, 0], "skin2", "Block"),
    P("Tail1", [0.55, 0.55, 1.4], "LowerTorso", "Tail1", [0, 0.05, 0.5, -15, 0, 0], [0, 0, -0.68, 0, 0, 0], "skin2"),
    P("Tail2", [0.42, 0.42, 1.3], "Tail1", "Tail2", [0, 0, 0.66, 12, 0, 0], [0, 0, -0.62, 0, 0, 0], "skin2"),
    P("Tail3", [0.28, 0.28, 1.2], "Tail2", "Tail3", [0, 0, 0.62, 12, 0, 0], [0, 0, -0.58, 0, 0, 0], "bone"),
])

SKULL_MASK = [
    # placa frontal, sobrancelha, bochechas, mandíbula com dentes, chifres, olhos, marcas
    D("Head", [1.35, 1.0, 0.35], [0, 0.08, -0.62, 0, 0, 0], "mask", "Block", "SmoothPlastic", "Sphere"),
    D("Head", [1.4, 0.28, 0.42], [0, 0.42, -0.66, -12, 0, 0], "mask", "Block", "SmoothPlastic"),
    D("Head", [0.28, 0.18, 0.08], [0.3, 0.22, -0.84, 0, 0, -8], "dark"),
    D("Head", [0.28, 0.18, 0.08], [-0.3, 0.22, -0.84, 0, 0, 8], "dark"),
    D("Head", [0.18, 0.1, 0.05], [0.3, 0.22, -0.88, 0, 0, -8], "eye", "Block", "Neon"),
    D("Head", [0.18, 0.1, 0.05], [-0.3, 0.22, -0.88, 0, 0, 8], "eye", "Block", "Neon"),
    D("Head", [1.1, 0.35, 0.5], [0, -0.38, -0.55, 8, 0, 0], "mask", "Block", "SmoothPlastic"),
    D("Head", [0.06, 0.95, 0.04], [0.42, 0.05, -0.81, 0, 0, 0], "accent", "Block", "Neon"),
    D("Head", [0.06, 0.95, 0.04], [-0.42, 0.05, -0.81, 0, 0, 0], "accent", "Block", "Neon"),
] + [D("Head", [0.1, 0.24, 0.1], [-0.42 + i * 0.12, -0.2, -0.82, 0, 0, 180], "bone", "Wedge") for i in range(8)] + mirror([
    D("Head", [0.28, 0.28, 1.0], [0.45, 0.55, -0.15, -55, 0, -25], "bone", "Block", None, "Sphere"),
    D("Head", [0.2, 0.2, 0.9], [0.7, 1.05, 0.05, -100, 0, -35], "bone", "Block", None, "Sphere"),
])
CLAWS = mirror([D("RightHand", [0.1, 0.12, 1.4], [x, -0.12, -0.75, -15, ry, 0], "bone", "Wedge") for x, ry in ((-0.28, 6), (0, 0), (0.28, -6))])
SPINE = [D("UpperTorso", [0.12, 0.55 - i * 0.06, 0.55], [0, 0.65 - i * 0.42, 0.72, -25, 0, 0], "bone", "Wedge") for i in range(4)] + \
        [D("Tail1", [0.1, 0.35, 0.4], [0, 0.32, 0, -20, 0, 0], "bone", "Wedge"), D("Tail2", [0.08, 0.3, 0.35], [0, 0.25, 0, -20, 0, 0], "bone", "Wedge")]
CHEST_HOLE = [D("UpperTorso", [0.15, 0.75, 0.75], [0, 0.1, -0.7, 0, 90, 0], "dark", "Cylinder")]
SHOULDER_BONES = mirror([D("RightUpperArm", [0.85, 0.35, 0.9], [0, 0.72, 0, 0, 0, -15], "bone", "Block", None, "Sphere")])

grunt = {
    "parts": grunt_parts,
    "root": [2.0, 2.0, 1.1],
    "decor": SKULL_MASK + CLAWS + SPINE + CHEST_HOLE + SHOULDER_BONES,
    "declarations": biped_declarations(knee_rest=48),
    "animSet": "Hollow",
}

# ======================================================================= BRUTE
# Gorila de osso: peito e braços enormes, pernas curtas, cabeça baixa entre os ombros, placas de armadura.
brute_parts = mirror([
    P("LowerTorso", [1.9, 0.8, 1.35], "HumanoidRootPart", "Root", [0, -0.55, 0, 0, 0, 0], [0, 0.05, 0, 0, 0, 0], "skin2"),
    P("UpperTorso", [2.9, 2.2, 1.9], "LowerTorso", "Waist", [0, 0.35, 0, -22, 0, 0], [0, -1.0, 0.1, 0, 0, 0]),
    P("Head", [1.1, 1.0, 1.15], "UpperTorso", "Neck", [0, 0.7, -0.75, 22, 0, 0], [0, -0.35, 0.1, 0, 0, 0], "skin2"),
    P("RightUpperArm", [1.15, 1.7, 1.15], "UpperTorso", "RightShoulder", [1.75, 0.55, -0.1, 28, 0, 0], [0, 0.72, 0, 0, 0, 0]),
    P("RightLowerArm", [1.25, 1.75, 1.25], "RightUpperArm", "RightElbow", [0, -0.78, 0, 15, 0, 0], [0, 0.8, 0, 0, 0, 0], "skin2"),
    P("RightHand", [1.35, 0.8, 1.35], "RightLowerArm", "RightWrist", [0, -0.85, 0, 0, 0, 0], [0, 0.3, 0, 0, 0, 0], "bone"),
    P("RightUpperLeg", [1.05, 1.15, 1.05], "LowerTorso", "RightHip", [0.65, -0.25, 0, 18, 0, 0], [0, 0.52, 0, 0, 0, 0]),
    P("RightLowerLeg", [0.95, 1.15, 0.95], "RightUpperLeg", "RightKnee", [0, -0.52, 0, -36, 0, 0], [0, 0.52, 0, 0, 0, 0], "skin2"),
    P("RightFoot", [1.1, 0.4, 1.4], "RightLowerLeg", "RightAnkle", [0, -0.55, 0, 18, 0, 0], [0, 0.15, -0.2, 0, 0, 0], "skin2", "Block"),
])
brute_decor = [
    D("Head", [1.25, 1.0, 0.4], [0, 0.05, -0.55, 0, 0, 0], "mask", "Block", "SmoothPlastic", "Sphere"),
    D("Head", [0.25, 0.14, 0.06], [0.28, 0.15, -0.78, 0, 0, -10], "eye", "Block", "Neon"),
    D("Head", [0.25, 0.14, 0.06], [-0.28, 0.15, -0.78, 0, 0, 10], "eye", "Block", "Neon"),
    D("Head", [1.0, 0.25, 0.25], [0, -0.32, -0.72, 0, 0, 0], "dark"),
    D("UpperTorso", [2.4, 1.5, 0.35], [0, 0.25, -0.9, 8, 0, 0], "bone", "Block", "Slate", "Sphere"),
    D("UpperTorso", [0.18, 0.85, 0.85], [0, 0.0, -1.05, 0, 90, 0], "dark", "Cylinder"),
] + mirror([
    D("Head", [0.4, 0.4, 1.4], [0.55, 0.5, -0.1, -40, 0, -35], "bone", "Block", None, "Sphere"),
    D("RightUpperArm", [1.45, 0.55, 1.45], [0, 0.65, 0, 0, 0, -10], "bone", "Block", "Slate", "Sphere"),
    D("RightLowerArm", [1.4, 0.9, 1.4], [0, -0.25, 0, 0, 0, 0], "bone", "Block", "Slate", "Sphere"),
    D("RightHand", [0.2, 0.25, 0.6], [0.35, -0.25, -0.6, -20, 0, 0], "bone", "Wedge"),
    D("RightHand", [0.2, 0.25, 0.6], [-0.35, -0.25, -0.6, -20, 0, 0], "bone", "Wedge"),
]) + [D("UpperTorso", [0.18, 0.8 - i * 0.12, 0.7], [0, 0.85 - i * 0.5, 0.95, -25, 0, 0], "bone", "Wedge") for i in range(4)]
brute = {
    "parts": brute_parts,
    "root": [2.6, 2.2, 1.4],
    "decor": brute_decor,
    "declarations": biped_declarations(tail=False, knee_rest=36),
    "animSet": "Brute",
}

rigs = {"HollowGrunt": grunt, "HollowBrute": brute}
with open(dest, "w") as f:
    json.dump(rigs, f, indent=1)
print("corpos:", ", ".join(rigs))

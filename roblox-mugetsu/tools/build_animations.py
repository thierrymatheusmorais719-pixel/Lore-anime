#!/usr/bin/env python3
"""Exporta a coreografia do PoseDriver como KeyframeSequences do Roblox (animations/*.model.json, Rojo).

No Studio elas aparecem em ServerStorage/MugetsuAnimations. Para virar Animation ID: clique com o botão
direito na KeyframeSequence -> "Save to Roblox" (ou abra no Animation Editor, ajuste e publique). Cole o
ID em src/shared/AssetManifest.luau (Animations[nome].id) e o jogo passa a tocar a animação publicada,
com os KeyframeMarkers disparando os efeitos.

As poses são as mesmas da animação procedural (PoseDriver.luau, via preview/data.js). Ficam de fora só
as camadas procedurais (respiração e tremor da concentração), que o Animator não tem.

Rodar: python3 preview/gen_data.py && python3 tools/build_animations.py
"""
import json, math, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = json.loads((ROOT / "preview/data.js").read_text().split("=", 1)[1].strip().rstrip(";"))
OUT = ROOT / "animations"

# Pose (nome da peça R15) -> junta do PoseDriver que move essa peça; e a hierarquia de Poses do R15
JOINT_OF = {"LowerTorso": "Root", "UpperTorso": "Waist", "Head": "Neck",
            "RightUpperArm": "RightShoulder", "RightLowerArm": "RightElbow", "RightHand": "RightWrist",
            "LeftUpperArm": "LeftShoulder", "LeftLowerArm": "LeftElbow", "LeftHand": "LeftWrist",
            "RightUpperLeg": "RightHip", "RightLowerLeg": "RightKnee", "LeftUpperLeg": "LeftHip", "LeftLowerLeg": "LeftKnee"}
TREE = ("HumanoidRootPart", [
    ("LowerTorso", [
        ("UpperTorso", [
            ("Head", []),
            ("RightUpperArm", [("RightLowerArm", [("RightHand", [])])]),
            ("LeftUpperArm", [("LeftLowerArm", [("LeftHand", [])])]),
        ]),
        ("RightUpperLeg", [("RightLowerLeg", [])]),
        ("LeftUpperLeg", [("LeftLowerLeg", [])]),
    ]),
])
PRIORITY_ACTION4 = 5   # Enum.AnimationPriority.Action4
EASE_CUBIC = 3         # Enum.PoseEasingStyle.Cubic
EASE_INOUT = 2         # Enum.PoseEasingDirection.InOut


def rot_xyz(rx, ry, rz):
    """CFrame.Angles(rx, ry, rz) = Rx*Ry*Rz, em linhas."""
    a, b, c = (math.radians(v) for v in (rx, ry, rz))
    ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
    Rx = [[1, 0, 0], [0, ca, -sa], [0, sa, ca]]
    Ry = [[cb, 0, sb], [0, 1, 0], [-sb, 0, cb]]
    Rz = [[cc, -sc, 0], [sc, cc, 0], [0, 0, 1]]
    mul = lambda A, B: [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mul(mul(Rx, Ry), Rz)


def pose_node(part, children, pose):
    joint = JOINT_OF.get(part)
    v = pose.get(joint, [0, 0, 0, 0]) if joint else [0, 0, 0, 0]
    y = v[3] if joint == "Root" and len(v) > 3 else 0
    R = rot_xyz(v[0], v[1], v[2])
    return {
        "Name": part, "ClassName": "Pose",
        "Properties": {
            "CFrame": {"CFrame": {"position": [0, round(y, 5), 0], "orientation": [[round(x, 6) for x in row] for row in R]}},
            "Weight": 1, "EasingStyle": {"Enum": EASE_CUBIC}, "EasingDirection": {"Enum": EASE_INOUT},
        },
        "Children": [pose_node(p, c, pose) for p, c in children],
    }


def build(name, anim):
    keyframes = []
    for k in anim["keys"]:
        kf = {"Name": "Keyframe", "ClassName": "Keyframe", "Properties": {"Time": k["t"]},
              "Children": [pose_node(TREE[0], TREE[1], DATA["poses"][k["pose"]])]}
        keyframes.append(kf)
    for marker, t in DATA.get("markers", {}).get(name, {}).items():
        same = next((kf for kf in keyframes if abs(kf["Properties"]["Time"] - t) < 1e-4), None)
        node = {"Name": marker, "ClassName": "KeyframeMarker", "Properties": {"Value": ""}}
        if same:
            same["Children"].append(node)
        else:  # keyframe só com o marker (sem poses), no instante exato do evento
            keyframes.append({"Name": "Keyframe", "ClassName": "Keyframe", "Properties": {"Time": t}, "Children": [node]})
    keyframes.sort(key=lambda kf: kf["Properties"]["Time"])
    return {"ClassName": "KeyframeSequence",
            "Properties": {"Loop": anim["looped"], "Priority": {"Enum": PRIORITY_ACTION4}},
            "Children": keyframes}


def main():
    OUT.mkdir(exist_ok=True)
    for name, anim in DATA["anims"].items():
        (OUT / f"{name}.model.json").write_text(json.dumps(build(name, anim), indent=1))
        n_markers = len(DATA.get("markers", {}).get(name, {}))
        print(f"{name}: {len(anim['keys'])} keyframes, {n_markers} markers, {anim['length']}s{' (loop)' if anim['looped'] else ''}")
    print("escrito em", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()

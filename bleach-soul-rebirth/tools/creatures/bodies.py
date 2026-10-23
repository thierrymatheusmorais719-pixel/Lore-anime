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


def P(name, size, parent, joint, c0, c1, role="skin", mesh="Sphere", color=None, material=None):
    p = {"name": name, "size": size, "parent": parent, "joint": joint, "c0": c0, "c1": c1, "role": role, "mesh": mesh}
    if color:
        p["color"] = color
    if material:
        p["material"] = material
    return p


def D(part, size, offset, role, shape="Block", material=None, mesh=None, color=None):
    d = {"part": part, "size": size, "offset": offset, "role": role, "shape": shape}
    if color:
        d["color"] = color
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


def both(items):
    """Espelha decorações: peças do lado direito viram esquerdas (mirror); peças centrais (cabeça,
    tronco) ganham uma cópia com X invertido."""
    out = []
    for it in items:
        if "Right" in it.get("part", ""):
            out += mirror([it])
        else:
            out.append(it)
            m = json.loads(json.dumps(it))
            v = m["offset"]
            m["offset"] = [-v[0], v[1], v[2], v[3], -v[4], -v[5]]
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


# ======================================================================= GRUNT (e variante Selvagem)
# Mesmo esqueleto curvado (pernas dobradas, cauda curta), dois visuais:
#   "purple" (imagem de referência 2): corpo roxo-azulado com marcas vermelhas em gota, braços
#     cinza longos com mãos enormes de dedos grossos, caveira sorridente de olhos amarelos e chifre
#   "feral" (imagem 3): corpo verde-azulado, juba marrom, caveira alongada de dentes grandes,
#     garras longas como galhos
from shapes import seg, curve, arc_points  # noqa: E402,F811


def grunt_body(style):
    import math as _m
    purple = style == "purple"
    BODY = [92, 92, 130] if purple else [86, 140, 144]
    BODY_D = [70, 70, 104] if purple else [64, 112, 116]
    ARM = [116, 116, 122] if purple else BODY
    HAND = [100, 100, 106] if purple else [104, 66, 44]
    MARK = [140, 28, 42]
    WHITE = [240, 238, 232]
    YELLOW = [255, 214, 40]
    INK = [14, 12, 16]
    FUR = [104, 64, 42]
    FUR_D = [78, 46, 30]
    # pele pelo papel (skin/skin2): o `look` de cada inimigo tinge (Hollow comum roxo-azulado,
    # Kurokage roxo-escuro); braços, mãos, marcas e máscara têm cor própria
    if purple:
        BODY = BODY_D = None
    parts = mirror([
        P("LowerTorso", [1.5, 0.75, 1.15], "HumanoidRootPart", "Root", [0, -0.65, 0, 0, 0, 0], [0, 0.05, 0, 0, 0, 0], "skin2", color=BODY_D),
        P("UpperTorso", [2.0, 1.8, 1.45], "LowerTorso", "Waist", [0, 0.3, 0, -28, 0, 0], [0, -0.82, 0.12, 0, 0, 0], color=BODY),
        P("Head", [1.15, 1.05, 1.25], "UpperTorso", "Neck", [0, 0.82, -0.4, 30, 0, 0], [0, -0.45, 0.15, 0, 0, 0], "skin2", color=BODY_D),
        P("RightUpperArm", [0.7, 1.65, 0.7], "UpperTorso", "RightShoulder", [1.15, 0.5, -0.1, 36, 0, 0], [0, 0.72, 0, 0, 0, 0], color=ARM),
        P("RightLowerArm", [0.62, 1.6, 0.62], "RightUpperArm", "RightElbow", [0, -0.78, 0, 18, 0, 0], [0, 0.72, 0, 0, 0, 0], color=ARM),
        P("RightHand", [1.1, 0.5, 1.15], "RightLowerArm", "RightWrist", [0, -0.78, 0, 0, 0, 0], [0, 0.2, 0, 0, 0, 0], color=HAND),
        P("RightUpperLeg", [0.85, 1.45, 0.85], "LowerTorso", "RightHip", [0.5, -0.25, 0, 22, 0, 0], [0, 0.66, 0, 0, 0, 0], color=BODY),
        P("RightLowerLeg", [0.7, 1.45, 0.7], "RightUpperLeg", "RightKnee", [0, -0.68, 0, -48, 0, 0], [0, 0.68, 0, 0, 0, 0], "skin2", color=BODY_D),
        P("RightFoot", [0.85, 0.35, 1.25], "RightLowerLeg", "RightAnkle", [0, -0.68, 0, 26, 0, 0], [0, 0.12, -0.2, 0, 0, 0], "skin2", "Block", color=BODY_D),
        P("Tail1", [0.42, 0.42, 1.2], "LowerTorso", "Tail1", [0, 0.05, 0.5, -15, 0, 0], [0, 0, -0.58, 0, 0, 0], "skin2", color=BODY_D),
        P("Tail2", [0.3, 0.3, 1.05], "Tail1", "Tail2", [0, 0, 0.56, 12, 0, 0], [0, 0, -0.5, 0, 0, 0], "skin2", color=BODY_D),
        P("Tail3", [0.2, 0.2, 0.9], "Tail2", "Tail3", [0, 0, 0.5, 12, 0, 0], [0, 0, -0.44, 0, 0, 0], "skin2", color=BODY_D),
    ])
    decor = [
        # buraco no peito: anel escuro com borda clara
        D("UpperTorso", [0.16, 0.8, 0.8], [0, 0.05, -0.7, 0, 90, 0], "dark", "Cylinder", None, None, INK),
        D("UpperTorso", [0.1, 0.95, 0.95], [0, 0.05, -0.66, 0, 90, 0], "skin2", "Cylinder", None, None, BODY_D),
    ]
    side = []
    if purple:
        # caveira sorridente: crânio, órbitas com olhos amarelos contornados, nariz, sorriso de dentes
        decor += [
            D("Head", [1.3, 1.15, 0.6], [0, 0.08, -0.5, 0, 0, 0], "mask", "Block", "SmoothPlastic", "Sphere", WHITE),
            D("Head", [1.0, 0.45, 0.4], [0, -0.42, -0.6, 6, 0, 0], "mask", "Block", "SmoothPlastic", "Sphere", WHITE),
            D("Head", [0.1, 0.12, 0.06], [0.07, -0.08, -0.84, 0, 0, 20], "dark", "Wedge", None, None, INK),
            D("Head", [0.1, 0.12, 0.06], [-0.07, -0.08, -0.84, 0, 0, -20], "dark", "Wedge", None, None, INK),
            D("Head", [0.82, 0.06, 0.08], [0, -0.38, -0.8, 0, 0, 0], "dark", "Block", None, None, INK),
        ]
        for i in range(7):
            x = -0.36 + i * 0.12
            decor.append(D("Head", [0.1, 0.16, 0.06], [x, -0.29, -0.8, 0, 0, 0], "mask", "Block", "SmoothPlastic", None, WHITE))
            decor.append(D("Head", [0.1, 0.14, 0.06], [x, -0.47, -0.78, 0, 0, 0], "mask", "Block", "SmoothPlastic", None, WHITE))
        side += [
            D("Head", [0.36, 0.3, 0.1], [0.27, 0.18, -0.8, 0, 0, -12], "dark", "Block", None, "Sphere", INK),
            D("Head", [0.22, 0.2, 0.08], [0.27, 0.18, -0.85, 0, 0, -12], "eye", "Block", "Neon", "Sphere"),
            D("Head", [0.06, 0.4, 0.04], [0.48, 0.0, -0.78, 0, 0, 25], "dark", "Block", None, None, INK),  # rachadura
        ]
        # chifre único no topo, roxo-avermelhado
        decor += curve(D, "Head", arc_points([0.22, 0.55, 0.0], [0.35, 1.7, 0.25], [0.15, 0.0, -0.1], 3), 0.3, "bone", [110, 40, 60], taper=0.2)
        # marcas vermelhas em gota pelo corpo (frente, costas, pernas)
        # faixas rentes à superfície dos blocos (frente e costas do tronco, frente das pernas)
        for x, y in ((0.55, 0.55), (0.78, 0.0), (0.45, -0.5), (0.2, 0.72)):
            side.append(D("UpperTorso", [0.14, 0.5, 0.05], [x, y, -0.745, 0, 0, -15 - x * 20], "skin", "Block", "SmoothPlastic", None, MARK))
            side.append(D("UpperTorso", [0.14, 0.5, 0.05], [x, y, 0.745, 0, 0, -15 - x * 20], "skin", "Block", "SmoothPlastic", None, MARK))
        for part, ys, z in (("RightUpperLeg", (0.35, -0.2), -0.445), ("RightLowerLeg", (0.3, -0.25), -0.375)):
            for y in ys:
                side.append(D(part, [0.12, 0.42, 0.05], [0.18, y, z, 0, 0, -12], "skin", "Block", "SmoothPlastic", None, MARK))
        # dedos grossos (2 falanges) com pontas escuras
        for fx in (-0.38, -0.13, 0.13, 0.38):
            pts = arc_points([fx, -0.1, -0.45], [fx * 1.1, -0.85, -0.85], [0, 0.0, -0.25], 2)
            side += curve(D, "RightHand", pts, 0.26, "skin", HAND, taper=0.8)
            side.append(D("RightHand", [0.16, 0.18, 0.22], [fx * 1.1, -0.95, -0.87, 30, 0, 0], "bone", "Wedge", None, None, [40, 34, 40]))
        for tx in (-0.28, 0.0, 0.28):
            side.append(D("RightFoot", [0.12, 0.14, 0.4], [tx, -0.02, -0.75, -8, 0, 0], "bone", "Wedge", None, None, MARK))
    else:
        # caveira alongada (cavalo) com dentes grandes e olhos amarelos pequenos
        decor += [
            D("Head", [1.15, 0.85, 0.55], [0, 0.35, -0.55, -10, 0, 0], "mask", "Block", "SmoothPlastic", "Sphere", WHITE),
            D("Head", [0.85, 1.15, 0.6], [0, -0.3, -0.72, 15, 0, 0], "mask", "Block", "SmoothPlastic", "Sphere", WHITE),
            D("Head", [0.8, 0.12, 0.12], [0, -0.48, -1.0, 15, 0, 0], "dark", "Block", None, None, INK),
        ]
        for i in range(6):
            x = -0.3 + i * 0.12
            decor.append(D("Head", [0.11, 0.24, 0.1], [x, -0.36, -1.03, 15, 0, 0], "mask", "Block", "SmoothPlastic", None, WHITE))
            decor.append(D("Head", [0.11, 0.22, 0.1], [x, -0.62, -0.96, 15, 0, 0], "mask", "Block", "SmoothPlastic", None, WHITE))
        side += [
            D("Head", [0.2, 0.16, 0.08], [0.28, 0.32, -0.82, 0, 0, -15], "dark", "Block", None, "Sphere", INK),
            D("Head", [0.1, 0.09, 0.05], [0.28, 0.32, -0.86, 0, 0, -15], "eye", "Block", "Neon", "Sphere", YELLOW),
        ]
        # juba marrom: bolas de pelo em volta da cabeça e do pescoço, com pontas
        for k in range(10):
            a = _m.radians(k / 10 * 360)
            x, y = _m.cos(a) * 0.75, _m.sin(a) * 0.7
            if y < -0.45:
                continue
            decor.append(D("Head", [0.75, 0.75, 0.6], [x, y + 0.05, 0.15, 0, 0, 0], "skin", "Block", "Fabric", "Sphere", FUR if k % 2 else FUR_D))
            decor.append(seg(D, "Head", [x * 1.1, y * 1.1, 0.2], [x * 1.65, y * 1.6 + 0.1, 0.35], 0.25, "skin", FUR_D, material="Fabric"))
        decor.append(D("UpperTorso", [1.8, 0.8, 1.4], [0, 0.85, 0.0, 0, 0, 0], "skin", "Block", "Fabric", "Sphere", FUR))
        # garras longas de galho: três por mão, curvas, ásperas
        for fx in (-0.32, 0.0, 0.32):
            pts = arc_points([fx, -0.1, -0.4], [fx * 1.4, -1.75, -1.45], [0, 0.0, -0.4], 3)
            side += curve(D, "RightHand", pts, 0.24, "bone", HAND, taper=0.3, material="Wood")
        for tx in (-0.28, 0.0, 0.28):
            side.append(D("RightFoot", [0.12, 0.14, 0.45], [tx, -0.02, -0.75, -8, 0, 0], "bone", "Wedge", "Wood", None, HAND))
    decor += both(side)
    return parts, decor


grunt_parts, grunt_decor = grunt_body("purple")
grunt = {
    "parts": grunt_parts,
    "root": [2.0, 2.0, 1.1],
    "decor": grunt_decor,
    "declarations": biped_declarations(knee_rest=48),
    "animSet": "Hollow",
}
feral_parts, feral_decor = grunt_body("feral")
feral = {
    "parts": feral_parts,
    "root": [2.0, 2.0, 1.1],
    "decor": feral_decor,
    "declarations": biped_declarations(knee_rest=48),
    "animSet": "Hollow",
}

# ======================================================================= BRUTE (samurai)
# Referência: chefe ogro de armadura samurai (corpo largo e pesado, pele roxo-acinzentada, armadura
# verde-petróleo com bordas creme, ombreiras enormes em camadas, chifres curvos claros, máscara
# escura com pontos roxos acesos, cinturão com discos verdes, cordões roxos e crânio, saia de penas
# douradas, calças largas verde-escuras, pés grandes com garras; costas com borlas roxas).
from shapes import seg, curve, arc_points  # noqa: E402

SKIN = [150, 126, 168]
SKIN_D = [118, 98, 138]
ARMOR = [30, 62, 64]
ARMOR_D = [17, 34, 37]
TRIM = [216, 206, 168]
GOLD = [226, 172, 48]
FEATHER = [240, 190, 42]
FEATHER_D = [206, 140, 28]
GREEN = [72, 140, 58]
GREEN_D = [44, 96, 40]
PURPLE = [108, 40, 118]
ROPE = [150, 62, 150]
BROWN = [92, 56, 34]
HORN = [234, 226, 198]
PANTS = [26, 50, 52]
CLAW = [206, 176, 124]
GLOW = [196, 96, 255]

brute_parts = mirror([
    P("LowerTorso", [2.6, 1.3, 1.9], "HumanoidRootPart", "Root", [0, -0.35, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], color=SKIN),
    P("UpperTorso", [3.2, 2.2, 2.1], "LowerTorso", "Waist", [0, 0.45, 0, -12, 0, 0], [0, -1.0, 0.05, 0, 0, 0], color=SKIN),
    P("Head", [1.25, 1.15, 1.25], "UpperTorso", "Neck", [0, 0.95, -0.6, 12, 0, 0], [0, -0.38, 0.1, 0, 0, 0], color=SKIN_D),
    P("RightUpperArm", [1.15, 1.7, 1.15], "UpperTorso", "RightShoulder", [1.95, 0.5, -0.05, 18, 0, 0], [0, 0.65, 0, 0, 0, 0], color=SKIN),
    P("RightLowerArm", [1.15, 1.6, 1.15], "RightUpperArm", "RightElbow", [0, -0.78, 0, 16, 0, 0], [0, 0.72, 0, 0, 0, 0], color=SKIN),
    P("RightHand", [1.25, 0.85, 1.35], "RightLowerArm", "RightWrist", [0, -0.78, 0, 0, 0, 0], [0, 0.3, 0, 0, 0, 0], color=SKIN_D),
    P("RightUpperLeg", [1.25, 1.15, 1.25], "LowerTorso", "RightHip", [0.78, -0.4, 0, 16, 0, 0], [0, 0.52, 0, 0, 0, 0], color=PANTS, material="Fabric"),
    P("RightLowerLeg", [1.1, 1.15, 1.1], "RightUpperLeg", "RightKnee", [0, -0.52, 0, -34, 0, 0], [0, 0.52, 0, 0, 0, 0], color=PANTS, material="Fabric"),
    P("RightFoot", [1.25, 0.45, 1.6], "RightLowerLeg", "RightAnkle", [0, -0.55, 0, 18, 0, 0], [0, 0.15, -0.25, 0, 0, 0], "skin", "Block", color=SKIN_D),
])


def brute_head():
    d = [
        # elmo/máscara escura que cobre a cabeça, com crista
        D("Head", [1.45, 1.3, 1.45], [0, 0.08, 0, 0, 0, 0], "mask", "Block", "SmoothPlastic", "Sphere", ARMOR_D),
        D("Head", [1.05, 0.85, 0.3], [0, -0.02, -0.62, -6, 0, 0], "mask", "Block", "SmoothPlastic", "Sphere", [36, 28, 48]),
        D("Head", [0.18, 0.5, 1.1], [0, 0.62, 0.05, 0, 0, 0], "mask", "Block", "SmoothPlastic", None, ARMOR),
        D("Head", [1.1, 0.12, 0.34], [0, 0.42, -0.66, -10, 0, 0], "mask", "Block", "SmoothPlastic", None, TRIM),
    ]
    # pontos roxos acesos na máscara (3 x 3), olhos maiores no meio
    for row in range(3):
        for col in (-1, 0, 1):
            big = row == 1 and col != 0
            size = 0.16 if big else 0.1
            d.append(D("Head", [size, size, 0.08], [col * 0.26, 0.2 - row * 0.2, -0.79, 0, 0, 0], "eye", "Block", "Neon", "Sphere", GLOW))
    # chifres curvos: saem do topo para fora, sobem e curvam para dentro na ponta
    horn = arc_points([0.42, 0.45, 0.05], [0.55, 1.75, 0.15], [0.75, 0.05, 0.0], 4)
    d += mirror(curve(D, "RightHead", horn, 0.36, "bone", HORN, taper=0.35, material="SmoothPlastic"))
    for item in d:
        if item["part"] in ("RightHead", "LeftHead"):
            item["part"] = "Head"
    return d


def pauldron():
    d = []
    # três placas sobrepostas descendo para fora, cada uma com borda creme
    for i, (x, y, rz, w) in enumerate([(0.05, 0.85, -8, 2.1), (0.3, 0.5, -24, 2.0), (0.52, 0.12, -40, 1.75)]):
        d.append(D("RightUpperArm", [w, 0.5, 1.95 - i * 0.15], [x, y, 0, 0, 0, rz], "skin", "Block", "Metal", "Sphere", ARMOR))
        d.append(D("RightUpperArm", [w + 0.06, 0.12, 2.0 - i * 0.15], [x + 0.03, y - 0.2, 0, 0, 0, rz], "skin", "Block", "SmoothPlastic", "Sphere", TRIM))
    # pontas da ombreira
    d.append(D("RightUpperArm", [0.3, 0.75, 0.55], [0.25, 1.25, -0.35, 0, 0, -15], "skin", "Wedge", "Metal", None, ARMOR_D))
    d.append(D("RightUpperArm", [0.3, 0.6, 0.5], [0.3, 1.15, 0.45, 0, 180, -15], "skin", "Wedge", "Metal", None, ARMOR_D))
    # bracelete marrom + pelagem amarela no bíceps
    d.append(D("RightUpperArm", [0.35, 1.3, 1.3], [0, -0.45, 0, 0, 0, 90], "skin", "Cylinder", "Fabric", None, BROWN))
    for k in range(10):
        ang = k / 10 * 360
        import math as _m
        x, z = _m.cos(_m.radians(ang)) * 0.62, _m.sin(_m.radians(ang)) * 0.62
        d.append(D("RightUpperArm", [0.32, 0.4, 0.32], [x, -0.72, z, 0, 0, 0], "skin", "Block", "Fabric", "Sphere", FEATHER))
    return d


def bracer():
    import math as _m
    d = [
        D("RightLowerArm", [1.05, 1.32, 1.32], [0, 0.0, 0, 0, 0, 90], "skin", "Cylinder", "Metal", None, ARMOR_D),
        D("RightLowerArm", [0.1, 1.38, 1.38], [0, 0.48, 0, 0, 0, 90], "skin", "Cylinder", "Metal", None, GOLD),
        D("RightLowerArm", [0.1, 1.38, 1.38], [0, -0.48, 0, 0, 0, 90], "skin", "Cylinder", "Metal", None, GOLD),
    ]
    for k in range(9):
        a = _m.radians(k / 9 * 360)
        d.append(D("RightLowerArm", [0.34, 0.36, 0.34], [_m.cos(a) * 0.62, -0.72, _m.sin(a) * 0.62, 0, 0, 0], "skin", "Block", "Fabric", "Sphere", FEATHER))
    # garras grossas
    for x in (-0.42, -0.14, 0.14, 0.42):
        d.append(D("RightHand", [0.16, 0.22, 0.55], [x, -0.3, -0.6, -35, 0, 0], "bone", "Wedge", "SmoothPlastic", None, CLAW))
    return d


def belt_and_skirt():
    import math as _m
    d = [
        # faixa larga roxa e cinto marrom por cima
        D("LowerTorso", [2.85, 0.6, 2.6], [0, 0.32, -0.15, 0, 0, 0], "skin", "Block", "Fabric", "Sphere", PURPLE),
        D("LowerTorso", [2.95, 0.22, 2.7], [0, 0.6, -0.15, 0, 0, 0], "skin", "Block", "Fabric", "Sphere", BROWN),
        # barriga saliente
        D("UpperTorso", [2.5, 1.4, 1.5], [0, -0.55, -0.42, 0, 0, 0], "skin", "Block", None, "Sphere", SKIN),
    ]
    # discos verdes em volta do cinto (frente e lados)
    for x in (-1.15, -0.55, 0.55, 1.15):
        z = -1.22 + abs(x) * 0.18
        d.append(D("LowerTorso", [0.18, 0.72, 0.72], [x, 0.32, z, 0, 90 + x * 22, 0], "skin", "Cylinder", "SmoothPlastic", None, GREEN))
        d.append(D("LowerTorso", [0.2, 0.36, 0.36], [x, 0.32, z - 0.03, 0, 90 + x * 22, 0], "skin", "Cylinder", "SmoothPlastic", None, GREEN_D))
    # crânio no centro: calota, órbitas, dentes
    d += [
        D("LowerTorso", [0.62, 0.58, 0.5], [0, 0.38, -1.36, 0, 0, 0], "bone", "Block", "SmoothPlastic", "Sphere", HORN),
        D("LowerTorso", [0.14, 0.14, 0.06], [0.13, 0.42, -1.61, 0, 0, 0], "dark", "Block", None, "Sphere", [20, 16, 20]),
        D("LowerTorso", [0.14, 0.14, 0.06], [-0.13, 0.42, -1.61, 0, 0, 0], "dark", "Block", None, "Sphere", [20, 16, 20]),
        D("LowerTorso", [0.4, 0.14, 0.3], [0, 0.14, -1.49, 0, 0, 0], "bone", "Block", "SmoothPlastic", None, HORN),
    ]
    # cordões roxos com pontas vermelhas pendurados entre os discos
    for x in (-0.85, 0.85):
        z = -1.28
        pts = arc_points([x, 0.15, z], [x * 0.9, -0.65, z - 0.05], [0, 0, -0.08], 3)
        d += curve(D, "LowerTorso", pts, 0.12, "skin", ROPE, taper=0.8, material="Fabric")
        d.append(D("LowerTorso", [0.22, 0.22, 0.22], [x * 0.9, -0.72, z - 0.05, 0, 0, 0], "skin", "Block", "Fabric", "Sphere", [190, 40, 50]))
    # saia de penas: duas camadas em volta do quadril, alternando dourado/âmbar
    # comprimentos irregulares (barra desfiada), penas finas e pontudas
    jag = [1.0, 0.82, 1.12, 0.9, 1.05, 0.78, 1.15, 0.95, 0.86, 1.08]
    for layer, (radius, length, y, count, width) in enumerate([(1.34, 1.45, -0.6, 30, 0.3), (1.2, 1.05, -0.42, 24, 0.34)]):
        for k in range(count):
            ang = k / count * 360 + layer * 6
            a = _m.radians(ang)
            x, z = _m.sin(a) * radius, -_m.cos(a) * radius * 0.85
            L = length * jag[(k * 3 + layer) % len(jag)]
            top = [x * 0.92, y + L * 0.4, z * 0.92]
            bottom = [x * 1.16, y - L * 0.6, z * 1.16]
            color = [FEATHER, FEATHER_D, GOLD][(k + layer) % 3]
            d.append(seg(D, "LowerTorso", top, bottom, [width, 0.1], "skin", color, mesh="Sphere", material="Fabric", up=[x, 0, z]))
    return d


def chest_and_back():
    d = [
        # gola de armadura em volta do pescoço e placa peitoral alta
        D("UpperTorso", [2.9, 0.75, 2.3], [0, 0.9, 0.05, 0, 0, 0], "skin", "Block", "Metal", "Sphere", ARMOR),
        D("UpperTorso", [2.95, 0.14, 2.35], [0, 0.6, 0.05, 0, 0, 0], "skin", "Block", "SmoothPlastic", "Sphere", TRIM),
        D("UpperTorso", [2.3, 0.75, 0.35], [0, 0.45, -1.05, -8, 0, 0], "skin", "Block", "Metal", "Sphere", ARMOR),
        # alças marrons cruzando o peito
        D("UpperTorso", [0.26, 2.4, 0.12], [0.55, 0.0, -1.1, 0, 0, 32], "skin", "Block", "Fabric", None, BROWN),
        D("UpperTorso", [0.26, 2.4, 0.12], [-0.55, 0.0, -1.1, 0, 0, -32], "skin", "Block", "Fabric", None, BROWN),
        # costas: placa de armadura, borlas roxas penduradas e pano
        D("UpperTorso", [2.6, 1.4, 0.4], [0, 0.35, 1.0, 10, 0, 0], "skin", "Block", "Metal", "Sphere", ARMOR),
        D("UpperTorso", [1.1, 1.5, 0.12], [0, -0.55, 1.1, 8, 0, 0], "skin", "Block", "Fabric", "Sphere", PURPLE),
        D("LowerTorso", [2.2, 0.5, 0.5], [0, 0.55, 1.0, 0, 0, 0], "skin", "Block", "Fabric", "Sphere", PURPLE),
    ]
    for x in (-0.4, 0.0, 0.4):
        pts = arc_points([x, 0.75, 1.15], [x * 1.1, -0.25, 1.25], [0, 0, 0.05], 3)
        d += curve(D, "UpperTorso", pts, 0.2, "skin", ROPE, taper=0.6, material="Fabric")
        d.append(D("UpperTorso", [0.32, 0.38, 0.32], [x * 1.1, -0.35, 1.25, 0, 0, 0], "skin", "Block", "Fabric", "Sphere", PURPLE))
    return d


def legs():
    d = [
        # calças bufantes, faixa no tornozelo, garras dos pés
        D("RightUpperLeg", [1.45, 1.1, 1.45], [0, -0.1, 0, 0, 0, 0], "skin", "Block", "Fabric", "Sphere", PANTS),
        D("RightLowerLeg", [0.3, 1.3, 1.3], [0, -0.42, 0, 0, 0, 90], "skin", "Cylinder", "Fabric", None, ARMOR_D),
    ]
    for x in (-0.38, 0.0, 0.38):
        d.append(D("RightFoot", [0.18, 0.2, 0.42], [x, -0.05, -0.85, -10, 0, 0], "bone", "Wedge", "SmoothPlastic", None, CLAW))
    return d


brute_decor = brute_head() + belt_and_skirt() + chest_and_back() + mirror(pauldron() + bracer() + legs())
brute = {
    "parts": brute_parts,
    "root": [3.2, 2.4, 1.8],
    "decor": brute_decor,
    "declarations": biped_declarations(tail=False, knee_rest=34),
    "animSet": "Brute",
}

# ======================================================================= HOUND
# Quadrúpede veloz: corpo horizontal, focinho longo de caveira com mandíbula que abre (junta Jaw),
# espinhos na espinha, cauda longa. Pernas com nomes do R15 (patas da frente = mãos, para o rastro
# das garras); joelhos dobrados em repouso para dar folga às passadas.
hound_parts = mirror([
    P("LowerTorso", [1.5, 1.15, 1.7], "HumanoidRootPart", "Root", [0, -0.2, 0.95, 0, 0, 0], [0, 0, 0, 0, 0, 0], "skin2"),
    P("UpperTorso", [1.8, 1.5, 1.9], "LowerTorso", "Waist", [0, 0.15, -0.8, 0, 0, 0], [0, 0, 0.95, 0, 0, 0]),
    P("Head", [1.05, 0.95, 1.6], "UpperTorso", "Neck", [0, 0.45, -0.85, 12, 0, 0], [0, -0.15, 0.6, 0, 0, 0], "skin2"),
    P("Jaw", [0.85, 0.3, 1.3], "Head", "Jaw", [0, -0.42, 0.25, 0, 0, 0], [0, 0, 0.55, 0, 0, 0], "bone", "Block"),
    P("RightUpperArm", [0.55, 1.25, 0.6], "UpperTorso", "RightShoulder", [0.72, -0.53, -0.35, 12, 0, 0], [0, 0.5, 0, 0, 0, 0]),
    P("RightLowerArm", [0.42, 1.15, 0.45], "RightUpperArm", "RightElbow", [0, -0.55, 0, -30, 0, 0], [0, 0.52, 0, 0, 0, 0], "skin2"),
    P("RightHand", [0.6, 0.28, 0.8], "RightLowerArm", "RightWrist", [0, -0.55, 0, 18, 0, 0], [0, 0.1, -0.15, 0, 0, 0], "skin2", "Block"),
    P("RightUpperLeg", [0.62, 1.3, 0.75], "LowerTorso", "RightHip", [0.6, -0.3, 0.15, -28, 0, 0], [0, 0.55, 0, 0, 0, 0]),
    P("RightLowerLeg", [0.45, 1.25, 0.45], "RightUpperLeg", "RightKnee", [0, -0.6, 0, 48, 0, 0], [0, 0.58, 0, 0, 0, 0], "skin2"),
    P("RightFoot", [0.6, 0.28, 0.85], "RightLowerLeg", "RightAnkle", [0, -0.6, 0, -20, 0, 0], [0, 0.1, -0.2, 0, 0, 0], "skin2", "Block"),
    P("Tail1", [0.5, 0.5, 1.4], "LowerTorso", "Tail1", [0, 0.25, 0.75, -20, 0, 0], [0, 0, -0.68, 0, 0, 0], "skin2"),
    P("Tail2", [0.38, 0.38, 1.3], "Tail1", "Tail2", [0, 0, 0.66, 10, 0, 0], [0, 0, -0.62, 0, 0, 0], "skin2"),
    P("Tail3", [0.25, 0.25, 1.2], "Tail2", "Tail3", [0, 0, 0.62, 10, 0, 0], [0, 0, -0.58, 0, 0, 0], "bone"),
])
hound_decor = [
    # caveira alongada: placa superior, testa, olhos, presas de cima e de baixo
    D("Head", [1.15, 0.45, 1.75], [0, 0.32, -0.1, 0, 0, 0], "mask", "Block", "SmoothPlastic", "Sphere"),
    D("Head", [1.2, 0.3, 0.55], [0, 0.42, 0.35, -15, 0, 0], "mask", "Block", "SmoothPlastic"),
    D("Head", [0.24, 0.12, 0.06], [0.33, 0.25, -0.35, 0, 25, -10], "eye", "Block", "Neon"),
    D("Head", [0.24, 0.12, 0.06], [-0.33, 0.25, -0.35, 0, -25, 10], "eye", "Block", "Neon"),
    D("Head", [0.06, 0.06, 1.3], [0.2, 0.42, -0.1, 0, 0, 0], "accent", "Block", "Neon"),
    D("Head", [0.06, 0.06, 1.3], [-0.2, 0.42, -0.1, 0, 0, 0], "accent", "Block", "Neon"),
    D("UpperTorso", [0.18, 0.7, 0.7], [0, -0.05, -0.65, 0, 90, 0], "dark", "Cylinder"),
] + [D("Head", [0.09, 0.22, 0.09], [-0.36 + i * 0.12, -0.12, -0.72 + (i % 2) * 0.02, 0, 0, 180], "bone", "Wedge") for i in range(7)] \
  + [D("Jaw", [0.09, 0.2, 0.09], [-0.3 + i * 0.12, 0.2, -0.55, 0, 0, 0], "bone", "Wedge") for i in range(6)] \
  + [D("UpperTorso", [0.12, 0.6 - i * 0.08, 0.5], [0, 0.85, 0.6 - i * 0.45, -35, 0, 0], "bone", "Wedge") for i in range(4)] \
  + [D("LowerTorso", [0.1, 0.42, 0.45], [0, 0.65, 0.2 - i * 0.5, -35, 0, 0], "bone", "Wedge") for i in range(2)] \
  + mirror([
    D("RightUpperArm", [0.75, 0.32, 0.8], [0, 0.55, 0, 0, 0, -15], "bone", "Block", "Slate", "Sphere"),
    D("RightHand", [0.08, 0.1, 0.5], [0.18, 0.0, -0.58, -4, 0, 0], "bone", "Wedge"),
    D("RightHand", [0.08, 0.1, 0.5], [-0.05, 0.0, -0.6, -4, 0, 0], "bone", "Wedge"),
    D("RightFoot", [0.08, 0.1, 0.45], [0.15, 0.0, -0.6, -4, 0, 0], "bone", "Wedge"),
    D("Head", [0.2, 0.2, 0.9], [0.38, 0.55, 0.55, 35, 0, -20], "bone", "Block", None, "Sphere"),
])


def quadruped_declarations():
    legs = {}
    hinges = {}
    limits = {"Root": "free", "Waist": {"turn": 60}, "Neck": {"turn": 80}, "Jaw": {"turn": 45}}
    for side in ("Right", "Left"):
        hinges[side + "Elbow"] = {"axis": "X", "flex": -1}
        hinges[side + "Knee"] = {"axis": "X", "flex": 1}
        legs[side + "Shoulder"] = {"hinge": side + "Elbow", "foot": side + "Wrist"}
        legs[side + "Hip"] = {"hinge": side + "Knee", "foot": side + "Ankle"}
        limits[side + "Shoulder"] = {"turn": 120}
        limits[side + "Hip"] = {"turn": 120}
        limits[side + "Elbow"] = {"min": -150, "max": 50}
        limits[side + "Knee"] = {"min": -30, "max": 150}
        limits[side + "Wrist"] = {"turn": 80}
        limits[side + "Ankle"] = {"turn": 80}
    for t in ("Tail1", "Tail2", "Tail3"):
        limits[t] = {"turn": 70}
    return {"version": 1, "feet": ["RightHand", "LeftHand", "RightFoot", "LeftFoot"],
            "hinges": hinges, "limbs": legs, "limits": limits}


hound = {
    "parts": hound_parts,
    "root": [2.0, 1.6, 3.4],
    "decor": hound_decor,
    "declarations": quadruped_declarations(),
    "animSet": "Hound",
}

# ======================================================================= MENOS GRANDE
# Manto preto altíssimo que afina até a máscara branca no topo (nariz longo), espinhos finos
# saindo na altura dos ombros, buraco no peito, mangas largas que terminam em farrapos e barra
# desfiada. Pernas e braços ficam dentro do manto (existem para andar e golpear).
ROBE = [22, 22, 30]
ROBE_L = [44, 44, 58]
ROBE_D = [12, 12, 18]
MASK_W = [244, 240, 232]


def menos_body():
    import math as _m
    parts = mirror([
        P("LowerTorso", [2.0, 1.2, 1.5], "HumanoidRootPart", "Root", [0, -0.3, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], color=ROBE_D),
        P("UpperTorso", [2.2, 2.8, 1.6], "LowerTorso", "Waist", [0, 0.4, 0, -6, 0, 0], [0, -1.3, 0, 0, 0, 0], color=ROBE),
        P("Head", [0.9, 1.3, 0.95], "UpperTorso", "Neck", [0, 2.05, -0.15, 6, 0, 0], [0, -0.55, 0, 0, 0, 0], color=MASK_W, material="SmoothPlastic"),
        P("RightUpperArm", [0.6, 1.5, 0.6], "UpperTorso", "RightShoulder", [1.05, 0.7, 0, 0, 0, 0], [0, 0.65, 0, 0, 0, 0], color=ROBE),
        P("RightLowerArm", [0.5, 1.4, 0.5], "RightUpperArm", "RightElbow", [0, -0.7, 0, 12, 0, 0], [0, 0.65, 0, 0, 0, 0], color=ROBE),
        P("RightHand", [0.55, 0.4, 0.6], "RightLowerArm", "RightWrist", [0, -0.68, 0, 0, 0, 0], [0, 0.15, 0, 0, 0, 0], color=ROBE_D),
        P("RightUpperLeg", [0.8, 1.6, 0.8], "LowerTorso", "RightHip", [0.5, -0.3, 0, 12, 0, 0], [0, 0.75, 0, 0, 0, 0], color=ROBE_D),
        P("RightLowerLeg", [0.7, 1.6, 0.7], "RightUpperLeg", "RightKnee", [0, -0.75, 0, -26, 0, 0], [0, 0.75, 0, 0, 0, 0], color=ROBE_D),
        P("RightFoot", [0.8, 0.3, 1.1], "RightLowerLeg", "RightAnkle", [0, -0.78, 0, 14, 0, 0], [0, 0.1, -0.15, 0, 0, 0], "skin", "Block", color=ROBE_D),
    ])
    decor = []
    # a barra mais comprida fica 0,2 acima da sola (no espaço do LowerTorso): o manto nunca
    # entra no chão e os pés continuam sendo o ponto mais baixo (HipHeight e marchas corretos)
    import rig_reading
    frames = rig_reading.rest_frames({"parts": parts})
    lt_y = frames["LowerTorso"][0][1]
    hem = rig_reading.lowest_point({"parts": parts}) - lt_y + 0.2
    jag = [1.0, 0.86, 0.97, 0.92, 1.0, 0.8, 0.95, 0.9]
    # saia do manto: painéis do quadril até a barra, abrindo em sino, comprimento desfiado
    count = 22
    for k in range(count):
        a = _m.radians(k / count * 360)
        sx, sz = _m.sin(a), -_m.cos(a)
        L = jag[k % len(jag)]
        top = [sx * 1.0, 0.6, sz * 0.75]
        bottom = [sx * 2.4, 0.6 + (hem - 0.6) * L + 0.12, sz * 1.8]
        decor.append(seg(D, "LowerTorso", top, bottom, [0.75, 0.14], "skin", ROBE_L if k % 3 == 0 else ROBE, mesh=None, material="Fabric", up=[sx, 0, sz]))
    # tronco do manto: cone do pescoço até a cintura
    for k in range(16):
        a = _m.radians(k / 16 * 360)
        sx, sz = _m.sin(a), -_m.cos(a)
        top = [sx * 0.42, 1.6, sz * 0.38]
        bottom = [sx * 1.55, -1.35, sz * 1.1]
        decor.append(seg(D, "UpperTorso", top, bottom, [0.75, 0.12], "skin", ROBE if k % 2 else ROBE_L, mesh=None, material="Fabric", up=[sx, 0, sz]))
    # capuz que sobe e envolve a máscara
    for k in range(10):
        a = _m.radians(k / 10 * 360)
        sx, sz = _m.sin(a), -_m.cos(a)
        if sz < -0.6:
            continue  # deixa a frente da máscara à mostra
        # capuz afunila até uma ponta logo acima e atrás da máscara
        decor.append(seg(D, "Head", [sx * 0.62, -0.9, sz * 0.6], [sx * 0.08, 0.95, 0.12 + sz * 0.08], [0.55, 0.12], "skin", ROBE, mesh=None, material="Fabric", up=[sx, 0, sz]))
    # máscara: nariz longo, olhos e boca escuros, sombras lilás
    decor += [
        D("Head", [0.95, 1.2, 0.3], [0, 0.0, -0.42, 0, 0, 0], "mask", "Block", "SmoothPlastic", "Sphere", MASK_W),
        seg(D, "Head", [0, 0.05, -0.55], [0, -0.25, -1.55], 0.26, "mask", MASK_W, mesh="Sphere", material="SmoothPlastic"),
        D("Head", [0.2, 0.26, 0.08], [0.2, 0.25, -0.58, 0, 0, -8], "dark", "Block", None, "Sphere", [10, 8, 12]),
        D("Head", [0.2, 0.26, 0.08], [-0.2, 0.25, -0.58, 0, 0, 8], "dark", "Block", None, "Sphere", [10, 8, 12]),
        D("Head", [0.07, 0.07, 0.04], [0.2, 0.25, -0.63, 0, 0, 0], "eye", "Block", "Neon", "Sphere", [255, 255, 255]),
        D("Head", [0.07, 0.07, 0.04], [-0.2, 0.25, -0.63, 0, 0, 0], "eye", "Block", "Neon", "Sphere", [255, 255, 255]),
        D("Head", [0.36, 0.2, 0.08], [0, -0.38, -0.58, 0, 0, 0], "dark", "Block", None, "Sphere", [10, 8, 12]),
        D("Head", [0.6, 0.3, 0.06], [0, -0.05, -0.57, 0, 0, 0], "skin", "Block", None, "Sphere", [196, 176, 214]),
    ]
    # buraco no peito: vazio escuro com borda
    decor += [
        D("UpperTorso", [0.2, 1.25, 1.0], [0, 0.05, -0.95, 0, 90, 0], "dark", "Cylinder", None, None, [4, 4, 6]),
        D("UpperTorso", [0.12, 1.4, 1.15], [0, 0.05, -0.88, 0, 90, 0], "skin", "Cylinder", "Fabric", None, ROBE_L),
    ]
    # espinhos finos saindo na altura dos ombros
    spikes = []
    for y, out in ((1.25, 1.9), (1.0, 1.5)):
        spikes.append(seg(D, "UpperTorso", [0.55, y, 0.0], [0.55 + out, y + 0.05, 0.0], 0.1, "skin", [70, 70, 80], mesh=None, material="SmoothPlastic"))
    # mangas: abas largas que descem dos ombros até abaixo das mãos, pontas em farrapos
    sleeves = []
    for i, (dx, dz, L) in enumerate([(0.15, -0.35, 1.0), (0.35, 0.0, 1.12), (0.2, 0.35, 0.92)]):
        sleeves.append(seg(D, "RightUpperArm", [dx * 0.3, 0.6, dz], [1.1 + dx, -2.0 * L, dz * 1.3], [1.0, 0.12], "skin", ROBE if i % 2 else ROBE_L, mesh=None, material="Fabric", up=[1, 0, 0]))
        sleeves.append(seg(D, "RightLowerArm", [0.5 + dx, -0.3, dz], [1.5 + dx, -1.7 * L, dz * 1.4], [0.8, 0.1], "skin", ROBE_D, mesh=None, material="Fabric", up=[1, 0, 0]))
        # farrapos nas pontas das mangas
        sleeves.append(seg(D, "RightLowerArm", [1.2 + dx, -1.4 * L, dz * 1.4], [1.75 + dx, -2.2 * L, dz * 1.5], [0.3, 0.08], "skin", ROBE, mesh=None, material="Fabric", up=[1, 0, 0]))
    decor += mirror(spikes + sleeves)
    return parts, decor


menos_parts, menos_decor = menos_body()
menos = {
    "parts": menos_parts,
    "root": [2.6, 3.0, 1.8],
    "decor": menos_decor,
    "declarations": biped_declarations(tail=False, knee_rest=26),
    "animSet": "Menos",
}

rigs = {"HollowGrunt": grunt, "HollowFeral": feral, "HollowBrute": brute, "HollowHound": hound, "MenosGrande": menos}
# Corpo em partes retas, como um corpo R15 normal (sem ovos/cápsulas com cara de massinha):
# tronco, quadril, braços, pernas, mãos e cauda viram blocos que se encaixam nas articulações.
# A cabeça segue arredondada (fica coberta pela máscara).
for body in rigs.values():
    for part in body["parts"]:
        if part.get("mesh") in ("Sphere", "Capsule") and part["name"] != "Head":
            part["mesh"] = "Block"

with open(dest, "w") as f:
    json.dump(rigs, f, indent=1)
print("corpos:", ", ".join(rigs))

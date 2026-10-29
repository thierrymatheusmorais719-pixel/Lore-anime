#!/usr/bin/env python3
"""Gera src/shared/KitDataProcedural.json: os kits visuais de Ichigo e Mugetsu, modelados de forma procedural
a partir das referências em docs/referencia/ (ichigo.png, mugetsu.png).

FONTE ÚNICA: o jogo (ModelKit.luau, via Rojo: .json vira ModuleScript) e a prévia three.js leem o mesmo
arquivo. Coordenadas no padrão Roblox: relativas ao CENTRO do membro R15 indicado em "attach",
personagem olha para -Z, direita = +X, rotações em graus como CFrame.Angles(rx, ry, rz) (= Rx*Ry*Rz).

Rodar: python3 tools/build_kits.py   (depois: python3 preview/gen_data.py)
"""
import json, math, pathlib, random

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "src/shared/KitDataProcedural.json"

# ---------------------------------------------------------------- álgebra 3x3 (listas de linhas)
def mmul(A, B):
    return [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

def rx(d):
    a = math.radians(d); c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]

def ry(d):
    a = math.radians(d); c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]

def rz(d):
    a = math.radians(d); c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]

def angles(a, b, c):  # CFrame.Angles
    return mmul(mmul(rx(a), ry(b)), rz(c))

def apply(R, v):
    return [sum(R[i][k] * v[k] for k in range(3)) for i in range(3)]

def norm(v):
    l = math.sqrt(sum(x * x for x in v)); return [x / l for x in v]

def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]

def add(a, b): return [a[i] + b[i] for i in range(3)]
def scale(a, s): return [x * s for x in a]

def basis(X, Y, Z):  # colunas = eixos locais
    return [[X[0], Y[0], Z[0]], [X[1], Y[1], Z[1]], [X[2], Y[2], Z[2]]]

def frame_y(ydir, zhint):
    """Matriz cujo eixo local +Y aponta para ydir; Z o mais próximo possível de zhint."""
    Y = norm(ydir)
    X = cross(Y, zhint)
    if math.sqrt(sum(x * x for x in X)) < 1e-6:
        X = cross(Y, [1, 0, 0] if abs(Y[0]) < 0.9 else [0, 0, 1])
    X = norm(X); Z = cross(X, Y)
    return basis(X, Y, Z)

def to_euler(R):
    """Decompõe R = Rx*Ry*Rz em graus (inverso de CFrame.Angles)."""
    b = math.asin(max(-1, min(1, R[0][2])))
    if abs(math.cos(b)) > 1e-6:
        a = math.atan2(-R[1][2], R[2][2]); c = math.atan2(-R[0][1], R[0][0])
    else:
        a = math.atan2(R[2][1], R[1][1]); c = 0
    e = [math.degrees(a), math.degrees(b), math.degrees(c)]
    # verificação: recompor tem de dar a mesma matriz
    R2 = angles(*e)
    err = max(abs(R[i][j] - R2[i][j]) for i in range(3) for j in range(3))
    assert err < 1e-6, f"decomposição falhou ({err})"
    return e

def r4(v): return [round(x, 4) for x in v]

# ---------------------------------------------------------------- paleta (das referências)
SKIN = [232, 192, 152]
BLACK = [12, 12, 14]
COAT = [16, 16, 20]
WHITE = [236, 234, 228]
ORANGE = [255, 128, 26]
ORANGE_D = [214, 92, 14]
NAVY = [34, 41, 54]
NAVY_L = [54, 63, 82]
NAVY_TIP = [70, 82, 104]
METAL = [26, 26, 30]
STEEL = [168, 170, 182]
CHAIN = [44, 44, 50]

class Kit:
    def __init__(self):
        self.parts, self.chains = [], []
        self.n = 0

    def part(self, attach, size, pos, R=None, color=BLACK, material="SmoothPlastic", shape="Block", name=None, attachments=None, transparency=0):
        self.n += 1
        p = {
            "name": name or f"P{self.n}", "attach": attach, "shape": shape, "size": r4(size), "pos": r4(pos),
            "rot": r4(to_euler(R)) if R else [0, 0, 0], "color": color, "material": material,
        }
        if transparency:
            p["transparency"] = transparency
        if attachments:
            p["attachments"] = [{"name": a, "pos": r4(v)} for a, v in attachments]
        self.parts.append(p)
        return p

    def spike(self, attach, base, direction, length, width, depth, color, zhint=(0, 0, 1), material="SmoothPlastic", crossed=False):
        R = frame_y(direction, list(zhint))
        center = add(base, scale(norm(direction), length / 2))
        p = self.part(attach, [width, length, depth], center, R, color, material, "Wedge")
        if crossed:  # segunda cunha girada 90° no eixo do espeto: lê como ponta 3D, não como placa
            self.part(attach, [width, length, depth], center, mmul(R, ry(90)), color, material, "Wedge")
        return p

    def chain(self, name, attach, pos, hang_dir, lengths, width, depth, bend, color, zhint=(0, 0, 1)):
        # segmentos pendem ao longo de -Y local: o eixo +Y do primeiro segmento aponta CONTRA o caimento
        R = frame_y(scale(hang_dir, -1), list(zhint))
        self.chains.append({"name": name, "attach": attach, "pos": r4(pos), "rot": r4(to_euler(R)), "lengths": lengths,
                            "width": width, "depth": depth, "bend": bend, "color": color, "material": "SmoothPlastic"})


def skirt(k, ring, length_rng, width, flare, top_y, rxz, color, tip_color, tip_len, gap_front=0.0, rng=None, tip_every=1):
    """Saia/casaco de painéis em anel, abrindo para fora, com dentes (wedges) na barra."""
    for i in range(ring):
        a = 360.0 * (i + 0.5) / ring
        if gap_front and abs(a - 180) < gap_front:
            continue
        ar = math.radians(a)
        n_out = [math.sin(ar), 0, math.cos(ar)]
        tang = [math.cos(ar), 0, -math.sin(ar)]
        f = math.radians(flare)
        Y = norm(add(scale([0, 1, 0], math.cos(f)), scale(n_out, -math.sin(f))))
        Z = norm(cross(tang, Y))
        R = basis(tang, Y, Z)
        L = rng.uniform(*length_rng)
        top = [rxz[0] * math.sin(ar), top_y, rxz[1] * math.cos(ar)]
        center = add(top, scale(Y, -L / 2))
        k.part("LowerTorso", [width, L, 0.08], center, R, color, "Fabric")
        bottom = add(top, scale(Y, -L))
        if i % tip_every == 0:
            for j, off in enumerate((-0.25, 0.25)):
                tl = tip_len * rng.uniform(0.7, 1.25)
                b = add(bottom, scale(tang, off * width))
                tc = tip_color if (j + i) % 2 == 0 else color
                k.spike("LowerTorso", add(b, scale(Y, 0.02)), scale(Y, -1), tl, width * 0.48, 0.07, tc, zhint=n_out)


def chain_helix(k, attach, n, y0, y1, radius, turns, color):
    for i in range(n):
        u = i / (n - 1)
        ang = math.radians(turns * 360 * u)
        p = [radius * math.cos(ang), y0 + (y1 - y0) * u, radius * math.sin(ang)]
        tangent = norm([-math.sin(ang), (y1 - y0) / (turns * 2 * math.pi * radius), math.cos(ang)])
        outward = [math.cos(ang), 0, math.sin(ang)]
        R = frame_y(outward, tangent)  # Y para fora; Z ao longo da corrente
        if i % 2:
            R = mmul(R, rz(90))
        k.part(attach, [0.1, 0.1, 0.24], p, R, color, "Metal")


def sword(k, mugetsu, rng):
    G = rx(-50)  # empunhadura: mesma de antes (ponta da lâmina acima do chão nas poses baixas)
    gp = [0, -0.2, 0]
    def at(local, Rl=None, size=None, color=METAL, material="Metal", shape="Block", name=None, attachments=None):
        pos = add(gp, apply(G, local))
        R = mmul(G, Rl) if Rl else G
        return k.part("RightHand", size, pos, R, color, material, shape, name, attachments)
    blade_len = 3.4 if mugetsu else 3.6
    bz = -(0.55 + blade_len / 2)
    at([0, 0, 0], size=[0.26, 0.26, 0.9], color=BLACK, material="Fabric", name="SwordHandle")
    if mugetsu:
        at([0, 0, -0.5], size=[0.42, 0.42, 0.08], color=METAL)
    else:  # guarda em "manji": quadrado girado + quadrado
        at([0, 0, -0.5], rz(45), size=[0.5, 0.5, 0.08], color=METAL)
        at([0, 0, -0.5], size=[0.36, 0.36, 0.1], color=[50, 50, 56])
    at([0, 0, bz], size=[0.1, 0.44, blade_len], color=([7, 7, 9] if mugetsu else [24, 24, 28]), name="Blade",
       attachments=[("TrailA", [0, 0, blade_len / 2 - 0.15]), ("TrailB", [0, 0, -blade_len / 2]), ("Tip", [0, 0, -blade_len / 2])])
    # TrailA (base) -> TrailB (ponta): o Trail cobre a lâmina inteira = arco largo de corte
    if not mugetsu:  # fio da lâmina
        at([0, -0.2, bz - 0.05], size=[0.105, 0.05, blade_len - 0.1], color=STEEL)
    else:  # espinhos de energia negra ao longo do dorso
        for i in range(7):
            z = -0.9 - i * 0.42
            h = rng.uniform(0.35, 0.65)
            at([0, 0.22, z], rx(rng.uniform(25, 50)), size=[0.06, h, 0.22], color=[5, 5, 7], material="SmoothPlastic", shape="Wedge")
    # corrente do pomo
    for i in range(6 if not mugetsu else 4):
        at([0, -0.12 - 0.14 * i, 0.5 + 0.16 * i], rx(30 + i * 12) if i % 2 == 0 else mmul(rx(30 + i * 12), rz(90)), size=[0.11, 0.11, 0.26], color=CHAIN)


def face(k, mugetsu):
    if mugetsu:
        for s in (-1, 1):
            k.part("Head", [0.26, 0.09, 0.04], [s * 0.25, 0.1, -0.615], None, [200, 24, 34], "Neon")
            k.part("Head", [0.32, 0.06, 0.04], [s * 0.26, 0.19, -0.615], rz(-s * 14), BLACK)
    else:
        for s in (-1, 1):
            k.part("Head", [0.24, 0.1, 0.04], [s * 0.25, 0.08, -0.615], None, [52, 30, 22])
            k.part("Head", [0.34, 0.07, 0.04], [s * 0.26, 0.21, -0.615], rz(-s * 16), ORANGE_D)
        k.part("Head", [0.22, 0.04, 0.03], [0, -0.3, -0.612], None, [120, 70, 60])  # boca séria


def crown(k, rng, color, rings, bias):
    """Cabelo espetado só no TOPO e na NUCA (o rosto fica livre; a frente é a franja).
    rings: (elevação°, quantidade, comprimento); bias: empurra a direção (Ichigo p/ cima, Mugetsu p/ baixo/trás)."""
    k.part("Head", [1.34, 0.55, 1.32], [0, 0.45, 0.06], None, color)       # calota
    k.part("Head", [1.32, 1.0, 0.42], [0, 0.0, 0.5], None, color)          # nuca
    for s_ in (-1, 1):
        k.part("Head", [0.18, 0.85, 1.0], [s_ * 0.66, 0.12, 0.12], None, color)  # costeletas/laterais
    for ring, (elev, count, ln) in enumerate(rings):
        for i in range(count):
            az = 360 * (i + rng.uniform(-0.25, 0.25)) / count + ring * 17
            a = math.radians(az); e = math.radians(elev)
            d0 = [math.sin(a) * math.cos(e), math.sin(e), math.cos(a) * math.cos(e)]
            if d0[2] < -0.25 and elev < 60:  # meia-frente baixa: deixa para a franja
                continue
            d = norm(add(d0, bias))
            base = [0.5 * d0[0], 0.3 + 0.32 * d0[1], 0.06 + 0.48 * d0[2]]
            k.spike("Head", base, d, ln * rng.uniform(0.8, 1.2), rng.uniform(0.34, 0.48), rng.uniform(0.2, 0.3), color, crossed=True)


def build_ichigo(rng):
    k = Kit()
    crown(k, rng, ORANGE, [(78, 5, 0.7), (52, 9, 0.9), (28, 11, 0.95), (6, 9, 0.85)], [0, 0.45, 0.25])
    for i, x in enumerate((-0.44, -0.22, 0.0, 0.22, 0.44)):  # franja curta: termina acima dos olhos
        k.spike("Head", [x, 0.62, -0.52], [x * 0.5, -0.8, -0.5], 0.38 + 0.06 * (i % 2), 0.3, 0.16, ORANGE, zhint=(0, 0, -1))
    face(k, False)
    # kosode: costas, ombros, laterais, lapelas em V com bordas brancas
    k.part("UpperTorso", [2.08, 1.62, 0.1], [0, 0, 0.53], None, COAT, "Fabric")
    k.part("UpperTorso", [2.24, 0.34, 1.14], [0, 0.66, 0], None, COAT, "Fabric")
    for s in (-1, 1):
        k.part("UpperTorso", [0.1, 1.6, 1.06], [s * 1.04, 0, 0], None, COAT, "Fabric")
        k.part("UpperTorso", [0.72, 1.7, 0.1], [s * 0.66, -0.05, -0.53], rz(s * 14), COAT, "Fabric")
        k.part("UpperTorso", [0.09, 1.72, 0.11], [s * 0.33, -0.05, -0.545], rz(s * 14), WHITE, "Fabric")
    k.part("LowerTorso", [2.12, 0.44, 1.12], [0, 0, 0], None, COAT, "Fabric")  # obi
    skirt(k, 16, (2.0, 2.3), 0.62, 9, -0.1, (1.04, 0.6), COAT, WHITE, 0.42, gap_front=16, rng=rng)
    for s in (-1, 1):  # bordas brancas da abertura frontal
        k.part("LowerTorso", [0.1, 2.1, 0.09], [s * 0.2, -1.15, -0.66], rx(-9), WHITE, "Fabric")
    # manga rasgada no braço esquerdo; correntes no direito
    k.part("LeftUpperArm", [1.1, 0.5, 1.1], [0, 0.38, 0], None, COAT, "Fabric")
    for i in range(4):
        a = math.radians(i * 90 + 20)
        k.spike("LeftUpperArm", [0.56 * math.cos(a), 0.14, 0.56 * math.sin(a)], [0, -1, 0], 0.35, 0.4, 0.06, WHITE if i % 2 else COAT, zhint=(math.cos(a), 0, math.sin(a)))
    chain_helix(k, "RightUpperArm", 30, 0.52, -0.52, 0.56, 2.6, CHAIN)
    chain_helix(k, "RightLowerArm", 26, 0.46, -0.46, 0.56, 2.3, CHAIN)
    sword(k, False, rng)
    colors = {"Head": SKIN, "UpperTorso": SKIN, "LowerTorso": COAT, "LeftUpperArm": SKIN, "LeftLowerArm": SKIN, "LeftHand": BLACK,
              "RightUpperArm": SKIN, "RightLowerArm": SKIN, "RightHand": BLACK, "LeftUpperLeg": COAT, "LeftLowerLeg": COAT,
              "LeftFoot": BLACK, "RightUpperLeg": COAT, "RightLowerLeg": COAT, "RightFoot": BLACK}
    return k, colors


def build_mugetsu(rng):
    k = Kit()
    crown(k, rng, BLACK, [(78, 6, 0.9), (52, 10, 1.15), (28, 12, 1.3), (6, 10, 1.25)], [0, -0.15, 0.55])
    # franja: mechas nas laterais dos olhos e uma fina entre eles (olhos ficam visíveis)
    for x, ln, w in ((-0.46, 0.75, 0.26), (-0.24, 0.42, 0.24), (0.0, 0.62, 0.13), (0.24, 0.42, 0.24), (0.46, 0.75, 0.26)):
        k.spike("Head", [x, 0.62, -0.53], [x * 0.25, -0.92, -0.3], ln, w, 0.14, BLACK, zhint=(0, 0, -1))
    # juba longa até o quadril, soprada para a esquerda do personagem (-X) e para trás
    for i in range(14):
        u = i / 13
        az = math.radians(-115 + 230 * u)  # das laterais passando pelas costas
        px, pz = 0.58 * math.sin(az), 0.05 + 0.55 * math.cos(az)
        if pz < -0.15:
            continue
        hang = norm([math.sin(az) * 0.15 - 0.18, -1.0, 0.16 + 0.12 * max(0, math.cos(az))])
        total = rng.uniform(4.6, 6.0) if abs(math.sin(az)) < 0.8 else rng.uniform(3.4, 4.4)
        segs = [round(total * f, 3) for f in (0.22, 0.26, 0.27, 0.25)]
        k.chain(f"Mane{i}", "Head", [px, 0.3 - 0.1 * abs(math.sin(az)), pz], hang, segs,
                round(rng.uniform(0.7, 1.0), 3), round(rng.uniform(0.26, 0.34), 3), -3, BLACK, zhint=(math.sin(az), 0, math.cos(az)))
    for s_ in (-1, 1):  # mechas da frente, sobre os ombros (como na referência)
        k.chain(f"FrontLock{s_}", "Head", [s_ * 0.6, 0.0, -0.2], norm([s_ * 0.25, -1, -0.15]), [0.8, 0.9, 0.9, 0.8], 0.55, 0.26, -2, BLACK, zhint=(s_, 0, 0))
    # máscara (faixa azul-marinho cobrindo nariz e boca)
    k.part("Head", [1.26, 0.52, 1.26], [0, -0.3, 0], None, NAVY, "Fabric")
    k.part("Head", [1.0, 0.07, 0.05], [0, -0.17, -0.64], None, NAVY_L, "Fabric")
    k.part("Head", [0.9, 0.06, 0.05], [0, -0.38, -0.64], None, [24, 29, 38], "Fabric")
    face(k, True)
    # torso enfaixado (cor base marinho no próprio membro) + faixas, placas negras e pele à mostra
    for i in range(6):
        k.part("UpperTorso", [2.04, 0.14, 1.04], [0, 0.62 - i * 0.25, 0], rz(8 if i % 2 else -8), NAVY_L, "Fabric")
    for (x, y, rot, w, h) in ((0.45, 0.35, 20, 0.55, 0.3), (0.7, -0.15, -15, 0.45, 0.35), (0.2, -0.5, 30, 0.6, 0.25), (-0.15, 0.1, -25, 0.4, 0.3),
                              (0.55, 0.65, 5, 0.6, 0.18), (-0.3, -0.45, 12, 0.5, 0.2)):
        k.part("UpperTorso", [w, h, 0.04], [x, y, -0.525], rz(rot), BLACK)
        k.part("UpperTorso", [w * 0.9, h, 0.04], [-x * 0.8, y + 0.05, 0.525], rz(-rot), BLACK)
    for (x, y, w, h) in ((-0.62, 0.3, 0.5, 0.42), (-0.78, -0.25, 0.38, 0.4), (-0.4, -0.6, 0.35, 0.22)):
        k.part("UpperTorso", [w, h, 0.03], [x, y, -0.518], None, SKIN, "SmoothPlastic")
    k.part("UpperTorso", [0.03, 0.9, 0.6], [-1.012, 0.1, -0.1], None, SKIN)
    # braço esquerdo de pele com listras negras; braço direito enfaixado (cor do membro) com faixas
    for seg, n in (("LeftUpperArm", 5), ("LeftLowerArm", 4)):
        for i in range(n):
            y = 0.45 - i * (0.9 / (n - 1))
            k.part(seg, [0.62, 0.1, 0.03], [0.05, y, -0.515], rz(rng.uniform(-35, 35)), BLACK)
            k.part(seg, [0.03, 0.1, 0.62], [-0.515, y - 0.08, 0.05], rx(rng.uniform(-35, 35)), BLACK)
            k.part(seg, [0.5, 0.08, 0.03], [-0.1, y - 0.1, 0.515], rz(rng.uniform(-30, 30)), BLACK)
    for seg in ("RightUpperArm", "RightLowerArm"):
        for i in range(3):
            k.part(seg, [1.04, 0.1, 1.04], [0, 0.35 - i * 0.35, 0], rz(rng.uniform(-10, 10)), NAVY_L, "Fabric")
    # saia longa toda rasgada, pontas cinza-azuladas
    k.part("LowerTorso", [2.12, 0.44, 1.12], [0, 0, 0], None, [20, 22, 28], "Fabric")
    skirt(k, 20, (2.25, 2.55), 0.58, 11, -0.1, (1.05, 0.62), COAT, NAVY_TIP, 0.48, rng=rng)
    sword(k, True, rng)
    colors = {"Head": SKIN, "UpperTorso": NAVY, "LowerTorso": COAT, "LeftUpperArm": SKIN, "LeftLowerArm": SKIN, "LeftHand": SKIN,
              "RightUpperArm": NAVY, "RightLowerArm": NAVY, "RightHand": NAVY, "LeftUpperLeg": COAT, "LeftLowerLeg": COAT,
              "LeftFoot": BLACK, "RightUpperLeg": COAT, "RightLowerLeg": COAT, "RightFoot": BLACK}
    return k, colors


def main():
    data = {"version": 2, "source": "tools/build_kits.py (referências: docs/referencia/)", "forms": {}}
    for name, fn in (("Ichigo", build_ichigo), ("Mugetsu", build_mugetsu)):
        k, colors = fn(random.Random(20 if name == "Ichigo" else 21))
        data["forms"][name] = {"limbColors": colors, "hideFace": True, "parts": k.parts, "chains": k.chains}
        segs = sum(len(c["lengths"]) for c in k.chains)
        print(f"{name}: {len(k.parts)} peças + {len(k.chains)} mechas ({segs} segmentos) = {len(k.parts) + segs} instâncias")
    OUT.write_text(json.dumps(data, separators=(",", ":")))
    print("escrito", OUT.relative_to(ROOT), f"({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()

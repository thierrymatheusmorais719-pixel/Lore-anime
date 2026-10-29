#!/usr/bin/env python3
"""Prepara um modelo 3D esculpido (malha densa, sem rig) para o kit do jogo.

Entrada: OBJ de corpo inteiro (ex.: assets/models/source/Mugetsu_Roblox.obj, Y para cima).
Saída:
  * assets/models/mugetsu_mesh/MugetsuMesh.obj  -> UM arquivo com os pedaços nomeados por membro R15
    + um cubo "Root" na origem do HumanoidRootPart. É o arquivo que se importa no Roblox Studio.
  * src/shared/MeshKitManifest.json -> como cada pedaço se prende ao rig, cor, material, attachments
    (rastro da espada) e peças extras (olhos). Lido pelo ModelKit (jogo) e pela prévia.

Etapas: remove fragmentos soltos -> gira 180° (frente em -Z) -> centraliza pelo tronco e escala do pé ao
ombro para o R15 -> segmenta (espada por proximidade da linha cabo->ponta; cabeça em cabelo/rosto/máscara;
braços/mãos/tronco/casaco/pernas por regiões do R15 em repouso) -> reduz cada pedaço -> exporta.

Requer: pip install trimesh numpy scipy fast-simplification
Uso: python3 tools/import_mesh.py <entrada.obj>
"""
import json, pathlib, sys
import numpy as np
import trimesh
import fast_simplification as fs

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_OBJ = ROOT / "assets/models/mugetsu_mesh/MugetsuMesh.obj"
OUT_MANIFEST = ROOT / "src/shared/MeshKitManifest.json"

# R15 em repouso (relativo ao HumanoidRootPart): pés -3, ombro/pescoço +1.8, cotovelo +0.4, punho -0.7.
FEET, SHOULDER = -3.0, 1.8
ELBOW_Y, WRIST_Y, NECK_Y, WAIST_Y = 0.4, -0.75, 1.85, -0.1
SHOULDER_TOP_SRC = 0.45  # altura do ombro no arquivo de origem (medida pelo perfil de largura)

# Cores (das imagens de referência do Mugetsu) e orçamento de triângulos por pedaço.
PIECES = {
    "Head_Hair":       ("Head",          [14, 14, 17], "SmoothPlastic", 9000),
    "Head_Face":       ("Head",          [232, 192, 152], "SmoothPlastic", 1200),
    "Head_Mask":       ("Head",          [40, 48, 62], "Fabric", 1500),
    "UpperTorso":      ("UpperTorso",    [24, 27, 34], "Fabric", 6000),
    "LowerTorso_Coat": ("LowerTorso",    [16, 16, 20], "Fabric", 9000),
    "RightUpperArm":   ("RightUpperArm", [40, 48, 62], "Fabric", 2500),
    "RightLowerArm":   ("RightLowerArm", [40, 48, 62], "Fabric", 2500),
    "RightHand":       ("RightHand",     [40, 48, 62], "Fabric", 1200),
    "LeftUpperArm":    ("LeftUpperArm",  [18, 18, 22], "Fabric", 2500),
    "LeftLowerArm":    ("LeftLowerArm",  [18, 18, 22], "Fabric", 2500),
    "RightLowerLeg":   ("RightLowerLeg", [16, 16, 20], "Fabric", 1500),
    "LeftLowerLeg":    ("LeftLowerLeg",  [16, 16, 20], "Fabric", 1500),
    "Blade":           ("RightHand",     [8, 8, 10], "Metal", 2500),
}


def load_main(path):
    m = trimesh.load(path, force="mesh", process=False)
    m = trimesh.Trimesh(m.vertices, m.faces, process=True)
    parts = m.split(only_watertight=False)
    main = max(parts, key=lambda p: len(p.faces))
    print(f"original: {len(m.faces)} triângulos; corpo principal: {len(main.faces)} (descartados {len(parts) - 1} fragmentos)")
    return main


def to_r15(mesh):
    V = mesh.vertices.copy()
    V[:, 0] *= -1; V[:, 2] *= -1  # 180° em Y: o arquivo olha para +Z, o Roblox para -Z
    sl = V[(V[:, 1] > 0.1) & (V[:, 1] < 0.4)]
    cx = (np.percentile(sl[:, 0], 2) + np.percentile(sl[:, 0], 98)) / 2
    cz = (np.percentile(sl[:, 2], 2) + np.percentile(sl[:, 2], 98)) / 2
    feet = V[:, 1].min()
    s = (SHOULDER - FEET) / (SHOULDER_TOP_SRC - feet)
    R = (V - [cx, feet, cz]) * s + [0, FEET, 0]
    print(f"escala {s:.3f}; altura final {R[:, 1].max() - R[:, 1].min():.2f} studs")
    return trimesh.Trimesh(R, mesh.faces, process=False)


def seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(P - (a + np.outer(t, ab)), axis=1), t


def segment(mesh):
    C = mesh.triangles_center
    N = mesh.face_normals
    labels = np.full(len(C), "", dtype=object)

    # --- espada: ponta = ponto mais à esquerda/frente perto do chão; cabo = centro da mão direita
    V = mesh.vertices
    low = V[(V[:, 1] < -1.9) & (V[:, 2] < -1.2)]
    tip = low[np.argmin(low[:, 0] + low[:, 2])]
    handpts = V[(V[:, 0] > 1.15) & (V[:, 1] < -0.8) & (V[:, 1] > -1.35)]
    grip = handpts.mean(0)
    d, t = seg_dist(C, grip, tip)
    # A katana é CURVA: a linha reta cabo->ponta se afasta da lâmina no meio. Raio folgado (0.4), mas só
    # conta como espada o que fica NA FRENTE da superfície do casaco naquele (x, y).
    dv, _ = seg_dist(V, grip, tip)
    body = V[dv > 0.45]
    cell = 0.1
    keys = np.floor(body[:, :2] / cell).astype(int)
    front = {}
    for (kx, ky), zz in zip(map(tuple, keys), body[:, 2]):
        if zz < front.get((kx, ky), 1e9):
            front[(kx, ky)] = zz
    ck = np.floor(C[:, :2] / cell).astype(int)
    coat_front = np.array([front.get((kx, ky), np.inf) for kx, ky in map(tuple, ck)])
    blade = (d < 0.4) & (t > 0.06) & (C[:, 2] < coat_front - 0.02)
    guard = (np.linalg.norm(C - grip, axis=1) < 0.55) & ((C[:, 2] < grip[2] - 0.1) | (C[:, 1] < grip[1] - 0.25)) & (C[:, 0] > 1.0)
    sel = np.where(blade | guard)[0]
    # onde a lâmina passa rente ao casaco, pedaços do casaco caem no raio; eles formam ilhas separadas
    # dentro da seleção. Mantém só as ilhas grandes (lâmina + guarda), o resto volta para o corpo.
    sub = mesh.submesh([sel], append=True, repair=False)
    comp = trimesh.graph.connected_component_labels(sub.face_adjacency, node_count=len(sub.faces))
    counts = np.bincount(comp)
    sc = sub.triangles_center
    keep_ids = []
    for cid in range(len(counts)):
        pts = sc[comp == cid]
        ext = float(np.linalg.norm(pts.max(0) - pts.min(0)))
        dg = float(np.linalg.norm(pts.mean(0) - grip))
        # lâmina: ilha longa (>1.5 stud). guarda/mão: ilha compacta bem junto ao cabo. O resto é casaco.
        ok = ext > 1.5 or dg < 0.45
        print(f"  ilha {cid}: {counts[cid]:5d} tri, extensão {ext:.2f}, dist. ao cabo {dg:.2f} -> {'espada' if ok else 'casaco'}")
        if ok:
            keep_ids.append(cid)
    keep = np.isin(comp, keep_ids)
    labels[sel[keep]] = "Blade"
    print(f"espada: cabo {grip.round(2)} -> ponta {tip.round(2)}  ({(blade | guard).sum()} triângulos)")

    rest = labels == ""
    x, y, z = C[:, 0], C[:, 1], C[:, 2]

    # --- cabeça: cabelo / rosto / máscara
    head = rest & (y > NECK_Y)
    hc = np.array([np.median(x[head]), 0, np.median(z[head])])
    front = head & (np.abs(x - hc[0]) < 0.5) & (y > 1.95) & (y < 2.75) & (N[:, 2] < -0.35) & (z < hc[2] - 0.3)
    labels[head] = "Head_Hair"
    labels[front & (y >= 2.32)] = "Head_Face"
    labels[front & (y < 2.32)] = "Head_Mask"

    # --- braços: só dentro da COLUNA de cada braço (medida no braço, acima do casaco), para não levar
    #     junto a lateral do casaco que abre na altura das mãos.
    rest = labels == ""
    Vv = mesh.vertices
    for side, sx in (("Right", 1), ("Left", -1)):
        col = Vv[(sx * Vv[:, 0] > 1.05) & (Vv[:, 1] > 0.6) & (Vv[:, 1] < 1.3)]
        ax, az = float(np.median(col[:, 0])), float(np.median(col[:, 2]))
        in_col = rest & (np.abs(x - ax) < 0.62) & (np.abs(z - az) < 0.62) & (y < SHOULDER + 0.1)
        in_col &= (sx * x > (0.86 if side == "Right" else 0.98))
        labels[in_col & (y >= ELBOW_Y)] = f"{side}UpperArm"
        labels[in_col & (y < ELBOW_Y) & (y >= WRIST_Y)] = f"{side}LowerArm"
        # mão: só a direita existe na malha (segura a espada); a esquerda some dentro da manga
        if side == "Right":
            near = rest & (np.linalg.norm(C - grip, axis=1) < 0.5) & (y < WRIST_Y + 0.05) & (x > 1.15)
            near &= (np.abs(x - ax) < 0.5) & (np.abs(z - az) < 0.75)  # só dentro da coluna do braço
            labels[near & (labels == "")] = "RightHand"
        print(f"braço {side}: coluna x={ax:.2f} z={az:.2f}")

    # --- pernas visíveis abaixo do casaco
    rest = labels == ""
    legs = rest & (y < -2.55) & (np.abs(x) < 1.05) & (np.abs(z) < 0.78)
    labels[legs & (x >= 0)] = "RightLowerLeg"
    labels[legs & (x < 0)] = "LeftLowerLeg"

    # --- tronco e casaco
    rest = labels == ""
    labels[rest & (y >= WAIST_Y)] = "UpperTorso"
    labels[rest & (y < WAIST_Y)] = "LowerTorso_Coat"
    return labels, grip, tip, hc


def decimate(mesh, target):
    if len(mesh.faces) <= target:
        return mesh
    v, f = fs.simplify(mesh.vertices.astype(np.float32), mesh.faces.astype(np.int32), target_reduction=1 - target / len(mesh.faces))
    return trimesh.Trimesh(v, f, process=True)


def main():
    src = pathlib.Path(sys.argv[1])
    mesh = to_r15(load_main(src))
    labels, grip, tip, hc = segment(mesh)
    OUT_OBJ.parent.mkdir(parents=True, exist_ok=True)
    pieces, total = {}, 0
    lines = ["# MugetsuMesh: pedaços por membro R15, coordenadas em studs relativas ao HumanoidRootPart",
             "# gerado por tools/import_mesh.py — importe no Roblox Studio (3D Importer), sem mesclar malhas"]
    vbase = 1

    def emit(name, V, F):
        nonlocal vbase
        lines.append(f"o {name}")
        lines.extend(f"v {a:.5f} {b:.5f} {c:.5f}" for a, b, c in V)
        lines.extend(f"f {i + vbase} {j + vbase} {k + vbase}" for i, j, k in F)
        vbase += len(V)

    # marcador de referência: cubo de 0.2 stud na origem do HRP
    cube = trimesh.creation.box(extents=[0.2, 0.2, 0.2])
    emit("Root", cube.vertices, cube.faces)
    for name, (limb, color, material, budget) in PIECES.items():
        sel = np.where(labels == name)[0]
        if len(sel) == 0:
            print(f"  aviso: pedaço {name} vazio")
            continue
        sub = mesh.submesh([sel], append=True)
        sub = decimate(sub, budget)
        bb = sub.bounds
        center = (bb[0] + bb[1]) / 2  # o Studio coloca a origem do MeshPart no centro da caixa
        info = {"attach": limb, "color": color, "material": material, "triangles": int(len(sub.faces)), "center": [round(float(c), 4) for c in center]}
        if name == "Blade":
            info["attachments"] = [
                {"name": "TrailA", "pos": [round(float(c), 4) for c in (grip + (tip - grip) * 0.12 - center)]},
                {"name": "TrailB", "pos": [round(float(c), 4) for c in (tip - center)]},
                {"name": "Tip", "pos": [round(float(c), 4) for c in (tip - center)]},
            ]
        pieces[name] = info
        total += len(sub.faces)
        emit(name, sub.vertices, sub.faces)
        print(f"  {name:16s} -> {limb:14s} {len(sub.faces):6d} triângulos")
    OUT_OBJ.write_text("\n".join(lines) + "\n")
    # olhos vermelhos (a malha não tem cor nem olhos): peças simples presas à cabeça, na frente do rosto
    face_z = float(np.percentile(mesh.vertices[(np.abs(mesh.vertices[:, 0] - hc[0]) < 0.45) & (np.abs(mesh.vertices[:, 1] - 2.45) < 0.12)][:, 2], 3))
    extras = [{"name": f"Eye{s}", "attach": "Head", "shape": "Block", "size": [0.24, 0.08, 0.04],
               "worldPos": [round(hc[0] + s * 0.24, 4), 2.45, round(face_z - 0.02, 4)], "color": [200, 24, 34], "material": "Neon"} for s in (-1, 1)]
    manifest = {"version": 1, "form": "Mugetsu", "source": f"tools/import_mesh.py <- {src.name}", "replaceBody": True,
                "file": "assets/models/mugetsu_mesh/MugetsuMesh.obj", "rootName": "Root", "pieces": pieces, "extras": extras,
                "totalTriangles": int(total)}
    OUT_MANIFEST.write_text(json.dumps(manifest, indent=1))
    print(f"total {total} triângulos; escrito {OUT_OBJ.relative_to(ROOT)} e {OUT_MANIFEST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

"""
Cena de teste: dois lutadores ORIGINAIS com rig R15, luta curta e câmeras.

  * AKIRA  — feiticeiro de energia (casaco marfim/turquesa, olhos turquesa)
  * KUROZAN — rei demónio (chifres, armadura carmesim, olhos dourados)

Cada parte do corpo é uma malha rígida com o nome do bone R15
(Akira_UpperTorso, Kurozan_RightHand...), presa ao bone, como no Roblox.
1 unidade do Blender = 1 stud (studs_per_unit = 1 no exportador).

Uso:
  blender --background --python build_demo_fighters.py -- <pasta_saida>
Gera <pasta_saida>/luta_teste.blend
"""

import math
import os
import sys

import bpy  # noqa: I001  (bpy tem de vir antes do bmesh fora do Blender)
import bmesh
from mathutils import Euler, Matrix, Vector

R = math.radians

# ---------------------------------------------------------------------------
# Esqueleto R15 (personagem a olhar para -Y; direita do personagem = -X)
# ---------------------------------------------------------------------------
BONES = {
    #  nome:            (head,               tail,                parent)
    "HumanoidRootPart": ((0, 0, 2.6), (0, 0, 3.0), None),
    "LowerTorso": ((0, 0, 2.45), (0, 0, 2.95), "HumanoidRootPart"),
    "UpperTorso": ((0, 0, 2.95), (0, 0, 4.2), "LowerTorso"),
    "Head": ((0, 0, 4.25), (0, 0, 5.2), "UpperTorso"),
    "RightUpperArm": ((-0.78, 0, 4.0), (-0.78, 0, 3.15), "UpperTorso"),
    "RightLowerArm": ((-0.78, 0, 3.15), (-0.78, 0, 2.35), "RightUpperArm"),
    "RightHand": ((-0.78, 0, 2.35), (-0.78, 0, 2.0), "RightLowerArm"),
    "LeftUpperArm": ((0.78, 0, 4.0), (0.78, 0, 3.15), "UpperTorso"),
    "LeftLowerArm": ((0.78, 0, 3.15), (0.78, 0, 2.35), "LeftUpperArm"),
    "LeftHand": ((0.78, 0, 2.35), (0.78, 0, 2.0), "LeftLowerArm"),
    "RightUpperLeg": ((-0.3, 0, 2.45), (-0.3, 0, 1.35), "LowerTorso"),
    "RightLowerLeg": ((-0.3, 0, 1.35), (-0.3, 0, 0.3), "RightUpperLeg"),
    "RightFoot": ((-0.3, 0, 0.3), (-0.3, -0.4, 0.08), "RightLowerLeg"),
    "LeftUpperLeg": ((0.3, 0, 2.45), (0.3, 0, 1.35), "LowerTorso"),
    "LeftLowerLeg": ((0.3, 0, 1.35), (0.3, 0, 0.3), "LeftUpperLeg"),
    "LeftFoot": ((0.3, 0, 0.3), (0.3, -0.4, 0.08), "LeftLowerLeg"),
}
CONNECTED = {"RightLowerArm", "RightHand", "LeftLowerArm", "LeftHand",
             "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot"}


# ---------------------------------------------------------------------------
# Materiais
# ---------------------------------------------------------------------------
def material(name, color, emission=0.0, rough=0.6, metal=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emission:
        p.inputs["Emission Color"].default_value = (*color, 1)
        p.inputs["Emission Strength"].default_value = emission
    m.diffuse_color = (*color, 1)
    return m


def hexc(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


# ---------------------------------------------------------------------------
# Construção de peças (bmesh) — tudo em coordenadas do mundo, rig na origem
# ---------------------------------------------------------------------------
class PartBuilder:
    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []

    def _mat_index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _finish(self, geom_verts, mat, smooth, loc, rot, scale=(1, 1, 1)):
        mtx = Matrix.Translation(loc) @ Euler([R(a) for a in rot]).to_matrix().to_4x4() \
            @ Matrix.Diagonal((*scale, 1))
        bmesh.ops.transform(self.bm, matrix=mtx, verts=geom_verts)
        idx = self._mat_index(mat)
        faces = {f for v in geom_verts for f in v.link_faces}
        for f in faces:
            f.material_index = idx
            f.smooth = smooth

    def box(self, size, loc, mat, rot=(0, 0, 0), bevel=0.06):
        before = set(self.bm.verts)
        res = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = res["verts"]
        bmesh.ops.scale(self.bm, vec=size, verts=verts)
        if bevel:
            edges = list({e for v in verts for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=2,
                            affect="EDGES", profile=0.5)
            verts = [v for v in self.bm.verts if v not in before]
        self._finish(verts, mat, False, loc, rot)

    def sphere(self, radius, loc, mat, scale=(1, 1, 1), rot=(0, 0, 0), segs=20):
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=segs, v_segments=segs // 2,
                                        radius=radius)
        self._finish(res["verts"], mat, True, loc, rot, scale)

    def cone(self, r1, r2, depth, loc, mat, rot=(0, 0, 0), segs=16, scale=(1, 1, 1)):
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segs,
                                    radius1=r1, radius2=r2, depth=depth)
        self._finish(res["verts"], mat, True, loc, rot, scale)

    def to_object(self, name, rig, bone_name):
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        obj = bpy.data.objects.new(name, me)
        rig.users_collection[0].objects.link(obj)
        bone = rig.data.bones[bone_name]
        obj.parent = rig
        obj.parent_type = "BONE"
        obj.parent_bone = bone_name
        obj.matrix_parent_inverse = (
            bone.matrix_local @ Matrix.Translation((0, bone.length, 0))).inverted()
        return obj


# ---------------------------------------------------------------------------
def build_rig(name, coll):
    arm = bpy.data.armatures.new(name)
    rig = bpy.data.objects.new(name, arm)
    coll.objects.link(rig)
    arm.display_type = "STICK"
    rig.show_in_front = True
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, (h, t, parent) in BONES.items():
        eb = arm.edit_bones.new(bname)
        eb.head, eb.tail, eb.roll = h, t, 0
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = bname in CONNECTED
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
    return rig


def limbs(parts, skin, sleeve, sleeve_r, hand_mat, pants, pants_r, boot):
    for side, sx in (("Right", -0.78), ("Left", 0.78)):
        parts[f"{side}UpperArm"].sphere(0.26, (sx, 0, 3.95), sleeve)  # ombro
        parts[f"{side}UpperArm"].cone(sleeve_r, sleeve_r * 0.9, 0.9, (sx, 0, 3.58), sleeve)
        parts[f"{side}LowerArm"].cone(sleeve_r * 0.9, sleeve_r * 0.85, 0.82, (sx, 0, 2.76), sleeve)
        parts[f"{side}Hand"].box((0.26, 0.3, 0.36), (sx, -0.02, 2.17), hand_mat, bevel=0.08)
        lx = -0.3 if side == "Right" else 0.3
        parts[f"{side}UpperLeg"].cone(pants_r, pants_r * 0.88, 1.12, (lx, 0, 1.9), pants)
        parts[f"{side}LowerLeg"].cone(pants_r * 0.88, pants_r * 0.8, 1.05, (lx, 0, 0.83), pants)
        parts[f"{side}Foot"].box((0.3, 0.55, 0.22), (lx, -0.1, 0.12), boot, bevel=0.07)


def build_akira(coll):
    rig = build_rig("AKIRA_RIG", coll)
    skin = material("Akira_Pele", hexc("f2d6c4"))
    coat = material("Akira_Casaco", hexc("ece6d8"), rough=0.5)
    trim = material("Akira_Turquesa", hexc("1fb5a8"), rough=0.35)
    pants = material("Akira_Calca", hexc("2b2f3a"))
    boot = material("Akira_Bota", hexc("15161b"), rough=0.3)
    hair = material("Akira_Cabelo", hexc("b9d6dd"), rough=0.4)
    eye = material("Akira_Olho", hexc("3ff5e0"), emission=6.0)
    glove = material("Akira_Luva", hexc("1c1e26"), rough=0.4)

    P = {b: PartBuilder() for b in BONES if b != "HumanoidRootPart"}
    # tronco: casaco com gola alta e faixa turquesa
    P["UpperTorso"].box((1.25, 0.62, 1.3), (0, 0, 3.58), coat)
    P["UpperTorso"].box((0.08, 0.64, 1.25), (0, -0.01, 3.58), trim, bevel=0.02)
    P["UpperTorso"].cone(0.36, 0.33, 0.45, (0, 0, 4.25), trim)
    P["LowerTorso"].box((1.1, 0.56, 0.55), (0, 0, 2.7), coat)
    P["LowerTorso"].box((1.14, 0.6, 0.1), (0, 0, 2.95), trim, bevel=0.02)
    # aba do casaco até aos joelhos
    P["LowerTorso"].cone(0.62, 0.78, 1.15, (0, 0.04, 1.95), coat, segs=20, scale=(1, 0.75, 1))
    # cabeça
    P["Head"].sphere(0.44, (0, 0, 4.75), skin, scale=(1, 1, 1.12))
    for sx in (-0.15, 0.15):
        P["Head"].sphere(0.075, (sx, -0.4, 4.78), eye, scale=(1.3, 0.4, 0.8))
    # cabelo: madeixas penteadas para trás
    for i, (x, z, ry) in enumerate([(-0.25, 5.1, -25), (0, 5.2, 0), (0.25, 5.1, 25),
                                    (-0.35, 4.95, -45), (0.35, 4.95, 45),
                                    (-0.12, 5.18, -10), (0.12, 5.18, 10)]):
        P["Head"].cone(0.2, 0.0, 0.85, (x, 0.22, z), hair, rot=(-65, ry, 0), segs=8,
                       scale=(1, 0.6, 1))
    P["Head"].sphere(0.47, (0, 0.05, 4.92), hair, scale=(1, 1.05, 0.7))
    limbs(P, skin, coat, 0.2, glove, pants, 0.22, boot)
    for side, sx in (("Right", -0.78), ("Left", 0.78)):
        P[f"{side}LowerArm"].cone(0.215, 0.215, 0.12, (sx, 0, 2.42), trim)  # punho turquesa
    for b, pb in P.items():
        pb.to_object(f"Akira_{b}", rig, b)
    return rig


def build_kurozan(coll):
    rig = build_rig("KUROZAN_RIG", coll)
    skin = material("Kurozan_Pele", hexc("c99878"))
    armor = material("Kurozan_Armadura", hexc("8e1622"), rough=0.35, metal=0.3)
    gold = material("Kurozan_Ouro", hexc("d9a441"), rough=0.25, metal=0.9)
    hakama = material("Kurozan_Hakama", hexc("17131a"))
    horn = material("Kurozan_Chifre", hexc("2a0f12"), rough=0.3)
    hair = material("Kurozan_Cabelo", hexc("1a1a22"), rough=0.45)
    eye = material("Kurozan_Olho", hexc("ffc23d"), emission=8.0)
    wrap = material("Kurozan_Faixa", hexc("e8e0d0"))

    P = {b: PartBuilder() for b in BONES if b != "HumanoidRootPart"}
    # tronco nu com placas de armadura e cinto dourado
    P["UpperTorso"].box((1.35, 0.66, 1.3), (0, 0, 3.58), skin)
    P["UpperTorso"].box((1.4, 0.7, 0.55), (0, 0, 3.95), armor, bevel=0.08)
    for sx in (-0.82, 0.82):
        P["UpperTorso"].sphere(0.36, (sx, 0, 4.05), armor, scale=(1, 1, 0.75))
        P["UpperTorso"].sphere(0.37, (sx, 0, 4.0), gold, scale=(1.02, 1.02, 0.25))
    P["LowerTorso"].box((1.2, 0.6, 0.55), (0, 0, 2.7), hakama)
    P["LowerTorso"].box((1.26, 0.66, 0.2), (0, 0, 2.95), gold, bevel=0.04)
    # cabeça, chifres, olhos dourados e cabelo comprido preso
    P["Head"].sphere(0.45, (0, 0, 4.72), skin, scale=(1, 1, 1.08))
    for sx, ry in ((-0.25, -30), (0.25, 30)):
        P["Head"].cone(0.11, 0.0, 0.55, (sx, -0.05, 5.25), horn, rot=(10, ry, 0), segs=10)
        P["Head"].sphere(0.07, (sx * 0.6, -0.41, 4.76), eye, scale=(1.4, 0.4, 0.7))
    P["Head"].box((0.5, 0.03, 0.05), (0, -0.44, 4.62), gold, bevel=0.01)  # pintura facial
    P["Head"].sphere(0.48, (0, 0.06, 4.95), hair, scale=(1, 1.05, 0.65))
    P["Head"].cone(0.16, 0.06, 1.4, (0, 0.55, 4.3), hair, rot=(25, 0, 0), segs=10)  # rabo
    limbs(P, skin, skin, 0.21, skin, hakama, 0.32, horn)
    for side, sx in (("Right", -0.78), ("Left", 0.78)):
        P[f"{side}LowerArm"].cone(0.225, 0.225, 0.45, (sx, 0, 2.6), wrap)  # ligaduras
        P[f"{side}UpperArm"].cone(0.225, 0.225, 0.1, (sx, 0, 3.45), gold)  # bracelete
    for b, pb in P.items():
        pb.to_object(f"Kurozan_{b}", rig, b)
    return rig


# ---------------------------------------------------------------------------
# Animação (60 fps). Eixos (bones verticais, roll 0):
#   braço/perna (aponta para baixo): X- = para a frente; Z+ = afastar à direita
#   tronco/cabeça (apontam para cima): X+ = dobrar à frente; Y = torção; Z+ = inclinar p/ direita
#   LowerTorso location: x = lado, y = cima, z = frente
# ---------------------------------------------------------------------------
GUARD = {
    "LowerTorso": {"loc": (0, -0.18, 0), "rot": (0, 0, 0)},
    "UpperTorso": (8, 0, 0),
    "Head": (-8, 0, 0),
    "RightUpperArm": (-45, 0, 12), "RightLowerArm": (-100, 0, 0),
    "LeftUpperArm": (-55, 0, -12), "LeftLowerArm": (-105, 0, 0),
    "RightUpperLeg": (14, 0, 6), "RightLowerLeg": (18, 0, 0), "RightFoot": (-10, 0, 0),
    "LeftUpperLeg": (-24, 0, -6), "LeftLowerLeg": (22, 0, 0), "LeftFoot": (0, 0, 0),
    "RightHand": (0, 0, 0), "LeftHand": (0, 0, 0),
}


def pose(base=GUARD, **over):
    p = {k: (dict(v) if isinstance(v, dict) else v) for k, v in base.items()}
    for k, v in over.items():
        if k == "loc":
            p["LowerTorso"]["loc"] = v
        elif k == "hip":
            p["LowerTorso"]["rot"] = v
        else:
            p[k] = v
    return p


def key(rig, frame, p):
    for bname, v in p.items():
        pb = rig.pose.bones[bname]
        if isinstance(v, dict):
            pb.location = v["loc"]
            pb.rotation_euler = [R(a) for a in v["rot"]]
            pb.keyframe_insert("location", frame=frame)
        else:
            pb.rotation_euler = [R(a) for a in v]
        pb.keyframe_insert("rotation_euler", frame=frame)


def animate(akira, kurozan):
    A, K = akira, kurozan
    # ---- AKIRA (ataca) ----
    key(A, 0, pose())
    key(A, 18, pose(loc=(0, -0.3, -0.1), hip=(0, 15, 0), UpperTorso=(12, 20, 0),
                    RightUpperArm=(-20, 0, 15), RightLowerArm=(-125, 0, 0)))          # antecipação
    key(A, 26, pose(loc=(0, -0.12, 0.9), hip=(0, -15, 0), UpperTorso=(18, -25, 0),
                    RightUpperArm=(-92, 0, -4), RightLowerArm=(-5, 0, 0)))             # CONTACTO jab
    key(A, 30, pose(loc=(0, -0.12, 0.92), hip=(0, -15, 0), UpperTorso=(18, -26, 0),
                    RightUpperArm=(-93, 0, -4), RightLowerArm=(-4, 0, 0)))             # hit-stop
    key(A, 44, pose(loc=(0, -0.18, 0.6)))                                              # recupera
    key(A, 58, pose(loc=(0, -0.18, 0.6)))
    key(A, 64, pose(loc=(0, -0.75, 0.55), hip=(0, 0, 0), UpperTorso=(35, 0, -18),
                    Head=(5, 0, 0)))                                                   # esquiva (abaixa)
    key(A, 76, pose(loc=(0, -0.7, 0.55), UpperTorso=(32, 0, 15)))
    key(A, 92, pose(loc=(0, -0.45, 0.5), UpperTorso=(14, 0, 0)))                       # carrega joelhada
    key(A, 104, pose(loc=(0, 0.05, 1.25), UpperTorso=(-8, 0, 0), Head=(0, 0, 0),
                     RightUpperLeg=(-105, 0, 0), RightLowerLeg=(115, 0, 0),
                     RightUpperArm=(-30, 0, 25), LeftUpperArm=(-10, 0, -40),
                     LeftLowerArm=(-30, 0, 0), LeftUpperLeg=(5, 0, 0)))                # CONTACTO joelho
    key(A, 112, pose(loc=(0, 0.06, 1.27), UpperTorso=(-8, 0, 0), Head=(0, 0, 0),
                     RightUpperLeg=(-106, 0, 0), RightLowerLeg=(116, 0, 0),
                     RightUpperArm=(-30, 0, 25), LeftUpperArm=(-10, 0, -40),
                     LeftLowerArm=(-30, 0, 0), LeftUpperLeg=(5, 0, 0)))                # hit-stop
    key(A, 132, pose(loc=(0, -0.15, 1.3)))
    finish = pose(loc=(0, -0.05, 1.3), hip=(0, -20, 0), UpperTorso=(0, -20, 0), Head=(-5, 15, 0),
                  RightUpperArm=(-90, 0, -5), RightLowerArm=(0, 0, 0),
                  LeftUpperArm=(5, 0, -10), LeftLowerArm=(-20, 0, 0))                 # aponta (golpe final)
    key(A, 160, finish)
    key(A, 240, pose(finish, loc=(0, -0.03, 1.3)))

    # ---- KUROZAN (defende e contra-ataca) ----
    block = pose(UpperTorso=(14, 0, 0), RightUpperArm=(-75, 0, -18), RightLowerArm=(-115, 0, 0),
                 LeftUpperArm=(-75, 0, 18), LeftLowerArm=(-115, 0, 0))
    key(K, 0, pose())
    key(K, 22, block)                                                                  # bloqueia antes
    key(K, 27, pose(block, loc=(0, -0.2, -0.3), UpperTorso=(4, 0, 0), Head=(-18, 0, 0)))  # reage +1 f
    key(K, 30, pose(block, loc=(0, -0.2, -0.32), UpperTorso=(4, 0, 0), Head=(-18, 0, 0)))
    key(K, 44, pose(loc=(0, -0.18, -0.35)))
    key(K, 54, pose(loc=(0, -0.28, -0.45), hip=(0, -20, 0), UpperTorso=(10, -30, 0),
                    LeftUpperArm=(-30, 0, -50), LeftLowerArm=(-60, 0, 0)))             # antecipação gancho
    key(K, 66, pose(loc=(0, -0.15, 0.3), hip=(0, 25, 0), UpperTorso=(14, 45, 0),
                    LeftUpperArm=(-85, 0, 30), LeftLowerArm=(-40, 0, 0)))              # gancho passa
    key(K, 76, pose(loc=(0, -0.15, 0.4), hip=(0, 30, 0), UpperTorso=(16, 55, 0),
                    LeftUpperArm=(-80, 0, 45), LeftLowerArm=(-35, 0, 0)))              # follow-through
    key(K, 96, pose(loc=(0, -0.18, 0.1)))
    key(K, 103, pose(loc=(0, -0.18, 0.1)))
    hit = pose(loc=(0, -0.05, -0.25), UpperTorso=(40, 0, 0), Head=(25, 0, 0),
               RightUpperArm=(-20, 0, 25), LeftUpperArm=(-20, 0, -25),
               RightLowerArm=(-40, 0, 0), LeftLowerArm=(-40, 0, 0))
    key(K, 105, hit)                                                                   # reage +1 f
    key(K, 112, pose(hit, loc=(0, -0.04, -0.27)))
    key(K, 124, pose(hit, loc=(0, 0.9, -4.5), UpperTorso=(-25, 0, 0), Head=(-30, 0, 0),
                     RightUpperLeg=(-50, 0, 0), LeftUpperLeg=(-70, 0, 0),
                     RightLowerLeg=(60, 0, 0), LeftLowerLeg=(70, 0, 0)))               # projetado
    key(K, 146, pose(loc=(0, -0.55, -8.0), UpperTorso=(30, 0, 0), Head=(-10, 0, 0),
                     RightUpperArm=(-40, 0, 40), LeftUpperArm=(-40, 0, -40),
                     RightUpperLeg=(-60, 0, 25), LeftUpperLeg=(10, 0, -25),
                     RightLowerLeg=(90, 0, 0), LeftLowerLeg=(30, 0, 0)))               # aterra e desliza
    key(K, 170, pose(loc=(0, -0.45, -8.6), UpperTorso=(22, 0, 0), Head=(-12, 0, 0)))
    key(K, 240, pose(loc=(0, -0.3, -8.6), UpperTorso=(12, 0, 0), Head=(-6, 0, 0)))

    # hit-stops com interpolação constante entre o contacto e o fim da pausa
    for rig, holds in ((A, (26, 104)), (K, (27, 105))):
        for fc in iter_fcurves(rig.animation_data.action):
            for kp in fc.keyframe_points:
                if int(round(kp.co.x)) in holds:
                    kp.interpolation = "LINEAR"


def iter_fcurves(action):
    layers = getattr(action, "layers", None)
    if layers:
        for layer in layers:
            for strip in layer.strips:
                for bag in getattr(strip, "channelbags", []):
                    yield from bag.fcurves
        return
    yield from action.fcurves


# ---------------------------------------------------------------------------
def camera(name, loc, target, lens, coll):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cam = bpy.data.objects.new(name, cd)
    coll.objects.link(cam)
    cam.location = loc
    tr = cam.constraints.new("TRACK_TO")
    tr.target = target
    tr.track_axis, tr.up_axis = "TRACK_NEGATIVE_Z", "UP_Y"
    return cam


def main(out_dir):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = 60
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    sc.frame_start, sc.frame_end = 0, 240
    coll = sc.collection

    origin = bpy.data.objects.new("SCENE_ORIGIN", None)
    coll.objects.link(origin)

    akira = build_akira(coll)
    kurozan = build_kurozan(coll)
    akira.location = (0, 1.9, 0)                      # olha para -Y
    kurozan.location = (0, -1.9, 0)
    kurozan.rotation_euler = (0, 0, R(180))            # olha para +Y
    animate(akira, kurozan)

    # chão
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    floor = bpy.context.object
    floor.name = "Chao"
    floor.data.materials.append(material("Chao", hexc("3b3f4a"), rough=0.8))

    # alvos e câmeras (trocadas por marcadores)
    tgt = bpy.data.objects.new("CAM_ALVO", None)
    coll.objects.link(tgt)
    tgt.location = (0, 0, 3.0)
    tgt.keyframe_insert("location", frame=0)
    tgt.location = (0, -3.0, 2.8)
    tgt.keyframe_insert("location", frame=150)

    c1 = camera("CAM_010_lateral", (11, 1.0, 3.6), tgt, 35, coll)
    c2 = camera("CAM_020_ombro", (2.2, 5.6, 4.6), tgt, 28, coll)
    c3 = camera("CAM_030_baixo", (6.5, -1.5, 0.9), tgt, 20, coll)
    c3.keyframe_insert("location", frame=100)
    c3.location = (8.0, -6.5, 1.4)
    c3.keyframe_insert("location", frame=200)
    # camera shake no impacto da joelhada
    for fc in iter_fcurves(c3.animation_data.action):
        mod = fc.modifiers.new("NOISE")
        mod.scale, mod.strength = 2.0, 0.35
        mod.use_restricted_range = True
        mod.frame_start, mod.frame_end = 104, 124
        mod.blend_in, mod.blend_out = 1, 12

    for f, cam in ((0, c1), (60, c2), (100, c3)):
        m = sc.timeline_markers.new(f"cam_{cam.name}", frame=f)
        m.camera = cam
    sc.camera = c1

    for f, n in ((26, "SFX:soco"), (26, "SHAKE:leve"), (27, "VFX:faiscas_bloqueio"),
                 (66, "VFX:smear_gancho"), (104, "VFX:impact_frame"), (104, "SHAKE:forte"),
                 (104, "SFX:impacto_forte"), (146, "VFX:poeira_aterragem"),
                 (160, "FACE:Akira:olhos_brilham")):
        sc.timeline_markers.new(n, frame=f)

    # luz
    sun = bpy.data.objects.new("Sol", bpy.data.lights.new("Sol", "SUN"))
    coll.objects.link(sun)
    sun.rotation_euler = (R(50), 0, R(35))
    sun.data.energy = 3.5
    rim = bpy.data.objects.new("Contraluz", bpy.data.lights.new("Contraluz", "SUN"))
    coll.objects.link(rim)
    rim.rotation_euler = (R(-60), 0, R(-150))
    rim.data.energy = 2.0
    rim.data.color = (0.6, 0.75, 1.0)
    world = bpy.data.worlds.new("Mundo")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.03, 0.035, 0.06, 1)

    sc.frame_set(0)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "luta_teste.blend")
    bpy.ops.wm.save_as_mainfile(filepath=path)
    print("guardado:", path)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    main(os.path.abspath(argv[0] if argv else "."))

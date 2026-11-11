"""Animações de luta para o R15 do Roblox, feitas no Blender.

Uso: <python com bpy> tools/blender/r15_anims.py
Gera:
  - tools/blender/r15_luta.blend      (esqueleto R15 + boneco de blocos + todas as ações; abra no Blender para ver/editar)
  - src/shared/Anims.luau             (animações amostradas a 30 qps, lidas pela cinemática)

Esqueleto: um osso por Motor6D do R15 (Root, Waist, Neck, ombros, cotovelos, pulsos, quadris, joelhos, tornozelos),
com a cabeça do osso no pivô da junta. Todos os ossos apontam para +Z do Blender com roll 0, então o espaço local
de cada osso coincide com os eixos do Roblox (X = X, Y local = cima, Z local = trás). Assim a rotação local
(matrix_basis) é exatamente o Motor6D.Transform da junta. Os keyframes são Euler em modo ZYX, que é a mesma
ordem de CFrame.Angles(x, y, z); o Blender interpola com curvas Bézier e o script amostra quadro a quadro.
"""
import math, os
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
FPS = 30

# pivôs das juntas no R15 "blocky" de escala 1 (coordenadas do Roblox, pés em y = 0, raiz em y = 3)
PIVOT = {
    "HumanoidRootPart": (0, 3.0, 0), "Root": (0, 3.0, 0), "Waist": (0, 3.0, 0), "Neck": (0, 4.6, 0),
    "RightShoulder": (1.5, 4.4, 0), "RightElbow": (1.5, 3.45, 0), "RightWrist": (1.5, 2.5, 0),
    "LeftShoulder": (-1.5, 4.4, 0), "LeftElbow": (-1.5, 3.45, 0), "LeftWrist": (-1.5, 2.5, 0),
    "RightHip": (0.5, 2.7, 0), "RightKnee": (0.5, 1.5, 0), "RightAnkle": (0.5, 0.3, 0),
    "LeftHip": (-0.5, 2.7, 0), "LeftKnee": (-0.5, 1.5, 0), "LeftAnkle": (-0.5, 0.3, 0),
}
PARENT = {
    "Root": "HumanoidRootPart", "Waist": "Root", "Neck": "Waist",
    "RightShoulder": "Waist", "RightElbow": "RightShoulder", "RightWrist": "RightElbow",
    "LeftShoulder": "Waist", "LeftElbow": "LeftShoulder", "LeftWrist": "LeftElbow",
    "RightHip": "Root", "RightKnee": "RightHip", "RightAnkle": "RightKnee",
    "LeftHip": "Root", "LeftKnee": "LeftHip", "LeftAnkle": "LeftKnee",
}
JOINTS = [j for j in PIVOT if j != "HumanoidRootPart"]
# peças do boneco (só para ver no Blender): junta que move a peça, centro e tamanho (Roblox)
BODY = {
    "LowerTorso": ("Root", (0, 2.8, 0), (2, 0.4, 1)), "UpperTorso": ("Waist", (0, 3.8, 0), (2, 1.6, 1)),
    "Head": ("Neck", (0, 5.2, 0), (1.2, 1.2, 1.2)),
    "RightUpperArm": ("RightShoulder", (1.5, 4.0, 0), (1, 1.2, 1)), "RightLowerArm": ("RightElbow", (1.5, 2.95, 0), (1, 1.05, 1)),
    "RightHand": ("RightWrist", (1.5, 2.3, 0), (1, 0.4, 1)),
    "LeftUpperArm": ("LeftShoulder", (-1.5, 4.0, 0), (1, 1.2, 1)), "LeftLowerArm": ("LeftElbow", (-1.5, 2.95, 0), (1, 1.05, 1)),
    "LeftHand": ("LeftWrist", (-1.5, 2.3, 0), (1, 0.4, 1)),
    "RightUpperLeg": ("RightHip", (0.5, 2.1, 0), (1, 1.2, 1)), "RightLowerLeg": ("RightKnee", (0.5, 0.9, 0), (1, 1.2, 1)),
    "RightFoot": ("RightAnkle", (0.5, 0.15, -0.05), (1, 0.3, 1.1)),
    "LeftUpperLeg": ("LeftHip", (-0.5, 2.1, 0), (1, 1.2, 1)), "LeftLowerLeg": ("LeftKnee", (-0.5, 0.9, 0), (1, 1.2, 1)),
    "LeftFoot": ("LeftAnkle", (-0.5, 0.15, -0.05), (1, 0.3, 1.1)),
}

def bl(v):  # Roblox -> Blender
    return Vector((v[0], -v[2], v[1]))

# ---------------------------------------------------------------- POSES-CHAVE (graus, convenção CFrame.Angles)
# "root" = deslocamento da raiz (studs), "rootRot" = rotação da raiz. Juntas ausentes = 0.
P = {}
P["idle"] = dict(Waist=(4, 0, 0), LeftShoulder=(0, 0, -8), RightShoulder=(0, 0, 8), LeftElbow=(-10, 0, 0), RightElbow=(-10, 0, 0), LeftHip=(0, 0, -3), RightHip=(0, 0, 3))
P["guard"] = dict(root=(0, -0.12, 0), Waist=(12, -18, 0), Neck=(-6, 14, 0), LeftShoulder=(70, 0, -20), LeftElbow=(-95, 0, 0), RightShoulder=(40, 0, 25),
                  RightElbow=(-110, 0, 0), LeftHip=(20, 0, -6), LeftKnee=(-30, 0, 0), RightHip=(-14, 0, 6), RightKnee=(-20, 0, 0), LeftAnkle=(10, 0, 0), RightAnkle=(34, 0, 0))  # tornozelos deixam o pé reto no chão
P["dash"] = dict(root=(0, -0.6, 0), rootRot=(28, 0, 0), Waist=(14, 0, 0), Neck=(-24, 0, 0), LeftShoulder=(-50, 0, -10), RightShoulder=(-50, 0, 10),
                 LeftElbow=(-20, 0, 0), RightElbow=(-20, 0, 0), LeftHip=(55, 0, 0), LeftKnee=(-80, 0, 0), RightHip=(-40, 0, 0), RightKnee=(-30, 0, 0))
P["punch"] = dict(root=(0, -0.3, -0.4), rootRot=(8, -25, 0), Waist=(6, -35, 0), Neck=(0, 30, 0), RightShoulder=(90, 0, 0), RightElbow=(0, 0, 0),
                  LeftShoulder=(30, 0, -20), LeftElbow=(-120, 0, 0), LeftHip=(30, 0, 0), LeftKnee=(-25, 0, 0), RightHip=(-30, 0, 0), RightKnee=(-10, 0, 0))
P["kick"] = dict(root=(0, 0.3, 0), rootRot=(-10, 30, 0), Waist=(-12, 20, 0), RightHip=(100, 0, 10), RightKnee=(-5, 0, 0), RightAnkle=(-30, 0, 0), LeftHip=(-10, 0, 0),
                 LeftKnee=(-25, 0, 0), LeftShoulder=(20, 0, -60), RightShoulder=(-30, 0, 50), LeftElbow=(-40, 0, 0), RightElbow=(-40, 0, 0))
P["hurt"] = dict(root=(0, -0.2, 0.6), rootRot=(-18, 0, 6), Waist=(-16, 0, 0), Neck=(-20, 0, 8), LeftShoulder=(-20, 0, -55), RightShoulder=(-30, 0, 60),
                 LeftElbow=(-30, 0, 0), RightElbow=(-40, 0, 0), LeftHip=(-12, 0, 0), RightHip=(18, 0, 0), RightKnee=(-30, 0, 0))
P["castUp"] = dict(rootRot=(-6, 0, 0), Waist=(-10, 0, 0), Neck=(-18, 0, 0), RightShoulder=(170, 0, 8), RightElbow=(-5, 0, 0), RightWrist=(10, 0, 0),
                   LeftShoulder=(20, 0, -30), LeftElbow=(-60, 0, 0), LeftHip=(6, 0, -8), RightHip=(-6, 0, 8))
P["castPoint"] = dict(root=(0, -0.25, 0), rootRot=(0, -10, 0), Waist=(4, -20, 0), Neck=(0, 18, 0), RightShoulder=(88, 0, 0), RightElbow=(0, 0, 0),
                      RightWrist=(-20, 0, 0), LeftShoulder=(40, 0, -10), LeftElbow=(-100, 0, 0), LeftHip=(22, 0, -8), LeftKnee=(-25, 0, 0), RightHip=(-18, 0, 8))
P["handSign"] = dict(Waist=(4, 0, 0), Neck=(8, 0, 0), LeftShoulder=(80, 0, 32), LeftElbow=(-110, 0, 0), RightShoulder=(80, 0, -32),
                     RightElbow=(-110, 0, 0), LeftWrist=(0, 0, 20), RightWrist=(0, 0, -20), LeftHip=(0, 0, -6), RightHip=(0, 0, 6))
P["slash"] = dict(root=(0, -0.45, -0.3), rootRot=(10, 40, 0), Waist=(8, 50, 0), Neck=(0, -40, 0), RightShoulder=(60, 0, 70), RightElbow=(-10, 0, 0),
                  LeftShoulder=(10, 0, -40), LeftElbow=(-60, 0, 0), LeftHip=(35, 0, 0), LeftKnee=(-45, 0, 0), RightHip=(-30, 0, 0), RightKnee=(-10, 0, 0))
P["kneel"] = dict(root=(0, -1.5, 0), rootRot=(18, 0, 0), Waist=(20, 0, 0), Neck=(22, 0, 0), LeftHip=(90, 0, 0), LeftKnee=(-100, 0, 0),
                  RightHip=(10, 0, 0), RightKnee=(-120, 0, 0), RightShoulder=(20, 0, 10), LeftShoulder=(50, 0, -10), LeftElbow=(-40, 0, 0))
P["float"] = dict(root=(0, 0.6, 0), rootRot=(-4, 0, 0), Waist=(-4, 0, 0), LeftShoulder=(10, 0, -40), RightShoulder=(10, 0, 40),
                  LeftElbow=(-20, 0, 0), RightElbow=(-20, 0, 0), LeftHip=(10, 0, -6), LeftKnee=(-30, 0, 0), RightHip=(4, 0, 6), RightKnee=(-15, 0, 0), LeftAnkle=(-30, 0, 0), RightAnkle=(-25, 0, 0))

def mirror(p):
    """Espelha esquerda/direita (troca os lados e inverte Y/Z das rotações e X do deslocamento)."""
    out = {}
    for k, v in p.items():
        if k == "root":
            out[k] = (-v[0], v[1], v[2])
        elif k == "rootRot" or k in ("Waist", "Neck"):
            out[k] = (v[0], -v[1], -v[2])
        else:
            kk = k.replace("Left", "#").replace("Right", "Left").replace("#", "Right")
            out[kk] = (v[0], -v[1], -v[2])
    return out

def mix(base, **over):
    """Pose = base com algumas juntas trocadas (over) ou somadas (chave terminando em '_add')."""
    out = dict(base)
    for k, v in over.items():
        if k.endswith("_add"):
            k = k[:-4]
            b = out.get(k, (0, 0, 0))
            out[k] = (b[0] + v[0], b[1] + v[1], b[2] + v[2])
        else:
            out[k] = v
    return out

G = P["guard"]
# ---------------------------------------------------------------- CLIPES (quadro, pose); "hit" = quadro do golpe
CLIPS = {
    "idle": dict(loop=True, keys=[(0, P["idle"]), (36, mix(P["idle"], root=(0, 0.05, 0), Waist_add=(2, 0, 0), LeftShoulder_add=(0, 0, -3), RightShoulder_add=(0, 0, 3), Neck_add=(-2, 0, 0))), (72, P["idle"])]),
    "guard": dict(loop=True, keys=[(0, G), (20, mix(G, root=(0, -0.2, 0), Waist_add=(3, 4, 0), LeftKnee_add=(-8, 0, 0), RightKnee_add=(-8, 0, 0), LeftHip_add=(4, 0, 0), RightHip_add=(4, 0, 0), LeftAnkle_add=(4, 0, 0), RightAnkle_add=(4, 0, 0))), (40, G)]),
    "dash": dict(loop=True, keys=[(0, P["dash"]),
                                  (8, mix(P["dash"], LeftHip=(-40, 0, 0), LeftKnee=(-30, 0, 0), RightHip=(55, 0, 0), RightKnee=(-80, 0, 0), root=(0, -0.45, 0))),
                                  (16, P["dash"])]),
    "punch": dict(hit=7, keys=[(0, G),
                               (4, mix(G, root=(0, -0.4, 0.25), rootRot=(4, 20, 0), Waist=(10, 25, 0), RightShoulder=(35, 0, 35), RightElbow=(-125, 0, 0))),
                               (7, mix(P["punch"], root=(0, -0.32, -0.6), Waist=(6, -45, 0), RightShoulder=(96, 0, -4))),
                               (10, P["punch"]), (18, mix(P["punch"], RightShoulder=(84, 0, 4), RightElbow=(-12, 0, 0)))]),
    "kick": dict(hit=9, keys=[(0, G),
                              (5, mix(G, root=(0, -0.1, 0), RightHip=(85, 0, 0), RightKnee=(-115, 0, 0), RightAnkle=(20, 0, 0), Waist=(-6, 10, 0))),
                              (9, mix(P["kick"], RightHip=(112, 0, 12), rootRot=(-14, 36, 0))),
                              (13, P["kick"]), (22, mix(P["kick"], RightHip=(95, 0, 8), RightKnee=(-15, 0, 0)))]),
    "hurt": dict(hit=3, keys=[(0, G),
                              (3, mix(P["hurt"], rootRot=(-28, 0, 9), Waist=(-26, 0, 0), Neck=(-30, 0, 12), root=(0, -0.2, 0.9))),
                              (8, P["hurt"]), (18, mix(P["hurt"], rootRot=(-10, 0, 3), Waist=(-8, 0, 0), Neck=(-6, 0, 4)))]),
    "slash": dict(hit=10, keys=[(0, G),
                                (6, mix(G, rootRot=(4, -35, 0), Waist=(-6, -45, 0), Neck=(0, 30, 0), RightShoulder=(160, 0, -25), RightElbow=(-30, 0, 0), root=(0, -0.3, 0.2))),
                                (10, mix(P["slash"], Waist=(10, 62, 0), RightShoulder=(55, 0, 85))),
                                (14, P["slash"]), (22, mix(P["slash"], Waist=(8, 44, 0)))]),
    "castUp": dict(hit=16, keys=[(0, G),
                                 (8, mix(G, root=(0, -0.6, 0), RightShoulder=(30, 0, 20), RightElbow=(-120, 0, 0), Neck=(10, 0, 0))),
                                 (16, mix(P["castUp"], RightShoulder=(178, 0, 4), root=(0, 0.15, 0))),
                                 (24, P["castUp"]), (40, mix(P["castUp"], RightShoulder=(172, 0, 10), Neck=(-22, 0, 0))), (56, P["castUp"])], holdLoop=(24, 56)),
    "castPoint": dict(hit=5, keys=[(0, mix(P["castUp"], RightShoulder=(140, 0, 10))),
                                   (5, mix(P["castPoint"], root=(0, -0.3, -0.5), RightShoulder=(92, 0, -4))),
                                   (9, P["castPoint"]), (20, mix(P["castPoint"], RightShoulder=(86, 0, 2), Waist=(4, -16, 0)))]),
    "handSign": dict(hit=10, keys=[(0, P["idle"]),
                                   (10, mix(P["handSign"], Neck=(14, 0, 0), LeftShoulder=(86, 0, 36), RightShoulder=(86, 0, -36))),
                                   (16, P["handSign"]), (40, mix(P["handSign"], Waist=(6, 0, 0), Neck=(4, 0, 0))), (64, P["handSign"])], holdLoop=(16, 64)),
    "float": dict(loop=True, keys=[(0, P["float"]),
                                   (30, mix(P["float"], root=(0, 0.95, 0), LeftKnee=(-38, 0, 0), RightKnee=(-22, 0, 0), LeftShoulder_add=(0, 0, -6), RightShoulder_add=(0, 0, 6))),
                                   (60, P["float"])]),
    "kneel": dict(hit=8, keys=[(0, G), (8, mix(P["kneel"], root=(0, -1.65, 0))), (14, P["kneel"])]),
}
CLIPS["punchL"] = dict(hit=7, keys=[(f, mirror(p)) for f, p in CLIPS["punch"]["keys"]])

# ---------------------------------------------------------------- cena
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS
arm_data = bpy.data.armatures.new("R15")
arm = bpy.data.objects.new("R15", arm_data)
scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for name in PIVOT:
    b = arm_data.edit_bones.new(name)
    b.head = bl(PIVOT[name])
    b.tail = b.head + Vector((0, 0, 0.4))
    b.roll = 0
for name, par in PARENT.items():
    arm_data.edit_bones[name].parent = arm_data.edit_bones[par]
    arm_data.edit_bones[name].use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")
# confere: eixos locais de cada osso = eixos do Roblox (X, cima, trás) expressos no Blender
expect = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
for b in arm_data.bones:
    m = b.matrix_local.to_3x3()
    assert all(abs(m[i][j] - expect[i][j]) < 1e-5 for i in range(3) for j in range(3)), (b.name, m)

# boneco de blocos (cada peça presa ao osso da sua junta)
for pname, (joint, center, size) in BODY.items():
    bpy.ops.mesh.primitive_cube_add(size=1)
    ob = bpy.context.active_object
    ob.name = pname
    ob.scale = (size[0], size[2], size[1])
    ob.location = bl(center)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.parent = arm
    ob.parent_type = "BONE"
    ob.parent_bone = joint
    # parent_bone usa a ponta (tail) do osso como origem; compensa para a peça ficar no lugar
    bone = arm_data.bones[joint]
    ob.matrix_parent_inverse = (arm.matrix_world @ Matrix.Translation(bone.tail_local) @ bone.matrix_local.to_3x3().to_4x4()).inverted()
    ob.location = bl(center)

for pb in arm.pose.bones:
    pb.rotation_mode = "ZYX"  # matriz Rx·Ry·Rz = CFrame.Angles(x, y, z)

def set_pose(pose, frame):
    for j in JOINTS:
        pb = arm.pose.bones[j]
        if j == "Root":
            rr = pose.get("rootRot", (0, 0, 0))
            pb.rotation_euler = [math.radians(a) for a in rr]
            pb.location = pose.get("root", (0, 0, 0))  # espaço local do osso = eixos do Roblox
            pb.keyframe_insert("location", frame=frame)
        else:
            pb.rotation_euler = [math.radians(a) for a in pose.get(j, (0, 0, 0))]
        pb.keyframe_insert("rotation_euler", frame=frame)

def fcurves_of(action):
    # Blender 4.4+ guarda as curvas em camadas/faixas (ações "em camadas"); versões antigas, em action.fcurves
    if hasattr(action, "layers") and len(action.layers) > 0:
        out = []
        for layer in action.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out.extend(cb.fcurves)
        return out
    return list(action.fcurves)

arm.animation_data_create()
out = {}
for name, clip in CLIPS.items():
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    for f, pose in clip["keys"]:
        set_pose(pose, f)
    for fc in fcurves_of(act):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
        fc.update()
    last = clip["keys"][-1][0]
    frames = []
    for f in range(0, last + 1):
        scene.frame_set(f)
        row = {}
        for j in JOINTS:
            m = arm.pose.bones[j].matrix_basis
            q = m.to_quaternion()
            row[j] = (q.x, q.y, q.z, q.w)
            if j == "Root":
                row["__pos"] = tuple(m.translation)
        frames.append(row)
    out[name] = dict(frames=frames, loop=clip.get("loop", False), hit=clip.get("hit", 0), holdLoop=clip.get("holdLoop"))
    print("clipe", name, len(frames), "quadros")

arm.animation_data.action = bpy.data.actions["guard"]
scene.frame_start, scene.frame_end = 0, 40
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "r15_luta.blend"))

# ---------------------------------------------------------------- Luau
def n(x):
    s = "%.4f" % x
    return "0" if s in ("0.0000", "-0.0000") else s.rstrip("0").rstrip(".")
L = ["-- GERADO por tools/blender/r15_anims.py (Blender). Não edite à mão: mude o script e rode de novo.",
     "-- Animações do R15 a %d qps. Para cada junta (nome do Motor6D): quatérnios x,y,z,w em sequência (um por quadro);" % FPS,
     "-- RootPos: deslocamento da junta Root (x,y,z por quadro). hit = quadro do golpe; holdLoop = trecho que repete no fim.",
     "local Anims = {}", "Anims.FPS = %d" % FPS, "Anims.Joints = { %s }" % ", ".join('"%s"' % j for j in JOINTS), "Anims.Clips = {"]
for name, c in out.items():
    fr = c["frames"]
    hl = c["holdLoop"]
    L.append('\t%s = { frames = %d, loop = %s, hit = %d, holdLoop = %s,' % (name, len(fr), "true" if c["loop"] else "false", c["hit"],
             ("{ %d, %d }" % tuple(hl)) if hl else "nil"))
    L.append("\t\tRootPos = { %s }," % ", ".join(n(v) for row in fr for v in row["__pos"]))
    L.append("\t\tJ = {")
    for j in JOINTS:
        L.append("\t\t\t%s = { %s }," % (j, ", ".join(n(v) for row in fr for v in row[j])))
    L.append("\t\t},")
    L.append("\t},")
L.append("}")
L.append("return Anims")
open(os.path.join(ROOT, "src", "shared", "Anims.luau"), "w", encoding="utf-8").write("\n".join(L) + "\n")
print("ok:", len(out), "clipes")

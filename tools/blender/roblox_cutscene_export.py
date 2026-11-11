"""
Roblox Cutscene Exporter — Blender 4.2+ / 5.x
================================================

Exporta uma cena de luta (vários rigs R15 + câmera + eventos) para o Roblox:

  1. Para cada CLIP e cada RIG -> um .fbx individual (bake das deform bones,
     começando no tempo 0, sem simplificação de curvas = golpes secos).
  2. Para cada CLIP -> um ModuleScript Luau (.lua) com:
       - CFrame da câmera ativa em cada frame (suporta troca de câmera
         por marcadores "Bind Camera to Markers") + FOV vertical + flag de corte
       - posição de cada rig relativa à origem da cena
       - marcadores de evento (VFX/FACE/SFX/SHAKE...) com o tempo em segundos

Uso:
  - Abra o .blend, ajuste o bloco CONFIG abaixo e rode no Text Editor (Alt+P), ou
  - blender cena.blend --background --python roblox_cutscene_export.py

O script NÃO altera o seu .blend de forma permanente: as actions de bake são
apagadas e as actions/constraints originais são restauradas no final.
"""

import math
import os

import bpy
from mathutils import Matrix

# ---------------------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------------------
CONFIG = {
    # Pasta de saída ("//" = relativo ao .blend)
    "output_dir": "//export_roblox",
    # Armatures (rigs de deformação com nomes de bones R15) a exportar
    "rigs": ["GOJO_RIG", "SUKUNA_RIG"],
    # Clips: (nome, frame inicial, frame final) — inclusive
    "clips": [
        ("01_taijutsu", 1, 240),
        ("02_hollow_purple", 241, 420),
        ("03_dismantle_cleave", 421, 600),
        ("04_dominios", 601, 900),
    ],
    # Quantos studs equivalem a 1 unidade do Blender (meça o seu rig!)
    # R15 padrão tem ~5.2 studs de altura -> studs_per_unit = 5.2 / altura_no_blender
    "studs_per_unit": 1.0,
    # Objeto (Empty) que representa a origem da cena; None = origem do mundo
    "scene_origin": "SCENE_ORIGIN",
    # Distância (em unidades Blender) a partir da qual um salto de câmera conta como corte
    "cut_distance": 2.0,
    # Prefixos de marcadores exportados como eventos (o resto é ignorado)
    "event_prefixes": ("VFX:", "FACE:", "SFX:", "SHAKE:", "FX:", "EVT:"),
    # Incluir as malhas no FBX (o Animation Editor só precisa da armature)
    "include_meshes": False,
    # Exportar só deform bones (descarta bones de controle/IK)
    "deform_only": True,
    # Convenção: no Blender os personagens olham para -Y (vista Front, Numpad 1).
    # Se no teste de calibração (guia, secção 4.5) a câmera aparecer do lado
    # oposto no Roblox, mude para True.
    "flip_front": False,
}

# Blender: Z para cima, personagem olha para -Y, direita do personagem = -X
# Roblox:  Y para cima, personagem olha para -Z, direita do personagem = +X
#   (x, y, z)_blender -> (-x, z, y)_roblox   (rotação própria, det = +1)
AXIS = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
if CONFIG["flip_front"]:
    AXIS = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
def abspath(path):
    return bpy.path.abspath(path)


def iter_fcurves(action):
    """Compatível com actions legadas (4.x) e slotted/layered (4.4+/5.x)."""
    layers = getattr(action, "layers", None)
    if layers:
        for layer in layers:
            for strip in layer.strips:
                for bag in getattr(strip, "channelbags", []):
                    yield from bag.fcurves
        return
    fcurves = getattr(action, "fcurves", None)
    if fcurves is not None:
        yield from fcurves


def shift_action(action, offset):
    for fc in iter_fcurves(action):
        for kp in fc.keyframe_points:
            kp.co.x += offset
            kp.handle_left.x += offset
            kp.handle_right.x += offset
        fc.update()


def set_constant_interpolation(action):
    """Após o bake cada frame já tem chave; CONSTANT evita interpolação
    sub-frame e preserva o efeito 'animado em 2s/3s'."""
    for fc in iter_fcurves(action):
        for kp in fc.keyframe_points:
            kp.interpolation = "CONSTANT"


def origin_matrix():
    name = CONFIG["scene_origin"]
    if name and name in bpy.data.objects:
        return bpy.data.objects[name].matrix_world.copy()
    return Matrix.Identity(4)


def to_roblox(mat_world, origin_inv, is_camera):
    """Converte matriz do Blender (relativa à origem da cena) em
    (x, y, z, r00..r22) no espaço do Roblox (row-major, como CFrame.new).

    Câmeras: o eixo local é igual nos dois programas (olha para -Z, +Y em
    cima), então só o espaço do mundo muda: R' = A·R.
    Rigs/objetos: o eixo local também muda (frente -Y -> -Z): R' = A·R·Aᵀ.
    """
    local = origin_inv @ mat_world
    loc, rot, _scale = local.decompose()
    p = AXIS @ loc * CONFIG["studs_per_unit"]
    r = AXIS @ rot.to_matrix()
    if not is_camera:
        r = r @ AXIS.transposed()
    return [p.x, p.y, p.z,
            r[0][0], r[0][1], r[0][2],
            r[1][0], r[1][1], r[1][2],
            r[2][0], r[2][1], r[2][2]]


def vertical_fov_deg(cam_obj, scene):
    cam = cam_obj.data
    rx = scene.render.resolution_x * scene.render.pixel_aspect_x
    ry = scene.render.resolution_y * scene.render.pixel_aspect_y
    fit = cam.sensor_fit
    if fit == "AUTO":
        fit = "HORIZONTAL" if rx >= ry else "VERTICAL"
    if fit == "VERTICAL":
        fov_y = 2 * math.atan(cam.sensor_height / (2 * cam.lens))
    else:
        fov_x = 2 * math.atan(cam.sensor_width / (2 * cam.lens))
        fov_y = 2 * math.atan(math.tan(fov_x / 2) * ry / rx)
    return math.degrees(fov_y)


def fmt(n):
    s = f"{n:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


# ---------------------------------------------------------------------------
# Exportação de rigs
# ---------------------------------------------------------------------------
def bake_and_export_rig(scene, rig, clip_name, start, end, out_dir):
    view_layer = bpy.context.view_layer

    # Guarda estado
    ad = rig.animation_data_create()
    orig_action = ad.action
    orig_slot = getattr(ad, "action_slot", None)
    muted = []

    # Seleciona só o rig
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in view_layer.objects:
        o.select_set(False)
    rig.select_set(True)
    view_layer.objects.active = rig

    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        is_deform = pb.bone.use_deform or not CONFIG["deform_only"]
        # 4.x: seleção vive em Bone.select; 5.x: em PoseBone.select
        target = pb if hasattr(pb, "select") else pb.bone
        target.select = is_deform

    # Bake visual (resolve IK, constraints e control rigs)
    bpy.ops.nla.bake(
        frame_start=start,
        frame_end=end,
        step=1,
        only_selected=True,
        visual_keying=True,
        clear_constraints=False,
        clear_parents=False,
        use_current_action=False,
        bake_types={"POSE"},
    )
    bpy.ops.object.mode_set(mode="OBJECT")
    baked = rig.animation_data.action
    baked.name = f"{rig.name}__{clip_name}"

    # Sem constraints no export: o bake já contém o resultado visual
    for pb in rig.pose.bones:
        for c in pb.constraints:
            if not c.mute:
                c.mute = True
                muted.append(c)

    shift_action(baked, -start)
    set_constant_interpolation(baked)

    # Range do FBX = 0..duração
    old_range = (scene.frame_start, scene.frame_end, scene.frame_current)
    scene.frame_start, scene.frame_end = 0, end - start
    scene.frame_set(0)

    if CONFIG["include_meshes"]:
        for child in rig.children:
            if child.type == "MESH":
                child.select_set(True)

    path = os.path.join(out_dir, f"{clip_name}__{rig.name}.fbx")
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"ARMATURE", "MESH"} if CONFIG["include_meshes"] else {"ARMATURE"},
        apply_scale_options="FBX_SCALE_NONE",
        axis_forward="-Z",
        axis_up="Y",
        add_leaf_bones=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        use_armature_deform_only=CONFIG["deform_only"],
        bake_anim=True,
        bake_anim_use_all_bones=True,
        bake_anim_use_nla_strips=False,
        bake_anim_use_all_actions=False,
        bake_anim_force_startend_keying=True,
        bake_anim_step=1.0,
        bake_anim_simplify_factor=0.0,  # 0 = não suaviza os snaps dos golpes
    )

    # Restaura estado
    scene.frame_start, scene.frame_end = old_range[0], old_range[1]
    scene.frame_set(old_range[2])
    for c in muted:
        c.mute = False
    rig.animation_data.action = orig_action
    if orig_slot is not None and orig_action is not None:
        rig.animation_data.action_slot = orig_slot
    bpy.data.actions.remove(baked)
    return path


# ---------------------------------------------------------------------------
# Exportação de câmera + eventos
# ---------------------------------------------------------------------------
def export_clip_data(scene, clip_name, start, end, out_dir):
    fps = scene.render.fps / scene.render.fps_base
    origin_inv = origin_matrix().inverted()
    old_frame = scene.frame_current

    frames = []
    prev_cam, prev_loc = None, None
    for f in range(start, end + 1):
        scene.frame_set(f)
        cam = scene.camera
        if cam is None:
            raise RuntimeError("A cena não tem câmera ativa.")
        loc = cam.matrix_world.translation.copy()
        cut = prev_cam is not None and (
            cam != prev_cam or (loc - prev_loc).length > CONFIG["cut_distance"]
        )
        row = to_roblox(cam.matrix_world, origin_inv, True)
        row.append(vertical_fov_deg(cam, scene))
        row.append(1 if cut else 0)
        frames.append(row)
        prev_cam, prev_loc = cam, loc

    scene.frame_set(start)
    rigs = {}
    for name in CONFIG["rigs"]:
        obj = bpy.data.objects.get(name)
        if obj:
            rigs[name] = to_roblox(obj.matrix_world, origin_inv, False)

    events = sorted(
        ((m.frame - start) / fps, m.name)
        for m in scene.timeline_markers
        if start <= m.frame <= end and m.name.startswith(CONFIG["event_prefixes"])
    )
    scene.frame_set(old_frame)

    lines = [
        f"-- Gerado por roblox_cutscene_export.py — clip '{clip_name}'",
        "-- camera[i] = {x,y,z, r00,r01,r02, r10,r11,r12, r20,r21,r22, fovY, cut}",
        "return {",
        f'\tname = "{clip_name}",',
        f"\tfps = {fmt(fps)},",
        f"\tlength = {fmt((end - start) / fps)},",
        "\trigs = {",
    ]
    for name, row in rigs.items():
        lines.append(f'\t\t["{name}"] = {{{", ".join(fmt(v) for v in row)}}},')
    lines.append("\t},")
    lines.append("\tevents = {")
    for t, name in events:
        safe = name.replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'\t\t{{t = {fmt(t)}, name = "{safe}"}},')
    lines.append("\t},")
    lines.append("\tcamera = {")
    for row in frames:
        lines.append("\t\t{" + ",".join(fmt(v) for v in row) + "},")
    lines.append("\t},")
    lines.append("}")

    path = os.path.join(out_dir, f"{clip_name}__CutsceneData.lua")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return path


# ---------------------------------------------------------------------------
def main():
    scene = bpy.context.scene
    out_dir = abspath(CONFIG["output_dir"])
    os.makedirs(out_dir, exist_ok=True)

    written = []
    for clip_name, start, end in CONFIG["clips"]:
        for rig_name in CONFIG["rigs"]:
            rig = bpy.data.objects.get(rig_name)
            if rig is None or rig.type != "ARMATURE":
                print(f"[aviso] rig '{rig_name}' não encontrado — ignorado")
                continue
            written.append(bake_and_export_rig(scene, rig, clip_name, start, end, out_dir))
        written.append(export_clip_data(scene, clip_name, start, end, out_dir))

    print("\n=== Roblox Cutscene Export ===")
    for p in written:
        print("  ", p)


if __name__ == "__main__":
    main()

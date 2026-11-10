"""
Monta no BLENDER o modelo 3D de cada pet: corpo CONTÍNUO (uma malha só, sem juntas de bolinha), esqueleto com
os mesmos nomes de partes do jogo, skinning suave, olhos pintados (textura) e cores assadas numa textura.
Exporta FBX para o Importador 3D do Roblox Studio e renderiza uma prévia.

Entrada: JSONs gerados por `python3 tools/run_tests.py luau --rigexport` (uma linha "RIG <id> {json}" por pet).
Uso (Blender como módulo Python, `pip install bpy`):
    python build_pets.py --rigs <pasta dos json> --out <pasta de saída> [--ids kit_1,leafcat_1] [--render] [--tex 1024]

Coordenadas: o JSON está no padrão do Roblox (Y para cima, frente = -Z, studs). Aqui vira o padrão do Blender
(Z para cima) com (x, y, z) -> (x, -z, y); o FBX volta para Y para cima, então o Roblox recebe as mesmas medidas.
"""
import argparse
import json
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

# --- utilidades ------------------------------------------------------------------------------------------


def rb(v):
    """Roblox (x, y, z) -> Blender."""
    return Vector((v[0], -v[2], v[1]))


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_mesh(name, verts, faces, colors=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    if colors is not None:
        attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for i, c in enumerate(colors):
            attr.data[i].color = (c[0], c[1], c[2], 1.0)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def select_only(*obs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]


def apply_modifier(ob, mod):
    select_only(ob)
    with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob]):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# --- regras de quais partes viram o corpo contínuo ---------------------------------------------------------

BODY_MATERIALS = {"Fabric", "SmoothPlastic", "Grass", "Wood", "Slate", "Metal"}


def part_bone(parts_by_name, p):
    """Osso que move a parte: a própria (se tem junta) ou o ancestral mais próximo com junta."""
    while p is not None:
        if p.get("joint"):
            return p["n"]
        p = parts_by_name.get(p.get("parent"))
    return None


def is_open(ob):
    """Malha aberta (tem borda solta): o remesh em voxels precisa de volume fechado."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    n = sum(1 for e in bm.edges if len(e.link_faces) < 2)
    bm.free()
    return n > 0


def local_thickness(ob):
    """Espessura típica da peça: de cada ponto, a distância até a outra face, para dentro (mediana)."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bvh = BVHTree.FromBMesh(bm)
    bm.free()
    n = len(me.vertices)
    step = max(1, n // 160)
    ds = []
    for i in range(0, n, step):
        v = me.vertices[i]
        if v.normal.length < 0.5:
            continue
        o = v.co - v.normal * 1e-4
        loc, _nr, _fi, d = bvh.ray_cast(o, -v.normal)
        if loc is not None:
            ds.append(d)
    if not ds:
        return 0.0
    ds.sort()
    return ds[len(ds) // 2]


def thickness(verts):
    lo = [min(v[i] for v in verts) for i in range(3)]
    hi = [max(v[i] for v in verts) for i in range(3)]
    return min(hi[i] - lo[i] for i in range(3))


# --- olho pintado (textura) --------------------------------------------------------------------------------


def eye_image(name, iris, glow, slit, sclera, size=256):
    """Olho de anime: globo escuro, íris com degradê, pupila grande, dois brilhos brancos e contorno."""
    img = bpy.data.images.new(name, size, size, alpha=True)
    px = [0.0] * (size * size * 4)
    ir = [srgb_to_linear(x / 255) for x in iris]
    scl = [srgb_to_linear(x / 255) for x in sclera] if sclera else [ir[0] * 0.18, ir[1] * 0.18, ir[2] * 0.18]
    for y in range(size):
        for x in range(size):
            u, v = (x + 0.5) / size * 2 - 1, (y + 0.5) / size * 2 - 1
            r = math.hypot(u, v)
            col = [0.02, 0.015, 0.03]  # contorno
            if r < 0.9:
                col = scl
            if r < 0.78:
                # íris: mais clara embaixo, escura em cima (luz de anime)
                k = 0.55 + 0.45 * (1 - (v + 1) / 2)
                col = [min(1, ir[i] * (0.6 + 0.9 * k) + (0.25 if glow else 0.0)) for i in range(3)]
                ring = (r - 0.62) / 0.16
                if ring > 0:
                    col = [col[i] * (1 - 0.5 * ring) for i in range(3)]
            pup = (abs(u) / 0.22) ** 2 + (abs(v) / 0.56) ** 2 < 1 if slit else r < 0.42
            if pup:
                col = [ir[i] * 0.08 if glow else 0.01 for i in range(3)]
            # pálpebra de cima mais grossa (traço de anime)
            if 0.78 <= r < 1.0 and v > 0.25:
                col = [0.02, 0.015, 0.03]
            # brilhos
            if math.hypot(u + 0.28, v - 0.32) < 0.24 or math.hypot(u - 0.3, v + 0.34) < 0.11:
                col = [1.0, 1.0, 1.0]
            i4 = (y * size + x) * 4
            px[i4:i4 + 4] = [col[0], col[1], col[2], 1.0]
    img.pixels = px
    return img


def make_eye(name, e, body_bvh, size_ref):
    """Calota achatada sobre a superfície da cabeça, virada para a normal do olho, com UV de frente."""
    c, n = rb(e["c"]), rb(e["n"]).normalized()
    r = e["r"] * 1.25
    tall = e.get("tall", 1.0) * 1.12
    # empurra o olho até a superfície do corpo contínuo (o corpo liso é um pouco mais cheio que o original)
    hit = None
    if body_bvh is not None:
        loc, _nrm, _i, _d = body_bvh.ray_cast(c + n * r * 4, -n)
        if loc is not None:
            hit = loc
    base = hit if hit is not None else c
    right = n.cross(Vector((0, 0, 1)))
    if right.length < 1e-4:
        right = Vector((1, 0, 0))
    right.normalize()
    up = right.cross(n).normalized()
    bm = bmesh.new()
    seg, rings = 24, 8
    verts = []
    uvs = []
    for k in range(rings + 1):
        a = (k / rings) * (math.pi / 2)  # da borda (0) até o topo (pi/2)
        rad = math.cos(a)
        h = math.sin(a) * r * 0.32
        row = []
        for s in range(seg):
            t = 2 * math.pi * s / seg
            lx, ly = math.cos(t) * rad, math.sin(t) * rad * tall
            p = base + right * (lx * r) + up * (ly * r) + n * (h - r * 0.06)
            row.append(bm.verts.new(p))
            uvs.append((lx, ly / tall))
        verts.append(row)
    bm.verts.ensure_lookup_table()
    faces = []
    for k in range(rings):
        for s in range(seg):
            a, b = verts[k][s], verts[k][(s + 1) % seg]
            c2, d = verts[k + 1][(s + 1) % seg], verts[k + 1][s]
            if k + 1 == rings:
                continue
            faces.append(bm.faces.new((a, b, c2, d)))
    top = [verts[rings - 1][s] for s in range(seg)]
    cap = bm.faces.new(top)
    uv_layer = bm.loops.layers.uv.new("UVMap")
    idx = {v: i for i, v in enumerate([x for row in verts for x in row])}
    for f in bm.faces:
        for loop in f.loops:
            lx, ly = uvs[idx[loop.vert]]
            loop[uv_layer].uv = (lx * 0.5 + 0.5, ly * 0.5 + 0.5)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for poly in me.polygons:
        poly.use_smooth = True
    _ = cap, faces
    return ob


FURRY = {"fox", "canine", "wolf", "pup", "feline", "lion", "lynx", "lagomorph", "rodent", "squirrel", "mustelid", "ursine", "caprine",
         "cervid", "heavy", "leafpanda", "bushgoat", "griffin", "tiger"}


def nearest_color(srcs, at):
    best = None
    for ob in srcs:
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bvh = BVHTree.FromBMesh(bm)
        bm.free()
        loc, _n, fi, d = bvh.find_nearest(at)
        if loc is not None and (best is None or d < best[0]):
            poly = ob.data.polygons[fi]
            cs = [ob.data.color_attributes["Col"].data[k].color for k in poly.vertices]
            best = (d, tuple(sum(c[j] for c in cs) / len(cs) for j in range(3)), ob)
    return (best[1], best[2]) if best else ((0.8, 0.8, 0.8), None)


def spike(name, base, direction, radius, length, color, bone):
    """Tufo de pelo: cone arredondado (o remesh e a suavização deixam macio)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=10, radius1=radius, radius2=radius * 0.12, depth=length)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    rot = direction.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    me.transform(Matrix.Translation(base + direction.normalized() * length * 0.45) @ rot)
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i in range(len(me.vertices)):
        attr.data[i].color = (color[0], color[1], color[2], 1.0)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["part"] = name
    ob["bone"] = bone
    return ob


def bead(name, at, radius, color, bone):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=radius)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.transform(Matrix.Translation(at))
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i in range(len(me.vertices)):
        attr.data[i].color = (color[0], color[1], color[2], 1.0)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["part"] = name
    ob["bone"] = bone
    return ob


def add_details(rig, by_name, srcs, size):
    new = []
    head_bone = None
    # tufos nas bochechas (abaixo e atrás de cada olho, apontando para fora e para trás)
    for k, e in enumerate(rig.get("eyes", [])):
        c, n, r = rb(e["c"]), rb(e["n"]).normalized(), e["r"]
        side = 1 if c.x >= 0 else -1
        head_bone = part_bone(by_name, by_name.get(e.get("part"))) or "Head"
        base = c + Vector((0, 0, -r * 1.7)) - n * r * 1.1 + Vector((side * r * 0.5, 0, 0))
        col, _ = nearest_color(srcs, base)
        for j, dz in enumerate((-0.35, 0.05, 0.42)):
            d = Vector((side * 0.85, -0.55, dz))
            new.append(spike("Tuft%d_%d" % (k, j), base + Vector((0, -j * r * 0.25, dz * r * 0.6)), d, r * 0.42, r * 1.25, col, head_bone))
    # pelo fofo no peito (frente do tronco, embaixo)
    torso = by_name.get("Torso")
    if torso:
        vs = [rb(torso["v"][i:i + 3]) for i in range(0, len(torso["v"]), 3)]
        zc = sum(v.z for v in vs) / len(vs)
        front = max(vs, key=lambda v: v.y - abs(v.z - (zc - 0.1 * size)) * 0.6 - abs(v.x))
        col, _ = nearest_color(srcs, front)
        rr = size * 0.045
        for j, (dx, dz) in enumerate(((-0.45, -0.2), (0.45, -0.2), (0.0, -0.5), (-0.2, -0.75), (0.2, -0.75))):
            base = front + Vector((dx * rr * 2.2, -rr * 0.8, dz * rr * 2.4))
            new.append(spike("Chest%d" % j, base, Vector((dx * 0.6, 1.0, -0.55 + dz * 0.3)), rr, rr * 2.4, col, "Torso"))
    # dedinhos nas patas: três bolinhas na frente de baixo de cada pé (somem na suavização e viram dedos)
    for p in rig["parts"]:
        if p["n"].startswith("Foot") or p["n"].startswith("Hand"):
            vs = [rb(p["v"][i:i + 3]) for i in range(0, len(p["v"]), 3)]
            xs = [v.x for v in vs]
            width = max(xs) - min(xs)
            zmin = min(v.z for v in vs)
            ymax = max(v.y for v in vs)
            xc = (max(xs) + min(xs)) / 2
            rad = width * 0.2
            col, _ = nearest_color(srcs, Vector((xc, ymax, zmin)))
            for j in (-1, 0, 1):
                at = Vector((xc + j * width * 0.28, ymax - rad * 0.7, zmin + rad * 0.85))
                new.append(bead("Toe_%s_%d" % (p["n"], j + 1), at, rad, col, part_bone(by_name, p) or "Torso"))
    srcs.extend(new)


# --- construção de um pet# --- construção de um pet -----------------------------------------------------------------------------------


def build(rig, out_dir, tex_size=1024, render=False, voxel=None):
    clear_scene()
    scene = bpy.context.scene
    parts = rig["parts"]
    by_name = {p["n"]: p for p in parts}

    # tamanho de referência (altura do pet)
    allv = [rb(p["v"][i:i + 3]) for p in parts for i in range(0, len(p["v"]), 3)]
    zmin, zmax = min(v.z for v in allv), max(v.z for v in allv)
    size = max(zmax - zmin, 0.5)
    vox = voxel or max(0.01, size * 0.0075)

    # 1) peças de origem (cada parte do corpo), com cor por vértice
    body_srcs, extras = [], []
    for p in parts:
        verts = [rb(p["v"][i:i + 3]) for i in range(0, len(p["v"]), 3)]
        cols = [tuple(srgb_to_linear(x / 255) for x in p["c"][i:i + 3]) for i in range(0, len(p["c"]), 3)]
        faces = [tuple(p["t"][i:i + 3]) for i in range(0, len(p["t"]), 3)]
        if p["role"] == "Eye" or p["n"].startswith("Lid"):
            continue  # olhos são refeitos (pintados) e as pálpebras ficam dentro da cabeça
        ob = make_mesh("src_" + p["n"], verts, faces, cols)
        ob["part"] = p["n"]
        ob["bone"] = part_bone(by_name, p) or "Torso"
        thin = thickness(verts) < vox * 2.5 or is_open(ob) or local_thickness(ob) < vox * 2.5
        wing = p["n"].startswith("Wing")
        is_body = (p["m"] in BODY_MATERIALS and p["m"] != "Metal" and float(p["tr"]) < 0.3 and p["role"] in ("Body", "Accent", "Detail")
                   and not wing)
        ob["glow"] = p["m"] in ("Neon", "Glass", "ForceField") or p["role"] == "Glow"
        # peças de pouca resolução (chapéu de cogumelo, folhas): subdivide antes, senão as faces aparecem
        if len(verts) < 700:
            sub = ob.modifiers.new("Sub0", "SUBSURF")
            sub.levels = 1
            apply_modifier(ob, sub)
        # peças finas (orelhas, folhas, caudas finas): engrossa um pouco para entrar no corpo contínuo
        # (sem isso o voxel não "enxerga" a lâmina e a orelha sai furada)
        if thin and (is_body or wing):
            so = ob.modifiers.new("Solid", "SOLIDIFY")
            so.thickness = vox * 2.6
            so.offset = 0
            so.use_even_offset = True
            apply_modifier(ob, so)
        (body_srcs if is_body else extras).append(ob)

    # pets todos de vidro/cristal/luz não têm "corpo comum": as peças maiores viram o corpo
    if not body_srcs:
        extras.sort(key=lambda o: -len(o.data.vertices))
        keep = [o for o in extras if not o["part"].startswith("Wing")][:max(1, len(extras) // 2)]
        for o in keep:
            extras.remove(o)
            body_srcs.append(o)

    # 1b) DETALHES esculpidos (entram no corpo contínuo e são suavizados com ele):
    #     tufos de pelo nas bochechas, pelo fofo no peito e dedinhos nas patas
    if rig.get("anatomy") in FURRY:
        add_details(rig, by_name, body_srcs, size)

    # 2) CORPO CONTÍNUO: junta as partes e refaz a superfície em voxels (some a emenda das juntas)
    src_bvh, src_cols, src_tris, src_bone = [], [], [], []
    for ob in body_srcs:
        me = ob.data
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        src_bvh.append((ob, BVHTree.FromBMesh(bm)))
        bm.free()
    select_only(*body_srcs)
    dup = [o.copy() for o in body_srcs]
    for o in dup:
        o.data = o.data.copy()
        scene.collection.objects.link(o)
    select_only(*dup)
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "Body"
    rm = body.modifiers.new("Remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = vox
    rm.use_smooth_shade = True
    apply_modifier(body, rm)
    sm = body.modifiers.new("Smooth", "CORRECTIVE_SMOOTH")
    sm.iterations = 6
    sm.smooth_type = "LENGTH_WEIGHTED"
    sm.use_only_smooth = True
    apply_modifier(body, sm)
    # orçamento do Roblox (MeshPart até ~20 mil triângulos): deixa ~12 mil
    tri = sum(len(pg.vertices) - 2 for pg in body.data.polygons)
    if tri > 12000:
        dc = body.modifiers.new("Decimate", "DECIMATE")
        dc.ratio = 12000 / tri
        apply_modifier(body, dc)
    for pg in body.data.polygons:
        pg.use_smooth = True

    # 3) cor e pesos de cada vértice do corpo novo, a partir das partes originais
    me = body.data
    col_attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    groups = {}
    blend = size * 0.06
    for i, v in enumerate(me.vertices):
        best = None
        dists = []
        for ob, bvh in src_bvh:
            loc, _nrm, fi, d = bvh.find_nearest(v.co)
            if loc is None:
                continue
            dists.append((d, ob, loc, fi))
            if best is None or d < best[0]:
                best = (d, ob, loc, fi)
        if best is None:
            continue
        # cor: interpolada no triângulo mais próximo da parte mais próxima
        d0, ob, loc, fi = best
        poly = ob.data.polygons[fi]
        vs = [ob.data.vertices[k].co for k in poly.vertices]
        cs = [ob.data.color_attributes["Col"].data[k].color for k in poly.vertices]
        w = [1 / max((loc - p).length, 1e-6) for p in vs]
        sw = sum(w)
        col_attr.data[i].color = tuple(sum(cs[k][j] * w[k] for k in range(len(vs))) / sw for j in range(3)) + (1.0,)
        # pesos: ossos das partes perto deste ponto, suavizados (a dobra da junta fica macia)
        acc = {}
        for d, o2, _l, _f in dists:
            if d <= d0 + blend:
                wt = math.exp(-((d - d0) / blend) ** 2 * 3)
                acc[o2["bone"]] = acc.get(o2["bone"], 0) + wt
        top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(x for _, x in top)
        for bname, wt in top:
            g = groups.get(bname)
            if g is None:
                g = body.vertex_groups.new(name=bname)
                groups[bname] = g
            g.add([i], wt / tot, "REPLACE")

    # 4) peças extras (finas, brilhantes, translúcidas: asas, folhas, gemas...) presas ao osso da parte
    extra_objs = []
    for ob in extras:
        bname = ob["bone"]
        g = ob.vertex_groups.new(name=bname)
        g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
        if not ob.get("glow") and len(ob.data.vertices) < 4000:
            sub = ob.modifiers.new("Sub", "SUBSURF")
            sub.levels = 1
            apply_modifier(ob, sub)
        for pg in ob.data.polygons:
            pg.use_smooth = True
        ob.name = "Detail_" + ob["part"]
        extra_objs.append(ob)
    for ob in body_srcs:
        bpy.data.objects.remove(ob, do_unlink=True)

    # 5) olhos pintados sobre a superfície nova
    bm = bmesh.new()
    bm.from_mesh(body.data)
    body_bvh = BVHTree.FromBMesh(bm)
    bm.free()
    eye_objs = []
    for k, e in enumerate(rig.get("eyes", [])):
        eo = make_eye("Eye%d" % (k + 1), e, body_bvh, size)
        img = eye_image("EyeTex%d" % (k + 1), e["iris"], e.get("glow"), e.get("slit"), e.get("sclera"))
        mat = bpy.data.materials.new("EyeMat%d" % (k + 1))
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.08
        eo.data.materials.append(mat)
        img.filepath_raw = os.path.join(out_dir, "%s_eye%d.png" % (rig["id"], k + 1))
        img.file_format = "PNG"
        img.save()
        g = eo.vertex_groups.new(name=part_bone(by_name, by_name.get(e.get("part"))) or "Head")
        g.add(list(range(len(eo.data.vertices))), 1.0, "REPLACE")
        eye_objs.append(eo)

    # 6) esqueleto: um osso por parte com junta, na posição do pivô, mesma hierarquia do jogo
    arm_data = bpy.data.armatures.new("Rig")
    arm = bpy.data.objects.new("Rig", arm_data)
    scene.collection.objects.link(arm)
    select_only(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    ebones = {}
    for p in parts:
        if p.get("joint"):
            b = arm_data.edit_bones.new(p["n"])
            h = rb(p["pivot"])
            b.head = h
            b.tail = h + Vector((0, 0, size * 0.06))
            ebones[p["n"]] = b
    for p in parts:
        if p["n"] in ebones:
            par = by_name.get(p.get("parent"))
            pb = part_bone(by_name, par) if par else None
            if pb and pb in ebones:
                ebones[p["n"]].parent = ebones[pb]
    bpy.ops.object.mode_set(mode="OBJECT")
    for ob in [body] + extra_objs + eye_objs:
        ob.parent = arm
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm

    # 7) textura: cores do corpo assadas numa imagem (o Roblox não usa cor por vértice nas MeshParts)
    select_only(body)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    img = bpy.data.images.new(rig["id"] + "_body", tex_size, tex_size)
    mat = bpy.data.materials.new("BodyMat")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    tnode = nt.nodes.new("ShaderNodeTexImage")
    tnode.image = img
    nt.nodes.active = tnode
    body.data.materials.append(mat)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 1
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.margin = 6
    select_only(body)
    bpy.ops.object.bake(type="DIFFUSE")
    img.filepath_raw = os.path.join(out_dir, rig["id"] + "_body.png")
    img.file_format = "PNG"
    img.save()
    # depois do bake o material usa a textura (é o que vai no FBX)
    nt.links.new(tnode.outputs["Color"], bsdf.inputs["Base Color"])
    for ob in extra_objs:
        m2 = bpy.data.materials.new("Mat_" + ob.name)
        m2.use_nodes = True
        b2 = m2.node_tree.nodes.get("Principled BSDF")
        vcol = ob.data.color_attributes.get("Col")
        if vcol and len(vcol.data):
            n = len(vcol.data)
            avg = [sum(vcol.data[i].color[j] for i in range(n)) / n for j in range(3)]
            b2.inputs["Base Color"].default_value = (avg[0], avg[1], avg[2], 1)
            if ob.get("glow"):
                b2.inputs["Emission Color"].default_value = (avg[0], avg[1], avg[2], 1)
                b2.inputs["Emission Strength"].default_value = 1.5
        ob.data.materials.append(m2)

    # 8) FBX (esqueleto + corpo + olhos + detalhes) com as texturas junto
    select_only(arm, body, *extra_objs, *eye_objs)
    fbx = os.path.join(out_dir, rig["id"] + ".fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True,
                             axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_UNITS", mesh_smooth_type="FACE", use_armature_deform_only=True)
    tris = sum(len(pg.vertices) - 2 for pg in body.data.polygons)

    # 9) prévia renderizada
    if render:
        render_preview(rig, out_dir, size, (zmin, zmax))
    return {"id": rig["id"], "tris": tris, "bones": len(ebones), "extras": len(extra_objs), "eyes": len(eye_objs), "voxel": vox}


def render_preview(rig, out_dir, size, zr):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.74, 0.86, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(12)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    scene.collection.objects.link(sun)
    ground = bpy.data.meshes.new("G")
    ground.from_pydata([(-50, -50, zr[0]), (50, -50, zr[0]), (50, 50, zr[0]), (-50, 50, zr[0])], [], [(0, 1, 2, 3)])
    gob = bpy.data.objects.new("Ground", ground)
    gm = bpy.data.materials.new("GM")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.36, 0.55, 0.25, 1)
    ground.materials.append(gm)
    scene.collection.objects.link(gob)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    mid = Vector((0, 0, (zr[0] + zr[1]) / 2))
    d = size * 1.9
    cam.location = mid + Vector((d * 0.75, d * 0.95, d * 0.3))  # 3/4 de frente (o pet olha para +Y)
    direction = mid - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.filepath = os.path.join(out_dir, rig["id"] + "_preview.png")
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--rigs", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--ids", default="")
    ap.add_argument("--render", action="store_true")
    ap.add_argument("--tex", type=int, default=1024)
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    ids = [x for x in a.ids.split(",") if x] or sorted(f[:-5] for f in os.listdir(a.rigs) if f.endswith(".json"))
    for pid in ids:
        if not a.force and os.path.exists(os.path.join(a.out, pid + ".fbx")):
            continue  # já feito (retoma de onde parou)
        rig = json.load(open(os.path.join(a.rigs, pid + ".json")))
        try:
            res = build(rig, a.out, a.tex, a.render)
            print("BUILT", json.dumps(res), flush=True)
        except Exception as e:  # um pet com problema não para os outros
            import traceback
            traceback.print_exc()
            print("FAILED", pid, e, flush=True)


if __name__ == "__main__":
    main()

"""Renderiza no Blender (Cycles na CPU; não precisa de placa de vídeo) quadros das animações do r15_luta.blend.
Uso: <python com bpy> tools/blender/render_poses.py <pasta-saída>"""
import os, sys, math
import bpy
HERE = os.path.dirname(os.path.abspath(__file__))
out = sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "r15_luta.blend"))
sc = bpy.context.scene
arm = bpy.data.objects["R15"]
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 24
sc.cycles.use_denoising = False
# cores do Ren nas peças do boneco
def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    return m
SKIN, COAT, LEGS = mat("pele", (0.86, 0.67, 0.55)), mat("casaco", (0.02, 0.03, 0.09)), mat("calca", (0.012, 0.012, 0.02))
for ob in bpy.data.objects:
    if ob.type == "MESH":
        n = ob.name
        ob.data.materials.clear()
        ob.data.materials.append(SKIN if ("Head" in n or "Hand" in n or "LowerArm" in n) else LEGS if ("Leg" in n or "Foot" in n) else COAT)
sun = bpy.data.objects.new("sol", bpy.data.lights.new("sol", "SUN"))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(150))
sc.collection.objects.link(sun)
sc.render.resolution_x, sc.render.resolution_y = 360, 420
sc.render.film_transparent = False
sc.world = bpy.data.worlds.new("w") if not sc.world else sc.world
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.25, 0.27, 0.36, 1)
cam_data = bpy.data.cameras.new("cam")
cam_data.lens = 50
cam = bpy.data.objects.new("cam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam
# câmera em 3/4 de frente (o R15 olha para -Z do Roblox = +Y do Blender)
cam.location = (7.5, 11, 4.2)
d = (0 - 7.5, 0 - 11, 2.6 - 4.2)
cam.rotation_euler = (math.atan2(math.hypot(d[0], d[1]), -d[2]), 0, math.atan2(d[1], d[0]) - math.pi / 2)
bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
bpy.context.active_object.data.materials.append(mat("chao", (0.18, 0.18, 0.2)))
shots = [("idle", 36), ("guard", 0), ("dash", 4), ("punch", 4), ("punch", 7), ("kick", 5), ("kick", 9), ("hurt", 3),
         ("slash", 6), ("slash", 10), ("castUp", 16), ("castPoint", 5), ("handSign", 16), ("float", 30), ("kneel", 14), ("punchL", 7)]
for i, (act, f) in enumerate(shots):
    arm.animation_data.action = bpy.data.actions[act]
    sc.frame_set(f)
    sc.render.filepath = os.path.join(out, "p%02d_%s_%d.png" % (i, act, f))
    bpy.ops.render.render(write_still=True)
print("ok")

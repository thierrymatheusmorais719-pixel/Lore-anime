#!/usr/bin/env python3
"""Exporta as animações de src/shared/Anim/Poses.luau para o formato JSON da skill
roblox-vfx-animation, para auditar/renderizar com scripts/animate.mjs.
Uso: python3 tools/export_poses.py OUT_DIR [Nome ...]"""
import json, os, re, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, "..")
out_dir = sys.argv[1]
wanted = sys.argv[2:]
os.makedirs(out_dir, exist_ok=True)
stub = open(os.path.join(here, "cframe_stub.luau"), encoding="utf-8").read()
combat = open(os.path.join(root, "src/shared/Config/Combat.luau"), encoding="utf-8").read()
poses = open(os.path.join(root, "src/shared/Anim/Poses.luau"), encoding="utf-8").read()
poses = re.sub(r"^--!\w+\n", "", poses)
poses = poses.replace("require(script.Parent.Parent.Config.Combat)", "__Combat()")
dump = r'''
local P = __Poses()
local names = {}
for name, def in P do
	if type(def) == "table" and def.keyframes then table.insert(names, name) end
end
table.sort(names)
for _, name in names do
	local def = P[name]
	local parts = {}
	for _, kf in def.keyframes do
		local joints = {}
		for joint, cf in kf.pose do
			local x, y, z = cf:ToEulerAnglesXYZ()
			table.insert(joints, string.format('"%s":[%.3f,%.3f,%.3f,%.4f,%.4f,%.4f]', joint, math.deg(x), math.deg(y), math.deg(z), cf.p[1], cf.p[2], cf.p[3]))
		end
		table.insert(parts, string.format('{"t":%.4f,"ease":"%s","j":{%s}}', kf.t, kf.ease or "inout", table.concat(joints, ",")))
	end
	print(string.format('{"name":"%s","loop":%s,"duration":%.4f,"keyframes":[%s]}', name, tostring(def.loop == true), def.duration, table.concat(parts, ",")))
end
'''
bundle = stub + "\nlocal function __Combat()\n" + combat + "\nend\nlocal function __Poses()\n" + poses + "\nend\n" + dump
path = os.path.join(out_dir, "_poses_bundle.luau")
open(path, "w", encoding="utf-8").write(bundle)
luau = os.environ.get("LUAU", "luau")
out = subprocess.run([luau, path], capture_output=True, text=True)
if out.returncode != 0:
    sys.exit(out.stderr)

EASE = {"linear": ("Linear", "In"), "out": ("CubicV2", "Out"), "inout": ("CubicV2", "InOut"), "expo": ("CubicV2", "Out")}
JOINTS = ["Root", "Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist",
          "RightHip", "RightKnee", "LeftHip", "LeftKnee"]
for line in out.stdout.strip().splitlines():
    d = json.loads(line)
    if wanted and d["name"] not in wanted:
        continue
    used = set()
    for kf in d["keyframes"]:
        used.update(kf["j"].keys())
    kfs = []
    for i, kf in enumerate(d["keyframes"]):
        joints = {}
        for j in JOINTS:
            if j not in used:
                continue
            v = kf["j"].get(j, [0, 0, 0, 0, 0, 0])
            pose = {"rotation": [round(v[0], 2), round(v[1], 2), round(v[2], 2)]}
            if j == "Root":
                pose["position"] = [round(v[3], 3), round(v[4], 3), round(v[5], 3)]
            joints[j] = pose
        style, direction = EASE.get(kf["ease"], EASE["inout"])
        t = round(kf["t"], 4)
        if kfs and t <= kfs[-1]["time"]:
            t = kfs[-1]["time"] + 0.001
        kfs.append({"time": t, "easing": {"style": style, "direction": direction}, "joints": joints})
    anim = {"name": d["name"], "rig": "R15", "loop": d["loop"], "keyframes": kfs}
    if d["loop"] and kfs:
        last = dict(kfs[0]); last["time"] = round(d["duration"], 4)
        if kfs[-1]["time"] < last["time"]:
            kfs.append(last)
        else:
            kfs[-1]["joints"] = kfs[0]["joints"]
    open(os.path.join(out_dir, d["name"] + ".json"), "w").write(json.dumps(anim))
    print(d["name"])

#!/usr/bin/env python3
"""Extrai Timeline (planos/eventos) e PoseDriver (poses) dos .luau para data.js — a prévia usa os MESMOS dados do jogo."""
import json, re, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
tl = (root / "src/shared/Timeline.luau").read_text()
pd = (root / "src/shared/PoseDriver.luau").read_text()

def vec(m): return [float(x) for x in m.split(",")]
shots = []
sh = tl[tl.index("Timeline.Shots = {"):tl.index("Timeline.Events = {")]
for blk in re.split(r"\n\t(?=\{ t = )", sh)[1:]:
    t = float(re.search(r"\{ t = ([\d.]+), duration = ([\d.]+), ease = \"(\w+)\"", blk).group(1))
    d = float(re.search(r"duration = ([\d.]+)", blk).group(1))
    e = re.search(r'ease = "(\w+)"', blk).group(1)
    def side(name):
        m = re.search(name + r" = \{ pos = V\(([^)]*)\), look = V\(([^)]*)\), fov = ([\d.]+) \}", blk)
        return {"pos": vec(m.group(1)), "look": vec(m.group(2)), "fov": float(m.group(3))}
    s = {"t": t, "duration": d, "ease": e, "from": side("from"), "to": side("to")}
    o = re.search(r"orbit = \{ degrees = ([\d.]+), radius = ([\d.]+), height = ([\d.]+) \}", blk)
    if o: s["orbit"] = {"degrees": float(o.group(1)), "radius": float(o.group(2)), "height": float(o.group(3))}
    shots.append(s)

events = []
ev = tl[tl.index("Timeline.Events = {"):tl.index("local function ease")]
for m in re.finditer(r'\{ t = ([\d.]+), name = "(\w+)"(?:, arg = ([^}]+?))? \}', ev):
    arg = m.group(3)
    if arg is not None:
        arg = arg.strip()
        arg = arg.strip('"') if arg.startswith('"') else float(arg)
    events.append({"t": float(m.group(1)), "name": m.group(2), "arg": arg})

poses = {}
for m in re.finditer(r"local (\w+): Pose = \{(.*?)\n\}", pd, re.S):
    poses[m.group(1)] = {j: [float(x) for x in v.split(",")] for j, v in re.findall(r"(\w+) = \{ ([-\d., ]+) \}", m.group(2))}
anims = {}
for m in re.finditer(r"(\w+) = \{ length = ([\d.]+), looped = (\w+), keys = \{(.*?)\} \},?\n", pd, re.S):
    anims[m.group(1)] = {"length": float(m.group(2)), "looped": m.group(3) == "true",
                         "keys": [{"t": float(t), "pose": p} for t, p in re.findall(r"P\(([\d.]+), (\w+)\)", m.group(4))]}
dur = float(re.search(r"Timeline.Duration = ([\d.]+)", tl).group(1))
kits = {"obj": json.loads((root / "src/shared/KitDataObj.json").read_text()), "procedural": json.loads((root / "src/shared/KitDataProcedural.json").read_text())}
(root / "preview/data.js").write_text("export const DATA = " + json.dumps({"duration": dur, "shots": shots, "events": events, "poses": poses, "anims": anims, "kits": kits}, indent=1) + ";\n")
print(len(shots), "planos", len(events), "eventos", len(poses), "poses", list(anims))

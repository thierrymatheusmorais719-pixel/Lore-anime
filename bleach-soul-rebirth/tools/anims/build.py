#!/usr/bin/env python3
"""Compila as animações autoradas (gerador author.py → json/) com o animate.mjs da skill
roblox-vfx-animation, exige que as checagens de movimento passem, e gera:
  • src/shared/Anim/Clips.luau        — dados de runtime (faixas por junta, mesmos CFrames/easing do Roblox)
  • tools/anims/keyframes/<Nome>.lua  — Luau que cria o KeyframeSequence no Studio (para publicar)
  • <sheets>/<Nome>.png               — folhas de contato para revisão visual
Uso: python3 tools/anims/build.py [--sheets DIR] [--only Nome,Nome]"""
import argparse, glob, json, os, re, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, "..", ".."))
skill = os.path.abspath(os.path.join(root, "..", ".claude", "skills", "vfxskill", "scripts", "animate.mjs"))

# Velocidade de chão (studs/s dos pés plantados) das marchas, da referência da skill.
GROUND_SPEED = {"NpcWalk": 2.21, "NpcRun": 4.08, "NpcSprint": 4.08 / 0.45}

PART_TO_JOINT = {
    "LowerTorso": "Root", "UpperTorso": "Waist", "Head": "Neck",
    "RightUpperArm": "RightShoulder", "RightLowerArm": "RightElbow", "RightHand": "RightWrist",
    "LeftUpperArm": "LeftShoulder", "LeftLowerArm": "LeftElbow", "LeftHand": "LeftWrist",
    "RightUpperLeg": "RightHip", "RightLowerLeg": "RightKnee", "RightFoot": "RightAnkle",
    "LeftUpperLeg": "LeftHip", "LeftLowerLeg": "LeftKnee", "LeftFoot": "LeftAnkle",
    "BodyAttach": "Weapon", "OffHandAttach": "OffHand", "SheathAttach": "Sheath",
}
POSE_RE = re.compile(r'P\("(\w+)",([\d.]+),\{([^}]*)\},"(\w+)","(\w+)"')

def parse_luau(text):
    tracks, markers = {}, []
    for block in text.split("local k = Instance.new(\"Keyframe\")")[1:]:
        time = float(re.search(r"k\.Time = ([\d.e-]+)", block).group(1))
        for m in re.finditer(r'm\.Name = "(\w+)"; m\.Value = "([^"]*)"', block):
            markers.append((m.group(1), time, m.group(2)))
        for part, weight, cf, style, direction in POSE_RE.findall(block):
            if float(weight) <= 0 or part not in PART_TO_JOINT:
                continue
            nums = [float(x) for x in cf.split(",")]
            tracks.setdefault(PART_TO_JOINT[part], []).append((time, nums, style, direction))
    for keys in tracks.values():
        keys.sort(key=lambda k: k[0])
    return tracks, markers

def fmt(n):
    s = f"{n:.5f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheets", default=None)
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    manifest = json.load(open(os.path.join(here, "json", "manifest.json")))
    only = set(filter(None, args.only.split(",")))
    out_lua = os.path.join(here, "keyframes")
    os.makedirs(out_lua, exist_ok=True)
    if args.sheets:
        os.makedirs(args.sheets, exist_ok=True)
    clips, failures = {}, []
    for name, info in sorted(manifest.items()):
        src = os.path.join(here, "json", name + ".json")
        lua_path = os.path.join(out_lua, name + ".lua")
        cmd = ["node", skill, src, "--out", lua_path, "--parent", "game.ServerStorage"]
        cmd += info.get("flags", [])
        if info.get("waive"):
            cmd += ["--waive", ",".join(info["waive"])]
        if args.sheets and (not only or name in only):
            cmd += ["--sheet", os.path.join(args.sheets, name + ".png")]
        res = subprocess.run(cmd, capture_output=True, text=True)
        try:
            report = json.loads(res.stdout)
        except Exception:
            failures.append((name, res.stdout[-400:] + res.stderr[-400:]))
            continue
        if not report.get("ok"):
            failures.append((name, report.get("errors") or [c for c in report.get("checks", []) if c["status"] == "fail"]))
            continue
        tracks, markers = parse_luau(open(lua_path).read())
        clips[name] = {"duration": report["duration"], "loop": report["loop"], "priority": report.get("priority", "Action"),
                       "tracks": tracks, "markers": markers, "groundSpeed": GROUND_SPEED.get(name) or info.get("groundSpeed")}
        print(f"ok  {name:16s} {report['duration']:.2f}s  poses={report['poses']}  marcadores={[m[0] for m in markers]}")
    if failures:
        for name, why in failures:
            print(f"FALHA {name}: {json.dumps(why, ensure_ascii=False)[:600]}")
        sys.exit(1)
    lines = ["-- GERADO por tools/anims/build.py a partir de tools/anims/json (animate.mjs da skill",
             "-- roblox-vfx-animation). NÃO edite à mão: edite author.py e rode o build.",
             "-- Cada faixa: { tempo, CFrame (Motor6D.Transform), estilo, direção } — easing da pose de saída.",
             "local C = CFrame.new", "return {"]
    for name, clip in sorted(clips.items()):
        lines.append(f"\t{name} = {{")
        lines.append(f"\t\tduration = {fmt(clip['duration'])},")
        lines.append(f"\t\tloop = {'true' if clip['loop'] else 'false'},")
        lines.append(f"\t\tpriority = \"{clip['priority']}\",")
        if clip.get("groundSpeed"):
            lines.append(f"\t\tgroundSpeed = {fmt(clip['groundSpeed'])},")
        lines.append("\t\tmarkers = {" + ", ".join(f"{{ name = \"{m[0]}\", time = {fmt(m[1])} }}" for m in clip["markers"]) + "},")
        lines.append("\t\ttracks = {")
        for joint, keys in sorted(clip["tracks"].items()):
            parts = []
            for t, n, style, direction in keys:
                parts.append(f"{{ {fmt(t)}, C({', '.join(fmt(x) for x in n)}), \"{style}\", \"{direction}\" }}")
            lines.append(f"\t\t\t{joint} = {{ " + ", ".join(parts) + " },")
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    dest = os.path.join(root, "src", "shared", "Anim", "Clips.luau")
    open(dest, "w").write("\n".join(lines) + "\n")
    print(f"\n{len(clips)} clips → {os.path.relpath(dest, root)}")

if __name__ == "__main__":
    main()

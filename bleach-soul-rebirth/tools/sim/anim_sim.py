#!/usr/bin/env python3
"""Roda o AnimController de verdade (código do cliente) num personagem R15 simulado, sem Studio:
confere que as juntas do jogador se mexem parado, andando e correndo — inclusive quando
Humanoid:ApplyDescription enche o Animate do projeto de valores. Uso:
  LUAU=caminho/luau python3 tools/sim/anim_sim.py"""
import os, re, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, "..", ".."))
LUAU = os.environ.get("LUAU", "luau")
SRC = {"Shared": os.path.join(root, "src", "shared"), "Client": os.path.join(root, "src", "client")}

modules, order = {}, []


def load(key, path):
    """key = 'Shared/Anim/Poses'; resolve os requires para MODULE("...")."""
    if key in modules:
        return
    modules[key] = None
    code = open(path, encoding="utf-8").read()
    code = re.sub(r"^--!\w+\n", "", code)
    code = re.sub(r"^export type ", "type ", code, flags=re.M)
    folder = key.rsplit("/", 1)[0]

    def resolve(expr):
        expr = expr.strip()
        m = re.match(r"(?:ReplicatedStorage\.)?Shared((?:\.\w+)+)$", expr)
        if m:
            return "Shared" + m.group(1).replace(".", "/")
        m = re.match(r"script((?:\.Parent)+)((?:\.\w+)+)$", expr)
        if m:
            ups = m.group(1).count(".Parent")
            base = key.split("/")[:-ups] if ups else key.split("/")
            return "/".join(base + m.group(2).strip(".").split("."))
        return None

    # aliases locais: local Shared = ReplicatedStorage.Shared
    def sub(m):
        target = resolve(m.group(1))
        if not target:
            return m.group(0)
        load(target, os.path.join(SRC[target.split("/")[0]], *target.split("/")[1:]) + ".luau")
        return f'MODULE("{target}")'
    code = re.sub(r"require\(([\w\.]+)\)(?:\s*::\s*any)?", sub, code)
    code = code.replace("os.clock()", "SIM_CLOCK()")  # os é só leitura no CLI
    modules[key] = code
    order.append(key)


load("Client/Controllers/AnimController", os.path.join(SRC["Client"], "Controllers", "AnimController.luau"))

cframe = open(os.path.join(root, "tools", "cframe_stub.luau"), encoding="utf-8").read().split("-- @@FIM_CFRAME@@")[0]
cframe = cframe.replace("local CFrame = {", "CFrame = {")
mock = open(os.path.join(here, "client_mock.luau"), encoding="utf-8").read()
scenario = open(os.path.join(here, "anim_scenario.luau"), encoding="utf-8").read()
parts = [cframe, mock, "local __modules, __cache = {}, {}",
         "function MODULE(name)\n\tif __cache[name] == nil then __cache[name] = __modules[name]() end\n\treturn __cache[name]\nend"]
for key in order:
    parts.append(f'__modules["{key}"] = function()\nlocal script = {{}}\nlocal ReplicatedStorage = {{ Shared = {{}} }}\n{modules[key]}\nend')
failed = False
for joint in ("Motor6D", "AnimationConstraint"):
    out = os.path.join(here, ".anim_sim.luau")
    open(out, "w", encoding="utf-8").write("\n".join(parts + [f'SIM_JOINT = "{joint}"', scenario]))
    res = subprocess.run([LUAU, out], capture_output=True, text=True)
    print(f"--- juntas {joint}")
    print(res.stdout[-6000:])
    if res.returncode != 0 or res.stderr.strip():
        print(res.stderr[-4000:])
        failed = True
    failed = failed or "FALHA" in res.stdout
sys.exit(1 if failed else 0)

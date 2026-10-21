#!/usr/bin/env python3
"""Empacota stubs + módulos puros + run.luau num único arquivo executável pelo CLI `luau`
(o CLI não permite injetar globais Roblox nos módulos via require)."""
import os, re

here = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(here, "..", "src", "shared")
run = open(os.path.join(here, "run.luau"), encoding="utf-8").read()
names = sorted(set(re.findall(r'MODULE\("([^"]+)"\)', run)))

out = [open(os.path.join(here, "stubs.luau"), encoding="utf-8").read()]
out.append("local __modules, __cache = {}, {}")
out.append("local function MODULE(name)\n\tif __cache[name] == nil then __cache[name] = __modules[name]() end\n\treturn __cache[name]\nend")
for name in names:
    code = open(os.path.join(src, name + ".luau"), encoding="utf-8").read()
    code = re.sub(r"^--!\w+\n", "", code)
    code = re.sub(r"^export type ", "type ", code, flags=re.M)
    out.append(f'__modules["{name}"] = function()\n{code}\nend')
out.append(run)
open(os.path.join(here, ".bundle.luau"), "w", encoding="utf-8").write("\n".join(out))
print(f"bundle: {len(names)} módulos")

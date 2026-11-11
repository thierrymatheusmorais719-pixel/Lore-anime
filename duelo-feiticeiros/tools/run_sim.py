#!/usr/bin/env python3
"""Roda a cinemática inteira no simulador (mock do Roblox reaproveitado de ../mythical-isles/tools).
Uso: python3 tools/run_sim.py <caminho do luau> [cenário .luau, padrão sim_cinematic.luau]
Não substitui um teste no Roblox Studio: o mock não renderiza nada, só executa o código e confere estado."""
import os, re, sys, subprocess, tempfile
here = os.path.dirname(os.path.abspath(__file__))
mi = os.path.join(here, "..", "..", "mythical-isles", "tools")
sys.path.insert(0, mi)
import run_tests  # PRELUDE

def main():
    luau = sys.argv[1] if len(sys.argv) > 1 else "luau"
    src = os.path.join(here, "..", "src")
    parts = [open(os.path.join(mi, "roblox_mock.luau"), encoding="utf-8").read(),
             run_tests.PRELUDE.replace("Color3 = {", "local __unusedColor3 = {").replace("Vector3 = {", "local __unusedVector3 = {"),
             open(os.path.join(mi, "sim_runtime.luau"), encoding="utf-8").read()]
    env = "local task, os, typeof, warn = SIM.task, SIM.os, SIM.typeof, SIM.warn\n"
    def add(path, file):
        code = open(file, encoding="utf-8").read()
        code = re.sub(r"^--!\w+\s*$", "", code, flags=re.M)
        # no mock, ReplicatedStorage.Duelo é o proxy dos módulos compartilhados
        code = code.replace('ReplicatedStorage:WaitForChild("Duelo")', '__proxy("Duelo")')
        parts.append('__modules["%s"] = function(script)\n%s%s\nend\n' % (path, env, code))
    for f in os.listdir(os.path.join(src, "shared")):
        if f.endswith(".luau"):
            add("Duelo/" + f[:-5], os.path.join(src, "shared", f))
    add("Server/Main", os.path.join(src, "server", "Main.server.luau"))
    add("Client/Main", os.path.join(src, "client", "Main.client.luau"))
    parts.append(env)
    script = sys.argv[2] if len(sys.argv) > 2 else "sim_cinematic.luau"
    parts.append(open(os.path.join(here, script), encoding="utf-8").read())
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
        f.write("\n".join(parts))
    sys.exit(subprocess.run([luau, f.name]).returncode)

main()

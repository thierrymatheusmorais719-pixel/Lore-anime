#!/usr/bin/env python3
"""Executa os testes de lógica pura (src/shared/Tests/*.spec.luau) FORA do Roblox Studio.

Empacota os ModuleScripts de src/shared/{Config,Logic,Tests} num único arquivo Luau, com um
`script` falso (para `require(script.Parent.X)` funcionar) e stubs mínimos de Color3/Vector3,
e roda com o CLI oficial do Luau (`luau`).

Uso:  python3 tools/run_tests.py [caminho/para/luau] [--smoke | --sim]
  --smoke  também executa os construtores 3D (Builders) sobre um mock da API do Roblox
           (tools/roblox_mock.luau) e verifica juntas, peças e mutações (tools/smoke_builders.luau)
  --sim    executa o SERVIDOR REAL (src/server) num simulador com relógio virtual
           (tools/sim_runtime.luau) e roda os cenários de tools/sim_scenarios.luau
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "shared")
FOLDERS = ["Config", "Logic", "Tests"]

PRELUDE = r'''
-- stubs mínimos de tipos do Roblox usados nas configs
Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end, new = function(r, g, b) return { R = r, G = g, B = b } end }
Vector3 = { new = function(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end }
local __modules = {}
local __cache = {}
local function __proxy(path)
	return setmetatable({ __path = path }, { __index = function(self, k)
		local p = rawget(self, "__path")
		if k == "Parent" then
			local parent = p:match("^(.*)/[^/]+$") or ""
			return __proxy(parent)
		elseif k == "Name" then
			return p:match("([^/]+)$")
		elseif k == "WaitForChild" or k == "FindFirstChild" then
			return function(_, name)
				return __proxy(p == "" and name or (p .. "/" .. name))
			end
		end
		return __proxy(p == "" and k or (p .. "/" .. k))
	end })
end
local __require = require
require = function(x)
	if type(x) == "table" and rawget(x, "__path") then
		local p = rawget(x, "__path")
		if __cache[p] == nil then
			local f = __modules[p]
			assert(f, "modulo nao encontrado: " .. p)
			__cache[p] = f(__proxy(p))
		end
		return __cache[p]
	end
	return __require(x)
end
'''

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    smoke = "--smoke" in sys.argv
    sim = "--sim" in sys.argv
    if sim:
        return run_sim(args[0] if args else "luau")
    luau = args[0] if args else "luau"
    here = os.path.dirname(os.path.abspath(__file__))
    parts = []
    if smoke:
        parts.append(open(os.path.join(here, "roblox_mock.luau"), encoding="utf-8").read())
    parts.append(PRELUDE if not smoke else PRELUDE.replace("Color3 = {", "local __unusedColor3 = {").replace("Vector3 = {", "local __unusedVector3 = {"))
    folders = FOLDERS + (["Builders", "Util"] if smoke else [])
    specs = []
    for folder in folders:
        d = os.path.join(ROOT, folder)
        for name in sorted(os.listdir(d)):
            if not name.endswith(".luau"):
                continue
            mod = name[: -len(".luau")]
            path = folder + "/" + mod
            src = open(os.path.join(d, name), encoding="utf-8").read()
            src = re.sub(r"^--!\w+\s*$", "", src, flags=re.M)
            src = re.sub(r"\bexport type\b", "type", src)
            parts.append('__modules["%s"] = function(script)\n%s\nend\n' % (path, src))
            if folder == "Tests" and mod.endswith(".spec"):
                specs.append(path)
    if smoke:
        parts.append(open(os.path.join(here, "smoke_builders.luau"), encoding="utf-8").read())
        with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
            f.write("\n".join(parts))
        sys.exit(subprocess.run([luau, f.name]).returncode)
    parts.append('local Runner = require(__proxy("Tests/TestRunner"))\n')
    parts.append("local specs = {%s}\n" % ", ".join('{ name = "%s", mod = require(__proxy("%s")) }' % (s, s) for s in specs))
    parts.append("local ok = Runner.run(specs, print)\nif not ok then error(\"TESTES FALHARAM\") end\n")
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
        f.write("\n".join(parts))
        bundle = f.name
    proc = subprocess.run([luau, bundle])
    sys.exit(proc.returncode)

def run_sim(luau):
    here = os.path.dirname(os.path.abspath(__file__))
    src = os.path.join(here, "..", "src")
    parts = [open(os.path.join(here, "roblox_mock.luau"), encoding="utf-8").read(),
             PRELUDE.replace("Color3 = {", "local __unusedColor3 = {").replace("Vector3 = {", "local __unusedVector3 = {"),
             open(os.path.join(here, "sim_runtime.luau"), encoding="utf-8").read()]
    env = "local task, os, typeof, warn = SIM.task, SIM.os, SIM.typeof, SIM.warn\n"
    def add(path, file):
        code = open(file, encoding="utf-8").read()
        code = re.sub(r"^--!\w+\s*$", "", code, flags=re.M)
        code = re.sub(r"\bexport type\b", "type", code)
        parts.append('__modules["%s"] = function(script)\n%s%s\nend\n' % (path, env, code))
    for d, _, fs in os.walk(os.path.join(src, "shared")):
        for f in fs:
            if f.endswith(".luau"):
                rel = os.path.relpath(os.path.join(d, f), os.path.join(src, "shared"))[:-5].replace(os.sep, "/")
                add("Shared/" + rel, os.path.join(d, f))
    add("Server/Main", os.path.join(src, "server", "Main.server.luau"))
    for f in os.listdir(os.path.join(src, "server", "Services")):
        if f.endswith(".luau"):
            add("Server/Services/" + f[:-5], os.path.join(src, "server", "Services", f))
    add("Client/Main", os.path.join(src, "client", "Main.client.luau"))
    for f in os.listdir(os.path.join(src, "client", "Controllers")):
        if f.endswith(".luau"):
            add("Client/Controllers/" + f[:-5], os.path.join(src, "client", "Controllers", f))
    parts.append("local task, os, typeof, warn = SIM.task, SIM.os, SIM.typeof, SIM.warn\n")
    parts.append(open(os.path.join(here, "sim_scenarios.luau"), encoding="utf-8").read())
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
        f.write("\n".join(parts))
    sys.exit(subprocess.run([luau, f.name]).returncode)

if __name__ == "__main__":
    main()

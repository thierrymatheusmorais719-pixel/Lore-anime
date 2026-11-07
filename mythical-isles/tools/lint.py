#!/usr/bin/env python3
"""Checagem estática simples com o `luau-analyze` oficial (sem definições da API do Roblox).

Como as definições do Roblox não estão disponíveis aqui, filtramos os avisos esperados
(globais do Roblox, tipos de instância) e mostramos o resto: variáveis não definidas
(erros de digitação), uso de locais antes da declaração, sintaxe, etc.

Uso: python3 tools/lint.py [caminho/para/luau-analyze]
"""
import os, re, subprocess, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src")
ROBLOX_GLOBALS = {
    "game", "workspace", "script", "Instance", "Enum", "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2",
    "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "NumberRange", "Random",
    "RaycastParams", "OverlapParams", "TweenInfo", "task", "typeof", "tick", "warn", "Rect", "BrickColor", "PhysicalProperties",
    "DateTime", "Font", "Ray", "Region3", "Faces", "Axes", "shared", "plugin", "settings", "utf8", "bit32", "buffer",
    "delay", "spawn", "wait", "elapsedTime", "time", "version", "printidentity", "gcinfo", "Path2DControlPoint",
    "Content",  # Content.fromObject (malhas criadas em tempo de execução com EditableMesh)
}
def main():
    exe = sys.argv[1] if len(sys.argv) > 1 else "luau-analyze"
    files = []
    for d, _, fs in os.walk(ROOT):
        files += [os.path.join(d, f) for f in fs if f.endswith(".luau")]
    proc = subprocess.run([exe, "--formatter=plain"] + files, capture_output=True, text=True)
    out = (proc.stdout + proc.stderr).splitlines()
    shown = 0
    for line in out:
        m = re.search(r"Unknown global '([^']+)'", line)
        if m:
            if m.group(1) in ROBLOX_GLOBALS:
                continue
            print(line); shown += 1; continue
        if re.search(r"UnknownType|Unknown type '|TypeError|not found|Cannot call|Unknown require|unknown require|could not be resolved|Type '|has no member|Key '|expects|is not|Argument count|cannot be|Unknown symbol|unknown member", line):
            continue  # ruído esperado sem as definições do Roblox
        if line.strip() == "caused by:" or line.startswith("  "):
            continue
        if line.strip():
            print(line); shown += 1
    print(f"lint: {shown} avisos relevantes")
    sys.exit(1 if shown else 0)
if __name__ == "__main__":
    main()

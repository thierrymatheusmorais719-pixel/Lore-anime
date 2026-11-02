#!/usr/bin/env python3
"""Verifica o código contra o dump oficial da API do Roblox (sem precisar do Studio).

Checa:
  1. Enum.X.Y  — enum e item existem
  2. Propriedades passadas em construtores de instância: Make("Class", {...}), UIKit.new/new("Class", {...})
     e helpers com classe conhecida (UIKit.frame/label/button/scroll, part/ellipsoid/p do mundo)
  3. local v = Instance.new("Class") ... v.Prop = valor
  4. Nomes de métodos chamados com ':' existem em alguma classe/datatype conhecido

Uso: python3 tools/api_check.py caminho/API-Dump.json
Dump: https://github.com/MaximumADHD/Roblox-Client-Tracker (API-Dump.json)
"""
import json, os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src")

def load(path):
    d = json.load(open(path, encoding="utf-8"))
    classes = {c["Name"]: c for c in d["Classes"]}
    enums = {e["Name"]: {i["Name"] for i in e["Items"]} for e in d["Enums"]}
    def members(name, kind=None):
        out = set()
        while name and name in classes:
            for m in classes[name]["Members"]:
                if kind is None or m["MemberType"] in kind:
                    out.add(m["Name"])
            name = classes[name].get("Superclass")
        return out
    allfuncs = set()
    for c in classes.values():
        for m in c["Members"]:
            if m["MemberType"] in ("Function", "Event", "Callback"):
                allfuncs.add(m["Name"])
    return classes, enums, members, allfuncs

DATATYPE_METHODS = {
    # CFrame / Vector3 / Color3 / UDim2 / Random / sinais / tweens / tipos do Luau
    "Inverse", "Lerp", "ToWorldSpace", "ToObjectSpace", "PointToWorldSpace", "PointToObjectSpace", "VectorToWorldSpace",
    "VectorToObjectSpace", "GetComponents", "ToEulerAnglesXYZ", "ToEulerAnglesYXZ", "ToOrientation", "ToAxisAngle", "Orthonormalize",
    "Dot", "Cross", "FuzzyEq", "Max", "Min", "Abs", "Ceil", "Floor", "Sign", "Angle",
    "ToHSV", "ToHex", "NextNumber", "NextInteger", "NextUnitVector", "Shuffle", "Clone",
    "Connect", "Once", "Wait", "Disconnect", "ConnectParallel",
    "sub", "match", "gmatch", "gsub", "format", "find", "lower", "upper", "rep", "split", "byte", "len", "reverse",
    # objetos do próprio projeto
    "allow", "clear",
}
CONSTRUCTOR_HELPERS = {
    r"UIKit\.frame\(\{": "Frame", r"UIKit\.label\(\{": "TextLabel", r"UIKit\.button\(\{": "TextButton", r"UIKit\.scroll\(\{": "ScrollingFrame",
    r"(?<![\w.])part\(\{": "Part", r"(?<![\w.])ellipsoid\(\{": "Part", r"(?<![\w.])p\(m, \{": "Part", r"(?<![\w.])p\(model, \{": "Part",
}
HELPER_EXTRA = {"radius"}  # chaves consumidas pelos helpers (não são propriedades)

def table_keys(src, start):
    """Lê a tabela que começa em src[start] == '{' e devolve as chaves de nível 1 (Nome = ...)."""
    depth, i, keys, token_start = 0, start, [], start + 1
    n = len(src)
    in_str = None
    while i < n:
        ch = src[i]
        if in_str:
            if ch == "\\":
                i += 2; continue
            if ch == in_str:
                in_str = None
        elif ch in "\"'":
            in_str = ch
        elif ch in "{([":
            depth += 1
            if depth == 1:
                token_start = i + 1
        elif ch in "})]":
            depth -= 1
            if depth == 0:
                seg = src[token_start:i]
                m = re.match(r"\s*([A-Za-z_]\w*)\s*=(?!=)", seg)
                if m: keys.append(m.group(1))
                return keys
        elif ch == "," and depth == 1:
            seg = src[token_start:i]
            m = re.match(r"\s*([A-Za-z_]\w*)\s*=(?!=)", seg)
            if m: keys.append(m.group(1))
            token_start = i + 1
        i += 1
    return keys

def main():
    classes, enums, members, allfuncs = load(sys.argv[1])
    problems = 0
    def report(f, line, msg):
        nonlocal problems
        problems += 1
        print(f"{os.path.relpath(f, ROOT)}:{line}: {msg}")
    project_funcs = set()
    files = []
    for d, _, fs in os.walk(ROOT):
        for f in fs:
            if f.endswith(".luau"):
                files.append(os.path.join(d, f))
    for f in files:
        src = open(f, encoding="utf-8").read()
        project_funcs |= set(re.findall(r"function\s+[\w.]+[.:](\w+)\s*\(", src))
    for f in files:
        src = open(f, encoding="utf-8").read()
        lineof = lambda pos: src.count("\n", 0, pos) + 1
        # 1. enums
        for m in re.finditer(r"Enum\.(\w+)\.(\w+)", src):
            e, item = m.group(1), m.group(2)
            if e not in enums:
                report(f, lineof(m.start()), f"Enum inexistente: Enum.{e}")
            elif item not in enums[e]:
                report(f, lineof(m.start()), f"Item inexistente: Enum.{e}.{item}")
        for m in re.finditer(r"Enum\.(\w+)\[", src):
            if m.group(1) not in enums:
                report(f, lineof(m.start()), f"Enum inexistente: Enum.{m.group(1)}")
        # 2. construtores com tabela
        for m in re.finditer(r'(?:Make|UIKit\.new|(?<![\w.])new)\("(\w+)",\s*\{', src):
            cls = m.group(1)
            if cls not in classes:
                report(f, lineof(m.start()), f"Classe inexistente: {cls}"); continue
            props = members(cls, ("Property",))
            for k in table_keys(src, m.end() - 1):
                if k != "Parent" and k not in props:
                    report(f, lineof(m.start()), f"{cls} não tem a propriedade '{k}'")
        for pat, cls in CONSTRUCTOR_HELPERS.items():
            for m in re.finditer(pat, src):
                props = members(cls, ("Property",))
                for k in table_keys(src, m.end() - 1):
                    if k not in props and k not in HELPER_EXTRA and k != "Parent":
                        report(f, lineof(m.start()), f"{cls} (helper) não tem a propriedade '{k}'")
        # 3. Instance.new + atribuições
        for m in re.finditer(r'local\s+(\w+)\s*=\s*Instance\.new\("(\w+)"\)', src):
            var, cls = m.group(1), m.group(2)
            if cls not in classes:
                report(f, lineof(m.start()), f"Classe inexistente: {cls}"); continue
            props = members(cls, ("Property",))
            rest = src[m.end():]
            # até a próxima redefinição da mesma variável
            nxt = re.search(r"local\s+" + re.escape(var) + r"\s*=", rest)
            scope = rest[: nxt.start()] if nxt else rest
            for a in re.finditer(r"(?<![\w.])" + re.escape(var) + r"\.(\w+)\s*=(?!=)", scope):
                if a.group(1) not in props:
                    report(f, lineof(m.end() + a.start()), f"{cls} não tem a propriedade '{a.group(1)}'")
        # 4. métodos
        for m in re.finditer(r":(\w+)\(", src):
            name = m.group(1)
            if name in allfuncs or name in DATATYPE_METHODS or name in project_funcs:
                continue
            # ignora anotações de tipo do tipo `x: number(`, improvável
            report(f, lineof(m.start()), f"método desconhecido ':{name}('")
    print(f"api_check: {problems} problemas")
    sys.exit(1 if problems else 0)

if __name__ == "__main__":
    main()

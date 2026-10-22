#!/usr/bin/env python3
"""Autoria das animações do jogo no formato de poses da skill roblox-vfx-animation.
Gera tools/anims/json/<Nome>.json + manifest.json (flags de checagem). Depois: build.py.

Convenções (references/character-animation.md):
  aim [direita, cima, frente]; bend em graus; aimAt em studs a partir do centro do HRP
  (tornozelo plantado em cima = -2.93); Weapon.rotation: [0,0,0] = lâmina saindo do punho,
  [-90,0,0] = lâmina ao longo do antebraço. Tempos de impacto = `windup` de Config/Combat.luau
  (tests/run.luau confere marcador "Hit" × windup)."""
import json, os

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "json")
os.makedirs(out, exist_ok=True)
manifest = {}

# Tempos de Config/Combat.luau (windup, duration)
LIGHT = [(0.10, 0.30), (0.10, 0.30), (0.12, 0.34), (0.11, 0.34), (0.17, 0.50)]
AERIAL = [(0.09, 0.28), (0.09, 0.28), (0.10, 0.30), (0.16, 0.50)]
HEAVY = (0.40, 0.75)
LAUNCHER = (0.15, 0.45)
COUNTER = (0.05, 0.42)
EXECUTION = (0.95, 1.55)
RECOVER = 0.22  # tempo extra para voltar à guarda (encadeia o próximo golpe)


def ease(style="CubicV2", direction="Out"):
    return {"style": style, "direction": direction}


def merge(*dicts):
    out_ = {}
    for d in dicts:
        for k, v in d.items():
            out_[k] = v
    return out_


def key(time, joints, easing=None, name=None, markers=None):
    k = {"time": round(time, 4), "joints": joints}
    if easing:
        k["easing"] = easing
    if name:
        k["name"] = name
    if name == "WindUp" and not markers:
        markers = ["Swing"]  # som do corte começa no preparo (nome de quadro não dispara evento)
    if markers:
        k["markers"] = [{"name": m} for m in markers]
    return k


def fill_first(keyframes, defaults):
    """O compilador exige que toda junta chaveada depois também esteja no 1º quadro."""
    used = set()
    for k in keyframes[1:]:
        used.update(k["joints"].keys())
    first = keyframes[0]["joints"]
    for j in used:
        if j not in first:
            if j in defaults:
                first[j] = defaults[j]
            elif j == "Root":
                first[j] = {"position": [0, 0, 0]}
            elif j.endswith("Elbow") or j.endswith("Knee"):
                first[j] = {"bend": 5}
            elif j.endswith("Shoulder"):
                first[j] = {"aim": [0.08 if j.startswith("Right") else -0.08, -1, 0]}
            else:
                first[j] = {"rotation": [0, 0, 0]}


def clip(name, keyframes, loop=False, priority="Action", flags=None, easing=None, waive=None, defaults=None):
    keyframes = json.loads(json.dumps(keyframes))  # cópia profunda (poses são reutilizadas)
    fill_first(keyframes, defaults if defaults is not None else GUARD)
    data = {"name": name, "rig": "R15", "loop": loop, "priority": priority, "keyframes": keyframes}
    if easing:
        data["easing"] = easing
    with open(os.path.join(out, name + ".json"), "w") as f:
        json.dump(data, f, indent=1)
    manifest[name] = {"flags": flags or [], "waive": waive or []}


# ---------------------------------------------------------------- posturas base
def feet(width=0.62, front=0.45, back=-0.45, drop=-0.25, right_front=True):
    """Pés plantados (base de luta). Base abaixada em `drop` studs."""
    r = [width, -2.93, front if right_front else back]
    l = [-width, -2.93, back if right_front else front]
    return {"Root": {"position": [0, drop, 0]}, "RightHip": {"aimAt": r}, "LeftHip": {"aimAt": l}}


def root(drop, forward=0.0, yaw=0.0, pitch=0.0, side=0.0):
    return {"Root": {"position": [side, drop, -forward], "rotation": [pitch, yaw, 0]}}


# ---------------------------------------------------------------- mira de lâmina (weapon_aim.py, com cache)
import sys as _sys
_sys.path.insert(0, here)
_cache_path = os.path.join(out, "aim_cache.json")
_aim_cache = json.load(open(_cache_path)) if os.path.exists(_cache_path) else {}


def blade(pose, target):
    """Define Weapon.rotation para a lâmina apontar para `target` [direita, cima, frente] nesta pose."""
    import weapon_aim
    relevant = {k: pose[k] for k in ("Root", "Waist", "RightShoulder", "RightElbow", "RightWrist") if k in pose}
    relevant.setdefault("Neck", {"rotation": [0, 0, 0]})
    cache_key = json.dumps([relevant, target], sort_keys=True)
    if cache_key not in _aim_cache:
        rot, dot = weapon_aim.solve(relevant, target)
        _aim_cache[cache_key] = rot
        print(f"  mira {target} → {rot} (alinhamento {dot:.3f})")
        json.dump(_aim_cache, open(_cache_path, "w"))
    result = dict(pose)
    result["Weapon"] = {"rotation": _aim_cache[cache_key]}
    return result


STANCE = feet()
NEUTRAL_LEGS = {"Root": {"position": [0, 0, 0], "rotation": [0, 0, 0]},
                "RightHip": {"aimAt": [0.5, -2.93, 0]}, "LeftHip": {"aimAt": [-0.5, -2.93, 0]}}

GUARD_ARMS = {
    "Waist": {"rotation": [0, -12, 0]},
    "Neck": {"rotation": [0, 10, 0]},
    "RightShoulder": {"aim": [0.35, -0.45, 0.8]},
    "RightElbow": {"bend": 65},
    "Weapon": {"rotation": [0, 0, 0]},
    "LeftShoulder": {"aim": [-0.25, -0.75, 0.45]},
    "LeftElbow": {"bend": 75},
}
GUARD = blade(merge(STANCE, GUARD_ARMS), [-0.15, 0.8, 0.55])
GUARD_ARMS = {k: v for k, v in GUARD.items() if k not in STANCE}


def arm(aim, bend, weapon=None, toward=None, side="Right"):
    j = {f"{side}Shoulder": {"aim": aim}, f"{side}Elbow": {"bend": bend}}
    if toward:
        j[f"{side}Shoulder"]["bendToward"] = toward
    if weapon is not None:
        j["Weapon" if side == "Right" else "OffHand"] = {"rotation": weapon}
    return j


def waist(yaw=0, pitch=0, roll=0):
    return {"Waist": {"rotation": [pitch, yaw, roll]}}


def neck(yaw=0, pitch=0):
    return {"Neck": {"rotation": [pitch, yaw, 0]}}


def left(aim, bend, toward=None):
    j = {"LeftShoulder": {"aim": aim}, "LeftElbow": {"bend": bend}}
    if toward:
        j["LeftShoulder"]["bendToward"] = toward
    return j


# ---------------------------------------------------------------- golpes leves
# Poses de fim de cada golpe = começo do próximo (o combo flui sem voltar ao zero).
S1_END = merge(STANCE, waist(25), neck(-15), arm([-0.7, -0.25, 0.6], 30, [-60, 0, 0]), left([-0.3, -0.8, -0.2], 25))
S2_END = merge(STANCE, waist(-25), neck(15), arm([0.8, 0.1, 0.35], 30, [-60, 0, 0]), left([-0.35, -0.7, 0.4], 60))
S3_END = merge(feet(drop=-0.4), waist(22, -10), arm([-0.4, -0.65, 0.6], 20, [-70, 0, 0]), left([-0.4, -0.7, 0.2], 45))
S4_END = merge(feet(drop=-0.45), waist(10, -5), arm([0.1, -0.05, 1], 10, [-90, 0, 0]), left([-0.6, -0.6, -0.4], 20))


def light(name, w, d, start, windup, hit, follow, end_pose, windup_at=0.5, extra_keys=None, waive=None):
    """Golpe leve: preparo (linear, rápido) → impacto exatamente em `w` → seguimento → pose final
    (= início do próximo golpe) → guarda. Segmentos rápidos lineares evitam picos de velocidade."""
    keys = [key(0, start, ease("Linear", "In"))]
    if windup is not None:
        keys.append(key(w * windup_at, windup, ease("Linear", "In"), name="WindUp"))
    for k in extra_keys or []:
        keys.append(k)
    keys += [
        key(w, hit, ease("Linear", "In"), name="Hit", markers=["Hit"]),
        key(w + (d - w) * 0.45, follow, ease("CubicV2", "Out")),
        key(d, end_pose, ease("CubicV2", "InOut")),
        key(d + RECOVER, GUARD),
    ]
    clip(name, keys, flags=["--grounded"], waive=waive)


w, d = LIGHT[0]
light("Slash1", w, d, GUARD,
      merge(STANCE, waist(-28), neck(20), arm([0.95, 0.1, 0.1], 35, [-90, 0, 0]), left([-0.3, -0.6, 0.6], 60)),
      merge(STANCE, waist(8), neck(0), arm([0.15, 0.05, 1], 5, [-90, 0, 0]), left([-0.3, -0.75, 0.3], 40)),
      merge(STANCE, waist(32), neck(-15), arm([-0.8, -0.05, 0.55], 15, [-80, 0, 0]), left([-0.3, -0.8, -0.2], 25)),
      S1_END)

w, d = LIGHT[1]
light("Slash2", w, d, S1_END,
      merge(STANCE, waist(34), neck(-18), arm([-0.8, 0.05, 0.5], 25, [-90, 0, 0]), left([-0.3, -0.8, -0.3], 20)),
      merge(STANCE, waist(0), neck(0), arm([0.1, 0.15, 1], 5, [-90, 0, 0]), left([-0.35, -0.7, 0.4], 50)),
      merge(STANCE, waist(-32), neck(15), arm([0.9, 0.25, 0.3], 15, [-80, 0, 0]), left([-0.35, -0.7, 0.45], 60)),
      S2_END, windup_at=0.35)

w, d = LIGHT[2]
light("Slash3", w, d, S2_END,
      merge(feet(drop=-0.2), waist(-20, 5), neck(10, 5), arm([0.4, 1, 0.15], 60, [0, 0, 0], toward=[0, 0, -1]), left([-0.4, -0.5, 0.5], 70)),
      merge(feet(drop=-0.42), waist(10, -12), arm([0.1, 0.05, 1], 8, [-95, 0, 0], toward=[0, 1, 0]), left([-0.4, -0.7, 0.3], 45)),
      merge(feet(drop=-0.42), waist(25, -12), arm([-0.45, -0.6, 0.65], 15, [-70, 0, 0], toward=[0, 1, 0.3]), left([-0.4, -0.75, 0.15], 40)),
      S3_END, windup_at=0.55,
      extra_keys=[])

w, d = LIGHT[3]
light("Slash4", w, d, S3_END,
      merge(feet(drop=-0.35), root(-0.35, -0.2, 0), waist(-35), arm([0.55, -0.35, -0.45], 95, [-90, 0, 0]), left([-0.2, -0.3, 0.9], 15)),
      merge(feet(drop=-0.45), root(-0.45, 0.45, 0), waist(15, -5), arm([0.05, 0.05, 1], 0, [-90, 0, 0]), left([-0.6, -0.6, -0.4], 15)),
      merge(feet(drop=-0.45), root(-0.45, 0.5, 0), waist(15, -5), arm([0.08, 0.0, 1], 5, [-90, 0, 0]), left([-0.6, -0.6, -0.4], 20)),
      S4_END)

w, d = LIGHT[4]
# Finalizador: as duas mãos sobem juntas acima da cabeça e descem num golpe vertical.
s5_windup = merge(feet(drop=-0.1), waist(-5, 12), neck(0, 15), arm([0.15, 1, -0.05], 45, [0, 0, 0], toward=[0, 0, -1]),
                  left([-0.15, 1, -0.05], 50, toward=[0, 0, -1]))
s5_over = merge(feet(drop=-0.3), waist(0, 0), arm([0.08, 0.75, 0.65], 15, [-60, 0, 0], toward=[0, 1, 0]),
                left([-0.08, 0.75, 0.65], 25, toward=[0, 1, 0]))
s5_hit = merge(feet(drop=-0.65), root(-0.65, 0.3, 0, -8), waist(0, -18), neck(0, -10),
               arm([0.05, 0.05, 1], 5, [-90, 0, 0], toward=[0, 1, 0]), left([-0.05, 0.05, 1], 15, toward=[0, 1, 0]))
s5_follow = merge(feet(drop=-0.7), root(-0.7, 0.35, 0, -10), waist(0, -26), arm([0.05, -0.55, 0.85], 8, [-80, 0, 0], toward=[0, 1, 0]),
                  left([-0.05, -0.5, 0.85], 15, toward=[0, 1, 0]))
clip("Slash5", [
    key(0, S4_END, ease("Linear", "In")),
    key(w * 0.55, s5_windup, ease("Linear", "In"), name="WindUp"),
    key(w * 0.8, s5_over, ease("Linear", "In")),
    key(w, s5_hit, ease("Linear", "In"), name="Hit", markers=["Hit"]),
    key(w + 0.12, s5_follow, ease("CubicV2", "Out")),
    key(d, merge(feet(drop=-0.5), waist(10, -10), arm([0.2, -0.6, 0.75], 30, [-50, 0, 0]), left([-0.4, -0.7, 0.3], 40)), ease("CubicV2", "InOut")),
    key(d + 0.3, GUARD),
], flags=["--grounded"])


# ---------------------------------------------------------------- posturas com espada (só tronco/braços:
# as pernas continuam no Animate padrão do Roblox, que anda/corre/pula)
UPPER_GUARD = merge(GUARD_ARMS, waist(-12, -2))
clip("SwordIdle", [
    key(0, UPPER_GUARD),
    key(1.2, merge(GUARD_ARMS, waist(-12, -4), arm([0.35, -0.42, 0.8], 68, [0, 0, 0]), left([-0.25, -0.72, 0.45], 78))),
    key(2.4, UPPER_GUARD),
], loop=True, priority="Idle", easing=ease("CubicV2", "InOut"), defaults=UPPER_GUARD)

RUN_ARMS = blade(merge(waist(0, -14), neck(0, 8), arm([0.3, -0.75, -0.55], 15), left([-0.15, -0.6, 0.6], 80)), [0.15, -0.25, -1])
clip("SwordRun", [key(0, RUN_ARMS), key(0.34, merge(RUN_ARMS, left([-0.15, -0.75, 0.35], 70))), key(0.68, RUN_ARMS)],
     loop=True, priority="Movement", easing=ease("CubicV2", "InOut"), defaults=RUN_ARMS)

BLOCK = blade(merge(feet(drop=-0.35), waist(-8, -4), neck(0, -6), arm([0.4, 0.45, 0.8], 95), left([-0.45, 0.35, 0.8], 100)), [-1, 0.2, 0.1])
clip("Block", [key(0, BLOCK), key(0.5, merge(BLOCK, feet(drop=-0.38))), key(1, BLOCK)], loop=True,
     easing=ease("CubicV2", "InOut"), flags=["--grounded"], defaults=BLOCK)
clip("BlockHit", [
    key(0, BLOCK, ease("Linear", "In")),
    key(0.06, merge(BLOCK, root(-0.45, -0.35, 0, 6), waist(-8, 6)), ease("CubicV2", "Out")),
    key(0.25, BLOCK),
], flags=["--grounded"], defaults=BLOCK)

# Saque: mão direita vai ao cabo no quadril esquerdo, puxa a lâmina num arco e para na guarda.
DRAW_GRAB = blade(merge(waist(18), neck(-10), arm([-0.55, -0.85, 0.35], 95), left([-0.35, -0.9, 0.1], 30)), [-0.25, -0.45, -1])
DRAW_OUT = merge(waist(-25), neck(15), arm([0.9, 0.35, 0.3], 10, [-90, 0, 0]), left([-0.3, -0.9, 0], 20))
clip("Draw", [
    key(0, merge(waist(0), arm([0.1, -1, 0], 5, [0, 0, 0]), left([-0.1, -1, 0], 5)), ease("CubicV2", "Out")),
    key(0.15, DRAW_GRAB, ease("Linear", "In"), name="Grab"),
    key(0.28, DRAW_OUT, ease("CubicV2", "Out"), name="Unsheathe", markers=["Draw"]),
    key(0.5, UPPER_GUARD),
], priority="Action", defaults=UPPER_GUARD)
clip("Sheathe", [
    key(0, UPPER_GUARD, ease("CubicV2", "InOut")),
    key(0.2, merge(waist(-20), arm([0.85, 0.2, 0.4], 20, [-90, 0, 0])), ease("Linear", "In")),
    key(0.38, DRAW_GRAB, ease("CubicV2", "Out"), markers=["Sheathe"]),
    key(0.6, merge(waist(0), arm([0.1, -1, 0], 5, [0, 0, 0]), left([-0.1, -1, 0], 5))),
], priority="Action", defaults=UPPER_GUARD)

# Carregar Reiatsu: base larga e baixa, punhos abertos para os lados, peito para cima.
CHARGE_A = merge(feet(width=0.9, front=0.2, back=-0.2, drop=-0.75), waist(0, -8), neck(0, -12),
                 arm([0.75, -0.7, 0.15], 35, [-30, 0, 0]), left([-0.75, -0.7, 0.15], 35))
CHARGE_B = merge(feet(width=0.9, front=0.2, back=-0.2, drop=-0.8), waist(0, -4), neck(0, -6),
                 arm([0.8, -0.65, 0.12], 40, [-30, 0, 0]), left([-0.8, -0.65, 0.12], 40))
clip("Charge", [key(0, CHARGE_A), key(0.4, CHARGE_B), key(0.8, CHARGE_A)], loop=True,
     easing=ease("CubicV2", "InOut"), flags=["--grounded"], defaults=CHARGE_A)

# Dash: inclinação forte para frente, braços para trás (estilo shunpo), pernas recolhidas.
DASH = merge(waist(0, -28), neck(0, 18), arm([0.3, -0.6, -0.75], 10, [-100, 0, 0]), left([-0.3, -0.6, -0.75], 10),
             {"RightHip": {"aim": [0.1, -0.85, 0.45]}, "RightKnee": {"bend": 70}, "LeftHip": {"aim": [-0.1, -0.9, -0.35]}, "LeftKnee": {"bend": 40}})
clip("Dash", [
    key(0, merge(UPPER_GUARD, {"RightHip": {"aim": [0.1, -1, 0]}, "RightKnee": {"bend": 5}, "LeftHip": {"aim": [-0.1, -1, 0]}, "LeftKnee": {"bend": 5}}), ease("Linear", "In")),
    key(0.06, DASH, ease("CubicV2", "InOut")),
    key(0.32, merge(DASH, waist(0, -18))),
], priority="Action", defaults=UPPER_GUARD)
TUCK = {"RightHip": {"aim": [0.15, -0.6, 0.75]}, "RightKnee": {"bend": 110}, "LeftHip": {"aim": [-0.15, -0.75, 0.55]}, "LeftKnee": {"bend": 95}}
clip("AirStep", [
    key(0, merge(UPPER_GUARD, {"RightHip": {"aim": [0.1, -1, 0]}, "RightKnee": {"bend": 5}, "LeftHip": {"aim": [-0.1, -1, 0]}, "LeftKnee": {"bend": 5}}), ease("CubicV2", "Out")),
    key(0.12, merge(UPPER_GUARD, TUCK, waist(0, 10)), ease("CubicV2", "InOut")),
    key(0.45, merge(UPPER_GUARD, {"RightHip": {"aim": [0.1, -0.95, 0.3]}, "RightKnee": {"bend": 35}, "LeftHip": {"aim": [-0.1, -1, 0.1]}, "LeftKnee": {"bend": 20}})),
], priority="Action", defaults=UPPER_GUARD)

# ---------------------------------------------------------------- combo aéreo (pernas recolhidas)
AIR_LEGS = {"RightHip": {"aim": [0.15, -0.7, 0.6]}, "RightKnee": {"bend": 90}, "LeftHip": {"aim": [-0.15, -0.85, 0.35]}, "LeftKnee": {"bend": 70}}
AIR_GUARD = merge(GUARD_ARMS, AIR_LEGS)


def aerial(name, w, d, start, windup, hit, follow, end_pose, windup_at=0.5):
    clip(name, [
        key(0, merge(AIR_LEGS, start), ease("Linear", "In")),
        key(w * windup_at, merge(AIR_LEGS, windup), ease("Linear", "In"), name="WindUp"),
        key(w, merge(AIR_LEGS, hit), ease("Linear", "In"), name="Hit", markers=["Hit"]),
        key(w + (d - w) * 0.45, merge(AIR_LEGS, follow), ease("CubicV2", "Out")),
        key(d, merge(AIR_LEGS, end_pose), ease("CubicV2", "InOut")),
        key(d + RECOVER, AIR_GUARD),
    ], defaults=AIR_GUARD)


A1_END = merge(waist(28), arm([-0.7, -0.2, 0.6], 25, [-60, 0, 0]), left([-0.3, -0.8, -0.2], 25))
A2_END = merge(waist(-25), arm([0.8, 0.15, 0.35], 25, [-60, 0, 0]), left([-0.35, -0.7, 0.4], 60))
A3_END = merge(waist(-10, 12), neck(0, 15), arm([0.2, 0.9, 0.3], 25, [-80, 0, 0], toward=[0, 1, 0]), left([-0.3, -0.5, 0.5], 60))
w, d = AERIAL[0]
aerial("Air1", w, d, GUARD_ARMS, merge(waist(-28), arm([0.95, 0.1, 0.1], 35, [-90, 0, 0])),
       merge(waist(8), arm([0.15, 0.05, 1], 5, [-90, 0, 0])), merge(waist(32), arm([-0.8, -0.05, 0.55], 15, [-80, 0, 0])), A1_END)
w, d = AERIAL[1]
aerial("Air2", w, d, A1_END, merge(waist(34), arm([-0.8, 0.05, 0.5], 25, [-90, 0, 0])),
       merge(waist(0), arm([0.1, 0.15, 1], 5, [-90, 0, 0])), merge(waist(-32), arm([0.9, 0.25, 0.3], 15, [-80, 0, 0])), A2_END, windup_at=0.35)
w, d = AERIAL[2]
aerial("Air3", w, d, A2_END, merge(waist(-15, -8), arm([0.5, -0.75, 0.4], 30, [-90, 0, 0])),
       merge(waist(0, 5), arm([0.15, 0.25, 1], 5, [-90, 0, 0], toward=[0, 1, 0])),
       merge(waist(-8, 12), arm([0.2, 0.85, 0.45], 15, [-85, 0, 0], toward=[0, 1, 0])), A3_END)
# Air4: martelada para baixo com as duas mãos (crava o alvo no chão)
w, d = AERIAL[3]
clip("Air4", [
    key(0, merge(AIR_LEGS, A3_END), ease("Linear", "In")),
    key(w * 0.5, merge(AIR_LEGS, waist(-5, 18), arm([0.15, 1, -0.05], 45, [0, 0, 0], toward=[0, 0, -1]), left([-0.15, 1, -0.05], 50, toward=[0, 0, -1])), ease("Linear", "In"), name="WindUp"),
    key(w * 0.8, merge(AIR_LEGS, waist(0, 0), arm([0.08, 0.75, 0.65], 15, [-60, 0, 0], toward=[0, 1, 0]), left([-0.08, 0.75, 0.65], 25, toward=[0, 1, 0])), ease("Linear", "In")),
    key(w, merge(AIR_LEGS, waist(0, -30), arm([0.05, -0.2, 1], 5, [-90, 0, 0], toward=[0, 1, 0]), left([-0.05, -0.2, 1], 15, toward=[0, 1, 0])), ease("Linear", "In"), name="Hit", markers=["Hit"]),
    key(w + 0.12, merge(AIR_LEGS, waist(0, -32), arm([0.05, -0.6, 0.8], 8, [-80, 0, 0], toward=[0, 1, 0]), left([-0.05, -0.6, 0.8], 15, toward=[0, 1, 0])), ease("CubicV2", "Out")),
    key(d, merge(AIR_LEGS, waist(0, -10), arm([0.2, -0.6, 0.75], 30, [-50, 0, 0]), left([-0.4, -0.7, 0.3], 40)), ease("CubicV2", "InOut")),
    key(d + 0.25, AIR_GUARD),
], defaults=AIR_GUARD)

# ---------------------------------------------------------------- pesado, lançador, contra, execução
w, d = HEAVY
HV_COIL = merge(feet(drop=-0.6), root(-0.6, -0.15, -20), waist(-45, 0), neck(35),
                arm([0.85, -0.35, -0.45], 25, [-90, 0, 0]), left([0.35, -0.6, 0.4], 70))
HV_HIT = merge(feet(drop=-0.55), root(-0.55, 0.35, 15), waist(30, -8), neck(-20),
               arm([-0.15, 0.0, 1], 5, [-90, 0, 0]), left([-0.6, -0.5, -0.4], 20))
HV_FOLLOW = merge(feet(drop=-0.55), root(-0.55, 0.4, 25), waist(45, -8), neck(-30),
                  arm([-0.85, -0.1, 0.4], 12, [-85, 0, 0]), left([-0.5, -0.7, -0.5], 20))
clip("HeavySlash", [
    key(0, GUARD, ease("CubicV2", "Out")),
    key(w * 0.7, HV_COIL, ease("CubicV2", "In"), name="WindUp"),
    key(w * 0.8, merge(HV_COIL, waist(-25, 0), arm([0.75, -0.2, 0.55], 12, [-90, 0, 0])), ease("Linear", "In")),
    key(w, HV_HIT, ease("Linear", "In"), name="Hit", markers=["Hit"]),
    key(w + 0.12, HV_FOLLOW, ease("CubicV2", "Out")),
    key(d, merge(HV_FOLLOW, waist(30, -4)), ease("CubicV2", "InOut")),
    key(d + 0.3, GUARD),
], flags=["--grounded"])

w, d = LAUNCHER
UP_LOW = merge(feet(width=0.6, front=0.35, back=-0.35, drop=-0.85), root(-0.85, 0.1, -10), waist(-20, -15), neck(0, 10),
               arm([0.45, -0.85, -0.15], 15, [-90, 0, 0]), left([-0.3, -0.5, 0.6], 70))
UP_HIT = merge(feet(width=0.6, front=0.35, back=-0.35, drop=-0.25), root(-0.15, 0.2, 5), waist(5, 8), neck(0, 20),
               arm([0.15, 0.6, 0.8], 5, [-90, 0, 0], toward=[0, 1, 0]), left([-0.45, -0.6, -0.3], 20))
UP_FOLLOW = merge(feet(width=0.6, front=0.35, back=-0.35, drop=-0.2), waist(8, 12), neck(0, 25), arm([0.1, 1, 0.25], 10, [-90, 0, 0], toward=[0, 1, 0]), left([-0.45, -0.6, -0.3], 20))
clip("Uppercut", [
    key(0, GUARD, ease("Linear", "In")),
    key(w * 0.6, UP_LOW, ease("Linear", "In"), name="WindUp"),
    key(w, UP_HIT, ease("Linear", "In"), name="Hit", markers=["Hit"]),
    key(w + 0.12, UP_FOLLOW, ease("CubicV2", "Out")),
    key(d, merge(UP_FOLLOW, arm([0.3, 0.4, 0.75], 40, [-45, 0, 0])), ease("CubicV2", "InOut")),
    key(d + RECOVER, GUARD),
], flags=["--grounded"])

w, d = COUNTER
PARRY_POSE = merge(feet(drop=-0.35), waist(-30), neck(25), arm([0.85, 0.3, 0.35], 25, [-90, 0, 0]), left([-0.3, -0.5, 0.6], 60))
CT_HIT = merge(feet(drop=-0.55), root(-0.55, 0.4, 20), waist(30, -6), neck(-20), arm([-0.4, 0.0, 1], 5, [-90, 0, 0]), left([-0.55, -0.55, -0.4], 20))
clip("Counter", [
    key(0, PARRY_POSE, ease("Linear", "In")),
    key(w, CT_HIT, ease("Linear", "In"), name="Hit", markers=["Hit"]),
    key(w + 0.1, merge(CT_HIT, waist(45, -6), arm([-0.85, -0.1, 0.4], 12, [-85, 0, 0])), ease("CubicV2", "Out")),
    key(d, merge(CT_HIT, waist(25, -4), arm([-0.6, -0.4, 0.6], 30, [-60, 0, 0])), ease("CubicV2", "InOut")),
    key(d + RECOVER, GUARD),
], flags=["--grounded"], waive=["velocity"])  # contra-ataque: 0,05 s de preparo → estalo intencional

# Execução (iaidō): mão no cabo junto ao quadril, pausa dramática, corte que atravessa, pose final.
w, d = EXECUTION
IAI_READY = blade(merge(feet(width=0.8, front=0.6, back=-0.5, drop=-0.7), root(-0.7, -0.1, -15), waist(-15, -6), neck(15, -4),
                        arm([-0.45, -0.75, 0.5], 100), left([-0.45, -0.85, 0.2], 40)), [-0.3, -0.35, -1])
IAI_CUT = merge(feet(width=0.8, front=0.6, back=-0.5, drop=-0.8), root(-0.75, 0.5, 15, -8), waist(30, -10), neck(-25),
                arm([0.95, 0.05, -0.3], 5, [-90, 0, 0]), left([-0.5, -0.6, 0.5], 40))
IAI_END = merge(feet(width=0.8, front=0.6, back=-0.5, drop=-0.8), root(-0.75, 0.5, 15, -8), waist(30, -10), neck(-25),
                arm([0.9, -0.25, -0.35], 10, [-90, 0, 0]), left([-0.5, -0.6, 0.5], 40))
clip("Execution", [
    key(0, GUARD, ease("CubicV2", "Out")),
    key(0.3, IAI_READY, ease("CubicV2", "InOut"), name="Ready"),
    key(w * 0.9, merge(IAI_READY, root(-0.8, -0.15, -18)), ease("Linear", "In")),
    key(w, IAI_CUT, ease("CubicV2", "Out"), name="Hit", markers=["Hit"]),
    key(w + 0.4, IAI_END, ease("CubicV2", "InOut")),
    key(d, merge(IAI_END, arm([0.6, -0.6, 0.4], 40, [-45, 0, 0])), ease("CubicV2", "InOut")),
    key(d + 0.4, merge(GUARD, feet(width=0.8, front=0.6, back=-0.5, drop=-0.35))),
], flags=["--grounded"])

# ---------------------------------------------------------------- reações
def reaction(name, peak, duration, at=0.06, priority="Action", flags=("--grounded",), defaults=None, hold=0.55):
    clip(name, [
        key(0, GUARD, ease("Linear", "In")),
        key(at, peak, ease("CubicV2", "Out"), name="Impact"),
        key(duration * hold, peak, ease("CubicV2", "InOut")),
        key(duration, GUARD),
    ], priority=priority, flags=list(flags), defaults=defaults)


reaction("Hit1", merge(feet(drop=-0.3), root(-0.3, -0.25, 0, 8), waist(8, 12), neck(0, 18), arm([0.6, -0.5, 0.4], 50, [-30, 0, 0]), left([-0.6, -0.5, 0.3], 50)), 0.42)
reaction("Hit2", merge(feet(drop=-0.3), root(-0.3, -0.25, -12, 5), waist(-15, 8, 6), neck(-12, 12), arm([0.75, -0.3, 0.2], 35, [-30, 0, 0]), left([-0.35, -0.7, 0.5], 60)), 0.42)
reaction("Stagger", merge(feet(width=0.75, front=0.2, back=-0.75, drop=-0.45), root(-0.45, -0.55, 8, 14), waist(0, 18), neck(0, 22),
                          arm([0.85, -0.1, 0.35], 25, [-45, 0, 0]), left([-0.85, -0.1, 0.35], 25)), 0.8)
reaction("GuardBreak", merge(feet(width=0.75, front=0.2, back=-0.75, drop=-0.35), root(-0.35, -0.5, 0, 12), waist(0, 20), neck(0, 25),
                             arm([0.55, 0.85, 0.2], 15, [0, 0, 0]), left([-0.55, 0.85, 0.2], 15)), 1.0, hold=0.7)
reaction("Parried", merge(feet(drop=-0.3), root(-0.3, -0.45, 10, 10), waist(15, 15), neck(0, 18), arm([0.6, 0.85, -0.25], 20, [-80, 0, 0], toward=[0, 0, -1]),
                          left([-0.6, -0.4, 0.4], 40)), 0.85, at=0.09, hold=0.65)
clip("ParrySuccess", [
    key(0, BLOCK, ease("Linear", "In")),
    key(0.07, PARRY_POSE, ease("CubicV2", "Out"), name="Deflect"),
    key(0.4, merge(PARRY_POSE, waist(-15))),
], flags=["--grounded"], defaults=BLOCK)
# Lançado ao ar: corpo arqueado, membros soltos (sem pés no chão)
clip("Launched", [
    key(0, UPPER_GUARD, ease("CubicV2", "Out")),
    key(0.12, merge(waist(0, 25), neck(0, 30), arm([0.85, 0.3, -0.2], 30, [-30, 0, 0]), left([-0.85, 0.3, -0.2], 30),
                    {"RightHip": {"aim": [0.2, -0.8, 0.5]}, "RightKnee": {"bend": 80}, "LeftHip": {"aim": [-0.2, -0.9, 0.25]}, "LeftKnee": {"bend": 50}}), ease("CubicV2", "InOut")),
    key(0.9, merge(waist(0, 15), neck(0, 15), arm([0.75, -0.2, 0.1], 40, [-30, 0, 0]), left([-0.75, -0.2, 0.1], 40),
                   {"RightHip": {"aim": [0.2, -0.9, 0.3]}, "RightKnee": {"bend": 45}, "LeftHip": {"aim": [-0.2, -0.95, 0.15]}, "LeftKnee": {"bend": 30}})),
    key(1.15, merge(UPPER_GUARD, {"RightHip": {"aim": [0.1, -1, 0]}, "RightKnee": {"bend": 5}, "LeftHip": {"aim": [-0.1, -1, 0]}, "LeftKnee": {"bend": 5}})),
], defaults=UPPER_GUARD)

# ---------------------------------------------------------------- conjurações (marcador "Release"; o cliente
# reescala a velocidade para que "Release" caia no `windup` de cada habilidade)
def cast(name, release, anticipation, pose, hold=0.4, flags=("--grounded",)):
    clip(name, [
        key(0, GUARD, ease("CubicV2", "Out")),
        key(release * 0.75, anticipation, ease("Linear", "In"), name="Charge"),
        key(release, pose, ease("CubicV2", "Out"), name="Release", markers=["Release"]),
        key(release + hold, pose, ease("CubicV2", "InOut")),
        key(release + hold + 0.25, GUARD),
    ], flags=list(flags))


cast("CastPoint", 0.25,
     merge(feet(drop=-0.3), waist(-25), neck(25), arm([0.35, -0.7, -0.3], 30, [-90, 0, 0]), left([-0.1, -0.2, 0.7], 110)),
     merge(feet(drop=-0.4), root(-0.4, 0.2, 25), waist(25), neck(-25), arm([0.45, -0.6, -0.4], 20, [-90, 0, 0]), left([-0.05, 0.05, 1], 0)))
cast("CastSlash", 0.25,
     merge(feet(drop=-0.25), waist(-20, 5), arm([0.4, 1, 0.15], 60, [0, 0, 0], toward=[0, 0, -1]), left([-0.4, -0.5, 0.5], 70)),
     merge(feet(drop=-0.6), root(-0.6, 0.35, 0, -6), waist(25, -15), arm([-0.45, -0.6, 0.65], 10, [-80, 0, 0], toward=[0, 1, 0.3]), left([-0.45, -0.7, -0.2], 25)))
cast("CastOverhead", 0.3,
     merge(feet(drop=-0.1), waist(0, 15), neck(0, 20), arm([0.2, 1, 0], 25, [-90, 0, 0], toward=[0, 0, -1]), left([-0.2, 1, 0], 25, toward=[0, 0, -1])),
     merge(feet(width=0.8, drop=-0.75), root(-0.75, 0.2, 0, -6), waist(0, -35), neck(0, -10),
           arm([0.15, -0.75, 0.6], 10, [-90, 0, 0], toward=[0, 1, 0]), left([-0.15, -0.75, 0.6], 10, toward=[0, 1, 0])))
cast("CastBurst", 0.3,
     merge(feet(width=0.75, drop=-0.65), waist(0, -22), neck(0, -25), arm([-0.35, -0.2, 0.8], 120, [-90, 0, 0]), left([0.35, -0.2, 0.8], 120)),
     merge(feet(width=0.85, drop=-0.35), waist(0, 12), neck(0, 22), arm([1, 0.35, 0.1], 5, [-90, 0, 0]), left([-1, 0.35, 0.1], 5)))
cast("CastCharge", 0.45,
     merge(feet(drop=-0.45), root(-0.45, -0.2, -15), waist(-20), arm([0.1, -0.2, 0.8], 100, [-90, 0, 0]), left([-0.1, -0.2, 0.8], 100)),
     merge(feet(drop=-0.55), root(-0.55, 0.3, 5), waist(5, -6), arm([0.15, 0.05, 1], 0, [-90, 0, 0]), left([-0.15, 0.05, 1], 0)), hold=0.45)
cast("CastBow", 0.25,
     merge(feet(drop=-0.3), root(-0.3, 0, 40), waist(10), neck(-45), left([-0.05, 0.05, 1], 0), arm([0.1, 0.05, 0.9], 120, [-90, 0, 0])),
     merge(feet(drop=-0.3), root(-0.3, 0, 40), waist(10), neck(-45), left([-0.05, 0.05, 1], 0), arm([0.75, 0.1, -0.3], 150, [-90, 0, 0])), hold=0.3)
cast("DashStrikePose", 0.12,
     merge(feet(drop=-0.6), waist(-10, -20), neck(0, 15), arm([0.35, -0.7, -0.5], 20, [-95, 0, 0]), left([-0.3, -0.6, -0.5], 20)),
     merge(feet(width=0.85, front=0.7, back=-0.7, drop=-0.9), root(-0.9, 0.5, 25, -10), waist(30, -15), neck(-25),
           arm([0.95, 0.0, -0.35], 5, [-90, 0, 0]), left([-0.5, -0.65, 0.35], 40)), hold=0.3)
cast("UltimateRaise", 1.0,
     merge(feet(width=0.8, drop=-0.2), waist(0, 15), neck(0, 30), arm([0.05, 1, 0.05], 5, [-90, 0, 0]), left([-0.85, -0.3, 0.3], 30)),
     merge(feet(width=0.9, front=0.55, back=-0.5, drop=-0.78), root(-0.78, 0.35, 0, -8), waist(5, -30), neck(0, -10),
           arm([0.1, -0.35, 0.95], 5, [-90, 0, 0], toward=[0, 1, 0]), left([-0.85, -0.2, 0.3], 30)), hold=0.8)

# ---------------------------------------------------------------- transformações
REL1_HOLD = merge(feet(drop=-0.3), waist(0, -10), neck(0, -10), arm([0.15, -0.1, 0.9], 85, [0, 0, 0]), left([-0.1, -0.05, 0.9], 95))
clip("ReleaseTier1", [
    key(0, GUARD, ease("CubicV2", "Out")),
    key(0.25, REL1_HOLD, ease("CubicV2", "InOut"), name="Command"),
    key(0.7, merge(REL1_HOLD, neck(0, -14)), ease("Linear", "In")),
    key(0.9, merge(feet(drop=-0.5), root(-0.5, 0.2, 20), waist(25, -8), arm([0.95, 0.1, -0.25], 5, [-90, 0, 0]), left([-0.5, -0.6, 0.4], 40)),
        ease("CubicV2", "Out"), name="Release", markers=["Release"]),
    key(1.4, GUARD),
], flags=["--grounded"])
REL2_KNEEL = merge(feet(width=0.8, front=0.6, back=-0.4, drop=-0.95), waist(0, -25), neck(0, -25),
                   arm([0.1, -0.75, 0.6], 40, [-30, 0, 0]), left([-0.1, -0.75, 0.6], 40))
REL2_RISE = merge(feet(width=0.85, drop=-0.15), waist(0, 15), neck(0, 30), arm([1, 0.4, 0.1], 5, [-90, 0, 0]), left([-1, 0.4, 0.1], 5))
clip("ReleaseTier2", [
    key(0, GUARD, ease("CubicV2", "Out")),
    key(0.35, REL2_KNEEL, ease("CubicV2", "InOut"), name="Kneel"),
    key(1.3, merge(REL2_KNEEL, waist(0, -30)), ease("Linear", "In")),
    key(1.6, REL2_RISE, ease("CubicV2", "Out"), name="Release", markers=["Release"]),
    key(2.0, merge(REL2_RISE, waist(0, 10))),
    key(2.35, GUARD),
], flags=["--grounded"])
MASK_HAND = merge(waist(0, -8), neck(0, -12), left([-0.05, 0.45, 0.8], 135))
clip("MaskOn", [
    key(0, UPPER_GUARD, ease("CubicV2", "Out")),
    key(0.3, merge(UPPER_GUARD, MASK_HAND), ease("Linear", "In"), name="Grab"),
    key(0.5, merge(UPPER_GUARD, MASK_HAND, neck(0, -16)), ease("Linear", "In")),
    key(0.62, merge(UPPER_GUARD, waist(0, 8), neck(0, 12), left([-0.85, -0.35, 0.3], 15)), ease("CubicV2", "Out"), name="Release", markers=["Release"]),
    key(0.95, UPPER_GUARD),
], defaults=UPPER_GUARD)
clip("Revert", [
    key(0, UPPER_GUARD, ease("CubicV2", "Out")),
    key(0.2, merge(waist(0, -18), neck(0, -20), arm([0.3, -0.85, 0.3], 30, [-30, 0, 0]), left([-0.3, -0.85, 0.3], 30)), ease("CubicV2", "InOut")),
    key(0.6, UPPER_GUARD),
], defaults=UPPER_GUARD)

# ---------------------------------------------------------------- NPC (diálogo) e locomoção de NPCs
clip("Wave", [
    key(0, {"RightShoulder": {"aim": [0.08, -1, 0]}, "RightElbow": {"bend": 8}}, ease("CubicV2", "Out")),
    key(0.25, {"RightShoulder": {"aim": [1, 0.3, 0.4], "bendToward": [0, 1, 0]}, "RightElbow": {"bend": 70}}, ease("CubicV2", "InOut")),
    key(0.5, {"RightElbow": {"bend": 115}}, ease("CubicV2", "InOut")),
    key(0.75, {"RightElbow": {"bend": 70}}, ease("CubicV2", "InOut")),
    key(1.0, {"RightElbow": {"bend": 115}}, ease("CubicV2", "InOut")),
    key(1.35, {"RightShoulder": {"aim": [0.08, -1, 0]}, "RightElbow": {"bend": 8}}),
], priority="Action", defaults={})
TALK_A = {"RightShoulder": {"aim": [0.3, -0.75, 0.55]}, "RightElbow": {"bend": 70}, "Neck": {"rotation": [-4, 0, 0]}}
TALK_B = {"RightShoulder": {"aim": [0.45, -0.6, 0.6]}, "RightElbow": {"bend": 55}, "Neck": {"rotation": [2, 6, 0]}}
clip("Talk", [key(0, TALK_A), key(0.8, TALK_B), key(1.6, TALK_A)], loop=True, priority="Action", easing=ease("CubicV2", "InOut"), defaults={})

# Locomoção de NPCs: receitas testadas da skill (Idle/Walk/Run), lidas do próprio arquivo de referência.
import re as _re
_ref = os.path.join(here, "..", "..", "..", ".claude", "skills", "vfxskill", "references", "character-animation.md")
_recipes = {}
for _block in _re.findall(r"```json\n(.*?)\n```", open(_ref, encoding="utf-8").read(), _re.S):
    _d = json.loads(_block)
    _recipes[_d["name"]] = _d
for _src, _dst, _flags, _prio in (("Idle", "NpcIdle", [], "Idle"), ("Walk", "NpcWalk", ["--locomotion"], "Movement"), ("Run", "NpcRun", ["--locomotion"], "Movement")):
    _d = json.loads(json.dumps(_recipes[_src]))
    _d["name"] = _dst
    _d["priority"] = _prio
    with open(os.path.join(out, _dst + ".json"), "w") as f:
        json.dump(_d, f, indent=1)
    manifest[_dst] = {"flags": _flags, "waive": []}

# Sprint: a corrida testada com tempos × 0,45 → velocidade de chão 4,08 / 0,45 ≈ 9,07 studs/s
# (a referência documenta 2,21 para Walk e 4,08 para Run). Só o tempo muda: o contato dos pés
# continua o mesmo, então as checagens de deslize/solo seguem valendo. Tronco mais inclinado.
_d = json.loads(json.dumps(_recipes["Run"]))
_d["name"] = "NpcSprint"
_d["priority"] = "Movement"
for _k in _d["keyframes"]:
    _k["time"] = round(_k["time"] * 0.45, 4)
    _k["joints"]["Waist"] = {"rotation": [-16, 0, 0]}
with open(os.path.join(out, "NpcSprint.json"), "w") as f:
    json.dump(_d, f, indent=1)
manifest["NpcSprint"] = {"flags": ["--locomotion"], "waive": []}
json.dump(_aim_cache, open(_cache_path, "w"))
with open(os.path.join(out, "manifest.json"), "w") as f:
    json.dump(manifest, f, indent=1)
print(len(manifest), "clips autorados")

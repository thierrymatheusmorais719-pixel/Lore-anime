#!/usr/bin/env python3
"""Animações próprias dos Hollows, compiladas e verificadas no corpo de cada criatura
(leitura em tools/creatures/rigs/<Corpo>.json, gerada de CreatureRigs.json por rig_reading.py).
Chamado no fim de tools/anims/author.py; os nomes levam o prefixo do `animSet` do corpo
(HollowSlash1, BruteWalk...) e o AnimController escolhe a versão da criatura pelo atributo AnimSet.

Peso e leitura: preparo grande e lento (antecipação), impacto seco no tempo exato do servidor
(`windup` de Config/Combat), seguimento longo e recuperação. Marcha por `gait` (pés plantados),
cauda por `waves` (onda que percorre a cadeia)."""
import json, os, sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import rig_reading  # noqa: E402

RIGS = os.path.join(here, "rigs")
LIGHT = [(0.10, 0.30), (0.10, 0.30), (0.12, 0.34), (0.11, 0.34), (0.17, 0.50)]
HEAVY = (0.40, 0.75)
LAUNCHER = (0.15, 0.45)


def ease(style="CubicV2", direction="Out"):
    return {"style": style, "direction": direction}


def merge(*dicts):
    out = {}
    for d in dicts:
        out.update(d)
    return out


def key(time, joints, easing=None, name=None, markers=None):
    k = {"time": round(time, 4), "joints": json.loads(json.dumps(joints))}
    if easing:
        k["easing"] = easing
    if name:
        k["name"] = name
    if name == "WindUp" and not markers:
        markers = ["Swing"]
    if markers:
        k["markers"] = [{"name": m} for m in markers]
    return k


class Creature:
    def __init__(self, body, out, manifest):
        self.body = body
        self.out = out
        self.manifest = manifest
        data = json.load(open(rig_reading.SOURCE))[body]
        self.set = data["animSet"]
        os.makedirs(RIGS, exist_ok=True)
        self.rig_path = os.path.join(RIGS, body + ".json")
        json.dump(rig_reading.reading(body), open(self.rig_path, "w"), indent=1)
        frames = rig_reading.rest_frames(data)
        parts = {p["name"]: p for p in data["parts"]}
        ankle = rig_reading.mul(frames["RightLowerLeg"], rig_reading.frame(parts["RightFoot"]["c0"]))[0]
        self.ankle = (ankle[0], ankle[1], -ankle[2])  # [direita, cima, frente]
        self.rig = "game.Workspace." + body
        self.guard = {}

    def feet(self, drop=0.0, width=0.0, front=0.25, back=-0.25):
        x, y, z = self.ankle
        return {"Root": {"position": [0, drop, 0]},
                "RightHip": {"aimAt": [x + width, y, z + front]}, "LeftHip": {"aimAt": [-x - width, y, z + back]}}

    def root(self, drop, forward=0.0, yaw=0.0, pitch=0.0):
        return {"Root": {"position": [0, drop, -forward], "rotation": [pitch, yaw, 0]}}

    def clip(self, name, keyframes, loop=False, priority="Action", flags=("--grounded",), waive=(), extra=None):
        keyframes = json.loads(json.dumps(keyframes))
        first = keyframes[0]["joints"]
        for k in keyframes[1:]:
            for j, v in k["joints"].items():
                if j not in first:
                    first[j] = self.guard.get(j, v)
        full = self.set + name
        data = {"name": full, "rig": self.rig, "loop": loop, "priority": priority, "keyframes": keyframes}
        data.update(extra or {})
        json.dump(data, open(os.path.join(self.out, full + ".json"), "w"), indent=1)
        self.manifest[full] = {"flags": list(flags), "waive": list(waive), "rig": os.path.relpath(self.rig_path, os.path.dirname(self.out))}

    def raw(self, name, data, flags=(), ground_speed=False):
        full = self.set + name
        data = dict(data, name=full, rig=self.rig)
        json.dump(data, open(os.path.join(self.out, full + ".json"), "w"), indent=1)
        self.manifest[full] = {"flags": list(flags), "waive": [], "rig": os.path.relpath(self.rig_path, os.path.dirname(self.out)),
                               "groundSpeedFromReport": ground_speed}


def arms(r_aim, r_bend, l_aim=None, l_bend=None, r_toward=None, l_toward=None):
    j = {"RightShoulder": {"aim": r_aim}, "RightElbow": {"bend": r_bend}}
    if r_toward:
        j["RightShoulder"]["bendToward"] = r_toward
    if l_aim is None:
        l_aim, l_bend = [-r_aim[0], r_aim[1], r_aim[2]], r_bend
    j["LeftShoulder"] = {"aim": l_aim}
    j["LeftElbow"] = {"bend": l_bend}
    if l_toward:
        j["LeftShoulder"]["bendToward"] = l_toward
    return j


def waist(yaw=0, pitch=0, roll=0):
    return {"Waist": {"rotation": [pitch, yaw, roll]}}


def neck(yaw=0, pitch=0, roll=0):
    return {"Neck": {"rotation": [pitch, yaw, roll]}}


def tail(a=0, b=0, c=0, lift=0):
    return {"Tail1": {"rotation": [lift, a, 0]}, "Tail2": {"rotation": [lift * 0.5, b, 0]}, "Tail3": {"rotation": [0, c, 0]}}


# ============================================================================ GRUNT
def grunt(c):
    G = merge(c.feet(drop=-0.15, width=0.12, front=0.35, back=-0.3), waist(0, -4), neck(0, -6),
              arms([0.55, -0.35, 0.75], 55, [-0.55, -0.35, 0.75], 55))
    c.guard = G
    TAIL_WAVE = {"joints": ["Tail1", "Tail2", "Tail3"], "axis": "Y", "amplitude": [8, 22], "lag": 0.18}

    # Respiração de predador: ombros sobem e descem, cabeça varre, cauda serpenteia
    breathe_in = merge(G, waist(4, -8), neck(-10, -10), arms([0.6, -0.3, 0.75], 60, [-0.55, -0.4, 0.7], 50))
    breathe_out = merge(G, c.feet(drop=-0.22, width=0.12, front=0.35, back=-0.3), waist(-3, -2), neck(8, -2),
                        arms([0.55, -0.42, 0.7], 50, [-0.6, -0.32, 0.75], 60))
    c.clip("Idle", [key(0, breathe_in, ease("CubicV2", "InOut")), key(1.1, breathe_out, ease("CubicV2", "InOut")),
                    key(2.2, breathe_in)], loop=True, priority="Idle",
           extra={"waves": [dict(TAIL_WAVE, amplitude=[6, 18], cycles=1)]})
    # Andar à espreita e correr de quatro... em duas: tronco mais baixo, braços em pêndulo
    c.raw("Walk", {"loop": True, "priority": "Movement", "duration": 0.9,
                   "gait": {"pattern": "walk", "stride": 1.5, "lift": 0.35, "bob": 0.12},
                   "keyframes": [key(0, merge(waist(-6, -6), neck(0, -4), arms([0.4, -0.7, 0.45], 35, [-0.4, -0.55, 0.6], 45)), ease("CubicV2", "InOut")),
                                 key(0.45, merge(waist(6, -6), neck(0, -4), arms([0.4, -0.55, 0.6], 45, [-0.4, -0.7, 0.45], 35)), ease("CubicV2", "InOut")),
                                 key(0.9, merge(waist(-6, -6), neck(0, -4), arms([0.4, -0.7, 0.45], 35, [-0.4, -0.55, 0.6], 45)))],
                   "waves": [dict(TAIL_WAVE, cycles=1)]}, flags=["--locomotion"], ground_speed=True)
    c.raw("Run", {"loop": True, "priority": "Movement", "duration": 0.5,
                  "gait": {"pattern": "walk", "stride": 2.6, "duty": 0.38, "lift": 0.6, "bob": 0.22},
                  "keyframes": [key(0, merge(waist(-10, -16), neck(0, 10), arms([0.45, -0.3, -0.75], 25, [-0.4, -0.1, 0.9], 70)), ease("CubicV2", "InOut")),
                                key(0.25, merge(waist(10, -16), neck(0, 10), arms([0.4, -0.1, 0.9], 70, [-0.45, -0.3, -0.75], 25)), ease("CubicV2", "InOut")),
                                key(0.5, merge(waist(-10, -16), neck(0, 10), arms([0.45, -0.3, -0.75], 25, [-0.4, -0.1, 0.9], 70)))],
                  "waves": [dict(TAIL_WAVE, amplitude=[5, 14], cycles=2, axis="X")]}, flags=["--locomotion"], ground_speed=True)

    def light(name, w, d, start, windup, hit, follow, end, windup_at=0.55):
        c.clip(name, [
            key(0, start, ease("Linear", "In")),
            key(w * windup_at, windup, ease("Linear", "In"), name="WindUp"),
            key(w, hit, ease("Linear", "In"), name="Hit", markers=["Hit"]),
            key(w + (d - w) * 0.45, follow, ease("CubicV2", "Out")),
            key(d, end, ease("CubicV2", "InOut")),
            key(d + 0.25, G),
        ])

    stance = c.feet(drop=-0.2, width=0.15, front=0.45, back=-0.35)
    lunge = c.feet(drop=-0.45, width=0.18, front=0.7, back=-0.55)
    # 1: garra direita de fora para dentro
    E1 = merge(stance, waist(30, -6), neck(-20), arms([-0.5, -0.45, 0.7], 25, [-0.5, -0.45, 0.6], 55), tail(-15, -15, -10))
    light("Slash1", *LIGHT[0], G,
          merge(stance, waist(-35, -4), neck(18), arms([1, 0.25, -0.15], 50, [-0.4, -0.4, 0.75], 50), tail(15, 12, 10)),
          merge(lunge, waist(5, -10), neck(0), arms([0.25, 0.0, 1], 10, [-0.45, -0.45, 0.65], 50), tail(0, 0, 0)),
          merge(lunge, waist(35, -10), neck(-20), arms([-0.65, -0.3, 0.65], 15, [-0.45, -0.5, 0.55], 55), tail(-18, -18, -12)),
          E1)
    # 2: garra esquerda volta, corpo torce para o outro lado
    E2 = merge(stance, waist(-30, -6), neck(20), arms([0.5, -0.45, 0.6], 55, [0.5, -0.45, 0.7], 25), tail(15, 15, 10))
    light("Slash2", *LIGHT[1], E1,
          merge(stance, waist(35, -4), neck(-18), arms([0.4, -0.4, 0.75], 50, [-1, 0.25, -0.15], 50), tail(-15, -12, -10)),
          merge(lunge, waist(-5, -10), arms([0.45, -0.45, 0.65], 50, [-0.25, 0.0, 1], 10), tail(0, 0, 0)),
          merge(lunge, waist(-35, -10), neck(20), arms([0.45, -0.5, 0.55], 55, [0.65, -0.3, 0.65], 15), tail(18, 18, 12)),
          E2, windup_at=0.4)
    # 3: as duas garras de cima para baixo (rasgo vertical)
    E3 = merge(lunge, waist(0, -24), neck(0, 10), arms([0.3, -0.85, 0.45], 15, [-0.3, -0.85, 0.45], 15), tail(0, 0, 0, lift=-15))
    light("Slash3", *LIGHT[2], E2,
          merge(c.feet(drop=-0.05, width=0.15, front=0.4, back=-0.4), waist(0, 14), neck(0, 18), arms([0.45, 1, 0.1], 60, [-0.45, 1, 0.1], 60, [0, 0, -1], [0, 0, -1]), tail(0, 0, 0, lift=15)),
          merge(lunge, waist(0, -20), neck(0, 5), arms([0.3, -0.1, 1], 10, [-0.3, -0.1, 1], 10, [0, 1, 0], [0, 1, 0]), tail(0, 0, 0, lift=-10)),
          merge(lunge, waist(0, -26), neck(0, 12), arms([0.3, -0.8, 0.5], 12, [-0.3, -0.8, 0.5], 12, [0, 1, 0], [0, 1, 0]), tail(0, 0, 0, lift=-15)),
          E3)
    # 4: mordida — cabeça e tronco projetados, braços abertos para trás
    E4 = merge(lunge, waist(0, -18), neck(0, -6), arms([0.75, -0.35, -0.45], 20, [-0.75, -0.35, -0.45], 20), tail(0, 0, 0, lift=10))
    light("Slash4", *LIGHT[3], E3,
          merge(c.feet(drop=-0.35, width=0.15, front=0.4, back=-0.5), c.root(-0.35, -0.25), waist(0, 12), neck(0, 25), arms([0.8, 0.1, 0.5], 40, [-0.8, 0.1, 0.5], 40), tail(0, 0, 0, lift=20)),
          merge(lunge, c.root(-0.45, 0.55), waist(0, -26), neck(0, -22), arms([0.8, -0.25, -0.5], 15, [-0.8, -0.25, -0.5], 15), tail(0, 0, 0, lift=-5)),
          merge(lunge, c.root(-0.45, 0.6), waist(0, -24), neck(0, -12), arms([0.75, -0.35, -0.5], 20, [-0.75, -0.35, -0.5], 20), tail(0, 0, 0, lift=5)),
          E4)
    # 5: finalizador — salta ligeiramente e crava as duas garras no chão à frente
    w, d = LIGHT[4]
    c.clip("Slash5", [
        key(0, E4, ease("Linear", "In")),
        key(w * 0.55, merge(c.feet(drop=0.0, width=0.15, front=0.3, back=-0.3), waist(0, 18), neck(0, 22), arms([0.5, 1, -0.1], 70, [-0.5, 1, -0.1], 70, [0, 0, -1], [0, 0, -1]), tail(0, 0, 0, lift=25)), ease("Linear", "In"), name="WindUp"),
        key(w, merge(c.feet(drop=-0.7, width=0.2, front=0.75, back=-0.55), c.root(-0.7, 0.4), waist(0, -34), neck(0, 18), arms([0.35, -0.55, 0.8], 5, [-0.35, -0.55, 0.8], 5, [0, 1, 0], [0, 1, 0]), tail(0, 0, 0, lift=-20)), ease("Linear", "In"), name="Hit", markers=["Hit"]),
        key(w + 0.14, merge(c.feet(drop=-0.75, width=0.2, front=0.75, back=-0.55), c.root(-0.75, 0.45), waist(0, -38), neck(0, 22), arms([0.35, -0.75, 0.6], 10, [-0.35, -0.75, 0.6], 10, [0, 1, 0], [0, 1, 0]), tail(0, 0, 0, lift=-15)), ease("CubicV2", "Out")),
        key(d, merge(c.feet(drop=-0.45, width=0.15, front=0.5, back=-0.4), waist(0, -18), neck(0, 8), arms([0.45, -0.6, 0.6], 35, [-0.45, -0.6, 0.6], 35)), ease("CubicV2", "InOut")),
        key(d + 0.35, G),
    ])
    # Pesado: ergue-se inteiro, garra direita atrás da cabeça (antecipação longa) e esmaga
    w, d = HEAVY
    c.clip("HeavySlash", [
        key(0, G, ease("CubicV2", "Out")),
        key(w * 0.7, merge(c.feet(drop=0.05, width=0.15, front=0.2, back=-0.55), c.root(0.05, -0.2, -25), waist(-30, 22), neck(10, 20), arms([0.55, 0.85, -0.3], 80, [-0.6, 0.1, 0.75], 30, [0, 0, -1]), tail(20, 15, 10, lift=20)), ease("Linear", "In"), name="WindUp"),
        key(w, merge(c.feet(drop=-0.75, width=0.2, front=0.8, back=-0.55), c.root(-0.75, 0.5, 15), waist(20, -32), neck(-10, 15), arms([-0.1, -0.45, 0.9], 5, [-0.7, -0.4, -0.3], 25, [0, 1, 0]), tail(-20, -15, -10, lift=-15)), ease("Linear", "In"), name="Hit", markers=["Hit"]),
        key(w + 0.15, merge(c.feet(drop=-0.8, width=0.2, front=0.8, back=-0.55), c.root(-0.8, 0.55, 18), waist(25, -36), neck(-12, 18), arms([-0.2, -0.7, 0.65], 10, [-0.7, -0.45, -0.3], 25, [0, 1, 0]), tail(-22, -18, -12, lift=-10)), ease("CubicV2", "Out")),
        key(d, merge(c.feet(drop=-0.4, width=0.15, front=0.5, back=-0.4), waist(10, -14), arms([0.3, -0.6, 0.7], 35, [-0.5, -0.5, 0.6], 45)), ease("CubicV2", "InOut")),
        key(d + 0.35, G),
    ])
    # Lançador: garra baixa que sobe rasgando
    w, d = LAUNCHER
    c.clip("Uppercut", [
        key(0, G, ease("Linear", "In")),
        key(w * 0.4, merge(c.feet(drop=-0.6, width=0.15, front=0.55, back=-0.45), waist(-20, -30), neck(0, 20), arms([0.45, -0.8, 0.1], 40, [-0.45, -0.4, 0.7], 50), tail(0, 0, 0, lift=-15)), ease("Linear", "In"), name="WindUp"),
        key(w, merge(c.feet(drop=-0.1, width=0.15, front=0.45, back=-0.4), waist(10, 10), neck(0, 20), arms([0.25, 0.75, 0.6], 15, [-0.5, -0.4, 0.6], 50, [0, 0, -1]), tail(0, 0, 0, lift=20)), ease("Linear", "In"), name="Hit", markers=["Hit"]),
        key(w + 0.12, merge(c.feet(drop=0.0, width=0.15, front=0.4, back=-0.4), waist(12, 16), neck(0, 26), arms([0.2, 1, 0.2], 15, [-0.5, -0.4, 0.55], 50, [0, 0, -1]), tail(0, 0, 0, lift=25)), ease("CubicV2", "Out")),
        key(d, merge(G, waist(5, 4)), ease("CubicV2", "InOut")),
        key(d + 0.3, G),
    ])
    # Defesa: braços cruzados diante da máscara
    BLOCK = merge(c.feet(drop=-0.35, width=0.15, front=0.35, back=-0.45), waist(0, -10), neck(0, -12),
                  arms([0.05, 0.3, 0.95], 120, [-0.05, 0.4, 0.92], 115), tail(0, 0, 0, lift=-10))
    c.clip("Block", [key(0, G, ease("CubicV2", "Out")), key(0.12, BLOCK)], loop=False)
    c.clip("BlockHit", [key(0, BLOCK, ease("Linear", "In")), key(0.06, merge(BLOCK, c.root(-0.45, -0.25), waist(0, 2), neck(0, 0)), ease("CubicV2", "Out")), key(0.3, BLOCK)])

    def reaction(name, peak, duration, at=0.06, hold=0.55):
        c.clip(name, [key(0, G, ease("Linear", "In")), key(at, peak, ease("CubicV2", "Out"), name="Impact"),
                      key(duration * hold, peak, ease("CubicV2", "InOut")), key(duration, G)])

    reaction("Hit1", merge(c.feet(drop=-0.35, width=0.15, front=0.3, back=-0.4), c.root(-0.35, -0.3, 8), waist(10, 18), neck(10, 25), arms([0.85, -0.2, 0.35], 40, [-0.7, -0.5, 0.2], 45), tail(10, 15, 15, lift=15)), 0.42)
    reaction("Hit2", merge(c.feet(drop=-0.35, width=0.15, front=0.3, back=-0.4), c.root(-0.35, -0.3, -12), waist(-18, 14, 8), neck(-15, 20), arms([0.6, -0.5, 0.25], 45, [-0.9, -0.1, 0.3], 35), tail(-10, -15, -15, lift=15)), 0.42)
    reaction("Stagger", merge(c.feet(drop=-0.5, width=0.2, front=0.1, back=-0.7), c.root(-0.5, -0.6, 10), waist(5, 26), neck(0, 30), arms([0.95, 0.1, 0.1], 25, [-0.95, 0.15, 0.1], 25), tail(0, 0, 0, lift=25)), 0.8)
    reaction("GuardBreak", merge(c.feet(drop=-0.4, width=0.2, front=0.1, back=-0.7), c.root(-0.4, -0.55), waist(0, 28), neck(0, 30), arms([0.7, 0.75, 0.0], 20, [-0.7, 0.75, 0.0], 20), tail(0, 0, 0, lift=25)), 1.0, hold=0.7)
    reaction("Parried", merge(c.feet(drop=-0.35, width=0.15, front=0.2, back=-0.6), c.root(-0.35, -0.45, 14), waist(18, 22), neck(10, 26), arms([0.7, 0.7, -0.2], 25, [-0.6, -0.4, 0.4], 45), tail(15, 15, 10, lift=20)), 0.85, at=0.09, hold=0.65)
    # No ar (lançado): corpo arqueado, membros soltos
    c.clip("Launched", [
        key(0, G, ease("CubicV2", "Out")),
        key(0.12, merge(waist(0, 30), neck(0, 30), arms([0.85, 0.35, -0.2], 30, [-0.85, 0.35, -0.2], 30), tail(0, 0, 0, lift=30),
                        {"RightHip": {"aim": [0.2, -0.75, 0.6]}, "LeftHip": {"aim": [-0.2, -0.9, 0.3]}}), ease("CubicV2", "InOut")),
        key(0.9, merge(waist(0, 18), neck(0, 15), arms([0.75, -0.2, 0.1], 40, [-0.75, -0.2, 0.1], 40), tail(0, 0, 0, lift=15),
                       {"RightHip": {"aim": [0.2, -0.9, 0.35]}, "LeftHip": {"aim": [-0.2, -0.95, 0.2]}})),
        key(1.15, G),
    ], flags=())
    # Avanço rasteiro (dash): corpo quase horizontal, braços para trás
    c.clip("Dash", [
        key(0, G, ease("CubicV2", "Out")),
        key(0.14, merge(c.feet(drop=-0.6, width=0.2, front=0.7, back=-0.7), c.root(-0.6, 0.3), waist(0, -30), neck(0, 25), arms([0.6, -0.4, -0.7], 15, [-0.6, -0.4, -0.7], 15), tail(0, 0, 0, lift=20)), ease("CubicV2", "InOut")),
        key(0.3, merge(c.feet(drop=-0.5, width=0.2, front=0.6, back=-0.6), c.root(-0.5, 0.2), waist(0, -24), neck(0, 20), arms([0.6, -0.5, -0.5], 20, [-0.6, -0.5, -0.5], 20), tail(0, 0, 0, lift=10)), ease("CubicV2", "InOut")),
        key(0.5, G),
    ])

    def cast(name, release, anticipation, pose, hold=0.4):
        c.clip(name, [
            key(0, G, ease("CubicV2", "Out")),
            key(release * 0.75, anticipation, ease("Linear", "In"), name="Charge"),
            key(release, pose, ease("CubicV2", "Out"), name="Release", markers=["Release"]),
            key(release + hold, pose, ease("CubicV2", "InOut")),
            key(release + hold + 0.3, G),
        ])

    # Salto/esmagar: agacha fundo, braços sobem, desce com as duas garras
    cast("CastOverhead", 0.3,
         merge(c.feet(drop=-0.8, width=0.2, front=0.45, back=-0.45), waist(0, 20), neck(0, 25), arms([0.5, 0.9, -0.2], 70, [-0.5, 0.9, -0.2], 70, [0, 0, -1], [0, 0, -1]), tail(0, 0, 0, lift=25)),
         merge(c.feet(drop=-0.75, width=0.2, front=0.75, back=-0.55), c.root(-0.75, 0.4), waist(0, -34), neck(0, 18), arms([0.35, -0.55, 0.8], 5, [-0.35, -0.55, 0.8], 5, [0, 1, 0], [0, 1, 0]), tail(0, 0, 0, lift=-20)))
    # Cero: cabeça projetada, mandíbula para a frente, braços abertos firmando o corpo
    cast("CastCharge", 0.45,
         merge(c.feet(drop=-0.5, width=0.25, front=0.45, back=-0.6), c.root(-0.5, -0.2), waist(0, 18), neck(0, 30), arms([0.95, -0.25, 0.1], 35, [-0.95, -0.25, 0.1], 35), tail(0, 0, 0, lift=25)),
         merge(c.feet(drop=-0.6, width=0.25, front=0.55, back=-0.65), c.root(-0.6, 0.25), waist(0, -14), neck(0, -10), arms([0.9, -0.45, -0.2], 25, [-0.9, -0.45, -0.2], 25), tail(0, 0, 0, lift=-10)), hold=0.5)
    # Rugido: peito para cima, braços abertos
    cast("CastBurst", 0.3,
         merge(c.feet(drop=-0.6, width=0.2), waist(0, -20), neck(0, -20), arms([0.3, -0.5, 0.8], 110, [-0.3, -0.5, 0.8], 110), tail(0, 0, 0, lift=-15)),
         merge(c.feet(drop=-0.25, width=0.25), waist(0, 26), neck(0, 35), arms([1, 0.45, -0.15], 15, [-1, 0.45, -0.15], 15), tail(10, 20, 25, lift=30)), hold=0.5)
    cast("CastPoint", 0.25,
         merge(stance, waist(-25, -5), neck(25), arms([0.6, -0.4, -0.5], 60, [-0.4, -0.3, 0.8], 50)),
         merge(lunge, waist(25, -10), neck(-20), arms([0.25, 0.0, 1], 0, [-0.6, -0.5, 0.3], 50)))
    cast("DashStrikePose", 0.12,
         merge(c.feet(drop=-0.6, width=0.2, front=0.6, back=-0.6), waist(-15, -20), neck(0, 20), arms([0.6, -0.4, -0.6], 20, [-0.6, -0.4, -0.6], 20)),
         merge(c.feet(drop=-0.8, width=0.2, front=0.8, back=-0.7), c.root(-0.8, 0.5, 20), waist(25, -20), neck(-20, 15), arms([0.95, 0.0, -0.3], 10, [-0.5, -0.6, 0.4], 40)), hold=0.3)


# ============================================================================ BRUTE
def brute(c):
    G = merge(c.feet(drop=-0.1, width=0.15, front=0.25, back=-0.25), waist(0, -4), neck(0, 4),
              arms([0.5, -0.8, 0.3], 30, [-0.5, -0.8, 0.3], 30))
    c.guard = G
    c.clip("Idle", [
        key(0, merge(G, waist(0, -6), arms([0.5, -0.82, 0.25], 28, [-0.5, -0.8, 0.3], 34)), ease("CubicV2", "InOut")),
        key(1.4, merge(G, c.feet(drop=-0.2, width=0.15, front=0.25, back=-0.25), waist(4, 0), neck(8, 0), arms([0.55, -0.78, 0.3], 36, [-0.5, -0.84, 0.25], 28)), ease("CubicV2", "InOut")),
        key(2.8, merge(G, waist(0, -6), arms([0.5, -0.82, 0.25], 28, [-0.5, -0.8, 0.3], 34))),
    ], loop=True, priority="Idle")
    # Andar pesado: passada curta, tronco balança de lado a lado, braços como pêndulos
    c.raw("Walk", {"loop": True, "priority": "Movement", "duration": 1.1,
                   "gait": {"pattern": "walk", "stride": 1.3, "lift": 0.3, "bob": 0.18},
                   "keyframes": [key(0, merge(waist(-8, -6, 5), neck(6, 0), arms([0.5, -0.8, -0.2], 25, [-0.5, -0.65, 0.55], 40)), ease("CubicV2", "InOut")),
                                 key(0.55, merge(waist(8, -6, -5), neck(-6, 0), arms([0.5, -0.65, 0.55], 40, [-0.5, -0.8, -0.2], 25)), ease("CubicV2", "InOut")),
                                 key(1.1, merge(waist(-8, -6, 5), neck(6, 0), arms([0.5, -0.8, -0.2], 25, [-0.5, -0.65, 0.55], 40)))]},
          flags=["--locomotion"], ground_speed=True)
    c.raw("Run", {"loop": True, "priority": "Movement", "duration": 0.62,
                  "gait": {"pattern": "walk", "stride": 2.0, "duty": 0.42, "lift": 0.45, "bob": 0.25},
                  "keyframes": [key(0, merge(waist(-10, -18, 6), neck(0, 14), arms([0.5, -0.5, -0.6], 25, [-0.5, -0.3, 0.8], 50)), ease("CubicV2", "InOut")),
                                key(0.31, merge(waist(10, -18, -6), neck(0, 14), arms([0.5, -0.3, 0.8], 50, [-0.5, -0.5, -0.6], 25)), ease("CubicV2", "InOut")),
                                key(0.62, merge(waist(-10, -18, 6), neck(0, 14), arms([0.5, -0.5, -0.6], 25, [-0.5, -0.3, 0.8], 50)))]},
          flags=["--locomotion"], ground_speed=True)

    stance = c.feet(drop=-0.25, width=0.2, front=0.4, back=-0.35)

    def light(name, w, d, start, windup, hit, follow, end, windup_at=0.55):
        c.clip(name, [
            key(0, start, ease("Linear", "In")),
            key(w * windup_at, windup, ease("Linear", "In"), name="WindUp"),
            key(w, hit, ease("Linear", "In"), name="Hit", markers=["Hit"]),
            key(w + (d - w) * 0.45, follow, ease("CubicV2", "Out")),
            key(d, end, ease("CubicV2", "InOut")),
            key(d + 0.35, G),
        ])

    # Socão em gancho da direita, depois da esquerda (o Brute encadeia 2)
    E1 = merge(stance, waist(30, -8), neck(-15), arms([-0.35, -0.6, 0.7], 30, [-0.5, -0.75, 0.35], 35))
    light("Slash1", *LIGHT[0], G,
          merge(stance, waist(-35, 2), neck(15), arms([0.95, -0.1, -0.3], 70, [-0.45, -0.6, 0.6], 50)),
          merge(stance, c.root(-0.3, 0.3), waist(10, -10), arms([0.2, -0.15, 1], 25, [-0.5, -0.7, 0.4], 40)),
          merge(stance, c.root(-0.3, 0.35), waist(35, -12), neck(-15), arms([-0.5, -0.4, 0.75], 25, [-0.5, -0.75, 0.35], 35)),
          E1)
    E2 = merge(stance, waist(-30, -8), neck(15), arms([0.5, -0.75, 0.35], 35, [0.35, -0.6, 0.7], 30))
    light("Slash2", *LIGHT[1], E1,
          merge(stance, waist(35, 2), neck(-15), arms([0.45, -0.6, 0.6], 50, [-0.95, -0.1, -0.3], 70)),
          merge(stance, c.root(-0.3, 0.3), waist(-10, -10), arms([0.5, -0.7, 0.4], 40, [-0.2, -0.15, 1], 25)),
          merge(stance, c.root(-0.3, 0.35), waist(-35, -12), neck(15), arms([0.5, -0.75, 0.35], 35, [0.5, -0.4, 0.75], 25)),
          E2, windup_at=0.4)
    E3 = merge(c.feet(drop=-0.6, width=0.25, front=0.55, back=-0.45), waist(0, -26), arms([0.4, -0.85, 0.35], 15, [-0.4, -0.85, 0.35], 15))
    light("Slash3", *LIGHT[2], E2,
          merge(c.feet(drop=0.0, width=0.2), waist(0, 16), neck(0, 18), arms([0.35, 1, 0.1], 70, [-0.35, 1, 0.1], 70, [0, 0, -1], [0, 0, -1])),
          merge(c.feet(drop=-0.6, width=0.25, front=0.55, back=-0.45), c.root(-0.6, 0.3), waist(0, -24), arms([0.3, -0.35, 0.9], 10, [-0.3, -0.35, 0.9], 10, [0, 1, 0], [0, 1, 0])),
          merge(c.feet(drop=-0.65, width=0.25, front=0.55, back=-0.45), c.root(-0.65, 0.35), waist(0, -28), arms([0.35, -0.8, 0.45], 12, [-0.35, -0.8, 0.45], 12, [0, 1, 0], [0, 1, 0])),
          E3)
    w, d = HEAVY
    # Pesado: martelo duplo — ergue os dois punhos bem alto e afunda o chão
    c.clip("HeavySlash", [
        key(0, G, ease("CubicV2", "Out")),
        key(w * 0.72, merge(c.feet(drop=0.0, width=0.25, front=0.5, back=-0.45), c.root(0.0, -0.1), waist(0, 24), neck(0, 22), arms([0.3, 1, -0.2], 60, [-0.3, 1, -0.2], 60, [0, 0, -1], [0, 0, -1])), ease("Linear", "In"), name="WindUp"),
        key(w, merge(c.feet(drop=-0.55, width=0.25, front=0.5, back=-0.45), c.root(-0.55, 0.35), waist(0, -34), neck(0, 20), arms([0.25, -0.6, 0.75], 5, [-0.25, -0.6, 0.75], 5, [0, 1, 0], [0, 1, 0])), ease("Linear", "In"), name="Hit", markers=["Hit"]),
        key(w + 0.15, merge(c.feet(drop=-0.6, width=0.25, front=0.5, back=-0.45), c.root(-0.6, 0.4), waist(0, -38), neck(0, 22), arms([0.3, -0.75, 0.55], 8, [-0.3, -0.75, 0.55], 8, [0, 1, 0], [0, 1, 0])), ease("CubicV2", "Out")),
        key(d, merge(c.feet(drop=-0.4, width=0.2), waist(0, -14), arms([0.45, -0.8, 0.35], 25, [-0.45, -0.8, 0.35], 25)), ease("CubicV2", "InOut")),
        key(d + 0.4, G),
    ])
    w, d = LAUNCHER
    c.clip("Uppercut", [
        key(0, G, ease("Linear", "In")),
        key(w * 0.4, merge(c.feet(drop=-0.6, width=0.2, front=0.45, back=-0.4), waist(-25, -28), arms([0.5, -0.8, 0.1], 60, [-0.5, -0.7, 0.4], 40)), ease("Linear", "In"), name="WindUp"),
        key(w, merge(c.feet(drop=-0.1, width=0.2, front=0.4, back=-0.35), waist(15, 10), neck(0, 18), arms([0.25, 0.7, 0.65], 30, [-0.5, -0.7, 0.4], 40, [0, 0, -1])), ease("Linear", "In"), name="Hit", markers=["Hit"]),
        key(w + 0.12, merge(c.feet(drop=0.0, width=0.2, front=0.35, back=-0.35), waist(18, 14), neck(0, 22), arms([0.2, 0.95, 0.25], 30, [-0.5, -0.7, 0.35], 40, [0, 0, -1])), ease("CubicV2", "Out")),
        key(d, merge(G, waist(5, 0)), ease("CubicV2", "InOut")),
        key(d + 0.35, G),
    ])
    BLOCK = merge(c.feet(drop=-0.35, width=0.2, front=0.3, back=-0.4), waist(0, -14), neck(0, -10), arms([0.15, 0.1, 0.98], 125, [-0.15, 0.2, 0.97], 120))
    c.clip("Block", [key(0, G, ease("CubicV2", "Out")), key(0.15, BLOCK)])
    c.clip("BlockHit", [key(0, BLOCK, ease("Linear", "In")), key(0.07, merge(BLOCK, c.root(-0.42, -0.2)), ease("CubicV2", "Out")), key(0.35, BLOCK)])

    def reaction(name, peak, duration, at=0.07, hold=0.55):
        c.clip(name, [key(0, G, ease("Linear", "In")), key(at, peak, ease("CubicV2", "Out"), name="Impact"),
                      key(duration * hold, peak, ease("CubicV2", "InOut")), key(duration, G)])

    reaction("Hit1", merge(c.feet(drop=-0.3, width=0.2, front=0.25, back=-0.35), c.root(-0.3, -0.2, 6), waist(8, 12), neck(8, 18), arms([0.7, -0.6, 0.2], 40, [-0.6, -0.75, 0.1], 35)), 0.45)
    reaction("Hit2", merge(c.feet(drop=-0.3, width=0.2, front=0.25, back=-0.35), c.root(-0.3, -0.2, -8), waist(-12, 10, 6), neck(-10, 16), arms([0.55, -0.75, 0.1], 35, [-0.75, -0.55, 0.2], 40)), 0.45)
    reaction("Stagger", merge(c.feet(drop=-0.45, width=0.25, front=0.1, back=-0.6), c.root(-0.45, -0.45, 8), waist(0, 20), neck(0, 24), arms([0.9, -0.1, 0.2], 25, [-0.9, -0.1, 0.2], 25)), 0.85)
    reaction("GuardBreak", merge(c.feet(drop=-0.4, width=0.25, front=0.1, back=-0.6), c.root(-0.4, -0.45), waist(0, 24), neck(0, 26), arms([0.65, 0.75, 0.05], 20, [-0.65, 0.75, 0.05], 20)), 1.0, hold=0.7)
    reaction("Parried", merge(c.feet(drop=-0.3, width=0.2, front=0.15, back=-0.5), c.root(-0.3, -0.35, 12), waist(15, 18), neck(8, 20), arms([0.6, 0.65, -0.2], 25, [-0.55, -0.6, 0.3], 40)), 0.85, at=0.09, hold=0.65)

    def cast(name, release, anticipation, pose, hold=0.45):
        c.clip(name, [
            key(0, G, ease("CubicV2", "Out")),
            key(release * 0.75, anticipation, ease("Linear", "In"), name="Charge"),
            key(release, pose, ease("CubicV2", "Out"), name="Release", markers=["Release"]),
            key(release + hold, pose, ease("CubicV2", "InOut")),
            key(release + hold + 0.35, G),
        ])

    # Esmagar o chão: punhos acima da cabeça → soco duplo no solo
    cast("CastOverhead", 0.3,
         merge(c.feet(drop=0.0, width=0.25, front=0.5, back=-0.45), c.root(0.0, -0.1), waist(0, 24), neck(0, 22), arms([0.3, 1, -0.2], 60, [-0.3, 1, -0.2], 60, [0, 0, -1], [0, 0, -1])),
         merge(c.feet(drop=-0.6, width=0.25, front=0.5, back=-0.45), c.root(-0.6, 0.4), waist(0, -38), neck(0, 22), arms([0.25, -0.75, 0.6], 5, [-0.25, -0.75, 0.6], 5, [0, 1, 0], [0, 1, 0])))
    cast("CastBurst", 0.3,
         merge(c.feet(drop=-0.55, width=0.25), waist(0, -22), neck(0, -18), arms([0.35, -0.6, 0.7], 100, [-0.35, -0.6, 0.7], 100)),
         merge(c.feet(drop=-0.2, width=0.3), waist(0, 24), neck(0, 30), arms([1, 0.35, -0.1], 20, [-1, 0.35, -0.1], 20)), hold=0.55)


def author_all(out, manifest):
    for body, fn in (("HollowGrunt", grunt), ("HollowBrute", brute)):
        fn(Creature(body, out, manifest))

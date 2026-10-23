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
        self.front_ankle = None
        if parts.get("RightHand", {}).get("parent") == "RightLowerArm" and self.set == "Hound":
            fa = rig_reading.mul(frames["RightLowerArm"], rig_reading.frame(parts["RightHand"]["c0"]))[0]
            self.front_ankle = (fa[0], fa[1], -fa[2])
        self.rig = "game.Workspace." + body
        self.guard = {}

    def feet(self, drop=0.0, width=0.0, front=0.25, back=-0.25):
        x, y, z = self.ankle
        return {"Root": {"position": [0, drop, 0]},
                "RightHip": {"aimAt": [x + width, y, z + front]}, "LeftHip": {"aimAt": [-x - width, y, z + back]}}

    def paws(self, drop=0.0, spread=0.0, front=0.0, back=0.0):
        """Quadrúpede: as quatro patas plantadas (front/back deslocam as da frente/de trás)."""
        fx, fy, fz = self.front_ankle
        hx, hy, hz = self.ankle
        return {"Root": {"position": [0, drop, 0]},
                "RightShoulder": {"aimAt": [fx + spread, fy, fz + front]}, "LeftShoulder": {"aimAt": [-fx - spread, fy, fz + front]},
                "RightHip": {"aimAt": [hx + spread, hy, hz + back]}, "LeftHip": {"aimAt": [-hx - spread, hy, hz + back]}}

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

    # Entrada em combate: ergue o tronco, abre os braços e ruge (sacode a cabeça)
    roar = merge(c.feet(drop=-0.1, width=0.2, front=0.35, back=-0.45), c.root(-0.1, -0.15, 0, 10), waist(0, 26), neck(0, 30),
                 arms([1, 0.3, -0.35], 30, [-1, 0.3, -0.35], 30), tail(10, 20, 25, lift=30))
    c.clip("Roar", [
        key(0, G, ease("CubicV2", "Out")),
        key(0.25, merge(c.feet(drop=-0.45, width=0.2, front=0.35, back=-0.45), waist(0, -14), neck(0, -10), arms([0.4, -0.6, 0.6], 80, [-0.4, -0.6, 0.6], 80)), ease("CubicV2", "Out"), name="Inhale"),
        key(0.45, roar, ease("CubicV2", "InOut"), name="Roar", markers=["Roar"]),
        key(0.65, merge(roar, neck(12, 32)), ease("CubicV2", "InOut")),
        key(0.85, merge(roar, neck(-12, 32)), ease("CubicV2", "InOut")),
        key(1.05, roar, ease("CubicV2", "InOut")),
        key(1.35, G),
    ])
    # Morte: recua com o golpe, os joelhos cedem e cai de cara no chão (fica no fim)
    stand_legs = {"Root": {"position": [0, -0.15, 0]}, "RightHip": {"aim": [0.15, -1, 0.15]}, "RightKnee": {"bend": 20},
                  "LeftHip": {"aim": [-0.15, -1, -0.1]}, "LeftKnee": {"bend": 20}}
    G_death = merge({k: v for k, v in G.items() if k not in ("Root", "RightHip", "LeftHip")}, stand_legs)
    c.clip("Death", [
        key(0, G_death, ease("CubicV2", "Out")),
        key(0.14, merge(waist(0, 22), neck(0, 28), arms([0.95, 0.2, 0.2], 30, [-0.95, 0.25, 0.15], 30), tail(0, 0, 0, lift=25),
                        {"Root": {"position": [0, -0.3, 0.35], "rotation": [14, 0, 0]},
                         "RightHip": {"aim": [0.2, -1, 0.1]}, "RightKnee": {"bend": 40}, "LeftHip": {"aim": [-0.2, -1, 0.05]}, "LeftKnee": {"bend": 40}}),
            ease("CubicV2", "InOut"), name="Impact", markers=["Impact"]),
        key(0.55, merge(waist(0, -8), neck(0, -25), arms([0.3, -1, 0.2], 15, [-0.3, -1, 0.15], 15), tail(0, 0, 0, lift=-5),
                        {"Root": {"position": [0, -1.35, 0.1], "rotation": [-12, 0, 0]},
                         "RightHip": {"aim": [0.2, -0.45, 0.9]}, "RightKnee": {"bend": 125}, "LeftHip": {"aim": [-0.2, -0.45, 0.9]}, "LeftKnee": {"bend": 125}}),
            ease("CubicV2", "In"), name="Knees"),
        key(0.95, merge(waist(0, -28), neck(10, -30), arms([0.4, -0.85, 0.5], 15, [-0.3, -0.9, 0.45], 20), tail(10, 15, 10, lift=-25),
                        {"Root": {"position": [0, -1.75, 0.1], "rotation": [-38, 0, 0]},
                         "RightHip": {"aim": [0.2, -0.3, 0.95]}, "RightKnee": {"bend": 140}, "LeftHip": {"aim": [-0.2, -0.3, 0.95]}, "LeftKnee": {"bend": 140}}),
            ease("Bounce", "Out"), name="Slump", markers=["Thud"]),
        key(1.5, merge(waist(0, -30), neck(14, -34), arms([0.4, -0.88, 0.45], 18, [-0.3, -0.92, 0.4], 22), tail(14, 18, 14, lift=-25),
                       {"Root": {"position": [0, -1.8, 0.1], "rotation": [-40, 0, 0]},
                        "RightHip": {"aim": [0.2, -0.3, 0.95]}, "RightKnee": {"bend": 140}, "LeftHip": {"aim": [-0.2, -0.3, 0.95]}, "LeftKnee": {"bend": 140}})),
    ], flags=(), waive=("rootDrift",))  # termina deitado de propósito: o jogo segura o último quadro

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

    # Entrada em combate: bate no peito duas vezes e ruge de cabeça erguida
    chest = merge(c.feet(drop=-0.2, width=0.25), waist(0, 10), neck(0, 18))
    c.clip("Roar", [
        key(0, G, ease("CubicV2", "Out")),
        key(0.2, merge(chest, arms([0.8, 0.2, 0.5], 110, [-0.6, -0.5, 0.4], 50)), ease("Linear", "In"), name="Raise"),
        key(0.32, merge(chest, arms([0.15, -0.2, 0.9], 140, [-0.6, -0.5, 0.4], 50)), ease("CubicV2", "Out"), name="PoundR", markers=["Pound"]),
        key(0.48, merge(chest, arms([0.6, -0.5, 0.4], 50, [-0.8, 0.2, 0.5], 110)), ease("Linear", "In")),
        key(0.6, merge(chest, arms([0.6, -0.5, 0.4], 50, [-0.15, -0.2, 0.9], 140)), ease("CubicV2", "Out"), name="PoundL", markers=["Pound"]),
        key(0.85, merge(c.feet(drop=-0.05, width=0.25), waist(0, 24), neck(0, 34), arms([1, 0.35, -0.2], 25, [-1, 0.35, -0.2], 25)), ease("CubicV2", "InOut"), name="Roar", markers=["Roar"]),
        key(1.25, merge(c.feet(drop=-0.05, width=0.25), waist(0, 24), neck(0, 30), arms([1, 0.3, -0.2], 25, [-1, 0.3, -0.2], 25)), ease("CubicV2", "InOut")),
        key(1.6, G),
    ])
    # Morte: cai de joelhos e tomba para o lado com o peso todo
    stand_legs = {"Root": {"position": [0, -0.1, 0]}, "RightHip": {"aim": [0.2, -1, 0.1]}, "RightKnee": {"bend": 15},
                  "LeftHip": {"aim": [-0.2, -1, -0.1]}, "LeftKnee": {"bend": 15}}
    G_death = merge({k: v for k, v in G.items() if k not in ("Root", "RightHip", "LeftHip")}, stand_legs)
    c.clip("Death", [
        key(0, G_death, ease("CubicV2", "Out")),
        key(0.15, merge(waist(0, 18), neck(0, 22), arms([0.9, -0.2, 0.2], 25, [-0.9, -0.1, 0.2], 25),
                        {"Root": {"position": [0, -0.3, 0.3], "rotation": [10, 0, 0]},
                         "RightHip": {"aim": [0.3, -1, 0.1]}, "RightKnee": {"bend": 35}, "LeftHip": {"aim": [-0.3, -1, 0.05]}, "LeftKnee": {"bend": 35}}),
            ease("CubicV2", "InOut"), name="Impact", markers=["Impact"]),
        key(0.6, merge(waist(0, -10), neck(0, -20), arms([0.45, -0.95, 0.2], 20, [-0.45, -0.95, 0.2], 20),
                       {"Root": {"position": [0, -1.0, 0], "rotation": [-8, 0, 0]},
                        "RightHip": {"aim": [0.3, -0.35, 0.9]}, "RightKnee": {"bend": 120}, "LeftHip": {"aim": [-0.3, -0.35, 0.9]}, "LeftKnee": {"bend": 120}}),
            ease("CubicV2", "In"), name="Knees", markers=["Thud"]),
        key(1.05, merge(waist(0, -6), neck(-15, 0), arms([0.6, -0.6, 0.4], 30, [-0.9, 0.2, 0.1], 20),
                        {"Root": {"position": [0.6, -2.1, 0], "rotation": [-10, 0, -80]},
                         "RightHip": {"aim": [0.3, -0.5, 0.75]}, "RightKnee": {"bend": 90}, "LeftHip": {"aim": [-0.3, -0.6, 0.7]}, "LeftKnee": {"bend": 70}}),
            ease("Bounce", "Out"), name="Fall", markers=["Thud"]),
        key(1.5, merge(waist(0, -6), neck(-18, 0), arms([0.6, -0.6, 0.4], 30, [-0.9, 0.2, 0.1], 22),
                       {"Root": {"position": [0.6, -2.1, 0], "rotation": [-10, 0, -80]},
                        "RightHip": {"aim": [0.3, -0.5, 0.75]}, "RightKnee": {"bend": 90}, "LeftHip": {"aim": [-0.3, -0.6, 0.7]}, "LeftKnee": {"bend": 70}})),
    ], flags=(), waive=("rootDrift",))  # termina caído de propósito: o jogo segura o último quadro

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


# ============================================================================ HOUND
def hound(c):
    def jaw(open_deg):
        return {"Jaw": {"rotation": [-open_deg, 0, 0]}}

    G = merge(c.paws(drop=-0.15, spread=0.05), waist(0, -3), neck(0, -10), jaw(0))
    c.guard = merge(G, tail(0, 0, 0))
    TAIL_WAVE = {"joints": ["Tail1", "Tail2", "Tail3"], "axis": "Y", "amplitude": [8, 20], "lag": 0.18}
    # Parado: respira, fareja (cabeça varre), mandíbula entreabre
    c.clip("Idle", [
        key(0, merge(G, waist(0, -2), neck(-12, -12), jaw(4)), ease("CubicV2", "InOut")),
        key(1.0, merge(c.paws(drop=-0.22, spread=0.05), waist(0, -5), neck(10, -6), jaw(10)), ease("CubicV2", "InOut")),
        key(2.0, merge(G, waist(0, -2), neck(-12, -12), jaw(4))),
    ], loop=True, priority="Idle", extra={"waves": [dict(TAIL_WAVE, cycles=2)]})
    # Trote e galope (pés plantados pelo gait); cabeça baixa e firme na corrida
    c.raw("Walk", {"loop": True, "priority": "Movement", "duration": 0.6,
                   "gait": {"pattern": "trot", "stride": 1.6, "lift": 0.35, "bob": 0.08},
                   "keyframes": [key(0, merge(neck(0, -10), jaw(3)), ease("CubicV2", "InOut")), key(0.3, merge(neck(0, -6), jaw(6)), ease("CubicV2", "InOut")), key(0.6, merge(neck(0, -10), jaw(3)))],
                   "waves": [dict(TAIL_WAVE, cycles=1)]}, flags=["--locomotion"], ground_speed=True)
    c.raw("Run", {"loop": True, "priority": "Movement", "duration": 0.42,
                  "gait": {"pattern": "gallop", "stride": 2.4, "duty": 0.38, "lift": 0.45, "bob": 0.15},
                  "keyframes": [key(0, merge(neck(0, -18), jaw(12)), ease("CubicV2", "InOut")), key(0.21, merge(neck(0, -8), jaw(20)), ease("CubicV2", "InOut")), key(0.42, merge(neck(0, -18), jaw(12)))],
                  "waves": [dict(TAIL_WAVE, axis="X", amplitude=[4, 12], cycles=1)]}, flags=["--locomotion"], ground_speed=True)

    def strike(name, w, d, start, windup, hit, follow, end, windup_at=0.55):
        c.clip(name, [
            key(0, start, ease("Linear", "In")),
            key(w * windup_at, windup, ease("Linear", "In"), name="WindUp"),
            key(w, hit, ease("Linear", "In"), name="Hit", markers=["Hit"]),
            key(w + (d - w) * 0.45, follow, ease("CubicV2", "Out")),
            key(d, end, ease("CubicV2", "InOut")),
            key(d + 0.25, G),
        ])

    crouch = c.paws(drop=-0.45, spread=0.08, front=-0.15, back=0.1)
    lunge = c.paws(drop=-0.35, spread=0.08, front=0.35, back=-0.15)
    # 1: mordida em investida — boca abre no preparo e fecha no impacto
    E1 = merge(lunge, c.root(-0.35, 0.3), waist(0, -4), neck(0, -12), jaw(2), tail(0, 0, 0, lift=5))
    strike("Slash1", *LIGHT[0], G,
           merge(crouch, c.root(-0.45, -0.2), waist(0, 6), neck(0, 10), jaw(35), tail(0, 0, 0, lift=20)),
           merge(lunge, c.root(-0.3, 0.6), waist(0, -8), neck(0, -20), jaw(0), tail(0, 0, 0, lift=-5)),
           merge(lunge, c.root(-0.32, 0.55), waist(0, -6), neck(8, -16), jaw(4), tail(0, 0, 0)),
           E1)
    # 2: patada com a pata direita da frente, de fora para dentro
    E2 = merge(lunge, c.root(-0.35, 0.3, -5), waist(-8, -4), neck(-10, -10), jaw(6))
    c.clip("Slash2", [
        key(0, E1, ease("Linear", "In")),
        key(LIGHT[1][0] * 0.4, merge(c.paws(drop=-0.22, spread=0.08, front=0.2, back=-0.1), c.root(-0.22, 0.15, 8), waist(12, 4), neck(15, -4), jaw(20),
                                      {"RightShoulder": {"aim": [0.6, -0.3, 0.7]}}), ease("Linear", "In"), name="WindUp", markers=["Swing"]),
        key(LIGHT[1][0], merge(c.paws(drop=-0.28, spread=0.08, front=0.25, back=-0.1), c.root(-0.28, 0.3, -6), waist(-10, -4), neck(-12, -10), jaw(8),
                               {"RightShoulder": {"aim": [-0.15, -0.75, 0.6]}}), ease("Linear", "In"), name="Hit", markers=["Hit"]),
        key(LIGHT[1][0] + 0.09, E2, ease("CubicV2", "Out")),
        key(LIGHT[1][1], E2, ease("CubicV2", "InOut")),
        key(LIGHT[1][1] + 0.25, G),
    ])
    # 3: salto curto com mordida dupla (mandíbula fecha forte no impacto)
    strike("Slash3", *LIGHT[2], E2,
           merge(c.paws(drop=-0.42, spread=0.08, front=-0.05, back=0.1), c.root(-0.42, -0.1, 0, 5), waist(0, 8), neck(0, 18), jaw(40), tail(0, 0, 0, lift=25)),
           merge(lunge, c.root(-0.2, 0.75, 0, -8), waist(0, -10), neck(0, -24), jaw(0), tail(0, 0, 0, lift=-10)),
           merge(lunge, c.root(-0.3, 0.7, 0, -6), waist(0, -8), neck(0, -18), jaw(14)),
           merge(lunge, c.root(-0.35, 0.4), neck(0, -12), jaw(4)))
    # Pesado: bote — agacha fundo, salta e prende o alvo com as duas patas e a mordida
    w, d = HEAVY
    c.clip("HeavySlash", [
        key(0, G, ease("CubicV2", "Out")),
        key(w * 0.75, merge(c.paws(drop=-0.6, spread=0.1, front=-0.2, back=0.15), c.root(-0.6, -0.35, 0, 12), waist(0, 10), neck(0, 20), jaw(45), tail(0, 0, 0, lift=30)), ease("Linear", "In"), name="WindUp", markers=["Swing"]),
        key(w, merge(waist(0, -6), neck(0, -22), jaw(0), tail(0, 0, 0, lift=-15),
                     {"Root": {"position": [0, 0.1, -1.1], "rotation": [-14, 0, 0]},
                      "RightShoulder": {"aim": [0.15, -0.3, 1]}, "LeftShoulder": {"aim": [-0.15, -0.3, 1]},
                      "RightHip": {"aim": [0.1, -0.6, -0.8]}, "LeftHip": {"aim": [-0.1, -0.6, -0.8]}}),
            ease("Linear", "In"), name="Hit", markers=["Hit"]),
        key(w + 0.15, merge(lunge, c.root(-0.4, 0.8), waist(0, -10), neck(0, -20), jaw(10)), ease("CubicV2", "Out")),
        key(d, merge(lunge, c.root(-0.35, 0.5), neck(0, -12), jaw(6)), ease("CubicV2", "InOut")),
        key(d + 0.35, G),
    ], flags=())
    w, d = LAUNCHER
    strike("Uppercut", w, d, G,
           merge(crouch, c.root(-0.5, -0.1), neck(0, -30), jaw(30)),
           merge(c.paws(drop=-0.2, spread=0.08), c.root(-0.2, 0.1, 0, 5), neck(0, 35), jaw(0)),
           merge(c.paws(drop=-0.22, spread=0.08), c.root(-0.22, 0.08, 0, 4), neck(0, 30), jaw(10)),
           G, windup_at=0.45)

    def reaction(name, peak, duration, at=0.06, hold=0.55):
        c.clip(name, [key(0, G, ease("Linear", "In")), key(at, peak, ease("CubicV2", "Out"), name="Impact"),
                      key(duration * hold, peak, ease("CubicV2", "InOut")), key(duration, G)])

    reaction("Hit1", merge(c.paws(drop=-0.3, spread=0.1, front=-0.15, back=0.1), c.root(-0.3, -0.35, 12), waist(8, 6), neck(25, 10), jaw(25), tail(10, 15, 15, lift=15)), 0.42)
    reaction("Hit2", merge(c.paws(drop=-0.3, spread=0.1, front=-0.15, back=0.1), c.root(-0.3, -0.35, -12), waist(-8, 6), neck(-25, 10), jaw(25), tail(-10, -15, -15, lift=15)), 0.42)
    reaction("Stagger", merge(c.paws(drop=-0.55, spread=0.15, front=-0.1, back=0.1), c.root(-0.55, -0.15, 0, 6), waist(0, 6), neck(0, 25), jaw(30), tail(0, 0, 0, lift=25)), 0.8)
    reaction("GuardBreak", merge(c.paws(drop=-0.55, spread=0.15, front=-0.1, back=0.1), c.root(-0.55, -0.15, 0, 6), neck(0, 30), jaw(35)), 1.0, hold=0.7)
    reaction("Parried", merge(c.paws(drop=-0.45, spread=0.12, front=-0.1, back=0.1), c.root(-0.45, -0.15, 12, 5), neck(20, 20), jaw(25)), 0.85, at=0.09, hold=0.65)
    BLOCK = merge(c.paws(drop=-0.55, spread=0.12, front=-0.2, back=0.2), c.root(-0.55, -0.3), neck(0, -25), jaw(0), tail(0, 0, 0, lift=-10))
    c.clip("Block", [key(0, G, ease("CubicV2", "Out")), key(0.12, BLOCK)])
    c.clip("BlockHit", [key(0, BLOCK, ease("Linear", "In")), key(0.06, merge(BLOCK, c.root(-0.6, -0.5)), ease("CubicV2", "Out")), key(0.3, BLOCK)])
    c.clip("Dash", [
        key(0, G, ease("CubicV2", "Out")),
        key(0.12, merge(c.paws(drop=-0.5, spread=0.1, front=0.4, back=-0.4), c.root(-0.5, 0.2), neck(0, -20), jaw(15)), ease("CubicV2", "InOut")),
        key(0.45, G),
    ])
    # Rugido: cabeça para cima, mandíbula escancarada, tremor
    rear = {"Root": {"position": [0, 0.12, 0.2], "rotation": [28, 0, 0]},
            "RightShoulder": {"aim": [0.25, -0.2, 1]}, "LeftShoulder": {"aim": [-0.25, -0.5, 0.85]}}
    howl = merge(rear, waist(0, 6), neck(0, 30), jaw(42), tail(0, 10, 20, lift=-20))
    c.clip("Roar", [
        key(0, G, ease("CubicV2", "Out")),
        key(0.3, merge(c.paws(drop=-0.45, spread=0.1), waist(0, -4), neck(0, -25), jaw(10)), ease("CubicV2", "Out"), name="Inhale"),
        key(0.55, howl, ease("CubicV2", "InOut"), name="Roar", markers=["Roar"]),
        key(0.75, merge(howl, neck(8, 34), {"RightShoulder": {"aim": [0.25, -0.5, 0.85]}, "LeftShoulder": {"aim": [-0.25, -0.2, 1]}}), ease("CubicV2", "InOut")),
        key(0.95, merge(howl, neck(-8, 34)), ease("CubicV2", "InOut")),
        key(1.2, merge(c.paws(drop=-0.3, spread=0.1), neck(0, 10), jaw(30)), ease("Bounce", "Out"), name="Land", markers=["Thud"]),
        key(1.5, G),
    ], flags=())
    # Ataque à distância e salto usam o bote
    c.clip("CastOverhead", [
        key(0, G, ease("CubicV2", "Out")),
        key(0.22, merge(c.paws(drop=-0.6, spread=0.1, front=-0.2, back=0.15), c.root(-0.6, -0.3, 0, 12), neck(0, 20), jaw(40)), ease("Linear", "In"), name="Charge"),
        key(0.3, merge(lunge, c.root(-0.3, 0.45, 0, -6), neck(0, -20), jaw(0)), ease("CubicV2", "Out"), name="Release", markers=["Release"]),
        key(0.7, merge(lunge, c.root(-0.35, 0.5), neck(0, -12), jaw(6)), ease("CubicV2", "InOut")),
        key(1.0, G),
    ])
    # Morte: tomba de lado, patas soltas, cabeça cai
    side = {"Root": {"position": [0.5, -1.05, 0], "rotation": [0, 0, -85]}}
    limp = {"RightShoulder": {"aim": [0.6, -0.2, 0.8]}, "LeftShoulder": {"aim": [0.5, -0.4, 0.75]},
            "RightHip": {"aim": [0.6, -0.3, -0.7]}, "LeftHip": {"aim": [0.5, -0.45, -0.7]}}
    c.clip("Death", [
        key(0, G, ease("CubicV2", "Out")),
        key(0.15, merge(c.paws(drop=-0.45, spread=0.12, front=-0.1, back=0.1), c.root(-0.45, -0.15, 0, 6), neck(0, 30), jaw(40), tail(0, 0, 0, lift=25)), ease("CubicV2", "InOut"), name="Impact", markers=["Impact"]),
        key(0.65, merge(side, limp, waist(0, 0, -6), neck(-10, -20), jaw(20), tail(10, 10, 10, lift=-20)), ease("Bounce", "Out"), name="Fall", markers=["Thud"]),
        key(1.2, merge(side, limp, waist(0, 0, -6), neck(-12, -22), jaw(24), tail(14, 12, 10, lift=-22))),
    ], flags=())


# ============================================================================ MENOS GRANDE
def menos(c):
    G = merge(c.feet(drop=-0.05, width=0.1), waist(0, -3), neck(0, -6), arms([0.45, -0.85, 0.2], 25, [-0.45, -0.85, 0.2], 25))
    c.guard = G
    # Parado: o corpo enorme oscila devagar, a cabeça inclina, as mangas balançam
    c.clip("Idle", [
        key(0, merge(G, waist(0, -3, 3), neck(-6, -6, -4)), ease("CubicV2", "InOut")),
        key(2.0, merge(G, c.feet(drop=-0.12, width=0.1), waist(0, -5, -3), neck(6, -9, 4), arms([0.5, -0.82, 0.25], 30, [-0.4, -0.88, 0.15], 20)), ease("CubicV2", "InOut")),
        key(4.0, merge(G, waist(0, -3, 3), neck(-6, -6, -4))),
    ], loop=True, priority="Idle")
    # Andar arrastado: passada curta e lenta, tronco balança de lado
    c.raw("Walk", {"loop": True, "priority": "Movement", "duration": 1.5,
                   "gait": {"pattern": "walk", "stride": 1.2, "lift": 0.18, "bob": 0.1},
                   "keyframes": [key(0, merge(waist(-4, -4, 4), neck(4, -6), arms([0.45, -0.85, 0.05], 25, [-0.45, -0.85, 0.35], 25)), ease("CubicV2", "InOut")),
                                 key(0.75, merge(waist(4, -4, -4), neck(-4, -6), arms([0.45, -0.85, 0.35], 25, [-0.45, -0.85, 0.05], 25)), ease("CubicV2", "InOut")),
                                 key(1.5, merge(waist(-4, -4, 4), neck(4, -6), arms([0.45, -0.85, 0.05], 25, [-0.45, -0.85, 0.35], 25)))]},
          flags=["--locomotion"], ground_speed=True)
    c.raw("Run", {"loop": True, "priority": "Movement", "duration": 0.95,
                  "gait": {"pattern": "walk", "stride": 1.7, "duty": 0.6, "lift": 0.25, "bob": 0.14},
                  "keyframes": [key(0, merge(waist(-5, -10, 5), neck(5, 4), arms([0.5, -0.8, -0.1], 30, [-0.5, -0.75, 0.45], 35)), ease("CubicV2", "InOut")),
                                key(0.475, merge(waist(5, -10, -5), neck(-5, 4), arms([0.5, -0.75, 0.45], 35, [-0.5, -0.8, -0.1], 30)), ease("CubicV2", "InOut")),
                                key(0.95, merge(waist(-5, -10, 5), neck(5, 4), arms([0.5, -0.8, -0.1], 30, [-0.5, -0.75, 0.45], 35)))]},
          flags=["--locomotion"], ground_speed=True)
    stance = c.feet(drop=-0.15, width=0.12, front=0.25, back=-0.2)
    # Golpe leve: varrida larga com o braço direito (a manga rasga o ar)
    w, d = LIGHT[0]
    c.clip("Slash1", [
        key(0, G, ease("Linear", "In")),
        key(w * 0.55, merge(stance, waist(-25, -2), neck(10, -4), arms([1, 0.15, -0.3], 30, [-0.45, -0.8, 0.3], 25)), ease("Linear", "In"), name="WindUp"),
        key(w, merge(stance, waist(10, -8), neck(-5, -8), arms([0.2, -0.3, 1], 10, [-0.45, -0.85, 0.2], 25)), ease("Linear", "In"), name="Hit", markers=["Hit"]),
        key(w + 0.12, merge(stance, waist(25, -8), neck(-10, -8), arms([-0.6, -0.4, 0.7], 15, [-0.45, -0.85, 0.15], 25)), ease("CubicV2", "Out")),
        key(d, merge(stance, waist(15, -5), arms([-0.3, -0.75, 0.55], 20, [-0.45, -0.85, 0.2], 25)), ease("CubicV2", "InOut")),
        key(d + 0.45, G),
    ])
    # Esmagar (pesado e habilidade de área): ergue os dois braços e desce com o corpo todo
    def slam(name, w, d, release_marker=False):
        hit_markers = ["Release"] if release_marker else ["Hit"]
        c.clip(name, [
            key(0, G, ease("CubicV2", "Out")),
            key(w * 0.35, merge(c.feet(drop=-0.05, width=0.12), waist(0, 6), neck(0, 8), arms([0.95, 0.2, 0.15], 30, [-0.95, 0.2, 0.15], 30, [0, 1, 0], [0, 1, 0])), ease("Linear", "In")),
            key(w * 0.7, merge(c.feet(drop=0.0, width=0.12), waist(0, 14), neck(0, 18), arms([0.35, 1, -0.15], 40, [-0.35, 1, -0.15], 40, [0, 0, -1], [0, 0, -1])), ease("Linear", "In"), name="Raise" if release_marker else "WindUp", markers=None if release_marker else ["Swing"]),
            key(w, merge(c.feet(drop=-0.5, width=0.12, front=0.3, back=-0.2), c.root(-0.5, 0.25), waist(0, -24), neck(0, -14), arms([0.3, -0.6, 0.75], 5, [-0.3, -0.6, 0.75], 5, [0, 1, 0], [0, 1, 0])), ease("Linear", "In"), name="Hit", markers=hit_markers),
            key(w + 0.2, merge(c.feet(drop=-0.55, width=0.12, front=0.3, back=-0.2), c.root(-0.55, 0.3), waist(0, -28), neck(0, -16), arms([0.3, -0.75, 0.6], 8, [-0.3, -0.75, 0.6], 8, [0, 1, 0], [0, 1, 0])), ease("CubicV2", "Out")),
            key(d, merge(G, waist(0, -12)), ease("CubicV2", "InOut")),
            key(d + 0.5, G),
        ])
    slam("HeavySlash", *HEAVY)
    slam("CastOverhead", 0.6, 1.3, release_marker=True)
    # Cero: a cabeça vai para trás juntando energia e projeta para a frente na descarga
    c.clip("CastCharge", [
        key(0, G, ease("CubicV2", "Out")),
        key(0.9, merge(c.feet(drop=-0.1, width=0.15, front=0.2, back=-0.3), c.root(-0.1, -0.15, 0, 8), waist(0, 14), neck(0, 30), arms([0.85, -0.2, 0.3], 30, [-0.85, -0.2, 0.3], 30)), ease("Linear", "In"), name="Charge"),
        key(1.3, merge(c.feet(drop=-0.3, width=0.15, front=0.3, back=-0.3), c.root(-0.3, 0.2), waist(0, -14), neck(0, -22), arms([0.75, -0.55, -0.2], 25, [-0.75, -0.55, -0.2], 25)), ease("CubicV2", "Out"), name="Release", markers=["Release"]),
        key(2.0, merge(c.feet(drop=-0.3, width=0.15, front=0.3, back=-0.3), c.root(-0.3, 0.2), waist(0, -12), neck(0, -18), arms([0.75, -0.55, -0.2], 25, [-0.75, -0.55, -0.2], 25)), ease("CubicV2", "InOut")),
        key(2.5, G),
    ])

    def reaction(name, peak, duration, at=0.1, hold=0.55):
        c.clip(name, [key(0, G, ease("Linear", "In")), key(at, peak, ease("CubicV2", "Out"), name="Impact"),
                      key(duration * hold, peak, ease("CubicV2", "InOut")), key(duration, G)])

    reaction("Hit1", merge(c.feet(drop=-0.15, width=0.12), c.root(-0.15, -0.15, 5), waist(6, 8, 4), neck(8, 12), arms([0.6, -0.6, 0.1], 30, [-0.5, -0.8, 0.1], 25)), 0.6)
    reaction("Hit2", merge(c.feet(drop=-0.15, width=0.12), c.root(-0.15, -0.15, -5), waist(-6, 8, -4), neck(-8, 12), arms([0.5, -0.8, 0.1], 25, [-0.6, -0.6, 0.1], 30)), 0.6)
    reaction("Stagger", merge(c.feet(drop=-0.3, width=0.15, front=0.1, back=-0.4), c.root(-0.3, -0.35, 0, 6), waist(0, 14), neck(0, 20), arms([0.8, -0.2, 0.1], 25, [-0.8, -0.2, 0.1], 25)), 1.1)
    reaction("GuardBreak", merge(c.feet(drop=-0.3, width=0.15, front=0.1, back=-0.4), c.root(-0.3, -0.35, 0, 6), waist(0, 16), neck(0, 22), arms([0.7, 0.4, 0.1], 25, [-0.7, 0.4, 0.1], 25)), 1.2, hold=0.7)
    reaction("Parried", merge(c.feet(drop=-0.2, width=0.12, front=0.1, back=-0.3), c.root(-0.2, -0.25, 8), waist(8, 10), neck(5, 14), arms([0.7, 0.3, 0.0], 30, [-0.5, -0.8, 0.2], 25)), 1.0, at=0.12, hold=0.65)
    reaction("Launched", merge(c.feet(drop=-0.35, width=0.15, front=0.1, back=-0.4), c.root(-0.35, -0.4, 0, 8), waist(0, 18), neck(0, 24), arms([0.85, 0.1, 0.1], 25, [-0.85, 0.1, 0.1], 25)), 1.2)
    # Rugido: cabeça para cima, mangas abertas, tremor
    roar = merge(c.feet(drop=0.0, width=0.12), c.root(0.0, -0.1, 0, 6), waist(0, 12), neck(0, 32), arms([1, 0.2, -0.1], 25, [-1, 0.2, -0.1], 25))
    c.clip("Roar", [
        key(0, G, ease("CubicV2", "Out")),
        key(0.4, merge(c.feet(drop=-0.25, width=0.12), waist(0, -10), neck(0, -14), arms([0.4, -0.8, 0.4], 40, [-0.4, -0.8, 0.4], 40)), ease("CubicV2", "Out"), name="Inhale"),
        key(0.75, roar, ease("CubicV2", "InOut"), name="Roar", markers=["Roar"]),
        key(1.0, merge(roar, neck(6, 34)), ease("CubicV2", "InOut")),
        key(1.25, merge(roar, neck(-6, 34)), ease("CubicV2", "InOut")),
        key(1.5, roar, ease("CubicV2", "InOut")),
        key(2.0, G),
    ])
    # Morte: perde a força, ajoelha dentro do manto e tomba de lado devagar
    stand_legs = {"Root": {"position": [0, -0.05, 0]}, "RightHip": {"aim": [0.12, -1, 0.1]}, "RightKnee": {"bend": 15},
                  "LeftHip": {"aim": [-0.12, -1, -0.05]}, "LeftKnee": {"bend": 15}}
    G_death = merge({k: v for k, v in G.items() if k not in ("Root", "RightHip", "LeftHip")}, stand_legs)
    down = {"Root": {"position": [0, -1.6, 0.1], "rotation": [-10, 0, 0]},
            "RightHip": {"aim": [0.15, -0.35, 0.9]}, "RightKnee": {"bend": 120}, "LeftHip": {"aim": [-0.15, -0.35, 0.9]}, "LeftKnee": {"bend": 120}}
    fallen = {"Root": {"position": [1.2, -2.7, 0.1], "rotation": [-10, 0, -78]},
              "RightHip": {"aim": [0.15, -0.35, 0.9]}, "RightKnee": {"bend": 100}, "LeftHip": {"aim": [-0.15, -0.4, 0.85]}, "LeftKnee": {"bend": 90}}
    c.clip("Death", [
        key(0, G_death, ease("CubicV2", "Out")),
        key(0.25, merge(G_death, waist(0, 16), neck(0, 26), arms([0.9, 0.2, 0.1], 25, [-0.9, 0.2, 0.1], 25)), ease("CubicV2", "InOut"), name="Impact", markers=["Impact"]),
        key(1.0, merge(down, waist(0, -10), neck(0, -20), arms([0.4, -0.9, 0.2], 20, [-0.4, -0.9, 0.2], 20)), ease("CubicV2", "In"), name="Knees", markers=["Thud"]),
        key(1.7, merge(fallen, waist(0, -6), neck(-15, -10), arms([0.6, -0.5, 0.4], 30, [-0.9, 0.3, 0.1], 20)), ease("Bounce", "Out"), name="Fall", markers=["Thud"]),
        key(2.3, merge(fallen, waist(0, -6), neck(-18, -10), arms([0.6, -0.5, 0.4], 30, [-0.9, 0.3, 0.1], 22))),
    ], flags=(), waive=("rootDrift",))  # termina caído de propósito: o jogo segura o último quadro


def author_all(out, manifest):
    for body, fn in (("HollowGrunt", grunt), ("HollowBrute", brute), ("HollowHound", hound), ("MenosGrande", menos)):
        fn(Creature(body, out, manifest))

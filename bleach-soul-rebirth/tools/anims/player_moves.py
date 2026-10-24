#!/usr/bin/env python3
"""Locomoção própria do jogador (substitui o Animate padrão do Roblox).
Dois conjuntos, escolhidos pelo AnimController conforme a espada está sacada ou não:
  Hero*  — espada embainhada: postura relaxada, corrida de anime com o tronco inclinado
  Sword* — espada na mão: base de luta, lâmina baixa para trás ao correr
Cada conjunto: Idle, Walk, Run, Sprint (marchas por `gait` da skill: pés plantados sem
deslizar, velocidade de chão medida), Jump e Fall.
Velocidades do jogo (Config/Combat): andar 18, disparada 27 studs/s. As marchas são
autoradas perto dessas velocidades para a taxa de reprodução ficar perto de 1."""
import json, os


def ease(style="CubicV2", direction="InOut"):
    return {"style": style, "direction": direction}


def key(time, joints, easing=None, name=None):
    k = {"time": round(time, 4), "joints": json.loads(json.dumps(joints))}
    if easing:
        k["easing"] = easing
    if name:
        k["name"] = name
    return k


def merge(*dicts):
    out = {}
    for d in dicts:
        out.update(d)
    return out


def arms(r_aim, r_bend, l_aim, l_bend, weapon=None):
    j = {"RightShoulder": {"aim": r_aim}, "RightElbow": {"bend": r_bend},
         "LeftShoulder": {"aim": l_aim}, "LeftElbow": {"bend": l_bend}}
    if weapon is not None:
        j["Weapon"] = {"rotation": weapon}
    return j


def waist(yaw=0, pitch=0, roll=0):
    return {"Waist": {"rotation": [pitch, yaw, roll]}}


def neck(yaw=0, pitch=0):
    return {"Neck": {"rotation": [pitch, yaw, 0]}}


def stance(width=0.62, front=0.3, back=-0.3, drop=-0.15, shift=0.0):
    return {"Root": {"position": [shift, drop, 0]},
            "RightHip": {"aimAt": [width * 0.85, -2.93, front]}, "LeftHip": {"aimAt": [-width * 0.85, -2.93, back]}}


def author(out, manifest, blade_aim):
    """blade_aim(pose, target) devolve a pose com Weapon.rotation apontando a lâmina (author.blade)."""
    def write(name, data, flags, ground_speed=False):
        data = dict(data, name=name, rig="R15")
        json.dump(data, open(os.path.join(out, name + ".json"), "w"), indent=1)
        manifest[name] = {"flags": flags, "waive": [], "groundSpeedFromReport": ground_speed}

    def gait(name, duration, stride, duty, lift, bob, upper_a, upper_b, crouch=0):
        """Marcha: o gait move quadril e pernas; as chaves animam só o tronco e os braços,
        balançando em oposição às pernas (meio ciclo cada lado)."""
        g = {"pattern": "walk", "stride": stride, "duty": duty, "lift": lift, "bob": bob}
        if crouch:
            g["crouch"] = crouch
        write(name, {"loop": True, "priority": "Movement", "duration": duration, "gait": g,
                     "keyframes": [key(0, upper_a, ease()), key(duration / 2, upper_b, ease()), key(duration, upper_a)]},
              ["--locomotion"], ground_speed=True)

    # ------------------------------------------------------------------ HERO (embainhada)
    # Parado: respira (peito sobe/desce), passa o peso de uma perna para a outra, ombros e cabeça
    # acompanham; cotovelos soltos e levemente dobrados (nada de braço reto de boneco)
    relaxed_a = merge(stance(drop=-0.1), waist(0, 0, 0), neck(0, 0), arms([0.2, -1, 0.06], 20, [-0.2, -1, 0.05], 22))
    relaxed_b = merge(stance(drop=-0.17, shift=0.07), waist(5, 4, -3), neck(-7, -3),
                      arms([0.24, -1, 0.12], 30, [-0.19, -1, 0.0], 18))
    relaxed_c = merge(stance(drop=-0.13, shift=-0.07), waist(-4, 2, 3), neck(6, 1),
                      arms([0.19, -1, 0.0], 18, [-0.24, -1, 0.12], 30))
    write("HeroIdle", {"loop": True, "priority": "Idle", "easing": ease(),
                       "keyframes": [key(0, relaxed_a), key(1.3, relaxed_b), key(2.6, relaxed_a), key(3.9, relaxed_c), key(5.2, relaxed_a)]}, [])
    # Andar (velocidades baixas: analógico parcial, aproximação)
    gait("HeroWalk", 0.5, 1.9, 0.6, 0.3, 0.06,
         merge(waist(-9, -3, 2), neck(7, 2), arms([0.12, -1, 0.6], 32, [-0.12, -1, -0.45], 12)),
         merge(waist(9, -3, -2), neck(-7, 2), arms([0.12, -1, -0.45], 12, [-0.12, -1, 0.6], 32)))
    # Corrida (18 studs/s): tronco inclinado, braços dobrados bombeando, ombros contra o quadril
    gait("HeroRun", 0.36, 2.3, 0.36, 0.38, 0.12,
         merge(waist(-10, -14), neck(8, 10), arms([0.12, -0.75, -0.65], 80, [-0.12, -0.55, 0.8], 95)),
         merge(waist(10, -14), neck(-8, 10), arms([0.12, -0.55, 0.8], 95, [-0.12, -0.75, -0.65], 80)))
    # Disparada (27 studs/s, Shift): bem inclinado, braços para trás (corrida de anime)
    sprint_arms = merge(waist(0, -26), neck(0, 22), arms([0.35, -0.35, -0.85], 20, [-0.35, -0.35, -0.85], 20))
    gait("HeroSprint", 0.31, 2.4, 0.3, 0.36, 0.08,
         merge(sprint_arms, waist(-6, -26)), merge(sprint_arms, waist(6, -26)))

    # Pulo: braços abrem e sobem, joelhos recolhem. Queda: braços abertos, pernas soltas.
    jump_pose = merge(waist(0, -8), neck(0, 6), arms([0.55, 0.6, 0.25], 25, [-0.55, 0.6, 0.25], 25),
                      {"RightHip": {"aim": [0.1, -0.85, 0.5]}, "RightKnee": {"bend": 70},
                       "LeftHip": {"aim": [-0.1, -1, 0.1]}, "LeftKnee": {"bend": 35}})
    fall_pose = merge(waist(0, 6), neck(0, 8), arms([0.9, 0.2, 0.1], 30, [-0.9, 0.25, 0.05], 35),
                      {"RightHip": {"aim": [0.15, -1, 0.25]}, "RightKnee": {"bend": 30},
                       "LeftHip": {"aim": [-0.15, -1, -0.1]}, "LeftKnee": {"bend": 20}})
    base_air = merge(waist(0, 0), neck(0, 0), arms([0.1, -1, 0], 10, [-0.1, -1, 0], 10),
                     {"RightHip": {"aim": [0.05, -1, 0]}, "RightKnee": {"bend": 5}, "LeftHip": {"aim": [-0.05, -1, 0]}, "LeftKnee": {"bend": 5}})
    write("HeroJump", {"loop": False, "priority": "Movement",
                       "keyframes": [key(0, base_air, ease("CubicV2", "Out")), key(0.25, jump_pose)]}, [])
    write("HeroFall", {"loop": True, "priority": "Movement", "easing": ease(),
                       "keyframes": [key(0, fall_pose), key(0.6, merge(fall_pose, arms([0.95, 0.3, 0.05], 25, [-0.95, 0.3, 0.0], 30))), key(1.2, fall_pose)]}, [])

    # ------------------------------------------------------------------ SWORD (espada na mão)
    # Guarda baixa (wakigamae solta): espada na mão direita ao lado do corpo, lâmina para a frente e
    # para baixo, bem longe do peito e do rosto; mão esquerda livre e pronta. Antes a guarda era
    # alta, com as mãos na frente do peito e a lâmina subindo na frente do rosto: vista de trás, a
    # espada parecia "no peito". Folga conferida em tools/sim/weapon_scenario.luau.
    guard_a = blade_aim(merge(stance(width=0.75, front=0.45, back=-0.45, drop=-0.28), waist(-16, -4), neck(14, 0),
                              arms([0.55, -0.7, 0.45], 30, [-0.3, -0.85, 0.35], 40)), [0.45, -0.3, 1])
    guard_b = blade_aim(merge(stance(width=0.75, front=0.45, back=-0.45, drop=-0.34), waist(-14, -6), neck(12, -2),
                              arms([0.55, -0.66, 0.48], 34, [-0.3, -0.82, 0.38], 44)), [0.45, -0.26, 1])
    write("SwordIdle", {"loop": True, "priority": "Idle", "easing": ease(),
                        "keyframes": [key(0, guard_a), key(1.2, guard_b), key(2.4, guard_a)]}, ["--grounded"])
    sw_walk_a = blade_aim(merge(waist(-12, -4), neck(10, 0), arms([0.55, -0.72, 0.42], 28, [-0.2, -1, 0.3], 20)), [0.45, -0.3, 1])
    sw_walk_b = blade_aim(merge(waist(-6, -4), neck(6, 0), arms([0.55, -0.7, 0.45], 30, [-0.2, -1, -0.3], 20)), [0.45, -0.3, 1])
    gait("SwordWalk", 0.5, 1.9, 0.6, 0.3, 0.06, sw_walk_a, sw_walk_b, crouch=0.15)
    # Corrida com a lâmina baixa apontando para trás; braço livre bombeia
    sw_run_a = blade_aim(merge(waist(-8, -16), neck(8, 12), arms([0.35, -0.8, -0.4], 15, [-0.12, -0.55, 0.8], 95)), [0.2, -0.3, -1])
    sw_run_b = blade_aim(merge(waist(8, -16), neck(-4, 12), arms([0.35, -0.8, -0.25], 20, [-0.12, -0.75, -0.6], 80)), [0.2, -0.3, -1])
    gait("SwordRun", 0.36, 2.3, 0.36, 0.38, 0.12, sw_run_a, sw_run_b, crouch=0.1)
    sw_sprint = blade_aim(merge(waist(0, -28), neck(0, 24), arms([0.4, -0.3, -0.85], 15, [-0.4, -0.3, -0.85], 20)), [0.25, 0.1, -1])
    gait("SwordSprint", 0.31, 2.4, 0.3, 0.36, 0.12, merge(sw_sprint, waist(-6, -28)), merge(sw_sprint, waist(6, -28)), crouch=0.1)
    write("SwordJump", {"loop": False, "priority": "Movement",
                        "keyframes": [key(0, merge(base_air, {"Weapon": guard_a["Weapon"]}), ease("CubicV2", "Out")),
                                      key(0.25, merge(jump_pose, arms([0.55, 0.3, 0.4], 50, [-0.55, 0.6, 0.25], 25), {"Weapon": guard_a["Weapon"]}))]}, [])
    sw_fall = blade_aim(merge(fall_pose, arms([0.85, 0.0, 0.35], 40, [-0.9, 0.25, 0.05], 35)), [0.6, 0.3, -0.7])
    write("SwordFall", {"loop": True, "priority": "Movement", "easing": ease(),
                        "keyframes": [key(0, sw_fall), key(0.6, merge(sw_fall, arms([0.88, 0.05, 0.3], 38, [-0.95, 0.3, 0.0], 30))), key(1.2, sw_fall)]}, [])

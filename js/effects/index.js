// Central de efeitos: reúne todos os sistemas e oferece "receitas" prontas
// (explosão completa, queda de raio, faíscas de carga...) já sincronizadas
// com tremor de câmera, clarão de tela e som.
import * as THREE from 'three';
import { CONFIG } from '../config.js';
import { GlowParticles, SparkLines, Smoke, Debris } from './particles.js';
import { LightningSystem } from './lightning.js';
import { ExplosionSystem } from './explosion.js';
import { MagicCircle, LightPillar } from './magicCircle.js';
import { Beam } from './beam.js';
import { rand, randomDir } from '../utils.js';

const MG = CONFIG.magic;

export class FX {
  /**
   * hooks: { shake(amount), flash(amount), aberration(amount), audio, env }
   */
  constructor(scene, hooks) {
    this.scene = scene;
    this.hooks = hooks;
    this.glow = new GlowParticles(scene);
    this.sparks = new SparkLines(scene);
    this.smoke = new Smoke(scene);
    this.debris = new Debris(scene);
    this.lightning = new LightningSystem(scene);
    this.explosions = new ExplosionSystem(scene);
    this.circle = new MagicCircle(scene, 3);
    this.footCircle = new MagicCircle(scene, 1.1);
    this.footCircle.spin = 1.2;
    this.pillar = new LightPillar(scene);
    this.beam = new Beam(scene);
    this.emberRate = 60;     // brasas ambientes por segundo
    this._emberAcc = 0;
    this._v = new THREE.Vector3();
  }

  get audio() { return this.hooks.audio; }

  // ---------------------------------------------------------------------------
  //  Receitas
  // ---------------------------------------------------------------------------
  /** Explosão mágica completa. power: 0.3 (pequena) .. 3 (gigante). */
  explode(pos, power = 1, o = {}) {
    const p = pos.clone();
    this.explosions.spawn(p, 1.4 * power, { duration: 1.1 + power * 0.35, ...o });
    this.glow.burst(p, Math.floor(260 * power), {
      speed: [2 * power, 11 * power], life: [0.5, 1.6], size: [0.14 * Math.sqrt(power), 0.01],
      color: [MG.core, MG.amber], gravity: -4, drag: 2.4, upBias: 0.3, intensity: 2.2,
    });
    this.glow.burst(p, Math.floor(120 * power), {
      speed: [0.5, 3 * power], life: [1.5, 3.5], size: [0.05, 0.0], color: [MG.gold, MG.deep], gravity: 0.6, drag: 1.2,
    });
    this.sparks.burst(p, Math.floor(160 * power), { speed: [8 * power, 22 * power], hemisphere: true, length: 0.04 });
    this.smoke.puff(p, Math.floor(26 * power), {
      speed: [1, 4 * power], radius: 0.6 * power, size0: [0.8 * power, 1.4 * power], size1: [3 * power, 5 * power],
      life: [2.5, 5.5], heat: 1, rise: 0.8, delay: 0.25,
    });
    if (p.y < 1.5) this.debris.burst(p, Math.floor(30 * power), { speed: [3 * power, 10 * power] });
    this.hooks.shake(0.35 + power * 0.35);
    this.hooks.flash(Math.min(1, 0.25 + power * 0.3));
    this.hooks.aberration(0.4 + power * 0.25);
    if (this.hooks.env) this.hooks.env.glow = Math.min(1.5, this.hooks.env.glow + power * 0.5);
    this.audio?.boom(power);
  }

  /** Raio caindo do céu num ponto do chão. */
  strike(ground, o = {}) {
    const top = ground.clone().add(new THREE.Vector3(rand(-3, 3), 22, rand(-3, 3)));
    this.lightning.bolt(top, ground, { width: o.width ?? 0.45, life: o.life ?? 0.5, branches: 4, depth: 7, rough: 0.12 });
    this.glow.burst(ground, 90, { speed: [2, 9], life: [0.3, 0.9], size: [0.12, 0.01], color: [MG.core, MG.gold], intensity: 2.5, hemisphere: true });
    this.sparks.burst(ground, 70, { speed: [6, 16], hemisphere: true });
    this.smoke.puff(ground, 6, { speed: [0.5, 2], size0: [0.5, 0.8], size1: [1.8, 3], heat: 1, life: [1.5, 3] });
    this.explosions.ring(ground, 3.5, 0.7);
    this.explosions.light.position.copy(ground).add(this._v.set(0, 2, 0));
    this.explosions.lightLevel = Math.max(this.explosions.lightLevel, 14);
    this.hooks.shake(o.shake ?? 0.35);
    this.hooks.flash(o.flash ?? 0.35);
    this.audio?.crack();
  }

  /** Pequenos arcos elétricos saindo de um ponto (crepitar). */
  arcs(from, count = 2, reach = 0.9) {
    for (let i = 0; i < count; i++) {
      const to = from.clone().add(randomDir().multiplyScalar(rand(reach * 0.4, reach)));
      this.lightning.bolt(from, to, { width: 0.06, life: rand(0.08, 0.18), branches: 1, depth: 4, rough: 0.3 });
    }
  }

  /** Partículas sendo sugadas para um ponto (carregar energia). */
  converge(target, count = 8, radius = 3) {
    for (let i = 0; i < count; i++) {
      const p = target.clone().add(randomDir().multiplyScalar(rand(radius * 0.5, radius)));
      this.glow.spawn({
        pos: p, vel: randomDir().multiplyScalar(0.5),
        life: 1.6, size: [0.05, 0.11], color: [MG.gold, MG.core], drag: 2.5, attract: 9, target, intensity: 2,
      });
    }
  }

  /** Espiral ascendente de energia ao redor de um ponto. */
  spiral(center, time, count = 6, radius = 1.2) {
    for (let i = 0; i < count; i++) {
      const a = time * 4 + (i / count) * Math.PI * 2;
      const p = new THREE.Vector3(center.x + Math.cos(a) * radius, center.y + rand(-0.5, 0.2), center.z + Math.sin(a) * radius);
      const v = new THREE.Vector3(-Math.sin(a) * 2, rand(2, 4), Math.cos(a) * 2);
      this.glow.spawn({ pos: p, vel: v, life: rand(0.8, 1.6), size: [0.07, 0.0], color: [MG.core, MG.amber], drag: 0.8, intensity: 1.8 });
    }
  }

  clear() {
    this.glow.clear(); this.sparks.clear(); this.smoke.clear(); this.debris.clear();
    this.lightning.clear(); this.explosions.clear();
    this.circle.reset(); this.footCircle.reset(); this.pillar.reset(); this.beam.reset();
    this.emberRate = 60;
  }

  update(dt, time, camera, viewportH) {
    // brasas ambientes subindo pela arena
    this._emberAcc += dt * this.emberRate;
    while (this._emberAcc >= 1) {
      this._emberAcc -= 1;
      const a = Math.random() * Math.PI * 2, r = Math.sqrt(Math.random()) * 14;
      this.glow.spawn({
        pos: this._v.set(Math.cos(a) * r, rand(0, 1), Math.sin(a) * r).clone(),
        vel: new THREE.Vector3(rand(-0.3, 0.3), rand(0.4, 1.2), rand(-0.3, 0.3)),
        life: rand(3, 6), size: [0.045, 0.01], color: [MG.amber, MG.deep], drag: 0.2, gravity: 0.05, intensity: 1.4,
      });
    }
    this.glow.update(dt, viewportH, camera.fov);
    this.smoke.update(dt, viewportH, camera.fov);
    this.sparks.update(dt);
    this.debris.update(dt);
    this.lightning.update(dt, camera);
    this.explosions.update(dt, time);
    this.circle.update(dt, time);
    this.footCircle.update(dt, time);
    this.pillar.update(dt, time);
  }
}

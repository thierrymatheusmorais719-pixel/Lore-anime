// Diretor de câmera: planos com movimento (dolly, órbita, travelling),
// cortes secos entre planos e tremor baseado em "trauma".
import * as THREE from 'three';
import { ease, lerp, wobble } from './utils.js';

/**
 * Um plano (shot):
 * {
 *   start, end,                       // segundos
 *   from: { pos, target, fov, roll }, // pos/target: Vector3 ou função () => Vector3
 *   to:   { pos, target, fov, roll },
 *   ease: função de easing,
 *   orbit: { center, radius:[a,b], angle:[a,b], height:[a,b] } // opcional
 * }
 */
export class CameraDirector {
  constructor(camera) {
    this.camera = camera;
    this.shots = [];
    this.trauma = 0;
    this.time = 0;
    this.enabled = true;
    this._p = new THREE.Vector3();
    this._t = new THREE.Vector3();
    this._a = new THREE.Vector3();
    this._b = new THREE.Vector3();
    this.lookAt = new THREE.Vector3();
  }

  setShots(shots) { this.shots = shots.slice().sort((a, b) => a.start - b.start); }

  shake(amount) { this.trauma = Math.min(1.2, this.trauma + amount); }

  reset() { this.trauma = 0; }

  _val(v, out) {
    if (typeof v === 'function') return out.copy(v());
    return out.copy(v);
  }

  update(dt, time) {
    this.time = time;
    this.trauma = Math.max(0, this.trauma - dt * 1.1);
    if (!this.enabled) return;

    let shot = this.shots[0];
    for (const s of this.shots) if (time >= s.start) shot = s;
    if (!shot) return;
    const k = (shot.ease || ease.inOutSine)(Math.min(1, Math.max(0, (time - shot.start) / (shot.end - shot.start))));
    const cam = this.camera;

    if (shot.orbit) {
      const o = shot.orbit;
      const c = this._val(o.center, this._t);
      const ang = lerp(o.angle[0], o.angle[1], k);
      const r = lerp(o.radius[0], o.radius[1], k);
      const h = lerp(o.height[0], o.height[1], k);
      this._p.set(c.x + Math.sin(ang) * r, c.y + h, c.z + Math.cos(ang) * r);
      this.lookAt.copy(c);
    } else {
      this._val(shot.from.pos, this._a);
      this._val(shot.to.pos, this._b);
      this._p.lerpVectors(this._a, this._b, k);
      this._val(shot.from.target, this._a);
      this._val(shot.to.target, this._b);
      this.lookAt.lerpVectors(this._a, this._b, k);
    }
    const fov = lerp(shot.from?.fov ?? 40, shot.to?.fov ?? shot.from?.fov ?? 40, k);
    const roll = lerp(shot.from?.roll ?? 0, shot.to?.roll ?? shot.from?.roll ?? 0, k);

    // tremor (trauma²) com ruído suave + leve "respiração" de câmera na mão
    const s = this.trauma * this.trauma;
    const t = time * 22;
    const hand = 0.012;
    cam.position.copy(this._p);
    cam.position.x += wobble(t, 1) * 0.28 * s + wobble(time * 0.7, 4) * hand;
    cam.position.y += wobble(t, 2) * 0.28 * s + wobble(time * 0.6, 5) * hand;
    cam.position.z += wobble(t, 3) * 0.2 * s;
    cam.lookAt(this.lookAt);
    cam.rotateZ(roll + wobble(t, 6) * 0.05 * s);
    if (cam.fov !== fov) { cam.fov = fov; cam.updateProjectionMatrix(); }
  }
}

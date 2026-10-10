// Linha do tempo: eventos pontuais (at), intervalos contínuos (during)
// e interpolações de propriedades (tween). Tudo é reiniciável.
import { ease as E } from './utils.js';

export class Timeline {
  constructor() {
    this.events = [];   // { t, fn, fired }
    this.ranges = [];   // { t0, t1, fn }
    this.tweens = [];   // ativos
    this.time = 0;
  }

  at(t, fn) { this.events.push({ t, fn, fired: false }); return this; }

  /** fn(progress 0..1, dt, time) chamado a cada quadro dentro de [t0, t1]. */
  during(t0, t1, fn) { this.ranges.push({ t0, t1, fn }); return this; }

  /** Interpola obj[key] até `to` em `dur` segundos (inicia agora). */
  tween(obj, key, to, dur, easing = E.inOutCubic) {
    this.tweens = this.tweens.filter((tw) => !(tw.obj === obj && tw.key === key));
    this.tweens.push({ obj, key, from: obj[key], to, dur: Math.max(0.0001, dur), t: 0, easing });
  }

  reset() {
    this.time = 0;
    for (const e of this.events) e.fired = false;
    this.tweens.length = 0;
  }

  update(dt, time) {
    this.time = time;
    for (const e of this.events) {
      if (!e.fired && time >= e.t) { e.fired = true; e.fn(time); }
    }
    for (const r of this.ranges) {
      if (time >= r.t0 && time < r.t1) r.fn((time - r.t0) / (r.t1 - r.t0), dt, time);
    }
    for (let i = this.tweens.length - 1; i >= 0; i--) {
      const tw = this.tweens[i];
      tw.t = Math.min(1, tw.t + dt / tw.dur);
      tw.obj[tw.key] = tw.from + (tw.to - tw.from) * tw.easing(tw.t);
      if (tw.t >= 1) this.tweens.splice(i, 1);
    }
  }
}

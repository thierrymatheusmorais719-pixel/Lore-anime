// Som 100% procedural com Web Audio (sem arquivos): drone ambiente,
// explosões graves, estalos de raio, carga ascendente e zumbido do feixe.
export class AudioEngine {
  constructor() {
    this.ctx = null;
    this.enabled = false;
    this.muted = false;
  }

  /** Precisa ser chamado a partir de um gesto do usuário (clique). */
  init() {
    if (this.ctx) return;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    this.ctx = new AC();
    const c = this.ctx;
    this.master = c.createGain();
    this.master.gain.value = 0.8;
    const comp = c.createDynamicsCompressor();
    comp.threshold.value = -14; comp.ratio.value = 6;
    this.master.connect(comp).connect(c.destination);
    // buffer de ruído branco reutilizável
    const len = c.sampleRate * 2;
    this.noise = c.createBuffer(1, len, c.sampleRate);
    const d = this.noise.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    this.enabled = true;
    this._startDrone();
  }

  get ok() { return this.enabled && !this.muted && this.ctx; }

  toggleMute() {
    this.muted = !this.muted;
    if (this.master) this.master.gain.setTargetAtTime(this.muted ? 0 : 0.8, this.ctx.currentTime, 0.05);
    return this.muted;
  }

  _noiseSrc() {
    const s = this.ctx.createBufferSource();
    s.buffer = this.noise; s.loop = true;
    s.loopStart = Math.random();
    return s;
  }

  _startDrone() {
    const c = this.ctx;
    const g = c.createGain(); g.gain.value = 0.0;
    const f = c.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 380; f.Q.value = 4;
    for (const fr of [55, 55.4, 82.5, 110.3]) {
      const o = c.createOscillator(); o.type = 'sawtooth'; o.frequency.value = fr;
      const og = c.createGain(); og.gain.value = 0.09;
      o.connect(og).connect(f); o.start();
    }
    const lfo = c.createOscillator(); lfo.frequency.value = 0.12;
    const lg = c.createGain(); lg.gain.value = 160;
    lfo.connect(lg).connect(f.frequency); lfo.start();
    f.connect(g).connect(this.master);
    this.droneGain = g;
    this.droneFilter = f;
    g.gain.setTargetAtTime(0.35, c.currentTime, 2);
  }

  /** Intensidade do drone (0..2). */
  swell(level, time = 1) {
    if (!this.ctx) return;
    this.droneGain.gain.setTargetAtTime(0.35 * level, this.ctx.currentTime, time / 3);
    this.droneFilter.frequency.setTargetAtTime(300 + level * 500, this.ctx.currentTime, time / 3);
  }

  boom(power = 1) {
    if (!this.ok) return;
    const c = this.ctx, t = c.currentTime;
    // ruído filtrado descendo
    const n = this._noiseSrc();
    const f = c.createBiquadFilter(); f.type = 'lowpass';
    f.frequency.setValueAtTime(2500, t);
    f.frequency.exponentialRampToValueAtTime(60, t + 1.2 + power * 0.5);
    const g = c.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(Math.min(1.4, 0.5 + power * 0.4), t + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 1.5 + power * 0.8);
    n.connect(f).connect(g).connect(this.master);
    n.start(t); n.stop(t + 2.5 + power);
    // pancada grave
    const o = c.createOscillator(); o.type = 'sine';
    o.frequency.setValueAtTime(90, t);
    o.frequency.exponentialRampToValueAtTime(28, t + 0.8);
    const og = c.createGain();
    og.gain.setValueAtTime(Math.min(1.5, 0.6 + power * 0.4), t);
    og.gain.exponentialRampToValueAtTime(0.0001, t + 1.2);
    o.connect(og).connect(this.master);
    o.start(t); o.stop(t + 1.3);
  }

  crack() {
    if (!this.ok) return;
    const c = this.ctx, t0 = c.currentTime;
    for (let i = 0; i < 4; i++) {
      const t = t0 + i * 0.035 + Math.random() * 0.02;
      const n = this._noiseSrc();
      const f = c.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = 1500 + Math.random() * 2000;
      const g = c.createGain();
      g.gain.setValueAtTime(0.7, t);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.12);
      n.connect(f).connect(g).connect(this.master);
      n.start(t); n.stop(t + 0.15);
    }
    // estrondo do trovão
    const n = this._noiseSrc();
    const f = c.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 300;
    const g = c.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(0.6, t0 + 0.08);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 1.4);
    n.connect(f).connect(g).connect(this.master);
    n.start(t0); n.stop(t0 + 1.5);
  }

  charge(duration = 3) {
    if (!this.ok) return;
    const c = this.ctx, t = c.currentTime;
    const o = c.createOscillator(); o.type = 'sawtooth';
    o.frequency.setValueAtTime(80, t);
    o.frequency.exponentialRampToValueAtTime(640, t + duration);
    const f = c.createBiquadFilter(); f.type = 'bandpass'; f.Q.value = 6;
    f.frequency.setValueAtTime(300, t);
    f.frequency.exponentialRampToValueAtTime(3000, t + duration);
    const trem = c.createOscillator(); trem.frequency.setValueAtTime(6, t); trem.frequency.linearRampToValueAtTime(26, t + duration);
    const tg = c.createGain(); tg.gain.value = 0.08;
    const g = c.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.18, t + duration * 0.9);
    g.gain.exponentialRampToValueAtTime(0.0001, t + duration + 0.2);
    trem.connect(tg).connect(g.gain);
    o.connect(f).connect(g).connect(this.master);
    o.start(t); trem.start(t); o.stop(t + duration + 0.3); trem.stop(t + duration + 0.3);
  }

  whoosh(dur = 0.6) {
    if (!this.ok) return;
    const c = this.ctx, t = c.currentTime;
    const n = this._noiseSrc();
    const f = c.createBiquadFilter(); f.type = 'bandpass'; f.Q.value = 2;
    f.frequency.setValueAtTime(300, t);
    f.frequency.exponentialRampToValueAtTime(2500, t + dur);
    const g = c.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.4, t + dur * 0.7);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    n.connect(f).connect(g).connect(this.master);
    n.start(t); n.stop(t + dur + 0.05);
  }

  chime() {
    if (!this.ok) return;
    const c = this.ctx, t = c.currentTime;
    [523.25, 659.25, 783.99, 1046.5, 1318.5].forEach((fr, i) => {
      const o = c.createOscillator(); o.type = 'sine'; o.frequency.value = fr;
      const g = c.createGain();
      const st = t + i * 0.07;
      g.gain.setValueAtTime(0.0001, st);
      g.gain.exponentialRampToValueAtTime(0.09, st + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, st + 2.2);
      o.connect(g).connect(this.master);
      o.start(st); o.stop(st + 2.3);
    });
  }

  beam(duration = 2.7) {
    if (!this.ok) return;
    const c = this.ctx, t = c.currentTime;
    const g = c.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.35, t + 0.1);
    g.gain.setValueAtTime(0.35, t + duration - 0.2);
    g.gain.exponentialRampToValueAtTime(0.0001, t + duration);
    const f = c.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 1800;
    for (const fr of [70, 140.5, 211]) {
      const o = c.createOscillator(); o.type = 'sawtooth'; o.frequency.value = fr;
      o.connect(f); o.start(t); o.stop(t + duration);
    }
    const n = this._noiseSrc();
    const nf = c.createBiquadFilter(); nf.type = 'highpass'; nf.frequency.value = 3000;
    const ng = c.createGain(); ng.gain.value = 0.3;
    n.connect(nf).connect(ng).connect(g);
    n.start(t); n.stop(t + duration);
    f.connect(g).connect(this.master);
  }
}

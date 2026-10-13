// Trilha e efeitos 100% sintetizados (Web Audio), sincronizados com film.js.
// A partitura é uma lista de eventos {t, dur, bus, play}. A mesma lista toca ao vivo
// (AudioContext) ou é renderizada offline (OfflineAudioContext) para exportar o vídeo.
import { rand } from './util.js';
import { HEARTBEATS, BOOM, FIRE, DURATION } from './film.js';

const hz = (m) => 440 * Math.pow(2, (m - 69) / 12);
const N = { C: 0, 'C#': 1, Db: 1, D: 2, Eb: 3, E: 4, F: 5, 'F#': 6, G: 7, Ab: 8, A: 9, Bb: 10, B: 11 };
const m = (s) => { const [, n, o] = s.match(/^([A-G][b#]?)(-?\d)$/); return 12 * (+o + 1) + N[n]; };

const BEAT = 0.5;            // 120 BPM; 1 compasso = 2 s, os cortes caem nos compassos
const BAR = 4 * BEAT;

// ---- instrumentos ----------------------------------------------------------------
// Cada função recebe (ac, out, when, dur, into) — "into" é quanto do evento já passou
// (ao começar do meio do filme).

let noiseBuf = null;
function noise(ac) {
  if (noiseBuf && noiseBuf.sampleRate === ac.sampleRate) return noiseBuf;
  const len = ac.sampleRate * 2;
  noiseBuf = ac.createBuffer(1, len, ac.sampleRate);
  const d = noiseBuf.getChannelData(0);
  for (let i = 0; i < len; i++) d[i] = rand(i, 1) * 2 - 1;
  return noiseBuf;
}
function noiseSrc(ac) {
  const s = ac.createBufferSource();
  s.buffer = noise(ac);
  s.loop = true;
  return s;
}
function env(ac, when, a, peak, hold, rel, into = 0) {
  const g = ac.createGain();
  const p = g.gain;
  p.setValueAtTime(0, when);
  p.linearRampToValueAtTime(peak, when + Math.max(0.001, a - into));
  p.setValueAtTime(peak, when + Math.max(0.002, a + hold - into));
  p.exponentialRampToValueAtTime(0.0001, when + Math.max(0.01, a + hold + rel - into));
  return g;
}

function kick(ac, out, when, _d, _i, vol = 1) {
  const o = ac.createOscillator();
  o.frequency.setValueAtTime(160, when);
  o.frequency.exponentialRampToValueAtTime(42, when + 0.16);
  const g = env(ac, when, 0.003, 0.9 * vol, 0.02, 0.35);
  o.connect(g).connect(out);
  o.start(when); o.stop(when + 0.5);
}
function snare(ac, out, when, _d, _i, vol = 1) {
  const n = noiseSrc(ac), f = ac.createBiquadFilter();
  f.type = 'bandpass'; f.frequency.value = 1900; f.Q.value = 0.8;
  const g = env(ac, when, 0.002, 0.5 * vol, 0.01, 0.18);
  n.connect(f).connect(g).connect(out);
  n.start(when, rand(when * 100, 2)); n.stop(when + 0.3);
  const o = ac.createOscillator();
  o.frequency.setValueAtTime(220, when);
  o.frequency.exponentialRampToValueAtTime(140, when + 0.08);
  const g2 = env(ac, when, 0.002, 0.35 * vol, 0.01, 0.1);
  o.connect(g2).connect(out);
  o.start(when); o.stop(when + 0.2);
}
function hat(ac, out, when, _d, _i, vol = 1) {
  const n = noiseSrc(ac), f = ac.createBiquadFilter();
  f.type = 'highpass'; f.frequency.value = 8000;
  const g = env(ac, when, 0.001, 0.18 * vol, 0.005, 0.05);
  n.connect(f).connect(g).connect(out);
  n.start(when, rand(when * 50, 3)); n.stop(when + 0.1);
}
function taiko(ac, out, when, _d, _i, vol = 1) {
  const o = ac.createOscillator();
  o.frequency.setValueAtTime(110, when);
  o.frequency.exponentialRampToValueAtTime(55, when + 0.3);
  const g = env(ac, when, 0.004, 1.0 * vol, 0.03, 0.8);
  o.connect(g).connect(out);
  o.start(when); o.stop(when + 1.2);
  const n = noiseSrc(ac), f = ac.createBiquadFilter();
  f.type = 'lowpass'; f.frequency.value = 900;
  const g2 = env(ac, when, 0.002, 0.5 * vol, 0.01, 0.15);
  n.connect(f).connect(g2).connect(out);
  n.start(when); n.stop(when + 0.3);
}
function crash(ac, out, when, _d, _i, vol = 1) {
  const n = noiseSrc(ac), f = ac.createBiquadFilter();
  f.type = 'highpass'; f.frequency.value = 4500;
  const g = env(ac, when, 0.002, 0.35 * vol, 0.05, 2.2);
  n.connect(f).connect(g).connect(out);
  n.start(when); n.stop(when + 2.6);
}

function saws(ac, freqs, detune = 9, type = 'sawtooth') {
  const mixG = ac.createGain();
  const nodes = [];
  for (const f of freqs) for (const d of [-detune, 0, detune]) {
    const o = ac.createOscillator();
    o.type = type; o.frequency.value = f; o.detune.value = d;
    o.connect(mixG); nodes.push(o);
  }
  mixG.gain.value = 1 / (freqs.length * 3);
  return { out: mixG, nodes };
}
function pad(notes, cutoff = 1100, vol = 0.35) {
  return (ac, out, when, dur, into) => {
    const { out: s, nodes } = saws(ac, notes.map((n) => hz(m(n))));
    const f = ac.createBiquadFilter();
    f.type = 'lowpass'; f.frequency.value = cutoff; f.Q.value = 0.7;
    const g = env(ac, when, 0.6, vol, Math.max(0, dur - 0.6), 0.9, into);
    s.connect(f).connect(g).connect(out);
    nodes.forEach((o) => { o.start(when); o.stop(when + dur + 1); });
  };
}
function bassNote(note, len = 0.45, vol = 0.5) {
  return (ac, out, when) => {
    const { out: s, nodes } = saws(ac, [hz(m(note))], 6);
    const f = ac.createBiquadFilter();
    f.type = 'lowpass';
    f.frequency.setValueAtTime(900, when);
    f.frequency.exponentialRampToValueAtTime(180, when + len);
    const g = env(ac, when, 0.005, vol, len * 0.5, len * 0.5);
    s.connect(f).connect(g).connect(out);
    nodes.forEach((o) => { o.start(when); o.stop(when + len + 0.1); });
  };
}
function pluck(note, vol = 0.22, type = 'triangle', len = 0.6) {
  return (ac, out, when) => {
    const o = ac.createOscillator(), o2 = ac.createOscillator();
    o.type = type; o.frequency.value = hz(m(note));
    o2.type = 'sine'; o2.frequency.value = hz(m(note)) * 2;
    const g = env(ac, when, 0.004, vol, 0.02, len);
    const g2 = env(ac, when, 0.004, vol * 0.3, 0.01, len * 0.5);
    o.connect(g).connect(out); o2.connect(g2).connect(out);
    o.start(when); o.stop(when + len + 0.1); o2.start(when); o2.stop(when + len + 0.1);
  };
}
function lead(note, len, vol = 0.16) {
  return (ac, out, when) => {
    const { out: s, nodes } = saws(ac, [hz(m(note))], 12);
    const lfo = ac.createOscillator(), lg = ac.createGain();
    lfo.frequency.value = 5.5; lg.gain.value = 14;
    lfo.connect(lg); nodes.forEach((o) => lg.connect(o.detune));
    const f = ac.createBiquadFilter();
    f.type = 'lowpass'; f.frequency.value = 2600;
    const g = env(ac, when, 0.03, vol, Math.max(0, len - 0.15), 0.25);
    s.connect(f).connect(g).connect(out);
    [...nodes, lfo].forEach((o) => { o.start(when); o.stop(when + len + 0.4); });
  };
}
function drone(note, vol = 0.3, cutoff = 220) {
  return (ac, out, when, dur, into) => {
    const { out: s, nodes } = saws(ac, [hz(m(note)), hz(m(note)) * 1.5], 5);
    const f = ac.createBiquadFilter();
    f.type = 'lowpass'; f.frequency.value = cutoff;
    const g = env(ac, when, 1.5, vol, Math.max(0, dur - 2.5), 1, into);
    s.connect(f).connect(g).connect(out);
    nodes.forEach((o) => { o.start(when); o.stop(when + dur + 0.2); });
  };
}
function riser(vol = 0.35, f0 = 200, f1 = 7000) {
  return (ac, out, when, dur, into) => {
    const n = noiseSrc(ac), f = ac.createBiquadFilter();
    f.type = 'bandpass'; f.Q.value = 2;
    const k = into / dur;
    f.frequency.setValueAtTime(f0 * Math.pow(f1 / f0, k), when);
    f.frequency.exponentialRampToValueAtTime(f1, when + dur - into);
    const g = ac.createGain();
    g.gain.setValueAtTime(0.001 + vol * k, when);
    g.gain.linearRampToValueAtTime(vol, when + dur - into);
    g.gain.linearRampToValueAtTime(0, when + dur - into + 0.03);
    n.connect(f).connect(g).connect(out);
    n.start(when); n.stop(when + dur - into + 0.1);
  };
}

// ---- efeitos sonoros ---------------------------------------------------------------
function heartbeat(ac, out, when) {
  const o = ac.createOscillator();
  o.frequency.setValueAtTime(70, when);
  o.frequency.exponentialRampToValueAtTime(38, when + 0.18);
  const g = env(ac, when, 0.01, 1, 0.03, 0.25);
  const f = ac.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 200;
  o.connect(f).connect(g).connect(out);
  o.start(when); o.stop(when + 0.4);
}
function whoosh(dur = 0.45, vol = 0.35, up = true) {
  return (ac, out, when) => {
    const n = noiseSrc(ac), f = ac.createBiquadFilter();
    f.type = 'bandpass'; f.Q.value = 1.4;
    f.frequency.setValueAtTime(up ? 300 : 3000, when);
    f.frequency.exponentialRampToValueAtTime(up ? 3000 : 250, when + dur);
    const g = ac.createGain();
    g.gain.setValueAtTime(0.001, when);
    g.gain.exponentialRampToValueAtTime(vol, when + dur * 0.7);
    g.gain.exponentialRampToValueAtTime(0.001, when + dur);
    n.connect(f).connect(g).connect(out);
    n.start(when, rand(when, 9)); n.stop(when + dur + 0.05);
  };
}
function shimmer(ac, out, when, dur) {   // transformação: cintilar ascendente
  for (let i = 0; i < 24; i++) {
    const tt = when + (i / 24) * dur;
    pluck(['D6', 'F6', 'A6', 'C7', 'D7', 'E7'][i % 6], 0.05 + 0.05 * (i / 24), 'sine', 0.5)(ac, out, tt);
  }
}
function glintS(ac, out, when) {
  for (const [f, v] of [[2637, 0.18], [3951, 0.1], [5274, 0.06]]) {
    const o = ac.createOscillator();
    o.frequency.value = f;
    const g = env(ac, when, 0.002, v, 0.01, 1.2);
    o.connect(g).connect(out);
    o.start(when); o.stop(when + 1.4);
  }
}
function crack(vol = 0.5) {
  return (ac, out, when) => {
    const n = noiseSrc(ac), f = ac.createBiquadFilter();
    f.type = 'highpass'; f.frequency.value = 1500;
    const g = env(ac, when, 0.001, vol, 0.02, 0.25);
    n.connect(f).connect(g).connect(out);
    n.start(when, rand(when, 4)); n.stop(when + 0.35);
    const o = ac.createOscillator();
    o.type = 'square';
    o.frequency.setValueAtTime(900, when);
    o.frequency.exponentialRampToValueAtTime(60, when + 0.2);
    const g2 = env(ac, when, 0.001, vol * 0.25, 0.01, 0.2);
    o.connect(g2).connect(out);
    o.start(when); o.stop(when + 0.3);
  };
}
function charge(ac, out, when, dur, into) {
  const o = ac.createOscillator(), o2 = ac.createOscillator();
  o.type = 'sawtooth'; o2.type = 'square';
  const k = into / dur;
  o.frequency.setValueAtTime(70 * Math.pow(6, k), when);
  o.frequency.exponentialRampToValueAtTime(420, when + dur - into);
  o2.frequency.setValueAtTime(71 * Math.pow(6, k), when);
  o2.frequency.exponentialRampToValueAtTime(426, when + dur - into);
  const trem = ac.createOscillator(), tg = ac.createGain();
  trem.frequency.setValueAtTime(6, when);
  trem.frequency.linearRampToValueAtTime(28, when + dur - into);
  tg.gain.value = 0.5;
  const f = ac.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 1800;
  const g = ac.createGain();
  g.gain.setValueAtTime(0.03 + 0.17 * k, when);
  g.gain.linearRampToValueAtTime(0.2, when + dur - into);
  g.gain.linearRampToValueAtTime(0, when + dur - into + 0.02);
  const am = ac.createGain(); am.gain.value = 0.5;
  trem.connect(tg).connect(am.gain);
  o.connect(f); o2.connect(f); f.connect(am).connect(g).connect(out);
  [o, o2, trem].forEach((x) => { x.start(when); x.stop(when + dur - into + 0.1); });
}
function beam(ac, out, when) {
  const n = noiseSrc(ac), f = ac.createBiquadFilter();
  f.type = 'lowpass';
  f.frequency.setValueAtTime(9000, when);
  f.frequency.exponentialRampToValueAtTime(400, when + 0.9);
  const g = env(ac, when, 0.003, 0.9, 0.05, 0.9);
  n.connect(f).connect(g).connect(out);
  n.start(when); n.stop(when + 1.1);
  const o = ac.createOscillator();
  o.type = 'sawtooth';
  o.frequency.setValueAtTime(1800, when);
  o.frequency.exponentialRampToValueAtTime(90, when + 0.7);
  const g2 = env(ac, when, 0.003, 0.3, 0.02, 0.7);
  o.connect(g2).connect(out);
  o.start(when); o.stop(when + 0.8);
}
function whine(ac, out, when, dur) {     // zumbido agudo do "silêncio" antes do impacto
  const o = ac.createOscillator();
  o.frequency.value = 6200;
  const g = env(ac, when, 0.05, 0.035, dur - 0.2, 0.15);
  o.connect(g).connect(out);
  o.start(when); o.stop(when + dur + 0.1);
}
function explosion(ac, out, when) {
  const sub = ac.createOscillator();
  sub.frequency.setValueAtTime(90, when);
  sub.frequency.exponentialRampToValueAtTime(28, when + 1.5);
  const gs = env(ac, when, 0.005, 1.0, 0.2, 2.5);
  sub.connect(gs).connect(out);
  sub.start(when); sub.stop(when + 3);
  const n = noiseSrc(ac), f = ac.createBiquadFilter();
  f.type = 'lowpass';
  f.frequency.setValueAtTime(6000, when);
  f.frequency.exponentialRampToValueAtTime(150, when + 4);
  const g = env(ac, when, 0.004, 1.0, 0.3, 4.2);
  n.connect(f).connect(g).connect(out);
  n.start(when); n.stop(when + 5);
}
function rumble(ac, out, when, dur, into) {
  const n = noiseSrc(ac), f = ac.createBiquadFilter();
  f.type = 'lowpass'; f.frequency.value = 160;
  const g = env(ac, when, 1, 0.5, Math.max(0, dur - 2.5), 1.5, into);
  n.connect(f).connect(g).connect(out);
  n.start(when); n.stop(when + dur + 0.2);
}

// ---- partitura -------------------------------------------------------------------
function buildScore() {
  const ev = [];
  const mus = (t, dur, play) => ev.push({ t, dur, bus: 'music', play });
  const sfx = (t, dur, play) => ev.push({ t, dur, bus: 'sfx', play });
  const bars = (a, b, fn) => { for (let t = a; t < b - 1e-6; t += BAR) fn(t); };
  const beats = (a, b, step, fn) => { for (let t = a; t < b - 1e-6; t += step) fn(t); };

  const CH = {
    Dm: ['D3', 'F3', 'A3', 'D4'], Bb: ['Bb2', 'D3', 'F3', 'Bb3'], Gm: ['G2', 'Bb2', 'D3', 'G3'],
    A: ['A2', 'C#3', 'E3', 'A3'], Eb: ['Eb3', 'G3', 'Bb3', 'Eb4'], C: ['C3', 'E3', 'G3', 'C4'],
    Asus: ['A2', 'D3', 'E3', 'A3'],
  };
  const ROOT = { Dm: 'D2', Bb: 'Bb1', Gm: 'G1', A: 'A1', Eb: 'Eb2', C: 'C2', Asus: 'A1' };
  const prog = (a, names, opts = {}) => names.forEach((c, i) => mus(a + i * BAR, BAR, pad(CH[c], opts.cut, opts.vol)));

  // 0–4 abertura: drone + coração
  mus(0, 12, drone('D2', 0.28));
  HEARTBEATS.forEach((t) => mus(t, 0.4, heartbeat));

  // 4–12 transformação: acordes + arpejo crescendo
  prog(4, ['Dm', 'Bb', 'Gm', 'A'], { cut: 900, vol: 0.3 });
  ['Dm', 'Bb', 'Gm', 'A'].forEach((c, i) => {
    const notes = [...CH[c].slice(1), CH[c][3].replace(/\d/, (o) => +o + 1)];
    beats(4 + i * BAR, 4 + (i + 1) * BAR, BEAT / 2, (t) => {
      const k = Math.round((t - 4) / (BEAT / 2));
      mus(t, 0.3, pluck(notes[k % notes.length].replace(/\d/, (o) => +o + 1), 0.07 + 0.012 * i));
    });
  });
  sfx(8.2, 2.3, shimmer);
  sfx(9.3, 1.2, glintS);
  sfx(10.9, 1.1, riser(0.3, 300, 5000));

  // 12–20 ataque/olhos: tambores em meio-tempo, frígio (Dm–Eb)
  prog(12, ['Dm', 'Eb', 'Dm', 'Eb'], { cut: 1300, vol: 0.32 });
  bars(12, 20, (t) => {
    mus(t, 0.5, taiko); mus(t + 2 * BEAT, 0.5, snare); mus(t + 3.5 * BEAT, 0.5, (a, o, w) => kick(a, o, w, 0, 0, 0.7));
    beats(t, t + BAR, BEAT / 2, (b) => mus(b, 0.3, bassNote(ROOT[(t - 12) % 4 === 0 ? 'Dm' : 'Eb'], 0.22, 0.42)));
  });
  sfx(12.75, 1.2, glintS);
  sfx(14.4, 0.4, crack(0.4)); sfx(15.3, 0.4, crack(0.35));
  sfx(19.5, 0.5, crack(0.7));

  // 20–26 olho: construção (4 no chão, rufar, subida)
  prog(20, ['Bb', 'C', 'Asus'], { cut: 1600, vol: 0.32 });
  bars(20, 26, (t) => beats(t, t + BAR, BEAT, (b) => mus(b, 0.5, kick)));
  beats(20, 24, BEAT / 2, (b) => mus(b, 0.3, hat));
  beats(24, 25, BEAT / 4, (b) => mus(b, 0.3, (a, o, w) => snare(a, o, w, 0, 0, 0.5)));
  beats(25, 26, BEAT / 8, (b) => mus(b, 0.3, (a, o, w) => snare(a, o, w, 0, 0, 0.35 + (b - 25) * 0.6)));
  bars(20, 26, (t) => beats(t, t + BAR, BEAT / 2, (b) => mus(b, 0.3, bassNote(ROOT[['Bb', 'C', 'Asus'][Math.floor((t - 20) / 2)]], 0.22, 0.42))));
  mus(22, 4, riser(0.28));
  sfx(25.5, 0.5, whoosh(0.5, 0.4));

  // 26–32 ataque em detalhe: tambores grandes + carga, depois silêncio
  prog(26, ['Dm', 'Bb'], { cut: 1800, vol: 0.34 });
  mus(30, FIRE - 30 + 0.05, pad(CH.A, 2000, 0.34));
  bars(26, 30, (t) => {
    [0, 1.5, 2, 3].forEach((b) => mus(t + b * BEAT, 0.5, taiko));
    beats(t, t + BAR, BEAT / 2, (b) => mus(b, 0.3, hat));
  });
  beats(30, FIRE, BEAT / 4, (b) => mus(b, 0.3, (a, o, w) => snare(a, o, w, 0, 0, 0.6)));
  sfx(26, FIRE - 26, charge);
  sfx(FIRE, 1, beam);
  sfx(FIRE + 0.1, BOOM - FIRE - 0.1, whine);

  // 32–40 explosão: o "drop"
  sfx(BOOM, 5, explosion);
  sfx(BOOM, 8, rumble);
  mus(BOOM, 3, crash); mus(36, 3, crash);
  prog(32, ['Dm', 'Bb', 'C', 'A'], { cut: 2400, vol: 0.38 });
  bars(32, 40, (t) => {
    mus(t, 0.5, kick); mus(t + 2 * BEAT, 0.5, kick); mus(t + 2.5 * BEAT, 0.5, (a, o, w) => kick(a, o, w, 0, 0, 0.6));
    mus(t + BEAT, 0.5, snare); mus(t + 3 * BEAT, 0.5, snare);
    beats(t, t + BAR, BEAT / 2, (b) => mus(b, 0.3, hat));
    const c = ['Dm', 'Bb', 'C', 'A'][Math.floor((t - 32) / 2)];
    beats(t, t + BAR, BEAT / 2, (b) => {
      const up = Math.round((b - t) / (BEAT / 2)) % 2;          // oitavas alternadas
      mus(b, 0.3, bassNote(up ? ROOT[c].replace(/\d/, (o) => +o + 1) : ROOT[c], 0.25, 0.5));
    });
  });
  [['D5', 0, 1], ['F5', 1.5, 0.5], ['A5', 2, 2], ['G5', 4, 1], ['F5', 5, 1], ['D5', 6, 2],
    ['E5', 8, 1], ['G5', 9, 0.5], ['C6', 9.5, 2.5], ['A5', 12, 3], ['E5', 15, 1]]
    .forEach(([n, b, l]) => mus(32 + b * BEAT, l * BEAT, lead(n, l * BEAT)));

  // 40–46 satélite: respiro etéreo
  mus(40, 6.2, pad(['D4', 'F4', 'A4', 'C5', 'E5'], 1700, 0.34));
  mus(40, 6, drone('D2', 0.26, 180));
  [['A5', 41], ['F5', 42.5], ['E5', 43.5], ['D5', 44.5]].forEach(([n, t]) => mus(t, 1.5, pluck(n, 0.16, 'sine', 1.6)));

  // 46–52 quadro final: tema
  prog(46, ['Dm', 'Bb', 'A'], { cut: 1200, vol: 0.28 });
  bars(46, 52, (t) => mus(t, 0.4, heartbeat));
  [['A4', 0, 1], ['D5', 1, 1], ['F5', 2, 1], ['E5', 3, 1], ['D5', 4, 1.5], ['C5', 5.5, 0.5], ['D5', 6, 1], ['A4', 7, 1],
    ['Bb4', 8, 1], ['A4', 9, 1], ['G4', 10, 1], ['A4', 11, 1]]
    .forEach(([n, b, l]) => mus(46 + b * BEAT, l * BEAT, pluck(n, 0.2, 'triangle', 0.9)));
  sfx(47.8, 1.2, glintS);

  // 52–54 encerramento
  mus(52, 0.5, taiko); mus(52, 2.6, crash);
  mus(52, 2, pad(CH.Dm, 900, 0.3));
  mus(52, 2, drone('D2', 0.22));

  // passagens nos cortes
  [[12, 0.35], [16, 0.35], [20, 0.4], [40, 0.25], [46, 0.25]].forEach(([t, v]) => sfx(t - 0.4, 0.45, whoosh(0.45, v)));

  return ev.sort((a, b) => a.t - b.t);
}

export const SCORE = buildScore();

function reverbIR(ac, secs = 2.6) {
  const len = Math.floor(ac.sampleRate * secs);
  const b = ac.createBuffer(2, len, ac.sampleRate);
  for (let c = 0; c < 2; c++) {
    const d = b.getChannelData(c);
    for (let i = 0; i < len; i++) d[i] = (rand(i * 2 + c, 77) * 2 - 1) * Math.pow(1 - i / len, 3);
  }
  return b;
}

// Monta o mixer: música + efeitos -> reverb/compressor -> saída
export function makeMixer(ac) {
  const master = ac.createGain();
  master.gain.value = 0.62;
  const comp = ac.createDynamicsCompressor();
  comp.threshold.value = -16; comp.ratio.value = 4; comp.attack.value = 0.005; comp.release.value = 0.2;
  const limit = ac.createDynamicsCompressor();        // limitador: segura os picos abaixo de 0 dB
  limit.threshold.value = -4; limit.knee.value = 0; limit.ratio.value = 20; limit.attack.value = 0.001; limit.release.value = 0.1;
  const trim = ac.createGain();
  trim.gain.value = 0.85;
  master.connect(comp).connect(limit).connect(trim).connect(ac.destination);
  const rev = ac.createConvolver();
  rev.buffer = reverbIR(ac);
  const revG = ac.createGain(); revG.gain.value = 0.28;
  rev.connect(revG).connect(master);
  const bus = {};
  for (const name of ['music', 'sfx']) {
    const g = ac.createGain();
    g.connect(master); g.connect(rev);
    bus[name] = g;
  }
  return { master, bus };
}

// Agenda os eventos com início em [from, to). "origin" é o instante do relógio de
// áudio que corresponde ao segundo "offset" do filme (onde a reprodução começou).
export function schedule(ac, bus, origin, offset, from = -Infinity, to = Infinity) {
  for (const e of SCORE) {
    if (e.t < from || e.t >= to) continue;
    if (e.t + e.dur < offset) continue;
    const into = Math.max(0, offset - e.t);
    if (into > 0 && e.dur < 0.6) continue;                 // não toca notas curtas pela metade
    e.play(ac, bus[e.bus], origin + Math.max(0, e.t - offset), e.dur, into);
  }
}

// Renderiza a trilha inteira offline (para exportar MP4) e devolve WAV em base64
export async function renderWav(sampleRate = 48000) {
  const ac = new OfflineAudioContext(2, Math.ceil(DURATION * sampleRate), sampleRate);
  const { bus } = makeMixer(ac);
  schedule(ac, bus, 0, 0);
  // (o OfflineAudioContext começa em 0, então origin = 0)
  const buf = await ac.startRendering();
  const n = buf.length, ch = [buf.getChannelData(0), buf.getChannelData(1)];
  const out = new DataView(new ArrayBuffer(44 + n * 4));
  const w = (o, s) => [...s].forEach((c, i) => out.setUint8(o + i, c.charCodeAt(0)));
  w(0, 'RIFF'); out.setUint32(4, 36 + n * 4, true); w(8, 'WAVEfmt ');
  out.setUint32(16, 16, true); out.setUint16(20, 1, true); out.setUint16(22, 2, true);
  out.setUint32(24, sampleRate, true); out.setUint32(28, sampleRate * 4, true);
  out.setUint16(32, 4, true); out.setUint16(34, 16, true); w(36, 'data'); out.setUint32(40, n * 4, true);
  for (let i = 0, o = 44; i < n; i++) for (let c = 0; c < 2; c++, o += 2) {
    out.setInt16(o, Math.max(-1, Math.min(1, ch[c][i])) * 32767, true);
  }
  const bytes = new Uint8Array(out.buffer);
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

// A TRILHA — lo-fi calmo de fundo + efeitos ligados ao roteiro (giz escrevendo, sino de cena,
// tique do cronômetro, sino de "tempo esgotado"). Tudo sai dos tempos de score.js.
// Como a aula é longa (~56 min), a música é um laço de 64 compassos e os efeitos são gravados em
// blocos; o ffmpeg junta tudo em out/music.wav (16 bits) no final.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { SR, Bus, reverb } = require('./engine/audio/dsp');
const I = require('./engine/audio/instruments');
const MIX = require('./engine/audio/mix');
const Genre = require('./engine/audio/genres');
const sc = require('./score');
const { clock, DURATION, ev, m } = sc;

const out = path.join(__dirname, 'out');
fs.mkdirSync(out, { recursive: true });

// ---------- 1) laço de música: renderiza 68 compassos e corta [2, 66) para emendar sem costura ----------
{
  const N = Math.ceil(clock.T(68) * SR) + SR * 2;
  const drums = new Bus(N), bass = new Bus(N), pad = new Bus(N), keys = new Bus(N), verb = new Bus(N);
  const { kicks } = Genre.play('lofi', { clock, from: 0, to: 68, chordAt: sc.chordAt, buses: { drums, bass, pad, keys }, gain: 0.8 });
  for (const c of sc.chords) if (c.bar < 68) for (const n of c.notes) { const { L, R } = I.padNote(n, c.t1 - c.t0, { cutoff: 900, attack: 0.6, release: 1.2 }); pad.addStereo(L, R, c.t0, 0.05); }
  // uma melodia suave de caixinha de música a cada 8 compassos
  const mel = ['E5', 'G5', 'A5', 'C6', 'B5', 'G5', 'A5', 'E5'];
  for (let b = 0; b < 68; b += 8) mel.forEach((nm, i) => { const x = I.musicBox(m(nm)); keys.addMono(x, clock.T(b + 4, i * 0.5), 0.07); verb.addMono(x, clock.T(b + 4, i * 0.5), 0.08); });
  const stems = { drums, bass, pad, keys, verb: reverb(verb, { room: 0.8, damp: 0.4 }) };
  const mix = MIX.mixdown(stems, { drums: 0.35, bass: 0.6, pad: 1.2, keys: 0.8, verb: 1 });
  MIX.highpass(mix, 30);
  Genre.fx('lofi', mix, { kicks, buses: [pad, keys] });
  MIX.master(mix, 0.6, undefined, { lufs: -24 }); // bem baixinho: é música de estudo
  const a = Math.round(clock.T(2) * SR), b = Math.round(clock.T(66) * SR);
  const loop = new Bus(b - a);
  loop.L.set(mix.L.subarray(a, b)); loop.R.set(mix.R.subarray(a, b));
  MIX.writeWav(path.join(out, 'loop.wav'), loop);
  console.log(`loop: ${((b - a) / SR).toFixed(1)} s`);
}

// ---------- 2) efeitos, em blocos de 5 min ----------
const CH = 300, nChunks = Math.ceil(DURATION / CH);
const SND = {
  chalk: [0, 1, 2, 3].map((k) => (d) => I.scribble(d, 31 + k)),
  chime: (sc2) => [m('C6'), m('E6'), m('G6')].map((n) => I.musicBox(n)),
  tick: I.woodTick(1.2),
  bell: I.bell(1318, 1.4, 2, 3.5),
  ting: I.ting(88),
};
const events = [];
for (const l of ev.lines) {
  events.push({ t: l.t, buf: SND.chalk[Math.round(l.t * 7) % 4](Math.min(1.4, l.dur)), g: 0.10 });
  if (l.type === 'f' && l.sol) events.push({ t: l.t + l.dur, buf: SND.ting, g: 0.12 });
}
for (const s of ev.scenes) if (s.t > 0.1) events.push({ t: s.t, buf: I.paperFwip(0.8, Math.round(s.t)), g: 0.08 });
for (const t of ev.chapters) SND.chime().forEach((b, i) => events.push({ t: t + i * 0.18, buf: b, g: 0.2 }));
for (const t of ev.ticks) events.push({ t, buf: SND.tick, g: 0.16 });
for (const t of ev.bells) events.push({ t, buf: SND.bell, g: 0.14 });
const list = [];
for (let k = 0; k < nChunks; k++) {
  const t0 = k * CH, len = Math.min(CH, DURATION - t0);
  const bus = new Bus(Math.ceil(len * SR) + 1);
  for (const e of events) {
    const i0 = Math.round((e.t - t0) * SR);
    if (i0 + e.buf.length < 0 || i0 >= bus.L.length) continue;
    for (let j = Math.max(0, -i0); j < e.buf.length && i0 + j < bus.L.length; j++) { const v = e.buf[j] * e.g; bus.L[i0 + j] += v; bus.R[i0 + j] += v; }
  }
  const f = path.join(out, `sfx_${String(k).padStart(2, '0')}.wav`);
  MIX.writeWav(f, bus); list.push(`file '${f}'`);
}
fs.writeFileSync(path.join(out, 'sfx.txt'), list.join('\n'));

// ---------- 3) juntar: laço repetido + efeitos -> out/music.wav ----------
execFileSync('ffmpeg', ['-loglevel', 'error', '-y',
  '-stream_loop', '-1', '-i', path.join(out, 'loop.wav'),
  '-f', 'concat', '-safe', '0', '-i', path.join(out, 'sfx.txt'),
  '-filter_complex', `[0:a]atrim=0:${DURATION.toFixed(3)},afade=t=in:d=2,afade=t=out:st=${(DURATION - 4).toFixed(3)}:d=4[mu];[1:a]atrim=0:${DURATION.toFixed(3)}[fx];[mu][fx]amix=inputs=2:normalize=0,volume=1.6,alimiter=limit=0.84[o]`,
  '-map', '[o]', '-ar', '48000', '-c:a', 'pcm_s16le', path.join(out, 'music.wav')]);
for (const l of list) fs.unlinkSync(l.slice(6, -1));
console.log(`wrote out/music.wav (${(DURATION / 60).toFixed(1)} min, ${events.length} efeitos)`);

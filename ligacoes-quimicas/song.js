// A TRILHA: um lo-fi tranquilo de estudo por baixo da narração, um "tic" de giz em cada corte,
// uma batida em cada título e efeitos nos momentos da ligação iônica.   node song.js   (STEMS=1, LUFS=-14)
const path = require('path');
const { VOICE, RATE } = require('./voicecfg');
const { SR, Bus, reverb } = require('./engine/audio/dsp');
const I = require('./engine/audio/instruments');
const MIX = require('./engine/audio/mix');
const Genre = require('./engine/audio/genres');
const Voice = require('./engine/audio/voice');
const sc = require('./score');
const { T, BEAT, DURATION, m, ev, clock, chordAt } = sc;

const N = Math.ceil((DURATION + 1) * SR);
const bus = () => new Bus(N);
const buses = { drums: bus(), bass: bus(), pad: bus(), keys: bus() };
const lead = bus(), fx = bus(), verb = bus();
const bars = Math.floor(DURATION / clock.BAR);

// a base: lo-fi o tempo todo; sem bateria na abertura, entra no compasso 2
Genre.play('lofi', { clock, from: 0, to: 2, chordAt, buses, drums: false, gain: 0.8 });
Genre.play('lofi', { clock, from: 2, to: bars, chordAt, buses, gain: 0.8 });
// a abertura: uma caixinha de música toca o tema
[['E5', 0], ['G5', 0.5], ['B5', 1], ['C6', 1.5], ['B5', 2.5], ['G5', 3], ['A5', 4], ['C6', 4.5], ['E6', 5], ['D6', 6]].forEach(([n, b]) => {
  const x = I.musicBox(m(n)); lead.addMono(x, T(0, b), 0.16, 0.15); verb.addMono(x, T(0, b), 0.2);
});

// cada corte de cena: o tique do giz no quadro
sc.cuts.forEach((t, i) => { fx.addMono(I.woodTick(1 + (i % 3) * 0.12), t, 0.35, (i % 2 ? 0.2 : -0.2)); fx.addMono(I.paperFwip(1.1, i + 2), t - 0.12, 0.08); });
// cada título: batida grave + um acorde brilhante
sc.titles.forEach((t, i) => {
  fx.addMono(I.thud(70, 0.16), t, 0.55); fx.addMono(I.woodTick(0.8), t, 0.3);
  const root = ['C5', 'E5', 'G5', 'A5', 'C5', 'G5'][i % 6];
  for (const k of [0, 4, 7, 12]) { const x = I.pluck(m(root) + k); lead.addMono(x, t, 0.12, k % 2 ? 0.25 : -0.25); verb.addMono(x, t, 0.12); }
});
// a ligação iônica: o elétron voa (assobio subindo) e chega (pop); os íons se juntam (batida)
fx.addMono(I.noiseSweep(1.0, 400, 3200, { q: 3 }), ev.transfer, 0.12);
fx.addMono(I.pop(2200), ev.land, 0.35);
fx.addMono(I.thud(90, 0.14), ev.snapNaCl, 0.5); fx.addMono(I.bell(784, 1.2), ev.snapNaCl, 0.12);
fx.addMono(I.woodTick(1.3), ev.f3, 0.35);
// o fim: um acorde de cordas segurado
for (const n of ['C4', 'E4', 'G4', 'B4']) { const { L, R } = I.strings(m(n), 4, { attack: 0.3, release: 1.5 }); lead.addStereo(L, R, sc.S.fim[0], 0.08); }

// a narração, com a música abaixando por baixo dela
const vo = Voice.speak(sc.vo, { out: path.join(__dirname, 'out'), length: DURATION, voice: VOICE, rate: RATE });
const music = [buses.drums, buses.bass, buses.pad, buses.keys, lead];
MIX.duck(music, vo.bus, { depth: 0.7 });

const room = reverb(verb, { room: 0.7, damp: 0.4 });
const voRoom = reverb(vo.bus, { room: 0.25, damp: 0.6 });
const stems = { ...buses, lead, fx, voice: vo.bus, voroom: voRoom, verb: room };
const GAIN = { drums: 0.45, bass: 0.5, pad: 0.6, keys: 0.6, lead: 0.8, fx: 0.9, voice: 2.2, voroom: 0.12, verb: 0.35 };
const mix = MIX.mixdown(stems, GAIN, { stemDir: process.env.STEMS ? path.join(__dirname, 'out') : null });
MIX.highpass(mix, 28);
MIX.fadeOut(mix, DURATION - 2, DURATION);
const res = MIX.master(mix, 0.8, undefined, { lufs: process.env.LUFS ? +process.env.LUFS : -14 });
MIX.writeWav(path.join(__dirname, 'out', 'music.wav'), mix);
console.log(`out/music.wav  ${DURATION.toFixed(1)}s  ${res.lufs.toFixed(1)} LUFS  voice: ${vo.engine}`);

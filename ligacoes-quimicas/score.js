// LIGAÇÕES QUÍMICAS (16:9, ~4 min): uma aula animada num quadro-negro, para a prova do 9º ano.
// A linha do tempo nasce do roteiro (lines.js) e da duração medida de cada fala (vodur.js):
// cada cena começa num tempo da música, cada fala começa quando a anterior termina.
(function () {
  const node = typeof require !== 'undefined';
  const U = node ? require('./engine/util') : globalThis.U;
  const MU = node ? require('./engine/music') : globalThis.MUSIC;
  const LINES = node ? require('./lines') : globalThis.LINES;
  const VODUR = node ? require('./vodur') : globalThis.VODUR;
  const { m, makeClock, makeChords } = MU;

  const FPS = 30;
  const FORMAT = '16:9';
  const STYLE = 'chalk';
  const [W, H] = U.formatSize(FORMAT);
  const SAFE = U.safeArea(W, H);
  const clock = makeClock({ bpm: 92, offset: 0 });
  const { T, BEAT } = clock;
  const snap = (t) => Math.ceil(t / BEAT - 1e-6) * BEAT; // o próximo tempo da música

  // as cenas que abrem uma parte nova ganham um título carimbado antes da primeira fala
  const TITLED = { intro: 1.4, ionica: 1.6, covalente: 1.6, metalica: 1.6, resumo: 0.9, dicas: 0.9 };
  const GAP = 0.45; // respiro entre falas
  const L = {}; // id -> { t, end, scene }
  const S = {}; // cena -> [início, fim]
  const vo = [];
  let cur = 0.3;
  for (const [scene, lines] of LINES.SCENES) {
    const t0 = snap(cur);
    let t = t0 + (TITLED[scene] || 0.55);
    for (const [id, text] of lines) {
      const d = VODUR[id] || 3;
      L[id] = { t, end: t + d, scene };
      vo.push({ at: t, text, who: 'narrator' });
      t += d + GAP;
    }
    const tail = scene === 'fim' ? 4.5 : scene === 'ionica' || scene === 'formula' ? 1.6 : 0.7;
    S[scene] = [t0, t - GAP + tail];
    cur = S[scene][1];
  }
  const DURATION = +(cur + 0.2).toFixed(2);
  const SCENE_LIST = LINES.SCENES.map(([s]) => s);
  const cuts = SCENE_LIST.slice(1).map((s) => S[s][0]); // cada troca de cena: um corte com "tic"
  const titles = Object.keys(TITLED).map((s) => S[s][0]); // os títulos: carimbo com batida

  // harmonia: um lo-fi tranquilo para estudar (C - Am - F - G), quatro compassos por volta
  const BARS = Math.ceil(DURATION / clock.BAR) + 1;
  const loop = ['Cmaj7', 'Am7', 'Fmaj7', 'G'];
  const { chords, chordAt } = makeChords(clock, {
    Cmaj7: { notes: ['E3', 'G3', 'B3', 'C4'], bass: 'C2' }, Am7: { notes: ['E3', 'G3', 'A3', 'C4'], bass: 'A1' },
    Fmaj7: { notes: ['E3', 'F3', 'A3', 'C4'], bass: 'F1' }, G: { notes: ['D3', 'G3', 'B3', 'D4'], bass: 'G1' },
  }, Array.from({ length: BARS }, (_, b) => [b, 0, 4, loop[b % 4]]));

  // pequenos sons ligados a momentos do desenho (o mesmo tempo serve o som e a imagem)
  const at = (id, u) => L[id].t + (L[id].end - L[id].t) * u;
  const ev = {
    transfer: at('n3', 0.25), // o elétron sai do sódio...
    land: at('n3', 0.25) + 1.1, // ...e chega no cloro
    snapNaCl: at('n5', 0.62), // os íons se juntam: NaCl
    f3: L.f3.t, // Al2O3 carimbado
  };

  const markers = { inicio: { t: titles[0] + 0.0001, sync: 'v' } };
  titles.slice(1).forEach((t, i) => { markers['titulo' + (i + 1)] = { t, sync: 'av' }; });
  markers.nacl = { t: ev.snapNaCl, sync: 'a' };
  markers.fim = { t: S.fim[0], sync: 'av' };

  const SCORE = { FPS, FORMAT, STYLE, W, H, SAFE, DURATION, clock, T, BEAT, S, SCENE_LIST, L, m, chords, chordAt, vo, cuts, titles, ev, markers };
  if (node) module.exports = SCORE; else globalThis.SCORE = SCORE;
})();

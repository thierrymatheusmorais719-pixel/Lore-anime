// Corta a narração do ElevenLabs (um arquivo só) em uma fala por linha de lines.js.
// Divide o roteiro em frases e, por programação dinâmica, escolhe uma pausa do áudio para o fim de cada
// frase: cada frase deve durar o que suas letras pedem (no ritmo médio da voz) e terminar numa pausa longa.
// Grava eleven/<id>.wav e eleven/map.json (texto -> arquivo).   node split-eleven.js [eleven/narracao.mp3]
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { SCENES } = require('./lines');
const SRC = process.argv[2] || path.join(__dirname, 'eleven', 'narracao.mp3');
const OUT = path.join(__dirname, 'eleven');

const lines = SCENES.flatMap(([, ls]) => ls.map(([id, text]) => ({ id, text })));
const sents = []; // { li (linha), w (peso) }
lines.forEach((l, li) => l.text.split(/(?<=[.!?])\s+/).forEach((s) => sents.push({ li, w: s.replace(/[^\p{L}\p{N}]/gu, '').length + 3 * (s.match(/[,:;]/g) || []).length + 2 })));
const r = spawnSync('ffmpeg', ['-v', 'info', '-i', SRC, '-af', 'silencedetect=noise=-38dB:d=0.1', '-f', 'null', '-'], { encoding: 'utf8' });
const dur = +spawnSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', SRC], { encoding: 'utf8' }).stdout;
let gaps = []; let s0 = null;
for (const l of r.stderr.split('\n')) {
  const a = l.match(/silence_start: ([\d.]+)/); if (a) s0 = +a[1];
  const b = l.match(/silence_end: ([\d.]+)/); if (b && s0 !== null) { gaps.push({ a: s0, b: +b[1], len: +b[1] - s0 }); s0 = null; }
}
const head = gaps.length && gaps[0].a < 0.05 ? gaps.shift().b : 0;
const tail = gaps.length && gaps[gaps.length - 1].b > dur - 0.05 ? gaps.pop().a : dur;
// pontos de corte: início, cada pausa, fim
const P = [{ a: head, b: head, len: 1 }, ...gaps, { a: tail, b: tail, len: 1 }];
const speech = (i, j) => P[j].a - P[i].b; // fala entre a pausa i e a pausa j
const W = sents.reduce((x, s) => x + s.w, 0);
const rate = (tail - head - gaps.reduce((x, g) => x + g.len, 0) * 0.5) / W; // s por unidade de peso
const K = sents.length, M = P.length, INF = 1e18;
const c = (k, i, j) => { const e = rate * sents[k].w, d = speech(i, j); return ((d - e) ** 2) / e - (j === M - 1 ? 0 : 3 * Math.min(P[j].len, 0.5)); };
const D = Array.from({ length: K }, () => new Float64Array(M).fill(INF));
const B = Array.from({ length: K }, () => new Int32Array(M).fill(-1));
for (let j = 1; j < M; j++) D[0][j] = c(0, 0, j);
for (let k = 1; k < K; k++) for (let j = k + 1; j < M; j++) for (let i = k; i < j; i++) {
  if (D[k - 1][i] >= INF) continue;
  const v = D[k - 1][i] + c(k, i, j); if (v < D[k][j]) { D[k][j] = v; B[k][j] = i; }
}
const end = new Array(K); let j = M - 1;
for (let k = K - 1; k >= 0; k--) { end[k] = j; j = B[k][j]; }
const start = end.map((e, k) => (k === 0 ? 0 : end[k - 1]));
const map = {};
lines.forEach((l, li) => {
  const ks = sents.map((s, k) => k).filter((k) => sents[k].li === li);
  const a = Math.max(0, P[start[ks[0]]].b - 0.04), b = Math.min(dur, P[end[ks[ks.length - 1]]].a + 0.08);
  const f = path.join(OUT, `${l.id}.wav`);
  spawnSync('ffmpeg', ['-v', 'error', '-y', '-ss', a.toFixed(3), '-to', b.toFixed(3), '-i', SRC, '-ac', '1', '-ar', '48000', f]);
  map[l.text.replace(/\s+/g, ' ').trim()] = f;
  const exp = ks.reduce((x, k) => x + sents[k].w, 0) * rate;
  console.log(`${l.id.padEnd(4)} ${a.toFixed(2).padStart(7)} → ${b.toFixed(2).padStart(7)}  ${(b - a).toFixed(2)}s (esperado ${exp.toFixed(1)})  ${l.text.slice(0, 45)}`);
});
fs.writeFileSync(path.join(OUT, 'map.json'), JSON.stringify(map, null, 1));

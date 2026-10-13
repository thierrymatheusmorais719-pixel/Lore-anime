// Mede quanto dura cada fala com a voz escolhida e grava vodur.js (lido por score.js, no Node e no navegador).
//   node measure.js
const fs = require('fs');
const path = require('path');
const Voice = require('./engine/audio/voice');
const { SCENES } = require('./lines');
const { VOICE, RATE } = require('./voicecfg');

const all = SCENES.flatMap(([, ls]) => ls.map(([id, text]) => ({ id, text, at: 0 })));
const vo = Voice.speak(all, { out: path.join(__dirname, 'out'), voice: VOICE, rate: RATE, save: false });
const dur = {};
vo.lines.forEach((l, i) => { dur[all[i].id] = +(l.end - l.t).toFixed(3); });
fs.writeFileSync(path.join(__dirname, 'vodur.js'), `// gerado por measure.js: duração (s) de cada fala\n(function () { const D = ${JSON.stringify(dur)};\n  if (typeof module !== 'undefined') module.exports = D; else globalThis.VODUR = D; })();\n`);
const total = Object.values(dur).reduce((a, b) => a + b, 0);
console.log(`vodur.js  ${all.length} falas  ${total.toFixed(1)}s de fala  (engine: ${vo.engine})`);

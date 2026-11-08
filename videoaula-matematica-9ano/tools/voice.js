// Gera a narração com a ElevenLabs: uma fala por arquivo em voice/<chave>.mp3 (cache: só gera o que falta)
// e grava voice-timings.js com a duração real de cada fala (score.js usa isso para cronometrar a lousa).
//   node tools/voice.js            gera o que falta
//   node tools/voice.js --dry      só mostra quantas falas/caracteres faltam
//   VOICE_ID=... MODEL=... node tools/voice.js
// A chave da API é injetada pelo proxy do ambiente no cabeçalho xi-api-key (aqui vai só um valor fictício).
const fs = require('fs');
const path = require('path');
const { execFile, execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const DIR = path.join(ROOT, 'voice');
const VOICE_ID = process.env.VOICE_ID || 'EXAVITQu4vr4xnSDxMaL';
const MODEL = process.env.MODEL || 'eleven_multilingual_v2';
const KEY = process.env.ELEVENLABS_API_KEY || 'dummy-key-replaced-by-proxy';
fs.mkdirSync(DIR, { recursive: true });

const score = require(path.join(ROOT, 'score.js'));
const items = score.NARRATION;
const todo = items.filter((x) => !fs.existsSync(path.join(DIR, x.key + '.mp3')));
console.log(`${items.length} falas, faltam ${todo.length} (${todo.reduce((a, x) => a + x.text.length, 0)} caracteres)`);
if (process.argv.includes('--dry')) process.exit(0);

function tts(item) {
  return new Promise((resolve, reject) => {
    const tmp = path.join(DIR, item.key + '.part');
    const body = JSON.stringify({ text: item.text, model_id: MODEL, voice_settings: { stability: 0.55, similarity_boost: 0.8, style: 0.15, use_speaker_boost: true, speed: 0.95 } });
    execFile('curl', ['-sS', '-w', '%{http_code}', '-o', tmp, '-X', 'POST',
      `https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}?output_format=mp3_44100_128`,
      '-H', `xi-api-key: ${KEY}`, '-H', 'Content-Type: application/json', '-H', 'Accept: audio/mpeg', '--data-binary', body],
    { maxBuffer: 1 << 20 }, (err, stdout) => {
      if (err) return reject(err);
      if (stdout.trim() !== '200') { const msg = fs.existsSync(tmp) ? fs.readFileSync(tmp, 'utf8').slice(0, 400) : ''; try { fs.unlinkSync(tmp); } catch (e) {} return reject(new Error(`HTTP ${stdout.trim()}: ${msg}`)); }
      fs.renameSync(tmp, path.join(DIR, item.key + '.mp3'));
      resolve();
    });
  });
}

(async () => {
  let i = 0, done = 0, failed = 0;
  const worker = async () => {
    while (i < todo.length) {
      const it = todo[i++];
      for (let attempt = 0; attempt < 4; attempt++) {
        try { await tts(it); done++; break; } catch (e) {
          if (/HTTP 40[13]/.test(e.message) || /quota|credits/i.test(e.message)) { console.error(e.message); process.exit(1); }
          if (attempt === 3) { failed++; console.error('falhou:', it.text.slice(0, 60), e.message); }
          await new Promise((r) => setTimeout(r, 2000 * 2 ** attempt));
        }
      }
      if (done % 25 === 0) console.log(`${done}/${todo.length}`);
    }
  };
  await Promise.all([worker(), worker(), worker()]);
  // durações reais
  const T = {};
  for (const x of items) {
    const f = path.join(DIR, x.key + '.mp3');
    if (!fs.existsSync(f)) continue;
    T[x.key] = Math.round(parseFloat(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f]).toString()) * 1000) / 1000;
  }
  fs.writeFileSync(path.join(ROOT, 'voice-timings.js'), `// gerado por tools/voice.js: duração (s) de cada fala\n(function () { const T = ${JSON.stringify(T)}; if (typeof module !== 'undefined') module.exports = T; else globalThis.VOICE_TIMINGS = T; })();\n`);
  console.log(`pronto: ${done} geradas, ${failed} falharam, ${Object.keys(T).length} com duração`);
})();

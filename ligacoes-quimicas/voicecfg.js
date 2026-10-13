// a voz do narrador: a gravação do ElevenLabs (eleven/narracao.mp3, cortada por split-eleven.js),
// servida pelo wrapper bin/piper. Alternativas: PIPER_MODEL=pf_dora (Kokoro) ou espeak-ng + 'mb-br4'.
const path = require('path');
process.env.PATH = path.join(__dirname, 'bin') + path.delimiter + process.env.PATH;
process.env.ANIM_TTS = process.env.ANIM_TTS || 'piper';
process.env.PIPER_MODEL = process.env.PIPER_MODEL || 'eleven';
module.exports = { VOICE: process.env.PIPER_MODEL, RATE: 0 };

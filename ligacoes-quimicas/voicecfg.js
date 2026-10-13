// a voz do narrador: Kokoro (voz neural pt-BR "pf_dora"), pelo wrapper bin/piper.
// Alternativas: pm_alex (masculina). Sem o Kokoro, troque para espeak-ng + 'mb-br4'.
const path = require('path');
process.env.PATH = path.join(__dirname, 'bin') + path.delimiter + process.env.PATH;
process.env.ANIM_TTS = process.env.ANIM_TTS || 'piper';
process.env.PIPER_MODEL = process.env.PIPER_MODEL || 'pf_dora';
process.env.KOKORO_SPEED = process.env.KOKORO_SPEED || '1.05';
module.exports = { VOICE: process.env.PIPER_MODEL, RATE: 0 };

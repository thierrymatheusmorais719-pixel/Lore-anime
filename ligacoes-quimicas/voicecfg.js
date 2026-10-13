// a voz do narrador (espeak-ng + MBROLA br4, português do Brasil), pelo wrapper bin/espeak-ng (volume menor)
const path = require('path');
process.env.PATH = path.join(__dirname, 'bin') + path.delimiter + process.env.PATH;
process.env.ANIM_TTS = process.env.ANIM_TTS || 'espeak-ng';
module.exports = { VOICE: 'mb-br4', RATE: 158 };

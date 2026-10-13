# kokoro-onnx: texto -> wav (voz pt-BR)
import sys, soundfile as sf
from kokoro_onnx import Kokoro
import os
D = os.environ.get('KOKORO_DIR', '/root/kokoro')
k = Kokoro(os.path.join(D, 'kokoro-v1.0.onnx'), os.path.join(D, 'voices-v1.0.bin'))
text, voice, speed, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
a, sr = k.create(text, voice=voice, speed=speed, lang='pt-br')
sf.write(out, a, sr)

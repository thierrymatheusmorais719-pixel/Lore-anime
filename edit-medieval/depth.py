#!/usr/bin/env python3
"""Gera mapas de profundidade (Depth Anything V2, ONNX) para as pinturas em refs/ -> depth/*.png."""
import os, sys, glob
import numpy as np, onnxruntime as ort
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
model = sys.argv[1]
sess = ort.InferenceSession(model)
os.makedirs(os.path.join(HERE, "depth"), exist_ok=True)
mean, std = np.array([0.485, 0.456, 0.406]), np.array([0.229, 0.224, 0.225])
for f in sorted(glob.glob(os.path.join(HERE, "refs", "*.jpg"))):
    im = Image.open(f).convert("RGB")
    def run(img):
        x = (np.asarray(img.resize((518, 518), Image.BICUBIC), np.float32) / 255 - mean) / std
        return sess.run(None, {sess.get_inputs()[0].name: x.transpose(2, 0, 1)[None].astype(np.float32)})[0][0]
    d = (run(im) + run(im.transpose(Image.FLIP_LEFT_RIGHT))[:, ::-1]) / 2   # TTA espelhado
    d = (d - d.min()) / (d.max() - d.min() + 1e-6)                           # 1 = perto
    out = Image.fromarray((d * 65535).astype(np.uint16)).resize(im.size, Image.BICUBIC)
    out.save(os.path.join(HERE, "depth", os.path.basename(f).replace(".jpg", ".png")))
    print(os.path.basename(f))

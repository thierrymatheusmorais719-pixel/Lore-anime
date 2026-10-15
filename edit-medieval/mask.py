#!/usr/bin/env python3
"""Recorte dos personagens (figura) em cada pintura com modelos do rembg via ONNX Runtime.

Uso: python3 mask.py <pasta_dos_modelos>  -> mascaras_alt/<nome>_<modelo>.png
Modelos (github.com/danielgatis/rembg/releases/tag/v0.0.0):
  BiRefNet-general-epoch_244.onnx, BiRefNet-portrait-epoch_150.onnx, isnet-general-use.onnx
"""
import os, sys
import cv2, numpy as np, onnxruntime as ort

ROOT = os.path.dirname(os.path.abspath(__file__))
IMN = ((0.485, 0.456, 0.406), (0.229, 0.224, 0.225))
MODELS = {  # nome: (arquivo, tamanho, média, desvio, sigmoid)
    "isnet": ("isnet-general-use.onnx", 1024, (0.5, 0.5, 0.5), (1, 1, 1), False),
    "birefnet": ("BiRefNet-general-epoch_244.onnx", 1024, *IMN, True),
    "portrait": ("BiRefNet-portrait-epoch_150.onnx", 1024, *IMN, True),
}

def run(sess, img, size, mean, std, sig):
    h, w = img.shape[:2]
    x = cv2.resize(img, (size, size), interpolation=cv2.INTER_LANCZOS4).astype(np.float32) / 255
    x = (x - mean) / std
    y = sess.run(None, {sess.get_inputs()[0].name: x.transpose(2, 0, 1)[None].astype(np.float32)})[0][0, 0]
    if sig:
        y = 1 / (1 + np.exp(-y))
    y = (y - y.min()) / (y.max() - y.min() + 1e-6)
    return cv2.resize(y, (w, h), interpolation=cv2.INTER_CUBIC)

def main():
    out = os.path.join(ROOT, "mascaras_alt"); os.makedirs(out, exist_ok=True)
    so = ort.SessionOptions(); so.intra_op_num_threads = 2
    so.enable_cpu_mem_arena = False  # BiRefNet estoura a memória com o arena ligado
    names = sorted(f for f in os.listdir(os.path.join(ROOT, "refs")) if f.endswith(".jpg"))
    for key, (fn, size, mean, std, sig) in MODELS.items():
        sess = ort.InferenceSession(os.path.join(sys.argv[1], fn), so, providers=["CPUExecutionProvider"])
        for f in names:
            dst = os.path.join(out, f.replace(".jpg", f"_{key}.png"))
            if os.path.exists(dst):
                continue
            img = cv2.imread(os.path.join(ROOT, "refs", f))[:, :, ::-1]
            m = run(sess, img, size, np.float32(mean), np.float32(std), sig)
            cv2.imwrite(dst, (np.clip(m, 0, 1) * 255).astype(np.uint8))
            print(key, f, flush=True)

if __name__ == "__main__":
    main()

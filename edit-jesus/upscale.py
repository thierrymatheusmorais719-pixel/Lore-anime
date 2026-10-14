#!/usr/bin/env python3
"""Upscale 4x das imagens com Real-ESRGAN (RRDBNet x4plus) via ONNX Runtime na CPU.

Lê os pesos .pth sem precisar do PyTorch (o .pth é um zip com pickle + tensores brutos),
monta a rede RRDBNet como grafo ONNX e processa a imagem em blocos.

Pesos: RealESRGAN_x4plus.pth (https://github.com/xinntao/Real-ESRGAN/releases/tag/v0.1.0)
Uso: python3 upscale.py <pesos.pth>   -> imagens_hd/<n>.png
"""
import io
import os
import pickle
import sys
import zipfile

import cv2
import numpy as np
import onnx
import onnxruntime as ort
from onnx import TensorProto, helper, numpy_helper

ROOT = os.path.dirname(os.path.abspath(__file__))
_DT = {"FloatStorage": np.float32, "HalfStorage": np.float16, "DoubleStorage": np.float64}


def load_pth(path):
    """Carrega um state_dict do PyTorch como dict de arrays numpy."""
    zf = zipfile.ZipFile(path)
    prefix = zf.namelist()[0].split("/")[0]

    class Storage:
        def __init__(self, dtype, key):
            self.arr = np.frombuffer(zf.read(f"{prefix}/data/{key}"), dtype=dtype)

    def rebuild(storage, offset, size, stride, *args):
        if not size:
            return storage.arr[offset:offset + 1].reshape(())
        st = [s * storage.arr.itemsize for s in stride]
        return np.lib.stride_tricks.as_strided(storage.arr[offset:], shape=size, strides=st).copy()

    class U(pickle.Unpickler):
        def find_class(self, mod, name):
            if name == "_rebuild_tensor_v2":
                return rebuild
            if name.endswith("Storage"):
                return name
            if mod == "collections" and name == "OrderedDict":
                import collections
                return collections.OrderedDict
            return super().find_class(mod, name)

        def persistent_load(self, pid):
            _, stype, key, _loc, _n = pid
            return Storage(_DT[stype if isinstance(stype, str) else stype.__name__], key)

    pkl = [n for n in zf.namelist() if n.endswith("data.pkl")][0]
    sd = U(io.BytesIO(zf.read(pkl))).load()
    return sd.get("params_ema", sd)


def build_model(sd):
    nodes, inits = [], []
    cnt = [0]

    def nm(p):
        cnt[0] += 1
        return f"{p}_{cnt[0]}"

    def conv(x, key):
        w, b = sd[key + ".weight"].astype(np.float32), sd[key + ".bias"].astype(np.float32)
        inits.extend([numpy_helper.from_array(w, key + ".w"), numpy_helper.from_array(b, key + ".b")])
        y = nm("conv")
        nodes.append(helper.make_node("Conv", [x, key + ".w", key + ".b"], [y], pads=[1, 1, 1, 1]))
        return y

    def lrelu(x):
        y = nm("lr")
        nodes.append(helper.make_node("LeakyRelu", [x], [y], alpha=0.2))
        return y

    def op(t, ins, **kw):
        y = nm(t)
        nodes.append(helper.make_node(t, ins, [y], **kw))
        return y

    inits.append(numpy_helper.from_array(np.array(0.2, np.float32), "k02"))
    inits.append(numpy_helper.from_array(np.array([1, 1, 2, 2], np.float32), "up2"))

    def rdb(x, p):
        x1 = lrelu(conv(x, p + ".conv1"))
        x2 = lrelu(conv(op("Concat", [x, x1], axis=1), p + ".conv2"))
        x3 = lrelu(conv(op("Concat", [x, x1, x2], axis=1), p + ".conv3"))
        x4 = lrelu(conv(op("Concat", [x, x1, x2, x3], axis=1), p + ".conv4"))
        x5 = conv(op("Concat", [x, x1, x2, x3, x4], axis=1), p + ".conv5")
        return op("Add", [op("Mul", [x5, "k02"]), x])

    feat = conv("input", "conv_first")
    h = feat
    nb = len({k.split(".")[1] for k in sd if k.startswith("body.")})
    for i in range(nb):
        r = rdb(rdb(rdb(h, f"body.{i}.rdb1"), f"body.{i}.rdb2"), f"body.{i}.rdb3")
        h = op("Add", [op("Mul", [r, "k02"]), h])
    feat = op("Add", [feat, conv(h, "conv_body")])
    up = op("Resize", [feat, "", "up2"], mode="nearest")
    feat = lrelu(conv(up, "conv_up1"))
    up = op("Resize", [feat, "", "up2"], mode="nearest")
    feat = lrelu(conv(up, "conv_up2"))
    out = conv(lrelu(conv(feat, "conv_hr")), "conv_last")
    nodes.append(helper.make_node("Identity", [out], ["output"]))
    g = helper.make_graph(nodes, "rrdbnet",
                          [helper.make_tensor_value_info("input", TensorProto.FLOAT, [1, 3, None, None])],
                          [helper.make_tensor_value_info("output", TensorProto.FLOAT, [1, 3, None, None])],
                          inits)
    m = helper.make_model(g, opset_imports=[helper.make_opsetid("", 17)], ir_version=9)
    so = ort.SessionOptions()
    so.intra_op_num_threads = os.cpu_count()
    so.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    return ort.InferenceSession(m.SerializeToString(), so, providers=["CPUExecutionProvider"])


def upscale(sess, img, tile=160, pad=12):
    h, w = img.shape[:2]
    x = img.transpose(2, 0, 1)[None].astype(np.float32) / 255
    out = np.zeros((3, h * 4, w * 4), np.float32)
    for y0 in range(0, h, tile):
        for x0 in range(0, w, tile):
            y1, x1 = min(y0 + tile, h), min(x0 + tile, w)
            py0, px0 = max(y0 - pad, 0), max(x0 - pad, 0)
            py1, px1 = min(y1 + pad, h), min(x1 + pad, w)
            o = sess.run(None, {"input": np.ascontiguousarray(x[:, :, py0:py1, px0:px1])})[0][0]
            out[:, y0 * 4:y1 * 4, x0 * 4:x1 * 4] = o[:, (y0 - py0) * 4:(y1 - py0) * 4, (x0 - px0) * 4:(x1 - px0) * 4]
    return (np.clip(out, 0, 1).transpose(1, 2, 0) * 255 + 0.5).astype(np.uint8)


def main():
    sess = build_model(load_pth(sys.argv[1]))
    os.makedirs(os.path.join(ROOT, "imagens_hd"), exist_ok=True)
    only = [int(a) for a in sys.argv[2].split(",")] if len(sys.argv) > 2 else range(1, 10)
    for i in only:
        dst = os.path.join(ROOT, "imagens_hd", f"{i}.png")
        if os.path.exists(dst):
            continue
        img = cv2.imread(os.path.join(ROOT, "imagens", f"{i}.jpg"))[:, :, ::-1].copy()
        hd = upscale(sess, img)
        # mistura 15% de Lanczos para manter a textura de pintura e evitar aspecto "plástico"
        lz = cv2.resize(img, (hd.shape[1], hd.shape[0]), interpolation=cv2.INTER_LANCZOS4)
        hd = cv2.addWeighted(hd, 0.85, lz, 0.15, 0)
        cv2.imwrite(dst, hd[:, :, ::-1])
        print(i, img.shape[1::-1], "->", hd.shape[1::-1], flush=True)


if __name__ == "__main__":
    main()

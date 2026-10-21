"""Legendas poéticas em ouro, no estilo da edit de Jesus.

Cada letra nasce de pó dourado que converge, acende do desfoque para o nítido subindo de leve e,
na saída, se desfaz em pó que sobe — da esquerda para a direita. Título e fecho em Cinzel (caixa
alta espaçada), frases em Cormorant Garamond itálico.
"""
import math
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
F_TITLE = os.path.join(ROOT, "fontes", "cinzel-latin-700-normal.woff")
F_SUB = os.path.join(ROOT, "fontes", "cinzel-latin-600-normal.woff")
F_LINE = os.path.join(ROOT, "fontes", "cormorant-garamond-latin-600-italic.woff")

# (texto, entrada, saída, estilo, altura do centro em fração da tela) — entradas nas batidas
LINES = [
    ("O ÚLTIMO JURAMENTO", 1.14, 3.55, "title", 0.80),
    ("uma história de amor e honra", 1.85, 3.55, "sub", 0.885),
    ("Sob a mesma lua, um só coração.", 4.33, 5.62, "line", 0.84),
    ("Jurei te proteger…", 7.19, 9.40, "line", 0.84),
    ("…mesmo que custe a minha vida.", 10.02, 12.20, "line", 0.84),
    ("E a tempestade levou tudo —", 12.85, 15.05, "line", 0.84),
    ("menos a promessa.", 15.66, 17.90, "line", 0.84),
    ("PARA SEMPRE", 18.89, 20.30, "title", 0.50),
]
STYLE = {  # fonte, tamanho (fração da altura), espaçamento entre letras (em), atraso entre letras (s)
    "title": (F_TITLE, 0.062, 0.18, 0.045),
    "sub": (F_SUB, 0.026, 0.30, 0.020),
    "line": (F_LINE, 0.056, 0.02, 0.028),
}
T_IN, T_OUT = 0.55, 0.55          # duração da formação e do desfazer de cada letra


def _gold(h):
    """Gradiente de ouro metálico (claro no topo, bronze embaixo, faixa de brilho no meio)."""
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    top = np.float32([1.00, 0.93, 0.72])
    mid = np.float32([0.96, 0.78, 0.40])
    low = np.float32([0.62, 0.42, 0.18])
    c = np.where(y < 0.5, top + (mid - top) * (y / 0.5), mid + (low - mid) * ((y - 0.5) / 0.5))
    c = c + np.exp(-((y - 0.38) / 0.06) ** 2) * 0.12     # reflexo
    return np.clip(c, 0, 1)


class Text:
    def __init__(self, W, H):
        self.W, self.H = W, H
        self.items = [self._layout(*ln) for ln in LINES]

    def _layout(self, text, t0, t1, style, cy):
        fpath, size, track, stagger = STYLE[style]
        px = int(size * self.H)
        ss = 2
        font = ImageFont.truetype(fpath, px * ss)
        adv = [font.getlength(ch) / ss + track * px for ch in text]
        total = sum(adv) - track * px
        x = (self.W - total) / 2
        asc, desc = font.getmetrics()
        hh = int((asc + desc) / ss) + 8
        chars = []
        for k, ch in enumerate(text):
            if ch != " ":
                bw = int(adv[k] + px)
                im = Image.new("L", (bw * ss, hh * ss), 0)
                ImageDraw.Draw(im).text((px // 2 * ss, 4 * ss), ch, font=font, fill=255)
                m = np.asarray(im.resize((bw, hh), Image.LANCZOS), np.float32) / 255
                if m.max() > 0:
                    chars.append(dict(m=m, x=x - px // 2, k=k, ch=ch))
            x += adv[k]
        y = cy * self.H - hh / 2
        g = _gold(hh)
        n = len(text)
        return dict(chars=chars, y=y, hh=hh, t0=t0, t1=t1, stagger=stagger, n=n, gold=g, px=px)

    def draw(self, frame, t):
        """Desenha as legendas ativas no quadro (float RGB 0..1, in-place) e devolve o quadro."""
        W, H = self.W, self.H
        for it in self.items:
            if not (it["t0"] - 0.1 <= t <= it["t1"] + 0.8):
                continue
            # sombra suave na base para a leitura
            vis = min(1.0, max(0.0, (t - it["t0"]) / 0.4)) * min(1.0, max(0.0, (it["t1"] + 0.6 - t) / 0.6))
            if vis > 0:
                y0 = int(max(0, it["y"] - it["hh"] * 1.2))
                y1 = int(min(H, it["y"] + it["hh"] * 2.2))
                yy = np.linspace(-1, 1, y1 - y0, dtype=np.float32)[:, None, None]
                frame[y0:y1] *= 1 - 0.28 * vis * np.exp(-yy * yy * 2.5)
            dust = np.zeros((H // 2, W // 2), np.float32)
            for c in it["chars"]:
                k = c["k"]
                a_in = it["t0"] + k * it["stagger"]
                a_out = it["t1"] + k * it["stagger"] * 0.6
                p = (t - a_in) / T_IN
                q = (t - a_out) / T_OUT
                if p <= 0 or q >= 1:
                    # pó convergindo antes da letra nascer
                    if -0.6 < p <= 0:
                        self._dust(dust, c, it, p + 0.6, k, inward=True)
                    continue
                e = 1 - (1 - min(p, 1.0)) ** 3                       # forma rápido e assenta
                fade_out = 1 - max(0.0, q) ** 0.8
                alpha = e * fade_out
                blur = (1 - e) * 0.10 * it["px"] + max(0.0, q) * 0.05 * it["px"]
                dy = (1 - e) * 0.25 * it["px"] - max(0.0, q) * 0.35 * it["px"]
                m = c["m"]
                if blur > 0.6:
                    m = cv2.GaussianBlur(m, (0, 0), blur)
                glow = cv2.GaussianBlur(c["m"], (0, 0), 0.12 * it["px"]) * (0.55 + 0.6 * (1 - e) + 0.4 * max(0.0, q))
                shadow = cv2.GaussianBlur(c["m"], (0, 0), 0.06 * it["px"])
                x0 = int(c["x"])
                y0 = int(it["y"] + dy)
                h, w = m.shape
                xa, ya = max(x0, 0), max(y0, 0)
                xb, yb = min(x0 + w, W), min(y0 + h, H)
                if xa >= xb or ya >= yb:
                    continue
                sl = (slice(ya - y0, yb - y0), slice(xa - x0, xb - x0))
                reg = frame[ya:yb, xa:xb]
                # sombra (leve, deslocada para baixo), brilho e a letra em ouro
                sh = shadow[sl][..., None] * 0.55 * alpha
                reg *= 1 - sh
                reg += glow[sl][..., None] * np.float32([1.0, 0.75, 0.35]) * 0.35 * alpha
                gm = m[sl][..., None] * alpha
                col = it["gold"][sl[0]][:, None, :]
                reg[:] = reg * (1 - gm) + col * gm
                if 0 < q < 1:   # desfazendo em pó que sobe
                    self._dust(dust, c, it, q, k, inward=False)
            if dust.max() > 0:
                d = cv2.GaussianBlur(dust, (0, 0), 1.2) + cv2.GaussianBlur(dust, (0, 0), 4) * 0.6
                d = cv2.resize(d, (W, H), interpolation=cv2.INTER_LINEAR)[..., None]
                frame += np.clip(d, 0, 1.5) * np.float32([1.0, 0.82, 0.45])
        return frame

    def _dust(self, canvas, c, it, s, k, inward):
        """Partículas douradas: convergem para a letra (inward) ou sobem dela ao se desfazer."""
        rng = np.random.default_rng(1000 + k * 7 + int(it["t0"] * 100))
        h, w = c["m"].shape
        cx, cy = c["x"] + w / 2, it["y"] + h / 2
        n = 10
        ang = rng.random(n) * 6.283
        rad = (0.6 + rng.random(n)) * it["px"] * 1.6
        for j in range(n):
            if inward:
                f = 1 - s / 0.6                                     # 1 longe -> 0 na letra
                x = cx + math.cos(ang[j]) * rad[j] * f
                y = cy + math.sin(ang[j]) * rad[j] * f
                a = 0.9 * (1 - f) + 0.1
            else:
                x = cx + (rng.random() - 0.5) * w + math.cos(ang[j]) * rad[j] * 0.3 * s
                y = cy - s * it["px"] * (1.2 + rng.random()) + (rng.random() - 0.5) * h * 0.5
                a = 1 - s
            r = max(1, int(it["px"] * 0.018 * (0.5 + rng.random())))
            cv2.circle(canvas, (int(x / 2 * 16), int(y / 2 * 16)), r * 8, float(a), -1, cv2.LINE_AA, shift=4)


# ---------------------------------------------------------------- legendas da música (referência)
F_TYPE = "/usr/share/fonts/truetype/freefont/FreeMonoBold.ttf"   # máquina de escrever, como na referência


class TypeCaptions:
    """Legendas da música no estilo da referência: palavras de máquina de escrever, em creme,
    que se completam palavra a palavra no centro da tela.

    O texto vem de `legendas_musica.txt` (uma entrada por linha: `tempo | texto`). Cada entrada fica
    na tela até a próxima (ou até `tempo | -`). Palavras entre *asteriscos* ficam em marrom dourado.
    """

    def __init__(self, W, H, path=os.path.join(ROOT, "legendas_musica.txt")):
        self.W, self.H = W, H
        self.px = int(0.046 * H)
        self.font = ImageFont.truetype(F_TYPE, self.px * 2)
        self.entries = []
        if os.path.exists(path):
            for ln in open(path, encoding="utf-8"):
                ln = ln.strip()
                if not ln or ln.startswith("#") or "|" not in ln:
                    continue
                tt, txt = ln.split("|", 1)
                self.entries.append((float(tt), txt.strip()))
        self.entries.sort()
        self._cache = {}

    def _sprite(self, txt):
        if txt in self._cache:
            return self._cache[txt]
        words = txt.split(" ")
        ss = 2
        clean = " ".join(w.strip("*") for w in words)
        wtot = int(self.font.getlength(clean)) + 8 * ss
        hh = int(self.px * 1.6) * ss
        im = Image.new("L", (wtot, hh), 0)
        hl = Image.new("L", (wtot, hh), 0)
        d, dh = ImageDraw.Draw(im), ImageDraw.Draw(hl)
        x = 4 * ss
        for k, w in enumerate(words):
            ww = w.strip("*") + (" " if k < len(words) - 1 else "")
            (dh if w.startswith("*") else d).text((x, int(0.2 * self.px * ss)), ww, font=self.font, fill=255)
            x += self.font.getlength(ww)
        m = np.asarray(im.resize((wtot // ss, hh // ss), Image.LANCZOS), np.float32) / 255
        mh = np.asarray(hl.resize((wtot // ss, hh // ss), Image.LANCZOS), np.float32) / 255
        self._cache[txt] = (m, mh)
        return m, mh

    def draw(self, frame, t):
        if not self.entries:
            return frame
        cur = None
        for k, (t0, txt) in enumerate(self.entries):
            t1 = self.entries[k + 1][0] if k + 1 < len(self.entries) else t0 + 3.0
            if t0 <= t < t1 + 0.25 and txt != "-":
                cur = (t0, t1, txt)
        if cur is None:
            return frame
        t0, t1, txt = cur
        a = min(1.0, (t - t0) / 0.06) * (1.0 if t < t1 else max(0.0, 1 - (t - t1) / 0.25))
        a *= 0.94 + 0.06 * math.sin(t * 47.0) * math.sin(t * 13.0)          # leve tremido de projetor
        m, mh = self._sprite(txt)
        h, w = m.shape
        x0 = int((self.W - w) / 2)
        y0 = int(0.56 * self.H - h / 2)
        reg = frame[y0:y0 + h, x0:x0 + w]
        sh = cv2.GaussianBlur(np.maximum(m, mh), (0, 0), 0.08 * self.px)[..., None]
        reg *= 1 - 0.45 * sh * a                                             # sombra para leitura
        glow = cv2.GaussianBlur(m + mh, (0, 0), 0.18 * self.px)[..., None]
        reg += glow * np.float32([0.9, 0.82, 0.7]) * 0.18 * a
        cream = np.float32([0.93, 0.90, 0.84])
        brown = np.float32([0.62, 0.42, 0.22])
        reg[:] = reg * (1 - m[..., None] * a) + cream * m[..., None] * a
        reg[:] = reg * (1 - mh[..., None] * a) + brown * mh[..., None] * a
        return frame

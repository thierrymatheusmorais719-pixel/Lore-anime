#!/usr/bin/env python3
"""Efeitos sonoros da edit medieval, sintetizados (numpy/scipy) e mixados sob a música.

Cada efeito acompanha o que acontece na imagem: transições (íris, nuvens, raio de luz, queima,
fumaça, clarão, zooms de impacto), ambientes por cena (grilos à noite, vento no castelo, chuva na
tempestade, vento na relva) e eventos (trovões nos relâmpagos, metal da armadura, pétalas).

Uso: python3 sfx.py MUSICA.m4a  -> audio/mix.wav (música + efeitos) e audio/sfx.wav (só efeitos)
"""
import os
import subprocess
import sys

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt, stft, istft

ROOT = os.path.dirname(os.path.abspath(__file__))
SR = 48000
DUR = 21.05
N = int(DUR * SR)
rng = np.random.default_rng(42)


def t_arr(d):
    return np.arange(int(d * SR)) / SR


def bp(x, lo, hi, order=4):
    return sosfilt(butter(order, [lo, hi], "bandpass", fs=SR, output="sos"), x)


def lp(x, f, order=4):
    return sosfilt(butter(order, f, "lowpass", fs=SR, output="sos"), x)


def hp(x, f, order=4):
    return sosfilt(butter(order, f, "highpass", fs=SR, output="sos"), x)


def env_adsr(n, a, r, curve=2.0):
    """Ataque linear-suave em a (s), corpo, liberação exponencial em r (s)."""
    t = np.arange(n) / SR
    e = np.clip(t / max(a, 1e-4), 0, 1) ** 1.5
    tail = np.clip((n / SR - t) / max(r, 1e-4), 0, 1) ** curve
    return e * tail


def norm(x, peak=1.0):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def swept_noise(d, f0, f1, width=0.6, seed=0):
    """Ruído com banda que varre de f0 a f1 (whoosh), no domínio da STFT."""
    r = np.random.default_rng(seed)
    x = r.standard_normal(int(d * SR))
    f, tt, Z = stft(x, SR, nperseg=1024)
    k = np.linspace(0, 1, Z.shape[1])
    fc = f0 * (f1 / f0) ** k                     # varredura exponencial
    lf = np.log(f[:, None] + 1)
    g = np.exp(-((lf - np.log(fc[None, :] + 1)) / width) ** 2)
    _, y = istft(Z * g, SR, nperseg=1024)
    return y[: int(d * SR)]


def reverb(x, rt=1.8, wet=0.35, seed=1):
    """Reverb de sala grande (IR de ruído com decaimento exponencial), estéreo decorrelacionado."""
    n = int(rt * SR)
    out = []
    for c in range(2):
        r = np.random.default_rng(seed + c)
        ir = r.standard_normal(n) * np.exp(-6.9 * np.arange(n) / n)
        ir = lp(ir, 7000)
        ir[0] = 0
        ir /= np.sqrt(np.sum(ir ** 2))
        y = np.pad(fftconvolve(x, ir), (0, 1))[: len(x) + n]
        out.append(y)
    dry = np.pad(x, (0, n))
    return np.stack([dry * (1 - wet) + out[0] * wet, dry * (1 - wet) + out[1] * wet], 1)


def stereo(x, pan=0.0):
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    return np.stack([x * l * 1.414, x * r * 1.414], 1)


# ------------------------------------------------------------------ efeitos
def whoosh(d=0.9, f0=300, f1=4000, seed=0):
    x = swept_noise(d, f0, f1, 0.5, seed)
    return norm(x * env_adsr(len(x), d * 0.6, d * 0.4))


def impact(d=1.2):
    """Zoom de impacto: grave descendo + estalo."""
    t = t_arr(d)
    body = np.sin(2 * np.pi * np.cumsum(45 + 90 * np.exp(-t * 18)) / SR) * np.exp(-t * 5)
    click = hp(rng.standard_normal(len(t)), 1500) * np.exp(-t * 60) * 0.5
    pre = swept_noise(d, 800, 200, 0.6, 7) * np.exp(-t * 8) * 0.4
    return norm(body + click + pre)


def chime_gliss(d=2.2, base=880):
    """Brilho mágico: sinos subindo em pentatônica, com cauda longa."""
    t = t_arr(d)
    y = np.zeros_like(t)
    notes = [0, 2, 4, 7, 9, 12, 14, 16, 19]
    for k, s in enumerate(notes):
        t0 = k * 0.045
        f = base * 2 ** (s / 12)
        tt = np.clip(t - t0, 0, None)
        on = (t >= t0)
        for h, a in ((1, 1.0), (2.76, 0.35), (5.4, 0.12)):
            y += on * a * np.sin(2 * np.pi * f * h * tt + k) * np.exp(-tt * (2.5 + h))
    shimmer = hp(rng.standard_normal(len(t)), 6000) * np.exp(-t * 3) * 0.08
    return norm(y + shimmer)


def metal_clank(d=1.6, f=420):
    """Metal de armadura: parciais inarmônicas com decaimentos diferentes."""
    t = t_arr(d)
    y = np.zeros_like(t)
    for ratio, a, dec in ((1, 1.0, 5), (2.32, 0.6, 7), (3.87, 0.4, 9), (5.13, 0.3, 12), (7.2, 0.2, 16)):
        y += a * np.sin(2 * np.pi * f * ratio * t + ratio) * np.exp(-t * dec)
    y += hp(rng.standard_normal(len(t)), 3000) * np.exp(-t * 80) * 0.6
    return norm(y)


def shing(d=1.2):
    """Raio de luz: varredura brilhante metálica."""
    t = t_arr(d)
    sweep = swept_noise(d, 2000, 9000, 0.35, 3) * env_adsr(len(t), 0.25, 0.9)
    ring = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * 3.5) for f in (2637, 3520, 4186)) * np.clip(t / 0.2, 0, 1)
    return norm(sweep + 0.25 * ring)


def fire_burn(d=1.4):
    t = t_arr(d)
    roar = lp(rng.standard_normal(len(t)), 1200) * env_adsr(len(t), 0.5, 0.8)
    crack = np.zeros_like(t)
    for _ in range(60):
        i = rng.integers(0, len(t) - 400)
        crack[i:i + 400] += rng.standard_normal(400) * np.exp(-np.arange(400) / 40) * rng.random()
    crack = hp(crack, 2000) * env_adsr(len(t), 0.3, 0.8)
    return norm(roar + 0.6 * crack)


def thunder(d=4.0, close=True, seed=5):
    r = np.random.default_rng(seed)
    t = t_arr(d)
    brown = np.cumsum(r.standard_normal(len(t)))
    brown = hp(brown, 20)
    rumble = lp(brown, 220) * np.exp(-t * 0.9) * (0.6 + 0.4 * np.abs(lp(r.standard_normal(len(t)), 6)) * 8)
    out = norm(rumble)
    if close:
        crack = hp(r.standard_normal(len(t)), 900) * np.exp(-t * 14)
        out = out + 0.7 * norm(crack)
    return norm(out)


def riser_swell(d=1.6):
    """Clarão: crescendo de ar + sino suave no ápice."""
    t = t_arr(d)
    air = swept_noise(d, 400, 7000, 0.6, 9) * np.clip(t / d, 0, 1) ** 2.5
    bell = sum(a * np.sin(2 * np.pi * f * t) for f, a in ((523.3, 1.0), (784, 0.6), (1046.5, 0.4)))
    bell = bell * np.clip((t - d * 0.55) / 0.05, 0, 1) * np.exp(-np.clip(t - d * 0.55, 0, None) * 2.5)
    return norm(air + 0.5 * norm(bell))


def soft_smoke(d=1.6):
    x = swept_noise(d, 1500, 250, 0.7, 11)
    return norm(x * env_adsr(len(x), d * 0.5, d * 0.5))


# ------------------------------------------------------------------ ambientes
def crickets(d):
    t = t_arr(d)
    y = np.zeros_like(t)
    for k, (f, per, ph) in enumerate(((4300, 0.62, 0.0), (4650, 0.81, 0.3), (3950, 0.97, 0.55))):
        gate = ((t + ph) % per) < 0.09
        pulses = (np.sin(2 * np.pi * 32 * t) > 0.2) * gate
        y += np.sin(2 * np.pi * f * t) * lp(pulses.astype(float), 400) * (0.8 - 0.2 * k)
    return norm(y)


def wind(d, seed=13, lo=150, hi=1400):
    r = np.random.default_rng(seed)
    t = t_arr(d)
    x = bp(r.standard_normal(len(t)), lo, hi, 2)
    mod = 0.55 + 0.45 * np.sin(2 * np.pi * t / 3.1 + 1) * np.sin(2 * np.pi * t / 1.7)
    return norm(x * (0.4 + 0.6 * np.abs(mod)))


def rain(d, seed=17):
    r = np.random.default_rng(seed)
    t = t_arr(d)
    bed = bp(r.standard_normal(len(t)), 900, 9000, 2)
    drops = np.zeros_like(t)
    for _ in range(int(d * 90)):
        i = r.integers(0, len(t) - 300)
        drops[i:i + 300] += np.sin(2 * np.pi * r.uniform(2500, 6000) * np.arange(300) / SR) * np.exp(-np.arange(300) / 30) * r.random()
    return norm(norm(bed) + 0.5 * norm(drops))


# ------------------------------------------------------------------ mixagem
mix = np.zeros((N + 3 * SR, 2))


def place(x, t0, gain_db, pan=0.0, rev=None):
    g = 10 ** (gain_db / 20)
    if x.ndim == 1:
        x = reverb(x, *rev) if rev else stereo(x, pan)
    i = int(t0 * SR)
    j = min(i + len(x), len(mix))
    mix[i:j] += x[: j - i] * g


def fade_bed(x, fi=0.6, fo=0.8):
    n = len(x)
    e = np.ones(n)
    a, b = int(fi * SR), int(fo * SR)
    e[:a] = np.linspace(0, 1, a)
    e[n - b:] = np.linspace(1, 0, b)
    return x * e


# ambientes por cena (tempos = cortes do render.py)
place(fade_bed(crickets(6.9), 1.2, 0.5), 0.0, -30, 0.25)            # noite na varanda
place(fade_bed(wind(7.0, lo=120, hi=900), 1.0, 0.6), 0.0, -34, -0.3)
place(fade_bed(wind(3.2, seed=21), 0.4, 0.6), 6.7, -27, -0.2)        # vento no castelo
place(fade_bed(rain(3.1)), 12.45, -25, 0.0)                           # chuva na tempestade
place(fade_bed(wind(3.1, seed=29, lo=200, hi=2000)), 12.45, -28, 0.3)
place(fade_bed(wind(3.0, seed=31, lo=180, hi=1600), 0.6, 0.8), 15.25, -29, 0.0)  # vento na relva
place(fade_bed(crickets(3.0), 0.8, 1.4), 18.1, -34, -0.25)          # entardecer

# transições (o impacto de cada efeito cai no corte)
place(chime_gliss(), 3.98 - 0.20, -17, rev=(2.2, 0.45, 3))           # íris dourada
place(whoosh(0.5, 400, 3000, 1), 3.98 - 0.30, -24, -0.4)
place(impact(), 5.76 - 0.01, -15, rev=(1.4, 0.25, 4))                # zoom na dama
place(whoosh(0.35, 2500, 500, 2), 5.76 - 0.33, -22, 0.3)
place(whoosh(1.0, 200, 2500, 3), 6.82 - 0.45, -18, -0.6)             # passagem de nuvens
place(shing(), 9.66 - 0.25, -19, rev=(1.8, 0.35, 5))                 # raio de luz
place(impact(), 10.72 - 0.01, -15, rev=(1.4, 0.25, 6))               # zoom no elmo
place(metal_clank(1.6, 410), 10.74, -22, rev=(1.6, 0.3, 7))
place(fire_burn(), 12.50 - 0.35, -20, 0.2)                           # queima de filme
place(thunder(4.0, True, 5), 12.52, -15, rev=(2.5, 0.35, 8))          # relâmpagos
place(impact(), 13.55 - 0.01, -16, rev=(1.4, 0.25, 9))               # zoom na tempestade
place(thunder(3.5, True, 6), 13.57, -16, rev=(2.5, 0.35, 10))
place(thunder(3.0, False, 7), 14.95, -20, rev=(2.5, 0.35, 11))
place(soft_smoke(), 15.34 - 0.55, -21, 0.0)                          # fumaça
place(metal_clank(2.0, 300), 15.62, -27, rev=(2.2, 0.45, 12))        # a armadura vazia
place(riser_swell(), 18.18 - 0.9, -18, rev=(2.4, 0.4, 13))           # clarão final
place(chime_gliss(3.0, 660), 20.0, -25, rev=(2.6, 0.5, 14))          # brilho no fim


# legendas em ouro: impacto grave no título, pó dourado (brilho suave) em cada frase
def title_boom(d=3.0):
    t = t_arr(d)
    sub = np.sin(2 * np.pi * np.cumsum(38 + 40 * np.exp(-t * 6)) / SR) * np.exp(-t * 1.6)
    air = swept_noise(d, 3000, 300, 0.6, 21) * np.exp(-t * 3) * 0.25
    return norm(sub + air)


def dust_shimmer(d=1.6, seed=0):
    r = np.random.default_rng(seed)
    t = t_arr(d)
    y = np.zeros_like(t)
    for _ in range(26):
        t0 = r.random() * d * 0.55
        f = r.uniform(3000, 7500)
        tt = np.clip(t - t0, 0, None)
        y += (t >= t0) * np.sin(2 * np.pi * f * tt) * np.exp(-tt * 9) * r.uniform(0.3, 1.0)
    return norm(y * env_adsr(len(t), 0.2, 0.9))


CAPTION_SFX = False  # sons das legendas desligados junto com elas
if CAPTION_SFX:
    place(title_boom(), 1.14, -14, rev=(2.8, 0.45, 15))                  # "O ÚLTIMO JURAMENTO"
    for k_, t_ in enumerate((1.14, 4.33, 7.19, 10.02, 12.85, 15.66, 18.89)):
        place(dust_shimmer(1.6, 30 + k_), t_ - 0.25, -27, rev=(2.0, 0.4, 40 + k_))
    place(title_boom(3.5), 18.89, -18, rev=(3.0, 0.5, 16))               # "PARA SEMPRE"

SFX_GAIN_DB = 7.0  # efeitos ~6-10 dB abaixo da música: presentes sem cobrir a trilha
sfx = mix[:N] * 10 ** (SFX_GAIN_DB / 20)


def main():
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", sys.argv[1], "-ac", "2", "-ar", str(SR),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    music = np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)[:N]
    music = np.pad(music, ((0, N - len(music)), (0, 0)))
    # leve "ducking": a música abaixa 2 dB por instantes nos impactos para os efeitos respirarem
    lvl = np.abs(sfx).max(1)
    duck = 1 - 0.2 * np.clip(lp(lvl, 8) / (np.abs(sfx).max() + 1e-9) * 2, 0, 1)
    out = music * duck[:, None] + sfx
    fo = int(1.6 * SR)
    out[-fo:] *= np.linspace(1, 0, fo)[:, None]
    out = np.tanh(out * 1.05) / np.tanh(1.05)    # limitador suave
    os.makedirs(os.path.join(ROOT, "audio"), exist_ok=True)
    for name, data in (("mix.wav", out), ("sfx.wav", sfx / (np.abs(sfx).max() + 1e-9) * 0.9)):
        pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "s16le", "-ar", str(SR), "-ac", "2", "-i", "-",
                        os.path.join(ROOT, "audio", name)], input=pcm.tobytes(), check=True)
    print("ok -> audio/mix.wav, audio/sfx.wav")


if __name__ == "__main__":
    main()

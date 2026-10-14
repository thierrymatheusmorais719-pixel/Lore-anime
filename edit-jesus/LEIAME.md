# Edit cristã — "Golden Brown" (≈40 s)

Edit sincronizada com o trecho de "Golden Brown" do vídeo de referência, usando as 9 imagens enviadas.

- `imagens/` — originais · `imagens_hd/` — upscale 4x Real-ESRGAN · `mascaras/` — recorte da figura
- `audio/golden_brown.m4a` — trilha usada (extraída do vídeo enviado)
- `fontes/` — Cinzel (SIL Open Font License) usada nas legendas
- `upscale.py` — Real-ESRGAN x4plus rodando em ONNX Runtime (lê o .pth sem PyTorch)
- `render.py` — a edição completa
- `saida/edit_jesus.mp4` — 1440×1080, 30 fps, H.264 CRF 17 + AAC 320k, 40,4 s

Requisitos: `pip install opencv-contrib-python-headless numpy pillow onnx onnxruntime` e `ffmpeg`.

    python3 upscale.py RealESRGAN_x4plus.pth   # gera imagens_hd/ (uma vez)
    python3 render.py                          # gera saida/edit_jesus.mp4

## Sequência

Versos: corte no início de cada frase. Instrumental: cortes nas batidas do baixo.

| tempo | imagem | letra |
|---|---|---|
| 0.00–3.85 | 4 Ascensão + GOD dourado | golden brown texture like sun |
| 3.85–6.60 | 1 Cristo no deserto | lays me down with my mind |
| 6.60–9.43 | 2 Sobre as águas (noite) | she runs throughout the night |
| 9.43–11.43 | 5 Getsêmani | no need to fight |
| 11.43–15.44 | 8 Sepulcro → 7 halo | never a frown with golden brown |
| 15.44–35.92 | 3, 6, 6 close, 9, 1, 2, 5, 3, 7, 8 | (instrumental) |
| 35.92–40.40 | 4 nuvens → 7 halo → 9 ascensão final | golden brown finer temptress through |

Transições: dissolve com brilho, zoom blur, flash, punch e whip. Efeitos: parallax 2.5D com
travelling lateral, câmera na mão sutil, nuvens, raios de luz, partículas, light leaks, bloom e grão.
Legendas palavra por palavra em ouro marrom (gradiente dourado→bronze, contorno marrom e brilho).

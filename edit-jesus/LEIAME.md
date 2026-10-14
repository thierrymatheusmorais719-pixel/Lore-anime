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

Os cortes caem **exatamente nas batidas detectadas no áudio** (baixo + percussão): as batidas mais
fortes viram cortes, e as outras viram pulsos de zoom e de luz com intensidade proporcional à força
da batida (`PULSES` no `render.py`). Nos versos, o corte fica na batida mais próxima do início da frase.
O feixe de luz da imagem 13 é animado (`light_beam`): raios que ondulam, faixas de brilho descendo,
partículas caindo e intensidade que respira e pulsa nas batidas.

| tempo | imagem | letra |
|---|---|---|
| 0.00–3.85 | 4 Ascensão + GOD dourado | golden brown texture like sun |
| 4.00–6.57 | 11 Jesus olhando Jerusalém | lays me down with my mind |
| 6.57–9.46 | 2 Sobre as águas (noite) | she runs throughout the night |
| 9.46–11.38 | 12 Tentação no deserto | no need to fight |
| 11.38–15.56 | 8 Sepulcro → 7 Ressurreição | never a frown with golden brown |
| 15.56–35.78 | 10 Sermão (geral/close), 13 oração na luz, 1, 6 (geral/close), 3, 5 (geral/close), 13 close, 12 close, 11 close, 2 close, 8 close | (instrumental) |
| 35.78–40.40 | 4 nuvens → 7 halo → 9 ascensão final | golden brown finer temptress through |

Transições (sempre misturando as duas cenas, nunca corte seco):
- **zoom-through** — a cena acelera para dentro e a próxima chega desacelerando, com zoom blur e aberração cromática
- **dissolve por luminância** — as luzes da cena nova surgem primeiro, com brilho dourado
- **slide** — as duas cenas deslizam juntas com motion blur proporcional à velocidade
- **flash** — superexposição suave + tremor de impacto ao aterrissar
- **spin** — giro com desfoque rotacional · **punch** — zoom de impacto com tremor

Legendas no estilo editorial: palavras de destaque em itálico serifado (Cormorant Garamond) em
ouro metálico com reflexo de luz; versos em caixa-alta espaçada (Cinzel) cor marfim; sombra elíptica
macia atrás do bloco. Cada frase tem uma animação própria de entrada / saída:

| frase | entrada | saída |
|---|---|---|
| golden brown / texture like sun | revelação macia com desfoque | desfoque subindo |
| lays me down / with my mind | sobe de uma fenda invisível | sobe e some na fenda |
| she runs throughout / the night | letras caem em cascata | apagada da esquerda p/ direita |
| no need / to fight | letras afastadas que se juntam (tracking) | zoom de impacto |
| never a frown / with golden brown | acende com clarão dourado | flutua para cima |
| golden brown / finer temptress through | cascata | desfoque + fade final |

Jesus "vivo" (`alive_field`): respiração no peito, cabeça inclinando devagar em torno do pescoço
(o rosto se move como um bloco rígido, sem deformar), balanço leve do corpo e onda descendo pela
roupa e pelo cabelo — tudo por um campo de deslocamento suave aplicado só à figura recortada.

Efeitos: parallax 2.5D com travelling lateral, câmera na mão sutil, nuvens, raios de luz,
partículas, light leaks, bloom e grão.

# Edit cinematográfica medieval (16:9)

Edit horizontal (1920×1080, 30 fps, ~21 s) feita a partir das 7 pinturas em `refs/`,
sincronizada à música (≈85 BPM). Resultado: `edit-medieval-16x9.mp4`.

As pinturas não são redesenhadas: `render.py` (numpy + OpenCV + ffmpeg) dá vida a elas:

- **Câmera 2.5D**: mapas de profundidade (`depth/`, gerados com Depth Anything V2 por
  `depth.py`) separam primeiro plano, personagens e fundo, então pans, tilts e dollies
  têm parallax real.
- **Personagens animados ("rigs")**: braço e mão erguendo a rosa, cabeças que se inclinam
  e viram, mãos que apertam, respiração. Cada rig gira em torno de uma articulação e é
  recortado pela profundidade para não arrastar o fundo.
- **Ambiente**: vento em cabelos, capas, vestidos, relva e flores; estrelas cintilando; lua
  e sol pulsando no ritmo; raios de luz; nuvens; chuva e relâmpagos na tempestade;
  vagalumes, poeira, pólen e pétalas (inclusive caindo da rosa).
- **Sincronia**: cortes a cada compasso (2,84 s), gestos com período de 1 compasso,
  brilho/luz pulsando a cada 2 tempos, pulsos de câmera e brilho metálico nos acentos.

## Roteiro

| Tempo | Plano | Câmera | Animação | Transição |
|---|---|---|---|---|
| 0,00 | Varanda, a rosa | tilt do céu até a rosa + push-in | ele ergue a rosa, os dois se inclinam, pétalas caem | fade do preto |
| 3,98 | Varanda ao luar | da lua até o casal | elmo vira para ela, ela ergue o olhar, respira | light leak |
| 6,82 | Juramento | do castelo ao juramento | ele curva a cabeça, ela se inclina, capa ao vento | chicote |
| 9,66 | O abraço | push-in com rotação | elmo encosta nas mãos dela, ela se inclina | flash |
| 12,50 | Tempestade | pull-out | cabelos e capa ao vento, chuva, relâmpagos | preto + relâmpago |
| 15,34 | Armadura na relva | vista de cima girando | relva e flores ao vento, pólen | dissolução |
| 18,18 | Armadura nas flores | tilt até o elmo | flores ao vento, raios dourados | light leak + fade |

## Como renderizar

```bash
pip install onnxruntime opencv-python-headless numpy pillow
# uma vez (modelo: github.com/fabio-sim/Depth-Anything-ONNX, depth_anything_v2_vits.onnx)
python3 edit-medieval/depth.py depth_anything_v2_vits.onnx
python3 edit-medieval/render.py musica.m4a edit-medieval/edit-medieval-16x9.mp4
python3 edit-medieval/render.py musica.m4a /tmp/x.mp4 --stills 1.5,6.82   # quadros de teste
```

Enquadramentos, rigs, intensidades, cortes e transições ficam em `SHOTS`, `CUTS` e
`TRANS` no topo de `render.py`.

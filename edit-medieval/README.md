# Edit cinematográfica medieval

Edit vertical (1080×1920, 30 fps, ~21 s) feita a partir das 7 pinturas em `refs/`,
sincronizada à música (≈85 BPM). Resultado: `edit-medieval.mp4`.

A arte original **não é redesenhada**: cada pintura é animada por um renderizador
procedural (`render.py`, numpy + PIL + ffmpeg), preservando rostos, mãos e armaduras.

## Roteiro (cortes na grade de 8 colcheias = 2,84 s)

| Tempo | Plano | Câmera | Vida na cena | Transição de entrada |
|---|---|---|---|---|
| 0,00 | Varanda, a rosa | push-in lento até a rosa | estrelas cintilando, lua respirando, vagalumes | fade do preto |
| 3,98 | Varanda ao luar | travelling lateral do cavaleiro à dama | estrelas, vagalumes, brilho no aço | light leak dourado |
| 6,82 | Juramento no castelo | tilt-down do castelo ao juramento | nuvens passando, relva ao vento, poeira | chicote lateral (whip) |
| 9,66 | O abraço | push-in com leve rotação | reflexo varrendo o elmo, cabelo/capa | flash de luz |
| 12,50 | Tempestade | pull-out | relâmpagos, nuvens, cabelos e capa ao vento, pétalas | mergulho no preto + relâmpago |
| 15,34 | Armadura na relva | plano zenital girando | relva ao vento, pólen | dissolução pelas sombras |
| 18,18 | Armadura nas flores | push-in dourado | flores ao vento, pólen dourado, brilho | light leak + fade final |

Em todos os planos: parallax por profundidade, micro movimento de câmera na mão,
pulsos sutis nos acentos da música, bloom, grade (preto profundo, sombras
musgo/azul, altas douradas), vinheta e granulação de filme.

## Como renderizar

```bash
python3 edit-medieval/render.py musica.m4a edit-medieval/edit-medieval.mp4
# quadros de teste:
python3 edit-medieval/render.py musica.m4a /tmp/x.mp4 --stills 1.5,6.82,12.7
```

Ajustes de direção (enquadramentos, intensidades, cortes, transições) ficam nas
listas `SHOTS`, `CUTS` e `TRANS` no topo de `render.py`.

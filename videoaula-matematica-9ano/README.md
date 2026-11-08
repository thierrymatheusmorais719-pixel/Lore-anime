# Videoaula — Matemática 9º ano (Capítulo 15)

Videoaula animada em estilo lousa de giz (~56 min, 1080p, 24 fps), começando do zero:
polígonos regulares, áreas e volumes, função quadrática (com Bhaskara), estatística e probabilidade,
com exercícios resolvidos, pausas cronometradas para o aluno tentar, revisão geral, formulário e
lista de 20 exercícios com gabarito (também em `LISTA-E-GABARITO.md`).

Cada quadro é desenhado em código (canvas) e a trilha (lo-fi + sons de giz, cronômetro e sinos) é
sintetizada em JavaScript a partir do mesmo roteiro, então som e imagem não se desalinham.

| arquivo | papel |
|---|---|
| `score.js` | roteiro: todas as cenas, linhas da lousa, exercícios e tempos |
| `film.js` | desenha cada quadro (figuras, gráficos, parábolas, dados...) |
| `song.js` | gera `out/music.wav` |
| `engine/` | motor de animação (vendorizado) |

## Gerar o vídeo
Requer Node 22+, ffmpeg e Chrome/Chromium.

```bash
node song.js                                  # trilha -> out/music.wav
FAST=1 node engine/render.js video            # quadros -> out/video.mp4 (~1 h em 4 núcleos)
COPYV=1 node engine/render.js mux             # -> out/videoaula-matematica-9ano.mp4
```

Para mudar o conteúdo, edite as listas de linhas em `score.js` (`# ` fórmula, `! ` erro comum,
`> ` dica); os tempos se recalculam sozinhos.

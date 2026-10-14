# Edit cristã — "GOD" (≈20 s)

Recriação do vídeo de referência usando as 9 imagens enviadas.

- `imagens/` — imagens originais (1–9) · `mascaras/` — recorte da figura (parallax 2.5D)
- `audio/musica_referencia.m4a` — trilha extraída do vídeo de referência
- `render.py` — toda a edição (câmera, nuvens, raios, partículas, texto GOD, transições)
- `saida/edit_jesus.mp4` — 1440×1080, 30 fps, H.264 CRF 14 + AAC 320k

Requisitos: `pip install opencv-contrib-python-headless numpy pillow` e `ffmpeg`.
Render: `python3 render.py` · prévia: `python3 render.py --preview`

## Sequência (cortes nos mesmos tempos da referência)

| tempo | imagem | entrada |
|---|---|---|
| 0.00–1.30 | 4 Ascensão + texto GOD dourado entre nuvens | quadro inclinado abre + zoom radial |
| 1.30–2.20 | 1 Cristo no deserto | zoom blur |
| 2.20–3.73 | 2 Caminhando sobre as águas | whip |
| 3.73–4.97 | 3 No barco | zoom |
| 4.97–6.13 | 5 Getsêmani | flash |
| 6.13–7.50 | 6 Carregando a cruz (geral → close) | whip / punch |
| 7.50–8.63 | 7 Ressurreição com anjos (geral → close) | zoom / flash |
| 8.63–9.93 | 8 Saindo do sepulcro | whip |
| 9.93–11.23 | 9 Ascensão entre raios | zoom |
| 11.23–14.87 | closes: 1, 2, 5 | whip / zoom / whip |
| 14.87–16.07 | 4 Ascensão com nuvens | flash |
| 16.07–18.47 | closes: 3, 7, 8 | punch / flash / zoom |
| 18.47–19.80 | 9 Ascensão final, fade para luz | flash |

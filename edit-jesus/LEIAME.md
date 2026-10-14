# Edit cristã — "GOD" (≈40 s)

Edit sincronizada com `audio/musica.m4a`, usando as 9 imagens enviadas.

- `imagens/` — imagens originais (1–9) · `mascaras/` — recorte da figura (parallax 2.5D)
- `audio/musica.m4a` — trilha usada · `audio/musica_referencia.m4a` — trilha do vídeo de referência
- `render.py` — toda a edição (câmera, nuvens, raios, partículas, texto GOD, transições)
- `saida/edit_jesus.mp4` — 1440×1080, 30 fps, H.264 CRF 17 + AAC 320k, 40,5 s

Requisitos: `pip install opencv-contrib-python-headless numpy pillow` e `ffmpeg`.
Render: `python3 render.py` · prévia: `python3 render.py --preview`

## Sequência (cortes nas batidas fortes da música, ~1,15 s)

| tempo | imagem | entrada |
|---|---|---|
| 0.00–3.88 | 4 Ascensão + texto GOD dourado entre nuvens | tela cheia: flash, giro leve; zoom radial no rosto |
| 3.88–6.18 | 1 Cristo no deserto | zoom blur |
| 6.18–8.48 | 2 Caminhando sobre as águas | whip |
| 8.48–10.75 | 3 No barco | zoom |
| 10.75–13.05 | 5 Getsêmani | flash |
| 13.05–15.35 | 6 Carregando a cruz (geral → close) | whip / punch |
| 15.35–17.65 | 7 Ressurreição com anjos (geral → close) | zoom / flash |
| 17.65–19.95 | 8 Saindo do sepulcro | whip |
| 19.95–22.22 | 9 Ascensão entre raios | zoom |
| 22.22–25.66 | closes: 1, 2, 5 | whip / zoom / whip |
| 25.66–27.96 | 4 Ascensão com nuvens | flash |
| 27.96–32.53 | closes: 3, 7, 8 | punch / flash / zoom |
| 32.53–34.83 | 5 Getsêmani (música desacelerando) | flash |
| 34.83–40.50 | 9 Ascensão final, fade para a luz | flash |

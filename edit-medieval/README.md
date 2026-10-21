# Edit cinematográfica medieval (16:9, HD, 2.5D)

Edit horizontal em **4K 60 fps** (3840×2160, ~21 s) feita a partir das 7 pinturas em `refs/`,
sincronizada à música (≈85 BPM), com efeitos sonoros, no mesmo estilo 2.5D da edit de Jesus
(`edit-jesus/`). Resultados: `edit-medieval-4k.mp4` (4K) e `edit-medieval-16x9.mp4` (Full HD).

## Pipeline

- `upscale.py`: upscale 4x com Real-ESRGAN x4plus (ONNX Runtime na CPU, lê o .pth sem PyTorch),
  igual ao da edit de Jesus → `refs_hd/` (~2900 px de largura).
- `mask.py`: recorte dos personagens com BiRefNet / isnet (modelos do rembg em ONNX) →
  `mascaras_alt/`; a escolhida de cada pintura fica em `mascaras/` (BiRefNet em todas).
- `render.py`: a edição. Personagens e fundo (com inpaint) viram camadas separadas (parallax 2.5D:
  os personagens aproximam mais e deslizam sobre o fundo), com a mesma "figura viva" da edit de Jesus:
  - cabeças girando rígidas em torno do pescoço (rostos não deformam), no ritmo do compasso;
  - braços articulados (ombro + cotovelo, mão inteira): o cavaleiro ergue a rosa, a manopla aperta
    a mão dela, mãos no joelho e no punho da espada;
  - respiração, balanço do corpo, cabelo em mechas com vento e capas/vestidos ondulando;
  - ambiente vivo: céu derivando, folhagem, flores e relva balançando, névoa;
  - estrelas cintilando, raios de luz, reflexo varrendo as armaduras, chuva, relâmpagos,
    vagalumes, pólen e pétalas caindo da rosa.
- Transições da edit de Jesus (íris dourada, nuvens, raio de luz, queima de filme, fumaça,
  clarão e zoom de impacto), com o impacto caindo na batida. Pulsos de zoom e de luz nas batidas
  medidas na música (`PULSES`).

- `sfx.py`: efeitos sonoros sintetizados e mixados sob a música (`audio/mix.wav`; `audio/sfx.wav`
  só os efeitos): sinos na íris dourada, vento nas nuvens, "shing" no raio de luz, impacto e metal
  nos zooms, fogo na queima, sopro na fumaça, crescendo com sino no clarão, trovões nos relâmpagos,
  e ambientes por cena (grilos à noite, vento no castelo e na relva, chuva na tempestade).
- `legendas.py`: título "O Último Juramento" e frases poéticas em ouro nas batidas (Cinzel e
  Cormorant Garamond em `fontes/`, licença OFL); cada letra nasce de pó dourado e se desfaz em pó.
- Luz: raios de luar nas cenas noturnas, relâmpagos que iluminam a cena (céu clareia, contorno nos
  personagens) e traço anamórfico de lente nas luzes fortes.
- Corpo rígido: personagens se movem como peça inteira (sem entortar); cabeças e braços com gestos
  por mola amortecida nas batidas.
- Realismo: desfoque de movimento (obturador 180°), profundidade de campo com puxada de foco,
  movimento orgânico com inércia, halação de película e aberração cromática leve.

## Roteiro

| Tempo | Plano | Transição de entrada |
|---|---|---|
| 0,00 | Varanda: ele ergue a rosa, pétalas caem | fade do preto |
| 3,98 | Varanda ao luar | íris dourada |
| 5,76 | Close na dama | zoom de impacto |
| 6,82 | Juramento diante do castelo | passagem de nuvens |
| 9,66 | O abraço | raio de luz |
| 10,72 | Close nas mãos e no elmo | zoom de impacto |
| 12,50 | Tempestade (chuva, relâmpagos) | queima de filme |
| 13,55 | Close na tempestade | zoom de impacto |
| 15,34 | Armadura vazia na relva | fumaça |
| 18,18 | Armadura nas flores, luz dourada | clarão + fade final |

## Como renderizar

```bash
pip install onnx onnxruntime opencv-python-headless numpy pillow
python3 edit-medieval/upscale.py RealESRGAN_x4plus.pth     # uma vez -> refs_hd/
python3 edit-medieval/mask.py <pasta_dos_modelos_rembg>    # uma vez -> mascaras_alt/
python3 edit-medieval/sfx.py musica.m4a                    # -> audio/mix.wav (música + efeitos)
# 4K em 4 partes (cada uma ~16 min em 4 núcleos) e junção com o áudio
for k in 0 1 2 3; do python3 edit-medieval/render.py edit-medieval/audio/mix.wav edit-medieval/edit-medieval-4k.mp4 --seg $k/4; done
python3 edit-medieval/render.py edit-medieval/audio/mix.wav edit-medieval/edit-medieval-4k.mp4 --mux 4
EDIT_RES=1080 python3 edit-medieval/render.py edit-medieval/audio/mix.wav /tmp/x.mp4 --stills 1.5,6.82   # testes
```

`depth.py`/`depth/` (mapas de profundidade da versão anterior) ficam como referência.

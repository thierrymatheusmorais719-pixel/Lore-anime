# Edit cinematográfica medieval (16:9, HD, 2.5D)

Edit horizontal (1920×1080, 60 fps, ~21 s) feita a partir das 7 pinturas em `refs/`,
sincronizada à música (≈85 BPM), no mesmo estilo 2.5D da edit de Jesus (`edit-jesus/`).
Resultado: `edit-medieval-16x9.mp4`.

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
python3 edit-medieval/render.py musica.m4a edit-medieval/edit-medieval-16x9.mp4
python3 edit-medieval/render.py musica.m4a /tmp/x.mp4 --stills 1.5,6.82   # quadros de teste
```

`depth.py`/`depth/` (mapas de profundidade da versão anterior) ficam como referência.

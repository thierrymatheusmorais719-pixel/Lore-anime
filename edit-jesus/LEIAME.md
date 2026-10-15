# Edit cristã — "Golden Brown" (≈40 s)

Edit sincronizada com o trecho de "Golden Brown" do vídeo de referência, usando as 9 imagens enviadas.

- `imagens/` — originais · `imagens_hd/` — upscale 4x Real-ESRGAN
- `mascaras/` — recorte da figura escolhido por auditoria (`escolha.json`: BiRefNet-portrait, u2net_human_seg,
  isnet ou união); `mascaras_alt/` — todas as máscaras candidatas (inclui as antigas `*_isnet.png`)
- `audio/golden_brown.m4a` — trilha usada (extraída do vídeo enviado)
- `fontes/` — Cinzel (SIL Open Font License) usada nas legendas
- `upscale.py` — Real-ESRGAN x4plus rodando em ONNX Runtime (lê o .pth sem PyTorch)
- `render.py` — a edição completa
- `god_text.py` — letreiro GOD em ouro (Cinzel Black, bisel, reflexo, metal escovado)
- `saida/edit_jesus.mp4` — 1920×1440, 120 fps, H.264 CRF 18 + AAC 320k, 40,4 s (render direto em CRF 17 e recomprimido para caber no GitHub)

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
| 3.85–6.56 | 11 Jesus olhando Jerusalém | lays me down with my mind |
| 6.56–9.32 | 2 Sobre as águas (noite) | she runs throughout the night |
| 9.32–11.24 | 12 Tentação no deserto | no need to fight |
| 11.24–15.45 | 8 Sepulcro → 7 Ressurreição | never a frown with golden brown |
| 15.45–35.93 | 10, 13, 1, 6, 3, 5, 12, 11, 2 (uma vez cada, ~2 s, aberto → close) | (instrumental) |
| 35.93–40.40 | 4 nuvens → 7 halo → 9 ascensão final | golden brown finer temptress through |

Nenhuma foto troca para ela mesma; cada transição dura ~1,1–1,5 s (limitada a 45% do plano vizinho).

Transições (o impacto cai na batida; tipo por corte em `SHOTS`):
- **burn** — queima de filme: a cena nova queima a antiga com uma frente incandescente
- **iris** — íris dourada: um círculo de luz se abre a partir do rosto de Jesus
- **cloud** — passagem de nuvens: um banco de nuvens atravessa a tela e a cena troca por trás
- **flare** — raio de luz: faixa dourada diagonal com brilho de lente anamórfico
- **smoke** — fumaça: dissolve orgânico com bordas de fumaça
- **bloom** — clarão: a cena se desfaz em luz e a próxima nasce dela · **punch** — zoom de impacto (closes)

Legendas no estilo editorial (destaque em itálico ouro metálico, versos em caixa-alta marfim).
Animação **pó de ouro**: partículas douradas convergem e formam cada letra, que acende do desfoque
para o nítido (faísca nas palavras de destaque) um pouco antes da voz; na saída as letras se desfazem
em pó que sobe, da esquerda para a direita.

Jesus "vivo" (`alive_field`): respiração no peito, cabeça inclinando devagar em torno do pescoço
(o rosto se move como um bloco rígido, sem deformar), balanço leve do corpo e onda descendo pela
roupa e pelo cabelo — tudo por um campo de deslocamento suave aplicado só à figura recortada.

Animação das fotos (tudo procedural, calculado quadro a quadro a 120 fps):
- **Jesus vivo** (`alive_field`): respiração, cabeça inclinando (rosto rígido), balanço do corpo,
  **cabelo** com mechas presas na raiz e pontas soltas balançando com rajadas de vento, roupa ondulando.
  Rostos secundários (Pedro, anjos, o tentador) ficam travados.
  Pontos presos (`PINS`): a mão apoiada na parede do sepulcro fica fixa no cenário, compensando até o parallax.
  A figura é projetada já com a animação direto da imagem HD (`warp_figure`): mãos perto da borda
  da tela nunca ficam cortadas. Auréolas que o recorte deixou de fora entram na figura (`HALO_ADD`).
- **Braços articulados** (`ARMS` / `arm_field`): nas fotos com braços livres (3, 4, 7, 9, 10, 12), o ombro
  gira o braço inteiro e o cotovelo gira o antebraço com leve atraso, como ossos rígidos — mãos e dedos
  se movem inteiros, sem deformar.
- **Ambiente vivo** (`ENV` / `env_field`): água com ondulação orgânica e brilhos nas cristas (cena do mar),
  nuvens que derivam e mudam de forma, folhas/flores/capim balançando, névoa e calor tremulando.
- **GOD** com reflexo de luz que atravessa as letras e faísca em estrela nas batidas da introdução.

Efeitos: parallax 2.5D com travelling lateral, câmera na mão sutil, nuvens, raios de luz,
partículas, light leaks, bloom e grão.

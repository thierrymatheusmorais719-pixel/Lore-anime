# Black Demon — Episódio 1: O Despertar Carmesim

Animação de 54 s feita a partir da página do mangá (`assets/pagina-original.webp`).
Os quadros 1 a 8 viraram planos animados. O quadro 9, o painel de controle, não foi animado:
virou os controles reais do player (SOM, MÚSICA, INÍCIO, REPRODUZIR DE NOVO).

Tudo roda no navegador, num `<canvas>` 2D, sem bibliotecas. A trilha e os efeitos sonoros
são sintetizados na hora (Web Audio).

## Como assistir

Os módulos JS não abrem direto pelo arquivo (`file://`), então use um servidor local
na raiz do repositório:

```bash
python3 -m http.server 8000
```

Depois abra **http://localhost:8000/black-demon/** e clique em **ASSISTIR**.

| Controle | Ação |
|---|---|
| Clique no vídeo / no quadro dos olhos, `Espaço` | pausar / continuar |
| Barra vermelha embaixo do vídeo, `← / →` | avançar / voltar |
| `F` | tela cheia |
| SOM | liga/desliga os efeitos sonoros |
| MÚSICA | liga/desliga a trilha |
| INÍCIO | segundo em que o "Reproduzir de novo" começa |

`?t=32` na URL já abre no segundo 32 (a explosão).

## Roteiro

| Tempo | Plano | O que acontece |
|---|---|---|
| 0–4 s | Abertura | Batidas de coração, título com glitch |
| 4–12 s | 1. Transformação | Câmera se aproxima, aura carmesim surge, os olhos ficam vermelhos, quadro de impacto |
| 12–16 s | 2. Ataque | Fundo escuro, traço vermelho brilhante, olhos acendem, raios |
| 16–20 s | 3. Olhos | Câmera desce até o sorriso, rachaduras pulsando no ritmo |
| 20–26 s | 4. Explosão | A íris gira, círculo rúnico, mergulho na pupila e o reflexo da explosão |
| 26–32 s | 8. Ataque (detalhe) | Energia sendo sugada pelo orbe, disparo e um silêncio superexposto |
| 32–40 s | 5. Fim do vilão | Quadros de impacto, onda de choque, destroços, câmera tremendo |
| 40–46 s | 6. Visão de satélite | Espaço, estrelas, anéis vermelhos se espalhando pelo planeta |
| 46–52 s | 7. Quadro final | Vento, brilho nos olhos, cartão "AKARI KURENAI" |
| 52–54 s | Encerramento | Logotipo |

O quadro 8 entra antes do 5 porque é o golpe que causa a explosão. Para mudar a ordem
ou a duração, edite `SHOTS` em `js/film.js` (e os tempos em `js/audio.js`).

## Estrutura

```
black-demon/
  index.html            Página e controles
  css/player.css        Visual de mangá (bordas pretas, papel)
  js/main.js            Relógio sincronizado com o áudio, controles, modo exportação
  js/film.js            ★ Roteiro: um desenho por plano, câmera e efeitos
  js/fx.js              Efeitos: brilho, raios, partículas, linhas de velocidade, ondas de choque
  js/audio.js           ★ Trilha e efeitos sonoros sintetizados (partitura)
  js/util.js            Easing e aleatório determinístico
  assets/painel-N.png   Quadros recortados da página, limpos e ampliados 3× (traço com transparência)
  assets/fonts/         Oswald e Pirata One (licença OFL)
  tools/exportar.js     Gera o MP4 1080p
```

## Vídeo pronto

`video/black-demon-ep1.mp4`: 1920×1080, 30 qps, 54 s, com som.

## Exportar o vídeo (MP4)

Precisa de Node 18+, `npm i playwright` e `ffmpeg`:

```bash
python3 -m http.server 8000 &
node black-demon/tools/exportar.js http://localhost:8000/black-demon/ black-demon.mp4
```

Cada quadro é desenhado a partir do tempo exato, sem estado, então o vídeo sai igual ao player.

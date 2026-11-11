# Duelo dos Feiticeiros — cinemática de luta (Roblox)

Cinemática roteirizada (~45 s) de uma luta entre feiticeiros em cima de um prédio, à noite, no estilo das
lutas de anime de "jujutsu": encarada, choque com quadro de impacto, troca de golpes com câmera em órbita,
técnicas com nome em letras grandes, duas "expansões de técnica" ao mesmo tempo e um golpe final.

Personagens **originais** (não são Gojo nem Sukuna):
- **Ren Arashi**, Feiticeiro da Tempestade (energia ciano): *Lança do Trovão*, *Olho da Tempestade*.
- **Akane Sumi**, Feiticeira da Tinta Carmesim (energia vermelha, pincel gigante): *Traço Carmesim*, *Pergaminho Sem Fim*.

## Como abrir
1. Baixe `build/DueloFeiticeiros.rbxl` e abra no Roblox Studio.
2. Aperte **Play**. A cinemática começa sozinha ~1 s depois do personagem aparecer.
3. Botão **Pular ▸** no canto; no fim aparece **▶ Assistir de novo**.

Para editar com Rojo: `rojo serve default.project.json`.

## Estrutura
| Arquivo | O que faz |
|---|---|
| `src/shared/City.luau` | Cidade noturna (prédios, janelas acesas, letreiros, lua), arena no telhado, luz/névoa |
| `src/shared/Rig.luau` | Os dois lutadores (peças + Motor6D) e as poses (guarda, soco, chute, sinal de mão...) |
| `src/shared/Vfx.luau` | Efeitos: impactos, ondas de choque, raios, feixes, cortes de tinta, cúpulas, quadro de impacto |
| `src/shared/Shot.luau` | Câmera: cortes, travellings, órbitas, seguir rosto, tremor |
| `src/shared/Ui.luau` | Barras de cinema, legendas, nome das técnicas, linhas de velocidade, cartão final |
| `src/shared/Timeline.luau` | **O roteiro**: tomada por tomada (edite aqui falas, tempos e golpes) |
| `src/server/Main.server.luau` | Monta a cidade e o ponto de nascimento |
| `src/client/Main.client.luau` | Toca a cinemática, esconde a interface padrão, replay |

## Testes (fora do Studio)
- `python3 tools/run_sim.py <luau>`: roda a cinemática inteira no simulador do Mythical Isles
  (`../mythical-isles/tools`) e confere tomadas, erros, câmera, limpeza, replay e pular.
- `python3 tools/run_sim.py <luau> preview/export_frames.luau`: exporta os quadros; `tools/preview/render.html` +
  `shoot.js` geram a prévia em vídeo (aproximada, sem partículas).

**Limitação:** nada disso foi testado dentro do Roblox Studio. O simulador não renderiza nem tem física real;
a prévia em vídeo é uma aproximação com three.js.

Texturas de partícula usadas: só as embutidas no Roblox (`rbxasset://textures/particles/...`). Nenhum ID de
catálogo ou de asset externo.

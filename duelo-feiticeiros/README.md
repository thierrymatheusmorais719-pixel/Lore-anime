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

## Corpos R15 e animações do Blender
- Os lutadores são **avatares R15 do Roblox**: o servidor monta cada um com `Players:CreateHumanoidModelFromDescription`
  (cores do personagem). Se isso falhar, o cliente monta um R15 "blocky" de peças com os mesmos nomes de peças e juntas.
  Por cima vão detalhes simples feitos de peças (cabelo, faixa; a Akane tem rabo de cavalo e o pincel nas costas).
- As **animações** (13: idle, guard, dash, punch, punchL, kick, hurt, slash, castUp, castPoint, handSign, float,
  kneel) foram feitas no Blender: `tools/blender/r15_anims.py` cria um esqueleto R15 (um osso por Motor6D),
  põe os keyframes (com antecipação, golpe com exagero e acomodação), o Blender interpola com curvas Bézier e o
  script amostra a 30 qps em `src/shared/Anims.luau`. O arquivo `tools/blender/r15_luta.blend` tem o esqueleto,
  um boneco e todas as ações, para abrir e editar no Blender. Depois de editar, rode o script de novo.
- No jogo, `Rig.luau` toca essas animações direto nos `Motor6D.Transform` (com transição entre elas). Não precisa
  publicar animações nem usar IDs de animação.
- `tools/blender/render_poses.py` renderiza no Blender (Cycles, CPU) uma folha com as poses.

## Itens do catálogo (roupa, calça, cabelo)
Em `src/shared/Appearance.luau` (no Studio: ReplicatedStorage → Duelo → Appearance) cada lutador tem campos
`shirt`, `pants`, `hair`, `accessories`, `face` e `skin`. Por padrão estão vazios e a cinemática usa os modelos
R15 só com as cores. Se você preencher um ID, o servidor acrescenta o item ao avatar R15. Se o avatar não puder
ser montado, aparece um aviso no Output e a cinemática usa o R15 de peças.

## Estrutura
| Arquivo | O que faz |
|---|---|
| `src/shared/City.luau` | Cidade noturna (prédios, janelas acesas, letreiros, lua), arena no telhado, luz/névoa |
| `src/shared/Rig.luau` | Os dois lutadores em R15 e o tocador das animações |
| `src/shared/Anims.luau` | Animações geradas pelo Blender (não editar à mão) |
| `src/shared/Vfx.luau` | Efeitos: impactos, ondas de choque, raios, feixes, cortes de tinta, cúpulas, quadro de impacto |
| `src/shared/Shot.luau` | Câmera: cortes, travellings, órbitas, seguir rosto, tremor |
| `src/shared/Ui.luau` | Barras de cinema, legendas, nome das técnicas, linhas de velocidade, cartão final |
| `src/shared/Appearance.luau` | IDs opcionais de itens do catálogo para cada lutador |
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

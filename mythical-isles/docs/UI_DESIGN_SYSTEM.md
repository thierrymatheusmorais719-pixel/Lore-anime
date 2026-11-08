# Mythical Isles — Guia de Design de Interface (UI/UX Design System)

> Guia para refazer a interface no padrão de simuladores grandes do Roblox. Tudo aqui é montável no Roblox
> Studio com objetos nativos (`Frame`, `ImageLabel`, `UICorner`, `UIStroke`, `UIGradient`, `CanvasGroup`,
> `ViewportFrame`, `TweenService`) e com o que o jogo já tem em `src/client/Controllers/UIKit.luau`.
>
> **Status:** é uma especificação. A interface atual (HUD, painéis, CombatHUD) ainda não foi refeita.
> Os itens marcados **[novo]** não existem no jogo hoje (por exemplo a moeda Gemas e os NPCs Oakenheart,
> Petalweave e Stonefist).
>
> **Imagens:** o projeto não usa assets de terceiros nem IDs inventados. As molduras são montadas com
> peças de UI (camadas de `Frame` + `UIStroke` + `UIGradient`). Os ícones usam glifos de texto até o autor
> enviar as próprias imagens pelo Asset Manager. Onde uma textura ajudaria, o guia diz qual, e o ID será
> o que o Roblox gerar no envio.

---

## Sumário

1. [Identidade visual](#1-identidade-visual)
2. [Tokens: cores, tipografia, espaçamento](#2-tokens-cores-tipografia-espaçamento)
3. [Biblioteca de componentes](#3-biblioteca-de-componentes)
4. [HUD principal](#4-hud-principal)
5. [Diálogo com NPCs (missões)](#5-diálogo-com-npcs-missões)
6. [Menus de tela cheia](#6-menus-de-tela-cheia)
7. [Seleção e teleporte de mundos](#7-seleção-e-teleporte-de-mundos)
8. [Animações e feedback visual](#8-animações-e-feedback-visual)
9. [Celular, acessibilidade e desempenho](#9-celular-acessibilidade-e-desempenho)
10. [Plano de implementação no código](#10-plano-de-implementação-no-código)

---

## 1. Identidade visual

### 1.1 Pilares

| Pilar | O que significa na tela | O que evitar |
|---|---|---|
| **Relíquia mágica** | Molduras de pedra rúnica e madeira polida, com cantos chanfrados e um friso de cristal/neon | Caixas cinzas retas, botão branco padrão do Roblox |
| **Leitura em 1 segundo** | Número grande, ícone grande e cor de raridade forte | Texto pequeno sobre fundo claro, três tons parecidos lado a lado |
| **Tela limpa** | Fundos escuros translúcidos; o 3D aparece através da UI | Painéis opacos cobrindo o mapa durante a exploração |
| **Recompensa que comemora** | Cada ganho tem som, brilho e escala ("pop") proporcionais à raridade | Ganho silencioso; animação longa em coisa comum |

### 1.2 Materiais da interface

Cada material é uma receita de camadas. Ver o passo a passo em [3.1](#31-moldura-rúnica-runeframe).

| Material | Uso | Receita curta |
|---|---|---|
| **Pedra rúnica** | Painéis principais, barra superior | Fundo `#1C1830` a 12% de transparência + gradiente vertical (topo mais claro) + `UIStroke` duplo (escuro por fora, friso claro por dentro) + runas finas em neon nos cantos |
| **Madeira polida** | Botões de categoria, abas, placas de nome de NPC | Gradiente `#8A5A32 → #5A3820` + veio (2 a 3 `Frame` de 2 px, 15% de opacidade) + borda `#2A1A10` |
| **Cristal / neon** | Destaques, foco, raridade, botões de ação | `UIStroke` de 2 px na cor de acento + segundo `UIStroke` de 6 px na mesma cor a 75% de transparência (simula brilho) |
| **Seiva / energia** | Preenchimento de barras (vida, XP, energia, Fúria) | Gradiente horizontal com 3 paradas + `UIGradient.Offset` animado (ver [4.4](#44-barras-de-status-do-jogador)) |

### 1.3 Tema por mundo

A estrutura é a mesma em todos os mundos. Muda só o **acento**: friso, brilho e ícone do mundo.

| Mundo | Nome no jogo | Acento | Secundário | Motivo dos cantos |
|---|---|---|---|---|
| 1 | Verdant Haven | `#7CE65A` verde-folha | `#FFD678` seiva dourada | folha + runa de raiz |
| 2 | Crystal Hollow | `#78DCFF` azul-cristal | `#B98CFF` violeta | prisma |
| 3 | Skybound Kingdom | `#FFFFFF` branco | `#E8B83C` ouro | asa |
| 4 | Whispering Wilds | `#B48CFF` lilás | `#5AD2B4` verde-água | olho / névoa |
| 5 | Astral Sanctuary | `#FFDC8C` ouro-estelar | `#9A7CFF` violeta | estrela |

> Os acentos dos mundos 1, 2, 4 e 5 já existem em `Config/Worlds.luau` (`palette.accent`). Reaproveite-os
> para o tema acompanhar o mundo do jogador automaticamente (atributo `World` do jogador).

---

## 2. Tokens: cores, tipografia, espaçamento

### 2.1 Fundos e superfícies

| Token | Hex | RGB | Uso |
|---|---|---|---|
| `bg.scrim` | `#0A0816` | 10, 8, 22 | Escurecer a tela atrás de menus de tela cheia (`BackgroundTransparency` 0.45) |
| `bg.panel` | `#1C1830` | 28, 24, 48 | Painel principal (transparência 0.12) |
| `bg.panel2` | `#2A2448` | 42, 36, 72 | Cartões, slots, linhas de lista |
| `bg.inset` | `#120F22` | 18, 15, 34 | Áreas "afundadas": campo de texto, trilho das barras |
| `edge.dark` | `#0B0914` | 11, 9, 20 | `UIStroke` externo (contorno) |
| `edge.light` | `#6C62A8` | 108, 98, 168 | Friso interno (relevo) |
| `wood.top` / `wood.bot` | `#8A5A32` / `#5A3820` | 138, 90, 50 / 90, 56, 32 | Madeira polida |
| `stone.top` / `stone.bot` | `#4A4560` / `#2A2638` | 74, 69, 96 / 42, 38, 56 | Pedra rúnica |

### 2.2 Ações e estados

| Token | Hex | RGB | Uso |
|---|---|---|---|
| `action.confirm` | `#2ECC71` | 46, 204, 113 | Comprar, aceitar, equipar (verde-esmeralda) |
| `action.confirm.hi` | `#7DFFB0` | 125, 255, 176 | Topo do gradiente / brilho do verde |
| `action.cancel` | `#E5484D` | 229, 72, 77 | Fechar, recusar, excluir |
| `action.cancel.hi` | `#FF8A8E` | 255, 138, 142 | Topo do gradiente do vermelho |
| `action.info` | `#3BA9FF` | 59, 169, 255 | Botões neutros e informativos |
| `action.disabled` | `#5A5670` | 90, 86, 112 | Sem dinheiro, bloqueado (texto `#A9A6BD`) |
| `status.hp` | `#3DDC6A` → `#1E9E45` | — | Vida |
| `status.energy` | `#5AC8FF` → `#2A7BE0` | — | Energia/mana (azul-celeste) |
| `status.xp` | `#B18CFF` → `#6C4BE0` | — | Experiência |
| `status.fury` | `#FFC450` → `#FF7A2E` | — | Fúria (ataque Assinatura) |

### 2.3 Moedas

| Moeda | No jogo | Cor | Glifo provisório |
|---|---|---|---|
| **Gold** | `coins` (Moedas) | `#FFD246` | ● |
| **Essência** | `essence` | `#78E6C8` | ◆ |
| **Fragmentos Astrais** | `astral` | `#AA96FF` | ✦ |
| **Cristais do mundo** | material do mundo: `verdant_sap` (Seiva Verdejante), `prism_shard`, `storm_feather`… | cor do item em `Config/Items.luau` | ⬢ |
| **Gemas** **[novo]** | não existe | `#FF5CA8` | ♦ |

> **Gemas** seriam uma moeda premium nova (vendida por Robux em Developer Products). Isso exige criar os
> produtos no Creator Dashboard; os IDs vêm de lá. Até lá, o slot das Gemas na barra superior fica oculto.

### 2.4 Raridades

As cores são as mesmas de `Config/Rarities.luau`, para a UI e o jogo nunca discordarem.

| Raridade | Fundo do slot (topo → base) | Borda | Efeito no slot |
|---|---|---|---|
| Comum | `#BEC4CC` → `#7A8088` | `#5A6068` | nenhum |
| Incomum | `#6ED678` → `#3A9A48` | `#2A6A34` | nenhum |
| Raro | `#50A0FF` → `#2A60C8` | `#1C4290` | brilho suave na borda |
| Épico | `#B062FF` → `#6A2AC8` | `#4A1A90` | brilho na borda + gradiente que gira devagar |
| Lendário | `#FFBA30` → `#E07A10` | `#8A4A08` | gradiente girando + brilho pulsando |
| Mítico | `#FF4878` → `#B01848` | `#700A2C` | girando + pulso + partículas de UI |
| Secret | `#28283A` → `#0A0A12`, acento `#EBEBFF` | `#EBEBFF` | contorno branco cintilante + estrelas |
| Celestial | `#96E6FF` → `#FFF0B4` | `#FFFFFF` | arco-íris suave girando + aura |

**Daltonismo:** a cor nunca vem sozinha. Todo slot mostra também a **sigla** da raridade (C, I, R, É, L, M, S,
✦) no canto e, a partir de Épico, um **padrão** no fundo (listras diagonais via `UIGradient`).

### 2.5 Tipografia

| Papel | Fonte (`Enum.Font`) | Tamanho em 1080p | Estilo |
|---|---|---|---|
| Título de janela, nome do mundo | **FredokaOne** (já é o `T.title` do jogo) | 32 a 40 | `UIStroke` de texto 2,5 px `#0B0914` |
| Números grandes (moedas, dano, nível) | **FredokaOne** | 22 a 28 | contorno 2 px + leve gradiente vertical |
| Botões | **GothamBlack** (`T.bold`) | 18 a 22 | contorno 1,5 px |
| Texto corrido, descrições | **GothamBold** (`T.body`) | 15 a 17 | sem contorno, sobre `bg.inset` |
| Fala de NPC | **PatrickHand** | 20 a 22 | cor `#F4ECD8` (pergaminho) |

> O Roblox renderiza os `Enum.Font.Gotham*` com uma fonte substituta atual. Confira a aparência no Studio;
> se precisar de pesos exatos, use `TextLabel.FontFace = Font.new(...)` com uma família do próprio Roblox.

Regras:
- `TextScaled` só em rótulos de largura fixa (números do HUD). Em textos longos use tamanho fixo + `UITextSizeConstraint` (`MinTextSize` 12, `MaxTextSize` 22).
- Contorno de texto: `TextStrokeTransparency` 0 com `TextStrokeColor3` = `edge.dark`. Para contorno mais grosso, use um `UIStroke` com `ApplyStrokeMode = Contextual` dentro do `TextLabel`.
- Números com separador: `1.250.000` → abreviar a partir de 100 mil (`1,25 M`). O `UIKit.fmt` já faz isso.

### 2.6 Espaçamento, cantos e sombras

| Token | Valor | Uso |
|---|---|---|
| `space.xs / sm / md / lg / xl` | 4 / 8 / 12 / 16 / 24 px | `UIPadding`, `UIListLayout.Padding` |
| `radius.sm / md / lg / pill` | 8 / 12 / 18 / 999 px | `UICorner.CornerRadius` |
| `stroke.outer` | 3 px, `edge.dark` | contorno de todo painel e botão |
| `stroke.inner` | 1,5 px, `edge.light`, transparência 0,35 | friso de relevo |
| `shadow` | `Frame` irmão, deslocado (0, +6 px), preto a 55% de transparência, mesmo `UICorner` | profundidade |
| `hit.min` | 48 × 48 px (celular 56 × 56) | menor área clicável |

### 2.7 Tokens em Lua (para `UIKit.Theme`)

```lua
-- acrescentar ao UIKit.Theme (os nomes atuais continuam valendo)
T.scrim      = Color3.fromRGB(10, 8, 22)
T.panelDark  = Color3.fromRGB(28, 24, 48)
T.panel2     = Color3.fromRGB(42, 36, 72)
T.inset      = Color3.fromRGB(18, 15, 34)
T.edgeDark   = Color3.fromRGB(11, 9, 20)
T.edgeLight  = Color3.fromRGB(108, 98, 168)
T.confirm, T.confirmHi = Color3.fromRGB(46, 204, 113), Color3.fromRGB(125, 255, 176)
T.cancel,  T.cancelHi  = Color3.fromRGB(229, 72, 77),  Color3.fromRGB(255, 138, 142)
T.energy   = Color3.fromRGB(90, 200, 255)
T.fury     = Color3.fromRGB(255, 196, 80)
T.speech   = Enum.Font.PatrickHand
T.radius   = { sm = 8, md = 12, lg = 18 }
```

---

## 3. Biblioteca de componentes

### 3.1 Moldura rúnica (`RuneFrame`)

A base de todo painel. Camadas, de trás para frente:

```
RuneFrame (Frame, transparente)
├── Shadow       Frame  pos (0, 0, 0, 6)  cor #000  transp 0.55  UICorner lg
├── Body         Frame  cor stone.bot     transp 0.12  UICorner lg
│   ├── UIGradient  Rotation 90  Color: stone.top → stone.bot
│   │               Transparency: 0 → 0.15   (topo mais "iluminado")
│   ├── UIStroke    3 px edge.dark  (contorno)
│   ├── Bevel       Frame inset 3 px, sem fundo, UICorner lg-3
│   │   └── UIStroke 1.5 px edge.light transp 0.35   (friso de relevo)
│   ├── Corner_TL…BR 4 × Frame 18×18 px rotacionados 45° (losango), cor do acento do mundo,
│   │               Material visual: UIStroke 1 px branco transp 0.6 → "runa de canto"
│   ├── Header      Frame altura 54 px, madeira polida (ver 3.3) com o título
│   └── Content     Frame com UIPadding md e o conteúdo
└── Glow         Frame do mesmo tamanho, sem fundo, UIStroke 6 px acento transp 0.8 (só quando em foco)
```

Propriedades-chave:
- `UICorner.CornerRadius = UDim.new(0, 18)` no corpo; cantos "chanfrados" saem dos losangos sobrepostos.
- O escurecimento do mapa atrás vem do **`BlurEffect` no `Lighting`** (`Size` 0 → 14 ao abrir), não da moldura. O Roblox não desfoca o que está atrás de um `Frame`; ele desfoca a cena 3D inteira.
- Para fazer fade do painel inteiro, coloque o `Body` dentro de um **`CanvasGroup`** e anime `GroupTransparency`.

### 3.2 Botões

| Variante | Fundo (gradiente vertical) | Borda | Texto | Uso |
|---|---|---|---|---|
| **Confirmar** | `confirm.hi` → `confirm` | 3 px `#0E5A30` | branco, contorno escuro | Comprar, Aceitar, Equipar |
| **Cancelar** | `cancel.hi` → `cancel` | 3 px `#6A1418` | branco | Fechar, Recusar, Excluir |
| **Info** | `#8ACDFF` → `#3BA9FF` | 3 px `#123E6A` | branco | Detalhes, Ver chances |
| **Dourado** | `#FFE48A` → `#E8A81C` | 3 px `#6A4A08` | `#3A2400` | Melhor oferta, Robux, Lendário |
| **Madeira** | `wood.top` → `wood.bot` | 3 px `#2A1A10` | `#FFE9C8` | Abas e categorias |
| **Desativado** | `action.disabled` liso | 3 px `#2A2838` | `#A9A6BD` | Sem saldo, bloqueado |

Estrutura do botão (lembra um "botão de jogo" com espessura):

```
Button (TextButton, AutoButtonColor = false, fundo transparente)
├── Base   Frame  cor = borda escura, deslocada (0, 0, 0, 4)   ← a "espessura" de baixo
└── Face   Frame  gradiente da variante, UICorner md, UIStroke 3 px borda
    ├── Shine  Frame topo 45% da altura, branco, transp 0.82, UICorner md   ← reflexo
    ├── Icon   TextLabel/ImageLabel 28 px à esquerda
    └── Label  TextLabel GothamBlack 20
```

Estados (TweenService, `Quad Out`):

| Estado | Face | Escala (`UIScale`) | Duração |
|---|---|---|---|
| Normal | posição 0 | 1.00 | — |
| Hover (PC) | brilho +10% (gradiente mais claro) | 1.06 | 0,12 s |
| Pressionado | desce 4 px (cobre a `Base`) | 0.96 | 0,06 s |
| Solto | volta ao normal | 1.00 com overshoot 1.03 (`Back Out`) | 0,18 s |
| Desativado | sem hover; um toque mostra um balão "Moedas insuficientes" | 1.00 | — |

### 3.3 Placa de madeira (títulos e nomes)

`Frame` 54 px de altura, gradiente madeira, `UICorner` md, 2 "pregos" (círculos 8 px `#C8A060`) nas pontas.
Título FredokaOne 30 px branco com contorno. Usado no cabeçalho das janelas e no nome do NPC.

### 3.4 Barra "recipiente" (vida, XP, energia, Fúria)

```
Bar (Frame 0.32 × 26 px)
├── Track   Frame bg.inset, UICorner pill, UIStroke 3 px edge.dark
├── Fill    Frame UICorner pill, Size = (fração, 1)
│   ├── UIGradient  Color: claro → médio → escuro (3 paradas), Rotation 0
│   ├── Flow        Frame sobreposto, branco, UIGradient Transparency 1 → 0.6 → 1 (faixa de luz)
│   │               animar Flow.UIGradient.Offset de (-1, 0) a (1, 0) em 1,6 s em loop
│   └── Bubbles     3 a 5 Frames 4 px brancos (transp 0.5) subindo devagar — só na seiva/XP
├── Glass   Frame metade de cima, branco transp 0.85, UICorner pill   ← vidro do recipiente
└── Value   TextLabel FredokaOne 16 "125 / 150"
```

- Ao **perder** valor: a parte perdida fica num `Frame` branco por 0,25 s e depois encolhe ("dano fantasma").
- Ao **ganhar**: o `Fill` cresce com `Quad Out` 0,3 s e a borda pisca na cor da barra.

### 3.5 Slot de item/pet

90 × 90 px (PC) ou 104 × 104 px (celular):
- **Fundo** com o gradiente da raridade, `UICorner` md e `UIStroke` 3 px com a borda da raridade.
- **Retrato** num `ViewportFrame` com o modelo do pet (o jogo já usa isso em `Fx.viewport`), `Ambient` `#AAB4D2` e `LightColor` branco.
- **Distintivos:** a sigla da raridade (canto superior esquerdo), a mutação (canto superior direito, ícone colorido) e o nível ("Nv 23", embaixo).
- **Equipado:** marca ✓ verde no canto e borda de 4 px `confirm`.
- **Travado:** cadeado no canto e o retrato a 40% de opacidade (`ImageTransparency` / `GroupTransparency`).
- **Selecionado:** o `Glow` do slot acende (6 px de brilho na cor da raridade) e o slot fica em escala 1.05.

### 3.6 Abas, tooltip, distintivo de notificação

- **Abas:** fileira de botões de madeira; a ativa é mais alta (+6 px), mais clara e tem um friso do acento em baixo.
- **Tooltip:** `RuneFrame` pequeno (máx. 280 px), aparece após 0,35 s de hover, segue o mouse com deslocamento (16, 16) e não tem no celular (lá vira "segurar").
- **Distintivo** (missão pronta, pet novo): círculo vermelho 20 px com número branco, pulando (escala 1 → 1.15 → 1, a cada 1,2 s).

---

## 4. HUD principal

### 4.1 Layout (PC 16:9 e celular)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ [Mundo 1: Verdant Haven ▾]   [● 1,25 M] [◆ 3.420] [⬢ 87] [♦ 120*]   [⚙][🔔]  │ ← barra superior
│                                                                              │
│ ⬡ Pets                                                    ┌──────────────┐  │
│ ⬡ Inventário                                              │ Missões (3)  │  │ ← rastreador
│ ⬡ Loja                     (mundo 3D livre)               │ ▸ Vença 10…  │  │
│ ⬡ Missões                                                 └──────────────┘  │
│ ⬡ Mundos                                                                     │
│ ⬡ Config.                                                                    │
│                                                                              │
│ ┌ Nv 23 ─────────────┐                     [equipe: 4 cartões + habilidades] │ ← CombatHUD atual
│ │ ❤ ███████░░ 125/150│                                                       │
│ │ ✦ ████░░░░░ XP 45% │                                                       │
│ └────────────────────┘                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
* Gemas [novo]
```

No celular: os botões laterais viram uma coluna de 5 ícones de 56 px na **esquerda**, longe do joystick. A barra
superior encolhe para ícone + número (sem rótulos). O rastreador de missões fica recolhido num botão.

### 4.2 Barra superior (moedas e mundo atual)

**Indicador do mundo** (à esquerda):
- Placa de madeira em pílula, 260 × 48 px.
- Brasão do mundo num losango de 40 px à esquerda (glifo do mundo + acento).
- Texto "Mundo 1" (GothamBold 13, `muted`) em cima de "Verdant Haven" (FredokaOne 22).
- Clicar abre o **Menu de Mundos** (seção 7).
- Ao trocar de mundo, a placa gira 360° no eixo Y (simulado com a escala X 1 → 0 → 1) e muda o acento.

**Contadores de moeda:** um componente por moeda, 170 × 44 px:
```
Counter
├── Pill     Frame bg.panel transp 0.1, UICorner pill, UIStroke 3 px edge.dark
├── Coin     Frame círculo 44 px sobreposto à esquerda (-8 px), gradiente da cor da moeda,
│            UIStroke 2 px escuro, glifo branco ● ◆ ✦ ⬢ ♦ (ou a imagem enviada pelo autor)
├── Amount   TextLabel FredokaOne 22, alinhado à direita, contorno 2 px
└── Plus     botão verde 28 px "+" na ponta (abre a Loja na aba da moeda)
```
- **Ganho:** o número sobe contando (Tween num `NumberValue`, 0,5 s), a moeda dá um "pop" (escala 1.25 → 1) e um "+250" flutua para cima e some.
- **Ganho grande** (mais de 10% do saldo): 6 a 10 moedinhas voam da posição do ganho na tela até o contador (ver [8.4](#84-efeitos-de-ganho)).

### 4.3 Botões laterais (menu principal)

- **Forma:** hexágono rúnico de 72 px, montado com um `Frame` quadrado girado 30° dentro de outro girado −30° (ou a imagem de hexágono enviada pelo autor), em pedra rúnica com friso do acento.
- **Ícone:** glifo de 34 px no centro, com sombra.

| Botão | Glifo provisório | Atalho |
|---|---|---|
| Pets | 🐾 | P |
| Inventário | 🎒 | I |
| Loja | 🛒 | L |
| Missões | 📜 | M |
| Mundos | 🌍 | T |
| Configurações | ⚙ | — |

- **Rótulo:** aparece à direita no hover (placa de madeira que desliza de 0 a 110 px de largura em 0,15 s).
- **Hover:** escala 1.12, giro de +6° e o brilho do acento acende (`UIStroke` 6 px, transparência 0.8 → 0.4).
- **Notificação:** distintivo vermelho com o número de missões prontas ou pets novos.
- **Ativo** (janela aberta): o hexágono fica com o friso em ouro e não responde a hover.

### 4.4 Barras de status do jogador

Painel no canto inferior esquerdo, 340 × 110 px, em pedra rúnica:
- **Retrato** do avatar num círculo de 64 px (`Players:GetUserThumbnailAsync`, tipo `HeadShot`), com moldura de madeira e a placa de nível "Nv 23" embaixo.
- **Vida** (`status.hp`): barra "recipiente" (3.4) com efeito de seiva verde fluindo. Abaixo de 25%, a barra pulsa em vermelho (`cancel`) a cada 0,8 s.
- **XP** (`status.xp`): a mesma barra, mais fina (14 px). Ao encher, faz o efeito de **subir de nível** (8.5).
- **Energia** (quando houver habilidade ativa): barra azul-celeste de 10 px.

---

## 5. Diálogo com NPCs (missões)

Hoje os NPCs falam por toasts, uma frase por interação (`RegionService.talk`). O painel abaixo substitui isso.

### 5.1 Layout

```
              ┌──────────────────────────────────────────────────────────┐
  ┌────────┐  │ ▓▓ OAKENHEART — Guardião do Bosque ▓▓            (placa) │
  │ retrato│  │                                                          │
  │  3D do │  │  "As raízes da Árvore-Santuário estão inquietas. Pode    │
  │  NPC   │  │   derrotar 10 Thornlings perto do lago?"  ▌             │
  └────────┘  │                                                          │
              │  Recompensa: ● 500   ◆ 20   Tomo de Habilidade ×1        │
              │                     [ Recusar ]   [ Aceitar Missão ]     │
              └──────────────────────────────────────────────────────────┘
```

- **Posição:** parte inferior central, 900 × 220 px no PC; no celular, largura total menos 24 px e altura de 40% da tela.
- **Retrato:** `ViewportFrame` 180 × 180 px saindo **para fora** da moldura à esquerda (deslocado −40 px em Y), com o modelo 3D do NPC: um clone do NPC do mapa, câmera fixa no rosto e uma rotação leve de ±8° em loop (TweenService no `CFrame` da câmera).
- **Placa do nome:** madeira polida com o nome em FredokaOne 26 e o título em GothamBold 15. A borda tem o acento do NPC (5.3).
- **Texto:** PatrickHand 22, cor pergaminho `#F4ECD8`, sobre `bg.inset`. Efeito de máquina de escrever com `TextLabel.MaxVisibleGraphemes` subindo 40 por segundo; clicar no painel completa o texto de uma vez.
- **Recompensas:** fileira de mini-contadores (ícone + número).
- **Botões:** Recusar (Cancelar) e Aceitar Missão (Confirmar), 200 × 56 px. Atalhos: `E` aceita, `Esc` fecha. No controle, `A` e `B`.
- **Várias falas:** o botão "Continuar ▸" substitui os dois botões até a última fala.

### 5.2 Fluxo

1. O `ProximityPrompt` do NPC dispara e o painel sobe (8.1).
2. A câmera faz um zoom leve no NPC (`FieldOfView` 70 → 60 em 0,4 s) e o `BlurEffect` vai a 6.
3. **Aceitar:** o painel faz um "pop" verde, a missão entra no rastreador (o item novo pisca 3 vezes) e o painel desce.
4. **Recusar ou sair de perto** (mais de 14 studs): o painel desce sem animação de recompensa.
5. **Missão concluída:** ao voltar ao NPC, a fala é de entrega e o botão vira "Receber recompensa" (Dourado), com chuva de moedas (8.4).

### 5.3 NPCs (acento e retrato)

| NPC | Status | Mundo | Acento da placa | Personalidade do texto |
|---|---|---|---|---|
| **Oakenheart** | [novo] | Verdant Haven (perto da Árvore-Santuário) | `#7CE65A` + casca `#5A3820` | calmo, ancestral |
| **Petalweave** | [novo] | Verdant Haven (clareira das flores) | `#FF8CC8` | alegre, tecelã de pétalas |
| **Stonefist** | [novo] | Verdant Haven (ruínas/rochas) | `#A89C8C` + runa verde | bruto, direto |
| Lyra, Orin, Vael | existem | Crystal Hollow | `#78DCFF` / `#4A6AB0` / `#B98CFF` | (falas atuais) |
| Capitã Aria, Arquiteta Seren | existem | Skybound Kingdom | `#5A8CE6` / `#E6DCC8` | (falas atuais) |

---

## 6. Menus de tela cheia

Regras comuns:
- **Abertura:** `scrim` em `0.45`, `BlurEffect.Size` 0 → 14 (0,25 s) e a janela entra em escala 0.85 → 1 com `Back Out` (8.1).
- **Tamanho:** 80% × 80% da tela, com `UIAspectRatioConstraint` 1.6 e no máximo 1280 × 800 px. No celular, 96% × 92%.
- **Cabeçalho:** placa de madeira com o título e o botão **X** (Cancelar, 48 px, canto superior direito, sai 12 px para fora da moldura).
- **Uma janela de cada vez:** abrir outra troca o conteúdo da atual (o `Panels.open` já usa um único modal).

### 6.1 Inventário e equipamento de pets

```
┌ PETS ──────────────────────────────────────────────────────────── [X] ┐
│ [Todos][Equipe][Comum…Celestial ▾][Mundo ▾]  🔍 buscar   48/200 pets │
├───────────────────────────────────────────┬──────────────────────────┤
│ ┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐                  │  [ retrato 3D girando ]  │
│ │✓ ││  ││  ││  ││  ││  │  grade de slots │  Bloomfox  ★ Épico        │
│ └──┘└──┘└──┘└──┘└──┘└──┘  (UIGridLayout) │  Mutação: Golden          │
│ ┌──┐┌──┐┌──┐ …                            │  Nv 23/40 ███████░ XP     │
│                                           │  Ataque 182  Defesa 64    │
│                                           │  Multiplicador ×1,45      │
│                                           │  ✦ Assinatura: Dança das  │
│                                           │    Pétalas (Fúria 6)      │
│                                           │  [Equipar] [Evoluir]      │
├───────────────────────────────────────────┴──────────────────────────┤
│ [Equipar Melhor]   [Excluir Auto ⚙]   [Evoluir/Fundir]   Equipe 4/4  │
└──────────────────────────────────────────────────────────────────────┘
```

- **Grade:** `ScrollingFrame` com `UIGridLayout` (`CellSize` 90 × 90, `CellPadding` 8). Ordem: equipados primeiro, depois raridade (maior primeiro) e poder.
- **Virtualização:** com mais de 120 pets, crie só os slots visíveis e reaproveite-os ao rolar. Os retratos 3D só existem para os slots visíveis.
- **Painel de detalhes** (35% da largura, à direita):
  - Retrato grande num `ViewportFrame` girando 20°/s.
  - Nome e raridade (sigla e cor).
  - Mutação e nível com barra de XP.
  - **Estatísticas:** Ataque, Defesa, Vida, Velocidade e Multiplicador do mundo (`statMult`), com setas ▲▼ comparando com o pet equipado mais fraco.
  - **Ataques próprios:** a habilidade de classe e o **ataque Assinatura** (nome, descrição, Fúria), que hoje já aparecem no painel do pet.
- **Equipar Melhor:** botão Confirmar. Escolhe os 4 de maior poder; os slots que mudam dão um "pop" e uma linha de luz liga o slot à equipe.
- **Excluir Auto:** abre uma sub-janela com caixas de seleção por raridade (Comum a Raro) e a regra "manter mutados". Antes de apagar, mostra "Isto vai excluir N pets" com botão vermelho e trava de 1 segundo segurando (`HoldDuration` simulado). **[novo]** A exclusão automática não existe hoje.
- **Evoluir/Fundir:** abre o painel de evolução com o custo atual (Essência, Pó de Evolução, Núcleo de Ascensão, como no jogo hoje). A fusão de cópias é **[novo]**.
- **Atalhos:** clique seleciona, clique duplo equipa ou desequipa, botão direito abre um menu rápido (Equipar, Travar, Evoluir).

### 6.2 Loja e ovos

**Estação de ovo** (abre ao interagir com a estação; hoje é o painel "Egg"):

```
┌ OVO DO BOSQUE ─────────────────────────────────────────────── [X] ┐
│        [ ovo 3D girando, com brilho ]        Preço: ● 100           │
│ ┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐                              │
│ │pet ││pet ││pet ││pet ││pet ││ ?? │  ← chances reais do servidor  │
│ │58% ││28% ││10% ││3,4%││0,55││0,05│     (cor da raridade no slot) │
│ └────┘└────┘└────┘└────┘└────┘└────┘                              │
│ Sorte ativa: +25% Lendário (máx. 15%)                               │
│ [ Chocar 1 ]  [ Chocar 3 ]  [ Auto ▶ ]                              │
└─────────────────────────────────────────────────────────────────────┘
```

- **Chances:** vêm do servidor, que já calcula as chances com a sorte. Pets ainda não descobertos aparecem como silhueta preta com "?".
- **Chocar 3** fica Dourado; **Auto** é **[novo]** (repete até o jogador parar, respeitando o limite do servidor).
- **Animação de chocar** (o `Fx.hatch` já existe; o roteiro abaixo é o alvo):
  1. Tela escurece e o ovo desce ao centro (0,3 s).
  2. Três balanços cada vez mais fortes (0,25 s cada), com rachaduras (linhas brancas) aparecendo.
  3. Clarão branco que cobre a tela (0,12 s) e o pet aparece em escala 0 → 1.15 → 1 (`Back Out`).
  4. A raridade surge numa faixa: Comum a Raro, simples; Épico em diante, raios girando atrás e brilho; Lendário em diante, a câmera treme, chovem partículas e há anúncio no chat. Secret e Celestial têm a animação especial que já existe.
  5. Botões: "Equipar", "Ok". No modo Auto, a revelação dura 0,6 s e não tem botões.

**Loja** (abas de madeira):

| Aba | Conteúdo | Observação |
|---|---|---|
| **Destaques** | oferta do dia, pacote inicial | cartão grande dourado com timer |
| **Gamepasses** | Sorte ×2, Chocar 3, Velocidade, Slots extras | `MarketplaceService:PromptGamePassPurchase`; os IDs vêm do Creator Dashboard |
| **Boosts** | poções de sorte, XP e moedas (temporárias) | a sorte respeita os tetos do `Config/Luck` |
| **Moedas / Gemas** | pacotes por Robux | Developer Products (`PromptProductPurchase`) e processamento no servidor (`ProcessReceipt`) |

- **Cartão de produto:** 240 × 300 px em pedra rúnica, com ícone grande, nome, descrição curta (2 linhas) e preço em botão Dourado (Robux) ou Confirmar (moedas). Já comprado: faixa "ATIVO ✓" verde atravessada.
- **Honestidade:** o preço em Robux mostrado vem de `MarketplaceService:GetProductInfo`, nunca escrito à mão.

---

## 7. Seleção e teleporte de mundos

### 7.1 Layout

```
┌ MUNDOS ──────────────────────────────────────────────────────────────── [X] ┐
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ │
│  │ ░ arte ░░  │ │ ░ arte ░░  │ │ ▓▓▓🔒▓▓▓▓  │ │ ▓▓▓🔒▓▓▓▓  │ │ ▓▓▓🔒▓▓▓▓  │ │
│  │ MUNDO 1    │ │ MUNDO 2    │ │ MUNDO 3    │ │ MUNDO 4    │ │ MUNDO 5    │ │
│  │ Verdant    │ │ Crystal    │ │ Skybound   │ │ Whispering │ │ Astral     │ │
│  │ Haven      │ │ Hollow     │ │ Kingdom    │ │ Wilds      │ │ Sanctuary  │ │
│  │ ● Você está│ │[Teleportar]│ │ ● 15.000   │ │ ● 60.000   │ │ ● 250.000  │ │
│  │   aqui     │ │            │ │ [Desbloq.] │ │ (bloqueado)│ │ (bloqueado)│ │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘ └────────────┘ │
│         ─────●──────────●──────────○──────────○──────────○─────            │ ← trilha
└──────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Cartões

200 × 320 px cada, `UIListLayout` horizontal. No celular, um `ScrollingFrame` horizontal com encaixe (snap) no cartão do meio.
- **Arte do mundo:** um `ViewportFrame` com uma maquete simples do marco do mundo:

  | Mundo | Maquete |
  |---|---|
  | 1 | Árvore-Santuário |
  | 2 | Farol Ancestral |
  | 3 | templo dourado |
  | 4 | árvore escura |
  | 5 | estrela |

  Ou uma imagem enviada pelo autor. Fundo com o gradiente do acento do mundo.
- **Desbloqueado / atual:** borda do acento, faixa "Você está aqui" (pulsando) e o botão "Teleportar" (Confirmar) nos outros mundos já abertos.
- **Bloqueado** (os custos são os de `Config/Worlds.luau`: 2.500, 15.000, 60.000 e 250.000 Moedas):
  - A arte fica em preto e branco (`ImageColor3` / `ViewportFrame.ImageColor3` = `#606070`) com 35% de escurecimento.
  - **Correntes:** duas faixas diagonais em X de elos (`Frame` 10 px em sequência, cinza-metal `#8A8CA0`, `UIStroke` escuro) sobre o cartão.
  - **Cadeado mágico** de 64 px no centro, com runa do acento brilhando e pulsando (`UIStroke` transparência 0.4 ↔ 0.8, 1,4 s).
  - **Requisito:** "● 15.000 Moedas" em destaque, com uma barra de progresso do saldo atual até o custo.
  - **Botão:** "Desbloquear" Dourado se o jogador tiver o saldo; senão, Desativado com "Faltam ● 3.200".
- **Ao desbloquear:** as correntes estalam (os elos voam para fora com rotação aleatória, 0,5 s), o cadeado abre e some, a cor volta (tween de `ImageColor3` em 0,6 s), a carta dá um "pop" e aparecem fogos (8.4). Depois o botão vira "Teleportar".
- **Trilha embaixo:** círculos ligados por linha; os preenchidos são os mundos abertos.

### 7.3 Teleporte

Os botões usam os pedidos que já existem no servidor (`State.request("Teleport", …)` e `State.request("UnlockWorld", …)`, tratados no `RequestRouter`). Na tela:
1. Fade para a cor do mundo de destino (0,35 s).
2. Nome do mundo grande no centro (FredokaOne 64), com subtítulo.
3. Fade de volta. O `RegionClient` já mostra o banner da região ao chegar.

---

## 8. Animações e feedback visual

### 8.1 Tabela de movimento

| Ação | Propriedade | De → Para | Duração | Easing |
|---|---|---|---|---|
| Abrir janela | `UIScale.Scale`, `CanvasGroup.GroupTransparency` | 0.85 → 1, 1 → 0 | 0,28 s | `Back`, `Out` |
| Fechar janela | idem | 1 → 0.9, 0 → 1 | 0,16 s | `Quad`, `In` |
| Scrim / Blur | `BackgroundTransparency`, `BlurEffect.Size` | 1 → 0.45, 0 → 14 | 0,25 s | `Quad`, `Out` |
| Hover de botão | `UIScale.Scale` | 1 → 1.06 | 0,12 s | `Quad`, `Out` |
| Pressionar | `Face.Position` Y, `UIScale` | +4 px, 0.96 | 0,06 s | `Linear` |
| Soltar | idem | volta, 1.03 → 1 | 0,18 s | `Back`, `Out` |
| Toast | `Position` Y + transparência | −60 px → 0 | 0,3 s | `Back`, `Out` |
| Contador de moedas | `NumberValue.Value` | antigo → novo | 0,5 s | `Quad`, `Out` |
| Distintivo | `UIScale` | 1 → 1.15 → 1 | 0,4 s, a cada 1,2 s | `Sine`, `InOut` |

Implementação: um único utilitário `UIKit.tween(inst, time, goal, style, dir)` (o `UIKit.pop` já existe) e um
`UIKit.press(button)` que liga os estados de 3.2 a qualquer botão.

### 8.2 Partículas de UI (cliques)

O Roblox não tem `ParticleEmitter` em 2D. As partículas da interface são `Frame`s pequenos animados:
- **Ao clicar:** 6 a 8 losangos (`Frame` 6 px girado 45°, cor do botão clareada) saem do ponto do clique em direções aleatórias, a 40 a 80 px, encolhendo e sumindo em 0,35 s.
- **Pool:** 40 losangos reutilizáveis num `Frame` de topo (`ZIndex` alto), para não criar e destruir objetos a cada clique.
- **Com "Qualidade de efeitos: Baixa"** (a configuração já existe), use 3 partículas, sem brilho.

### 8.3 Brilho de pet ao subir de nível

No cartão da equipe (CombatHUD) e no slot do inventário:
1. Um anel branco expande do retrato (escala 1 → 1.6, transparência 0.2 → 1, 0,45 s).
2. O texto "Nv 24!" sobe em FredokaOne dourado, com "pop".
3. O retrato fica com o brilho do acento por 1,5 s.
4. No mundo 3D, ao mesmo tempo, o `Fx` solta faíscas douradas no pet.

### 8.4 Efeitos de ganho

| Evento | Efeito |
|---|---|
| Moedas (normal) | "+N" flutuando sobre o contador |
| Moedas (grande) | 6 a 10 moedinhas voam pela tela até o contador em curva (Bezier simples), uma a uma, cada uma com um "tic" e um "pop" no contador |
| Missão concluída | faixa dourada no topo, "MISSÃO CONCLUÍDA" com brilho varrendo da esquerda à direita (`UIGradient.Offset`) |
| Item **Lendário** | tela escurece 30%; raios girando atrás do item (8 `Frame` finos em leque, rotação 30°/s); estrelas piscando; texto da raridade com gradiente animado |
| Item **Mítico** | como o Lendário, mais um tremor de câmera curto e borda da tela pulsando em rosa |
| **Secret / Celestial** | mantém a revelação especial que já existe (`Fx.hatch`) e soma o anúncio global |

### 8.5 Subir de nível do jogador

A barra de XP se enche até o fim, brilha em branco e esvazia. "SUBIU DE NÍVEL!" aparece no centro (FredokaOne 56,
dourado, contorno escuro) com escala 0.5 → 1.1 → 1. O número do nível na placa troca com um giro. Total 1,6 s,
sem bloquear o jogo.

---

## 9. Celular, acessibilidade e desempenho

- **Escala:** um `UIScale` no topo de cada `ScreenGui`. O jogo já tem escala responsiva no CombatHUD. Base 1080p: `Scale = clamp(min(largura/1920, altura/1080) × 1.0, 0.7, 1.25)`; no celular, multiplique por 1.15.
- **Áreas seguras:** `ScreenGui.ScreenInsets = DeviceSafeInsets` (fora do entalhe e da barra do sistema) e `IgnoreGuiInset` só onde houver fundo de tela cheia.
- **Toque:** mínimo de 56 px. Nada importante nos 30% inferiores da esquerda (joystick) nem da direita (pulo).
- **Contraste:** texto claro sobre `bg.panel` passa de 7:1. Nunca coloque texto amarelo sobre o verde da confirmação sem contorno.
- **Movimento reduzido:** um interruptor nas Configurações. Ele desliga tremores, rotações contínuas e partículas, e deixa só fades.
- **Desempenho:**
  - **Retratos 3D:** no máximo 24 `ViewportFrame` visíveis ao mesmo tempo, com virtualização da grade (6.1).
  - **Animações contínuas:** gradientes girando e fluxos das barras rodam a 30 quadros por segundo (um laço só, em `RenderStepped`, que pula quadros ímpares) e param quando a janela está fechada.
  - **Desfoque:** o `BlurEffect` só fica ligado com menus de tela cheia abertos.

---

## 10. Plano de implementação no código

| Etapa | Arquivo | O que fazer |
|---|---|---|
| 1 | `client/Controllers/UIKit.luau` | Acrescentar os tokens (2.7) e os construtores `runeFrame`, `gameButton` (3.2), `vesselBar` (3.4), `slot` (3.5), `counter` (4.2), `tween`, `press` e `uiParticles` (8.2) |
| 2 | `client/Controllers/HUD.luau` | Trocar a barra superior pelos contadores (4.2), pôr os hexágonos laterais (4.3) e o painel de status (4.4) |
| 3 | `client/Controllers/Panels.luau` | Passar Pets, Itens, Sorte, Bestiário, Missões, Mapa e Configurações para o `runeFrame`. Pets ganha a grade nova (6.1) e Mapa vira o Menu de Mundos (7) |
| 4 | **[novo]** `client/Controllers/Dialog.luau` | Painel de diálogo (5). No servidor, `RegionService.talk` passa a mandar a fala inteira e as missões do NPC, em vez de um toast |
| 5 | `client/Controllers/Fx.luau` | Roteiro de chocar (6.2), efeitos de ganho (8.4) e subir de nível (8.5) |
| 6 | **[novo]** Loja | Aba de Gamepasses e Produtos com `MarketplaceService`, mais `ProcessReceipt` no servidor. Os IDs são criados pelo autor no Creator Dashboard |
| 7 | Testes | No simulador: abrir cada janela, os estados dos botões, o fluxo de diálogo e o desbloqueio de mundo sem erro (como os cenários atuais dos painéis) |

**Ordem sugerida:** 1 → 2 → 3 (Pets e Mundos primeiro) → 5 → 4 → 6. Cada etapa deixa o jogo jogável.

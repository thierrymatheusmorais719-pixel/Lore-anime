# BLEACH — SOUL REBIRTH (Roblox)

RPG de ação inspirado em Bleach, escrito em **Luau** e organizado para **Rojo**. Todo o mapa, os rigs dos
NPCs/inimigos, as armas, os efeitos e as animações são gerados por código. **Não há assets de terceiros
nem IDs inventados**: as animações são procedurais (podem ser trocadas por animações publicadas), e os sons
usam arquivos embutidos no próprio cliente Roblox (`rbxasset://sounds/...`).

> Status: código completo, com verificação de tipos limpa (luau-lsp + definições Roblox), 31 testes de lógica
> passando e `rojo build` gerando o `.rbxl`. **Ainda não foi executado dentro do Roblox Studio** (o ambiente
> onde foi escrito não tem Studio). Siga o roteiro de teste abaixo e reporte o que aparecer na saída.

---

## 1. Como abrir no Roblox Studio

### Opção A — arquivo de lugar (mais simples)
1. Instale o [Rokit](https://github.com/rojo-rbx/rokit) e, nesta pasta, rode `rokit install`
   (ou instale o [Rojo 7.4](https://github.com/rojo-rbx/rojo/releases) manualmente).
2. `rojo build default.project.json -o BleachSoulRebirth.rbxl`
3. Abra `BleachSoulRebirth.rbxl` no Roblox Studio.

### Opção B — sincronização ao vivo
1. `rojo serve` nesta pasta.
2. No Studio, instale o plugin do Rojo e clique em **Connect**.

### Configurações obrigatórias no Studio (Game Settings)
| Onde | O quê | Por quê |
|---|---|---|
| **Avatar → Avatar Type** | **R15** | As animações procedurais usam as juntas R15. Em R6 o combate funciona, mas sem animações. |
| **Security → Enable Studio Access to API Services** | Ligado (para testar o salvamento) | Sem isso o jogo roda em "modo memória" e avisa no Output que nada será salvo. |

Publique o lugar antes de testar o DataStore (Studio exige um lugar publicado).

---

## 2. Roteiro de teste (Play / F5)

1. **Seleção de facção** aparece sobre a praça de Karakura → escolha uma.
2. Você nasce na praça. A missão **"Primeiros Passos"** aparece no canto direito → fale com seu mentor
   (NPC com seu nome de facção, tecla **E**).
3. **Combate** contra os Hollows a leste/oeste da praça:
   - Clique repetido = combo de 5 golpes (o 5º arremessa). **R** lança o inimigo para cima; pule e ataque no ar
     para o combo aéreo (o último golpe crava o inimigo no chão).
   - **F** no instante do golpe inimigo = **PARRY** (clarão + "PARRY!"); o próximo clique vira **contra-ataque**.
   - **E** = ataque pesado (quebra a guarda). Em um inimigo **atordoado com pouca vida**, vira **EXECUÇÃO**
     cinematográfica.
   - **Q** = dash com invencibilidade e imagens residuais; **Espaço no ar** = pulo duplo.
   - **Z / X / C** = habilidades da facção; **T** segura para carregar Reiatsu.
4. **Transformação**: abra o **Menu (M) → Dev** (só no Studio) → "Nível 15" e "Desbloquear formas" → aperte
   **G** (Shikai/Resurrección/...) e **G** de novo (Bankai/...). A cena pode ser pulada com qualquer tecla.
   Shinigami: **H** = Máscara Hollow. No Tier 2 aparece a ultimate em **V**.
5. **Chefe**: Kurokage fica no pátio da escola ao norte da praça (2 fases; na segunda invoca Hollows).
6. **Portais**: laranja = Campo de Treino (bonecos, alvos de dano, arena PvP, chefes das provações);
   Senkaimon = Soul Society (nível 4); Garganta = Hueco Mundo (nível 12).
7. **Menu (M)**: atributos, árvore de habilidades, inventário (equipar/usar/vender), missões (história +
   diárias), poderes (invocação com pity ou compra direta), viagem rápida e opções (qualidade de efeitos,
   tremor de câmera, cenas). Loja e forja: fale com o **Velho Sōma**.
8. **Salvamento**: saia e entre de novo — nível, itens, missões e configurações devem permanecer.

Controles completos (teclado / controle): Menu → Opções. No **celular**, botões na tela + botão "☰ Menu".

---

## 3. Arquitetura

```
src/
├─ shared/            → ReplicatedStorage.Shared
│  ├─ Config/         dados: Combat, Abilities (~80), Factions, Powers (13), Enemies, Quests, NPCs,
│  │                  Items, Loot, Progression, SkillTrees, Zones, Elements, Animations, Sounds
│  ├─ Logic/          regras puras e testáveis: CombatRules, Stats, ProgressionLogic, InventoryLogic,
│  │                  LootLogic, GachaLogic, QuestLogic, DataSchema, Loadout
│  ├─ Anim/Poses      biblioteca de animações procedurais R15
│  ├─ Util/           Signal, Trove, Log, RateLimiter, Pool, Spring, TableUtil
│  ├─ Net             definição dos RemoteEvents/RemoteFunction
│  └─ Physics         impulsos (LinearVelocity), flutuar no ar
├─ server/            → ServerScriptService.Server
│  ├─ Main.server     inicialização (Init em ordem → Start)
│  ├─ Services/       Data, Combat, Ability, Transformation, Character, Progression, Inventory,
│  │                  Quest (missões + diálogos), Enemy, World, UI (roteador de pedidos), Dev (só Studio)
│  ├─ Enemy/EnemyBrain IA: perseguir, combos, esquiva/bloqueio/parry reativos, habilidades, fases
│  ├─ Builders/       RigBuilder (R15 procedural), WeaponBuilder, OutfitBuilder (tecidos articulados)
│  └─ World/          Build (primitivas) + Regions (Karakura, Treino, Soul Society, Hueco Mundo)
└─ client/            → StarterPlayerScripts.Client
   ├─ Main.client
   ├─ Controllers/    Data, Input, Combat (previsão), Anim, Fx (eventos→efeitos), VFX, Camera, Sound,
   │                  HUD, Menu, Dialogue, FactionSelect, Zone (iluminação)
   └─ UI/Kit          tema e componentes
```

### Segurança (servidor autoritativo)
- O cliente envia **apenas intenções** (`CombatInput`: "Light", "Dash", "Ability" + direção/mira).
  Dano, alcance, hitboxes, cooldowns, custo de Reiatsu, stun, parry e knockback são decididos no servidor.
- Direção e ponto de mira são validados (vetor unitário; ponto limitado ao alcance da habilidade).
- O servidor resolve qual habilidade está no espaço Z/X/C/V (o cliente não escolhe o ID).
- Rate limit por jogador em `CombatInput` e `Request`; opções de diálogo só valem se existirem no estado atual;
  loja/forja exigem estar perto do NPC; comandos Dev só funcionam com `RunService:IsStudio()`.
- Knockback em jogadores é enviado ao dono (que controla a física do próprio personagem); em NPCs é aplicado
  direto no servidor.

### Combate fluido
- **Previsão local**: o golpe anima no mesmo frame do clique; o servidor confirma e os outros jogadores veem.
- **Buffer de comandos** (0,28 s), cancelamento da recuperação por dash/bloqueio/habilidade.
- **Hit-stop**, tremor de câmera, FOV dinâmico, faíscas/clarões/ondas de choque no quadro de impacto.
- Os quadros de impacto das animações são gerados a partir de `Config/Combat` (`windup`), então animação e
  hitbox do servidor ficam sempre sincronizadas.

### Desempenho
- IA a ~8 Hz, escalonada entre frames, e inimigos dormem sem jogadores em 300 studs.
- Estado de combate a 10 Hz; atributos só replicam quando mudam.
- Emissores de partículas compartilhados, pool de números de dano, `Debris` para temporários.
- Animação procedural só em rigs a menos de 220 studs da câmera. Qualidade **Baixa** corta partículas e luzes.

---

## 4. Trocar por animações e sons próprios

**Animações**: em `src/shared/Config/Animations.luau`, preencha `assetId` com um ID **publicado por você ou
pelo grupo dono da experiência**:
```lua
Animations.List.Slash1.assetId = "rbxassetid://1234567890"
```
O `AnimController` passa a usar o `AnimationTrack` no lugar da versão procedural. Para casar com a hitbox,
o impacto da animação deve acontecer no `windup` do golpe em `Config/Combat.luau` (ou ajuste `speed`).

**Sons**: troque os `id` em `src/shared/Config/Sounds.luau` por `rbxassetid://...` próprios.

**Mapa**: cada região é uma função em `src/server/World/Regions.luau`. Substitua por modelos próprios
mantendo livres as áreas de spawns, portais e arenas (definidas em `Config/Zones.luau`).

---

## 5. Ferramentas e verificação

```bash
rokit install                                       # rojo, selene, stylua, luau-lsp
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src   # tipos
python3 tests/bundle.py && luau tests/.bundle.luau                                  # testes
rojo build default.project.json -o BleachSoulRebirth.rbxl
```
`globalTypes.d.luau` vem do repositório do luau-lsp (mesma versão da ferramenta). Os testes cobrem regras de
combate, atributos, progressão, árvore, inventário/forja, loot com pity, invocação com pity, missões, diárias,
migração de dados e **integridade das configs** (toda habilidade/animação/item/inimigo referenciado existe).

---

## 6. O que ainda precisa ser validado no Studio

- Sensação das poses procedurais (ângulos podem precisar de ajuste fino por golpe em `Anim/Poses.luau`).
- Equilíbrio de dano/vida/XP (tudo em `Config/`).
- Comportamento do knockback em terrenos irregulares e das execuções em grupo.
- Pathfinding: a IA usa `MoveTo` direto (as arenas são abertas); mapas fechados pedem `PathfindingService`.
- Sessão travada do DataStore ao trocar de servidor rapidamente (a trava expira em 10 min ou é assumida após ~16 s).

---

## 7. Skill de VFX/animação para o Claude Code

O projeto inclui a skill **roblox-vfx-animation** em `.claude/skills/vfxskill/`
(origem: https://github.com/adnvli/vfxskill, commit `f17b9a6`, licença MIT). O Claude Code a carrega
automaticamente em trabalhos de efeitos e animações (`/skills` para conferir).

- **Requisitos para o fluxo completo:** um MCP do Roblox Studio com `execute_luau` e `screen_capture`
  (para construir e capturar efeitos quadro a quadro), Node.js 18+ e, opcionalmente, Blender
  (texturas/flipbooks e malhas de meia-lua/anel).
- **Variáveis de ambiente** (só para `scripts/upload.mjs`, que envia texturas/malhas/animações via Open Cloud):
  `ROBLOX_API_KEY` (ou `ROBLOX_OPEN_CLOUD_API_KEY`) e `ROBLOX_USER_ID` ou `ROBLOX_GROUP_ID` (dono do lugar).
  Uploads são permanentes e moderados.
- **Como se encaixa aqui:** os efeitos deste jogo ficam em `src/client/Controllers/VFXController.luau` e
  `SpectacleFx.luau` (gerados por código); as animações em `src/shared/Anim/Poses.luau` com IDs
  publicados opcionais em `src/shared/Config/Animations.luau`. A skill serve para produzir texturas,
  flipbooks e animações publicadas e então plugá-las nesses arquivos.

# Mythical Isles — Pet Evolution Simulator (Roblox)

Simulador de pets com exploração, **sorte**, **mutações raras**, raridades **SECRET** e **CELESTIAL**,
**combate em equipe**, **inimigos com IA**, **5 bosses com fases**, recompensas, missões, bestiário e
salvamento. Tudo em **Luau**, organizado para **Rojo**. Mapa, criaturas, bosses, efeitos e interface são
**gerados por código**: não há assets de terceiros nem IDs inventados (as únicas texturas usadas são as que
vêm dentro do próprio cliente Roblox: `rbxasset://textures/particles/sparkles_main.dds` e `smoke_main.dds`).

> **Status honesto:** o código está completo e foi verificado com o compilador e o analisador oficiais do
> Luau, contra o dump público da API do Roblox, com 57 testes de lógica, 633 verificações dos modelos 3D e
> **96 cenários executando o servidor e o cliente reais num simulador** (detalhes na seção 6).
> **Ele ainda não foi aberto no Roblox Studio** (o ambiente onde foi escrito não tem Studio), então visual,
> física, colisão, PathfindingService real, animações em tela e celular precisam ser conferidos aí. Use o
> roteiro da seção 7.

---

## 1. Como abrir no Roblox Studio

**Opção A — arquivo pronto:** abra `build/MythicalIsles.rbxl` no Studio.

**Opção B — gerar/sincronizar com Rojo:**
```bash
rokit install            # ou instale o Rojo 7.4 manualmente
rojo build default.project.json -o build/MythicalIsles.rbxl
# ou, para editar ao vivo:
rojo serve               # e no Studio: plugin Rojo → Connect
```

**Para testar o salvamento (DataStore):** publique o lugar e ative *Game Settings → Security → Enable Studio
Access to API Services*. Sem isso o jogo roda em **modo memória** e avisa na tela e no Output que nada será
salvo.

Ao dar Play no Studio, o servidor imprime `[Testes] Testes: 57 passaram…` (os testes de lógica rodam
automaticamente no Studio) e o menu **Opções** ganha a seção **Testes (somente no Studio)**, com comandos
para moedas, itens, mundos, nível máximo, evento de sorte, avançar fase do boss, tesouro e Estrela Errante.
Esses comandos são recusados em servidores publicados (`RunService:IsStudio()`).

## 2. Como jogar

| Ação | PC | Celular |
|---|---|---|
| Mirar / atacar inimigo | clique no inimigo | toque no inimigo |
| Ataque básico (cajado) | **F** | botão ⚔ |
| Habilidade do pet 1–4 | **1 2 3 4** | botões da barra da equipe |
| Próximo alvo | **Tab / Q** | — |
| Minerar recurso | clique no recurso | toque |
| Estações de ovo, portais, tesouros | **E** (ProximityPrompt) | toque no prompt |
| Mapa / fechar painel | **M** / **Esc** | ✕ |

Ciclo: o jogador nasce em **Verdant Haven** com 150 moedas → choca o primeiro ovo (o pet já entra na
equipe) → pets mineram recursos (moedas) e lutam → ovos melhores, evolução, habilidades → boss da arena →
portal para o próximo mundo (Crystal Hollow → Skybound Kingdom → Whispering Wilds → Astral Sanctuary).

## 3. Sistemas implementados (mapa para o pedido)

| # | Pedido | Onde | Resumo |
|---|---|---|---|
| 1 | **Sorte global** | `shared/Config/Luck.luau`, `shared/Logic/LuckLogic.luau`, `server/Services/LuckService.luau` | 6 categorias (pets raros, mutações, tesouros, drops, ovos especiais, eventos secretos). Fontes: eventos agendados por UTC (iguais em todos os servidores), 5 poções, buffs de missão, perks de pets, coleção, login diário e sinergia. Teto por **tipo de fonte** e por **categoria** (ex.: pets raros no máx. x3). O cliente nunca envia sorte: o servidor calcula tudo |
| 1 | Interface da sorte | `client/Controllers/Panels.luau` (Sorte), `HUD.luau` | multiplicador por categoria, fontes ativas com tempo restante, limites e histórico de descobertas |
| 2 | **SECRET / CELESTIAL** | `Config/Rarities.luau`, `Config/Eggs.luau` | 1 SECRET por mundo, 2 CELESTIAL. Teto por tentativa (SECRET 1%, CELESTIAL 0,2%) e influência reduzida da sorte no Celestial. Condições reais e visíveis (ex.: Celestara exige 15 espécies no bestiário). Animação especial, anúncio no servidor + global (MessagingService) com id único (sem duplicatas), histórico e bestiário |
| 2 | Probabilidades reais | `EggService.odds` + `HatchLogic.eggOdds` | o painel do ovo mostra a chance calculada pela **mesma função** e com o **mesmo multiplicador** usados no sorteio, além da chance base e do motivo das entradas bloqueadas |
| 3 | **Mutações** | `Config/Mutations.luau`, `Builders/MutationVisuals.luau` | Golden, Radiant, Prismatic, Ancient, Phantom, Astral: chance configurável (2% base, máx. 10%), regras por mundo, material/cor/partículas/peças extras (runas, estrelas, anel orbital), ciclo de cor Prismatic no cliente. Persistem no inventário, seguem na evolução e nos acessórios. Catalisadores de boss aplicam uma mutação definida |
| 4 | **Combate com pets** | `Config/Combat.luau`, `Logic/PetStats.luau`, `CombatService.luau` | vida, ataque, defesa, velocidade, alcance, energia, crítico; 5 funções (Tanque, Atacante, Suporte, Explorador, Especialista), testadas para que nenhuma domine em todos os atributos |
| 5 | **Modelos dos inimigos** | `Builders/EnemyModels.luau` | 14 espécies originais com construtor próprio, mais a invocação da Wilderbloom e a Estrela Errante (16 modelos). Silhuetas distintas (bulbo de espinhos, gigante de raízes, fera espinhosa, aracnídeo de cristal, golem, verme, orbe elétrico, felino de nuvem, cavaleiro alado, pantera de névoa, cervo oco, tartaruga-árvore, sentinela flutuante, guardião do portal) |
| 6 | **IA** | `Logic/EnemyBrain.luau`, `EnemyService.luau` | Idle, Patrulha, Investigação, Perseguição, Ataque, Recuperação, Retorno e Derrota. Detecção com linha de visão, histerese de alvo, coleira por distância e tempo, retorno invulnerável com cura, detecção de travamento. PathfindingService para inimigos terrestres e voo direto com desvio por raycast para os voadores. Alcance verificado no servidor |
| 7 | **Bosses** | `Config/Bosses.luau`, `Builders/BossModels.luau`, `BossService.luau` | Elderroot, Prism Titan, Tempest Wyrm (fase aérea), The Wilderbloom (invocações, zonas seguras), Void Sovereign (4 fases). Entrada, fases com transição invulnerável, aviso do próximo ataque, respawn, reset se a arena esvaziar, vida que escala com os jogadores |
| 8 | **Arenas** | `WorldBuilder.arena` | piso, borda luminosa (limite), 10 pilares com luz, decoração temática, portão de entrada. Só quem está **dentro** da arena causa dano e participa |
| 9 | **Habilidades** | `Config/Abilities.luau`, `CombatService.useAbility` | Investida, Projétil, Escudo (provoca), Cura, Onda de Choque, Quebrar Defesa, Vento Veloz, Faro do Tesouro (marca e revela), Laço de Raízes, Chuva Estelar. Recarga, custo, alcance, efeito no servidor, limite anti-spam, ranks 1–5 |
| 10 | **Drops** | `Config/Drops.luau`, `Logic/DropLogic.luau`, `RewardService.luau` | tabelas por inimigo/boss/tesouro; a sorte só afeta entradas marcadas e **sempre com teto**. Variantes de pet, ovos especiais, cosméticos, catalisadores, troféus. Cada jogador elegível rola com a própria sorte |
| 11 | **Progressão** | `PetStats`, `PetService` | XP de combate, níveis, 3 estágios de evolução (o pet antigo evoluído continua competitivo; há teste para isso), ranks de habilidade, 5 sinergias, conjunto de mundo (+12% de dano contra inimigos daquele mundo) |
| 12 | **Interface de combate** | `CombatHUD.luau`, `WorldClient.luau`, `Fx.luau` | barras de vida de inimigos e boss, nome e nível, estados (marcado, defesa reduzida, preso, voltando), aviso "⚠ ataque em Xs", equipe com recarga e energia, feed e histórico de drops, anúncios, escala responsiva e botões grandes no celular |
| 13 | **Integração** | todos | uma única conta de perfil (`DataSchema`) para inventário, equipe, bestiário, missões, sorte, histórico e encontros já recompensados |

**Base do simulador**: 5 ilhas (terreno + decoração), 10 ovos com moedas/essência, 5 ovos especiais,
34 espécies, recursos quebráveis, tesouros, portais, 16 missões de história, 3 diárias por dia (iguais em
todos os servidores), 9 marcos de coleção, login diário e DataStore com trava de sessão, autosave e
BindToClose.

## 4. Arquitetura

```
src/
├─ shared/  (ReplicatedStorage.Shared)
│  ├─ Config/    Rarities, Worlds, Pets, Eggs, Mutations, Luck, Combat, Abilities, Items, Drops,
│  │             Enemies, Bosses, Quests, Exploration  ← todo o balanceamento fica aqui
│  ├─ Logic/     regras PURAS e testáveis: LuckLogic, HatchLogic, DropLogic, PetStats, CombatRules,
│  │             AttackShapes, EnemyBrain, BossLogic, DataSchema, InventoryLogic, QuestLogic, CollectionLogic
│  ├─ Builders/  ModelKit, CreatureBuilder (pets), MutationVisuals, Accessories, EnemyModels, BossModels
│  ├─ Tests/     TestRunner + *.spec (rodam no Studio e no CLI)
│  ├─ Util/      Make, RateLimiter
│  └─ Net        Remotes: Request (RemoteFunction), Action e Push (RemoteEvents)
├─ server/  (ServerScriptService.Server)
│  ├─ Main.server.luau   inicialização
│  └─ Services/  DataService, LuckService, AnnounceService, RewardService, QuestService, WorldService
│                (+WorldBuilder), PetService, CombatService (+Entities, Telegraph), EnemyService,
│                BossService, ExplorationService, EggService, DevService, RequestRouter
└─ client/  (StarterPlayerScripts.Client)
   ├─ Main.client.luau
   └─ Controllers/  State, UIKit, HUD, CombatHUD, Panels, Fx, Animator, WorldClient, Input
tools/   verificações fora do Studio (seção 6)
```

**Segurança**: todo pedido passa pelo `RequestRouter`, que valida tipos e limita a frequência. O cliente
só pede ações ("chocar este ovo", "usar a habilidade do slot 2", "mirar neste modelo"). Preço, sorte,
sorteio, alcance (pelas posições do servidor), linha de visão, recarga, energia, dano e recompensas são
decididos no servidor. Inimigos, bosses e pets têm `SetNetworkOwner(nil)`.

**Indicadores justos**: `AttackShapes.build` gera as formas (círculo, anel, cone, linha, cruz e zonas
seguras). O servidor cria as peças do aviso a partir delas (`Telegraph.luau`) e testa o acerto com
**essas mesmas formas**. Se a fase muda durante o aviso, o ataque é cancelado junto com o aviso.

**Animação**: o cliente (`Animator.luau`) anima todas as criaturas pelo nome das juntas (Body, Neck, Leg*,
Arm*, Wing*, Tail*, Seg*, Jaw, Petal*, Root*, Orbit*), lendo atributos replicados (`Action`, `WindupEnd`,
`HitAt`, `Dead`, `Knocked`). Cobre parado, movimento, preparação, golpe, dano (com clarão) e derrota
(queda e desaparecimento), com nível de detalhe por distância.

## 5. Balanceamento

A vida dos inimigos foi calculada a partir do dano por segundo **esperado** de uma equipe típica em cada
mundo (raridade, estágio e nível médios), mirando cerca de 8 a 40 s por inimigo e cerca de 2 min de boss em
dupla. O dano contra **jogadores** é separado (`pdmg`), porque os jogadores não escalam como os pets. Todos os
números ficam em `shared/Config/*`. Ajuste-os depois de jogar no Studio: essa calibragem precisa de
partidas reais.

## 6. Testes: o que foi validado e como

Ferramentas usadas: CLI oficial do Luau (`luau`, `luau-analyze`, `luau-compile`) 0.650, Rojo 7.4.4 e o
dump público da API do Roblox (`API-Dump.json`, de MaximumADHD/Roblox-Client-Tracker).

| Verificação | Comando | Resultado |
|---|---|---|
| Sintaxe de todos os arquivos | `luau-compile --null` em cada `.luau` | ok |
| Variáveis indefinidas / código suspeito | `python3 tools/lint.py luau-analyze` | 0 avisos |
| Propriedades, Enums e métodos contra a API real do Roblox | `python3 tools/api_check.py API-Dump.json` | 0 problemas (o verificador acusa erros plantados de propósito) |
| Lógica pura | `python3 tools/run_tests.py luau` | **57 testes passando** |
| Modelos 3D (34 pets × 6 mutações × 5 acessórios, 16 inimigos, 5 bosses) | `python3 tools/run_tests.py luau --smoke` | **633 verificações, 0 falhas** |
| Servidor + cliente reais num simulador | `python3 tools/run_tests.py luau --sim` | **96 cenários passando** |
| Geração do lugar | `rojo build` | `build/MythicalIsles.rbxl` |

O **simulador** (`tools/roblox_mock.luau`, `tools/sim_runtime.luau`) executa o `Main.server` e o
`Main.client` **sem modificação**, com relógio virtual, agendador de `task`, jogadores, DataStore em
memória (que serializa como JSON e recusa tipos não salváveis), MessagingService em loopback, remotes
ligados de verdade e uma física mínima (`AlignPosition` e `Humanoid:MoveTo` movem os modelos; raycasts
acertam o chão das ilhas). Ele **não** simula colisão, renderização, rede real nem o PathfindingService:
no simulador o pathfinding sempre falha, então só a rota alternativa (movimento direto com detecção de
travamento) foi exercitada.

### Os 15 testes obrigatórios

| # | Teste | Situação |
|---|---|---|
| 1 | Encontrar e enfrentar um inimigo | ✅ simulador (servidor + HUD do cliente) |
| 2 | Inimigo detecta e executa os estados | ✅ simulador (Chase, Attack, Recover, Return, Idle/Patrol, Investigate) + testes da máquina de estados |
| 3 | Pets participam do combate | ✅ simulador (aproximação física e dano registrado por pet) |
| 4 | Alcance, recarga e regras de dano | ✅ simulador (ataque fora do alcance recusado, repetição na recarga ignorada, spam de habilidade bloqueado, slot inválido ignorado) + testes da fórmula |
| 5 | Boss muda de fase | ✅ simulador, **nos 5 bosses** (inclui a transição invulnerável e o aviso aos jogadores) |
| 6 | Indicadores = ataques executados | ✅ simulador (o teste de acerto recebe os mesmos objetos de forma usados no aviso) + testes geométricos de cada forma. ⚠ aparência no Studio não verificada |
| 7 | Derrota gera recompensas válidas | ✅ simulador (drops, moedas/essência, XP, bestiário e missão) |
| 8 | Probabilidades de drop respeitam a configuração | ✅ testes estatísticos (100 mil a 200 mil rolagens) + teto com sorte "infinita" |
| 9 | Sorte não pode ser falsificada | ✅ simulador (campos falsos de sorte no pedido, ação "SetLuck", poção que o jogador não possui: tudo ignorado ou recusado) |
| 10 | Mutações persistem | ✅ simulador (salva no DataStore → sai → volta → mutação, bestiário e modelo restaurados; a evolução mantém a mutação) |
| 11 | Bestiário registra inimigos e pets | ✅ simulador |
| 12 | Bosses sem recompensa duplicada | ✅ simulador (`encounterId` salvo no perfil + trava no servidor; segunda derrota forçada não paga de novo) |
| 13 | Vários jogadores sem compartilhar inventário | ✅ simulador (3 jogadores no mesmo boss: os 2 que lutaram recebem cada um no próprio perfil; o que só ficou parado na arena não recebe nada). ⚠ entre servidores só o loopback do MessagingService foi testado |
| 14 | Funciona no celular | ⚠ **não validado em dispositivo**. Há escala responsiva, botões de toque e toque no mundo para mirar, mas no simulador o cliente rodou só no modo PC |
| 15 | Efeitos limpos e desempenho aceitável | ✅ parcialmente: indicadores removidos após os ataques, inimigos mortos removidos, número de inimigos estável com respawn, nenhum erro em 564 s simulados. ⚠ **FPS e carga reais não foram medidos** |

### Erros encontrados e corrigidos durante os testes

- `UIKit.frame` repassava o campo `radius` para o Frame (erro na primeira tela) — corrigido.
- A Tempest Wyrm tinha só 13 studs de altura — aumentada 1,6× (agora 37×21×53).
- `MisleadingAndOr` na IA (o atacante nunca era limpo ao voltar à origem) — reescrito.
- Estação de ovo sem `PrimaryPart` (`GetPivot` indefinido na checagem de distância) — corrigido.
- Golpe corpo a corpo checava o atordoamento com um horário antigo — corrigido.
- Humanoid de rig próprio: definido `RigType = R15` para o `HipHeight` valer.
- Função global vazando no CombatService — virou local.
- `Marble` não é material de Terrain — cada ilha recebeu materiais de Terrain exclusivos.
- Jogador podia nascer "no céu" (antes do mapa ficar pronto) — o servidor agora cria o personagem
  só depois do mundo construído, coloca na praça, devolve à praça quem cai da ilha e faz o respawn.
  As ilhas continuam flutuando (é o tema), agora com um mar de nuvens abaixo.
- O arquivo gerado pelo Rojo não trazia o objeto **Terrain** no Workspace, e o construtor das ilhas
  usava `workspace.Terrain` logo ao carregar. Provável causa de "só aparece o céu". Agora o projeto
  inclui o Terrain, a ilha é feita com peças se o Terrain faltar, cada etapa do servidor roda
  protegida e qualquer erro aparece escrito na tela do jogo (além do Output), junto com uma tela
  de carregamento.
- **Primeiro teste no Studio (foto do usuário):** o jogo carregou, com ilha, HUD e personagem. O único erro foi
  `WorldService.init` escrevendo `Workspace.FallenPartsDestroyHeight`, que só plugins podem alterar.
  A propriedade foi para o `default.project.json`, e o `tools/api_check.py` agora acusa escrita em
  propriedades protegidas.
- Jogador novo começava com 0 moedas e não conseguia chocar o primeiro ovo — começa com 150.
- (Infraestrutura de teste: a matriz de rotação do mock acumulava erro no `PivotTo`; agora é re-ortonormalizada como no motor.)

## 7. Roteiro para conferir no Studio

1. **Play**: o Output deve mostrar `mundos construídos`, `servidor pronto` e `[Testes] Testes: 57 passaram`.
2. Ande até o **Ovo do Bosque** (E) → painel com as chances → *Chocar 1* → animação → o pet segue você.
3. Clique num **arbusto** → os pets mineram (moedas sobem e o número dourado aparece).
4. Vá até os **Thornlings** (lado −Z da ilha) → eles devem perseguir, atacar com aviso, voltar se você fugir.
   Confira se não atravessam pedras e se os pets **animam** (pernas, asas, cauda). Esse é o ponto de maior
   risco visual: a animação usa `Motor6D.Transform` no cliente.
5. Opções → Testes → *+1M moedas*, *Todos os itens*, *Equipe no nível máximo* → entre na **arena** (lado +Z):
   Elderroot desperta, os avisos vermelhos aparecem antes dos golpes e *Boss atual: -35% vida* troca a fase.
6. Saia e entre de novo (com o DataStore ativo): pets, mutações, itens e missões devem permanecer.
7. **Celular**: use o *Device Emulator* do Studio: barra da equipe, botão ⚔ e toque nos inimigos.
8. Abra o *MicroProfiler* durante uma luta de boss com efeitos ligados (e com *Qualidade de efeitos: Baixa*).

## 8. Limitações conhecidas

- Nunca executado no Roblox Studio (ver seção 6). Física, colisão, aparência, sons e desempenho reais estão
  pendentes de verificação.
- Sem meshes ou animações publicadas: tudo é procedural (peças primitivas, SpecialMesh de esfera e
  `Motor6D.Transform`). Não há som.
- O PathfindingService real não foi exercitado (no simulador sempre cai na rota alternativa).
- Anúncios globais dependem do MessagingService (limites do Roblox). O código limita a publicação a 10 por
  minuto por servidor.

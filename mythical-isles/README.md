# Mythical Isles — Pet Evolution Simulator (Roblox)

Simulador de pets com exploração, **sorte**, **mutações raras**, raridades **SECRET** e **CELESTIAL**,
**combate em equipe**, **inimigos com IA**, **5 bosses com fases**, recompensas, missões, bestiário e
salvamento. Tudo em **Luau**, organizado para **Rojo**. Mapa, criaturas, bosses, efeitos e interface são
**gerados por código**: não há assets de terceiros nem IDs inventados (as únicas texturas usadas são as que
vêm dentro do próprio cliente Roblox: `rbxasset://textures/particles/sparkles_main.dds`, `smoke_main.dds` e `fire_main.dds`).

> **Status honesto:** o código está completo e foi verificado com o compilador e o analisador oficiais do
> Luau, contra o dump público da API do Roblox, com 58 testes de lógica, 3297 verificações dos modelos 3D e
> **132 cenários executando o servidor e o cliente reais num simulador** (detalhes na seção 6).
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

Ao dar Play no Studio, o servidor imprime `[Testes] Testes: 58 passaram…` (os testes de lógica rodam
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

**Mundos 1 e 2 com 80 pets cada** (a partir da arte do autor em `docs/concept/`): famílias como nas fileiras da
arte (cervos, coelhos, raposas, cogumelos, slimes, golens, dragõezinhos, tartarugas-bosque, ents... / gatinhos,
ratinhos, slimes, raposas de cauda de cristal, lobos, cervos de ametista, dragão, golens, grifo), com os SECRET
**Sylvanox** e **Lumivex**. O Mundo 1 ganhou a Árvore Ancestral num platô no meio de um lago turquesa, penhascos
de musgo com cachoeiras, cachoeiras caindo da borda da ilha, bonsais, flores roxas e raios de sol.

**Visual mais realista (pets e cenário):**
- **Pets** (`Builders/CreatureBuilder.luau`, `ModelKit.detailedEye`):
  - **Olhos:** contorno, íris com profundidade, pupila (em fenda nos répteis e olhos brilhantes) e dois brilhos.
  - **Piscar:** a pálpebra fica escondida dentro da cabeça e o cliente a desliza sobre o olho a cada 3–5 s.
  - **Rosto:**
    - focinho com ponte, almofadas claras, queixo e nariz úmido (com reflexo);
    - bochechas com tufos de pelo;
    - orelhas em camadas (externa, interna rosada e ponta escura).
  - **Corpo:** barriga e peito mais claros (contra-sombreamento), pescoço e ancas, pernas lisas com pata e três dedos.
  - **Caudas articuladas:** uma onda percorre os segmentos (juntas `TailSeg*`).
  - **Asas:** penas em leque com pose de planeio.
  - **Cogumelos:** lamelas e pintas em relevo. **Slimes:** translúcidos com bolhas.
  - Média de 70 peças por pet (antes eram 31).
- **Luz** (`default.project.json` + `WorldClient`):
  - Iluminação Future com reflexos do céu (`EnvironmentDiffuse/SpecularScale` = 1) e sombras suaves.
  - Atmosphere com névoa e brilho do sol, nuvens dinâmicas (`Clouds`) e grama animada do Terrain (`Decoration`).
  - Bloom contido, raios de sol, correção de cor e uma leve profundidade de campo ao fundo.
  - Cada ilha tem seu próprio perfil de clima.
- **Terreno e vegetação** (`WorldBuilder`):
  - **Terreno:**
    - caminhos de terra sinuosos da praça até cada área;
    - manchas de solo, gelo ou lava conforme a ilha;
    - montinhos suaves e pedras semienterradas;
    - rochas irregulares sob a borda da ilha, que quebram o formato de "bolo de andares".
  - **Vegetação:**
    - árvores de galhos e cubos (ver "Árvore de galhos e cubos" abaixo) em três proporções: normal, alta e baixa de copa larga;
    - moitas, samambaias e grupos de rochas com musgo;
    - penhascos naturais atrás do lago.
  - Tudo é colocado sobre o chão real, encontrado por raycast.

**Folhagem e efeitos visuais:**
- **Folhagem** (`WorldBuilder.foliage`):
  - Moitas, arbustos de flor e os arbustos colhíveis não são mais bolas (as árvores agora usam o modelo de galhos e cubos).
  - Cada copa é um tufo de folhas individuais (triângulos e lâminas finas com material LeafyGrass) apontando para fora em leque, sobre um miolo escuro facetado.
  - As folhas de cima são mais claras (luz do sol) e as de baixo mais escuras.
  - Samambaias de frondes compridas e musgo em placas.
- **Efeitos visuais** (`client/Controllers/Fx.luau`), montados em camadas:
  - **Peças de cada efeito:** clarão de luz real (PointLight), faíscas alongadas que caem com a gravidade, brasas, bolas de fogo com fumaça, poeira que se espalha rente ao chão e fragmentos com física que quicam.
  - **Projéteis:** têm rastro (Trail).
  - **Tremor de câmera:** acontece perto dos impactos e fica reduzido no modo "efeitos: baixa".
  - **Golpes comuns:** cada acerto mostra um pequeno impacto.
  - **Meteoros:** a Chuva Estelar lança meteoros de fogo.
  - **Golpes dos bosses:** levantam poeira e lascas em toda a área atingida.
- **Ambiente:**
  - braseiros da arena com fogo de partículas (chama, brasas e fumaça);
  - respingos nas cachoeiras;
  - vaga-lumes de partículas na Árvore Ancestral;
  - pólen, esporos, cintilações ou névoa, conforme a ilha.
- **Texturas:** só as embutidas no cliente Roblox (`sparkles_main.dds`, `smoke_main.dds` e `fire_main.dds`, em `rbxasset://textures/particles/`).

### Árvore de galhos e cubos (todos os mundos)

`WorldBuilder.branchTree`, a partir da segunda referência do autor (árvore low-poly). Prévia em `docs/preview/arvore_nova.png`.

- **Tronco:** fino, marrom-avermelhado escuro, que se divide em 4 galhos (3 na versão alta, 5 na baixa), e cada galho em dois ramos.
- **Copa:** em cada ponta, um cacho de cubos girados ao acaso com material Grass (textura de grama do Roblox), em verdes escuros; os cubos de cima são um pouco mais claros e os de baixo ficam na sombra.
- **Cachos pendentes:** presos por ramos finos nas laterais.
- **Colisão:** só o tronco colide. De 60 a 100 peças por árvore conforme a proporção (as antigas tinham perto de 160). Com isso o Mundo 2 caiu para ≈ 5.500 peças e o Mundo 3 para ≈ 7.300.
- **Onde:** todas as árvores dos 5 mundos passam por esse modelo (`oakTree`, `bonsai` e o antigo pinheiro viraram proporções dele), inclusive a árvore gigante dos Celestial Gardens. A copa da Árvore Ancestral do lago também foi refeita com cachos de cubos (o tronco gigante, as raízes e o platô continuam).
- **Exceção:** o bosque de blocos do Verdant Haven (abaixo) continua com o seu próprio modelo.
- **Cores:** no Verdant Haven e na Árvore Ancestral, verdes escuros como na referência. No Crystal Hollow os cubos seguem azuis/violeta, e no Skybound Kingdom alguns são dourados ou rosados, para manter a identidade de cada mundo. Basta trocar as cores nas chamadas para deixar tudo verde.

### Verdant Haven — árvore de blocos (referência do autor)

`server/Services/BlockTree.luau`, posicionada por `WorldBuilder.blockGrove`. Referência em `docs/concept/world1_tree_ref.jpg`. Prévias em `docs/preview/arvore_*.png`.

**A árvore:**
- **Tronco:** grosso, marrom-escuro, com lascas de casca, raízes em cunha e galhos meio escondidos.
- **Copa:** muito larga e irregular, de blocos em vários tons de verde e alturas diferentes. Tem placas com *studs* e rosetas de folhas arredondadas e brilhantes.
- **Base:** placa verde baixa e pisável, com tufos de grama, plantas de folha larga, pedrinhas e folhas caídas.

**O bosque:**
- A **árvore de destaque** fica em θ 38°, a 120 studs do centro, entre a praça e a borda nordeste.
- Em volta, **6 árvores da mesma família** (larga, alta, redonda e jovens). Cada uma tem escala, copa e quantidade de blocos e rosetas diferentes, sem cópias idênticas.
- **Nada foi removido do mapa:** as áreas do bosque ficam reservadas para que a decoração aleatória não se sobreponha.

**Colisão:**
- Só o tronco, as raízes da árvore de destaque e a placa da base colidem.
- A copa não colide, e dá para andar em volta e por baixo dela.
- O bosque inteiro tem 535 peças.

### Mundo 3 — Skybound Kingdom

Construído a partir da arte de referência do autor (`docs/concept/world3_ref.png`). Prévias em `docs/preview/sky_*.png`.

**Código:**
- `server/Services/SkyKingdom.luau`: o mapa.
- `server/Services/SkyKit.luau`: ilhas, pontes e arquitetura.
- `shared/Config/Regions.luau`: as regiões.

**Ilhas:**
- **Ilha principal:** fica com o Cloud Harbor, a área de combate e a Tempest Arena.
- **Satélites:** em volta flutuam **8 ilhas satélites de Terrain**, cada uma com silhueta própria: topo de grama com contorno lobado, camada de rocha clara, base que afina em degraus irregulares, saliências e "pingentes" de rocha. Têm também raízes e cipós pendurados e cristais nas laterais.
- **Muro invisível:** cada ilha tem um, com aberturas nas pontes.
- **Pontes celestes:** 8 pontes de mármore com balaústres, frisos dourados, arcos por baixo e lanternas douradas; uma delas é suspensa, de cordas.

| Região | Onde | O que tem |
|---|---|---|
| **Cloud Harbor** | ilha principal | Praça, estações de ovo e portais. **Cais com navio voador** ancorado (casco, vela, balão). Pavilhão de cúpula dourada, estátua de guardião alado, três cachoeiras caindo da borda, lanternas e árvores. NPC **Capitã Aria**, portal e baú. |
| **Golden Heights** | θ 34°, 26 studs acima | **Palácio Celestial**: terraços, escadarias, colunata com frontão, salão, 4 torreões e torre central com **anéis dourados e feixe de luz**. Torres, estátuas, jardins, cristal gigante e cachoeira de 200 studs. **Ponte de cordas** até a torre solitária com o baú. NPC **Seren**. |
| **Storm Islands** | θ 266° (3 ilhas) | Nuvens de tempestade 2D com **raios** que caem periodicamente. **Cristais elétricos** com faíscas, torres destruídas e ruínas (arco e colunas). Cachoeira gigante de 220 studs e rajadas de vento. NPC **Thal** e baú. |
| **Celestial Gardens** | θ 160° (3 ilhas) | **Árvore gigante**, lago cristalino, canteiros de flores coloridas, bonsais, cristais, fonte dourada, pavilhão com lago e cachoeira. NPC **Lumi** e baú sob a árvore. |
| **Tempest Arena** | θ 90° | Arena do Wyrm cercada de **torres destruídas**, cristais elétricos, nuvens de tempestade com raios e vento. Tem relicário (baú). |

**Abaixo e acima das ilhas:** nuvens 2D brancas no estilo do céu anime e a cor de céu própria do mundo (Tarde Dourada Celestial).

**Ligação com o resto do jogo:**
- **Circuito de portais:** porto → alturas → tempestade → jardins → arena → porto, com "Voltar ao início".
- **Baús-santuário:** com recarga de 30 min.
- **Inimigos:** as zonas existentes (θ 222°–318°, junto à ponte das Storm Islands).
- **Boss e ovos:** o Tempest Wyrm e as estações de ovo existentes.
- **Ilhas satélites:** contam como parte do mundo (`Worlds.sky.extent`), para tesouros, região e queda.

**Tempest Wyrm, refeito** (184 peças, 81 studs de envergadura):
- **Cabeça:** placas no focinho, narinas, sobrancelhas, chifres, crista e membranas.
- **Pescoço e corpo:** pescoço articulado em 3 juntas, que o Animator ondula; corpo longo com placas de armadura e escamas ventrais.
- **Espinhos, asas e cauda:** fileira dupla de espinhos, asas enormes com veios elétricos e cauda de 8 segmentos.
- **Energia elétrica:** olhos, boca, peito, asas e cauda carregam energia azul com **arcos elétricos** antes dos ataques. Nos golpes de área, **raios caem do céu**.

**Testes do Mundo 3:**
- as 9 ilhas são alcançáveis pelas pontes a partir do porto;
- cada ponta de ponte e o cais têm chão firme embaixo e espaço livre em cima;
- inclinação máxima das pontes é 25°;
- portais, baús e NPCs funcionam;
- inimigos e boss estão presentes;
- raios e arcos rodam sem erro e somem;
- orçamento: cerca de 7.300 peças, 26 luzes e 74 emissores.

### Céu estilo anime 2D e cor de ambiente por mundo

`shared/Builders/AnimeSky.luau` e `client/Controllers/SkyClient.luau`. Prévias em `docs/preview/ceu_*.png`.

**Como é feito:**
- **Sem imagens externas:** o céu é desenhado no próprio jogo, sem skybox e sem IDs de asset.
- **Degradê:** vem da `Atmosphere` do Roblox, tingida pela paleta do mundo (`Color` = horizonte, `Decay` = alto do céu).
  - **Correção do "céu bugado":** antes o degradê era pintado em 8 painéis `BillboardGui` gigantes em volta da câmera. Só que `BillboardGui` sempre fica paralelo à tela, então ao virar ou inclinar a câmera os painéis giravam, abriam frestas, deixavam o céu padrão aparecer por cima e cobriam as ilhas distantes. Os painéis foram removidos.
  - Nuvens, faixas, sol e estrelas agora ficam a 1.050–1.500 studs da câmera, além da ilha mais distante que se vê (≈ 800 studs no Skybound Kingdom), então não cobrem mais nenhuma ilha.
  - O sol e a lua do Roblox ficam escondidos (`Sky.CelestialBodiesShown = false`), para não aparecerem dois sóis.
  - Nas prévias o degradê é uma aproximação do que a Atmosphere produz; o tom exato no jogo depende do motor do Roblox.
- **Nuvens:** 14 nuvens planas "cel-shaded" (sombra pastel embaixo, preenchimento e brilho em cima, base reta) e faixas finas no horizonte.
- **Sol ou lua:** em 2D com halo, posicionado na direção real do sol (ou da lua) do Roblox.
- **Estrelas:** cintilantes, nos mundos noturnos.
- **Cor chapada:** tudo usa `LightInfluence = 0`, sem sombreamento 3D e sem acionar o Bloom.
- **Movimento:** o céu fica centrado na câmera (parece infinitamente distante), e as nuvens derivam devagar com o vento.

**Paletas:** cada mundo tem a sua, que também define a cor da névoa (Atmosphere), do decaimento, do tom (ColorCorrection) e da luz ambiente.

| Mundo | Céu |
|---|---|
| Verdant Haven | Manhã Esmeralda: azul vivo, horizonte verde-menta, nuvens brancas |
| Crystal Hollow | Tarde Safira: anil, horizonte lavanda, sombras violeta |
| Skybound Kingdom | Pôr do Sol Rosa-Dourado (o horário passou para 17:18) |
| Whispering Wilds | Crepúsculo Turquesa |
| Astral Sanctuary | Noite Violeta, com estrelas e lua crescente |

### Mundo 2 — Crystal Hollow

Construído a partir da arte de referência do autor (`docs/concept/world2_ref.png`). Prévias:
`docs/preview/crystal_*.png`, com o terreno voxelizado como o Roblox faz.

**Código:**
- `server/Services/CrystalHollow.luau`: o mapa e as cinco regiões.
- `server/Services/CrystalKit.luau`: cristais e arquitetura.
- `server/Services/RegionService.luau`: portais de região, baús e NPCs.
- `shared/Config/Regions.luau`: limites, luz e sons de cada região.
- `client/Controllers/RegionClient.luau`: nome da região na tela, luz e som por região.

| Região | Onde | O que tem |
|---|---|---|
| **Crystal Valley** | centro | Praça, ovos e portais de mundo. Grama animada, caminhos de pedra e uma lagoa com flores luminosas. Árvores de folhas azuis e violeta, aglomerados de cristal e lanternas com fogo. Arco em ruínas, NPC **Lyra**, portal de região e **Baú do Vale**. |
| **Shattered Peaks** | θ 45° | Três montanhas de Terrain (74, 100 e 66 studs) com faces de penhasco, musgo e cristais gigantes nos cumes. **Grande cachoeira** de 76 studs caindo de um paredão numa bacia. Rio escavado até a lagoa do vale, com ponte de pedra. Rampa de pedra até uma plataforma e **ponte suspensa** na frente da cachoeira, levando ao **Baú do Pico**. |
| **Azure Caverns** | θ 195° | Maciço rochoso com túnel de entrada, **salão escavado** e lago subterrâneo. Cristais nas paredes, estalactites, névoa e luz azul. **Passagem secreta** atrás de uma cortina de cristais leva à câmara com o **cristal raro** e o **Baú Secreto**. NPC **Orin**. |
| **Prism Lake** | θ 140° | Lago de margens irregulares com ilhas e cristais saindo da água. **Ponte de pedra** até a ilha das ruínas (colunas, arco, cristal raro e **Baú das Ruínas**). Penhasco com **duas cachoeiras**. Riacho de saída que cai da borda da ilha. |
| **Titan's Domain** | θ 90° | Arena do Prism Titan cercada por obeliscos com cristais e estandartes. Estátua colossal quebrada, **fachada de templo** em ruínas, dois espigões de cristal gigantes, **Relicário do Titã** e NPC **Vael**. |

**Ligação entre as regiões:**
- **Caminhos:** caminhos de pedra ligam o vale a cada região.
- **Circuito de portais:** vale → picos → cavernas → lago → domínio → vale. Cada portal também tem "Voltar ao vale" (tecla R).
- **Validação no servidor:** o portal exige o mundo desbloqueado e o jogador dentro dele, com intervalo anti-spam. Os pets vão junto.

**Recompensas e NPCs:**
- **Baús-santuário:** recompensa da tabela `Drops.Shrine`, com recarga de 30 min por jogador salva no perfil (`data.shrines`). Na primeira abertura aparece o aviso "Local secreto descoberto". Contam para a missão de tesouros.
- **NPCs:** dão dicas da região, uma fala diferente a cada conversa.

**Prism Titan, refeito:**
- **Corpo:**
  - pedra escura com peitorais, abdômen em placas e costelas;
  - núcleo no peito com moldura, casca de cristal e veios de energia;
  - rosto com testa, maçãs, olhos fundos e brilhantes, nariz e mandíbula com dentes de cristal;
  - chifres e coroa de cristal;
  - ombreiras com cristais, antebraços largos com espinhos e punhos com nós dos dedos;
  - grande aglomerado de cristais nas costas.
- **Energia:** o núcleo, os olhos e os punhos pulsam em repouso, carregam luz e partículas enquanto o ataque é preparado e soltam uma rajada no golpe.

**Luz:**
- O mundo virou uma tarde de céu azul, como na referência.
- Cada região ajusta a névoa e a luz: a caverna é escura e enevoada, o lago mais claro, o domínio mais dramático.
- O Bloom continua contido.

**Sistemas que continuaram iguais e foram testados:**
- ovos e estações, inimigos e zonas, campos de recurso e o boss;
- portais de mundo, desbloqueio e salvamento.

O terreno novo não pode soterrar nenhum ponto de gameplay. O simulador verifica 113 pontos no estado final do terreno, contando as escavações: túnel, salão, passagem secreta, plataformas, ilha, chegadas dos portais e baús.

**Desempenho:**
- O Mundo 2 tem cerca de 5.500 peças, 45 luzes e 104 emissores, com teto testado de 9.000, 60 e 120.
- A decoração não colide nem dispara Touched, e peças pequenas não projetam sombra.

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
| Lógica pura | `python3 tools/run_tests.py luau` | **58 testes passando** |
| Modelos 3D (182 pets × 6 mutações × 5 acessórios, 16 inimigos, 5 bosses ≤ 280 peças) | `python3 tools/run_tests.py luau --smoke` | **3297 verificações, 0 falhas** |
| Servidor + cliente reais num simulador | `python3 tools/run_tests.py luau --sim` | **135 cenários passando** (inclui efeitos visuais, regiões dos Mundos 2 e 3, céu anime sem painéis, a árvore de galhos e cubos em todos os mundos e o bosque do Mundo 1) |
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
- **Domo de rocha sobre a ilha** (achado pela prévia renderizada): a "raiz" da ilha flutuante era uma esfera
  de raio 165 centrada 52 studs abaixo do chão, cujo topo saía 113 studs ACIMA da grama, enterrando a praça.
  Trocada por camadas de cilindros sempre abaixo do chão; o simulador agora reprova qualquer terreno acima da superfície.
- Jogador novo começava com 0 moedas e não conseguia chocar o primeiro ovo — começa com 150.
- (Infraestrutura de teste: a matriz de rotação do mock acumulava erro no `PivotTo`; agora é re-ortonormalizada como no motor.)

## 7. Roteiro para conferir no Studio

1. **Play**: o Output deve mostrar `mundos construídos`, `servidor pronto` e `[Testes] Testes: 58 passaram`.
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

10. **Skybound Kingdom**:
    - Atravesse as 8 pontes, incluindo a de cordas até a torre das Golden Heights.
    - Confira se as cachoeiras caem até as nuvens.
    - Veja os raios nas Storm Islands.
    - Lute contra o Wyrm e confira os arcos elétricos antes dos golpes.
    - Teste no celular.
9. **Crystal Hollow**:
   - Desbloqueie o mundo e entre pelo portal.
   - Atravesse o circuito de portais de região e confira o nome de cada região na tela e a mudança de luz.
   - Suba a rampa dos Shattered Peaks e atravesse a ponte suspensa.
   - Entre nas Azure Caverns, ache a passagem atrás da cortina de cristais e abra o baú secreto.
   - Siga a ponte do Prism Lake até a ilha das ruínas.
   - Lute contra o Prism Titan e veja o núcleo e os punhos carregarem antes dos golpes.
   - Pontos de atenção:
     - se os túneis e plataformas de Terrain ficaram com o tamanho certo depois da voxelização (4 studs);
     - se as cachoeiras encostam na água;
     - o FPS no celular.

## 8. Limitações conhecidas

- **Sons ambientes do Mundo 2:**
  - O sistema está pronto (som por região com transição suave), mas `Regions.Sounds` está vazio.
  - O projeto não inventa IDs de áudio: cole IDs do Creator Store (vento, cachoeira, gotejamento de caverna, água, zumbido de cristais) e eles passam a tocar.
- **StreamingEnabled continua desligado:**
  - O cliente lê modelos de todas as ilhas (estações, recursos, inimigos), e o teleporte entre ilhas a 1.400 studs pode deixar o personagem cair antes do terreno chegar.
  - Ligar exige `RequestStreamAroundAsync` nos teleportes e testes no Studio.
  - A otimização feita foi por orçamento de peças, luzes e emissores.
- Nunca executado no Roblox Studio (ver seção 6). Física, colisão, aparência, sons e desempenho reais estão
  pendentes de verificação.
- Sem meshes ou animações publicadas: tudo é procedural (peças primitivas, SpecialMesh de esfera e
  `Motor6D.Transform`). Não há som. O visual "realista" daqui é o teto do que dá para fazer só com peças:
  qualidade de jogo profissional de verdade (pelo com textura, formas orgânicas contínuas) exige meshes
  esculpidas no Blender com texturas/SurfaceAppearance, importadas pelo 3D Importer do Studio. A estrutura
  de juntas (`Body`, `Neck`, `Leg*`, `Tail*`...) foi pensada para aceitar essas meshes depois.
- Pets agora têm ~70 peças cada: com muitos jogadores e 4 pets por jogador, confira o desempenho no
  MicroProfiler (dá para baixar detalhes, como dedos e bolhas, se precisar).
- A Verdant Haven tem ~7.100 peças (a folhagem é feita de folhas individuais); confira o FPS no celular.
  Os efeitos de partícula não aparecem nas prévias, só no jogo.
- As prévias em `docs/preview/` são renderizadas fora do Roblox: não mostram a grama animada, as texturas
  dos materiais, as nuvens nem a Atmosphere reais.
- O PathfindingService real não foi exercitado (no simulador sempre cai na rota alternativa).
- Anúncios globais dependem do MessagingService (limites do Roblox). O código limita a publicação a 10 por
  minuto por servidor.

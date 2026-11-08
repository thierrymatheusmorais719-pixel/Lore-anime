# Mythical Isles — Pet Evolution Simulator (Roblox)

Simulador de pets com exploração, **sorte**, **mutações raras**, raridades **SECRET** e **CELESTIAL**,
**combate em equipe**, **inimigos com IA**, **5 bosses com fases**, recompensas, missões, bestiário e
salvamento. Tudo em **Luau**, organizado para **Rojo**. Mapa, criaturas, bosses, efeitos e interface são
**gerados por código**: não há assets de terceiros nem IDs inventados (as únicas texturas usadas são as que
vêm dentro do próprio cliente Roblox: `rbxasset://textures/particles/sparkles_main.dds`, `smoke_main.dds` e `fire_main.dds`).

> **Status honesto:** o código está completo e foi verificado com o compilador e o analisador oficiais do
> Luau, contra o dump público da API do Roblox, com 62 testes de lógica, 3866 verificações dos modelos 3D e
> **167 cenários executando o servidor e o cliente reais num simulador** (detalhes na seção 6).
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

**Pets 3D novos:** funcionam de dois jeitos, escolhidos sozinhos pelo jogo:
- **sem configurar nada:** modo **low-poly** — a mesma anatomia, esqueleto e animação, com a superfície feita de
  triângulos de peças (cada triângulo = 2 WedgeParts), estilo facetado (prévias `docs/preview/malha_lowpoly_*.png`).
  Por ser pesado (~1.500 peças por pet), só os pets do próprio jogador usam esse modo; os dos outros ficam no modelo antigo.
- **com a opção ligada:** malhas **lisas** (`EditableMesh`). O Roblox só libera com:
1. *Arquivo → Publicar no Roblox* (as Configurações do jogo só abrem num jogo publicado);
2. *Início → Configurações do jogo (Game Settings) → Segurança (Security)* → ative **Allow Mesh / Image APIs** e salve
   (o Roblox exige que o dono da experiência tenha 13+ e ID verificado);
3. pare e dê Play de novo.

Sem a opção o jogo usa o modo low-poly e avisa com uma mensagem rápida. A caixa de erro na tela só aparece se
nenhum dos dois modos funcionar.

**Bosses 3D novos:** seguem a mesma regra, sozinhos — low-poly de peças sem configurar nada
(`docs/preview/boss_line_low.jpg`), malhas lisas com a opção ligada (`docs/preview/boss_line_mesh.jpg`).

**Para testar o salvamento (DataStore):** publique o lugar e ative *Game Settings → Security → Enable Studio
Access to API Services*. Sem isso o jogo roda em **modo memória** e avisa na tela e no Output que nada será
salvo.

Ao dar Play no Studio, o servidor imprime `[Testes] Testes: 62 passaram…` (os testes de lógica rodam
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
| 7 | **Bosses** | `Config/Bosses.luau`, `Builders/BossModels.luau` (servidor), `Builders/BossAnatomy.luau` + `BossVisuals.luau` (visual no cliente), `BossService.luau` | Elderroot, Prism Titan, Tempest Wyrm (fase aérea), The Wilderbloom (invocações, zonas seguras), Void Sovereign (4 fases). Entrada, fases com transição invulnerável, aviso do próximo ataque, respawn, reset se a arena esvaziar, vida que escala com os jogadores |
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

**2ª leva de pets do Mundo 1 (10 espécies, o mundo agora tem 90):** feitos a partir das três referências enviadas
como **modelos originais** (nomes, proporções e detalhes próprios, sem copiar os personagens), com corpos novos no
`Builders/CreatureBuilder.luau`. Prévias em `docs/preview/pets_novos*.png`.

| Família | Raridade | Corpo (`rig`) | Como é |
|---|---|---|---|
| Sprout / Maple / Blossom / Mossy Panda | Comum | `leafpanda` | Panda de corpo de pera coberto por um manto-capuz de folhas com barra em pontas, rosto de panda (manchas escuras, focinho claro), orelhas redondas, broto alto que balança, bracinhos escuros levantados com garras claras |
| Berrytuft / Bluebramble / Sunberry Goat | Raro | `bushgoat` | Cabra redonda e fofa (barriga creme, pelo verde-claro), arbusto de folhas com frutinhas nas costas, orelhas caídas de folha, chifres anelados curvados para trás, cascos escuros |
| Meadow / Autumn Mammoth | Épico | `mammoth` | Mamute de pele castanha coberto por um manto de capim com fios compridos caindo pelas laterais e pela testa, orelhas de folha, tromba articulada, presas curvas, braceletes de cipó |
| Elder Grove Mammoth | Lendário | `mammoth` | Versão maior, de olhos brilhantes e presas douradas |

Entram sozinhos nos ovos do Mundo 1 (o peso de cada raridade é dividido entre as espécies dela).

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

### Pets refeitos: malhas anatômicas, esqueleto e animação por espécie

Prévias em `docs/preview/malha_*.png` (geometria real gerada pelo jogo, renderizada fora do Roblox).

**Como os modelos são feitos:**
- **Malhas contínuas, não bolinhas:** cada parte do corpo é uma superfície orgânica fechada (`Builders/MeshKit.luau`)
  que percorre uma curva com seções de largura/altura variáveis — tronco com peito profundo e cintura recolhida,
  pescoço, crânio com focinho, mandíbula, orelhas, coxa, canela, pata, cauda — com normais suaves e **cor por
  vértice** (dorso mais escuro, barriga clara, meias, máscara, listras, pintas, estrelas).
- **MeshParts de verdade, criadas pelo próprio jogo:** `Builders/PetMesh.luau` grava a geometria num
  `EditableMesh` e cria a `MeshPart` com `AssetService:CreateMeshPartAsync`. **Nenhuma malha foi enviada como
  asset e nenhum ID foi inventado.** Um molde por espécie fica em cache no cliente e cada pet é um clone.
- **Anatomia por tipo de animal** (`Builders/PetAnatomy.luau`, 32 tipos para as 192 espécies): canídeos (raposa,
  lobo, filhote), felinos (gato, lince, leão com juba, pantera com pintas), grifo, cervídeos (galhada),
  caprinos (chifre em espiral, barba), lebres, roedores, esquilos, mustelídeos, ursos, javalis e mamutes (tromba
  articulada, presas), répteis e dragões (escamas, espinhos, asas de membrana), sapo (patas com membrana),
  tartaruga (casco com placas), besouros (6 patas, élitros), aves (bico em gancho nos gaviões, disco facial nas
  corujas, rêmiges uma a uma, leque da cauda, garras), morcego, mariposa, serpentes (corpo em 6 segmentos),
  slime (gota com poça escorrendo), cogumelo (lamelas), golens facetados, gorila, ent, espíritos e o panda de folhas.
- **Esqueleto completo:** pivôs nas articulações reais — ombro → cotovelo → pulso nas patas da frente, quadril →
  joelho → jarrete nas de trás (digitígradas nos cães e gatos, plantígradas nos ursos, cascos nos cervídeos),
  pescoço → cabeça → mandíbula, base das orelhas, pálpebras, cauda em cadeia, asas, segmentos da serpente.
- **Rostos:** olhos com íris, pupila (redonda ou em fenda), contorno e brilho, encaixados na superfície real
  do crânio (raio contra a malha), sobrancelhas, bochechas, focinho, nariz e boca.

**Animação própria por anatomia** (`client/Controllers/CreatureMotion.luau`): respiração, piscar, orelhas e cauda
abanando em todas; trote em diagonal ao andar e galope com a coluna flexionando ao correr nos quadrúpedes; saltos
nas lebres, esquilos e sapos; marcha em tripé nos besouros; voo com batida de asas nas aves; onda pelo corpo nas
serpentes; passada com braços opostos nos bípedes. **Ataque** diferente por tipo (bote e mordida nos canídeos,
patada nos felinos, cabeçada/empinada nos cervídeos e pesados, bicada com mergulho nas aves, bote da serpente,
golpe com os dois braços nos golens), **pulo** quando o dono pula, **comemoração** quando um boss é derrotado,
**reação ao dono** (olha para ele, orelhas em pé e cauda abanando quando ele chega perto) e **desmaio** quando
o pet é nocauteado.

**Raridade muda o modelo** (`PetAnatomy.decorate`): Incomum ganha meias e máscara claras; Raro, peitoral de pelo
e pontas escuras; Épico, marcas que brilham no dorso e gema na testa; Lendário, diadema e braceletes de ouro com
brilho e luz; Mítico, fitas etéreas (ForceField), runas orbitando e rastro; Secret, pelagem estrelada, coroa de
cristais e aura; Celestial, auréola de luz.

**Como entra no jogo** (`client/Controllers/PetVisuals.luau`): o servidor continua com o pet de sempre (posição,
seguir o dono, combate, inventário, equipar — nada disso mudou); o cliente põe o modelo de malhas por cima, preso à
raiz do pet, e esconde o modelo antigo só na tela dele. Mutações e acessórios são aplicados no modelo novo. As
miniaturas do inventário e a revelação do ovo usam a malha quando ela já está pronta.
**Se a API de malhas não funcionar** (ex.: desligada nas configurações do jogo), o cliente mantém o modelo antigo,
sem erro.

### Bosses anatômicos (malha ou low-poly)

Os 5 bosses foram refeitos com a mesma técnica dos pets, seguindo a arte conceitual (`docs/concept/bosses.png`).
Prévias: `docs/preview/boss_line_mesh.jpg`, `boss_line_low.jpg` e `boss_*_pair.jpg` (malha | low-poly lado a lado).

- **Elderroot:** colosso de casca com relevo de sulcos, musgo nas faces de cima, placas de casca no peito,
  rachaduras verdes, cristal no peito, galhada ramificada com folhas, órbitas fundas com olhos verdes, presas,
  barba de raízes, punhos de nós de madeira e pés de raízes com garras.
- **Prism Titan:** rocha facetada em blocos (peitorais, costelas, abdômen, corcova), aglomerados de cristal de vidro
  com núcleo luminoso (costas, ombros, coroa, antebraços, joelhos), coração de energia com casca de vidro e veios,
  olhos em fenda e punhos enormes.
- **Tempest Wyrm:** dragão de prata com dorso azulado e ventre em placas, pescoço articulado em 3 juntas, cabeça
  com dentes, chifres e espinhos dourados, olhos e boca elétricos, asas com ossos dourados, membrana recortada e
  veios elétricos, 4 patas com garras e esporões, cauda de 8 segmentos com lâmina.
- **The Wilderbloom:** fera de casca corcunda com espinhos espalhados pela superfície, coração e veios rosa, coroa
  de 8 pétalas de cristal articuladas, braços com garras e 4 cipós espinhosos que se enrolam com cristais na ponta.
- **Void Sovereign:** armadura facetada com frisos dourados, gema no peito, túnica de 10 placas até o chão com barra
  brilhante, capa com dobras e forro roxo, elmo com viseira e olhos roxos, coroa de chifres dourados, auréola com
  espinhos, ombreiras em camadas e 8 cristais em órbita.

**Como entra no jogo** (`client/Controllers/BossVisuals.luau`): o servidor continua com o boss de sempre (posição,
IA, fases, ataques, vida, hitbox). O cliente monta o boss novo (`Builders/BossAnatomy.luau` → `Builders/BossMesh.luau`,
mesmo construtor dos pets: `PetMesh.assemble`) **só quando o jogador chega perto da arena**, prende na raiz do boss
do servidor e esconde o antigo na tela dele; ao se afastar, o boss novo sai da cena. As juntas têm **os mesmos
nomes** do modelo antigo (Body, Neck, Jaw, ArmL/R, LegL/R, LegFL…, WingL/R, NeckSeg1–3, Seg1–8, Petal1–8, Root1–4,
Orbit, OrbitHalo), então o `Animator` anima o boss novo com os mesmos golpes, rugidos, preparação e derrota, lendo os
atributos do boss do servidor. A energia (`Fx`) passa para as peças novas (núcleo, olhos, punhos, gema, veios das
asas, ponta da cauda), com os arcos elétricos do Wyrm. Peso: 7.000–16.000 triângulos por boss em malha; no modo
low-poly 2.500–3.100 triângulos (≈ 5.000–6.200 cunhas), montados em lotes para não travar.
Se nenhum dos dois modos funcionar, o boss antigo continua visível.

### Árvore-Santuário (Great Sanctuary Tree) — Verdant Haven

`server/Services/SanctuaryTree.luau` + `SanctuaryService.luau` (Elevador de Seiva) + `client/Controllers/SanctuaryClient.luau`
(runas). Prévias: `docs/preview/arvore_santuario_*.jpg`.

- **Lugar:** no lago turquesa onde ficava a Árvore Ancestral (que ela substituiu), longe da praça do spawn. O tronco
  fica suspenso sobre o lago, com o platô e as cachoeiras embaixo dele.
- **Escala:** ~310 studs de altura e copa de ~280 studs de diâmetro: visível de qualquer ponto da ilha.
- **6 raízes em arco** pousam em volta do lago, desviando da arena, dos penhascos e do campo de recursos; a
  **Escadaria da Raiz** fica virada para a praça. Poças de seiva brilhante nos pés das raízes.
- **Andares:** Margem do Lago (chão) → **Escadaria da Raiz** (degraus de 1,25 stud por cima da raiz longa) →
  **Coração da Raiz** (deck em anel, ~49 studs) → **rampa em espiral** pela casca (≤ 15° por tábua, com corrimão) →
  **4 Galhos Suspensos** que saem da rampa como estradas de tábuas até **ninhos com baús** → **Copas Celestiais** (deck
  dentro da copa, flores de luz, terraços de folhas para subir pulando) → **Coroa Estelar** (mirante com altar e
  relicário, ~302 studs).
- **Elevador de Seiva:** estações em cada andar com "Subir"/"Descer" para o vizinho, validadas no servidor (perto da
  estação, sem pular andar). A **Coroa Estelar só abre depois de vencer o Elderroot**. Os pets vão junto.
- **6 baús novos** (4 ninhos, copa e coroa) no sistema de baús-santuário (recompensa e recarga por jogador).
- **Detalhes:** casca com relevo de sulcos e musgo nas faces de cima (malha convertida em cunhas, sem EditableMesh),
  6 anéis de **runas** que acendem em ondas subindo pelo tronco (douradas depois do Elderroot), **seiva** escorrendo
  pelos sulcos, esporos dourados caindo da copa, vagalumes, lanternas de esporos, rosetas e flores-estrela.
- **Peso:** ≈ 4.840 peças (3.506 cunhas da casca + 1.330 peças). A ilha 1 passa a ter ≈ 17.600 peças.
  `Worlds.verdant.ceiling = 340`: quem está no alto da árvore continua "no Verdant Haven".

### Farol Ancestral e ruínas (Mundo 2 — Crystal Hollow)

`server/Services/BeaconTower.luau`, construído por `CrystalHollow.buildBeacon` no fim do caminho oeste do vale
(θ 294°, 100 studs do centro, entre as zonas de inimigos). Feito a partir da imagem do autor. Prévias:
`docs/preview/farol_ancestral*.jpg`.

- **Torre-farol de ~110 studs** em treliça de pedra que se alarga para cima (anéis octogonais, montantes e
  travessas em X), base em degraus com painéis de runas violeta, brilho violeta na cintura, coroa de pontas, um
  **cristal azul gigante** (vidro com núcleo de neon, luz e brilhos) e um **feixe de luz** subindo ao céu.
- **10 raízes de pedra com veios violeta** espalhando-se pelo chão (malha em cunhas, sem EditableMesh).
- **Ruínas em volta:** portal de pedra (trilito) na entrada — no lugar do antigo arco do caminho oeste —,
  colunata com vigas, círculo de pedras em pé (algumas caídas, com runas), colunas quebradas, blocos e lajes
  do piso antigo, e **3 ilhotas flutuantes** com árvores de cristal. As peças só nascem fora das zonas de inimigos
  e dos campos; a área ficou reservada (sem árvores da decoração por cima).
- **Região com nome** ("Farol Ancestral — Ruínas do Farol") e o baú **Relicário do Farol**.
- **Peso:** ≈ 2.200 peças (contado à parte do orçamento do mundo).

### Ataques Assinatura (um ataque próprio por pet do Verdant Haven)

`shared/Config/Signatures.luau` (catálogo), `server/Services/SignatureService.luau` (execução e validação),
`client/Controllers/Fx.luau` (efeitos), barra de **Fúria** no HUD da equipe e a descrição no painel do pet.

- **Como funciona:** cada ataque básico do pet enche a **Fúria** (5 golpes nos Comuns/Incomuns, 6 nos Raros/Épicos,
  7 nos Lendários, 8 nos Míticos/Secret). Com a barra cheia, o próximo golpe é o **Assinatura** da espécie, com o nome
  na tela sobre o pet. Não gasta energia e não ocupa as teclas 1-4 (a habilidade de classe continua igual).
- **Os 39 pets do Mundo 1** têm Assinatura (33 entradas por família; as variantes da mesma família dividem o ataque).
  Exemplos: *Mordida de Folha Cortante* (raposinha), *Pulo Florido* (coelho), *Pio Hipnótico* (corujinha), *Nuvem de
  Esporos* (cogumelo), *Pisão Rachado* (golem), *Galhada Enraizante* (cervo), *Esferas de Polinização* (wyvern),
  *Uivo da Matilha* (lobo), *Onda de Choque Vibracional* (gorila de musgo), *Vendaval Esmeralda* (wisp),
  *Chuva de Meteoros de Esmeralda* (cão espectral), *Despertar das Raízes Ancestrais* (cervo ancião),
  *Coração da Floresta* (ent), *Eclipse do Santuário* (Sylvanox).
- **Mecânicas (todas no servidor):** formas de alvo único, cone, círculo, área no alvo, linha, ricochete, vários alvos e
  tornado que anda; golpes em pulsos; atordoar, prender, lentidão (agora também nos inimigos comuns), empurrar, puxar,
  marca, quebra de defesa e sangramento; cura, escudo, força e velocidade para a equipe, provocar e faro de baús.
  Em **bosses**, atordoar/prender vira lentidão de 40% e eles não são empurrados.
- **Força crescente por raridade** (conferida em teste): Comuns ≈ 1,3× um golpe; Míticos com área grande e vários
  pulsos, mas com Fúria maior.
- **Não implementado da proposta:** os pets novos *Urso de Casca* e *Coruja Antiga* (exigem modelo, ovo e balanceamento
  próprios); as zonas e os inimigos novos das fases 3 a 5.

### Ilhas ampliadas: anel de mata para exploração

`WorldBuilder.wildRing` e `WorldBuilder.ringPlan`. Prévias em `docs/preview/mata_*.png` e `crystal_mata_alto.png`.

- **Tamanho:** a parte central de cada ilha (praça, ovos, portais, arena, zonas e as regiões feitas à mão) ficou
  igual; em volta dela a ilha cresceu e ganhou um anel de mata.

  | Mundo | Raio antes | Raio agora | Área | Árvores na mata | Peças no mundo |
  |---|---|---|---|---|---|
  | Verdant Haven | 230 | 345 | ×2,25 | 251 | ≈ 12.800 |
  | Crystal Hollow | 230 | 315 | ×1,9 | 76 (+ cristais) | ≈ 8.400 |
  | Whispering Wilds | 230 | 335 | ×2,1 | 246 | ≈ 9.500 |
  | Astral Sanctuary | 220 | 315 | ×2,05 | 115 (+ estilhaços) | ≈ 4.000 |

  O Skybound Kingdom não mudou: ele já é o maior (ilhas satélites até 390 studs) e as pontes entre as ilhas
  dependem das distâncias atuais.
- **Floresta densa:** árvores de galhos e cubos (versão leve, ~25 peças), com bosques fechados e clareiras
  sorteados por um "ruído" de senos, arbustos de cubos, pedras com musgo e, por mundo, cristais (Mundo 2) ou
  estilhaços flutuantes (Mundo 5). As faixas dos riachos que descem até a borda ficam livres.
- **Trilha:** uma trilha de terra sinuosa dá a volta na ilha dentro da mata, com quatro ligações até a parte
  central e um trecho até cada lugar.
- **Seis lugares para descobrir em cada mundo**, cada um com um **baú-santuário de verdade** (mesmo sistema dos
  baús das regiões: recompensa da tabela `Drops.Shrine`, recarga de 30 min por jogador, aviso de "local secreto
  descoberto" na primeira vez):
  ruínas com colunas quebradas, lago escondido (água de Terrain), mirante de madeira no alto de um morro,
  acampamento abandonado (barracas, fogueira com fogo e luz), tronco oco gigante para atravessar por dentro e
  círculo de pedras com runas.
- Os baús de tesouro aleatórios da exploração passam a aparecer também na mata (eles usam o raio da ilha).

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
│  ├─ Builders/  ModelKit, CreatureBuilder (pets), MutationVisuals, Accessories, EnemyModels, BossModels,
│  │             MeshKit, PetAnatomy, PetMesh (pets de malha), BossAnatomy, BossMesh (bosses de malha)
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
| Lógica pura | `python3 tools/run_tests.py luau` | **62 testes passando** |
| Modelos 3D (192 pets × 6 mutações × 5 acessórios, 16 inimigos, 5 bosses ≤ 280 peças) + malhas anatômicas das 192 espécies (esqueleto completo por tipo, índices válidos, nenhum vértice NaN, pés no chão, nenhuma silhueta de "bolinha", ≤ 18.000 triângulos) + bosses anatômicos nos dois modos (todas as juntas do boss antigo, mesma altura de raiz, pés no chão, peças de energia com cor, ≤ 20.000 / 3.400 triângulos) | `python3 tools/run_tests.py luau --smoke` | **3866 verificações, 0 falhas** |
| Servidor + cliente reais num simulador | `python3 tools/run_tests.py luau --sim` | **167 cenários passando** (inclui o Farol Ancestral do Mundo 2: torre, ruínas, ilhotas, região e baú; os ataques Assinatura: formas, controle, cura, escudo, força e a Fúria em combate real, e todos os efeitos no cliente; a Árvore-Santuário: escala, rampa, altura livre, elevador, baús e runas; o boss novo: troca do Prism Titan pelo de malhas com o antigo escondido, mesmas juntas, raiz acompanhando a do servidor, juntas animadas, energia carregando nas peças novas, sair/voltar da cena pela distância e o modo low-poly sem EditableMesh; inclui efeitos visuais, regiões dos Mundos 2 e 3, céu anime sem painéis, a árvore de galhos e cubos em todos os mundos, o bosque do Mundo 1, o anel de mata com os baús abrindo e os pets de malha: troca de todos os pets da equipe, modelo antigo escondido, juntas animadas, pose de ataque e desmaio) |
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

1. **Play**: o Output deve mostrar `mundos construídos`, `servidor pronto` e `[Testes] Testes: 62 passaram`.
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
- **Pets de malha — o que ainda precisa do Studio:**
  - As malhas são criadas em tempo de execução com `EditableMesh`. No Studio isso funciona direto; num jogo
    publicado pode ser preciso ligar a opção de APIs de malha/imagem ("Allow Mesh / Image APIs") nas
    configurações de segurança do jogo, conforme as regras atuais do Roblox para essa API. Sem ela, o jogo
    continua com os pets antigos.
  - Não foi possível ver as malhas dentro do Roblox. O simulador confere as chamadas da API, a montagem do
    esqueleto e a animação das juntas, e as prévias mostram a geometria real. Mas a cor por vértice com os
    materiais do Roblox (Fabric etc.), o sombreamento e o desempenho reais só se confirmam no Studio.
  - Animações são procedurais (`Motor6D.Transform` a cada quadro), não `AnimationTrack`s publicadas: não há
    animação enviada como asset. O esqueleto usa `Motor6D` com nomes fixos, então aceita animações publicadas
    depois.
  - As formas são geradas por código, não esculpidas à mão. É um salto grande em relação às peças primitivas,
    mas qualidade de estúdio profissional (pelo com textura, retopologia, skinning) ainda pediria modelos
    esculpidos e importados pelo 3D Importer, com texturas.
  - Peso: em média 8.400 triângulos e 22 MeshParts por pet (máx. 14.800). As malhas são feitas uma vez por espécie
    e clonadas. Confira no MicroProfiler com muitos jogadores.
- **Bosses anatômicos — o que ainda precisa do Studio:**
  - Não foram vistos dentro do Roblox. O simulador confere a montagem, as juntas, a animação, a energia e a troca
    de modo; as prévias mostram a geometria real. Aparência com os materiais do Roblox e desempenho só no Studio.
  - No modo low-poly cada boss tem ≈ 5.000–6.200 peças (cunhas soldadas a ossos animados). Por isso só o boss de que
    o jogador está perto é montado. Confira no MicroProfiler, principalmente no celular.
  - "100x melhor" não é medida: o salto real é de ~250 peças primitivas por boss para superfícies contínuas com
    relevo, cor por vértice e milhares de faces. Modelos esculpidos à mão e texturizados (3D Importer) ainda
    seriam o próximo nível.
- **Ataques Assinatura — o que ainda precisa do Studio:** os efeitos visuais foram executados no simulador (todos os
  estilos rodam e limpam as peças), mas não vistos na tela; o equilíbrio de dano em partidas reais.
- **Árvore-Santuário — o que ainda precisa do Studio:** subir a rampa, a escada e os galhos com o personagem real
  (o simulador confere geometria, inclinação, altura livre e o elevador, mas não a física do Humanoid), a sombra da copa
  e o desempenho das ~4.800 peças a mais.
- Não há som.
- O modelo de peças antigo (~70 peças por pet) continua sendo criado no servidor, porque é ele que segue o dono e
  luta; no cliente ele fica invisível quando a malha está pronta.
- Com a mata, a Verdant Haven tem ≈ 12.800 peças e o Whispering Wilds ≈ 9.500 (todas ancoradas, sem
  colisão nas copas). Confira o FPS no celular; se pesar, aumente `cell` em `WorldBuilder.Ring` (menos árvores)
  ou ligue o StreamingEnabled (ver acima).
  Os efeitos de partícula não aparecem nas prévias, só no jogo.
- As prévias em `docs/preview/` são renderizadas fora do Roblox: não mostram a grama animada, as texturas
  dos materiais, as nuvens nem a Atmosphere reais.
- O PathfindingService real não foi exercitado (no simulador sempre cai na rota alternativa).
- Anúncios globais dependem do MessagingService (limites do Roblox). O código limita a publicação a 10 por
  minuto por servidor.

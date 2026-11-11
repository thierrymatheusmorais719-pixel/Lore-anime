# Gojo vs Sukuna: guia de animação no Blender para o Roblox

Guia de produção para animar do zero uma luta estilo anime entre dois rigs R15 no Blender
(4.2 LTS ou 5.x) e levá-la para o Roblox Studio / Moon Animator 2 sem perder tempo nem impacto.

Ferramentas incluídas neste repositório:

| Ficheiro | Para que serve |
|---|---|
| `tools/blender/roblox_cutscene_export.py` | Bake + export de **um .fbx por rig e por clip**, mais um ModuleScript com câmera, FOV, cortes e eventos |
| `tools/roblox/CutscenePlayer.lua` | ModuleScript que toca os dois rigs em sincronia, conduz a câmera e dispara os eventos de VFX |

> **Referência visual (o vídeo enviado, 64 s a 60 fps):** a edição alterna paletas por personagem
> (vermelho/carmim para o Sukuna, azul/violeta para o Gojo), usa *impact frames* em preto e branco
> invertido, tramas de mangá sobre a imagem, *close-ups* das mãos nos selos e um plano dedicado à
> esfera roxa sobre fundo em espiral. O guia usa essa linguagem como alvo.

> **Direitos de autor:** Gojo e Sukuna pertencem a Gege Akutami/Shueisha. Para estudo e fan-art
> não publicada, sem problema. Num jogo público ou monetizado no Roblox, modelos com o aspeto e o
> nome deles podem ser moderados ou retirados por pedido DMCA. Se o jogo for a sério, use
> personagens originais com o mesmo tipo de poderes.

---

## 0. Restrições do Roblox que mandam em tudo

Conheça isto antes de animar, ou vai refazer trabalho:

1. **Partes R15 são rígidas.** Uma animação Roblox só guarda rotação e posição (CFrame) de cada
   junta. **Não há escala por bone**: *squash & stretch* real não chega ao jogo. Dá para o
   simular (secção 2.4).
2. **O HumanoidRootPart não se anima.** A junta `Root` liga o `HumanoidRootPart` ao `LowerTorso`.
   A animação move o `LowerTorso` em relação ao HRP. Todo o deslocamento do corpo (avançar,
   saltar, ser projetado) é chave no **LowerTorso**. O bone `HumanoidRootPart` fica parado.
3. **Mãos R15 não têm dedos.** Para selos de mão é preciso um rig com bones de dedos
   (secção 1.3).
4. **Câmera, VFX, materiais e shape keys não entram pelo FBX de animação.** Animação de câmera e
   eventos de efeito saem por outro caminho: o script exporta-os para Luau.
5. **Cada personagem é uma animação separada.** Dois rigs geram dois FBX por clip, sincronizados
   pelo mesmo frame inicial e pela mesma origem de cena.

---

## 1. Setup da cena e rigging

### 1.1 Projeto e cena

1. **Output Properties → Frame Rate: 60 fps.** O vídeo de referência é 60 fps e o jogo roda a
   60. Animar a 30 e exportar a 60 também funciona, mas mantenha um único fps do início ao fim.
   Nunca use *Time Stretching* para mudar fps depois de animar.
2. **Resolução 1920×1080 (16:9)**, a mesma proporção do ecrã do jogador. O script calcula o FOV
   vertical do Roblox a partir disto.
3. **Unidades:** deixe Metric com Unit Scale 1. A conversão para studs fica num único número
   (`studs_per_unit` no script). Para o medir, um R15 padrão tem cerca de 5,2 studs de altura,
   portanto `studs_per_unit = 5.2 / altura_do_rig_no_blender`.
4. **Um Empty `SCENE_ORIGIN`** no centro da arena. No Roblox crie uma Part ancorada
   `SceneOrigin` no mesmo ponto. Rigs e câmera são exportados relativamente a ela, por isso a
   luta pode ser colocada em qualquer lugar do mapa.
5. **Coleções:** `RIG_GOJO`, `RIG_SUKUNA`, `CAMERAS`, `VFX`, `CENARIO`, `REF` (vídeo de
   referência num plano, ou como fundo de câmera).
6. **Preferências → Animation → Default Interpolation: Constant** durante o *blocking*.

### 1.2 Rig R15 compatível com o Roblox

O FBX só funciona se os **nomes e a hierarquia dos bones** forem iguais aos do personagem no
Studio:

```
HumanoidRootPart
└─ LowerTorso
   ├─ UpperTorso
   │  ├─ Head
   │  ├─ LeftUpperArm → LeftLowerArm → LeftHand
   │  └─ RightUpperArm → RightLowerArm → RightHand
   ├─ LeftUpperLeg → LeftLowerLeg → LeftFoot
   └─ RightUpperLeg → RightLowerLeg → RightFoot
```

Duas formas de obter este rig:

- **Recomendado:** use os ficheiros de referência de personagem R15 que a Roblox publica no
  Creator Hub (secção de *Characters / reference files*). Já vêm com armature, nomes e
  orientação certos para o importador.
- **A partir do Studio:** *Avatar → Rig Builder → R15*, selecione o rig e use
  *Export Selection* para .fbx. Importe no Blender e confirme que os nomes dos bones batem com a
  árvore acima.

Antes de animar, faça o **teste de ida e volta**: 10 frames a rodar só o `RightUpperArm` 90°,
export, import no Studio. Se o braço rodar no eixo certo, a pipeline está validada. Só depois
comece a animar a sério.

Regras do rig de deformação (DEF):

- Bones **sem escala** e sem *Inherit Scale* a mudar ao longo da animação.
- **Não renomeie** nem reparente os bones DEF.
- Marque como *Deform* apenas os bones que existem no Studio. O script exporta só bones *Deform*.

### 1.3 Rig de controlo para artes marciais (CTRL)

Animar diretamente no DEF serve para poses simples. Para taijutsu rápido monte uma camada de
controlo **na mesma armature**, com bones `CTRL_*` sem *Deform*, e prenda os DEF com
*Copy Transforms*:

| Controlo | Tipo | Porquê |
|---|---|---|
| `CTRL_root` (no chão) | posição + rotação global | desloca o corpo todo; o DEF `LowerTorso` copia-o |
| `CTRL_hips` | FK | rotação da anca, a origem de todo soco com peso |
| `CTRL_chest` | FK | torção do tronco: a anca roda primeiro e o peito vem 1–2 frames depois |
| `CTRL_foot.L/R` + `pole_knee.L/R` | **IK** | pés pregados no chão durante trocas de golpes |
| `CTRL_hand.L/R` + `pole_elbow.L/R` | **IK/FK switch** | FK para socos em arco; IK para bloqueios, agarrões e mão no chão |
| `CTRL_head` | FK com *Child Of* ao peito | *head-snaps* nos impactos |

Detalhes:

- **IK/FK switch** com uma custom property (`ik_fk_arm_L` de 0 a 1) a controlar a *influence*
  das constraints. Chave essa propriedade em **Constant** no frame da troca, para o braço não
  "deslizar".
- **Pés:** dê ao `CTRL_foot` um *Limit Location* com Z ≥ 0 para evitar atravessar o chão.
- **Os golpes atravessam os oponentes:** em lutas rápidas é normal. Corrija só o que a câmera
  mostra.
- Na exportação o script faz *visual bake* dos DEF (resolve IK e constraints), silencia as
  constraints, exporta e repõe tudo. O control rig nunca vai para o FBX.

### 1.4 Selos de mão (hand seals)

O selo do **Vazio Incomensurável** (Gojo: indicador e médio cruzados, mão erguida) e o
**Enmaten** do **Santuário Malevolente** (Sukuna: as duas mãos juntas em forma de santuário)
precisam de dedos. Três opções, da mais simples à mais completa:

1. **Troca de malha da mão.** Modele 4–6 mãos fixas (aberta, punho, faca, selo do Gojo, metade
   esquerda e metade direita do Enmaten). No Roblox troque o `MeshId` (ou a visibilidade de
   Accessories na mão) por evento `FACE:`/`EVT:` no frame do selo. É o método mais usado em
   jogos de anime no Roblox, porque é barato e fica nítido.
2. **Bones de dedos num MeshPart com skinning.** A mão passa a ter bones (`Index1..3`,
   `Middle1..3`...) como filhos de `RightHand`. O Roblox suporta animação de `Bone` vinda de FBX
   desde que os nomes batam com o modelo. Mais trabalho no rigging, mas permite transições
   animadas.
3. **Só no Blender (cinemática renderizada).** Se o plano do selo for vídeo pré-renderizado, use
   o rig de dedos completo e esqueça as limitações.

Técnica de animação do selo:

- **Pose library / Asset Browser:** guarde cada selo como *Pose Asset* (botão direito → *Mark as
  Asset*). Aplicar a pose em vez de a refazer garante o mesmo selo em todos os planos.
- Os dedos **chegam fora de tempo**: polegar → indicador → restantes, com 1–2 frames entre cada.
  Selos em que todos os dedos fecham no mesmo frame parecem de robô.
- **Selo = pausa.** Mantenha 8–15 frames (a 60 fps) quase imóvel, só com 1–2° de tremor nos
  dedos. É o momento que a câmera vai cortar para close-up.

### 1.5 Posturas de combate

- **Gojo:** postura descontraída e arrogante. Mão no bolso ou braços soltos, peso numa perna,
  ombros caídos, cabeça ligeiramente inclinada. Os golpes saem desse relaxamento sem
  antecipação longa: ele não precisa de se esforçar.
- **Sukuna:** postura larga e predatória. Joelhos fletidos, tronco à frente, braços abertos,
  queixo baixo e olhar por cima. Antecipações curtas mas muito carregadas, e sorriso.
- **Linha de ação:** em cada pose-chave trace mentalmente uma curva C ou S da cabeça ao pé de
  apoio. Use *Viewport → Overlays → Bones off* e veja a silhueta a preto (Workbench, cor *Single*,
  preto). Se o golpe não se lê em silhueta, a pose não está pronta.

### 1.6 Expressões faciais

Uma cabeça R15 clássica não tem rig facial. Opções:

- **Decals/texturas trocadas (estilo anime, recomendado).** Crie um atlas de olhos e bocas
  (neutro, sorriso arrogante, olhos abertos com íris brilhante, grito, sangue a escorrer). No
  Blender pré-visualize-o com um *Image Texture* cuja seleção é feita por uma custom property
  `face_id` no rig, chaveada em Constant. Para o Roblox marque a troca com um marcador
  `FACE:Gojo:olhos_abertos`. O `CutscenePlayer` recebe-o em `onEvent` e troca a `Decal`/
  `TextureID`.
- **Dynamic Heads (FACS).** O Roblox anima cabeças dinâmicas com *FaceControls*. Dá para chavear
  no Animation Editor depois de importar o corpo. É mais realista e menos "anime".
- **Olhos brilhantes (Gojo sem venda):** um `PointLight` pequeno e uma `Decal` emissiva com
  `ParticleEmitter` de brilho, ligados por evento.

---

## 2. Animação de combate corpo a corpo (taijutsu)

### 2.1 Método: do beat sheet ao polish

1. **Beat sheet.** Antes de tocar no Blender, escreva a troca em linhas com tempo:
   ```
   00.00  Gojo avança (teleporte curto)        | Sukuna em guarda
   00.30  Gojo jab esquerdo → Sukuna bloqueia  | IMPACTO 1
   00.50  Sukuna gancho direito → Gojo esquiva
   00.75  Gojo joelhada no estômago            | IMPACTO 2 (forte)
   01.10  Sukuna projetado 4 m, desliza        | câmera treme
   ```
2. **Thumbnails** em papel ou Grease Pencil: 1 desenho por linha, só linha de ação.
3. **Blocking em Constant (stepped).** Só poses-chave nos dois personagens: guarda, antecipação,
   contacto, *follow-through*, recuperação.
4. **Breakdowns.** Adicione poses intermédias que definem o arco (2.3).
5. **Spline + polish.** Mude para Bézier e limpe no Graph Editor. Overlap: cabelo, roupa e a mão
   relaxada chegam 1–3 frames depois.
6. **Stepped final (opcional, muito anime).** Volte a *Constant* com chaves a cada 2 ou 3 frames
   ("animar em 2s/3s"), mas mantenha os frames de impacto e de *smear* em 1s. O script
   exporta em Constant e preserva isso no Roblox.

### 2.2 Troca de golpes sincronizada

A regra de ouro: **o frame de contacto é partilhado.** O frame em que o punho do Gojo atinge a
guarda do Sukuna é o mesmo frame em que a guarda do Sukuna cede.

- Anime **os dois rigs na mesma cena e no mesmo timeline.** Nunca anime um personagem num
  ficheiro e o outro noutro.
- Marque cada contacto com um marcador (`M` no timeline) chamado `SHAKE:forte`, `VFX:impacto`
  ou `SFX:soco`. Servem de guia e são exportados como eventos.
- **Ação → reação:** quem bate tem a antecipação; quem recebe reage **1 frame depois** do
  contacto (60 fps), com o corpo a mover-se no sentido da força: cabeça primeiro, depois peito,
  depois anca.
- **Ritmo:** alterne rápido-rápido-LENTO. Três socos de 6 frames e uma pancada final com
  antecipação de 12 frames e *hit-stop* parecem muito mais fortes do que dez golpes iguais.

Timing de referência a 60 fps (divida por 2 para 30 fps):

| Golpe | Antecipação | Ação até ao contacto | Hit-stop (pausa no contacto) | Follow-through + recuperação |
|---|---|---|---|---|
| Jab | 3–4 f | 2–3 f | 2–3 f | 6–10 f |
| Direto/cruzado com peso | 6–10 f | 3–4 f | 4–6 f | 10–16 f |
| Pontapé circular | 8–12 f | 4–5 f | 4–6 f | 14–20 f |
| Golpe final (projeção) | 14–24 f | 2–3 f | 8–12 f (com impact frame) | 20–40 f |
| Bloqueio (quem defende) | 2–3 f antes do contacto | — | partilhado | recua 6–10 f |

**Hit-stop:** nos frames de contacto os dois corpos ficam quase parados, com só 1–2 cm de
vibração no `LowerTorso` de quem recebe. Em conjunto com o *camera shake* e o flash é o que vende
o peso.

### 2.3 Arcos de movimento

- *Pose Mode → selecione `RightHand` → Pose → Motion Paths → Calculate* (range = cena). Mostra o
  caminho do punho.
- **Socos não são retas.** O punho sai num arco ligeiro de baixo para cima e roda no fim
  (corkscrew). A anca roda primeiro e o ombro avança depois.
- **Pontapés** desenham um arco grande na horizontal. O pé de apoio roda no chão (pivot no
  calcanhar ou na ponta, via IK).
- Corrija pelo arco, não pelas curvas. Se o caminho tem bicos ou dentes, falta um breakdown.
- Para ver o arco do corpo inteiro ative também *Motion Paths* no `CTRL_root` e no `CTRL_head`.
  A cabeça deve desenhar uma onda suave mesmo em golpes violentos.

### 2.4 Antecipação, squash & stretch e impacto (dentro do limite do R15)

Sem escala nos bones, o *squash & stretch* simula-se com:

1. **Pose.** Antes do soco o corpo comprime (anca baixa, ombros encolhidos, braço recolhido
   atrás). No contacto o corpo estica: braço totalmente estendido, ombro projetado, perna de trás
   esticada. Comprimido → esticado é o *squash & stretch* do corpo rígido.
2. **Overshoot.** Leve o braço 5–10° além do natural no frame a seguir ao contacto e regresse.
   O `LowerTorso` de quem recebe "dobra" além do equilíbrio.
3. **Smear frames.** No frame entre antecipação e contacto deslize o `UpperArm`/`LowerArm` à frente
   (na Constant o olho preenche o resto) e acrescente um *smear mesh*: um plano curvo com
   gradiente alfa no caminho do punho, visível 1–2 frames. No Roblox isso vira um `Trail` nos
   `Attachment` da mão, ou um MeshPart ativado por evento `VFX:smear`.
4. **Impact frame.** 2–3 frames de imagem invertida (preto e branco ou duotom). No Blender use o
   compositor: *Invert* + *Color Ramp* com Mix chaveado em 0/1. No Roblox use `ColorCorrection`
   (`Saturation = -1`, `Contrast = 1`, `TintColor`) ligado e desligado pelo evento `VFX:impact_frame`.
5. **Camera shake.** Na câmera do Blender: modificador *Noise* no F-Curve da rotação, com
   *Influence* chaveada (0 → 1 → 0 em 6–10 frames). Como a câmera é exportada frame a frame, o
   shake chega ao Roblox automaticamente.

---

## 3. Efeitos visuais e técnicas especiais (VFX)

**Divisão de trabalho:** no Blender faz-se o timing e o look de referência. No Roblox o VFX é
reconstruído com `ParticleEmitter` (com flipbooks), `Beam`, `Trail`, `MeshPart` com `Neon`/
`ForceField`, `PointLight`, `Highlight` e `ColorCorrection`/`Bloom`. O que liga os dois são os
**marcadores de evento** exportados pelo script.

### 3.1 Roxo Vazio (Hollow Purple)

Coreografia (cerca de 3 s a 60 fps):

| Frames | Ação | Corpo | Câmera |
|---|---|---|---|
| 0–40 | **Azul** (atração) aparece na mão esquerda estendida | braço esquerdo à frente, ombros abertos | plano médio, lento push-in |
| 30–70 | **Vermelho** (repulsão) aparece na mão direita | braço direito à frente | corte para close-up da mão direita |
| 70–110 | As duas esferas aproximam-se e orbitam | mãos convergem à frente do peito | dolly circular de 90° em volta do Gojo |
| 110–125 | **Fusão → roxo**, flash branco 2 f | hit-stop total | close no rosto, olhos brilhantes |
| 125–150 | Esfera roxa cresce, distorção no ar | mão direita aponta (gesto do vídeo: indicador estendido, esfera na ponta do dedo) | *dolly zoom* |
| 150–180 | **Disparo** | recuo do ombro pelo coice | câmera segue a esfera, tudo no caminho apaga-se |

Construção no Blender (EEVEE):

1. **Núcleo:** UV Sphere com material *Emission* (força 20–50), cor `#B04CFF`. Por cima, uma
   segunda esfera ligeiramente maior com *Layer Weight → Fresnel* a controlar Mix entre
   *Transparent* e *Emission*, para a borda brilhar e o centro ficar escuro (o anel do vídeo).
2. **Turbulência:** *Noise Texture* animada (W ligado a `#frame/30`) no Displacement ou na
   máscara de cor. Dá a superfície de energia instável.
3. **Esferas azul e vermelha:** a mesma receita com `#3A7BFF` e `#FF2A3A`. Na fusão, chave a cor
   das duas para roxo e a escala de uma delas para 0.
4. **Espiral de fundo:** um plano grande atrás com *Wave Texture* em modo *Rings* deformada por
   *Twist* (Simple Deform). Roda o *Mapping* ao longo do tempo para a espiral roxa do vídeo.
5. **Partículas a ser sugadas:** Geometry Nodes, pontos numa esfera grande que interpolam para o
   centro (*Mix* posição → centro com fator = tempo), com tamanho a diminuir. No Roblox um
   `ParticleEmitter` com `Speed` negativo, ou emissão numa casca esférica com `Acceleration` para
   o centro.
6. **Disparo:** escale a esfera ao longo do eixo de tiro e use *Shape Key* ou *Simple Deform →
   Stretch* para um rasto. Atrás, um cilindro com material de distorção (refração no EEVEE) apaga
   o cenário: chave a visibilidade dos objetos atingidos com um *Boolean* animado.
7. **Glow:** no Blender 4.2+ o bloom é feito no compositor. Use *Glare* (Fog Glow ou Bloom),
   *threshold* 1 e *mix* 0. Para o look do vídeo acrescente um *Color Balance* para empurrar
   sombras para violeta.

No Roblox:

- Esferas = `Part` esférica `Neon` (núcleo) + `Part` maior com `ForceField` (borda), `PointLight`
  roxo com `Range` animado e `ParticleEmitter` com flipbook de energia.
- **Flipbook:** renderize no Blender a esfera isolada (fundo transparente, 16 frames), monte uma
  folha 4×4 (por exemplo com o add-on *Sprite Sheet Maker*, ou ImageMagick
  `montage -tile 4x4 -geometry +0+0 frame_*.png sheet.png`) e use em
  `ParticleEmitter.FlipbookLayout = Grid4x4`.
- Eventos sugeridos: `VFX:blue_on`, `VFX:red_on`, `VFX:purple_merge`, `VFX:impact_frame`,
  `VFX:purple_fire`, `SHAKE:extremo`.

### 3.2 Desmantelar e Clivar (Dismantle / Cleave)

- **Desmantelar** = cortes à distância, lâminas invisíveis que se veem pelo rasto e pelo que
  cortam.
- **Clivar** = cortes ajustados ao alvo, uma grelha rápida de cortes no corpo atingido.

Construção da lâmina (Blender):

1. Plano estreito (por exemplo 4 × 0,08 m) com *Simple Deform → Bend* para curvar em crescente.
2. Material: *Emission* branco no centro e vermelho/preto nas bordas, com *Gradient Texture* no
   alfa (pontas transparentes). Para o "corte no ar", outro plano igual com refração sobreposto.
3. **Animação de "rasgo":** *Mapping → Location X* de −1 a +1 em 3–4 frames. A linha
   desenha-se de uma ponta à outra em vez de aparecer inteira. Ao terminar fica 2 frames e
   desvanece em 4.
4. **Rajada:** duplique 10–20 lâminas com rotações aleatórias à volta do alvo (*Array* + *Object
   Offset* com Empty rodado, ou Geometry Nodes *Instance on Points* com rotação aleatória) e
   desfase a animação 1 frame entre cada (no Dope Sheet, *Offset* em escada).
5. **Linhas de corte no cenário:** Grease Pencil com traço fino preto e vermelho por cima dos
   prédios, chaveado a 1 frame por linha. Em seguida os blocos cortados deslizam com Cell Fracture
   ou com cortes Boolean manuais e simulação Rigid Body cozinhada (*Bake to Keyframes*).
6. **Clivar no corpo:** 6–8 lâminas curtas num padrão de grelha à frente do alvo, todas em 6
   frames, seguidas de 2 impact frames vermelhos e de partículas de "sangue" estilizadas em
   formas de manchas de tinta (o vídeo usa manchas planas vermelhas, não sangue realista).

Gesto do Sukuna: movimento de "corte" com dois dedos ou com a mão aberta em faca. A antecipação
é muito curta (3–4 f) e o *follow-through* longo. A mão "passa" e o efeito chega 2 frames depois:
o atraso faz parecer que o corte viajou.

No Roblox: `Beam` entre dois `Attachment` com `Texture` de lâmina e `TextureLength`/`TextureSpeed`
para o rasgo, ou `MeshPart` da lâmina com `Transparency` em `TweenService`. Rajadas geradas por
script com `task.delay(i/60, ...)`. Marque `VFX:dismantle_burst` e `VFX:cleave_grid`.

### 3.3 Câmeras dinâmicas e expansão de domínio

Configuração das câmeras:

- Uma câmera por plano (`CAM_010`, `CAM_020`...). Troque entre elas com *Bind Camera to Markers*
  (`Ctrl+B` com a câmera selecionada e o marcador no frame do corte). O script deteta a câmera
  ativa em cada frame e marca o **corte**, para o Roblox não interpolar entre planos.
- Para movimentos orgânicos, ponha a câmera como filha de um Empty `CAM_rig`: o Empty faz o
  percurso (*Follow Path* numa curva) e a câmera faz o shake e o *aim* (*Damped Track* a um Empty
  alvo).
- **Lente:** grande-angular (14–24 mm) muito perto para ação e violência. Teleobjetiva (85–135 mm)
  para encaradas e selos. O FOV é exportado por frame.

Receita de ativação do domínio (cerca de 4–5 s):

1. **Selo (close-up das mãos):** 85 mm, câmera quase parada, ligeiro *push-in*. Fundo escurece
   (chave a *World Strength* ou uma esfera preta que cresce). Evento `FACE:...` para a expressão.
2. **Falar o nome:** plano do rosto em contraluz. *Dolly zoom* (efeito vertigo): afaste a câmera
   enquanto aumenta a distância focal (por exemplo de 24 mm a 70 mm em 40 frames) para manter o
   rosto do mesmo tamanho enquanto o fundo "estica".
3. **Explosão do domínio:** esfera gigante invertida (normais para dentro) que cresce a partir
   do utilizador e engole a câmera. Na passagem pela câmera dê 2 frames de branco (Gojo) ou de
   vermelho (Sukuna).
4. **Revelação:** grande plano geral, câmera a subir em grua e a rodar à volta do dono do
   domínio.

**Vazio Incomensurável (Gojo):** espaço infinito. Mundo preto com estrelas (Geometry Nodes:
milhares de pontos com emissão e tamanhos aleatórios), um "horizonte" de luz branca e partículas
de informação a voar em direção à vítima. Paleta azul, branco e violeta. A vítima fica imóvel,
por isso pose congelada e só os olhos a tremer.

**Santuário Malevolente (Sukuna):** céu vermelho/sangue, água escura no chão (plano com
*Principled* de *roughness* baixo), o santuário com crânios atrás. Câmera baixa (*contre-plongée*)
para mostrar escala. Em seguida a **rajada de cortes contínuos**: dezenas de lâminas da secção
3.2 em loop e linhas de corte em todo o cenário.

No Roblox a troca de ambiente é feita por eventos:

| Evento | O que o `onEvent` deve fazer |
|---|---|
| `VFX:domain_gojo` | `Lighting.ClockTime`/`Sky` para céu preto estrelado, `Atmosphere.Density` 0, `ColorCorrection.TintColor` azul, esfera `MeshPart` invertida a crescer com `TweenService` |
| `VFX:domain_sukuna` | `Sky` vermelho, `Atmosphere.Color` vermelho, `ColorCorrection.Contrast` alto, clonar o modelo do santuário para a `SceneOrigin` |
| `VFX:domain_flash` | `Frame` branco/vermelho em ecrã inteiro com transparência 0 → 1 em 0,1 s |

---

## 4. Exportação das animações

### 4.1 Organizar o timeline

- **Uma cena contínua** com os dois rigs, dividida em **clips** por intervalo de frames:
  ```
  001–240   01_taijutsu
  241–420   02_hollow_purple
  421–600   03_dismantle_cleave
  601–900   04_dominios
  ```
- Cada clip deve **começar e acabar numa pose que se possa ligar** à seguinte (ou a um corte de
  câmera).
- Deixe **2–4 frames de "handle"** antes e depois de cada clip, para o blend do Roblox não comer
  a antecipação.
- Clips curtos (até cerca de 10–20 s) carregam mais depressa, são mais fáceis de reaproveitar e
  evitam o limite de duração no upload de animações.
- **Marcadores** com os prefixos `VFX:`, `FACE:`, `SFX:`, `SHAKE:`, `FX:` e `EVT:` viram eventos.
  Os outros (por exemplo os de *bind camera*) são ignorados.

### 4.2 Correr o script de exportação

1. Abra `tools/blender/roblox_cutscene_export.py` no *Text Editor* do Blender.
2. Ajuste `CONFIG`: nomes dos rigs, lista de clips, `studs_per_unit` e `scene_origin`.
3. `Alt+P` (ou em linha de comando:
   `blender cena.blend --background --python tools/blender/roblox_cutscene_export.py`).
4. Resultado em `export_roblox/` ao lado do .blend:
   ```
   01_taijutsu__GOJO_RIG.fbx
   01_taijutsu__SUKUNA_RIG.fbx
   01_taijutsu__CutsceneData.lua
   02_hollow_purple__GOJO_RIG.fbx
   ...
   ```

O script faz por si, para cada rig e clip:

- **Visual bake** das deform bones (resolve IK e constraints), 1 chave por frame;
- **Desloca a action para começar no frame 0**, assim o tempo 0 do Roblox é o primeiro frame do
  clip;
- **Interpolação Constant** (com 1 chave por frame, preserva os 2s/3s e os snaps);
- Exporta com `bake_anim_simplify_factor = 0`. **Este é o ponto mais importante:** o valor padrão
  (1.0) suaviza curvas e mata hit-stops e snaps de 1 frame;
- `add_leaf_bones = False` (bones `_end` partem o mapeamento de nomes), *Deform only*, eixos
  `-Z forward / Y up`, sem NLA e sem "All Actions";
- Repõe a sua action, as constraints e o range da cena.

Para exportar à mão, as definições equivalentes do FBX são: *Selected Objects*, *Armature*,
*Apply Scalings: All Local* (o mesmo que o script usa; troque só se o teste de ida e volta pedir), *Forward −Z*,
*Up Y*, *Only Deform Bones* ✓, *Add Leaf Bones* ✗, *Bake Animation* ✓, *NLA Strips* ✗,
*All Actions* ✗, *Force Start/End Keying* ✓, *Sampling Rate 1*, *Simplify 0*.

### 4.3 Importar no Roblox Studio

1. Coloque os dois rigs (com `Humanoid` + `Animator`, HRP **ancorado**) no Workspace e defina o
   **Pivot** de cada modelo no chão entre os pés (*Model → Edit Pivot*).
2. *Avatar → Animation Editor*, selecione o rig do Gojo.
3. Menu `⋯` → *Import → From FBX Animation* → `01_taijutsu__GOJO_RIG.fbx`.
4. Confira: duração, fps (*Settings* do editor → a mesma taxa do Blender) e se não há juntas
   "partidas". Uma junta parada indica um nome de bone que não bate.
5. Se precisar de eventos dentro da própria animação, adicione *Animation Events* aqui
   (por exemplo para `GetMarkerReachedSignal`). Os eventos do script já chegam pelo `.lua`.
6. *Publish to Roblox* e anote o **Asset ID**.
7. Repita para o Sukuna, no mesmo clip.

### 4.4 Moon Animator 2

O Moon Animator 2 usa ficheiros de animação próprios, e a importação direta de FBX não é o
caminho fiável. O fluxo que funciona:

1. Importe o FBX no **Animation Editor nativo** (4.3) e guarde/exporte o resultado como
   `KeyframeSequence` (fica em `ServerStorage.RBX_ANIMSAVES`), ou publique e use o ID.
2. No Moon Animator 2, abra o rig e use a importação de animação (a partir do
   `KeyframeSequence`/ID do Roblox; o nome exato da opção muda entre versões).
3. Use o Moon para o que ele faz melhor: **câmera** (se preferir refinar no Studio em vez de usar
   o `.lua` do Blender), **eventos sincronizados** e ajuste de **easing** por chave.
4. Mantenha a mesma taxa de frames do Blender no projeto do Moon. Os tempos ficam em segundos,
   e um fps diferente faz as chaves cair entre frames.

### 4.5 Tocar a cena no jogo (`CutscenePlayer.lua`)

1. Copie `CutscenePlayer.lua` para `ReplicatedStorage/Cutscene` como **ModuleScript**.
2. Copie cada `*__CutsceneData.lua` para `ReplicatedStorage/Cutscene/Data` como ModuleScript
   (com o mesmo nome).
3. Num **LocalScript**:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CutscenePlayer = require(ReplicatedStorage.Cutscene.CutscenePlayer)
local data = require(ReplicatedStorage.Cutscene.Data["02_hollow_purple__CutsceneData"])

local opts = {
	origin = workspace.Arena.SceneOrigin.CFrame,
	rigs = { GOJO_RIG = workspace.Gojo, SUKUNA_RIG = workspace.Sukuna },
	animations = {
		GOJO_RIG = "rbxassetid://ID_DO_GOJO",
		SUKUNA_RIG = "rbxassetid://ID_DO_SUKUNA",
	},
	onEvent = function(name: string)
		if name == "VFX:impact_frame" then
			local cc = Lighting:FindFirstChild("ImpactCC") :: ColorCorrectionEffect
			cc.Enabled = true
			task.delay(2 / 60, function() cc.Enabled = false end)
		elseif name == "VFX:purple_fire" then
			-- ativar esfera, beam, partículas...
		end
	end,
}

local tracks = CutscenePlayer.preload(data, opts) -- durante o loading
CutscenePlayer.play(data, opts, tracks)
```

**Teste de calibração (faça uma vez):** no Blender ponha uma câmera atrás do Gojo a olhar para o
Sukuna e exporte um clip de 30 frames. No Roblox a câmera tem de aparecer atrás do Gojo. Se
aparecer do lado oposto (de frente para ele), mude `flip_front = True` no `CONFIG` do script. Se
aparecer longe ou perto demais, corrija `studs_per_unit`.

### 4.6 Checklist final

- [ ] fps do Blender = fps do Animation Editor/Moon (60)
- [ ] Nomes dos bones DEF = nomes das partes R15 no Studio, sem `_end`
- [ ] `HumanoidRootPart` sem chaves; deslocamento todo no `LowerTorso`
- [ ] Nenhum bone com escala animada
- [ ] Simplify = 0 no export; hit-stops e snaps de 1 frame visíveis no Studio
- [ ] Os dois FBX do mesmo clip têm exatamente a mesma duração
- [ ] Pivot dos modelos no chão; `SceneOrigin` no Roblox = `SCENE_ORIGIN` no Blender
- [ ] Teste de calibração da câmera feito
- [ ] Eventos (`VFX:`, `FACE:`, `SFX:`, `SHAKE:`) aparecem na lista `events` do `.lua`

# Mugetsu — transformação cinematográfica (Roblox)

Projeto **novo e independente** (pasta `roblox-mugetsu/`; o projeto WebGL "Lore" na raiz do repositório
não foi tocado). Experiência inspirada em Bleach: o jogador aperta **G**, Ichigo vira **Mugetsu** numa
cutscene de 30 s coreografada a partir do vídeo de referência, e ganha a habilidade **Getsuga Tenshō
Negro** (tecla **F**) com telegraph, cooldown e dano validados no servidor.

> **Leia antes:** este código foi escrito **sem Roblox Studio** (ambiente de nuvem). Foi verificado por
> compilação Luau, testes unitários e uma simulação do servidor — **não foi executado no Studio**.
> Visual, câmera e sincronia de animação precisam de uma passada sua no Studio (seção "Testes manuais").
> Detalhes honestos em "Limitações".

## Como rodar

**Mais rápido:** abra `Mugetsu.rbxlx` (já gerado com `rojo build`, 26 scripts nas classes corretas) no Studio.

**Com Rojo (para editar)**
```bash
cd roblox-mugetsu
rojo build -o Mugetsu.rbxlx      # ou: rojo serve  + plugin Rojo no Studio
```
Abra `Mugetsu.rbxlx` no Studio → **Play** (ou *Start Server* + 2 clientes para multiplayer).
O avatar precisa ser **R15** (Game Settings → Avatar → R15, ou avatar R15 no Studio).

**Sem Rojo:** crie manualmente `ReplicatedStorage/Mugetsu` ← `src/shared`, `ServerScriptService/MugetsuServer`
← `src/server` (`Main.server.luau` = Script), `StarterPlayerScripts/MugetsuClient` ← `src/client`
(`Main.client.luau` = LocalScript). Os demais arquivos são ModuleScripts com o mesmo nome.

Controles: **G** transformar · **F** Getsuga · botões na tela (também no celular). Tudo configurável em
`src/shared/Config.luau` (teclas, cooldowns, dano, alcance, qualidade).

## Coreografia (do vídeo de referência → `src/shared/Timeline.luau`)

| Vídeo (≈) | Plano no vídeo | Timeline (s) | Implementação |
|---|---|---|---|
| 0–2 | costas, espada baixa | 0–2.6 Fase 1 | câmera aproxima por trás, iluminação fria, ducking do ambiente, aura sussurrada |
| 2–4 | close na lâmina | 2.6–5 | corte para a espada, brilho na ponta (`SwordGlint`) |
| 4–8 | pose frontal | 5–9.2 Fase 2 | órbita de 110° ao redor, `Concentrate`, fragmentos do chão, pulsos de luz, onda de pressão |
| 8–12 | close nos olhos, reiatsu azul | 9.2–12 | aproximação em Expo, luz azul no rosto |
| 12–16 | pilar de luz azul, máscara | 12–17 Fase 3 | cenário noturno, pilar (neon), fragmentos brancos convergem para o rosto |
| 16–20 | flash branco, tentáculos negros | 16.6–19 | fade branco; **troca real de modelo no servidor dentro do branco (17.4 s)**; fitas negras (Beams) |
| 20–24 | Mugetsu emerge, golpe | 19–26 Fase 4 | whip de câmera, flash, shockwave, anéis, estilhaços, trail negro/branco na espada, cenário reage, impact frame |
| 26–32 | olho vermelho, blackout | 26–30 Outro | fade preto, iluminação "Mugetsu" (alto contraste), close do olho |

Tempo é do **servidor** (`Workspace:GetServerTimeNow`): servidor e todos os clientes consomem a mesma
lista de eventos, sem timers independentes por efeito.

## Arquitetura

```
src/shared   (ReplicatedStorage.Mugetsu)   Config · Timeline · StateMachine · AbilityMath · PoseDriver
                                            Remotes · AssetManifest · Maid
src/server   (ServerScriptService)          Main · TransformationService · AbilityService · ModelKit
                                            ArenaBuilder · RateLimiter
src/client   (StarterPlayerScripts)         Main · CutsceneController · CameraDirector · VFX · PoseApplier
                                            LightingDirector · AudioDirector · Hud · InputController
                                            AbilityClient · HairSway · Quality
tests/                                      run.mjs · unit.luau · sim_env.luau · sim_server.luau · mocks.luau
```
* **Servidor autoritativo:** valida pedido (R15, vivo, cooldown, rate limit), trava movimento
  (WalkSpeed/Jump/AutoRotate/Anchored + ForceField), executa `MorphSwap`/`EnableAbility`, e **sempre**
  restaura (fim, morte, saída, remoção do personagem, watchdog de Duração+6 s).
* **Cliente:** máquina de estados (`Idle→Starting→Running→Climax→Finishing`, `Cancelled`), câmera
  exclusiva (planos por pontos de referência + órbita + tremor determinístico), HUD/letterbox, VFX em
  pool com laço único e `Session:clean()`. Qualquer erro em handler é capturado; qualquer saída passa por
  `teardownOwner` (câmera, HUD, iluminação, áudio, input, animação).
* **Observadores** (jogadores até `MaxRange`) recebem `CutsceneObserve`: veem pose + VFX + troca de modelo,
  sem câmera/HUD. Os VFX são locais a cada cliente (nada de milhares de peças replicadas).
* **Habilidade:** `RequestAbility(aim)` → servidor checa forma/cooldown/rate/direção (sanitiza NaN, vertical,
  mira oposta à frente) → telegraph (0,9 s) → varredura por segmentos (sem buracos) → dano único por alvo.

## Modelo e animações (o que é real e o que é provisório)

* **Transformação visual real:** `ModelKit` solda peças ao rig R15 existente (cabelo longo em cadeia de
  Motor6D que balança, máscara, bandagens, casaco rasgado, katana com corrente, olhos vermelhos, pele
  mais pálida) e faz crossfade Ichigo→Mugetsu. **São peças procedurais — funcionam e são compatíveis com
  o rig, mas não têm a qualidade de um modelo esculpido.** Para trocar por arte final, coloque em
  `ServerStorage/MugetsuAssets/MugetsuKit` peças com atributos `Form` ("Ichigo"/"Mugetsu"), `AttachTo`
  (nome do membro R15) e `Offset` (CFrame); o builder as usa automaticamente.
* **Animações:** nenhuma animação publicada foi inventada. `AssetManifest.Animations.*.id` está vazio;
  enquanto vazio, `PoseDriver` anima por poses procedurais (Motor6D.Transform) sincronizadas ao relógio do
  servidor. Quando você colar um ID real, a animação passa a ser usada e seus `KeyframeMarker`s disparam os
  eventos (`ReleaseImpact`, `SwordSlash`, `MaskForm`…), com fallback temporizado de 0,6 s.
* **Áudio:** nenhum som é tocado sem ID (`AssetManifest.Sounds`). O console lista os que faltam.

## Assets externos ainda necessários

| Item | Onde colar | Briefing |
|---|---|---|
| Animações `Prepare`, `Concentrate`, `Transform`, `Release`, `FinalPose`, `GetsugaCast` | `AssetManifest.Animations[nome].id` | descrição, duração e markers esperados no próprio manifesto |
| Sons `AmbientBed`, `Heartbeat`, `EnergyRise`, `Impact`, `SwordSlash`, `Getsuga`, `Tendrils` | `AssetManifest.Sounds[nome].id` | idem (use só áudio original/licenciado) |
| Modelo/kit de alta qualidade (opcional) | `ServerStorage/MugetsuAssets/MugetsuKit` | ver acima |
| Texturas de partícula próprias (opcional) | `VFX.luau` (`SMOKE`/`SPARK`) | hoje usa texturas embutidas do cliente Roblox |

## Modelo 3D do Ichigo (malha esculpida)

O modelo enviado (Ichigo normal; OBJ de ~600 mil triângulos, sem cor) foi processado por `tools/import_mesh.py`: limpeza de
172 mil fragmentos soltos, rotação para a frente do Roblox, escala para o R15, corte por membro (cabelo, rosto,
mandíbula, torso, casaco, braços, mão, pernas e espada), redução para ≈43 mil triângulos e cores das referências.
Resultado: `assets/models/ichigo_mesh/IchigoMesh.obj` + `src/shared/MeshKitManifest.json`.

O envio da malha para o Roblox precisa ser feito por você no Studio (é a sua conta): **siga
[`docs/IMPORTAR_MALHA.md`](docs/IMPORTAR_MALHA.md)**. Enquanto o Model não for importado, o jogo usa o kit de peças
(`Config.Kit.Source`). A prévia (`preview/index.html`) já mostra a malha na cutscene; `preview/mesh.html?seg=1`
mostra os cortes por membro.

## Skins do catálogo (por ID), só na cutscene

`Config.Skins.Ichigo` / `Config.Skins.Mugetsu` recebem IDs do catálogo (ou `{ bundle = ID }`). O servidor
descobre o tipo de cada item (`MarketplaceService`) e monta um `HumanoidDescription` a partir da aparência
original do jogador: Ichigo antes da cena começar, Mugetsu no início do flash branco, e volta ao normal no
fim da forma (`RestoreAfter = "Form"`) ou da cutscene (`"Cutscene"`). Uma forma com skin usa só a espada do
jogo (rastro/golpes); sem skin, usa o kit. `src/server/SkinService.luau`.

## Animações

Coreografia procedural em `src/shared/PoseDriver.luau` (funciona sem assets) e exportada como
KeyframeSequences em `ServerStorage/MugetsuAnimations` para publicar como Animation IDs:
[`docs/ANIMACOES.md`](docs/ANIMACOES.md).

## Testes

```bash
cd roblox-mugetsu && npm i && npm test
```
Roda num VM Luau real (WASM): **(1)** compila todos os 26 arquivos; **(2)** 20 testes unitários
(Timeline sem evento perdido/duplicado mesmo com lag, máquina de estados, cooldown, sanitização de mira,
caixa de acerto e varredura sem buracos, continuidade das poses); **(3)** 17 cenários dos serviços
**reais** do servidor sobre um Roblox simulado com relógio virtual: transformação completa e restauração,
cancelamento antes/depois da troca, saída do jogador, watchdog, R6 recusado, expiração de forma, validação
da habilidade (forma, cooldown, rate limit, entradas inválidas, mira forjada, morte no telegraph), dano
único/alcance/lateral/atrás e multiplayer. Mutações injetadas (validação removida, restauração removida)
fazem os testes falharem, confirmando que eles verificam o comportamento.

### Testes manuais no Studio (pendentes — não executei)
1. Play → **G**: câmera segue os planos, controles travam, letterbox aparece; no fim voltam sozinhos.
2. Conferir **sinais das poses** (`PoseDriver` documenta a convenção de eixos derivada da geometria R15;
   se algum membro girar ao contrário, inverta o sinal na pose correspondente).
3. Katana alinhada na mão (`ModelKit`: rotação −67°) nas poses de guarda e golpe.
4. *Start Server + 2 Players*: o segundo vê a transformação do primeiro; cooldown e dano independentes.
5. Mobile (emulador do Studio): botões visíveis; qualidade `Low` por padrão (`LocalPlayer:SetAttribute("MugetsuQuality","High")` força).
6. Morrer/sair no meio da cena: controles e câmera voltam.

## Limitações conhecidas
* Não rodou no Studio: a **estética final** (timing de câmera vs. pose, legibilidade da silhueta no clímax,
  desempenho real em celular) não foi vista por ninguém ainda. Os orçamentos (peças ≤220, partículas
  escaladas por qualidade, laço único) foram dimensionados, não medidos.
* Cliente (câmera/VFX/HUD/pose) só passou em **compilação**; a lógica do servidor foi simulada, o cliente não.
* Falha do cliente no meio da cena restaura o cliente na hora; o servidor só libera o personagem ao fim
  da linha do tempo (≤30 s) ou por morte/saída — não há remote "cancelar" do cliente (decisão de segurança).
* Peças procedurais ≠ modelo de alta qualidade; animações são poses procedurais até você publicar as reais.
* Não há DataStore/persistência (fora do escopo).
* Combate de terceiros: o atributo `MugetsuCutscene` do jogador indica cena ativa; outros sistemas de
  combate devem consultá-lo (aqui o servidor já bloqueia a habilidade e dá ForceField durante a cena).

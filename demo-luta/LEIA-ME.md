# Luta de teste: Akira vs Kurozan

Dois lutadores originais com rig R15 e uma troca de golpes de 4 s (60 fps):
jab → bloqueio → gancho → esquiva → joelhada → projeção.
Servem para testar o pipeline Blender → Roblox do guia
(`docs/guia-gojo-vs-sukuna-blender-roblox.md`).

| Ficheiro | Para quê |
|---|---|
| `luta_teste.blend` | Cena completa: rigs, animação, 3 câmeras, marcadores de eventos |
| `luta_teste.glb` | Tudo animado num ficheiro; abre em qualquer visualizador 3D (também no telemóvel) |
| `modelos/*.fbx` | Os dois personagens com malha e rig, sem animação |
| `export_roblox/*.fbx` | Animações prontas para o Animation Editor (1 por personagem e por clip) |
| `export_roblox/*__CutsceneData.lua` | Câmera + eventos para o `tools/roblox/CutscenePlayer.lua` |

## Testar no Roblox Studio (5 minutos)

1. *Avatar → Rig Builder → R15 → Block Rig*, duas vezes (um "Akira" e um "Kurozan").
   Os nomes dos bones são iguais aos de qualquer R15, por isso a animação funciona
   em qualquer boneco R15.
2. Ancore o `HumanoidRootPart` dos dois.
3. *Animation Editor* → selecione o primeiro → `⋯` → *Import → From FBX Animation* →
   `luta_completa__AKIRA_RIG.fbx`. Repita com o outro e `luta_completa__KUROZAN_RIG.fbx`.
4. Publique as duas animações e siga a secção 4.5 do guia para tocar tudo
   sincronizado com a câmera (`SceneOrigin` + `CutscenePlayer`).

## Abrir no Blender

Abra `luta_teste.blend` e carregue em espaço para ver a luta. As câmeras trocam
sozinhas nos marcadores `cam_*`. Para reexportar:
`tools/blender/roblox_cutscene_export.py` (no CONFIG mude `rigs` para
`["AKIRA_RIG", "KUROZAN_RIG"]` e `studs_per_unit` para `1.0`).
Para regenerar a cena do zero: `tools/blender/build_demo_fighters.py`.

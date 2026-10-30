# Animações da cutscene

O jogo já anima o personagem sozinho: a coreografia está em `src/shared/PoseDriver.luau` (poses-chave por
junta do R15, com respiração e tremor por cima) e roda igual em todos os jogadores, sem precisar de nenhum
asset. Coreografia: guarda baixa → ergue o olhar → guarda com a espada à frente → encara a câmera → mão no
rosto → **rugido** quando a máscara se forma → encolhido no flash branco → antecipação com a espada no alto →
**corte no impacto (19,6 s)** → continuação → pose final do Mugetsu. Golpe do Getsuga: carga baixa → corte
ascendente.

## Transformar em Animation IDs (opcional, para editar/refinar no Animation Editor)

As mesmas animações estão dentro do jogo como **KeyframeSequence**, em `ServerStorage/MugetsuAnimations`
(`Prepare`, `Concentrate`, `Transform`, `Release`, `FinalPose`, `GetsugaCast`), já com os marcadores de evento
(`Impact`, `Slash`, `Mask`, `Swap`, `Fire`).

1. No Studio, em **ServerStorage → MugetsuAnimations**, clique com o botão direito numa animação →
   **Save to Roblox** (precisa estar logado). Copie o ID que aparece.
   * Para ajustar antes: abra o **Animation Editor** com um rig R15 selecionado e importe/edite a sequência.
2. Cole o ID em `ReplicatedStorage → Mugetsu → AssetManifest`, no campo `id` da animação correspondente
   (formato `"rbxassetid://123456"`).
3. Pronto: o jogo passa a tocar a animação publicada; os marcadores disparam os efeitos (impacto, corte,
   máscara). Animações sem ID continuam na versão procedural.

As KeyframeSequences não têm a respiração nem o tremor da concentração (camadas procedurais).

Para regenerar depois de mudar a coreografia: `python3 preview/gen_data.py && python3 tools/build_animations.py`.

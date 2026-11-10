# Modelos dos pets feitos no Blender

Os pets podem usar um modelo **contínuo** (uma malha só, sem juntas de bolinha), com esqueleto, olhos pintados e
textura, gerado automaticamente no Blender a partir da anatomia do jogo. Esse modelo entra no Roblox pelo
**Importador 3D do Studio**, que não depende da opção "Allow Mesh / Image APIs".

## Como colocar um pet no jogo

1. No Studio, abra o lugar (`build/MythicalIsles.rbxl`).
2. **Arquivo → Importar 3D** (ou Início → Importar 3D) e escolha o FBX do pet, por exemplo `kit_1.fbx`.
3. Na janela do importador:
   - deixe marcado importar como **modelo único** com **rig/esqueleto** (as opções de "Rig" ligadas);
   - **não** marque "Anchored";
   - a unidade de escala pode ficar como vier: o jogo ajusta o tamanho sozinho pela altura do pet.
4. Clique em Importar. O Studio cria um `Model` no Workspace com o nome do arquivo.
5. Arraste esse `Model` para **ReplicatedStorage → PetRigs** e confira que o nome é exatamente o id da espécie
   (`kit_1`, `leafcat_1`, ...).
6. Salve/publique. Ao dar Play, os pets dessa espécie usam o modelo novo; as outras continuam como antes.

O jogo procura `ReplicatedStorage.PetRigs.<id>`. Os ossos do modelo têm os mesmos nomes das partes do corpo
(`Torso`, `Head`, `UpperFL`...), e a cada quadro seguem o esqueleto que o jogo já anima — todas as animações
existentes continuam valendo.

## Como gerar os FBX de novo

```
pip install bpy                                   # Blender como módulo Python (5.2)
python3 tools/run_tests.py luau --rigexport > rigs.txt
# separe cada linha "RIG <id> {json}" em <pasta>/<id>.json
python tools/blender/build_pets.py --rigs <pasta> --out <saída> --render
```

O script, para cada pet:
- junta as partes do corpo e refaz a superfície em voxels (some a emenda das juntas), suaviza e reduz para
  ~12 mil triângulos;
- esculpe detalhes nos peludos: tufos nas bochechas, pelo fofo no peito e dedinhos nas patas;
- recria os olhos como calotas brilhantes com textura pintada (íris em degradê, pupila grande, dois brilhos);
- monta o esqueleto (um osso por parte com junta) e calcula os pesos de skinning pela distância a cada parte;
- assa as cores numa textura 1024×1024 e exporta FBX com as texturas embutidas, mais uma prévia renderizada.

## Limitações

- A importação é manual, um FBX por vez, e o Studio envia a malha e as texturas para a sua conta.
- O passo de importação e o modelo dentro do Roblox **não foram testados** (só o lado do jogo, num simulador
  com um modelo falso de mesma estrutura). Se o Importador 3D criar os ossos com outros nomes ou outra
  hierarquia, me avise com uma foto do Explorer.
- Mutações que recolorem o pet não tingem a textura do modelo importado (os efeitos de partículas continuam).
- Os bosses ainda não passam por esse processo.

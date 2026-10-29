# Como colocar o modelo 3D do Mugetsu no jogo (Roblox Studio)

O arquivo pronto é `assets/models/mugetsu_mesh/MugetsuMesh.obj`. Ele já está cortado por parte do corpo,
reduzido (≈43 mil triângulos no total, no máximo 9 mil por peça), virado para a frente certa e na escala
do corpo R15. O jogo já sabe encaixar cada peça; você só precisa enviá-lo para a sua conta pelo Studio.

## Passo a passo (uma vez só)

1. Abra o `Mugetsu.rbxlx` no Roblox Studio (precisa estar logado na sua conta).
2. Use o **Importador 3D** do Studio (aba *Home* ou *Avatar* → **Import 3D**) e escolha `MugetsuMesh.obj`.
3. Nas opções de importação:
   * deixe a unidade do arquivo em **studs** (o modelo deve medir ≈ 6,5 studs de altura);
   * **não** mescle as malhas (cada peça precisa continuar separada, com o nome dela).
4. Confirme. Vai aparecer um Model no Workspace com peças chamadas `Root`, `Head_Hair`, `Head_Face`,
   `Head_Mask`, `UpperTorso`, `LowerTorso_Coat`, `RightUpperArm`, `RightLowerArm`, `RightHand`,
   `LeftUpperArm`, `LeftLowerArm`, `RightLowerLeg`, `LeftLowerLeg`, `Blade`.
5. Renomeie esse Model para **`MugetsuMesh`**.
6. Em **ServerStorage**, crie uma pasta chamada **`MugetsuAssets`** e arraste o Model `MugetsuMesh` para dentro.
7. Aperte **Play** e use **G**. No Output deve aparecer:
   `[Mugetsu] forma Mugetsu montada a partir da malha importada (13 pedaços)`.

Não precisa posicionar nada: o jogo usa o cubo `Root` como referência e encaixa cada peça no membro do
personagem pelas juntas, seja qual for o lugar onde o Model foi solto.

## Se algo der errado

* **Mensagem "MugetsuMesh sem o cubo 'Root'"**: o Model importado não tem a peça `Root`; reimporte sem mesclar.
* **Peças no lugar errado ou escala estranha**: o avatar precisa ser **R15** com escala padrão
  (Game Settings → Avatar → R15, escalas em 100%). O modelo foi ajustado para o corpo R15 padrão.
* **Alguma peça não aparece**: confira se os nomes das peças são exatamente os da lista acima.
* **Quer voltar ao kit antigo**: em `src/shared/Config.luau`, `Kit.UseMesh = false` (ou só tire o Model da pasta).

## Refazer a partir de outro modelo

```bash
pip install trimesh numpy scipy fast-simplification
python3 tools/import_mesh.py caminho/do/modelo.obj   # gera o OBJ cortado e o MeshKitManifest.json
python3 preview/gen_data.py                          # atualiza a prévia
```
`tools/import_mesh.py` foi calibrado para este modelo (ombro na altura 0.45 do arquivo, espada na mão direita);
um modelo diferente pode exigir ajustar essas medidas no topo do script.

# Como colocar o modelo 3D do Ichigo no jogo (Roblox Studio)

O modelo enviado é o **Ichigo normal** (antes da transformação). Ele vira a forma Ichigo da cutscene;
o Mugetsu vem das skins por ID (`Config.Skins.Mugetsu`) ou, sem elas, do kit procedural.

O arquivo pronto é `assets/models/ichigo_mesh/IchigoMesh.obj`. Ele já está cortado por parte do corpo,
reduzido (≈43 mil triângulos no total, no máximo 9 mil por peça), virado para a frente certa e na escala
do corpo R15. O jogo já sabe encaixar cada peça; você só precisa enviá-lo para a sua conta pelo Studio.

## Passo a passo (uma vez só)

1. Abra o `Mugetsu.rbxlx` no Roblox Studio (precisa estar logado na sua conta).
2. Use o **Importador 3D** do Studio (aba *Home* ou *Avatar* → **Import 3D**) e escolha `IchigoMesh.obj`.
3. Nas opções de importação:
   * deixe a unidade do arquivo em **studs** (o modelo deve medir ≈ 6,5 studs de altura);
   * **não** mescle as malhas (cada peça precisa continuar separada, com o nome dela).
4. Confirme. O modelo aparece no mapa (Workspace). **Pronto, não precisa mover nem renomear nada.**
5. Aperte **Play**. Ao iniciar, o jogo encontra o modelo sozinho, guarda em `ServerStorage/MugetsuAssets`
   e o Output mostra `modelo importado encontrado em ...`. O personagem aparece como o Ichigo do modelo
   e, ao usar **G**, ele vira o Mugetsu.

Para o modelo ficar salvo no jogo, salve o place depois de importar (File → Save).

## Se algo der errado

* **Nenhuma mensagem `modelo importado encontrado`**: o import provavelmente mesclou as peças; reimporte sem mesclar.
* **Mensagem "IchigoMesh sem o cubo 'Root'"**: o Model importado não tem a peça `Root`; reimporte sem mesclar.
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

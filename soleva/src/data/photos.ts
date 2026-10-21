/**
 * Fotos reais dos produtos. Coloque os arquivos em
 *   src/assets/produtos/<slug-do-produto>/
 * (jpg, jpeg, png ou webp). A ordem segue o nome do arquivo: 1.jpg, 2.jpg…
 * A primeira foto é a principal. Produtos sem fotos usam o render vetorial.
 * Um arquivo chamado `recorte.png`/`recorte.webp` (tênis sem fundo) é usado nos
 * cards e nas vitrines; as demais fotos aparecem na galeria do produto.
 */
const files = import.meta.glob<string>('../assets/produtos/*/*.{jpg,jpeg,png,webp,JPG,JPEG,PNG,WEBP}', {
  eager: true,
  import: 'default',
  query: '?url',
});

const bySlug: Record<string, { name: string; url: string }[]> = {};
for (const [path, url] of Object.entries(files)) {
  const [, slug, name] = path.match(/produtos\/([^/]+)\/([^/]+)$/) ?? [];
  if (slug) (bySlug[slug] ??= []).push({ name, url });
}

const isCutout = (name: string) => /^recorte\./i.test(name);

export function photosFor(slug: string): string[] | undefined {
  const list = bySlug[slug]?.filter((f) => !isCutout(f.name));
  if (!list?.length) return undefined;
  return list
    .sort((a, b) => a.name.localeCompare(b.name, 'pt-BR', { numeric: true }))
    .map((f) => f.url);
}

export function cutoutFor(slug: string): string | undefined {
  return bySlug[slug]?.find((f) => isCutout(f.name))?.url;
}

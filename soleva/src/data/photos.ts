/**
 * Fotos reais dos produtos. Coloque os arquivos em
 *   src/assets/produtos/<slug-do-produto>/
 * (jpg, jpeg, png ou webp). A ordem segue o nome do arquivo: 1.jpg, 2.jpg…
 * A primeira foto é a principal. Produtos sem fotos usam o render vetorial.
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

export function photosFor(slug: string): string[] | undefined {
  const list = bySlug[slug];
  if (!list?.length) return undefined;
  return list
    .sort((a, b) => a.name.localeCompare(b.name, 'pt-BR', { numeric: true }))
    .map((f) => f.url);
}

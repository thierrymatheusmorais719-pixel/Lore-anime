import type { CategoryId, ColorId, Product } from '../types';
import { isNew, isOnSale, isUpcoming, releaseTimestamp, totalStock } from './product';
import { searchProducts } from './search';

export type SortKey = 'relevancia' | 'menor-preco' | 'maior-preco' | 'novidades' | 'populares';

export const SORT_OPTIONS: { id: SortKey; label: string }[] = [
  { id: 'relevancia', label: 'Relevância' },
  { id: 'populares', label: 'Mais populares' },
  { id: 'novidades', label: 'Novidades' },
  { id: 'menor-preco', label: 'Menor preço' },
  { id: 'maior-preco', label: 'Maior preço' },
];

export type Flag = 'promocao' | 'lancamento' | 'limitado' | 'disponivel';

export const FLAG_LABELS: Record<Flag, string> = {
  lancamento: 'Lançamentos',
  promocao: 'Em promoção',
  limitado: 'Edição limitada',
  disponivel: 'Disponível agora',
};

export interface Filters {
  q: string;
  brands: string[];
  categories: CategoryId[];
  sizes: string[];
  colors: ColorId[];
  priceMin: number | null;
  priceMax: number | null;
  flags: Flag[];
  collection: string | null;
  sort: SortKey;
}

export const emptyFilters = (): Filters => ({
  q: '',
  brands: [],
  categories: [],
  sizes: [],
  colors: [],
  priceMin: null,
  priceMax: null,
  flags: [],
  collection: null,
  sort: 'relevancia',
});

const list = (v: string | null) => (v ? v.split(',').filter(Boolean) : []);
const num = (v: string | null) => {
  if (v === null || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? n : null;
};

/** A URL é a fonte da verdade dos filtros: links compartilháveis e botão voltar funcionam. */
export function parseFilters(params: URLSearchParams, category?: string): Filters {
  const sort = params.get('ordem') as SortKey | null;
  const f: Filters = {
    q: params.get('q') ?? '',
    brands: list(params.get('marca')),
    categories: list(params.get('categoria')) as CategoryId[],
    sizes: list(params.get('tamanho')),
    colors: list(params.get('cor')) as ColorId[],
    priceMin: num(params.get('min')),
    priceMax: num(params.get('max')),
    flags: list(params.get('filtro')) as Flag[],
    collection: params.get('colecao'),
    sort: sort && SORT_OPTIONS.some((o) => o.id === sort) ? sort : 'relevancia',
  };
  if (category && !f.categories.includes(category as CategoryId)) f.categories = [category as CategoryId];
  return f;
}

export function serializeFilters(f: Filters, omitCategory = false): URLSearchParams {
  const p = new URLSearchParams();
  if (f.q) p.set('q', f.q);
  if (f.brands.length) p.set('marca', f.brands.join(','));
  if (!omitCategory && f.categories.length) p.set('categoria', f.categories.join(','));
  if (f.sizes.length) p.set('tamanho', f.sizes.join(','));
  if (f.colors.length) p.set('cor', f.colors.join(','));
  if (f.priceMin !== null) p.set('min', String(f.priceMin));
  if (f.priceMax !== null) p.set('max', String(f.priceMax));
  if (f.flags.length) p.set('filtro', f.flags.join(','));
  if (f.collection) p.set('colecao', f.collection);
  if (f.sort !== 'relevancia') p.set('ordem', f.sort);
  return p;
}

export function countActive(f: Filters): number {
  return (
    f.brands.length +
    f.categories.length +
    f.sizes.length +
    f.colors.length +
    f.flags.length +
    (f.priceMin !== null || f.priceMax !== null ? 1 : 0) +
    (f.collection ? 1 : 0)
  );
}

export function applyFilters(products: Product[], f: Filters, now = Date.now()): Product[] {
  let out = f.q.trim() ? searchProducts(products, f.q) : [...products];

  out = out.filter((p) => {
    if (f.brands.length && !f.brands.includes(p.brandId)) return false;
    if (f.categories.length && !f.categories.includes(p.category)) return false;
    if (f.colors.length && !p.colors.some((c) => f.colors.includes(c))) return false;
    if (f.sizes.length && !f.sizes.some((s) => (p.stock[s] ?? 0) > 0)) return false;
    if (f.priceMin !== null && p.price < f.priceMin) return false;
    if (f.priceMax !== null && p.price > f.priceMax) return false;
    if (f.collection && p.collection !== f.collection) return false;
    for (const flag of f.flags) {
      if (flag === 'promocao' && !isOnSale(p)) return false;
      if (flag === 'lancamento' && !(isNew(p, now) || isUpcoming(p, now))) return false;
      if (flag === 'limitado' && !p.limited) return false;
      if (flag === 'disponivel' && (isUpcoming(p, now) || totalStock(p) === 0)) return false;
    }
    return true;
  });

  switch (f.sort) {
    case 'menor-preco':
      out.sort((a, b) => a.price - b.price);
      break;
    case 'maior-preco':
      out.sort((a, b) => b.price - a.price);
      break;
    case 'novidades':
      out.sort((a, b) => releaseTimestamp(b) - releaseTimestamp(a));
      break;
    case 'populares':
      out.sort((a, b) => b.popularity - a.popularity);
      break;
    case 'relevancia':
      // Com busca, mantém a ordem por pontuação; sem busca, popularidade.
      if (!f.q.trim()) out.sort((a, b) => b.popularity - a.popularity);
      break;
  }
  return out;
}

/** Quantos produtos cada opção de faceta retornaria, mantendo os demais filtros. */
export function facetCount(products: Product[], f: Filters, patch: Partial<Filters>): number {
  return applyFilters(products, { ...f, ...patch }).length;
}

export const toggle = <T,>(arr: T[], v: T): T[] => (arr.includes(v) ? arr.filter((x) => x !== v) : [...arr, v]);

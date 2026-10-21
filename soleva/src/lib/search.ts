import { BRANDS, CATEGORIES } from '../data/catalog';
import type { Product } from '../types';
import { brandName } from './product';

export const normalize = (s: string) =>
  s
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

function haystack(p: Product) {
  const category = CATEGORIES.find((c) => c.id === p.category)?.name ?? '';
  return normalize(`${brandName(p)} ${p.name} ${p.model} ${p.colorway} ${category} ${p.sku}`);
}

/**
 * Pontua um produto para uma busca. Todos os termos precisam aparecer;
 * correspondências no início de palavra, na marca e no nome valem mais.
 * Retorna 0 quando não há correspondência.
 */
export function scoreProduct(p: Product, query: string): number {
  const terms = normalize(query).split(' ').filter(Boolean);
  if (!terms.length) return 0;
  const hay = haystack(p);
  const title = normalize(`${brandName(p)} ${p.name} ${p.model}`);
  let score = 0;
  for (const t of terms) {
    const idx = hay.indexOf(t);
    if (idx === -1) return 0;
    score += 1;
    if (idx === 0 || hay[idx - 1] === ' ') score += 2;
    if (title.includes(t)) score += 3;
  }
  return score + p.popularity / 100;
}

export function searchProducts(products: Product[], query: string): Product[] {
  return products
    .map((p) => ({ p, s: scoreProduct(p, query) }))
    .filter((x) => x.s > 0)
    .sort((a, b) => b.s - a.s)
    .map((x) => x.p);
}

export interface Suggestion {
  kind: 'brand' | 'category' | 'model';
  label: string;
  to: string;
}

/** Sugestões de texto (marcas, categorias e modelos) para o autocompletar. */
export function suggest(products: Product[], query: string, limit = 5): Suggestion[] {
  const q = normalize(query);
  if (!q) return [];
  const out: Suggestion[] = [];
  for (const b of BRANDS) {
    if (normalize(b.name).includes(q)) out.push({ kind: 'brand', label: b.name, to: `/loja?marca=${b.id}` });
  }
  for (const c of CATEGORIES) {
    if (normalize(c.name).includes(q)) out.push({ kind: 'category', label: c.name, to: `/loja/${c.id}` });
  }
  const models = new Set<string>();
  for (const p of searchProducts(products, query)) {
    const label = `${brandName(p)} ${p.name}`;
    if (!models.has(label)) {
      models.add(label);
      out.push({ kind: 'model', label, to: `/loja?q=${encodeURIComponent(label)}` });
    }
  }
  return out.slice(0, limit);
}

import { photosFor } from './photos';
import type { Brand, CategoryId, ColorId, Palette, Product, Silhouette } from '../types';

export const SIZES = ['34', '35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '45'];

export const BRANDS: Brand[] = [
  { id: 'nike', name: 'Nike', origin: 'Beaverton, EUA', tagline: 'Air Force 1, Dunk e os clássicos de sempre.' },
  { id: 'jordan', name: 'Jordan', origin: 'Chicago, EUA', tagline: 'A linha que levou o basquete para a rua.' },
  { id: 'adidas', name: 'adidas', origin: 'Herzogenaurach, Alemanha', tagline: 'Três listras, do esporte ao skate.' },
];

export const CATEGORIES: { id: CategoryId; name: string; blurb: string }[] = [
  { id: 'lifestyle', name: 'Lifestyle', blurb: 'Do café ao fim da noite.' },
  { id: 'basketball', name: 'Basketball', blurb: 'Tração e suporte de quadra.' },
  { id: 'running', name: 'Running', blurb: 'Espuma responsiva, quilômetro após quilômetro.' },
  { id: 'skate', name: 'Skate', blurb: 'Vulcanizados, duráveis, com feeling.' },
  { id: 'streetwear', name: 'Streetwear', blurb: 'Silhuetas que fazem o look.' },
];

export const COLORS: { id: ColorId; name: string; swatch: string }[] = [
  { id: 'preto', name: 'Preto', swatch: '#111111' },
  { id: 'branco', name: 'Branco', swatch: '#f4f4f2' },
  { id: 'cinza', name: 'Cinza', swatch: '#9a9a96' },
  { id: 'bege', name: 'Bege', swatch: '#d9cbb0' },
  { id: 'marrom', name: 'Marrom', swatch: '#6b4a33' },
  { id: 'verde', name: 'Verde', swatch: '#4f7a3a' },
  { id: 'azul', name: 'Azul', swatch: '#2c4f8c' },
  { id: 'vermelho', name: 'Vermelho', swatch: '#c3272b' },
  { id: 'laranja', name: 'Laranja', swatch: '#e66a1f' },
  { id: 'roxo', name: 'Roxo', swatch: '#5a3f8f' },
];

export const COLLECTIONS = [
  {
    id: 'triple-black',
    name: 'Triple Black',
    kicker: 'Coleção 01',
    description: 'Preto da cabeça ao solado. Couro, camurça e nobuck que combinam com tudo e não denunciam a sujeira da cidade.',
  },
  {
    id: 'preto-e-branco',
    name: 'Preto & Branco',
    kicker: 'Coleção 02',
    description: 'O contraste mais clássico do sneaker: Panda, swoosh preto em couro branco e o Jordan 1 na combinação original.',
  },
  {
    id: 'arquivo',
    name: 'Arquivo',
    kicker: 'Reedição',
    description: 'Retros de basquete dos anos 80 e 90, reeditados com o shape fiel ao original.',
  },
];

/* ---------- Gerador determinístico de estoque ---------- */

function hash(str: string): number {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function makeStock(seed: string, range: [string, string], scarce = false): Record<string, number> {
  const stock: Record<string, number> = {};
  let h = hash(seed);
  const from = SIZES.indexOf(range[0]);
  const to = SIZES.indexOf(range[1]);
  SIZES.forEach((size, i) => {
    h = Math.imul(h ^ (h >>> 13), 1274126177) >>> 0;
    if (i < from || i > to) return;
    const roll = h % 100;
    if (scarce) stock[size] = roll < 35 ? 0 : (roll % 4) + 1;
    else stock[size] = roll < 10 ? 0 : roll < 25 ? (roll % 3) + 1 : (roll % 18) + 4;
  });
  return stock;
}

/* ---------- Paletas ---------- */

const pal = (
  upper: string,
  overlay: string,
  accent: string,
  midsole = '#f2f1ec',
  outsole = '#e8e6df',
  laces = upper,
  lining = overlay,
): Palette => ({ upper, overlay, accent, midsole, outsole, laces, lining });

interface Seed {
  slug: string;
  name: string;
  model: string;
  brandId: string;
  category: CategoryId;
  colorway: string;
  colors: ColorId[];
  silhouette: Silhouette;
  palette: Palette;
  price: number;
  compareAtPrice?: number;
  releaseDate: string;
  limited?: number;
  collection?: string;
  popularity: number;
  rating: number;
  reviewCount: number;
  sizes?: [string, string];
  description: string;
  materials: string[];
  features: string[];
}

const seeds: Seed[] = [
  {
    slug: 'nike-air-force-1-07-triple-black',
    name: "Air Force 1 '07",
    model: 'Triple Black',
    brandId: 'nike',
    category: 'lifestyle',
    colorway: 'Preto / Preto',
    colors: ['preto'],
    silhouette: 'court',
    palette: pal('#141414', '#0d0d0d', '#1e1e1e', '#141414', '#0b0b0b', '#141414', '#1e1e1e'),
    price: 899.99,
    releaseDate: '2026-08-14',
    collection: 'triple-black',
    popularity: 99,
    rating: 4.9,
    reviewCount: 1284,
    description:
      'O Air Force 1 nasceu nas quadras em 1982 e nunca mais saiu da rua. Couro liso todo preto, entressola com Air encapsulado e o solado com o círculo de pivô que virou assinatura.',
    materials: ['Cabedal em couro liso', 'Entressola em espuma com unidade Nike Air', 'Solado em borracha com padrão de pivô'],
    features: ['Perfurações na biqueira', 'Colarinho acolchoado de cano baixo', 'Deubré metálico no cadarço'],
  },
  {
    slug: 'nike-air-force-1-07-white-black',
    name: "Air Force 1 '07",
    model: 'White Black',
    brandId: 'nike',
    category: 'streetwear',
    colorway: 'Branco / Preto',
    colors: ['branco', 'preto'],
    silhouette: 'court',
    palette: pal('#f6f6f4', '#efefec', '#111111', '#f6f6f4', '#e9e9e6', '#f6f6f4', '#efefec'),
    price: 849.99,
    compareAtPrice: 999.99,
    releaseDate: '2026-06-02',
    collection: 'preto-e-branco',
    popularity: 93,
    rating: 4.8,
    reviewCount: 612,
    description:
      'Couro branco, swoosh preto pintado e o "AIR" destacado na entressola. Uma versão do AF1 com mais contraste, que aparece de longe sem perder o jeito clássico.',
    materials: ['Cabedal em couro', 'Entressola em espuma com unidade Nike Air', 'Solado em borracha'],
    features: ['Swoosh preto com acabamento brilhante', 'Logo AIR destacado na entressola', 'Deubré "AF1" no cadarço'],
  },
  {
    slug: 'nike-dunk-low-panda',
    name: 'Dunk Low Retro',
    model: 'Panda',
    brandId: 'nike',
    category: 'streetwear',
    colorway: 'Branco / Preto',
    colors: ['branco', 'preto'],
    silhouette: 'court',
    palette: pal('#f6f6f4', '#141414', '#141414', '#f6f6f4', '#141414', '#141414', '#f6f6f4'),
    price: 899.99,
    releaseDate: '2026-10-05',
    collection: 'preto-e-branco',
    popularity: 98,
    rating: 4.8,
    reviewCount: 947,
    description:
      'Lançado em 1985 para o basquete universitário, o Dunk virou ícone do streetwear. Na combinação Panda, os overlays pretos em couro sobre base branca deixam o visual limpo e fácil de usar.',
    materials: ['Cabedal em couro', 'Entressola em espuma', 'Solado em borracha com padrão de pivô'],
    features: ['Perfil baixo acolchoado', 'Logo Nike bordado na lingueta', 'Shape retrô fiel ao de 1985'],
  },
  {
    slug: 'jordan-1-retro-high-og-bred',
    name: 'Air Jordan 1 Retro High OG',
    model: 'Bred',
    brandId: 'jordan',
    category: 'basketball',
    colorway: 'Vermelho Varsity / Preto / Branco',
    colors: ['vermelho', 'preto'],
    silhouette: 'high',
    palette: pal('#b3202a', '#141414', '#141414', '#f4f2ec', '#141414', '#141414', '#141414'),
    price: 1999.99,
    releaseDate: '2026-09-18',
    limited: 300,
    collection: 'arquivo',
    popularity: 97,
    rating: 4.9,
    reviewCount: 318,
    description:
      'A combinação vermelha e preta que a liga proibiu em 1985. Couro premium, logo Wings no colarinho e a etiqueta Nike Air na lingueta, como no original.',
    materials: ['Cabedal em couro premium', 'Forro têxtil', 'Solado em borracha com padrão de pivô'],
    features: ['Logo Wings gravado no colarinho', 'Etiqueta Nike Air na lingueta', 'Unidade Air encapsulada no calcanhar'],
  },
  {
    slug: 'jordan-1-retro-high-og-black-white',
    name: 'Air Jordan 1 Retro High OG',
    model: 'Black White',
    brandId: 'jordan',
    category: 'basketball',
    colorway: 'Preto / Branco',
    colors: ['preto', 'branco'],
    silhouette: 'high',
    palette: pal('#f4f2ec', '#141414', '#141414', '#f4f2ec', '#141414', '#141414', '#141414'),
    price: 1699.99,
    releaseDate: '2026-11-14',
    collection: 'preto-e-branco',
    popularity: 95,
    rating: 0,
    reviewCount: 0,
    description:
      'O Jordan 1 High em preto e branco, com couro macio e acabamento OG. Lançamento em 14/11 às 10h, com limite de um par por cliente.',
    materials: ['Cabedal em couro', 'Forro têxtil', 'Solado em borracha'],
    features: ['Logo Wings no colarinho', 'Etiqueta Nike Air na lingueta', 'Caixa OG'],
  },
  {
    slug: 'jordan-4-retro-black-cat',
    name: 'Air Jordan 4 Retro',
    model: 'Black Cat',
    brandId: 'jordan',
    category: 'basketball',
    colorway: 'Preto / Grafite Claro',
    colors: ['preto'],
    silhouette: 'high',
    palette: pal('#161616', '#0d0d0d', '#5a5a5a', '#161616', '#0b0b0b', '#161616', '#2a2a2a'),
    price: 2499.99,
    releaseDate: '2026-10-12',
    limited: 250,
    collection: 'triple-black',
    popularity: 99,
    rating: 5,
    reviewCount: 204,
    description:
      'O Black Cat leva o Jordan 4 ao preto absoluto: nubuck preto, painéis em malha, asas laterais e a unidade Air visível no calcanhar. Um dos retros mais procurados dos últimos anos.',
    materials: ['Cabedal em nubuck', 'Painéis em malha', 'Unidade Air visível no calcanhar', 'Solado em borracha'],
    features: ['Asas laterais para ajuste do cadarço', 'Logo Jumpman na lingueta', 'Acompanha certificado de autenticidade'],
  },
  {
    slug: 'adidas-runfalcon-3-black-white',
    name: 'Runfalcon 3.0',
    model: 'Core Black',
    brandId: 'adidas',
    category: 'running',
    colorway: 'Preto / Branco',
    colors: ['preto', 'branco'],
    silhouette: 'runner',
    palette: pal('#161616', '#0d0d0d', '#f6f6f4', '#f6f6f4', '#161616', '#161616', '#f6f6f4'),
    price: 399.99,
    compareAtPrice: 499.99,
    releaseDate: '2026-09-20',
    popularity: 84,
    rating: 4.6,
    reviewCount: 533,
    description:
      'Tênis de corrida para o dia a dia: cabedal em mesh respirável, entressola em espuma Cloudfoam e as três listras em contraste. Leve para treinar e confortável para o resto do dia.',
    materials: ['Cabedal em mesh respirável', 'Entressola em Cloudfoam', 'Solado em borracha'],
    features: ['Ideal para caminhadas e corridas leves', 'Cabedal com fio reciclado', 'Palmilha acolchoada'],
  },
  {
    slug: 'adidas-campus-00s-core-black',
    name: 'Campus 00s',
    model: 'Core Black',
    brandId: 'adidas',
    category: 'skate',
    colorway: 'Preto / Preto / Branco',
    colors: ['preto'],
    silhouette: 'skate',
    palette: pal('#161616', '#0d0d0d', '#2a2a2a', '#161616', '#0d0d0d', '#161616', '#2a2a2a'),
    price: 799.99,
    releaseDate: '2026-07-22',
    collection: 'triple-black',
    popularity: 90,
    rating: 4.7,
    reviewCount: 389,
    description:
      'O Campus voltou com proporções dos anos 2000: camurça grossa, lingueta acolchoada e solado de borracha mais largo. Na versão Core Black, as listras pespontadas em branco são o único contraste.',
    materials: ['Cabedal em camurça', 'Forro têxtil', 'Solado em borracha'],
    features: ['Listras pespontadas em contraste', 'Lingueta e colarinho acolchoados', 'Solado largo estilo anos 2000'],
  },
];

export const PRODUCTS: Product[] = seeds.map((s, i) => {
  const brand = BRANDS.find((b) => b.id === s.brandId)!;
  return {
    id: `p${String(i + 1).padStart(3, '0')}`,
    slug: s.slug,
    name: s.name,
    model: s.model,
    brandId: s.brandId,
    category: s.category,
    colorway: s.colorway,
    colors: s.colors,
    silhouette: s.silhouette,
    palette: s.palette,
    images: photosFor(s.slug),
    price: s.price,
    compareAtPrice: s.compareAtPrice,
    releaseDate: s.releaseDate,
    limited: s.limited ? { totalPairs: s.limited } : undefined,
    collection: s.collection,
    popularity: s.popularity,
    rating: s.rating,
    reviewCount: s.reviewCount,
    stock: makeStock(s.slug, s.sizes ?? ['34', '45'], Boolean(s.limited)),
    description: s.description,
    materials: s.materials,
    features: s.features,
    sku: `${brand.name.slice(0, 3).toUpperCase()}-${String(hash(s.slug) % 90000 + 10000)}`,
  };
});

export const getBrand = (id: string) => BRANDS.find((b) => b.id === id);
export const getCategory = (id: string) => CATEGORIES.find((c) => c.id === id);
export const getCollection = (id?: string) => COLLECTIONS.find((c) => c.id === id);
export const getProduct = (id: string) => PRODUCTS.find((p) => p.id === id);
export const getProductBySlug = (slug: string) => PRODUCTS.find((p) => p.slug === slug);

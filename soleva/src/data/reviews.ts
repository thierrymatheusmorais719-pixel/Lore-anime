import type { Product, Review } from '../types';
import { readJSON, writeJSON } from '../lib/storage';

const AUTHORS = [
  ['Rafael M.', 'São Paulo, SP'], ['Juliana C.', 'Belo Horizonte, MG'], ['Thiago R.', 'Curitiba, PR'],
  ['Camila S.', 'Rio de Janeiro, RJ'], ['Bruno A.', 'Porto Alegre, RS'], ['Larissa F.', 'Recife, PE'],
  ['Pedro H.', 'Florianópolis, SC'], ['Marina L.', 'Salvador, BA'], ['Gustavo P.', 'Goiânia, GO'],
  ['Beatriz N.', 'Campinas, SP'], ['Lucas V.', 'Fortaleza, CE'], ['Ana Clara D.', 'Brasília, DF'],
];

const TEXTS: { rating: number; title: string; body: string; fit: Review['fit'] }[] = [
  { rating: 5, title: 'Acabamento impecável', body: 'Chegou muito bem embalado e o acabamento é de outro nível. Costuras alinhadas, sem cola aparente. Já virou o meu tênis do dia a dia.', fit: 'normal' },
  { rating: 5, title: 'Conforto desde o primeiro uso', body: 'Usei o dia inteiro logo que chegou e não machucou em nada. A palmilha é muito confortável e o tênis é mais leve do que parece nas fotos.', fit: 'normal' },
  { rating: 4, title: 'Lindo, mas forma um pouco pequeno', body: 'O tênis é lindo pessoalmente, a cor é exatamente a da foto. Só achei a forma um pouco justa, se tiver o pé largo vale pegar meio número acima.', fit: 'pequeno' },
  { rating: 5, title: 'Valeu cada centavo', body: 'Material premium de verdade. Já tive outros tênis nessa faixa de preço e esse é disparado o mais bem feito. Entrega chegou antes do prazo.', fit: 'normal' },
  { rating: 4, title: 'Muito bom', body: 'Bonito e confortável. Tirei uma estrela porque o cadarço original é um pouco curto, mas veio um extra na caixa que resolveu.', fit: 'normal' },
  { rating: 5, title: 'Recebo elogio toda vez', body: 'Toda vez que saio com ele alguém pergunta onde comprei. A cor fica ainda melhor ao vivo.', fit: 'normal' },
  { rating: 3, title: 'Bom, mas esperava mais amortecimento', body: 'Visual muito bonito e bem construído, mas para ficar muitas horas em pé senti falta de mais amortecimento. Para uso casual está ótimo.', fit: 'grande' },
  { rating: 5, title: 'Troca fácil', body: 'Pedi a numeração errada e a troca foi super tranquila, pela própria página do pedido. O tênis em si é perfeito.', fit: 'normal' },
];

function rng(seed: number) {
  return () => {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return seed / 2 ** 32;
  };
}

export function getReviews(p: Product): Review[] {
  const local = readJSON<Review[]>(`soleva:reviews:${p.id}`, []);
  if (p.reviewCount === 0) return local;
  const rand = rng(Number(p.id.slice(1)) * 7919);
  const n = Math.min(6, p.reviewCount);
  const sizes = Object.keys(p.stock);
  const authorOffset = Math.floor(rand() * AUTHORS.length);
  const base: Review[] = Array.from({ length: n }, (_, i) => {
    const t = TEXTS[Math.floor(rand() * TEXTS.length)];
    const [author, city] = AUTHORS[(authorOffset + i * 5) % AUTHORS.length];
    const date = new Date(Date.now() - Math.floor(rand() * 120 + 2) * 86_400_000).toISOString();
    // Mantém as notas exibidas coerentes com a média do produto.
    const rating = p.rating >= 4.7 ? Math.max(4, t.rating) : t.rating;
    return {
      id: `${p.id}-r${i}`,
      productId: p.id,
      author,
      city,
      rating,
      title: rating === t.rating ? t.title : TEXTS[0].title,
      body: rating === t.rating ? t.body : TEXTS[0].body,
      size: sizes[Math.floor(rand() * sizes.length)],
      fit: t.fit,
      date,
      verified: rand() > 0.15,
    };
  });
  return [...local, ...base.sort((a, b) => b.date.localeCompare(a.date))];
}

export function addLocalReview(review: Review) {
  const key = `soleva:reviews:${review.productId}`;
  writeJSON(key, [review, ...readJSON<Review[]>(key, [])]);
}

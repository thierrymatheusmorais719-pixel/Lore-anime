import { describe, expect, it } from 'vitest';
import { PRODUCTS, getProduct } from '../data/catalog';
import { cartReducer, type CartState } from '../store/cart';
import { applyFilters, emptyFilters, parseFilters, serializeFilters } from './filters';
import { computeTotals, maxQuantity, validateCoupon } from './pricing';
import { searchProducts, suggest } from './search';
import { isValidCPF, validateAddress } from './validation';

const inStock = (p = PRODUCTS.find((x) => !x.limited)!) => {
  const size = Object.keys(p.stock).find((s) => p.stock[s] > 3)!;
  return { p, size };
};

describe('filtros', () => {
  it('filtra por marca, categoria e faixa de preço', () => {
    const f = { ...emptyFilters(), brands: ['orbit'], priceMax: 1200 };
    const out = applyFilters(PRODUCTS, f);
    expect(out.length).toBeGreaterThan(0);
    expect(out.every((p) => p.brandId === 'orbit' && p.price <= 1200)).toBe(true);
  });

  it('filtra por tamanho disponível em estoque', () => {
    const out = applyFilters(PRODUCTS, { ...emptyFilters(), sizes: ['34'] });
    expect(out.every((p) => (p.stock['34'] ?? 0) > 0)).toBe(true);
  });

  it('ordena por menor e maior preço', () => {
    const asc = applyFilters(PRODUCTS, { ...emptyFilters(), sort: 'menor-preco' }).map((p) => p.price);
    expect(asc).toEqual([...asc].sort((a, b) => a - b));
    const desc = applyFilters(PRODUCTS, { ...emptyFilters(), sort: 'maior-preco' }).map((p) => p.price);
    expect(desc).toEqual([...desc].sort((a, b) => b - a));
  });

  it('serializa e lê os filtros da URL sem perdas', () => {
    const f = { ...emptyFilters(), q: 'aero', brands: ['soleva', 'kuro'], colors: ['preto' as const], priceMin: 500, sort: 'novidades' as const };
    expect(parseFilters(serializeFilters(f))).toEqual(f);
  });
});

describe('busca', () => {
  it('encontra por marca e modelo, ignorando acentos', () => {
    expect(searchProducts(PRODUCTS, 'kuro').every((p) => p.brandId === 'kuro')).toBe(true);
    expect(searchProducts(PRODUCTS, 'atlantico').length).toBeGreaterThan(0);
    expect(searchProducts(PRODUCTS, 'zzzz')).toHaveLength(0);
  });
  it('sugere marcas', () => {
    expect(suggest(PRODUCTS, 'orb')[0]).toMatchObject({ kind: 'brand', label: 'Orbit Athletic' });
  });
});

describe('carrinho', () => {
  const empty: CartState = { items: [], couponCode: null };

  it('soma quantidade do mesmo produto/tamanho e respeita o estoque', () => {
    const { p, size } = inStock();
    let s = cartReducer(empty, { type: 'add', product: p, size, quantity: 2 });
    s = cartReducer(s, { type: 'add', product: p, size, quantity: 99 });
    expect(s.items).toHaveLength(1);
    expect(s.items[0].quantity).toBe(maxQuantity(p, size));
  });

  it('não adiciona tamanho esgotado', () => {
    const p = PRODUCTS.find((x) => Object.values(x.stock).includes(0))!;
    const out = Object.keys(p.stock).find((s) => p.stock[s] === 0)!;
    expect(cartReducer(empty, { type: 'add', product: p, size: out, quantity: 1 }).items).toHaveLength(0);
  });

  it('troca de tamanho mesclando itens iguais', () => {
    const { p } = inStock();
    const [a, b] = Object.keys(p.stock).filter((s) => p.stock[s] > 3);
    let s = cartReducer(empty, { type: 'add', product: p, size: a, quantity: 1 });
    s = cartReducer(s, { type: 'add', product: p, size: b, quantity: 1 });
    s = cartReducer(s, { type: 'changeSize', product: p, from: a, to: b });
    expect(s.items).toEqual([{ productId: p.id, size: b, quantity: 2 }]);
  });

  it('edição limitada: 1 par por cliente', () => {
    const p = PRODUCTS.find((x) => x.limited && Object.values(x.stock).some((n) => n > 1))!;
    const size = Object.keys(p.stock).find((s) => p.stock[s] > 1)!;
    const s = cartReducer(empty, { type: 'add', product: p, size, quantity: 3 });
    expect(s.items[0].quantity).toBe(1);
  });
});

describe('totais e cupons', () => {
  const { p, size } = inStock(PRODUCTS.find((x) => x.slug === 'mesa-vulc-pro-noite'));
  const items = [{ productId: p.id, size, quantity: 1 }];

  it('cobra frete abaixo do mínimo e aplica cupom percentual', () => {
    const r = validateCoupon('bemvindo10', p.price);
    expect(r.ok).toBe(true);
    const t = computeTotals(items, getProduct, r.ok ? r.coupon : null, 20);
    expect(t.discount).toBeCloseTo(p.price * 0.1, 2);
    expect(t.shipping).toBe(20);
    expect(t.total).toBeCloseTo(p.price - t.discount + 20, 2);
  });

  it('rejeita cupom abaixo do valor mínimo', () => {
    expect(validateCoupon('SOLEVA150', 500).ok).toBe(false);
  });

  it('frete grátis só na entrega padrão', () => {
    const big = [{ productId: p.id, size, quantity: 2 }];
    expect(computeTotals(big, getProduct, null, 30, true).shipping).toBe(0);
    expect(computeTotals(big, getProduct, null, 50, false).shipping).toBe(50);
  });
});

describe('validação', () => {
  it('valida CPF pelos dígitos verificadores', () => {
    expect(isValidCPF('529.982.247-25')).toBe(true);
    expect(isValidCPF('529.982.247-24')).toBe(false);
    expect(isValidCPF('111.111.111-11')).toBe(false);
  });
  it('aponta campos obrigatórios do endereço', () => {
    const e = validateAddress({ cep: '0131', street: '', number: '', complement: '', district: '', city: '', state: 'XX' });
    expect(Object.keys(e).sort()).toEqual(['cep', 'city', 'district', 'number', 'state', 'street']);
  });
});

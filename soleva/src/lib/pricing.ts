import type { CartItem, Coupon, Product } from '../types';

/**
 * Cupons de demonstração. Em produção a validação PRECISA acontecer no back-end
 * (o front apenas exibe o desconto retornado pelo servidor).
 */
export const DEMO_COUPONS: Coupon[] = [
  { code: 'BEMVINDO10', label: '10% na primeira compra', type: 'percent', value: 10 },
  { code: 'SOLEVA150', label: 'R$ 150 off acima de R$ 1.200', type: 'fixed', value: 150, minSubtotal: 1200 },
  { code: 'FRETEGRATIS', label: 'Frete grátis', type: 'shipping', value: 0 },
];

export const FREE_SHIPPING_THRESHOLD = 799;

export type CouponResult = { ok: true; coupon: Coupon } | { ok: false; error: string };

export function validateCoupon(code: string, subtotal: number): CouponResult {
  const c = DEMO_COUPONS.find((x) => x.code === code.trim().toUpperCase());
  if (!c) return { ok: false, error: 'Cupom inválido ou expirado.' };
  if (c.minSubtotal && subtotal < c.minSubtotal) {
    return { ok: false, error: `Válido para compras acima de R$ ${c.minSubtotal.toLocaleString('pt-BR')}.` };
  }
  return { ok: true, coupon: c };
}

export interface Totals {
  subtotal: number;
  discount: number;
  shipping: number | null;
  freeShipping: boolean;
  total: number;
  itemCount: number;
}

export function computeTotals(
  items: CartItem[],
  lookup: (id: string) => Product | undefined,
  coupon: Coupon | null,
  shippingPrice: number | null,
  /** Frete grátis vale para a entrega padrão; opções expressas são cobradas. */
  freeShippingEligible = true,
): Totals {
  let subtotal = 0;
  let itemCount = 0;
  for (const it of items) {
    const p = lookup(it.productId);
    if (!p) continue;
    subtotal += p.price * it.quantity;
    itemCount += it.quantity;
  }
  subtotal = round(subtotal);

  // Cupom deixa de valer se o subtotal cair abaixo do mínimo.
  const active = coupon && (!coupon.minSubtotal || subtotal >= coupon.minSubtotal) ? coupon : null;
  let discount = 0;
  if (active?.type === 'percent') discount = round((subtotal * active.value) / 100);
  if (active?.type === 'fixed') discount = Math.min(active.value, subtotal);

  const freeShipping = active?.type === 'shipping' || subtotal - discount >= FREE_SHIPPING_THRESHOLD;
  const shipping = shippingPrice === null ? null : freeShipping && freeShippingEligible ? 0 : shippingPrice;
  const total = round(subtotal - discount + (shipping ?? 0));
  return { subtotal, discount, shipping, freeShipping, total, itemCount };
}

const round = (n: number) => Math.round(n * 100) / 100;

export const MAX_QTY_PER_ITEM = 5;

/** Quantidade máxima permitida para um item: limite por pedido e estoque. */
export const maxQuantity = (p: Product, size: string) =>
  Math.min(MAX_QTY_PER_ITEM, p.limited ? 1 : Infinity, p.stock[size] ?? 0);

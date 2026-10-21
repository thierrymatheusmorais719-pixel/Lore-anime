import type { CartItem, Product } from '../types';
import { maxQuantity } from '../lib/pricing';

export interface CartState {
  items: CartItem[];
  couponCode: string | null;
}

export type CartAction =
  | { type: 'add'; product: Product; size: string; quantity: number }
  | { type: 'remove'; productId: string; size: string }
  | { type: 'setQty'; product: Product; size: string; quantity: number }
  | { type: 'changeSize'; product: Product; from: string; to: string }
  | { type: 'coupon'; code: string | null }
  | { type: 'clear' }
  | { type: 'hydrate'; state: CartState };

const same = (a: CartItem, id: string, size: string) => a.productId === id && a.size === size;

export function cartReducer(state: CartState, action: CartAction): CartState {
  switch (action.type) {
    case 'add': {
      const { product, size } = action;
      const max = maxQuantity(product, size);
      if (max <= 0) return state;
      const existing = state.items.find((i) => same(i, product.id, size));
      if (existing) {
        const quantity = Math.min(max, existing.quantity + action.quantity);
        return { ...state, items: state.items.map((i) => (i === existing ? { ...i, quantity } : i)) };
      }
      return {
        ...state,
        items: [...state.items, { productId: product.id, size, quantity: Math.min(max, Math.max(1, action.quantity)) }],
      };
    }
    case 'remove':
      return { ...state, items: state.items.filter((i) => !same(i, action.productId, action.size)) };
    case 'setQty': {
      const max = maxQuantity(action.product, action.size);
      const quantity = Math.max(1, Math.min(max, Math.floor(action.quantity)));
      return {
        ...state,
        items: state.items.map((i) => (same(i, action.product.id, action.size) ? { ...i, quantity } : i)),
      };
    }
    case 'changeSize': {
      const { product, from, to } = action;
      if (from === to) return state;
      const max = maxQuantity(product, to);
      if (max <= 0) return state;
      const moving = state.items.find((i) => same(i, product.id, from));
      if (!moving) return state;
      const target = state.items.find((i) => same(i, product.id, to));
      if (target) {
        // Mescla com o item que já tinha a numeração de destino.
        return {
          ...state,
          items: state.items
            .filter((i) => i !== moving)
            .map((i) => (i === target ? { ...i, quantity: Math.min(max, i.quantity + moving.quantity) } : i)),
        };
      }
      return {
        ...state,
        items: state.items.map((i) => (i === moving ? { ...i, size: to, quantity: Math.min(max, i.quantity) } : i)),
      };
    }
    case 'coupon':
      return { ...state, couponCode: action.code };
    case 'clear':
      return { items: [], couponCode: null };
    case 'hydrate':
      return action.state;
  }
}

/** Remove itens que deixaram de existir ou ficaram sem estoque desde a última visita. */
export function sanitizeCart(state: CartState, lookup: (id: string) => Product | undefined): CartState {
  const items = state.items
    .map((i) => {
      const p = lookup(i.productId);
      if (!p) return null;
      const max = maxQuantity(p, i.size);
      return max > 0 ? { ...i, quantity: Math.min(i.quantity, max) } : null;
    })
    .filter((i): i is CartItem => i !== null);
  return { ...state, items };
}

import { createContext, useCallback, useContext, useEffect, useMemo, useReducer, useRef, useState, type ReactNode } from 'react';
import { getProduct } from '../data/catalog';
import { flyToCart } from '../lib/flyToCart';
import { computeTotals, validateCoupon, type Totals } from '../lib/pricing';
import { readJSON, writeJSON } from '../lib/storage';
import type { CartItem, Coupon, Product } from '../types';
import { cartReducer, sanitizeCart, type CartState } from './cart';

const CART_KEY = 'soleva:cart';
const FAV_KEY = 'soleva:favorites';
const HISTORY_KEY = 'soleva:search-history';

interface Toast {
  id: number;
  title: string;
  body?: string;
  product?: Product;
}

interface ShopContext {
  items: CartItem[];
  coupon: Coupon | null;
  totals: Totals;
  addToCart: (product: Product, size: string, quantity?: number, opts?: { from?: Element | null }) => void;
  removeFromCart: (productId: string, size: string) => void;
  setQuantity: (product: Product, size: string, quantity: number) => void;
  changeSize: (product: Product, from: string, to: string) => void;
  applyCoupon: (code: string) => string | null;
  removeCoupon: () => void;
  clearCart: () => void;

  favorites: string[];
  isFavorite: (id: string) => boolean;
  toggleFavorite: (product: Product) => void;

  history: string[];
  pushHistory: (q: string) => void;
  clearHistory: () => void;

  cartOpen: boolean;
  setCartOpen: (v: boolean) => void;
  searchOpen: boolean;
  setSearchOpen: (v: boolean) => void;

  toasts: Toast[];
  notify: (t: Omit<Toast, 'id'>) => void;
  dismiss: (id: number) => void;
}

const Ctx = createContext<ShopContext | null>(null);

const loadCart = (): CartState => sanitizeCart(readJSON<CartState>(CART_KEY, { items: [], couponCode: null }), getProduct);

export function ShopProvider({ children }: { children: ReactNode }) {
  const [cart, dispatch] = useReducer(cartReducer, undefined, loadCart);
  const [favorites, setFavorites] = useState<string[]>(() => readJSON(FAV_KEY, []));
  const [history, setHistory] = useState<string[]>(() => readJSON(HISTORY_KEY, []));
  const [cartOpen, setCartOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const toastId = useRef(0);

  useEffect(() => writeJSON(CART_KEY, cart), [cart]);
  useEffect(() => writeJSON(FAV_KEY, favorites), [favorites]);
  useEffect(() => writeJSON(HISTORY_KEY, history), [history]);

  // Mantém carrinho e favoritos sincronizados entre abas.
  useEffect(() => {
    const onStorage = (e: StorageEvent) => {
      if (e.key === CART_KEY) dispatch({ type: 'hydrate', state: loadCart() });
      if (e.key === FAV_KEY) setFavorites(readJSON(FAV_KEY, []));
    };
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  }, []);

  const dismiss = useCallback((id: number) => setToasts((t) => t.filter((x) => x.id !== id)), []);
  const notify = useCallback(
    (t: Omit<Toast, 'id'>) => {
      const id = ++toastId.current;
      setToasts((list) => [...list.slice(-2), { ...t, id }]);
      window.setTimeout(() => dismiss(id), 3800);
    },
    [dismiss],
  );

  const subtotalOnly = computeTotals(cart.items, getProduct, null, null).subtotal;
  const couponResult = cart.couponCode ? validateCoupon(cart.couponCode, subtotalOnly) : null;
  const coupon = couponResult?.ok ? couponResult.coupon : null;
  const totals = computeTotals(cart.items, getProduct, coupon, null);

  const value = useMemo<ShopContext>(
    () => ({
      items: cart.items,
      coupon,
      totals,
      addToCart: (product, size, quantity = 1, opts) => {
        dispatch({ type: 'add', product, size, quantity });
        // Com origem conhecida, o tênis voa até a sacola antes de abrir o carrinho.
        const delay = flyToCart(opts?.from);
        if (delay) window.setTimeout(() => setCartOpen(true), delay - 80);
        else setCartOpen(true);
      },
      removeFromCart: (productId, size) => dispatch({ type: 'remove', productId, size }),
      setQuantity: (product, size, quantity) => dispatch({ type: 'setQty', product, size, quantity }),
      changeSize: (product, from, to) => dispatch({ type: 'changeSize', product, from, to }),
      applyCoupon: (code) => {
        const r = validateCoupon(code, subtotalOnly);
        if (!r.ok) return r.error;
        dispatch({ type: 'coupon', code: r.coupon.code });
        return null;
      },
      removeCoupon: () => dispatch({ type: 'coupon', code: null }),
      clearCart: () => dispatch({ type: 'clear' }),

      favorites,
      isFavorite: (id) => favorites.includes(id),
      toggleFavorite: (product) => {
        const adding = !favorites.includes(product.id);
        setFavorites((f) => (adding ? [product.id, ...f] : f.filter((x) => x !== product.id)));
        notify({ title: adding ? 'Salvo nos favoritos' : 'Removido dos favoritos', product });
      },

      history,
      pushHistory: (q) => {
        const term = q.trim();
        if (term.length < 2) return;
        setHistory((h) => [term, ...h.filter((x) => x.toLowerCase() !== term.toLowerCase())].slice(0, 6));
      },
      clearHistory: () => setHistory([]),

      cartOpen,
      setCartOpen,
      searchOpen,
      setSearchOpen,

      toasts,
      notify,
      dismiss,
    }),
    [cart, favorites, history, cartOpen, searchOpen, toasts, notify, dismiss],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useShop() {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error('useShop precisa estar dentro de <ShopProvider>');
  return ctx;
}

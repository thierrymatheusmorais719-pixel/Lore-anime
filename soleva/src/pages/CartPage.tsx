import { useMemo, useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { PRODUCTS, getBrand, getProduct } from '../data/catalog';
import { FreeShippingBar } from '../components/CartDrawer';
import { Icon } from '../components/Icon';
import { CouponField, TotalsTable } from '../components/OrderSummary';
import { ProductCard } from '../components/ProductCard';
import { EmptyState, ProductMedia, QuantityInput } from '../components/ui';
import { useDocumentTitle } from '../hooks';
import { formatPrice } from '../lib/format';
import { computeTotals, maxQuantity } from '../lib/pricing';
import { isUpcoming } from '../lib/product';
import { isValidCEP, maskCEP } from '../lib/validation';
import { shippingProvider } from '../services/shipping';
import { useShop } from '../store/ShopProvider';
import type { ShippingOption } from '../types';

export function CartPage() {
  useDocumentTitle('Carrinho');
  const { items, coupon, removeFromCart, setQuantity, changeSize, isFavorite, toggleFavorite } = useShop();
  const [cep, setCep] = useState('');
  const [quote, setQuote] = useState<ShippingOption | null>(null);
  const [quoteState, setQuoteState] = useState<'idle' | 'loading' | 'error'>('idle');

  const totals = computeTotals(items, getProduct, coupon, quote?.price ?? null);
  const suggestions = useMemo(
    () => PRODUCTS.filter((p) => !items.some((i) => i.productId === p.id) && !isUpcoming(p)).sort((a, b) => b.popularity - a.popularity).slice(0, 4),
    [items],
  );

  const calc = async (e: FormEvent) => {
    e.preventDefault();
    if (!isValidCEP(cep)) return setQuoteState('error');
    setQuoteState('loading');
    try {
      const opts = await shippingProvider.quote(cep, items);
      setQuote(opts[0]);
      setQuoteState('idle');
    } catch {
      setQuoteState('error');
    }
  };

  if (items.length === 0) {
    return (
      <div className="container page-pad">
        <h1 className="display h1">Carrinho</h1>
        <EmptyState
          icon="bag"
          title="Seu carrinho está vazio"
          body="Que tal começar pelos lançamentos da semana?"
          action={
            <Link to="/loja?filtro=lancamento&ordem=novidades" className="btn btn-primary">
              Ver lançamentos <Icon name="arrowRight" size={18} className="arrow" />
            </Link>
          }
        />
        <section className="section">
          <h2 className="display h3">Mais procurados</h2>
          <div className="grid-4" style={{ marginTop: 24 }}>
            {suggestions.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      </div>
    );
  }

  return (
    <div className="container page-pad">
      <h1 className="display h1">
        Carrinho <span className="mono muted">({totals.itemCount})</span>
      </h1>
      <div className="cart-grid">
        <div>
          <FreeShippingBar amount={totals.subtotal - totals.discount} />
          <ul className="cart-lines">
            {items.map((it) => {
              const p = getProduct(it.productId);
              if (!p) return null;
              const max = maxQuantity(p, it.size);
              return (
                <li key={`${it.productId}-${it.size}`} className="cart-line">
                  <Link to={`/produto/${p.slug}`} className="cart-thumb">
                    <ProductMedia product={p} />
                  </Link>
                  <div className="cart-line-info">
                    <span className="mono muted">{getBrand(p.brandId)?.name}</span>
                    <Link to={`/produto/${p.slug}`} className="cart-line-name">
                      {p.name} “{p.model}”
                    </Link>
                    <span className="muted small">{p.colorway}</span>
                    <div className="cart-line-controls">
                      <label className="line-size">
                        <span className="sr-only">Tamanho</span>
                        <select value={it.size} onChange={(e) => changeSize(p, it.size, e.target.value)}>
                          {Object.keys(p.stock).map((s) => (
                            <option key={s} value={s} disabled={p.stock[s] === 0}>
                              Tam. {s}
                              {p.stock[s] === 0 ? ' — esgotado' : ''}
                            </option>
                          ))}
                        </select>
                        <Icon name="chevronDown" size={14} />
                      </label>
                      <QuantityInput size="sm" value={it.quantity} max={max} onChange={(q) => setQuantity(p, it.size, q)} />
                    </div>
                    {p.limited && <span className="mono small warn">Limite de 1 par por cliente</span>}
                    {!p.limited && it.quantity >= max && <span className="mono small warn">Quantidade máxima disponível</span>}
                  </div>
                  <div className="cart-line-end">
                    <strong>{formatPrice(p.price * it.quantity)}</strong>
                    {it.quantity > 1 && <span className="muted small">{formatPrice(p.price)} cada</span>}
                    <div className="cart-line-actions">
                      <button className="link-btn" onClick={() => !isFavorite(p.id) && toggleFavorite(p)}>
                        <Icon name="heart" size={14} filled={isFavorite(p.id)} /> {isFavorite(p.id) ? 'Nos favoritos' : 'Salvar'}
                      </button>
                      <button className="link-btn" onClick={() => removeFromCart(p.id, it.size)}>
                        <Icon name="trash" size={14} /> Remover
                      </button>
                    </div>
                  </div>
                </li>
              );
            })}
          </ul>
        </div>

        <aside className="summary">
          <h2 className="display h3">Resumo</h2>
          <CouponField />
          <form className="ship-calc-row" onSubmit={calc}>
            <input className="input" inputMode="numeric" placeholder="CEP para frete" value={cep} onChange={(e) => setCep(maskCEP(e.target.value))} aria-label="CEP" aria-invalid={quoteState === 'error'} />
            <button className="btn btn-outline btn-sm" disabled={quoteState === 'loading'}>
              {quoteState === 'loading' ? <span className="spinner" /> : 'Calcular'}
            </button>
          </form>
          {quoteState === 'error' && <p className="field-error">CEP inválido.</p>}
          {quote && (
            <p className="muted small">
              {quote.label}: {quote.days[0]}–{quote.days[1]} dias úteis (estimativa)
            </p>
          )}
          <TotalsTable totals={totals} />
          <Link to="/checkout" className="btn btn-primary btn-block">
            <Icon name="lock" size={16} /> Finalizar compra
          </Link>
          <Link to="/loja" className="btn btn-outline btn-block">
            Continuar comprando
          </Link>
          <ul className="pdp-perks small">
            <li><Icon name="returns" size={16} /> Primeira troca grátis em 30 dias</li>
            <li><Icon name="shield" size={16} /> Compra protegida e autenticidade garantida</li>
          </ul>
        </aside>
      </div>
    </div>
  );
}

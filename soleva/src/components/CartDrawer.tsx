import { Link, useNavigate } from 'react-router-dom';
import { getBrand, getProduct } from '../data/catalog';
import { useEscape, useLockBody } from '../hooks';
import { formatPrice } from '../lib/format';
import { FREE_SHIPPING_THRESHOLD, maxQuantity } from '../lib/pricing';
import { useShop } from '../store/ShopProvider';
import { Icon } from './Icon';
import { EmptyState, ProductMedia, QuantityInput } from './ui';

export function FreeShippingBar({ amount }: { amount: number }) {
  const left = Math.max(0, FREE_SHIPPING_THRESHOLD - amount);
  const pct = Math.min(100, (amount / FREE_SHIPPING_THRESHOLD) * 100);
  return (
    <div className="ship-bar">
      <p>
        {left > 0 ? (
          <>
            Faltam <strong>{formatPrice(left)}</strong> para o frete grátis
          </>
        ) : (
          <>
            <Icon name="check" size={16} /> Você ganhou <strong>frete grátis</strong>
          </>
        )}
      </p>
      <div className="ship-bar-track">
        <span style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

export function CartDrawer() {
  const { cartOpen, setCartOpen, items, totals, removeFromCart, setQuantity, changeSize } = useShop();
  const navigate = useNavigate();
  const close = () => setCartOpen(false);
  useLockBody(cartOpen);
  useEscape(cartOpen, close);

  return (
    <>
      <div className={`overlay ${cartOpen ? 'open' : ''}`} onClick={close} aria-hidden="true" />
      <aside className={`drawer ${cartOpen ? 'open' : ''}`} aria-label="Carrinho" aria-hidden={!cartOpen} inert={!cartOpen}>
        <header className="drawer-head">
          <h2 className="display h3">
            Carrinho <span className="mono muted">({totals.itemCount})</span>
          </h2>
          <button className="icon-btn" onClick={close} aria-label="Fechar carrinho">
            <Icon name="close" />
          </button>
        </header>

        {items.length === 0 ? (
          <div className="drawer-empty">
            <EmptyState
              icon="bag"
              title="Seu carrinho está vazio"
              body="Os pares que você adicionar aparecem aqui."
              action={
                <Link to="/loja" className="btn btn-primary" onClick={close}>
                  Explorar a loja <Icon name="arrowRight" size={18} className="arrow" />
                </Link>
              }
            />
          </div>
        ) : (
          <>
            <div className="drawer-body">
              <FreeShippingBar amount={totals.subtotal - totals.discount} />
              <ul className="line-items">
                {items.map((it) => {
                  const p = getProduct(it.productId);
                  if (!p) return null;
                  return (
                    <li key={`${it.productId}-${it.size}`} className="line-item">
                      <Link to={`/produto/${p.slug}`} className="line-thumb" onClick={close}>
                        <ProductMedia product={p} />
                      </Link>
                      <div className="line-info">
                        <span className="mono muted">{getBrand(p.brandId)?.name}</span>
                        <Link to={`/produto/${p.slug}`} className="line-name" onClick={close}>
                          {p.name} “{p.model}”
                        </Link>
                        <div className="line-controls">
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
                          <QuantityInput size="sm" value={it.quantity} max={maxQuantity(p, it.size)} onChange={(q) => setQuantity(p, it.size, q)} />
                        </div>
                      </div>
                      <div className="line-end">
                        <strong>{formatPrice(p.price * it.quantity)}</strong>
                        <button className="line-remove" onClick={() => removeFromCart(p.id, it.size)} aria-label={`Remover ${p.name} tamanho ${it.size}`}>
                          <Icon name="trash" size={16} />
                        </button>
                      </div>
                    </li>
                  );
                })}
              </ul>
            </div>
            <footer className="drawer-foot">
              <div className="row">
                <span>Subtotal</span>
                <strong>{formatPrice(totals.subtotal)}</strong>
              </div>
              {totals.discount > 0 && (
                <div className="row muted">
                  <span>Desconto</span>
                  <span>− {formatPrice(totals.discount)}</span>
                </div>
              )}
              <p className="muted small">Frete e cupons calculados no carrinho e no checkout.</p>
              <div className="drawer-actions">
                <Link to="/carrinho" className="btn btn-outline" onClick={close}>
                  Ver carrinho
                </Link>
                <button
                  className="btn btn-primary"
                  onClick={() => {
                    close();
                    navigate('/checkout');
                  }}
                >
                  Finalizar compra
                </button>
              </div>
            </footer>
          </>
        )}
      </aside>
    </>
  );
}

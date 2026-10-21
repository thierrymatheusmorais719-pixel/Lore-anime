import { useState, type FormEvent, type ReactNode } from 'react';
import { getBrand, getProduct } from '../data/catalog';
import { formatPrice } from '../lib/format';
import { DEMO_COUPONS, type Totals } from '../lib/pricing';
import { useShop } from '../store/ShopProvider';
import { Icon } from './Icon';
import { ProductMedia } from './ui';

export function CouponField() {
  const { coupon, applyCoupon, removeCoupon } = useShop();
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    if (!code.trim()) return setError('Digite um cupom.');
    const err = applyCoupon(code);
    setError(err);
    if (!err) setCode('');
  };

  if (coupon) {
    return (
      <div className="coupon-applied">
        <Icon name="check" size={16} />
        <div>
          <strong className="mono">{coupon.code}</strong>
          <span className="muted small">{coupon.label}</span>
        </div>
        <button className="link-btn" onClick={removeCoupon}>
          Remover
        </button>
      </div>
    );
  }

  return (
    <form className="coupon" onSubmit={submit} noValidate>
      <label htmlFor="coupon" className="sr-only">
        Cupom de desconto
      </label>
      <input id="coupon" className="input" placeholder="Cupom de desconto" value={code} onChange={(e) => setCode(e.target.value.toUpperCase())} aria-invalid={Boolean(error)} />
      <button className="btn btn-outline btn-sm">Aplicar</button>
      {error && <p className="field-error">{error}</p>}
      <p className="field-hint">
        Cupons de teste: {DEMO_COUPONS.map((c) => c.code).join(', ')}
      </p>
    </form>
  );
}

export function TotalsTable({ totals, shippingLabel }: { totals: Totals; shippingLabel?: ReactNode }) {
  return (
    <dl className="totals">
      <div>
        <dt>Subtotal ({totals.itemCount} {totals.itemCount === 1 ? 'item' : 'itens'})</dt>
        <dd>{formatPrice(totals.subtotal)}</dd>
      </div>
      {totals.discount > 0 && (
        <div className="discount">
          <dt>Desconto</dt>
          <dd>− {formatPrice(totals.discount)}</dd>
        </div>
      )}
      <div>
        <dt>Frete</dt>
        <dd>{totals.shipping === null ? shippingLabel ?? <span className="muted">Calculado no checkout</span> : totals.shipping === 0 ? <span className="free">Grátis</span> : formatPrice(totals.shipping)}</dd>
      </div>
      <div className="grand">
        <dt>Total</dt>
        <dd>{formatPrice(totals.total)}</dd>
      </div>
    </dl>
  );
}

export function MiniLines() {
  const { items } = useShop();
  return (
    <ul className="mini-lines">
      {items.map((it) => {
        const p = getProduct(it.productId);
        if (!p) return null;
        return (
          <li key={`${it.productId}-${it.size}`}>
            <div className="mini-thumb">
              <ProductMedia product={p} />
              <span className="mini-qty">{it.quantity}</span>
            </div>
            <div>
              <span className="mono muted">{getBrand(p.brandId)?.name}</span>
              <strong>
                {p.name} “{p.model}”
              </strong>
              <span className="muted small">Tam. {it.size}</span>
            </div>
            <span>{formatPrice(p.price * it.quantity)}</span>
          </li>
        );
      })}
    </ul>
  );
}

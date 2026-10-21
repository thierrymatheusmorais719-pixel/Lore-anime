import { useShop } from '../store/ShopProvider';
import { Icon } from './Icon';
import { ProductMedia } from './ui';

export function Toasts() {
  const { toasts, dismiss } = useShop();
  return (
    <div className="toasts" role="status" aria-live="polite">
      {toasts.map((t) => (
        <div key={t.id} className="toast">
          {t.product && (
            <div className="toast-thumb">
              <ProductMedia product={t.product} />
            </div>
          )}
          <div>
            <strong>{t.title}</strong>
            {t.body && <p>{t.body}</p>}
          </div>
          <button onClick={() => dismiss(t.id)} aria-label="Fechar aviso" className="icon-btn">
            <Icon name="close" size={16} />
          </button>
        </div>
      ))}
    </div>
  );
}

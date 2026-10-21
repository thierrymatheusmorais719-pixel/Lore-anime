import { useState } from 'react';
import { Link } from 'react-router-dom';
import { getBrand } from '../data/catalog';
import { availableSizes, isUpcoming } from '../lib/product';
import { useShop } from '../store/ShopProvider';
import type { Product } from '../types';
import { Icon } from './Icon';
import { Badges, Modal, Price, ProductMedia, Stars } from './ui';

/** Visualização rápida: escolher tamanho e adicionar sem sair da lista. */
export function QuickView({ product, open, onClose }: { product: Product; open: boolean; onClose: () => void }) {
  const { addToCart } = useShop();
  const [size, setSize] = useState<string | null>(null);
  const [error, setError] = useState(false);
  const brand = getBrand(product.brandId);
  const upcoming = isUpcoming(product);
  const available = availableSizes(product);

  const add = () => {
    if (!size) return setError(true);
    const from = document.querySelector('.quickview-media img');
    onClose();
    addToCart(product, size, 1, { from });
  };

  return (
    <Modal open={open} onClose={onClose} title="Visualização rápida" wide>
      <div className="quickview">
        <div className="quickview-media">
          <ProductMedia product={product} sizes="(max-width: 700px) 90vw, 420px" />
        </div>
        <div className="quickview-info">
          <Badges product={product} max={3} />
          <span className="mono muted">{brand?.name}</span>
          <h3 className="display quickview-title">
            {product.name} <span>“{product.model}”</span>
          </h3>
          {product.reviewCount > 0 && (
            <span className="quickview-rating">
              <Stars value={product.rating} /> <span className="muted small">{product.reviewCount} avaliações</span>
            </span>
          )}
          <Price product={product} size="lg" showInstallments />
          {!upcoming && available.length > 0 ? (
            <>
              <div className="size-grid quickview-sizes" role="radiogroup" aria-label="Tamanho">
                {Object.entries(product.stock).map(([s, n]) => (
                  <button
                    key={s}
                    role="radio"
                    aria-checked={size === s}
                    disabled={n === 0}
                    className={`size-chip ${size === s ? 'on' : ''} ${n === 0 ? 'out' : ''}`}
                    onClick={() => {
                      setSize(s);
                      setError(false);
                    }}
                  >
                    {s}
                  </button>
                ))}
              </div>
              {error && (
                <p className="field-error" role="alert">
                  <Icon name="alert" size={14} /> Escolha um tamanho.
                </p>
              )}
              <button className="btn btn-primary btn-block" onClick={add}>
                <Icon name="bag" size={18} /> Adicionar ao carrinho
              </button>
            </>
          ) : (
            <p className="muted">{upcoming ? 'Este modelo ainda não foi lançado.' : 'Esgotado no momento.'}</p>
          )}
          <Link to={`/produto/${product.slug}`} className="link" onClick={onClose}>
            Ver todos os detalhes <Icon name="arrowRight" size={16} />
          </Link>
        </div>
      </div>
    </Modal>
  );
}

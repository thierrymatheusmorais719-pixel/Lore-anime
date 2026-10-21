import { useState } from 'react';
import { Link } from 'react-router-dom';
import { getBrand } from '../data/catalog';
import { formatDate } from '../lib/format';
import { availableSizes, isUpcoming } from '../lib/product';
import { useShop } from '../store/ShopProvider';
import type { Product } from '../types';
import { Icon } from './Icon';
import { QuickView } from './QuickView';
import { Badges, Price, ProductMedia, Stars } from './ui';

interface Props {
  product: Product;
  variant?: 'default' | 'dark' | 'compact';
  rank?: number;
  quickAdd?: boolean;
}

// Inclinação 3D e reflexo de luz seguindo o mouse.
function tilt(e: React.MouseEvent<HTMLDivElement>) {
  const el = e.currentTarget;
  const r = el.getBoundingClientRect();
  const x = (e.clientX - r.left) / r.width;
  const y = (e.clientY - r.top) / r.height;
  el.style.setProperty('--ry', `${(x - 0.5) * 10}deg`);
  el.style.setProperty('--rx', `${(0.5 - y) * 8}deg`);
  el.style.setProperty('--gx', `${x * 100}%`);
  el.style.setProperty('--gy', `${y * 100}%`);
}
function resetTilt(e: React.MouseEvent<HTMLDivElement>) {
  e.currentTarget.style.setProperty('--rx', '0deg');
  e.currentTarget.style.setProperty('--ry', '0deg');
}

export function ProductCard({ product, variant = 'default', rank, quickAdd = true }: Props) {
  const { isFavorite, toggleFavorite, addToCart } = useShop();
  const brand = getBrand(product.brandId);
  const upcoming = isUpcoming(product);
  const sizes = availableSizes(product);
  const fav = isFavorite(product.id);
  const href = `/produto/${product.slug}`;
  const [quick, setQuick] = useState(false);

  return (
    <article className={`card card-${variant}`}>
      <div className="card-media" onMouseMove={tilt} onMouseLeave={resetTilt}>
        <Link to={href} className="card-media-link" data-cursor="Ver" aria-label={`${brand?.name} ${product.name} ${product.model}`}>
          <ProductMedia product={product} className="card-art card-art-main" />
          {product.cutout ? (
            <ProductMedia product={product} prefer="photo" className="card-art card-art-alt card-photo-reveal" />
          ) : (
            (!product.images || product.images.length > 1) && (
              <ProductMedia product={product} view="medial" index={1} className="card-art card-art-alt" />
            )
          )}
        </Link>
        <Badges product={product} />
        {rank !== undefined && <span className="card-rank">{String(rank).padStart(2, '0')}</span>}
        <button
          className={`card-fav ${fav ? 'on' : ''}`}
          onClick={() => toggleFavorite(product)}
          aria-pressed={fav}
          aria-label={fav ? 'Remover dos favoritos' : 'Adicionar aos favoritos'}
        >
          <Icon name="heart" size={18} filled={fav} />
        </button>
        <button className="card-eye" onClick={() => setQuick(true)} aria-label={`Visualização rápida de ${product.name} ${product.model}`}>
          <Icon name="eye" size={18} />
        </button>
        {quickAdd && !upcoming && sizes.length > 0 && (
          <div className="card-quick" aria-label="Adicionar rápido">
            <span className="mono">Adicionar rápido</span>
            <div className="card-quick-sizes">
              {sizes.slice(0, 8).map((s) => (
                <button
                  key={s}
                  onClick={(e) => addToCart(product, s, 1, { from: e.currentTarget.closest('.card')?.querySelector('.card-art-main') })}
                  aria-label={`Adicionar tamanho ${s} ao carrinho`}
                >
                  {s}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>
      <Link to={href} className="card-info">
        <div className="card-meta">
          <span className="mono card-brand">{brand?.name}</span>
          {product.reviewCount > 0 ? (
            <span className="card-rating">
              <Stars value={product.rating} size={11} />
              <span className="mono">({product.reviewCount})</span>
            </span>
          ) : upcoming ? (
            <span className="mono card-drop">
              <Icon name="clock" size={12} /> {formatDate(product.releaseDate)}
            </span>
          ) : null}
        </div>
        <h3 className="card-title">
          {product.name} <span>“{product.model}”</span>
        </h3>
        <p className="card-colorway">{product.colorway}</p>
        <Price product={product} />
      </Link>
      {quick && <QuickView product={product} open={quick} onClose={() => setQuick(false)} />}
    </article>
  );
}

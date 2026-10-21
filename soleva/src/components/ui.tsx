import { useEffect, useRef, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { getBrand } from '../data/catalog';
import { useCountdown, useEscape, useLockBody, useReveal } from '../hooks';
import { formatPrice, installments } from '../lib/format';
import { productBadges } from '../lib/product';
import type { Product } from '../types';
import { Icon } from './Icon';
import { SneakerArt, VIEW_LABELS, type SneakerView } from './SneakerArt';

export function Reveal({ children, delay = 0, className = '', as: Tag = 'div' }: { children: ReactNode; delay?: number; className?: string; as?: 'div' | 'section' | 'li' }) {
  const ref = useReveal<HTMLDivElement>();
  return (
    <Tag ref={ref as never} className={`reveal ${className}`} style={{ ['--d' as string]: `${delay}s` }}>
      {children}
    </Tag>
  );
}

/** Imagem do produto: foto real quando houver, senão o render vetorial. */
export function ProductMedia({ product, view = 'lateral', index = 0, className }: { product: Product; view?: SneakerView; index?: number; className?: string }) {
  const photo = product.images?.[index] ?? product.images?.[0];
  const brand = getBrand(product.brandId)?.name.toUpperCase() ?? '';
  const alt = `${brand} ${product.name} ${product.model} — ${VIEW_LABELS[view]}`;
  if (photo) return <img src={photo} alt={product.images?.[index] ? alt : alt.replace(VIEW_LABELS[view], 'foto')} className={`photo ${className ?? ''}`} loading="lazy" decoding="async" />;
  return <SneakerArt palette={product.palette} silhouette={product.silhouette} view={view} brandMark={brand.split(' ')[0]} className={className} title={alt} />;
}

export function Stars({ value, size = 14 }: { value: number; size?: number }) {
  return (
    <span className="stars" aria-label={`${value.toFixed(1)} de 5 estrelas`} role="img">
      {[0, 1, 2, 3, 4].map((i) => {
        const fill = Math.max(0, Math.min(1, value - i));
        return (
          <span key={i} className="star" style={{ width: size, height: size }}>
            <Icon name="star" size={size} />
            <span style={{ width: `${fill * 100}%` }}>
              <Icon name="star" size={size} filled />
            </span>
          </span>
        );
      })}
    </span>
  );
}

export function Price({ product, size = 'md', showInstallments = false }: { product: Product; size?: 'md' | 'lg'; showInstallments?: boolean }) {
  const inst = installments(product.price);
  return (
    <div className={`price price-${size}`}>
      <div className="price-row">
        <span className="price-now">{formatPrice(product.price)}</span>
        {product.compareAtPrice && <s className="price-was">{formatPrice(product.compareAtPrice)}</s>}
      </div>
      {showInstallments && inst.count > 1 && (
        <span className="price-inst">
          ou {inst.count}x de {formatPrice(inst.value)} sem juros
        </span>
      )}
    </div>
  );
}

export function Badges({ product, max = 2 }: { product: Product; max?: number }) {
  const badges = productBadges(product).slice(0, max);
  if (!badges.length) return null;
  return (
    <div className="badges">
      {badges.map((b) => (
        <span key={b.label} className={`badge badge-${b.tone}`}>
          {b.label}
        </span>
      ))}
    </div>
  );
}

export function SectionHeader({ eyebrow, title, action, dark }: { eyebrow?: string; title: ReactNode; action?: { label: string; to: string }; dark?: boolean }) {
  return (
    <div className={`section-head ${dark ? 'on-dark' : ''}`}>
      <div>
        {eyebrow && <span className="eyebrow">{eyebrow}</span>}
        <h2 className="display h2">{title}</h2>
      </div>
      {action && (
        <Link to={action.to} className="link">
          {action.label} <Icon name="arrowRight" size={16} />
        </Link>
      )}
    </div>
  );
}

export function Countdown({ target, compact = false }: { target: number; compact?: boolean }) {
  const t = useCountdown(target);
  const parts: [number, string][] = [
    [t.days, 'dias'],
    [t.hours, 'h'],
    [t.minutes, 'min'],
    [t.seconds, 's'],
  ];
  return (
    <div className={`countdown ${compact ? 'compact' : ''}`} role="timer" aria-live="off">
      {parts.map(([v, l]) => (
        <div key={l}>
          <strong>{String(v).padStart(2, '0')}</strong>
          <span>{l}</span>
        </div>
      ))}
    </div>
  );
}

export function Modal({ open, onClose, title, children, wide }: { open: boolean; onClose: () => void; title: string; children: ReactNode; wide?: boolean }) {
  const ref = useRef<HTMLDivElement>(null);
  useLockBody(open);
  useEscape(open, onClose);
  useEffect(() => {
    if (open) ref.current?.focus();
  }, [open]);
  if (!open) return null;
  return (
    <div className="modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className={`modal ${wide ? 'wide' : ''}`} role="dialog" aria-modal="true" aria-label={title} tabIndex={-1} ref={ref}>
        <header className="modal-head">
          <h3 className="display h3">{title}</h3>
          <button className="icon-btn" onClick={onClose} aria-label="Fechar">
            <Icon name="close" />
          </button>
        </header>
        <div className="modal-body">{children}</div>
      </div>
    </div>
  );
}

export function QuantityInput({ value, max, onChange, size = 'md' }: { value: number; max: number; onChange: (v: number) => void; size?: 'sm' | 'md' }) {
  return (
    <div className={`qty qty-${size}`} role="group" aria-label="Quantidade">
      <button type="button" onClick={() => onChange(value - 1)} disabled={value <= 1} aria-label="Diminuir quantidade">
        <Icon name="minus" size={16} />
      </button>
      <output aria-live="polite">{value}</output>
      <button type="button" onClick={() => onChange(value + 1)} disabled={value >= max} aria-label="Aumentar quantidade">
        <Icon name="plus" size={16} />
      </button>
    </div>
  );
}

export function EmptyState({ icon, title, body, action }: { icon: Parameters<typeof Icon>[0]['name']; title: string; body?: ReactNode; action?: ReactNode }) {
  return (
    <div className="empty">
      <div className="empty-icon">
        <Icon name={icon} size={28} />
      </div>
      <h3 className="display h3">{title}</h3>
      {body && <p className="muted">{body}</p>}
      {action}
    </div>
  );
}

export function SkeletonCard() {
  return (
    <div className="card card-skeleton" aria-hidden="true">
      <div className="card-media skeleton" />
      <div className="skeleton" style={{ height: 12, width: '40%', marginTop: 16 }} />
      <div className="skeleton" style={{ height: 18, width: '75%', marginTop: 10 }} />
      <div className="skeleton" style={{ height: 14, width: '30%', marginTop: 12 }} />
    </div>
  );
}

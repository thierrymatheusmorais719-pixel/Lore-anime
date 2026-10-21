import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { BRANDS, CATEGORIES, COLLECTIONS, PRODUCTS, getBrand, getProductBySlug } from '../data/catalog';
import { Icon } from '../components/Icon';
import { ProductCard } from '../components/ProductCard';
import { Countdown, ProductMedia, Reveal, SectionHeader } from '../components/ui';
import { useDocumentTitle } from '../hooks';
import { formatDate, formatPrice } from '../lib/format';
import { isNew, isUpcoming, releaseTimestamp, totalStock } from '../lib/product';
import { isValidEmail } from '../lib/validation';
import { subscribe } from '../services/newsletter';
import type { Product } from '../types';

const HERO_SLUGS = ['soleva-aero-01-phantom', 'orbit-apex-high-royal', 'northline-polar-x-limited'];
const HERO_COPY: Record<string, { kicker: string; line1: string; line2: string; specs: [string, string][] }> = {
  'soleva-aero-01-phantom': {
    kicker: 'Drop 001 · Disponível agora',
    line1: 'Aero 01',
    line2: 'Phantom',
    specs: [['Peso', '286 g'], ['Drop', '8 mm'], ['Espuma', 'SVX supercrítica']],
  },
  'orbit-apex-high-royal': {
    kicker: 'Arquivo 01 · Reedição',
    line1: 'Apex High',
    line2: 'Royal',
    specs: [['Cano', 'Alto'], ['Couro', 'Semi-brilho'], ['Ano', '1985']],
  },
  'northline-polar-x-limited': {
    kicker: 'Edição numerada · 600 pares',
    line1: 'Polar X',
    line2: 'Aurora',
    specs: [['Placa', 'Carbono'], ['Peso', '198 g'], ['Espuma', 'PEBA']],
  },
};

export function Home() {
  useDocumentTitle('');
  return (
    <>
      <Hero />
      <BrandMarquee />
      <Launches />
      <Categories />
      <BestSellers />
      <NextDrop />
      <Collections />
      <Rares />
      <PromoBanner />
      <Featured />
      <Brands />
      <Newsletter />
    </>
  );
}

/* ---------------- Hero ---------------- */

function Hero() {
  const slides = useMemo(() => HERO_SLUGS.map((s) => getProductBySlug(s)!).filter(Boolean), []);
  const [i, setI] = useState(0);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    if (paused) return;
    const t = window.setTimeout(() => setI((x) => (x + 1) % slides.length), 7000);
    return () => window.clearTimeout(t);
  }, [i, paused, slides.length]);

  const p = slides[i];
  const copy = HERO_COPY[p.slug];
  const brand = getBrand(p.brandId)!;

  return (
    <section className="hero dark" onMouseEnter={() => setPaused(true)} onMouseLeave={() => setPaused(false)} aria-roledescription="carrossel" aria-label="Destaques">
      <div className="hero-grid-bg" aria-hidden="true" />
      <div className="container hero-inner">
        <div className="hero-copy" key={p.id}>
          <span className="eyebrow hero-anim" style={{ ['--d' as string]: '0s' }}>
            {copy.kicker}
          </span>
          <h1 className="display hero-title">
            <span className="hero-anim" style={{ ['--d' as string]: '.05s' }}>{copy.line1}</span>
            <span className="hero-anim outline" style={{ ['--d' as string]: '.12s' }}>{copy.line2}</span>
          </h1>
          <p className="lead hero-anim" style={{ ['--d' as string]: '.2s' }}>
            {p.description.split('. ')[0]}.
          </p>
          <div className="hero-cta hero-anim" style={{ ['--d' as string]: '.28s' }}>
            <Link to={`/produto/${p.slug}`} className="btn btn-primary">
              Comprar — {formatPrice(p.price)} <Icon name="arrowRight" size={18} className="arrow" />
            </Link>
            <Link to={`/loja?marca=${brand.id}`} className="btn btn-outline">
              Ver {brand.name}
            </Link>
          </div>
        </div>

        <div className="hero-visual" key={`v-${p.id}`}>
          <div className="hero-halo" style={{ background: `radial-gradient(closest-side, ${p.palette.accent}33, transparent)` }} />
          <span className="hero-index display" aria-hidden="true">
            0{i + 1}
          </span>
          <div className={`hero-shoe ${p.images?.length ? 'has-photo' : ''}`}>
            <ProductMedia product={p} />
          </div>
          <dl className="hero-specs">
            {copy.specs.map(([k, v]) => (
              <div key={k}>
                <dt className="mono">{k}</dt>
                <dd>{v}</dd>
              </div>
            ))}
          </dl>
        </div>
      </div>

      <div className="container hero-nav">
        {slides.map((s, idx) => (
          <button key={s.id} className={`hero-dot ${idx === i ? 'active' : ''} ${paused ? 'paused' : ''}`} onClick={() => setI(idx)} aria-label={`Destaque ${idx + 1}: ${s.name} ${s.model}`} aria-current={idx === i}>
            <span className="mono">0{idx + 1}</span>
            <span className="hero-dot-label">
              {s.name} “{s.model}”
            </span>
            <span className="hero-dot-bar">
              <span />
            </span>
          </button>
        ))}
      </div>
    </section>
  );
}

function BrandMarquee() {
  const items = [...BRANDS, ...BRANDS];
  return (
    <div className="marquee" aria-hidden="true">
      <div className="marquee-track">
        {items.map((b, i) => (
          <span key={i}>
            {b.name}
            <svg viewBox="0 0 10 10" width="10" height="10">
              <rect x="2" y="2" width="6" height="6" transform="rotate(45 5 5)" fill="currentColor" />
            </svg>
          </span>
        ))}
      </div>
    </div>
  );
}

/* ---------------- Lançamentos ---------------- */

function Rail({ children, label }: { children: React.ReactNode; label: string }) {
  const ref = useRef<HTMLDivElement>(null);
  const scroll = (dir: number) => ref.current?.scrollBy({ left: dir * ref.current.clientWidth * 0.8, behavior: 'smooth' });
  return (
    <div className="rail-wrap">
      <div className="rail" ref={ref} role="list" aria-label={label}>
        {children}
      </div>
      <div className="rail-controls">
        <button className="icon-btn bordered" onClick={() => scroll(-1)} aria-label="Anterior">
          <Icon name="arrowLeft" />
        </button>
        <button className="icon-btn bordered" onClick={() => scroll(1)} aria-label="Próximo">
          <Icon name="arrowRight" />
        </button>
      </div>
    </div>
  );
}

function Launches() {
  const items = useMemo(
    () => PRODUCTS.filter((p) => isNew(p) || isUpcoming(p)).sort((a, b) => releaseTimestamp(b) - releaseTimestamp(a)),
    [],
  );
  return (
    <section className="section">
      <div className="container">
        <Reveal>
          <SectionHeader eyebrow="Novidades da semana" title="Lançamentos" action={{ label: 'Ver todos', to: '/loja?filtro=lancamento&ordem=novidades' }} />
        </Reveal>
        <Reveal delay={0.1}>
          <Rail label="Lançamentos">
            {items.map((p) => (
              <div role="listitem" key={p.id} className="rail-item">
                <ProductCard product={p} />
              </div>
            ))}
          </Rail>
        </Reveal>
      </div>
    </section>
  );
}

/* ---------------- Categorias ---------------- */

function Categories() {
  const tiles = CATEGORIES.map((c) => {
    const items = PRODUCTS.filter((p) => p.category === c.id);
    const hero = [...items].sort((a, b) => b.popularity - a.popularity)[0];
    return { ...c, count: items.length, hero };
  });
  return (
    <section className="section section-tight">
      <div className="container">
        <Reveal>
          <SectionHeader eyebrow="Compre por estilo" title="Categorias" />
        </Reveal>
        <div className="cat-grid">
          {tiles.map((t, idx) => (
            <Reveal key={t.id} delay={idx * 0.06} className={`cat-tile cat-${idx}`}>
              <Link to={`/loja/${t.id}`} className={idx === 0 ? 'dark' : ''}>
                <div className="cat-text">
                  <span className="mono">{String(idx + 1).padStart(2, '0')} — {t.count} modelos</span>
                  <h3 className="display">{t.name}</h3>
                  <p>{t.blurb}</p>
                </div>
                {t.hero && (
                  <div className="cat-art">
                    <ProductMedia product={t.hero} />
                  </div>
                )}
                <span className="cat-go" aria-hidden="true">
                  <Icon name="arrowUpRight" size={20} />
                </span>
              </Link>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ---------------- Mais vendidos ---------------- */

function BestSellers() {
  const items = useMemo(
    () => PRODUCTS.filter((p) => !isUpcoming(p) && !p.limited).sort((a, b) => b.reviewCount * b.rating - a.reviewCount * a.rating).slice(0, 4),
    [],
  );
  return (
    <section className="section">
      <div className="container">
        <Reveal>
          <SectionHeader eyebrow="Os favoritos da comunidade" title="Mais vendidos" action={{ label: 'Ranking completo', to: '/loja?ordem=populares' }} />
        </Reveal>
        <div className="grid-4">
          {items.map((p, i) => (
            <Reveal key={p.id} delay={i * 0.07}>
              <ProductCard product={p} rank={i + 1} />
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ---------------- Próximo drop ---------------- */

function NextDrop() {
  const next = useMemo(() => PRODUCTS.filter((p) => isUpcoming(p)).sort((a, b) => releaseTimestamp(a) - releaseTimestamp(b))[0], []);
  if (!next) return null;
  const brand = getBrand(next.brandId)!;
  return (
    <section className="section section-tight">
      <div className="container">
        <Reveal className="drop dark">
          <div className="drop-copy">
            <span className="eyebrow">Próximo drop · {formatDate(next.releaseDate, { day: '2-digit', month: 'long' })}, 10h</span>
            <h2 className="display h2">
              {next.name}
              <br />
              <span className="accent">“{next.model}”</span>
            </h2>
            <p className="lead">{next.description}</p>
            <Countdown target={releaseTimestamp(next)} />
            <Link to={`/produto/${next.slug}`} className="btn btn-primary">
              Ativar lembrete <Icon name="arrowRight" size={18} className="arrow" />
            </Link>
          </div>
          <div className="drop-art">
            <span className="drop-tag mono">
              {brand.name} — {formatPrice(next.price)}
            </span>
            <ProductMedia product={next} />
          </div>
        </Reveal>
      </div>
    </section>
  );
}

/* ---------------- Coleções ---------------- */

function Collections() {
  const cols = COLLECTIONS.map((c) => ({ ...c, items: PRODUCTS.filter((p) => p.collection === c.id) }))
    .sort((a, b) => b.items.length - a.items.length)
    .slice(0, 3);
  return (
    <section className="section">
      <div className="container">
        <Reveal>
          <SectionHeader eyebrow="Curadoria SOLEVA" title="Coleções exclusivas" />
        </Reveal>
        <div className="collections">
          {cols.map((c, idx) => (
            <Reveal key={c.id} delay={idx * 0.08} className={`collection collection-${idx} tone-${c.id}`}>
              <Link to={`/loja?colecao=${c.id}`}>
                <div className="collection-art">
                  {c.items.slice(0, 3).map((p, k) => (
                    <div key={p.id} className={`collection-shoe s${k}`}>
                      <ProductMedia product={p} view={k === 1 ? 'medial' : 'lateral'} />
                    </div>
                  ))}
                </div>
                <div className="collection-copy">
                  <span className="mono">{c.kicker} · {c.items.length} pares</span>
                  <h3 className="display">{c.name}</h3>
                  <p>{c.description}</p>
                  <span className="link">
                    Explorar coleção <Icon name="arrowRight" size={16} />
                  </span>
                </div>
              </Link>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ---------------- Raros ---------------- */

export function RareCard({ product }: { product: Product }) {
  const brand = getBrand(product.brandId)!;
  const left = totalStock(product);
  const total = product.limited?.totalPairs ?? 0;
  // Proporção vendida simulada a partir do estoque disponível no Brasil.
  const sold = Math.min(98, Math.max(62, 100 - left * 1.6));
  const upcoming = isUpcoming(product);
  return (
    <Link to={`/produto/${product.slug}`} className="rare">
      <div className="rare-top">
        <span className="mono">{brand.name}</span>
        <span className="mono rare-serial">Nº {total} pares</span>
      </div>
      <div className="rare-art">
        <ProductMedia product={product} />
      </div>
      <h3 className="display">
        {product.name} <span>“{product.model}”</span>
      </h3>
      <div className="rare-foot">
        <strong>{formatPrice(product.price)}</strong>
        {upcoming ? (
          <span className="mono accent">Lança {formatDate(product.releaseDate)}</span>
        ) : left === 0 ? (
          <span className="mono">Esgotado</span>
        ) : (
          <span className="mono accent">Restam {left} pares</span>
        )}
      </div>
      {!upcoming && (
        <div className="rare-meter" aria-label={`${Math.round(sold)}% vendido`}>
          <span style={{ width: `${sold}%` }} />
        </div>
      )}
    </Link>
  );
}

function Rares() {
  const items = useMemo(() => PRODUCTS.filter((p) => p.limited).sort((a, b) => b.price - a.price).slice(0, 4), []);
  return (
    <section className="section rares dark">
      <div className="container">
        <Reveal>
          <SectionHeader dark eyebrow="Numerados · Autenticados · Raros" title={<>Raros & edições<br />limitadas</>} action={{ label: 'Ver todos os raros', to: '/raros' }} />
        </Reveal>
        <div className="grid-4">
          {items.map((p, i) => (
            <Reveal key={p.id} delay={i * 0.07}>
              <RareCard product={p} />
            </Reveal>
          ))}
        </div>
        <Reveal className="rares-note">
          <Icon name="shield" size={22} />
          <p>
            Todo par raro passa por verificação de autenticidade em 12 pontos antes do envio e acompanha certificado
            com número de série.
          </p>
        </Reveal>
      </div>
    </section>
  );
}

/* ---------------- Promo ---------------- */

function PromoBanner() {
  const p = getProductBySlug('halden-trail-92-moss')!;
  return (
    <section className="section section-tight">
      <div className="container">
        <Reveal className="promo">
          <div className="promo-copy">
            <span className="mono">Oferta de temporada · até 31/10</span>
            <h2 className="display">
              Até 20% off
              <br />
              em seleção
            </h2>
            <p>
              Clássicos de arquivo e runners com preço reduzido. E mais <strong>R$ 150 off</strong> acima de R$ 1.200 com
              o cupom <code>SOLEVA150</code>.
            </p>
            <Link to="/loja?filtro=promocao" className="btn btn-primary">
              Ver promoções <Icon name="arrowRight" size={18} className="arrow" />
            </Link>
          </div>
          <div className="promo-art">
            <ProductMedia product={p} />
          </div>
        </Reveal>
      </div>
    </section>
  );
}

/* ---------------- Destaques ---------------- */

function Featured() {
  const items = useMemo(
    () => PRODUCTS.filter((p) => !isUpcoming(p) && p.rating >= 4.7).sort((a, b) => b.rating - a.rating || b.reviewCount - a.reviewCount).slice(0, 8),
    [],
  );
  return (
    <section className="section">
      <div className="container">
        <Reveal>
          <SectionHeader eyebrow="Avaliados com nota máxima" title="Em destaque" action={{ label: 'Ir para a loja', to: '/loja' }} />
        </Reveal>
        <div className="grid-4">
          {items.map((p, i) => (
            <Reveal key={p.id} delay={(i % 4) * 0.06}>
              <ProductCard product={p} />
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ---------------- Marcas ---------------- */

function Brands() {
  return (
    <section className="section section-tight">
      <div className="container">
        <Reveal>
          <SectionHeader eyebrow="As marcas que vestimos" title="Marcas populares" />
        </Reveal>
        <div className="brand-grid">
          {BRANDS.map((b, i) => {
            const count = PRODUCTS.filter((p) => p.brandId === b.id).length;
            return (
              <Reveal key={b.id} delay={i * 0.04}>
                <Link to={`/loja?marca=${b.id}`} className="brand-card">
                  <span className="mono">{b.origin}</span>
                  <strong className={`brand-word brand-${b.id}`}>{b.name}</strong>
                  <p>{b.tagline}</p>
                  <span className="mono brand-count">
                    {count} modelos <Icon name="arrowRight" size={14} />
                  </span>
                </Link>
              </Reveal>
            );
          })}
          <Reveal delay={0.3}>
            <Link to="/loja" className="brand-card brand-all dark">
              <strong className="display">Ver tudo</strong>
              <Icon name="arrowUpRight" size={28} />
            </Link>
          </Reveal>
        </div>
      </div>
    </section>
  );
}

/* ---------------- Newsletter ---------------- */

function Newsletter() {
  const [email, setEmail] = useState('');
  const [state, setState] = useState<'idle' | 'loading' | 'done'>('idle');
  const [error, setError] = useState('');

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!isValidEmail(email)) return setError('Digite um e-mail válido.');
    setError('');
    setState('loading');
    await subscribe(email.trim());
    setState('done');
  };

  return (
    <section className="newsletter dark">
      <div className="container newsletter-inner">
        <div>
          <span className="eyebrow">SOLEVA Insider</span>
          <h2 className="display h2">
            Chegue antes
            <br />
            nos drops.
          </h2>
        </div>
        <div>
          <p className="lead">
            Aviso de lançamentos 24h antes, acesso antecipado às edições limitadas e 10% off na primeira compra.
          </p>
          {state === 'done' ? (
            <div className="newsletter-done" role="status">
              <Icon name="check" size={20} />
              <div>
                <strong>Você está na lista.</strong>
                <p className="muted small">
                  Modo demonstração: o cadastro foi salvo apenas neste navegador. Use o cupom <code>BEMVINDO10</code>.
                </p>
              </div>
            </div>
          ) : (
            <form className="newsletter-form" onSubmit={onSubmit} noValidate>
              <label htmlFor="nl-email" className="sr-only">
                E-mail
              </label>
              <input
                id="nl-email"
                type="email"
                placeholder="seu@email.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                aria-invalid={Boolean(error)}
                aria-describedby={error ? 'nl-error' : undefined}
              />
              <button className="btn btn-primary" disabled={state === 'loading'}>
                {state === 'loading' ? <span className="spinner" /> : 'Quero entrar'}
              </button>
            </form>
          )}
          {error && (
            <p className="field-error" id="nl-error" role="alert">
              <Icon name="alert" size={14} /> {error}
            </p>
          )}
          <p className="muted small">Sem spam. Você pode sair quando quiser.</p>
        </div>
      </div>
    </section>
  );
}

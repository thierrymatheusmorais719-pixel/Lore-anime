import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { BRANDS, CATEGORIES, COLLECTIONS, PRODUCTS, getBrand, getProductBySlug } from '../data/catalog';
import { Icon } from '../components/Icon';
import { ProductCard } from '../components/ProductCard';
import { Showcase } from '../components/Showcase';
import { useIntroDone } from '../components/Intro';
import { Countdown, ProductMedia, Reveal, SectionHeader } from '../components/ui';
import { useDocumentTitle } from '../hooks';
import { formatDate, formatPrice, installments, plural } from '../lib/format';
import { isNew, isUpcoming, releaseTimestamp, totalStock } from '../lib/product';
import { isValidEmail } from '../lib/validation';
import { subscribe } from '../services/newsletter';
import type { Product } from '../types';

const HERO_SLUGS = ['nike-air-force-1-07-triple-black', 'jordan-4-retro-black-cat', 'nike-dunk-low-panda'];
const HERO_COPY: Record<string, { kicker: string; line1: string; line2: string; specs: [string, string][] }> = {
  'nike-air-force-1-07-triple-black': {
    kicker: 'O mais vendido da casa',
    line1: 'Air Force 1',
    line2: 'Triple Black',
    specs: [['Cabedal', 'Couro liso'], ['Amortecimento', 'Nike Air'], ['Desde', '1982']],
  },
  'jordan-4-retro-black-cat': {
    kicker: 'Edição limitada · 250 pares',
    line1: 'Jordan 4',
    line2: 'Black Cat',
    specs: [['Cabedal', 'Nubuck'], ['Air', 'Visível'], ['Pares', '250']],
  },
  'nike-dunk-low-panda': {
    kicker: 'Lançamento · Disponível agora',
    line1: 'Dunk Low',
    line2: 'Panda',
    specs: [['Cabedal', 'Couro'], ['Perfil', 'Baixo'], ['Desde', '1985']],
  },
};

export function Home() {
  useDocumentTitle('');
  // Remonta o hero quando a abertura termina, para as animações tocarem à vista.
  const introDone = useIntroDone();
  return (
    <>
      <Hero key={introDone ? 'ready' : 'waiting'} />
      <BrandMarquee />
      <Launches />
      <Categories />
      <Showcase />
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
  const [i, setIndex] = useState(0);
  const [leaving, setLeaving] = useState<number | null>(null);
  const [paused, setPaused] = useState(false);
  const ref = useRef<HTMLElement>(null);

  // Troca de destaque: o tênis atual sai voando enquanto o próximo entra.
  const setI = (next: number | ((x: number) => number)) =>
    setIndex((cur) => {
      const n = typeof next === 'function' ? next(cur) : next;
      if (n !== cur) setLeaving(cur);
      return n;
    });
  useEffect(() => {
    if (leaving === null) return;
    const t = window.setTimeout(() => setLeaving(null), 900);
    return () => window.clearTimeout(t);
  }, [leaving, i]);

  useEffect(() => {
    if (paused) return;
    const t = window.setTimeout(() => setI((x) => (x + 1) % slides.length), 7000);
    return () => window.clearTimeout(t);
  }, [i, paused, slides.length]);

  // Parallax leve do tênis e do brilho seguindo o mouse.
  const onMove = (e: React.MouseEvent) => {
    const el = ref.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    el.style.setProperty('--mx', (((e.clientX - r.left) / r.width) * 2 - 1).toFixed(3));
    el.style.setProperty('--my', (((e.clientY - r.top) / r.height) * 2 - 1).toFixed(3));
    el.style.setProperty('--px', `${e.clientX - r.left}px`);
    el.style.setProperty('--py', `${e.clientY - r.top}px`);
  };

  const p = slides[i];
  const copy = HERO_COPY[p.slug];
  const brand = getBrand(p.brandId)!;
  const inst = installments(p.price);

  return (
    <section
      ref={ref}
      className="hero dark"
      onMouseMove={onMove}
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      aria-roledescription="carrossel"
      aria-label="Destaques"
    >
      <div className="hero-grid-bg" aria-hidden="true" />
      <div className="hero-word display" key={`w-${p.id}`} aria-hidden="true">
        {copy.line2}
      </div>
      <div className="container hero-inner">
        <div className="hero-copy" key={p.id}>
          <span className="eyebrow hero-anim" style={{ ['--d' as string]: '0s' }}>
            {copy.kicker}
          </span>
          <h1 className="display hero-title">
            <span className="mask-line">
              <span className="mask-inner" style={{ ['--d' as string]: '.05s' }}>{copy.line1}</span>
            </span>
            <span className="mask-line">
              <span className="mask-inner outline" style={{ ['--d' as string]: '.16s' }}>{copy.line2}</span>
            </span>
          </h1>
          <p className="lead hero-anim" style={{ ['--d' as string]: '.2s' }}>
            {p.description.split('. ')[0]}.
          </p>
          <div className="hero-cta hero-anim" style={{ ['--d' as string]: '.28s' }}>
            <Link to={`/produto/${p.slug}`} className="btn btn-primary">
              Comprar agora <Icon name="arrowRight" size={18} className="arrow" />
            </Link>
            <Link to={`/loja?marca=${brand.id}`} className="btn btn-outline">
              Ver {brand.name}
            </Link>
          </div>
        </div>

        <div className="hero-visual">
          <div className="hero-halo" key={`h-${p.id}`} />
          <span className="hero-index display" aria-hidden="true" key={`i-${p.id}`}>
            0{i + 1}
          </span>
          <div className="hero-price" key={`p-${p.id}`}>
            <span className="mono">{brand.name}</span>
            <strong>{formatPrice(p.price)}</strong>
            <span className="mono">
              {inst.count}x de {formatPrice(inst.value)}
            </span>
          </div>
          {leaving !== null && leaving !== i && (
            <div className="hero-shoe leaving" key={`out-${slides[leaving].id}`} aria-hidden="true">
              <ProductMedia product={slides[leaving]} sizes="(max-width: 900px) 100vw, 60vw" />
            </div>
          )}
          <div className={`hero-shoe entering ${p.images?.length && !p.cutout ? 'has-photo' : ''}`} key={`in-${p.id}`}>
            <ProductMedia product={p} sizes="(max-width: 900px) 100vw, 60vw" />
          </div>
          <div className="hero-floor" aria-hidden="true" key={`f-${p.id}`} />
          <dl className="hero-specs" key={`s-${p.id}`}>
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
            <span className="hero-dot-thumb" aria-hidden="true">
              <ProductMedia product={s} />
            </span>
            <span className="hero-dot-text">
              <span className="mono">0{idx + 1}</span>
              <span className="hero-dot-label">
                {s.name} “{s.model}”
              </span>
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
                  <span className="mono">{String(idx + 1).padStart(2, '0')} — {plural(t.count, 'modelo', 'modelos')}</span>
                  <h3 className="display">{t.name}</h3>
                  <p>{t.blurb}</p>
                </div>
                {t.hero && (
                  <div className="cat-art">
                    <ProductMedia product={t.hero} sizes="(max-width: 900px) 70vw, 45vw" />
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
        <Reveal className="drop dark grain">
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
            <ProductMedia product={next} sizes="(max-width: 900px) 100vw, 50vw" />
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
                  <span className="mono">{c.kicker} · {plural(c.items.length, 'par', 'pares')}</span>
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
          <span className="mono accent">{left === 1 ? 'Resta 1 par' : `Restam ${left} pares`}</span>
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
    <section className="section rares dark grain">
      <div className="container">
        <Reveal>
          <SectionHeader dark eyebrow="Numerados · Autenticados · Raros" title={['Raros & edições', 'limitadas']} action={{ label: 'Ver todos os raros', to: '/raros' }} />
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
  const p = getProductBySlug('nike-air-force-1-07-white-black')!;
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
              Air Force 1 e Runfalcon com preço reduzido. E mais <strong>R$ 150 off</strong> acima de R$ 1.200 com
              o cupom <code>SOLEVA150</code>.
            </p>
            <Link to="/loja?filtro=promocao" className="btn btn-primary">
              Ver promoções <Icon name="arrowRight" size={18} className="arrow" />
            </Link>
          </div>
          <div className="promo-art">
            <ProductMedia product={p} sizes="(max-width: 800px) 100vw, 50vw" />
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
                    {plural(count, 'modelo', 'modelos')} <Icon name="arrowRight" size={14} />
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
    <section className="newsletter dark grain">
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

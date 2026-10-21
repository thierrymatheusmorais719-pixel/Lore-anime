import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { PRODUCTS, getBrand, getCategory, getCollection, getProductBySlug } from '../data/catalog';
import { addLocalReview, getReviews } from '../data/reviews';
import { Icon } from '../components/Icon';
import { ProductCard } from '../components/ProductCard';
import { SizeGuide } from '../components/SizeGuide';
import { VIEW_LABELS, type SneakerView } from '../components/SneakerArt';
import { Badges, Countdown, EmptyState, Modal, Price, ProductMedia, QuantityInput, Stars } from '../components/ui';
import { useDocumentTitle } from '../hooks';
import { formatDate, formatPrice } from '../lib/format';
import { maxQuantity } from '../lib/pricing';
import { isUpcoming, releaseTimestamp, totalStock } from '../lib/product';
import { isValidCEP, maskCEP } from '../lib/validation';
import { readJSON, writeJSON } from '../lib/storage';
import { shippingProvider } from '../services/shipping';
import { useShop } from '../store/ShopProvider';
import type { Product, Review, ShippingOption } from '../types';

const VIEWS: SneakerView[] = ['lateral', 'medial', 'heel', 'toe', 'sole'];

const viewLabel = (product: Product, i: number) => (product.images?.length ? `Foto ${i + 1}` : VIEW_LABELS[VIEWS[i]]);

export function ProductPage() {
  const { slug = '' } = useParams();
  const product = getProductBySlug(slug);
  useDocumentTitle(product ? `${getBrand(product.brandId)?.name} ${product.name} “${product.model}”` : 'Produto não encontrado');

  if (!product) {
    return (
      <div className="container page-pad">
        <EmptyState
          icon="search"
          title="Produto não encontrado"
          body="Esse modelo pode ter saído do catálogo ou o link está incorreto."
          action={
            <Link to="/loja" className="btn btn-primary">
              Voltar para a loja
            </Link>
          }
        />
      </div>
    );
  }
  return <ProductView key={product.id} product={product} />;
}

function ProductView({ product }: { product: Product }) {
  const brand = getBrand(product.brandId)!;
  const category = getCategory(product.category)!;
  const collection = getCollection(product.collection);
  const upcoming = isUpcoming(product);
  const stockTotal = totalStock(product);
  const { addToCart, isFavorite, toggleFavorite, notify } = useShop();
  const navigate = useNavigate();

  const [size, setSize] = useState<string | null>(null);
  const [qty, setQty] = useState(1);
  const [sizeError, setSizeError] = useState(false);
  const [guideOpen, setGuideOpen] = useState(false);
  const sizeRef = useRef<HTMLDivElement>(null);
  const fav = isFavorite(product.id);
  const max = size ? maxQuantity(product, size) : 1;

  useEffect(() => {
    window.scrollTo({ top: 0 });
  }, []);
  useEffect(() => setQty((q) => Math.min(q, Math.max(1, max))), [max]);

  const requireSize = () => {
    if (size && (product.stock[size] ?? 0) > 0) return true;
    setSizeError(true);
    sizeRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    sizeRef.current?.classList.remove('shake');
    void sizeRef.current?.offsetWidth;
    sizeRef.current?.classList.add('shake');
    return false;
  };

  const onAdd = () => {
    if (!requireSize()) return;
    addToCart(product, size!, qty);
  };
  const onBuy = () => {
    if (!requireSize()) return;
    addToCart(product, size!, qty);
    navigate('/checkout');
  };

  const reminders = readJSON<string[]>('soleva:reminders', []);
  const [reminded, setReminded] = useState(reminders.includes(product.id));
  const onRemind = () => {
    const list = readJSON<string[]>('soleva:reminders', []);
    const next = reminded ? list.filter((x) => x !== product.id) : [...list, product.id];
    writeJSON('soleva:reminders', next);
    setReminded(!reminded);
    notify({ title: reminded ? 'Lembrete removido' : 'Lembrete ativado', body: reminded ? undefined : 'Avisaremos neste navegador quando o drop abrir.', product });
  };

  const similar = useMemo(
    () =>
      PRODUCTS.filter((p) => p.id !== product.id)
        .map((p) => ({ p, s: (p.category === product.category ? 2 : 0) + (p.brandId === product.brandId ? 1.5 : 0) + (p.silhouette === product.silhouette ? 1 : 0) + p.popularity / 200 }))
        .sort((a, b) => b.s - a.s)
        .slice(0, 4)
        .map((x) => x.p),
    [product],
  );

  const stockStatus = upcoming
    ? null
    : stockTotal === 0
      ? { tone: 'out', label: 'Esgotado em todas as numerações' }
      : size
        ? product.stock[size] <= 2
          ? { tone: 'low', label: `Últimos ${product.stock[size]} ${product.stock[size] === 1 ? 'par' : 'pares'} no tamanho ${size}` }
          : { tone: 'ok', label: `Em estoque no tamanho ${size} · envio em até 24h úteis` }
        : stockTotal < 15
          ? { tone: 'low', label: 'Estoque baixo — poucas numerações disponíveis' }
          : { tone: 'ok', label: 'Em estoque · envio em até 24h úteis' };

  return (
    <div className="pdp">
      <div className="container">
        <nav className="crumbs mono" aria-label="Trilha">
          <Link to="/">Início</Link> / <Link to={`/loja/${category.id}`}>{category.name}</Link> / <Link to={`/loja?marca=${brand.id}`}>{brand.name}</Link> / <span>{product.name}</span>
        </nav>

        <div className="pdp-grid">
          <Gallery product={product} />

          <div className="pdp-info">
            <div className="pdp-head">
              <Badges product={product} max={3} />
              <Link to={`/loja?marca=${brand.id}`} className="mono pdp-brand">
                {brand.name}
              </Link>
              <h1 className="display pdp-title">
                {product.name}
                <span>“{product.model}”</span>
              </h1>
              <p className="pdp-colorway">{product.colorway}</p>
              {product.reviewCount > 0 && (
                <a href="#avaliacoes" className="pdp-rating">
                  <Stars value={product.rating} />
                  <span>{product.rating.toFixed(1)}</span>
                  <span className="muted">· {product.reviewCount} avaliações</span>
                </a>
              )}
            </div>

            <Price product={product} size="lg" showInstallments />

            {product.limited && (
              <div className="pdp-limited">
                <Icon name="bolt" size={18} />
                <div>
                  <strong>Edição limitada — {product.limited.totalPairs} pares</strong>
                  <p>Limite de 1 par por cliente. Acompanha certificado de autenticidade numerado.</p>
                </div>
              </div>
            )}

            {upcoming && (
              <div className="pdp-drop dark">
                <span className="mono">Lançamento em {formatDate(product.releaseDate, { day: '2-digit', month: 'long', year: 'numeric' })} às 10h</span>
                <Countdown target={releaseTimestamp(product)} compact />
              </div>
            )}

            <div className={`pdp-sizes ${sizeError ? 'error' : ''}`} ref={sizeRef}>
              <div className="pdp-sizes-head">
                <span id="size-label">
                  {upcoming ? 'Numerações previstas' : 'Selecione o tamanho'} <span className="mono muted">(BR)</span>
                </span>
                <button className="link-btn" onClick={() => setGuideOpen(true)}>
                  <Icon name="ruler" size={16} /> Guia de tamanhos
                </button>
              </div>
              <div className="size-grid size-grid-lg" role="radiogroup" aria-labelledby="size-label">
                {Object.entries(product.stock).map(([s, n]) => {
                  const out = n === 0;
                  return (
                    <button
                      key={s}
                      role="radio"
                      aria-checked={size === s}
                      className={`size-chip ${size === s ? 'on' : ''} ${out ? 'out' : ''} ${!out && n <= 2 && !upcoming ? 'low' : ''}`}
                      disabled={out || upcoming}
                      onClick={() => {
                        setSize(s);
                        setSizeError(false);
                      }}
                      aria-label={`Tamanho ${s}${out ? ', esgotado' : n <= 2 ? `, últimas ${n} unidades` : ''}`}
                    >
                      {s}
                    </button>
                  );
                })}
              </div>
              {sizeError && (
                <p className="field-error" role="alert">
                  <Icon name="alert" size={14} /> Selecione um tamanho disponível para continuar.
                </p>
              )}
            </div>

            {stockStatus && (
              <p className={`stock stock-${stockStatus.tone}`}>
                <span className="stock-dot" /> {stockStatus.label}
              </p>
            )}

            {!upcoming && stockTotal > 0 && (
              <div className="pdp-buy">
                <QuantityInput value={qty} max={Math.max(1, max)} onChange={(q) => setQty(Math.max(1, Math.min(max, q)))} />
                <button className="btn btn-primary pdp-add" onClick={onAdd}>
                  <Icon name="bag" size={18} /> Adicionar ao carrinho
                </button>
                <button className={`icon-btn bordered pdp-fav ${fav ? 'on' : ''}`} onClick={() => toggleFavorite(product)} aria-pressed={fav} aria-label={fav ? 'Remover dos favoritos' : 'Favoritar'}>
                  <Icon name="heart" filled={fav} />
                </button>
                <button className="btn btn-accent btn-block pdp-now" onClick={onBuy}>
                  Comprar agora <Icon name="arrowRight" size={18} className="arrow" />
                </button>
              </div>
            )}

            {(upcoming || stockTotal === 0) && (
              <div className="pdp-buy">
                <button className="btn btn-primary btn-block" onClick={onRemind}>
                  <Icon name={reminded ? 'check' : 'clock'} size={18} /> {reminded ? 'Lembrete ativado' : upcoming ? 'Ativar lembrete do drop' : 'Avise-me quando chegar'}
                </button>
                <button className={`icon-btn bordered pdp-fav ${fav ? 'on' : ''}`} onClick={() => toggleFavorite(product)} aria-pressed={fav} aria-label={fav ? 'Remover dos favoritos' : 'Favoritar'}>
                  <Icon name="heart" filled={fav} />
                </button>
              </div>
            )}

            <ShippingCalc />

            <ul className="pdp-perks">
              <li><Icon name="truck" size={18} /> Frete grátis acima de R$ 799</li>
              <li><Icon name="returns" size={18} /> Primeira troca grátis em 30 dias</li>
              <li><Icon name="shield" size={18} /> Autenticidade garantida</li>
            </ul>

            <Accordion
              items={[
                {
                  title: 'Descrição',
                  open: true,
                  body: (
                    <>
                      <p>{product.description}</p>
                      <dl className="spec-list">
                        <div><dt>Marca</dt><dd>{brand.name} · {brand.origin}</dd></div>
                        <div><dt>Categoria</dt><dd>{category.name}</dd></div>
                        {collection && <div><dt>Coleção</dt><dd><Link to={`/loja?colecao=${collection.id}`}>{collection.name}</Link></dd></div>}
                        <div><dt>Cor</dt><dd>{product.colorway}</dd></div>
                        <div><dt>Lançamento</dt><dd>{formatDate(product.releaseDate, { day: '2-digit', month: '2-digit', year: 'numeric' })}</dd></div>
                        <div><dt>Código</dt><dd className="mono">{product.sku}</dd></div>
                      </dl>
                    </>
                  ),
                },
                {
                  title: 'Materiais e características',
                  body: (
                    <div className="two-lists">
                      <div>
                        <h4 className="mono">Materiais</h4>
                        <ul>{product.materials.map((m) => <li key={m}>{m}</li>)}</ul>
                      </div>
                      <div>
                        <h4 className="mono">Características</h4>
                        <ul>{product.features.map((m) => <li key={m}>{m}</li>)}</ul>
                      </div>
                    </div>
                  ),
                },
                {
                  title: 'Entrega e devolução',
                  body: (
                    <>
                      <p>Pedidos aprovados até 14h são despachados no mesmo dia útil. O prazo de entrega começa a contar após a confirmação do pagamento.</p>
                      <p>Você tem 30 dias a partir do recebimento para trocar ou devolver. O produto deve estar sem uso, com etiquetas e na caixa original. A primeira troca é gratuita.</p>
                      <Link to="/ajuda/trocas" className="link">Política completa <Icon name="arrowRight" size={14} /></Link>
                    </>
                  ),
                },
                {
                  title: 'Autenticidade',
                  body: <p>Compramos direto das marcas e distribuidores oficiais. Edições limitadas passam por inspeção em 12 pontos e seguem com certificado e lacre numerado.</p>,
                },
              ]}
            />
          </div>
        </div>
      </div>

      <Reviews product={product} />

      <section className="section">
        <div className="container">
          <div className="section-head">
            <div>
              <span className="eyebrow">Você também pode gostar</span>
              <h2 className="display h2">Semelhantes</h2>
            </div>
          </div>
          <div className="grid-4">
            {similar.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </div>
      </section>

      {!upcoming && stockTotal > 0 && (
        <div className="sticky-buy">
          <div className="sticky-buy-media">
            <ProductMedia product={product} />
          </div>
          <div className="sticky-buy-info">
            <strong>{product.name}</strong>
            <span>{size ? `Tam. ${size}` : 'Escolha o tamanho'} · {formatPrice(product.price)}</span>
          </div>
          <button className="btn btn-primary btn-sm" onClick={onAdd}>
            Adicionar
          </button>
        </div>
      )}

      <Modal open={guideOpen} onClose={() => setGuideOpen(false)} title="Guia de tamanhos">
        <SizeGuide highlight={size ?? undefined} />
      </Modal>
    </div>
  );
}

function Gallery({ product }: { product: Product }) {
  const [active, setActive] = useState(0);
  const [zoom, setZoom] = useState<{ x: number; y: number } | null>(null);
  // Com fotos reais, a galeria mostra as fotos; sem fotos, as vistas do render.
  const views = product.images?.length ? product.images.map((_, i) => VIEWS[i] ?? 'lateral') : VIEWS;

  const onKey = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowRight') setActive((a) => (a + 1) % views.length);
    if (e.key === 'ArrowLeft') setActive((a) => (a - 1 + views.length) % views.length);
  };

  return (
    <div className="gallery" onKeyDown={onKey}>
      <div className="gallery-thumbs" role="tablist" aria-label="Imagens do produto">
        {views.map((v, i) => (
          <button key={i} role="tab" aria-selected={active === i} className={active === i ? 'on' : ''} onClick={() => setActive(i)} aria-label={viewLabel(product, i)}>
            <ProductMedia product={product} view={v} index={i} />
          </button>
        ))}
      </div>
      <div
        className={`gallery-main ${zoom ? 'zooming' : ''}`}
        onMouseMove={(e) => {
          const r = e.currentTarget.getBoundingClientRect();
          setZoom({ x: ((e.clientX - r.left) / r.width) * 100, y: ((e.clientY - r.top) / r.height) * 100 });
        }}
        onMouseLeave={() => setZoom(null)}
        tabIndex={0}
        role="tabpanel"
        aria-label={`${viewLabel(product, active)} — use as setas para navegar`}
      >
        <div className="gallery-stage" style={zoom ? { transformOrigin: `${zoom.x}% ${zoom.y}%` } : undefined} key={active}>
          <ProductMedia product={product} view={views[active]} index={active} />
        </div>
        <span className="gallery-count mono">
          {String(active + 1).padStart(2, '0')} / {String(views.length).padStart(2, '0')} — {viewLabel(product, active)}
        </span>
        <div className="gallery-arrows">
          <button className="icon-btn" onClick={() => setActive((a) => (a - 1 + views.length) % views.length)} aria-label="Imagem anterior">
            <Icon name="arrowLeft" />
          </button>
          <button className="icon-btn" onClick={() => setActive((a) => (a + 1) % views.length)} aria-label="Próxima imagem">
            <Icon name="arrowRight" />
          </button>
        </div>
      </div>
      <div className="gallery-mobile" aria-hidden="true">
        {views.map((v, i) => (
          <div key={i} className="gallery-slide">
            <ProductMedia product={product} view={v} index={i} />
          </div>
        ))}
      </div>
    </div>
  );
}

function ShippingCalc() {
  const [cep, setCep] = useState('');
  const [state, setState] = useState<'idle' | 'loading' | 'error' | 'done'>('idle');
  const [options, setOptions] = useState<ShippingOption[]>([]);

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!isValidCEP(cep)) return setState('error');
    setState('loading');
    try {
      setOptions(await shippingProvider.quote(cep, [{ quantity: 1 }]));
      setState('done');
    } catch {
      setState('error');
    }
  };

  return (
    <div className="ship-calc">
      <form onSubmit={onSubmit}>
        <label htmlFor="pdp-cep">
          <Icon name="truck" size={18} /> Calcular frete e prazo
        </label>
        <div className="ship-calc-row">
          <input id="pdp-cep" className="input" inputMode="numeric" placeholder="00000-000" value={cep} onChange={(e) => setCep(maskCEP(e.target.value))} aria-invalid={state === 'error'} />
          <button className="btn btn-outline btn-sm" disabled={state === 'loading'}>
            {state === 'loading' ? <span className="spinner" /> : 'Calcular'}
          </button>
        </div>
      </form>
      {state === 'error' && <p className="field-error">Digite um CEP válido com 8 dígitos.</p>}
      {state === 'done' && (
        <ul className="ship-options">
          {options.map((o) => (
            <li key={o.id}>
              <span>{o.label}</span>
              <span className="muted">
                {o.days[0]}–{o.days[1]} dias úteis
              </span>
              <strong>{formatPrice(o.price)}</strong>
            </li>
          ))}
          <li className="muted small">Estimativa. Frete grátis em compras acima de R$ 799.</li>
        </ul>
      )}
    </div>
  );
}

function Accordion({ items }: { items: { title: string; body: React.ReactNode; open?: boolean }[] }) {
  return (
    <div className="accordion">
      {items.map((it) => (
        <details key={it.title} open={it.open}>
          <summary>
            {it.title}
            <Icon name="plus" size={18} />
          </summary>
          <div className="accordion-body">{it.body}</div>
        </details>
      ))}
    </div>
  );
}

function Reviews({ product }: { product: Product }) {
  const [reviews, setReviews] = useState<Review[]>(() => getReviews(product));
  const [formOpen, setFormOpen] = useState(false);
  const [filter, setFilter] = useState<number | null>(null);

  const dist = [5, 4, 3, 2, 1].map((star) => {
    // Distribuição aproximada a partir da média agregada do produto.
    const avg = product.rating || 0;
    const weights: Record<number, number> = {
      5: Math.max(0, avg - 3.6) * 1.6,
      4: 0.6,
      3: Math.max(0.05, 4.9 - avg) * 0.5,
      2: Math.max(0.02, 4.9 - avg) * 0.2,
      1: Math.max(0.01, 4.9 - avg) * 0.1,
    };
    const total = Object.values(weights).reduce((a, b) => a + b, 0);
    return { star, pct: product.reviewCount ? (weights[star] / total) * 100 : 0 };
  });

  const fitCounts = reviews.reduce<Record<string, number>>((acc, r) => ({ ...acc, [r.fit]: (acc[r.fit] ?? 0) + 1 }), {});
  const fitTotal = reviews.length || 1;
  const fitPos = (((fitCounts.grande ?? 0) - (fitCounts.pequeno ?? 0)) / fitTotal) * 50 + 50;
  const list = filter ? reviews.filter((r) => r.rating === filter) : reviews;

  return (
    <section className="section reviews" id="avaliacoes">
      <div className="container">
        <div className="section-head">
          <div>
            <span className="eyebrow">Quem comprou, recomenda</span>
            <h2 className="display h2">Avaliações</h2>
          </div>
          <button className="btn btn-outline" onClick={() => setFormOpen(true)}>
            Escrever avaliação
          </button>
        </div>

        {product.reviewCount === 0 && reviews.length === 0 ? (
          <EmptyState icon="star" title="Ainda sem avaliações" body={isUpcoming(product) ? 'As avaliações abrem após o lançamento.' : 'Seja a primeira pessoa a avaliar este modelo.'} />
        ) : (
          <div className="reviews-grid">
            <aside className="reviews-summary">
              <div className="reviews-score">
                <strong className="display">{product.rating.toFixed(1)}</strong>
                <div>
                  <Stars value={product.rating} size={18} />
                  <p className="muted small">{product.reviewCount} avaliações</p>
                </div>
              </div>
              <ul className="dist">
                {dist.map((d) => (
                  <li key={d.star}>
                    <button className={filter === d.star ? 'on' : ''} onClick={() => setFilter(filter === d.star ? null : d.star)} aria-pressed={filter === d.star}>
                      <span className="mono">{d.star}★</span>
                      <span className="dist-bar">
                        <span style={{ width: `${d.pct}%` }} />
                      </span>
                      <span className="mono muted">{Math.round(d.pct)}%</span>
                    </button>
                  </li>
                ))}
              </ul>
              <div className="fit">
                <span className="mono">Caimento</span>
                <div className="fit-track">
                  <span style={{ left: `${Math.max(4, Math.min(96, fitPos))}%` }} />
                </div>
                <div className="fit-labels mono muted">
                  <span>Pequeno</span>
                  <span>Ideal</span>
                  <span>Grande</span>
                </div>
              </div>
            </aside>
            <ul className="review-list">
              {list.length === 0 && <li className="muted">Nenhuma avaliação com {filter} estrelas entre as mais recentes.</li>}
              {list.map((r) => (
                <li key={r.id} className="review">
                  <div className="review-head">
                    <Stars value={r.rating} />
                    <span className="mono muted">{new Date(r.date).toLocaleDateString('pt-BR')}</span>
                  </div>
                  <h3>{r.title}</h3>
                  <p>{r.body}</p>
                  <div className="review-meta mono muted">
                    <span>{r.author} · {r.city}</span>
                    <span>Tam. {r.size} · caimento {r.fit}</span>
                    {r.verified && (
                      <span className="verified">
                        <Icon name="check" size={12} /> Compra verificada
                      </span>
                    )}
                    {r.local && <span>Sua avaliação (salva neste navegador)</span>}
                  </div>
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>

      <Modal open={formOpen} onClose={() => setFormOpen(false)} title="Avaliar produto">
        <ReviewForm
          product={product}
          onDone={(r) => {
            addLocalReview(r);
            setReviews((rs) => [r, ...rs]);
            setFormOpen(false);
          }}
        />
      </Modal>
    </section>
  );
}

function ReviewForm({ product, onDone }: { product: Product; onDone: (r: Review) => void }) {
  const [rating, setRating] = useState(0);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [author, setAuthor] = useState('');
  const [size, setSize] = useState(Object.keys(product.stock)[4] ?? '40');
  const [fit, setFit] = useState<Review['fit']>('normal');
  const [errors, setErrors] = useState<Record<string, string>>({});

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const err: Record<string, string> = {};
    if (!rating) err.rating = 'Escolha de 1 a 5 estrelas.';
    if (title.trim().length < 3) err.title = 'Dê um título à sua avaliação.';
    if (body.trim().length < 20) err.body = 'Conte um pouco mais (mínimo de 20 caracteres).';
    if (author.trim().length < 2) err.author = 'Informe seu nome.';
    setErrors(err);
    if (Object.keys(err).length) return;
    onDone({
      id: `local-${Date.now()}`,
      productId: product.id,
      author: author.trim(),
      city: '',
      rating,
      title: title.trim(),
      body: body.trim(),
      size,
      fit,
      date: new Date().toISOString(),
      verified: false,
      local: true,
    });
  };

  return (
    <form className="form-stack" onSubmit={submit} noValidate>
      <div className="field">
        <label>Sua nota</label>
        <div className="star-input" role="radiogroup" aria-label="Nota">
          {[1, 2, 3, 4, 5].map((n) => (
            <button type="button" key={n} role="radio" aria-checked={rating === n} onClick={() => setRating(n)} aria-label={`${n} estrela${n > 1 ? 's' : ''}`} className={n <= rating ? 'on' : ''}>
              <Icon name="star" size={28} filled={n <= rating} />
            </button>
          ))}
        </div>
        {errors.rating && <p className="field-error">{errors.rating}</p>}
      </div>
      <div className="field">
        <label htmlFor="rv-title">Título</label>
        <input id="rv-title" className="input" value={title} onChange={(e) => setTitle(e.target.value)} aria-invalid={Boolean(errors.title)} />
        {errors.title && <p className="field-error">{errors.title}</p>}
      </div>
      <div className="field">
        <label htmlFor="rv-body">Avaliação</label>
        <textarea id="rv-body" className="input" rows={4} value={body} onChange={(e) => setBody(e.target.value)} aria-invalid={Boolean(errors.body)} />
        {errors.body && <p className="field-error">{errors.body}</p>}
      </div>
      <div className="form-row">
        <div className="field">
          <label htmlFor="rv-name">Nome</label>
          <input id="rv-name" className="input" value={author} onChange={(e) => setAuthor(e.target.value)} aria-invalid={Boolean(errors.author)} />
          {errors.author && <p className="field-error">{errors.author}</p>}
        </div>
        <div className="field">
          <label htmlFor="rv-size">Tamanho comprado</label>
          <select id="rv-size" className="select" value={size} onChange={(e) => setSize(e.target.value)}>
            {Object.keys(product.stock).map((s) => (
              <option key={s}>{s}</option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="rv-fit">Caimento</label>
          <select id="rv-fit" className="select" value={fit} onChange={(e) => setFit(e.target.value as Review['fit'])}>
            <option value="pequeno">Pequeno</option>
            <option value="normal">Ideal</option>
            <option value="grande">Grande</option>
          </select>
        </div>
      </div>
      <p className="field-hint">Modo demonstração: sua avaliação fica salva apenas neste navegador.</p>
      <button className="btn btn-primary">Publicar avaliação</button>
    </form>
  );
}

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { BRANDS, CATEGORIES, COLLECTIONS, COLORS, SIZES, getCategory, getCollection } from '../data/catalog';
import { Icon } from '../components/Icon';
import { ProductCard } from '../components/ProductCard';
import { EmptyState, SkeletonCard } from '../components/ui';
import { useDocumentTitle, useEscape, useLockBody } from '../hooks';
import {
  FLAG_LABELS,
  SORT_OPTIONS,
  applyFilters,
  countActive,
  emptyFilters,
  facetCount,
  parseFilters,
  serializeFilters,
  toggle,
  type Filters,
  type Flag,
  type SortKey,
} from '../lib/filters';
import { formatPrice, plural } from '../lib/format';
import { fetchProducts } from '../services/catalog';
import type { Product } from '../types';

const PAGE_SIZE = 12;
const PRICE_PRESETS: [number | null, number | null, string][] = [
  [null, 700, 'Até R$ 700'],
  [700, 1200, 'R$ 700 – 1.200'],
  [1200, 2000, 'R$ 1.200 – 2.000'],
  [2000, null, 'Acima de R$ 2.000'],
];

type LoadState = { status: 'loading' } | { status: 'error'; message: string } | { status: 'ready'; products: Product[] };

function useCatalog() {
  const [state, setState] = useState<LoadState>({ status: 'loading' });
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    const ctrl = new AbortController();
    setState({ status: 'loading' });
    fetchProducts(ctrl.signal)
      .then((products) => setState({ status: 'ready', products }))
      .catch((e: Error) => {
        if (e.name !== 'AbortError') setState({ status: 'error', message: e.message });
      });
    return () => ctrl.abort();
  }, [attempt]);
  return { state, retry: () => setAttempt((a) => a + 1) };
}

export function Shop({ preset }: { preset?: 'raros' }) {
  const { categoria } = useParams();
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const { state, retry } = useCatalog();
  const [visible, setVisible] = useState(PAGE_SIZE);
  const [panelOpen, setPanelOpen] = useState(false);
  useLockBody(panelOpen);
  useEscape(panelOpen, () => setPanelOpen(false));

  const routeCategory = categoria && getCategory(categoria) ? categoria : undefined;
  const filters = useMemo(() => {
    const f = parseFilters(params, routeCategory);
    if (preset === 'raros' && !f.flags.includes('limitado')) f.flags = [...f.flags, 'limitado'];
    return f;
  }, [params, routeCategory, preset]);

  const update = useCallback(
    (patch: Partial<Filters>) => {
      const next = { ...filters, ...patch };
      if (preset === 'raros') next.flags = next.flags.filter((x) => x !== 'limitado');
      const keepRoute = routeCategory && next.categories.length === 1 && next.categories[0] === routeCategory;
      const qs = serializeFilters(next, Boolean(keepRoute)).toString();
      const base = preset === 'raros' ? '/raros' : keepRoute ? `/loja/${routeCategory}` : '/loja';
      navigate(`${base}${qs ? `?${qs}` : ''}`, { replace: true, preventScrollReset: true });
      setVisible(PAGE_SIZE);
    },
    [filters, navigate, routeCategory, preset],
  );

  const products = state.status === 'ready' ? state.products : [];
  const results = useMemo(() => applyFilters(products, filters), [products, filters]);
  const shown = results.slice(0, visible);
  const active = countActive(filters) - (preset === 'raros' ? 1 : 0) - (routeCategory && filters.categories.length === 1 ? 1 : 0);

  const category = routeCategory ? getCategory(routeCategory) : undefined;
  const collection = getCollection(filters.collection ?? undefined);
  const title = preset === 'raros' ? 'Raros & limitados' : filters.q ? `“${filters.q}”` : collection?.name ?? category?.name ?? 'Todos os tênis';
  const subtitle =
    preset === 'raros'
      ? 'Edições numeradas, reedições de arquivo e colaborações. Todos com certificado de autenticidade.'
      : collection?.description ?? category?.blurb ?? 'Lançamentos, clássicos e raridades de sete marcas, com curadoria SOLEVA.';
  useDocumentTitle(filters.q ? `Busca: ${filters.q}` : title);

  // Carregamento progressivo ao chegar perto do fim da lista.
  const sentinel = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = sentinel.current;
    if (!el || visible >= results.length) return;
    const io = new IntersectionObserver((e) => e[0].isIntersecting && setVisible((v) => v + PAGE_SIZE), { rootMargin: '400px' });
    io.observe(el);
    return () => io.disconnect();
  }, [visible, results.length]);

  const clearAll = () => {
    const base = emptyFilters();
    update({ ...base, q: '', categories: routeCategory ? [routeCategory as Filters['categories'][number]] : [] });
  };

  const chips: { label: string; remove: () => void }[] = [
    ...(filters.q ? [{ label: `Busca: ${filters.q}`, remove: () => update({ q: '' }) }] : []),
    ...filters.categories
      .filter((c) => c !== routeCategory)
      .map((c) => ({ label: getCategory(c)?.name ?? c, remove: () => update({ categories: toggle(filters.categories, c) }) })),
    ...filters.brands.map((b) => ({ label: BRANDS.find((x) => x.id === b)?.name ?? b, remove: () => update({ brands: toggle(filters.brands, b) }) })),
    ...filters.sizes.map((s) => ({ label: `Tam. ${s}`, remove: () => update({ sizes: toggle(filters.sizes, s) }) })),
    ...filters.colors.map((c) => ({ label: COLORS.find((x) => x.id === c)?.name ?? c, remove: () => update({ colors: toggle(filters.colors, c) }) })),
    ...filters.flags
      .filter((f) => !(preset === 'raros' && f === 'limitado'))
      .map((f) => ({ label: FLAG_LABELS[f], remove: () => update({ flags: toggle(filters.flags, f) }) })),
    ...(filters.priceMin !== null || filters.priceMax !== null
      ? [{ label: priceLabel(filters.priceMin, filters.priceMax), remove: () => update({ priceMin: null, priceMax: null }) }]
      : []),
    ...(collection ? [{ label: `Coleção ${collection.name}`, remove: () => update({ collection: null }) }] : []),
  ];

  return (
    <div className="shop">
      <header className={`shop-hero ${preset === 'raros' ? 'dark' : ''}`}>
        <div className="container">
          <nav className="crumbs mono" aria-label="Trilha">
            <Link to="/">Início</Link> / <Link to="/loja">Loja</Link>
            {category && <> / <span>{category.name}</span></>}
            {preset === 'raros' && <> / <span>Raros</span></>}
          </nav>
          <h1 className="display h1">{title}</h1>
          <p className="lead">{subtitle}</p>
          {!preset && (
            <div className="shop-cats">
              <Link to="/loja" className={`chip ${!routeCategory ? 'on' : ''}`}>
                Todos
              </Link>
              {CATEGORIES.map((c) => (
                <Link key={c.id} to={`/loja/${c.id}`} className={`chip ${routeCategory === c.id ? 'on' : ''}`}>
                  {c.name}
                </Link>
              ))}
            </div>
          )}
        </div>
      </header>

      <div className="container shop-body">
        <div className={`overlay ${panelOpen ? 'open' : ''} filters-overlay`} onClick={() => setPanelOpen(false)} />
        <aside className={`filters ${panelOpen ? 'open' : ''}`} aria-label="Filtros">
          <div className="filters-head">
            <h2 className="display h3">Filtros</h2>
            <button className="icon-btn" onClick={() => setPanelOpen(false)} aria-label="Fechar filtros">
              <Icon name="close" />
            </button>
          </div>
          <div className="filters-scroll">
            <FilterSearch value={filters.q} onChange={(q) => update({ q })} />

            {!routeCategory && (
              <FilterGroup title="Categoria">
                {CATEGORIES.map((c) => (
                  <Check
                    key={c.id}
                    label={c.name}
                    checked={filters.categories.includes(c.id)}
                    count={facetCount(products, filters, { categories: toggle(filters.categories, c.id) })}
                    onChange={() => update({ categories: toggle(filters.categories, c.id) })}
                    countIsResult={!filters.categories.includes(c.id)}
                  />
                ))}
              </FilterGroup>
            )}

            <FilterGroup title="Marca">
              {BRANDS.map((b) => (
                <Check
                  key={b.id}
                  label={b.name}
                  checked={filters.brands.includes(b.id)}
                  count={facetCount(products, filters, { brands: toggle(filters.brands, b.id) })}
                  onChange={() => update({ brands: toggle(filters.brands, b.id) })}
                  countIsResult={!filters.brands.includes(b.id)}
                />
              ))}
            </FilterGroup>

            <FilterGroup title="Tamanho (BR)">
              <div className="size-grid">
                {SIZES.map((s) => {
                  const on = filters.sizes.includes(s);
                  const n = facetCount(products, filters, { sizes: [s] });
                  return (
                    <button key={s} className={`size-chip ${on ? 'on' : ''}`} aria-pressed={on} disabled={!on && n === 0} onClick={() => update({ sizes: toggle(filters.sizes, s) })}>
                      {s}
                    </button>
                  );
                })}
              </div>
              <p className="field-hint">Mostra modelos com a numeração disponível em estoque.</p>
            </FilterGroup>

            <FilterGroup title="Cor">
              <div className="swatches">
                {COLORS.map((c) => {
                  const on = filters.colors.includes(c.id);
                  return (
                    <button key={c.id} className={`swatch ${on ? 'on' : ''}`} aria-pressed={on} onClick={() => update({ colors: toggle(filters.colors, c.id) })} title={c.name}>
                      <span style={{ background: c.swatch }} />
                      <small>{c.name}</small>
                    </button>
                  );
                })}
              </div>
            </FilterGroup>

            <FilterGroup title="Preço">
              <PriceFilter min={filters.priceMin} max={filters.priceMax} onChange={(priceMin, priceMax) => update({ priceMin, priceMax })} />
            </FilterGroup>

            <FilterGroup title="Destaques">
              {(Object.keys(FLAG_LABELS) as Flag[])
                .filter((f) => !(preset === 'raros' && f === 'limitado'))
                .map((f) => (
                  <Check
                    key={f}
                    label={FLAG_LABELS[f]}
                    checked={filters.flags.includes(f)}
                    count={facetCount(products, filters, { flags: toggle(filters.flags, f) })}
                    onChange={() => update({ flags: toggle(filters.flags, f) })}
                    countIsResult={!filters.flags.includes(f)}
                  />
                ))}
            </FilterGroup>

            {!preset && (
              <FilterGroup title="Coleção">
                {COLLECTIONS.map((c) => (
                  <Check
                    key={c.id}
                    label={c.name}
                    checked={filters.collection === c.id}
                    count={facetCount(products, filters, { collection: c.id })}
                    onChange={() => update({ collection: filters.collection === c.id ? null : c.id })}
                    countIsResult
                  />
                ))}
              </FilterGroup>
            )}
          </div>
          <div className="filters-foot">
            <button className="btn btn-outline" onClick={clearAll} disabled={active === 0}>
              Limpar
            </button>
            <button className="btn btn-primary" onClick={() => setPanelOpen(false)}>
              Ver {results.length} {results.length === 1 ? 'produto' : 'produtos'}
            </button>
          </div>
        </aside>

        <section className="results" aria-live="polite" aria-busy={state.status === 'loading'}>
          <div className="toolbar">
            <button className="btn btn-outline btn-sm filter-toggle" onClick={() => setPanelOpen(true)}>
              <Icon name="filter" size={16} /> Filtros {active > 0 && <span className="pill">{active}</span>}
            </button>
            <p className="mono muted result-count">
              {state.status === 'ready' ? plural(results.length, 'produto', 'produtos') : state.status === 'loading' ? 'Carregando…' : '—'}
            </p>
            <label className="sort">
              <span className="mono muted">Ordenar</span>
              <select value={filters.sort} onChange={(e) => update({ sort: e.target.value as SortKey })}>
                {SORT_OPTIONS.map((o) => (
                  <option key={o.id} value={o.id}>
                    {o.label}
                  </option>
                ))}
              </select>
              <Icon name="chevronDown" size={14} />
            </label>
          </div>

          {chips.length > 0 && (
            <div className="active-chips">
              {chips.map((c) => (
                <button key={c.label} className="chip on" onClick={c.remove}>
                  {c.label} <Icon name="close" size={12} />
                </button>
              ))}
              {chips.length > 1 && (
                <button className="chip-clear mono" onClick={clearAll}>
                  Limpar tudo
                </button>
              )}
            </div>
          )}

          {state.status === 'loading' && (
            <div className="product-grid">
              {Array.from({ length: 6 }, (_, i) => (
                <SkeletonCard key={i} />
              ))}
            </div>
          )}

          {state.status === 'error' && (
            <EmptyState
              icon="alert"
              title="Algo deu errado"
              body={`${state.message} Verifique sua conexão e tente novamente.`}
              action={
                <button className="btn btn-primary" onClick={retry}>
                  Tentar novamente
                </button>
              }
            />
          )}

          {state.status === 'ready' && results.length === 0 && (
            <EmptyState
              icon="search"
              title="Nenhum tênis encontrado"
              body="Nenhum produto corresponde a essa combinação de filtros. Remova algum filtro ou tente outra busca."
              action={
                <button className="btn btn-primary" onClick={clearAll}>
                  Limpar filtros
                </button>
              }
            />
          )}

          {state.status === 'ready' && results.length > 0 && (
            <>
              <div className="product-grid">
                {shown.map((p) => (
                  <ProductCard key={p.id} product={p} />
                ))}
              </div>
              <div className="load-more" ref={sentinel}>
                <p className="mono muted">
                  Mostrando {shown.length} de {results.length}
                </p>
                <div className="load-bar">
                  <span style={{ width: `${(shown.length / results.length) * 100}%` }} />
                </div>
                {visible < results.length && (
                  <button className="btn btn-outline" onClick={() => setVisible((v) => v + PAGE_SIZE)}>
                    Carregar mais
                  </button>
                )}
              </div>
            </>
          )}
        </section>
      </div>
    </div>
  );
}

function priceLabel(min: number | null, max: number | null) {
  if (min !== null && max !== null) return `${formatPrice(min)} – ${formatPrice(max)}`;
  if (min !== null) return `A partir de ${formatPrice(min)}`;
  return `Até ${formatPrice(max ?? 0)}`;
}

function FilterGroup({ title, children }: { title: string; children: React.ReactNode }) {
  const [open, setOpen] = useState(true);
  return (
    <div className={`filter-group ${open ? 'open' : ''}`}>
      <button className="filter-group-head" onClick={() => setOpen(!open)} aria-expanded={open}>
        <span>{title}</span>
        <Icon name="chevronDown" size={16} />
      </button>
      {open && <div className="filter-group-body">{children}</div>}
    </div>
  );
}

function Check({ label, checked, count, onChange, countIsResult }: { label: string; checked: boolean; count: number; onChange: () => void; countIsResult: boolean }) {
  const disabled = !checked && count === 0;
  return (
    <label className={`checkbox ${disabled ? 'disabled' : ''}`}>
      <input type="checkbox" checked={checked} onChange={onChange} disabled={disabled} />
      <span>{label}</span>
      {countIsResult && <span className="mono muted count-n">{count}</span>}
    </label>
  );
}

function FilterSearch({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  const [v, setV] = useState(value);
  useEffect(() => setV(value), [value]);
  useEffect(() => {
    if (v === value) return;
    const t = window.setTimeout(() => onChange(v), 250);
    return () => window.clearTimeout(t);
  }, [v, value, onChange]);
  return (
    <div className="filter-search">
      <Icon name="search" size={16} />
      <input value={v} onChange={(e) => setV(e.target.value)} placeholder="Buscar nesta lista" aria-label="Buscar por nome ou marca" />
      {v && (
        <button onClick={() => setV('')} aria-label="Limpar busca">
          <Icon name="close" size={14} />
        </button>
      )}
    </div>
  );
}

function PriceFilter({ min, max, onChange }: { min: number | null; max: number | null; onChange: (min: number | null, max: number | null) => void }) {
  const [lo, setLo] = useState(min?.toString() ?? '');
  const [hi, setHi] = useState(max?.toString() ?? '');
  useEffect(() => {
    setLo(min?.toString() ?? '');
    setHi(max?.toString() ?? '');
  }, [min, max]);
  const apply = () => {
    const a = lo === '' ? null : Math.max(0, Number(lo));
    const b = hi === '' ? null : Math.max(0, Number(hi));
    if (a !== null && b !== null && a > b) onChange(b, a);
    else onChange(a, b);
  };
  return (
    <div className="price-filter">
      <div className="chips">
        {PRICE_PRESETS.map(([a, b, l]) => {
          const on = min === a && max === b;
          return (
            <button key={l} className={`chip ${on ? 'on' : ''}`} onClick={() => (on ? onChange(null, null) : onChange(a, b))} aria-pressed={on}>
              {l}
            </button>
          );
        })}
      </div>
      <form
        className="price-inputs"
        onSubmit={(e) => {
          e.preventDefault();
          apply();
        }}
      >
        <label>
          <span className="mono muted">Mín.</span>
          <input inputMode="numeric" value={lo} onChange={(e) => setLo(e.target.value.replace(/\D/g, ''))} onBlur={apply} placeholder="0" aria-label="Preço mínimo" />
        </label>
        <span className="muted">—</span>
        <label>
          <span className="mono muted">Máx.</span>
          <input inputMode="numeric" value={hi} onChange={(e) => setHi(e.target.value.replace(/\D/g, ''))} onBlur={apply} placeholder="4000" aria-label="Preço máximo" />
        </label>
      </form>
    </div>
  );
}

import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { BRANDS, PRODUCTS, getBrand } from '../data/catalog';
import { useDebounced, useEscape, useLockBody } from '../hooks';
import { formatPrice } from '../lib/format';
import { searchProducts, suggest } from '../lib/search';
import { useShop } from '../store/ShopProvider';
import { Icon } from './Icon';
import { ProductMedia } from './ui';

const POPULAR_TERMS = ['Aero 01', 'Apex High', 'Court 74', 'Polar X', 'Vulc Pro', 'Edição limitada'];

export function SearchOverlay() {
  const { searchOpen, setSearchOpen, history, pushHistory, clearHistory } = useShop();
  const [query, setQuery] = useState('');
  const [active, setActive] = useState(-1);
  const inputRef = useRef<HTMLInputElement>(null);
  const navigate = useNavigate();
  const q = useDebounced(query, 120);
  const close = () => setSearchOpen(false);

  useLockBody(searchOpen);
  useEscape(searchOpen, close);

  // Atalhos globais: Ctrl/⌘+K e "/" (fora de campos de texto).
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      const typing = target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName);
      if ((e.key.toLowerCase() === 'k' && (e.metaKey || e.ctrlKey)) || (e.key === '/' && !typing)) {
        e.preventDefault();
        setSearchOpen(true);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [setSearchOpen]);

  useEffect(() => {
    if (searchOpen) {
      setQuery('');
      setActive(-1);
      window.setTimeout(() => inputRef.current?.focus(), 30);
    }
  }, [searchOpen]);

  const results = useMemo(() => (q.trim() ? searchProducts(PRODUCTS, q).slice(0, 6) : []), [q]);
  const suggestions = useMemo(() => suggest(PRODUCTS, q, 5), [q]);
  const popular = useMemo(() => [...PRODUCTS].sort((a, b) => b.popularity - a.popularity).slice(0, 4), []);

  // Itens navegáveis por teclado: sugestões seguidas de produtos.
  const nav = [
    ...suggestions.map((s) => ({ to: s.to, label: s.label })),
    ...results.map((p) => ({ to: `/produto/${p.slug}`, label: `${p.name} ${p.model}` })),
  ];

  const go = (to: string, term?: string) => {
    if (term) pushHistory(term);
    close();
    navigate(to);
  };

  const submit = () => {
    if (active >= 0 && nav[active]) return go(nav[active].to, query);
    if (query.trim()) go(`/loja?q=${encodeURIComponent(query.trim())}`, query);
  };

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActive((a) => Math.min(nav.length - 1, a + 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActive((a) => Math.max(-1, a - 1));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      submit();
    }
  };

  const typing = q.trim().length > 0;

  return (
    <div className={`search ${searchOpen ? 'open' : ''}`} aria-hidden={!searchOpen} inert={!searchOpen}>
      <div className="search-backdrop" onClick={close} />
      <div className="search-panel" role="dialog" aria-modal="true" aria-label="Buscar produtos">
        <div className="search-bar container">
          <Icon name="search" size={22} />
          <input
            ref={inputRef}
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              setActive(-1);
            }}
            onKeyDown={onKeyDown}
            placeholder="Buscar por marca, modelo ou cor"
            aria-label="Buscar"
            role="combobox"
            aria-expanded={typing}
            aria-controls="search-results"
            aria-activedescendant={active >= 0 ? `sr-${active}` : undefined}
            autoComplete="off"
            spellCheck={false}
          />
          {query && (
            <button className="search-clear mono" onClick={() => setQuery('')}>
              Limpar
            </button>
          )}
          <button className="icon-btn" onClick={close} aria-label="Fechar busca">
            <Icon name="close" />
          </button>
        </div>

        <div className="search-content container" id="search-results">
          {!typing && (
            <div className="search-idle">
              <div className="search-col">
                {history.length > 0 && (
                  <section>
                    <header>
                      <h4 className="mono">Buscas recentes</h4>
                      <button className="mono muted" onClick={clearHistory}>
                        Limpar
                      </button>
                    </header>
                    <ul className="search-list">
                      {history.map((h) => (
                        <li key={h}>
                          <button onClick={() => go(`/loja?q=${encodeURIComponent(h)}`, h)}>
                            <Icon name="history" size={16} /> {h}
                          </button>
                        </li>
                      ))}
                    </ul>
                  </section>
                )}
                <section>
                  <header>
                    <h4 className="mono">Em alta</h4>
                  </header>
                  <div className="chips">
                    {POPULAR_TERMS.map((t) => (
                      <button key={t} className="chip" onClick={() => go(`/loja?q=${encodeURIComponent(t)}`, t)}>
                        <Icon name="trend" size={14} /> {t}
                      </button>
                    ))}
                  </div>
                </section>
                <section>
                  <header>
                    <h4 className="mono">Marcas</h4>
                  </header>
                  <div className="chips">
                    {BRANDS.map((b) => (
                      <button key={b.id} className="chip" onClick={() => go(`/loja?marca=${b.id}`)}>
                        {b.name}
                      </button>
                    ))}
                  </div>
                </section>
              </div>
              <section className="search-popular">
                <header>
                  <h4 className="mono">Produtos populares</h4>
                </header>
                <div className="search-products">
                  {popular.map((p) => (
                    <Link key={p.id} to={`/produto/${p.slug}`} onClick={close} className="search-product">
                      <div className="search-product-media">
                        <ProductMedia product={p} />
                      </div>
                      <span className="mono muted">{getBrand(p.brandId)?.name}</span>
                      <strong>
                        {p.name} “{p.model}”
                      </strong>
                      <span>{formatPrice(p.price)}</span>
                    </Link>
                  ))}
                </div>
              </section>
            </div>
          )}

          {typing && nav.length > 0 && (
            <div className="search-results">
              {suggestions.length > 0 && (
                <ul className="search-list search-suggestions" role="listbox">
                  {suggestions.map((s, i) => (
                    <li key={s.to} id={`sr-${i}`} role="option" aria-selected={active === i}>
                      <button className={active === i ? 'active' : ''} onMouseEnter={() => setActive(i)} onClick={() => go(s.to, s.label)}>
                        <Icon name="search" size={16} />
                        <Highlight text={s.label} query={q} />
                        <span className="mono muted kind">{s.kind === 'brand' ? 'Marca' : s.kind === 'category' ? 'Categoria' : 'Modelo'}</span>
                      </button>
                    </li>
                  ))}
                </ul>
              )}
              <div className="search-hits" role="listbox">
                {results.map((p, j) => {
                  const i = suggestions.length + j;
                  return (
                    <Link
                      key={p.id}
                      id={`sr-${i}`}
                      role="option"
                      aria-selected={active === i}
                      to={`/produto/${p.slug}`}
                      className={`search-hit ${active === i ? 'active' : ''}`}
                      onMouseEnter={() => setActive(i)}
                      onClick={() => {
                        pushHistory(query);
                        close();
                      }}
                    >
                      <div className="search-hit-media">
                        <ProductMedia product={p} />
                      </div>
                      <div>
                        <span className="mono muted">{getBrand(p.brandId)?.name}</span>
                        <strong>
                          <Highlight text={`${p.name} “${p.model}”`} query={q} />
                        </strong>
                        <span className="muted small">{p.colorway}</span>
                      </div>
                      <span className="search-hit-price">{formatPrice(p.price)}</span>
                    </Link>
                  );
                })}
              </div>
              <button className="link search-all" onClick={submit}>
                Ver todos os resultados para “{query.trim()}” <Icon name="arrowRight" size={16} />
              </button>
            </div>
          )}

          {typing && nav.length === 0 && (
            <div className="search-empty">
              <p className="display h3">Nada encontrado para “{q.trim()}”</p>
              <p className="muted">Confira a ortografia ou tente um termo mais amplo, como o nome da marca.</p>
              <div className="chips">
                {POPULAR_TERMS.slice(0, 4).map((t) => (
                  <button key={t} className="chip" onClick={() => setQuery(t)}>
                    {t}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
        <div className="search-hints container mono muted">
          <span><kbd>↑</kbd><kbd>↓</kbd> navegar</span>
          <span><kbd>Enter</kbd> abrir</span>
          <span><kbd>Esc</kbd> fechar</span>
        </div>
      </div>
    </div>
  );
}

function Highlight({ text, query }: { text: string; query: string }) {
  const q = query.trim().toLowerCase();
  if (!q) return <>{text}</>;
  // Normaliza caractere a caractere para manter os índices alinhados ao texto original.
  const fold = (str: string) => str.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  const folded = Array.from(text, (ch) => fold(ch).charAt(0) || ch).join('');
  const i = folded.indexOf(fold(q));
  if (i === -1) return <>{text}</>;
  return (
    <>
      {text.slice(0, i)}
      <mark>{text.slice(i, i + q.length)}</mark>
      {text.slice(i + q.length)}
    </>
  );
}

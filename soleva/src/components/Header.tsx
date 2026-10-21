import { useEffect, useState } from 'react';
import { Link, NavLink, useLocation } from 'react-router-dom';
import { CATEGORIES } from '../data/catalog';
import { useLockBody } from '../hooks';
import { useShop } from '../store/ShopProvider';
import { Icon } from './Icon';

export function Logo({ className = '' }: { className?: string }) {
  return (
    <Link to="/" className={`logo ${className}`} aria-label="SOLEVA — página inicial">
      <svg viewBox="0 0 28 28" width="26" height="26" aria-hidden="true">
        <rect width="28" height="28" rx="7" fill="currentColor" />
        <path d="M6 16.6c4.6-.9 6.4 2.7 11 1 3.7-1.4 4.4-3 4.4-3v3.2s-.9 1.9-4.2 3c-4.8 1.6-6.8-1.9-11.2-1.2z" fill="var(--accent)" />
      </svg>
      <span>SOLEVA</span>
    </Link>
  );
}

const NAV = [
  { to: '/loja?filtro=lancamento&ordem=novidades', label: 'Lançamentos' },
  ...CATEGORIES.map((c) => ({ to: `/loja/${c.id}`, label: c.name })),
  { to: '/raros', label: 'Raros' },
];

export function Header() {
  const { totals, favorites, setCartOpen, setSearchOpen } = useShop();
  const [menuOpen, setMenuOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const location = useLocation();
  useLockBody(menuOpen);

  useEffect(() => setMenuOpen(false), [location.pathname, location.search]);
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const isMac = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform);

  return (
    <>
      <div className="announce">
        <div className="announce-track">
          <span>Frete grátis acima de R$ 799</span>
          <span className="dot" />
          <span>Primeira troca grátis em até 30 dias</span>
          <span className="dot" />
          <span>Até 10x sem juros</span>
          <span className="dot" />
          <span>Autenticidade garantida em todos os pares</span>
        </div>
      </div>
      <header className={`header ${scrolled ? 'scrolled' : ''}`}>
        <div className="container header-inner">
          <button className="icon-btn menu-btn" onClick={() => setMenuOpen(true)} aria-label="Abrir menu" aria-expanded={menuOpen}>
            <Icon name="menu" />
          </button>
          <Logo />
          <nav className="nav" aria-label="Principal">
            {NAV.map((n) => (
              <NavLink key={n.label} to={n.to} className={({ isActive }) => (isActive && n.to !== '/loja?filtro=lancamento&ordem=novidades' ? 'active' : '')}>
                {n.label}
              </NavLink>
            ))}
          </nav>
          <div className="header-actions">
            <button className="search-trigger" onClick={() => setSearchOpen(true)} aria-label="Buscar (atalho: / ou Ctrl+K)">
              <Icon name="search" size={18} />
              <span>Buscar</span>
              <kbd>{isMac ? '⌘K' : 'Ctrl K'}</kbd>
            </button>
            <button className="icon-btn search-icon-only" onClick={() => setSearchOpen(true)} aria-label="Buscar">
              <Icon name="search" />
            </button>
            <Link to="/favoritos" className="icon-btn" aria-label={`Favoritos (${favorites.length})`}>
              <Icon name="heart" />
              {favorites.length > 0 && <span className="count">{favorites.length}</span>}
            </Link>
            <button className="icon-btn" onClick={() => setCartOpen(true)} aria-label={`Carrinho (${totals.itemCount} itens)`}>
              <Icon name="bag" />
              {totals.itemCount > 0 && <span className="count count-accent">{totals.itemCount}</span>}
            </button>
          </div>
        </div>
      </header>

      <div className={`mobile-menu dark ${menuOpen ? 'open' : ''}`} aria-hidden={!menuOpen} inert={!menuOpen}>
        <div className="mobile-menu-head">
          <Logo />
          <button className="icon-btn" onClick={() => setMenuOpen(false)} aria-label="Fechar menu">
            <Icon name="close" />
          </button>
        </div>
        <nav className="mobile-nav" aria-label="Menu móvel">
          {NAV.map((n, i) => (
            <Link key={n.label} to={n.to} style={{ ['--i' as string]: i }}>
              <span>{n.label}</span>
              <Icon name="arrowUpRight" size={22} />
            </Link>
          ))}
        </nav>
        <div className="mobile-menu-foot">
          <Link to="/loja">Ver loja completa</Link>
          <Link to="/favoritos">Favoritos</Link>
          <Link to="/ajuda/entregas">Ajuda</Link>
        </div>
      </div>
    </>
  );
}

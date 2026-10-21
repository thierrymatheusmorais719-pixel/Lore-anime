import { Link } from 'react-router-dom';
import { CATEGORIES } from '../data/catalog';
import { Logo } from './Header';
import { Icon } from './Icon';

export function Footer() {
  return (
    <footer className="footer dark grain">
      <div className="container">
        <div className="footer-top">
          <div className="footer-brand">
            <Logo />
            <p>
              Sneakers premium, lançamentos e edições limitadas. Curadoria feita em São Paulo, autenticidade garantida
              em cada par.
            </p>
            <div className="socials">
              <a href="https://instagram.com" target="_blank" rel="noreferrer" aria-label="Instagram" className="icon-btn"><Icon name="instagram" /></a>
              <a href="https://tiktok.com" target="_blank" rel="noreferrer" aria-label="TikTok" className="icon-btn"><Icon name="tiktok" /></a>
              <a href="https://youtube.com" target="_blank" rel="noreferrer" aria-label="YouTube" className="icon-btn"><Icon name="youtube" /></a>
              <a href="https://x.com" target="_blank" rel="noreferrer" aria-label="X" className="icon-btn"><Icon name="xsocial" /></a>
            </div>
          </div>
          <div className="footer-cols">
            <div>
              <h4>Loja</h4>
              <Link to="/loja?filtro=lancamento&ordem=novidades">Lançamentos</Link>
              {CATEGORIES.map((c) => (
                <Link key={c.id} to={`/loja/${c.id}`}>{c.name}</Link>
              ))}
              <Link to="/raros">Raros & limitados</Link>
              <Link to="/loja?filtro=promocao">Promoções</Link>
            </div>
            <div>
              <h4>Ajuda</h4>
              <Link to="/ajuda/entregas">Entregas e prazos</Link>
              <Link to="/ajuda/trocas">Trocas e devoluções</Link>
              <Link to="/ajuda/tamanhos">Guia de tamanhos</Link>
              <Link to="/ajuda/pagamentos">Pagamentos</Link>
              <Link to="/ajuda/autenticidade">Autenticidade</Link>
            </div>
            <div>
              <h4>Atendimento</h4>
              <a href="mailto:atendimento@soleva.example">atendimento@soleva.example</a>
              <span>Seg. a sex., 9h às 18h</span>
              <span>Sáb., 9h às 13h</span>
              <Link to="/ajuda/contato">Fale conosco</Link>
            </div>
          </div>
        </div>
        <div className="footer-word" aria-hidden="true">SOLEVA</div>
        <div className="footer-bottom">
          <span>© {new Date().getFullYear()} SOLEVA. Projeto de demonstração. Marcas citadas pertencem aos seus donos.</span>
          <div>
            <Link to="/ajuda/privacidade">Privacidade</Link>
            <Link to="/ajuda/termos">Termos de uso</Link>
          </div>
        </div>
      </div>
    </footer>
  );
}

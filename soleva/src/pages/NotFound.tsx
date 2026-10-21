import { Link } from 'react-router-dom';
import { useDocumentTitle } from '../hooks';

export function NotFound() {
  useDocumentTitle('Página não encontrada');
  return (
    <div className="container page-pad notfound">
      <p className="display notfound-code">404</p>
      <h1 className="display h2">Esse par sumiu da prateleira.</h1>
      <p className="lead">A página que você procura não existe ou mudou de endereço.</p>
      <div className="hero-cta">
        <Link to="/" className="btn btn-primary">Voltar ao início</Link>
        <Link to="/loja" className="btn btn-outline">Ir para a loja</Link>
      </div>
    </div>
  );
}

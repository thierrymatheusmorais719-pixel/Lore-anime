import { Link } from 'react-router-dom';
import { getProduct } from '../data/catalog';
import { Icon } from '../components/Icon';
import { ProductCard } from '../components/ProductCard';
import { EmptyState } from '../components/ui';
import { useDocumentTitle } from '../hooks';
import { useShop } from '../store/ShopProvider';

export function Favorites() {
  useDocumentTitle('Favoritos');
  const { favorites } = useShop();
  const products = favorites.map(getProduct).filter((p) => p !== undefined);
  return (
    <div className="container page-pad">
      <span className="eyebrow">Sua lista</span>
      <h1 className="display h1">
        Favoritos <span className="mono muted">({products.length})</span>
      </h1>
      {products.length === 0 ? (
        <EmptyState
          icon="heart"
          title="Nenhum favorito ainda"
          body="Toque no coração de qualquer produto para salvá-lo aqui e acompanhar preço e disponibilidade."
          action={
            <Link to="/loja" className="btn btn-primary">
              Explorar a loja <Icon name="arrowRight" size={18} className="arrow" />
            </Link>
          }
        />
      ) : (
        <div className="product-grid product-grid-4" style={{ marginTop: 32 }}>
          {products.map((p) => (
            <ProductCard key={p.id} product={p} />
          ))}
        </div>
      )}
    </div>
  );
}

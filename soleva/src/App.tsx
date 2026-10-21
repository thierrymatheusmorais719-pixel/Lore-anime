import { Outlet, ScrollRestoration, createBrowserRouter } from 'react-router-dom';
import { CartDrawer } from './components/CartDrawer';
import { Footer } from './components/Footer';
import { Header } from './components/Header';
import { SearchOverlay } from './components/SearchOverlay';
import { Toasts } from './components/Toasts';
import { CartPage } from './pages/CartPage';
import { Checkout } from './pages/Checkout';
import { Favorites } from './pages/Favorites';
import { Home } from './pages/Home';
import { Info } from './pages/Info';
import { NotFound } from './pages/NotFound';
import { OrderPage } from './pages/OrderPage';
import { ProductPage } from './pages/ProductPage';
import { Shop } from './pages/Shop';
import { ShopProvider } from './store/ShopProvider';

function Layout() {
  return (
    <ShopProvider>
      <a href="#main" className="skip-link">
        Pular para o conteúdo
      </a>
      <Header />
      <main id="main">
        <Outlet />
      </main>
      <Footer />
      <CartDrawer />
      <SearchOverlay />
      <Toasts />
      <ScrollRestoration getKey={(location) => location.pathname} />
    </ShopProvider>
  );
}

export const router = createBrowserRouter(
  [
    {
      element: <Layout />,
      children: [
        { path: '/', element: <Home /> },
        { path: '/loja', element: <Shop /> },
        { path: '/loja/:categoria', element: <Shop /> },
        { path: '/raros', element: <Shop preset="raros" /> },
        { path: '/produto/:slug', element: <ProductPage /> },
        { path: '/carrinho', element: <CartPage /> },
        { path: '/checkout', element: <Checkout /> },
        { path: '/pedido/:id', element: <OrderPage /> },
        { path: '/favoritos', element: <Favorites /> },
        { path: '/ajuda/:topic', element: <Info /> },
        { path: '*', element: <NotFound /> },
      ],
    },
  ],
  { basename: import.meta.env.BASE_URL.replace(/\/$/, '') || '/' },
);

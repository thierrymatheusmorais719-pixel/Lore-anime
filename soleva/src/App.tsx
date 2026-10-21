import { Outlet, ScrollRestoration, createBrowserRouter, createMemoryRouter, useLocation } from 'react-router-dom';
import { CartDrawer } from './components/CartDrawer';
import { Footer } from './components/Footer';
import { CursorBubble } from './components/CursorBubble';
import { Header } from './components/Header';
import { IntroProvider } from './components/Intro';
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
  const { pathname } = useLocation();
  return (
    <ShopProvider>
      <IntroProvider>
      <a href="#main" className="skip-link">
        Pular para o conteúdo
      </a>
      <Header />
      <main id="main">
        {/* A chave pelo caminho reinicia a animação de entrada a cada troca de página. */}
        <div className="page-enter" key={pathname}>
          <Outlet />
        </div>
      </main>
      <Footer />
      <CartDrawer />
      <SearchOverlay />
      <Toasts />
      <CursorBubble />
      <ScrollRestoration getKey={(location) => location.pathname} />
      </IntroProvider>
    </ShopProvider>
  );
}

const routes = [
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
];

// VITE_ROUTER=memory: para ambientes embutidos (iframes/sandboxes) sem controle da URL.
export const router =
  import.meta.env.VITE_ROUTER === 'memory'
    ? createMemoryRouter(routes)
    : createBrowserRouter(routes, { basename: import.meta.env.BASE_URL.replace(/\/$/, '') || '/' });

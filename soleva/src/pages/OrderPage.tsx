import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { getProduct } from '../data/catalog';
import { Icon } from '../components/Icon';
import { EmptyState, ProductMedia } from '../components/ui';
import { useDocumentTitle } from '../hooks';
import { formatPrice } from '../lib/format';
import { getOrder, saveOrder } from '../services/orders';
import { getPaymentProvider } from '../services/payments';
import type { Order } from '../types';

const STATUS: Record<Order['status'], { title: string; body: string; tone: string; icon: 'info' | 'clock' | 'check' | 'alert' }> = {
  demo: {
    title: 'Pedido de demonstração registrado',
    body: 'Nenhum pagamento foi processado e nenhuma cobrança foi feita. Este pedido existe apenas neste navegador, para fins de demonstração.',
    tone: 'demo',
    icon: 'info',
  },
  awaiting_payment: {
    title: 'Aguardando confirmação do pagamento',
    body: 'Assim que o provedor de pagamento confirmar, você receberá um e-mail e o pedido seguirá para separação.',
    tone: 'pending',
    icon: 'clock',
  },
  paid: {
    title: 'Pagamento confirmado',
    body: 'Recebemos a confirmação do provedor de pagamento. Seu pedido já está em separação.',
    tone: 'ok',
    icon: 'check',
  },
  payment_failed: {
    title: 'Pagamento não aprovado',
    body: 'O provedor recusou o pagamento. Você pode tentar novamente com outra forma de pagamento.',
    tone: 'error',
    icon: 'alert',
  },
};

export function OrderPage() {
  const { id = '' } = useParams();
  const [order, setOrder] = useState<Order | undefined>(() => getOrder(id));
  useDocumentTitle(order ? `Pedido ${order.id}` : 'Pedido');

  // Para provedores reais, o status vem do back-end (alimentado por webhooks).
  useEffect(() => {
    if (!order || order.status !== 'awaiting_payment') return;
    const provider = getPaymentProvider();
    if (!provider.fetchStatus) return;
    let alive = true;
    const poll = async () => {
      const status = await provider.fetchStatus!(order.id).catch(() => order.status);
      if (alive && status !== order.status) {
        const next = { ...order, status };
        saveOrder(next);
        setOrder(next);
      }
    };
    poll();
    const t = window.setInterval(poll, 8000);
    return () => {
      alive = false;
      window.clearInterval(t);
    };
  }, [order]);

  if (!order) {
    return (
      <div className="container page-pad">
        <EmptyState
          icon="package"
          title="Pedido não encontrado"
          body="Os pedidos de demonstração ficam salvos apenas no navegador em que foram feitos."
          action={
            <Link to="/" className="btn btn-primary">
              Voltar ao início
            </Link>
          }
        />
      </div>
    );
  }

  const s = STATUS[order.status];
  return (
    <div className="container page-pad order">
      <div className={`order-status status-${s.tone}`}>
        <div className="order-icon">
          <Icon name={s.icon} size={26} />
        </div>
        <div>
          <span className="mono">Pedido {order.id}</span>
          <h1 className="display h2">{s.title}</h1>
          <p>{s.body}</p>
        </div>
      </div>

      <div className="order-grid">
        <section>
          <h2 className="display h3">Itens</h2>
          <ul className="mini-lines">
            {order.lines.map((l) => {
              const p = getProduct(l.productId);
              return (
                <li key={`${l.productId}-${l.size}`}>
                  <div className="mini-thumb">
                    {p && <ProductMedia product={p} />}
                    <span className="mini-qty">{l.quantity}</span>
                  </div>
                  <div>
                    <span className="mono muted">{l.brand}</span>
                    <strong>{l.name}</strong>
                    <span className="muted small">Tam. {l.size}</span>
                  </div>
                  <span>{formatPrice(l.unitPrice * l.quantity)}</span>
                </li>
              );
            })}
          </ul>
          <dl className="totals">
            <div><dt>Subtotal</dt><dd>{formatPrice(order.subtotal)}</dd></div>
            {order.discount > 0 && <div className="discount"><dt>Desconto {order.coupon && `(${order.coupon})`}</dt><dd>− {formatPrice(order.discount)}</dd></div>}
            <div><dt>Frete — {order.shipping.label}</dt><dd>{order.shippingCost === 0 ? 'Grátis' : formatPrice(order.shippingCost)}</dd></div>
            <div className="grand"><dt>Total</dt><dd>{formatPrice(order.total)}</dd></div>
          </dl>
        </section>
        <aside className="order-side">
          <div>
            <h3 className="mono">Entrega</h3>
            <p>
              {order.customer.name}
              <br />
              {order.address.street}, {order.address.number}
              {order.address.complement && ` — ${order.address.complement}`}
              <br />
              {order.address.district} · {order.address.city}/{order.address.state}
              <br />
              CEP {order.address.cep}
            </p>
            <p className="muted small">
              Prazo estimado: {order.shipping.days[0]}–{order.shipping.days[1]} dias úteis após a confirmação do pagamento.
            </p>
          </div>
          <div>
            <h3 className="mono">Contato</h3>
            <p>
              {order.customer.email}
              <br />
              {order.customer.phone}
            </p>
          </div>
          <ol className="timeline">
            <li className="done">Pedido registrado · {new Date(order.createdAt).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })}</li>
            <li className={order.status === 'paid' ? 'done' : ''}>Pagamento confirmado pelo provedor</li>
            <li>Separação e autenticação</li>
            <li>Enviado</li>
            <li>Entregue</li>
          </ol>
          <Link to="/loja" className="btn btn-primary btn-block">
            Continuar comprando
          </Link>
        </aside>
      </div>
    </div>
  );
}

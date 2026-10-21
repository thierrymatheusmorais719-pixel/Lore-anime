import type { Order } from '../../types';
import type { PaymentProvider } from './types';

/**
 * Provedores com checkout hospedado. O front envia o pedido ao SEU back-end,
 * que cria a preferência (Mercado Pago) ou a Checkout Session (Stripe) com a
 * chave secreta e devolve a URL de pagamento. Contrato esperado:
 *
 *   POST {VITE_API_URL}/payments/{provider}/checkout   body: Order
 *     -> 200 { "url": "https://..." }
 *   GET  {VITE_API_URL}/orders/{id}/status
 *     -> 200 { "status": "awaiting_payment" | "paid" | "payment_failed" }
 */
function hosted(id: 'mercadopago' | 'stripe', label: string, apiUrl: string): PaymentProvider {
  return {
    id,
    label,
    isDemo: false,
    async start(order: Order) {
      const res = await fetch(`${apiUrl}/payments/${id}/checkout`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(order),
      });
      if (!res.ok) throw new Error('Não foi possível iniciar o pagamento. Tente novamente.');
      const data = (await res.json()) as { url?: string };
      if (!data.url) throw new Error('Resposta inválida do servidor de pagamentos.');
      return { kind: 'redirect', url: data.url };
    },
    async fetchStatus(orderId: string) {
      const res = await fetch(`${apiUrl}/orders/${encodeURIComponent(orderId)}/status`);
      if (!res.ok) return 'awaiting_payment';
      const data = (await res.json()) as { status?: Order['status'] };
      return data.status ?? 'awaiting_payment';
    },
  };
}

export const mercadoPagoProvider = (apiUrl: string) => hosted('mercadopago', 'Mercado Pago', apiUrl);
export const stripeProvider = (apiUrl: string) => hosted('stripe', 'Stripe', apiUrl);

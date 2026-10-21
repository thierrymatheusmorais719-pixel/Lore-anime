import type { Order } from '../../types';

/**
 * Resultado de iniciar um pagamento.
 * - `redirect`: o provedor hospeda o checkout (Mercado Pago Checkout Pro / Stripe Checkout).
 * - `demo`: nenhum pagamento é processado; pedido fica marcado como demonstração.
 *
 * Um pedido só deve ser considerado PAGO quando o back-end receber a confirmação
 * do provedor (webhook) — nunca a partir do retorno do navegador.
 */
export type PaymentStart =
  | { kind: 'redirect'; url: string }
  | { kind: 'demo' };

export interface PaymentProvider {
  id: 'demo' | 'mercadopago' | 'stripe';
  label: string;
  isDemo: boolean;
  start(order: Order): Promise<PaymentStart>;
  /** Consulta o status confirmado pelo back-end (alimentado por webhooks). */
  fetchStatus?(orderId: string): Promise<Order['status']>;
}

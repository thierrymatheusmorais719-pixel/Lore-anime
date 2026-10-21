import { demoProvider } from './demo';
import { mercadoPagoProvider, stripeProvider } from './hosted';
import type { PaymentProvider } from './types';

export type { PaymentProvider, PaymentStart } from './types';

/**
 * Seleciona o provedor pelas variáveis de ambiente. Sem back-end configurado
 * (VITE_API_URL), cai SEMPRE no modo demonstração.
 */
export function getPaymentProvider(): PaymentProvider {
  const provider = import.meta.env.VITE_PAYMENT_PROVIDER as string | undefined;
  const apiUrl = (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, '');
  if (!apiUrl) return demoProvider;
  if (provider === 'mercadopago') return mercadoPagoProvider(apiUrl);
  if (provider === 'stripe') return stripeProvider(apiUrl);
  return demoProvider;
}

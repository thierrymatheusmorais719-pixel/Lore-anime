import type { PaymentProvider } from './types';

export const demoProvider: PaymentProvider = {
  id: 'demo',
  label: 'Modo demonstração',
  isDemo: true,
  async start() {
    await new Promise((r) => setTimeout(r, 700));
    return { kind: 'demo' };
  },
};

import type { ShippingOption } from '../types';
import { onlyDigits } from '../lib/validation';

/**
 * Contrato para cotação de frete. A implementação local abaixo é uma ESTIMATIVA
 * por região do CEP; para produção, implemente `ShippingProvider` chamando
 * Correios, Melhor Envio, Frenet etc. pelo seu back-end.
 */
export interface ShippingProvider {
  quote(cep: string, items: { quantity: number }[]): Promise<ShippingOption[]>;
}

// Faixas por primeiro dígito do CEP: [preço base, prazo mín., prazo máx.]
const REGIONS: Record<string, [number, number, number]> = {
  '0': [19.9, 1, 3], // Grande SP
  '1': [24.9, 2, 4], // Interior SP
  '2': [27.9, 2, 5], // RJ / ES
  '3': [29.9, 3, 6], // MG
  '4': [36.9, 4, 8], // BA / SE
  '5': [39.9, 5, 9], // PE / AL / PB / RN
  '6': [44.9, 6, 11], // CE / PI / MA / Norte
  '7': [34.9, 4, 8], // Centro-Oeste / TO
  '8': [29.9, 3, 6], // PR / SC
  '9': [31.9, 3, 7], // RS
};

export const localEstimator: ShippingProvider = {
  async quote(cep, items) {
    await new Promise((r) => setTimeout(r, 380));
    const d = onlyDigits(cep);
    if (d.length !== 8) throw new Error('CEP inválido');
    const [base, min, max] = REGIONS[d[0]];
    const pairs = items.reduce((a, b) => a + b.quantity, 0);
    const extra = Math.max(0, pairs - 1) * 6;
    return [
      { id: 'padrao', label: 'Entrega padrão', carrier: 'Transportadora', price: round(base + extra), days: [min, max], estimate: true },
      { id: 'expressa', label: 'Entrega expressa', carrier: 'Expressa', price: round(base * 1.9 + extra), days: [Math.max(1, min - 1), Math.max(2, min + 1)], estimate: true },
    ];
  },
};

const round = (n: number) => Math.round(n * 100) / 100;

export const shippingProvider: ShippingProvider = localEstimator;

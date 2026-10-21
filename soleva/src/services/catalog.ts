import { PRODUCTS } from '../data/catalog';
import type { Product } from '../types';

/**
 * Camada de acesso ao catálogo. Hoje lê os dados locais com latência simulada;
 * para usar uma API real, troque a implementação de `fetchProducts` mantendo a assinatura.
 */
const LATENCY_MS = 420;

export class CatalogError extends Error {}

export async function fetchProducts(signal?: AbortSignal): Promise<Product[]> {
  await delay(LATENCY_MS, signal);
  // Permite visualizar o estado de erro: /loja?simular=erro
  if (new URLSearchParams(window.location.search).get('simular') === 'erro') {
    throw new CatalogError('Não foi possível carregar o catálogo.');
  }
  return PRODUCTS;
}

function delay(ms: number, signal?: AbortSignal) {
  return new Promise<void>((resolve, reject) => {
    const t = window.setTimeout(resolve, ms);
    signal?.addEventListener('abort', () => {
      window.clearTimeout(t);
      reject(new DOMException('Aborted', 'AbortError'));
    });
  });
}

import { readJSON, writeJSON } from '../lib/storage';
import type { Order } from '../types';

const KEY = 'soleva:orders';

export const listOrders = () => readJSON<Order[]>(KEY, []);
export const getOrder = (id: string) => listOrders().find((o) => o.id === id);

export function saveOrder(order: Order) {
  writeJSON(KEY, [order, ...listOrders().filter((o) => o.id !== order.id)].slice(0, 20));
}

export function newOrderId() {
  const n = Math.floor(Math.random() * 900000 + 100000);
  return `SLV-${new Date().getFullYear()}-${n}`;
}

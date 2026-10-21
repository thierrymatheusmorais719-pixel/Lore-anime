import { getBrand } from '../data/catalog';
import type { Product } from '../types';

const DAY = 86_400_000;
const NEW_WINDOW_DAYS = 45;

const releaseTime = (p: Product) => new Date(`${p.releaseDate}T10:00:00-03:00`).getTime();

export const isUpcoming = (p: Product, now = Date.now()) => releaseTime(p) > now;

export const isNew = (p: Product, now = Date.now()) => {
  const t = releaseTime(p);
  return t <= now && now - t < NEW_WINDOW_DAYS * DAY;
};

export const isOnSale = (p: Product) => Boolean(p.compareAtPrice && p.compareAtPrice > p.price);

export const discountPercent = (p: Product) =>
  p.compareAtPrice ? Math.round((1 - p.price / p.compareAtPrice) * 100) : 0;

export const totalStock = (p: Product) => Object.values(p.stock).reduce((a, b) => a + b, 0);

export const availableSizes = (p: Product) => Object.keys(p.stock).filter((s) => p.stock[s] > 0);

export const brandName = (p: Product) => getBrand(p.brandId)?.name ?? '';

export const fullName = (p: Product) => `${brandName(p)} ${p.name} “${p.model}”`;

export const releaseTimestamp = releaseTime;

export type Badge = { label: string; tone: 'accent' | 'dark' | 'light' | 'sale' };

export function productBadges(p: Product, now = Date.now()): Badge[] {
  const badges: Badge[] = [];
  if (isUpcoming(p, now)) badges.push({ label: 'Em breve', tone: 'accent' });
  else if (isNew(p, now)) badges.push({ label: 'Lançamento', tone: 'accent' });
  if (p.limited) badges.push({ label: `Edição limitada`, tone: 'dark' });
  if (isOnSale(p)) badges.push({ label: `-${discountPercent(p)}%`, tone: 'sale' });
  if (!isUpcoming(p, now) && totalStock(p) === 0) badges.push({ label: 'Esgotado', tone: 'light' });
  return badges;
}

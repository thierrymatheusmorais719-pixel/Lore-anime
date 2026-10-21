export type CategoryId = 'lifestyle' | 'basketball' | 'running' | 'skate' | 'streetwear';

export type ColorId =
  | 'preto'
  | 'branco'
  | 'cinza'
  | 'verde'
  | 'vermelho'
  | 'azul'
  | 'bege'
  | 'laranja'
  | 'roxo'
  | 'marrom';

/** Silhuetas suportadas pelo renderizador de produto (SneakerArt). */
export type Silhouette = 'court' | 'high' | 'runner' | 'skate';

export interface Palette {
  upper: string;
  overlay: string;
  accent: string;
  midsole: string;
  outsole: string;
  laces: string;
  lining: string;
}

export interface Brand {
  id: string;
  name: string;
  origin: string;
  tagline: string;
}

export interface Product {
  id: string;
  slug: string;
  name: string;
  model: string;
  brandId: string;
  category: CategoryId;
  colorway: string;
  colors: ColorId[];
  silhouette: Silhouette;
  palette: Palette;
  /** URLs de fotos reais. Quando vazio, a galeria usa o render vetorial do produto. */
  images?: string[];
  price: number;
  compareAtPrice?: number;
  releaseDate: string;
  limited?: { totalPairs: number };
  collection?: string;
  popularity: number;
  rating: number;
  reviewCount: number;
  /** Estoque por numeração (BR). */
  stock: Record<string, number>;
  description: string;
  materials: string[];
  features: string[];
  sku: string;
}

export interface Review {
  id: string;
  productId: string;
  author: string;
  city: string;
  rating: number;
  title: string;
  body: string;
  size: string;
  fit: 'pequeno' | 'normal' | 'grande';
  date: string;
  verified: boolean;
  local?: boolean;
}

export interface CartItem {
  productId: string;
  size: string;
  quantity: number;
}

export interface Coupon {
  code: string;
  label: string;
  type: 'percent' | 'fixed' | 'shipping';
  value: number;
  minSubtotal?: number;
}

export interface Address {
  cep: string;
  street: string;
  number: string;
  complement: string;
  district: string;
  city: string;
  state: string;
}

export interface Customer {
  name: string;
  email: string;
  cpf: string;
  phone: string;
}

export interface ShippingOption {
  id: string;
  label: string;
  carrier: string;
  price: number;
  days: [number, number];
  estimate: boolean;
}

export type OrderStatus =
  | 'demo'
  | 'awaiting_payment'
  | 'paid'
  | 'payment_failed';

export interface OrderLine {
  productId: string;
  name: string;
  brand: string;
  size: string;
  quantity: number;
  unitPrice: number;
}

export interface Order {
  id: string;
  createdAt: string;
  status: OrderStatus;
  provider: string;
  customer: Customer;
  address: Address;
  shipping: ShippingOption;
  lines: OrderLine[];
  coupon?: string;
  subtotal: number;
  discount: number;
  shippingCost: number;
  total: number;
}

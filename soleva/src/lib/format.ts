const brl = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

export const formatPrice = (value: number) => brl.format(value);

export const installments = (value: number, max = 10, minInstallment = 50) => {
  const n = Math.max(1, Math.min(max, Math.floor(value / minInstallment)));
  return { count: n, value: value / n };
};

export const formatDate = (iso: string, opts: Intl.DateTimeFormatOptions = { day: '2-digit', month: 'short' }) =>
  new Date(`${iso.slice(0, 10)}T12:00:00`).toLocaleDateString('pt-BR', opts).replace('.', '');

export const plural = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`;

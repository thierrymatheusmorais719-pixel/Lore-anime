import type { Address, Customer } from '../types';

export const onlyDigits = (s: string) => s.replace(/\D/g, '');

export function isValidCPF(value: string): boolean {
  const cpf = onlyDigits(value);
  if (cpf.length !== 11 || /^(\d)\1{10}$/.test(cpf)) return false;
  const calc = (len: number) => {
    let sum = 0;
    for (let i = 0; i < len; i++) sum += Number(cpf[i]) * (len + 1 - i);
    const r = (sum * 10) % 11;
    return r === 10 ? 0 : r;
  };
  return calc(9) === Number(cpf[9]) && calc(10) === Number(cpf[10]);
}

export const isValidEmail = (v: string) => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v.trim());
export const isValidCEP = (v: string) => onlyDigits(v).length === 8;
export const isValidPhone = (v: string) => {
  const d = onlyDigits(v);
  return d.length === 10 || d.length === 11;
};

export const UF = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA',
  'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
];

export const maskCPF = (v: string) =>
  onlyDigits(v)
    .slice(0, 11)
    .replace(/(\d{3})(\d)/, '$1.$2')
    .replace(/(\d{3})(\d)/, '$1.$2')
    .replace(/(\d{3})(\d{1,2})$/, '$1-$2');

export const maskCEP = (v: string) => onlyDigits(v).slice(0, 8).replace(/(\d{5})(\d)/, '$1-$2');

export const maskPhone = (v: string) => {
  const d = onlyDigits(v).slice(0, 11);
  if (d.length <= 10) return d.replace(/(\d{2})(\d)/, '($1) $2').replace(/(\d{4})(\d)/, '$1-$2');
  return d.replace(/(\d{2})(\d)/, '($1) $2').replace(/(\d{5})(\d)/, '$1-$2');
};

export type Errors<T> = Partial<Record<keyof T, string>>;

export function validateCustomer(c: Customer): Errors<Customer> {
  const e: Errors<Customer> = {};
  if (c.name.trim().split(/\s+/).length < 2) e.name = 'Informe nome e sobrenome.';
  if (!isValidEmail(c.email)) e.email = 'E-mail inválido.';
  if (!isValidCPF(c.cpf)) e.cpf = 'CPF inválido.';
  if (!isValidPhone(c.phone)) e.phone = 'Telefone com DDD, ex.: (11) 91234-5678.';
  return e;
}

export function validateAddress(a: Address): Errors<Address> {
  const e: Errors<Address> = {};
  if (!isValidCEP(a.cep)) e.cep = 'CEP deve ter 8 dígitos.';
  if (a.street.trim().length < 3) e.street = 'Informe a rua.';
  if (!a.number.trim()) e.number = 'Informe o número (ou “S/N”).';
  if (a.district.trim().length < 2) e.district = 'Informe o bairro.';
  if (a.city.trim().length < 2) e.city = 'Informe a cidade.';
  if (!UF.includes(a.state)) e.state = 'Selecione o estado.';
  return e;
}

import { onlyDigits } from '../lib/validation';

export interface CepResult {
  street: string;
  district: string;
  city: string;
  state: string;
}

/** Autopreenchimento de endereço via ViaCEP (API pública, sem chave). */
export async function lookupCep(cep: string, signal?: AbortSignal): Promise<CepResult | null> {
  const d = onlyDigits(cep);
  if (d.length !== 8) return null;
  try {
    const res = await fetch(`https://viacep.com.br/ws/${d}/json/`, { signal });
    if (!res.ok) return null;
    const data = await res.json();
    if (data.erro) return null;
    return { street: data.logradouro ?? '', district: data.bairro ?? '', city: data.localidade ?? '', state: data.uf ?? '' };
  } catch {
    return null;
  }
}

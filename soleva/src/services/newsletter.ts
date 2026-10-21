import { readJSON, writeJSON } from '../lib/storage';

/** Sem back-end de e-mail configurado, o cadastro fica apenas neste navegador. */
export async function subscribe(email: string) {
  await new Promise((r) => setTimeout(r, 500));
  const list = readJSON<string[]>('soleva:newsletter', []);
  if (!list.includes(email)) writeJSON('soleva:newsletter', [...list, email]);
}

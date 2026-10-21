import { copyFileSync } from 'node:fs';
import { resolve } from 'node:path';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

// Hospedagens estáticas (GitHub Pages, S3) servem 404.html para rotas
// desconhecidas: copiamos o index para que o roteamento SPA funcione.
const spaFallback = () => ({
  name: 'spa-fallback',
  closeBundle() {
    const out = resolve(import.meta.dirname, 'dist');
    copyFileSync(resolve(out, 'index.html'), resolve(out, '404.html'));
  },
});

export default defineConfig({
  base: process.env.SOLEVA_BASE ?? '/',
  plugins: [react(), spaFallback()],
  test: { environment: 'node', include: ['src/**/*.test.ts'] },
});

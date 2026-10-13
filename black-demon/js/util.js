// Utilitários: matemática, easing e aleatório determinístico.
// Tudo que é "aleatório" depende só de (índice, semente), então qualquer
// instante do filme pode ser desenhado de novo igual (seek, exportar vídeo).

export const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
export const lerp = (a, b, t) => a + (b - a) * t;
export const seg = (t, a, b) => clamp((t - a) / (b - a));
export const smooth = (t) => t * t * (3 - 2 * t);

export const ease = {
  inOut: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  out: (t) => 1 - Math.pow(1 - t, 3),
  in: (t) => t * t * t,
  outExpo: (t) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t)),
  inExpo: (t) => (t <= 0 ? 0 : Math.pow(2, 10 * t - 10)),
  outBack: (t) => 1 + 2.70158 * Math.pow(t - 1, 3) + 1.70158 * Math.pow(t - 1, 2),
};

export function rand(i, s = 0) {
  const x = Math.sin(i * 127.1 + s * 311.7 + 0.137) * 43758.5453;
  return x - Math.floor(x);
}
export const rrange = (i, s, a, b) => a + (b - a) * rand(i, s);

// Ruído 1D suave (para tremor de câmera e cintilação)
export function noise1(x, s = 0) {
  const i = Math.floor(x), f = x - i;
  return lerp(rand(i, s), rand(i + 1, s), smooth(f)) * 2 - 1;
}

// Pulso que decai após cada instante da lista (batidas, impactos)
export function pulse(t, times, decay = 6) {
  let v = 0;
  for (const k of times) {
    const d = t - k;
    if (d >= 0 && d < 3) v = Math.max(v, Math.exp(-d * decay));
  }
  return v;
}

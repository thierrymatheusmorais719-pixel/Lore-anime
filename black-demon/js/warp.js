// Deformação por malha (estilo Live2D): o desenho é dividido em triângulos e cada
// vértice é deslocado por um campo suave. Assim a cabeça vira, inclina e o cabelo
// balança sem redesenhar nada.

// Transformação afim que leva o triângulo s (origem) ao triângulo d (destino)
function affine(s0, s1, s2, d0, d1, d2) {
  const den = (s1[0] - s0[0]) * (s2[1] - s0[1]) - (s2[0] - s0[0]) * (s1[1] - s0[1]);
  const a = ((d1[0] - d0[0]) * (s2[1] - s0[1]) - (d2[0] - d0[0]) * (s1[1] - s0[1])) / den;
  const c = ((d2[0] - d0[0]) * (s1[0] - s0[0]) - (d1[0] - d0[0]) * (s2[0] - s0[0])) / den;
  const b = ((d1[1] - d0[1]) * (s2[1] - s0[1]) - (d2[1] - d0[1]) * (s1[1] - s0[1])) / den;
  const d = ((d2[1] - d0[1]) * (s1[0] - s0[0]) - (d1[1] - d0[1]) * (s2[0] - s0[0])) / den;
  return [a, b, c, d, d0[0] - a * s0[0] - c * s0[1], d0[1] - b * s0[0] - d * s0[1]];
}

// Aumenta o triângulo um pouquinho em volta do centro, para não aparecer fresta entre eles
function inflate(p, cx, cy, by = 0.9) {
  const dx = p[0] - cx, dy = p[1] - cy, L = Math.hypot(dx, dy) || 1;
  return [p[0] + (dx / L) * by, p[1] + (dy / L) * by];
}

function tri(ctx, img, s0, s1, s2, d0, d1, d2) {
  const cx = (d0[0] + d1[0] + d2[0]) / 3, cy = (d0[1] + d1[1] + d2[1]) / 3;
  ctx.save();
  ctx.beginPath();
  const [a, b, c] = [inflate(d0, cx, cy), inflate(d1, cx, cy), inflate(d2, cx, cy)];
  ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.lineTo(c[0], c[1]);
  ctx.closePath();
  ctx.clip();
  ctx.transform(...affine(s0, s1, s2, d0, d1, d2));
  // só a parte da imagem que o triângulo usa (bem mais rápido que a imagem inteira)
  const x0 = Math.max(0, Math.floor(Math.min(s0[0], s1[0], s2[0])) - 2);
  const y0 = Math.max(0, Math.floor(Math.min(s0[1], s1[1], s2[1])) - 2);
  const x1 = Math.min(img.width, Math.ceil(Math.max(s0[0], s1[0], s2[0])) + 2);
  const y1 = Math.min(img.height, Math.ceil(Math.max(s0[1], s1[1], s2[1])) + 2);
  if (x1 > x0 && y1 > y0) ctx.drawImage(img, x0, y0, x1 - x0, y1 - y0, x0, y0, x1 - x0, y1 - y0);
  ctx.restore();
}

// Desenha img (no espaço do painel) deformada por disp(x, y) -> [dx, dy]
export function drawWarped(ctx, img, disp, nx = 20, ny = 12) {
  const W = img.width, H = img.height;
  const src = [], dst = [];
  for (let j = 0; j <= ny; j++) {
    for (let i = 0; i <= nx; i++) {
      const x = (i / nx) * W, y = (j / ny) * H;
      const [dx, dy] = disp(x, y);
      src.push([x, y]);
      // as bordas do painel ficam presas, para não abrir buraco na tela
      const edge = i === 0 || i === nx || j === 0 || j === ny;
      dst.push(edge ? [x, y] : [x + dx, y + dy]);
    }
  }
  const at = (i, j) => j * (nx + 1) + i;
  for (let j = 0; j < ny; j++) {
    for (let i = 0; i < nx; i++) {
      const p00 = at(i, j), p10 = at(i + 1, j), p01 = at(i, j + 1), p11 = at(i + 1, j + 1);
      tri(ctx, img, src[p00], src[p10], src[p11], dst[p00], dst[p10], dst[p11]);
      tri(ctx, img, src[p00], src[p11], src[p01], dst[p00], dst[p11], dst[p01]);
    }
  }
}

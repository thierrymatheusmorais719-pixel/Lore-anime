// Efeitos de desenho: tinta colorida, brilho, raios, linhas de velocidade,
// partículas, ondas de choque, granulação e vinheta.
import { rand, rrange, lerp, clamp } from './util.js';

export const W = 1920, H = 1080;

function canvas(w, h) {
  const c = document.createElement('canvas');
  c.width = Math.max(1, Math.round(w));
  c.height = Math.max(1, Math.round(h));
  return c;
}

// ---- Painéis ----------------------------------------------------------------
// Cada painel é tinta preta com alfa. Versões coloridas e "brilho" (desfoque por
// redução de escala, que funciona em qualquer navegador) ficam em cache.
const cache = new Map();

export function tint(img, color) {
  const key = img.src + '|t|' + color;
  if (cache.has(key)) return cache.get(key);
  const c = canvas(img.width, img.height), x = c.getContext('2d');
  x.drawImage(img, 0, 0);
  x.globalCompositeOperation = 'source-in';
  x.fillStyle = color;
  x.fillRect(0, 0, c.width, c.height);
  cache.set(key, c);
  return c;
}

export function glow(img, color, div = 10) {
  const key = img.src + '|g|' + color + '|' + div;
  if (cache.has(key)) return cache.get(key);
  const src = tint(img, color);
  let cur = src;
  for (let d = 2; d <= div; d *= 2) {        // reduções sucessivas = desfoque suave
    const c = canvas(src.width / d, src.height / d), x = c.getContext('2d');
    x.imageSmoothingQuality = 'high';
    x.drawImage(cur, 0, 0, c.width, c.height);
    cur = c;
  }
  cache.set(key, cur);
  return cur;
}

// Desenha a imagem (ou brilho reduzido) ocupando o tamanho do painel
export function drawFull(ctx, src, P, alpha = 1, op = 'source-over') {
  ctx.globalAlpha = alpha;
  ctx.globalCompositeOperation = op;
  ctx.drawImage(src, 0, 0, P.w, P.h);
  ctx.globalAlpha = 1;
  ctx.globalCompositeOperation = 'source-over';
}

// ---- Câmera -----------------------------------------------------------------
// cam = { u, v (ponto do painel no centro, 0..1), zoom (1 = cobre a tela), rot (graus),
//         sx, sy (tremor em px de tela) }
export function camMatrix(P, cam) {
  const base = Math.max(W / P.w, H / P.h);
  const s = base * cam.zoom;
  // limita o centro para nunca mostrar fora do painel (com zoom >= 1)
  const halfW = W / 2 / s, halfH = H / 2 / s;
  const cx = clamp(cam.u * P.w, halfW, P.w - halfW);
  const cy = clamp(cam.v * P.h, halfH, P.h - halfH);
  return { s, cx, cy, rot: ((cam.rot || 0) * Math.PI) / 180, sx: cam.sx || 0, sy: cam.sy || 0 };
}

export function applyCam(ctx, M) {
  ctx.translate(W / 2 + M.sx, H / 2 + M.sy);
  ctx.rotate(M.rot);
  ctx.scale(M.s, M.s);
  ctx.translate(-M.cx, -M.cy);
}

// Tremor de câmera com ruído (amp em px)
export function shake(t, amp, freq = 22, seed = 1) {
  if (amp <= 0) return { sx: 0, sy: 0 };
  const n = (s) => {
    const x = t * freq, i = Math.floor(x), f = x - i;
    return lerp(rand(i, s), rand(i + 1, s), f) * 2 - 1;
  };
  return { sx: n(seed) * amp, sy: n(seed + 7) * amp };
}

// ---- Fundo ------------------------------------------------------------------
export function linearBg(ctx, stops, x0 = 0, y0 = 0, x1 = 0, y1 = H) {
  const g = ctx.createLinearGradient(x0, y0, x1, y1);
  stops.forEach(([o, c]) => g.addColorStop(o, c));
  ctx.fillStyle = g;
  ctx.fillRect(-50, -50, W + 100, H + 100);
}

export function radialBg(ctx, x, y, r, stops) {
  const g = ctx.createRadialGradient(x, y, 0, x, y, r);
  stops.forEach(([o, c]) => g.addColorStop(o, c));
  ctx.fillStyle = g;
  ctx.fillRect(-50, -50, W + 100, H + 100);
}

export function glowDot(ctx, x, y, r, color, alpha = 1, op = 'lighter') {
  if (r <= 0 || alpha <= 0) return;
  const g = ctx.createRadialGradient(x, y, 0, x, y, r);
  g.addColorStop(0, color);
  g.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.globalCompositeOperation = op;
  ctx.globalAlpha = clamp(alpha);
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fill();
  ctx.globalAlpha = 1;
  ctx.globalCompositeOperation = 'source-over';
}

// Brilho em forma de estrela de 4 pontas (reflexo nos olhos)
export function glint(ctx, x, y, size, rot, alpha, color = '#fff') {
  if (alpha <= 0) return;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rot);
  ctx.globalCompositeOperation = 'lighter';
  ctx.globalAlpha = clamp(alpha);
  ctx.fillStyle = color;
  for (let k = 0; k < 2; k++) {
    const L = k ? size * 0.55 : size, w = size * 0.07;
    ctx.beginPath();
    ctx.moveTo(-L, 0); ctx.quadraticCurveTo(0, -w, L, 0); ctx.quadraticCurveTo(0, w, -L, 0);
    ctx.moveTo(0, -L); ctx.quadraticCurveTo(w, 0, 0, L); ctx.quadraticCurveTo(-w, 0, 0, -L);
    ctx.fill();
    ctx.rotate(Math.PI / 4);
  }
  ctx.restore();
  glowDot(ctx, x, y, size * 0.6, color, alpha * 0.8);
}

// ---- Linhas de velocidade / foco (estilo mangá) ----------------------------------
export function speedLines(ctx, cx, cy, { n = 90, inner = 300, color = '#000', alpha = 1, seed = 0, width = 14 } = {}) {
  if (alpha <= 0) return;
  ctx.save();
  ctx.globalAlpha = clamp(alpha);
  ctx.fillStyle = color;
  const R = 2400;
  for (let i = 0; i < n; i++) {
    const a = rand(i, seed) * Math.PI * 2;
    const r0 = inner * rrange(i, seed + 1, 0.85, 1.6);
    const w = width * rrange(i, seed + 2, 0.2, 1) / R;
    ctx.beginPath();
    ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0);
    ctx.lineTo(cx + Math.cos(a - w * 60) * R, cy + Math.sin(a - w * 60) * R);
    ctx.lineTo(cx + Math.cos(a + w * 60) * R, cy + Math.sin(a + w * 60) * R);
    ctx.closePath();
    ctx.fill();
  }
  ctx.restore();
}

// Linhas de vento (horizontais) em tela
export function windLines(ctx, t, { n = 40, color = '#fff', alpha = 0.5, speed = 2600, seed = 3, dir = -1 } = {}) {
  if (alpha <= 0) return;
  ctx.save();
  ctx.strokeStyle = color;
  ctx.lineCap = 'round';
  for (let i = 0; i < n; i++) {
    const y = rand(i, seed) * H;
    const len = rrange(i, seed + 1, 80, 420);
    const sp = speed * rrange(i, seed + 2, 0.6, 1.4);
    const span = W + len + 200;
    const x = ((rand(i, seed + 3) * span + t * sp) % span) - len - 100;
    const xx = dir < 0 ? W - x : x;
    ctx.globalAlpha = alpha * rrange(i, seed + 4, 0.2, 1);
    ctx.lineWidth = rrange(i, seed + 5, 1, 3.5);
    ctx.beginPath();
    ctx.moveTo(xx, y);
    ctx.lineTo(xx - dir * len, y + len * 0.04);
    ctx.stroke();
  }
  ctx.restore();
}

// ---- Partículas analíticas (posição = função do tempo) ---------------------------
// Brasas que sobem, cinzas ao vento, detritos que voam, energia que converge.
export function embers(ctx, t, { n = 120, seed = 10, rate = 1, color = '#ff3b3b', core = '#ffd6c0',
  vy = -260, vx = 40, life = 2.6, size = 6, area = [0, 0, W, H], alpha = 1, sway = 50 } = {}) {
  if (alpha <= 0) return;
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  for (let i = 0; i < n; i++) {
    const L = life * rrange(i, seed, 0.6, 1.3);
    const period = L;
    const phase = rand(i, seed + 1) * period;
    const age = (t * rate + phase) % period;
    const k = age / L;
    const x0 = area[0] + rand(i, seed + 2) * (area[2] - area[0]);
    const y0 = area[1] + rand(i, seed + 3) * (area[3] - area[1]);
    const x = x0 + vx * age * rrange(i, seed + 4, 0.5, 1.5) + Math.sin(age * 2 + i) * sway;
    const y = y0 + vy * age * rrange(i, seed + 5, 0.6, 1.4);
    const a = alpha * Math.sin(Math.PI * k);
    const r = size * rrange(i, seed + 6, 0.4, 1.3) * (1 - k * 0.5);
    ctx.globalAlpha = clamp(a * 0.55);
    ctx.fillStyle = color;
    ctx.beginPath(); ctx.arc(x, y, r * 2.6, 0, 7); ctx.fill();
    ctx.globalAlpha = clamp(a);
    ctx.fillStyle = core;
    ctx.beginPath(); ctx.arc(x, y, r * 0.8, 0, 7); ctx.fill();
  }
  ctx.restore();
}

// Partículas sugadas para um ponto (carregando energia)
export function converge(ctx, t, cx, cy, { n = 140, seed = 20, r0 = 900, life = 0.9, color = '#fff', alpha = 1, op = 'lighter' } = {}) {
  if (alpha <= 0) return;
  ctx.save();
  ctx.globalCompositeOperation = op;
  ctx.strokeStyle = color;
  ctx.lineCap = 'round';
  for (let i = 0; i < n; i++) {
    const L = life * rrange(i, seed, 0.6, 1.4);
    const age = (t + rand(i, seed + 1) * L) % L;
    const k = age / L;
    const a = rand(i, seed + 2) * Math.PI * 2;
    const d = r0 * rrange(i, seed + 3, 0.4, 1) * Math.pow(1 - k, 1.6);
    const d2 = d + 40 + 120 * (1 - k);
    ctx.globalAlpha = clamp(alpha * Math.sin(Math.PI * k));
    ctx.lineWidth = rrange(i, seed + 4, 1.5, 4);
    ctx.beginPath();
    ctx.moveTo(cx + Math.cos(a) * d, cy + Math.sin(a) * d);
    ctx.lineTo(cx + Math.cos(a) * d2, cy + Math.sin(a) * d2);
    ctx.stroke();
  }
  ctx.restore();
}

// Detritos voando para fora de um centro (explosão)
export function debris(ctx, age, cx, cy, { n = 80, seed = 30, speed = 1500, color = '#1a0406', alpha = 1, size = 18, gravity = 600 } = {}) {
  if (alpha <= 0 || age < 0) return;
  ctx.save();
  ctx.fillStyle = color;
  for (let i = 0; i < n; i++) {
    const a = -Math.PI * rrange(i, seed, 0.05, 0.95) + rrange(i, seed + 9, -0.4, 0.4);
    const sp = speed * rrange(i, seed + 1, 0.3, 1.2);
    const x = cx + Math.cos(a) * sp * age;
    const y = cy + Math.sin(a) * sp * age + gravity * age * age;
    const s = size * rrange(i, seed + 2, 0.3, 1.2);
    ctx.globalAlpha = clamp(alpha * (1 - age / 4));
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(age * rrange(i, seed + 3, -8, 8));
    ctx.beginPath();
    ctx.moveTo(-s, -s * 0.4); ctx.lineTo(s * 0.6, -s * 0.7); ctx.lineTo(s, s * 0.3); ctx.lineTo(-s * 0.3, s * 0.8);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }
  ctx.restore();
}

// ---- Raios ------------------------------------------------------------------
function boltPath(x0, y0, x1, y1, seed, rough, depth, out) {
  if (depth === 0) { out.push([x1, y1]); return; }
  const mx = (x0 + x1) / 2, my = (y0 + y1) / 2;
  const dx = x1 - x0, dy = y1 - y0, len = Math.hypot(dx, dy);
  const off = (rand(depth * 31 + out.length, seed) - 0.5) * len * rough;
  const nx = mx - (dy / len) * off, ny = my + (dx / len) * off;
  boltPath(x0, y0, nx, ny, seed, rough, depth - 1, out);
  boltPath(nx, ny, x1, y1, seed, rough, depth - 1, out);
}

export function bolt(ctx, x0, y0, x1, y1, { seed = 1, color = '#ff2a3a', core = '#fff', width = 6, alpha = 1, rough = 0.5, branches = 2 } = {}) {
  if (alpha <= 0) return;
  const pts = [[x0, y0]];
  boltPath(x0, y0, x1, y1, seed, rough, 6, pts);
  const stroke = (p, w, c, a) => {
    ctx.globalAlpha = clamp(a);
    ctx.strokeStyle = c;
    ctx.lineWidth = w;
    ctx.beginPath();
    ctx.moveTo(p[0][0], p[0][1]);
    for (let i = 1; i < p.length; i++) ctx.lineTo(p[i][0], p[i][1]);
    ctx.stroke();
  };
  ctx.save();
  ctx.lineJoin = 'round';
  ctx.lineCap = 'round';
  ctx.globalCompositeOperation = 'lighter';
  stroke(pts, width * 5, color, alpha * 0.25);
  stroke(pts, width * 2, color, alpha * 0.7);
  stroke(pts, width * 0.7, core, alpha);
  for (let b = 0; b < branches; b++) {
    const i = Math.floor(rrange(b, seed + 5, 0.2, 0.7) * pts.length);
    const [bx, by] = pts[i];
    const ang = Math.atan2(y1 - y0, x1 - x0) + rrange(b, seed + 6, -1.1, 1.1);
    const L = Math.hypot(x1 - x0, y1 - y0) * rrange(b, seed + 7, 0.15, 0.4);
    const bp = [[bx, by]];
    boltPath(bx, by, bx + Math.cos(ang) * L, by + Math.sin(ang) * L, seed + b * 13, rough, 4, bp);
    stroke(bp, width * 1.2, color, alpha * 0.6);
    stroke(bp, width * 0.4, core, alpha * 0.8);
  }
  ctx.restore();
}

// ---- Anéis / ondas de choque / círculo rúnico -----------------------------------
export function ring(ctx, x, y, rx, ry, { color = '#fff', width = 10, alpha = 1, op = 'lighter', rot = 0 } = {}) {
  if (alpha <= 0 || rx <= 0) return;
  ctx.save();
  ctx.globalCompositeOperation = op;
  ctx.globalAlpha = clamp(alpha);
  ctx.strokeStyle = color;
  ctx.lineWidth = width;
  ctx.beginPath();
  ctx.ellipse(x, y, rx, Math.max(0.1, ry), rot, 0, Math.PI * 2);
  ctx.stroke();
  ctx.restore();
}

export function runeCircle(ctx, x, y, r, ang, { color = '#ff2a3a', alpha = 1, seed = 4 } = {}) {
  if (alpha <= 0) return;
  ctx.save();
  ctx.translate(x, y);
  ctx.globalCompositeOperation = 'lighter';
  ctx.globalAlpha = clamp(alpha);
  ctx.strokeStyle = color;
  ctx.fillStyle = color;
  ctx.lineWidth = r * 0.012;
  ctx.beginPath(); ctx.arc(0, 0, r, 0, 7); ctx.stroke();
  ctx.beginPath(); ctx.arc(0, 0, r * 0.86, 0, 7); ctx.stroke();
  ctx.lineWidth = r * 0.006;
  ctx.beginPath(); ctx.arc(0, 0, r * 1.08, 0, 7); ctx.stroke();
  ctx.rotate(ang);
  // marcas rúnicas entre os anéis
  for (let i = 0; i < 36; i++) {
    ctx.save();
    ctx.rotate((i / 36) * Math.PI * 2);
    const h = r * rrange(i, seed, 0.03, 0.09);
    ctx.fillRect(r * 0.9, -r * 0.006, h, r * 0.012);
    if (rand(i, seed + 1) > 0.5) ctx.fillRect(r * 0.92, -h * 0.4, r * 0.01, h * 0.8);
    ctx.restore();
  }
  // estrela de 6 pontas
  ctx.rotate(-ang * 1.8);
  ctx.lineWidth = r * 0.008;
  for (let k = 0; k < 2; k++) {
    ctx.beginPath();
    for (let i = 0; i <= 3; i++) {
      const a = (i / 3) * Math.PI * 2 + k * Math.PI / 3 - Math.PI / 2;
      i ? ctx.lineTo(Math.cos(a) * r * 0.84, Math.sin(a) * r * 0.84) : ctx.moveTo(Math.cos(a) * r * 0.84, Math.sin(a) * r * 0.84);
    }
    ctx.stroke();
  }
  ctx.restore();
}

// ---- Acabamento de tela -------------------------------------------------------
let grainTex = null;
function grain() {
  if (grainTex) return grainTex;
  const c = canvas(256, 256), x = c.getContext('2d');
  const d = x.createImageData(256, 256);
  for (let i = 0; i < d.data.length; i += 4) {
    const v = Math.floor(rand(i, 99) * 255);
    d.data[i] = d.data[i + 1] = d.data[i + 2] = v;
    d.data[i + 3] = 255;
  }
  x.putImageData(d, 0, 0);
  grainTex = c;
  return c;
}

export function finish(ctx, t, { vignette = 0.55, grainAmt = 0.07, tintColor = null } = {}) {
  if (vignette > 0) {
    const g = ctx.createRadialGradient(W / 2, H / 2, H * 0.35, W / 2, H / 2, H * 1.05);
    g.addColorStop(0, 'rgba(0,0,0,0)');
    g.addColorStop(1, `rgba(0,0,0,${vignette})`);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
  }
  if (tintColor) {
    ctx.globalCompositeOperation = 'soft-light';
    ctx.fillStyle = tintColor;
    ctx.fillRect(0, 0, W, H);
    ctx.globalCompositeOperation = 'source-over';
  }
  if (grainAmt > 0) {
    const g = grain();
    const f = Math.floor(t * 24);              // granulação a 24 qps, como filme
    const ox = -rand(f, 5) * 256, oy = -rand(f, 6) * 256;
    ctx.globalAlpha = grainAmt;
    ctx.globalCompositeOperation = 'overlay';
    for (let y = oy; y < H; y += 256) for (let x = ox; x < W; x += 256) ctx.drawImage(g, x, y);
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
  }
}

export function flash(ctx, color, alpha, op = 'source-over') {
  if (alpha <= 0) return;
  ctx.globalCompositeOperation = op;
  ctx.globalAlpha = clamp(alpha);
  ctx.fillStyle = color;
  ctx.fillRect(0, 0, W, H);
  ctx.globalAlpha = 1;
  ctx.globalCompositeOperation = 'source-over';
}

// Roteiro visual de "Black Demon — Episódio 1: O Despertar Carmesim".
// render(ctx, t) desenha o quadro do instante t (segundos), sem estado:
// o mesmo t sempre gera a mesma imagem.
import { clamp, lerp, seg, ease, rand, rrange, pulse, noise1 } from './util.js';
import {
  W, H, tint, glow, drawFull, camMatrix, applyCam, shake, linearBg, radialBg,
  glowDot, glint, speedLines, windLines, embers, converge, debris, bolt, ring,
  runeCircle, finish, flash,
} from './fx.js';
import { prepEyes, drawEyes, blink, gaze } from './eyes.js';

export const DURATION = 54;

// Ordem dos planos. Os números são os do seu mangá; o 8 (ataque em detalhe)
// entra antes da explosão porque é o golpe que a causa.
export const SHOTS = [
  { id: 'abertura', a: 0, b: 4 },
  { id: 'p1', a: 4, b: 12, nome: '1. Transformação' },
  { id: 'p2', a: 12, b: 16, nome: '2. Ataque' },
  { id: 'p3', a: 16, b: 20, nome: '3. Olhos' },
  { id: 'p4', a: 20, b: 26, nome: '4. Explosão' },
  { id: 'p8', a: 26, b: 32, nome: '8. Ataque (detalhe)' },
  { id: 'p5', a: 32, b: 40, nome: '5. Fim do vilão' },
  { id: 'p6', a: 40, b: 46, nome: '6. Visão de satélite' },
  { id: 'p7', a: 46, b: 52, nome: '7. Quadro final' },
  { id: 'fim', a: 52, b: 54 },
];

// Pontos do desenho (0..1 dentro de cada painel), medidos na página original
const PTS = {
  p1: { eyes: [[0.352, 0.455], [0.622, 0.452]] },
  p2: { eyes: [[0.31, 0.44], [0.6, 0.45]], mouth: [0.47, 0.73] },
  p3: { eyes: [[0.29, 0.53], [0.69, 0.5]], mouth: [0.5, 0.84] },
  p4: { iris: [0.4932, 0.6609], irisR: 0.211, pupil: [0.5095, 0.6499] },
  p5: { ring: [0.5, 0.56], ringRx: 0.36, ringRy: 0.07, cloud: [0.48, 0.38] },
  p6: { blast: [0.5, 0.58], cloud: [0.5, 0.33], moon: [0.925, 0.1] },
  p7: { eyes: [[0.372, 0.44], [0.652, 0.44]] },
  p8: { orb: [0.765, 0.44], hand: [0.69, 0.44] },
};

export const HEARTBEATS = [0.6, 0.88, 2.6, 2.88];
export const BOOM = 32;
export const FIRE = 30.6;

let panels = {};
export async function load(base = 'assets/') {
  const ids = [1, 2, 3, 4, 5, 6, 7, 8];
  const imgs = await Promise.all(ids.map((n) => new Promise((ok, fail) => {
    const im = new Image();
    im.onload = () => ok(im);
    im.onerror = fail;
    im.src = `${base}painel-${n}.png`;
  })));
  ids.forEach((n, i) => { panels['p' + n] = { img: imgs[i], w: imgs[i].width, h: imgs[i].height }; });
  // pré-calcula as cores usadas, para não travar no primeiro quadro de cada plano
  const warm = [
    ['p1', '#d0102a'], ['p2', '#ff3646'], ['p2', '#00d8ff'], ['p3', '#ff2a3a'],
    ['p4', '#ffd6dc'], ['p4', '#ff1d3d'], ['p5', '#9a0a10'], ['p6', '#d7e4ff'],
    ['p6', '#5b7cff'], ['p7', '#c0102a'], ['p8', '#3a0008'],
  ];
  for (const [p, c] of warm) { tint(panels[p].img, c); glow(panels[p].img, c); }
}

// ---- auxiliares ---------------------------------------------------------------
function hex(c) { return [1, 3, 5].map((i) => parseInt(c.slice(i, i + 2), 16)); }
function mix(a, b, t) {
  const A = hex(a), B = hex(b);
  return `rgb(${A.map((v, i) => Math.round(lerp(v, B[i], clamp(t)))).join(',')})`;
}

// Coloca a câmera sobre o painel e desenha fn em coordenadas do painel
function inPanel(ctx, P, cam, fn) {
  const M = camMatrix(P, cam);
  ctx.save();
  applyCam(ctx, M);
  fn(M);
  ctx.restore();
  return M;
}

// Converte ponto do painel (0..1) para a tela
function toScreen(P, M, u, v) {
  const x = (u * P.w - M.cx) * M.s, y = (v * P.h - M.cy) * M.s;
  const c = Math.cos(M.rot), s = Math.sin(M.rot);
  return [W / 2 + M.sx + x * c - y * s, H / 2 + M.sy + x * s + y * c];
}

function text(ctx, str, x, y, { font, color = '#fff', alpha = 1, align = 'center', glowC = null, blur = 0, spacing = 0 }) {
  if (alpha <= 0) return;
  ctx.save();
  ctx.globalAlpha = clamp(alpha);
  ctx.font = font;
  ctx.textAlign = align;
  ctx.textBaseline = 'middle';
  if ('letterSpacing' in ctx) ctx.letterSpacing = spacing + 'px';
  if (glowC) { ctx.shadowColor = glowC; ctx.shadowBlur = blur; }
  ctx.fillStyle = color;
  ctx.fillText(str, x, y);
  ctx.restore();
}

// Logotipo: olhos de demônio + sorriso (como no quadro do player)
function demonEyes(ctx, x, y, s, alpha, color = '#ff1f35') {
  if (alpha <= 0) return;
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(s, s);
  ctx.globalAlpha = clamp(alpha);
  ctx.shadowColor = color;
  ctx.shadowBlur = 40;
  ctx.fillStyle = color;
  for (const d of [-1, 1]) {
    ctx.save();
    ctx.scale(d, 1);
    ctx.beginPath();
    ctx.moveTo(-14, -6);
    ctx.quadraticCurveTo(-60, -40, -150, -62);
    ctx.lineTo(-128, -52);
    ctx.quadraticCurveTo(-150, -24, -118, 6);
    ctx.quadraticCurveTo(-70, 10, -14, -6);
    ctx.fill();
    ctx.restore();
  }
  ctx.beginPath();
  ctx.moveTo(-70, 58);
  ctx.quadraticCurveTo(0, 96, 70, 58);
  ctx.quadraticCurveTo(0, 82, -70, 58);
  ctx.fill();
  ctx.restore();
}

// ---- planos ---------------------------------------------------------------------

function abertura(ctx, t) {
  ctx.fillStyle = '#000';
  ctx.fillRect(0, 0, W, H);
  const hb = pulse(t, HEARTBEATS, 5);
  radialBg(ctx, W / 2, H / 2, H * 0.9, [[0, `rgba(120,0,18,${0.15 + hb * 0.45})`], [1, 'rgba(0,0,0,0)']]);
  embers(ctx, t, { n: 50, alpha: 0.5 * seg(t, 0, 1.5), size: 4, vy: -120, seed: 3 });
  const a = seg(t, 0.5, 1.4) * (1 - seg(t, 3.3, 3.9));
  const jit = t < 1.4 ? (rand(Math.floor(t * 30), 7) - 0.5) * 30 * (1 - seg(t, 0.5, 1.4)) : 0;
  text(ctx, 'Black Demon', W / 2 + jit, H / 2 - 30, {
    font: '200px "Pirata One", "UnifrakturMaguntia", serif', color: '#e8102a', alpha: a, glowC: '#ff0022', blur: 40 + hb * 60,
  });
  if (t < 1.4 && a > 0) {   // fantasma ciano do "glitch"
    text(ctx, 'Black Demon', W / 2 - jit * 1.5, H / 2 - 30, {
      font: '200px "Pirata One", serif', color: '#00e0ff', alpha: a * 0.35,
    });
  }
  const b = seg(t, 1.8, 2.5) * (1 - seg(t, 3.3, 3.9));
  text(ctx, 'EPISÓDIO 1  —  O DESPERTAR CARMESIM', W / 2, H / 2 + 120, {
    font: '500 40px "Oswald", "Arial Narrow", sans-serif', color: '#f2d6d9', alpha: b, spacing: 10,
  });
  finish(ctx, t, { vignette: 0.6, grainAmt: 0.08 });
}

function p1(ctx, t, T) {
  const P = panels.p1;
  const awaken = ease.inOut(seg(t, 4.2, 6.5));
  const rush = seg(t, 7, 8);
  linearBg(ctx, [[0, mix('#ece8ef', '#f7d7d9', awaken)], [1, mix('#cfc8d8', '#c33349', awaken)]]);
  const cam = {
    u: lerp(0.5, 0.488, ease.inOut(seg(t, 0, 7))),
    v: lerp(0.58, 0.45, ease.inOut(seg(t, 0, 7))),
    zoom: 1.02 + 0.38 * ease.inOut(seg(t, 0, 7)) + 1.1 * ease.inExpo(rush) + 0.01 * Math.sin(T * 1.7),
    ...shake(T, 2 * awaken + 16 * rush, 24, 11),
  };
  inPanel(ctx, P, cam, () => {
    // aura carmesim: halo vermelho em volta do traço
    drawFull(ctx, glow(P.img, '#d0102a'), P, 0.95 * awaken);
    // olhos: olha para um lado, para o outro, pisca... e abre já vermelho
    const E = prepEyes('p1', P);
    drawFull(ctx, E.base, P);
    const lid = blink(t, [1.05, 4.3, 6.6]);
    const [lx, ly] = gaze(t, [[0, 0, 0], [1.5, -17, 0], [2.6, 15, -1], [3.5, 0, 0]]);
    const look = [lx + 1.5 * awaken * noise1(T * 18, 4), ly + 1.2 * awaken * noise1(T * 18, 8)];
    drawEyes(ctx, E, look, lid);
    const red = ease.out(seg(t, 4.42, 5.2)) * (1 - 0.85 * lid);
    for (const [u, v] of PTS.p1.eyes) {
      glowDot(ctx, u * P.w + look[0], v * P.h + look[1], 70, '#ff1030', red * 0.95, 'multiply');
      glowDot(ctx, u * P.w + look[0], v * P.h + look[1], 120, '#ff6070', red * 0.5, 'multiply');
    }
    const g = pulse(t, [5.3], 3.2) * (1 - lid);
    for (const [u, v] of PTS.p1.eyes) glint(ctx, u * P.w + 8 + look[0], v * P.h - 10, 70 + 50 * g, 0.3, g);
  });
  // brasas escuras subindo + vento
  embers(ctx, T, { n: 90, alpha: 0.15 + 0.85 * awaken, color: '#8a0016', core: '#ff3a50', size: 5, vy: -220, seed: 12 });
  windLines(ctx, T, { n: 26, color: '#5a0010', alpha: 0.12 + 0.25 * awaken, speed: 1800, dir: 1 });
  speedLines(ctx, W / 2, H / 2 - 40, { n: 110, inner: 420, color: '#140004', alpha: ease.in(rush) * 0.9, seed: Math.floor(T * 20) });
  finish(ctx, T, { vignette: 0.35 + 0.3 * awaken, grainAmt: 0.06 });
}

function p2(ctx, t, T) {
  const P = panels.p2;
  radialBg(ctx, W / 2, H * 0.45, H, [[0, '#3c0712'], [0.6, '#0d0205'], [1, '#000']]);
  const beat = pulse(T, [12, 12.5, 13, 13.5, 14, 14.5, 15, 15.5], 8);
  const cam = {
    u: 0.455, v: 0.5,
    zoom: 1.18 + 0.26 * ease.out(seg(t, 0, 4)) + 0.04 * beat,
    rot: lerp(-1.5, 1.2, ease.inOut(seg(t, 0, 4))),
    ...shake(T, 3 + 6 * beat, 20, 21),
  };
  const flare = ease.out(seg(t, 0.45, 0.9)) * (0.85 + 0.15 * noise1(T * 12, 3));
  inPanel(ctx, P, cam, () => {
    for (const [u, v] of PTS.p2.eyes) {
      glowDot(ctx, u * P.w, v * P.h, 260, '#ff0a2a', flare * 0.75);
      glowDot(ctx, u * P.w, v * P.h, 110, '#ffd0d4', flare * 0.9);
    }
    glowDot(ctx, PTS.p2.mouth[0] * P.w, PTS.p2.mouth[1] * P.h, 200, '#ff0a2a', flare * 0.35);
    drawFull(ctx, glow(P.img, '#ff3646'), P, 0.9 + 0.4 * beat, 'lighter');
    ctx.save();
    ctx.translate(5, 0);
    drawFull(ctx, tint(P.img, '#00d8ff'), P, 0.22, 'lighter');   // aberração cromática
    ctx.restore();
    drawFull(ctx, tint(P.img, '#ff3646'), P);
    const g = pulse(t, [0.75], 3);
    for (const [u, v] of PTS.p2.eyes) glint(ctx, u * P.w + 20, v * P.h - 8, 120 * (0.5 + g), 0.2, g);
  });
  speedLines(ctx, W / 2, H / 2, { n: 90, inner: 380, color: '#ff2a3a', alpha: 0.5 * (1 - seg(t, 0, 0.6)), seed: 4 });
  embers(ctx, T, { n: 70, size: 4, vy: -180, seed: 22, alpha: 0.8 });
  for (const [a, b, s] of [[2.4, 2.62, 1], [3.3, 3.48, 2]]) {
    if (t > a && t < b) {
      const f = Math.floor(T * 30);
      bolt(ctx, rrange(f, s, 0, W * 0.3), -20, rrange(f, s + 1, W * 0.3, W * 0.7), H + 20, { seed: f + s * 7, width: 5, alpha: 0.85 });
      flash(ctx, '#ff2040', 0.12, 'lighter');
    }
  }
  finish(ctx, T, { vignette: 0.6, grainAmt: 0.08 });
}

function p3(ctx, t, T) {
  const P = panels.p3;
  radialBg(ctx, W / 2, H / 2, H, [[0, '#2a040c'], [1, '#050002']]);
  const beats = []; for (let k = 16; k < 20; k += 0.5) beats.push(k);
  const beat = pulse(T, beats, 7);
  const end = seg(t, 3.5, 4);
  const cam = {
    u: 0.49,
    v: lerp(0.4, 0.72, ease.inOut(seg(t, 0.3, 3.6))),
    zoom: 1.15 + 0.3 * ease.inOut(seg(t, 0, 4)) + 0.05 * beat + 0.4 * ease.in(end),
    rot: lerp(1.5, -1.5, seg(t, 0, 4)),
    ...shake(T, 4 + 10 * beat + 18 * end, 26, 31),
  };
  inPanel(ctx, P, cam, () => {
    for (const [u, v] of PTS.p3.eyes) {
      glowDot(ctx, u * P.w, v * P.h, 230, '#ff0a2a', 0.7 + 0.3 * beat);
      glowDot(ctx, u * P.w, v * P.h, 90, '#ffe0e0', 0.8);
    }
    glowDot(ctx, PTS.p3.mouth[0] * P.w, PTS.p3.mouth[1] * P.h, 220, '#ff0a2a', 0.35 + 0.3 * beat);
    drawFull(ctx, glow(P.img, '#ff2a3a'), P, 0.5 + 0.9 * beat, 'lighter');
    drawFull(ctx, tint(P.img, '#ff2a3a'), P);
  });
  embers(ctx, T, { n: 110, size: 5, vy: -320, seed: 32, alpha: 0.9 });
  if (end > 0) {
    const f = Math.floor(T * 30);
    for (let k = 0; k < 3; k++) {
      bolt(ctx, rrange(f, k, 0, W), -20, rrange(f, k + 3, 0, W), H + 20, { seed: f * 3 + k, width: 6, alpha: end });
    }
    flash(ctx, '#ff1030', end * 0.35, 'lighter');
  }
  finish(ctx, T, { vignette: 0.65, grainAmt: 0.08 });
}

function p4(ctx, t, T) {
  const P = panels.p4;
  const { iris, irisR, pupil } = PTS.p4;
  radialBg(ctx, W / 2, H / 2, H * 1.1, [[0, '#5e0715'], [0.55, '#1a0108'], [1, '#000']]);
  const plunge = ease.inExpo(seg(t, 3.8, 6));
  const cam = {
    u: lerp(0.5, pupil[0], ease.inOut(seg(t, 0, 4))),
    v: lerp(0.6, pupil[1], ease.inOut(seg(t, 0, 4))),
    zoom: 1.04 + 0.22 * ease.inOut(seg(t, 0, 4)) + 5.5 * plunge,
    rot: lerp(-2, 2, seg(t, 0, 6)),
    ...shake(T, 2 + 10 * plunge, 18, 41),
  };
  const boom = ease.out(seg(t, 4.6, 5.8));        // reflexo da explosão na pupila
  const spin = 0.12 * t + 1.6 * ease.in(seg(t, 3, 6));
  const M = inPanel(ctx, P, cam, () => {
    const cx = iris[0] * P.w, cy = iris[1] * P.h, R = irisR * P.w;
    drawFull(ctx, glow(P.img, '#ff1d3d'), P, 0.75, 'lighter');
    drawFull(ctx, tint(P.img, '#ffd6dc'), P);
    // íris girando (recorte circular redesenhado com rotação)
    ctx.save();
    ctx.beginPath();
    ctx.arc(cx, cy, R * 0.93, 0, 7);
    ctx.clip();
    const ig = ctx.createRadialGradient(cx, cy, 0, cx, cy, R);
    ig.addColorStop(0, '#ff3a4c');
    ig.addColorStop(0.5, '#9a0820');
    ig.addColorStop(1, '#3a0010');
    ctx.fillStyle = ig;
    ctx.fillRect(cx - R, cy - R, 2 * R, 2 * R);
    ctx.translate(cx, cy);
    ctx.rotate(spin);
    ctx.translate(-cx, -cy);
    drawFull(ctx, tint(P.img, '#ffd6dc'), P);
    ctx.restore();
    runeCircle(ctx, cx, cy, R * 1.22, -spin * 1.4, { alpha: ease.out(seg(t, 0.8, 2)) * 0.9, color: '#ff2a44' });
    const px = pupil[0] * P.w, py = pupil[1] * P.h;
    glowDot(ctx, px, py, 40 + 30 * Math.sin(t * 6) ** 2, '#ffffff', 0.9);
    glowDot(ctx, px, py, R * 2.4 * boom, '#ffb060', boom);
    glowDot(ctx, px, py, R * 1.4 * boom, '#ffffff', boom);
  });
  const [sx, sy] = toScreen(P, M, pupil[0], pupil[1]);
  speedLines(ctx, sx, sy, { n: 70, inner: 300, width: 9, color: '#ff8a9a', alpha: 0.4 * seg(t, 3.5, 5), seed: Math.floor(T * 24) });
  embers(ctx, T, { n: 60, size: 4, seed: 42, alpha: 0.7, vy: -150 });
  flash(ctx, '#fff', ease.in(seg(t, 5.5, 6)));
  finish(ctx, T, { vignette: 0.6, grainAmt: 0.07 });
}

function p8(ctx, t, T) {
  const P = panels.p8;
  const fire = FIRE - 26;
  const charge = ease.in(seg(t, 0, fire));
  const after = seg(t, fire, 6);
  linearBg(ctx, [[0, '#d82540'], [0.55, '#9c1028'], [1, '#3c0612']]);
  const cam = {
    u: lerp(0.47, 0.6, ease.inOut(seg(t, 0, fire))),
    v: 0.47,
    zoom: 1.08 + 0.22 * ease.inOut(seg(t, 0, fire)),
    rot: lerp(0, -2, charge),
    ...shake(T, 2 + 12 * charge + 40 * Math.exp(-(t - fire) * 3) * (t > fire), 24, 51),
  };
  const [ou, ov] = PTS.p8.orb;
  const M = inPanel(ctx, P, cam, () => {
    const ox = ou * P.w, oy = ov * P.h;
    glowDot(ctx, ox, oy, P.w * (0.25 + 0.35 * charge), '#ffcf8a', 0.55 + 0.4 * charge, 'screen');
    drawFull(ctx, glow(P.img, '#3a0008'), P, 0.5, 'multiply');
    drawFull(ctx, P.img, P);
    runeCircle(ctx, ox, oy, P.w * 0.21, t * 0.8, { color: '#fff1d0', alpha: ease.out(seg(t, 0.4, 1.4)) * 0.85 });
    const fl = 0.85 + 0.15 * noise1(T * 25, 5);
    glowDot(ctx, ox, oy, P.w * (0.05 + 0.13 * charge) * fl, '#ffffff', 1);
    glowDot(ctx, ox, oy, P.w * (0.03 + 0.06 * charge), '#ffffff', 1);
    for (let k = 0; k < 4; k++) {          // anéis de pressão saindo do orbe
      const ph = ((t * 1.6 + k / 4) % 1);
      ring(ctx, ox, oy, P.w * (0.04 + 0.3 * ph), P.w * (0.04 + 0.3 * ph), { width: 6, alpha: (1 - ph) * 0.6 * seg(t, 0.3, 1), color: '#fff3d6' });
    }
  });
  const [sx, sy] = toScreen(P, M, ou, ov);
  converge(ctx, T, sx, sy, { n: 160, r0: 1100, alpha: seg(t, 0.2, 1) * (1 - after) });
  const f = Math.floor(T * 14);
  const nb = Math.floor(1 + 5 * charge);
  for (let k = 0; k < nb; k++) {
    const a = rand(f * 7 + k, 61) * Math.PI * 2, L = rrange(f + k, 62, 260, 700) * (0.6 + charge);
    bolt(ctx, sx, sy, sx + Math.cos(a) * L, sy + Math.sin(a) * L, { seed: f * 13 + k, width: 4, color: '#ffb0b8', alpha: 0.9 * (1 - after) });
  }
  speedLines(ctx, sx, sy, { n: 70, inner: 320, color: '#2a0006', alpha: 0.35 * charge * (1 - after), seed: Math.floor(T * 20) });
  // disparo: estouro branco, depois o "silêncio" superexposto antes do impacto
  if (t > fire) {
    flash(ctx, '#ffffff', 0.55 + 0.45 * Math.exp(-(t - fire) * 6));
    const k = ease.outExpo(seg(t, fire, fire + 0.5));
    const hb = 8 + 260 * k;
    const bg = ctx.createLinearGradient(0, sy - hb * 1.6, 0, sy + hb * 1.6);
    bg.addColorStop(0, 'rgba(255,255,255,0)');
    bg.addColorStop(0.3, '#fff');
    bg.addColorStop(0.7, '#fff');
    bg.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = bg;
    ctx.fillRect(0, sy - hb * 1.6, W, hb * 3.2);
    inPanel(ctx, P, cam, () => drawFull(ctx, tint(P.img, '#c0102a'), P, 0.22 * (1 - seg(t, 5.2, 6))));
  }
  finish(ctx, T, { vignette: 0.5 * (1 - after), grainAmt: 0.07 });
}

function p5(ctx, t, T) {
  const P = panels.p5;
  const cam = {
    u: 0.5,
    v: lerp(0.62, 0.45, ease.out(seg(t, 0, 6))),
    zoom: lerp(1.5, 1.06, ease.out(seg(t, 0, 6.5))),
    ...shake(T, 34 * Math.exp(-t * 1.1) + 4 + 14 * pulse(t, [1.6], 3), 26, 61),
  };
  // quadros de impacto: alterna negativo/positivo nos primeiros instantes
  if (t < 0.32) {
    const neg = Math.floor(t / 0.08) % 2 === 0;
    ctx.fillStyle = neg ? '#000' : '#fff';
    ctx.fillRect(0, 0, W, H);
    inPanel(ctx, P, cam, () => drawFull(ctx, neg ? tint(P.img, '#ffffff') : P.img, P));
    if (neg) flash(ctx, '#ff1030', 0.5, 'multiply');
    return;
  }
  const M = camMatrix(P, cam);
  const [cx, cy] = toScreen(P, M, PTS.p5.cloud[0], PTS.p5.cloud[1]);
  const fl = 1 + 0.08 * noise1(T * 9, 7);
  radialBg(ctx, cx, cy, H * 1.15 * fl, [[0, '#fffbe8'], [0.2, '#ffd06a'], [0.45, '#f05a2a'], [0.75, '#a3112a'], [1, '#2a040c']]);
  inPanel(ctx, P, cam, () => {
    drawFull(ctx, glow(P.img, '#9a0a10'), P, 0.55, 'multiply');
    drawFull(ctx, P.img, P);
    const [ru, rv] = PTS.p5.ring;
    for (const [d, a] of [[0, 1], [1.5, 0.7]]) {
      const k = ease.outExpo(seg(t, 0.3 + d, 3 + d));
      ring(ctx, ru * P.w, rv * P.h, P.w * (0.12 + 1.2 * k), P.h * (0.04 + 0.3 * k), { width: 26 * (1 - k) + 4, alpha: a * (1 - k), color: '#fff6dc' });
    }
  });
  debris(ctx, t - 0.3, cx, cy + 120, { n: 70, speed: 1700, size: 20, color: '#1c0306', seed: 33 });
  embers(ctx, T, { n: 120, color: '#ff7a2a', core: '#fff1c0', vy: -380, vx: 120, size: 6, seed: 52, alpha: 0.9 });
  speedLines(ctx, cx, cy, { n: 100, inner: 420, color: '#1a0204', alpha: 0.6 * (1 - seg(t, 0.3, 1.8)), seed: Math.floor(T * 20) });
  flash(ctx, '#ffffff', 0.85 * Math.exp(-(t - 0.32) * 4));
  flash(ctx, '#000', ease.in(seg(t, 7.5, 8)));
  finish(ctx, T, { vignette: 0.55, grainAmt: 0.07 });
}

function p6(ctx, t, T) {
  const P = panels.p6;
  linearBg(ctx, [[0, '#010208'], [0.6, '#060a22'], [1, '#0d1438']]);
  const cam = {
    u: 0.5,
    v: lerp(0.52, 0.46, ease.out(seg(t, 0, 6))),
    zoom: lerp(1.45, 1.04, ease.out(seg(t, 0, 6))),
    rot: lerp(2, 0, ease.out(seg(t, 0, 6))),
  };
  // estrelas cintilando
  ctx.fillStyle = '#fff';
  for (let i = 0; i < 160; i++) {
    ctx.globalAlpha = 0.25 + 0.6 * (0.5 + 0.5 * Math.sin(T * rrange(i, 71, 1, 4) + i));
    const s = rrange(i, 72, 1, 3);
    ctx.fillRect(rand(i, 73) * W, rand(i, 74) * H * 0.7, s, s);
  }
  ctx.globalAlpha = 1;
  inPanel(ctx, P, cam, () => {
    const [bu, bv] = PTS.p6.blast, [cu, cv] = PTS.p6.cloud, [mu, mv] = PTS.p6.moon;
    glowDot(ctx, bu * P.w, bv * P.h, P.w * 0.32, '#ff3a1a', 0.75 + 0.1 * Math.sin(T * 5));
    glowDot(ctx, cu * P.w, cv * P.h, P.w * 0.16, '#ff9a4a', 0.55);
    glowDot(ctx, mu * P.w, mv * P.h, P.w * 0.08, '#c8d6ff', 0.35);
    drawFull(ctx, glow(P.img, '#5b7cff'), P, 0.45, 'lighter');
    drawFull(ctx, tint(P.img, '#d7e4ff'), P);
    for (const d of [0, 1.8, 3.6]) {
      const k = ease.out(seg(t, d, d + 2.6));
      ring(ctx, bu * P.w, bv * P.h, P.w * (0.06 + 0.42 * k), P.h * (0.03 + 0.2 * k), { width: 10, alpha: (1 - k) * 0.9 * (k > 0), color: '#ff4058' });
    }
    glowDot(ctx, bu * P.w, bv * P.h, P.w * 0.07, '#fff0d0', 0.9);
  });
  flash(ctx, '#000', 1 - seg(t, 0, 0.5));
  flash(ctx, '#000', ease.in(seg(t, 5.6, 6)));
  finish(ctx, T, { vignette: 0.6, grainAmt: 0.06 });
}

function p7(ctx, t, T) {
  const P = panels.p7;
  linearBg(ctx, [[0, '#f3dcdc'], [0.55, '#e7b3b8'], [1, '#a81f36']]);
  const cam = {
    u: lerp(0.5, 0.512, ease.inOut(seg(t, 0, 6))),
    v: lerp(0.52, 0.44, ease.inOut(seg(t, 0, 6))),
    zoom: 1.04 + 0.26 * ease.inOut(seg(t, 0, 6)) + 0.008 * Math.sin(T * 1.3),
  };
  inPanel(ctx, P, cam, () => {
    drawFull(ctx, glow(P.img, '#c0102a'), P, 0.5, 'multiply');
    // olhos: começa olhando de lado, vira para a câmera, pisca, desvia o olhar
    const E = prepEyes('p7', P);
    drawFull(ctx, E.base, P);
    const lid = blink(t, [3.3]);
    const look = gaze(t, [[0, 15, 0], [1.05, 0, 0], [4.5, -9, 0]], 0.16);
    drawEyes(ctx, E, look, lid);
    for (const [u, v] of PTS.p7.eyes) {
      glowDot(ctx, u * P.w + look[0], v * P.h + look[1], 60, '#ff1030', 0.9 * (1 - 0.85 * lid), 'multiply');
      glowDot(ctx, u * P.w + look[0], v * P.h + look[1], 110, '#ff6070', 0.4 * (1 - 0.85 * lid), 'multiply');
    }
    const g = pulse(t, [1.8], 2.5) * (1 - lid);
    for (const [u, v] of PTS.p7.eyes) glint(ctx, u * P.w + 6 + look[0], v * P.h - 8, 70 * (0.4 + g), 0.4, g);
  });
  embers(ctx, T, { n: 70, color: '#6a0012', core: '#ff3a50', vy: -60, vx: -160, size: 5, seed: 82, alpha: 0.8 });
  windLines(ctx, T, { n: 22, color: '#ffffff', alpha: 0.35, speed: 1400, dir: -1, seed: 9 });
  // cartão com o nome (como a legenda do painel 8)
  const k = ease.outBack(seg(t, 2.3, 2.9)), out = ease.in(seg(t, 5.1, 5.5));
  if (k > 0 && out < 1) {
    const x = lerp(-700, 90, k) - 900 * out, y = H - 300;
    ctx.save();
    ctx.fillStyle = '#c4102c';
    ctx.beginPath();
    ctx.moveTo(x - 40, y + 30); ctx.lineTo(x + 760, y - 10); ctx.lineTo(x + 740, y + 200); ctx.lineTo(x - 60, y + 210);
    ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.strokeStyle = '#000';
    ctx.lineWidth = 8;
    ctx.fillRect(x, y, 640, 190);
    ctx.strokeRect(x, y, 640, 190);
    ctx.restore();
    text(ctx, 'AKARI KURENAI', x + 320, y + 72, { font: '700 92px "Oswald", "Arial Narrow", sans-serif', color: '#000' });
    text(ctx, 'O DESPERTAR CARMESIM', x + 320, y + 148, { font: '500 38px "Oswald", "Arial Narrow", sans-serif', color: '#c4102c', spacing: 4 });
  }
  flash(ctx, '#000', ease.inOut(seg(t, 5.3, 6)));
  finish(ctx, T, { vignette: 0.45, grainAmt: 0.06 });
}

function fim(ctx, t, T) {
  ctx.fillStyle = '#000';
  ctx.fillRect(0, 0, W, H);
  const a = seg(t, 0.15, 0.6) * (1 - seg(t, 1.55, 2));
  radialBg(ctx, W / 2, H * 0.42, H * 0.7, [[0, `rgba(110,0,20,${0.5 * a})`], [1, 'rgba(0,0,0,0)']]);
  demonEyes(ctx, W / 2, H * 0.3, 1.1, a);
  text(ctx, 'Black Demon', W / 2, H * 0.6, { font: '150px "Pirata One", serif', color: '#f2f2f2', alpha: a, glowC: '#ff0022', blur: 30 });
  text(ctx, 'EPISÓDIO 1  ·  O DESPERTAR CARMESIM', W / 2, H * 0.73, { font: '500 34px "Oswald", sans-serif', color: '#e5838f', alpha: a, spacing: 8 });
  finish(ctx, T, { vignette: 0.5, grainAmt: 0.08 });
}

const DRAW = { abertura, p1, p2, p3, p4, p8, p5, p6, p7, fim };

// Clarões nos cortes (instante, cor, força, decaimento)
const CUT_FLASH = [[12, '#ffffff', 0.9, 7], [16, '#ff2040', 0.7, 6], [20, '#ffffff', 0.8, 6], [26, '#ffffff', 1, 4]];

export function shotAt(t) {
  return SHOTS.find((s) => t >= s.a && t < s.b) || SHOTS[SHOTS.length - 1];
}

export function render(ctx, t) {
  t = clamp(t, 0, DURATION - 1e-4);
  const s = shotAt(t);
  ctx.save();
  DRAW[s.id](ctx, t - s.a, t);
  for (const [c, col, a, d] of CUT_FLASH) {
    if (t >= c && t < c + 1) flash(ctx, col, a * Math.exp(-(t - c) * d), col === '#ffffff' ? 'source-over' : 'lighter');
  }
  // quadro de impacto (negativo) no golpe final da transformação
  if (t > 11.84 && t < 11.94) {
    flash(ctx, '#ffffff', 1, 'difference');
    flash(ctx, '#e0102a', 1, 'color');
  }
  ctx.restore();
}

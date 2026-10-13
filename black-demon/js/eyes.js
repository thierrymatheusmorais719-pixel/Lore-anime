// Olhos animados: a parte de dentro de cada olho vira uma camada separada que
// desliza (olhar para os lados) e recebe uma pálpebra que fecha (piscar).
import { clamp, lerp, ease, seg } from './util.js';

// Contorno da abertura de cada olho, traçado à mão sobre o desenho.
// Coordenadas em px do painel ampliado, relativas a um recorte 360x220
// centrado em (u, v) — o mesmo recorte usado para traçar.
const OUTLINES = {
  p1: [
    { c: [0.352, 0.455], poly: [[92, 64], [150, 70], [200, 82], [233, 95], [248, 105], [246, 128], [230, 145], [217, 153], [187, 161], [150, 157], [122, 143], [110, 120], [97, 88]] },
    { c: [0.622, 0.452], poly: [[103, 112], [143, 93], [187, 83], [233, 76], [248, 75], [247, 107], [233, 120], [213, 138], [187, 152], [157, 157], [130, 153], [112, 142], [102, 130]] },
  ],
  p7: [
    { c: [0.372, 0.44], poly: [[80, 70], [127, 69], [167, 73], [200, 85], [230, 98], [243, 110], [233, 122], [207, 135], [167, 140], [133, 135], [110, 127], [93, 103]] },
    { c: [0.652, 0.44], poly: [[97, 92], [133, 63], [167, 53], [210, 48], [217, 60], [213, 83], [207, 105], [183, 117], [150, 119], [117, 113], [100, 103]] },
  ],
};

const prepared = new Map();
const LID = 16;          // espessura (px) da faixa da pálpebra que se move

function canvas(w, h) {
  const c = document.createElement('canvas');
  c.width = Math.ceil(w); c.height = Math.ceil(h);
  return c;
}
function pathOf(ctx, poly, ox = 0, oy = 0) {
  ctx.beginPath();
  poly.forEach(([x, y], i) => (i ? ctx.lineTo(x - ox, y - oy) : ctx.moveTo(x - ox, y - oy)));
  ctx.closePath();
}

// Limite de cima e de baixo da abertura em cada coluna (para a pálpebra)
function columns(poly, x0, x1, n = 72) {
  const cols = [];
  for (let i = 0; i <= n; i++) {
    const x = lerp(x0 + 1, x1 - 1, i / n);
    const ys = [];
    for (let k = 0; k < poly.length; k++) {
      const [ax, ay] = poly[k], [bx, by] = poly[(k + 1) % poly.length];
      if ((ax <= x && bx > x) || (bx <= x && ax > x)) ys.push(ay + ((x - ax) / (bx - ax)) * (by - ay));
    }
    if (ys.length >= 2) cols.push([x, Math.min(...ys), Math.max(...ys)]);
  }
  return cols;
}

// Prepara: painel com os olhos apagados + recorte de cada olho
export function prepEyes(id, P) {
  if (prepared.has(id)) return prepared.get(id);
  const eyes = OUTLINES[id].map(({ c, poly }) => {
    const ox = Math.floor(c[0] * P.w) - 180, oy = Math.floor(c[1] * P.h) - 110;
    const pts = poly.map(([x, y]) => [x + ox, y + oy]);
    const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]);
    const box = { x: Math.min(...xs) - 4, y: Math.min(...ys) - 4 };
    box.w = Math.max(...xs) + 4 - box.x;
    box.h = Math.max(...ys) + 4 - box.y;
    const sprite = canvas(box.w, box.h), s = sprite.getContext('2d');
    pathOf(s, pts, box.x, box.y);
    s.clip();
    s.drawImage(P.img, -box.x, -box.y);
    const cols = columns(pts, Math.min(...xs), Math.max(...xs));
    // faixa da pálpebra de cima: o traço grosso logo acima da abertura, que desce ao piscar
    const band = [...cols.map(([x, top]) => [x, top - LID]), ...cols.slice().reverse().map(([x, top]) => [x, top + 2])];
    const lid = canvas(box.w, box.h + LID), l = lid.getContext('2d');
    pathOf(l, band, box.x, box.y - LID);
    l.clip();
    l.drawImage(P.img, -box.x, -(box.y - LID));
    return { pts, box, sprite, work: canvas(box.w, box.h), cols, band, lid };
  });
  const base = canvas(P.w, P.h), b = base.getContext('2d');
  b.drawImage(P.img, 0, 0);
  b.globalCompositeOperation = 'destination-out';
  for (const e of eyes) { pathOf(b, e.pts); b.fill(); pathOf(b, e.band); b.fill(); }
  const r = { base, eyes };
  prepared.set(id, r);
  return r;
}

// Desenha os olhos. look = deslocamento da íris em px (x, y); lid = 0 aberto … 1 fechado
export function drawEyes(ctx, E, look, lid) {
  for (const e of E.eyes) {
    const { box, work } = e;
    const w = work.getContext('2d');
    w.setTransform(1, 0, 0, 1, 0, 0);
    w.globalCompositeOperation = 'source-over';
    w.clearRect(0, 0, work.width, work.height);
    w.drawImage(e.sprite, look[0], look[1]);
    if (lid > 0.001) {
      // a pálpebra desce: apaga tudo acima da linha dela (o fundo do quadro vira a "pele")
      // e põe uma sombra leve nessa pele
      w.beginPath();
      w.moveTo(0, -2);
      for (const [x, top, bot] of e.cols) w.lineTo(x - box.x, lerp(top, bot, lid) - box.y);
      w.lineTo(work.width, -2);
      w.closePath();
      w.globalCompositeOperation = 'destination-out';
      w.fillStyle = '#000';
      w.fill();
      w.globalCompositeOperation = 'source-over';
      const sh = w.createLinearGradient(0, 0, 0, work.height);
      sh.addColorStop(0, 'rgba(110, 30, 45, 0)');
      sh.addColorStop(1, `rgba(110, 30, 45, ${0.24 * clamp(lid * 2)})`);
      w.fillStyle = sh;
      w.fill();
    }
    w.globalCompositeOperation = 'destination-in';
    w.fillStyle = '#000';
    pathOf(w, e.pts, box.x, box.y);
    w.fill();
    ctx.drawImage(work, box.x, box.y);
    // pálpebra: desenhada em fatias verticais, cada uma descendo até a linha de baixo
    const n = e.cols.length, step = n > 1 ? e.cols[1][0] - e.cols[0][0] : 4;
    for (let i = 0; i < n; i++) {
      const [x, top, bot] = e.cols[i];
      const x0 = i === 0 ? box.x : x - step / 2;
      const x1 = i === n - 1 ? box.x + box.w : x + step / 2 + 0.6;
      const dy = (bot - top) * lid;
      ctx.drawImage(e.lid, x0 - box.x, 0, x1 - x0, e.lid.height, x0, box.y - LID + dy, x1 - x0, e.lid.height);
    }
  }
}

// Piscada: fecha rápido, segura um instante, abre um pouco mais devagar
export function blink(t, times) {
  let v = 0;
  for (const b of times) {
    const d = t - b;
    if (d < 0 || d > 0.3) continue;
    v = Math.max(v, d < 0.07 ? ease.in(d / 0.07) : d < 0.11 ? 1 : 1 - ease.out((d - 0.11) / 0.19));
  }
  return v;
}

// Olhar: lista de [instante, x, y]; move entre posições com uma "sacada" rápida (0,14 s)
export function gaze(t, keys, dur = 0.14) {
  let [px, py] = [keys[0][1], keys[0][2]];
  for (let i = 1; i < keys.length; i++) {
    const [k, x, y] = keys[i];
    if (t < k) break;
    const f = ease.out(seg(t, k, k + dur));
    px = lerp(px, x, f);
    py = lerp(py, y, f);
  }
  return [px, py];
}

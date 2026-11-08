// A LOUSA — desenha o quadro t. Tudo é função pura de t (sem estado), então qualquer worker
// pode desenhar qualquer quadro e tudo sempre bate com os sons gerados em song.js.
(function () {
  const U = globalThis.U, G = globalThis.G, Ch = globalThis.Ch, S = globalThis.SCORE, Studio = globalThis.Studio;
  const { clamp, lerp, ease } = U;
  const W = G.W, H = G.H;
  const PI = Math.PI, TAU = PI * 2;

  const C = { ink: '#F2EEE3', y: '#FFE27A', p: '#FF9AA2', b: '#9ED8FF', g: '#B8F2A0', o: '#FFB870', v: '#D7B8FF', dim: 'rgba(242,238,227,0.38)' };
  const FAM = '"Patrick Hand", "DejaVu Sans", sans-serif';
  const TFAM = '"Caveat", "DejaVu Sans", sans-serif';
  const BOX = { x: 1235, y: 225, w: 600, h: 700 };
  const CX = BOX.x + BOX.w / 2, CY = BOX.y + BOX.h / 2;

  const TEACHER = { skin: '#C98A62', hair: '#2B1D14', hairStyle: 'curly', glasses: 'round', outfit: 'shirt', shirt: '#4F7CAC', collar: '#DDE7F2', bottoms: 'pants', shorts: '#3A3A48', build: 'regular' };
  globalThis.CAST = { professora: TEACHER };

  // ---------------- pequenos utilitários ----------------
  const txt = (ctx, s, x, y, o = {}) => G.text(ctx, s, x, y, Object.assign({ size: 40, fam: FAM, weight: 400, color: C.ink, boil: 0.35 }, o));
  const ttl = (ctx, s, x, y, o = {}) => G.text(ctx, s, x, y, Object.assign({ size: 64, fam: TFAM, weight: 700, color: C.y, boil: 0.5 }, o));
  const meas = (ctx, s, size, fam = FAM, weight = 400) => G.measure(ctx, s, size, fam, weight);
  const regPts = (n, cx, cy, r, rot = -PI / 2) => Array.from({ length: n }, (_, i) => [cx + r * Math.cos(rot + (i * TAU) / n), cy + r * Math.sin(rot + (i * TAU) / n)]);
  const sub = (a, b) => [a[0] - b[0], a[1] - b[1]];
  const ang = (v) => Math.atan2(v[1], v[0]);
  const mid = (a, b, k = 0.5) => [lerp(a[0], b[0], k), lerp(a[1], b[1], k)];
  function partial(pts, p) { // a fração p de uma linha poligonal
    if (p >= 1) return pts; if (p <= 0) return [pts[0], pts[0]];
    let L = 0; const seg = [];
    for (let i = 1; i < pts.length; i++) { const d = Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]); seg.push(d); L += d; }
    let want = L * p; const out = [pts[0]];
    for (let i = 1; i < pts.length; i++) {
      if (want >= seg[i - 1]) { out.push(pts[i]); want -= seg[i - 1]; } else { const k = want / seg[i - 1]; out.push(mid(pts[i - 1], pts[i], k)); break; }
    }
    return out;
  }
  const ln = (ctx, pts, color = C.ink, lw = 4, p = 1, seed = 3) => { if (p > 0) G.line(ctx, partial(pts, p), { color, lw, seed, step: 14 }); };
  const closed = (pts) => [...pts, pts[0]];
  function arc(ctx, cx, cy, r, a0, a1, color, lw = 4, p = 1) {
    const n = Math.max(6, Math.ceil(Math.abs(a1 - a0) * 12)); const pts = [];
    for (let i = 0; i <= n; i++) { const a = lerp(a0, a1, i / n); pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]); }
    ln(ctx, pts, color, lw, p, 7);
  }
  // ângulo interno no vértice v, entre as direções para a e b (o menor dos dois)
  function angleArc(ctx, v, a, b, r, color, p = 1, label, lsize = 34) {
    let a0 = ang(sub(a, v)), a1 = ang(sub(b, v));
    let d = a1 - a0; while (d > PI) d -= TAU; while (d < -PI) d += TAU;
    arc(ctx, v[0], v[1], r, a0, a0 + d, color, 4, p);
    if (label && p > 0.5) { const am = a0 + d / 2; txt(ctx, label, v[0] + Math.cos(am) * (r + 30), v[1] + Math.sin(am) * (r + 30) + 12, { size: lsize, color, align: 'center', alpha: clamp((p - 0.5) * 2) }); }
  }
  function check(ctx, x, y, s = 1, a = 1) { if (a > 0) ln(ctx, [[x - 18 * s, y], [x - 4 * s, y + 16 * s], [x + 22 * s, y - 20 * s]], C.g, 7, a); }
  function cross(ctx, x, y, s = 1, a = 1) { if (a > 0) { ln(ctx, [[x - 18 * s, y - 18 * s], [x + 18 * s, y + 18 * s]], C.p, 7, clamp(a * 2)); ln(ctx, [[x + 18 * s, y - 18 * s], [x - 18 * s, y + 18 * s]], C.p, 7, clamp(a * 2 - 1)); } }
  const fillPoly = (ctx, pts, color, alpha = 1, seed = 5) => G.poly(ctx, pts, { fill: color, stroke: null, alpha, seed, lw: 0 });
  const strokePoly = (ctx, pts, color = C.ink, lw = 4, seed = 2, fill) => G.poly(ctx, pts, { stroke: color, lw, seed, fill });
  function dashed(ctx, a, b, color = C.dim, lw = 3) {
    const n = Math.max(2, Math.round(Math.hypot(b[0] - a[0], b[1] - a[1]) / 22));
    for (let i = 0; i < n; i += 2) ln(ctx, [mid(a, b, i / n), mid(a, b, Math.min(1, (i + 1) / n))], color, lw, 1, i);
  }
  const dot = (ctx, x, y, r, color) => G.ellipse(ctx, x, y, r, r, { fill: color, stroke: color, lw: 2, seed: Math.round(x + y) });
  function rightMark(ctx, v, d1, d2, s = 22, color = C.ink) { // marca de ângulo reto
    const n1 = Math.hypot(...d1), n2 = Math.hypot(...d2);
    const a = [v[0] + (d1[0] / n1) * s, v[1] + (d1[1] / n1) * s], b = [v[0] + (d2[0] / n2) * s, v[1] + (d2[1] / n2) * s];
    ln(ctx, [a, [a[0] + b[0] - v[0], a[1] + b[1] - v[1]], b], color, 3);
  }
  function arrow(ctx, a, b, color = C.ink, lw = 4, p = 1) {
    if (p <= 0) return; const e = mid(a, b, p); ln(ctx, [a, e], color, lw);
    const an = ang(sub(e, a)); ln(ctx, [[e[0] - 18 * Math.cos(an - 0.45), e[1] - 18 * Math.sin(an - 0.45)], e, [e[0] - 18 * Math.cos(an + 0.45), e[1] - 18 * Math.sin(an + 0.45)]], color, lw);
  }
  // sólidos em perspectiva cavaleira
  const DEP = [0.5, -0.36];
  function box3(ctx, x, y, c, h, d, k, o = {}) { // (x,y) = canto frontal inferior esquerdo
    const v = [d * k * DEP[0], d * k * DEP[1]];
    const F = [[x, y], [x + c * k, y], [x + c * k, y - h * k], [x, y - h * k]];
    const T = [F[3], F[2], [F[2][0] + v[0], F[2][1] + v[1]], [F[3][0] + v[0], F[3][1] + v[1]]];
    const R = [F[1], [F[1][0] + v[0], F[1][1] + v[1]], [F[2][0] + v[0], F[2][1] + v[1]], F[2]];
    const col = o.color || C.ink, a = o.alpha ?? 1, s = o.seed || 4;
    if (o.back) { const B0 = [x + v[0], y + v[1]]; dashed(ctx, B0, [B0[0] + c * k, B0[1]], C.dim, 2); dashed(ctx, B0, [B0[0], B0[1] - h * k], C.dim, 2); dashed(ctx, B0, [x, y], C.dim, 2); }
    G.poly(ctx, R, { fill: o.fill ? G.tint(o.fill, -0.25) : null, stroke: col, lw: o.lw || 4, seed: s + 1, alpha: a });
    G.poly(ctx, T, { fill: o.fill ? G.tint(o.fill, 0.2) : null, stroke: col, lw: o.lw || 4, seed: s + 2, alpha: a });
    G.poly(ctx, F, { fill: o.fill || null, stroke: col, lw: o.lw || 4, seed: s, alpha: a });
    return { F, T, R, v };
  }
  function cylinder(ctx, cx, by, r, h, o = {}) {
    const ry = r * 0.32, col = o.color || C.ink, a = o.alpha ?? 1;
    if (o.fill) { ctx.save(); ctx.globalAlpha *= a * 0.5; ctx.fillStyle = o.fill; ctx.beginPath(); ctx.ellipse(cx, by, r, ry, 0, 0, PI); ctx.lineTo(cx - r, by - h); ctx.ellipse(cx, by - h, r, ry, 0, PI, 0, true); ctx.closePath(); ctx.fill(); ctx.restore(); }
    ctx.save(); ctx.globalAlpha *= a;
    arc(ctx, cx, by, r, 0, PI, col, 4); arc(ctx, cx, by, r, PI, TAU, C.dim, 2);
    // a elipse de baixo é desenhada achatada: escala vertical
    ctx.restore();
    ctx.save(); ctx.globalAlpha *= a;
    ctx.translate(cx, by); ctx.scale(1, ry / r); ctx.translate(-cx, -by);
    ctx.restore();
    ellipseLine(ctx, cx, by, r, ry, col, a, true);
    ellipseLine(ctx, cx, by - h, r, ry, col, a, false, o.top);
    ln(ctx, [[cx - r, by], [cx - r, by - h]], col, 4); ln(ctx, [[cx + r, by], [cx + r, by - h]], col, 4);
  }
  function ellipseLine(ctx, cx, cy, rx, ry, col, a = 1, halfBack = false, fill) {
    const front = [], back = [];
    for (let i = 0; i <= 40; i++) { const t = (i / 40) * PI; front.push([cx + rx * Math.cos(t), cy + ry * Math.sin(t)]); back.push([cx + rx * Math.cos(t + PI), cy + ry * Math.sin(t + PI)]); }
    ctx.save(); ctx.globalAlpha *= a;
    if (fill) G.ellipse(ctx, cx, cy, rx, ry, { fill, stroke: null, lw: 0, seed: 3 });
    ln(ctx, front, col, 4); ln(ctx, back, halfBack ? C.dim : col, halfBack ? 2 : 4);
    ctx.restore();
  }
  function cone(ctx, cx, by, r, h, o = {}) {
    const ry = r * 0.32, col = o.color || C.ink;
    ctx.save(); ctx.globalAlpha *= o.alpha ?? 1;
    if (o.fill) fillPoly(ctx, [[cx - r, by], [cx, by - h], [cx + r, by]], o.fill, 0.5);
    ellipseLine(ctx, cx, by, r, ry, col, 1, true);
    ln(ctx, [[cx - r, by], [cx, by - h], [cx + r, by]], col, 4);
    ctx.restore();
  }

  // ---------------- ambiente de uma figura ----------------
  // at(k): quando a linha original k aparece (relativo à cena); on(k, d): 0→1 a partir dali
  function env(sc, lt) {
    const at = (k) => {
      if (k === undefined || k === null || k < 0) return 0.3;
      const l = (sc.lines || []).find((q) => q.src === k);
      return l ? l.at : k >= 90 ? 1e9 : 0.3;
    };
    return { at, on: (k, d = 0.7) => clamp((lt - at(k)) / d), t: lt, since: (k) => lt - at(k) };
  }

  // =====================================================================
  // FIGURAS
  // =====================================================================
  const FIG = {};

  FIG.isPoly = (ctx, f, E) => {
    const rows = [BOX.y + 110, BOX.y + 345, BOX.y + 580], x = BOX.x + 170;
    const a0 = E.on(f.s[0], 1.2), a1 = E.on(f.s[1], 1.2), a2 = E.on(f.s[2], 1.2);
    const pent = [[-90, 40], [-70, -60], [20, -95], [95, -20], [50, 70]].map(([a, b]) => [x + a, rows[0] + b]);
    ln(ctx, closed(pent), C.y, 5, a0); check(ctx, x + 250, rows[0], 1.3, clamp(a0 * 2 - 1)); txt(ctx, 'polígono', x + 300, rows[0] + 14, { alpha: clamp(a0 * 2 - 1), color: C.g });
    const open = [[-90, 50], [-40, -60], [20, 40], [90, -50]].map(([a, b]) => [x + a, rows[1] + b]);
    ln(ctx, open, C.ink, 5, a1); cross(ctx, x + 250, rows[1], 1.1, clamp(a1 * 2 - 1)); txt(ctx, 'aberta', x + 300, rows[1] + 14, { alpha: clamp(a1 * 2 - 1), color: C.p });
    const circ = []; for (let i = 0; i <= 48; i++) circ.push([x + 85 * Math.cos((i / 48) * TAU), rows[2] + 85 * Math.sin((i / 48) * TAU)]);
    ln(ctx, circ, C.ink, 5, a2); cross(ctx, x + 250, rows[2], 1.1, clamp(a2 * 2 - 1)); txt(ctx, 'curva', x + 300, rows[2] + 14, { alpha: clamp(a2 * 2 - 1), color: C.p });
  };

  FIG.polyParts = (ctx, f, E) => {
    const P = [[-180, -30], [-40, -200], [170, -120], [160, 140], [-110, 170]].map(([a, b]) => [CX + a, CY + b]);
    const a = E.on(f.s[0], 1.8);
    for (let i = 0; i < 5; i++) ln(ctx, [P[i], P[(i + 1) % 5]], C.y, 6, clamp(a * 5 - i), 10 + i);
    if (a > 0.9) txt(ctx, 'lado', ...mid(P[2], P[3]).map((v, i) => v + (i ? 10 : 22)), { color: C.y, size: 36 });
    const v = E.on(f.s[1], 1.4);
    'ABCDE'.split('').forEach((L, i) => {
      const k = clamp(v * 5 - i); if (k <= 0) return;
      dot(ctx, P[i][0], P[i][1], 9 * k, C.b);
      const o = sub(P[i], [CX, CY]); const n = Math.hypot(...o);
      txt(ctx, L, P[i][0] + (o[0] / n) * 42, P[i][1] + (o[1] / n) * 42 + 14, { color: C.b, size: 44, align: 'center', alpha: k });
    });
    const g = E.on(f.s[2], 1.6);
    for (let i = 0; i < 5; i++) angleArc(ctx, P[i], P[(i + 1) % 5], P[(i + 4) % 5], 40, C.p, clamp(g * 5 - i));
  };

  FIG.degrees = (ctx, f, E) => {
    const items = [[f.s[0], 360, '360°', 'uma volta'], [f.s[1], 180, '180°', 'meia volta (reta)'], [f.s[2], 90, '90°', 'ângulo reto']];
    items.forEach(([k, deg, lab, name], i) => {
      const a = E.on(k, 1.5); if (a <= 0) return;
      const cx = BOX.x + 150, cy = BOX.y + 110 + i * 240, r = 80;
      ln(ctx, [[cx, cy], [cx + r + 20, cy]], C.ink, 4);
      const sweep = (deg * PI) / 180 * ease.inOutCubic(a);
      arc(ctx, cx, cy, r * 0.6, 0, -sweep, C.y, 5);
      ln(ctx, [[cx, cy], [cx + (r + 20) * Math.cos(-sweep), cy + (r + 20) * Math.sin(-sweep)]], C.ink, 4);
      if (deg === 90 && a >= 1) rightMark(ctx, [cx, cy], [1, 0], [0, -1], 24, C.y);
      txt(ctx, lab, cx + 160, cy + 2, { size: 52, color: C.y, alpha: clamp(a * 2 - 1) });
      txt(ctx, name, cx + 160, cy + 50, { size: 34, color: C.ink, alpha: clamp(a * 2 - 1) });
    });
  };

  FIG.gallery = (ctx, f, E) => {
    let k = -1; f.ns.forEach((n, i) => { if (E.since(i) >= 0) k = i; });
    if (k < 0) return;
    const n = f.ns[k], a = clamp(E.since(k) / 1.2);
    const P = regPts(n, CX, CY - 20, 230);
    for (let i = 0; i < n; i++) ln(ctx, [P[i], P[(i + 1) % n]], C.y, 6, clamp(a * n - i), i);
    P.forEach((p, i) => { if (a * n > i) { dot(ctx, p[0], p[1], 7, C.b); txt(ctx, String(i + 1), CX + (p[0] - CX) * 1.18, CY - 20 + (p[1] - CY + 20) * 1.18 + 12, { size: 32, color: C.b, align: 'center' }); } });
    txt(ctx, `${n} lados`, CX, CY + 300, { size: 50, color: C.ink, align: 'center', alpha: a });
  };

  FIG.regIrreg = (ctx, f, E) => {
    const a0 = E.on(f.s[0], 1.2), a1 = E.on(f.s[1], 1.2), a2 = E.on(f.s[2], 1.2), a3 = E.on(f.s[3], 1.2);
    const cx1 = BOX.x + 140, cx2 = BOX.x + 440, cy1 = BOX.y + 150, cy2 = BOX.y + 470;
    const R = regPts(6, cx1, cy1, 110, 0);
    ln(ctx, closed(R), C.g, 5, a0);
    if (a0 >= 1) for (let i = 0; i < 6; i++) { const m = mid(R[i], R[(i + 1) % 6]); const d = sub(R[(i + 1) % 6], R[i]); const n = Math.hypot(...d); const nx = -d[1] / n * 10, ny = d[0] / n * 10; ln(ctx, [[m[0] - nx, m[1] - ny], [m[0] + nx, m[1] + ny]], C.g, 3); }
    txt(ctx, 'regular', cx1, cy1 + 160, { align: 'center', color: C.g, alpha: a0 });
    const I = [[-110, -10], [-40, -100], [90, -80], [120, 30], [20, 110], [-80, 70]].map(([x, y]) => [cx2 + x, cy1 + y]);
    ln(ctx, closed(I), C.p, 5, a1); txt(ctx, 'irregular', cx2, cy1 + 160, { align: 'center', color: C.p, alpha: a1 });
    const rect = [[cx1 - 130, cy2 - 70], [cx1 + 130, cy2 - 70], [cx1 + 130, cy2 + 70], [cx1 - 130, cy2 + 70]];
    ln(ctx, closed(rect), C.ink, 5, a2); if (a2 >= 1) rightMark(ctx, rect[3], [1, 0], [0, -1], 22, C.y);
    txt(ctx, 'retângulo', cx1, cy2 + 130, { align: 'center', alpha: a2 }); cross(ctx, cx1 + 120, cy2 + 118, 0.8, a2);
    const rh = [[cx2, cy2 - 110], [cx2 + 85, cy2], [cx2, cy2 + 110], [cx2 - 85, cy2]];
    ln(ctx, closed(rh), C.ink, 5, a3); txt(ctx, 'losango', cx2, cy2 + 160, { align: 'center', alpha: a3 }); cross(ctx, cx2 + 110, cy2 + 148, 0.8, a3);
  };

  FIG.tri180 = (ctx, f, E) => {
    const V = [[BOX.x + 60, BOX.y + 360], [BOX.x + 560, BOX.y + 360], [BOX.x + 200, BOX.y + 40]];
    const a = E.on(f.s[0], 1.2);
    ln(ctx, closed(V), C.ink, 5, a);
    const cols = [C.p, C.b, C.y], names = ['a', 'b', 'c'];
    const spans = [], starts = [];
    for (let i = 0; i < 3; i++) {
      const v = V[i], p = V[(i + 1) % 3], q = V[(i + 2) % 3];
      let a0 = ang(sub(p, v)), a1 = ang(sub(q, v)); let d = a1 - a0; while (d > PI) d -= TAU; while (d < -PI) d += TAU;
      if (d < 0) { a0 = a0 + d; d = -d; }
      spans.push(d); starts.push(a0);
    }
    const m = E.on(f.s[1], 2.4), mv = ease.inOutCubic(clamp((m - 0.15) / 0.85));
    const P = [CX, BOX.y + 600];
    if (m > 0) ln(ctx, [[BOX.x + 40, P[1]], [BOX.x + BOX.w - 40, P[1]]], C.ink, 4, clamp(m * 4));
    let acc = -PI;
    for (let i = 0; i < 3; i++) {
      const fs = acc; acc += spans[i];
      const cx = lerp(V[i][0], P[0], mv), cy = lerp(V[i][1], P[1], mv);
      let s0 = starts[i], d = fs - s0; while (d > PI) d -= TAU; while (d < -PI) d += TAU;
      const st = s0 + d * mv;
      if (a > 0.8) {
        ctx.save(); ctx.globalAlpha *= 0.55 * clamp((a - 0.8) * 5); ctx.fillStyle = cols[i];
        ctx.beginPath(); ctx.moveTo(cx, cy); ctx.arc(cx, cy, 70, st, st + spans[i]); ctx.closePath(); ctx.fill(); ctx.restore();
        arc(ctx, cx, cy, 70, st, st + spans[i], cols[i], 4);
        const am = st + spans[i] / 2; txt(ctx, names[i], cx + Math.cos(am) * 100, cy + Math.sin(am) * 100 + 14, { size: 44, color: cols[i], align: 'center' });
      }
    }
    if (mv >= 1) txt(ctx, 'a + b + c = 180°', CX, P[1] + 80, { size: 50, color: C.y, align: 'center', alpha: clamp(m * 3 - 2) });
  };

  FIG.triSplit = (ctx, f, E) => {
    let n = f.steps[0][1], since = E.since(f.steps[0][0]);
    for (const [k, nn] of f.steps) if (E.since(k) >= 0) { n = nn; since = E.since(k); }
    if (since < 0) return;
    const P = regPts(n, CX, CY - 10, 250);
    const a = clamp(since / 1.0);
    ln(ctx, closed(P), C.ink, 5, a);
    const tris = n - 2, cols = [C.p, C.b, C.y, C.g, C.o, C.v];
    for (let i = 0; i < tris; i++) {
      const k = clamp((since - 1 - i * 0.45) / 0.5); if (k <= 0) continue;
      fillPoly(ctx, [P[0], P[i + 1], P[i + 2]], cols[i % cols.length], 0.55 * k, 20 + i);
      if (i < tris - 1) ln(ctx, [P[0], P[i + 2]], C.ink, 3, k);
    }
    dot(ctx, P[0][0], P[0][1], 9, C.y);
    const k = clamp((since - 1 - tris * 0.45) / 0.6);
    txt(ctx, `${n} lados → ${tris} triângulos`, CX, CY + 320, { size: 44, align: 'center', alpha: k, color: C.y });
  };

  FIG.polyAngle = (ctx, f, E) => {
    const n = f.n, P = regPts(n, CX, CY, 240, -PI / 2 - PI / n);
    const a = clamp(E.t / 1.0);
    ln(ctx, closed(P), C.ink, 5, a);
    const k = E.on(f.s, 1);
    if (k > 0) angleArc(ctx, P[n - 1], P[0], P[n - 2], 55, C.y, k, f.label, 46);
    if (k > 0) dot(ctx, P[n - 1][0], P[n - 1][1], 8, C.y);
    txt(ctx, `n = ${n}`, CX, BOX.y + BOX.h - 10, { size: 44, align: 'center', alpha: a, color: C.b });
  };

  FIG.extAngle = (ctx, f, E) => {
    const n = f.n, P = regPts(n, CX - 30, CY + 20, 210, 0);
    ln(ctx, closed(P), C.ink, 5, clamp(E.t / 1));
    const a = E.on(f.s[0], 1.2);
    if (a > 0) {
      const v = P[1], prev = P[0], next = P[2];
      const dir = sub(v, prev), L = Math.hypot(...dir); const ext = [v[0] + (dir[0] / L) * 170, v[1] + (dir[1] / L) * 170];
      dashed(ctx, v, mid(v, ext, a), C.b, 4);
      angleArc(ctx, v, next, prev, 46, C.p, a, 'ai', 36);
      angleArc(ctx, v, ext, next, 70, C.b, clamp(a * 2 - 1), 'ae', 36);
    }
    const c = E.on(f.s[1], 1.2);
    if (c > 0) {
      const O = [CX - 30, CY + 20];
      ln(ctx, [O, P[3]], C.y, 4, c); ln(ctx, [O, P[4]], C.y, 4, c);
      angleArc(ctx, O, P[3], P[4], 50, C.y, c, 'ac', 36); dot(ctx, O[0], O[1], 7, C.y);
    }
  };

  FIG.grid = (ctx, f, E) => {
    const { w, h } = f; const k = Math.min(440 / w, 360 / h, 95);
    const x0 = CX - (w * k) / 2, y0 = CY - (h * k) / 2 - 30;
    const a = clamp(E.t / 0.8);
    ctx.save(); ctx.globalAlpha *= 0.5 * a;
    for (let i = 0; i <= w; i++) ln(ctx, [[x0 + i * k, y0], [x0 + i * k, y0 + h * k]], C.dim, 2, 1, i);
    for (let j = 0; j <= h; j++) ln(ctx, [[x0, y0 + j * k], [x0 + w * k, y0 + j * k]], C.dim, 2, 1, 40 + j);
    ctx.restore();
    const R = [[x0, y0], [x0 + w * k, y0], [x0 + w * k, y0 + h * k], [x0, y0 + h * k]];
    ln(ctx, closed(R), C.ink, 5, a);
    const labs = f.labels || [`${w} cm`, `${h} cm`];
    txt(ctx, labs[0], CX, y0 + h * k + 55, { align: 'center', alpha: a, color: C.b });
    txt(ctx, labs[1], x0 - 20, y0 + (h * k) / 2 + 12, { align: 'right', alpha: a, color: C.b });
    const areaStep = f.mode === 'area' || f.mode === 'both' ? f.s[0] : null;
    const perStep = f.mode === 'perim' ? f.s[0] : f.mode === 'both' ? f.s[1] : null;
    if (areaStep !== null) {
      const s = E.since(areaStep), N = w * h, per = Math.min(0.25, 3 / N);
      let shown = 0;
      for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
        const idx = j * w + i, q = clamp((s - idx * per) / 0.25); if (q <= 0) continue; shown = idx + 1;
        G.rrect(ctx, x0 + i * k + 5, y0 + j * k + 5, k - 10, k - 10, 6, { fill: C.g, stroke: null, lw: 0, alpha: 0.6 * q, seed: idx });
        if (k > 60) txt(ctx, String(idx + 1), x0 + i * k + k / 2, y0 + j * k + k / 2 + 12, { size: 30, align: 'center', color: '#1E3328', alpha: q });
      }
      if (s > 0 && f.mode !== 'both') txt(ctx, `${shown} quadradinhos`, CX, y0 - 30, { align: 'center', color: C.g, size: 42 });
      const s2 = f.s[1] !== undefined && f.mode === 'area' ? E.on(f.s[1], 0.8) : 0;
      if (s2 > 0) txt(ctx, `${w} · ${h} = ${w * h}`, CX, y0 + h * k + 120, { align: 'center', color: C.y, size: 52, alpha: s2 });
    }
    if (perStep !== null) {
      const s = E.since(perStep); const p = clamp(s / 4);
      if (s > 0) {
        ln(ctx, closed(R), C.y, 8, p, 77);
        const pos = partial(closed(R), p); const e = pos[pos.length - 1];
        dot(ctx, e[0], e[1], 12, C.o); txt(ctx, 'formiga', e[0], e[1] - 24, { size: 28, color: C.o, align: 'center' });
        const per = 2 * (w + h);
        const isBoth = f.mode === 'both';
        const val = isBoth ? `perímetro = ${labs[0].replace(/ .*/, '')} + ${labs[1].replace(/ .*/, '')} + ${labs[0].replace(/ .*/, '')} + ${labs[1].replace(/ .*/, '')}` : `P = ${w} + ${h} + ${w} + ${h} = ${per}`;
        txt(ctx, val, CX, y0 + h * k + 120, { align: 'center', color: C.y, size: isBoth ? 36 : 46, alpha: clamp(s - 4) });
      }
    }
  };

  FIG.areaVol = (ctx, f, E) => {
    const a = E.on(f.s[0], 1.2), b = E.on(f.s[1], 1.5);
    const k = 50, x0 = BOX.x + 120, y0 = BOX.y + 40;
    if (a > 0) {
      for (let j = 0; j < 3; j++) for (let i = 0; i < 3; i++) { const q = clamp(a * 9 - (j * 3 + i)); if (q > 0) G.rrect(ctx, x0 + i * k, y0 + j * k, k - 4, k - 4, 4, { fill: C.g, stroke: C.ink, lw: 2, alpha: q, seed: i + j * 3 }); }
      txt(ctx, 'ÁREA: 9 quadradinhos', x0 + 180, y0 + 90, { size: 36, color: C.g, alpha: a });
      txt(ctx, '(plano: 2 dimensões)', x0 + 180, y0 + 135, { size: 30, color: C.dim, alpha: a });
    }
    if (b > 0) {
      const ox = BOX.x + 110, oy = BOX.y + 560, kk = 60, cubes = [];
      for (let y = 0; y < 3; y++) for (let z = 2; z >= 0; z--) for (let x = 0; x < 3; x++) cubes.push([x, y, z]);
      cubes.forEach(([x, y, z], i) => {
        const q = clamp(b * 27 - i); if (q <= 0) return;
        const px = ox + x * kk + z * kk * DEP[0], py = oy - y * kk + z * kk * DEP[1] - (1 - q) * 40;
        box3(ctx, px, py, 1, 1, 1, kk, { fill: C.b, lw: 2, seed: i, alpha: q });
      });
      txt(ctx, 'VOLUME: 27 cubinhos', BOX.x + 370, oy - 120, { size: 36, color: C.b, alpha: b });
      txt(ctx, '(sólido: 3 dimensões)', BOX.x + 370, oy - 75, { size: 30, color: C.dim, alpha: b });
    }
  };

  FIG.units = (ctx, f, E) => {
    const a = E.on(f.s[0]), b = E.on(f.s[1]), c = E.on(f.s[2], 1);
    const x = BOX.x + 120, k = 110;
    ln(ctx, [[x, BOX.y + 90], [x + k, BOX.y + 90]], C.y, 7, a);
    if (a > 0) { ln(ctx, [[x, BOX.y + 75], [x, BOX.y + 105]], C.y, 4); ln(ctx, [[x + k, BOX.y + 75], [x + k, BOX.y + 105]], C.y, 4); txt(ctx, '1 cm', x + k + 50, BOX.y + 102, { color: C.y, alpha: a }); txt(ctx, 'comprimento', x + k + 50, BOX.y + 145, { size: 30, color: C.dim, alpha: a }); }
    if (b > 0) { G.rrect(ctx, x, BOX.y + 230, k, k, 2, { fill: C.g, stroke: C.g, lw: 4, alpha: b, seed: 5 }); txt(ctx, '1 cm²', x + k + 50, BOX.y + 300, { color: C.g, alpha: b }); txt(ctx, 'área', x + k + 50, BOX.y + 343, { size: 30, color: C.dim, alpha: b }); }
    if (c > 0) { box3(ctx, x, BOX.y + 600, 1, 1, 1, k, { fill: C.b, color: C.b, alpha: c }); txt(ctx, '1 cm³', x + k + 100, BOX.y + 560, { color: C.b, alpha: c }); txt(ctx, 'volume', x + k + 100, BOX.y + 603, { size: 30, color: C.dim, alpha: c }); }
  };

  FIG.triArea = (ctx, f, E) => {
    const x0 = BOX.x + 60, x1 = BOX.x + 540, yb = BOX.y + 470, yt = BOX.y + 150, apx = BOX.x + 220;
    const a = E.on(f.s[0], 1.2), b = E.on(f.s[1], 1.2), c = E.on(f.s[2], 1.2);
    const R = [[x0, yb], [x1, yb], [x1, yt], [x0, yt]], T = [[x0, yb], [x1, yb], [apx, yt]];
    if (a > 0) { for (let i = 0; i < 4; i++) dashed(ctx, R[i], R[(i + 1) % 4], C.dim, 3); }
    ln(ctx, closed(T), C.ink, 5, a);
    if (b > 0) {
      fillPoly(ctx, T, C.y, 0.5 * b, 7);
      fillPoly(ctx, [[x0, yb], [apx, yt], [x0, yt]], C.b, 0.35 * b, 8); fillPoly(ctx, [[x1, yb], [x1, yt], [apx, yt]], C.b, 0.35 * b, 9);
      txt(ctx, 'triângulo = metade', CX, yb + 150, { align: 'center', color: C.y, alpha: b, size: 42 });
    }
    txt(ctx, 'b', (x0 + x1) / 2, yb + 50, { align: 'center', color: C.b, alpha: a, size: 46 });
    if (c > 0) {
      dashed(ctx, [apx, yt], mid([apx, yt], [apx, yb], c), C.g, 5);
      if (c >= 1) rightMark(ctx, [apx, yb], [1, 0], [0, -1], 24, C.g);
      txt(ctx, 'h', apx + 18, (yt + yb) / 2, { color: C.g, alpha: c, size: 46 });
      txt(ctx, 'não é h!', (apx + x1) / 2 + 40, (yt + yb) / 2 - 20, { color: C.p, alpha: c, size: 36 });
    } else if (a > 0) txt(ctx, 'h', x0 - 34, (yt + yb) / 2, { color: C.g, alpha: a, size: 46 });
  };

  FIG.shapes2 = (ctx, f, E) => {
    const a = E.on(f.s[0], 2.5), b = E.on(f.s[1], 1.2), c = E.on(f.s[2], 1.2);
    // paralelogramo que vira retângulo
    const y0 = BOX.y + 40, hh = 130, x0 = BOX.x + 120, bb = 300, sh = 80;
    if (a > 0) {
      const m = ease.inOutCubic(clamp((a - 0.4) / 0.6));
      fillPoly(ctx, [[x0 + sh, y0], [x0 + sh + bb - sh, y0], [x0 + bb, y0 + hh], [x0 + sh, y0 + hh]], C.g, 0.45, 3);
      ln(ctx, [[x0 + sh, y0], [x0 + bb + sh, y0], [x0 + bb, y0 + hh], [x0, y0 + hh], [x0 + sh, y0]], C.ink, 5, clamp(a * 3));
      const dx = m * bb; // o triângulo da esquerda escorrega para a direita
      fillPoly(ctx, [[x0 + sh + dx, y0], [x0 + sh + dx, y0 + hh], [x0 + dx, y0 + hh]], C.y, 0.6, 4);
      ln(ctx, closed([[x0 + sh + dx, y0], [x0 + sh + dx, y0 + hh], [x0 + dx, y0 + hh]]), C.y, 3);
      txt(ctx, 'paralelogramo → retângulo', CX - 20, y0 + hh + 50, { align: 'center', size: 34, alpha: a });
    }
    if (b > 0) {
      const yy = BOX.y + 290, xb = BOX.x + 100;
      const T = [[xb, yy + 150], [xb + 340, yy + 150], [xb + 250, yy], [xb + 90, yy]];
      ln(ctx, closed(T), C.ink, 5, b);
      txt(ctx, 'B', xb + 170, yy + 195, { align: 'center', color: C.b, alpha: b }); txt(ctx, 'b', xb + 170, yy - 15, { align: 'center', color: C.b, alpha: b });
      dashed(ctx, [xb + 250, yy], [xb + 250, yy + 150], C.g, 3); txt(ctx, 'h', xb + 262, yy + 90, { color: C.g, alpha: b });
      txt(ctx, 'trapézio', xb + 370, yy + 95, { alpha: b, size: 36 });
    }
    if (c > 0) {
      const cx = BOX.x + 230, cy = BOX.y + 625;
      const L = [[cx, cy - 90], [cx + 150, cy], [cx, cy + 90], [cx - 150, cy]];
      ln(ctx, closed(L), C.ink, 5, c);
      dashed(ctx, L[3], L[1], C.y, 3); dashed(ctx, L[0], L[2], C.p, 3);
      txt(ctx, 'D', cx + 80, cy - 10, { color: C.y, alpha: c }); txt(ctx, 'd', cx + 10, cy - 40, { color: C.p, alpha: c });
      txt(ctx, 'losango', cx + 190, cy + 12, { alpha: c, size: 36 });
    }
  };

  FIG.circle = (ctx, f, E) => {
    const r = 220, cx = CX, cy = CY - 20;
    const a = clamp(E.t / 1);
    const circ = []; for (let i = 0; i <= 64; i++) circ.push([cx + r * Math.cos((i / 64) * TAU), cy + r * Math.sin((i / 64) * TAU)]);
    ln(ctx, circ, C.ink, 5, a); dot(ctx, cx, cy, 7, C.ink);
    const b = E.on(f.s[0]); ln(ctx, [[cx, cy], [cx + r, cy]], C.y, 5, b); if (b > 0) txt(ctx, 'r', cx + r / 2, cy - 14, { color: C.y, alpha: b, size: 50, align: 'center' });
    const c = E.on(f.s[1]); if (c > 0) { ln(ctx, [[cx - r * 0.7071, cy + r * 0.7071], [cx + r * 0.7071, cy - r * 0.7071]], C.b, 5, c); txt(ctx, 'd', cx - 60, cy + 30, { color: C.b, alpha: c, size: 50 }); }
    const d = E.on(f.s[2], 3); if (d > 0) { ln(ctx, circ, C.p, 9, d, 33); txt(ctx, 'C (contorno)', cx, cy + r + 70, { align: 'center', color: C.p, alpha: clamp(d * 2) }); }
  };

  FIG.circleArea = (ctx, f, E) => {
    const r = 220, cx = CX, cy = CY - 30, a = clamp(E.t / 1.2);
    if (f.pizza) {
      G.ellipse(ctx, cx, cy, r, r, { fill: '#E8B060', stroke: C.o, lw: 6, alpha: a, seed: 4 });
      G.ellipse(ctx, cx, cy, r - 22, r - 22, { fill: '#D9534F', stroke: null, lw: 0, alpha: a * 0.8, seed: 5 });
      for (let i = 0; i < 8; i++) ln(ctx, [[cx, cy], [cx + r * Math.cos((i * TAU) / 8), cy + r * Math.sin((i * TAU) / 8)]], C.ink, 2, a);
      for (let i = 0; i < 12; i++) { const an = G.rnd(i, 1) * TAU, rr = 40 + G.rnd(i, 2) * 140; dot(ctx, cx + rr * Math.cos(an), cy + rr * Math.sin(an), 14, '#F5E6C8'); }
      const b = E.on(1, 1); ln(ctx, [[cx - r, cy + r + 40], [cx + r, cy + r + 40]], C.b, 4, b); txt(ctx, 'd = 30 cm', cx, cy + r + 90, { align: 'center', color: C.b, alpha: b });
      const c = E.on(1, 1); ln(ctx, [[cx, cy], [cx + r, cy]], C.y, 6, c); if (c > 0) txt(ctx, 'r = 15', cx + r / 2, cy - 16, { align: 'center', color: C.y, alpha: c, size: 40 });
      return;
    }
    G.ellipse(ctx, cx, cy, r, r, { fill: C.g, stroke: C.ink, lw: 5, alpha: a, seed: 4 });
    ln(ctx, [[cx, cy], [cx + r, cy]], C.y, 6, a); txt(ctx, 'r = 5', cx + r / 2, cy - 16, { align: 'center', color: C.y, alpha: a, size: 44 });
    txt(ctx, 'A = π · r²', cx, cy + r + 80, { align: 'center', color: C.y, alpha: a, size: 54 });
  };

  FIG.hexTri = (ctx, f, E) => {
    const P = regPts(6, CX, CY - 10, 250, 0), s = E.since(0), cols = [C.p, C.b, C.y, C.g, C.o, C.v];
    ln(ctx, closed(P), C.ink, 5, clamp(s / 1));
    for (let i = 0; i < 6; i++) {
      const k = clamp((s - 1.2 - i * 0.5) / 0.5); if (k <= 0) continue;
      fillPoly(ctx, [[CX, CY - 10], P[i], P[(i + 1) % 6]], cols[i], 0.5 * k, i + 3);
      ln(ctx, [[CX, CY - 10], P[i]], C.ink, 3, k);
      const m = mid(P[i], P[(i + 1) % 6]); txt(ctx, 'l', m[0] + (m[0] - CX) * 0.15, m[1] + (m[1] - CY + 10) * 0.15 + 12, { size: 36, align: 'center', color: C.y, alpha: k });
    }
    txt(ctx, '6 triângulos equiláteros', CX, CY + 310, { align: 'center', alpha: clamp((s - 4.5) / 0.6), color: C.y });
  };

  FIG.solids = (ctx, f, E) => {
    const cells = [[BOX.x + 140, BOX.y + 200], [BOX.x + 440, BOX.y + 200], [BOX.x + 140, BOX.y + 440], [BOX.x + 440, BOX.y + 440], [BOX.x + 140, BOX.y + 680], [BOX.x + 440, BOX.y + 680]];
    const names = ['cubo', 'paralelepípedo', 'cilindro', 'cone', 'pirâmide', 'esfera'];
    cells.forEach(([x, y], i) => {
      const a = E.on(f.s[i], 0.8); if (a <= 0) return;
      ctx.save(); ctx.globalAlpha *= a;
      if (i === 0) box3(ctx, x - 70, y - 30, 1, 1, 1, 110, { fill: C.b });
      if (i === 1) box3(ctx, x - 110, y - 30, 2, 1, 1, 90, { fill: C.o });
      if (i === 2) cylinder(ctx, x, y - 30, 60, 120, { fill: C.g });
      if (i === 3) cone(ctx, x, y - 30, 65, 140, { fill: C.y });
      if (i === 4) { const b = [[x - 80, y - 30], [x + 40, y - 30], [x + 80, y - 65], [x - 40, y - 65]], apex = [x, y - 170]; fillPoly(ctx, [b[0], b[1], apex], C.p, 0.5); fillPoly(ctx, [b[1], b[2], apex], C.p, 0.3); ln(ctx, closed(b.slice(0, 2).concat([b[2]])), C.ink, 4); dashed(ctx, b[2], b[3]); dashed(ctx, b[3], b[0]); dashed(ctx, b[3], apex); ln(ctx, [b[0], apex, b[1]], C.ink, 4); ln(ctx, [b[2], apex], C.ink, 4); }
      if (i === 5) { G.ellipse(ctx, x, y - 95, 75, 75, { fill: C.v, stroke: C.ink, lw: 4, seed: 6 }); ellipseLine(ctx, x, y - 95, 75, 22, C.ink, 0.8, true); }
      ctx.restore();
      txt(ctx, names[i], x, y + 20, { size: 32, align: 'center', alpha: a });
    });
  };

  FIG.boxFill = (ctx, f, E) => {
    const { c, l, h } = f, k = 95, ox = BOX.x + 90, oy = BOX.y + 520;
    const a = clamp(E.t / 1);
    const frame = () => {
      const v = [l * k * DEP[0], l * k * DEP[1]];
      const F = [[ox, oy], [ox + c * k, oy], [ox + c * k, oy - h * k], [ox, oy - h * k]];
      ln(ctx, closed(F), C.ink, 4, a); ln(ctx, [F[3], [F[3][0] + v[0], F[3][1] + v[1]], [F[2][0] + v[0], F[2][1] + v[1]], F[2]], C.ink, 4, a);
      ln(ctx, [[F[2][0] + v[0], F[2][1] + v[1]], [F[1][0] + v[0], F[1][1] + v[1]], F[1]], C.ink, 4, a);
    };
    if (f.water) {
      const lv = E.on(0, 4) * h;
      if (lv > 0) box3(ctx, ox, oy, c, lv, l, k, { fill: C.b, color: C.b, lw: 2, seed: 9 });
      frame();
      txt(ctx, '2 m', ox + (c * k) / 2, oy + 50, { align: 'center', color: C.y, alpha: a }); txt(ctx, '1 m', ox - 50, oy - (h * k) / 2, { align: 'center', color: C.y, alpha: a }); txt(ctx, '1,5 m', ox + c * k + 70, oy - 40, { color: C.y, alpha: a });
      return;
    }
    const cubes = [];
    for (let y = 0; y < h; y++) for (let z = l - 1; z >= 0; z--) for (let x = 0; x < c; x++) cubes.push([x, y, z]);
    cubes.forEach(([x, y, z], i) => {
      const layer = y === 0 ? f.s[0] : f.s[1];
      const idx = y === 0 ? i : i - c * l;
      const q = clamp((E.since(layer) - idx * 0.12) / 0.3); if (q <= 0) return;
      const px = ox + x * k + z * k * DEP[0], py = oy - y * k + z * k * DEP[1] - (1 - q) * 60;
      box3(ctx, px, py, 1, 1, 1, k, { fill: y ? C.o : C.b, lw: 2, seed: i, alpha: q });
    });
    frame();
    txt(ctx, `c = ${c}`, ox + (c * k) / 2, oy + 50, { align: 'center', color: C.y, alpha: a });
    txt(ctx, `h = ${h}`, ox - 60, oy - (h * k) / 2, { align: 'center', color: C.y, alpha: a });
    txt(ctx, `l = ${l}`, ox + c * k + (l * k * DEP[0]) / 2 + 30, oy + (l * k * DEP[1]) / 2 + 10, { color: C.y, alpha: a });
    const n0 = clamp(E.since(f.s[0]) / (c * l * 0.12 + 0.3)), n1 = clamp(E.since(f.s[1]) / (c * l * 0.12 + 0.3));
    if (n0 > 0) txt(ctx, `${Math.round(n0 * c * l) + Math.round(n1 * c * l)} cubinhos`, CX, oy + 140, { align: 'center', size: 46, color: C.g });
  };

  FIG.cyl = (ctx, f, E) => {
    const cx = CX, by = BOX.y + 560, r = 150, h = 330, a = clamp(E.t / 1);
    const b = E.on(f.s[0], 1), c = E.on(f.s[1], 3);
    if (b > 0) {
      const lev = c > 0 ? h * ease.inOutCubic(c) : 0;
      ctx.save(); ctx.globalAlpha *= 0.45 * b; ctx.fillStyle = C.g;
      ctx.beginPath(); ctx.ellipse(cx, by, r, r * 0.32, 0, 0, PI); ctx.lineTo(cx - r, by - lev); ctx.ellipse(cx, by - lev, r, r * 0.32, 0, PI, 0, true); ctx.closePath(); ctx.fill();
      ctx.beginPath(); ctx.ellipse(cx, by - lev, r, r * 0.32, 0, 0, TAU); ctx.fill(); ctx.restore();
      txt(ctx, 'base: π · r²', cx, by - lev + 12, { align: 'center', color: C.y, size: 40, alpha: b });
    }
    ctx.save(); ctx.globalAlpha *= a; cylinder(ctx, cx, by, r, h, {}); ctx.restore();
    ln(ctx, [[cx, by - h], [cx + r, by - h]], C.p, 4, a); txt(ctx, 'r', cx + r / 2, by - h - 14, { color: C.p, align: 'center', alpha: a });
    txt(ctx, 'h', cx + r + 30, by - h / 2, { color: C.p, alpha: a, size: 46 });
    if (c > 0) txt(ctx, 'V = base · altura', cx, by + 150, { align: 'center', color: C.y, alpha: clamp(c * 2 - 1), size: 44 });
  };

  FIG.cone3 = (ctx, f, E) => {
    const s = E.since(f.s[0]); if (s < 0) return;
    const by = BOX.y + 470, r = 100, h = 250;
    const cxA = BOX.x + 160, cxB = BOX.x + 440;
    const fill = clamp((s - 1.5) / 6); const k = Math.min(3, Math.floor(fill * 3 + 1e-6));
    cylinder(ctx, cxA, by, r, h, {});
    const lev = h * fill;
    ctx.save(); ctx.globalAlpha *= 0.45; ctx.fillStyle = C.b; ctx.beginPath(); ctx.ellipse(cxA, by, r, r * 0.32, 0, 0, PI); ctx.lineTo(cxA - r, by - lev); ctx.ellipse(cxA, by - lev, r, r * 0.32, 0, PI, 0, true); ctx.closePath(); ctx.fill(); ctx.restore();
    cone(ctx, cxB, by, r, h, { fill: C.b });
    txt(ctx, 'cilindro', cxA, by + 70, { align: 'center' }); txt(ctx, 'cone', cxB, by + 70, { align: 'center' });
    txt(ctx, `${k} cone${k === 1 ? '' : 's'} de água`, CX, by + 150, { align: 'center', color: C.b, alpha: clamp(s - 1.5) });
    txt(ctx, '3 cones = 1 cilindro', CX, by + 215, { align: 'center', color: C.y, alpha: clamp(s - 7.5), size: 48 });
  };

  FIG.balance = (ctx, f, E) => {
    const a = E.on(f.s[0], 1), b = E.on(f.s[1], 1);
    const cx = CX, py = BOX.y + 380;
    ctx.save(); ctx.globalAlpha *= a;
    ln(ctx, [[cx, py + 220], [cx, py]], C.ink, 6); ln(ctx, [[cx - 90, py + 220], [cx + 90, py + 220]], C.ink, 6);
    ln(ctx, [[cx - 250, py], [cx + 250, py]], C.ink, 6);
    for (const sx of [-1, 1]) { ln(ctx, [[cx + sx * 230, py], [cx + sx * 230 - 70, py + 110]], C.dim, 3); ln(ctx, [[cx + sx * 230, py], [cx + sx * 230 + 70, py + 110]], C.dim, 3); ln(ctx, [[cx + sx * 230 - 100, py + 110], [cx + sx * 230 + 100, py + 110]], C.ink, 5); }
    G.rrect(ctx, cx - 300, py + 30, 70, 76, 8, { fill: C.y, stroke: C.ink, lw: 3, seed: 3 });
    txt(ctx, b > 0.5 ? '4' : 'x', cx - 265, py + 85, { align: 'center', color: '#20302A', size: 48 });
    for (let i = 0; i < 3; i++) dot(ctx, cx - 200 + i * 34, py + 92, 15, C.b);
    for (let i = 0; i < 7; i++) dot(ctx, cx + 155 + (i % 4) * 36, py + 92 - Math.floor(i / 4) * 34, 15, C.b);
    txt(ctx, 'x + 3', cx - 230, py + 175, { align: 'center', color: C.y }); txt(ctx, '7', cx + 230, py + 175, { align: 'center', color: C.y });
    ctx.restore();
    if (b > 0) txt(ctx, 'x = 4  (4 + 3 = 7)', cx, py - 70, { align: 'center', color: C.g, size: 52, alpha: b });
  };

  FIG.numline = (ctx, f, E) => {
    const y = CY, x0 = BOX.x + 20, x1 = BOX.x + BOX.w - 20, X = (v) => lerp(x0, x1, (v + 7) / 14);
    const a = clamp(E.t / 1);
    arrow(ctx, [x0, y], [x1 + 10, y], C.ink, 4, a);
    for (let v = -7; v <= 7; v++) { ln(ctx, [[X(v), y - 12], [X(v), y + 12]], v === 0 ? C.y : C.ink, 3, a); if (v % 1 === 0) txt(ctx, String(v).replace('-', '−'), X(v), y + 50, { size: 26, align: 'center', alpha: a, color: v < 0 ? C.p : v > 0 ? C.g : C.y }); }
    txt(ctx, 'negativos', X(-4), y + 110, { align: 'center', color: C.p, alpha: a, size: 34 }); txt(ctx, 'positivos', X(4), y + 110, { align: 'center', color: C.g, alpha: a, size: 34 });
    const hop = (from, to, k, color, lab, dy) => {
      if (k <= 0) return; const pts = []; for (let i = 0; i <= 30; i++) { const u = i / 30; pts.push([lerp(X(from), X(to), u), y - 20 - Math.sin(u * PI) * dy]); }
      ln(ctx, pts, color, 5, k); dot(ctx, X(from), y, 9, color);
      if (k >= 1) { dot(ctx, X(to), y, 11, color); txt(ctx, lab, (X(from) + X(to)) / 2, dy < 150 ? y + 175 : y - 30 - dy, { align: 'center', color, size: 36 }); }
    };
    hop(-5, -2, E.on(f.s[0], 1.2), C.b, '−5 + 3 = −2', 80);
    hop(-2, -6, E.on(f.s[1], 1.2), C.o, '−2 − 4 = −6', 190);
  };

  FIG.machine = (ctx, f, E) => {
    const bx = BOX.x + 150, by = CY - 120, bw = 300, bh = 200, a = clamp(E.t / 1);
    G.rrect(ctx, bx, by, bw, bh, 20, { fill: '#5B6C8F', stroke: C.ink, lw: 5, alpha: a, seed: 3 });
    txt(ctx, 'f(x) = 2x + 1', bx + bw / 2, by + bh / 2 + 14, { align: 'center', size: 42, color: C.y, alpha: a });
    arrow(ctx, [BOX.x, by + bh / 2], [bx - 10, by + bh / 2], C.dim, 4, a); arrow(ctx, [bx + bw + 10, by + bh / 2], [BOX.x + BOX.w, by + bh / 2], C.dim, 4, a);
    txt(ctx, 'entra x', BOX.x + 60, by - 20, { align: 'center', size: 32, alpha: a, color: C.b }); txt(ctx, 'sai f(x)', BOX.x + BOX.w - 60, by - 20, { align: 'center', size: 32, alpha: a, color: C.g });
    const run = (k, inp, out, row) => {
      const s = E.since(k); if (s < 0) return;
      const u1 = clamp(s / 1.2), u2 = clamp((s - 1.6) / 1.2);
      const yy = by + bh / 2 + 12;
      if (u1 < 1) txt(ctx, inp, lerp(BOX.x + 30, bx + 40, ease.inOutQuad(u1)), yy, { size: 56, color: C.b, align: 'center' });
      if (u2 > 0) txt(ctx, out, lerp(bx + bw - 40, BOX.x + BOX.w - 50, ease.outQuad(u2)), yy, { size: 56, color: C.g, align: 'center' });
      txt(ctx, `f(${inp}) = ${out}`, CX, by + bh + 90 + row * 70, { align: 'center', size: 46, color: C.y, alpha: u2 });
    };
    const second = E.since(f.s[1]) >= 0;
    if (!second) run(f.s[0], '3', '7', 0); else run(f.s[1], '0', '1', 1);
    if (second) txt(ctx, 'f(3) = 7', CX, by + bh + 90, { align: 'center', size: 46, color: C.y });
  };

  FIG.abc = () => {}; // a própria lousa já mostra a fórmula em destaque

  FIG.table = (ctx, f, E) => {
    const rows = f.rows, cw = 220, rh = 70, x0 = CX - cw, y0 = BOX.y + 40;
    const a = clamp(E.t / 0.8);
    G.rrect(ctx, x0, y0, cw * 2, rh, 6, { fill: '#3E5E4C', stroke: C.ink, lw: 4, alpha: a, seed: 2 });
    f.head.forEach((h, j) => txt(ctx, h, x0 + cw * j + cw / 2, y0 + 48, { align: 'center', color: C.y, alpha: a, size: 42 }));
    rows.forEach((r, i) => {
      const k = f.allAt !== undefined ? clamp((E.since(f.allAt) - i * 0.35) / 0.4) : E.on(f.s0 + i, 0.5);
      if (k <= 0) return;
      const yy = y0 + rh * (i + 1);
      ln(ctx, closed([[x0, yy], [x0 + 2 * cw, yy], [x0 + 2 * cw, yy + rh], [x0, yy + rh]]), C.ink, 3, k);
      ln(ctx, [[x0 + cw, yy], [x0 + cw, yy + rh]], C.ink, 3, k);
      const hl = r[1] === '0' && f.head[1] === 'f(x)';
      r.forEach((c, j) => txt(ctx, c, x0 + cw * j + cw / 2, yy + 48, { align: 'center', alpha: k, size: 42, color: j && hl ? C.p : C.ink }));
    });
  };

  // eixos cartesianos (para plano e parábolas)
  function axes(ctx, xr, yr, box, a = 1) {
    const X = (x) => lerp(box.x, box.x + box.w, (x - xr[0]) / (xr[1] - xr[0]));
    const Y = (y) => lerp(box.y + box.h, box.y, (y - yr[0]) / (yr[1] - yr[0]));
    ctx.save(); ctx.globalAlpha *= a;
    const stepY = yr[1] - yr[0] > 12 ? 2 : 1;
    for (let x = Math.ceil(xr[0]); x <= xr[1]; x++) if (x) ln(ctx, [[X(x), box.y], [X(x), box.y + box.h]], 'rgba(242,238,227,0.12)', 1.5, 1, x);
    for (let y = Math.ceil(yr[0]); y <= yr[1]; y += 1) if (y) ln(ctx, [[box.x, Y(y)], [box.x + box.w, Y(y)]], 'rgba(242,238,227,0.12)', 1.5, 1, 50 + y);
    arrow(ctx, [box.x, Y(0)], [box.x + box.w + 14, Y(0)], C.ink, 3); arrow(ctx, [X(0), box.y + box.h], [X(0), box.y - 14], C.ink, 3);
    txt(ctx, 'x', box.x + box.w + 10, Y(0) + 40, { size: 34, color: C.ink }); txt(ctx, 'y', X(0) + 18, box.y - 4, { size: 34 });
    for (let x = Math.ceil(xr[0]); x <= xr[1]; x++) if (x) txt(ctx, String(x).replace('-', '−'), X(x), Y(0) + 30, { size: 22, align: 'center', color: C.dim });
    for (let y = Math.ceil(yr[0] / stepY) * stepY; y <= yr[1]; y += stepY) if (y) txt(ctx, String(y).replace('-', '−'), X(0) - 10, Y(y) + 8, { size: 22, align: 'right', color: C.dim });
    ctx.restore();
    return { X, Y };
  }

  FIG.plane = (ctx, f, E) => {
    const { X, Y } = axes(ctx, [-5, 5], [-5, 5], { x: BOX.x + 20, y: BOX.y + 20, w: 560, h: 560 }, clamp(E.t / 1));
    const s = E.since(f.s[0]);
    if (s > 0) {
      const u1 = clamp(s / 1.2), u2 = clamp((s - 1.4) / 1.2);
      dashed(ctx, [X(0), Y(0)], [X(2 * u1), Y(0)], C.b, 5); if (u1 >= 1) txt(ctx, '2 →', X(1), Y(0) - 14, { size: 30, color: C.b, align: 'center' });
      if (u2 > 0) { dashed(ctx, [X(2), Y(0)], [X(2), Y(3 * u2)], C.g, 5); }
      if (u2 >= 1) { dot(ctx, X(2), Y(3), 11, C.y); txt(ctx, '(2, 3)', X(2) + 20, Y(3) - 14, { color: C.y, size: 40 }); txt(ctx, '3 ↑', X(2) + 16, Y(1.5), { size: 30, color: C.g }); }
    }
    const k = E.on(f.s[1]); if (k > 0) { dot(ctx, X(-1), Y(0), 11 * k, C.p); txt(ctx, '(−1, 0)', X(-1) - 20, Y(0) - 22, { color: C.p, size: 36, align: 'right', alpha: k }); }
  };

  FIG.parab = (ctx, f, E) => {
    const { a, b, c, xr, yr } = f;
    const F = (x) => a * x * x + b * x + c;
    const { X, Y } = axes(ctx, xr, yr, { x: BOX.x + 30, y: BOX.y + 10, w: 540, h: 600 }, clamp(E.t / 1));
    const inY = (y) => y >= yr[0] - 0.5 && y <= yr[1] + 0.5;
    if (f.pts !== undefined) [-1, 0, 1, 2, 3, 4].forEach((x, i) => { const k = clamp((E.since(f.pts) - i * 0.45) / 0.4); if (k > 0) { dot(ctx, X(x), Y(F(x)), 10 * k, C.y); } });
    const ca = f.curve === 0 ? clamp(E.t / 1.6) : E.on(f.curve, 2.2);
    if (ca > 0) {
      const pts = []; for (let i = 0; i <= 160; i++) { const x = lerp(xr[0], xr[1], i / 160); const y = F(x); if (inY(y)) pts.push([X(x), Y(clamp(y, yr[0] - 0.5, yr[1] + 0.5))]); }
      ln(ctx, pts, a > 0 ? C.g : C.o, 6, ca, 41);
    }
    const D = b * b - 4 * a * c, xv = -b / (2 * a), yv = F(xv);
    if (f.roots !== undefined) {
      const k = E.on(f.roots, 0.8);
      if (k > 0 && D >= 0) {
        const rs = D === 0 ? [xv] : [(-b - Math.sqrt(D)) / (2 * a), (-b + Math.sqrt(D)) / (2 * a)];
        rs.forEach((r) => { G.ellipse(ctx, X(r), Y(0), 18 * k, 18 * k, { stroke: C.p, lw: 5, seed: 3 }); dot(ctx, X(r), Y(0), 7, C.p); txt(ctx, `x = ${fmt(r)}`, X(r), Y(0) + (a > 0 ? 64 : -30), { size: 32, align: 'center', color: C.p, alpha: k }); });
      }
    }
    if (f.vertex !== undefined) {
      const k = E.on(f.vertex, 0.8);
      if (k > 0) {
        dashed(ctx, [X(xv), Y(yr[0])], [X(xv), Y(yr[1])], C.dim, 2);
        dot(ctx, X(xv), Y(yv), 12 * k, C.y);
        txt(ctx, `V(${fmt(xv)}, ${fmt(yv)})`, X(xv) + 22, Y(yv) + (a > 0 ? 44 : -22), { size: 36, color: C.y, alpha: k });
      }
    }
    if (f.axis !== undefined) { const k = E.on(f.axis, 1); if (k > 0) dashed(ctx, [X(xv), Y(yr[0])], [X(xv), lerp(Y(yr[0]), Y(yr[1]), k)], C.b, 3); }
    if (f.cpt !== undefined) { const k = E.on(f.cpt, 0.8); if (k > 0) { dot(ctx, X(0), Y(c), 12 * k, C.b); txt(ctx, `(0, ${fmt(c)})`, X(0) + 20, Y(c) + 12, { size: 36, color: C.b, alpha: k }); } }
    if (f.ball && D >= 0) {
      const r0 = (-b + Math.sqrt(D)) / (2 * a), r1 = (-b - Math.sqrt(D)) / (2 * a);
      const lo = Math.min(r0, r1), hi = Math.max(r0, r1);
      const u = (E.t * 0.35) % 1, x = lerp(lo, hi, u);
      G.ellipse(ctx, X(x), Y(F(x)) - 16, 16, 16, { fill: C.ink, stroke: C.ink, lw: 2, seed: 2 });
    }
    txt(ctx, eqn(a, b, c), CX, BOX.y + BOX.h + 30, { align: 'center', size: 40, color: C.ink, alpha: clamp(E.t / 1) });
  };
  function fmt(v) { const r = Math.round(v * 100) / 100; return String(r).replace('.', ',').replace('-', '−'); }
  function eqn(a, b, c) {
    const term = (k, s, first) => { if (!k) return ''; const sg = k < 0 ? '− ' : first ? '' : '+ '; const v = Math.abs(k); return `${first && k < 0 ? '−' : sg}${v === 1 && s ? '' : v}${s} `; };
    return ('f(x) = ' + term(a, 'x²', true) + term(b, 'x', false) + term(c, '', false)).trim();
  }

  FIG.updown = (ctx, f, E) => {
    const mk = (k, aa, y0, lab, sub, col) => {
      if (k <= 0) return;
      const { X, Y } = axes(ctx, [-3, 3], [-4, 4], { x: BOX.x + 40, y: y0, w: 320, h: 280 }, k);
      const pts = []; for (let i = 0; i <= 60; i++) { const x = lerp(-2.6, 2.6, i / 60); const y = aa > 0 ? 0.5 * x * x - 2 : -0.5 * x * x + 2; pts.push([X(x), Y(y)]); }
      ln(ctx, pts, col, 6, k); dot(ctx, X(0), Y(aa > 0 ? -2 : 2), 10, C.y);
      txt(ctx, lab, BOX.x + 420, y0 + 120, { color: col, size: 46, alpha: k }); txt(ctx, sub, BOX.x + 420, y0 + 175, { size: 34, alpha: k });
    };
    mk(E.on(f.s[0], 1.2), 1, BOX.y + 10, 'a > 0', 'mínimo', C.g);
    mk(E.on(f.s[1], 1.2), -1, BOX.y + 380, 'a < 0', 'máximo', C.o);
  };

  FIG.completeSq = (ctx, f, E) => {
    const x = 240, k = 100, x0 = BOX.x + 80, y0 = BOX.y + 60;
    const a = E.on(f.s[0], 1.2), b = E.on(f.s[1], 1.2);
    if (a > 0) {
      G.rrect(ctx, x0, y0, x, x, 2, { fill: C.p, stroke: C.ink, lw: 4, alpha: a, seed: 1 }); txt(ctx, 'x²', x0 + x / 2, y0 + x / 2 + 16, { align: 'center', size: 56, color: C.ink, alpha: a });
      G.rrect(ctx, x0 + x, y0, k, x, 2, { fill: C.b, stroke: C.ink, lw: 4, alpha: a, seed: 2 }); txt(ctx, '3x', x0 + x + k / 2, y0 + x / 2 + 14, { align: 'center', size: 42, alpha: a });
      G.rrect(ctx, x0, y0 + x, x, k, 2, { fill: C.b, stroke: C.ink, lw: 4, alpha: a, seed: 3 }); txt(ctx, '3x', x0 + x / 2, y0 + x + k / 2 + 14, { align: 'center', size: 42, alpha: a });
      txt(ctx, 'x', x0 + x / 2, y0 - 14, { align: 'center', color: C.y, alpha: a }); txt(ctx, '3', x0 + x + k / 2, y0 - 14, { align: 'center', color: C.y, alpha: a });
      txt(ctx, 'x² + 6x', x0 + x + k + 40, y0 + 120, { size: 44, alpha: a });
    }
    if (b > 0) {
      const dy = (1 - ease.outBack(b, 1.5)) * -120;
      G.rrect(ctx, x0 + x, y0 + x + dy, k, k, 2, { fill: C.y, stroke: C.ink, lw: 4, alpha: b, seed: 4 }); txt(ctx, '9', x0 + x + k / 2, y0 + x + k / 2 + 16 + dy, { align: 'center', size: 46, color: '#20302A', alpha: b });
      txt(ctx, '+ 9 completa o quadrado!', CX, y0 + x + k + 80, { align: 'center', color: C.y, alpha: b, size: 40 });
      txt(ctx, '(x + 3)²', CX, y0 + x + k + 150, { align: 'center', color: C.g, alpha: b, size: 56 });
    }
  };

  FIG.bhaskara = (ctx, f, E) => {
    const a = E.on(f.s[0], 1), b = E.on(f.s[1], 1.4);
    if (a > 0) { G.rrect(ctx, BOX.x + 40, BOX.y + 40, 520, 120, 16, { stroke: C.y, lw: 4, seed: 3, alpha: a }); txt(ctx, 'Δ = b² − 4ac', CX, BOX.y + 120, { align: 'center', size: 64, color: C.y, alpha: a }); }
    if (b > 0) {
      const cy = BOX.y + 400;
      G.rrect(ctx, BOX.x + 20, cy - 150, 560, 290, 16, { stroke: C.y, lw: 4, seed: 4, alpha: b });
      txt(ctx, 'x =', BOX.x + 110, cy + 20, { size: 64, color: C.y, alpha: b, align: 'center' });
      txt(ctx, '−b ±', BOX.x + 280, cy - 40, { size: 60, color: C.y, alpha: b, align: 'center' });
      // radical √Δ desenhado à mão
      const rx = BOX.x + 360, ry = cy - 30;
      ln(ctx, [[rx, ry - 10], [rx + 14, ry + 6], [rx + 34, ry - 52], [rx + 120, ry - 52]], C.y, 5, b);
      txt(ctx, 'Δ', rx + 76, ry - 2, { size: 58, color: C.y, alpha: b, align: 'center' });
      ln(ctx, [[BOX.x + 200, cy], [BOX.x + 500, cy]], C.y, 5, b);
      txt(ctx, '2a', BOX.x + 350, cy + 70, { size: 60, color: C.y, alpha: b, align: 'center' });
    }
  };

  FIG.delta3 = (ctx, f, E) => {
    const cases = [[f.s[0], 1, -2, 'Δ > 0', '2 raízes'], [f.s[1], 1, 0, 'Δ = 0', '1 raiz'], [f.s[2], 1, 1.5, 'Δ < 0', 'nenhuma']];
    cases.forEach(([k, aa, cc, lab, sub], i) => {
      const a = E.on(k, 1.2); if (a <= 0) return;
      const box = { x: BOX.x + 20, y: BOX.y + i * 240, w: 300, h: 200 };
      const X = (x) => lerp(box.x, box.x + box.w, (x + 3) / 6), Y = (y) => lerp(box.y + box.h, box.y, (y + 3) / 7);
      ln(ctx, [[box.x, Y(0)], [box.x + box.w, Y(0)]], C.ink, 3, a);
      const pts = []; for (let j = 0; j <= 50; j++) { const x = lerp(-2.6, 2.6, j / 50); const y = 0.6 * x * x + cc; if (y <= 4) pts.push([X(x), Y(y)]); }
      ln(ctx, pts, C.g, 5, a);
      if (a >= 1) { if (cc < 0) { const r = Math.sqrt(-cc / 0.6); dot(ctx, X(-r), Y(0), 9, C.p); dot(ctx, X(r), Y(0), 9, C.p); } else if (cc === 0) dot(ctx, X(0), Y(0), 9, C.p); }
      txt(ctx, lab, BOX.x + 360, box.y + 100, { size: 46, color: C.y, alpha: a }); txt(ctx, sub, BOX.x + 360, box.y + 150, { size: 34, alpha: a });
    });
  };

  FIG.tally = (ctx, f, E) => {
    const a = clamp(E.t / 1), x0 = BOX.x + 60, y0 = BOX.y + 40;
    G.rrect(ctx, x0, y0, 480, 600, 18, { fill: '#C9A675', stroke: C.ink, lw: 4, alpha: a, seed: 2 });
    G.rrect(ctx, x0 + 25, y0 + 40, 430, 540, 6, { fill: '#F4EFE2', stroke: null, lw: 0, alpha: a, seed: 3 });
    G.rrect(ctx, x0 + 170, y0 - 15, 140, 50, 10, { fill: '#8C8C8C', stroke: C.ink, lw: 3, alpha: a, seed: 4 });
    txt(ctx, 'Fruta favorita?', x0 + 240, y0 + 110, { align: 'center', size: 42, color: '#2B2B2B', alpha: a });
    const data = [['Maçã', 8], ['Banana', 12], ['Uva', 6], ['Manga', 4]];
    const s = E.since(f.s[0]);
    data.forEach(([nm, n], i) => {
      const y = y0 + 200 + i * 100;
      txt(ctx, nm, x0 + 50, y, { size: 38, color: '#2B2B2B', alpha: a });
      for (let j = 0; j < n; j++) {
        const q = clamp((s - (i * 12 + j) * 0.12) / 0.15); if (q <= 0) continue;
        const grp = Math.floor(j / 5), r = j % 5, bx = x0 + 200 + grp * 80;
        if (r < 4) ln(ctx, [[bx + r * 14, y - 36], [bx + r * 14, y + 4]], '#2B2B2B', 4, q, j);
        else ln(ctx, [[bx - 8, y - 6], [bx + 52, y - 30]], '#C0392B', 4, q, j);
      }
    });
  };

  FIG.charts = (ctx, f, E) => {
    const a = E.on(f.s[0], 1.5), b = E.on(f.s[1], 1.5), c = E.on(f.s[2], 1.5);
    const data = [['Maçã', 8, C.p], ['Banana', 12, C.y], ['Uva', 6, C.v], ['Manga', 4, C.o]];
    if (a > 0) {
      const x0 = BOX.x + 70, yb = BOX.y + 220;
      ln(ctx, [[x0, BOX.y], [x0, yb], [x0 + 500, yb]], C.ink, 3, a);
      data.forEach(([nm, v, col], i) => { const hh = v * 15 * clamp(a * 1.6 - i * 0.15); G.rrect(ctx, x0 + 30 + i * 118, yb - hh, 80, hh, 4, { fill: col, stroke: C.ink, lw: 2, seed: i }); txt(ctx, nm, x0 + 70 + i * 118, yb + 34, { size: 26, align: 'center' }); if (hh > 10) txt(ctx, String(v), x0 + 70 + i * 118, yb - hh - 8, { size: 28, align: 'center', color: col }); });
      for (let v = 0; v <= 12; v += 4) txt(ctx, String(v), x0 - 12, yb - v * 15 + 8, { size: 22, align: 'right', color: C.dim });
    }
    if (b > 0) {
      const cx = BOX.x + 160, cy = BOX.y + 390, r = 105; let acc = -PI / 2;
      data.forEach(([nm, v, col], i) => { const sp = (v / 30) * TAU * b; ctx.save(); ctx.globalAlpha *= 0.7; ctx.fillStyle = col; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.arc(cx, cy, r, acc, acc + sp); ctx.closePath(); ctx.fill(); ctx.restore(); acc += sp; });
      arc(ctx, cx, cy, r, 0, TAU, C.ink, 3, b);
      data.forEach(([nm, v, col], i) => txt(ctx, `${nm} ${Math.round((v / 30) * 100)}%`, BOX.x + 310, BOX.y + 320 + i * 42, { size: 30, color: col, alpha: b }));
    }
    if (c > 0) {
      const x0 = BOX.x + 70, yb = BOX.y + 680, temps = [22, 25, 24, 28, 30, 27, 26], days = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
      ln(ctx, [[x0, yb - 160], [x0, yb], [x0 + 500, yb]], C.ink, 3, c);
      const pts = temps.map((v, i) => [x0 + 30 + i * 72, yb - (v - 18) * 12]);
      ln(ctx, pts, C.b, 5, c);
      pts.forEach((p, i) => { if (c * 7 > i) { dot(ctx, p[0], p[1], 7, C.b); txt(ctx, days[i], p[0], yb + 30, { size: 24, align: 'center', color: C.dim }); } });
      txt(ctx, 'temperatura na semana', x0 + 250, yb - 175, { size: 28, align: 'center', color: C.b, alpha: c });
    }
  };

  FIG.meanBars = (ctx, f, E) => {
    const a = E.on(f.s[0], 1.2), lev = E.on(f.s[1], 2);
    if (a <= 0) return;
    const x0 = BOX.x + 60, yb = BOX.y + 560, k = 50;
    ln(ctx, [[x0, BOX.y + 40], [x0, yb], [x0 + 520, yb]], C.ink, 3, a);
    for (let v = 0; v <= 10; v += 2) txt(ctx, String(v), x0 - 12, yb - v * k + 8, { size: 24, align: 'right', color: C.dim, alpha: a });
    const cols = [C.p, C.b, C.y, C.g, C.o];
    f.vals.forEach((v, i) => {
      const hv = lerp(v, f.mean, ease.inOutCubic(lev)) * clamp(a * 1.6 - i * 0.12);
      G.rrect(ctx, x0 + 30 + i * 98, yb - hv * k, 70, hv * k, 4, { fill: cols[i], stroke: C.ink, lw: 2, seed: i });
      txt(ctx, fmt(hv), x0 + 65 + i * 98, yb - hv * k - 10, { size: 30, align: 'center', color: cols[i] });
    });
    if (lev > 0) { dashed(ctx, [x0, yb - f.mean * k], [x0 + 520, yb - f.mean * k], C.y, 4); txt(ctx, `média = ${f.mean}`, x0 + 260, yb + 70, { align: 'center', color: C.y, size: 46, alpha: lev }); }
  };

  FIG.freqBars = (ctx, f, E) => {
    const a = E.on(f.s[0], 1.2), h = E.on(f.s[1], 0.8);
    if (a <= 0) return;
    const n = f.data.length, x0 = BOX.x + 60, yb = BOX.y + 520, bw = Math.min(100, 480 / n), k = 120;
    ln(ctx, [[x0, BOX.y + 80], [x0, yb], [x0 + 520, yb]], C.ink, 3, a);
    f.data.forEach(([lab, v], i) => {
      const hv = v * k * clamp(a * 1.5 - i * 0.1), hl = i === f.hl && h > 0;
      G.rrect(ctx, x0 + 20 + i * (bw + 10), yb - hv, bw, hv, 4, { fill: hl ? C.y : C.b, stroke: C.ink, lw: 2, seed: i });
      txt(ctx, lab, x0 + 20 + i * (bw + 10) + bw / 2, yb + 36, { size: 32, align: 'center' });
      if (hv > 5) txt(ctx, `${v}×`, x0 + 20 + i * (bw + 10) + bw / 2, yb - hv - 12, { size: 30, align: 'center', color: hl ? C.y : C.ink });
    });
    if (h > 0) txt(ctx, 'moda!', x0 + 20 + f.hl * (bw + 10) + bw / 2, BOX.y + 40, { size: 50, align: 'center', color: C.y, alpha: h });
    txt(ctx, 'quantas vezes aparece', x0 + 260, yb + 90, { size: 30, align: 'center', color: C.dim, alpha: a });
  };

  FIG.median = (ctx, f, E) => {
    const vals = [7, 2, 9, 4, 5], sorted = [2, 4, 5, 7, 9];
    const a = E.on(f.s[0], 1), b = E.on(f.s[1], 1.6), c = E.on(f.s[2], 1.2);
    const y = BOX.y + 120, gap = 108, x0 = BOX.x + 80;
    if (a > 0) vals.forEach((v, i) => {
      const j = sorted.indexOf(v), x = lerp(x0 + i * gap, x0 + j * gap, ease.inOutCubic(b)), yy = y - Math.sin(PI * b) * 60 * (i % 2 ? 1 : -1);
      const hl = b >= 1 && j === 2;
      G.rrect(ctx, x - 40, yy - 40, 80, 80, 14, { fill: hl ? C.y : '#4A6A58', stroke: C.ink, lw: 3, alpha: a, seed: i });
      txt(ctx, String(v), x, yy + 16, { align: 'center', size: 46, color: hl ? '#20302A' : C.ink, alpha: a });
    });
    if (b >= 1) { arrow(ctx, [x0 + 2 * gap, y + 150], [x0 + 2 * gap, y + 55], C.y, 4); txt(ctx, 'mediana = 5', x0 + 2 * gap, y + 200, { align: 'center', color: C.y, size: 42 }); }
    if (c > 0) {
      const v2 = [3, 4, 6, 8, 10, 12], y2 = BOX.y + 470, g2 = 92;
      v2.forEach((v, i) => { const hl = i === 2 || i === 3; G.rrect(ctx, BOX.x + 40 + i * g2, y2 - 36, 74, 72, 12, { fill: hl ? C.y : '#4A6A58', stroke: C.ink, lw: 3, alpha: c, seed: 20 + i }); txt(ctx, String(v), BOX.x + 77 + i * g2, y2 + 14, { align: 'center', size: 40, color: hl ? '#20302A' : C.ink, alpha: c }); });
      txt(ctx, '(6 + 8) ÷ 2 = 7', CX, y2 + 110, { align: 'center', color: C.y, size: 46, alpha: c });
    }
  };

  FIG.temps = (ctx, f, E) => {
    const a = E.on(f.s[0], 1.2), b = E.on(f.s[1], 1);
    if (a <= 0) return;
    const x0 = BOX.x + 70, yb = BOX.y + 540, k = 14, mx = Math.max(...f.vals), mn = Math.min(...f.vals);
    f.vals.forEach((v, i) => {
      const x = x0 + i * 110, hv = v * k * clamp(a * 1.5 - i * 0.1);
      G.rrect(ctx, x, yb - 32 * k, 36, 32 * k, 18, { stroke: C.ink, lw: 3, seed: i, alpha: a });
      const col = b > 0 && v === mx ? C.p : b > 0 && v === mn ? C.b : C.o;
      G.rrect(ctx, x + 8, yb - hv, 20, hv, 10, { fill: col, stroke: null, lw: 0, seed: 10 + i });
      dot(ctx, x + 18, yb + 16, 24, col);
      txt(ctx, `${v}°`, x + 18, yb + 80, { size: 34, align: 'center', color: col, alpha: a });
    });
    if (b > 0) txt(ctx, `${mx} − ${mn} = ${mx - mn}°`, CX, BOX.y + 60, { align: 'center', color: C.y, size: 50, alpha: b });
  };

  FIG.probBar = (ctx, f, E) => {
    const a = clamp(E.t / 1.2), x0 = BOX.x + 40, x1 = BOX.x + 560, y = CY;
    const g = ctx.createLinearGradient(x0, 0, x1, 0); g.addColorStop(0, C.p); g.addColorStop(0.5, C.y); g.addColorStop(1, C.g);
    ctx.save(); ctx.globalAlpha *= 0.6 * a; ctx.fillStyle = g; ctx.fillRect(x0, y - 18, (x1 - x0) * a, 36); ctx.restore();
    ln(ctx, closed([[x0, y - 18], [x1, y - 18], [x1, y + 18], [x0, y + 18]]), C.ink, 3, a);
    [[0, '0', '0%'], [0.5, '1/2', '50%'], [1, '1', '100%']].forEach(([p, l1, l2]) => { txt(ctx, l1, lerp(x0, x1, p), y + 70, { align: 'center', size: 40, alpha: a }); txt(ctx, l2, lerp(x0, x1, p), y + 112, { align: 'center', size: 32, color: C.dim, alpha: a }); });
    if (!f.marks) {
      const k = E.on(f.s[0]);
      txt(ctx, 'nunca', x0, y - 50, { align: 'center', color: C.p, alpha: k }); txt(ctx, 'sempre', x1, y - 50, { align: 'center', color: C.g, alpha: k });
      return;
    }
    const pin = (p, k, lab, col, up) => { if (k <= 0) return; const x = lerp(x0, x1, p); arrow(ctx, [x, y - 140 * (up ? 1 : 0) - 60], [x, y - 24], col, 4, k); txt(ctx, lab, x, y - (up ? 210 : 72), { align: 'center', color: col, size: 34, alpha: k }); };
    pin(0, E.on(f.s[0]), 'impossível', C.p, false);
    pin(1, E.on(f.s[1]), 'certo', C.g, false);
    pin(1 / 6, E.on(f.s[2]), 'possível (1/6)', C.y, true);
  };

  function die(ctx, x, y, s, n, o = {}) {
    G.rrect(ctx, x - s / 2, y - s / 2, s, s, s * 0.18, { fill: o.fill || '#F4EFE2', stroke: o.stroke || C.ink, lw: o.lw || 3, seed: n, alpha: o.alpha ?? 1 });
    const P = { 1: [[0, 0]], 2: [[-1, -1], [1, 1]], 3: [[-1, -1], [0, 0], [1, 1]], 4: [[-1, -1], [1, -1], [-1, 1], [1, 1]], 5: [[-1, -1], [1, -1], [0, 0], [-1, 1], [1, 1]], 6: [[-1, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [1, 1]] }[n];
    ctx.save(); ctx.globalAlpha *= o.alpha ?? 1; ctx.fillStyle = '#1F2A24';
    for (const [a, b] of P) { ctx.beginPath(); ctx.arc(x + a * s * 0.26, y + b * s * 0.26, s * 0.085, 0, TAU); ctx.fill(); }
    ctx.restore();
  }
  FIG.coinDice = (ctx, f, E) => {
    if (!f.noCoin) {
      const a = E.on(f.s[0], 1);
      if (a > 0) {
        const flip = Math.abs(Math.cos(E.t * 3)), cx = BOX.x + 170, cy = BOX.y + 120;
        G.ellipse(ctx, cx, cy, 80 * Math.max(0.08, flip), 80, { fill: '#E8C35A', stroke: '#9C7A20', lw: 5, alpha: a, seed: 3 });
        txt(ctx, 'cara  ou  coroa', BOX.x + 300, cy + 14, { size: 40, alpha: a, color: C.y });
      }
    }
    const d = E.on(f.s[1], 1.2);
    const h1 = E.on(f.s[2], 0.6), h2 = f.s[3] !== undefined ? E.on(f.s[3], 0.6) : 0;
    for (let n = 1; n <= 6; n++) {
      const x = BOX.x + 110 + ((n - 1) % 3) * 190, y = BOX.y + (f.noCoin ? 200 : 360) + Math.floor((n - 1) / 3) * 190;
      const q = clamp(d * 6 - (n - 1)); if (q <= 0) continue;
      const isH1 = f.hl && f.hl.includes(n) && h1 > 0 && !(h2 > 0), isH2 = f.hl2 && f.hl2.includes(n) && h2 > 0;
      die(ctx, x, y - (1 - q) * 40, 130, n, { alpha: q, stroke: isH1 ? C.y : isH2 ? C.g : C.ink, lw: isH1 || isH2 ? 8 : 3 });
    }
    if (h1 > 0 && !(h2 > 0) && f.hl) txt(ctx, `${f.hl.length} de 6`, CX, BOX.y + BOX.h, { align: 'center', size: 48, color: C.y, alpha: h1 });
    if (h2 > 0) txt(ctx, `${f.hl2.length} de 6`, CX, BOX.y + BOX.h, { align: 'center', size: 48, color: C.g, alpha: h2 });
  };

  FIG.fracPie = (ctx, f, E) => {
    f.fr.forEach(([n, d], i) => {
      const a = E.on(f.s[i], 1.2); if (a <= 0) return;
      const cx = BOX.x + 130, cy = BOX.y + 110 + i * 240, r = 95;
      for (let j = 0; j < d; j++) {
        const a0 = -PI / 2 + (j * TAU) / d, a1 = a0 + TAU / d;
        if (j < n) { const q = clamp(a * d - j); ctx.save(); ctx.globalAlpha *= 0.7 * q; ctx.fillStyle = C.o; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.arc(cx, cy, r, a0, a1); ctx.closePath(); ctx.fill(); ctx.restore(); }
        ln(ctx, [[cx, cy], [cx + r * Math.cos(a0), cy + r * Math.sin(a0)]], C.ink, 3, a);
      }
      arc(ctx, cx, cy, r, 0, TAU, C.ink, 4, a);
      const pct = Math.round((n / d) * 1000) / 10;
      txt(ctx, `${n}/${d} = ${fmt(n / d)} = ${fmt(pct)}%`, BOX.x + 260, cy + 14, { size: 40, color: C.y, alpha: a });
    });
  };

  FIG.urn = (ctx, f, E) => {
    const a = clamp(E.t / 1), cx = CX, cy = CY + 20;
    G.poly(ctx, [[cx - 160, cy - 200], [cx + 160, cy - 200], [cx + 200, cy + 200], [cx - 200, cy + 200]], { fill: 'rgba(158,216,255,0.15)', stroke: C.ink, lw: 5, alpha: a, seed: 3 });
    const h1 = E.on(f.s[1], 0.6), h2 = E.on(f.s[2], 0.6);
    const balls = []; for (let i = 0; i < f.red; i++) balls.push('r'); for (let i = 0; i < f.blue; i++) balls.push('b');
    balls.forEach((k, i) => {
      const x = cx - 120 + (i % 4) * 80 + (Math.floor(i / 4) % 2) * 30, y = cy + 140 - Math.floor(i / 4) * 80;
      const glow = (k === 'r' && h1 > 0 && h2 <= 0) || (k === 'b' && h2 > 0);
      G.ellipse(ctx, x, y, 34, 34, { fill: k === 'r' ? '#E05555' : '#4F8FE0', stroke: glow ? C.y : C.ink, lw: glow ? 7 : 3, alpha: a, seed: i });
    });
    if (h1 > 0 && h2 <= 0) txt(ctx, `vermelhas: ${f.red} de ${f.red + f.blue}`, cx, cy - 240, { align: 'center', color: '#FF8A8A', alpha: h1 });
    if (h2 > 0) txt(ctx, `azuis: ${f.blue} de ${f.red + f.blue}`, cx, cy - 240, { align: 'center', color: C.b, alpha: h2 });
  };

  FIG.diceGrid = (ctx, f, E) => {
    const a = E.on(f.s[0], 2.5), b = E.on(f.s[1], 1);
    if (a <= 0) return;
    const k = 76, x0 = BOX.x + 90, y0 = BOX.y + 110;
    for (let i = 1; i <= 6; i++) { txt(ctx, String(i), x0 + (i - 0.5) * k, y0 - 18, { align: 'center', color: C.b, size: 34, alpha: a }); txt(ctx, String(i), x0 - 28, y0 + (i - 0.5) * k + 12, { align: 'center', color: C.o, size: 34, alpha: a }); }
    txt(ctx, 'dado 1 →', x0 + 3 * k, y0 - 64, { align: 'center', size: 30, color: C.b, alpha: a });
    for (let r = 1; r <= 6; r++) for (let c = 1; c <= 6; c++) {
      const q = clamp(a * 36 - ((r - 1) * 6 + (c - 1))); if (q <= 0) continue;
      const hl = b > 0 && r + c === 7;
      G.rrect(ctx, x0 + (c - 1) * k + 3, y0 + (r - 1) * k + 3, k - 6, k - 6, 8, { fill: hl ? C.y : '#41604F', stroke: C.dim, lw: 2, alpha: q, seed: r * 7 + c });
      txt(ctx, String(r + c), x0 + (c - 0.5) * k, y0 + (r - 0.5) * k + 12, { align: 'center', size: 32, color: hl ? '#20302A' : C.ink, alpha: q });
    }
    if (b > 0) txt(ctx, 'soma 7: 6 de 36 casas', CX, y0 + 6 * k + 70, { align: 'center', color: C.y, size: 42, alpha: b });
  };

  // =====================================================================
  // CENAS
  // =====================================================================
  function header(ctx, sc, lt, color) {
    const tag = sc.chapter > 0 && sc.chapter < 6 ? `AULA ${sc.chapter} · ${sc.chapterName}` : sc.chapter === 6 ? 'REVISÃO FINAL' : 'MATEMÁTICA · 9º ANO';
    G.decor(() => txt(ctx, tag, 110, 72, { size: 30, color: C.dim, boil: 0 }));
    const size = sc.title.length > 44 ? 50 : 62;
    const tw = meas(ctx, sc.title, size, TFAM, 700);
    ttl(ctx, sc.title, 110, 150, { size, color });
    ln(ctx, [[105, 172], [105 + Math.min(tw, 1720), 176]], color, 4, clamp(lt / 0.8), 99);
  }

  function lines(ctx, sc, lt) {
    const ls = sc.lines; const n = ls.length;
    const hasFig = !!sc.fig, maxW = hasFig ? 1080 : 1700;
    const lh = Math.min(68, 790 / Math.max(1, n));
    let y = 250;
    for (const l of ls) {
      if (l.type === 'b') { y += lh * 0.55; continue; }
      const p = clamp((lt - l.at) / l.dur);
      if (p > 0) {
        let size = (l.type === 'f' ? 46 : 42) + (sc.kind === 'ex' ? 6 : 0); if (lh < 60) size = Math.round(size * (lh / 62) + 2);
        const x = 110 + (l.type === 'e' || l.type === 't' ? 58 : 0) + (l.type === 'f' ? 22 : 0);
        let tw = meas(ctx, l.text, size); const lim = maxW - (x - 110) - 30;
        if (tw > lim) { size = Math.floor(size * lim / tw); tw = meas(ctx, l.text, size); }
        const col = { n: C.ink, f: C.y, e: C.p, t: C.b }[l.type];
        if (l.type === 'f') G.rrect(ctx, 106, y - size * 0.98, tw + 54, size * 1.42, 12, { stroke: C.y, lw: 3, seed: Math.round(l.at * 10), alpha: clamp(p * 2) * 0.9, fill: 'rgba(255,226,122,0.06)' });
        if ((l.type === 'e' || l.type === 't') && !l.cont) {
          if (l.type === 'e') { G.poly(ctx, [[108, y - 4], [130, y - 34], [152, y - 4]], { fill: C.p, stroke: C.p, lw: 2, seed: 4, alpha: clamp(p * 3) }); txt(ctx, '!', 130, y - 6, { size: 26, color: '#2E4638', align: 'center', alpha: clamp(p * 3), boil: 0 }); }
          else { G.ellipse(ctx, 130, y - 15, 15, 15, { fill: C.b, stroke: C.b, lw: 2, seed: 5, alpha: clamp(p * 3) }); txt(ctx, 'i', 130, y - 5, { size: 26, color: '#2E4638', align: 'center', alpha: clamp(p * 3), boil: 0 }); }
        }
        ctx.save();
        if (p < 1) { ctx.beginPath(); ctx.rect(x - 10, y - size * 1.3, (tw + 20) * p, size * 2); ctx.clip(); }
        txt(ctx, l.text, x, y, { size, color: col });
        ctx.restore();
        if (p < 1) { const cxp = x + tw * p; G.decor(() => dot(ctx, cxp, y - 8, 5, '#FFFFFF')); } // ponta do giz
      }
      y += lh;
    }
    return y;
  }

  function timer(ctx, sc, lt) {
    const T0 = sc.timer.t0, T1 = sc.timer.t1; if (lt < T0 - 0.2) return;
    const k = clamp((lt - T0 + 0.2) / 0.4), left = Math.max(0, Math.ceil(T1 - lt - 1e-6)), u = clamp((lt - T0) / (T1 - T0));
    const cx = sc.fig ? 300 : CX, cy = sc.fig ? 830 : 830, r = 70;
    const bx = sc.fig ? 110 : 560;
    ctx.save(); ctx.globalAlpha *= k;
    G.rrect(ctx, bx, cy - 105, sc.fig ? 1040 : 1100, 210, 26, { fill: 'rgba(0,0,0,0.18)', stroke: C.p, lw: 4, seed: 8 });
    const tx = bx + 120;
    arc(ctx, tx, cy, r, -PI / 2, -PI / 2 + TAU, C.dim, 6);
    if (u < 1) arc(ctx, tx, cy, r, -PI / 2 + TAU * u, -PI / 2 + TAU, C.p, 9);
    txt(ctx, lt >= T1 ? '✓' : String(left), tx, cy + 22, { size: 64, align: 'center', color: lt >= T1 ? C.g : C.ink, boil: 0 });
    // símbolo de pausa
    G.rrect(ctx, bx + 230, cy - 46, 22, 70, 4, { fill: C.p, stroke: null, lw: 0, seed: 2 }); G.rrect(ctx, bx + 264, cy - 46, 22, 70, 4, { fill: C.p, stroke: null, lw: 0, seed: 3 });
    txt(ctx, 'PAUSE O VÍDEO E TENTE!', bx + 320, cy - 2, { size: 54, color: C.p, fam: TFAM, weight: 700 });
    txt(ctx, sc.list ? 'Resolva no caderno. Gabarito no final.' : 'A resolução aparece em seguida.', bx + 320, cy + 50, { size: 34, color: C.ink });
    ctx.restore();
  }

  function teacher(ctx, x, y, s, t, o = {}) {
    Ch.person(ctx, Object.assign({ x, y, s, pose: 'stand', style: TEACHER, eyes: 'normal', mouth: 'smile', blink: (t % 3.7) < 0.12 ? 1 : 0 }, o));
  }

  function chapterCard(ctx, sc, lt) {
    const k = ease.outBack(clamp(lt / 0.7), 1.6);
    ctx.save(); ctx.translate(560, 330); ctx.scale(k, k);
    txt(ctx, `AULA ${sc.num}`, 0, 0, { size: 70, color: C.b, align: 'center', fam: TFAM, weight: 700 });
    if (sc.num === 6) { ctx.restore(); ctx.save(); ctx.translate(560, 330); ctx.scale(k, k); G.rrect(ctx, -210, -70, 420, 90, 12, { fill: '#2E4638', stroke: null, lw: 0, seed: 1 }); txt(ctx, 'FINAL', 0, 0, { size: 70, color: C.b, align: 'center', fam: TFAM, weight: 700 }); }
    ctx.restore();
    ttl(ctx, sc.title, 560, 450, { size: 96, align: 'center', alpha: clamp(lt / 0.6) });
    txt(ctx, sc.sub, 560, 520, { size: 44, align: 'center', color: C.ink, alpha: clamp((lt - 0.5) / 0.6) });
    sc.topics.forEach((tp, i) => {
      const a = clamp((lt - 1.4 - i * 0.55) / 0.5); if (a <= 0) return;
      dot(ctx, 300, 618 + i * 64, 8, C.y); txt(ctx, tp, 330, 630 + i * 64, { size: 40, alpha: a });
    });
    const wave = false;
    teacher(ctx, 1480, 1000, 1.45, lt, { gesture: wave ? 'wave' : 'point', eyes: 'happy', mouth: wave ? 'grin' : 'smile' });
    if (lt < 2.6) G.bubble(ctx, sc.num === 6 ? 'Hora de revisar!' : `Vamos à aula ${sc.num}!`, 1500, 300, 1470, 430, lt, 0.4, 2.6, { size: 46 });
  }

  function intro(ctx, sc, lt) {
    txt(ctx, 'MATEMÁTICA · 9º ANO', 140, 190, { size: 48, color: C.b, alpha: clamp(lt / 0.6) });
    ttl(ctx, 'Videoaula completa', 140, 320, { size: 120, alpha: clamp((lt - 0.3) / 0.6) });
    txt(ctx, 'do zero até a prova — Capítulo 15', 140, 400, { size: 52, alpha: clamp((lt - 0.8) / 0.6) });
    const items = ['Polígonos regulares', 'Áreas e volumes', 'Função quadrática', 'Estatística', 'Probabilidade'];
    items.forEach((it, i) => { const a = clamp((lt - 2 - i * 0.7) / 0.5); if (a > 0) { txt(ctx, `${i + 1}.`, 160, 520 + i * 74, { size: 48, color: C.y, alpha: a }); txt(ctx, it, 220, 520 + i * 74, { size: 48, alpha: a }); } });
    teacher(ctx, 1450, 1000, 1.55, lt, { gesture: 'thumbsUp', eyes: 'happy', mouth: 'grin' });
    G.bubble(ctx, 'Olá! Vamos aprender juntos!', 1450, 250, 1440, 380, lt, 0.8, 5.5, { size: 46 });
    G.bubble(ctx, 'Pegue lápis e caderno!', 1450, 250, 1440, 380, lt, 6, 11, { size: 46 });
  }

  function ending(ctx, sc, lt) {
    ttl(ctx, 'Bons estudos!', W / 2, 330, { size: 130, align: 'center', alpha: clamp(lt / 0.6) });
    txt(ctx, 'Reveja as partes difíceis quantas vezes precisar.', W / 2, 430, { size: 48, align: 'center', alpha: clamp((lt - 0.6) / 0.6) });
    txt(ctx, 'Errar faz parte de aprender. Você consegue!', W / 2, 500, { size: 48, align: 'center', color: C.y, alpha: clamp((lt - 1.2) / 0.6) });
    teacher(ctx, W / 2, 1010, 1.25, lt, { gesture: lt < 4 ? 'thumbsUp' : 'cheer', eyes: 'happy', mouth: 'grin' });
    G.confetti(ctx, lt, 1.5, { n: 90, seed: 7, spawn: 3 });
  }

  function progress(ctx, t) {
    G.decor(() => {
      const y = H - 18, x0 = 40, x1 = W - 40;
      ctx.save(); ctx.globalAlpha = 0.5;
      ctx.fillStyle = 'rgba(255,255,255,0.12)'; ctx.fillRect(x0, y, x1 - x0, 5);
      ctx.fillStyle = C.y; ctx.fillRect(x0, y, (x1 - x0) * (t / S.DURATION), 5);
      for (const c of S.CHAPTERS) { const x = lerp(x0, x1, c.t / S.DURATION); ctx.fillStyle = C.ink; ctx.fillRect(x - 1, y - 6, 3, 17); }
      ctx.restore();
    });
  }

  function boardFrame(ctx) { // moldura de madeira da lousa
    ctx.save(); ctx.strokeStyle = '#6B4A2B'; ctx.lineWidth = 22; ctx.strokeRect(11, 11, W - 22, H - 22);
    ctx.strokeStyle = 'rgba(0,0,0,0.35)'; ctx.lineWidth = 3; ctx.strokeRect(22, 22, W - 44, H - 44); ctx.restore();
  }

  function drawScene(ctx, sc, lt) {
    if (sc.kind === 'intro') return intro(ctx, sc, lt);
    if (sc.kind === 'chapter') return chapterCard(ctx, sc, lt);
    if (sc.kind === 'end') return ending(ctx, sc, lt);
    const col = sc.kind === 'ex' ? C.p : sc.solution ? C.g : C.y;
    header(ctx, sc, lt, col);
    lines(ctx, sc, lt);
    if (sc.fig && FIG[sc.fig.type]) {
      ctx.save();
      FIG[sc.fig.type](ctx, sc.fig, env(sc, lt));
      ctx.restore();
    }
    if (sc.timer) timer(ctx, sc, lt);
  }

  // busca binária da cena atual
  function sceneAt(t) {
    const A = S.SCENES; let lo = 0, hi = A.length - 1;
    while (lo < hi) { const m = (lo + hi + 1) >> 1; if (A[m].t0 <= t) lo = m; else hi = m - 1; }
    return A[lo];
  }

  Studio.film({
    draw(ctx, t) {
      G.bg(ctx);
      const sc = sceneAt(t), lt = t - sc.t0;
      // "apagar a lousa": a cena some nos últimos 0,3 s e a nova surge em 0,3 s
      const fin = clamp(lt / 0.3), fout = clamp((sc.t1 - t) / 0.3);
      ctx.save(); ctx.globalAlpha = Math.min(fin, fout);
      drawScene(ctx, sc, lt);
      ctx.restore();
      boardFrame(ctx);
      progress(ctx, t);
    },
    post: { grain: 0, vignette: 0.4, chalk: 0.9 },
    fadeOut: 1.2,
  });
})();

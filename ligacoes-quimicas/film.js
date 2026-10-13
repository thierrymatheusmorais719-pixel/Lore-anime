// O FILME: uma aula de Ligações Químicas desenhada a giz. Cada cena é uma função pura de t;
// os momentos vêm das falas (S.L) e dos tempos de cada palavra da narração (out/voice.json).
(function () {
  const U = globalThis.U, G = globalThis.G, Ch = globalThis.Ch, UI = globalThis.UI, Subs = globalThis.Subs, S = globalThis.SCORE, Studio = globalThis.Studio;
  const { clamp, ease, lerp } = U;
  const { L, ev, BEAT, clock } = S;
  const W = G.W, H = G.H;
  let VO = null, SUBS = [];

  // ---------- cores do giz ----------
  const INK = '#F2EEE3', DIM = 'rgba(242,238,227,0.35)', YEL = '#FFD95A', BLU = '#7FD3FF', PINK = '#FF8FB1', GRN = '#9BE38B', ORG = '#FFAA66', RED = '#FF6B6B', LIL = '#C9A7FF';
  const HAND = 'Patrick Hand', TITLE = 'Bungee', SYMF = 'Inter'; // Bungee só tem maiúsculas: símbolos químicos vão em Inter

  // ---------- tempo ----------
  const at = (id, u = 0) => L[id].t + (L[id].end - L[id].t) * u;
  const norm = (s) => String(s).toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]/g, '');
  // o instante em que a narração diz `word` na fala `id` (n-ésima vez); senão uma fração da fala
  function wt(id, word, u = 0.5, nth = 1) {
    const line = VO && VO.lines.find((l) => Math.abs(l.t - L[id].t) < 0.02);
    if (line) { let k = 0; for (const w of line.words) if (norm(w.w).startsWith(norm(word)) && ++k === nth) return w.t; }
    return at(id, u);
  }
  const fadeIn = (t, t0, d = 0.35) => clamp((t - t0) / d);
  const pop = (t, t0) => UI.pop(t, t0, 0.32, 2.4);
  // carimbo: grande no primeiro quadro (um corte limpo), de 135% para 100%
  const stamp = (t, t0) => (t < t0 ? 0 : 1 + 0.35 * (1 - ease.outCubic(clamp((t - t0) / 0.22))));
  const talk = (t) => { const m = VO ? Subs.mouth(VO, t, 'narrator') : null; return m && m.talking ? m : 'smile'; };

  // ---------- texto ----------
  const txt = (ctx, s, x, y, o = {}) => G.text(ctx, s, x, y, { fam: HAND, weight: 400, size: 46, color: INK, ...o });
  // fórmulas químicas: "Al_2O_3", "Na^{+}", "e^{-}" (índices e cargas desenhados à mão, sem depender da fonte)
  function chemRuns(str) {
    const out = []; const re = /_(\d+)|\^\{([^}]*)\}|\^(\S)|([^_^]+)/g; let mm;
    while ((mm = re.exec(str))) {
      if (mm[1]) out.push({ s: mm[1], k: 'sub' });
      else if (mm[2] !== undefined || mm[3]) out.push({ s: (mm[2] ?? mm[3]).replace(/-/g, '−'), k: 'sup' });
      else out.push({ s: mm[4], k: 'n' });
    }
    return out;
  }
  function chemW(ctx, str, size, fam, weight) {
    return chemRuns(str).reduce((a, r) => a + G.measure(ctx, r.s, r.k === 'n' ? size : size * 0.62, fam, weight), 0);
  }
  function chem(ctx, str, x, y, o = {}) {
    const { size = 46, fam = HAND, weight = 400, align = 'left', color = INK, alpha = 1, stroke, strokeW } = o;
    const w = chemW(ctx, str, size, fam, weight);
    let cx = align === 'center' ? x - w / 2 : align === 'right' ? x - w : x;
    for (const r of chemRuns(str)) {
      const sz = r.k === 'n' ? size : size * 0.62;
      const dy = r.k === 'sub' ? size * 0.22 : r.k === 'sup' ? -size * 0.42 : 0;
      G.text(ctx, r.s, cx, y + dy, { size: sz, fam, weight, color, alpha, stroke, strokeW, boil: 0.5 });
      cx += G.measure(ctx, r.s, sz, fam, weight);
    }
    return w;
  }
  // um título carimbado com sombra
  function bigTitle(ctx, t, t0, str, sub, color, y = 380) {
    const k = stamp(t, t0); if (k <= 0) return;
    ctx.save(); ctx.translate(W / 2, y); ctx.scale(k, k); ctx.rotate(-0.025);
    G.text(ctx, str, 0, 0, { size: 128, fam: TITLE, weight: 400, align: 'center', color, stroke: '#1C2A22', strokeW: 14 });
    ctx.restore();
    if (sub) chem(ctx, sub, W / 2, y + 110, { size: 64, align: 'center', alpha: fadeIn(t, t0 + 0.35) });
  }
  const heading = (ctx, t, t0, str, color = YEL, y = 120) => { const p = pop(t, t0); if (p <= 0) return; ctx.save(); ctx.translate(W / 2, y); ctx.scale(p, p); G.text(ctx, str, 0, 0, { size: 72, fam: TITLE, weight: 400, align: 'center', color }); ctx.restore(); };
  function underline(ctx, x0, x1, y, t, t0, color = YEL, seed = 1) { const u = ease.outCubic(fadeIn(t, t0, 0.45)); if (u <= 0) return; G.line(ctx, [[x0, y], [lerp(x0, x1, u), y + 4]], { color, lw: 5, seed }); }
  function arrow(ctx, pts, color = INK, lw = 5, seed = 3, u = 1) {
    if (u <= 0) return;
    const n = Math.max(2, Math.round(pts.length * u)); const p = pts.slice(0, n);
    G.line(ctx, p, { color, lw, seed });
    const [a, b] = [p[p.length - 2], p[p.length - 1]]; const ang = Math.atan2(b[1] - a[1], b[0] - a[0]);
    G.line(ctx, [[b[0] - 24 * Math.cos(ang - 0.45), b[1] - 24 * Math.sin(ang - 0.45)], b, [b[0] - 24 * Math.cos(ang + 0.45), b[1] - 24 * Math.sin(ang + 0.45)]], { color, lw, seed: seed + 1 });
  }
  const curve = (x0, y0, x1, y1, bend, n = 30) => Array.from({ length: n + 1 }, (_, i) => { const u = i / n; return [lerp(x0, x1, u), lerp(y0, y1, u) - Math.sin(Math.PI * u) * bend]; });
  // marcas de lista: ✓ verde, ✗ vermelho, ⚡ amarelo
  function mark(ctx, kind, x, y, p) {
    if (p <= 0) return;
    if (kind === 'ok') G.line(ctx, [[x - 18, y], [x - 18 + 14 * Math.min(1, p * 2), y + 14 * Math.min(1, p * 2)], ...(p > 0.5 ? [[x - 4 + 30 * (p - 0.5) * 2, y + 14 - 34 * (p - 0.5) * 2]] : [])], { color: GRN, lw: 7, seed: 11 });
    else if (kind === 'no') { G.line(ctx, [[x - 16, y - 16], [x - 16 + 32 * Math.min(1, p * 2), y - 16 + 32 * Math.min(1, p * 2)]], { color: RED, lw: 7, seed: 12 }); if (p > 0.5) G.line(ctx, [[x + 16, y - 16], [x + 16 - 32 * (p - 0.5) * 2, y - 16 + 32 * (p - 0.5) * 2]], { color: RED, lw: 7, seed: 13 }); }
    else if (kind === 'bolt') { ctx.save(); ctx.globalAlpha *= p; bolt(ctx, x, y, 0.55); ctx.restore(); }
  }
  function bolt(ctx, x, y, s = 1, color = YEL) { G.poly(ctx, [[x + 10 * s, y - 50 * s], [x - 22 * s, y + 6 * s], [x - 2 * s, y + 6 * s], [x - 12 * s, y + 50 * s], [x + 24 * s, y - 8 * s], [x + 2 * s, y - 8 * s]], { fill: color, lw: 3, seed: 21 }); }
  // uma lista: [{ at, text, kind }]
  function list(ctx, t, items, x, y, step = 84, size = 46) {
    items.forEach((it, i) => {
      const p = fadeIn(t, it.at, 0.3); if (p <= 0) return;
      const yy = y + i * step;
      mark(ctx, it.kind || 'ok', x + 20, yy - 14, clamp((t - it.at) / 0.35));
      ctx.save(); ctx.globalAlpha *= p; ctx.translate(30 * (1 - ease.outCubic(p)), 0);
      chem(ctx, it.text, x + 70, yy, { size, color: it.color || INK });
      ctx.restore();
    });
  }

  // ---------- átomos (modelo de Bohr, em giz) ----------
  function eDot(ctx, x, y, color = PINK, r = 10, glow = 0) {
    if (glow > 0) { ctx.save(); ctx.globalAlpha *= 0.35 * glow; ctx.fillStyle = color; ctx.beginPath(); ctx.arc(x, y, r * 2.4, 0, Math.PI * 2); ctx.fill(); ctx.restore(); }
    ctx.fillStyle = color; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#1C2A22'; ctx.lineWidth = 2.5; ctx.stroke();
  }
  // shells: elétrons por camada; outer: { n, alpha, skip (ângulo vazio), color, glow, angles } para a última camada
  function atom(ctx, x, y, o) {
    const { sym, shells, color = YEL, t = 0, r = 40, gap = 42, seed = 1, outer = {}, s = 1, alpha = 1, symSize } = o;
    ctx.save(); ctx.globalAlpha *= alpha; ctx.translate(x, y); ctx.scale(s, s);
    shells.forEach((n, k) => {
      const last = k === shells.length - 1;
      const R = r + gap * (k + 1);
      const a = last && outer.alpha !== undefined ? outer.alpha : 1;
      if (a <= 0) return;
      ctx.save(); ctx.globalAlpha *= a;
      G.ellipse(ctx, 0, 0, R, R, { fill: null, stroke: last && outer.ring ? outer.ring : DIM, lw: 2.5, seed: seed + k * 7 });
      const count = last && outer.n !== undefined ? outer.n : n;
      for (let i = 0; i < count; i++) {
        let ang;
        if (last && outer.angles) ang = outer.angles[i];
        else if (last && outer.fixed) ang = (outer.fixed0 || 0) + (Math.PI * 2 * (i + (outer.skip ? 1 : 0))) / (count + (outer.skip ? 1 : 0));
        else ang = (Math.PI * 2 * i) / n + t * 0.5 * (k % 2 ? -1 : 1) / (k + 1) + k * 0.4;
        const hl = last && outer.hl ? outer.hl(i) : 0;
        eDot(ctx, Math.cos(ang) * R, Math.sin(ang) * R, last && outer.color ? outer.color : PINK, 10 + 4 * hl, hl + (last && outer.glow ? outer.glow : 0));
      }
      ctx.restore();
    });
    G.ellipse(ctx, 0, 0, r, r, { fill: color, lw: 4, seed: seed + 99 });
    G.text(ctx, sym, 0, (symSize || r * 0.95) * 0.36, { size: symSize || r * 0.95, fam: SYMF, weight: 800, align: 'center', color: '#1C2A22', boil: 0.3 });
    ctx.restore();
  }
  const shellR = (r, gap, k) => r + gap * (k + 1);

  // ---------- Lewis: símbolo + pares ----------
  function dots(ctx, x, y, dir, n = 2, color = PINK, sep = 13) { // um par (ou elétron) ao lado de (x, y)
    const px = dir === 'up' || dir === 'down' ? 1 : 0, py = 1 - px;
    for (let i = 0; i < n; i++) { const o = (i - (n - 1) / 2) * sep; eDot(ctx, x + px * o, y + py * o, color, 7); }
  }
  function sym(ctx, s, x, y, color = INK, size = 92) { G.text(ctx, s, x, y + size * 0.34, { size, fam: SYMF, weight: 800, align: 'center', color, boil: 0.4 }); }
  // ligação: n traços entre dois pontos
  function bond(ctx, x0, y0, x1, y1, n, color = INK, u = 1, seed = 5) {
    if (u <= 0) return;
    const ang = Math.atan2(y1 - y0, x1 - x0), nx = -Math.sin(ang), ny = Math.cos(ang);
    for (let i = 0; i < n; i++) { const o = (i - (n - 1) / 2) * 16; G.line(ctx, [[x0 + nx * o, y0 + ny * o], [lerp(x0, x1, u) + nx * o, lerp(y0, y1, u) + ny * o]], { color, lw: 6, seed: seed + i }); }
  }
  // par compartilhado (Lewis) entre dois átomos: k pares lado a lado
  function sharedPairs(ctx, x, y, k, vertical = false, color = PINK) {
    for (let j = 0; j < k; j++) { const o = (j - (k - 1) / 2) * 20; if (vertical) dots(ctx, x, y + o, 'up', 2, color); else dots(ctx, x + o, y, 'left', 2, color); }
  }

  // ---------- quadro: moldura + decoração ----------
  function board(ctx) {
    G.bg(ctx);
    G.decor(() => {
      G.line(ctx, [[0, H - 24], [W, H - 24]], { color: 'rgba(140,100,60,0.9)', lw: 26, seed: 900 });
    });
  }
  // fórmulas de fundo (bem apagadas), para dar textura de sala de aula
  const DOODLES = [['H_2O', 150, 140], ['NaCl', 1760, 170], ['CO_2', 1700, 820], ['O_2', 140, 830], ['e^{-}', 980, 70], ['N_2', 1820, 520], ['Fe', 90, 480]];
  function doodles(ctx) { G.decor(() => DOODLES.forEach(([s, x, y], i) => chem(ctx, s, x, y, { size: 44, color: 'rgba(242,238,227,0.08)', align: 'center' }))); }

  // =================================================================================================
  // CENAS
  // =================================================================================================
  function intro(ctx, t) {
    doodles(ctx);
    const t0 = S.S.intro[0];
    // átomos girando em volta do título
    atom(ctx, 330, 330, { sym: 'Na', shells: [2, 8, 1], color: YEL, t, r: 34, gap: 30, seed: 3, s: pop(t, t0 + 0.5) });
    atom(ctx, 1590, 300, { sym: 'O', shells: [2, 6], color: BLU, t, r: 34, gap: 34, seed: 7, s: pop(t, t0 + 0.8) });
    const k = stamp(t, t0);
    if (k > 0) {
      ctx.save(); ctx.translate(W / 2, 330); ctx.scale(k, k); ctx.rotate(-0.03);
      G.text(ctx, 'LIGAÇÕES', 0, -40, { size: 150, fam: TITLE, weight: 400, align: 'center', color: YEL, stroke: '#1C2A22', strokeW: 16 });
      G.text(ctx, 'QUÍMICAS', 0, 120, { size: 150, fam: TITLE, weight: 400, align: 'center', color: INK, stroke: '#1C2A22', strokeW: 16 });
      ctx.restore();
    }
    txt(ctx, 'Revisão para a prova · 9º ano · 3º trimestre', W / 2, 545, { size: 50, align: 'center', alpha: fadeIn(t, t0 + 0.6) });
    // os três tipos, um por palavra
    const kinds = [['IÔNICA', ORG, 'ionica'], ['COVALENTE', BLU, 'covalente'], ['METÁLICA', YEL, 'metalica']];
    kinds.forEach(([s, c, w], i) => {
      const p = pop(t, wt('i2', w, 0.3 + i * 0.2)); if (p <= 0) return;
      const x = 540 + i * 420;
      ctx.save(); ctx.translate(x, 700); ctx.scale(p, p); ctx.rotate((i - 1) * 0.04);
      G.rrect(ctx, -185, -62, 370, 110, 22, { fill: 'rgba(0,0,0,0.25)', stroke: c, lw: 5, seed: 40 + i });
      G.text(ctx, s, 0, 18, { size: 52, fam: TITLE, weight: 400, align: 'center', color: c });
      ctx.restore();
    });
    Ch.claude(ctx, { x: 1700, y: 900, s: 0.62, eyes: t > L.i2.t ? 'happy' : 'normal', armL: 0.3 + 0.3 * Math.sin(Math.PI * clock.phase(t)), armR: 1.2, mouth: talk(t), blush: 0.4 });
  }

  function octeto(ctx, t) {
    doodles(ctx);
    if (t < L.o2.t) { // por que os átomos se ligam?
      const t0 = S.S.octeto[0];
      txt(ctx, 'Por que os átomos se ligam?', W / 2, 220, { size: 84, align: 'center', alpha: fadeIn(t, t0) });
      const d = 380 - 200 * ease.inOutCubic(clamp((t - L.o1.t) / (L.o1.end - L.o1.t)));
      atom(ctx, W / 2 - d, 520, { sym: '?', shells: [3], color: LIL, t, r: 36, gap: 50, seed: 5 });
      atom(ctx, W / 2 + d, 520, { sym: '?', shells: [5], color: LIL, t: t + 1, r: 36, gap: 50, seed: 9 });
      const k = stamp(t, wt('o1', 'estabilidade', 0.8));
      if (k > 0) { ctx.save(); ctx.translate(W / 2, 800); ctx.scale(k, k); G.text(ctx, 'ESTABILIDADE!', 0, 0, { size: 96, fam: TITLE, weight: 400, align: 'center', color: GRN, stroke: '#1C2A22', strokeW: 12 }); ctx.restore(); }
      return;
    }
    // o neônio: 8 elétrons na última camada
    const count = clamp((t - L.o3.t - 0.6) / 2.4) * 8;
    atom(ctx, 480, 450, {
      sym: 'Ne', shells: [2, 8], color: LIL, t, r: 52, gap: 70, seed: 15, s: pop(t, L.o2.t),
      outer: { ring: t > L.o3.t ? YEL : DIM, hl: (i) => (t > L.o3.t && i < count ? Math.max(0, 1 - (count - i - 1) * 0.5) * 0.8 : 0), glow: t > L.o3.t ? 0.6 : 0 },
    });
    txt(ctx, 'Ne · neônio (gás nobre)', 480, 760, { size: 46, align: 'center', color: LIL, alpha: fadeIn(t, L.o2.t + 0.3) });
    // coluna da direita
    chem(ctx, 'Gás nobre = estável', 920, 240, { size: 58, alpha: fadeIn(t, wt('o2', 'estaveis', 0.4)) });
    chem(ctx, '8 e^{-} na última camada', 920, 320, { size: 58, color: PINK, alpha: fadeIn(t, wt('o2', 'oito', 0.7)) });
    const k = stamp(t, L.o3.t);
    if (k > 0) { ctx.save(); ctx.translate(1300, 460); ctx.scale(k, k); ctx.rotate(-0.02); G.text(ctx, 'REGRA DO OCTETO', 0, 0, { size: 82, fam: TITLE, weight: 400, align: 'center', color: YEL, stroke: '#1C2A22', strokeW: 12 }); ctx.restore(); }
    if (t > L.o3.t + 0.6 && t < L.o4.t + 0.3) {
      const n = Math.min(8, Math.ceil(count));
      G.text(ctx, `${n}`, 1300, 610, { size: 120, fam: TITLE, weight: 400, align: 'center', color: PINK, alpha: n > 0 ? 1 : 0 });
    }
    chem(ctx, 'ligar-se para ficar com 8 e^{-}', 920, 560, { size: 48, alpha: t >= L.o4.t ? fadeIn(t, wt('o3', 'ligacoes', 0.5)) : 0 });
    chem(ctx, 'na camada de valência', 920, 620, { size: 48, alpha: t >= L.o4.t ? fadeIn(t, wt('o3', 'ligacoes', 0.5)) : 0 });
    // a exceção
    if (t >= L.o4.t) {
      const p = pop(t, L.o4.t);
      ctx.save(); ctx.translate(1300, 720); ctx.scale(p, p);
      G.rrect(ctx, -400, -70, 800, 170, 24, { fill: 'rgba(255,107,107,0.15)', stroke: RED, lw: 5, seed: 61 });
      atom(ctx, -310, 15, { sym: 'He', shells: [2], color: LIL, t, r: 26, gap: 30, seed: 63, symSize: 24 });
      G.text(ctx, 'EXCEÇÃO', -220, -15, { size: 40, fam: TITLE, weight: 400, color: RED });
      chem(ctx, 'H fica estável com 2 e^{-} (igual ao He)', -220, 50, { size: 42 });
      ctx.restore();
    }
  }

  const FAM = [['1A', 'Na', 1], ['2A', 'Mg', 2], ['3A', 'Al', 3], ['4A', 'C', 4], ['5A', 'N', 5], ['6A', 'O', 6], ['7A', 'Cl', 7], ['8A', 'Ne', 8]];
  function valencia(ctx, t) {
    doodles(ctx);
    const t0 = S.S.valencia[0];
    txt(ctx, 'Elétrons de valência = elétrons da última camada', W / 2, 110, { size: 56, align: 'center', alpha: fadeIn(t, t0) });
    underline(ctx, 420, 1500, 135, t, wt('v1', 'valencia', 0.4), PINK, 70);
    const metal = t >= L.v2.t, amet = t >= L.v3.t;
    FAM.forEach(([fam, el, n], i) => {
      const x = 205 + i * 215, y = 190;
      const p = pop(t, L.v1.t + 0.5 + i * 0.22); if (p <= 0) return;
      const tint = metal && i < 3 ? YEL : amet && i >= 4 && i <= 6 ? BLU : i === 7 ? LIL : DIM;
      ctx.save(); ctx.translate(x + 95, y + 115); ctx.scale(p, p);
      G.rrect(ctx, -95, -115, 190, 230, 18, { fill: (metal && i < 3) || (amet && i >= 4 && i <= 6) ? 'rgba(0,0,0,0.25)' : null, stroke: tint, lw: 4, seed: 80 + i });
      G.text(ctx, fam, 0, -70, { size: 38, fam: HAND, weight: 400, align: 'center', color: INK });
      G.text(ctx, el, 0, 20, { size: 64, fam: SYMF, weight: 800, align: 'center', color: tint === DIM ? INK : tint });
      chem(ctx, `${n} e^{-}`, 0, 85, { size: 42, align: 'center', color: PINK });
      ctx.restore();
    });
    if (metal) {
      const p = fadeIn(t, L.v2.t);
      G.line(ctx, [[205, 445], [205, 465], [835, 465], [835, 445]], { color: YEL, lw: 5, seed: 91, alpha: p });
      ctx.save(); ctx.globalAlpha *= p;
      G.text(ctx, 'METAIS', 520, 540, { size: 60, fam: TITLE, weight: 400, align: 'center', color: YEL });
      chem(ctx, '1 a 3 e^{-} · PERDEM elétrons', 520, 610, { size: 46, align: 'center' });
      ctx.restore();
      const q = fadeIn(t, wt('v2', 'cations', 0.75));
      ctx.save(); ctx.globalAlpha *= q; chem(ctx, 'Na → Na^{+} + e^{-}', 520, 700, { size: 58, align: 'center', color: ORG }); txt(ctx, 'cátion (íon positivo)', 520, 770, { size: 42, align: 'center', color: ORG }); ctx.restore();
    }
    if (amet) {
      const p = fadeIn(t, L.v3.t);
      G.line(ctx, [[1065, 445], [1065, 465], [1695, 465], [1695, 445]], { color: BLU, lw: 5, seed: 92, alpha: p });
      ctx.save(); ctx.globalAlpha *= p;
      G.text(ctx, 'AMETAIS', 1380, 540, { size: 60, fam: TITLE, weight: 400, align: 'center', color: BLU });
      chem(ctx, '5 a 7 e^{-} · GANHAM elétrons', 1380, 610, { size: 46, align: 'center' });
      ctx.restore();
      const q = fadeIn(t, wt('v3', 'anions', 0.75));
      ctx.save(); ctx.globalAlpha *= q; chem(ctx, 'Cl + e^{-} → Cl^{-}', 1380, 700, { size: 58, align: 'center', color: BLU }); txt(ctx, 'ânion (íon negativo)', 1380, 770, { size: 42, align: 'center', color: BLU }); ctx.restore();
    }
  }

  // ---------- ligação iônica: Na + Cl ----------
  function ionica(ctx, t) {
    doodles(ctx);
    const t0 = S.S.ionica[0];
    if (t < L.n2.t - 0.05) {
      bigTitle(ctx, t, t0, 'LIGAÇÃO IÔNICA', null, ORG, 400);
      const pm = pop(t, wt('n1', 'metal', 0.6)), pa = pop(t, wt('n1', 'ametal', 0.85));
      [[pm, 'METAL', YEL, 760], [pa, 'AMETAL', BLU, 1160]].forEach(([p, s, c, x]) => { if (p <= 0) return; ctx.save(); ctx.translate(x, 600); ctx.scale(p, p); G.rrect(ctx, -170, -60, 340, 100, 20, { fill: 'rgba(0,0,0,0.25)', stroke: c, lw: 5, seed: x }); G.text(ctx, s, 0, 12, { size: 50, fam: TITLE, weight: 400, align: 'center', color: c }); ctx.restore(); });
      if (pa > 0) G.text(ctx, '+', 960, 618, { size: 80, fam: TITLE, weight: 400, align: 'center', color: INK });
      return;
    }
    const tA = ev.transfer, tB = ev.land;
    const moved = t >= tB;
    // n5: os íons se aproximam
    const join = ease.inOutCubic(clamp((t - at('n5', 0.15)) / (ev.snapNaCl - at('n5', 0.15))));
    const naX = lerp(560, 790, join), clX = lerp(1340, 1110, join), y = 430;
    const r = 34, gap = 38;
    const naOuterA = moved ? 1 - clamp((t - tB) / 0.6) : 1;
    // sódio
    atom(ctx, naX, y, { sym: 'Na', shells: [2, 8, 1], color: YEL, t, r, gap, seed: 101, s: pop(t, L.n2.t) * (moved ? lerp(1, 0.92, clamp((t - tB) / 0.6)) : 1), outer: { n: 0, alpha: naOuterA, ring: t > wt('n2', 'um', 0.4) && !moved ? PINK : DIM } });
    // cloro: 7 elétrons fixos, com um lugar vazio à esquerda (ângulo π)
    const clR = shellR(r, gap, 2);
    atom(ctx, clX, y, { sym: 'Cl', shells: [2, 8, 7], color: BLU, t: t + 2, r, gap, seed: 131, s: pop(t, L.n2.t + 0.35) * (moved ? lerp(1, 1.06, clamp((t - tB) / 0.6)) : 1), outer: { fixed: true, skip: true, fixed0: Math.PI, ring: t > wt('n2', 'sete', 0.7) ? PINK : DIM } });
    // o elétron do sódio: espera do lado direito, voa para o cloro
    const naR = shellR(r, gap, 2);
    let ex, ey;
    if (t < tA) { const a = 0.25 * Math.sin(t * 1.3); ex = naX + Math.cos(a) * naR; ey = y + Math.sin(a) * naR; }
    else if (t < tB) { const u = ease.inOutCubic((t - tA) / (tB - tA)); const p = curve(naX + naR, y, clX - clR * 1.06, y, 160, 1); ex = lerp(p[0][0], p[1][0], u); ey = y - Math.sin(Math.PI * u) * 170; }
    else { const s = lerp(1, 1.06, clamp((t - tB) / 0.6)); ex = clX - clR * s; ey = y; }
    if (t >= tA && t < tB) { // um rastro
      for (let i = 1; i <= 6; i++) { const tt = t - i * 0.035; if (tt < tA) break; const u = ease.inOutCubic((tt - tA) / (tB - tA)); ctx.save(); ctx.globalAlpha *= 0.5 - i * 0.07; eDot(ctx, lerp(naX + naR, clX - clR * 1.06, u), y - Math.sin(Math.PI * u) * 170, PINK, 9); ctx.restore(); }
    }
    eDot(ctx, ex, ey, PINK, 12, t >= tA - 0.4 ? 1 : 0.3);
    if (t >= tA - 0.2 && t < tB + 1.2) chem(ctx, 'transfere 1 e^{-}', (naX + clX) / 2, y - 230, { size: 50, align: 'center', color: PINK, alpha: fadeIn(t, tA - 0.2) * (1 - clamp((t - tB - 0.8) / 0.4)) });
    // legendas
    const labA = 1 - clamp((t - L.n4.t) / 0.3);
    if (labA > 0) {
      ctx.save(); ctx.globalAlpha *= labA;
      txt(ctx, 'Sódio (Na) · metal', naX, 700, { size: 46, align: 'center', color: YEL, alpha: fadeIn(t, L.n2.t + 0.2) });
      chem(ctx, moved ? '2, 8, 0 → fica com 8!' : '2, 8, 1 → 1 e^{-} de valência', naX, 760, { size: 40, align: 'center', alpha: fadeIn(t, wt('n2', 'um', 0.4)) });
      txt(ctx, 'Cloro (Cl) · ametal', clX, 700, { size: 46, align: 'center', color: BLU, alpha: fadeIn(t, L.n2.t + 0.5) });
      chem(ctx, moved ? '2, 8, 8 → fica com 8!' : '2, 8, 7 → 7 e^{-} de valência', clX, 760, { size: 40, align: 'center', alpha: fadeIn(t, wt('n2', 'sete', 0.7)) });
      ctx.restore();
    }
    // n4: os íons
    if (t >= L.n4.t) {
      const pn = pop(t, wt('n4', 'cation', 0.25)), pc = pop(t, wt('n4', 'anion', 0.7));
      if (pn > 0) { ctx.save(); ctx.translate(naX, 720); ctx.scale(pn, pn); G.rrect(ctx, -150, -60, 300, 110, 22, { fill: 'rgba(0,0,0,0.3)', stroke: ORG, lw: 5, seed: 151 }); chem(ctx, 'Na^{+}', 0, 18, { size: 70, align: 'center', color: ORG, fam: SYMF, weight: 800 }); ctx.restore(); txt(ctx, 'cátion', naX, 830, { size: 40, align: 'center', color: ORG, alpha: pn > 0 ? 1 : 0 }); }
      if (pc > 0) { ctx.save(); ctx.translate(clX, 720); ctx.scale(pc, pc); G.rrect(ctx, -150, -60, 300, 110, 22, { fill: 'rgba(0,0,0,0.3)', stroke: BLU, lw: 5, seed: 152 }); chem(ctx, 'Cl^{-}', 0, 18, { size: 70, align: 'center', color: BLU, fam: SYMF, weight: 800 }); ctx.restore(); txt(ctx, 'ânion (cloreto)', clX, 830, { size: 40, align: 'center', color: BLU, alpha: pc > 0 ? 1 : 0 }); }
    }
    // n5: atração, depois NaCl
    if (t >= L.n5.t && t < ev.snapNaCl) {
      const wob = Math.sin(t * 9) * 6;
      arrow(ctx, [[naX + 130, y - 210 + wob], [(naX + clX) / 2 - 20, y - 210 + wob]], GRN, 6, 161, fadeIn(t, L.n5.t, 0.4));
      arrow(ctx, [[clX - 130, y - 210 - wob], [(naX + clX) / 2 + 20, y - 210 - wob]], GRN, 6, 163, fadeIn(t, L.n5.t, 0.4));
      txt(ctx, 'atração eletrostática', (naX + clX) / 2, y - 260, { size: 46, align: 'center', color: GRN, alpha: fadeIn(t, wt('n5', 'atracao', 0.3)) });
    }
    if (t >= ev.snapNaCl) {
      const k = stamp(t, ev.snapNaCl);
      G.rays(ctx, W / 2, y, { n: 28, r0: 260, r1: 900, color: 'rgba(255,217,90,0.18)', lw: 14, seed: 171, spin: (t - ev.snapNaCl) * 0.15 });
      ctx.save(); ctx.translate(W / 2, 165); ctx.scale(k, k); G.text(ctx, 'NaCl', 0, 0, { size: 120, fam: SYMF, weight: 800, align: 'center', color: YEL, stroke: '#1C2A22', strokeW: 14 }); ctx.restore();
      txt(ctx, 'cloreto de sódio = sal de cozinha', W / 2, 240, { size: 50, align: 'center', alpha: fadeIn(t, ev.snapNaCl + 0.4) });
    }
  }

  function reticulo(ctx, t) {
    doodles(ctx);
    const t0 = S.S.reticulo[0];
    // o retículo: Cl⁻ grandes e Na⁺ pequenos, alternados, crescendo do centro
    const cx = 470, cy = 470, step = 92, n = 6;
    for (const layer of [1, 0]) {
      for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) {
        const x = cx + (i - (n - 1) / 2) * step + layer * 38 + Math.sin(t * 0.6) * 6 * layer, y = cy + (j - (n - 1) / 2) * step - layer * 38;
        const d = Math.hypot(i - (n - 1) / 2, j - (n - 1) / 2);
        const p = pop(t, t0 + 0.2 + d * 0.25); if (p <= 0) continue;
        const cl = (i + j + layer) % 2 === 0;
        ctx.save(); ctx.globalAlpha *= layer ? 0.35 : 1; ctx.translate(x, y); ctx.scale(p, p);
        G.ellipse(ctx, 0, 0, cl ? 36 : 22, cl ? 36 : 22, { fill: cl ? BLU : ORG, lw: 3, seed: 200 + i * 11 + j + layer * 50 });
        if (!layer) G.text(ctx, cl ? '−' : '+', 0, cl ? 12 : 10, { size: cl ? 40 : 30, fam: TITLE, weight: 400, align: 'center', color: '#1C2A22', boil: 0.2 });
        ctx.restore();
      }
    }
    G.text(ctx, 'Retículo cristalino', 1290, 150, { size: 64, fam: TITLE, weight: 400, align: 'center', color: YEL, alpha: fadeIn(t, wt('n6', 'reticulo', 0.5)) });
    chem(ctx, 'íons Na^{+} e Cl^{-} bem organizados', 1290, 225, { size: 46, align: 'center', alpha: fadeIn(t, wt('n6', 'grade', 0.85)) });
    list(ctx, t, [
      { at: wt('n7', 'solidos', 0.35), text: 'Sólidos a 25 °C' },
      { at: wt('n7', 'fusao', 0.7), text: 'Pontos de fusão e ebulição ALTOS' },
      { at: wt('n8', 'duros', 0.05), text: 'Duros, mas quebradiços' },
      { at: wt('n8', 'conduzem', 0.3), text: 'Conduzem: fundidos ou em água', kind: 'bolt', color: YEL },
      { at: wt('n8', 'solido', 0.8), text: 'Sólidos: NÃO conduzem', kind: 'no', color: RED },
    ], 930, 360, 92, 48);
  }

  function formula(ctx, t) {
    doodles(ctx);
    const t0 = S.S.formula[0];
    heading(ctx, t, t0, 'DICA: MONTANDO A FÓRMULA', YEL, 130);
    txt(ctx, 'a carga de um vira o índice do outro', W / 2, 225, { size: 56, align: 'center', alpha: fadeIn(t, wt('f1', 'carga', 0.3)) });
    const pa = pop(t, wt('f2', 'aluminio', 0.05)), po = pop(t, wt('f2', 'oxigenio', 0.3));
    if (pa > 0) { ctx.save(); ctx.translate(720, 470); ctx.scale(pa, pa); chem(ctx, 'Al^{3+}', 0, 0, { size: 150, fam: SYMF, weight: 800, align: 'center', color: YEL }); ctx.restore(); }
    if (po > 0) { ctx.save(); ctx.translate(1200, 470); ctx.scale(po, po); chem(ctx, 'O^{2-}', 0, 0, { size: 150, fam: SYMF, weight: 800, align: 'center', color: BLU }); ctx.restore(); }
    // as setas em X: o 3 vai para o oxigênio, o 2 vai para o alumínio
    const a1 = wt('f2', 'tres', 0.55, 2), a2 = wt('f2', 'dois', 0.8, 2);
    arrow(ctx, curve(800, 360, 1270, 600, -60), ORG, 6, 301, ease.outCubic(fadeIn(t, a1, 0.7)));
    arrow(ctx, curve(1280, 360, 800, 600, -60), ORG, 6, 305, ease.outCubic(fadeIn(t, a2, 0.7)));
    if (t >= ev.f3) {
      const k = stamp(t, ev.f3);
      ctx.save(); ctx.translate(W / 2, 720); ctx.scale(k, k);
      G.rrect(ctx, -260, -105, 520, 150, 26, { fill: 'rgba(155,227,139,0.15)', stroke: GRN, lw: 6, seed: 311 });
      chem(ctx, 'Al_2O_3', 0, 18, { size: 130, fam: SYMF, weight: 800, align: 'center', color: GRN });
      ctx.restore();
      txt(ctx, '2 × (+3) = +6     3 × (−2) = −6     total = 0 ✓', W / 2, 850, { size: 40, align: 'center', color: INK, alpha: fadeIn(t, ev.f3 + 0.9) });
    }
  }

  // ---------- ligação covalente ----------
  const ROWS = [
    { id: 'c3', name: 'H_2', what: 'gás hidrogênio', el: 'H', n: 1, kind: 'SIMPLES', lone: 0 },
    { id: 'c4', name: 'O_2', what: 'gás oxigênio', el: 'O', n: 2, kind: 'DUPLA', lone: 2 },
    { id: 'c5', name: 'N_2', what: 'gás nitrogênio', el: 'N', n: 3, kind: 'TRIPLA', lone: 1 },
  ];
  function covalente(ctx, t) {
    doodles(ctx);
    const t0 = S.S.covalente[0];
    if (t < L.c2.t - 0.05) {
      bigTitle(ctx, t, t0, 'LIGAÇÃO COVALENTE', null, BLU, 400);
      const p = pop(t, wt('c1', 'ametais', 0.5)), q = pop(t, wt('c1', 'hidrogenio', 0.9));
      if (p > 0) { ctx.save(); ctx.translate(W / 2, 600); ctx.scale(p, p); G.rrect(ctx, -330, -60, 660, 100, 20, { fill: 'rgba(0,0,0,0.25)', stroke: BLU, lw: 5, seed: 401 }); G.text(ctx, 'AMETAL + AMETAL', 0, 12, { size: 50, fam: TITLE, weight: 400, align: 'center', color: BLU }); ctx.restore(); }
      if (q > 0) txt(ctx, '(ou ametal + hidrogênio)', W / 2, 720, { size: 50, align: 'center', alpha: q });
      return;
    }
    if (t < L.c3.t - 0.05) { // compartilhar: duas camadas se sobrepõem, o par fica no meio
      txt(ctx, 'ninguém perde, ninguém ganha:', W / 2, 180, { size: 58, align: 'center', alpha: fadeIn(t, L.c2.t) });
      const k = stamp(t, wt('c2', 'compartilham', 0.6));
      if (k > 0) { ctx.save(); ctx.translate(W / 2, 290); ctx.scale(k, k); G.text(ctx, 'COMPARTILHAM!', 0, 0, { size: 96, fam: TITLE, weight: 400, align: 'center', color: PINK, stroke: '#1C2A22', strokeW: 12 }); ctx.restore(); }
      const close = ease.inOutCubic(clamp((t - L.c2.t - 0.3) / 2));
      const d = lerp(300, 150, close), y = 600;
      [-1, 1].forEach((s) => { G.ellipse(ctx, W / 2 + s * d / 2 + s * 0, y, 150, 150, { fill: null, stroke: DIM, lw: 3, seed: 410 + s }); G.ellipse(ctx, W / 2 + s * d, y, 44, 44, { fill: BLU, lw: 4, seed: 415 + s }); });
      // os dois elétrons vão para a região compartilhada
      const sh = clamp((t - L.c2.t - 1.2) / 1.2);
      [-1, 1].forEach((s) => { const ex = lerp(W / 2 + s * d + s * 150, W / 2, ease.inOutCubic(sh)), ey = lerp(y, y + s * 22, sh); eDot(ctx, ex, ey, PINK, 12, sh); });
      if (sh >= 1) txt(ctx, 'par compartilhado', W / 2, 820, { size: 50, align: 'center', color: PINK, alpha: fadeIn(t, L.c2.t + 2.4) });
      return;
    }
    // a tabela: Lewis · estrutural · tipo
    const hdr = fadeIn(t, L.c3.t);
    ctx.save(); ctx.globalAlpha *= hdr;
    [['molécula', 270], ['eletrônica (Lewis)', 770], ['estrutural', 1220], ['ligação', 1630]].forEach(([s, x]) => txt(ctx, s, x, 150, { size: 44, align: 'center', color: YEL }));
    G.line(ctx, [[110, 180], [1810, 182]], { color: DIM, lw: 3, seed: 420 });
    ctx.restore();
    ROWS.forEach((r, i) => {
      const t1 = L[r.id].t; if (t < t1) return;
      const y = 300 + i * 200, p = pop(t, t1);
      ctx.save(); ctx.globalAlpha *= clamp(p);
      chem(ctx, r.name, 270, y + 20, { size: 84, fam: SYMF, weight: 800, align: 'center', color: BLU });
      txt(ctx, r.what, 270, y + 75, { size: 36, align: 'center' });
      // Lewis
      const lp = fadeIn(t, t1 + 0.6, 0.4);
      ctx.save(); ctx.globalAlpha *= lp;
      sym(ctx, r.el, 690, y, INK, 80); sym(ctx, r.el, 850, y, INK, 80);
      sharedPairs(ctx, 770, y, r.n, false);
      if (r.lone === 2) { [690, 850].forEach((x) => { dots(ctx, x, y - 62, 'up'); dots(ctx, x, y + 62, 'up'); }); }
      if (r.lone === 1) { dots(ctx, 690 - 62, y, 'left'); dots(ctx, 850 + 62, y, 'left'); }
      ctx.restore();
      // estrutural
      const sp = fadeIn(t, wt(r.id, 'par', 0.6), 0.5);
      if (sp > 0) { sym(ctx, r.el, 1130, y, INK, 80); sym(ctx, r.el, 1310, y, INK, 80); bond(ctx, 1170, y, 1270, y, r.n, PINK, ease.outCubic(sp), 430 + i * 5); }
      // tipo
      const kp = pop(t, wt(r.id, ['simples', 'dupla', 'tripla'][i], 0.85));
      if (kp > 0) { ctx.save(); ctx.translate(1630, y + 5); ctx.scale(kp, kp); G.text(ctx, r.kind, 0, 10, { size: 52, fam: TITLE, weight: 400, align: 'center', color: [GRN, YEL, ORG][i] }); txt(ctx, `${r.n} par${r.n > 1 ? 'es' : ''}`, 0, 60, { size: 38, align: 'center' }); ctx.restore(); }
      ctx.restore();
    });
  }

  function water(ctx, x, y, t, t1, s = 1) {
    const hx = 120 * s, hy = 95 * s;
    const p = fadeIn(t, t1, 0.4);
    bond(ctx, x - 30 * s, y + 25 * s, x - hx + 25 * s, y + hy - 15 * s, 1, PINK, ease.outCubic(fadeIn(t, t1 + 0.4, 0.5)), 501);
    bond(ctx, x + 30 * s, y + 25 * s, x + hx - 25 * s, y + hy - 15 * s, 1, PINK, ease.outCubic(fadeIn(t, t1 + 0.6, 0.5)), 503);
    ctx.save(); ctx.globalAlpha *= p;
    sym(ctx, 'O', x, y, BLU, 90 * s); sym(ctx, 'H', x - hx, y + hy, INK, 80 * s); sym(ctx, 'H', x + hx, y + hy, INK, 80 * s);
    dots(ctx, x - 30 * s, y - 62 * s, 'up'); dots(ctx, x + 30 * s, y - 62 * s, 'up');
    ctx.restore();
  }
  function moleculas(ctx, t) {
    doodles(ctx);
    const t0 = S.S.moleculas[0];
    G.line(ctx, [[960, 170], [962, 800]], { color: DIM, lw: 3, seed: 510 });
    // água
    chem(ctx, 'H_2O · água', 480, 170, { size: 66, fam: SYMF, weight: 800, align: 'center', color: BLU, alpha: fadeIn(t, t0) });
    water(ctx, 480, 380, t, L.c6.t, 1.5);
    chem(ctx, 'O: 6 e^{-} de valência', 480, 680, { size: 46, align: 'center', alpha: fadeIn(t, wt('c6', 'seis', 0.3)) });
    txt(ctx, '→ 2 ligações simples', 480, 745, { size: 46, align: 'center', color: GRN, alpha: fadeIn(t, wt('c6', 'duas', 0.6)) });
    // gás carbônico
    if (t >= L.c7.t - 0.1) {
      chem(ctx, 'CO_2 · gás carbônico', 1440, 170, { size: 66, fam: SYMF, weight: 800, align: 'center', color: BLU, alpha: fadeIn(t, L.c7.t - 0.1) });
      const y = 420, p = fadeIn(t, L.c7.t + 0.2);
      ctx.save(); ctx.globalAlpha *= p;
      sym(ctx, 'O', 1230, y, BLU, 90); sym(ctx, 'C', 1440, y, YEL, 90); sym(ctx, 'O', 1650, y, BLU, 90);
      [1230, 1650].forEach((x) => { dots(ctx, x, y - 65, 'up'); dots(ctx, x, y + 65, 'up'); });
      ctx.restore();
      const b = ease.outCubic(fadeIn(t, wt('c7', 'duplas', 0.75), 0.5));
      bond(ctx, 1280, y, 1390, y, 2, PINK, b, 520); bond(ctx, 1600, y, 1490, y, 2, PINK, b, 524);
      chem(ctx, 'C: 4 e^{-} de valência', 1440, 680, { size: 46, align: 'center', alpha: fadeIn(t, wt('c7', 'quatro', 0.4)) });
      txt(ctx, '→ 2 ligações duplas', 1440, 745, { size: 46, align: 'center', color: YEL, alpha: fadeIn(t, wt('c7', 'duplas', 0.75)) });
    }
  }

  function formulas(ctx, t) {
    doodles(ctx);
    const t0 = S.S.formulas[0];
    heading(ctx, t, t0, '3 JEITOS DE REPRESENTAR', YEL, 120);
    const cards = [['Eletrônica', '(de Lewis)', 'c9'], ['Estrutural', 'pares viram traços', 'c10'], ['Molecular', 'só átomos e quantidades', 'c11']];
    cards.forEach(([a, b, id], i) => {
      const x = 360 + i * 600, y = 210, p = pop(t, L.c8.t + 0.6 + i * 0.35); if (p <= 0) return;
      ctx.save(); ctx.translate(x, y + 260); ctx.scale(p, p);
      G.rrect(ctx, -270, -260, 540, 560, 26, { fill: 'rgba(0,0,0,0.22)', stroke: t >= L[id].t ? [PINK, GRN, YEL][i] : DIM, lw: 5, seed: 600 + i });
      G.text(ctx, a, 0, -185, { size: 52, fam: TITLE, weight: 400, align: 'center', color: [PINK, GRN, YEL][i] });
      txt(ctx, b, 0, -130, { size: 38, align: 'center' });
      ctx.restore();
      if (t < L[id].t) return;
      const q = fadeIn(t, L[id].t + 0.3, 0.5), cy = y + 330;
      ctx.save(); ctx.globalAlpha *= q;
      if (i === 0) { sym(ctx, 'H', x - 140, cy, INK, 72); sym(ctx, 'O', x, cy, BLU, 80); sym(ctx, 'H', x + 140, cy, INK, 72); sharedPairs(ctx, x - 72, cy, 1); sharedPairs(ctx, x + 72, cy, 1); dots(ctx, x, cy - 58, 'up'); dots(ctx, x, cy + 58, 'up'); }
      if (i === 1) { sym(ctx, 'H', x - 150, cy, INK, 72); sym(ctx, 'O', x, cy, BLU, 80); sym(ctx, 'H', x + 150, cy, INK, 72); bond(ctx, x - 110, cy, x - 45, cy, 1, GRN, 1, 611); bond(ctx, x + 45, cy, x + 110, cy, 1, GRN, 1, 613); }
      if (i === 2) chem(ctx, 'H_2O', x, cy + 40, { size: 130, fam: SYMF, weight: 800, align: 'center', color: YEL });
      ctx.restore();
    });
  }

  function covprop(ctx, t) {
    doodles(ctx);
    const t0 = S.S.covprop[0];
    heading(ctx, t, t0, 'COMPOSTOS COVALENTES', BLU, 130);
    list(ctx, t, [
      { at: wt('c12', 'moleculas', 0.1), text: 'Formam moléculas' },
      { at: wt('c12', 'solidos', 0.3), text: 'Sólidos, líquidos ou gasosos' },
      { at: wt('c12', 'fusao', 0.65), text: 'PF e PE mais BAIXOS que os iônicos' },
      { at: wt('c13', 'conduzem', 0.4), text: 'Em geral, NÃO conduzem eletricidade', kind: 'no', color: RED },
    ], 150, 300, 110, 52);
    // três estados físicos
    const s = wt('c12', 'solidos', 0.3);
    const icons = [['açúcar', 1300], ['água', 1520], ['gás O₂', 1740]];
    icons.forEach(([lab, x], i) => {
      const p = pop(t, s + i * 0.45); if (p <= 0) return;
      ctx.save(); ctx.translate(x, 330); ctx.scale(p, p);
      if (i === 0) { G.poly(ctx, [[-50, -20], [10, -50], [60, -20], [0, 10]], { fill: '#FFFFFF', lw: 3, seed: 701 }); G.poly(ctx, [[-50, -20], [0, 10], [0, 70], [-50, 40]], { fill: '#D9D4C7', lw: 3, seed: 702 }); G.poly(ctx, [[0, 10], [60, -20], [60, 40], [0, 70]], { fill: '#BDB7A8', lw: 3, seed: 703 }); }
      if (i === 1) { G.poly(ctx, [[0, -60], [40, 0], [45, 25], [25, 60], [-25, 60], [-45, 25], [-40, 0]], { fill: BLU, lw: 3, seed: 704 }); }
      if (i === 2) { for (let k = 0; k < 4; k++) G.ellipse(ctx, -40 + k * 27, 10 + Math.sin(t * 2 + k) * 8, 32, 32, { fill: 'rgba(242,238,227,0.4)', lw: 3, seed: 705 + k }); }
      ctx.restore();
      txt(ctx, lab, x, 450, { size: 38, align: 'center', alpha: clamp(p) });
    });
    txt(ctx, 'sólido · líquido · gasoso', 1520, 520, { size: 40, align: 'center', color: YEL, alpha: fadeIn(t, s + 1.2) });
  }

  // ---------- ligação metálica ----------
  const GRID = []; for (let j = 0; j < 4; j++) for (let i = 0; i < 7; i++) GRID.push([420 + i * 180 + (j % 2) * 90, 300 + j * 140]);
  function seaElectrons(ctx, t, free, n = 34, glow = 0) {
    for (let i = 0; i < n; i++) {
      const home = GRID[i % GRID.length];
      const fx = 1060 + U.noise1(t * 0.35 + i * 7.1, i) * 720, fy = 510 + U.noise1(t * 0.3 + i * 3.3, i + 50) * 300;
      const a = t * 1.5 + i;
      const bx = home[0] + Math.cos(a) * 62, by = home[1] + Math.sin(a) * 62;
      const u = ease.inOutCubic(clamp(free - (i % 7) * 0.05));
      eDot(ctx, lerp(bx, fx, u), lerp(by, fy, u), PINK, 9, glow);
    }
  }
  function cations(ctx, t, t0, freed) {
    GRID.forEach(([x, y], i) => {
      const p = pop(t, t0 + i * 0.03); if (p <= 0) return;
      ctx.save(); ctx.translate(x, y); ctx.scale(p, p);
      G.ellipse(ctx, 0, 0, 48, 48, { fill: freed ? ORG : YEL, lw: 4, seed: 800 + i });
      G.text(ctx, freed ? '+' : 'M', 0, freed ? 18 : 14, { size: freed ? 52 : 40, fam: TITLE, weight: 400, align: 'center', color: '#1C2A22', boil: 0.2 });
      ctx.restore();
    });
  }
  function metalica(ctx, t) {
    doodles(ctx);
    const t0 = S.S.metalica[0];
    if (t < L.m2.t - 0.05) {
      bigTitle(ctx, t, t0, 'LIGAÇÃO METÁLICA', null, YEL, 400);
      const p = pop(t, wt('m1', 'metais', 0.7));
      if (p > 0) { ctx.save(); ctx.translate(W / 2, 600); ctx.scale(p, p); G.rrect(ctx, -300, -60, 600, 100, 20, { fill: 'rgba(0,0,0,0.25)', stroke: YEL, lw: 5, seed: 851 }); G.text(ctx, 'METAL + METAL', 0, 12, { size: 50, fam: TITLE, weight: 400, align: 'center', color: YEL }); ctx.restore(); }
      return;
    }
    const tFree = wt('m2', 'soltam', 0.2);
    const free = clamp((t - tFree) / 1.8);
    const glow = t >= L.m3.t ? 0.5 + 0.3 * Math.sin(t * 4) : 0;
    if (t >= L.m3.t) { ctx.save(); ctx.globalAlpha *= 0.18 * fadeIn(t, L.m3.t, 0.8); ctx.fillStyle = PINK; ctx.beginPath(); ctx.roundRect(330, 210, 1440, 590, 80); ctx.fill(); ctx.restore(); }
    cations(ctx, t, L.m2.t - 0.6, free > 0.5);
    seaElectrons(ctx, t, free, 34, glow);
    txt(ctx, free > 0.5 ? 'cátions metálicos  +  elétrons livres' : 'átomos de metal', W / 2, 150, { size: 54, align: 'center', color: free > 0.5 ? ORG : YEL });
    const k = stamp(t, wt('m2', 'mar', 0.8));
    if (k > 0 && t < L.m3.t) { ctx.save(); ctx.translate(W / 2, 880 - 40); ctx.scale(k, k); G.text(ctx, 'MAR DE ELÉTRONS', 0, 0, { size: 70, fam: TITLE, weight: 400, align: 'center', color: PINK, stroke: '#1C2A22', strokeW: 12 }); ctx.restore(); }
    if (t >= L.m3.t) { const p = pop(t, wt('m3', 'cola', 0.4)); if (p > 0) { ctx.save(); ctx.translate(W / 2, 840); ctx.scale(p, p); G.text(ctx, 'funciona como uma "cola"', 0, 0, { size: 62, fam: TITLE, weight: 400, align: 'center', color: PINK, stroke: '#1C2A22', strokeW: 12 }); ctx.restore(); } }
  }

  function metprop(ctx, t) {
    doodles(ctx);
    const items = [
      ['Condutores de eletricidade', wt('m4', 'eletricidade', 0.55)], ['Condutores de calor', wt('m4', 'calor', 0.85)], ['Brilho metálico', wt('m5', 'brilho', 0.1)],
      ['Maleáveis → lâminas', wt('m5', 'maleaveis', 0.35)], ['Dúcteis → fios', wt('m5', 'ducteis', 0.7)], ['Sólidos a 25 °C*', wt('m6', 'solidos', 0.1)],
    ];
    items.forEach(([lab, t1], i) => {
      const x = 330 + (i % 3) * 630, y = 130 + Math.floor(i / 3) * 360, p = pop(t, t1); if (p <= 0) return;
      ctx.save(); ctx.translate(x, y + 160); ctx.scale(p, p);
      G.rrect(ctx, -290, -160, 580, 320, 26, { fill: 'rgba(0,0,0,0.22)', stroke: YEL, lw: 4, seed: 900 + i });
      const u = t - t1;
      ctx.save(); ctx.translate(0, -30);
      if (i === 0) { G.line(ctx, [[-200, 0], [200, 0]], { color: '#C98B5A', lw: 14, seed: 911 }); const bx = -200 + ((u * 260) % 400); bolt(ctx, bx, -10, 0.8); }
      if (i === 1) { G.rrect(ctx, -200, -12, 400, 24, 10, { fill: lerp(0, 1, clamp(u / 2)) > 0.5 ? '#FF8A5B' : '#A8B2BD', lw: 3, seed: 912 }); G.poly(ctx, [[-215, 60], [-190, -10], [-170, 30], [-150, -40], [-120, 60]], { fill: ORG, lw: 3, seed: 913 }); }
      if (i === 2) { G.rrect(ctx, -120, -55, 240, 110, 14, { fill: '#C8CED6', lw: 4, seed: 914 }); [[-60, -20, 26], [50, 10, 34], [90, -40, 18]].forEach(([sx, sy, r], k) => G.star(ctx, sx, sy, r * (0.7 + 0.3 * Math.sin(t * 5 + k * 2)), { fill: '#FFFFFF', seed: 915 + k })); }
      if (i === 3) { const f = ease.outCubic(clamp(u / 1.2)); G.rrect(ctx, -lerp(70, 210, f), 40 - lerp(80, 18, f), lerp(140, 420, f), lerp(80, 18, f), 6, { fill: '#C8CED6', lw: 3, seed: 916 }); G.rrect(ctx, -40, -100 + 60 * (0.5 + 0.5 * Math.sin(u * 9)) * (1 - f), 80, 40, 6, { fill: '#8B6B4A', lw: 3, seed: 917 }); }
      if (i === 4) { const pts = []; const len = ease.outCubic(clamp(u / 1.2)); for (let k = 0; k <= 60 * len; k++) pts.push([-200 + k * 6.6, Math.sin(k * 0.55) * 30]); if (pts.length > 1) G.line(ctx, pts, { color: '#D98A4E', lw: 6, seed: 918 }); }
      if (i === 5) { G.rrect(ctx, -170, -45, 120, 90, 10, { fill: '#A8B2BD', lw: 3, seed: 919 }); G.poly(ctx, [[110, -60], [150, 10], [140, 40], [110, 52], [80, 40], [70, 10]], { fill: '#DDE3EA', lw: 3, seed: 920 }); G.text(ctx, 'Hg', 110, 30, { size: 30, fam: SYMF, weight: 800, align: 'center', color: '#1C2A22' }); }
      ctx.restore();
      G.text(ctx, lab, 0, 115, { size: 44, fam: HAND, weight: 400, align: 'center', color: INK });
      ctx.restore();
    });
    const pe = fadeIn(t, wt('m6', 'mercurio', 0.6));
    if (pe > 0) txt(ctx, '* exceção: mercúrio (Hg) é LÍQUIDO', 1590, 885, { size: 40, align: 'center', color: RED, alpha: pe });
  }

  function ligas(ctx, t) {
    doodles(ctx);
    const t0 = S.S.ligas[0];
    heading(ctx, t, t0, 'LIGAS METÁLICAS', YEL, 150);
    txt(ctx, 'misturas de metais (às vezes com um pouco de outro elemento)', W / 2, 235, { size: 44, align: 'center', alpha: fadeIn(t, L.m7.t + 0.8) });
    const L3 = [['BRONZE', 'Cu + Sn', 'cobre + estanho', '#D08A4A', 'bronze'], ['LATÃO', 'Cu + Zn', 'cobre + zinco', '#E3C25A', 'latao'], ['AÇO', 'Fe + C', 'ferro + carbono', '#B7C0CA', 'aco']];
    L3.forEach(([n, f, d, c, w], i) => {
      const p = pop(t, wt('m8', w, 0.05 + i * 0.32)); if (p <= 0) return;
      const x = 380 + i * 580;
      ctx.save(); ctx.translate(x, 540); ctx.scale(p, p); ctx.rotate((i - 1) * 0.02);
      G.rrect(ctx, -250, -220, 500, 440, 28, { fill: 'rgba(0,0,0,0.22)', stroke: c, lw: 5, seed: 950 + i });
      G.poly(ctx, [[-110, -120], [110, -120], [140, -40], [-140, -40]], { fill: c, lw: 4, seed: 955 + i }); // um lingote
      G.text(ctx, n, 0, 50, { size: 66, fam: TITLE, weight: 400, align: 'center', color: c });
      G.text(ctx, f, 0, 125, { size: 54, fam: SYMF, weight: 800, align: 'center', color: INK });
      txt(ctx, d, 0, 185, { size: 40, align: 'center' });
      ctx.restore();
    });
  }

  function resumo(ctx, t) {
    doodles(ctx);
    const t0 = S.S.resumo[0];
    const k = stamp(t, t0);
    if (k > 0) { ctx.save(); ctx.translate(W / 2, 110); ctx.scale(k, k); G.text(ctx, 'RESUMO', 0, 0, { size: 90, fam: TITLE, weight: 400, align: 'center', color: YEL, stroke: '#1C2A22', strokeW: 12 }); ctx.restore(); }
    const cols = [130, 520, 980, 1400, 1800];
    const head = ['Ligação', 'Entre quem?', 'Elétrons', 'Forma'];
    const rows = [
      ['r2', 'IÔNICA', ORG, ['metal + ametal'], ['transferidos'], ['íons (cátion e ânion)', 'retículo cristalino']],
      ['r3', 'COVALENTE', BLU, ['ametal + ametal', '(ou com H)'], ['compartilhados', '(pares)'], ['moléculas']],
      ['r4', 'METÁLICA', YEL, ['metal + metal'], ['livres:', 'mar de elétrons'], ['cátions + elétrons', 'livres']],
    ];
    const hp = fadeIn(t, L.r1.t + 0.3);
    ctx.save(); ctx.globalAlpha *= hp;
    head.forEach((h, i) => txt(ctx, h, (cols[i] + cols[i + 1]) / 2, 230, { size: 46, align: 'center', color: INK }));
    G.line(ctx, [[cols[0], 255], [cols[4], 257]], { color: INK, lw: 4, seed: 1001 });
    ctx.restore();
    rows.forEach(([id, name, c, a, b, d], i) => {
      const t1 = L[id].t; if (t < t1) return;
      const y = 340 + i * 175;
      const q = (j) => fadeIn(t, t1 + j * 0.45 * (L[id].end - L[id].t) / 3, 0.3);
      ctx.save(); ctx.globalAlpha *= q(0); ctx.translate((cols[0] + cols[1]) / 2, y); ctx.scale(pop(t, t1), pop(t, t1)); G.text(ctx, name, 0, 14, { size: 52, fam: TITLE, weight: 400, align: 'center', color: c }); ctx.restore();
      [a, b, d].forEach((cell, j) => { cell.forEach((s, li) => txt(ctx, s, (cols[j + 1] + cols[j + 2]) / 2, y + 14 + (li - (cell.length - 1) / 2) * 48, { size: 42, align: 'center', color: j === 1 ? PINK : INK, alpha: q(j + 1) })); });
      G.line(ctx, [[cols[0], y + 88], [cols[4], y + 90]], { color: DIM, lw: 2, seed: 1010 + i, alpha: q(0) });
    });
  }

  function dicas(ctx, t) {
    doodles(ctx);
    const t0 = S.S.dicas[0];
    const k = stamp(t, t0);
    if (k > 0) { ctx.save(); ctx.translate(W / 2, 120); ctx.scale(k, k); G.text(ctx, '3 DICAS PARA A PROVA', 0, 0, { size: 84, fam: TITLE, weight: 400, align: 'center', color: GRN, stroke: '#1C2A22', strokeW: 12 }); ctx.restore(); }
    const tips = [
      ['d2', 'Metal ou ametal? Isso já diz a ligação.', 'metal + ametal = iônica · ametal + ametal = covalente · metal + metal = metálica'],
      ['d3', 'Conte os elétrons de valência pela família.', '1A → 1 e^{-} · 2A → 2 e^{-} · 3A → 3 e^{-} · 5A → 5 e^{-} · 6A → 6 e^{-} · 7A → 7 e^{-}'],
      ['d4', 'Hidrogênio se comporta como ametal.', 'H + ametal = covalente:  H_2O, HCl, CH_4, NH_3'],
    ];
    tips.forEach(([id, a, b], i) => {
      const p = pop(t, L[id].t); if (p <= 0) return;
      const y = 300 + i * 200;
      ctx.save(); ctx.translate(W / 2, y); ctx.scale(p, p);
      G.rrect(ctx, -830, -80, 1660, 170, 26, { fill: 'rgba(0,0,0,0.22)', stroke: GRN, lw: 4, seed: 1100 + i });
      G.ellipse(ctx, -740, 5, 52, 52, { fill: GRN, lw: 4, seed: 1105 + i });
      G.text(ctx, String(i + 1), -740, 28, { size: 62, fam: TITLE, weight: 400, align: 'center', color: '#1C2A22' });
      txt(ctx, a, -650, -5, { size: 54 });
      chem(ctx, b, -650, 55, { size: 36, color: YEL, alpha: fadeIn(t, L[id].t + 0.7) });
      ctx.restore();
    });
  }

  function fim(ctx, t) {
    const t0 = S.S.fim[0];
    G.rays(ctx, W / 2, 420, { n: 32, r0: 200, r1: 1500, color: 'rgba(255,217,90,0.18)', lw: 16, seed: 1201, spin: (t - t0) * 0.15 });
    doodles(ctx);
    const k = stamp(t, t0);
    if (k > 0) { ctx.save(); ctx.translate(W / 2, 330); ctx.scale(k, k); ctx.rotate(-0.03); G.text(ctx, 'BOA PROVA!', 0, 0, { size: 170, fam: TITLE, weight: 400, align: 'center', color: YEL, stroke: '#1C2A22', strokeW: 18 }); ctx.restore(); }
    txt(ctx, 'iônica · covalente · metálica', W / 2, 450, { size: 56, align: 'center', alpha: fadeIn(t, t0 + 0.5) });
    txt(ctx, 'Você consegue!', W / 2, 540, { size: 64, align: 'center', color: GRN, alpha: fadeIn(t, t0 + 1.0) });
    Ch.claude(ctx, { x: W / 2, y: 860, s: 0.8, eyes: 'happy', armL: 1.3 + 0.3 * Math.sin(t * 6), armR: 1.3 + 0.3 * Math.sin(t * 6 + 1), mouth: talk(t), blush: 0.5 });
    G.confetti(ctx, t, t0, { n: 160, seed: 7 });
  }

  // =================================================================================================
  const SCENES = { intro, octeto, valencia, ionica, reticulo, formula, covalente, moleculas, formulas, covprop, metalica, metprop, ligas, resumo, dicas, fim };
  const sceneAt = (t) => { let s = 'intro'; for (const n of S.SCENE_LIST) if (t >= S.S[n][0]) s = n; return s; };
  Studio.film({
    fadeOut: 1.6,
    post: { vignette: 0.4 },
    async init() { VO = await Studio.loadJSON('out/voice.json'); SUBS = VO ? Subs.fromVoice(VO, { maxWords: 7, hold: 0.25 }) : []; },
    draw(ctx, t) {
      G.setStyle('chalk');
      const name = sceneAt(t);
      const [a, b] = S.S[name];
      board(ctx);
      // câmera: um empurrão lento em cada cena, um tranco em cada título
      const u = clamp((t - a) / Math.max(1, b - a));
      const tt = S.titles.filter((x) => t >= x).pop();
      const shake = tt !== undefined ? 10 * Math.exp(-(t - tt) * 9) : 0;
      const z = 1 + 0.025 * ease.inOutQuad(u);
      ctx.save();
      ctx.translate(W / 2 + U.noise1(t * 30, 1) * shake, H * 0.45 + U.noise1(t * 30, 2) * shake); ctx.scale(z, z); ctx.translate(-W / 2, -H * 0.45);
      SCENES[name](ctx, t);
      ctx.restore();
      // flash nos títulos; um "apagador" curto em cada corte
      if (tt !== undefined && t - tt < 0.18) { ctx.fillStyle = `rgba(255,255,255,${0.55 * (1 - (t - tt) / 0.18)})`; ctx.fillRect(0, 0, W, H); }
      // legendas
      Subs.draw(ctx, t, SUBS, { style: 'pop', size: 44 });
    },
  });
})();

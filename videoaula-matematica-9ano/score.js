// ROTEIRO — fonte única de verdade para imagem E som.
// Cada cena, cada linha escrita na lousa e cada "tique" do cronômetro é um evento aqui.
// film.js desenha a partir disto e song.js gera os sons (giz, sinos, cronômetro) a partir dos MESMOS tempos.
(function () {
  const node = typeof require !== 'undefined';
  const U = node ? require('./engine/util') : globalThis.U;
  const MU = node ? require('./engine/music') : globalThis.MUSIC;
  const { m, makeClock, makeChords } = MU;

  const FPS = 24;
  const FORMAT = U.pickFormat('16:9');
  const [W, H] = U.formatSize(FORMAT);
  const SAFE = U.safeArea(W, H);
  const WIDE = W / H > 1.2;
  const STYLE = 'chalk';
  const clock = makeClock({ bpm: 80, offset: 0 }); // 1 tempo = 0,75 s · 1 compasso = 3 s
  const { T, BEAT } = clock;

  // ---------------- narração (ElevenLabs) ----------------
  // Cada fala tem uma chave (hash do texto). voice-timings.js guarda a duração real de cada fala
  // já gerada; sem ela, usamos uma estimativa. Os tempos da lousa seguem a voz.
  const VT = (node ? (() => { try { return require('./voice-timings.js'); } catch (e) { return {}; } })() : globalThis.VOICE_TIMINGS) || {};
  const NARRATION = new Map();
  const vkey = (s) => { let h = 5381; for (let i = 0; i < s.length; i++) h = ((h * 33) ^ s.charCodeAt(i)) >>> 0; return 'v' + h.toString(16) + s.length.toString(16); };
  function voice(text) {
    text = text.replace(/\s+/g, ' ').replace(/\s+([,.!?:;])/g, '$1').replace(/([,.])\1+/g, '$1').trim();
    if (!text || !/[\p{L}\d]/u.test(text)) return null;
    const key = vkey(text);
    NARRATION.set(key, text);
    const d = VT[key] ?? (0.4 + text.length / 14.5);
    return { key, text, d };
  }
  const NUM = { 2: ['meio', 'meios'], 3: ['terço', 'terços'], 4: ['quarto', 'quartos'], 5: ['quinto', 'quintos'], 6: ['sexto', 'sextos'], 7: ['sétimo', 'sétimos'], 8: ['oitavo', 'oitavos'], 9: ['nono', 'nonos'], 10: ['décimo', 'décimos'], 100: ['centésimo', 'centésimos'] };
  const frac = (n, d) => { const w = NUM[d]; if (!w) return ` ${n} sobre ${d} `; return ` ${n === '1' ? 'um' : n} ${n === '1' ? w[0] : w[1]} `; };
  // texto da lousa -> português falado
  function say(s) {
    let t = ' ' + s + ' ';
    const R = (a, b) => { t = t.replace(a, b); };
    R(/:\)|:\(/g, '');
    R(/\{CC, CK, KC, KK\}/g, 'cara cara, cara coroa, coroa cara, coroa coroa');
    R(/(\d) (\d{3})(?!\d)/g, '$1$2'); R(/(\d) (\d{3})(?!\d)/g, '$1$2');
    R(/R\$ ?([\d.,]+)/g, '$1 reais');
    R(/Ex\.:/g, 'Exemplo:'); R(/\bnº/g, 'número'); R(/\bEx\./g, 'Exemplo');
    R(/\b([fh])\(([^()]+)\)/g, '$1 de $2'); R(/\bP\(/g, 'a probabilidade de ('); R(/\bV\(/g, 'vértice (');
    R(/\(([^()]+)\)²/g, ' o quadrado de $1'); R(/\(([^()]+)\)³/g, ' o cubo de $1');
    R(/(\d+)\/(\d+)/g, (_, n, d) => frac(n, d));
    R(/\bcm²/g, ' centímetros quadrados'); R(/\bm²/g, ' metros quadrados'); R(/\bkm²/g, ' quilômetros quadrados');
    R(/\bcm³/g, ' centímetros cúbicos'); R(/\bdm³/g, ' decímetro cúbico'); R(/\bm³/g, ' metros cúbicos');
    R(/²/g, ' ao quadrado'); R(/³/g, ' ao cubo');
    R(/x₁/g, 'x um'); R(/x₂/g, 'x dois');
    R(/√/g, ' raiz de '); R(/±/g, ' mais ou menos '); R(/≈/g, ' aproximadamente '); R(/≠/g, ' diferente de ');
    R(/≤/g, ' menor ou igual a '); R(/≥/g, ' maior ou igual a ');
    R(/→|←/g, ', '); R(/·/g, ' vezes '); R(/×/g, ' por '); R(/÷/g, ' dividido por ');
    R(/=/g, ' igual a '); R(/>/g, ' maior que '); R(/</g, ' menor que ');
    R(/(^|[\s(])−\s?(\d)/g, '$1 menos $2'); R(/−/g, ' menos '); R(/\+/g, ' mais ');
    R(/°/g, ' graus'); R(/π/g, ' pi '); R(/Δ/g, ' delta '); R(/Ω/g, ' ômega '); R(/%/g, ' por cento');
    R(/\bai\b/g, 'ângulo interno'); R(/\bae\b/g, 'ângulo externo'); R(/\bac\b/g, 'ângulo central');
    R(/\bxv\b/g, 'x do vértice'); R(/\byv\b/g, 'y do vértice'); R(/\btv\b/g, 't do vértice');
    R(/\b4ac\b/g, '4 a c'); R(/\b(\d+)([a-z]{1,2})\b/g, (_, d, l) => d + ' ' + l.split('').join(' ')); R(/\bax\b/g, 'a x'); R(/\bbx\b/g, 'b x');
    R(/[(){}|✓]/g, ' '); R(/\.\.\./g, '.'); R(/"/g, '');
    R(/\b[A-ZÀ-Ý]{3,}\b/g, (w) => w.toLowerCase());
    return t.replace(/\s+/g, ' ').trim();
  }

  // ---------------- marcação das linhas ----------------
  // '# ' fórmula (amarelo, em destaque) · '! ' erro comum (rosa) · '> ' dica (azul) · '' linha em branco
  // uma linha também pode ser [texto da lousa, texto falado] ('' = sem fala)
  const PAUSE = 12; // segundos de "pause e tente"
  function parse(s) {
    let spoken;
    if (Array.isArray(s)) { spoken = s[1]; s = s[0]; }
    if (s === '') return { type: 'b', text: '' };
    let p = { type: 'n', text: s };
    if (s.startsWith('# ')) p = { type: 'f', text: s.slice(2) };
    else if (s.startsWith('! ')) p = { type: 'e', text: s.slice(2) };
    else if (s.startsWith('> ')) p = { type: 't', text: s.slice(2) };
    p.spoken = spoken !== undefined ? spoken : (p.type === 'e' ? 'Atenção! ' : '') + say(p.text);
    return p;
  }
  function wrap(text, max) {
    if (text.length <= max) return [text];
    const out = []; let cur = '';
    for (const w of text.split(' ')) {
      if ((cur + ' ' + w).trim().length > max && cur) { out.push(cur); cur = w; } else cur = (cur + ' ' + w).trim();
    }
    if (cur) out.push(cur);
    return out;
  }
  // linhas -> [{text, type, src, at, dur, voice}], tempos relativos ao início da cena; a voz dita o ritmo
  function layLines(raw, start, max) {
    const lines = []; let at = start;
    raw.forEach((s, src) => {
      const p = parse(s);
      if (p.type === 'b') { lines.push({ ...p, src, at, dur: 0 }); at += 0.3; return; }
      const parts = p.type === 'f' ? [p.text] : wrap(p.text, max);
      const v = voice(p.spoken);
      const total = parts.reduce((a, x) => a + x.length, 0);
      const span = v ? v.d : 0.6 + total / 16;
      let acc = 0;
      parts.forEach((txt, k) => {
        const ta = at + span * (acc / total);
        acc += txt.length;
        const dur = Math.max(0.4, Math.min(1.8, span * (txt.length / total), 0.35 + txt.length / 30));
        lines.push({ type: p.type, text: txt, src, at: ta, dur, cont: k > 0, voice: k === 0 ? v : null });
      });
      at += span + 0.5 + (p.type === 'f' ? 0.5 : 0);
    });
    return { lines, end: at };
  }
  const snap = (d) => Math.ceil(d / BEAT - 1e-6) * BEAT; // cortes sempre em cima do tempo da música

  // ---------------- construtores de cena ----------------
  const SCENES = [];
  let chapter = 0, chapterName = 'Abertura';
  const CH = (num, title, sub, topics) => {
    chapter = num; chapterName = title;
    const v = voice(num === 6 ? `Chegamos à revisão final! Vamos ver: ${topics.map(say).join(', ')}.` : `Aula ${num}: ${title}, ${sub}. Nesta aula vamos ver: ${topics.map(say).join(', ')}.`);
    SCENES.push({ kind: 'chapter', num, title, sub, topics: topics || [], voices: [{ at: 0.6, ...v }], dur: snap(Math.max(9, 0.6 + v.d + 1.5)) });
  };
  // título falado no início, depois as linhas
  const titled = (title, spokenTitle) => { const v = voice(spokenTitle ?? say(title)); return { v, start: Math.max(1.1, 0.4 + (v ? v.d + 0.45 : 0)) }; };
  const B = (title, raw, fig, spokenTitle) => {
    const max = fig ? 56 : 80;
    const tt = titled(title, spokenTitle);
    const { lines, end } = layLines(raw, tt.start, max);
    SCENES.push({ kind: 'board', title, lines, fig, voices: tt.v ? [{ at: 0.4, ...tt.v }] : [], dur: snap(end + 2.2) });
  };
  // exercício: enunciado + cronômetro de pausa, depois uma lousa com a resolução
  const EX = (title, q, sol, fig, figQ) => {
    const tt = titled(title);
    // o enunciado é falado de uma vez só (é uma frase), as linhas aparecem acompanhando a fala
    const qv = voice(say(q.join(' ')));
    const qraw = q.map((s, i) => [s, '']);
    const { lines } = layLines(qraw, tt.start, 75);
    const tot = q.reduce((a, s) => a + s.length, 0); let acc = 0;
    lines.forEach((l) => { l.at = tt.start + qv.d * (acc / tot); acc += l.text.length; l.dur = Math.min(1.8, Math.max(0.5, qv.d * l.text.length / tot)); });
    lines[0].voice = qv;
    const pv = voice('Agora pause o vídeo e tente resolver sozinho. Depois confira a resolução.');
    const t0 = tt.start + qv.d + 0.8;
    const timer = { t0, t1: t0 + Math.max(PAUSE, pv.d + 3) };
    SCENES.push({ kind: 'ex', title, lines, fig: figQ, timer, voices: [{ at: 0.4, ...tt.v }, { at: t0, ...pv }], dur: snap(timer.t1 + 0.9) });
    const qShort = q.join(' ');
    B('Resolução — ' + title, [['> ' + (qShort.length > 70 ? qShort.slice(0, 67) + '...' : qShort), ''], ...sol], fig, `Vamos resolver o ${title.replace(/ — .*/, '')}.`);
    SCENES[SCENES.length - 1].solution = true;
  };
  const LIST = (title, items, from) => { // bloco da lista final: 4 questões e um cronômetro
    const raw = []; items.forEach((it, i) => { raw.push([`${from + i}) ${it}`, `Questão ${from + i}. ${say(it)}`]); });
    const tt = titled(title, `Questões ${from} a ${from + items.length - 1}.`);
    const { lines, end } = layLines(raw, tt.start, 80);
    const pv = voice('Pause o vídeo e resolva estas questões no caderno.');
    const timer = { t0: end + 0.4, t1: end + 0.4 + 20 };
    SCENES.push({ kind: 'ex', title, lines, timer, list: true, voices: [{ at: 0.4, ...tt.v }, { at: timer.t0, ...pv }], dur: snap(timer.t1 + 0.9) });
  };
  const tagScenes = () => { for (const s of SCENES) if (s.chapter === undefined) { s.chapter = chapter; s.chapterName = chapterName; } };

  // =====================================================================
  // ABERTURA
  // =====================================================================
  { const v = voice('Olá! Seja bem-vindo à videoaula completa de Matemática do nono ano, capítulo 15. Vamos começar do zero e estudar polígonos regulares, áreas e volumes, função quadrática, estatística e probabilidade. Pegue lápis e caderno, e vamos lá!'); SCENES.push({ kind: 'intro', voices: [{ at: 0.8, ...v }], dur: snap(Math.max(12, v.d + 2.5)) }); }
  B('Como usar esta videoaula', [
    'Vamos começar do ZERO. Não precisa saber nada antes!',
    'Cada aula explica primeiro o básico e depois avança.',
    '',
    'As cores do giz têm significado:',
    '# Amarelo = fórmula importante (anote no caderno!)',
    '! Rosa = erro comum que muitos alunos cometem',
    '> Azul = dica ou observação',
    '',
    'Quando aparecer o relógio PAUSE O VÍDEO e tente',
    'resolver sozinho. Depois confira a resolução.',
    'Tenha lápis, papel e calculadora (se o professor deixar).',
  ]);
  B('O que vamos estudar', [
    'Aula 1 — Polígonos regulares',
    'Aula 2 — Áreas e volumes',
    'Aula 3 — Função quadrática (com Bhaskara)',
    'Aula 4 — Estatística',
    'Aula 5 — Probabilidade',
    '',
    'No final: revisão geral, resumo das fórmulas',
    'e uma lista com 20 exercícios de prova + gabarito.',
  ]);
  tagScenes();

  // =====================================================================
  // AULA 1 — POLÍGONOS REGULARES
  // =====================================================================
  CH(1, 'Polígonos regulares', 'lados, vértices e ângulos', ['O que é polígono', 'Lados, vértices, ângulos', 'Regular x irregular', 'Soma dos ângulos internos', 'Ângulo interno, externo e central']);
  B('O que é um polígono?', [
    'Polígono é uma figura PLANA e FECHADA,',
    'formada apenas por segmentos de reta.',
    '',
    'Plana: desenhada no papel, sem volume.',
    'Fechada: a linha começa e termina no mesmo ponto.',
    'Segmento de reta: um "pedaço" de reta (lado reto).',
    '',
    '! Figura aberta NÃO é polígono.',
    '! Círculo NÃO é polígono: ele é curvo.',
  ], { type: 'isPoly', s: [0, 7, 8] });
  B('Lados, vértices e ângulos', [
    'LADOS: os segmentos que formam a figura.',
    'VÉRTICES: os "cantos", onde dois lados se encontram.',
    'Damos nomes com letras maiúsculas: A, B, C, D, E...',
    'ÂNGULO INTERNO: a "abertura" entre dois lados, do lado de dentro.',
    '',
    'Num polígono, sempre vale:',
    '# nº de lados = nº de vértices = nº de ângulos',
    'O pentágono ao lado tem 5 lados, 5 vértices e 5 ângulos.',
  ], { type: 'polyParts', s: [0, 1, 3] });
  B('Graus: como medir um ângulo', [
    'Ângulos são medidos em GRAUS. Símbolo: °',
    'Uma volta completa tem 360°.',
    'Meia volta tem 180°: forma uma linha reta.',
    'Um quarto de volta tem 90°: é o ÂNGULO RETO,',
    'igual ao canto de uma folha de caderno.',
    '',
    '> Menor que 90° = agudo · maior que 90° = obtuso.',
  ], { type: 'degrees', s: [1, 2, 3] });
  B('Os nomes dos polígonos', [
    '3 lados → triângulo',
    '4 lados → quadrilátero (ex.: quadrado)',
    '5 lados → pentágono',
    '6 lados → hexágono',
    '7 lados → heptágono',
    '8 lados → octógono',
    '9 lados → eneágono',
    '10 lados → decágono',
    '12 lados → dodecágono',
    '> "penta" = 5, "hexa" = 6, "octo" = 8, "deca" = 10.',
  ], { type: 'gallery', ns: [3, 4, 5, 6, 7, 8, 9, 10, 12] });
  B('Regular x irregular', [
    'Um polígono é REGULAR quando tem:',
    '1) todos os LADOS com a mesma medida, E',
    '2) todos os ÂNGULOS com a mesma medida.',
    'Se faltar uma dessas duas coisas, ele é IRREGULAR.',
    '',
    '! O retângulo tem os 4 ângulos iguais (90°),',
    'mas os lados não são iguais: NÃO é regular.',
    '! O losango tem os 4 lados iguais, mas os',
    'ângulos são diferentes: também NÃO é regular.',
    '> O quadrado é o quadrilátero regular.',
  ], { type: 'regIrreg', s: [0, 3, 5, 7] });
  B('O segredo do triângulo: 180°', [
    'Some os 3 ângulos internos de QUALQUER triângulo:',
    'o resultado é sempre 180°.',
    '',
    'Por quê? Recorte os 3 cantos e coloque um',
    'ao lado do outro: eles formam meia volta,',
    'uma linha reta. E linha reta mede 180°!',
    '# a + b + c = 180°',
    'Ex.: 60° + 60° + 60° = 180°',
    'Ex.: 90° + 30° + 60° = 180°',
  ], { type: 'tri180', s: [0, 3] });
  B('Soma dos ângulos internos (S)', [
    'Escolha UM vértice e trace as diagonais',
    'que saem dele: o polígono vira triângulos!',
    '',
    'Quadrilátero (4 lados) → 2 triângulos',
    'Pentágono (5 lados) → 3 triângulos',
    'Hexágono (6 lados) → 4 triângulos',
    'Sempre: nº de triângulos = n − 2  (n = nº de lados)',
    'Cada triângulo vale 180°. Então a soma é:',
    '# S = (n − 2) · 180°',
    '> O ponto · significa multiplicação (×).',
  ], { type: 'triSplit', steps: [[0, 4], [3, 4], [4, 5], [5, 6]] });
  B('Usando a fórmula da soma', [
    'Pentágono: n = 5',
    'S = (n − 2) · 180°',
    'S = (5 − 2) · 180°   ← troco n por 5',
    'S = 3 · 180°   ← primeiro o parêntese',
    'S = 540°',
    '',
    'Hexágono: n = 6',
    'S = (6 − 2) · 180° = 4 · 180° = 720°',
    '! Erro comum: fazer 5 − 2 · 180 sem parêntese.',
    '! Primeiro o parêntese, depois a multiplicação!',
  ], { type: 'triSplit', steps: [[0, 5], [6, 6]] });
  B('Cada ângulo interno (ai) do polígono regular', [
    'No polígono REGULAR todos os ângulos são iguais.',
    'Então basta repartir a soma entre os n ângulos:',
    '# ai = S ÷ n',
    '# ai = (n − 2) · 180° ÷ n',
    '',
    'Hexágono regular: S = 720°',
    'ai = 720° ÷ 6 = 120°',
    'Quadrado: S = 360° → ai = 360° ÷ 4 = 90°',
    'Triângulo equilátero: ai = 180° ÷ 3 = 60°',
  ], { type: 'polyAngle', n: 6, label: '120°', s: 5 });
  B('Ângulo externo (ae) e ângulo central (ac)', [
    'ÂNGULO EXTERNO: prolongue um lado para fora.',
    'Ele completa o interno até 180° (linha reta):',
    '# ai + ae = 180°',
    'A soma dos externos é SEMPRE 360° (uma volta).',
    '# ae = 360° ÷ n',
    'ÂNGULO CENTRAL: no centro, entre dois vértices',
    'vizinhos. Também mede:',
    '# ac = 360° ÷ n',
    'Hexágono: ae = ac = 360° ÷ 6 = 60° e ai = 120°',
  ], { type: 'extAngle', n: 6, s: [0, 5] });
  EX('Exercício 1', ['Quanto mede cada ângulo interno', 'de um octógono regular?'], [
    'Octógono → n = 8 lados',
    'Passo 1 — soma: S = (n − 2) · 180°',
    'S = (8 − 2) · 180° = 6 · 180° = 1080°',
    'Passo 2 — dividir pelos 8 ângulos:',
    'ai = 1080° ÷ 8 = 135°',
    '# Resposta: 135°',
    '> Conferindo: ae = 360° ÷ 8 = 45° e 135° + 45° = 180° ✓',
  ], { type: 'polyAngle', n: 8, label: '135°', s: 4 }, { type: 'polyAngle', n: 8, label: '?', s: 0 });
  EX('Exercício 2', ['Um polígono regular tem ângulo externo de 30°.', 'Quantos lados ele tem?'], [
    'Sabemos que: ae = 360° ÷ n',
    'Então: 30° = 360° ÷ n',
    'Isso quer dizer: n = 360° ÷ 30°',
    'n = 12',
    '# Resposta: 12 lados (dodecágono)',
    '> Truque: nº de lados = 360 ÷ ângulo externo.',
  ], { type: 'polyAngle', n: 12, label: '150°', s: 4 });
  EX('Exercício 3', ['Qual é a soma dos ângulos internos de um decágono?'], [
    'Decágono → n = 10',
    'S = (10 − 2) · 180°',
    'S = 8 · 180°',
    'S = 1440°',
    '# Resposta: 1440°',
    '> São 8 triângulos de 180° cada.',
  ], { type: 'triSplit', steps: [[0, 10]] });
  B('Resumo da Aula 1', [
    'Polígono: figura plana, fechada, de lados retos.',
    'Regular: lados iguais E ângulos iguais.',
    '# S = (n − 2) · 180°',
    '# ai = S ÷ n',
    '# ae = 360° ÷ n   e   ai + ae = 180°',
    '# ac = 360° ÷ n',
    '> Soma dos ângulos de um triângulo = 180°.',
  ]);
  tagScenes();

  // =====================================================================
  // AULA 2 — ÁREAS E VOLUMES
  // =====================================================================
  CH(2, 'Áreas e volumes', 'perímetro, área e volume', ['Perímetro x área x volume', 'Unidades de medida', 'Áreas das figuras planas', 'Sólidos geométricos', 'Volumes']);
  B('O que é perímetro?', [
    'PERÍMETRO é a medida do CONTORNO da figura:',
    'a soma de todos os seus lados.',
    'Imagine uma formiga andando em volta da figura:',
    'o caminho que ela faz é o perímetro.',
    '',
    'Retângulo de 5 cm por 3 cm:',
    'P = 5 + 3 + 5 + 3 = 16 cm',
    '# P = soma de todos os lados',
    '> Perímetro usa unidade de comprimento: cm, m, km.',
  ], { type: 'grid', w: 5, h: 3, mode: 'perim', s: [2, 5] });
  B('O que é área?', [
    'ÁREA é o tamanho da SUPERFÍCIE da figura:',
    'o espaço que fica DENTRO dela.',
    'Medimos contando quantos quadradinhos de',
    '1 cm por 1 cm cabem dentro da figura.',
    '',
    'Retângulo de 5 cm por 3 cm:',
    '3 fileiras de 5 quadradinhos = 15 quadradinhos',
    '# A = 15 cm²',
    '> cm² lê-se "centímetro quadrado".',
  ], { type: 'grid', w: 5, h: 3, mode: 'area', s: [2, 6] });
  B('Área x volume', [
    'ÁREA: figura PLANA, com 2 dimensões',
    '(comprimento e largura). Ex.: o piso de uma sala.',
    'Conta QUADRADINHOS → unidade cm², m².',
    '',
    'VOLUME: SÓLIDO, com 3 dimensões',
    '(comprimento, largura e ALTURA).',
    'Ex.: quanta água cabe numa caixa-d\'água.',
    'Conta CUBINHOS → unidade cm³, m³.',
  ], { type: 'areaVol', s: [0, 4] });
  B('Unidades de medida', [
    'Comprimento (1 dimensão): mm, cm, m, km',
    'Área (2 dimensões): cm², m², km²',
    'Volume (3 dimensões): cm³, m³',
    '',
    '1 m = 100 cm',
    '1 m² = 100 cm · 100 cm = 10 000 cm²',
    '1 m³ = 100 · 100 · 100 = 1 000 000 cm³',
    '# 1 litro = 1 dm³ = 1000 cm³',
    '# 1 m³ = 1000 litros',
    '! Erro comum: achar que 1 m² = 100 cm². Não é!',
  ], { type: 'units', s: [0, 1, 2] });
  B('Área do retângulo e do quadrado', [
    'Retângulo: base (b) e altura (h).',
    'Cada fileira tem b quadradinhos e são h fileiras:',
    '# A = b · h',
    'Ex.: b = 6 m e h = 3 m → A = 6 · 3 = 18 m²',
    '',
    'Quadrado: os 4 lados são iguais (l).',
    '# A = l · l = l²',
    'Ex.: l = 6 cm → A = 6² = 6 · 6 = 36 cm²',
    '! l² é l · l, e NÃO l · 2!  6² = 36, e não 12.',
  ], { type: 'grid', w: 6, h: 3, mode: 'area', s: [1, 3], labels: ['b = 6', 'h = 3'] });
  B('Área do triângulo', [
    'Desenhe um retângulo em volta do triângulo,',
    'com a mesma base (b) e a mesma altura (h).',
    'O triângulo ocupa EXATAMENTE a metade dele.',
    '# A = (b · h) ÷ 2',
    'Ex.: b = 10 cm e h = 6 cm',
    'A = (10 · 6) ÷ 2 = 60 ÷ 2 = 30 cm²',
    '! A altura forma 90° com a base. Ela NÃO é o',
    'lado inclinado do triângulo!',
  ], { type: 'triArea', s: [0, 2, 6] });
  B('Paralelogramo, trapézio e losango', [
    'Paralelogramo: corte um triângulo de um lado e',
    'encaixe do outro: vira um retângulo!',
    '# A = b · h',
    'Trapézio: base maior (B), base menor (b), altura (h).',
    '# A = (B + b) · h ÷ 2',
    'Ex.: B = 8, b = 4, h = 5 → (8 + 4) · 5 ÷ 2 = 30',
    'Losango: diagonal maior (D) e menor (d).',
    '# A = (D · d) ÷ 2',
  ], { type: 'shapes2', s: [0, 3, 6] });
  B('O círculo: raio, diâmetro e π', [
    'RAIO (r): do centro até a borda.',
    'DIÂMETRO (d): atravessa o círculo pelo centro.',
    '# d = 2 · r',
    'π (lê-se "pi") é um número especial: π ≈ 3,14',
    '(≈ significa "aproximadamente")',
    'Contorno do círculo (comprimento):',
    '# C = 2 · π · r',
    'Ex.: r = 5 cm → C = 2 · 3,14 · 5 = 31,4 cm',
  ], { type: 'circle', s: [0, 1, 5] });
  B('Área do círculo', [
    '# A = π · r²',
    'Ex.: r = 5 cm',
    'A = 3,14 · 5²',
    'A = 3,14 · 25',
    'A = 78,5 cm²',
    '',
    '! Use o RAIO! Se o problema der o diâmetro,',
    'divida por 2 primeiro.',
    '! r² = r · r (5² = 25, não 10).',
  ], { type: 'circleArea' });
  B('Área do hexágono regular', [
    'Ligue o centro aos 6 vértices: aparecem',
    '6 triângulos equiláteros (lados iguais a l).',
    'Área de 1 triângulo equilátero:',
    '# A = l² · √3 ÷ 4',
    'Hexágono = 6 desses triângulos:',
    '# A = 6 · l² · √3 ÷ 4',
    '√3 é a "raiz quadrada de 3": √3 ≈ 1,73',
    'Ex.: l = 2 cm → 6 · 4 · 1,73 ÷ 4 ≈ 10,4 cm²',
    '> Polígonos regulares + áreas juntos na prova!',
  ], { type: 'hexTri', s: 0 });
  B('Sólidos geométricos', [
    'Sólidos têm 3 dimensões: comprimento,',
    'largura e ALTURA. Eles ocupam espaço.',
    'Cubo: 6 faces quadradas iguais (como um dado).',
    'Paralelepípedo: forma de caixa de sapato.',
    'Cilindro: forma de lata de refrigerante.',
    'Cone: forma de casquinha de sorvete.',
    'Pirâmide: base de polígono e uma ponta.',
    'Esfera: forma de bola.',
    '> Cubo: 6 faces, 12 arestas e 8 vértices.',
  ], { type: 'solids', s: [2, 3, 4, 5, 6, 7] });
  B('Volume do paralelepípedo e do cubo', [
    'Volume = quantos cubinhos de 1 cm³ cabem.',
    'Caixa 4 × 3 × 2: no chão cabem 4 · 3 = 12 cubinhos.',
    'São 2 andares: 12 · 2 = 24 cubinhos.',
    '# V = c · l · h',
    '(comprimento · largura · altura)',
    'Cubo de aresta a (todas iguais):',
    '# V = a · a · a = a³',
    'Ex.: a = 3 cm → V = 3 · 3 · 3 = 27 cm³',
    '! a³ é a · a · a, e NÃO a · 3!',
  ], { type: 'boxFill', c: 4, l: 3, h: 2, s: [1, 2] });
  B('Volume do cilindro (e dos prismas)', [
    'Regra geral para prismas e cilindros:',
    '# V = (área da base) · altura',
    'No cilindro a base é um círculo (π · r²):',
    '# V = π · r² · h',
    'Ex.: lata com r = 3 cm e h = 10 cm',
    'V = 3,14 · 3² · 10',
    'V = 3,14 · 9 · 10 = 282,6 cm³',
    'Em litros: 282,6 ÷ 1000 ≈ 0,28 L',
  ], { type: 'cyl', s: [2, 4] });
  B('Cone, pirâmide e esfera (bônus)', [
    'Cone e pirâmide têm 1/3 do volume do cilindro',
    '(ou prisma) de mesma base e mesma altura:',
    '# V = (área da base) · h ÷ 3',
    'Esfera de raio r:',
    '# V = 4 · π · r³ ÷ 3',
    '> Prioridade na prova: cubo, paralelepípedo',
    'e cilindro!',
  ], { type: 'cone3', s: [0] });
  EX('Exercício 4', ['Um terreno retangular mede 20 m por 15 m.', 'Qual é a sua área? E o seu perímetro?'], [
    'Área: A = b · h = 20 · 15 = 300',
    '# A = 300 m²',
    'Perímetro: soma dos 4 lados',
    'P = 20 + 15 + 20 + 15 = 70',
    '# P = 70 m',
    '! Área em m², perímetro em m. Não troque!',
  ], { type: 'grid', w: 4, h: 3, mode: 'both', s: [0, 2], labels: ['20 m', '15 m'] });
  EX('Exercício 5', ['Uma pizza tem 30 cm de diâmetro.', 'Qual é a área da pizza? (use π ≈ 3,14)'], [
    'Diâmetro = 30 cm → raio = 30 ÷ 2 = 15 cm',
    'A = π · r²',
    'A = 3,14 · 15² = 3,14 · 225',
    'A = 706,5',
    '# A = 706,5 cm²',
    '! Quem usou 30 no lugar do raio errou!',
  ], { type: 'circleArea', pizza: true });
  EX('Exercício 6', ['Uma caixa-d\'água tem forma de paralelepípedo', 'de 2 m × 1,5 m × 1 m. Quantos litros ela comporta?'], [
    'V = c · l · h = 2 · 1,5 · 1',
    'V = 3 m³',
    'Como 1 m³ = 1000 litros:',
    '3 · 1000 = 3000',
    '# Resposta: 3000 litros',
  ], { type: 'boxFill', c: 4, l: 3, h: 2, s: [0, 0], water: true });
  EX('Exercício 7', ['Calcule a área de um triângulo de', 'base 12 cm e altura 7 cm.'], [
    'A = (b · h) ÷ 2',
    'A = (12 · 7) ÷ 2',
    'A = 84 ÷ 2',
    '# A = 42 cm²',
  ], { type: 'triArea', s: [0, 0, 99] });
  B('Resumo da Aula 2', [
    'Perímetro = contorno (cm) · Área = superfície (cm²) · Volume = espaço (cm³)',
    '# Retângulo: A = b · h      Quadrado: A = l²',
    '# Triângulo: A = b · h ÷ 2',
    '# Trapézio: A = (B + b) · h ÷ 2      Losango: A = D · d ÷ 2',
    '# Círculo: A = π · r²      C = 2 · π · r',
    '# Paralelepípedo: V = c · l · h      Cubo: V = a³',
    '# Cilindro: V = π · r² · h',
    '> 1 m³ = 1000 L  ·  1 L = 1000 cm³',
  ]);
  tagScenes();

  // =====================================================================
  // AULA 3 — FUNÇÃO QUADRÁTICA
  // =====================================================================
  CH(3, 'Função quadrática', 'do zero até a Bhaskara', ['Incógnitas e sinais', 'O que é função', 'f(x) = ax² + bx + c', 'Tabela e gráfico (parábola)', 'Raízes, Bhaskara e Δ', 'Vértice']);
  B('Incógnitas: letras no lugar de números', [
    'Em matemática usamos LETRAS no lugar de números',
    'que ainda não conhecemos. Essa letra é a INCÓGNITA.',
    'Ex.: x + 3 = 7',
    'Qual número somado com 3 dá 7? É o 4. Então x = 4.',
    '',
    'Escrever 2x significa 2 · x (o · fica escondido).',
    'x² significa x · x ("x ao quadrado").',
    'Se x = 5: 2x = 2 · 5 = 10 e x² = 5 · 5 = 25.',
    '! −3² = −9, mas (−3)² = (−3) · (−3) = 9.',
  ], { type: 'balance', s: [2, 3] });
  B('Revisão rápida: números negativos', [
    'Regra dos sinais na multiplicação:',
    '# (+)·(+) = +    (−)·(−) = +',
    '# (+)·(−) = −    (−)·(+) = −',
    'Ex.: (−2) · (−3) = 6',
    'Ex.: (−4)² = (−4) · (−4) = 16',
    'Soma: −5 + 3 = −2 (devia 5, paguei 3, devo 2)',
    'Ex.: −2 − 4 = −6 (devo 2 e devo mais 4)',
    '> Isso será MUITO usado na fórmula de Bhaskara!',
  ], { type: 'numline', s: [5, 6] });
  B('O que é uma função?', [
    'Função é como uma "máquina": você coloca',
    'um número (x) e ela devolve outro, f(x),',
    'sempre seguindo a MESMA regra.',
    'Lê-se f(x) como "f de x".',
    '',
    'Regra: f(x) = 2x + 1',
    'Entra x = 3 → sai 2 · 3 + 1 = 7. Então f(3) = 7.',
    'Entra x = 0 → sai 2 · 0 + 1 = 1. Então f(0) = 1.',
    '> Cada x gera UM ÚNICO resultado.',
  ], { type: 'machine', s: [6, 7] });
  B('O que é uma função quadrática?', [
    'É a função em que o MAIOR expoente do x é 2:',
    '# f(x) = ax² + bx + c',
    'a, b e c são números chamados COEFICIENTES:',
    'a = o número que multiplica x²',
    'b = o número que multiplica x',
    'c = o número sozinho (termo independente)',
    '! Regra de ouro: a ≠ 0 (≠ significa "diferente de").',
    'Se a = 0, sobra bx + c: aí NÃO é quadrática.',
    '> Também é chamada de função do 2º grau.',
  ], { type: 'abc' });
  B('Identificando a, b e c', [
    'f(x) = 2x² + 3x − 5   →   a = 2, b = 3, c = −5',
    'f(x) = x² − 4x + 1   →   a = 1, b = −4, c = 1',
    'f(x) = −x² + 9   →   a = −1, b = 0, c = 9',
    'f(x) = 3x² − 6x   →   a = 3, b = −6, c = 0',
    '',
    '> x² sozinho tem a = 1 (o 1 fica "escondido").',
    '> Se um termo não aparece, ele vale 0.',
    '! O sinal vai junto! Em "− 4x", b = −4 (e não 4).',
    'f(x) = 5x + 2 NÃO é quadrática: não tem x².',
  ]);
  B('Tabela de valores', [
    'Para f(x) = x² − 2x − 3, escolhemos valores de x',
    'e calculamos f(x) trocando o x pelo número:',
    'x = −1: (−1)² − 2·(−1) − 3 = 1 + 2 − 3 = 0',
    'x = 0: 0² − 2·0 − 3 = −3',
    'x = 1: 1² − 2·1 − 3 = 1 − 2 − 3 = −4',
    'x = 2: 2² − 2·2 − 3 = 4 − 4 − 3 = −3',
    'x = 3: 3² − 2·3 − 3 = 9 − 6 − 3 = 0',
    'x = 4: 4² − 2·4 − 3 = 16 − 8 − 3 = 5',
    'Cada par (x, f(x)) vira um PONTO no gráfico.',
  ], { type: 'table', head: ['x', 'f(x)'], rows: [['−1', '0'], ['0', '−3'], ['1', '−4'], ['2', '−3'], ['3', '0'], ['4', '5']], s0: 2 });
  B('Plano cartesiano', [
    'São duas retas numeradas que se cruzam no zero:',
    'eixo x (deitado) e eixo y (em pé).',
    'Um ponto é escrito (x, y). O ponto (2, 3) quer dizer:',
    'ande 2 para a DIREITA e depois 3 para CIMA.',
    'O ponto (−1, 0) fica em cima do eixo x.',
    'Negativo em x: esquerda. Negativo em y: baixo.',
    '> Na função, o y é o resultado: y = f(x).',
  ], { type: 'plane', s: [2, 4] });
  B('Construindo o gráfico', [
    'Marcamos os pontos da tabela:',
    '(−1, 0), (0, −3), (1, −4), (2, −3), (3, 0), (4, 5)',
    'e ligamos com uma curva suave.',
    '',
    'Essa curva se chama PARÁBOLA.',
    'Todo gráfico de função quadrática é uma parábola.',
    '> A parábola é simétrica: os dois lados são',
    'iguais, como um espelho.',
  ], { type: 'parab', a: 1, b: -2, c: -3, xr: [-3, 5], yr: [-5, 7], pts: 1, curve: 2, axis: 6 });
  B('Concavidade: para cima ou para baixo?', [
    'Quem decide é o SINAL do a:',
    '# a > 0 → concavidade para CIMA',
    'Parece um sorriso :) e tem um ponto MÍNIMO.',
    '# a < 0 → concavidade para BAIXO',
    'Parece uma boca triste :( e tem um ponto MÁXIMO.',
    '',
    'Ex.: f(x) = 2x² + 1 → a = 2 > 0 → para cima',
    'Ex.: f(x) = −x² + 4 → a = −1 < 0 → para baixo',
    '> ">" é "maior que"   e   "<" é "menor que".',
  ], { type: 'updown', s: [1, 3] });
  B('Onde a parábola corta o eixo y?', [
    'Troque x por 0:',
    'f(0) = a · 0² + b · 0 + c = c',
    '# A parábola corta o eixo y no ponto (0, c)',
    'Ex.: f(x) = x² − 2x − 3 corta o eixo y em −3.',
    '> É o jeito mais rápido de achar um ponto!',
  ], { type: 'parab', a: 1, b: -2, c: -3, xr: [-3, 5], yr: [-5, 7], curve: 0, cpt: 2 });
  B('Raízes (ou zeros) da função', [
    'Raízes são os valores de x que fazem f(x) = 0.',
    'No gráfico: onde a parábola CORTA o eixo x.',
    'Em f(x) = x² − 2x − 3, a tabela mostrou que',
    'f(−1) = 0 e f(3) = 0.',
    '# Raízes: x = −1 e x = 3',
    'Para achar as raízes sem tabela, resolvemos a',
    'equação do 2º grau:',
    '# ax² + bx + c = 0',
  ], { type: 'parab', a: 1, b: -2, c: -3, xr: [-3, 5], yr: [-5, 7], curve: 0, roots: 1 });
  B('Por que existe uma fórmula? (completar quadrado)', [
    'Lembre da área de um quadrado de lado (x + k):',
    '(x + k)² = x² + 2kx + k²',
    'Ex.: resolver x² + 6x = 7',
    'Somo 9 dos dois lados: x² + 6x + 9 = 7 + 9 = 16',
    'Isso é um quadrado perfeito: (x + 3)² = 16',
    'Tiro a raiz: x + 3 = 4  ou  x + 3 = −4',
    'x = 1  ou  x = −7',
    '> Repetindo isso com letras (a, b, c) no lugar',
    'dos números, chegamos à fórmula de Bhaskara!',
  ], { type: 'completeSq', s: [0, 3] });
  B('A fórmula de Bhaskara', [
    'Resolve qualquer ax² + bx + c = 0.',
    'Passo 1 — calcular o DELTA (Δ):',
    '# Δ = b² − 4 · a · c',
    'Passo 2 — calcular os valores de x:',
    '# x = (−b ± √Δ) ÷ (2 · a)',
    '± quer dizer: faça UMA conta com + e OUTRA com −.',
    'Por isso aparecem duas respostas: x₁ e x₂.',
    '√Δ é a raiz quadrada de Δ: o número que',
    'vezes ele mesmo dá Δ. Ex.: √16 = 4 (4 · 4 = 16).',
  ], { type: 'bhaskara', s: [2, 4] });
  B('Delta (Δ): quantas raízes?', [
    '# Δ > 0 → duas raízes diferentes',
    'A parábola corta o eixo x em 2 pontos.',
    '# Δ = 0 → uma raiz só (duas iguais)',
    'A parábola apenas ENCOSTA no eixo x.',
    '# Δ < 0 → nenhuma raiz real',
    'A parábola não toca o eixo x.',
    '> Não existe raiz quadrada de número negativo',
    'nos números reais. Ex.: √(−9) não existe.',
  ], { type: 'delta3', s: [0, 2, 4] });
  EX('Bhaskara passo a passo', ['Resolva a equação: x² − 5x + 6 = 0'], [
    'Coeficientes: a = 1, b = −5, c = 6',
    'Δ = b² − 4ac = (−5)² − 4 · 1 · 6',
    'Δ = 25 − 24 = 1   (Δ > 0: duas raízes)',
    'x = (−b ± √Δ) ÷ 2a = (5 ± 1) ÷ 2',
    'x₁ = (5 + 1) ÷ 2 = 6 ÷ 2 = 3',
    'x₂ = (5 − 1) ÷ 2 = 4 ÷ 2 = 2',
    '# Raízes: 2 e 3',
    '! −b com b = −5 vira +5 (menos com menos).',
    '> Confira: 3² − 5·3 + 6 = 9 − 15 + 6 = 0 ✓',
  ], { type: 'parab', a: 1, b: -5, c: 6, xr: [-1, 6], yr: [-2, 8], curve: 0, roots: 6 });
  EX('Exercício 8', ['Resolva a equação: 2x² − 8 = 0'], [
    'a = 2, b = 0 (não tem termo em x), c = −8',
    'Δ = 0² − 4 · 2 · (−8) = 0 + 64 = 64',
    '√64 = 8',
    'x = (0 ± 8) ÷ (2 · 2) = ±8 ÷ 4',
    'x₁ = 8 ÷ 4 = 2   e   x₂ = −8 ÷ 4 = −2',
    '# Raízes: −2 e 2',
    '> Atalho: 2x² = 8 → x² = 4 → x = 2 ou x = −2',
  ], { type: 'parab', a: 2, b: 0, c: -8, xr: [-4, 4], yr: [-9, 6], curve: 0, roots: 5 });
  EX('Exercício 9', ['Resolva: x² − 6x + 9 = 0'], [
    'a = 1, b = −6, c = 9',
    'Δ = (−6)² − 4 · 1 · 9 = 36 − 36 = 0',
    'Δ = 0 → uma raiz só',
    'x = (6 ± 0) ÷ 2 = 6 ÷ 2 = 3',
    '# Raiz: x = 3',
    '> A parábola só encosta no eixo x no ponto 3.',
  ], { type: 'parab', a: 1, b: -6, c: 9, xr: [-1, 7], yr: [-2, 9], curve: 0, roots: 4 });
  EX('Exercício 10', ['Quantas raízes reais tem f(x) = x² + 2x + 5?'], [
    'a = 1, b = 2, c = 5',
    'Δ = 2² − 4 · 1 · 5 = 4 − 20 = −16',
    'Δ < 0',
    '# Nenhuma raiz real',
    '> A parábola fica toda acima do eixo x.',
  ], { type: 'parab', a: 1, b: 2, c: 5, xr: [-5, 3], yr: [-2, 10], curve: 3 });
  B('Vértice da parábola', [
    'O vértice é o "bico" da parábola: o ponto mais',
    'baixo (se a > 0) ou o mais alto (se a < 0).',
    '# xv = −b ÷ (2 · a)',
    '# yv = −Δ ÷ (4 · a)   ou calcule f(xv)',
    'Em f(x) = x² − 2x − 3:',
    'xv = −(−2) ÷ (2 · 1) = 2 ÷ 2 = 1',
    'yv = f(1) = 1 − 2 − 3 = −4',
    '# Vértice: (1, −4) → valor mínimo = −4',
    '> O xv fica no meio das raízes: (−1 + 3) ÷ 2 = 1 ✓',
  ], { type: 'parab', a: 1, b: -2, c: -3, xr: [-3, 5], yr: [-5, 7], curve: 0, vertex: 5, roots: 8 });
  EX('Exercício 11 — problema', ['Uma bola é chutada para cima e sua altura é', 'h(t) = −t² + 4t   (h em metros, t em segundos).', 'Qual é a altura máxima da bola?'], [
    'a = −1 < 0 → concavidade para baixo → tem MÁXIMO',
    'O máximo está no vértice: tv = −b ÷ 2a',
    'tv = −4 ÷ (2 · (−1)) = −4 ÷ (−2) = 2 s',
    'h(2) = −(2)² + 4 · 2 = −4 + 8 = 4',
    '# Altura máxima: 4 m (quando t = 2 s)',
    '> Raízes: t = 0 (chute) e t = 4 (a bola cai).',
  ], { type: 'parab', a: -1, b: 4, c: 0, xr: [-1, 5], yr: [-2, 6], curve: 0, vertex: 3, roots: 6, ball: true });
  B('Resumo da Aula 3', [
    '# f(x) = ax² + bx + c   com a ≠ 0',
    'Gráfico: parábola · a > 0 para cima · a < 0 para baixo',
    'Corta o eixo y em (0, c) · Raízes: onde f(x) = 0',
    '# Δ = b² − 4ac',
    '# x = (−b ± √Δ) ÷ 2a',
    'Δ > 0: 2 raízes · Δ = 0: 1 raiz · Δ < 0: nenhuma real',
    '# Vértice: xv = −b ÷ 2a   e   yv = −Δ ÷ 4a',
  ]);
  tagScenes();

  // =====================================================================
  // AULA 4 — ESTATÍSTICA
  // =====================================================================
  CH(4, 'Estatística', 'tabelas, gráficos e medidas', ['Tabelas e gráficos', 'Média', 'Moda', 'Mediana', 'Amplitude']);
  B('O que é estatística?', [
    'Estatística é a parte da matemática que COLETA,',
    'ORGANIZA e INTERPRETA dados.',
    'Dados são informações, geralmente números.',
    'Ex.: notas da turma, temperaturas da semana,',
    'gols de um time, a fruta preferida dos alunos.',
    'Numa pesquisa, perguntamos algo a um grupo',
    'de pessoas e organizamos as respostas.',
    '> VARIÁVEL: aquilo que está sendo pesquisado.',
  ], { type: 'tally', s: [5] });
  B('Lendo tabelas', [
    'Pesquisa: "Qual sua fruta favorita?" (30 alunos)',
    'Cada linha mostra uma resposta e quantas',
    'vezes ela apareceu: a FREQUÊNCIA.',
    'Total: 8 + 12 + 6 + 4 = 30 ✓',
    'Frequência relativa = parte ÷ total:',
    'Banana: 12 ÷ 30 = 0,4 = 40%',
    'Maçã: 8 ÷ 30 ≈ 0,27 ≈ 27%',
    '> Sempre confira se a soma dá o total.',
  ], { type: 'table', head: ['Fruta', 'Alunos'], rows: [['Maçã', '8'], ['Banana', '12'], ['Uva', '6'], ['Manga', '4'], ['Total', '30']], s0: 0, allAt: 1 });
  B('Lendo gráficos', [
    'Gráfico de BARRAS: compara quantidades.',
    'Quanto mais alta a barra, maior o valor.',
    'Leia sempre: o TÍTULO, os EIXOS e a ESCALA.',
    '',
    'Gráfico de SETORES ("pizza"): partes de um todo.',
    'O círculo inteiro vale 100%.',
    'Gráfico de LINHAS: mostra mudança no tempo.',
    '! Cuidado: veja se a escala começa no zero!',
  ], { type: 'charts', s: [0, 4, 6] });
  B('Média aritmética', [
    'Média = "repartir igualmente".',
    '# Média = soma dos valores ÷ quantidade de valores',
    'Notas: 6, 8, 7, 9, 5',
    'Soma: 6 + 8 + 7 + 9 + 5 = 35',
    'Quantidade: 5 notas',
    'Média = 35 ÷ 5 = 7',
    '> Ideia: se todos tirassem a mesma nota e',
    'o total fosse o mesmo (35), cada um tiraria 7.',
  ], { type: 'meanBars', vals: [6, 8, 7, 9, 5], mean: 7, s: [2, 6] });
  B('Média com tabela (média ponderada)', [
    'Quando os valores se repetem, multiplique cada',
    'valor pela sua frequência (quantas vezes aparece).',
    'Nº de irmãos de 10 alunos:',
    '0 irmão: 2 alunos · 1 irmão: 5 · 2 irmãos: 3',
    'Soma = 0·2 + 1·5 + 2·3 = 0 + 5 + 6 = 11',
    'Quantidade = 2 + 5 + 3 = 10 alunos',
    'Média = 11 ÷ 10 = 1,1 irmão',
  ], { type: 'table', head: ['Irmãos', 'Alunos'], rows: [['0', '2'], ['1', '5'], ['2', '3']], s0: 3, allAt: 3 });
  B('Moda', [
    'Moda é o valor que MAIS se repete.',
    'Idades: 13, 14, 14, 15, 14, 13, 16',
    'O 14 aparece 3 vezes → Moda = 14',
    '',
    'Pode haver duas modas (bimodal):',
    '2, 3, 3, 5, 5, 7 → modas: 3 e 5',
    'Ou nenhuma moda (todos aparecem igual):',
    '1, 2, 3, 4 → não tem moda',
    '> Moda = o que "está na moda", o mais comum.',
  ], { type: 'freqBars', data: [['13', 2], ['14', 3], ['15', 1], ['16', 1]], hl: 1, s: [1, 2] });
  B('Mediana', [
    'Mediana é o valor do MEIO, depois de colocar',
    'os dados EM ORDEM (do menor para o maior).',
    'Dados: 7, 2, 9, 4, 5',
    'Em ordem: 2, 4, 5, 7, 9 → mediana = 5',
    'Quantidade PAR? Não existe um só meio:',
    'faça a média dos DOIS valores do meio.',
    '3, 4, 6, 8, 10, 12 → (6 + 8) ÷ 2 = 7',
    '! Erro comum: esquecer de colocar em ORDEM!',
  ], { type: 'median', s: [2, 3, 6] });
  B('Amplitude', [
    'A amplitude mostra o quanto os dados',
    'estão "espalhados".',
    '# Amplitude = maior valor − menor valor',
    'Temperaturas: 18°, 25°, 21°, 30°, 16°',
    'Maior: 30° · Menor: 16°',
    'Amplitude = 30 − 16 = 14°',
    '> Amplitude grande = dados muito diferentes.',
  ], { type: 'temps', vals: [18, 25, 21, 30, 16], s: [3, 4] });
  EX('Exercício 12', ['Gols de um time em 7 jogos: 2, 0, 3, 1, 2, 4, 2.', 'Calcule a média, a moda, a mediana e a amplitude.'], [
    'Soma: 2 + 0 + 3 + 1 + 2 + 4 + 2 = 14',
    'Média = 14 ÷ 7 = 2',
    'Moda = 2 (aparece 3 vezes)',
    'Em ordem: 0, 1, 2, 2, 2, 3, 4',
    'Mediana = o 4º valor (o do meio) = 2',
    'Amplitude = 4 − 0 = 4',
    '# Média 2 · Moda 2 · Mediana 2 · Amplitude 4',
  ], { type: 'freqBars', data: [['0', 1], ['1', 1], ['2', 3], ['3', 1], ['4', 1]], hl: 2, s: [2, 2] });
  EX('Exercício 13', ['Salários numa empresa (R$): 1500, 1500, 2000, 2500, 12 500.', 'O que representa melhor o salário "típico":', 'a média ou a mediana?'], [
    'Soma = 20 000 → Média = 20 000 ÷ 5 = R$ 4000',
    'Mediana (já está em ordem) = R$ 2000',
    'A média ficou alta por causa de UM salário',
    'muito maior que os outros (12 500).',
    '# A mediana (R$ 2000) representa melhor.',
    '> Valores muito diferentes "puxam" a média.',
  ]);
  B('Resumo da Aula 4', [
    '# Média = soma ÷ quantidade',
    '# Moda = valor que mais aparece',
    '# Mediana = valor do meio (com os dados em ordem!)',
    '# Amplitude = maior − menor',
    'Tabela: frequência = quantas vezes aparece',
    'Frequência relativa (%) = parte ÷ total · 100',
    'Gráficos: leia título, eixos e escala.',
  ]);
  tagScenes();

  // =====================================================================
  // AULA 5 — PROBABILIDADE
  // =====================================================================
  CH(5, 'Probabilidade', 'a matemática da chance', ['Eventos e possibilidades', 'Espaço amostral', 'Possível, impossível e certo', 'Calcular probabilidade', 'Fração, decimal e %']);
  B('O que é probabilidade?', [
    'Probabilidade mede a CHANCE de algo acontecer.',
    'Experimento aleatório: não dá para saber o',
    'resultado antes. Ex.: jogar uma moeda, rolar',
    'um dado, sortear um nome.',
    '',
    'A probabilidade vai de 0 a 1 (de 0% a 100%):',
    '0 = nunca acontece · 1 = sempre acontece.',
  ], { type: 'probBar', s: [5] });
  B('Espaço amostral e evento', [
    'ESPAÇO AMOSTRAL (Ω): TODOS os resultados possíveis.',
    'Moeda: Ω = {cara, coroa} → 2 resultados',
    'Dado: Ω = {1, 2, 3, 4, 5, 6} → 6 resultados',
    '',
    'EVENTO: os resultados que nos interessam.',
    'Ex.: "sair número par" no dado:',
    'E = {2, 4, 6} → 3 resultados',
    '> Ω é a letra grega ômega. As chaves { }',
    'servem para listar os elementos (um conjunto).',
  ], { type: 'coinDice', hl: [2, 4, 6], s: [1, 2, 5] });
  B('Possível, impossível e certo', [
    'Evento IMPOSSÍVEL: nunca acontece → P = 0',
    'Ex.: tirar 7 num dado comum.',
    'Evento CERTO: sempre acontece → P = 1',
    'Ex.: tirar um número menor que 7 no dado.',
    'Evento POSSÍVEL: pode ou não acontecer:',
    'fica entre 0 e 1. Ex.: tirar 6 → P = 1/6',
  ], { type: 'probBar', marks: true, s: [0, 2, 4] });
  B('Calculando a probabilidade', [
    '# P = casos favoráveis ÷ casos possíveis',
    'Favoráveis: o que eu QUERO que aconteça.',
    'Possíveis: TUDO o que pode acontecer.',
    '',
    'Dado: P(sair 5) = 1 ÷ 6 = 1/6',
    'Dado: P(sair par) = 3 ÷ 6 = 3/6 = 1/2',
    'Moeda: P(cara) = 1 ÷ 2 = 1/2',
    '! Só vale se todos os resultados tiverem a mesma',
    'chance (dado e moeda "honestos").',
  ], { type: 'coinDice', hl: [5], hl2: [2, 4, 6], s: [0, 0, 4, 5] });
  B('Fração, decimal e porcentagem', [
    'A mesma chance pode ser escrita de 3 jeitos:',
    '1/2 = 0,5 = 50%',
    '1/4 = 0,25 = 25%',
    '3/5 = 0,6 = 60%',
    'Fração → decimal: divida em cima por embaixo (3 ÷ 5 = 0,6).',
    'Decimal → porcentagem: multiplique por 100.',
    '0,6 · 100 = 60%',
    '> "%" significa "de cada 100". 1/6 ≈ 16,7%',
  ], { type: 'fracPie', fr: [[1, 2], [1, 4], [3, 5]], s: [1, 2, 3] });
  B('Simplificando frações', [
    'Divida o de cima e o de baixo pelo MESMO número:',
    '3/6 → (3 ÷ 3) / (6 ÷ 3) = 1/2',
    '4/10 → (4 ÷ 2) / (10 ÷ 2) = 2/5',
    '12/30 → (12 ÷ 6) / (30 ÷ 6) = 2/5',
    '> A fração simplificada vale a mesma coisa!',
    '3/6 e 1/2 são a metade da pizza do mesmo jeito.',
  ], { type: 'fracPie', fr: [[3, 6], [1, 2]], s: [1, 1] });
  B('Exemplos do cotidiano', [
    'Urna com 3 bolas vermelhas e 5 azuis.',
    'Total = 3 + 5 = 8 bolas',
    'P(vermelha) = 3/8 = 0,375 = 37,5%',
    'P(azul) = 5/8 = 0,625 = 62,5%',
    'P(verde) = 0/8 = 0 → impossível',
    '> P(vermelha) + P(azul) = 3/8 + 5/8 = 8/8 = 1',
    'Rifa: comprei 4 dos 100 números.',
    'P(ganhar) = 4/100 = 4%',
  ], { type: 'urn', red: 3, blue: 5, s: [0, 2, 3] });
  B('Dois experimentos juntos', [
    'Duas moedas: Ω = {CC, CK, KC, KK} (C = cara, K = coroa)',
    'São 2 · 2 = 4 resultados.',
    'P(duas caras) = 1/4 = 25%',
    'P(uma cara e uma coroa) = 2/4 = 1/2',
    'Dois dados: 6 · 6 = 36 resultados.',
    'Soma 7: (1,6) (2,5) (3,4) (4,3) (5,2) (6,1)',
    'P(soma 7) = 6/36 = 1/6',
    '> Princípio multiplicativo: multiplique as possibilidades.',
  ], { type: 'diceGrid', s: [4, 5] });
  EX('Exercício 14', ['Numa sala há 12 meninas e 18 meninos.', 'Sorteando um aluno, qual a probabilidade', 'de ser menina? Dê em fração e em %.'], [
    'Possíveis: 12 + 18 = 30 alunos',
    'Favoráveis: 12 meninas',
    'P = 12/30',
    'Simplificando (÷ 6): 12/30 = 2/5',
    '2 ÷ 5 = 0,4 → 0,4 · 100 = 40%',
    '# P = 2/5 = 40%',
  ]);
  EX('Exercício 15', ['Rolando um dado, qual a probabilidade', 'de sair um número maior que 4?'], [
    'Ω = {1, 2, 3, 4, 5, 6} → 6 possíveis',
    'Maior que 4: {5, 6} → 2 favoráveis',
    '! "Maior que 4" NÃO inclui o próprio 4!',
    'P = 2/6 = 1/3 ≈ 33,3%',
    '# P = 1/3',
  ], { type: 'coinDice', hl: [5, 6], noCoin: true, s: [0, 1, 2] });
  B('Resumo da Aula 5', [
    'Espaço amostral (Ω): todos os resultados possíveis',
    'Evento: os resultados que interessam',
    '# P = favoráveis ÷ possíveis',
    '0 ≤ P ≤ 1 · impossível = 0 · certo = 1',
    'Fração → decimal: divida · decimal → %: vezes 100',
    'Experimentos juntos: multiplique (2 · 2, 6 · 6)',
  ]);
  tagScenes();

  // =====================================================================
  // REVISÃO GERAL, FORMULÁRIO, LISTA DE 20 EXERCÍCIOS, GABARITO
  // =====================================================================
  CH(6, 'Revisão geral', 'tudo o que cai na prova', ['Revisão das 5 aulas', 'Formulário', '20 exercícios de prova', 'Gabarito comentado']);
  B('Revisão geral (1/2)', [
    'POLÍGONOS: regular = lados e ângulos iguais.',
    'Soma dos internos (n − 2) · 180°; cada interno = soma ÷ n.',
    'Externo e central = 360° ÷ n. Interno + externo = 180°.',
    'ÁREAS: perímetro é contorno; área é superfície (cm²).',
    'Volume é o espaço ocupado (cm³). 1 m³ = 1000 L.',
    'Círculo: use o RAIO. π ≈ 3,14.',
    'FUNÇÃO QUADRÁTICA: f(x) = ax² + bx + c, com a ≠ 0.',
    'a > 0 → para cima (mínimo); a < 0 → para baixo (máximo).',
  ]);
  B('Revisão geral (2/2)', [
    'Raízes: onde f(x) = 0 → Bhaskara.',
    'Δ > 0: duas raízes · Δ = 0: uma · Δ < 0: nenhuma real.',
    'Vértice: xv = −b ÷ 2a.',
    'ESTATÍSTICA: média = soma ÷ quantidade.',
    'Moda = mais frequente · Mediana = meio (ORDENE!)',
    'Amplitude = maior − menor.',
    'PROBABILIDADE: P = favoráveis ÷ possíveis.',
    'De 0 (impossível) a 1 (certo). Em %: vezes 100.',
  ]);
  B('Formulário (1/2) — Geometria', [
    '# S = (n − 2) · 180°      ai = S ÷ n',
    '# ae = 360° ÷ n      ac = 360° ÷ n      ai + ae = 180°',
    '# Retângulo: A = b · h      Quadrado: A = l²',
    '# Triângulo: A = b · h ÷ 2      Paralelogramo: A = b · h',
    '# Trapézio: A = (B + b) · h ÷ 2      Losango: A = D · d ÷ 2',
    '# Círculo: A = π · r²      C = 2 · π · r',
    '# Hexágono regular: A = 6 · l² · √3 ÷ 4',
    '# Paralelepípedo: V = c · l · h      Cubo: V = a³',
    '# Cilindro: V = π · r² · h      Cone/pirâmide: V = Ab · h ÷ 3',
  ]);
  B('Formulário (2/2) — Funções, estatística e probabilidade', [
    '# f(x) = ax² + bx + c   (a ≠ 0)',
    '# Δ = b² − 4 · a · c',
    '# x = (−b ± √Δ) ÷ (2 · a)',
    '# xv = −b ÷ (2a)      yv = −Δ ÷ (4a)',
    '# Média = soma ÷ quantidade',
    '# Amplitude = maior − menor',
    '# P = casos favoráveis ÷ casos possíveis',
    '> Tire uma foto desta tela para estudar!',
  ]);
  B('Lista de 20 exercícios', [
    'Agora é a sua vez! São 20 questões parecidas',
    'com as de prova, em blocos de 4.',
    'Em cada bloco PAUSE O VÍDEO e resolva no caderno.',
    'O gabarito comentado vem logo depois da lista.',
    '> Também está no arquivo LISTA-E-GABARITO.md.',
  ]);
  const LISTA = [
    'Calcule a soma dos ângulos internos de um heptágono.',
    'Quanto mede cada ângulo interno de um pentágono regular?',
    'Um polígono regular tem ângulo interno de 140°. Quantos lados ele tem?',
    'Quanto mede o ângulo central de um hexágono regular?',
    'Um quadrado tem perímetro de 36 cm. Qual é a sua área?',
    'Calcule a área de um trapézio de bases 10 cm e 6 cm e altura 4 cm.',
    'Calcule a área de um círculo de raio 4 cm (π ≈ 3,14).',
    'Um aquário mede 50 cm × 30 cm × 40 cm. Quantos litros cabem nele?',
    'Calcule o volume de um cilindro com r = 2 m e h = 5 m (π ≈ 3,14).',
    'Um cubo tem volume de 64 cm³. Quanto mede a sua aresta?',
    'Identifique a, b e c em f(x) = −3x² + x − 7.',
    'Calcule f(−2) para f(x) = x² + 3x − 1.',
    'Resolva a equação x² − 7x + 10 = 0.',
    'Calcule Δ e diga quantas raízes tem 4x² − 4x + 1 = 0.',
    'Encontre o vértice da parábola de f(x) = x² − 6x + 5.',
    'f(x) = −2x² + 5x: a concavidade é para cima ou para baixo? Quais as raízes?',
    'Dados: 6, 8, 5, 8, 10, 7, 12, 8. Calcule média, moda, mediana e amplitude.',
    'Nº de irmãos: 4 alunos têm 0, 9 têm 1, 5 têm 2 e 2 têm 3. Qual a média?',
    'Uma urna tem 4 bolas brancas, 6 pretas e 10 verdes. Qual a P(preta) em %?',
    'Jogando duas moedas, qual a probabilidade de sair pelo menos uma cara?',
  ];
  for (let k = 0; k < 5; k++) LIST(`Lista — questões ${k * 4 + 1} a ${k * 4 + 4}`, LISTA.slice(k * 4, k * 4 + 4), k * 4 + 1);
  B('Gabarito (1 a 5)', [
    '1) S = (7 − 2) · 180° = 5 · 180° = 900°',
    '2) S = 540° → ai = 540° ÷ 5 = 108°',
    '3) ae = 180° − 140° = 40° → n = 360° ÷ 40° = 9 lados',
    '4) ac = 360° ÷ 6 = 60°',
    '5) lado = 36 ÷ 4 = 9 cm → A = 9² = 81 cm²',
  ]);
  B('Gabarito (6 a 10)', [
    '6) A = (10 + 6) · 4 ÷ 2 = 16 · 4 ÷ 2 = 32 cm²',
    '7) A = 3,14 · 4² = 3,14 · 16 = 50,24 cm²',
    '8) V = 50 · 30 · 40 = 60 000 cm³ = 60 litros',
    '9) V = 3,14 · 2² · 5 = 3,14 · 4 · 5 = 62,8 m³',
    '10) a³ = 64 → a = 4 cm (pois 4 · 4 · 4 = 64)',
  ]);
  B('Gabarito (11 a 15)', [
    '11) a = −3, b = 1, c = −7',
    '12) f(−2) = (−2)² + 3·(−2) − 1 = 4 − 6 − 1 = −3',
    '13) Δ = 49 − 40 = 9 → x = (7 ± 3) ÷ 2 → x = 5 ou x = 2',
    '14) Δ = 16 − 16 = 0 → uma raiz: x = 4 ÷ 8 = 1/2',
    '15) xv = 6 ÷ 2 = 3; yv = 9 − 18 + 5 = −4 → V(3, −4)',
  ]);
  B('Gabarito (16 a 20)', [
    '16) a = −2 < 0 → para baixo. x(−2x + 5) = 0 → x = 0 ou x = 5/2',
    '17) soma 64 ÷ 8 = média 8 · moda 8 · mediana (8 + 8) ÷ 2 = 8 · amplitude 12 − 5 = 7',
    '18) (0·4 + 1·9 + 2·5 + 3·2) ÷ 20 = 25 ÷ 20 = 1,25',
    '19) total 20 → P = 6/20 = 3/10 = 30%',
    '20) Ω = {CC, CK, KC, KK} → 3 com cara → P = 3/4 = 75%',
  ]);
  { const v = voice('Parabéns por chegar até o final! Reveja as partes difíceis quantas vezes precisar. Errar faz parte de aprender. Bons estudos, você consegue!'); SCENES.push({ kind: 'end', voices: [{ at: 0.8, ...v }], dur: snap(Math.max(13.5, v.d + 4)) }); }
  tagScenes();

  // ---------------- tempos absolutos ----------------
  let t = 0.0;
  SCENES.forEach((s, i) => { s.i = i; s.t0 = t; s.t1 = t + s.dur; t = s.t1; });
  const DURATION = t;
  const CHAPTERS = SCENES.filter((s) => s.kind === 'chapter').map((s) => ({ num: s.num, title: s.title, t: s.t0 }));

  // eventos de som tirados do roteiro (o filme lê os mesmos tempos)
  const ev = { lines: [], scenes: [], ticks: [], bells: [], chapters: [], voice: [] };
  for (const s of SCENES) {
    ev.scenes.push({ t: s.t0, kind: s.kind });
    for (const v of s.voices || []) if (v.key) ev.voice.push({ t: s.t0 + v.at, key: v.key, d: v.d });
    for (const l of s.lines || []) if (l.voice) ev.voice.push({ t: s.t0 + l.at, key: l.voice.key, d: l.voice.d });
    if (s.kind === 'chapter') ev.chapters.push(s.t0);
    for (const l of s.lines || []) if (l.type !== 'b') ev.lines.push({ t: s.t0 + l.at, dur: l.dur, type: l.type, sol: !!s.solution });
    if (s.timer) {
      for (let k = 0; k < Math.round(s.timer.t1 - s.timer.t0); k++) ev.ticks.push(s.timer.t0 + k);
      ev.bells.push(s.timer.t1);
    }
  }

  // ---------------- harmonia (laço lo-fi de 4 compassos) ----------------
  const { chords, chordAt } = makeChords(clock, {
    Fmaj7: { notes: ['A3', 'C4', 'E4'], bass: 'F2' },
    Em7: { notes: ['G3', 'B3', 'D4'], bass: 'E2' },
    Dm7: { notes: ['F3', 'A3', 'C4'], bass: 'D2' },
    Cmaj7: { notes: ['E3', 'G3', 'B3'], bass: 'C2' },
  }, Array.from({ length: 72 }, (_, b) => [b, 0, 4, ['Fmaj7', 'Em7', 'Dm7', 'Cmaj7'][b % 4]]));

  const markers = {};
  CHAPTERS.forEach((c) => { markers['aula' + c.num] = { t: c.t, sync: 'av' }; });
  const firstEx = SCENES.find((s) => s.kind === 'ex');
  markers.pausa1 = firstEx.t0 + firstEx.timer.t0;
  markers.fim = SCENES[SCENES.length - 1].t0;

  const S = {}; // seções para levels.js
  SCENES.forEach((s) => { if (s.kind === 'chapter') S['aula' + s.num] = [s.t0, s.t1]; });

  const SCORE = { FPS, FORMAT, W, H, SAFE, WIDE, STYLE, DURATION, clock, T, BEAT, S, m, chords, chordAt, SCENES, CHAPTERS, ev, markers, PAUSE, NARRATION: [...NARRATION].map(([key, text]) => ({ key, text })) };
  if (node) module.exports = SCORE; else globalThis.SCORE = SCORE;
})();

// Prévia em vídeo: node tools/preview/shoot.js <pasta-saída> [passo] [primeiro] [último]
// (servidor HTTP na raiz do repositório: python3 -m http.server 8765). Gera PNGs numerados; o ffmpeg junta.
const { chromium } = require('playwright');
const out = process.argv[2];
const step = Number(process.argv[3] || 1), first = Number(process.argv[4] || 0);
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const pg = await b.newPage({ viewport: { width: 1280, height: 720 } });
  pg.on('console', m => m.type() === 'error' && console.log('console:', m.text()));
  pg.on('pageerror', e => console.log('pageerror:', e.message));
  await pg.goto('http://localhost:8765/duelo-feiticeiros/tools/preview/render.html');
  await pg.waitForFunction('window.READY === true', null, { timeout: 180000 });
  const n = await pg.evaluate('window.FRAMES');
  const last = Number(process.argv[5] || n - 1);
  let k = 0;
  for (let i = first; i <= last; i += step) {
    await pg.evaluate(i => window.showFrame(i), i);
    await pg.screenshot({ path: `${out}/f${String(k++).padStart(4, '0')}.png` });
    if (k % 50 === 0) console.log('quadro', i, '/', last);
  }
  await b.close();
})();

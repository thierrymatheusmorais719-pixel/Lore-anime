// Gera as imagens de prévia: node tools/preview/shoot.js <pasta-saida> (servidor HTTP na raiz do repositório)
const { chromium } = require('playwright');
const out = process.argv[2];
const base = process.argv[3] || 'http://localhost:8765/mythical-isles/tools/preview/render.html';
const shots = [
  ['ilha', 'scene=island&ground=island&pos=-60,70,150&look=10,0,0&fov=55&fog=420&player=6,3,30&hud=1&shadow=200'],
  ['ilha_alto', 'scene=island&ground=island&pos=-330,260,330&look=0,-10,20&fov=45&shadow=280&title=Verdant%20Haven'],
  ['arena_boss', 'scene=island&ground=island&pos=-40,45,30&look=0,10,140&fov=55&shadow=200&title=Arena%20do%20Elderroot'],
  ['pets', 'scene=pets&pos=21,24,62&look=21,1,14&fov=50&title=Os%2034%20pets&floor=%2398d878'],
  ['mutacoes', 'scene=mutations&pos=24,11,44&look=24,2,0&fov=50&title=Astral%20Lion:%20normal%20e%206%20muta%C3%A7%C3%B5es&floor=%23b0a0e0'],
  ['inimigos', 'scene=enemies&pos=32,22,62&look=32,3,14&fov=52&title=Inimigos&floor=%23a8c890'],
  ['bosses', 'scene=bosses&pos=100,30,125&look=100,12,0&fov=58&title=Os%205%20bosses&floor=%23a8b8d0'],
];
(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  page.on('console', m => { if (m.type() === 'error') console.log('console:', m.text()); });
  page.on('pageerror', e => console.log('pageerror:', e.message));
  for (const [name, qs] of shots) {
    await page.goto(`${base}?${qs}`);
    await page.waitForFunction(() => window.READY === true, null, { timeout: 120000 });
    await page.waitForTimeout(300);
    await page.screenshot({ path: `${out}/${name}.png` });
    console.log('ok', name);
  }
  await browser.close();
})();

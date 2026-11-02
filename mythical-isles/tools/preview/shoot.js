// Gera as imagens de prévia: node tools/preview/shoot.js <pasta-saida> (servidor HTTP na raiz do repositório)
const { chromium } = require('playwright');
const out = process.argv[2];
const base = process.argv[3] || 'http://localhost:8765/mythical-isles/tools/preview/render.html';
const shots = [
  ['ilha', 'scene=island&ground=terrain&pos=-60,70,150&look=10,0,0&fov=55&fog=420&player=6,3,30&hud=1&shadow=200'],
  ['ilha_alto', 'scene=island&ground=terrain&pos=-330,260,330&look=0,-10,20&fov=45&shadow=280&title=Verdant%20Haven'],
  ['arena_boss', 'scene=island&ground=terrain&pos=-40,45,30&look=0,10,140&fov=55&shadow=200&title=Arena%20do%20Elderroot'],
  ['lago_arvore', 'scene=island&ground=terrain&pos=-55,32,30&look=-130,22,108&fov=58&fog=500&shadow=180&title=Mundo%201%20-%20%C3%81rvore%20Ancestral'],
  ['lago_alto', 'scene=island&ground=terrain&pos=-30,95,-10&look=-125,8,105&fov=55&shadow=200&title=Lago%20e%20cachoeiras'],
  ['pets_mundo1', 'scene=pets_verdant&pos=34,40,98&look=34,1,32&fov=55&title=Mundo%201%20-%20Verdant%20Haven%3A%2080%20pets&floor=%2398d878'],
  ['pets_mundo2', 'scene=pets_crystal&pos=34,40,98&look=34,1,32&fov=55&title=Mundo%202%20-%20Crystal%20Hollow%3A%2080%20pets&skytop=%230a0618&skybot=%23281c4a&floor=%23202040'],
  ['mutacoes', 'scene=mutations&pos=24,11,44&look=24,2,0&fov=50&title=Astral%20Lion:%20normal%20e%206%20muta%C3%A7%C3%B5es&floor=%23b0a0e0'],
  ['inimigos', 'scene=enemies&pos=32,22,62&look=32,3,14&fov=52&title=Inimigos&floor=%23a8c890'],
  ['boss_elderroot', 'scene=bosses&pos=0,18,46&look=0,14,0&fov=50&title=Elderroot&skytop=%230a0618&skybot=%23281c4a&floor=%23181428'],
  ['boss_prism_titan', 'scene=bosses&pos=50,18,46&look=50,14,0&fov=50&title=Prism%20Titan&skytop=%230a0618&skybot=%23281c4a&floor=%23181428'],
  ['boss_tempest_wyrm', 'scene=bosses&pos=125,30,82&look=125,16,0&fov=50&title=Tempest%20Wyrm&skytop=%230a0618&skybot=%23281c4a&floor=%23181428'],
  ['boss_wilderbloom', 'scene=bosses&pos=205,22,56&look=205,9,0&fov=50&title=The%20Wilderbloom&skytop=%230a0618&skybot=%23281c4a&floor=%23181428'],
  ['boss_void_sovereign', 'scene=bosses&pos=265,18,48&look=265,14,0&fov=50&title=Void%20Sovereign&skytop=%230a0618&skybot=%23281c4a&floor=%23181428'],
  ['bosses', 'scene=bosses&pos=132,40,175&look=132,14,0&fov=58&title=Os%205%20bosses&skytop=%230a0618&skybot=%23281c4a&floor=%23181428'],
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

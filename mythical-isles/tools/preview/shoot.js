// Gera as imagens de prévia: node tools/preview/shoot.js <pasta-saida> (servidor HTTP na raiz do repositório)
const { chromium } = require('playwright');
const out = process.argv[2];
const base = process.argv[3] || 'http://localhost:8765/mythical-isles/tools/preview/render.html';
const shots = [
  ['ilha', 'scene=island&ground=terrain&pos=-60,70,150&look=10,0,0&fov=55&atmo=0.0016&player=6,3,30&hud=1&shadow=200'],
  ['ilha_chao', 'scene=island&ground=terrain&pos=-20,9,-60&look=60,5,-130&fov=60&atmo=0.0022&shadow=160&title=Verdant%20Haven'],
  ['ilha_alto', 'scene=island&ground=terrain&pos=-330,260,330&look=0,-10,20&fov=45&shadow=280&atmo=0.0008&title=Verdant%20Haven'],
  ['arena_boss', 'scene=island&ground=terrain&pos=-40,45,30&look=0,10,140&fov=55&shadow=200&title=Arena%20do%20Elderroot'],
  ['lago_arvore', 'scene=island&ground=terrain&pos=-55,32,30&look=-130,22,108&fov=58&atmo=0.0016&shadow=180&title=Mundo%201%20-%20%C3%81rvore%20Ancestral'],
  ['lago_alto', 'scene=island&ground=terrain&pos=-30,95,-10&look=-125,8,105&fov=55&shadow=200&title=Lago%20e%20cachoeiras'],
  ['ceu_verdant', 'scene=island&ground=terrain&sky=verdant&pos=-40,14,60&look=60,40,-90&fov=70&atmo=0.0012&shadow=200&sun=300,35&title=Verdant%20Haven%20-%20Manh%C3%A3%20Esmeralda'],
  ['ceu_crystal', 'scene=crystal&ground=voxel&tfile=terrain_crystal&vcenter=1400,0,262&sky=crystal&pos=1372,14,-28&look=1530,50,130&fov=70&shadow=220&atmo=0.0012&sun=20,38&title=Crystal%20Hollow%20-%20Tarde%20Safira'],
  ['ceu_sky', 'scene=island&ground=terrain&sky=sky&pos=-40,14,60&look=60,30,-90&fov=70&atmo=0.0012&shadow=200&sun=300,12&title=C%C3%A9u%20do%20Skybound%20Kingdom%20(sobre%20a%20ilha%201%2C%20para%20comparar)'],
  ['ceu_wilds', 'scene=island&ground=terrain&sky=wilds&pos=-40,14,60&look=60,30,-90&fov=70&atmo=0.0012&shadow=200&sun=300,8&title=C%C3%A9u%20do%20Whispering%20Wilds%20(sobre%20a%20ilha%201%2C%20para%20comparar)'],
  ['ceu_astral', 'scene=island&ground=terrain&sky=astral&pos=-40,14,60&look=60,40,-90&fov=70&atmo=0.0012&shadow=200&sun=300,40&title=C%C3%A9u%20do%20Astral%20Sanctuary%20(sobre%20a%20ilha%201%2C%20para%20comparar)'],
  ['pets_perto', 'scene=showcase&pos=15,10,36&look=15,1.6,3.5&fov=42&title=Pets%20de%20perto&floor=%2398d878&shadow=40'],
  ['pets_perto2', 'scene=showcase&pos=6.5,3.4,10.5&look=3,1.3,4.5&fov=45&floor=%2398d878&shadow=30'],
  ['crystal_alto', 'scene=crystal&ground=voxel&tfile=terrain_crystal&vcenter=1400,0,262&pos=1110,250,-280&look=1400,0,40&fov=50&shadow=320&atmo=0.0007&title=Crystal%20Hollow%20-%20Mundo%202'],
  ['crystal_vale', 'scene=crystal&ground=voxel&tfile=terrain_crystal&vcenter=1400,0,262&pos=1372,12,-28&look=1530,40,130&fov=62&shadow=220&atmo=0.0016&title=Crystal%20Valley'],
  ['crystal_picos', 'scene=crystal&ground=voxel&tfile=terrain_crystal&vcenter=1400,0,262&pos=1470,22,60&look=1545,50,150&fov=62&shadow=220&atmo=0.0012&title=Shattered%20Peaks'],
  ['crystal_lago', 'scene=crystal&ground=voxel&tfile=terrain_crystal&vcenter=1400,0,262&pos=1330,24,52&look=1262,4,122&fov=60&shadow=200&atmo=0.0014&title=Prism%20Lake'],
  ['crystal_caverna', 'scene=crystal&ground=voxel&tfile=terrain_crystal&vcenter=1400,0,262&vcut=1214.5,-49.7,48,1.5&pos=1262,62,-6&look=1210,0,-52&fov=55&shadow=120&title=Azure%20Caverns%20(corte%20do%20interior)'],
  ['crystal_titan', 'scene=crystal&ground=voxel&tfile=terrain_crystal&vcenter=1400,0,262&pos=1400,28,30&look=1400,14,200&fov=60&shadow=240&atmo=0.0012&title=Titan%27s%20Domain'],
  ['sky_alto', 'scene=sky&ground=voxel&tfile=terrain_sky&vcenter=2800,0,410&vy=20,250&sky=sky&storm=1&pos=2420,360,-440&look=2800,150,60&fov=55&shadow=480&atmo=0.0005&sun=200,40&title=Skybound%20Kingdom%20-%20Mundo%203'],
  ['sky_porto', 'scene=sky&ground=voxel&tfile=terrain_sky&vcenter=2800,0,410&vy=20,250&sky=sky&storm=1&pos=2786,174,30&look=3032,166,-62&fov=62&shadow=240&atmo=0.001&sun=150,35&title=Cloud%20Harbor'],
  ['sky_alturas', 'scene=sky&ground=voxel&tfile=terrain_sky&vcenter=2800,0,410&vy=20,250&sky=sky&storm=1&pos=2950,180,128&look=3070,210,182&fov=62&shadow=240&atmo=0.0009&sun=200,40&title=Golden%20Heights'],
  ['sky_tempestade', 'scene=sky&ground=voxel&tfile=terrain_sky&vcenter=2800,0,410&vy=20,250&sky=sky&storm=1&pos=2796,182,-196&look=2782,168,-320&fov=64&shadow=260&atmo=0.0012&sun=60,35&title=Storm%20Islands'],
  ['sky_jardins', 'scene=sky&ground=voxel&tfile=terrain_sky&vcenter=2800,0,410&vy=20,250&sky=sky&storm=1&pos=2614,180,64&look=2516,172,104&fov=64&shadow=240&atmo=0.001&sun=300,40&title=Celestial%20Gardens'],
  ['sky_arena', 'scene=sky&ground=voxel&tfile=terrain_sky&vcenter=2800,0,410&vy=20,250&sky=sky&storm=1&pos=2800,190,36&look=2800,176,200&fov=62&shadow=260&atmo=0.001&sun=270,35&title=Tempest%20Arena'],
  ['arvore_destaque', 'scene=island&ground=terrain&sky=verdant&pos=124,12,106&look=94,16,73&fov=60&shadow=80&atmo=0.001&sun=200,40&title=Verdant%20Haven%20-%20%C3%81rvore%20de%20destaque'],
  ['arvore_bosque', 'scene=island&ground=terrain&sky=verdant&pos=40,60,10&look=118,6,120&fov=60&shadow=200&atmo=0.0008&sun=200,40&title=Bosque%20da%20%C3%A1rvore%20de%20blocos%20(Mundo%201)'],
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
  const only = process.env.ONLY ? process.env.ONLY.split(',') : null;
  for (const [name, qs] of shots) {
    if (only && !only.includes(name)) continue;
    await page.goto(`${base}?${qs}`);
    await page.waitForFunction(() => window.READY === true, null, { timeout: 120000 });
    await page.waitForTimeout(300);
    await page.screenshot({ path: `${out}/${name}.png` });
    console.log('ok', name);
  }
  await browser.close();
})();

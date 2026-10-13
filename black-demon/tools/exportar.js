// Exporta o episódio para MP4 1080p (30 qps) com a trilha sintetizada.
// Requer: Node 18+, `npm i playwright` e ffmpeg no PATH.
// Uso (na raiz do repositório, com um servidor local rodando na porta 8000):
//   python3 -m http.server 8000 &
//   node black-demon/tools/exportar.js http://localhost:8000/black-demon/ black-demon.mp4
const { chromium } = require('playwright');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

(async () => {
  const [url = 'http://localhost:8000/black-demon/', out = 'black-demon.mp4', fpsArg = '30'] = process.argv.slice(2);
  const fps = +fpsArg;
  const tmp = fs.mkdtempSync(path.join(process.env.FRAMES_DIR || os.tmpdir(), 'black-demon-'));
  const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  page.on('pageerror', (e) => console.error('erro na página:', e.message));
  await page.goto(url + (url.includes('?') ? '&' : '?') + 'export');
  await page.waitForFunction(() => window.__film && window.__film.ready, null, { timeout: 60000 });

  const dur = await page.evaluate(() => window.__film.duration);
  const total = Math.round(dur * fps);
  for (let i = 0; i < total; i++) {
    const data = await page.evaluate((t) => {
      window.__film.draw(t);
      return document.getElementById('film').toDataURL('image/jpeg', 0.94);
    }, i / fps);
    fs.writeFileSync(path.join(tmp, `q${String(i).padStart(5, '0')}.jpg`), Buffer.from(data.split(',')[1], 'base64'));
    if (i % fps === 0) process.stdout.write(`\rquadros: ${i}/${total}`);
  }
  console.log('\náudio...');
  const wav = await page.evaluate(() => window.__film.wav());
  fs.writeFileSync(path.join(tmp, 'trilha.wav'), Buffer.from(wav, 'base64'));
  await browser.close();

  execFileSync('ffmpeg', [
    '-y', '-loglevel', 'error', '-framerate', String(fps), '-i', path.join(tmp, 'q%05d.jpg'),
    '-i', path.join(tmp, 'trilha.wav'),
    '-c:v', 'libx264', '-preset', 'slow', '-crf', process.env.CRF || '23', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
    '-c:a', 'aac', '-b:a', '192k', '-shortest', out,
  ], { stdio: 'inherit' });
  fs.rmSync(tmp, { recursive: true, force: true });
  console.log('pronto:', out);
})();

// ============================================================================
//  Ponto de entrada: renderer, pós-processamento, loop e controles
// ============================================================================
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

import { CONFIG } from './config.js';
import { Lore } from './character.js';
import { Environment } from './environment.js';
import { FX } from './effects/index.js';
import { CameraDirector } from './camera.js';
import { Timeline } from './timeline.js';
import { AudioEngine } from './audio.js';
import { buildCutscene } from './cutscene.js';

const $ = (id) => document.getElementById(id);
const params = new URLSearchParams(location.search);

function showError(err) {
  console.error(err);
  const el = $('error');
  el.textContent = 'Erro ao iniciar a cutscene:\n' + (err && err.stack ? err.stack : err);
  el.hidden = false;
}

// ---------------------------------------------------------------------------
//  Renderer e cena
// ---------------------------------------------------------------------------
const canvas = $('scene');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, CONFIG.quality.pixelRatioCap));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = CONFIG.post.exposure;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.shadowMap.enabled = CONFIG.quality.shadows;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(36, window.innerWidth / window.innerHeight, 0.05, 600);
camera.position.set(5, 1.5, 10);

// ---------------------------------------------------------------------------
//  Pós-processamento: bloom + passe cinematográfico (vinheta, aberração, grão)
// ---------------------------------------------------------------------------
const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(
  new THREE.Vector2(window.innerWidth, window.innerHeight),
  CONFIG.post.bloomStrength, CONFIG.post.bloomRadius, CONFIG.post.bloomThreshold,
);
composer.addPass(bloom);
const cinematic = new ShaderPass({
  uniforms: {
    tDiffuse: { value: null },
    uAberration: { value: 0 },
    uVignette: { value: CONFIG.post.vignette },
    uTime: { value: 0 },
  },
  vertexShader: /* glsl */`
    varying vec2 vUv;
    void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
  fragmentShader: /* glsl */`
    uniform sampler2D tDiffuse; uniform float uAberration; uniform float uVignette; uniform float uTime;
    varying vec2 vUv;
    float hash(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
    void main(){
      vec2 d = vUv - 0.5;
      vec2 off = d * (0.002 + uAberration * 0.007);
      vec3 col;
      col.r = texture2D(tDiffuse, vUv + off).r;
      col.g = texture2D(tDiffuse, vUv).g;
      col.b = texture2D(tDiffuse, vUv - off).b;
      float r = length(d * vec2(1.0, 0.8));
      col *= mix(1.0, smoothstep(0.85, 0.25, r), uVignette);
      col += (hash(vUv * 900.0 + uTime) - 0.5) * 0.025;
      gl_FragColor = vec4(col, 1.0);
    }`,
});
composer.addPass(cinematic);
composer.addPass(new OutputPass());

// ---------------------------------------------------------------------------
//  Interface (título, legendas, clarão, fade)
// ---------------------------------------------------------------------------
const ui = {
  flashLevel: 0,
  aberrationLevel: 0,
  fadeVal: 1, fadeTarget: 1, fadeSpeed: 1,
  flash(a) { this.flashLevel = Math.min(1, Math.max(this.flashLevel, a)); },
  aberration(a) { this.aberrationLevel = Math.max(this.aberrationLevel, a); },
  fade(target, dur = 1) { this.fadeTarget = target; this.fadeSpeed = 1 / Math.max(0.01, dur); },
  title(show) { $('title-card').classList.toggle('show', show); },
  subtitle(text) {
    const el = $('subtitle');
    if (!CONFIG.cutscene.showSubtitles) return;
    if (text) { el.textContent = text; el.classList.add('show'); } else el.classList.remove('show');
  },
  reset() {
    this.flashLevel = 0; this.aberrationLevel = 0; this.fadeVal = 1; this.fadeTarget = 1;
    this.title(false); this.subtitle(null);
  },
  update(dt) {
    this.flashLevel = Math.max(0, this.flashLevel - dt * 2.8);
    this.aberrationLevel = Math.max(0, this.aberrationLevel - dt * 2.5);
    const d = this.fadeTarget - this.fadeVal;
    this.fadeVal += Math.sign(d) * Math.min(Math.abs(d), dt * this.fadeSpeed);
    $('flash').style.opacity = (this.flashLevel * this.flashLevel * 0.7).toFixed(3);
    $('fade').style.opacity = this.fadeVal.toFixed(3);
    cinematic.uniforms.uAberration.value = this.aberrationLevel;
    bloom.strength = CONFIG.post.bloomStrength + this.flashLevel * 0.35;
  },
};

// ---------------------------------------------------------------------------
//  Montagem da cena
// ---------------------------------------------------------------------------
const env = new Environment(scene);
const lore = new Lore(scene);
const director = new CameraDirector(camera);
const audio = new AudioEngine();
const fx = new FX(scene, {
  shake: (a) => director.shake(a),
  flash: (a) => ui.flash(a),
  aberration: (a) => ui.aberration(a),
  audio,
  env,
});
const tl = new Timeline();

const state = {
  time: 0,
  playing: false,
  started: false,
  timeScale: 1,
  slowmoLeft: 0,
  freeCam: false,
};

const ctx = {
  tl, lore, fx, director, audio, ui, env, camera, scene,
  /** Câmera lenta (hit-stop) por `dur` segundos reais. */
  slowmo(scale, dur) { state.timeScale = scale; state.slowmoLeft = dur; },
};
buildCutscene(ctx);

// Controles de câmera livre (tecla C)
const controls = new OrbitControls(camera, canvas);
controls.enabled = false;
controls.target.set(0, 1.2, 0);
controls.enableDamping = true;

// ---------------------------------------------------------------------------
//  Simulação
// ---------------------------------------------------------------------------
function step(dt) {
  // câmera lenta
  if (state.slowmoLeft > 0) {
    state.slowmoLeft -= dt;
    if (state.slowmoLeft <= 0) state.timeScale = 1;
  }
  const sdt = dt * state.timeScale;
  state.time += sdt;
  tl.update(sdt, state.time);
  lore.update(sdt, state.time);
  env.update(sdt, state.time);
  fx.beam.update(sdt, state.time);
  director.update(sdt, state.time);
  fx.update(sdt, state.time, camera, renderer.domElement.height);
  ui.update(dt); // tempo real: clarões não se arrastam na câmera lenta

  if (state.time >= CONFIG.cutscene.duration) {
    if (CONFIG.cutscene.loop) restart();
    else state.playing = false;
  }
}

function restart() {
  state.time = 0;
  state.timeScale = 1;
  state.slowmoLeft = 0;
  tl.reset();
  lore.reset();
  fx.clear();
  director.reset();
  env.reset();
  ui.reset();
}

/** Pula para um instante simulando os quadros intermediários (sem som). */
function seek(t) {
  t = Math.max(0, Math.min(CONFIG.cutscene.duration - 0.05, t));
  const wasEnabled = audio.enabled;
  audio.enabled = false;
  restart();
  const h = 1 / 30;
  while (state.time + h < t) step(h);
  audio.enabled = wasEnabled;
}

// ---------------------------------------------------------------------------
//  Loop principal
// ---------------------------------------------------------------------------
const clock = new THREE.Clock();
const hudTime = $('hud-time');
function frame() {
  requestAnimationFrame(frame);
  const dt = Math.min(clock.getDelta(), 1 / 20);
  if (state.playing) step(dt);
  else lore.update(0, state.time); // mantém pose consistente quando pausado
  if (state.freeCam) controls.update();
  cinematic.uniforms.uTime.value = performance.now() * 0.001;
  composer.render();
  hudTime.textContent = state.time.toFixed(1).padStart(4, '0') + 's' + (state.playing ? '' : ' ⏸');
}

// ---------------------------------------------------------------------------
//  Eventos
// ---------------------------------------------------------------------------
function onResize() {
  const w = window.innerWidth, h = window.innerHeight;
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  renderer.setSize(w, h);
  composer.setSize(w, h);
  bloom.resolution.set(w, h);
}
window.addEventListener('resize', onResize);

function start() {
  if (state.started) return;
  state.started = true;
  if ($('opt-sound').checked && !params.has('nosound')) {
    try { audio.init(); } catch (e) { console.warn('Áudio indisponível:', e); }
  }
  $('start').classList.add('hidden');
  restart();
  const t0 = parseFloat(params.get('t'));
  if (t0 > 0) seek(t0);
  state.playing = true;
}

window.addEventListener('keydown', (e) => {
  if (!state.started) { if (e.code === 'Enter' || e.code === 'Space') start(); return; }
  switch (e.code) {
    case 'Space': state.playing = !state.playing; e.preventDefault(); break;
    case 'KeyR': restart(); state.playing = true; break;
    case 'KeyC':
      state.freeCam = !state.freeCam;
      director.enabled = !state.freeCam;
      controls.enabled = state.freeCam;
      if (state.freeCam) controls.target.copy(director.lookAt);
      break;
    case 'KeyM': audio.toggleMute(); break;
    case 'KeyH': document.body.classList.toggle('hide-hud'); break;
    case 'KeyL': document.body.classList.toggle('no-letterbox'); break;
    case 'ArrowRight': seek(state.time + 5); break;
    case 'ArrowLeft': seek(state.time - 5); break;
    default: break;
  }
});

$('start-btn').addEventListener('click', start);
$('start-btn').disabled = false;
$('loading').textContent = 'Pronto.';

// Primeiro quadro (ainda atrás da tela inicial) para compilar shaders.
lore.update(0, 0);
director.update(0, 0);
try {
  composer.render();
} catch (e) {
  showError(e);
}

window.__LORE_READY__ = true;
frame();

if (params.has('autoplay')) start();

// Exposto para experimentos no console (ex.: LORE.lore.setPose('raise'))
window.LORE = { THREE, scene, camera, renderer, lore, fx, director, tl, ui, env, audio, state, seek, restart, CONFIG };

window.addEventListener('error', (e) => showError(e.error || e.message));

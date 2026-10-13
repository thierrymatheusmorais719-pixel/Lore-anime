// Player: relógio sincronizado com o áudio, controles e modo de exportação.
import { load, render, DURATION, shotAt } from './film.js';
import { makeMixer, schedule, renderWav } from './audio.js';

const $ = (id) => document.getElementById(id);
const canvas = $('film');
const ctx = canvas.getContext('2d');
const params = new URLSearchParams(location.search);
const EXPORT = params.has('export');

// resolução interna: 1080p; telas pequenas usam 720p para manter a fluidez
const Q = EXPORT ? 1 : (Math.min(window.innerWidth, 1400) < 900 ? 2 / 3 : 1);
canvas.width = 1920 * Q;
canvas.height = 1080 * Q;

function draw(t) {
  ctx.setTransform(Q, 0, 0, Q, 0, 0);
  render(ctx, t);
}

// ---- estado de reprodução ------------------------------------------------------
let ac = null, mixer = null, session = null;
let playing = false, ended = false;
let offset = 0;          // segundo do filme em que a reprodução (re)começou
let origin = 0;          // instante do relógio correspondente a "offset"
let scheduledTo = 0;     // até onde a partitura já foi agendada
let pausedAt = 0;

const clock = () => (ac ? ac.currentTime : performance.now() / 1000);
const filmTime = () => (playing ? offset + (clock() - origin) : pausedAt);

function ensureAudio() {
  if (ac) return;
  try {
    ac = new (window.AudioContext || window.webkitAudioContext)();
    mixer = makeMixer(ac);
    applyMutes();
  } catch { ac = null; }
}

function applyMutes() {
  if (!mixer) return;
  mixer.bus.sfx.gain.value = $('sfx').checked ? 1 : 0;
  mixer.bus.music.gain.value = $('music').getAttribute('aria-pressed') === 'true' ? 1 : 0;
}

function newSession() {
  if (session) { session.music.disconnect(); session.sfx.disconnect(); }
  if (!mixer) { session = null; return; }
  session = { music: ac.createGain(), sfx: ac.createGain() };
  session.music.connect(mixer.bus.music);
  session.sfx.connect(mixer.bus.sfx);
}

function playFrom(t) {
  ensureAudio();
  if (ac && ac.state === 'suspended') ac.resume();
  t = Math.max(0, Math.min(DURATION - 0.05, t));
  newSession();
  offset = t;
  origin = clock() + 0.06;
  scheduledTo = t;
  if (session) { schedule(ac, session, origin, offset, -Infinity, t + 1.2); scheduledTo = t + 1.2; }
  playing = true;
  ended = false;
  $('overlay').hidden = true;
}

function pause() {
  if (!playing) return;
  pausedAt = filmTime();
  playing = false;
  if (session) { session.music.disconnect(); session.sfx.disconnect(); session = null; }
}

function toggle() {
  if (playing) pause();
  else playFrom(ended ? startValue() : pausedAt);
}

function seek(t) {
  if (playing) playFrom(t);
  else { pausedAt = Math.max(0, Math.min(DURATION - 0.05, t)); ended = false; }
}

const startValue = () => Math.max(0, Math.min(DURATION - 1, parseFloat($('startAt').value) || 0));

// ---- laço ------------------------------------------------------------------------
let lastShot = '';
function frame() {
  let t = filmTime();
  if (playing && t >= DURATION) {
    pause();
    pausedAt = DURATION - 0.01;
    ended = true;
    t = pausedAt;
  }
  if (playing && session && scheduledTo < t + 1.2 && scheduledTo < DURATION) {
    schedule(ac, session, origin, offset, scheduledTo, t + 1.2);
    scheduledTo = t + 1.2;
  }
  draw(t);
  $('time').textContent = t.toFixed(1).replace('.', ',') + ' s';
  $('fill').style.width = (100 * t / DURATION) + '%';
  $('progress').setAttribute('aria-valuenow', t.toFixed(1));
  const s = shotAt(t);
  const label = s.nome || (s.id === 'abertura' ? 'Abertura' : 'Encerramento');
  if (label !== lastShot) { $('shot').textContent = label.toUpperCase(); lastShot = label; }
  $('preview').classList.toggle('live', playing);
  requestAnimationFrame(frame);
}

// ---- controles --------------------------------------------------------------------
function wire() {
  $('overlay').addEventListener('click', () => playFrom(startValue()));
  $('replay').addEventListener('click', () => playFrom(startValue()));
  $('preview').addEventListener('click', toggle);
  $('sfx').addEventListener('change', applyMutes);
  $('music').addEventListener('click', (e) => {
    const b = e.currentTarget;
    b.setAttribute('aria-pressed', b.getAttribute('aria-pressed') === 'true' ? 'false' : 'true');
    applyMutes();
  });
  $('startAt').addEventListener('change', () => { $('startAt').value = startValue(); if (!playing) seek(startValue()); });
  const bar = $('progress');
  const seekEvt = (e) => {
    const r = bar.getBoundingClientRect();
    seek(((e.clientX - r.left) / r.width) * DURATION);
    $('overlay').hidden = true;
  };
  bar.addEventListener('pointerdown', (e) => { e.stopPropagation(); seekEvt(e); if (!playing) playFrom(pausedAt); });
  canvas.addEventListener('click', toggle);
  window.addEventListener('keydown', (e) => {
    if (e.target.tagName === 'INPUT' && e.target.type === 'number') return;
    if (e.code === 'Space') { e.preventDefault(); $('overlay').hidden ? toggle() : playFrom(startValue()); }
    else if (e.key === 'f' || e.key === 'F') {
      const st = $('stage');
      document.fullscreenElement ? document.exitFullscreen() : st.requestFullscreen?.();
    } else if (e.key === 'ArrowRight') seek(filmTime() + 2);
    else if (e.key === 'ArrowLeft') seek(filmTime() - 2);
  });
}

async function boot() {
  if (params.has('t')) { $('startAt').value = parseFloat(params.get('t')) || 0; pausedAt = startValue(); }
  await Promise.all([
    document.fonts.load('200px "Pirata One"'),
    document.fonts.load('700 90px "Oswald"'),
    document.fonts.load('500 40px "Oswald"'),
  ]).catch(() => {});
  await load('assets/');
  if (EXPORT) {
    document.body.classList.add('export');
    window.__film = { draw, wav: renderWav, duration: DURATION, ready: true };
    draw(0);
    return;
  }
  wire();
  requestAnimationFrame(frame);
}

boot();

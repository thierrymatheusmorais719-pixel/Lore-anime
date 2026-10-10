// ============================================================================
//  ROTEIRO DA CUTSCENE — "Lore, o Rei Mago"
// ============================================================================
//  Planos (≈34 s):
//   A  0.0–5.0   Abertura: dolly lento até Lore na arena em ruínas + título
//   B  5.0–8.5   Close-up: os olhos dourados despertam
//   C  8.5–11.3  Carga: círculo mágico, energia sugada para o orbe do cajado
//   D 11.3–14.2  Tempestade: raios caem ao redor; um raio atinge o cajado
//   E 14.2–18.5  O golpe: cajado cravado no chão → explosão + onda de choque
//   F 18.5–23.8  Ascensão: levitação, pilar de luz, raios de energia, órbita
//   G 23.8–27.3  O feixe: disparo de energia contra as rochas distantes
//   H 27.3–34.0  Desfecho: pouso, fumaça se dissipando, título final
//  Altere tempos, poses e efeitos aqui para refinar a cena.
import * as THREE from 'three';
import { ease, rand, randomDir } from './utils.js';

const V = (x, y, z) => new THREE.Vector3(x, y, z);

export function buildCutscene(ctx) {
  const { tl, lore, fx, director, audio, ui, env } = ctx;
  const P = lore.params;
  const tmp = new THREE.Vector3();

  // Atalhos relativos ao personagem
  const head = () => lore.focus('head', 0.1);
  const chest = () => lore.focus('chest', 0.15);
  const rel = (fn, dx, dy, dz) => () => fn().add(tmp.set(dx, dy, dz));

  // --------------------------------------------------------------------------
  //  CÂMERA
  // --------------------------------------------------------------------------
  director.setShots([
    { start: 0, end: 5.0, ease: ease.inOutSine,
      from: { pos: V(5.5, 0.9, 11), target: V(0, 1.25, 0), fov: 34 },
      to:   { pos: V(2.5, 0.7, 5.0), target: V(0, 1.45, 0), fov: 31 } },
    { start: 5.0, end: 8.5, ease: ease.outCubic,
      from: { pos: rel(head, 0.55, 0.02, 1.3), target: head, fov: 30 },
      to:   { pos: rel(head, 0.32, -0.05, 1.05), target: head, fov: 28 } },
    { start: 8.5, end: 11.3, ease: ease.inOutSine,
      from: { pos: V(2.4, 0.45, 3.1), target: V(0, 1.3, 0.3), fov: 40 },
      to:   { pos: V(1.6, 0.55, 2.7), target: V(0, 1.7, 0.2), fov: 42 } },
    { start: 11.3, end: 14.2, ease: ease.inOutSine,
      from: { pos: V(-7.5, 0.5, 8.5), target: V(0, 2.4, 0), fov: 44 },
      to:   { pos: V(-6.0, 1.0, 7.0), target: V(0, 1.9, 0), fov: 40 } },
    { start: 14.2, end: 14.45, ease: ease.linear,
      from: { pos: V(4.0, 1.3, 2.6), target: V(0, 1.1, 0.5), fov: 38 },
      to:   { pos: V(3.8, 1.2, 2.5), target: V(0, 0.9, 0.5), fov: 38 } },
    { start: 14.45, end: 18.5, ease: ease.outCubic,
      from: { pos: V(4.2, 1.3, 3.2), target: V(0, 0.9, 0.8), fov: 40 },
      to:   { pos: V(5.0, 3.4, 8.0), target: V(0, 1.2, 0), fov: 48 } },
    { start: 18.5, end: 23.8, ease: ease.inOutSine,
      orbit: { center: chest, radius: [6.5, 4.6], angle: [0.5, 0.5 + 3.4], height: [-0.9, 0.5] },
      from: { fov: 42 }, to: { fov: 38 } },
    { start: 23.8, end: 25.8, ease: ease.outQuad,
      from: { pos: rel(chest, -1.7, 0.55, -3.3), target: V(0.6, 2.2, 14), fov: 42 },
      to:   { pos: rel(chest, -1.4, 0.4, -2.7), target: V(0.2, 2.0, 18), fov: 36 } },
    { start: 25.8, end: 27.3, ease: ease.linear,
      from: { pos: V(12, 2.6, 9.5), target: V(0, 2.4, 13), fov: 50 },
      to:   { pos: V(11, 3.2, 13.5), target: V(0, 2.0, 17), fov: 48 } },
    { start: 27.3, end: 34, ease: ease.outQuad,
      from: { pos: V(2.8, 0.7, 6.8), target: rel(chest, 0, 0.1, 0), fov: 34 },
      to:   { pos: V(1.3, 1.0, 3.6), target: rel(chest, 0, 0.25, 0), fov: 30 } },
  ]);

  // --------------------------------------------------------------------------
  //  A — Abertura
  // --------------------------------------------------------------------------
  tl.at(0, () => {
    lore.snapPose('idle');
    ui.fade(0, 2.2);
    audio.swell(0.6, 2);
    fx.emberRate = 60;
  });
  tl.at(1.2, () => ui.title(true));
  tl.at(4.6, () => ui.title(false));

  // --------------------------------------------------------------------------
  //  B — Os olhos despertam
  // --------------------------------------------------------------------------
  tl.at(5.0, () => lore.setPose('awaken', 1.6, ease.inOutSine));
  tl.at(6.0, () => {
    tl.tween(P, 'eyeGlow', 1, 0.35, ease.outCubic);
    ui.flash(0.12);
    audio.chime();
    fx.glow.burst(lore.world('head'), 40, { speed: [0.5, 2], life: [0.4, 1], size: [0.04, 0], color: [0xfff3b0, 0xffc93c], gravity: 0, intensity: 2 });
  });
  tl.at(6.3, () => ui.subtitle('“Vocês despertaram aquilo que dormia sob a coroa…”'));
  tl.at(8.3, () => ui.subtitle(null));

  // --------------------------------------------------------------------------
  //  C — Carga de energia
  // --------------------------------------------------------------------------
  tl.at(8.5, () => {
    lore.setPose('charge', 0.55, ease.outCubic);
    fx.circle.show(1);
    audio.charge(4.8);
    audio.swell(1.0, 2);
    tl.tween(P, 'orbPower', 1.6, 2.4, ease.inQuad);
    tl.tween(P, 'wind', 0.9, 2);
    fx.emberRate = 120;
  });
  let arcAcc = 0;
  tl.during(8.6, 11.2, (p, dt) => {
    const orb = lore.world('orb');
    fx.converge(orb, Math.ceil(dt * 160), 3.2);
    director.shake(dt * 0.22 * (0.4 + p));
    arcAcc += dt;
    if (arcAcc > 0.18) { arcAcc = 0; fx.arcs(orb, 2, 0.6 + p * 0.6); }
    if (Math.random() < dt * 2) fx.circle.pulse(0.3);
  });
  tl.at(10.0, () => ui.subtitle('“Ouçam o trovão do Rei.”'));
  tl.at(11.8, () => ui.subtitle(null));
  tl.at(10.6, () => { lore.setPose('raise', 0.6, ease.outBack); audio.whoosh(0.5); });

  // --------------------------------------------------------------------------
  //  D — Tempestade de raios
  // --------------------------------------------------------------------------
  const strikeTimes = [11.45, 11.75, 12.0, 12.3, 12.55, 12.85, 13.1];
  strikeTimes.forEach((t, i) => tl.at(t, () => {
    const a = i * 2.1 + rand(-0.4, 0.4);
    const r = rand(3.6, 7);
    fx.strike(V(Math.sin(a) * r, 0.02, Math.cos(a) * r), { shake: 0.3, flash: 0.25 });
  }));
  tl.during(11.3, 13.35, (p, dt) => {
    if (Math.random() < dt * 6) fx.arcs(lore.world('orb'), 1, 1.2);
  });
  tl.at(13.35, () => {
    const orb = lore.world('orb');
    fx.lightning.bolt(orb.clone().add(V(rand(-2, 2), 24, rand(-2, 2))), orb, { width: 0.8, life: 0.6, branches: 6, depth: 7, rough: 0.1 });
    fx.glow.burst(orb, 220, { speed: [2, 9], life: [0.4, 1.2], size: [0.12, 0], color: [0xfffbe6, 0xffc93c], intensity: 2.5, gravity: -1 });
    fx.sparks.burst(orb, 120, { speed: [5, 14] });
    fx.circle.pulse(1.2);
    P.orbPower = 3;
    tl.tween(P, 'orbPower', 2.2, 0.8);
    director.shake(0.6);
    ui.flash(0.65);
    ui.aberration(1.2);
    audio.crack(); audio.boom(0.5);
  });

  // --------------------------------------------------------------------------
  //  E — O golpe
  // --------------------------------------------------------------------------
  tl.at(13.7, () => lore.setPose('windup', 0.5, ease.outCubic));
  tl.at(14.2, () => { lore.setPose('slam', 0.22, ease.inCubic); audio.whoosh(0.25); });
  tl.at(14.43, () => {
    const base = lore.world('staffBase');
    base.y = 0.25;
    ctx.slowmo(0.2, 0.18);
    fx.explode(base, 1.7);
    fx.explosions.ring(V(base.x, 0, base.z), 16, 1.6);
    fx.circle.pulse(0.9);
    lore.kick(0.25);
    tl.tween(P, 'orbPower', 1.0, 1.5);
    tl.tween(P, 'wind', 1.7, 0.3, ease.outQuad);
    director.shake(0.5);
    ui.flash(0.85);
  });
  [15.0, 15.35, 15.7, 16.05].forEach((t, k) => tl.at(t, () => {
    const r = 4.5 + k * 1.6;
    for (let i = 0; i < 3; i++) {
      const a = k * 0.9 + (i / 3) * Math.PI * 2 + rand(-0.3, 0.3);
      fx.explode(V(Math.sin(a) * r, 0.2, Math.cos(a) * r), 0.75 - k * 0.08, { shell: false });
    }
  }));
  tl.at(15.4, () => tl.tween(P, 'wind', 0.8, 2));
  tl.at(16.2, () => ui.subtitle('“Ajoelhem-se.”'));
  tl.at(18.0, () => ui.subtitle(null));
  tl.at(17.0, () => { lore.setPose('idle', 1.3, ease.inOutSine); fx.circle.show(0.45); });

  // --------------------------------------------------------------------------
  //  F — Ascensão
  // --------------------------------------------------------------------------
  tl.at(18.5, () => {
    lore.setPose('levitate', 1.8, ease.inOutSine);
    tl.tween(P, 'groundLock', 0, 1.2, ease.inOutSine);
    tl.tween(P, 'lift', 1.6, 3.2, ease.inOutSine);
    tl.tween(P, 'wind', 1.3, 2);
    tl.tween(P, 'orbPower', 1.8, 2);
    fx.pillar.target = 0.55;
    fx.circle.show(1);
    fx.footCircle.show(1);
    audio.chime(); audio.swell(1.4, 3);
    fx.emberRate = 200;
  });
  let rayAcc = 0;
  tl.during(18.6, 23.8, (p, dt, time) => {
    const c = lore.world('hips');
    fx.spiral(c, time, Math.ceil(dt * 90), 1.1 + Math.sin(time * 2) * 0.2);
    fx.footCircle.group.position.set(c.x, Math.max(0.03, lore.world('ankleL').y - 0.12), c.z);
    rayAcc += dt;
    if (rayAcc > 0.42 && p > 0.15) {
      rayAcc = 0;
      // raios de energia irradiando do corpo até o chão
      const a = rand(0, Math.PI * 2), r = rand(2.5, 5);
      const g = V(Math.sin(a) * r, 0.02, Math.cos(a) * r);
      fx.lightning.bolt(lore.world('chest'), g, { width: 0.18, life: 0.3, branches: 2, depth: 6, rough: 0.2 });
      fx.glow.burst(g, 40, { speed: [1, 5], life: [0.3, 0.8], size: [0.08, 0], hemisphere: true, intensity: 2 });
      fx.smoke.puff(g, 2, { size0: [0.4, 0.6], size1: [1.2, 2], life: [1, 2], heat: 0.8 });
      director.shake(0.12);
      audio.crack();
    }
  });
  tl.at(23.1, () => { lore.setPose('castPrep', 0.65, ease.inOutCubic); fx.pillar.target = 0.3; audio.whoosh(0.6); });
  tl.during(23.1, 24.25, (p, dt) => {
    fx.converge(lore.world('handL'), Math.ceil(dt * 120), 1.6);
  });

  // --------------------------------------------------------------------------
  //  G — O feixe
  // --------------------------------------------------------------------------
  tl.at(24.25, () => {
    lore.setPose('cast', 0.14, ease.outCubic);
    lore.kick(0.35);
    fx.beam.fire(lore.world('handL'), env.target);
    audio.beam(2.8);
    director.shake(0.5);
    ui.flash(0.35);
    ui.aberration(1);
    fx.glow.burst(lore.world('handL'), 150, { speed: [2, 8], life: [0.3, 0.8], size: [0.1, 0], intensity: 2.5, gravity: 0 });
  });
  let hitAcc = 0;
  tl.during(24.3, 27.0, (p, dt) => {
    const hand = lore.world('handL');
    fx.beam.from.copy(hand);
    director.shake(dt * 0.9);
    ui.aberration(0.35);
    if (Math.random() < dt * 30) fx.sparks.burst(hand, 3, { speed: [3, 8], life: [0.2, 0.4] });
    if (fx.beam.extend >= 1) {
      hitAcc += dt;
      if (hitAcc > 0.22) {
        hitAcc = 0;
        fx.explode(env.target.clone().add(randomDir().multiplyScalar(rand(0.5, 2.5)).setY(rand(0.3, 2.8))), rand(0.7, 1.1), { shell: false });
      }
    }
  });
  tl.at(27.0, () => {
    fx.beam.stop();
    fx.explode(env.target.clone().setY(1.8), 3.4);
    fx.explosions.ring(V(env.target.x, 0, env.target.z), 34, 2.2);
    director.shake(0.9);
    ui.flash(1);
    env.glow = 1.5;
    lore.setPose('levitate', 0.9, ease.outCubic);
  });

  // --------------------------------------------------------------------------
  //  H — Desfecho
  // --------------------------------------------------------------------------
  tl.at(27.6, () => {
    lore.setPose('final', 2.8, ease.inOutSine);
    tl.tween(P, 'lift', 0, 2.7, ease.inOutSine);
    fx.pillar.target = 0;
    fx.footCircle.hide();
    fx.circle.show(0.35);
    tl.tween(P, 'wind', 0.55, 3);
    tl.tween(P, 'eyeGlow', 0.45, 3);
    tl.tween(P, 'orbPower', 0.8, 3);
    audio.swell(0.8, 3);
    fx.emberRate = 90;
  });
  tl.at(28.4, () => tl.tween(P, 'groundLock', 1, 1.9, ease.inOutSine));
  tl.at(30.3, () => {
    fx.explosions.ring(V(0, 0, 0), 5, 1.1);
    fx.smoke.puff(V(0, 0.1, 0), 14, { speed: [1.5, 3.5], up: 0.15, size0: [0.4, 0.7], size1: [1.5, 2.6], life: [1.5, 3], heat: 0, alpha: 0.35, rise: 0.1 });
    fx.glow.burst(V(0, 0.1, 0), 60, { speed: [1, 4], flat: 0.2, life: [0.4, 1.2], size: [0.06, 0] });
    director.shake(0.25);
    audio.boom(0.25);
  });
  tl.at(29.4, () => ui.subtitle('“Este reino… ainda é meu.”'));
  tl.at(31.8, () => ui.subtitle(null));
  tl.at(31.0, () => ui.title(true));
  tl.at(32.6, () => { ui.fade(1, 1.3); audio.swell(0.4, 2); });
  tl.at(33.3, () => ui.title(false));
}

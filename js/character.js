// ============================================================================
//  Lore, o Rei Mago — personagem procedural com rig hierárquico
// ============================================================================
// O corpo é montado com primitivas do Three.js, sombreamento toon (3 faixas)
// e contorno "inverted hull" para o visual de anime. Cada articulação é um
// Object3D; as poses (poses.js) giram essas articulações e são mescladas
// suavemente. Capa, saia e cabelo têm movimento secundário procedural.
import * as THREE from 'three';
import { CONFIG } from './config.js';
import { BASE, resolvePose } from './poses.js';
import { lerp, clamp, ease, makeToonGradient, makeGlowTexture, wobble } from './utils.js';

const C = CONFIG.character;
const gradient = makeToonGradient([0.32, 0.62, 1.0]);
const glowTex = makeGlowTexture(128, 'rgba(255,255,240,1)', 'rgba(255,190,60,0.4)');

function toon(color, extra = {}) {
  return new THREE.MeshToonMaterial({ color, gradientMap: gradient, ...extra });
}

// Contorno: empurra os vértices pela normal e desenha só as faces traseiras.
const outlineMat = new THREE.ShaderMaterial({
  uniforms: { uWidth: { value: C.outlineWidth }, uColor: { value: new THREE.Color(C.outline) } },
  vertexShader: /* glsl */`
    uniform float uWidth;
    void main(){
      vec3 p = position + normalize(normal) * uWidth;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(p, 1.0);
    }`,
  fragmentShader: /* glsl */`
    uniform vec3 uColor;
    void main(){ gl_FragColor = vec4(uColor, 1.0); }`,
  side: THREE.BackSide,
});

export class Lore {
  constructor(scene) {
    this.root = new THREE.Group();        // posição/rotação no mundo
    this.rig = new THREE.Group();         // deslocamento vertical (apoio no chão)
    this.root.add(this.rig);
    scene.add(this.root);

    this.joints = {};
    this.mats = {
      skin: toon(C.skin),
      hair: toon(C.hair),
      robe: toon(C.robe),
      robeIn: toon(C.robeInner),
      robeDS: toon(C.robe, { side: THREE.DoubleSide }),
      trim: toon(C.trim, { emissive: C.trim, emissiveIntensity: 0.12 }),
      trimDS: toon(C.trim, { side: THREE.DoubleSide, emissive: C.trim, emissiveIntensity: 0.12 }),
      armor: toon(C.armor, { emissive: C.armor, emissiveIntensity: 0.08 }),
      boots: toon(C.boots),
      cape: toon(C.cape, { side: THREE.DoubleSide }),
      collar: toon(C.capeInner, { side: THREE.DoubleSide }),
      crown: toon(C.crown, { emissive: C.crown, emissiveIntensity: 0.25 }),
      gem: new THREE.MeshBasicMaterial({ color: new THREE.Color(C.crownGem).multiplyScalar(1.1) }),
      dark: new THREE.MeshBasicMaterial({ color: 0x140a10 }),
      eyeWhite: new THREE.MeshBasicMaterial({ color: 0xfaf6ff, polygonOffset: true, polygonOffsetFactor: -1 }),
      iris: new THREE.MeshBasicMaterial({ color: new THREE.Color(C.eyes), polygonOffset: true, polygonOffsetFactor: -2 }),
      pupil: new THREE.MeshBasicMaterial({ color: 0x1a0d00, polygonOffset: true, polygonOffsetFactor: -3 }),
      wood: toon(C.staffWood),
      metal: toon(C.staffMetal, { emissive: C.staffMetal, emissiveIntensity: 0.2 }),
      orb: new THREE.MeshBasicMaterial({ color: new THREE.Color(C.staffOrb) }),
    };

    // Parâmetros animáveis (a timeline altera estes valores)
    this.params = {
      lift: 0,          // altura de levitação
      groundLock: 1,    // 1 = pés presos ao chão, 0 = livre
      yaw: 0,           // rotação do corpo
      eyeGlow: 0,       // 0..1 brilho dos olhos
      orbPower: 0.35,   // 0..3 brilho do orbe do cajado
      wind: 0.25,       // 0..2 vento na capa/cabelo
      breath: 1,        // intensidade da respiração
    };
    this.recoil = 0;    // impulso de recuo (impactos)

    this._build();

    this.cur = resolvePose('idle');
    this.from = resolvePose('idle');
    this.to = resolvePose('idle');
    this.tT = 1; this.tDur = 1; this.tEase = ease.inOutCubic;
    this.time = 0;

    this._tmp = new THREE.Vector3();
    this._tmp2 = new THREE.Vector3();
    this._q = new THREE.Quaternion();
    this._e = new THREE.Euler();
  }

  // --------------------------------------------------------------------------
  //  Construção
  // --------------------------------------------------------------------------
  _joint(name, parent, pos) {
    const j = new THREE.Group();
    j.name = name;
    j.position.set(...pos);
    parent.add(j);
    this.joints[name] = j;
    return j;
  }

  _mesh(geo, mat, parent, pos = [0, 0, 0], rot = [0, 0, 0], scale = [1, 1, 1], outline = true) {
    const m = new THREE.Mesh(geo, mat);
    m.position.set(...pos);
    m.rotation.set(...rot);
    m.scale.set(...scale);
    m.castShadow = true;
    parent.add(m);
    if (outline) {
      const o = new THREE.Mesh(geo, outlineMat);
      m.add(o);
    }
    return m;
  }

  _build() {
    const M = this.mats;
    const hips = this._joint('hips', this.rig, [0, 0.98, 0]);

    // ---- Quadril, cinto e saia do manto -----------------------------------
    this._mesh(new THREE.CylinderGeometry(0.17, 0.16, 0.2, 18), M.robe, hips, [0, 0.0, 0]);
    this._mesh(new THREE.TorusGeometry(0.172, 0.026, 8, 28), M.trim, hips, [0, 0.07, 0], [Math.PI / 2, 0, 0], [1, 0.75, 1]);
    this._mesh(new THREE.BoxGeometry(0.09, 0.08, 0.03), M.armor, hips, [0, 0.07, 0.135]);
    this._mesh(new THREE.OctahedronGeometry(0.022), M.gem, hips, [0, 0.07, 0.155], [0, 0, 0], [1, 1.3, 0.6], false);

    this.skirt = [];
    const panelDefs = [
      { a0: 0.14, a1: 1.05, follow: 'L', k: 0.85 },
      { a0: -1.05, a1: -0.14, follow: 'R', k: 0.85 },
      { a0: 1.05, a1: 2.15, follow: 'L', k: 0.45 },
      { a0: -2.15, a1: -1.05, follow: 'R', k: 0.45 },
      { a0: 2.15, a1: 4.13, follow: 'back', k: 0.7 },
    ];
    for (const d of panelDefs) {
      const g = new THREE.Group();
      g.position.y = 0.04;
      hips.add(g);
      const len = 0.8;
      const geo = new THREE.CylinderGeometry(0.18, 0.37, len, 10, 4, true, d.a0, d.a1 - d.a0);
      geo.translate(0, -len / 2, 0);
      this._mesh(geo, M.robeDS, g, [0, 0, 0], [0, 0, 0], [1, 1, 1], false);
      const trimGeo = new THREE.CylinderGeometry(0.367, 0.374, 0.05, 10, 1, true, d.a0, d.a1 - d.a0);
      this._mesh(trimGeo, M.trimDS, g, [0, -len + 0.02, 0], [0, 0, 0], [1, 1, 1], false);
      // ponto médio do painel (para decidir a direção do balanço)
      const mid = (d.a0 + d.a1) / 2;
      this.skirt.push({ g, ...d, sx: Math.sin(mid), sz: Math.cos(mid), seed: Math.random() * 10 });
    }

    // ---- Pernas ------------------------------------------------------------
    this.feet = {};
    for (const [S, s] of [['L', 1], ['R', -1]]) {
      const thigh = this._joint('thigh' + S, hips, [s * 0.1, -0.03, 0]);
      this._mesh(new THREE.CylinderGeometry(0.078, 0.062, 0.45, 12), M.robeIn, thigh, [0, -0.225, 0]);
      const knee = this._joint('knee' + S, thigh, [0, -0.45, 0]);
      this._mesh(new THREE.CylinderGeometry(0.064, 0.05, 0.45, 12), M.boots, knee, [0, -0.225, 0]);
      this._mesh(new THREE.CylinderGeometry(0.078, 0.07, 0.08, 12), M.trim, knee, [0, -0.08, 0]);
      this._mesh(new THREE.SphereGeometry(0.05, 12, 8), M.armor, knee, [0, 0, 0.035], [0, 0, 0], [1, 1.2, 0.7]);
      const ankle = this._joint('ankle' + S, knee, [0, -0.45, 0]);
      this._mesh(new THREE.BoxGeometry(0.1, 0.07, 0.25), M.boots, ankle, [0, -0.04, 0.05]);
      this._mesh(new THREE.ConeGeometry(0.045, 0.08, 8), M.trim, ankle, [0, -0.045, 0.2], [Math.PI / 2, 0, 0], [1, 1, 0.7]);
      const toe = new THREE.Object3D(); toe.position.set(0, -0.075, 0.18); ankle.add(toe);
      const heel = new THREE.Object3D(); heel.position.set(0, -0.075, -0.07); ankle.add(heel);
      this.feet[S] = [toe, heel];
    }

    // ---- Tronco ------------------------------------------------------------
    const spine = this._joint('spine', hips, [0, 0.08, 0]);
    this._mesh(new THREE.CylinderGeometry(0.15, 0.168, 0.25, 16), M.robe, spine, [0, 0.1, 0], [0, 0, 0], [1, 1, 0.82]);
    const chest = this._joint('chest', spine, [0, 0.22, 0]);
    this._mesh(new THREE.CylinderGeometry(0.22, 0.155, 0.36, 18), M.robe, chest, [0, 0.15, 0], [0, 0, 0], [1, 1, 0.72]);
    // peitoral dourado (somente a frente)
    this._mesh(new THREE.CylinderGeometry(0.228, 0.165, 0.3, 18, 1, true, -0.95, 1.9), M.trimDS, chest, [0, 0.16, 0], [0, 0, 0], [1, 1, 0.75], false);
    this._mesh(new THREE.OctahedronGeometry(0.035), M.gem, chest, [0, 0.2, 0.172], [0, 0, 0], [1, 1.4, 0.5], false);
    // gola alta de mago
    this._mesh(new THREE.CylinderGeometry(0.16, 0.12, 0.2, 18, 1, true, Math.PI - 1.4, 2.8), M.collar, chest, [0, 0.4, -0.01], [0.15, 0, 0], [1, 1, 1], false);
    this._mesh(new THREE.CylinderGeometry(0.163, 0.163, 0.02, 18, 1, true, Math.PI - 1.4, 2.8), M.trimDS, chest, [0, 0.5, -0.025], [0.15, 0, 0], [1, 1, 1], false);
    // fechos da capa
    for (const s of [1, -1]) this._mesh(new THREE.SphereGeometry(0.03, 10, 8), M.armor, chest, [s * 0.15, 0.3, 0.11]);

    // ---- Braços ------------------------------------------------------------
    this.hands = {};
    for (const [S, s] of [['L', 1], ['R', -1]]) {
      const sh = this._joint('shoulder' + S, chest, [s * 0.25, 0.27, 0]);
      // ombreira em camadas com espinho
      this._mesh(new THREE.SphereGeometry(0.115, 18, 10, 0, Math.PI * 2, 0, Math.PI / 2), M.armor, sh, [s * 0.015, 0.02, 0], [0, 0, -s * 0.35], [1.15, 0.85, 1.15]);
      this._mesh(new THREE.SphereGeometry(0.12, 18, 6, 0, Math.PI * 2, Math.PI / 2 - 0.25, 0.25), M.trimDS, sh, [s * 0.015, 0.02, 0], [0, 0, -s * 0.35], [1.2, 0.9, 1.2], false);
      this._mesh(new THREE.ConeGeometry(0.026, 0.13, 8), M.armor, sh, [s * 0.06, 0.1, 0], [0, 0, -s * 0.6]);
      this._mesh(new THREE.CylinderGeometry(0.06, 0.052, 0.3, 12), M.robe, sh, [0, -0.15, 0]);
      const el = this._joint('elbow' + S, sh, [0, -0.3, 0]);
      this._mesh(new THREE.CylinderGeometry(0.05, 0.042, 0.26, 12), M.robeIn, el, [0, -0.13, 0]);
      // manga em sino
      this._mesh(new THREE.CylinderGeometry(0.07, 0.135, 0.24, 16, 1, true), M.robeDS, el, [0, -0.08, 0], [0, 0, 0], [1, 1, 1], false);
      this._mesh(new THREE.TorusGeometry(0.135, 0.012, 6, 20), M.trim, el, [0, -0.2, 0], [Math.PI / 2, 0, 0], [1, 1, 1], false);
      const wr = this._joint('wrist' + S, el, [0, -0.27, 0]);
      this._mesh(new THREE.CylinderGeometry(0.05, 0.047, 0.05, 12), M.armor, wr, [0, 0.02, 0]);
      this._mesh(new THREE.SphereGeometry(0.045, 12, 10), M.skin, wr, [0, -0.05, 0.005], [0, 0, 0], [0.9, 1.35, 0.6]);
      this._mesh(new THREE.BoxGeometry(0.02, 0.05, 0.022), M.skin, wr, [s * 0.042, -0.035, 0.012], [0, 0, s * 0.4]); // polegar
      const tip = new THREE.Object3D(); tip.position.set(0, -0.08, 0); wr.add(tip);
      const grip = new THREE.Object3D(); grip.position.set(0, -0.055, 0.01); wr.add(grip);
      this.hands[S] = { tip, grip };
    }

    // ---- Pescoço e cabeça --------------------------------------------------
    const neck = this._joint('neck', chest, [0, 0.36, 0]);
    this._mesh(new THREE.CylinderGeometry(0.05, 0.056, 0.11, 12), M.skin, neck, [0, 0.03, 0]);
    const head = this._joint('head', neck, [0, 0.09, 0]);
    this._mesh(new THREE.SphereGeometry(0.115, 28, 20), M.skin, head, [0, 0.1, 0], [0, 0, 0], [0.92, 1.05, 0.98]);
    // queixo afilado estilo anime
    this._mesh(new THREE.ConeGeometry(0.075, 0.09, 16), M.skin, head, [0, 0.025, 0.03], [Math.PI + 0.35, 0, 0], [1, 1, 0.8], false);

    // olhos
    this.eyeGlows = [];
    for (const s of [1, -1]) {
      const eye = new THREE.Group();
      eye.position.set(s * 0.04, 0.098, 0.111);
      eye.rotation.set(0, s * 0.3, 0);
      head.add(eye);
      const white = new THREE.Mesh(new THREE.CircleGeometry(0.026, 24), M.eyeWhite);
      white.scale.set(1.15, 0.85, 1); eye.add(white);
      const iris = new THREE.Mesh(new THREE.CircleGeometry(0.0175, 20), M.iris);
      iris.position.set(-s * 0.003, -0.001, 0.0008); iris.scale.set(0.9, 1.05, 1); eye.add(iris);
      const pupil = new THREE.Mesh(new THREE.CircleGeometry(0.0065, 12), M.pupil);
      pupil.position.set(-s * 0.003, -0.001, 0.0016); pupil.scale.set(0.7, 1.2, 1); eye.add(pupil);
      const lash = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.007, 0.004), M.dark);
      lash.position.set(0, 0.02, 0.002); lash.rotation.z = -s * 0.12; eye.add(lash);
      const brow = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.008, 0.008), new THREE.MeshBasicMaterial({ color: C.hairShadow }));
      brow.position.set(s * 0.004, 0.04, 0.004); brow.rotation.z = s * 0.28; eye.add(brow);
      const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, color: C.eyes, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0 }));
      glow.scale.setScalar(0.12); glow.position.z = 0.01; eye.add(glow);
      this.eyeGlows.push(glow);
    }
    const mouth = new THREE.Mesh(new THREE.BoxGeometry(0.03, 0.004, 0.004), M.dark);
    mouth.position.set(0, 0.045, 0.104); head.add(mouth);

    // cabelo
    this.hairGroup = new THREE.Group();
    this.hairGroup.position.y = 0.11;
    head.add(this.hairGroup);
    this._mesh(new THREE.SphereGeometry(0.126, 22, 14, 0, Math.PI * 2, 0, Math.PI * 0.56), M.hair, this.hairGroup, [0, 0.0, -0.008], [-0.3, 0, 0], [0.98, 1.06, 1.04]);
    this.hairSpikes = [];
    const up = new THREE.Vector3(0, 1, 0);
    const addSpike = (az, el, len, rad, bendDown, bendBack) => {
      // az: 0 = frente, cresce para a esquerda do personagem
      const n = new THREE.Vector3(Math.sin(az) * Math.cos(el), Math.sin(el), Math.cos(az) * Math.cos(el));
      const base = n.clone().multiplyScalar(0.105);
      const dir = n.clone();
      dir.y -= bendDown; dir.z -= bendBack; dir.normalize();
      const geo = new THREE.ConeGeometry(rad, len, 6);
      geo.translate(0, len / 2, 0);
      const pivot = new THREE.Group();
      pivot.position.copy(base);
      pivot.quaternion.setFromUnitVectors(up, dir);
      this.hairGroup.add(pivot);
      this._mesh(geo, M.hair, pivot, [0, 0, 0], [0, 0, 0], [1, 1, 0.6]);
      this.hairSpikes.push({ pivot, q0: pivot.quaternion.clone(), seed: Math.random() * 10, len });
    };
    for (let i = 0; i < 15; i++) {
      const az = THREE.MathUtils.lerp(1.45, Math.PI * 2 - 1.45, i / 14);
      addSpike(az, 0.15 + (i % 3) * 0.18, 0.16 + Math.random() * 0.1, 0.046, 1.0, 0.7);
    }
    for (let i = 0; i < 6; i++) addSpike(Math.PI + (i - 2.5) * 0.35, -0.2, 0.36 + Math.random() * 0.16, 0.05, 1.6, 0.5); // longos atrás
    for (let i = 0; i < 6; i++) addSpike((i - 2.5) * 0.45 + Math.PI, 0.9, 0.2, 0.05, -0.3, 0.9); // topo
    for (let i = 0; i < 5; i++) addSpike((i - 2) * 0.3, 0.95, 0.085 + Math.random() * 0.025, 0.03, 1.4, -0.5); // franja
    for (const s of [1, -1]) addSpike(s * 1.3, 0.25, 0.17, 0.03, 2.2, 0.15); // mechas laterais

    // coroa
    const crown = new THREE.Group();
    crown.position.set(0, 0.2, -0.008);
    crown.rotation.x = -0.18;
    head.add(crown);
    this._mesh(new THREE.CylinderGeometry(0.128, 0.134, 0.05, 28, 1, true), M.crown, crown, [0, 0, 0], [0, 0, 0], [1, 1, 1.02], false);
    const crownRing = new THREE.Mesh(new THREE.TorusGeometry(0.131, 0.007, 6, 32), M.crown);
    crownRing.rotation.x = Math.PI / 2; crownRing.position.y = -0.025; crown.add(crownRing);
    for (let i = 0; i < 9; i++) {
      const a = (i / 9) * Math.PI * 2;
      const front = i === 0;
      const h = front ? 0.14 : 0.08 + (i % 2) * 0.025;
      const spike = this._mesh(new THREE.ConeGeometry(front ? 0.026 : 0.019, h, 6), M.crown, crown,
        [Math.sin(a) * 0.131, 0.025 + h / 2, Math.cos(a) * 0.131], [Math.cos(a) * 0.12, 0, -Math.sin(a) * 0.12]);
      spike.castShadow = false;
      const gem = new THREE.Mesh(new THREE.SphereGeometry(front ? 0.013 : 0.007, 10, 8), M.gem);
      gem.position.set(Math.sin(a) * 0.137, 0.005, Math.cos(a) * 0.137);
      crown.add(gem);
    }

    // ---- Capa (pano animado por vértice) ----------------------------------
    const capeW = 0.62, capeH = 1.45;
    const capeGeo = new THREE.PlaneGeometry(capeW, capeH, 10, 22);
    capeGeo.translate(0, -capeH / 2, 0);
    this.capeBase = capeGeo.attributes.position.array.slice();
    this.capeGeo = capeGeo;
    this.capeH = capeH; this.capeW = capeW;
    const cape = new THREE.Mesh(capeGeo, M.cape);
    cape.castShadow = true;
    cape.position.set(0, 0.32, -0.13);
    chest.add(cape);
    this.cape = cape;

    // ---- Cajado ------------------------------------------------------------
    const staff = new THREE.Group();
    this.root.add(staff);
    this.staff = staff;
    const inner = new THREE.Group();
    staff.add(inner);
    this.staffInner = inner;
    this.staffLen = 2.0;
    const L = this.staffLen;
    this._mesh(new THREE.CylinderGeometry(0.022, 0.03, L, 10), M.wood, inner, [0, L / 2, 0]);
    for (const y of [0.35, 0.9, 1.45]) this._mesh(new THREE.CylinderGeometry(0.034, 0.034, 0.035, 10), M.metal, inner, [0, y, 0], [0, 0, 0], [1, 1, 1], false);
    this._mesh(new THREE.ConeGeometry(0.03, 0.1, 8), M.metal, inner, [0, -0.04, 0], [Math.PI, 0, 0]);
    const headG = new THREE.Group(); headG.position.y = L; inner.add(headG);
    this._mesh(new THREE.CylinderGeometry(0.05, 0.03, 0.09, 10), M.metal, headG, [0, 0.0, 0]);
    this._mesh(new THREE.TorusGeometry(0.14, 0.02, 8, 36, Math.PI * 1.55), M.metal, headG, [0, 0.17, 0], [0, 0, -Math.PI * 0.5 - Math.PI * 0.275]);
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * Math.PI * 2 + 0.4;
      this._mesh(new THREE.ConeGeometry(0.014, 0.12, 6), M.metal, headG, [Math.cos(a) * 0.05, 0.08, Math.sin(a) * 0.05], [Math.sin(a) * 0.5, 0, -Math.cos(a) * 0.5], [1, 1, 1], false);
    }
    const orb = new THREE.Mesh(new THREE.SphereGeometry(0.075, 24, 16), M.orb);
    orb.position.y = 0.17;
    headG.add(orb);
    this.orb = orb;
    this.orbGlow = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, color: CONFIG.magic.gold, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true }));
    orb.add(this.orbGlow);
    this.orbLight = new THREE.PointLight(CONFIG.magic.gold, 1, 7, 1.2);
    orb.add(this.orbLight);
    this.staffBase = new THREE.Object3D(); this.staffBase.position.y = -0.08; inner.add(this.staffBase);
  }

  // --------------------------------------------------------------------------
  //  API de animação
  // --------------------------------------------------------------------------
  /** Transição suave para uma pose. */
  setPose(name, duration = 0.6, easing = ease.inOutCubic) {
    this.from = this._snapshot();
    this.to = resolvePose(name);
    this.tT = 0;
    this.tDur = Math.max(0.0001, duration);
    this.tEase = easing;
    if (duration <= 0) { this.tT = 1; this.cur = resolvePose(name); }
  }

  snapPose(name) { this.setPose(name, 0); }

  /** Empurrão para trás em impactos. */
  kick(amount = 1) { this.recoil = Math.min(1.5, this.recoil + amount); }

  _snapshot() {
    const s = {};
    for (const k in this.cur) s[k] = this.cur[k].slice();
    return s;
  }

  /** Posição de mundo de uma articulação ou ponto especial. */
  world(name, out = new THREE.Vector3()) {
    const special = {
      orb: this.orb, staffBase: this.staffBase,
      handL: this.hands.L.tip, handR: this.hands.R.tip,
    };
    const obj = special[name] || this.joints[name];
    return obj.getWorldPosition(out);
  }

  /** Ponto de foco da câmera (cabeça/peito) com deslocamento opcional. */
  focus(name = 'head', dy = 0.1, out = new THREE.Vector3()) {
    this.world(name, out);
    out.y += dy;
    return out;
  }

  reset() {
    Object.assign(this.params, { lift: 0, groundLock: 1, yaw: 0, eyeGlow: 0, orbPower: 0.35, wind: 0.25, breath: 1 });
    this.recoil = 0;
    this.snapPose('idle');
    this.root.position.set(0, 0, 0);
  }

  // --------------------------------------------------------------------------
  //  Atualização por quadro
  // --------------------------------------------------------------------------
  update(dt, time) {
    this.time = time;
    const P = this.params;

    // 1) mistura de poses
    if (this.tT < 1) {
      this.tT = Math.min(1, this.tT + dt / this.tDur);
      const k = this.tEase(this.tT);
      for (const key in BASE) {
        const a = this.from[key], b = this.to[key], c = this.cur[key];
        c[0] = lerp(a[0], b[0], k); c[1] = lerp(a[1], b[1], k); c[2] = lerp(a[2], b[2], k);
      }
    }
    this.recoil = Math.max(0, this.recoil - dt * 2.2);

    // 2) aplica rotações + camadas procedurais (respiração, balanço, recuo)
    const br = Math.sin(time * 1.7) * 0.025 * P.breath;
    const sway = Math.sin(time * 0.8) * 0.015 * P.breath;
    const rc = ease.outCubic(Math.min(1, this.recoil));
    const levFloat = (1 - P.groundLock);
    for (const key in BASE) {
      if (key === 'staff' || key === 'grip') continue;
      const j = this.joints[key];
      const v = this.cur[key];
      j.rotation.set(v[0], v[1], v[2]);
    }
    const J = this.joints;
    J.chest.rotation.x += br - rc * 0.35;
    J.spine.rotation.x -= rc * 0.25;
    J.head.rotation.x += -br * 0.5 + rc * 0.2;
    J.hips.rotation.z += sway;
    J.shoulderL.rotation.z += br * 0.6 + levFloat * Math.sin(time * 1.3) * 0.08;
    J.shoulderR.rotation.z -= br * 0.6 + levFloat * Math.sin(time * 1.3 + 1) * 0.06;
    J.kneeL.rotation.x += levFloat * Math.sin(time * 1.1) * 0.1;
    J.kneeR.rotation.x += levFloat * Math.sin(time * 1.1 + 2) * 0.1;

    // 3) raiz: rotação e levitação (com flutuação senoidal)
    this.root.rotation.y = P.yaw;
    this.rig.position.y = 0;
    this.rig.updateMatrixWorld(true);

    // 4) apoio no chão: o pé mais baixo encosta em y = 0
    let minY = Infinity;
    for (const S of ['L', 'R']) for (const p of this.feet[S]) {
      p.getWorldPosition(this._tmp);
      this.root.worldToLocal(this._tmp);
      minY = Math.min(minY, this._tmp.y);
    }
    const bob = levFloat * Math.sin(time * 1.6) * 0.06;
    this.rig.position.y = -minY * P.groundLock + P.lift + bob;
    this.rig.updateMatrixWorld(true);

    // 5) cajado segue a mão direita
    this.hands.R.grip.getWorldPosition(this._tmp);
    this.root.worldToLocal(this._tmp);
    this.staff.position.copy(this._tmp);
    const sr = this.cur.staff;
    this.staff.rotation.set(sr[0], sr[1], sr[2]);
    this.staffInner.position.y = -this.cur.grip[0] * this.staffLen;

    // 6) orbe e olhos
    const pw = P.orbPower;
    const flick = 1 + Math.sin(time * 23) * 0.05 + Math.sin(time * 37) * 0.04;
    this.mats.orb.color.set(C.staffOrb).multiplyScalar(1 + pw * 1.4 * flick);
    this.orbGlow.scale.setScalar((0.3 + pw * 0.45) * flick);
    this.orbGlow.material.opacity = clamp(0.25 + pw * 0.25);
    this.orbLight.intensity = (0.25 + pw * 1.4) * flick;
    this.orbLight.distance = 5 + pw * 6;
    const eg = P.eyeGlow;
    this.mats.iris.color.set(C.eyes).multiplyScalar(1 + eg * 2.2);
    for (const g of this.eyeGlows) {
      g.material.opacity = eg * 0.55;
      g.scale.setScalar(0.03 + eg * 0.045 * flick);
    }

    // 7) movimento secundário: saia, cabelo e capa
    const w = P.wind + levFloat * 0.5;
    for (const p of this.skirt) {
      let rx;
      const tl = this.cur.thighL[0], tr = this.cur.thighR[0];
      if (p.follow === 'L') rx = Math.min(0, tl) * p.k + Math.max(0, tl) * 0.15;
      else if (p.follow === 'R') rx = Math.min(0, tr) * p.k + Math.max(0, tr) * 0.15;
      else rx = Math.max(0, Math.max(tl, tr)) * p.k;
      const flutter = Math.sin(time * 3.2 + p.seed) * 0.05 * w + wobble(time * 1.5, p.seed) * 0.04 * w;
      // levitação: vento de baixo para cima abre a saia
      p.g.rotation.x = rx + flutter * p.sz + levFloat * 0.25 * -p.sz * 0.6 + rc * 0.2 * p.sz;
      p.g.rotation.z = flutter * -p.sx + levFloat * 0.2 * p.sx;
    }
    for (const h of this.hairSpikes) {
      this._e.set(
        Math.sin(time * 4 + h.seed) * 0.06 * w + wobble(time * 2, h.seed) * 0.05 * w,
        0,
        Math.sin(time * 3.3 + h.seed * 2) * 0.05 * w,
      );
      this._q.setFromEuler(this._e);
      h.pivot.quaternion.copy(h.q0).multiply(this._q);
    }
    this._updateCape(time, w, rc, levFloat);
  }

  _updateCape(time, wind, recoil, lev) {
    const pos = this.capeGeo.attributes.position.array;
    const base = this.capeBase;
    const H = this.capeH, W = this.capeW;
    for (let i = 0; i < pos.length; i += 3) {
      const bx = base[i], by = base[i + 1];
      const v = -by / H;           // 0 no topo, 1 na barra
      const u = bx / W;            // -0.5..0.5
      const vv = v * v;
      const wave = Math.sin(time * 3.4 - v * 5.5 + u * 3.0) * 0.5 + Math.sin(time * 5.7 - v * 9 + u * 7) * 0.25;
      const flare = 0.08 + v * 0.3 + wind * vv * 0.55 + recoil * vv * 0.6 + lev * vv * 0.4;
      pos[i] = bx * (1 + v * 0.45) + Math.sin(time * 2.1 + v * 4) * 0.04 * wind * v;
      pos[i + 1] = by + wind * vv * 0.32 + lev * vv * 0.35;
      pos[i + 2] = -flare - wave * (0.04 + wind * 0.13) * v;
    }
    this.capeGeo.attributes.position.needsUpdate = true;
    this.capeGeo.computeVertexNormals();
  }
}

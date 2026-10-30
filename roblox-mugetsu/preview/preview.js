// Prévia APROXIMADA em three.js da cutscene. Usa os mesmos dados da Timeline/PoseDriver do projeto
// (gerados por gen_data.py). Tudo é função pura do tempo t => dá para pular para qualquer instante.
// Não é o Roblox: iluminação, materiais, partículas e pós-processamento são aproximações.
import * as THREE from "../../vendor/three/build/three.module.js";
import { DATA } from "./data.js";

const rad = (d) => (d * Math.PI) / 180;
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const lerp = (a, b, k) => a + (b - a) * k;
const smooth = (a) => a * a * (3 - 2 * a);
const hash = (n) => { const s = Math.sin(n * 127.1 + 311.7) * 43758.5453; return s - Math.floor(s); };
const easeFn = (kind, a) => {
  a = clamp(a);
  if (kind === "Linear") return a;
  if (kind === "Quad") return a < 0.5 ? 2 * a * a : 1 - Math.pow(-2 * a + 2, 2) / 2;
  if (kind === "Expo") { if (a <= 0) return 0; if (a >= 1) return 1; return a < 0.5 ? Math.pow(2, 20 * a - 10) / 2 : (2 - Math.pow(2, -20 * a + 10)) / 2; }
  return 0.5 - 0.5 * Math.cos(a * Math.PI);
};
const evT = (name, i = 0) => DATA.events.filter((e) => e.name === name)[i]?.t ?? 1e9;
const evAll = (name) => DATA.events.filter((e) => e.name === name);

// ------------------------------------------------------------------ renderer / cena
const canvas = document.getElementById("c");
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(1);
renderer.shadowMap.enabled = true;
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(50, 16 / 9, 0.1, 900);
scene.fog = new THREE.Fog(0x000000, 90, 420);
const hemi = new THREE.HemisphereLight(0xffffff, 0x888888, 1);
scene.add(hemi);
const sun = new THREE.DirectionalLight(0xffffff, 1);
sun.position.set(40, 70, -30);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -30, right: 30, top: 30, bottom: -30, near: 1, far: 200 });
scene.add(sun);
const pBlue = new THREE.PointLight(0x50aaff, 0, 60); pBlue.position.set(0, 4, 0); scene.add(pBlue);
const pWhite = new THREE.PointLight(0xffffff, 0, 120); pWhite.position.set(0, 5, 0); scene.add(pWhite);
const pEye = new THREE.PointLight(0x50aaff, 0, 14); scene.add(pEye);
const pMask = new THREE.PointLight(0xffffff, 0, 16); scene.add(pMask);
const pFace = new THREE.PointLight(0xe1e6f2, 0, 12); pFace.position.set(0.6, 5.9, -2.4); scene.add(pFace);

// ------------------------------------------------------------------ cenário
const std = (c, r = 0.9) => new THREE.MeshStandardMaterial({ color: c, roughness: r, metalness: 0 });
const floor = new THREE.Mesh(new THREE.CircleGeometry(160, 64), std(0xb0a082)); floor.rotation.x = -Math.PI / 2; floor.receiveShadow = true; scene.add(floor);
const plate = new THREE.Mesh(new THREE.CircleGeometry(40, 64), std(0xc4b8a0)); plate.rotation.x = -Math.PI / 2; plate.position.y = 0.03; plate.receiveShadow = true; scene.add(plate);
const reactive = [];
for (let i = 0; i < 14; i++) {
  const a = (i / 14) * Math.PI * 2, dist = 154 + (hash(i) - 0.5) * 12, h = 40 + hash(i + 40) * 45, w = 34 + hash(i + 80) * 22;
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, 18 + hash(i + 3) * 12), std(0x96805c, 1));
  m.position.set(Math.cos(a) * dist, h / 2 - 2, Math.sin(a) * dist); m.lookAt(0, h / 2 - 2, 0); scene.add(m);
  reactive.push({ m, base: m.position.clone(), amp: 0.4 + hash(i) * 0.5 });
}
for (let i = 0; i < 22; i++) {
  const a = hash(i + 200) * Math.PI * 2, d = 46 + hash(i + 300) * 64, s = 3 + hash(i + 400) * 6;
  const m = new THREE.Mesh(new THREE.BoxGeometry(s, s * 0.8, s * 1.1), std(0x80705a, 1));
  m.position.set(Math.cos(a) * d, s * 0.3, Math.sin(a) * d); m.rotation.set(hash(i), hash(i + 1) * 6, hash(i + 2)); m.castShadow = m.receiveShadow = true; scene.add(m);
  reactive.push({ m, base: m.position.clone(), amp: 1 });
}

// ------------------------------------------------------------------ personagem (R15 em blocos) + kits do KitData.json
function box(w, h, d, mat, parent, pos = [0, 0, 0], rot = [0, 0, 0]) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  m.position.set(...pos); m.rotation.set(rad(rot[0]), rad(rot[1]), rad(rot[2]), "XYZ"); m.castShadow = true; parent.add(m); return m;
}
const G = (parent, pos = [0, 0, 0]) => { const g = new THREE.Group(); g.position.set(...pos); parent.add(g); return g; };
const J = {}; // junta -> Group (rotação = Motor6D.Transform)
const LIMB = {}; // nome do membro R15 -> Group no CENTRO da peça (mesma referência dos offsets do Roblox)
const limbMat = {};
const limbBox = {};
function limb(name, parent, pos, size) { const g = G(parent, pos); limbMat[name] = std(0xffffff, 0.75); limbBox[name] = box(...size, limbMat[name], g); LIMB[name] = g; return g; }
const root = G(scene, [0, 3, 0]); J.Root = root;
const lowerC = limb("LowerTorso", root, [0, 0, 0], [2, 0.4, 1]);
const waist = G(root, [0, 0.2, 0]); J.Waist = waist;
const upperC = limb("UpperTorso", waist, [0, 0.8, 0], [2, 1.6, 1]);
const neck = G(waist, [0, 1.6, 0]); J.Neck = neck;
const headC = limb("Head", neck, [0, 0.6, 0], [1.2, 1.2, 1.2]);
function arm(side) {
  const s = side === "R" ? 1 : -1, P = side === "R" ? "Right" : "Left";
  const sh = G(waist, [s * 1.25, 1.4, 0]); J[P + "Shoulder"] = sh;
  const upC = limb(P + "UpperArm", sh, [0, -0.6, 0], [1, 1.2, 1]);
  const el = G(sh, [0, -1.2, 0]); J[P + "Elbow"] = el;
  const loC = limb(P + "LowerArm", el, [0, -0.55, 0], [1, 1.1, 1]);
  const wr = G(el, [0, -1.1, 0]); J[P + "Wrist"] = wr; const handC = limb(P + "Hand", wr, [0, -0.2, 0], [0.9, 0.4, 0.9]);
  return { upC, loC, handC };
}
const R = arm("R"), L = arm("L");
function leg(side) {
  const s = side === "R" ? 1 : -1, P = side === "R" ? "Right" : "Left";
  const hip = G(root, [s * 0.5, -0.2, 0]); J[P + "Hip"] = hip;
  limb(P + "UpperLeg", hip, [0, -0.6, 0], [1, 1.2, 1]);
  const kn = G(hip, [0, -1.2, 0]); J[P + "Knee"] = kn;
  limb(P + "LowerLeg", kn, [0, -0.6, 0], [1, 1.2, 1]); limb(P + "Foot", kn, [0, -1.35, 0.1], [1.1, 0.3, 1.2]);
}
leg("R"); leg("L");

// WedgePart do Roblox: corte em Y-Z com face vertical atrás (+Z), base embaixo e rampa subindo de frente-baixo
// para trás-cima. A aresta de cima (a "ponta") fica em +Y.
function wedgeGeo(w, h, d) {
  const x0 = -w / 2, x1 = w / 2, A = [-h / 2, -d / 2], B = [-h / 2, d / 2], C = [h / 2, d / 2];
  const v = (x, p) => [x, p[0], p[1]];
  const tri = [v(x0, A), v(x0, C), v(x0, B), v(x1, A), v(x1, B), v(x1, C),
    v(x0, A), v(x0, B), v(x1, B), v(x0, A), v(x1, B), v(x1, A),
    v(x0, B), v(x0, C), v(x1, C), v(x0, B), v(x1, C), v(x1, B),
    v(x0, A), v(x1, A), v(x1, C), v(x0, A), v(x1, C), v(x0, C)].flat();
  const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(tri, 3)); g.computeVertexNormals(); return g;
}
const matCache = {};
function kitMat(c, material) {
  const key = c.join(",") + material;
  if (!matCache[key]) {
    const col = new THREE.Color(c[0] / 255, c[1] / 255, c[2] / 255);
    matCache[key] = material === "Neon" ? new THREE.MeshBasicMaterial({ color: col })
      : new THREE.MeshStandardMaterial({ color: col, roughness: material === "Metal" ? 0.35 : material === "Fabric" ? 0.95 : 0.6, metalness: material === "Metal" ? 0.55 : 0, side: THREE.DoubleSide });
  }
  return matCache[key];
}
const hair = [];
const kits = {};
const KIT_SRC = new URLSearchParams(location.search).get("kit") === "obj" ? "obj" : "procedural"; // igual a Config.Kit.Source
function shapeGeo(p) {
  if (p.shape === "Wedge") return wedgeGeo(...p.size);
  if (p.shape === "Ball") return new THREE.SphereGeometry(p.size[0] / 2, 14, 10);
  if (p.shape === "Cylinder") { const g = new THREE.CylinderGeometry(0.5, 0.5, 1, 14); g.rotateZ(-Math.PI / 2); g.scale(p.size[0], p.size[1], p.size[2]); return g; } // eixo X, como no Roblox
  return new THREE.BoxGeometry(...p.size);
}
function buildKit(name) {
  const def = DATA.kits[KIT_SRC].forms[name], groups = [], named = {};
  for (const p of def.parts) {
    const host = LIMB[p.attach]; if (!host) { console.warn("membro desconhecido", p.attach); continue; }
    const geo = shapeGeo(p);
    const m = new THREE.Mesh(geo, kitMat(p.color, p.material));
    m.position.set(...p.pos); m.rotation.set(rad(p.rot[0]), rad(p.rot[1]), rad(p.rot[2]), "XYZ"); m.castShadow = true;
    host.add(m); groups.push(m); named[p.name] = m;
    for (const a of p.attachments || []) { const o = new THREE.Object3D(); o.name = a.name; o.position.set(...a.pos); m.add(o); named[a.name] = o; }
  }
  for (const c of def.chains) {
    let parent = LIMB[c.attach];
    c.lengths.forEach((len, i) => {
      const jg = new THREE.Group();
      if (i === 0) { jg.position.set(...c.pos); jg.rotation.set(rad(c.rot[0]), rad(c.rot[1]), rad(c.rot[2]), "XYZ"); groups.push(jg); }
      else jg.position.set(0, -c.lengths[i - 1], 0);
      parent.add(jg);
      const w = c.width * (1 - i * 0.18);
      const last = i === c.lengths.length - 1;
      const seg = new THREE.Mesh(last ? wedgeGeo(w, len, c.depth) : new THREE.BoxGeometry(w, len, c.depth), kitMat(c.color, c.material));
      seg.position.set(0, -len / 2, 0); if (last) seg.rotation.z = Math.PI; seg.castShadow = true; jg.add(seg);
      if (name === "Mugetsu") hair.push({ jg, idx: i + 1, ph: c.name.length * 0.7 + i, bend: i === 0 ? null : rad(c.bend), base: i === 0 ? jg.rotation.clone() : null });
      parent = jg;
    });
  }
  kits[name] = { groups, named, colors: def.limbColors };
}
// Forma do manifesto (Ichigo) com a malha esculpida (MeshKitManifest + IchigoMesh.obj), como o ModelKit faz
// quando o Model importado existe no ServerStorage. ?mesh=0 volta ao kit de peças.
async function buildMeshKit() {
  const man = await (await fetch("../src/shared/MeshKitManifest.json")).json();
  const txt = await (await fetch("../" + man.file)).text();
  const V = [], groupsIdx = {}; let cur = null;
  for (const line of txt.split("\n")) {
    const t = line.trim().split(/\s+/);
    if (t[0] === "o") { cur = t[1]; groupsIdx[cur] = []; } else if (t[0] === "v") V.push(t.slice(1, 4).map(Number)); else if (t[0] === "f") groupsIdx[cur].push(...t.slice(1, 4).map((x) => parseInt(x) - 1));
  }
  scene.updateMatrixWorld(true); // juntas ainda em repouso aqui
  const hrp = new THREE.Matrix4().makeTranslation(0, 3, 0), groups = [], named = {};
  const place = (obj, limbName) => { const L = LIMB[limbName]; obj.applyMatrix4(new THREE.Matrix4().copy(L.matrixWorld).invert().multiply(hrp)); L.add(obj); groups.push(obj); };
  for (const [name, info] of Object.entries(man.pieces)) {
    const idx = groupsIdx[name]; if (!idx) continue;
    const pos = []; for (const k of idx) pos.push(...V[k]);
    const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3)); g.computeVertexNormals();
    const m = new THREE.Mesh(g, kitMat(info.color, info.material)); m.castShadow = true; m.material.flatShading = true;
    for (const a of info.attachments || []) { const o = new THREE.Object3D(); o.name = a.name; o.position.set(info.center[0] + a.pos[0], info.center[1] + a.pos[1], info.center[2] + a.pos[2]); m.add(o); named[a.name] = o; }
    place(m, info.attach); named[name] = m;
  }
  for (const e of man.extras) { const m = new THREE.Mesh(new THREE.BoxGeometry(...e.size), kitMat(e.color, e.material)); m.position.set(...e.worldPos); place(m, e.attach); }
  kits[man.form] = { groups, named, colors: DATA.kits[KIT_SRC].forms[man.form].limbColors, replaceBody: man.replaceBody };
}
buildKit("Mugetsu");
if (new URLSearchParams(location.search).get("mesh") !== "0") await buildMeshKit(); else buildKit("Ichigo");
const swordM = { base: kits.Mugetsu.named.TrailA, tip: kits.Mugetsu.named.TrailB };
let currentForm = null;
function setForm(f) {
  if (f === currentForm) return; currentForm = f;
  for (const [n, k] of Object.entries(kits)) k.groups.forEach((g) => (g.visible = n === f));
  for (const [limbName, c] of Object.entries(kits[f].colors)) limbMat[limbName]?.color.setRGB(c[0] / 255, c[1] / 255, c[2] / 255);
  for (const b of Object.values(limbBox)) b.visible = !kits[f].replaceBody; // corpo de blocos some sob a malha
}

// ------------------------------------------------------------------ pose (porta do PoseDriver.sample)
const JOINTS = ["Root", "Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist", "RightHip", "RightKnee", "LeftHip", "LeftKnee"];
function samplePose(name, t, intensity) {
  const a = DATA.anims[name]; if (!a) return null;
  const keys = a.keys;
  const last = DATA.poses[keys[keys.length - 1].pose];
  let tt = a.looped ? t % a.length : clamp(t, 0, keys[keys.length - 1].t);
  let lo = keys[0], hi = keys[keys.length - 1];
  for (let i = 0; i < keys.length - 1; i++) if (tt >= keys[i].t && tt <= keys[i + 1].t) { lo = keys[i]; hi = keys[i + 1]; break; }
  const span = hi.t - lo.t, k = span > 1e-6 ? smooth((tt - lo.t) / span) : 1;
  const out = {}, Z = [0, 0, 0, 0];
  for (const j of JOINTS) {
    const A = DATA.poses[lo.pose][j] || Z, B = DATA.poses[hi.pose][j] || Z;
    out[j] = [0, 1, 2, 3].map((i) => (A[i] ?? 0) + ((B[i] ?? 0) - (A[i] ?? 0)) * k);
  }
  if (a.breath > 0) { // igual ao PoseDriver.sample: respiração por cima
    const b1 = Math.sin(t * 2.1) * a.breath;
    out.Waist[0] += b1 * 0.6; out.Neck[0] -= b1 * 0.4; out.RightShoulder[2] += b1 * 0.5; out.LeftShoulder[2] -= b1 * 0.5; out.Root[3] += b1 * 0.012;
  }
  if (name === "Concentrate" && intensity > 0) {
    const amp = intensity * 2.2;
    for (const j of ["RightShoulder", "LeftShoulder", "Neck", "Waist"]) { const o = out[j]; if (o) { o[0] += Math.sin(t * 31 + j.length) * amp; o[2] += Math.sin(t * 27 + j.length * 2) * amp * 0.6; } }
  }
  return out;
}
const animEvents = evAll("Anim").map((e) => ({ t: e.t, name: e.arg }));
function applyPose(t) {
  let cur = { t: 0, name: "Prepare" };
  for (const e of animEvents) if (t >= e.t) cur = e;
  const pose = samplePose(cur.name, Math.max(0, t - cur.t), cur.name === "Concentrate" ? 1 : 0);
  for (const j of JOINTS) {
    const g = J[j], p = pose[j]; if (!g || !p) continue;
    g.rotation.set(rad(p[0]), rad(p[1]), rad(p[2]), "XYZ");
    if (j === "Root") g.position.y = 3 + (p[3] || 0);
  }
  scene.updateMatrixWorld(true);
}
let windGust = 0;
// igual ao HairSway.luau: Transform = Angles(sx, 0, sz) aplicado DEPOIS do C0 em todo segmento (inclusive a raiz)
const _q = new THREE.Quaternion(), _e = new THREE.Euler();
function swayHair(t) {
  for (const h of hair) {
    const amp = rad(3 + h.idx * 2.2) * (1 + windGust * 2.5);
    const sx = Math.sin(t * 1.6 + h.ph + h.idx * 0.7) * amp, sz = Math.sin(t * 1.1 + h.ph * 1.3 + h.idx * 0.5) * amp * 0.8;
    _q.setFromEuler(_e.set(sx, 0, sz, "XYZ"));
    if (h.idx === 1) h.jg.quaternion.setFromEuler(h.base).multiply(_q);
    else h.jg.quaternion.setFromEuler(_e.set(h.bend, 0, 0, "XYZ")).multiply(_q);
  }
}

// ------------------------------------------------------------------ partículas (pontos com sombreamento suave)
function makeLayer(cap, additive, uni) {
  const geo = new THREE.BufferGeometry();
  const pos = new Float32Array(cap * 3), size = new Float32Array(cap), alpha = new Float32Array(cap), col = new Float32Array(cap * 3);
  geo.setAttribute("position", new THREE.BufferAttribute(pos, 3)); geo.setAttribute("aSize", new THREE.BufferAttribute(size, 1));
  geo.setAttribute("aAlpha", new THREE.BufferAttribute(alpha, 1)); geo.setAttribute("aColor", new THREE.BufferAttribute(col, 3));
  const mat = new THREE.ShaderMaterial({
    uniforms: { uScale: uni }, transparent: true, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending,
    vertexShader: `attribute float aSize; attribute float aAlpha; attribute vec3 aColor; uniform float uScale; varying float vA; varying vec3 vC;
      void main(){ vec4 mv = modelViewMatrix * vec4(position,1.); gl_Position = projectionMatrix * mv; gl_PointSize = max(1., aSize * uScale / -mv.z); vA = aAlpha; vC = aColor; }`,
    fragmentShader: `varying float vA; varying vec3 vC; void main(){ float d = length(gl_PointCoord-.5); float a = smoothstep(.5,.05,d) * vA; if(a<.003) discard; gl_FragColor = vec4(vC, a); }`,
  });
  const pts = new THREE.Points(geo, mat); pts.frustumCulled = false; scene.add(pts);
  let n = 0;
  return {
    reset() { n = 0; },
    push(x, y, z, s, a, r, g, b) { if (n >= cap || a <= 0.002) return; pos[n * 3] = x; pos[n * 3 + 1] = y; pos[n * 3 + 2] = z; size[n] = s; alpha[n] = a; col[n * 3] = r; col[n * 3 + 1] = g; col[n * 3 + 2] = b; n++; },
    flush() { geo.setDrawRange(0, n); for (const k of ["position", "aSize", "aAlpha", "aColor"]) geo.attributes[k].needsUpdate = true; },
  };
}
const uScale = { value: 800 };
const smokeL = makeLayer(6000, false, uScale), sparkL = makeLayer(3000, true, uScale);

const wp = (obj) => new THREE.Vector3().setFromMatrixPosition(obj.matrixWorld);
const C = { blue: [0.31, 0.67, 1.0], white: [0.93, 0.96, 1], black: [0.02, 0.02, 0.03], red: [0.75, 0.09, 0.13], dust: [0.6, 0.52, 0.4] };

function auraIntensity(t) {
  const wh = evT("AuraWhispers"), eg = evT("EnergyGather"), stop = evT("WhiteOut"), rel = evT("ReleaseImpact");
  let blue = 0, black = 0;
  if (t >= wh && t < stop) blue = t < eg ? 0.25 * clamp((t - wh) / 3) : lerp(0.25, 1, clamp((t - eg) / 7));
  if (t >= rel) black = clamp((t - rel) / 0.3);
  return { blue, black };
}
function emitAura(t) {
  const { blue, black } = auraIntensity(t);
  if (blue <= 0 && black <= 0) return;
  const pal = black > 0 ? C.black : C.blue, inten = black > 0 ? black : blue;
  const feet = new THREE.Vector3(0, 0.1, 0), chest = wp(upperC), rA = wp(R.loC), lA = wp(L.loC), hand = wp(R.handC);
  const spec = [
    [feet, 60, 1.4, 2.4, 3, 7, 2.2, 6, 7, 0.3], [chest, 36, 0.9, 1.6, 1, 3, 1.4, 3.4, 4, 0.35], [rA, 18, 0.6, 1.1, 1, 3, 0.7, 1.8, 5, 0.25],
    [lA, 18, 0.6, 1.1, 1, 3, 0.7, 1.8, 5, 0.25], [hand, 18, 0.6, 1.1, 1, 3, 0.7, 1.8, 5, 0.25],
  ];
  spec.forEach(([p, N, l0, l1, s0, s1, z0, z1, acc, a0], si) => {
    for (let k = 0; k < N; k++) {
      if (k / N > inten) continue;
      const life = lerp(l0, l1, hash(k + si * 91)), u = (t / life + hash(k * 7 + si)) % 1, age = u * life;
      const th = hash(k * 3 + si) * 6.283, ph = si === 0 ? hash(k * 5) * 0.5 : hash(k * 5 + 1) * 3.14 - 1.57, sp = lerp(s0, s1, hash(k * 11 + si));
      const dir = si === 0 ? [Math.cos(th) * Math.sin(ph), Math.cos(ph) * 0.8 + 0.5, Math.sin(th) * Math.sin(ph)] : [Math.cos(th) * Math.cos(ph), Math.sin(ph) + 0.4, Math.sin(th) * Math.cos(ph)];
      const sz = lerp(z0, z1, u);
      smokeL.push(p.x + dir[0] * sp * age + (si === 0 ? Math.cos(th) * 1.2 : 0), p.y + dir[1] * sp * age + 0.5 * acc * age * age * 0.4, p.z + dir[2] * sp * age + (si === 0 ? Math.sin(th) * 1.2 : 0), sz, a0 * (1 - u) * 1.6 * Math.min(1, inten + 0.2), pal[0], pal[1], pal[2]);
    }
  });
  for (let k = 0; k < 40; k++) {
    if (k / 40 > inten) continue;
    const life = lerp(0.5, 1.1, hash(k + 900)), u = (t / life + hash(k * 13)) % 1, age = u * life, th = hash(k * 3 + 77) * 6.283, ph = hash(k * 5 + 78) * 3.14 - 1.57, sp = lerp(5, 11, hash(k * 17));
    const c = black > 0 ? C.red : C.white;
    sparkL.push(chest.x + Math.cos(th) * Math.cos(ph) * sp * age, chest.y + Math.sin(ph) * sp * age + age, chest.z + Math.sin(th) * Math.cos(ph) * sp * age, 0.35 * (1 - u) + 0.05, 1 - u, c[0], c[1], c[2]);
  }
}
function dust(t, t0, pos, n, dur = 2) {
  const age = t - t0; if (age < 0 || age > dur) return;
  for (let k = 0; k < n; k++) {
    const th = hash(k * 3 + t0 * 10) * 6.283, sp = lerp(18, 34, hash(k * 7)), u = age / dur, dist = sp * (1 - Math.exp(-3 * age)) / 3;
    smokeL.push(pos[0] + Math.cos(th) * dist, pos[1] + 0.8 + hash(k) * 3 * Math.min(1, age * 2), pos[2] + Math.sin(th) * dist, lerp(3, 11, u), 0.4 * (1 - u), C.dust[0], C.dust[1], C.dust[2]);
  }
}

// ------------------------------------------------------------------ fragmentos (InstancedMesh), anéis, domo, pilar, tentáculos, rastro
const SH_CAP = 260;
const shardMesh = new THREE.InstancedMesh(new THREE.BoxGeometry(0.5, 1.6, 0.4), new THREE.MeshBasicMaterial({ transparent: true }), SH_CAP);
shardMesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage); shardMesh.frustumCulled = false; scene.add(shardMesh);
const shardCol = new THREE.Color(); let shardN = 0; const dummy = new THREE.Object3D();
function shardPush(x, y, z, s, rx, ry, rz, c, vis) {
  if (shardN >= SH_CAP || vis <= 0.02) return;
  dummy.position.set(x, y, z); dummy.rotation.set(rx, ry, rz); dummy.scale.setScalar(s * vis); dummy.updateMatrix();
  shardMesh.setMatrixAt(shardN, dummy.matrix); shardMesh.setColorAt(shardN, shardCol.setRGB(c[0], c[1], c[2])); shardN++;
}
function shards(t, t0, dur, mode, origin, count, color, goalFn, seed) {
  const age = t - t0; if (age < 0 || age > dur) return;
  const k = age / dur;
  for (let i = 0; i < count; i++) {
    const a = hash(i + seed) * 6.283, s = lerp(0.25, 0.9, hash(i + seed + 5)), sp = [hash(i + 11 + seed) * 6 - 3, hash(i + 12 + seed) * 6 - 3, hash(i + 13 + seed) * 6 - 3], rr = lerp(4, 14, hash(i + seed + 9));
    let x, y, z, vis = 1;
    if (mode === "burst") { const v = lerp(18, 70, hash(i + seed + 2)), vy = lerp(10, 34, hash(i + seed + 3)); x = origin[0] + Math.cos(a) * v * age; z = origin[2] + Math.sin(a) * v * age; y = Math.max(origin[1] + 0.2, origin[1] + vy * age - 30 * age * age); vis = 1 - clamp((k - 0.6) / 0.4); }
    else if (mode === "rise") { const ang = a + age * 0.9, r = rr * (1 - 0.25 * k); x = origin[0] + Math.cos(ang) * r; z = origin[2] + Math.sin(ang) * r; y = origin[1] + lerp(5, 12, hash(i + seed + 4)) * age; vis = 1 - clamp((k - 0.6) / 0.4); }
    else { const g = goalFn(), p0 = [origin[0] + Math.cos(a) * rr * 2.2, origin[1] + hash(i + seed + 6) * 6, origin[2] + Math.sin(a) * rr * 2.2]; const e = k * k; x = lerp(p0[0], g[0], e); y = lerp(p0[1], g[1], e); z = lerp(p0[2], g[2], e); vis = 1 - clamp((k - 0.85) / 0.15); }
    shardPush(x, y, z, s * 1.1, sp[0] * age, sp[1] * age, sp[2] * age, color, vis);
  }
}
const ringMeshes = [];
for (let i = 0; i < 8; i++) { const m = new THREE.Mesh(new THREE.RingGeometry(0.965, 1, 96), new THREE.MeshBasicMaterial({ side: THREE.DoubleSide, transparent: true, depthWrite: false })); m.visible = false; scene.add(m); ringMeshes.push(m); }
let ringN = 0;
function ringPush(t, t0, dur, maxR, color, y, tilt = [0, 0]) {
  const age = t - t0; if (age < 0 || age > dur || ringN >= ringMeshes.length) return;
  const k = age / dur, r = Math.max(0.5, maxR * (1 - Math.pow(1 - k, 2))), m = ringMeshes[ringN++];
  m.visible = true; m.position.set(0, y, 0); m.rotation.set(-Math.PI / 2 + tilt[0], 0, tilt[1]); m.scale.setScalar(r); m.material.color.setRGB(...color); m.material.opacity = 1 - k * k;
}
const dome = new THREE.Mesh(new THREE.SphereGeometry(1, 40, 16, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, depthWrite: false, side: THREE.DoubleSide }));
dome.visible = false; scene.add(dome);
function domePush(t, t0, dur, radius, color) { const age = t - t0; if (age < 0 || age > dur) return false; const k = age / dur, r = radius * (1 - Math.pow(1 - k, 2)); dome.visible = true; dome.scale.set(r, r * 0.3, r); dome.position.y = 0.1; dome.material.color.setRGB(...color); dome.material.opacity = 0.4 * (1 - k); return true; }
const spireO = new THREE.Mesh(new THREE.CylinderGeometry(1, 1, 1, 24, 1, true), new THREE.MeshBasicMaterial({ color: 0x50aaff, transparent: true, depthWrite: false, side: THREE.DoubleSide }));
const spireI = new THREE.Mesh(new THREE.CylinderGeometry(1, 1, 1, 24, 1, true), new THREE.MeshBasicMaterial({ color: 0xeef6ff, transparent: true, depthWrite: false })); spireO.visible = spireI.visible = false; scene.add(spireO, spireI);
function spirePush(t) {
  const t0 = evT("BlueSpire"), dur = 3.6, age = t - t0; if (age < 0 || age > dur) return false; const k = age / dur;
  const grow = easeFn("Quad", Math.min(k / 0.25, 1)), fade = k > 0.75 ? (k - 0.75) / 0.25 : 0, h = 70 * grow, w = (1 - fade) * (7 + Math.sin(k * 40) * 0.5);
  spireO.visible = spireI.visible = true; spireO.scale.set(w * 0.8, h, w * 0.8); spireI.scale.set(w * 0.3, h, w * 0.3);
  spireO.position.set(0, h / 2, -2); spireI.position.set(0, h / 2, -2); spireO.material.opacity = 0.55 * (1 - fade); spireI.material.opacity = 1 - fade; return true;
}
const tendrilMeshes = [];
for (let i = 0; i < 14; i++) { const m = new THREE.Mesh(new THREE.BufferGeometry(), new THREE.MeshBasicMaterial({ color: 0x050506, transparent: true, side: THREE.DoubleSide })); m.visible = false; m.frustumCulled = false; scene.add(m); tendrilMeshes.push(m); }
function tendrilsPush(t) {
  const t0 = evT("BlackTendrils"), dur = 2.8, age = t - t0;
  tendrilMeshes.forEach((m, i) => {
    if (age < 0 || age > dur) { m.visible = false; return; }
    const ang = (i / 14) * 6.283 + (hash(i + 500) - 0.5) * 0.6, rad_ = lerp(3, 11, hash(i + 510)), delay = hash(i + 520) * 0.35;
    const kk = clamp((age / dur - delay) / (1 - delay)), fall = easeFn("Quad", Math.min(kk / 0.4, 1)), fade = kk > 0.7 ? (kk - 0.7) / 0.3 : 0;
    const top = new THREE.Vector3(Math.cos(ang) * rad_, 23 + hash(i + 530) * 10, Math.sin(ang) * rad_), bot = new THREE.Vector3(Math.cos(ang) * rad_ * 0.35, 3.5, Math.sin(ang) * rad_ * 0.35);
    const a0 = top.clone().lerp(bot, fall * 0.35), a1 = top.clone().lerp(bot, fall);
    const side = new THREE.Vector3((hash(i + 540) - 0.5) * 14, 0, (hash(i + 550) - 0.5) * 14);
    const curve = new THREE.CubicBezierCurve3(a0, a0.clone().lerp(a1, 0.33).add(side), a0.clone().lerp(a1, 0.66).sub(side.clone().multiplyScalar(0.6)), a1);
    const pts = curve.getPoints(14), w0 = lerp(1.6, 3.2, hash(i + 560)), cam = camera.position, pos = [], idx = [];
    pts.forEach((p, j) => { const u = j / 14, tan = curve.getTangent(u), n = new THREE.Vector3().crossVectors(tan, new THREE.Vector3().subVectors(cam, p)).normalize().multiplyScalar(w0 * (1 - u) * 0.5 + 0.05); pos.push(p.x + n.x, p.y + n.y, p.z + n.z, p.x - n.x, p.y - n.y, p.z - n.z); if (j < 14) idx.push(j * 2, j * 2 + 1, j * 2 + 2, j * 2 + 1, j * 2 + 3, j * 2 + 2); });
    m.geometry.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3)); m.geometry.setIndex(idx); m.material.opacity = 1 - fade; m.visible = true;
  });
}
// rastro da espada: reamostra a pose em instantes passados e liga a ponta/base da lâmina (como um Trail)
const trailBlack = new THREE.Mesh(new THREE.BufferGeometry(), new THREE.MeshBasicMaterial({ color: 0x050506, transparent: true, side: THREE.DoubleSide, depthWrite: false }));
const trailWhite = new THREE.Mesh(new THREE.BufferGeometry(), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, side: THREE.DoubleSide, depthWrite: false })); trailBlack.frustumCulled = trailWhite.frustumCulled = false; trailBlack.visible = trailWhite.visible = false; scene.add(trailBlack, trailWhite);
function trailPush(t) {
  const t0 = evT("SwordSlash"), age = t - t0;
  if (age < 0 || age > 0.9 + 0.4) { trailBlack.visible = trailWhite.visible = false; return; }
  const N = 18, a = [], b = [];
  for (let i = 0; i <= N; i++) {
    const ts = t - (i / N) * 0.4; if (ts < t0) break;
    applyPose(ts); const base = wp(swordM.base), tip = wp(swordM.tip); a.push(base); b.push(tip);
  }
  applyPose(t);
  if (a.length < 2) { trailBlack.visible = trailWhite.visible = false; return; }
  const build = (wid) => { const pos = [], idx = [], col = []; a.forEach((p, j) => { const q = b[j], m = p.clone().lerp(q, 0.5), h = q.clone().sub(p).multiplyScalar(0.5 * wid); const f = 1 - j / (a.length - 1); pos.push(m.x - h.x, m.y - h.y, m.z - h.z, m.x + h.x, m.y + h.y, m.z + h.z); if (j < a.length - 1) idx.push(j * 2, j * 2 + 1, j * 2 + 2, j * 2 + 1, j * 2 + 3, j * 2 + 2); }); const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3)); g.setIndex(idx); return g; };
  trailBlack.geometry.dispose(); trailBlack.geometry = build(1.0); trailWhite.geometry.dispose(); trailWhite.geometry = build(0.35);
  const fade = age > 0.9 ? 1 - (age - 0.9) / 0.4 : 1; trailBlack.material.opacity = 0.9 * fade; trailWhite.material.opacity = 0.9 * fade; trailBlack.visible = trailWhite.visible = true;
}

// ------------------------------------------------------------------ iluminação (porta dos presets do LightingDirector)
const PRE = {
  Default: { bg: [150, 190, 235], hs: [200, 220, 255], hg: [150, 130, 100], hi: 0.9, sc: [255, 240, 215], si: 2.2, sat: 1, con: 1, br: 1 },
  Cold: { bg: [92, 104, 132], hs: [120, 135, 170], hg: [60, 66, 84], hi: 0.8, sc: [190, 210, 255], si: 1.3, sat: 0.75, con: 1.15, br: 0.95 },
  Night: { bg: [6, 14, 38], hs: [60, 100, 190], hg: [20, 34, 70], hi: 1.1, sc: [140, 180, 255], si: 0.9, sat: 0.9, con: 1.2, br: 0.9 },
  Overcast: { bg: [212, 212, 218], hs: [240, 240, 245], hg: [180, 170, 150], hi: 1.6, sc: [255, 255, 255], si: 1.2, sat: 0.45, con: 1.15, br: 1.05 },
  Mugetsu: { bg: [14, 14, 18], hs: [70, 70, 78], hg: [20, 20, 22], hi: 0.35, sc: [255, 255, 255], si: 1.6, sat: 0.15, con: 1.5, br: 0.95 },
};
const SEQ = [[0, "Default", 0.01], [evT("Lighting", 0), "Cold", 1.0], [evT("BlueSpire"), "Night", 0.6], [evT("WhiteOut"), "Overcast", 0.05], [evT("Lighting", 1), "Mugetsu", 0.1]];
function preset(t) {
  let i = 0; for (let j = 0; j < SEQ.length; j++) if (t >= SEQ[j][0]) i = j;
  const cur = PRE[SEQ[i][1]], prev = PRE[SEQ[Math.max(0, i - 1)][1]], k = smooth(clamp((t - SEQ[i][0]) / SEQ[i][2]));
  const mix = (a, b) => (Array.isArray(a) ? a.map((v, n) => lerp(v, b[n], k)) : lerp(a, b, k));
  return Object.fromEntries(Object.keys(cur).map((key) => [key, mix(prev[key], cur[key])]));
}
const rgb = (a) => new THREE.Color(a[0] / 255, a[1] / 255, a[2] / 255);

// ------------------------------------------------------------------ câmera (porta do CameraDirector)
function shotAt(t) {
  let s = null; for (const sh of DATA.shots) if (t >= sh.t) s = sh; if (!s) s = DATA.shots[0];
  const alpha = clamp((t - s.t) / Math.max(s.duration, 1e-3)), k = easeFn(s.ease === "Orbit" ? "Sine" : s.ease, alpha);
  const V = (a) => new THREE.Vector3(...a).add(new THREE.Vector3(0, 3, 0));
  let pos, look;
  if (s.ease === "Orbit" && s.orbit) { const o = s.orbit, st = Math.atan2(s.from.pos[0], s.from.pos[2]), ang = st + rad(o.degrees) * k; pos = new THREE.Vector3(Math.sin(ang) * o.radius, o.height + 0.6 * Math.sin(k * Math.PI), Math.cos(ang) * o.radius).add(new THREE.Vector3(0, 3, 0)); }
  else pos = V(s.from.pos).lerp(V(s.to.pos), k);
  look = V(s.from.look).lerp(V(s.to.look), k);
  return { pos, look, fov: lerp(s.from.fov, s.to.fov, k) };
}
const noise = (t, sd) => Math.sin(t * 47 + sd) * 0.6 + Math.sin(t * 81 + sd * 2.3) * 0.4;
const SHAKES = [["PulseLight", (a) => [0.05 + 0.08 * (a ?? 0.5), 0.3]], ["PressureWave", () => [0.25, 0.8]], ["MaskForm", () => [0.18, 0.6]], ["ShakeSmall", () => [0.12, 0.5]], ["ReleaseImpact", () => [0.8, 0.7]], ["ImpactFrame", () => [0.3, 0.25]]];
const PUNCH = [["PauseBeat", -4, 0.5], ["ReleaseImpact", 14, 0.5]];

// ------------------------------------------------------------------ quadro
const el = (id) => document.getElementById(id);
const fadeEl = el("fade"), flashEl = el("flash"), barT = el("barT"), barB = el("barB");
function render(t) {
  const W = canvas.clientWidth, H = canvas.clientHeight;
  if (canvas.width !== W || canvas.height !== H) { renderer.setSize(W, H, false); camera.aspect = W / H; }
  // forma
  const studio = window.__studio; // depuração: luz neutra, sem efeitos/overlays (vistas do modelo)
  setForm(studio?.form ?? (t >= evT("MorphSwap") ? "Mugetsu" : "Ichigo"));
  windGust = t >= evT("ReleaseImpact") ? Math.max(0, 1 - (t - evT("ReleaseImpact")) / 3) : 0;
  applyPose(t); swayHair(t); scene.updateMatrixWorld(true);
  // iluminação
  const P = studio ? { bg: [38, 40, 46], hs: [235, 235, 240], hg: [70, 70, 76], hi: 1.3, sc: [255, 250, 240], si: 2.4, sat: 1, con: 1, br: 1 } : preset(t);
  scene.background = rgb(P.bg); scene.fog.color.copy(rgb(P.bg));
  hemi.color.copy(rgb(P.hs)); hemi.groundColor.copy(rgb(P.hg)); hemi.intensity = P.hi; sun.color.copy(rgb(P.sc)); sun.intensity = P.si;
  // luzes pontuais de pulso
  let blueI = 0; for (const e of evAll("PulseLight")) { const a = t - e.t; if (a >= 0 && a < 0.55) blueI += (3 + 4 * e.arg) * (1 - a / 0.55) ** 2 * 6; }
  pBlue.position.set(0, 4, 0); pBlue.intensity = blueI;
  let whiteI = 0; const rel = evT("ReleaseImpact"); if (t >= rel && t < rel + 0.7) whiteI = 10 * (1 - (t - rel) / 0.7) ** 2 * 60; pWhite.intensity = whiteI;
  const eyeT = evT("EyeReiatsu"); pEye.position.set(0, 5.4, -1.5); pEye.intensity = t >= eyeT && t < eyeT + 2.4 ? 14 * (1 - (t - eyeT) / 2.4) ** 2 : 0;
  const mk = evT("MaskForm"); pMask.position.set(0, 5.4, -0.6); pMask.intensity = t >= mk && t < mk + 0.8 ? 40 * (1 - (t - mk) / 0.8) ** 2 : 0;
  pFace.intensity = t >= evT("Lighting", 1) ? 50 : 0;
  // partículas e formas
  smokeL.reset(); sparkL.reset(); shardN = 0; ringN = 0; ringMeshes.forEach((m) => (m.visible = false));
  if (!studio) emitAura(t);
  const floorPos = [0, 0.05, 0];
  const chestFn = () => { const c = wp(upperC); return [c.x, c.y, c.z]; };
  const eg = evT("EnergyGather");
  if (t >= eg && t < eg + 7.5) for (let i = 0; i < 70; i++) { const per = lerp(0.9, 1.3, hash(i + 77)), tt = (t + hash(i + 3) * per) % per, k = (t - eg) / 6.5; if (i / 70 > clamp(k) * 0.9 + 0.1) continue; shards(tt, 0, per, "converge", floorPos, 1, C.blue, chestFn, i * 17); }
  shards(t, evT("GroundShards"), 5.2, "rise", floorPos, 22, [0.07, 0.08, 0.13], null, 100); shards(t, evT("GroundShards"), 5.2, "rise", floorPos, 14, C.blue, null, 200);
  shards(t, evT("PressureWave"), 1.6, "burst", floorPos, 10, C.blue, null, 300);
  const head = wp(headC); shards(t, evT("MaskForm"), 1.1, "converge", [head.x, head.y + 1, head.z - 6], 26, C.white, () => [head.x, head.y - 0.2, head.z - 0.6], 400);
  shards(t, rel, 1.8, "burst", floorPos, 36, [0.04, 0.04, 0.05], null, 500); shards(t, rel, 1.6, "burst", floorPos, 12, C.white, null, 600);
  const pw = evT("PressureWave"); ringPush(t, pw, 1.3 * 0.9, 28 * 1.15, C.white, 0.15); ringPush(t, pw, 1.3 * 0.7, 28 * 0.8, C.blue, 0.2);
  for (let i = 1; i <= 4; i++) ringPush(t, rel, 0.7 + i * 0.18, 36 + i * 16, i % 2 === 0 ? C.white : C.black, 0.2 + i * 0.4);
  ringPush(t, rel, 0.9, 30, C.black, 3, [rad(18), rad(-12)]); ringPush(t, rel, 1.2 * 0.9, 70 * 1.15, C.white, 0.15);
  const d1 = domePush(t, pw, 1.3, 28, C.blue), d2 = domePush(t, rel, 1.2, 70, C.white); dome.visible = d1 || d2;
  const sp = spirePush(t); if (!sp) spireO.visible = spireI.visible = false;
  tendrilsPush(t); trailPush(t);
  dust(t, pw, floorPos, 24); dust(t, rel, floorPos, 40);
  // cenário reage
  const ea = evT("EnvironmentReact"); const age = t - ea;
  for (const r of reactive) { const d = r.base.length(), delay = clamp(d / 170) * 0.35, k = clamp((age / 2.4 - delay) / (1 - delay)); const amp = age >= 0 && age < 2.4 ? (1 - k) ** 2 * r.amp * 1.3 : 0; r.m.position.set(r.base.x + Math.sin(t * 38 + d) * 0.25 * amp, r.base.y + Math.sin(t * 49) * 0.12 * amp, r.base.z + Math.cos(t * 34 + d) * 0.25 * amp); }
  smokeL.flush(); sparkL.flush(); shardMesh.count = shardN; shardMesh.instanceMatrix.needsUpdate = true; if (shardMesh.instanceColor) shardMesh.instanceColor.needsUpdate = true;
  // câmera + tremor + punch de FOV
  const sh = shotAt(t); let off = new THREE.Vector3(), roll = 0;
  for (const [name, fn] of SHAKES) for (const e of evAll(name)) { const a = t - e.t, [amp, dur] = fn(e.arg); if (a >= 0 && a < dur) { const f = (1 - a / dur) ** 2 * amp; off.add(new THREE.Vector3(noise(t, 1) * f, noise(t, 7) * f, noise(t, 13) * f * 0.5)); roll += noise(t, 19) * f * 0.02; } }
  let fov = sh.fov; for (const [name, amt, dec] of PUNCH) for (const e of evAll(name)) { const a = t - e.t; if (a >= 0 && a < dec) fov += amt * (1 - a / dec); }
  if (window.__cam) { sh.pos.set(...window.__cam.pos); sh.look.set(...window.__cam.look); sh.fov = window.__cam.fov || 40; off.set(0, 0, 0); roll = 0; fov = sh.fov; }
  camera.position.copy(sh.pos); camera.lookAt(sh.look); camera.position.add(off); camera.rotateZ(roll); camera.fov = clamp(fov, 8, 110); camera.updateProjectionMatrix();
  uScale.value = H / (2 * Math.tan(rad(camera.fov) / 2));
  // faixas, fades, flash, impact frame, pós (CSS)
  const bars = 0.12 * smooth(clamp(t / 0.9)); barT.style.height = barB.style.height = bars * 100 + "%";
  let wo = 0; const bf = evT("BeginFade"), we = evT("WhiteOutEnd"); if (t >= bf) wo = clamp((t - bf) / 0.4); if (t >= we) wo = 1 - clamp((t - we) / 0.35);
  fadeEl.style.background = "#fff"; let black = 0; const fb = evT("FadeToBlack"), ff = evT("FadeFromBlack"); if (t >= fb) black = clamp((t - fb) / 1.3); if (t >= ff) black = 1 - clamp((t - ff) / 1.4);
  let fl = 0; if (t >= rel && t < rel + 0.30) fl = t < rel + 0.05 ? 1 : 1 - (t - rel - 0.05) / 0.25;
  const imp = evT("ImpactFrame"), isImp = t >= imp && t < imp + 0.12;
  if (black > 0) { fadeEl.style.background = "#000"; fadeEl.style.opacity = black; } else fadeEl.style.opacity = wo;
  flashEl.style.background = isImp && t < imp + 0.04 ? "#000" : "#fff"; flashEl.style.opacity = isImp && t < imp + 0.04 ? 1 : fl;
  let pulse = 0; for (const e of evAll("PulseLight")) { const a = t - e.t; if (a >= 0 && a < 0.45) pulse += e.arg * 0.5 * (1 - a / 0.45) * 0.25; }
  if (t >= rel && t < rel + 0.45) pulse += 0.3 * (1 - (t - rel) / 0.45);
  canvas.style.filter = isImp ? "grayscale(1) contrast(1.9) brightness(1.1)" : `saturate(${P.sat}) contrast(${P.con}) brightness(${P.br + pulse})`;
  if (studio) {
    smokeL.reset(); sparkL.reset(); smokeL.flush(); sparkL.flush(); shardMesh.count = 0; ringMeshes.forEach((m) => (m.visible = false));
    dome.visible = spireO.visible = spireI.visible = trailBlack.visible = trailWhite.visible = false; tendrilMeshes.forEach((m) => (m.visible = false));
    pBlue.intensity = pWhite.intensity = pEye.intensity = pMask.intensity = pFace.intensity = 0;
    fadeEl.style.opacity = flashEl.style.opacity = 0; barT.style.height = barB.style.height = "0"; canvas.style.filter = "none";
    sun.position.set(-30, 60, -50);
  } else sun.position.set(40, 70, -30);
  renderer.render(scene, camera);
  // legenda
  const phase = DATA.events.filter((e) => e.t <= t).slice(-1)[0];
  el("lbl").textContent = `t=${t.toFixed(2)}s · ${currentPhase(t)} · ${phase ? phase.name : ""}`;
}
function currentPhase(t) { return t < 5 ? "Ativação" : t < 12 ? "Concentração" : t < 19 ? "Transformação" : t < 26 ? "Liberação" : "Final"; }

// ------------------------------------------------------------------ controle
let t = 0, playing = true, last = performance.now();
const seek = el("seek"), play = el("play");
window.seek = (v) => { t = v; playing = false; render(t); };
window.__ready = true;
window.__bladeAt = (tt) => { applyPose(tt); setForm(tt >= evT("MorphSwap") ? "Mugetsu" : "Ichigo"); scene.updateMatrixWorld(true); const k = kits[currentForm].named; const r = (o) => wp(o).toArray().map((v, i) => +(v - (i === 1 ? 3 : 0)).toFixed(2)); return { base: r(k.TrailA), tip: r(k.TrailB), hand: r(R.handC), head: r(headC) }; }; // depuração (relativo ao HRP)
seek.addEventListener("input", () => { t = +seek.value; playing = false; play.textContent = "▶"; });
play.addEventListener("click", () => { playing = !playing; play.textContent = playing ? "⏸" : "▶"; });
if (new URLSearchParams(location.search).has("shot")) { document.body.classList.add("shot"); playing = false; }
function loop(now) { const dt = (now - last) / 1000; last = now; if (playing) { t += dt; if (t > DATA.duration) t = 0; seek.value = t; } render(t); requestAnimationFrame(loop); }
requestAnimationFrame(loop);

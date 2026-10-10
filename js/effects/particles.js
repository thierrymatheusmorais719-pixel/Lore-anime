// ============================================================================
//  Sistemas de partículas
// ============================================================================
//  • GlowParticles — pontos brilhantes aditivos (energia, brasas, faíscas)
//  • SparkLines    — faíscas alongadas (rastros) desenhadas como segmentos
//  • Smoke         — fumaça volumosa com blending normal e rotação
//  • Debris        — pedaços de rocha com física simples (InstancedMesh)
// Todos usam pools de tamanho fixo (sem alocação por quadro).
import * as THREE from 'three';
import { CONFIG } from '../config.js';
import { rand, randomDir, makeSmokeTexture } from '../utils.js';

const _c0 = new THREE.Color();
const _c1 = new THREE.Color();
const _v = new THREE.Vector3();

// ---------------------------------------------------------------------------
export class GlowParticles {
  constructor(scene, max = CONFIG.quality.maxParticles) {
    this.max = max;
    this.pos = new Float32Array(max * 3);
    this.vel = new Float32Array(max * 3);
    this.col = new Float32Array(max * 3);
    this.c0 = new Float32Array(max * 3);
    this.c1 = new Float32Array(max * 3);
    this.size = new Float32Array(max);
    this.s0 = new Float32Array(max);
    this.s1 = new Float32Array(max);
    this.alpha = new Float32Array(max);
    this.life = new Float32Array(max);
    this.maxLife = new Float32Array(max);
    this.drag = new Float32Array(max);
    this.grav = new Float32Array(max);
    this.attract = new Float32Array(max);           // força em direção ao alvo
    this.target = new Float32Array(max * 3);
    this.cursor = 0;

    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('color', new THREE.BufferAttribute(this.col, 3).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('size', new THREE.BufferAttribute(this.size, 1).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('alpha', new THREE.BufferAttribute(this.alpha, 1).setUsage(THREE.DynamicDrawUsage));
    this.geo = geo;

    this.material = new THREE.ShaderMaterial({
      uniforms: { uScale: { value: 500 } },
      vertexShader: /* glsl */`
        attribute float size; attribute float alpha; attribute vec3 color;
        uniform float uScale;
        varying vec3 vColor; varying float vAlpha;
        void main(){
          vColor = color; vAlpha = alpha;
          vec4 mv = modelViewMatrix * vec4(position, 1.0);
          gl_PointSize = size * uScale / max(0.05, -mv.z);
          gl_Position = projectionMatrix * mv;
        }`,
      fragmentShader: /* glsl */`
        varying vec3 vColor; varying float vAlpha;
        void main(){
          float d = length(gl_PointCoord - 0.5) * 2.0;
          if (d > 1.0) discard;
          float glow = exp(-d * d * 4.0);
          float core = exp(-d * d * 28.0);
          vec3 c = vColor * glow * 0.7 + vec3(1.0, 0.97, 0.9) * core * 0.8;
          gl_FragColor = vec4(c * vAlpha, 1.0);
        }`,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
      transparent: true,
    });
    this.points = new THREE.Points(geo, this.material);
    this.points.frustumCulled = false;
    scene.add(this.points);
  }

  /**
   * Emite uma partícula.
   * o: { pos, vel, life, size:[a,b], color:[c0,c1], drag, gravity, attract, target }
   */
  spawn(o) {
    const i = this.cursor;
    this.cursor = (this.cursor + 1) % this.max;
    const i3 = i * 3;
    this.pos[i3] = o.pos.x; this.pos[i3 + 1] = o.pos.y; this.pos[i3 + 2] = o.pos.z;
    const v = o.vel || _v.set(0, 0, 0);
    this.vel[i3] = v.x; this.vel[i3 + 1] = v.y; this.vel[i3 + 2] = v.z;
    _c0.set(o.color ? o.color[0] : 0xffc93c);
    _c1.set(o.color ? o.color[1] ?? o.color[0] : 0xff5a00);
    const hdr = o.intensity ?? 1.5;
    this.c0[i3] = _c0.r * hdr; this.c0[i3 + 1] = _c0.g * hdr; this.c0[i3 + 2] = _c0.b * hdr;
    this.c1[i3] = _c1.r * hdr; this.c1[i3 + 1] = _c1.g * hdr; this.c1[i3 + 2] = _c1.b * hdr;
    this.s0[i] = o.size ? o.size[0] : 0.1;
    this.s1[i] = o.size ? o.size[1] ?? o.size[0] : 0.02;
    this.life[i] = this.maxLife[i] = o.life ?? 1;
    this.drag[i] = o.drag ?? 1;
    this.grav[i] = o.gravity ?? 0;
    this.attract[i] = o.attract ?? 0;
    if (o.target) { this.target[i3] = o.target.x; this.target[i3 + 1] = o.target.y; this.target[i3 + 2] = o.target.z; }
  }

  /** Explosão de partículas a partir de um ponto. */
  burst(center, count, o = {}) {
    const [smin, smax] = o.speed || [2, 8];
    for (let k = 0; k < count; k++) {
      randomDir(_v);
      if (o.hemisphere) _v.y = Math.abs(_v.y);
      if (o.flat) { _v.y *= o.flat; }
      if (o.upBias) _v.y += o.upBias;
      _v.normalize().multiplyScalar(rand(smin, smax));
      const p = new THREE.Vector3(center.x, center.y, center.z);
      if (o.radius) p.add(randomDir().multiplyScalar(Math.random() * o.radius));
      this.spawn({
        pos: p, vel: _v.clone(),
        life: rand(...(o.life || [0.6, 1.6])),
        size: o.size || [rand(0.06, 0.16), 0.01],
        color: o.color || [0xfff1b0, 0xff7a00],
        drag: o.drag ?? 2.2,
        gravity: o.gravity ?? -3,
        intensity: o.intensity,
      });
    }
  }

  clear() { this.life.fill(0); this.alpha.fill(0); this.size.fill(0); }

  update(dt, viewportH, fov) {
    this.material.uniforms.uScale.value = viewportH / (2 * Math.tan((fov * Math.PI) / 360));
    const P = this.pos, V = this.vel;
    for (let i = 0; i < this.max; i++) {
      if (this.life[i] <= 0) { this.alpha[i] = 0; this.size[i] = 0; continue; }
      this.life[i] -= dt;
      const t = 1 - Math.max(0, this.life[i]) / this.maxLife[i]; // 0 → 1
      const i3 = i * 3;
      const dr = Math.exp(-this.drag[i] * dt);
      V[i3] *= dr; V[i3 + 1] = V[i3 + 1] * dr + this.grav[i] * dt; V[i3 + 2] *= dr;
      const at = this.attract[i];
      if (at) {
        const dx = this.target[i3] - P[i3], dy = this.target[i3 + 1] - P[i3 + 1], dz = this.target[i3 + 2] - P[i3 + 2];
        V[i3] += dx * at * dt; V[i3 + 1] += dy * at * dt; V[i3 + 2] += dz * at * dt;
        if (dx * dx + dy * dy + dz * dz < 0.004) this.life[i] = 0;
      }
      P[i3] += V[i3] * dt; P[i3 + 1] += V[i3 + 1] * dt; P[i3 + 2] += V[i3 + 2] * dt;
      if (P[i3 + 1] < 0.02 && this.grav[i] < 0) { P[i3 + 1] = 0.02; V[i3 + 1] *= -0.3; }
      this.col[i3] = this.c0[i3] + (this.c1[i3] - this.c0[i3]) * t;
      this.col[i3 + 1] = this.c0[i3 + 1] + (this.c1[i3 + 1] - this.c0[i3 + 1]) * t;
      this.col[i3 + 2] = this.c0[i3 + 2] + (this.c1[i3 + 2] - this.c0[i3 + 2]) * t;
      this.size[i] = this.s0[i] + (this.s1[i] - this.s0[i]) * t;
      this.alpha[i] = Math.min(1, t * 12) * (1 - t * t);
    }
    const a = this.geo.attributes;
    a.position.needsUpdate = a.color.needsUpdate = a.size.needsUpdate = a.alpha.needsUpdate = true;
  }
}

// ---------------------------------------------------------------------------
export class SparkLines {
  constructor(scene, max = 1500) {
    this.max = max;
    this.pos = new Float32Array(max * 6);   // cabeça + cauda
    this.col = new Float32Array(max * 6);
    this.p = new Float32Array(max * 3);
    this.v = new Float32Array(max * 3);
    this.life = new Float32Array(max);
    this.maxLife = new Float32Array(max);
    this.len = new Float32Array(max);
    this.cursor = 0;
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('color', new THREE.BufferAttribute(this.col, 3).setUsage(THREE.DynamicDrawUsage));
    this.geo = geo;
    this.lines = new THREE.LineSegments(geo, new THREE.LineBasicMaterial({
      vertexColors: true, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true,
    }));
    this.lines.frustumCulled = false;
    scene.add(this.lines);
    this.color = new THREE.Color(CONFIG.magic.gold);
  }

  burst(center, count, o = {}) {
    const [smin, smax] = o.speed || [6, 18];
    for (let k = 0; k < count; k++) {
      const i = this.cursor; this.cursor = (this.cursor + 1) % this.max;
      randomDir(_v);
      if (o.hemisphere) _v.y = Math.abs(_v.y) * 0.8 + 0.2;
      _v.normalize().multiplyScalar(rand(smin, smax));
      const i3 = i * 3;
      this.p[i3] = center.x; this.p[i3 + 1] = center.y; this.p[i3 + 2] = center.z;
      this.v[i3] = _v.x; this.v[i3 + 1] = _v.y; this.v[i3 + 2] = _v.z;
      this.life[i] = this.maxLife[i] = rand(...(o.life || [0.3, 0.9]));
      this.len[i] = o.length ?? 0.05;
    }
  }

  clear() { this.life.fill(0); this.pos.fill(0); this.col.fill(0); }

  update(dt) {
    for (let i = 0; i < this.max; i++) {
      const i3 = i * 3, i6 = i * 6;
      if (this.life[i] <= 0) { this.col.fill(0, i6, i6 + 6); continue; }
      this.life[i] -= dt;
      const k = Math.max(0, this.life[i] / this.maxLife[i]);
      const dr = Math.exp(-1.6 * dt);
      this.v[i3] *= dr; this.v[i3 + 1] = this.v[i3 + 1] * dr - 9.8 * dt; this.v[i3 + 2] *= dr;
      this.p[i3] += this.v[i3] * dt; this.p[i3 + 1] += this.v[i3 + 1] * dt; this.p[i3 + 2] += this.v[i3 + 2] * dt;
      if (this.p[i3 + 1] < 0.01) { this.p[i3 + 1] = 0.01; this.v[i3 + 1] *= -0.35; }
      const L = this.len[i];
      this.pos[i6] = this.p[i3]; this.pos[i6 + 1] = this.p[i3 + 1]; this.pos[i6 + 2] = this.p[i3 + 2];
      this.pos[i6 + 3] = this.p[i3] - this.v[i3] * L; this.pos[i6 + 4] = this.p[i3 + 1] - this.v[i3 + 1] * L; this.pos[i6 + 5] = this.p[i3 + 2] - this.v[i3 + 2] * L;
      const b = k * 3;
      this.col[i6] = 1.0 * b; this.col[i6 + 1] = 0.9 * b; this.col[i6 + 2] = 0.6 * b;
      this.col[i6 + 3] = this.color.r * b * 0.5; this.col[i6 + 4] = this.color.g * b * 0.3; this.col[i6 + 5] = 0;
    }
    this.geo.attributes.position.needsUpdate = this.geo.attributes.color.needsUpdate = true;
  }
}

// ---------------------------------------------------------------------------
export class Smoke {
  constructor(scene, max = CONFIG.quality.maxSmoke) {
    this.max = max;
    this.pos = new Float32Array(max * 3);
    this.vel = new Float32Array(max * 3);
    this.size = new Float32Array(max);
    this.s0 = new Float32Array(max);
    this.s1 = new Float32Array(max);
    this.alpha = new Float32Array(max);
    this.a0 = new Float32Array(max);
    this.rot = new Float32Array(max);
    this.rotV = new Float32Array(max);
    this.heat = new Float32Array(max);  // brilho quente no início
    this.life = new Float32Array(max);
    this.maxLife = new Float32Array(max);
    this.delay = new Float32Array(max);
    this.cursor = 0;

    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('size', new THREE.BufferAttribute(this.size, 1).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('alpha', new THREE.BufferAttribute(this.alpha, 1).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('rot', new THREE.BufferAttribute(this.rot, 1).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('heat', new THREE.BufferAttribute(this.heat, 1).setUsage(THREE.DynamicDrawUsage));
    this.geo = geo;
    this.material = new THREE.ShaderMaterial({
      uniforms: { uMap: { value: makeSmokeTexture() }, uScale: { value: 500 } },
      vertexShader: /* glsl */`
        attribute float size; attribute float alpha; attribute float rot; attribute float heat;
        uniform float uScale;
        varying float vAlpha; varying float vRot; varying float vHeat;
        void main(){
          vAlpha = alpha; vRot = rot; vHeat = heat;
          vec4 mv = modelViewMatrix * vec4(position, 1.0);
          gl_PointSize = min(size * uScale / max(0.1, -mv.z), 2048.0);
          gl_Position = projectionMatrix * mv;
        }`,
      fragmentShader: /* glsl */`
        uniform sampler2D uMap;
        varying float vAlpha; varying float vRot; varying float vHeat;
        void main(){
          vec2 uv = gl_PointCoord - 0.5;
          float c = cos(vRot), s = sin(vRot);
          uv = mat2(c, -s, s, c) * uv + 0.5;
          vec4 t = texture2D(uMap, uv);
          vec3 smoke = mix(vec3(0.09,0.07,0.11), vec3(0.22,0.18,0.22), t.r);
          vec3 hot = vec3(1.6, 0.8, 0.25);
          vec3 col = mix(smoke, hot, vHeat);
          gl_FragColor = vec4(col, t.a * vAlpha);
        }`,
      transparent: true,
      depthWrite: false,
    });
    this.points = new THREE.Points(geo, this.material);
    this.points.frustumCulled = false;
    this.points.renderOrder = 2;
    scene.add(this.points);
  }

  puff(center, count, o = {}) {
    for (let k = 0; k < count; k++) {
      const i = this.cursor; this.cursor = (this.cursor + 1) % this.max;
      const i3 = i * 3;
      randomDir(_v);
      _v.y = Math.abs(_v.y) * (o.up ?? 0.6);
      const sp = rand(...(o.speed || [0.5, 3]));
      const r = o.radius ?? 0.5;
      this.pos[i3] = center.x + _v.x * r; this.pos[i3 + 1] = center.y + _v.y * r * 0.5; this.pos[i3 + 2] = center.z + _v.z * r;
      this.vel[i3] = _v.x * sp; this.vel[i3 + 1] = _v.y * sp + (o.rise ?? 0.6); this.vel[i3 + 2] = _v.z * sp;
      this.s0[i] = rand(...(o.size0 || [0.6, 1.2]));
      this.s1[i] = rand(...(o.size1 || [2.5, 4.5]));
      this.a0[i] = o.alpha ?? 0.55;
      this.rot[i] = rand(0, 6.28); this.rotV[i] = rand(-0.6, 0.6);
      this.life[i] = this.maxLife[i] = rand(...(o.life || [2.5, 5]));
      this.delay[i] = o.delay ? rand(0, o.delay) : 0;
      this.heat[i] = o.heat ?? 0.8;
    }
  }

  clear() { this.life.fill(0); this.alpha.fill(0); this.size.fill(0); }

  update(dt, viewportH, fov) {
    this.material.uniforms.uScale.value = viewportH / (2 * Math.tan((fov * Math.PI) / 360));
    for (let i = 0; i < this.max; i++) {
      if (this.life[i] <= 0) { this.alpha[i] = 0; this.size[i] = 0; continue; }
      if (this.delay[i] > 0) { this.delay[i] -= dt; this.alpha[i] = 0; continue; }
      this.life[i] -= dt;
      const t = 1 - Math.max(0, this.life[i]) / this.maxLife[i];
      const i3 = i * 3;
      const dr = Math.exp(-1.8 * dt);
      this.vel[i3] *= dr; this.vel[i3 + 1] = this.vel[i3 + 1] * dr + 0.25 * dt; this.vel[i3 + 2] *= dr;
      this.pos[i3] += this.vel[i3] * dt; this.pos[i3 + 1] += this.vel[i3 + 1] * dt; this.pos[i3 + 2] += this.vel[i3 + 2] * dt;
      this.rot[i] += this.rotV[i] * dt;
      this.size[i] = this.s0[i] + (this.s1[i] - this.s0[i]) * (1 - Math.pow(1 - t, 2));
      this.alpha[i] = this.a0[i] * Math.min(1, t * 6) * (1 - t);
      this.heat[i] = Math.max(0, this.heat[i] - dt * 2.2);
    }
    const a = this.geo.attributes;
    a.position.needsUpdate = a.size.needsUpdate = a.alpha.needsUpdate = a.rot.needsUpdate = a.heat.needsUpdate = true;
  }
}

// ---------------------------------------------------------------------------
export class Debris {
  constructor(scene, max = 220) {
    this.max = max;
    const geo = new THREE.DodecahedronGeometry(1, 0);
    const mat = new THREE.MeshStandardMaterial({ color: 0x3a3346, roughness: 1, flatShading: true, emissive: 0x401800, emissiveIntensity: 0 });
    this.mesh = new THREE.InstancedMesh(geo, mat, max);
    this.mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.mesh.castShadow = true;
    this.mesh.frustumCulled = false;
    scene.add(this.mesh);
    this.items = Array.from({ length: max }, () => ({
      p: new THREE.Vector3(), v: new THREE.Vector3(), r: new THREE.Euler(), rv: new THREE.Vector3(), s: 0, life: 0,
    }));
    this.cursor = 0;
    this.m = new THREE.Matrix4();
    this.q = new THREE.Quaternion();
    this.sc = new THREE.Vector3();
    this.clear();
  }

  burst(center, count, o = {}) {
    for (let k = 0; k < count; k++) {
      const it = this.items[this.cursor]; this.cursor = (this.cursor + 1) % this.max;
      it.p.copy(center).add(_v.set(rand(-0.4, 0.4), 0.1, rand(-0.4, 0.4)));
      randomDir(it.v); it.v.y = Math.abs(it.v.y) * 1.4 + 0.4;
      it.v.normalize().multiplyScalar(rand(...(o.speed || [4, 12])));
      it.r.set(rand(0, 6), rand(0, 6), rand(0, 6));
      it.rv.set(rand(-8, 8), rand(-8, 8), rand(-8, 8));
      it.s = rand(...(o.size || [0.05, 0.22]));
      it.life = rand(3, 5);
    }
  }

  clear() {
    for (let i = 0; i < this.max; i++) {
      this.items[i].life = 0;
      this.m.makeScale(0, 0, 0);
      this.mesh.setMatrixAt(i, this.m);
    }
    this.mesh.instanceMatrix.needsUpdate = true;
  }

  update(dt) {
    for (let i = 0; i < this.max; i++) {
      const it = this.items[i];
      if (it.life <= 0) { this.m.makeScale(0, 0, 0); this.mesh.setMatrixAt(i, this.m); continue; }
      it.life -= dt;
      it.v.y -= 14 * dt;
      it.p.addScaledVector(it.v, dt);
      if (it.p.y < it.s * 0.6) {
        it.p.y = it.s * 0.6;
        it.v.y *= -0.3; it.v.x *= 0.6; it.v.z *= 0.6; it.rv.multiplyScalar(0.6);
      }
      it.r.x += it.rv.x * dt; it.r.y += it.rv.y * dt; it.r.z += it.rv.z * dt;
      this.q.setFromEuler(it.r);
      const s = it.s * Math.min(1, it.life * 2);
      this.sc.set(s, s, s);
      this.m.compose(it.p, this.q, this.sc);
      this.mesh.setMatrixAt(i, this.m);
    }
    this.mesh.instanceMatrix.needsUpdate = true;
  }
}

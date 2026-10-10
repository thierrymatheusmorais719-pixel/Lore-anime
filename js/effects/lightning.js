// Raios: caminho fractal (deslocamento do ponto médio) com ramificações,
// renderizado como fita voltada para a câmera com shader de brilho.
import * as THREE from 'three';
import { CONFIG } from '../config.js';
import { rand } from '../utils.js';

const mat = new THREE.ShaderMaterial({
  uniforms: { uColor: { value: new THREE.Color(CONFIG.magic.gold) } },
  vertexShader: /* glsl */`
    attribute float side; attribute float bright;
    varying float vSide; varying float vBright;
    void main(){ vSide = side; vBright = bright; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
  fragmentShader: /* glsl */`
    uniform vec3 uColor;
    varying float vSide; varying float vBright;
    void main(){
      float d = abs(vSide);
      float core = smoothstep(0.22, 0.0, d);
            float halo = exp(-d * 7.0);
      vec3 c = uColor * halo * 0.45 + vec3(1.0,0.98,0.9) * core * 2.2;
      gl_FragColor = vec4(c * vBright, 1.0);
    }`,
  blending: THREE.AdditiveBlending,
  depthWrite: false,
  transparent: true,
  side: THREE.DoubleSide,
});

function fractalPath(a, b, depth, rough) {
  let pts = [a.clone(), b.clone()];
  let off = a.distanceTo(b) * rough;
  for (let d = 0; d < depth; d++) {
    const next = [pts[0]];
    for (let i = 0; i < pts.length - 1; i++) {
      const p = pts[i], q = pts[i + 1];
      const m = p.clone().lerp(q, 0.5);
      m.x += rand(-off, off); m.y += rand(-off, off) * 0.5; m.z += rand(-off, off);
      next.push(m, q);
    }
    pts = next;
    off *= 0.52;
  }
  return pts;
}

class Bolt {
  constructor(scene, a, b, o) {
    this.scene = scene;
    this.a = a.clone(); this.b = b.clone();
    this.width = o.width ?? 0.35;
    this.life = this.maxLife = o.life ?? 0.45;
    this.branches = o.branches ?? 3;
    this.depth = o.depth ?? 6;
    this.rough = o.rough ?? 0.18;
    this.regen = 0;
    this.geo = new THREE.BufferGeometry();
    this.mesh = new THREE.Mesh(this.geo, mat);
    this.mesh.frustumCulled = false;
    scene.add(this.mesh);
    this._generate();
  }

  _generate() {
    this.paths = [];
    const main = fractalPath(this.a, this.b, this.depth, this.rough);
    this.paths.push({ pts: main, w: 1 });
    for (let k = 0; k < this.branches; k++) {
      const i = Math.floor(rand(0.15, 0.75) * main.length);
      const start = main[i];
      const dir = main[Math.min(main.length - 1, i + 4)].clone().sub(start);
      const len = this.a.distanceTo(this.b) * rand(0.15, 0.35);
      dir.normalize().add(new THREE.Vector3(rand(-0.9, 0.9), rand(-0.4, 0.2), rand(-0.9, 0.9))).normalize().multiplyScalar(len);
      this.paths.push({ pts: fractalPath(start, start.clone().add(dir), this.depth - 2, 0.25), w: 0.45 });
    }
  }

  build(camPos) {
    const pos = [], side = [], bright = [], idx = [];
    let base = 0;
    const k = Math.max(0, this.life / this.maxLife);
    const flicker = (0.55 + Math.random() * 0.45) * (0.4 + k * 0.6);
    const t = new THREE.Vector3(), toCam = new THREE.Vector3(), s = new THREE.Vector3();
    for (const path of this.paths) {
      const P = path.pts;
      const n = P.length;
      for (let i = 0; i < n; i++) {
        const p = P[i];
        t.copy(P[Math.min(n - 1, i + 1)]).sub(P[Math.max(0, i - 1)]).normalize();
        toCam.copy(camPos).sub(p).normalize();
        s.crossVectors(t, toCam).normalize();
        const taper = path.w < 1 ? 1 - i / n : 1;
        const w = this.width * path.w * (0.4 + 0.6 * taper);
        pos.push(p.x + s.x * w, p.y + s.y * w, p.z + s.z * w, p.x - s.x * w, p.y - s.y * w, p.z - s.z * w);
        side.push(1, -1);
        const b = flicker * path.w;
        bright.push(b, b);
        if (i < n - 1) {
          const a0 = base + i * 2;
          idx.push(a0, a0 + 1, a0 + 2, a0 + 1, a0 + 3, a0 + 2);
        }
      }
      base += n * 2;
    }
    this.geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    this.geo.setAttribute('side', new THREE.Float32BufferAttribute(side, 1));
    this.geo.setAttribute('bright', new THREE.Float32BufferAttribute(bright, 1));
    this.geo.setIndex(idx);
  }

  update(dt, camPos) {
    this.life -= dt;
    this.regen -= dt;
    if (this.regen <= 0) { this._generate(); this.regen = 0.06; }
    this.build(camPos);
    return this.life > 0;
  }

  dispose() {
    this.scene.remove(this.mesh);
    this.geo.dispose();
  }
}

export class LightningSystem {
  constructor(scene) {
    this.scene = scene;
    this.bolts = [];
  }

  /** Cria um raio de `a` até `b`. */
  bolt(a, b, o = {}) {
    const bolt = new Bolt(this.scene, a, b, o);
    this.bolts.push(bolt);
    return bolt;
  }

  clear() {
    for (const b of this.bolts) b.dispose();
    this.bolts.length = 0;
  }

  update(dt, camera) {
    for (let i = this.bolts.length - 1; i >= 0; i--) {
      if (!this.bolts[i].update(dt, camera.position)) {
        this.bolts[i].dispose();
        this.bolts.splice(i, 1);
      }
    }
  }
}

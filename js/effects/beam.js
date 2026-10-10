// Feixe de energia: dois cilindros (núcleo + aura) com shader animado
// orientados da origem até o alvo; o comprimento cresce ao disparar.
import * as THREE from 'three';
import { CONFIG } from '../config.js';
import { GLSL_NOISE } from '../utils.js';

function beamMaterial(core) {
  return new THREE.ShaderMaterial({
    uniforms: {
      uTime: { value: 0 }, uOpacity: { value: 0 },
      uColor: { value: new THREE.Color(core ? CONFIG.magic.core : CONFIG.magic.gold) },
      uLen: { value: 1 },
    },
    vertexShader: GLSL_NOISE + /* glsl */`
      uniform float uTime; uniform float uLen;
      varying vec2 vUv; varying vec3 vN; varying vec3 vV; varying float vNoise;
      void main(){
        vUv = uv;
        float n = snoise(vec3(uv.x * 4.0, uv.y * uLen * 0.6 - uTime * 8.0, uTime));
        vNoise = n;
        vec3 p = position + normal * n * ${core ? '0.03' : '0.12'};
        vec4 mv = modelViewMatrix * vec4(p, 1.0);
        vN = normalize(normalMatrix * normal); vV = normalize(-mv.xyz);
        gl_Position = projectionMatrix * mv;
      }`,
    fragmentShader: /* glsl */`
      uniform float uTime; uniform float uOpacity; uniform vec3 uColor; uniform float uLen;
      varying vec2 vUv; varying vec3 vN; varying vec3 vV; varying float vNoise;
      void main(){
        float facing = abs(dot(vN, vV));
        float body = ${core ? 'pow(facing, 0.6) * 3.5' : 'pow(facing, 1.5) * 0.9 + pow(1.0 - facing, 3.0) * 0.6'};
        float streaks = 0.7 + 0.3 * sin(vUv.y * uLen * 6.0 - uTime * 40.0 + vUv.x * 18.0);
        float tip = smoothstep(1.0, 0.97, vUv.y);
        vec3 c = uColor * body * streaks * (0.85 + vNoise * 0.3);
        gl_FragColor = vec4(c * uOpacity * tip, 1.0);
      }`,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
    transparent: true,
  });
}

export class Beam {
  constructor(scene) {
    this.group = new THREE.Group();
    scene.add(this.group);
    const mk = (r, core) => {
      const geo = new THREE.CylinderGeometry(r, r, 1, 24, 40, true);
      geo.translate(0, 0.5, 0); // base na origem, cresce em +Y
      const m = new THREE.Mesh(geo, beamMaterial(core));
      m.frustumCulled = false;
      this.group.add(m);
      return m;
    };
    this.core = mk(0.16, true);
    this.aura = mk(0.5, false);
    this.active = false;
    this.opacity = 0;
    this.extend = 0;
    this.width = 1;
    this.from = new THREE.Vector3();
    this.to = new THREE.Vector3();
    this.group.visible = false;
  }

  fire(from, to) {
    this.active = true;
    this.extend = 0;
    this.from.copy(from); this.to.copy(to);
    this.group.visible = true;
  }

  stop() { this.active = false; }

  reset() { this.active = false; this.opacity = 0; this.extend = 0; this.group.visible = false; }

  /** Ponta atual do feixe (para efeitos de impacto). */
  tip(out = new THREE.Vector3()) { return out.copy(this.from).lerp(this.to, this.extend); }

  update(dt, time, from) {
    if (from) this.from.copy(from);
    if (this.active) {
      this.opacity = Math.min(1, this.opacity + dt * 8);
      this.extend = Math.min(1, this.extend + dt * 4.5);
    } else {
      this.opacity = Math.max(0, this.opacity - dt * 3);
    }
    if (this.opacity <= 0) { this.group.visible = false; return; }
    const dir = new THREE.Vector3().subVectors(this.to, this.from);
    const len = dir.length() * this.extend;
    this.group.position.copy(this.from);
    this.group.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.normalize());
    const w = this.width * (1 + Math.sin(time * 40) * 0.06) * (this.active ? 1 : this.opacity);
    for (const m of [this.core, this.aura]) {
      m.scale.set(w, Math.max(0.001, len), w);
      m.material.uniforms.uTime.value = time;
      m.material.uniforms.uOpacity.value = this.opacity;
      m.material.uniforms.uLen.value = len;
    }
  }
}

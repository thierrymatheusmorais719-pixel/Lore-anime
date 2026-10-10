// Explosões mágicas: bola de energia com ruído, anel de choque no chão,
// casca de choque esférica e pulso de luz.
import * as THREE from 'three';
import { CONFIG } from '../config.js';
import { GLSL_NOISE, ease, clamp } from '../utils.js';

const fireballMat = new THREE.ShaderMaterial({
  uniforms: {
    uTime: { value: 0 }, uProgress: { value: 0 }, uSeed: { value: 0 },
    uCore: { value: new THREE.Color(CONFIG.magic.core) },
    uGold: { value: new THREE.Color(CONFIG.magic.gold) },
    uAmber: { value: new THREE.Color(CONFIG.magic.amber) },
    uDeep: { value: new THREE.Color(CONFIG.magic.deep) },
  },
  vertexShader: GLSL_NOISE + /* glsl */`
    uniform float uTime; uniform float uProgress; uniform float uSeed;
    varying float vNoise; varying vec3 vNormal; varying vec3 vView;
    void main(){
      float n = fbm(normal * 1.6 + vec3(uSeed) + vec3(0.0, -uTime * 1.4, 0.0));
      vNoise = n;
      vec3 p = position * (1.0 + n * 0.45 * (0.5 + uProgress));
      vec4 mv = modelViewMatrix * vec4(p, 1.0);
      vNormal = normalize(normalMatrix * normal);
      vView = normalize(-mv.xyz);
      gl_Position = projectionMatrix * mv;
    }`,
  fragmentShader: /* glsl */`
    uniform float uProgress;
    uniform vec3 uCore; uniform vec3 uGold; uniform vec3 uAmber; uniform vec3 uDeep;
    varying float vNoise; varying vec3 vNormal; varying vec3 vView;
    void main(){
      float fres = pow(1.0 - abs(dot(vNormal, vView)), 1.5);
      float heat = clamp(vNoise * 0.8 + 0.55 - uProgress * 0.9, 0.0, 1.0);
      vec3 col = mix(uDeep, uAmber, smoothstep(0.0, 0.35, heat));
      col = mix(col, uGold, smoothstep(0.35, 0.65, heat));
      col = mix(col, uCore, smoothstep(0.7, 1.0, heat));
      float alpha = (1.0 - smoothstep(0.45, 1.0, uProgress)) * (0.55 + 0.45 * (1.0 - fres));
      // erosão: buracos aparecem conforme a explosão se dissipa
      alpha *= smoothstep(uProgress * 0.9 - 0.15, uProgress * 0.9 + 0.1, vNoise * 0.5 + 0.5);
      gl_FragColor = vec4(col * (0.55 + heat * 1.5) * alpha, 1.0);
    }`,
  blending: THREE.AdditiveBlending,
  depthWrite: false,
  transparent: true,
});

const ringMat = new THREE.ShaderMaterial({
  uniforms: { uProgress: { value: 0 }, uColor: { value: new THREE.Color(CONFIG.magic.gold) } },
  vertexShader: /* glsl */`
    varying vec2 vUv;
    void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
  fragmentShader: /* glsl */`
    uniform float uProgress; uniform vec3 uColor;
    varying vec2 vUv;
    void main(){
      float r = length(vUv - 0.5) * 2.0;           // 0 centro → 1 borda
      float edge = 0.92;
      float band = smoothstep(edge - 0.18, edge, r) * (1.0 - smoothstep(edge, 1.0, r));
      float inner = smoothstep(0.0, edge, r) * 0.03;
      float fade = 1.0 - smoothstep(0.0, 1.0, uProgress);
      vec3 c = uColor * (band * 1.4 + inner) + vec3(1.0) * band * band * 0.6;
      gl_FragColor = vec4(c * fade, 1.0);
    }`,
  blending: THREE.AdditiveBlending,
  depthWrite: false,
  transparent: true,
  side: THREE.DoubleSide,
});

const shellMat = new THREE.ShaderMaterial({
  uniforms: { uProgress: { value: 0 }, uColor: { value: new THREE.Color(CONFIG.magic.amber) } },
  vertexShader: /* glsl */`
    varying vec3 vN; varying vec3 vV;
    void main(){
      vec4 mv = modelViewMatrix * vec4(position,1.0);
      vN = normalize(normalMatrix * normal); vV = normalize(-mv.xyz);
      gl_Position = projectionMatrix * mv;
    }`,
  fragmentShader: /* glsl */`
    uniform float uProgress; uniform vec3 uColor;
    varying vec3 vN; varying vec3 vV;
    void main(){
      float f = pow(1.0 - abs(dot(vN, vV)), 3.0);
      float a = f * (1.0 - uProgress) * (1.0 - uProgress);
      gl_FragColor = vec4(uColor * a * 0.8, 1.0);
    }`,
  blending: THREE.AdditiveBlending,
  depthWrite: false,
  transparent: true,
});

const sphereGeo = new THREE.IcosahedronGeometry(1, 5);
const ringGeo = new THREE.PlaneGeometry(2, 2);

export class ExplosionSystem {
  constructor(scene) {
    this.scene = scene;
    this.items = [];
    this.light = new THREE.PointLight(CONFIG.magic.gold, 0, 40, 1.5);
    this.light.position.set(0, 2, 0);
    scene.add(this.light);
    this.lightLevel = 0;
  }

  /**
   * Cria os elementos geométricos de uma explosão.
   * size: raio final da bola de energia.
   */
  spawn(pos, size = 2, o = {}) {
    const dur = o.duration ?? 1.4;
    const fb = new THREE.Mesh(sphereGeo, fireballMat.clone());
    fb.position.copy(pos);
    fb.material.uniforms.uSeed.value = Math.random() * 100;
    fb.frustumCulled = false;
    this.scene.add(fb);
    this.items.push({ mesh: fb, t: 0, dur, kind: 'fireball', size });

    if (o.ring !== false) {
      const ring = new THREE.Mesh(ringGeo, ringMat.clone());
      ring.rotation.x = -Math.PI / 2;
      ring.position.set(pos.x, 0.05, pos.z);
      this.scene.add(ring);
      this.items.push({ mesh: ring, t: 0, dur: dur * 1.1, kind: 'ring', size: size * (o.ringScale ?? 4.5) });
    }
    if (o.shell !== false) {
      const shell = new THREE.Mesh(sphereGeo, shellMat.clone());
      shell.position.copy(pos);
      this.scene.add(shell);
      this.items.push({ mesh: shell, t: 0, dur: dur * 0.6, kind: 'shell', size: size * 3.2 });
    }
    this.light.position.copy(pos).add(new THREE.Vector3(0, 0.8, 0));
    this.lightLevel = Math.max(this.lightLevel, 8 * size);
  }

  /** Apenas um anel de choque (ex.: ao pousar). */
  ring(pos, size = 4, dur = 1) {
    const ring = new THREE.Mesh(ringGeo, ringMat.clone());
    ring.rotation.x = -Math.PI / 2;
    ring.position.set(pos.x, 0.05, pos.z);
    this.scene.add(ring);
    this.items.push({ mesh: ring, t: 0, dur, kind: 'ring', size });
  }

  clear() {
    for (const it of this.items) { this.scene.remove(it.mesh); it.mesh.material.dispose(); }
    this.items.length = 0;
    this.lightLevel = 0;
    this.light.intensity = 0;
  }

  update(dt, time) {
    for (let i = this.items.length - 1; i >= 0; i--) {
      const it = this.items[i];
      it.t += dt;
      const p = clamp(it.t / it.dur);
      const u = it.mesh.material.uniforms;
      u.uProgress.value = p;
      if (it.kind === 'fireball') {
        u.uTime.value = time;
        it.mesh.scale.setScalar(it.size * (0.15 + 0.85 * ease.outExpo(p)));
      } else if (it.kind === 'ring') {
        it.mesh.scale.setScalar(it.size * ease.outCubic(p) + 0.01);
      } else {
        it.mesh.scale.setScalar(it.size * ease.outQuad(p) + 0.01);
      }
      if (p >= 1) {
        this.scene.remove(it.mesh);
        it.mesh.material.dispose();
        this.items.splice(i, 1);
      }
    }
    this.lightLevel *= Math.exp(-dt * 4);
    this.light.intensity = this.lightLevel;
  }
}

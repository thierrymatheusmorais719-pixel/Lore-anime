// Círculo mágico rúnico (textura desenhada em canvas) e pilar de luz.
import * as THREE from 'three';
import { CONFIG } from '../config.js';
import { rand } from '../utils.js';

function drawGlyph(g, x, y, s) {
  // runas procedurais: traços retos aleatórios dentro de uma célula
  g.beginPath();
  const n = 2 + ((Math.random() * 3) | 0);
  for (let i = 0; i < n; i++) {
    const ax = x + rand(-s, s), ay = y + rand(-s, s);
    g.moveTo(ax, ay);
    g.lineTo(x + rand(-s, s), y + rand(-s, s));
  }
  g.stroke();
}

function makeCircleTexture(variant = 0) {
  const S = 1024, c = document.createElement('canvas');
  c.width = c.height = S;
  const g = c.getContext('2d');
  const cx = S / 2;
  g.translate(cx, cx);
  g.strokeStyle = '#fff';
  g.fillStyle = '#fff';
  g.lineCap = 'round';
  g.shadowColor = '#fff';
  g.shadowBlur = 8;

  const circle = (r, w) => { g.lineWidth = w; g.beginPath(); g.arc(0, 0, r, 0, Math.PI * 2); g.stroke(); };

  if (variant === 0) {
    circle(500, 6); circle(482, 2); circle(400, 4); circle(300, 3); circle(150, 5);
    // anel de runas
    g.lineWidth = 3;
    const runes = 36;
    for (let i = 0; i < runes; i++) {
      const a = (i / runes) * Math.PI * 2;
      g.save(); g.rotate(a); drawGlyph(g, 0, -441, 15); g.restore();
    }
    // marcas
    for (let i = 0; i < 120; i++) {
      const a = (i / 120) * Math.PI * 2;
      const l = i % 5 === 0 ? 22 : 10;
      g.lineWidth = 2;
      g.beginPath(); g.moveTo(Math.cos(a) * 400, Math.sin(a) * 400); g.lineTo(Math.cos(a) * (400 - l), Math.sin(a) * (400 - l)); g.stroke();
    }
    // dois triângulos (hexagrama) e um heptagrama interno
    g.lineWidth = 4;
    for (const off of [0, Math.PI]) {
      g.beginPath();
      for (let i = 0; i <= 3; i++) {
        const a = off + (i / 3) * Math.PI * 2 - Math.PI / 2;
        const x = Math.cos(a) * 300, y = Math.sin(a) * 300;
        i ? g.lineTo(x, y) : g.moveTo(x, y);
      }
      g.stroke();
    }
    g.lineWidth = 3;
    g.beginPath();
    for (let i = 0; i <= 7; i++) {
      const a = (i * 3 / 7) * Math.PI * 2 - Math.PI / 2;
      const x = Math.cos(a) * 150, y = Math.sin(a) * 150;
      i ? g.lineTo(x, y) : g.moveTo(x, y);
    }
    g.stroke();
    // pequenos círculos nas pontas
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * Math.PI * 2 - Math.PI / 2;
      g.lineWidth = 3;
      g.beginPath(); g.arc(Math.cos(a) * 300, Math.sin(a) * 300, 26, 0, Math.PI * 2); g.stroke();
      g.beginPath(); g.arc(Math.cos(a) * 300, Math.sin(a) * 300, 8, 0, Math.PI * 2); g.fill();
    }
    g.beginPath(); g.arc(0, 0, 30, 0, Math.PI * 2); g.fill();
  } else {
    // anel externo secundário
    circle(505, 3); circle(470, 8);
    g.lineWidth = 2;
    for (let i = 0; i < 64; i++) {
      const a = (i / 64) * Math.PI * 2;
      g.save(); g.rotate(a); drawGlyph(g, 0, -488, 9); g.restore();
    }
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * Math.PI * 2;
      g.save(); g.rotate(a);
      g.beginPath(); g.moveTo(0, -470); g.lineTo(-18, -430); g.lineTo(18, -430); g.closePath(); g.fill();
      g.restore();
    }
  }
  const tex = new THREE.CanvasTexture(c);
  tex.anisotropy = 8;
  return tex;
}

const circleShader = (tex) => new THREE.ShaderMaterial({
  uniforms: {
    uMap: { value: tex }, uOpacity: { value: 0 }, uTime: { value: 0 },
    uColor: { value: new THREE.Color(CONFIG.magic.gold) },
  },
  vertexShader: /* glsl */`
    varying vec2 vUv;
    void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
  fragmentShader: /* glsl */`
    uniform sampler2D uMap; uniform float uOpacity; uniform float uTime; uniform vec3 uColor;
    varying vec2 vUv;
    void main(){
      float m = texture2D(uMap, vUv).r;
      float r = length(vUv - 0.5) * 2.0;
      float pulse = 0.75 + 0.25 * sin(uTime * 6.0 - r * 12.0);
      vec3 c = uColor * m * 1.1 * pulse + vec3(1.0, 0.95, 0.8) * pow(m, 3.0) * 0.5;
      c += uColor * 0.025 * smoothstep(1.0, 0.0, r);   // brilho difuso
      gl_FragColor = vec4(c * uOpacity, 1.0);
    }`,
  blending: THREE.AdditiveBlending,
  depthWrite: false,
  transparent: true,
  side: THREE.DoubleSide,
});

export class MagicCircle {
  constructor(scene, radius = 3) {
    this.group = new THREE.Group();
    this.group.position.y = 0.03;
    scene.add(this.group);
    const geo = new THREE.PlaneGeometry(radius * 2, radius * 2);
    this.inner = new THREE.Mesh(geo, circleShader(makeCircleTexture(0)));
    this.outer = new THREE.Mesh(geo, circleShader(makeCircleTexture(1)));
    this.outer.scale.setScalar(1.25);
    for (const m of [this.inner, this.outer]) { m.rotation.x = -Math.PI / 2; this.group.add(m); }
    this.opacity = 0;      // valor atual
    this.target = 0;       // valor desejado (a timeline define)
    this.spin = 0.4;
    this.scale = 1;
    this.flare = 0;
  }

  show(opacity = 1) { this.target = opacity; }
  hide() { this.target = 0; }
  pulse(a = 1) { this.flare = Math.max(this.flare, a); }

  reset() { this.opacity = this.target = this.flare = 0; this.scale = 1; this.group.position.set(0, 0.03, 0); }

  update(dt, time) {
    this.opacity += (this.target - this.opacity) * Math.min(1, dt * 3);
    this.flare = Math.max(0, this.flare - dt * 1.5);
    const o = this.opacity + this.flare * 0.5;
    this.inner.rotation.z += dt * this.spin;
    this.outer.rotation.z -= dt * this.spin * 0.6;
    const s = this.scale * (0.6 + 0.4 * Math.min(1, this.opacity * 1.3)) * (1 + this.flare * 0.15);
    this.group.scale.setScalar(s);
    for (const m of [this.inner, this.outer]) {
      m.material.uniforms.uOpacity.value = o;
      m.material.uniforms.uTime.value = time;
    }
    this.group.visible = o > 0.003;
  }
}

/** Coluna de luz vertical (levitação). */
export class LightPillar {
  constructor(scene) {
    const geo = new THREE.CylinderGeometry(1.1, 1.5, 30, 48, 1, true);
    geo.translate(0, 15, 0);
    this.mesh = new THREE.Mesh(geo, new THREE.ShaderMaterial({
      uniforms: { uTime: { value: 0 }, uOpacity: { value: 0 }, uColor: { value: new THREE.Color(CONFIG.magic.gold) } },
      vertexShader: /* glsl */`
        varying vec2 vUv; varying vec3 vN; varying vec3 vV;
        void main(){
          vUv = uv;
          vec4 mv = modelViewMatrix * vec4(position,1.0);
          vN = normalize(normalMatrix * normal); vV = normalize(-mv.xyz);
          gl_Position = projectionMatrix * mv;
        }`,
      fragmentShader: /* glsl */`
        uniform float uTime; uniform float uOpacity; uniform vec3 uColor;
        varying vec2 vUv; varying vec3 vN; varying vec3 vV;
        void main(){
          float edge = 1.0 - abs(dot(vN, vV));
          float streak = 0.5 + 0.5 * sin(vUv.x * 60.0 + uTime * 3.0) * sin(vUv.y * 8.0 - uTime * 6.0);
          float fadeY = smoothstep(0.0, 0.05, vUv.y) * (1.0 - smoothstep(0.2, 1.0, vUv.y));
          float a = (0.03 + pow(edge, 3.0) * 0.3) * (0.5 + 0.5 * streak) * fadeY * uOpacity;
          gl_FragColor = vec4(uColor * a, 1.0);
        }`,
      blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, side: THREE.DoubleSide,
    }));
    this.mesh.frustumCulled = false;
    scene.add(this.mesh);
    this.opacity = 0; this.target = 0;
  }
  reset() { this.opacity = this.target = 0; }
  update(dt, time) {
    this.opacity += (this.target - this.opacity) * Math.min(1, dt * 2);
    this.mesh.material.uniforms.uOpacity.value = this.opacity;
    this.mesh.material.uniforms.uTime.value = time;
    this.mesh.visible = this.opacity > 0.003;
  }
}

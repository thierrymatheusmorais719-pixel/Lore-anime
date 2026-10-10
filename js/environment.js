// Cenário: arena em ruínas sob um céu noturno, neblina e iluminação.
import * as THREE from 'three';
import { CONFIG } from './config.js';
import { rand } from './utils.js';

function makeGroundTexture() {
  const s = 512;
  const c = document.createElement('canvas');
  c.width = c.height = s;
  const g = c.getContext('2d');
  g.fillStyle = '#2a2433'; g.fillRect(0, 0, s, s);
  // ladrilhos irregulares
  const n = 8, cell = s / n;
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    const l = 26 + Math.random() * 18;
    g.fillStyle = `hsl(${260 + Math.random() * 20}, 12%, ${l}%)`;
    g.fillRect(x * cell + 3, y * cell + 3, cell - 6, cell - 6);
  }
  // rachaduras
  g.strokeStyle = 'rgba(10,6,16,0.8)';
  for (let i = 0; i < 40; i++) {
    g.lineWidth = Math.random() * 2 + 0.5;
    g.beginPath();
    let x = Math.random() * s, y = Math.random() * s;
    g.moveTo(x, y);
    for (let k = 0; k < 6; k++) { x += rand(-30, 30); y += rand(-30, 30); g.lineTo(x, y); }
    g.stroke();
  }
  // sujeira
  for (let i = 0; i < 3000; i++) {
    g.fillStyle = `rgba(0,0,0,${Math.random() * 0.15})`;
    g.fillRect(Math.random() * s, Math.random() * s, 2, 2);
  }
  const tex = new THREE.CanvasTexture(c);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(10, 10);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;
  return tex;
}

export class Environment {
  constructor(scene) {
    this.scene = scene;
    scene.fog = new THREE.FogExp2(0x120b22, 0.028);
    scene.background = new THREE.Color(0x06040c);

    // ---- Céu (esfera com shader: gradiente, estrelas, lua) ----------------
    const skyMat = new THREE.ShaderMaterial({
      side: THREE.BackSide,
      depthWrite: false,
      fog: false,
      uniforms: { uTime: { value: 0 }, uGlow: { value: 0 } },
      vertexShader: /* glsl */`
        varying vec3 vDir;
        void main(){
          vDir = normalize(position);
          vec4 p = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
          gl_Position = p.xyww;
        }`,
      fragmentShader: /* glsl */`
        varying vec3 vDir;
        uniform float uTime; uniform float uGlow;
        float hash(vec3 p){ return fract(sin(dot(p, vec3(12.9898,78.233,37.719))) * 43758.5453); }
        void main(){
          vec3 d = normalize(vDir);
          float h = d.y;
          vec3 top = vec3(0.02,0.01,0.06);
          vec3 mid = vec3(0.10,0.05,0.18);
          vec3 hor = vec3(0.28,0.12,0.22);
          vec3 col = mix(hor, mid, smoothstep(-0.05, 0.25, h));
          col = mix(col, top, smoothstep(0.25, 0.9, h));
          // estrelas
          vec3 cell = floor(d * 220.0);
          float s = hash(cell);
          float tw = 0.6 + 0.4 * sin(uTime * 2.0 + s * 50.0);
          col += vec3(1.0,0.95,0.85) * step(0.9975, s) * tw * smoothstep(0.05, 0.4, h) * 1.5;
          // lua
          vec3 moonDir = normalize(vec3(-0.45, 0.42, -0.78));
          float m = dot(d, moonDir);
          col += vec3(1.0,0.92,0.75) * smoothstep(0.9985, 0.9992, m) * 2.2;
          col += vec3(0.5,0.35,0.6) * pow(max(m,0.0), 60.0) * 0.6;
          // brilho dourado da magia no horizonte
          col += vec3(1.0,0.6,0.15) * uGlow * smoothstep(0.4, -0.05, h) * 0.25;
          gl_FragColor = vec4(col, 1.0);
        }`,
    });
    this.sky = new THREE.Mesh(new THREE.SphereGeometry(400, 32, 16), skyMat);
    this.sky.frustumCulled = false;
    scene.add(this.sky);

    // ---- Chão --------------------------------------------------------------
    const groundTex = makeGroundTexture();
    const ground = new THREE.Mesh(
      new THREE.CircleGeometry(120, 64),
      new THREE.MeshStandardMaterial({ map: groundTex, roughness: 0.92, metalness: 0.05, color: 0xb8b0c8 }),
    );
    ground.rotation.x = -Math.PI / 2;
    ground.receiveShadow = true;
    scene.add(ground);
    this.ground = ground;

    // plataforma central (estrado do rei)
    const daisMat = new THREE.MeshStandardMaterial({ color: 0x3a3248, roughness: 0.8 });
    const dais = new THREE.Mesh(new THREE.CylinderGeometry(3.2, 3.4, 0.08, 48), daisMat);
    dais.position.y = -0.035; dais.receiveShadow = true;
    scene.add(dais);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(3.25, 0.05, 8, 64), new THREE.MeshStandardMaterial({ color: 0x8a6a2a, roughness: 0.4, metalness: 0.7, emissive: 0x2a1800 }));
    ring.rotation.x = Math.PI / 2; ring.position.y = 0.01;
    scene.add(ring);

    // ---- Ruínas ------------------------------------------------------------
    const stone = new THREE.MeshStandardMaterial({ color: 0x4a4358, roughness: 0.95, flatShading: true });
    const stoneDark = new THREE.MeshStandardMaterial({ color: 0x2d2838, roughness: 1, flatShading: true });
    const count = 16;
    for (let i = 0; i < count; i++) {
      const a = (i / count) * Math.PI * 2 + rand(-0.08, 0.08);
      const r = rand(11, 14);
      const x = Math.sin(a) * r, z = Math.cos(a) * r;
      if (z > 0 && Math.abs(x) < 9) continue; // abertura frontal: feixe e câmera livres
      const h = Math.random() < 0.35 ? rand(5, 7.5) : rand(1.2, 4);
      const pillar = new THREE.Mesh(new THREE.CylinderGeometry(0.55, 0.65, h, 10), stone);
      pillar.position.set(x, h / 2, z);
      pillar.rotation.z = rand(-0.05, 0.05);
      pillar.castShadow = pillar.receiveShadow = true;
      scene.add(pillar);
      if (h > 5) {
        const cap = new THREE.Mesh(new THREE.BoxGeometry(1.7, 0.35, 1.7), stone);
        cap.position.set(x, h + 0.17, z);
        cap.rotation.y = a;
        scene.add(cap);
      }
      // destroços na base
      for (let k = 0; k < 3; k++) {
        const rock = new THREE.Mesh(new THREE.DodecahedronGeometry(rand(0.2, 0.55), 0), stoneDark);
        rock.position.set(x + rand(-1.5, 1.5), rand(0.05, 0.2), z + rand(-1.5, 1.5));
        rock.rotation.set(rand(0, 3), rand(0, 3), rand(0, 3));
        rock.castShadow = true;
        scene.add(rock);
      }
    }

    // formação rochosa distante (alvo do feixe)
    this.target = new THREE.Vector3(0, 1.6, 26);
    for (let i = 0; i < 9; i++) {
      const rk = new THREE.Mesh(new THREE.DodecahedronGeometry(rand(1.2, 2.6), 1), stoneDark);
      rk.position.set(rand(-4, 4), rand(0.4, 2.2), 26 + rand(-2, 3));
      rk.scale.y = rand(1, 2.2);
      rk.rotation.set(rand(0, 3), rand(0, 3), rand(0, 3));
      scene.add(rk);
    }
    // montanhas no horizonte
    for (let i = 0; i < 22; i++) {
      const a = (i / 22) * Math.PI * 2;
      const r = rand(60, 80);
      const m = new THREE.Mesh(new THREE.ConeGeometry(rand(10, 20), rand(12, 30), 5), stoneDark);
      m.position.set(Math.sin(a) * r, 0, Math.cos(a) * r);
      scene.add(m);
    }

    // ---- Luzes -------------------------------------------------------------
    this.hemi = new THREE.HemisphereLight(0x6a5aa8, 0x1a0f14, 0.55);
    scene.add(this.hemi);

    const moon = new THREE.DirectionalLight(0xa9b4ff, 1.15);
    moon.position.set(-8, 14, -10);
    moon.castShadow = CONFIG.quality.shadows;
    moon.shadow.mapSize.set(2048, 2048);
    moon.shadow.camera.left = -8; moon.shadow.camera.right = 8;
    moon.shadow.camera.top = 8; moon.shadow.camera.bottom = -8;
    moon.shadow.camera.near = 1; moon.shadow.camera.far = 40;
    moon.shadow.bias = -0.0005;
    moon.shadow.normalBias = 0.02;
    scene.add(moon);
    this.moon = moon;

    // contraluz (rim light) quente para destacar a silhueta
    const rim = new THREE.DirectionalLight(0xffb36a, 0.7);
    rim.position.set(6, 4, -8);
    scene.add(rim);
    this.rim = rim;

    // luz de preenchimento fria na frente
    const fill = new THREE.DirectionalLight(0x8090ff, 0.35);
    fill.position.set(2, 3, 8);
    scene.add(fill);

    this.glow = 0;
  }

  update(dt, time) {
    this.sky.material.uniforms.uTime.value = time;
    this.glow = Math.max(0, this.glow - dt * 0.6);
    this.sky.material.uniforms.uGlow.value = this.glow;
  }

  reset() { this.glow = 0; }
}

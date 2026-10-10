// ============================================================================
//  Biblioteca de poses de Lore
// ============================================================================
// Cada pose define rotações [x, y, z] (radianos) por articulação.
// Convenções (personagem olhando para +Z):
//   • braço/perna para FRENTE  → x negativo   (braço acima da cabeça ≈ x = -3)
//   • braço esquerdo para FORA → z positivo  | braço direito para fora → z negativo
//   • cotovelo dobrando        → x negativo   | joelho dobrando → x positivo
//   • tronco/cabeça inclinando para frente → x positivo
// `staff` é a orientação do cajado no espaço do personagem.
// `grip` é a posição da mão ao longo do cajado (0 = base, 1 = topo).
// Articulações omitidas herdam os valores de `BASE`.

export const BASE = {
  hips:      [0, 0, 0],
  spine:     [0, 0, 0],
  chest:     [0, 0, 0],
  neck:      [0, 0, 0],
  head:      [0, 0, 0],
  shoulderL: [0, 0, 0.12],
  elbowL:    [-0.2, 0, 0],
  wristL:    [0, 0, 0],
  shoulderR: [0, 0, -0.12],
  elbowR:    [-0.2, 0, 0],
  wristR:    [0, 0, 0],
  thighL:    [0, 0, 0.04],
  kneeL:     [0, 0, 0],
  ankleL:    [0, 0, 0],
  thighR:    [0, 0, -0.04],
  kneeR:     [0, 0, 0],
  ankleR:    [0, 0, 0],
  staff:     [0, 0, -0.06],
  grip:      [0.47, 0, 0],
};

export const POSES = {
  // Postura real, firme, cajado plantado ao lado
  idle: {
    chest:     [-0.05, 0.08, 0],
    head:      [0.04, -0.06, 0],
    shoulderL: [0.05, 0, 0.16],
    elbowL:    [-0.3, 0, 0],
    shoulderR: [-0.25, 0, -0.18],
    elbowR:    [-1.05, 0, 0],
    thighL:    [-0.05, 0, 0.08],
    thighR:    [0.06, 0, -0.1],
    kneeL:     [0.08, 0, 0],
    kneeR:     [0.05, 0, 0],
    staff:     [0.02, 0, -0.08],
  },

  // Cabeça erguida, olhar desafiador (close-up)
  awaken: {
    chest:     [-0.1, 0.12, 0],
    neck:      [-0.08, 0, 0],
    head:      [-0.12, -0.18, 0.04],
    shoulderL: [0.1, 0, 0.2],
    elbowL:    [-0.4, 0, 0],
    shoulderR: [-0.25, 0, -0.18],
    elbowR:    [-1.05, 0, 0],
    thighL:    [-0.05, 0, 0.08],
    thighR:    [0.06, 0, -0.1],
    staff:     [0.02, 0, -0.08],
  },

  // Agacha e concentra energia: mão esquerda junto ao orbe
  charge: {
    spine:     [0.12, 0.25, 0],
    chest:     [0.05, 0.2, 0],
    head:      [0.1, -0.35, 0],
    shoulderL: [-1.35, 0.3, 0.1],
    elbowL:    [-1.25, 0, 0],
    wristL:    [0, 0, -0.4],
    shoulderR: [-0.95, -0.2, -0.25],
    elbowR:    [-0.9, 0, 0],
    thighL:    [-0.55, 0, 0.18],
    kneeL:     [0.85, 0, 0],
    ankleL:    [-0.3, 0, 0],
    thighR:    [0.25, 0, -0.18],
    kneeR:     [0.75, 0, 0],
    ankleR:    [-0.3, 0, 0],
    staff:     [0.12, 0, -0.18],
    grip:      [0.42, 0, 0],
  },

  // Cajado erguido para o céu, chamando os raios
  raise: {
    spine:     [-0.12, 0, 0],
    chest:     [-0.18, 0, 0],
    neck:      [-0.15, 0, 0],
    head:      [-0.35, 0, 0],
    shoulderL: [-0.2, 0, 1.15],
    elbowL:    [-0.35, 0, 0],
    wristL:    [0, 0, 0.4],
    shoulderR: [-2.95, 0, 0.12],
    elbowR:    [-0.15, 0, 0],
    thighL:    [-0.1, 0, 0.22],
    kneeL:     [0.1, 0, 0],
    thighR:    [0.1, 0, -0.22],
    kneeR:     [0.1, 0, 0],
    staff:     [0.0, 0, 0.0],
    grip:      [0.35, 0, 0],
  },

  // Preparação do golpe: inclina para trás, cajado sobre a cabeça
  windup: {
    spine:     [-0.25, -0.1, 0],
    chest:     [-0.25, -0.1, 0],
    neck:      [0.05, 0, 0],
    head:      [0.05, 0.1, 0],
    shoulderL: [-2.7, 0, 0.35],
    elbowL:    [-0.6, 0, 0],
    shoulderR: [-2.85, 0, -0.1],
    elbowR:    [-0.5, 0, 0],
    thighL:    [-0.45, 0, 0.12],
    kneeL:     [0.35, 0, 0],
    thighR:    [0.25, 0, -0.12],
    kneeR:     [0.3, 0, 0],
    staff:     [-0.55, 0, 0],
    grip:      [0.3, 0, 0],
  },

  // Golpe: crava o cajado no chão em avanço profundo
  slam: {
    spine:     [0.45, 0, 0],
    chest:     [0.3, 0, 0],
    neck:      [-0.2, 0, 0],
    head:      [-0.25, 0, 0],
    shoulderL: [-1.0, 0, 0.25],
    elbowL:    [-0.3, 0, 0],
    shoulderR: [-1.15, 0, -0.05],
    elbowR:    [-0.25, 0, 0],
    thighL:    [-1.05, 0, 0.12],
    kneeL:     [1.5, 0, 0],
    ankleL:    [-0.4, 0, 0],
    thighR:    [0.55, 0, -0.12],
    kneeR:     [0.7, 0, 0],
    ankleR:    [0.2, 0, 0],
    staff:     [0.35, 0, 0],
    grip:      [0.55, 0, 0],
  },

  // Levitação: braços abertos, pernas soltas, energia ao redor
  levitate: {
    spine:     [-0.08, 0, 0],
    chest:     [-0.12, 0, 0],
    neck:      [-0.05, 0, 0],
    head:      [-0.1, 0, 0],
    shoulderL: [-0.25, 0, 1.25],
    elbowL:    [-0.3, 0.3, 0],
    wristL:    [0, 0, 0.3],
    shoulderR: [-0.35, 0, -1.05],
    elbowR:    [-0.45, 0, 0],
    thighL:    [-0.45, 0, 0.06],
    kneeL:     [0.95, 0, 0],
    ankleL:    [0.55, 0, 0],
    thighR:    [-0.08, 0, -0.06],
    kneeR:     [0.35, 0, 0],
    ankleR:    [0.5, 0, 0],
    staff:     [0.1, 0, -0.5],
    grip:      [0.5, 0, 0],
  },

  // Antecipação do feixe: mão esquerda recua
  castPrep: {
    spine:     [0, 0.4, 0],
    chest:     [-0.05, 0.35, 0],
    head:      [0, -0.6, 0],
    shoulderL: [-0.4, 0, 0.6],
    elbowL:    [-1.6, 0, 0],
    shoulderR: [-0.2, 0, -0.9],
    elbowR:    [-0.5, 0, 0],
    thighL:    [-0.4, 0, 0.06],
    kneeL:     [0.8, 0, 0],
    ankleL:    [0.5, 0, 0],
    thighR:    [-0.1, 0, -0.06],
    kneeR:     [0.4, 0, 0],
    ankleR:    [0.5, 0, 0],
    staff:     [0.15, 0, -0.6],
  },

  // Dispara o feixe com a mão esquerda estendida
  cast: {
    spine:     [0.05, -0.3, 0],
    chest:     [0.05, -0.35, 0],
    neck:      [0, 0.2, 0],
    head:      [0.05, 0.42, 0],
    shoulderL: [-1.55, 0.25, 0.0],
    elbowL:    [-0.05, 0, 0],
    wristL:    [-0.9, 0, 0],
    shoulderR: [0.35, 0, -0.75],
    elbowR:    [-0.35, 0, 0],
    thighL:    [-0.55, 0, 0.06],
    kneeL:     [0.6, 0, 0],
    ankleL:    [0.4, 0, 0],
    thighR:    [0.15, 0, -0.06],
    kneeR:     [0.5, 0, 0],
    ankleR:    [0.5, 0, 0],
    staff:     [0.2, 0, -0.7],
  },

  // Pose final: cajado plantado, olhar ao horizonte
  final: {
    chest:     [-0.08, -0.12, 0],
    neck:      [-0.05, 0.1, 0],
    head:      [-0.1, 0.25, 0],
    shoulderL: [0.15, 0, 0.18],
    elbowL:    [-0.15, 0, 0],
    shoulderR: [-0.1, 0, -0.38],
    elbowR:    [-0.75, 0, 0],
    thighL:    [-0.12, 0, 0.12],
    kneeL:     [0.1, 0, 0],
    thighR:    [0.1, 0, -0.12],
    kneeR:     [0.05, 0, 0],
    staff:     [0.0, 0, -0.2],
  },
};

/** Cria uma cópia completa de uma pose (com BASE preenchendo lacunas). */
export function resolvePose(name) {
  const src = typeof name === 'string' ? POSES[name] : name;
  if (!src) throw new Error(`Pose desconhecida: ${name}`);
  const out = {};
  for (const k in BASE) out[k] = (src[k] || BASE[k]).slice();
  return out;
}

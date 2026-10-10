// ============================================================================
//  CONFIGURAÇÃO CENTRAL — altere aqui para aprimorar Lore e a cutscene
// ============================================================================
// Todas as cores estão em hexadecimal. Os valores de tempo estão em segundos.

export const CONFIG = {
  // --------------------------------------------------------------------------
  // Aparência de Lore, o Rei Mago
  // --------------------------------------------------------------------------
  character: {
    height: 1.85,            // altura aproximada em unidades de mundo (≈ metros)
    skin: 0xf2d0b4,
    hair: 0xe4e0f4,          // cabelo prateado/branco
    hairShadow: 0xb9b3e6,
    eyes: 0xffd54a,          // olhos dourados (brilham durante a magia)
    robe: 0x1d1640,          // manto real azul-noite
    robeInner: 0x2d2363,
    trim: 0xffc93c,          // detalhes dourados
    cape: 0x5a0f1f,          // capa carmesim
    capeInner: 0x1a0610,
    armor: 0xd9b45a,         // ombreiras / peitoral
    boots: 0x241a2e,
    crown: 0xffcf40,
    crownGem: 0xff3b6b,
    staffWood: 0x3b2418,
    staffMetal: 0xe8c25a,
    staffOrb: 0xfff1a8,
    outline: 0x07040f,       // contorno estilo anime
    outlineWidth: 0.012,
  },

  // --------------------------------------------------------------------------
  // Paleta da magia
  // --------------------------------------------------------------------------
  magic: {
    core: 0xfffbe6,
    gold: 0xffc93c,
    amber: 0xff9a1f,
    deep: 0xff5a00,
    lightning: 0xfff3b0,
  },

  // --------------------------------------------------------------------------
  // Pós-processamento
  // --------------------------------------------------------------------------
  post: {
    bloomStrength: 0.85,
    bloomRadius: 0.45,
    bloomThreshold: 0.92,
    vignette: 0.9,
    exposure: 0.95,
  },

  // --------------------------------------------------------------------------
  // Cutscene
  // --------------------------------------------------------------------------
  cutscene: {
    duration: 34,            // duração total (s); repete em loop
    loop: true,
    showSubtitles: true,
  },

  // Qualidade: reduza se o computador for mais modesto
  quality: {
    maxParticles: 9000,
    maxSmoke: 900,
    pixelRatioCap: 2,
    shadows: true,
  },
};

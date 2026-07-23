/*
 * Entity definitions: fighters and the actions they can take.
 * Everything is data-driven so later steps can add enemies, weapons,
 * and abilities without touching the combat engine.
 */

const Actions = {
  strike: {
    id: 'strike',
    name: 'Axe Strike',
    hint: 'A solid blow. Reliable.',
    staminaCost: 2,
    damage: [8, 14],
    hitChance: 0.9,
    stun: 0,
  },
  heavyBlow: {
    id: 'heavyBlow',
    name: 'Skull-Splitter',
    hint: 'Slow and brutal. May miss.',
    staminaCost: 4,
    damage: [16, 26],
    hitChance: 0.65,
    stun: 0,
  },
  shieldBash: {
    id: 'shieldBash',
    name: 'Shield Bash',
    hint: 'Light damage, may stun a turn.',
    staminaCost: 3,
    damage: [3, 6],
    hitChance: 0.85,
    stun: 0.5,
  },
  guard: {
    id: 'guard',
    name: 'Raise Shield',
    hint: 'Halve next hit, recover stamina.',
    staminaCost: 0,
    damage: null,       // no attack
    guard: true,
    staminaRecover: 3,
  },
};

function makeFighter(def) {
  return {
    name: def.name,
    epithet: def.epithet || '',
    maxHp: def.maxHp,
    hp: def.maxHp,
    maxStamina: def.maxStamina,
    stamina: def.maxStamina,
    actions: def.actions,
    palette: def.palette,   // colors used by the renderer
    guarding: false,
    stunned: false,
    facing: def.facing,     // 1 = faces right, -1 = faces left
    x: def.x,
    ai: def.ai || null,
  };
}

function createPlayer() {
  return makeFighter({
    name: 'Ragnvald',
    epithet: 'Half-Axe',
    maxHp: 60,
    maxStamina: 10,
    actions: [Actions.strike, Actions.heavyBlow, Actions.shieldBash, Actions.guard],
    palette: { tunic: '#4a5d3a', trim: '#c9a227', shield: '#8a1f1f', hair: '#c98d3f' },
    facing: 1,
    x: 300,
  });
}

function createSaxonCeorl() {
  return makeFighter({
    name: 'Aelfric',
    epithet: 'of Eoforwic',
    maxHp: 45,
    maxStamina: 8,
    actions: [Actions.strike, Actions.shieldBash, Actions.guard],
    palette: { tunic: '#5a4632', trim: '#b0a58f', shield: '#3f5a73', hair: '#6b4f2a' },
    facing: -1,
    x: 660,
    ai: saxonAI,
  });
}

/*
 * Simple enemy brain: mostly attacks, guards when hurt and tired.
 * Receives (self, opponent), returns an action from self.actions.
 */
function saxonAI(self, opponent) {
  const affordable = self.actions.filter(
    a => a.staminaCost <= self.stamina && !a.guard
  );

  // Tired or badly hurt with low stamina: raise the shield.
  const guard = self.actions.find(a => a.guard);
  if (affordable.length === 0) return guard;
  if (self.hp < self.maxHp * 0.35 && self.stamina < 4 && Math.random() < 0.6) {
    return guard;
  }

  return affordable[Math.floor(Math.random() * affordable.length)];
}

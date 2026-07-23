/*
 * Turn-based combat engine.
 * A battle is: player picks an action -> it resolves -> enemy acts -> repeat.
 * The engine mutates fighters and emits log lines; it knows nothing about
 * rendering or the DOM beyond the log callback handed to it.
 */

const STAMINA_REGEN_PER_TURN = 1;

class Battle {
  constructor(player, enemy, onLog) {
    this.player = player;
    this.enemy = enemy;
    this.onLog = onLog;
    this.over = false;
    this.winner = null;
  }

  log(text, cls) {
    this.onLog(text, cls);
  }

  /* Run one full round: the player's chosen action, then the enemy's reply. */
  playerTurn(action) {
    if (this.over) return;

    this.resolveAction(this.player, this.enemy, action, 'log-player');
    if (this.checkEnd()) return;

    this.enemyTurn();
    if (this.checkEnd()) return;

    this.endRound();
  }

  enemyTurn() {
    const e = this.enemy;
    if (e.stunned) {
      this.log(`${e.name} reels from the blow and loses his turn!`, 'log-system');
      e.stunned = false;
      return;
    }
    const action = e.ai(e, this.player);
    this.resolveAction(e, this.player, action, 'log-enemy');
  }

  resolveAction(attacker, defender, action, cls) {
    attacker.guarding = false;

    if (action.guard) {
      attacker.guarding = true;
      attacker.stamina = Math.min(
        attacker.maxStamina, attacker.stamina + action.staminaRecover
      );
      this.log(`${attacker.name} plants his feet behind his shield.`, cls);
      return;
    }

    attacker.stamina -= action.staminaCost;

    if (Math.random() > action.hitChance) {
      this.log(`${attacker.name}'s ${action.name} whistles through empty air!`, cls);
      return;
    }

    let dmg = randInt(action.damage[0], action.damage[1]);
    let suffix = '';
    if (defender.guarding) {
      dmg = Math.ceil(dmg / 2);
      suffix = ' — the shield takes half the force';
    }
    defender.hp = Math.max(0, defender.hp - dmg);
    this.log(
      `${attacker.name} lands ${action.name} for ${dmg} damage${suffix}.`, cls
    );

    if (action.stun && !defender.guarding && Math.random() < action.stun) {
      defender.stunned = true;
      this.log(`${defender.name} is staggered!`, 'log-system');
    }
  }

  endRound() {
    for (const f of [this.player, this.enemy]) {
      f.stamina = Math.min(f.maxStamina, f.stamina + STAMINA_REGEN_PER_TURN);
    }
  }

  checkEnd() {
    if (this.enemy.hp <= 0) {
      this.over = true;
      this.winner = this.player;
      this.log(`${this.enemy.name} falls. The way is clear.`, 'log-system');
    } else if (this.player.hp <= 0) {
      this.over = true;
      this.winner = this.enemy;
      this.log(`${this.player.name} falls to the mud of Northumbria...`, 'log-system');
    }
    return this.over;
  }
}

function randInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

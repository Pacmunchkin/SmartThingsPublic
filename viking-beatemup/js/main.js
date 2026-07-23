/*
 * Game shell: state machine (TITLE -> BATTLE -> VICTORY/DEFEAT),
 * wiring between the DOM action bar and the combat engine, and the
 * canvas redraw loop.
 */

const canvas = document.getElementById('game-canvas');
const ctx = canvas.getContext('2d');

const ui = {
  title: document.getElementById('title-screen'),
  end: document.getElementById('end-screen'),
  endTitle: document.getElementById('end-title'),
  endText: document.getElementById('end-text'),
  battle: document.getElementById('battle-ui'),
  actionBar: document.getElementById('action-bar'),
  log: document.getElementById('combat-log'),
};

let battle = null;

function logLine(text, cls) {
  const div = document.createElement('div');
  div.className = cls || '';
  div.textContent = text;
  ui.log.appendChild(div);
  ui.log.scrollTop = ui.log.scrollHeight;
}

function startBattle() {
  const player = createPlayer();
  const enemy = createSaxonCeorl();
  battle = new Battle(player, enemy, logLine);

  ui.title.classList.add('hidden');
  ui.end.classList.add('hidden');
  ui.battle.classList.remove('hidden');
  ui.log.innerHTML = '';

  logLine(
    `${enemy.name} ${enemy.epithet} blocks the road, spear-wall raised. Choose your blow.`,
    'log-system'
  );
  refresh();
}

function refresh() {
  drawScene(ctx, battle.player, battle.enemy);
  buildActionBar();

  if (battle.over) {
    ui.actionBar.querySelectorAll('button').forEach(b => (b.disabled = true));
    setTimeout(showEndScreen, 1200);
  }
}

function buildActionBar() {
  ui.actionBar.innerHTML = '';
  for (const action of battle.player.actions) {
    const btn = document.createElement('button');
    btn.className = 'action-button';

    const cost = action.staminaCost > 0 ? `${action.staminaCost} stamina` : 'free';
    btn.innerHTML =
      `${action.name} <span class="cost">${cost}</span>` +
      `<span class="hint">${action.hint}</span>`;

    btn.disabled = battle.over || action.staminaCost > battle.player.stamina;
    btn.addEventListener('click', () => {
      battle.playerTurn(action);
      refresh();
    });
    ui.actionBar.appendChild(btn);
  }
}

function showEndScreen() {
  ui.battle.classList.add('hidden');
  ui.end.classList.remove('hidden');
  if (battle.winner === battle.player) {
    ui.endTitle.textContent = 'VICTORY';
    ui.endText.textContent =
      'The skalds will sing of this. But Eoforwic still lies ahead...';
  } else {
    ui.endTitle.textContent = 'SLAIN';
    ui.endText.textContent =
      'The ravens gather. Odin calls you to try again.';
  }
}

document.getElementById('btn-start').addEventListener('click', startBattle);
document.getElementById('btn-again').addEventListener('click', startBattle);

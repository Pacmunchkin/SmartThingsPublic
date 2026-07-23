# Blood on the Whale-Road

A turn-based beat 'em up set in 9th century Viking Britain. You are Ragnvald
Half-Axe, a warrior of the Great Heathen Army, fighting your way through
Northumbria in 866 AD.

Plain HTML5/JavaScript — no build step, no dependencies. Open
`index.html` in any browser to play.

## How to play

Combat is turn-based: pick an action, watch it resolve, then your opponent
answers. Manage **stamina** — heavy blows hit hard but drain you, and raising
your shield recovers stamina while halving the next hit you take.

| Action | Cost | Effect |
| --- | --- | --- |
| Axe Strike | 2 | Reliable damage |
| Skull-Splitter | 4 | Heavy damage, may miss |
| Shield Bash | 3 | Light damage, may stun the enemy for a turn |
| Raise Shield | free | Halve the next hit, recover 3 stamina |

## Project layout

- `index.html` — page shell, overlays, and UI containers
- `css/style.css` — all styling
- `js/entities.js` — fighter and action definitions (data-driven), enemy AI
- `js/combat.js` — the turn engine; no DOM or rendering knowledge
- `js/render.js` — canvas drawing (scene, fighters, status bars)
- `js/main.js` — state machine and UI wiring

## Roadmap

- [x] **Step 1** — scaffold, turn engine, one duel (Viking vs. Saxon ceorl)
- [ ] **Step 2** — multiple enemies per battle and a wave/stage structure
      (the beat 'em up part: fight through a warband, not just one man)
- [ ] **Step 3** — a campaign map: raid from the coast to Eoforwic (York)
      through a series of stages with rests between
- [ ] **Step 4** — progression: loot, weapon upgrades, new abilities
      (berserk rage, throwing axes, feints)
- [ ] **Step 5** — richer enemies: thegns, huscarls, mounted men, shield-walls
      with formation mechanics
- [ ] **Step 6** — art & sound pass: sprite animation, hit effects, music

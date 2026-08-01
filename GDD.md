# Game Design Document — *Warlord* (working title)

**Version:** 0.2 (vertical-slice code complete; pre-playtest)
**Engine:** Godot 4.7, 2D top-down
**Status legend:** ✅ Implemented · 🔶 Decided, not built · 🕓 Planned / later

---

## 1. High Concept

A 9th-century Viking conquest game where you **lead your warband from the
front**. You directly control a single warlord with the left stick; an
autonomous retinue fights attached to you; and you make macro decisions
about which villages, fortifications, and cities to take. Part *Bad North*,
part *Overlord*, in the setting of the Great Heathen Army's invasion of
Anglo-Saxon England.

**Genre:** Real-time tactics with a commander-avatar hook. Single-player,
**campaign** (not a roguelite, despite roguelite-adjacent systems).

**Elevator pitch:** *You are a Viking warlord. Sail in, gather a warband
from the villages you conquer, and carve through burhs and cities to break
the kingdom — but every warlord who falls is gone for the raid, and a total
wipe sends you back to the start of the level.*

---

## 2. Design Pillars

1. **Lead from the front.** You *are* a unit on the field, not a god-cursor.
2. **The warband is your power.** Strength comes from the retinue you gather
   and the hacksilver you plunder to arm and level them — not base-building.
3. **Deliberate, weighty conquest.** Slow buildup to big battles; movement
   should be engaging in itself ("Skyrim-level" traversal feel). 🕓
4. **Meaningful permadeath, humane recovery.** Losing a warlord hurts (and
   spurs the survivors' revenge boon); a total wipe just restarts the level
   (§9), never the campaign.
5. **Historically grounded.** Mechanics map to real 9th-century warfare.
6. **Gamepad-first.** Designed for a controller from day one.

---

## 3. Setting & Historical Grounding

Based on the **Great Heathen Army** campaigns in England, c. 865–896 — a
coalition of warlords (Ivar, Halfdan, Ubba, Guthrum) operating jointly.
Nearly every core system has a primary-source anchor:

| Game element | Historical basis |
|---|---|
| Multiple allied warlords | The Great Heathen Army was a coalition of chieftains |
| Burhs at choke points | Alfred's fortified towns (Burghal Hidage garrison quotas) |
| Spears as baseline troop | The spear was the most common Viking weapon |
| Shield & Sword as elite | Swords were prestige weapons of the sworn *hird* |
| Feigned Retreat ability | The feigned retreat, a documented Viking deception |
| Knockback / Push Back | *Svinfylking* (boar's-snout wedge) splitting a shield wall |
| Steadfast ability | The *skjaldborg* (shield wall) |
| Rally Cry / Raise the Standard | Chieftains under the raven banner (*merki*); morale tied to the banner and the man |
| Brace (spears) | The braced spear-hedge receiving a charge |
| Muster (villages) | The war-arrow (*herör*) summons; Alfred's fyrd rotation |
| Hacksilver economy | Silver hoards & hack-silver bullion funding the host |

---

## 4. Core Gameplay Loop

1. **War Council** — before the level, choose each warlord's unit type and
   starting ability. ✅
2. **Land & lead** — control the selected warlord; the retinue follows. ✅
3. **Gather** — conquer villages; they produce recruits that muster into
   your retinue. ✅
4. **Fight** — engage enemy garrisons and warbands in Bad North-style
   pairing combat. ✅
5. **Grow** — plunder **hacksilver**; heal at churches; upgrade warlords,
   cooldowns & gear between levels (§6.5). ✅
6. **Break** — assault burhs (choke points) and the city (gate +
   battlements). ✅
7. **Win** — defeat the last enemy warlord. ✅

---

## 5. Controls (Gamepad)

| Input | Action |
|---|---|
| Left stick | Move the selected warlord ✅ |
| A / B / X / Y | Select warlord A / B / X / Y; camera snaps ✅ |
| Hold X + D-pad Up/Left/Right | Fire the selected warlord's ability in that slot ✅ |
| (X selects on *release*, so hold-X for abilities doesn't switch warlord) | ✅ |

Menus (War Council, church picks) use built-in `ui_*` actions (d-pad /
stick / keyboard). Movement is bound to `move_*` (left stick); the d-pad is
reserved for abilities. ✅

---

## 6. Systems

### 6.1 Warlords ✅
- `CharacterBody2D`, extends a shared `Combatant` base.
- Directly player-controlled (selected) or AI-controlled, via a swappable
  `*Controller` child node (Player / AI).
- **Worth ~5 recruits in a fight:** tuned to beat 5 default recruits
  attacking together and die to 6 (65 HP, 5 dmg, 1 hit/s). Retune as unit
  stats settle.
- **Untargetable while the retinue lives** — enemies turn on the warlord
  only once its retinue is defeated (except while *Rally Cry* is active, which
  deliberately exposes the warlord — §6.4).
- **Permadeath:** a dead warlord is gone for the level (no mid-level respawn);
  survivors gain the revenge boon, and a total wipe restarts the level (§6.11).
- **Move speed = 0.9 × its unit type's speed** (a fixed **base ~140** when it
  has no unit type). Keeps the warlord just under its retinue's pace so it can
  never outrun its own band, and makes **mobility a unit-type trait** (Seax
  warbands skirmish, Axe warbands are slow juggernauts) — which drives the
  retreat game (§6.14b) with no extra flee-speed code.

### 6.2 Recruits & Retinue ✅
- One reusable `recruit.tscn` used everywhere (retinues, village/burh
  garrisons).
- **Bad North-style pairing combat:** each recruit tracks how many enemies
  target it (`engaged_count`); attackers prefer the *least-engaged* enemy,
  nearest as tiebreaker — fights naturally resolve into duels, doubling up
  only when outnumbered. Duels are committed until one side dies.
- Behavior priority: fight units → fight structures (non-sticky) → follow
  warlord → hold post.
- Retinue cap: **50** (`max_retinue`) overall; **per-unit-type caps** limit
  the mix (§15.4).
- **Combat behaviours (rebuild refinements):**
  - **Retaliation + rally:** a unit shot from beyond its aggro range charges
    the shooter *and* alerts everyone sharing its leader (same retinue /
    garrison), so the whole group turns on the archers together (Bad North
    "rush the bows"). Chase is **distance-capped** so groups don't cross the map.
  - **Hold-at-range (bows):** ranged units flagged `hold_at_range` stop at
    their range and trade fire instead of closing (bows-vs-bows don't brawl);
    they still swing weakly if an enemy reaches them.
  - **Targeting:** melee uses least-engaged pairing (duels); **ranged targets
    the *nearest* enemy** — so a tanky screen (Shield Wall, missile armour 5)
    draws battlement / archer fire and lets other units slip past.
  - Arrows carry their **shooter** (for retaliation) and a **max travel**
    distance (no map-crossing shots).
  - **Knockback on ranged hits:** arrows and spear-throws shove the target
    back a touch (`UnitType.ranged_knockback`), reduced by the target's
    `knockback_resist` — slows the melee rush on a bow line without ever
    perma-peeling it (heavies resist; see §15.7). Melee hits carry no
    knockback (only the Shield Bash / Push Back / Knockback abilities do).

### 6.3 Unit Types ✅ (resource-driven — `UnitType.tres`)

**Six types.** Each carries a **built-in "signature" ability** that auto-fills
the warlord's **Up** d-pad slot (Left/Right are player-picked universals —
§6.4). Full stats, the **armour model**, and **per-type retinue caps** live in
§15 (Combat Balance).

| Type | Role | Signature ability (Up) |
|---|---|---|
| Seax | Fast assault — shreds light troops, bounces off armour | **Flurry** (attack-speed burst) |
| Axe | Anti-armour shock — few heavy, piercing blows | **Shield Breach** (armour pierce) |
| Spear | Line infantry — first-strike, throws while closing | **Brace** (opening damage vs charge) |
| Sword & Shield | Durable anchor | **Shield Bash** (single-target stun) |
| Shield Wall | Fortress — anti-missile, holds chokes | **Push Back** (AoE shove + brief stun) |
| Bows | Long-range artillery — helpless if reached | **Volley** (fire-rate burst) |

A warlord's assigned unit type stamps its stats **and its signature Up
ability** onto the whole retinue.

### 6.4 Abilities ✅ (resource-driven — `Ability.tres`)
Three slots per warlord (Up/Left/Right), each an ability asset. Cooldown +
duration + magnitude + radius per ability.

**Built-in signatures** (auto-fill the **Up** slot per unit type):

| Signature | Unit | Effect | "When" |
|---|---|---|---|
| **Flurry** | Seax | +atk speed **then −atk speed (exhausted)** | commit-and-cost: blitz to finish; swing weak after |
| **Shield Breach** | Axe | ignores a share of enemy armour | vs armour; wasted on light |
| **Brace** | Spear | opening / anti-charge burst | reactive: right before impact |
| **Shield Bash** | Sword & Shield | stun one enemy, **interrupts their ability** | hold-to-punish |
| **Push Back** | Shield Wall | AoE shove + brief stun | break a charge, make space |
| **Volley** | Bows | +fire rate **then reload (can't fire)** | commit-and-cost: unload on massed targets |

**Cooldowns:** stored on the ability asset, counted down per-warlord
per-slot; HUD shows READY / countdown / ACTIVE.

#### 6.4a Ability model (rebuild direction)
The three slots resolved into a **fixed identity + free choice** split:
- **Up = the unit type's built-in signature ability** (§6.3) — auto-filled.
- **Left / Right = player-chosen *universal* cooldowns** — must be two
  *different* universals; any warlord may take the same ones as another.

**Universal cooldowns** (picked in the War Council):

| Universal | Effect | "When" | Status |
|---|---|---|---|
| Charge | **+move AND +attack speed** (usable anytime) | opportunity-cost: offense *or* escape | ✅ |
| Steadfast | +armour (½ dmg taken) − move speed | commit: hold ground, can't flee | ✅ |
| Rally Cry | retinue +dmg & +def, **warlord exposed** | risk: tip a knife-edge fight, risk the jarl | ✅ |
| Knockback | shove + stun one enemy | reactive: peel / interrupt | ✅ |
| Feigned Retreat | auto-retreat then counter | bait | 🕓 retreat AI |
| Scout | detach a scout, reveal fog | info | 🕓 fog of war |
| Raise the Standard | plant banner (can't move), morale | commit | 🕓 morale |

**Commit-and-cost philosophy.** The strongest cooldowns leave a *punishable
window* — the counterplay is built in: Flurry → **exhaustion**, Volley →
**reload**, Rally → **exposed warlord**, Charge → **spent (can't also escape)**.
Five "when" flavours across the roster — opportunity-cost (Charge), reactive
(Shield Bash / Knockback / Brace / Push Back), commit (Steadfast / Standard),
commit-and-cost (Flurry / Volley), risk/exposure (Rally). **Keep cost windows
short & recoverable** (a learnable mistake, not an army-wipe); the reactive
stuns + Steadfast stay the accessible low-risk picks.

**Primitives:** **stun** (frozen + *interrupts active buffs*; spinning-star
tell) and **knockback** (a decaying shove) — these unlock Shield Bash, Push
Back, and Knockback. Buff effects apply as multipliers to warlord + retinue;
instant effects (stun/knockback) fire once and don't linger.

**Who has cooldowns:** **only warlords** (enemy warlords included). Structures
— burhs, villages, battlements, city gates — never use abilities; they're
balanced by numbers/HP, giving the player low-stakes practice before the
warlord "boss" fights (which escalate: first warlord easy → last a real duel).

**Design intent — no "press to win," bait-and-punish (Overwatch-like).** Every
cooldown opens a **vulnerability window** (spent → on cooldown); the loop is
*bait the enemy's ability, then push during the downtime*. **Balance by
cooldown length (uptime), not magnitude** — a small persistent edge compounds
(Lanchester), so strong = long cooldown = long punish window.

**Counter-web** (a legible spine; the rest contextual):
- **Stun (Shield Bash / Knockback) → any active buff** — interrupts it (the
  hardest counter: *control beats commitment*).
- **Shield Breach (pierce) → Steadfast / armour.**
- **Steadfast (defence) → offensive bursts** (Flurry / Volley / Shield Breach).
- **Brace / Push Back → Charge** (the engage); **Charge → Volley** (closes on
  the archers).
- Loop: **Offence → Defence → Pierce → Control → Spacing → Offence.**
- Purely contextual (no hard counter): Rally Cry, Scout, Raise the Standard,
  Feigned Retreat.

**Enemy-AI intent** 🕓: enemy warlords **use** their cooldowns on **legible,
exploitable triggers** (predictable enough to *bait* — Souls-boss style, not
optimal). Late-game warlords should **hold their stun to interrupt the
player's buffs** rather than open with it — "the boss punishes your buttons."

### 6.5 Hacksilver & Progression 🕓 (replaces the renown system)
**Hacksilver is the single currency** — a shared treasury, not per-warlord XP.
- **Earned:** a lump on **level victory** (with a decaying first-clear bonus —
  §9), and from some **in-level NPC interactions**.
- **Spent between levels** (in the War Council / upgrade screen, §6.12) on:
  - **Level up a warlord** — HP and stats.
  - **Buy cooldowns** — unlock abilities for the Left/Right slots (§6.6).
  - **Buy armour & weapons** — the unit-stat upgrades (armour points, damage —
    plugs straight into §15).
  - **Upgrade fresh recruits/warlords** — **early levels cost less** to upgrade,
    so a replacement (after a permadeath, §6.11) **catches up quickly**; costs
    scale up later so power isn't free forever.
- **In-level:** silver may be **spent *or* earned** in NPC interactions (bribes,
  hire, buy passage/info, plunder) — see §6.14 + interaction tracking (§6.15).

Progression is now **player-directed spending** (craft your build) instead of
automatic XP tiers — more roguelike, and it deletes the renown book-keeping.

### 6.6 Ability Upgrade Trees 🔶 (Option B — component system)
- An ability becomes a **list of effect-components**, each with a type,
  magnitude, and `min_level`. Enables **branching upgrade trees** and unique
  warlord builds (e.g. Charge L2 gains knockback, L3 gains damage).
- **Silver economy:** **hacksilver (§6.5) buys** either **a new cooldown** (fill
  an empty L/R slot) **or a level in an existing one** — breadth vs depth. With
  **3 d-pad slots**, early silver buys **breadth** (three tools), then you're
  **out of slots → depth** (upgrade what you have). Each cooldown levels
  separately (players build differently); the shared ability asset holds the
  per-level component table.
- Supersedes the interim fixed-3-slots model in the current code.

### 6.7 Villages ✅
- Produce a recruit every 10s up to a 25 garrison cap.
- **Captured** when their garrison is wiped and an enemy warlord is in range
  → flips team.
- **Muster:** a same-team warlord in range absorbs the garrison into its
  retinue (also triggered at range by the Call ability).

### 6.8 Burhs (Fortifications) ✅
- Garrison of N recruits (exported) in a ring; a **barrier physically blocks
  a choke point** until the garrison is wiped, then opens permanently.
- **Not capturable** — just defeated. Placed at choke points in level design.

### 6.9 Settlements — Villages, Towns & Cities ✅ / 🕓
Settlements are **compositions of building blocks, not fixed sizes** — stack
obstacles (gate, burhs, battlements) on a core to make reaching it harder.
**Two capture triggers, both already built:**
- **Village / fortified town** (core = a producer): **taken when its garrison
  is cleared** (existing village capture). Wrap a village in a gate + burhs for
  a defended-but-lordless town — *no new code*.
- **City** (core = a **jarl**, i.e. an enemy warlord): **taken when the jarl
  dies.** The jarl is the city's heart, the assault's target, *and* a
  win-condition warlord — so a city falls on the same `died` event the level
  already tracks; no separate defender-counting. On the jarl's death the city
  **falls** (open barriers, silence towers, garrison routs) 🕓; v0.2 flips it to
  a friendly **super-village** (best producer on the map — the crown-jewel
  prize). Every city has a jarl.

**Fortress furniture** — obstacles on the way to the core, *none required to
win*:
- **Gate:** destructible structure (~500 HP), **meleeable by anyone**; blocks
  the opening, removed at 0 HP. Optional 🕓: gate **spawns defenders while it
  holds** (pressure clock).
- **Burhs:** a garrison behind a barrier that **opens when the garrison is
  cleared** (melee clears it). Not capturable — just defeated.
- **Battlements:** wall-top archers, **destroyable by *ranged* only**. **Never
  a required kill** — with jarl-capture you win by reaching the jarl, so
  battlements are **optional attrition**. Counters: bows silence them, **Shield
  Wall** (missile armour) tanks them, Steadfast buffs through, numbers absorb.
  *Level-design rule: keep them painful-but-survivable for a melee approach —
  never lethal enough to make bows mandatory.*
- Indestructible walls funnel the assault to the gate. **Villages don't get
  battlements** (city furniture only).

### 6.10 Churches ✅ / 🕓
- ✅ Heal the warlord + retinue in range.
- 🕓 Possible **in-level silver NPC** (a monk who sells a blessing/relic, or is
  plundered for hacksilver) — an interaction node (§6.14 / §6.15).
- (Checkpointing is **no longer church-based** — the *level itself* is the retry
  unit; see §9.)

### 6.11 Warlord Lifecycle 🕓 (replaces longship replacements)
- **Start each level** with the warlords set in the loadout.
- **In-level death is permadeath** — a fallen warlord is gone for that level;
  you fight on shorthanded. **No mid-level respawn.**
- **Revenge boon:** when a warlord falls, the **survivors gain a boon** to help
  finish the level, **escalating with each death** — the last warlord standing
  has the biggest boost. A comeback/rubber-band that keeps a bad run winnable
  and dramatic ("avenge them!"). Also softens the loss without a respawn.
- **Total wipe → restart the level** from its start state (§9) — the level is
  the retry unit.
- **Between levels:** empty roster slots are **filled with fresh recruits/
  warlords** for the next loadout — cheap to upgrade with silver early (§6.5),
  so a rebuilt roster catches up fast.

### 6.12 War Council (Loadout & Upgrade Menu) ✅ / 🕓
- Pauses at level start; walks each warlord through choosing a unit type +
  first ability, and shows the level objective (enemy-warlord count).
- 🕓 **Between levels it's also the upgrade/spend screen** — fill empty roster
  slots with fresh recruits and spend **hacksilver** (§6.5) on warlord levels,
  cooldowns, gear, and recruit upgrades before the next level starts.

### 6.13 UI ✅ (gray-box, pre-art)
- HUD: selected warlord name, HP, army size; **hacksilver treasury**; three
  ability slots (READY / countdown / ACTIVE / LOCKED).
- Health bars (warlords, recruits, gate); selection marker triangle.
- **Cooldown display:** the selected warlord's three abilities as **radial
  dials** (bottom-centre) that fill as they recover — arrow + name per slot.
- **Warlord roster (bottom-right):** every player warlord as `[button] · health
  ring · unit type`. The **ring sweeps down and green→red with HP**, so you see
  at a glance **which warband is in trouble and which button switches to it**
  (+ a HOLD marker when that warlord is holding). Face-button glyphs in the full
  GUI.

### 6.13b Squad Commands — Hold Stance 🕓 (v0.2)
A per-warlord stance toggle (**tap** a shoulder button; retreat is the *held*
one): **FOLLOW** (default) or **HOLD**. A held retinue **stands its ground** —
holds near the warlord, strikes only enemies within range, and **never advances
or charges** (suppresses the retaliation-charge). Ranged held units still fire
at in-range targets without repositioning.
- **Unlocks screening:** set Warlord A (Shield Wall) to Hold as a wall in front
  of the battlements → switch to Warlord B → maneuver B's band past behind the
  shields. One warband becomes a mobile fortification while another flanks.
- Command set: move (stick) · select (face) · abilities (d-pad) · **hold (tap
  shoulder)** · retreat (hold shoulder).

### 6.13c Feedback Channels 🕓 (three text spaces, by attention)
The more a message matters, the more it interrupts:

| Channel | Attention | Pauses? | Carries | Where |
|---|---|---|---|---|
| **Dialogue bar** | high — *read it* | **no (walk-and-talk)** | narrative / story | left column |
| **Toast** | medium — *notice it* | no | mechanical, explicit | top-centre |
| **Bark** | low — *nice if caught* | no | flavour, combat mood | over the unit |

- **Dialogue = walk-and-talk (non-pausing).** The player keeps control while
  warlords chat — perfect for slow level openings (march-and-talk). *Only* pause
  for a genuine **choice**; never full-screen (that kills the living moment),
  never mid-combat. Left column (narrow = fast to read); it can dim the rest.
- **Toasts** = un-caused, notable events (found buffs, **enemy** buffs for
  counterplay, objectives, economy, threats). **Flavour headline + explicit
  effect** ("Bjorn's band tastes blood / ⚔ +20% damage · 15s"). **Show the
  gain (+20%), never the multiplier (×1.2).** Colour: green buff / red nerf /
  gold objective. **Warband-level, rounded, meaningful** — never per-recruit,
  never imperceptible. Your *own* ability presses stay on the HUD, not toasts.
- **Barks** = recruit flavour + combat-swing lines ("They break!"), on a
  cooldown so they don't spam; **no mechanical claims** (that's the toast's job).
- **Screen map:** dialogue left · warlord readout top-left · toasts top-centre ·
  cooldown radials bottom-centre · warlord roster + health rings bottom-right ·
  barks over units. Corners used; centre stays clear.

### 6.14b Retreat 🕓 (targeted for v0.25 — emergent model)
**No button — retreat is just leaving.** Walking the warlord away *is* the
retreat; the cost and tension come from three rules, almost no new code.
- **Rearguard = whoever's left behind.** You retreat *from a losing fight*,
  where the enemy is doubling up and the whole retinue is engaged — so fleeing
  **abandons your men** (the price of fleeing). A manageable fight leaves a
  few free recruits trailing as escort. The split is emergent, not chosen.
- **Leaderless → 0 damage.** A retinue recruit whose warlord is beyond a
  **leash range** (~half a screen) deals **zero** damage — it dies at its
  normal rate, *pins* its enemies (they can't chase while it lives), and buys
  time it can't turn into a win. (Garrison recruits, led by a *structure*, keep
  fighting — structures don't flee.) This one damage-gate **is** the whole
  rearguard system, and it unifies with jarl-death routing. Rearguard size (=
  how many were engaged when you ran) sets the head start; you pay for it in
  dead men.
- **Chase:** enemies finish the rearguard, *then* pursue if the warlord's in
  range — governed by the **existing aggro/chase-cap** (tune duration live).
- **Flee speed is emergent** — the warlord moves at **0.9× its unit-type
  speed** (§6.1), so a slow Axe warband genuinely struggles to outrun fast
  pursuers while a Seax warband skirmishes away. **Charge** (its move-speed
  half) is the escape hatch — but a Charge you *spent winning* isn't there to
  flee with (commit-and-cost, §6.4).
- **Cost:** the **abandoned men + the tactical setback** (you rejoin a
  reinforced, alerted enemy). With renown gone, there's no separate score
  penalty — the dead rearguard *is* the price.
- **Economy fit:** you spend the *recoverable* clock (army) to survive the
  level, §8. **Self-limiting:** you lose the abandoned men and rejoin a
  now-reinforced, alerted enemy — never free.
- **v0.1** already has the "soft retreat" (walk off, the patrol AI drops
  aggro); this is the v0.25 formalisation. New code is tiny: the leaderless
  damage-gate and the warlord-speed derivation (§6.1).

### 6.14 Exploration & Discoverables 🕓
Interactable things placed in the world to make traversal rewarding (and to
counter the "traversal grind" risk). **Any reward can be permanent or
temporary** — the perm/temp choice is the main balancing lever (see note).

**Grounding — no magic (two channels).** Every buff has a *material* or
*psychological* cause, never a supernatural one. The gods do not alter steel
or flesh.
- **Material channel** — weapons → damage, armour/shields → defence, food &
  provisions → speed, rest/healer/herbs → healing, plunder → hacksilver
  arrivals, roads/fords/boats/rear-entrances → routes. **Survivability (HP,
  armour, healing) comes ONLY from this channel** — gear and recovery.
- **Morale channel** — omens, a raven, a skald's song, a heartening
  sacrifice, a recovered banner → a **temporary buff to attack + defence**
  (heartened men fight harder and hold the line), plus reputation (§6.15). **No separate
  "morale" variable** — "morale" is just the flavour label for a buff that
  applies the existing damage/defence multipliers. This is where Norse
  belief lives without magic: it moved men's courage (real), it did not
  thicken their mail.
Rule: **belief improves how hard men fight (attack/defence) and their
reputation; it never raises max HP or heals — health comes only from the
material channel (gear, food, rest).** Re-skinning a source is free — the
mechanics are identical whether the fiction is "a sacrifice before battle"
or "a cache of Frankish mail."

**Multiplier vs flat — a hard rule (from simulation, §15.1).** Combat buffs are
**multipliers** (×damage, ×attack-speed, ×defence): they preserve the armour
counter-web and can never invert a matchup. **Flat** bonuses are reserved for
**HP and armour points** (their natural unit). Crucially a **flat *damage***
bonus *breaks armour* — a +2 lets a 2-dmg Seax punch straight through 2 armour
it otherwise bounces off — so flat-damage / pierce is used **only** as a
deliberate, signposted **armour-breaker** reward ("whetted blades / bodkin
arrows"), never as a generic buff. So: **morale → multipliers; material → flat
HP/armour** (plus the rare armour-breaker).

**Reward taxonomy** — what a discovery can grant, what it serves, and how it
usually wants to be tuned:

| Reward | Serves | Tends to be | Material/morale source |
|---|---|---|---|
| Hacksilver | Silver economy | One-off, sized to the find | Plunder hoard, tribute, a buried cache |
| Damage boost | Combat | Temporary (or capped perm) | Forged/captured weapons, a smithy |
| Defence boost | Combat | Temporary (or capped perm) | Mail, shields, armour cache |
| Army speed boost | Traversal/combat | Temporary | Food stores, provisions, pack animals |
| Route reward | Strategic | Permanent (safe) | Ford, boat, **rear postern into a fort**, road, bridge |
| Healing | Recovery | Instant/one-time | Rest at camp, a healer/herbs, clean water |
| Recruits | Army clock | Permanent (self-limiting) | Deserters, escaped thralls, a champion |
| Sabotage | Strategic denial | One-time | Disable a beacon, burn a granary (cut enemy production), open a gate from inside |
| Useful information | Scouting | Permanent or timed reveal | Local guide, watchtower, captured scout |
| Speed a new warlord | Death economy | One-time | Silver hoard (plunder pays the crew) |
| Silver for a fresh warlord | Catch-up | One-time | A recovered hoard — arms a raw replacement fast |
| Morale (= attack + defence) | Combat | Temporary | Omen, raven, skald's song, a heartening sacrifice |
| Village production boost | Economy | Temporary or capped perm | Captured tools/livestock/seed, a mill |
| Lore & flavour | Worldbuilding | n/a | Runestones, ruins, captured monks, skalds |

**Permanent vs temporary — the balancing rule:**
- **Power** (damage/defence/production) → prefer **temporary** blessings or
  **capped** permanent upgrades. Uncapped permanent power is the snowball
  trap that breaks the 5-vs-6 tuning.
- **Knowledge & routes** (info, fords, rear entrances) → safe as
  **permanent** — it's map mastery, not raw power.
- **Recovery** (healing, recruits) → safe — self-limiting (spent, or die
  normally).
- **Catch-up finds** (speed/silver a newbie) → **one-time**, and they
  tie straight into the two-clocks recovery (§8): they soften a death
  without cheapening it.

**Flavour sources** (the fiction that carries the rewards): Norse *blót*
offering sites (choose a god → a themed blessing), silver hoards
(guard the best ones), wandering skalds/völvas/smiths/thralls, Roman roads
and river boats, sacred springs, runestones, enemy beacons to sabotage, a
raven (Odin's) that leads to a hidden hoard.

**Narrative encounters.** Discoverables are not just buff-dispensers — most
are small **story vignettes** with choices (a child robbed by a bandit —
help or walk on; an injured stag — mercy, spend a recruit to nurse it, or
ignore). **Not everything gives a buff**; most are worldbuilding or moral
texture, which keeps exploration from becoming a farmable checklist — the
lopsided ratio toward flavour is deliberate.

- **Auto-run makes "ignore" free.** Encounters trigger on entering the zone
  and are **unpaused** — walking on *is* the "no". Engaging means choosing to
  stop. No ignore button, no forced pause.
- **Interaction flow:** enter the proximity zone → a dialogue window opens at
  the **bottom of the screen**. Walk by with the **stick** (ignore) or engage
  with the **d-pad** (plain d-pad = choices; hold-X + d-pad is still
  abilities, so no clash — d-pad directions map to the options). When the
  encounter **leaves the screen** (walk far enough that it scrolls off, or
  switch warlords), the window closes and the encounter is **consumed — no
  respawn, gone for good**, whether or not you chose. You may linger beside it
  as long as you like (camera-locked, no timer); only *leaving* is final.
  Tech: `Area2D` (enter) + `VisibleOnScreenNotifier2D` `screen_exited`
  (consume) + a consumed flag.
- **Choices can cost, not just reward:** a fight (risk), spending a recruit,
  time — as well as hacksilver/buffs/nothing.
- **This IS the dialogue system.** An encounter (opening line → choices →
  per-choice outcome text + optional effect) is the same tech as Warcraft
  3-style warlord conversations (§11). Build once, serve both. The
  `Discoverable` resource grows from a flat buff into a small choice-tree.
- **Dependency:** immediate outcomes are easy; *delayed/persistent* ones
  (the nursed recruit rejoins later) need the **save/persistence system** —
  build immediate encounters first.
- **Authoring at volume:** past a couple dozen, move narrative into a
  text-based format / dialogue tool so writing doesn't touch scenes.

**Temporary buff lifespans.** Buffs expire in the *currency of the activity
they serve* — spend a buff in its own resource so it never feels wasted:
- **Encounters** (e.g. +damage for 3 fights) — combat buffs. An "encounter"
  ends after the army is **calm for 3 min** (tunable), so a chained raid
  counts as one — rewarding sustained aggression.
- **Distance** (e.g. speed for 100 tiles) — movement buffs.
- **Real-time** (e.g. 5 min) — continuous/economy buffs.
- **Permanent (capped)** — gear/relic finds.
Modelled as `expiry_type {TIME|DISTANCE|ENCOUNTERS|PERMANENT} + amount`.
Avoid **real-time on combat buffs** — in a slow game they expire during
travel, before the fight, and pressure the player to rush.

**Vision & fog = the camera.** No fog-of-war system: the locked camera *is*
the fog — you see only what's around the warlord, no shroud, no memory. A
**vision buff is a temporary camera zoom-out** (`Camera2D.zoom`). Cheap, and
it reinforces leading from the front (you don't know what's over the hill).

**Buff feedback = toasts, not a live HUD.** Passive buffs announce their
limit on gain and their end on expiry ("+Speed for 100 tiles" → "Speed wore
off") — no cluttered countdowns. Abilities keep their live cooldown HUD
(active management); discoverable buffs are fire-and-forget toasts.

**Future — momentum / resolve** 🕓: sustaining combat by linking enemy
groups into one long fight raises army resolve (= morale, attack+defence).
Pairs with the 3-min encounter window that enables the chaining.

**Connections:** the hoard/relic ideas also seed the future **gold/loot
economy**. Route rewards across the clocks (army / hacksilver / traversal)
so exploration serves different needs, and **guard the best rewards** so a
find is a decision, not a checkbox.

---

### 6.15 Interaction Tracking & Dialogue Trees 🕓
The game **remembers what the player did** — settlements razed vs spared, NPCs
bribed vs killed, whether they retreated, which warlord fell — and **dialogue
reflects it.** A lightweight flag/counter store (per-run and per-campaign) feeds
branching **dialogue trees** in the walk-and-talk bar (§6.13c), so warlords
reference recent deeds ("After Hafic burned, the villages bar their doors") and
NPCs react to reputation. Cheap to start (a dictionary of bools/counts +
condition-gated lines); it makes the world feel consequential and turns the
**hacksilver NPC interactions** (§6.5) into a memory, not one-offs.

---

## 7. Level Structure, Win & Faction Model

- **Faction = an integer `team`** on every combatant and structure (0 =
  player, 1 = enemy; higher numbers allow multiple factions). "Enemy" is
  simply *team ≠ player team*. ✅
- **Win condition:** no living warlord whose team differs from the player's.
  Populate a level with any number of enemy warlords. ✅
- **Defeat = total wipe → restart the level** from its start state (§6.11, §9);
  the level is the retry unit. Single warlord deaths are permanent *for the
  level*, and survivors gain an escalating **revenge boon** (§6.11).
- **Target level length ≈ 20 min.** One clean pass through the loop.
- ✅ **LevelManager** hooks each enemy warlord's death: toasts progress
  ("2 of 3 defeated") and shows a **victory/defeat panel** with stats (time,
  warlords lost, army remaining) on the last kill / total loss; replay on (A).

**Difficulty = two independent layers.**
- **Unit balance** (caps + counters + armour, §15) makes matchups *readable and
  counterable* — fixed design.
- **Encounter/level balance** is a **level-design lever, not a fairness
  target** — a 6-Seax band vs a 6-Axe burh is *meant* to lose head-on.
- **The contract that keeps that fair: encounters must be *readable* and
  *escapable*, not balanced.** The player reads a bad matchup *before*
  committing (weapon silhouettes + counters) and can always pull out (soft
  retreat via the AI's aggro-drop; formal retreat §6.14b), restock at a village,
  find narrative buffs (§6.14), or bring another warlord / the right counter and
  re-engage. **Persistence + tactics beats parity — grind does not** (a warlord
  death is permanent for the level; a wipe costs a restart, never the campaign).

**Nerf philosophy.** Loss aversion is real — a −15% *feels* worse than +20%
feels good. So: **no opaque persistent stat-debuffs on the player.** Make fights
harder by (a) **buffing the enemy**, (b) **contextual weakness** (armour,
leaderless→0 dmg, flanked), and (c) **scenario rules** (below). The *only*
imposed player debuff is a **rare, clearly-caused, recoverable "shaken"** state
(the dark twin of morale buffs — men spooked by a bad omen / a fallen jarl,
until rallied).

**Scenario modifiers (level rules).** The best "nerfs": narratively-explained
**rules that change the puzzle**, not the numbers — and they reuse existing
systems via flags. E.g. *cold winter* (village production off — survive on your
band), *lost at sea* (start with no retinue — take the first village bare), *the
food is held* (villages locked until you clear the bandit camp). Four rules:
**state it up front** (dialogue + toast), **one twist per level**, **hook a
system the player leans on** (economy/reinforcement/mobility), **give a readable
out or honest endurance.** This is §7's difficulty lever with names on it.

**Shuffled elements (per run).** Some world state **re-rolls each attempt** so
retries aren't rote: which city gate is fortified vs weak (run 1 east strong /
west weak → run 2 swapped), where an ambush sits (left approach vs centre), a
garrison's size or type. Keeps the 20-min level fresh across restarts and adds
roguelike texture. Implement as seeded flags read at level start.

**v0.1 slice scope:** 4 player warlords; loadout → fight → win by killing all
enemy warlords, in ~20 min. *In:* movement, retinues, combat + armour, abilities
(buffs + stun/knockback), villages/burhs/city-as-fortress, enemy **patrol AI**
(waypoint steering, no navmesh), loadout screen, win/lose + toasts. *Deferred
(documented, out of slice):* hacksilver progression, silver upgrade trees,
churches, revenge boon, restart-decay economy, formal retreat, hold stance,
fog/morale, city-capture economy, shuffled elements, real art. Enemy warlords in
v0.1 **don't use abilities** (leave their L/R empty).

---

## 8. Death Economy — Within a Level

The level is the unit of risk; losses recover at different speeds:

- **Army (recruits):** recovers **fast, in-level** — muster a fresh warband from
  captured villages.
- **A warlord:** **permanent for the level** (§6.11) — fight on shorthanded, but
  survivors gain the escalating **revenge boon**, so a loss is a *comeback hook*,
  not a death spiral.
- **Total wipe:** **restart the level** (§9) — never the campaign.
- **Between levels:** empty roster slots refill with fresh recruits and
  **hacksilver** (§6.5) rebuilds power (cheap early, so a rebuilt roster catches
  up).

Note: because a warlord is untargetable until its retinue is dead, the retinue
is almost always gone before the warlord falls — "inherit the orphaned retinue"
is a non-mechanic. Rare lingering retinues **fade on camera change**. 🔶

---

## 9. Campaign Recovery — The Level Is the Checkpoint 🕓

The level is the unit of retry, which makes recovery simple:
- **Total wipe → restart the level** from its start state. No campaign loss —
  re-attempt the same ~20-min level.
- **Restart-decay (anti-scum):** the **hacksilver reward for clearing a level
  starts with a bonus that shrinks with each restart**, flattening to a floor
  after ~3–4 tries. This stops the player **restarting the instant a warlord
  dies** to preserve the roster — pushing on with the revenge boon (§6.11)
  usually out-earns a fresh restart.
- **Progression banks between levels** — a cleared level is done; roster,
  cooldowns, gear, and silver carry forward. Requires a **save between levels**
  (no mid-level save).

This *replaces* the church-checkpoint contract: no in-level saves, no "push or
bank?" — just clean, replayable ~20-min levels with a decaying retry reward.

---

## 10. Technical Architecture ✅

- **Base class `Combatant`** (`CharacterBody2D`): team, health, `take_damage`,
  `died` signal, stun, structure flag, silver kill-credit. Extended by
  `Warlord` and `Recruit`.
- **Controller split:** `Warlord` finds a `*Controller` child by wildcard and
  asks it for a move direction each frame — same warlord scene serves player
  (`PlayerController`) and AI (`AIController`).
- **Data-driven content:** `UnitType` and `Ability` are `Resource` classes;
  gameplay content is authored as `.tres` assets, not code.
- **Pathfinding:** `NavigationAgent2D` on recruits + AI warlords (path when
  far, straight line up close). The **player warlord stays direct stick
  control**. Burh barriers / city gates use `NavigationObstacle2D` that clear
  on defeat. Works from a `NavigationRegion2D` or a `TileMapLayer`'s TileSet
  navigation (code is source-agnostic).
- **Performance:** target *searches* throttled to 4×/s, staggered per unit;
  fighting itself is never throttled.
- **Names:** drawn without replacement from `warlord_names.csv`.

### Key scripts
`combatant.gd` · `warlord.gd` · `warlord_commander.gd` · `warlord_controller
.gd` · `player_controller.gd` · `ai_controller.gd` · `recruit.gd` ·
`village.gd` · `burh.gd` · `city.gd` · `city_gate.gd` · `battlement.gd` ·
`arrow.gd` · `church.gd` · `unit_type.gd` · `ability.gd` · `war_council.gd` ·
`level_manager.gd` · `hud.gd` · `health_bar.gd` · `selection_marker.gd` ·
`name_pool.gd`. Assets: `abilities/*.tres` (8), `units/*.tres` (5),
`warlord_names.csv`. Build guide: `LEVEL_SETUP.md`.

---

## 11. Roadmap (post-playtest)

1. 🕓 **Playtest the vertical slice** — build one level per `LEVEL_SETUP.md`,
   tune (5-vs-6 breakpoint, cooldowns, production, march distances).
2. 🕓 **Art pass** — replace gray boxes with sprites.
3. 🕓 **Movement feel** — acceleration curves, retinue flow (pairs with art).
4. 🕓 **Dialogue system** — Warcraft 3-style, pre/post-level and on-meeting;
   leans on existing warlord names.
5. 🔶 **Ability upgrade trees** (Option B component system) + silver-funded,
   church-chosen upgrades.
6. 🔶 **Save / checkpoint system** — the campaign-recovery contract (§9).
7. 🕓 **Campaign layer** — stitch levels, persist warlords/hacksilver between them.
8. 🕓 Enemy warlord ability AI; results/continue screen; onboarding for the
   invisible rules.
9. 🕓 **Send-warlord-home command** (needs navigation + village muster): order
   a depleted warlord to autopilot to the nearest friendly village to reload,
   freeing the player to actively control another warlord in the meantime.
   Kills the "manually walk home to reload" tedium; serves the single-thumb,
   multiple-units pillar. The auto-walking warlord is still vulnerable en
   route (interceptable).

---

## 12. Design Risks (from comparable-game review research)

| Risk (seen in) | Status |
|---|---|
| Follower pathing jank (Pikmin, Bad North) | ✅ Addressed — navmesh pathfinding |
| Permadeath full-restart boredom (Bad North) | 🔶 Addressed — permadeath-per-level + revenge boon + restart-decay (§6.11/§9) |
| Rebuild grind after setback (Kingdom Two Crowns) | Mitigated by Call + village caps; watch in playtest |
| Traversal time (Kingdom Two Crowns) | Design goal is *engaging* slow travel; movement-feel pass 🕓 |
| Rule opacity (Thronefall, Kingdom) | 🕓 Progressive complexity (below) + radius indicators |
| Content variety (Bad North) | 5 unit types + 8 abilities; enemy loadout variety is editor work |
| Hold-X input overload | Watch in playtest; a shoulder-button modifier is the fallback |

---

## 12b. Progressive Complexity (Onboarding) 🕓

The game has many overlapping systems (buffs, cooldowns, unit types, unit
maneuvers, army caps, multiple warlords, permadeath, discoverables) — too
much to present at level 1. **The campaign IS the tutorial: introduce one
mechanic per level**, building slowly to the full-complexity late game.

Key point: complexity is controlled by **what each level is composed of, not
by gating code** — the modular, data-driven architecture already supports
this. A level with no ability `.tres` assigned simply has no abilities; a
one-warlord level *is* the single-warlord tutorial. Example ladder:

1. Move & fight (one warlord, one unit type, no abilities, no economy).
2. One ability.
3. Villages + mustering (grow the army).
4. A burh (choke points).
5. A second warlord + switching.
6. Hacksilver, churches, unit-type choice, permadeath stakes…

Only small "lock"/prompt polish is code; the teaching ladder itself is level
design. Keep every system **toggleable-by-omission** (they already are).

## 13. Reference Games

- **Pikmin 3** — multi-leader switching (closest to the 4-warlord control).
- **Pikmin 4** — movement feel & onboarding.
- **Bad North** — pairing combat, real-time tactics.
- **Overlord** — avatar commanding an attached swarm (closest mechanical cousin).
- **Kingdom: Two Crowns** — avatar-as-strategy, territory.
- **Shadow Tactics** — single-thumb coordination of multiple units.
- **Far Cry** — outpost/village assault fantasy.

*Study their control and follower feel; not their pacing — the deliberate,
slow buildup is a purposeful divergence.*

## 14. Art Direction & Sprite Pipeline 🕓 (decisions locked, art not yet built)

Gray-box now; this is the plan for when real sprites land. **Validated** on
real asset-pack sprites (spear grunt, sword-and-shield grunt, warlord) with a
Python/Pillow emulator that mirrors the Godot shader math — recolour,
shuffle-bag variety, enemy contrast, and two-warband readability all confirmed
in mock scenes.

### 14.1 Core technique — single-sprite palette swap (no layers)
Each unit is **one coloured sprite sheet** recoloured by a **palette-swap
shader** — *not* stacked greyscale layers (rejected: too much art per frame).
The shader recolours by **colour family**, so parts that differ in hue/sat
(tunic vs trousers vs skin) recolour **independently** with no layering.

- Per-region formula (preserves the sprite's own shading ramp):
  `out_rgb = clamp(target_rgb × (pixel_luma / region_base_luma))`.
- A pixel belongs to a region if its **hue + saturation** fall in that
  region's window. **Neutrals** (dark outlines, metal, white trim — low S or
  very low V) are left untouched.
- Set the target colours **once at spawn** (uniform writes) — no per-frame CPU.

**Region windows measured from the three test sprites** (thresholds for the
shader):
- **Spear grunt:** tunic = hue 330–360/0–10 & S>0.5 · skin = hue 10–45 & S
  0.2–0.7 & V>0.5.
- **Sword & shield:** livery (top + **helmet** + shield trim) = hue 335–360/0–8
  & S>0.5 · trousers = hue 200–240 & S>0.5 · skin = hue 8–28 & S 0.25–0.55 &
  V>0.6.
- **Warlord:** robe = hue 325–360/0–12 & S>0.6 · skin = hue 0–25 & S 0.28–0.55
  & V>0.55.

*Helmet note:* on the sword-and-shield sprite the helmet is the **same red** as
the tunic, so it recolours **with** the livery — desired (helmet + shield read
as warband colour). Only a problem if a **fixed metal** helmet is wanted; that
would be an **art** change (repaint it a distinct grey), not code.

### 14.2 Colour bags — variety without clustering
Randomise per unit at spawn by drawing from curated palettes via a **shuffle
bag** (deal without replacement; reshuffle when empty) — guarantees spread, so
you never get "three similar reds in a row" (Tetris-style bag). Independent
bags: **skin** (~10 tones, pale→dark), **livery/tunic**, **trousers** (dark
neutrals).

- **Skin is basically free** and doesn't signal team — randomise on every NPC.
- Curate palettes to be **visually distinct** (spread across hue). Optional
  hue-family bag if keeping several shades of one colour.

### 14.3 Team & warband colour scheme (readability)
Two independent signals: **hue-family = team**, **specific colour = warband**.
- **Players:** each warlord + his retinue **share one livery** (drawn from the
  livery bag) → warbands are colour-coded for one-thumb multi-retinue control.
  Recruits wear the **warlord's** colour (never the opposite). The **warlord**
  is elevated by **size** (68² vs recruit 48²) + HUD (HP bar, selection marker,
  ability shine) — **not** colour.
- **Enemies:** **uniform red** tunic + random skin (red never blends /
  universally reads hostile). The **enemy warlord** is recoloured **white or
  near-black** to pop from his red horde (colour **and** size).
- **Livery-bag rules:** **reserve red for enemies** (exclude from player bag);
  **exclude hues near common terrain** (no forest-green on grass — it goes
  muddy; blue/magenta/gold/teal/purple/orange all pop). Terrain-contrast is a
  hard rule, learned from a green-on-grass test.

### 14.4 Sprites needed
- **6 recruit sheets** — one per weapon (seax, axe, sword & shield, spear, bow,
  shield-wall). **The weapon silhouette *is* the unit-type readout** (replaces
  the interim emoji marker) — read army composition at a glance.
- **1 warlord sheet** — a single, more-armoured, larger "leader" look. No
  warlord-per-weapon; his type is read from retinue + HUD.

### 14.5 Animation
**AnimatedSprite2D + SpriteFrames** (not AnimationPlayer — that's only worth it
for a modular multi-layer rig). Named animations:
`idle_ / walk_ / fight_ × up/down/left/right` (12), **or 9 with `flip_h`** to
mirror the side view if the pack gives one side. The palette-swap shader is
**one material** on the sprite → recolours whichever animation is playing.
- Drive by velocity: dominant axis → facing; speed≈0 → `idle_<lastdir>`;
  combat target → `fight_`.
- **Combat = a stance pose**; keep the **artifact `Slash`/`Arrow`** effects as
  the hit feedback → **no bespoke attack frames needed** to ship readable
  combat ("before full animations, if ever").

### 14.6 Deferred (paperdoll layers) 🕓
Hair and masc/fem presentation are **later**. Code can **select + recolour**
authored pieces, but it **cannot invent shapes** — hairstyles/beards/body
types are **art**. If/when added: a small set of **hair overlay sprites**
(pick 1 + recolour from a hair bag) does gender variety cheaply; **separate
masc/fem body bases** are the big art lift and low priority. Get gender mostly
from **hair**, not separate bodies.

### 14.7 Performance
The per-frame shader is **negligible** even for hundreds of 2D sprites. The
only caveat: a **unique `ShaderMaterial` per unit** can break 2D batching at
very high counts (more draw calls). **Escape hatch** (only if it ever bites):
**bake the recolour to a texture once at spawn**, then use a plain sprite —
no per-frame shader, fully batchable. Don't build this pre-emptively.

### 14.8 Code-drawn terrain 🕓 (exploring)
Ambition: **draw map features from code/shaders** instead of sprite tiles — a
script that takes a line/curve and renders a **river** (a widened, shaded
polyline with flow), plus roads, coastlines, field borders. Pros: tiny asset
footprint, procedurally varied maps, pairs naturally with **shuffled elements**
(§7). Godot fit: `Line2D` / `Polygon2D` + a `canvas_item` shader for water/edges,
over a `TileMapLayer` base. Treat as R&D — prototype **one** feature (a river)
before committing the map pipeline to it.

---

## 15. Combat Balance & Tuning 🕓 (starting values — tune in playtest)

Derived from a Monte-Carlo combat simulator that mirrors the pairing / ranged
/ armour rules (100+ battles per data point). **These are starting numbers,
not gospel.** The sim clumps units with **no flanking, kiting, or screening**,
so it **over-rates shields** and **under-rates bows / fast units** — finalise
in real play (§15.6).

### 15.1 Armour model (StarCraft-style flat reduction)
Flat per-hit reduction — so big slow hits shrug off armour while fast weak
hits get eaten, *for free*:

`dealt = max(15% of raw, raw − target_armour × (1 − attacker_pierce))`

- New `UnitType` fields: **`armour`** (melee), **`missile_armour`** (vs arrows),
  **`pierce`** (0–1 — ignores that fraction of the target's armour).
- **The damage floor (~15% of raw) is a key knob:** it decides whether light
  troops can grind through armour at all. `0` = shields **hard-wall** Seax
  (you *must* bring anti-armour); higher = grindable. The floor only bites
  when `armour ≥ raw damage` — i.e. exactly the light-vs-shield case.

### 15.2 Attack-speed ladder
Attack interval should **inversely track per-hit damage** — otherwise "slow"
just means "worse." Slow units must **trade sustained DPS for per-hit punch**.
Axe = slowest / biggest hit (anti-armour); Seax = fastest.

### 15.3 Recommended starting stat block

| Unit | move | HP | dmg | atk int | ranged rr/rd/ri | armour | miss. | pierce | cap |
|---|---|---|---|---|---|---|---|---|---|
| **Seax** | 210 | 9 | 2 | 0.5 | — | 0 | 0 | 0 | **12** |
| **Spear** | 175 | 12 | 3 | 0.8 | 120/3/2.0 | 1 | 1 | 0.30 | **5** |
| **Sword & Shield** | 160 | 17 | 3 | 0.95 | — | 2 | 2 | 0 | **6** |
| **Bows** | 170 | 7 | 1 | 1.1 | 300/4/1.4 | 0 | 0 | 0.60 | **9** |
| **Shield Wall** | 135 | 16 | 2 | 1.3 | — | 3 | **5** | 0 | **6** |
| **Axe** | 150 | 14 | 6 | 1.7 | — | 1 | 1 | 0.55 | **6** |

### 15.4 Retinue caps — the *primary* balance lever
Per-type caps limit how many of a type a retinue may hold. Because of
**Lanchester's square law**, cheap units need caps far *lower* than raw power
implies (12 cheap bodies rout 4 elites regardless of quality), so caps are
solved against **full-retinue fights** (~cap ∝ power^-0.7), anchored to
**Seax = 12**. The rock-paper-scissors lives at the **cap** level, not
per-unit: e.g. 10 Axe ≈ 21 Seax, yet a full Seax retinue (12) *beats* a full
Axe retinue (6).

### 15.5 Counter web (units, from the sim)
- **Seax** → Axe, Bows (fast closers); walled by shields.
- **Axe** → shields (pierce); loses to Seax, Bows.
- **Spear** → most infantry (first strike); loses to Axe.
- **Sword & Shield** → light (Seax); folds to anti-armour.
- **Shield Wall** → Bows (missile armour) & Seax; too slow vs Axe.
- **Bows** → armour at range; die to Seax rushes, bounce off Shield Wall.

### 15.6 Known sim biases — correct these in playtest
- **Shields test too strong** (the sim never flanks to punish their slowness).
- **Bows & Seax test too weak** (no kiting/screening) — their caps (9 / 12)
  pre-compensate; expect them to shine once positioning is real.
- **Spear sits on a knife-edge at cap 5** — first thing to watch/tune.

### 15.7 Knockback on damage (ranged only)
Arrows and spear-throws **shove the target back a little on hit** — the point is
to *slow the melee rush* on the bows, buying the archers extra volleys, not to
peel-lock the attacker forever. Melee hits carry **no** knockback (only the
signature *Shield Bash / Push Back / Knockback* abilities do).

- **New `UnitType` fields:** **`ranged_knockback`** (px of setback per hit, `0`
  = none) and **`knockback_resist`** (`0–1`, fraction of incoming shove
  ignored). Heavies (**Axe, Shield Wall**) get high resist — they are the
  built-in counter to a bow line trying to kite them.
- **Starting magnitudes:** **Bows ≈ 20–30 px** setback/hit, **Spear ≈ 40–50 px**
  (heavier throw, but slower fire rate). Resist: Axe / Shield Wall **≈ 0.6–0.8**,
  Sword & Shield **≈ 0.3**, light **0**.
- **Reuses the existing `apply_knockback(dir, speed)` primitive** (decaying
  shove, `KNOCKBACK_DECAY = 800`). Setback distance ≈ `speed² / (2 × decay)`, so
  bows fire at **speed ≈ 200**, spears at **≈ 270**. Applied at the ranged hit,
  scaled by `(1 − target.knockback_resist)`. Optional per-target knockback
  cooldown (~0.3 s) if stacked hits jitter a unit.
- **Sim finding (why the magnitudes are safe):** across 0→150 px setback/hit,
  under both *nearest* and *spread* bow targeting, **12 Seax still break through
  9 Bows 100% of the time** — nearest-targeting fixates on the bounced
  front-runner while the pack keeps advancing, so there is **no perma-peel
  lock**. Knockback slows the rush; it never stops it.
- **Scope:** v0.2 polish — the numbers are cheap to add once the ranged hit path
  and `apply_knockback` are in.

---

## 16. Vertical Slice — The Build Target 🕓

Per Indie Game Clinic: **not a tutorial — a slice of the *mid-game*** that shows
the core at its best. **One level, ~20-min critical path, ruthlessly polished.**
Guard against scope creep like it's the enemy.

**Polish *feel* over breadth.** The moment-to-moment of selecting a warlord,
moving a retinue, and the mill/pairing combat is what a tester judges first —
nail responsiveness before adding content. Cut content, never core-verb polish.

**The six beats to engineer** (design the level so a cold tester can't miss
them):
1. **Command feel** — move, retinue trails, a first easy skirmish.
2. **Economy** — capture a village → muster → the warband visibly *grows*.
3. **Counter puzzle** — hit something you can't beat head-on (Seax bounce off a
   shield wall) → bring the right unit, flank with a 2nd warlord, or use an
   ability. *Needs 2–3 unit types in play, or the RPS never surfaces.*
4. **Assault set-piece** — the city: battlements raining arrows, screen with
   Shield Wall, breach the gate, push to the jarl.
5. **Clutch cooldown** — a close fight an ability turns (Rally / Shield Bash).
6. **The win** — kill the last jarl → VICTORY + stats.

**Onboarding = just-in-time toasts, never front-loaded.** Introduce each control
*at the moment it's relevant* ("walk in to muster," "they're too armoured —
press ▲"), one-shot. Teaches through play; keeps the mid-game feel.

**In:** 2–4 warlords + loadout · mill/flock command · **2–3 unit types**
(counters bite) · built-in signatures + one universal cooldown · village
capture/muster · one assault set-piece (city + jarl) · enemy patrol AI ·
win/defeat + victory panel · three-channel feedback · **basic sprites** (floaty
ok — mustn't *look* like a prototype).

**Out (keep it clean/baseline):** hacksilver/upgrades, revenge boon &
restart-decay (it's a single-level slice), scenario modifiers, shuffled
elements, the full discoverables system (one narrative buff for flavour),
churches, formal retreat, fog/morale, multi-level. Show the *default* game at
its best.

**The test for every feature:** *"Does this make a tester feel the core fantasy
in the next 10 minutes?"* If not — later.

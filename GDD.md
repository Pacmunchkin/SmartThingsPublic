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
the kingdom — but every warlord who falls is gone, replaced only by a raw
newcomer off the next longship.*

---

## 2. Design Pillars

1. **Lead from the front.** You *are* a unit on the field, not a god-cursor.
2. **The warband is your power.** Strength comes from the retinue you gather
   and the renown your warlords earn — not from base-building.
3. **Deliberate, weighty conquest.** Slow buildup to big battles; movement
   should be engaging in itself ("Skyrim-level" traversal feel). 🕓
4. **Meaningful permadeath, humane recovery.** Losing a warlord hurts; a
   total wipe never costs the campaign (checkpoint contract). 🔶
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
| Draw Out ability | The feigned retreat, a documented Viking deception |
| Knock Back ability | *Svinfylking* (boar's-snout wedge) splitting a shield wall |
| Steadfast ability | The *skjaldborg* (shield wall) |
| Warlord Leads ability | Chieftains fighting under the raven banner (*merki*); morale tied to the banner and the man |
| Ditch ability | Fortified ditched camps (Repton, 873; Irish *longphorts*) |
| Call ability | The war-arrow (*herör*) summons; Alfred's fyrd rotation |
| Longship replacements | The "Great Summer Army" reinforcing by ship, 871 |

---

## 4. Core Gameplay Loop

1. **War Council** — before the level, choose each warlord's unit type and
   starting ability. ✅
2. **Land & lead** — control the selected warlord; the retinue follows. ✅
3. **Gather** — conquer villages; they produce recruits that muster into
   your retinue. ✅
4. **Fight** — engage enemy garrisons and warbands in Bad North-style
   pairing combat. ✅
5. **Grow** — earn renown from deeds; heal and level up abilities at
   churches. ✅
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
  only once its retinue is defeated (except while *Warlord Leads* is active).
- **Permadeath:** a dead warlord is gone for the run; its select slot dies
  unless a longship replacement is enabled.

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

| Ability | Effect |
|---|---|
| Charge | Warlord + retinue move faster (sustained) |
| Steadfast | All damage taken reduced (sustained) |
| Knock Back | Shove + stun nearby enemies (instant) |
| Warlord Leads | Warlord targetable but retinue healed & buffed (sustained) |
| Advance | Melee hits shove enemies back — the line pushes forward (sustained) |
| Draw Out | Force-taunt enemies onto your army — the feigned retreat (instant) |
| Ditch | Ranged/arrow damage reduced (sustained) |
| Call | Friendly villages send garrisons running to you (instant) |

**Cooldowns:** stored on the ability asset, counted down per-warlord
per-slot; HUD shows READY / countdown / ACTIVE.

#### 6.4a Ability model (rebuild direction)
The three slots resolved into a **fixed identity + free choice** split:
- **Up = the unit type's built-in signature ability** (§6.3) — auto-filled.
- **Left / Right = player-chosen *universal* cooldowns** — must be two
  *different* universals; any warlord may take the same ones as another.

**Universal cooldowns** (picked in the War Council):

| Ability | Effect | Status |
|---|---|---|
| Charge | +move speed (blocked if already in melee) | ✅ |
| Steadfast | +armour (½ damage taken) − move speed | ✅ |
| Rally Cry | retinue +damage & +defence | ✅ |
| Knockback | shove + stun one enemy | ✅ |
| Feigned Retreat | auto-retreat then counter | 🕓 needs retreat AI |
| Scout | detach a scout, reveal fog | 🕓 needs fog of war |
| Raise the Standard | plant banner, morale | 🕓 needs morale |

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

### 6.5 Renown & Ability Levels (Veterancy)
**Two stacked layers.** Renown is career XP; Ability Level is the tier you
spend. ✅ **Implemented (v0.25):** float renown, deed values, level
thresholds, level-derived buffs, and slot-unlock-by-level. 🔶 **Still to
come (Option B, §6.6):** spending points to *upgrade a cooldown's depth*
(the branching component trees) — for now a level only unlocks the 3 slots.
(Numbers below are vertical-slice pacing — the real game progresses slower.)

- **Renown = career XP** — a running float, per-warlord, persists across the
  campaign (longship newbies start at 0), effectively uncapped. Earned by
  deeds only (never by waiting):

  | Deed | Renown | Deed | Renown |
  |---|---|---|---|
  | Enemy recruit | 0.1 | City | 5 |
  | Village | 1 | Enemy warlord | 10 |
  | Burh | 3 | **Retreat** | **−1** |

  (A single enemy-warlord kill = instant max level — "slay their champion,
  come into your power." Recruits/villages are the minor trickle.)

- **Ability Level (1–6) = tier derived from renown thresholds:**

  | Level | 1 | 2 | 3 | 4 | 5 | 6 |
  |---|---|---|---|---|---|---|
  | Renown | 0 | 1 | 3 | 5 | 7 | 10 |

- **Level drives everything** — passive buffs *and* ability points:
  - Buffs scale with **level** (not raw renown, or they'd explode at
    renown 10+): warlord +10% max HP / level; retinue +5% max HP, +2% speed
    / level. Bounded at level 6.
  - **1 ability point per level** (§6.6).
- Retreat's −1 renown can drop a level → removes a point (locks/downgrades a
  cooldown) and lowers the buffs.

### 6.6 Ability Upgrade Trees 🔶 (Option B — component system)
- An ability becomes a **list of effect-components**, each with a type,
  magnitude, and `min_level`. Enables **branching upgrade trees** and unique
  warlord builds (e.g. Charge L2 gains knockback, L3 gains damage).
- **Points economy:** each **Ability Level** (§6.5) grants **1 point**, spent
  as **add a new cooldown OR upgrade an existing one** — breadth vs depth.
  With **3 d-pad slots** (max 3 cooldowns) and **6 points** at max level, a
  curve emerges free: **early points buy breadth** (three tools by level 3),
  **points 4–6 force depth** (out of slots → upgrade). "At level 3: three
  cooldowns *or* one cooldown at level 3."
- **Renown funds levels; it isn't equal to them.** The warlord tracks each
  cooldown's level separately (so players build differently); the shared
  asset holds the per-level component table. Points are spent at churches;
  a renown loss (retreat) that drops a level locks/downgrades a cooldown.
- Supersedes the interim fixed-3-slots-at-renown model in the current code.

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

### 6.10 Churches ✅ / 🔶
- ✅ Heal the warlord + retinue in range; host the unpaused ability-pick when
  a renown-unlocked slot is empty.
- 🔶 **Checkpoint save point** (see §9): bank progress; reload point on wipe.

### 6.11 Longship Replacements ✅
- On a warlord's death, after a delay, a **renown-0 replacement** with a
  drawn name lands at a dock marker, fills the empty slot, and gets an
  arrival loadout. Endless — the cost of death is renown lost + time + the
  march back.
- 🔶 A level can disable replacements (empty "Warlord Scene") for a
  **true-permadeath hard level**.

### 6.12 War Council (Loadout Menu) ✅
- Pauses at level start; walks each warlord through choosing a unit type +
  first ability. Also hosts the unpaused church and longship-arrival picks.

### 6.13 UI ✅ (gray-box, pre-art)
- HUD: selected warlord name, renown, HP, army size; three ability slots
  (READY / countdown / ACTIVE / LOCKED); longship countdown.
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

### 6.14b Retreat 🕓 (targeted for v0.25)
The pressure-release valve for a losing fight — save the warlord, pay with
half the army.
- **Input:** hold **R** (a free shoulder button) for **3 s** → the selected
  warlord retreats. The hold guards against accidents.
- **Rearguard:** ~**50% of the retinue** (the half already closest to the
  enemy) is left behind to hold — mechanically, their follow-target is
  cleared so they hold position and fight (existing garrison behavior). The
  warlord flees with the other 50% as a mobile escort.
- **Pursuit:** while the rearguard lives, enemies are occupied with it. When
  it falls, enemies within pursuit range give chase. Because the warlord is
  untargetable while any retinue lives, the escort must be cut down before
  the warlord is exposed — a running fight, a last chance.
- **Flee speed:** the fleeing group (warlord + escort) is injured/spent:
  `speed = (base + buffs) × 0.8`. Buffs stay active in retreat, so a saved
  **speed buff is your escape hatch** — no buff → 0.8× vs pursuers' 1.0× (they
  close the gap; a thin rearguard = caught); Charge 1.5× → 1.2× (clean
  getaway). Escape abilities become dual-purpose (offense *and* escape).
- **Player-controlled:** retreat is an **active chase you steer**, not
  auto-path — route to safety yourself while the faster pursuers close. The
  natural goal is a **friendly village** (safety *and* the rebuild point:
  muster fresh recruits). **Escape resolves** on reaching a friendly village
  **or** outrunning pursuers to a safe distance (they give up). While fleeing
  the warlord + escort don't stop to fight (or they'd be left behind); if
  overtaken, a running fight breaks out.
- **Future idea** 🕓: fleeing into a friendly village could have its garrison
  join the fight — a retreat that becomes an ambush.
- **Renown cost:** retreat also drops renown by **1** (fleeing costs face —
  the reputation/morale channel). Kept small so **one** retreat is
  recoverable, while repeated ones compound. A renown drop can push the
  warlord below an ability slot's threshold and **lock that slot** (via the
  existing `is_slot_unlocked` gate) — the ability greys out until the renown
  is re-earned (auto-recover; a "permanently removed, re-pick at church"
  variant is a one-line change if wanted). It also lowers the renown HP
  bonus.
- **Economy fit:** trades the *recoverable* clock (army) to save the
  *expensive* one (renown + build) — see §8. **Self-limiting:** each retreat
  costs half the army + renown, and a recruit-less warlord can't retreat
  safely, so it can't be spammed. A successful retreat keeps the warlord in
  the level to regroup.
- **Build note:** mostly reuse (rearguard = null follow-target; pursuit =
  existing targeting/AI). New: hold-R input, the 50% split, a flee-state
  (run to safety, don't stop to fight), the safe-distance check.

### 6.14 Exploration & Discoverables 🕓
Interactable things placed in the world to make traversal rewarding (and to
counter the "traversal grind" risk). **Any reward can be permanent or
temporary** — the perm/temp choice is the main balancing lever (see note).

**Grounding — no magic (two channels).** Every buff has a *material* or
*psychological* cause, never a supernatural one. The gods do not alter steel
or flesh.
- **Material channel** — weapons → damage, armour/shields → defence, food &
  provisions → speed, rest/healer/herbs → healing, silver → longship
  arrivals, roads/fords/boats/rear-entrances → routes. **Survivability (HP,
  armour, healing) comes ONLY from this channel** — gear and recovery.
- **Morale channel** — omens, a raven, a skald's song, a heartening
  sacrifice, a recovered banner → a **temporary buff to attack + defence**
  (heartened men fight harder and hold the line), plus renown. **No separate
  "morale" variable** — "morale" is just the flavour label for a buff that
  applies the existing damage/defence multipliers. This is where Norse
  belief lives without magic: it moved men's courage (real), it did not
  thicken their mail.
Rule: **belief improves how hard men fight (attack/defence) and their
renown; it never raises max HP or heals — health comes only from the
material channel (gear, food, rest).** Re-skinning a source is free — the
mechanics are identical whether the fiction is "a sacrifice before battle"
or "a cache of Frankish mail."

**Reward taxonomy** — what a discovery can grant, what it serves, and how it
usually wants to be tuned:

| Reward | Serves | Tends to be | Material/morale source |
|---|---|---|---|
| Renown | Renown clock | Permanent, small/rare | Skald, famous plunder, runestone (reputation) |
| Damage boost | Combat | Temporary (or capped perm) | Forged/captured weapons, a smithy |
| Defence boost | Combat | Temporary (or capped perm) | Mail, shields, armour cache |
| Army speed boost | Traversal/combat | Temporary | Food stores, provisions, pack animals |
| Route reward | Strategic | Permanent (safe) | Ford, boat, **rear postern into a fort**, road, bridge |
| Healing | Recovery | Instant/one-time | Rest at camp, a healer/herbs, clean water |
| Recruits | Army clock | Permanent (self-limiting) | Deserters, escaped thralls, a champion |
| Sabotage | Strategic denial | One-time | Disable a beacon, burn a granary (cut enemy production), open a gate from inside |
| Useful information | Scouting | Permanent or timed reveal | Local guide, watchtower, captured scout |
| Speed a new warlord | Death economy | One-time | Silver hoard (plunder pays the crew) |
| Renown for a new warlord | Death economy | One-time | Recovered banner — the named legacy heartens the men |
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
- **Death-economy finds** (speed/renown a newbie) → **one-time**, and they
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
  time — as well as renown/buffs/nothing.
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
economy**. Route rewards across the three clocks (army / renown / traversal)
so exploration serves different needs, and **guard the best rewards** so a
find is a decision, not a checkbox.

---

## 7. Level Structure, Win & Faction Model

- **Faction = an integer `team`** on every combatant and structure (0 =
  player, 1 = enemy; higher numbers allow multiple factions). "Enemy" is
  simply *team ≠ player team*. ✅
- **Win condition:** no living warlord whose team differs from the player's.
  Populate a level with any number of enemy warlords. ✅
- **No defeat state by design** (endless longships). A defeat check would be
  added only for no-replacement hard levels. 🔶
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
  re-engage. **Persistence + tactics beats parity — grind does not** (death
  costs time + renown).

**v0.1 slice scope:** 4 player warlords; loadout → fight → win by killing all
enemy warlords. *In:* movement, retinues, combat + armour, abilities (buffs +
stun/knockback), villages/burhs/city-as-fortress, enemy **patrol AI** (waypoint
steering, no navmesh), loadout screen, win/lose + toasts. *Deferred (documented,
out of slice):* renown/veterancy, churches, longship respawn, formal retreat,
hold stance, fog/morale, city-capture economy, real art. Enemy warlords in v0.1
**don't use abilities** (leave their L/R empty).

---

## 8. Death Economy — Two Clocks

When a warlord dies, the player loses two things that recover at different
speeds:

- **Army (recruits):** recovers **fast** — a newbie musters a big warband
  quickly from late-game stocked villages (via mustering + Call).
- **Renown (personal power + ability build):** recovers **slow** — the
  lasting cost of death.

🔶 **Deed-magnitude renown** (recommended, not built): renown reward scales
with the *objective's* size (village +1, burh +2, gate/warlord +3), so
late-game newbies catch up naturally without cheapening death.

Note: because a warlord is untargetable until its retinue is dead, the
retinue is almost always gone before the warlord falls — so "inherit the
orphaned retinue" is a non-mechanic. Rare lingering retinues **fade out on
camera change**. 🔶

---

## 9. Campaign Recovery — The Checkpoint Contract 🔶

Solves the "10 hours in, total wipe, player quits" risk. **Single death**
and **total wipe** are different problems with different solutions:

- **Single death** → the two-clocks recovery above.
- **Total wipe** → **reload the last church checkpoint**, roster restored to
  its state at that church.

**The contract:** *deaths bank permanently when you reach the next church; a
wipe reloads the last church.* Permadeath is real (banked at churches);
a wipe costs the time since your last save, never the campaign. This makes
churches strategic ("push or bank?") and makes the punishing "three renown-0
warlords vs a late level" state rare and self-inflicted.

Requires the **save system** (serialize warlords, retinues, renown, villages,
cooldowns) — the priority of the campaign phase.

---

## 10. Technical Architecture ✅

- **Base class `Combatant`** (`CharacterBody2D`): team, health, `take_damage`,
  `died` signal, stun, structure flag, renown kill-credit. Extended by
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
5. 🔶 **Ability upgrade trees** (Option B component system) + renown-funded,
   church-chosen upgrades.
6. 🔶 **Save / checkpoint system** — the campaign-recovery contract (§9).
7. 🕓 **Campaign layer** — stitch levels, persist warlords/renown between them.
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
| Permadeath full-restart boredom (Bad North) | 🔶 Addressed — longship + checkpoint contract |
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
6. Renown, churches, unit-type choice, permadeath stakes…

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

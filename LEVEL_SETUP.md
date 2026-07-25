# Level Setup Checklist — Vertical Slice

Everything needed to assemble one playable, winnable test level from the
scripts in this repo. Build **bottom-up**: project settings → assets →
leaf scenes → composite scenes → the level. Each scene lists its exact
node tree (also documented in the top comment of each `.gd` file).

Godot 4.7, 2D. All visuals are gray-box `ColorRect`s for now.

---

## 0. Project Settings

### Input Map  (Project Settings → Input Map — add these actions)
- [ ] `select_a` → Joypad Button 0 (A / Cross)
- [ ] `select_b` → Joypad Button 1 (B / Circle)
- [ ] `select_x` → Joypad Button 2 (X / Square)
- [ ] `select_y` → Joypad Button 3 (Y / Triangle)
- [ ] `ability_up` → Joypad D-pad Up
- [ ] `ability_left` → Joypad D-pad Left
- [ ] `ability_right` → Joypad D-pad Right
- [ ] `move_left` → Joypad Axis 0 (Left Stick, negative)
- [ ] `move_right` → Joypad Axis 0 (Left Stick, positive)
- [ ] `move_up` → Joypad Axis 1 (Left Stick, negative)
- [ ] `move_down` → Joypad Axis 1 (Left Stick, positive)

(Add keyboard keys to the same actions if you want to test without a pad.
`ui_*` actions used by menus already exist by default — no setup.)

### Collision (simplest graybox start)
- [ ] Put every unit, wall, gate, and burh barrier on **collision layer 1,
      mask 1**. That way recruits shove each other, hold a battle line, and
      bump walls. Refine into separate layers later if needed.

### Motion mode (top-down)
- Warlord and Recruit set **Motion Mode = Floating** in code (`_ready`), so
  no Inspector step is needed. (The `CharacterBody2D` default, *Grounded*,
  is for platformers — its floor-snapping fights upward movement and drags
  horizontal movement downward when units share a collision layer.)

---

## 1. Resource Assets (.tres)

Create in the FileSystem dock: right-click → New Resource. Full field
values are in `game_assets.gd`. **Minimum to playtest: 1 UnitType + 1
Ability.** The full set makes the loadout menus feel complete.

### Unit Types (New Resource → UnitType) → save in `res://units/`
- [ ] `seaxes.tres`   (fast, weak, quick attacks)
- [ ] `axes.tres`     (slow, tough, hard hits)
- [ ] `spears.tres`   (throws while closing; ranged_range 120)
- [ ] `shield.tres`   (resilient)
- [ ] `bows.tres`     (ranged_only ON; never melees)

### Abilities (New Resource → Ability) → save in `res://abilities/`
- [ ] `charge.tres` · `steadfast.tres` · `knock_back.tres` ·
      `warlord_leads.tres` · `advance.tres` · `draw_out.tres` ·
      `ditch.tres` · `call.tres`

---

## 2. Leaf Scenes

### `recruit.tscn`  — root **CharacterBody2D** + `recruit.gd`
- [ ] `ColorRect`  (Size 16×16, Position −8,−8, gray)
- [ ] `CollisionShape2D`  (Circle radius ~8 or Rect 16×16)
- [ ] `NavigationAgent2D`  (Inspector: **Avoidance = OFF**) — enables pathing
- [ ] `HealthBar` (Node2D + `health_bar.gd`, Pos 0,12, Bar Width 16,
      **Hide When Full = ON**)  *(optional but recommended)*

### `warlord.tscn`  — root **CharacterBody2D** + `warlord.gd`
- [ ] `ColorRect`  (~20×20, a distinct colour from recruits)
- [ ] `CollisionShape2D`
- [ ] `HealthBar` (Node2D + `health_bar.gd`, Pos 0,18)
- [ ] `SelectionMarker` (Node2D + `selection_marker.gd`, Pos 0,−24)
- [ ] `NavigationAgent2D`  (Avoidance OFF) — used only by AI warlords
- [ ] `Retinue` (plain Node2D) — drop `recruit.tscn` instances in here for
      a starting retinue
- [ ] Inspector: set **Max Retinue 50**, and optionally **Unit Type** /
      **Ability Up/Left/Right** (the War Council can override these)
- **NOTE:** the Controller / AIController node is added per-instance in
  `main.tscn`, **not** inside this scene.

### `battlement.tscn`  — root **Node2D** + `battlement.gd`
- [ ] `ColorRect`  (~24×24, Pos −12,−12)

### `city_gate.tscn`  — root **CharacterBody2D** + `city_gate.gd`
- [ ] `ColorRect`  (96×24, centred)
- [ ] `CollisionShape2D`  (seals the gateway)
- [ ] `NavigationObstacle2D`  (vertices covering the gateway) *(optional)*
- [ ] `HealthBar` (Pos 0,20, Bar Width 96) *(optional)*

### `church.tscn`  — root **Node2D** + `church.gd`
- [ ] `ColorRect`  (~32×32, centred)

---

## 3. Composite Scenes

### `village.tscn`  — root **Node2D** + `village.gd`
- [ ] `Garrison` (plain Node2D) — optionally drop `recruit.tscn` instances
      at their guard spots
- [ ] Inspector: **Recruit Scene = recruit.tscn**, **Team** (1 = enemy),
      Max Garrison 25, Production Interval 10

### `burh.tscn`  — root **Node2D** + `burh.gd`
- [ ] `Garrison` (plain Node2D)
- [ ] `Barrier` (StaticBody2D)
  - [ ] `CollisionShape2D` (sized to seal the choke)
  - [ ] `ColorRect` (the wall)
  - [ ] `NavigationObstacle2D` (vertices = the blocked gap) *(optional)*
- [ ] Inspector: **Recruit Scene = recruit.tscn**, **Garrison Count**,
      **Team**, Spawn Radius 40

### `city.tscn`  — root **Node2D** + `city.gd`
- [ ] `Gate` (instance of `city_gate.tscn`) — place in the wall opening
- [ ] `Battlements` (plain Node2D) → several `battlement.tscn` instances
      along the walls
- [ ] `Walls` (StaticBody2D) → CollisionShape2D + ColorRect segments
      arranged so the Gate is the only way through
- [ ] Inspector: **Team** (1)

---

## 4. The Level — `main.tscn`  — root **Node2D** + `warlord_commander.gd`

### Core children
- [ ] `Camera2D`  (direct child of Main — the commander drives it)
- [ ] `WarlordA` (instance of `warlord.tscn`, **Team 0**)
  - [ ] child `Controller` (plain Node + `player_controller.gd`)
- [ ] `WarlordB`, `WarlordX`, `WarlordY` — same, each with a `Controller`
      child (use as many as the level wants; unused slots can stay empty)
- [ ] One or more **enemy warlords** (instance `warlord.tscn`, **Team 1**)
  - [ ] child `AIController` (plain Node + `ai_controller.gd`)
  - [ ] give each a Retinue so it's a real fight
- [ ] `Village` instances (Team 1 enemy, or Team 0 to start friendly)
- [ ] `Burh` instances at choke points (Team 1)
- [ ] `City` instance (Team 1)
- [ ] `Church` instance(s) (Team 0)
- [ ] `LongshipDock` (Marker2D) at the shoreline / player entry

### Navigation (needed for pathfinding to do anything)
- [ ] `NavigationRegion2D` with a NavigationPolygon **baked** around the
      walls / burhs / city (set agent radius ≈ recruit radius so units
      don't clip corners).  *(Or use a TileMapLayer with TileSet
      navigation later — the code is identical.)*

### UI / systems children
- [ ] `Hud` (CanvasLayer + `hud.gd`)
- [ ] `WarCouncil` (CanvasLayer + `war_council.gd`)
  - [ ] Inspector: drag all UnitType `.tres` into **Unit Types**,
        all Ability `.tres` into **Abilities**
- [ ] `LevelManager` (CanvasLayer + `level_manager.gd`, **Player Team 0**)

### Wire the commander (select Main, Inspector)
- [ ] **Warlord A / B / X / Y** ← drag the matching warlord instances
- [ ] **Warlord Scene** ← `warlord.tscn`  (enables longship replacements;
      leave empty for a true-permadeath hard level)
- [ ] **Longship Dock** ← the `LongshipDock` Marker2D
- [ ] **Replacement Delay** 60 (or taste)

- [ ] Set `main.tscn` as the project's **main scene** (Project → Run).

---

## 5. Smoke Test — verify the slice end-to-end

- [ ] Launch → **War Council** appears, game paused. Pick unit types /
      abilities for each warlord; after the last, the level starts.
- [ ] Left stick moves the **selected** warlord; A/B/X/Y switch, camera
      snaps, selection triangle follows. Retinue trails.
- [ ] Walk a retinue into an enemy garrison → recruits **pair off** and
      fight; survivors return to post/warlord.
- [ ] Path around a wall/burh (units route, don't smear on the wall).
- [ ] Hold **X + D-pad** on the selected warlord → ability fires; HUD shows
      cooldown / ACTIVE; LOCKED slots show renown requirement.
- [ ] Conquer a village → it flips team, produces recruits; stand near →
      they muster into the retinue. **Renown +1** on the HUD.
- [ ] Visit a **Church** → warlord + retinue heal; if a slot is unlocked
      and empty, the ability-pick opens (unpaused).
- [ ] Reduce a warlord's retinue to 0, then kill the warlord → **LONGSHIP
      INBOUND** counts down; a fresh named warlord lands and gets an
      arrival loadout.
- [ ] Defeat the **last enemy warlord** → **VICTORY** panel, game pauses.

---

## Minimum viable first test
You don't need everything to start. The smallest end-to-end test:
1 UnitType + 1 Ability, `recruit.tscn`, `warlord.tscn`, one player warlord
(+Controller) and one enemy warlord (+AIController, +small retinue), a
NavigationRegion2D, and the three CanvasLayers (Hud, WarCouncil,
LevelManager). Kill the enemy warlord → VICTORY. Grow from there.

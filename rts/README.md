# Wessex — squad-tactics RTS

A Godot 4.3 project containing a **code-generated level** for a squad-tactics
RTS: continuous-space cover, no base building, scripted campaign missions.

There are no art assets. Every texture is written at run time and every
material is a shader in this repository.

```
godot --path rts                    # open / play
```

Press **R** while playing to regenerate with a new seed.

---

## 1. The generated level

`worldgen/generated_world.tscn` builds a 1080 × 1920
valley in five stages, in this order, and the order is the whole design:

| # | Stage | File | What it does |
|---|-------|------|--------------|
| 1 | Forest | `stages/forest_stage.gd` | Blankets the entire map in wildwood. Density comes from fBm so the canopy already has natural glades. |
| 2 | River | `stages/river_stage.gd` | Meanders a channel from the top edge to the bottom, widening downstream. Clears every tree in the channel and on the banks. Picks 3 fords at the narrows. |
| 3 | Landscape | `stages/landscape_stage.gd` | Hills + ridged crags, then a valley profile driven purely by distance to the river. Reports how much buildable flat it produced. |
| 4 | Villages | `stages/village_stage.gd` | Scores every cell on where people would actually settle, picks 4 sites, clears and levels them. |
| 5 | Roads | `stages/road_stage.gd` | A* over a cost field, minimum spanning tree between villages plus one redundant link and a way out of the valley. Clears the verges. |

**Each stage may only subtract from or build on what came before.** That
constraint is what makes the map read as a place with a history rather than
four noise fields stacked on each other: the river explains the valley, the
valley explains the villages, and the villages explain the roads. Every gap in
the canopy is somewhere water, rock, or people put it there.

### Why the river comes before the terrain

Backwards from how water works, deliberately. Deriving a river from a heightmap
gives you whatever the noise happened to allow — sometimes a lake, sometimes
nothing. Authoring the river first and raising the land around it guarantees one
continuous navigable corridor down the length of the map, which is a hard
requirement for a playable level and only a cosmetic loss in realism.

### Stage 3's contract with stage 4

The valley is a flat **terrace** either side of the channel, not a V. Without
that there is nowhere to build and stage 4 has nothing to choose between. The
stage logs the flat area it produced so the guarantee is measurable:

```
landscape: 13712 buildable cells in the valley (44% of the floor, 493632 px^2)
```

### How stage 4 decides where people live

Weighted score per cell, in descending order of influence
(`village_stage.gd`):

- **Water** — a *band* around ~105 px from the centreline, not a gradient.
  Close enough to carry from daily, far enough that the spring flood misses.
- **Dry ground** — strictly above the local waterline. Height above the *local*
  river, not the mouth, or every northern site looks like a clifftop.
- **Flat, workable land**, and enough of it to grow into (summed-area table, so
  "room within reach" is O(1) per candidate).
- **A crossing** — fords make towns.
- **Shelter** — in the valley, not on an exposed top.

Sites are then picked greedily with a 400 px minimum separation.

### What "most efficient road" means

Not the shortest line — the cheapest one, over costs that mattered to someone
walking with a loaded pony: climbing is expensive, wading is worse, standing
wood is a nuisance, and **someone else's road is nearly free**. That last term
makes the network braid rather than run parallel routes fifty paces apart.

Cliffs are `INF` cost and the river is near-prohibitive off a ford, so the roads
find the passes and the crossings without either being special-cased.

A low-frequency roughness field is added to the cost. Without it, a least-cost
path across the uniformly flat valley floor is a dead straight line — which is
what the roads looked like before, and nothing like a worn track.

---

## 2. Rendering — shaders and code-baked textures

| Thing | Where | Notes |
|-------|-------|-------|
| Ground | `shaders/terrain.gdshader` | One full-map pass. Hillshade from the height gradient, hypsometric tint, cliff strata, tilled fields with ridge-and-furrow, road wear, animated water with foam and glint. All noise is procedural in-shader. |
| Trees | `shaders/tree.gdshader` | One `MultiMeshInstance2D`, ~7800 instances, one draw call. Per-instance species/tint/sway. |
| Canopy atlas | `texture_baker.gd` | Three species drawn in code: lobed silhouette from summed sine harmonics, dome shading, value-noise grain. |
| Data textures | `texture_baker.gd` | `field` = height/slope/water/river-distance, `cover` = road/settled/canopy/cliff. |

The field map is **RGBA16F**, not RGBA8. The hillshade differentiates the height
channel, and 8-bit steps produce visible contour rings across exactly the ground
flat enough to build on. Half floats cost 460 KB and the banding disappears.

MultiMesh instance data is only readable in the vertex stage, so
`INSTANCE_CUSTOM` is forwarded to the fragment stage through varyings. The frame
index is `flat` — interpolating it blends two species together at the atlas seam.

---

## 3. Authoring your own level (`levels/level_1.tscn`)

Open `levels/level_1.tscn` and drag things about — it rebuilds as you edit.

Every feature is a **brush**: a node that paints into one shared `WorldData`
grid. `LevelRoot` walks its descendants and calls `apply(world)` on each, so
**tree order is layer order** — drag a node above another and it paints first.
Group brushes under plain `Node2D`s for tidiness; the walk is depth-first, so a
group behaves exactly like its contents inlined.

```
Level1                (LevelRoot)      map_size, cell_size, level_seed
├── Forest            (ForestBrush)    no polygon = the whole map
├── River             (RiverBrush)     └── Path2D   ← drag the handles
├── Hills
│   ├── WestValleyWall (ScarpBrush)    └── Path2D
│   ├── EastValleyWall (ScarpBrush)    └── Path2D
│   └── NorthKnoll     (HillBrush)     └── Polygon2D
├── Clearings
│   └── RiversideMeadow (ClearingBrush) └── Polygon2D
├── Settlements
│   ├── Upperford      (SettlementBrush)  ← just drag the node
│   ├── Nethertun      (SettlementBrush)
│   └── Stanwic        (SettlementBrush)
├── Roads
│   ├── UpperfordToNethertun (RoadBrush)  SOLVE
│   ├── NethertunToStanwic   (RoadBrush)  SOLVE
│   └── WayOutOfTheValley    (RoadBrush)  SOLVE + to_map_edge
├── Terrain           (ColorRect)      ← the shader draws here
├── Trees             (MultiMeshInstance2D)
├── Sectors           (Node2D)         ← capture points appear here
└── WorldSampler      (Node)
```

| Brush | Shape child | What it does |
|---|---|---|
| `ForestBrush` | `Polygon2D` *(optional)* | Plants wildwood. No polygon = whole map. Several can coexist with different spacing/species. |
| `RiverBrush` | `Path2D` | Carves a channel along the curve, widening source→mouth, clears channel and banks, places fords at the narrows. |
| `HillBrush` | `Polygon2D` | Raises (or with a negative height, sinks) ground. The polygon is the **top**; `falloff` is how far the slope runs out. |
| `ScarpBrush` | `Path2D` | A **step** in the ground — different height each side of the line. Valley walls, escarpments, terrace edges. |
| `ClearingBrush` | `Polygon2D` | Fells trees, feathered at the edge. Optionally marks the ground worked. |
| `SettlementBrush` | *(none — drag the node)* | Clears, levels, marks core and fields, and registers a capture point. |
| `RoadBrush` | `Path2D` *(DRAWN mode)* | `SOLVE`: A* between two named settlements. `DRAWN`: follows your curve exactly. |

### "Which part is uphill?"

You never say. You set a **height**, and slope is the gradient of the height
field — so which way is up is a consequence of the numbers, not a declaration.
That is the same rule everywhere, which is why a hill steep enough becomes an
impassable cliff on its own: `LevelRoot` recomputes the gradient after every
height brush and marks anything past `LandscapeStage.CLIFF_SLOPE`.

A `Curve2D` on its own genuinely cannot express a hill — a line has no up. What
it *does* have is two sides, and that is what `ScarpBrush` uses: `height_left`
and `height_right`, with the ground stepping between them over `run` px. Short
run = cliff, long run = walkable hillside.

**Left and right are relative to the direction the curve is drawn**, as if
walking it from first point to last. In the example level both valley walls are
`height_right`-high, because one is drawn north→south and the other
south→north. If you get it backwards, swap the two numbers or reverse the
curve — either works.

### Roads: solved or drawn

`SOLVE` runs A* over the real cost of the ground (climbing expensive, wading
worse, wood a nuisance, **an existing road nearly free**) between two
settlements looked up by `settlement_name`. Put a road *below* another in the
tree and it will join it and share a stretch rather than running parallel.

`DRAWN` follows a `Path2D` exactly — for when the route is a design decision
rather than a logistics one.

A road can only find settlements placed **above** it in the tree. That is the
layer order doing its job: a road cannot lead to a village that does not exist
yet.

### Writing a new brush

```gdscript
@tool
class_name PalisadeBrush
extends WorldBrush

func apply(world: WorldData) -> void:
    var line := curve_points()      # or polygon_points()
    ...

func affects_height() -> bool:
    return false                     # true if you write world.height
```

`WorldBrush` gives you `polygon_points()`, `curve_points()`,
`for_each_cell_near()`, `clear_trees()`, `distance_to_polyline()` and
`side_of_polyline()` — that last one is how anything one-sided (a ditch's spoil
bank, a wall's fighting step) tells inside from outside without the author
labelling it.

### Where palisades, gates, tents and walls fit

They split into two kinds, and it matters which:

**Field brushes** change the grid, like the ones above. Earthworks and ditches
belong here: they are terrain, they move height, and `WorldSampler` already
reports cover and passability from the grid. An earthwork brush is a
`ScarpBrush` with a ditch on one side and a bank on the other.

**Object placers** emit discrete `CoverVolume` nodes. Palisades, brick walls,
gates, doors, tents, farmstead buildings all belong here, because each is a
*thing* with its own integrity, flammability and garrison — and `CoverVolume`
already models all of that, including directional protection, burning and
degrading a class at a time under fire.

Which means there are really only two placers to write, not eight:

- **stamp cover along a curve** → palisade, brick wall, hedge, revetment. A gate
  is a gap in the run with its own destructible volume.
- **stamp cover over a footprint** → tent, hut, barn, gatehouse, farmstead.

Both should emit into a `Cover` node the way settlements emit into `Sectors`,
so the combat layer sees exactly what the hand-authored Athelney map gives it.

---

## 4. Gameplay queries

A generated map can't use one `Area2D` per piece of cover — there are thousands
of trees and the cliff line is a raster, not a polygon. `worldgen/world_sampler.gd`
answers the same questions directly from the cell grid:

```gdscript
sampler.move_multiplier(pos)          # road 1.15, wood 0.7, ford 0.5, cliff 0
sampler.passable(pos, armoured, wheeled)
sampler.cover_class(pos)              # maps onto CoverVolume.CoverClass
sampler.damage_multiplier(target, shooter)   # flanking included
sampler.has_line_of_sight(a, b)       # DDA; one trunk doesn't blind you, four do
sampler.describe(pos)                 # everything at once
```

The answers deliberately match `TerrainRegion`/`CoverVolume` semantics, so the
combat layer doesn't care which kind of map it's standing on.

Villages become `TacticalSector` capture points automatically; ones on a ford are
flagged `mission_critical`.

---

## 5. The runtime layer (`scripts/`)

Shared by generated and hand-authored maps.

- `cover_volume.gd` — polygon cover with **directional** protection. Damage
  multipliers NONE/LIGHT/MEDIUM/HEAVY = 1.0 / 0.75 / 0.55 / 0.35, applied only
  when the shot arrives inside the protected arc. Flammable cover degrades a
  class at a time.
- `terrain_region.gd` — movement, concealment, elevation, hazards. Overlapping
  regions resolve by `terrain_priority`, highest wins.
- `tactical_sector.gd` — presence-based contested capture. An enemy squad stalls
  capture rather than reversing it.
- `trigger_volume.gd` — tripwires with a dwell requirement, armed per act.
- `mission_director.gd` — runs acts, wave timelines, scripted beats and
  objectives. Doesn't know how to build a squad: it resolves an archetype and a
  position, then hands both to a spawner or emits `squad_requested`.

Scale: **1 px = 0.1 m**.

---

## 6. The hand-authored example mission

`missions/m04_athelney/` is a scripted three-act mission built by hand before
the generator existed — *The Causeway at Æthelinga Īeg*, Somerset Levels,
February 878. It still loads and still validates, and it's the worked example of
what the mission data model can express: escort → shieldwall defence with fire
arrows and marsh mist reshaping the map mid-act → counterattack with a fleeing
hero the player can cut off by burning his ships first.

Its geometry is hand-placed polygons on a 2400 × 1800 landscape map, so it does
**not** use the generator. Treat it as the mission-format reference, not as the
level pipeline.

```
python3 tools/validate_mission.py
```

Cross-checks every id in the mission resource against the scene — Godot won't
complain about a wave that spawns at a marker nobody placed, it just quietly
does nothing at minute six.

---

## 7. Tuning

Most knobs are constants at the top of each stage.

| Want | Change |
|------|--------|
| Denser/sparser wood | `ForestStage.SPACING`, `GLADE_THRESHOLD` |
| Wider/narrower valley floor | `LandscapeStage.TERRACE_HALF_WIDTH`, `WALL_RUN` |
| More/less impassable rock | `LandscapeStage.CLIFF_SLOPE` (0.80 ≈ 6% of map) |
| More villages | `VillageStage.COUNT`, `MIN_SEPARATION` |
| Different settlement logic | the `W_*` weights in `VillageStage` |
| Roads that hug/avoid terrain | `RoadStage.SLOPE_PENALTY`, `ROUGH_PENALTY` |
| Map size | `WorldGenerator.map_size`, and the viewport in `project.godot` |

Generation takes ~4 s for 1080 × 1920 at `cell_size = 6` (180 × 320 cells). It
runs synchronously in `_ready()`; a shipping build should move it to a thread or
a loading screen.

---

## 8. Rendering a preview

```
xvfb-run -a godot --path rts --rendering-driver opengl3 \
  --resolution 1080x1920 --script tools/capture_preview.gd -- \
  --seed 777 --out preview.png

# a hand-authored level instead
xvfb-run -a godot --path rts --rendering-driver opengl3 \
  --resolution 1080x1920 --script tools/capture_preview.gd -- \
  --scene res://levels/level_1.tscn --out level1.png
```

Needs a GL context, so plain `--headless` won't do. Useful in CI: a seed that
used to produce a valley and now produces a lake is a regression you want to
see, not read about.

---

## Known limitations

- **No navmesh.** `WorldSampler.passable()` gives per-cell passability, but
  nothing bakes a `NavigationPolygon` from it yet. Unit pathing needs either
  that or an A* grid reusing `RoadStage`'s cost field.
- **No unit layer.** `MissionDirector` emits `squad_requested`; nothing listens.
  The archetypes in `factions/` are stat blocks, not scenes.
- **Roads still show occasional right-angle corners** where the cost field ties
  and A* picks an axis. Chaikin smoothing softens but doesn't remove it.
- Generation is single-threaded and blocking. A hand-authored level rebuild is
  ~7 s at `cell_size = 6`; each RoadBrush rebuilds the whole cost field, which
  is the obvious thing to cache next.
- No cover placers yet, so palisades, walls, gates and tents are still to come.

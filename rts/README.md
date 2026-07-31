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

`worldgen/generated_world.tscn` is the main scene. It builds a 1080 × 1920
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

## 3. Gameplay queries

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

## 4. The runtime layer (`scripts/`)

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

## 5. The hand-authored example mission

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

## 6. Tuning

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

## 7. Rendering a preview

```
xvfb-run -a godot --path rts --rendering-driver opengl3 \
  --resolution 1080x1920 --script tools/capture_preview.gd -- \
  --seed 777 --out preview.png
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
- Generation is single-threaded and blocking.

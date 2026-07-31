class_name WorldSampler
extends Node

## Gameplay queries against the generated world.
##
## The hand-authored map used one Area2D per piece of terrain and cover. A
## generated map cannot: it has thousands of trees and a cliff line that is a
## raster, not a polygon. So the same questions - how fast do I move here, can
## I see through it, what does it protect me from - are answered directly from
## the cell grid instead.
##
## The answers deliberately match TerrainRegion and CoverVolume's semantics, so
## the combat layer does not care which kind of map it is standing on.

const CLIFF_COVER_REACH := 26.0  ## How far from a rock face you still get it.

var world: WorldData


func bind(data: WorldData) -> void:
	world = data


func _flags_at(world_pos: Vector2) -> int:
	if world == null:
		return 0
	var c := world.cell_at(world_pos)
	return world.flags[world.idx(c.x, c.y)]


# --- movement ---------------------------------------------------------------

func move_multiplier(world_pos: Vector2) -> float:
	var flags := _flags_at(world_pos)
	if (flags & WorldData.CLIFF) != 0:
		return 0.0
	if (flags & WorldData.ROAD) != 0:
		return 1.15
	if (flags & WorldData.RIVER) != 0:
		return 0.5 if (flags & WorldData.FORD) != 0 else 0.3
	if (flags & WorldData.VILLAGE) != 0:
		return 1.0
	if (flags & WorldData.FIELD) != 0:
		return 0.92
	if (flags & WorldData.BANK) != 0:
		return 0.85
	if (flags & WorldData.FOREST) != 0:
		return 0.7
	# Open hillside: the going is set by the gradient.
	return clampf(1.0 - world.slope_at(world_pos) * 0.9, 0.35, 1.0)


func passable(world_pos: Vector2, is_armoured: bool = false,
		is_wheeled: bool = false) -> bool:
	var flags := _flags_at(world_pos)
	if (flags & WorldData.CLIFF) != 0:
		return false
	var in_water := (flags & WorldData.RIVER) != 0
	if in_water and (flags & WorldData.FORD) == 0:
		return false  # Off a ford the channel is too deep to wade.
	if is_wheeled:
		# Carts keep to made ground and gentle slopes.
		if (flags & (WorldData.ROAD | WorldData.VILLAGE | WorldData.FIELD)) != 0:
			return true
		return not in_water and world.slope_at(world_pos) < 0.18
	if is_armoured and in_water:
		return false  # Mail and moving water do not mix.
	return true


# --- perception -------------------------------------------------------------

func concealment(world_pos: Vector2) -> float:
	var flags := _flags_at(world_pos)
	if (flags & WorldData.FOREST) != 0:
		return 0.55
	if (flags & WorldData.FIELD) != 0:
		return 0.12
	return 0.0


func elevation_band(world_pos: Vector2) -> int:
	var height := world.height_at(world_pos)
	if height < 0.0:
		return 0
	if height < 30.0:
		return 1
	if height < 75.0:
		return 2
	return 3


## Walks the grid between two points and reports whether the canopy or a crag
## breaks the line. Cheap DDA rather than a physics raycast, because the
## occluders are cells, not bodies.
func has_line_of_sight(from_pos: Vector2, to_pos: Vector2) -> bool:
	if world == null:
		return true
	var distance := from_pos.distance_to(to_pos)
	if distance < 1.0:
		return true
	var steps := int(distance / float(world.cell))
	var blocked_run := 0
	for i in range(1, steps):
		var point := from_pos.lerp(to_pos, float(i) / float(steps))
		var flags := _flags_at(point)
		if (flags & WorldData.CLIFF) != 0:
			return false
		if (flags & WorldData.FOREST) != 0:
			# A single trunk does not blind you; a depth of wood does.
			blocked_run += 1
			if blocked_run >= 4:
				return false
		else:
			blocked_run = 0
	return true


# --- cover ------------------------------------------------------------------

## Mapped onto CoverVolume.CoverClass so the damage tables are shared.
func cover_class(world_pos: Vector2) -> CoverVolume.CoverClass:
	var flags := _flags_at(world_pos)
	if (flags & WorldData.ROAD) != 0:
		return CoverVolume.CoverClass.NONE  # A made road is a killing ground.
	if (flags & WorldData.VILLAGE) != 0:
		return CoverVolume.CoverClass.MEDIUM
	if _near_cliff(world_pos):
		return CoverVolume.CoverClass.HEAVY
	if (flags & WorldData.FOREST) != 0:
		return CoverVolume.CoverClass.LIGHT
	if (flags & WorldData.FIELD) != 0:
		return CoverVolume.CoverClass.LIGHT
	return CoverVolume.CoverClass.NONE


## Cliff cover is directional: it protects from the rock's side only. Returns
## the world direction the protected face points, or -1 when the cover here is
## omnidirectional.
func cover_facing_deg(world_pos: Vector2) -> float:
	var towards := _nearest_cliff_direction(world_pos)
	if towards == Vector2.ZERO:
		return -1.0
	return rad_to_deg(towards.angle())


func damage_multiplier(target_pos: Vector2, shooter_pos: Vector2) -> float:
	var cover := cover_class(target_pos)
	if cover == CoverVolume.CoverClass.NONE:
		return 1.0
	var facing := cover_facing_deg(target_pos)
	if facing >= 0.0:
		var to_shooter := (shooter_pos - target_pos).angle()
		if absf(angle_difference(deg_to_rad(facing), to_shooter)) > deg_to_rad(95.0):
			return 1.0  # Flanked: the rock is behind them now.
	return CoverVolume.DAMAGE_MULTIPLIER[cover]


func _near_cliff(world_pos: Vector2) -> bool:
	return _nearest_cliff_direction(world_pos) != Vector2.ZERO


func _nearest_cliff_direction(world_pos: Vector2) -> Vector2:
	if world == null:
		return Vector2.ZERO
	var origin := world.cell_at(world_pos)
	var reach := int(ceil(CLIFF_COVER_REACH / float(world.cell)))
	var best := Vector2.ZERO
	var best_distance := INF
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if dx == 0 and dy == 0:
				continue
			if not world.has_flag(origin.x + dx, origin.y + dy, WorldData.CLIFF):
				continue
			var offset := Vector2(dx, dy) * float(world.cell)
			var d := offset.length()
			if d < best_distance and d <= CLIFF_COVER_REACH:
				best_distance = d
				best = offset
	return best.normalized() if best != Vector2.ZERO else Vector2.ZERO


# --- convenience ------------------------------------------------------------

## Everything at once, for the combat layer's per-tick terrain lookup.
func describe(world_pos: Vector2) -> Dictionary:
	return {
		"move": move_multiplier(world_pos),
		"passable": passable(world_pos),
		"concealment": concealment(world_pos),
		"elevation": elevation_band(world_pos),
		"cover": cover_class(world_pos),
		"cover_facing_deg": cover_facing_deg(world_pos),
		"height": world.height_at(world_pos) if world != null else 0.0,
		"slope": world.slope_at(world_pos) if world != null else 0.0,
	}

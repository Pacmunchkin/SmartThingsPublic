@tool
class_name TerrainRegion
extends Area2D

## Ground that changes how units move, see and hold, without protecting them.
##
## Terrain and cover are deliberately separate: the marsh slows and hides but
## gives nothing to stand behind, while a dry-stone wall protects without
## affecting the going. A river ford is the interesting case - fast to cross
## relative to the marsh, but it strips cover and morale while you are in it.

enum Elevation {
	MARSH = 0,      ## Below the flood line.
	FLOODPLAIN = 1, ## The valley bottom - the default.
	VILLAGE = 2,    ## A metre or two up; dry ground.
	RISE = 3,       ## The minster mound. Commands the whole valley.
}

enum Hazard {
	NONE = 0,
	EXPOSED = 1,  ## In the open water of the ford: no cover may be claimed here.
	MIRE = 2,     ## Risk of bogging; heavy squads lose formation.
	FIRE = 3,     ## Set by scripted events; damages anything standing in it.
}

@export var region_name: String = ""
## Regions are allowed to overlap - the minster rise sits on top of the village
## ground, the causeway runs across the marsh. Where they do, the highest
## priority wins outright rather than the two being blended or resolved by
## whichever Area2D the physics server reports first.
@export var terrain_priority: int = 0

@export_group("Movement")
## Multiplies squad move speed. Road 1.15, plough 0.85, wood 0.7, marsh 0.4.
@export_range(0.05, 2.0, 0.05) var move_multiplier: float = 1.0
@export var passable_on_foot: bool = true
## Mail-armoured huscarls and hearthweru. False for deep marsh and open water.
@export var passable_when_armoured: bool = true
## Ox-carts and anything else on wheels. Roads, fields and the causeway only.
@export var passable_by_wheeled: bool = false

@export_group("Perception")
## 0 = fully visible, 1 = invisible until adjacent. Woods and reeds hide.
@export_range(0.0, 1.0, 0.05) var concealment: float = 0.0
## Multiplies a squad's own sight radius while it stands here.
@export_range(0.25, 2.0, 0.05) var sight_multiplier: float = 1.0
@export var elevation: Elevation = Elevation.FLOODPLAIN

@export_group("Effects")
@export var hazard: Hazard = Hazard.NONE
## Added to morale regeneration per second. Negative in the ford and the mire.
@export_range(-5.0, 5.0, 0.5) var morale_per_second: float = 0.0
## Higher ground extends missile reach; used as a flat multiplier on range.
@export_range(0.5, 1.5, 0.05) var missile_range_multiplier: float = 1.0


func _ready() -> void:
	add_to_group(&"terrain")


## The region that governs a point, given every region overlapping it.
static func resolve(regions: Array) -> TerrainRegion:
	var best: TerrainRegion = null
	for region in regions:
		if region is TerrainRegion and (best == null or region.terrain_priority > best.terrain_priority):
			best = region
	return best


func allows(is_armoured: bool, is_wheeled: bool) -> bool:
	if is_wheeled:
		return passable_by_wheeled
	if is_armoured:
		return passable_when_armoured
	return passable_on_foot


## Elevation advantage of this region over another, in bands. Feed into the
## ranged-accuracy roll: shooting downhill is easier than shooting up.
func elevation_advantage_over(other: TerrainRegion) -> int:
	if other == null:
		return int(elevation)
	return int(elevation) - int(other.elevation)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var has_shape := false
	for child in get_children():
		if child is CollisionPolygon2D or child is CollisionShape2D:
			has_shape = true
			break
	if not has_shape:
		warnings.append("TerrainRegion needs a CollisionPolygon2D or CollisionShape2D child.")
	if not passable_on_foot and passable_when_armoured:
		warnings.append("Region is impassable on foot but passable when armoured - probably inverted.")
	return warnings

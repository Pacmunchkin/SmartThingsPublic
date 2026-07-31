@tool
class_name CoverVolume
extends Area2D

## A piece of continuous-space cover.
##
## Cover is authored as arbitrary polygon geometry rather than tile flags, so a
## hedgerow, a church wall and an upturned ox-cart can all protect a squad by
## the same rules. Protection is resolved per-shot from the direction the shot
## arrives, which is what makes flanking meaningful: a squad tucked behind the
## churchyard's north wall gains nothing once the Danes come round the lychgate.
##
## World coordinates are pixels; 1 px = 0.1 m (see rts/README.md).

enum CoverClass {
	NONE = 0,   ## Concealment only, if anything. No damage reduction.
	LIGHT = 1,  ## Wattle hut wall, reeds, timber. Falls apart under sustained fire.
	MEDIUM = 2, ## Hedgerow, dry-stone wall, earth bank.
	HEAVY = 3,  ## Mortared stone, ship's hull, deep ditch.
}

## Incoming-damage multiplier for each class when the shot is inside the
## protected arc. Tuned so that heavy cover roughly triples time-to-kill.
const DAMAGE_MULTIPLIER := {
	CoverClass.NONE: 1.0,
	CoverClass.LIGHT: 0.75,
	CoverClass.MEDIUM: 0.55,
	CoverClass.HEAVY: 0.35,
}

## Suppression accrues more slowly behind better cover.
const SUPPRESSION_MULTIPLIER := {
	CoverClass.NONE: 1.0,
	CoverClass.LIGHT: 0.8,
	CoverClass.MEDIUM: 0.6,
	CoverClass.HEAVY: 0.4,
}

@export var cover_class: CoverClass = CoverClass.LIGHT

@export_group("Facing")
## When false the cover protects from every direction (a hedge, a standing
## stone). When true only shots arriving inside the arc below are reduced.
@export var directional: bool = false
## Direction the protected face points, in Godot 2D degrees:
## 0 = east (+X), 90 = south (+Y), 180 = west, 270 = north.
@export_range(0.0, 360.0, 1.0) var protected_facing_deg: float = 270.0
## Total width of the protected arc, centred on protected_facing_deg.
@export_range(0.0, 360.0, 5.0) var protected_arc_deg: float = 180.0

@export_group("Physical")
## Metres. Anything at or above 1.6 m blocks a standing man's line of sight.
@export_range(0.0, 8.0, 0.1) var height_m: float = 1.0
@export var blocks_line_of_sight: bool = false
## Squads that can be ordered inside rather than merely behind (tower, barn).
@export_range(0, 12) var garrison_slots: int = 0

@export_group("Destruction")
@export var destructible: bool = false
@export var integrity: float = 100.0
## Thatch and hulls burn. The mission director's BURN_COVER_GROUP action looks
## for this flag, and burning degrades the volume one class at a time.
@export var flammable: bool = false
## Free-form tag so scripted events can address a set of volumes at once,
## e.g. "village_thatch" or "longships".
@export var group_tag: StringName = &""

signal degraded(new_class: CoverClass)
signal destroyed

var _burning: bool = false
var _max_integrity: float = 100.0


func _ready() -> void:
	_max_integrity = maxf(integrity, 1.0)
	if group_tag != &"":
		add_to_group(group_tag)
	add_to_group(&"cover")


## True when a shot travelling from `from_position` toward this volume lands
## inside the protected arc.
func protects_against(from_position: Vector2) -> bool:
	if not directional:
		return true
	var to_shooter := (from_position - global_position).angle()
	var facing := deg_to_rad(protected_facing_deg)
	return absf(angle_difference(facing, to_shooter)) <= deg_to_rad(protected_arc_deg) * 0.5


## Damage multiplier applied to a shot originating at `from_position`.
func damage_multiplier_from(from_position: Vector2) -> float:
	if not protects_against(from_position):
		return 1.0
	return DAMAGE_MULTIPLIER[cover_class]


func suppression_multiplier_from(from_position: Vector2) -> float:
	if not protects_against(from_position):
		return 1.0
	return SUPPRESSION_MULTIPLIER[cover_class]


## Note this is independent of cover_class: reed beds are CoverClass.NONE but
## still hide what is behind them.
func occludes_sight() -> bool:
	return blocks_line_of_sight


## Returns true if the volume was knocked down a class or removed entirely.
func apply_damage(amount: float) -> bool:
	if not destructible:
		return false
	integrity = maxf(integrity - amount, 0.0)
	var ratio := integrity / _max_integrity
	var target_class: CoverClass = cover_class
	if ratio <= 0.0:
		target_class = CoverClass.NONE
	elif ratio < 0.35:
		target_class = CoverClass.LIGHT if cover_class > CoverClass.LIGHT else CoverClass.NONE
	elif ratio < 0.7 and cover_class == CoverClass.HEAVY:
		target_class = CoverClass.MEDIUM
	if target_class == cover_class:
		return false
	cover_class = target_class
	if cover_class == CoverClass.NONE:
		blocks_line_of_sight = false
		destroyed.emit()
	else:
		degraded.emit(cover_class)
	return true


## Ignite. Burning cover degrades over `seconds_to_ruin` and, while alight,
## denies the position to both sides.
func ignite(seconds_to_ruin: float = 20.0) -> void:
	if _burning or not flammable:
		return
	_burning = true
	destructible = true
	var steps := 20
	var tick := seconds_to_ruin / float(steps)
	var damage_per_tick := _max_integrity / float(steps)
	for _i in steps:
		await get_tree().create_timer(tick).timeout
		if not is_instance_valid(self):
			return
		apply_damage(damage_per_tick)
		if cover_class == CoverClass.NONE:
			return


func is_burning() -> bool:
	return _burning


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var has_shape := false
	for child in get_children():
		if child is CollisionPolygon2D or child is CollisionShape2D:
			has_shape = true
			break
	if not has_shape:
		warnings.append("CoverVolume needs a CollisionPolygon2D or CollisionShape2D child.")
	if directional and protected_arc_deg >= 359.0:
		warnings.append("Directional cover with a 360 deg arc is just omnidirectional cover.")
	if flammable and not destructible and integrity <= 0.0:
		warnings.append("Flammable cover should carry a positive integrity value.")
	return warnings

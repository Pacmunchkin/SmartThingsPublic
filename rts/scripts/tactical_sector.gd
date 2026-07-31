@tool
class_name TacticalSector
extends Area2D

## A territory point. Squad-tactics RTS has no base building, so sectors are
## the whole economy: they gate reinforcement, sight and, in this mission,
## whether the evacuation keeps moving.
##
## Capture is presence-based and contested: an enemy squad inside the volume
## stalls capture rather than reversing it, so a single scout can buy time but
## cannot take ground on its own.

enum Faction { NEUTRAL = 0, SAXON = 1, DANE = 2 }

@export var sector_id: StringName = &""
@export var display_name: String = ""
@export var owner_faction: Faction = Faction.NEUTRAL

@export_group("Capture")
## Seconds of uncontested presence needed to flip the sector.
@export_range(1.0, 120.0, 1.0) var capture_seconds: float = 20.0
## Progress lost per second when nobody is inside. 0 = progress is sticky.
@export_range(0.0, 10.0, 0.5) var decay_per_second: float = 1.0
## Each squad beyond the first adds this fraction to capture speed, capped.
@export_range(0.0, 1.0, 0.05) var extra_squad_bonus: float = 0.25
@export_range(1.0, 4.0, 0.25) var max_capture_speed: float = 2.0
## A sector the mission cannot afford to lose. The director watches these.
@export var mission_critical: bool = false

@export_group("Held effects")
## Squads per minute added to the owner's reinforcement trickle.
@export_range(0.0, 4.0, 0.25) var reinforcement_bonus: float = 0.0
## Extra sight radius, in pixels, granted to the owner across the whole map.
@export_range(0.0, 600.0, 10.0) var sight_bonus_px: float = 0.0
## Multiplies the owner's missile range for squads standing inside.
@export_range(0.5, 1.5, 0.05) var local_missile_multiplier: float = 1.0

signal captured(new_owner: Faction, previous_owner: Faction)
signal contested(is_contested: bool)
signal progress_changed(faction: Faction, ratio: float)

var _progress: float = 0.0
var _progress_faction: Faction = Faction.NEUTRAL
var _was_contested: bool = false
var _occupants: Array[Node2D] = []


func _ready() -> void:
	add_to_group(&"sector")
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_tick_capture(delta)


func _on_body_entered(body: Node2D) -> void:
	if _faction_of(body) != Faction.NEUTRAL and not _occupants.has(body):
		_occupants.append(body)


func _on_body_exited(body: Node2D) -> void:
	_occupants.erase(body)


func _faction_of(body: Node) -> Faction:
	if body == null or not body.has_method(&"get_faction"):
		return Faction.NEUTRAL
	return body.call(&"get_faction") as Faction


func _tick_capture(delta: float) -> void:
	var saxon := 0
	var dane := 0
	for unit in _occupants:
		if not is_instance_valid(unit):
			continue
		# Routing or pinned squads hold no ground.
		if unit.has_method(&"holds_ground") and not unit.call(&"holds_ground"):
			continue
		match _faction_of(unit):
			Faction.SAXON: saxon += 1
			Faction.DANE: dane += 1

	var is_contested := saxon > 0 and dane > 0
	if is_contested != _was_contested:
		_was_contested = is_contested
		contested.emit(is_contested)
	if is_contested:
		return

	var present: Faction = Faction.NEUTRAL
	var count := 0
	if saxon > 0:
		present = Faction.SAXON
		count = saxon
	elif dane > 0:
		present = Faction.DANE
		count = dane

	if present == Faction.NEUTRAL:
		if _progress > 0.0 and decay_per_second > 0.0:
			_set_progress(_progress_faction, maxf(_progress - decay_per_second * delta, 0.0))
		return
	if present == owner_faction:
		# Reinforcing your own ground just clears any enemy inroads.
		if _progress_faction != owner_faction and _progress > 0.0:
			_set_progress(_progress_faction, maxf(_progress - capture_speed(count) * delta, 0.0))
		return

	if present != _progress_faction:
		_progress = 0.0
		_progress_faction = present
	_set_progress(present, _progress + capture_speed(count) * delta)
	if _progress >= capture_seconds:
		_flip_to(present)


func capture_speed(squad_count: int) -> float:
	return minf(1.0 + float(squad_count - 1) * extra_squad_bonus, max_capture_speed)


func _set_progress(faction: Faction, value: float) -> void:
	_progress = clampf(value, 0.0, capture_seconds)
	_progress_faction = faction
	progress_changed.emit(faction, _progress / capture_seconds)


func _flip_to(faction: Faction) -> void:
	var previous := owner_faction
	owner_faction = faction
	_progress = 0.0
	_progress_faction = Faction.NEUTRAL
	captured.emit(faction, previous)


func is_held_by(faction: Faction) -> bool:
	return owner_faction == faction


func capture_ratio() -> float:
	return _progress / capture_seconds


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if String(sector_id).is_empty():
		warnings.append("TacticalSector needs a sector_id; mission data addresses it by that id.")
	var has_shape := false
	for child in get_children():
		if child is CollisionPolygon2D or child is CollisionShape2D:
			has_shape = true
			break
	if not has_shape:
		warnings.append("TacticalSector needs a CollisionPolygon2D or CollisionShape2D child.")
	return warnings

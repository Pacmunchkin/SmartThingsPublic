@tool
class_name TriggerVolume
extends Area2D

## A scripted tripwire. Fires once (or repeatedly) when enough units of the
## right faction have been inside for long enough.
##
## The dwell requirement matters more than it looks: without it, a single
## routing squad brushing the edge of the ford would fire the "the ford is
## breached" beat and spend the mission's best dramatic moment on nothing.

enum Faction { ANY = 0, SAXON = 1, DANE = 2 }

@export var trigger_id: StringName = &""
@export var activating_faction: Faction = Faction.DANE
@export_range(1, 10) var required_units: int = 1
## Seconds the requirement must hold continuously before the trigger fires.
@export_range(0.0, 30.0, 0.5) var dwell_seconds: float = 0.5
@export var one_shot: bool = true
## Only armed while the director is running one of these acts. Empty = always.
@export var active_in_acts: Array[StringName] = []

signal fired(trigger_id: StringName, by_faction: Faction)

var _occupants: Array[Node2D] = []
var _dwell: float = 0.0
var _spent: bool = false
var _armed: bool = true


func _ready() -> void:
	add_to_group(&"trigger")
	if Engine.is_editor_hint():
		return
	body_entered.connect(func(b: Node2D) -> void:
		if not _occupants.has(b):
			_occupants.append(b))
	body_exited.connect(func(b: Node2D) -> void: _occupants.erase(b))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _spent or not _armed:
		return
	var count := 0
	var faction := Faction.ANY
	for unit in _occupants:
		if not is_instance_valid(unit) or not unit.has_method(&"get_faction"):
			continue
		var unit_faction := unit.call(&"get_faction") as int
		if activating_faction != Faction.ANY and unit_faction != int(activating_faction):
			continue
		count += 1
		faction = unit_faction as Faction
	if count < required_units:
		_dwell = 0.0
		return
	_dwell += delta
	if _dwell >= dwell_seconds:
		_dwell = 0.0
		if one_shot:
			_spent = true
		fired.emit(trigger_id, faction)


## Called by the mission director when an act begins.
func set_active_act(act_id: StringName) -> void:
	_armed = active_in_acts.is_empty() or active_in_acts.has(act_id)


## Silence this trigger for the rest of the mission. Used when the player has
## made the beat it guards impossible - burning the longships disarms the
## jarl's escape, rather than leaving a tripwire that can no longer mean
## anything.
func disarm() -> void:
	_spent = true
	_armed = false
	_dwell = 0.0


func reset() -> void:
	_spent = false
	_dwell = 0.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if String(trigger_id).is_empty():
		warnings.append("TriggerVolume needs a trigger_id; scripted events listen for that id.")
	return warnings

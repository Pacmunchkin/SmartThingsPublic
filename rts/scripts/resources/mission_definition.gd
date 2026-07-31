@tool
class_name MissionDefinition
extends Resource

## Everything about a scripted mission that is not geometry. The .tscn holds
## the ground; this holds the argument.

enum Difficulty { CEORL = 0, THEGN = 1, EALDORMAN = 2 }

@export var mission_id: StringName = &""
@export var title: String = ""
@export var subtitle: String = ""
@export_multiline var briefing: String = ""
## Author's note on what is invented and what is attested. Shown on the
## loading screen; keeps the campaign honest about where drama replaces record.
@export_multiline var historical_note: String = ""
@export var level_scene: String = ""

@export_group("Structure")
@export var acts: Array[Resource] = []          ## MissionAct, in order
@export var squad_library: Array[Resource] = [] ## SquadArchetype

@export_group("Failure")
## Units whose death ends the mission immediately.
@export var protected_units: Array[StringName] = []
## Sectors that fail the mission if the enemy holds them past the grace period.
@export var critical_sectors: Array[StringName] = []
@export var critical_sector_grace_seconds: float = 75.0
@export var fail_if_all_squads_lost: bool = true

@export_group("Presentation")
## Play area in world pixels; the camera clamps to this.
@export var play_area: Rect2 = Rect2(0, 0, 2400, 1800)
## Metres per pixel. Every distance in this mission is authored in pixels.
@export var metres_per_pixel: float = 0.1
## Designer's target completion time, in seconds.
@export var par_time_seconds: float = 960.0

@export_group("Difficulty")
## Wave-size multipliers, indexed by Difficulty.
@export var wave_scalars: PackedFloat32Array = PackedFloat32Array([0.75, 1.0, 1.3])
## Enemy damage multipliers, indexed by Difficulty.
@export var damage_scalars: PackedFloat32Array = PackedFloat32Array([0.85, 1.0, 1.15])
## Player reinforcement interval multipliers, indexed by Difficulty.
@export var reinforcement_scalars: PackedFloat32Array = PackedFloat32Array([0.85, 1.0, 1.2])


func get_act(index: int) -> MissionAct:
	if index < 0 or index >= acts.size():
		return null
	return acts[index] as MissionAct


func find_act(id: StringName) -> MissionAct:
	for act in acts:
		if act is MissionAct and act.act_id == id:
			return act
	return null


func find_squad(id: StringName) -> SquadArchetype:
	for squad in squad_library:
		if squad is SquadArchetype and squad.squad_id == id:
			return squad
	return null


func wave_scalar(difficulty: Difficulty) -> float:
	return _scalar(wave_scalars, difficulty)


func damage_scalar(difficulty: Difficulty) -> float:
	return _scalar(damage_scalars, difficulty)


func reinforcement_scalar(difficulty: Difficulty) -> float:
	return _scalar(reinforcement_scalars, difficulty)


func _scalar(table: PackedFloat32Array, difficulty: Difficulty) -> float:
	var index := int(difficulty)
	return table[index] if index < table.size() else 1.0


func metres(pixels: float) -> float:
	return pixels * metres_per_pixel


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if acts.is_empty():
		warnings.append("Mission has no acts.")
	var seen: Dictionary = {}
	for squad in squad_library:
		if squad is SquadArchetype:
			if seen.has(squad.squad_id):
				warnings.append("Duplicate squad_id in library: %s" % squad.squad_id)
			seen[squad.squad_id] = true
	return warnings

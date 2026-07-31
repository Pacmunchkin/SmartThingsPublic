@tool
class_name WaveDefinition
extends Resource

## A scheduled arrival of squads.
##
## Waves are authored as "this much pressure, from here, aimed there" rather
## than as explicit unit lists per difficulty. difficulty_scalar multiplies the
## counts at load time so the three presets share one timeline and the beats
## land at the same moments regardless of difficulty.

enum Trigger {
	ACT_TIME = 0,       ## delay_seconds after the act opens.
	TRIGGER_VOLUME = 1, ## When trigger_id fires.
	SECTOR_LOST = 2,    ## When target_sector changes hands away from the player.
	OBJECTIVE_DONE = 3, ## When objective_id completes.
}

@export var wave_id: StringName = &""
@export var trigger: Trigger = Trigger.ACT_TIME
@export var delay_seconds: float = 0.0
@export var trigger_id: StringName = &""
@export var objective_id: StringName = &""
@export var target_sector: StringName = &""

@export_group("Composition")
## Spawn marker ids; squads are dealt round-robin across them.
@export var spawn_markers: Array[StringName] = []
## Parallel arrays: squad_ids[i] arrives squad_counts[i] times.
@export var squad_ids: Array[StringName] = []
@export var squad_counts: Array[int] = []
## Multiplied into squad_counts by the difficulty preset. Authored at 1.0.
@export_range(0.25, 2.5, 0.05) var difficulty_scalar: float = 1.0

@export_group("Orders")
## Sector the wave moves to attack. Empty = hold near the spawn.
@export var order_sector: StringName = &""
@export var stance: SpawnMarker.Stance = SpawnMarker.Stance.ASSAULT
## Seconds between individual squads arriving, so a wave trickles rather than
## popping into existence all at once.
@export_range(0.0, 30.0, 0.5) var stagger_seconds: float = 2.0

@export_group("Repetition")
## 0 = one-off. Otherwise the wave repeats on this interval until the act ends.
@export var repeat_interval: float = 0.0
@export var max_repeats: int = 0

@export_group("Presentation")
## Shown as a warning banner this many seconds before the wave lands. 0 = none.
@export var telegraph_seconds: float = 0.0
@export_multiline var telegraph_text: String = ""


## Total squads in one firing of this wave, after difficulty scaling.
func squad_total(scalar: float = 1.0) -> int:
	var total := 0
	for count in squad_counts:
		total += _scaled(count, scalar)
	return total


## Expanded list of squad ids for one firing.
func build_roster(scalar: float = 1.0) -> Array[StringName]:
	var roster: Array[StringName] = []
	for i in mini(squad_ids.size(), squad_counts.size()):
		for _n in _scaled(squad_counts[i], scalar):
			roster.append(squad_ids[i])
	return roster


func _scaled(count: int, scalar: float) -> int:
	# Round to nearest but never scale a present squad down to nothing: a wave
	# authored with one berserkir should still bring one on the easy preset.
	var scaled := int(round(float(count) * difficulty_scalar * scalar))
	return maxi(scaled, 1) if count > 0 else 0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if squad_ids.size() != squad_counts.size():
		warnings.append("squad_ids and squad_counts must be the same length.")
	if spawn_markers.is_empty():
		warnings.append("Wave has no spawn markers.")
	if trigger == Trigger.TRIGGER_VOLUME and String(trigger_id).is_empty():
		warnings.append("Wave triggers on a volume but names no trigger_id.")
	return warnings

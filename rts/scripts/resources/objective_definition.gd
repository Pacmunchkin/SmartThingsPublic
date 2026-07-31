@tool
class_name ObjectiveDefinition
extends Resource

## One line in the objectives panel, and the rule behind it.

enum Kind {
	HOLD_SECTOR = 0,    ## Own target_sector for duration_seconds, cumulative.
	CAPTURE_SECTOR = 1, ## Own target_sector at all, once.
	SURVIVE_TIME = 2,   ## Stay alive for duration_seconds.
	ESCORT = 3,         ## Bring target_unit to target_marker.
	PROTECT_UNIT = 4,   ## target_unit must not die.
	KILL_TARGET = 5,    ## target_unit must die.
	DESTROY_OBJECTS = 6,## Destroy required_count cover volumes tagged target_group.
	PRESERVE_OBJECTS = 7,## Keep at least required_count of target_group standing.
}

enum Priority {
	PRIMARY = 0,   ## Failing it fails the mission.
	SECONDARY = 1, ## Shapes the next act but is survivable.
	BONUS = 2,     ## Campaign carry-over only.
}

@export var objective_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.HOLD_SECTOR
@export var priority: Priority = Priority.PRIMARY

@export_group("Target")
@export var target_sector: StringName = &""
@export var target_unit: StringName = &""
@export var target_marker: StringName = &""
@export var target_group: StringName = &""
@export var required_count: int = 1

@export_group("Timing")
@export var duration_seconds: float = 0.0
## Seconds of enemy control tolerated before a HOLD_SECTOR objective fails.
## 0 means losing the sector for an instant fails it.
@export var grace_seconds: float = 0.0
## Hidden from the player until revealed by a scripted event.
@export var starts_hidden: bool = false

@export_group("Consequences")
## Applied to the next act's wave sizes when this objective is completed.
## 0.85 means the player earned a 15% lighter next wave.
@export_range(0.5, 1.5, 0.05) var completion_wave_scalar: float = 1.0
## Free-form flag written to the campaign state on completion.
@export var sets_campaign_flag: StringName = &""


func is_failure_condition() -> bool:
	return priority == Priority.PRIMARY

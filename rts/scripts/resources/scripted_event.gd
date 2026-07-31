@tool
class_name ScriptedEvent
extends Resource

## A "when X, do Y" rule. The director owns the whole timeline as a list of
## these, which keeps the mission's dramatic beats in data rather than in a
## per-mission script file - the level designer can move the mist, the fire
## arrows and the jarl's arrival without touching code.

enum When {
	ACT_TIME = 0,        ## delay_seconds after the act opens.
	TRIGGER_VOLUME = 1,  ## A TriggerVolume with trigger_id fired.
	SECTOR_CAPTURED = 2, ## target_sector flipped to by_faction.
	OBJECTIVE_DONE = 3,
	OBJECTIVE_FAILED = 4,
	UNIT_KILLED = 5,     ## target_unit died.
	UNIT_HEALTH_BELOW = 6, ## target_unit dropped under health_fraction.
	CHAINED_ONLY = 7,    ## Never fires on its own; only via chained_event_ids.
}

enum Action {
	PLAY_LINE = 0,        ## Dialogue / banner. Uses text and speaker.
	SPAWN_WAVE = 1,       ## Fires wave_id immediately.
	BURN_COVER_GROUP = 2, ## Ignites count volumes tagged cover_group.
	SET_WEATHER = 3,      ## weather_id + duration_seconds.
	REVEAL_AREA = 4,      ## Grants vision at target_marker for duration_seconds.
	REVEAL_OBJECTIVE = 5, ## Un-hides a hidden objective.
	ADVANCE_ACT = 6,
	MODIFY_SECTOR = 7,    ## Force-sets a sector's owner (scripted losses).
	SET_UNIT_STANCE = 8,  ## e.g. the jarl breaking for the ships.
	END_MISSION = 9,      ## outcome: 0 fail, 1 partial, 2 success.
	DISARM_TRIGGER = 10,  ## Permanently silences the TriggerVolume trigger_id.
}

@export var event_id: StringName = &""

@export_group("Condition")
@export var when: When = When.ACT_TIME
@export var delay_seconds: float = 0.0
@export var trigger_id: StringName = &""
@export var target_sector: StringName = &""
@export var target_unit: StringName = &""
@export var objective_id: StringName = &""
@export_range(0.0, 1.0, 0.05) var health_fraction: float = 0.4
@export var by_faction: TacticalSector.Faction = TacticalSector.Faction.DANE
@export var one_shot: bool = true

@export_group("Action")
@export var action: Action = Action.PLAY_LINE
@export var wave_id: StringName = &""
@export var cover_group: StringName = &""
@export var target_marker: StringName = &""
@export var weather_id: StringName = &""
@export var new_stance: SpawnMarker.Stance = SpawnMarker.Stance.ADVANCE
@export var new_owner: TacticalSector.Faction = TacticalSector.Faction.DANE
@export var outcome: int = 2
@export var count: int = 1
@export var duration_seconds: float = 0.0

@export_group("Presentation")
@export var speaker: String = ""
@export_multiline var text: String = ""
## Extra events fired immediately after this one, for compound beats.
@export var chained_event_ids: Array[StringName] = []

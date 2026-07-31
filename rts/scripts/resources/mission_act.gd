@tool
class_name MissionAct
extends Resource

## One phase of a scripted mission. Each act has its own objectives, its own
## wave timeline and its own advance condition, so the mission reads as three
## short problems rather than one long one.

enum Advance {
	OBJECTIVE_DONE = 0, ## advance_objective completed.
	TIME_ELAPSED = 1,   ## advance_seconds since the act opened.
	SECTOR_HELD = 2,    ## advance_sector owned by the player at advance_seconds.
	TRIGGER = 3,        ## advance_trigger fired.
	SCRIPTED = 4,       ## Only an ADVANCE_ACT event ends this act.
}

@export var act_id: StringName = &""
@export var title: String = ""
@export_multiline var briefing: String = ""
## Shown when the act closes successfully.
@export_multiline var outro: String = ""

@export_group("Content")
@export var objectives: Array[Resource] = []       ## ObjectiveDefinition
@export var waves: Array[Resource] = []            ## WaveDefinition
@export var scripted_events: Array[Resource] = []  ## ScriptedEvent
## Spawn markers whose squads are placed the moment the act opens.
@export var deploy_spawn_markers: Array[StringName] = []

@export_group("Advance")
@export var advance: Advance = Advance.OBJECTIVE_DONE
@export var advance_objective: StringName = &""
@export var advance_sector: StringName = &""
@export var advance_trigger: StringName = &""
@export var advance_seconds: float = 0.0

@export_group("Reinforcement")
## Player squads trickling in during this act. 0 = none.
@export var reinforcement_interval: float = 0.0
@export var reinforcement_squad_id: StringName = &""
@export var reinforcement_marker: StringName = &""
## Sectors that speed the trickle up, via their reinforcement_bonus.
@export var reinforcement_sectors: Array[StringName] = []
@export var reinforcement_cap: int = 0


func find_objective(id: StringName) -> ObjectiveDefinition:
	for objective in objectives:
		if objective is ObjectiveDefinition and objective.objective_id == id:
			return objective
	return null


func find_wave(id: StringName) -> WaveDefinition:
	for wave in waves:
		if wave is WaveDefinition and wave.wave_id == id:
			return wave
	return null


func find_event(id: StringName) -> ScriptedEvent:
	for event in scripted_events:
		if event is ScriptedEvent and event.event_id == id:
			return event
	return null

class_name MissionDirector
extends Node

## Runs a scripted mission: opens acts, schedules waves, fires the timeline of
## dramatic beats and judges the objectives.
##
## The director deliberately does not know how to build a squad. It resolves a
## SquadArchetype and a world position, then hands both to `squad_spawner` (any
## node with `spawn_squad(archetype, position, facing_deg, stance, order_sector)`
## returning a Node2D) or, failing that, just emits `squad_requested`. That lets
## the whole mission be authored, loaded and dry-run before a single unit
## exists - which is how this level was built.

enum State { PENDING = 0, ACTIVE = 1, COMPLETE = 2, FAILED = 3 }
enum Outcome { FAILURE = 0, PARTIAL = 1, SUCCESS = 2 }

signal act_started(act: MissionAct, index: int)
signal act_finished(act: MissionAct, index: int)
signal objective_state_changed(objective: ObjectiveDefinition, state: State)
signal squad_requested(archetype: SquadArchetype, position: Vector2, facing_deg: float, stance: SpawnMarker.Stance, order_sector: StringName)
signal line_played(speaker: String, text: String)
signal weather_changed(weather_id: StringName, duration: float)
signal mission_ended(outcome: Outcome)

@export var mission: MissionDefinition
@export var difficulty: MissionDefinition.Difficulty = MissionDefinition.Difficulty.THEGN
@export var squad_spawner: Node
## Start paused so a briefing screen can call `begin()` when it is dismissed.
@export var autostart: bool = true

var _act_index: int = -1
var _act: MissionAct
var _act_time: float = 0.0
var _running: bool = false
var _ended: bool = false

var _sectors: Dictionary = {}   ## StringName -> TacticalSector
var _markers: Dictionary = {}   ## StringName -> SpawnMarker
var _triggers: Dictionary = {}  ## StringName -> TriggerVolume
var _units: Dictionary = {}     ## StringName -> Node2D (named/tracked units only)

var _objective_state: Dictionary = {}  ## StringName -> Dictionary
var _pending_waves: Array[Dictionary] = []
var _fired_events: Dictionary = {}
var _wave_repeats: Dictionary = {}
var _reinforcement_timer: float = 0.0
var _reinforcements_sent: int = 0
## Multiplies the next act's waves; earned by completing optional objectives.
var _carried_wave_scalar: float = 1.0


func _ready() -> void:
	if mission == null:
		push_error("MissionDirector has no MissionDefinition.")
		set_process(false)
		return
	_index_scene()
	if autostart:
		begin()


func _index_scene() -> void:
	var root := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	for node in get_tree().get_nodes_in_group(&"sector"):
		if node is TacticalSector:
			_sectors[node.sector_id] = node
			node.captured.connect(_on_sector_captured.bind(node))
	for node in get_tree().get_nodes_in_group(&"spawn"):
		if node is SpawnMarker:
			_markers[node.spawn_id] = node
	for node in get_tree().get_nodes_in_group(&"trigger"):
		if node is TriggerVolume:
			_triggers[node.trigger_id] = node
			node.fired.connect(_on_trigger_fired)
	if root == null:
		push_warning("MissionDirector could not resolve a scene root; using group lookups only.")


func begin() -> void:
	_running = true
	_ended = false
	_carried_wave_scalar = 1.0
	_advance_to_act(0)


func _process(delta: float) -> void:
	if not _running or _ended or _act == null:
		return
	_act_time += delta
	_process_waves(delta)
	_process_events()
	_process_objectives(delta)
	_process_reinforcements(delta)
	_check_mission_failure(delta)
	_check_act_advance()


# --- Acts ---------------------------------------------------------------

func _advance_to_act(index: int) -> void:
	if _act != null:
		act_finished.emit(_act, _act_index)
		if not _act.outro.is_empty():
			line_played.emit("", _act.outro)
	if index >= mission.acts.size():
		_end_mission(Outcome.SUCCESS)
		return

	_act_index = index
	_act = mission.get_act(index)
	if _act == null:
		_end_mission(Outcome.SUCCESS)
		return

	_act_time = 0.0
	_pending_waves.clear()
	_fired_events.clear()
	_wave_repeats.clear()
	_reinforcement_timer = 0.0
	_reinforcements_sent = 0

	for trigger: TriggerVolume in _triggers.values():
		trigger.set_active_act(_act.act_id)

	for objective in _act.objectives:
		if objective is ObjectiveDefinition:
			_objective_state[objective.objective_id] = {
				"objective": objective,
				"state": State.ACTIVE,
				"elapsed": 0.0,
				"enemy_hold": 0.0,
			}
			objective_state_changed.emit(objective, State.ACTIVE)

	for marker_id in _act.deploy_spawn_markers:
		_deploy_marker(marker_id)

	for wave in _act.waves:
		if wave is WaveDefinition and wave.trigger == WaveDefinition.Trigger.ACT_TIME:
			_schedule_wave(wave, wave.delay_seconds)

	act_started.emit(_act, _act_index)
	if not _act.briefing.is_empty():
		line_played.emit("", _act.briefing)


func _check_act_advance() -> void:
	if _act == null:
		return
	var ready := false
	match _act.advance:
		MissionAct.Advance.OBJECTIVE_DONE:
			ready = _objective_is(_act.advance_objective, State.COMPLETE)
		MissionAct.Advance.TIME_ELAPSED:
			ready = _act_time >= _act.advance_seconds
		MissionAct.Advance.SECTOR_HELD:
			var sector: TacticalSector = _sectors.get(_act.advance_sector)
			ready = _act_time >= _act.advance_seconds and sector != null \
				and sector.is_held_by(TacticalSector.Faction.SAXON)
		MissionAct.Advance.TRIGGER, MissionAct.Advance.SCRIPTED:
			ready = false  # Driven by an ADVANCE_ACT event or _on_trigger_fired.
	if ready:
		_advance_to_act(_act_index + 1)


# --- Waves --------------------------------------------------------------

func _schedule_wave(wave: WaveDefinition, delay: float) -> void:
	if wave.telegraph_seconds > 0.0 and not wave.telegraph_text.is_empty():
		_pending_waves.append({
			"wave": wave,
			"at": _act_time + maxf(delay - wave.telegraph_seconds, 0.0),
			"telegraph": true,
		})
	_pending_waves.append({"wave": wave, "at": _act_time + delay, "telegraph": false})


func _process_waves(_delta: float) -> void:
	var due: Array[Dictionary] = []
	for entry in _pending_waves:
		if _act_time >= entry["at"]:
			due.append(entry)
	for entry in due:
		_pending_waves.erase(entry)
		var wave: WaveDefinition = entry["wave"]
		if entry["telegraph"]:
			line_played.emit("", wave.telegraph_text)
			continue
		_fire_wave(wave)
		if wave.repeat_interval > 0.0:
			var fired := int(_wave_repeats.get(wave.wave_id, 0)) + 1
			_wave_repeats[wave.wave_id] = fired
			if wave.max_repeats <= 0 or fired < wave.max_repeats:
				_schedule_wave(wave, wave.repeat_interval)


func _fire_wave(wave: WaveDefinition) -> void:
	var scalar := mission.wave_scalar(difficulty) * _carried_wave_scalar
	var roster := wave.build_roster(scalar)
	if roster.is_empty() or wave.spawn_markers.is_empty():
		return
	for i in roster.size():
		var marker_id: StringName = wave.spawn_markers[i % wave.spawn_markers.size()]
		var marker: SpawnMarker = _markers.get(marker_id)
		if marker == null:
			push_warning("Wave %s references unknown spawn marker %s" % [wave.wave_id, marker_id])
			continue
		var archetype := mission.find_squad(roster[i])
		if archetype == null:
			push_warning("Wave %s references unknown squad %s" % [wave.wave_id, roster[i]])
			continue
		var order: StringName = wave.order_sector if wave.order_sector != &"" else marker.default_order_target
		var delay := float(i) * wave.stagger_seconds
		if delay > 0.0:
			_spawn_later(archetype, marker, i, wave.stance, order, delay)
		else:
			_spawn(archetype, marker, i, wave.stance, order)


func _spawn_later(archetype: SquadArchetype, marker: SpawnMarker, index: int,
		stance: SpawnMarker.Stance, order: StringName, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if _ended or not is_instance_valid(marker):
		return
	_spawn(archetype, marker, index, stance, order)


func _spawn(archetype: SquadArchetype, marker: SpawnMarker, index: int,
		stance: SpawnMarker.Stance, order: StringName) -> Node2D:
	var position := marker.position_for_index(index)
	squad_requested.emit(archetype, position, marker.facing_deg, stance, order)
	if squad_spawner == null or not squad_spawner.has_method(&"spawn_squad"):
		return null
	var unit: Node2D = squad_spawner.call(&"spawn_squad", archetype, position,
		marker.facing_deg, stance, order)
	if unit != null and archetype.role == SquadArchetype.Role.HERO:
		_units[archetype.squad_id] = unit
	elif unit != null and archetype.role == SquadArchetype.Role.OBJECT:
		_units[archetype.squad_id] = unit
	return unit


func _deploy_marker(marker_id: StringName) -> void:
	var marker: SpawnMarker = _markers.get(marker_id)
	if marker == null:
		push_warning("Act %s deploys unknown marker %s" % [_act.act_id, marker_id])
		return
	if marker.is_navigation_target_only():
		return
	var archetype := mission.find_squad(marker.squad_id)
	if archetype == null:
		push_warning("Marker %s references unknown squad %s" % [marker_id, marker.squad_id])
		return
	_spawn(archetype, marker, 0, marker.stance, marker.default_order_target)


# --- Reinforcements -----------------------------------------------------

func _process_reinforcements(delta: float) -> void:
	if _act == null or _act.reinforcement_interval <= 0.0:
		return
	if _act.reinforcement_cap > 0 and _reinforcements_sent >= _act.reinforcement_cap:
		return
	# Sectors held speed the trickle rather than granting a lump sum, so losing
	# the drove road is felt as a thinning stream, not a sudden cliff.
	var rate := 1.0
	for sector_id in _act.reinforcement_sectors:
		var sector: TacticalSector = _sectors.get(sector_id)
		if sector != null and sector.is_held_by(TacticalSector.Faction.SAXON):
			rate += sector.reinforcement_bonus
	var interval := _act.reinforcement_interval * mission.reinforcement_scalar(difficulty) / rate
	_reinforcement_timer += delta
	if _reinforcement_timer < interval:
		return
	_reinforcement_timer = 0.0
	var marker: SpawnMarker = _markers.get(_act.reinforcement_marker)
	var archetype := mission.find_squad(_act.reinforcement_squad_id)
	if marker == null or archetype == null:
		return
	_reinforcements_sent += 1
	_spawn(archetype, marker, _reinforcements_sent, marker.stance, marker.default_order_target)


# --- Objectives ---------------------------------------------------------

func _process_objectives(delta: float) -> void:
	for id: StringName in _objective_state.keys():
		var entry: Dictionary = _objective_state[id]
		if entry["state"] != State.ACTIVE:
			continue
		var objective: ObjectiveDefinition = entry["objective"]
		match objective.kind:
			ObjectiveDefinition.Kind.HOLD_SECTOR:
				_tick_hold(entry, objective, delta)
			ObjectiveDefinition.Kind.SURVIVE_TIME:
				entry["elapsed"] += delta
				if entry["elapsed"] >= objective.duration_seconds:
					_set_objective(id, State.COMPLETE)
			ObjectiveDefinition.Kind.CAPTURE_SECTOR:
				var sector: TacticalSector = _sectors.get(objective.target_sector)
				if sector != null and sector.is_held_by(TacticalSector.Faction.SAXON):
					_set_objective(id, State.COMPLETE)
			ObjectiveDefinition.Kind.PROTECT_UNIT:
				if _unit_is_dead(objective.target_unit):
					_set_objective(id, State.FAILED)
			ObjectiveDefinition.Kind.KILL_TARGET:
				if _unit_is_dead(objective.target_unit):
					_set_objective(id, State.COMPLETE)
			ObjectiveDefinition.Kind.ESCORT:
				_tick_escort(id, objective)
			ObjectiveDefinition.Kind.DESTROY_OBJECTS:
				if _cover_standing(objective.target_group) <= \
						_cover_total(objective.target_group) - objective.required_count:
					_set_objective(id, State.COMPLETE)
			ObjectiveDefinition.Kind.PRESERVE_OBJECTS:
				# Judged when the act closes; failure is only certain at the end.
				if _cover_standing(objective.target_group) < objective.required_count:
					_set_objective(id, State.FAILED)


func _tick_hold(entry: Dictionary, objective: ObjectiveDefinition, delta: float) -> void:
	var sector: TacticalSector = _sectors.get(objective.target_sector)
	if sector == null:
		return
	if sector.is_held_by(TacticalSector.Faction.SAXON):
		entry["enemy_hold"] = 0.0
		entry["elapsed"] += delta
		if objective.duration_seconds > 0.0 and entry["elapsed"] >= objective.duration_seconds:
			_set_objective(objective.objective_id, State.COMPLETE)
	elif sector.is_held_by(TacticalSector.Faction.DANE):
		entry["enemy_hold"] += delta
		if entry["enemy_hold"] > objective.grace_seconds:
			_set_objective(objective.objective_id, State.FAILED)


func _tick_escort(id: StringName, objective: ObjectiveDefinition) -> void:
	var unit: Node2D = _units.get(objective.target_unit)
	var marker: SpawnMarker = _markers.get(objective.target_marker)
	if unit == null or marker == null:
		return
	if not is_instance_valid(unit):
		_set_objective(id, State.FAILED)
		return
	if unit.global_position.distance_to(marker.global_position) <= maxf(marker.scatter_px, 40.0):
		_set_objective(id, State.COMPLETE)


func _set_objective(id: StringName, state: State) -> void:
	var entry: Dictionary = _objective_state.get(id, {})
	if entry.is_empty() or entry["state"] == state:
		return
	entry["state"] = state
	var objective: ObjectiveDefinition = entry["objective"]
	objective_state_changed.emit(objective, state)

	if state == State.COMPLETE:
		if objective.completion_wave_scalar != 1.0:
			_carried_wave_scalar *= objective.completion_wave_scalar
		_fire_events_for(ScriptedEvent.When.OBJECTIVE_DONE, {"objective": id})
		_fire_waves_for(WaveDefinition.Trigger.OBJECTIVE_DONE, id)
	elif state == State.FAILED:
		_fire_events_for(ScriptedEvent.When.OBJECTIVE_FAILED, {"objective": id})
		if objective.is_failure_condition():
			_end_mission(Outcome.FAILURE)


func _objective_is(id: StringName, state: State) -> bool:
	var entry: Dictionary = _objective_state.get(id, {})
	return not entry.is_empty() and entry["state"] == state


# --- Scripted events ----------------------------------------------------

func _process_events() -> void:
	if _act == null:
		return
	for event in _act.scripted_events:
		if event is ScriptedEvent and event.when == ScriptedEvent.When.ACT_TIME \
				and not _fired_events.has(event.event_id) and _act_time >= event.delay_seconds:
			_run_event(event)


func _fire_events_for(when: ScriptedEvent.When, context: Dictionary) -> void:
	if _act == null:
		return
	for event in _act.scripted_events:
		if not (event is ScriptedEvent) or event.when != when:
			continue
		if event.one_shot and _fired_events.has(event.event_id):
			continue
		match when:
			ScriptedEvent.When.TRIGGER_VOLUME:
				if event.trigger_id != context.get("trigger"):
					continue
			ScriptedEvent.When.SECTOR_CAPTURED:
				if event.target_sector != context.get("sector") \
						or int(event.by_faction) != int(context.get("faction", -1)):
					continue
			ScriptedEvent.When.OBJECTIVE_DONE, ScriptedEvent.When.OBJECTIVE_FAILED:
				if event.objective_id != context.get("objective"):
					continue
			ScriptedEvent.When.UNIT_KILLED, ScriptedEvent.When.UNIT_HEALTH_BELOW:
				if event.target_unit != context.get("unit"):
					continue
			_:
				continue
		_run_event(event)


func _run_event(event: ScriptedEvent) -> void:
	_fired_events[event.event_id] = true
	match event.action:
		ScriptedEvent.Action.PLAY_LINE:
			line_played.emit(event.speaker, event.text)
		ScriptedEvent.Action.SPAWN_WAVE:
			var wave := _act.find_wave(event.wave_id)
			if wave != null:
				_fire_wave(wave)
		ScriptedEvent.Action.BURN_COVER_GROUP:
			_burn_cover(event.cover_group, event.count, maxf(event.duration_seconds, 20.0))
		ScriptedEvent.Action.SET_WEATHER:
			weather_changed.emit(event.weather_id, event.duration_seconds)
		ScriptedEvent.Action.REVEAL_AREA:
			var marker: SpawnMarker = _markers.get(event.target_marker)
			if marker != null:
				squad_requested.emit(null, marker.global_position, 0.0,
					SpawnMarker.Stance.HOLD, &"reveal")
		ScriptedEvent.Action.REVEAL_OBJECTIVE:
			var entry: Dictionary = _objective_state.get(event.objective_id, {})
			if not entry.is_empty():
				entry["objective"].starts_hidden = false
				objective_state_changed.emit(entry["objective"], entry["state"])
		ScriptedEvent.Action.ADVANCE_ACT:
			_advance_to_act(_act_index + 1)
			return  # The old act's chained events are no longer meaningful.
		ScriptedEvent.Action.MODIFY_SECTOR:
			var sector: TacticalSector = _sectors.get(event.target_sector)
			if sector != null:
				sector.owner_faction = event.new_owner
				sector.captured.emit(event.new_owner, TacticalSector.Faction.NEUTRAL)
		ScriptedEvent.Action.SET_UNIT_STANCE:
			var unit: Node2D = _units.get(event.target_unit)
			if unit != null and unit.has_method(&"set_stance"):
				unit.call(&"set_stance", event.new_stance)
		ScriptedEvent.Action.END_MISSION:
			_end_mission(event.outcome as Outcome)
			return
		ScriptedEvent.Action.DISARM_TRIGGER:
			var volume: TriggerVolume = _triggers.get(event.trigger_id)
			if volume != null:
				volume.disarm()

	for chained_id in event.chained_event_ids:
		var chained := _act.find_event(chained_id)
		if chained != null and not _fired_events.has(chained_id):
			_run_event(chained)


func _burn_cover(group: StringName, count: int, seconds: float) -> void:
	var candidates: Array[CoverVolume] = []
	for node in get_tree().get_nodes_in_group(group):
		if node is CoverVolume and node.flammable and not node.is_burning():
			candidates.append(node)
	candidates.shuffle()
	for i in mini(count, candidates.size()):
		candidates[i].ignite(seconds)


# --- Signals in --------------------------------------------------------

func _on_trigger_fired(trigger_id: StringName, _faction: int) -> void:
	if _act == null:
		return
	_fire_events_for(ScriptedEvent.When.TRIGGER_VOLUME, {"trigger": trigger_id})
	_fire_waves_for(WaveDefinition.Trigger.TRIGGER_VOLUME, trigger_id)
	if _act.advance == MissionAct.Advance.TRIGGER and _act.advance_trigger == trigger_id:
		_advance_to_act(_act_index + 1)


func _on_sector_captured(new_owner: TacticalSector.Faction,
		_previous: TacticalSector.Faction, sector: TacticalSector) -> void:
	_fire_events_for(ScriptedEvent.When.SECTOR_CAPTURED,
		{"sector": sector.sector_id, "faction": int(new_owner)})
	if new_owner != TacticalSector.Faction.SAXON:
		_fire_waves_for(WaveDefinition.Trigger.SECTOR_LOST, sector.sector_id)


func _fire_waves_for(trigger: WaveDefinition.Trigger, key: StringName) -> void:
	if _act == null:
		return
	for wave in _act.waves:
		if not (wave is WaveDefinition) or wave.trigger != trigger:
			continue
		var matches := false
		match trigger:
			WaveDefinition.Trigger.TRIGGER_VOLUME: matches = wave.trigger_id == key
			WaveDefinition.Trigger.SECTOR_LOST: matches = wave.target_sector == key
			WaveDefinition.Trigger.OBJECTIVE_DONE: matches = wave.objective_id == key
			_: matches = false
		if matches:
			_schedule_wave(wave, wave.delay_seconds)


## Call from the unit layer when a tracked unit dies.
func report_unit_killed(unit_id: StringName) -> void:
	_units.erase(unit_id)
	_fire_events_for(ScriptedEvent.When.UNIT_KILLED, {"unit": unit_id})
	if mission.protected_units.has(unit_id):
		_end_mission(Outcome.FAILURE)


## Call from the unit layer when a tracked unit crosses a health threshold.
func report_unit_health(unit_id: StringName, health_fraction: float) -> void:
	if _act == null:
		return
	for event in _act.scripted_events:
		if event is ScriptedEvent and event.when == ScriptedEvent.When.UNIT_HEALTH_BELOW \
				and event.target_unit == unit_id and health_fraction <= event.health_fraction \
				and not _fired_events.has(event.event_id):
			_run_event(event)


# --- Failure ------------------------------------------------------------

func _check_mission_failure(delta: float) -> void:
	for sector_id in mission.critical_sectors:
		var sector: TacticalSector = _sectors.get(sector_id)
		if sector == null:
			continue
		var key := "crit_%s" % sector_id
		if sector.is_held_by(TacticalSector.Faction.DANE):
			var held := float(_objective_state.get(key, {}).get("enemy_hold", 0.0)) + delta
			_objective_state[key] = {"objective": null, "state": State.ACTIVE,
				"elapsed": 0.0, "enemy_hold": held}
			if held >= mission.critical_sector_grace_seconds:
				_end_mission(Outcome.FAILURE)
				return
		else:
			_objective_state.erase(key)


func _end_mission(outcome: Outcome) -> void:
	if _ended:
		return
	_ended = true
	_running = false
	mission_ended.emit(outcome)


# --- Helpers ------------------------------------------------------------

func _unit_is_dead(unit_id: StringName) -> bool:
	if not _units.has(unit_id):
		return false  # Never spawned; not the same as killed.
	return not is_instance_valid(_units[unit_id])


func _cover_standing(group: StringName) -> int:
	var standing := 0
	for node in get_tree().get_nodes_in_group(group):
		if node is CoverVolume and node.cover_class != CoverVolume.CoverClass.NONE:
			standing += 1
	return standing


func _cover_total(group: StringName) -> int:
	return get_tree().get_nodes_in_group(group).size()


func current_act() -> MissionAct:
	return _act


func act_elapsed() -> float:
	return _act_time

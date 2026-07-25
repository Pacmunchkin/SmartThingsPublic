# =============================================================================
# SCENE ARCHITECTURE — village.tscn
#
# Village (Node2D)                 <- attach this script (village.gd) here
# └── Garrison (Node2D)            <- plain Node2D; drop recruit.tscn
#     ├── Recruit (recruit.tscn)      instances in here, positioned where
#     ├── Recruit (recruit.tscn)      they should stand guard. Each one
#     └── ...                         gets this village's team and adds +1
#                                     to garrison_size.
#
# INSPECTOR SETUP: drag recruit.tscn into "Recruit Scene" so the village
# can produce recruits.
#
# GARRISON: garrison recruits hold the position they were placed at and
# fight any enemy-team combatant that comes within their aggro_range
# (see recruit.gd). Survivors walk back to their posts afterwards.
#
# PRODUCTION: every village produces from scene start — one recruit every
# production_interval seconds, spawned at the Garrison node — until the
# garrison holds max_garrison recruits. Production pauses while full and
# resumes when there is room again.
#
# CONQUEST: when the garrison is wiped out and a warlord of another team
# is within warlord_range, the village flips to that warlord's team and
# production continues for the new owner.
#
# MUSTERING: whenever a same-team warlord is within warlord_range, garrison
# recruits (including freshly produced ones) transfer into that warlord's
# retinue until the retinue is full (warlord.max_retinue). If no friendly
# warlord is near, recruits loiter at the garrison — and guard the
# village — until one returns.
#
# Instance village.tscn into main.tscn wherever a village belongs.
# Set "Team" in the Inspector per village (player warlords default to 0).
#
# Planned (not yet implemented): buildings, watchtowers, fortifications.
# =============================================================================

extends Node2D
class_name Village

# Recruits only fight recruits on a different team.
@export var team: int = 1

# Drag recruit.tscn here; needed for production.
@export var recruit_scene: PackedScene

# Seconds between produced recruits.
@export var production_interval: float = 10.0

# Production pauses while the garrison holds this many recruits.
@export var max_garrison: int = 25

# "The warlord is at the village" distance, used for both conquest and
# mustering garrison recruits into a retinue.
@export var warlord_range: float = 250.0

# +1 per recruit in the Garrison node, -1 when one dies or joins a retinue.
var garrison_size: int = 0

var _production_timer: float = 0.0

@onready var _garrison: Node2D = $Garrison

func _ready() -> void:
	add_to_group("villages")
	_production_timer = production_interval
	for child in _garrison.get_children():
		if child is Recruit:
			_enroll(child)

func _physics_process(delta: float) -> void:
	_try_capture()
	_produce(delta)
	_muster()

# --- Garrison bookkeeping ---------------------------------------------------

func _enroll(recruit: Recruit) -> void:
	recruit.team = team
	recruit.died.connect(_on_recruit_died)
	garrison_size += 1

func _on_recruit_died(_recruit: Combatant) -> void:
	garrison_size -= 1

# --- Conquest ---------------------------------------------------------------

# Garrison dead + enemy warlord at the village = the village changes hands.
func _try_capture() -> void:
	if garrison_size > 0:
		return
	var conqueror := _nearest_warlord_in_range(false)
	if conqueror == null:
		return
	team = conqueror.team
	conqueror.add_renown(1.0)  # a village taken is a deed of renown

# --- Production -------------------------------------------------------------

func _produce(delta: float) -> void:
	if recruit_scene == null or garrison_size >= max_garrison:
		return
	_production_timer -= delta
	if _production_timer <= 0.0:
		_production_timer += production_interval
		_spawn_recruit()

func _spawn_recruit() -> void:
	var recruit := recruit_scene.instantiate() as Recruit
	if recruit == null:
		return
	recruit.position = Vector2.ZERO  # at the Garrison node
	recruit.team = team
	_garrison.add_child(recruit)
	_enroll(recruit)

# --- Mustering --------------------------------------------------------------

# A friendly warlord within warlord_range collects the garrison, up to
# its retinue cap.
func _muster() -> void:
	if garrison_size == 0:
		return
	var warlord := _nearest_warlord_in_range(true)
	if warlord == null:
		return
	for child in _garrison.get_children():
		if warlord.army_size >= warlord.max_retinue:
			break
		if child is Recruit:
			_transfer(child, warlord)

func _transfer(recruit: Recruit, warlord: Warlord) -> void:
	recruit.died.disconnect(_on_recruit_died)
	garrison_size -= 1
	warlord.add_recruit(recruit)

# Called by the Call ability (see warlord.gd): send the garrison to this
# warlord no matter how far away it is — they run there. Cap still applies.
func send_garrison(warlord: Warlord) -> void:
	for child in _garrison.get_children():
		if warlord.army_size >= warlord.max_retinue:
			break
		if child is Recruit:
			_transfer(child, warlord)

# --- Helpers ----------------------------------------------------------------

func _nearest_warlord_in_range(same_team: bool) -> Warlord:
	var best: Warlord = null
	var best_dist: float = warlord_range
	for node in get_tree().get_nodes_in_group("warlords"):
		var warlord := node as Warlord
		if warlord == null:
			continue
		if (warlord.team == team) != same_team:
			continue
		var dist := global_position.distance_to(warlord.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = warlord
	return best

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
# can produce new recruits after being conquered.
#
# GARRISON: garrison recruits hold the position they were placed at and
# fight any enemy-team combatant that comes within their aggro_range
# (see recruit.gd). Survivors walk back to their posts afterwards.
#
# CONQUEST: when the garrison is wiped out and a warlord of another team
# is within warlord_range, the village flips to that warlord's team and
# starts producing recruits (one every production_interval seconds,
# spawned at the Garrison node).
#
# MUSTERING: whenever a same-team warlord is within warlord_range, every
# garrison recruit (including freshly produced ones) transfers into that
# warlord's retinue. If no friendly warlord is near, produced recruits
# loiter at the garrison — and guard the village — until one returns.
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

# Drag recruit.tscn here; needed for post-conquest production.
@export var recruit_scene: PackedScene

# Seconds between produced recruits once the village has been conquered.
@export var production_interval: float = 10.0

# "The warlord is at the village" distance, used for both conquest and
# mustering garrison recruits into a retinue.
@export var warlord_range: float = 250.0

# +1 per recruit in the Garrison node, -1 when one dies or joins a retinue.
var garrison_size: int = 0

var _production_enabled: bool = false
var _production_timer: float = 0.0

@onready var _garrison: Node2D = $Garrison

func _ready() -> void:
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

# Garrison dead + enemy warlord at the village = the village changes hands
# and begins producing recruits for its new owner.
func _try_capture() -> void:
	if garrison_size > 0:
		return
	var conqueror := _nearest_warlord_in_range(false)
	if conqueror == null:
		return
	team = conqueror.team
	_production_enabled = true
	_production_timer = production_interval

# --- Production -------------------------------------------------------------

func _produce(delta: float) -> void:
	if not _production_enabled or recruit_scene == null:
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

# A friendly warlord within warlord_range collects the whole garrison.
func _muster() -> void:
	if garrison_size == 0:
		return
	var warlord := _nearest_warlord_in_range(true)
	if warlord == null:
		return
	for child in _garrison.get_children():
		if child is Recruit:
			_transfer(child, warlord)

func _transfer(recruit: Recruit, warlord: Warlord) -> void:
	recruit.died.disconnect(_on_recruit_died)
	garrison_size -= 1
	warlord.add_recruit(recruit)

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

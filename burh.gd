# =============================================================================
# SCENE ARCHITECTURE — burh.tscn
#
# Burh (Node2D)                    <- attach this script (burh.gd) here
# ├── Garrison (Node2D)            <- spawn point / parent for the garrison.
# │                                   (Optional: hand-placed recruit.tscn
# │                                   instances in here also enroll.)
# └── Barrier (StaticBody2D)       <- physically blocks the choke point
#     ├── CollisionShape2D         <- size/shape this in the editor to seal
#     │                               the passage (add more shapes if needed)
#     └── ColorRect                <- gray box visual for the wall
#
# INSPECTOR SETUP: drag recruit.tscn into "Recruit Scene" and set
# "Garrison Count" for how many defenders spawn at scene start.
#
# A Burh is a fortification placed at a choke point during level design.
# Unlike a village it is NEVER captured and produces nothing. The Barrier
# blocks ALL movement through the choke point until every garrison recruit
# is dead; then the barrier opens (collision off, hidden) permanently —
# defeated is defeated.
#
# Spawned recruits stand in a ring of spawn_radius around the Garrison
# node and defend their posts like a village garrison (see recruit.gd).
#
# NOTE: there is no pathfinding yet — units walk straight lines and will
# hug the barrier wall, so keep choke-point geometry simple for now.
# =============================================================================

extends Node2D
class_name Burh

# Recruits only fight recruits on a different team.
@export var team: int = 1

# Drag recruit.tscn here.
@export var recruit_scene: PackedScene

# How many garrison recruits spawn at scene start.
@export var garrison_count: int = 10

# Spawned recruits stand in a ring this far from the Garrison node.
@export var spawn_radius: float = 40.0

# +1 per garrison recruit, -1 when one dies. 0 = burh defeated.
var garrison_size: int = 0

@onready var _garrison: Node2D = $Garrison
@onready var _barrier: StaticBody2D = $Barrier

func _ready() -> void:
	for child in _garrison.get_children():
		if child is Recruit:
			_enroll(child)
	for i in garrison_count:
		_spawn_recruit(i)
	if garrison_size == 0:
		_open_barrier()

func _spawn_recruit(index: int) -> void:
	if recruit_scene == null:
		return
	var recruit := recruit_scene.instantiate() as Recruit
	if recruit == null:
		return
	var angle := TAU * float(index) / float(maxi(garrison_count, 1))
	recruit.position = Vector2.RIGHT.rotated(angle) * spawn_radius
	recruit.team = team
	_garrison.add_child(recruit)
	_enroll(recruit)

func _enroll(recruit: Recruit) -> void:
	recruit.team = team
	recruit.died.connect(_on_recruit_died)
	garrison_size += 1

func _on_recruit_died(_recruit: Combatant) -> void:
	garrison_size -= 1
	if garrison_size <= 0:
		_open_barrier()

# Defeat is permanent: hide the wall and switch off its collision so the
# choke point becomes passable.
func _open_barrier() -> void:
	_barrier.hide()
	for child in _barrier.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)

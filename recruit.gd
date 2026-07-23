# =============================================================================
# SCENE ARCHITECTURE — recruit.tscn
#
# Recruit (CharacterBody2D)        <- attach this script (recruit.gd) here
# ├── ColorRect                    <- gray box placeholder visual for now.
# │                                   Set Size to 16x16 and Position to -8,-8
# │                                   so it is centered; Color = gray.
# │                                   (Swap for a Sprite2D when art is ready.)
# └── CollisionShape2D             <- physics collision shape
#
# REUSE: this one scene is instanced everywhere recruits appear —
# warlord retinues (warlord.tscn), village garrisons (village.tscn),
# fortifications, watchtowers, etc.
#
# BEHAVIOR PRIORITY (highest first):
#   1. FIGHT  — an enemy-team recruit is within aggro_range: pair up with it
#               (Bad North style — prefer enemies nobody is fighting yet),
#               chase it, and attack until one of us dies.
#   2. FOLLOW — a follow target is set (retinue): trail the warlord.
#   3. POST   — no follow target (garrison): stand at / return to the
#               position this recruit was placed at.
# =============================================================================

extends CharacterBody2D
class_name Recruit

signal died(recruit: Recruit)

# --- Team -------------------------------------------------------------------
# Overwritten by the owning Warlord or Village at scene start.
# Recruits only attack recruits on a different team.
@export var team: int = 0

# --- Movement ---------------------------------------------------------------
@export var move_speed: float = 180.0   # pixels per second
@export var stop_distance: float = 40.0 # stop following when this close

# --- Combat -----------------------------------------------------------------
@export var max_health: float = 10.0
@export var attack_damage: float = 2.0
@export var attack_interval: float = 1.0 # seconds between attacks
@export var attack_range: float = 24.0   # close enough to swing
@export var aggro_range: float = 160.0   # enemies inside this start a fight

# --- Runtime state ----------------------------------------------------------
var follow_target: Node2D = null
var health: float
var engaged_count: int = 0  # how many enemies are targeting me (for pairing)

var _combat_target: Recruit = null
var _post_position: Vector2
var _attack_timer: float = 0.0

func _ready() -> void:
	health = max_health
	_post_position = global_position
	add_to_group("recruits")

# Called by the owning Warlord. Makes this recruit trail the target.
# top_level = true detaches the recruit from its parent's transform so it
# can lag behind a moving warlord instead of being dragged rigidly with it.
func set_follow_target(target: Node2D) -> void:
	follow_target = target
	if not top_level:
		var keep := global_position
		top_level = true
		global_position = keep

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		_die()

func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_update_combat_target()
	if _combat_target != null:
		velocity = _fight(_combat_target)
	elif follow_target != null:
		velocity = _velocity_toward(follow_target.global_position, stop_distance)
	else:
		velocity = _velocity_toward(_post_position, 4.0)
	move_and_slide()

# --- Combat internals -------------------------------------------------------

func _update_combat_target() -> void:
	if _combat_target != null and not is_instance_valid(_combat_target):
		_combat_target = null
	if _combat_target != null:
		return
	var best: Recruit = null
	for node in get_tree().get_nodes_in_group("recruits"):
		var other := node as Recruit
		if other == null or other == self or other.team == team:
			continue
		if global_position.distance_to(other.global_position) > aggro_range:
			continue
		if best == null or _is_better_target(other, best):
			best = other
	if best != null:
		_combat_target = best
		best.engaged_count += 1

# Bad North pairing rule: an enemy no one is fighting beats an enemy that
# already has attackers; among equals, the nearer one wins.
func _is_better_target(candidate: Recruit, current_best: Recruit) -> bool:
	if candidate.engaged_count != current_best.engaged_count:
		return candidate.engaged_count < current_best.engaged_count
	return global_position.distance_to(candidate.global_position) \
			< global_position.distance_to(current_best.global_position)

func _fight(target: Recruit) -> Vector2:
	if global_position.distance_to(target.global_position) > attack_range:
		return _velocity_toward(target.global_position, attack_range)
	if _attack_timer == 0.0:
		_attack_timer = attack_interval
		target.take_damage(attack_damage)
	return Vector2.ZERO

func _velocity_toward(point: Vector2, stop_at: float) -> Vector2:
	var to_point: Vector2 = point - global_position
	if to_point.length() <= stop_at:
		return Vector2.ZERO
	return to_point.normalized() * move_speed

func _die() -> void:
	if _combat_target != null and is_instance_valid(_combat_target):
		_combat_target.engaged_count -= 1
	died.emit(self)
	queue_free()

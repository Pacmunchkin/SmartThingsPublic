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
# REUSE: this one scene will be instanced everywhere recruits appear —
# warlord retinues, villages, fortifications, watchtowers, etc.
#   - With a follow target set (via set_follow_target), the recruit walks
#     to stay near that target (retinue behavior).
#   - With no follow target, the recruit stands where it was placed
#     (village / fortification / watchtower behavior).
# =============================================================================

extends CharacterBody2D
class_name Recruit

# --- Movement ---------------------------------------------------------------
@export var move_speed: float = 180.0   # pixels per second
@export var stop_distance: float = 40.0 # stop following when this close

# --- Following --------------------------------------------------------------
var follow_target: Node2D = null

# Called by the owning Warlord. Makes this recruit trail the target.
# top_level = true detaches the recruit from its parent's transform so it
# can lag behind a moving warlord instead of being dragged rigidly with it.
func set_follow_target(target: Node2D) -> void:
	follow_target = target
	if not top_level:
		var keep := global_position
		top_level = true
		global_position = keep

func _physics_process(_delta: float) -> void:
	if follow_target == null:
		velocity = Vector2.ZERO
		return
	var to_target: Vector2 = follow_target.global_position - global_position
	if to_target.length() <= stop_distance:
		velocity = Vector2.ZERO
	else:
		velocity = to_target.normalized() * move_speed
	move_and_slide()

# =============================================================================
# SCENE ARCHITECTURE — warlord.tscn
#
# Warlord (CharacterBody2D)        <- attach this script (warlord.gd) here
# ├── Sprite2D                     <- warlord visual
# └── CollisionShape2D             <- physics collision shape
#
# Planned (not yet implemented):
#   - Exported variables + a Warlord character Resource (.tres) will control
#     special abilities, cooldowns, and special items.
# =============================================================================

extends CharacterBody2D
class_name Warlord

# --- Movement ---------------------------------------------------------------
@export var move_speed: float = 200.0  # pixels per second

func _physics_process(_delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir * move_speed
	move_and_slide()

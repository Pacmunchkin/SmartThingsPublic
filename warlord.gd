# =============================================================================
# SCENE ARCHITECTURE — warlord.tscn
#
# Warlord (CharacterBody2D)        <- attach this script (warlord.gd) here
# ├── Sprite2D                     <- warlord visual
# ├── CollisionShape2D             <- physics collision shape
# └── Retinue (Node2D)             <- plain Node2D; drop recruit.tscn
#     ├── Recruit (recruit.tscn)      instances in here. Each recruit found
#     ├── Recruit (recruit.tscn)      here at scene start follows this
#     └── ...                         warlord and adds +1 to army_size.
#
# This scene is instanced multiple times inside main.tscn — see
# warlord_commander.gd for the main scene layout.
#
# Planned (not yet implemented):
#   - Exported variables + a Warlord character Resource (.tres) will control
#     special abilities, cooldowns, and special items.
# =============================================================================

extends CharacterBody2D
class_name Warlord

# --- Movement ---------------------------------------------------------------
@export var move_speed: float = 200.0  # pixels per second

# --- Selection --------------------------------------------------------------
# Set by WarlordCommander. Only the selected warlord responds to the stick.
var is_selected: bool = false

# --- Retinue / army ---------------------------------------------------------
# +1 per recruit in the Retinue node at scene start.
var army_size: int = 0

@onready var _retinue: Node2D = $Retinue

func _ready() -> void:
	for child in _retinue.get_children():
		if child is Recruit:
			child.set_follow_target(self)
			army_size += 1

func _physics_process(_delta: float) -> void:
	if not is_selected:
		velocity = Vector2.ZERO
		return
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir * move_speed
	move_and_slide()

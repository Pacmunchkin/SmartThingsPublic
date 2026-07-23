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
# Garrison recruits have no follow target, so they hold the position they
# were placed at. When an enemy-team recruit (e.g. a warlord's retinue)
# comes within their aggro_range, they pair up and fight (see recruit.gd).
# Survivors walk back to their guard posts afterwards.
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

# +1 per recruit in the Garrison node at scene start, -1 when one dies.
var garrison_size: int = 0

@onready var _garrison: Node2D = $Garrison

func _ready() -> void:
	for child in _garrison.get_children():
		if child is Recruit:
			child.team = team
			child.died.connect(_on_recruit_died)
			garrison_size += 1

func _on_recruit_died(_recruit: Recruit) -> void:
	garrison_size -= 1

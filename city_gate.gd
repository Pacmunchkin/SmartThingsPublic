# =============================================================================
# SCENE ARCHITECTURE — city_gate.tscn
#
# CityGate (CharacterBody2D)       <- attach this script (city_gate.gd) here
# ├── ColorRect                    <- gray box wall/gate visual. Size it to
# │                                   the gateway (e.g. 96x24) and offset it
# │                                   so it is centered on the node.
# ├── CollisionShape2D             <- sized to seal the gateway; blocks all
# │                                   movement until the gate is destroyed
# └── NavigationObstacle2D         <- OPTIONAL (needs a baked navmesh). Give
#                                     it "vertices" covering the gateway so
#                                     units path around the sealed gate. No
#                                     code needed to re-open it: the whole
#                                     gate is freed at 0 health, taking this
#                                     obstacle with it, so the navmesh opens.
#
# Extends Combatant so recruits and warlords can attack it, but it is a
# STRUCTURE (is_structure below): it never moves, never fights back, and
# attackers are not locked onto it — they break off when their warlord
# leaves (see recruit.gd) and always prefer living enemies over it.
#
# body_radius widens the "in melee range" test so attackers can hit the
# gate's edge instead of trying to reach its center. Set it to roughly
# half the gate's width.
#
# At 0 health the gate is destroyed and removed — the way in is open.
# Instanced inside city.tscn (see city.gd), which assigns its team.
# =============================================================================

extends Combatant
class_name CityGate

@export var max_health: float = 500.0

# Roughly half the gate's collision width; melee reach is measured to the
# gate's edge, not its center.
@export var body_radius: float = 48.0

func _ready() -> void:
	super._ready()
	health = max_health

func is_structure() -> bool:
	return true

func target_radius() -> float:
	return body_radius

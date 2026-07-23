# =============================================================================
# RESOURCE CLASS — unit_type.gd (no scene; create .tres assets from it).
#
# A UnitType describes how a class of recruits fights: Seaxes, Axes,
# Spears, Shield & Sword, Bows. Create one .tres asset per type:
#   FileSystem dock > right-click > New Resource... > UnitType
# then set its stats in the Inspector and drag it onto a Warlord's
# "Unit Type" slot. Every recruit in that warlord's retinue takes these
# stats (see warlord.gd add_recruit / recruit.gd apply_unit_type).
#
# Ranged fields: ranged_range 0 means pure melee.
#   - Spears: ranged_range > 0, ranged_only OFF — they throw while closing
#     the distance, then fight in melee (slow thrusts).
#   - Bows: ranged_range > 0, ranged_only ON — they hold at range, never
#     melee, and cannot move and shoot at the same time.
# =============================================================================

extends Resource
class_name UnitType

@export var display_name: String = "Recruit"

# --- Movement ---------------------------------------------------------------
@export var move_speed: float = 180.0   # pixels per second

# --- Melee ------------------------------------------------------------------
@export var max_health: float = 10.0
@export var attack_damage: float = 2.0
@export var attack_interval: float = 1.0 # seconds between attacks
@export var attack_range: float = 24.0

# --- Ranged (ranged_range 0 = none) -----------------------------------------
@export var ranged_range: float = 0.0
@export var ranged_damage: float = 0.0
@export var ranged_interval: float = 3.0
@export var projectile_speed: float = 400.0
@export var ranged_only: bool = false   # bows: hold at range, never melee

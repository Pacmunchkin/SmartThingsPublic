# =============================================================================
# RESOURCE CLASS — ability.gd (no scene; create .tres assets from it).
#
# An Ability is a warlord cooldown power. Create one .tres asset per
# ability (FileSystem dock > New Resource... > Ability), set its numbers,
# and drag it into one of a Warlord's three slots: "Ability Up",
# "Ability Left", "Ability Right".
#
# ACTIVATION (see warlord_commander.gd): hold the X button and press
# d-pad Up / Left / Right to fire the matching slot on the SELECTED
# warlord. The effect lasts `duration` seconds and applies to the warlord
# and its whole retinue; the slot then recharges for `cooldown` seconds.
#
# IMPLEMENTED EFFECTS (more added as we build them):
#   CHARGE    — move speed of warlord + retinue multiplied by `magnitude`
#               (e.g. 1.5 = 50% faster) for the duration.
#   STEADFAST — damage taken by warlord + retinue multiplied by `magnitude`
#               (e.g. 0.5 = half damage) for the duration.
# =============================================================================

extends Resource
class_name Ability

enum Effect {
	CHARGE,
	STEADFAST,
}

@export var display_name: String = "Ability"
@export var effect: Effect = Effect.CHARGE
@export var cooldown: float = 20.0  # seconds before the slot can fire again
@export var duration: float = 5.0   # seconds the effect stays active
# CHARGE: speed multiplier (1.5 = +50% speed).
# STEADFAST: damage-taken multiplier (0.5 = half damage).
@export var magnitude: float = 1.0

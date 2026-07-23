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
# warlord. The slot then recharges for `cooldown` seconds.
#
# IMPLEMENTED EFFECTS (more added as we build them) — what each field
# means per effect:
#
#   CHARGE        sustained: move speed of warlord + retinue multiplied by
#                 `magnitude` (1.5 = +50%) for `duration` seconds.
#   STEADFAST     sustained: damage taken by warlord + retinue multiplied
#                 by `magnitude` (0.5 = half) for `duration` seconds.
#   KNOCK_BACK    instant: every enemy unit within `radius` px of the
#                 warlord is shoved `magnitude` px away and stunned for
#                 `duration` seconds (stunned = no moving, no attacking).
#   WARLORD_LEADS sustained: for `duration` seconds the warlord leads from
#                 the front — enemies CAN target the warlord even while
#                 the retinue lives — and on activation every retinue
#                 recruit is healed by `magnitude` HP (up to max health).
# =============================================================================

extends Resource
class_name Ability

enum Effect {
	CHARGE,
	STEADFAST,
	KNOCK_BACK,
	WARLORD_LEADS,
}

@export var display_name: String = "Ability"
@export var effect: Effect = Effect.CHARGE
@export var cooldown: float = 20.0  # seconds before the slot can fire again
@export var duration: float = 5.0   # effect time (KNOCK_BACK: stun time)
# CHARGE: speed multiplier. STEADFAST: damage-taken multiplier.
# KNOCK_BACK: push distance in px. WARLORD_LEADS: HP healed per recruit.
@export var magnitude: float = 1.0
# KNOCK_BACK only: enemies within this many px of the warlord are hit.
@export var radius: float = 120.0

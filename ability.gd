# =============================================================================
# RESOURCE CLASS — ability.gd (no scene; create .tres assets from it).
#
# An Ability is a warlord cooldown power. Create one .tres asset per
# ability (FileSystem dock > New Resource... > Ability), set its numbers,
# and drag it into one of a Warlord's three slots: "Ability Up",
# "Ability Left", "Ability Right". Eight effects, three slots — choosing
# which three a warlord carries is part of what differentiates them.
#
# ACTIVATION (see warlord_commander.gd): hold the X button and press
# d-pad Up / Left / Right to fire the matching slot on the SELECTED
# warlord. The slot then recharges for `cooldown` seconds.
#
# EFFECTS — what each field means per effect:
#
#   CHARGE        sustained: move speed of warlord + retinue multiplied by
#                 `magnitude` (1.5 = +50%) for `duration` seconds.
#   STEADFAST     sustained: ALL damage taken by warlord + retinue
#                 multiplied by `magnitude` (0.5 = half) for `duration` s.
#   KNOCK_BACK    instant: every enemy unit within `radius` px of the
#                 warlord is shoved `magnitude` px away and stunned for
#                 `duration` seconds (stunned = no moving, no attacking).
#   WARLORD_LEADS sustained: for `duration` seconds the warlord leads from
#                 the front — enemies CAN target the warlord even while
#                 the retinue lives — and on activation every retinue
#                 recruit is healed by `magnitude` HP (up to max health).
#   ADVANCE       sustained: for `duration` seconds every melee hit by the
#                 warlord or retinue also shoves the struck enemy
#                 `magnitude` px backwards — the fight line pushes forward.
#   DRAW_OUT      instant: the feigned retreat. Every enemy recruit within
#                 `radius` px is forced to engage this warlord's army and,
#                 because duels are committed, follows wherever it moves.
#   DITCH         sustained: ranged (arrow/javelin) damage taken by warlord
#                 + retinue multiplied by `magnitude` (0.25 = quarter) for
#                 `duration` seconds. Melee damage unaffected.
#   CALL          instant: every same-team village within `radius` px sends
#                 its garrison recruits running to join this warlord's
#                 retinue (retinue cap still applies).
# =============================================================================

extends Resource
class_name Ability

enum Effect {
	CHARGE,
	STEADFAST,
	KNOCK_BACK,
	WARLORD_LEADS,
	ADVANCE,
	DRAW_OUT,
	DITCH,
	CALL,
}

@export var display_name: String = "Ability"
@export var effect: Effect = Effect.CHARGE
@export var cooldown: float = 20.0  # seconds before the slot can fire again
@export var duration: float = 5.0   # effect time (KNOCK_BACK: stun time;
									# unused by instant DRAW_OUT / CALL)
# CHARGE: speed multiplier. STEADFAST: damage-taken multiplier.
# KNOCK_BACK: push px. WARLORD_LEADS: HP healed. ADVANCE: push px per hit.
# DITCH: ranged-damage-taken multiplier. DRAW_OUT / CALL: unused.
@export var magnitude: float = 1.0
# Area effects: KNOCK_BACK blast radius, DRAW_OUT taunt radius,
# CALL village-response radius. Others ignore it.
@export var radius: float = 120.0

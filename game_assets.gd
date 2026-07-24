# =============================================================================
# ASSET MANIFEST — reference only. This script attaches to nothing and runs
# nothing; it is the checklist of the .tres resource assets the game expects
# you to create in the FileSystem dock (right-click > New Resource...), set
# the fields on in the Inspector, and drag into the slots noted below.
#
# Suggested folders:  res://units/   res://abilities/
# All numbers are the v0.1 playtest baselines — tune freely.
#
# =============================================================================
# UNIT TYPES  (New Resource... > UnitType ; drag onto Warlord "Unit Type",
#              or offer via the War Council "Unit Types" array)
# -----------------------------------------------------------------------------
#   FILE                display_name    move  HP   dmg  interval  range | ranged
#   units/seaxes.tres   "Seaxes"        180   8    2    0.6       24    | none
#   units/axes.tres     "Axes"          180   12   4    1.4       24    | none
#   units/spears.tres   "Spears"        180   10   3    1.8       24    | throw
#   units/shield.tres   "Shield & Sword"180   16   2.5  1.0       24    | none
#   units/bows.tres     "Bows"          180   8    0    -         24    | only
#
#   Ranged fields (leave at 0 / off for the melee-only types above):
#     spears.tres : ranged_range 120, ranged_damage 3, ranged_interval 4,
#                   projectile_speed 400, ranged_only OFF  (throws while closing)
#     bows.tres   : ranged_range 200, ranged_damage 2, ranged_interval 2,
#                   projectile_speed 400, ranged_only ON   (never melees)
#
# =============================================================================
# ABILITIES  (New Resource... > Ability ; drag into Warlord "Ability Up /
#             Left / Right", and into the War Council "Abilities" array)
# -----------------------------------------------------------------------------
#   FILE                     display_name   effect        cd   dur  magnitude  radius
#   abilities/charge.tres    "Charge"       CHARGE        20   5    1.5        -
#   abilities/steadfast.tres "Steadfast"    STEADFAST     30   6    0.5        -
#   abilities/knock_back.tres"Knock Back"   KNOCK_BACK    45   1.0  80         120
#   abilities/warlord_leads.tres "Warlord Leads" WARLORD_LEADS 60 10 5         -
#   abilities/advance.tres   "Advance"      ADVANCE       15   4    10         -
#   abilities/draw_out.tres  "Draw Out"     DRAW_OUT      15   0    -          300
#   abilities/ditch.tres     "Ditch"        DITCH         45   8    0.25       -
#   abilities/call.tres      "Call"         CALL          120  0    -          2000
#
#   magnitude means different things per effect (see ability.gd header):
#     CHARGE speed x  | STEADFAST all-dmg x | KNOCK_BACK push px | WARLORD_LEADS
#     heal HP | ADVANCE push px/hit | DITCH ranged-dmg x | DRAW_OUT/CALL unused
#
# =============================================================================
# NON-.tres ASSETS also required (not resources — listed for completeness):
#   warlord_names.csv   already in the repo; edit rows to taste.
#   Scenes to build:    warlord.tscn, recruit.tscn, village.tscn, burh.tscn,
#                       city.tscn (+ city_gate.tscn, battlement.tscn),
#                       church.tscn, main.tscn  (see each script's header).
# =============================================================================

extends RefCounted
class_name GameAssets

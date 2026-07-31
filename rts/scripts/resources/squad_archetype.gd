@tool
class_name SquadArchetype
extends Resource

## One kind of squad. Squad-tactics RTS resolves combat per-squad rather than
## per-man, so model_count is mostly a health pool and a visual - but it also
## drives how quickly a squad loses cohesion, which is why the eight-man fyrd
## levy feels so different from the four-man berserkir.
##
## Distances are in pixels: 1 px = 0.1 m.

enum Faction { NEUTRAL = 0, SAXON = 1, DANE = 2 }

enum Role {
	LINE = 0,     ## Shieldwall infantry. The spine of both armies.
	ELITE = 1,    ## Mailed retainers. Expensive, slow to replace.
	MISSILE = 2,  ## Bows and slings.
	SHOCK = 3,    ## Berserkir. Fast, fragile to missiles, brutal in contact.
	HERO = 4,     ## Named character. Death is usually a mission failure.
	OBJECT = 5,   ## Non-combatant: the ox-cart, a relic chest.
}

@export var squad_id: StringName = &""
@export var display_name: String = ""
@export var faction: Faction = Faction.SAXON
@export var role: Role = Role.LINE

@export_group("Body")
@export_range(1, 16) var model_count: int = 8
@export var health_per_model: float = 100.0
## Fraction of incoming damage removed by armour, before cover is applied.
@export_range(0.0, 0.8, 0.05) var armour: float = 0.0
## Multiplies damage from axes and other armour-piercing weapons.
@export_range(0.5, 2.0, 0.05) var armour_pierce_vulnerability: float = 1.0

@export_group("Movement")
## Pixels per second on unmodified ground. 30 px/s = 3 m/s, a jog under load.
@export var move_speed: float = 30.0
@export var is_armoured: bool = false
@export var is_wheeled: bool = false

@export_group("Melee")
@export var melee_damage: float = 18.0
## Pixels. Spears reach further than axes and strike first on the closing turn.
@export var melee_reach_px: float = 20.0
@export_range(0.2, 4.0, 0.1) var melee_interval: float = 1.2

@export_group("Missile")
@export var missile_range_px: float = 0.0
@export var missile_damage: float = 0.0
@export_range(0.2, 8.0, 0.1) var missile_interval: float = 3.0
@export_range(0.0, 1.0, 0.05) var missile_accuracy: float = 0.45

@export_group("Morale")
@export var morale: float = 100.0
## Morale lost per second while under fire and out of cover.
@export_range(0.0, 30.0, 0.5) var suppression_rate: float = 6.0
@export_range(0.0, 30.0, 0.5) var morale_recovery: float = 4.0
## Below this fraction the squad routs toward its spawn.
@export_range(0.0, 1.0, 0.05) var rout_threshold: float = 0.25
## Berserkir and heroes ignore suppression entirely.
@export var immune_to_suppression: bool = false

@export_group("Perception")
@export var sight_radius_px: float = 550.0

@export_group("Abilities")
## Ability ids resolved by the combat layer. Documented in rts/README.md.
@export var abilities: Array[StringName] = []
## Heroes only: fraction of health at which scripted flight behaviour begins.
@export_range(0.0, 1.0, 0.05) var flees_below_health: float = 0.0

@export_group("Reinforcement")
## Cost in the mission's reinforcement pool. Objects and heroes are 0.
@export var reinforce_cost: int = 1


func max_health() -> float:
	return float(model_count) * health_per_model


func is_combatant() -> bool:
	return role != Role.OBJECT


func has_ability(ability: StringName) -> bool:
	return abilities.has(ability)

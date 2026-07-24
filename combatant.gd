# =============================================================================
# SCRIPT-ONLY BASE CLASS — combatant.gd has no scene file of its own.
#
# Combatant (extends CharacterBody2D) is the shared base for anything that
# can take part in a battle:
#   - Recruit (recruit.gd) extends Combatant
#   - Warlord (warlord.gd) extends Combatant
#
# Provides: team, health pool, take_damage() + died signal, the
# engaged_count bookkeeping used for Bad North style pairing, and the
# "combatants" group that targeting scans.
#
# Subclasses export their own max_health (defaults differ per class) and
# MUST call super._ready() from their _ready().
# =============================================================================

extends CharacterBody2D
class_name Combatant

signal died(combatant: Combatant)

# Combatants only fight combatants on a different team.
@export var team: int = 0

var health: float = 1.0
var engaged_count: int = 0  # enemies currently targeting me (for pairing)

# Last combatant to damage me — used for renown kill/conquest credit.
var last_attacker: Combatant = null

# Ability modifiers, set by an owning Warlord's active abilities
# (see warlord.gd): Steadfast scales all damage taken, Ditch scales ranged
# damage taken, Charge scales speed, Advance shoves on melee hits.
var damage_taken_multiplier: float = 1.0
var ranged_damage_taken_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var melee_push: float = 0.0  # px each of my melee hits shoves the target

# Stun (e.g. from Knock Back): a stunned combatant cannot move or attack.
# Subclasses tick stun_timer down in _physics_process and early-out.
var stun_timer: float = 0.0

func stun(duration: float) -> void:
	stun_timer = maxf(stun_timer, duration)

func is_stunned() -> bool:
	return stun_timer > 0.0

func _ready() -> void:
	add_to_group("combatants")

# Can enemies pick me as a combat target right now?
# Warlord overrides this: only targetable once its retinue is defeated.
func can_be_targeted() -> bool:
	return true

# Structures (e.g. CityGate) don't move or fight back; attackers prefer
# living enemies over them and are never locked onto them.
func is_structure() -> bool:
	return false

# Extra reach when meleeing this target: wide structures return ~half their
# width so attackers hit their edge instead of walking to their center.
func target_radius() -> float:
	return 0.0

# The warlord who gets renown credit for this combatant's deeds:
# a warlord credits itself, a retinue recruit credits its warlord,
# garrison recruits and structures credit nobody.
func get_credited_warlord() -> Warlord:
	return null

func take_damage(amount: float, attacker: Combatant = null) -> void:
	if attacker != null:
		last_attacker = attacker
	health -= amount * damage_taken_multiplier
	if health <= 0.0:
		_die()

# Damage from projectiles (arrows, javelins) — Ditch resists this channel.
func take_ranged_damage(amount: float, attacker: Combatant = null) -> void:
	take_damage(amount * ranged_damage_taken_multiplier, attacker)

func _die() -> void:
	_award_kill_credit()
	died.emit(self)
	queue_free()

# Renown: tell the killer's warlord what fell (see warlord.on_enemy_killed).
func _award_kill_credit() -> void:
	if last_attacker == null or not is_instance_valid(last_attacker):
		return
	var credited := last_attacker.get_credited_warlord()
	if credited != null and is_instance_valid(credited) and credited.team != team:
		credited.on_enemy_killed(self)

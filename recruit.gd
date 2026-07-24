# =============================================================================
# SCENE ARCHITECTURE — recruit.tscn
#
# Recruit (CharacterBody2D)        <- attach this script (recruit.gd) here
# ├── ColorRect                    <- gray box placeholder visual for now.
# │                                   Set Size to 16x16 and Position to -8,-8
# │                                   so it is centered; Color = gray.
# │                                   (Swap for a Sprite2D when art is ready.)
# └── CollisionShape2D             <- physics collision shape
#
# Extends Combatant (combatant.gd) for team / health / died / pairing state.
#
# REUSE: this one scene is instanced everywhere recruits appear —
# warlord retinues (warlord.tscn), village garrisons (village.tscn),
# fortifications, watchtowers, etc.
#
# BEHAVIOR PRIORITY (highest first):
#   1. FIGHT  — an enemy-team combatant in aggro_range is targetable:
#               pair up with it (Bad North style — prefer enemies nobody is
#               fighting yet), chase it, attack until one of us dies.
#               Enemy warlords only become targetable once their own
#               retinue is defeated (see warlord.gd can_be_targeted).
#   2. FOLLOW — a follow target is set (retinue): trail the warlord.
#   3. POST   — no follow target (garrison): stand at / return to the
#               position this recruit was placed at.
# =============================================================================

extends Combatant
class_name Recruit

# --- Movement ---------------------------------------------------------------
@export var move_speed: float = 180.0   # pixels per second
@export var stop_distance: float = 40.0 # stop following when this close

# --- Combat -----------------------------------------------------------------
@export var max_health: float = 10.0
@export var attack_damage: float = 2.0
@export var attack_interval: float = 1.0 # seconds between attacks
@export var attack_range: float = 24.0   # close enough to swing
@export var aggro_range: float = 160.0   # enemies inside this start a fight

# --- Ranged (overwritten by a UnitType; 0 range = pure melee) ---------------
var ranged_range: float = 0.0
var ranged_damage: float = 0.0
var ranged_interval: float = 3.0
var projectile_speed: float = 400.0
var ranged_only: bool = false

# --- Runtime state ----------------------------------------------------------
# Target SEARCHES run at most 4x/s (staggered per recruit) — with hundreds
# of idle units, scanning the combatants group every frame is the main CPU
# cost. Fighting itself is not throttled.
const TARGET_SCAN_INTERVAL: float = 0.25

var follow_target: Node2D = null

var _combat_target: Combatant = null
var _post_position: Vector2
var _attack_timer: float = 0.0
var _ranged_timer: float = 0.0
var _scan_timer: float = 0.0
var _base_max_health: float = 10.0  # pre-renown max health (see below)

func _ready() -> void:
	super._ready()
	health = max_health
	_base_max_health = max_health
	_post_position = global_position
	_scan_timer = randf() * TARGET_SCAN_INTERVAL  # stagger scans across units

# Renown credit flows to my warlord (null for garrison recruits).
func get_credited_warlord() -> Warlord:
	if follow_target != null and is_instance_valid(follow_target):
		return follow_target as Warlord
	return null

# Renown: the warlord's reputation raises the retinue's max health.
# Gains heal the difference; losses (never happens in v1) just clamp.
func apply_health_bonus(multiplier: float) -> void:
	var old_max := max_health
	max_health = _base_max_health * multiplier
	if max_health > old_max:
		health += max_health - old_max
	else:
		health = minf(health, max_health)

# Called by the owning Warlord: this recruit fights as the given type
# (Seaxes, Axes, Spears, Shield & Sword, Bows — see unit_type.gd).
func apply_unit_type(unit_type: UnitType) -> void:
	move_speed = unit_type.move_speed
	max_health = unit_type.max_health
	health = unit_type.max_health
	_base_max_health = unit_type.max_health
	attack_damage = unit_type.attack_damage
	attack_interval = unit_type.attack_interval
	attack_range = unit_type.attack_range
	ranged_range = unit_type.ranged_range
	ranged_damage = unit_type.ranged_damage
	ranged_interval = unit_type.ranged_interval
	projectile_speed = unit_type.projectile_speed
	ranged_only = unit_type.ranged_only

# Called by the owning Warlord. Makes this recruit trail the target.
# top_level = true detaches the recruit from its parent's transform so it
# can lag behind a moving warlord instead of being dragged rigidly with it.
func set_follow_target(target: Node2D) -> void:
	follow_target = target
	if not top_level:
		var keep := global_position
		top_level = true
		global_position = keep

func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_ranged_timer = maxf(_ranged_timer - delta, 0.0)
	_scan_timer = maxf(_scan_timer - delta, 0.0)
	stun_timer = maxf(stun_timer - delta, 0.0)
	if is_stunned():
		velocity = Vector2.ZERO
		return
	_update_combat_target()
	if _combat_target != null:
		velocity = _fight(_combat_target)
	elif follow_target != null:
		velocity = _velocity_toward(follow_target.global_position, stop_distance)
	else:
		velocity = _velocity_toward(_post_position, 4.0)
	move_and_slide()

# --- Combat internals -------------------------------------------------------

func _update_combat_target() -> void:
	if _combat_target != null and not is_instance_valid(_combat_target):
		_combat_target = null
	# Structure attacks are not sticky: break off the moment the anchor
	# (my warlord, or my post) is left behind — the player pulling their
	# warlord away pulls the retinue off the gate.
	if _combat_target != null and _combat_target.is_structure():
		if _anchor_position().distance_to(global_position) > aggro_range:
			_release_combat_target()
	# Duels with living enemies stay committed until one side dies.
	if _combat_target != null and not _combat_target.is_structure():
		return
	# Everything below SEARCHES for a target — throttled.
	if _scan_timer > 0.0:
		return
	_scan_timer = TARGET_SCAN_INTERVAL
	# Living enemies always outrank structures.
	var best_unit := _best_unit_target()
	if best_unit != null:
		_release_combat_target()
		_combat_target = best_unit
		best_unit.engaged_count += 1
		return
	if _combat_target != null:
		return  # keep hammering the structure
	var structure := _nearest_structure_target()
	if structure != null:
		_combat_target = structure
		structure.engaged_count += 1

func _best_unit_target() -> Combatant:
	var best: Combatant = null
	for node in get_tree().get_nodes_in_group("combatants"):
		var other := node as Combatant
		if other == null or other == self or other.team == team:
			continue
		if other.is_structure() or not other.can_be_targeted():
			continue
		if global_position.distance_to(other.global_position) > aggro_range:
			continue
		if best == null or _is_better_target(other, best):
			best = other
	return best

func _nearest_structure_target() -> Combatant:
	var best: Combatant = null
	var best_dist: float = aggro_range
	for node in get_tree().get_nodes_in_group("combatants"):
		var other := node as Combatant
		if other == null or other.team == team:
			continue
		if not other.is_structure() or not other.can_be_targeted():
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = other
	return best

func _release_combat_target() -> void:
	if _combat_target != null and is_instance_valid(_combat_target):
		_combat_target.engaged_count -= 1
	_combat_target = null

# Where this recruit "belongs": its warlord if it has one, else its post.
func _anchor_position() -> Vector2:
	if follow_target != null:
		return follow_target.global_position
	return _post_position

# Bad North pairing rule: an enemy no one is fighting beats an enemy that
# already has attackers; among equals, the nearer one wins.
func _is_better_target(candidate: Combatant, current_best: Combatant) -> bool:
	if candidate.engaged_count != current_best.engaged_count:
		return candidate.engaged_count < current_best.engaged_count
	return global_position.distance_to(candidate.global_position) \
			< global_position.distance_to(current_best.global_position)

func _fight(target: Combatant) -> Vector2:
	var reach: float = attack_range + target.target_radius()
	var dist: float = global_position.distance_to(target.global_position)
	# Melee swing when in reach (bows never melee).
	if dist <= reach and not ranged_only:
		if _attack_timer == 0.0:
			_attack_timer = attack_interval
			target.take_damage(attack_damage, self)
			_push_target(target)
		return Vector2.ZERO
	var ranged_reach: float = ranged_range + target.target_radius()
	if ranged_range > 0.0 and dist <= ranged_reach:
		if ranged_only:
			# Bows hold position to shoot — they cannot move and attack.
			if _ranged_timer == 0.0:
				_ranged_timer = ranged_interval
				_loose_projectile(target)
			return Vector2.ZERO
		# Spears throw on the move while closing to melee.
		if _ranged_timer == 0.0 and dist > reach:
			_ranged_timer = ranged_interval
			_loose_projectile(target)
	if ranged_only:
		return _velocity_toward(target.global_position, ranged_reach)
	return _velocity_toward(target.global_position, reach)

# Advance: while active, each melee hit also shoves the target backwards.
func _push_target(target: Combatant) -> void:
	if melee_push <= 0.0 or not is_instance_valid(target) or target.is_structure():
		return
	var offset: Vector2 = target.global_position - global_position
	var dir := offset.normalized() if offset.length() > 0.0 else Vector2.RIGHT
	target.move_and_collide(dir * melee_push)

# Draw Out: an enemy warlord's feigned retreat forces this recruit to
# chase the given lure; the normal duel commitment keeps it following.
func force_engage(target: Combatant) -> void:
	if target == null or not is_instance_valid(target) or target == self:
		return
	_release_combat_target()
	_combat_target = target
	target.engaged_count += 1

func _loose_projectile(target: Combatant) -> void:
	var arrow := Arrow.new()
	arrow.target = target
	arrow.damage = ranged_damage
	arrow.speed = projectile_speed
	arrow.shooter = self
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = global_position

func _velocity_toward(point: Vector2, stop_at: float) -> Vector2:
	var to_point: Vector2 = point - global_position
	if to_point.length() <= stop_at:
		return Vector2.ZERO
	return to_point.normalized() * move_speed * speed_multiplier

func _die() -> void:
	if _combat_target != null and is_instance_valid(_combat_target):
		_combat_target.engaged_count -= 1
	super._die()

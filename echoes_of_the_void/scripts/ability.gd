class_name Ability
extends RefCounted

# =============================================================================
# ABILITY — data + runtime state for one ability slot.
# Created via Abilities.get_ability(id).
# Each entity holds its own instance so cooldown timers are independent.
#
# Caller flow:
#   1. if ab.can_use(stats):      — check resources + cooldown
#   2.     ab.spend(stats)        — deduct costs, start cooldown
#   3.     damage = ab.calc_damage(stats) — compute final damage
#   4.     apply damage to targets via receive_hit(damage, dir)
# =============================================================================

var id           : String = ""
var display_name : String = ""
var description  : String = ""
var anim         : String = ""       # animation prefix used by creature.gd
var is_magic     : bool   = false

var damage_mult  : float  = 1.0
var range_       : float  = 1.5
var cooldown     : float  = 1.0
var hit_frame    : int    = 1    # animation frame (0-indexed) at which damage/flash/knockback fire
var effect_name  : String = ""
var effect_chance: float  = 0.0

# Resource costs
var hp_cost     : int = 0
var energy_cost : int = 0
var focus_cost  : int = 0
var flow_cost   : int = 0

# Runtime
var _timer : float = 0.0

var is_ready : bool:
	get: return _timer <= 0.0

var cooldown_pct : float:
	get: return clampf(1.0 - _timer / cooldown, 0.0, 1.0) if cooldown > 0.0 else 1.0


# =============================================================================
# FRAME UPDATE
# =============================================================================

func tick(dt: float) -> void:
	_timer = maxf(0.0, _timer - dt)


# =============================================================================
# RESOURCE CHECK / SPEND
# =============================================================================

func can_use(user: Stats) -> bool:
	if _timer > 0.0:                     return false
	if float(hp_cost)     > user.hp:     return false
	if float(energy_cost) > user.energy: return false
	if float(focus_cost)  > user.focus:  return false
	if float(flow_cost)   > user.flow:   return false
	return true


func spend(user: Stats) -> void:
	# Deducts costs and starts cooldown. Only call after can_use() == true.
	user.hp     -= float(hp_cost)
	user.energy -= float(energy_cost)
	user.focus  -= float(focus_cost)
	user.flow   -= float(flow_cost)
	_timer = cooldown


# =============================================================================
# DAMAGE
# =============================================================================

func calc_damage(user: Stats) -> float:
	# Returns final damage value. On crit: damage ×2, player gains 1 Focus.
	var atk     : float = user.matk if is_magic else user.patk
	var actual  : float = maxf(1.0, atk * damage_mult)
	var is_crit : bool  = randf() < (user.mcrit if is_magic else user.crit)
	if is_crit:
		actual     *= 2.0
		user.focus  = minf(float(user.focus_max), user.focus + 1.0)
	return actual

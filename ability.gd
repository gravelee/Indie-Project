class_name Ability
extends RefCounted

const _AbilityData := preload("res://abilities.gd")


# ── Fields ────────────────────────────────────────────────────────────────────

var name          : String
var level         : int
var damage_mult   : float
var cooldown      : float
var range_        : float
var hp_cost       : int
var energy_cost   : int
var rage_cost     : int
var mp_cost       : int
var effect_name   : String
var effect_chance : float
var anim          : String
var is_magic      : bool
var description   : String

var last_hit_verdict	: Array  = []	# set use().
var last_hit_targets	: Array  = []	# set use().
var _timer        		: float  = 0.0	# update tick(), set use().


# =============================================================================
# LIFECYCLE
# =============================================================================

# Called: get_ability().
func _init(
	p_name: String, p_level: int, p_damage_mult: float, p_cooldown: float,
	p_range: float, p_hp_cost: float, p_energy_cost: float, p_rage_cost: float, p_mp_cost: float,
	p_effect_name: String, p_effect_chance: float, p_anim: String,
	p_is_magic: bool, p_description: String
) -> void:

	name          = p_name
	level         = p_level
	damage_mult   = p_damage_mult
	cooldown      = p_cooldown
	range_        = p_range
	hp_cost       = p_hp_cost
	energy_cost   = p_energy_cost
	rage_cost     = p_rage_cost
	mp_cost       = p_mp_cost
	effect_name   = p_effect_name
	effect_chance = p_effect_chance
	anim          = p_anim
	is_magic      = p_is_magic
	description   = p_description


# =============================================================================
# API
# =============================================================================

# Called: creature._physics_process(), player._physics_process().
func tick(dt: float) -> void:

	if _timer > 0.0:
		_timer = maxf(0.0, _timer - dt)


# Called: creature._try_attack(), player._try_attack().
func check_resources(user_stats: Stats, dist: float) -> bool:

	return (
		# Check ability's timer.
		ready
		# Check ability's range.
		and dist <= range_
		# Check gcd_timer reset and if resources exist.
		and user_stats.check_resources([hp_cost,energy_cost,rage_cost,mp_cost])
	)


# Called: creature._try_attack(), player.resolve_attack().
func use(user_stats: Stats, targets: Array, dist: float) -> void:

	# Pay resource costs.
	user_stats.spend_resources([hp_cost,energy_cost,rage_cost,mp_cost])

	var results : Array = []

	for t in targets:

		var result : Dictionary = {
			"damage"  : 0.0,
			"crit"    : false,
			"effect"  : "",
			"hit_type": "normal",   # "normal" | "dodge" | "block" | "resist"
			"is_magic": is_magic,
		}

		# Magic resist check.
		if is_magic and StatusEffect.roll(t.stats.resist):
			result["hit_type"] = "resist"
			results.append(result)
			continue

		# Dodge check.
		if StatusEffect.roll(t.stats.dodge):
			result["hit_type"] = "dodge"
			results.append(result)
			continue

		# Block check (physical only).
		if not is_magic and StatusEffect.roll(t.stats.block):
			result["hit_type"] = "block"
			results.append(result)
			continue

		# Raw damage.
		var base : float = user_stats.matk if is_magic else user_stats.patk
		var raw  : float = base * damage_mult

		# Crit roll.
		var crit_stat : float = user_stats.mcrit if is_magic else user_stats.crit
		if StatusEffect.roll(crit_stat):
			raw              *= 2.0
			result["crit"]    = true
			user_stats.rage   = minf(user_stats.rage_max, user_stats.rage + 2.0)
		else:
			user_stats.rage   = minf(user_stats.rage_max, user_stats.rage + 1.0)

		# Apply defense — Stats.take_damage returns actual damage after mitigation.
		var actual         : float = t.take_damage(raw, false, is_magic, result["crit"])
		result["damage"]   = actual
		
		# Check if target still alive.
		if t.alive:
			
			# Target gains rage when hit.
			t.stats.rage = minf(t.stats.rage_max, t.stats.rage + 1.0)

			# Status effect roll.
			if effect_name != "" and effect_chance > 0.0:
				if StatusEffect.roll(effect_chance):
					# Physical effects apply immediately; magic effects need extra resist roll.
					if not is_magic or not StatusEffect.roll(t.stats.resist):
						t.stats.apply_effect(effect_name)
						result["effect"] = effect_name
		# Target not alive.
		else:
			# The killer gains exp.
			user_stats.gain_exp(t.stats.exp_reward())
			
		results.append(result)
		
	last_hit_verdict = results
	last_hit_targets = targets
	
	user_stats.gcd_timer = user_stats.GCD
	_timer = cooldown


# ── Read-only ─────────────────────────────────────────────────────────────────

# Called: can_use(), stat_panel.gd.
var ready : bool:
	
	get: return _timer <= 0.0

# Called: stat_panel.gd.
var cooldown_pct : float:
	
	get: return _timer / cooldown if cooldown > 0.0 else 0.0


# =============================================================================
# FACTORY
# =============================================================================

# Called: creature.init(), player.load_animations().
static func get_ability(ability_name: String, p_level: int = 1) -> Ability:

	var data : Dictionary = _AbilityData.ABILITY_DATA.get(ability_name, {})
	if data.is_empty():
		push_error("Ability not found: " + ability_name)
		return null

	# Extract base values.
	var damage_mult   : float  	= data["damage_mult"]
	var p_cooldown    : float  	= data["cooldown"]
	var range_        : float  	= data["range_"]
	var hp_cost       : int    	= data["hp_cost"]
	var energy_cost   : int    	= data["energy_cost"]
	var rage_cost     : int    	= data["rage_cost"]
	var mp_cost       : int    	= data["mp_cost"]
	var effect_name   : String 	= data["effect_name"]
	var effect_chance : float  	= data["effect_chance"]
	var anim          : String 	= data["anim"]

	# Apply per-level scaling (level 1 = 0 gain, level 100 = full scale_value).
	var scale_fields : Array   	= data.get("scale", [])
	var scale_values : Array   	= data.get("scale_value", [])

	for i in range(scale_fields.size()):
		var field : String 		= scale_fields[i]
		var gain  : float		= scale_values[i] * float(p_level - 1) / 99.0

		match field:
			"damage_mult"  : damage_mult   += gain
			"cooldown"     : p_cooldown     = maxf(1.0, p_cooldown - gain)
			"range_"       : range_        += gain
			"hp_cost"      : hp_cost       += gain
			"energy_cost"  : energy_cost   += gain
			"rage_cost"    : rage_cost     += gain
			"mp_cost"      : mp_cost       += gain
			"effect_chance": effect_chance += gain

	return Ability.new(
		data["name"], p_level, damage_mult, p_cooldown, range_,
		hp_cost, energy_cost, rage_cost, mp_cost,
		effect_name, effect_chance, anim,
		data["is_magic"], data["description"])

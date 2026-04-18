class_name StatusEffect
extends RefCounted

const _Statuses := preload("res://statuses.gd")


# ── Roll helper ───────────────────────────────────────────────────────────────

# Called: Ability.use().
static func roll(chance: float) -> bool:

	return randf() * 100.0 <= chance


# =============================================================================
# EFFECT
# One active status instance.
# =============================================================================

class Effect:

	var name           : String
	var type           : String   		# "dot" | "flag" | "modifier".
	var is_magic       : bool
	var tick_dmg       : float
	var tick_rate      : float
	var duration       : float
	var max_stacks     : int
	var color          : Color
	var flag           : String   		# Stats property name for "flag" type.
	var stat           : String   		# Stats property name for "modifier" type.
	var modifier       : float

	var stacks         : int   = 1
	var expired        : bool  = false
	var tick_timer     : float = 0.0
	var time_remaining : float = 0.0
	
	# If this is 0.0 after application means that a stronger effect is applied on top of it.
	# The stronger effect has the same modifier as this one.
	var original_value : float = 0.0	# Sets the original value here while modified value is set in stats.
	
	# If this is True after application means that a longer effect is applied on top of it.
	# The longer effect has the same flag as this one.
	var weak_flag	   : bool  = false


	# Called: EffectManager.apply().
	func init(data: Dictionary) -> void:

		name           = data["name"]
		type           = data["type"]
		is_magic       = data["is_magic"]
		tick_dmg       = data["tick_dmg"]
		tick_rate      = data["tick_rate"]
		duration       = data["duration"]
		max_stacks     = data["max_stacks"]
		color          = data["color"]
		flag           = data["flag"]
		stat           = data["stat"]
		modifier       = data["modifier"]
		
		time_remaining = duration


	# Called: EffectManager.apply().
	func reapply() -> void:

		time_remaining = duration
		
		if stacks < max_stacks:
			stacks += 1


	# Called: EffectManager.update().
	func update(dt: float) -> void:
		
		time_remaining -= dt
		
		if time_remaining <= 0.0:
			expired = true


	# Called: EffectManager.update().
	func tick(dt: float) -> bool:

		tick_timer += dt
		
		if tick_timer >= tick_rate:
			tick_timer    -= tick_rate
			return true
			
		return false


	# Called: stat_panel.gd.
	func duration_pct() -> float:

		return maxf(0.0, time_remaining / duration)


# =============================================================================
# EFFECT MANAGER
# Owns all active Effects for one entity.
# =============================================================================

class EffectManager:

	var _active : Dictionary = {}
	var total_damage  : Array[float]  = [0.0]
	var expired_names : Array[String] = []

	# Called: Ability.use().
	func apply(effect_name: String) -> bool:

		var data : Dictionary = _Statuses.STATUS_DATA.get(effect_name, {})
		if data.is_empty():
			return false

		var effect : Effect = _active.get(effect_name, null)
		if effect:
			effect.reapply()
			return true

		effect = Effect.new()
		effect.init(data)
		_active[effect_name] = effect
		return true


	# Called: stats.cleanse_effect().
	func cleanse(effect_name: String) -> bool:

		return _active.erase(effect_name)


	# Called: stats.cleanse_all_effects().
	func cleanse_all() -> void:

		_active = {}


	# Called: stats._physics_process().
	func update(dt: float) -> void:

		total_damage[0] = 0.0
		expired_names = []

		for effect_name in _active:
			var effect : Effect = _active[effect_name] 
			if effect.type == "dot" and effect.tick(dt):
				total_damage[0] += effect.tick_dmg * effect.stacks
			effect.update(dt)
			if effect.expired:
				expired_names.append(effect_name)


	# Called: stat_panel.gd.
	func get_active() -> Dictionary:

		return _active


	# Called: stat_panel.gd.
	func count() -> int:

		return _active.size()

class_name StatusEffect
extends RefCounted

# =============================================================================
# STATUS EFFECT — one active status instance on an entity.
# Created via Statuses.get_status(effect_id, max_stacks).
#
# Caller flow (per physics frame on the entity owning this effect):
#   1. if se.tick(delta): apply se.tick_dmg * se.stacks damage
#   2. se.update(delta)
#   3. if se.expired: remove from active dict
#
# To reapply (same effect hits again): se.reapply(max_stacks)
#   — refreshes duration and increments stacks up to max.
# =============================================================================

var id             : String = ""
var display_name   : String = ""
var tick_dmg       : float  = 0.0
var tick_rate      : float  = 1.0
var duration       : float  = 5.0
var max_stacks     : int    = 1
var is_magic       : bool   = false
var color          : Color  = Color.WHITE

# Runtime
var stacks         : int   = 1
var time_remaining : float = 0.0
var tick_timer     : float = 0.0
var expired        : bool  = false


func init(data: Dictionary, p_max_stacks: int) -> void:
	id             = data.get("id",           "")
	display_name   = data.get("display_name", "")
	tick_dmg       = data.get("tick_dmg",     1.0)
	tick_rate      = data.get("tick_rate",    1.0)
	duration       = data.get("duration",     5.0)
	is_magic       = data.get("is_magic",     false)
	color          = data.get("color",        Color.WHITE)
	max_stacks     = p_max_stacks
	time_remaining = duration
	stacks         = 1


func reapply(p_max_stacks: int) -> void:
	# Refreshes duration and adds a stack (up to max_stacks).
	# max_stacks updated in case the ability was upgraded since last application.
	time_remaining = duration
	max_stacks     = p_max_stacks
	if stacks < max_stacks:
		stacks += 1


func update(dt: float) -> void:
	time_remaining -= dt
	if time_remaining <= 0.0:
		expired = true


func tick(dt: float) -> bool:
	# Returns true once per tick_rate seconds — caller applies damage when true.
	tick_timer += dt
	if tick_timer >= tick_rate:
		tick_timer -= tick_rate
		return true
	return false


func duration_pct() -> float:
	return maxf(0.0, time_remaining / duration)

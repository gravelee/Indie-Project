class_name Statuses
extends RefCounted

# =============================================================================
# STATUSES — static registry of all status effect definitions.
# Usage: var se := Statuses.get_status("bleed", max_stacks)
# Each call returns a fresh StatusEffect instance ready for use.
# =============================================================================

const STATUS_DATA : Dictionary = {

	"bleed": {
		"display_name": "Bleed",
		"tick_dmg":     1.0,
		"tick_rate":    3.0,    # ticks every 3 s
		"duration":     15.0,
		"is_magic":     false,
		"color":        Color(0.71, 0.12, 0.12),
	},

	"poison": {
		"display_name": "Poison",
		"tick_dmg":     1.0,
		"tick_rate":    1.5,    # ticks every 1.5 s — faster, same per-tick damage
		"duration":     15.0,
		"is_magic":     false,
		"color":        Color(0.31, 0.71, 0.16),
	},
}


static func get_status(effect_id: String, p_max_stacks: int) -> StatusEffect:
	var data : Dictionary = STATUS_DATA.get(effect_id, {})
	if data.is_empty():
		return null
	var d  : Dictionary  = data.duplicate()
	d["id"] = effect_id
	var se  := StatusEffect.new()
	se.init(d, p_max_stacks)
	return se

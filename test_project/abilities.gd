class_name Abilities
extends RefCounted

const _DATA : Dictionary = {
	
	"punch": {
		"damage_mult":  1.0,
		"range_":       1.5,
		"cooldown":     1.0,
		"energy_cost":  1,
		"hit_frame":    2
		}
}


# Called: player.gd, creature.gd.
static func get_ability(p_id: String) -> Ability:
	
	assert(p_id in _DATA, "Abilities.get_ability: unknown id '%s'" % p_id)
	var data : Dictionary = _DATA.get(p_id, {})
	var ab   : Ability    = Ability.new()
	ab.id          = p_id
	ab.damage_mult = data["damage_mult"]
	ab.range_      = data["range_"]
	ab.cooldown    = data["cooldown"]
	ab.hit_frame   = data["hit_frame"]
	ab.energy_cost = data["energy_cost"]
	return ab

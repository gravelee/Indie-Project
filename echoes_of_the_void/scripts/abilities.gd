class_name Abilities
extends RefCounted

# =============================================================================
# ABILITIES — static factory.  Creates independent Ability instances by id.
# Usage: var ab := Abilities.get_ability("slash")
# Each call returns a fresh object — entities own their own cooldown timers.
# =============================================================================

const _DATA : Dictionary = {

	# ---- Player abilities -------------------------------------------------------

	"punch": {
		"display_name": "Punch",
		"description":  "A basic melee strike.",
		"anim":         "attack",
		"is_magic":     false,
		"damage_mult":  1.0,
		"range_":       1.5,
		"cooldown":     0.5,
		"energy_cost":  1,
		"hit_frame":    2,
	},

	"heavy_strike": {
		"display_name": "Heavy Strike",
		"description":  "A powerful blow. Crits generate Focus.",
		"anim":         "attack",
		"is_magic":     false,
		"damage_mult":  1.8,
		"range_":       1.5,
		"cooldown":     5.0,
		"energy_cost":  3,
	},

	# ---- Creature abilities -----------------------------------------------------

	"rat_bite": {
		"display_name": "Bite",
		"description":  "Rat snaps at the target.",
		"anim":         "attack_bite",
		"is_magic":     false,
		"damage_mult":  1.0,
		"range_":       1.2,
		"cooldown":     2.5,
		"hit_frame":    4,
	},

	"rat_slash": {
		"display_name": "Claw Slash",
		"description":  "Rat rakes with its claws.",
		"anim":         "attack_slash",
		"is_magic":     false,
		"damage_mult":  1.2,
		"range_":       1.3,
		"cooldown":     3.0,
		"hit_frame":    5,
	},

	"snake_bite": {
		"display_name": "Venomous Bite",
		"description":  "Snake strikes at close range.",
		"anim":         "attack_bite",
		"is_magic":     false,
		"damage_mult":  1.0,
		"range_":       1.2,
		"cooldown":     3.0,
		"hit_frame":    4,
	},

	"snake_tail_slam": {
		"display_name": "Tail Slam",
		"description":  "Snake sweeps its tail in a wide arc.",
		"anim":         "attack_tail_slam",
		"is_magic":     false,
		"damage_mult":  0.8,
		"range_":       1.6,
		"cooldown":     4.0,
		"hit_frame":    5,
	},
}


static func get_ability(p_id: String) -> Ability:
	var data : Dictionary = _DATA.get(p_id, {})
	var ab   := Ability.new()
	ab.id            = p_id
	ab.display_name  = data.get("display_name",  p_id)
	ab.description   = data.get("description",   "")
	ab.anim          = data.get("anim",           "attack")
	ab.is_magic      = data.get("is_magic",       false)
	ab.damage_mult   = data.get("damage_mult",    1.0)
	ab.range_        = data.get("range_",         1.5)
	ab.cooldown      = data.get("cooldown",       1.0)
	ab.hit_frame     = data.get("hit_frame",      1)
	ab.effect_name   = data.get("effect_name",    "")
	ab.effect_chance = data.get("effect_chance",  0.0)
	ab.hp_cost       = data.get("hp_cost",        0)
	ab.energy_cost   = data.get("energy_cost",    0)
	ab.focus_cost    = data.get("focus_cost",     0)
	ab.flow_cost     = data.get("flow_cost",      0)
	return ab


# Returns the hit frame for a creature ability without allocating a full Ability object.
# creature.gd uses this: type="rat", anim_prefix="attack_bite" → id="rat_bite"
static func get_hit_frame(p_id: String) -> int:
	return _DATA.get(p_id, {}).get("hit_frame", 1)

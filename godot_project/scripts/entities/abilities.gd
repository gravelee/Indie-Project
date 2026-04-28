class_name AbilityData

# =============================================================================
# ABILITIES.GD
#
# Responsibilities:
#   - Define all ability data in one place.
#
# Scale / Scale_value:
#   Parallel arrays — field name and how much it gains from level 1 to 100.
#   At level 1 gain = 0; at level 100 gain = scale_value.
#   Supported fields: "damage_mult", "cooldown" (reduced), "range_", "effect_chance".
# =============================================================================

const MELEE_ATTACK_RANGE := 60

const ABILITY_DATA : Dictionary = {

	"player_slash": {
		"name"         : "Forward Slash",
		"damage_mult"  : 1.0,
		"cooldown"     : 2.0,
		"range_"       : 0,
		"hp_cost"      : 0.0,
		"energy_cost"  : 1.0,
		"rage_cost"    : 0.0,
		"mp_cost"      : 0.0,
		"effect_name"  : "",
		"effect_chance": 0.0,
		"anim"         : "forward_slash",
		"is_magic"     : false,
		"description"  : "Physical x1.0 | 2 s CD | 1 energy | no effect. Scales: dmg +0.5, CD -0.5 s.",
		"scale"        : ["damage_mult", "cooldown"],
		"scale_value"  : [0.5, 0.5]
	},

	"rat_bite": {
		"name"         : "Bite",
		"damage_mult"  : 1.0,
		"cooldown"     : 2.0,
		"range_"       : MELEE_ATTACK_RANGE,
		"hp_cost"      : 0.0,
		"energy_cost"  : 1.0,
		"rage_cost"    : 0.0,
		"mp_cost"      : 0.0,
		"effect_name"  : "rat_bite_bleed",
		"effect_chance": 5.0,
		"anim"         : "rat_bite",
		"is_magic"     : false,
		"description"  : "Physical x1.0 | 2 s CD | 1 energy | bleed 5%. Scales: effect chance +10%.",
		"scale"        : ["effect_chance"],
		"scale_value"  : [10.0]
	},

	"rat_slash": {
		"name"         : "Slash",
		"damage_mult"  : 1.5,
		"cooldown"     : 6.0,
		"range_"       : MELEE_ATTACK_RANGE,
		"hp_cost"      : 0.0,
		"energy_cost"  : 1.0,
		"rage_cost"    : 0.0,
		"mp_cost"      : 0.0,
		"effect_name"  : "",
		"effect_chance": 0.0,
		"anim"         : "rat_slash",
		"is_magic"     : false,
		"description"  : "Physical x1.5 | 6 s CD | 1 energy | no effect. Scales: CD -1 s.",
		"scale"        : ["cooldown"],
		"scale_value"  : [1.0]
	},

	"snake_bite": {
		"name"         : "Bite",
		"damage_mult"  : 1.3,
		"cooldown"     : 2.5,
		"range_"       : MELEE_ATTACK_RANGE,
		"hp_cost"      : 0.0,
		"energy_cost"  : 1.0,
		"rage_cost"    : 0.0,
		"mp_cost"      : 0.0,
		"effect_name"  : "snake_bite_poison",
		"effect_chance": 5.0,
		"anim"         : "snake_bite",
		"is_magic"     : false,
		"description"  : "Physical x1.3 | 2.5 s CD | 1 energy | poison 5%. Scales: effect chance +5%.",
		"scale"        : ["effect_chance"],
		"scale_value"  : [5.0]
	},

	"snake_tail_slam": {
		"name"         : "Tail Slam",
		"damage_mult"  : 1.8,
		"cooldown"     : 10.0,
		"range_"       : MELEE_ATTACK_RANGE,
		"hp_cost"      : 0.0,
		"energy_cost"  : 1.0,
		"rage_cost"    : 1.0,
		"mp_cost"      : 0.0,
		"effect_name"  : "",
		"effect_chance": 0.0,
		"anim"         : "snake_tail_slam",
		"is_magic"     : false,
		"description"  : "Physical x1.8 | 10 s CD | 1 energy + 1 rage | no effect. Scales: dmg +0.2, CD -2 s.",
		"scale"        : ["damage_mult", "cooldown"],
		"scale_value"  : [0.2, 2.0]
	},
}

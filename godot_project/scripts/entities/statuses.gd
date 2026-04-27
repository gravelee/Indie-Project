class_name Statuses

# =============================================================================
# STATUSES.GD
#
# Responsibilities:
#   - Define all status effect data in one place
#
# Types:
#   "dot"      — deals tick_dmg every tick_rate seconds
#   "flag"     — sets a boolean on Stats (stunned, silenced, frozen)
#   "modifier" — multiplies a Stats field by modifier for the duration
# =============================================================================

const STATUS_DATA : Dictionary = {

	"rat_bite_bleed": {
		"name"       : "bleed",
		"type"       : "dot",
		"is_magic"   : false,
		"tick_dmg"   : 1.0,
		"tick_rate"  : 3.0,
		"duration"   : 15.0,
		"max_stacks" : 2,
		"color"      : Color(0.71, 0.12, 0.12),
		"flag"       : "",
		"stat"       : "",
		"modifier"   : 1.0,
	},

	"snake_bite_poison": {
		"name"       : "poison",
		"type"       : "dot",
		"is_magic"   : false,
		"tick_dmg"   : 1.0,
		"tick_rate"  : 1.5,
		"duration"   : 15.0,
		"max_stacks" : 1,
		"color"      : Color(0.31, 0.71, 0.16),
		"flag"       : "",
		"stat"       : "",
		"modifier"   : 1.0,
	},

	"creature_ability_burn": {
		"name"       : "burn",
		"type"       : "dot",
		"is_magic"   : true,
		"tick_dmg"   : 3.0,
		"tick_rate"  : 3.0,
		"duration"   : 12.0,
		"max_stacks" : 2,
		"color"      : Color(0.86, 0.39, 0.08),
		"flag"       : "",
		"stat"       : "",
		"modifier"   : 1.0,
	},

	"creature_ability_stun": {
		"name"       : "stun",
		"type"       : "flag",
		"is_magic"   : false,
		"tick_dmg"   : 0.0,
		"tick_rate"  : 0.0,
		"duration"   : 2.0,
		"max_stacks" : 1,
		"color"      : Color(0.86, 0.86, 0.20),
		"flag"       : "stunned",
		"stat"       : "",
		"modifier"   : 1.0,
	},

	"creature_ability_slow": {
		"name"       : "slow",
		"type"       : "modifier",
		"is_magic"   : true,
		"tick_dmg"   : 0.0,
		"tick_rate"  : 0.0,
		"duration"   : 4.0,
		"max_stacks" : 1,
		"color"      : Color(0.39, 0.39, 0.86),
		"flag"       : "",
		"stat"       : "mspd",
		"modifier"   : 0.5,
	},

	"creature_ability_silence": {
		"name"       : "silence",
		"type"       : "flag",
		"is_magic"   : true,
		"tick_dmg"   : 0.0,
		"tick_rate"  : 0.0,
		"duration"   : 3.0,
		"max_stacks" : 1,
		"color"      : Color(0.63, 0.31, 0.78),
		"flag"       : "silenced",
		"stat"       : "",
		"modifier"   : 1.0,
	},

	"creature_ability_weaken": {
		"name"       : "weaken",
		"type"       : "modifier",
		"is_magic"   : true,
		"tick_dmg"   : 0.0,
		"tick_rate"  : 0.0,
		"duration"   : 4.0,
		"max_stacks" : 1,
		"color"      : Color(0.71, 0.51, 0.20),
		"flag"       : "",
		"stat"       : "patk",
		"modifier"   : 0.8,
	},

	"creature_ability_freeze": {
		"name"       : "freeze",
		"type"       : "flag",
		"is_magic"   : true,
		"tick_dmg"   : 0.0,
		"tick_rate"  : 0.0,
		"duration"   : 2.5,
		"max_stacks" : 1,
		"color"      : Color(0.59, 0.86, 1.00),
		"flag"       : "frozen",
		"stat"       : "",
		"modifier"   : 1.0,
	},

	"creature_ability_blind": {
		"name"       : "blind",
		"type"       : "modifier",
		"is_magic"   : true,
		"tick_dmg"   : 0.0,
		"tick_rate"  : 0.0,
		"duration"   : 3.0,
		"max_stacks" : 1,
		"color"      : Color(0.31, 0.31, 0.31),
		"flag"       : "",
		"stat"       : "crit",
		"modifier"   : 0.0,   # removes crit entirely while blind
	},
}

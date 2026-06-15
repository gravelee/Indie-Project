class_name Abilities
extends RefCounted

# ---------------------------------------------------------------------------
# Ability registry — all ability definitions live here.
# Adding a new ability = adding a new entry to _DATA. No other file needs to change.
# Every field is required — Ability._init() hard-crashes on any missing key.
#
# Fields per entry:
#   damage_mult : float — multiplier on user.patk. 1.0 = full patk damage.
#   range_      : float — raycast reach in world units (1 unit = 1 tile = 32px).
#   cooldown    : float — seconds before the ability can be used again.
#   energy_cost : int   — energy drained from the user on use.
#   hit_frame   : int   — animation frame index when damage is applied.
#   anim        : String — animation base name; direction suffix added at play time.
# ---------------------------------------------------------------------------

const _DATA : Dictionary = {

	"punch": {
		"damage_mult":  1.0,
		"range_":       1.5,
		"cooldown":     1.0,
		"energy_cost":  1,
		"hit_frame":    2,
		"anim":         "attack_unarmed"
		},

	"rat_bite": {
		"damage_mult":  1.0,
		"range_":       1.4,
		"cooldown":     2.0,
		"energy_cost":  1,
		"hit_frame":    3,
		"anim":         "attack_bite"
		}
}


# Called: player.gd, creature.gd.
# Factory — creates and returns a fresh Ability instance for the given id.
# Each caller gets its own instance so cooldown timers are tracked independently.
static func get_ability(p_id: String) -> Ability:

	assert(p_id in _DATA, "Abilities.get_ability: unknown id '%s'" % p_id)
	return Ability.new(p_id, _DATA[p_id])
